DO $tests$
DECLARE
    sample RECORD;
    points meteo_plpgsql.interpolation_points;
    actual NUMERIC;
    passed INTEGER := 0;
BEGIN
    points := meteo_plpgsql.get_interpolation_points(26);
    IF points.x0 <> 25 OR points.y0 <> 2 OR points.x1 <> 30 OR points.y1 <> 3.5 THEN
        RAISE EXCEPTION 'Неверные границы для 26 градусов: %', points;
    END IF;
    RAISE NOTICE '26 °C: x0=%, y0=%, x1=%, y1=%', points.x0,points.y0,points.x1,points.y1;
    FOR sample IN SELECT * FROM (VALUES
        (-10::NUMERIC,0::NUMERIC), (-0.01,0), (0,0.5), (2.5,0.5),
        (5,0.5), (7.5,0.75), (10,1), (15,1), (20,1),
        (23,1.6), (25,2), (26,2.3), (30,3.5), (35,4),
        (40,4.5), (40.01,4.5), (50,4.5)
    ) AS cases(temperature,expected) LOOP
        points := meteo_plpgsql.get_interpolation_points(sample.temperature);
        actual := meteo_plpgsql.interpolate(sample.temperature,points);
        IF actual IS DISTINCT FROM sample.expected THEN
            RAISE EXCEPTION 'Температура %: ожидалось %, получено %', sample.temperature,sample.expected,actual;
        END IF;
        passed := passed + 1;
        RAISE NOTICE 'Тест %: температура % °C; поправка %; ОК',passed,sample.temperature,round(actual,4);
    END LOOP;
    BEGIN
        PERFORM meteo_plpgsql.get_interpolation_points(NULL);
        RAISE EXCEPTION 'NULL ошибочно принят' USING ERRCODE = 'ZX001';
    EXCEPTION WHEN raise_exception THEN
        RAISE NOTICE 'NULL: корректно отклонен';
    END;
    RAISE NOTICE 'Успешно: % числовых проверок, проверка границ 26 °C и отклонение NULL',passed;
END;
$tests$;

SELECT t.temperature AS "Температура, °C",
    p.x0, p.y0, p.x1, p.y1,
    ROUND(meteo_plpgsql.interpolate(t.temperature,p),4) AS "Поправка, °C"
FROM (VALUES (-10::NUMERIC),(0),(23),(26),(40),(50)) AS t(temperature)
CROSS JOIN LATERAL meteo_plpgsql.get_interpolation_points(t.temperature) p
ORDER BY t.temperature;
