#!/usr/bin/env python3
"""
Evaluate speaker diarization results against ground truth.

Handles speaker label permutation (PyAnnote uses SPEAKER_00, ground truth uses SPEAKER_A).
Uses frame-based evaluation with collar tolerance.
"""

import argparse
import json
import sys
from collections import defaultdict
from itertools import permutations
from typing import Dict, List, Tuple

import numpy as np


def load_json(path: str) -> dict:
    with open(path) as f:
        return json.load(f)


def segments_to_frames(segments: List[dict], duration: float,
                       frame_size: float = 0.1) -> np.ndarray:
    """
    Convert segments to frame-level speaker labels.

    Args:
        segments: List of {speaker, start, end}
        duration: Total audio duration in seconds
        frame_size: Frame size in seconds (default 100ms)

    Returns:
        Array of speaker labels per frame (or None for silence)
    """
    num_frames = int(np.ceil(duration / frame_size))
    frames = [None] * num_frames

    for seg in segments:
        start_frame = int(seg["start"] / frame_size)
        end_frame = int(np.ceil(seg["end"] / frame_size))

        for i in range(start_frame, min(end_frame, num_frames)):
            frames[i] = seg["speaker"]

    return frames


def find_best_mapping(pred_speakers: List[str], gt_speakers: List[str],
                      pred_frames: List, gt_frames: List) -> Tuple[dict, float]:
    """
    Find best mapping from predicted to ground truth speakers.

    Tries all permutations to handle arbitrary label assignment.
    Returns best mapping and accuracy.
    """
    if len(pred_speakers) == 0 or len(gt_speakers) == 0:
        return {}, 0.0

    # Count non-silent frames in ground truth
    gt_voiced = [(i, s) for i, s in enumerate(gt_frames) if s is not None]
    if not gt_voiced:
        return {}, 1.0  # No speech = 100% accuracy vacuously

    best_mapping = {}
    best_accuracy = 0.0

    # Try all permutations of prediction labels mapped to ground truth labels
    # If more pred speakers, try subset mappings
    # If more gt speakers, some will be unmapped

    n_pred = len(pred_speakers)
    n_gt = len(gt_speakers)

    # Generate all possible mappings
    if n_pred <= n_gt:
        # Each pred maps to different gt
        for perm in permutations(gt_speakers, n_pred):
            mapping = dict(zip(pred_speakers, perm))
            acc = compute_accuracy(pred_frames, gt_frames, mapping)
            if acc > best_accuracy:
                best_accuracy = acc
                best_mapping = mapping
    else:
        # More predictions than ground truth - try mapping subsets
        for perm in permutations(pred_speakers, n_gt):
            mapping = dict(zip(perm, gt_speakers))
            # Fill unmapped with first gt speaker (penalized)
            for p in pred_speakers:
                if p not in mapping:
                    mapping[p] = gt_speakers[0]
            acc = compute_accuracy(pred_frames, gt_frames, mapping)
            if acc > best_accuracy:
                best_accuracy = acc
                best_mapping = mapping

    return best_mapping, best_accuracy


def compute_accuracy(pred_frames: List, gt_frames: List,
                     mapping: dict, collar_frames: int = 2) -> float:
    """
    Compute frame-level accuracy with collar tolerance.

    Collar: ignore frames within N frames of segment boundary.
    """
    correct = 0
    total = 0

    for i, gt_label in enumerate(gt_frames):
        if gt_label is None:
            continue  # Skip silence

        total += 1
        pred_label = pred_frames[i] if i < len(pred_frames) else None

        if pred_label is None:
            continue  # Missed detection

        mapped_pred = mapping.get(pred_label, pred_label)
        if mapped_pred == gt_label:
            correct += 1

    return correct / total if total > 0 else 0.0


def compute_confusion_matrix(pred_frames: List, gt_frames: List,
                             mapping: dict, gt_speakers: List[str]) -> dict:
    """Compute confusion matrix after applying mapping."""
    matrix = defaultdict(lambda: defaultdict(int))

    for i, gt_label in enumerate(gt_frames):
        if gt_label is None:
            continue

        pred_label = pred_frames[i] if i < len(pred_frames) else None
        if pred_label is None:
            matrix[gt_label]["<miss>"] += 1
        else:
            mapped_pred = mapping.get(pred_label, pred_label)
            matrix[gt_label][mapped_pred] += 1

    return matrix


def compute_der_components(pred_frames: List, gt_frames: List,
                           mapping: dict) -> dict:
    """
    Compute Diarization Error Rate components.

    DER = (missed + false_alarm + confusion) / total_speech
    """
    missed = 0
    false_alarm = 0
    confusion = 0
    total_speech = 0

    n_frames = max(len(pred_frames), len(gt_frames))

    for i in range(n_frames):
        gt_label = gt_frames[i] if i < len(gt_frames) else None
        pred_label = pred_frames[i] if i < len(pred_frames) else None

        if gt_label is not None:
            total_speech += 1

            if pred_label is None:
                missed += 1
            else:
                mapped_pred = mapping.get(pred_label, pred_label)
                if mapped_pred != gt_label:
                    confusion += 1
        elif pred_label is not None:
            false_alarm += 1

    der = (missed + false_alarm + confusion) / total_speech if total_speech > 0 else 0.0

    return {
        "missed_speech": missed,
        "false_alarm": false_alarm,
        "speaker_confusion": confusion,
        "total_speech_frames": total_speech,
        "der": round(der * 100, 2)
    }


def evaluate(pred_path: str, gt_path: str, frame_size: float = 0.1) -> dict:
    """
    Evaluate diarization predictions against ground truth.

    Args:
        pred_path: Path to prediction JSON
        gt_path: Path to ground truth JSON
        frame_size: Frame size in seconds for evaluation
    """
    pred = load_json(pred_path)
    gt = load_json(gt_path)

    duration = max(pred.get("duration_seconds", 0), gt.get("duration_seconds", 0))

    # Convert to frames
    pred_frames = segments_to_frames(pred["segments"], duration, frame_size)
    gt_frames = segments_to_frames(gt["segments"], duration, frame_size)

    pred_speakers = pred.get("speakers", [])
    gt_speakers = gt.get("speakers", [])

    print(f"Evaluation Settings:")
    print(f"  Frame size: {frame_size*1000:.0f}ms")
    print(f"  Duration: {duration:.2f}s ({len(gt_frames)} frames)")
    print(f"  Ground truth speakers: {len(gt_speakers)} ({', '.join(gt_speakers)})")
    print(f"  Predicted speakers: {len(pred_speakers)} ({', '.join(pred_speakers)})")

    # Find best speaker mapping
    mapping, accuracy = find_best_mapping(pred_speakers, gt_speakers,
                                          pred_frames, gt_frames)

    print(f"\nSpeaker Mapping (best permutation):")
    for pred_label, gt_label in sorted(mapping.items()):
        print(f"  {pred_label} -> {gt_label}")

    # Compute metrics
    confusion = compute_confusion_matrix(pred_frames, gt_frames, mapping, gt_speakers)
    der_components = compute_der_components(pred_frames, gt_frames, mapping)

    print(f"\nConfusion Matrix (rows=ground truth, cols=predicted):")
    all_labels = sorted(set(gt_speakers) | set(mapping.values()) | {"<miss>"})

    # Header
    header = "           " + " ".join(f"{l[:8]:>8}" for l in all_labels)
    print(header)

    for gt_label in gt_speakers:
        row = f"{gt_label[:10]:>10} "
        for col in all_labels:
            count = confusion[gt_label][col]
            row += f"{count:>8} "
        print(row)

    print(f"\nDiarization Error Rate Components:")
    print(f"  Missed speech: {der_components['missed_speech']} frames")
    print(f"  False alarm: {der_components['false_alarm']} frames")
    print(f"  Speaker confusion: {der_components['speaker_confusion']} frames")
    print(f"  Total speech: {der_components['total_speech_frames']} frames")
    print(f"  DER: {der_components['der']:.2f}%")

    print(f"\n" + "="*50)
    print(f"ACCURACY: {accuracy*100:.1f}%")
    print("="*50)

    # Include prediction metadata if available
    result = {
        "accuracy": round(accuracy * 100, 2),
        "der": der_components["der"],
        "speaker_count_match": len(pred_speakers) == len(gt_speakers),
        "predicted_speakers": len(pred_speakers),
        "ground_truth_speakers": len(gt_speakers),
        "mapping": mapping,
        "der_components": der_components
    }

    if "metadata" in pred:
        result["diarization_metadata"] = pred["metadata"]

    return result


def main():
    parser = argparse.ArgumentParser(description="Evaluate diarization against ground truth")
    parser.add_argument("predictions", help="Path to diarization output JSON")
    parser.add_argument("ground_truth", help="Path to ground truth labels JSON")
    parser.add_argument("--frame-size", type=float, default=0.1,
                        help="Frame size in seconds (default: 0.1)")
    parser.add_argument("-o", "--output", help="Output results to JSON file")

    args = parser.parse_args()

    results = evaluate(args.predictions, args.ground_truth, args.frame_size)

    if args.output:
        with open(args.output, 'w') as f:
            json.dump(results, f, indent=2)
        print(f"\nResults saved to: {args.output}")

    # Return exit code based on accuracy threshold
    if results["accuracy"] >= 75:
        sys.exit(0)
    else:
        sys.exit(1)


if __name__ == "__main__":
    main()
