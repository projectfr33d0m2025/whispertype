# Speaker Diarization Spike Results

**Date:** 2025-01-24
**Duration:** ~2 hours (including debugging)

---

## Test Setup

| Test | Audio Source | Duration | Speakers | Type |
|------|--------------|----------|----------|------|
| two_speakers_120s | TTS Generated | 1:46 | 2 | Synthesized |
| four_speakers_300s | TTS Generated | 3:28 | 4 | Synthesized |

**Important Note:** The test audio files appear to be **TTS (Text-to-Speech) generated**, not real human recordings. This significantly impacts the validity of the results, as TTS voices often have very uniform acoustic characteristics that make speaker differentiation extremely difficult.

---

## Results (Latest Run: 2025-01-24)

| Test | Segments | Correct | Accuracy | Target | Verdict |
|------|----------|---------|----------|--------|---------|
| Single Speaker | 60 | 60 | 100.0% | 75% | ✅ PASS |
| 2 Speakers | 106 | 62 | 58.5% | 75% | ❌ FAIL |
| 4 Speakers | 208 | 82 | 39.4% | 65% | ❌ FAIL |

**Average Accuracy:** 66.0%

Both tests performed only slightly better than random chance, indicating that the simple acoustic features are not discriminative enough for these audio samples.

---

## Confusion Matrices

### Two Speakers Test
```
                  SPEAKER_A   SPEAKER_B
   Cluster 0:     37          54
   Cluster 1:     8           7
```
**Observation:** One cluster captured almost all segments (91 out of 106), indicating the features didn't provide meaningful separation.

### Four Speakers Test
```
             A       B       C       D       
Cluster 0:   17      7       28      33      
Cluster 1:   5       4       8       8       
Cluster 2:   7       7       17      17      
Cluster 3:   12      31      4       3       
```
**Observation:** Very scattered distribution with no clear speaker-to-cluster mapping.

---

## Technical Notes

### Features Extracted (per 1-second segment)
1. **Energy (RMS)** - Overall loudness
2. **Zero Crossing Rate** - Voice vs noise indicator
3. **Spectral Centroid** - "Brightness" of voice
4. **Spectral Rolloff** - Frequency distribution (85th percentile)
5. **Spectral Flatness** - Tonal vs noisy characteristic
6. **Pitch (F0)** - Fundamental frequency via autocorrelation

### Processing Pipeline
1. Load 16kHz mono WAV
2. Segment into 1-second windows
3. Skip silent segments (RMS < 0.001)
4. Extract 6 features per segment
5. Normalize features (z-score)
6. K-means clustering (k = number of speakers)
7. Greedy matching to ground truth

### Performance
- Processing speed: ~300x realtime
- Feature extraction: ~0.67s for 208 segments (3.5min audio)
- Clustering: <0.01s for 200+ segments
- Load time: ~0.02s per file

---

## Observations

### What worked:
1. ✅ The processing pipeline is functional and fast
2. ✅ WAV loading and feature extraction work correctly
3. ✅ K-means clustering converges quickly (9-13 iterations)

### What didn't work:
1. ❌ Simple acoustic features don't capture "speaker identity"
2. ❌ TTS audio has too uniform characteristics
3. ❌ No meaningful separation between speakers achieved

### Why it failed:
The fundamental issue is that **simple acoustic features (energy, ZCR, spectral statistics) describe the SOUND itself, not the SPEAKER**. Two people saying the same word will have similar energy and spectral characteristics. What we need are features that capture the unique timbre and resonance of each speaker's vocal tract - this requires:
- **MFCC (Mel-Frequency Cepstral Coefficients)** - Better representation of vocal characteristics
- **Speaker Embeddings** - Neural network-derived representations (what PyAnnote uses)

Additionally, the **TTS test audio** is a poor test case because:
- Synthesized voices are designed to be consistent
- No natural vocal variation between utterances
- May use the same underlying model with minor parameter changes

---

## Recommendation

- [ ] ~~Proceed with Swift-only as PRIMARY approach~~
- [ ] ~~Proceed with Swift-only as FALLBACK only~~
- [ ] ~~Proceed with Swift-only + improvements~~
- [x] **Need real human recordings for valid testing**
- [x] **Consider PyAnnote for production quality**

### Critical Next Steps

1. **Obtain Real Test Audio**
   - Record actual 2-person conversation with different speakers
   - Use real Zoom/Teams meeting recording
   - Ensure speakers have noticeably different voices

2. **Re-run Spike with Real Audio**
   - If accuracy improves to >70% with real audio → Swift-only viable as fallback
   - If still <65% → Need neural speaker embeddings (PyAnnote)

3. **Consider Adding MFCCs**
   - If we get real audio and results are marginal (65-75%)
   - Add 13 MFCC coefficients to feature vector
   - Requires DCT implementation but stays Swift-only

---

## Code Status

The spike code is **functional** and can be used for further testing:

```
Spike/SpeakerDiarization/
├── AudioFeatureExtractor.swift   ✅ Working
├── SimpleKMeans.swift            ✅ Working (with k-means++ fix)
├── SpikeEvaluator.swift          ✅ Working
├── SpeakerDiarizationSpike.swift ✅ Working
├── main.swift                    ✅ CLI entry point
└── README.md                     ✅ Instructions
```

### Build & Run
```bash
swiftc -O -framework Accelerate \
  Spike/SpeakerDiarization/*.swift \
  -o spike_runner && ./spike_runner
```

### Fixes Applied During Spike
1. Fixed `vDSP_vmul` parameter order (missing stride parameter)
2. Fixed WAV loading memory alignment (byte-by-byte reading)
3. Fixed pitch estimation array access (manual loop vs vDSP_dotpr slice)
4. Fixed k-means++ initialization bug (fallback logic was adding extra centroids)

---

## Conclusion

**The spike is INCONCLUSIVE due to TTS test audio.** 

The Swift-only approach with simple features works technically but produces random results on synthesized audio. Before deciding on the approach for Phase 4, we need to:

1. Test with **real human recordings**
2. If still poor results, consider:
   - Adding MFCCs to feature set
   - Using PyAnnote as primary with Swift as offline fallback
   - Deferring speaker diarization to v1.4.0

**Action Required:** Create or obtain real 2-person conversation recordings with distinct speakers for valid testing.
