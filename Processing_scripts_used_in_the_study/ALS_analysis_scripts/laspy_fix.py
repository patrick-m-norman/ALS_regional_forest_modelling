import laspy
import os

def laspy_write(source: str, dest: str, chunk_size: int = 1_234_567) -> None:
    """Fix bad laz files and strip extra bytes."""
    with laspy.open(source) as f:
        # Read the header and remove extra bytes
        header = f.header
        header.extra_bytes = None
        
        with laspy.open(dest, mode="w", header=header) as writer:
            for points in f.chunk_iterator(chunk_size):
                # Strip extra bytes from points
                points = points[:header.point_count]
                writer.write_points(points)

input_folder = 'point_clouds'
output_folder = 'fixed_point_clouds'


# Create output directory if it does not exist
os.makedirs(output_folder, exist_ok=True)

# Loop over all .laz files in the input folder
for filename in os.listdir(input_folder):
    if filename.endswith('.laz'):
        source_path = os.path.join(input_folder, filename)
        dest_path = os.path.join(output_folder, filename)
        laspy_write(source_path, dest_path)

print("Processing complete.")

