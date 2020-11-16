######################
CREATE PROCEDURE prcGetBranchesOfBranch
	@BranchGuid		UNIQUEIDENTIFIER
AS
	SELECT Guid ,name FROM br000 WHERE ParentGuid = @BranchGuid OR Guid = @BranchGuid
 
 ######################
 #END