# Aseprite FFMPEG MP4 Exporter

A simple Aseprite plugin that exports sprites to MP4 video format using FFMPEG with a customizable UI.

## Features

- **Export to MP4**: Convert your Aseprite animation to MP4 video
- **Customizable Settings**:
  - FPS (frames per second)
  - Encoding preset (quality vs speed tradeoff)
  - Quality (CRF slider for fine-tuned quality)
  - Pixel format (yuv420p, yuv422p, yuv444p)
  - Scale factor (upscale or downscale)
  - Loop animation option
  - Optional audio mixing
- **Temporary File Management**: Automatically cleans up temporary frame files

## Prerequisites

1. **FFMPEG**: You must have FFMPEG installed and available in your system PATH
   - Download from: https://ffmpeg.org/download.html
   - Add FFMPEG to your Windows PATH environment variable
   - Verify installation: Open PowerShell and run `ffmpeg -version`

2. **Aseprite**: Obviously, you need Aseprite installed

## Installation

1. Locate your Aseprite extensions folder:
   - Windows: `%APPDATA%\Aseprite\extensions`
   - Or go to Edit → Preferences → Files → Extensions Folder

2. Create a new folder in the extensions directory (e.g., `ffmpeg-mp4-export`)

3. Copy these files into that folder:
   - `init.lua` (the main plugin script)
   - `package.json` (plugin metadata)

4. Restart Aseprite

## Usage

1. Open a sprite in Aseprite
2. Go to **File → Export to MP4 (FFMPEG)** (or similar menu location)
3. A dialog will appear with export options:
   - **Output Path**: Where to save the MP4 file (defaults to Desktop)
   - **Filename**: Name of the output file
   - **FPS**: Animation speed (24 is typical)
   - **Encoding Preset**: Balance between quality and encoding speed
     - ultrafast/superfast: Fast encoding, larger files
     - medium: Balanced
     - slower/veryslow: Smaller files, slower encoding
   - **Quality (CRF)**: 18-28 range (lower = better quality but larger files)
   - **Pixel Format**: Video color format
   - **Scale**: Multiply or divide resolution (1 = original)
   - **Loop Animation**: Repeat the animation
   - **Audio**: Optionally mix in an audio file

4. Click **Export** and wait for FFMPEG to process

## Encoding Presets Explained

- **ultrafast** - Fastest encoding, largest file size
- **superfast** - Very fast, large files
- **veryfast** - Fast, reasonable file size
- **faster** - Good speed/quality balance
- **fast** - Balanced
- **medium** - Good compression (default)
- **slow** - Better quality, slower
- **slower** - Very good quality, much slower
- **veryslow** - Best quality, very slow

## CRF (Quality) Values

CRF = Constant Rate Factor (0-51)
- 0-17: High quality (larger files)
- 18-28: Recommended range (18 = visually lossless, 23 = default good quality)
- 29-51: Lower quality (smaller files)

## Troubleshooting

**"FFMPEG export failed"**
- Make sure FFMPEG is installed
- Check that FFMPEG is in your system PATH
- Try running `ffmpeg -version` in PowerShell to verify

**File export seems stuck**
- FFMPEG might be processing. Wait a bit longer, especially with large files or slow presets
- Check the console output for errors

**Output file is too large**
- Use a higher CRF value (23-28)
- Use a faster preset (they compress better)
- Use a lower scale factor to reduce resolution

**Output file looks pixelated**
- Use a lower CRF value (18-22)
- Use a slower preset (better compression)

## Notes

- The plugin creates temporary PNG frames in your system temp directory during export
- These are automatically deleted after FFMPEG completes
- If export fails, you may need to manually delete the temp folder (named `aseprite_export_[timestamp]`)

## Advanced: Custom FFMPEG Command

If you need to use custom FFMPEG options, you can modify the `build_ffmpeg_command` function in `init.lua` to add additional FFMPEG parameters.

## License

MIT License - Feel free to modify and distribute as needed
