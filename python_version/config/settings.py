"""
Configuration settings for eRezept-Automatisierung.
"""
from pathlib import Path

# Base directory (python_version folder)
BASE_DIR = Path(__file__).parent.parent

# Folder paths
INPUT_FOLDER = BASE_DIR / "input"
OUTPUT_FOLDER = BASE_DIR / "output"
LOGS_FOLDER = BASE_DIR / "logs"
DATA_FOLDER = BASE_DIR / "data"

# CSV file paths
PATIENT_APO_MAPPING_CSV = DATA_FOLDER / "patient_apo_mapping.csv"
KIM_APO_MAPPING_CSV = DATA_FOLDER / "KIM_apo_mapping.CSV"

# CSV column indices (0-indexed for Python)
CSV_COLUMNS = {
    "last_name": 2,      # Column 3 in 1-indexed = Nachname
    "first_name": 4,     # Column 5 in 1-indexed = Vorname
    "birth_date": 5,     # Column 6 in 1-indexed = Geburtsdatum
    "apo_key": 34,       # Column 35 in 1-indexed = Inhalt (APO_KEY)
}

# OCR settings
OCR_LANGUAGE = "deu"
OCR_DPI = 300

# Processing settings
DRY_RUN = True  # If True, don't send emails
FILE_PATTERN = "*.pdf"
