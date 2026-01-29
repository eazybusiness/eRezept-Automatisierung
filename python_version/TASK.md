# TASKS (Python Version)

## Completed (2026-01-29)

- [x] Create folder structure
- [x] Copy input files (PDFs, CSVs)
- [x] Create PLANNING.md
- [x] Build main processing script
- [x] Test with 5 PDF files
- [x] Verify pharmacy mapping works
- [x] Write unit tests (13 tests, all passing)
- [x] Create README.md

## Test Results

| Patient | Birthdate | Pharmacy | Status |
|---------|-----------|----------|--------|
| Elisabeth Großmann | 16.08.1946 | APO_BURG_BOVENDEN | ✅ |
| Reinhold Hartje | 14.12.1936 | APO_BAEREN | ✅ |
| Harry Heilmann | 29.04.1949 | APO_FELDTOR | ✅ |
| Astrid Pföhler | 27.03.1939 | APO_MUEHLEN | ✅ |
| Bernd Messerschmidt | 15.06.1959 | unklar | ⚠️ (not in CSV) |

## Requirements

- Python 3.8+
- Tesseract OCR installed (with German language data)
- Poppler (for pdf2image)
