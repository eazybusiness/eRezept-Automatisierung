"""
CSV lookup module for patient-to-pharmacy mapping.

Reads customer CSV files and provides lookup functions.
"""
import csv
import re
from pathlib import Path
from typing import Dict, Optional

from config.settings import (
    PATIENT_APO_MAPPING_CSV,
    KIM_APO_MAPPING_CSV,
    CSV_COLUMNS,
)


class PatientPharmacyLookup:
    """
    Handles patient-to-pharmacy lookups from CSV data.
    """
    
    def __init__(self):
        """Initialize the lookup with empty caches."""
        self._patient_cache: Dict[str, str] = {}
        self._kim_cache: Dict[str, dict] = {}
        self._loaded = False
    
    def load_csv_data(self) -> bool:
        """
        Load both CSV files into memory caches.

        Returns:
            True if both files loaded successfully, False otherwise.
        """
        patient_ok = self._load_patient_mapping()
        kim_ok = self._load_kim_mapping()
        self._loaded = patient_ok and kim_ok
        return self._loaded
    
    def _load_patient_mapping(self) -> bool:
        """
        Load patient-to-pharmacy mapping from CSV.

        Returns:
            True if loaded successfully.
        """
        try:
            if not PATIENT_APO_MAPPING_CSV.exists():
                print(f"[ERROR] Patient CSV not found: {PATIENT_APO_MAPPING_CSV}")
                return False
            
            with open(PATIENT_APO_MAPPING_CSV, "r", encoding="utf-8") as f:
                reader = csv.reader(f, delimiter=";")
                
                # Skip header row
                next(reader, None)
                
                for row in reader:
                    if len(row) <= CSV_COLUMNS["apo_key"]:
                        continue
                    
                    last_name = row[CSV_COLUMNS["last_name"]].strip()
                    first_name = row[CSV_COLUMNS["first_name"]].strip()
                    birth_date = row[CSV_COLUMNS["birth_date"]].strip()
                    sozialanamnese = row[CSV_COLUMNS["apo_key"]]
                    
                    # Extract APO_KEY from Sozialanamnese text
                    apo_key = self._extract_apo_key(sozialanamnese)
                    
                    if last_name and first_name and birth_date and apo_key:
                        # Create multiple key variants for flexible matching
                        keys = [
                            f"{last_name};{first_name};{birth_date}",
                            f"{first_name} {last_name};{birth_date}",
                            f"{last_name} {first_name};{birth_date}",
                        ]
                        for key in keys:
                            self._patient_cache[key] = apo_key
            
            print(f"[INFO] Loaded {len(self._patient_cache)} patient cache entries")
            return True
        
        except Exception as e:
            print(f"[ERROR] Failed to load patient CSV: {e}")
            return False
    
    def _load_kim_mapping(self) -> bool:
        """
        Load KIM address mapping from CSV.

        Returns:
            True if loaded successfully.
        """
        try:
            if not KIM_APO_MAPPING_CSV.exists():
                print(f"[ERROR] KIM CSV not found: {KIM_APO_MAPPING_CSV}")
                return False
            
            with open(KIM_APO_MAPPING_CSV, "r", encoding="utf-8") as f:
                reader = csv.DictReader(f, delimiter=";")
                
                for row in reader:
                    apo_key = row.get("KIM_APO", "").strip()
                    kim_addr = row.get("KIM_ADDR", "").strip()
                    apo_name = row.get("APO_NAME", "").strip()
                    
                    if apo_key and kim_addr:
                        self._kim_cache[apo_key] = {
                            "kim_address": kim_addr,
                            "apo_name": apo_name,
                        }
            
            print(f"[INFO] Loaded {len(self._kim_cache)} KIM cache entries")
            return True
        
        except Exception as e:
            print(f"[ERROR] Failed to load KIM CSV: {e}")
            return False
    
    def _extract_apo_key(self, text: str) -> Optional[str]:
        """
        Extract APO_KEY from Sozialanamnese text.

        Args:
            text: The Sozialanamnese field content.

        Returns:
            APO_KEY string (e.g., "APO_BAEREN") or None.
        """
        match = re.search(r"(APO_[A-Z_]+)", text)
        if match:
            return match.group(1)
        return None
    
    def find_pharmacy(self, patient_name: str, birth_date: str) -> Optional[str]:
        """
        Find pharmacy APO_KEY for a patient.

        Args:
            patient_name: Full name from OCR (e.g., "Elisabeth Großmann").
            birth_date: Birth date from OCR (e.g., "16.08.1946").

        Returns:
            APO_KEY string or None if not found.
        """
        if not self._loaded:
            self.load_csv_data()
        
        # Try different name formats
        # OCR gives us "Vorname Nachname", CSV has "Nachname;Vorname"
        name_parts = patient_name.split()
        
        if len(name_parts) >= 2:
            first_name = name_parts[0]
            last_name = " ".join(name_parts[1:])  # Handle multi-part last names
            
            # Try: Nachname;Vorname;Datum (primary CSV format)
            key1 = f"{last_name};{first_name};{birth_date}"
            if key1 in self._patient_cache:
                return self._patient_cache[key1]
            
            # Try: Vorname Nachname;Datum
            key2 = f"{first_name} {last_name};{birth_date}"
            if key2 in self._patient_cache:
                return self._patient_cache[key2]
            
            # Try: Nachname Vorname;Datum
            key3 = f"{last_name} {first_name};{birth_date}"
            if key3 in self._patient_cache:
                return self._patient_cache[key3]
        
        # Fallback: Search by birth date only (if unique)
        matching = [k for k in self._patient_cache.keys() if k.endswith(f";{birth_date}")]
        if len(matching) == 1:
            return self._patient_cache[matching[0]]
        
        return None
    
    def get_kim_address(self, apo_key: str) -> Optional[dict]:
        """
        Get KIM email address for a pharmacy.

        Args:
            apo_key: Pharmacy key (e.g., "APO_BAEREN").

        Returns:
            Dict with 'kim_address' and 'apo_name', or None.
        """
        if not self._loaded:
            self.load_csv_data()
        
        return self._kim_cache.get(apo_key)
