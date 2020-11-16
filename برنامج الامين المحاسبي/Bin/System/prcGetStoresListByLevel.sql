#########################################################
CREATE PROCEDURE prcGetStoresListByLevel
	@StoreGUID [UNIQUEIDENTIFIER] = 0x0,
	@Level [INT] = 0,
	@Tree [INT] = 0
AS
	SET NOCOUNT ON
	IF @Tree=0
		SELECT
			[fn].[GUID],
			[st].[stSecurity] AS [Security],
			[fn].[Level]
		FROM
			[fnGetStoresListByLevel](@StoreGUID, @Level) AS [fn] INNER JOIN [vwst] AS [st]
			ON [fn].[GUID] = [st].[stGUID]
	ELSE
		SELECT 
			[fn].[GUID], 
			[st].[stSecurity] AS [Security], 
			[fn].[Level],
			[st].[stName],
			[st].[stLatinName]
		FROM 
			[fnGetStoresListByLevel](@StoreGUID, @Level) AS [fn] INNER JOIN [vwst] AS [st]
			ON [fn].[GUID] = [st].[stGUID]
			INNER JOIN [fnGetStoresListTree](@StoreGUID,0) [fnT] ON [fnT].[GUID] = [fn].[GUID]
			ORDER BY [Path]
		

#########################################################
#END 