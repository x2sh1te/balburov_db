BEGIN;
CREATE SCHEMA meteo_plpgsql;
DO $structure$
DECLARE
    item RECORD;
BEGIN
    FOR item IN SELECT * FROM (VALUES
        ('positions', 'name VARCHAR(255)'),
        ('equipment_types', 'name VARCHAR(255)'),
        ('users', 'full_name VARCHAR(255), position_id INTEGER'),
        ('batches', 'user_id INTEGER, equipment_type_id INTEGER'),
        ('base_units', 'name VARCHAR(100), symbol VARCHAR(20)'),
        ('measurement_units', 'name VARCHAR(100), symbol VARCHAR(20)'),
        ('measurement_unit_components', 'measurement_unit_id INTEGER, base_unit_id INTEGER, power INTEGER'),
        ('parameter_types', 'name VARCHAR(100), measurement_unit_id INTEGER'),
        ('parameters', 'batch_id INTEGER, parameter_type_id INTEGER, value DECIMAL(10,2), measurement_date DATE'),
        ('temperature_corrections', 'source_label VARCHAR(30), temperature_from DECIMAL(5,2), temperature_to DECIMAL(5,2), correction DECIMAL(5,2)')
    ) AS definitions(table_name, columns_sql)
    LOOP
        EXECUTE format('CREATE SEQUENCE meteo_plpgsql.%I START WITH 1', item.table_name || '_id_seq');
        EXECUTE format(
            'CREATE TABLE meteo_plpgsql.%I (id INTEGER DEFAULT nextval(%L), %s)',
            item.table_name, 'meteo_plpgsql.' || item.table_name || '_id_seq', item.columns_sql);
        EXECUTE format('ALTER SEQUENCE meteo_plpgsql.%I OWNED BY meteo_plpgsql.%I.id',
            item.table_name || '_id_seq', item.table_name);
    END LOOP;
END;
$structure$;
COMMIT;
BEGIN;
DO $data$
DECLARE
    staff_id INTEGER;
    batch_id_new INTEGER;
    person_name TEXT;
BEGIN
    INSERT INTO meteo_plpgsql.positions (name) VALUES ('Старший метеоролог'), ('Оператор-вычислитель');
    INSERT INTO meteo_plpgsql.equipment_types (name) VALUES ('Портативный метеокомплект'), ('Учебный датчик сноса');
    INSERT INTO meteo_plpgsql.base_units (name, symbol) VALUES ('метр', 'м'), ('секунда', 'с'), ('кельвин', 'K');
    INSERT INTO meteo_plpgsql.measurement_units (name, symbol)
    VALUES ('метр', 'м'), ('метр в секунду', 'м/с'), ('градус Цельсия', '°C'), ('процент', '%');
    INSERT INTO meteo_plpgsql.measurement_unit_components (measurement_unit_id, base_unit_id, power)
    VALUES (1,1,1), (2,1,1), (2,2,-1), (3,3,1);
    INSERT INTO meteo_plpgsql.parameter_types (name, measurement_unit_id)
    VALUES ('Высота метеопоста',1), ('Температура',3), ('Скорость ветра',2),
           ('Дальность сноса индикатора',1), ('Относительная влажность',4);
    FOREACH person_name IN ARRAY ARRAY['Иванов И.И.', 'Петров П.П.'] LOOP
        INSERT INTO meteo_plpgsql.users (full_name, position_id)
        VALUES (person_name, CASE WHEN person_name = 'Иванов И.И.' THEN 1 ELSE 2 END)
        RETURNING id INTO staff_id;
        INSERT INTO meteo_plpgsql.batches (user_id, equipment_type_id)
        VALUES (staff_id, CASE WHEN person_name = 'Иванов И.И.' THEN 1 ELSE 2 END)
        RETURNING id INTO batch_id_new;
        INSERT INTO meteo_plpgsql.parameters (batch_id, parameter_type_id, value, measurement_date)
        VALUES (batch_id_new,1,100,DATE '2026-10-01'),
               (batch_id_new,2,23,DATE '2026-10-01'),
               (batch_id_new,3,6,DATE '2026-10-01'),
               (batch_id_new,4,45,DATE '2026-10-01'),
               (batch_id_new,5,65,DATE '2026-10-01');
    END LOOP;
    INSERT INTO meteo_plpgsql.temperature_corrections
        (source_label, temperature_from, temperature_to, correction)
    VALUES ('Ниже 0',NULL,0,0), ('0 - 5',0,5,0.5), ('10 - 15',10,15,1),
           ('20',20,20,1.5), ('25',25,25,2), ('30',30,30,3.5), ('40',40,40,4.5);
END;
$data$;
COMMIT;
BEGIN;
DO $constraints$
DECLARE
    table_name_new TEXT;
    item RECORD;
BEGIN
    FOREACH table_name_new IN ARRAY ARRAY['positions','equipment_types','users','batches',
        'base_units','measurement_units','measurement_unit_components','parameter_types',
        'parameters','temperature_corrections'] LOOP
        EXECUTE format('ALTER TABLE meteo_plpgsql.%I ADD PRIMARY KEY (id)', table_name_new);
    END LOOP;
    FOR item IN SELECT * FROM (VALUES
        ('positions','name'), ('equipment_types','name'), ('users','full_name'), ('users','position_id'),
        ('batches','user_id'), ('batches','equipment_type_id'), ('base_units','name'), ('base_units','symbol'),
        ('measurement_units','name'), ('measurement_units','symbol'),
        ('measurement_unit_components','measurement_unit_id'), ('measurement_unit_components','base_unit_id'),
        ('measurement_unit_components','power'), ('parameter_types','name'), ('parameter_types','measurement_unit_id'),
        ('parameters','batch_id'), ('parameters','parameter_type_id'), ('parameters','value'), ('parameters','measurement_date'),
        ('temperature_corrections','source_label'), ('temperature_corrections','temperature_to'),
        ('temperature_corrections','correction')
    ) AS required(table_name, column_name) LOOP
        EXECUTE format('ALTER TABLE meteo_plpgsql.%I ALTER COLUMN %I SET NOT NULL', item.table_name, item.column_name);
    END LOOP;
    FOR item IN SELECT * FROM (VALUES
        ('users','position_id','positions'), ('batches','user_id','users'),
        ('batches','equipment_type_id','equipment_types'),
        ('measurement_unit_components','measurement_unit_id','measurement_units'),
        ('measurement_unit_components','base_unit_id','base_units'),
        ('parameter_types','measurement_unit_id','measurement_units'),
        ('parameters','batch_id','batches'), ('parameters','parameter_type_id','parameter_types')
    ) AS relations(table_name, column_name, target_name) LOOP
        EXECUTE format('ALTER TABLE meteo_plpgsql.%I ADD FOREIGN KEY (%I) REFERENCES meteo_plpgsql.%I(id)',
            item.table_name, item.column_name, item.target_name);
    END LOOP;
    ALTER TABLE meteo_plpgsql.measurement_unit_components ADD UNIQUE (measurement_unit_id, base_unit_id);
    ALTER TABLE meteo_plpgsql.parameters ADD UNIQUE (batch_id, parameter_type_id);
    ALTER TABLE meteo_plpgsql.temperature_corrections ADD UNIQUE (source_label);
    ALTER TABLE meteo_plpgsql.temperature_corrections ADD CHECK (temperature_from IS NULL OR temperature_from <= temperature_to);
    ALTER TABLE meteo_plpgsql.temperature_corrections ADD CHECK (correction >= 0);
END;
$constraints$;
COMMIT;

SELECT
    id AS "Код",
    source_label AS "Температура воздуха, °C",
    temperature_from AS "Нижняя граница, °C",
    temperature_to AS "Верхняя граница, °C",
    correction AS "Виртуальная поправка, °C"
FROM meteo_plpgsql.temperature_corrections
ORDER BY id;
