#################################################################
CREATE PROCEDURE prcDifferencesBillsMaterials
	@CloseDayDate Datetime
AS
	SET NOCOUNT ON

	Declare @IncreaseBillTypeGuid uniqueidentifier =  dbo.fnOption_GetGUID('PFC_IncreaseBillType')
	Declare @DecreaseBillTypeGuid uniqueidentifier =  dbo.fnOption_GetGUID('PFC_DecreaseBillType')
	Declare @IncreasePriceBillTypeGuid uniqueidentifier =  dbo.fnOption_GetGUID('PFC_IncreasePricesBillType')
	Declare @DecreasePriceBillTypeGuid uniqueidentifier =  dbo.fnOption_GetGUID('PFC_DecreasePricesBillType')
    Declare @PriceType INT = dbo.fnOption_GetINT('PFC_CenterPriceBox', 0)

	Declare @Date datetime = (select max(Date) from MaterialPriceHistory000 where Date <= @CloseDayDate)

	DECLARE @Result TABLE
	(
		MatGuid		 UNIQUEIDENTIFIER,		
		Qty		     INT,
		biPrice		 FLOAT,
		Unity		 INT, 
		CurrencyGUID UNIQUEIDENTIFIER,
		StoreGUID    UNIQUEIDENTIFIER,
		CurrencyVal  FLOAT,
		btDirection  INT
	)

	INSERT INTO @Result
	SELECT 
		mt.MatGuid,		
		sum(bi.Qty) as qty ,
		bi.Price,
		Unity, 
		bi.CurrencyGUID,
		bi.StoreGUID,
		bi.CurrencyVal,
		CASE Bt.bIsInput WHEN 0 THEN 1 ELSE -1 END
	FROM MaterialPriceHistory000 mt INNER JOIN bi000 bi ON mt.MatGuid = bi.MatGUID 
	INNER JOIN bu000 bu ON  bu.GUID = bi.ParentGUID  
	INNER JOIN bt000 bt ON Bt.Guid = Bu.TypeGuid 
	WHERE price <> EndUser
	AND TypeGUID NOT IN (@IncreaseBillTypeGuid, @DecreaseBillTypeGuid, @IncreasePriceBillTypeGuid, @DecreasePriceBillTypeGuid)
	AND mt.Date = @Date AND bu.Date = @CloseDayDate
	GROUP BY mt.MatGuid, Unity, bi.CurrencyGUID, bi.StoreGUID, bi.Price, bi.CurrencyVal, Bt.bIsInput

	SELECT 
		Result.*, 
		CASE
		WHEN Result.unity = 1 and @PriceType = 4   THEN (Result.biPrice - mt.Whole)
		WHEN Result.unity = 1 and @PriceType = 8   THEN (Result.biPrice - mt.Half)
		WHEN Result.unity = 1 and @PriceType = 16  THEN (Result.biPrice - mt.Export)
		WHEN Result.unity = 1 and @PriceType = 32  THEN (Result.biPrice - mt.Vendor)
		WHEN Result.unity = 1 and @PriceType = 64  THEN (Result.biPrice - mt.Retail)
		WHEN Result.unity = 1 and @PriceType = 128 THEN (Result.biPrice - mt.EndUser)

		WHEN Result.unity = 2 and @PriceType = 4   THEN (Result.biPrice - mt.Whole2)
		WHEN Result.unity = 2 and @PriceType = 8   THEN (Result.biPrice - mt.Half2)
		WHEN Result.unity = 2 and @PriceType = 16  THEN (Result.biPrice - mt.Export2)
		WHEN Result.unity = 2 and @PriceType = 32  THEN (Result.biPrice - mt.Vendor2)
		WHEN Result.unity = 2 and @PriceType = 64  THEN (Result.biPrice - mt.Retail2)
		WHEN Result.unity = 2 and @PriceType = 128 THEN (Result.biPrice - mt.EndUser2)

		WHEN Result.unity = 3 and @PriceType = 4   THEN (Result.biPrice - mt.Whole3)
		WHEN Result.unity = 3 and @PriceType = 8   THEN (Result.biPrice - mt.Half3)
		WHEN Result.unity = 3 and @PriceType = 16  THEN (Result.biPrice - mt.Export3)
		WHEN Result.unity = 3 and @PriceType = 32  THEN (Result.biPrice - mt.Vendor3)
		WHEN Result.unity = 3 and @PriceType = 64  THEN (Result.biPrice - mt.Retail3)
		WHEN Result.unity = 3 and @PriceType = 128 THEN (Result.biPrice - mt.EndUser3)

		ELSE 0
		END * Result.btDirection AS Differences 
	 FROM @Result AS Result INNER JOIN MaterialPriceHistory000 mt ON Result.MatGuid = mt.MatGuid 
	 WHERE mt.Date = @Date 
###################################################################
CREATE PROCEDURE prcGetDifferencesBillsGuid
	@CloseDayDate Datetime
AS
	SET NOCOUNT ON

	Declare @IncreaseBillTypeGuid uniqueidentifier =  dbo.fnOption_GetGUID('PFC_IncreaseBillType')
	Declare @DecreaseBillTypeGuid uniqueidentifier =  dbo.fnOption_GetGUID('PFC_DecreaseBillType')
	
	SELECT GUID FROM bu000 
	WHERE Date = @CloseDayDate AND TypeGuid = @IncreaseBillTypeGuid

	SELECT GUID FROM bu000 
	WHERE Date = @CloseDayDate AND TypeGuid = @DecreaseBillTypeGuid
###################################################################
#END