################################
CREATE PROCEDURE prcPrepareCalcMatSalesAvg
	-- @SrcTypesGUID	UNIQUEIDENTIFIER,
	@MatGUID 		[UNIQUEIDENTIFIER],
	@PeriodGUID		[UNIQUEIDENTIFIER],
	-- @GroupGUID 	UNIQUEIDENTIFIER,
	@CustGUID 		[UNIQUEIDENTIFIER],
	-- @StoreGUID 	UNIQUEIDENTIFIER,
	-- @CostGUID 	UNIQUEIDENTIFIER,
	@AccGUID 		[UNIQUEIDENTIFIER],
	@UseUnit		[INT],
	@IsGroupByCust	[BIT] = 0
AS
BEGIN
	SET NOCOUNT ON

	DECLARE @SD [DATETIME]
	SELECT @SD = [StartDate] FROM [vwPeriods] WHERE [GUID] = @PeriodGUID

	DECLARE @StartDate 		[DATETIME]
	DECLARE @EndDate 		[DATETIME]

	-- Õ”«» „Ã«· 6 √‘Â— ”«»ﬁ…
	SELECT @EndDate = DATEADD(day, -1, @SD)
	SELECT @StartDate = DATEADD(month, -6, @EndDate)

	DECLARE @CurrencyGUID [UNIQUEIDENTIFIER]
	SELECT @CurrencyGUID = [GUID] From [my000] WHERE [Number] = 1


	DECLARE @s [NVARCHAR](max)
	SET @s = '
	INSERT INTO [#Result]
	SELECT
		[rv].[buType],
		[rv].[buGuid],
		[rv].[buDate], 
		0, 
		-- [p].[SubPeriodCounter], 
		[rv].[BuSortFlag], 
		[rv].[BiNumber], 
		[rv].[buNotes], 
		[rv].[buCust_Name], 
		[rv].[buCustPtr], 
		CASE WHEN [UserReadPriceSecurity] >= [BuSecurity] THEN [rv].[buItemsDisc] ELSE 0 END AS [buItemsDisc], 
		[rv].[biStorePtr], 
		[rv].[biNotes], '
	IF @UseUnit = 1
		SET @S = @S + '2'
	ELSE IF @UseUnit = 2
		SET @S = @S + '3'
	ELSE IF @UseUnit = 3 --«·«› —«÷Ì…
		SET @S = @S + '1'
	ELSE IF @UseUnit = 0
		SET @S = @S + '1'
	SET @S = @S + 'AS [biUnity], '
	/*
	IF @UseUnit = 1
		SET @S = @S + 'CASE rv.mtUnit2Fact WHEN 0 THEN 1 ELSE rv.mtUnit2Fact END '
	ELSE IF @UseUnit = 2
		SET @S = @S + 'CASE rv.mtUnit3Fact WHEN 0 THEN 1 ELSE rv.mtUnit3Fact END '
	ELSE IF @UseUnit = 3 --«·«› —«÷Ì…
		SET @S = @S + 'CASE rv.mtDefUnitFact WHEN 0 THEN 1 ELSE rv.mtDefUnitFact END '
	ELSE IF @UseUnit = 0
		SET @S = @S + '1'
	SET @S = @S + 'AS biUnity, '
	*/

	SET @s = @s + '	
		CASE WHEN [UserReadPriceSecurity] >= [BuSecurity] THEN [rv].[biPrice] ELSE 0 END AS [biPrice], 
		[rv].[biCurrencyPtr], 
		[rv].[biCurrencyVal], 
		CASE WHEN [UserReadPriceSecurity] >= [BuSecurity] THEN [rv].[biDiscount] ELSE 0 END AS [biDiscount], 
		CASE WHEN [UserReadPriceSecurity] >= [BuSecurity] THEN [rv].[biExtra] ELSE 0 END AS [biExtra], 
		[rv].[biBillQty], 
		--[rv].[biBillBonusQnt], 
		[rv].[BiMatPtr],
		[rv].[MtName],
		[rv].[MtCode], 
		[rv].[MtLatinName], '
	IF @UseUnit = 1
		SET @S = @S + 'CASE [rv].[mtUnit2Fact] WHEN 0 THEN [rv].[mtUnity] ELSE [rv].[mtUnit2] END '
	ELSE IF @UseUnit = 2
		SET @S = @S + 'CASE [rv].[mtUnit3Fact] WHEN 0 THEN [rv].[mtUnity] ELSE [rv].[mtUnit3] END '
	ELSE IF @UseUnit = 3
		SET @S = @S + '[rv].[mtDefUnitName] '
	ELSE IF @UseUnit = 0
		SET @S = @S + '[rv].[mtUnity] '
	SET @S = @S + 'AS [mtUnitName] , '
	
	SET @s = @s + '	[rv].[MtDefUnitName],
		[rv].[MtDefUnitFact],
		--- cause checks must be credit pay 
		[rv].[btIsInput], 
		[rv].[biQty],
		[rv].[btIsOutput], 
		--rv.[BiBonusQnt], 
		-- CASE WHEN [UserReadPriceSecurity] >= [BuSecurity] THEN r.[buTotal] ELSE 0 END AS buTotal, 
		CASE WHEN [UserReadPriceSecurity] >= [BuSecurity] THEN [rv].[FixedBiPrice] ELSE 0 END AS FixedBiPrice], 
		[rv].[MtUnitFact], 
		CASE WHEN [UserReadPriceSecurity] >= [BuSecurity] THEN [rv].[FixedBuTotalExtra] ELSE 0 END AS [FixedBuTotalExtra], 
		CASE WHEN [UserReadPriceSecurity] >= [BuSecurity] THEN [rv].[FixedBuTotal] ELSE 0 END AS [FixedBuTotal], 
		CASE WHEN [UserReadPriceSecurity] >= [BuSecurity] THEN [rv].[FixedBuTotalDisc] ELSE 0 END AS [FixedBuTotalDisc], 
		CASE WHEN [UserReadPriceSecurity] >= [BuSecurity] THEN [rv].[FixedBiDiscount] ELSE 0 END AS [FixedBiDiscount], 
		[rv].[mtFlag],
		[rv].[mtUnit2Fact],
		[rv].[mtUnit3Fact],
		[rv].[mtUnity],
		[rv].[mtUnit2], 
		[rv].[mtUnit3], 
		[rv].[buSecurity], 
		[bt].[UserSecurity], 
		[bt].[UserReadPriceSecurity], 
		[rv].[MtSecurity],
		[p].[StartDate],
		[p].[StartDate],
		[p].[EndDate],'
SET @s = @s + ' CASE WHEN ' + CAST (@IsGroupByCust AS NVARCHAR) + ' = 1 THEN [ct].[CustGuid] ELSE 0x0 END'
SET @s = @s + '
	FROM
		[dbo].[fnExtended_bi_Fixed]( ''' + CONVERT( [NVARCHAR](100), @CurrencyGUID)  + ''') AS [rv] 
		INNER JOIN [fnGetPeriod]( 3, ''' + CONVERT( [NVARCHAR](100), @StartDate) + ''',''' +  CONVERT( [NVARCHAR](100), @EndDate) + ''') AS [p]	ON [rv].[buDate] BETWEEN [p].[StartDate] AND [p].[EndDate]
		INNER JOIN [#BillsTypesTbl] AS [bt] ON [rv].[buType] = [bt].[TypeGuid]
		INNER JOIN [#CustTbl] AS [ct] ON [rv].[BuCustPtr] = [ct].[CustGuid]
		INNER JOIN [#MatTbl] AS [mtTbl] ON [rv].[biMatPtr] = [mtTbl].[MatGuid]
		LEFT JOIN [DistMe000] AS [Me] ON [Me].[mtGuid] = [mtTbl].[MatGuid]
	WHERE
		(rv.[Budate] BETWEEN ''' + CONVERT( [NVARCHAR](100), @StartDate) + '''AND''' + CONVERT( [NVARCHAR](100), @EndDate) + ''')
		AND( [rv].[btType] = 1)
		AND( ([btBillType] = 1) OR ( [btBillType] = 3))--„»Ì⁄ √Ê „— Ã⁄ „»Ì⁄
		AND( (''' + CONVERT( [NVARCHAR](100), @CustGUID) + ''' = 0x0) OR ([rv].[BuCustPtr] IN ( SELECT [CustGUID] FROM [#CustTbl])))
		AND( (''' + CONVERT( [NVARCHAR](100), @AccGUID) + ''' = 0x0) OR ([buCustAcc] = ''' + CONVERT( [NVARCHAR](100), @AccGUID) + ''') OR ([BuCustPtr] IN ( SELECT [CustGUID] FROM [#CustTbl])))
		AND ( ( [Me].[State] Is NULL) OR ( [Me].[State] = 0))'

	
	print @s
	EXECUTE( @s)
	-- check sec
	EXEC [prcCheckSecurity]
	--- return result set
-- select * from #Result
	CREATE TABLE [#Result2]
	(
		[BiMatPtr]			[UNIQUEIDENTIFIER],
		[MtName]			[NVARCHAR](256) COLLATE ARABIC_CI_AI,
		[MtCode]			[NVARCHAR](256) COLLATE ARABIC_CI_AI,
		[MtLatinName]		[NVARCHAR](256) COLLATE ARABIC_CI_AI,
		[mtUnitName]		[NVARCHAR](256) COLLATE ARABIC_CI_AI,
		
		[UnitNameInBill]	[NVARCHAR](256) COLLATE ARABIC_CI_AI,
		[Unit]				[INT],

		[MtUnit2]			[NVARCHAR](256) COLLATE ARABIC_CI_AI,
		[MtUnit3]			[NVARCHAR](256) COLLATE ARABIC_CI_AI,

		[mtUnitFact]		[FLOAT],
		[PeriodY]			[INT],
		[periodM]			[INT],
		--periodW			INT,
		--SumInQty			FLOAT,
		[SumOutQty]			[FLOAT],
		--SumInBonusQty		FLOAT,
		--SumOutBonusQty	FLOAT,
		-- SumInPrice		FLOAT,
		-- SumOutPrice		FLOAT,
		-- SumInExtra		FLOAT,
		-- SumOutExtra		FLOAT,
		-- SumInDisc		FLOAT,
		-- SumOutDisc		FLOAT,
		-- SumInDiscVal		FLOAT,
		-- SumOutDiscVal	FLOAT,
		[StartDate]			[DATETIME],
		[PeriodStart]		[DATETIME],
		[PeriodEnd]			[DATETIME],
		[Cust]				[UNIQUEIDENTIFIER]
	)

	CREATE TABLE [#Result3]
	( 
		[BiMatPtr]			[UNIQUEIDENTIFIER], 
		[MtName]			[NVARCHAR](256) COLLATE ARABIC_CI_AI,
		[MtCode]			[NVARCHAR](256) COLLATE ARABIC_CI_AI,
		[MtLatinName]		[NVARCHAR](256) COLLATE ARABIC_CI_AI,
		[mtUnitName]		[NVARCHAR](256) COLLATE ARABIC_CI_AI,

		[UnitNameInBill]	[NVARCHAR](256) COLLATE ARABIC_CI_AI,
		[Unit]				[INT],
		[MtUnit2]			[NVARCHAR](256) COLLATE ARABIC_CI_AI,
		[MtUnit3]			[NVARCHAR](256) COLLATE ARABIC_CI_AI,

		[mtUnitFact]		[FLOAT],
		--SumInQty			FLOAT,
		[SumOutQty]			[FLOAT],
		--SumInBonusQty		FLOAT,
		--SumOutBonusQty	FLOAT,
		[pCount]			[FLOAT],
		[Cust]				[UNIQUEIDENTIFIER]
	) 


-- new 
	SET @s = 'INSERT INTO [#Result2]
	SELECT
		[rv].[BiMatPtr],
		[rv].[MtName],
		[rv].[MtCode],
		[rv].[MtLatinName],
		[mtUnitName],
		[mtUnitName] AS [UnitNameInBill],
		[biUnity] AS [Unit], '
	/*
	IF @UseUnit = 1
		SET @S = @S + 'CASE rv.mtUnit2Fact WHEN 0 THEN rv.mtUnity ELSE rv.mtUnit2 END '
	ELSE IF @UseUnit = 2
		SET @S = @S + 'CASE rv.mtUnit3Fact WHEN 0 THEN rv.mtUnity ELSE rv.mtUnit3 END '
	ELSE IF @UseUnit = 3
		SET @S = @S + 'rv.mtDefUnitName '
	ELSE IF @UseUnit = 0
		SET @S = @S + 'rv.mtUnity '
	SET @S = @S + 'AS mtUnitName , '
	*/
	/*
		SET @S = @S + ' CASE rv.biUnity WHEN 1 THEN rv.MtUnity 
								  WHEN 2 THEN rv.MtUnit2
								  ELSE rv.MtUnit3 END AS UnitNameInBill,'
	*/
	-- SET @S = @S + ' biUnity,'
	/*
	IF @UseUnit = 1
		SET @S = @S + 'CASE rv.mtUnit2Fact WHEN 0 THEN 1 ELSE rv.mtUnit2Fact END '
	ELSE IF @UseUnit = 2
		SET @S = @S + 'CASE rv.mtUnit3Fact WHEN 0 THEN 1 ELSE rv.mtUnit3Fact END '
	ELSE IF @UseUnit = 3 --«·«› —«÷Ì…
		SET @S = @S + 'CASE rv.mtDefUnitFact WHEN 0 THEN 1 ELSE rv.mtDefUnitFact END '
	ELSE IF @UseUnit = 0
		SET @S = @S + '1'
	SET @S = @S + 'AS Unit, '
	*/
	SET @S = @S + ' [MtUnit2],'
	SET @S = @S + ' [MtUnit3],'

	IF @UseUnit = 1
		SET @S = @S + '[rv].[mtUnit2Fact] '
	ELSE IF @UseUnit = 2
		SET @S = @S + '[rv].[mtUnit3Fact] '
	ELSE IF @UseUnit = 3
		SET @S = @S + '[rv].[mtDefUnitFact] '
	ELSE IF @UseUnit = 0
		SET @S = @S + '1 '
	SET @S = @S + 'AS [mtUnitFact] ,
		YEAR([Budate]) AS [PeriodY], 
		MONTH([Budate]) AS [periodM],' 
	-- SET @s = @s + ' 0 AS PeriodDDDDD, ' 
	IF @UseUnit = 1
		SET @S = @S + '( (SUM( [rv].[btIsOutput] * [rv].[biQty] ) - ( SUM( [rv].[btIsInput]  * [rv].[biQty] )))/CASE [mtUnit2Fact]	WHEN 0 THEN 1 ELSE [mtUnit2Fact] END ) '	
	ELSE IF @UseUnit = 2
		SET @S = @S + '( (SUM( [rv].[btIsOutput] * [rv].[biQty] ) - ( SUM( [rv].[btIsInput]  * [rv].[biQty] )))/CASE [mtUnit3Fact]	WHEN 0 THEN 1 ELSE [mtUnit3Fact] END ) '	
	ELSE IF @UseUnit = 3
		SET @S = @S + '( (SUM( [rv].[btIsOutput] * [rv].[biQty] ) - (SUM( [rv].[btIsInput]  * [rv].[biQty] ))) /CASE [mtDefUnitFact] WHEN 0 THEN 1 ELSE [mtDefUnitFact] END ) '	
	ELSE IF @UseUnit = 0
		SET @S = @S + '( SUM( [rv].[btIsOutput] * [rv].[biQty] ) - SUM( [rv].[btIsInput]  * [rv].[biQty] ) ) '	
	SET @S = @S + 'AS [SumOutQty], '
	SET @S = @S + ' [StartDate],
					[PeriodStart],
					[PeriodEnd],'

	SET @s = @s + ' [rv].[Cust]'

	SET @S = @S + ' 
	FROM
		[#Result] AS [rv]
	GROUP BY
		[BiMatPtr],
		[MtName],
		[MtCode], 
		[MtLatinName],
		[mtUnitName],'

	IF @UseUnit = 1
		SET @S = @S + '[mtUnit2], [mtUnity], '
	ELSE IF @UseUnit = 2
		SET @S = @S + '[mtUnit3], [mtUnity], '
	ELSE IF @UseUnit = 3
		SET @S = @S + '[mtDefUnitName], '
	ELSE IF @UseUnit = 0
		SET @S = @S + '[mtUnity], '

	IF @UseUnit = 1
		SET @S = @S + '[MtUnit2Fact], '
	ELSE IF @UseUnit = 2
		SET @S = @S + '[MtUnit3Fact], '
	ELSE IF @UseUnit = 3
		SET @S = @S + '[mtDefUnitFact], '
		SET @S = @S + '
		YEAR([Budate]), 
		MONTH([Budate]),
		[StartDate],
		[PeriodStart],
		[PeriodEnd],
		[rv].[Cust],
		[rv].[biUnity],
		[MtUnit2],
		[MtUnit3]'
	print @s
	EXECUTE( @s)

-- select * from #result2
--- Ã„Ì⁄ ﬂ· „«œ… Õ”» Ê⁄—÷ ≈Ã„«·Ì ﬂ„Ì Â« „⁄ ⁄œœ «·√‘Â— ÕÌÀ ”  „ «·ﬁ”„… ⁄·Ï ⁄œœ «·√‘Â— ›Ì «·ŒÿÊ… «· «·Ì…


	SET @s = ' 
	INSERT INTO [#Result3]
	SELECT
		[BiMatPtr],
		[MtName],
		[MtCode],
		[MtLatinName],
		[mtUnitName],
		[UnitNameInBill],
		[Unit],
		[MtUnit2],
		[MtUnit3],


		[mtUnitFact],
		--SUM([SumInQty]),
		--SUM([SumOutQty]) - SUM([SumInQty]), -- „»Ì⁄ - „— Ã⁄ 
		--  „  ﬁ”„ Â« ⁄·Ï ⁄«„· «· ÕÊÌ· ﬁ»· Â–« Ê»«· «·Ì ·« œ«⁄Ì ··ﬁ”„… Â‰«--
		 SUM([SumOutQty]),
		--SUM([SumInBonusQty]),
		--SUM([SumOutBonusQty]),
		COUNT(*),'

	IF @IsGroupByCust = 1
		SET @s = @s + '[Cust]'
	ELSE
		SET @s = @s + '0x0'

	SET @s = @s + ' FROM [#Result2]
	GROUP BY
		[BiMatPtr],
		[MtName],
		[MtCode],
		[MtLatinName],
		[mtUnitName],
		[UnitNameInBill],
		[Unit],
		[MtUnit2],
		[MtUnit3],
		[mtUnitFact],
		[Cust] '
	print @s
	EXECUTE( @s)
-- select * from #result3
	-- returning Result set
	INSERT INTO [#MainRes]
		SELECT
			ISNULL( [r].[BiMatPtr], [mt].[mtGUID]) AS [BiMatPtr],
			[mt].[MtName],
			[mt].[MtCode],
			[mt].[MtLatinName],
			ISNULL( [r].[mtUnitName], '') AS [mtUnitName],
			ISNULL( [r].[UnitNameInBill],'') as [UnitNameInBill],
			ISNULL( [r].[Unit], 1) AS [Unit],
			ISNULL( [r].[MtUnit2], mt.[MtUnit2]) AS [MtUnit2],
			ISNULL( [r].[MtUnit3], mt.[MtUnit3]) AS [MtUnit3],
			ISNULL( [r].[mtUnitFact], 1) AS [mtUnitFact],
			---ISNULL( mt.mtUnit2Fact, 0) AS mtUnit2Fact,
			---ISNULL( mt.mtUnit3Fact, 0) AS mtUnit3Fact,
			--ISNULL( r.SumInQty, 0) AS SumInQty,
			ISNULL( CASE WHEN [r].[pCount] = 0 THEN [r].[SumOutQty] ELSE [r].[SumOutQty] / [r].[pCount] END, 0) AS [Avg],
			ISNULL([Cust] , 0x0) AS [Cust]
			--ISNULL( r.SumInBonusQty, 0) AS SumInBonusQty,
			--ISNULL( r.SumOutBonusQty, 0) AS SumOutBonusQty
		FROM [#Result3] AS [r] RIGHT JOIN [vwmt] AS [mt] ON  [r].[BiMatPtr] = [mt].[mtGuid]

-- select * from vwmt
	-- SELECT *FROM #SecViol
END
/*

delete from bdp000 where number  14
select * from bdp000
select * from dbo.fnGetPeriod ( 3, '1/1/2004', '1/1/2005')

select * from Distdistributortarget000

EXEC prcCalcMatSalesAvg
0x0,
'0BCA492B-31FA-43C6-A4CD-F43E6ADEB14E',
0x0,	--	@CustGUID
0x0,	--	@AccGUID
0,		-- @UseUnit
0		-- @IsGroupByCust

select * from bdp000 '45363466-DAA5-40F9-819A-977BA31C1CFC'

select * from disGeneralTarget000
delete  from disGeneralTarget000
select * from bt000
select * from my000

select btType, btBillType, btname from dbo.fnExtended_bi_Fixed('579CFBFB-0250-4B32-B8AF-C1DE819FBA15')

EXEC prcPrepareCalcMatSalesAvg  0x0, '45363466-daa5-40f9-819a-977ba31c1cfc', 0x0, 0x0, 0

select * from bdp000 

exec prcCalcMatSalesAvg 0x0, '47E618BD-9662-4CD6-9851-212E51DDF17E', 0x0, 0x0, 1

*/


################################
#END