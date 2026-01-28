# Windows Test Package (Quick Start)

This folder is a **self-contained test package** intended to be copied to a Windows machine (e.g. `Downloads`) and executed immediately.

## What this package does

- Uses **relative paths only** (no `C:\Daten\ERP\...`).
- Creates all required subfolders inside this package folder.
- Runs in **Dry-Run** by default:
  - `EnableSend = $false`
  - SMTP host is set to `testserver`
  - No outbound emails are sent.

## Folder overview

- `local-inbox/` - drop real customer PDFs here (local only)
- `pharmacies/` - routed PDFs per APO_KEY
- `sent/` - processed (sent or dry-run) PDFs
- `unklar/` - PDFs that could not be matched
- `logs/` - JSONL logs
- `local-data/` - drop real customer mapping CSVs here (local only)
- `data/` - sample mapping files (committed)
- `tools/` - OCR tools (Tesseract + Ghostscript)

## 1) Copy to Windows

Copy this folder to a local path, e.g.:

- `C:\Users\<you>\Downloads\windows-test-package\`

## 2) Check PowerShell version

In `cmd.exe`:

```cmd
powershell -Command "$PSVersionTable.PSVersion"
```

## 3) Run (one command)

Open PowerShell and run:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
Set-Location "C:\Users\<you>\Downloads\windows-test-package"
.\run-test.ps1
```

If PowerShell refuses to run scripts due to policy restrictions, use the launcher:

```cmd
run-test.cmd
```

Stop with:

- `Ctrl + C`

## 4) Provide OCR tools (required for real PDF extraction)

For OCR-based extraction, these files must exist:

- `tools\tesseract.exe`
- `tools\tessdata\deu.traineddata`
- `tools\gswin64c.exe`

If they are missing, the script will log errors and routing will likely fail.

## 5) Test cycle

- Put real customer PDFs into `local-inbox/`
- Put real customer mappings into `local-data/`:
  - `patient_apo_mapping.csv`
  - `KIM_apo_mapping.csv`
- Watch `logs/` for status updates
- Check moved files in `pharmacies/`, `unklar/`, `sent/`

## Safety note

Do not set `EnableSend = $true` during testing.
