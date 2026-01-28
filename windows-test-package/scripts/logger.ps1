# Logging Modul für eRezept-Automatisierung
# JSONL-basiertes Logging mit Audit-Trail

function ConvertTo-JsonLineCompat {
    param(
        [hashtable]$Object
    )

    # PowerShell 2.0 does not provide ConvertTo-Json. Fall back to a minimal JSON serializer.
    if (Get-Command ConvertTo-Json -ErrorAction SilentlyContinue) {
        return ($Object | ConvertTo-Json -Compress)
    }

    function Escape-JsonString {
        param([string]$Value)

        if ($null -eq $Value) { return "" }
        return ($Value -replace "\\", "\\\\" -replace '"', '\\"' -replace "\r", "" -replace "\n", "\\n")
    }

    $parts = @()
    foreach ($key in $Object.Keys) {
        $val = $Object[$key]

        if ($null -eq $val) {
            $parts += ('"{0}":null' -f (Escape-JsonString $key))
        }
        elseif ($val -is [bool]) {
            $parts += ('"{0}":{1}' -f (Escape-JsonString $key), ($(if ($val) { 'true' } else { 'false' })))
        }
        elseif ($val -is [int] -or $val -is [long] -or $val -is [double] -or $val -is [decimal]) {
            $parts += ('"{0}":{1}' -f (Escape-JsonString $key), $val)
        }
        else {
            $parts += ('"{0}":"{1}"' -f (Escape-JsonString $key), (Escape-JsonString ([string]$val)))
        }
    }

    return ('{' + ($parts -join ',') + '}')
}

function ConvertFrom-JsonLineCompat {
    param(
        [string]$Line
    )

    # PowerShell 2.0 does not provide ConvertFrom-Json. Fall back to a minimal parser
    # extracting only the fields we need for duplicate detection.
    if (Get-Command ConvertFrom-Json -ErrorAction SilentlyContinue) {
        return ($Line | ConvertFrom-Json)
    }

    $result = @{}
    if ([string]::IsNullOrEmpty($Line)) {
        return $result
    }

    $mHash = [regex]::Match($Line, '"file_hash"\s*:\s*"(?<v>[^"]*)"')
    if ($mHash.Success) { $result.file_hash = $mHash.Groups['v'].Value }

    $mStatus = [regex]::Match($Line, '"status"\s*:\s*"(?<v>[^"]*)"')
    if ($mStatus.Success) { $result.status = $mStatus.Groups['v'].Value }

    $mTs = [regex]::Match($Line, '"timestamp"\s*:\s*"(?<v>[^"]*)"')
    if ($mTs.Success) { $result.timestamp = $mTs.Groups['v'].Value }

    return $result
}

function Get-Sha256FileHashCompat {
    param(
        [string]$FilePath
    )

    if ([string]::IsNullOrEmpty($FilePath)) {
        return $null
    }

    # Prefer the built-in cmdlet when available (PS 4+), otherwise compute via .NET (PS 2 compatible).
    $builtinCmdlet = Get-Command Get-FileHash -CommandType Cmdlet -ErrorAction SilentlyContinue
    if ($builtinCmdlet) {
        try {
            $hash = Microsoft.PowerShell.Utility\Get-FileHash -Path $FilePath -Algorithm $ProcessingConfig.HashAlgorithm
            return $hash.Hash
        }
        catch {
            # Reason: On older PowerShell versions the cmdlet may not exist; fall back to .NET.
        }
    }

    $stream = $null
    try {
        $stream = [System.IO.File]::OpenRead($FilePath)
        $sha = New-Object System.Security.Cryptography.SHA256Managed
        $bytes = $sha.ComputeHash($stream)
        $hex = New-Object System.Text.StringBuilder
        foreach ($b in $bytes) {
            $null = $hex.AppendFormat('{0:x2}', $b)
        }
        return $hex.ToString().ToUpperInvariant()
    }
    finally {
        if ($stream) { $stream.Dispose() }
    }
}

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
        
        # In JSON konvertieren (PS2-compatible fallback)
        $jsonLine = ConvertTo-JsonLineCompat -Object $logEntry
        
        # In Log-Datei schreiben (append-only)
        $logFile = Join-Path $Config.LogFolder "erezept_$(Get-Date -Format 'yyyy-MM-dd').jsonl"
        Add-Content -Path $logFile -Value $jsonLine -Encoding UTF8
        
        # Bei bestimmten Status auch in Konsole ausgeben
        if ($Status -eq "ERROR" -or $Status -eq "WARN") {
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
        return (Get-Sha256FileHashCompat -FilePath $FilePath)
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
                    $entry = ConvertFrom-JsonLineCompat -Line $line
                    $isProcessedStatus = ($entry.status -eq $LogConfig.Status_SENT -or $entry.status -eq $LogConfig.Status_ROUTED -or $entry.status -eq $LogConfig.Status_COMPLETED)
                    if ($entry.file_hash -eq $FileHash -and $isProcessedStatus) {
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
                    $entry = ConvertFrom-JsonLineCompat -Line $line
                    
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
