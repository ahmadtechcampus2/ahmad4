##########################################################
CREATE  FUNCTION fnDate_Amn2Sql( @StringDate NVARCHAR(50) )
	RETURNS DATETIME
AS BEGIN

--this function convert string date in any format
--to SQL DATETIME format

	--DECLARE
	--@DAY [NVARCHAR](2),
	--@MONTH [NVARCHAR](10),
	--@YEAR [NVARCHAR](4),
	--@DATE DATETIME = CAST(@d AS DATETIME)
	--SET @DAY = DAY(@DATE)
	--SET @MONTH = MONTH(@DATE)
	--SET @YEAR = YEAR(@DATE)
	--RETURN CAST((@YEAR + '-' + @MONTH + '-' + @DAY) AS [DATETIME])

	DECLARE @ResultDate DATETIME

	SET @ResultDate = ( CASE ISDATE(@StringDate) WHEN 1 THEN CONVERT(DATETIME, @StringDate) 
												 ELSE CONVERT(DATETIME, @StringDate, 105) 
						END )

	RETURN @ResultDate

END
#################################################
#END