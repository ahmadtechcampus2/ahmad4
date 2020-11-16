################################################################
CREATE PROCEDURE prcFixOriTable
AS
	SELECT DISTINCT
		ORI1.GUID     AS OriGuid1,
		ORI2.GUID     AS OriGuid2,
		ORI1.POIGuid  AS ItemGuid,
		ORI1.Date     AS DeportationDate,  
		ORI2.Qty      AS DeportedQty,  
		ORI1.TypeGuid AS SrcState,  
		ORI2.TypeGuid AS DestState,
		oit.Operation AS Operation,
		ORI1.BuGuid   AS BuGuid,
		ORI1.bIsRecycled  
	INTO #PostTbl
	FROM  
		 		   ori000 AS ORI1   
		INNER JOIN ori000 AS ORI2 ON ORI1.POIGuid = ORI2.POIGuid
		INNER JOIN oit000 as oit  on oit.GUID = ORI2.TypeGuid
	WHERE  
		    (ORI1.Qty  = 0 - ORI2.Qty)   
		AND (ORI2.Qty  > 0)              
		AND (ORI1.Date = ORI2.Date)  
		AND (ORI1.Number = ORI2.Number - 1) 
		AND (ORI1.Number <> 0)  
		AND (ORI2.Number <> 0) 
		 
	delete from ori000 where guid in 
	( 
		select OriGuid1 
		from #PostTbl pt
		where 
			(pt.bIsRecycled <> 1)
			AND
			(
				(pt.buguid != 0x0 and pt.buguid not in (select guid from bu000) and (pt.operation = 1 or pt.operation = 2)) 
			)
	
		union 
	
		select OriGuid2 
		from #PostTbl pt
		where 
			(pt.bIsRecycled <> 1)
			AND
			(				
				(pt.buguid != 0x0 and pt.buguid not in (select guid from bu000) and (pt.operation = 1 or pt.operation = 2)) 
			)
	) 
	 
	if (dbo.fnObjectExists('mn000') = 1)
		delete from ori000 where guid in 
		(
			select OriGuid1 
			from #PostTbl pt
			where 
				(pt.bIsRecycled <> 1)
				AND
				(				
					(pt.buguid != 0x0 and pt.buguid not in (select guid from MN000) and pt.operation = 3) 
					or 
					(pt.BuGuid = 0x0 and pt.operation = 3)
				)
			
			union
		
			select OriGuid2 
			from #PostTbl pt
			where 
				(pt.bIsRecycled <> 1)
				AND
				(				
					(pt.buguid != 0x0 and pt.buguid not in (select guid from MN000) and pt.operation = 3) 
					or 
					(pt.BuGuid = 0x0 and pt.operation = 3)
				)
		)
		
	delete from ori000 
	where buguid != 0x0 
		  and buguid not in (select guid from bu000)
		  and buguid not in (select guid from MN000)
		  and bIsRecycled <> 1
		  
	delete from ori000
	where 
		guid not in (select OriGuid1 from #PostTbl) 
		and 
		guid not in (select OriGuid2 from #PostTbl) 
		and 
		Number != 0	
################################################################
CREATE PROCEDURE prcFixAutoFinishedOrders
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
		SET Finished = 0 
		WHERE ParentGuid IN (SELECT oq.OrderGuid  
							 FROM #OrderedQtys AS oq INNER JOIN #AchievedOrders AS ao  
								  ON oq.OrderGuid = ao.OrderGuid AND ao.AchievedQty < oq.OrderQty)
			  AND (Finished != 0)
################################################################	
CREATE PROCEDURE prcMaintainOrders
	@chks INT = 0
AS
	if (@chks & 1 = 1)
		EXEC prcFixOriTable
	
	if (@chks & 2 = 2)
		EXEC prcFixAutoFinishedOrders	 		
################################################################	
CREATE PROCEDURE prcFixOrderOri
	@OrderGUID UNIQUEIDENTIFIER
AS
	DELETE O 
	FROM ori000 AS O
	WHERE 
		POGUID = @OrderGUID
		AND buGUID != 0x0 
		AND NOT EXISTS(SELECT 1 FROM bu000 WHERE GUID = O.buGUID)
		AND NOT EXISTS(SELECT 1 FROM MN000 WHERE GUID = O.buGUID)
################################################################		
#END