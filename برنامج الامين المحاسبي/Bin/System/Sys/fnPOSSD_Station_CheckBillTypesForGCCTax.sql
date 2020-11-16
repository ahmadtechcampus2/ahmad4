#################################################################
CREATE FUNCTION fnPOSSD_Station_CheckBillTypesForGCCTax
(
	 @StationGUID   UNIQUEIDENTIFIER
)
RETURNS BIT
AS
BEGIN

	DECLARE @saleBillType		    UNIQUEIDENTIFIER
	DECLARE @saleReturnBillType	    UNIQUEIDENTIFIER
	DECLARE @PurchaseBillType       UNIQUEIDENTIFIER
	DECLARE @PurchaseReturnBillType UNIQUEIDENTIFIER

	SELECT 
		@saleBillType			= ISNULL(SaleBillTypeGUID, 0x0), 
		@saleReturnBillType     = ISNULL(SaleReturnBillTypeGUID, 0x0),
		@PurchaseBillType		= ISNULL(PurchaseBillTypeGUID, 0x0),
		@PurchaseReturnBillType = ISNULL(PurchaseReturnBillTypeGUID, 0x0)
	FROM 
		POSSDStation000 
	WHERE 
		[GUID] = @StationGUID


	IF((SELECT [dbo].fnPOSSD_Station_CheckBillTypeForGCCTax(@saleBillType)) = 0 AND @saleBillType != 0x0)
	BEGIN
		RETURN 0
	END

	IF((SELECT [dbo].fnPOSSD_Station_CheckBillTypeForGCCTax(@saleReturnBillType)) = 0 AND @saleReturnBillType != 0x0)
	BEGIN
		RETURN 0
	END

	--IF((SELECT [dbo].fnPOSSD_Station_CheckBillTypeForGCCTax(@PurchaseBillType)) = 0 AND @PurchaseBillType != 0x0)
	--BEGIN
	--	RETURN 0
	--END

	--IF((SELECT [dbo].fnPOSSD_Station_CheckBillTypeForGCCTax(@PurchaseReturnBillType)) = 0 AND @PurchaseReturnBillType != 0x0)
	--BEGIN
	--	RETURN 0
	--END

	RETURN 1
END
#################################################################
#END 