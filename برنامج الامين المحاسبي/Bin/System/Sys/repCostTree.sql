##########################################################################
CREATE PROCEDURE repCostTree 
	@Lang		[INT] = 0,					-- Language	(0=Arabic; 1=English) 
	@compositeStr   [NVARCHAR](250) = 'composite',
	@distributeStr	[NVARCHAR](250) = 'distribute'
	
AS 
	SET NOCOUNT ON  
			 
	CREATE TABLE [#SecViol] ([Type] [INT], [Cnt] [INT]) 
	CREATE TABLE [#Result]( 
			[Guid]			[UNIQUEIDENTIFIER], 
			[ParentGuid] 		[UNIQUEIDENTIFIER], 
			[Code]			[NVARCHAR](250) COLLATE ARABIC_CI_AI, 
			[Name]			[NVARCHAR](250) COLLATE ARABIC_CI_AI, 
			[Number]		[FLOAT], 
			[Type] 			[int],
			[CostSecurity]		[INT], 
			[Level]			[INT], 
			[Path] 			[NVARCHAR](max) COLLATE ARABIC_CI_AI 
		   	) 
	 
	INSERT INTO [#Result]  
	SELECT  
			[co].[coGuid],  
			CASE WHEN [co].[coParent] IS Null then 0x0 ELSE [co].[coParent] END AS [Parent], 
			[co].[coCode],  
			CASE WHEN (@Lang = 1)AND([co].[coLatinName] <> '') THEN  [co].[coLatinName] ELSE [co].[coName] END AS [acName], 
			[co].[coNumber], 
			[co].[cotype],
			[co].[coSecurity], 
			[fn].[Level], 
			[fn].[Path] 
		FROM 
			[vwco] as [co] INNER JOIN [dbo].[fnGetCostsListSorted]( 0x0, 1) AS [fn] 
			ON [co].[coGuid] = [fn].[Guid]
		WHERE   [co].[cotype] NOT IN (1,2)

	 
-- check if composite or distribute exists make temp root cost for each of them
-- 
	IF exists( SELECT * FROM co000 WHERE type = 1)
	BEGIN
		
	INSERT INTO [#Result] 
		SELECT  
				[co].[coGuid],  
				0x00, 
				[co].[coCode],  
				CASE WHEN (@Lang = 1)AND([co].[coLatinName] <> '') THEN  [co].[coLatinName] ELSE [co].[coName] END AS [acName], 
				[co].[coNumber], 
				[co].[cotype],
				[co].[coSecurity], 
				'1', 
				0 
			FROM 
				[vwco] AS co
				WHERE cotype = 1 
	END


	IF exists( SELECT * FROM co000 WHERE type = 2)
	BEGIN
		
	INSERT INTO [#Result] 
		SELECT  
				[co].[coGuid],  
				0X00, 
				[co].[coCode],  
				CASE WHEN (@Lang = 1)AND([co].[coLatinName] <> '') THEN  [co].[coLatinName] ELSE [co].[coName] END AS [acName], 
				[co].[coNumber], 
				[co].[cotype],
				[co].[coSecurity], 
				'1', 
				0 
			FROM 
				[vwco] as co
				where cotype = 2 
	end

	EXEC [prcCheckSecurity] 
	SELECT * FROM [#Result] ORDER BY [Path] 
	SELECT * FROM [#SecViol] 
###############################################################################
#END