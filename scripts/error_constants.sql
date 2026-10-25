-- Константы задания «Работа с ошибками».
-- На новой базе выполнить перед error_work.sql.
-- В текущей базе эти объекты уже созданы в pgAdmin: повторно не запускать.
BEGIN;

CREATE TABLE meteo_plpgsql.parameter_rules (
    code TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    min_value NUMERIC,
    max_value NUMERIC,
    decimal_places INTEGER NOT NULL,
    error_message TEXT NOT NULL,
    CHECK (decimal_places >= 0),
    CHECK (min_value IS NULL OR max_value IS NULL OR min_value <= max_value)
);

INSERT INTO meteo_plpgsql.parameter_rules
    (code, name, min_value, max_value, decimal_places, error_message)
VALUES
    ('height', 'Высота метеопоста', 0, 10000, 0,
     'Высота должна быть целым числом от 0 до 10000'),
    ('temperature', 'Температура', -58, 58, 1,
     'Температура должна быть от -58 до 58, не более одного знака после запятой'),
    ('pressure', 'Давление', 500, 900, 0,
     'Давление должно быть целым числом от 500 до 900'),
    ('wind_direction', 'Направление ветра', 0, 59, 0,
     'Направление ветра должно быть целым числом от 0 до 59'),
    ('wind_speed', 'Скорость ветра', 0, 15, 0,
     'Скорость ветра должна быть целым числом от 0 до 15'),
    ('distance', 'Дальность сноса', 0, 150, 0,
     'Дальность сноса должна быть целым числом от 0 до 150');

CREATE TABLE meteo_plpgsql.calculation_constants (
    code TEXT PRIMARY KEY,
    value NUMERIC NOT NULL,
    description TEXT NOT NULL
);

INSERT INTO meteo_plpgsql.calculation_constants (code, value, description)
VALUES
    ('reference_pressure', 750, 'Табличное давление, мм рт. ст.'),
    ('reference_temperature', 15.9, 'Табличная виртуальная температура, °C');

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
