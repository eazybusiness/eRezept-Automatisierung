"""
Tests for CSV lookup module.
"""
import pytest
import sys
from pathlib import Path

# Add project root to path
sys.path.insert(0, str(Path(__file__).parent.parent))

from src.csv_lookup import PatientPharmacyLookup


class TestPatientPharmacyLookup:
    """Tests for PatientPharmacyLookup class."""
    
    @pytest.fixture
    def lookup(self):
        """Create a lookup instance with loaded data."""
        lkp = PatientPharmacyLookup()
        lkp.load_csv_data()
        return lkp
    
    def test_load_csv_data(self, lookup):
        """Test that CSV data loads successfully."""
        assert lookup._loaded is True
        assert len(lookup._patient_cache) > 0
    
    def test_find_pharmacy_existing_patient(self, lookup):
        """Test finding pharmacy for existing patient."""
        # Elisabeth Großmann should map to APO_BURG_BOVENDEN
        result = lookup.find_pharmacy("Elisabeth Großmann", "16.08.1946")
        assert result == "APO_BURG_BOVENDEN"
    
    def test_find_pharmacy_hartje(self, lookup):
        """Test finding pharmacy for Reinhold Hartje."""
        result = lookup.find_pharmacy("Reinhold Hartje", "14.12.1936")
        assert result == "APO_BAEREN"
    
    def test_find_pharmacy_heilmann(self, lookup):
        """Test finding pharmacy for Harry Heilmann."""
        result = lookup.find_pharmacy("Harry Heilmann", "29.04.1949")
        assert result == "APO_FELDTOR"
    
    def test_find_pharmacy_pfoehler(self, lookup):
        """Test finding pharmacy for Astrid Pföhler."""
        result = lookup.find_pharmacy("Astrid Pföhler", "27.03.1939")
        assert result == "APO_MUEHLEN"
    
    def test_find_pharmacy_nonexistent(self, lookup):
        """Test that nonexistent patient returns None."""
        # Bernd Messerschmidt doesn't exist in CSV (only Christa)
        result = lookup.find_pharmacy("Bernd Messerschmidt", "15.06.1959")
        assert result is None
    
    def test_find_pharmacy_wrong_date(self, lookup):
        """Test that wrong birthdate returns None."""
        result = lookup.find_pharmacy("Elisabeth Großmann", "01.01.2000")
        assert result is None
