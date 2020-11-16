################################################################################
CREATE PROCEDURE prcPOSSD_GCC_GetTaxCode (@POSStationGUID UNIQUEIDENTIFIER)	
AS
BEGIN
	/*******************************************************************************************************
	Company : Syriansoft
	SP : prcPOSSD_GCC_GetTaxCode
	Purpose: get all the GCC TaxCode list that are related to a specific POS Station
	How to Call: EXEC prcPOSSD_GCC_GetTaxCode '3C2561FE-406C-446D-AFE3-6212319487F8'
	Create By: Hanadi Salka													Created On: 11 July 2019
	Updated On:																Updated By:
	Change Note:
	********************************************************************************************************/
	DECLARE @Groups TABLE
	(
		Number int ,
		GroupGUID UNIQUEIDENTIFIER,  
		Name NVARCHAR(MAX),
		Code NVARCHAR(MAX),
		ParentGUID UNIQUEIDENTIFIER,  
		LatinName  NVARCHAR(MAX),
		PictureGUID UNIQUEIDENTIFIER,
		GroupIndex	INT,
		Groupkind	TINYINT
	);
	DECLARE @debitAccountGuid					UNIQUEIDENTIFIER = NULL;
	DECLARE @SaleBillTypeCustGUID				UNIQUEIDENTIFIER = NULL;
	DECLARE @PurchaseBillTypeCustGUID			UNIQUEIDENTIFIER = NULL;
	DECLARE @SaleReturnBillTypeCustGUID			UNIQUEIDENTIFIER = NULL;
	DECLARE @PurchaseReturnBillTypeCustGUID		UNIQUEIDENTIFIER = NULL;
	-- *******************************************************************************************
	-- Get the group related to the pos station
	INSERT INTO @Groups (Number,GroupGUID, Name,Code, ParentGUID, LatinName, PictureGUID, GroupIndex, Groupkind)
	EXEC prcPOSSD_Station_GetGroups @POSStationGUID;		
	
	SELECT 
		@debitAccountGuid = DebitAccGUID 
	FROM POSSDStation000 WHERE [GUID] = @POSStationGUID;
	

	SELECT 
		@SaleBillTypeCustGUID = BT.CustAccGuid
	FROM POSSDStation000 PC LEFT JOIN bt000 AS BT ON (BT.GUID = PC.SaleBillTypeGUID);

	SELECT 
		@PurchaseBillTypeCustGUID = BT.CustAccGuid
	FROM POSSDStation000 PC LEFT JOIN bt000 AS BT ON (BT.GUID = PC.PurchaseBillTypeGUID);

	SELECT 
		@SaleReturnBillTypeCustGUID = BT.CustAccGuid
	FROM POSSDStation000 PC LEFT JOIN bt000 AS BT ON (BT.GUID = PC.SaleReturnBillTypeGUID);

	SELECT 
		@PurchaseReturnBillTypeCustGUID = BT.CustAccGuid
	FROM POSSDStation000 PC LEFT JOIN bt000 AS BT ON (BT.GUID = PC.PurchaseReturnBillTypeGUID);


	/*if(@debitAccountGuid = 0x00 OR @debitAccountGuid = NULL)
		return;*/

	SELECT 
		GCCTC.*
	FROM dbo.fnGetAccountsList(@debitAccountGuid, 0) AS CUACC  INNER JOIN vexCu AS CU ON (CU.AccountGUID = CUACC.GUID)
	INNER JOIN GCCCustomerTax000  AS GCCCU  ON (GCCCU.CustGUID = CU.GUID)
	INNER JOIN GCCTaxCoding000 AS GCCTC ON (GCCTC.TaxCode = GCCCU.TaxCode AND GCCTC.TaxType = GCCCU.TaxType)
	UNION 
	SELECT 
		GCCTC.*
	FROM vexCu AS CU 
	INNER JOIN GCCCustomerTax000  AS GCCCU  ON (GCCCU.CustGUID = CU.GUID)
	INNER JOIN GCCTaxCoding000 AS GCCTC ON (GCCTC.TaxCode = GCCCU.TaxCode AND GCCTC.TaxType = GCCCU.TaxType)
	WHERE CU.GUID = @SaleBillTypeCustGUID
	UNION 
	SELECT 
		GCCTC.*
	FROM vexCu AS CU 
	INNER JOIN GCCCustomerTax000  AS GCCCU  ON (GCCCU.CustGUID = CU.GUID)
	INNER JOIN GCCTaxCoding000 AS GCCTC ON (GCCTC.TaxCode = GCCCU.TaxCode AND GCCTC.TaxType = GCCCU.TaxType)
	WHERE CU.GUID = @PurchaseBillTypeCustGUID
	UNION 
	SELECT 
		GCCTC.*
	FROM vexCu AS CU 
	INNER JOIN GCCCustomerTax000  AS GCCCU  ON (GCCCU.CustGUID = CU.GUID)
	INNER JOIN GCCTaxCoding000 AS GCCTC ON (GCCTC.TaxCode = GCCCU.TaxCode AND GCCTC.TaxType = GCCCU.TaxType)
	WHERE CU.GUID = @SaleReturnBillTypeCustGUID
	UNION 
	SELECT 
		GCCTC.*
	FROM vexCu AS CU 
	INNER JOIN GCCCustomerTax000  AS GCCCU  ON (GCCCU.CustGUID = CU.GUID)
	INNER JOIN GCCTaxCoding000 AS GCCTC ON (GCCTC.TaxCode = GCCCU.TaxCode AND GCCTC.TaxType = GCCCU.TaxType)
	WHERE CU.GUID =  @PurchaseReturnBillTypeCustGUID
	UNION 
	SELECT 
		GCCTC.*
	FROM mt000 AS MT INNER JOIN @Groups AS GR ON (GR.GroupGUID = MT.GroupGUID)
	INNER JOIN GCCMaterialTax000 AS GCCMT ON (GCCMT.MatGUID = MT.GUID)
	INNER JOIN GCCTaxCoding000 AS GCCTC ON (GCCTC.TaxCode = GCCMT.TaxCode AND GCCTC.TaxType = GCCMT.TaxType);
END
#################################################################
CREATE PROCEDURE prcPOSSD_GCC_GetLocation (@POSStationGUID UNIQUEIDENTIFIER)	
AS
BEGIN
	/*******************************************************************************************************
	Company : Syriansoft
	SP : prcPOSSD_GCC_GetLocation
	Purpose: get all the GCC Locations that are related to a specific POS Station
	How to Call: EXEC prcPOSSD_GCC_GetLocation '3C2561FE-406C-446D-AFE3-6212319487F8'
	Create By: Hanadi Salka													Created On: 11 July 2019
	Updated On:																Updated By:
	Change Note:
	********************************************************************************************************/
	DECLARE @debitAccountGuid					UNIQUEIDENTIFIER = NULL;
	DECLARE @SaleBillTypeCustGUID				UNIQUEIDENTIFIER = NULL;
	DECLARE @PurchaseBillTypeCustGUID			UNIQUEIDENTIFIER = NULL;
	DECLARE @SaleReturnBillTypeCustGUID			UNIQUEIDENTIFIER = NULL;
	DECLARE @PurchaseReturnBillTypeCustGUID		UNIQUEIDENTIFIER = NULL;

	SELECT 
		@SaleBillTypeCustGUID = BT.CustAccGuid
	FROM POSSDStation000 PC LEFT JOIN bt000 AS BT ON (BT.GUID = PC.SaleBillTypeGUID);

	SELECT 
		@PurchaseBillTypeCustGUID = BT.CustAccGuid
	FROM POSSDStation000 PC LEFT JOIN bt000 AS BT ON (BT.GUID = PC.PurchaseBillTypeGUID);

	SELECT 
		@SaleReturnBillTypeCustGUID = BT.CustAccGuid
	FROM POSSDStation000 PC LEFT JOIN bt000 AS BT ON (BT.GUID = PC.SaleReturnBillTypeGUID);

	SELECT 
		@PurchaseReturnBillTypeCustGUID = BT.CustAccGuid
	FROM POSSDStation000 PC LEFT JOIN bt000 AS BT ON (BT.GUID = PC.PurchaseReturnBillTypeGUID);

	SELECT 
		@debitAccountGuid = DebitAccGUID 
	FROM POSSDStation000 WHERE [GUID] = @POSStationGUID;
	

	/*if(@debitAccountGuid = 0x00 OR @debitAccountGuid = NULL)
		return;*/
	
	SELECT 
		GCCLOC.GUID,		
		GCCLOC.Name,
		GCCLOC.LatinName
	FROM dbo.fnGetAccountsList(@debitAccountGuid, 0) AS CUACC  INNER JOIN vexCu AS CU ON (CU.AccountGUID = CUACC.GUID)
	INNER JOIN  GCCCustLocations000 AS GCCLOC ON (CU.GCCLocationGUID = GCCLOC.GUID)
	UNION 
	SELECT 
		GCCLOC.GUID,		
		GCCLOC.Name,
		GCCLOC.LatinName
	FROM vexCu AS CU 
	INNER JOIN  GCCCustLocations000 AS GCCLOC ON (CU.GCCLocationGUID = GCCLOC.GUID)
	WHERE CU.GUID = @SaleBillTypeCustGUID
	UNION 
	SELECT 
		GCCLOC.GUID,		
		GCCLOC.Name,
		GCCLOC.LatinName
	FROM vexCu AS CU 
	INNER JOIN  GCCCustLocations000 AS GCCLOC ON (CU.GCCLocationGUID = GCCLOC.GUID)
	WHERE CU.GUID = @PurchaseBillTypeCustGUID
	UNION 
	SELECT 
		GCCLOC.GUID,		
		GCCLOC.Name,
		GCCLOC.LatinName
	FROM vexCu AS CU 
	INNER JOIN  GCCCustLocations000 AS GCCLOC ON (CU.GCCLocationGUID = GCCLOC.GUID)
	WHERE CU.GUID = @SaleReturnBillTypeCustGUID
	UNION 
	SELECT 
		GCCLOC.GUID,		
		GCCLOC.Name,
		GCCLOC.LatinName
	FROM vexCu AS CU 
	INNER JOIN  GCCCustLocations000 AS GCCLOC ON (CU.GCCLocationGUID = GCCLOC.GUID)
	WHERE CU.GUID = @PurchaseReturnBillTypeCustGUID;
END
#################################################################
#END
