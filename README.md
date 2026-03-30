# MLB Injury Recovery Prediction Pipeline

## Table of Contents
- [1. Project Overview](#1-project-overview)
- [2. Data Source](#2-data-source)
- [3. Data Preprocessing](#3-data-preprocessing)
  - [3.1 Date Standardization](#31-date-standardization)
  - [3.2 Position Categorization](#32-position-categorization)
  - [3.3 Handling Missing & Undisclosed Data](#33-handling-missing--undisclosed-data)
  - [3.4 Outlier Detection and Removal](#34-outlier-detection-and-removal)
- [4. Feature Engineering](#4-feature-engineering)
  - [4.1 Calculation of Precise Age at Injury](#41-calculation-of-precise-age-at-injury)
  - [4.2 Anatomy & Pathophysiology Extraction](#42-anatomy--pathophysiology-extraction)
  - [4.3 Relapse Detection (Recurring Injuries)](#43-relapse-detection-recurring-injuries)
- [5. Model Development](#5-model-development)
  - [5.1 Model Selection: CatBoost](#51-model-selection-catboost)
  - [5.2 Multi-Classification Approach](#52-multi-classification-approach)
  - [5.3 Training and Validation Split](#53-training-and-validation-split)
  - [5.4 Hyperparameter Tuning & Optimization](#54-hyperparameter-tuning--optimization)
    - [5.4.1 Determining the Learning Rate](#541-determining-the-learning-rate)
    - [5.4.2 Determining the Number of Iterations & Model Shrinkage](#542-determining-the-number-of-iterations--model-shrinkage)
- [6. Evaluation Metric](#6-evaluation-metric)

---

## 1. Project Overview
This project aims to bridge the "Clinical vs. Semantic" gap in sports medicine data. By transforming raw, unstructured injury reports into clinically meaningful features, I developed a Machine Learning model capable of predicting the number of days a player will spend on the Injured List (IL). This supports front-office decision-making, roster management, and player valuation.

## 2. Data Source
The primary dataset is curated from the **FanGraphs RosterResource Injury Report**.
* **URL:** [https://www.fangraphs.com/roster-resource/injury-report](https://www.fangraphs.com/roster-resource/injury-report)
* **Description:** A comprehensive tracker of active and historical MLB injuries, including player position, injury type, and dates of IL stint.

## 3. Data Preprocessing
To ensure the model receives high-quality, high-signal data, the following preprocessing steps are applied:

### 3.1 Date Standardization
Raw date formats in sports reporting are often inconsistent. All date-related columns (`date_injury`, `date_il_retro`, `date_return`) are standardized into a uniform **DD/MM/YY** format. This allows for accurate calculation of `days_injured` and enables chronological sorting for time-series analysis.

### 3.2 Position Categorization
MLB rosters use various acronyms for positions. To reduce noise and group players by similar physical demands, inconsistent position data is mapped into eight primary categories:
* **Pitchers:** Starting Pitcher (**SP**), Relief Pitcher (**RP**), and Swingman/Hybrid (**SPRP**).
* **Position Players:** Infielder (**INF**), Outfielder (**OF**), Catcher (**C**), and Designated Hitter (**DH**).
* **Utility Players:** Utility Player (**U**).

### 3.3 Handling Missing & Undisclosed Data
In professional sports, teams occasionally list injuries as "Undisclosed" or leave exact injury dates blank for ongoing injuries. 
* Records with **missing values** in critical fields (`date_injury`) are dropped.
* Injuries listed as **"Undisclosed"** or **"Personal"** are removed, as they lack the physiological signal required for a medical recovery model.

### 3.4 Outlier Detection and Removal
To prevent the model from being skewed (e.g., a simple strain that took 200 days due to unforeseen complications), we apply a grouped outlier filter:
* **Method:** Interquartile Range (**IQR**) Outliers.
* **Logic:** Outliers are calculated **within** each specific *Injury Type* and *Location* grouping.
* **Action:** Data points falling below $Q1 - 1.5 \times IQR$ or above $Q3 + 1.5 \times IQR$ are dropped to ensure the model learns the "typical" recovery curve for a specific diagnosis.

### 4. Feature Engineering

To provide the model with high-signal predictors, the raw data was transformed into several specialized features that capture the biological and historical context of each injury.

#### 4.1 Calculation of Precise Age at Injury
Age is a critical factor in biological recovery times. To move beyond simple birth years, a precise age was calculated using a relational data join:
* **Data Integration:** The primary injury table was joined with a supplemental player metadata dataset using `playerid` as the primary key.
* **Feature Extraction:** From this join, the player's exact `Date of Birth` was retrieved.
* **Calculation:** The `Age at Injury` was derived by subtracting the `Date of Birth` from the `Date of Injury`. This provides a continuous numerical feature (e.g., 24.3 years) that allows the model to account for subtle physiological differences in aging athletes.

#### 4.2 Anatomy & Pathophysiology Extraction
We moved beyond raw text descriptions by extracting two specific features using clinical heuristics:
1.  **Body Part Mapping:** Using Regular Expressions (Regex) with word boundaries, we mapped over 600 unique injury strings to 12 consistent anatomical zones (e.g., "Thoracic" or "Lat" $\rightarrow$ `Back/Spine`).
2.  **Clinical Logic Clustering:** Injuries were categorized by their **mechanism of healing** rather than just keywords. This creates groups such as `Neurovascular`, `Major Surgical`, and `Muscle/Soft Tissue`, which have distinct biological recovery windows.

#### 4.3 Relapse Detection (Recurring Injuries)
A dedicated logic was built to identify if a player is suffering from a recurring issue in the same body part:
* **Logic:** For every player, injuries are sorted chronologically.
* **Flagging:** The first instance of an injury to a specific body part is labeled `0`. Every subsequent injury to that same body part for that player is labeled `1`.
* **Predictive Value:** This allows the model to distinguish between a "Fresh" injury and a "Chronic/Relapse" injury, which often requires a more conservative (longer) recovery timeline.

## 5. Model Development

### 5.1 Model Selection: CatBoost
The **CatBoost** library was chosen as the primary algorithm for this pipeline. The decision was driven by the specific nature of MLB injury data, which contains a **high volume of categorical columns** (Position, Medical Cluster, Body Part). 
* CatBoost's proprietary handling of categorical features (Target Statistics) allows it to process high-cardinality data without the need for manual One-Hot Encoding, which often degrades performance in other tree-based models.

### 5.2 Multi-Classification Approach
The model is configured for **Multi-Classification**. Rather than just predicting a specific day count, the model classifies injuries into specific severity tiers (e.g., *Mild, Moderate, Severe, Season-Ending*). This provides a more actionable "Risk Profile" for players than a single numerical estimate.

### 5.3 Training and Validation Split
To ensure real-world applicability, the data is split **chronologically**:
* **Training Set:** Historical data (e.g., 2020–2024) is used to teach the model patterns.
* **Test Set:** The most recent injuries (e.g., 2025) are used for evaluation.
This ensures the model is "predicting the future based on the past," mirroring how it would be used by an MLB training staff during a live season.

### 5.4 Hyperparameter Tuning & Optimization

To achieve the highest predictive accuracy and prevent the model from simply memorizing historical data (overfitting), the following tuning strategy was implemented:

#### 5.4.1 Determining the Learning Rate ($\eta$)
The **Learning Rate** (step size) was determined through an iterative search to balance training speed and model stability. Learning rate 0.01 was chosen as it was most optimal. 

#### 5.4.2 Determining the Number of Iterations & Model Shrinkage
Rather than picking an arbitrary number of iterations (e.g., 1000), the optimal training duration was determined using **Automatic Model Shrinkage**:
* **Validation Monitoring:** During the training process, the model evaluates its performance on a validation set at the end of every epoch.
* **Optimal Iteration Detection:** The algorithm identifies the exact point (the **"Best Iteration"**) where the loss on the validation set is at its absolute minimum. 
* **Automatic Shrinkage:** CatBoost does not simply stop; it **shrinks the model back** to the "Best Iteration." 
* **Reasoning:** This ensures that any "over-learning" or noise captured in the final, declining rounds of training is discarded. The final model used for prediction is the one that achieved the peak generalized accuracy.

## 6. Evaluation Metric

**Accuracy** was chosen as the primary metric to determine how well the model predicted the correct **Severity Tier** (e.g., *Mild, Moderate, Severe, Season-Ending*). 

* **Calculation:** This represents the percentage of total predictions where the model's predicted severity class matched the actual recorded recovery window.
* **Significance:** In a multi-classification context, high accuracy indicates that the model has successfully learned the non-linear boundaries between different injury outcomes. It demonstrates the model's ability to distinguish between physiologically distinct events—such as a simple muscle strain versus a surgical-level tear—despite them often sharing similar keywords in raw text.