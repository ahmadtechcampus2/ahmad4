#################################################################
CREATE PROCEDURE prcPDABilling_GetOptions
	@PDAUserName NVARCHAR(250) 
AS 
	SET NOCOUNT ON 

	DECLARE @Price1Name NVARCHAR(100) 
	DECLARE @Price2Name NVARCHAR(100) 
	DECLARE @Price3Name NVARCHAR(100) 
	DECLARE @Price4Name NVARCHAR(100) 
	DECLARE @Price5Name NVARCHAR(100) 
	DECLARE @Price6Name NVARCHAR(100) 
	SELECT @Price1Name = ISNULL(Asc1, '') FROM mc000 WHERE Type = 8 AND Number = 1095 
	SELECT @Price2Name = ISNULL(Asc1, '') FROM mc000 WHERE Type = 8 AND Number = 1096 
	SELECT @Price3Name = ISNULL(Asc1, '') FROM mc000 WHERE Type = 8 AND Number = 1098 
	SELECT @Price4Name = ISNULL(Asc1, '') FROM mc000 WHERE Type = 8 AND Number = 1099 

	SELECT @Price5Name = ISNULL(Asc1, '') FROM mc000 WHERE Type = 8 AND Number = 1097   -- Retail 
	SELECT @Price6Name = ISNULL(Asc1, '') FROM mc000 WHERE Type = 8 AND Number = 1100   -- EndUser 

	SELECT 
		1 AS Number, 
		pl.GUID, 
		pl.DistributerName AS Name,
		pl.PalmUserName,
		pl.PrivateStoreGuid AS StoreGUID,
		pl.MatSortFld,
		pl.CustSortFld,
		pl.BillsStartDate,
		pl.BillsEndDate,
		pl.GlStartDate,
		pl.GLEndDate,
		pl.bExportSerialNum,
		pl.bExportEmptyMaterial,
		pl.DistributorPassword,
		pl.SupervisorPassword,
		pl.License,	
		pl.DefaultPayType,
		pl.CanChangePrice,
		pl.ItemDiscType,
		pl.AccessByBarcode, 
		pl.AccessByRFID, 
		pl.VisiblePricesMask AS lstPrices,
		-- To avoid conflict between PPC processing & sql 
		CAST(CASE pl.OutNegative	 WHEN 1 THEN 0 ELSE 1 END AS BIT) AS OutNegative,
		
		CAST(0 AS BIT)		AS NoOverTakeMaxDebit, 
		CAST(1 AS BIT)		AS ShowCustInfo, 
		CAST(0 AS BIT)		AS UseCustLastPrice, 
		CAST(0 AS BIT)		AS CustBarcodeHasValidate, 
		CAST(0 AS BIT)		AS CanChangeCustBarcode, 		

		ISNULL(@Price1Name, '') AS Price1Name, 
		ISNULL(@Price2Name, '') AS Price2Name, 
		ISNULL(@Price3Name, '') AS Price3Name, 
		ISNULL(@Price4Name, '') AS Price4Name, 
		ISNULL(@Price5Name, '') AS Price5Name, 
		ISNULL(@Price6Name, '') AS Price6Name,
		GetDate()				AS SyncDate  
	FROM   
		[pl000] AS pl 
	WHERE 
		[pl].[PalmUserName] = @PDAUserName 

/*
EXEC prcPDABilling_GetOptions 'IT7000'
Select StoreGuid, PrivateStoreGuid, * FROM Pl000
*/
#################################################################
#END