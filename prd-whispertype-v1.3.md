# WhisperType v1.3.0 - Product Requirements Document
# Meeting Transcription & Live Subtitles

**Version:** 1.3.0  
**Status:** In Progress  
**Created:** January 6, 2025  
**Revised:** January 24, 2025 (Phase 4 Speaker Diarization deferred to v1.4.0)  
**Author:** Eng Leong  

---

## Executive Summary

WhisperType v1.3.0 introduces **Meeting Transcription** - a major feature that transforms WhisperType from a quick voice-to-text tool into a comprehensive meeting productivity assistant. Users can record meetings up to 90 minutes, view live subtitles during recording, and receive AI-powered summaries after the meeting ends.

> **Note (January 2025):** Speaker Diarization (F4) has been **deferred to v1.4.0** due to implementation complexity (HuggingFace token requirement creates poor UX for consumer apps). The core meeting recording, transcription, summarization, and history features remain fully functional without speaker labels.

### Key Value Propositions

1. **Privacy-First Meeting Recording** - All transcription happens locally, unlike cloud-based competitors (Otter.ai, Fireflies.ai)
2. **Works with Any App** - Generic system audio capture works with Teams, Zoom, Google Meet, or any application
3. **No Subscription Required** - Free alternative to Teams Premium transcript feature
4. **Customizable Summaries** - User-defined templates for different meeting types

---

## Problem Statement

### Current Pain Points

1. **Microsoft Teams transcript is not free** - Requires Teams Premium or specific licensing
2. **In-person meetings have no transcript** - Conference room meetings without video calls lack documentation
3. **Cloud transcription services raise privacy concerns** - Sensitive business discussions sent to third-party servers
4. **Generic summaries don't fit all needs** - Different meeting types require different summary formats

### Target Use Cases

| Use Case | Description |
|----------|-------------|
| **Remote Meetings** | Teams/Zoom calls where user wants private, local transcription |
| **In-Person Meetings** | Conference room discussions captured via laptop microphone |
| **Hybrid Meetings** | Mix of remote and in-person participants |
| **Personal Notes** | Recording personal voice memos or brainstorming sessions |

---

## Goals & Success Metrics

### Goals

| Goal | Description |
|------|-------------|
| **G1** | Enable recording of meetings up to 90 minutes without memory issues |
| **G2** | Provide real-time visual feedback via live subtitles |
| ~~**G3**~~ | ~~Accurately identify and label different speakers~~ **(DEFERRED to v1.4.0)** |
| **G4** | Generate useful, customizable meeting summaries |
| **G5** | Maintain complete privacy with local-first processing |

### Success Metrics

| Metric | Target |
|--------|--------|
| Memory usage during 60-min recording | < 150 MB |
| Transcription accuracy (WER) | Maintain v1.2 levels |
| ~~Speaker diarization accuracy~~ | ~~> 85% correct speaker assignment~~ **(DEFERRED)** |
| End-to-end processing time (60-min meeting) | < 15 minutes |
| User can start recording within | 3 clicks from menu bar |

---

## User Personas

### Primary Persona: Remote Worker

- **Name:** Sarah, Product Manager
- **Context:** Works from home, 4-6 video calls daily
- **Pain:** Can't always take notes during calls, Teams transcript costs extra
- **Need:** Reliable meeting documentation without subscription fees

### Secondary Persona: Team Lead

- **Name:** John, Engineering Manager
- **Context:** Mix of remote and in-person meetings
- **Pain:** In-person meetings have no automatic documentation
- **Need:** Consistent documentation across all meeting types

---

## Feature Specifications

## F1: Extended Recording (90 Minutes)

### F1.1 Overview

Enable continuous audio recording for up to 90 minutes while maintaining low memory footprint through chunked disk storage.

### F1.2 Requirements

| ID | Requirement | Priority |
|----|-------------|----------|
| F1.2.1 | Support recording duration up to 90 minutes | Must |
| F1.2.2 | Memory usage must not exceed 150 MB during recording | Must |
| F1.2.3 | Audio saved to disk in chunks (not held in memory) | Must |
| F1.2.4 | Auto-stop recording at 90-minute limit | Must |
| F1.2.5 | Display warning at 85 minutes (5 min remaining) | Must |
| F1.2.6 | Show elapsed time in menu bar during recording | Must |
| F1.2.7 | Support pause/resume recording | Nice |

### F1.3 Technical Approach

```
Audio Input → Ring Buffer (30s max) → Chunk Writer → Disk
                    ↓
              Audio Stream Bus (Combine Publisher)
                    ↓
         ┌─────────┴─────────┐
         ↓                   ↓
    Live Subtitles      Level Meter
```

**Chunk Strategy:**
- Chunk size: 30 seconds of audio
- Format: WAV (16-bit, 16kHz, mono)
- Storage: `~/Library/Application Support/WhisperType/Meetings/<session-id>/audio/`
- Naming: `chunk_001.wav`, `chunk_002.wav`, etc.

### F1.4 User Flow

```
1. User clicks menu bar → "Start Meeting Recording"
2. Configuration sheet appears:
   - Audio source selection
   - Confirmation of duration limit
3. User clicks "Start Recording"
4. Recording begins:
   - Menu bar shows red indicator + elapsed time
   - Live subtitles window opens (if enabled)
5. At 85 minutes: Warning notification
6. At 90 minutes: Auto-stop + begin processing
7. User can manually stop at any time
```

---

## F2: System Audio Capture

### F2.1 Overview

Capture audio from any application (Microsoft Teams, Zoom, etc.) using macOS ScreenCaptureKit, enabling transcription of remote meeting participants.

### F2.2 Requirements

| ID | Requirement | Priority |
|----|-------------|----------|
| F2.2.1 | Capture system audio from any application | Must |
| F2.2.2 | Support microphone-only recording | Must |
| F2.2.3 | Support system audio-only recording | Must |
| F2.2.4 | Support combined mic + system audio (mixed) | Must |
| F2.2.5 | Mix multiple sources into single audio track | Must |
| F2.2.6 | Handle Screen Recording permission gracefully | Must |
| F2.2.7 | Show audio level meters for each source | Must |

### F2.3 Audio Source Options

| Option | Description | Use Case |
|--------|-------------|----------|
| **Microphone Only** | Records only from selected mic | In-person meetings |
| **System Audio Only** | Records application audio output | Listening to recordings |
| **Both (Mixed)** | Combines mic + system into single track | Video calls (recommended) |

### F2.4 Technical Approach

```swift
// Using ScreenCaptureKit (macOS 13+)
import ScreenCaptureKit

class SystemAudioCapture {
    func startCapture() async throws {
        let config = SCStreamConfiguration()
        config.capturesAudio = true
        config.excludesCurrentProcessAudio = true // Don't capture WhisperType's own audio
        
        // Capture all audio, not tied to specific window
        let filter = SCContentFilter(display: display, excludingWindows: [])
        
        let stream = SCStream(filter: filter, configuration: config, delegate: self)
        try await stream.startCapture()
    }
}
```

### F2.5 Permission Handling

**Required Permission:** Screen Recording

**Flow:**
1. First attempt to capture system audio
2. If permission not granted → Show explanation dialog
3. Guide user to System Settings → Privacy & Security → Screen Recording
4. User enables WhisperType
5. User restarts WhisperType (required by macOS)
6. System audio capture now works

**UI Text:**
```
"System Audio Permission Required"

To record audio from Microsoft Teams and other apps, WhisperType needs 
Screen Recording permission. This is required by macOS for capturing 
application audio.

Your screen content is NOT recorded - only audio is captured.

[Open System Settings]  [Use Microphone Only]
```

---

## F3: Live Subtitles

### F3.1 Overview

Display real-time transcription in a floating window during recording, providing immediate visual feedback of what's being captured.

### F3.2 Requirements

| ID | Requirement | Priority |
|----|-------------|----------|
| F3.2.1 | Show transcribed text in floating window | Must |
| F3.2.2 | Display timestamps for each text segment | Must |
| F3.2.3 | Window must be draggable | Must |
| F3.2.4 | Window must be resizable | Must |
| F3.2.5 | Auto-scroll to latest text | Must |
| F3.2.6 | Window stays on top of other windows | Must |
| F3.2.7 | User can minimize/close window without stopping recording | Must |
| F3.2.8 | Transcription latency < 5 seconds | Must |
| F3.2.9 | Remember window position between sessions | Nice |

### F3.3 UI Specification

```
┌─────────────────────────────────────────────────────────────────┐
│  📝 Live Transcript                    ● REC 00:45:23    [–][×] │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  [00:44:58]                                                      │
│  So I think we should proceed with the budget allocation        │
│  as discussed in the previous meeting.                          │
│                                                                  │
│  [00:45:12]                                                      │
│  The marketing team has confirmed they can work within          │
│  those constraints for Q1.                                       │
│                                                                  │
│  [00:45:23]                                                      │
│  Great, let's move to the next agenda item then. Sarah,         │
│  can you give us an update on the engineering timeline?         │
│                                                                  │
│                                                          ▼       │
└─────────────────────────────────────────────────────────────────┘

Window Specifications:
- Default size: 500w × 300h pixels
- Minimum size: 300w × 150h pixels
- Default position: Bottom-right of screen
- Opacity: 95%
- Font: System font, 14pt
- Timestamp color: Secondary/gray
- Text color: Primary/black (adapts to dark mode)
```

### F3.4 Technical Approach

**Processing Strategy (Two-Pass Approach):**

```
┌─────────────────────────────────────────────────────────────┐
│                    DURING RECORDING                         │
│                                                             │
│  Audio Stream Bus                                           │
│         │                                                   │
│         ├──► Disk Writer (30s chunks to WAV files)          │
│         │                                                   │
│         └──► Live Whisper Processor (60s buffer)            │
│                      │                                      │
│                      ▼                                      │
│              Delayed Subtitles (~60s latency)               │
│                      │                                      │
│                      ▼                                      │
│              Subtitle Window (SwiftUI)                      │
└─────────────────────────────────────────────────────────────┘
                         │
                   Recording Stops
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                    AFTER RECORDING                          │
│                                                             │
│  Load all WAV chunks → Concatenate → Full Transcription     │
│         │                                                   │
│         ▼                                                   │
│  Accurate Final Transcript (same approach as option-space)  │
│         │                                                   │
│         ▼                                                   │
│  Save to transcript.md + Post Notification                  │
└─────────────────────────────────────────────────────────────┘
```

**Live Subtitles (Pass 1 - During Recording):**
- Buffer: 60 seconds of audio (prioritizes accuracy over latency)
- Process: Every 60 seconds (clean chunks, no overlap)
- Vocabulary: Uses VocabularyManager hints for domain-specific terms
- Threading: Background queue, UI updates on main thread
- Trade-off: ~60 second delay for near option-space accuracy

**Final Transcript (Pass 2 - After Recording):**
- Loads all saved WAV chunks and concatenates audio
- Transcribes full audio in segments to preserve timing information
- Groups text into ~30-second blocks with `[HH:MM:SS]` or `[MM:SS]` timestamps
- Uses vocabulary hints from VocabularyManager
- Saves to `transcript.md` and `transcript.txt` in session folder

- Posts `meetingTranscriptReady` notification for UI display

**Window Management Strategy (CRITICAL):**
To prevent "Zombie Object" crashes (EXC_BAD_ACCESS) on macOS, all auxiliary windows (`LiveSubtitleWindow`, `ProcessingIndicatorWindow`, `TranscriptResultWindow`) MUST implement the **Singleton + Persistent State** pattern:
- **Singleton:** The `NSWindow` is created once and reused. It is NEVER deallocated.
- **Persistent State:** The SwitUI view observes a persistent `ObservableObject`.
- **Behavior:** "Closing" a window hides it (`orderOut`) but keeps the object alive. This ensures that pending SwiftUI animations and Combine subscriptions do not trigger crashes during autorelease pool drains.

### F3.5 Content Display Rules

| Element | Display |
|---------|---------|
| **Timestamp** | `[HH:MM:SS]` format, gray color, above text block |
| **Text** | Plain transcribed text, no speaker labels |
| **Paragraphs** | New paragraph every ~30 seconds or on detected pause |
| **Formatting** | No formatting (bold, italic, etc.) in live view |

### F3.6 Window Behavior

| Action | Behavior |
|--------|----------|
| Close button (×) | Hide window, recording continues |
| Minimize button (–) | Minimize to dock, recording continues |
| Menu bar → "Show Live Transcript" | Re-open window (unhide) |
| Recording stops | Window hides (persists in background) |
| App loses focus | Window can stay visible (always on top) |

---

## F4: Speaker Diarization

> ⚠️ **DEFERRED TO v1.4.0**
> 
> Speaker diarization has been deferred due to implementation complexity:
> - PyAnnote requires HuggingFace token, creating poor UX for consumer apps
> - ~500MB+ model downloads required
> - Python subprocess management adds complexity
> - Swift-only approach (spike tested) achieved only 39-58% accuracy - insufficient
> 
> **Impact:** Transcripts will not have speaker labels (e.g., "Speaker A:", "Speaker B:"). Users can still read the full transcript and manually identify speakers based on context.
> 
> **v1.4.0 Plan:** Investigate Core ML speaker embedding models or alternative libraries without HuggingFace dependency.

### F4.1 Overview

Identify and label different speakers in the transcript after the meeting ends. Uses pyannote.audio for accurate diarization with a fallback to basic voice clustering.

### F4.2 Requirements

| ID | Requirement | Priority |
|----|-------------|----------|
| F4.2.1 | Identify distinct speakers in audio | Must |
| F4.2.2 | Label speakers as "Speaker A", "Speaker B", etc. | Must |
| F4.2.3 | Align speaker labels with transcript segments | Must |
| F4.2.4 | Allow user to rename speakers after meeting | Must |
| F4.2.5 | Work without Python/PyAnnote (basic clustering) | Must |
| F4.2.6 | Better accuracy with PyAnnote (optional) | Must |
| F4.2.7 | Support 2-10 speakers | Must |
| F4.2.8 | Processing time < 50% of meeting duration | Nice |

### F4.3 Two-Tier Approach

**Tier 1: Basic Voice Clustering (No Dependencies)**
- Built-in Swift implementation
- Uses audio feature extraction + k-means clustering
- Accuracy: ~70-75%
- Always available

**Tier 2: PyAnnote.audio (Optional, Better Accuracy)**
- Requires Python + pyannote.audio
- Uses neural speaker embeddings
- Accuracy: ~85-90%
- Optional HuggingFace token for best models

### F4.4 PyAnnote Setup Flow

```
┌─────────────────────────────────────────────────────────────────┐
│  Speaker Identification Setup                                    │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  WhisperType can identify who said what in your meetings.       │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │ ○ Basic Mode (Built-in)                                     ││
│  │   • No setup required                                       ││
│  │   • Good accuracy for 2-3 speakers                          ││
│  │   • Works offline                                           ││
│  └─────────────────────────────────────────────────────────────┘│
│                                                                  │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │ ● Enhanced Mode (Recommended)                               ││
│  │   • Better accuracy for 4+ speakers                         ││
│  │   • Requires one-time setup                                 ││
│  │   • Uses pyannote.audio (open source)                       ││
│  │                                                             ││
│  │   Status: ⚠️ Python not detected                            ││
│  │   [Install Python via Homebrew]                             ││
│  │                                                             ││
│  │   Status: ⚠️ HuggingFace token not set (optional)           ││
│  │   [Add Token] - Improves accuracy                           ││
│  └─────────────────────────────────────────────────────────────┘│
│                                                                  │
│                                         [Save]  [Skip for Now]  │
└─────────────────────────────────────────────────────────────────┘
```

### F4.5 Technical Implementation

**Python Detection:**
```swift
func detectPython() -> PythonStatus {
    // Check common locations
    let paths = [
        "/opt/homebrew/bin/python3",      // Homebrew (Apple Silicon)
        "/usr/local/bin/python3",          // Homebrew (Intel)
        "/usr/bin/python3",                // System Python
        "~/.pyenv/shims/python3"           // pyenv
    ]
    
    for path in paths {
        if FileManager.default.fileExists(atPath: path) {
            // Verify version >= 3.8
            return .available(path: path, version: getVersion(path))
        }
    }
    return .notFound
}
```

**PyAnnote Subprocess:**
```swift
func diarize(audioFile: URL) async throws -> [SpeakerSegment] {
    let process = Process()
    process.executableURL = pythonPath
    process.arguments = [
        bundledScriptPath.path,
        "--audio", audioFile.path,
        "--output-format", "json",
        "--min-speakers", "2",
        "--max-speakers", "10"
    ]
    
    // Run and parse JSON output
    ...
}
```

### F4.6 Speaker Name Editing

```
┌─────────────────────────────────────────────────────────────────┐
│  Speakers (3 detected)                                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  👤 Speaker A    →  [Sarah Chen          ] ✏️                   │
│     Speaking time: 18:32 (41%)                                   │
│                                                                  │
│  👤 Speaker B    →  [John Smith          ] ✏️                   │
│     Speaking time: 15:45 (35%)                                   │
│                                                                  │
│  👤 Speaker C    →  [Unknown             ] ✏️                   │
│     Speaking time: 10:43 (24%)                                   │
│                                                                  │
│  💡 Tip: Names are saved and suggested for future meetings      │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## F5: Meeting Summary & Templates

### F5.1 Overview

Generate AI-powered meeting summaries using customizable templates. Supports both local (Ollama) and cloud LLM providers.

### F5.2 Requirements

| ID | Requirement | Priority |
|----|-------------|----------|
| F5.2.1 | Generate summary from transcript | Must |
| F5.2.2 | Support 6 built-in templates | Must |
| F5.2.3 | Support custom user templates | Must |
| F5.2.4 | Extract action items with assignees | Must |
| F5.2.5 | Work with local LLM (Ollama) | Must |
| F5.2.6 | Work with cloud LLM (OpenRouter/OpenAI) | Must |
| F5.2.7 | Hierarchical summarization for long meetings | Must |
| F5.2.8 | Graceful fallback if LLM unavailable | Must |

### F5.3 Built-in Templates

**1. Standard Meeting Notes**
```markdown
## Summary
{{summary}}

## Key Discussion Points
{{key_points}}

## Decisions Made
{{decisions}}

## Action Items
{{action_items}}

## Participants
{{participants}}
```

**2. Action-Focused**
```markdown
## Action Items

{{action_items}}

---
Meeting: {{date}} | Duration: {{duration}}
```

**3. Detailed Minutes**
```markdown
# Meeting Minutes
**Date:** {{date}}  
**Duration:** {{duration}}  
**Participants:** {{participants}}

## Summary
{{summary}}

## Discussion Details
{{key_points}}

## Decisions
{{decisions}}

## Action Items
{{action_items}}

## Full Transcript
{{transcript_short}}

[Full transcript available in meeting history]
```

**4. Executive Brief**
```markdown
## {{date}} Meeting Brief

{{summary}}

**Key Decisions:** {{decisions}}

**Critical Actions:** {{action_items}}
```

**5. Stand-up/Scrum**
```markdown
## Daily Stand-up - {{date}}

### Updates by Participant
{{key_points}}

### Blockers Mentioned
{{blockers}}

### Action Items
{{action_items}}
```

**6. 1-on-1**
```markdown
## 1-on-1 Meeting - {{date}}

### Discussion Topics
{{key_points}}

### Feedback & Notes
{{feedback}}

### Follow-up Items
{{action_items}}

### Next Meeting Topics
{{next_topics}}
```

### F5.4 Template Variables

| Variable | Description |
|----------|-------------|
| `{{summary}}` | 2-3 paragraph summary of the meeting |
| `{{key_points}}` | Bullet list of main discussion points |
| `{{decisions}}` | Decisions that were made |
| `{{action_items}}` | Tasks with assignees and due dates |
| `{{participants}}` | List of speakers (with names if edited) |
| `{{duration}}` | Meeting length (e.g., "45 minutes") |
| `{{date}}` | Meeting date and time |
| `{{transcript}}` | Full transcript text |
| `{{transcript_short}}` | First 500 words of transcript |
| `{{blockers}}` | Blockers mentioned (for stand-ups) |
| `{{feedback}}` | Feedback items (for 1-on-1s) |
| `{{next_topics}}` | Topics for next meeting |

### F5.5 Hierarchical Summarization

For meetings > 30 minutes, use chunked summarization to handle LLM context limits:

```
Full Transcript (60 min = ~9,000 words)
            │
            ▼
┌───────────────────────────────────────────────────┐
│  Chunk 1   │  Chunk 2   │  Chunk 3   │  Chunk 4  │
│  (15 min)  │  (15 min)  │  (15 min)  │  (15 min) │
└───────────────────────────────────────────────────┘
            │
            ▼ (Summarize each chunk)
┌───────────────────────────────────────────────────┐
│ Summary 1  │ Summary 2  │ Summary 3  │ Summary 4 │
│ (200 words)│ (200 words)│ (200 words)│(200 words)│
└───────────────────────────────────────────────────┘
            │
            ▼ (Combine + Apply Template)
┌───────────────────────────────────────────────────┐
│              Final Meeting Summary                 │
│              (Using user's template)               │
└───────────────────────────────────────────────────┘
```

### F5.6 LLM Fallback Strategy

| Condition | Behavior |
|-----------|----------|
| LLM available | Generate full summary with template |
| LLM unavailable | Provide transcript only, show message |
| LLM times out | Retry once, then fallback to transcript |
| Partial failure | Show what was generated + error message |

**Fallback Message:**
```
"Summary generation unavailable. Your full transcript is saved below.

To enable AI summaries:
• Local: Install Ollama and run 'ollama pull llama3.2:3b'
• Cloud: Add your API key in Settings → Processing"
```

---

## F6: Meeting History

### F6.1 Overview

Store and organize past meeting transcripts and summaries in a searchable database with easy access to review and export.

### F6.2 Requirements

| ID | Requirement | Priority |
|----|-------------|----------|
| F6.2.1 | List all past meetings with metadata | Must |
| F6.2.2 | Show meeting title, date, duration, speaker count | Must |
| F6.2.3 | Search meetings by title | Must |
| F6.2.4 | Open and view past meeting details | Must |
| F6.2.5 | Delete individual meetings | Must |
| F6.2.6 | Export meeting to Markdown | Must |
| F6.2.7 | Copy summary/transcript to clipboard | Must |
| F6.2.8 | Show storage usage | Must |
| F6.2.9 | Auto-delete audio after transcription (default) | Must |
| F6.2.10 | Option to keep audio files | Must |
| F6.2.11 | Full-text search on transcripts | Nice |
| F6.2.12 | Re-summarize meeting with different template | Must |

### F6.3 Data Model

```sql
-- SQLite Schema

CREATE TABLE meetings (
    id TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    created_at TIMESTAMP NOT NULL,
    duration_seconds INTEGER NOT NULL,
    audio_source TEXT NOT NULL,  -- 'microphone', 'system', 'both'
    speaker_count INTEGER DEFAULT 0,
    status TEXT NOT NULL,  -- 'recording', 'processing', 'complete', 'error'
    error_message TEXT,
    
    -- File paths (relative to Meetings directory)
    session_directory TEXT NOT NULL,
    transcript_file TEXT,
    summary_file TEXT,
    audio_kept BOOLEAN DEFAULT FALSE,
    
    -- Quick access (denormalized)
    summary_preview TEXT,  -- First 200 chars
    template_used TEXT
);

CREATE TABLE meeting_speakers (
    id TEXT PRIMARY KEY,
    meeting_id TEXT REFERENCES meetings(id) ON DELETE CASCADE,
    speaker_label TEXT NOT NULL,  -- 'Speaker A'
    display_name TEXT,  -- User-edited name
    speaking_duration_seconds INTEGER,
    speaking_percentage REAL
);

CREATE TABLE meeting_action_items (
    id TEXT PRIMARY KEY,
    meeting_id TEXT REFERENCES meetings(id) ON DELETE CASCADE,
    assignee TEXT,
    action_text TEXT NOT NULL,
    due_date TEXT,
    timestamp_seconds INTEGER,  -- When mentioned in meeting
    completed BOOLEAN DEFAULT FALSE
);

CREATE INDEX idx_meetings_created ON meetings(created_at DESC);
CREATE INDEX idx_meetings_title ON meetings(title);
```

### F6.4 File Structure

```
~/Library/Application Support/WhisperType/
├── Meetings/
│   ├── 2025-01-06_103000_<uuid>/
│   │   ├── transcript.md
│   │   ├── transcript.json      # Structured with timestamps + speakers
│   │   ├── summary.md
│   │   ├── metadata.json
│   │   ├── diarization.json     # Speaker segments
│   │   └── audio/               # Only if user opts to keep
│   │       ├── chunk_001.wav
│   │       └── ...
│   │
│   └── 2025-01-05_140000_<uuid>/
│       └── ...
│
├── meetings.db                   # SQLite database
├── Models/                       # Whisper models (existing)
└── vocabulary.json               # Custom vocabulary (existing)
```

### F6.5 History UI

```
┌─────────────────────────────────────────────────────────────────────────┐
│  Meeting History                                     🔍 [Search...]     │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  TODAY                                                                   │
│  ┌────────────────────────────────────────────────────────────────────┐ │
│  │ 🎙️ Q1 Planning Meeting                                             │ │
│  │    45:23 • 3 speakers • 10:30 AM                                   │ │
│  │    Discussed budget allocation for Q1. Key decisions: increase...  │ │
│  │                                                    [Open] [Delete] │ │
│  └────────────────────────────────────────────────────────────────────┘ │
│                                                                          │
│  YESTERDAY                                                               │
│  ┌────────────────────────────────────────────────────────────────────┐ │
│  │ 🎙️ Engineering Standup                                             │ │
│  │    15:42 • 4 speakers • 9:00 AM                                    │ │
│  │    Sprint review and blockers discussion...                        │ │
│  │                                                    [Open] [Delete] │ │
│  └────────────────────────────────────────────────────────────────────┘ │
│                                                                          │
│  LAST WEEK                                                               │
│  ┌────────────────────────────────────────────────────────────────────┐ │
│  │ 🎙️ Client Call - Acme Corp                                         │ │
│  │    62:15 • 2 speakers • Jan 2                                      │ │
│  │                                                    [Open] [Delete] │ │
│  └────────────────────────────────────────────────────────────────────┘ │
│                                                                          │
│  ─────────────────────────────────────────────────────────────────────  │
│  📊 Storage: 45 MB used • 12 meetings               [Manage Storage]   │
└─────────────────────────────────────────────────────────────────────────┘
```

### F6.6 Meeting Detail View

```
┌─────────────────────────────────────────────────────────────────────────┐
│  ← Back    Q1 Planning Meeting                              [Edit Title]│
│            January 6, 2025 • 45:23 • 3 speakers                         │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  [Summary]  [Transcript]  [Action Items]  [Speakers]                    │
│  ═══════════════════════════════════════════════════════════════════    │
│                                                                          │
│  ## Summary                                                              │
│                                                                          │
│  The team discussed Q1 budget allocation and timeline adjustments.      │
│  Key decisions included increasing marketing spend by 15% and           │
│  delaying new hires until the March review meeting.                     │
│                                                                          │
│  ## Key Discussion Points                                                │
│                                                                          │
│  • Budget reallocation from R&D to marketing for Q1 campaign            │
│  • Timeline concerns raised by the engineering team regarding           │
│    the product launch date                                              │
│  • Client feedback on the updated product roadmap                       │
│                                                                          │
│  ## Decisions Made                                                       │
│                                                                          │
│  1. Increase marketing budget by 15% for Q1                             │
│  2. Delay Q2 hiring cycle until March review                            │
│  3. Schedule follow-up meeting with Acme Corp next week                 │
│                                                                          │
│  ─────────────────────────────────────────────────────────────────────  │
│  [Copy Summary]  [Re-Summarize]  [Export as Markdown]                  │
└─────────────────────────────────────────────────────────────────────────┘
```

### F6.7 Re-Summarize Feature

**Purpose:** Allow users to regenerate meeting summaries using a different template without re-transcribing the audio.

**User Flow:**
1. User opens a meeting from Meeting History
2. User clicks "Re-Summarize" button in the Summary tab
3. Sheet/dialog appears with template picker showing all available templates
4. User selects desired template from dropdown
5. User clicks "Regenerate Summary"
6. Processing indicator shows progress
7. Summary is regenerated using the selected template and updated in place
8. Summary file is overwritten with new content
9. Database is updated with new template name

**UI Specification:**

```
┌───────────────────────────────────────────────────────────┐
│  Re-Summarize Meeting                                     │
├───────────────────────────────────────────────────────────┤
│                                                            │
│  Choose a template to regenerate the meeting summary.     │
│                                                            │
│  Template:  [Standard Meeting Notes        ▼]             │
│                                                            │
│  Templates available:                                     │
│  • Standard Meeting Notes                                │
│  • Action-Focused                                         │
│  • Detailed Minutes                                       │
│  • Executive Brief                                        │
│  • Stand-up/Scrum                                         │
│  • 1-on-1                                                 │
│  • [Your Custom Templates]                                │
│                                                            │
│  ⓘ This will regenerate the summary using the existing   │
│     transcript. The original summary will be replaced.    │
│                                                            │
│                              [Cancel]  [Regenerate]       │
└───────────────────────────────────────────────────────────┘
```

**Implementation Notes:**
- Re-summarize uses the existing `transcript.txt` from the meeting session
- No need to reload audio or re-transcribe
- Calls `MeetingSummarizer.summarize()` with the selected template
- Updates `summary.md` file in session directory
- Updates database record with new `template_used` value
- Shows processing indicator during LLM generation
- Handles errors gracefully (e.g., LLM unavailable)
- Button only appears on Summary tab when summary exists



## F7: Audio Quality Monitoring

### F7.1 Overview

Provide real-time feedback on audio quality during recording and annotate transcript with confidence levels.

### F7.2 Requirements

| ID | Requirement | Priority |
|----|-------------|----------|
| F7.2.1 | Show audio level meters during recording | Must |
| F7.2.2 | Warn if audio level is too low | Must |
| F7.2.3 | Warn if audio level is clipping | Must |
| F7.2.4 | Note low-confidence segments in transcript | Must |

### F7.3 Warning Thresholds

| Condition | Threshold | Warning |
|-----------|-----------|---------|
| Too quiet | < -40 dB for > 10 sec | "Audio level is very low. Check your microphone." |
| Clipping | > -1 dB | "Audio is too loud and may be distorted." |
| No audio | Silence > 30 sec | "No audio detected. Is your microphone working?" |

### F7.4 Transcript Confidence

```markdown
## Transcript

[00:00:15] **Sarah:** Hi everyone, thanks for joining today's meeting.

[00:00:23] **John:** Thanks Sarah. So looking at the numbers...

[00:00:45] ⚠️ _[Low confidence - audio unclear]_
**Unknown:** [inaudible] ...the marketing budget...

[00:01:02] **Sarah:** Right, so we need to discuss the allocation.
```

---

## Non-Functional Requirements

### Performance

| Metric | Requirement |
|--------|-------------|
| Recording start latency | < 2 seconds |
| Live subtitle latency | < 5 seconds |
| Memory during 60-min recording | < 150 MB |
| Post-meeting processing (60 min) | < 15 minutes |
| App launch time | < 3 seconds |

### Reliability

| Metric | Requirement |
|--------|-------------|
| Recording failure recovery | Save all chunks captured before failure |
| App crash during recording | Chunks on disk should be recoverable |
| Processing interruption | Allow resume from last checkpoint |

### Privacy

| Aspect | Implementation |
|--------|----------------|
| Audio processing | 100% local (Whisper) |
| Speaker diarization | Local (PyAnnote runs locally) |
| LLM summarization | User choice (local Ollama or cloud) |
| Data storage | Local only, no cloud sync |
| Telemetry | None |

### Compatibility

| Aspect | Requirement |
|--------|-------------|
| macOS version | 13.0 (Ventura) or later |
| Architecture | Apple Silicon (primary), Intel (supported) |
| RAM | 8 GB minimum, 16 GB recommended |
| Disk space | ~500 MB per hour of recording (temporary) |

---

## User Interface Specifications

### Menu Bar States

| State | Icon | Menu Items |
|-------|------|------------|
| Idle | 📊 Waveform | Start Meeting Recording, Settings, History |
| Meeting Recording | 🔴 + Timer | Stop Recording, Show Live Transcript, Pause |
| Processing | ⏳ Spinner | Processing... (progress %), Cancel |
| Error | ⚠️ Warning | View Error, Retry, Dismiss |

### Settings Additions

New "Meetings" tab in Settings:

```
┌─────────────────────────────────────────────────────────────────────────┐
│  Settings                                                               │
├─────────────────────────────────────────────────────────────────────────┤
│  [General] [Processing] [Vocabulary] [App Rules] [Models] [Meetings]   │
│  ═══════════════════════════════════════════════════════════════════    │
│                                                                          │
│  RECORDING                                                               │
│  ─────────────────────────────────────────────────────────────────────  │
│  Default audio source:     [Both (Microphone + System) ▼]               │
│  Show live subtitles:      [✓]                                          │
│  Audio quality warnings:   [✓]                                          │
│                                                                          │
│  SPEAKER IDENTIFICATION                                                  │
│  ─────────────────────────────────────────────────────────────────────  │
│  Mode:                     [Enhanced (PyAnnote) ▼]                       │
│  Python path:              /opt/homebrew/bin/python3  [Detect]          │
│  HuggingFace token:        [••••••••••••]  [Edit]                       │
│  Status:                   ✅ Ready                                      │
│                                                                          │
│  SUMMARY                                                                 │
│  ─────────────────────────────────────────────────────────────────────  │
│  Default template:         [Standard Meeting Notes ▼]                   │
│  [Manage Templates...]                                                  │
│                                                                          │
│  STORAGE                                                                 │
│  ─────────────────────────────────────────────────────────────────────  │
│  Keep audio files:         [ ] (Saves disk space when unchecked)        │
│  Storage used:             234 MB (12 meetings)                         │
│  [Clear All Meeting History...]                                         │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Error Handling

### Error Scenarios

| Scenario | User Message | System Action |
|----------|--------------|---------------|
| Microphone permission denied | "Microphone access required..." | Link to System Settings |
| Screen Recording permission denied | "System audio requires Screen Recording..." | Link to System Settings |
| No audio input detected | "No audio detected. Check microphone." | Continue recording, show warning |
| Disk full during recording | "Not enough disk space. Recording stopped." | Save what was captured |
| Whisper model not loaded | "Please download a model first." | Link to Models settings |
| Python not found (for PyAnnote) | "Python not detected. Using basic mode." | Fall back to basic clustering |
| LLM unavailable | "Summary unavailable. Transcript saved." | Show transcript only |
| Processing timeout | "Processing taking longer than expected." | Option to continue or cancel |

---

## Testing Requirements

### Test Scenarios

| Category | Test Case |
|----------|-----------|
| **Recording** | 90-minute continuous recording without memory leak |
| **Recording** | Mixed audio (mic + system) quality verification |
| **Recording** | Recover chunks after app crash |
| **Live Subtitles** | Latency < 5 seconds consistently |
| **Live Subtitles** | Window responsiveness during long recordings |
| ~~**Diarization**~~ | ~~2-speaker accuracy > 85%~~ **(DEFERRED to v1.4.0)** |
| ~~**Diarization**~~ | ~~4-speaker accuracy > 80%~~ **(DEFERRED to v1.4.0)** |
| ~~**Diarization**~~ | ~~Graceful fallback without Python~~ **(DEFERRED to v1.4.0)** |
| **Summary** | Template variable substitution correct |
| **Summary** | Hierarchical summarization for 60-min meeting |
| **History** | Search by title returns correct results |
| **History** | Delete meeting removes all files |
| **Permissions** | Graceful handling of denied permissions |

---

## Release Criteria

### Must Pass Before Release

- [ ] 90-minute recording completes without crash or memory issue
- [ ] Live subtitles display with < 5 second latency
- ~~[ ] Speaker diarization achieves > 80% accuracy on test set~~ **(DEFERRED to v1.4.0)**
- [ ] All 6 built-in templates generate valid output
- [ ] Meeting history correctly stores and retrieves meetings
- [ ] Export to Markdown produces valid file
- [ ] Works on macOS 13, 14, and 15
- [ ] Works on Apple Silicon and Intel Macs

---

## Future Considerations (Post v1.3.0)

| Feature | Version | Notes |
|---------|---------|-------|
| **Speaker Diarization** | **v1.4.0** | **Deferred from v1.3.0** - Requires better approach (Core ML model or library without HF token) |
| Real-time speaker labels in subtitles | v1.4.0 | Depends on speaker diarization |
| Core ML diarization model | v1.4.0 | Remove Python/HuggingFace dependency |
| Export to DOCX/PDF | v1.4.0 | Deferred |
| App auto-detection | v1.4.0 | Deferred |
| Full-text search | v1.4.0 | Nice-to-have |
| Calendar integration | v2.0.0 | Auto-create meetings from calendar |
| Cloud sync | v2.0.0 | Sync meetings across devices |

---

## Appendix A: Competitive Analysis

| Feature | WhisperType 1.3 | Otter.ai | Fireflies.ai | Teams Premium |
|---------|-----------------|----------|--------------|---------------|
| **Price** | Free | $17/mo | $19/mo | ~$10/user/mo |
| **Privacy** | 100% Local | Cloud | Cloud | Cloud |
| **Offline** | ✅ Yes | ❌ No | ❌ No | ❌ No |
| **Custom Templates** | ✅ Yes | Limited | Limited | ❌ No |
| **Any App Audio** | ✅ Yes | ✅ Yes | ✅ Yes | Teams only |
| **Live Subtitles** | ✅ Yes | ✅ Yes | ❌ No | ✅ Yes |
| **Speaker ID** | ⏳ v1.4.0 | ✅ Yes | ✅ Yes | ✅ Yes |
| **Action Items** | ✅ Yes | ✅ Yes | ✅ Yes | ✅ Yes |

---

## Appendix B: Glossary

| Term | Definition |
|------|------------|
| **Diarization** | The process of identifying and labeling different speakers in audio |
| **PyAnnote** | Open-source Python library for speaker diarization |
| **Chunk** | A segment of audio (typically 30 seconds) saved to disk |
| **ScreenCaptureKit** | macOS framework for capturing screen and audio content |
| **Hierarchical Summarization** | Summarizing long content in stages (chunks → combined) |
| **WER** | Word Error Rate - measure of transcription accuracy |

---

*End of PRD*
