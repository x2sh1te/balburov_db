DO $$
DECLARE
    p meteo_plpgsql.input_parameters;
BEGIN
    -- задаём входные данные для ДМК
    -- направление 180° соответствует 30 большим делениям
    p.equipment_type_id := 1;
    p.height := 100;
    p.temperature := 20;
    p.pressure := 750;
    p.wind_direction := 30;
    p.wind_speed := 5;

    CALL public.calculation(p, p.equipment_type_id);
END;
$$;

-- выводим результат по высотам в том же сеансе pgAdmin
SELECT height AS "Высота, м",
       delta_h0 AS "ΔH0",
       delta_t0_mp AS "ΔT0мп",
       delta_ty AS "ΔTy",
       wind_speed AS "Скорость ветра, м/с",
       wind_direction AS "Направление, дел."
FROM pg_temp.calculation_result
ORDER BY height;
