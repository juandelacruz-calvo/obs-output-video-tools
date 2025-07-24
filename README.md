# MP4 Video Merger & Audio Processor

A comprehensive bash script that merges multiple MP4 files, provides optional video cutting with timestamps, automatically normalizes audio to -0.5dB peak, and extracts high-quality MP3 audio files.

## 🎬 Features

- **Smart MP4 Merging** - Combines multiple MP4 files while preserving original format and quality
- **Interactive Video Cutting** - Trim videos with flexible timestamp input (HH:MM:SS, MM:SS, or SS)
- **Intelligent Audio Normalization** - Automatically normalizes audio to -0.5dB peak (skips if already optimal)
- **High-Quality MP3 Extraction** - Creates 320kbps, 48kHz MP3 files automatically
- **Format Preservation** - No re-encoding during merge and cut operations for maximum quality
- **Comprehensive Video Analysis** - Shows codec information, resolution, duration, and audio specs
- **Smart File Management** - Handles existing files with skip/override options
- **Consistent Output Naming** - All files use customizable prefix for easy organization

## 📋 Requirements

- **FFmpeg** - Must be installed and available in PATH
- **Ubuntu/Linux** - Script is designed for bash environments
- **Dependencies** - At least one of: `bc`, `python3`, or `awk` (for floating-point calculations)

### Installing FFmpeg

```bash
# Ubuntu/Debian
sudo apt update && sudo apt install ffmpeg

# Check installation
ffmpeg -version
```

## 🚀 Installation

1. Download the script:
```bash
wget https://your-repo/merge_mp4_files.sh
# or
curl -O https://your-repo/merge_mp4_files.sh
```

2. Make it executable:
```bash
chmod +x merge_mp4_files.sh
```

## 📖 Usage

```bash
./merge_mp4_files.sh [input_directory] [output_prefix]
```

### Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `input_directory` | Directory containing MP4 files | Current directory (`.`) |
| `output_prefix` | Prefix for all output files | `processed` |

### Examples

```bash
# Basic usage - processes current directory
./merge_mp4_files.sh
# Output: processed_merged.mp4, processed_cut.mp4, processed_normalized.mp4, processed_audio.mp3

# Custom directory
./merge_mp4_files.sh ./my_videos
# Output: processed_* files from ./my_videos

# Custom prefix
./merge_mp4_files.sh ./videos project
# Output: project_merged.mp4, project_cut.mp4, project_normalized.mp4, project_audio.mp3
```

## 📁 Output Files

The script generates up to 4 files with your chosen prefix:

| File | Description | Always Created |
|------|-------------|----------------|
| `{prefix}_merged.mp4` | Merged video from all MP4s | ✅ Yes |
| `{prefix}_cut.mp4` | Trimmed video (if cutting enabled) | ❓ Optional |
| `{prefix}_normalized.mp4` | Audio normalized to -0.5dB | ✅ Yes |
| `{prefix}_audio.mp3` | High-quality MP3 (320kbps) | ✅ Yes |

## 🔄 Workflow

### 1. **Video Analysis & Merging**
- Scans directory for MP4 files (sorted alphabetically)
- Analyzes first file for format information (codec, resolution, framerate)
- Checks if merged file exists (skip/override/cancel options)
- Merges files using FFmpeg concat demuxer (no re-encoding)

### 2. **Optional Video Cutting**
- Interactive prompt for video trimming
- Flexible timestamp formats: `HH:MM:SS`, `MM:SS`, or `SS`
- Shows total duration and validates input ranges
- Preserves format during cutting (stream copy)

### 3. **Automatic Audio Processing**
- **Smart Normalization**: Analyzes current peak levels
  - If ≥ -0.5dB: Renames file (no processing needed)
  - If < -0.5dB: Applies calculated gain to reach -0.5dB
- **MP3 Extraction**: Creates high-quality MP3 from normalized video

### 4. **Results Summary**
- Shows all created files with sizes and durations
- Displays processing summary with checkmarks

## 💡 Example Session

```bash
$ ./merge_mp4_files.sh ./vacation_clips final

[INFO] MP4 File Merger, Cutter & Audio Processor
[INFO] Output prefix: final

[INFO] Found 5 MP4 files
[INFO] Video codec: h264, Audio codec: aac
[INFO] Resolution: 1920x1080, Frame rate: 30/1

[SUCCESS] Files merged successfully! (final_merged.mp4)
[DURATION] Total merged video duration: 02:15:30 (8130 seconds)

Do you want to cut/trim the merged video? (y/N): y
   start time: 00:05:00
     end time: 01:45:00
[SUCCESS] Video cutting completed!

[AUDIO] Audio Processing Pipeline
[INFO] Current peak level: -2.1dB
[INFO] Applying gain: 1.6dB to reach -0.5dB peak
[SUCCESS] Audio normalization completed!
[SUCCESS] MP3 extraction completed!

[SUCCESS] Processing Summary
✓ Merged video: final_merged.mp4
✓ Cut video: final_cut.mp4
✓ Normalized video: final_normalized.mp4  
✓ MP3 audio: final_audio.mp3
```

## 🎯 Timestamp Format Examples

| Input | Interpretation | Seconds |
|-------|----------------|---------|
| `30` | 30 seconds | 30 |
| `5:30` | 5 minutes 30 seconds | 330 |
| `1:05:30` | 1 hour 5 minutes 30 seconds | 3930 |
| `00` | 0 seconds (start) | 0 |
| `90` | 90 seconds (1.5 minutes) | 90 |

## 🔧 Advanced Features

### Existing File Handling
When a merged file already exists:
- **Skip (s)**: Use existing file, proceed to cutting/audio
- **Override (o)**: Delete existing, create fresh merge
- **Cancel (c)**: Exit script

### Audio Normalization Intelligence
- Analyzes current peak levels before processing
- Skips normalization if audio is already ≥ -0.5dB
- Moves/renames file instead of copying when skipping
- Provides clear feedback about what was done

### Format Preservation
- Uses FFmpeg stream copy (`-c copy`) whenever possible
- No quality loss during merge and cut operations
- Maintains original codecs, resolution, and framerate

## 🛠️ Troubleshooting

### Common Issues

**Error: "FFmpeg not found"**
```bash
# Install FFmpeg
sudo apt update && sudo apt install ffmpeg
```

**Error: "No MP4 files found"**
- Check directory path
- Ensure files have `.mp4` extension (case sensitive)
- Verify read permissions

**Error: "Failed to merge files"**
- MP4 files may have incompatible formats
- Try re-encoding: `ffmpeg -i input.mp4 -c:v libx264 -c:a aac output.mp4`

**Error: "Numerical result out of range"**
- Usually resolved in latest version
- Ensure `bc`, `python3`, or `awk` is installed

### Performance Tips

- **SSD Storage**: Process files on SSD for faster operations
- **File Organization**: Keep source files in same directory
- **Batch Processing**: Use consistent prefixes for easy file management

## 📊 Technical Specifications

### Video Processing
- **Merge Method**: FFmpeg concat demuxer
- **Quality**: Lossless (stream copy)
- **Supported Formats**: Any MP4-compatible codecs
- **Performance**: Limited by disk I/O, not CPU

### Audio Processing
- **Normalization Target**: -0.5dB peak
- **Analysis Method**: FFmpeg volumedetect filter
- **MP3 Quality**: 320kbps, 48kHz sampling rate
- **Codec**: libmp3lame

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🤝 Contributing

Contributions welcome! Please test thoroughly before submitting pull requests.

## 📞 Support

For issues or questions:
1. Check the troubleshooting section
2. Verify FFmpeg installation
3. Test with small sample files first
4. Check file permissions and paths

---

**Happy Video Processing! 🎬🎵** 