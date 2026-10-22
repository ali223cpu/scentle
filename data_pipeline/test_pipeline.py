#!/usr/bin/env python3
"""
test_pipeline.py
----------------
Unit and integration test suite for the Scentle data pipeline.
Verifies parsing logic, flanker grouping, Tier 2 deduplication, schema invariants,
and memory/payload limits.
"""

import json
import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from export_scentle_json import (
    clean_perfume_name,
    normalize_gender,
    clean_perfumer,
    extract_base_line,
    generate_flanker_id,
)


class TestDataCleaning(unittest.TestCase):
    def test_clean_perfume_name_with_brand_suffix(self):
        self.assertEqual(clean_perfume_name("Sauvage Dior", "Dior"), "Sauvage")
        self.assertEqual(clean_perfume_name("Aventus Creed", "Creed"), "Aventus")
        self.assertEqual(clean_perfume_name("Baccarat Rouge 540 Maison Francis Kurkdjian", "Maison Francis Kurkdjian"), "Baccarat Rouge 540")

    def test_clean_perfume_name_without_brand_suffix(self):
        self.assertEqual(clean_perfume_name("Bleu de Chanel", "Chanel"), "Bleu de")
        self.assertEqual(clean_perfume_name("Black Orchid", "Tom Ford"), "Black Orchid")

    def test_clean_perfume_name_edge_cases(self):
        self.assertEqual(clean_perfume_name("", "Brand"), "")
        self.assertEqual(clean_perfume_name("Dior", "Dior"), "Dior")

    def test_normalize_gender(self):
        self.assertEqual(normalize_gender("for men"), "Men")
        self.assertEqual(normalize_gender("FOR MEN"), "Men")
        self.assertEqual(normalize_gender("for women"), "Women")
        self.assertEqual(normalize_gender("for women and men"), "Unisex")
        self.assertEqual(normalize_gender(None), "Unisex")
        self.assertEqual(normalize_gender(""), "Unisex")

    def test_clean_perfumer(self):
        self.assertEqual(clean_perfumer("François Demachy"), "François Demachy")
        self.assertEqual(clean_perfumer("N/A"), "")
        self.assertEqual(clean_perfumer(None), "")
        self.assertEqual(clean_perfumer(""), "")


class TestFlankerGrouping(unittest.TestCase):
    def test_extract_base_line_sauvage(self):
        self.assertEqual(extract_base_line("Sauvage", "Dior"), "Sauvage")
        self.assertEqual(extract_base_line("Sauvage Eau de Parfum", "Dior"), "Sauvage")
        self.assertEqual(extract_base_line("Sauvage Parfum", "Dior"), "Sauvage")
        self.assertEqual(extract_base_line("Sauvage Elixir", "Dior"), "Sauvage")
        self.assertEqual(extract_base_line("Sauvage Eau Forte", "Dior"), "Sauvage")

    def test_extract_base_line_bleu_de_chanel(self):
        self.assertEqual(extract_base_line("Bleu de Chanel", "Chanel"), "Bleu de Chanel")
        self.assertEqual(extract_base_line("Bleu de Chanel Eau de Parfum", "Chanel"), "Bleu de Chanel")
        self.assertEqual(extract_base_line("Bleu de Chanel Parfum", "Chanel"), "Bleu de Chanel")

    def test_extract_base_line_dior_homme(self):
        self.assertEqual(extract_base_line("Dior Homme", "Dior"), "Dior Homme")
        self.assertEqual(extract_base_line("Dior Homme Intense 2011", "Dior"), "Dior Homme")
        self.assertEqual(extract_base_line("Dior Homme Cologne 2013", "Dior"), "Dior Homme")
        self.assertEqual(extract_base_line("Dior Homme 2020", "Dior"), "Dior Homme")

    def test_extract_base_line_acqua_di_gio(self):
        self.assertEqual(extract_base_line("Acqua di Giò", "Giorgio Armani"), "Acqua di Giò")
        self.assertEqual(extract_base_line("Acqua di Giò Profumo", "Giorgio Armani"), "Acqua di Giò")
        self.assertEqual(extract_base_line("Acqua di Giò Parfum", "Giorgio Armani"), "Acqua di Giò")
        self.assertEqual(extract_base_line("Acqua di Gioia", "Giorgio Armani"), "Acqua di Gioia")

    def test_generate_flanker_id_deterministic(self):
        h1 = generate_flanker_id("Dior", "Sauvage")
        h2 = generate_flanker_id("dior", "sauvage")
        h3 = generate_flanker_id("Dior", "Dior Homme")
        self.assertEqual(h1, h2)
        self.assertEqual(len(h1), 6)
        self.assertNotEqual(h1, h3)


class TestExportedDatasetInvariants(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.json_path = os.path.join(os.path.dirname(__file__), "scentle_db.json")
        if not os.path.exists(cls.json_path):
            raise unittest.SkipTest("scentle_db.json not found; run export first.")
        with open(cls.json_path, "r", encoding="utf-8") as f:
            cls.data = json.load(f)

    def test_file_size_under_limit(self):
        size_bytes = os.path.getsize(self.json_path)
        size_mb = size_bytes / (1024 * 1024)
        self.assertLessEqual(size_mb, 4.5, f"File size {size_mb:.2f} MB exceeds 4.5 MB budget")

    def test_tier1_record_count(self):
        self.assertGreaterEqual(len(self.data), 8000)
        self.assertLessEqual(len(self.data), 15000)

    def test_tier2_record_count(self):
        t2_items = [p for p in self.data if p.get("m") == 1]
        self.assertGreaterEqual(len(t2_items), 800)
        self.assertLessEqual(len(t2_items), 1500)

    def test_schema_keys_present(self):
        sample = self.data[0]
        required_keys = {"id", "n", "b", "c", "y", "g", "p", "img", "v", "fl", "nt", "ac"}
        self.assertTrue(required_keys.issubset(sample.keys()))

    def test_flanker_cap_in_tier2(self):
        """Ensures at most 2 perfumes per baseLine in Tier 2 mystery pool."""
        t2_items = [p for p in self.data if p.get("m") == 1]
        fl_counts = {}
        for p in t2_items:
            fl_counts[p["fl"]] = fl_counts.get(p["fl"], 0) + 1
        for fl, count in fl_counts.items():
            self.assertLessEqual(
                count, 2, f"Line {fl} has {count} perfumes in Tier 2 (max allowed is 2)"
            )

    def test_sauvage_flanker_deduplication(self):
        sauvage_all = [p for p in self.data if "Sauvage" in p["n"] and p["b"] == "Dior"]
        sauvage_fls = {p["fl"] for p in sauvage_all if p["n"] in ["Sauvage", "Sauvage Elixir", "Sauvage Eau de Parfum", "Sauvage Parfum"]}
        # All core Sauvages must share identical fl
        self.assertEqual(len(sauvage_fls), 1)

        # Count how many core Sauvages made it to Tier 2
        core_fl = list(sauvage_fls)[0]
        sauvage_t2 = [p for p in self.data if p.get("m") == 1 and p["fl"] == core_fl]
        self.assertLessEqual(len(sauvage_t2), 2)
        # Should be top 2: Sauvage (29,943 votes) and Sauvage Elixir (16,369 votes)
        t2_names = [p["n"] for p in sauvage_t2]
        self.assertIn("Sauvage", t2_names)
        self.assertIn("Sauvage Elixir", t2_names)

    def test_tier2_data_completeness(self):
        t2_items = [p for p in self.data if p.get("m") == 1]
        for item in t2_items:
            self.assertGreater(item["y"], 1800, f"Perfume {item['id']} invalid year")
            self.assertTrue(bool(item["b"].strip()), f"Perfume {item['id']} empty brand")
            self.assertGreaterEqual(len(item["ac"]), 3, f"Perfume {item['id']} has <3 accords")
            nt = item["nt"]
            self.assertIn("t", nt, f"Perfume {item['id']} missing top notes")
            self.assertIn("m", nt, f"Perfume {item['id']} missing middle notes")
            self.assertIn("b", nt, f"Perfume {item['id']} missing base notes")
            self.assertGreater(len(nt["t"]), 0)
            self.assertGreater(len(nt["m"]), 0)
            self.assertGreater(len(nt["b"]), 0)


if __name__ == "__main__":
    unittest.main()
