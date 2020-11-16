####################################
CREATE PROCEDURE repSnProfits
	@StartDate			[DATETIME],
	@EndDate			[DATETIME],
	@SrcTypesguid		[UNIQUEIDENTIFIER],
	@SN					[NVARCHAR](256),
	@CurrencyGUID 		[UNIQUEIDENTIFIER] ,
	@CurrencyVal 		[FLOAT],
	--------------- new
	@MatGuid 			[UNIQUEIDENTIFIER], -- 0 All Mat or MatNumber
	@GroupGuid 			[UNIQUEIDENTIFIER],
	@Vendor 			[FLOAT],
	@SalesMan 			[FLOAT],
	@CustGuid 			[UNIQUEIDENTIFIER], -- 0 all cust or one cust 
	@StoreGuid 			[UNIQUEIDENTIFIER], --0 all stores so don't check store or list of stores 
	@AccGuid			[UNIQUEIDENTIFIER],
	@Lang				[BIT] = 0,
	@MatCondGuid		[UNIQUEIDENTIFIER] = 0X00
AS
	SET NOCOUNT ON
	DECLARE @cnt INT
	CREATE TABLE [#SecViol]( [Type] [INT], [Cnt] [INTEGER])
	CREATE TABLE [#BillsTypesTbl]( [TypeGuid] [UNIQUEIDENTIFIER] , [UserSecurity] [INTEGER], [UserReadPriceSecurity] [INTEGER])
	CREATE TABLE [#MatTbl]( [MatGuid] [UNIQUEIDENTIFIER], [mtSecurity] [INT])
	CREATE TABLE [#StoreTbl](	[StoreGuid] [UNIQUEIDENTIFIER], [Security] [INT])
	CREATE TABLE [#CustTbl]( [CustGuid] [UNIQUEIDENTIFIER], [Security] [INT])
	 
	--Filling temporary tables 
	INSERT INTO [#MatTbl]			EXEC [prcGetMatsList] 		@MatGuid, @GroupGuid, -1,@MatCondGuid
	INSERT INTO [#BillsTypesTbl]EXEC [prcGetBillsTypesList]	@SrcTypesguid
	INSERT INTO [#StoreTbl]			EXEC [prcGetStoresList] 		@StoreGuid 
	INSERT INTO [#CustTbl]			EXEC [prcGetCustsList] 		@CustGuid, @AccGuid 
	IF @SN IS NULL
		SET @SN = ''
	SELECT [MatGuid],[m].[mtSecurity],CASE @Lang WHEN 0 THEN [Name] ELSE CASE [LatinName] WHEN '' THEN [Name] ELSE [LatinName] END END AS [mtName],[Code] AS [mtCode]
	INTO [#MatTbl2]
	FROM [#MatTbl] AS [m] INNER JOIN [mt000] AS [mt] ON [mt].[Guid] = [m].[MatGuid] WHERE [SnFlag] = 1
	
	--CREATE CLUSTERED INDEX [snpft] ON [#MatTbl2]([MatGuid])
	SELECT [CustGuid] ,[c].[Security],CASE @Lang WHEN 0 THEN [CustomerName] ELSE CASE [LatinName] WHEN '' THEN [CustomerName] ELSE [LatinName] END END AS [cuName]
	INTO [#CustTbl2]
	FROM [#CustTbl] AS [c] INNER JOIN [cu000] AS [cu] on [cu].[Guid] = [c].[CustGuid]
	
	IF ((@AccGuid = 0x00) AND (@CustGuid = 0x00))
		INSERT INTO [#CustTbl2] VALUES(0X00,0,'')
	CREATE TABLE #SN
	(
		[ID]					[INT] IDENTITY(1,1),
		[snGuid]				[UNIQUEIDENTIFIER],
		[biNumber]				[FLOAT],
		[SN]					[NVARCHAR] (256) COLLATE ARABIC_CI_AI,
		[price]					[FLOAT],
		[biGuid]				[UNIQUEIDENTIFIER],
		[buGuid]				[UNIQUEIDENTIFIER],
		[biNotes]				[NVARCHAR] (256) COLLATE ARABIC_CI_AI,
		[biMatPtr]				[UNIQUEIDENTIFIER] ,
		[biStorePtr]			[UNIQUEIDENTIFIER] ,
		[mtCode]				[NVARCHAR] (256) COLLATE ARABIC_CI_AI,
		[mtName]				[NVARCHAR] (256) COLLATE ARABIC_CI_AI,
		[mtSecurity]			[INT],
		[btDirection]			[INT]
	)
	CREATE TABLE #TRSN
	(
		[ID]					[INT],
		[inid]					[INT],
		[inbuGuid]				[UNIQUEIDENTIFIER] ,
		[InPrice]				[FLOAT]
	)
	INSERT INTO #sn ([SN],[price],[snGuid],[biGuid],[biNumber],[buGuid],[biNotes],[biMatPtr],[biStorePtr],[mtCode],[mtName],[mtSecurity],[btDirection])			
		SELECT [SN],[dbo].[fnCurrency_fix]((CASE biQty WHEN 0 THEN 0 ELSE
		(([Bi].[biPrice]*[Bi].[biQty])
		-(TotalDiscountPercent + biBonusDisc + biDiscount)
		+(TotalExtraPercent + biExtra))/[Bi].[biQty] END ) + (biLCExtra - biLCDisc)/(biQty + bi.biBonusQnt) , [Bi].[biCurrencyPtr], [Bi].[biCurrencyVal], @CurrencyGUID,[Bi].[buDate]), 
			[sn].[Guid],[Bi].[biGuid],[biNumber],[Bi].[buGuid],[biNotes],[biMatPtr],[biStorePtr],
			[mtTbl].[mtCode],
			[mtTbl].[mtName],[mtSecurity],[btDirection]
		FROM ([vcSNs] [sn] INNER JOIN [vwbubi][bi] ON [Bi].[biGuid] = [sn].[biGuid]
		INNER JOIN [#MatTbl2] AS [mtTbl] ON [sn].[MatGuid] = [mtTbl].[MatGuid]) 
		INNER JOIN [#StoreTbl] AS [st] ON [Bi].[BiStorePtr] = [StoreGuid]
		WHERE 
		(@SN = '' OR [sn].[SN] = '' + @SN + '')
		AND (([btDirection] = -1 AND [Bi].[buDate]  BETWEEN @StartDate AND @EndDate) OR [btDirection] = 1)
		AND( ([Bi].[BuVendor] = @Vendor) 			OR (@Vendor = 0 )) 
		AND( ([Bi].[BuSalesManPtr] = @SalesMan)	OR (@SalesMan = 0)) 
	ORDER BY [biMatPtr],[biStorePtr],[SN].[GUID],[Bi].[buDate],[btDirection] DESC,[buSortFlag],[buNumber],[biNumber]
	
	SELECT [out].[id],[out].[SN],[out].[price],[out].[biGuid],[out].[biNumber],[out].[buGuid],[out].[biNotes],[out].[biMatPtr],[out].[biStorePtr],[out].[mtCode],[out].[mtName],[out].[mtSecurity]
	,ISNULL([in].[price],0) AS [inPrice] ,ISNULL([in].[biGuid],0x00) AS [inbiGuid],ISNULL([in].[buGuid],0x00) AS [inbuGuid]
	INTO [#SNS]
	FROM [#sn] [out] LEFT JOIN [#sn] [in]  ON [in].[snGuid] = [out].[snGuid] AND [in].[biStorePtr] = [out].[biStorePtr] AND  [out].[id] = ([in].[id] + 1) 
	WHERE [OUT].[btDirection] = -1 AND ISNULL([in].[btDirection],1) = 1

	CREATE TABLE [#Result]
	(
		[buType]				[UNIQUEIDENTIFIER] ,
		[BillInGuid]			[UNIQUEIDENTIFIER] ,
		[BillOutGuid]			[UNIQUEIDENTIFIER] ,
		[buNumber]				[UNIQUEIDENTIFIER] ,
		[buNum]					[INT],
		[biNum]					[INT],
		[BuSortFlag]			[INT],
		[biGuid]				[UNIQUEIDENTIFIER] ,
		[biMatPtr]				[UNIQUEIDENTIFIER] ,
		[buFormatedNumber] 		[NVARCHAR] (256) COLLATE ARABIC_CI_AI,
		[buLatinFormatedNumber]	[NVARCHAR] (256) COLLATE ARABIC_CI_AI,
		[buIsPosted]			[INT],
		[biNotes]				[NVARCHAR] (256) COLLATE ARABIC_CI_AI,
		[InPrice]				[FLOAT],
		[OutPrice]				[FLOAT],
		[buCustPtr]				[UNIQUEIDENTIFIER] ,
		[buDate]				[DateTime] ,
		[buNotes]				[NVARCHAR] (1000) COLLATE ARABIC_CI_AI,
		[buVendor]				[INT],
		[buSalesManPtr]			[INT],
		[biStorePtr]			[UNIQUEIDENTIFIER] ,
		[buCust_Name]			[NVARCHAR] (256) COLLATE ARABIC_CI_AI,
		[mtCode]				[NVARCHAR] (256) COLLATE ARABIC_CI_AI,
		[mtName]				[NVARCHAR] (256) COLLATE ARABIC_CI_AI,
		[SN]					[NVARCHAR] (256) COLLATE ARABIC_CI_AI,
		[cuCustomerName]		[NVARCHAR] (256) COLLATE ARABIC_CI_AI,
		[Security]				[INT],
		[UserSecurity] 			[INT],
		[UserReadPriceSecurity]	[INT]
	)

	INSERT INTO [#Result]
	SELECT
		[OutbuBi].[buType],
		[sn].[inbuGuid],
		[OutbuBi].[buGUID],
		[OutbuBi].[buGUID],
		[OutbuBi].[buNumber],
		[sn].[biNumber],
		[OutbuBi].[BuSortFlag],
		[sn].[biGuid],
		[sn].[biMatPtr],
		[OutbuBi].[buFormatedNumber],
		[OutbuBi].[buLatinFormatedNumber],
		[OutbuBi].[buIsPosted],
		[sn].[biNotes],
		CASE WHEN [bt].[UserReadPriceSecurity] >= [OutbuBi].[BuSecurity] THEN 1 ELSE 0 END * [sn].[inPrice], 
		CASE WHEN [bt].[UserReadPriceSecurity] >= [OutbuBi].[BuSecurity] THEN 1 ELSE 0 END * [sn].[Price], 
		[OutbuBi].[buCustPtr],
		[OutbuBi].[buDate],
		[OutbuBi].[buNotes],
		[OutbuBi].[buVendor],
		[OutbuBi].[buSalesManPtr],
		[sn].[biStorePtr],
		[OutbuBi].[buCust_Name],
		[sn].[mtCode],
		[sn].[mtName],
		[sn].[SN],
		[cu].[cuName],
		[OutbuBi].[BuSecurity],
		[bt].[UserSecurity],
		[bt].[UserReadPriceSecurity]
	FROM
		(#SNS AS [sn] 
		
		INNER JOIN [vwbu] AS [OutbuBi] ON [OutbuBi].[buGUID] = [sn].[buGuid]  )
		INNER JOIN [#BillsTypesTbl] AS [bt] ON [OutbuBi].[buType] = [bt].[TypeGuid]
		INNER JOIN [#CustTbl2] AS [cu] ON [OutbuBi].[BuCustPtr] = [CustGuid]
	
	EXEC [prcCheckSecurity] 

	SELECT [r].[Sn], r.[biMatPtr], [r].[InPrice], [r].[OutPrice], [r].[BillInGuid], [r].[BillOutGuid] ,
			[r].[mtName],[r].[mtCode], [r].[buDate] , [r].[buFormatedNumber], [r].[buLatinFormatedNumber],
			[r].[cuCustomerName]
	FROM [#Result] AS [r] 
	ORDER BY [buDate],[BuSortFlag],[buNum]
	SELECT * From [#SecViol]

/*
	PRCConnections_add2 '„œÌ—'
	exec [repSnProfits] '8/28/2007', '11/6/2007', 'efb965a3-74a9-4ed8-bb73-438272a6bcc4', '', '04b7552d-3d32-47db-b041-50119e80dd52', 1.000000, 'b1ff8bdc-19d0-43e7-8c66-cda72a26e079', '00000000-0000-0000-0000-000000000000', 0, 0, '00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000000', 0, '00000000-0000-0000-0000-000000000000'
*/
#####################################
#END
