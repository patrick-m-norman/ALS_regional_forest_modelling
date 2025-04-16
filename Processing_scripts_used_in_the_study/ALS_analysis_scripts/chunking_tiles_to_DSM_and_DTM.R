# Load required packages
library(raster)
library(rgdal)
library(graphics)
library(sp)
library(sf)
library(lidR)
library(future)

setwd(".")

#the folder where all the las/laz files are located
ctg <- catalog("./cleaned_point_clouds")

# Save information about ctg to a text file
ctg_info <- capture.output(print(ctg))

# Write the captured information to a text file
writeLines(ctg_info, "ctg_info.txt")

print(ctg)

#breaking into chunks 
opt_chunk_buffer(ctg) <- 50 #Change this depending on computer memory contraints
print(ctg)
plot(ctg)
opt_filter(ctg) <- "-keep_first -drop_z_below 0 -drop_z_above 1600" #Dropping returns that are below sea level and above the tops of mountains

#Writingit out in parallel on bash
plan(multisession, workers = 5)

#Setting the EPSG code for the las
st_crs(ctg) <- YOUR_EPSG_CODE #Change to your EPSG
print(ctg)
plot(ctg, chunk = TRUE)

# Convert LAScatalog to sf object and write as shapefile
sf_ctg <- sf::st_as_sf(ctg)
# Write sf object to shapefile
#Write sf object to shapefile with the name of the directory
dirName <- basename(getwd())
st_write(sf_ctg, paste0(dirName, ".shp"))

#creating a digital surface model (DSM) and the digital terrain model (DTM)
opt_output_files(ctg) <- paste0("./DSM/DSM_{XLEFT}_{YBOTTOM}_{YTOP}_{XRIGHT}")
dsm_pitfree_05_2 <- rasterize_canopy(ctg, 1, p2r(subcircle = 0.6), pkg = "terra")
dsm_pitfree_05_2
 
opt_output_files(ctg) <- paste0("./DTM/DTM_{XLEFT}_{YBOTTOM}_{YTOP}_{XRIGHT}")
dtm <- rasterize_terrain(ctg,res=1, algorithm = tin())
dtm
# 



