-- NYPD Arrest Data (Year to Date): starter SQL for SQLite
-- Table name assumed: arrests (import the CSV with DB Browser for SQLite, "File > Import > Table from CSV")
-- Tip: import every column as TEXT first, then CAST where needed. Column names match the API field names.
-- Review each query and run it yourself before using any result in your write-up.
 
------------------------------------------------------------
-- 0. FIRST LOOK: sanity checks (do these before anything else)
------------------------------------------------------------
SELECT COUNT(*) AS total_rows FROM arrests;
 
-- Dates in this file are MM/DD/YYYY. Every query below converts them to YYYY-MM-DD
-- on the fly with substr(), so SQLite's date functions (strftime) work correctly.
SELECT arrest_date FROM arrests LIMIT 5;
 
SELECT MIN((substr(arrest_date, 7, 4) || '-' || substr(arrest_date, 1, 2) || '-' || substr(arrest_date, 4, 2))) AS first_date,
       MAX((substr(arrest_date, 7, 4) || '-' || substr(arrest_date, 1, 2) || '-' || substr(arrest_date, 4, 2))) AS last_date
FROM arrests;

-- What values exist in the coded columns?
SELECT DISTINCT law_cat_cd FROM arrests;
SELECT DISTINCT arrest_boro FROM arrests;
SELECT DISTINCT jurisdiction_code FROM arrests ORDER BY 1;
 
-- Duplicate check: arrest_key should be unique.
SELECT COUNT(*) AS rows_total, COUNT(DISTINCT arrest_key) AS unique_keys FROM arrests;

------------------------------------------------------------
-- 1. Arrests by month
------------------------------------------------------------
SELECT strftime('%Y-%m', (substr(arrest_date, 7, 4) || '-' || substr(arrest_date, 1, 2) || '-' || substr(arrest_date, 4, 2))) AS month,
       COUNT(*) AS arrests
FROM arrests
GROUP BY month
ORDER BY month;
 
-- Note: the latest month may be partial. Say so in your write-up.
 
------------------------------------------------------------
-- 2. Arrests by day of week
------------------------------------------------------------
SELECT CASE strftime('%w', (substr(arrest_date, 7, 4) || '-' || substr(arrest_date, 1, 2) || '-' || substr(arrest_date, 4, 2)))
         WHEN '0' THEN '7-Sun' WHEN '1' THEN '1-Mon' WHEN '2' THEN '2-Tue'
         WHEN '3' THEN '3-Wed' WHEN '4' THEN '4-Thu' WHEN '5' THEN '5-Fri'
         WHEN '6' THEN '6-Sat' END AS day_of_week,
       COUNT(*) AS arrests
FROM arrests
GROUP BY day_of_week
ORDER BY day_of_week;
 
------------------------------------------------------------
-- 3. Arrests by borough
------------------------------------------------------------
SELECT CASE arrest_boro
         WHEN 'B' THEN 'Bronx' WHEN 'K' THEN 'Brooklyn' WHEN 'M' THEN 'Manhattan'
         WHEN 'Q' THEN 'Queens' WHEN 'S' THEN 'Staten Island' ELSE 'Other/Unknown' END AS borough,
       COUNT(*) AS arrests,
       ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM arrests), 1) AS pct_of_total
FROM arrests
GROUP BY borough
ORDER BY arrests DESC;
 
-- These are raw counts, not rates. Boroughs differ in population, so don't call one "more dangerous".

------------------------------------------------------------
-- 4. Top 10 precincts by arrest count
------------------------------------------------------------
SELECT arrest_precinct, COUNT(*) AS arrests
FROM arrests
GROUP BY arrest_precinct
ORDER BY arrests DESC
LIMIT 10;
 
------------------------------------------------------------
-- 5. Felony / misdemeanor / violation mix by borough
------------------------------------------------------------
SELECT arrest_boro,
       law_cat_cd,
       COUNT(*) AS arrests,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY arrest_boro), 1) AS pct_within_borough
FROM arrests
GROUP BY arrest_boro, law_cat_cd
ORDER BY arrest_boro, arrests DESC;
 
------------------------------------------------------------
-- 6. Top 10 offense categories overall
------------------------------------------------------------
SELECT ofns_desc, COUNT(*) AS arrests
FROM arrests
GROUP BY ofns_desc
ORDER BY arrests DESC
LIMIT 10;
 
 
------------------------------------------------------------
-- 7. Top 3 offense categories within each borough (window function)
-- Needs SQLite 3.25 or newer.
------------------------------------------------------------
WITH ranked AS (
  SELECT arrest_boro,
         ofns_desc,
         COUNT(*) AS arrests,
         ROW_NUMBER() OVER (PARTITION BY arrest_boro ORDER BY COUNT(*) DESC) AS rnk
  FROM arrests
  GROUP BY arrest_boro, ofns_desc
)
SELECT arrest_boro, rnk, ofns_desc, arrests
FROM ranked
WHERE rnk <= 3
ORDER BY arrest_boro, rnk;
 
------------------------------------------------------------
-- 8. Jurisdiction split: Patrol (0), Transit (1), Housing (2), other (3+)
------------------------------------------------------------
SELECT CASE CAST(jurisdiction_code AS INTEGER)
         WHEN 0 THEN 'Patrol'
         WHEN 1 THEN 'Transit'
         WHEN 2 THEN 'Housing'
         ELSE 'Non-NYPD / other' END AS jurisdiction,
       COUNT(*) AS arrests,
       ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM arrests), 1) AS pct_of_total
FROM arrests
GROUP BY jurisdiction
ORDER BY arrests DESC;
 
------------------------------------------------------------
-- 9. DATA QUALITY: document what you found and how you handled it
------------------------------------------------------------
-- Blank, null, or placeholder values in key fields.
SELECT
  SUM(CASE WHEN ofns_desc IS NULL OR TRIM(ofns_desc) = '' OR ofns_desc = '(null)' THEN 1 ELSE 0 END) AS missing_ofns_desc,
  SUM(CASE WHEN law_code  IS NULL OR TRIM(law_code)  = '' OR law_code  = '(null)' THEN 1 ELSE 0 END) AS missing_law_code,
  SUM(CASE WHEN law_cat_cd IS NULL OR TRIM(law_cat_cd) = '' OR law_cat_cd = '(null)' THEN 1 ELSE 0 END) AS missing_law_cat_cd,
  SUM(CASE WHEN latitude IS NULL OR TRIM(latitude) = '' THEN 1 ELSE 0 END) AS missing_latitude,
  COUNT(*) AS total_rows
FROM arrests;
 
-- Arrests with placeholder law codes (footnote 8 explains LOC00000UM-type codes).
SELECT COUNT(*) AS placeholder_law_codes
FROM arrests
WHERE law_code LIKE 'LOC0000%';
 
-- Unrecognized values in the borough field.
SELECT arrest_boro, COUNT(*) AS rows_
FROM arrests
WHERE arrest_boro NOT IN ('B','K','M','Q','S') OR arrest_boro IS NULL
GROUP BY arrest_boro;
 
-- Not used in these queries on purpose: AGE_GROUP / PERP_SEX / PERP_RACE.
-- Arrest counts by demographic group without population data can't support conclusions.
-- If you include them, keep it descriptive and add that caveat in the README.
 