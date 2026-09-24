import unittest
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[1]
SCRIPT_DIR = PROJECT_ROOT / "scripts"
TEST_DIR = PROJECT_ROOT / "tests"

CLEANING_SCRIPTS = (
    "03_DrugClass_Cleaning.sql",
    "04_DosageForm_Cleaning.sql",
    "05_Manufacturer_Cleaning.sql",
    "06_Indication_Cleaning.sql",
    "07_Generic_Cleaning.sql",
    "08_Medicine_Cleaning.sql",
    "09_MedicinePackageSize_Cleaning.sql",
    "10_MedicinePackageContainer_Cleaning.sql",
    "11_GenericIndication_Cleaning.sql",
)


class CleaningContractTests(unittest.TestCase):
    def test_all_database_scripts_use_the_sqlcmd_database_variable(self):
        names = ("00_CreateDatabase.sql", "02_LoadSourceData.sql", *CLEANING_SCRIPTS)
        for name in names:
            sql = (SCRIPT_DIR / name).read_text(encoding="utf-8-sig")
            with self.subTest(script=name):
                self.assertIn("USE [$(DatabaseName)]", sql)

        for name in ("12_Validation.sql", "13_ValidationGate.sql"):
            sql = (TEST_DIR / name).read_text(encoding="utf-8-sig")
            with self.subTest(script=name):
                self.assertIn("USE [$(DatabaseName)]", sql)

    def test_destructive_reload_requires_explicit_confirmation(self):
        sql = (SCRIPT_DIR / "02_LoadSourceData.sql").read_text(encoding="utf-8-sig")
        self.assertIn("$(AllowDestructiveReset)", sql)
        self.assertIn("<> 'YES'", sql)
        self.assertIn("$(SourceDataPath)", sql)

    def test_database_creation_quotes_the_configured_name(self):
        sql = (SCRIPT_DIR / "00_CreateDatabase.sql").read_text(encoding="utf-8-sig")
        self.assertIn("QUOTENAME(@DatabaseName)", sql)
        self.assertIn("EXEC sys.sp_executesql @CreateSql", sql)

    def test_full_runner_targets_clean_database_and_includes_all_steps(self):
        runner = (PROJECT_ROOT / "run_full_cleaning.sql").read_text(
            encoding="utf-8-sig"
        )
        self.assertIn(
            ':setvar DatabaseName "PharmaMarketAnalytics_Clean"', runner
        )
        self.assertIn(':setvar AllowDestructiveReset "YES"', runner)

        expected = (
            "00_CreateDatabase.sql",
            "02_LoadSourceData.sql",
            *CLEANING_SCRIPTS,
            "12_Validation.sql",
            "13_ValidationGate.sql",
        )
        positions = []
        for name in expected:
            self.assertEqual(runner.count(name), 1, name)
            positions.append(runner.index(name))
        self.assertEqual(positions, sorted(positions))

    def test_validation_runner_is_read_only(self):
        runner = (PROJECT_ROOT / "run_validation.sql").read_text(encoding="utf-8-sig")
        self.assertIn(
            ':setvar DatabaseName "PharmaMarketAnalytics_Clean"', runner
        )
        self.assertEqual(runner.count("12_Validation.sql"), 1)
        self.assertEqual(runner.count("13_ValidationGate.sql"), 1)
        self.assertNotIn("02_LoadSourceData.sql", runner)

    def test_validation_gate_checks_expected_clean_row_counts(self):
        sql = (TEST_DIR / "13_ValidationGate.sql").read_text(encoding="utf-8-sig")
        expected_counts = {
            "Drug_Class": 422,
            "Dosage_Form": 113,
            "Manufacturer": 240,
            "Indication": 2043,
            "Generic": 1711,
            "Medicine": 21708,
            "Medicine_PackageSize": 14349,
            "Medicine_PackageContainer": 22707,
            "Generic_Indication": 1608,
        }
        for table, count in expected_counts.items():
            with self.subTest(table=table):
                self.assertIn(f"'{table} row count'", sql)
                self.assertIn(f", {count} FROM {table}", sql)


if __name__ == "__main__":
    unittest.main()
