-- =====================================================================================
-- Tokyo electricity demand database (SQLite)
-- 4 related tables: hourly demand, hourly weather (8 JMA stations), stations, calendar
-- =====================================================================================

DROP TABLE IF EXISTS weather_hourly;
DROP TABLE IF EXISTS demand_hourly;
DROP TABLE IF EXISTS stations;
DROP TABLE IF EXISTS calendar;

-- One row per day: Japanese calendar information
CREATE TABLE calendar (
    date          TEXT    PRIMARY KEY,          -- 'YYYY-MM-DD'
    year          INTEGER NOT NULL,
    month         INTEGER NOT NULL CHECK (month BETWEEN 1 AND 12),
    weekday       TEXT    NOT NULL,             -- 'Monday' ... 'Sunday'
    season        TEXT    NOT NULL CHECK (season IN ('Winter', 'Spring', 'Summer', 'Autumn')),
    holiday_name  TEXT,                         -- NULL on ordinary days
    is_holiday    INTEGER NOT NULL CHECK (is_holiday IN (0, 1)),
    is_workday    INTEGER NOT NULL CHECK (is_workday IN (0, 1))
);

-- One row per JMA weather station
CREATE TABLE stations (
    station_id                 INTEGER PRIMARY KEY,   -- JMA station number, e.g. 47662 = Tokyo
    name_en                    TEXT NOT NULL,
    name_ja                    TEXT NOT NULL,
    prefecture                 TEXT NOT NULL,
    prefecture_population_10k  REAL NOT NULL          -- 2020 census, in units of 10,000 people
);

-- One row per hour: TEPCO area electricity data
CREATE TABLE demand_hourly (
    datetime        TEXT PRIMARY KEY,                 -- 'YYYY-MM-DD HH:MM:SS' (JST)
    date            TEXT NOT NULL REFERENCES calendar(date),
    hour            INTEGER NOT NULL CHECK (hour BETWEEN 0 AND 23),
    demand_gw       REAL NOT NULL CHECK (demand_gw > 0),
    forecast_gw     REAL,                             -- TEPCO's published forecast
    supply_gw       REAL,                             -- available supply capacity
    usage_rate_pct  INTEGER CHECK (usage_rate_pct BETWEEN 0 AND 100),
    solar_gw        REAL CHECK (solar_gw >= 0)
);

-- One row per hour per station: JMA observations
CREATE TABLE weather_hourly (
    datetime    TEXT    NOT NULL REFERENCES demand_hourly(datetime),
    station_id  INTEGER NOT NULL REFERENCES stations(station_id),
    temp_c      REAL,
    rh_pct      REAL CHECK (rh_pct BETWEEN 0 AND 100),
    sun_h       REAL CHECK (sun_h BETWEEN 0 AND 1),
    PRIMARY KEY (datetime, station_id)
);

CREATE INDEX idx_demand_date    ON demand_hourly(date);
CREATE INDEX idx_weather_station ON weather_hourly(station_id);
