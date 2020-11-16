#########################################################
CREATE FUNCTION fnMaterial_GetPrice( 
		@matGUID [UNIQUEIDENTIFIER], 
		@priceType [INT], 
		@untilDate [DATETIME]) 
	RETURNS [FLOAT]
AS BEGIN 
/* 
this function returns price for a given material and date, according to a pricing policy provided by @priceType 
	@price type: 
		0: LastPrice  
		1: AvgPrice  
		2: MaxPrice  
*/ 
	DECLARE @result [FLOAT] 
	IF @untilDate >= (SELECT MAX([buDate]) FROM [vwbubi] WHERE [biMatPtr] = @matGUID) 
	BEGIN 
		IF @priceType = 0 -- lastPrice 
			SET @result = (SELECT [LastPrice] FROM [mt000] WHERE [GUID] = @matGUID) 
		IF @priceType = 1 -- avgPrice 
			SET @result = (SELECT [avgPrice] FROM [mt000] WHERE [GUID] = @matGUID) 
		IF @priceType = 2 -- maxPrice 
			SET @result = (SELECT [MaxPrice] FROM [mt000] WHERE [GUID] = @matGUID) 
	END 
	ELSE 
	BEGIN 
		-- fetch price from bi 
		IF @priceType = 0 -- lastPrice 
			SET @result = (SELECT TOP 1 [biUnitPrice] FROM [vwExtended_bi] WHERE [biMatPtr] = @matGUID AND [buIsPosted] = 1 AND [buDate] <= @untilDate AND [btAffectLastPrice] = 1 ORDER BY [buDate] DESC, [buNumber] DESC) 
	 
		IF @priceType = 1 -- avgPrice 
			SET @result = (SELECT TOP 1 [biUnitPrice] - ([biProfits] / [biQty]) FROM [vwExtended_bi] WHERE [biMatPtr] = @matGUID AND [buDate] <= @untilDate AND [buIsPosted] = 1 AND [btAffectCostPrice] = 1 ORDER BY [buDate] DESC, [buNumber] DESC, [buSortFlag] Asc,biNumber DESC)  
	 
		IF @priceType = 2 -- maxPrice 
			SET @result = (SELECT MAX([biUnitPrice]) FROM [vwExtended_bi] WHERE [biMatPtr] = @matGUID and [buDate] <= @untilDate AND [buIsPosted] = 1 AND [btAffectLastPrice] = 1) 
	END 
	RETURN (ISNULL(@result, 0)) 
END  
#########################################################
#END