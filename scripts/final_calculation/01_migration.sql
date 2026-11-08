DO $$
BEGIN
    -- применяем после учебного скрипта 20261102.sql
    CREATE TABLE public.calc_headers (
        id integer PRIMARY KEY,
        description text NOT NULL,
        header_values integer[] NOT NULL
    );

    ALTER TABLE public.calc_correction_types
        ADD COLUMN header_id integer REFERENCES public.calc_headers(id);

    COMMENT ON TABLE public.calc_headers IS 'таблица для хранения наборов заголовков';
    COMMENT ON COLUMN public.calc_headers.id IS 'уникальный код набора';
    COMMENT ON COLUMN public.calc_headers.description IS 'описание набора заголовков';
    COMMENT ON COLUMN public.calc_headers.header_values IS 'значения заголовков в порядке столбцов';

    COMMENT ON TABLE public.calc_correction_heights IS 'справочник стандартных высот';
    COMMENT ON COLUMN public.calc_correction_heights.id IS 'уникальный код высоты';
    COMMENT ON COLUMN public.calc_correction_heights.height IS 'стандартная высота в метрах';

    COMMENT ON TABLE public.calc_correction_types IS 'справочник типов табличных поправок';
    COMMENT ON COLUMN public.calc_correction_types.id IS 'уникальный код типа';
    COMMENT ON COLUMN public.calc_correction_types.parent_id IS 'код родительского типа';
    COMMENT ON COLUMN public.calc_correction_types.measurment_equipment_id IS 'код оборудования';
    COMMENT ON COLUMN public.calc_correction_types.description IS 'описание типа поправки';
    COMMENT ON COLUMN public.calc_correction_types.header_id IS 'ссылка на набор заголовков';

    COMMENT ON TABLE public.calc_correction IS 'табличные поправки по высотам и типам';
    COMMENT ON COLUMN public.calc_correction.id IS 'уникальный код строки поправок';
    COMMENT ON COLUMN public.calc_correction.height_id IS 'код стандартной высоты';
    COMMENT ON COLUMN public.calc_correction.type_id IS 'код типа поправки';
    COMMENT ON COLUMN public.calc_correction.row_values IS 'значения в порядке заголовков или одна поправка направления';

    -- позиции заголовков совпадают с позициями поправок
    INSERT INTO public.calc_headers (id, description, header_values)
    VALUES
        (1, 'температурные отклонения', ARRAY[1,2,3,4,5,6,7,8,9,10,20,30,40,50]),
        (2, 'дальность сноса ВР, м', ARRAY[40,50,60,70,80,90,100,110,120,130,140,150]),
        (3, 'приземная скорость ветра ДМК, м/с', ARRAY[3,4,5,6,7,8,9,10,11,12,13,14,15]);

    UPDATE public.calc_correction_types SET header_id = 1 WHERE id IN (8, 9);
    UPDATE public.calc_correction_types SET header_id = 2 WHERE id = 4;
    UPDATE public.calc_correction_types SET header_id = 3 WHERE id = 6;
    ALTER TABLE public.calc_correction_types DROP COLUMN header_values RESTRICT;

    -- исправляем перепутанные типы в исходных строках
    UPDATE public.calc_correction SET type_id = 9 WHERE id BETWEEN 1 AND 4 AND type_id = 8;
    UPDATE public.calc_correction SET type_id = 8 WHERE id BETWEEN 5 AND 8 AND type_id = 7;

    -- обновляем четыре исходные высоты и добавляем пять недостающих
    ALTER TABLE public.calc_correction
        ADD CONSTRAINT calc_correction_height_type_key UNIQUE (height_id, type_id);

    INSERT INTO public.calc_correction (height_id, type_id, row_values)
    VALUES
        (1, 9, ARRAY[-1, -2, -3, -4, -5, -6, -7, -8, -8, -9, -20, -29, -39, -49]),
        (2, 9, ARRAY[-1, -2, -3, -4, -5, -6, -6, -7, -8, -9, -19, -29, -38, -48]),
        (3, 9, ARRAY[-1, -2, -3, -4, -5, -6, -6, -7, -7, -8, -18, -28, -37, -46]),
        (4, 9, ARRAY[-1, -2, -3, -4, -4, -5, -5, -6, -7, -8, -17, -26, -35, -44]),
        (5, 9, ARRAY[-1, -2, -3, -3, -4, -4, -5, -6, -7, -7, -17, -25, -34, -42]),
        (6, 9, ARRAY[-1, -2, -3, -3, -4, -4, -5, -6, -6, -7, -16, -24, -32, -40]),
        (7, 9, ARRAY[-1, -2, -2, -3, -4, -4, -5, -5, -6, -7, -15, -23, -31, -38]),
        (8, 9, ARRAY[-1, -2, -2, -3, -4, -4, -4, -5, -5, -6, -15, -22, -30, -37]),
        (9, 9, ARRAY[-1, -2, -2, -3, -4, -4, -4, -4, -5, -6, -14, -20, -27, -34]),
        (1, 8, ARRAY[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 20, 30, NULL, NULL]),
        (2, 8, ARRAY[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 20, 30, NULL, NULL]),
        (3, 8, ARRAY[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 20, 30, NULL, NULL]),
        (4, 8, ARRAY[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 20, 30, NULL, NULL]),
        (5, 8, ARRAY[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 20, 30, NULL, NULL]),
        (6, 8, ARRAY[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 20, 30, NULL, NULL]),
        (7, 8, ARRAY[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 20, 30, NULL, NULL]),
        (8, 8, ARRAY[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 20, 30, NULL, NULL]),
        (9, 8, ARRAY[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 20, 30, NULL, NULL]),
        (1, 4, ARRAY[3, 4, 5, 6, 7, 7, 8, 9, 10, 11, 12, 12]),
        (2, 4, ARRAY[4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]),
        (3, 4, ARRAY[4, 5, 6, 7, 8, 9, 10, 11, 13, 14, 15, 16]),
        (4, 4, ARRAY[4, 5, 7, 8, 8, 9, 11, 12, 13, 15, 15, 16]),
        (5, 4, ARRAY[4, 6, 7, 8, 9, 10, 11, 13, 14, 15, 17, 17]),
        (6, 4, ARRAY[4, 6, 7, 8, 9, 10, 11, 13, 14, 16, 17, 18]),
        (7, 4, ARRAY[4, 6, 8, 9, 9, 10, 12, 14, 15, 16, 18, 19]),
        (8, 4, ARRAY[5, 6, 8, 9, 10, 11, 12, 14, 15, 17, 18, 19]),
        (9, 4, ARRAY[5, 6, 8, 9, 10, 11, 12, 14, 16, 18, 19, 20]),
        (1, 5, ARRAY[0]),
        (2, 5, ARRAY[1]),
        (3, 5, ARRAY[2]),
        (4, 5, ARRAY[2]),
        (5, 5, ARRAY[3]),
        (6, 5, ARRAY[3]),
        (7, 5, ARRAY[3]),
        (8, 5, ARRAY[4]),
        (9, 5, ARRAY[4]),
        (1, 6, ARRAY[4, 6, 8, 9, 10, 12, 14, 15, 16, 18, 20, 21, 22]),
        (2, 6, ARRAY[5, 7, 10, 11, 12, 14, 17, 18, 20, 22, 23, 25, 27]),
        (3, 6, ARRAY[5, 8, 10, 11, 13, 15, 18, 19, 21, 23, 25, 27, 28]),
        (4, 6, ARRAY[5, 8, 11, 12, 13, 16, 19, 20, 22, 24, 26, 28, 30]),
        (5, 6, ARRAY[6, 8, 11, 13, 14, 17, 20, 21, 23, 25, 27, 29, 32]),
        (6, 6, ARRAY[6, 9, 11, 13, 14, 17, 20, 21, 24, 26, 28, 30, 32]),
        (7, 6, ARRAY[6, 9, 12, 14, 15, 18, 21, 22, 25, 27, 29, 32, 34]),
        (8, 6, ARRAY[6, 9, 12, 14, 15, 18, 21, 23, 25, 28, 30, 32, 36]),
        (9, 6, ARRAY[6, 10, 12, 14, 16, 19, 22, 24, 26, 29, 32, 34, 36]),
        (1, 7, ARRAY[1]),
        (2, 7, ARRAY[2]),
        (3, 7, ARRAY[3]),
        (4, 7, ARRAY[3]),
        (5, 7, ARRAY[4]),
        (6, 7, ARRAY[4]),
        (7, 7, ARRAY[4]),
        (8, 7, ARRAY[5]),
        (9, 7, ARRAY[5])
    ON CONFLICT (height_id, type_id) DO UPDATE
    SET row_values = EXCLUDED.row_values;

    -- по таблице 1 поправка при 20 °C равна 1,5 °C
    UPDATE meteo_plpgsql.interpolation_corrections
    SET correction = 1.5
    WHERE temperature = 20;
END;
$$;
