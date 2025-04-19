import os
import shutil
import glob

def transfer_depth_images(rgb_folder, depth_folder, output_folder):
    # Create output folder if it doesn't exist
    if not os.path.exists(output_folder):
        os.makedirs(output_folder)
    
    # Get list of RGB images
    rgb_pattern = os.path.join(rgb_folder, "frame_*_rgb_crop_*.png")
    rgb_images = glob.glob(rgb_pattern)
    
    for rgb_path in rgb_images:
        # Extract frame number and crop number from RGB filename
        rgb_filename = os.path.basename(rgb_path)
        parts = rgb_filename.split('_')
        frame_num = parts[1]
        crop_num = parts[-1].split('.')[0]  # Remove .png
        
        # Construct corresponding depth filename
        depth_filename = f"frame_{frame_num}_depth_crop_{crop_num}.png"
        depth_path = os.path.join(depth_folder, depth_filename)
        
        # Check if depth image exists and copy to output folder
        if os.path.exists(depth_path):
            output_path = os.path.join(output_folder, depth_filename)
            shutil.copy(depth_path, output_path)
            print(f"Copied: {depth_filename}")
        else:
            print(f"Depth image not found for: {rgb_filename}")

# Example usage
rgb_folder = ".\\April_05_2025-Batch3\\outputs_4\\depth_rgb_recording(4)\\WhitewithManySpots"      # Replace with your RGB images folder path
depth_folder = ".\\April_05_2025-Batch3\\outputs\\depth_rgb_recording(4)"  # Replace with your depth images folder path
output_folder = ".\\April_05_2025-Batch3\\outputs_4\\depth_rgb_recording(4)\\WhitewithManySpots" # Replace with your output folder path

transfer_depth_images(rgb_folder, depth_folder, output_folder)