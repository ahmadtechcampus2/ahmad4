##############################################################################
CREATE PROCEDURE repDayMtGrandTotal
	@StartDate 				[DATETIME],
	@EndDate 				[DATETIME],
	@SrcTypesGUID			[UNIQUEIDENTIFIER],
	@MatGUID 				[UNIQUEIDENTIFIER], -- 0 All Mat or MatNumber
	@GroupGUID 				[UNIQUEIDENTIFIER],
	@PostedValue 			[INT], -- 0, 1 , -1
	@Vendor 				[FLOAT],
	@SalesMan 				[FLOAT],
	@NotesContain 			[NVARCHAR](256),
	@NotesNotContain 		[NVARCHAR](256),
	@CustGUID 				[UNIQUEIDENTIFIER],
	@StoreGUID 				[UNIQUEIDENTIFIER],
	@CostGUID 				[UNIQUEIDENTIFIER],
	@AccGUID 				[UNIQUEIDENTIFIER],
	@CurrencyGUID 			[UNIQUEIDENTIFIER],
	@CurrencyVal 			[FLOAT],
	@UseUnit 				[INT]
AS
SET NOCOUNT ON
--Creating temporary tables
CREATE TABLE [#SecViol]( [Type] [INT], [Cnt] [INTEGER]) 
CREATE TABLE [#MatTbl]( [MatGUID] [UNIQUEIDENTIFIER], [mtSecurity] [INT]) 
CREATE TABLE [#BillsTypesTbl]( [TypeGuid] [UNIQUEIDENTIFIER], [UserSecurity] [INTEGER], [UserReadPriceSecurity] [INTEGER]) 
CREATE TABLE [#StoreTbl]( [StoreGUID] [UNIQUEIDENTIFIER], [Security] [INT]) 
CREATE TABLE [#CostTbl]( [CostGUID] [UNIQUEIDENTIFIER], [Security] [INT]) 
CREATE TABLE [#CustTbl]( [CustGUID] [UNIQUEIDENTIFIER], [Security] [INT]) 
--Filling temporary tables 
INSERT INTO [#MatTbl]			EXEC [prcGetMatsList] 		@MatGUID, @GroupGUID 
INSERT INTO [#BillsTypesTbl]	EXEC [prcGetBillsTypesList] 	@SrcTypesguid--, @UserGuid 
INSERT INTO [#StoreTbl]			EXEC [prcGetStoresList] 		@StoreGUID 
INSERT INTO [#CostTbl]			EXEC [prcGetCostsList] 		@CostGUID 
INSERT INTO [#CustTbl]			EXEC [prcGetCustsList] 		@CustGUID, @AccGUID 
IF @NotesContain IS NULL 
	SET @NotesContain = '' 
IF @NotesNotContain IS NULL 
	SET @NotesNotContain = '' 
CREATE TABLE [#Result] 
( 
	[BuType]					[UNIQUEIDENTIFIER], 
	[btIsInput]				[INT], 
	[biQty]					[FLOAT], 
	[biQty2]					[FLOAT], 
	[biQty3]					[FLOAT], 
	[BiBonusQnt]				[FLOAT], 
	[BuPayType]				[INT], 
	[FixedBiPrice]			[FLOAT], 
	[MtUnitFact] 				[FLOAT], 
	[mtUnit2Fact]				[FLOAT],
	[mtUnit3Fact]				[FLOAT],
	[mtDefUnitFact] 			[FLOAT], 
	[FixedBuTotalDisc]		[FLOAT],	 
	[FixedBuItemsDisc]		[FLOAT], 
	[FixedBuTotal]			[FLOAT], 
	[FixedBuTotalExtra]		[FLOAT], 
	[FixedbiDiscount]			[FLOAT], 
	[Security]				[INT], 
	[UserSecurity] 			[INT], 
	[UserReadPriceSecurity]	[INT], 
	[MtSecurity]				[INT] 
) 
INSERT INTO [#Result] 
SELECT 
	[BuType], 
	[btIsInput], 
	[biQty], 
	[biQty2], 
	[biQty3], 
	[BiBonusQnt], 
	[BuPayType], 
	[FixedBiPrice],  
	[MtUnitFact], 
	[mtUnit2Fact], 
	[mtUnit3Fact], 
	[mtDefUnitFact], 
	[FixedBuTotalDisc],  
	[FixedBuItemsDisc],  
	[FixedBuTotal],  
	[FixedBuTotalExtra], 
	[FixedbiDiscount],  
	[buSecurity], 
	[bt].[UserSecurity], 
	[bt].[UserReadPriceSecurity], 
	[mtTbl].[MtSecurity] 
FROM 
	[dbo].[fnExtended_Bi_Fixed]( @CurrencyGUID) AS [rv] 
	INNER JOIN [#BillsTypesTbl] AS [bt] ON [rv].[buType] = [bt].[TypeGUID] 
	INNER JOIN [#MatTbl] AS [mtTbl] ON [rv].[biMatPtr] = [mtTbl].[MatGUID] 
WHERE 
	([rv].[Budate] BETWEEN @StartDate AND @EndDate) 
	AND( (@PostedValue = -1) 					OR ([rv].[BuIsPosted] = @PostedValue)) 
	AND( ([rv].[BuVendor] = @Vendor) 				OR (@Vendor = 0 )) 
	AND( ([rv].[BuSalesManPtr] = @SalesMan) 		OR (@SalesMan = 0)) 
	AND( (@NotesContain = '')					OR ([rv].[BuNotes] LIKE '%'+ @NotesContain + '%') OR ( [rv].[BiNotes] LIKE '%' + @NotesContain + '%')) 
	AND( (@NotesNotContain ='')					OR (([rv].[BuNotes] NOT LIKE '%' + @NotesNotContain + '%') AND ([rv].[BiNotes] NOT LIKE '%'+ @NotesNotContain + '%'))) 
	AND( (@StoreGUID = 0x0) 					OR ([rv].[BiStorePtr] IN( SELECT [StoreGUID] FROM [#StoreTbl]))) 
	AND( (@CostGUID = 0x0) 						OR ([rv].[BiCostPtr] IN( SELECT [CostGUID] FROM [#CostTbl]))) 
	AND( (@CustGUID = 0x0) 						OR ([rv].[BuCustPtr] IN ( SELECT [CustGUID] FROM [#CustTbl]))) 
	AND( (@AccGUID = 0x0) 						OR ([rv].[buCustAcc] = @AccGUID)	OR ([rv].[BuCustPtr] IN ( SELECT [CustGUID] FROM [#CustTbl]))) 
EXEC [prcCheckSecurity] 

SELECT 
	--rv.BuType, 
	--rv.btIsInput,
	SUM( [rv].[biQty] /(CASE @UseUnit	WHEN 1 THEN (CASE [mtUnit2Fact] 	WHEN 0 THEN 1 ELSE [mtUnit2Fact] END) 
													WHEN 2 THEN (CASE [mtUnit3Fact] 	WHEN 0 THEN 1 ELSE [mtUnit3Fact] END) 
													WHEN 3 THEN (CASE [mtDefUnitFact] WHEN 0 THEN 1 ELSE [mtDefUnitFact] END) 
													ELSE 1 END ))AS [SumQty],
	SUM([rv].[biQty2]) AS [SumQty2],
	SUM([rv].[biQty3]) AS [SumQty3],
	SUM([rv].[BiBonusQnt]/(CASE @UseUnit	WHEN 1 THEN (CASE [mtUnit2Fact] 	WHEN 0 THEN 1 ELSE [mtUnit2Fact] END) 
												WHEN 2 THEN (CASE [mtUnit3Fact] 	WHEN 0 THEN 1 ELSE [mtUnit3Fact] END) 
												WHEN 3 THEN (CASE [mtDefUnitFact] WHEN 0 THEN 1 ELSE [mtDefUnitFact] END) 
												ELSE 1 END )) AS [SumBonusQty],
	SUM(( CASE [BuPayType] WHEN 0 THEN [rv].[FixedBiPrice] * [rv].[BiQty] / [mtUnitFact] ELSE 0 END)) AS [SumCashPrice], 
	SUM(( CASE WHEN [BuPayType] >= 1 THEN [rv].[FixedBiPrice] * [rv].[BiQty] / [mtUnitFact] ELSE 0 END)) AS [SumCreditPrice], 
	SUM(( CASE [BuPayType] 
				WHEN 0 THEN ( [FixedBuTotalDisc] - [FixedBuItemsDisc]) * [FixedbiPrice] * [rv].[BiQty] / [MtUnitFact]/  (CASE [FixedBuTotal] WHEN 0 THEN 1 ELSE [FixedBuTotal] END) 
				ELSE 0 END)) AS [SumCashDisc], 
	SUM( ( CASE WHEN [BuPayType] >= 1 THEN ( [FixedBuTotalDisc] - [FixedBuItemsDisc]) * [FixedbiPrice] * [rv].[BiQty] / [MtUnitFact]/ (CASE [FixedBuTotal] WHEN 0 THEN 1 ELSE [FixedBuTotal] END) 
			ELSE 0	END)) AS [SumCreditDisc], 
	SUM( 	(CASE [BuPayType]  
				WHEN 0 THEN [FixedBuTotalExtra]*[FixedbiPrice] * [rv].[BiQty] / [mtUnitFact] / (CASE [FixedBuTotal] WHEN 0 THEN 1 ELSE [FixedBuTotal] END) 
				ELSE 0 END)) AS [SumCashExtra], 
	SUM( (CASE 
			WHEN [BuPayType] >= 1 THEN [FixedBuTotalExtra]* [FixedbiPrice] * [rv].[BiQty] / [mtUnitFact] / (CASE [FixedBuTotal] WHEN 0 THEN 1 ELSE [FixedBuTotal] END) 
			ELSE 0 END )) AS [SumCreditExtra], 
	SUM(  (CASE [BuPayType] 
			WHEN 0 THEN [FixedbiDiscount] ELSE 0 END)) AS [SumCashDiscVal], 
	SUM(  (CASE 
			WHEN [BuPayType] >= 1 THEN [FixedbiDiscount] ELSE 0 END)) AS [SumCreditDiscVal] 
FROM 
	[#Result] AS [rv] 
WHERE 
	[UserSecurity] >= [Security] 
--GROUP BY 
	--rv.BuType, 
	--rv.btIsInput 
SELECT *FROM [#SecViol] 
DROP TABLE [#Result] 
DROP TABLE [#SecViol] 
/* 
prcConnections_add2 '„œÌ—'
SELECT * FROM MY000
SELECT * FROM MT000
select biQty, FixedBiPrice,buFormatedNumber, mtName, [mtUnit2Fact], [mtUnit3Fact], [mtDefUnitFact] 
FROM fnExtended_Bi_Fixed( '69C9D1D5-A7D3-4E86-A410-ADA120F32C16')
ORDER BY buFormatedNumber
select *
FROM fnExtended_Bi_Fixed( '69C9D1D5-A7D3-4E86-A410-ADA120F32C16')

EXEC repDayMtGrandTotal
'1/1/2001'			--@StartDate [DATETIME], 
,'12/31/2001'		--@EndDate [DATETIME], 
,0x0				--@SrcTypes [VARCHAR](2000), 
,0x0 --@MatPtr [INT], -- 0 All Mat or MatNumber 
,0x0			--@GroupPtr [INT], 
,-1				--@PostedValue [INT], -- 0, 1 , -1 
,0				--@Vendor [FLOAT], 
,0				--@SalesMan [FLOAT], 
,''				--@NotesContain [VARCHAR](256), 
,''				--@NotesNotContain [VARCHAR](256), 
,0x0			--@CustPtr [INT], 
,0x0			--@StorePtr [INT], 
,0x0			--@CostPtr [INT], 
,0x0			--@Acc [INT], 
,0x0			--@CurrencyPtr [INT], 
,1				--@CurrencyVal FLOAT 
,1
*/ 

###############################################################################
#END
