# Model v0.2 - results and decision

Date: 2026-10-28. Run: `ml/models/run_20261028_0953` (not in git), log `ml/models/train_v2_log.txt`.

## What changed from v0.1
- Training data: RiceLeafDiseaseBD + "Multi-class rice leaf disease" (Mendeley n8jpkpfz5p, incl. web photos), 8,995 photos.
- Zoom augmentation down to 30% of the area; 4:3 centre crop like the app; EfficientNetB0, 224 px.
- Unseen-source test: Dhan-Shomadhan (Mendeley znsxdctwtt), 883 photos, never trained on.

## Results

| | v0.1 (in the app) | v0.2 |
|---|---:|---:|
| Validation accuracy (v2 val, single view) | - | 79.4% |
| Validation, app rule: answered at >=95% correct | 39% (v1 val) | 60% |
| **Unseen source, single-view accuracy** | **42.6%** | **23.6%** |
| Unseen, field photos | 28.8% | 29.6% |
| Unseen, white-background photos | 48.2% | 21.1% |

**v0.2 is better on data like its training data and worse on a new source.** Cause (seen in the
confusion matrix): in the multiclass set Blast/Brown spot are often photographed on white paper
(38% / 77%) and Sheath blight never is, so v0.2 learned "white background → blast"; Dhan-Shomadhan's
sheath blight photos are on white paper and became Blast (43/281 correct vs 220/281 for v0.1).
The shortcut risk was flagged in `ml/reports/split_v2_report.txt` before training.

**Decision: v0.2 is not shipped. The app keeps v0.1.**

## Safety finding for v0.1 (the app)

On the unseen source, with the app's 5-view rule:

| Threshold | Answered | Correct when answered |
|---|---:|---:|
| 0.85 (was in the app) | 22.1% | 80.5% |
| 0.91 | 15.5% | 85.4% |
| **0.95 (now in the app)** | 11.1% | 93.9% |

0.85 looked safe on validation (95%) but 1 in 5 confident answers was wrong on new photos.
The app threshold is now 0.95 (`assets/models/rice_disease_v0_1.json`). Because this set was used
for that choice, it is no longer a clean test.

## What this means
- Both models generalise poorly to photos from another source - consistent with published
  cross-dataset results for Bangladeshi rice leaf classifiers (arXiv 2609.31709).
- More web data alone does not fix it and can make it worse through background shortcuts.

## Next steps (in order of expected value)
1. **Real photos from target farmers' fields** (phones they use, several districts) - the only
   trustworthy test, and the most useful training data. Even 30-50 per disease helps.
2. Remove the background shortcut: train on field photos only, or crop to the leaf (segmentation)
   before classifying, or paste leaves onto varied backgrounds during training.
3. Hold out whole sources in validation (leave-one-dataset-out) so model choice rewards
   generalisation, not fit to familiar data.
