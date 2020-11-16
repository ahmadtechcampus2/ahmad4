#########################################################
CREATE FUNCTION fnBranch_getDefaultMask()
	RETURNS [BIGINT]
AS
BEGIN
	DECLARE @result [BIGINT]

	IF EXISTS(SELECT * FROM [vbBr])
		SET @result = (SELECT TOP 1 [branchMask] FROM [vbBr] ORDER BY [Number])
	ELSE
		SET @result = (SELECT TOP 1 [branchMask] FROM [vtBr] ORDER BY [Number])

	RETURN ISNULL(@result, 0)
END

#########################################################
#END  