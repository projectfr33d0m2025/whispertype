#!/bin/bash
# convert_audio.sh
# Converts audio files to the format required for the spike (16kHz mono WAV)
#
# Usage: ./convert_audio.sh input_file output_file
# Example: ./convert_audio.sh meeting.mp4 two_speakers_zoom.wav

set -e

if [ $# -lt 2 ]; then
    echo "Usage: $0 <input_file> <output_file> [duration_seconds]"
    echo ""
    echo "Examples:"
    echo "  $0 meeting.mp4 two_speakers_zoom.wav"
    echo "  $0 recording.m4a two_speakers_clear.wav 120"
    echo ""
    echo "Converts to: 16kHz, mono, 16-bit PCM WAV"
    exit 1
fi

INPUT="$1"
OUTPUT="$2"
DURATION="${3:-}"

if [ ! -f "$INPUT" ]; then
    echo "Error: Input file not found: $INPUT"
    exit 1
fi

# Check if ffmpeg is available
if ! command -v ffmpeg &> /dev/null; then
    echo "Error: ffmpeg is not installed"
    echo "Install with: brew install ffmpeg"
    exit 1
fi

echo "Converting: $INPUT"
echo "Output: $OUTPUT"

# Build ffmpeg command
FFMPEG_CMD="ffmpeg -i \"$INPUT\" -ar 16000 -ac 1 -acodec pcm_s16le"

if [ -n "$DURATION" ]; then
    FFMPEG_CMD="$FFMPEG_CMD -t $DURATION"
    echo "Duration: ${DURATION}s"
fi

FFMPEG_CMD="$FFMPEG_CMD -y \"$OUTPUT\""

# Run conversion
echo ""
echo "Running: $FFMPEG_CMD"
eval $FFMPEG_CMD

# Show result
echo ""
echo "✅ Conversion complete!"
echo ""

# Show audio info
if command -v ffprobe &> /dev/null; then
    echo "Audio info:"
    ffprobe -hide_banner -i "$OUTPUT" 2>&1 | grep -E "Duration|Stream|Audio"
fi

echo ""
echo "Next step: Create ground truth labels file:"
echo "  ${OUTPUT%.wav}_labels.json"
