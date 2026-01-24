# Speaker Diarization Spike - Swift-Only Approach

**Goal:** Validate if simple audio features + k-means clustering can achieve acceptable speaker separation (>70% accuracy) for typical 2-person meetings without requiring Python/PyAnnote.

**Duration:** 0.5 - 1 day

**Success Criteria:**
- 2-speaker clear audio: >75% accuracy
- 2-speaker Teams/Zoom audio: >65% accuracy

---

## Quick Start

### 1. Prepare Test Audio

Create WAV files in `TestAssets/SpikeAudio/`:

```bash
# Requirements:
# - 16kHz sample rate
# - Mono channel
# - 16-bit PCM
# - 1-3 minutes duration
```

**Option A: Record yourself**
1. Open QuickTime Player → File → New Audio Recording
2. Record a 2-minute conversation:
   - You speak for 10-15 seconds
   - Play a YouTube video of someone else speaking for 10-15 seconds
   - Alternate 4-5 times
3. Export as WAV (use `ffmpeg` to convert if needed):
   ```bash
   ffmpeg -i recording.m4a -ar 16000 -ac 1 -acodec pcm_s16le two_speakers_clear.wav
   ```

**Option B: Use existing meeting recording**
1. Export a short segment from Teams/Zoom
2. Convert to correct format:
   ```bash
   ffmpeg -i meeting.mp4 -ar 16000 -ac 1 -acodec pcm_s16le -t 120 two_speakers_zoom.wav
   ```

### 2. Create Ground Truth Labels

Create a JSON file with the same base name + `_labels.json`:

```json
{
  "audio_file": "two_speakers_clear.wav",
  "segments": [
    {"speaker": "A", "start": 0.0, "end": 12.5},
    {"speaker": "B", "start": 14.0, "end": 26.0},
    {"speaker": "A", "start": 28.0, "end": 41.5},
    {"speaker": "B", "start": 43.0, "end": 55.0},
    {"speaker": "A", "start": 57.0, "end": 70.0},
    {"speaker": "B", "start": 72.0, "end": 85.0}
  ]
}
```

**Tips for creating ground truth:**
- Listen to the audio and note speaker changes
- Times don't need to be millisecond-perfect (±0.5s is fine)
- Use any labels you want (A/B, Speaker1/Speaker2, names, etc.)
- Include all speech segments, skip pure silence

### 3. Run the Spike

**Option A: Xcode Test Target**

Add the spike files to your test target and create a test:

```swift
import XCTest

class SpeakerDiarizationSpikeTests: XCTestCase {
    
    func testSpikeAllAudio() throws {
        let spike = SpeakerDiarizationSpike()
        let testDir = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("TestAssets")
            .appendingPathComponent("SpikeAudio")
        
        let results = try spike.runAllSpikes(in: testDir, verbose: true)
        
        // Assert minimum accuracy
        for result in results {
            XCTAssertGreaterThanOrEqual(
                result.accuracy, 
                0.65, 
                "\(result.audioFile) accuracy too low"
            )
        }
    }
}
```

**Option B: Command Line (Swift Package)**

Uncomment the last line in `SpeakerDiarizationSpike.swift`:
```swift
runSpikeFromCommandLine()
```

Then run:
```bash
swift Spike/SpeakerDiarization/*.swift
```

---

## Expected Output

```
🚀 Speaker Diarization Spike - Swift Only
=========================================

Test Directory: /Users/.../TestAssets/SpikeAudio

───────────────────────────────────────────────────────────
Test: two_speakers_clear.wav
───────────────────────────────────────────────────────────
🎯 Running Speaker Diarization Spike
   Audio: two_speakers_clear.wav
   Ground Truth: two_speakers_clear_labels.json

✅ Loaded ground truth: 6 segments, 2 speakers
⏳ Loading audio...
✅ Loaded 85.0 seconds of audio in 0.02s
⏳ Extracting features...
✅ Extracted features for 72 segments in 0.15s
⏳ Clustering (k=2)...
✅ Clustering complete in 12 iterations (0.01s)
⏳ Evaluating accuracy...

═══════════════════════════════════════════════════════════
                    SPIKE RESULTS
═══════════════════════════════════════════════════════════

  Audio File:      two_speakers_clear.wav
  Total Segments:  72
  Correct:         61
  Accuracy:        84.7%

  Speaker Mapping:
    Cluster 0 → A
    Cluster 1 → B

  Confusion Matrix:
                    A         B
  A                32         3
  B                 8        29

═══════════════════════════════════════════════════════════
  ✅ PASS - Accuracy >= 75%
     Swift-only approach is VIABLE for this scenario
═══════════════════════════════════════════════════════════
```

---

## Understanding Results

### Accuracy Thresholds

| Result | Interpretation |
|--------|----------------|
| ≥ 75% | ✅ **PASS** - Swift-only is viable |
| 65-75% | ⚠️ **MARGINAL** - Works but needs improvement |
| < 65% | ❌ **FAIL** - May not be viable |

### Confusion Matrix

```
              Actual A    Actual B
Predicted A:    32           3      ← Cluster 0 mapped to Speaker A
Predicted B:     8          29      ← Cluster 1 mapped to Speaker B
```

- **Diagonal (32, 29)**: Correct predictions
- **Off-diagonal (3, 8)**: Errors (misclassifications)

### What Affects Accuracy

| Factor | Impact | Notes |
|--------|--------|-------|
| Gender difference | High | Male/female easier to separate |
| Voice similarity | High | Similar voices harder to separate |
| Audio quality | Medium | Compression, noise reduce accuracy |
| Segment length | Medium | Shorter segments = noisier features |
| Overlapping speech | High | Not handled well by simple clustering |

---

## Troubleshooting

### "No non-silent segments found"
- Check audio volume (may be too quiet)
- Lower `silenceThreshold` in `AudioFeatureExtractor.swift`

### Very low accuracy (<50%)
- Features may not discriminate well for this audio
- Try different segment duration (0.5s or 2s instead of 1s)
- Check if speakers have very similar voices

### Slow processing
- Should process at 10-50x realtime
- If slower, check for large audio files or memory issues

---

## Files Structure

```
Spike/
└── SpeakerDiarization/
    ├── README.md                      # This file
    ├── AudioFeatureExtractor.swift    # Feature extraction
    ├── SimpleKMeans.swift             # K-means clustering
    ├── SpikeEvaluator.swift           # Evaluation against ground truth
    └── SpeakerDiarizationSpike.swift  # Main spike runner

TestAssets/
└── SpikeAudio/
    ├── two_speakers_clear.wav         # Test audio 1
    ├── two_speakers_clear_labels.json # Ground truth 1
    ├── two_speakers_zoom.wav          # Test audio 2 (optional)
    └── two_speakers_zoom_labels.json  # Ground truth 2 (optional)
```

---

## Next Steps After Spike

### If PASS (≥75%)
1. Document results in `RESULTS.md`
2. Proceed with Swift-only as primary approach for Phase 4
3. Consider PyAnnote as optional "enhanced mode"

### If MARGINAL (65-75%)
1. Try improvements (see below)
2. Document limitations clearly for users
3. Consider Swift-only as fallback, prioritize PyAnnote

### If FAIL (<65%)
1. Document findings
2. Evaluate if PyAnnote dependency is acceptable
3. Consider deferring speaker diarization to v1.4

---

## Potential Improvements

If results are marginal, try these quick improvements:

### 1. Add MFCCs
More discriminative features, but more complex:
```swift
// Add 13 MFCC coefficients to feature vector
// Requires DCT implementation
```

### 2. Adjust Segment Duration
```swift
// In AudioFeatureExtractor.swift:
private let segmentDuration: Double = 2.0  // Try 2 seconds
```

### 3. Add Delta Features
Capture temporal dynamics:
```swift
// Compute first derivatives of features
// More useful for speaker characteristics
```

### 4. Use Gaussian Mixture Models
Better than k-means for audio:
```swift
// Implement simple GMM or use vDSP clustering
```

---

## Results Documentation Template

After running spike, create `RESULTS.md`:

```markdown
# Speaker Diarization Spike Results

**Date:** YYYY-MM-DD
**Duration:** X hours

## Test Setup

| Test | Audio Source | Duration | Speakers |
|------|--------------|----------|----------|
| Clear | [source] | X:XX | [description] |
| Zoom | [source] | X:XX | [description] |

## Results

| Test | Segments | Correct | Accuracy | Verdict |
|------|----------|---------|----------|---------|
| Clear | XX | XX | XX.X% | ✅/⚠️/❌ |
| Zoom | XX | XX | XX.X% | ✅/⚠️/❌ |

## Observations

1. [What worked well]
2. [What didn't work]
3. [Surprising findings]

## Recommendation

[ ] Proceed with Swift-only as primary
[ ] Proceed with Swift-only + improvements
[ ] Use Swift-only as fallback only
[ ] Need more testing

## Next Steps

1. [Action items]
```
