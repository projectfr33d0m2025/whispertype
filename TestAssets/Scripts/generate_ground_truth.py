#!/usr/bin/env python3
"""
Generate ground truth JSON labels from ElevenLabs script files.

Usage:
    python3 generate_ground_truth.py <script_file> <output_json>
    
Example:
    python3 generate_ground_truth.py two_speakers_script.txt ../Audio/two_speakers_120s_labels.json
"""

import re
import json
import sys
from pathlib import Path
from typing import List, Dict, Tuple


def parse_time(time_str: str) -> float:
    """Convert time string (M:SS or H:MM:SS) to seconds."""
    parts = time_str.strip().split(':')
    if len(parts) == 2:
        minutes, seconds = parts
        return int(minutes) * 60 + float(seconds)
    elif len(parts) == 3:
        hours, minutes, seconds = parts
        return int(hours) * 3600 + int(minutes) * 60 + float(seconds)
    else:
        raise ValueError(f"Invalid time format: {time_str}")


def parse_segment_header(line: str) -> Tuple[str, float, float]:
    """
    Parse a segment header like: [SPEAKER_A | 0:00 - 0:08]
    Returns: (speaker_id, start_time, end_time)
    """
    pattern = r'\[(\w+)\s*\|\s*(\d+:\d+(?:\.\d+)?)\s*-\s*(\d+:\d+(?:\.\d+)?)\]'
    match = re.match(pattern, line.strip())
    if not match:
        return None
    
    speaker = match.group(1)
    start = parse_time(match.group(2))
    end = parse_time(match.group(3))
    
    return speaker, start, end


def parse_script_file(filepath: str) -> Dict:
    """Parse a script file and extract speaker segments."""
    segments = []
    speakers = set()
    current_text = []
    current_segment = None
    
    with open(filepath, 'r', encoding='utf-8') as f:
        for line in f:
            line = line.strip()
            
            # Skip empty lines, comments, and metadata
            if not line or line.startswith('#') or line == '---':
                if current_segment and current_text:
                    current_segment['text'] = ' '.join(current_text).strip()
                    segments.append(current_segment)
                    current_text = []
                    current_segment = None
                continue
            
            # Try to parse as segment header
            parsed = parse_segment_header(line)
            if parsed:
                # Save previous segment
                if current_segment and current_text:
                    current_segment['text'] = ' '.join(current_text).strip()
                    segments.append(current_segment)
                    current_text = []
                
                speaker, start, end = parsed
                speakers.add(speaker)
                current_segment = {
                    'speaker': speaker,
                    'start': start,
                    'end': end
                }
            elif current_segment:
                # Accumulate text for current segment
                current_text.append(line)
    
    # Don't forget the last segment
    if current_segment and current_text:
        current_segment['text'] = ' '.join(current_text).strip()
        segments.append(current_segment)
    
    # Calculate total duration
    total_duration = max(seg['end'] for seg in segments) if segments else 0
    
    return {
        'audio_file': '',  # To be filled in
        'duration_seconds': total_duration,
        'speakers': sorted(list(speakers)),
        'segments': segments
    }


def generate_expected_text(segments: List[Dict]) -> str:
    """Generate expected transcription text from segments."""
    return ' '.join(seg.get('text', '') for seg in segments)


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    
    script_file = sys.argv[1]
    
    if len(sys.argv) >= 3:
        output_file = sys.argv[2]
    else:
        # Default output name
        stem = Path(script_file).stem.replace('_script', '')
        output_file = f"{stem}_labels.json"
    
    print(f"Parsing: {script_file}")
    result = parse_script_file(script_file)
    
    # Set audio filename based on script name
    stem = Path(script_file).stem.replace('_script', '')
    result['audio_file'] = f"{stem}.wav"
    
    # Write JSON output
    with open(output_file, 'w', encoding='utf-8') as f:
        json.dump(result, f, indent=2, ensure_ascii=False)
    
    print(f"Generated: {output_file}")
    print(f"  Duration: {result['duration_seconds']}s")
    print(f"  Speakers: {', '.join(result['speakers'])}")
    print(f"  Segments: {len(result['segments'])}")
    
    # If this is the known_text script, also generate expected.txt
    if 'known_text' in script_file:
        expected_text = generate_expected_text(result['segments'])
        expected_file = output_file.replace('_labels.json', '_expected.txt')
        with open(expected_file, 'w', encoding='utf-8') as f:
            f.write(expected_text)
        print(f"Generated: {expected_file}")


if __name__ == '__main__':
    main()
