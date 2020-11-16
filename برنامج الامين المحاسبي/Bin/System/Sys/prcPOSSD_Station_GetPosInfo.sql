#################################################################
CREATE FUNCTION fnPOSSD_Station_GetBillGCCLocation
(
	 @BillType   UNIQUEIDENTIFIER
)
RETURNS UNIQUEIDENTIFIER
AS
BEGIN
	DECLARE @Result				UNIQUEIDENTIFIER = 0x0;	
	SELECT 		
		@Result				= CU.GCCLocationGUID 
	FROM 
		bt000 AS BT INNER JOIN cu000 AS CU ON (CU.GUID = BT.CustAccGuid)
	WHERE 
		BT.[GUID] = @BillType;
	RETURN @Result;
END
#################################################################
CREATE FUNCTION fnPOSSD_Station_GetBillGCCLocationName
(
	 @BillType   UNIQUEIDENTIFIER,
	 @language  BIT
)
RETURNS NVARCHAR(250)
AS
BEGIN
	
	DECLARE @DefaultGCCLoc		UNIQUEIDENTIFIER = 0x0
	DECLARE @GCCLocationName	NVARCHAR(250) = NULL
	

	SET @DefaultGCCLoc =  DBO.fnPOSSD_Station_GetBillGCCLocation(@BillType);

	
		SELECT @GCCLocationName =
		CASE @language   WHEN 0   THEN GCCLOC.Name
					     ELSE CASE LEN(GCCLOC.LatinName) WHEN 0 THEN GCCLOC.Name 
						 ELSE GCCLOC.LatinName END END   

		FROM GCCCustLocations000 AS GCCLOC
		WHERE GUID = @DefaultGCCLoc;
	RETURN @GCCLocationName;

END
#################################################################
CREATE PROCEDURE prcPOSSD_Station_GetPosInfo
@StationGUID UNIQUEIDENTIFIER
AS 
BEGIN
	
	DECLARE @IsGCCTaxSystemEnable		BIT				= ISNULL((SELECT Value FROM op000 WHERE Name = 'AmnCfg_EnableGCCTaxSystem'), 0)
	DECLARE @TaxNumber					NVARCHAR(250);
	DECLARE @TaxNumberCode				NVARCHAR(250);
	DECLARE @VatType					INT				= 1;		

	SELECT 
		  @TaxNumber		= GCCTypes.TaxNumber,
		  @TaxNumberCode	= GCCTypes.TaxNumberCode
	FROM GCCTaxTypes000 GCCTypes 
	WHERE GCCTypes.[Type] = @VatType;
	
	SELECT 
		PC.*,
		@IsGCCTaxSystemEnable AS IsGCCTaxSystemEnable,
		dbo.fnPOSSD_Station_GetBillGCCLocation(PC.SaleBillTypeGUID)	AS SaleBillTypeGCCLocationGUID,
		dbo.fnPOSSD_Station_GetBillGCCLocation(PC.PurchaseBillTypeGUID)	AS PurchaseBillTypeGCCLocationGUID,
		dbo.fnPOSSD_Station_GetBillGCCLocation(PC.SaleReturnBillTypeGUID) AS SaleReturnBillTypeGCCLocationGUID,
		dbo.fnPOSSD_Station_GetBillGCCLocation(PC.PurchaseReturnBillTypeGUID) AS PurchaseReturnBillTypeGCCLocationGUID,
		
		@TaxNumber AS TaxNumber,
		@TaxNumberCode AS TaxNumberCode
	FROM POSSDStation000 PC 	
	WHERE 
		PC.GUID = @StationGUID
END
#################################################################
CREATE PROCEDURE prcPOSSD_Station_GetBillTypes
@StationGUID UNIQUEIDENTIFIER
AS 
BEGIN	
	DECLARE @SaleBillTypeGUID				UNIQUEIDENTIFIER = NULL;
	DECLARE @PurchaseBillTypeGUID			UNIQUEIDENTIFIER = NULL;
	DECLARE @SaleReturnBillTypeGUID			UNIQUEIDENTIFIER = NULL;
	DECLARE @PurchaseReturnBillTypeGUID		UNIQUEIDENTIFIER = NULL;

	DECLARE @SaleBillTypeCustGUID		    UNIQUEIDENTIFIER = NULL;
	DECLARE @PurchaseBillTypeCustGUID	    UNIQUEIDENTIFIER = NULL;
	DECLARE @SaleReturnBillTypeCustGUID     UNIQUEIDENTIFIER = NULL;
	DECLARE @PurchaseReturnBillTypeCustGUID UNIQUEIDENTIFIER = NULL;

	SELECT 
		@SaleBillTypeGUID			= POS.SaleBillTypeGUID,
		@PurchaseBillTypeGUID		= POS.PurchaseBillTypeGUID,
		@SaleReturnBillTypeGUID		= POS.SaleReturnBillTypeGUID,
		@PurchaseReturnBillTypeGUID = POS.PurchaseReturnBillTypeGUID
	FROM POSSDStation000 POS
	WHERE POS.[GUID] = @StationGUID;

	SELECT 
		BT.[GUID],
		CASE BT.VATSystem 
			WHEN 0 THEN 0
			WHEN 1 THEN 1
			ELSE 2
		END												  AS TaxType,
		BT.taxBeforeDiscount							  AS IsTaxCalculationBeforeDiscount,
		BT.taxBeforeExtra								  AS IsTaxCalculationBeforeAddition,
		dbo.fnPOSSD_Station_GetBillGCCLocation(BT.[GUID]) AS GCCLocationGUID,
		GCCCT.TaxCode									  AS TaxCode,
		GCCCT.TaxNumber									  AS TaxNumber,
		CU.CustomerName									  AS GCCTaxDefCustomerName,
		CU.LatinName									  AS GCCTaxDefCustomerLatinName,
		BT.IsPriceIncludeTax							  AS GCCIsPriceIncludeTax
	FROM 
		bt000 BT
		LEFT JOIN GCCCustomerTax000 GCCCT  ON GCCCT.CustGUID  = BT.CustAccGuid
		LEFT JOIN cu000 CU ON GCCCT.CustGUID = CU.[GUID]
	WHERE 
		BT.[GUID] IN (@SaleBillTypeGUID, @PurchaseBillTypeGUID, @SaleReturnBillTypeGUID, @PurchaseReturnBillTypeGUID);
END
#################################################################
CREATE FUNCTION GetAmeenPosProAPIVersion()
RETURNS NVARCHAR(50)
AS
BEGIN
       DECLARE @ameenPosProAPIVersion NVARCHAR(50)

       SELECT @ameenPosProAPIVersion = CONVERT(NVARCHAR(50), value) FROM sys.extended_properties WHERE name = 'AmnPosProAPIVersion'

       RETURN @ameenPosProAPIVersion

END
#################################################################
CREATE PROCEDURE prcPOSSD_Station_GetList (@DeviceId	NVARCHAR(250))
AS
BEGIN
	/*******************************************************************************************************
	Company : Syriansoft
	SP : prcPOSSD_Station_GetList
	Purpose: get list of pos station
	How to Call: EXEC prcPOSSD_Station_GetList 'mk7byA24Z62zacxj3+DPdHkgVVae2FV/CmaSOueR4dI='
	Create By: Hanadi Salka													Created On: 05 May 2019
	Updated On:																Updated By:
	Change Note:
	********************************************************************************************************/
	SELECT 		
		S.GUID,
		S.Number,
		S.Code,
		S.Name,
		S.LatinName,
		S.DataTransferMode,
		CASE WHEN S.DataTransferMode = 0 THEN 1 ELSE 0 END AS OnlineMode,
		COUNT(SD.DeviceID) AS OpenShiftCount,
		COUNT(SDSD.DeviceID) AS OpenShiftSameDeviceCount	

	FROM POSSDStation000 AS S LEFT JOIN POSSDShift000 AS SH ON (S.GUID = SH.StationGUID )
	LEFT JOIN POSSDShiftDetail000 AS SD ON (SD.ShiftGUID = SH.GUID AND SD.DeviceID != @DeviceId AND SH.CloseDate IS NULL)
	LEFT JOIN POSSDShiftDetail000 AS SDSD ON (SDSD.ShiftGUID = SH.GUID AND SDSD.DeviceID = @DeviceId AND SH.CloseDate IS NULL)
	GROUP BY S.GUID, S.Number, S.Code, S.Name,S.LatinName,S.DataTransferMode;
END
#################################################################
#END 