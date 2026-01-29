#!/usr/bin/env python3
"""
eRezept-Automatisierung - Main Processing Script

Processes e-prescription PDFs:
1. Extract patient info via OCR
2. Look up assigned pharmacy from CSV
3. Route PDFs to pharmacy-specific folders
"""
import sys
from pathlib import Path
from datetime import datetime

# Add project root to path
sys.path.insert(0, str(Path(__file__).parent))

from config.settings import INPUT_FOLDER, OUTPUT_FOLDER, LOGS_FOLDER, FILE_PATTERN
from src.pdf_processor import extract_text_from_pdf, extract_patient_info
from src.csv_lookup import PatientPharmacyLookup
from src.file_router import route_pdf, get_routing_summary


def process_pdfs():
    """
    Main processing function.
    
    Processes all PDFs in the input folder.
    """
    print("=" * 60)
    print("eRezept-Automatisierung (Python Version)")
    print("=" * 60)
    print(f"Input folder: {INPUT_FOLDER}")
    print(f"Output folder: {OUTPUT_FOLDER}")
    print()
    
    # Initialize lookup
    lookup = PatientPharmacyLookup()
    if not lookup.load_csv_data():
        print("[ERROR] Failed to load CSV data. Exiting.")
        return False
    
    # Find PDFs
    pdf_files = list(INPUT_FOLDER.glob(FILE_PATTERN))
    
    if not pdf_files:
        print(f"[INFO] No PDF files found in {INPUT_FOLDER}")
        return True
    
    print(f"[INFO] Found {len(pdf_files)} PDF files to process")
    print("-" * 60)
    
    # Process each PDF
    results = {
        "success": 0,
        "no_patient": 0,
        "no_pharmacy": 0,
        "error": 0,
    }
    
    for pdf_path in pdf_files:
        print(f"\n[PROCESSING] {pdf_path.name}")
        
        try:
            # Step 1: OCR
            text = extract_text_from_pdf(pdf_path)
            
            if not text:
                print(f"  [ERROR] OCR failed")
                results["error"] += 1
                route_pdf(pdf_path, None)
                continue
            
            # Step 2: Extract patient info
            patient_info = extract_patient_info(text)
            
            if not patient_info:
                print(f"  [WARN] No patient data found")
                results["no_patient"] += 1
                route_pdf(pdf_path, None, patient_info)
                continue
            
            print(f"  [INFO] Patient: {patient_info['full_name']}")
            
            # Step 3: Look up pharmacy
            apo_key = lookup.find_pharmacy(
                patient_info["name"],
                patient_info["birth_date"]
            )
            
            if not apo_key:
                print(f"  [WARN] No pharmacy found for patient")
                results["no_pharmacy"] += 1
                route_pdf(pdf_path, None, patient_info)
                continue
            
            print(f"  [INFO] Pharmacy: {apo_key}")
            
            # Step 4: Get KIM address (optional)
            kim_info = lookup.get_kim_address(apo_key)
            if kim_info:
                print(f"  [INFO] KIM: {kim_info['kim_address']}")
            
            # Step 5: Route file
            dest = route_pdf(pdf_path, apo_key, patient_info)
            print(f"  [OK] Routed to: {dest.parent.name}/")
            results["success"] += 1
            
        except Exception as e:
            print(f"  [ERROR] Processing failed: {e}")
            results["error"] += 1
            route_pdf(pdf_path, None)
    
    # Summary
    print("\n" + "=" * 60)
    print("PROCESSING SUMMARY")
    print("=" * 60)
    print(f"  Success:      {results['success']}")
    print(f"  No patient:   {results['no_patient']}")
    print(f"  No pharmacy:  {results['no_pharmacy']}")
    print(f"  Errors:       {results['error']}")
    print()
    
    # Routing summary
    routing = get_routing_summary(OUTPUT_FOLDER)
    if routing:
        print("Files routed to:")
        for folder, count in sorted(routing.items()):
            print(f"  {folder}: {count} file(s)")
    
    return results["error"] == 0


if __name__ == "__main__":
    success = process_pdfs()
    sys.exit(0 if success else 1)
