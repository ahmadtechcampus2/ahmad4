################################################################################################
CREATE FUNCTION fnGetDateFromDT(@DT [DATETIME])
	RETURNS [DATETIME]
AS BEGIN
	RETURN 
		CAST(CAST(YEAR(@DT) AS [NVARCHAR](4)) + '-' + CAST(MONTH(@DT) AS [NVARCHAR](4)) + '-' + CAST(DAY(@DT) AS [NVARCHAR](4)) AS [DATETIME])
END
################################################################################################
CREATE FUNCTION fnGetDateFromTime(@d DATETIME)
RETURNS DATETIME
AS
BEGIN
	DECLARE @S NVARCHAR(20)
	SET @S =  CAST(DATEPART(m, @d) AS NVARCHAR(2)) +'/'+  CAST(DATEPART(d, @d) AS NVARCHAR(2)) +'/'+ CAST(DATEPART(yy, @d) AS NVARCHAR(4))
	RETURN CAST(@S AS DATETIME)
END
################################################################################################
#END