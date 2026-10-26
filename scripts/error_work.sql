-- Работа с ошибками. Выполнить после error_constants.sql.
-- Зависимости: plpgsql_setup.sql, interpolation_setup.sql, error_constants.sql.
-- Установка на схеме meteo_plpgsql после предыдущих заданий; CREATE TYPE выполняется один раз.
-- Отчёты и проверки ниже выполнять отдельно выделенным блоком.
-- Существующие измерения не изменяются.

BEGIN;
CREATE TYPE meteo_plpgsql.input_parameters AS (
    equipment_type_id INTEGER,
    height NUMERIC,
    temperature NUMERIC,
    pressure NUMERIC,
    wind_direction NUMERIC,
    wind_speed NUMERIC,
    distance NUMERIC
);

CREATE OR REPLACE FUNCTION meteo_plpgsql.check_parameters(p meteo_plpgsql.input_parameters)
RETURNS TEXT LANGUAGE plpgsql STABLE AS $$
DECLARE
    v_errors TEXT[] := '{}';
    rule meteo_plpgsql.parameter_rules;
BEGIN
    IF p.equipment_type_id IS NULL OR p.equipment_type_id NOT IN (1, 2) THEN
        v_errors := array_append(v_errors, 'Неверный тип оборудования');
    END IF;

    rule := meteo_plpgsql.get_rule('height');
    IF p.height IS NULL OR p.height < rule.min_value OR p.height > rule.max_value THEN
        v_errors := array_append(v_errors, rule.error_message);
    END IF;

    rule := meteo_plpgsql.get_rule('temperature');
    IF p.temperature IS NULL OR p.temperature < rule.min_value OR p.temperature > rule.max_value THEN
        v_errors := array_append(v_errors, rule.error_message);
    END IF;

    rule := meteo_plpgsql.get_rule('pressure');
    IF p.pressure IS NULL OR p.pressure < rule.min_value OR p.pressure > rule.max_value THEN
        v_errors := array_append(v_errors, rule.error_message);
    END IF;

    rule := meteo_plpgsql.get_rule('wind_direction');
    IF p.wind_direction IS NULL OR p.wind_direction < rule.min_value OR p.wind_direction > rule.max_value THEN
        v_errors := array_append(v_errors, rule.error_message);
    END IF;

    IF p.equipment_type_id = 1 THEN
        rule := meteo_plpgsql.get_rule('wind_speed');
        IF p.wind_speed IS NULL OR p.wind_speed < rule.min_value OR p.wind_speed > rule.max_value THEN
            v_errors := array_append(v_errors, rule.error_message);
        END IF;
    END IF;

    IF p.equipment_type_id = 2 THEN
        rule := meteo_plpgsql.get_rule('distance');
        IF p.distance IS NULL OR p.distance < rule.min_value OR p.distance > rule.max_value THEN
            v_errors := array_append(v_errors, rule.error_message);
        END IF;
    END IF;

    RETURN array_to_string(v_errors, '; ');
END;
$$;
COMMIT;

-- Список параметров с ошибками: одна строка на пачку.
-- В текущем справочнике нет давления и направления: отсутствие даёт ошибки.
-- MAX допустим для проверенных данных без повторов типа внутри пачки.
CREATE OR REPLACE VIEW meteo_plpgsql.checked_batches AS
WITH batch_values AS (
    SELECT b.id AS batch_id, b.user_id, b.equipment_type_id,
        MAX(CASE WHEN p.parameter_type_id = 1 THEN p.value END) AS height,
        MAX(CASE WHEN p.parameter_type_id = 2 THEN p.value END) AS temperature,
        NULL::NUMERIC AS pressure,
        NULL::NUMERIC AS wind_direction,
        MAX(CASE WHEN p.parameter_type_id = 3 THEN p.value END) AS wind_speed,
        MAX(CASE WHEN p.parameter_type_id = 4 THEN p.value END) AS distance
    FROM meteo_plpgsql.batches b
    LEFT JOIN meteo_plpgsql.parameters p ON p.batch_id = b.id
    GROUP BY b.id, b.user_id, b.equipment_type_id
)
SELECT v.*, meteo_plpgsql.check_parameters(
    ROW(equipment_type_id,height,temperature,pressure,wind_direction,wind_speed,distance)
        ::meteo_plpgsql.input_parameters
) AS errors FROM batch_values v;

-- 2. Список параметров с ошибками.
SELECT c.batch_id AS "№", eq.name AS "Тип оборудования",
    c.height AS "Высота метеопоста", c.temperature AS "Температура",
    c.pressure AS "Давление", c.wind_direction AS "Направление ветра",
    c.wind_speed AS "Скорость ветра", c.distance AS "Дальность сноса пуль",
    c.errors <> '' AS "Флаг: Есть ошибка", c.errors AS "Описание ошибки"
FROM meteo_plpgsql.checked_batches c
LEFT JOIN meteo_plpgsql.equipment_types eq ON eq.id = c.equipment_type_id
ORDER BY c.batch_id;

-- 3. Лучший стрелок. Сотрудники без пачек не участвуют в рейтинге.
WITH totals AS (
    SELECT u.id, u.full_name, COUNT(c.batch_id) AS batches,
        COALESCE(SUM(cardinality(string_to_array(c.errors, '; '))), 0) AS errors
    FROM meteo_plpgsql.users u
    LEFT JOIN meteo_plpgsql.checked_batches c ON c.user_id = u.id
    GROUP BY u.id, u.full_name
)
SELECT CASE WHEN batches > 0 THEN
        DENSE_RANK() OVER (ORDER BY (batches = 0), errors)
    END AS "Место",
    full_name AS "Сотрудник", batches AS "Количество пачек",
    errors AS "Количество ошибок"
FROM totals
ORDER BY (batches = 0), errors, id;

-- Заголовок. Использует существующую interpolation_corrections из
-- interpolation_setup.sql: (20,1), тогда как TechnicalTask.md содержит (20,1.5).
-- Скриншот задания «Работа с ошибками» таблицы поправок не содержит.
-- Проверка входной высоты: диапазон 0..10000 (принято пользователем).
-- Формат ВВВВ поддерживает 0..9999; 10000 отклоняется без обрезания цифр.
-- Отрицательная температура: правило |отклонение|+50 перенесено из алгоритма
-- табличной части бюллетеня; применение к заголовку требует подтверждения.
CREATE OR REPLACE FUNCTION meteo_plpgsql.make_meteo_header(
    p meteo_plpgsql.input_parameters,
    p_time TIMESTAMP DEFAULT timezone('Asia/Irkutsk', CURRENT_TIMESTAMP)
)
RETURNS TEXT LANGUAGE plpgsql STABLE AS $$
DECLARE
    errors TEXT;
    correction NUMERIC;
    pressure_delta INTEGER;
    temperature_delta INTEGER;
    temperature_code INTEGER;
    time_group TEXT;
    height_group TEXT;
    pressure_group TEXT;
BEGIN
    errors := meteo_plpgsql.check_parameters(p);
    IF errors <> '' THEN
        RAISE EXCEPTION 'Ошибки параметров: %', errors;
    END IF;
    IF p_time IS NULL THEN
        RAISE EXCEPTION 'Не указано время измерения';
    END IF;
    IF p.height <> trunc(p.height) OR p.height < 0 OR p.height > 9999 THEN
        RAISE EXCEPTION 'Для высоты % не определено кодирование в ВВВВ', p.height;
    END IF;
    correction := meteo_plpgsql.interpolate(
        p.temperature, meteo_plpgsql.get_interpolation_points(p.temperature));
    pressure_delta := (p.pressure
        - meteo_plpgsql.get_constant('reference_pressure'))::INTEGER;
    temperature_delta := round(p.temperature + correction
        - meteo_plpgsql.get_constant('reference_temperature'))::INTEGER;
    temperature_code := CASE WHEN temperature_delta < 0
        THEN abs(temperature_delta) + meteo_plpgsql.get_constant('negative_temperature_offset')::INTEGER
        ELSE temperature_delta END;
    IF temperature_code > 99 THEN
        RAISE EXCEPTION 'Отклонение температуры % не помещается в ТТ', temperature_delta;
    END IF;
    time_group := to_char(p_time, 'DDHH24')
        || floor(EXTRACT(MINUTE FROM p_time) / 10)::INTEGER::TEXT;
    height_group := lpad(p.height::INTEGER::TEXT, 4, '0');
    pressure_group := lpad((CASE WHEN pressure_delta < 0
        THEN meteo_plpgsql.get_constant('negative_pressure_offset')::INTEGER + abs(pressure_delta)
        ELSE pressure_delta END)::TEXT, 3, '0');
    RETURN time_group || ' ' || height_group || ' '
        || pressure_group || lpad(temperature_code::TEXT, 2, '0');
END;
$$;

-- Проверки: каждая строка должна вернуть true.
WITH examples AS (
    SELECT * FROM (VALUES
        (ROW(1,100,23,750,15,6,NULL)::meteo_plpgsql.input_parameters, FALSE),
        (ROW(2,0,-58,500,0,NULL,150)::meteo_plpgsql.input_parameters, FALSE),
        (ROW(1,10000,58,900,59,15,NULL)::meteo_plpgsql.input_parameters, FALSE),
        (ROW(1,-1,23,750,15,6,NULL)::meteo_plpgsql.input_parameters, TRUE),
        (ROW(1,100,NULL,750,15,6,NULL)::meteo_plpgsql.input_parameters, TRUE),
        (ROW(1,100,59,750,15,6,NULL)::meteo_plpgsql.input_parameters, TRUE),
        (ROW(2,100,23,750,15,NULL,151)::meteo_plpgsql.input_parameters, TRUE)
    ) AS v(parameters, expected_error)
)
SELECT (meteo_plpgsql.check_parameters(parameters) <> '') = expected_error
    AS "Проверка пройдена" FROM examples;

WITH examples AS (
    SELECT * FROM (VALUES
        (765::NUMERIC, TIMESTAMP '2026-10-25 09:30:00', '25093 0100 01511'),
        (743::NUMERIC, TIMESTAMP '2026-10-25 09:59:00', '25095 0100 50711'),
        (750::NUMERIC, TIMESTAMP '2026-10-25 00:00:00', '25000 0100 00011')
    ) AS v(pressure, measured_at, expected)
)
SELECT meteo_plpgsql.make_meteo_header(
    ROW(1,100,25,pressure,15,6,NULL)::meteo_plpgsql.input_parameters,
    measured_at) = expected AS "Проверка пройдена"
FROM examples;
