##################################################### 
CREATE FUNCTION fnGetRolesList(@RoleGUID [UNIQUEIDENTIFIER])
	RETURNS @Result TABLE ([GUID] [UNIQUEIDENTIFIER], [Level] [INT])
AS BEGIN
/*
This function:
	- returns a list of roles descending from given @roleGuid
	- returns @roleGuid with the result.
	- never return users, only roles: this will be done by joining with roles of us000 later in the function for optimization.
*/

	DECLARE @ChildBuf TABLE([GUID] [UNIQUEIDENTIFIER], [Level] [INT], [OK] [BIT])
	DECLARE @ParentBuf TABLE ([GUID] [UNIQUEIDENTIFIER]) 
	DECLARE
		@Continue	[INT],
		@Level		[INT]

	SET @Level = 1
	INSERT INTO @ChildBuf SELECT [rtParentGUID], @Level, 0 FROM [vwRT] WHERE [rtChildGUID] = @RoleGUID

	SET @Continue = @@ROWCOUNT

	WHILE @Continue <> 0
	BEGIN 
		INSERT INTO @ParentBuf
			SELECT [rtParentGUID]
			FROM [vwRT] AS [rt] INNER JOIN @ChildBuf AS [fb] ON [rt].[rtChildGUID] = [fb].[GUID]
			WHERE [fb].[OK] = 0 AND [rt].[rtParentGUID] NOT IN (SELECT [GUID] FROM @ChildBuf)
		SET @Continue = @@ROWCOUNT
		SET @Level = @Level + 1
		UPDATE @ChildBuf SET [OK] = 1 WHERE [OK] = 0
		INSERT INTO @ChildBuf SELECT [GUID], @Level, 0 FROM @ParentBuf
		DELETE FROM @ParentBuf
	END

	-- INSERT INTO @Result VALUES(@UserGUID, 0)
	INSERT INTO @Result 
		SELECT [b].[GUID], [b].[Level]
		FROM @ChildBuf b INNER JOIN [vwUs] [u]  ON [b].[GUID] = [u].[usGUID]
		WHERE [u].[usType] = 1
	RETURN
END

#####################################################
#END