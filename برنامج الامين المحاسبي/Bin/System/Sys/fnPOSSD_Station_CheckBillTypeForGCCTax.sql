#################################################################
CREATE FUNCTION fnPOSSD_Station_CheckBillTypeForGCCTax
(
	 @BillType   UNIQUEIDENTIFIER
)
RETURNS BIT
AS
BEGIN
	DECLARE @Result				     BIT = 1
	DECLARE @UseExciseTax		     BIT = 1
	DECLARE @AssignedCustomer	     UNIQUEIDENTIFIER = 0x0
	DECLARE @CustomerGCCLocationGUID UNIQUEIDENTIFIER = 0x0
	

	SELECT 
		@AssignedCustomer		 = ISNULL(BT.CustAccGuid, 0x0), 
		@CustomerGCCLocationGUID = ISNULL(CU.GCCLocationGUID, 0x0),
		@UseExciseTax			 = BT.UseExciseTax 
	FROM 
		bt000 BT
		INNER JOIN cu000 CU ON BT.CustAccGuid = CU.[GUID]
	WHERE 
		BT.[GUID] = @BillType


	IF(@AssignedCustomer = 0x0 OR @CustomerGCCLocationGUID = 0x0 OR @UseExciseTax = 1)
	BEGIN
		SET @Result = 0
	END

	RETURN @Result
END
#################################################################
#END 