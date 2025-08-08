# UCR Violent Crime Data — R Script

[![Made with R](https://img.shields.io/badge/Made%20with-R-blue?logo=R)](https://www.r-project.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Last Commit](https://img.shields.io/github/last-commit/yourusername/yourrepo)](https://github.com/yourusername/yourrepo/commits/main)

This repository contains an **R script** that downloads **Violent Crime** statistics for all 50 U.S. states from the **FBI Crime Data Explorer (CDE) API** and produces **monthly** and **yearly** summary CSVs.
---
## Background & Purpose
Downloading comprehensive FBI UCR data for **all offenses, all states, and multiple years** directly from the [Crime Data Explorer](https://crime-data-explorer.fr.cloud.gov/) web interface is **virtually impossible** — the site limits filtering, export size, and batch downloads.

This project uses the **FBI CDE public API** instead, allowing automated retrieval of crime statistics programmatically for **every U.S. state** over a multi-year range.

While results may differ slightly from the live CDE website (due to data revisions, estimation of counts from rates, and API/web sync timing), this approach makes it feasible to **aggregate, analyze, and store nationwide crime data** in a reproducible way.

I developed this method to overcome CDE’s manual download limitations and to produce **clean, structured CSVs** ready for analysis in R, Python, or Excel.

---

> ⚠️ **Important:** You must obtain a **free API key** from [api.data.gov](https://api.data.gov/signup/) before running the script. Without it, the script will not work.

---

## 📑 Table of Contents
- [Overview](#overview)
- [Get an API Key (Required)](#get-an-api-key-required)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Configuration](#configuration)
- [What the Script Does](#what-the-script-does)
- [Outputs](#outputs)
- [Column Reference (Schema)](#column-reference-schema)
- [Customization](#customization)
- [Troubleshooting & FAQs](#troubleshooting--faqs)
- [Reproducibility Tips](#reproducibility-tips)
- [License](#license)
- [Acknowledgments](#acknowledgments)
- [Contact](#contact)

---

## Overview
- **Scope:** Violent crime (`"V"`) from January 2018 to December 2024.
- **Coverage:** All 50 U.S. states (extendable to include D.C.).
- **Sources:** [FBI Crime Data Explorer API](https://crime-data-explorer.fr.cloud.gov/api) via api.data.gov.
- **Outputs:** Two CSVs — monthly and yearly summaries — for further analysis in R, Python, or Excel.

---

## Get an API Key (Required)
1. Go to [https://api.data.gov/signup/](https://api.data.gov/signup/) and request a **free** API key.
2. Once received by email, open the script and replace:
   ```r
   API_KEY <- "YOUR_API_KEY_HERE"
   ```
3. **Better (secure) method:** Store it in your environment file:
   - Edit `~/.Renviron` and add:
     ```
     API_KEY=your_real_key_here
     ```
   - In the script:
     ```r
     API_KEY <- Sys.getenv("API_KEY")
     ```
   - Restart R/RStudio after saving.

> 🔐 **Never** commit your real API key to a public GitHub repository.

---

## Prerequisites
- **R** version 4.1 or higher (RStudio recommended)
- Install these R packages:
  ```r
  install.packages(c("httr", "jsonlite", "dplyr", "purrr", "readr", "tidyr"))
  ```

---

## Quick Start
1. **Clone or download** this repository.
2. **Set your API key** in the script (see [Get an API Key](#get-an-api-key-required)).
3. **Adjust configuration values** if needed (date range, output file paths, etc.).
4. **Run the script** in R or RStudio:
   ```r
   source("ucr_fbi_data.R")
   ```
5. **Locate the CSV outputs** in the file paths you configured in the script.

---

## Configuration
At the top of the script:
```r
API_KEY <- "XXXX"     # or Sys.getenv("API_KEY")
FROM    <- "01-2018"  # start month-year 
TO      <- "12-2024"  # end month-year
You can change the **start date** (`FROM`) and **end date** (`TO`) in the script to **any date range you want**, provided the FBI CDE API has data for that period.
KEEP_ONLY_ACTUAL <- FALSE  # TRUE to remove estimated months
```
- Change **date range** to fetch different periods.
- Change **output file paths** in the `write_csv()` lines.
- Set `KEEP_ONLY_ACTUAL` to `TRUE` for fully-actual yearly data.

---

## What the Script Does
1. Fetches monthly violent crime data for each state from the FBI API:
   ```text
   /summarized/state/{STATE}/{OFFENSE}?from=MM-YYYY&to=MM-YYYY&API_KEY=...
   ```
2. Uses **actual counts** when available.
3. Estimates counts from rates & population when necessary:
   ```r
   round(rate_per_100k * population / 100000)
   ```
4. Flags each month as `"actual"` or `"estimated"`.
5. Aggregates monthly data to yearly totals & averages.

---

## Outputs
Two CSVs are generated:

| File | Description |
|------|-------------|
| `ucr_offenses_2018_2024_by_state_monthly.csv` | Monthly counts, rates, and source type per state-month |
| `ucr_offenses_2018_2024_by_state_yearly.csv` | Yearly totals, average rates, and counts of actual vs. estimated months |

---

---

## Notes on Data Accuracy
The results produced by this script **may differ slightly** from the figures shown in the live [FBI Crime Data Explorer](https://crime-data-explorer.fr.cloud.gov/).  
Possible reasons include:
- The FBI periodically **revises historical data**, so results may change if you re-run the script later.
- Some months are returned by the API as **rates only**, and counts are estimated from population data.
- The API’s dataset and the web interface may not be synchronized in real time.

For critical analysis, always document:
- The **date you pulled the data**
- The **API parameters** you used
---

## Column Reference (Schema)

**Monthly CSV:**
- `state_abbr` — two-letter code (e.g., CA)
- `offense_code` — `"V"` for Violent Crime
- `offense_name` — e.g., "Violent crime"
- `month` — MM-YYYY
- `year` — numeric year
- `month_count` — actual or estimated
- `month_rate_per_100k` — rate per 100k population
- `source_type` — `"actual"` or `"estimated"`

**Yearly CSV:**
- `state_abbr`, `offense_code`, `offense_name`
- `year` — numeric year
- `offense_count` — total annual count
- `offense_rate_per_100k_avg` — average monthly rate
- `months_actual` — number of actual months
- `months_estimated` — number of estimated months
- `any_estimated` — TRUE if any month was estimated

---

## Customization
- **Include D.C.:**
  ```r
  state_names <- c(state_names, DC = "District of Columbia")
  ```
- **Add more offense codes:**
  ```r
  offenses <- c("V", "R", "P") # example codes
  offense_names <- c(V="Violent crime", R="Robbery", P="Property crime")
  ```
- **Change output folder:** edit the `write_csv()` paths.

---

## Troubleshooting & FAQs
**Q: 403/401 errors?**  
A: API key missing/incorrect. Check environment variable or script value.

**Q: 429 Too Many Requests?**  
A: Hit API rate limit. Wait or slow down requests.

**Q: Some months are "estimated"?**  
A: This happens when the API returns rates but not actual counts — script calculates them.

**Q: Data changes on re-run?**  
A: FBI revises data occasionally — results may differ.

---

## Reproducibility Tips
- Save a copy of your CSV outputs with a timestamp.
- Use `renv` or similar to freeze R package versions.
- Log your API call dates for tracking.

---

## License
This project is licensed under the [MIT License](LICENSE).

---

## Acknowledgments
Data provided by the **FBI Crime Data Explorer** API via **api.data.gov**.

---

## Contact
For questions or suggestions:
- Open an [Issue](../../issues) on this repo
- Connect on [LinkedIn](https://www.linkedin.com/in/seyvan-nouri-45323253/)https://public.tableau.com/views/AreasDemographic/Dashboard1?:language=en-US&:sid=&:redirect=auth&:display_count=n&:origin=viz_share_link
