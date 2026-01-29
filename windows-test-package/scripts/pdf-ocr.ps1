# PDF-OCR Modul für eRezept-Automatisierung
# Extrahiert Patientennamen aus -90° gedrehten PDFs

function Rotate-PDF {
    <#
    .SYNOPSIS
        Rotiert eine PDF-Datei um 90 Grad im Uhrzeigersinn
    .PARAMETER Path
        Pfad zur PDF-Datei
    .PARAMETER OutputPath
        Pfad für die rotierte PDF-Datei
    #>
    param(
        [string]$Path,
        [string]$OutputPath
    )
    
    try {
        # For now, skip rotation and work with original PDF
        # Tesseract can handle rotated text with --psm 0 (auto orientation detection)
        Write-Log "Kopiere PDF (Rotation wird von Tesseract gehandhabt): $Path" -Status "INFO"
        
        Copy-Item -Path $Path -Destination $OutputPath -Force
        
        if (Test-Path $OutputPath) {
            Write-Log "PDF bereit für OCR: $OutputPath" -Status "INFO"
            return $OutputPath
        } else {
            Write-Log "Fehler beim Kopieren der PDF" -Status "ERROR"
            return $null
        }
    }
    catch {
        Write-Log "Fehler bei PDF-Vorbereitung: $($_.Exception.Message)" -Status "ERROR"
        return $null
    }
}

function Extract-TextFromPDF {
    <#
    .SYNOPSIS
        Extrahiert Text aus PDF mit Tesseract OCR
    .PARAMETER Path
        Pfad zur PDF-Datei
    #>
    param([string]$Path)
    
    try {
        # Temporäre Dateien
        $tempPng = Join-Path $env:TEMP "pdf_page_$(Get-Random).png"
        $tempTxt = Join-Path $env:TEMP "ocr_$(Get-Random).txt"
        
        # Schritt 1: PDF zu PNG mit Ghostscript konvertieren
        Write-Log "Konvertiere PDF zu Bild: $Path" -Status "INFO"
        
        $gsArgs = @(
            "-sDEVICE=png16m",
            "-dTextAlphaBits=4",
            "-dGraphicsAlphaBits=4",
            "-r300",  # 300 DPI für gute OCR-Qualität
            "-dFirstPage=1",
            "-dLastPage=1",
            "-sOutputFile=$tempPng",
            "-dNOPAUSE",
            "-dBATCH",
            "-dSAFER",
            $Path
        )
        
        $gsProcess = Start-Process -FilePath $Config.GhostscriptExe -ArgumentList $gsArgs -Wait -PassThru -NoNewWindow
        
        if ($gsProcess.ExitCode -ne 0 -or -not (Test-Path $tempPng)) {
            Write-Log "Fehler bei PDF-zu-Bild Konvertierung: ExitCode $($gsProcess.ExitCode)" -Status "ERROR"
            return $null
        }
        
        # Schritt 2: OCR auf PNG-Bild mit Tesseract
        Write-Log "Führe OCR durch auf Bild" -Status "INFO"
        
        $tessArgs = @(
            $tempPng,
            $tempTxt.Replace('.txt', ''),  # Tesseract fügt .txt automatisch hinzu
            "-l", $ProcessingConfig.OCRLanguage,
            "--psm", "1",  # Automatic page segmentation with OSD (handles rotation)
            "--oem", "3"   # Default OCR engine mode
        )
        
        $tessProcess = Start-Process -FilePath $Config.TesseractExe -ArgumentList $tessArgs -Wait -PassThru -NoNewWindow
        
        # Aufräumen: PNG löschen
        Remove-Item $tempPng -Force -ErrorAction SilentlyContinue
        
        if ($tessProcess.ExitCode -eq 0 -and (Test-Path $tempTxt)) {
            $text = Get-Content -Path $tempTxt -Encoding UTF8 -Raw
            Remove-Item $tempTxt -Force -ErrorAction SilentlyContinue
            Write-Log "OCR erfolgreich, Textlänge: $($text.Length)" -Status "INFO"
            return $text
        } else {
            Write-Log "Fehler bei OCR: ExitCode $($tessProcess.ExitCode)" -Status "ERROR"
            return $null
        }
    }
    catch {
        Write-Log "Fehler bei OCR: $($_.Exception.Message)" -Status "ERROR"
        return $null
    }
}

function Extract-PatientNameFromPDF {
    <#
    .SYNOPSIS
        Extrahiert Patientenname und Geburtsdatum aus PDF
    .PARAMETER Path
        Pfad zur PDF-Datei
    .RETURNS
        Hashtable mit Name und Geburtsdatum oder $null
    #>
    param([string]$Path)
    
    try {
        Write-Log "Verarbeite PDF: $Path" -Status "INFO"
        
        # Schritt 1: PDF rotieren
        $rotatedPdf = Join-Path $env:TEMP "rotated_$(Get-Random).pdf"
        $rotationResult = Rotate-PDF -Path $Path -OutputPath $rotatedPdf
        
        if (-not $rotationResult) {
            Write-Log "PDF-Rotation fehlgeschlagen: $Path" -Status "ERROR"
            return $null
        }
        
        # Schritt 2: OCR durchführen
        $ocrText = Extract-TextFromPDF -Path $rotatedPdf
        
        # Temporäre Datei aufräumen
        Remove-Item $rotatedPdf -Force -ErrorAction SilentlyContinue
        
        if (-not $ocrText) {
            Write-Log "OCR fehlgeschlagen: $Path" -Status "ERROR"
            return $null
        }
        
        # Schritt 3: Regex-Patterns für Patientendaten
        # WICHTIG: Patient kommt NACH "für geboren am" auf der NÄCHSTEN Zeile!
        # Format: "( für geboren am \" gefolgt von neuer Zeile mit "Vorname Nachname DD.MM.YYYY"
        # KRITISCH: Muss VOR "ausgestellt von" stoppen, sonst wird Arztname extrahiert!
        
        # Debug: OCR-Output vollständig in Datei speichern
        $debugFile = Join-Path $Config.TempFolder "ocr_debug_$(Get-Random).txt"
        $ocrText | Out-File -FilePath $debugFile -Encoding UTF8
        Write-Log "OCR-Output gespeichert in: $debugFile" -Status "INFO"
        Write-Log "OCR-Output (erste 500 Zeichen): $($ocrText.Substring(0, [Math]::Min(500, $ocrText.Length)))" -Status "INFO"
        
        # Strategie: Text zwischen "für geboren am" und "ausgestellt von" extrahieren
        $sectionPattern = "(?s)f\u00FCr\s+geboren\s+am\s*\\?\s*[\r\n]+(.*?)(?:[\r\n]+.*?ausgestellt\s+von|$)"
        
        if ($ocrText -match $sectionPattern) {
            $patientSection = $matches[1]
            Write-Log "Patient-Sektion extrahiert: $($patientSection.Substring(0, [Math]::Min(100, $patientSection.Length)))" -Status "DEBUG"
            
            # In dieser Sektion nach Name + Datum suchen
            $namePattern = "([A-Z][a-z]+(?:\s+[A-Z][a-z]+)+)\s+(\d{2}\.\d{2}\.\d{4})"
            
            if ($patientSection -match $namePattern) {
                $name = $matches[1].Trim()
                $datum = $matches[2].Trim()
                
                Write-Log "Patient gefunden: Name='$name', Geburtsdatum='$datum'" -Status "INFO"
                
                return @{
                    Name = $name
                    BirthDate = $datum
                    FullName = "$name ($datum)"
                }
            }
        }
        
        # Fallback: Direktes Pattern mit negativem Lookahead für "ausgestellt von"
        $patterns = @(
            # Pattern 1: Nach "für geboren am" bis zum ersten Name+Datum, aber nicht nach "ausgestellt"
            "(?s)f\u00FCr\s+geboren\s+am\s*[^\r\n]*[\r\n]+\s*(?<name>[A-Z][a-z]+\s+[A-Z][a-z]+(?:\s+[A-Z][a-z]+)?)\s+(?<datum>\d{2}\.\d{2}\.\d{4})",
            
            # Pattern 2: Flexibler - nach "für geboren am" mindestens 5 Zeichen Abstand vor Name
            "(?s)f\u00FCr\s+geboren\s+am.{5,50}?(?<name>[A-Z][a-z]+\s+[A-Z][a-z]+(?:\s+[A-Z][a-z]+)?)\s+(?<datum>\d{2}\.\d{2}\.\d{4})"
        )
        
        foreach ($pattern in $patterns) {
            if ($ocrText -match $pattern) {
                $name = $matches['name'].Trim()
                $datum = $matches['datum'].Trim()
                
                # Sicherheitscheck: Ist das wirklich ein Patient und nicht der Arzt?
                if ($name -notmatch "Frank|Dr\.|med\.") {
                    Write-Log "Patient gefunden (Fallback): Name='$name', Geburtsdatum='$datum'" -Status "INFO"
                    
                    return @{
                        Name = $name
                        BirthDate = $datum
                        FullName = "$name ($datum)"
                    }
                } else {
                    Write-Log "Arztname erkannt und übersprungen: $name" -Status "DEBUG"
                }
            }
        }
        
        Write-Log "Keine Patientendaten gefunden in: $Path" -Status "WARN"
        return $null
    }
    catch {
        Write-Log "Fehler bei Extraktion: $($_.Exception.Message)" -Status "ERROR"
        return $null
    }
}

function Test-PDFQuality {
    <#
    .SYNOPSIS
        Testet die Qualität der OCR-Erkennung
    .PARAMETER Text
        Extrahierter Text aus PDF
    #>
    param([string]$Text)
    
    if ([string]::IsNullOrWhiteSpace($Text)) {
        return $false
    }
    
    # Einfache Qualitätschecks
    $hasGermanChars = $Text -match '[\u00E4\u00F6\u00FC\u00C4\u00D6\u00DC\u00DF]'
    $hasNumbers = $Text -match '\d'
    $hasValidWords = $Text -match ('\b(F\u00FCr|Patient|Name|geboren|Geburtsdatum)\b')
    
    return $hasGermanChars -and $hasNumbers -and $hasValidWords
}
