#############################################
CREATE FUNCTION fnPOSSD_Station_GetCustomerArea
-- Param ----------------------------------------------------------
	  ( @DebitAccountGUID UNIQUEIDENTIFIER )
-- Return ----------------------------------------------------------
RETURNS @Result TABLE([GUID] UNIQUEIDENTIFIER, Area NVARCHAR(50))
--------------------------------------------------------------------
AS 
BEGIN
	
	INSERT INTO @Result
	SELECT
		[GUID], 
		Name
	FROM 
		AddressArea000

	RETURN
END
##############################################
#END
