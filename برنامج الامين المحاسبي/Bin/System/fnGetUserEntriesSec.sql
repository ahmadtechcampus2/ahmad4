##########################################################################
CREATE FUNCTION fnGetUserEntriesSec(@UserGUID [UNIQUEIDENTIFIER])
	RETURNS @Result TABLE([GUID] [UNIQUEIDENTIFIER], [BrowseSec] [INT], [EnterSec] [INT], [ModifySec] [INT], [DeleteSec] [INT], [PostSec] [INT])
AS BEGIN
	SET @UserGUID = ISNULL(@UserGUID, [dbo].[fnGetCurrentUserGUID]())

	INSERT INTO @Result
		SELECT 
			[et].[etGuid],
			[dbo].[fnGetUserEntrySec_Browse]	(@UserGUID, [etGUID]), -- (SELECT uiPermission FROM vwUIX WHERE uiSystem = 1 AND uiSubID = et.etGUID AND uiUserGUID = @UserGUID AND uiPermType = 1),	-- Browse
			[dbo].[fnGetUserEntrySec_Enter]		(@UserGUID, [etGUID]), -- (SELECT uiPermission FROM vwUIX WHERE uiSystem = 1 AND uiSubID = et.etGUID AND uiUserGUID = @UserGUID AND uiPermType = 0),	-- Enter
			[dbo].[fnGetUserEntrySec_Modify]	(@UserGUID, [etGUID]), -- (SELECT uiPermission FROM vwUIX WHERE uiSystem = 1 AND uiSubID = et.etGUID AND uiUserGUID = @UserGUID AND uiPermType = 2),	-- Modify
			[dbo].[fnGetUserEntrySec_Delete]	(@UserGUID, [etGUID]), -- (SELECT uiPermission FROM vwUIX WHERE uiSystem = 1 AND uiSubID = et.etGUID AND uiUserGUID = @UserGUID AND uiPermType = 3),	-- Delete
			[dbo].[fnGetUserEntrySec_Post]		(@UserGUID, [etGUID]) -- (SELECT uiPermission FROM vwUIX WHERE uiSystem = 1 AND uiSubID = et.etGUID AND uiUserGUID = @UserGUID AND uiPermType = 4)	-- post
		FROM
			[vwET] AS [et]
		UNION ALL
			SELECT
				0x0,
				[dbo].[fnGetUserEntrySec_Browse]	(@UserGUID, DEFAULT),
				[dbo].[fnGetUserEntrySec_Enter]		(@UserGUID, DEFAULT),
				[dbo].[fnGetUserEntrySec_Modify]	(@UserGUID, DEFAULT),
				[dbo].[fnGetUserEntrySec_Delete]	(@UserGUID, DEFAULT),
				[dbo].[fnGetUserEntrySec_Post]		(@UserGUID, DEFAULT)

	RETURN
END

##########################################################################
#END