###############################################################################
CREATE PROCEDURE prcSO_AddTempBill
	@GUID			UNIQUEIDENTIFIER,
	@Date			DATETIME,
	@CustGUID	UNIQUEIDENTIFIER,
	@BillTypeGUID	UNIQUEIDENTIFIER,
	@CostGUID		UNIQUEIDENTIFIER,
	@CurrencyGUID	UNIQUEIDENTIFIER
AS
	SET NOCOUNT ON

INSERT INTO [TempBills000](
	[GUID],
	[Date],
	[CustomerGUID],
	[BillTypeGUID],
	[CostGUID],
	[HostName],
	[HostId],
	[CurrencyGUID])
VALUES(
	@GUID,
	@Date,
	@CustGUID,
	@BillTypeGUID,
	@CostGUID,
	HOST_NAME(),
	HOST_ID(),
	@CurrencyGUID)
################################################################################
#END