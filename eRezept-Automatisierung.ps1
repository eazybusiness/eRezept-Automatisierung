<#
.SYNOPSIS
    eRezept-Versand Automatisierung - PowerShell Skript
.DESCRIPTION
    Automatisiert den Versand von eRezept-PDFs an Apotheken über KIM-Dienst.
    Liest Patientennamen aus PDFs,查找 Apotheken in Excel, verschiebt Dateien und sendet E-Mails.
    
    Ablauf:
    1. Überwache Eingangsordner auf neue PDFs
    2. Extrahiere Patientennamen aus PDF-Metadaten/Inhalt
    3. Suche Patient->Apotheke Mapping in Excel-Tabelle
    4. Verschiebe PDF in apothekenspezifischen Unterordner
    5. Suche Apotheke->KIM-Email Mapping in Excel
    6. Sende PDF per KIM-Dienst an Apotheke
    7. Logging mit SHA-256 Hash für Duplikatschutz
    
.NOTES
    Author: Ihr Name
    Version: 1.0
    Requires: PowerShell 5.1+, ImportExcel Module
#>

# ==================== KONFIGURATION ====================
# Alle Pfade relativ zum Skriptverzeichnis
$Config = @{
    # Ordnerpfade
    InputFolder = ".\input"           # Hier landen neue PDFs vom PDFCreator
    PharmacyFolders = ".\pharmacies"  # Unterordner für jede Apotheke
    LogFolder = ".\logs"              # Logdateien
    TempFolder = ".\temp"             # Temporäre Dateien
    
    # Excel-Dateien
    PatientPharmacyMapping = ".\data\patienten_apotheken.xlsx"
    PharmacyEmailMapping = ".\data\apotheken_emails.xlsx"
    
    # Spaltennamen in Excel (anpassen!)
    PatientPharmacySheet = "Sheet1"
    PatientColumn = "Patientenname"
    PharmacyColumn = "Apotheke"
    
    PharmacyEmailSheet = "Sheet1"
    PharmacyNameColumn = "Apotheke"
    EmailColumn = "KIM_Email"
    
    # E-Mail Konfiguration
    # SmtpServer = "kv.dox.kim.telematik"  # KIM-Dienst SMTP (Produktiv)
    SmtpServer = "testserver"          # Test-Host, verhindert versehentlichen Versand
    SmtpPort = 587
    EmailFrom = "praxis@domain.de"
    EmailSubject = "eRezept für {0}"
    EnableSend = $false
    
    # Überwachungseinstellungen
    ScanInterval = 30                 # Sekunden zwischen Scans
    FileExtensions = @("*.pdf")
}

# ==================== MODULE IMPORT ====================
# ImportExcel für Excel-Zugriff (installieren mit: Install-Module -Name ImportExcel)
try {
    Import-Module ImportExcel -ErrorAction Stop
}
catch {
    Write-Error "ImportExcel Modul nicht gefunden. Installieren mit: Install-Module -Name ImportExcel"
    exit 1
}

# ==================== FUNKTIONEN ====================

function Initialize-Directories {
    <#
    .SYNOPSIS
        Erstellt notwendige Verzeichnisse falls nicht vorhanden
    #>
    param($Config)
    
    $folders = @($Config.InputFolder, $Config.PharmacyFolders, $Config.LogFolder, $Config.TempFolder)
    
    foreach ($folder in $folders) {
        if (-not (Test-Path $folder)) {
            New-Item -ItemType Directory -Path $folder -Force | Out-Null
            Write-Log "Verzeichnis erstellt: $folder"
        }
    }
}

function Write-Log {
    <#
    .SYNOPSIS
        Schreibt Log-Einträge in JSONL-Format für Audit-Trail
    #>
    param(
        [string]$Message,
        [string]$Status = "INFO",
        [string]$PatientName = "",
        [string]$Pharmacy = "",
        [string]$FileHash = ""
    )
    
    $logEntry = @{
        timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ss.fffZ"
        status = $Status
        message = $Message
        patient = $PatientName
        pharmacy = $Pharmacy
        file_hash = $FileHash
    } | ConvertTo-Json -Compress
    
    $logFile = Join-Path $Config.LogFolder "erezept_$(Get-Date -Format 'yyyy-MM-dd').jsonl"
    Add-Content -Path $logFile -Value $logEntry -Encoding UTF8
}

function Get-FileHash {
    <#
    .SYNOPSIS
        Berechnet SHA-256 Hash für Duplikatschutz
    #>
    param([string]$FilePath)
    
    try {
        $hash = Microsoft.PowerShell.Utility\Get-FileHash -Path $FilePath -Algorithm SHA256
        return $hash.Hash
    }
    catch {
        Write-Log "Fehler bei Hash-Berechnung: $($_.Exception.Message)" -Status "ERROR"
        return $null
    }
}

function Test-DuplicateFile {
    <#
    .SYNOPSIS
        Prüft ob Datei bereits verarbeitet wurde (Duplikatschutz)
    #>
    param([string]$FileHash)
    
    $logFiles = Get-ChildItem -Path $Config.LogFolder -Filter "*.jsonl" -ErrorAction SilentlyContinue
    
    foreach ($logFile in $logFiles) {
        $content = Get-Content -Path $logFile.FullName -Encoding UTF8
        foreach ($line in $content) {
            try {
                $entry = $line | ConvertFrom-Json
                if ($entry.file_hash -eq $FileHash -and $entry.status -in @("SENT", "ROUTED")) {
                    return $true
                }
            }
            catch {
                continue
            }
        }
    }
    return $false
}

function Extract-PatientNameFromPDF {
    <#
    .SYNOPSIS
        Extrahiert Patientennamen aus PDF-Metadaten oder Inhalt
    #>
    param([string]$FilePath)
    
    try {
        # Versuch 1: PDF-Metadaten auslesen
        $pdfReader = New-Object -ComObject AcroPDFLib.AcroPDF
        $pdfReader.LoadFile($FilePath)
        # Alternative Methode falls COM nicht verfügbar
        
        # Versuch 2: Text aus PDF extrahieren (vereinfacht)
        $text = [System.IO.File]::ReadAllText($FilePath)
        
        # Patientennamen-Muster (anpassen!)
        $patterns = @(
            "Patient:\s*([A-Z][a-z]+\s+[A-Z][a-z]+)",
            "Name:\s*([A-Z][a-z]+\s+[A-Z][a-z]+)",
            "Patientenname:\s*([A-Z][a-z]+\s+[A-Z][a-z]+)"
        )
        
        foreach ($pattern in $patterns) {
            if ($text -match $pattern) {
                return $matches[1].Trim()
            }
        }
        
        return $null
    }
    catch {
        Write-Log "Fehler bei PDF-Extraktion: $($_.Exception.Message)" -Status "ERROR"
        return $null
    }
}

function Get-PharmacyForPatient {
    <#
    .SYNOPSIS
        Sucht Apotheke für Patienten in Excel-Tabelle
    #>
    param([string]$PatientName)
    
    try {
        $data = Import-Excel -Path $Config.PatientPharmacyMapping -WorksheetName $Config.PatientPharmacySheet
        
        $entry = $data | Where-Object { $_.$($Config.PatientColumn) -like "*$PatientName*" } | Select-Object -First 1
        
        if ($entry) {
            return $entry.$($Config.PharmacyColumn)
        }
        
        return $null
    }
    catch {
        Write-Log "Fehler bei Patient->Apotheke Lookup: $($_.Exception.Message)" -Status "ERROR"
        return $null
    }
}

function Get-EmailForPharmacy {
    <#
    .SYNOPSIS
        Sucht KIM-Email für Apotheke in Excel-Tabelle
    #>
    param([string]$PharmacyName)
    
    try {
        $data = Import-Excel -Path $Config.PharmacyEmailMapping -WorksheetName $Config.PharmacyEmailSheet
        
        $entry = $data | Where-Object { $_.$($Config.PharmacyNameColumn) -eq $PharmacyName } | Select-Object -First 1
        
        if ($entry) {
            return $entry.$($Config.EmailColumn)
        }
        
        return $null
    }
    catch {
        Write-Log "Fehler bei Apotheke->Email Lookup: $($_.Exception.Message)" -Status "ERROR"
        return $null
    }
}

function Move-PDFToPharmacyFolder {
    <#
    .SYNOPSIS
        Verschiebt PDF in apothekenspezifischen Unterordner
    #>
    param(
        [string]$SourcePath,
        [string]$PharmacyName,
        [string]$FileHash
    )
    
    try {
        # Zielordner erstellen falls nicht vorhanden
        $targetFolder = Join-Path $Config.PharmacyFolders $PharmacyName
        if (-not (Test-Path $targetFolder)) {
            New-Item -ItemType Directory -Path $targetFolder -Force | Out-Null
        }
        
        $targetPath = Join-Path $targetFolder (Split-Path $SourcePath -Leaf)
        
        # Datei verschieben
        Move-Item -Path $SourcePath -Destination $targetPath -Force
        
        Write-Log "PDF verschoben nach: $targetPath" -Status "ROUTED" -Pharmacy $PharmacyName -FileHash $FileHash
        
        return $targetPath
    }
    catch {
        Write-Log "Fehler beim Verschieben: $($_.Exception.Message)" -Status "ERROR" -Pharmacy $PharmacyName -FileHash $FileHash
        return $null
    }
}

function Send-PDFViaKIM {
    <#
    .SYNOPSIS
        Sendet PDF per KIM-Dienst (E-Mail) an Apotheke
    #>
    param(
        [string]$PDFPath,
        [string]$PharmacyName,
        [string]$RecipientEmail,
        [string]$PatientName,
        [string]$FileHash
    )
    
    try {
        if ($Config.ContainsKey('EnableSend') -and -not $Config.EnableSend) {
            Write-Log "EnableSend ist deaktiviert. Überspringe E-Mail-Versand (Dry-Run) an: $RecipientEmail" -Status "INFO" -Patient $PatientName -Pharmacy $PharmacyName -FileHash $FileHash
            return $true
        }

        $subject = $Config.EmailSubject -f $PatientName
        $body = "Sehr geehrte Apotheke,`n`nAnbei das eRezept für Patienten: $PatientName`n`nMit freundlichen Grüßen`nIhre Praxis"
        
        $mailParams = @{
            SmtpServer = $Config.SmtpServer
            Port = $Config.SmtpPort
            From = $Config.EmailFrom
            To = $RecipientEmail
            Subject = $subject
            Body = $body
            Attachments = $PDFPath
            Encoding = "UTF8"
        }
        
        Send-MailMessage @mailParams
        
        Write-Log "PDF gesendet an: $RecipientEmail" -Status "SENT" -Patient $PatientName -Pharmacy $PharmacyName -FileHash $FileHash
        
        return $true
    }
    catch {
        Write-Log "Fehler beim E-Mail-Versand: $($_.Exception.Message)" -Status "ERROR" -Patient $PatientName -Pharmacy $PharmacyName -FileHash $FileHash
        return $false
    }
}

function Process-NewPDFs {
    <#
    .SYNOPSIS
        Hauptverarbeitungsfunktion für neue PDFs
    #>
    Write-Log "Scanne nach neuen PDFs..." -Status "INFO"
    
    # Neue PDFs suchen
    $pdfFiles = Get-ChildItem -Path $Config.InputFolder -Filter $Config.FileExtensions -ErrorAction SilentlyContinue
    
    foreach ($pdf in $pdfFiles) {
        try {
            Write-Log "Verarbeite Datei: $($pdf.Name)" -Status "INFO"
            
            # Hash für Duplikatschutz
            $fileHash = Get-FileHash -FilePath $pdf.FullName
            if (-not $fileHash) {
                continue
            }
            
            # Duplikatsprüfung
            if (Test-DuplicateFile -FileHash $fileHash) {
                Write-Log "Duplikat erkannt, überspringe: $($pdf.Name)" -Status "DUPLICATE_BLOCKED" -FileHash $fileHash
                continue
            }
            
            # Patientennamen extrahieren
            $patientName = Extract-PatientNameFromPDF -FilePath $pdf.FullName
            if (-not $patientName) {
                Write-Log "Kein Patientenname gefunden: $($pdf.Name)" -Status "UNKLAR" -FileHash $fileHash
                continue
            }
            
            Write-Log "Patient gefunden: $patientName" -Status "INFO" -Patient $patientName -FileHash $fileHash
            
            # Apotheke suchen
            $pharmacy = Get-PharmacyForPatient -PatientName $patientName
            if (-not $pharmacy) {
                Write-Log "Keine Apotheke gefunden für: $patientName" -Status "UNKLAR" -Patient $patientName -FileHash $fileHash
                continue
            }
            
            # PDF verschieben
            $movedPath = Move-PDFToPharmacyFolder -SourcePath $pdf.FullName -PharmacyName $pharmacy -FileHash $fileHash
            if (-not $movedPath) {
                continue
            }
            
            # KIM-Email suchen
            $kimEmail = Get-EmailForPharmacy -PharmacyName $pharmacy
            if (-not $kimEmail) {
                Write-Log "Keine KIM-Email gefunden für Apotheke: $pharmacy" -Status "UNKLAR" -Patient $patientName -Pharmacy $pharmacy -FileHash $fileHash
                continue
            }
            
            # PDF senden
            $sent = Send-PDFViaKIM -PDFPath $movedPath -PharmacyName $pharmacy -RecipientEmail $kimEmail -PatientName $patientName -FileHash $fileHash
            
            if ($sent) {
                Write-Log "Prozess abgeschlossen für: $($pdf.Name)" -Status "COMPLETED" -Patient $patientName -Pharmacy $pharmacy -FileHash $fileHash
            }
        }
        catch {
            Write-Log "Allgemeiner Fehler bei $($pdf.Name): $($_.Exception.Message)" -Status "ERROR"
        }
    }
}

# ==================== HAUPTPROGRAMM ====================
function Start-eRezeptAutomation {
    <#
    .SYNOPSIS
        Hauptfunktion - startet die Überwachungsschleife
    #>
    
    Write-Host "eRezept-Versand Automatisierung gestartet" -ForegroundColor Green
    Write-Host "Überwache Ordner: $($Config.InputFolder)" -ForegroundColor Yellow
    
    # Initialisierung
    Initialize-Directories -Config $Config
    Write-Log "eRezept-Automatisierung gestartet" -Status "INFO"
    
    # Endlosschleife für Dienstbetrieb
    while ($true) {
        try {
            Process-NewPDFs
            Start-Sleep -Seconds $Config.ScanInterval
        }
        catch {
            Write-Log "Kritischer Fehler in Hauptschleife: $($_.Exception.Message)" -Status "ERROR"
            Start-Sleep -Seconds 60  # Bei Fehlern länger warten
        }
    }
}

# Skript starten
if (-not $PSScriptRoot) {
    $PSScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
}

Start-eRezeptAutomation
