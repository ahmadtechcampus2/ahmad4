#########################################################
CREATE FUNCTION fnAccCustLastCheckDate
	(
	@Acc UNIQUEIDENTIFIER = 0x0,
	@Cust UNIQUEIDENTIFIER = 0x0
	)
RETURNS DATETIME 

AS 
BEGIN
  RETURN( 
	SELECT TOP 1 CheckedToDate  
	FROM CheckAcc000
	WHERE
		ISNULL(AccGUID, 0x0) = CASE WHEN ISNULL(@Acc, 0x0) <> 0x0 THEN ISNULL(@Acc, 0x0) ELSE ISNULL(AccGUID, 0x0)END 
		AND ISNULL(CustGUID, 0x0) = CASE WHEN ISNULL(@Cust, 0x0)  <> 0x0 THEN ISNULL(@Cust, 0x0) ELSE ISNULL(CustGUID, 0x0)END 
	ORDER BY
		CheckedToDate DESC
	)
END 
#########################################################
CREATE FUNCTION fnGetLastCheckInfo(@CustGuid UNIQUEIDENTIFIER, @AccGuid UNIQUEIDENTIFIER)
RETURNS TABLE
AS	
	RETURN
	(
		SELECT TOP(1) Notes, CheckedToDate 
		FROM CheckAcc000 C
		WHERE C.CustGUID = @CustGuid OR C.AccGUID = @AccGuid
		ORDER BY CheckedToDate DESC
	)
#########################################################
#END