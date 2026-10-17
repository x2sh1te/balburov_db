-- Выполнить один раз после second_migration.sql.
-- Учебные диапазоны заданы для проверки данных, а не как нормативы.
BEGIN;
INSERT INTO measurement_units (id, name, symbol)
VALUES (4, 'процент', '%');
INSERT INTO parameter_types (id, name, measurement_unit_id)
VALUES (5, 'Относительная влажность', 4);

INSERT INTO users (full_name, position_id)
SELECT 'Тест: Сидоров С.С.', id FROM positions WHERE id = 1;
INSERT INTO users (full_name, position_id)
SELECT 'Тест: Смирнова А.А.', id FROM positions WHERE id = 2;
INSERT INTO users (full_name, position_id)
SELECT 'Тест: Кузнецов Д.Д.', id FROM positions WHERE id = 1;

INSERT INTO batches (user_id, equipment_type_id)
SELECT id, 1 FROM users WHERE full_name = 'Тест: Сидоров С.С.';
INSERT INTO batches (user_id, equipment_type_id)
SELECT id, 2 FROM users WHERE full_name = 'Тест: Смирнова А.А.';
INSERT INTO batches (user_id, equipment_type_id)
SELECT id, 1 FROM users WHERE full_name = 'Тест: Кузнецов Д.Д.';

-- Полная корректная пачка из пяти разных параметров.
INSERT INTO parameters (batch_id, parameter_type_id, value, measurement_date)
SELECT b.id, pt.id,
    CASE pt.id
        WHEN 1 THEN 120.00
        WHEN 2 THEN 18.50
        WHEN 3 THEN 4.20
        WHEN 4 THEN 30.00
        WHEN 5 THEN 65.00
    END,
    DATE '2026-10-01'
FROM batches b
INNER JOIN users u ON b.user_id = u.id
CROSS JOIN parameter_types pt
WHERE u.full_name = 'Тест: Сидоров С.С.' AND pt.id BETWEEN 1 AND 5;

-- Ошибочная пачка: нет дальности сноса, влажность выше 100%.
INSERT INTO parameters (batch_id, parameter_type_id, value, measurement_date)
SELECT b.id, pt.id,
    CASE pt.id
        WHEN 1 THEN 150.00
        WHEN 2 THEN 12.00
        WHEN 3 THEN 7.00
        WHEN 5 THEN 120.00
    END,
    DATE '2026-10-02'
FROM batches b
INNER JOIN users u ON b.user_id = u.id
CROSS JOIN parameter_types pt
WHERE u.full_name = 'Тест: Смирнова А.А.'
    AND pt.id IN (1, 2, 3, 5);
-- Пачка Кузнецова намеренно пустая.
COMMIT;
