######################################################
CREATE PROC GetDistStoreInventory
	@DistGuid	UNIQUEIDENTIFIER,
	@PriceType  INT = 128
AS
	DECLARE 
		@StartPeriodDate DATE,
		@EndPeriodDate	DATE,
		@StoreGuid		UNIQUEIDENTIFIER
	
	-- GET DIST STORE GUID
	SELECT 
		@StoreGuid = StoreGuid
	From 
		Distributor000 AS Dist
	WHERE 
		Dist.Guid = @DistGuid
	
	-- GET START PERIOD AND END PERIOD DATE
	SET DATEFORMAT DMY 
	SELECT @StartPeriodDate = 
		CAST(value AS DATE) 
	FROM 
		op000 
	WHERE 
		Name = 'AmnCfg_FPDate' 

	SELECT @EndPeriodDate =
		CAST(value AS DATE)
	FROM 
		op000 
	WHERE 
		Name = 'AmnCfg_EPDate'
	SET DATEFORMAT YMD
	----------------------------------------
	-- GET STORE INVENTORY	
	SELECT 
	ISNULL(
	SUM(btDirection 
		* bubi.biQty 
		* CASE @PriceType 
			WHEN 4	THEN mt.Whole
			WHEN 8	THEN mt.Half
			WHEN 16 THEN mt.Export
			WHEN 32 THEN mt.vendor
			WHEN 64 THEN mt.Retail
			ELSE mt.EndUser
		  END 
		), 0) AS StoreInventory
	FROM 
		vwbubi as bubi
		INNER JOIN mt000 as mt ON mt.Guid = bubi.biMatPtr
	WHERE 
		BuStorePtr = @StoreGuid
		AND buDate Between @StartPeriodDate AND @EndPeriodDate
/*
EXEC prcDistGetDistStoreInventory 0x0, 128
*/	
######################################################
#END