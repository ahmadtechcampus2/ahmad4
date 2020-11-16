##################################################################
CREATE PROCEDURE repSegmentedMaterialsInv
	@StartDate 				[DATETIME], 
	@EndDate 				[DATETIME], 
	@MatGUID 				[UNIQUEIDENTIFIER], -- 0 All Mat or MatNumber 
	@GroupGUID 				[UNIQUEIDENTIFIER], 
	@StoreGUID 				[UNIQUEIDENTIFIER], -- 0 all stores so don't check store or list of stores 
	@CostGUID 				[UNIQUEIDENTIFIER], -- 0 all costs so don't Check cost or list of costs 
	@ShowEmpty 				[BIT], 
	@ShowBalancedMat		[BIT], 
	@ShowGroups 			[BIT],
	@ShowCompositions		[BIT],
	@ShowUnLinked 			[BIT], 
	@ShowDetailsUnits		[BIT], 
	@CurrencyGUID 			[UNIQUEIDENTIFIER], 
	@UseUnit 				[INT], 
	@PriceType 				[INT], 
	@PricePolicy 			[INT],
	@MatCondGuid			[UNIQUEIDENTIFIER]
AS 
	SET NOCOUNT ON
	
	IF [dbo].[fnGetUserMaterialSec_Balance]([dbo].[fnGetCurrentUserGuid]()) <= 0  
		RETURN  

	DECLARE @Zero FLOAT 
	SET @Zero = dbo.fnGetZeroValueQTY() 
	
	DECLARE @SrcTypesguid [UNIQUEIDENTIFIER]
	SET @SrcTypesguid = 0x0
	
	DECLARE @cmpUnmctch	BIT
	SET @cmpUnmctch	= 1
	IF EXISTS(SELECT * FROM [op000] WHERE [Name] = 'AmnCfg_UnmatchedMsg' AND [Type] = 0 AND Value = '0')
		SET @cmpUnmctch	= 0

	CREATE TABLE [#SecViol] ([Type] [INT], [Cnt] [INTEGER])  
	CREATE TABLE [#MatTbl] ([MatGUID] [UNIQUEIDENTIFIER], [mtSecurity] [INT])  
	CREATE TABLE [#StoreTbl] ([StoreGUID] [UNIQUEIDENTIFIER], [Security] [INT])  
	CREATE TABLE [#BillsTypesTbl] ([TypeGuid] [UNIQUEIDENTIFIER], [UserSecurity] [INTEGER], UserReadPriceSecurity [INTEGER])  
	CREATE TABLE [#CostTbl] ([CostGUID] [UNIQUEIDENTIFIER], [Security] [INT])  
	CREATE TABLE [#GR] ([Guid] [UNIQUEIDENTIFIER])
	CREATE TABLE [#t_Prices2] ([mtNumber] [UNIQUEIDENTIFIER], [APrice] [FLOAT], [stNumber] [UNIQUEIDENTIFIER])  
	CREATE TABLE [#t_Prices] ([mtNumber] [UNIQUEIDENTIFIER], [APrice] [FLOAT])

	INSERT INTO [#MatTbl]		EXEC [prcGetMatsList] 		@MatGUID, @GroupGUID, 0, @MatCondGuid, 0
	INSERT INTO [#StoreTbl]		EXEC [prcGetStoresList] 	@StoreGUID  
	INSERT INTO [#CostTbl]		EXEC [prcGetCostsList] 		@CostGUID  
	INSERT INTO [#BillsTypesTbl]EXEC [prcGetBillsTypesList]	@SrcTypesguid  
	
	DELETE m
	FROM 
		[#MatTbl] m 
		INNER JOIN mt000 mt ON m.[MatGUID] = mt.GUID 
	WHERE ISNULL(mt.Parent, 0x0) = 0x0

	DECLARE @Admin [INT], @MinSec [INT], @UserGuid [UNIQUEIDENTIFIER], @cnt [INT]  
	SET @UserGuid = [dbo].[fnGetCurrentUserGUID]()  
	SET @Admin = [dbo].[fnIsAdmin](ISNULL(@userGUID, 0x0))  
	IF @Admin = 0  
	BEGIN  
		SET @MinSec = [dbo].[fnGetMinSecurityLevel]()  
		INSERT INTO [#GR] SELECT [Guid] FROM [fnGetGroupsList](@GroupGUID)  
		
		DELETE [r] FROM [#GR] AS [r] INNER JOIN fnGroup_HSecList() AS [f] ON [r].[gUID] = [f].[GUID] where [f].[Security] > [dbo].[fnGetUserGroupSec_Browse](@UserGuid)  
		DELETE [m] FROM 
			[#MatTbl] AS [m]  
			INNER JOIN [mt000] AS [mt] ON [MatGUID] = [mt].[Guid]   
		WHERE 
			[mtSecurity] > [dbo].[fnGetUserMaterialSec_Browse](@UserGuid)   
			OR 
			[Groupguid] NOT IN (SELECT [Guid] FRoM [#Gr])  

		SET @cnt = @@ROWCOUNT  
		IF @cnt > 0  
			INSERT INTO [#SecViol] values(7, @cnt)  
	END

	CREATE TABLE [#t_PricesQnt]
	(
		[mtNumber] 	[UNIQUEIDENTIFIER],
		[APrice] 	[FLOAT],
		[Qnt] [FLOAT]
	)

	DECLARE @CurrencyVal FLOAT = 1
	DECLARE  @defCurr UNIQUEIDENTIFIER = (SELECT TOP 1 GUID FROM my000 WHERE CurrencyVal = 1)

	IF @PriceType = 2 AND (@PricePolicy = 122 or @PricePolicy = 126) -- LastPrice  
	BEGIN  
		EXEC [prcGetLastPriceNewEquation] @StartDate , @EndDate , @MatGUID, @GroupGUID, @StoreGUID, @CostGUID, 0, @CurrencyGUID, @SrcTypesguid, @ShowUnLinked, 0, @type = @PricePolicy	
	END	
	ELSE IF @PriceType = 2 AND @PricePolicy = 120 -- MaxPrice  
	BEGIN  
		EXEC [prcGetMaxPrice] @StartDate, @EndDate, @MatGUID, @GroupGUID, @StoreGUID, @CostGUID, 0, @defCurr, @CurrencyVal, @SrcTypesguid, @ShowUnLinked, 0  
		UPDATE #t_Prices  
			SET APrice =(APrice / dbo.fnGetCurVal(@CurrencyGUID, @EndDate))
	END  
	ELSE IF @PriceType = 2 AND @PricePolicy = 121 -- COST And AvgPrice NO STORE DETAILS  
	BEGIN  
		EXEC [prcGetAvgPrice]	@StartDate,	@EndDate, @MatGUID, @GroupGUID, @StoreGUID, @CostGUID, 0, 
			@CurrencyGUID, @CurrencyVal, @SrcTypesguid,	@ShowUnLinked, 0, 0
	END  
	ELSE IF @PriceType = -1  
		INSERT INTO [#t_Prices] SELECT [MatGUID], 0 FROM [#MatTbl]  
		  
	ELSE IF @PriceType = 2 AND @PricePolicy = 124 -- LastPrice with extra and discount  
	BEGIN  
		EXEC [prcGetLastPriceNewEquation] @StartDate , @EndDate , @MatGUID, @GroupGUID, @StoreGUID, @CostGUID, 0,	@CurrencyGUID, @SrcTypesguid, @ShowUnLinked, 0, 0 /*@CalcLastCost*/,	1 /*@ProcessExtra*/  , 124 ,0
	END  
	ELSE IF @PriceType = 2 AND @PricePolicy = 130  
	BEGIN  
		INSERT INTO [#t_Prices]  
		SELECT   
			[r].[biMatPtr], (SUM([FixedBiTotal]) / SUM([biQty] + [biBonusQnt])) / dbo.fnGetCurVal(@CurrencyGUID, @EndDate)
		FROM  
			[fnExtended_bi_Fixed](@CurrencyGUID) AS [r]  
			INNER JOIN [#BillsTypesTbl] AS [bt] ON [r].[buType] = [bt].[TypeGuid]  
			INNER JOIN [#MatTbl] AS [mtTbl] ON [r].[biMatPtr] = [mtTbl].[MatGUID]  
			INNER JOIN [#StoreTbl] AS [st] ON [st].[StoreGUID] = [biStorePtr]  
		WHERE  
			[budate] BETWEEN @StartDate AND @EndDate AND [BtBillType] = 0  
			AND((@CostGUID = 0x0) OR ([BiCostPtr] IN( SELECT [CostGUID] FROM [#CostTbl])))  
			AND [buIsPosted] > 0   
		GROUP BY [r].[biMatPtr] 
			 
	END  
	ELSE IF @PriceType = 0x8000 
	BEGIN 
		INSERT INTO #t_Prices 
		SELECT 
			MatGuid, 
			[dbo].[fnGetOutbalanceAveragePrice](MatGuid, @EndDate) / dbo.fnGetCurVal(@CurrencyGUID, @EndDate)
		FROM  
			#MatTbl mt 
			JOIN mt000 mat ON mt.MatGuid = mat.[Guid] 
	END 
	ELSE 
	BEGIN  
		DECLARE @UnitType INT 
		SET @UnitType = CASE @UseUnit WHEN 5 THEN 0 ELSE @UseUnit END 
		EXEC [prcGetMtPrice] @MatGUID, @GroupGUID, 0, @CurrencyGUID, @CurrencyVal, @SrcTypesguid, @PriceType, @PricePolicy, @ShowUnLinked, @UnitType, @EndDate
	END  


	CREATE TABLE [#SResult]  
	(  
		[biMatPtr] 			[UNIQUEIDENTIFIER],  
		[biQty]  			[FLOAT],  
		[biQty2]			[FLOAT],  
		[biQty3]			[FLOAT],  
		[Security]			[INT],  
		[UserSecurity] 		[INT],  
		[MtSecurity]		[INT],  
		[APrice]			[FLOAT],  
		[bMove]				[TINYINT],
		mtParent			[UNIQUEIDENTIFIER]
	) 

	INSERT INTO [#SResult]   
	SELECT   
		[r].[biMatPtr],   
		SUM(([r].[biQty] + [r].[biBonusQnt])* [r].[buDirection]),   
		SUM([r].[biQty2]* [r].[buDirection]),   
		SUM([r].[biQty3]* [r].[buDirection]),   
		[r].[buSecurity],   
		[bt].[UserSecurity],   
		[mtTbl].[MtSecurity],   
		CASE  @PricePolicy WHEN 125 THEN CASE WHEN [r].[buDirection] = -1 THEN 0 
			ELSE (r.biPrice/r.biQty) * CASE 
			WHEN @useunit= 0 or (@UseUnit = 3 and mt.mtDefUnit = 1) THEN 
						CASE WHEN r.biUnity = 1 THEN r.biQty
						WHEN r.biUnity = 2 THEN r.biQty2
						ELSE  r.biQty3 END
			WHEN @useunit= 1 or (@UseUnit = 3 and mt.mtDefUnit = 2) THEN 
						CASE WHEN r.biUnity = 1 THEN r.biQty
						WHEN r.biUnity = 2 THEN r.biQty2
						ELSE  r.biQty3 END
			WHEN @useunit= 2 or (@UseUnit = 3 and mt.mtDefUnit = 3)THEN 
						CASE WHEN r.biUnity = 1 THEN r.biQty
						WHEN r.biUnity = 2 THEN r.biQty2
						ELSE  r.biQty3 END
			END END ELSE 0 END,
		1,
		mt.mtParent
	FROM   
		[vwbubi] AS [r]  
		INNER JOIN [#BillsTypesTbl] AS [bt] ON [r].[buType] = [bt].[TypeGuid]   
		INNER JOIN [#MatTbl] AS [mtTbl] ON [r].[biMatPtr] = [mtTbl].[MatGUID]  
		INNER JOIN [vwMt] AS [mt] ON [mtTbl].[MatGUID] = [mt].[mtGUID]   
		INNER JOIN [#StoreTbl] AS [st] ON [st].[StoreGUID] = [biStorePtr]
	WHERE   
		[budate] BETWEEN @StartDate AND @EndDate
		AND ((@CostGUID = 0x0) OR ([BiCostPtr] IN( SELECT [CostGUID] FROM [#CostTbl])))   
		AND [buIsPosted] > 0   
	GROUP BY   
		[r].[biMatPtr],   
		[r].[buSecurity],   
		[bt].[UserSecurity],   
		[mtTbl].[MtSecurity],   
		mt.mtParent,
		CASE  @PricePolicy WHEN 125 THEN CASE WHEN [r].[buDirection] = -1 THEN 0 
			ELSE (r.biPrice/r.biQty) * CASE 
			WHEN @useunit= 0 or (@UseUnit = 3 and mt.mtDefUnit = 1) THEN 
						CASE WHEN r.biUnity = 1 THEN  r.biQty
						WHEN r.biUnity = 2 THEN r.biQty2
						ELSE  r.biQty3 END
			WHEN @useunit= 1 or (@UseUnit = 3 and mt.mtDefUnit = 2) THEN 
						CASE WHEN r.biUnity = 1 THEN  r.biQty
						WHEN r.biUnity = 2 THEN r.biQty2
						ELSE  r.biQty3 END
			WHEN @useunit= 2 or (@UseUnit = 3 and mt.mtDefUnit = 3)THEN 
						CASE WHEN r.biUnity = 1 THEN  r.biQty
						WHEN r.biUnity = 2 THEN r.biQty2
						ELSE  r.biQty3 END
			END END ELSE 0 END 

	IF @ShowEmpty = 1
		INSERT INTO [#SResult]  
		SELECT [mtTbl].[MatGUID], 0, 0, 0, 0, 0,[mtTbl].[MtSecurity], 0, 0, mt.Parent
		FROM  
			[#MatTbl] AS [mtTbl] 
			INNER JOIN mt000 mt ON [mtTbl].MatGUID = mt.GUID
		WHERE [mtTbl].[MatGUID] NOT IN (SELECT [biMatPtr] FROM [#SResult])  

	IF @ShowBalancedMat = 0 
		DELETE [#SResult] WHERE ABS([biQty]) < @Zero AND [bMove] = 1 

	EXEC [prcCheckSecurity] @Result = '#SResult'  

	UPDATE [r] SET [APrice] = [p].[APrice] FROM [#SResult] AS [r] INNER JOIN [#t_Prices] AS [p] ON [mtNumber] = [biMatPtr] 


	CREATE TABLE [#R]  
	(  
		[mtNumber]		[UNIQUEIDENTIFIER],  
		[mtQty]			[FLOAT],  
		[Qnt2]			[FLOAT],  
		[Qnt3]			[FLOAT],  
		[APrice]		[FLOAT],  
		[id]			[INT]	DEFAULT 0,  
		[mtUnitFact]	[FLOAT] DEFAULT 1,  
		[MtGroup]		[UNIQUEIDENTIFIER],  
		[RecType] 		[NVARCHAR](1) COLLATE ARABIC_CI_AI DEFAULT 'm' NOT NULL,  
		[grLevel] 		[INT],  
		[mtName]		[NVARCHAR](500) COLLATE ARABIC_CI_AI,  
		[mtCode]		[NVARCHAR](500) COLLATE ARABIC_CI_AI,  
		[mtLatinName]	[NVARCHAR](500) COLLATE ARABIC_CI_AI,  		 
		[Move]			INT
	)  

	INSERT INTO [#R] ([mtNumber], [mtQty], [Qnt2], [Qnt3], [APrice], [id], [Move], [MtGroup])  
	SELECT  
		[biMatPtr], 
		SUM([biQty]), 
		SUM([biQty2]), 
		SUM([biQty3]), 
		ISNULL([APrice],0), 
		'',   
		MAX([bMove]),
		r.mtParent
	FROM  
		[#SResult] AS [r]  
	GROUP BY  
		[biMatPtr], 
		r.mtParent,
		[APrice]

	UPDATE [r]  
	SET   
		[mtName] = [Name],  
		[mtCode] = [Code],  
		[mtLatinName] = [LatinName],  
		[mtUnitFact] = CASE @UseUnit WHEN 0 THEN 1  
				WHEN 1 THEN CASE [Unit2Fact] WHEN 0 THEN 1 ELSE [Unit2Fact] END  
				WHEN 2 THEN CASE [Unit3Fact] WHEN 0 THEN 1 ELSE [Unit3Fact] END  
				ELSE  
					CASE [DefUnit]  
						WHEN 1 THEN 1  
						WHEN 2 THEN CASE [Unit2Fact] WHEN 0 THEN 1 ELSE [Unit2Fact] END  
						ELSE CASE [Unit3Fact] WHEN 0 THEN 1 ELSE [Unit3Fact] END  
							   
					END  
				END  
	FROM [#R] AS [r]   
	INNER JOIN [mt000] AS [mt] ON [mtNumber] = [mt].[Guid]   

	INSERT INTO [#R] ([mtNumber], [mtQty], [Qnt2], [Qnt3], [APrice], [id], [MtGroup], [RecType], [grLevel], [mtName], [mtCode], [mtLatinName])
	SELECT 
		mt.GUID, SUM(r.[mtQty] / r.[mtUnitFact]), SUM(r.[Qnt2]), SUM(r.[Qnt3]), SUM(r.[APrice] * r.[mtQty]), r.[id], 
		mt.GroupGUID, 'b', 0, mt.Name, mt.Code, mt.LatinName
	FROM 
		mt000 mt 
		INNER JOIN [#R] r ON r.[MtGroup] = mt.GUID
	GROUP BY mt.GUID, r.[id], mt.GroupGUID, mt.Name, mt.Code, mt.LatinName

	IF @ShowGroups > 0  
	BEGIN  
		DECLARE @Level INT 

		CREATE TABLE [#grp]([Guid] [UNIQUEIDENTIFIER], [Level] INT, [grName] NVARCHAR(256), [grLatinName] NVARCHAR(256), [grCode] NVARCHAR(256), [ParentGuid] [UNIQUEIDENTIFIER])
		INSERT INTO [#grp] SELECT [f].[Guid], [f].[Level], [Name] AS [grName], [LatinName] AS [grLatinName], [Code] AS [grCode], [ParentGuid] 
		FROM [dbo].[fnGetGroupsListByLevel](@GroupGUID,0) AS [f] INNER JOIN [gr000] AS [gr] ON [gr].[Guid] = [f].[Guid]  
		
		SELECT @Level = MAX([Level]) FROM [#grp]  
		UPDATE [r]  
		SET   
			[grLevel] = [Level],  
			[mtUnitFact] = CASE @UseUnit WHEN 0 THEN 1  
					WHEN 1 THEN CASE [Unit2Fact] WHEN 0 THEN 1 ELSE [Unit2Fact] END  
					WHEN 2 THEN CASE [Unit3Fact] WHEN 0 THEN 1 ELSE [Unit3Fact] END  
					ELSE  
						CASE [DefUnit]  
							WHEN 1 THEN 1  
							WHEN 2 THEN CASE [Unit2Fact] WHEN 0 THEN 1 ELSE [Unit2Fact] END  
							ELSE CASE [Unit3Fact] WHEN 0 THEN 1 ELSE [Unit3Fact] END  
							   
						END  
					END  
					 
		FROM [#R] AS [r]   
		INNER JOIN [mt000] AS [mt] ON [mtNumber] = [mt].[Guid]   
		INNER JOIN [#grp] AS [gr] ON [gr].[Guid] = r.MtGroup  

		INSERT INTO [#R]([mtNumber],[mtQty],[Qnt2],[Qnt3],[APrice],[id],[MtGroup],[RecType],[grLevel],[mtName],[mtCode],[mtLatinName])  
		SELECT  [gr].[Guid],SUM([mtQty]/[mtUnitFact]),SUM([Qnt2]),SUM([Qnt3]),SUM([APrice] *[mtQty]),[id],[gr].[ParentGuid],'g',[gr].[Level],[grName],[grCode],[grLatinName]   
		FROM 
			[#R] AS [r] 
			INNER JOIN  [#grp] AS [gr] ON [gr].[Guid] = [r].[MtGroup]  
		GROUP BY [gr].[Guid], [id], [gr].[ParentGuid], [gr].[Level], [grName], [grCode], [grLatinName]   
		
		WHILE (@Level > 0)  
		BEGIN  
			UPDATE r 
			SET 
				[mtQty] = r.[mtQty] + r1.mtQty, 
				[Qnt2] = r.[Qnt2] + r1.[Qnt2],
				[Qnt3] = r.[Qnt3] + r1.[Qnt3],
				[APrice] = r.[APrice] + r1.[APrice]
			FROM 
				[#R] AS [r] INNER JOIN [#grp] AS [gr] ON [gr].[Guid] = [r].[mtNumber]
				INNER JOIN (
					SELECT 
						[MtGroup] AS [MtGroup], 
						SUM([mtQty]) AS mtQty, 
						SUM([Qnt2]) AS Qnt2, 
						SUM([Qnt3]) AS Qnt3,
						SUM([APrice]) AS [APrice] FROM [#R] WHERE [grLevel] = @Level AND [RecType] = 'g' 
							GROUP BY [MtGroup]) r1 ON r1.[MtGroup] = [gr].[Guid]

			INSERT INTO [#R]([mtNumber], [mtQty], [Qnt2], [Qnt3], [APrice], [id], [MtGroup], [RecType], [grLevel], [mtName], [mtCode], [mtLatinName])   
			SELECT [gr].[Guid],SUM([mtQty]),SUM([Qnt2]),SUM([Qnt3]),SUM([APrice]), [id], [gr].[ParentGuid], 'g', [gr].[Level], [grName], [grCode], [grLatinName]  
			FROM [#R] AS [r] INNER JOIN  [#grp] AS [gr] ON [gr].[Guid] = [r].[MtGroup]  
			WHERE [r].[grLevel] = @Level AND [RecType] = 'g' AND [gr].[Guid] not in (select mtNumber from #R)
			GROUP BY [gr].[Guid], [id], [gr].[ParentGuid], [gr].[Level], [grName], [grCode], [grLatinName]

			SET @Level = @Level - 1  
		END  

		CREATE TABLE [#MainRes3]  
		(  
			[mtNumber]		[UNIQUEIDENTIFIER],  
			[mtQty]			[FLOAT],  
			[Qnt2]			[FLOAT],  
			[Qnt3]			[FLOAT],  
			[APrice]		[FLOAT],  
			[id]			[INT]	DEFAULT 0,  
			[MtGroup]		[UNIQUEIDENTIFIER],  
			[RecType] 		[NVARCHAR](1) COLLATE ARABIC_CI_AI DEFAULT 'm' NOT NULL,  
			[grLevel] 		[INT],  
			[mtName]		[NVARCHAR](255) COLLATE ARABIC_CI_AI,  
			[mtCode]		[NVARCHAR](255) COLLATE ARABIC_CI_AI,  
			[mtLatinName]		[NVARCHAR](255) COLLATE ARABIC_CI_AI,  
			[mtUnitFact]	[FLOAT],
			[Path]			[NVARCHAR](MAX),
			[MaterialGUID]  [UNIQUEIDENTIFIER],
			[Move]		INT
		) 

		INSERT INTO [#MainRes3]  
		SELECT 
			r.[mtNumber],
			SUM(r.[mtQty]) AS [mtQty],
			SUM(r.[Qnt2]) AS [Qnt2],
			SUM(r.[Qnt3]) AS [Qnt3],
			SUM(r.[APrice]) [APrice],
			0,
			r.[MtGroup],
			r.[RecType],
			r.[grLevel],
			r.[mtName],
			r.[mtCode],
			r.[mtLatinName],
			r.[mtUnitFact],
			f.[Path],
			r.[mtNumber],
			r.[move]
		FROM 
			[#r] as r LEFT JOIN [dbo].[fnGetGroupsOfGroupSorted](0x0, 0) as f ON [r].[mtNumber] = f.[GUID]
		WHERE 
			r.[RecType] = 'g' 
		GROUP BY  
			r.[mtNumber],
			r.[mtName],
			r.[mtCode],
			r.[mtLatinName],
			r.[MtGroup],
			r.[RecType],
			r.[grLevel],
			r.[mtUnitFact],
			f.[Path],
			r.[mtNumber],
			r.[move]
		UNION ALL  
		SELECT 
			r.[mtNumber],
			SUM(r.[mtQty]),
			SUM(r.[Qnt2]),
			SUM(r.[Qnt3]),
			SUM(r.[APrice]),
			0,
			r.[MtGroup],
			r.[RecType],
			r.[grLevel],
			r.[mtName],
			r.[mtCode],
			r.[mtLatinName],
			r.[mtUnitFact],
			'Material',
			r.[mtNumber],
			r.[move]
		FROM 
			[#r] as r 
		WHERE 
			r.[RecType] = 'm' OR r.[RecType] = 'b'
		GROUP BY  
			r.[mtNumber],
			r.[mtName],
			r.[mtCode],
			r.[mtLatinName],
			r.[MtGroup],
			r.[RecType],
			r.[grLevel],
			r.[mtUnitFact],
			r.[mtNumber],
			r.[move]
	END  

	CREATE TABLE #FinalResult(
		[move] INT,
		[mtNumber] UNIQUEIDENTIFIER, 
		[Qnt] FLOAT,   
		[Qnt2] FLOAT, [Qnt3] FLOAT,	
		[APrice] FLOAT,  
		[mtUnity] NVARCHAR(250), 
		[MtUnit2] NVARCHAR(250), 
		[MtUnit3] NVARCHAR(250), 
		[mtDefUnitFact] FLOAT, 
		[grName] NVARCHAR(250), 
		[grCode] NVARCHAR(250),
		[mtUnitFact] FLOAT, 
		mtUnit2Fact FLOAT, 
		mtUnit3Fact FLOAT, 
		[mtDefUnitName] NVARCHAR(250),  
		MtName NVARCHAR(250), 
		MtCode NVARCHAR(250), 
		[mtLatinName] NVARCHAR(250), 
		[MtGroup] UNIQUEIDENTIFIER,
		[GroupParent] UNIQUEIDENTIFIER,
		[RecType] NVARCHAR(10),
		[grLevel] INT,
		[Quantity1] FLOAT,
		QuantityName1 NVARCHAR(250),
		[Quantity2] FLOAT,
		QuantityName2 NVARCHAR(250),
		[Quantity3] FLOAT,
		QuantityName3 NVARCHAR(250),
		UnitName NVARCHAR(250),
		[Price] FLOAT,
		[AVal] FLOAT,
		-- [path] NVARCHAR(250),
		MaterialGUID UNIQUEIDENTIFIER,
		[Qty] FLOAT, 
		[Qty2] FLOAT,
		[Qty3] FLOAT,
		NotMatchedQty BIT
	)

	DECLARE @SqlStr [NVARCHAR](MAX)  
	DECLARE @Str [NVARCHAR](MAX)  

	SET @Str = '  
		[r].[mtNumber], [r].[mtQty] AS [Qnt],   
		[r].[Qnt2], [r].[Qnt3],	[r].[APrice],  
		ISNULL([v_mt].[mtUnity], '''') AS [mtUnity], ISNULL([v_mt].[MtUnit2], '''') AS [MtUnit2], ISNULL([v_mt].[MtUnit3], '''') AS [MtUnit3], ISNULL([v_mt].[mtDefUnitFact], '''') AS [mtDefUnitFact], ISNULL([v_mt].[grName],' + '''' + '''' +') AS [grName], ISNULL([v_mt].[grCode],' + '''' + '''' +') AS [grCode], '    
	
	IF @ShowGroups > 0 
	BEGIN 
		SET @Str = @Str + ' ISNULL([r].[mtUnitFact], '''') AS [mtUnitFact],' 
	END 
	ELSE 
	BEGIN 
		IF @UseUnit = 0  
			SET @Str = @Str + 'CASE [r].[mtUnitFact] WHEN 0 THEN 1 ELSE [r].[mtUnitFact] END AS [mtUnitFact],' 		 
		ELSE IF @UseUnit = 1   
			SET @Str = @Str + 'CASE [v_mt].[mtUnit2Fact] WHEN 0 THEN 1 ELSE [v_mt].[mtUnit2Fact] END AS [mtUnitFact],'  
		ELSE IF @UseUnit = 2   
			SET @Str = @Str + 'CASE [v_mt].[mtUnit3Fact] WHEN 0 THEN 1 ELSE [v_mt].[mtUnit3Fact] END AS [mtUnitFact],'  
		ELSE   
			SET @Str = @Str + ' ISNULL([mtDefUnitFact], '''') AS [mtUnitFact],'  
	END 

	DECLARE @Prefix [NVARCHAR](10)  
	SET @Prefix = ' v_mt.'  
	SET @Str = @Str + ' ISNULL([v_mt].[mtUnit2Fact], 0 ) as mtUnit2Fact, ISNULL([v_mt].[mtUnit3Fact], 0) as mtUnit3Fact, ISNULL([v_mt].[mtDefUnitName],'+''''+''''+') AS [mtDefUnitName],'  

	IF @ShowGroups > 0  
		SET @Str = @Str + ' [r].[mtName] AS MtName, [r].[mtCode] AS MtCode, [r].[mtLatinName],  '  
	else	  
		SET @Str = @Str + ' [v_mt].[mtName] AS MtName, [v_mt].[mtCode] AS MtCode, [v_mt].[mtLatinName], '  

	SET @Str = @Str + ' [r].[MtGroup], CAST(0x0 AS [UNIQUEIDENTIFIER]) AS [GroupParent],[r].[RecType],'  
	IF @ShowGroups > 0  
	BEGIN  
		SET @Str = @Str + ' [r].[grLevel] '  
	END  
	ELSE  
	BEGIN  
		SET @Str = @Str + ' 0 AS [grLevel] '  
	END  

	SET @SqlStr =  '
		INSERT INTO #FinalResult 
		SELECT ISNULL(r.[move], -1) AS move, ' + @Str  
	
	IF @ShowDetailsUnits > 0
	BEGIN 
		SET @SqlStr = @SqlStr + 
			', 0 AS [Quantity1], 
			CASE r.RecType WHEN ''g'' THEN '''' ELSE [mtUnity] END AS QuantityName1, 
			0 AS Quantity2, 
			CASE r.RecType WHEN ''g'' THEN '''' ELSE [MtUnit2] END AS QuantityName2, 
			0 AS Quantity3, 
			CASE r.RecType WHEN ''g'' THEN '''' ELSE [MtUnit3] END AS QuantityName3,
			'''' AS UnitName '
	END ELSE BEGIN 
		SET @SqlStr = @SqlStr + 
			', 0 AS [Quantity1], '''' AS QuantityName1, 0 AS Quantity2, '''' AS QuantityName2, 0 AS Quantity3, '''' AS QuantityName3 '
		IF @UseUnit = 0
			SET @SqlStr = @SqlStr + ', CASE [mtUnity] WHEN '''' THEN [mtDefUnitName] ELSE [mtUnity] END AS UnitName'
		ELSE IF @UseUnit = 1
			SET @SqlStr = @SqlStr + ', CASE [MtUnit2] WHEN '''' THEN [mtDefUnitName] ELSE [MtUnit2] END AS UnitName'
		ELSE IF @UseUnit = 2
			SET @SqlStr = @SqlStr + ', CASE [MtUnit3] WHEN '''' THEN [mtDefUnitName] ELSE [MtUnit3] END AS UnitName'
		ELSE 
			SET @SqlStr = @SqlStr + ', ISNULL([mtDefUnitName], '''') AS UnitName'
	END 
	
	SET @SqlStr = @SqlStr + 
		', CASE [r].RecType WHEN ''m'' THEN [r].[APrice] ELSE 0.0 END AS [Price]
		, CASE [r].RecType WHEN ''m'' THEN [r].[mtQty] * [r].[APrice] ELSE 0.0 END AS [AVal] '
		
	IF @ShowGroups > 0 
		SET @SqlStr = @SqlStr + ', MaterialGUID' 
	ELSE 
		SET @SqlStr = @SqlStr + ', r.[mtNumber] AS MaterialGUID' 
	SET @SqlStr = @SqlStr + ' 
		,CASE 
			WHEN [r].[RecType] = ''m'' THEN ' +
				CASE @UseUnit
					WHEN 0 THEN ' [r].[mtQty] '
					WHEN 1 THEN ' [r].[mtQty] / (CASE [v_mt].[mtUnit2Fact] WHEN 0 THEN [mtDefUnitFact] ELSE [v_mt].[mtUnit2Fact] END) '
					WHEN 2 THEN ' [r].[mtQty] / (CASE [v_mt].[mtUnit3Fact] WHEN 0 THEN [mtDefUnitFact] ELSE [v_mt].[mtUnit3Fact] END) '
					WHEN 3 THEN ' [r].[mtQty] / [mtDefUnitFact] '
					ELSE ' [r].[mtQty] '
				END
	SET @SqlStr = @SqlStr + ' 
			ELSE [r].[mtQty] 
		END AS Qty,'
	IF @ShowUnLinked <> 1
		SET @SqlStr = @SqlStr + ' 
			CASE [mtUnit2Fact] 
				WHEN 0 THEN 0
				ELSE [r].[mtQty] / [mtUnit2Fact]
			END AS [Qty2],
			CASE [mtUnit3Fact] 
				WHEN 0 THEN 0
				ELSE [r].[mtQty] / [mtUnit3Fact]
			END AS [Qty3], 0 '
	ELSE
		SET @SqlStr = @SqlStr + ' 
				[r].[Qnt2] AS [Qty2],
				[r].[Qnt3] AS [Qty3], 0 '

	SET @SqlStr = @SqlStr + ' FROM '  
	IF @ShowGroups > 0 
	BEGIN
		SET @SqlStr = @SqlStr + ' [#MainRes3] AS [r1] LEFT JOIN [#R] AS [r] ON [r].[mtNumber] = [r1].[mtNumber]'
		SET @SqlStr = @SqlStr + ' LEFT '
	END   
	ELSE  
		SET @SqlStr = @SqlStr + ' [#R] AS [r] INNER '  
	SET @SqlStr = @SqlStr + ' JOIN [vwmtgr] AS [v_mt] ON [r].[mtNumber] = [v_mt].[mtGUID] '  
	
	EXECUTE ( @SqlStr )  

	IF @ShowDetailsUnits > 0
	BEGIN 
		UPDATE #FinalResult
		SET 
			[Quantity3] = (CASE [mtUnit3Fact] WHEN 0 THEN 0 ELSE CAST([Qnt] / [mtUnit3Fact] AS INT) END)
		WHERE 
			RecType = 'm'
		UPDATE #FinalResult
		SET 
			[Quantity2] = (CASE [mtUnit2Fact] WHEN 0 THEN 0 ELSE CAST( ([Qnt] - [Quantity3] * [mtUnit3Fact]) / [mtUnit2Fact] AS INT) END)
		WHERE 
			RecType = 'm'
		UPDATE #FinalResult
		SET 
			[Quantity1] = ([Qnt] - [Quantity3] * [mtUnit3Fact] - [Quantity2] * [mtUnit2Fact])
		WHERE 
			RecType = 'm'
	END 

	UPDATE fr
	SET 
		AVal = gr.[AVal],
		[Qty2] = gr.[Qty2],
		[Qty3] = gr.[Qty3],
		Quantity1 = gr.[Quantity1],
		Quantity2 = gr.[Quantity2],
		Quantity3 = gr.[Quantity3]
	FROM
		#FinalResult fr 
		INNER JOIN (
			SELECT 
				MtGroup,
				SUM([AVal]) AS [AVal],
				SUM([Qty2]) AS [Qty2],
				SUM([Qty3]) AS [Qty3],
				SUM([Quantity1]) AS [Quantity1],
				SUM([Quantity2]) AS [Quantity2],
				SUM([Quantity3]) AS [Quantity3]
			FROM 
				#FinalResult
			WHERE RecType = 'm'
			GROUP BY MtGroup) gr ON gr.MtGroup = fr.mtNumber

	IF @ShowGroups > 0
	BEGIN 
		CREATE TABLE #GroupFinalResult (
			MtGroup UNIQUEIDENTIFIER,
			[AVal] FLOAT,
			[Qty2] FLOAT,
			[Qty3] FLOAT,
			[Quantity1] FLOAT,
			[Quantity2] FLOAT,
			[Quantity3] FLOAT
		)
		DECLARE @MaxLevel INT
		SET @MaxLevel = (SELECT MAX(grlevel) FROM #FinalResult)
		WHILE (ISNULL(@MaxLevel, 0) >= 1)
		BEGIN 
			TRUNCATE TABLE #GroupFinalResult
			INSERT INTO #GroupFinalResult
			SELECT 
				MtGroup,
				SUM([AVal]) AS [AVal],
				SUM([Qty2]),
				SUM([Qty3]),
				SUM([Quantity1]) AS [Quantity1],
				SUM([Quantity2]) AS [Quantity2],
				SUM([Quantity3]) AS [Quantity3]
			FROM 
				#FinalResult	
			GROUP BY MtGroup

			UPDATE fr
			SET 
				AVal = gr.[AVal],
				[Qty2] = gr.[Qty2],
				[Qty3] = gr.[Qty3],
				Quantity1 = gr.[Quantity1],
				Quantity2 = gr.[Quantity2],
				Quantity3 = gr.[Quantity3]
			FROM
				#FinalResult fr 
				INNER JOIN #GroupFinalResult gr ON fr.mtNumber = gr.MtGroup AND fr.grlevel = @MaxLevel
			SET @MaxLevel = @MaxLevel - 1
		END
	END 

	IF @ShowDetailsUnits = 0
	BEGIN 
		UPDATE #FinalResult SET Price = CASE Qty WHEN 0 THEN Price ELSE AVal / Qty END 
	END 

	IF (@ShowGroups > 0) OR (@ShowCompositions > 0)
	BEGIN
		UPDATE [#FinalResult] SET [MaterialGUID] = NEWID() WHERE [RecType] = 'm';
	END  
	
	IF @ShowCompositions = 0
		DELETE #FinalResult WHERE RecType = 'm'

	SELECT 
		*,
		CASE WHEN [RecType] <> 'g' THEN [mtNumber] ELSE 0x0 END AS OnlyMaterialGuid
	FROM 
		#FinalResult
	ORDER BY MtCode

	SELECT * FROM [#SecViol]    
###########################################################
#END