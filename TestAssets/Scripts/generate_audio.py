#!/usr/bin/env python3
"""
Generate audio files using ElevenLabs API.

Usage:
    # Set your API key first:
    export ELEVENLABS_API_KEY="your-api-key"
    
    # Generate a single file:
    python3 generate_audio.py --script two_speakers_script.txt --output ../Audio/two_speakers_120s.wav
    
    # Generate all test audio files:
    python3 generate_audio.py --all

Requirements:
    pip install elevenlabs pydub
"""

import os
import re
import sys
import argparse
from pathlib import Path
from typing import Dict, List, Tuple

try:
    from elevenlabs import generate, save, set_api_key, voices
    from pydub import AudioSegment
    ELEVENLABS_AVAILABLE = True
except ImportError:
    ELEVENLABS_AVAILABLE = False
    print("⚠️  ElevenLabs SDK not installed. Run: pip install elevenlabs pydub")

# Default voice mapping
DEFAULT_VOICES = {
    "SPEAKER_A": "Adam",      # pNInz6obpgDQGcFmaJgB - Male
    "SPEAKER_B": "Rachel",    # 21m00Tcm4TlvDq8ikWAM - Female
    "SPEAKER_C": "Clyde",     # 2EiwWnXFnvU5JabPnv8n - Male (older)
    "SPEAKER_D": "Domi",      # AZnzlk1XvdvUeBnXmlld - Female (younger)
}

OUTPUT_DIR = Path(__file__).parent.parent / "Audio"


def parse_script_segments(filepath: str) -> List[Dict]:
    """Parse script file and extract segments with speaker and text."""
    segments = []
    current_segment = None
    current_text = []
    
    pattern = r'\[(\w+)\s*\|\s*[\d:.]+ - [\d:.]+\]'
    
    with open(filepath, 'r', encoding='utf-8') as f:
        for line in f:
            line = line.strip()
            
            # Skip comments and metadata
            if not line or line.startswith('#') or line == '---':
                if current_segment and current_text:
                    current_segment['text'] = ' '.join(current_text).strip()
                    segments.append(current_segment)
                    current_text = []
                    current_segment = None
                continue
            
            # Check for segment header
            match = re.match(pattern, line)
            if match:
                if current_segment and current_text:
                    current_segment['text'] = ' '.join(current_text).strip()
                    segments.append(current_segment)
                    current_text = []
                
                current_segment = {'speaker': match.group(1)}
            elif current_segment:
                current_text.append(line)
    
    # Last segment
    if current_segment and current_text:
        current_segment['text'] = ' '.join(current_text).strip()
        segments.append(current_segment)
    
    return segments


def generate_segment_audio(text: str, voice: str, output_path: Path) -> bool:
    """Generate audio for a single segment using ElevenLabs."""
    if not ELEVENLABS_AVAILABLE:
        print("❌ ElevenLabs SDK not available")
        return False
    
    try:
        audio = generate(
            text=text,
            voice=voice,
            model="eleven_monolingual_v1"
        )
        save(audio, str(output_path))
        return True
    except Exception as e:
        print(f"❌ Error generating audio: {e}")
        return False


def concatenate_audio_files(audio_files: List[Path], output_path: Path, 
                           target_sample_rate: int = 16000):
    """Concatenate multiple audio files into one."""
    combined = AudioSegment.empty()
    
    for audio_file in audio_files:
        segment = AudioSegment.from_file(str(audio_file))
        combined += segment
    
    # Convert to target format: mono, 16-bit, 16kHz
    combined = combined.set_channels(1)
    combined = combined.set_frame_rate(target_sample_rate)
    combined = combined.set_sample_width(2)  # 16-bit
    
    combined.export(str(output_path), format="wav")
    print(f"✅ Created: {output_path}")


def generate_from_script(script_path: str, output_path: str, 
                        voice_mapping: Dict[str, str] = None):
    """Generate complete audio file from a script."""
    if voice_mapping is None:
        voice_mapping = DEFAULT_VOICES
    
    segments = parse_script_segments(script_path)
    if not segments:
        print(f"❌ No segments found in {script_path}")
        return False
    
    print(f"📝 Found {len(segments)} segments in script")
    
    # Create temp directory for segment audio
    temp_dir = Path(output_path).parent / "temp_segments"
    temp_dir.mkdir(exist_ok=True)
    
    segment_files = []
    for i, segment in enumerate(segments):
        speaker = segment['speaker']
        voice = voice_mapping.get(speaker, "Adam")
        text = segment['text']
        
        segment_file = temp_dir / f"segment_{i:03d}.mp3"
        print(f"  [{i+1}/{len(segments)}] {speaker} ({voice}): {text[:50]}...")
        
        if generate_segment_audio(text, voice, segment_file):
            segment_files.append(segment_file)
        else:
            print(f"❌ Failed to generate segment {i}")
            return False
    
    # Concatenate all segments
    output_path = Path(output_path)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    concatenate_audio_files(segment_files, output_path)
    
    # Cleanup temp files
    for f in segment_files:
        f.unlink()
    temp_dir.rmdir()
    
    return True


def generate_all():
    """Generate all test audio files."""
    scripts_dir = Path(__file__).parent
    
    files_to_generate = [
        ("single_speaker_script.txt", "single_speaker_60s.wav"),
        ("two_speakers_script.txt", "two_speakers_120s.wav"),
        ("four_speakers_script.txt", "four_speakers_300s.wav"),
        ("known_text_script.txt", "known_text_30s.wav"),
    ]
    
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    
    for script_name, output_name in files_to_generate:
        script_path = scripts_dir / script_name
        output_path = OUTPUT_DIR / output_name
        
        if not script_path.exists():
            print(f"⚠️  Script not found: {script_path}")
            continue
        
        print(f"\n🎙️  Generating {output_name}...")
        generate_from_script(str(script_path), str(output_path))


def main():
    parser = argparse.ArgumentParser(description="Generate test audio using ElevenLabs")
    parser.add_argument("--script", help="Path to script file")
    parser.add_argument("--output", help="Output WAV file path")
    parser.add_argument("--all", action="store_true", help="Generate all test files")
    parser.add_argument("--list-voices", action="store_true", help="List available voices")
    
    args = parser.parse_args()
    
    # Check API key
    api_key = os.environ.get("ELEVENLABS_API_KEY")
    if api_key:
        set_api_key(api_key)
    else:
        print("⚠️  ELEVENLABS_API_KEY not set. Run: export ELEVENLABS_API_KEY='your-key'")
    
    if args.list_voices:
        if ELEVENLABS_AVAILABLE and api_key:
            print("Available voices:")
            for voice in voices():
                print(f"  - {voice.name}: {voice.voice_id}")
        return
    
    if args.all:
        generate_all()
    elif args.script and args.output:
        generate_from_script(args.script, args.output)
    else:
        parser.print_help()


if __name__ == "__main__":
    main()
