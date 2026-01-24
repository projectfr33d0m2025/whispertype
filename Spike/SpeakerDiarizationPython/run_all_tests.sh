#!/bin/bash
# Run all speaker diarization tests
# Usage: ./run_all_tests.sh [pyannote|simple]

set -e
cd "$(dirname "$0")"

MODE="${1:-pyannote}"
AUDIO_DIR="../../TestAssets/Audio"

if [ "$MODE" = "pyannote" ]; then
    if [ -z "$HF_TOKEN" ]; then
        echo "ERROR: HF_TOKEN not set"
        echo "Run: export HF_TOKEN='your_token'"
        exit 1
    fi
    SCRIPT="spike_diarization.py"
    SUFFIX="_pyannote"
else
    SCRIPT="spike_diarization_simple.py"
    SUFFIX="_simple"
fi

echo "=== Running $MODE diarization ==="
echo

# Test files
declare -a TESTS=(
    "two_speakers_120s:two_speakers_labels"
    "four_speakers_300s:four_speakers_labels"
    "single_speaker_60s:single_speaker_labels"
)

for test in "${TESTS[@]}"; do
    IFS=':' read -r audio labels <<< "$test"

    echo ">>> Processing $audio.wav"
    python $SCRIPT "$AUDIO_DIR/${audio}.wav" -o "results_${audio}${SUFFIX}.json"
    echo

    echo ">>> Evaluating against ${labels}.json"
    python spike_evaluate.py "results_${audio}${SUFFIX}.json" "$AUDIO_DIR/${labels}.json" || true
    echo
    echo "---"
    echo
done

echo "=== Complete ==="
