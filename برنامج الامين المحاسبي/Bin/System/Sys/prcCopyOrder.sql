################################################################
CREATE PROCEDURE prcCopyOrder 
	@DestDBName	[NVARCHAR](255), 
	@RndText	[NVARCHAR](100)
AS   
	SET @DestDBName = '[' + @DestDBName + ']';
	DECLARE @MakeFast AS BIT 
	SET @MakeFast = 1 
	DECLARE @query  AS NVARCHAR(max) 
	DECLARE @insert AS NVARCHAR(1000) 
	DECLARE @where  AS NVARCHAR(1000) 
	DECLARE @upd AS NVARCHAR(1000)
	DECLARE @documentWhere  AS NVARCHAR(1000) 
	 
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
		bt.Type IN (5, 6) 
		AND
		-- bring only Finished separated orders those Parent Orders are Active
		((info.Finished = 0) OR (info.Finished = 1 AND bu.[GUID] IN (SELECT ORGuid FROM ORRel000 WHERE ParentGuid IN (SELECT DISTINCT orel.ParentGuid FROM orrel000 orel INNER JOIN OrAddInfo000 info ON orel.ParentGuid = info.ParentGuid WHERE info.Finished = 0) )))
		AND 
		info.Add1 = 0
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
	--
	------------------------------------------------------- 
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
	---------------------------------------------------------- 
	DECLARE @tableP AS NVARCHAR(100)
	DECLARE	@SQLPay AS NVARCHAR(Max)
	set @tableP = @DestDBName + '..TrnOrdPayment000'
	
	SET @SQLPay = 'INSERT INTO ' + @tableP +' 
	--—»ÿ «·œ›⁄« 
	SELECT 
	distinct
		o.PaymentNumber,
		bt.Name +'':''+ CAST(bu.Number AS NVARCHAR),  -- TypeName
		o.BillGuid,
		o.PaymentDate,
		o.UpdatedValueWithCurrency / (CASE WHEN bu.CurrencyVal <> 0 THEN bu.CurrencyVal ELSE 1 END) AS PaymentValue
	FROM
		vwOrderPayments o
		INNER JOIN bu000 bu ON o.BillGuid = bu.Guid
		INNER JOIN bt000 bt ON bu.TypeGuid = bt.Guid
	WHERE
		o.BillGuid IN ('+ @OrdersSelect+' ) AND o.UpdatedValueWithCurrency <> 0'
	EXEC (@SQLPay)
	Set @SQLPay=''
	SET @SQLPay = 'INSERT INTO ' + @tableP +' 
	SELECT 
		distinct
		o.PaymentNumber,
		ISNULL((et.Abbrev + '': '' + CAST(py.Number AS NVARCHAR)), bi.btAbbrev+ '': '' + CAST(bi.buNumber AS NVARCHAR)),
		o.PaymentGuid, -- ParentGuid
		ISNULL(en.[Date], bi.buDate),
		(CASE WHEN bp.CurrencyGUID <> b.CurrencyGUID THEN (CASE WHEN bp.CurrencyVal = 1 THEN bp.Val / b.CurrencyVal ELSE bp.Val END) ELSE bp.Val / b.CurrencyVal END)
	FROM 
		bp000 bp
		INNER JOIN vwOrderPayments o ON (bp.DebtGUID = o.PaymentGuid OR  bp.PayGUID = o.PaymentGuid) AND 
		( o.BillGuid IN ( '+@OrdersSelect+' ))
		inner join bu000 b on b.guid in ( '+@OrdersSelect+' )
		LEFT JOIN vwOrderPayments oPay ON (bp.DebtGUID = oPay.PaymentGuid OR  bp.PayGUID = oPay.PaymentGuid) AND oPay.BillGuid NOT IN  ( '+@OrdersSelect+' )
		LEFT JOIN en000 en ON bp.DebtGUID = en.[Guid] OR bp.PayGUID = en.[Guid]
		LEFT JOIN ce000 ce ON en.ParentGUID = ce.[GUID]
		LEFT JOIN er000 er ON er.EntryGUID = ce.[GUID]
		LEFT JOIN py000 py ON py.[GUID] = er.ParentGUID
		LEFT JOIN et000 et ON et.[Guid] = ce.TypeGUID
		LEFT JOIN my000 my ON my.[GUID] = bp.CurrencyGUID
		LEFT JOIN vwExtended_bi bi ON bi.buGuid = bp.DebtGUID OR bi.buGUID = bp.PayGUID';
	EXEC (@SQLPay);
	
	----------------------------------
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
	
	SET @upd = ' UPDATE ' + @DestDBName + '..ori000 SET Notes = ''' + @RndText + ''' + '' - '' + Notes'
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
	-- Approval Tables
	--------------------------------------------------------
	-- UsrApp000 
	--		GUID
	--		ParentGUID (bt000.[guid])
	--		UserGUID (us000.[guid])
	--		Order
	SET @where = '1 = 1'  
	IF (@MakeFast = 0) 
		EXEC prcCopyTbl @DestDBName, 'UsrApp000', @where, 1, 0	 
	ELSE 
	BEGIN 
		SET @query = @insert 
		SELECT @query = REPLACE(@query, 'TargetTbl', 'UsrApp000') 
		SELECT @query = REPLACE(@query, 'WhereCond', @where) 
		EXEC (@query) 
	END
	--------------------------------------------------------
	-- OrderApprovals000 
	--		GUID
	--		Number
	--		OrderGUID
	--		UserGUID
	SET @where = 'OrderGuid IN ( ' + @OrdersSelect + ' )'  
	IF (@MakeFast = 0) 
		EXEC prcCopyTbl @DestDBName, 'OrderApprovals000', @where, 1, 0	 
	ELSE 
	BEGIN 
		SET @query = @insert 
		SELECT @query = REPLACE(@query, 'TargetTbl', 'OrderApprovals000') 
		SELECT @query = REPLACE(@query, 'WhereCond', @where) 
		EXEC (@query) 
	END	
	-------------------------------------------------------- 
	-- OrderApprovalStates000
	--		GUID
	--		Number
	--		ParentGUID (OrderApprovals000.guid)
	--		UserGUID
	--		AlternativeUserGUID
	--		IsApproved
	--		OperationTime
	--		ComputerName
	SET @where = '1 = 1'  
	IF (@MakeFast = 0) 
		EXEC prcCopyTbl @DestDBName, 'OrderApprovalStates000', @where, 1, 0	 
	ELSE 
	BEGIN 
		SET @query = @insert 
		SELECT @query = REPLACE(@query, 'TargetTbl', 'OrderApprovalStates000') 
		SELECT @query = REPLACE(@query, 'WhereCond', @where) 
		EXEC (@query) 
	END	
	-------------------------------------------------------- 
	-- OrderAlternativeUsers000
	--		GUID
	--		Number
	--		Security
	--		UserGUID
	--		AlternativeUserGUID
	--		IsActive
	--		Type
	--		IsAllAvailableTypes
	SET @where = '1 = 1'  
	IF (@MakeFast = 0) 
		EXEC prcCopyTbl @DestDBName, 'OrderAlternativeUsers000', @where, 1, 0	 
	ELSE 
	BEGIN 
		SET @query = @insert 
		SELECT @query = REPLACE(@query, 'TargetTbl', 'OrderAlternativeUsers000') 
		SELECT @query = REPLACE(@query, 'WhereCond', @where) 
		EXEC (@query) 
	END	
	-------------------------------------------------------- 
	-- OrderAlternativeUserTypes000
	--		GUID
	--		ParentGUID (OrderAlternativeUsers000.GUID)
	--		OrderTypeGUID (bt.guid)
	SET @where = '1 = 1'  
	IF (@MakeFast = 0) 
		EXEC prcCopyTbl @DestDBName, 'OrderAlternativeUserTypes000', @where, 1, 0	 
	ELSE 
	BEGIN 
		SET @query = @insert 
		SELECT @query = REPLACE(@query, 'TargetTbl', 'OrderAlternativeUserTypes000') 
		SELECT @query = REPLACE(@query, 'WhereCond', @where) 
		EXEC (@query) 
	END	
	-------------------------------------------------------- 
	-- MgrApp000
	--		GUID
	--		UserGUID
	--		OrderGUID
	--		ApprovalDate (date and time)
	SET @where = 'OrderGuid IN ( ' + @OrdersSelect + ' )'  
	IF (@MakeFast = 0) 
		EXEC prcCopyTbl @DestDBName, 'MgrApp000', @where, 1, 0	 
	ELSE 
	BEGIN 
		SET @query = @insert 
		SELECT @query = REPLACE(@query, 'TargetTbl', 'MgrApp000') 
		SELECT @query = REPLACE(@query, 'WhereCond', @where) 
		EXEC (@query) 
	END	
	----------------------------------------------------------- 
	-- Payment Terms (Many Payments)
	----------------------------------------------------------- 
	-- OrderPayments000
	--		GUID
	--		BillGuid
	--		Number
	--		PayDate
	--		Value
	--		Percentage
	SET @where = '1 = 1'  
	IF (@MakeFast = 0) 
		EXEC prcCopyTbl @DestDBName, 'OrderPayments000', @where, 1, 0	 
	ELSE 
	BEGIN 
		SET @query = @insert 
		SELECT @query = REPLACE(@query, 'TargetTbl', 'OrderPayments000') 
		SELECT @query = REPLACE(@query, 'WhereCond', @where) 
		EXEC (@query) 
	END	
	----------------------------------------------------------- 
	-- Payments Linking
	----------------------------------------------------------- 
	-- bp000
	--		GUID
	--		DebtGUID
	--		PayGUID
	--		PayType
	--		Val
	--		CurrencyGUID
	--		CurrencyVal
	--		RecType
	--		DebitType
	-- The following condition brings only the linked payments for orders (linked payments for bills will be ignored)
	SET @where = 'DebitType = 1'  
	IF (@MakeFast = 0) 
		EXEC prcCopyTbl @DestDBName, 'bp000', @where, 1, 0	 
	ELSE 
	BEGIN 
		SET @query = @insert 
		SELECT @query = REPLACE(@query, 'TargetTbl', 'bp000') 
		SELECT @query = REPLACE(@query, 'WhereCond', @where) 
		EXEC (@query) 
	END	
	-----------------------------------------------------------
	-- orrel000 ( Ã“∆… «·ÿ·»Ì« )
	--		GUID
	--		ORGuid	(Child Order GUID  - bu.GUID)
	--		ParentGUID (Parent Order GUID - bu.GUID)
	--		ORParentTypeGuid (Child Order Type GUID - bt.GUID)
	--		ORNumber (Child Order Number)
	--		ORParentNumber (Parent Order Number)
	SET @where = 'ParentGuid IN ( ' + @OrdersSelect + ' )'  
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
	-- Archiving Tables
	----------------------------------------------------------- 
	-- Documents Table
	SET @where = '[ID] IN (SELECT [DocumentID] FROM [DMSTblDocumentFieldValue] WHERE [FieldID]=''b3ba4459-56ab-4117-8e5e-a4e84e074477'' AND [Value] IN ( ' + @OrdersSelect + ' ))'    
	IF (@MakeFast = 0) 
		EXEC prcCopyTbl @DestDBName, 'DMSTblDocument', @where, 1, 0	 
	ELSE 
	BEGIN 
		SET @query = @insert 
		SELECT @query = REPLACE(@query, 'TargetTbl', 'DMSTblDocument') 
		SELECT @query = REPLACE(@query, 'WhereCond', @where) 
		EXEC (@query) 
	END	
	-----------------------------------------------------------
	--Files table
	SET @documentWhere = @where
	SET @where = '[DocumentId] IN (SELECT [ID] FROM [DMSTblDocument] WHERE  ' + @documentWhere   +')'
	IF (@MakeFast = 0) 
		EXEC prcCopyTbl @DestDBName, 'DMSTblFile', @where, 1 ,0	 
	ELSE 
	BEGIN 
		SET @query = @insert 
		SELECT @query = REPLACE(@query, 'TargetTbl', 'DMSTblFile') 
		SELECT @query = REPLACE(@query, 'WhereCond', @where) 
		EXEC (@query) 
	END	
	-----------------------------------------------------------
	--DocumentFieldValues table
	SET @where = '[DocumentID] IN (SELECT [ID] FROM [DMSTblDocument] WHERE  ' + @documentWhere   +')'
	IF (@MakeFast = 0) 
		EXEC prcCopyTbl @DestDBName, 'DMSTblDocumentFieldValue', @where, 1, 0	 
	ELSE 
	BEGIN 
		SET @query = @insert 
		SELECT @query = REPLACE(@query, 'TargetTbl', 'DMSTblDocumentFieldValue') 
		SELECT @query = REPLACE(@query, 'WhereCond', @where) 
		EXEC (@query) 
	END	
	-----------------------------------------------------------
	IF dbo.fnObjectExists('##AmnOrders_OrdersToBeCopied') = 1
		DROP TABLE ##AmnOrders_OrdersToBeCopied
################################################################
#END