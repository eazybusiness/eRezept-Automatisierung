# Tesseract Deutsche Sprachdaten installieren

## Problem
Tesseract kann keine deutschen Texte erkennen, weil `deu.traineddata` fehlt.

## Lösung - In Windows VM ausführen:

### Option 1: Direkt von GitHub herunterladen (Empfohlen)
```powershell
# In PowerShell (Admin)
Invoke-WebRequest -Uri "https://github.com/tesseract-ocr/tessdata/raw/main/deu.traineddata" -OutFile "C:\Program Files\Tesseract-OCR\tessdata\deu.traineddata"
```

### Option 2: Aus dem Test-Package kopieren
```powershell
# Die Datei ist bereits im Package enthalten!
Copy-Item "C:\Users\admin\Downloads\windows-test-package\tools\downloads\deu.traineddata" "C:\Program Files\Tesseract-OCR\tessdata\deu.traineddata"
```

### Option 3: Vom HTTP-Server herunterladen
```powershell
Invoke-WebRequest -Uri "http://192.168.1.111:8080/windows-test-package/tools/downloads/deu.traineddata" -OutFile "C:\Program Files\Tesseract-OCR\tessdata\deu.traineddata"
```

## Prüfen ob erfolgreich
```powershell
Test-Path "C:\Program Files\Tesseract-OCR\tessdata\deu.traineddata"
# Sollte "True" zurückgeben
```

## Dann erneut testen
```powershell
cd C:\Users\admin\Downloads\windows-test-package
.\run-test.cmd
```
