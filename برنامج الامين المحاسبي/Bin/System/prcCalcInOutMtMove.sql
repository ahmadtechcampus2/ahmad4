################################################################
CREATE PROCEDURE prcCalcInOutMtMove
	@StartDate 			[DATETIME], 
	@EndDate 			[DATETIME], 
	@SrcTypesguid		[UNIQUEIDENTIFIER], 
	@MatGUID 			[UNIQUEIDENTIFIER], -- 0 All Mat or MatNumber 
	@GroupGUID 			[UNIQUEIDENTIFIER], 
	@PostedValue 		[INT], -- 0, 1 , -1 
	@Vendor 			[FLOAT], 
	@SalesMan 			[FLOAT], 
	@NotesContain 		[NVARCHAR](256),-- NULL or Contain Text 
	@NotesNotContain 	[NVARCHAR](256), -- NULL or Not Contain 
	@CustGUID 			[UNIQUEIDENTIFIER], -- 0 all cust or one cust 
	@StoreGUID 			[UNIQUEIDENTIFIER], --0 all stores so don't check store or list of stores 
	@CostGUID 			[UNIQUEIDENTIFIER], -- 0 all costs so don't Check cost or list of costs 
	@AccGUID 			[UNIQUEIDENTIFIER], 
	@CurrencyGUID 		[UNIQUEIDENTIFIER], 
	@CurrencyVal 		[FLOAT], 
	@MatType 			[INT], -- 0 MatStore or 1 MAtService or -1 ALL Mats Types 
	@UseUnit 			[INT] 
AS 
---------------------------------------- 
	SET NOCOUNT ON 
	CREATE TABLE [#Result] 
	( 
		
		[BiMatPtr]							[UNIQUEIDENTIFIER], 
		[btIsInput] 						[INT], 
		[biQty] 							[FLOAT], 
		[mtDefUnitName]						[NVARCHAR](255) COLLATE ARABIC_CI_AI,
		[mtUnit2Fact]						[FLOAT],  
		[mtUnit3Fact]						[FLOAT], 
		[mtDefUnitFact]						[FLOAT], 
		[btIsOutput] 						[INT], 
		[biBonusQnt] 						[FLOAT], 
		[biQty2]							[FLOAT], 
		[biQty3]							[FLOAT], 
		[FixedBiPrice]						[FLOAT], 
		[FixedBiVat]						[FLOAT], 
		[MtUnitFact]						[FLOAT], 
		[FixedBuTotalExtra]					[FLOAT], 
		[FixedBuTotalDisc] 					[FLOAT], 
		[Security]							[INT], 
		[UserSecurity] 						[INT], 
		[UserReadPriceSecurity]				[INT], 
		[MtSecurity]						[INT],
		[FixedBiTotalPrice]					[FLOAT],
		[Sumcurcost]						[FLOAT]	
	) 
	INSERT INTO [#Result]
	SELECT 
	
		[BiMatPtr], 
		[rv].[btIsInput], 
		SUM([biQty]),
		[mtDefUnitName], 
		[mtUnit2Fact], 
		[mtUnit3Fact], 
		[mtDefUnitFact], 
		[rv].[btIsOutput], 
		SUM([biBonusQnt]), 
		SUM([biCalculatedQty2]), 
		SUM([biCalculatedQty3]), 
		CASE WHEN [UserReadPriceSecurity] >= [buSecurity] THEN 1 ELSE 0 END * SUM( ( ( [FixedBiPrice] * [rv].[biQty] ) + ( [FixedBiLCExtra] - [FixedBiLCDisc ] ) ) / [MtUnitFact] ),
		CASE WHEN [UserReadPriceSecurity] >= [buSecurity] THEN 1 ELSE 0 END * SUM( [FixedBiVat] ),  
		[MtUnitFact], 
		CASE WHEN [UserReadPriceSecurity] >= [buSecurity] THEN 1 ELSE 0 END * SUM( ( ( [FixedBuTotalExtra] - [FixedbuItemExtra] ) * [FixedBiPrice] * [rv].[biQty] / [MtUnitFact] ) / CASE [FixedBuTotal] WHEN 0 THEN 1 ELSE [FixedBuTotal] END + [FixedbiExtra]    ), 
		CASE WHEN [UserReadPriceSecurity] >= [buSecurity] THEN 1 ELSE 0 END * SUM( ( ( [FixedBuTotalDisc] - [FixedBuItemsDisc]  ) * [FixedBiPrice] * [rv].[biQty] / [MtUnitFact] ) / CASE [FixedBuTotal] WHEN 0 THEN 1 ELSE [FixedBuTotal] END + [FixedbiDiscount] ),  
		[BuSecurity], 
		CASE [rv].[buIsPosted] WHEN 1 THEN [bt].[UserSecurity] ELSE [bt].[UnPostedSecurity] END, 
		[bt].[UserReadPriceSecurity], 
		[mtTbl].[MtSecurity],
		CASE WHEN [UserReadPriceSecurity] >= [buSecurity] THEN 1 ELSE 0 END * SUM( [FixedBiTotal] + [FixedBiLCExtra] - [FixedBiLCDisc] ),
		CASE WHEN [UserReadPriceSecurity] >= [buSecurity] THEN 1 ELSE 0 END * CASE SUM([biQty]*[rv].[btIsOutput] ) WHEN 0 THEN 0 ELSE SUM((([biUnitCostPrice]*([biQty]+biBonusQnt))*[rv].[btIsOutput]))/SUM(([biQty]+biBonusQnt)*[rv].[btIsOutput] ) END
	FROM 
		[dbo].[fnExtended_Bi_Fixed]( @CurrencyGUID) AS [rv]  
		INNER JOIN [#BillsTypesTbl] AS [bt] ON [rv].[buType] = [bt].[TypeGuid] 
		INNER JOIN vwbt AS bt2 ON [bt2].[btGUID] = [bt].[TypeGUID] 
		INNER JOIN [#MatTbl] AS [mtTbl] ON [rv].[biMatPtr] = [mtTbl].[MatGuid] 
	WHERE 
		([rv].[Budate] BETWEEN @StartDate AND @EndDate) 
		AND( (@PostedValue = -1) 				OR ([rv].[BuIsPosted] = @PostedValue)) 
		AND( (@MatType = -1) 					OR ([mtType] = @MatType)) 
		AND( (BuVendor = @Vendor) 				OR (@Vendor = 0 )) 
		AND( (BuSalesManPtr = @SalesMan) 		OR (@SalesMan = 0)) 
		AND( (@NotesContain = '')				OR ([BuNotes] LIKE '%'+ @NotesContain + '%') OR ( [BiNotes] LIKE '%' + @NotesContain + '%')) 
		AND( (@NotesNotContain ='')				OR (([BuNotes] NOT LIKE '%' + @NotesNotContain + '%') AND ([BiNotes] NOT LIKE '%'+ @NotesNotContain + '%'))) 
		AND( (@StoreGUID = 0x0) 				OR ([BiStorePtr] IN( SELECT [StoreGUID] FROM [#StoreTbl]))) 
		AND( (@CostGUID = 0x0) 					OR ([BiCostPtr] IN( SELECT [CostGUID] FROM [#CostTbl]))) 
		AND( (@CustGUID = 0x0) 					OR ([BuCustPtr] IN ( SELECT [CustGUID] FROM [#CustTbl]))) 
		AND( (@AccGUID = 0x0) 					OR ([buCustAcc] = @AccGUID) OR ([BuCustPtr] IN ( SELECT [CustGUID] FROM [#CustTbl]))) 
		AND ([bt2].[btSortNum] <> 0)
	GROUP BY 
		[BiMatPtr], 
		[rv].[btIsInput], 
		[mtDefUnitName], 
		[mtUnit2Fact], 
		[mtUnit3Fact], 
		[mtDefUnitFact], 
		[rv].[btIsOutput], 
		[MtUnitFact], 
		[BuSecurity], 
		CASE [buIsPosted] WHEN 1 THEN [bt].[UserSecurity] ELSE [bt].[UnPostedSecurity] END, 
		[bt].[UserReadPriceSecurity], 
		[mtTbl].[MtSecurity] 
	
	
	---check Security 
	EXEC [prcCheckSecurity] 

	-- return result set 
	INSERT INTO [#InOutResult] 
	SELECT 
		[vmt].[MtGUID], 
		[vmt].[MtName], 
		[vmt].[MtCode], 
		[vmt].[MtLatinName], 
		[vmt].[MtUnity],
		[vmt].[mtUnit2], 
		[vmt].[mtUnit3], 
		[vwbi].[mtDefUnitName], 
		[vwbi].[SumInQty], 
		[vwbi].[SumOutQty], 
		[vwbi].[SumInQty2], 
		[vwbi].[SumOutQty2], 
		[vwbi].[SumInQty3], 
		[vwbi].[SumOutQty3], 
		[vwbi].[SumInBonusQty], 
		[vwbi].[SumOutBonusQty], 
		[vwbi].[SumInPrice],
		[vwbi].[SumInVat],  
		[vwbi].[SumOutPrice], 
		[vwbi].[SumOutVat], 
		[vwbi].[SumInExtra], 
		[vwbi].[SumOutExtra], 
		[vwbi].[SumInDisc], 
		[vwbi].[SumOutDisc], 
		0, 
		0,
		[InFixedBiTotalPrice],
		[OutFixedBiTotalPrice],
		[vwbi].[Sumcurcost]
	FROM 
		[VwMt] As [vmt] INNER JOIN 
		( 
	SELECT 
			[rv].[mtDefUnitName], 
			[rv].[BiMatPtr], 
			CASE @UseUnit 	WHEN 0 THEN SUM( [rv].[btIsInput] * [rv].[biQty] )--unit 1 
							WHEN 1 THEN	SUM( [rv].[btIsInput] * [rv].[biQty] / (CASE [mtUnit2Fact] WHEN 0 THEN 1 ELSE [mtUnit2Fact] END)) 
							WHEN 2 THEN SUM( [rv].[btIsInput] * [rv].[biQty] / (CASE [mtUnit3Fact] WHEN 0 THEN 1 ELSE [mtUnit3Fact] END)) 
							WHEN 3 THEN SUM( [rv].[btIsInput] * [rv].[biQty] / (CASE [mtDefUnitFact] WHEN 0 THEN 1 ELSE [mtDefUnitFact] END)) 
			END AS [SumInQty], 
			CASE @UseUnit 	WHEN 0 THEN	SUM( [rv].[btIsOutput] * [rv].[biQty] ) 
							WHEN 1 THEN SUM( [rv].[btIsOutput] * [rv].[biQty] / (CASE [mtUnit2Fact] WHEN 0 THEN 1 ELSE [mtUnit2Fact] END)) 
							WHEN 2 THEN SUM( [rv].[btIsOutput] * [rv].[biQty] / (CASE [mtUnit3Fact] WHEN 0 THEN 1 ELSE [mtUnit3Fact] END)) 
							WHEN 3 THEN SUM( [rv].[btIsOutput] * [rv].[biQty] / (CASE [mtDefUnitFact] WHEN 0 THEN 1 ELSE [mtDefUnitFact] END)) 
			END AS [SumOutQty], 
			CASE @UseUnit 	WHEN 0 THEN	SUM( [rv].[btIsInput] * [rv].[biBonusQnt] ) 
							WHEN 1 THEN SUM( [rv].[btIsInput] * [rv].[biBonusQnt] / (CASE [mtUnit2Fact] WHEN 0 THEN 1 ELSE [mtUnit2Fact] END)) 
							WHEN 2 THEN SUM( [rv].[btIsInput] * [rv].[biBonusQnt] / (CASE [mtUnit3Fact] WHEN 0 THEN 1 ELSE [mtUnit3Fact] END)) 
							WHEN 3 THEN SUM( [rv].[btIsInput] * [rv].[biBonusQnt] / (CASE [mtDefUnitFact] WHEN 0 THEN 1 ELSE [mtDefUnitFact] END)) 
			END AS [SumInBonusQty], 
			CASE @UseUnit 	WHEN 0 THEN SUM( [rv].[btIsOutput] * [rv].[biBonusQnt] ) 
							WHEN 1 THEN SUM( [rv].[btIsOutput] * [rv].[biBonusQnt] / (CASE [mtUnit2Fact] WHEN 0 THEN 1 ELSE [mtUnit2Fact] END))   
							WHEN 2 THEN SUM( [rv].[btIsOutput] * [rv].[biBonusQnt] / (CASE [mtUnit3Fact] WHEN 0 THEN 1 ELSE [mtUnit3Fact] END)) 
							WHEN 3 THEN SUM( [rv].[btIsOutput] * [rv].[biBonusQnt] / (CASE [mtDefUnitFact] WHEN 0 THEN 1 ELSE [mtDefUnitFact] END)) 
			END AS [SumOutBonusQty], 
			SUM( [rv].[btIsInput] * [rv].[biQty2])AS [SumInQty2], 
			SUM( [rv].[btIsOutput] * [rv].[biQty2])AS [SumOutQty2], 
			SUM( [rv].[btIsInput] * [rv].[biQty3])AS [SumInQty3], 
			SUM( [rv].[btIsOutput] * [rv].[biQty3])AS [SumOutQty3], 
			SUM( [rv].[btIsInput] * [rv].[FixedBiPrice]) AS [SumInPrice], 
			SUM( [rv].[btIsInput] * [rv].[FixedBiVat]) AS [SumInVat],
			SUM( [rv].[btIsOutput] * [rv].[FixedBiPrice]) AS [SumOutPrice], 
			SUM( [rv].[btIsOutput] * [rv].[FixedBiVat]) AS SumOutVat,
			SUM( [rv].[btIsInput] * [FixedBuTotalExtra]) AS [SumInExtra], 
			SUM( [rv].[btIsOutput] * [FixedBuTotalExtra] ) AS [SumOutExtra], 
			SUM( [rv].[btIsInput] * [FixedBuTotalDisc]) AS [SumInDisc], 
			SUM( [rv].[btIsOutput] * [FixedBuTotalDisc]) AS [SumOutDisc],
			SUM( [rv].[btIsInput] * [FixedBiTotalPrice]) AS [InFixedBiTotalPrice], 
			SUM( [rv].[btIsOutput] * [FixedBiTotalPrice]) AS [OutFixedBiTotalPrice],
			CASE  SUM( [rv].[btIsOutput] * [rv].[biQty]) WHEN 0 THEN 0 ELSE SUM([rv].[Sumcurcost] *  [rv].[btIsOutput] * ([rv].[biQty] + [rv].biBonusQnt ))/ SUM( [rv].[btIsOutput] * ([rv].[biQty]+ [rv].biBonusQnt)) END AS [Sumcurcost]
		FROM 
			[#Result]	AS [rv] 
		WHERE 
			[UserSecurity] >= [Security] 
	GROUP BY 
		[rv].[BiMatPtr], 
		[rv].[mtDefUnitName]) AS [vwbi] ON 
		[vwbi].[biMatPtr] = [vmt].[MtGuid] 
--order by 
--DROP TABLE #Result 
/* 
prcConnections_add2 '„œÌ—' 
exec [prcCallVrtInvPricesProcs] '1/1/2004', '12/31/2004', '12/31/2003', '12/31/2003', '00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000000', 0, '04b7552d-3d32-47db-b041-50119e80dd52', 1.000000, 0, 0, 'f915a959-e375-4d06-ba14-ee6f315ffee8', 128, 120, 1, 0, '00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000000', 0, 1, 0, 3, -842150401, 0
*/ 
#########################################################
#END