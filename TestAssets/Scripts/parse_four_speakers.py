#!/usr/bin/env python3
"""
Parse SRT-style transcript with speaker labels to generate ground truth JSON.
"""

import json
import re

# Input transcript (from user)
transcript = """
00:00:00,100 --> 00:00:09,500 [Speaker 0]
Alright, everyone, let's get started with our weekly sprint planning meeting. We have a lot to cover today, so let's dive right in. Lisa, can you start with the product update? 
00:00:09,720 --> 00:00:26,080 [Speaker 1]
Sure. Thanks, Alex. So based on customer feedback from last week, we're prioritizing the notification system redesign. Users have been complaining about missing important alerts. I've written up the requirements, and I think we can ship this in two sprints. 
00:00:26,080 --> 00:00:38,660 [Speaker 2]
I've looked at the technical requirements. The back-end changes are straightforward, but we'll need to update the push notification service. That integration hasn't been touched in over a year, so there might be some surprises. 
00:00:38,880 --> 00:00:55,600 [Speaker 3]
From a design perspective, I've already started on the mock-ups. I'm thinking we go with a notification center approach, similar to what iOS does. Users can see all their notifications in one place and manage their preferences easily. 
00:00:55,600 --> 00:00:59,720 [Speaker 0]
That sounds good, Emma. How long do you estimate for the design work? 
00:00:59,720 --> 00:01:08,190 [Speaker 3]
I should have the high-fidelity mock-ups ready by Wednesday. Then I'll need a day to prepare the specs for handoff to development. 
00:01:08,190 --> 00:01:20,480 [Speaker 2]
That works for me. Once I have the designs, I can start on the front-end implementation. I'm estimating about five days for the UI work, assuming no major changes to the designs. 
00:01:20,480 --> 00:01:33,780 [Speaker 1]
Perfect. Now, there's one more thing. The CEO wants us to add analytics tracking to the notifications. She wants to know which notifications users are engaging with and which ones they're ignoring. 
00:01:33,780 --> 00:01:40,160 [Speaker 0]
That's a reasonable request. Marcus, can you add the analytics events to your implementation estimate? 
00:01:40,160 --> 00:01:49,340 [Speaker 2]
Yeah, that should add about a day. I'll use our existing analytics framework. We just need to define the event names and properties with the data team. 
00:01:49,340 --> 00:01:59,940 [Speaker 3]
Should I include any visual feedback for the analytics, like showing users which notifications are most popular? That could be a nice engagement feature. 
00:01:59,940 --> 00:02:11,540 [Speaker 1]
Let's keep that out of scope for now, but add it to the backlog. I like the idea, but we need to ship the core functionality first. We can always iterate in future sprints. 
00:02:11,540 --> 00:02:21,300 [Speaker 0]
Good call, Lisa. Okay, let's talk about blockers. Marcus, you mentioned the push notification service might have issues. What's your plan there? 
00:02:21,300 --> 00:02:36,079 [Speaker 2]
I'll spend the first day of the sprint doing a technical spike. I'll review the current implementation, check for any deprecated APIs, and document what needs to be updated. If it's a bigger job than expected, I'll flag it immediately. 
00:02:36,080 --> 00:02:44,940 [Speaker 1]
That's smart. Better to know early than to discover problems mid-sprint. Emma, do you have any dependencies on other teams? 
00:02:44,940 --> 00:02:57,960 [Speaker 3]
Just one. I need the updated brand guidelines from the marketing team. They said they'd have them by Monday. If that's delayed, I can start with our current design system and update later. 
00:02:57,960 --> 00:03:06,420 [Speaker 0]
Alright, I'll follow up with marketing to make sure we get those guidelines on time. Any other concerns before we assign story points? 
00:03:06,420 --> 00:03:13,780 [Speaker 2]
One thing: Should we plan for a bug fix day? We still have a few issues from the last release that need attention. 
00:03:13,780 --> 00:03:23,840 [Speaker 1]
Good point. Let's allocate Friday for bug fixes and tech debt. That gives us four days for the notification work and keeps our quality high. 
00:03:23,840 --> 00:03:28,400 [Speaker 0]
Perfect. Let's start the point estimation. Emma, you're up first.
"""

# Speaker mapping (from script)
# Speaker 0 = Alex (PM) = SPEAKER_A
# Speaker 1 = Lisa (Product Owner) = SPEAKER_D  
# Speaker 2 = Marcus (Developer) = SPEAKER_C
# Speaker 3 = Emma (Designer) = SPEAKER_B
SPEAKER_MAP = {
    "Speaker 0": "SPEAKER_A",  # Alex - PM
    "Speaker 1": "SPEAKER_D",  # Lisa - Product Owner
    "Speaker 2": "SPEAKER_C",  # Marcus - Developer
    "Speaker 3": "SPEAKER_B",  # Emma - Designer
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
    
    # Pattern: HH:MM:SS,mmm --> HH:MM:SS,mmm [Speaker N]
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
    "audio_file": "four_speakers_300s.wav",
    "duration_seconds": round(duration, 3),
    "speakers": speakers,
    "segments": segments
}

# Print JSON
print(json.dumps(output, indent=2))
