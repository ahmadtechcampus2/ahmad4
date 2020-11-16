#############################################################################################################
##--Ì⁄Ìœ —ﬁ„ «·„«œ… Ê«·”⁄— 
##-----ÌÃ» „⁄«·Ã… «·’·«ÕÌ…  ··›Ê« Ì— Ê’·«ÕÌ… ﬁ—«¡… ”⁄—
CREATE PROCEDURE prcGetLastPrice
	@StartDate 			[DATETIME],
	@EndDate 			[DATETIME],
	@MatGUID 			[UNIQUEIDENTIFIER], -- 0 All Mat or MatNumber
	@GroupGUID 			[UNIQUEIDENTIFIER],
	@StoreGUID 			[UNIQUEIDENTIFIER], -- 0 all stores so don't check store or list of stores
	@CostGUID 			[UNIQUEIDENTIFIER], -- 0 all costs so don't Check cost or list of costs
	@MatType 			[INT], -- 0 Store or 1 Service or -1 ALL
	@CurrencyGUID 		[UNIQUEIDENTIFIER], -- if 0x0 then use buy currencyPtr else use fixed Price
	@SrcTypesguid		[UNIQUEIDENTIFIER],
	@ShowUnLinked 		[INT] = 0,
	@UseUnit 			[INT],
	@CalcLastCost		[INT] = 0,
	@ProcessExtra		[INT] = 0
AS

	SET NOCOUNT ON
	DECLARE @ReadLastPricePerm INT
	SELECT @ReadLastPricePerm = [dbo].[fnGetReadMatLastPrice]( [dbo].[fnGetCurrentUserGUID]())

	IF( EXISTS( SELECT * FROM [vwbu] WHERE [buDate] < @StartDate OR [buDate] > @EndDate)
		OR @CostGUID <> 0x0 --selected cost so from bu , bi
		--OR ISNULL( @SrcTypes, '') <> ''   -- selected src types so from bi, bu
		OR @ShowUnLinked = 1  -- we must calc sum(qty2), Sum(Qty3) from bi, bu
		OR @ReadLastPricePerm = 0 -- not Admin
		OR @CurrencyGUID = 0x0
		OR @CalcLastCost = 1
		OR @ProcessExtra = 1
		or @SrcTypesguid <> 0x00
		)
	BEGIN

		CREATE TABLE [#Result]
		(
			ID INT IDENTITY(1,1),
			[biMatPtr] 				[UNIQUEIDENTIFIER],
		
	
			[biPrice]				[FLOAT],
			[FixedbiPrice]			[FLOAT],
			[biCurrencyVal]			[FLOAT],
			[biUnitDiscount]		[FLOAT],
			[biUnitExtra]			[FLOAT],

			[Security]				[INT],
			[UserReadPriceSecurity]	[INT],
			[UserSecurity] 			[INT],
			[MtSecurity]			[INT],
			[mtUnitFact]			[FLOAT],
			[biStorePtr]			[UNIQUEIDENTIFIER],
			[FixedbiPriceED]		[FLOAT]
		)

		INSERT INTO [#Result]
		(
			[biMatPtr], 				
							
			[biPrice],				
			[FixedbiPrice],			
			[biCurrencyVal],			
			[biUnitDiscount],		
			[biUnitExtra],			
						
			[Security],				
			[UserReadPriceSecurity],	
			[UserSecurity], 			
			[MtSecurity],			
			[mtUnitFact],			
			[biStorePtr],			
			[FixedbiPriceED]		
		
		)
		SELECT
			[r].[biMatPtr],
		
			CASE WHEN [UserReadPriceSecurity] >= [BuSecurity] THEN [r].[biPrice] ELSE 0 END AS [biPrice],
			CASE WHEN [UserReadPriceSecurity] >= [BuSecurity] THEN [r].[FixedbiPrice] ELSE 0 END AS [FixedbiPrice],
			[r].[biCurrencyVal],
			CASE WHEN [UserReadPriceSecurity] >= [BuSecurity] THEN [r].[biUnitDiscount] ELSE 0 END AS [biUnitDiscount],
			CASE WHEN [UserReadPriceSecurity] >= [BuSecurity] THEN [r].[biUnitExtra] ELSE 0 END AS [biUnitExtra],

			[r].[buSecurity],
			[bt].[UserSecurity],
			[bt].[UserReadPriceSecurity],
			[r].[MtSecurity],
			[r].[mtUnitFact],
			[r].[biStorePtr],
			CASE @ReadLastPricePerm  WHEN 1 THEN 0 ELSE CASE WHEN [UserReadPriceSecurity] >= [BuSecurity] THEN ([r].[FixedBiTotal] -[r].[biVAT]) /CASE [r].[biQty] WHEN 0 THEN 1 ELSE [r].[biQty] END ELSE 0 END END
		FROM
			[dbo].[fnExtended_Bi_Fixed]( @CurrencyGUID) AS [r]
			INNER JOIN [#BillsTypesTbl] AS [bt] ON [r].[buType] = [bt].[TypeGuid]
			INNER JOIN [#MatTbl] AS [mtTbl] ON [r].[biMatPtr] = [mtTbl].[MatGUID]
		WHERE
			((@CostGUID = 0x0) OR ([BiCostPtr] IN( SELECT [CostGUID] FROM [#CostTbl])))
			AND [buDate] BETWEEN @StartDate AND @EndDate
			AND [btAffectLastPrice] > 0
			--	Last Price does'nt depend on store 
			--AND((@StoreGUID = 0) OR (biStorePtr IN( SELECT StoreGUID FROM #StoreTbl)))
			AND ((@MatType = -1) OR ([mtType] = @MatType))
			AND [buIsPosted] > 0 
		ORDER BY [r].[biMatPtr],[r].[buDate],[r].[buSortFlag],[r].[buNumber],[r].[biNumber]
	--select * from #Result
	---check Sec
		EXEC [prcCheckSecurity]

	-----
		INSERT INTO [#t_Prices]
		SELECT
			[vwmtGr].[mtGUID],
			ISNULL( [bi5].[LastPrice], 0) AS [APrice]
		FROM
			[vwmtGr] INNER JOIN [#MatTbl] AS [mtTbl] ON [vwmtGr].[mtGUID] = [mtTbl].[MatGUID]
			INNER JOIN
			(
				SELECT
					[bi3].[biMatPtr],
					
					MAX([bi3].[biPrice]) AS [LastPrice]
				FROM
				(
					SELECT
						[biMatPtr],
						(CASE @CurrencyGUID
							WHEN 0x0 THEN [biPrice] / (case [mtUnitFact] when 0 then 1 else [mtUnitFact] end) / (CASE [biCurrencyVal] WHEN 0 THEN 1 ELSE [biCurrencyVal] END) 
							ELSE (CASE @CalcLastCost WHEN 1 THEN ( [FixedbiPrice] / (case [mtUnitFact] when 0 then 1 else [mtUnitFact] end) + [biUnitExtra] - [biUnitDiscount])
													 ELSE ( CASE @ProcessExtra WHEN 0 THEN [FixedbiPrice] / (case [mtUnitFact] when 0 then 1 else [mtUnitFact] end) 
																				ELSE [FixedbiPriceED] END
					) END)
						END) AS [biPrice]
				FROM
					[#Result] AS [bi1]
				WHERE
					Id IN (select max(ID) FROM [#Result] GROUP BY [biMatPtr])
					AND [UserSecurity] >= [Security]
			) AS [bi3]
		GROUP BY
				[bi3].[biMatPtr]
			
		)AS [bi5]
			ON [vwMtGr].[mtGUID] = [bi5].[biMatPtr]
		WHERE
			((@MatType = -1) OR ([mtType] = @MatType))
	END
	ELSE
	BEGIN
		--Calc From mt, ms
		--print 'mt ms'
		INSERT INTO [#t_Prices] SELECT
			[v_mt].[mtGUID],
			ISNULL( [v_mt].[mtPrice], 0)AS [APrice]
		FROM
			[dbo].[fnGetMtPricesWithSec]( 2/*@PriceType*/,122 /*@PricePolicy*/, @UseUnit, @CurrencyGUID, @EndDate) AS [v_mt]
			INNER JOIN [#MatTbl] AS [mtTbl] ON [v_mt].[mtGUID] = [mtTbl].[MatGUID] 
		WHERE
			((@MatType = -1) 						OR ([mtType] = @MatType))
	END
#########################################################
CREATE PROC prcGetMaterialLastSalePrice
	@MaterialGUID UNIQUEIDENTIFIER
AS
	SET NOCOUNT ON

	SELECT 
		Price
	FROM (
		SELECT 
			BI.Price AS Price, 
			ROW_NUMBER() OVER(PARTITION BY BI.MatGUID ORDER BY BU.Date DESC) AS RN 
		FROM bu000 AS BU
			INNER JOIN bi000 AS BI ON BU.GUID = BI.ParentGUID
			INNER JOIN bt000 AS BT ON BT.GUID = BU.TypeGUID
		WHERE
			BT.Type = 1 AND BillType = 1
			AND BI.MatGUID = @MaterialGUID) B
	WHERE RN = 1
#########################################################
CREATE PROC prcGetCurrInfoPriceLastPurchase
	@mtGUID		UNIQUEIDENTIFIER
 AS  

	SELECT TOP (1) 
	 ISNULL(bu.CurrencyVal, 1) AS CurrencyValue ,
	 ISNULL(bu.CurrencyGUID, 0x0) AS CurrencyID
	FROM bu000 bu
		INNER JOIN bt000 bt ON bt.[GUID] = bu.TypeGUID 
		INNER JOIN bi000 bi ON bi.ParentGUID  = bu.[GUID]
		INNER JOIN mt000 mt ON mt.[GUID] = bi.MatGUID
	WHERE mt.[GUID] =  @mtGUID 
		  AND bu.[Date] = mt.LastPriceDate
		  AND bt.bAffectLastPrice = 1 
		  AND bt.bIsInput = 1
#########################################################
CREATE FUNCTION fnGetCurrencyIDLastPurchaseBill
(
	@mtGUID UNIQUEIDENTIFIER
)
RETURNS UNIQUEIDENTIFIER
BEGIN
    RETURN (SELECT TOP (1)
				ISNULL(bu.CurrencyGUID, 0x0) AS CurrencyID
			FROM bu000 bu
				INNER JOIN bt000 bt ON bt.[GUID] = bu.TypeGUID 
				INNER JOIN bi000 bi ON bi.ParentGUID  = bu.[GUID]
				INNER JOIN mt000 mt ON mt.[GUID] = bi.MatGUID
			WHERE mt.[GUID] =  @mtGUID 
				  AND bu.[Date] = mt.LastPriceDate
				  AND bt.bAffectLastPrice = 1 
		          AND bt.bIsInput = 1)
END
#########################################################
#END