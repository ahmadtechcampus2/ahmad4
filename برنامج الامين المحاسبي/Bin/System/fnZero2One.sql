###########################################################################
CREATE FUNCTION Zero2One(@Value [FLOAT])
	RETURNS [FLOAT]
AS BEGIN
	IF ISNULL(@Value, 0) = 0
		RETURN 0
	RETURN @Value
END

###########################################################################
#END