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
# EXPORT
# pandas to_csv handles quoted fields automatically
# encoding='utf-8-sig' adds BOM marker for SQL Server
# compatibility and preserves Unicode characters
# ==========================

for table_name, query in tables.items():
    print(f'Exporting {table_name}...', end=' ')

    df = pd.read_sql(query, conn)

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
