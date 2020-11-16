##########################################################################
##
CREATE PROCEDURE repStoreTree
	@Lang		INT = 0					-- Language	(0=Arabic; 1=English)

AS
	SET NOCOUNT ON
	
	CREATE TABLE [#SecViol] (Type [INT], Cnt [INT])
	CREATE TABLE [#Result](
			[Guid]			[UNIQUEIDENTIFIER],
			[ParentGuid] 	[UNIQUEIDENTIFIER],
			[Code]			[NVARCHAR](250) COLLATE ARABIC_CI_AI,
			[Name]			[NVARCHAR](250) COLLATE ARABIC_CI_AI,
			[Number]		[FLOAT],
			[StoreSecurity]	[INT],
			[Level] 		[INT],
			[Path] 			[NVARCHAR](max) COLLATE ARABIC_CI_AI
		   	)
	
	INSERT INTO [#Result] 
	SELECT 
			[st].[stGuid], 
			CASE WHEN [st].[stParent] IS Null then 0x0 ELSE [st].[stParent] END AS [Parent],
			[st].[stCode], 
			CASE WHEN (@Lang = 1)AND([st].[stLatinName] <> '') THEN  [st].[stLatinName] ELSE [st].[stName] END AS [stName],
			[st].[stNumber],
			[st].[stSecurity],
			[fn].[Level],
			[fn].[Path]
		FROM
			[vwst] as [st] INNER JOIN [dbo].[fnGetStoresListTree]( 0x0, 0) AS [fn] 
			ON [st].[stGuid] = [fn].[Guid]

	EXEC [prcCheckSecurity]
	SELECT * FROM [#Result] ORDER BY [Path]
	SELECT * FROM [#SecViol]
###############################################################################
#END