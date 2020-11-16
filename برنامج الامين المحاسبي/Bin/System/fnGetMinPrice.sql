###############################################################################
CREATE FUNCTION fnGetMinPrice(
		@BillType	[UNIQUEIDENTIFIER],
		@UserGuid	[UNIQUEIDENTIFIER])
RETURNS [FLOAT]
AS  
BEGIN 
	DECLARE @MinPrice INT
	
	SET @MinPrice = ( SELECT MinPrice FROM UserMaxDiscounts000 umd
	WHERE umd.BillTypeGUID = @BillType
	AND umd.UserGUID = @UserGuid)
	
	IF( ISNULL( @MinPrice,0) = 0)
		SET @MinPrice = ( SELECT MinPrice FROM us000 u WHERE u.GUID =@UserGuid)
		
	RETURN @MinPrice
END 
###############################################################################
#END