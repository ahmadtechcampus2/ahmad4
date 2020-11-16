#########################################################
CREATE PROCEDURE prcConnections_Add2
	@LoginName [NVARCHAR](128)
AS
	DECLARE @g [UNIQUEIDENTIFIER]
	
	SET @g = (SELECT TOP 1 [GUID] FROM [us000] WHERE [LoginName] = @LoginName)

	IF @g IS NULL
	BEGIN
		RAISERROR ('user not found ... ', 16, 1)
		RETURN
	END
	
	EXEC [prcConnections_Add] @g
	
#########################################################
#END