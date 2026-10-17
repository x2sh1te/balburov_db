-- Каждый запрос выполнять отдельно для отдельного скриншота.

-- 1. Количество измерений каждого пользователя и сравнение с остальными.
SELECT u.id, u.full_name AS "Сотрудник",
    COUNT(p.id) AS "Измерений",
    CASE WHEN NOT EXISTS (
        SELECT u2.id
        FROM users u2
        LEFT JOIN batches b2 ON b2.user_id = u2.id
        LEFT JOIN parameters p2 ON p2.batch_id = b2.id
        GROUP BY u2.id
        HAVING COUNT(p2.id) <> COUNT(p.id)
    ) THEN 'Да' ELSE 'Нет' END AS "У всех поровну"
FROM users u
LEFT JOIN batches b ON b.user_id = u.id
LEFT JOIN parameters p ON p.batch_id = b.id
GROUP BY u.id, u.full_name
ORDER BY u.id;

-- 2. Проверка всех пачек на отсутствие измерений.
SELECT b.id AS "Пачка", u.full_name AS "Сотрудник",
    COUNT(p.id) AS "Измерений",
    CASE WHEN COUNT(p.id) = 0 THEN 'Пустая' ELSE 'Не пустая' END AS "Результат"
FROM batches b
LEFT JOIN users u ON u.id = b.user_id
LEFT JOIN parameters p ON p.batch_id = b.id
GROUP BY b.id, u.full_name
ORDER BY b.id;
-- 3. Полнота: пять строк, пять разных ожидаемых типов.
SELECT b.id AS "Пачка", COUNT(p.id) AS "Измерений",
    COUNT(DISTINCT p.parameter_type_id) AS "Разных типов",
    CASE WHEN COUNT(p.id) = 5
        AND COUNT(DISTINCT CASE WHEN p.parameter_type_id BETWEEN 1 AND 5
            THEN p.parameter_type_id ELSE NULL END) = 5
        THEN 'Полная' ELSE 'Ошибка состава' END AS "Результат"
FROM batches b
LEFT JOIN parameters p ON p.batch_id = b.id
GROUP BY b.id
ORDER BY b.id;

-- 4. Учебные диапазоны, согласованные для этого набора:
-- высота -500..9000 м; температура -90..60 °C;
-- ветер 0..100 м/с; снос 0..1000 м; влажность 0..100%.
SELECT p.id AS "Измерение", p.batch_id AS "Пачка",
    pt.name AS "Параметр", p.value AS "Значение",
    CASE pt.id
        WHEN 1 THEN '-500 .. 9000 м'
        WHEN 2 THEN '-90 .. 60 °C'
        WHEN 3 THEN '0 .. 100 м/с'
        WHEN 4 THEN '0 .. 1000 м'
        WHEN 5 THEN '0 .. 100 %'
        ELSE 'Не задан' END AS "Допустимый диапазон",
    CASE WHEN p.value IS NULL THEN 'Нет значения'
        ELSE 'Вне диапазона или неизвестный тип' END AS "Ошибка"
FROM parameters p
INNER JOIN parameter_types pt ON pt.id = p.parameter_type_id
WHERE p.value IS NULL
    OR (pt.id = 1 AND (p.value < -500 OR p.value > 9000))
    OR (pt.id = 2 AND (p.value < -90 OR p.value > 60))
    OR (pt.id = 3 AND (p.value < 0 OR p.value > 100))
    OR (pt.id = 4 AND (p.value < 0 OR p.value > 1000))
    OR (pt.id = 5 AND (p.value < 0 OR p.value > 100))
    OR pt.id NOT BETWEEN 1 AND 5
ORDER BY p.batch_id, p.id;

-- 5. Единица назначена типу параметра, поэтому проверяем справочник.
SELECT pt.name AS "Параметр", mu.symbol AS "Единица",
    CASE WHEN
        (pt.id IN (1, 4) AND mu.id = 1 AND mu.symbol = 'м')
        OR (pt.id = 2 AND mu.id = 3 AND mu.symbol = '°C')
        OR (pt.id = 3 AND mu.id = 2 AND mu.symbol = 'м/с')
        OR (pt.id = 5 AND mu.id = 4 AND mu.symbol = '%')
    THEN 'Верно' ELSE 'Ошибка' END AS "Результат"
FROM parameter_types pt
LEFT JOIN measurement_units mu ON mu.id = pt.measurement_unit_id
ORDER BY pt.id;
