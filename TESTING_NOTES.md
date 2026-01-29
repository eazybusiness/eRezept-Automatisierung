# Testing Notes - Version 2

## Download Package

The updated test package is available at:
**http://localhost:8080/erezept-test-package-v2.zip**

## What Was Fixed

### Patient Name Extraction Bug

**Before**: Script extracted "Tobias Frank (15.01.2026)" - the doctor's name
**After**: Script now correctly extracts patient names like "Reinhold Hartje (14.12.1936)"

The fix ensures the regex only looks at the patient section of the e-prescription, not the doctor section.

## Testing Instructions

1. **Download** the new package from the web server
2. **Extract** to your Windows test machine
3. **Copy your test PDFs** to `windows-test-package\local-inbox\`
4. **Run** the test: `run-test.cmd`

## Expected Results

For the 5 test PDFs you mentioned:
- ✅ Elisabeth Großmann (16.08.1946) - Should be found
- ✅ Reinhold Hartje (14.12.1936) - Should be found  
- ✅ Bernd Messerschmidt (15.06.1959) - Should be found
- ✅ Astrid Pföhler (27.03.1939) - Should be found
- ⚠️ Harry Heilmann (29.04.1949) - Check if this patient exists in CSV

## Pharmacy Lookup

The pharmacy extraction is working correctly with the pattern `APO_*`. 

If patients are not found in the pharmacy mapping:
1. Check if the patient exists in `data\patient_apo_mapping.csv`
2. Verify the name format matches: "Nachname;Vorname;Geburtsdatum"
3. Check the "Inhalt" column contains the `APO_*` pattern

## Debug Information

The script creates debug files in `temp\ocr_debug_*.txt` showing the exact OCR output for each PDF. Check these files if extraction fails.

## Known Limitations

- Patient names must be in format "Vorname Nachname" (first name, last name)
- Birthdate must be in format "DD.MM.YYYY"
- The CSV must contain the patient with exact name match (case-sensitive)

## Next Steps

After testing, please provide:
1. Which patients were successfully extracted
2. Which patients failed (if any)
3. The OCR debug output for any failures
4. Client feedback on pharmacy mapping structure
