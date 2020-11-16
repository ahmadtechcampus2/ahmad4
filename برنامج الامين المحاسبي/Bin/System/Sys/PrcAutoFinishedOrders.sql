################################################################
CREATE PROCEDURE prcAutoFinishedOrders
AS
	SELECT 
		bu.Guid      AS OrderGuid,  
		SUM(bi.Qty)  AS OrderQty 
	INTO #OrderedQtys 
	FROM   
		bt000 AS bt
		INNER JOIN bu000  AS bu  ON bt.GUID = bu.TypeGUID
		INNER JOIN bi000  AS bi  ON bi.ParentGuid = bu.Guid
	WHERE bt.Type IN (5, 6)
	GROUP BY bu.Guid 
	----------------------------------------------------- 
	SELECT 
		bu.GUID   AS OrderGuid, 
		ISNULL((SELECT SUM(ISNULL(ORI.Qty, 0))					
				FROM ori000 ORI
				WHERE ORI.POGuid = bu.GUID AND ORI.TypeGuid = (SELECT TOP 1 OIT.Guid 
															   FROM oit000 OIT INNER JOIN oitvs000 OITVS ON OIT.Guid = OITVS.ParentGuid 
															   WHERE OITVS.OtGuid = bt.GUID AND OITVS.Selected = 1 ORDER BY OITVS.StateOrder DESC
															   )
		), 0) AS AchievedQty 
	INTO #AchievedOrders 
	FROM  
		bt000 AS bt
		INNER JOIN bu000  AS bu  ON bt.GUID = bu.TypeGUID
	WHERE bt.Type IN (5, 6)
	------------------------------------------------------ 
	UPDATE OrAddInfo000 
		SET Finished = 1 
		WHERE ParentGuid IN (SELECT oq.OrderGuid  
							 FROM #OrderedQtys AS oq INNER JOIN #AchievedOrders AS ao  
								  ON oq.OrderGuid = ao.OrderGuid AND ao.AchievedQty = oq.OrderQty)
			  AND (Finished = 0)
################################################################