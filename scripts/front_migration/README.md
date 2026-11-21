# Перенос ресурсов Front

Подготовил скрипты переноса закупок, продаж, аудита персонала и складских движений из MSSQL в PostgreSQL.

- [Структура OLAP](01_structure.sql)
- [Выборки из MSSQL](02_extract.sql)
- [Вставка данных в PostgreSQL](03_load.sql)
- [Справочник времени](04_time.sql)

В PostgreSQL сначала выполняются `01_structure.sql` и `04_time.sql`, затем `03_load.sql`.
