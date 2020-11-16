#########################################################
CREATE PROCEDURE prcGetBuEnTypesList
	@SrcGuid [UNIQUEIDENTIFIER] = NULL, 
	@UserGUID [UNIQUEIDENTIFIER] = NULL 
AS  
/*  
This procedure:  
	- returns the Type, Security of provided @SrcGuid. 
	- returns all types when @Source is NULL.  
	- can get the UserID if not specified.  
	-- Bill ( Type >= 1  and  Type <= 2048 ) 
	-- Entry ( Type < 1  or  Type > 2048 )  
	-- in return Result the field type : Type = 0 -> Entry , Type = 1 -> Bill
*/  
	SET NOCOUNT ON
	
	SELECT 
		ISNULL ( [fnbu].[GUID], [fnEn].[GUID]) AS [GUID], 
		ISNULL ( [fnbu].[BrowseSec], [fnen].[BrowseSec]) AS [Security],
		CASE WHEN [fnbu].[GUID] IS NULL THEN 0 ELSE 1 END AS [Type] -- Type = 0 -> Entry , Type = 1 -> Bill
	FROM 
		[RepSrcs] AS [rs] LEFT JOIN ( SELECT * FROM [vwET] INNER JOIN [dbo].[fnGetUserEntriesSec](@UserGUID) AS [fn] ON [fn].[GUID] = [etGUID] )AS [fnEn] ON ( [rs].[IdType] = [fnEn].[Guid] AND ( [fnEn].[etEntryType] < 1  OR  [fnEn].[etEntryType] > 2048 ) )
		LEFT JOIN (SELECT * FROM [vwBT] INNER JOIN [dbo].[fnGetUserBillsSec](@UserGUID) AS [fn] ON [fn].[GUID] = [btGUID])AS [fnBu] ON ( [rs].[IdType] = [fnBu].[Guid] AND [fnBu].[btType] >= 1  AND  [fnBu].[btType] <= 2048)
	WHERE 
		[rs].[IdTbl] = @SrcGuid

#########################################################
#END