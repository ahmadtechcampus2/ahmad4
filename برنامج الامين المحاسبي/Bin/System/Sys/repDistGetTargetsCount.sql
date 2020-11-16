########################################
## repDistGetTargetsCount
CREATE PROCEDURE repDistGetTargetsCount
	@periodGUID UNIQUEIDENTIFIER  
AS 
	SET NOCOUNT ON
	SELECT COUNT(*) AS ROWSCOUNT INTO #RESULT FROM vwDisGeneralTarget WHERE PeriodGuid = @periodGUID
	SELECT * FROM #RESULT

#############################
#END
