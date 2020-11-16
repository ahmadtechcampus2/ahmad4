#########################################################
CREATE PROCEDURE prcGetEntriesTypesList  
	@SrcGuid [UNIQUEIDENTIFIER] = NULL,
	@UserGUID [UNIQUEIDENTIFIER] = NULL
AS 
/* 
This procedure: 
	- returns the Type, Security of provided @SrcGuid.
	- returns all types when @Source is NULL. 
	- can get the UserID if not specified. 
*/ 

	SET NOCOUNT ON
	
	SELECT
		*
	FROM
		[dbo].[fnGetEntriesTypesList]( @SrcGuid, @UserGUID)
			
#########################################################
#END