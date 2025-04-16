#This script loops through a series of folders to create structure from motion point clouds from drone imagery

sudo
for folder in ./*/; do
    docker run -ti --rm -v ./"$folder":/datasets/code \
    --gpus all opendronemap/odm:gpu --project-path /datasets \
    --orthophoto-resolution 5 --pc-quality ultra --rolling-shutter --max-concurrency 20 --feature-quality ultra --optimize-disk-space
done