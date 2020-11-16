################################################################################
CREATE FUNCTION fnGetCollectNotesTypesList(
	@SrcGuid [UNIQUEIDENTIFIER] = NULL, 
	@UserGUID [UNIQUEIDENTIFIER] = NULL)
	RETURNS @Result TABLE( [GUID] [UNIQUEIDENTIFIER], [Security] [INT])
AS  
/*  
This function:  
	- returns the Type, Security of provided @SrcGuid. 
	- returns all types when @Source is NULL.  
	- can get the UserID if not specified.  
*/  
BEGIN
	IF( @UserGUID IS NULL )
		SET @UserGUID = [dbo].[fnGetCurrentUserGUID]()
	IF( @SrcGuid IS NULL)
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
				AND [IdSubType] = 6
	RETURN
END
################################################################################
#END