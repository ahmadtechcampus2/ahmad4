#########################################################
CREATE FUNCTION fnBranch_getCurrentUserReadMask_scalar(@withConnectionBranchMask [bit] = 1)
	RETURNS [BIGINT]
AS BEGIN
/*
this function:
	- is the scalar version of fnBranch_getCurrentUserMask.
	-  is used in WHERE clauses of vcXXXs rendering the views writable.
	- 
*/
	RETURN (
				SELECT 
							CASE @withConnectionBranchMask
								WHEN 1 THEN [usBranchReadMask] & [dbo].[fnConnections_getBranchMask]()
								ELSE [usBranchReadMask]
							END
				FROM [vwUSX_OfCurrentUser])
END

-- select dbo.fnBranch_getCurrentUserReadMask_scalar(default)
-- select dbo.fnBranch_getCurrentUserReadMask_scalar(0)

#########################################################
#END