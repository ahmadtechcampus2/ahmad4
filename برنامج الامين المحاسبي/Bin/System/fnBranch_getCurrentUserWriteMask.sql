#########################################################
CREATE FUNCTION fnBranch_getCurrentUserWriteMask()
	RETURNS @result TABLE([mask] [BIGINT])

AS BEGIN
	INSERT INTO @result SELECT [dbo].[fnBranch_getCurrentUserWriteMask_scalar]()

	RETURN
END

-- select * from fnBranch_getCurrentUserWriteMask()

#########################################################
#END