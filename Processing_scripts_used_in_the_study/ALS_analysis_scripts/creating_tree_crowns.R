library(raster)
library(rgdal)
library(sp)
library(sf)
library(lidR)
library(future)
library(terra)


setwd(".")

############################################Looping through the individual tree catalog to make crown polygons##############################
tree_ctg <- catalog("./Indiv_Trees")
opt_output_files(tree_ctg) <- paste0("./Crowns/Crown_polygons_{XLEFT}_{YBOTTOM}")
crowns <- crown_metrics(tree_ctg, func = NULL, geom = "concave", res=1)
crowns
