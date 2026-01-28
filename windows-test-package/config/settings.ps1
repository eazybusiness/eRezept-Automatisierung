# eRezept-Automatisierung - Test Configuration (relative paths)

$Config = @{
    InputFolder = ".\inbox"
    PharmacyBaseFolder = ".\pharmacies"
    UnklarFolder = ".\unklar"
    SentFolder = ".\sent"
    LogFolder = ".\logs"
    TempFolder = ".\temp"

    ToolsFolder = ".\tools"

    PatientApoMapping = ".\data\patient_apo_mapping.csv"
    KIMApoMapping = ".\data\KIM_apo_mapping.csv"

    TesseractExe = ".\tools\tesseract.exe"
    TesseractData = ".\tools\tessdata"
    GhostscriptExe = ".\tools\gswin64c.exe"
}

$CSVConfig = @{
    PatientLastNameColumn = 2
    PatientFirstNameColumn = 4
    PatientBirthDateColumn = 6
    ApoKeyColumn = 34

    KIMApoColumn = "KIM_APO"
    KIMAddrColumn = "KIM_ADDR"
    KIMNameColumn = "APO_NAME"
}

$KIMConfig = @{
    # SmtpServer = "kv.dox.kim.telematik"
    SmtpServer = "testserver"
    SmtpPort = 587
    UseSSL = $true
    EmailFrom = "praxis@domain.de"
    EmailSubject = "eRezept für {0}"

    EnableSend = $false

    ErrorEmailTo = "error@domain.de"
}

$ProcessingConfig = @{
    ScanInterval = 5
    FilePattern = "*.pdf"

    OCRLanguage = "deu"
    OCROutputFormat = "txt"

    MaxConcurrentOCR = 1
    OCRTimeoutSeconds = 30

    EnableDuplicateCheck = $true
    HashAlgorithm = "SHA256"
}

$LogConfig = @{
    LogLevel = "INFO"
    LogFormat = "JSONL"
    MaxLogSizeMB = 100
    MaxLogFiles = 30

    Status_ROUTED = "ROUTED"
    Status_SENT = "SENT"
    Status_DUPLICATE = "DUPLICATE_BLOCKED"
    STATUS_UNKLAR = "UNKLAR"
    Status_ERROR = "ERROR"
    Status_COMPLETED = "COMPLETED"
}

$ErrorConfig = @{
    RetryAttempts = 1
    RetryDelaySeconds = 2
    EnableErrorNotifications = $true

    DeadLetterFolder = ".\deadletter"
}
