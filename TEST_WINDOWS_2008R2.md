# Windows Test Guide (Windows Server 2008 R2)

This document describes how to test the complete project on **Windows Server 2008 R2** from a USB stick, with a strict focus on **test mode (no outbound sending)**.

## Scope

- Run the automation from the project folder copied to a USB stick.
- Verify:
  - folder scanning
  - PDF processing/OCR
  - CSV lookups
  - routing/moving files to target folders
  - logging
  - duplicate detection
  - **no email is sent during tests**

## Safety: “No Data Must Be Sent”

### Default safety configuration (already set)

In `config/settings.ps1`:

- `EnableSend = $false`
- `SmtpServer = "testserver"`
- The real KIM host is kept commented:
  - `# SmtpServer = "kv.dox.kim.telematik"`

This means:

- The script will **not call SMTP sending** during testing.
- Even error notifications are suppressed from sending.

### Extra safety layer (recommended)

If you want a second safety barrier:

- Disconnect the test server from the network during the first test run.

## Prerequisites

### 1) Windows PowerShell version

Windows Server 2008 R2 uses **Windows PowerShell**, not PowerShell Core (`pwsh`).

Check PowerShell version:

From `cmd.exe`:

```cmd
powershell -Command "$PSVersionTable.PSVersion"
```

From PowerShell:

```powershell
$PSVersionTable.PSVersion
```

Expected:

- PowerShell **2.0** is often preinstalled on 2008 R2.
- Some features may require higher versions (WMF upgrade). If you see problems, we can decide on WMF/PowerShell upgrades.

### 2) Write permissions

The configured paths in `config/settings.ps1` require that the executingC:\Daten\ERP\... folders exist and are writable.

Ensure these exist (example):

- `C:\Daten\ERP\Heim_INBOX`
- `C:\Daten\ERP\Heim\Apotheken`
- `C:\Daten\ERP\Heim\UNKLAR`
- `C:\Daten\ERP\Heim_SENT`
- `C:\Daten\ERP\Heim_LOGGING`
- `C:\Daten\ERP\Heim\DEADLETTER`

### 3) Tools

The OCR pipeline expects these files (relative to the project root or script location, depending on how you run it):

- `tools\tesseract.exe`
- `tools\tessdata\deu.traineddata`
- `tools\gswin64c.exe`

If they are not present yet, you can install them using the project’s setup scripts (may require internet access):

- `scripts\setup-tools.ps1`

## USB Copy / Folder Layout

1. Copy the **entire** project folder to USB, e.g.:

- `E:\eRezept-Automatisierung\`

2. Copy it from USB to a local folder on the server (recommended for permissions/performance):

- `C:\eRezept-Automatisierung\`

## Configure “Test Mode”

Open (Edit):

- `C:\eRezept-Automatisierung\config\settings.ps1`

Confirm:

- `EnableSend = $false`
- `SmtpServer = "testserver"`

Do **not** enable sending during tests.

## Prepare Test Data

### 1) Test PDFs

Place a few test PDFs into:

- `C:\Daten\ERP\Heim_INBOX`

The default file pattern is:

- `ERP_NEURO_*.pdf`

So names like:

- `ERP_NEURO_2026-01-15_1001.pdf`

### 2) Test CSV mapping files

Ensure these exist:

- `C:\Daten\ERP\patient_apo_mapping.csv`
- `C:\Daten\ERP\KIM_apo_mapping.csv`

For tests, use **test-only** data.

## Running the automation (manual console test)

### 1) Open an elevated PowerShell

- Start Menu
- Right click “Windows PowerShell”
- Run as Administrator

### 2) Allow script execution for this session only

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

### 3) Start from the project folder

```powershell
Set-Location "C:\eRezept-Automatisierung"
```

### 4) Start the script

Current entry script:

```powershell
.\eRezept-Automatisierung.ps1
```

### 5) Stop the script

The script runs in a loop. Stop it with:

- `Ctrl + C`

## What to verify (test checklist)

### A) Startup

- Script starts without errors.
- Required folders are created (if the script does so) or errors are logged clearly.

### B) Processing pipeline

For each PDF placed in `Heim_INBOX`:

- A log entry appears in `C:\Daten\ERP\Heim_LOGGING`.
- The system tries OCR extraction.
- Patient + birthdate are found (or it logs `UNKLAR`).
- CSV lookup resolves an `APO_KEY`.
- The PDF is moved to the correct target folder or `UNKLAR`.

### C) Duplicate detection

- Put the same PDF again into `Heim_INBOX`.
- Verify it is detected as duplicate (based on hash + logs).

### D) No email sending (critical)

With `EnableSend = $false`:

- There must be **no SMTP traffic**.
- You should see logs like:
  - `EnableSend ist deaktiviert. Überspringe E-Mail-Versand (Dry-Run)`

## Logs: where to look

- Folder:
  - `C:\Daten\ERP\Heim_LOGGING`
- Format:
  - JSONL: one JSON object per line

Useful quick checks:

- Search for `ERROR`
- Search for `UNKLAR`
- Search for `DUPLICATE_BLOCKED`
- Search for `EnableSend`

## Troubleshooting

### 1) Script does not start (ExecutionPolicy)

- Run:
  - `Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass`

### 2) OCR tools not found

- Verify `tools\` paths exist.
- Verify `config/settings.ps1` matches the shipped tool filenames.

### 3) Permissions / Access denied

- Ensure `C:\Daten\ERP\...` exists.
- Ensure the running user has full access.

### 4) No files are picked up

- Check the filename pattern:
  - `ERP_NEURO_*.pdf`
- Ensure PDFs are placed in:
  - `C:\Daten\ERP\Heim_INBOX`

### 5) CSV lookup fails

- Ensure files exist at:
  - `C:\Daten\ERP\patient_apo_mapping.csv`
  - `C:\Daten\ERP\KIM_apo_mapping.csv`
- Confirm delimiter is `;` and encoding is UTF-8.

## When can we say “ready / finished”?

The project can be considered ready for production enablement only if:

- No crashes over an extended run (e.g. 4-8 hours continuous).
- Correct routing for a representative sample of PDFs.
- `UNKLAR` cases are acceptable and handled.
- Duplicate protection prevents double processing reliably.
- Logs are complete and readable.
- **Email sending remains disabled during tests** and only gets enabled with an explicit, documented action.

## Enabling sending later (NOT FOR TEST)

Only after all tests pass:

- Set in `config/settings.ps1`:
  - `EnableSend = $true`
- Replace `SmtpServer = "testserver"` with the real host.

Do this only when you explicitly start a production rollout.
