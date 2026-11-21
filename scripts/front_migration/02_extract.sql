USE [Front];
SET NOCOUNT ON;

DECLARE @start  date = '20231101';
DECLARE @finish date = '20231201';

-- dim_products
WITH used_products AS (
    SELECT o.ProductID AS product_id
    FROM dbo.bm_StorageOperations AS o
    JOIN dbo.bm_JournalBarnetDocs AS d ON d.ID = o.DocumentID
    WHERE d.IsUse = 1 AND o.OperationID IN (1, 2)

    UNION

    SELECT p.id
    FROM dbo.journal AS j
    JOIN dbo.product AS p ON p.productid = j.id
    WHERE j.transtype = 101 AND j.receiptn <> 0
      AND j.id NOT IN ('888880', '888881')
)
SELECT p.id AS external_id, p.productid AS product_code, p.description AS name
FROM dbo.product AS p
JOIN used_products AS u ON u.product_id = p.id;

-- dim_ranges
SELECT id AS external_id, sizeid AS name, portionrate AS factor
FROM dbo.size;

-- dim_vendors
SELECT id AS external_id, firstname AS name
FROM dbo.vendors;

-- dim_transtypes
SELECT transtypeid AS external_id, description AS name
FROM dbo.transtype;

-- dim_personals
SELECT personid AS external_id, lastname, firstname
FROM dbo.personnel;

-- dim_storages
SELECT id AS external_id, description AS name
FROM dbo.storages;

-- fact_purchases
SELECT o.ID AS source_id, d.ID AS document_id, d.Period AS operation_date,
       YEAR(d.Period) * 100 + MONTH(d.Period) AS time_id,
       o.ProductID AS product_id, o.VendorID AS vendor_id, o.RangeID AS range_id,
       o.[Count] AS quantity, o.Price AS unit_price, o.Amount AS amount
FROM dbo.bm_StorageOperations AS o
JOIN dbo.bm_JournalBarnetDocs AS d ON d.ID = o.DocumentID
WHERE d.Period >= @start AND d.Period < @finish
  AND d.IsUse = 1 AND d.DocumentTypeID = 4 AND o.OperationID = 1;

-- fact_sales
SELECT j.transnumber AS source_id, j.receiptn AS receipt_id, j.dater AS operation_date,
       YEAR(j.dater) * 100 + MONTH(j.dater) AS time_id,
       p.id AS product_id, j.transtype AS transtype_id, j.quantity, j.amount
FROM dbo.journal AS j
JOIN dbo.product AS p ON p.productid = j.id
WHERE j.dater >= @start AND j.dater < @finish
  AND j.transtype = 101 AND j.receiptn <> 0
  AND j.id NOT IN ('888880', '888881');

-- fact_personnel_audit
SELECT s.ID AS source_id, s.DateAdd AS operation_date,
       YEAR(s.DateAdd) * 100 + MONTH(s.DateAdd) AS time_id,
       p.personid AS person_id, s.[Type] AS event_type, s.IsError AS is_error
FROM dbo.bm_JournalSessions AS s
JOIN dbo.personnel AS p ON p.personid = s.PersonID
WHERE s.DateAdd >= @start AND s.DateAdd < @finish;

-- fact_stock_movements
SELECT o.ID AS source_id, d.ID AS document_id, d.Period AS operation_date,
       YEAR(d.Period) * 100 + MONTH(d.Period) AS time_id,
       o.ProductID AS product_id, o.StorageID AS storage_id, o.RangeID AS range_id,
       o.OperationID AS operation_type, o.[Count] AS quantity
FROM dbo.bm_StorageOperations AS o
JOIN dbo.bm_JournalBarnetDocs AS d ON d.ID = o.DocumentID
WHERE d.Period >= @start AND d.Period < @finish
  AND d.IsUse = 1 AND o.OperationID IN (1, 2);
