# WhisperType v1.3.0 - Development Tasks (Final)

**Version:** 1.3.0  
**Status:** Planning  
**Created:** January 6, 2025  
**Revised:** January 6, 2025 (v3 - Added User Acceptance Tests)  
**Estimated Duration:** 10-12 weeks  

---

## Overview

This document breaks down the v1.3.0 Meeting Transcription feature into development phases. Each phase is **independently testable and validated** with:

- ✅ Clear validation criteria with measurable targets
- ✅ Demo milestone for tangible proof
- ✅ Automated tests where possible, manual tests clearly marked
- ✅ **User Acceptance Tests (UAT)** - Step-by-step manual testing guide
- ✅ Test artifacts with expected outputs

---

## Phase Dependency Graph

```
                    ┌─────────────────────────────────────────────────────────┐
                    │                    PHASE 1                              │
                    │              Foundation & Architecture                   │
                    │        (includes Test Artifacts creation)               │
                    └─────────────────────────┬───────────────────────────────┘
                                              │
              ┌───────────────┬───────────────┼───────────────┬───────────────┐
              ▼               ▼               ▼               ▼               ▼
       ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐
       │ PHASE 2  │    │ PHASE 3  │    │ PHASE 4  │    │ PHASE 5  │    │ PHASE 6  │
       │ System   │    │  Live    │    │ Speaker  │    │   LLM    │    │ History  │
       │  Audio   │    │ Subtitles│    │ Diarizn. │    │ Summary  │    │ Storage  │
       └────┬─────┘    └────┬─────┘    └────┬─────┘    └────┬─────┘    └────┬─────┘
            └───────────────┴───────────────┴───────┬───────┴───────────────┘
                                                    ▼
                                            ┌──────────────┐
                                            │   PHASE 7    │
                                            │ Integration  │
                                            └──────┬───────┘
                                                   ▼
                                            ┌──────────────┐
                                            │   PHASE 8    │
                                            │   Release    │
                                            └──────────────┘
```

### Phase Summary

| Phase | Name | Duration | Dependencies | Parallel With |
|-------|------|----------|--------------|---------------|
| 1 | Foundation & Architecture | 2-3 weeks | None | - |
| 2 | System Audio Capture | 1-2 weeks | Phase 1 | 3, 4, 5, 6 |
| 3 | Live Subtitles | 1-2 weeks | Phase 1 | 2, 4, 5, 6 |
| 4 | Speaker Diarization | 2 weeks | Phase 1 | 2, 3, 5, 6 |
| 5 | LLM Summarization | 1-2 weeks | Phase 1 | 2, 3, 4, 6 |
| 6 | Meeting History & Storage | 1-2 weeks | Phase 1 | 2, 3, 4, 5 |
| 7 | Integration & Polish | 1-2 weeks | 1-6 | - |
| 8 | Testing & Release | 1 week | 7 | - |

---

## Phase 1: Foundation & Architecture
**Goal:** Build streaming audio architecture AND create all test artifacts  
**Duration:** 2-3 weeks  
**Dependencies:** None

### Phase 1 Validation Criteria

| Criteria | Target | Test Type | How to Verify |
|----------|--------|-----------|---------------|
| Recording works | ✅ | Automated | Unit test: record 2 min → 4 chunks |
| Memory bounded | < 100 MB | Automated | XCTest memory assertion |
| Chunks valid WAV | ✅ | Automated | Validate WAV header, duration 28-32s |
| State machine | All transitions | Automated | Unit tests for all paths |
| Test artifacts exist | All files | Automated | File existence checks |

### Phase 1 Demo Milestone

**Demo:** "Record 5 minutes of microphone audio"
```
1. Run: MeetingRecorderTests.testFiveMinuteRecording()
2. Assert: 10 chunks created in temp directory
3. Assert: Each chunk is 28-32 seconds (allowing variance)
4. Assert: Peak memory during test < 100 MB
5. Assert: All chunks pass WAV validation
```

---

### 1.1 Project Setup & Test Artifacts

- [ ] **1.1.1** Create `Meeting/` directory structure
- [ ] **1.1.2** Update `Constants.swift` with meeting constants
- [ ] **1.1.3** Update `Info.plist` with Screen Recording description
- [ ] **1.1.4** Update version to 1.3.0

**Test Artifacts (REQUIRED for all phases):**

> **📁 Setup Scripts Available:** `TestAssets/Scripts/`
> 
> Run `./setup_test_assets.sh --auto` to generate all auto-generatable files.
> For ElevenLabs audio: `export ELEVENLABS_API_KEY="..." && ./setup_test_assets.sh --elevenlabs`

- [ ] **1.1.5** Create `TestAssets/` directory structure
- [ ] **1.1.6** Run setup script for auto-generated files:
  ```bash
  cd TestAssets/Scripts
  ./setup_test_assets.sh --auto
  ```
  This generates:
  - `silence_30s.wav` - ffmpeg generated
  - `tone_1khz_30s.wav` - ffmpeg generated  
  - `low_volume_30s.wav` - ffmpeg generated
  - `clipping_30s.wav` - ffmpeg generated
  - `known_text_30s.wav` - macOS TTS (or ElevenLabs)
  - All mock JSON files

- [ ] **1.1.7** Generate ElevenLabs audio files (recommended):
  ```bash
  # Set your API key
  export ELEVENLABS_API_KEY="your-key-from-elevenlabs.io"
  
  # Generate all speaker audio files
  ./setup_test_assets.sh --elevenlabs
  ```
  This generates (with automatic ground truth labels):
  ```
  TestAssets/Audio/
  ├── single_speaker_60s.wav             # 1 voice (Adam)
  ├── two_speakers_120s.wav              # 2 voices (Adam, Rachel)
  ├── two_speakers_120s_labels.json      # Auto-generated from script
  ├── four_speakers_300s.wav             # 4 voices (Adam, Rachel, Clyde, Domi)
  ├── four_speakers_300s_labels.json     # Auto-generated from script
  ├── known_text_30s.wav                 # For WER testing
  └── known_text_30s_expected.txt        # Expected transcription
  ```

- [ ] **1.1.8** Verify mock data files exist:
  ```
  TestAssets/Mocks/
  ├── sample_transcript.json             # Transcript without speakers
  ├── sample_transcript_speakers.json    # Transcript with speakers
  ├── sample_diarization.json            # Speaker segments only
  ├── sample_meeting_record.json         # Complete meeting record
  ├── sample_summary_input.json          # Input for summarization
  └── sample_summary_expected.md         # Expected summary structure
  ```

- [ ] **1.1.9** Ground truth labels (auto-generated from scripts):
  ```json
  // two_speakers_120s_labels.json (auto-generated)
  {
    "audio_file": "two_speakers_120s.wav",
    "duration_seconds": 120,
    "speakers": ["SPEAKER_A", "SPEAKER_B"],
    "segments": [
      {"speaker": "SPEAKER_A", "start": 0.0, "end": 8.0, "text": "Good morning..."},
      {"speaker": "SPEAKER_B", "start": 8.0, "end": 15.0, "text": "Good morning..."},
      ...
    ]
  }
  ```

- [ ] **1.1.10** Document test artifact sources:
  | File | Source | License |
  |------|--------|---------|
  | silence/tone WAVs | ffmpeg generated | N/A |
  | Speaker audio | ElevenLabs TTS | ElevenLabs ToS |
  | Mock JSON | Generated scripts | N/A |

### 1.2 Audio Stream Bus

- [ ] **1.2.1** Create `AudioStreamBus.swift`
- [ ] **1.2.2** Define `AudioChunk` model
- [ ] **1.2.3** Define `AudioLevel` model
- [ ] **1.2.4** Write unit tests (AUTOMATED):
  - [ ] `testSingleSubscriberReceivesChunks`
  - [ ] `testMultipleSubscribersReceiveSameChunks`
  - [ ] `testUnsubscribeStopsReceiving`
  - [ ] `testLevelPublishing`

### 1.3 Chunked Disk Writer

- [ ] **1.3.1** Create `ChunkedDiskWriter.swift`
- [ ] **1.3.2** Implement WAV file writing (16-bit, 16kHz, mono)
- [ ] **1.3.3** Implement chunk naming (`chunk_001.wav`)
- [ ] **1.3.4** Implement session cleanup
- [ ] **1.3.5** Create `WAVValidator.swift` utility
- [ ] **1.3.6** Write unit tests (AUTOMATED):
  - [ ] `testChunkWritingProducesValidWAV` - validate header, sample rate
  - [ ] `testChunkDurationIsCorrect` - 28-32 seconds
  - [ ] `testSessionFinalizationReturnsAllChunkURLs`
  - [ ] `testCleanupRemovesAllFiles`

### 1.4 Meeting Session Model

- [ ] **1.4.1** Create `MeetingSession.swift`
- [ ] **1.4.2** Define `MeetingState` enum
- [ ] **1.4.3** Define `ProcessingStage` enum
- [ ] **1.4.4** Define `AudioSource` enum
- [ ] **1.4.5** Write unit tests (AUTOMATED):
  - [ ] `testAllStateTransitions`
  - [ ] `testInvalidTransitionsThrow`

### 1.5 Meeting Recorder (Microphone Only)

- [ ] **1.5.1** Create `MeetingRecorder.swift`
- [ ] **1.5.2** Implement ring buffer (30s max)
- [ ] **1.5.3** Implement chunk emission every 30 seconds
- [ ] **1.5.4** Integrate with existing `AudioRecorder`
- [ ] **1.5.5** Implement duration tracking
- [ ] **1.5.6** Implement 90-minute auto-stop
- [ ] **1.5.7** Implement 85-minute warning
- [ ] **1.5.8** Write tests:
  - [ ] `testTwoMinuteRecordingProducesFourChunks` (AUTOMATED)
  - [ ] `testMemoryStaysUnder100MB` (AUTOMATED with XCTMemoryMetric)
  - [ ] `testNinetyMinuteLimitTriggersAutoStop` (AUTOMATED, simulated)
  - [ ] `testCancelCleansUpFiles` (AUTOMATED)

### 1.6 Meeting Coordinator (Basic)

- [ ] **1.6.1** Create `MeetingCoordinator.swift`
- [ ] **1.6.2** Implement state machine
- [ ] **1.6.3** Implement background task management
- [ ] **1.6.4** Add to AppCoordinator
- [ ] **1.6.5** Write unit tests (AUTOMATED):
  - [ ] `testStateTransitionIdleToRecording`
  - [ ] `testStateTransitionRecordingToComplete`
  - [ ] `testCancellationFromAnyState`
  - [ ] `testErrorStateHandling`

### 1.7 Phase 1 Validation Checklist

- [ ] **1.7.1** All unit tests pass (`xcodebuild test`)
- [ ] **1.7.2** All test artifacts exist and are valid
- [ ] **1.7.3** Memory test confirms < 100 MB
- [ ] **1.7.4** WAV validation passes for all chunks
- [ ] **1.7.5** 5-minute demo recording successful

---

### 1.8 Phase 1 User Acceptance Tests (UAT)

**Time Required:** ~15 minutes

#### UAT 1.1: Basic Recording Test
| Step | Action | Expected Result | ✓ |
|------|--------|-----------------|---|
| 1 | Launch WhisperType | App starts without errors | [ ] |
| 2 | Click menu bar icon → "Start Meeting Recording" | Recording dialog appears | [ ] |
| 3 | Select "Microphone" as audio source | Option is selected | [ ] |
| 4 | Click "Start Recording" | Recording begins, timer shows 00:00 | [ ] |
| 5 | Speak into microphone for 2 minutes | Timer advances, audio level meter moves | [ ] |
| 6 | Click "Stop Recording" | Recording stops | [ ] |
| 7 | Open Finder → Go to `~/Library/Application Support/WhisperType/Meetings/` | Session folder exists with today's date | [ ] |
| 8 | Open the session folder → `audio/` subfolder | 4 chunk files exist (chunk_001.wav to chunk_004.wav) | [ ] |
| 9 | Double-click chunk_002.wav to play | Your voice is audible, ~30 seconds duration | [ ] |

#### UAT 1.2: Extended Recording Test (5 minutes)
| Step | Action | Expected Result | ✓ |
|------|--------|-----------------|---|
| 1 | Start a new meeting recording | Recording begins | [ ] |
| 2 | Open Activity Monitor, find WhisperType | Note initial memory usage | [ ] |
| 3 | Speak or play audio for 5 minutes | Timer reaches 05:00 | [ ] |
| 4 | Check Activity Monitor periodically | Memory stays under 100 MB | [ ] |
| 5 | Stop recording | Recording stops normally | [ ] |
| 6 | Check session folder | 10 chunk files exist | [ ] |
| 7 | Verify chunk durations | Each chunk is approximately 30 seconds | [ ] |

#### UAT 1.3: Cancel Recording Test
| Step | Action | Expected Result | ✓ |
|------|--------|-----------------|---|
| 1 | Start a new meeting recording | Recording begins | [ ] |
| 2 | Speak for 1 minute | Timer shows ~01:00, chunks being created | [ ] |
| 3 | Click "Cancel Recording" | Confirmation dialog appears | [ ] |
| 4 | Confirm cancellation | Recording stops | [ ] |
| 5 | Check Meetings folder | No new session folder created (or folder is empty/deleted) | [ ] |

#### UAT 1.4: Duration Display Test
| Step | Action | Expected Result | ✓ |
|------|--------|-----------------|---|
| 1 | Start recording | Timer shows 00:00 | [ ] |
| 2 | Wait 30 seconds | Timer shows ~00:30 | [ ] |
| 3 | Wait another 30 seconds | Timer shows ~01:00 | [ ] |
| 4 | Menu bar shows recording indicator | Red dot or recording icon visible | [ ] |

**Phase 1 UAT Sign-off:**
- [ ] All UAT tests passed
- [ ] Tester: _________________
- [ ] Date: _________________

**Phase 1 Exit Criteria:** All 1.7.x and 1.8 UAT items checked ✅

---

## Phase 2: System Audio Capture
**Goal:** Capture audio from any application  
**Duration:** 1-2 weeks  
**Dependencies:** Phase 1  
**Can Parallel With:** Phases 3, 4, 5, 6

### Phase 2 Validation Criteria

| Criteria | Target | Test Type | How to Verify |
|----------|--------|-----------|---------------|
| System audio captured | ✅ | Automated | Play test file, verify capture |
| Audio quality | Correlation > 0.8 | Automated | Compare waveforms |
| Mixing works | ✅ | Automated | Verify both sources in output |
| Permissions handled | ✅ | Manual | Test denied/granted states |

### Phase 2 Demo Milestone

**Demo:** "Capture audio playing from another process"
```
1. Use afplay to play tone_1khz_30s.wav in background
2. Start system audio capture for 5 seconds
3. Stop capture
4. Verify: Captured audio contains 1kHz tone
5. Verify: Cross-correlation with original > 0.8
```

---

### 2.1 ScreenCaptureKit Integration

- [ ] **2.1.1** Create `SystemAudioCapture.swift`
- [ ] **2.1.2** Implement `SCStreamDelegate`
- [ ] **2.1.3** Configure audio-only capture
- [ ] **2.1.4** Handle permission states
- [ ] **2.1.5** Write tests:
  - [ ] `testPermissionCheckReturnsCorrectState` (AUTOMATED)
  - [ ] `testCaptureStartsAndStopsWithoutCrash` (AUTOMATED)
  - [ ] `testAudioSamplesReceivedInDelegate` (AUTOMATED)

### 2.2 Audio Mixing

- [ ] **2.2.1** Create `AudioMixer.swift`
- [ ] **2.2.2** Implement sample-level mixing
- [ ] **2.2.3** Implement normalization (prevent clipping)
- [ ] **2.2.4** Handle sample rate differences
- [ ] **2.2.5** Write unit tests (AUTOMATED):
  - [ ] `testMixingTwoEqualLengthArrays`
  - [ ] `testMixingDifferentLengthArrays`
  - [ ] `testNormalizationPreventsClipping`
  - [ ] `testMixingWithTestAudioFiles`

### 2.3 Integration with Meeting Recorder

- [ ] **2.3.1** Add system audio source to `MeetingRecorder`
- [ ] **2.3.2** Implement source selection logic
- [ ] **2.3.3** Update audio level reporting
- [ ] **2.3.4** Write integration tests:
  - [ ] `testMicrophoneOnlyRecording` (AUTOMATED)
  - [ ] `testSystemOnlyRecordingWithAfplay` (AUTOMATED - plays test file)
  - [ ] `testMixedRecording` (AUTOMATED)

### 2.4 Audio Quality Validation

- [ ] **2.4.1** Create `AudioQualityValidator.swift`
- [ ] **2.4.2** Implement cross-correlation comparison
- [ ] **2.4.3** Write test:
  - [ ] `testCapturedAudioMatchesOriginal` - correlation > 0.8

### 2.5 Permission UI

- [ ] **2.5.1** Create permission request dialog
- [ ] **2.5.2** Handle permission change detection
- [ ] **2.5.3** Add permission status to Settings
- [ ] **2.5.4** Write tests (MANUAL):
  - [ ] Test dialog appears when permission needed
  - [ ] Test "Open Settings" button works
  - [ ] Test fallback to mic-only works

### 2.6 Phase 2 Validation Checklist

- [ ] **2.6.1** All automated tests pass
- [ ] **2.6.2** System audio capture demo successful
- [ ] **2.6.3** Audio quality correlation > 0.8
- [ ] **2.6.4** Manual permission tests pass
- [ ] **2.6.5** Mixed recording test successful

---

### 2.7 Phase 2 User Acceptance Tests (UAT)

**Time Required:** ~20 minutes

**Prerequisites:**
- Screen Recording permission NOT yet granted (for permission tests)
- A YouTube video or audio file ready to play

#### UAT 2.1: Permission Request Test
| Step | Action | Expected Result | ✓ |
|------|--------|-----------------|---|
| 1 | Start meeting recording | Recording dialog appears | [ ] |
| 2 | Select "System Audio" or "Both" | Permission warning shown (if not granted) | [ ] |
| 3 | Click "Request Permission" | macOS permission dialog appears | [ ] |
| 4 | Click "Open System Settings" | System Settings opens to Privacy & Security | [ ] |
| 5 | Enable Screen Recording for WhisperType | Permission granted | [ ] |
| 6 | Restart WhisperType | App restarts | [ ] |
| 7 | Check Settings → Permissions | Screen Recording shows "Granted" | [ ] |

#### UAT 2.2: System Audio Only Recording (YouTube)
| Step | Action | Expected Result | ✓ |
|------|--------|-----------------|---|
| 1 | Open Safari/Chrome and navigate to YouTube | YouTube loads | [ ] |
| 2 | Find a video with clear speech (e.g., news clip) | Video ready | [ ] |
| 3 | Start meeting recording with "System Audio" source | Recording begins | [ ] |
| 4 | Play the YouTube video for 30 seconds | Video plays, WhisperType shows system audio level | [ ] |
| 5 | Stop recording | Recording stops | [ ] |
| 6 | Navigate to session folder → audio/ | chunk_001.wav exists | [ ] |
| 7 | Play chunk_001.wav | YouTube video audio is clearly audible | [ ] |

#### UAT 2.3: Mixed Recording (Microphone + System)
| Step | Action | Expected Result | ✓ |
|------|--------|-----------------|---|
| 1 | Open a YouTube video (don't play yet) | Video ready | [ ] |
| 2 | Start meeting recording with "Both" source | Recording begins, two level meters shown | [ ] |
| 3 | Play the YouTube video | System audio level meter moves | [ ] |
| 4 | Speak into microphone: "This is a microphone test" | Microphone level meter moves | [ ] |
| 5 | Continue for 30 seconds with both sources | Both meters active | [ ] |
| 6 | Stop recording | Recording stops | [ ] |
| 7 | Play chunk_001.wav | BOTH YouTube audio AND your voice audible | [ ] |

#### UAT 2.4: Permission Denied Fallback
| Step | Action | Expected Result | ✓ |
|------|--------|-----------------|---|
| 1 | Go to System Settings → Privacy → Screen Recording | Settings open | [ ] |
| 2 | Disable WhisperType's Screen Recording permission | Permission revoked | [ ] |
| 3 | Restart WhisperType | App restarts | [ ] |
| 4 | Try to start recording with "System Audio" | Warning message shown | [ ] |
| 5 | Click "Use Microphone Only" | Falls back to microphone recording | [ ] |
| 6 | Verify microphone recording works | Recording proceeds normally | [ ] |

#### UAT 2.5: Teams/Zoom Audio Capture (Optional)
| Step | Action | Expected Result | ✓ |
|------|--------|-----------------|---|
| 1 | Join a Microsoft Teams or Zoom meeting | Meeting active | [ ] |
| 2 | Start WhisperType recording with "System Audio" | Recording begins | [ ] |
| 3 | Let other participants speak for 30 seconds | System audio captured | [ ] |
| 4 | Stop recording | Recording stops | [ ] |
| 5 | Play the chunk file | Meeting participants' voices audible | [ ] |

**Phase 2 UAT Sign-off:**
- [ ] All UAT tests passed
- [ ] Tester: _________________
- [ ] Date: _________________

**Phase 2 Exit Criteria:** All 2.6.x and 2.7 UAT items checked ✅

---

## Phase 3: Live Subtitles
**Goal:** Display real-time transcription during recording  
**Duration:** 1-2 weeks  
**Dependencies:** Phase 1  
**Can Parallel With:** Phases 2, 4, 5, 6

### Phase 3 Validation Criteria

| Criteria | Target | Test Type | How to Verify |
|----------|--------|-----------|---------------|
| Transcription works | ✅ | Automated | known_text test |
| Transcription accuracy | WER < 20% | Automated | Compare to expected |
| Latency | < 5 seconds | Automated | Timestamp comparison |
| Window functional | ✅ | Manual | UI interaction tests |

### Phase 3 Demo Milestone

**Demo:** "Live subtitles with measured latency"
```
1. Play known_text_30s.wav through microphone input (loopback)
2. Start recording with live subtitles enabled
3. Measure: Time from audio start to first transcript update
4. After completion, compare transcript to known_text_30s_expected.txt
5. Assert: Latency < 5 seconds
6. Assert: WER (Word Error Rate) < 20%
```

---

### 3.1 Streaming Whisper Processor

- [ ] **3.1.1** Create `StreamingWhisperProcessor.swift`
- [ ] **3.1.2** Implement 10-second buffer accumulation
- [ ] **3.1.3** Implement context overlap (last 50 words)
- [ ] **3.1.4** Implement background processing queue
- [ ] **3.1.5** Define `TranscriptUpdate` model
- [ ] **3.1.6** Write tests:
  - [ ] `testBufferAccumulationTiming` (AUTOMATED)
  - [ ] `testContextIsPassedToWhisper` (AUTOMATED)
  - [ ] `testUpdatesArePublished` (AUTOMATED)
  - [ ] `testWithKnownTextAudio` (AUTOMATED - uses test file)

### 3.2 Latency Measurement

- [ ] **3.2.1** Create `LatencyMeasurement.swift` utility
- [ ] **3.2.2** Record timestamp when audio chunk sent
- [ ] **3.2.3** Record timestamp when transcript received
- [ ] **3.2.4** Write test:
  - [ ] `testLatencyUnderFiveSeconds` (AUTOMATED)

### 3.3 Transcription Accuracy

- [ ] **3.3.1** Create `WERCalculator.swift` (Word Error Rate)
- [ ] **3.3.2** Implement Levenshtein distance for WER
- [ ] **3.3.3** Write test:
  - [ ] `testWERUnderTwentyPercent` (AUTOMATED - uses known_text files)

### 3.4 Partial Transcript Store

- [ ] **3.4.1** Create `PartialTranscriptStore.swift`
- [ ] **3.4.2** Implement in-memory storage
- [ ] **3.4.3** Implement JSON persistence
- [ ] **3.4.4** Write unit tests (AUTOMATED):
  - [ ] `testAppendAddsEntry`
  - [ ] `testGetAllReturnsInOrder`
  - [ ] `testClearRemovesAll`
  - [ ] `testJSONSaveLoadRoundtrip`

### 3.5 Live Subtitle Window

- [ ] **3.5.1** Create `LiveSubtitleWindow.swift`
- [ ] **3.5.2** Create `LiveSubtitleView.swift`
- [ ] **3.5.3** Create `SubtitleEntryView.swift`
- [ ] **3.5.4** Implement auto-scroll behavior
- [ ] **3.5.5** Implement position persistence
- [ ] **3.5.6** Write UI tests (MANUAL):
  - [ ] Window opens at saved position
  - [ ] Window is draggable
  - [ ] Window is resizable
  - [ ] Auto-scroll to bottom works
  - [ ] Scroll pauses when user scrolls up

### 3.6 Window Controls

- [ ] **3.6.1** Implement close button (hide, continue recording)
- [ ] **3.6.2** Implement minimize button
- [ ] **3.6.3** Add "Show Live Transcript" menu item
- [ ] **3.6.4** Add keyboard shortcut

### 3.7 Integration

- [ ] **3.7.1** Connect `MeetingCoordinator` to processor
- [ ] **3.7.2** Auto-open window on recording start
- [ ] **3.7.3** Close window on recording stop
- [ ] **3.7.4** Add toggle to start recording dialog

### 3.8 Phase 3 Validation Checklist

- [ ] **3.8.1** All automated tests pass
- [ ] **3.8.2** Latency test < 5 seconds
- [ ] **3.8.3** WER test < 20%
- [ ] **3.8.4** Manual UI tests pass
- [ ] **3.8.5** Live subtitles demo successful

---

### 3.9 Phase 3 User Acceptance Tests (UAT)

**Time Required:** ~15 minutes

**Prerequisites:**
- A quiet environment for clear speech
- Stopwatch or timer app ready

#### UAT 3.1: Basic Live Subtitles Test
| Step | Action | Expected Result | ✓ |
|------|--------|-----------------|---|
| 1 | Start meeting recording | Recording dialog appears | [ ] |
| 2 | Check "Show Live Subtitles" option | Option is checked | [ ] |
| 3 | Click "Start Recording" | Recording begins AND subtitle window opens | [ ] |
| 4 | Observe the subtitle window | Window is floating, semi-transparent | [ ] |
| 5 | Say clearly: "Hello, this is a test of live subtitles" | Words appear in subtitle window | [ ] |
| 6 | Note approximately how long until text appears | Should be less than 5 seconds | [ ] |

#### UAT 3.2: Latency Measurement Test
| Step | Action | Expected Result | ✓ |
|------|--------|-----------------|---|
| 1 | Start a new recording with live subtitles | Recording and subtitles active | [ ] |
| 2 | Start your stopwatch | Timer running | [ ] |
| 3 | Say: "Start timing now" | You said the phrase | [ ] |
| 4 | Stop stopwatch when "now" appears in subtitles | Time recorded | [ ] |
| 5 | Record the latency: _____ seconds | Should be < 5 seconds | [ ] |
| 6 | Repeat 3 times, calculate average | Average < 5 seconds | [ ] |

#### UAT 3.3: Transcription Accuracy Test
| Step | Action | Expected Result | ✓ |
|------|--------|-----------------|---|
| 1 | Start recording with live subtitles | Active | [ ] |
| 2 | Read this text clearly: "The quick brown fox jumps over the lazy dog. Pack my box with five dozen liquor jugs." | Text spoken | [ ] |
| 3 | Wait for subtitles to appear | Text displayed | [ ] |
| 4 | Compare displayed text to what you said | Most words are correct (>80%) | [ ] |
| 5 | Note any consistent errors | Document for improvement | [ ] |

#### UAT 3.4: Window Behavior Test
| Step | Action | Expected Result | ✓ |
|------|--------|-----------------|---|
| 1 | With subtitle window open, drag it to a new position | Window moves smoothly | [ ] |
| 2 | Resize the window (drag corner/edge) | Window resizes | [ ] |
| 3 | Close the subtitle window (X button) | Window closes | [ ] |
| 4 | Check that recording is still running | Timer still advancing | [ ] |
| 5 | Speak: "Recording should still work" | Audio still being captured | [ ] |
| 6 | Click menu → "Show Live Transcript" | Window reopens | [ ] |
| 7 | Verify your last sentence appears | Text is visible | [ ] |
| 8 | Stop and restart the app | App restarts | [ ] |
| 9 | Start new recording with subtitles | Window opens at last position | [ ] |

#### UAT 3.5: Auto-Scroll Test
| Step | Action | Expected Result | ✓ |
|------|--------|-----------------|---|
| 1 | Start recording with subtitles | Active | [ ] |
| 2 | Speak continuously for 2 minutes | Lots of text generated | [ ] |
| 3 | Observe the subtitle window | Automatically scrolls to show newest text | [ ] |
| 4 | Manually scroll UP in the window | You can see older text | [ ] |
| 5 | Continue speaking | Auto-scroll is PAUSED (stays where you scrolled) | [ ] |
| 6 | Scroll back to bottom OR click "Resume" | Auto-scroll resumes | [ ] |

#### UAT 3.6: Keyboard Shortcut Test
| Step | Action | Expected Result | ✓ |
|------|--------|-----------------|---|
| 1 | Start recording with subtitles visible | Active | [ ] |
| 2 | Press the configured shortcut (check Settings) | Window toggles visibility | [ ] |
| 3 | Press shortcut again | Window reappears | [ ] |

**Phase 3 UAT Sign-off:**
- [ ] All UAT tests passed
- [ ] Average latency: _____ seconds (must be < 5)
- [ ] Tester: _________________
- [ ] Date: _________________

**Phase 3 Exit Criteria:** All 3.8.x and 3.9 UAT items checked ✅

---

## Phase 4: Speaker Diarization
**Goal:** Identify and label speakers in transcript  
**Duration:** 2 weeks  
**Dependencies:** Phase 1  
**Can Parallel With:** Phases 2, 3, 5, 6

### Phase 4 Validation Criteria

| Criteria | Target | Test Type | How to Verify |
|----------|--------|-----------|---------------|
| Basic mode works | ✅ | Automated | Run without Python |
| PyAnnote mode works | ✅ | Automated | Run with Python |
| 2-speaker DER | < 25% | Automated | Compare to ground truth |
| 4-speaker DER | < 35% | Automated | Compare to ground truth |
| Fallback works | ✅ | Automated | Mock Python unavailable |

**DER = Diarization Error Rate** (lower is better)

### Phase 4 Demo Milestone

**Demo:** "Diarize 2-speaker test audio"
```
1. Load two_speakers_120s.wav
2. Run diarization (basic mode)
3. Load two_speakers_120s_labels.json (ground truth)
4. Calculate DER using standard formula
5. Assert: DER < 25% for basic mode
6. If PyAnnote available, run again and compare
```

---

### 4.1 DER Calculator

- [ ] **4.1.1** Create `DERCalculator.swift`
  ```swift
  // Diarization Error Rate = (FA + Miss + Confusion) / Total
  // FA = False Alarm (speech detected when none)
  // Miss = Missed speech
  // Confusion = Wrong speaker assigned
  func calculateDER(
      predicted: [SpeakerSegment],
      groundTruth: [SpeakerSegment],
      collar: Double = 0.25  // 250ms tolerance
  ) -> DERResult
  ```
- [ ] **4.1.2** Implement segment overlap calculation
- [ ] **4.1.3** Write unit tests with known inputs/outputs

### 4.2 Basic Voice Clustering

- [ ] **4.2.1** Create `BasicSpeakerClustering.swift`
- [ ] **4.2.2** Implement MFCC feature extraction
- [ ] **4.2.3** Implement k-means clustering
- [ ] **4.2.4** Output speaker segments
- [ ] **4.2.5** Write tests (AUTOMATED):
  - [ ] `testFeatureExtractionProducesVectors`
  - [ ] `testClusteringWith2SpeakerAudio` - uses test file
  - [ ] `testClusteringWith4SpeakerAudio` - uses test file
  - [ ] `testClusteringWithSilence` - edge case

### 4.3 Python Environment Detection

- [ ] **4.3.1** Create `PythonEnvironment.swift`
- [ ] **4.3.2** Check common Python locations
- [ ] **4.3.3** Verify Python version >= 3.8
- [ ] **4.3.4** Check pyannote installation
- [ ] **4.3.5** Write tests (AUTOMATED):
  - [ ] `testDetectionWithPython`
  - [ ] `testDetectionWithoutPython` (mock)
  - [ ] `testPyannoteCheck`

### 4.4 PyAnnote Integration

- [ ] **4.4.1** Create `Scripts/diarize.py`
- [ ] **4.4.2** Create `PyAnnoteDiarizer.swift`
- [ ] **4.4.3** Implement subprocess execution
- [ ] **4.4.4** Parse JSON output
- [ ] **4.4.5** Handle errors and timeouts
- [ ] **4.4.6** Write tests:
  - [ ] `testDiarizeWith2SpeakerAudio` (AUTOMATED if Python available)
  - [ ] `testTimeoutHandling` (AUTOMATED)
  - [ ] `testErrorHandling` (AUTOMATED)

### 4.5 Speaker Diarizer (Unified)

- [ ] **4.5.1** Create `SpeakerDiarizer.swift`
- [ ] **4.5.2** Implement audio concatenation
- [ ] **4.5.3** Implement tier selection
- [ ] **4.5.4** Define `SpeakerSegment` model
- [ ] **4.5.5** Write tests (AUTOMATED):
  - [ ] `testAutoSelectsPyAnnoteWhenAvailable`
  - [ ] `testFallsBackToBasicWhenPyAnnoteUnavailable`

### 4.6 Transcript-Diarization Alignment

- [ ] **4.6.1** Create `DiarizationAligner.swift`
- [ ] **4.6.2** Implement time-based alignment
- [ ] **4.6.3** Handle overlapping speech
- [ ] **4.6.4** Handle gaps
- [ ] **4.6.5** Define `SpeakerTranscriptSegment`
- [ ] **4.6.6** Write tests (AUTOMATED):
  - [ ] `testPerfectAlignmentCase`
  - [ ] `testOverlappingSpeech`
  - [ ] `testGapsInDiarization`
  - [ ] `testWithMockDataFiles`

### 4.7 Accuracy Validation Tests

- [ ] **4.7.1** `testBasicMode2SpeakerDERUnder25Percent` (AUTOMATED)
- [ ] **4.7.2** `testBasicMode4SpeakerDERUnder35Percent` (AUTOMATED)
- [ ] **4.7.3** `testPyAnnote2SpeakerDERUnder15Percent` (AUTOMATED, skip if no Python)
- [ ] **4.7.4** `testPyAnnote4SpeakerDERUnder25Percent` (AUTOMATED, skip if no Python)

### 4.8 Speaker Name Management

- [ ] **4.8.1** Create `SpeakerNameStore.swift`
- [ ] **4.8.2** Implement name storage per meeting
- [ ] **4.8.3** Implement name suggestions
- [ ] **4.8.4** Write unit tests (AUTOMATED)

### 4.9 Diarization Settings UI

- [ ] **4.9.1** Add diarization section to Settings
- [ ] **4.9.2** Create PyAnnote setup wizard

### 4.10 Phase 4 Validation Checklist

- [ ] **4.10.1** All automated tests pass
- [ ] **4.10.2** Basic mode DER < 25% (2-speaker)
- [ ] **4.10.3** Basic mode DER < 35% (4-speaker)
- [ ] **4.10.4** Fallback test passes (no Python)
- [ ] **4.10.5** Diarization demo successful

---

### 4.11 Phase 4 User Acceptance Tests (UAT)

**Time Required:** ~25 minutes

**Prerequisites:**
- Another person to help (or ability to change voice pitch significantly)
- Python 3.8+ installed (optional, for enhanced mode test)

#### UAT 4.1: Two-Person Conversation Test
| Step | Action | Expected Result | ✓ |
|------|--------|-----------------|---|
| 1 | Find a partner or prepare to change your voice | Ready | [ ] |
| 2 | Start meeting recording (Microphone) | Recording active | [ ] |
| 3 | Person 1 speaks for 30 seconds | Speech recorded | [ ] |
| 4 | Person 2 speaks for 30 seconds (or change voice) | Different voice recorded | [ ] |
| 5 | Alternate speakers 2-3 more times | Multiple transitions | [ ] |
| 6 | Stop recording | Processing begins | [ ] |
| 7 | Wait for processing to complete | "Identifying speakers" stage shown | [ ] |
| 8 | View the result | "2 speakers detected" message | [ ] |
| 9 | Check transcript | Speaker labels shown (Speaker A:, Speaker B:) | [ ] |
| 10 | Verify labels roughly match who was talking | Labels are mostly correct | [ ] |

#### UAT 4.2: Speaker Name Editing Test
| Step | Action | Expected Result | ✓ |
|------|--------|-----------------|---|
| 1 | Open a processed meeting with speakers | Meeting detail view | [ ] |
| 2 | Go to "Speakers" tab | List of speakers shown | [ ] |
| 3 | Click on "Speaker A" name | Name becomes editable | [ ] |
| 4 | Type "John" and press Enter | Name changes to "John" | [ ] |
| 5 | Check transcript tab | Labels now show "John:" instead of "Speaker A:" | [ ] |
| 6 | Close and reopen the meeting | Changes persisted | [ ] |

#### UAT 4.3: Single Speaker Test (Edge Case)
| Step | Action | Expected Result | ✓ |
|------|--------|-----------------|---|
| 1 | Start recording | Active | [ ] |
| 2 | Only ONE person speaks for 2 minutes | Single voice | [ ] |
| 3 | Stop and process | Processing completes | [ ] |
| 4 | Check result | "1 speaker detected" or all text labeled same speaker | [ ] |

#### UAT 4.4: Basic Mode Fallback Test (No Python)
| Step | Action | Expected Result | ✓ |
|------|--------|-----------------|---|
| 1 | Open Terminal | Terminal open | [ ] |
| 2 | Temporarily rename Python: `sudo mv /usr/local/bin/python3 /usr/local/bin/python3.bak` | Python "removed" | [ ] |
| 3 | Restart WhisperType | App restarts | [ ] |
| 4 | Check Settings → Meetings → Speaker Identification | Shows "Basic Mode (Python not found)" | [ ] |
| 5 | Record a 2-person conversation | Recording complete | [ ] |
| 6 | Process the meeting | Diarization runs in basic mode | [ ] |
| 7 | Verify speakers are still detected | Speakers identified (may be less accurate) | [ ] |
| 8 | Restore Python: `sudo mv /usr/local/bin/python3.bak /usr/local/bin/python3` | Python restored | [ ] |

#### UAT 4.5: PyAnnote Enhanced Mode Test (Optional)
| Step | Action | Expected Result | ✓ |
|------|--------|-----------------|---|
| 1 | Ensure Python 3.8+ is installed | `python3 --version` shows 3.8+ | [ ] |
| 2 | Install pyannote: `pip3 install pyannote.audio` | Installation complete | [ ] |
| 3 | Open Settings → Meetings → Speaker Identification | Shows Python detected | [ ] |
| 4 | Click "Setup PyAnnote" | Setup wizard opens | [ ] |
| 5 | Enter HuggingFace token (if required) | Token saved | [ ] |
| 6 | Record a 2-person conversation | Recording complete | [ ] |
| 7 | Process the meeting | Uses PyAnnote (enhanced mode) | [ ] |
| 8 | Compare accuracy to basic mode | Should be more accurate | [ ] |

#### UAT 4.6: Diarization Settings Test
| Step | Action | Expected Result | ✓ |
|------|--------|-----------------|---|
| 1 | Open Settings → Meetings | Settings panel | [ ] |
| 2 | Find "Speaker Identification" section | Section visible | [ ] |
| 3 | See mode display (Basic/Enhanced) | Current mode shown | [ ] |
| 4 | See Python status | Detected/Not Detected shown | [ ] |

**Phase 4 UAT Sign-off:**
- [ ] All UAT tests passed
- [ ] Speaker detection accuracy acceptable
- [ ] Tester: _________________
- [ ] Date: _________________

**Phase 4 Exit Criteria:** All 4.10.x and 4.11 UAT items checked ✅

---

## Phase 5: LLM Summarization
**Goal:** Generate customizable meeting summaries  
**Duration:** 1-2 weeks  
**Dependencies:** Phase 1  
**Can Parallel With:** Phases 2, 3, 4, 6

### Phase 5 Validation Criteria

| Criteria | Target | Test Type | How to Verify |
|----------|--------|-----------|---------------|
| Templates render | All 6 work | Automated | Generate with each |
| Variables filled | 100% | Automated | No `{{var}}` in output |
| Structure valid | ✅ | Automated | Required sections present |
| Keywords present | > 80% | Automated | Key terms from transcript |
| Fallback works | ✅ | Automated | Mock LLM unavailable |

### Phase 5 Demo Milestone

**Demo:** "Generate summary from mock transcript"
```
1. Load sample_transcript_speakers.json
2. Run summarization with "Standard Meeting Notes" template
3. Verify: No {{variables}} remain in output
4. Verify: Output has ## Summary, ## Key Points, ## Action Items sections
5. Verify: 80%+ of key terms from transcript appear in summary
```

---

### 5.1 Summary Templates

- [ ] **5.1.1** Create `SummaryTemplate.swift`
- [ ] **5.1.2** Create `SummaryTemplateStore.swift`
- [ ] **5.1.3** Implement 6 built-in templates
- [ ] **5.1.4** Implement custom template storage
- [ ] **5.1.5** Write tests (AUTOMATED):
  - [ ] `testBuiltInTemplatesLoad`
  - [ ] `testCustomTemplateCRUD`
  - [ ] `testJSONPersistence`

### 5.2 Template Variable Extraction

- [ ] **5.2.1** Create `TemplateVariableExtractor.swift`
- [ ] **5.2.2** Parse `{{variable}}` syntax
- [ ] **5.2.3** Write tests (AUTOMATED):
  - [ ] `testExtractsAllVariables`
  - [ ] `testHandlesNestedBraces`
  - [ ] `testHandlesNoVariables`

### 5.3 Summary Output Validation

- [ ] **5.3.1** Create `SummaryValidator.swift`
  ```swift
  struct SummaryValidation {
      let allVariablesFilled: Bool      // No {{var}} in output
      let requiredSectionsPresent: Bool // Has expected headers
      let keywordCoverage: Double       // % of key terms present
  }
  ```
- [ ] **5.3.2** Implement variable check (regex for `{{...}}`)
- [ ] **5.3.3** Implement section check
- [ ] **5.3.4** Implement keyword extraction and matching

### 5.4 Meeting Summarizer

- [ ] **5.4.1** Create `MeetingSummarizer.swift`
- [ ] **5.4.2** Implement hierarchical summarization
- [ ] **5.4.3** Define prompts for each variable
- [ ] **5.4.4** Implement template rendering
- [ ] **5.4.5** Write tests (AUTOMATED with mock LLM):
  - [ ] `testWithMockTranscript`
  - [ ] `testAllVariableTypesFilled`
  - [ ] `testHierarchicalChunking`

### 5.5 Action Item Extraction

- [ ] **5.5.1** Create `ActionItemExtractor.swift`
- [ ] **5.5.2** Define `ActionItem` model
- [ ] **5.5.3** Implement extraction prompt
- [ ] **5.5.4** Write tests (AUTOMATED):
  - [ ] `testExtractsObviousActionItems`
  - [ ] `testHandlesNoActionItems`

### 5.6 LLM Integration

- [ ] **5.6.1** Integrate with existing `LLMEngine`
- [ ] **5.6.2** Add meeting prompts to `PromptBuilder`
- [ ] **5.6.3** Handle context length limits
- [ ] **5.6.4** Implement fallback behavior
- [ ] **5.6.5** Write tests:
  - [ ] `testWithOllama` (INTEGRATION - skip if unavailable)
  - [ ] `testFallbackWhenLLMUnavailable` (AUTOMATED with mock)

### 5.7 Template Editor UI

- [ ] **5.7.1** Create `TemplateEditorView.swift`
- [ ] **5.7.2** Create `TemplateListView.swift`
- [ ] **5.7.3** Add to Settings

### 5.8 Phase 5 Validation Checklist

- [ ] **5.8.1** All automated tests pass
- [ ] **5.8.2** All 6 templates generate valid output
- [ ] **5.8.3** No `{{variables}}` in any output
- [ ] **5.8.4** Keyword coverage > 80%
- [ ] **5.8.5** Fallback test passes
- [ ] **5.8.6** Summary demo successful

---

### 5.9 Phase 5 User Acceptance Tests (UAT)

**Time Required:** ~20 minutes

**Prerequisites:**
- Ollama installed with a model (e.g., llama2, mistral) OR cloud LLM configured
- Prepare a script to read during recording

**Test Script to Read:**
```
"Let's discuss three items today. First, the Q1 budget is approved at $50,000 
for marketing. Second, Sarah will prepare the product roadmap by next Friday. 
Third, we decided to delay the launch until March 15th. 
John, please send the updated project timeline to the team by end of day Monday.
Also, remind everyone that the office will be closed next Thursday for the holiday."
```

#### UAT 5.1: Summary Generation Test
| Step | Action | Expected Result | ✓ |
|------|--------|-----------------|---|
| 1 | Start meeting recording | Active | [ ] |
| 2 | Read the Test Script above clearly | Script spoken | [ ] |
| 3 | Add some filler conversation (30 sec) | More content | [ ] |
| 4 | Stop recording | Processing begins | [ ] |
| 5 | Wait for "Generating summary..." stage | Stage visible | [ ] |
| 6 | View completed meeting | Summary tab shown | [ ] |
| 7 | Check Summary section exists | Has "Summary" header | [ ] |
| 8 | Verify summary mentions: budget, roadmap, launch | Key topics present | [ ] |

#### UAT 5.2: Action Items Extraction Test
| Step | Action | Expected Result | ✓ |
|------|--------|-----------------|---|
| 1 | Open the meeting from UAT 5.1 | Meeting detail view | [ ] |
| 2 | Go to "Action Items" tab | Action items displayed | [ ] |
| 3 | Look for Sarah's roadmap task | "Sarah" + "roadmap" + "Friday" found | [ ] |
| 4 | Look for John's timeline task | "John" + "timeline" + "Monday" found | [ ] |
| 5 | Verify action items have assignees | Names shown | [ ] |

#### UAT 5.3: Template Selection Test
| Step | Action | Expected Result | ✓ |
|------|--------|-----------------|---|
| 1 | Open Settings → Meetings → Summary Templates | Template list shown | [ ] |
| 2 | See 6 built-in templates listed | All 6 visible | [ ] |
| 3 | Select "Action-Focused" template as default | Selected | [ ] |
| 4 | Record and process a new meeting | Processing complete | [ ] |
| 5 | Check summary format | Different from default, action-focused | [ ] |
| 6 | Try "Executive Brief" template | Shorter, executive format | [ ] |

#### UAT 5.4: All Templates Test
| Step | Action | Expected Result | ✓ |
|------|--------|-----------------|---|
| 1 | Record a 2-minute meeting with varied content | Recording complete | [ ] |
| 2 | Process with "Standard Meeting Notes" | Valid summary generated | [ ] |
| 3 | Re-process with "Action-Focused" | Different format, valid | [ ] |
| 4 | Re-process with "Detailed Minutes" | Longer, more detailed | [ ] |
| 5 | Re-process with "Executive Brief" | Short, high-level | [ ] |
| 6 | Re-process with "Stand-up/Scrum" | Blockers/progress format | [ ] |
| 7 | Re-process with "1-on-1" | Personal meeting format | [ ] |

#### UAT 5.5: Custom Template Test
| Step | Action | Expected Result | ✓ |
|------|--------|-----------------|---|
| 1 | Open Settings → Meetings → Summary Templates | Template list | [ ] |
| 2 | Click "Create Custom Template" | Editor opens | [ ] |
| 3 | Name it "My Custom Format" | Name entered | [ ] |
| 4 | Enter template content with variables: `## My Summary\n{{summary}}\n\n## Actions\n{{action_items}}` | Content entered | [ ] |
| 5 | Click Save | Template saved | [ ] |
| 6 | Verify it appears in template list | Listed as custom | [ ] |
| 7 | Use it for a meeting | Custom format applied | [ ] |
| 8 | Edit the custom template | Changes saved | [ ] |
| 9 | Delete the custom template | Removed from list | [ ] |

#### UAT 5.6: LLM Unavailable Fallback Test
| Step | Action | Expected Result | ✓ |
|------|--------|-----------------|---|
| 1 | Stop Ollama: `killall ollama` OR disconnect from cloud | LLM unavailable | [ ] |
| 2 | Record and process a meeting | Processing begins | [ ] |
| 3 | Observe summarization stage | Shows warning/skip message | [ ] |
| 4 | View result | Transcript shown, summary shows fallback message | [ ] |
| 5 | Restart Ollama: `ollama serve` | LLM restored | [ ] |
| 6 | Re-process the meeting (if option available) | Summary now generated | [ ] |

#### UAT 5.7: Key Points Verification Test
| Step | Action | Expected Result | ✓ |
|------|--------|-----------------|---|
| 1 | Use the meeting from UAT 5.1 | Meeting with known content | [ ] |
| 2 | Open Summary tab | Summary displayed | [ ] |
| 3 | Find "Key Points" section | Section exists | [ ] |
| 4 | Verify these topics mentioned: | | |
|   | - Budget ($50,000, Q1, marketing) | ✓ or ✗ | [ ] |
|   | - Product roadmap | ✓ or ✗ | [ ] |
|   | - Launch delay (March 15) | ✓ or ✗ | [ ] |
|   | - Office closure | ✓ or ✗ | [ ] |
| 5 | At least 3 of 4 topics present | >75% coverage | [ ] |

**Phase 5 UAT Sign-off:**
- [ ] All UAT tests passed
- [ ] All 6 templates work correctly
- [ ] Action items extracted accurately
- [ ] Tester: _________________
- [ ] Date: _________________

**Phase 5 Exit Criteria:** All 5.8.x and 5.9 UAT items checked ✅

---

## Phase 6: Meeting History & Storage
**Goal:** Store, search, and manage meeting records  
**Duration:** 1-2 weeks  
**Dependencies:** Phase 1  
**Can Parallel With:** Phases 2, 3, 4, 5

### Phase 6 Validation Criteria

| Criteria | Target | Test Type | How to Verify |
|----------|--------|-----------|---------------|
| Database CRUD | ✅ | Automated | All operations work |
| File storage | ✅ | Automated | Files created/deleted |
| Search works | ✅ | Automated | Find by title |
| Export works | ✅ | Automated | Valid Markdown |
| Cleanup complete | ✅ | Automated | No orphan files |

### Phase 6 Demo Milestone

**Demo:** "Full CRUD cycle with mock meeting"
```
1. Create mock meeting record → Insert into DB
2. List all meetings → Verify appears
3. Search by title → Verify found
4. Update title → Verify changed
5. Export to Markdown → Verify file valid
6. Delete meeting → Verify removed from DB and disk
```

---

### 6.1 SQLite Database

- [ ] **6.1.1** Create `MeetingDatabase.swift`
- [ ] **6.1.2** Define database schema
- [ ] **6.1.3** Implement migrations
- [ ] **6.1.4** Add indexes
- [ ] **6.1.5** Write tests (AUTOMATED):
  - [ ] `testDatabaseInitialization`
  - [ ] `testInsertMeeting`
  - [ ] `testUpdateMeeting`
  - [ ] `testGetMeetingByID`
  - [ ] `testGetAllMeetings`
  - [ ] `testSearchByTitle`
  - [ ] `testDeleteMeeting`
  - [ ] `testMigrationFromV1ToV2` (future-proofing)

### 6.2 File Storage Manager

- [ ] **6.2.1** Create `MeetingFileManager.swift`
- [ ] **6.2.2** Implement directory creation
- [ ] **6.2.3** Implement transcript/summary saving
- [ ] **6.2.4** Implement audio cleanup
- [ ] **6.2.5** Implement storage calculation
- [ ] **6.2.6** Write tests (AUTOMATED):
  - [ ] `testDirectoryCreation`
  - [ ] `testFileSaving`
  - [ ] `testFileDeletion`
  - [ ] `testStorageCalculation`
  - [ ] `testCleanupRemovesOrphanFiles`

### 6.3 Meeting Record Model

- [ ] **6.3.1** Create `MeetingRecord.swift`
- [ ] **6.3.2** Create `MeetingSpeaker` model
- [ ] **6.3.3** Create `MeetingMetadata` model
- [ ] **6.3.4** Write tests (AUTOMATED):
  - [ ] `testModelEncodingDecoding`

### 6.4 Meeting History UI

- [ ] **6.4.1** Create `MeetingHistoryView.swift`
- [ ] **6.4.2** Create `MeetingRowView.swift`
- [ ] **6.4.3** Create `MeetingDetailView.swift`
- [ ] **6.4.4** Create `SummaryTabView.swift`
- [ ] **6.4.5** Create `TranscriptTabView.swift`
- [ ] **6.4.6** Create `ActionItemsTabView.swift`
- [ ] **6.4.7** Create `SpeakersTabView.swift`
- [ ] **6.4.8** Write UI tests (MANUAL):
  - [ ] List displays meetings correctly
  - [ ] Search filters list
  - [ ] Detail view shows correct data

### 6.5 Export

- [ ] **6.5.1** Create `MeetingExporter.swift`
- [ ] **6.5.2** Implement Markdown export
- [ ] **6.5.3** Implement clipboard copy
- [ ] **6.5.4** Write tests (AUTOMATED):
  - [ ] `testMarkdownOutputFormat`
  - [ ] `testMarkdownContainsAllSections`

### 6.6 Storage Management

- [ ] **6.6.1** Create `StorageManagementView.swift`
- [ ] **6.6.2** Add "Keep audio" toggle
- [ ] **6.6.3** Implement bulk delete

### 6.7 Scale Testing

- [ ] **6.7.1** `testWith100Meetings` (AUTOMATED) - performance check
- [ ] **6.7.2** `testSearchPerformanceWith100Meetings` (AUTOMATED)

### 6.8 Phase 6 Validation Checklist

- [ ] **6.8.1** All automated tests pass
- [ ] **6.8.2** Full CRUD cycle demo successful
- [ ] **6.8.3** Export produces valid Markdown
- [ ] **6.8.4** Delete removes all related files
- [ ] **6.8.5** Scale tests pass (100 meetings)

---

### 6.9 Phase 6 User Acceptance Tests (UAT)

**Time Required:** ~20 minutes

**Prerequisites:**
- Complete at least 3 meeting recordings first (from previous phases)

#### UAT 6.1: Meeting History List Test
| Step | Action | Expected Result | ✓ |
|------|--------|-----------------|---|
| 1 | Click menu → "Meeting History" | History window opens | [ ] |
| 2 | Observe the list | All past meetings displayed | [ ] |
| 3 | Verify meetings show: title, date, duration | Info displayed correctly | [ ] |
| 4 | Verify meetings are sorted by date (newest first) | Correct order | [ ] |
| 5 | See storage indicator at bottom | Total storage shown (e.g., "125 MB used") | [ ] |

#### UAT 6.2: Meeting Detail View Test
| Step | Action | Expected Result | ✓ |
|------|--------|-----------------|---|
| 1 | Click on any meeting in the list | Detail view opens | [ ] |
| 2 | See tabs: Summary, Transcript, Action Items, Speakers | All 4 tabs visible | [ ] |
| 3 | Click Summary tab | Summary content shown | [ ] |
| 4 | Click Transcript tab | Full transcript with timestamps | [ ] |
| 5 | Click Action Items tab | Action items listed (if any) | [ ] |
| 6 | Click Speakers tab | Speaker list with speaking time | [ ] |

#### UAT 6.3: Edit Meeting Title Test
| Step | Action | Expected Result | ✓ |
|------|--------|-----------------|---|
| 1 | Open a meeting's detail view | Detail view open | [ ] |
| 2 | Find the title at the top | Current title shown | [ ] |
| 3 | Click the title to edit | Title becomes editable | [ ] |
| 4 | Change to "Test Meeting - Renamed" | New title entered | [ ] |
| 5 | Press Enter or click away | Title saved | [ ] |
| 6 | Go back to history list | List shown | [ ] |
| 7 | Find the meeting | Shows new title "Test Meeting - Renamed" | [ ] |
| 8 | Close and reopen history | Title persisted | [ ] |

#### UAT 6.4: Search Test
| Step | Action | Expected Result | ✓ |
|------|--------|-----------------|---|
| 1 | Create meetings with distinct titles: "Budget Review", "Product Planning", "Team Standup" | 3 meetings exist | [ ] |
| 2 | Open Meeting History | All meetings shown | [ ] |
| 3 | Click in search box | Search active | [ ] |
| 4 | Type "Budget" | Only "Budget Review" shown | [ ] |
| 5 | Clear search | All meetings shown again | [ ] |
| 6 | Type "Product" | Only "Product Planning" shown | [ ] |
| 7 | Type "xyz123" (no match) | Empty state or "No meetings found" | [ ] |

#### UAT 6.5: Export to Markdown Test
| Step | Action | Expected Result | ✓ |
|------|--------|-----------------|---|
| 1 | Open a meeting with summary and transcript | Detail view | [ ] |
| 2 | Click "Export" button | Export dialog or file save dialog | [ ] |
| 3 | Choose location, click Save | File saved | [ ] |
| 4 | Open the saved .md file in any text editor | File opens | [ ] |
| 5 | Verify contains: | | |
|   | - Meeting title | Present | [ ] |
|   | - Date and duration | Present | [ ] |
|   | - Summary section | Present | [ ] |
|   | - Transcript section | Present | [ ] |
|   | - Speakers section | Present | [ ] |
| 6 | Open .md in a Markdown viewer | Renders correctly | [ ] |

#### UAT 6.6: Copy to Clipboard Test
| Step | Action | Expected Result | ✓ |
|------|--------|-----------------|---|
| 1 | Open a meeting's Summary tab | Summary visible | [ ] |
| 2 | Click "Copy" button | Copied notification shown | [ ] |
| 3 | Open any text app (Notes, TextEdit) | App open | [ ] |
| 4 | Paste (Cmd+V) | Summary content pasted | [ ] |
| 5 | Verify content matches what was shown | Identical | [ ] |

#### UAT 6.7: Delete Meeting Test
| Step | Action | Expected Result | ✓ |
|------|--------|-----------------|---|
| 1 | Note the session folder path of a meeting | Path noted | [ ] |
| 2 | Open Meeting History | List shown | [ ] |
| 3 | Find the meeting to delete | Meeting visible | [ ] |
| 4 | Click delete button (trash icon) | Confirmation dialog | [ ] |
| 5 | Confirm deletion | Meeting removed from list | [ ] |
| 6 | Check Finder for the session folder | Folder deleted | [ ] |
| 7 | Close and reopen history | Meeting still gone | [ ] |

#### UAT 6.8: Storage Management Test
| Step | Action | Expected Result | ✓ |
|------|--------|-----------------|---|
| 1 | Open Settings → Meetings → Storage | Storage view | [ ] |
| 2 | See total storage used | Size displayed (e.g., "245 MB") | [ ] |
| 3 | See list of meetings by size | Largest first | [ ] |
| 4 | Toggle "Keep audio files" OFF | Setting changed | [ ] |
| 5 | Record and process a new meeting | Complete | [ ] |
| 6 | Check session folder | Audio chunks deleted, transcript kept | [ ] |
| 7 | Toggle "Keep audio files" ON | Setting changed | [ ] |

#### UAT 6.9: Multiple Meetings Stress Test
| Step | Action | Expected Result | ✓ |
|------|--------|-----------------|---|
| 1 | Ensure at least 10 meetings exist | 10+ meetings | [ ] |
| 2 | Open Meeting History | List loads quickly (<2 sec) | [ ] |
| 3 | Scroll through the list | Smooth scrolling | [ ] |
| 4 | Search for a meeting | Results appear quickly (<1 sec) | [ ] |
| 5 | Open different meetings rapidly | No crashes, smooth transitions | [ ] |

**Phase 6 UAT Sign-off:**
- [ ] All UAT tests passed
- [ ] CRUD operations work correctly
- [ ] Export produces valid files
- [ ] Tester: _________________
- [ ] Date: _________________

**Phase 6 Exit Criteria:** All 6.8.x and 6.9 UAT items checked ✅

---

## Phase 7: Integration & Polish
**Goal:** Connect all components and polish UX  
**Duration:** 1-2 weeks  
**Dependencies:** Phases 1-6

### Phase 7 Validation Criteria

| Criteria | Target | Test Type | How to Verify |
|----------|--------|-----------|---------------|
| Full flow works | ✅ | Manual | End-to-end recording |
| All audio sources | ✅ | Manual | Test mic, system, both |
| Error scenarios | 100% handled | Manual | Test each scenario |
| v1.2 regression | 0 failures | Automated | Run regression suite |
| UI polish | ✅ | Manual | Checklist review |

### Phase 7 Demo Milestone

**Demo:** "Complete 5-minute meeting flow"
```
1. Start meeting recording (Both sources)
2. Enable live subtitles
3. Speak for 5 minutes with 2 voices (or simulated)
4. Stop recording
5. Wait for processing (observe progress UI)
6. Verify: Summary shows 2 speakers
7. Verify: Transcript has speaker labels
8. Verify: Meeting appears in history
9. Export to Markdown
10. Verify: File contains all expected sections
```

---

### 7.1 Start Meeting Flow

- [ ] **7.1.1** Create `MeetingStartSheet.swift`
- [ ] **7.1.2** Add "Start Meeting" to menu bar
- [ ] **7.1.3** Handle permission requests

### 7.2 Recording Status

- [ ] **7.2.1** Create `MeetingStatusView.swift`
- [ ] **7.2.2** Update menu bar icon during recording
- [ ] **7.2.3** Implement 85-minute warning
- [ ] **7.2.4** Implement 90-minute auto-stop

### 7.3 Processing Progress

- [ ] **7.3.1** Create `MeetingProcessingView.swift`
- [ ] **7.3.2** Implement stage transitions
- [ ] **7.3.3** Post notification when complete

### 7.4 Error Handling

**Error Scenarios to Test:**

| Scenario | Expected Behavior | Test Type |
|----------|-------------------|-----------|
| Audio device disconnected | Save chunks so far, show error, offer retry | Manual |
| Disk full during recording | Stop recording, save what exists, show error | Manual |
| Microphone permission revoked | Stop recording, show permission dialog | Manual |
| Screen Recording permission revoked | Fall back to mic-only | Manual |
| Python crashes during diarization | Skip diarization, proceed with transcript | Automated |
| LLM timeout | Skip summary, show transcript only | Automated |
| LLM returns invalid response | Use fallback template | Automated |
| App crash during recording | Recover chunks on next launch | Manual |
| Network failure (cloud LLM) | Fall back to local or skip | Automated |

- [ ] **7.4.1** Implement error handler for each scenario
- [ ] **7.4.2** Test: `testDiarizationFailureContinuesWithTranscript` (AUTOMATED)
- [ ] **7.4.3** Test: `testLLMTimeoutSkipsSummary` (AUTOMATED)
- [ ] **7.4.4** Test: `testLLMInvalidResponseUsesFallback` (AUTOMATED)
- [ ] **7.4.5** Manual: Test audio device disconnection
- [ ] **7.4.6** Manual: Test disk full scenario
- [ ] **7.4.7** Manual: Test permission revocation
- [ ] **7.4.8** Manual: Test crash recovery

### 7.5 Audio Quality Warnings

- [ ] **7.5.1** Low audio level detection
- [ ] **7.5.2** Clipping detection
- [ ] **7.5.3** Show warnings in status view
- [ ] **7.5.4** Add confidence markers

### 7.6 Settings Integration

- [ ] **7.6.1** Create "Meetings" settings tab
- [ ] **7.6.2** Add all meeting settings
- [ ] **7.6.3** Add history link

### 7.7 Menu Bar Updates

- [ ] **7.7.1** Add meeting items to menu
- [ ] **7.7.2** Update menu during recording

### 7.8 v1.2 Regression Tests

**Existing Features to Verify:**

| Feature | Test |
|---------|------|
| Quick dictation | Still works with global hotkey |
| Model download | Models download correctly |
| Model switching | Can switch models |
| Vocabulary | Custom vocabulary still applied |
| App rules | Per-app rules still work |
| Text injection | Text injected correctly |
| Menu bar | Menu bar icon and menu work |
| Settings | All settings persist |

- [ ] **7.8.1** Create `RegressionTests.swift`
- [ ] **7.8.2** Test: `testQuickDictationStillWorks`
- [ ] **7.8.3** Test: `testModelSwitching`
- [ ] **7.8.4** Test: `testVocabularyApplied`
- [ ] **7.8.5** Test: `testAppRulesWork`
- [ ] **7.8.6** Test: `testTextInjection`
- [ ] **7.8.7** Test: `testSettingsPersist`

### 7.9 UI Polish Checklist

- [ ] **7.9.1** All buttons have hover states
- [ ] **7.9.2** All text is readable (contrast)
- [ ] **7.9.3** Dark mode looks correct
- [ ] **7.9.4** Windows remember position
- [ ] **7.9.5** No layout shifts on data load
- [ ] **7.9.6** Loading states shown
- [ ] **7.9.7** Error states shown clearly
- [ ] **7.9.8** Keyboard navigation works

### 7.10 Phase 7 Validation Checklist

- [ ] **7.10.1** Full end-to-end demo successful
- [ ] **7.10.2** All audio source combinations tested
- [ ] **7.10.3** All error scenarios tested
- [ ] **7.10.4** v1.2 regression tests pass
- [ ] **7.10.5** UI polish checklist complete

---

### 7.11 Phase 7 User Acceptance Tests (UAT)

**Time Required:** ~45 minutes

**Prerequisites:**
- All phases 1-6 complete
- A partner for 2-person test OR ability to play audio
- Ollama running with a model

#### UAT 7.1: Complete End-to-End Flow Test
| Step | Action | Expected Result | ✓ |
|------|--------|-----------------|---|
| 1 | Click menu → "Start Meeting Recording" | Recording dialog opens | [ ] |
| 2 | Select "Both (Microphone + System Audio)" | Option selected | [ ] |
| 3 | Check "Show Live Subtitles" | Option checked | [ ] |
| 4 | Click "Start Recording" | Recording begins, subtitle window opens | [ ] |
| 5 | Play a YouTube video with speech | System audio captured | [ ] |
| 6 | Speak yourself: "I am testing the meeting recorder" | Your voice captured | [ ] |
| 7 | Continue for 5 minutes with both sources | Recording proceeds | [ ] |
| 8 | Observe live subtitles | Both voices transcribed | [ ] |
| 9 | Click "Stop Recording" | Recording stops, processing begins | [ ] |
| 10 | Watch progress stages: | | |
|    | - "Saving audio..." | Shown | [ ] |
|    | - "Transcribing (1/X)..." | Shown with progress | [ ] |
|    | - "Identifying speakers..." | Shown | [ ] |
|    | - "Generating summary..." | Shown | [ ] |
| 11 | Wait for completion | Notification appears | [ ] |
| 12 | View the meeting result | Detail view opens | [ ] |
| 13 | Check Summary tab | Summary generated with key points | [ ] |
| 14 | Check Transcript tab | Full transcript with speaker labels | [ ] |
| 15 | Check Speakers tab | 2+ speakers detected | [ ] |
| 16 | Check Action Items tab | Any action items shown | [ ] |
| 17 | Open Meeting History | New meeting at top of list | [ ] |
| 18 | Export to Markdown | File saved successfully | [ ] |
| 19 | Open and verify Markdown | All sections present | [ ] |

#### UAT 7.2: Audio Source Combinations Test
| Step | Action | Expected Result | ✓ |
|------|--------|-----------------|---|
| 1 | Record 1 min with "Microphone Only" | Only mic audio captured | [ ] |
| 2 | Record 1 min with "System Audio Only" | Only system audio captured | [ ] |
| 3 | Record 1 min with "Both" | Both sources mixed | [ ] |
| 4 | Verify all 3 recordings process correctly | All complete | [ ] |

#### UAT 7.3: Processing Progress UI Test
| Step | Action | Expected Result | ✓ |
|------|--------|-----------------|---|
| 1 | Complete a 3-minute recording | Recording stops | [ ] |
| 2 | Observe processing view | Progress view appears | [ ] |
| 3 | See current stage displayed | Stage name visible | [ ] |
| 4 | See progress bar/percentage | Progress indicator moves | [ ] |
| 5 | See estimated time remaining (if shown) | Time updates | [ ] |
| 6 | Wait for completion | View transitions to results | [ ] |

#### UAT 7.4: Error Scenario - Audio Device Disconnect
| Step | Action | Expected Result | ✓ |
|------|--------|-----------------|---|
| 1 | Start recording with external microphone | Recording active | [ ] |
| 2 | Speak for 30 seconds | Audio captured | [ ] |
| 3 | Unplug the microphone | Device disconnected | [ ] |
| 4 | Observe app behavior | Error message shown | [ ] |
| 5 | Check what was saved | Partial recording saved | [ ] |

#### UAT 7.5: Error Scenario - Cancel During Processing
| Step | Action | Expected Result | ✓ |
|------|--------|-----------------|---|
| 1 | Complete a 2-minute recording | Processing begins | [ ] |
| 2 | While "Transcribing...", click Cancel | Confirmation dialog | [ ] |
| 3 | Confirm cancellation | Processing stops | [ ] |
| 4 | Check meeting history | Partial result saved (if any) | [ ] |

#### UAT 7.6: 85-Minute Warning Test (Simulated)
| Step | Action | Expected Result | ✓ |
|------|--------|-----------------|---|
| 1 | If possible, simulate 85-minute recording OR check code logic | Warning should trigger | [ ] |
| 2 | Verify warning notification appears | "Recording will stop in 5 minutes" | [ ] |
| 3 | Warning is non-blocking (recording continues) | Recording proceeds | [ ] |

#### UAT 7.7: v1.2 Feature Regression Tests
| Step | Action | Expected Result | ✓ |
|------|--------|-----------------|---|
| 1 | **Quick Dictation:** Press global hotkey (e.g., Ctrl+Space) | Quick dictation activates | [ ] |
| 2 | Speak briefly, release hotkey | Text inserted at cursor | [ ] |
| 3 | **Model Switching:** Open Settings → Models | Model list shown | [ ] |
| 4 | Switch to a different model | Model changes | [ ] |
| 5 | Test dictation with new model | Works correctly | [ ] |
| 6 | **Custom Vocabulary:** Add a custom word in Settings | Word added | [ ] |
| 7 | Dictate a sentence using that word | Word recognized correctly | [ ] |
| 8 | **App Rules:** Check per-app rules still apply | Rules active | [ ] |
| 9 | **Settings Persistence:** Change a setting, restart app | Setting preserved | [ ] |
| 10 | **Menu Bar:** Click menu bar icon | Menu appears | [ ] |
| 11 | All menu items functional | Items work | [ ] |

#### UAT 7.8: UI Polish Checklist
| Item | Checked | ✓ |
|------|---------|---|
| All buttons show hover state | | [ ] |
| Text is readable in light mode | | [ ] |
| Text is readable in dark mode | | [ ] |
| Dark mode colors correct | | [ ] |
| Windows open at remembered positions | | [ ] |
| No layout jump when data loads | | [ ] |
| Loading spinners shown during waits | | [ ] |
| Error messages are clear and helpful | | [ ] |
| Can navigate with keyboard (Tab, Enter) | | [ ] |
| No truncated text | | [ ] |
| Icons are clear and recognizable | | [ ] |

#### UAT 7.9: Notification Test
| Step | Action | Expected Result | ✓ |
|------|--------|-----------------|---|
| 1 | Ensure notifications enabled for WhisperType | Enabled in System Settings | [ ] |
| 2 | Complete a meeting recording | Processing completes | [ ] |
| 3 | If app is not frontmost | Notification appears | [ ] |
| 4 | Click notification | Opens meeting detail | [ ] |

#### UAT 7.10: Settings - Meetings Tab Test
| Step | Action | Expected Result | ✓ |
|------|--------|-----------------|---|
| 1 | Open Settings → Meetings | Meetings tab visible | [ ] |
| 2 | See sections: | | |
|    | - Default audio source | Dropdown works | [ ] |
|    | - Show live subtitles by default | Toggle works | [ ] |
|    | - Speaker identification mode | Options shown | [ ] |
|    | - Summary template | Dropdown works | [ ] |
|    | - Storage settings | Options visible | [ ] |
| 3 | Change settings | Changes apply | [ ] |
| 4 | Click "Meeting History" link | History opens | [ ] |
| 5 | Restart app, verify settings persist | Persisted | [ ] |

**Phase 7 UAT Sign-off:**
- [ ] All UAT tests passed
- [ ] End-to-end flow works completely
- [ ] All error scenarios handled gracefully
- [ ] v1.2 features still work (no regressions)
- [ ] UI polish checklist complete
- [ ] Tester: _________________
- [ ] Date: _________________

**Phase 7 Exit Criteria:** All 7.10.x and 7.11 UAT items checked ✅

---

## Phase 8: Testing & Release
**Goal:** Comprehensive testing and release  
**Duration:** 1 week  
**Dependencies:** Phase 7

### 8.1 Test Suite Execution

- [ ] **8.1.1** Run full automated test suite
- [ ] **8.1.2** Verify code coverage > 70% (Xcode coverage report)
- [ ] **8.1.3** Fix any failing tests

### 8.2 Integration Tests

**Quick Suite (< 10 min, run on every commit):**
- [ ] **8.2.1** Full flow - 2 minutes
- [ ] **8.2.2** System audio - 30 seconds
- [ ] **8.2.3** Live subtitles - 1 minute

**Full Suite (run before release):**
- [ ] **8.2.4** Full flow - 30 minutes
- [ ] **8.2.5** Memory stress test - 60 minutes simulated

### 8.3 Performance Tests

| Test | Target | Result |
|------|--------|--------|
| Memory (60-min recording) | < 150 MB | [ ] Pass |
| Latency (live subtitles) | < 5 seconds | [ ] Pass |
| Processing (60-min meeting) | < 15 minutes | [ ] Pass |
| Storage (per hour) | < 500 MB | [ ] Pass |

### 8.4 Compatibility Tests

| Platform | Result |
|----------|--------|
| macOS 13 (Ventura) | [ ] Pass |
| macOS 14 (Sonoma) | [ ] Pass |
| macOS 15 (Sequoia) | [ ] Pass |
| Apple Silicon | [ ] Pass |
| Intel Mac | [ ] Pass |

### 8.5 Edge Case Tests

- [ ] **8.5.1** Recording with complete silence
- [ ] **8.5.2** Recording with very loud audio (clipping)
- [ ] **8.5.3** Recording with background noise
- [ ] **8.5.4** Meeting with 10 speakers
- [ ] **8.5.5** Non-English meeting
- [ ] **8.5.6** Permission denied at start
- [ ] **8.5.7** No Python installed

### 8.6 Manual QA Checklist

- [ ] **8.6.1** First launch experience
- [ ] **8.6.2** Permission request flows
- [ ] **8.6.3** All settings work correctly
- [ ] **8.6.4** Dark mode appearance
- [ ] **8.6.5** Accessibility (VoiceOver)
- [ ] **8.6.6** Localization (if applicable)

### 8.7 Documentation

- [ ] **8.7.1** Update README.md
- [ ] **8.7.2** Write RELEASE_NOTES.md
- [ ] **8.7.3** Update screenshots
- [ ] **8.7.4** Document PyAnnote setup

### 8.8 Release

- [ ] **8.8.1** Update version numbers
- [ ] **8.8.2** Build release DMG
- [ ] **8.8.3** Test DMG installation on clean Mac
- [ ] **8.8.4** Create GitHub release
- [ ] **8.8.5** Final review and tag

---

### 8.9 Phase 8 User Acceptance Tests (UAT)

**Time Required:** ~2 hours

**Prerequisites:**
- All phases 1-7 complete and signed off
- Access to multiple macOS versions (if possible)
- Clean Mac for installation test (or VM)

#### UAT 8.1: Extended Recording Stress Test (30 minutes)
| Step | Action | Expected Result | ✓ |
|------|--------|-----------------|---|
| 1 | Prepare 30+ minutes of audio content | Content ready | [ ] |
| 2 | Start meeting recording (Both sources) | Recording active | [ ] |
| 3 | Open Activity Monitor | Monitor ready | [ ] |
| 4 | Let recording run for 30 minutes | Record memory every 5 min: | |
|    | - 5 min: _____ MB | < 150 MB | [ ] |
|    | - 10 min: _____ MB | < 150 MB | [ ] |
|    | - 15 min: _____ MB | < 150 MB | [ ] |
|    | - 20 min: _____ MB | < 150 MB | [ ] |
|    | - 25 min: _____ MB | < 150 MB | [ ] |
|    | - 30 min: _____ MB | < 150 MB | [ ] |
| 5 | Stop recording | Processing begins | [ ] |
| 6 | Note processing time: _____ minutes | < 15 min for 30 min recording | [ ] |
| 7 | Verify complete result | All sections present | [ ] |

#### UAT 8.2: 60-Minute Stress Test (Optional but Recommended)
| Step | Action | Expected Result | ✓ |
|------|--------|-----------------|---|
| 1 | Record for 60 minutes | Recording completes | [ ] |
| 2 | Peak memory: _____ MB | < 150 MB | [ ] |
| 3 | Processing time: _____ minutes | < 15 minutes | [ ] |
| 4 | Result complete and correct | Yes | [ ] |

#### UAT 8.3: Edge Case - Complete Silence
| Step | Action | Expected Result | ✓ |
|------|--------|-----------------|---|
| 1 | Start recording with no audio input | Recording active | [ ] |
| 2 | Wait 2 minutes in silence | Timer advances | [ ] |
| 3 | Stop recording | Processing begins | [ ] |
| 4 | Check result | Handles gracefully (empty or minimal transcript) | [ ] |

#### UAT 8.4: Edge Case - Very Loud Audio
| Step | Action | Expected Result | ✓ |
|------|--------|-----------------|---|
| 1 | Find loud audio source (max volume) | Ready | [ ] |
| 2 | Start recording | Active | [ ] |
| 3 | Play very loud audio (watch clipping warning) | Warning shown | [ ] |
| 4 | Record for 1 minute | Complete | [ ] |
| 5 | Check result | Transcript generated (quality may be lower) | [ ] |

#### UAT 8.5: Edge Case - Background Noise
| Step | Action | Expected Result | ✓ |
|------|--------|-----------------|---|
| 1 | Create noisy environment (fan, music) | Noise present | [ ] |
| 2 | Start recording | Active | [ ] |
| 3 | Speak clearly over the noise | Speech with noise | [ ] |
| 4 | Stop and process | Complete | [ ] |
| 5 | Check transcript accuracy | Reasonable accuracy despite noise | [ ] |

#### UAT 8.6: Edge Case - Non-English Meeting
| Step | Action | Expected Result | ✓ |
|------|--------|-----------------|---|
| 1 | Start recording | Active | [ ] |
| 2 | Speak in another language (Spanish, Chinese, etc.) | Non-English speech | [ ] |
| 3 | Process the meeting | Complete | [ ] |
| 4 | Check if language detected/transcribed | Transcribed (if model supports) | [ ] |

#### UAT 8.7: Fresh Installation Test
| Step | Action | Expected Result | ✓ |
|------|--------|-----------------|---|
| 1 | Get WhisperType DMG file | DMG ready | [ ] |
| 2 | On a clean Mac (or after uninstalling) | Clean state | [ ] |
| 3 | Open DMG | DMG opens | [ ] |
| 4 | Drag to Applications | Copied | [ ] |
| 5 | Launch WhisperType | App starts | [ ] |
| 6 | Complete first-launch setup | Setup completes | [ ] |
| 7 | Grant all required permissions | Permissions granted | [ ] |
| 8 | Test quick dictation | Works | [ ] |
| 9 | Test meeting recording | Works | [ ] |

#### UAT 8.8: macOS Compatibility Tests
| macOS Version | Installation | Quick Dictation | Meeting Recording | Processing | ✓ |
|---------------|--------------|-----------------|-------------------|------------|---|
| macOS 13 Ventura | Works | Works | Works | Works | [ ] |
| macOS 14 Sonoma | Works | Works | Works | Works | [ ] |
| macOS 15 Sequoia | Works | Works | Works | Works | [ ] |

#### UAT 8.9: Architecture Compatibility Tests
| Architecture | Installation | All Features | Performance OK | ✓ |
|--------------|--------------|--------------|----------------|---|
| Apple Silicon (M1/M2/M3) | Works | Works | Yes | [ ] |
| Intel | Works | Works | Yes | [ ] |

#### UAT 8.10: First Launch Experience Test
| Step | Action | Expected Result | ✓ |
|------|--------|-----------------|---|
| 1 | Launch app for first time | Welcome screen shown | [ ] |
| 2 | Follow onboarding steps | Clear instructions | [ ] |
| 3 | Permission requests are clear | Understand what's needed | [ ] |
| 4 | Model download works | Model downloads | [ ] |
| 5 | First dictation works | Success! | [ ] |

#### UAT 8.11: Accessibility Test (VoiceOver)
| Step | Action | Expected Result | ✓ |
|------|--------|-----------------|---|
| 1 | Enable VoiceOver (Cmd+F5) | VoiceOver active | [ ] |
| 2 | Navigate to WhisperType menu | Menu accessible | [ ] |
| 3 | Start meeting recording via VoiceOver | Recording starts | [ ] |
| 4 | Navigate Meeting History | List is navigable | [ ] |
| 5 | Open a meeting detail | Content is read | [ ] |
| 6 | All buttons have labels | Labels announced | [ ] |

#### UAT 8.12: Dark Mode Test
| Step | Action | Expected Result | ✓ |
|------|--------|-----------------|---|
| 1 | Set macOS to Dark Mode | Dark mode active | [ ] |
| 2 | Open all WhisperType windows | All windows visible | [ ] |
| 3 | Check text readability | All text readable | [ ] |
| 4 | Check button visibility | Buttons visible | [ ] |
| 5 | Check live subtitle window | Readable and visible | [ ] |
| 6 | Switch to Light Mode | Light mode active | [ ] |
| 7 | Verify all still looks correct | Yes | [ ] |

#### UAT 8.13: Documentation Review
| Document | Exists | Accurate | Complete | ✓ |
|----------|--------|----------|----------|---|
| README.md | Yes | Yes | Yes | [ ] |
| RELEASE_NOTES.md | Yes | Yes | Yes | [ ] |
| Screenshots updated | Yes | Yes | Yes | [ ] |
| PyAnnote setup guide | Yes | Yes | Yes | [ ] |

**Phase 8 UAT Sign-off:**
- [ ] All UAT tests passed
- [ ] Performance targets met (memory, latency, processing time)
- [ ] Compatible with all target macOS versions
- [ ] Compatible with Intel and Apple Silicon
- [ ] Accessibility (VoiceOver) works
- [ ] Dark/Light mode works
- [ ] Fresh installation works
- [ ] Documentation complete

**Final Sign-off:**
- [ ] Product Owner: _________________
- [ ] QA Lead: _________________
- [ ] Date: _________________

**Phase 8 Exit Criteria:** All 8.x and 8.9 UAT items checked ✅

---

## Appendix A: Test Artifact Specifications

### Quick Setup

```bash
cd TestAssets/Scripts

# Auto-generate everything possible (no API key needed)
./setup_test_assets.sh --auto

# Generate ElevenLabs audio (recommended for diarization tests)
export ELEVENLABS_API_KEY="your-key"
./setup_test_assets.sh --elevenlabs
```

### Audio Test Files

| File | Duration | Source | Generation Method |
|------|----------|--------|-------------------|
| `silence_30s.wav` | 30s | Auto | `ffmpeg -f lavfi -i anullsrc` |
| `tone_1khz_30s.wav` | 30s | Auto | `ffmpeg -f lavfi -i sine` |
| `low_volume_30s.wav` | 30s | Auto | `ffmpeg` with volume filter |
| `clipping_30s.wav` | 30s | Auto | `ffmpeg` with overdrive |
| `known_text_30s.wav` | 30s | Auto/ElevenLabs | macOS `say` or ElevenLabs |
| `single_speaker_60s.wav` | 60s | **ElevenLabs** | 1 voice (Adam) |
| `two_speakers_120s.wav` | 120s | **ElevenLabs** | 2 voices (Adam, Rachel) |
| `four_speakers_300s.wav` | 300s | **ElevenLabs** | 4 voices (Adam, Rachel, Clyde, Domi) |

### ElevenLabs Voice Mapping

| Speaker | Voice Name | Voice ID | Character |
|---------|------------|----------|-----------|
| SPEAKER_A | Adam | pNInz6obpgDQGcFmaJgB | Male (PM) |
| SPEAKER_B | Rachel | 21m00Tcm4TlvDq8ikWAM | Female (Designer) |
| SPEAKER_C | Clyde | 2EiwWnXFnvU5JabPnv8n | Male (Developer) |
| SPEAKER_D | Domi | AZnzlk1XvdvUeBnXmlld | Female (Product) |

### Script Files (in `TestAssets/Scripts/`)

| Script | Output Audio | Output Labels | Content |
|--------|--------------|---------------|---------|
| `single_speaker_script.txt` | `single_speaker_60s.wav` | N/A | Product update monologue |
| `two_speakers_script.txt` | `two_speakers_120s.wav` | `*_labels.json` | Budget planning dialogue |
| `four_speakers_script.txt` | `four_speakers_300s.wav` | `*_labels.json` | Sprint planning meeting |
| `known_text_script.txt` | `known_text_30s.wav` | `*_expected.txt` | Pangrams for WER testing |

### Ground Truth JSON Format (Auto-Generated)

```json
{
  "audio_file": "two_speakers_120s.wav",
  "duration_seconds": 120.0,
  "speakers": ["SPEAKER_A", "SPEAKER_B"],
  "segments": [
    {"speaker": "SPEAKER_A", "start": 0.0, "end": 8.0, "text": "Good morning Sarah..."},
    {"speaker": "SPEAKER_B", "start": 8.0, "end": 15.0, "text": "Good morning Michael..."},
    {"speaker": "SPEAKER_A", "start": 15.0, "end": 28.0, "text": "Let's start with..."}
  ]
}
```

> **Note:** Ground truth labels are automatically generated from the script files using `generate_ground_truth.py`. Since you write the script, timestamps are exact.

### Mock Data Files (Auto-Generated)

Run `python3 generate_mock_data.py` to create:

| File | Purpose |
|------|---------|
| `sample_transcript.json` | Transcript without speaker labels |
| `sample_transcript_speakers.json` | Transcript with speakers + expected keywords |
| `sample_diarization.json` | Speaker segments only (no text) |
| `sample_meeting_record.json` | Complete meeting record (DB format) |
| `sample_summary_input.json` | Input for LLM summarization |
| `sample_summary_expected.md` | Expected summary output |

### Manual Alternative (No ElevenLabs)

If you prefer not to use ElevenLabs API:

1. Open each `*_script.txt` in `TestAssets/Scripts/`
2. Copy text for each speaker segment
3. Generate audio in ElevenLabs web UI (https://elevenlabs.io)
4. Download and save to `TestAssets/Audio/`
5. Run: `python3 generate_ground_truth.py <script> <output.json>`

---

## Appendix B: Validation Summary

| Phase | Key Validation | Pass Criteria |
|-------|----------------|---------------|
| 1 | Record + chunks | Memory < 100 MB, 10 chunks for 5 min |
| 2 | System audio | Correlation > 0.8 with original |
| 3 | Live subtitles | Latency < 5s, WER < 20% |
| 4 | Diarization | DER < 25% (2-speaker), < 35% (4-speaker) |
| 5 | Summarization | All variables filled, keywords > 80% |
| 6 | Storage | CRUD works, cleanup complete |
| 7 | Integration | All scenarios handled, regression pass |
| 8 | Release | All tests pass, QA complete |

---

## Appendix C: Definition of Done

A phase is complete when:

1. ✅ All tasks checked off
2. ✅ All automated tests pass
3. ✅ Demo milestone completed successfully
4. ✅ Validation criteria met (documented)
5. ✅ **All UAT tests passed and signed off**
6. ✅ No critical bugs
7. ✅ Code reviewed
8. ✅ Documentation updated

---

## Appendix D: UAT Summary by Phase

| Phase | UAT Count | Est. Time | Key Tests |
|-------|-----------|-----------|-----------|
| 1 | 4 tests | 15 min | Recording, chunks, memory, cancel |
| 2 | 5 tests | 20 min | Permissions, YouTube, Teams, mixed, fallback |
| 3 | 6 tests | 15 min | Subtitles, latency, accuracy, window, scroll |
| 4 | 6 tests | 25 min | 2-person, names, single speaker, fallback, PyAnnote |
| 5 | 7 tests | 20 min | Summary, action items, templates, custom, fallback |
| 6 | 9 tests | 20 min | History, detail, edit, search, export, delete, storage |
| 7 | 10 tests | 45 min | E2E flow, sources, errors, regression, polish |
| 8 | 13 tests | 2 hours | Stress, edge cases, install, compatibility, accessibility |

**Total UAT Tests:** ~60 tests  
**Total UAT Time:** ~4-5 hours

---

*End of Tasks Document (Final with UAT)*
