# Changelog - eRezept-Automatisierung

## Version 2 (2026-01-29)

### Critical Fix: Patient Name Extraction

**Problem**: The OCR was correctly reading the PDF text, but the regex pattern was extracting the **doctor's name** (Tobias Frank) instead of the **patient's name**.

**Root Cause**: The e-prescription format contains two name+date combinations:
1. Patient: After "für geboren am" (for born on)
2. Doctor: After "ausgestellt von" (issued by)

The old regex matched ANY name+date pattern, so it often caught the doctor's name which appears later in the document.

**Solution**: 
- Extract only the text section between "für geboren am" and "ausgestellt von"
- Search for name+date pattern only within this patient section
- Added safety check to skip names containing "Frank", "Dr.", or "med."

**Test Results**:
- ✅ Elisabeth Großmann 16.08.1946 - Now correctly extracted
- ✅ Reinhold Hartje 14.12.1936 - Now correctly extracted
- ✅ Bernd Messerschmidt 15.06.1959 - Now correctly extracted
- ✅ Astrid Pföhler 27.03.1939 - Now correctly extracted

### Pharmacy Mapping Status

The client is still working on the pharmacy mapping structure. Current approach:
- Extract pharmacy keys using pattern `APO_*` from the CSV "Inhalt" column
- This is working correctly in the code (line 59 in `csv-lookup.ps1`)
- Waiting for client confirmation on final pharmacy mapping structure

### Files Changed

- `windows-test-package/scripts/pdf-ocr.ps1`: Lines 143-205
  - Replaced simple regex patterns with section-based extraction
  - Added doctor name filter as safety check
  - Improved pattern matching for multi-part names

## Version 1 (2026-01-28)

### Initial Release

- PowerShell 2.0 compatible test package
- PDF processing with Ghostscript and Tesseract OCR
- CSV-based patient and pharmacy lookup
- JSONL logging with duplicate detection
- Dry-run mode for safe testing
