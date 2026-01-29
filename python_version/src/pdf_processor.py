"""
PDF processing module for OCR extraction.

Uses pdf2image and pytesseract to extract text from PDF files.
"""
import re
from pathlib import Path
from typing import Optional

try:
    from pdf2image import convert_from_path
    import pytesseract
    from PIL import Image
except ImportError as e:
    raise ImportError(
        f"Missing dependency: {e}. Install with: pip install pdf2image pytesseract Pillow"
    )

from config.settings import OCR_LANGUAGE, OCR_DPI


def extract_text_from_pdf(pdf_path: Path) -> Optional[str]:
    """
    Extract text from a PDF file using OCR.

    Args:
        pdf_path: Path to the PDF file.

    Returns:
        Extracted text as string, or None if extraction failed.
    """
    try:
        # Convert PDF to images (first page only)
        images = convert_from_path(
            pdf_path,
            dpi=OCR_DPI,
            first_page=1,
            last_page=1
        )
        
        if not images:
            print(f"[ERROR] No pages found in PDF: {pdf_path}")
            return None
        
        # OCR on first page
        text = pytesseract.image_to_string(
            images[0],
            lang=OCR_LANGUAGE,
            config="--psm 1 --oem 3"  # Auto page segmentation with OSD
        )
        
        return text
    
    except Exception as e:
        print(f"[ERROR] OCR failed for {pdf_path}: {e}")
        return None


def extract_patient_info(text: str) -> Optional[dict]:
    """
    Extract patient name and birthdate from OCR text.

    The PDF format varies:
    - Format A: "für geboren am" on same line, then "Name DD.MM.YYYY" on next line
    - Format B: "für" then "Name" then "geboren am" then "DD.MM.YYYY" on separate lines

    Args:
        text: OCR extracted text.

    Returns:
        Dict with 'name' and 'birth_date' keys, or None if not found.
    """
    if not text:
        return None
    
    # Pattern 1: Name and date on SAME line after "für geboren am"
    # Example: "für geboren am\nHarry Heilmann 29.04.1949"
    pattern_same_line = r"für\s+geboren\s+am\s*[\r\n]+\s*([A-ZÄÖÜ][a-zäöüß]+(?:\s+[A-ZÄÖÜ][a-zäöüß]+)+)\s+(\d{2}\.\d{2}\.\d{4})"
    
    match = re.search(pattern_same_line, text, re.IGNORECASE)
    if match:
        name = match.group(1).strip()
        birth_date = match.group(2).strip()
        if not re.search(r"Frank|Dr\.|med\.", name, re.IGNORECASE):
            return {"name": name, "birth_date": birth_date, "full_name": f"{name} ({birth_date})"}
    
    # Pattern 2: Name and date on SEPARATE lines
    # Example: "für\nAstrid Pföhler\n...\ngeboren am\n27.03.1939"
    # Name is on the line immediately after "für", before "ausgestellt"
    pattern_separate = r"für\s*[\r\n]+\s*([A-ZÄÖÜ][a-zäöüß]+\s+[A-ZÄÖÜ][a-zäöüß]+)\s*[\r\n]+"
    
    match = re.search(pattern_separate, text)
    if match:
        name = match.group(1).strip()
        # Find date separately
        date_match = re.search(r"geboren\s+am\s*[\r\n]+\s*(\d{2}\.\d{2}\.\d{4})", text, re.IGNORECASE)
        if date_match and not re.search(r"Frank|Dr\.|med\.", name, re.IGNORECASE):
            birth_date = date_match.group(1).strip()
            return {"name": name, "birth_date": birth_date, "full_name": f"{name} ({birth_date})"}
    
    # Pattern 3: Flexible - find name after "für" and date after "geboren am"
    # Extract name: first capitalized name after "für" (just 2 words, no more)
    name_match = re.search(r"für\s*[\r\n]+\s*([A-ZÄÖÜ][a-zäöüß]+\s+[A-ZÄÖÜ][a-zäöüß]+)", text)
    date_match = re.search(r"geboren\s+am\s*[\r\n]+\s*(\d{2}\.\d{2}\.\d{4})", text, re.IGNORECASE)
    
    if name_match and date_match:
        name = name_match.group(1).strip()
        birth_date = date_match.group(1).strip()
        if not re.search(r"Frank|Dr\.|med\.", name, re.IGNORECASE):
            return {"name": name, "birth_date": birth_date, "full_name": f"{name} ({birth_date})"}
    
    return None
