##########################################################################
CREATE FUNCTION fnGetUserNotesSec(@UserGUID [UNIQUEIDENTIFIER])
	RETURNS @Result TABLE([GUID] [UNIQUEIDENTIFIER], [BrowseSec] [INT], [EnterSec] [INT], [ModifySec] [INT], [DeleteSec] [INT])
AS BEGIN
	SET @UserGUID = ISNULL(@UserGUID, [dbo].[fnGetCurrentUserGUID]())
	IF [dbo].[fnIsAdmin](@UserGUID) = 0
		INSERT INTO @Result
			SELECT
				[nt].[ntGuid],
				[dbo].[fnGetUserNoteSec_Browse]	(@UserGUID, [ntGUID]), -- (SELECT uiPermission FROM vwUIX WHERE uiSystem = 1 AND uiSubID = nt.ntGUID AND uiUserGUID = @UserGUID AND uiPermType = 1),	-- Browse
				[dbo].[fnGetUserNoteSec_Enter]		(@UserGUID, [ntGUID]), -- (SELECT uiPermission FROM vwUIX WHERE uiSystem = 1 AND uiSubID = nt.ntGUID AND uiUserGUID = @UserGUID AND uiPermType = 0),	-- Enter
				[dbo].[fnGetUserNoteSec_Modify]		(@UserGUID, [ntGUID]), -- (SELECT uiPermission FROM vwUIX WHERE uiSystem = 1 AND uiSubID = nt.ntGUID AND uiUserGUID = @UserGUID AND uiPermType = 2),	-- Modify
				[dbo].[fnGetUserNoteSec_Delete]		(@UserGUID, [ntGUID]) -- (SELECT uiPermission FROM vwUIX WHERE uiSystem = 1 AND uiSubID = nt.ntGUID AND uiUserGUID = @UserGUID AND uiPermType = 3)	-- Delete
			FROM [vwNT] AS [nt]
	ELSE BEGIN
		DECLARE @msl [INT]
		SET @msl = [dbo].[fnGetMaxSecurityLevel]()
		INSERT INTO @Result
			SELECT [ntGUID], @msl, @msl, @msl, @msl FROM [vwNT]
	END
	RETURN
END

##########################################################################
#END