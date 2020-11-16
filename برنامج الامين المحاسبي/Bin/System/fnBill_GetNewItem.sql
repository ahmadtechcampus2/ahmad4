#########################################################
CREATE FUNCTION fnBill_GetNewNum(@TypeGUID UNIQUEIDENTIFIER, @BranchGUID UNIQUEIDENTIFIER = NULL)
	RETURNS INT
AS BEGIN
	IF ISNULL(@BranchGUID, 0x0) = 0x0
		RETURN ISNULL((SELECT MAX(Number) FROM bu000 WHERE TypeGUID = @TypeGUID), 0) + 1
	RETURN ISNULL((SELECT MAX(Number) FROM bu000 WHERE TypeGUID = @TypeGUID AND Branch = @BranchGUID), 0) + 1
 END

#########################################################
#END 