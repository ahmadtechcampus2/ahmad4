#########################################################
CREATE PROCEDURE CheckLCConfilctAfterTransfare
	@DestDB NVARCHAR(250)
AS

SET NOCOUNT ON

IF LEFT(@DestDB, 1) <> N'['
BEGIN
	SET @DestDB = N'[' + @DestDB + N']';
END

EXEC('
DECLARE @Result TABLE 
(
	[Name] NVARCHAR(250),
	[Date] Date,
	[Number] INT
)

SELECT bu.* INTO #Res FROM bu000 bu INNER JOIN LC000 lc ON bu.LCGUID = lc.GUID WHERE bu.LCGUID <> 0x0 AND lc.State = 1 AND CAST (bu.GUID AS [NVARCHAR](256)) IN (
	SELECT mc.ASC3 FROM ' + @DestDB + '..bu000 bu INNER JOIN ' + @DestDB + '..LC000 lc ON bu.LCGUID = lc.GUID INNER JOIN '+ @DestDB +'..[MC000] AS mc ON CAST (bu.guid AS [NVARCHAR](256)) = mc.[ASC2] WHERE bu.LCGUID <> 0x0 AND lc.State = 0)

IF EXISTS (SELECT * FROM #Res)
BEGIN
	DECLARE @billID UNIQUEIDENTIFIER, @billIDDest UNIQUEIDENTIFIER
	
	WHILE EXISTS(SELECT TOP 1 * FROM #Res)
	BEGIN
		SELECT TOP 1 @billID = GUID FROM #Res
		SELECT @billIDDest = CONVERT(UNIQUEIDENTIFIER, ASC2) FROM ' + @DestDB + '..[MC000] AS mc WHERE CAST (@billID AS [NVARCHAR](256)) = mc.[ASC3]

		IF ((SELECT Total FROM bu000 WHERE GUID = @billID) - (SELECT Total FROM ' + @DestDB + '..bu000  WHERE GUID = @billIDDest)) <> 0
			OR ((SELECT COUNT(*) FROM bi000 WHERE ParentGUID = @billID) - (SELECT COUNT(*) FROM ' + @DestDB + '..bi000 WHERE ParentGUID = @billIDDest)) <> 0 
			OR (SELECT [Number]
				  ,[Qty]
				  ,[OrderQnt]
				  ,[Unity]
				  ,[Price]
				  ,[BonusQnt]
				  ,[Discount]
				  ,[BonusDisc]
				  ,[Extra]
				  ,[CurrencyVal]
				  ,[Notes]
				  ,[Profits]
				  ,[Num1]
				  ,[Num2]
				  ,[Qty2]
				  ,[Qty3]
				  ,[ClassPtr]
				  ,[ExpireDate]
				  ,[ProductionDate]
				  ,[Length]
				  ,[Width]
				  ,[Height]
				  ,[VAT]
				  ,[VATRatio]
				  ,[MatGUID]
				  ,[CurrencyGUID]
				  ,[StoreGUID]
				  ,[CostGUID]
				  ,[SOType]
				  ,[SOGuid]
				  ,[Count]
				  ,[SOGroup]
				  ,[TotalDiscountPercent]
				  ,[TotalExtraPercent]
				  ,[ClassPrice]
				  ,[MatCurVal]
				  ,[TaxCode]
				  ,[ExciseTaxVal]
				  ,[PurchaseVal]
				  ,[ReversChargeVal]
				  ,[ExciseTaxPercent]
				  ,[ExciseTaxCode]
				  ,[LCDisc]
				  ,[LCExtra]
			 FROM bi000 bu WHERE bu.ParentGUID =  @billID FOR XML AUTO ) <> 
			 ( SELECT [Number]
				  ,[Qty]
				  ,[OrderQnt]
				  ,[Unity]
				  ,[Price]
				  ,[BonusQnt]
				  ,[Discount]
				  ,[BonusDisc]
				  ,[Extra]
				  ,[CurrencyVal]
				  ,[Notes]
				  ,[Profits]
				  ,[Num1]
				  ,[Num2]
				  ,[Qty2]
				  ,[Qty3]
				  ,[ClassPtr]
				  ,[ExpireDate]
				  ,[ProductionDate]
				  ,[Length]
				  ,[Width]
				  ,[Height]
				  ,[VAT]
				  ,[VATRatio]
				  ,[MatGUID]
				  ,[CurrencyGUID]
				  ,[StoreGUID]
				  ,[CostGUID]
				  ,[SOType]
				  ,[SOGuid]
				  ,[Count]
				  ,[SOGroup]
				  ,[TotalDiscountPercent]
				  ,[TotalExtraPercent]
				  ,[ClassPrice]
				  ,[MatCurVal]
				  ,[TaxCode]
				  ,[ExciseTaxVal]
				  ,[PurchaseVal]
				  ,[ReversChargeVal]
				  ,[ExciseTaxPercent]
				  ,[ExciseTaxCode]
				  ,[LCDisc]
				  ,[LCExtra]
			 FROM ' + @DestDB + '..bi000 bu WHERE bu.ParentGUID = @billIDDest FOR XML AUTO )
			BEGIN
				INSERT INTO @Result SELECT lc.Name, bu.Date, bu.Number FROM bu000 bu INNER JOIN LC000 lc ON bu.LCGUID = lc.GUID WHERE bu.GUID = @billID
			END

		DELETE FROM #Res WHERE GUID = @billID
	END
END

SELECT * FROM @Result')
#########################################################
#end