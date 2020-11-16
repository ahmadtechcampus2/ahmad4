CREATE   PROCEDURE prcGetgroupsListByLevel 
	@GroupGUID [UNIQUEIDENTIFIER] = 0x0, 
	@Level [INT] = 0 
AS 
	SET NOCOUNT ON
	
	SELECT 
		[fn].[GUID], 
		[gr].[grSecurity] AS [Security], 
		[fn].[Level] 
	FROM 
		[dbo].[fnGetGroupsListByLevel] (@GroupGUID, @Level) AS [fn] INNER JOIN [vwGr] AS [gr] 
		ON [fn].[GUID] = [gr].[grGUID]


