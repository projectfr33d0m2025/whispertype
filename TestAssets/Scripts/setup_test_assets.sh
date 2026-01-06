#!/bin/bash
#
# WhisperType Test Assets Setup Script
# 
# This script sets up all test artifacts needed for WhisperType v1.3.0 testing.
#
# Usage:
#   ./setup_test_assets.sh           # Run all setup steps
#   ./setup_test_assets.sh --auto    # Auto-generate files (no ElevenLabs)
#   ./setup_test_assets.sh --help    # Show help
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
AUDIO_DIR="$PROJECT_ROOT/Audio"
MOCKS_DIR="$PROJECT_ROOT/Mocks"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_header() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

print_step() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

show_help() {
    cat << EOF
WhisperType Test Assets Setup Script

Usage:
    ./setup_test_assets.sh [OPTIONS]

Options:
    --auto          Auto-generate all possible files (no ElevenLabs needed)
    --elevenlabs    Generate audio files using ElevenLabs API
    --mock-only     Only generate mock JSON data files
    --audio-only    Only generate audio files
    --help          Show this help message

Environment Variables:
    ELEVENLABS_API_KEY    Required for --elevenlabs option

Examples:
    # Generate everything that doesn't need ElevenLabs:
    ./setup_test_assets.sh --auto

    # Generate audio with ElevenLabs:
    export ELEVENLABS_API_KEY="your-key"
    ./setup_test_assets.sh --elevenlabs

    # Just generate mock data:
    ./setup_test_assets.sh --mock-only
EOF
}

create_directories() {
    print_header "Creating Directory Structure"
    
    mkdir -p "$AUDIO_DIR"
    mkdir -p "$MOCKS_DIR"
    
    print_step "Created $AUDIO_DIR"
    print_step "Created $MOCKS_DIR"
}

generate_programmatic_audio() {
    print_header "Generating Programmatic Audio Files"
    
    # Check for ffmpeg
    if ! command -v ffmpeg &> /dev/null; then
        print_error "ffmpeg not found. Install with: brew install ffmpeg"
        return 1
    fi
    
    # Generate silence (30 seconds)
    ffmpeg -y -f lavfi -i anullsrc=r=16000:cl=mono -t 30 -acodec pcm_s16le \
        "$AUDIO_DIR/silence_30s.wav" 2>/dev/null
    print_step "Generated silence_30s.wav"
    
    # Generate 1kHz tone (30 seconds)
    ffmpeg -y -f lavfi -i "sine=frequency=1000:sample_rate=16000" -t 30 -acodec pcm_s16le \
        "$AUDIO_DIR/tone_1khz_30s.wav" 2>/dev/null
    print_step "Generated tone_1khz_30s.wav"
    
    # Generate low volume audio (quiet sine wave)
    ffmpeg -y -f lavfi -i "sine=frequency=440:sample_rate=16000" -t 30 \
        -af "volume=0.1" -acodec pcm_s16le \
        "$AUDIO_DIR/low_volume_30s.wav" 2>/dev/null
    print_step "Generated low_volume_30s.wav"
    
    # Generate clipping audio (over-amplified sine wave)
    ffmpeg -y -f lavfi -i "sine=frequency=440:sample_rate=16000" -t 30 \
        -af "volume=10" -acodec pcm_s16le \
        "$AUDIO_DIR/clipping_30s.wav" 2>/dev/null
    print_step "Generated clipping_30s.wav"
}

generate_tts_audio() {
    print_header "Generating TTS Audio (macOS say command)"
    
    # Use macOS 'say' command as fallback for known text
    if command -v say &> /dev/null; then
        # Generate known text audio using macOS TTS
        TEXT="The quick brown fox jumps over the lazy dog. Pack my box with five dozen liquor jugs. How vexingly quick daft zebras jump. The five boxing wizards jump quickly."
        
        say -o "$AUDIO_DIR/known_text_30s_tts.aiff" "$TEXT"
        
        # Convert to WAV format
        ffmpeg -y -i "$AUDIO_DIR/known_text_30s_tts.aiff" \
            -ar 16000 -ac 1 -acodec pcm_s16le \
            "$AUDIO_DIR/known_text_30s.wav" 2>/dev/null
        
        rm -f "$AUDIO_DIR/known_text_30s_tts.aiff"
        print_step "Generated known_text_30s.wav (using macOS TTS)"
        
        # Create expected transcription file
        echo "$TEXT" > "$AUDIO_DIR/known_text_30s_expected.txt"
        print_step "Created known_text_30s_expected.txt"
    else
        print_warning "macOS 'say' command not available"
    fi
}

generate_mock_data() {
    print_header "Generating Mock Data Files"
    
    cd "$SCRIPT_DIR"
    python3 generate_mock_data.py
    print_step "Generated all mock JSON files"
}

generate_ground_truth() {
    print_header "Generating Ground Truth Labels"
    
    cd "$SCRIPT_DIR"
    
    # Generate ground truth for each script
    for script in *_script.txt; do
        if [[ -f "$script" ]]; then
            base="${script%_script.txt}"
            python3 generate_ground_truth.py "$script" "$AUDIO_DIR/${base}_labels.json"
        fi
    done
}

generate_elevenlabs_audio() {
    print_header "Generating Audio with ElevenLabs"
    
    if [[ -z "$ELEVENLABS_API_KEY" ]]; then
        print_error "ELEVENLABS_API_KEY not set"
        echo "  Run: export ELEVENLABS_API_KEY='your-key'"
        return 1
    fi
    
    cd "$SCRIPT_DIR"
    
    # Check for required packages
    if ! python3 -c "import elevenlabs" 2>/dev/null; then
        print_warning "Installing elevenlabs package..."
        pip3 install elevenlabs pydub
    fi
    
    python3 generate_audio.py --all
}

verify_setup() {
    print_header "Verifying Setup"
    
    local missing=0
    
    # Check audio files
    echo "Audio files:"
    for file in silence_30s.wav tone_1khz_30s.wav; do
        if [[ -f "$AUDIO_DIR/$file" ]]; then
            print_step "$file"
        else
            print_warning "$file (missing)"
            ((missing++))
        fi
    done
    
    # Check mock files
    echo ""
    echo "Mock data files:"
    for file in sample_transcript.json sample_transcript_speakers.json sample_meeting_record.json; do
        if [[ -f "$MOCKS_DIR/$file" ]]; then
            print_step "$file"
        else
            print_warning "$file (missing)"
            ((missing++))
        fi
    done
    
    echo ""
    if [[ $missing -eq 0 ]]; then
        print_step "All required files present!"
    else
        print_warning "$missing files missing"
    fi
}

print_next_steps() {
    print_header "Next Steps"
    
    cat << EOF

${GREEN}Auto-generated files are ready!${NC}

For ElevenLabs audio (recommended for diarization testing):

  1. Get your API key from https://elevenlabs.io
  
  2. Set the environment variable:
     ${YELLOW}export ELEVENLABS_API_KEY="your-key-here"${NC}
  
  3. Generate audio files:
     ${YELLOW}./setup_test_assets.sh --elevenlabs${NC}

Alternative (manual generation):

  1. Open each *_script.txt file in Scripts/
  2. Copy the text for each speaker
  3. Generate in ElevenLabs web UI with appropriate voice
  4. Download and save to Audio/ directory
  5. Run: ${YELLOW}python3 generate_ground_truth.py <script> <output.json>${NC}

For more info, see: Scripts/README.md
EOF
}

# Main execution
main() {
    case "${1:-}" in
        --help)
            show_help
            exit 0
            ;;
        --auto)
            create_directories
            generate_programmatic_audio
            generate_tts_audio
            generate_mock_data
            generate_ground_truth
            verify_setup
            print_next_steps
            ;;
        --elevenlabs)
            create_directories
            generate_elevenlabs_audio
            generate_ground_truth
            verify_setup
            ;;
        --mock-only)
            create_directories
            generate_mock_data
            ;;
        --audio-only)
            create_directories
            generate_programmatic_audio
            generate_tts_audio
            ;;
        *)
            create_directories
            generate_programmatic_audio
            generate_tts_audio
            generate_mock_data
            generate_ground_truth
            verify_setup
            print_next_steps
            ;;
    esac
}

main "$@"
