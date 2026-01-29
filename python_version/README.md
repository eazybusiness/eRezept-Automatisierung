# eRezept-Automatisierung (Python Version)

Processes e-prescription PDFs by extracting patient information via OCR and routing them to pharmacy-specific folders.

## Features

- **PDF OCR**: Extracts text from scanned prescription PDFs using Tesseract
- **Patient Extraction**: Identifies patient name and birthdate from OCR text
- **Pharmacy Lookup**: Maps patients to pharmacies using CSV data
- **File Routing**: Organizes PDFs into pharmacy-specific output folders

## Requirements

### System Dependencies

```bash
# Ubuntu/Debian
sudo apt-get install tesseract-ocr tesseract-ocr-deu poppler-utils

# macOS
brew install tesseract tesseract-lang poppler

# Windows
# Install Tesseract from: https://github.com/UB-Mannheim/tesseract/wiki
# Install Poppler from: https://github.com/oschwartz10612/poppler-windows/releases
```

### Python Dependencies

```bash
python3 -m venv .venv
source .venv/bin/activate  # Linux/macOS
# .venv\Scripts\activate   # Windows

pip install -r requirements.txt
```

## Usage

1. Place PDF files in `input/` folder
2. Ensure CSV mapping files are in `data/` folder:
   - `patient_apo_mapping.csv` - Patient to pharmacy mapping
   - `KIM_apo_mapping.CSV` - Pharmacy to KIM email mapping
3. Run the script:

```bash
python main.py
```

4. Processed PDFs will be routed to `output/<APO_KEY>/` folders

## Project Structure

```
python_version/
├── main.py              # Main entry point
├── config/
│   └── settings.py      # Configuration
├── src/
│   ├── pdf_processor.py # OCR extraction
│   ├── csv_lookup.py    # Patient-pharmacy mapping
│   └── file_router.py   # File routing
├── data/                # CSV mapping files (not in git)
├── input/               # Input PDFs (not in git)
├── output/              # Routed PDFs (not in git)
└── logs/                # Processing logs
```

## CSV Format

### patient_apo_mapping.csv (semicolon-delimited)
- Column 3: Nachname (Last Name)
- Column 5: Vorname (First Name)
- Column 6: Geburtsdatum (Birth Date, DD.MM.YYYY)
- Column 35: Sozialanamnese (contains APO_KEY like "APO_BAEREN")

### KIM_apo_mapping.CSV (semicolon-delimited)
- KIM_APO: Pharmacy key
- KIM_ADDR: KIM email address
- APO_NAME: Pharmacy name

## Test Results

Successfully tested with 5 prescription PDFs:
- ✅ Elisabeth Großmann → APO_BURG_BOVENDEN
- ✅ Reinhold Hartje → APO_BAEREN
- ✅ Harry Heilmann → APO_FELDTOR
- ✅ Astrid Pföhler → APO_MUEHLEN
- ⚠️ Bernd Messerschmidt → unklar (patient not in CSV database)
