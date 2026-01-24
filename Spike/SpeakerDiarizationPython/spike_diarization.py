#!/usr/bin/env python3
"""
Speaker Diarization Spike using PyAnnote.audio

Runs speaker diarization on audio file and outputs segments with speaker labels.
"""

import argparse
import json
import os
import sys
import time
from pathlib import Path

import torch
import torchaudio
from pyannote.audio import Pipeline


def load_audio_info(audio_path: str) -> dict:
    """Get audio file info without loading full audio."""
    info = torchaudio.info(audio_path)
    return {
        "sample_rate": info.sample_rate,
        "num_frames": info.num_frames,
        "num_channels": info.num_channels,
        "duration_seconds": info.num_frames / info.sample_rate
    }


def run_diarization(audio_path: str, hf_token: str = None, num_speakers: int = None,
                    min_speakers: int = None, max_speakers: int = None) -> dict:
    """
    Run PyAnnote speaker diarization on audio file.

    Args:
        audio_path: Path to audio file (WAV, 16kHz mono recommended)
        hf_token: HuggingFace token for model download
        num_speakers: Optional hint for number of speakers

    Returns:
        Dict with segments and metadata
    """
    # Get token from env if not provided
    if not hf_token:
        hf_token = os.environ.get("HF_TOKEN") or os.environ.get("HUGGINGFACE_TOKEN")

    if not hf_token:
        print("ERROR: HuggingFace token required. Set HF_TOKEN env var or pass --hf-token")
        print("Get token at: https://huggingface.co/settings/tokens")
        print("Accept model terms at: https://huggingface.co/pyannote/speaker-diarization-3.1")
        sys.exit(1)

    # Get audio info
    audio_info = load_audio_info(audio_path)
    print(f"Audio: {audio_path}")
    print(f"  Duration: {audio_info['duration_seconds']:.2f}s")
    print(f"  Sample rate: {audio_info['sample_rate']}Hz")
    print(f"  Channels: {audio_info['num_channels']}")

    # Determine device
    if torch.backends.mps.is_available():
        device = torch.device("mps")
        print(f"  Device: Apple Silicon (MPS)")
    elif torch.cuda.is_available():
        device = torch.device("cuda")
        print(f"  Device: CUDA")
    else:
        device = torch.device("cpu")
        print(f"  Device: CPU")

    # Load pipeline
    print("\nLoading PyAnnote pipeline...")
    start_load = time.time()

    pipeline = Pipeline.from_pretrained(
        "pyannote/speaker-diarization-3.1",
        token=hf_token
    )
    pipeline.to(device)

    load_time = time.time() - start_load
    print(f"  Model loaded in {load_time:.2f}s")

    # Load audio as waveform (workaround for PyAnnote 4.x torchcodec issue)
    import torchaudio
    waveform, sample_rate = torchaudio.load(audio_path)

    # Run diarization
    print("\nRunning diarization...")
    start_diarize = time.time()

    # Pass as dict to avoid torchcodec dependency
    audio_input = {"waveform": waveform, "sample_rate": sample_rate}

    # Build kwargs for speaker count hints
    kwargs = {}
    if num_speakers:
        kwargs["num_speakers"] = num_speakers
    if min_speakers:
        kwargs["min_speakers"] = min_speakers
    if max_speakers:
        kwargs["max_speakers"] = max_speakers

    diarization = pipeline(audio_input, **kwargs)

    diarize_time = time.time() - start_diarize
    realtime_factor = diarize_time / audio_info['duration_seconds']
    print(f"  Diarization complete in {diarize_time:.2f}s ({realtime_factor:.2f}x realtime)")

    # Extract segments (PyAnnote 4.x returns DiarizeOutput with speaker_diarization attribute)
    segments = []
    speakers_found = set()

    # Handle both PyAnnote 3.x (Annotation) and 4.x (DiarizeOutput)
    if hasattr(diarization, 'speaker_diarization'):
        annotation = diarization.speaker_diarization
    else:
        annotation = diarization

    for turn, _, speaker in annotation.itertracks(yield_label=True):
        segments.append({
            "speaker": speaker,
            "start": round(turn.start, 3),
            "end": round(turn.end, 3)
        })
        speakers_found.add(speaker)

    print(f"\nResults:")
    print(f"  Speakers found: {len(speakers_found)} ({', '.join(sorted(speakers_found))})")
    print(f"  Segments: {len(segments)}")

    return {
        "audio_file": os.path.basename(audio_path),
        "duration_seconds": audio_info['duration_seconds'],
        "speakers": sorted(list(speakers_found)),
        "segments": segments,
        "metadata": {
            "model": "pyannote/speaker-diarization-3.1",
            "device": str(device),
            "load_time_seconds": round(load_time, 3),
            "diarization_time_seconds": round(diarize_time, 3),
            "realtime_factor": round(realtime_factor, 3)
        }
    }


def main():
    parser = argparse.ArgumentParser(description="Run speaker diarization on audio file")
    parser.add_argument("audio_path", help="Path to audio file")
    parser.add_argument("-o", "--output", help="Output JSON file (default: stdout)")
    parser.add_argument("--hf-token", help="HuggingFace token (or set HF_TOKEN env)")
    parser.add_argument("--num-speakers", type=int, help="Exact number of speakers (if known)")
    parser.add_argument("--min-speakers", type=int, help="Minimum number of speakers")
    parser.add_argument("--max-speakers", type=int, help="Maximum number of speakers")

    args = parser.parse_args()

    if not os.path.exists(args.audio_path):
        print(f"ERROR: Audio file not found: {args.audio_path}")
        sys.exit(1)

    result = run_diarization(args.audio_path, args.hf_token, args.num_speakers,
                             args.min_speakers, args.max_speakers)

    output_json = json.dumps(result, indent=2)

    if args.output:
        with open(args.output, 'w') as f:
            f.write(output_json)
        print(f"\nResults written to: {args.output}")
    else:
        print("\n" + "="*60)
        print(output_json)


if __name__ == "__main__":
    main()
