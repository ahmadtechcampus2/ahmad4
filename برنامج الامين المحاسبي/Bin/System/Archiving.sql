###############################################################################
CREATE PROCEDURE prcArchiving_GetMatList
AS
	SET NOCOUNT ON
		
	CREATE TABLE [#SecViol] ([Type] [INT], [Cnt] [INT])
	CREATE TABLE [#Result](
			[Guid]		[UNIQUEIDENTIFIER],
			[Code]		[NVARCHAR](250) COLLATE ARABIC_CI_AI,
			[Name]		[NVARCHAR](250) COLLATE ARABIC_CI_AI,
			[LatinName]		[NVARCHAR](250) COLLATE ARABIC_CI_AI,
			[MatSecurity] [INT]
		   	)
	
	INSERT INTO [#Result] 
	SELECT 
			[mt].[mtGuid], 
			[mt].[mtCode], 
			[mt].[mtName],
			[mt].[mtLatinName],
			[mt].[mtSecurity]
	FROM
			[vwmt] as [mt]
	WHERE ([mt].[mttype] <> 2) 
	
	EXEC [prcCheckSecurity]
	SELECT [Guid] ID,[Code],[Name],[LatinName] FROM [#Result] 

###########################################################################
#END