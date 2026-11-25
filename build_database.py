"""
Create the SQLite database tokyo_electricity.db from the CSV files in this folder.

    python build_database.py

Steps: run schema.sql (CREATE TABLE), then INSERT every row from
calendar.csv, stations.csv, demand_hourly.csv.gz and weather_hourly.csv.gz.
Uses only the Python standard library (sqlite3, csv, gzip).
"""
import csv
import gzip
import sqlite3
from pathlib import Path

HERE = Path(__file__).resolve().parent
DB = HERE / "tokyo_electricity.db"


def rows(path):
    opener = gzip.open if path.suffix == ".gz" else open
    with opener(path, "rt", encoding="utf-8", newline="") as f:
        yield from csv.DictReader(f)


def none_if_blank(v):
    return None if v in ("", None) else v


def build(db_path: Path = DB) -> dict:
    if db_path.exists():
        db_path.unlink()
    con = sqlite3.connect(db_path)
    con.execute("PRAGMA foreign_keys = ON")
    con.executescript((HERE / "schema.sql").read_text(encoding="utf-8"))

    con.executemany(
        "INSERT INTO calendar VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
        [(r["date"], int(r["year"]), int(r["month"]), r["weekday"], r["season"], none_if_blank(r["holiday_name"]),
          int(r["is_holiday"]), int(r["is_workday"])) for r in rows(HERE / "calendar.csv")])

    con.executemany(
        "INSERT INTO stations VALUES (?, ?, ?, ?, ?)",
        [(int(r["station_id"]), r["name_en"], r["name_ja"], r["prefecture"], float(r["prefecture_population_10k"]))
         for r in rows(HERE / "stations.csv")])

    con.executemany(
        "INSERT INTO demand_hourly VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
        [(r["datetime"], r["datetime"][:10], int(r["datetime"][11:13]), float(r["demand_gw"]),
          float(r["forecast_gw"]), float(r["supply_gw"]), int(r["usage_rate_pct"]), float(r["solar_gw"]))
         for r in rows(HERE / "demand_hourly.csv.gz")])

    con.executemany(
        "INSERT INTO weather_hourly VALUES (?, ?, ?, ?, ?)",
        [(r["datetime"], int(r["station_id"]), none_if_blank(r["temp_c"]), none_if_blank(r["rh_pct"]),
          none_if_blank(r["sun_h"])) for r in rows(HERE / "weather_hourly.csv.gz")])

    con.commit()
    counts = {t: con.execute(f"SELECT COUNT(*) FROM {t}").fetchone()[0]
              for t in ["calendar", "stations", "demand_hourly", "weather_hourly"]}
    problems = con.execute("PRAGMA foreign_key_check").fetchall()
    con.execute("VACUUM")
    con.close()
    return {"rows": counts, "foreign_key_problems": len(problems)}


if __name__ == "__main__":
    print(build())
