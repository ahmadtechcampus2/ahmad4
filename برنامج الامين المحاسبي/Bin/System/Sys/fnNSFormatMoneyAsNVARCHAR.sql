################################################################################
CREATE FUNCTION fnNSFormatMoneyAsNVARCHAR (@Number DECIMAL(20,5), @CurrencyCode NVARCHAR(50))
RETURNS   VARCHAR(100)

AS
---------------------------------------------------------------------------------
	BEGIN
	DECLARE @String VARCHAR(100)
	DECLARE @Position INT = 4
	DECLARE @AmnCfg_PricePrec INT = (SELECT CAST(Value AS INT) FROM op000 WHERE Name = 'AmnCfg_PricePrec')

	  IF(@Number IS NOT NULL)
	   BEGIN

		   SET   @String = CASE @AmnCfg_PricePrec
						   WHEN 0 THEN CONVERT(VARCHAR(50), CONVERT(DECIMAL(20,0), @Number))
						   WHEN 1 THEN CONVERT(VARCHAR(50), CONVERT(DECIMAL(20,1), @Number))
						   WHEN 2 THEN CONVERT(VARCHAR(50), CONVERT(DECIMAL(20,2), @Number))
						   WHEN 3 THEN CONVERT(VARCHAR(50), CONVERT(DECIMAL(20,3), @Number))
						   WHEN 4 THEN CONVERT(VARCHAR(50), CONVERT(DECIMAL(20,4), @Number))
						   WHEN 5 THEN CONVERT(VARCHAR(50), CONVERT(DECIMAL(20,5), @Number))
						   WHEN 6 THEN CONVERT(VARCHAR(50), CONVERT(DECIMAL(20,6), @Number))
						   ELSE CONVERT(VARCHAR(50), @Number)
						   END

		   WHILE(LEN(@String) > 3 OR CHARINDEX('.', @String) > 0) AND PATINDEX('%[,.]%', LEFT(@String, CASE WHEN @Number < 0 THEN 5 ELSE 4 END)) = 0
			  SELECT @String = STUFF(@String, CASE WHEN CHARINDEX('.', @String) > 0 THEN CHARINDEX('.', @String) 
																					ELSE LEN(@String) + 1 END - (@Position - 1), 0, ','),
					 @Position = @Position + 4


	   END

	RETURN   @String + ' ' + @CurrencyCode
	END
################################################################################
#END
