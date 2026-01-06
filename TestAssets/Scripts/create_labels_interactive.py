#!/usr/bin/env python3
"""
Interactive tool to create ground truth labels by entering timestamps.

Usage:
    python3 create_labels_interactive.py two_speakers_120s.wav
    
You'll be prompted to enter speaker changes as you listen to the audio.
"""

import json
import sys
from pathlib import Path


def parse_time(time_str: str) -> float:
    """Convert time string (SS, M:SS, or MM:SS) to seconds."""
    time_str = time_str.strip()
    if ':' in time_str:
        parts = time_str.split(':')
        if len(parts) == 2:
            minutes, seconds = parts
            return int(minutes) * 60 + float(seconds)
    return float(time_str)


def format_time(seconds: float) -> str:
    """Format seconds as M:SS."""
    mins = int(seconds // 60)
    secs = seconds % 60
    return f"{mins}:{secs:05.2f}"


def main():
    if len(sys.argv) < 2:
        print("Usage: python3 create_labels_interactive.py <audio_file.wav>")
        print("\nExample: python3 create_labels_interactive.py two_speakers_120s.wav")
        sys.exit(1)
    
    audio_file = sys.argv[1]
    output_file = audio_file.replace('.wav', '_labels.json')
    
    print(f"""
╔══════════════════════════════════════════════════════════════╗
║         Ground Truth Label Creator                           ║
╠══════════════════════════════════════════════════════════════╣
║  Audio: {audio_file:<52} ║
║  Output: {output_file:<51} ║
╚══════════════════════════════════════════════════════════════╝

Instructions:
1. Open the audio file in QuickTime or VLC
2. Play and note when each speaker STARTS talking
3. Enter each segment below

Format: <speaker> <start_time>
  - Speaker: A, B, C, or D (or full name like SPEAKER_A)
  - Time: seconds (e.g., 45) or M:SS (e.g., 1:30)

Example entries:
  A 0
  B 8.5
  A 15
  B 28.2

Type 'done' when finished, 'undo' to remove last entry, 'list' to see entries.
""")

    segments = []
    speakers_seen = set()
    
    while True:
        try:
            entry = input("Enter segment (or done/undo/list): ").strip()
        except EOFError:
            break
            
        if entry.lower() == 'done':
            break
        elif entry.lower() == 'undo':
            if segments:
                removed = segments.pop()
                print(f"  Removed: {removed['speaker']} at {format_time(removed['start'])}")
            else:
                print("  Nothing to undo")
            continue
        elif entry.lower() == 'list':
            if segments:
                print("\nCurrent segments:")
                for i, seg in enumerate(segments):
                    print(f"  {i+1}. {seg['speaker']} from {format_time(seg['start'])}")
                print()
            else:
                print("  No segments yet")
            continue
        elif not entry:
            continue
        
        # Parse entry
        parts = entry.split()
        if len(parts) < 2:
            print("  ⚠️  Format: <speaker> <start_time>  (e.g., 'A 0' or 'B 1:30')")
            continue
        
        speaker_input = parts[0].upper()
        time_input = parts[1]
        
        # Normalize speaker name
        if speaker_input in ['A', 'B', 'C', 'D']:
            speaker = f"SPEAKER_{speaker_input}"
        elif speaker_input.startswith('SPEAKER_'):
            speaker = speaker_input
        else:
            speaker = f"SPEAKER_{speaker_input}"
        
        try:
            start_time = parse_time(time_input)
        except ValueError:
            print(f"  ⚠️  Invalid time format: {time_input}")
            continue
        
        segments.append({'speaker': speaker, 'start': start_time})
        speakers_seen.add(speaker)
        print(f"  ✓ Added: {speaker} at {format_time(start_time)}")
    
    if not segments:
        print("\nNo segments entered. Exiting.")
        sys.exit(1)
    
    # Sort by start time
    segments.sort(key=lambda x: x['start'])
    
    # Calculate end times (each segment ends when the next one starts)
    # Get total duration from ffprobe if available
    try:
        import subprocess
        result = subprocess.run(
            ['ffprobe', '-v', 'quiet', '-show_entries', 'format=duration', 
             '-of', 'default=noprint_wrappers=1:nokey=1', audio_file],
            capture_output=True, text=True
        )
        total_duration = float(result.stdout.strip())
    except:
        # Ask user for duration
        dur_input = input(f"\nEnter total audio duration (seconds or M:SS): ").strip()
        total_duration = parse_time(dur_input)
    
    # Add end times
    for i, seg in enumerate(segments):
        if i < len(segments) - 1:
            seg['end'] = segments[i + 1]['start']
        else:
            seg['end'] = total_duration
    
    # Build output
    output = {
        'audio_file': audio_file,
        'duration_seconds': total_duration,
        'speakers': sorted(list(speakers_seen)),
        'segments': segments
    }
    
    # Write JSON
    with open(output_file, 'w') as f:
        json.dump(output, f, indent=2)
    
    print(f"""
╔══════════════════════════════════════════════════════════════╗
║  ✅ Labels saved to: {output_file:<39} ║
╠══════════════════════════════════════════════════════════════╣
║  Duration: {format_time(total_duration):<49} ║
║  Speakers: {', '.join(sorted(speakers_seen)):<49} ║
║  Segments: {len(segments):<49} ║
╚══════════════════════════════════════════════════════════════╝
""")
    
    # Show summary
    print("Segments:")
    for seg in segments:
        print(f"  {seg['speaker']}: {format_time(seg['start'])} - {format_time(seg['end'])}")


if __name__ == '__main__':
    main()
