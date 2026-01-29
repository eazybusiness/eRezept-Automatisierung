# Quick VM Testing Workflow - NO VirtualBox Sharing Needed!

## HTTP Server Running on Host
- **URL:** http://192.168.1.111:8080
- **Status:** ✅ RUNNING

---

## STEP 1: Download Files to Windows VM (ONE TIME)

### In Windows VM - Open PowerShell (Admin):

```powershell
# Download the test package
Invoke-WebRequest -Uri "http://192.168.1.111:8080/windows-test-package.zip" -OutFile "$env:USERPROFILE\Downloads\windows-test-package.zip"

# Extract it
Expand-Archive -Path "$env:USERPROFILE\Downloads\windows-test-package.zip" -DestinationPath "$env:USERPROFILE\Desktop" -Force

# Navigate to it
cd "$env:USERPROFILE\Desktop\windows-test-package"

# Run diagnostics
.\diagnose.cmd
```

---

## STEP 2: Test-Modify-Copy Cycle

### A. Run Test in Windows VM
```powershell
cd $env:USERPROFILE\Desktop\windows-test-package
.\run-test.cmd
```

### B. Copy Error Messages (Manual)
1. **In Windows VM**: Select error text → Right-click → Copy
2. **On Linux Host**: Open text editor → Paste
3. **Save to file**: `/home/nop/CascadeProjects/eRezept-Automatisierung/vm-errors.txt`

### C. Modify Code on Linux Host
```bash
# Edit your scripts
vim /home/nop/CascadeProjects/eRezept-Automatisierung/windows-test-package/scripts/pdf-ocr.ps1

# The HTTP server will automatically serve the updated files
```

### D. Download Updated Files in Windows VM
```powershell
# Download specific updated script
Invoke-WebRequest -Uri "http://192.168.1.111:8080/windows-test-package/scripts/pdf-ocr.ps1" -OutFile "$env:USERPROFILE\Desktop\windows-test-package\scripts\pdf-ocr.ps1"

# Or re-download entire package
Invoke-WebRequest -Uri "http://192.168.1.111:8080/windows-test-package.zip" -OutFile "$env:USERPROFILE\Downloads\windows-test-package.zip"
Expand-Archive -Path "$env:USERPROFILE\Downloads\windows-test-package.zip" -DestinationPath "$env:USERPROFILE\Desktop" -Force
```

### E. Test Again
```powershell
cd $env:USERPROFILE\Desktop\windows-test-package
.\run-test.cmd
```

---

## QUICK COMMANDS FOR WINDOWS VM

### Download Single Script (Fast Updates)
```powershell
# Update pdf-ocr.ps1
Invoke-WebRequest -Uri "http://192.168.1.111:8080/windows-test-package/scripts/pdf-ocr.ps1" -OutFile "$env:USERPROFILE\Desktop\windows-test-package\scripts\pdf-ocr.ps1"

# Update logger.ps1
Invoke-WebRequest -Uri "http://192.168.1.111:8080/windows-test-package/scripts/logger.ps1" -OutFile "$env:USERPROFILE\Desktop\windows-test-package\scripts\logger.ps1"

# Update csv-lookup.ps1
Invoke-WebRequest -Uri "http://192.168.1.111:8080/windows-test-package/scripts/csv-lookup.ps1" -OutFile "$env:USERPROFILE\Desktop\windows-test-package\scripts\csv-lookup.ps1"

# Update run-test.ps1
Invoke-WebRequest -Uri "http://192.168.1.111:8080/windows-test-package/run-test.ps1" -OutFile "$env:USERPROFILE\Desktop\windows-test-package\run-test.ps1"
```

### View Logs
```powershell
cd $env:USERPROFILE\Desktop\windows-test-package\logs
Get-Content *.jsonl | Select-Object -Last 20
```

### Copy Log Contents (to paste on host)
```powershell
Get-Content logs\*.jsonl | Set-Clipboard
# Then paste on Linux host
```

---

## WORKFLOW SUMMARY

```
┌─────────────────────────────────────────────────────────────┐
│ 1. Edit code on Linux                                       │
│    /home/nop/CascadeProjects/eRezept-Automatisierung/      │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ 2. Download updated file in Windows VM                      │
│    Invoke-WebRequest http://192.168.1.111:8080/...         │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ 3. Test in Windows VM                                       │
│    .\run-test.cmd or .\diagnose.cmd                        │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ 4. Copy error messages manually                             │
│    Select → Copy → Paste in Linux text editor              │
└─────────────────────────────────────────────────────────────┘
                            ↓
                      Repeat from step 1
```

---

## TIPS FOR FASTER WORKFLOW

### Create PowerShell Aliases in VM
```powershell
# Add to PowerShell profile
function Update-Scripts {
    Invoke-WebRequest -Uri "http://192.168.1.111:8080/windows-test-package.zip" -OutFile "$env:USERPROFILE\Downloads\windows-test-package.zip"
    Expand-Archive -Path "$env:USERPROFILE\Downloads\windows-test-package.zip" -DestinationPath "$env:USERPROFILE\Desktop" -Force
    Write-Host "Scripts updated!" -ForegroundColor Green
}

function Test-ERP {
    cd "$env:USERPROFILE\Desktop\windows-test-package"
    .\run-test.cmd
}

# Usage:
# Update-Scripts
# Test-ERP
```

### Browse All Files
Open browser in Windows VM: http://192.168.1.111:8080

---

## STOP HTTP SERVER (when done)

On Linux host:
```bash
# Find the process
ps aux | grep "python3 -m http.server"

# Kill it
pkill -f "python3 -m http.server 8080"
```

---

## TROUBLESHOOTING

### Can't access http://192.168.1.111:8080
1. Check VM network mode: Should be NAT (already configured)
2. Test in VM browser first: http://192.168.1.111:8080
3. If fails, try: http://10.0.2.2:8080 (VirtualBox NAT gateway)

### Downloads fail
```powershell
# Bypass SSL/TLS issues
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Invoke-WebRequest -Uri "http://192.168.1.111:8080/windows-test-package.zip" -OutFile "$env:USERPROFILE\Downloads\windows-test-package.zip"
```

### Manual typing errors
Type this short URL in VM browser: **192.168.1.111:8080**
Then download files by clicking

---

**NO GUEST ADDITIONS NEEDED! NO SHARED FOLDERS! NO DRAG & DROP!**

Just HTTP downloads and manual copy/paste for errors. Simple and works immediately!
