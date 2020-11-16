#########################################################
CREATE FUNCTION fnBranch_getCurrentUserReadMask(@withConnectionBranchMask [bit] = 1)
	RETURNS @result TABLE([mask] [BIGINT])

AS BEGIN
/*
this function:
	- returns currenct connections' branch mask after crossing it with the connection choosen branches, if specified in @withConnectionBranchMask
*/
		INSERT INTO @result SELECT [dbo].[fnBranch_getCurrentUserReadMask_scalar](@withConnectionBranchMask)

	RETURN
END

-- select * from fnBranch_getCurrentUserReadMask()

#########################################################
#END