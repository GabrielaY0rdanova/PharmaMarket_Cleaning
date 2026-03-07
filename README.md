# 🧹 PharmaMarket_Cleaning
## 🏷️ Project Badges

![SQL Server](https://img.shields.io/badge/SQL%20Server-2022-blue?logo=microsoftsqlserver&logoColor=white)
![Python](https://img.shields.io/badge/Python-3.x-blue?logo=python&logoColor=white)
![Kaggle](https://img.shields.io/badge/Kaggle-Dataset-orange?logo=kaggle&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-lightgrey)

## 📖 Overview
This project performs **data cleaning and quality validation** on the PharmaMarketAnalytics database.  
It inspects every table for NULLs, duplicates, encoding artifacts, referential integrity issues, and structural inconsistencies — applying targeted fixes where needed and documenting all findings.

The cleaned data is loaded into a separate database (`PharmaMarketAnalytics_Clean`) so the original ETL output is preserved and the two states can be compared at any time.

---

## 🔗 Related Project

This project is the **second stage** of a two-part pipeline. It depends on the ETL project, which builds the source database that this project cleans:

👉 **[PharmaMarket_ETL](https://github.com/GabrielaY0rdanova/PharmaMarket_ETL)**

The ETL project extracts data from raw CSV files, parses complex multi-value fields, creates child tables for package sizing and container pricing, and loads everything into `PharmaMarketAnalytics`.

**If you have already run the ETL project**, `PharmaMarketAnalytics` is already populated on your machine. Run all scripts in order starting from `00_CreateDatabase.sql` — including `01_ExportSourceData.py`, which will export the data from your local ETL database into the `source_data/` folder, and `02_LoadSourceData.sql`, which loads it into `PharmaMarketAnalytics_Clean`.

**If you have not run the ETL project**, the `source_data/` folder in this repository already contains the pre-exported CSV snapshots. Skip `01_ExportSourceData.py` and start from `00_CreateDatabase.sql`, then run `02_LoadSourceData.sql` to load the CSVs directly.

---

## 🗂️ Project Structure

```
PharmaMarket_Cleaning/
│
├── docs/                              # Documentation
│   └── cleaning_findings.md          # Detailed findings and decisions for every table
│
├── source_data/                       # CSV snapshots exported from PharmaMarketAnalytics
│   ├── Drug_Class.csv
│   ├── Dosage_Form.csv
│   ├── Manufacturer.csv
│   ├── Indication.csv
│   ├── Generic.csv
│   ├── Medicine.csv
│   ├── Medicine_PackageSize.csv
│   ├── Medicine_PackageContainer.csv
│   └── Generic_Indication.csv
│
├── scripts/                           # SQL and Python scripts
│   ├── 00_CreateDatabase.sql          # Creates PharmaMarketAnalytics_Clean
│   ├── 01_ExportSourceData.py         # Exports post-ETL snapshots to source_data/
│   ├── 02_LoadSourceData.sql          # Creates tables and bulk loads CSVs
│   ├── 03_DrugClass_Cleaning.sql
│   ├── 04_DosageForm_Cleaning.sql
│   ├── 05_Manufacturer_Cleaning.sql
│   ├── 06_Indication_Cleaning.sql
│   ├── 07_Generic_Cleaning.sql
│   ├── 08_Medicine_Cleaning.sql
│   ├── 09_MedicinePackageSize_Cleaning.sql
│   ├── 10_MedicinePackageContainer_Cleaning.sql
│   └── 11_GenericIndication_Cleaning.sql
│
├── tests/                             # Validation queries
│   └── 12_Validation.sql
│
└── README.md
```

---

## 🏗️ Database Schema

This project operates on the same schema produced by the ETL project. The tables cleaned are:

| Table Name                  | Description |
|-----------------------------|-------------|
| Drug_Class                  | Drug classes with unique names |
| Dosage_Form                 | Medicine dosage forms |
| Manufacturer                | Pharmaceutical manufacturers |
| Indication                  | Medical indications/conditions |
| Generic                     | Generic drugs linked to drug classes |
| Medicine                    | Brand medicines linked to generics, manufacturers, and dosage forms |
| Medicine_PackageSize        | Pack size options per medicine with pack price |
| Medicine_PackageContainer   | Container size options per medicine with unit price and container type category |
| Generic_Indication          | Junction table linking generics to indications (many-to-many) |

---

## 🔄 Cleaning Workflow

### Step 1 — Create the clean database
Run `00_CreateDatabase.sql` to create `PharmaMarketAnalytics_Clean` if it does not already exist.

### Step 2 — Export source data *(skip if you have not run the ETL project)*
Run `01_ExportSourceData.py` to export post-ETL snapshots from `PharmaMarketAnalytics` into the `source_data/` folder.

> ⚠️ **Only needed if you have run the ETL project locally.** If you have not, the `source_data/` folder already contains the pre-exported CSVs — skip this step and go straight to Step 3.

This script uses `pandas` and `pyodbc` to export all tables as CSV files. Using Python rather than SSMS ensures consistent quoting of special characters, commas, and Unicode values during export and re-import.

### Step 3 — Load source data
Run `02_LoadSourceData.sql` to create all tables in `PharmaMarketAnalytics_Clean` and bulk load the exported CSVs.

### Step 4 — Run cleaning scripts
Execute the cleaning scripts in order:

1. `03_DrugClass_Cleaning.sql`
2. `04_DosageForm_Cleaning.sql`
3. `05_Manufacturer_Cleaning.sql`
4. `06_Indication_Cleaning.sql`
5. `07_Generic_Cleaning.sql`
6. `08_Medicine_Cleaning.sql`
7. `09_MedicinePackageSize_Cleaning.sql`
8. `10_MedicinePackageContainer_Cleaning.sql`
9. `11_GenericIndication_Cleaning.sql`

### Step 5 — Validate
Run `tests/12_Validation.sql` to verify all cleaning results against expected values.

---

## 🔍 What Was Cleaned

A full account of every finding and decision is in [`docs/cleaning_findings.md`](docs/cleaning_findings.md). A summary by table:

| Table | Issues Found | Fixed |
|---|---|---|
| Drug_Class | 1,177 rows with comma artifacts, 2 encoding artifacts | ✅ Yes — 1,177 rows deleted/merged, 2 encoding fixes |
| Dosage_Form | 1 capitalisation inconsistency | ✅ Yes |
| Manufacturer | 1 encoding artifact, 2 double spaces, 3 missing periods, 1 lowercase suffix, 1 typo | ✅ Yes — all 8 fixed |
| Indication | 24 encoding artifacts (22 apostrophes, 1 NBSP, 1 umlaut) | ✅ Yes — all fixed |
| Generic | 5 encoding artifacts (2 apostrophes, 2 NBSP, 1 beta symbol) | ✅ Yes — all fixed |
| Medicine | 214 NULL Generic_ID, 849 NULL Strength, 147 NULL Manufacturer_ID, 59 duplicates | ⚠️ Documented — not fixable from source data |
| Medicine_PackageSize | No issues | ✅ Clean |
| Medicine_PackageContainer | 39 placeholder rows, 3 duplicate groups, 3 N/A container types | ⚠️ Documented — accepted as-is |
| Generic_Indication | No issues | ✅ Clean |

---

## 📂⚡ File Path Configuration (Important)

This project uses `BULK INSERT` and a Python export script, both of which require absolute file paths.

⚠️ **After cloning the repository, update file paths in two places:**

### In `01_ExportSourceData.py`
Update the `OUTPUT_FOLDER` variable:
```python
OUTPUT_FOLDER = r'C:\Your\Path\To\PharmaMarket_Cleaning\source_data'
```

### In `02_LoadSourceData.sql`
Update the path in each `BULK INSERT` statement:
```sql
FROM 'C:\Your\Path\To\PharmaMarket_Cleaning\source_data\Drug_Class.csv'
```

### ⚠️ Important Notes
- The path must be accessible by the SQL Server instance.
- If SQL Server runs locally, the file must exist on your machine.
- If SQL Server runs remotely or in Docker, the file must exist on that server or container.
- Spaces in folder names are fully supported as long as the path is enclosed in single quotes.

---

## 🛠️ Technologies Used

- **SQL Server / T-SQL** — data inspection, cleaning, and validation
- **Python 3 / pandas / pyodbc** — CSV export from source database
- **BULK INSERT** with `FORMAT = 'CSV'` and `FIELDQUOTE` for robust CSV re-import
- **CTEs** for duplicate identification and safe reassignment
- **NCHAR / UNICODE / PATINDEX** for encoding artifact detection and repair

---

## 🚀 Upcoming Projects
This cleaning project is part of a series built on the PharmaMarketAnalytics database:

- 🔍 **Exploratory Data Analysis (EDA)** — Uncovering patterns in drug classes, generics, manufacturers, and indications through analytical SQL queries and summary statistics.
- 📊 **Data Visualization** — An interactive dashboard presenting key insights from the database, including drug distribution, manufacturer market share, and indication trends.

---

## 📚 Data Source

The source CSV files were obtained from the Kaggle dataset:

[Assorted Medicine Dataset of Bangladesh](https://www.kaggle.com/datasets/ahmedshahriarsakib/assorted-medicine-dataset-of-bangladesh)

This dataset is used for educational purposes and to demonstrate data cleaning workflows.

---

## 👩‍💻 About Me

Hi! I'm [Gabriela Yordanova](https://www.linkedin.com/in/gabriela-yordanova-837ba2124/). 
With a background in pharmacy, I bring domain knowledge that goes beyond the data — 
knowing which findings are meaningful and which are just noise is half the work in cleaning. 
This project is the second stage of the pipeline, making sure the data is trustworthy 
before any analysis begins.

*This project is part of my portfolio showcasing data cleaning and quality validation skills.*

---

## 🛡️ License

This project is licensed under the [MIT License](LICENSE) and is available for educational and portfolio purposes.
