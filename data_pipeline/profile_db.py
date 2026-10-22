#!/usr/bin/env python3
"""
profile_db.py
-------------
FragranceDB Schema Discovery & Statistical Profiling Engine.
Analyzes local SQL Server dataset for Scentle game database extraction.
"""

import argparse
import os
import sys
from typing import Dict, List, Any, Optional
import pyodbc
import pandas as pd
import numpy as np


def get_connection(
    server: str = "localhost",
    database: str = "FragranceDB",
    user: Optional[str] = None,
    password: Optional[str] = None,
    driver: Optional[str] = None,
) -> pyodbc.Connection:
    """
    Establishes an ODBC connection to SQL Server with fallback driver resolution.
    Supports Windows Authentication and SQL Server Authentication.
    """
    available_drivers = [d for d in pyodbc.drivers() if "SQL Server" in d]
    
    if driver is None:
        # Prefer ODBC Driver 18, then 17, then standard SQL Server
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
    print(f"Connecting to SQL Server via [{driver}] at [{server}] (Database: {database})...")
    return pyodbc.connect(conn_str)


def discover_schema(conn: pyodbc.Connection) -> pd.DataFrame:
    """Discovers all tables and columns in INFORMATION_SCHEMA."""
    query = """
    SELECT 
        TABLE_SCHEMA,
        TABLE_NAME,
        COLUMN_NAME,
        ORDINAL_POSITION,
        DATA_TYPE,
        IS_NULLABLE,
        CHARACTER_MAXIMUM_LENGTH
    FROM INFORMATION_SCHEMA.COLUMNS
    ORDER BY TABLE_SCHEMA, TABLE_NAME, ORDINAL_POSITION;
    """
    return pd.read_sql(query, conn)


def profile_dataset(conn: pyodbc.Connection) -> Dict[str, Any]:
    """
    Runs comprehensive profiling queries on FragranceDB tables:
    Perfumes, Brands, Countries, Notes, PerfumeNotes, Accords, PerfumeAccords, PerfumeVotes.
    """
    cursor = conn.cursor()

    # 1. Total counts across core tables
    table_counts = {}
    for tbl in [
        "Perfumes", "Brands", "Countries", "Notes", 
        "PerfumeNotes", "Accords", "PerfumeAccords", "PerfumeVotes"
    ]:
        cursor.execute(f"SELECT COUNT(*) FROM dbo.{tbl}")
        table_counts[tbl] = cursor.fetchone()[0]

    # 2. Votes distribution and percentiles
    votes_query = """
    SELECT 
        p.perfume_id,
        COALESCE(v.rating_count, 0) AS vote_count,
        v.rating_value,
        v.review_count
    FROM dbo.Perfumes p
    LEFT JOIN dbo.PerfumeVotes v ON p.perfume_id = v.perfume_id
    """
    df_votes = pd.read_sql(votes_query, conn)

    vote_series = df_votes["vote_count"]
    percentiles = {
        "50th (Median)": float(vote_series.quantile(0.50)),
        "75th": float(vote_series.quantile(0.75)),
        "90th": float(vote_series.quantile(0.90)),
        "95th": float(vote_series.quantile(0.95)),
        "99th": float(vote_series.quantile(0.99)),
    }

    # Vote count brackets
    brackets = [0, 1, 10, 25, 50, 75, 100, 150, 200, 300, 500, 1000, 2500, 5000]
    bracket_counts = {
        f">= {b}": int((vote_series >= b).sum()) for b in brackets
    }

    # 3. Completeness breakdown
    completeness_query = """
    WITH NoteCounts AS (
        SELECT 
            perfume_id,
            COUNT(DISTINCT note_id) AS total_notes,
            COUNT(DISTINCT CASE WHEN note_level = 'top' THEN note_id END) AS top_notes,
            COUNT(DISTINCT CASE WHEN note_level = 'middle' THEN note_id END) AS middle_notes,
            COUNT(DISTINCT CASE WHEN note_level = 'base' THEN note_id END) AS base_notes,
            COUNT(DISTINCT CASE WHEN note_level = 'linear' THEN note_id END) AS linear_notes
        FROM dbo.PerfumeNotes
        GROUP BY perfume_id
    ),
    AccordCounts AS (
        SELECT 
            perfume_id,
            COUNT(DISTINCT accord_id) AS total_accords
        FROM dbo.PerfumeAccords
        GROUP BY perfume_id
    )
    SELECT 
        p.perfume_id,
        p.perfume_name,
        p.launch_year,
        p.perfume_for,
        p.perfumer_name,
        p.image_url,
        b.brand_name,
        c.country_name,
        COALESCE(v.rating_count, 0) AS vote_count,
        COALESCE(nc.total_notes, 0) AS total_notes,
        COALESCE(nc.top_notes, 0) AS top_notes,
        COALESCE(nc.middle_notes, 0) AS middle_notes,
        COALESCE(nc.base_notes, 0) AS base_notes,
        COALESCE(nc.linear_notes, 0) AS linear_notes,
        COALESCE(ac.total_accords, 0) AS total_accords
    FROM dbo.Perfumes p
    LEFT JOIN dbo.Brands b ON p.brand_id = b.id
    LEFT JOIN dbo.Countries c ON b.country_id = c.country_id
    LEFT JOIN dbo.PerfumeVotes v ON p.perfume_id = v.perfume_id
    LEFT JOIN NoteCounts nc ON p.perfume_id = nc.perfume_id
    LEFT JOIN AccordCounts ac ON p.perfume_id = ac.perfume_id;
    """
    df_comp = pd.read_sql(completeness_query, conn)

    # Filtering completeness masks
    has_valid_year = (df_comp["launch_year"].notna()) & (df_comp["launch_year"] > 1800) & (df_comp["launch_year"] <= 2026)
    has_valid_brand = df_comp["brand_name"].notna() & (df_comp["brand_name"].str.strip() != "")
    has_ge_3_notes = df_comp["total_notes"] >= 3
    has_ge_2_accords = df_comp["total_accords"] >= 2
    has_ge_3_accords = df_comp["total_accords"] >= 3
    has_pyramid = (df_comp["top_notes"] > 0) & (df_comp["middle_notes"] > 0) & (df_comp["base_notes"] > 0)
    has_image = df_comp["image_url"].notna() & (df_comp["image_url"].str.strip() != "")

    complete_basic = has_valid_year & has_ge_3_notes & has_ge_2_accords
    complete_strict = has_valid_year & has_valid_brand & has_ge_3_notes & has_ge_3_accords

    report = {
        "table_counts": table_counts,
        "vote_percentiles": percentiles,
        "vote_brackets": bracket_counts,
        "total_perfumes": len(df_comp),
        "valid_year_count": int(has_valid_year.sum()),
        "valid_brand_count": int(has_valid_brand.sum()),
        "ge_3_notes_count": int(has_ge_3_notes.sum()),
        "ge_2_accords_count": int(has_ge_2_accords.sum()),
        "ge_3_accords_count": int(has_ge_3_accords.sum()),
        "pyramid_notes_count": int(has_pyramid.sum()),
        "image_count": int(has_image.sum()),
        "complete_basic_count": int(complete_basic.sum()),
        "complete_strict_count": int(complete_strict.sum()),
        "df_comp": df_comp,
    }
    return report


def main():
    parser = argparse.ArgumentParser(description="Profile FragranceDB for Scentle")
    parser.add_argument("--server", default="localhost", help="SQL Server host / instance")
    parser.add_argument("--database", default="FragranceDB", help="Database name")
    parser.add_argument("--user", default=None, help="SQL username (if using SQL auth)")
    parser.add_argument("--password", default=None, help="SQL password (if using SQL auth)")
    args = parser.parse_args()

    conn = get_connection(args.server, args.database, args.user, args.password)

    print("\n" + "=" * 70)
    print("SCHEMA DISCOVERY: INFORMATION_SCHEMA REPORT")
    print("=" * 70)
    df_schema = discover_schema(conn)
    tables = df_schema["TABLE_NAME"].unique()
    for tbl in tables:
        cols = df_schema[df_schema["TABLE_NAME"] == tbl]
        col_summary = [f"{r['COLUMN_NAME']} ({r['DATA_TYPE']})" for _, r in cols.iterrows()]
        print(f"Table [{tbl}] ({len(cols)} columns):")
        print(f"  -> {', '.join(col_summary)}\n")

    print("=" * 70)
    print("DATASET STATISTICAL PROFILE")
    print("=" * 70)
    profile = profile_dataset(conn)

    print("\n--- Row Counts per Table ---")
    for tbl, count in profile["table_counts"].items():
        print(f"  {tbl:20s}: {count:>10,d}")

    print("\n--- Perfume Votes Percentiles (All Perfumes) ---")
    for pct, val in profile["vote_percentiles"].items():
        print(f"  {pct:18s}: {val:>10.1f} votes")

    print("\n--- Perfumes by Minimum Vote Threshold ---")
    for brk, count in profile["vote_brackets"].items():
        pct = (count / profile["total_perfumes"]) * 100
        print(f"  Votes {brk:10s}: {count:>8,d} perfumes ({pct:5.1f}%)")

    print("\n--- Completeness Metrics ---")
    tot = profile["total_perfumes"]
    print(f"  Total Perfumes                     : {tot:>8,d} (100.0%)")
    print(f"  Valid Release Year (>1800)         : {profile['valid_year_count']:>8,d} ({profile['valid_year_count']/tot*100:5.1f}%)")
    print(f"  Valid Brand Name                   : {profile['valid_brand_count']:>8,d} ({profile['valid_brand_count']/tot*100:5.1f}%)")
    print(f"  Notes >= 3                         : {profile['ge_3_notes_count']:>8,d} ({profile['ge_3_notes_count']/tot*100:5.1f}%)")
    print(f"  Accords >= 2                       : {profile['ge_2_accords_count']:>8,d} ({profile['ge_2_accords_count']/tot*100:5.1f}%)")
    print(f"  Accords >= 3                       : {profile['ge_3_accords_count']:>8,d} ({profile['ge_3_accords_count']/tot*100:5.1f}%)")
    print(f"  Full Pyramid (Top+Middle+Base)     : {profile['pyramid_notes_count']:>8,d} ({profile['pyramid_notes_count']/tot*100:5.1f}%)")
    print(f"  Bottle Image Available             : {profile['image_count']:>8,d} ({profile['image_count']/tot*100:5.1f}%)")
    print(f"  Complete (Year + >=3 Notes + >=2 Accords): {profile['complete_basic_count']:>8,d} ({profile['complete_basic_count']/tot*100:5.1f}%)")
    print(f"  Strict Complete (+Brand + >=3 Accords)   : {profile['complete_strict_count']:>8,d} ({profile['complete_strict_count']/tot*100:5.1f}%)")

    # Tier candidate analysis
    df = profile["df_comp"]
    print("\n" + "=" * 70)
    print("TIER CANDIDATE SIZE & COMPLETENESS SIMULATION")
    print("=" * 70)

    # Searchable Pool (Tier 1) Candidates:
    # Requires: non-empty brand, total_notes >= 1, vote_count >= threshold
    print("\n[Tier 1 Candidates: Searchable Guess Pool]")
    for min_votes in [1, 5, 10, 15, 20, 25, 30, 40, 50, 60, 75, 100]:
        t1_cand = df[
            (df["brand_name"].notna()) & 
            (df["brand_name"].str.strip() != "") &
            (df["total_notes"] >= 1) & 
            (df["total_accords"] >= 1) &
            (df["vote_count"] >= min_votes)
        ]
        cnt = len(t1_cand)
        # Approximate JSON size: average ~280 bytes minified per perfume record
        est_mb = (cnt * 280) / (1024 * 1024)
        print(f"  Cutoff >= {min_votes:3d} votes: {cnt:>7,d} perfumes | Est. Minified JSON Size: ~{est_mb:4.2f} MB")

    # Mystery Target Pool (Tier 2) Candidates:
    # Requires: high votes, valid year, non-empty brand, total_notes >= 3, total_accords >= 3
    print("\n[Tier 2 Candidates: Iconic Mystery Target Pool]")
    for min_votes in [300, 400, 500, 600, 700, 800, 900, 1000, 1200, 1500, 2000]:
        t2_cand = df[
            (df["brand_name"].notna()) & 
            (df["brand_name"].str.strip() != "") &
            (df["launch_year"].notna()) & 
            (df["launch_year"] > 1800) & 
            (df["launch_year"] <= 2026) &
            (df["total_notes"] >= 3) & 
            (df["total_accords"] >= 3) &
            (df["vote_count"] >= min_votes)
        ]
        cnt = len(t2_cand)
        pyramid_ratio = (t2_cand["top_notes"] > 0) & (t2_cand["middle_notes"] > 0) & (t2_cand["base_notes"] > 0)
        pyr_pct = (pyramid_ratio.sum() / cnt * 100) if cnt > 0 else 0
        print(f"  Cutoff >= {min_votes:4d} votes: {cnt:>5,d} perfumes | Full Pyramid: {pyr_pct:5.1f}%")

    conn.close()
    print("\nProfiling completed successfully.")


if __name__ == "__main__":
    main()
