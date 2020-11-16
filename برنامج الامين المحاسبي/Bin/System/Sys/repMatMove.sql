#######################################################
CREATE PROCEDURE repGetPrevBal
	@StartDate 		[DATETIME],
	@MatGUID 		[UNIQUEIDENTIFIER],
	@GroupGUID 		[UNIQUEIDENTIFIER],
	@StoreGUID  	[UNIQUEIDENTIFIER],
	@CostGUID 		[UNIQUEIDENTIFIER],
	@UseUnit 		[INT], --1 First 2 Seccound 3 Third 
	@SrcTypesguid	[UNIQUEIDENTIFIER],
	@CurrencyGUID 	[UNIQUEIDENTIFIER],
	@Sort			[INT] = 0,--0 CODE 1 NAME 2 LATINNAME
	@PostedValue 	[INT] = 1,
	@Class			[NVARCHAR](256) = '',
	@Collect1		[INT] = 0,
	@Collect2		[INT] = 0,
	@Collect3		[INT] = 0
AS
	DECLARE @Sql NVARCHAR(max)
	DECLARE @Col1 NVARCHAR(100)
	DECLARE @Col2 NVARCHAR(100)
	DECLARE @Col3 NVARCHAR(100)
	CREATE TABLE [#T_RESULT]
	(
		[MatPtr] 			[UNIQUEIDENTIFIER],
		[buDate] 			[DATETIME],
		[buDirection]		[INT] ,
		[biQty] 			[FLOAT] ,
		[biQty2]			[FLOAT] ,
		[biQty3] 			[FLOAT] ,
		[biBounus]		[FLOAT] DEFAULT 0,
		[FixedBiPrice] 		[FLOAT] DEFAULT 0,
		[btSecurity] 		[INT],
		[MatSecurity] 		[INT],
		[Security]		[INT],
		[UNITFACT]		[FLOAT] 
		
	)

	INSERT INTO [#T_RESULT]
		SELECT 
			
			[bi].[biMatPtr],
			[bi].[buDate],
			CASE [bi].[btIsInput] 
				WHEN 1 THEN 1
				ELSE -1
			END,
			CASE @UseUnit 
				WHEN 0 THEN [bi].[biQty]
				WHEN 1 THEN  [bi].[biQty]/CASE [bi].[mtUnit2Fact] WHEN 0 THEN 1 ELSE  [bi].[mtUnit2Fact] END
				WHEN 2 THEN  [bi].[biQty]/CASE [bi].[mtUnit3Fact] WHEN 0 THEN 1 ELSE  [bi].[mtUnit3Fact] END
				ELSE [bi].[biQty] / [bi].[mtDefUnitFact]
			END,
			[bi].[biCalculatedQty2],
			[bi].[biCalculatedQty3],
			CASE @UseUnit 
				WHEN 0 THEN [bi].[biBonusQnt]
				WHEN 1 THEN  [bi].[biBonusQnt]/CASE [bi].[mtUnit2Fact] WHEN 0 THEN 1 ELSE  [bi].[mtUnit2Fact] END
				WHEN 2 THEN  [bi].[biBonusQnt]/CASE [bi].[mtUnit3Fact] WHEN 0 THEN 1 ELSE  [bi].[mtUnit3Fact] END
				ELSE [bi].[biBonusQnt]/ [bi].[mtDefUnitFact]
			END,
			[bi].[FixedbiTotal],
			CASE [bi].[buIsPosted] WHEN 1 THEN [UserSecurity] ELSE [UnPostedSecurity] END,
			[mt].[mtSecurity],
			[bi].[buSecurity],
		CASE @UseUnit 
			WHEN 0 THEN 1
			WHEN 1 THEN [bi].[mtUnit2Fact]
			WHEN 2 THEN [bi].[mtUnit3Fact]
			ELSE  [bi].[mtDefUnitFact]
		END
			
		FROM 
			[fnExtended_bi_Fixed](@CurrencyGUID) AS [bi]
			INNER JOIN [#MatTbl] AS [mt] ON [mt].[MatGUID] = [bi].[biMatPtr]
			INNER JOIN [#BillsTypesTbl] AS [bt] ON bt.TypeGuid = [bi].[buType]
			INNER JOIN [#StoreTbl] AS [st] ON [st].[StoreGUID] = [bi].[biStorePtr]
			INNER JOIN [#CostTbl] AS [co] ON [co].[CostGUID] = [bi].[biCostPtr]	
		WHERE 
			([buDate] < @StartDate )
		    AND (([buIsPosted] = @PostedValue) OR (@PostedValue = -1))
		    AND( @Class = ''			OR @Class = [biClassPtr])
	EXEC [prcCheckSecurity] @RESULT = '#T_RESULT'
	CREATE TABLE [#t_Prices]
	(
		[mtNumber] 	[UNIQUEIDENTIFIER],
		[APrice] 		[FLOAT]
	)
	CREATE TABLE [#t_Prices2]
	(
		[Col1] [NVARCHAR](255)  COLLATE ARABIC_CI_AI, 
		[Col2] [NVARCHAR](255)  COLLATE ARABIC_CI_AI, 
		[Col3] [NVARCHAR](255)  COLLATE ARABIC_CI_AI, 
		[APrice] 		[FLOAT]
	)
	DECLARE @D [DATETIME]
	SET @D = @StartDate - 1
	IF (@Collect1 = 0)
		EXEC [prcGetAvgPrice]	'1/1/1980',@D,@MatGUID,@GroupGUID,@StoreGUID, @CostGUID, -1, @CurrencyGUID, 1, @SrcTypesguid,0, @UseUnit
	ELSE
		INSERT INTo [#t_Prices2] EXEC [prcGetAvgPrice_WithCollect]	'1/1/1980',@D,@MatGUID,@GroupGUID,@StoreGUID, @CostGUID, -1, @CurrencyGUID, 1, @SrcTypesguid,0, @UseUnit,@Collect1,@Collect2,@Collect3
	IF (@Collect1 = 0)
		SELECT 
			[MatPtr],
			[r].[mtName],
			MAX(r.[PQty]) AS [PQty],
			MAX([PQnt2])  AS [PQnt2],
			MAX([PQnt3])  AS [PQnt3],
			ISNULL( [APrice],0) * [UNITFACT]  AS [PAPrice]
		FROM 
			(SELECT 
				[r].[MatPtr] MatPtr, 
				[mt].[mtName],
				SUM(([biQty] + [biBounus])* [buDirection]) AS [PQty],
				SUM([biQty2] * [buDirection])  AS [PQnt2],
				SUM([biQty3] * [buDirection])  AS [PQnt3],
				[r].[UNITFACT] [UNITFACT]
			FROM 	
				[#T_RESULT] AS [r] 
				INNER JOIN [vwmt] AS [mt] ON [mt].[mtGuid] = [r].[MatPtr]
			GROUP BY 
				[r].[MatPtr],
				[mt].[mtName],
				[r].[UNITFACT]) r
			LEFT JOIN [#t_Prices] AS [p] ON  [p].[mtNumber] =  [r].[MatPtr]
		GROUP BY 
			[r].[MatPtr],
			[r].[mtName],
			[r].[UNITFACT],
			[APrice]
	ELSE
	BEGIN
		SET @Col1 = dbo.fnGetMatCollectedFieldName(@Collect1, CASE @Collect1 WHEN 11 THEN 'GR' ELSE 'mt' END)
		SET @Col2 = dbo.fnGetMatCollectedFieldName(@Collect2, CASE @Collect2 WHEN 11 THEN 'GR' ELSE 'mt' END)
		SET @Col3 = dbo.fnGetMatCollectedFieldName(@Collect3, CASE @Collect3 WHEN 11 THEN 'GR' ELSE 'mt' END)
		SET @Sql =  ' UPDATE [r] SET [UNITFACT] = 1  FROM [#T_RESULT] AS [r] '
					+ ' INNER JOIN [vwmt] AS [mt] ON [mt].[mtGuid] = [r].[MatPtr] ' 
					+ dbo.fnGetInnerJoinGroup(CASE WHEN @Collect1 = 11 OR @Collect2 = 11 OR @Collect3 = 11 THEN 1 ELSE 0 END ,'mtGroup') 
					+ 'WHERE ' + @col1 + ' = ''''' 
		IF @Collect2 <> 0
			SET @Sql = @Sql + ' AND ' + @col2 + '= '''''
		IF @Collect3 <> 0
			SET @Sql = @Sql  + ' AND ' + @col3 + '= '''''
		EXEC (@Sql)
		SET @Sql = 'SELECT 	' + @col1 + ' [Col1], '
		IF @Collect2 > 0
			SET @Sql = @Sql + @col2 + ' [Col2],'
		IF @Collect3 > 0
			SET @Sql = @Sql +  @col3 + ' [Col3],'
		SET @Sql = @Sql + 'SUM(([biQty]+[biBounus])* [buDirection]) AS [PQty],
				SUM([biQty2]*[buDirection])  AS [PQnt2],
				SUM([biQty3]*[buDirection])  AS [PQnt3],
				ISNULL( [APrice],0) *  [UNITFACT]  AS [PAPrice]
				FROM [#T_RESULT] AS [r] 
				INNER JOIN [vwmt] AS [mt] ON [mt].[mtGuid] = [r].[MatPtr]  '
				+ dbo.fnGetInnerJoinGroup(CASE WHEN @Collect1 = 11 OR @Collect2 = 11 OR @Collect3 = 11 THEN 1 ELSE 0 END ,'mtGroup') 
				+ ' LEFT JOIN [#t_Prices2] AS [p] ON  [p].[Col1] = ' + CASE WHEN @Collect1 = 11 THEN 'gr.' ELSE 'mt.' END + @Col1 
		IF @Collect2 > 0
			SET @Sql = @Sql + ' AND [p].[Col2] = ' + CASE WHEN @Collect2 = 11 THEN 'gr.' ELSE 'mt.' END + + @Col2
		IF @Collect3 > 0
			SET @Sql = @Sql + ' AND [p].[Col3] = ' + CASE WHEN @Collect3 = 11 THEN 'gr.' ELSE 'mt.' END +  @Col3
		SET @Sql = @Sql +  ' GROUP BY [UNITFACT],[APrice],' +  @col1 
		IF @Collect2 > 0
			SET @Sql = @Sql + ',' +  @col2 
		IF @Collect3 > 0
			SET @Sql = @Sql + ',' +  @col3 
		EXEC (@Sql)

		
	END 
#######################################################
CREATE PROCEDURE repMatMove
	@IsCalledByWeb		[BIT],
	@MatGUID 			[UNIQUEIDENTIFIER],
	@StartDate 			[DATETIME],
	@EndDate 			[DATETIME],
	@CustCondGuid		[UNIQUEIDENTIFIER],
	@StoreGUID 			[UNIQUEIDENTIFIER], -- 0 all stores so don't check store or list of stores
	@CostGUID 			[UNIQUEIDENTIFIER], -- 0 all costs so don't Check cost or list of costs
	@PostedValue 		[INT], -- 1 posted or 0 unposted -1 all posted & unposted
	@NotesContain 		[NVARCHAR](256),-- NULL or Contain Text
	@NotesNotContain 	[NVARCHAR](256), -- NULL or Not Contain
	@SrcTypesguid		[UNIQUEIDENTIFIER],
	@PrevBal			[INT] = 0,
	@UseUnit			[INT] = 0,
	@CurrencyGUID		[UNIQUEIDENTIFIER] = 0X00,
	@RID				[FLOAT] = 0,
	@ShowChecked		[INT] = 0,
	@ItemChecked		[INT] = -1,
	@CheckForUsers		[INT] = 0,
	@Lang				[BIT] = 0,
	@Class				[NVARCHAR](256) = '',
	@SelectedUserGuid	[UNIQUEIDENTIFIER] = 0X00,
	@PriceType			[INT] = 2 ,
	@PricePolicy		[INT] = 121,
	@CurVal				[FLOAT] = 1,
	@IsIncludeOpenedLC	[BIT] = 0,
	@AccSum				[BIT] = 0
AS
	SET NOCOUNT ON

	DECLARE @SortAffectCostType BIT 
	SET @SortAffectCostType = 0
	IF @PostedValue = 1
		SET @SortAffectCostType = 1

	-- Creating temporary tables
	CREATE TABLE [#SecViol]( [Type] [INT], [Cnt] [INTEGER])
	CREATE TABLE [#BillsTypesTbl]( [TypeGuid] [UNIQUEIDENTIFIER], [UserSecurity] [INTEGER], [UserReadPriceSecurity] [INTEGER], 
		[UnPostedSecurity] [INTEGER], [PriorityNum] [INTEGER], [SamePriorityOrder] INT, [SortNumber] INT) 
	CREATE TABLE [#StoreTbl](	[StoreGuid] [UNIQUEIDENTIFIER], [Security] [INT])
	CREATE TABLE [#CostTbl]( [CostGuid] [UNIQUEIDENTIFIER], [Security] [INT],[Name] [NVARCHAR](256) COLLATE ARABIC_CI_AI)
	CREATE TABLE [#CustTbl]( [CustGuid] [UNIQUEIDENTIFIER], [Security] [INT]) 
	CREATE TABLE [#StoreTbl2] ([StoreGuid] UNIQUEIDENTIFIER, [Security] INT, [stName] NVARCHAR(256))
	CREATE TABLE [#CustTbl2] ([CustGuid] UNIQUEIDENTIFIER, [Security] INT, 
	cuCustomerName NVARCHAR(256), cuCustomerLatinName NVARCHAR(256))
	--Filling temporary tables
	--INSERT INTO [#BillsTypesTbl]	EXEC [prcGetBillsTypesList] 	@SrcTypes
	INSERT INTO [#BillsTypesTbl] EXEC [prcGetBillsTypesList3] 	@SrcTypesguid, NULL, @SortAffectCostType--, @UserGuid

	INSERT INTO [#StoreTbl]		EXEC [prcGetStoresList] 		@StoreGUID
	INSERT INTO [#CostTbl]([CostGuid], [Security])		EXEC [prcGetCostsList] 			@CostGUID
	INSERT INTO [#CustTbl]		EXEC [prcGetCustsList] 	null, null, @CustCondGuid 
	IF (@CustCondGuid = 0X00)
		INSERT INTO [#CustTbl] VALUES(0X00,0)
	INSERT INTO [#CustTbl2] SELECT [CustGuid], c.[Security], ISNULL(CustomerName,'') cuCustomerName, ISNULL(LatinName,'') cuCustomerLatinName  
	FROM [#CustTbl] C LEFT JOIN [cu000] cu ON cu.Guid = [CustGuid]
	CREATE TABLE [#MatTbl]( [MatGUID] [UNIQUEIDENTIFIER], [mtSecurity] [INT])  
	IF (ISNULL(@CostGUID,0X0) = 0X0)
		INSERT INTO [#CostTbl] VALUES (0X0,0,'')
	
	INSERT INTO [#StoreTbl2] SELECT [StoreGuid], [s].[Security],CASE @Lang WHEN 0 THEN [Name] ELSE CASE [LatinName] WHEN '' THEN [Name] ELSE [LatinName] END  END AS [stName]
	FROM [#StoreTbl] AS [s] INNER JOIN [st000] AS [st] ON [st].[guid] = [StoreGuid] 
	
	IF @NotesContain IS NULL
		SET @NotesContain = ''
	IF @NotesNotContain IS NULL
		SET @NotesNotContain = ''
	CREATE TABLE #QTYS
	(
		[Qty]		FLOAT,
		[Bonus]		FLOAT,
		[Price]		FLOAT,
		[MatGUID] [UNIQUEIDENTIFIER],
		[stGUID] [UNIQUEIDENTIFIER]	,
		[TotalDiscountPercent] FLOAT,
		[TotalExtraPercent] FLOAT   
	) 
	CREATE TABLE [#EndResult]
	(
		[MatPtr]				[UNIQUEIDENTIFIER],
		[buType]				[UNIQUEIDENTIFIER],
		[buNumber]				[UNIQUEIDENTIFIER],
		[BillNumber]			[INT],
		[buIsPosted]			[INT],
		[buCostPtr]				[UNIQUEIDENTIFIER],
		[Security]				[INT],
		[buDate]				[DATETIME],
		[buNotes]				[NVARCHAR](MAX) ,
		[buVendor]				[INT],
		[buSalesManPtr]			[INT],
		[buCust_Name]			[NVARCHAR](256),
		[buCustLatinName]		[NVARCHAR](256),
		[buTotal]				[FLOAT],
		[BuFirstPayment]			[FLOAT],
		[buTotalDisc]			[FLOAT],
		[buTotalExtra]			[FLOAT],
		[buItemsDisc]			[FLOAT],
		[buBonusDisc]			[FLOAT],
		[biGuid]				[UNIQUEIDENTIFIER],
		[biStorePtr]			[UNIQUEIDENTIFIER],
		[biNotes]				[NVARCHAR](MAX) ,
		[biPrice]				[FLOAT],
		[biBillQty]				[FLOAT],
		[biBillBonusQnt]		[FLOAT],
		[biQty]					[FLOAT],
		[biCalculatedQty2]		[FLOAT],
		[biCalculatedQty3]		[FLOAT],
		[biBonusQnt]			[FLOAT],
		[biUnity]				[INT],
		[biDiscount]			[FLOAT],
		[biBonusDisc]			[FLOAT],
		[biExtra]				[FLOAT],
		[biProfits]				[FLOAT],
		[biLCDisc]				[FLOAT],
		[biLCExtra]				[FLOAT],
		[MtUnit2]				[NVARCHAR](256) ,
		[MtUnit3]				[NVARCHAR](256) ,
		[UserSecurity]			[INT],
		[UserReadPriceSecurity]	[INT],
		[MtSecurity]			[INT],
		[buFormatedNumber]		[NVARCHAR](256) ,
		[buLatinFormatedNumber]	[NVARCHAR](256) ,
		[CostCodeName]			[NVARCHAR](256) ,
		[Checked]				[INT] DEFAULT 0,
		[ExpireDate]			[DATETIME],
		[ProductionDate]		[DATETIME],
		[Length]				[FLOAT],
		[Width]					[FLOAT],
		[Height]				[FLOAT],
		[Count]					[FLOAT],
		[ClassPtr]				[NVARCHAR](256) ,
		[Fact]					[FLOAT],
		[stName]				[NVARCHAR](256) ,
		[Branch]				[UNIQUEIDENTIFIER],
		biVat					FLOAT,
		[buItemsExtra]			[FLOAT],
		[biUnitPrice]			[FLOAT],
		[biMatPtr]				[UNIQUEIDENTIFIER],
		[MtUnity]				[NVARCHAR](256) ,
		[mtDefUnitName]			[NVARCHAR](256) ,
		[biUnitExtra]			FLOAT,
		[biUnitDiscount]		FLOAT,
		[RowNumber]				[INT] IDENTITY(1,1),
		[PriorityNum]			[INTEGER],
		[SamePriorityOrder]		INT, 
		[SortNumber]			INT,
		[LCGuid]				[UNIQUEIDENTIFIER],	
		[LCName]				[NVARCHAR](256),
		IsMatched				BIT,
		[BiTotalDiscountPercent]	FLOAT,
		[BiTotalExtraPercent]	    FLOAT
	)
	INSERT INTO [#EndResult]
	(
		[MatPtr],
		[buType],
		[buNumber],
		[BillNumber],
		[buIsPosted],
		[buCostPtr],
		[Security],
		[buDate],
		[buNotes],
		[buVendor],
		[buSalesManPtr],
		[buCust_Name],
		[buCustLatinName],
		[buTotal],
		[BuFirstPayment],
		[buTotalDisc],
		[buTotalExtra],
		[buItemsDisc],
		[buBonusDisc],
		[biStorePtr],
		[biNotes],
		[biPrice],
		[biBillQty],
		[biBillBonusQnt],
		[biQty],
		[biCalculatedQty2],
		[biCalculatedQty3],
		[biBonusQnt],
		[biUnity],
		[biDiscount],
		[biBonusDisc],
		[biExtra],
		[biProfits],
		[biLCDisc],
		[biLCExtra],
		[MtUnit2],
		[MtUnit3],
		[UserSecurity],
		[UserReadPriceSecurity],
		[MtSecurity],
		[buFormatedNumber],
		[buLatinFormatedNumber],
		[CostCodeName],
		[ExpireDate],
		[ProductionDate],
		[Length],
		[Width],
		[Height],
		[Count],
		[ClassPtr],	
		[biGuid],
		[Fact],
		[stName],
		[Branch],
		biVat,
		[buItemsExtra],
		[biUnitPrice],
		[biMatPtr],
		[MtUnity],
		[mtDefUnitName],
		[biUnitExtra],
		[biUnitDiscount],
		[PriorityNum],
		[SamePriorityOrder],
		[SortNumber],
		[LCGuid],
		[LCName],
		IsMatched,
		[BiTotalDiscountPercent],
		[BiTotalExtraPercent]
	)
	SELECT
		@MatGUID,
		[r].[buType],
		[r].[buGUID],
		[r].[buNumber],
		[r].[buIsPosted],
		[r].[buCostPtr],
		[r].[buSecurity],
		[r].[buDate],
		[r].[buNotes],
		[r].[buVendor],
		[r].[buSalesManPtr],
		[c].[cuCustomerName],
		[c].[cuCustomerLatinName],
		CASE WHEN [UserReadPriceSecurity] >= [BuSecurity] THEN [r].[buTotal] ELSE 0 END , 
		CASE WHEN [UserReadPriceSecurity] >= [BuSecurity] THEN [r].[buFirstPay] * [dbo].[fnCurrency_fix](1, [biCurrencyPtr], [biCurrencyVal], @CurrencyGUID, [buDate]) ELSE 0 END,  
		CASE WHEN [UserReadPriceSecurity] >= [BuSecurity] THEN [r].[buTotalDisc] ELSE 0 END, 
		CASE WHEN [UserReadPriceSecurity] >= [BuSecurity] THEN [r].[buTotalExtra] - [r].[buItemsExtra] ELSE 0 END, 
		CASE WHEN [UserReadPriceSecurity] >= [BuSecurity] THEN [r].[buItemsDisc] ELSE 0 END,
		CASE WHEN [UserReadPriceSecurity] >= [BuSecurity] THEN [r].[buBonusDisc] ELSE 0 END, 
		[r].[biStorePtr],
		[r].[biNotes],
		CASE WHEN [UserReadPriceSecurity] >= [BuSecurity] THEN [r].[biPrice] ELSE 0 END AS [biPrice], 
		[r].[biBillQty],
		[r].[biBillBonusQnt],
		[r].[biQty],
		[r].[biCalculatedQty2],
		[r].[biCalculatedQty3],
		[r].[biBonusQnt],
		[r].[biUnity],
		CASE WHEN [UserReadPriceSecurity] >= [BuSecurity] THEN [r].[biDiscount] ELSE 0 END ,
		CASE WHEN [UserReadPriceSecurity] >= [BuSecurity] THEN [r].[biBonusDisc] ELSE 0 END ,
		CASE WHEN [UserReadPriceSecurity] >= [BuSecurity] THEN [r].[biExtra] ELSE 0 END,
		CASE WHEN [UserReadPriceSecurity] >= [BuSecurity] THEN [r].[biProfits] ELSE 0 END,
		CASE WHEN [UserReadPriceSecurity] >= [BuSecurity] THEN [r].[biLCDisc]  ELSE 0 END ,
		CASE WHEN [UserReadPriceSecurity] >= [BuSecurity] THEN [r].[biLCExtra] ELSE 0 END,
		[r].[MtUnit2],
		[r].[MtUnit3],
		CASE [r].[buIsPosted] WHEN 1 THEN [UserSecurity] ELSE [UnPostedSecurity] END,
		[bt].[UserReadPriceSecurity],
		[r].[mtsecurity],
		[r].[buFormatedNumber],
		[r].[buLatinFormatedNumber],
		[co].[Name],
		[r].[biExpireDate],
		[r].[biProductionDate],
		[r].[biLength],
		[r].[biWidth],
		[r].[biHeight],
		[r].[biCount],
		[r].[biClassPtr],
		[r].[biGuid],
		[dbo].[fnCurrency_fix](1, [biCurrencyPtr], [biCurrencyVal], @CurrencyGUID, [buDate]),
		[st].[stName],[r].[buBranch],
		[biVat],
		CASE WHEN [UserReadPriceSecurity] >= [BuSecurity] THEN [r].[buItemsExtra] ELSE 0 END AS [buItemsExtra],
		CASE WHEN [UserReadPriceSecurity] >= [BuSecurity] THEN [r].[biUnitPrice] ELSE 0 END AS [biUnitPrice], 
		[r].[biMatPtr],
		[r].[MtUnity],
		[r].[mtDefUnitName],
		[r].[biUnitExtra],
		[r].[biUnitDiscount],
		[PriorityNum],
		bt.[SamePriorityOrder],
		bt.[SortNumber],
		ISNULL([lc].[GUID], 0x0),
		CASE WHEN [dbo].[fnConnections_GetLanguage]() <> 0 AND ISNULL([lc].[LatinName], '') <> '' THEN [lc].[LatinName] ELSE [lc].[Name] END + ': ' + CAST([lc].[Number] AS NVARCHAR(200)),
		1,
		[r].[biTotalDiscountPercent],
		[r].[biTotalExtraPercent]
	FROM
		(([dbo].[vwExtended_bi] AS [r]
		INNER JOIN [#BillsTypesTbl] AS [bt] ON [r].[buType] = [bt].[TypeGuid])
		INNER JOIN [#CostTbl] AS [co] ON [co].[CostGUID] = [BiCostPtr])
		INNER JOIN [#StoreTbl2] AS [st] ON [st].[StoreGUID] = [BiStorePtr]
		INNER JOIN [#CustTbl2] AS [c] ON [c].[CustGuid] = [r].[buCustPtr]
		LEFT JOIN [LC000] AS [lc] ON [lc].[GUID] = [r].[buLCGUID]
	WHERE
		[budate] BETWEEN @StartDate AND @EndDate
		AND( (@PostedValue = -1) 				OR (BuIsPosted = @PostedValue))
		AND( [BiMatPtr] = @MatGUID)
		AND( (@NotesContain = '')				OR ([BuNotes] LIKE '%'+ @NotesContain + '%') OR ( [BiNotes] LIKE '%' + @NotesContain + '%'))
		AND( (@NotesNotContain ='')				OR (([BuNotes] NOT LIKE '%' + @NotesNotContain + '%') AND ([BiNotes] NOT LIKE '%'+ @NotesNotContain + '%')))
		AND( @Class = ''			OR @Class = [biClassPtr])
		AND( @SelectedUserGuid = 0x00		OR @SelectedUserGuid = [buUserGUID])
	--	dbo.vwExtended_bi
	ORDER BY
		[BuDate],
		--[BtDirection] DESC,
		[BuSortFlag],
		[buType],
		[BuNumber]
	----------------------------------------------------------------------
	DECLARE @moveCount INT = (SELECT ISNULL(count(*), 0) FROM #endResult)
	DECLARE @allMoveCount INT = (SELECT ISNULL(count(*), 0) 
		FROM bi000 bi
			INNER JOIN [#CostTbl] AS [co] ON [co].[CostGUID] = bi.CostGUID
			INNER JOIN [#StoreTbl2] AS [st] ON [st].[StoreGUID] = bi.StoreGUID
			LEFT JOIN bu000 AS bu ON bu.guid= bi.ParentGUID
		WHERE MatGUID = @MatGUID 
				AND ((((@PostedValue = 1 OR @PostedValue = -1) AND @AccSum = 0 ) OR ( @PostedValue = 1 AND  bu.Date BETWEEN @StartDate AND @EndDate AND @AccSum = 1)) AND bu.IsPosted = 1 ))

	UPDATE #EndResult SET IsMatched = CASE WHEN @moveCount = @allMoveCount THEN 1 ELSE 0 END
	----------------------------------------------------------------------
	--Calc LC Extra And Disc If LC Is Open
	IF @IsIncludeOpenedLC = 1
	BEGIN
		UPDATE R
			SET 
				R.biLCDisc = F.LCDisc,
				R.biLCExtra = F.LCExtra
		FROM #EndResult AS R
			CROSS APPLY dbo.fnLCGetBillItemsDiscExtra(R.LCGuid) AS F
				WHERE R.biGuid = F.biGUID
	END
		
	DECLARE @Type	UNIQUEIDENTIFIER
	SELECT @Type = b.[TypeGuid] FROM [#BillsTypesTbl] [b] INNER JOIN [bt000] bt ON b.[TypeGuid] = bt.Guid AND bt.Type = 2 AND [SortNum] = 2
	IF @Type IS NOT NULL
	BEGIN
		INSERT INTO [#MatTbl]			EXEC [prcGetMatsList] 		@MatGUID
		EXEC prcCalcEPBill @StartDate,@EndDate,@CurrencyGUID,@CostGUID,@StoreGuid,@PriceType,@PricePolicy,@PostedValue,@CurVal,@UseUnit	
		INSERT INTO [#EndResult]
		(
			[buType],
			[Security],
			[buDate],
			[biPrice]
		)
		SELECT @Type,0,@EndDate,SUM([Price] * (qty + [Bonus] ))
		FROM #QTYS
	END
	EXEC [prcCheckSecurity] @Result = '#EndResult'
	IF (@ShowChecked > 0)
	BEGIN
		DECLARE @UserGuid [UNIQUEIDENTIFIER] 
		SET @UserGuid = [dbo].[fnGetCurrentUserGUID]() 
		UPDATE [Res]
		SET  
			[Checked] = 1 
			--UserCheckGuid = RCH.UserGuid 
		FROM  
			[#EndResult] AS [Res] INNER JOIN [RCH000] As [RCH] 
			ON [Res].[biGuid] = [RCH].[ObjGUID]
		WHERE  
			@rid  = [RCH].[Type]
			AND( (@CheckForUsers = 1) OR ([RCH].[UserGuid] = @UserGuid))
		
		IF( @ItemChecked = 0)  
				DELETE FROM [#EndResult] WHERE [Checked] <> 1 OR  [Checked] IS NULL
		ELSE IF( @ItemChecked = 1)  
				DELETE FROM [#EndResult] WHERE [Checked] = 1 
	END
	DECLARE @Sql NVARCHAR(max)
	SET @Sql = 'SELECT 
		[r].[buType],
		[r].[buNumber],
		[r].[buIsPosted],
		[r].[buCostPtr],
		[r].[Security],
		[r].[buDate],
		[r].[buTotal],
		[r].[BuFirstPayment],
		ISNULL([r].[buTotalDisc],0) AS [buTotalDisc],
		[r].[buTotalExtra],
		[r].[buItemsDisc],
		[r].[buBonusDisc],
		[r].[buCust_Name] AS BuCustomerName,
		[r].[biStorePtr],
		ISNULL([r].[biPrice],0) AS [biPrice], 
		[r].[biBillQty],
		[r].[biBillBonusQnt],
		[r].[biQty],
		[r].[biCalculatedQty2],
		[r].[biCalculatedQty3],
		[r].[biBonusQnt],
		[r].[biUnity],
		[r].[biDiscount],
		[r].[biBonusDisc],
		[r].[biExtra],
		[r].[biProfits],
		[r].[biLCDisc],
		[r].[biLCExtra],
		[r].[MtUnit2],
		[r].[MtUnit3],
		[r].[UserSecurity],
		[r].[UserReadPriceSecurity],
		[r].[MtSecurity],
		[r].[buFormatedNumber],
		[r].[buLatinFormatedNumber],
		[r].[RowNumber],
		[r].[stName],
		[r].[Fact],
		[r].[Checked],
		ISNULL([MB].[ManGuid],0x0) AS [ManGuid],[r].[biGuid], [bt].[SortNum],
		[r].[LCGuid],
		[r].[LCName],
		[r].[IsMatched],
		[r].[BiTotalDiscountPercent],
		[r].[BiTotalExtraPercent] '
		
		IF (@IsCalledByWeb = 1)
		BEGIN
			SET @Sql = @Sql +  ',
			[r].[buItemsExtra],
			ISNULL([r].[biUnitPrice],0) AS [biUnitPrice], 
			[r].[biMatPtr],
			[r].[MtUnity],
			[r].[mtDefUnitName],
			[r].[biUnitExtra],
			[r].[biUnitDiscount],
			[bt].[bAffectCostPrice] AS [btAffectCostPrice], 
			[bt].[bAffectCustPrice] AS [btAffectCustPrice], 
			[bt].[Type] AS [btType], 
			[bt].[SortNum] AS [btSortNum], 
			[bt].[bIsInput] AS [btIsInput],
			[mt].[Unit2Fact],
			[mt].[Unit2FactFlag],
			[mt].[Unit3Fact],
			[mt].[Unit3FactFlag],
			CASE [bt].[BillType] WHEN 4 THEN -1 WHEN 5 THEN -1 ELSE 1 END AS billTypeSortFlag,
			mt.Code, 
			mt.Name, 
			mt.LatinName, 
			mt.Unity, 
			buCust_Name CuName,
			buCustLatinName CuLatinName, 
			bDiscAffectProfit, 
			bDiscAffectCost, 
			bExtraAffectProfit, 
			bExtraAffectCost '
		END
	-------------------------------------------------------------------------------------------------------
	
	SET @Sql = @Sql + ' FROM [#EndResult] AS [r] INNER JOIN bt000 bt on [r].[butype] = [bt].[guid]  '
	SET @Sql = @Sql +  ' LEFT JOIN [MB000] [MB] ON [r].[buNumber] = [MB].[BillGuid] '
	IF (@IsCalledByWeb = 1)
	BEGIN
		SET @Sql = @Sql +  ' LEFT JOIN [mt000] [mt] ON [r].[biMatPtr] = [mt].[GUID] '
	END

	SET @Sql = @Sql + '	ORDER BY [r].[budate], [r].[PriorityNum], r.[SortNumber], [r].[BillNumber], r.[SamePriorityOrder], [r].[RowNumber] ' 
	EXEC (@Sql)
	
	SELECT * FROM [#SecViol]
	IF @PrevBal = 1
	BEGIN
		DROP TABLE [#EndResult]

		DELETE [#MatTbl]
		INSERT INTO [#MatTbl]		EXEC [prcGetMatsList] 		@MatGUID, 0X00 
		EXEC repGetPrevBal @StartDate,@MatGUID,0x00,@StoreGUID,@CostGUID,@UseUnit,@SrcTypesguid,@CurrencyGUID,0,@PostedValue,@Class
	END	
	
#########################################################
CREATE PROCEDURE GetAllMatMoveInBills
	@MatGUID 	   UNIQUEIDENTIFIER = 0x0,
	@StoreGUID 	   UNIQUEIDENTIFIER = 0x0,
	@CostGUID 	   UNIQUEIDENTIFIER = 0x0,
	@GroupGUID 	   UNIQUEIDENTIFIER = 0x0,
	@OrderTypesSrc UNIQUEIDENTIFIER = 0x0,
	@ShowPrevBal   int = 0,
	@ShowJobCost   int = 0,
	@StartDate 	   DATETIME,
	@EndDate 	   DATETIME
AS	
BEGIN
	SET NOCOUNT ON 
	DECLARE @ResultCount int = 0
	CREATE Table #CostTbl(   
		Guid UNIQUEIDENTIFIER  
	)
	INSERT INTO #CostTbl SELECT * FROM fnGetCostsList(@CostGuid)  
	IF (@CostGuid = 0x0)  
		INSERT INTO #CostTbl VALUES (0x0)
	CREATE Table #BillsTypeTbl(   
		Guid UNIQUEIDENTIFIER,
		Name varchar(100) COLLATE ARABIC_CI_AI
	)
	INSERT INTO #BillsTypeTbl SELECT  bt.btGUID, bt.btName FROM vwbt AS bt WHERE bt.btGUID not in (SELECT IdType FROM RepSrcs WHERE IdTbl=@OrderTypesSrc)
	CREATE Table #GroupsTbl(   
		Guid UNIQUEIDENTIFIER,		
	)	
	INSERT INTO #GroupsTbl SELECT * FROM  fnGetGroupsList(@GroupGUID)
	IF (@GroupGUID = 0x0)  
		INSERT INTO #GroupsTbl VALUES (0x0)
	SELECT DISTINCT bi.biMatPtr, bt.btGuid, bt.btName ,bi.biGUID ,bi.biParent as ParentGuid
	FROM vwbt As bt
	INNER JOIN vwbu As bu ON bt.btGuid = bu.buType 
	INNER JOIN vwbi As bi ON bi.biParent = bu.buGuid 
	INNER JOIN #CostTbl As col ON col.Guid = bu.buCostPtr  
	INNER JOIN fnGetStoresList (@StoreGuid) AS stl ON stl.Guid = bu.buStorePtr   
	INNER JOIN #BillsTypeTbl As r ON (bt.btGuid = r.Guid)	
	INNER JOIN vwmt As m On (m.mtGuid = bi.biMatPtr)
	INNER JOIN #GroupsTbl As g ON  (g.Guid = m.mtGroup)
	WHERE 
	(bi.biMatPtr = @MatGUID OR @MatGUID = 0x0)  
	AND (bu.buStorePtr = @StoreGUID OR @StoreGUID = 0x0)   
	AND (bu.buCostPtr = @CostGUID OR @CostGUID = 0x0)  
	AND (m.mtGroup = @GroupGUID OR @GroupGUID = 0x0)  
	AND (NOT EXISTS(select * from RecostMaterials000 WHERE InBillGuid = bi.biParent))
	AND (NOT EXISTS(select * from RecostMaterials000 WHERE OutBillGuid = bi.biParent)) 
	SELECT bi.biMatPtr
	FROM vwbt As bt
	INNER JOIN vwbu As bu ON bt.btGuid = bu.buType 
	INNER JOIN vwbi As bi ON bi.biParent = bu.buGuid 
	INNER JOIN #CostTbl As col ON col.Guid = bu.buCostPtr  
	INNER JOIN fnGetStoresList (@StoreGuid) AS stl ON stl.Guid = bu.buStorePtr   	
	INNER JOIN vwmt As m On (m.mtGuid = bi.biMatPtr)
	INNER JOIN #GroupsTbl As g ON  (g.Guid = m.mtGroup)
	WHERE 
	(bi.biMatPtr = @MatGUID OR @MatGUID = 0x0)  
	AND (bu.buStorePtr = @StoreGUID OR @StoreGUID = 0x0)   
	AND (bu.buCostPtr = @CostGUID OR @CostGUID = 0x0)  
	AND (m.mtGroup = @GroupGUID OR @GroupGUID = 0x0) 
	AND ((bu.buDate < @StartDate) OR (bu.buDate > @EndDate))
	AND (NOT EXISTS(select * from RecostMaterials000 WHERE InBillGuid = bi.biParent))
	AND (NOT EXISTS(select * from RecostMaterials000 WHERE OutBillGuid = bi.biParent)) 
END

#########################################################
CREATE PROCEDURE repMatMoveMultiProduct
	@MatGUID 			[UNIQUEIDENTIFIER], 
	@GroupGUID			[UNIQUEIDENTIFIER], 
	@StartDate 			[DATETIME], 
	@EndDate 			[DATETIME], 
	@CustCondGuid		[UNIQUEIDENTIFIER],
	@StoreGUID 			[UNIQUEIDENTIFIER], -- 0 all stores so don't check store or list of stores 
	@CostGUID 			[UNIQUEIDENTIFIER], -- 0 all costs so don't Check cost or list of costs 
	@PostedValue 		[INT], -- 1 posted or 0 unposted -1 all posted & unposted 
	@NotesContain 		[NVARCHAR](256),-- NULL or Contain Text 
	@NotesNotContain 	[NVARCHAR](256), -- NULL or Not Contain 
	@SrcTypesguid		[UNIQUEIDENTIFIER] ,
	@UseUnit			[INT] = 0, --0 DEF 1 FIRST 
	@PrevBal			[INT] = 0,
	@CurrencyGUID		[UNIQUEIDENTIFIER] = 0X00,
	@RID				[FLOAT] = 0,
	@ShowChecked		[INT] = 0,
	@ItemChecked		[INT] = -1,
	@CheckForUsers		[INT] = 0,
	@Lang				[BIT] = 0,
	@Class				[NVARCHAR](256) = '',
	@MatCond			[UNIQUEIDENTIFIER] = 0X00,
	@SelectedUserGuid	[UNIQUEIDENTIFIER] = 0X00,
	@PriceType			[INT] = 2 ,
	@PricePolicy		[INT] = 121,
	@CurVal				[FLOAT] = 1,
	@IsIncludeOpenedLC	[BIT] = 0,
	@DetailCompositionMove   [INT] = 0,
	@AccSum				[BIT] = 0,
	@IsCalledByWeb		[BIT] = 0
AS 
	SET NOCOUNT ON 

	DECLARE @col1 NVARCHAR(100),@col2 NVARCHAR(100),@col3 NVARCHAR(100)

	DECLARE @SortAffectCostType BIT 
	SET @SortAffectCostType = 0
	IF @PostedValue = 1
		SET @SortAffectCostType = 1
	
	-- Creating temporary tables 
	CREATE TABLE [#SecViol]( [Type] [INT], [Cnt] [INTEGER]) 
	CREATE TABLE [#BillsTypesTbl]( [TypeGuid] [UNIQUEIDENTIFIER], [UserSecurity] [INTEGER], [UserReadPriceSecurity] [INTEGER], 
		[UnPostedSecurity] [INTEGER], [PriorityNum] [INTEGER], [SamePriorityOrder] INT, [SortNumber] INT) 
	CREATE TABLE [#StoreTbl]( [StoreGuid] [UNIQUEIDENTIFIER], [Security] [INT]) 
	CREATE TABLE [#CostTbl]( [CostGuid] [UNIQUEIDENTIFIER], [Security] [INT],[Name] [NVARCHAR](256) COLLATE ARABIC_CI_AI)
	CREATE TABLE [#MatTbl]( [MatGUID] [UNIQUEIDENTIFIER], [mtSecurity] [INT])  
	CREATE TABLE [#CustTbl]( [CustGuid] [UNIQUEIDENTIFIER], [Security] [INT]) 
	CREATE TABLE [#StoreTbl2] ([StoreGuid] UNIQUEIDENTIFIER, [Security] INT, [stName] NVARCHAR(250))
	CREATE TABLE [#CustTbl2] ([CustGuid] UNIQUEIDENTIFIER, [Security] INT, cuCustomerName NVARCHAR(250), cuCustomerLatinName NVARCHAR(250))
	
	--Filling temporary tables 
	INSERT INTO [#MatTbl]			EXEC [prcGetMatsList] 		@MatGUID, @GroupGUID,-1,@MatCond
	INSERT INTO [#BillsTypesTbl]	EXEC [prcGetBillsTypesList3] 	@SrcTypesguid, NULL, @SortAffectCostType
	INSERT INTO [#StoreTbl]			EXEC [prcGetStoresList] 		@StoreGUID 
	INSERT INTO [#CostTbl]([CostGuid], [Security])		EXEC [prcGetCostsList] 			@CostGUID
	INSERT INTO [#CustTbl]		EXEC [prcGetCustsList] 	null, null, @CustCondGuid 
	  IF (@CustCondGuid = 0X00)
        INSERT INTO [#CustTbl] VALUES(0X00,0)

	INSERT INTO [#CustTbl2] SELECT [CustGuid], c.[Security], ISNULL(CustomerName,'') cuCustomerName, ISNULL(LatinName,'') cuCustomerLatinName 
  FROM [#CustTbl] C LEFT JOIN [cu000] cu ON cu.Guid = [CustGuid]
	IF (ISNULL(@CostGUID,0X0) = 0X0)
		INSERT INTO [#CostTbl] VALUES (0X0,0,'')
	IF @NotesContain IS NULL 
		SET @NotesContain = '' 
	IF @NotesNotContain IS NULL 
		SET @NotesNotContain = '' 
	INSERT INTO [#StoreTbl2] SELECT  [StoreGuid] , [s].[Security],CASE @Lang WHEN 0 THEN [Name] ELSE CASE [LatinName] WHEN '' THEN [Name] ELSE [LatinName] END END AS [stName] FROM [#StoreTbl] AS [s] INNER JOIN [st000] AS [st] ON [st].[Guid] = [StoreGuid] 
	CREATE TABLE #QTYS
	(
		[Qty]		FLOAT,
		[Bonus]		FLOAT,
		[Price]		FLOAT,
		[MatGUID] [UNIQUEIDENTIFIER],
		[stGUID] [UNIQUEIDENTIFIER]	,
		[TotalDiscountPercent] FLOAT,
		[TotalExtraPercent] FLOAT   
	) 
	CREATE TABLE [#EndResult] 
	( 
		[MatPtr] 					[UNIQUEIDENTIFIER],
		[MatCode]					[NVARCHAR](256) ,
		[MatName]					[NVARCHAR](256) ,
		[buType]					[UNIQUEIDENTIFIER], 
		[buNumber]					[UNIQUEIDENTIFIER],
		[BillNumber]				[INT],
		[buIsPosted]				[INT], 
		[buCostPtr]					[UNIQUEIDENTIFIER], 
		[Security]					[INT], 
		[buDate]					[DATETIME], 
		[buNotes]					[NVARCHAR](MAX) , 
		[buVendor]					[INT], 
		[buSalesManPtr]				[INT], 
		[buCust_Name]				[NVARCHAR](256) , 
		[buCustLatinName]			[NVARCHAR](256),
		[buTotal]					[FLOAT], 
		[BuFirstPayment]				[FLOAT], 
		[buTotalDisc]				[FLOAT], 
		[buTotalExtra]				[FLOAT], 
		[buItemsDisc]				[FLOAT], 
		[buBonusDisc]				[FLOAT], 
		[biGuid]					[UNIQUEIDENTIFIER], 
		[biStorePtr]				[UNIQUEIDENTIFIER], 
		[biNotes]					[NVARCHAR](MAX) , 
		[biPrice]					[FLOAT], 
		[biBillQty]					[FLOAT], 
		[biBillBonusQnt]			[FLOAT], 
		[biQty]						[FLOAT], 
		[biCalculatedQty2]			[FLOAT], 
		[biCalculatedQty3]			[FLOAT], 
		[biBonusQnt]				[FLOAT], 
		[biUnity]					[INT], 
		[biDiscount]				[FLOAT], 
		[biBonusDisc]				[FLOAT], 
		[biExtra]					[FLOAT], 
		[biProfits]					[FLOAT], 
		[biLCDisc]					[FLOAT],
		[biLCExtra]					[FLOAT],
		[MtUnit2]					[NVARCHAR](256) , 
		[MtUnit3]					[NVARCHAR](256) , 
		[UserSecurity] 				[INT], 
		[UserReadPriceSecurity]		[INT], 
		[MatSecurity]				[INT], 
		[buFormatedNumber]			[NVARCHAR](256) , 
		[buLatinFormatedNumber]		[NVARCHAR](256) ,
		[UnitName]					[NVARCHAR](256) ,
		[mtUnity]					[NVARCHAR](256) ,
		[UnitFact]					[FLOAT], 
		[Unit2Fact]					[FLOAT],
		[Unit3Fact]					[FLOAT],
		[DefUnit]					[INT], 
		[CostCodeName]				[NVARCHAR](256) , 
		[Checked]					[INT] DEFAULT 0,
		[ExpireDate]				[DATETIME],
		[ProductionDate]			[DATETIME],
		[Length]					[FLOAT],
		[Width]						[FLOAT],
		[Height]					[FLOAT],
		[Count]						[FLOAT],
		[ClassPtr]					[NVARCHAR](256) ,
		[Fact]						[FLOAT],
		[stName]					[NVARCHAR](256) ,
		[Branch]					[UNIQUEIDENTIFIER], 
		biVat						FLOAT,
		[RowNumber]					[INT] IDENTITY(1,1), 
		[PriorityNum]				[INTEGER],
		[SamePriorityOrder]			INT, 
		[SortNumber]				INT,
		[LCGuid]					[UNIQUEIDENTIFIER],
		[LCName]					[NVARCHAR](256) COLLATE ARABIC_CI_AI,
		[IsMatched]					BIT,
		[BiTotalDiscountPercent]	FLOAT,
		[BiTotalExtraPercent]	    FLOAT
	) 
	INSERT INTO [#EndResult] 
	( 
		[MatPtr] 	,
		[MatCode],
		[MatName],
		[buType], 
		[buNumber], 
		[BillNumber],
		[buIsPosted], 
		[buCostPtr], 
		[Security], 
		[buDate], 
		[buNotes], 
		[buVendor], 
		[buSalesManPtr], 
		[buCust_Name], 
		[buCustLatinName],
		[buTotal], 
		[BuFirstPayment],
		[buTotalDisc], 
		[buTotalExtra], 
		[buItemsDisc], 
		[buBonusDisc], 
		[biStorePtr], 
		[biNotes], 
		[biPrice], 
		[biBillQty], 
		[biBillBonusQnt], 
		[biQty], 
		[biCalculatedQty2], 
		[biCalculatedQty3], 
		[biBonusQnt], 
		[biUnity], 
		[biDiscount], 
		[biBonusDisc], 
		[biExtra], 
		[biProfits], 
		[biLCDisc],
		[biLCExtra],
		[MtUnit2], 
		[MtUnit3], 
		[UserSecurity], 
		[UserReadPriceSecurity], 
		[MatSecurity], 
		[buFormatedNumber], 
		[buLatinFormatedNumber],
		[UnitFact],
		[Unit2Fact],
		[Unit3Fact],
		[DefUnit],
		[UnitName],
		[mtUnity],
		[CostCodeName],
		[ExpireDate],
		[ProductionDate],
		[Length],
		[Width],
		[Height],
		[Count],
		[ClassPtr],	
		[biGuid],
		[Fact],
		[stName],
		[Branch],biVat,
		[PriorityNum],
		[SamePriorityOrder],
		[SortNumber],
		[LCGuid],
		[LCName],
		[IsMatched],
		[BiTotalDiscountPercent],
		[BiTotalExtraPercent]
	) 
	SELECT 
		[r].[biMatPtr],
		[r].[mtCode],
		CASE @DetailCompositionMove WHEN 0 THEN CASE @Lang WHEN 0 THEN   [r].mtName ELSE CASE [r].[mtLatinName] WHEN '' THEN [r].[mtName] ELSE [r].[mtLatinName] END END ELSE CASE @Lang WHEN 0 THEN   [r].mtCompositionName ELSE CASE [r].[mtCompositionLatinName] WHEN '' THEN [r].mtCompositionName ELSE [r].mtCompositionLatinName END END  END ,
		[r].[buType], 
		[r].[buGUID],
		[r].[buNumber],
		[r].[buIsPosted], 
		[r].[buCostPtr], 
		[r].[buSecurity], 
		[r].[buDate], 
		[r].[buNotes], 
		[r].[buVendor], 
		[r].[buSalesManPtr], 
		[c].[cuCustomerName], 
		[c].[cuCustomerLatinName],
		CASE WHEN [UserReadPriceSecurity] >= [BuSecurity] THEN [r].[buTotal] ELSE 0 END,  
		CASE WHEN [UserReadPriceSecurity] >= [BuSecurity] THEN [r].[buFirstPay] * [dbo].[fnCurrency_fix](1, [biCurrencyPtr], [biCurrencyVal], @CurrencyGUID, [buDate]) ELSE 0 END,  
		CASE WHEN [UserReadPriceSecurity] >= [BuSecurity] THEN [r].[buTotalDisc] ELSE 0 END,  
		CASE WHEN [UserReadPriceSecurity] >= [BuSecurity] THEN [r].[buTotalExtra] - [r].[buItemsExtra] ELSE 0 END,  
		CASE WHEN [UserReadPriceSecurity] >= [BuSecurity] THEN [r].[buItemsDisc] ELSE 0 END, 
		CASE WHEN [UserReadPriceSecurity] >= [BuSecurity] THEN [r].[buBonusDisc] ELSE 0 END,  
		[r].[biStorePtr], 
		[r].[biNotes], 
		CASE WHEN [UserReadPriceSecurity] >= [BuSecurity] THEN [r].[biPrice] ELSE 0 END,  
		[r].[biBillQty], 
		[r].[biBillBonusQnt], 
		[r].[biQty], 
		[r].[biCalculatedQty2], 
		[r].[biCalculatedQty3], 
		[r].[biBonusQnt], 
		[r].[biUnity], 
		CASE WHEN [UserReadPriceSecurity] >= [BuSecurity] THEN [r].[biDiscount]  ELSE 0 END, 
		CASE WHEN [UserReadPriceSecurity] >= [BuSecurity] THEN [r].[biBonusDisc] ELSE 0 END, 
		CASE WHEN [UserReadPriceSecurity] >= [BuSecurity] THEN [r].[biExtra] ELSE 0 END, 
		CASE WHEN [UserReadPriceSecurity] >= [BuSecurity] THEN [r].[biProfits] ELSE 0 END,
		CASE WHEN [UserReadPriceSecurity] >= [BuSecurity] THEN [r].[biLCDisc]  ELSE 0 END, 
		CASE WHEN [UserReadPriceSecurity] >= [BuSecurity] THEN [r].[biLCExtra]  ELSE 0 END,  
		[r].[MtUnit2], 
		[r].[MtUnit3], 
		CASE [r].[buIsPosted] WHEN 1 THEN [UserSecurity] ELSE [UnPostedSecurity] END,
		[bt].[UserReadPriceSecurity], 
		[r].[mtsecurity], 
		[r].[buFormatedNumber], 
		[r].[buLatinFormatedNumber],
		[r].[mtUnit2Fact],
		[r].[mtUnit2Fact],
		[r].[mtUnit3Fact],
		[r].[mtDefUnit],
		CASE @UseUnit
			WHEN 0 THEN [r].[mtUnity]
			WHEN 1 THEN [r].[mtUnit2] 
			WHEN 2 THEN [r].[mtUnit3] 
			ELSE [r].[mtDefUnitName]
		END,
		[r].[mtUnity],
		[co].[Name],
		[r].[biExpireDate],
		[r].[biProductionDate],
		[r].[biLength],
		[r].[biWidth],
		[r].[biHeight],
		[r].[biCount],
		[r].[biClassPtr],
		[biGuid],
		[dbo].[fnCurrency_fix](1, [biCurrencyPtr], [biCurrencyVal], @CurrencyGUID, [buDate]),
		[st].[stName],[buBranch],biVat,[PriorityNum],
		bt.[SamePriorityOrder],
		bt.[SortNumber],
		[lc].[GUID],
		CASE WHEN [dbo].[fnConnections_GetLanguage]() <> 0 AND ISNULL([lc].[LatinName], '') <> '' THEN [lc].[LatinName] ELSE [lc].[Name] END + ': ' + CAST([lc].[Number] AS NVARCHAR(200)),
		1,
		[r].[biTotalDiscountPercent],
		[r].[biTotalExtraPercent]
	FROM
		((([dbo].[vwExtended_bi] AS [r]
		INNER JOIN [#BillsTypesTbl] AS [bt] ON [r].[buType] = [bt].[TypeGuid])
		INNER JOIN [#MatTbl]AS [mt] ON [mt].[MatGUID] = [r].[biMatPtr])
		INNER JOIN [#CostTbl] AS [co] ON [co].[CostGUID] = [BiCostPtr])
		INNER JOIN [#StoreTbl2] AS [st] ON [st].[StoreGUID] = [BiStorePtr]
		INNER JOIN [#CustTbl2] AS [c] ON [c].[CustGuid] = [r].[buCustPtr]
		LEFT JOIN [LC000] AS [lc] ON [lc].[GUID] = [r].[buLCGUID]
	WHERE 
		[budate] BETWEEN @StartDate AND @EndDate 
		AND( (@PostedValue = -1) 				OR ([BuIsPosted] = @PostedValue)) 
		AND( (@NotesContain = '')				OR ([BuNotes] LIKE '%'+ @NotesContain + '%') OR ( [BiNotes] LIKE '%' + @NotesContain + '%')) 
		AND( (@NotesNotContain ='')				OR (([BuNotes] NOT LIKE '%' + @NotesNotContain + '%') AND ([BiNotes] NOT LIKE '%'+ @NotesNotContain + '%'))) 
		AND( @Class = ''			OR @Class = [biClassPtr])
		AND( @SelectedUserGuid = 0x00		OR @SelectedUserGuid = [buUserGUID])
	--	dbo.vwExtended_bi 
	ORDER BY 
		[BuDate],
		--[BtDirection] DESC, 
		[BuSortFlag],
		[buType], 
		[BuNumber] 
	--OPTION (FAST 1)  
	---check sec 
	
	----------------------------------------------------------------------
	--Calc LC Extra And Disc If LC Is Open
	IF @IsIncludeOpenedLC = 1
	BEGIN
		UPDATE R
			SET 
				R.biLCDisc = F.LCDisc,
				R.biLCExtra = F.LCExtra
		FROM #EndResult AS R
			CROSS APPLY dbo.fnLCGetBillItemsDiscExtra(R.LCGuid) AS F
				WHERE R.biGuid = F.biGUID
	END

	EXEC [prcCheckSecurity] @Result = '#EndResult'
	IF (@ShowChecked > 0)
	BEGIN
		DECLARE @UserGuid [UNIQUEIDENTIFIER] 
		SET @UserGuid = [dbo].[fnGetCurrentUserGUID]() 
		
		UPDATE [Res]
		SET  
			[Checked] = 1 
			--UserCheckGuid = RCH.UserGuid 
		FROM  
			[#EndResult] AS [Res] INNER JOIN [RCH000] As [RCH] 
			ON [Res].[biGuid] = [RCH].[ObjGUID]
		WHERE  
			@rid  = [RCH].[Type]
			AND( (@CheckForUsers = 1) OR ([RCH].[UserGuid] = @UserGuid))
		
		IF( @ItemChecked = 0)  
			DELETE FROM [#EndResult] WHERE [Checked] <> 1 OR  [Checked] IS NULL
		ELSE IF( @ItemChecked = 1)  
				DELETE FROM [#EndResult] WHERE [Checked] = 1 
	END
	DECLARE @Type	UNIQUEIDENTIFIER
	SELECT @Type = b.[TypeGuid] FROM [#BillsTypesTbl] [b] INNER JOIN [bt000] bt ON b.[TypeGuid] = bt.Guid AND bt.Type = 2 AND [SortNum] = 2
	IF @Type IS NOT NULL
	BEGIN
		EXEC prcCalcEPBill @StartDate,@EndDate,@CurrencyGUID,@CostGUID,@StoreGuid,@PriceType,@PricePolicy,@PostedValue,@CurVal,@UseUnit	
		INSERT INTO [#EndResult]
		(
			[buType],
			[MatPtr],
			[Security],
			[buDate],
			[biPrice],
			[MatCode],
			[MatName]
		)
		SELECT @Type,[MatGUID],0,@EndDate,SUM(a.[Price] * (a.qty + a.[Bonus] )),Code,CASE @Lang WHEN 0 THEN [Name] ELSE CASE [LatinName] WHEN '' THEN [Name] ELSE [LatinName] END END
		FROM #QTYS a INNER JOIN mt000 b on b.Guid = [MatGUID] GROUP BY [MatGUID],Code,CASE @Lang WHEN 0 THEN [Name] ELSE CASE [LatinName] WHEN '' THEN [Name] ELSE [LatinName] END END
	END 
	-------------------------------------------------------------------------
	CREATE TABLE #MatMoveCount
	(
		MatGuid UNIQUEIDENTIFIER,
		MoveCount INT,
		AllMoveCount INT
	)

	INSERT INTO #MatMoveCount
	SELECT bi.MatGUID, 0, COUNT(*) 
	FROM bi000 bi
		INNER JOIN [#MatTbl] AS [mt] ON [mt].[MatGUID] = bi.MatGUID
		INNER JOIN [#CostTbl] AS [co] ON [co].[CostGUID] = bi.CostGUID
		INNER JOIN [#StoreTbl2] AS [st] ON [st].[StoreGUID] = bi.StoreGUID
		LEFT JOIN bu000 AS bu ON bu.GUID = bi.ParentGUID
		WHERE  ((((( @PostedValue = -1 OR  @PostedValue = 1) AND @AccSum = 0) OR ( @PostedValue = 1 AND bu.Date BETWEEN @StartDate AND @EndDate AND @AccSum = 1)) AND (Bu.IsPosted = 1)) 
			OR ((@PostedValue = 0 )))
	GROUP BY bi.MatGUID

	UPDATE #MatMoveCount SET MoveCount = MCount
	FROM (SELECT MatPtr, COUNT(biGuid) MCount FROM #EndResult GROUP BY MatPtr) T
	WHERE MatPtr = MatGuid

	UPDATE #EndResult Set IsMatched = CASE WHEN MoveCount = AllMoveCount THEN 1 ELSE 0 END
	FROM #MatMoveCount
	WHERE MatPtr = MatGuid
	-------------------------------------------------------------------------
	DECLARE @Sql NVARCHAR(max)
	
	SET @Sql = 'SELECT [r].[MatPtr],
	[r].[MatCode],
		[r].[MatName],
		[r].[buType], 
		[r].[buNumber], 
		[r].[buIsPosted], 
		[r].[buCostPtr], 
		[r].[Security], 
		[r].[buDate], 
		[r].[buTotal], 
		[r].[BuFirstPayment],
		ISNULL([r].[buTotalDisc],0) AS [buTotalDisc], 
		[r].[buTotalExtra], 
		[r].[buItemsDisc], 
		[r].[buBonusDisc], 
		[r].[biStorePtr], 
		ISNULL([r].[biPrice],0) AS [biPrice], 
		[r].[biBillQty], 
		[r].[biBillBonusQnt], 
		[r].[biQty], 
		[r].[biCalculatedQty2], 
		[r].[biCalculatedQty3], 
		[r].[mtUnity],
		[r].[biBonusQnt], 
		[r].[biUnity], 
		[r].[biDiscount], 
		[r].[biBonusDisc], 
		[r].[biExtra], 
		[r].[biProfits], 
		[r].[biLCDisc],
		[r].[biLCExtra],
		[r].[MtUnit2], 
		[r].[MtUnit3], 
		[r].[UserSecurity], 
		[r].[UserReadPriceSecurity], 
		[r].[MatSecurity], 
		[r].[buFormatedNumber], 
		[r].[buLatinFormatedNumber], 
		[r].[RowNumber], 
		[r].[stName],
		[r].[UnitFact],
		[r].[Unit2Fact],
		[r].[Unit3Fact],
		[r].[DefUnit],
		[r].[UnitName],
		[r].[Fact],
		[r].[Checked],
		ISNULL([MB].[ManGuid],0x0) AS [ManGuid],
		[r].[biGuid], [bt].[SortNum], CASE [bt].[BillType] WHEN 4 THEN -1 WHEN 5 THEN -1 ELSE 1 END AS billTypeSortFlag,
		[r].[LCGuid],
		[r].[LCName],
		[r].[IsMatched],
		[r].[BiTotalDiscountPercent],
		[r].[BiTotalExtraPercent] '

		IF (@IsCalledByWeb = 1)		
		BEGIN		
			SET @Sql = @Sql +  ',		
				[buCust_Name] AS CuName,		
				[buCustLatinName] AS CuLatinName,		
				[mt].[Unity], 		
				[bDiscAffectProfit], 		
				[bDiscAffectCost], 		
				[bExtraAffectProfit], 		
				[bExtraAffectCost],
				[bAffectCostPrice] AS [btAffectCostPrice],
				[bAffectCustPrice] AS [btAffectCustPrice],
				[bIsInput] AS [btIsInput],
				mt.[Unit2FactFlag],
				mt.[Unit3FactFlag]
			'		
		END
	-------------------------------------------------------------------------------------------------------
	SET @Sql = @Sql + ' FROM [#EndResult] AS [r] INNER JOIN bt000 bt ON [r].[butype] = [bt].[guid] '
	SET @Sql = @Sql + ' LEFT JOIN [MB000] [MB] ON [r].[buNumber] = [MB].[BillGuid] '
	IF (@IsCalledByWeb = 1)		
	BEGIN		
		SET @Sql = @Sql +  ' LEFT JOIN [mt000] [mt] ON [r].[MatPtr] = [mt].[GUID]  '		
	END
	SET @Sql = @Sql + '	ORDER BY [r].[MatCode], [r].[budate], [r].[PriorityNum], r.[SortNumber], [r].[BillNumber], r.[SamePriorityOrder], [r].[RowNumber] ' 
	
	EXEC (@Sql)

	IF @PrevBal = 1
	BEGIN
		DROP TABLE [#EndResult]
		EXEC repGetPrevBal @StartDate,@MatGUID,@GroupGUID,@StoreGUID,@CostGUID,@UseUnit,@SrcTypesguid,@CurrencyGUID,0,@PostedValue,@Class,0,0,0
	END
	SELECT * FROM [#SecViol] 
###########################################################################
#END
