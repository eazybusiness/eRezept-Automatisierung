# CSV-Lookup Modul für eRezept-Automatisierung
# Sucht Apotheken und KIM-Adressen in CSV-Dateien

# Cache für Performance
$script:PatientCache = @{}
$script:KIMCache = @{}
$script:CacheTimestamp = $null

function Read-Utf8TextFileCompat {
    param(
        [string]$Path
    )

    # Reason: PowerShell 2.0 lacks Import-Csv -Encoding; ensure we can reliably read UTF-8.
    $bytes = [System.IO.File]::ReadAllBytes($Path)
    return [System.Text.Encoding]::UTF8.GetString($bytes)
}

function Split-CsvLineSimple {
    param(
        [string]$Line,
        [string]$Delimiter = ';'
    )

    # Minimal CSV split for our mapping files (no embedded delimiters expected).
    return $Line.Split(@($Delimiter))
}

function Import-PatientApoMapping {
    <#
    .SYNOPSIS
        Lädt die Patient-Apotheken CSV-Datei und erstellt einen Cache
    #>
    try {
        Write-Log "Lade Patient-Apotheken Mapping: $($Config.PatientApoMapping)" -Status "INFO"

        $text = Read-Utf8TextFileCompat -Path $Config.PatientApoMapping
        $lines = $text -split "\r?\n" | Where-Object { $_ -and ($_.Trim() -ne "") }
        
        # Cache erstellen: Key = "Nachname;Vorname;Geburtsdatum"
        $script:PatientCache = @{}

        foreach ($line in $lines) {
            $cols = Split-CsvLineSimple -Line $line -Delimiter ';'

            if ($cols.Length -ge $CSVConfig.ApoKeyColumn) {
                $lastName = $cols[$CSVConfig.PatientLastNameColumn - 1]
                $firstName = $cols[$CSVConfig.PatientFirstNameColumn - 1]
                $birthDate = $cols[$CSVConfig.PatientBirthDateColumn - 1]
                $apoKey = $cols[$CSVConfig.ApoKeyColumn - 1]
                
                # Bereinigen
                $lastName = ($lastName -replace '\s+', ' ').Trim()
                $firstName = ($firstName -replace '\s+', ' ').Trim()
                $birthDate = ($birthDate -replace '\s+', ' ').Trim()
                $apoKey = ($apoKey -replace '\s+', ' ').Trim()
                
                if ($lastName -and $firstName -and $birthDate -and $apoKey) {
                    # Mehrere Keys für Flexibilität
                    $key1 = "$lastName;$firstName;$birthDate"
                    $key2 = "$firstName $lastName;$birthDate"
                    $key3 = "$lastName $firstName;$birthDate"
                    
                    $script:PatientCache[$key1] = $apoKey
                    $script:PatientCache[$key2] = $apoKey
                    $script:PatientCache[$key3] = $apoKey
                    
                    Write-Log "Patient gecacht: $key1 -> $apoKey" -Status "DEBUG"
                }
            }
        }
        
        $script:CacheTimestamp = Get-Date
        Write-Log "Patient-Cache erstellt mit $($script:PatientCache.Count) Einträgen" -Status "INFO"
        
        return $true
    }
    catch {
        Write-Log "Fehler beim Laden der Patient-Apotheken CSV: $($_.Exception.Message)" -Status "ERROR"
        return $false
    }
}

function Import-KIMApoMapping {
    <#
    .SYNOPSIS
        Lädt die KIM-Apotheken CSV-Datei und erstellt einen Cache
    #>
    try {
        Write-Log "Lade KIM-Apotheken Mapping: $($Config.KIMApoMapping)" -Status "INFO"

        $text = Read-Utf8TextFileCompat -Path $Config.KIMApoMapping
        $lines = $text -split "\r?\n" | Where-Object { $_ -and ($_.Trim() -ne "") }

        if ($lines.Count -lt 2) {
            throw "CSV enthält keine Datenzeilen."
        }

        $headerCols = Split-CsvLineSimple -Line $lines[0] -Delimiter ';'
        $headerIndex = @{}
        for ($i = 0; $i -lt $headerCols.Length; $i++) {
            $headerIndex[$headerCols[$i]] = $i
        }

        $idxApo = $null
        $idxAddr = $null
        $idxName = $null

        if ($headerIndex.ContainsKey($CSVConfig.KIMApoColumn)) { $idxApo = $headerIndex[$CSVConfig.KIMApoColumn] }
        if ($headerIndex.ContainsKey($CSVConfig.KIMAddrColumn)) { $idxAddr = $headerIndex[$CSVConfig.KIMAddrColumn] }
        if ($headerIndex.ContainsKey($CSVConfig.KIMNameColumn)) { $idxName = $headerIndex[$CSVConfig.KIMNameColumn] }

        if ($null -eq $idxApo -or $null -eq $idxAddr) {
            throw "CSV Header fehlt: $($CSVConfig.KIMApoColumn) oder $($CSVConfig.KIMAddrColumn)"
        }
        
        # Cache erstellen: Key = APO_KEY
        $script:KIMCache = @{}

        for ($lineIdx = 1; $lineIdx -lt $lines.Count; $lineIdx++) {
            $cols = Split-CsvLineSimple -Line $lines[$lineIdx] -Delimiter ';'

            if ($cols.Length -le $idxAddr) {
                continue
            }

            $apoKey = $cols[$idxApo]
            $kimAddr = $cols[$idxAddr]
            $apoName = if ($null -ne $idxName -and $cols.Length -gt $idxName) { $cols[$idxName] } else { "" }
            
            if ($apoKey -and $kimAddr) {
                $script:KIMCache[$apoKey] = @{
                    KIMAddress = $kimAddr
                    ApoName = $apoName
                }
                
                Write-Log "KIM gecacht: $apoKey -> $kimAddr" -Status "DEBUG"
            }
        }
        
        Write-Log "KIM-Cache erstellt mit $($script:KIMCache.Count) Einträgen" -Status "INFO"
        
        return $true
    }
    catch {
        Write-Log "Fehler beim Laden der KIM-Apotheken CSV: $($_.Exception.Message)" -Status "ERROR"
        return $false
    }
}

function Get-PharmacyForPatient {
    <#
    .SYNOPSIS
        Sucht die Apotheke für einen Patienten
    .PARAMETER PatientName
        Vollständiger Name des Patienten
    .PARAMETER BirthDate
        Geburtsdatum des Patienten
    .RETURNS
        APO_KEY oder $null
    #>
    param(
        [string]$PatientName,
        [string]$BirthDate
    )
    
    try {
        # Cache prüfen und bei Bedarf neu laden
        if (-not $script:CacheTimestamp -or (Get-Date) - $script:CacheTimestamp -gt [TimeSpan]::FromMinutes(30)) {
            Write-Log "Cache ist abgelaufen, lade neu..." -Status "INFO"
            Import-PatientApoMapping | Out-Null
        }
        
        # Verschiedene Namensformate probieren
        $nameVariants = New-Object System.Collections.Generic.List[string]

        # Variante 1: Voller Name wie geliefert
        $null = $nameVariants.Add("$PatientName;$BirthDate")

        # Variante 2/3: Wenn Name in "Vorname Nachname" aufteilbar ist
        if ($PatientName -match '^(.+?)\s+(\S+)$') {
            $first = $matches[1]
            $last  = $matches[2]

            # Nachname;Vorname;Datum
            $null = $nameVariants.Add("$last;$first;$BirthDate")
            # Vorname Nachname;Datum
            $null = $nameVariants.Add("$first $last;$BirthDate")
        }
        
        foreach ($variant in $nameVariants) {
            if ($script:PatientCache.ContainsKey($variant)) {
                $apoKey = $script:PatientCache[$variant]
                Write-Log "Apotheke gefunden für '$PatientName' ($BirthDate): $apoKey" -Status "INFO"
                return $apoKey
            }
        }
        
        # Fallback: Teilweise Suche (nur wenn Geburtsdatum eindeutig)
        $matchingPatients = $script:PatientCache.Keys | Where-Object { $_ -like "*$BirthDate" }
        
        if ($matchingPatients.Count -eq 1) {
            $apoKey = $script:PatientCache[$matchingPatients[0]]
            Write-Log "Apotheke gefunden (Fallback): $apoKey" -Status "INFO"
            return $apoKey
        }
        
        Write-Log "Keine Apotheke gefunden für: $PatientName ($BirthDate)" -Status "WARN"
        return $null
    }
    catch {
        Write-Log "Fehler bei Apotheken-Suche: $($_.Exception.Message)" -Status "ERROR"
        return $null
    }
}

function Get-EmailForPharmacy {
    <#
    .SYNOPSIS
        Sucht die KIM-E-Mail für eine Apotheke
    .PARAMETER ApoKey
        APO_KEY der Apotheke
    .RETURNS
        Hashtable mit KIMAddress und ApoName oder $null
    #>
    param([string]$ApoKey)
    
    try {
        # Cache prüfen
        if ($script:KIMCache.Count -eq 0) {
            Import-KIMApoMapping | Out-Null
        }
        
        if ($script:KIMCache.ContainsKey($ApoKey)) {
            $kimInfo = $script:KIMCache[$ApoKey]
            Write-Log "KIM-Adresse gefunden für $ApoKey`: $($kimInfo.KIMAddress)" -Status "INFO"
            return $kimInfo
        }
        
        Write-Log "Keine KIM-Adresse gefunden für: $ApoKey" -Status "WARN"
        return $null
    }
    catch {
        Write-Log "Fehler bei KIM-Suche: $($_.Exception.Message)" -Status "ERROR"
        return $null
    }
}

function Initialize-CSVCache {
    <#
    .SYNOPSIS
        Initialisiert beide CSV-Caches
    #>
    try {
        Write-Log "Initialisiere CSV-Caches..." -Status "INFO"
        
        $patientLoaded = Import-PatientApoMapping
        $kimLoaded = Import-KIMApoMapping
        
        if ($patientLoaded -and $kimLoaded) {
            Write-Log "CSV-Caches erfolgreich initialisiert" -Status "INFO"
            return $true
        } else {
            Write-Log "Fehler bei Initialisierung der CSV-Caches" -Status "ERROR"
            return $false
        }
    }
    catch {
        Write-Log "Fehler bei Cache-Initialisierung: $($_.Exception.Message)" -Status "ERROR"
        return $false
    }
}

function Get-CacheStatistics {
    <#
    .SYNOPSIS
        Gibt Statistiken über die Caches zurück
    #>
    return @{
        PatientCacheSize = $script:PatientCache.Count
        KIMCacheSize = $script:KIMCache.Count
        CacheTimestamp = $script:CacheTimestamp
        CacheAge = if ($script:CacheTimestamp) { (Get-Date) - $script:CacheTimestamp } else { $null }
    }
}
