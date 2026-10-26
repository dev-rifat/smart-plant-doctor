# RiceLeafDiseaseBD: A Field-Based Annotated Smartphone Image Dataset of Healthy and Diseased Rice Leaves from Bangladesh

## Overview

RiceLeafDiseaseBD is a curated image dataset of rice leaves (*Oryza sativa*) collected from major rice-producing regions of Bangladesh. The dataset is designed to support research in computer vision, plant disease analysis, and precision agriculture. It provides both original rice leaf images and region-level annotated data for common rice leaf diseases.

The dataset emphasizes consistency, reproducibility, and transparency and is released without predefined training, validation, or test splits to allow flexible experimental design by downstream users.

> **Version 2 notice.** The bounding-box coordinate files have been corrected in this release. Version 1 reported 76,150 annotations, but the released label files contained 70,067, and an audit found that the automated conversion from the manually drawn rectangles had also recorded background regions as lesions. Coordinates have been re-derived from the original drawn annotations, yielding **22,123 boxes**. Users of Version 1 should migrate. See [Annotation Revision History](#annotation-revision-history).

---

## Dataset Summary

- **Domain:** Agricultural imaging, computer vision, plant pathology
- **Total Images:** 9,769
- **Number of Classes:** 6
- **Image Resolution:** 1024 × 1024 pixels
- **Total Annotations:** 21,460 bounding boxes
- **Annotation Type:** Bounding boxes (region-level lesion localization)
- **Annotation Format:** YOLO-compatible text format
- **Geographic Region:** Gazipur, Dhaka, Bangladesh
- **Data Collection Period:** Summer 2025
- **Rice Varieties:** BRRI dhan28, BRRI dhan29

### Class Distribution

| Class ID | Class | Images | Bounding Boxes | Avg. Boxes/Image |
|---:|---|---:|---:|---:|
| 0 | Brown Spot | 2,178 | 9,352 | 4.3 |
| 1 | Blast | 1,326 | 4,844 | 3.7 |
| 2 | Healthy | 1,575 | — | 0 |
| 3 | Leaf Smut | 724 | 1,501 | 2.1 |
| 4 | Rice Tungro | 2,244 | 3,156 | 1.4 |
| 5 | Sheath Blight | 1,722 | 2,605 | 1.5 |
| | **Total** | **9,769** | **22,123** | **2.6**\* |

\* Averaged over the 8,194 images in the five disease classes. Healthy images have empty annotation files.

The class distribution is not balanced: Rice Tungro and Brown Spot together account for 45% of the images, while Leaf Smut accounts for 7%.

---

## Dataset Contents

### 1. Original Images
- Unannotated rice leaf images
- Organized into class-wise folders
- Suitable for image-level classification, visualization, and general analysis

### 2. Annotated Data
- Region-level annotations for diseased images
- Bounding boxes indicating diseased regions
- Annotation files in YOLO-compatible plain-text format
- Visualization images with bounding box overlays

---

## Directory Structure

```
RiceLeafDiseaseBD/
├── README.md
├── Data_Collection_Pipeline.png
├── Annotation_Protocol.pdf
├── Dataset_Metadata.csv
├── Original_Images/
│   ├── Healthy/
│   │   ├── healthy_001.jpg
│   │   └── ...
│   ├── Blast/
│   ├── Brown_Spot/
│   ├── Leaf_Smut/
│   ├── Rice_Tungro/
│   └── Sheath_Blight/
└── Annotated_Data/
    ├── Blast/
    │   ├── images/
    │   │   ├── blast_001.jpg
    │   │   └── ...
    │   └── labels/
    │       ├── blast_001.txt
    │       └── ...
    ├── Brown_Spot/
    ├── Leaf_Smut/
    ├── Rice_Tungro/
    └── Sheath_Blight/
```

The `images/` folders under `Annotated_Data/` contain the visual overlays with the drawn rectangles. The unmarked photographs are in `Original_Images/`. Both are provided for every diseased image.

---

## Image Acquisition

- Captured using two smartphone models: CMF Phone 2 Pro (50 MP) and Google Pixel 5.
- Photographed under natural field conditions with original backgrounds.
- Collected during the Summer 2025 growing season from multiple rice fields.
- Images capture natural variation in lighting, leaf dimensions, growth stage, and disease progression.
- All images standardized to 1024 × 1024 pixels prior to release.

---

## Disease Classes

1. Healthy
2. Blast (*Magnaporthe oryzae*)
3. Brown Spot (*Bipolaris oryzae*)
4. Leaf Smut (*Entyloma oryzae*)
5. Rice Tungro (viral, transmitted by leafhoppers)
6. Sheath Blight (*Rhizoctonia solani*)

All filenames begin with the class name as a prefix to ensure traceability.

---

## Annotation Method

Region-level annotations were produced manually by trained annotators under guidance from agricultural experts and experienced rice farmers:

- Visual identification of disease lesions and symptomatic areas
- Rectangular bounding box drawn around each diseased region
- Standardized protocols to ensure consistency across disease categories
- Validation by agricultural experts

**No automated detection models (e.g. YOLO, CNNs) were used to place annotations.** The rectangles were drawn by hand and are preserved in the overlay images under `Annotated_Data/<class>/images/`.

### Coordinate extraction

The YOLO coordinate files are derived from those drawn rectangles by automated extraction:

1. **Stroke segmentation** — HSV thresholding across both red hue lobes (H ∈ [0,6] ∪ [174,180]) with a high saturation floor (S ≥ 150, V ≥ 80). The saturation constraint separates the drawn stroke from naturally reddish content such as necrotic tissue, soil, and dry vegetation.
2. **Denoising** — 2 × 2 morphological opening to remove isolated speckles.
3. **Outline closure** — morphological operation with a 15 × 15 elliptical kernel to bridge small breaks in hand-drawn outlines.
4. **Component extraction** — connected components with at least 25 stroke pixels; the axis-aligned bounding box of each is taken from its stroke pixels.
5. **Normalisation** — conversion to YOLO format.

Forty-five images (0.5%) returned no boxes automatically and were annotated manually.

A detailed description of the annotation rules and validation steps is provided in `Annotation_Protocol.pdf`.

---

## Annotation Revision History

An audit conducted for Version 2 identified two defects in the Version 1 coordinate files.

**Reported counts were inconsistent.** The Version 1 README reported 76,150 boxes and the Mendeley record reported 74,836, while the released label files contained 70,067.

**The initial conversion over-detected.** Overlaying label boxes on their source images showed that the original extraction had recorded reddish image content in addition to the drawn rectangles. Because it keyed on colour without geometric constraints, background regions — soil, dry vegetation, and in some frames the annotator's hand — were recorded as lesion boxes. The drawn rectangles themselves were recovered correctly; the error was one of over-detection, not misplacement.

The manually drawn annotations are unaffected, as they are preserved in the overlay images. Coordinates have been re-derived from those images using the procedure above, yielding 22,123 boxes.

**Known limitation of the current extraction.** Rectangles drawn close together can merge into a single connected component and be recorded as one box. The reported counts are therefore a slight floor on the number of individually drawn regions.

Users of Version 1 should migrate to Version 2. Any results computed against Version 1 labels — including lesion counts, infected-area estimates, and localization supervision — should be regenerated.

---

## Annotation Format

Annotations are stored in YOLO-compatible plain-text format. Each file corresponds to one image with the same base filename:

```
<class_id> <center_x> <center_y> <width> <height>
```

Example:
```
0 0.512695 0.651855 0.005859 0.006836
0 0.602051 0.639648 0.004883 0.005859
0 0.473145 0.839355 0.051758 0.083008
```

All coordinates are normalized with respect to image width and height. Every line within a file carries the class identifier of its folder.

**Class ID mapping:**

| ID | Class |
|---:|---|
| 0 | Brown Spot |
| 1 | Blast |
| 2 | Healthy |
| 3 | Leaf Smut |
| 4 | Rice Tungro |
| 5 | Sheath Blight |

Healthy images carry empty annotation files; class ID 2 does not appear in any file.

---

## File Naming Convention

- Filenames begin with the class name as a prefix.
- Image and annotation files correspond one-to-one, differing only by extension.

```
brown_spot_001.jpg
brown_spot_001.txt
```

---

## Dataset Splits

Released without predefined training, validation, or test splits. Users are encouraged to create task-specific splits according to their experimental requirements. Note that the class distribution is uneven, so stratified splitting is recommended.

---

## Pipeline Documentation

`Data_Collection_Pipeline.png` in the root directory provides a visual summary of the data collection, preprocessing, annotation, and dataset organization workflow.

---

## Intended Use

- Rice leaf disease classification
- Lesion localization and detection
- Disease severity assessment and lesion counting
- Benchmarking object detection algorithms
- Multi-task learning combining classification and localization
- Transfer learning and self-supervised learning studies
- Lightweight mobile diagnostic applications for edge devices
- Precision agriculture research

---

## Limitations

- Annotations are bounding boxes and do not provide pixel-level segmentation. Boxes drawn around elongated or irregular lesions include surrounding healthy tissue.
- Half of all bounding boxes are smaller than 20 × 20 pixels, which limits the precision achievable for area-based severity estimation.
- Coordinates are derived from the drawn rectangles by automated extraction; rectangles drawn close together may merge into a single box.
- Images were collected from a specific geographic region (Gazipur, Bangladesh) during a single season (Summer 2025).
- Annotation density varies by disease characteristics: Blast and Brown Spot have numerous small lesions, while Sheath Blight has larger symptomatic areas.
- Annotations represent visually observable symptoms validated by experts, not laboratory-confirmed diagnoses.
- No leaf-region masks are provided. Severity expressed relative to leaf area rather than image area requires additional segmentation.

---

## Technical Specifications

- **Framework compatibility:** TensorFlow, PyTorch, Keras
- **Computer vision libraries:** OpenCV, scikit-image, Albumentations
- **Object detection models:** YOLOv5, YOLOv8, Faster R-CNN
- **Supported tasks:** Classification, object detection, severity estimation, lesion counting

---

## Citation

If you use this dataset in your research, please cite the corresponding data paper.

Munna, Mohammad Mehedi Hasan; Islam, Toriqul ; Saha, Smita; Safy, Iqbal Hossain; Bari, Saiful ; Akter, Jasmin; Rahman, Md Momtajur; Akter, Riya; Antu, Nahid Hossain; Kabir, Acramul Haque; Tulona, Reefka Fabliha; Islam, Ashraful; Amin, M Ashraful (2026), “RiceLeafDiseaseBD: A Field-Based Annotated Smartphone Image Dataset of Healthy and Diseased Rice Leaves from Bangladesh”, Mendeley Data, V3, doi: 10.17632/86s4jzj2m4.3

---

## License

Creative Commons Attribution 4.0 International (CC BY 4.0).

---

## Acknowledgments

- Bangladesh Rice Research Institute (BRRI)
- Agricultural extension officers from the Gazipur region
- Experienced rice farmers who provided expert validation

---

## Contact

mohammadmehedi.munna@gmail.com

---

## Version History

**v2.0 (2026)** — Corrected bounding-box coordinates re-derived from the drawn annotations (22,123 boxes, replacing 70,067 in the released v1 files). Corrected class identifiers so that each file uses the identifier of its class folder. Added per-class statistics, the coordinate extraction procedure, and expanded limitations.

**v1.0 (2026)** — Initial release. Superseded; see [Annotation Revision History](#annotation-revision-history).
