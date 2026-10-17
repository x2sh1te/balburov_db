CREATE TABLE base_units (
    id INTEGER NOT NULL,
    name VARCHAR(100) NOT NULL,
    symbol VARCHAR(20) NOT NULL,
    PRIMARY KEY (id)
);

INSERT INTO base_units (id, name, symbol)
VALUES (1, 'метр', 'м');

INSERT INTO base_units (id, name, symbol)
VALUES (2, 'секунда', 'с');

INSERT INTO base_units (id, name, symbol)
VALUES (3, 'кельвин', 'K');

CREATE TABLE measurement_units (
    id INTEGER NOT NULL,
    name VARCHAR(100) NOT NULL,
    symbol VARCHAR(20) NOT NULL,
    PRIMARY KEY (id)
);

INSERT INTO measurement_units (id, name, symbol)
VALUES (1, 'метр', 'м');

INSERT INTO measurement_units (id, name, symbol)
VALUES (2, 'метр в секунду', 'м/с');

INSERT INTO measurement_units (id, name, symbol)
VALUES (3, 'градус Цельсия', '°C');

CREATE TABLE measurement_unit_components (
    measurement_unit_id INTEGER NOT NULL,
    base_unit_id INTEGER NOT NULL,
    power INTEGER NOT NULL,
    PRIMARY KEY (measurement_unit_id, base_unit_id),
    FOREIGN KEY (measurement_unit_id)
        REFERENCES measurement_units(id),
    FOREIGN KEY (base_unit_id)
        REFERENCES base_units(id)
);


INSERT INTO measurement_unit_components
    (measurement_unit_id, base_unit_id, power)
VALUES (1, 1, 1);

INSERT INTO measurement_unit_components
    (measurement_unit_id, base_unit_id, power)
VALUES (2, 1, 1);

INSERT INTO measurement_unit_components
    (measurement_unit_id, base_unit_id, power)
VALUES (2, 2, -1);

INSERT INTO measurement_unit_components
    (measurement_unit_id, base_unit_id, power)
VALUES (3, 3, 1);
CREATE TABLE parameter_types (
    id INTEGER NOT NULL,
    name VARCHAR(100) NOT NULL,
    measurement_unit_id INTEGER NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (measurement_unit_id) REFERENCES measurement_units(id)
);

INSERT INTO parameter_types (id, name, measurement_unit_id)
VALUES (1, 'Высота метеопоста', 1);
INSERT INTO parameter_types (id, name, measurement_unit_id)
VALUES (2, 'Температура', 3);
INSERT INTO parameter_types (id, name, measurement_unit_id)
VALUES (3, 'Скорость ветра', 2);
INSERT INTO parameter_types (id, name, measurement_unit_id)
VALUES (4, 'Дальность сноса пуль', 1);

ALTER TABLE parameters ADD COLUMN parameter_type_id INTEGER;
ALTER TABLE parameters ADD COLUMN measurement_date DATE;

UPDATE parameters
SET parameter_type_id = (
    SELECT pt.id FROM parameter_types pt
    WHERE pt.name = parameters.name
);

-- Учебные даты: исходная база не содержала дат измерений.
UPDATE parameters SET measurement_date = DATE '2026-09-22' WHERE batch_id = 1;
UPDATE parameters SET measurement_date = DATE '2026-09-23' WHERE batch_id = 2;

ALTER TABLE parameters
    ADD CONSTRAINT fk_parameters_parameter_type
    FOREIGN KEY (parameter_type_id) REFERENCES parameter_types(id);
ALTER TABLE parameters
    ADD CONSTRAINT chk_parameters_type_required
    CHECK (parameter_type_id IS NOT NULL);
ALTER TABLE parameters
    ADD CONSTRAINT chk_parameters_date_required
    CHECK (measurement_date IS NOT NULL);

ALTER TABLE parameters DROP COLUMN name RESTRICT;

SELECT
    p.measurement_date AS "Дата измерения",
    b.id AS "Номер пачки",
    u.full_name AS "ФИО сотрудника",
    pt.name || ', ' || mu.symbol AS "Наименование параметра и ед. измерения",
    p.value AS "Значение"
FROM parameters p
INNER JOIN batches b ON p.batch_id = b.id
INNER JOIN users u ON b.user_id = u.id
INNER JOIN parameter_types pt ON p.parameter_type_id = pt.id
INNER JOIN measurement_units mu ON pt.measurement_unit_id = mu.id
ORDER BY p.measurement_date, b.id, p.id;
