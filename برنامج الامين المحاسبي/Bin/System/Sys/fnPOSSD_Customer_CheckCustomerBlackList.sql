################################################################################
CREATE FUNCTION fnPOSSD_Customer_CheckCustomerBlackList(
	@CustomerGUID UNIQUEIDENTIFIER)

RETURNS BIT
AS
BEGIN
	IF EXISTS(SELECT * FROM POSSDOrderBlacklist000 WHERE CustomerGUID = @CustomerGUID)
		RETURN 1
	RETURN 0 
END	
#################################################################
#END
