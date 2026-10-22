#!/usr/bin/env python3
"""
export_scentle_json.py
----------------------
High-performance export pipeline for Scentle mobile game database.
Extracts Tier 1 (Searchable Guess Pool) with Fragrance Line ID ("fl")
and flags Tier 2 (Mystery Target Pool) capped at max 2 perfumes per base line.
Outputs minified JSON under 4.5 MB.
"""

import argparse
import hashlib
import json
import os
import re
import sys
import time
from typing import Dict, List, Any, Optional, Tuple
import pyodbc


# Regex terms for baseLine normalization
FLANKER_TERMS = [
    r"\beau\s+de\s+parfum\b",
    r"\beau\s+de\s+toilette\b",
    r"\beau\s+de\s+cologne\b",
    r"\beau\s+fra[iî]che\b",
    r"\beau\s+forte\b",
    r"\bextrait\s+de\s+parfum\b",
    r"\bpure\s+parfum\b",
    r"\bparfum\s+cologne\b",
    r"\ble\s+parfum\b",
    r"\bparfum\b",
    r"\bprofumo\b",
    r"\bedp\b",
    r"\bedt\b",
    r"\bedc\b",
    r"\bcologne\s+intense\b",
    r"\bcologne\b",
    r"\bextrait\b",
    r"\belixir\b",
    r"\bélixir\b",
    r"\bintens[eé]ment\b",
    r"\bintense\b",
    r"\bextr[eê]me\b",
    r"\bextreme\b",
    r"\babsolu\b",
    r"\babsolue\b",
    r"\bvery\s+cool\s+spray\b",
]

COMPILED_FLANKER_TERMS = [re.compile(t, re.IGNORECASE) for t in FLANKER_TERMS]


def extract_base_line(name: str, brand: str = "") -> str:
    """
    Extracts a normalized parent baseLine string for flanker grouping.
    Strips concentration terms, editions, flanker modifiers, and standalone years.
    Examples:
      - 'Sauvage Eau de Parfum' -> 'Sauvage'
      - 'Sauvage Elixir' -> 'Sauvage'
      - 'Bleu de Chanel Parfum' -> 'Bleu de Chanel'
      - 'Dior Homme Intense 2011' -> 'Dior Homme'
      - 'Acqua di Giò Profumo' -> 'Acqua di Giò'
      - 'Miss Dior (2012)' -> 'Miss Dior'
    """
    if not name:
        return ""

    s = name.replace("’", "'").replace("`", "'")

    # 1. Strip bracketed/parenthesized years: (2012), [2018], etc.
    s = re.sub(r"[\(\[]\s*\d{4}\s*[\)\]]", "", s)

    # 2. Strip standalone 4-digit years at word boundary (e.g. 2011, 2020)
    s = re.sub(r"\b(19\d\d|20\d\d)\b", "", s)

    # 3. Strip concentration and flanker modifier suffixes
    for pat in COMPILED_FLANKER_TERMS:
        s = pat.sub("", s)

    # Strip trailing/embedded l'eau if the name has other substance (e.g., "Bleu L'Eau" -> "Bleu", but keep "L'Eau d'Issey")
    s = re.sub(r"(?<=\w)\s+l\'eau\b", "", s, flags=re.IGNORECASE)

    # Clean up punctuation and multiple whitespace
    s = re.sub(r"[\(\)\[\]\-_,:\/]", " ", s)
    s = re.sub(r"\s+", " ", s).strip()
    return s if s else name


def generate_flanker_id(brand: str, base_line: str) -> str:
    """
    Generates a deterministic 6-character hex hash representing the Fragrance Line ID ('fl').
    Scoped to brand and normalized baseLine.
    """
    key = f"{brand.strip().lower()}:{base_line.strip().lower()}"
    return hashlib.md5(key.encode("utf-8")).hexdigest()[:6]


def get_connection(
    server: str = "localhost",
    database: str = "FragranceDB",
    user: Optional[str] = None,
    password: Optional[str] = None,
) -> pyodbc.Connection:
    """Connects to SQL Server with driver fallback and trusted connection."""
    available_drivers = [d for d in pyodbc.drivers() if "SQL Server" in d]
    preferred = [
        "ODBC Driver 18 for SQL Server",
        "ODBC Driver 17 for SQL Server",
        "SQL Server",
    ]
    driver = next((d for d in preferred if d in available_drivers), available_drivers[0] if available_drivers else "SQL Server")

    conn_parts = [
        f"DRIVER={{{driver}}}",
        f"SERVER={server}",
        f"DATABASE={database}",
    ]
    if user and password:
        conn_parts.extend([f"UID={user}", f"PWD={password}"])
    else:
        conn_parts.append("Trusted_Connection=yes")

    if "ODBC Driver 18" in driver:
        conn_parts.append("TrustServerCertificate=yes")

    conn_str = ";".join(conn_parts) + ";"
    print(f"Connecting to SQL Server via [{driver}] at [{server}] (DB: {database})...")
    return pyodbc.connect(conn_str)


def clean_perfume_name(name: str, brand: str) -> str:
    """
    Cleans raw Fragrantica perfume titles by stripping duplicate trailing brand names
    and redundant punctuation.
    """
    if not name:
        return ""
    clean = name.strip()
    if brand:
        b_clean = brand.strip()
        if clean.endswith(b_clean) and len(clean) > len(b_clean):
            clean = clean[:-len(b_clean)].strip()
            clean = clean.rstrip(" -:,/")
    return clean.strip()


def normalize_gender(perfume_for: Optional[str]) -> str:
    """Normalizes Fragrantica 'perfume_for' string to standard compact gender."""
    if not perfume_for:
        return "Unisex"
    s = perfume_for.lower().strip()
    if s == "for men":
        return "Men"
    elif s == "for women":
        return "Women"
    else:
        return "Unisex"


def clean_perfumer(perfumer_name: Optional[str]) -> str:
    """Normalizes perfumer string, stripping placeholder values like N/A."""
    if not perfumer_name or perfumer_name.strip() in ("N/A", "null", "None", ""):
        return ""
    return perfumer_name.strip()


def extract_and_export(
    conn: pyodbc.Connection,
    output_path: str,
    t1_vote_cutoff: int = 220,
    t2_vote_cutoff: int = 2200,
    max_flankers_in_t2: int = 2,
    max_accords_per_perfume: int = 5,
    max_size_mb: float = 4.5,
) -> Tuple[int, int, float]:
    """
    Extracts Tier 1 and Tier 2 perfumes, assigns Fragrance Line ID ("fl"),
    deduplicates Tier 2 flankers to max 2 per baseLine, and writes minified JSON.
    """
    cursor = conn.cursor()
    start_time = time.time()

    print(f"\n[1/4] Querying Tier 1 candidate pool (Votes >= {t1_vote_cutoff})...")
    perfumes_query = f"""
    SELECT 
        p.perfume_id,
        p.perfume_name,
        b.brand_name,
        COALESCE(c.country_name, '') AS country_name,
        COALESCE(p.launch_year, 0) AS launch_year,
        p.perfume_for,
        p.perfumer_name,
        COALESCE(p.image_url, '') AS image_url,
        COALESCE(v.rating_count, 0) AS vote_count
    FROM dbo.Perfumes p
    JOIN dbo.Brands b ON p.brand_id = b.id
    LEFT JOIN dbo.Countries c ON b.country_id = c.country_id
    JOIN dbo.PerfumeVotes v ON p.perfume_id = v.perfume_id
    WHERE v.rating_count >= {t1_vote_cutoff}
      AND b.brand_name IS NOT NULL AND b.brand_name != ''
      AND EXISTS (SELECT 1 FROM dbo.PerfumeNotes WHERE perfume_id = p.perfume_id)
      AND EXISTS (SELECT 1 FROM dbo.PerfumeAccords WHERE perfume_id = p.perfume_id)
    ORDER BY v.rating_count DESC;
    """
    cursor.execute(perfumes_query)
    perfume_rows = cursor.fetchall()
    total_t1 = len(perfume_rows)
    print(f"      Selected {total_t1:,} perfumes for Tier 1.")

    if total_t1 == 0:
        raise ValueError(f"No perfumes matched criteria with cutoff >= {t1_vote_cutoff}")

    p_ids = [r[0] for r in perfume_rows]

    # Populate temporary table for high-performance indexed join
    print("[2/4] Indexing selected IDs and batching child Notes and Accords...")
    cursor.execute("CREATE TABLE #SelectedPerfumes (perfume_id INT PRIMARY KEY);")
    cursor.fast_executemany = True
    cursor.executemany("INSERT INTO #SelectedPerfumes VALUES (?);", [(pid,) for pid in p_ids])

    # Fetch notes
    notes_query = """
    SELECT 
        pn.perfume_id,
        pn.note_level,
        n.note_name
    FROM dbo.PerfumeNotes pn
    JOIN dbo.Notes n ON pn.note_id = n.note_id
    JOIN #SelectedPerfumes s ON pn.perfume_id = s.perfume_id;
    """
    cursor.execute(notes_query)
    notes_map: Dict[int, Dict[str, List[str]]] = {}
    for pid, note_level, note_name in cursor.fetchall():
        if pid not in notes_map:
            notes_map[pid] = {"t": [], "m": [], "b": [], "l": []}
        lvl = note_level.lower().strip() if note_level else "m"
        key = "t" if lvl == "top" else ("m" if lvl == "middle" else ("b" if lvl == "base" else "l"))
        notes_map[pid][key].append(note_name)

    # Fetch accords ordered by strength descending
    accords_query = """
    SELECT 
        pa.perfume_id,
        a.accord_name,
        pa.accord_strength
    FROM dbo.PerfumeAccords pa
    JOIN dbo.Accords a ON pa.accord_id = a.accord_id
    JOIN #SelectedPerfumes s ON pa.perfume_id = s.perfume_id
    ORDER BY pa.perfume_id, pa.accord_strength DESC;
    """
    cursor.execute(accords_query)
    accords_map: Dict[int, List[str]] = {}
    for pid, accord_name, strength in cursor.fetchall():
        if pid not in accords_map:
            accords_map[pid] = []
        if len(accords_map[pid]) < max_accords_per_perfume:
            accords_map[pid].append(accord_name)

    cursor.execute("DROP TABLE #SelectedPerfumes;")

    print(f"[3/4] Flanker grouping, Fragrance Line ID hashing, and Tier 2 cap (max {max_flankers_in_t2}/line)...")
    records = []
    t2_count = 0
    flanker_t2_tracker: Dict[str, int] = {}

    # Since perfume_rows is ORDERED BY v.rating_count DESC,
    # the highest-voted original is evaluated first, followed by the top flanker.
    for row in perfume_rows:
        pid, raw_name, brand, country, year, p_for, perfumer, img, votes = row
        clean_name = clean_perfume_name(raw_name, brand)
        gender = normalize_gender(p_for)
        perfumer_clean = clean_perfumer(perfumer)

        # Flanker parent line extraction & deterministic line ID
        base_line = extract_base_line(clean_name, brand)
        fl_id = generate_flanker_id(brand, base_line)

        # Notes structure
        p_notes = notes_map.get(pid, {"t": [], "m": [], "b": [], "l": []})
        nt_obj = {}
        if p_notes["t"]:
            nt_obj["t"] = p_notes["t"]
        if p_notes["m"]:
            nt_obj["m"] = p_notes["m"]
        if p_notes["b"]:
            nt_obj["b"] = p_notes["b"]
        if p_notes["l"]:
            nt_obj["l"] = p_notes["l"]

        # Accords
        p_accords = accords_map.get(pid, [])

        # Tier 2 eligibility check:
        # High votes (>= cutoff), valid year (>1800), non-empty brand, >= 3 accords,
        # and populated notes (Top + Middle + Base).
        is_t2_eligible = (
            votes >= t2_vote_cutoff and
            year is not None and 1800 < year <= 2026 and
            bool(brand) and
            len(p_notes.get("t", [])) > 0 and
            len(p_notes.get("m", [])) > 0 and
            len(p_notes.get("b", [])) > 0 and
            len(p_accords) >= 3
        )

        is_t2 = False
        if is_t2_eligible:
            chosen_for_line = flanker_t2_tracker.get(fl_id, 0)
            if chosen_for_line < max_flankers_in_t2:
                is_t2 = True
                flanker_t2_tracker[fl_id] = chosen_for_line + 1
                t2_count += 1

        rec: Dict[str, Any] = {
            "id": pid,
            "n": clean_name,
            "b": brand,
            "c": country,
            "y": year,
            "g": gender,
            "p": perfumer_clean,
            "img": img,
            "v": votes,
            "fl": fl_id,
            "nt": nt_obj,
            "ac": p_accords,
        }

        if is_t2:
            rec["m"] = 1

        records.append(rec)

    print(f"[4/4] Serializing {len(records):,} records to minified JSON: {output_path}...")
    os.makedirs(os.path.dirname(os.path.abspath(output_path)), exist_ok=True)

    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(records, f, separators=(",", ":"), ensure_ascii=False)

    file_size_bytes = os.path.getsize(output_path)
    file_size_mb = file_size_bytes / (1024 * 1024)
    elapsed = time.time() - start_time

    print(f"\n=======================================================")
    print(f"EXPORT COMPLETED SUCCESSFULLY in {elapsed:.2f}s")
    print(f"=======================================================")
    print(f"  Target File          : {output_path}")
    print(f"  Total Tier 1 Pool    : {total_t1:,} perfumes (Vote cutoff >= {t1_vote_cutoff})")
    print(f"  Tier 2 Mystery Pool  : {t2_count:,} perfumes (Vote cutoff >= {t2_vote_cutoff}, max {max_flankers_in_t2}/line)")
    print(f"  Uncompressed Size    : {file_size_mb:.2f} MB ({file_size_bytes:,} bytes)")
    print(f"  Size Limit Budget    : {max_size_mb:.2f} MB (Headroom: {max_size_mb - file_size_mb:.2f} MB)")
    print(f"=======================================================\n")

    if file_size_mb > max_size_mb:
        raise ValueError(
            f"Export exceeded size constraint! File is {file_size_mb:.2f} MB, "
            f"must be strictly under {max_size_mb:.2f} MB."
        )

    return total_t1, t2_count, file_size_mb


def main():
    parser = argparse.ArgumentParser(description="Export Scentle game database with flanker grouping")
    parser.add_argument("--server", default="localhost", help="SQL Server host / instance")
    parser.add_argument("--database", default="FragranceDB", help="Database name")
    parser.add_argument("--user", default=None, help="SQL username (if using SQL auth)")
    parser.add_argument("--password", default=None, help="SQL password (if using SQL auth)")
    parser.add_argument("--output", default="data_pipeline/scentle_db.json", help="Output JSON path")
    parser.add_argument("--t1-cutoff", type=int, default=220, help="Tier 1 min votes cutoff")
    parser.add_argument("--t2-cutoff", type=int, default=2200, help="Tier 2 min votes cutoff")
    parser.add_argument("--max-flankers", type=int, default=2, help="Max Tier 2 perfumes per flanker line")
    parser.add_argument("--max-size-mb", type=float, default=4.5, help="Max allowed uncompressed JSON size")
    args = parser.parse_args()

    conn = get_connection(args.server, args.database, args.user, args.password)
    extract_and_export(
        conn=conn,
        output_path=args.output,
        t1_vote_cutoff=args.t1_cutoff,
        t2_vote_cutoff=args.t2_cutoff,
        max_flankers_in_t2=args.max_flankers,
        max_size_mb=args.max_size_mb,
    )
    conn.close()


if __name__ == "__main__":
    main()
