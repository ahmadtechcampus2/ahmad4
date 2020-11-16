##########################################################################
CREATE PROCEDURE SNMove
	@SNName 			[NVARCHAR] (256),
	@StartDate 			[DateTime] ,
	@EndDate 			[DateTime] ,
	@PostedValue 		[INT],
	@NotesContain 		[NVARCHAR] (256),
	@NotesNotContain	[NVARCHAR] (256),
	@CurrencyGUID 		[UNIQUEIDENTIFIER] ,
	@CurrencyVal 		[FLOAT],
	@SrcTypesguid		[UNIQUEIDENTIFIER] ,
	@ShowGroup			[INT],
	@MatGUID 			[UNIQUEIDENTIFIER] ,
	@GroupGUID 			[UNIQUEIDENTIFIER] ,
	@StoreGUID 			[UNIQUEIDENTIFIER] ,
	@CustGUID 			[UNIQUEIDENTIFIER]  = 0x0,
	@AccGUID 			[UNIQUEIDENTIFIER]  = 0x0,
	@Lang				[INT] = 0,
	@MatCondGuid		[UNIQUEIDENTIFIER]  = 0x00,
	@CostGUID 			[UNIQUEIDENTIFIER] = 0x00,
	@SnStartWith		[NVARCHAR] (256) = ''	 		
AS
	SET NOCOUNT ON
	CREATE TABLE [#SecViol]( [Type] [INT], [Cnt] [INTEGER])
	CREATE TABLE [#CustTbl]( [CustGuid] [UNIQUEIDENTIFIER] , [Security] [INT])
	CREATE TABLE [#BillsTypesTbl]( [TypeGuid] [UNIQUEIDENTIFIER] , [UserSecurity] [INTEGER], [UserReadPriceSecurity] [INTEGER],[UnPostedSecurity] [INTEGER])
	CREATE TABLE [#MatTbl]( MatGuid [UNIQUEIDENTIFIER] , [mtSecurity] [INT])
	CREATE TABLE [#StoreTbl]( [StoreGuid] [UNIQUEIDENTIFIER] , [Security] [INT])
	CREATE TABLE [#SNGuidsTbl]( [Guid] [UNIQUEIDENTIFIER],[ParentGuid] [UNIQUEIDENTIFIER])
	CREATE TABLE [#CostTbl]( [CostGUID] [UNIQUEIDENTIFIER] , [Security] [INT])
		
	IF @NotesContain IS NULL
		SET @NotesContain = ''
	IF @NotesNotContain IS NULL
		SET @NotesNotContain = ''
	IF @SNName IS NULL
		SET @SNName = ''
	IF @SnStartWith IS NULL
		SET @SnStartWith = ''

	INSERT INTO [#CustTbl]		EXEC [prcGetCustsList] 		@CustGUID, @AccGUID
	INSERT INTO [#BillsTypesTbl]EXEC [prcGetBillsTypesList2]	@SrcTypesguid
	INSERT INTO [#MatTbl]		EXEC [prcGetMatsList] 		@MatGuid, @GroupGuid,-1,@MatCondGuid
	INSERT INTO [#StoreTbl]		EXEC [prcGetStoresList] 	@StoreGuid
	INSERT INTO [#CostTbl]		EXEC [prcGetCostsList] 		@CostGUID
	IF @CostGUID = 0X00
		INSERT INTO [#CostTbl] VALUES(0X00,0)
	SELECT [StoreGuid], [s].[Security],CASE @Lang WHEN 0 THEN [Name] ELSE CASE [LatinName] WHEN '' THEN [Name] ELSE [LatinName] END END AS [stName] INTO [#StoreTbl2] FROM [#StoreTbl] AS [s] INNER JOIN [st000] AS [st] ON [st].[Guid] = [StoreGuid]
	SELECT [CustGuid] , [c].[Security],CASE @Lang WHEN 0 THEN [CustomerName] ELSE CASE [LatinName] WHEN '' THEN [CustomerName] ELSE [LatinName] END END AS [buCust_Name] INTO [#CustTbl2] FROM [#CustTbl] AS [c] INNER JOIN [cu000] AS [cu] ON [cu].[Guid] = [c].[CustGuid]
	IF ((@CustGUID = 0X00) AND ( @AccGUID = 0X00))
		INSERT INTO [#CustTbl2] VALUES(0X00,0,'')
	
	IF( @SNName = '')
		INSERT INTO [#SNGuidsTbl]( [Guid],[ParentGuid]) 
			SELECT DISTINCT [biGUID],[ParentGuid] 
			From [snt000] [t] 
			INNER JOIN [snc000] [s] ON [s].[Guid] = [t].[ParentGuid] 
			WHERE @SnStartWith = '' OR [SN] LIKE  '' + @SnStartWith + '%'
	ELSE
	BEGIN
		INSERT INTO [#SNGuidsTbl]( [Guid],[ParentGuid]) 
			SELECT DISTINCT [biGUID],[ParentGuid] 
			From [snt000] [t] 
			INNER JOIN [snc000] [s] ON [s].[Guid] = [t].[ParentGuid] 
			WHERE [SN] = '' +  @SNName +''					
	END
	
	CREATE TABLE [#Res] (
			[biGuid]				[UNIQUEIDENTIFIER] 
	)

	CREATE TABLE [#Result]
	(
		[buType]				[UNIQUEIDENTIFIER] ,
		[buName]				[NVARCHAR] (100) COLLATE ARABIC_CI_AI,
		[buNumber]				[UNIQUEIDENTIFIER] ,
		[buNum]					[INT],
		[biNum]					[INT],
		[BuSortFlag]			[INT],
		[biGuid]				[UNIQUEIDENTIFIER] ,
		[biMatPtr]				[UNIQUEIDENTIFIER] ,
		[buIsPosted]			[INT],
		[biNotes]				[NVARCHAR] (256) COLLATE ARABIC_CI_AI,
		[biPrice]				[FLOAT],
		[buDisc]				[FLOAT],
		[buExtra]				[FLOAT],
		[biQty]					[FLOAT],
		[biCurrencyPtr]			[UNIQUEIDENTIFIER] ,
		[biCurrencyVal]			[FLOAT],
		[buDate]				[DateTime] ,
		[buNotes]				[NVARCHAR] (1000) COLLATE ARABIC_CI_AI,
		[buVendor]				[INT],
		[buSalesManPtr]			[INT],
		[biStorePtr]			[UNIQUEIDENTIFIER] ,
		[buCust_Name]			[NVARCHAR] (256) COLLATE ARABIC_CI_AI,
		[stName]				[NVARCHAR] (256) COLLATE ARABIC_CI_AI,
		[Security]				[INT],
		[UserSecurity] 			[INT],
		[UserReadPriceSecurity]	[INT],
		[grName]				[NVARCHAR] (256) COLLATE ARABIC_CI_AI
	)

	INSERT INTO [#Result]
	SELECT
		[bubi].[buType],
		[bubi].[btAbbrev],
		[bubi].[buGUID],
		[bubi].[buNumber],
		[bubi].[biNumber],
		[bubi].[BuSortFlag],
		[bubi].[biGuid],
		[bubi].[biMatPtr],
		[bubi].[buIsPosted],
		[bubi].[biNotes],
		[dbo].[fnCurrency_fix]((([bubi].[biPrice] * [bubi].[biQty]/([bubi].[biQty]+[bubi].[bibonusQnt])) + (([bubi].[biLCExtra] - [bubi].[biLCDisc])/([bubi].[biQty]+[bubi].[bibonusQnt]) ) + ((biTotalExtraPercent + biExtra - biTotalDiscountPercent - biDiscount - biBonusDisc) / ([bubi].[biQty]+[bubi].[bibonusQnt]))), 
		[bubi].[biCurrencyPtr], [bubi].[biCurrencyVal], @CurrencyGUID,[bubi].[buDate]),
		CASE buTotal 
			WHEN 0 THEN 0 
			ELSE [dbo].[fnCurrency_fix]((biUnitDiscount + ([bubi].[biLCDisc])/([bubi].[biQty]+[bubi].[bibonusQnt])) , [bubi].[biCurrencyPtr], [bubi].[biCurrencyVal], @CurrencyGUID, [bubi].[buDate]) 
		END,
		CASE buTotal 
			WHEN 0 THEN 0 
			ELSE [dbo].[fnCurrency_fix]((biUnitExtra+ ([bubi].[biLCExtra])/([bubi].[biQty]+[bubi].[bibonusQnt])), [bubi].[biCurrencyPtr], [bubi].[biCurrencyVal], @CurrencyGUID, [bubi].[buDate]) 
		END,
		[bubi].[biQty],
		[bubi].[biCurrencyPtr],
		[bubi].[biCurrencyVal],
		[bubi].[buDate],
		[bubi].[buNotes],
		[bubi].[buVendor],
		[bubi].[buSalesManPtr],
		[bubi].[biStorePtr],
		[cu].[buCust_Name],
		[st].[stName],
		[bubi].[BuSecurity],
		CASE [BuIsPosted] WHEN 1 THEN [bt].[UserSecurity] ELSE [UnPostedSecurity] END,
		[bt].[UserReadPriceSecurity],
		''
	FROM
		[vwExtended_bi] AS [buBi]
		INNER JOIN [#BillsTypesTbl] AS [bt] ON [bubi].[buType] = [bt].[TypeGuid]
		INNER JOIN [#MatTbl] AS [mtTbl] ON [bubi].[biMatPtr] = [mtTbl].[MatGuid]
		INNER JOIN (SELECT DISTINCT [guid] FROM [#SNGuidsTbl]) AS [g] ON [bubi].[biGuid] = [g].[guid]
		INNER JOIN [#CustTbl2] AS [cu] ON [buBi].[BuCustPtr] = [cu].[CustGUID]
		INNER JOIN  [#StoreTbl2] AS [st] ON  [st].[StoreGUID] = [BiStorePtr]
		INNER JOIN  [#CostTbl] AS [co] ON [co].[CostGUID] = [buBi].[biCostPtr]
	WHERE
		(CAST([bubi].[buDate] AS DATE) BETWEEN @StartDate AND @EndDate)
		AND( (@PostedValue = -1) 				OR ([BuIsPosted] = @PostedValue))
		AND( (@NotesContain = '')				OR ([BuNotes] LIKE '%'+ @NotesContain + '%') OR ( [BiNotes] LIKE '%' + @NotesContain + '%'))
		AND( (@NotesNotContain ='')				OR (([BuNotes] NOT LIKE '%' + @NotesNotContain + '%') AND ([BiNotes] NOT LIKE '%'+ @NotesNotContain + '%')))

	EXEC [prcCheckSecurity]

	CREATE CLUSTERED INDEX SNID ON #result([buDate],[buNum],[biNum],[BuSortFlag])

	IF (@ShowGroup = 1)
		UPDATE [r] SET [grName] = [gr].[grName]
		FROM [#Result] AS [r] INNER JOIN
		( 
			SELECT [mt].[Guid],CASE @Lang WHEN 0 THEN [grName] ELSE CASE [grLatinName] WHEN '' THEN [grName] ELSE [grLatinName] END END AS [grName] 
			FROM [mt000] AS [mt]
			INNER JOIN [vwGr] AS [gr1] ON [mt].[GroupGuid] = [gr1].[grGuid]
		) AS [gr] ON  [biMatPtr] = [gr].[guid]

----------- Main Result -----------------------------------------------------------------------
	SELECT
		[SN],
		[biGUID],
		[r].[buType],
		[r].[buName],
		[r].[buNumber],
		[r].[buNum],
		[r].[BuSortFlag],
		[r].[biGuid],
		[r].[buIsPosted],
		[r].[biNotes],
		CASE WHEN [r].[UserReadPriceSecurity] >= [r].[Security] THEN [r].[biPrice] ELSE 0 END AS [biPrice],
		CASE WHEN [r].[UserReadPriceSecurity] >= [r].[Security] THEN 1 ELSE 0 END * [buDisc]  AS [buDisc],
		CASE WHEN [r].[UserReadPriceSecurity] >= [r].[Security] THEN 1 ELSE 0 END * [buExtra] AS [buExtra],
		[r].[biQty],	
		[r].[biCurrencyPtr],
		[r].[biCurrencyVal],
		[r].[buDate],
		[r].[buNotes],
		[r].[buVendor],
		[r].[buSalesManPtr],
		[r].[buCust_Name],
		[r].[biMatPtr] AS [MatPtr],
		[mt].[MtDefUnitFact],
		[mt].[mtDefUnitName],
		[r].[grName],
		[r].[stName]
	FROM
		[SNC000] AS [SN] 
		INNER JOIN [#SNGuidsTbl] [snt] ON  [SN].[Guid] = [snt].[ParentGuid]
		INNER JOIN [#result] AS [r] ON [r].[biGUID] = [snt].[Guid]
		INNER JOIN [vwmt] AS [mt] ON [r].[biMatPtr] = [mt].[mtGUID]
	ORDER BY
		[r].[BuDate],
		[r].[BuSortFlag],
		[r].[BuNum],
		[r].[BiNum],
		LEN([SN]),
			[SN]

	SELECT * FROM [#SecViol]
------------------------------------------------------------------------------------------------

/*
prcConnections_add2 '„œÌ—'
exec   [SNMove] '7F7204007340', '1/1/2004', '4/5/2007', 1, '', '', '04b7552d-3d32-47db-b041-50119e80dd52', 1.000000, '9009370b-ae97-448c-9a15-1a64eaa12363', 0, '00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000000', 0, '00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000000',''
*/
###############################################################################
#END


