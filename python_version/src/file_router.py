"""
File routing module for organizing processed PDFs.

Routes PDFs to pharmacy-specific folders or 'unklar' folder.
"""
import shutil
from pathlib import Path
from typing import Optional

from config.settings import OUTPUT_FOLDER


def route_pdf(
    pdf_path: Path,
    apo_key: Optional[str],
    patient_info: Optional[dict] = None
) -> Path:
    """
    Route a PDF to the appropriate output folder.

    Args:
        pdf_path: Path to the source PDF.
        apo_key: Pharmacy key (e.g., "APO_BAEREN") or None.
        patient_info: Optional patient info dict for logging.

    Returns:
        Path to the destination file.
    """
    if apo_key:
        dest_folder = OUTPUT_FOLDER / apo_key
    else:
        dest_folder = OUTPUT_FOLDER / "unklar"
    
    # Create folder if needed
    dest_folder.mkdir(parents=True, exist_ok=True)
    
    # Copy file to destination
    dest_path = dest_folder / pdf_path.name
    shutil.copy2(pdf_path, dest_path)
    
    return dest_path


def get_routing_summary(output_folder: Path) -> dict:
    """
    Get summary of routed files.

    Args:
        output_folder: Path to output folder.

    Returns:
        Dict with folder names as keys and file counts as values.
    """
    summary = {}
    
    if not output_folder.exists():
        return summary
    
    for folder in output_folder.iterdir():
        if folder.is_dir():
            pdf_count = len(list(folder.glob("*.pdf")))
            if pdf_count > 0:
                summary[folder.name] = pdf_count
    
    return summary
