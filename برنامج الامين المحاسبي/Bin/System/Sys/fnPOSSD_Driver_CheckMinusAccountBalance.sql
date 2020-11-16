#################################################################
CREATE FUNCTION fnPOSSD_Driver_CheckMinusAccountBalance
-- Param ------------------------------------------------
		( @DriverGuid     UNIQUEIDENTIFIER )
-- Return -----------------------------------------------
RETURNS BIT
---------------------------------------------------------
AS
BEGIN
	
	DECLARE @Result						BIT   = 1
	DECLARE @DriverMinusInOpenShift		FLOAT = 0
	DECLARE @DriverIncreaseInOpenShift	FLOAT = 0

	SELECT 
		@DriverMinusInOpenShift	   = SUM((CASE EO.IsPayment WHEN 1 THEN 1 ELSE 0 END) * EO.Amount),
		@DriverIncreaseInOpenShift = SUM((CASE EO.IsPayment WHEN 0 THEN 1 ELSE 0 END) * EO.Amount)
	FROM 
		POSSDShift000 SH
		INNER JOIN POSSDExternalOperation000 EO ON SH.[GUID] = EO.ShiftGUID
	WHERE 
		SH.CloseDate IS NULL
		AND EO.[Type] = 11
		AND RelatedToGUID = @DriverGuid

	 
	 SELECT 
		@Result = CASE WHEN D.MinusLimitValue <= (@DriverMinusInOpenShift + dbo.fnAccount_getBalance(AC.[GUID], DEFAULT, DEFAULT, DEFAULT, DEFAULT)) - @DriverIncreaseInOpenShift THEN 0 ELSE 1 END
	 FROM 
		POSSDDriver000 D 
		INNER JOIN ac000 AC on D.MinusAccountGUID = AC.[GUID]
	 WHERE
		D.[GUID] = @DriverGuid


	RETURN @Result

	
END
#################################################################
#END
