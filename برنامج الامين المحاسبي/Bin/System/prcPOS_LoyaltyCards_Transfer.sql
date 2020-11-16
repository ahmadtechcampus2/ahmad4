################################################################################
CREATE PROCEDURE prcPOS_LoyaltyCards_Transfer
	@DestDb NVARCHAR(250)
AS  
	SET NOCOUNT ON  
	DECLARE @q	NVARCHAR(250)
	IF SUBSTRING(@DestDb, 1, 1) != '['
		SET @DestDb = QUOTENAME(@DestDb)

	SET @q = 'UPDATE ' + @DestDb + '..POSLoyaltyCardSource000 SET IsActive = 0, InactivateDate = GETDATE()'
	EXEC sp_executesql @q

################################################################################
#END
