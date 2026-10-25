SELECT *
FROM meteo_plpgsql.interpolation_corrections
ORDER BY temperature;

SELECT
    temperature AS x0,
    correction AS y0,
    LEAD(temperature, 1, temperature)
        OVER (ORDER BY temperature) AS x1,
    LEAD(correction, 1, correction)
        OVER (ORDER BY temperature) AS y1
FROM meteo_plpgsql.interpolation_corrections
ORDER BY temperature;

WITH points AS (
    SELECT
        temperature AS x0,
        correction AS y0,
        LEAD(temperature, 1, temperature)
            OVER (ORDER BY temperature) AS x1,
        LEAD(correction, 1, correction)
            OVER (ORDER BY temperature) AS y1
    FROM meteo_plpgsql.interpolation_corrections
),
midpoints AS (
    SELECT
        *,
        (x0 + x1) / 2 AS x
    FROM points
)
SELECT
    ROW_NUMBER() OVER (ORDER BY x0) AS "№",
    x0, y0, x1, y1, ROUND(x, 2) AS x,
    ROUND(
        meteo_plpgsql.interpolate(
            x,
            ROW(x0, y0, x1, y1)::meteo_plpgsql.interpolation_points
        ),
        2
    ) AS y
FROM midpoints
ORDER BY x0;
