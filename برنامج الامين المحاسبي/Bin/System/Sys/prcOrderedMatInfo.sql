################################################################
CREATE PROCEDURE prcOrderedMatInfo
	@MatGuid	UNIQUEIDENTIFIER = 0x0 
	-- 1: Unit1, 2: Unit2, 3: Unit3, else: Default Unit
	,@Unit		INT = 1 
AS
BEGIN 
	SET NOCOUNT ON;
	
	IF @MatGuid = 0x0 
	BEGIN
		RETURN;
	END
	
	SELECT 
		StoreGUID,
		st.Name AS StoreName,
		StockBeforeSatisfyingOrders AS Stock,
		PurchaseOrdered AS InOrderedQty,
		PurchaseAchieved AS InAchievedQty,
		PurchaseOrderRemainder AS InRemainedQty,
		SellOrdered AS OutOrderedQty,
		SellAchieved AS OutAchievedQty,
		SellOrderRemainder AS OutRemainedQty,
		(ISNULL(PurchaseOrderRemainder, 0)
				- ISNULL(SellOrderRemainder, 0)
		) AS [Difference],
		StockAfterSatisfyingOrders AS StockAfter
	FROM
		(
		SELECT     
			mt.[GUID] AS mtGuid,
			ISNULL(sello.StoreGUID, ISNULL(puro.StoreGUID, 0x0)) StoreGUID,
			ISNULL(sello.Ordered, 0) AS SellOrdered,
			ISNULL(puro.Ordered, 0) AS PurchaseOrdered,
			ISNULL(sello.Achieved, 0) AS SellAchieved,
			ISNULL(puro.Achieved, 0) AS PurchaseAchieved,
			ISNULL(sello.SellToBeAchieved, 0) AS SellOrderRemainder, 
			ISNULL(puro.PurchaseToBeAchieved, 0) AS PurchaseOrderRemainder, 
			ISNULL(stock.StockQty, 0) AS StockBeforeSatisfyingOrders,
			((ISNULL(puro.PurchaseToBeAchieved, 0)
				- ISNULL(sello.SellToBeAchieved, 0) ) 
				+ ISNULL(stock.StockQty, 0)) AS StockAfterSatisfyingOrders 
		FROM         
			dbo.vbMt AS mt 
			INNER JOIN
				dbo.vbGr AS gr ON mt.GroupGUID = gr.[GUID] --?? is it necessary??
			LEFT JOIN (
				-- sell order
				SELECT 
					MatGuid, 
					MatName,
					StoreGuid,
					st.Name AS StoreName,
					Sum(ISNULL(OrderedQtySum, 0)) Ordered, 
					Sum(ISNULL(achievedQty, 0))  Achieved, 
					Sum(ISNULL(OrderedQtySum, 0)) - Sum(ISNULL(achievedQty, 0)) SellToBeAchieved
				FROM 
				( 
					SELECT
						mt.[mtGUID] AS MatGuid,
						mt.[mtName] AS MatName,
						st.[stGUID] AS StoreGuid,
						0 AS OrderedQtySum,
						0 AS achievedQty
					FROM
						vwMt mt
						CROSS JOIN
						vwSt st
					WHERE
						mt.[mtGUID] = @MatGuid
					UNION ALL
					SELECT 
						bi.biMatPtr AS MatGuid, 
						bi.mtName AS MatName,
						bi.biStorePtr AS StoreGUID,
						(bi.biQty
							/ (	CASE @Unit
									WHEN 1 THEN 1
									WHEN 2 THEN (CASE WHEN bi.mtUnit2Fact <> 0 THEN bi.mtUnit2Fact ELSE 1 END)
									WHEN 3 THEN (CASE WHEN bi.mtUnit3Fact <> 0 THEN bi.mtUnit3Fact ELSE 1 END)
									ELSE (CASE WHEN bi.mtDefUnitFact <> 0 THEN bi.mtDefUnitFact ELSE 1 END)
								END)
						) AS OrderedQtySum, 
						0 AS achievedQty 
					FROM 
						vwExtended_bi bi 
						-- no need to join with ori000 to know ordered quantity
					WHERE 
						buGUID IN 
							(SELECT bu.[GUID] FROM bu000 bu 
								INNER JOIN oraddinfo000 info ON bu.[guid] = info.[ParentGuid] 
							WHERE bu.TypeGuid IN (SELECT [GUID] FROM bt000 WHERE [TYPE] = 5)
								AND finished <> 1 AND add1 <> 1 
							)
						AND
							bi.biMatPtr = @MatGuid 
					UNION ALL
					SELECT 
						vbi.biMatPtr AS MatGuid ,
						vbi.mtName AS MatName,
						vbi.biStorePtr AS StoreGUID,
						0 AS OrderedQtySum, 
						(ori.Qty
							/ (	CASE @Unit
									WHEN 1 THEN 1
									WHEN 2 THEN (CASE WHEN vbi.mtUnit2Fact <> 0 THEN vbi.mtUnit2Fact ELSE 1 END)
									WHEN 3 THEN (CASE WHEN vbi.mtUnit3Fact <> 0 THEN vbi.mtUnit3Fact ELSE 1 END)
									ELSE (CASE WHEN vbi.mtDefUnitFact <> 0 THEN vbi.mtDefUnitFact ELSE 1 END)
								END)
						) AS AchievedQtySum 
					FROM ori000 ori
						INNER JOIN 
							(SELECT bu.[GUID] FROM bu000 bu 
								INNER JOIN oraddinfo000 info ON bu.[guid] = info.[ParentGuid] 
							WHERE bu.TypeGuid IN (SELECT [GUID] FROM bt000 WHERE [TYPE] = 5)
								AND finished <> 1 AND add1 <> 1 
							) bu ON bu.[GUID] = ori.POGUID
						INNER JOIN 
							vwExtended_bi vbi ON vbi.biGUID = ori.POIGUID
					WHERE 
						ori.BuGuid <> 0x0
						AND 
						TypeGuid  IN (SELECT [GUID] FROM oit000 WHERE operation = 1)
				) xyz
					INNER JOIN st000 st ON xyz.StoreGuid = st.[GUID]
				WHERE
					MatGuid = @MatGuid 
				GROUP BY 
					MatGuid
					,MatName
					,StoreGUID
					,st.[Name]
			) sello ON sello.MatGuid = mt.[GUID]
			LEFT JOIN (
				-- purchase orders
				SELECT 
					MatGuid, 
					MatName,
					StoreGUID,
					st.Name AS StoreName,
					Sum(ISNULL(OrderedQtySum, 0)) Ordered, 
					Sum(IsNull(achievedQty, 0))  Achieved, 
					Sum(ISNULL(OrderedQtySum, 0)) - Sum(IsNull(achievedQty, 0)) PurchaseToBeAchieved
				FROM 
				( 
					SELECT
						mt.[mtGUID] AS MatGuid,
						mt.[mtName] AS MatName,
						st.[stGUID] AS StoreGuid,
						0 AS OrderedQtySum,
						0 AS achievedQty
					FROM
						vwMt mt
						CROSS JOIN
						vwSt st
					WHERE
						mt.[mtGUID] = @MatGuid
					UNION ALL
					SELECT 
						bi.biMatPtr AS MatGuid, 
						bi.mtName AS MatName,
						bi.biStorePtr AS StoreGUID,
						(bi.biQty
							/ (	CASE @Unit
									WHEN 1 THEN 1
									WHEN 2 THEN (CASE WHEN bi.mtUnit2Fact <> 0 THEN bi.mtUnit2Fact ELSE 1 END)
									WHEN 3 THEN (CASE WHEN bi.mtUnit3Fact <> 0 THEN bi.mtUnit3Fact ELSE 1 END)
									ELSE (CASE WHEN bi.mtDefUnitFact <> 0 THEN bi.mtDefUnitFact ELSE 1 END)
								END)
						) AS OrderedQtySum, 
						0 AS achievedQty 
					FROM vwExtended_Bi bi 
						-- no need to join with ori000 to know ordered quantity
						WHERE buGUID IN 
							(SELECT bu.[GUID] FROM bu000 bu 
								INNER JOIN oraddinfo000 info ON bu.[guid] = info.[ParentGuid] 
							WHERE bu.TypeGuid IN (SELECT [GUID] FROM bt000 WHERE [TYPE] = 6)
								AND finished <> 1 AND add1 <> 1
							)
						AND
						bi.biMatPtr = @MatGuid 
					
					UNION ALL
					SELECT 
						vbi.biMatPtr AS MatGuid ,
						vbi.mtName AS MatName,
						vbi.biStorePtr AS StoreGUID,
						0 AS OrderedQtySum, 
						(ori.Qty
							/ (	CASE @Unit
									WHEN 1 THEN 1
									WHEN 2 THEN (CASE WHEN vbi.mtUnit2Fact <> 0 THEN vbi.mtUnit2Fact ELSE 1 END)
									WHEN 3 THEN (CASE WHEN vbi.mtUnit3Fact <> 0 THEN vbi.mtUnit3Fact ELSE 1 END)
									ELSE (CASE WHEN vbi.mtDefUnitFact <> 0 THEN vbi.mtDefUnitFact ELSE 1 END)
								END)
						) AS AchievedQtySum 
					FROM ori000 ori
						INNER JOIN 
							(SELECT bu.[GUID] FROM bu000 bu 
								INNER JOIN oraddinfo000 info ON bu.[guid] = info.[ParentGuid] 
							WHERE bu.TypeGuid IN (SELECT [GUID] FROM bt000 WHERE [TYPE] = 6)
								AND finished <> 1 AND add1 <> 1
							) bu ON bu.[GUID] = ori.POGUID
						INNER JOIN 
							vwExtended_bi vbi ON vbi.biGUID = ori.POIGUID
					WHERE 
						ori.BuGuid <> 0x0
						AND 
							TypeGuid  IN (SELECT [GUID] FROM oit000 WHERE operation = 1)
						AND 
							vbi.biMatPtr = @MatGuid
				) xyz
					INNER JOIN 
						st000 st ON xyz.StoreGUID = st.[GUID]
				GROUP BY 
					MatGuid
					,MatName
					,StoreGUID
					,st.Name
			) puro ON puro.MatGuid = mt.[GUID] AND sello.StoreGuid = puro.StoreGuid
			Left Join
			(
				-- المخزون
				SELECT 
					xuz.MatGuid, 
					xuz.MatName,
					xuz.StoreGuid,
					xuz.StoreName,
					SUM(ISNULL(inQty, 0)) - SUM(ISNULL(outQty, 0)) AS StockQty
				FROM 	  
				(
					SELECT
						mt.[mtGUID] AS MatGuid,
						mt.[mtName] AS MatName,
						st.[stGUID] AS StoreGuid,
						st.[stName] AS StoreName,
						0 AS inQty,
						0 AS outQty
					FROM
						vwMt mt
						CROSS JOIN
						vwSt st
					WHERE
						mt.[mtGUID] = @MatGuid
						
					UNION ALL
					--// Compute the input bills stock
					SELECT  
						mt.mtGUID AS MatGuid, 
						mt.mtName AS MatName,
						bi.biStorePtr AS StoreGuid,
						st.[stName] AS StoreName,
						(SUM(
						bi.biQty
							/ (	CASE @Unit
								WHEN 1 THEN 1
								WHEN 2 THEN (CASE WHEN bi.mtUnit2Fact <> 0 THEN bi.mtUnit2Fact ELSE 1 END)
								WHEN 3 THEN (CASE WHEN bi.mtUnit3Fact <> 0 THEN bi.mtUnit3Fact ELSE 1 END)
								ELSE (CASE WHEN bi.mtDefUnitFact <> 0 THEN bi.mtDefUnitFact ELSE 1 END)
							END)
						) 
						+ 
						SUM(
						bi.biBonusQnt
							/ (	CASE @Unit
								WHEN 1 THEN 1
								WHEN 2 THEN (CASE WHEN bi.mtUnit2Fact <> 0 THEN bi.mtUnit2Fact ELSE 1 END)
								WHEN 3 THEN (CASE WHEN bi.mtUnit3Fact <> 0 THEN bi.mtUnit3Fact ELSE 1 END)
								ELSE (CASE WHEN bi.mtDefUnitFact <> 0 THEN bi.mtDefUnitFact ELSE 1 END)
							END)
						)) 
						AS inQty, 
						0 AS outQty
					FROM 
						vwMt AS mt
						RIGHT JOIN 
							vwExtended_Bi AS bi ON (bi.biMatPtr = mt.[mtGUID]) 
						LEFT JOIN 
							vwSt AS st ON bi.biStorePtr = st.[stGUID]
					WHERE
						(bi.btIsInput = 1)  
						AND (bi.[btType] NOT IN (5, 6)) 
						AND (bi.[buIsPosted] = 1)
					GROUP BY
						mt.mtGUID
						,mt.mtName
						,biStorePtr
						,stName
					
					UNION ALL
					SELECT
						mt.[GUID] AS MatGuid, 
						mt.Name,
						0x0 AS StoreGuid,
						'' AS StoreName,
						0 AS inQty,
						0 AS outQty
					FROM
						mt000 mt
					WHERE
						mt.[GUID] NOT IN (
							SELECT DISTINCT biMatPtr FROM vwExtended_bi
						)
					---------------------------------------------------------------------------------------     
					UNION ALL
					-- // Compute the output bills stock
					SELECT  
						mt.mtGUID AS MatGuid,
						mt.mtName AS MatName,
						ISNULL(bi.biStorePtr, 0x0) AS StoreGuid,
						ISNULL(st.[stName], '') AS StoreName,
						0 AS inQty,
						(SUM(
						ISNULL(bi.biQty, 0)
							/ (	CASE @Unit
								WHEN 1 THEN 1
								WHEN 2 THEN (CASE WHEN bi.mtUnit2Fact <> 0 THEN bi.mtUnit2Fact ELSE 1 END)
								WHEN 3 THEN (CASE WHEN bi.mtUnit3Fact <> 0 THEN bi.mtUnit3Fact ELSE 1 END)
								ELSE (CASE WHEN bi.mtDefUnitFact <> 0 THEN bi.mtDefUnitFact ELSE 1 END)
							END)
						) 
						+ 
						SUM(
						ISNULL(bi.biBonusQnt, 0)
							/ (	CASE @Unit
								WHEN 1 THEN 1
								WHEN 2 THEN (CASE WHEN bi.mtUnit2Fact <> 0 THEN bi.mtUnit2Fact ELSE 1 END)
								WHEN 3 THEN (CASE WHEN bi.mtUnit3Fact <> 0 THEN bi.mtUnit3Fact ELSE 1 END)
								ELSE (CASE WHEN bi.mtDefUnitFact <> 0 THEN bi.mtDefUnitFact ELSE 1 END)
							END)
						)) 
						AS outQty
					FROM 
						vwMt AS mt
						RIGHT JOIN 
							vwExtended_Bi AS bi ON (bi.biMatPtr = mt.[mtGUID]) 
						
						LEFT JOIN 
							vwSt AS st ON bi.biStorePtr = st.[stGUID]
					WHERE
						(bi.btIsInput = 0)  
						AND (bi.[btType] NOT IN (5, 6)) 
						AND (bi.[buIsPosted] = 1)
					GROUP BY
						mt.mtGUID
						,mt.mtName
						,biStorePtr
						,stName
					---------------------------------------------------------------------------------------
					UNION ALL
					-- Get Non ordered materials
					SELECT
						mt.[GUID] AS MatGuid, 
						mt.Name,
						0x0 AS StoreGuid,
						'' AS StoreName,
						0 AS inQty,
						0 AS outQty
					FROM
						mt000 mt
					WHERE
						mt.[GUID] NOT IN (
							SELECT DISTINCT biMatPtr FROM vwExtended_bi
						)
				) xuz
				WHERE
					xuz.MatGuid = @MatGuid
				GROUP BY 
					xuz.MatGuid,
					xuz.MatName,
					xuz.StoreGuid,
					xuz.StoreName
			) stock ON stock.MatGuid = mt.[GUID] AND stock.StoreGuid = puro.StoreGuid
		WHERE
			(MT.[GUID] = @MatGuid) OR (@MatGuid = 0x0)
		) main
	INNER JOIN st000 st ON main.StoreGUID = st.[GUID]
END
################################################################
#END