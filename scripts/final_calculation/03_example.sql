DO $$
DECLARE
    p meteo_plpgsql.input_parameters;
BEGIN
    -- задаём входные данные для ДМК
    -- пример 2 из ТЗ
    p.equipment_type_id := 1;
    p.height := 100;
    p.temperature := 25;
    p.pressure := 765;
    p.wind_direction := 15;
    p.wind_speed := 6;

    CALL public.calculation(p, p.equipment_type_id);

    CREATE TEMP TABLE IF NOT EXISTS calculation_examples AS
    SELECT ''::text AS equipment, r.*
    FROM pg_temp.calculation_result AS r
    WITH NO DATA;

    DELETE FROM pg_temp.calculation_examples;
    INSERT INTO pg_temp.calculation_examples
    SELECT 'ДМК', r.* FROM pg_temp.calculation_result AS r;

    -- проверяем интерполяцию скорости для ВР между 40 и 50 м
    p.equipment_type_id := 2;
    p.wind_speed := NULL;
    p.distance := 45;
    CALL public.calculation(p, p.equipment_type_id);

    INSERT INTO pg_temp.calculation_examples
    SELECT 'ВР', r.* FROM pg_temp.calculation_result AS r;
END;
$$;

-- выводим результат по высотам в том же сеансе pgAdmin
SELECT equipment AS "Оборудование",
       height AS "Высота, м",
       delta_h0 AS "ΔH0",
       delta_t0_mp AS "ΔT0мп",
       delta_ty AS "ΔTy",
       public.format_temperature_deviation(delta_ty) AS "ΔTy в бюллетене",
       wind_speed AS "Скорость ветра, м/с",
       wind_direction AS "Направление, дел."
FROM pg_temp.calculation_examples
ORDER BY equipment, height;
