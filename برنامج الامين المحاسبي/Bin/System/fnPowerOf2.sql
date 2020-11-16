#########################################################
CREATE FUNCTION fnPowerOf2(@power [int])
RETURNS BIGINT
AS BEGIN 
	DECLARE @result [bigint],@I INT 
	-- limit power to bigint: 
	IF @power not between 0 and 62 
		SET @result = 0 
	
	ELSE BEGIN 
		-- calc power: 
		SET @I = 30 
		SET @result = 1 
		WHILE @power > 0 
		BEGIN
			IF  @power < @I
				SET @I = @power
			
			SET @result = @result * POWER( 2,@I) 
			SET @power = @power - @I 
		END 
	END 
	RETURN @result 
END 

#########################################################
#END