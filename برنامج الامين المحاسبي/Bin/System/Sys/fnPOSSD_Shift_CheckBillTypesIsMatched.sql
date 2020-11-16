#################################################################
CREATE FUNCTION fnPOSSD_Shift_CheckBillTypesIsMatched
(
	 @CurrentPOSGuid		UNIQUEIDENTIFIER,
	 @CurrentSaleBillType   UNIQUEIDENTIFIER
)
RETURNS INT
AS
BEGIN
	DECLARE @Result				INT = 0
	DECLARE @SaleBillType		UNIQUEIDENTIFIER

	SELECT @SaleBillType = SaleBillTypeGUID 
	FROM POSSDStation000
	WHERE [GUID] = @CurrentPOSGuid

	IF(@CurrentSaleBillType <> @SaleBillType)
	BEGIN
		SET @Result = 1
	END

	RETURN @Result
END
#################################################################
#END 