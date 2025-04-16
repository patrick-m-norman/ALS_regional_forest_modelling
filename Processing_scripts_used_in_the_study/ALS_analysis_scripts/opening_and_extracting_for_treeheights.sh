#USING laspy, PDAL, LidR and GDAL TO QUICKLY CREATE A TREE HEIGHT RASTER FROM POINT CLOUD DATA SOURCED
#Move all of your point cloud las or laz into a folder named point_clouds. Leave the following scripts in your work directory
#laspy_fix.py
#point_cleaning.json
#chunking_tiles_to_CHM_and_DTM.R
#smoothing_raster_and_getting_treetops.R
#creating_tree_crowns.R

#Creating three folders
mkdir cleaned_point_clouds fixed_point_clouds

##Opening up the shell in a conda environment containing the pdal program
eval "$(conda shell.bash hook)"
conda activate open3d_env

python laspy_fix.py

conda activate pdal_env
#Having a go at looping throug each laz

#Further cleaning of the point clouds using PDAL
basename -s.laz ./fixed_point_clouds/*.laz | xargs -n1 -P5 \
    -I % pdal pipeline point_cleaning.json \
    --readers.las.filename=./fixed_point_clouds/%.laz \
    --writers.las.filename=./cleaned_point_clouds/%_cleaned.laz

#Creating three folders
mkdir DTM CHM Indiv_Trees Crowns

#Create a terrain and surface model tif for each point cloud in parallel and put the output in the relavent folders
Rscript chunking_tiles_to_DSM_and_DTM.R

#Now activate gdal environment
#eval "$(conda shell.bash hook)"
conda activate gdal_env

#merging each of the tifs together. If you have many overlapping tiles, it will take the last file.
gdal_merge.py -a_nodata -999 -co BIGTIFF=YES -o DSM_merged.tif -co NUM_THREADS=ALL_CPUS ./DSM/*.tif
gdal_merge.py -a_nodata -999 -co BIGTIFF=YES -o DTM_merged.tif -co NUM_THREADS=ALL_CPUS ./DTM/*.tif

##Using gdal to subtract the DTM from the DSM
gdal_calc.py -A DSM_merged.tif -B DTM_merged.tif --co=BIGTIFF=YES --co=COMPRESS=DEFLATE --co=NUM_THREADS=ALL_CPUS --outfile=./Tree_heights.tif --calc="A-B"

#Running the tree top detection and tree crown creation scripts
Rscript smoothing_raster_and_getting_treetops.R
Rscript creating_tree_crowns.R

# Output merged shapefile with filtered polygons
ogrmerge.py -single -f VRT -o ./Crowns/merged.vrt ./Crowns/*.shp

# Merge and filter polygons by area using ogr2ogr
ogr2ogr -f "GPKG" Crowns_over5m.gpkg ./Crowns/merged.vrt -dialect sqlite -sql "SELECT * FROM merged WHERE ST_Area(geometry) >= 5 AND ST_Perimeter(geometry) < 150"


