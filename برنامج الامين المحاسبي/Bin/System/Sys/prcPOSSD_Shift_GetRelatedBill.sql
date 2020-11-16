#################################################################
CREATE PROCEDURE prcPOSGetBillRelatedToTheShift
-- Params -------------------------------   
	@ShiftGuid				UNIQUEIDENTIFIER,
	@BillType				INT = 0 -- 0:All, 1: Sales, 2: Purchases, 3: ReturnedSales, 4: Returned Purchases 
-----------------------------------------   
AS
    SET NOCOUNT ON
------------------------------------------------------------------------
DECLARE @SalesBillType UNIQUEIDENTIFIER,
		@SalesReturnBillType UNIQUEIDENTIFIER,
		@PurchasesBillType UNIQUEIDENTIFIER,
		@PurchasesReturnBillType UNIQUEIDENTIFIER

SELECT @SalesBillType = pos.SaleBillType,
		@SalesReturnBillType = pos.SaleReturnBillType,
		@PurchasesBillType = pos.PurchaseBillType,
		@PurchasesReturnBillType = pos.PurchaseReturnBillType 
FROM POSCard000 pos
INNER JOIN POSShift000 shifts ON shifts.[POSGuid] = pos.[Guid]
WHERE shifts.[Guid] = @ShiftGuid

SELECT BR.BillGUID  AS BillGuid,
	   BU.Number    AS BillNumber,
	   BU.TypeGUID  AS BillTypeGuid
		
FROM  BillRel000 BR 
INNER JOIN bu000 BU ON BR.BillGUID = BU.[GUID]
WHERE ParentGUID     = @ShiftGuid 
AND 
(
	@BillType = 0
	OR (@BillType = 1 AND @SalesBillType = BU.[TypeGUID])
	OR (@BillType = 2 AND @PurchasesBillType = BU.[TypeGUID])
	OR (@BillType = 3 AND @SalesReturnBillType = BU.[TypeGUID])
	OR (@BillType = 4 AND @PurchasesReturnBillType = BU.[TypeGUID])
) 
#################################################################
#END
