
#########################################################
CREATE TRIGGER trg_mt000_CheckConstraints
	ON mt000 FOR DELETE
	NOT FOR REPLICATION
AS
/*
This trigger checks:
	- not to delete used accounts
*/
	IF @@ROWCOUNT = 0
		RETURN
	SET NOCOUNT ON
	CREATE TABLE #DeletedMaterials (   
	     Material		UNIQUEIDENTIFIER  
	    ,UsedIn         int
		,ErrMsg         nvarchar(400)    
    )
	insert into #DeletedMaterials (Material,UsedIn)
	    select [GUID],[dbo].[fnMaterialGroup_IsUsed]([GUID],[GroupGUID]) from [deleted]
    update #DeletedMaterials set ErrMsg = 'AmnE0060: Can''t delete Material(s), it''s being used ...'
	where UsedIn not in (0,0x000109, 0x000110, 0x000111, 0x000112,0x000113,0x000114,0x000115,0x000116,0x000117,0x000118,0x000102)
	update #DeletedMaterials set ErrMsg = 'AmnE0061: Can''t delete Material(s), it''s being used in BOM ...'
	where UsedIn  in (0x000119,0x000120,0x000121,0x000122,0x000123)
	update #DeletedMaterials set ErrMsg = 'AmnE0500: Can''t delete Material(s), it''s being used in POS ...'
	where UsedIn  in (0x000111,0x000112)
		-- حذف من الطلبيات 
	update #DeletedMaterials set ErrMsg = 'AmnE0065: Can''t delete Material(s), it''s being used in orders ...'
	where UsedIn  in (0x000113)
	-- حذف من نماذج التصنيع
	update #DeletedMaterials set ErrMsg = 'AmnE0073: Can''t delete Material(s), it''s being used in Manufacture Model ...'
	where UsedIn  in (0x000102)
	-- حذف من بطاقات التكليف
	update #DeletedMaterials set ErrMsg = 'AmnE0067: Can''t delete Material(s), it''s being used in in Cost Materials Card ...'
	where UsedIn  in (0x000114)
	--  حذف من المواد التجميعية 
	update #DeletedMaterials set ErrMsg = 'AmnE0068: Can''t delete Material(s), it''s being used in Assembled Products ...'
	where UsedIn  in (0x000103)
	--  حذف من المجموعات التجميعية 
	update #DeletedMaterials set ErrMsg = 'AmnE0069: Can''t delete Material(s), it''s being used in Assembled Group ...'
	where UsedIn  in (0x000115)
	--  حذف من عروض التوزيع 
	update #DeletedMaterials set ErrMsg = 'AmnE0070: Can''t delete Material(s), it''s being used in Distributive offer ...'
	where UsedIn  in (0x000116)
	-- حذف من نقاط البيع  
	update #DeletedMaterials set ErrMsg = 'AmnE0071: Can''t delete Material(s), it''s being used in POS Special Offer ...'
	where UsedIn  in (0x000117 ,0x000130)
	--  حذف من بطاقة البدائل 
	update #DeletedMaterials set ErrMsg = 'AmnE0072: Can''t delete Material(s), it''s being used in Alternative material ...'
	where UsedIn  in (0x000118)
	
	update #DeletedMaterials set ErrMsg = 'AmnE0501: Can''t delete Material(s), it''s being used in Bill ...'
	where UsedIn  in (0x000101)
	update #DeletedMaterials set ErrMsg = 'AmnE0502: Can''t delete Material(s), it''s being used in POS Smart Device Group ...'
	where UsedIn  in (0x000129)
	
	---********************************************************************************
	-- Delete item used in group associated with POS smart devices
	update #DeletedMaterials set ErrMsg = 'AmnE0502: Can''t delete Material(s), it''s being used in POS Smart Device Group ...'
	where UsedIn  in (0x000129)
	--study a case when deleting used material:
	INSERT INTO [ErrorLog] ([level], [type], [c1], [g1], [i1])
		SELECT 1, 0, #DeletedMaterials.ErrMsg, #DeletedMaterials.Material,  #DeletedMaterials.UsedIn
		FROM  #DeletedMaterials
		WHERE   #DeletedMaterials.UsedIn <> 0

#########################################################
CREATE TRIGGER trg_mt000_delete 
	ON [mt000] FOR DELETE
	NOT FOR REPLICATION
AS
	IF @@ROWCOUNT = 0 RETURN
	SET NOCOUNT ON	

	-- delete related ma 
	DELETE [ma000] FROM [ma000] AS [ma] INNER JOIN [deleted] AS [d] ON [ma].[ObjGUID] = [d].[GUID]
	DELETE [md000] FROM [md000] AS [md] INNER JOIN [deleted] AS [d] ON [md].[ParentGUID] = [d].[GUID]
	--Delete related targets
	DELETE MatTargets000 FROM MatTargets000 AS matTargets INNER JOIN deleted AS d ON matTargets.mtGUID = d.GUID
	
	DELETE CompositeMaterials FROM mt000 CompositeMaterials JOIN deleted Parents ON CompositeMaterials.Parent = Parents.GUID
	
	-- Deleted Related records in POSSDStationSyncModifiedData000
	DELETE [POSSDStationSyncModifiedData000] FROM [POSSDStationSyncModifiedData000] AS [SSD] INNER JOIN [deleted] AS [d] ON (SSD.[RelatedToObject] = 'MT000' AND [SSD].[ReleatedToObjectGuid] = [d].[GUID])
#########################################################
CREATE TRIGGER trg_mt000_Assets
	ON [mt000] FOR INSERT, DELETE, UPDATE
	NOT FOR REPLICATION
AS  
	IF @@ROWCOUNT = 0 RETURN
	SET NOCOUNT ON	

	DECLARE @causeOfTrigger [INT]

	SET @causeOfTrigger = 0

	IF EXISTS(SELECT * FROM [inserted])
		SET @causeOfTrigger = @causeOfTrigger ^ 1

	IF EXISTS(SELECT * FROM [deleted])
		SET @causeOfTrigger = @causeOfTrigger ^ 2

	IF @causeOfTrigger = 1 -- insert only
		INSERT INTO [as000]([Number], [Code], [Name], [latinName], [ParentGUID], [Security], [AccGUID], [DepAccGUID], [AccuDepAccGUID])
			SELECT [dbo].[fnAssets_GetNewNumber](), [Code], [Name], [latinName], [GUID] , [Security], 0x0, 0x0, 0x0 FROM [inserted] WHERE [Type] = 2 

	ELSE IF @causeOfTrigger = 2 -- delete only
		DELETE [as000] FROM [as000] AS [ad] INNER JOIN [deleted] AS [d] ON [ad].[ParentGUID] = [d].[GUID]

	ELSE IF EXISTS(SELECT * FROM [inserted] AS [i] INNER JOIN [deleted] AS [d] ON [i].[GUID] = [d].[GUID] WHERE [i].[type] <> [d].[type]) -- type update
	BEGIN
		DECLARE
			@c CURSOR,
			@GUID [UNIQUEIDENTIFIER],
			@oldType [INT],
			@newType [INT]

		SET @c = CURSOR FAST_FORWARD FOR 
					SELECT [i].[GUID], [d].[Type], [i].[Type]
					FROM [inserted] AS [i] INNER JOIN [deleted] AS [d] ON [i].[GUID] = [d].[GUID]
					WHERE [i].[type] <> [d].[type] -- type update

		OPEN @c FETCH FROM @c INTO @GUID, @oldType, @newType
		WHILE @@FETCH_STATUS = 0
		BEGIN
			IF @newType = 2 AND NOT EXISTS(SELECT * FROM [as000] WHERE [parentGUID] = @GUID) -- the material has become a asset, so, generate and entry in as000 for it
				INSERT INTO [as000]([Number], [Code], [Name], [latinName], [ParentGUID], [Security], [AccGUID], [DepAccGUID], [AccuDepAccGUID])
					SELECT [dbo].[fnAssets_GetNewNumber](), [Code], [Name], [latinName], [GUID], [Security], 0x0, 0x0, 0x0 FROM [inserted] WHERE [GUID] = @GUID

			ELSE IF @oldType = 2 -- the material was an asset, so, delete related as000
				DELETE [as000] WHERE [parentGUID] = @GUID			
				
			FETCH FROM @c INTO @GUID, @oldType, @newType
		END
		CLOSE @c DEALLOCATE @c
	END

#########################################################	
CREATE TRIGGER trg_mt000_CheckBalance
	ON [mt000] FOR UPDATE
	NOT FOR REPLICATION
AS
	IF @@ROWCOUNT = 0 RETURN 
	SET NOCOUNT ON	 

	IF UPDATE(Qty) 

		IF dbo.fnOption_GetInt('AmnCfg_MatQtyByStore', '0') = 0
		BEGIN
			DECLARE @isCalcPurchaseOrderRemindedQty BIT
			SELECT @isCalcPurchaseOrderRemindedQty = dbo.fnOption_GetInt('AmnCfg_CalcPurchaseOrderRemindedQty', '0')

			INSERT INTO [ErrorLog] ([level], [type], [c1], [g1])  
			SELECT  
				2,  
				0,  
				'AmnW0062: ' + cast([MT].[GUID] as NVARCHAR(128)) + ' Product balance is less than zero, ' + dbo.fnMaterial_GetCodeName( [MT].[GUID]),
				[MT].[GUID]  
			FROM  
				[inserted] AS [MT]  
				INNER JOIN [deleted] [d] ON [d].[GUID] = [MT].[GUID]
			WHERE  
				(([MT].[Qty] + (CASE @isCalcPurchaseOrderRemindedQty 
								  WHEN 1 THEN [dbo].[fnGetPurchaseOrderRemaindedQty](MT.GUID, 0x0, 0x0) 
								  ELSE 0 
								END)) < -dbo.fnGetZeroValueQTY() )
				AND   
				[MT].[Qty] < [d].[Qty]
				AND  
				[mt].[Type] <> 1 -- ÛíÑ ÎÏãíÉ 

			INSERT INTO [ErrorLog] ([level], [type], [c1], [g1])  
			SELECT  
				2,  
				0,  
				'AmnW0063: ' + cast([MT].[GUID] as NVARCHAR(128)) + ' Product balance is less than minimum, ' + dbo.fnMaterial_GetCodeName( [MT].[GUID]),
				[MT].[GUID]  
			FROM  
				[inserted] AS [MT] 
				INNER JOIN [deleted] [d] ON [d].[GUID] = [MT].[GUID]				
			WHERE  
				(([MT].[Qty] + (CASE @isCalcPurchaseOrderRemindedQty 
								  WHEN 1 THEN [dbo].[fnGetPurchaseOrderRemaindedQty](MT.GUID, 0x0, 0x0) 
								  ELSE 0 
								END)) < [mt].[Low] )
				AND   
					[MT].[Qty] < [d].[Qty]
				AND  
					[mt].[Type] <> 1 -- ÛíÑ ÎÏãíÉ 
				
			INSERT INTO [ErrorLog] ([level], [type], [c1], [g1])  
			SELECT  
				2,  
				0,  
				'AmnW0064: ' + cast([MT].[GUID] as NVARCHAR(128)) + ' Product balance is less than ordering limit, ' + dbo.fnMaterial_GetCodeName( [MT].[GUID]),
				[MT].[GUID]  
			FROM  
				[inserted] AS [MT] 
				INNER JOIN [deleted] [d] ON [d].[GUID] = [MT].[GUID]				
			WHERE  
				(([MT].[Qty] + (CASE @isCalcPurchaseOrderRemindedQty 
								  WHEN 1 THEN [dbo].[fnGetPurchaseOrderRemaindedQty](MT.GUID, 0x0, 0x0) 
								  ELSE 0 
								 END)) < [mt].[OrderLimit] )
				AND   
					[MT].[Qty] < [d].[Qty]
				AND  
					[mt].[Type] <> 1 -- ÛíÑ ÎÏãíÉ 
		END
	/*
	IF UPDATE(Qty)
	INSERT INTO [ErrorLog] ([level], [type], [c1], [g1]) 
		SELECT 
			2, 
			0, 
			'AmnW0062: ' + cast([guid] as NVARCHAR(128)) + ' Product balance is less than zero, ' + [Code] + '-' + [Name], 
			[guid] 
		FROM 
			[inserted] 
		WHERE 
			[Qty] < 0
	*/
#########################################################	
CREATE TRIGGER TRG_MT000_UPDATE_BARCODE
	ON [MT000] FOR UPDATE, INSERT
	NOT FOR REPLICATION
AS 
	IF @@ROWCOUNT = 0 RETURN 
	SET NOCOUNT ON
	IF [DBO].[fnOption_GetInt]('AmnCfg_MatUniqueBarcode', '0') = 0 AND NOT EXISTS (SELECT [GUID] FROM inserted WHERE Parent <> 0x0)
		RETURN

	DECLARE @t TABLE(Code NVARCHAR(255),Name NVARCHAR(255),Guid uniqueidentifier)

	IF UPDATE(BARCODE)
		INSERT INTO @T 
		SELECT Code, Name, Guid  FROM (
			SELECT A.Code, A.Name, A.Guid FROM INSERTED A INNER JOIN MT000 M ON A.BARCODE = M.BARCODE  WHERE A.GUID <> M.GUID AND A.BARCODE <> ''
			UNION ALL
			SELECT A.Code, A.Name, A.Guid FROM INSERTED A INNER JOIN MT000 M ON A.BARCODE = M.BARCODE2 WHERE A.BARCODE <> '' AND M.bARCODE2 <> '' 
			UNION ALL 
			SELECT A.Code, A.Name, A.Guid FROM INSERTED A INNER JOIN MT000 M ON A.BARCODE = M.BARCODE3 WHERE A.BARCODE <> '' AND M.bARCODE3 <> '' 
			) AS A
	
	IF UPDATE(BARCODE2)
		INSERT INTO @T 
		SELECT Code, Name, Guid FROM ( 
			SELECT  A.Code, A.Name, A.Guid FROM INSERTED A INNER JOIN MT000 M ON A.BARCODE2 = M.BARCODE  WHERE A.BARCODE2 <> '' AND   M.bARCODE <> ''
			UNION ALL
			SELECT  A.Code, A.Name, A.Guid FROM INSERTED A INNER JOIN MT000 M ON A.BARCODE2 = M.BARCODE2 WHERE A.GUID <> M.GUID  AND M.bARCODE2 <> '' 
			UNION ALL 
			SELECT  A.Code, A.Name, A.Guid FROM INSERTED A INNER JOIN MT000 M ON A.BARCODE2 = M.BARCODE3 WHERE A.BARCODE2 <> '' AND M.bARCODE3 <> '' 
			) A 
	
	IF UPDATE(BARCODE3) 
		INSERT INTO @T 
		SELECT Code, Name, Guid  FROM ( 
			SELECT  A.Code, A.Name, A.Guid FROM INSERTED A INNER JOIN MT000 M ON A.BARCODE3 = M.BARCODE  WHERE A.BARCODE3 <> '' AND M.BARCODE <> ''
			UNION ALL 
			SELECT  A.Code, A.Name, A.Guid FROM INSERTED A INNER JOIN MT000 M ON A.BARCODE3 = M.BARCODE2 WHERE A.BARCODE3 <> '' AND M.BARCODE2 <> '' 
			UNION ALL 
			SELECT  A.Code, A.Name, A.Guid FROM INSERTED A INNER JOIN MT000 M ON A.BARCODE3 = M.BARCODE3 WHERE A.GUID <> M.GUID  AND M.BARCODE3 <> '' 
			) A 
	
	INSERT INTO [ErrorLog] ([level], [type], [c1], [g1]) 
	SELECT  1, 0, 
		'AmnW0855: ' + ' , ' + Code + '-' + Name, 
		[MT].[GUID] 
	FROM @T AS [MT]
#########################################################	
CREATE TRIGGER trg_mt000_UpdatePrices
   ON mt000
   AFTER UPDATE
   NOT FOR REPLICATION
AS 
BEGIN
	SET NOCOUNT ON;
	
	IF UPDATE(CurrencyGUID)
	BEGIN
		;WITH LastBill AS
		(
			SELECT DISTINCT
				biMatPtr,
				buNumber,
				buDate,
				buCurrencyVal
			FROM 
				vwExtended_bi BI
				JOIN inserted I ON BI.biMatPtr = I.GUID
				JOIN cp000 CP ON cp.MatGUID = I.GUID AND CP.CustGUID = BI.buCustPtr
			WHERE
				bi.btAffectCustPrice = 1
				AND buCurrencyPtr = I.CurrencyGUID
				AND buDate = CP.[Date]
		)
		UPDATE CP
		SET 
			CurrencyVal = ISNULL(B.buCurrencyVal, dbo.fnGetCurVal(I.CurrencyGUID, CP.[Date])),
			CurrencyGUID = I.CurrencyGUID
		FROM
			cp000 CP
			JOIN inserted I ON CP.MatGUID = I.[GUID]
			LEFT JOIN LastBill B ON B.biMatPtr = I.[GUID];

		DISABLE TRIGGER trg_bi000_CheckConstraints ON bi000;

		UPDATE BI
		SET MatCurVal = CASE WHEN BU.CurrencyGUID = I.CurrencyGUID THEN BU.CurrencyVal ELSE dbo.fnGetCurVal(I.CurrencyGUID, BU.[Date]) END
		FROM 
			bi000 BI
			JOIN inserted I ON I.GUID = BI.MatGUID
			JOIN BU000 BU ON BU.GUID = BI.ParentGUID
		WHERE 
			I.ClassFlag = 1 AND BI.ClassPrice <> 0;

		ENABLE TRIGGER trg_bi000_CheckConstraints ON bi000;
	END
END
#########################################################

CREATE TRIGGER trg_mt000_MaterialSegments000_INSERT
ON [mt000] AFTER INSERT
NOT FOR REPLICATION
AS
	IF @@ROWCOUNT = 0 RETURN
	SET NOCOUNT ON	

	DECLARE @MaterialId UNIQUEIDENTIFIER; 
	DECLARE @GroupId UNIQUEIDENTIFIER;
	DECLARE @HasSegments BIT;
	DECLARE @Type INT;

	DECLARE Mat_Cursor CURSOR FOR
	SELECT 
	GUID AS MaterialId, 
	GroupGUID AS GroupId, 
	HasSegments as HasSegments,
	[Type] as [Type]
	from inserted;

	OPEN Mat_Cursor; 
	FETCH NEXT FROM Mat_Cursor INTO @MaterialId, @GroupId, @HasSegments, @Type;

	WHILE @@FETCH_STATUS = 0
	BEGIN
		IF((@HasSegments = 1 ) AND (@Type = 0))
		BEGIN
			EXEC prcAddMaterialSegments @MaterialId, @GroupId	
		END

		FETCH NEXT FROM Mat_Cursor INTO @MaterialId, @GroupId, @HasSegments, @Type;
	END

	CLOSE Mat_Cursor
	DEALLOCATE Mat_Cursor
#########################################################
CREATE TRIGGER trg_mt000_INSERT_CompositeMaterial
	ON mt000 AFTER INSERT
	NOT FOR REPLICATION
AS  
	IF @@ROWCOUNT = 0 RETURN
	SET NOCOUNT ON	

	IF NOT EXISTS(SELECT * FROM [inserted] WHERE [Parent] <> 0x0)
	RETURN;

	UPDATE mt
	SET Unity = parentTable.Unity,
		Spec = parentTable.Spec,
		PriceType = parentTable.PriceType,
		SellType = parentTable.SellType,
		BonusOne = parentTable.BonusOne,
		CurrencyVal = parentTable.CurrencyVal,
		Origin = parentTable.Origin,
		Company = parentTable.Company,
		TYPE = parentTable.Type,
		SECURITY = parentTable.Security,
		Bonus = parentTable.Bonus,
		Unit2 = parentTable.Unit2,
		Unit2Fact = parentTable.Unit2Fact,
		Unit3 = parentTable.Unit3,
		Unit3Fact = parentTable.Unit3Fact,
		Flag = parentTable.Flag,
		Pos = parentTable.Pos,
		Dim = parentTable.Dim,
		ExpireFlag = parentTable.ExpireFlag,
		ProductionFlag = parentTable.ProductionFlag,
		Unit2FactFlag = parentTable.Unit2FactFlag,
		Unit3FactFlag = parentTable.Unit3FactFlag,
		SNFlag = parentTable.SNFlag,
		ForceInSN = parentTable.ForceInSN,
		ForceOutSN = parentTable.ForceOutSN,
		VAT = parentTable.VAT,
		Color = parentTable.Color,
		Provenance = parentTable.Provenance,
		Quality = parentTable.Quality,
		Model = parentTable.Model,
		GroupGUID = parentTable.GroupGUID,
		CurrencyGUID = parentTable.CurrencyGUID,
		DefUnit = parentTable.DefUnit,
		bHide = parentTable.bHide,
		branchMask = parentTable.branchMask,
		Assemble = parentTable.Assemble,
		CalPriceFromDetail = parentTable.CalPriceFromDetail,
		ForceInExpire = parentTable.ForceInExpire,
		ForceOutExpire = parentTable.ForceOutExpire,
		IsIntegerQuantity = parentTable.IsIntegerQuantity,
		ClassFlag = parentTable.ClassFlag,
		ForceInClass = parentTable.ForceInClass,
		ForceOutClass = parentTable.ForceOutClass,
		DisableLastPrice = parentTable.DisableLastPrice,
		LastPriceCurVal = parentTable.LastPriceCurVal,
		IsCompositionUpdated = 0
	FROM mt000 AS mt
	INNER JOIN mt000 AS parentTable ON mt.Parent = parentTable.[Guid]
	WHERE mt.GUID IN
	 (SELECT Guid
		 FROM [inserted]
		 WHERE Parent <> 0x0)

	IF((SELECT [dbo].[fnOption_GetBit]('AmnCfg_EnableGCCTaxSystem', 0)) <> 0)
	BEGIN
		INSERT INTO GCCMaterialTax000 
			([GUID]
			,[TaxType]
			,[TaxCode]
			,[Ratio]
			,[MatGUID]
			,[ProfitMargin])
		SELECT
			NEWID()
			,parentTax.TaxType
			,parentTax.TaxCode
			,parentTax.Ratio
			,mt.GUID
			,parentTax.ProfitMargin 
		FROM 
		[inserted] mt
		LEFT JOIN GCCMaterialTax000 parentTax ON parentTax.MatGUID = mt.Parent
		WHERE 
		mt.Parent <> 0x0
		AND parentTax.MatGUID IS NOT NULL
	END
#########################################################
CREATE TRIGGER trg_mt000_Segmentation_UPDATE
ON mt000 FOR UPDATE
NOT FOR REPLICATION
AS
	IF @@ROWCOUNT = 0 RETURN
	SET NOCOUNT ON	

	IF UPDATE(HasSegments)
	BEGIN 
		CREATE TABLE #invalidMaterials 
		(   
			MaterialId		UNIQUEIDENTIFIER  
			,UsedIn         int
			,ErrMsg         nvarchar(400) 
			,HadSegments	BIT
			,HasSegments	BIT   
		)

		INSERT INTO  #invalidMaterials (MaterialId, UsedIn, HadSegments, HasSegments)
			SELECT d.[GUID], [dbo].[fnMaterial_IsUsed](d.[GUID]), d.HasSegments, i.HasSegments 
			FROM [deleted] d
			JOIN [inserted] i ON d.[GUID] = i.[GUID]
			WHERE (d.HasSegments = 0 AND i.HasSegments = 1) OR (d.HasSegments = 1 AND i.HasSegments = 0)


		UPDATE #invalidMaterials 
		SET ErrMsg = CASE WHEN (HadSegments = 0 AND HasSegments = 1) THEN 'AmnE0138: Can''t edit Material(s), it''s being used ...'
						  WHEN (HadSegments = 1 AND HasSegments = 0 ) THEN 'AmnE0160: Can''t edit CompositeMaterial(s), it''s being used ...' 
						  END

		UPDATE #invalidMaterials 
		SET ErrMsg = CASE WHEN (HadSegments = 0 AND HasSegments = 1) THEN 'AmnE0139: Can''t edit Material(s), it''s being used IN BOM ...'
						  WHEN (HadSegments = 1 AND HasSegments = 0 ) THEN 'AmnE0161: Can''t edit CompositeMaterial(s), it''s being used IN BOM...' 
						  END
		WHERE UsedIn IN (0x000119,0x000120,0x000121,0x000122,0x000123) 


		--äÞÇØ ÇáÈíÚ
		UPDATE #invalidMaterials 
		SET ErrMsg = CASE WHEN (HadSegments = 0 AND HasSegments = 1) THEN 'AmnE0140: Can''t edit Material(s), it''s being used IN POS ...'
					  WHEN (HadSegments = 1 AND HasSegments = 0 ) THEN 'AmnE0162: Can''t edit CompositeMaterial(s), it''s being used IN POS...' 
					  END
		WHERE UsedIn IN (0x000111,0x000112)

		--  ÇáØáÈíÇÊ 
		UPDATE #invalidMaterials 
		SET ErrMsg = CASE WHEN (HadSegments = 0 AND HasSegments = 1) THEN 'AmnE0141: Can''t edit Material(s), it''s being used IN Orders ...'
					 WHEN (HadSegments = 1 AND HasSegments = 0 ) THEN 'AmnE0163: Can''t edit CompositeMaterial(s), it''s being used IN Orders...' 
					 END
		where UsedIn  IN (0x000113)

		--  äãÇÐÌ ÇáÊÕäíÚ
		UPDATE #invalidMaterials 
		SET ErrMsg = CASE WHEN (HadSegments = 0 AND HasSegments = 1) THEN 'AmnE0142: Can''t edit Material(s), it''s being used IN FORM ...'
					 WHEN (HadSegments = 1 AND HasSegments = 0 ) THEN 'AmnE0164: Can''t edit CompositeMaterial(s), it''s being used IN FORM...' 
					 END
		WHERE UsedIn  in (0x000102)

		--  ÈØÇÞÇÊ ÇáÊßáíÝ
		UPDATE #invalidMaterials 
		SET ErrMsg = CASE WHEN (HadSegments = 0 AND HasSegments = 1) THEN 'AmnE0143: Can''t edit Material(s), it''s being used IN Cost Materials Card ...'
					 WHEN (HadSegments = 1 AND HasSegments = 0 ) THEN 'AmnE0165: Can''t edit CompositeMaterial(s), it''s being used IN Cost Materials Card...' 
					 END
		where UsedIn  in (0x000114)

		--   ÇáãæÇÏ ÇáÊÌãíÚíÉ 
		UPDATE #invalidMaterials 
		SET ErrMsg = CASE WHEN (HadSegments = 0 AND HasSegments = 1) THEN 'AmnE0144: Can''t edit Material(s), it''s being used IN Assembled Products...'
					 WHEN (HadSegments = 1 AND HasSegments = 0 ) THEN 'AmnE0166: Can''t edit CompositeMaterial(s), it''s being used IN Assembled Products...' 
					 END
		where UsedIn  in (0x000103)

		--   ÇáãÌãæÚÇÊ ÇáÊÌãíÚíÉ 
		UPDATE #invalidMaterials 
		SET ErrMsg = CASE WHEN (HadSegments = 0 AND HasSegments = 1) THEN 'AmnE0145: Can''t edit Material(s), it''s being used IN Assembled Group...'
					 WHEN (HadSegments = 1 AND HasSegments = 0 ) THEN 'AmnE0167: Can''t edit CompositeMaterial(s), it''s being used IN Assembled Group...' 
					 END
		where UsedIn  in (0x000115)

		--   ÚÑæÖ ÇáÊæÒíÚ 
		UPDATE #invalidMaterials 
		SET ErrMsg = CASE WHEN (HadSegments = 0 AND HasSegments = 1) THEN 'AmnE0146: Can''t edit Material(s), it''s being used IN Distributive offer...'
					 WHEN (HadSegments = 1 AND HasSegments = 0 ) THEN 'AmnE0168: Can''t edit CompositeMaterial(s), it''s being used IN Distributive offer...' 
					 END
		where UsedIn  in (0x000116)

		--   äÞÇØ ÇáÈíÚ  
		UPDATE #invalidMaterials 
		SET ErrMsg = CASE WHEN (HadSegments = 0 AND HasSegments = 1) THEN 'AmnE0147: Can''t edit Material(s), it''s being used IN POS Special Offer ...'
					 WHEN (HadSegments = 1 AND HasSegments = 0 ) THEN 'AmnE0169: Can''t edit CompositeMaterial(s), it''s being used IN POS Special Offer ...' 
					 END
		where UsedIn  in (0x000117,0x000125)

		--   ÈØÇÞÉ ÇáÈÏÇÆá 
		UPDATE #invalidMaterials 
		SET ErrMsg = CASE WHEN (HadSegments = 0 AND HasSegments = 1) THEN 'AmnE0148: Can''t edit Material(s), it''s being used IN Alternative material ...'
					 WHEN (HadSegments = 1 AND HasSegments = 0 ) THEN 'AmnE0570: Can''t edit CompositeMaterial(s), it''s being used IN Alternative material ...' 
					 END
		where UsedIn  in (0x000118)
	
		-- ÈØÇÞÉ ÈÏÇÆá ÃæÇãÑ ÊÔÛíá
		UPDATE #invalidMaterials 
		SET ErrMsg = CASE WHEN (HadSegments = 0 AND HasSegments = 1) THEN 'AmnE0149: Can''t edit Material(s), it''s being used IN JOC Alternative material ...'
					 WHEN (HadSegments = 1 AND HasSegments = 0 ) THEN 'AmnE0571: Can''t edit CompositeMaterial(s), it''s being used IN JOC Alternative material ...' 
					 END
		WHERE UsedIn IN (0x000124) AND HadSegments = 0 AND HasSegments = 1	


		--   ÚÑæÖ ÎÇÕÉ
		UPDATE #invalidMaterials 
		SET ErrMsg = CASE WHEN (HadSegments = 0 AND HasSegments = 1) THEN 'AmnE0572: Can''t edit Material(s), it''s being used IN Special Offer ...'
					 WHEN (HadSegments = 1 AND HasSegments = 0 ) THEN 'AmnE0573: Can''t edit CompositeMaterial(s), it''s being used IN Special Offer ...'
					 END
		where UsedIn  in (0x000126,0x000127,0x000128)

		UPDATE #invalidMaterials 
		SET ErrMsg = CASE WHEN (HadSegments = 0 AND HasSegments = 1) THEN 'AmnE0574: Can''t edit Material(s), it''s being used IN Bill ...'
						  WHEN (HadSegments = 1 AND HasSegments = 0 ) THEN 'AmnE0575: Can''t edit CompositeMaterial(s), it''s being used IN Bill...' 
						  END
		WHERE UsedIn IN (0x000101) 

		INSERT INTO [ErrorLog] ([level], [type], [c1], [g1], [i1])
		SELECT 1, 0, t.ErrMsg, t.MaterialId,  t.UsedIn
		FROM  #invalidMaterials t
		WHERE   t.UsedIn <> 0

		DROP TABLE #invalidMaterials

		--Deleting Material Segments and composite materials
		DELETE ms 
		FROM MaterialSegments000 ms 
		JOIN inserted i ON i.GUID = ms.MaterialId
		WHERE i.HasSegments = 0

		DELETE mt
		FROM mt000 mt
		JOIN inserted i ON i.GUID = mt.Parent
		WHERE i.HasSegments = 0
	END
#########################################################
CREATE TRIGGER trg_mt000_INSERT_CompositeMatPicture
ON mt000 AFTER INSERT
NOT FOR REPLICATION
AS
	IF @@ROWCOUNT = 0 RETURN
	SET NOCOUNT ON	

	IF NOT EXISTS(SELECT * FROM [inserted] WHERE Parent <> 0x0)
	RETURN;

	DECLARE @MatGuid UNIQUEIDENTIFIER; 
	DECLARE @ParentMatGuid UNIQUEIDENTIFIER; 
	DECLARE CompositeMatCursor CURSOR FOR
	SELECT 
	GUID ,
	Parent
	FROM [inserted] 
	WHERE Parent <> 0x0

	OPEN CompositeMatCursor; 
	FETCH NEXT FROM CompositeMatCursor INTO @MatGuid, @ParentMatGuid

	WHILE @@FETCH_STATUS = 0
	BEGIN
		
		EXEC prcUpdateCompositeMaterialPicture @ParentMatGuid , @MatGuid , 1

		FETCH NEXT FROM CompositeMatCursor INTO @MatGuid, @ParentMatGuid
	END

	CLOSE CompositeMatCursor
	DEALLOCATE CompositeMatCursor
#########################################################
CREATE TRIGGER trg_mt000_UPDATE_Combosition_BranchMask ON mt000
AFTER UPDATE 
NOT FOR REPLICATION
AS
	IF @@ROWCOUNT = 0 RETURN
	SET NOCOUNT ON

	IF NOT EXISTS (SELECT * FROM INSERTED I INNER JOIN DELETED D ON I.GUID = D.GUID WHERE I.HasSegments = 1 AND D.branchMask <> I.branchMask) 
		RETURN 

	UPDATE mt000    
	SET branchMask = I.branchMask 
	FROM
		mt000 MT
		INNER JOIN INSERTED I ON I.GUID = MT.Parent  
	WHERE MT.branchMask <> I.branchMask
#########################################################
CREATE TRIGGER trg_mt000_UpdateMatName
   ON mt000  
   AFTER UPDATE ,INSERT
   NOT FOR REPLICATION
AS BEGIN
	IF @@ROWCOUNT = 0 RETURN
	SET NOCOUNT ON

	DECLARE @IncludeCompositionInMatName INT;
	SET @IncludeCompositionInMatName = ISNULL((SELECT TOP 1 CAST(Value AS INT) FROM op000 WHERE Name = 'AmnCfg_IncludeCompositionInMatName'), 0) 
	
	IF @IncludeCompositionInMatName <> 1 
		RETURN

    IF EXISTS(SELECT * FROM deleted WHERE PARENT != 0X0) AND (UPDATE(CompositionName) OR UPDATE(CompositionLatinName))
	BEGIN
		UPDATE MT
		SET name = REPLACE(MT.Name, D.CompositionName, I.CompositionName),
			LatinName = REPLACE(MT.LatinName, D.CompositionLatinName, I.CompositionLatinName)
		FROM mt000 MT
		INNER JOIN Inserted I  ON MT.GUID = I.GUID
		INNER JOIN deleted D  on MT.GUID = D.GUID
		WHERE MT.PARENT != 0X0
	END 
	IF NOT EXISTS(SELECT * FROM deleted) AND EXISTS(SELECT * FROM inserted WHERE PARENT != 0X0)
	BEGIN
		UPDATE MT
		SET name = I.Name + CASE WHEN I.Parent != 0X0 THEN + ' (' + I.CompositionName + ')' ELSE  '' END,
			LatinName =  I.LatinName + CASE WHEN I.Parent != 0X0 THEN
			CASE WHEN ( I.CompositionLatinName = '' OR I.CompositionLatinName = '-') THEN '' ELSE  + ' (' + I.CompositionLatinName + ')' END ELSE  '' END
		FROM mt000 MT
		INNER JOIN Inserted I  ON MT.GUID = I.GUID
		WHERE MT.PARENT != 0X0
	END
END
#########################################################
#END