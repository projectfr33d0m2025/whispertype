#!/usr/bin/env python3
"""
Generate all mock data files for WhisperType testing.

Usage:
    python3 generate_mock_data.py
    
This creates all JSON mock files in ../Mocks/
"""

import json
from pathlib import Path
from datetime import datetime, timedelta

OUTPUT_DIR = Path(__file__).parent.parent / "Mocks"


def create_sample_transcript():
    """Basic transcript without speaker labels."""
    return {
        "meeting_id": "test-transcript-001",
        "duration_seconds": 180,
        "created_at": datetime.now().isoformat(),
        "segments": [
            {"text": "Good morning everyone. Let's get started with today's meeting.", "start_time": 0.0, "end_time": 4.5},
            {"text": "First item on the agenda is the Q1 budget review.", "start_time": 4.5, "end_time": 8.2},
            {"text": "We've allocated fifty thousand dollars for marketing.", "start_time": 8.2, "end_time": 12.0},
            {"text": "The engineering team has requested two new hires.", "start_time": 12.0, "end_time": 15.5},
            {"text": "We need to discuss the product roadmap for next quarter.", "start_time": 15.5, "end_time": 19.8},
            {"text": "Sarah will prepare the marketing plan by Friday.", "start_time": 19.8, "end_time": 23.5},
            {"text": "John, please send the updated timeline to everyone.", "start_time": 23.5, "end_time": 27.2},
            {"text": "Let's schedule a follow-up meeting for next week.", "start_time": 27.2, "end_time": 31.0},
            {"text": "Thank you all for your time. Meeting adjourned.", "start_time": 31.0, "end_time": 35.0}
        ],
        "full_text": "Good morning everyone. Let's get started with today's meeting. First item on the agenda is the Q1 budget review. We've allocated fifty thousand dollars for marketing. The engineering team has requested two new hires. We need to discuss the product roadmap for next quarter. Sarah will prepare the marketing plan by Friday. John, please send the updated timeline to everyone. Let's schedule a follow-up meeting for next week. Thank you all for your time. Meeting adjourned."
    }


def create_sample_transcript_speakers():
    """Transcript with speaker labels."""
    return {
        "meeting_id": "test-transcript-speakers-001",
        "duration_seconds": 300,
        "created_at": datetime.now().isoformat(),
        "speakers": ["SPEAKER_A", "SPEAKER_B"],
        "speaker_names": {
            "SPEAKER_A": "Michael",
            "SPEAKER_B": "Sarah"
        },
        "segments": [
            {"speaker": "SPEAKER_A", "text": "Good morning Sarah. Thanks for meeting with me today.", "start_time": 0.0, "end_time": 4.0},
            {"speaker": "SPEAKER_B", "text": "Good morning Michael. Happy to discuss the budget.", "start_time": 4.0, "end_time": 7.5},
            {"speaker": "SPEAKER_A", "text": "Let's start with the marketing allocation. We're proposing fifty thousand dollars.", "start_time": 7.5, "end_time": 13.0},
            {"speaker": "SPEAKER_B", "text": "That seems reasonable. I'd suggest allocating fifteen thousand for social media specifically.", "start_time": 13.0, "end_time": 19.0},
            {"speaker": "SPEAKER_A", "text": "Agreed. Now regarding product development, the team wants two senior developers.", "start_time": 19.0, "end_time": 25.0},
            {"speaker": "SPEAKER_B", "text": "What if we start with one senior and one mid-level? That would save forty thousand annually.", "start_time": 25.0, "end_time": 32.0},
            {"speaker": "SPEAKER_A", "text": "Good compromise. I'll discuss with the CTO. Can you prepare the final summary by Friday?", "start_time": 32.0, "end_time": 39.0},
            {"speaker": "SPEAKER_B", "text": "Absolutely. I'll have everything ready by Thursday afternoon.", "start_time": 39.0, "end_time": 44.0}
        ],
        "expected_keywords": ["budget", "marketing", "fifty thousand", "social media", "developers", "CTO", "Friday"],
        "expected_action_items": [
            {"assignee": "Michael", "task": "Discuss hiring plan with CTO", "due": None},
            {"assignee": "Sarah", "task": "Prepare final budget summary", "due": "Friday"}
        ]
    }


def create_sample_diarization():
    """Speaker diarization segments only (no transcript text)."""
    return {
        "audio_file": "two_speakers_120s.wav",
        "duration_seconds": 120.0,
        "num_speakers": 2,
        "speakers": ["SPEAKER_A", "SPEAKER_B"],
        "segments": [
            {"speaker": "SPEAKER_A", "start": 0.0, "end": 8.0},
            {"speaker": "SPEAKER_B", "start": 8.0, "end": 15.0},
            {"speaker": "SPEAKER_A", "start": 15.0, "end": 28.0},
            {"speaker": "SPEAKER_B", "start": 28.0, "end": 42.0},
            {"speaker": "SPEAKER_A", "start": 42.0, "end": 55.0},
            {"speaker": "SPEAKER_B", "start": 55.0, "end": 70.0},
            {"speaker": "SPEAKER_A", "start": 70.0, "end": 82.0},
            {"speaker": "SPEAKER_B", "start": 82.0, "end": 98.0},
            {"speaker": "SPEAKER_A", "start": 98.0, "end": 110.0},
            {"speaker": "SPEAKER_B", "start": 110.0, "end": 120.0}
        ],
        "speaker_stats": {
            "SPEAKER_A": {"total_time": 50.0, "num_segments": 5},
            "SPEAKER_B": {"total_time": 70.0, "num_segments": 5}
        }
    }


def create_sample_meeting_record():
    """Complete meeting record as stored in database."""
    now = datetime.now()
    return {
        "id": "meeting-uuid-12345",
        "title": "Q1 Budget Planning Meeting",
        "created_at": now.isoformat(),
        "updated_at": now.isoformat(),
        "duration_seconds": 300,
        "audio_source": "both",  # "microphone", "system", "both"
        "status": "completed",
        "speakers": [
            {"id": "SPEAKER_A", "name": "Michael", "speaking_time": 120.0, "color": "#4A90D9"},
            {"id": "SPEAKER_B", "name": "Sarah", "speaking_time": 180.0, "color": "#D94A4A"}
        ],
        "summary": {
            "template": "standard_meeting_notes",
            "generated_at": now.isoformat(),
            "content": {
                "overview": "Budget planning meeting between Michael and Sarah to discuss Q1 allocations for marketing and product development.",
                "key_points": [
                    "Marketing budget set at $50,000 with $15,000 allocated to social media",
                    "Product team requesting two new developers",
                    "Compromise reached: one senior developer and one mid-level",
                    "Follow-up summary due by Friday"
                ],
                "action_items": [
                    {"assignee": "Michael", "task": "Discuss hiring compromise with CTO", "due": None, "completed": False},
                    {"assignee": "Sarah", "task": "Prepare final budget summary", "due": "Friday", "completed": False}
                ],
                "decisions": [
                    "$50,000 allocated to marketing",
                    "$15,000 specifically for social media campaigns",
                    "Hire one senior developer and one mid-level developer"
                ]
            }
        },
        "transcript": {
            "segments": [
                {"speaker": "SPEAKER_A", "text": "Good morning Sarah. Thanks for meeting with me today.", "start_time": 0.0, "end_time": 4.0},
                {"speaker": "SPEAKER_B", "text": "Good morning Michael. Happy to discuss the budget.", "start_time": 4.0, "end_time": 7.5}
            ],
            "word_count": 450,
            "confidence": 0.92
        },
        "files": {
            "audio_chunks": ["chunk_001.wav", "chunk_002.wav", "chunk_003.wav"],
            "transcript_json": "transcript.json",
            "summary_md": "summary.md"
        },
        "metadata": {
            "whisper_model": "medium.en",
            "diarization_mode": "pyannote",
            "llm_model": "llama2",
            "processing_time_seconds": 45.2
        }
    }


def create_sample_summary_input():
    """Input format for summarization (what goes to LLM)."""
    return {
        "meeting_id": "test-summary-input-001",
        "template": "standard_meeting_notes",
        "transcript_text": """
Michael: Good morning Sarah. Thanks for meeting with me today to discuss the Q1 budget allocation.

Sarah: Good morning Michael. Of course. I've reviewed the preliminary numbers and have some thoughts to share.

Michael: Great. Let's start with the marketing budget. We're proposing fifty thousand dollars for digital advertising. That's a twenty percent increase from last quarter.

Sarah: I think that's reasonable given our growth targets. However, I'd suggest we allocate at least fifteen thousand specifically for social media campaigns. The ROI on our Instagram ads has been exceptional.

Michael: Agreed. Now, regarding the product development budget. The engineering team is requesting additional headcount. They want to hire two senior developers.

Sarah: Two positions might stretch our budget. What if we start with one senior developer and one mid-level? That would save us approximately forty thousand annually while still adding capacity.

Michael: That's a good compromise. I'll discuss it with the CTO. Can you prepare the final summary by Friday?

Sarah: Absolutely. I'll have the complete breakdown ready for your review by Thursday afternoon.
        """.strip(),
        "speakers": ["Michael", "Sarah"],
        "duration_seconds": 120,
        "variables_to_extract": [
            "summary",
            "key_points",
            "action_items",
            "decisions",
            "follow_ups"
        ]
    }


def create_sample_summary_expected():
    """Expected summary output (Markdown format)."""
    return """# Meeting Summary

## Overview
Budget planning meeting between Michael and Sarah to discuss Q1 allocations.

## Key Points
- Marketing budget approved at $50,000 (20% increase from Q4)
- $15,000 specifically allocated for social media campaigns based on strong Instagram ROI
- Engineering team headcount request modified from two senior developers to one senior + one mid-level
- Compromise saves approximately $40,000 annually while adding capacity

## Action Items
- [ ] **Michael**: Discuss hiring compromise with CTO
- [ ] **Sarah**: Prepare final budget summary (Due: Friday)

## Decisions Made
1. Marketing budget: $50,000 for Q1
2. Social media allocation: $15,000
3. New hires: 1 senior developer + 1 mid-level developer

## Follow-ups
- Final budget summary review on Thursday afternoon
- Follow-up with CTO on hiring plan
"""


def main():
    # Create output directory
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    
    files_to_create = [
        ("sample_transcript.json", create_sample_transcript()),
        ("sample_transcript_speakers.json", create_sample_transcript_speakers()),
        ("sample_diarization.json", create_sample_diarization()),
        ("sample_meeting_record.json", create_sample_meeting_record()),
        ("sample_summary_input.json", create_sample_summary_input()),
    ]
    
    for filename, data in files_to_create:
        filepath = OUTPUT_DIR / filename
        with open(filepath, 'w', encoding='utf-8') as f:
            json.dump(data, f, indent=2, ensure_ascii=False)
        print(f"Created: {filepath}")
    
    # Create markdown file separately
    expected_md = create_sample_summary_expected()
    md_path = OUTPUT_DIR / "sample_summary_expected.md"
    with open(md_path, 'w', encoding='utf-8') as f:
        f.write(expected_md)
    print(f"Created: {md_path}")
    
    print(f"\n✅ All mock data files created in {OUTPUT_DIR}/")


if __name__ == '__main__':
    main()
