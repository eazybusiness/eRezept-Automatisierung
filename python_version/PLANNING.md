# eRezept-Automatisierung (Python Version)

## Goal
Create a Python-based solution for processing e-prescription PDFs:
1. Extract patient name and birthdate from PDF via OCR
2. Look up assigned pharmacy from CSV mapping
3. Route PDFs to pharmacy-specific folders
4. Log all processing steps

## Architecture

### Components
- `main.py`: Main entry point and orchestration
- `config/settings.py`: Configuration (paths, CSV columns)
- `src/pdf_processor.py`: PDF to text extraction (OCR)
- `src/csv_lookup.py`: Patient-to-pharmacy mapping
- `src/file_router.py`: File routing logic

### Data Flow
```
input/ (PDFs) -> OCR extraction -> patient lookup -> route to output/<APO_KEY>/
```

### Dependencies
- **pdf2image**: Convert PDF pages to images (requires poppler)
- **pytesseract**: OCR wrapper for Tesseract
- **Pillow**: Image processing

Note: Tesseract OCR and Poppler are external dependencies that must be installed.

## CSV Structure (Customer Data)
- Column 3: Nachname (Last Name)
- Column 5: Vorname (First Name)
- Column 6: Geburtsdatum (Birth Date)
- Column 35: Inhalt (contains APO_KEY like "APO_BAEREN")

## Safety
- Dry-run mode by default (no email sending)
- Customer data (CSVs, PDFs) must never be committed to git
