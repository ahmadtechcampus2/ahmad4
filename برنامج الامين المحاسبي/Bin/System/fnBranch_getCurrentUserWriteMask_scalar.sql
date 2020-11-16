#########################################################
CREATE FUNCTION fnBranch_getCurrentUserWriteMask_scalar()
	RETURNS [BIGINT]
AS BEGIN
/*
	- this is a scalar version of fnBranch_getCurrentUserMask.
	- it is used in WHERE clauses of vcXXXs rendering the views writable.
*/
	RETURN (SELECT [usBranchWriteMask] FROM [vwUSX_OfCurrentUser])
END

-- select dbo.fnBranch_getCurrentUserWriteMask_scalar()

#########################################################
CREATE FUNCTION fnGetUserBranchMask()
	RETURNS [BIGINT] 
AS BEGIN 
	return (SELECT usBranchReadMask FROM vwUSX_OfCurrentUser)
END
#########################################################
#END 