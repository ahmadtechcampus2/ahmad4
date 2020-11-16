###############################################################################
CREATE PROCEDURE prcBranch_GetBranchesOfBranch
	@BranchGuid		UNIQUEIDENTIFIER
AS
	SET NOCOUNT ON
	
	SELECT Guid ,name FROM br000 WHERE ParentGuid = @BranchGuid OR Guid = @BranchGuid
 
###############################################################################
#END