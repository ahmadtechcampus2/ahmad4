#########################################################################
CREATE FUNCTION fnGetOrdersRemainderAndStockQty(
	@StartDate	DATE = '1/1/1980'
	,@EndDate	DATE = '12/31/2079'
)
RETURNS TABLE
AS
RETURN
(
SELECT     
	mt.[GUID] AS mtGuid,
	ISNULL(sello.Remainder, 0) AS SellOrderRemainder, 
	ISNULL(puro.Remainder, 0) AS PurchaseOrderRemainder, 
	ISNULL(stock.StockQty, 0) AS StockBeforeSatisfyingOrders,
	((ISNULL(puro.Remainder, 0)
		- ISNULL(sello.Remainder, 0) ) 
		+ ISNULL(stock.StockQty, 0)) AS StockAfterSatisfyingOrders 
FROM         
	dbo.vbMt AS mt 
	INNER JOIN
		dbo.vbGr AS gr ON mt.GroupGUID = gr.[GUID]
	LEFT JOIN (
		-- sell order
		SELECT 
			*
		FROM
			fnGetOrderedRemainder(@StartDate, @EndDate, 5, 0)
	) sello ON sello.mtGuid = mt.[GUID]
	LEFT JOIN (
		-- purchase orders
		SELECT 
			*
		FROM
			fnGetOrderedRemainder(@StartDate, @EndDate, 6, 0)
	) puro ON puro.mtGuid = mt.[GUID]
	LEFT JOIN
	(
		-- المخزون
		SELECT 
			xuz.mtGuid, 
			SUM(ISNULL(inQty, 0)) - SUM(ISNULL(outQty, 0)) AS StockQty
		FROM 	  
		(
			SELECT mt.[GUID] AS mtGuid, ISNULL(bb.Qty, 0) AS inQty , 0 AS outQty
			FROM 
				vbMt AS mt 
			LEFT JOIN  
				(SELECT  
					bi.MatGuid,  
					(SUM(bi.Qty) + SUM(bi.BonusQnt)) AS Qty      
				FROM		   bi000     AS bi 
					INNER JOIN bu000     AS bu ON bi.ParentGuid = bu.[GUID]     
					INNER JOIN bt000     AS bt ON bu.TypeGuid   = bt.[GUID]  
					   
				WHERE     
					(bt.bIsInput = 1)  
					AND (bt.[Type] NOT IN (5, 6)) 
					AND (bu.[IsPosted] = 1) 
				GROUP BY     
					bi.MatGuid   
				) AS bb ON bb.MatGuid = mt.[GUID] 
			-----------------------------------------------------------------------------------------     
			UNION ALL
			SELECT mt.[GUID], 0 AS inQty, ISNULL(bb.Qty, 0) AS outQty 
			FROM 
				mt000 AS mt 
			LEFT JOIN  
				(SELECT bi.MatGuid, (SUM(bi.Qty) + SUM(bi.BonusQnt)) AS Qty        
				FROM		   bi000     AS bi 
					INNER JOIN bu000     AS bu ON bi.ParentGuid = bu.[GUID]     
					INNER JOIN bt000     AS bt ON bu.TypeGuid   = bt.[GUID]    
				WHERE     
					(bt.bIsInput = 0)  
					AND (bt.Type NOT IN (5, 6)) 
					AND (bu.[IsPosted] = 1) 
				GROUP BY
					bi.MatGuid 
				) AS bb ON bb.MatGuid = mt.[GUID] 
		) xuz
		GROUP BY xuz.mtGuid
	) stock ON stock.mtGuid = mt.[GUID]
)
#########################################################################
#END