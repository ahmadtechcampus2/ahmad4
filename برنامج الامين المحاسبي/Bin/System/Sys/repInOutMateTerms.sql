################################################################################
CREATE PROCEDURE repInOutMatTerms
	@StartDate 		[DATETIME], 
	@EndDate		[DATETIME], 
	@MatGUID 		[UNIQUEIDENTIFIER], 
	@GroupGUID 		[UNIQUEIDENTIFIER], 
	@StoreGUID		[UNIQUEIDENTIFIER],
	@UseUinit		[INT],
	@Lang			[BIT] = 0,
	@Period			[INT] = 0,
	@MatCondGuid	[UNIQUEIDENTIFIER] = 0x00,
	@SrcTypes 		[UNIQUEIDENTIFIER]= 0x00,
	@GroupedByStores [BIT] 
AS
	SET NOCOUNT ON
	CREATE TABLE [#SecViol]( [Type] [INT], [Cnt] [INTEGER])  
	CREATE TABLE [#MatTbl]( [MatGUID] [UNIQUEIDENTIFIER], [mtSecurity] [INT])  
	CREATE TABLE [#BillsTypesTbl]( [TypeGuid] [UNIQUEIDENTIFIER], [UserSecurity] [INTEGER], [UserReadPriceSecurity] [INTEGER],[UnPostedSecurity] [INT])  
	CREATE TABLE [#StoreTbl](	[StoreGUID] [UNIQUEIDENTIFIER], [Security] [INT])  
	CREATE TABLE [#CostTbl]( [CostGUID] [UNIQUEIDENTIFIER], [Security] [INT])  
	DECLARE @Def [FLOAT]
	SET @Def = DATEDIFF(day, @StartDate, @EndDate) 
	IF (@Def = 0)
		SET @Def = 1
	SET @Def = @Def / 
		CASE @Period 
			WHEN 1 THEN 7 
			WHEN 2 THEN 30 
			WHEN 3 THEN 91
			WHEN 4 THEN 182
			WHEN 5 THEN 365
			ELSE 1 END
	INSERT INTO [#MatTbl]			EXEC [prcGetMatsList] 		@MatGUID, @GroupGUID ,-1,@MatCondGuid
	INSERT INTO [#BillsTypesTbl]	EXEC [prcGetBillsTypesList2] @SrcTypes--, @UserGuid  
	INSERT INTO [#StoreTbl]			EXEC [prcGetStoresList] 	@StoreGUID  
	INSERT INTO [#CostTbl]			EXEC [prcGetCostsList] 		0X00
	
	IF @SrcTypes IS NULL
		SET @SrcTypes = ''
	IF [dbo].[fnGetUserMaterialSec_Balance]([dbo].[fnGetCurrentUserGuid]()) > 0
			update [#billsTypesTbl] set [userSecurity] = [dbo].[fnGetMaxSecurityLevel]()
	IF @GroupGUID = 0X00 OR @MatGUID = 0X00
		INSERT INTO [#CostTbl] VALUES(0X00,0)
	CREATE TABLE [#RESULT]
	(
		[MatGuid]	[UNIQUEIDENTIFIER], 
		[StoreGuid]	[UNIQUEIDENTIFIER], 
		[Qty]		[FLOAT],
		[Security]	[INT],
		[mtSecurity]	[INT],
		[stSecurity]	[INT],
		[btSecurity]	[INT],
		[Direction]	[INT],
		[Sale]		[BIT],
		[Preiod]	[INT]
	)
	CREATE TABLE [#EndResult]
	(
		[MatGuid]	[UNIQUEIDENTIFIER], 
		[StoreGuid]	[UNIQUEIDENTIFIER],
		[MtCode]	[NVARCHAR](256) COLLATE ARABIC_CI_AI, 
		[MtName]	[NVARCHAR](256) COLLATE ARABIC_CI_AI,   
		[MinTerm]	[FLOAT] ,	
		[MaxTerm]	[FLOAT] ,	
		[OredeTerm]	[FLOAT] ,
		[UnitFact]	[FLOAT] ,
		[MatUnitName] [NVARCHAR](256) COLLATE ARABIC_CI_AI,
		[PrevBalQty]	[FLOAT] DEFAULT 0,
		[SalesAmount]	[FLOAT] DEFAULT 0,
		[Qty]		[FLOAT] ,
		[InQty]		[FLOAT] DEFAULT 0,
		[OutQty]	[FLOAT] DEFAULT 0
	)
	
	INSERT INTO [#RESULT] 
	SELECT
	[biMatPtr],[biStorePtr],
	SUM([biQty]),
	[buSecurity],
	[mtSecurity],
	[st].[Security],
	[UserSecurity],
	[buDirection],
	CASE  WHEN [btBillType] = 1 AND [buDate] BETWEEN @StartDate AND @EndDate THEN 1 ELSE 0 END,
	CASE WHEN [buDate] < @StartDate THEN 0 WHEN [buDate] BETWEEN @StartDate AND @EndDate THEN 1 ELSE 2 END
	FROM [vwbubi] AS [bu] 
	INNER JOIN [#MatTbl] AS [mt] ON [mt].[MatGUID] = [bu].[biMatPtr]
	INNER JOIN  [#StoreTbl] AS [st] ON [StoreGUID] = [bu].[biStorePtr]
	INNER JOIN  [#BillsTypesTbl] AS [bt] ON [TypeGuid] = [buType] 
	INNER JOIN  [#CostTbl] AS [co] ON [CostGUID] = [biCostPtr]
	WHERE [buIsPosted] > 0
	GROUP BY
		[biMatPtr],[biStorePtr],
		[buSecurity],
		[mtSecurity],
		[st].[Security],
		[UserSecurity],
		[buDirection],
		CASE  WHEN [btBillType] = 1 AND [buDate] BETWEEN @StartDate AND @EndDate THEN 1 ELSE 0 END,
		CASE WHEN [buDate] < @StartDate THEN 0 WHEN [buDate] BETWEEN @StartDate AND @EndDate THEN 1 ELSE 2 END
	
	DECLARE @Admin [INT],@UserGuid [UNIQUEIDENTIFIER],@BalSec [INT] 
	SET @UserGuid = [dbo].[fnGetCurrentUserGUID]() 
	SET @Admin = [dbo].[fnIsAdmin](ISNULL(@userGUID,0x00) ) 
	IF (@Admin = 0)
	BEGIN
		SET @BalSec = [dbo].[fnGetUserMaterialSec_Balance](@UserGuid)
		UPDATE [#Result] SET [Security] = -5 WHERE [mtSecurity] >= @BalSec
		EXEC [prcCheckSecurity] 
	END
	CREATE CLUSTERED INDEX [rInd] ON [#RESULT]([MatGuid],[StoreGuid])
	INSERT INTO [#EndResult]([MatGuid],[StoreGuid],[Qty]) 
	SELECT [MatGuid],[StoreGuid],SUM([Qty]*[Direction]) FROM [#RESULT] GROUP BY [MatGuid],[StoreGuid]
	CREATE CLUSTERED INDEX [rInd] ON [#EndResult]([MatGuid],[StoreGuid])
	UPDATE [r]
		SET [MtCode] = [mt].[Code], 
		[MtName] = CASE @Lang WHEN 0 THEN [mt].[Name] ELSE CASE [mt].[LatinName] WHEN '' THEN [mt].[Name] ELSE  [mt].[LatinName] END END,    
		[MinTerm] = [Low],	
		[MaxTerm] = [High],	
		[OredeTerm] = [OrderLimit],
		[UnitFact] = CASE @UseUinit 
				WHEN 0 THEN 1 
				WHEN 1 THEN CASE [Unit2Fact] WHEN 0 THEN 1 ELSE [Unit2Fact] END
				WHEN 2 THEN CASE [Unit3Fact] WHEN 0 THEN 1 ELSE [Unit3Fact] END
				ELSE
					CASE [DefUnit] 
						WHEN 1 THEN 1 
						WHEN 2 THEN CASE [Unit2Fact] WHEN 0 THEN 1 ELSE [Unit2Fact] END
						ELSE CASE [Unit3Fact] WHEN 0 THEN 1 ELSE [Unit3Fact] END
					end
				END,
		[MatUnitName] = CASE @UseUinit WHEN 0 THEN [Unity] WHEN 1 THEN [Unit2] WHEN 2 THEN [Unit3] WHEN 3 THEN 
					CASE [DefUnit] WHEN 1 THEN [Unity] WHEN 2 THEN [Unit2] ELSE [Unit3] END END
		FROM [#EndResult] AS [r] INNER JOIN [mt000] AS [mt] ON [mt].[Guid] =  [MatGuid]
		
	UPDATE [e]   SET [InQty] = [In], [OutQty] = [Out]
	FROM  [#EndResult] AS [e] 
	INNER JOIN ( SELECT [MatGuid],[StoreGuid],SUM( [Qty]* CASE [Direction] WHEN -1 THEN 0 ELSE 1 END) AS [In] ,SUM( [Qty]* CASE [Direction] WHEN 1 THEN 0 ELSE 1 END) AS [Out] FROM [#RESULT] WHERE [Preiod] = 1 GROUP BY [MatGuid],[StoreGuid]) AS [r] ON [e].[MatGuid] = [r].[MatGuid] AND [e].[StoreGuid] = [r].[StoreGuid]

	UPDATE [e]   SET [PrevBalQty] = [Qut]
	FROM  [#EndResult] AS [e] 
	INNER JOIN ( SELECT [MatGuid],[StoreGuid],SUM( [Qty]* [Direction]) AS [Qut] FROM [#RESULT] WHERE [Preiod] = 0 GROUP BY [MatGuid],[StoreGuid]) AS [r] ON [e].[MatGuid] = [r].[MatGuid] AND [e].[StoreGuid] = [r].[StoreGuid]
		
	UPDATE [e]   SET [SalesAmount] = [Qut]
	FROM  [#EndResult] AS [e] 
	INNER JOIN ( SELECT [MatGuid],[StoreGuid],SUM( [Qty]* [Sale])/@Def AS [Qut] FROM [#RESULT]  GROUP BY [MatGuid],[StoreGuid]) AS [r] ON [e].[MatGuid] = [r].[MatGuid] AND [e].[StoreGuid] = [r].[StoreGuid]


IF(@GroupedByStores = 1)
BEGIN

	SELECT 	
		[MatGuid], 
		[MatUnitName],
		[StoreGuid],
		[MtCode], 
		[MtName], 
		[MtCode] +' - '+ [MtName] AS Material,
		[st].[Code] + '-' + CASE @Lang WHEN 0 THEN [st].[Name] ELSE  CASE [st].[LatinName] WHEN '' THEN [st].[Name] ELSE [st].[LatinName] END END AS [store],
		[MinTerm]/[UnitFact] AS [MinTerm] ,	
		[MaxTerm]/[UnitFact] AS [MaxTerm],	
		[OredeTerm]/[UnitFact] AS [OredeTerm] ,
		[PrevBalQty]/[UnitFact] AS [PrevBalQty],
		[SalesAmount]/[UnitFact] AS [SalesAmount],
		[Qty]/[UnitFact] AS [Qty],
		[InQty]/[UnitFact] AS [InQty],
		[OutQty]/[UnitFact] AS	[OutQty]
	FROM [#EndResult] AS [r] INNER JOIN [St000] AS [st] ON [st].[Guid] = [StoreGuid]

END

--++++++++++++++++++++++++++++++++++++   GROUPED BY STORES RESULT

ELSE
BEGIN
		SELECT 	
			 [MatGuid], 
			 [MatUnitName],
			 [StoreGuid],
			 [MtCode], 
			 [MtName], 
			 [MtCode] +' - '+ [MtName] AS Material,
			 [st].[Code] + '-' + CASE @Lang WHEN 0 THEN [st].[Name] ELSE  CASE [st].[LatinName] WHEN '' THEN [st].[Name] ELSE [st].[LatinName] END END AS [store],
			 [MinTerm]/[UnitFact] AS [MinTerm] ,	
			 [MaxTerm]/[UnitFact] AS [MaxTerm],	
			 [OredeTerm]/[UnitFact] AS [OredeTerm] ,
			 [PrevBalQty]/[UnitFact] AS [PrevBalQty],
			 0 AS [SalesAmount],
			 [Qty]/[UnitFact] AS [Qty],
			 [InQty]/[UnitFact] AS [InQty],
			 [OutQty]/[UnitFact] AS	[OutQty]
		INTO #GroupedResult
		FROM [#EndResult] AS [r] 
		INNER JOIN [St000] AS [st] ON [st].[Guid] = [StoreGuid]



CREATE TABLE [#EndGroupedResult]
	(
		[MatGuid]		UNIQUEIDENTIFIER, 
		[MtName]		NVARCHAR(256) COLLATE ARABIC_CI_AI,
		[MtCode]		NVARCHAR(256) COLLATE ARABIC_CI_AI,
		[Material]		NVARCHAR(256),
		[MatUnitName]	NVARCHAR(256) COLLATE ARABIC_CI_AI,
		[SalesAmount]	FLOAT DEFAULT 0,
		[MinTerm]		FLOAT,
		[MaxTerm]		FLOAT,	
		[OredeTerm]		FLOAT,
		[Qty]			FLOAT,
		[PrevBalQty]	FLOAT DEFAULT 0,
		[InQty]			FLOAT DEFAULT 0,
		[OutQty]		FLOAT DEFAULT 0
	)

INSERT INTO [#EndGroupedResult]
	SELECT MatGuid,
		   MtName,
		   MtCode,
		   Material,
		   MatUnitName,
		   SalesAmount,
		   MAX(MinTerm)		   AS [MinTerm],
		   MAX(MaxTerm)		   AS [MaxTerm], 
		   MAX(OredeTerm)	   AS [OredeTerm],
		   SUM(Qty)			   AS [Qty],
		   SUM(PrevBalQty)	   AS [PrevBalQty],
		   SUM(InQty)		   AS [InQty],
		   SUM(OutQty)		   AS [OutQty]
	FROM #GroupedResult 
	GROUP BY MatGuid,
			 MtName,
			 MtCode,
			 Material,
			 MatUnitName,
			 SalesAmount


			SELECT * INTO #TempResult FROM #EndGroupedResult
			DECLARE @Id [UNIQUEIDENTIFIER]
			DECLARE @Qty [FLOAT]
		
			WHILE (SELECT Count(*) FROM #TempResult) > 0
			BEGIN
				SELECT TOP 1 @Id = MatGuid FROM #TempResult
	
				UPDATE #EndGroupedResult
				SET SalesAmount =  (SELECT isnull(SUM(bi.Qty), 0)
								    FROM bi000 bi 
								    INNER JOIN bu000 bu ON bi.ParentGUID = bu.[GUID]
								    INNER JOIN bt000 bt ON bu.TypeGUID = bt.[GUID]
									WHERE bt.BillType = 1
									AND	  bu.[Date] BETWEEN @StartDate AND @EndDate
								    AND   bi.MatGUID = @Id)
				WHERE MatGuid = @Id

				DELETE #TempResult WHERE MatGuid = @Id
			END

			UPDATE #EndGroupedResult
			SET SalesAmount = SalesAmount / @Def
	
	SELECT * FROM #EndGroupedResult

END

--++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

SELECT * FROM [#SecViol]
###################################################################################
#END