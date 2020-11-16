#########################################################
CREATE PROC prcGetGroupsList
	@GroupGUID [UNIQUEIDENTIFIER] = NULL
AS
	SET NOCOUNT ON
	
	SELECT 
		[gr].[grGUID] AS [GUID],
		[gr].[grSecurity] AS [Security]
	FROM
		[dbo].[fnGetGroupsOfGroup](@GroupGUID) AS [fn] INNER JOIN [vwgr] AS [gr]
		ON [fn].[GUID] = [gr].[grGUID]

#########################################################
#END