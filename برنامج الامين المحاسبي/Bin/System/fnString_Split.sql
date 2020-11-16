###########################################################################
CREATE FUNCTION fnString_Split( @str NVARCHAR(max), @char NVARCHAR(10) = ',')
	RETURNS @Result TABLE ( SubStr NVARCHAR(250) COLLATE ARABIC_CI_AI)
AS BEGIN 
	DECLARE 
		@StratIndex INT, 
		@EndIndex INT

	SET @EndIndex = CHARINDEX( @char, @str)
	IF @EndIndex = 0
	BEGIN 
		INSERT INTO @Result SELECT @str
	END ELSE BEGIN 
		SET @StratIndex = 0

		WHILE @EndIndex != 0
		BEGIN 
			INSERT INTO @Result SELECT RTRIM( LTRIM( SUBSTRING( @str, @StratIndex, @EndIndex-@StratIndex)))
			SET @StratIndex = @EndIndex + 1
			SET @EndIndex = CHARINDEX( @char, @str, @StratIndex)
		END
		INSERT INTO @Result SELECT RTRIM( LTRIM( SUBSTRING( @str, @StratIndex, LEN(@str)-@StratIndex+1)))
	END
	RETURN 
END 
###########################################################################
#END
