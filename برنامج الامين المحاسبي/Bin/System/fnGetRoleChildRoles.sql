#########################################################
CREATE FUNCTION fnGetRoleChildRoles(@RoleGUID [UNIQUEIDENTIFIER])
		RETURNS @Result TABLE ([GUID] [UNIQUEIDENTIFIER])
AS BEGIN
	DECLARE
		@c CURSOR,
		@Role [UNIQUEIDENTIFIER]

	SET @c = CURSOR FAST_FORWARD FOR SELECT [usGUID] FROM [vwUs] WHERE [usType] = 1
	OPEN @c FETCH FROM @c INTO @Role
	WHILE @@Fetch_STATUS = 0
	BEGIN
		IF EXISTS(SELECT * FROM [fnGetUserRolesList](@Role) WHERE [GUID] = @Role)
			INSERT INTO @Result VALUES (@Role)
		FETCH FROM @c INTO @Role
	END
	CLOSE @c
	DEALLOCATE @c
	RETURN
END

#########################################################
#END