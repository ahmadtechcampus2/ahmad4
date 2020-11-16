###############################################################################

CREATE FUNCTION fnGetStrToPeriod ( @STR [NVARCHAR](max)) 
	RETURNS @Result TABLE ([STARTDATE] [DATETIME],[ENDDATE] [DATETIME])
AS 
BEGIN
	DECLARE @I [INT],@Cur [INT],@LEN [INT]
	DECLARE @StartDate [DATETIME],@EndDate [DATETIME] 	
	DECLARE @STR1 [NVARCHAR](255)
	DECLARE @STR2 [NVARCHAR](255)
	SET @I = 0
	SET @Cur = 0
	WHILE @I <= LEN(@Str)
	BEGIN
		SET @LEN = 0 
		WHILE (SUBSTRING (@Str,@I,1) <> ',') AND (@I <= LEN(@Str))
		BEGIN
			SET @LEN = @LEN + 1 
			SET @I = @I+ 1
	
		END
		SET @STR1 = SUBSTRING(@Str,@Cur,@LEN)
		
		SET @StartDate = CAST(@Str1  AS [DATETIME])
		
		SET @CUR =  @I+ 1 
		SET @I = @I+ 1 
		SET @LEN = 0 
		WHILE (SUBSTRING (@Str,@I,1) <> ',') AND (@I <= LEN(@Str))
		BEGIN
			SET @LEN = @LEN + 1 
			SET @I = @I+ 1
		END
		SET @STR2 = SUBSTRING(@Str,@Cur,@LEN)
		SET @EndDate = CAST( @STR2 AS [DATETIME])
		
		SET @CUR =  @I+ 1 
		SET @I = @I+ 1
		SET @LEN = 0 
		INSERT INTO @Result VALUES ( @StartDate,@EndDate)
	END
	RETURN

END   
###############################################################################
#END 