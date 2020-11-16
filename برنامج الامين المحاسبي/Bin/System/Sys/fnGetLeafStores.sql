#########################################################################
CREATE FUNCTION fnGetLeafStores(@StoreGuid [UNIQUEIDENTIFIER])
RETURNS @Result TABLE ([StoreGuid] [UNIQUEIDENTIFIER]) 
AS BEGIN 
	INSERT INTO @Result 
		SELECT [stGUID] FROM vwst
		WHERE (
			[stGUID] NOT IN (SELECT [stParent] FROM vwst)
			AND (
				[stParent] IN (SELECT [GUID] FROM fnGetStoresListByLevel(@StoreGuid, 8))				
				)
			 )
	if ((SELECT COUNT(*) FROM @Result) = 0) 
		INSERT INTO @Result VALUES (@StoreGuid)
	RETURN
END 
#########################################################################
CREATE FUNCTION fnMaterial_getQty_withUnPostedByStore(
		@matGuid [uniqueidentifier], @StoreGUID [uniqueidentifier])
	RETURNS [float]
AS BEGIN
/*
this function:
	- returns the total quantity of a given @matGuid by accumulating from bill
	  the only deffirence between this function and fnMaterial_getQty is that this function
	  deals accumolates unposted bills, but ignores bu with bNoPost
	- deals with core tables directly, ignoring branches and itemSecurity features.
*/

	DECLARE @result [float]

	SET @result = (	
			SELECT sum([qty] * (CASE [bIsInput] WHEN 1 THEN 1 ELSE -1 END))
			FROM [bi000] [bi] 
			INNER JOIN [bu000] [bu] ON [bi].[parentGuid] = [bu].[guid] 
			INNER JOIN [bt000] [bt] ON [bu].[typeGuid] = [bt].[guid]
			JOIN dbo.fnGetStoresList(@StoreGUID) AS S ON S.[Guid] = [bi].StoreGUID 
			JOIN vdstNoSons AS vd ON vd.GUID = S.[Guid]		
		WHERE 
			vd.Security <= [dbo].[fnGetUserSec](dbo.fnGetCurrentUserGUID(), 0x1001D000, 0x0, 1, 1)
			AND [bi].[matGuid] = @matGuid AND [bt].[bNoPost] = 0)

	RETURN ISNULL(@result, 0.0)
END
#########################################################################
CREATE FUNCTION fnGetStoreMatQty(@StoreGUID UNIQUEIDENTIFIER = 0x0	)
RETURNS TABLE
AS
RETURN(

	WITH M AS
	(
		SELECT 
			msMatPtr AS MatGuid, 
			ISNULL(SUM(MS.msQty), 0) AS Qty 
		FROM 
			vwMs AS MS 
			JOIN dbo.fnGetStoresList(@StoreGUID) AS S ON S.[Guid] = MS.msStorePtr 
			JOIN vdstNoSons AS vd ON vd.GUID=MS.msStorePtr		
		WHERE 
		-- ÇÎÊÈÇÑ ÕáÇÍíÉ ÇáãÓÊÎÏã Úáì ÇáãÓÊæÏÚ
			vd.Security <= [dbo].[fnGetUserSec](dbo.fnGetCurrentUserGUID(), 0x1001D000, 0x0, 1, 1)
		GROUP BY 
			msMatPtr
	)
	SELECT 
		
	   mt.[Number]
	  ,mt.[Name]
	  ,mt.[Code]
	  ,mt.[LatinName]
	  ,mt.[BarCode]  
	  ,mt.[CodedCode]
	  ,mt.[Unity]     
      ,mt.[Spec]
	  ,ISNULL(M.Qty, 0) AS Qty
      ,mt.[High]
      ,mt.[Low]
      ,mt.[Whole]
      ,mt.[Half]
      ,mt.[Retail]
      ,mt.[EndUser]
      ,mt.[Export]
      ,mt.[Vendor]
      ,mt.[MaxPrice]
      ,mt.[AvgPrice]
      ,mt.[LastPrice]
      ,mt.[PriceType]
      ,mt.[SellType]
      ,mt.[BonusOne]
      ,mt.[CurrencyVal]
      ,mt.[UseFlag]
      ,mt.[Origin]
      ,mt.[Company]
      ,mt.[Type]
      ,mt.[Security]
      ,mt.[LastPriceDate]
      ,mt.[Bonus]
      ,mt.[Unit2]
      ,mt.[Unit2Fact]
      ,mt.[Unit3]
      ,mt.[Unit3Fact]
      ,mt.[Flag]
      ,mt.[Pos]
      ,mt.[Dim]
      ,mt.[ExpireFlag]
      ,mt.[ProductionFlag]
      ,mt.[Unit2FactFlag]
      ,mt.[Unit3FactFlag]
      ,mt.[BarCode2]
      ,mt.[BarCode3]
      ,mt.[SNFlag]
      ,mt.[ForceInSN]
      ,mt.[ForceOutSN]
      ,mt.[VAT]
      ,mt.[Color]
      ,mt.[Provenance]
      ,mt.[Quality]
      ,mt.[Model]
      ,mt.[Whole2]
      ,mt.[Half2]
      ,mt.[Retail2]
      ,mt.[EndUser2]
      ,mt.[Export2]
      ,mt.[Vendor2]
      ,mt.[MaxPrice2]
      ,mt.[LastPrice2]
      ,mt.[Whole3]
      ,mt.[Half3]
      ,mt.[Retail3]
      ,mt.[EndUser3]
      ,mt.[Export3]
      ,mt.[Vendor3]
      ,mt.[MaxPrice3]
      ,mt.[LastPrice3]
      ,mt.[GUID]
      ,mt.[GroupGUID]
      ,mt.[PictureGUID]
      ,mt.[CurrencyGUID]
      ,mt.[DefUnit]
      ,mt.[bHide]
      ,mt.[branchMask]
      ,mt.[OldGUID]
      ,mt.[NewGUID]
      ,mt.[Assemble]
      ,mt.[OrderLimit]
      ,mt.[CalPriceFromDetail]
      ,mt.[ForceInExpire]
      ,mt.[ForceOutExpire]
      ,mt.[CreateDate]
      ,mt.[IsIntegerQuantity]
      ,mt.[ClassFlag]
      ,mt.[ForceInClass]
      ,mt.[ForceOutClass]
      ,mt.[DisableLastPrice]
      ,mt.[LastPriceCurVal]
      ,mt.[PrevQty]
	  ,dbo.fnMaterial_getQty_withUnPostedByStore(mt.[GUID], @StoreGUID) AS Qty0
	  ,[gr].[Code] AS [grCode]
		,[gr].[Name] AS [grName]
		,[gr].[LatinName] AS [grLatinName]
		,fnOrd.*
	 FROM 
		vdMt2 AS [mt] 
		INNER JOIN [vbGr] AS [gr] ON [mt].[GroupGUID] = [gr].[GUID] 
		LEFT JOIN M ON mt.GUID = M.MatGUID
		LEFT JOIN dbo.fnGetOrdersRemainderAndStockQty('1/1/1980', '12/31/2079') AS fnOrd ON mt.GUID = fnOrd.mtGuid
	)
################################################################
#END