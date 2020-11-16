################################################################
CREATE PROCEDURE prcCopyOrder 
	@DestDBName	[NVARCHAR](255), 
	@RndText	[NVARCHAR](100)
AS   
	 
	EXECUTE prcNotSupportedInAzureYet
	/*
	DECLARE @MakeFast AS BIT 
	SET @MakeFast = 1 
	DECLARE @query  AS NVARCHAR(max) 
	DECLARE @insert AS NVARCHAR(1000) 
	DECLARE @where  AS NVARCHAR(1000) 
	DECLARE @upd AS NVARCHAR(1000)
	 
	SET @insert = 'INSERT INTO ' + @DestDBName + '..TargetTbl '+ 
				  'SELECT * '+ 
				  'FROM TargetTbl '+ 
				  'WHERE WhereCond' 
	-------------------------------------------------------------
	IF dbo.fnObjectExists('#AmnOrders_OrderedQtysNotFinishedNotCanceled') = 1
		DROP TABLE #AmnOrders_OrderedQtysNotFinishedNotCanceled
		
	SELECT   
		bt.Guid		 AS OrderTypeGuid,
		bu.Guid      AS OrderGuid,  
		SUM(bi.Qty)  AS OrderQty
	INTO #AmnOrders_OrderedQtysNotFinishedNotCanceled  
	FROM   
				   bt000  		AS bt  
		INNER JOIN bu000  		AS bu   ON bt.Guid = bu.TypeGuid
		INNER JOIN OrAddInfo000 AS info ON bu.Guid = info.ParentGuid
		INNER JOIN bi000  		AS bi   ON bi.ParentGuid = bu.Guid
	WHERE 
		bt.Type IN (5, 6) AND info.Finished = 0 AND info.Add1 = 0
	GROUP BY 
		bt.Guid,
		bu.Guid
	--------------------------------------------------------------------------------
	IF dbo.fnObjectExists('#AmnOrders_OrderedAcheivedQtysNotFinishedNotCanceled') = 1
		DROP TABLE #AmnOrders_OrderedAcheivedQtysNotFinishedNotCanceled
		
	SELECT      
		bu.OrderGuid, 
		bu.OrderQty,
		SUM(CASE dbo.fnIsFinalState(bu.OrderTypeGuid, ori.TypeGuid) WHEN 1 THEN ori.Qty ELSE 0 END) AS AchievedQty  
	INTO #AmnOrders_OrderedAcheivedQtysNotFinishedNotCanceled
	FROM  
		#AmnOrders_OrderedQtysNotFinishedNotCanceled bu
		INNER JOIN ori000  ori ON ori.POGUID = bu.OrderGuid 
	GROUP BY 
		bu.OrderGuid, 
		bu.OrderQty
	------------------------------------------------------	 
	-- «·ÿ·»Ì«  €Ì— «·„—’œ… Ê€Ì— „‰ ÂÌ… Ê €Ì— „·€Ì…
	IF dbo.fnObjectExists('##AmnOrders_OrdersToBeCopied') = 1
		DROP TABLE ##AmnOrders_OrdersToBeCopied
		
	SELECT OrderGuid
	INTO ##AmnOrders_OrdersToBeCopied
	FROM #AmnOrders_OrderedAcheivedQtysNotFinishedNotCanceled
	WHERE AchievedQty < OrderQty
	--------------------------------------------------------
	-- drop temp tables
	IF dbo.fnObjectExists('#AmnOrders_OrderedQtysNotFinishedNotCanceled') = 1
		DROP TABLE #AmnOrders_OrderedQtysNotFinishedNotCanceled
		
	IF dbo.fnObjectExists('#AmnOrders_OrderedAcheivedQtysNotFinishedNotCanceled') = 1
		DROP TABLE #AmnOrders_OrderedAcheivedQtysNotFinishedNotCanceled
	-------------------------------------------------------------
	-- bt000 
	-- oit000 
	-------------------------------------------------------- 
	-- oitvs000 
	SET @query = ' SELECT guid FROM ' + @DestDBName + '..oitvs000 '
	EXEC (@query)	
	IF @@ROWCOUNT = 0
	BEGIN
		IF (@MakeFast = 0) 
			EXEC prcCopyTbl @DestDBName, 'oitvs000', '1=1', 1, 0 
		ELSE  
		BEGIN 
			SET @query = @insert 
			SELECT @query = REPLACE(@query, 'TargetTbl', 'oitvs000') 
			SELECT @query = REPLACE(@query, 'WhereCond', '1=1') 
			EXEC (@query) 
		END 
	END
	-------------------------------------------------------- 
	-- omsg000 
	IF (@MakeFast = 0) 
		EXEC prcCopyTbl @DestDBName, 'omsg000', '1=1', 1, 0 
	ELSE 
		BEGIN 
			SET @query = @insert 
			SELECT @query = REPLACE(@query, 'TargetTbl', 'omsg000') 
			SELECT @query = REPLACE(@query, 'WhereCond', '1=1') 
			EXEC (@query) 
		END 
	-------------------------------------------------------- 
	DECLARE @OrdersSelect AS NVARCHAR(1000) 
	SET @OrdersSelect = ' SELECT OrderGuid FROM ##AmnOrders_OrdersToBeCopied ' 
	--------------------------------------------------------- 
	-- bu000 
	SET @where = 'Guid IN (' + @OrdersSelect + ')' 
	IF (@MakeFast = 0) 
		EXEC prcCopyTbl @DestDBName, 'bu000', @where, 1, 0	 
	ELSE 
		BEGIN 
			SET @query = @insert 
			SELECT @query = REPLACE(@query, 'TargetTbl', 'bu000') 
			SELECT @query = REPLACE(@query, 'WhereCond', @where) 
			EXEC (@query) 
		END	 
	---------------------------------------------------------- 
	-- OrAddInfo000 
	SET @where = 'ParentGuid IN (' + @OrdersSelect + ')'
	IF (@MakeFast = 0) 
		EXEC prcCopyTbl @DestDBName, 'OrAddInfo000', @where, 1, 0	 
	ELSE 
		BEGIN 
			SET @query = @insert 
			SELECT @query = REPLACE(@query, 'TargetTbl', 'OrAddInfo000') 
			SELECT @query = REPLACE(@query, 'WhereCond', @where) 
			EXEC (@query) 
		END	 
		
	SET @upd = 'UPDATE ' + @DestDBName + '..OrAddInfo000 SET Add2 = CAST(1 AS NVARCHAR(5))'
	EXEC (@upd)	
	----------------------------------------------------------- 
	-- bi000 
	SET @where = 'ParentGuid IN (' + @OrdersSelect + ')' 
	IF (@MakeFast = 0) 
		EXEC prcCopyTbl @DestDBName, 'bi000', @where, 1, 0		 
	ELSE 
		BEGIN 
			SET @query = @insert 
			SELECT @query = REPLACE(@query, 'TargetTbl', 'bi000') 
			SELECT @query = REPLACE(@query, 'WhereCond', @where) 
			EXEC (@query) 
		END	 
	----------------------------------------------------------- 
	-- ori000 
	SET @where = 'POGuid IN (' + @OrdersSelect + ')' 
	IF (@MakeFast = 0) 
		EXEC prcCopyTbl @DestDBName, 'ori000', @where, 1, 0		 
	ELSE 
		BEGIN 
			SET @query = @insert 
			SELECT @query = REPLACE(@query, 'TargetTbl', 'ori000') 
			SELECT @query = REPLACE(@query, 'WhereCond', @where) 
			EXEC (@query) 
		END	 
	
	SET @upd = 'UPDATE ' + @DestDBName + '..ori000 SET BuGuid = 0x0 '
	EXEC (@upd)	 
	
	SET @upd = 'UPDATE ' + @DestDBName + '..ori000 SET bIsRecycled = 1 '
	EXEC (@upd)	
	
	SET @upd = ' UPDATE ' + @DestDBName + '..ori000 SET Notes = ''' + @RndText + ''' + '' '' + bt.Name + '' : '' + CAST(bu.Number AS NVARCHAR(10)) '
			   +' FROM ori000 ori INNER JOIN bu000 bu on bu.GUID = ori.POGUID '
							  + ' INNER JOIN bt000 bt on bt.GUID = bu.TypeGUID '	
	EXEC (@upd)	
	----------------------------------------------------------- 
	-- orrel000 
	SET @where = '(OrGuid IN (' + @OrdersSelect + ')) AND (ParentGuid IN (' + @OrdersSelect + '))' 
	IF (@MakeFast = 0) 
		EXEC prcCopyTbl @DestDBName, 'orrel000', @where, 1, 0		 
	ELSE 
		BEGIN 
			SET @query = @insert 
			SELECT @query = REPLACE(@query, 'TargetTbl', 'orrel000') 
			SELECT @query = REPLACE(@query, 'WhereCond', @where) 
			EXEC (@query) 
		END	 
	----------------------------------------------------------- 
	-- ppo000 
	SET @where = '(POGuid IS NULL OR POGuid = 0x0) OR (POGuid IN (' + @OrdersSelect + '))' 
	IF (@MakeFast = 0) 
		EXEC prcCopyTbl @DestDBName, 'ppo000', @where, 1, 0		 
	ELSE 
		BEGIN 
			SET @query = @insert 
			SELECT @query = REPLACE(@query, 'TargetTbl', 'ppo000') 
			SELECT @query = REPLACE(@query, 'WhereCond', @where) 
			EXEC (@query) 
		END	 
	----------------------------------------------------------- 
	----------------------------------------------------------- 
	-- ppi000 
	SET @where = '((PPOGuid IN (SELECT Guid '+ 
	                           'FROM ppo000 '+ 
							   'WHERE (POGuid IS NULL OR POGuid=0x0) OR (POGuid IN (' + @OrdersSelect + ')))) '+ 
				   ' AND '+ 
				   '(SOGuid IN (' + @OrdersSelect + ')))' 
	IF (@MakeFast = 0) 
		EXEC prcCopyTbl @DestDBName, 'ppi000', @where, 1, 0	 
	ELSE 
		BEGIN 
			SET @query = @insert 
			SELECT @query = REPLACE(@query, 'TargetTbl', 'ppi000') 
			SELECT @query = REPLACE(@query, 'WhereCond', @where) 
			EXEC (@query) 
		END	 
	----------------------------------------------------------- 
	-------------------------------------------------------- 
	-- evc000 
	IF (@MakeFast = 0) 
		EXEC prcCopyTbl @DestDBName, 'evc000', '1=1', 1, 0 
	ELSE  
		BEGIN 
			SET @query = @insert 
			SELECT @query = REPLACE(@query, 'TargetTbl', 'evc000') 
			SELECT @query = REPLACE(@query, 'WhereCond', '1=1') 
			EXEC (@query) 
		END 
	-------------------------------------------------------- 
	-- evs000 
	IF (@MakeFast = 0) 
		EXEC prcCopyTbl @DestDBName, 'evs000', '1=1', 1, 0 
	ELSE  
		BEGIN 
			SET @query = @insert 
			SELECT @query = REPLACE(@query, 'TargetTbl', 'evs000') 
			SELECT @query = REPLACE(@query, 'WhereCond', '1=1') 
			EXEC (@query) 
		END 
	-------------------------------------------------------- 
	-- evsi000 
	IF (@MakeFast = 0) 
		EXEC prcCopyTbl @DestDBName, 'evsi000', '1=1', 1, 0 
	ELSE  
		BEGIN 
			SET @query = @insert 
			SELECT @query = REPLACE(@query, 'TargetTbl', 'evsi000') 
			SELECT @query = REPLACE(@query, 'WhereCond', '1=1') 
			EXEC (@query) 
		END 
	-------------------------------------------------------- 
	-- evm000 
	IF (@MakeFast = 0) 
		EXEC prcCopyTbl @DestDBName, 'evm000', '1=1', 1, 0	 
	ELSE 
		BEGIN 
			SET @query = @insert 
			SELECT @query = REPLACE(@query, 'TargetTbl', 'evm000') 
			SELECT @query = REPLACE(@query, 'WhereCond', '1=1') 
			EXEC (@query) 
		END	 
	-------------------------------------------------------- 
	-- evmi000 
	IF (@MakeFast = 0) 
		EXEC prcCopyTbl @DestDBName, 'evmi000', '1=1', 1, 0	 
	ELSE 
		BEGIN 
			SET @query = @insert 
			SELECT @query = REPLACE(@query, 'TargetTbl', 'evmi000') 
			SELECT @query = REPLACE(@query, 'WhereCond', '1=1') 
			EXEC (@query) 
		END	 
	-------------------------------------------------------- 
	-- OrDoc000 
	IF (@MakeFast = 0) 
		EXEC prcCopyTbl @DestDBName, 'OrDoc000', '1=1', 1, 0	 
	ELSE 
		BEGIN 
			SET @query = @insert 
			SELECT @query = REPLACE(@query, 'TargetTbl', 'OrDoc000') 
			SELECT @query = REPLACE(@query, 'WhereCond', '1=1') 
			EXEC (@query) 
		END	 
	-------------------------------------------------------- 
	-- OrDocVs000 
	IF (@MakeFast = 0) 
		EXEC prcCopyTbl @DestDBName, 'OrDocVs000', '1=1', 1, 0	 
	ELSE 
		BEGIN 
			SET @query = @insert 
			SELECT @query = REPLACE(@query, 'TargetTbl', 'OrDocVs000') 
			SELECT @query = REPLACE(@query, 'WhereCond', '1=1') 
			EXEC (@query) 
		END	 
	-------------------------------------------------------- 
	-- DocAch000 
	SET @where = 'OrderGuid IN ( ' + @OrdersSelect + ' )'  
	IF (@MakeFast = 0) 
		EXEC prcCopyTbl @DestDBName, 'DocAch000', @where, 1, 0	 
	ELSE 
		BEGIN 
			SET @query = @insert 
			SELECT @query = REPLACE(@query, 'TargetTbl', 'DocAch000') 
			SELECT @query = REPLACE(@query, 'WhereCond', @where) 
			EXEC (@query) 
		END	 
	-------------------------------------------------------- 
	-- OrApp000 
	SET @where = 'OrderGuid IN ( ' + @OrdersSelect + ' )'  
	IF (@MakeFast = 0) 
		EXEC prcCopyTbl @DestDBName, 'OrApp000', @where, 1, 0	 
	ELSE 
		BEGIN 
			SET @query = @insert 
			SELECT @query = REPLACE(@query, 'TargetTbl', 'OrApp000') 
			SELECT @query = REPLACE(@query, 'WhereCond', @where) 
			EXEC (@query) 
		END	 
	----------------------------------------------------------- 
	IF dbo.fnObjectExists('##AmnOrders_OrdersToBeCopied') = 1
		DROP TABLE ##AmnOrders_OrdersToBeCopied
	*/
################################################################
#END