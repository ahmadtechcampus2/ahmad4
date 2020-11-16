################################################################################
CREATE PROCEDURE repGetMatList
	@Lang			INT = 0,					-- Language	(0=Arabic; 1=English)
	@Group			[UNIQUEIDENTIFIER] = NULL,
	@MatParentGUID	[UNIQUEIDENTIFIER] = NULL
AS
	SET NOCOUNT ON
		
	CREATE TABLE [#SecViol] ([Type] [INT], [Cnt] [INT])
	CREATE TABLE [#Mats] ([MatGUID] [UNIQUEIDENTIFIER], [Security] [INT])
	INSERT INTO [#Mats] EXEC [prcGetMatsList] NULL, @Group, -1, NULL
	
	CREATE TABLE [#Result](
			[Guid]		[UNIQUEIDENTIFIER],
			[GroupGuid] 	[UNIQUEIDENTIFIER],
			[Code]		[NVARCHAR](250) COLLATE ARABIC_CI_AI,
			[Name]		[NVARCHAR](250) COLLATE ARABIC_CI_AI,
			[Number]		[FLOAT],
			[MatSecurity] [INT]
		   	)
	IF (ISNULL(@Group, 0x0) != 0x0)
	BEGIN
		INSERT INTO [#Result] 
		SELECT 
				[m].[MatGUID], 
				[mt].[GroupGUID],
				[mt].[Code], 
				CASE WHEN (@Lang = 1) AND ([mt].[LatinName] <> '') THEN  [mt].[LatinName] ELSE [mt].[Name] END AS [mtName],
				[mt].[Number],
				[m].[Security]
		FROM
				[vwMaterials] AS [mt]
				INNER JOIN [#Mats] AS [m] ON [m].[MatGUID] = [mt].[GUID]
		WHERE 
				((@Group IS NULL) OR ([mt].[GroupGUID] = @Group) OR (SELECT [Kind] FROM [gr000] WHERE [GUID] = @Group) = 1)
				AND	([mt].[type] <> 2) 
		END

	ELSE IF (ISNULL(@MatParentGUID, 0x0) != 0x0)
	BEGIN
		INSERT INTO [#Result] 
		SELECT 
				[mt].[mtGUID], 
				[mt].[mtGroup],
				[mt].[mtCode], 
				CASE WHEN (@Lang = 1) AND ([mt].[mtCompositionName] <> '') THEN  [mt].[mtCompositionLatinName] ELSE [mt].[mtCompositionName] END AS [mtName],
				[mt].[mtNumber],
				[mt].[mtSecurity]
		FROM
				[vwmt] AS [mt]
		WHERE 
				[mt].[mtParent] = @MatParentGuid
	END

	EXEC [prcCheckSecurity]
	SELECT * FROM [#Result]
	SELECT * FROM [#SecViol]
###################################################################################
#END
