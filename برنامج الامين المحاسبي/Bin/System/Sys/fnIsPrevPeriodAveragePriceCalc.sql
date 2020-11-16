###########################################################################
CREATE FUNCTION fnIsPrevPeriodAveragePriceCalc(@StartPeriod DATE)
RETURNS BIT
AS
BEGIN
	RETURN (SELECT CASE WHEN EXISTS(SELECT * FROM oap000 WHERE StartDate < @StartPeriod) THEN 1 ELSE 0 END);
END
###########################################################################

###########################################################################
#END