import cv2
import torch
import numpy as np
from realesrgan.utils import RealESRGANer
from realesrgan.archs.srvgg_arch import SRVGGNetCompact
from pathlib import Path
from tqdm import tqdm

def load_model():
    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    model_path = "models\\4x-UltraSharp.pth"  # Update with full path if needed
    model = SRVGGNetCompact(num_in_ch=3, num_out_ch=3, num_feat=64, num_conv=32, upscale=4, act_type='prelu')
    upsampler = RealESRGANer(
        scale=4,
        model_path=model_path,
        model=model,
        tile=0,  # Set to 0 if you have enough GPU memory
        tile_pad=10,
        pre_pad=0,
        half=True if device.type == "cuda" else False
    )
    return upsampler

# Upscale an image using 4x-UltraSharp
def image_upscale(image_path, output_path):
    model = load_model()
    image = cv2.imread(str(image_path), cv2.IMREAD_UNCHANGED)
    image = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)  # Convert to RGB

    upscaled_image, _ = model.enhance(image, outscale=4)
    upscaled_image = cv2.cvtColor(upscaled_image, cv2.COLOR_RGB2BGR)
    cv2.imwrite(str(output_path), upscaled_image)

def process_subfolder(subdir, output_subdir):
    output_subdir.mkdir(parents=True, exist_ok=True)

    image_files = sorted(subdir.glob("frame_*_rgb_crop.png"))  # Assuming filenames have '_rgb.png'
    for rgb_file in tqdm(image_files, desc=f"Processing {subdir.name}"):
        depth_file = rgb_file.with_name(rgb_file.stem.replace("_rgb", "_depth") + rgb_file.suffix)

        if not depth_file.exists():
            print(f"Warning: No corresponding depth image for {rgb_file.name}")
            continue

        # # Read images
        # rgb_image = cv2.imread(str(rgb_file))
        # depth_image = cv2.imread(str(depth_file), cv2.IMREAD_UNCHANGED)

        # # Remove background
        # rgb_upscale = image_upscale(rgb_image)
        # depth_upscale = image_upscale(depth_image)

        # # Save output images
        # cv2.imwrite(str(output_subdir / rgb_file.name), rgb_upscale)
        # cv2.imwrite(str(output_subdir / depth_file.name), depth_upscale)

        # Define output file paths
        output_rgb_file = output_subdir / rgb_file.name
        output_depth_file = output_subdir / depth_file.name

        # Process images with Waifu2x
        image_upscale(rgb_file, output_rgb_file)
        image_upscale(depth_file, output_depth_file)

def process_images(input_folder, output_folder):
    input_path = Path(input_folder)
    output_path = Path(output_folder)
    
    if not input_path.exists():
        print("Input folder does not exist.")
        return
    
    for subdir in tqdm(list(input_path.glob('*')), desc="Processing folders"):
        if subdir.is_dir():
            process_subfolder(subdir, output_path / subdir.relative_to(input_path))

if __name__ == "__main__":
    input_folder = ".\\Jan_14_2025-Batch1\\outputs_test"  # Change this to your actual path
    output_folder = ".\\Jan_14_2025-Batch1\\background_remove_output_20250309"
    process_images(input_folder, output_folder)