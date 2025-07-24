#!/bin/bash

# Script to merge MP4 files using FFmpeg, cut, normalize audio, and extract MP3
# Usage: ./merge_mp4_files.sh [input_directory] [output_prefix]

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_duration() {
    echo -e "${CYAN}[DURATION]${NC} $1"
}

print_audio() {
    echo -e "${PURPLE}[AUDIO]${NC} $1"
}

# Function to display usage
usage() {
    echo "Usage: $0 [input_directory] [output_prefix]"
    echo ""
    echo "Arguments:"
    echo "  input_directory   Directory containing MP4 files (default: current directory)"
    echo "  output_prefix     Prefix for all output files (default: processed)"
    echo ""
    echo "Examples:"
    echo "  $0                    # Creates: processed_merged.mp4, processed_cut.mp4, etc."
    echo "  $0 ./videos          # Same files from ./videos directory"
    echo "  $0 ./videos final    # Custom prefix: final_merged.mp4, final_cut.mp4, etc."
    echo ""
    echo "Output Files (with default prefix 'processed'):"
    echo "  processed_merged.mp4      # Merged video (default name)"
    echo "  processed_cut.mp4         # Cut/trimmed video (if cutting enabled)"
    echo "  processed_normalized.mp4  # Normalized audio video"
    echo "  processed_audio.mp3       # Extracted high-quality MP3"
    echo ""
    echo "Features:"
    echo "  - Preserves original video format and quality"
    echo "  - Shows video duration information"
    echo "  - Optional video cutting with timestamps"
    echo "  - Audio peak normalization to -0.5dB"
    echo "  - High-quality MP3 audio extraction"
    echo "  - Automatic codec detection and format preservation"
    echo ""
    echo "Requirements:"
    echo "  - FFmpeg must be installed"
    echo "  - MP4 files should have compatible codecs for best results"
}

# Check if ffmpeg is installed
check_ffmpeg() {
    if ! command -v ffmpeg &> /dev/null; then
        print_error "FFmpeg is not installed or not in PATH"
        print_info "Install FFmpeg with: sudo apt update && sudo apt install ffmpeg"
        exit 1
    fi
}

# Function to get video duration in seconds
get_video_duration() {
    local video_file="$1"
    local duration
    
    if [ ! -f "$video_file" ]; then
        echo "0"
        return 1
    fi
    
    # Get duration using ffprobe
    duration=$(ffprobe -v quiet -show_entries format=duration -of csv=p=0 "$video_file" 2>/dev/null || echo "0")
    echo "$duration"
}

# Function to format seconds to HH:MM:SS
format_duration() {
    local seconds="$1"
    local hours minutes secs
    
    # Handle decimal seconds
    seconds=${seconds%.*}
    
    hours=$((seconds / 3600))
    minutes=$(((seconds % 3600) / 60))
    secs=$((seconds % 60))
    
    printf "%02d:%02d:%02d" "$hours" "$minutes" "$secs"
}

# Function to validate timestamp format
validate_timestamp() {
    local timestamp="$1"
    
    # Handle empty input
    if [ -z "$timestamp" ]; then
        return 1
    fi
    
    # Check if timestamp matches HH:MM:SS or MM:SS or SS format
    # Also allow single digit formats like "0", "5", etc.
    if [[ $timestamp =~ ^([0-9]{1,2}:)?([0-9]{1,2}:)?[0-9]{1,2}(\.[0-9]+)?$ ]]; then
        return 0
    else
        return 1
    fi
}

# Function to compare floating point numbers
float_compare() {
    local num1="$1"
    local operator="$2" 
    local num2="$3"
    
    # Use awk for floating point comparison
    awk -v n1="$num1" -v op="$operator" -v n2="$num2" 'BEGIN {
        if (op == "<") exit !(n1 < n2)
        if (op == "<=") exit !(n1 <= n2)
        if (op == ">") exit !(n1 > n2)
        if (op == ">=") exit !(n1 >= n2)
        if (op == "==") exit !(n1 == n2)
        exit 1
    }'
}

# Function to convert floating point duration to integer seconds
duration_to_int() {
    local duration="$1"
    printf "%.0f" "$duration"
}

# Function to convert timestamp to seconds
timestamp_to_seconds() {
    local timestamp="$1"
    local total_seconds=0
    
    # Split by colons
    IFS=':' read -ra PARTS <<< "$timestamp"
    local parts_count=${#PARTS[@]}
    
    if [ $parts_count -eq 1 ]; then
        # SS format - convert to integer, handling "00" case
        total_seconds=$((10#${PARTS[0]:-0}))
    elif [ $parts_count -eq 2 ]; then
        # MM:SS format
        total_seconds=$((10#${PARTS[0]:-0} * 60 + 10#${PARTS[1]:-0}))
    elif [ $parts_count -eq 3 ]; then
        # HH:MM:SS format
        total_seconds=$((10#${PARTS[0]:-0} * 3600 + 10#${PARTS[1]:-0} * 60 + 10#${PARTS[2]:-0}))
    fi
    
    # Ensure we return an integer
    echo "$total_seconds"
}

# Function to detect video format and codec information
detect_video_info() {
    local video_file="$1"
    
    print_info "Analyzing video format and codecs..."
    
    # Get video codec
    local video_codec=$(ffprobe -v quiet -select_streams v:0 -show_entries stream=codec_name -of csv=p=0 "$video_file" 2>/dev/null || echo "unknown")
    
    # Get audio codec
    local audio_codec=$(ffprobe -v quiet -select_streams a:0 -show_entries stream=codec_name -of csv=p=0 "$video_file" 2>/dev/null || echo "unknown")
    
    # Get resolution
    local resolution=$(ffprobe -v quiet -select_streams v:0 -show_entries stream=width,height -of csv=s=x:p=0 "$video_file" 2>/dev/null || echo "unknown")
    
    # Get frame rate
    local framerate=$(ffprobe -v quiet -select_streams v:0 -show_entries stream=r_frame_rate -of csv=p=0 "$video_file" 2>/dev/null || echo "unknown")
    
    # Get audio sample rate and bitrate
    local sample_rate=$(ffprobe -v quiet -select_streams a:0 -show_entries stream=sample_rate -of csv=p=0 "$video_file" 2>/dev/null || echo "unknown")
    local audio_bitrate=$(ffprobe -v quiet -select_streams a:0 -show_entries stream=bit_rate -of csv=p=0 "$video_file" 2>/dev/null || echo "unknown")
    
    print_info "Video codec: $video_codec"
    print_info "Audio codec: $audio_codec" 
    print_info "Resolution: $resolution"
    print_info "Frame rate: $framerate"
    print_audio "Audio sample rate: $sample_rate Hz"
    print_audio "Audio bitrate: $audio_bitrate bps"
}

# Function to create file list for FFmpeg concat
create_file_list() {
    local input_dir="$1"
    local file_list="$2"
    local count=0
    local first_file=""
    
    print_info "Creating file list from directory: $input_dir"
    
    # Remove existing file list
    > "$file_list"
    
    # Find all MP4 files and add them to the list
    while IFS= read -r -d '' file; do
        # Get absolute path to avoid issues with relative paths
        abs_path=$(realpath "$file")
        echo "file '$abs_path'" >> "$file_list"
        print_info "Added: $(basename "$file")"
        
        # Store first file for format analysis
        if [ $count -eq 0 ]; then
            first_file="$abs_path"
        fi
        
        ((count++))
    done < <(find "$input_dir" -maxdepth 1 -name "*.mp4" -type f -print0 | sort -z)
    
    if [ $count -eq 0 ]; then
        print_error "No MP4 files found in directory: $input_dir"
        return 1
    fi
    
    print_success "Found $count MP4 files"
    
    # Analyze first file to show format info
    if [ -n "$first_file" ]; then
        print_info "Format information (based on first file):"
        detect_video_info "$first_file"
    fi
    
    return 0
}

# Function to merge files using FFmpeg with format preservation
merge_files() {
    local file_list="$1"
    local output_file="$2"
    
    print_info "Starting merge process with format preservation..."
    print_info "Output file: $output_file"
    
    # Use FFmpeg concat demuxer for exact format preservation (no re-encoding)
    # The -c copy parameter ensures no transcoding occurs
    if ffmpeg -f concat -safe 0 -i "$file_list" -c copy -avoid_negative_ts make_zero "$output_file" -y; then
        print_success "Files merged successfully with original format preserved!"
        print_info "Output saved as: $output_file"
        
        # Display file size and duration
        if [ -f "$output_file" ]; then
            file_size=$(du -h "$output_file" | cut -f1)
            duration_seconds=$(get_video_duration "$output_file")
            duration_formatted=$(format_duration "$duration_seconds")
            
            print_info "Output file size: $file_size"
            print_duration "Total merged video duration: $duration_formatted ($duration_seconds seconds)"
            
            # Analyze merged file format
            detect_video_info "$output_file"
        fi
        
        return 0
    else
        print_error "Failed to merge files"
        print_warning "This might happen if the MP4 files have incompatible formats"
        print_info "Common solutions:"
        print_info "  1. Ensure all MP4 files have the same codec and format"
        print_info "  2. Try re-encoding method (slower): ffmpeg -f concat -safe 0 -i '$file_list' -c:v libx264 -c:a aac '$output_file'"
        return 1
    fi
}

# Function to cut/trim video
cut_video() {
    local input_file="$1"
    local output_file="$2"
    local start_time="$3"
    local end_time="$4"
    
    print_info "Cutting video from $start_time to $end_time..."
    
    # Calculate duration for the cut
    local start_seconds=$(timestamp_to_seconds "$start_time")
    local end_seconds=$(timestamp_to_seconds "$end_time")
    local duration_seconds=$((end_seconds - start_seconds))
    
    if [ $duration_seconds -le 0 ]; then
        print_error "End time must be after start time"
        return 1
    fi
    
    local duration_formatted=$(format_duration "$duration_seconds")
    print_info "Cut duration will be: $duration_formatted ($duration_seconds seconds)"
    
    # Use FFmpeg to cut the video while preserving format
    if ffmpeg -ss "$start_time" -i "$input_file" -t "$duration_seconds" -c copy -avoid_negative_ts make_zero "$output_file" -y; then
        print_success "Video cut successfully!"
        
        # Show final file information
        if [ -f "$output_file" ]; then
            file_size=$(du -h "$output_file" | cut -f1)
            actual_duration=$(get_video_duration "$output_file")
            actual_duration_formatted=$(format_duration "$actual_duration")
            
            print_info "Final output file: $output_file"
            print_info "Final file size: $file_size"
            print_duration "Final video duration: $actual_duration_formatted ($actual_duration seconds)"
        fi
        
        return 0
    else
        print_error "Failed to cut video"
        return 1
    fi
}

# Function to normalize audio to -0.5dB
normalize_audio() {
    local input_file="$1"
    local output_file="$2"
    
    print_audio "Starting audio normalization to -0.5dB peak..."
    print_info "Input: $input_file"
    print_info "Output: $output_file"
    
    # First pass: analyze the audio to get the peak level
    print_info "Analyzing audio levels..."
    local max_volume=$(ffmpeg -i "$input_file" -af "volumedetect" -vn -sn -dn -f null /dev/null 2>&1 | grep "max_volume" | awk '{print $5}' | sed 's/dB//')
    
    if [ -z "$max_volume" ]; then
        print_error "Could not detect audio levels"
        return 1
    fi
    
    print_info "Current peak level: ${max_volume}dB"
    
    # Check if peak level is already at or above -0.5dB
    local target_db="-0.5"
    if float_compare "$max_volume" ">=" "$target_db"; then
        print_info "Peak level (${max_volume}dB) is already at or above target (-0.5dB)"
        print_info "Skipping normalization and renaming file..."
        
        # Move/rename the file to the normalized output name
        if mv "$input_file" "$output_file"; then
            print_success "File renamed as normalized version (no processing needed)"
        else
            print_error "Failed to rename file"
            return 1
        fi
    else
        # Calculate the gain needed to reach -0.5dB
        local gain_needed
        
        # Try different calculation methods
        if command -v bc &> /dev/null; then
            gain_needed=$(echo "$target_db - ($max_volume)" | bc -l)
        elif command -v python3 &> /dev/null; then
            gain_needed=$(python3 -c "print($target_db - ($max_volume))")
        elif command -v awk &> /dev/null; then
            gain_needed=$(awk "BEGIN {print $target_db - ($max_volume)}")
        else
            print_error "No calculation tool available (bc, python3, or awk)"
            return 1
        fi
        
        # Validate the calculation result
        if [ -z "$gain_needed" ]; then
            print_error "Failed to calculate required gain"
            return 1
        fi
        
        print_info "Applying gain: ${gain_needed}dB to reach -0.5dB peak"
        
        # Apply the calculated gain while preserving video
        if ! ffmpeg -i "$input_file" -af "volume=${gain_needed}dB" -c:v copy "$output_file" -y; then
            print_error "Failed to normalize audio"
            print_warning "This might happen if the video doesn't have an audio stream"
            return 1
        fi
    fi
    
    print_success "Audio normalization completed!"
    
    # Show file information
    if [ -f "$output_file" ]; then
        file_size=$(du -h "$output_file" | cut -f1)
        duration_seconds=$(get_video_duration "$output_file")
        duration_formatted=$(format_duration "$duration_seconds")
        
        print_info "Output file: $output_file"
        print_info "File size: $file_size"
        print_duration "Duration: $duration_formatted"
        
        # Different message based on whether we actually normalized or just copied
        if float_compare "$max_volume" ">=" "$target_db"; then
            print_audio "Audio already at optimal level (${max_volume}dB)"
        else
            print_audio "Audio peak normalized to -0.5dB"
        fi
    fi
    
    return 0
}

# Function to extract high-quality MP3 audio
extract_mp3() {
    local input_file="$1"
    local output_file="$2"
    
    print_audio "Extracting high-quality MP3 audio..."
    print_info "Input: $input_file"
    print_info "Output: $output_file"
    
    # Extract audio as high-quality MP3 (320kbps, 48kHz)
    # Use the normalized video as source for consistent audio levels
    if ffmpeg -i "$input_file" -vn -acodec libmp3lame -b:a 320k -ar 48000 "$output_file" -y; then
        print_success "MP3 extraction completed!"
        
        # Show file information
        if [ -f "$output_file" ]; then
            file_size=$(du -h "$output_file" | cut -f1)
            duration_seconds=$(get_video_duration "$output_file")
            duration_formatted=$(format_duration "$duration_seconds")
            
            print_info "MP3 file: $output_file"
            print_info "File size: $file_size"
            print_duration "Duration: $duration_formatted"
            print_audio "Quality: 320kbps, 48kHz sampling rate"
        fi
        
        return 0
    else
        print_error "Failed to extract MP3 audio"
        return 1
    fi
}

# Function to prompt for video cutting
prompt_video_cutting() {
    local merged_file="$1"
    local output_prefix="$2"
    local cut_output="${output_prefix}_cut.mp4"
    local normalized_output="${output_prefix}_normalized.mp4"
    local mp3_output="${output_prefix}_audio.mp3"
    local final_video_file="$merged_file"
    
    echo ""
    print_info "Video Processing Options"
    print_info "======================="
    
    # Ask about cutting
    read -p "Do you want to cut/trim the merged video? (y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        local duration_seconds=$(get_video_duration "$merged_file")
        local duration_formatted=$(format_duration "$duration_seconds")
        
        print_info "Total video duration: $duration_formatted"
        print_info "Timestamp format: HH:MM:SS, MM:SS, or SS (examples: 01:30:45, 15:30, 90)"
        
        # Get start time
        while true; do
            read -p "   start time: " start_time
            if validate_timestamp "$start_time"; then
                local start_seconds=$(timestamp_to_seconds "$start_time")
                if float_compare "$start_seconds" "<" "$duration_seconds"; then
                    break
                else
                    local duration_int=$(duration_to_int "$duration_seconds")
                    print_error "Start time ($start_seconds seconds) cannot be greater than video duration ($duration_int seconds)"
                fi
            else
                print_error "Invalid timestamp format. Use HH:MM:SS, MM:SS, or SS"
            fi
        done
        
        # Get end time
        while true; do
            read -p "     end time: " end_time
            if validate_timestamp "$end_time"; then
                local end_seconds=$(timestamp_to_seconds "$end_time")
                local start_seconds=$(timestamp_to_seconds "$start_time")
                if float_compare "$end_seconds" ">" "$start_seconds" && float_compare "$end_seconds" "<=" "$duration_seconds"; then
                    break
                else
                    local duration_int=$(duration_to_int "$duration_seconds")
                    print_error "End time must be after start time and within video duration ($duration_int seconds)"
                fi
            else
                print_error "Invalid timestamp format. Use HH:MM:SS, MM:SS, or SS"
            fi
        done
        
        # Perform the cut
        if cut_video "$merged_file" "$cut_output" "$start_time" "$end_time"; then
            print_success "Video cutting completed!"
            final_video_file="$cut_output"
        else
            print_error "Video cutting failed, proceeding with original merged file"
            final_video_file="$merged_file"
        fi
    else
        print_info "Skipping video cutting, using merged file for audio processing"
        final_video_file="$merged_file"
    fi
    
    # Audio processing section
    echo ""
    print_audio "Audio Processing Pipeline"
    print_audio "========================"
    print_info "Automatically processing audio (normalization + MP3 extraction)..."
    
    # Automatically normalize audio to -0.5dB peak
    if normalize_audio "$final_video_file" "$normalized_output"; then
        print_success "Audio normalization completed!"
        final_video_file="$normalized_output"
    else
        print_warning "Audio normalization failed, using previous file for MP3 extraction"
    fi
    
    # Automatically extract high-quality MP3 audio
    if extract_mp3 "$final_video_file" "$mp3_output"; then
        print_success "MP3 extraction completed!"
    else
        print_warning "MP3 extraction failed"
    fi
    
    # Summary of created files
    echo ""
    print_success "Processing Summary"
    print_success "=================="
    print_info "Created files with prefix '$output_prefix':"
    
    [ -f "$merged_file" ] && print_info "✓ Merged video: $merged_file"
    [ -f "$cut_output" ] && print_info "✓ Cut video: $cut_output"
    [ -f "$normalized_output" ] && print_info "✓ Normalized video: $normalized_output"
    [ -f "$mp3_output" ] && print_info "✓ MP3 audio: $mp3_output"
}

# Main function
main() {
    # Parse arguments
    local input_dir="${1:-.}"  # Default to current directory
    local output_prefix="${2:-processed}"  # Default prefix for output files
    local output_file="${output_prefix}_merged.mp4"  # Merged filename always uses prefix
    
    # Show help if requested
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        usage
        exit 0
    fi
    
    print_info "MP4 File Merger, Cutter & Audio Processor"
    print_info "========================================="
    print_info "Output prefix: $output_prefix"
    
    # Check prerequisites
    check_ffmpeg
    
    # Validate input directory
    if [ ! -d "$input_dir" ]; then
        print_error "Directory does not exist: $input_dir"
        exit 1
    fi
    
    # Convert to absolute path
    input_dir=$(realpath "$input_dir")
    
    # Create temporary file list
    file_list=$(mktemp /tmp/ffmpeg_filelist_XXXXXX.txt)
    
    # Ensure cleanup on exit
    trap "rm -f '$file_list'" EXIT
    
    print_info "Input directory: $input_dir"
    
    # Create file list
    if ! create_file_list "$input_dir" "$file_list"; then
        exit 1
    fi
    
    # Show file list content
    print_info "Generated file list:"
    cat "$file_list" | sed 's/^/  /'
    
    # Check if merged output file already exists
    local skip_merge=false
    if [ -f "$output_file" ]; then
        print_warning "Merged file '$output_file' already exists"
        echo "Options:"
        echo "  s) Skip merging and use existing file"
        echo "  o) Override existing file with new merge"
        echo "  c) Cancel operation"
        
        while true; do
            read -p "Choose option (s/o/c): " -n 1 -r
            echo
            case $REPLY in
                [Ss])
                    print_info "Skipping merge, using existing file: $output_file"
                    skip_merge=true
                    break
                    ;;
                [Oo])
                    print_info "Will override existing file with new merge"
                    skip_merge=false
                    break
                    ;;
                [Cc])
                    print_info "Operation cancelled by user"
                    exit 0
                    ;;
                *)
                    print_error "Invalid option. Please choose 's', 'o', or 'c'"
                    ;;
            esac
        done
    fi
    
    # Merge files (only if not skipping)
    if [ "$skip_merge" = true ]; then
        print_success "Using existing merged file! 🎬"
        
        # Show existing file information
        if [ -f "$output_file" ]; then
            file_size=$(du -h "$output_file" | cut -f1)
            duration_seconds=$(get_video_duration "$output_file")
            duration_formatted=$(format_duration "$duration_seconds")
            
            print_info "Existing file size: $file_size"
            print_duration "Existing video duration: $duration_formatted ($duration_seconds seconds)"
        fi
    else
        if merge_files "$file_list" "$output_file"; then
            print_success "Merging completed! 🎬"
        else
            exit 1
        fi
    fi
    
    # Prompt for video cutting and audio processing
    prompt_video_cutting "$output_file" "$output_prefix"
    
    print_success "All operations completed! 🎉🎵"
}

# Run main function with all arguments
main "$@" 