BEGIN;
DO $ddl$
BEGIN
    CREATE TABLE meteo_plpgsql.interpolation_corrections (
        temperature NUMERIC(8,2) PRIMARY KEY,
        correction NUMERIC(8,2) NOT NULL
    );
    INSERT INTO meteo_plpgsql.interpolation_corrections VALUES
        (0,0.5), (5,0.5), (10,1), (20,1), (25,2), (30,3.5), (40,4.5);
    CREATE TYPE meteo_plpgsql.interpolation_points AS (
        x0 NUMERIC, y0 NUMERIC, x1 NUMERIC, y1 NUMERIC
    );
    EXECUTE $function$
    CREATE FUNCTION meteo_plpgsql.get_interpolation_points(p_temperature NUMERIC)
    RETURNS meteo_plpgsql.interpolation_points
    LANGUAGE plpgsql STABLE AS $body$
    DECLARE
        result meteo_plpgsql.interpolation_points;
    BEGIN
        IF p_temperature IS NULL THEN
            RAISE EXCEPTION 'Температура не должна быть NULL';
        END IF;
        IF p_temperature < 0 THEN
            RETURN ROW(p_temperature,0,p_temperature,0)::meteo_plpgsql.interpolation_points;
        ELSIF p_temperature > 40 THEN
            RETURN ROW(40,4.5,40,4.5)::meteo_plpgsql.interpolation_points;
        END IF;
        SELECT temperature, correction INTO result.x0, result.y0
        FROM meteo_plpgsql.interpolation_corrections
        WHERE temperature <= p_temperature ORDER BY temperature DESC LIMIT 1;
        SELECT temperature, correction INTO result.x1, result.y1
        FROM meteo_plpgsql.interpolation_corrections
        WHERE temperature >= p_temperature ORDER BY temperature LIMIT 1;
        IF result.x0 IS NULL OR result.x1 IS NULL THEN
            RAISE EXCEPTION 'В справочнике отсутствуют необходимые границы';
        END IF;
        RETURN result;
    END;
    $body$;
    $function$;
    EXECUTE $function$
    CREATE FUNCTION meteo_plpgsql.interpolate(p_x NUMERIC, p_points meteo_plpgsql.interpolation_points)
    RETURNS NUMERIC LANGUAGE plpgsql IMMUTABLE AS $body$
    BEGIN
        IF p_x IS NULL OR p_points.x0 IS NULL OR p_points.y0 IS NULL
            OR p_points.x1 IS NULL OR p_points.y1 IS NULL THEN
            RAISE EXCEPTION 'Аргументы интерполяции не должны быть NULL';
        END IF;
        IF p_points.x0 > p_points.x1 THEN
            RAISE EXCEPTION 'Нижняя граница больше верхней';
        END IF;
        IF p_points.x0 = p_points.x1 THEN
            IF p_points.y0 <> p_points.y1 THEN
                RAISE EXCEPTION 'Одна точка не может иметь две разные поправки';
            END IF;
            RETURN p_points.y0;
        END IF;
        IF p_x < p_points.x0 OR p_x > p_points.x1 THEN
            RAISE EXCEPTION 'Значение находится вне интервала интерполяции';
        END IF;
        RETURN p_points.y0 + (p_x-p_points.x0)*(p_points.y1-p_points.y0)
            /(p_points.x1-p_points.x0);
    END;
    $body$;
    $function$;
END;
$ddl$;
COMMIT;
SELECT (meteo_plpgsql.get_interpolation_points(26)).*;
