library(raster)
#library(rgdal)
library(graphics)
library(sp)
library(sf)
library(lidR)
library(future)
library(terra)
library(dplyr)

#Writingit out in parallel on bash
plan(multisession, workers = 5)

setwd(".")

#the folder where all the las/laz files are located
ctg <- catalog("./cleaned_point_clouds")
opt_chunk_buffer(ctg) <- 50
print(ctg)

#Setting the EPSG code for the las
st_crs(ctg) <- 7856 #Change to your EPSG
print(ctg)
plot(ctg, chunk = TRUE)

#Getting the tree height raster created in the previous step
tree_heights <- rast("Tree_heights.tif")
print(tree_heights)

#Making a smoothing area kernel
kernel <- matrix(1,3,3)

#The curve function for finding the tree heights
f <- function(x) {
  y <- 4 * (-(exp(-0.1*(x-6)) - 1.5)) + 3
  y[x < 5] <- x * 0.01 + 1
  y[x > 25] <- 8.5
  return(y)
}

#Searching for the number of las/laz files in the point cloud folder
num_files <-  list.files("./cleaned_point_clouds", pattern = ".", all.files = FALSE, recursive = TRUE, full.names = TRUE) %>% 
  length()

#Breaking the number of files into workable 70 file chunks
catalog_sequence <- seq(1, num_files, by =70) %>% #Getting each 20 increment within the full list number
  append(num_files) #Adding the final value for the 

############################################Looping through the point clouds to make the individual tree las/laz files##############################
# Create a for loop to iterate over the ctg in 70 tile increments
for (i in seq(catalog_sequence)) {
  if (i < length(catalog_sequence)) {
  first_value <-catalog_sequence[i]
  next_value <- catalog_sequence[i + 1]  #Getting the next value in the list
  print(first_value)
  print(next_value)
  
  # Reduce the catalog to the current 70 tile increment
  reduced_catalog <- ctg[first_value:next_value, ]
  
  # Print the reduced catalog
  print(reduced_catalog)
  
  # Convert the reduced catalog to a spatial polygons data frame
  ctg_polygons <- st_cast(reduced_catalog$geometry, "POLYGON") %>%
    st_as_sf(.)
  ctg_poly_union <- st_combine(ctg_polygons)
  
  # Print the ctg polygons data frame
  print(ctg_poly_union)
  # Mask the tree heights raster with the ctg polygons
  reduced_raster <- crop(tree_heights, ctg_poly_union) %>%
    terra::focal(".", w = kernel, fun = median, na.rm = TRUE) #smoothing the raster to create a continuous canopy polygon
  print(reduced_raster)
  
  # Set values less than zero to NA
  values(reduced_raster)[values(reduced_raster) < 0] = NA
  
  # Locate the tree tops in the reduced raster
  ttops_chm_pitfree_05_2_smoothed <- locate_trees(reduced_raster, lmf(f))
  print(ttops_chm_pitfree_05_2_smoothed)
#sf::st_write(ttops_chm_pitfree_05_2_smoothed, "ttops_chm_pitfree_05_2_smoothed.shp")
  
  # Run the dalponte2016 algorithm on the reduced raster
  algo <- dalponte2016(reduced_raster, ttops_chm_pitfree_05_2_smoothed, max_cr = 10)
  print(algo)
  
  # Set the output file paths for the reduced catalog
  opt_output_files(reduced_catalog) <- paste0("./Indiv_Trees/Trees_{XLEFT}_{YBOTTOM}_{YTOP}_{XRIGHT}")
  
  # Segment the trees in the reduced catalog
  seg_tree <- segment_trees(reduced_catalog, algo)
  
  # Print the segmented tree data frame
  print(seg_tree)
  }
  else {
  print("Finished creating the individual tree las files")
  }
}



