#########################################################
CREATE FUNCTION fnPOSSD_Driver_CheckDuplicationExtraAndMinusDriverAccount(
	@DriverGUID UNIQUEIDENTIFIER,
	@AccountGUID UNIQUEIDENTIFIER)

RETURNS BIT
AS
BEGIN

	IF EXISTS(SELECT * FROM POSSDDriver000 where (ExtraAccountGUID = @AccountGUID OR MinusAccountGUID = @AccountGUID) AND GUID != @DriverGUID)
		RETURN 1
	RETURN 0 
END	
#########################################################
#END 