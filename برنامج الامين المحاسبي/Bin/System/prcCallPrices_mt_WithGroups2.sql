#####################################################
CREATE PROCEDURE prcCallPrices_mt_WithGroups2
	@StartDate 			[DATETIME],
	@EndDate 			[DATETIME],
	@MatGUID 			[UNIQUEIDENTIFIER],
	@GroupGUID 			[UNIQUEIDENTIFIER],
	@StoreGUID 			[UNIQUEIDENTIFIER],
	@CostGUID 			[UNIQUEIDENTIFIER],
	@MatType 			[INT],
	@CurrencyGUID 		[UNIQUEIDENTIFIER],
	@CurrencyVal 		[FLOAT],
	@DetailsStores 		[INT],
	@ShowEmpty 			[INT],
	@SrcTypesGUID		[UNIQUEIDENTIFIER],
	@PriceType 			[INT],
	@PricePolicy 		[INT],
	@SortType 			[INT] = 0, -- 0 NONE, 1 matCode, 2MatName, 3Store
	@ShowUnLinked 		[INT] = 0,
	@AccGUID 			[UNIQUEIDENTIFIER] = 0x0,-- 0 all acounts or one cust when @ForCustomer not 0 or AccNumber 
	@CustGUID 			[UNIQUEIDENTIFIER] = 0x0, -- 0 all custs or group of custs when @ForAccount not 0 or CustNumber 
	@ShowGroups 		[INT] = 0, -- if 1 add 3 new columns for groups
	@CalcPrices 		[INT] = 1,
	@UseUnit 			[INT]
AS
--SET NOCOUNT ON
CREATE TABLE [#MainResult] (
	[StorePtr]		[UNIQUEIDENTIFIER],
	[MtNumber]		[UNIQUEIDENTIFIER],
	[Qnt]			[FLOAT] DEFAULT 0,
	[Qnt2]			[FLOAT] DEFAULT 0,
	[Qnt3]			[FLOAT] DEFAULT 0,
	[APrice]		[FLOAT] DEFAULT 0,
	[mtUnity]		[NVARCHAR](255) COLLATE ARABIC_CI_AI,
	[mtUnit2]		[NVARCHAR](255) COLLATE ARABIC_CI_AI,
	[mtUnit3]		[NVARCHAR](255) COLLATE ARABIC_CI_AI,
	[mtDefUnitFact]	[FLOAT],
	[grName]		[NVARCHAR](255) COLLATE ARABIC_CI_AI,
	[mtName]		[NVARCHAR](255) COLLATE ARABIC_CI_AI,
	[mtCode]		[NVARCHAR](255) COLLATE ARABIC_CI_AI,
	[mtLatinName]	[NVARCHAR](255) COLLATE ARABIC_CI_AI,
	[mtUnit2Fact]	[FLOAT],
	[mtUnit3Fact]	[FLOAT],
	[mtBarCode]		[NVARCHAR](500) COLLATE ARABIC_CI_AI,
	[mtSpec]		[NVARCHAR](255) COLLATE ARABIC_CI_AI,
	[mtDim]			[NVARCHAR](255) COLLATE ARABIC_CI_AI,
	[mtOrigin]		[NVARCHAR](255) COLLATE ARABIC_CI_AI,
	[mtPos]			[NVARCHAR](255) COLLATE ARABIC_CI_AI,
	[mtCompany]		[NVARCHAR](255) COLLATE ARABIC_CI_AI,

	[mtColor]		[NVARCHAR](255) COLLATE ARABIC_CI_AI,
	[mtProvenance]	[NVARCHAR](255) COLLATE ARABIC_CI_AI,
	[mtQuality]		[NVARCHAR](255) COLLATE ARABIC_CI_AI,
	[mtModel]		[NVARCHAR](255) COLLATE ARABIC_CI_AI,

	[mtBarCode2]	[NVARCHAR](500) COLLATE ARABIC_CI_AI,
	[mtBarCode3]	[NVARCHAR](500) COLLATE ARABIC_CI_AI,

	[mtType]		[INT],
	[mtDefUnitName]	[NVARCHAR](255) COLLATE ARABIC_CI_AI,
	
	[MtGroup]		[UNIQUEIDENTIFIER],
	[GroupParentPtr][UNIQUEIDENTIFIER],
	
	[RecType] 		[NVARCHAR](1) COLLATE ARABIC_CI_AI DEFAULT 'm' NOT NULL,
	[Level] 		[INT] DEFAULT 0 NOT NULL,
	[STName] 		[NVARCHAR](255) COLLATE ARABIC_CI_AI
	)

	INSERT INTO [#MainResult]	EXEC [prcPreparePricesProc] @StartDate, @EndDate, @MatGUID, @GroupGUID, @StoreGUID, @CostGUID, @MatType, @CurrencyGUID, @CurrencyVal, @DetailsStores, @ShowEmpty, @SrcTypesGUID, @PriceType, @PricePolicy, @SortType, @ShowUnLinked, @ShowGroups, @UseUnit

	DECLARE @Level [INT] 
	SET @Level = 0 
	-- start looping: 

	WHILE 1 = 1
	BEGIN
		-- Inc level
		SET @Level = @Level + 1
		-- insert heigher generation:
		INSERT INTO [#MainResult] SELECT
			0x0,--StorePtr,
			[grGUID],--MtNumber,
			0,--Qnt	,
			0,--Qnt2
			0,--Qnt3
			0,--APrice,
			'',--mtUnity,
			'',--mtUnit2,
			'',--mtUnit3,
			1,--mtDefUnitFact,
			[grName],
			[grName],--mtName,
			[grCode],
			[grLatinName],--mtLatinName,
			1,--mtUnit2Fact,
			1,--mtUnit3Fact,
			'',--mtBarCode,
			'',--mtSpec,
			'',--mtDim,
			'',--mtOrigin,
			'',--mtPos,
			'',--mtCompany,

			'',--mtColor
			'',--mtProvenance
			'',--mtQuality
			'',--mtModel
			
			'',--mtBarCode2
			'',--mtBarCode3
			0,--mtType,
			'',--mtDefUnitName,
			[grParent],--MtGroup
			[grParent],--GroupParentPtr,-- INT DEFAULT 0,
			'g',--RecType ,--CHAR(1) DEFAULT 'm' NOT NULL,
			@Level, --INT DEFAULT 0 NOT NULL
			''
		FROM
			[vwGr]
		WHERE [grGUID] IN (SELECT [MtGroup] FROM [#MainResult] AS [r] WHERE [r].[Level] = @Level - 1)
			AND [grGUID] IN (SELECT * FROM [dbo].[fnGetGroupsOfGroup]( @GroupGUID))

		IF @@ROWCOUNT = 0
			BREAK
		-- update the Sums of the fresh generation:
		UPDATE [#MainResult] SET
			[Qnt] = (SELECT Sum([son].[Qnt] / CASE @UseUnit WHEN 0 THEN 1
													  WHEN 1 THEN CASE [mtUnit2Fact] WHEN 0 THEN 1 ELSE [mtUnit2Fact] END
													  WHEN 2 THEN CASE [mtUnit3Fact] WHEN 0 THEN 1 ELSE [mtUnit3Fact] END
													  WHEN 3 THEN CASE [mtDefUnitFact] WHEN 0 THEN 1 ELSE [mtDefUnitFact] END
										END ) FROM [#MainResult] AS [Son] WHERE [Son].[MtGroup] = [Father].[MtNumber]),
			[Qnt2] = (SELECT Sum([son].[Qnt2] / CASE @UseUnit WHEN 0 THEN 1
														WHEN 1 THEN CASE [mtUnit2Fact] WHEN 0 THEN 1 ELSE [mtUnit2Fact] END
														WHEN 2 THEN CASE [mtUnit3Fact] WHEN 0 THEN 1 ELSE [mtUnit3Fact] END
														WHEN 3 THEN CASE [mtDefUnitFact] WHEN 0 THEN 1 ELSE [mtDefUnitFact] END
										END) FROM [#MainResult] AS [Son] WHERE [Son].[MtGroup] = [Father].[MtNumber]), 
			[Qnt3] = (SELECT Sum([son].[Qnt3] / CASE @UseUnit WHEN 0 THEN 1
														WHEN 1 THEN CASE [mtUnit2Fact] WHEN 0 THEN 1 ELSE [mtUnit2Fact] END
														WHEN 2 THEN CASE [mtUnit3Fact] WHEN 0 THEN 1 ELSE [mtUnit3Fact] END
														WHEN 3 THEN CASE [mtDefUnitFact] WHEN 0 THEN 1 ELSE [mtDefUnitFact] END
										END) FROM [#MainResult] AS [Son] WHERE [Son].[MtGroup] = [Father].[MtNumber]), 
			--if rec is mat so aprice = sum(Qnt * Price) else if it's a group so aprice = sum(price)
			[APrice] = (SELECT Sum(CASE [son].[RecType] WHEN 'm' THEN [son].[APrice] * [son].[Qnt]	ELSE [son].[APrice]  END) FROM [#MainResult] AS [Son] WHERE [Son].[MtGroup] = [Father].[MtNumber])--,
			-- To Add Sum Qnt2, Qnt3 if there is UnLinkedUnits
			--CurCardDebit = (SELECT Sum(son.CurCardDebit) FROM @t AS Son WHERE Son.Parent = Father.Account), 
			--CurCardCredit = (SELECT Sum(son.CurCardCredit) FROM @t AS Son WHERE Son.Parent = Father.Account) 
		FROM 
			[#MainResult] AS [Father]
		WHERE
			[Level] = @Level AND [Father].[RecType] = 'g'

		DELETE FROM [#MainResult] WHERE
			[Level] < @Level AND [MtNumber] IN (SELECT [MtNumber] FROM [#MainResult] AS [t] WHERE [t].[Level] = @Level) AND [RecType] = 'g'

	END
---
--- Update price of groups to single price
	--UPDATE #MainResult SET APrice = (APrice / (CASE Qnt WHEN 0 THEN 1 ELSE Qnt END)) WHERE RecType = 'g'
-- return result to caller:
	IF @ShowGroups = 2	-- groups Only
		DELETE FROM [#MainResult] WHERE [RecType] = 'm'
	SELECT * FROM [#MainResult]
-- drop  temprorary Result table
DROP TABLE [#MainResult]

/*
select * from us000
prcConnections_add 'C5168252-2F02-4514-B542-19DB4B6A238C'

EXEC prcCallPricesProcs2
'1/1/2002', 	--@StartDate
'11/30/2005', 	--@EndDate
0x0,			--@MatGUID
0x0, 			--@GroupGUID
0x0, 			--@StoreGUID
0x0, 			--@CostGUID
0, 				--@MatType
0x0, 			--@CurrencyGUID
1.000000,		--@CurrencyVal
1,				--@DetailsStores
0, 				--@ShowEmpty
0x0,			--@SrcTypesguid
128, 			--@PriceType
120, 			--@PricePolicy
0, 				--@SortType
0, 				--@ShowUnLinked
0x0, 			--@AccGUID
0x0, 			--@CustGUID
1, 				--@ShowGroups
1, 				--@CalcPrices
3
*/
/*

EXEC prcCallPricesProcs2 '4/1/2003', '4/14/2003', 0x0, 0x0, 0x0, 0x0, 0, '0aec4cc5-f365-41b2-87ba-5ea369569ad2', 1.000000, 1, 0, 0x0, 2, 121, 1, 0, 0x0, 0x0, 1, 1, 3

SELECT *FROM gr000

*/
########################################################
#END