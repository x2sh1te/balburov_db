-- Задание «Работа с ошибками»: код, выполненный пользователем в pgAdmin.
-- Зависимости: plpgsql_setup.sql, interpolation_setup.sql, error_constants.sql.
-- Объекты уже существуют в текущей базе. Блоки CREATE повторно не выполнять.
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

CREATE FUNCTION meteo_plpgsql.check_parameters(p meteo_plpgsql.input_parameters)
RETURNS TEXT LANGUAGE plpgsql STABLE AS $$
DECLARE
    item RECORD;
    errors TEXT[] := ARRAY[]::TEXT[];
BEGIN
    IF p.equipment_type_id IS NULL THEN
        errors := array_append(errors, 'Не указан тип оборудования');
    ELSIF p.equipment_type_id NOT IN (1, 2) THEN
        errors := array_append(errors, 'Неизвестный тип оборудования');
    END IF;
    FOR item IN
        WITH input_values AS (
            SELECT * FROM (VALUES
                (1, 'height', p.height),
                (2, 'temperature', p.temperature),
                (3, 'pressure', p.pressure),
                (4, 'wind_direction', p.wind_direction),
                (5, 'wind_speed', p.wind_speed),
                (6, 'distance', p.distance)
            ) AS v(sort_order, code, value)
        )
        SELECT v.value, r.*
        FROM input_values v
        JOIN meteo_plpgsql.parameter_rules r ON r.code = v.code
        WHERE v.code NOT IN ('wind_speed', 'distance')
           OR (v.code = 'wind_speed' AND p.equipment_type_id = 1)
           OR (v.code = 'distance' AND p.equipment_type_id = 2)
        ORDER BY v.sort_order
    LOOP
        IF item.value IS NULL THEN
            errors := array_append(errors, item.name || ': значение не указано');
        ELSIF item.value::TEXT IN ('NaN', 'Infinity', '-Infinity')
           OR item.value < item.min_value
           OR item.value > item.max_value
           OR item.value <> round(item.value, item.decimal_places)
        THEN
            errors := array_append(errors, item.error_message);
        END IF;
    END LOOP;
    RETURN array_to_string(errors, '; ');
END;
$$;
COMMIT;

-- Проверка функции: три примера.
WITH examples AS (
    SELECT * FROM (VALUES
        ('Верные данные', ROW(1,100,23,750,15,6,NULL)::meteo_plpgsql.input_parameters),
        ('Ошибка температуры', ROW(1,100,59,750,15,6,NULL)::meteo_plpgsql.input_parameters),
        ('Ошибка дальности', ROW(2,100,23,750,15,NULL,151)::meteo_plpgsql.input_parameters)
    ) AS v(example, parameters)
), checked AS (
    SELECT example, meteo_plpgsql.check_parameters(parameters) AS errors FROM examples
)
SELECT example AS "Пример", errors <> '' AS "Флаг: Есть ошибка",
       errors AS "Описание ошибки" FROM checked;

-- Список параметров с ошибками: одна строка на пачку.
-- В текущем справочнике нет давления и направления: отсутствие даёт ошибки.
-- MAX допустим для проверенных данных без повторов типа внутри пачки.
WITH batch_values AS (
    SELECT b.id AS batch_id, b.equipment_type_id,
        MAX(CASE WHEN p.parameter_type_id = 1 THEN p.value END) AS height,
        MAX(CASE WHEN p.parameter_type_id = 2 THEN p.value END) AS temperature,
        NULL::NUMERIC AS pressure,
        NULL::NUMERIC AS wind_direction,
        MAX(CASE WHEN p.parameter_type_id = 3 THEN p.value END) AS wind_speed,
        MAX(CASE WHEN p.parameter_type_id = 4 THEN p.value END) AS distance
    FROM meteo_plpgsql.batches b
    LEFT JOIN meteo_plpgsql.parameters p ON p.batch_id = b.id
    GROUP BY b.id, b.equipment_type_id
), checked AS (
    SELECT v.*, meteo_plpgsql.check_parameters(
        ROW(equipment_type_id,height,temperature,pressure,wind_direction,wind_speed,distance)
            ::meteo_plpgsql.input_parameters
    ) AS errors FROM batch_values v
)
SELECT c.batch_id AS "№", eq.name AS "Тип оборудования",
    c.height AS "Высота метеопоста", c.temperature AS "Температура",
    c.pressure AS "Давление", c.wind_direction AS "Направление ветра",
    c.wind_speed AS "Скорость ветра", c.distance AS "Дальность сноса",
    c.errors <> '' AS "Флаг: Есть ошибка", c.errors AS "Описание ошибки"
FROM checked c
LEFT JOIN meteo_plpgsql.equipment_types eq ON eq.id = c.equipment_type_id
ORDER BY c.batch_id;

-- Лучший стрелок: число ошибок, а не только число ошибочных пачек.
-- Формат описаний check_parameters использует разделитель '; '.
WITH batch_values AS (
    SELECT b.id AS batch_id, b.user_id, b.equipment_type_id,
        MAX(CASE WHEN p.parameter_type_id = 1 THEN p.value END) AS height,
        MAX(CASE WHEN p.parameter_type_id = 2 THEN p.value END) AS temperature,
        MAX(CASE WHEN p.parameter_type_id = 3 THEN p.value END) AS wind_speed,
        MAX(CASE WHEN p.parameter_type_id = 4 THEN p.value END) AS distance
    FROM meteo_plpgsql.batches b
    LEFT JOIN meteo_plpgsql.parameters p ON p.batch_id = b.id
    GROUP BY b.id, b.user_id, b.equipment_type_id
), checked AS (
    SELECT batch_id, user_id, meteo_plpgsql.check_parameters(
        ROW(equipment_type_id,height,temperature,NULL::NUMERIC,NULL::NUMERIC,wind_speed,distance)
            ::meteo_plpgsql.input_parameters
    ) AS errors FROM batch_values
), error_counts AS (
    SELECT batch_id, user_id,
        cardinality(string_to_array(errors, '; ')) AS error_count FROM checked
), user_totals AS (
    SELECT u.id, u.full_name, COUNT(e.batch_id) AS batch_count,
        COUNT(CASE WHEN e.error_count > 0 THEN 1 END) AS bad_batch_count,
        COALESCE(SUM(e.error_count), 0) AS error_count
    FROM meteo_plpgsql.users u
    LEFT JOIN error_counts e ON e.user_id = u.id
    GROUP BY u.id, u.full_name
), ranked AS (
    SELECT *, DENSE_RANK() OVER (ORDER BY error_count) AS place
    FROM user_totals WHERE batch_count > 0
)
SELECT r.place AS "Место", u.id AS "Код сотрудника", u.full_name AS "Сотрудник",
    u.batch_count AS "Всего пачек", u.bad_batch_count AS "Пачек с ошибками",
    u.error_count AS "Количество ошибок"
FROM user_totals u LEFT JOIN ranked r ON r.id = u.id
ORDER BY r.place NULLS LAST, u.id;

-- Заголовок. Использует существующую interpolation_corrections из
-- interpolation_setup.sql: (20,1), тогда как TechnicalTask.md содержит (20,1.5).
-- Скриншот задания «Работа с ошибками» таблицы поправок не содержит.
-- Проверка входной высоты: 0..10000, целое число (принято пользователем).
-- Формат ВВВВ поддерживает 0..9999; 10000 отклоняется без обрезания цифр.
-- Отрицательная температура: правило |отклонение|+50 перенесено из алгоритма
-- табличной части бюллетеня; применение к заголовку требует подтверждения.
CREATE FUNCTION meteo_plpgsql.make_meteo_header(
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
    IF p.height < 0 OR p.height > 9999 THEN
        RAISE EXCEPTION 'Для высоты % не определено кодирование в ВВВВ', p.height;
    END IF;
    correction := meteo_plpgsql.interpolate(
        p.temperature, meteo_plpgsql.get_interpolation_points(p.temperature));
    pressure_delta := (p.pressure
        - meteo_plpgsql.get_constant('reference_pressure'))::INTEGER;
    temperature_delta := round(p.temperature + correction
        - meteo_plpgsql.get_constant('reference_temperature'))::INTEGER;
    temperature_code := CASE WHEN temperature_delta < 0
        THEN abs(temperature_delta) + 50 ELSE temperature_delta END;
    IF temperature_code > 99 THEN
        RAISE EXCEPTION 'Отклонение температуры % не помещается в ТТ', temperature_delta;
    END IF;
    time_group := to_char(p_time, 'DDHH24')
        || floor(EXTRACT(MINUTE FROM p_time) / 10)::INTEGER::TEXT;
    height_group := lpad(p.height::INTEGER::TEXT, 4, '0');
    pressure_group := lpad((CASE WHEN pressure_delta < 0
        THEN 500 + abs(pressure_delta) ELSE pressure_delta END)::TEXT, 3, '0');
    RETURN time_group || ' ' || height_group || ' '
        || pressure_group || lpad(temperature_code::TEXT, 2, '0');
END;
$$;

-- Пример заголовка: 25093 0100 01511.
SELECT meteo_plpgsql.make_meteo_header(
    ROW(1,100,25,765,15,6,NULL)::meteo_plpgsql.input_parameters,
    TIMESTAMP '2026-10-25 09:30:00') AS "Заголовок";

-- Два подтверждённых примера кодирования давления: оба true.
WITH examples AS (
    SELECT * FROM (VALUES
        (765::NUMERIC, '25093 0100 01511'),
        (743::NUMERIC, '25093 0100 50711')
    ) AS v(pressure, expected)
), results AS (
    SELECT expected, meteo_plpgsql.make_meteo_header(
        ROW(1,100,25,pressure,15,6,NULL)::meteo_plpgsql.input_parameters,
        TIMESTAMP '2026-10-25 09:30:00') AS actual FROM examples
)
SELECT expected AS "Ожидается", actual AS "Получено",
       actual = expected AS "Проверка пройдена" FROM results;

-- Повторы: на проверенных данных результат пустой.
SELECT batch_id AS "Пачка", parameter_type_id AS "Код параметра",
       COUNT(*) AS "Количество"
FROM meteo_plpgsql.parameters
GROUP BY batch_id, parameter_type_id HAVING COUNT(*) > 1
ORDER BY batch_id, parameter_type_id;

-- Границы и ошибки: восемь true в последнем столбце.
WITH examples AS (
    SELECT * FROM (VALUES
        ('Нижние границы', ROW(1,0,-58,500,0,0,NULL)::meteo_plpgsql.input_parameters, FALSE),
        ('Верхняя граница высоты', ROW(1,10000,23,750,15,6,NULL)::meteo_plpgsql.input_parameters, FALSE),
        ('Отрицательная высота', ROW(1,-1,23,750,15,6,NULL)::meteo_plpgsql.input_parameters, TRUE),
        ('Верхние границы', ROW(2,100,58,900,59,NULL,150)::meteo_plpgsql.input_parameters, FALSE),
        ('Нет температуры', ROW(1,100,NULL,750,15,6,NULL)::meteo_plpgsql.input_parameters, TRUE),
        ('Дробное давление', ROW(1,100,23,750.5,15,6,NULL)::meteo_plpgsql.input_parameters, TRUE),
        ('Лишняя точность температуры', ROW(1,100,23.45,750,15,6,NULL)::meteo_plpgsql.input_parameters, TRUE),
        ('Неизвестное оборудование', ROW(3,100,23,750,15,6,45)::meteo_plpgsql.input_parameters, TRUE)
    ) AS v(example, parameters, expected_error)
), checked AS (
    SELECT *, meteo_plpgsql.check_parameters(parameters) AS errors FROM examples
)
SELECT example AS "Пример", errors <> '' AS "Флаг: Есть ошибка",
       errors AS "Описание ошибки",
       (errors <> '') = expected_error AS "Проверка пройдена" FROM checked;
