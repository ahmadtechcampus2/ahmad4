########################################################################################
CREATE FUNCTION fnGetNotesTypesList (
	@SrcGuid [UNIQUEIDENTIFIER] = 0x0, 
	@UserGUID [UNIQUEIDENTIFIER] = 0x0)
	RETURNS @Result TABLE([GUID] [UNIQUEIDENTIFIER],[Security] [INT])
AS  
/*  
This function:  
	- returns the Type, Security of provided @SrcGuid. 
	- returns all types when @Source is NULL.  
	- can get the UserID if not specified.  
*/  
BEGIN
	IF ISNULL(@UserGUID, 0x0) = 0x0
		SET @UserGUID = [dbo].[fnGetCurrentUserGUID]()

	IF ISNULL(@SrcGuid, 0x0) = 0x0
		INSERT INTO @Result 
			SELECT 
				[GUID],
				[BrowseSec]
			FROM 
				[fnGetUserNotesSec]( @UserGUID) AS [fn] 
	ELSE
		INSERT INTO @Result 
			SELECT 
				[IdType],
				[dbo].[fnGetUserNoteSec_Browse](@UserGUID, [idType])
			FROM 
				[RepSrcs]
			WHERE
				[IdTbl] = @SrcGuid 
				AND [IdSubType] = 5
	RETURN
END
################################################################################
#END

