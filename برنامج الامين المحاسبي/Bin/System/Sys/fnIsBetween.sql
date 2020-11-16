############################################
CREATE FUNCTION fnIsBetween(@Date DATETIME,
		@Start DATETIME, @END DATETIME)
	RETURNS BIT
AS BEGIN

IF (YEAR(@Date) < YEAR (@Start)) 
	OR ((YEAR(@Date) = YEAR (@Start)) AND (MONTH(@Date) < MONTH(@Start)))
	OR ((YEAR(@Date) = YEAR (@Start)) AND (MONTH(@Date) = MONTH(@Start)) AND (DAY(@Date)<DAY(@Start)))
BEGIN
	RETURN 0
END

IF (YEAR(@Date) > YEAR (@END)) 
	OR ((YEAR(@Date) = YEAR (@END)) AND (MONTH(@Date) > MONTH(@END)))
	OR ((YEAR(@Date) = YEAR (@END)) AND (MONTH(@Date) = MONTH(@END)) AND (DAY(@Date)>DAY(@END)))
BEGIN
	RETURN 0
END
RETURN 1
END
############################################
#END