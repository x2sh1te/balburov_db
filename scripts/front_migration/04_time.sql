-- Справочник времени
DO $$
BEGIN
    CREATE TABLE IF NOT EXISTS dim_time (
        id bigint PRIMARY KEY,
        date_start date,
        date_end date,
        month_name text,
        year integer,
        quarter_num integer,
        quarter_name text
    );
END;
$$;

-- Одна строка на месяц
WITH months AS (
    SELECT month_start,
           EXTRACT(YEAR FROM month_start)::integer AS year,
           EXTRACT(MONTH FROM month_start)::integer AS month_num,
           EXTRACT(QUARTER FROM month_start)::integer AS quarter_num
    FROM generate_series(
        timestamp '2013-01-01',
        timestamp '2023-12-01',
        interval '1 month'
    ) AS series(month_start)
)
INSERT INTO dim_time (id, date_start, date_end, month_name, year, quarter_num, quarter_name)
SELECT year * 100 + month_num,
       month_start::date,
       (month_start + interval '1 month' - interval '1 day')::date,
       (ARRAY['Январь', 'Февраль', 'Март', 'Апрель', 'Май', 'Июнь',
              'Июль', 'Август', 'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь'])[month_num],
       year,
       quarter_num,
       (ARRAY['I квартал', 'II квартал', 'III квартал', 'IV квартал'])[quarter_num]
FROM months
ON CONFLICT (id) DO NOTHING;
