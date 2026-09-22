
DROP TABLE IF EXISTS parameters;
DROP TABLE IF EXISTS batches;
DROP TABLE IF EXISTS users;
DROP TABLE IF EXISTS equipment_types;
DROP TABLE IF EXISTS positions;

CREATE TABLE positions (
    id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name VARCHAR(255) NOT NULL
);

CREATE TABLE equipment_types (
    id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name VARCHAR(255) NOT NULL
);

CREATE TABLE users (
    id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    full_name VARCHAR(255) NOT NULL,
    position_id INT,
    FOREIGN KEY (position_id) REFERENCES positions(id)
);

CREATE TABLE batches (
    id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id INT,
    equipment_type_id INT,
    FOREIGN KEY (user_id) REFERENCES users(id),
    FOREIGN KEY (equipment_type_id) REFERENCES equipment_types(id)
);

CREATE TABLE parameters (
    id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    batch_id INT,
    name VARCHAR(255) NOT NULL,
    value DECIMAL(10, 2),
    FOREIGN KEY (batch_id) REFERENCES batches(id)
);

INSERT INTO positions (name) VALUES 
('Старший метеоролог'),
('Оператор-вычислитель');

INSERT INTO equipment_types (name) VALUES 
('Десантный метео комплект (ДМК)'),
('Ветровое ружье (ВР)');

INSERT INTO users (full_name, position_id) VALUES 
('Иванов И.И.', 1),
('Петров П.П.', 2);

INSERT INTO batches (user_id, equipment_type_id) VALUES 
(1, 1), 
(2, 2);

INSERT INTO parameters (batch_id, name, value) VALUES 
(1, 'Высота метеопоста', 100.00),
(1, 'Температура', 15.00),
(1, 'Скорость ветра', 6.00),
(2, 'Высота метеопоста', 150.00),
(2, 'Температура', -5.50),
(2, 'Дальность сноса пуль', 45.00);

SELECT 
    b.id AS "Код пачки",
    u.full_name AS "Сотрудник",
    pos.name AS "Должность",
    eq.name AS "Оборудование",
    p.name AS "Параметр",
    p.value AS "Значение"
FROM batches b
INNER JOIN users u ON b.user_id = u.id
INNER JOIN positions pos ON u.position_id = pos.id
INNER JOIN equipment_types eq ON b.equipment_type_id = eq.id
INNER JOIN parameters p ON p.batch_id = b.id
ORDER BY b.id, p.id;