##########################################################################
CREATE FUNCTION fnCheckCloseAccount(@Acc UNIQUEIDENTIFIER, @Cust UNIQUEIDENTIFIER)
	RETURNS BIT
AS 
BEGIN
	IF @Acc != 0x0 AND @Cust = 0x0
	BEGIN
		IF NOT EXISTS(SELECT * FROM cu000 WHERE AccountGUID =  @Acc)
		BEGIN
			RETURN 0
		END

		IF NOT EXISTS(SELECT AccountGUID FROM cu000 
						GROUP BY AccountGUID
						HAVING AccountGUID = @Acc AND SUM(Debit - Credit) = 0)
		BEGIN
			RETURN 0
		END
	END

	IF NOT EXISTS(SELECT * FROM cu000 WHERE GUID = @Cust AND (Debit - Credit) = 0)
	BEGIN
		RETURN 0
	END

	RETURN 1
END
##########################################################################
#END