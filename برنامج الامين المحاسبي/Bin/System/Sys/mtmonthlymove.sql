##########################################################
CREATE PROCEDURE repMtMonthlyMove
	@StartDate 		[DATETIME], 
	@EndDate 		[DATETIME], 
	@SrcTypesGUID	[UNIQUEIDENTIFIER], 
	@MatGUID 		[UNIQUEIDENTIFIER], 
	@GroupGUID 		[UNIQUEIDENTIFIER], 
	@CustGUID 		[UNIQUEIDENTIFIER], 
	@StoreGUID 		[UNIQUEIDENTIFIER], 
	@CostGUID 		[UNIQUEIDENTIFIER], 
	@AccGUID 		[UNIQUEIDENTIFIER], 
	@CurrencyGUID 	[UNIQUEIDENTIFIER], 
	@CurrencyVal 	[FLOAT], 
	@ViewType 		[INT],
	@UseUnit		[INT],
	@Str			[NVARCHAR](max) = '',
	@InOutSign		[INT] = 0,
	@MatCondGUID 	[UNIQUEIDENTIFIER] = 0X00,
	@CustCondGUID	[UNIQUEIDENTIFIER] = 0x0,
	@ShowGrp		[BIT] = 0,
	@GrpLevel		[INT] = 0,
	@ShowMt			[BIT] = 1,
	@Collect1		[INT] = 0,
	@Collect2		[INT] = 0,
	@Collect3		[INT] = 0,
	@DetLag			[INT] = 0,
	@ShowFlag		[INT] = 0,
	@Axe			[INT] = 0
AS 
	SET NOCOUNT ON 
	DECLARE 
		@s		NVARCHAR(max),
		@Col1	NVARCHAR(100),
		@Col2	NVARCHAR(100),
		@Col3	NVARCHAR(100) 
		
	-- Creating temporary tables 
	CREATE TABLE [#SecViol] ([Type] [INT], [Cnt] [INTEGER]) 
	CREATE TABLE [#MatTbl] ([MatGUID] [UNIQUEIDENTIFIER], [mtSecurity] [INT]) 
	CREATE TABLE [#BillsTypesTbl] ([TypeGuid] [UNIQUEIDENTIFIER], [UserSecurity] [INTEGER], [UserReadPriceSecurity] [INTEGER], [UnPostedSecurity] [INTEGER]) 
	CREATE TABLE [#StoreTbl] ([StoreGUID] [UNIQUEIDENTIFIER], [Security] [INT]) 
	CREATE TABLE [#CostTbl] ([CostGUID] [UNIQUEIDENTIFIER], [Security] [INT]) 
	CREATE TABLE [#CustTbl] ([CustGUID] [UNIQUEIDENTIFIER], [Security] [INT]) 
	CREATE TABLE [#MatTbl2]([MatGUID] [UNIQUEIDENTIFIER], [mtSecurity] INT, [GroupGUID] [UNIQUEIDENTIFIER])
	--Filling temporary tables 
	INSERT INTO [#MatTbl] EXEC [prcGetMatsList] @MatGUID, @GroupGUID, -1, @MatCondGUID 
	INSERT INTO [#BillsTypesTbl] EXEC [prcGetBillsTypesList2] @SrcTypesGUID
	INSERT INTO [#StoreTbl] EXEC [prcGetStoresList] @StoreGUID 
	INSERT INTO [#CostTbl] EXEC [prcGetCostsList] @CostGUID 
	
	DECLARE 
		-- @Admin [INT],
		@UserGuid [UNIQUEIDENTIFIER],
		@cnt [INT],
		@GrpSort [INT]
		
	SET @UserGuid = [dbo].[fnGetCurrentUserGUID]()
	-- SET @Admin = [dbo].[fnIsAdmin](ISNULL(@userGUID, 0x00) )
	
	IF [dbo].[fnIsAdmin](ISNULL(@userGUID, 0x0)) = 0
	BEGIN
		CREATE TABLE [#GR]([Guid] [UNIQUEIDENTIFIER])
		INSERT INTO [#GR] SELECT [Guid]  
		FROM [fnGetGroupsList](@GroupGUID)
		DELETE [r] 
		FROM 
			[#GR] AS [r] 
			INNER JOIN fnGroup_HSecList() AS [f] ON [r].[gUID] = [f].[GUID] 
		WHERE 
			[f].[Security] > [dbo].[fnGetUserGroupSec_Browse](@UserGuid)
		DELETE [m] 
		FROM 
			[#MatTbl] AS [m]
			INNER JOIN [mt000] AS [mt] ON [MatGUID] = [mt].[Guid] 
		WHERE 
			[mtSecurity] > [dbo].[fnGetUserMaterialSec_Browse](@UserGuid) 
			OR 
			[Groupguid] NOT IN (SELECT [Guid] FROM [#Gr])
		SET @cnt = @@ROWCOUNT
		IF @cnt > 0
			INSERT INTO [#SecViol] VALUES(7, @cnt)
	END
	
	IF ISNULL(@CostGUID, 0X00) = 0X00
		INSERT INTO [#CostTbl] VALUES (0X00, 0)
	INSERT INTO 
		[#MatTbl2]
	SELECT 
		[MatGUID],
		[mtSecurity],
		[GroupGUID] 
	FROM 
		[#MatTbl] AS [mt] 
		INNER JOIN [mt000] AS [m] ON   [MatGUID] = [m].[Guid]
	CREATE CLUSTERED INDEX mtInd ON [#MatTbl2]([MatGUID])
	CREATE CLUSTERED INDEX stInd ON [#StoreTbl]([StoreGUID])
		  
	INSERT INTO #CustTbl EXEC [prcGetCustsList]  @CustGuid, @AccGuid, @CustCondGuid
	IF (@AccGuid = 0X00) AND (@CustGuid = 0X00) AND (@CustCondGuid = 0x)
	INSERT INTO #CustTbl VALUES (0X00,0)

	DECLARE @PERIOD TABLE(
		[Period]	[INT], 
		[StartDate] [DATETIME], 
		[EndDate]	[DATETIME]) 
	IF @ViewType <> 3  
	BEGIN
		set language 'arabic'
		INSERT INTO @PERIOD SELECT [Period],[StartDate],[EndDate] FROM [dbo].[fnGetPeriod](@ViewType, @StartDate, @EndDate) 
		set language 'english'
	END
	ELSE
		INSERT INTO @PERIOD 
			SELECT ROW_NUMBER() OVER (ORDER BY [StartDate], [EndDate]) AS [Period] , [StartDate], [EndDate] 
			FROM [dbo].[fnGetStrToPeriod] (@STR)

	CREATE TABLE [#Result]( 
		[Period]				[INT], 
		[biStorePtr]			[UNIQUEIDENTIFIER], 
		[biMatPtr]				[UNIQUEIDENTIFIER], 
		[mtName]				[NVARCHAR](256) COLLATE ARABIC_CI_AI, 
		[mtCode]				[NVARCHAR](256) COLLATE ARABIC_CI_AI,  
		[mtLatinName]			[NVARCHAR](256) COLLATE ARABIC_CI_AI,
		[mtCompositionName]		[NVARCHAR](500) COLLATE ARABIC_CI_AI,
		[mtCompositionLatinName][NVARCHAR](500) COLLATE ARABIC_CI_AI,	 
		[mtDefUnitName]			[NVARCHAR](256) COLLATE ARABIC_CI_AI, 
		[mtDefUnitFact]			[FLOAT],	  
		[buPayType] 			[INT], 
		[biQty]					[FLOAT], 
		[biBonusQnt]			[FLOAT], 
		[FixedBiTotal]			[FLOAT], 
		[FixedBiTotalDisc]		[FLOAT], 
		[FixedBiTotalExtra]		[FLOAT], 
		[FixedBiTotalVat]		[FLOAT], 
		[MtUnitFact]			[FLOAT], 
		[mtUnit2Fact]			[FLOAT],  
		[mtUnit3Fact]			[FLOAT],
		[mtUnity]				[NVARCHAR](256) COLLATE ARABIC_CI_AI, 
		[mtUnit2]				[NVARCHAR](256) COLLATE ARABIC_CI_AI, 
		[mtUnit3]				[NVARCHAR](256) COLLATE ARABIC_CI_AI, 
		[Security]				[INT], 
		[UserSecurity] 			[INT], 
		[UserReadPriceSecurity]	[INT], 
		[MtSecurity]			[INT],
		[StartDate]				[DATETIME],
		[EndDate]				[DATETIME],
		[GroupPtr]				[UNIQUEIDENTIFIER],
		[Path]					[NVARCHAR](1000),
		[isGrp]					[BIT],		
		[grLevel]				[INT],
		[UnitFact]				[FLOAT],
		[BiCostPtr]				UNIQUEIDENTIFIER,
		[FirstPurchase]			[SMALLDATETIME],
		[LastSale]				[SMALLDATETIME],
		[Balance]				[FLOAT],
		[btDirection]			[INT])
	
	CREATE CLUSTERED INDEX [CUInd] ON [#CustTbl] ([CustGUID])

	;WITH Bills AS
	(
		SELECT 
			[biStorePtr], 
			[BiMatPtr], 
			[MtName], 
			[MtCode], 
			[MtLatinName], 
			[mtCompositionName],
			[mtCompositionLatinName],
			[MtDefUnitName],
			[MtDefUnitFact],
			[buIsCash],
			[btDirection],
			[FixedCurrencyFactor],
			[biVat],
			[MtUnitFact], 
			[mtUnit2Fact], 
			[mtUnit3Fact], 
			[mtUnity],
			[mtUnit2], 
			[mtUnit3], 
			[buSecurity], 
			[buIsPosted],
			fn.[MtSecurity],
			[BiCostPtr],
			[BuCustPtr],
			[buCustAcc],
			[buDate],
			[buType],
			btBillType,
			[bt].[UserSecurity],
			[bt].[UnPostedSecurity],
			[bt].[UserReadPriceSecurity], 
			[GroupGUID],
			CASE @UseUnit
				WHEN 1 THEN CASE [mtUnit2Fact]	WHEN 0 THEN [biQty] ELSE [biQty]/[mtUnit2Fact] END 
				WHEN 2 THEN CASE [mtUnit3Fact]	WHEN 0 THEN [biQty] ELSE [biQty]/[mtUnit3Fact] END
				WHEN 3 THEN CASE [mtDefUnitFact] WHEN 0 THEN [biQty] ELSE [biQty]/[mtDefUnitFact] END
				WHEN 0 THEN [biQty] 
			END AS [biQty],
			CASE @UseUnit 
				WHEN 0 THEN [biUnitPrice]
				WHEN 1 THEN CASE [mtUnit2Fact] WHEN 0 THEN [biPrice] ELSE [biUnitPrice] * [mtUnit2Fact] END
				WHEN 2 THEN CASE [mtUnit3Fact] WHEN 0 THEN [biPrice] ELSE [biUnitPrice] * [mtUnit3Fact] END
				WHEN 3 THEN CASE [mtDefUnitFact] WHEN 0 THEN [biPrice] ELSE [biUnitPrice] * [mtDefUnitFact] END
			END AS [biUnitPrice],
			CASE @UseUnit	
				WHEN 1 THEN CASE [mtUnit2Fact]	WHEN 0 THEN [biBonusQnt] ELSE [biBonusQnt]/[mtUnit2Fact] END 
				WHEN 2 THEN CASE [mtUnit3Fact]	WHEN 0 THEN [biBonusQnt] ELSE [biBonusQnt]/[mtUnit3Fact] END
				WHEN 3 THEN CASE [mtDefUnitFact] WHEN 0 THEN [biBonusQnt] ELSE [biBonusQnt]/[mtDefUnitFact] END
				WHEN 0 THEN [biBonusQnt] 
			END AS [biBonusQnt],
			CASE @UseUnit 
				WHEN 0 THEN [biUnitDiscount]
				WHEN 1 THEN CASE [mtUnit2Fact] WHEN 0 THEN [biDiscount] ELSE [biUnitDiscount] * [mtUnit2Fact] END
				WHEN 2 THEN CASE [mtUnit3Fact] WHEN 0 THEN [biDiscount] ELSE [biUnitDiscount] * [mtUnit3Fact] END
				WHEN 3 THEN CASE [mtDefUnitFact] WHEN 0 THEN [biDiscount] ELSE [biUnitDiscount] * [mtDefUnitFact] END
			END AS [biUnitDiscount],
			CASE @UseUnit 
				WHEN 0 THEN [biUnitExtra]
				WHEN 1 THEN CASE [mtUnit2Fact] WHEN 0 THEN [biExtra] ELSE [biUnitExtra] * [mtUnit2Fact] END
				WHEN 2 THEN CASE [mtUnit3Fact] WHEN 0 THEN [biExtra] ELSE [biUnitExtra] * [mtUnit3Fact] END
				WHEN 3 THEN CASE [mtDefUnitFact] WHEN 0 THEN [biExtra] ELSE [biUnitExtra] * [mtDefUnitFact] END
			END	 AS [biUnitExtra]
		FROM 
			[dbo].[fnExtended_bi_Fixed](@CurrencyGUID) AS fn
			INNER JOIN [#BillsTypesTbl] AS [bt] ON fn.[buType] = [bt].[TypeGuid]
			INNER JOIN [#MatTbl2] AS [mtTbl] ON [biMatPtr] = [mtTbl].[MatGuid] 
			INNER JOIN [#CostTbl] AS [co] ON [BiCostPtr] = [CostGUID]
			INNER JOIN [#StoreTbl] AS [st] ON [BiStorePtr] = [StoreGUID]
			INNER JOIN [#CustTbl] AS [cu] ON [BuCustPtr] = [CustGUID]
		WHERE
			([Budate] BETWEEN @StartDate AND @EndDate)
			AND (@MatGUID = 0X00 OR @MatGUID = [BiMatPtr])
	)
	INSERT INTO [#Result]  
	SELECT 
		[rv].[Period], 
		[rv].[biStorePtr], 
		[rv].[BiMatPtr], 
		[rv].[MtName], 
		[rv].[MtCode], 
		[rv].[MtLatinName],
		[rv].[mtCompositionName],
		[rv].[mtCompositionLatinName], 
		[rv].[MtDefUnitName],
		[rv].[MtDefUnitFact],
		[buPayType], 
		[rv].[biQty],
		[rv].[BiBonusQnt], 
		[rv].[FixedBiTotal] , 
		[rv].[FixedBiTotalDisc],	
		[rv].[FixedBiTotalExtra],	
		[rv].[FixedBiTotalVat],	
		[rv].[MtUnitFact], 
		[rv].[mtUnit2Fact], 
		[rv].[mtUnit3Fact], 
		[rv].[mtUnity],
		[rv].[mtUnit2], 
		[rv].[mtUnit3], 
		[rv].[buSecurity], 
		[rv].[UserSecurity], 
		[rv].[UserReadPriceSecurity], 
		[rv].[MtSecurity],
		[rv].[StartDate],
		[rv].[EndDate],
		[GroupGUID],
		'',0,0,
		CASE  @UseUnit 
			WHEN 0 THEN 1 
			WHEN 1 THEN CASE [rv].[mtUnit2Fact]	WHEN 0 THEN 1 ELSE [mtUnit2Fact] END 
			WHEN 2 THEN CASE [mtUnit3Fact]	WHEN 0 THEN 1 ELSE [mtUnit3Fact] END
			ELSE [mtDefUnitFact] 
		END,
		[BiCostPtr],
		FP,
		LS,
		BAL,
		[btDirection]
	FROM 
		(
		SELECT 
				[p].[Period], 
				[rv].[biStorePtr], 
				[rv].[BiMatPtr], 
				[rv].[MtName], 
				[rv].[MtCode], 
				[rv].[MtLatinName], 
				[rv].[mtCompositionName],
				[rv].[mtCompositionLatinName],
				[rv].[MtDefUnitName],
				[rv].[MtDefUnitFact],
				[GroupGUID],
				---cause checks must be credit pay 
				[buIsCash] AS [buPayType],
				SUM(([rv].[biQty] + [rv].[BiBonusQnt])  * CASE @InOutSign WHEN 0 THEN 1  WHEN 1 THEN [rv].[btDirection] ELSE -1 * [rv].[btDirection] END) AS BAL,
				SUM(CASE @InOutSign WHEN 0 THEN 1  WHEN 1 THEN [rv].[btDirection] ELSE -1 * [rv].[btDirection] END * [rv].[biQty]) AS [biQty],
				SUM(CASE @InOutSign WHEN 0 THEN 1  WHEN 1 THEN [rv].[btDirection] ELSE -1 * [rv].[btDirection] END  * [rv].[BiBonusQnt]) AS [BiBonusQnt] , 
				SUM(CASE WHEN [UserReadPriceSecurity] >= [BuSecurity] THEN CASE @InOutSign WHEN 0 THEN 1  WHEN 1 THEN [rv].[btDirection] ELSE -1 * [rv].[btDirection] END * [biUnitPrice] * [biQty] * [FixedCurrencyFactor] ELSE 0 END) AS [FixedBiTotal],
				SUM(CASE WHEN [UserReadPriceSecurity] >= [BuSecurity] THEN CASE @InOutSign WHEN 0 THEN 1  WHEN 1 THEN [rv].[btDirection] ELSE -1 * [rv].[btDirection] END * [biUnitDiscount] * [biQty] * [FixedCurrencyFactor] ELSE 0 END) AS [FixedBiTotalDisc],  
				SUM(CASE WHEN [UserReadPriceSecurity] >= [BuSecurity] THEN CASE @InOutSign WHEN 0 THEN 1  WHEN 1 THEN [rv].[btDirection] ELSE -1 * [rv].[btDirection] END * [biUnitExtra] * [biQty] * [FixedCurrencyFactor] ELSE 0 END) AS [FixedBiTotalExtra], 
				SUM(CASE WHEN [UserReadPriceSecurity] >= [BuSecurity] THEN CASE @InOutSign WHEN 0 THEN 1  WHEN 1 THEN [rv].[btDirection] ELSE -1 * [rv].[btDirection] END * [biVat] * [FixedCurrencyFactor] ELSE 0 END) AS [FixedBiTotalVat],   
				[rv].[MtUnitFact], 
				[rv].[mtUnit2Fact], 
				[rv].[mtUnit3Fact], 
				[rv].[mtUnity],
				[rv].[mtUnit2], 
				[rv].[mtUnit3], 
				[rv].[buSecurity], 
				CASE [rv].[buIsPosted] WHEN 1 THEN [UserSecurity] ELSE [UnPostedSecurity] END AS [UserSecurity],
				[UserReadPriceSecurity], 
				[rv].[MtSecurity],
				[p].[StartDate],
				[p].[EndDate],
				[rv].[BiCostPtr],
				[BuCustPtr],
				[buCustAcc],
				MIN(CASE [rv].btBillType WHEN 0 THEN [rv].[budate] ELSE '1/1/1980' END) FP,
				MAX(CASE [rv].btBillType WHEN 1 THEN [rv].[budate] ELSE '1/1/1980' END) LS,
				[rv].[btDirection] [btDirection]
			FROM 
				Bills AS [rv] 
				INNER JOIN @PERIOD AS [p] ON [rv].[buDate] BETWEEN [p].[StartDate] AND [p].[EndDate]
			GROUP BY 
				[p].[Period], 
				[rv].[biStorePtr], 
				[rv].[BiMatPtr], 
				[rv].[MtName], 
				[rv].[MtCode], 
				[rv].[MtLatinName],
				[rv].[mtCompositionName],
				[rv].[mtCompositionLatinName], 
				[rv].[MtDefUnitName],
				[rv].[MtDefUnitFact],
				[buIsCash],
				[rv].[MtUnitFact], 
				[rv].[mtUnit2Fact], 
				[rv].[mtUnit3Fact], 
				[rv].[mtUnity],
				[rv].[mtUnit2], 
				[rv].[mtUnit3], 
				[GroupGUID],
				[rv].[buSecurity], 
				[rv].[buIsPosted],
				[UserSecurity],
				[UnPostedSecurity],
				[UserReadPriceSecurity], 
				[rv].[MtSecurity],
				[p].[StartDate],
				[p].[EndDate],
				[rv].[BiCostPtr],
				[BuCustPtr],
				[buCustAcc],
				[rv].[BuDate],
				[rv].[btBillType],
				[rv].[btDirection]
		) AS [rv] 
		
	----check sec 
	EXEC [prcCheckSecurity] 
	
	IF (@Collect1 > 0)
	BEGIN
		SET @Col1 = dbo.fnGetMatCollectedFieldName(@Collect1,'')
		SET @Col2 = dbo.fnGetMatCollectedFieldName(@Collect2,'')
		SET @Col3 = dbo.fnGetMatCollectedFieldName(@Collect3,'')	
		SET @S =  'UPDATE [r] SET [MtUnitFact] = 0,[mtUnit2Fact] = 0,[mtUnit3Fact] = 0 , [mtUnity] = '''',[mtUnit2] = '''',[mtUnit3]= '''' FROM [#Result] [r] INNER JOIN [mt000] [mt] ON [mt].[Guid] = [biMatPtr] ' 
		+  dbo.fnGetInnerJoinGroup(CASE WHEN @Collect1 = 11 OR @Collect2 = 11 OR @Collect3 = 11 THEN 1 ELSE 0 END ,'GroupGuid') + ' WHERE  ' +  @Col1 + ' = '''' '
		IF @Collect2 <> 0
			SET @S = @S + ' AND ' + @col2 + '= '''''
		IF @Collect3 <> 0
			SET @S = @S  + ' AND ' + @col3 + '= '''''
		EXEC(@S)
	END
	--- return result set 
	
	IF (@ShowGrp > 0)
	BEGIN
		CREATE TABLE [#GRP] (
		[Guid] UNIQUEIDENTIFIER, 
		[Level] INT,
		[Path] VARCHAR(8000),
		[Name] NVARCHAR(256),
		[Code] NVARCHAR(256),
		[LatinName] NVARCHAR(256),
		[ParentGUID] UNIQUEIDENTIFIER) 
		SET @GrpSort = 1
		
		INSERT INTO 
			[#GRP]
		SELECT 
			[f].[Guid], 
			[Level],
			[Path],
			[Name],
			[Code],
			[LatinName],
			[ParentGUID] 
		FROM 
			[dbo].[fnGetGroupsOfGroupSorted](@GroupGUID, @GrpSort) AS [f] 
			INNER JOIN [gr000] AS [gr] ON [gr].[Guid] = [f].[Guid]
		
		IF (@GrpLevel > 0)
			UPDATE [gr] 
			SET [path] = [gr2].[path] 
			FROM 
				[#GRP] AS [GR] 
				INNER JOIN (SELECT [path] FROM [#GRP] WHERE [Level] = (@GrpLevel - 1) ) AS [gr2] ON [gr].[path] LIKE [gr2].[path] + '%'  WHERE [Level] > (@GrpLevel - 1)
		UPDATE [r] 
		SET [grLevel] = [Level],[Path] = [gr].[Path] 
		FROM 
			[#RESULT] AS [r]
			INNER JOIN [#GRP] AS [gr] ON [R].[GroupPtr] = [gr].[Guid]
		
		INSERT INTO [#RESULT](
			[Period],
			[biStorePtr],
			[biMatPtr],
			[mtName],
			[mtCode],
			[mtLatinName],
			[mtCompositionName],		
			[mtCompositionLatinName],
			[buPayType],
			[biQty],
			[biBonusQnt],
			[FixedBiTotal],
			[FixedBiTotalDisc],
			[FixedBiTotalExtra],
			[FixedBiTotalVat],
			[StartDate],
			[EndDate],
			[GroupPtr],
			[Path],
			[isGrp],
			[grLevel],
			[mtDefUnitFact],
			[mtUnit2Fact],
			[mtUnit3Fact],
			[Balance],
			[BiCostPtr]
			)
		SELECT 
			[Period],
			[biStorePtr],
			[gr].[Guid],
			[gr].[Name],
			[gr].[Code],
			[gr].[LatinName],
			[mtCompositionName],		
			[mtCompositionLatinName],
			[buPayType],
			SUM([biQty]),
			SUM([biBonusQnt]),
			SUM([FixedBiTotal]),
			SUM([FixedBiTotalDisc]),
			SUM([FixedBiTotalExtra]),
			SUM([FixedBiTotalVat]),
			[StartDate],
			[EndDate],
			[gr].[ParentGUID],
			[gr].[Path],
			1,
			[gr].[Level],
			r.mtDefUnitFact,
			r.mtUnit2Fact,
			r.mtUnit3Fact,
			(SUM([biQty] + [BiBonusQnt]) * (CASE @InOutSign WHEN 0 THEN 1  WHEN 1 THEN [r].[btDirection] ELSE -1 * [r].[btDirection] END)) AS BAL,
			[BiCostPtr]
		FROM 
			[#RESULT] AS [r]
			INNER JOIN [#GRP] AS [gr] ON [R].[GroupPtr] = [gr].[Guid]
		GROUP BY
			[Period], [biStorePtr], [BiCostPtr], [gr].[Guid], [gr].[Name], [gr].[Code], [gr].[LatinName],[mtCompositionName],		
			[mtCompositionLatinName],[buPayType], [StartDate], [EndDate], [gr].[ParentGUID], [gr].[Path], [gr].[Level],
			r.mtDefUnitFact,
			r.mtUnit2Fact,
			r.mtUnit3Fact,
			[r].[btDirection]

		SELECT @Cnt = MAX([LEVEL]) FROM [#GRP]
		WHILE @Cnt > 0
		BEGIN
			INSERT INTO [#RESULT](
				[Period],
				[biStorePtr],
				[biMatPtr],
				[mtName],
				[mtCode],
				[mtLatinName],
				[mtCompositionName],		
				[mtCompositionLatinName],
				[buPayType],
				[biQty],
				[biBonusQnt],
				[FixedBiTotal],
				[FixedBiTotalDisc],
				[FixedBiTotalExtra],
				[FixedBiTotalVat],
				[StartDate],
				[EndDate],
				[GroupPtr],
				[Path],
				[isGrp],
				[grLevel],
				[mtDefUnitFact],
				[mtUnit2Fact],
				[mtUnit3Fact],
				[BiCostPtr])
			SELECT
				[Period],
				[biStorePtr],
				[gr].[Guid],
				[gr].[Name],
				[gr].[Code],
				[gr].[LatinName],
				[mtCompositionName],		
				[mtCompositionLatinName],
				[buPayType],
				SUM([biQty]),
				SUM([biBonusQnt]),
				SUM([FixedBiTotal]),
				SUM([FixedBiTotalDisc]),
				SUM([FixedBiTotalExtra]),
				SUM([FixedBiTotalVat]),
				[StartDate],
				[EndDate],
				[gr].[ParentGUID],
				[gr].[Path],
				1,
				[gr].[Level],
				r.mtDefUnitFact,
				r.mtUnit2Fact,
				r.mtUnit3Fact,
				[BiCostPtr]
			FROM 
				[#RESULT] AS [r]
				INNER JOIN [#GRP] AS [gr] ON [R].[GroupPtr] = [gr].[Guid]
			WHERE 
				[r].[grLevel] = @cnt AND [isgrp] = 1
			GROUP BY
				[Period],
				[biStorePtr],
				[BiCostPtr],
				[gr].[Guid],
				[gr].[Name],
				[gr].[Code],
				[gr].[LatinName],
				[mtCompositionName],		
				[mtCompositionLatinName],
				[buPayType],
				[StartDate], 
				[EndDate],
				[gr].[ParentGUID],
				[gr].[Path],
				[gr].[Level],
				r.mtDefUnitFact,
				r.mtUnit2Fact,
				r.mtUnit3Fact
			
			SET @Cnt = @Cnt - 1
		END
	
	IF (@ShowFlag & 0x001 > 0)
		UPDATE #Result 
		SET 
			FirstPurchase = (SELECT MIN(R.FirstPurchase) FROM #Result R WHERE R.BiMatPtr = BiMatPtr AND R.FirstPurchase != '1/1/1980')
	
	IF (@ShowFlag & 0x002 > 0)
		UPDATE #Result 
		SET LastSale = (SELECT MAX(R.LastSale) FROM #Result R WHERE R.BiMatPtr = BiMatPtr)

	------- Delete groups and update parents--------------------------------------------------
	IF (@GrpLevel > 0)
	Begin
		CREATE TABLE #groupsList([Guid] [UNIQUEIDENTIFIER], ParentGuid [UNIQUEIDENTIFIER], Sec INT, Lev INT) 
		INSERT INTO #groupsList EXEC prcGetGroupParnetList 0x0, @GrpLevel
		DECLARE @ChildGuid  [UNIQUEIDENTIFIER]
		DECLARE @ParentGUID [UNIQUEIDENTIFIER]
	
		WHILE (SELECT Count(*) FROM #groupsList) > 0
		BEGIN
			SELECT TOP 1 @ChildGuid = [Guid], @ParentGUID = ParentGuid FROM #groupsList		
			UPDATE [#Result]
			SET [GroupPtr] = @ParentGUID
			WHERE [GroupPtr] = @ChildGuid
			DELETE #groupsList WHERE [Guid] = @ChildGuid
		END
		DELETE [#RESULT] WHERE [IsGrp] = 1 AND [grLevel] > (@GrpLevel - 1)
	END
	----------------------------------------------------------------------------------------
	UPDATE #Result SET mtUnit2Fact = NULL, mtUnit3Fact = NULL,mtDefUnitFact = NULL WHERE IsGrp = 1
	END
	IF @ShowMt = 0 
		DELETE [#RESULT] WHERE [IsGrp] = 0

	IF ( @Axe = 0 AND @ShowGrp = 1)
	BEGIN

		UPDATE [#Result]
			SET [biStorePtr] = 0x00,
				[BiCostPtr] = 0x00
		WHERE [isGrp] = 1
	END
	-----------------------------------------------------------------------------------------------------
	--------------------------------------- 1st Result --------------------------------------------------	
	
	SET @s = 'SELECT	ISNULL(Min(FirstPurchase), ''1/1/1980'' ) AS FirstPurchase, 
						ISNULL(Max(LastSale), ''1/1/1980'' ) AS LastSale,'
	
	SET @S = @S + ' ISNULL(SUM([rv].[biQty] + [rv].[BiBonusQnt]), 0.0)  AS Balance, '
	
	IF (@Collect1 = 0)
		SET @s = @s + '
			ISNULL([rv].[BiMatPtr], 0x00), 
			ISNULL([rv].[MtName], ''''), 
			ISNULL([rv].[MtCode], ''''), 
			ISNULL([rv].[MtLatinName], ''''),
			ISNULL([rv].[mtCompositionName], ''''),
			ISNULL([rv].[mtCompositionLatinName], ''''),
			'''' AS [Col1],
			'''' AS [Col2],
			'''' AS [Col3],'
	ELSE
	BEGIN
		SET @S = @S + '0x00 AS [BiMatPtr], '''' AS [MtName], '''' AS [MtCode], '''' AS [MtLatinName],'''' AS [mtCompositionName],'''' AS [mtCompositionLatinName],'
		SET @s = @s + CASE WHEN @Collect1 = 11 THEN ' '' '' ' ELSE  '[mt].' END + @col1 + ' [Col1],'		
		SET @s = @s + CASE @Collect2 WHEN 0 THEN ' '' '' ' WHEN 11 THEN ' '' '' ' ELSE  '[mt].' END + @col2 + ' [Col2],'
		SET @s = @s  + CASE @Collect3 WHEN 0 THEN ' '' '' ' WHEN 11 THEN ' '' '' ' ELSE  '[mt].' END + @col3 + ' [Col3],'
	END

	IF (@Collect1 = 0)
	BEGIN
		IF @UseUnit = 1
			SET @S = @S + 'CASE [rv].[mtUnit2Fact] WHEN 0 THEN ISNULL([rv].[mtUnity], '''') ELSE ISNULL([rv].[mtUnit2], '''') END '
		ELSE IF @UseUnit = 2
			SET @S = @S + 'CASE [rv].[mtUnit3Fact] WHEN 0 THEN ISNULL([rv].[mtUnity], '''') ELSE ISNULL([rv].[mtUnit3], '''') END '	
		ELSE IF @UseUnit = 3
			SET @S = @S + 'ISNULL([rv].[mtDefUnitName], '''') '	
		ELSE IF @UseUnit = 0
			SET @S = @S + 'ISNULL([rv].[mtUnity], '''') '	
		
		SET @S = @S + 'AS [mtUnitName] ,'
	
		IF @UseUnit = 1
			SET @S = @S + 'ISNULL([rv].[mtUnit2Fact], 1) '
		ELSE IF @UseUnit = 2
			SET @S = @S + 'ISNULL([rv].[mtUnit3Fact], 1) '	
		ELSE IF @UseUnit = 3
			SET @S = @S + 'ISNULL([rv].[mtDefUnitFact], 1) '	
		ELSE IF @UseUnit = 0
			SET @S = @S + '1 '	

		SET @S = @S + 'AS [mtUnitFact] ,'
	END
	ELSE
	BEGIN
		SET @S = @S + ' '''' AS [mtUnitName], 1 AS [mtUnitFact], '
	END

	----- Detailed by Cost Center ---------------------------------------------------------------------------------
	IF (@DetLag & 0X00001) > 0
		SET @S = @S + '	ISNULL([co].[Code], '''') AS [coCode], ISNULL([co].[Name], '''') AS [coName],
						ISNULL([co].[LatinName], '''') AS [coLatinName], ISNULL([co].[Guid],0X00) AS [coGuid],'
	ELSE
		SET @S = @S + ''''' AS [coCode], '''' AS [coName], '''' AS [coLatinName], 0x00 AS [coGuid],'
	---------------------------------------------------------------------------------------------------------------
	
	----- Detailed by Store ---------------------------------------------------------------------------------------
	IF (@DetLag & 0X00002) > 0
		SET @S = @S + '	ISNULL([st].[Code], '''') AS [stCode], ISNULL([st].[Name], '''') AS [stName], 
						ISNULL([st].[LatinName], '''') AS [stLatinName], ISNULL([st].[Guid],0X00) AS [stGuid],'
	ELSE
		SET @S = @S + ''''' AS [stCode], '''' AS [stName], '''' AS [stLatinName], 0x00 AS [stGuid],'
	---------------------------------------------------------------------------------------------------------------

	SET @S = @S + 'ISNULL(SUM([rv].[biQty]), 0.0) AS [SumQty], ISNULL(SUM([rv].[BiBonusQnt]), 0.0) AS [SumBonusQty],'
	
	----------------- Show Groups ---------------------------------------------------------------------
	IF (@ShowGrp >0)
			SET @S = @S + 'ISNULL([IsGrp], 0), ISNULL([GroupPtr], 0x00),'
	ELSE
		SET @S = @S + '0 AS [IsGrp], 0x00 AS [GroupPtr],'
	--------------------------------------------------------------------------------------------------

	SET @S = @S + '	ISNULL(SUM([FixedBiTotal]), 0.0) AS [SumPrice], 
					ISNULL(SUM([FixedBiTotalDisc]), 0.0) AS [SumPriceDisc],
					ISNULL(SUM([FixedBiTotalExtra]), 0.0) AS [SumPriceExtra],
					ISNULL(SUM( [FixedBiTotalVat]), 0.0) AS [SumPriceVat],
					ISNULL([StartDate], ''1/1/1980'') AS [PeriodStartDate],
					ISNULL([EndDate], ''1/1/1980'') AS [PeriodEndDate]'

	IF (@ShowGrp >0) and (@ShowMt =0)
		SET @S = @S +', ISNULL([rv].grLevel, 0) '
	ELSE
		SET @S = @S + ', 0 AS grLevel '	

	SET @S = @S +' , ISNULL([Period], 0)'
	
	IF (@ShowGrp >0)
		SET @S = @S + ' , ISNULL([Path], '''')'
	ELSE
		SET @S = @S + ' , '''' '

	SET @S = @S + ' FROM [#Result] AS [rv] '

	IF (@Collect1 <> 0)
		SET @S = @S +' INNER JOIN [mt000] [mt] ON [mt].[Guid] = [rv].[BiMatPtr] '
	
	SET @S = @S +  dbo.fnGetInnerJoinGroup(CASE WHEN @Collect1 = 11 OR @Collect2 = 11 OR @Collect3 = 11 THEN 1 ELSE 0 END ,'GroupGuid') 
	
	IF (@DetLag & 0X00001) > 0
		SET @S = @S + CHAR(13) + 'LEFT JOIN [CO000] Co ON [BiCostPtr] = [co].[Guid] '
	IF (@DetLag & 0X00002) > 0
		SET @S = @S + CHAR(13) + 'LEFT JOIN [st000] st ON [BiStorePtr] = [st].[Guid] '
	
	------------------------------ Group by ------------------------------------------------------------------
	SET @S = @S +' GROUP BY '
	IF (@Collect1 = 0)
		SET @S = @S + '[BiMatPtr], [MtName], [MtCode], [MtLatinName],[mtCompositionName],[mtCompositionLatinName],' 
	ELSE
	BEGIN
		SET @S = @S + CASE WHEN @Collect1 = 11 THEN '' ELSE  '[mt].' END +  @col1 + ','
		IF @Collect2 > 0
			SET @S = @S  + CASE WHEN @Collect2 = 11 THEN '' ELSE  '[mt].' END +  @col2 + ','
		IF @Collect3 > 0
			SET @S = @S  + CASE WHEN @Collect3 = 11 THEN '' ELSE  '[mt].' END +  @col3 + ','
	END
	
	SET @S = @S + '[StartDate],[EndDate], [Period]'

	IF (@DetLag & 0X00001) > 0
		SET @S = @S + CHAR(13) + ',[co].[Code],[co].[Name] ,co.LatinName , co.Guid'
	
	IF (@DetLag & 0X00002) > 0
		SET @S = @S + CHAR(13) + ',[st].[Code] ,[st].[Name],st.LatinName, st.Guid '
	
	IF (@ShowGrp >0)
	BEGIN
		SET @S = @S + ',[IsGrp] ,[Path], [GroupPtr] '
	END
	
	----- UNIT ---------------------------------------------
	IF( @Collect1 = 0)
	BEGIN
		IF @UseUnit = 1
			SET @S = @S + ',[mtUnit2], [mtUnity] '
		ELSE IF @UseUnit = 2
			SET @S = @S + ',[mtUnit3], [mtUnity] '
		ELSE IF @UseUnit = 3
			SET @S = @S + ',[mtDefUnitName] '
		ELSE IF @UseUnit = 0
			SET @S = @S + ',[mtUnity] '
		IF @UseUnit = 1
			SET @S = @S + ',[MtUnit2Fact] '
		ELSE IF @UseUnit = 2
			SET @S = @S + ',[MtUnit3Fact] '
		ELSE IF @UseUnit = 3
			SET @S = @S + ',[mtDefUnitFact] '
	END
	------------------------------------------------------

	IF (@ShowGrp >0) and (@ShowMt =0)  
		SET @S = @S  +',[rv].grLevel '
	-----------------------------------------------------------------------------------------------------------
	-------------------------------- ORDER --------------------------------------------------------------------
	SET @S = @S + ' ORDER BY [StartDate]'
	
	IF (@ShowGrp >0)
		SET @s =@s + ' ,[Path], [IsGrp] DESC, [BiMatPtr]'
	ELSE
	BEGIN
		IF (@Collect1 = 0)
		BEGIN
			SET @s =@s + ' , [MtCode], [BiMatPtr]'
		END
		ELSE
		BEGIN
			SET @S = @S + ' , '  + CASE WHEN @Collect1 = 11 THEN '' ELSE  '[mt].' END +  @col1 
			IF @Collect2 > 0
				SET @S = @S +  ','  + CASE WHEN @Collect2 = 11 THEN '' ELSE  '[mt].' END +  @col2
			IF @Collect3 > 0
				SET @S = @S + ','  + CASE WHEN @Collect3 = 11 THEN '' ELSE  '[mt].' END +  @col3
		END
	END
	IF (@DetLag & 0X00001) > 0
		SET @S = @S + CHAR(13) + ', [co].[Code], [co].[Guid]'
	IF (@DetLag & 0X00002) > 0
		SET @S = @S + CHAR(13) + ', [st].[Code], [st].[Guid]'
	----------------------------------------------------------------------------------------------------------
	
	
	CREATE TABLE [#FinalResult]( 
		[FirstPurchase]			[SMALLDATETIME],
		[LastSale]				[SMALLDATETIME],
		[Balance]				[FLOAT],
		[biMatPtr]				[UNIQUEIDENTIFIER], 
		[mtName]				[NVARCHAR](256) COLLATE ARABIC_CI_AI, 
		[mtCode]				[NVARCHAR](256) COLLATE ARABIC_CI_AI,  
		[mtLatinName]			[NVARCHAR](256) COLLATE ARABIC_CI_AI,
		[mtCompositionName]		[NVARCHAR](500) COLLATE ARABIC_CI_AI,
		[mtCompositionLatinName][NVARCHAR](500) COLLATE ARABIC_CI_AI,	 
		[Col1]					[NVARCHAR](100),
		[Col2]					[NVARCHAR](100),
		[Col3]					[NVARCHAR](100),		
		[mtUnitName]			[NVARCHAR](256) COLLATE ARABIC_CI_AI,
		[mtUnitFact]			[FLOAT],	
		[coCode]				[NVARCHAR](256) COLLATE ARABIC_CI_AI,
		[coName]				[NVARCHAR](256) COLLATE ARABIC_CI_AI,
		[coLatinName]			[NVARCHAR](256) COLLATE ARABIC_CI_AI,
		[coGuid]				[UNIQUEIDENTIFIER],		
		[stCode]				[NVARCHAR](256) COLLATE ARABIC_CI_AI,
		[stName]				[NVARCHAR](256) COLLATE ARABIC_CI_AI,
		[stLatinName]			[NVARCHAR](256) COLLATE ARABIC_CI_AI,
		[stGuid]				[UNIQUEIDENTIFIER],		
		[SumQty]				[FLOAT],
		[SumBonusQty]			[FLOAT],
		[isGrp]					[BIT],
		[GroupPtr]				[UNIQUEIDENTIFIER],
		[SumPrice]				[FLOAT],
		[SumPriceDisc]			[FLOAT],
		[SumPriceExtra]			[FLOAT],
		[SumPriceVat]			[FLOAT],
		[PeriodStartDate]		[DATETIME],
		[PeriodEndDate]			[DATETIME],
		[grLevel]				[INT],
		[PeriodID]				[INT],
		[grPath]				[NVARCHAR](1000))

	INSERT INTO [#FinalResult] EXECUTE (@s)
	
	UPDATE [#FinalResult]
	SET [FirstPurchase] = ISNULL((SELECT MIN([FirstPurchase]) FROM [#FinalResult] AS FinR
							WHERE R1.biMatPtr = FinR.biMatPtr AND R1.coGuid = FinR.coGuid AND R1.stGuid = FinR.stGuid
							AND FinR.FirstPurchase != '1/1/1980'
							GROUP BY FinR.biMatPtr, FinR.coGuid, FinR.stGuid), '1/1/1980'),
		[LastSale] = ISNULL((SELECT MAX([LastSale]) FROM [#FinalResult] AS FinR
							WHERE R1.biMatPtr = FinR.biMatPtr AND R1.coGuid = FinR.coGuid AND R1.stGuid = FinR.stGuid
							GROUP BY FinR.biMatPtr, FinR.coGuid, FinR.stGuid), '1/1/1980'),
		[Balance] = ISNULL((SELECT SUM([Balance]) FROM [#FinalResult] AS FinR
						WHERE R1.biMatPtr = FinR.biMatPtr AND R1.coGuid = FinR.coGuid AND R1.stGuid = FinR.stGuid
						GROUP BY FinR.biMatPtr, FinR.coGuid, FinR.stGuid), 0.0)
	FROM [#FinalResult] R1
	
	----------------------- Return Materials List ------------------------------------------------------
	CREATE TABLE [#MatResult]( 
		[LineNum]				[INT],
		[biMatPtr]				[UNIQUEIDENTIFIER],	 
		[mtCode]				[NVARCHAR](256) COLLATE ARABIC_CI_AI,  	
		[Col1]					[NVARCHAR](100),
		[Col2]					[NVARCHAR](100),
		[Col3]					[NVARCHAR](100),			
		[coCode]				[NVARCHAR](256) COLLATE ARABIC_CI_AI,
		[coGuid]				[UNIQUEIDENTIFIER],		
		[stCode]				[NVARCHAR](256) COLLATE ARABIC_CI_AI,
		[stGuid]				[UNIQUEIDENTIFIER],			
		[isGrp]					[BIT],
		[grPath]				[NVARCHAR](1000))

	INSERT INTO [#MatResult]
		SELECT DISTINCT Row_number() over(order by [grPath], [IsGrp] DESC, [MtCode], [BiMatPtr], [Col1], [Col2], [Col3], [coCode], [coGuid], [stCode], [stGuid]),
			ISNULL([biMatPtr], 0x00) AS [biMatPtr], 
			ISNULL([MtCode], '') AS [MtCode], 
			ISNULL([Col1], '') AS [Col1], 
			ISNULL([Col2], '') AS [Col2], 
			ISNULL([Col3], '') AS [Col3], 
			ISNULL([coCode], '') AS [coCode], 
			ISNULL([coGuid], 0x00) AS [coGuid], 
			ISNULL([stCode], '') AS [stCode], 
			ISNULL([stGuid], 0x00) AS [stGuid], 
			ISNULL([IsGrp], 0) AS [IsGrp], 
			ISNULL([grPath], '') AS [grPath]
		FROM [#FinalResult]
		GROUP BY [grPath], [IsGrp], [MtCode], [BiMatPtr], [Col1], [Col2], [Col3], [coCode], [coGuid], [stCode], [stGuid]

	----------------- Materials list ---------------------------------------------------------
	SELECT DISTINCT [FirstPurchase], [LastSale], [Balance], [biMatPtr], [mtName], [mtCode], [mtLatinName],[mtCompositionName],[mtCompositionLatinName], [Col1],
		[Col2], [Col3],[mtUnitName], [mtUnitFact], [coCode], [coName], [coLatinName], [coGuid], [stCode], [stName],
		[stLatinName], [stGuid], [isGrp], [GroupPtr], [grLevel], [grPath]
	FROM [#FinalResult]
	ORDER BY [grPath], [IsGrp] DESC, [MtCode], [BiMatPtr], [Col1], [Col2], [Col3], [coCode], [coGuid], [stCode], [stGuid]
	----------------------------------------------------------------------------------------------

	----------- Return PeriodsList -----------------------------------------------------------
	DECLARE @PeriodsList TABLE(
		[PeriodID]			[INT], 
		[PeriodStartDate]	[DATETIME], 
		[PeriodEndDate]		[DATETIME],
		[IsEmpty]			[BIT]) 

	INSERT INTO @PeriodsList
		SELECT ISNULL(Period, 0), ISNULL(StartDate, '1/1/1980'), ISNULL(EndDate, '1/1/1980'), 1 FROM @PERIOD

	UPDATE @PeriodsList 
		SET [IsEmpty] = 0
	FROM @PeriodsList AS P
	INNER JOIN [#FinalResult] AS R ON R.[PeriodID] = P.[PeriodID]
	
	SELECT * FROM @PeriodsList Order by [PeriodID]
	------------------------------------------------------------------------------------------

	IF @Axe = 0
	BEGIN
		
		--------- Ordered Materials with Periods Data List -------------------------------------------------------
		SELECT (R2.[LineNum]-1)  AS LineNum, R1.[biMatPtr], R1.[coGuid], R1.[stGuid], R1.[SumQty], R1.[SumBonusQty], R1.[SumPrice],
				R1.[SumPriceDisc], R1.[SumPriceExtra], R1.[SumPriceVat], R1.[PeriodID]
		FROM [#FinalResult] R1
		INNER JOIN [#MatResult] R2 ON R1.[biMatPtr] = R2.[biMatPtr] AND R1.[coGuid] = R2.[coGuid] AND R1.[stGuid] = R2.[stGuid]
		Order By R2.[LineNum]
		---------------------------------------------------------------------------------------------------------
	END
	ELSE
	BEGIN
		-------------------------- Return Detialed Periods List ------------------------------------------------
		DECLARE @DetailedPeriodsList TABLE(
			[LineNum]			[INT],
			[PeriodID]			[INT], 
			[PeriodStartDate]	[DATETIME], 
			[PeriodEndDate]		[DATETIME],
			[coGuid]			[UNIQUEIDENTIFIER],
			[coCode]			[NVARCHAR](256) COLLATE ARABIC_CI_AI,
			[coName]			[NVARCHAR](256) COLLATE ARABIC_CI_AI,
			[coLatinName]		[NVARCHAR](256) COLLATE ARABIC_CI_AI,
			[stGuid]			[UNIQUEIDENTIFIER],	
			[stName]			[NVARCHAR](256) COLLATE ARABIC_CI_AI,
			[stLatinName]		[NVARCHAR](256) COLLATE ARABIC_CI_AI,
			[stCode]			[NVARCHAR](256) COLLATE ARABIC_CI_AI,
			[IsEmpty]			[BIT]) 
	
		INSERT INTO @DetailedPeriodsList
			SELECT DISTINCT 0, R.[PeriodID], R.[PeriodStartDate], R.[PeriodEndDate], R.[coGuid], R.[coCode], 
				R.[coName], R.[coLatinName], R.[stGuid], R.[stName], R.[stLatinName], R.[stCode], 0
			FROM [#FinalResult] AS R 
			ORDER BY R.[PeriodID], R.[PeriodStartDate], R.[PeriodEndDate], R.[coCode], R.[coGuid], R.[coName], R.[coLatinName],
			 R.[stCode], R.[stName], R.[stLatinName], R.[stGuid]
	
		INSERT INTO @DetailedPeriodsList
			SELECT 0, P.[Period], P.[StartDate],	P.[EndDate], 0x00, '', '', '', 0x00, '', '', '', 1
			FROM @PERIOD AS P
			WHERE P.[Period] NOT IN ( SELECT [PeriodID] FROM [#FinalResult] )

		DECLARE @RowNum INT
		SET @RowNum = -1
		Update R
			SET  @RowNum = [LineNum] = @RowNum +1
		FROM @DetailedPeriodsList R

		--------- Ordered Materials with Periods Data List -------------------------------------------------------
		SELECT DP.[LineNum], R1.[biMatPtr], R1.[coGuid], R1.[stGuid], R1.[SumQty], R1.[SumBonusQty], R1.[SumPrice],
				R1.[SumPriceDisc], R1.[SumPriceExtra], R1.[SumPriceVat], R1.[PeriodID], R2.[IsGrp]
		FROM [#FinalResult] R1
		INNER JOIN [#MatResult] R2 ON R1.[biMatPtr] = R2.[biMatPtr] AND R1.[coGuid] = R2.[coGuid] AND R1.[stGuid] = R2.[stGuid]
		INNER JOIN @DetailedPeriodsList DP ON DP.[PeriodID] = R1.[PeriodID] AND DP.[coGuid] = R1.[coGuid] AND DP.[stGuid] = R1.[stGuid]
		Order By R2.[LineNum]
		------------------------------------------------------------------------------------------------------------

		SELECT * FROM @DetailedPeriodsList

		----------- Columns Count ---------------------------------------------------------------------------------
		SELECT Count(DISTINCT [biMatPtr]) AS ColCount FROM [#MatResult]
		------------------------------------------------------------------------------------------------------------

	END

	SELECT * FROM [#SecViol]

###############################################################################
#END