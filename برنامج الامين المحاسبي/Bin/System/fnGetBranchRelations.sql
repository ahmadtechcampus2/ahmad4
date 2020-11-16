##########################################################################################
CREATE FUNCTION fnGetBranchRelations (@BranchGUID UNIQUEIDENTIFIER)
	RETURNS TABLE
AS
	RETURN (SELECT * FROM bl000 WHERE BranchGUID = @BranchGUID)

##########################################################################################
#END