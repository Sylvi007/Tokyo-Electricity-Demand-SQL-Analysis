-- =====================================================================================
-- Tokyo electricity demand - SQL analysis (SQLite)
-- Each query starts with "-- name:" and "-- question:" so run_queries.py can run them one by one.
-- Units: demand/supply/solar in GW (one hour of 1 GW = 1 GWh), temperature in °C.
-- =====================================================================================


-- ---------------------------------------------------------------------------
-- A. SELECT, WHERE, ORDER BY
-- ---------------------------------------------------------------------------

-- name: q01_top10_demand_hours
-- question: What were the 10 highest-demand hours, and how hot was Tokyo then?
SELECT d.datetime,
       d.demand_gw,
       w.temp_c AS tokyo_temp_c,
       d.usage_rate_pct
FROM demand_hourly AS d
JOIN weather_hourly AS w
  ON w.datetime = d.datetime AND w.station_id = 47662          -- Tokyo station
ORDER BY d.demand_gw DESC
LIMIT 10;

-- name: q02_tight_supply_hours
-- question: Which hours came closest to running out of supply (usage rate of 97% or more)?
SELECT datetime, demand_gw, supply_gw, usage_rate_pct,
       ROUND(supply_gw - demand_gw, 2) AS spare_gw
FROM demand_hourly
WHERE usage_rate_pct >= 97
ORDER BY usage_rate_pct DESC, spare_gw ASC;


-- ---------------------------------------------------------------------------
-- B. Aggregate functions
-- ---------------------------------------------------------------------------

-- name: q03_overall_summary
-- question: What does the whole dataset look like in one row?
SELECT COUNT(*)                                  AS hours,
       MIN(date)                                 AS first_day,
       MAX(date)                                 AS last_day,
       ROUND(AVG(demand_gw), 2)                  AS avg_demand_gw,
       MIN(demand_gw)                            AS min_demand_gw,
       MAX(demand_gw)                            AS max_demand_gw,
       ROUND(SUM(demand_gw) / 1000.0, 1)         AS total_energy_twh,
       ROUND(SUM(solar_gw) / SUM(demand_gw) * 100, 1) AS solar_share_pct
FROM demand_hourly;


-- ---------------------------------------------------------------------------
-- C. GROUP BY (+ HAVING)
-- ---------------------------------------------------------------------------

-- name: q04_by_year
-- question: How did demand, energy use and solar change from year to year?
SELECT c.year,
       COUNT(*)                                    AS hours,
       ROUND(AVG(d.demand_gw), 2)                  AS avg_demand_gw,
       MAX(d.demand_gw)                            AS peak_demand_gw,
       ROUND(SUM(d.demand_gw) / 1000.0, 1)         AS energy_twh,
       MAX(d.solar_gw)                             AS max_solar_gw,
       ROUND(SUM(d.solar_gw) / SUM(d.demand_gw) * 100, 1) AS solar_share_pct
FROM demand_hourly AS d
JOIN calendar AS c ON c.date = d.date
GROUP BY c.year
ORDER BY c.year;

-- name: q05_high_demand_months
-- question: Which calendar months average more than 33 GW? (GROUP BY + HAVING)
SELECT c.month,
       ROUND(AVG(d.demand_gw), 2) AS avg_demand_gw,
       MAX(d.demand_gw)           AS peak_demand_gw,
       COUNT(DISTINCT d.date)     AS days
FROM demand_hourly AS d
JOIN calendar AS c ON c.date = d.date
GROUP BY c.month
HAVING AVG(d.demand_gw) > 33
ORDER BY avg_demand_gw DESC;

-- name: q06_peak_hour_by_season
-- question: At what time of day does demand peak in each season?
SELECT c.season,
       d.hour,
       ROUND(AVG(d.demand_gw), 2) AS avg_demand_gw
FROM demand_hourly AS d
JOIN calendar AS c ON c.date = d.date
GROUP BY c.season, d.hour
HAVING AVG(d.demand_gw) = (
    SELECT MAX(avg_h) FROM (
        SELECT AVG(d2.demand_gw) AS avg_h
        FROM demand_hourly AS d2
        JOIN calendar AS c2 ON c2.date = d2.date
        WHERE c2.season = c.season
        GROUP BY d2.hour))
ORDER BY avg_demand_gw DESC;


-- ---------------------------------------------------------------------------
-- D. JOINs with the calendar table
-- ---------------------------------------------------------------------------

-- name: q07_workday_vs_dayoff
-- question: How much more electricity is used on workdays than on weekends and holidays?
SELECT CASE WHEN c.is_workday = 1 THEN 'Workday' ELSE 'Weekend / holiday' END AS day_type,
       COUNT(DISTINCT c.date)       AS days,
       ROUND(AVG(d.demand_gw), 2)   AS avg_demand_gw,
       MAX(d.demand_gw)             AS peak_demand_gw
FROM demand_hourly AS d
JOIN calendar AS c ON c.date = d.date
GROUP BY day_type
ORDER BY avg_demand_gw DESC;

-- name: q08_by_weekday
-- question: Which day of the week uses the most and least electricity (public holidays excluded)?
SELECT c.weekday,
       ROUND(AVG(d.demand_gw), 2) AS avg_demand_gw,
       MAX(d.demand_gw)           AS peak_demand_gw
FROM demand_hourly AS d
JOIN calendar AS c ON c.date = d.date
WHERE c.is_holiday = 0
GROUP BY c.weekday
ORDER BY avg_demand_gw DESC;

-- name: q09_holidays_ranked
-- question: Which holidays have the lowest demand?
SELECT c.holiday_name,
       COUNT(DISTINCT c.date)     AS days,
       ROUND(AVG(d.demand_gw), 2) AS avg_demand_gw,
       MIN(d.demand_gw)           AS lowest_hour_gw
FROM calendar AS c
JOIN demand_hourly AS d ON d.date = c.date
WHERE c.holiday_name IS NOT NULL
GROUP BY c.holiday_name
ORDER BY avg_demand_gw ASC;


-- ---------------------------------------------------------------------------
-- E. JOINs with weather + stations
-- ---------------------------------------------------------------------------

-- name: q10_station_records
-- question: Which of the 8 Kanto weather stations is the hottest and the coldest?
SELECT s.name_en, s.name_ja, s.prefecture,
       ROUND(AVG(w.temp_c), 2)                          AS avg_temp_c,
       MAX(w.temp_c)                                    AS max_temp_c,
       MIN(w.temp_c)                                    AS min_temp_c,
       SUM(CASE WHEN w.temp_c >= 35 THEN 1 ELSE 0 END)  AS hours_35c_plus,
       SUM(CASE WHEN w.temp_c < 0 THEN 1 ELSE 0 END)    AS hours_below_0c
FROM weather_hourly AS w
JOIN stations AS s ON s.station_id = w.station_id
GROUP BY s.station_id
ORDER BY max_temp_c DESC;

-- name: q11_demand_by_temperature_band
-- question: How does demand change with Tokyo's temperature? (CASE bands + JOIN + GROUP BY)
SELECT CASE
         WHEN w.temp_c < 5  THEN '1: below 5 °C'
         WHEN w.temp_c < 10 THEN '2: 5–10 °C'
         WHEN w.temp_c < 15 THEN '3: 10–15 °C'
         WHEN w.temp_c < 20 THEN '4: 15–20 °C'
         WHEN w.temp_c < 25 THEN '5: 20–25 °C'
         WHEN w.temp_c < 30 THEN '6: 25–30 °C'
         WHEN w.temp_c < 35 THEN '7: 30–35 °C'
         ELSE                    '8: 35 °C and above'
       END                         AS temp_band,
       COUNT(*)                    AS hours,
       ROUND(AVG(d.demand_gw), 2)  AS avg_demand_gw,
       MAX(d.demand_gw)            AS peak_demand_gw,
       MIN(d.demand_gw)            AS low_demand_gw
FROM demand_hourly AS d
JOIN weather_hourly AS w ON w.datetime = d.datetime
JOIN stations AS s ON s.station_id = w.station_id
WHERE s.name_en = 'Tokyo'
GROUP BY temp_band
ORDER BY temp_band;

-- name: q12_kanto_weighted_temp_on_peak_days
-- question: On the 5 highest-demand days, how hot was it across Kanto (population-weighted)?
WITH daily_peak AS (
    SELECT date, MAX(demand_gw) AS peak_gw
    FROM demand_hourly
    GROUP BY date
    ORDER BY peak_gw DESC
    LIMIT 5
)
SELECT p.date,
       c.weekday,
       p.peak_gw,
       ROUND(SUM(w.temp_c * s.prefecture_population_10k) / SUM(s.prefecture_population_10k), 1)
                                AS kanto_weighted_max_temp_c,
       MAX(w.temp_c)            AS hottest_station_temp_c
FROM daily_peak AS p
JOIN calendar AS c ON c.date = p.date
JOIN demand_hourly AS d ON d.date = p.date AND d.demand_gw = p.peak_gw   -- the peak hour itself
JOIN weather_hourly AS w ON w.datetime = d.datetime
JOIN stations AS s ON s.station_id = w.station_id
GROUP BY p.date
ORDER BY p.peak_gw DESC;


-- ---------------------------------------------------------------------------
-- F. Subqueries, CTEs and window functions
-- ---------------------------------------------------------------------------

-- name: q13_peak_day_each_year
-- question: What was the single highest-demand day in each year, and what kind of day was it?
WITH daily AS (
    SELECT d.date, c.year, c.weekday, c.holiday_name, MAX(d.demand_gw) AS peak_gw
    FROM demand_hourly AS d
    JOIN calendar AS c ON c.date = d.date
    GROUP BY d.date
),
ranked AS (
    SELECT *, ROW_NUMBER() OVER (PARTITION BY year ORDER BY peak_gw DESC) AS rn
    FROM daily
)
SELECT year, date, weekday, peak_gw
FROM ranked
WHERE rn = 1
ORDER BY year;

-- name: q14_days_above_55gw
-- question: How many days reached 55 GW or more each year, and how hot did Tokyo get on them?
SELECT c.year,
       COUNT(*)                         AS days_55gw_plus,
       ROUND(AVG(t.max_temp_c), 1)      AS avg_tokyo_max_temp_c
FROM (
    SELECT d.date, MAX(d.demand_gw) AS peak_gw, MAX(w.temp_c) AS max_temp_c
    FROM demand_hourly AS d
    JOIN weather_hourly AS w ON w.datetime = d.datetime AND w.station_id = 47662
    GROUP BY d.date
) AS t
JOIN calendar AS c ON c.date = t.date
WHERE t.peak_gw >= 55
GROUP BY c.year
ORDER BY c.year;

-- name: q15_forecast_accuracy_by_season
-- question: How accurate is TEPCO's demand forecast in each season?
SELECT c.season,
       COUNT(*)                                                    AS hours,
       ROUND(AVG(ABS(d.demand_gw - d.forecast_gw) / d.demand_gw) * 100, 2) AS mape_pct,
       ROUND(AVG(d.demand_gw - d.forecast_gw), 3)                  AS avg_bias_gw,
       ROUND(MAX(ABS(d.demand_gw - d.forecast_gw)), 2)             AS worst_miss_gw
FROM demand_hourly AS d
JOIN calendar AS c ON c.date = d.date
GROUP BY c.season
ORDER BY mape_pct DESC;

-- name: q16_solar_by_hour_spring
-- question: How much of the demand does solar cover at each daytime hour in spring?
SELECT d.hour,
       ROUND(AVG(d.demand_gw), 2)                          AS avg_demand_gw,
       ROUND(AVG(d.solar_gw), 2)                           AS avg_solar_gw,
       ROUND(AVG(d.demand_gw - d.solar_gw), 2)             AS avg_net_demand_gw,
       ROUND(SUM(d.solar_gw) / SUM(d.demand_gw) * 100, 1)  AS solar_share_pct
FROM demand_hourly AS d
JOIN calendar AS c ON c.date = d.date
WHERE c.season = 'Spring' AND d.hour BETWEEN 6 AND 18
GROUP BY d.hour
ORDER BY d.hour;
