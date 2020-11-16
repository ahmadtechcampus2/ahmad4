##########################################################################
CREATE FUNCTION fnGetUserBillsSec(@UserGUID [UNIQUEIDENTIFIER])
	RETURNS @Result TABLE([GUID] [UNIQUEIDENTIFIER], 
							[BrowseSec] [INT], 
							[EnterSec] [INT], 
							[ModifySec] [INT], 
							[DeleteSec] [INT], 
							[PostSec] [INT], 
							[GenEntrySec] [INT], 
							[PostEntrySec] [INT], 
							[ChangPriceSec] [INT], 
							[ReadPriceSec] [INT])
AS BEGIN
	SET @UserGUID = ISNULL(@UserGUID, [dbo].[fnGetCurrentUserGUID]())
	IF [dbo].[fnIsAdmin](@UserGUID) = 0
		INSERT INTO @Result
			SELECT
				[bt].[btGuid],
				[dbo].[fnGetUserBillSec_Browse]			(@UserGUID, [btGUID]), -- (SELECT uiPermission FROM vwUIX WHERE uiSystem = 1 AND uiSubID = bt.[btGUID] AND uiUserGUID = @UserGUID AND uiPermType = 1), -- Browse
				[dbo].[fnGetUserBillSec_Enter]				(@UserGUID, [btGUID]), -- (SELECT uiPermission FROM vwUIX WHERE uiSystem = 1 AND uiSubID = bt.[btGUID] AND uiUserGUID = @UserGUID AND uiPermType = 0),	-- Enter
				[dbo].[fnGetUserBillSec_Modify]			(@UserGUID, [btGUID]), -- (SELECT uiPermission FROM vwUIX WHERE uiSystem = 1 AND uiSubID = bt.[btGUID] AND uiUserGUID = @UserGUID AND uiPermType = 2),	-- Modify
				[dbo].[fnGetUserBillSec_Delete]			(@UserGUID, [btGUID]), -- (SELECT uiPermission FROM vwUIX WHERE uiSystem = 1 AND uiSubID = bt.[btGUID] AND uiUserGUID = @UserGUID AND uiPermType = 3),	-- Delete
				[dbo].[fnGetUserBillSec_Post]				(@UserGUID, [btGUID]), -- (SELECT uiPermission FROM vwUIX WHERE uiSystem = 1 AND uiSubID = bt.[btGUID] AND uiUserGUID = @UserGUID AND uiPermType = 4),	-- post
				[dbo].[fnGetUserBillSec_GenEntry]		(@UserGUID, [btGUID]), -- (SELECT uiPermission FROM vwUIX WHERE uiSystem = 1 AND uiSubID = bt.[btGUID] AND uiUserGUID = @UserGUID AND uiPermType = 5),	-- GenEntry
				[dbo].[fnGetUserBillSec_PostEntry]		(@UserGUID, [btGUID]), -- (SELECT uiPermission FROM vwUIX WHERE uiSystem = 1 AND uiSubID = bt.[btGUID] AND uiUserGUID = @UserGUID AND uiPermType = 6),	-- PostEntry
				[dbo].[fnGetUserBillSec_ChangePrice]	(@UserGUID, [btGUID]), -- (SELECT uiPermission FROM vwUIX WHERE uiSystem = 1 AND uiSubID = bt.[btGUID] AND uiUserGUID = @UserGUID AND uiPermType = 7),	-- ChangePrice
				[dbo].[fnGetUserBillSec_ReadPrice]		(@UserGUID, [btGUID]) -- (SELECT uiPermission FROM vwUIX WHERE uiSystem = 1 AND uiSubID = bt.[btGUID] AND uiUserGUID = @UserGUID AND uiPermType = 8)	-- ReadPrice
			FROM
				[vwBT] AS [bt]
	ELSE BEGIN
		DECLARE @msl [INT]
		SET @msl = [dbo].[fnGetMaxSecurityLevel]()
		INSERT INTO @Result
			SELECT [btGUID], @msl, @msl, @msl, @msl, @msl, @msl, @msl, @msl, @msl FROM [vwBT]
	END
	RETURN
END

##########################################################################
CREATE FUNCTION fnGetUserBillsSec2 ( @UserGUID [UNIQUEIDENTIFIER] )
	RETURNS @Result TABLE([GUID] [UNIQUEIDENTIFIER],  
							[BrowsePostSec] [INT],  
							[EnterSec] [INT],
							[ModifyPostSec] [INT],  
							[DeletePostSec] [INT],  
							[PostSec] [INT],  
							[GenEntrySec] [INT],  
							[PostEntrySec] [INT],  
							[ChangPriceSec] [INT],  
							[ReadPriceSec] [INT],
							[BrowseUnPostSec] [INT],  
							[ModifyUnPostSec] [INT],  
							[DeleteUnPostSec] [INT]) 
AS BEGIN 
	SET @UserGUID = ISNULL(@UserGUID, [dbo].[fnGetCurrentUserGUID]()) 
	IF [dbo].[fnIsAdmin](@UserGUID) = 0 
		INSERT INTO @Result 
			SELECT 
				[bt].[btGuid], 
				[dbo].[fnGetUserBillSec_Browse]			(@UserGUID, [btGUID]), -- (SELECT uiPermission FROM vwUIX WHERE uiSystem = 1 AND uiSubID = bt.[btGUID] AND uiUserGUID = @UserGUID AND uiPermType = 1), -- Browse 
				[dbo].[fnGetUserBillSec_Enter]			(@UserGUID, [btGUID]), -- (SELECT uiPermission FROM vwUIX WHERE uiSystem = 1 AND uiSubID = bt.[btGUID] AND uiUserGUID = @UserGUID AND uiPermType = 0),	-- Enter 
				[dbo].[fnGetUserBillSec_Modify]			(@UserGUID, [btGUID]), -- (SELECT uiPermission FROM vwUIX WHERE uiSystem = 1 AND uiSubID = bt.[btGUID] AND uiUserGUID = @UserGUID AND uiPermType = 2),	-- Modify 
				[dbo].[fnGetUserBillSec_Delete]			(@UserGUID, [btGUID]), -- (SELECT uiPermission FROM vwUIX WHERE uiSystem = 1 AND uiSubID = bt.[btGUID] AND uiUserGUID = @UserGUID AND uiPermType = 3),	-- Delete 
				[dbo].[fnGetUserBillSec_Post]			(@UserGUID, [btGUID]), -- (SELECT uiPermission FROM vwUIX WHERE uiSystem = 1 AND uiSubID = bt.[btGUID] AND uiUserGUID = @UserGUID AND uiPermType = 4),	-- post 
				[dbo].[fnGetUserBillSec_GenEntry]		(@UserGUID, [btGUID]), -- (SELECT uiPermission FROM vwUIX WHERE uiSystem = 1 AND uiSubID = bt.[btGUID] AND uiUserGUID = @UserGUID AND uiPermType = 5),	-- GenEntry 
				[dbo].[fnGetUserBillSec_PostEntry]		(@UserGUID, [btGUID]), -- (SELECT uiPermission FROM vwUIX WHERE uiSystem = 1 AND uiSubID = bt.[btGUID] AND uiUserGUID = @UserGUID AND uiPermType = 6),	-- PostEntry 
				[dbo].[fnGetUserBillSec_ChangePrice]		(@UserGUID, [btGUID]), -- (SELECT uiPermission FROM vwUIX WHERE uiSystem = 1 AND uiSubID = bt.[btGUID] AND uiUserGUID = @UserGUID AND uiPermType = 7),	-- ChangePrice 
				[dbo].[fnGetUserBillSec_ReadPrice]		(@UserGUID, [btGUID]), -- (SELECT uiPermission FROM vwUIX WHERE uiSystem = 1 AND uiSubID = bt.[btGUID] AND uiUserGUID = @UserGUID AND uiPermType = 8)	-- ReadPrice 
				[dbo].[fnGetUserBillSec_BrowseUnPosted]		(@UserGUID, [btGUID]), -- (SELECT uiPermission FROM vwUIX WHERE uiSystem = 1 AND uiSubID = bt.[btGUID] AND uiUserGUID = @UserGUID AND uiPermType = 9), -- Browse
				[dbo].[fnGetUserBillSec_ModifyUnPosted]		(@UserGUID, [btGUID]), -- (SELECT uiPermission FROM vwUIX WHERE uiSystem = 1 AND uiSubID = bt.[btGUID] AND uiUserGUID = @UserGUID AND uiPermType = 10),	-- Modify 
				[dbo].[fnGetUserBillSec_DeleteUnPosted]		(@UserGUID, [btGUID])  -- (SELECT uiPermission FROM vwUIX WHERE uiSystem = 1 AND uiSubID = bt.[btGUID] AND uiUserGUID = @UserGUID AND uiPermType = 11),	-- Delete 
			FROM 
				[vwBT] AS [bt] 
	ELSE BEGIN 
		DECLARE @msl [INT] 
		SET @msl = [dbo].[fnGetMaxSecurityLevel]() 
		INSERT INTO @Result 
			   SELECT [btGUID], @msl, @msl, @msl, @msl, @msl, @msl, @msl, @msl, @msl, @msl, @msl, @msl
			   FROM [vwBT]
	END 
	RETURN 
END
##########################################################################
#END