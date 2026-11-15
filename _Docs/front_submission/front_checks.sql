USE [Front];
SET NOCOUNT ON;

-- 1. Три товара в документе поступления 388238.
SELECT d.DocumentTypeID, p.description, o.[Count], o.Price, o.Amount
FROM dbo.bm_StorageOperations AS o
JOIN dbo.bm_JournalBarnetDocs AS d ON d.ID = o.DocumentID
JOIN dbo.product AS p ON p.id = o.ProductID
WHERE d.ID = 388238
ORDER BY o.ID;

-- 2. Продажи пиццы 271363 за ноябрь 2023.
SELECT COUNT(*) AS sale_lines, SUM(quantity) AS quantity, SUM(amount) AS amount
FROM dbo.journal
WHERE id = '271363' AND transtype = 101 AND receiptn <> 0
  AND dater >= '20231101' AND dater < '20231201';

-- 3. Закупки у поставщика 107 за ноябрь 2023.
SELECT COUNT(DISTINCT d.ID) AS documents, COUNT(DISTINCT o.ProductID) AS products,
       SUM(o.Amount) AS purchase_amount
FROM dbo.bm_StorageOperations AS o
JOIN dbo.bm_JournalBarnetDocs AS d ON d.ID = o.DocumentID
WHERE o.VendorID = 107 AND o.OperationID = 1 AND d.DocumentTypeID = 4 AND d.IsUse = 1
  AND d.Period >= '20231101' AND d.Period < '20231201';

-- 4. Отметки сотрудника 1029. NULL в quarter_no означает итог за полугодие.
SELECT DATEPART(quarter, dater) AS quarter_no,
       COUNT(DISTINCT CAST(dater AS date)) AS days_with_events,
       SUM(CASE WHEN transtype = 386 THEN 1 ELSE 0 END) AS starts,
       SUM(CASE WHEN transtype = 387 THEN 1 ELSE 0 END) AS finishes
FROM dbo.journal
WHERE loginid = '1029' AND transtype IN (386, 387)
  AND dater >= '20230101' AND dater < '20230701'
GROUP BY ROLLUP (DATEPART(quarter, dater));

-- 5а. Движение булочки 4603796 на складе 41 за неделю.
SELECT SUM(CASE WHEN o.OperationID = 1 THEN o.[Count] ELSE 0 END) AS received,
       SUM(CASE WHEN o.OperationID = 2 THEN -o.[Count] ELSE 0 END) AS written_off,
       SUM(o.[Count]) AS net_change
FROM dbo.bm_StorageOperations AS o
JOIN dbo.bm_JournalBarnetDocs AS d ON d.ID = o.DocumentID
JOIN dbo.product AS p ON p.id = o.ProductID
WHERE p.productid = '4603796' AND o.StorageID = 41
  AND o.OperationID IN (1, 2) AND d.IsUse = 1
  AND d.Period >= '20231120' AND d.Period < '20231127'
GROUP BY o.RangeID;

-- 5б. Есть ли в таблицах остатков строки с кодом товара?
SELECT 'onhand' AS source_table, COUNT(*) AS total_rows,
       COUNT(NULLIF(LTRIM(RTRIM(productid)), '')) AS rows_with_product
FROM dbo.onhand
UNION ALL
SELECT 'storagesonhand', COUNT(*), COUNT(NULLIF(LTRIM(RTRIM(productid)), ''))
FROM dbo.storagesonhand
UNION ALL
SELECT 'stockperiod', COUNT(*), COUNT(NULLIF(LTRIM(RTRIM(productid)), ''))
FROM dbo.stockperiod;
