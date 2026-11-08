DO $$
BEGIN
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
        speed_index integer;           -- позиция входного значения в массиве
        mean_speed integer;            -- скорость среднего ветра
        mean_direction numeric;        -- направление в больших делениях угломера
    BEGIN
        -- выбираем справочники по типу оборудования
        IF p_equipment_id = 1 THEN
            speed_type := 6;
            direction_type := 7;
            wind_input := p.wind_speed;
            wind_threshold := 3;
        ELSIF p_equipment_id = 2 THEN
            speed_type := 4;
            direction_type := 5;
            wind_input := p.distance;
            wind_threshold := 40;
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

            speed_index := array_position(
                speed_headers, trunc(wind_input)::integer
            );

            IF wind_input <> trunc(wind_input) OR speed_index IS NULL THEN
                RAISE EXCEPTION 'В таблице 3 нет столбца для значения %', wind_input;
            END IF;
        END IF;

        -- получаем виртуальную поправку из существующей интерполяции
        virtual_correction := meteo_plpgsql.interpolate(
            p.temperature,
            meteo_plpgsql.get_interpolation_points(p.temperature)
        );

        -- делим величину отклонения на десятки и единицы для таьлицы 2
        ground_deviation := round(p.temperature + virtual_correction - 15.9);
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

            --  складываем поправки десятков и единиц если прочерк то будет  NULL
            mean_deviation := 0;

            IF tens > 0 THEN
                mean_deviation :=
                    temperature_values[array_position(temperature_headers, tens)];
            END IF;

            IF units > 0 THEN
                mean_deviation := mean_deviation
                    + temperature_values[array_position(temperature_headers, units)];
            END IF;

            --  если скорость и направление ниже порога то они равно нулю
            IF wind_input < wind_threshold THEN
                mean_speed := 0;
                mean_direction := 0;
            ELSE
                SELECT c.row_values[speed_index] INTO mean_speed
                FROM public.calc_correction AS c
                WHERE c.height_id = current_height.id
                  AND c.type_id = speed_type;

                -- прибавляем одну поправку направления на высоту
                SELECT mod(p.wind_direction + c.row_values[1], 60)
                INTO mean_direction
                FROM public.calc_correction AS c
                WHERE c.height_id = current_height.id
                  AND c.type_id = direction_type;
            END IF;

            -- сохраняем одну строку результата на высоту
            INSERT INTO pg_temp.calculation_result
                (height, delta_h0, delta_t0_mp, delta_ty, wind_speed, wind_direction)
            VALUES
                (current_height.height, p.pressure - 750, ground_deviation,
                 mean_deviation, mean_speed, mean_direction);
        END LOOP;
    END;
    $procedure$;

    COMMENT ON PROCEDURE public.calculation(
        meteo_plpgsql.input_parameters, integer
    ) IS 'расчёт метеоданных по стандартным высотам с выводом во временную таблицу';
END;
$$;
