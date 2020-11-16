#################################
CREATE PROCEDURE prcBranch_getCurrentUserReadMask( @withConnectionBranchMask [bit] = 1)
AS 
	SET NOCOUNT ON
	
	SELECT * FROM [fnBranch_getCurrentUserReadMask]( @withConnectionBranchMask)


##############################################################
#END 