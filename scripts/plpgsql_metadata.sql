-- Таблицы, последовательности и ограничения новой схемы.
SELECT ROW_NUMBER() OVER (ORDER BY object_type, object_name) AS "№",
       object_name AS "Наименование", object_type AS "Тип"
FROM (
    SELECT table_name AS object_name, 'Таблица' AS object_type
    FROM information_schema.tables
    WHERE table_schema = 'meteo_plpgsql' AND table_type = 'BASE TABLE'
    UNION ALL
    SELECT sequence_name, 'Последовательность'
    FROM information_schema.sequences WHERE sequence_schema = 'meteo_plpgsql'
    UNION ALL
    SELECT table_name || '.' || constraint_name,
           CASE constraint_type WHEN 'PRIMARY KEY' THEN 'Первичный ключ'
               WHEN 'FOREIGN KEY' THEN 'Внешний ключ' WHEN 'UNIQUE' THEN 'Уникальность'
               ELSE 'Проверка' END
    FROM information_schema.table_constraints WHERE constraint_schema = 'meteo_plpgsql'
) metadata
ORDER BY object_type, object_name;
