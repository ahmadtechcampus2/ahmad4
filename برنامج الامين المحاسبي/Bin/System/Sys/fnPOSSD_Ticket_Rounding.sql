################################################################################
CREATE FUNCTION fnPOSSD_Ticket_Rounding
-- Param ----------------------------------------------------------
	  ( @Value FLOAT,
	    @RoundingPrecision FLOAT )
-- Return ----------------------------------------------------------
RETURNS @Result TABLE(RoundingUp FLOAT, RoundingDown FLOAT)
--------------------------------------------------------------------
AS 
BEGIN
	
	IF(@RoundingPrecision = 0)
	BEGIN
		INSERT INTO @Result
		SELECT 0, 0
		RETURN
	END


	INSERT INTO @Result
	SELECT 
		CEILING(@Value / @RoundingPrecision) * @RoundingPrecision,
		FLOOR  (@Value / @RoundingPrecision) * @RoundingPrecision 
	
	RETURN
END
#################################################################
#END
