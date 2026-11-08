DO $$
BEGIN
    CREATE OR REPLACE FUNCTION public.format_temperature_deviation(p_value integer)
    RETURNS integer
    LANGUAGE sql
    IMMUTABLE
    AS $format$
        SELECT CASE WHEN p_value < 0 THEN abs(p_value) + 50 ELSE p_value END;
    $format$;

    CREATE OR REPLACE PROCEDURE public.calculation(
        p meteo_plpgsql.input_parameters,
        p_equipment_id integer
    )
    LANGUAGE plpgsql
    AS $procedure$
    DECLARE
        current_height record;         -- код и значение текущей высоты
        virtual_correction numeric;    -- виртуальная поправка из таблицы 1
        ground_deviation integer;      -- округлённое приземное отклонение
        deviation_size integer;        -- величина отклонения без знака
        tens integer;                  -- часть отклонения, кратная десяти
        units integer;                 -- остаток после вычитания десятков
        temperature_type integer;      -- тип поправки по знаку отклонения
        temperature_headers integer[]; -- заголовки таблицы 2
        temperature_values integer[];  -- поправки для текущей высоты
        mean_deviation integer;        -- среднее отклонение температуры
        speed_type integer;            -- тип строки со скоростями
        direction_type integer;        -- тип строки с поправкой направления
        wind_input numeric;            -- приземная скорость или дальность сноса
        wind_threshold integer;        -- порог обнуления ветра
        speed_headers integer[];       -- заголовки таблицы 3
        dmk_threshold CONSTANT integer := 3;
        vr_threshold CONSTANT integer := 40;
        full_circle CONSTANT integer := 60;
        reference_pressure CONSTANT numeric := meteo_plpgsql.get_constant('reference_pressure');
        reference_temperature CONSTANT numeric := meteo_plpgsql.get_constant('reference_temperature');
        lower_input integer;
        upper_input integer;
        speed_values integer[];
        lower_speed integer;
        upper_speed integer;
        speed_index integer;           -- позиция входного значения в массиве
        mean_speed integer;            -- скорость среднего ветра
        mean_direction numeric;        -- направление в больших делениях угломера
    BEGIN
        -- выбираем справочники по типу оборудования
        IF p_equipment_id = 1 THEN
            speed_type := 6;
            direction_type := 7;
            wind_input := p.wind_speed;
            wind_threshold := dmk_threshold;
        ELSIF p_equipment_id = 2 THEN
            speed_type := 4;
            direction_type := 5;
            wind_input := p.distance;
            wind_threshold := vr_threshold;
        ELSE
            RAISE EXCEPTION 'Укажите тип оборудования: 1 (ДМК) или 2 (ВР)';
        END IF;

        IF wind_input IS NULL OR wind_input < 0 THEN
            RAISE EXCEPTION 'Укажите неотрицательную скорость или дальность';
        END IF;

        -- находим номер столбца по скорости или дальности сноса
        IF wind_input >= wind_threshold THEN
            SELECT ch.header_values INTO speed_headers
            FROM public.calc_correction_types AS t
            JOIN public.calc_headers AS ch ON ch.id = t.header_id
            WHERE t.id = speed_type;

            -- ищем соседние столбцы для линейной интерполяции
            SELECT max(value) INTO lower_input
            FROM unnest(speed_headers) AS headers(value)
            WHERE value <= wind_input;

            SELECT min(value) INTO upper_input
            FROM unnest(speed_headers) AS headers(value)
            WHERE value >= wind_input;

            IF lower_input IS NULL OR upper_input IS NULL THEN
                RAISE EXCEPTION 'Значение % вне диапазона таблицы 3', wind_input;
            END IF;

            speed_index := array_position(speed_headers, lower_input);
        END IF;

        -- получаем виртуальную поправку из существующей интерполяции
        virtual_correction := meteo_plpgsql.interpolate(
            p.temperature,
            meteo_plpgsql.get_interpolation_points(p.temperature)
        );

        -- делим величину отклонения на десятки и единицы для таблицы 2
        ground_deviation := round(p.temperature + virtual_correction - reference_temperature);
        deviation_size := abs(ground_deviation);
        tens := (deviation_size / 10) * 10;
        units := deviation_size % 10;

        temperature_type := 8;
        IF ground_deviation < 0 THEN
            temperature_type := 9;
        END IF;

        SELECT ch.header_values INTO temperature_headers
        FROM public.calc_correction_types AS t
        JOIN public.calc_headers AS ch ON ch.id = t.header_id
        WHERE t.id = temperature_type;

        -- сохраняем результат во временной таблице текущего сеанса
        CREATE TEMP TABLE IF NOT EXISTS calculation_result (
            height integer,
            delta_h0 numeric,
            delta_t0_mp integer,
            delta_ty integer,
            wind_speed integer,
            wind_direction numeric
        );

        -- очищаем результат предыдущего вызова в этой сессии
        DELETE FROM pg_temp.calculation_result;

        -- рассчитываем показатели для каждой стандартной высоты
        FOR current_height IN
            SELECT id, height
            FROM public.calc_correction_heights
            ORDER BY height
        LOOP
            SELECT c.row_values INTO temperature_values
            FROM public.calc_correction AS c
            WHERE c.height_id = current_height.id
              AND c.type_id = temperature_type;

            -- складываем поправки десятков и единиц, прочерк даёт NULL
            mean_deviation := 0;

            IF tens > 0 THEN
                mean_deviation :=
                    temperature_values[array_position(temperature_headers, tens)];
            END IF;

            IF units > 0 THEN
                mean_deviation := mean_deviation
                    + temperature_values[array_position(temperature_headers, units)];
            END IF;

            -- ниже порога скорость и направление равны нулю
            IF wind_input < wind_threshold THEN
                mean_speed := 0;
                mean_direction := 0;
            ELSE
                SELECT c.row_values INTO speed_values
                FROM public.calc_correction AS c
                WHERE c.height_id = current_height.id
                  AND c.type_id = speed_type;

                lower_speed := speed_values[speed_index];
                upper_speed := speed_values[array_position(speed_headers, upper_input)];

                IF lower_input = upper_input THEN
                    mean_speed := lower_speed;
                ELSE
                    mean_speed := round(lower_speed
                        + (wind_input - lower_input) * (upper_speed - lower_speed)
                          / (upper_input - lower_input));
                END IF;

                -- прибавляем одну поправку направления на высоту
                SELECT mod(p.wind_direction + c.row_values[1], full_circle)
                INTO mean_direction
                FROM public.calc_correction AS c
                WHERE c.height_id = current_height.id
                  AND c.type_id = direction_type;
            END IF;

            -- сохраняем одну строку результата на высоту
            INSERT INTO pg_temp.calculation_result
                (height, delta_h0, delta_t0_mp, delta_ty, wind_speed, wind_direction)
            VALUES
                (current_height.height, p.pressure - reference_pressure, ground_deviation,
                 mean_deviation, mean_speed, mean_direction);
        END LOOP;
    END;
    $procedure$;

    COMMENT ON PROCEDURE public.calculation(
        meteo_plpgsql.input_parameters, integer
    ) IS 'расчёт метеоданных по стандартным высотам с выводом во временную таблицу';
END;
$$;
