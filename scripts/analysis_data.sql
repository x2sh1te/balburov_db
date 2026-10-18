-- Ответ GigaChat после исправления ошибок запуска; форматирование сокращено.
-- Один запуск на базе после второй миграции. PostgreSQL.
BEGIN;
INSERT INTO measurement_units (id, name, symbol)
VALUES (4, 'процент', '%') ON CONFLICT (id) DO NOTHING;
INSERT INTO parameter_types (id, name, measurement_unit_id)
VALUES (5, 'относительная влажность', 4) ON CONFLICT (id) DO NOTHING;
WITH inserted_users AS (
    INSERT INTO users (full_name, position_id) VALUES
        ('Иванов Алексей Сергеевич', 1),
        ('Петрова Мария Дмитриевна', 2),
        ('Сидоров Николай Павлович', 1)
    RETURNING id, full_name
), inserted_batches AS (
    INSERT INTO batches (user_id, equipment_type_id)
    SELECT u.id, CASE
        WHEN u.full_name = 'Иванов Алексей Сергеевич' THEN 1
        WHEN u.full_name = 'Петрова Мария Дмитриевна' THEN 2
        ELSE 1 END
    FROM inserted_users u
    RETURNING id, user_id, equipment_type_id
)
INSERT INTO parameters (batch_id, parameter_type_id, value, measurement_date)
SELECT b.id, v.parameter_type_id, v.value, v.measurement_date
FROM inserted_batches b
CROSS JOIN LATERAL (
    VALUES
        (1, 150.50, DATE '2024-05-01'),
        (2, 22.40, DATE '2024-05-01'),
        (3, 5.20, DATE '2024-05-01'),
        (4, 120.00, DATE '2024-05-01'),
        (5, 65.00, DATE '2024-05-01')
    UNION ALL VALUES
        (1, 50.00, DATE '2024-05-02'),
        (2, 101.50, DATE '2024-05-02'),
        (3, 15.80, DATE '2024-05-02'),
        (4, -10.00, DATE '2024-05-02'),
        (5, 105.00, DATE '2024-05-02')
    UNION ALL VALUES
        (1, 200.00, DATE '2024-05-03'),
        (2, NULL, DATE '2024-05-03'),
        (3, 0.00, DATE '2024-05-03'),
        (4, 250.75, DATE '2024-05-03'),
        (5, NULL, DATE '2024-05-03')
    UNION ALL VALUES
        (1, 175.25, DATE '2024-05-04'),
        (2, -99.99, DATE '2024-05-04'),
        (3, 25.40, DATE '2024-05-04'),
        (4, 180.00, DATE '2024-05-04'),
        (5, 40.00, DATE '2024-05-04')
    UNION ALL VALUES
        (2, 18.20, DATE '2024-05-05'),
        (3, 8.10, DATE '2024-05-05'),
        (5, 72.50, DATE '2024-05-05')
) AS v(parameter_type_id, value, measurement_date)
WHERE (
    (b.user_id IN (SELECT id FROM inserted_users WHERE full_name IN
        ('Иванов Алексей Сергеевич', 'Сидоров Николай Павлович'))
        AND b.equipment_type_id = 1 AND v.measurement_date = DATE '2024-05-01')
    OR (b.user_id = (SELECT id FROM inserted_users WHERE full_name = 'Петрова Мария Дмитриевна')
        AND b.equipment_type_id = 2 AND v.measurement_date = DATE '2024-05-02')
    OR (b.user_id = (SELECT id FROM inserted_users WHERE full_name = 'Сидоров Николай Павлович')
        AND b.equipment_type_id = 1 AND v.measurement_date = DATE '2024-05-03')
    OR (b.user_id = (SELECT id FROM inserted_users WHERE full_name = 'Иванов Алексей Сергеевич')
        AND b.equipment_type_id = 2
        AND v.measurement_date IN (DATE '2024-05-04', DATE '2024-05-05'))
);
COMMIT;
