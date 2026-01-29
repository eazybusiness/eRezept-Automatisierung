"""
Tests for PDF processor module.
"""
import pytest
import sys
from pathlib import Path

# Add project root to path
sys.path.insert(0, str(Path(__file__).parent.parent))

from src.pdf_processor import extract_patient_info


class TestExtractPatientInfo:
    """Tests for extract_patient_info function."""
    
    def test_same_line_format(self):
        """Test extraction when name and date are on same line."""
        text = """Ausdruck zur Einlösung Ihres E-Rezeptes

für geboren am

Harry Heilmann 29.04.1949

ausgestellt von ausgestellt am
Dr. med. Tobias Frank 15.01.2026
"""
        result = extract_patient_info(text)
        
        assert result is not None
        assert result["name"] == "Harry Heilmann"
        assert result["birth_date"] == "29.04.1949"
    
    def test_separate_lines_format(self):
        """Test extraction when name and date are on separate lines."""
        text = """Ausdruck zur Einlösung Ihres E-Rezeptes

für

Astrid Pföhler

ausgestellt von

Dr. med. Tobias Frank
Neuro GP Göttingen

geboren am

27.03.1939

ausgestellt am

15.01.2026
"""
        result = extract_patient_info(text)
        
        assert result is not None
        assert result["name"] == "Astrid Pföhler"
        assert result["birth_date"] == "27.03.1939"
    
    def test_umlaut_names(self):
        """Test extraction of names with German umlauts."""
        text = """für

Elisabeth Großmann

geboren am

16.08.1946
"""
        result = extract_patient_info(text)
        
        assert result is not None
        assert result["name"] == "Elisabeth Großmann"
        assert result["birth_date"] == "16.08.1946"
    
    def test_skip_doctor_name(self):
        """Test that doctor names are skipped."""
        text = """für

Dr. med. Tobias Frank

geboren am

01.01.1970
"""
        result = extract_patient_info(text)
        
        # Should return None because "Frank" is in the exclusion list
        assert result is None
    
    def test_empty_text(self):
        """Test with empty text."""
        result = extract_patient_info("")
        assert result is None
        
        result = extract_patient_info(None)
        assert result is None
    
    def test_no_patient_data(self):
        """Test with text that has no patient data."""
        text = "This is just random text without any patient information."
        result = extract_patient_info(text)
        assert result is None
