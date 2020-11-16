###############################################################################
CREATE PROCEDURE prcSO_AddTempBillItem
	@GUID				UNIQUEIDENTIFIER,
	@Number				INT,
	@MaterialGUID		UNIQUEIDENTIFIER,
	@Quantity			FLOAT,
	@Unit				INT,
	@Price				FLOAT,
	@BounsQuantity		FLOAT,
	@SOItemGUID			UNIQUEIDENTIFIER,
	@SOContractItemGUID	UNIQUEIDENTIFIER,
	@BillGUID			UNIQUEIDENTIFIER
AS
	SET NOCOUNT ON
	
INSERT INTO TempBillItems000(
	GUID,
	Number,
	MaterialGUID,
	Quantity,
	Unit,
	Price,
	BounsQuantity,
	SOItemGUID,
	SOContractItemGUID,
	BillGUID)
VALUES(
	@GUID,
	@Number,
	@MaterialGUID,
	@Quantity,
	@Unit,
	@Price,
	@BounsQuantity,
	@SOItemGUID,
	@SOContractItemGUID,
	@BillGUID)
################################################################################
#END