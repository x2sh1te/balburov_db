-- Константы задания «Работа с ошибками».
-- На новой базе выполнить перед error_work.sql.
-- Упрощённая версия для новой установки; поверх текущей базы не выполнять.
BEGIN;

CREATE TABLE meteo_plpgsql.parameter_rules (
    code TEXT PRIMARY KEY,
    min_value NUMERIC NOT NULL,
    max_value NUMERIC NOT NULL,
    error_message TEXT NOT NULL
);

INSERT INTO meteo_plpgsql.parameter_rules
    (code, min_value, max_value, error_message)
VALUES
    ('height', 0, 10000, 'Неверная высота метеопоста'),
    ('temperature', -58, 58, 'Температура вне диапазона'),
    ('pressure', 500, 900, 'Давление вне диапазона'),
    ('wind_direction', 0, 59, 'Направление ветра вне диапазона'),
    ('wind_speed', 0, 15, 'Скорость ветра вне диапазона'),
    ('distance', 0, 150, 'Дальность сноса вне диапазона');

-- Описания ошибок для существующих типов параметров нашей схемы.
ALTER TABLE meteo_plpgsql.parameter_types
ADD COLUMN IF NOT EXISTS error_desc TEXT;

UPDATE meteo_plpgsql.parameter_types pt
SET error_desc = r.error_message
FROM meteo_plpgsql.parameter_rules r
WHERE r.code = CASE pt.id
    WHEN 1 THEN 'height'
    WHEN 2 THEN 'temperature'
    WHEN 3 THEN 'wind_speed'
    WHEN 4 THEN 'distance'
END;

CREATE OR REPLACE FUNCTION meteo_plpgsql.get_rule(p_code TEXT)
RETURNS meteo_plpgsql.parameter_rules
LANGUAGE plpgsql
AS $$
DECLARE
    rule meteo_plpgsql.parameter_rules;
BEGIN
    SELECT *
    INTO STRICT rule
    FROM meteo_plpgsql.parameter_rules
    WHERE code = p_code;

    RETURN rule;
END;
$$;

CREATE TABLE meteo_plpgsql.calculation_constants (
    code TEXT PRIMARY KEY,
    value NUMERIC NOT NULL,
    description TEXT NOT NULL
);

INSERT INTO meteo_plpgsql.calculation_constants (code, value, description)
VALUES
    ('reference_pressure', 750, 'Табличное давление, мм рт. ст.'),
    ('reference_temperature', 15.9, 'Табличная виртуальная температура, °C'),
    ('negative_pressure_offset', 500, 'Смещение кода отрицательного давления'),
    ('negative_temperature_offset', 50, 'Смещение кода отрицательной температуры');

CREATE FUNCTION meteo_plpgsql.get_constant(p_code TEXT)
RETURNS NUMERIC LANGUAGE plpgsql STABLE AS $$
DECLARE
    result NUMERIC;
BEGIN
    SELECT value INTO result
    FROM meteo_plpgsql.calculation_constants
    WHERE code = p_code;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Константа "%" не найдена', p_code;
    END IF;
    RETURN result;
END;
$$;
COMMIT;

SELECT * FROM meteo_plpgsql.parameter_rules ORDER BY code;
SELECT meteo_plpgsql.get_constant('reference_pressure') AS "Табличное давление",
       meteo_plpgsql.get_constant('reference_temperature') AS "Табличная температура";
