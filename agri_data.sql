select * from dist_agri
--1. Year-wise Trend of Rice Production Across States (Top 3 States)

SELECT year, state, total_rice_production
FROM (
    SELECT 
        year,
        state,
        SUM(rice_production) AS total_rice_production,
        RANK() OVER (PARTITION BY year ORDER BY SUM(rice_production) DESC) AS rank
    FROM dist_agri
    GROUP BY year, state
) ranked_data
WHERE rank <= 3
ORDER BY year, rank;

-- Top 5 Districts by Wheat Yield Increase Over the Last 5 Years
WITH wheat_change AS (
    SELECT district, year, wheat_yield,
           wheat_yield - LAG(wheat_yield, 5) OVER (PARTITION BY district ORDER BY year) AS yield_increase
    FROM dist_agri
)
SELECT district, MAX(yield_increase) AS max_increase
FROM wheat_change
WHERE yield_increase IS NOT NULL
GROUP BY district
ORDER BY max_increase DESC
LIMIT 5;

--3. States with Highest Growth in Oilseed Production (5-Year Growth Rate)

WITH oilseed_growth AS (
    SELECT state,
           FIRST_VALUE(oilseeds_production) OVER w AS prod_start,
           LAST_VALUE(oilseeds_production) OVER w AS prod_end
    FROM dist_agri
    WHERE year BETWEEN 2016 AND 2021
    WINDOW w AS (PARTITION BY state ORDER BY year
                 ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING)
)
SELECT DISTINCT state,
       ((prod_end - prod_start) / NULLIF(prod_start, 0)) * 100 AS growth_rate
FROM oilseed_growth
ORDER BY growth_rate DESC
LIMIT 5;

--4. District-wise Correlation Between Area and Production for Rice, Wheat, and Maize

SELECT district,
       CORR(rice_area, rice_production) AS rice_corr,
       CORR(wheat_area, wheat_production) AS wheat_corr,
       CORR(maize_area, maize_production) AS maize_corr
FROM dist_agri
GROUP BY district;

--5.Yearly Production Growth of Cotton in Top 5 Cotton Producing States
WITH top_states AS (
    SELECT state, SUM(cotton_production) AS total_production
    FROM dist_agri
    GROUP BY state
    ORDER BY total_production DESC
    LIMIT 5
)
SELECT c.year, c.state, SUM(c.cotton_production) AS yearly_production
FROM dist_agri c
JOIN top_states ts ON c.state = ts.state
GROUP BY c.year, c.state
ORDER BY c.year, yearly_production DESC;

--6. Districts with the Highest Groundnut Production in 2020

SELECT district, state, groundnut_production
FROM dist_agri
WHERE year = 2000
  AND groundnut_production IS NOT NULL
ORDER BY groundnut_production DESC
LIMIT 5;


--Annual Average Maize Yield Across All States
SELECT year, state, AVG(maize_yield) AS avg_maize_yield
FROM dist_agri
GROUP BY year, state
ORDER BY year, avg_maize_yield DESC;

--8. Total Area Cultivated for Oilseeds in Each State
SELECT state, SUM(oilseeds_area) AS total_oilseeds_area
FROM dist_agri
GROUP BY state
ORDER BY total_oilseeds_area DESC;

--9. Districts with the Highest Rice Yield
SELECT district, state, MAX(rice_yield) AS max_rice_yield
FROM dist_agri
GROUP BY district, state
ORDER BY max_rice_yield DESC
LIMIT 5;

--10. Compare Production of Wheat and Rice for Top 5 States Over 10 Years
WITH top_states AS (
    SELECT state, SUM(rice_production + wheat_production) AS total
    FROM dist_agri
    WHERE year BETWEEN 2011 AND 2020
    GROUP BY state
    ORDER BY total DESC
    LIMIT 5
)
SELECT year, state, SUM(rice_production) AS rice, SUM(wheat_production) AS wheat
FROM dist_agri
WHERE year BETWEEN 2011 AND 2020 AND state IN (SELECT state FROM top_states)
GROUP BY year, state
ORDER BY year, state;

--6
SELECT district, state, groundnut_production
FROM dist_agri
WHERE year = 2000
  AND groundnut_production IS NOT NULL
ORDER BY groundnut_production DESC
LIMIT 5;
--2. Top 5 Districts by Wheat Yield Increase Over the Last 5 Years
WITH years AS (
    SELECT
        MIN(year) AS min_year,
        MAX(year) AS max_year
    FROM dist_agri
),
wheat_by_district AS (
    SELECT
        d.district,
        d.state,
        d.year,
        AVG(d.wheat_yield) AS avg_wheat_yield
    FROM dist_agri d
    GROUP BY d.district, d.state, d.year
),
base AS (
    SELECT
        w.district,
        w.state,
        CASE
            WHEN w.year = (SELECT min_year FROM years) THEN 'start'
            WHEN w.year = (SELECT max_year FROM years) THEN 'end'
        END AS period,
        w.avg_wheat_yield
    FROM wheat_by_district w
    JOIN years y
      ON w.year IN (y.min_year, y.max_year)
),
pivoted AS (
    SELECT
        district,
        state,
        MAX(CASE WHEN period = 'start' THEN avg_wheat_yield END) AS start_yield,
        MAX(CASE WHEN period = 'end'   THEN avg_wheat_yield END) AS end_yield
    FROM base
    GROUP BY district, state
)
SELECT
    district,
    state,
    start_yield,
    end_yield,
    (end_yield - start_yield) AS yield_increase
FROM pivoted
WHERE start_yield IS NOT NULL
  AND end_yield IS NOT NULL
ORDER BY yield_increase DESC
LIMIT 5;

--3
WITH years AS (
    SELECT
        MIN(year) AS min_year,
        MAX(year) AS max_year
    FROM dist_agri
),
state_year_oilseed AS (
    SELECT
        year,
        state,
        SUM(
            COALESCE(groundnut_production, 0) +
       
            COALESCE(sesamum_production, 0) +
            COALESCE(sunflower_production, 0) +
            COALESCE(safflower_production, 0) +
            
            COALESCE(linseed_production, 0)
        ) AS total_oilseed_prod
    FROM dist_agri
    GROUP BY year, state
),
base AS (
    SELECT
        s.state,
        CASE
            WHEN s.year = (SELECT min_year FROM years) THEN 'start'
            WHEN s.year = (SELECT max_year FROM years) THEN 'end'
        END AS period,
        s.total_oilseed_prod
    FROM state_year_oilseed s
    JOIN years y
      ON s.year IN (y.min_year, y.max_year)
),
pivoted AS (
    SELECT
        state,
        MAX(CASE WHEN period = 'start' THEN total_oilseed_prod END) AS start_prod,
        MAX(CASE WHEN period = 'end'   THEN total_oilseed_prod END) AS end_prod
    FROM base
    GROUP BY state
)
SELECT
    state,
    start_prod,
    end_prod,
    CASE
        WHEN start_prod > 0
        THEN ((end_prod - start_prod) / start_prod::numeric) * 100
        ELSE NULL
    END AS growth_rate_pct
FROM pivoted
WHERE start_prod IS NOT NULL
  AND end_prod IS NOT NULL
ORDER BY growth_rate_pct DESC
LIMIT 10;
