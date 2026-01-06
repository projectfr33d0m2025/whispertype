#!/usr/bin/env python3
"""
Parse SRT-style transcript for two speakers.
"""

import json
import re

transcript = """
00:00:00,119 --> 00:00:07,139 [Speaker 0]
[clears throat] Good morning, Sarah. Thanks for meeting with me today to discuss the Q One budget allocation. 
00:00:07,139 --> 00:00:10,559 [Speaker 1]
Good morning, Michael. Of course! 
00:00:10,559 --> 00:00:15,420 [Speaker 1]
I've reviewed the preliminary numbers and have some thoughts to share. 
00:00:15,420 --> 00:00:25,420 [Speaker 0]
Great. Let's start with the marketing budget. We're proposing fifty thousand dollars for digital advertising. That's a twenty percent increase from last quarter. 
00:00:25,420 --> 00:00:40,759 [Speaker 1]
I think that's reasonable, given our growth targets. However, I'd suggest we allocate at least fifteen thousand specifically for social media campaigns. The ROI on our Instagram ads has been exceptional. 
00:00:40,759 --> 00:00:50,939 [Speaker 0]
Agreed. Now, regarding the product development budget, the engineering team is requesting additional headcount. They want to hire two senior developers. 
00:00:50,939 --> 00:01:04,099 [Speaker 1]
Two positions might stretch our budget. What if we start with one senior developer and one mid-level? That would save us approximately forty thousand annually while still adding capacity. 
00:01:04,099 --> 00:01:13,540 [Speaker 0]
That's a good compromise. I'll discuss it with the CTO. What about the customer success team? They've asked for a new CRM system. 
00:01:13,540 --> 00:01:29,659 [Speaker 1]
The CRM request is valid. Our current system is outdated. [sighs] I've gotten quotes from three vendors. Salesforce is the most expensive at thirty thousand, but HubSpot offers similar features for eighteen thousand. 
00:01:29,659 --> 00:01:38,040 [Speaker 0]
Let's go with HubSpot then. That frees up budget for the training program we discussed. Can you prepare a final summary by Friday? 
00:01:38,040 --> 00:01:46,500 [Speaker 1]
Absolutely. I'll have the complete breakdown ready for your review by Thursday afternoon, and we can finalize it before the board meeting.
"""

# Speaker mapping
# Speaker 0 = Michael = SPEAKER_A
# Speaker 1 = Sarah = SPEAKER_B
SPEAKER_MAP = {
    "Speaker 0": "SPEAKER_A",  # Michael
    "Speaker 1": "SPEAKER_B",  # Sarah
}

def parse_time(time_str: str) -> float:
    """Convert HH:MM:SS,mmm to seconds."""
    match = re.match(r'(\d+):(\d+):(\d+),(\d+)', time_str)
    if match:
        hours, mins, secs, ms = match.groups()
        return int(hours) * 3600 + int(mins) * 60 + int(secs) + int(ms) / 1000
    return 0.0

def parse_transcript(text: str) -> list:
    """Parse SRT-style transcript into segments."""
    segments = []
    
    pattern = r'(\d+:\d+:\d+,\d+)\s*-->\s*(\d+:\d+:\d+,\d+)\s*\[([^\]]+)\]\s*\n(.+?)(?=\n\d+:\d+:\d+|\Z)'
    
    matches = re.findall(pattern, text, re.DOTALL)
    
    for start_str, end_str, speaker, text_content in matches:
        start = parse_time(start_str)
        end = parse_time(end_str)
        speaker_id = SPEAKER_MAP.get(speaker, speaker)
        
        segments.append({
            "speaker": speaker_id,
            "start": round(start, 3),
            "end": round(end, 3),
            "text": text_content.strip()
        })
    
    return segments

# Parse
segments = parse_transcript(transcript)

# Get unique speakers and duration
speakers = sorted(set(seg["speaker"] for seg in segments))
duration = max(seg["end"] for seg in segments)

# Build output
output = {
    "audio_file": "two_speakers_120s.wav",
    "duration_seconds": round(duration, 3),
    "speakers": speakers,
    "segments": segments
}

print(json.dumps(output, indent=2))
