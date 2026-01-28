# Logging Modul für eRezept-Automatisierung
# JSONL-basiertes Logging mit Audit-Trail

function Write-Log {
    <#
    .SYNOPSIS
        Schreibt einen Log-Eintrag im JSONL-Format
    .PARAMETER Message
        Log-Nachricht
    .PARAMETER Status
        Status-Code (INFO, WARN, ERROR, ROUTED, SENT, etc.)
    .PARAMETER PatientName
        Name des Patienten (datensparsam)
    .PARAMETER Pharmacy
        Apotheke/APO_KEY
    .PARAMETER FileHash
        SHA-256 Hash der Datei
    .PARAMETER AdditionalData
        Zusätzliche Daten als Hashtable
    #>
    param(
        [string]$Message,
        [string]$Status = "INFO",
        [string]$PatientName = "",
        [string]$Pharmacy = "",
        [string]$FileHash = "",
        [hashtable]$AdditionalData = @{}
    )
    
    try {
        # Log-Verzeichnis prüfen
        if (-not (Test-Path $Config.LogFolder)) {
            New-Item -ItemType Directory -Path $Config.LogFolder -Force | Out-Null
        }
        
        # Log-Eintrag erstellen
        $logEntry = @{
            timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ss.fffZ"
            status = $Status
            message = $Message
            patient = if ($PatientName) { $PatientName.Substring(0, [Math]::Min(50, $PatientName.Length)) } else { "" }
            pharmacy = $Pharmacy
            file_hash = $FileHash
        }
        
        # Zusätzliche Daten hinzufügen
        $AdditionalData.GetEnumerator() | ForEach-Object {
            $logEntry[$_.Key] = $_.Value
        }
        
        # In JSON konvertieren
        $jsonLine = $logEntry | ConvertTo-Json -Compress
        
        # In Log-Datei schreiben (append-only)
        $logFile = Join-Path $Config.LogFolder "erezept_$(Get-Date -Format 'yyyy-MM-dd').jsonl"
        Add-Content -Path $logFile -Value $jsonLine -Encoding UTF8
        
        # Bei bestimmten Status auch in Konsole ausgeben
        if ($Status -in @("ERROR", "WARN")) {
            Write-Host "[$Status] $Message" -ForegroundColor $(if ($Status -eq "ERROR") { "Red" } else { "Yellow" })
        }
        
        # Log-Rotation prüfen
        Invoke-LogRotation
    }
    catch {
        Write-Host "Fehler beim Logging: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Invoke-LogRotation {
    <#
    .SYNOPSIS
        Prüft und führt Log-Rotation durch
    #>
    try {
        $logFiles = Get-ChildItem -Path $Config.LogFolder -Filter "erezept_*.jsonl" | Sort-Object LastWriteTime -Descending
        
        if ($logFiles.Count -gt $LogConfig.MaxLogFiles) {
            $filesToDelete = $logFiles | Select-Object -Skip $LogConfig.MaxLogFiles
            
            foreach ($file in $filesToDelete) {
                Remove-Item $file.FullName -Force
                Write-Log "Alte Log-Datei gelöscht: $($file.Name)" -Status "INFO"
            }
        }
        
        # Größe der aktuellen Log-Datei prüfen
        $currentLogFile = Join-Path $Config.LogFolder "erezept_$(Get-Date -Format 'yyyy-MM-dd').jsonl"
        if (Test-Path $currentLogFile) {
            $fileInfo = Get-Item $currentLogFile
            $sizeMB = $fileInfo.Length / 1MB
            
            if ($sizeMB -gt $LogConfig.MaxLogSizeMB) {
                # Neue Datei mit Zeitstempel erstellen
                $newLogFile = Join-Path $Config.LogFolder "erezept_$(Get-Date -Format 'yyyy-MM-dd_HHmmss').jsonl"
                Move-Item $currentLogFile $newLogFile
                Write-Log "Log-Datei rotiert wegen Größe: $($sizeMB:N2)MB" -Status "INFO"
            }
        }
    }
    catch {
        Write-Host "Fehler bei Log-Rotation: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Get-FileHash {
    <#
    .SYNOPSIS
        Berechnet SHA-256 Hash für Duplikatschutz
    .PARAMETER FilePath
        Pfad zur Datei
    .RETURNS
        Hash als String oder $null
    #>
    param([string]$FilePath)
    
    try {
        $hash = Microsoft.PowerShell.Utility\Get-FileHash -Path $FilePath -Algorithm $ProcessingConfig.HashAlgorithm
        return $hash.Hash
    }
    catch {
        Write-Log "Fehler bei Hash-Berechnung für $FilePath`: $($_.Exception.Message)" -Status "ERROR"
        return $null
    }
}

function Test-DuplicateFile {
    <#
    .SYNOPSIS
        Prüft ob Datei bereits verarbeitet wurde
    .PARAMETER FileHash
        SHA-256 Hash der Datei
    .RETURNS
        $true wenn Duplikat, sonst $false
    #>
    param([string]$FileHash)
    
    try {
        if (-not $ProcessingConfig.EnableDuplicateCheck) {
            return $false
        }
        
        # Letzte 30 Tage an Log-Dateien durchsuchen
        $cutoffDate = (Get-Date).AddDays(-30)
        $logFiles = Get-ChildItem -Path $Config.LogFolder -Filter "erezept_*.jsonl" | 
                   Where-Object { $_.LastWriteTime -gt $cutoffDate }
        
        foreach ($logFile in $logFiles) {
            $content = Get-Content -Path $logFile.FullName -Encoding UTF8
            foreach ($line in $content) {
                try {
                    $entry = $line | ConvertFrom-Json
                    if ($entry.file_hash -eq $FileHash -and $entry.status -in @($LogConfig.Status_SENT, $LogConfig.Status_ROUTED, $LogConfig.Status_COMPLETED)) {
                        Write-Log "Duplikat erkannt: Hash $FileHash bereits verarbeitet am $($entry.timestamp)" -Status "INFO"
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
    catch {
        Write-Log "Fehler bei Duplikatsprüfung: $($_.Exception.Message)" -Status "ERROR"
        return $false
    }
}

function Send-ErrorNotification {
    <#
    .SYNOPSIS
        Sendet eine E-Mail-Benachrichtigung bei Fehlern
    .PARAMETER Subject
        Betreff der E-Mail
    .PARAMETER Body
        Inhalt der E-Mail
    .PARAMETER Priority
        Priorität (Low, Normal, High)
    #>
    param(
        [string]$Subject,
        [string]$Body,
        [string]$Priority = "Normal"
    )
    
    try {
        if ($KIMConfig.ContainsKey('EnableSend') -and -not $KIMConfig.EnableSend) {
            Write-Log "EnableSend ist deaktiviert. Überspringe Fehlerbenachrichtigung (Dry-Run)." -Status "INFO"
            return
        }

        if (-not $ErrorConfig.EnableErrorNotifications -or -not $KIMConfig.ErrorEmailTo) {
            return
        }
        
        $mailParams = @{
            SmtpServer = $KIMConfig.SmtpServer
            Port = $KIMConfig.SmtpPort
            UseSsl = $KIMConfig.UseSSL
            From = $KIMConfig.EmailFrom
            To = $KIMConfig.ErrorEmailTo
            Subject = $Subject
            Body = $Body
            Priority = $Priority
        }
        
        # Bei Bedarf Authentifizierung hinzufügen (noch zu implementieren)
        # $mailParams.Credential = Get-Credential
        
        Send-MailMessage @mailParams
        
        Write-Log "Fehlerbenachrichtigung gesendet an: $($KIMConfig.ErrorEmailTo)" -Status "INFO"
    }
    catch {
        Write-Log "Fehler beim Senden der Fehlerbenachrichtigung: $($_.Exception.Message)" -Status "ERROR"
    }
}

function Get-LogStatistics {
    <#
    .SYNOPSIS
        Gibt Statistiken über die Logs zurück
    .PARAMETER Days
        Anzahl der Tage für die Statistik
    #>
    param([int]$Days = 7)
    
    try {
        $cutoffDate = (Get-Date).AddDays(-$Days)
        $logFiles = Get-ChildItem -Path $Config.LogFolder -Filter "erezept_*.jsonl" | 
                   Where-Object { $_.LastWriteTime -gt $cutoffDate }
        
        $stats = @{
            TotalEntries = 0
            StatusCounts = @{}
            ProcessedFiles = @{}
            ErrorCount = 0
            DateRange = @{
                Start = $cutoffDate
                End = Get-Date
            }
        }
        
        foreach ($logFile in $logFiles) {
            $content = Get-Content -Path $logFile.FullName -Encoding UTF8
            $stats.TotalEntries += $content.Count
            
            foreach ($line in $content) {
                try {
                    $entry = $line | ConvertFrom-Json
                    
                    # Status zählen
                    if (-not $stats.StatusCounts.ContainsKey($entry.status)) {
                        $stats.StatusCounts[$entry.status] = 0
                    }
                    $stats.StatusCounts[$entry.status]++
                    
                    # Fehler zählen
                    if ($entry.status -eq $LogConfig.Status_ERROR) {
                        $stats.ErrorCount++
                    }
                    
                    # Verarbeitete Dateien
                    if ($entry.file_hash) {
                        $stats.ProcessedFiles[$entry.file_hash] = $entry.status
                    }
                }
                catch {
                    continue
                }
            }
        }
        
        return $stats
    }
    catch {
        Write-Log "Fehler bei Log-Statistik: $($_.Exception.Message)" -Status "ERROR"
        return $null
    }
}
