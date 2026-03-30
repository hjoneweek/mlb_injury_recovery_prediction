# MLB Injury Recovery Prediction Pipeline

## 1. Project Overview
This project aims to bridge the "Clinical vs. Semantic" gap in sports medicine data. By transforming raw, unstructured injury reports into clinically meaningful features, we develop a Machine Learning model capable of predicting the number of days a player will spend on the Injured List (IL). This supports front-office decision-making, roster management, and player valuation.

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
* **Versatility:** Utility Player (**U**).

### 3.3 Handling Missing & Undisclosed Data
In professional sports, teams occasionally list injuries as "Undisclosed" or leave return dates blank for ongoing injuries. 
* Records with **missing values** in critical fields (`date_injury`, `date_return`) are dropped.
* Injuries listed as **"Undisclosed"** or **"Personal"** are removed, as they lack the physiological signal required for a medical recovery model.

### 3.4 Outlier Detection and Removal
To prevent the model from being skewed by "freak occurrences" (e.g., a simple strain that took 200 days due to unforeseen complications), we apply a grouped outlier filter:
* **Method:** Interquartile Range (**IQR**) Outliers.
* **Logic:** Outliers are calculated **within** each specific *Injury Type* and *Location* grouping.
* **Action:** Data points falling below $Q1 - 1.5 \times IQR$ or above $Q3 + 1.5 \times IQR$ are dropped to ensure the model learns the "typical" recovery curve for a specific diagnosis.

### 4. Feature Engineering

To provide the model with high-signal predictors, the raw data was transformed into several specialized features that capture the biological and historical context of each injury.

#### 4.1 Calculation of Precise Age at Injury
Age is a critical factor in biological recovery times. To move beyond simple birth years, a precise age was calculated using a relational data join:
* **Data Integration:** The primary injury table was joined with a supplemental player metadata dataset using `playerid` as the primary key.
* **Feature Extraction:** From this join, the player’s exact `Date of Birth` was retrieved.
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
