#!/usr/bin/env python3
"""
Simple speaker diarization using spectral clustering on MFCC features.
No auth required - for baseline comparison only.

This is a fallback when PyAnnote is not available.
"""

import argparse
import json
import os
import sys
import time
from pathlib import Path

import numpy as np
import librosa
from scipy.cluster.hierarchy import linkage, fcluster
from scipy.spatial.distance import pdist


def extract_features(audio_path: str, sr: int = 16000,
                     frame_length: float = 0.5, hop_length: float = 0.25) -> tuple:
    """
    Extract MFCC features from audio.

    Returns:
        features: Array of shape (n_frames, n_mfcc)
        times: Array of frame center times
    """
    # Load audio
    y, sr_actual = librosa.load(audio_path, sr=sr, mono=True)
    duration = len(y) / sr

    # Frame-level feature extraction
    n_fft = int(frame_length * sr)
    hop = int(hop_length * sr)

    # Extract MFCCs
    mfcc = librosa.feature.mfcc(y=y, sr=sr, n_mfcc=20, n_fft=n_fft, hop_length=hop)

    # Add delta features
    delta = librosa.feature.delta(mfcc)
    delta2 = librosa.feature.delta(mfcc, order=2)

    # Combine (transpose to n_frames x n_features)
    features = np.vstack([mfcc, delta, delta2]).T

    # Calculate frame times
    n_frames = features.shape[0]
    times = np.arange(n_frames) * hop_length + frame_length / 2

    return features, times, duration


def detect_speech(audio_path: str, sr: int = 16000,
                  frame_length: float = 0.5, hop_length: float = 0.25,
                  energy_threshold: float = 0.01) -> np.ndarray:
    """
    Simple energy-based speech detection.

    Returns boolean mask for speech frames.
    """
    y, _ = librosa.load(audio_path, sr=sr, mono=True)

    n_fft = int(frame_length * sr)
    hop = int(hop_length * sr)

    # RMS energy
    rms = librosa.feature.rms(y=y, frame_length=n_fft, hop_length=hop)[0]

    # Threshold relative to max
    threshold = energy_threshold * np.max(rms)
    speech_mask = rms > threshold

    return speech_mask


def cluster_speakers(features: np.ndarray, num_speakers: int = None,
                     min_speakers: int = 1, max_speakers: int = 8) -> np.ndarray:
    """
    Cluster features into speaker groups using hierarchical clustering.
    """
    if len(features) < 2:
        return np.zeros(len(features), dtype=int)

    # Compute pairwise distances
    distances = pdist(features, metric='cosine')

    # Hierarchical clustering
    Z = linkage(distances, method='ward')

    if num_speakers:
        labels = fcluster(Z, t=num_speakers, criterion='maxclust') - 1
    else:
        # Auto-detect: try different cluster counts, pick by silhouette
        from sklearn.metrics import silhouette_score

        best_score = -1
        best_labels = None
        best_k = 2

        for k in range(min_speakers, min(max_speakers + 1, len(features))):
            labels = fcluster(Z, t=k, criterion='maxclust') - 1

            if len(np.unique(labels)) < 2:
                continue

            try:
                score = silhouette_score(features, labels, metric='cosine')
                if score > best_score:
                    best_score = score
                    best_labels = labels
                    best_k = k
            except:
                pass

        labels = best_labels if best_labels is not None else fcluster(Z, t=2, criterion='maxclust') - 1
        print(f"  Auto-detected {best_k} speakers (silhouette={best_score:.3f})")

    return labels


def labels_to_segments(labels: np.ndarray, times: np.ndarray,
                       speech_mask: np.ndarray, hop_length: float) -> list:
    """
    Convert frame-level labels to segments.
    """
    segments = []
    current_speaker = None
    segment_start = None

    for i, (label, is_speech, t) in enumerate(zip(labels, speech_mask, times)):
        if is_speech:
            speaker = f"SPEAKER_{label:02d}"

            if speaker != current_speaker:
                # Close previous segment
                if current_speaker is not None:
                    segments.append({
                        "speaker": current_speaker,
                        "start": round(segment_start, 3),
                        "end": round(t - hop_length / 2, 3)
                    })

                # Start new segment
                current_speaker = speaker
                segment_start = t - hop_length / 2
        else:
            # Silence - close current segment
            if current_speaker is not None:
                segments.append({
                    "speaker": current_speaker,
                    "start": round(segment_start, 3),
                    "end": round(t - hop_length / 2, 3)
                })
                current_speaker = None
                segment_start = None

    # Close final segment
    if current_speaker is not None:
        segments.append({
            "speaker": current_speaker,
            "start": round(segment_start, 3),
            "end": round(times[-1] + hop_length / 2, 3)
        })

    # Merge very short gaps between same speaker
    merged = []
    for seg in segments:
        if merged and merged[-1]["speaker"] == seg["speaker"]:
            gap = seg["start"] - merged[-1]["end"]
            if gap < 0.3:  # Merge if gap < 300ms
                merged[-1]["end"] = seg["end"]
                continue
        merged.append(seg)

    return merged


def run_diarization(audio_path: str, num_speakers: int = None) -> dict:
    """
    Run simple speaker diarization.
    """
    print(f"Audio: {audio_path}")

    # Extract features
    start_time = time.time()
    print("\nExtracting features...")

    features, times, duration = extract_features(audio_path)
    speech_mask = detect_speech(audio_path)

    # Ensure mask length matches features
    min_len = min(len(features), len(speech_mask))
    features = features[:min_len]
    times = times[:min_len]
    speech_mask = speech_mask[:min_len]

    print(f"  Duration: {duration:.2f}s")
    print(f"  Frames: {len(features)}")
    print(f"  Speech frames: {np.sum(speech_mask)}")

    # Filter to speech frames only for clustering
    speech_features = features[speech_mask]

    if len(speech_features) < 2:
        print("  Warning: Too little speech detected")
        return {
            "audio_file": os.path.basename(audio_path),
            "duration_seconds": duration,
            "speakers": [],
            "segments": [],
            "metadata": {"error": "insufficient_speech"}
        }

    # Cluster speakers
    print("\nClustering speakers...")
    speech_labels = cluster_speakers(speech_features, num_speakers)

    # Map back to all frames
    all_labels = np.zeros(len(features), dtype=int)
    all_labels[speech_mask] = speech_labels

    # Convert to segments
    segments = labels_to_segments(all_labels, times, speech_mask, 0.25)

    diarize_time = time.time() - start_time
    realtime_factor = diarize_time / duration

    speakers = sorted(list(set(s["speaker"] for s in segments)))

    print(f"\nResults:")
    print(f"  Speakers found: {len(speakers)} ({', '.join(speakers)})")
    print(f"  Segments: {len(segments)}")
    print(f"  Processing time: {diarize_time:.2f}s ({realtime_factor:.2f}x realtime)")

    return {
        "audio_file": os.path.basename(audio_path),
        "duration_seconds": duration,
        "speakers": speakers,
        "segments": segments,
        "metadata": {
            "model": "simple-mfcc-clustering",
            "device": "cpu",
            "diarization_time_seconds": round(diarize_time, 3),
            "realtime_factor": round(realtime_factor, 3)
        }
    }


def main():
    parser = argparse.ArgumentParser(description="Simple speaker diarization (no auth required)")
    parser.add_argument("audio_path", help="Path to audio file")
    parser.add_argument("-o", "--output", help="Output JSON file")
    parser.add_argument("--num-speakers", type=int, help="Number of speakers (auto-detect if not set)")

    args = parser.parse_args()

    if not os.path.exists(args.audio_path):
        print(f"ERROR: File not found: {args.audio_path}")
        sys.exit(1)

    result = run_diarization(args.audio_path, args.num_speakers)

    output_json = json.dumps(result, indent=2)

    if args.output:
        with open(args.output, 'w') as f:
            f.write(output_json)
        print(f"\nResults written to: {args.output}")
    else:
        print("\n" + "=" * 60)
        print(output_json)


if __name__ == "__main__":
    main()
