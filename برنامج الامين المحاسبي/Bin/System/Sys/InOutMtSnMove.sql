##########################################################################
CREATE PROCEDURE repCallCalcInOutMtSnMove
	@StartDate 			[DATETIME], 
	@EndDate 			[DATETIME], 
	@SN					[NVARCHAR](255),
	@SrcTypesguid 		[UNIQUEIDENTIFIER], 
	@MatGUID 			[UNIQUEIDENTIFIER], -- 0 All Mat or MatNumber 
	@GroupGUID 			[UNIQUEIDENTIFIER], 
	@PostedValue 		[INT], 	-- 0, 1 , -1 
	@Vendor 			[FLOAT], 
	@SalesMan 			[FLOAT], 
	@NotesContain 		[NVARCHAR](256),-- NULL or Contain Text 
	@NotesNotContain 	[NVARCHAR](256), -- NULL or Not Contain 
	@CustGUID 			[UNIQUEIDENTIFIER], -- 0 all cust or one cust 
	@StoreGUID 			[UNIQUEIDENTIFIER], --0 all stores so don't check store or list of stores 
	@CostGUID 			[UNIQUEIDENTIFIER], -- 0 all costs so don't Check cost or list of costs 
	@CurrencyGUID 		[UNIQUEIDENTIFIER],
	@AccGUID 			[UNIQUEIDENTIFIER],  
	@MatType 			[INT],
	@Sort				[INT] = 0,--0 CODE 1 NAME 3 LATIN NAME
	@NotShowBalacedSn	[INT] = 0,
	@MatCond			[UNIQUEIDENTIFIER] = 0X00
AS 
	SET NOCOUNT ON 
	-- Creating temporary tables 
	CREATE TABLE [#SecViol]( [Type] [INT], [Cnt] [INTEGER]) 
	CREATE TABLE [#MatTbl]( [MatGUID] [UNIQUEIDENTIFIER], [mtSecurity] [INT]) 
	CREATE TABLE [#BillsTypesTbl]( [TypeGuid] [UNIQUEIDENTIFIER], [UserSecurity] [INTEGER], [UserReadPriceSecurity] [INTEGER], [UnpostedSecurity] [INTEGER]) 
	CREATE TABLE [#StoreTbl]([StoreGUID] [UNIQUEIDENTIFIER], [Security] [INT]) 
	CREATE TABLE [#CostTbl]( [CostGUID] [UNIQUEIDENTIFIER], [Security] [INT]) 
	CREATE TABLE [#CustTbl]( [CustGUID] [UNIQUEIDENTIFIER], [Security] [INT])
	-- Filling temporary tables
	INSERT INTO [#MatTbl]			EXEC [prcGetMatsList] 		@MatGUID, @GroupGUID, @MatType ,@MatCond
	INSERT INTO [#BillsTypesTbl]	EXEC [prcGetBillsTypesList2]	@SrcTypesguid 
	INSERT INTO [#StoreTbl]			EXEC [prcGetStoresList]		@StoreGUID 
	INSERT INTO [#CostTbl]			EXEC [prcGetCostsList] 		@CostGUID 
	INSERT INTO [#CustTbl]			EXEC [prcGetCustsList] 		@CustGUID, @AccGUID 
	
	IF (@CostGUID = 0X00)
		INSERT INTO [#CostTbl] VALUES(0X00,0)
	
	IF (@CustGUID = 0X00) AND (@AccGUID = 0X00)
		INSERT INTO [#CustTbl] VALUES(0X00,0)
	
	SELECT [MatGUID], [mtSecurity],[Unity] AS [mtDefUnitName] INTO  [#MatTbl2]
	FROM [#MatTbl] INNER JOIN [mt000] ON [Guid] = [MatGUID] WHERE [SnFlag] = 1
	
	CREATE CLUSTERED INDEX [stIndex] ON  [#StoreTbl]([StoreGUID])
	CREATE CLUSTERED INDEX [coIndex] ON  [#CostTbl]( [CostGUID])
	CREATE CLUSTERED INDEX [cuIndex] ON  [#CustTbl]([CustGUID])
	
	IF @NotesContain IS NULL 
		SET @NotesContain = '' 
	
	IF @NotesNotContain IS NULL 
		SET @NotesNotContain = '' 

	CREATE TABLE [#InOutResult] 
	( 
		[MtNumber]		[UNIQUEIDENTIFIER], 
		[MtName]		[NVARCHAR](255) COLLATE ARABIC_CI_AI, 
		[MtCode]		[NVARCHAR](255) COLLATE ARABIC_CI_AI, 
		[MtLatinName]	[NVARCHAR](255) COLLATE ARABIC_CI_AI, 
		[mtUnity]		[NVARCHAR](255) COLLATE ARABIC_CI_AI, 
		[SN]			[NVARCHAR](255) COLLATE ARABIC_CI_AI, 
		[SumInQty]		[FLOAT], 
		[SumOutQty]		[FLOAT], 
		[SumInPrice]	[FLOAT], 
		[SumInVat]		[FLOAT],
		[SumOutPrice]	[FLOAT],
		[SumOutVat]		[FLOAT],
		[SumInExtra]	[FLOAT], 
		[SumOutExtra]	[FLOAT], 
		[SumInDisc]		[FLOAT], 
		[SumOutDisc]	[FLOAT]
	)
	
	CREATE TABLE [#Result]
	( 
		[buType] 						[UNIQUEIDENTIFIER],
		[SN]							[NVARCHAR](255) COLLATE ARABIC_CI_AI,
		[PayType]						[INT], 
		[BiMatPtr]						[UNIQUEIDENTIFIER], 
		[btIsInput] 					[INT], 
		[biQty] 						[FLOAT], 
		[btIsOutput] 					[INT], 
		[FixedBiPrice]					[FLOAT], 
		[FixedBiVat]					[FLOAT], 
		[FixedBuTotalDisc] 				[FLOAT], 
		[FixedBuTotalExtra]				[FLOAT], 
		[Security]						[INT], 
		[UserSecurity] 					[INT], 
		[UserReadPriceSecurity]			[INT], 
		[MtSecurity]					[INT] 
	)
	
	CREATE TABLE [#SN]
	(
		[SN]		[NVARCHAR](255) COLLATE ARABIC_CI_AI,
		[Guid]		[UNIQUEIDENTIFIER]
	)

	INSERT INTO [#SN]
		SELECT [SN], [biGuid]
		FROM SNC000 a INNER JOIN SNT000 B ON B.ParentGuid = a.Guid
		WHERE ( (@SN = '') OR ([SN] = @SN) ) 
		
	CREATE CLUSTERED INDEX [snInd] ON [#SN]([Guid])

	INSERT INTO [#Result] 
	SELECT 
		[buType], 
		[sn].[SN], 
		CASE WHEN [buPayType] > 1 THEN 1 ELSE [buPayType] END,
		[BiMatPtr], 
		[btIsInput], 
		1, 
		[btIsOutput], 
		(CASE WHEN [bt].[UserReadPriceSecurity] >= [BuSecurity] THEN 1 ELSE 0 END * [FixedBiPrice] * [biQty] /([biQty] + [biBonusQnt])) + ((rv.[biLCExtra] - rv.[biLCDisc]) / ([biQty] + [biBonusQnt])),
		CASE WHEN [bt].[UserReadPriceSecurity] >= [BuSecurity] THEN 1 ELSE 0 END * [FixedBiVat]/([biQty] + [biBonusQnt]),  
		CASE WHEN [bt].[UserReadPriceSecurity] >= [BuSecurity] THEN 1 ELSE 0 END * [FixedCurrencyFactor] * (([biQty] * [BiPrice] * ([BuTotalDisc]  - [BuItemsDisc] - FixedDIDiscount)  / (CASE [BuTotal] WHEN 0 THEN 1 ELSE [BuTotal] END) + [biDiscount] + FixedTotalDiscountPercent) / ([biQty] + [biBonusQnt])), 
		CASE WHEN [bt].[UserReadPriceSecurity] >= [BuSecurity] THEN 1 ELSE 0 END * [FixedCurrencyFactor] * (([biQty] * [BiPrice] * ([BuTotalExtra] - [BuItemsExtra] - FixedDIExtra) / (CASE [BuTotal] WHEN 0 THEN 1 ELSE [BuTotal] END) + [biExtra] + FixedTotalExtraPercent ) / ([biQty] + [biBonusQnt])), 
		[BuSecurity], 
		CASE [buIsPosted] WHEN 1 THEN [bt].[UserSecurity] ELSE [UnpostedSecurity] END, 
		[bt].[UserReadPriceSecurity], 
		[mtTbl].[MtSecurity] 
	FROM 
		((([dbo].[fn_bubi_Fixed]( @CurrencyGUID) AS [rv]	
		INNER JOIN [#SN] AS [sn] ON  [sn].[GUID] = [rv].[biGUID] )
		INNER JOIN [#BillsTypesTbl] AS [bt] ON [rv].[buType] = [bt].[TypeGuid])
		INNER JOIN [#MatTbl2] AS [mtTbl] ON [rv].[biMatPtr] = [mtTbl].[MatGuid])
		INNER JOIN [#StoreTbl] AS [st] ON [rv].[BiStorePtr] = [st].[StoreGUID]
		INNER JOIN [#CostTbl] AS [co] ON [rv].[BiCostPtr] = [co].[CostGUID]
		INNER join [#CustTbl] AS [cu] ON [BuCustPtr] = [cu].[CustGUID]
	WHERE 
		([rv].[Budate] BETWEEN @StartDate AND @EndDate) 
		AND( (@PostedValue = -1) 				OR ([rv].[BuIsPosted] = @PostedValue)) 
		AND( ([BuVendor] = @Vendor)				OR (@Vendor = 0 )) 
		AND( ([BuSalesManPtr] = @SalesMan) 		OR (@SalesMan = 0)) 
		AND( (@NotesContain = '')				OR ([BuNotes] LIKE '%'+ @NotesContain + '%') OR ( [BiNotes] LIKE '%' + @NotesContain + '%')) 
		AND( (@NotesNotContain ='')				OR (([BuNotes] NOT LIKE '%' + @NotesNotContain + '%') AND ([BiNotes] NOT LIKE '%'+ @NotesNotContain + '%'))) 
	
	---check Security 
	EXEC [prcCheckSecurity] 
	--CREATE CLUSTERED INDEX [SNINOUT] ON #RESULT ([BiMatPtr],[SN])
	INSERT INTO [#InOutResult] 
	SELECT 
		[mt].[GUID] AS [MtGUID], 
		[mt].[Name] AS [MtName], 
		[mt].[Code] AS [MtCode], 
		[mt].[LatinName] AS [MtLatinName], 
		[mt].[Unity], 
		[vwbi].[SN],
		[vwbi].[SumInQty], 
		[vwbi].[SumOutQty], 
		[vwbi].[SumInPrice],
		[vwbi].[SumInVat],  
		[vwbi].[SumOutPrice], 
		[vwbi].[SumOutVat], 
		[vwbi].[SumInExtra], 
		[vwbi].[SumOutExtra], 
		[vwbi].[SumInDisc], 
		[vwbi].[SumOutDisc]
	FROM 
		[Mt000] As [mt] INNER JOIN 
		( 
		SELECT 
			[rv].[BiMatPtr],
			[rv].[SN],
			SUM( [rv].[btIsInput] * [rv].[biQty] ) AS [SumInQty] , 
			SUM( [rv].[btIsOutput] * [rv].[biQty] ) AS [SumOutQty], 
			SUM( [rv].[btIsInput] * [rv].[FixedBiPrice]) AS [SumInPrice], 
			SUM( [rv].[btIsInput] * [rv].[FixedBiVat]) AS [SumInVat],
			SUM( [rv].[btIsOutput] * [rv].[FixedBiPrice]) AS [SumOutPrice], 
			SUM( [rv].[btIsOutput] * [rv].[FixedBiVat]) AS [SumOutVat] ,
			SUM( [rv].[btIsInput] * [FixedBuTotalExtra]) AS [SumInExtra], 
			SUM( [rv].[btIsOutput] * [FixedBuTotalExtra] ) AS [SumOutExtra], 
			SUM( [rv].[btIsInput] * [FixedBuTotalDisc]) AS 	[SumInDisc],
			SUM( [rv].[btIsOutput] * [FixedBuTotalDisc]) AS [SumOutDisc]
		FROM 
			[#Result]	AS [rv] 
		WHERE 
			[UserSecurity] >= [Security] 
		GROUP BY 
			[rv].[BiMatPtr], 
			[rv].[SN]
	) AS [vwbi] ON 	[vwbi].[biMatPtr] = [mt].[Guid]
	WHERE @NotShowBalacedSn = 0 OR [SumInQty] <> [SumOutQty]
	
	IF (@Sort = 0)
		SELECT *  FROM [#InOutResult] 	ORDER BY  [MtCode] ,LEN([SN]),[SN] 
	ELSE IF (@Sort = 1)
		SELECT * FROM [#InOutResult] 	ORDER BY [MtName]  ,LEN([SN]),[SN] 
	ELSE 
		SELECT * FROM [#InOutResult] 	ORDER BY [MtLatinName]  ,LEN([SN]),[SN] 
	
	SELECT 
		[buType],
		[bt].[Name] AS [NAME],
		CASE  [bt].[LatinName] WHEN '' THEN [bt].[Name] ELSE [bt].[LatinName] END AS [LATINNAME] ,
		[PayType],	
		SUM( [rv].[biQty] )  AS [SumQty], 
		SUM( [rv].[FixedBiPrice] ) AS [SumPrice], 
		SUM( [rv].[FixedBiVat]) AS [SumVat],
		SUM( [FixedBuTotalExtra]) AS [SumExtra], 
		SUM( [FixedBuTotalDisc]) AS [SumDisc], 
		--SUM( [FixedbiDiscount]) AS [SumDiscVal],
		CASE [rv].[btIsInput] WHEN 0 THEN  -1 ELSE 1 END AS [DIR],
		0 AS [Cash],
		0 AS [Later]
	FROM 
		[#Result] AS [rv] INNER JOIN [bt000] AS [BT] ON [BT].[GUID] = [rv].[buType]
	WHERE 
		[UserSecurity] >= [Security]
	GROUP BY
		[bt].[Name],
		CASE  [bt].[LatinName] WHEN '' THEN [bt].[Name] ELSE [bt].[LatinName] END  ,
		[buType],
		[PayType],
		[rv].[btIsInput]
	ORDER BY
		[buType],
		[PayType]
		
	SELECT * FROM [#SecViol]
	
	SET NOCOUNT OFF
/*
prcConnections_Add2 '„œÌ—'
exec [repCallCalcInOutMtSnMove] '1/1/2004', '12/31/2004', '', '0545baec-8fda-4ecf-9179-1f06d80e3fed', '00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000000', 1, 0, 0, '', '', '00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000000', '04b7552d-3d32-47db-b041-50119e80dd52', '00000000-0000-0000-0000-000000000000', 257, 0, 0

*/
###############################################################################
#END

	