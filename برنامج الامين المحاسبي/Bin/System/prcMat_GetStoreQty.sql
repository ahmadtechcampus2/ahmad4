###########################################
CREATE PROC prcHasDifferenceClassPrice
	@BillGUID UNIQUEIDENTIFIER,
	@MatGUID UNIQUEIDENTIFIER, 
	@Class [NVARCHAR](250), 
	@ClassPrice FLOAT
AS 
	SET NOCOUNT ON 
	
	DECLARE @HasDifferenceClassPrice BIT 
	SET @HasDifferenceClassPrice = 0

	DECLARE @LastClassPrice FLOAT 
	SET @LastClassPrice = 0

	SET @LastClassPrice = (
		SELECT TOP 1 
			(bi.ClassPrice 
				* (CASE ISNULL(bi.CurrencyVal, 0) WHEN 0 THEN (CASE ISNULL(bu.CurrencyVal, 0) WHEN 0 THEN 1 ELSE bu.CurrencyVal END) ELSE bi.CurrencyVal END)
				/ (CASE bi.Unity 
						WHEN 2 THEN (CASE ISNULL(mt.Unit2Fact, 0) WHEN 0 THEN 1 ELSE mt.Unit2Fact END) 
						WHEN 3 THEN (CASE ISNULL(mt.Unit3Fact, 0) WHEN 0 THEN 1 ELSE mt.Unit3Fact END)
						ELSE 1
					END))
		FROM 
			bi000 bi 
			INNER JOIN mt000 mt ON mt.[GUID] = bi.MatGUID 
			INNER JOIN bu000 bu ON bu.[GUID] = bi.ParentGUID 
			INNER JOIN bt000 bt ON bt.[GUID] = bu.TypeGUID 
		WHERE
			bu.GUID != @BillGUID
			AND 
			((bt.FldClassPrice > 0) OR ((bt.FldClassPrice <= 0) AND (bi.ClassPrice > 0)))
			AND  
			bi.ClassPtr = @Class 
			AND 
			bi.MatGUID = @MatGUID
		ORDER BY 
			bu.[Date] DESC, [bu].[Number] DESC, [bi].[Number] DESC)
	
	IF ((@LastClassPrice IS NOT NULL) AND (ABS(@LastClassPrice - @ClassPrice) > 0.01))
		SET @HasDifferenceClassPrice = 1
	
	SELECT 
		@HasDifferenceClassPrice AS HasDifferenceClassPrice,
		ISNULL(@LastClassPrice, 0) AS LastClassPrice
###########################################
CREATE FUNCTION fnGetMatClassPrice(@MatGUID UNIQUEIDENTIFIER, @Class [NVARCHAR](250), @BillDate DATE, @CurrencyGUID UNIQUEIDENTIFIER, @CurrencyVal FLOAT)
	RETURNS FLOAT 
AS 
BEGIN 
	RETURN (
	ISNULL((SELECT 
		TOP 1 
			(bi.ClassPrice / (CASE bi.MatCurVal WHEN 0 THEN 1 ELSE bi.MatCurVal END)) *
			(CASE 
				WHEN @CurrencyGUID = mt.CurrencyGUID THEN @CurrencyVal
				ELSE [dbo].fnGetCurVal(mt.CurrencyGUID, @BillDate)
			END)			
			-- * (CASE ISNULL(bi.CurrencyVal, 0) WHEN 0 THEN (CASE ISNULL(bu.CurrencyVal, 0) WHEN 0 THEN 1 ELSE bu.CurrencyVal END) ELSE bi.CurrencyVal END)
			/ (CASE bi.Unity 
				WHEN 2 THEN (CASE ISNULL(mt.Unit2Fact, 0) WHEN 0 THEN 1 ELSE mt.Unit2Fact END) 
				WHEN 3 THEN (CASE ISNULL(mt.Unit3Fact, 0) WHEN 0 THEN 1 ELSE mt.Unit3Fact END)
				ELSE 1
			END)
	FROM 
		bi000 bi 
		INNER JOIN mt000 mt ON mt.[GUID] = bi.MatGUID 
		INNER JOIN bu000 bu ON bu.[GUID] = bi.ParentGUID 
	WHERE 
		bi.ClassPtr = @Class 
		AND 
		bi.MatGUID = @MatGUID
		AND
		bi.ClassPrice > 0 
		AND 
		mt.ClassFlag > 0
	ORDER BY 
		bu.[Date] DESC, [bu].[Number] DESC, [bi].[Number] DESC), 0))
END 
###########################################
CREATE PROCEDURE prcMaterial_GetStoreQty 
	@MatGUID [UNIQUEIDENTIFIER] = 0x0,
	@bGroupStore [BIT] = 0,
	@bGroupExpireDate [BIT] = 0,
	@bGroupClass [BIT] = 0,
	@bCost [BIT] = 0,
	@StGUID [UNIQUEIDENTIFIER] = 0x0,
	@ShowClassPrice [BIT] = 0,
	@BillDate DATE = '1-1-2015',
	@CurrencyGUID [UNIQUEIDENTIFIER] = 0x0,
	@CurrencyVal FLOAT = 1
AS 
-----------------------------------------------
-- This procedure calculates the quantities of specified material grouped by store { or [or] and }
-- ExpireDate { or [or] and } GroupClass . 
-- If you don't specify a material this procedure bring all materials .
-----------------------------------------------
	SET NOCOUNT ON   
-----------------------------------------------
-- Creating temporary tables 
-----------------------------------------------
	-- CREATE TABLE #SecViol(Type INT,Cnt INTEGER)  
	CREATE TABLE [#Result]
	(
		[MatGUID] [UNIQUEIDENTIFIER],
		[StoreGUID] [UNIQUEIDENTIFIER],
		[ExpireDate] [DATETIME],
		[Class] [NVARCHAR](250) COLLATE ARABIC_CI_AI,
		[CostGUID] [UNIQUEIDENTIFIER],
		[MatQty] [FLOAT],
		[ClassPrice] FLOAT,
		CurrencyGUID UNIQUEIDENTIFIER, 
		CurrencyVal FLOAT
	) 

	 

	INSERT INTO [#Result] 
		SELECT 
			biMatPtr, 
			CASE @bGroupStore 
				WHEN 1 THEN [b].[biStorePtr] END, 
			CASE @bGroupExpireDate 
				WHEN 1 THEN [b].[biExpireDate] END, 
			CASE @bGroupClass 
				WHEN 1 THEN [b].[biClassPtr] END, 
			CASE @bCost
				WHEN 1 THEN ISNULL( [b].[biCostPtr], 0x0)	END, 
			SUM(buDirection *([b].[biQty] + [b].[biBonusQnt])),
			0, 0x0, 1
		FROM 
			-- [vwbu] AS [bu] 
			-- INNER JOIN [vwbi] AS [bi] ON [bu].[buGUID] = [bi].[biParent] 
			[vwBuBi] [b]
			--INNER JOIN [vwbt] AS [bt] ON [b].[buType] = [bt].[btGUID]
			--INNER JOIN [vwmt] AS [mt] ON [b].[biMatPtr] = [mt].[mtGUID] 
			--Why this inner it's only overhead 
			--INNER JOIN [vwst] AS [st] ON [b].[biStorePtr] = [st].[stGUID] 
			--Why this inner it's only overhead 
			--LEFT JOIN [vwco] AS [co] ON [b].[biCostPtr] = [co].[coGUID]
		WHERE  
			(biMatPtr = @MatGUID)
			AND ([b].[buisposted] = 1) 
			AND (([b].[biStorePtr] = @StGUID) OR (b.buStorePtr = @StGUID) OR (@StGUID = 0x0)) 
		GROUP BY 
			biMatPtr, 
			CASE @bGroupStore 
				WHEN 1 THEN [b].[biStorePtr] END, 
			CASE @bGroupExpireDate 
				WHEN 1 THEN [b].[biExpireDate] END, 
			CASE @bGroupClass 
				WHEN 1 THEN [b].[biClassPtr] END, 
			CASE @bCost 
				WHEN 1 THEN ISNULL([b].[biCostPtr], 0x0) END 
	
	IF @ShowClassPrice = 1
	BEGIN 
		UPDATE [#Result]
		SET ClassPrice = dbo.fnGetMatClassPrice([MatGUID], [Class], @BillDate, @CurrencyGUID, @CurrencyVal)
		--	CurrencyGUID = ISNULL(fn.CurrencyGUID, 0x0),
		--	CurrencyVal = ISNULL(fn.CurrencyVal, 1)
		--FROM 
		--	[#Result] r 
		--	CROSS APPLY dbo.fnGetMatClassPrice(r.[MatGUID], r.[Class], @BillDate, @CurrencyGUID, @CurrencyVal) fn 
	END  

	DECLARE @Lang INT 
	SET @Lang = (SELECT [dbo].[fnConnections_GetLanguage]())
	-- for more preformence
	--INSERT INTO [#EndResult]
		SELECT 
			ISNULL([r].[StoreGUID], 0x0) [StoreGUID], 
			ISNULL([st].[stCode], '') [StoreCode], 
			( CASE @Lang
				WHEN 0 THEN 
					CASE ISNULL([st].[stName], '')
						WHEN '' THEN ISNULL([st].[stLatinName], '')
						ELSE [st].[stName]
					END 	
				WHEN 1 THEN 
					CASE ISNULL([st].[stLatinName], '')
						WHEN '' THEN ISNULL([st].[stName], '')
						ELSE [st].[stLatinName]
					END 
				END 
			) [StoreName],

--			ISNULL([st].[stLatinName], ''), 
			CASE [Mt].ExpireFlag WHEN 1 THEN ISNULL([r].[ExpireDate], '')  END [ExpireDate], 
			ISNULL([r].[Class], '') [Class], 
			ISNULL([r].[CostGUID], 0x0) [CostGUID], 
			ISNULL([co].[coCode], '') [CostCode], 
			( CASE @Lang
				WHEN 0 THEN 
					CASE ISNULL([co].[coName], '')
						WHEN '' THEN ISNULL([co].[coLatinName], '')
						ELSE [co].[coName]
					END 
				WHEN 1 THEN 
					CASE ISNULL([co].[coLatinName], '')
						WHEN '' THEN ISNULL([co].[coName], '')
						ELSE [co].[coLatinName]
					END 
				END 
			) [CostName],
			[r].[MatQty] [MatQty],
			r.ClassPrice,
			r.CurrencyGUID,
			r.CurrencyVal
		FROM
			[#Result] [r] 
			LEFT JOIN [vwst] [st] ON [r].[StoreGUID] = [st].[stGUID]
			LEFT JOIN [vwco] [co] ON [r].[CostGUID] = [co].[coGUID]
			INNER JOIN mt000 [Mt] on [Mt].GUID = [r].[MatGUID] 
		WHERE
			[r].[MatQty] <> 0
		ORDER BY 
			[ExpireDate], [Class], [MatQty], [StoreCode]
	/*SELECT 
		* 
	FROM 
		[#EndResult]
	WHERE
		[MatQty] <> 0
	ORDER BY 
		[ExpireDate], [Class], [MatQty], [StoreCode]*/
-----------------------------------------------
-- Dropping unnecessary tables 
-----------------------------------------------
	-- DROP TABLE  #EndResult 
	-- DROP TABLE  #Result
	-- DROP TABLE  #SecViol
	--SET NOCOUNT OFF 

-- exec prcMat_GetStoreQty '17D83034-0466-4543-B983-EF8CD125934C',1,1,1
###############################################################
CREATE PROCEDURE prcGetStoreQntByExpireDate
	@mtGuid [UNIQUEIDENTIFIER],
	@stGuid [UNIQUEIDENTIFIER],
	@expireDate [DATETIME]
AS 
	SET NOCOUNT ON 

	SELECT 
		SUM((CASE [btIsInput] WHEN 1 THEN ([biQty] + [biBonusQnt]) ELSE -([biQty] + [biBonusQnt]) END)) AS [Qnt]
	FROM 
		vwExtended_Bi
	WHERE 
		([biMatPtr] = @mtGuid)
		AND 
		((@stGuid = 0x0) OR ([biStorePtr] = @stGuid))
		AND 
		([biExpireDate] = @expireDate)
		AND 
		([buIsPosted] = 1)
		AND 
		([mtExpireFlag] = 1)
	GROUP BY
		[biMatPtr],
		[biStorePtr],
		[biExpireDate]
###############################################################
CREATE PROCEDURE prcBillMatClassPtrLinkWithExpireDate
	@mtGuid [UNIQUEIDENTIFIER],
	@stGuid [UNIQUEIDENTIFIER],

	@expireDate [DATETIME],
	@classPtr NVARCHAR(MAX)


AS BEGIN
		IF EXISTS (SELECT * FROM vwExtended_bi bi
					WHERE bi.btIsInput = 1
						AND bi.biMatPtr=@mtGuid
						AND bi.biStorePtr=@stGuid
							AND bi.biClassPtr=@classPtr	
						)
							 
		 SELECT * FROM vwExtended_bi bi
					WHERE bi.btIsInput = 1
						AND bi.biMatPtr=@mtGuid
						AND bi.biStorePtr=@stGuid
						AND bi.biExpireDate=@expireDate
						AND bi.biClassPtr=@classPtr
		ELSE 
			SELECT 1
		
END
##################################################################
CREATE PROCEDURE prcBillMatClassPtrPreventManyExpireDate
	@mtGuid UNIQUEIDENTIFIER,
	@stGuid UNIQUEIDENTIFIER,
	@expireDate DATETIME,
	@classPtr NVARCHAR(MAX)
AS
	SET NOCOUNT ON

	SELECT * 
	FROM vwExtended_bi bi
	WHERE
		bi.btIsInput = 1
		AND bi.biMatPtr = @mtGuid
		AND bi.biStorePtr = @stGuid
		AND bi.biExpireDate <> @expireDate
		AND bi.biClassPtr = @classPtr
########################################################################
CREATE PROCEDURE prcGetStoreQntByBranch(@matGUID UNIQUEIDENTIFIER, @StoreGUID UNIQUEIDENTIFIER, @Branch UNIQUEIDENTIFIER) 
AS 
	SET NOCOUNT ON 

	SELECT 
		SUM((CASE btIsInput WHEN 1 THEN 1 ELSE -1 END) * (biQty + biBonusQnt)) AS Qnt 
	FROM 
		vwExtended_Bi 
	WHERE 
		biMatPtr = @matGUID 
		AND (buIsPosted = 1)
		AND ((ISNULL(@Branch, 0x0) = 0X0) OR (buBranch = @Branch))
		AND ((ISNULL(@StoreGUID, 0x0) = 0X0) OR (biStorePtr = @StoreGUID))
	GROUP BY 
		CASE ISNULL(@Branch, 0x0) WHEN 0x0 THEN 0x0 ELSE buBranch END,
		CASE ISNULL(@StoreGUID, 0x0) WHEN 0x0 THEN 0x0 ELSE biStorePtr END
###############################################################
#END
