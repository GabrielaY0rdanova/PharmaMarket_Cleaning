# =================================================
# 01_ExportSourceData.py
# Exports post-ETL, pre-cleaning snapshots from
# PharmaMarketAnalytics to CSV files in source_data/
#
# WHY PYTHON:
# SQL Server's SSMS export wizard wraps fields containing
# commas in double quotes inconsistently, which causes
# BULK INSERT to misparse columns during re-import.
# pandas handles CSV quoting correctly by default,
# ensuring all special characters, commas, and Unicode
# values (e.g. Bengali currency symbols) are preserved.
#
# REQUIREMENTS:
# - Python 3.x
# - pandas:  pip install pandas
# - pyodbc:  pip install pyodbc
#
# USAGE:
# 1. Update SERVER and OUTPUT_FOLDER below
# 2. Ensure PharmaMarketAnalytics database is running
# 3. Run: python 01_ExportSourceData.py
#    or open in Jupyter Notebook and run all cells
# =================================================

import pyodbc
import pandas as pd
import os

# ==========================
# CONFIGURATION
# Update these values to match your local setup
# ==========================

SERVER   = 'localhost'              # SQL Server instance name
DATABASE = 'PharmaMarketAnalytics'

# Path to the source_data folder in this project
# Update this to match the location on your machine
OUTPUT_FOLDER = r'E:\Data Analysis\My Projects\PharmaMarket_Cleaning\source_data'

# ==========================
# CONNECTION
# Uses Windows Authentication (Trusted_Connection)
# No username or password required
# ==========================

conn = pyodbc.connect(
    f'DRIVER={{SQL Server}};'
    f'SERVER={SERVER};'
    f'DATABASE={DATABASE};'
    f'Trusted_Connection=yes;'
)

print(f'Connected to {DATABASE} on {SERVER}')
print(f'Exporting to: {OUTPUT_FOLDER}')
print('-' * 50)

# ==========================
# EXPORT QUERIES
# Each table is exported with its full column set
# ordered by primary key for consistency
#
# Medicine exports the final post-ETL schema:
#   - Package_Container and Package_Size were split into
#     child tables by 07_Medicine_PackageSize_ETL.sql and
#     07b_Medicine_PackageContainer_ETL.sql and are no
#     longer present in Medicine.
#   - Unit_Price was dropped by 07b after being moved to
#     Medicine_PackageContainer.
#
# Medicine_PackageSize and Medicine_PackageContainer are
# exported as separate tables for cleaning inspection.
# ==========================

tables = {
    'Drug_Class': '''
        SELECT Drug_Class_ID,
               Drug_Class_Name,
               Slug
        FROM Drug_Class
        ORDER BY Drug_Class_ID
    ''',

    'Dosage_Form': '''
        SELECT Dosage_Form_ID,
               Dosage_Form_Name,
               Slug
        FROM Dosage_Form
        ORDER BY Dosage_Form_ID
    ''',

    'Manufacturer': '''
        SELECT Manufacturer_ID,
               Manufacturer_Name,
               Slug
        FROM Manufacturer
        ORDER BY Manufacturer_ID
    ''',

    'Indication': '''
        SELECT Indication_ID,
               Indication_Name,
               Slug
        FROM Indication
        ORDER BY Indication_ID
    ''',

    'Generic': '''
        SELECT Generic_ID,
               Generic_Name,
               Slug,
               Drug_Class_ID
        FROM Generic
        ORDER BY Generic_ID
    ''',

    'Medicine': '''
        SELECT Brand_ID,
               Brand_Name,
               Type,
               Slug,
               Dosage_Form_ID,
               Generic_ID,
               Strength,
               Manufacturer_ID
        FROM Medicine
        ORDER BY Brand_ID
    ''',

    'Medicine_PackageSize': '''
        SELECT PackageSize_ID,
               Brand_ID,
               Pack_Size,
               Pack_Price
        FROM Medicine_PackageSize
        ORDER BY PackageSize_ID
    ''',

    'Medicine_PackageContainer': '''
        SELECT PackageContainer_ID,
               Brand_ID,
               Container_Size,
               Unit_Price
        FROM Medicine_PackageContainer
        ORDER BY PackageContainer_ID
    ''',

    'Generic_Indication': '''
        SELECT Generic_Indication_ID,
               Generic_ID,
               Indication_ID
        FROM Generic_Indication
        ORDER BY Generic_Indication_ID
    '''
}

# ==========================
# INTEGER COLUMNS PER TABLE
# pyodbc reads nullable INT columns from SQL Server as
# float (e.g. 299.0 instead of 299) when NULLs are present.
# Casting to pandas Int64 (nullable integer) before export
# ensures clean integer formatting in the CSV, which
# BULK INSERT can then load directly without TRY_CAST errors.
# ==========================

integer_columns = {
    'Drug_Class':               ['Drug_Class_ID'],
    'Dosage_Form':              ['Dosage_Form_ID'],
    'Manufacturer':             ['Manufacturer_ID'],
    'Indication':               ['Indication_ID'],
    'Generic':                  ['Generic_ID', 'Drug_Class_ID'],
    'Medicine':                 ['Brand_ID', 'Dosage_Form_ID', 'Generic_ID', 'Manufacturer_ID'],
    'Medicine_PackageSize':     ['PackageSize_ID', 'Brand_ID', 'Pack_Size'],
    'Medicine_PackageContainer':['PackageContainer_ID', 'Brand_ID'],
    'Generic_Indication':       ['Generic_Indication_ID', 'Generic_ID', 'Indication_ID'],
}

# ==========================
# EXPORT
# pandas to_csv handles quoted fields automatically.
# encoding='utf-8-sig' adds BOM marker for SQL Server
# compatibility and preserves Unicode characters.
# Integer columns are cast to Int64 before export so
# they write as plain integers (e.g. 299, not 299.0).
# ==========================

for table_name, query in tables.items():
    print(f'Exporting {table_name}...', end=' ')

    df = pd.read_sql(query, conn)

    # Cast integer columns to nullable Int64 to prevent
    # float formatting (299.0) caused by NULLs in the data
    for col in integer_columns.get(table_name, []):
        if col in df.columns:
            df[col] = pd.to_numeric(df[col], errors='coerce').astype('Int64')

    output_path = os.path.join(OUTPUT_FOLDER, f'{table_name}.csv')
    df.to_csv(output_path, index=False, encoding='utf-8-sig')

    print(f'{len(df):,} rows exported to {output_path}')

# ==========================
# CLEANUP
# ==========================

conn.close()

print('-' * 50)
print('Export complete. All tables saved to source_data/')
print('Next step: run 02_LoadSourceData.sql in SSMS')