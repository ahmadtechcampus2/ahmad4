#########################################################
CREATE FUNCTION fnBill_getNewNum(@TypeGUID [UNIQUEIDENTIFIER], @BranchGUID [UNIQUEIDENTIFIER] = NULL)
	RETURNS [INT]
AS BEGIN
	DECLARE @result [INT]

	IF ISNULL(@BranchGUID, 0x0) = 0x0
		SET @result = ISNULL((SELECT MAX([Number]) FROM [bu000] WHERE [TypeGUID] = @TypeGUID), 0) + 1
	ELSE
		SET @result = ISNULL((SELECT MAX([Number]) FROM [bu000] WHERE [TypeGUID] = @TypeGUID AND [Branch] = @BranchGUID), 0) + 1

	RETURN @result
 END
#########################################################
#END