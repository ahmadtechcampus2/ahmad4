#########################################################
CREATE FUNCTION fnBranch_getDefaultGuid()
	RETURNS [UNIQUEIDENTIFIER]
AS
BEGIN
	DECLARE @result [UNIQUEIDENTIFIER]

	IF EXISTS(SELECT * FROM [vbBr])
		SET @result = (SELECT TOP 1 [GUID] FROM [vbBr] ORDER BY [Number]) 
	ELSE
		SET @result = (SELECT TOP 1 [GUID] FROM [vtBr] ORDER BY [Number])

	RETURN ISNULL(@result, 0x0)
END

#########################################################
#END 