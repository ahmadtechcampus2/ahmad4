#########################################################
CREATE FUNCTION fnGetUserRolesList(@UserGUID [UNIQUEIDENTIFIER] = 0x0)
	RETURNS @Result TABLE (GUID [UNIQUEIDENTIFIER], [Level] [INT])
AS BEGIN 
	DECLARE @ChildBuf TABLE([GUID] [UNIQUEIDENTIFIER],[Level] [INT], [OK] [BIT])
	DECLARE @ParentBuf TABLE ([GUID] [UNIQUEIDENTIFIER]) 
	DECLARE
		@Continue [INT],
		@Level [INT]

	IF ISNULL(@UserGUID, 0x0) = 0x0
		SET @userGuid = [dbo].[fnGetCurrentUserGuid]()

	SET @Level = 1
	INSERT INTO @ChildBuf SELECT [rtParentGUID], @Level, 0 FROM [vwRT] WHERE [rtChildGUID] = @UserGUID
	SET	@Continue = @@ROWCOUNT

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
	INSERT INTO @Result SELECT [GUID], [Level] FROM @ChildBuf
	RETURN 
END

#########################################################
#END