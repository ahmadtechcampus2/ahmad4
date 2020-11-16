###################################
Create View vwPrintQueue
AS
	SELECT 
		[PQ].[OrderID],
		[Sequence],
		[Tables].[Code] AS TableCode,
		[Orders].[OrderID]	AS OrderNumber
	FROM PrintQueue000 PQ
	LEFT JOIN Or000 Orders ON PQ.OrderID = Orders.Guid
	LEFT JOIN Tb000 Tables ON Orders.TableGuid = Tables.Guid
###################################
#END	