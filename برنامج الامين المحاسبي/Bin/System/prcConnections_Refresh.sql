###############################################################################################
CREATE PROC prcConnections_Refresh
AS
	DECLARE
		@c CURSOR,
		@UserGUID [UNIQUEIDENTIFIER]
	
	EXEC [prcConnections_Clean]

	SET @c = CURSOR FAST_FORWARD FOR SELECT [UserGUID] FROM [connections]
	OPEN @c FETCH FROM @c INTO @UserGUID

	WHILE @@FETCH_STATUS = 0
	BEGIN
		EXEC [prcUser_BuildSecurityTable] @UserGUID
		FETCH FROM @c INTO @UserGUID
	END

	CLOSE @c DEALLOCATE @c

###############################################################################################
#END