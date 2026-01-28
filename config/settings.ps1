# eRezept-Versand Automatisierung - Konfiguration
# Alle Pfade relativ zum Skriptverzeichnis

# ==================== VERZEICHNISSE ====================
$Config = @{
    # Eingangs- und Ausgangsverzeichnisse (Kunden-Pfade)
    InputFolder = "C:\Daten\ERP\Heim_INBOX"
    PharmacyBaseFolder = "C:\Daten\ERP\Heim\Apotheken"
    UnklarFolder = "C:\Daten\ERP\Heim\UNKLAR"
    SentFolder = "C:\Daten\ERP\Heim_SENT"
    LogFolder = "C:\Daten\ERP\Heim_LOGGING"
    
    # Tools Verzeichnis (relativ zum Skript)
    ToolsFolder = ".\tools"
    
    # CSV-Dateien (Kunden-Pfade)
    PatientApoMapping = "C:\Daten\ERP\patient_apo_mapping.csv"
    KIMApoMapping = "C:\Daten\ERP\KIM_apo_mapping.csv"
    
    # Tool Pfade
    TesseractExe = ".\tools\tesseract.exe"
    TesseractData = ".\tools\tessdata"
    GhostscriptExe = ".\tools\gswin64c.exe"
}

# ==================== CSV-SPALTEN ====================
$CSVConfig = @{
    # patient_apo_mapping.csv
    PatientLastNameColumn = 2      # Spalte 2: Nachname
    PatientFirstNameColumn = 4     # Spalte 4: Vorname
    PatientBirthDateColumn = 6     # Spalte 6: Geburtsdatum
    ApoKeyColumn = 34              # Spalte 34: APO_KEY
    
    # KIM_apo_mapping.csv
    KIMApoColumn = "KIM_APO"
    KIMAddrColumn = "KIM_ADDR"
    KIMNameColumn = "APO_NAME"
}

# ==================== KIM-DIENST ====================
$KIMConfig = @{
    SmtpServer = "kv.dox.kim.telematik"
    SmtpPort = 587
    UseSSL = $true
    EmailFrom = "praxis@domain.de"  # Anpassen!
    EmailSubject = "eRezept für {0}"
    
    # Fehlerbenachrichtigung
    ErrorEmailTo = "error@domain.de"  # Anpassen!
}

# ==================== VERARBEITUNG ====================
$ProcessingConfig = @{
    # Scan-Intervall in Sekunden
    ScanInterval = 30
    
    # Dateifilter
    FilePattern = "ERP_NEURO_*.pdf"
    
    # OCR Einstellungen
    OCRLanguage = "deu"
    OCROutputFormat = "txt"
    
    # Performance
    MaxConcurrentOCR = 2
    OCRTimeoutSeconds = 30
    
    # Duplikatschutz
    EnableDuplicateCheck = $true
    HashAlgorithm = "SHA256"
}

# ==================== LOGGING ====================
$LogConfig = @{
    LogLevel = "INFO"  # DEBUG, INFO, WARN, ERROR
    LogFormat = "JSONL"
    MaxLogSizeMB = 100
    MaxLogFiles = 30
    
    # Status-Codes
    Status_ROUTED = "ROUTED"
    Status_SENT = "SENT"
    Status_DUPLICATE = "DUPLICATE_BLOCKED"
    STATUS_UNKLAR = "UNKLAR"
    Status_ERROR = "ERROR"
    Status_COMPLETED = "COMPLETED"
}

# ==================== ERROR-HANDLING ====================
$ErrorConfig = @{
    RetryAttempts = 3
    RetryDelaySeconds = 5
    EnableErrorNotifications = $true
    
    # Dead-Letter-Queue
    DeadLetterFolder = "C:\Daten\ERP\Heim\DEADLETTER"
}
