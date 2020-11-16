####################################################
###### prcDistInitMatSnOfDistributor
CREATE PROC prcDistInitMatSnOfDistributor
	@DistGuid	UNIQUEIDENTIFIER 
AS 
	SET NOCOUNT ON  
	DELETE DistDeviceSN000 WHERE DistributorGUID = @DistGUID    
	DECLARE @bExportSerialNum		BIT, 
			@StoreGuid				UNIQUEIDENTIFIER
	SELECT @bExportSerialNum = ISNULL( [ExportSerialNumFlag], 0), @StoreGuid = StoreGuid  
	FROM vwDistributor WHERE Guid = @DistGuid 
	IF @bExportSerialNum = 0 
		RETURN 
	------------------------------------------------------------------------------------- 
	--------- From "repMatSn"INSERT INTO DistDeviceMT000(   Stored Procedure 
	CREATE TABLE #MatSn(  
		[ID]			[INT] IDENTITY(0,1),  
		[SN]			[NVARCHAR](255)  COLLATE ARABIC_CI_AI,  
		[snGuid]        [UNIQUEIDENTIFIER],  
		[mtGuid]		[UNIQUEIDENTIFIER],  
		[stGuid]		[UNIQUEIDENTIFIER],  
		[biGuid]        [UNIQUEIDENTIFIER],   
		[Direction]     [INT],  
	 )  
	INSERT INTO #MatSn( SN, snGuid, mtGuid, stGuid, biGuid, Direction ) 
	SELECT  
		  ISNULL([snc].[SN] , ''),		 
		  ISNULL([snc].[GUID] , 0x0),     
		  ISNULL([snc].[MatGuid] , 0x0),  
		  ISNULL([bi].[StoreGUID],0x0),	 
		  ISNULL([bi].[GUID],0x0),	
		  CASE bt.bIsInput WHEN 0 THEN -1 ELSE 1 END   AS Direction
		/* 
		  CASE bt.BillType  WHEN 0 THEN  1 	WHEN 1 THEN -1 	WHEN 2 THEN  1 	WHEN 3 THEN -1 	WHEN 4 THEN  1 	WHEN 5 THEN -1 	ELSE 0   END AS [Direction] 
		*/ 
	FROM [snc000] AS snc     
		  INNER JOIN [snt000]AS snt ON [snc].[GUID] = [snt].ParentGUID  
		  INNER JOIN [bu000] AS bu ON [snt].[buGuid] = [bu].[GUID]  
		  INNER JOIN [bi000] AS bi ON [snt].[biGUID] = [bi].[GUID]  
		  INNER JOIN [bt000] AS bt ON [bu].[TypeGUID] = [bt].[GUID]  
		  INNER JOIN [DistDeviceMt000] AS mt ON [snc].[MatGUID] = [mt].[mtGUID] AND mt.DistributorGuid = @DistGuid AND snFlag = 1 
		  LEFT JOIN  [DistDeviceSt000] AS st ON [bi].[StoreGUID] = [st].[stGUID] AND st.DistributorGuid = @DistGuid 
	WHERE  
		(bi.StoreGuid = @StoreGuid AND ISNULL(st.stGuid, 0x00) = 0x00) OR (ISNULL(st.stGuid, 0x00) <> 0x00 )			  
	ORDER BY [SN]  , bu.[Date] , [Direction]  , bu.Number
------------------------------------------------------------------------------------------  
	CREATE TABLE #temp1 ([SN] [NVARCHAR](255)  COLLATE ARABIC_CI_AI , _SUM [INT] , [ID] [INT])  
	INSERT INTO #temp1  
	SELECT ISNULL(SN,'') AS SN , SUM(Direction) AS [Direction] , MAX(ID) AS [GID]  
	FROM #MatSn 
	GROUP BY [SN] , [mtGuid]  
	DELETE FROM #temp1 WHERE _Sum = 0  
	------------------------------------------------------------------------------------ 
	--- Return first Result Set -- needed data  
	INSERT INTO DistDeviceSN000 (  
		Guid, Item, Sn, InGuid, OutGuid, Notes, MatGuid, DistributorGUID)     
	SELECT  
		snGuid,	0, SN.SN, sn.biGuid, 0x00, sn.stGuid, sn.mtGuid, @DistGuid 
	FROM  
		[#MatSn] AS [sn] INNER JOIN [#temp1] AS [t] ON [sn].[Id] = [t].[Id] 
	  
/*
EXEC prcConnections_Add2 '„œÌ—'
EXEC prcDistInitMatSnOfDistributor '3CA230D3-DAFE-426B-BDFC-327A36AF76B0'
*/
####################################################
###### prcDistInitMatOfDistributor
CREATE PROCEDURE prcDistInitMatOfDistributor
		@DistributorGUID uniqueidentifier   
AS        
	SET NOCOUNT ON         
	-----------------------------------
	DECLARE @IsGCCEnabled BIT = (SELECT [dbo].[fnOption_GetBit]('AmnCfg_EnableGCCTaxSystem', DEFAULT))
	------------------------------------ 
	DECLARE @PostedInvenytoryAfterRealizeOrders BIT
	DECLARE @CalcPurchaseOrderRemindedQtyIsChecked INT = dbo.fnOption_GetInt('AmnCfg_CalcPurchaseOrderRemindedQty', '0') 
	------------------------------------     
	DECLARE	@GroupGUID 			UNIQUEIDENTIFIER,    
		@MatCondId 				INT,   
		@MatCondGuid			UNIQUEIDENTIFIER,      
		@MatSortFld 			NVARCHAR(250),       
		@StoreGUID 				UNIQUEIDENTIFIER,  
		@OrderStoreGUID 				UNIQUEIDENTIFIER,      
		@CheckStoreGUID 		UNIQUEIDENTIFIER,    
		@CanUseGPRS BIT, 
		@bExportEmptyMaterial 	BIT,       
		@ExportStoreGuid 		UNIQUEIDENTIFIER,    
		@ExportStoreFlag		INT,    
		@SalesManGuid 			UNIQUEIDENTIFIER,    
		@CostGuid 				UNIQUEIDENTIFIER
------------------------------------     
	SELECT @PostedInvenytoryAfterRealizeOrders = dst.PostedInvenytoryAfterRealizeOrders FROM Distributor000 dst 
			WHERE GUID = @DistributorGUID
------------------------------------     
	SELECT      
		@GroupGUID 				= ISNULL( [MatGroupGUID], 0x0),      
		@MatCondId 				= ISNULL( [MatCondId], 0),   
		@MatCondGuid			= ISNULL( [MatCondGuid], 0x0),     
		@MatSortFld 			= ISNULL( [MatSortFld], 0),      
		@StoreGUID 				= ISNULL( [StoreGUID], 0x0),   
		@OrderStoreGUID			= ISNULL( [OrderStoreGuid], 0x0),   
		@CheckStoreGUID 		= ISNULL([VerificationStore], 0x0),      
		@CanUseGPRS				= ISNULL(CanUseGPRS, 0), 
		@bExportEmptyMaterial 	= ISNULL( [ExportEmptyMaterialFlag], 0),      
		@ExportStoreGuid 		= ISNULL( [ExportStoreGuid], 0x0),      
		@ExportStoreFlag 		= ISNULL( [ExportStoreFlag], 0),    
		@SalesManGuid 			= ISNULL( [PrimSalesmanGUID], 0x0)  
	FROM      
		[vwDistributor]     
	WHERE      
		[GUID] = @DistributorGUID      
	SELECT @CostGuid = ISNULL([CostGuid], 0x00) FROM [DistSalesMan000] Where [Guid] = @SalesMAnGUID    
	------------------------------------     
	CREATE TABLE #GroupTbl(                
		[GUID] 		uniqueidentifier,       
		[ParentGUID] 	uniqueidentifier,       
		[Name] 		NVARCHAR(255)  COLLATE Arabic_CI_AI,
		[LatinName] 		NVARCHAR(255)  COLLATE Arabic_CI_AI,       
		[HasMats] 		int,     
		[Level] 	int     
	)     
	------------------------------------     
	CREATE TABLE #MatCond ( [GUID] uniqueidentifier, [Security] INT)          
	INSERT INTO #MatCond EXEC prcPalm_GetMatsList @MatCondId , @MatCondGuid       
	------------------------------------     
	CREATE TABLE #MatTbl(       
		[GUID] 		uniqueidentifier,          
		[GroupGUID] 	uniqueidentifier,          
		[Code] 		NVARCHAR(255)  COLLATE Arabic_CI_AI,                
		[BarCode] 	NVARCHAR(255) COLLATE Arabic_CI_AI,                 
		[BarCode2] 	NVARCHAR(255) COLLATE Arabic_CI_AI,                 
		[BarCode3] 	NVARCHAR(255) COLLATE Arabic_CI_AI,                 
		[Name] 		NVARCHAR(255) COLLATE Arabic_CI_AI,                 
		[LatinName] 	NVARCHAR(255) COLLATE Arabic_CI_AI,             
		[Price1] 		float,                 
		[Price2] 		float,                 
		[Price3] 		float,                 
		[Price4] 		float,                 
		[Price5] 		float,                 
		[Price6] 		float,                 
		[Price1Unit2] 	Float,                 
		[Price2Unit2] 	float,                 
		[Price3Unit2] 	float,                 
		[Price4Unit2] 	float,                 
		[Price5Unit2] 	Float,                 
		[Price6Unit2] 	Float,                 
		[Price1Unit3] 	float,                 
		[Price2Unit3] 	float,                 
		[Price3Unit3] 	float,                 
		[Price4Unit3] 	float,                 
		[Price5Unit3] 	Float,                 
		[Price6Unit3] 	Float,  
		[Unity] 		NVARCHAR(255) COLLATE Arabic_CI_AI,                 
		[Unit2] 		NVARCHAR(255) COLLATE Arabic_CI_AI,                 
		[Unit3] 		NVARCHAR(255) COLLATE Arabic_CI_AI,                 
		[Unit2Fact] 	float,        
		[Unit3Fact] 	float,        
		[Qty] 			float,        
		[DefUnit] 		int,     
		[SNFlag]		INT,     
		[ForceInSN]		INT,     
		[ForceOutSN]	INT,   
		[MatTemplateGuid]	UNIQUEIDENTIFIER,  
		[BonusOne] 		float,        
		[Bonus] 		float,        
		[VAT] 			float,
		[Promotions]	NVARCHAR(255),
		[Discounts]		NVARCHAR(255),
		[bHide]			INT, 
		[PicturePath]   NVARCHAR(1000) COLLATE Arabic_CI_AI,
		[CurrencyGUID]  UNIQUEIDENTIFIER,
		[CurrencyValue]	FLOAT
	)     
	CREATE TABLE #MsTbl    
	(    
		[GUID] 				Uniqueidentifier,    
		[MatGUID] 			Uniqueidentifier,    
		[StoreGUID]			Uniqueidentifier,    
		[Qty]				FLOAT DEFAULT (0),
		[ReservedQty]		FLOAT DEFAULT (0)     
	)    
		
	CREATE TABLE #TemplatesDetail    
	(    
		[TemplateGuid]	UNIQUEIDENTIFIER,    
		[GroupGuid]	UNIQUEIDENTIFIER    
	)    
	DECLARE @CTemplates	CURSOR,    
		@TGuid		UNIQUEIDENTIFIER,    
		@GGuid		UNIQUEIDENTIFIER    
	SET @CTemplates = CURSOR FAST_FORWARD FOR    
		SELECT [Guid], [GroupGuid] FROM [DistMatTemplates000] ORDER BY [Number]    
	OPEN @CTemplates FETCH FROM @CTemplates INTO @TGuid, @GGuid    
	WHILE @@FETCH_STATUS = 0    
	BEGIN    
		INSERT INTO #TemplatesDetail    
			 SELECT @TGuid, [Guid] FROM fnGetGroupsList( @GGuid)     
		FETCH FROM @CTemplates INTO @TGuid, @GGuid    
	END    
	CLOSE @CTemplates DEALLOCATE @CTemplates    
	------------------------------------     
	CREATE TABLE #MatList (MatGUID UNIQUEIDENTIFIER ,Security INT) 
	IF (@GroupGUID = 0x0)   
	BEGIN                     
		INSERT INTO #GroupTbl                        
			SELECT [grGUID] , [grParent], [grName],[grLatinName], 0, 0 From [vwGr]  
			
		 INSERT INTO #MatList                        
			SELECT mtGUID , 1 From [vwMt]             
	END         
	ELSE
	BEGIN                                               
		INSERT INTO #MatList EXEC [prcGetMatsList]  0x0, @GroupGUID, -1, 0x0 
		INSERT INTO #GroupTbl           
		SELECT DISTINCT gr.GUID, gr.ParentGUID, gr.Name, gr.LatinName, 0 ,0
		FROM #MatList mtL
			INNER JOIN mt000 mt ON mt.GUID = mtL.MatGUID
			INNER JOIN gr000 gr ON gr.GUID = mt.GroupGuid     
	END 
	------------------------------------     
	INSERT INTO #MatTbl                        
	(               
		[GUID],               
		[GroupGUID],               
		[Code],               
		[BarCode],               
		[BarCode2],               
		[BarCode3],               
		[Name],               
		[LatinName],               
		[Price1],               
		[Price2],               
		[Price3],               
		[Price4],               
		[Price5],                 
		[Price6],                 
		[Price1Unit2],               
		[Price2Unit2],               
		[Price3Unit2],               
		[Price4Unit2],               
		[Price5Unit2],                 
		[Price6Unit2],                 
		[Price1Unit3],               
		[Price2Unit3],               
		[Price3Unit3],               
		[Price4Unit3],               
		[Price5Unit3],                 
		[Price6Unit3], 	                 
		[Unity],               
		[Unit2],               
		[Unit3],                 
		[Unit2Fact],                 
		[Unit3Fact],                 
		[Qty],        
		[DefUnit],        
		[SNFlag],     
		[ForceInSN],     
		[ForceOutSN],   
		[MatTemplateGUID],  
		[BonusOne],        
		[Bonus],  
		[VAT],
		[Promotions],
		[Discounts],
		[bHide], 
		[PicturePath],
		[CurrencyGUID],
		[CurrencyValue]
	)               
		SELECT                 
			[mt].[mtGUID],                
			[mt].[mtGroup],                
			[mt].[mtCode],                
			[mt].[mtBarCode],                
			[mt].[mtBarCode2],               
			[mt].[mtBarCode3],               
			[mt].[mtName],                
			[mt].[mtLatinName],                
			[mt].[mtWhole]		AS Price1,                
			[mt].[mtHalf]		AS Price2,         
			[mt].[mtVendor]		AS Price3,     
			[mt].[mtExport]		AS Price4,     
			[mt].[mtRetail]		AS Price5,  
			[mt].[mtEndUser]	AS Price6,  
			[mt].[mtWhole2]		AS Price1Unit2,         
			[mt].[mtHalf2]		AS Price2Unit2,         
			[mt].[mtVendor2]	AS Price3Unit2,     
			[mt].[mtExport2]	AS Price4Unit2,     
			[mt].[mtRetail2]	AS Price5Unit2,  
			[mt].[mtEndUser2]	AS Price6Unit2,  
			[mt].[mtWhole3]		AS Price1Unit3,         
			[mt].[mtHalf3]		AS Price2Unit3,         
			[mt].[mtVendor3]	AS Price3Unit3,     
			[mt].[mtExport3]	AS Price4Unit3,     
			[mt].[mtRetail3]	AS Price5Unit3,  
			[mt].[mtEndUser3]	AS Price6Unit3,  
			[mt].[mtUnity],                
			[mt].[mtUnit2],                
			[mt].[mtUnit3],                
			[mt].[mtUnit2Fact],                
			[mt].[mtUnit3Fact],                
			0,        
			[mt].[mtDefUnit],     
			[mt].[mtSNFlag],     
			[mt].[mtForceInSN],     
			[mt].[mtForceOutSN],   
			ISNULL([td].[TemplateGuid], 0x0),  
			[mt].[mtBonusOne],        
			[mt].[mtBonus],  
			CASE @IsGCCEnabled WHEN 0 THEN [mt].[mtVAT] ELSE ISNULL(GCC.Ratio, 0) END,
			'',
			'',
			[mt2].[bHide], 
			ISNULL([bm].[Name], ''),
			mt.mtCurrencyPtr,
			mt.mtCurrencyVal
		FROM           
			[vwMt] AS mt    
			INNER JOIN #MatList mtl ON mtl.MatGUID = mt.mtGUID
			INNER JOIN #MatCond AS [mTcn] ON [mTcn].[GUID] = [mt].[mtGUID]               
			LEFT JOIN #TemplatesDetail AS td ON [td].[GroupGUID] = [mt].[mtGroup]   
			INNER JOIN mt000 mt2 ON mt2.Guid = [mt].[mtGUID]
			LEFT JOIN bm000 bm ON bm.GUID = mt.mtPicture
			LEFT JOIN GCCMaterialTax000 GCC on mt.mtGUID = gcc.MatGUID AND GCC.TaxType = 1

	;WITH CTE (GUID, ParentGUID, Name, LatinName) AS
	(
		SELECT GUID, ParentGUID, Name, LatinName
			FROM gr000 WHERE GUID IN (select guid from #GroupTbl)
		UNION ALL
		SELECT gr.GUID, gr.ParentGUID, gr.Name, gr.LatinName
			FROM gr000 gr INNER JOIN CTE  ON gr.GUID = CTE.ParentGUID
	)
	INSERT INTO #GroupTbl
	SELECT DISTINCT CTE.*, 0, 0 FROM  CTE WHERE GUID NOT IN (SELECT GUID FROM #GroupTbl)
	------------------------------------     
	DELETE DistDeviceST000 WHERE DistributorGUID = @DistributorGUID     
	DELETE DistDeviceGR000 WHERE DistributorGUID = @DistributorGUID     
	DELETE DistDeviceMT000 WHERE DistributorGUID = @DistributorGUID     
	DELETE DistDeviceMS000 WHERE DistributorGUID = @DistributorGUID     
	DELETE DistDeviceActiveLines000 WHERE DistributorGUID = @DistributorGUID    
	DELETE DistDeviceMatExBarcode000 WHERE DistributorGUID = @DistributorGUID    
	
	--EXEC RecalcMs000
	------------------------------------     
	---  Export Stores    «·„” Êœ⁄« 
	IF (@ExportStoreFlag = 1 AND @ExportStoreGUID <> 0x0)    
	BEGIN    
		INSERT INTO DistDeviceSt000	    
				(	    
					[stGuid],     
					[DistributorGuid],     
					[ParentGuid],     
					[CustGuid],     
					[Name],
					[LatinName]  
				)    
		SELECT     
				[fn].[Guid],     
				@DistributorGuid,     
				[st].[stParent],     
				ISNULL([cu].[CuGuid], 0x0),    -- ISNULL([ce].[CustomerGuid], 0x0),  
				[st].[stName],
				[st].[stLatinName]     
		FROM     
			dbo.fnGetStoresList(@ExportStoreGuid) AS [fn]    
			INNER JOIN [vwSt] AS [st] ON [st].[stGuid] = [fn].[Guid]    
			INNER JOIN DistDeviceCu000 AS cu ON cu.StoreGuid = [fn].[Guid] AND cu.DistributorGuid = @DistributorGuid
		WHERE [fn].[Guid] <> @StoreGuid AND [fn].[Guid] <> @OrderStoreGUID 
		/*SELECT     
			[fn].[Guid],     
			@DistributorGuid,     
			[st].[stParent],     
			ISNULL([cu].[CuGuid], 0x0),    -- ISNULL([ce].[CustomerGuid], 0x0),  
			[st].[stName]     
		FROM     
			dbo.fnGetStoresList(@ExportStoreGuid) AS [fn]    
			INNER JOIN [vwSt] AS [st] ON [st].[stGuid] = [fn].[Guid]    
			LEFT JOIN DistDeviceCu000 AS cu ON cu.StoreGuid = [fn].[Guid] AND cu.DistributorGuid = @DistributorGuid
		WHERE 
			[fn].[Guid] = @StoreGuid OR 
			[fn].[Guid] = @ExportStoreGUID		*/		
	END  
	-- „” Êœ⁄ «·„‰œÊ»
	INSERT INTO DistDeviceSt000	    
			(	    
				[stGuid],     
				[DistributorGuid],     
				[ParentGuid],     
				[CustGuid],     
				[Name],
				[LatinName]    
			)    
	SELECT     
		[st].[stGuid],     
		@DistributorGuid,     
		[st].[stParent],     
		0x0,
		[st].[stName],
		[st].[stLatinName]      
	FROM     
		[vwSt] AS [st]
	WHERE 
		[st].[stGuid] = @StoreGUID OR [st].[stGuid] = @OrderStoreGUID
	--************************************************* 
	--  ’œÌ— Ã—œ „” Êœ⁄ «· Õﬁﬁ 

	SELECT 
		[biStorePtr] as [StoreGUID],
		[biMatPtr] as [MatGUID] , 
		Sum([buDirection]* ([biQty]+[biBonusQnt])) Qty
	INTO #MS
	FROM [vwBuBi]
	WHERE [buIsPosted] <> 0
	GROUP BY [biStorePtr],[biMatPtr];

	IF (@CanUseGPRS = 1) 
	BEGIN 
		INSERT INTO DistDeviceSt000	    
				(	    
					[stGuid],     
					[DistributorGuid],     
					[ParentGuid],     
					[CustGuid],     
					[Name],
					[LatinName]    
				)    
		SELECT     
			@CheckStoreGUID,     
			@DistributorGuid,     
			[st].[stParent],     
			0x0,
			[st].[stName],
			[st].[stLatinName]     
		FROM     
			[vwSt] AS [st]
		WHERE 
			[st].[stGuid] = @CheckStoreGUID
				
		INSERT INTO #MsTbl ( [GUID], [MatGUID], [StoreGUID], [Qty] ) 	    
		SELECT 
			newID(), [mt].[GUID], @CheckStoreGUID, ISNULL([ms].[Qty], 0)    
		FROM     
			#MatTbl AS [mt]    
			LEFT JOIN #MS AS [ms] ON [mt].[GUID] = [ms].[MatGUID] AND [ms].[StoreGUID] = @CheckStoreGUID   
	END 
		
	--  ’œÌ— Ã—œ „” Êœ⁄ «·„‰œÊ»    
	INSERT INTO #MsTbl ( [GUID], [MatGUID], [StoreGUID], [Qty] ) 	    
	SELECT     
		newID(), [mt].[GUID], @StoreGUID, ISNULL([ms].[Qty], 0)    
	FROM     
		#MatTbl AS [mt]    
		LEFT JOIN #MS AS [ms] ON [mt].[GUID] = [ms].[MatGUID] AND [ms].[StoreGUID] = @StoreGUID   
	WHERE
		NOT EXISTS (SELECT 1 FROM #MsTbl subms WHERE subms.StoreGUID = [ms].[StoreGUID] AND subms.MatGUID = [ms].[MatGUID]) -- if exists then it is already inserted above
	IF(@OrderStoreGUID <> 0x0)
	BEGIN
		INSERT INTO #MsTbl ( [GUID], [MatGUID], [StoreGUID], [Qty], [ReservedQty] ) 	    
		SELECT     
			newID()
			,[mt].[GUID]
			,@OrderStoreGUID
			,CASE WHEN @PostedInvenytoryAfterRealizeOrders = 1 AND @CalcPurchaseOrderRemindedQtyIsChecked = 0
			      THEN (ISNULL([ms].[Qty], 0) + dbo.fnGetPurchaseOrdRemaindedQty2([mt].[GUID], @OrderStoreGUID, 0x0) - dbo.fnGetSalesOrdRemaindedQty2([mt].[GUID], @OrderStoreGUID, 0x0))
				  WHEN @CalcPurchaseOrderRemindedQtyIsChecked = 1
				  THEN (ISNULL([ms].[Qty], 0) + dbo.fnGetPurchaseOrdRemaindedQty2([mt].[GUID], @OrderStoreGUID, 0x0))
				  ELSE ISNULL([ms].[Qty], 0)
			 END
			,dbo.fnGetReservedQty([mt].[GUID],@OrderStoreGUID,0x0)
		FROM     
			#MatTbl AS [mt]    
			LEFT JOIN [ms000] AS [ms] ON [mt].[GUID] = [ms].[MatGUID] AND [ms].[StoreGUID] = @OrderStoreGUID
	END
	--  ’œÌ— Ã—œ „” Êœ⁄«  «·„‰«ﬁ·… 
	IF (@ExportStoreFlag = 1 AND @ExportStoreGUID <> 0x0)    
	BEGIN
	
		INSERT INTO #MsTbl ( [GUID], [MatGUID], [StoreGUID], [Qty] ) 	    
		SELECT     
			newId(), [ms].[MatGUID], [ms].[StoreGUID], [ms].[Qty]    
		FROM     
			#MS AS ms    
			INNER JOIN #MatTbl AS mt ON [mt].[GUID] = [ms].[MatGUID]	    
			INNER JOIN [DistDeviceSt000] AS [st] ON [st].[stGUID] = [ms].[StoreGUID]     
		WHERE   
			[st].[DistributorGUID] = @DistributorGUID AND
			NOT EXISTS (SELECT 1 FROM #MsTbl subms WHERE subms.StoreGUID = [ms].[StoreGUID] AND subms.MatGUID = [ms].[MatGUID]) -- if exists then it is already inserted above
	END
	
	--  Ã„Ì⁄ «·ﬂ„Ì« 	
	UPDATE #MatTbl SET [Qty] = [Total].[msQty]    
	FROM 	(    
			SELECT [matGuid] , SUM([ms].[Qty]) AS msQty     
			FROM #msTbl AS [ms]   
			GROUP BY [matGUID]    
		) AS Total     
		INNER JOIN #MatTbl AS [mt] ON [mt].[GUID] = [Total].[matGUID]
	------------------------------------     
	----- Delete Empty Material          
	IF (@bExportEmptyMaterial = 0)          
	BEGIN          
		DELETE #MatTbl   
			FROM #MatTbl AS mt    
			LEFT JOIN DistDeviceActiveLines000 AS al ON al.MatGuid = mt.GUID   
		WHERE Qty <=0 AND ISNULL(al.GUID, 0x0) = 0x0     
	   
		DELETE #msTbl WHERE Qty <=0   
	END          
	------------------------------------     
	-- Delete Empty Group        
	while EXISTS (     
			SELECT GUID FROM #GroupTbl      
			WHERE      
				GUID NOT IN (SELECT DISTINCT GroupGUID FROM #MatTbl) AND      
				GUID NOT IN (SELECT DISTINCT ParentGUID FROM #GroupTbl)     
			  )     
		DELETE #GroupTbl        
		WHERE        
			GUID NOT IN (SELECT DISTINCT GroupGUID FROM #MatTbl) AND      
			GUID NOT IN (SELECT DISTINCT ParentGUID FROM #GroupTbl)     
	UPDATE #GroupTbl SET ParentGUID = 0x0 WHERE GUID = @GroupGUID        
	------------------------------------   	
	-- Calc MatGroup Flag        
	UPDATE #GroupTbl        
	SET        
		[HasMats] = 1,      
		[Level] = 2      
	WHERE        
		GUID IN (SELECT GroupGUID FROM #MatTbl)        
		
	UPDATE #GroupTbl     
	SET        
		[HasMats] = 0,      
		[Level] = 1      
	WHERE        
		GUID NOT IN (SELECT GroupGUID FROM #MatTbl)        
		--GUID IN (SELECT GroupGUID FROM #GroupTbl)        
	------------------------------------     
	INSERT INTO DistDeviceGr000(     
		[grGUID],     
		[DistributorGUID],     
		[ParentGUID],     
		[Name],
		[LatinName],      
		[HasMats],     
		[Level]     
	)     
	SELECT     
		[GUID],     
		@DistributorGUID,     
		[ParentGUID],     
		[Name],
		[LatinName],     
		[HasMats],     
		[Level]     
	FROM     
		#GroupTbl     
	------------------------------------     
	INSERT INTO DistDeviceMT000(        
		[mtGUID],     
		[DistributorGUID],     
		[GroupGUID],     
		[Code],     
		[Name], 
		[LatinName],    
		[Qty],     
		[InQty],     
		[OutQty],     
		[Barcode],     
		[Barcode2],     
		[Barcode3],     
		[Unity],     
		[Unit2],     
		[Unit3],     
		[Price1],     
		[Price2],     
		[Price3],     
		[Price4],     
		[Price5],     
		[Price6],     
		[Price1Unit2],     
		[Price2Unit2],     
		[Price3Unit2],     
		[Price4Unit2],     
		[Price5Unit2],     
		[Price6Unit2],     
		[Price1Unit3],     
		[Price2Unit3],     
		[Price3Unit3],     
		[Price4Unit3],     
		[Price5Unit3],     
		[Price6Unit3],     
		[Unit2Fact],     
		[Unit3Fact],     
		[DefUnit],     
		[SNFlag],     
		[ForceInSN],     
		[ForceOutSN],   
		[MatTemplateGUID],  
		[BonusOne],        
		[Bonus],  
		[VAT],
		[Promotions],  
		[Discounts],
		[bHide],
		[PicturePath],
		[CurrencyGUID],
		[CurrencyValue]
	)     
	SELECT          
		[GUID],     
		@DistributorGUID,     
		[GroupGUID],          
		[Code],          
		[Name],
		[LatinName],          
		[Qty],     
		0,     
		0,     
		[BarCode],          
		[BarCode2],          
		[BarCode3],          
		[Unity],          
		[Unit2],          
		[Unit3],          
		[Price1],          
		[Price2],          
		[Price3],          
		[Price4],          
		[Price5],          
		[Price6],          
		[Price1Unit2],          
		[Price2Unit2],          
		[Price3Unit2],          
		[Price4Unit2],          
		[Price5Unit2],          
		[Price6Unit2],          
		[Price1Unit3],          
		[Price2Unit3],          
		[Price3Unit3],          
		[Price4Unit3],          
		[Price5Unit3],          
		[Price6Unit3],          
		[Unit2Fact],          
		[Unit3Fact],          
		[DefUnit],     
		[SNFlag],     
		[ForceInSN],     
		[ForceOutSN],   
		[MatTemplateGUID],  
		[BonusOne],        
		[Bonus],  
		[VAT],
		'0',  
		'0',
		[bHide],
		[PicturePath],
		[CurrencyGUID],
		[CurrencyValue]
	FROM     
		#MatTbl AS [mt]    
	------------------------------------     
	INSERT INTO DistDeviceMS000    
		(    
			[GUID],    
			[DistributorGUID],    
			[MatGUID],    
			[StoreGUID],    
			[Qty],    
			[InQty],    
			[OutQty],
			[ReservedQty]    
		)    
	SELECT     
		[Guid],    
		@DistributorGUID,    
		[MatGuid],    
		[StoreGUID],    
		[Qty],    
		0,    
		0,
		ISNULL([ReservedQty], 0)
	FROM     
		#msTbl 
		 
	--------------------------------------------- Set AllChildMatsIsEmpty Flag For Groups 
	--Get Active Groups (Not Empty)	 
	CREATE TABLE #ActiveGroups 
		( 
			[GroupGuid]	UNIQUEIDENTIFIER    
		) 
		 
	INSERT INTO #ActiveGroups 
	Select Distinct 
		mt.GroupGuid 
	From  
		DistDeviceMt000 mt 
		INNER JOIN DistDeviceMs000 AS ms ON ms.MatGuid = mt.mtGuid 
	Where 
		mt.DistributorGuid = @DistributorGUID 
		AND MS.StoreGuid = (CASE WHEN @CanUseGPRS = 1 THEN @CheckStoreGUID 
									ELSE ( CASE WHEN @StoreGUID = MS.StoreGuid THEN @StoreGUID ELSE @OrderStoreGUID END ) END) 
		AND (ms.Qty + ms.InQty - ms.OutQty  > 0)  
	---------------------------------------	 
	-- Consider All Groups As Empty 
	UPDATE DistDeviceGr000 SET [AllChildMatsIsEmpty] = 1 
	DECLARE @ActiveGroups	CURSOR 
	DECLARE @ActiveGroupGuid		UNIQUEIDENTIFIER    
	SET @ActiveGroups = CURSOR FAST_FORWARD FOR    
	SELECT [GroupGuid] FROM #ActiveGroups 
	OPEN @ActiveGroups  
	FETCH FROM @ActiveGroups INTO @ActiveGroupGuid    
	WHILE @@FETCH_STATUS = 0    
	BEGIN    
		-- Set All Group Parents As Active 
		UPDATE  
			DistDeviceGr000  
		SET  
			[AllChildMatsIsEmpty] = 0 
		WHERE  
			grGuid IN (SELECT @ActiveGroupGuid UNION ALL SELECT Guid from dbo.fnGetGroupParents (@ActiveGroupGuid)) 
			AND DistributorGuid = @DistributorGUID 
	
		FETCH FROM @ActiveGroups INTO @ActiveGroupGuid    
	END    
	CLOSE @ActiveGroups  
	DEALLOCATE @ActiveGroups	
	
	 INSERT INTO DistDeviceMatExBarcode000 
	 SELECT	NEWID(),
			MatExBarcode.Number,
			MatExBarcode.MatGuid,
			MatExBarcode.MatUnit,
			MatExBarcode.Barcode,
			MatExBarcode.IsDefault,
			@DistributorGUID
	 FROM MatExBarcode000 AS MatExBarcode 
	 INNER JOIN (SELECT DISTINCT mtGuid FROM DistDeviceMT000 WHERE DistributorGUID = @DistributorGUID) AS distmt ON distmt.mtGuid = MatExBarcode.MatGuid

	-------------------------------------- 
	DROP table #GroupTbl     
	DROP table #MatTbl     
	Drop table #ActiveGroups 
	--------------------------------------  
/*
Select * from Distributor000

EXEC prcDistInitMatOfDistributor '86945365-345A-438A-B397-D2AA82CE4E9E'
SELECT * FROM DistDeviceST000

Select * from DistDeviceMs000 
Where DistributorGuid = '86945365-345A-438A-B397-D2AA82CE4E9E' 
AND MatGuid = 'AA592CBE-FA00-4CC9-8393-16CF9FFE9E4A'
Order by StoreGuid, MatGuid

Select * from St000
Select * from DistDevicemt000
Select * from Ms000 order by StoreGuid
Delete DistDeviceMs000

prcDistInitMatOfDistributor  '86945365-345A-438A-B397-D2AA82CE4E9E'
SELECT * FROM DistDeviceST000

Select * From dbo.fnGetStoresList('808396BA-E268-4381-B1F8-67800AF11A5C') AS [fn]    
Select * from St000

Select * from mt000
*/

/*
EXEC prcDistInitMatOfDistributor 'F6ADB10A-0DE6-40A0-94D5-04409EFA8293'
Select * from DistDeviceMt000 Where DistributorGuid = 'F6ADB10A-0DE6-40A0-94D5-04409EFA8293'
*/
#####################################################################################################
CREATE PROCEDURE prcDistGetMatsSerialNums
	@DistGuid UNIQUEIDENTIFIER

AS
BEGIN
   DECLARE @StoreGUID UNIQUEIDENTIFIER,
		  @ExportSerialNumFlag INT 
SET NOCOUNT ON
   SET	@StoreGUID = (select StoreGUID from Distributor000 where GUID = @DistGuid)
   SET @ExportSerialNumFlag = (select ExportSerialNumFlag from Distributor000 where GUID = @DistGuid) 
   DELETE DistDeviceSnc000
   INSERT INTO DistDeviceSnc000 ([GUID], SN, MatGUID, Qty,StGuid)
	  SELECT DISTINCT 
       snc.[guid],
       snc.sn,
       snc.MatGuid,
       snc.Qty,
       snc.stguid
    FROM vcSNs snc
    WHERE (
        SELECT SUM([buDirection])
        FROM [vcSNs] [sn]
        INNER JOIN vwbu B ON b.buGuid = sn.buGuid
        WHERE sn.MatGuid = snc.MatGUID
              AND sn.sn = snc.SN 
              AND b.buStorePtr = snc.stguid ) = 1 
              AND snc.stguid = @StoreGUID
			  AND snc.Qty = 1
			  AND @ExportSerialNumFlag = 1
    ORDER BY snc.sn
END
#####################################################################################################
CREATE PROCEDURE prcDist_PostSerialNumberTransactions
	@GUID AS UNIQUEIDENTIFIER,
	@Item AS FLOAT,
	@biGUID AS UNIQUEIDENTIFIER,
	@stGUID AS UNIQUEIDENTIFIER,
	@ParentGUID AS UNIQUEIDENTIFIER,
	@Notes AS NVARCHAR(250),
	@buGuid AS UNIQUEIDENTIFIER
AS
BEGIN

	SET NOCOUNT ON

	UPDATE snt000
	SET 
		Item = @Item,
		biGUID = @biGUID,
		stGUID = @stGUID,
		ParentGUID = @ParentGUID,
		Notes = @Notes,
		buGuid = @buGuid
	WHERE 
		GUID = @GUID
END
#####################################################################################################
CREATE PROC RecalcMs000 
AS
BEGIN
	DECLARE @USER_VAR VARCHAR(255) 
	
	SELECT TOP 1 @USER_VAR = LOGINNAME FROM US000 WHERE BADMIN=1 ORDER BY NUMBER 
	
	EXEC PRCCONNECTIONS_ADD2 @USER_VAR

	ALTER TABLE [ms000] DISABLE TRIGGER ALL
	DELETE [ms000]
	
	INSERT INTO [ms000] ([StoreGUID], [MatGUID],[Qty])
		SELECT [biStorePtr],[biMatPtr], Sum([buDirection]* ([biQty]+[biBonusQnt]))
		FROM [vwExtended_bi]
		WHERE [buIsPosted] <> 0
		GROUP BY [biStorePtr],[biMatPtr]
	ALTER TABLE [ms000] ENABLE TRIGGER ALL
END
#####################################################################################################
CREATE PROCEDURE prcDistInitLastPriceOfDistributor
	@DistributorGUID UNIQUEIDENTIFIER = 0x0
AS
BEGIN
	SET NOCOUNT ON

	DELETE FROM DistDeviceCp000 WHERE DistributorGuid = @DistributorGuid

	DECLARE @UseCustLastPrice BIT
	SELECT @UseCustLastPrice = dst.UseCustLastPrice FROM Distributor000 dst 
			WHERE GUID = @DistributorGUID
	DECLARE @CurrencyVal [FLOAT] = (SELECT my.CurrencyVal FROM op000 AS op INNER JOIN my000 AS my ON my.GUID = op.Value WHERE op.Name = 'AmnCfg_DefaultCurrency')
	DECLARE @CurrencyGuid UNIQUEIDENTIFIER = (SELECT Value FROM op000 WHERE Name = 'AmnCfg_DefaultCurrency')

	if(@UseCustLastPrice != 1)
	BEGIN
		RETURN
	END

	INSERT INTO DistDeviceCp000 
		SELECT	NEWID(),
				@DistributorGUID,
				cp.Price / @CurrencyVal,
				cp.Unity,
				cp.GUID,
				cp.CustGUID,
				cp.MatGUID,
				cp.DiscValue,
				cp.ExtraValue,
				@CurrencyVal,
				@CurrencyGuid,
				cp.Date
			From cp000 cp 
			INNER JOIN DistDeviceMt000 mt ON mt.mtGuid = cp.MatGUID AND mt.DistributorGUID = @DistributorGUID
			INNER JOIN DistDeviceCu000 cu ON cu.cuGuid = cp.CustGUID AND cu.DistributorGUID = @DistributorGUID
END
#####################################################################################################
CREATE PROCEDURE prcDistInitCF_ValueOfDistributor
	@DistributorGUID UNIQUEIDENTIFIER = 0x0,
	@TableMap NVARCHAR(max) = 'CustAddress000'
AS
BEGIN
	SET NOCOUNT ON

	DELETE FROM DistDeviceCF_Value000 WHERE DistributorGuid = @DistributorGuid

	DECLARE @TableName NVARCHAR(max),
			@sql NVARCHAR(max),
			@TableGUID UNIQUEIDENTIFIER

	Select @TableName = CFGroup_Table, @TableGUID = CFGroup_Guid from CFMapping000 
		WHERE Orginal_Table = @TableMap And IsMapped = 1
	if(@TableName IS NULL OR @TableGUID IS NULL)
	BEGIN  
		RETURN  
	END

	CREATE TABLE #Temp_DISTDevice
	(
		CV_TABLE_GUID UNIQUEIDENTIFIER,
		Dist_Orginal_Guid UNIQUEIDENTIFIER
	)

	SET @sql = 'INSERT INTO #Temp_DISTDevice
				Select CFV.GUID, CFV.Orginal_Guid FROM DistDeviceCustAddress000 DDCD INNER JOIN '+@TableName+' CFV ON CFV.Orginal_Guid = DDCD.AddressGUID 
				WHERE DDCD.DistributorGUID = '''+CONVERT(nvarchar(max), @DistributorGUID)+''''

	EXEC(@sql)

	Declare @cursorRowName nvarchar(max),
			@FldType INT,
			@DefaultINTValue INT

	Declare rowCursor CURSOR FOR SELECT FldType, ColumnName, IntDefaultValue FROM CFFlds000 WHERE GGuid = @TableGUID
	OPEN rowCursor FETCH NEXT FROM rowCursor INTO @FldType, @cursorRowName, @DefaultINTValue
	WHILE @@FETCH_STATUS = 0
	BEGIN
		Declare @cursorColumnValue nvarchar(max),
				@CF_GUID UNIQUEIDENTIFIER,
				@Orginal_Guid UNIQUEIDENTIFIER, 
				@Orginal_Table nvarchar(max),
				@ResultOfInsert NVARCHAR(max), 
				@IsSync BIT

		SET @sql = 'Declare columnCursor CURSOR FOR SELECT CV.GUID, CV.Orginal_Guid, CV.Orginal_Table, CV.'+@cursorRowName+' FROM '+ @TableName+' AS CV INNER JOIN #Temp_DISTDevice TDD ON TDD.CV_TABLE_GUID = CV.GUID'
		EXEC(@sql)
		OPEN columnCursor FETCH NEXT FROM columnCursor INTO @CF_GUID, @Orginal_Guid, @Orginal_Table, @cursorColumnValue
		WHILE @@FETCH_STATUS = 0
		BEGIN

		IF @FldType = 7 
		BEGIN
			Set @cursorColumnValue = (SELECT CONVERT(VARCHAR(5),CONVERT(DATETIME, @cursorColumnValue, 0), 108))
		END

		IF @FldType = 4
		BEGIN 
			Set @cursorColumnValue =(SELECT CONVERT(VARCHAR(10), CONVERT(DATETIME, @cursorColumnValue, 0), 23)) 
		END
			INSERT INTO DistDeviceCF_Value000 VALUES (NEWID(), @CF_GUID, @Orginal_Guid, @Orginal_Table, @DistributorGUID, @cursorRowName, @cursorColumnValue, '', 1)
			FETCH NEXT FROM columnCursor INTO @CF_GUID, @Orginal_Guid, @Orginal_Table, @cursorColumnValue
		END
		CLOSE columnCursor
		DEALLOCATE columnCursor
		FETCH NEXT FROM rowCursor INTO @FldType, @cursorRowName, @DefaultINTValue
	END
	CLOSE rowCursor
	DEALLOCATE rowCursor

	EXEC CheckCF_ValueDuplication @TableGUID, @TableName
END
#####################################################################################################
CREATE PROCEDURE SetCF_ValueFromDistCFDistributor
	@TableMap NVARCHAR(max) = 'CustAddress000'
AS
BEGIN
	SET NOCOUNT ON

	DECLARE @TableName NVARCHAR(max),
			@sql NVARCHAR(max),
			@TableGUID UNIQUEIDENTIFIER

	Select @TableName = CFGroup_Table, @TableGUID = CFGroup_Guid from CFMapping000 
		WHERE Orginal_Table = @TableMap And IsMapped = 1
	if(@TableName IS NULL OR @TableGUID IS NULL)
	BEGIN  
		RETURN  
	END

	EXEC CheckCF_ValueDuplication @TableGUID, @TableName, 0

	UPDATE Final_DDF SET IsSync = Temp_DDF.IsSync, ResultOfInsert = Temp_DDF.ResultOfInsert
	FROM DistDeviceCF_Value000 Final_DDF JOIN
											(SELECT Sub_DDF.*
												FROM DistDeviceCF_Value000 Sub_DDF
												WHERE Sub_DDF.IsSync = 0
											) Temp_DDF
	ON Temp_DDF.GUID_CF = Final_DDF.GUID_CF

   Declare @cursorCoulmnName nvarchar(max),
			@cursorColumnValue nvarchar(max),
			@CF_GUID UNIQUEIDENTIFIER,
			@Orginal_Guid UNIQUEIDENTIFIER, 
			@Orginal_Table nvarchar(max),
			@DistributorGUID UNIQUEIDENTIFIER

   Declare rowCursor CURSOR FOR SELECT GUID_CF, Orginal_GUID, Orginal_TABLE, DistributorGUID, Column_Name, New_Value FROM DistDeviceCF_Value000 WHERE IsSync = 1
   OPEN rowCursor FETCH NEXT FROM rowCursor INTO @CF_GUID, @Orginal_Guid, @Orginal_Table, @DistributorGUID, @cursorCoulmnName, @cursorColumnValue
   WHILE @@FETCH_STATUS = 0
   BEGIN
		SET @sql = 'SELECT 1 FROM '+@TableName+' WHERE GUID = '''+CONVERT(nvarchar(max), @CF_GUID)+''' AND Orginal_GUID = '''+CONVERT(nvarchar(max), @Orginal_Guid)+''''
		EXEC(@sql)
		If @@RowCount > 0
		BEGIN
			SET @sql = 'UPDATE '+@TableName+' SET '+@cursorCoulmnName+' = '''+@cursorColumnValue+''' WHERE GUID = '''+CONVERT(nvarchar(max), @CF_GUID)+''' AND Orginal_GUID = '''+CONVERT(nvarchar(max), @Orginal_Guid)+''''
			EXEC(@sql) 
		END
		ELSE
		BEGIN
			SET @sql = 'INSERT INTO '+@TableName+' (GUID, Orginal_GUID, Orginal_Table, '+@cursorCoulmnName+') VALUES ('''+CONVERT(nvarchar(max), @CF_GUID)+''', '''+CONVERT(nvarchar(max), @Orginal_Guid)+''', '''+@Orginal_Table+''', '''+@cursorColumnValue+''')'
			EXEC(@sql) 
		END
		FETCH NEXT FROM rowCursor INTO @CF_GUID, @Orginal_Guid, @Orginal_Table, @DistributorGUID, @cursorCoulmnName, @cursorColumnValue
	END
	CLOSE rowCursor
	DEALLOCATE rowCursor

END
#####################################################################################################
CREATE PROCEDURE CheckCF_ValueDuplication
	@TableGUID UNIQUEIDENTIFIER = 0x0,
	@Cf_valueTableName nvarchar(max),
	@AmenToDist Bit = 1

AS
BEGIN
	SET NOCOUNT ON
	UPDATE DistDeviceCF_Value000 SET IsSync = 1, ResultOfInsert = ''
	Declare @OrginalTableCount INT,
			@DistTableCount INT

	SET @OrginalTableCount = (SELECT COUNT(DISTINCT ColumnName) FROM CFFlds000 CFF
								INNER JOIN DistDeviceCF_Value000 DDV ON DDV.Column_Name = CFF.ColumnName 
								WHERE CFF.GGuid = @TableGUID)

	SET @DistTableCount = (select COUNT(DISTINCT Column_Name) from DistDeviceCF_Value000)

	IF @OrginalTableCount < @DistTableCount
	BEGIN
		Update DistDeviceCF_Value000
		SET		ResultOfInsert = 'Removed Field', 
				IsSync = 0 
		
		WHERE Column_Name in (SELECT Column_Name FROM DistDeviceCF_Value000 EXCEPT SELECT ColumnName FROM CFFlds000)
	END

	IF @OrginalTableCount > @DistTableCount
	BEGIN
		Update DistDeviceCF_Value000
		SET		ResultOfInsert = 'Added Field', 
				IsSync = 0 
		
		WHERE Column_Name in (SELECT ColumnName FROM CFFlds000 EXCEPT SELECT Column_Name FROM DistDeviceCF_Value000)

		UPDATE DDF_Table
			SET
				DDF_Table.New_Value =	CASE 
										WHEN CFF_Table.FldType = 2 OR CFF_Table.FldType = 3 THEN CFF_Table.FloatDefaultValue
										WHEN CFF_Table.FldType = 4  THEN (SELECT CONVERT(VARCHAR(5),CONVERT(DATETIME, CFF_Table.TextDefaultValue , 0), 108))
										WHEN CFF_Table.FldType = 7 AND CFF_Table.IntDefaultValue = 1 THEN (SELECT VALUE FROM OP000 WHERE NAME = 'AmnCfg_FPDate')
										WHEN CFF_Table.FldType = 7 AND CFF_Table.IntDefaultValue = 2 THEN (SELECT VALUE FROM OP000 WHERE NAME = 'AmnCfg_EPDate')
										WHEN CFF_Table.FldType = 7 AND CFF_Table.IntDefaultValue = 3 THEN (SELECT CONVERT(VARCHAR(10), 
											CONVERT(DATETIME, GETDATE(), 0), 23))
										WHEN CFF_Table.FldType = 7 AND CFF_Table.IntDefaultValue = 4 THEN (SELECT CONVERT(VARCHAR(10), 
											CONVERT(DATETIME, (SELECT DATEADD(month, DATEDIFF(month, 0, GETDATE()), 0)) , 0), 23))
										WHEN CFF_Table.FldType = 0 THEN CFF_Table.TextDefaultValue
										ELSE CFF_Table.TextDefaultValue
										END																
				
			FROM
				DistDeviceCF_Value000 AS DDF_Table
				INNER JOIN CFFlds000 AS CFF_Table
					ON DDF_Table.Column_Name = CFF_Table.ColumnName AND CFF_Table.GGuid = @TableGUID
					
	END

	IF @AmenToDist = 0
	BEGIN
		UPDATE DDF_Table
		SET
			DDF_Table.ResultOfInsert = DDF_Table.ResultOfInsert + 'Can''t Convert '''+DDF_Table.New_Value+ ''' To Float' ,
			DDF_Table.IsSync = 0															
		FROM
			DistDeviceCF_Value000 AS DDF_Table  
			INNER JOIN CFFlds000 AS CFF_Table 
			ON DDF_Table.Column_Name = CFF_Table.ColumnName
		WHERE
			CFF_Table.GGuid = @TableGUID AND 
			(CFF_Table.FldType = 2 OR CFF_Table.FldType = 3) AND
			DDF_Table.New_Value IS NOT NULL AND
			ISNUMERIC(DDF_Table.New_Value) <> 1 
		
		UPDATE DDF_Table
		SET
			DDF_Table.ResultOfInsert = DDF_Table.ResultOfInsert + 'Can''t Convert '''+DDF_Table.New_Value+ ''' To Int' ,
			DDF_Table.IsSync = 0															
			
		FROM
			DistDeviceCF_Value000 AS DDF_Table  
			INNER JOIN CFFlds000 AS CFF_Table 
			ON DDF_Table.Column_Name = CFF_Table.ColumnName
		WHERE
			CFF_Table.GGuid = @TableGUID AND 
			(CFF_Table.FldType = 1 OR CFF_Table.FldType = 6) AND
			DDF_Table.New_Value IS NOT NULL AND
			( ISNUMERIC(DDF_Table.New_Value) <> 1 OR 
													(ISNUMERIC(DDF_Table.New_Value) = 1  AND
													  FLOOR(DDF_Table.New_Value) <> CEILING(DDF_Table.New_Value)))
		
		UPDATE DDF_Table
		SET
			DDF_Table.ResultOfInsert = DDF_Table.ResultOfInsert +  'Can''t Convert '''+DDF_Table.New_Value+ ''' To Date' ,
			DDF_Table.IsSync = 0															
			
		FROM
			DistDeviceCF_Value000 AS DDF_Table  
			INNER JOIN CFFlds000 AS CFF_Table 
			ON DDF_Table.Column_Name = CFF_Table.ColumnName
		WHERE
			CFF_Table.GGuid = @TableGUID AND 
			CFF_Table.FldType = 4 AND
			DDF_Table.New_Value IS NOT NULL AND
			ISDate(DDF_Table.New_Value) <> 1
		
		UPDATE DDF_Table
		SET
			DDF_Table.ResultOfInsert = DDF_Table.ResultOfInsert + 'Can''t Convert '''+DDF_Table.New_Value+ ''' To Time' ,
			DDF_Table.IsSync = 0															
			
		FROM
			DistDeviceCF_Value000 AS DDF_Table  
			INNER JOIN CFFlds000 AS CFF_Table 
			ON DDF_Table.Column_Name = CFF_Table.ColumnName
		WHERE
			CFF_Table.GGuid = @TableGUID AND 
			CFF_Table.FldType = 7 AND
			DDF_Table.New_Value IS NOT NULL AND
			DDF_Table.New_Value NOT LIKE '[0-2][0-9]:[0-5][0-9]%'
	END

	IF @AmenToDist = 0
	BEGIN
		SELECT DDV.GUID, DDV.GUID_CF,DDV.Column_Name, DDV.New_Value INTO #DuplicateValue from DistDeviceCF_Value000 DDV
		INNER JOIN CFFlds000 CFF ON CFF.ColumnName = DDV.Column_Name 
		WHERE 
		CFF.GGuid = @TableGUID AND CFF.IsUnique = 1 AND DDV.IsSync = 1

		DECLARE @sql Nvarchar(max),
				@DDV_GUID UNIQUEIDENTIFIER,
				@CFV_GUID UNIQUEIDENTIFIER,
				@coulmnName nvarchar(max),
				@new_Value nvarchar(max)

		Declare columnCursor CURSOR FOR SELECT DV.GUID, DV.GUID_CF, DV.Column_Name, DV.New_Value from #DuplicateValue DV
		OPEN columnCursor FETCH NEXT FROM columnCursor INTO @DDV_GUID, @CFV_GUID, @coulmnName, @new_Value
		WHILE @@FETCH_STATUS = 0
		BEGIN
			set @sql = 'IF EXISTS(SELECT '+@coulmnName+' from '+@Cf_valueTableName+' WHERE GUID != '''+CONVERT(nvarchar(max), @CFV_GUID)+''' AND DATALENGTH('+@coulmnName+') > 0 AND '+@coulmnName+' =									'''+@new_Value+''' )
						BEGIN
							Update DistDeviceCF_Value000
								SET	ResultOfInsert = CONCAT(ResultOfInsert,'', Duplicated Value''), 
								IsSync = 0
							WHERE GUID = '''+CONVERT(nvarchar(max), @DDV_GUID)+''' AND IsSync = 1
						END'
			EXEC(@sql)
			FETCH NEXT FROM columnCursor INTO @DDV_GUID, @CFV_GUID, @coulmnName, @new_Value
		END
		CLOSE columnCursor
		DEALLOCATE columnCursor
	END
END
#####################################################################################################
#END
