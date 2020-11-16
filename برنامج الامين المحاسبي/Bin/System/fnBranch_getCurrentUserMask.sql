#########################################################
CREATE FUNCTION fnBranch_getCurrentUserMask()
	RETURNS @result TABLE(mask BIGINT)

AS BEGIN
	INSERT INTO @result SELECT dbo.fnBranch_getCurrentUserMask_scalar()

	RETURN
END

-- select * from fnBranch_getCurrentUserMask()

#########################################################
#END