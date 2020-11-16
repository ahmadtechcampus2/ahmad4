###############################################################################
CREATE PROCEDURE PrcMatPricesList
	@GroupGuid			[UNIQUEIDENTIFIER] = 0x00,
	@StoreGuid			[UNIQUEIDENTIFIER] = 0x00,
	@MatCondGuid		[UNIQUEIDENTIFIER] = 0x00,
	@ShowGroups			[BIT] = 0,
	@ShowEmptyMat		[BIT] = 0,
	@IncludeSubStores	[BIT] = 0,
	@ShowFlag			[INT] = 0, -- 0:Asset, 1:Store, 2:Service
	@UseUnit			[INT] = 0,
	@UseMatCardCurr		[BIT] = 0,
	@CurrencyGuid		[UNIQUEIDENTIFIER] = 0x00,
	@ShowGrpPrices		[BIT] = 0,
	@ShowGrpQtys		[BIT] = 0
AS
SET NOCOUNT ON;
CREATE TABLE [#SecViol]( [Type] [INT], [Cnt] [INTEGER])
  
DECLARE @Criteria [NVARCHAR](MAX)
IF ISNULL(@MatCondGuid, 0x00) <> 0x00
BEGIN
	SET @Criteria = [dbo].[fnGetConditionStr2](NULL,@MatCondGuid)
END
ELSE 
	SET @Criteria = ''
------------------------ Group Kind -----------------------------------
DECLARE @GrpKind TINYINT
IF(ISNULL(@GroupGuid, 0x00) <> 0x00)
BEGIN
	SET @GrpKind = (SELECT [Kind] FROM [vcGr] WHERE [GUID] = @GroupGuid)
END
----------------------------------------------------------------------
DECLARE	@UserGuid [UNIQUEIDENTIFIER]
SET @UserGuid = [dbo].[fnGetCurrentUserGUID]()
CREATE TABLE #Mats  (	[MtNumber]			[INT],
						[MtName]			[NVARCHAR](250),
						[MtCode]			[NVARCHAR](100),
						[MtLatinName]		[NVARCHAR](250),
						[MtBarCode]			[NVARCHAR](500), 
						[MtUnity]			[NVARCHAR](100),
						[mtCurrencyVal]		[FlOAT],
						[LPmhCurrencyVal]	[FLOAT], -- mat currency value at last price date
						[LPSelmhCurrencyVal][FLOAT], -- selected currency value at last price date
						[MatType]			[INT],
						[MtUnit2]			[NVARCHAR](100),
						[MtUnit2Fact]		[FlOAT],
						[MtUnit3]			[NVARCHAR](100),
						[MtUnit3Fact]		[FlOAT], 
						[MtCurUnitFact]		[FlOAT], -- Selected unit factor	
						[MtVAT]				[FlOAT],
						[MtGuid]			[UNIQUEIDENTIFIER],
						[MtPtr]				[UNIQUEIDENTIFIER],
						[GrpPtr]			[UNIQUEIDENTIFIER],
						[MtGroupGuid]		[UNIQUEIDENTIFIER],
						[MtCurrencyGuid]	[UNIQUEIDENTIFIER],
						[MtCurrencyCode]	[NVARCHAR](100),
						[mhCurrencyVal]		[FlOAT],
						[MtDefUnit]			[INT],
						[MtDefUnitFact]		[FlOAT],
						[MtSecurity]		[INT],
						[MtGrpLevel]		[INT],
						[MtGrpPath]			[NVARCHAR](max) COLLATE ARABIC_CI_AI,
						[MtGrpName]			[NVARCHAR](256),
						[MtGrpCode]			[NVARCHAR](256),
						[MtGrpLatinName]	[NVARCHAR](256),
						[MtGrpParentGUID]	[UNIQUEIDENTIFIER],
						[MtStoreGuid]		[UNIQUEIDENTIFIER],
						[MtQty]				[FLOAT],
						[IsMat]				[BIT],
						[MtPriceType]		[INT],
						[MtWhole]			[FLOAT], [MtWhole2]		[FLOAT], [MtWhole3]		[FLOAT],
						[MtHalf]			[FLOAT], [MtHalf2]		[FLOAT], [MtHalf3]		[FLOAT],
						[MtVendor]			[FLOAT], [MtVendor2]	[FLOAT], [MtVendor3]	[FLOAT],
						[MtExport]			[FLOAT], [MtExport2]	[FLOAT], [MtExport3]	[FLOAT],
						[MtRetail]			[FLOAT], [MtRetail2]	[FLOAT], [MtRetail3]	[FLOAT],
						[MtEndUser]			[FLOAT], [MtEndUser2]	[FLOAT], [MtEndUser3]	[FLOAT],
						[MtMaxPrice]		[FLOAT], [MtMaxPrice2]	[FLOAT], [MtMaxPrice3]	[FLOAT],
						[MtAvgPrice]		[FLOAT],	
						[MtLastPrice]		[FLOAT], [MtLastPrice2]	[FLOAT], [MtLastPrice3]	[FLOAT],
						[MtLastPriceByHist]	[FLOAT], [MtLastPriceByHist2]	[FLOAT], [MtLastPriceByHist3]	[FLOAT],
						[MtLastPriceCurVal]	[FLOAT], [MtLastPriceDate] [DATETIME], [LastBillCurrencyGuid] [UNIQUEIDENTIFIER]
					)
DECLARE @SqlRes [NVARCHAR](MAX)
SET @SqlRes = 'SELECT	mt.Number, mt.Name, mt.Code, mt.LatinName, mt.BarCode, mt.Unity,
						CASE mt.CurrencyVal WHEN 0 THEN 1 ELSE mt.CurrencyVal END, mt.Type, mt.Unit2, mt.Unit2Fact, mt.Unit3, mt.Unit3Fact,
						mt.VAT, mt.GUID, mt.GUID, 0x00, mt.GroupGUID, mt.CurrencyGUID, mt.DefUnit, mt.Security, mt.Qty, 1, 
						mt.PriceType,
						mt.Whole, mt.Half, mt.Vendor, mt.Export, mt.Retail, mt.EndUser, mt.MaxPrice, mt.AvgPrice, mt.LastPrice,
						mt.Whole2, mt.Half2, mt.Vendor2, mt.Export2, mt.Retail2, mt.EndUser2, mt.MaxPrice2, mt.LastPrice2,
						mt.Whole3, mt.Half3, mt.Vendor3, mt.Export3, mt.Retail3, mt.EndUser3, mt.MaxPrice3, mt.LastPrice3,
						CASE mt.LastPriceCurVal WHEN 0 THEN 1 ELSE mt.LastPriceCurVal END, mt.LastPriceDate
				FROM  [vcMt] AS [mt]'
IF(ISNULL(@MatCondGuid, 0x00) <> 0x00)
BEGIN
	SET  @SqlRes += 'INNER JOIN [vwMtGr] AS [mtGr] ON ([mtGr].[mtGuid] = [mt].[Guid])'
END
IF( (ISNULL(@GroupGuid, 0x00) <> 0x00) AND @GrpKind = 0 )
BEGIN
	SET  @SqlRes += 'INNER JOIN [dbo].[fnGetGroupsList](''' + CONVERT([NVARCHAR](255),@GroupGuid) + ''') AS [GrpList] ON ([mt].[groupGuid] = [GrpList].[Guid] )'
END
IF( (ISNULL(@GroupGuid, 0x00) <> 0x00) AND @GrpKind <> 0 )
BEGIN
	SET  @SqlRes += 'INNER JOIN [dbo].[fnGetMatsOfCollectiveGrps](''' + CONVERT([NVARCHAR](255),@GroupGuid) + ''') AS [f] ON ([mt].[Guid] = [f].[mtGuid])'
END
		
IF(ISNULL(@MatCondGuid, 0x00) <> 0x00)
BEGIN					
	SET @SqlRes += 'WHERE ' + @Criteria 
END
SET @SqlRes += ' ORDER BY mt.Number'
INSERT INTO #Mats (	[MtNumber], [MtName], [MtCode], [MtLatinName], [MtBarCode],
					[MtUnity], [MtCurrencyVal], [MatType], [MtUnit2], [MtUnit2Fact],
					[MtUnit3], [MtUnit3Fact], [MtVAT], [MtGuid], [MtPtr], [GrpPtr], [MtGroupGuid],
					[MtCurrencyGuid], [MtDefUnit], [MtSecurity], [MtQty], [IsMat], [MtPriceType],
					[MtWhole], [MtHalf], [MtVendor], [MtExport], [MtRetail], [MtEndUser],
					[MtMaxPrice], [MtAvgPrice], [MtLastPrice],
					[MtWhole2], [MtHalf2], [MtVendor2], [MtExport2], [MtRetail2], [MtEndUser2],
					[MtMaxPrice2], [MtLastPrice2],
					[MtWhole3], [MtHalf3], [MtVendor3], [MtExport3], [MtRetail3], [MtEndUser3],
					[MtMaxPrice3], [MtLastPrice3], [MtLastPriceCurVal], [MtLastPriceDate])  
		EXEC (@SqlRes)
---------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------
DELETE FROM m 
FROM vcMt AS mt INNER JOIN #Mats AS m ON mt.GUID = m.MtGuid
WHERE mt.HasSegments = 1
---------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------
DELETE FROM #Mats 
WHERE  ( [MatType] = 0 AND @ShowFlag & 0x00000001 = 0) 
	OR ( [MatType] = 1 AND @ShowFlag & 0x00000002 = 0) 
	OR ( [MatType] = 2 AND @ShowFlag & 0x00000004 = 0)
---------------------- Stores ---------------------------------------------------------------------
---------------------------------------------------------------------------------------------------
IF(ISNULL(@StoreGuid, 0x00) <> 0x00)
BEGIN
	IF(@IncludeSubStores = 0 AND @ShowEmptyMat = 0)
	BEGIN
		UPDATE mat
		SET mat.[MtStoreGuid] = 
			(SELECT [StoreGUID] FROM [ms000] Where @StoreGuid = [StoreGUID] AND mat.[MtGuid] = [MatGUID])
		FROM #Mats AS mat
		DELETE FROM #Mats WHERE ([MtStoreGuid] <> @StoreGuid OR ISNULL([MtStoreGuid], 0x00) = 0x00)
		UPDATE mat
		SET mat.[MtQty] = 
			(SELECT SUM([Qty]) FROM [ms000] Where @StoreGuid = [StoreGUID] AND mat.[MtGuid] = [MatGUID]
				GROUP BY [StoreGUID], [MatGUID])
		FROM #Mats AS mat
			
	END
	ELSE
	BEGIN
		DECLARE @Stores TABLE (	[StoreGuid]		[UNIQUEIDENTIFIER])
		DECLARE @StoreMat TABLE([StoreGuid]		[UNIQUEIDENTIFIER],
								[MaterialGuid]	[UNIQUEIDENTIFIER],
								[MtStQty]		[FLOAT])
		INSERT INTO @Stores ([StoreGuid])
			SELECT * FROM dbo.fnGetStoresList(@StoreGuid)
		INSERT INTO @StoreMat
			SELECT st.[StoreGuid], ms.[MatGUID], ms.[Qty]
			FROM @Stores AS st
			INNER JOIN [ms000] AS ms ON st.[StoreGuid] = ms.[StoreGUID]
		UPDATE mat
		SET mat.[MtStoreGuid] = (SELECT Top 1 ([StoreGuid]) FROM @StoreMat WHERE [MaterialGuid] = mat.[MtGuid] )
		FROM #Mats AS mat
		WHERE
		(SELECT Top 1 ([StoreGuid]) FROM @StoreMat) IS NOT NULL
		
		IF(@IncludeSubStores = 0 AND @ShowEmptyMat <> 0)
		BEGIN
			UPDATE mat
			SET mat.[MtStQty] = 0
			FROM @StoreMat AS mat
			WHERE StoreGuid <> @StoreGuid
		END
		UPDATE mat
		SET mat.[MtQty] = 
			(	SELECT SUM([MtStQty]) 
				FROM @StoreMat WHERE mat.[MtGuid] = [MaterialGuid]
				GROUP BY [MaterialGuid])
		FROM #Mats AS mat
		UPDATE mat
		SET mat.[MtQty] = 0
		FROM #Mats AS mat
		WHERE mat.[MtQty] IS NULL
	END
END
---------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------
--------------------------- Group security --------------------------------------------------------
---------------------------------------------------------------------------------------------------
IF [dbo].[fnIsAdmin](ISNULL(@userGUID, 0x0)) = 0
BEGIN
	DECLARE @GroupsSec TABLE([GrpGuid] [UNIQUEIDENTIFIER])
	INSERT INTO @GroupsSec 
			SELECT [Guid] FROM [fnGetGroupsList](@GroupGUID)
	DELETE [r] 
	FROM @GroupsSec AS [r] 
	INNER JOIN fnGroup_HSecList() AS [f] ON [r].[GrpGuid] = [f].[GUID] 
	WHERE [f].[Security] > [dbo].[fnGetUserGroupSec_Browse](@UserGuid)
	
	DELETE [m] 
	FROM #Mats AS [m]
	INNER JOIN [mt000] AS [mt] ON [MtGuid] = [mt].[Guid] 
	WHERE  [mtSecurity] > [dbo].[fnGetUserMaterialSec_Browse](@UserGuid) 
		OR  NOT EXISTS(SELECT 1 FROM @GroupsSec AS F WHERE mt.[Groupguid] = F.GrpGuid)
	
END
---------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------
------------------------- Add Groups to List ------------------------------------------------------
DECLARE @Groups TABLE  (	[GrpGuid]		[UNIQUEIDENTIFIER], 
							[GrpLevel]		[INT],
							[GrpPath]		[VARCHAR](max),
							[GrpName]		[NVARCHAR](256),
							[GrpCode]		[NVARCHAR](256),
							[GrpLatinName]	[NVARCHAR](256),
							[GrpParentGUID] [UNIQUEIDENTIFIER],
							[GrpNumber]		[INT]
						) 
		
INSERT INTO @Groups
		SELECT 
			[f].[Guid], 
			[Level],
			[Path],
			[Name],
			[Code],
			[LatinName],
			[ParentGUID],
			[Number] 
		FROM 
			[dbo].[fnGetGroupsOfGroupSorted](@GroupGUID, 1) AS [f] 
			INNER JOIN [gr000] AS [gr] ON [gr].[Guid] = [f].[Guid]
				
UPDATE [r] 
	SET [MtGrpLevel] = [GrpLevel],
		[MtGrpPath] = [GrpPath],
		[MtGrpName] = [GrpName],
		[MtGrpCode] = [GrpCode],
		[MtGrpLatinName] = [GrpLatinName],
		[MtGrpParentGuid] = [GrpParentGUID] 
FROM #Mats AS [r]
INNER JOIN @Groups AS [gr] ON [R].[MtGroupGuid] = [gr].[GrpGuid]

IF(@ShowGroups <> 0)
BEGIN
	INSERT INTO #Mats ([MtNumber], [MtGuid], [MtGrpLevel], [MtGrpPath], [MtName], [MtCode], [MtLatinName], [MtGroupGuid], [MtPtr], [GrpPtr], [IsMat] )
		SELECT [GrpNumber], [GrpGuid], [GrpLevel], [GrpPath], [GrpName], [GrpCode],
				[GrpLatinName], [GrpParentGUID], 0x00, [GrpGuid], 0
		FROM @Groups
	DELETE FROM #Mats WHERE [IsMat] = 0 AND ( (SELECT Count([GUID]) FROM [dbo].[fnGetMatOfGroupList]([MtGuid])
																INNER JOIN #Mats ON [GUID] = [MtGuid] ) = 0  ) 
END
---------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------
DELETE FROM #Mats 
WHERE  ( [MatType] = 0 AND @ShowFlag & 0x00000001 = 0) 
	OR ( [MatType] = 1 AND @ShowFlag & 0x00000002 = 0) 
	OR ( [MatType] = 2 AND @ShowFlag & 0x00000004 = 0)
----------------------------------- Update Qtys with unit -----------------------------------------
---------------------------------------------------------------------------------------------------
IF(@UseUnit <> 0)
BEGIN
	UPDATE mat
	SET [MtDefUnitFact] = (CASE [MtDefUnit]	WHEN 0 THEN 1
											WHEN 1 THEN 1
											WHEN 2 THEN [MtUnit2Fact] 
											WHEN 3 THEN [MtUnit3Fact] END)
	FROM #Mats AS mat
	
	UPDATE mat
	SET [MtQty] =(CASE @UseUnit WHEN 1 THEN CASE [MtUnit2Fact] WHEN 0 THEN [MtQty] ELSE [MtQty] / [MtUnit2Fact] END
								WHEN 2 THEN CASE [MtUnit3Fact] WHEN 0 THEN [MtQty] ELSE [MtQty] / [MtUnit3Fact] END
								WHEN 3 THEN CASE [MtDefUnitFact] WHEN 0 THEN [MtQty] ELSE [MtQty] / [MtDefUnitFact] END
								WHEN 0 THEN [MtQty] END)

	FROM #Mats AS mat
END

IF(@UseUnit = 1) -- Unit 2
BEGIN 
	UPDATE mat
		SET [MtWhole] = CASE [MtUnit2Fact] WHEN 0 THEN [MtWhole] ELSE [MtWhole2] END,
			[MtHalf] = CASE [MtUnit2Fact] WHEN 0 THEN [MtHalf] ELSE [MtHalf2] END,
			[MtVendor] = CASE [MtUnit2Fact] WHEN 0 THEN [MtVendor] ELSE [MtVendor2] END,
			[MtExport] =  CASE [MtUnit2Fact] WHEN 0 THEN [MtExport] ELSE [MtExport2] END,
			[MtRetail] = CASE [MtUnit2Fact] WHEN 0 THEN [MtRetail] ELSE [MtRetail2] END,
			[MtEndUser] =  CASE [MtUnit2Fact] WHEN 0 THEN [MtEndUser] ELSE [MtEndUser2] END,
			[MtMaxPrice] = CASE [MtUnit2Fact] WHEN 0 THEN [MtMaxPrice] ELSE [MtMaxPrice2] END,
			[MtLastPrice] = CASE [MtUnit2Fact] WHEN 0 THEN [MtLastPrice] ELSE [MtLastPrice2] END,
			[MtUnity] = [MtUnit2]
	FROM #Mats AS mat
END

IF(@UseUnit = 2) -- Unit 3
BEGIN 
	UPDATE mat
		SET [MtWhole] = CASE [MtUnit3Fact] WHEN 0 THEN [MtWhole] ELSE [MtWhole3] END,
			[MtHalf] = CASE [MtUnit3Fact] WHEN 0 THEN [MtHalf] ELSE [MtHalf3] END,
			[MtVendor] = CASE [MtUnit3Fact] WHEN 0 THEN [MtVendor] ELSE [MtVendor3] END,
			[MtExport] =  CASE [MtUnit3Fact] WHEN 0 THEN [MtExport] ELSE [MtExport3] END,
			[MtRetail] = CASE [MtUnit3Fact] WHEN 0 THEN [MtRetail] ELSE [MtRetail3] END,
			[MtEndUser] =  CASE [MtUnit3Fact] WHEN 0 THEN [MtEndUser] ELSE [MtEndUser3] END,
			[MtMaxPrice] = CASE [MtUnit3Fact] WHEN 0 THEN [MtMaxPrice] ELSE [MtMaxPrice3] END,
			[MtLastPrice] = CASE [MtUnit3Fact] WHEN 0 THEN [MtLastPrice] ELSE [MtLastPrice3] END,
			[MtUnity] = [MtUnit3]
	FROM #Mats AS mat
END

IF(@UseUnit = 3) -- Default unit
BEGIN 
	UPDATE mat
		SET [MtWhole] = CASE ISNULL([MtDefUnitFact],0) WHEN 0 THEN [MtWhole]
						ELSE (CASE [MtDefUnit] WHEN 1 THEN [MtWhole] WHEN 2 THEN [MtWhole2] WHEN 3 THEN [MtWhole3] END) END,
			
			[MtHalf] = CASE ISNULL([MtDefUnitFact], 0) WHEN 0 THEN [MtHalf]
						ELSE (CASE [MtDefUnit] WHEN 1 THEN [MtHalf] WHEN 2 THEN [MtHalf2] WHEN 3 THEN [MtHalf3] END) END,
			
			[MtVendor] = CASE ISNULL([MtDefUnitFact], 0) WHEN 0 THEN [MtVendor]
						ELSE (CASE [MtDefUnit] WHEN 1 THEN [MtVendor] WHEN 2 THEN  [MtVendor2] WHEN 3 THEN [MtVendor3] END) END,
			
			[MtExport] =  CASE ISNULL([MtDefUnitFact], 0) WHEN 0 THEN [MtExport]
							ELSE (CASE [MtDefUnit] WHEN 1 THEN [MtExport] WHEN 2 THEN [MtExport2] WHEN 3 THEN [MtExport3] END) END,
			
			[MtRetail] = CASE ISNULL([MtDefUnitFact], 0) WHEN 0 THEN [MtRetail]
							ELSE (CASE [MtDefUnit] WHEN 1 THEN [MtRetail] WHEN 2 THEN [MtRetail2] WHEN 3 THEN [MtRetail3] END) END,		
			
			[MtEndUser] =  CASE ISNULL([MtDefUnitFact], 0) WHEN 0 THEN [MtEndUser]
							ELSE (CASE [MtDefUnit] WHEN 1 THEN [MtEndUser] WHEN 2 THEN [MtEndUser2] WHEN 3 THEN [MtEndUser3] END) END,
			
			[MtMaxPrice] = CASE ISNULL([MtDefUnitFact], 0) WHEN 0 THEN [MtMaxPrice]
							ELSE (CASE [MtDefUnit] WHEN 1 THEN [MtMaxPrice] WHEN 2 THEN [MtMaxPrice2] WHEN 3 THEN [MtMaxPrice3] END) END,
			
			[MtLastPrice] = CASE ISNULL([MtDefUnitFact], 0) WHEN 0 THEN [MtLastPrice]
							ELSE (CASE [MtDefUnit] WHEN 1 THEN [MtLastPrice] WHEN 2 THEN [MtLastPrice2] WHEN 3 THEN [MtLastPrice3] END )END,
			
			[MtUnity] = CASE [MTDefUnit] WHEN 1 THEN [MtUnity] WHEN 2 THEN [MtUnit2] WHEN 3 THEN [MtUnit3] END
	FROM #Mats AS mat
END

---------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------
------------------------Empty Mats----------------------------
--------------------------------------------------------------
IF(@ShowEmptyMat = 0)
BEGIN
	DELETE FROM #Mats WHERE ([IsMat] = 1 AND ([MtQty] = 0))
END

--- Update unit factor --------------------
UPDATE mat
	SET [MtCurUnitFact] = ISNULL((CASE @UseUnit WHEN 1 THEN [MtUnit2Fact] WHEN 2 THEN [MtUnit3Fact] WHEN 3 THEN [MtDefUnitFact] ELSE 0 END), 1)
FROM #Mats AS mat

---------------------------------------------------------------------------------------------------
------------------------ Currency -----------------------------------------------------------------
DECLARE @CurrList TABLE ( [myGuid] [UNIQUEIDENTIFIER], [myCode] [NVARCHAR](100))
INSERT INTO @CurrList SELECT [myGUID],[myCODE] FROM vwmy

Update mat
Set [MtCurrencyCode] = (Select [myCODE] FROM @CurrList WHERE [myGuid] = mat.[MtCurrencyGuid]),
	[mhCurrencyVal] = ([dbo].[fnGetCurVal](mat.[MtCurrencyGuid], GETDATE())),
	[LPmhCurrencyVal] = ([dbo].[fnGetCurVal](mat.[MtCurrencyGuid], mat.[MtLastPriceDate])),
	[LPSelmhCurrencyVal] = ([dbo].[fnGetCurVal](@CurrencyGuid, mat.[MtLastPriceDate])),
	[LastBillCurrencyGuid] = ([dbo].fnGetCurrencyIDLastPurchaseBill(mat.[MtGuid]))
FROM #Mats AS mat
---------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------
DECLARE @SelCurValue [FLOAT]
SET @SelCurValue = ISNULL(( [dbo].[fnGetCurVal](@CurrencyGuid, GETDATE())), 1)

if(@SelCurValue = 0)
	BEGIN
		SET @SelCurValue = 1
	END
	
UPDATE mat
	SET [MtAvgPrice]	= [MtAvgPrice] / @SelCurValue,
		[MtMaxPrice]	= [MtMaxPrice] / @SelCurValue,
		[MtLastPriceByHist]  = [MtLastPrice] / [dbo].[fnGetCurVal]([LastBillCurrencyGuid], mat.[MtLastPriceDate])
		* dbo.fnGetCurVal([LastBillCurrencyGuid], GETDATE()) / @SelCurValue,
		[MtLastPrice]	= ([MtLastPrice]  * ([LPmhCurrencyVal] / [MtLastPriceCurVal])) / [LPSelmhCurrencyVal],
		[MtWhole]		= ([MtWhole]  * ([mhCurrencyVal] /[MtCurrencyVal])) / @SelCurValue,
		[MtHalf]		= ([MtHalf]  * ([mhCurrencyVal] /[MtCurrencyVal]))/ @SelCurValue,
		[MtVendor]		= ([MtVendor]  * ([mhCurrencyVal] /[MtCurrencyVal]))/ @SelCurValue,
		[MtExport]		= ([MtExport] *  ([mhCurrencyVal] /[MtCurrencyVal])) / @SelCurValue,
		[MtRetail]		= ([MtRetail] *  ([mhCurrencyVal] /[MtCurrencyVal]))/ @SelCurValue,
		[MtEndUser]		= ([MtEndUser] *  ([mhCurrencyVal] /[MtCurrencyVal]))/ @SelCurValue
FROM #Mats AS mat
WHERE [MtPriceType] = 15 -- Real Price

------------------------ Update Groups Prices ------------------------------------------------------


if(@ShowGroups <> 0 AND ( @ShowGrpPrices<> 0 OR @ShowGrpQtys<> 0 ))
BEGIN
	UPDATE #Mats 
		SET 
			#Mats.[MtAvgPrice] = GrpSums.[AvgPrice],
			#Mats.[MtMaxPrice] = GrpSums.[MaxPrice],
			#Mats.[MtLastPrice] = GrpSums.[LastPrice],
			#Mats.[MtLastPriceByHist] = GrpSums.[LastPriceByHistory],
			#Mats.[MtWhole] = GrpSums.[Whole],
			#Mats.[MtHalf] = GrpSums.[Half],
			#Mats.[MtVendor] = GrpSums.[Vendor],
			#Mats.[MtExport] = GrpSums.[Export],
			#Mats.[MtRetail] = GrpSums.[Retail],
			#Mats.[MtEndUser] = GrpSums.[EndUser],
			#Mats.[MtQty] = GrpSums.[GrpQty],
			#Mats.[MtPriceType] =15
	FROM 
	(
		SELECT mats.[MtGroupGuid],	CASE @ShowGrpPrices WHEN 0 THEN 0 ELSE SUM([MtAvgPrice] * ([MtQty])) END AS AvgPrice,
									CASE @ShowGrpPrices WHEN 0 THEN 0 ELSE SUM([MtMaxPrice] * ([MtQty])) END AS MaxPrice,
									CASE @ShowGrpPrices WHEN 0 THEN 0 ELSE SUM([MtLastPrice] * ([MtQty])) END AS LastPrice,
									CASE @ShowGrpPrices WHEN 0 THEN 0 ELSE SUM([MtLastPriceByHist] * ([MtQty])) END AS LastPriceByHistory,
									CASE @ShowGrpPrices WHEN 0 THEN 0 ELSE SUM([MtWhole] * ([MtQty])) END AS Whole,
									CASE @ShowGrpPrices WHEN 0 THEN 0 ELSE SUM([MtHalf] * ([MtQty])) END AS Half,
									CASE @ShowGrpPrices WHEN 0 THEN 0 ELSE SUM([MtVendor] * ([MtQty])) END AS Vendor,
									CASE @ShowGrpPrices WHEN 0 THEN 0 ELSE SUM([MtExport] * ([MtQty])) END AS Export,
									CASE @ShowGrpPrices WHEN 0 THEN 0 ELSE SUM([MtRetail] * ([MtQty])) END AS Retail,
									CASE @ShowGrpPrices WHEN 0 THEN 0 ELSE SUM([MtEndUser] * ([MtQty])) END AS EndUser,
									CASE @ShowGrpQtys WHEN 0 THEN 0 ELSE SUM([MtQty]) END AS GrpQty
		FROM #Mats AS mats
		WHERE mats.[IsMat] = 1
		GROUP BY mats.[MtGroupGuid]
	) AS GrpSums
	WHERE GrpSums.[MtGroupGuid] = #Mats.[GrpPtr] AND #Mats.[IsMat] = 0

	DECLARE @GroupsSums TABLE  (	[GrpGuid]				[UNIQUEIDENTIFIER],
									[AvgPrice]				[FLOAT], 
									[MaxPrice]				[FLOAT],
									[LastPrice]				[FLOAT],
									[LastPriceByHistory]	[FLOAT],
									[Whole]					[FLOAT],
									[Half]					[FLOAT],
									[Vendor]				[FLOAT],
									[Export]				[FLOAT],
									[Retail]				[FLOAT],
									[EndUser]				[FLOAT],
									[GrpQty]				[FLOAT]
								) 

	 
	DECLARE @Level INT
	SELECT @Level = (MAX([MtGrpLevel])) - 1 FROM #Mats
	WHILE @Level > -1
	BEGIN

	DELETE FROM @GroupsSums

	INSERT INTO @GroupsSums
		SELECT mats.[MtGroupGuid],	CASE @ShowGrpPrices WHEN 0 THEN 0 ELSE SUM([MtAvgPrice]) END AS AvgPrice,
									CASE @ShowGrpPrices WHEN 0 THEN 0 ELSE SUM([MtMaxPrice]) END AS MaxPrice,
									CASE @ShowGrpPrices WHEN 0 THEN 0 ELSE SUM([MtLastPrice]) END AS LastPrice,
									CASE @ShowGrpPrices WHEN 0 THEN 0 ELSE SUM([MtLastPriceByHist]) END AS LastPriceByHistory,
									CASE @ShowGrpPrices WHEN 0 THEN 0 ELSE SUM([MtWhole]) END AS Whole,
									CASE @ShowGrpPrices WHEN 0 THEN 0 ELSE SUM([MtHalf]) END AS Half,
									CASE @ShowGrpPrices WHEN 0 THEN 0 ELSE SUM([MtVendor]) END AS Vendor,
									CASE @ShowGrpPrices WHEN 0 THEN 0 ELSE SUM([MtExport]) END AS Export,
									CASE @ShowGrpPrices WHEN 0 THEN 0 ELSE SUM([MtRetail]) END AS Retail,
									CASE @ShowGrpPrices WHEN 0 THEN 0 ELSE SUM([MtEndUser]) END AS EndUser,
									CASE @ShowGrpQtys WHEN 0 THEN 0 ELSE SUM([MtQty]) END AS GrpQty
			FROM #Mats AS mats 
			WHERE mats.IsMat = 0 AND mats.[MtGroupGuid] <> 0x00
			AND @Level + 1  = mats.[MtGrpLevel]
			GROUP BY mats.[MtGroupGuid]

		UPDATE #Mats
			SET #Mats.[MtAvgPrice] = ISNULL(#Mats.[MtAvgPrice], 0) + GrpSums.[AvgPrice],
				#Mats.[MtMaxPrice] = ISNULL(#Mats.[MtMaxPrice], 0 ) +  GrpSums.[MaxPrice],
				#Mats.[MtLastPrice] = ISNULL(#Mats.[MtLastPrice], 0) + GrpSums.[LastPrice],
				#Mats.[MtLastPriceByHist] = ISNULL(#Mats.[MtLastPriceByHist], 0) + GrpSums.[LastPriceByHistory],
				#Mats.[MtWhole] = ISNULL(#Mats.[MtWhole], 0) + GrpSums.[Whole],
				#Mats.[MtHalf] = ISNULL(#Mats.[MtHalf], 0) + GrpSums.[Half],
				#Mats.[MtVendor] = ISNULL(#Mats.[MtVendor], 0) +  GrpSums.[Vendor],
				#Mats.[MtExport] = ISNULL(#Mats.[MtExport], 0) + GrpSums.[Export],
				#Mats.[MtRetail] = ISNULL(#Mats.[MtRetail], 0) + GrpSums.[Retail],
				#Mats.[MtEndUser] = ISNULL(#Mats.[MtEndUser], 0) + GrpSums.[EndUser],
				#Mats.[MtQty] = ISNULL(#Mats.[MtQty], 0) + GrpSums.[GrpQty] ,
				#Mats.[MtPriceType] =15
		FROM  @GroupsSums as GrpSums
		WHERE GrpSums.[GrpGuid] = #Mats.[GrpPtr] 

		SET @Level = @Level - 1
	END
END
-----------------------------------------------------------------------------------------------------

EXEC [prcCheckSecurity]  @result = '#Mats'

---------------------------------------------- Result --------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------
SELECT		ISNULL([MtNumber],  0)					AS [MtNumber],
			ISNULL([MtName], '')					AS [MtName],
			ISNULL([MtCode], '')					AS [MtCode],
			ISNULL( [MtBarCode]	,'')				AS [MtBarCode],
			ISNULL( [MtUnity] ,'' )					AS [MtUnity],
			ISNULL( [MtCurrencyVal],0.0 )			AS [MtCurrencyVal],
			ISNULL( [MatType],0 )					AS [MatType],
			ISNULL( [MtGuid] , 0x00 )				AS [MtGuid],
			ISNULL( [MtPtr] , 0x00 )				AS [MtPtr],
			ISNULL( [GrpPtr] , 0x00 )				AS [GrpPtr],
			ISNULL( [MtGroupGuid] , 0x00 )			AS [MtGroupGuid],
			ISNULL( [MtCurrencyGuid] ,0x00 )		AS [MtCurrencyGuid],
			ISNULL( [MtCurrencyCode] , '' )			AS [MtCurrencyCode],
			ISNULL(	[MhCurrencyVal], 0.0)			AS [MtCurrencyValue],
			ISNULL( [MtSecurity] , 0 )				AS [MtSecurity],
			ISNULL( [MtGrpLevel] , 0 )				AS [MtGrpLevel],
			ISNULL( [MtGrpPath] , '' )				AS [MtGrpPath],
			ISNULL( [MtGrpName] , '' )				AS [MtGrpName],
			ISNULL( [MtGrpCode] , '' )				AS [MtGrpCode],
			ISNULL( [MtGrpLatinName] , '' )			AS [MtGrpLatinName],
			ISNULL( [MtGrpParentGUID] , 0x00 )		AS [MtGrpParentGUID],
			ISNULL( [MtStoreGuid] , 0x00 )			AS [MtStoreGuid],
			ISNULL( [MtQty] , 0.0 )					AS [MtQty],
			ISNULL( [IsMat] , 0 )					AS [IsMat],
			ISNULL( [MtPriceType] , 0 )				AS [MtPriceType],
			ISNULL( [MtWhole] , 0.0 )				AS [MtWhole],
			ISNULL( [MtHalf] , 0.0 )				AS [MtHalf],
			ISNULL( [MtVendor] , 0.0 )				AS [MtVendor],
			ISNULL( [MtExport] , 0.0 )				AS [MtExport],
			ISNULL( [MtRetail] , 0.0 )				AS [MtRetail],
			ISNULL( [MtEndUser] , 0.0 )				AS [MtEndUser],
			ISNULL( [MtMaxPrice] , 0.0 )			AS [MtMaxPrice],
			ISNULL( [MtAvgPrice] , 0.0)				AS [MtAvgPrice],
			ISNULL( [MtLastPrice] , 0.0 )			AS [MtLastPrice],
			ISNULL( [MtLastPriceCurVal] , 0.0 )		AS [MtLastPriceCurVal],
			ISNULL( [MtLastPriceByHist] , 0.0 )		AS [MtLastPriceByHist]
FROM #Mats 
ORDER By 
	(CASE WHEN @ShowGroups = 0 THEN MtNumber END ),
	(CASE WHEN @ShowGroups <> 0 THEN [MtGrpPath] END),
	(CASE WHEN @ShowGroups <> 0 THEN [MtCode] END)
SELECT * FROM [#SecViol]
--------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------

###############################################################################
#End


