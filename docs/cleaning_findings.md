# Cleaning Findings
## PharmaMarket Data Cleaning Project

**Database:** PharmaMarketAnalytics_Clean  
**Source database:** PharmaMarketAnalytics  
**Scripts:** `03_DrugClass_Cleaning.sql` through `11_GenericIndication_Cleaning.sql`  
**Tables cleaned:** Drug_Class, Dosage_Form, Manufacturer, Indication, Generic, Medicine, Medicine_PackageSize, Medicine_PackageContainer, Generic_Indication

---

## Table 1 — Drug_Class

**Source rows:** 1,599  
**Script:** `03_DrugClass_Cleaning.sql`

### Fix 1: Lone and leading comma rows
- **Affected rows:** 11 (1 lone comma + 10 leading comma)
- **Issue:** `Drug_Class_Name` was either `','` or started with a comma (e.g. `',Something'`). The drug class name was unrecoverable from these rows.
- **Decision:** Insert a placeholder row `(Drug_Class_ID = 0, Drug_Class_Name = 'N/A')`, reassign all linked generics to `Drug_Class_ID = 0`, then delete the unrecoverable rows.
- **Generics reassigned:** 51 rows in Generic table

### Fix 2: Trailing comma rows
- **Affected rows:** 24
- **Issue:** `Drug_Class_Name` had a trailing comma (e.g. `'4-Quinolone preparations,'`).
- **Decision:** Strip the trailing comma using `TRIM(',' FROM Drug_Class_Name)`.
- **Side effect:** All 24 stripped names were duplicates of existing clean rows. Handled in Fix 2b.

### Fix 2b: Duplicates created by Fix 2
- **Affected rows:** 24 duplicate rows deleted
- **Decision:** For each duplicate pair, keep the row with the lower `Drug_Class_ID` (original clean row). Reassign any generics linked to the higher ID to the lower ID before deleting.

### Fix 3: Both-parts rows
- **Affected rows:** 1,143
- **Issue:** `Drug_Class_Name` contained embedded indication data after a comma (e.g. `'4-Quinolone preparations,Acute bacterial sinusitis'`). The part before the comma was a valid, recoverable drug class name.
- **Decision:** Extract the drug class name (part before the comma), reassign linked generics to the existing clean row matching that name, then delete the both-parts rows.

### Fix 4: Encoding artifacts
- **Affected rows:** 2
- **Issue:** Greek letter β (beta) was stored as garbled sequence — UTF-8 `NCHAR(946)` misread as Latin-1, producing `NCHAR(223)`.
- **Pattern:** `NCHAR(223)` → `NCHAR(946)` = β
- **Affected rows:** Drug_Class_ID 239 (`Long-acting selective β-adrenoceptor stimulants`) and 362 (`Short-acting selective & β2-adrenoceptor stimulants`)

### Final state
- **Rows after cleaning:** 422 (down from 1,599)
- **N/A placeholder:** Drug_Class_ID = 0 retained for unresolvable generics
- **Known non-ASCII characters:** 2 (β in Drug_Class_IDs 239 and 362 — intentional, not artifacts)

---

## Table 2 — Dosage_Form

**Source rows:** 113  
**Script:** `04_DosageForm_Cleaning.sql`

### Fix 1: Capitalisation inconsistency
- **Affected rows:** 1
- **Issue:** `'Emulsion for infusion'` — lowercase 'i' in 'infusion', inconsistent with all other dosage form names.
- **Fix:** Updated to `'Emulsion for Infusion'`.

### Final state
- **Rows after cleaning:** 113 (unchanged)
- **No NULLs, blanks, or duplicates found.**

---

## Table 3 — Manufacturer

**Source rows:** 240  
**Script:** `05_Manufacturer_Cleaning.sql`

### Fix 1: Encoding artifact — garbled apostrophe
- **Affected rows:** 1 (Manufacturer_ID 65)
- **Pattern:** `NCHAR(226) + NCHAR(8364) + NCHAR(8482)` → `NCHAR(8217)` = '
- **Cause:** UTF-8 right single quotation mark misread as Latin-1
- **Affected row:** `'Doctorâ€™s Chemical Works Ltd.'` → `'Doctor's Chemical Works Ltd.'`

### Fix 2: Double spaces
- **Affected rows:** 2 (Manufacturer_IDs 43, 48)
- **Issue:** Internal double spaces in `Manufacturer_Name`.
- **Fix:** `REPLACE(Manufacturer_Name, '  ', ' ')`
- **Affected rows:** `'Bronson  Laboratories (BD) Ltd.'`, `'Chemist Laboratories  Ltd.'`

### Fix 3: Missing period after 'Ltd'
- **Affected rows:** 3 (Manufacturer_IDs 7, 68, 159)
- **Issue:** `Manufacturer_Name` ended with `'Ltd'` without a period, inconsistent with the standard `'Ltd.'`.
- **Fix:** Appended period to the name.

### Fix 4: Lowercase 'ltd.'
- **Affected rows:** 1 (Manufacturer_ID 236)
- **Issue:** `'ltd.'` in all lowercase.
- **Fix:** `REPLACE(Manufacturer_Name, 'ltd.', 'Ltd.')`
- **Affected row:** `'West-Coast pharmaceutical works ltd.'` → `'...Ltd.'`

### Fix 5: Typo in manufacturer name
- **Affected rows:** 1 (Manufacturer_ID 129)
- **Issue:** `'Pharmaceuticls'` — missing letter 'a'.
- **Fix:** `'Libra Pharmaceuticls Ltd.'` → `'Libra Pharmaceuticals Ltd.'`

### No fix: 'Limited' vs 'Ltd.' variation
- 13 manufacturers use `'Limited'`, 145 use `'Ltd.'`. Both are correct legal suffixes. Spot-checked and confirmed each reflects the actual registered company name. Standardising would reduce accuracy.

### No fix: Foreign language and trade names
- Foreign language company names (e.g. `'ACM laboratoire dermatologique'`) and registered trade names with unconventional capitalisation (e.g. `'AstraZeneca pharmaceuticals'`) are correct as registered. No changes applied.

### Final state
- **Rows after cleaning:** 240 (unchanged)
- **No NULLs, blanks, or duplicates found.**
- **Known non-ASCII characters:** 1 (curly apostrophe NCHAR 8217 in ID 65 — intentional, not an artifact)

---

## Table 4 — Indication

**Source rows:** 2,043  
**Script:** `06_Indication_Cleaning.sql`

### Fix 1: Garbled curly apostrophes
- **Affected rows:** 22
- **Pattern:** `NCHAR(226) + NCHAR(8364) + NCHAR(8482)` → `NCHAR(8217)` = '
- **Cause:** UTF-8 right single quotation mark (U+2019) misread as Latin-1
- **Examples:** `Addison's disease`, `Alzheimer's disease`, `Athlete's foot`

### Fix 2: Garbled non-breaking space
- **Affected rows:** 1
- **Pattern:** `NCHAR(194)` → single space `' '`
- **Cause:** UTF-8 non-breaking space (U+00A0) misread as Latin-1
- **Affected row:** `'Cutaneous or mucocutaneous mycotic infections'`

### Fix 3: Garbled umlaut
- **Affected rows:** 1
- **Pattern:** `NCHAR(195) + NCHAR(182)` → `NCHAR(246)` = ö
- **Cause:** UTF-8 ö (U+00F6) misread as Latin-1
- **Affected row:** `'Waldenström's macroglobulinemia'` (apostrophe also corrected by Fix 1)

### Final state
- **Rows after cleaning:** 2,043 (unchanged)
- **No NULLs, blanks, or duplicates found.**
- **Known non-ASCII characters:** 23 (22 curly apostrophes NCHAR 8217 + 1 umlaut ö NCHAR 246 — intentional, not artifacts)

---

## Table 5 — Generic

**Source rows:** 1,711  
**Script:** `07_Generic_Cleaning.sql`

### Fix 1: Garbled curly apostrophes
- **Affected rows:** 2
- **Pattern:** `NCHAR(226) + NCHAR(8364) + NCHAR(8482)` → `NCHAR(8217)` = '
- **Cause:** UTF-8 right single quotation mark misread as Latin-1
- **Affected rows:** `Devil's Cotton + Ashoka bark + Aswagandha`, `St. John's Wort`

### Fix 2: Garbled non-breaking spaces around plus sign
- **Affected rows:** 1
- **Pattern:** `NCHAR(194) + '+' + NCHAR(194)` → `' + '`
- **Cause:** UTF-8 non-breaking spaces surrounding a plus sign misread as Latin-1
- **Affected row:** `'Paracetamol + Tramadol Hydrochloride'`
- **Note:** Fix 2 must run before Fix 3 — both target NCHAR(194)

### Fix 3: Garbled non-breaking space
- **Affected rows:** 1
- **Pattern:** `NCHAR(194)` → single space `' '`
- **Affected row:** `'Progesterone (Vaginal Gel)'`

### Fix 4: Garbled beta symbol
- **Affected rows:** 1
- **Pattern:** `NCHAR(206) + NCHAR(178)` → `NCHAR(946)` = β
- **Cause:** Same encoding issue as Drug_Class Fix 4
- **Affected row:** `'β-Sitosterol'`

### No fix: N/A drug class generics
- **Affected rows:** 61 generics with `Drug_Class_ID = 0`
- 51 were reassigned during Drug_Class cleaning (unrecoverable source data). The remaining 10 were always unclassified in the source system. Correct drug class assignments cannot be determined without external pharmaceutical reference data. Left as `Drug_Class_ID = 0` intentionally.

### Final state
- **Rows after cleaning:** 1,711 (unchanged)
- **No NULLs, blanks, duplicates, or whitespace issues found.**
- **Known non-ASCII characters:** 3 (2 curly apostrophes NCHAR 8217 + 1 beta β NCHAR 946 — intentional, not artifacts)

---

## Table 6 — Medicine

**Source rows:** 21,708 (21,357 allopathic, 351 herbal)  
**Script:** `08_Medicine_Cleaning.sql`

### No fix: NULL fields
The following NULL counts are expected and not fixable from source data:

| Column | NULL Count | Reason |
|---|---|---|
| Generic_ID | 214 | Combination medicines and herbal preparations with no single generic classification |
| Strength | 849 | Missing source data, no systematic pattern, unrecoverable |
| Manufacturer_ID | 147 | Unknown manufacturer in source data |

### No fix: Brand_Name duplicates
Hundreds of Brand_Names appear 2-9 times. All confirmed legitimate — same brand name, different strengths or dosage forms (e.g. Napa × 8 = 8 distinct strength/form combinations). No duplicate rows exist.

### No fix: 59 true duplicate rows
59 rows are true duplicates (identical Brand_Name + Strength + Dosage_Form_ID + Manufacturer_ID), caused by CSV parsing artifacts in the source file. These propagate into the child tables as known duplicate groups — documented in scripts 09 and 10. Retained as-is; deduplication would require source-level investigation.

### Final state
- **Rows after cleaning:** 21,708 (unchanged)
- **No encoding artifacts in Brand_Name.**
- **No whitespace issues found.**

---

## Table 7 — Medicine_PackageSize

**Source rows:** 14,349  
**Script:** `09_MedicinePackageSize_Cleaning.sql`

### No fix: Table fully clean
- No NULLs in Pack_Size or Pack_Price.
- No orphaned Brand_IDs.
- No medicines with more than 3 pack sizes.

### No fix: Known duplicate group
- **Affected rows:** 1 duplicate group (Brand_ID 20089, Unisaline Fruity, Pack_Size 20)
- Caused by upstream Medicine duplicate. Retained as-is — consistent with the known artifact documented in Table 6 above.

### Notable: Max price
- Max Pack_Price of 278,400 BDT — Juparib 150mg, 120 tablets. Confirmed plausible: Juparib (olaparib) is a PARP inhibitor used in oncology. Not an error.

### Final state
- **Rows after cleaning:** 14,349 (unchanged)

---

## Table 8 — Medicine_PackageContainer

**Source rows:** 22,707  
**Script:** `10_MedicinePackageContainer_Cleaning.sql`

### Data structure finding
The ETL design assumed two exclusive formats — container medicines (Container_Size populated, Unit_Price NULL) and unit-priced medicines (Container_Size NULL, Unit_Price populated). Inspection revealed three actual formats:

| Format | Description | Row Count |
|---|---|---|
| Format B | Unit-priced — Container_Size NULL, Unit_Price populated | 13,496 |
| Format Mixed | Both Container_Size and Unit_Price populated | 9,172 |
| Format Placeholder | Container_Size contains 'Price Unavailable' or 'Not for sale', Unit_Price NULL | 39 |

Format Mixed reflects source data that had unit pricing alongside container size all along — the ETL captured this correctly. No data was lost or incorrectly transformed.

### No fix: Placeholder rows
39 rows have Container_Size containing `'Price Unavailable'` or `'Not for sale'`. These carry meaningful context about why pricing is absent and are accepted as-is.

### No fix: Known duplicate groups
- **Affected rows:** 3 duplicate groups (Brand_IDs 3952 Cholera Fluid, 9027 Glucose Saline, 13603 Normal Saline)
- All caused by upstream Medicine duplicates. Retained as-is — consistent with the known artifact documented in Table 6 above.

### Container_Type column
`Container_Type` is a derived category column populated by the ETL project (`07b_Medicine_PackageContainer_ETL.sql`) using LIKE pattern matching on Container_Size. Categories include: Bottle, Vial, Tube, Ampoule, Drop, Inhaler, Pre-filled Syringe, Pen, Sachet, Bag, and others. 3 rows have `Container_Type = 'N/A'` — plain quantity strings (`250 mg` x2, `500 mg` x1) with no recognisable container keyword. Accepted as-is.

### Final state
- **Rows after cleaning:** 22,707 (unchanged)
- **Null_Container_Type:** 0
- **N/A Container_Type:** 3 (accepted)

---

## Table 9 — Generic_Indication

**Source rows:** 1,608  
**Script:** `11_GenericIndication_Cleaning.sql`

### No fix: Table fully clean
- No NULLs, no duplicates, no orphaned foreign keys.
- All 1,608 Generic_IDs exist in the Generic table.
- All 1,608 Indication_IDs exist in the Indication table.

### No fix: Pairs involving N/A generics
- **Affected rows:** 9 pairs involve generics with `Drug_Class_ID = 0`.
- The generic data is valid — only the drug class is unresolvable. Pairs retained as-is.

### Notable characteristic
- Every generic has exactly 1 indication in this table.
- 1,608 distinct generics reference 662 distinct indications — many indications are shared across multiple generics.

### Final state
- **Rows after cleaning:** 1,608 (unchanged)

---

## Known Remaining Issues

### 1. N/A generics (61 rows)
61 generics have `Drug_Class_ID = 0` (N/A placeholder). Correct drug class assignments require external pharmaceutical reference data and are outside the scope of this cleaning project. Retained as-is and flagged for future enrichment.

### 2. Medicine duplicate rows (59 rows)
59 true duplicate Medicine rows carried forward from the source CSV. Deduplication requires source-level investigation to confirm which rows to retain. Flagged for future work.

### 3. Medicine_PackageContainer N/A container types (3 rows)
3 rows (`250 mg` x2, `500 mg` x1) have `Container_Type = 'N/A'` — plain quantity strings with no container keyword. Cannot be categorised without external reference. Accepted as-is.