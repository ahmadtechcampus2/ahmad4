############################################
CREATE PROCEDURE prcRestGenerateInOutBill
	@PeriodID UNIQUEIDENTIFIER,
	@Period [BIGINT]
AS
	EXECUTE prcNotSupportedInAzureYet
	/*
	DECLARE		@Number FLOAT,  
				@GUID UNIQUEIDENTIFIER,  
				@MnGUID UNIQUEIDENTIFIER, 
				@Qty FLOAT,  
				@SemiFlag INT 
	DECLARE	@ReadyItems TABLE 
	( 
		MnID UNIQUEIDENTIFIER, 
		Qty FLOAT 
	) 

	DECLARE	@FinalReadyItems TABLE 
	( 
		MnID UNIQUEIDENTIFIER, 
		Qty FLOAT,
		Ord int 
	) 

	IF EXISTS (SELECT * FROM tempdb.dbo.sysobjects WHERE id = object_id(N'[tempdb].[dbo].[#RowMaterials ]'))
	DROP TABLE [dbo].[#RowMaterials ]
	CREATE TABLE #RowMaterials   
	(   
		[SELECTEDGUID]       [UNIQUEIDENTIFIER],  
		[GUID]               [UNIQUEIDENTIFIER],   
		[PARENTGUID]         [UNIQUEIDENTIFIER],   
		ClassPtr             [NVARCHAR] (100) COLLATE ARABIC_CI_AI,
		[FROMNAME]           [NVARCHAR] (300) COLLATE ARABIC_CI_AI,
		[MATGUID]            [UNIQUEIDENTIFIER],
		[MATNAME]            [NVARCHAR] (300) COLLATE ARABIC_CI_AI, 
		[QTY]                [FLOAT],   
		[QtyInForm]          [FLOAT],
		[PATH]               [NVARCHAR](1000),   
		[Unit]			     [INT],	   
		[IsSemiReadyMat]     [INT]

	)

	INSERT @ReadyItems SELECT mn.GUID, 
			ISNULL(SUM(items.Qty), 0)/(CASE mi.Qty WHEN 0 THEN 1 ELSE mi.Qty END) 
	FROM RestOrder000 orders 
		INNER JOIN RestOrderItem000 items  ON orders.Guid=items.ParentID 
		INNER JOIN mi000 mi ON mi.[MatGUID]=items.MatID 
		INNER JOIN mn000 mn ON mn.GUID=mi.[ParentGUID] 
	WHERE (items.Type Not in (1,3,4)) AND (orders.Type In (1, 2, 3)) 
			AND orders.Period=@Period 
			AND mn.Type=0 
			AND mi.Type = 0 
	GROUP BY mn.GUID, items.MatID, mi.Qty  


	------------------------------ Get Semi Material for each ready material to re-manufacture -----------------------------
	DECLARE @MatID UNIQUEIDENTIFIER
	DECLARE @semiMatCount INT

	DECLARE mnCursor CURSOR FAST_FORWARD 
	FOR SELECT MnID, Qty FROM @ReadyItems --GROUP BY MnID 
	OPEN mnCursor 
	FETCH FROM mnCursor INTO @MnGUID, @Qty
	WHILE @@FETCH_STATUS = 0 
	BEGIN 
		--get mat id for ready mat in rest bill
		SELECT @MatID = MatGUID FROM MI000 WHERE ParentGuid = @MnGUID AND TYPE = 0
	
		--get semi materials for that ready mat
		INSERT INTO #RowMaterials EXEC prcGetManufacMaterialTree @MatID
	
		UPDATE #RowMaterials
		SET QTY = QTY * @QTY
		WHERE PARENTGUID = @MnGUID
	
		FETCH NEXT FROM mnCursor INTO @MnGUID, @Qty 
	
	END
	CLOSE mnCursor 
	DEALLOCATE mnCursor 

	DECLARE rowMaterialCursor CURSOR FAST_FORWARD 
	FOR SELECT MatGUID, QTY FROM #RowMaterials WHERE [IsSemiReadyMat] = 1
	OPEN rowMaterialCursor 
	FETCH FROM rowMaterialCursor INTO @MatID, @QTY
	WHILE @@FETCH_STATUS = 0 
	BEGIN 
		SELECT @MnGUID = [ParentGuid] FROM mi000 WHERE MATGUID =  @MatID AND TYPE = 0
		INSERT INTO @FinalReadyItems VALUES(@MnGUID, @QTY, 0)
	
		FETCH NEXT FROM rowMaterialCursor INTO @MatID, @QTY
	END
	CLOSE rowMaterialCursor 
	DEALLOCATE rowMaterialCursor 

	-----------------------------------------------------------------------------
	INSERT INTO @FinalReadyItems SELECT MnID, SUM(Qty), 1 FROM @ReadyItems GROUP BY MnID

	DECLARE mnCursor CURSOR FAST_FORWARD 
	FOR SELECT MnID, Qty FROM @FinalReadyItems ORDER BY Ord 
	OPEN mnCursor 
	FETCH FROM mnCursor INTO @MnGUID, @Qty

	WHILE @@FETCH_STATUS = 0
	BEGIN

		SELECT @Number = ISNULL( MAX(Number), 0) + 1 FROM [MN000] WHERE Type=1
		SET @GUID = newid()
	
		-- Header of the manufacture operation
		INSERT INTO MN000 ([Type] ,[Number] ,[Date] ,[InDate],[OutDate] , [Qty] ,[Notes]
		  ,[Security],[Flags],[PriceType],[CurrencyVal],[UnitPrice]
		  ,[TotalPrice],[GUID],[FormGUID],[InStoreGUID],[OutStoreGUID],[InAccountGUID]
		  ,[OutAccountGUID],[InCostGUID],[OutCostGUID],[InTempAccGUID],[OutTempAccGUID]
		  ,[CurrencyGUID],[LOT],[ProductionTime],[BranchGUID],[CostSemiGUID]) 
		SELECT  1 /*[Type]*/ , @Number /*[Number]*/ , GetDate() /*[Date]*/ , GetDate() /*[InDate]*/
		  , GetDate() /*[OutDate]*/ , @Qty /*[Qty] */,[Notes]
		  ,[Security],[Flags], 1 /*Average Price [PriceType]*/,[CurrencyVal],[UnitPrice]
		  ,[TotalPrice], @GUID /*[GUID]*/,[FormGUID],[InStoreGUID],[OutStoreGUID],[InAccountGUID]
		  ,[OutAccountGUID],[InCostGUID],[OutCostGUID],[InTempAccGUID],[OutTempAccGUID]
		  ,[CurrencyGUID],[LOT],[ProductionTime],[BranchGUID],[CostSemiGUID]
		FROM [MN000] WHERE GUID = @MnGUID

		IF @@ROWCOUNT < 1
		BEGIN
			FETCH NEXT FROM mnCursor INTO @MnGUID, @Qty
			CONTINUE
		END

		-- The raw and ready material
		INSERT INTO mi000([Type],[Number],[Unity],[Qty],[Notes],[CurrencyVal],[Price]
		  ,[Class],[GUID],[Qty2],[Qty3],[ParentGUID],[MatGUID],[StoreGUID]
		  ,[CurrencyGUID],[ExpireDate],[ProductionDate],[Length],[Width],[Height]
		  ,[CostGUID],[Percentage])
		SELECT [Type],[Number],[Unity],[Qty] * @Qty,[Notes],[CurrencyVal],[Price]
		  ,[Class], newid() /*[GUID]*/ ,[Qty2],[Qty3], @GUID /*[ParentGUID]*/,[MatGUID],[StoreGUID]
		  ,[CurrencyGUID],[ExpireDate],[ProductionDate],[Length],[Width],[Height]
		  ,[CostGUID],[Percentage]
		FROM [MI000] 
		WHERE ParentGUID = @MnGUID AND ([MatGUID] NOT IN  
			-- this condition to exclude the hold items which added in restaurant
			(SELECT items.MatID FROM RestOrder000 orders INNER JOIN RestOrderItem000 items ON items.ParentID=orders.Guid  WHERE items.Type=4 AND orders.Period=@Period))

		-- this operation to add the extra items which added to the ready item in the restaurant
		INSERT INTO mi000([Type],[Number],[Unity],[Qty],[Notes],[CurrencyVal],[Price]
		  ,[Class],[GUID],[Qty2],[Qty3],[ParentGUID],[MatGUID],[StoreGUID]
		  ,[CurrencyGUID],[ExpireDate],[ProductionDate],[Length],[Width],[Height]
		  ,[CostGUID],[Percentage])
		SELECT 1 /*[Type]*/,item.[Number], item.Unity /*[Unity]*/, item.Qty/*[Qty]*/, item.[Note], mi.[CurrencyVal], item.[Price]
		  ,mi.[Class], newid() /*[GUID]*/ ,mi.[Qty2],mi.[Qty3], @GUID /*[ParentGUID]*/,item.MatID /*[MatGUID]*/,mi.[StoreGUID]
		  ,mi.[CurrencyGUID],mi.[ExpireDate],mi.[ProductionDate],mi.[Length],mi.[Width],mi.[Height]
		  ,mi.[CostGUID],mi.[Percentage]
		FROM [MI000] mi 
			INNER JOIN RestOrderItem000 parent ON mi.MatGUID=parent.MatID
			INNER JOIN RestOrderItem000 item ON item.ItemParentID=parent.GUID AND item.Type=3
			INNER JOIN RestOrder000 orders ON parent.ParentID=orders.Guid AND orders.Period=@Period
		WHERE mi.ParentGUID = @MnGUID

		EXEC [prcManufac_genBills] @GUID,0,4,0,0,0 

		INSERT INTO BillRel000 Values (newid(), 13, @GUID, @PeriodID, 0)

		FETCH NEXT FROM mnCursor INTO @MnGUID, @Qty
	END

	CLOSE mnCursor
	DEALLOCATE mnCursor
	*/
############################################
#END