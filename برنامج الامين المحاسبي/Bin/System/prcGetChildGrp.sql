#########################################################
CREATE PROCEDURE prcGetChildGrp 
	@GrpPtr AS [UNIQUEIDENTIFIER]
AS
	SET NOCOUNT ON
	IF @GrpPtr = NULL
		SELECT 
			[grGUID] AS [Number], 
			[grCode] As [Code], 
			[grName] AS [Name], 
			[grParent] AS [Parent] 
		FROM 
			[vwGr]
	ELSE
		SELECT 
			[grGUID] AS [Number], 
			[grCode] As [Code], 
			[grName] AS [Name], 
			[grParent] AS [Parent] 
		FROM 
			[vwGr] 
		WHERE 
			[grParent] = @GrpPtr
#########################################################
CREATE PROCEDURE prcGetChildGrpList
	@GrpPtr AS [UNIQUEIDENTIFIER],
	@Sort	[INT]
AS
	SET NOCOUNT ON
	IF ((SELECT [Kind] FROM [gr000] WHERE [GUID] = @GrpPtr) = 0)
		SELECT 
			[gr].[GUID] AS [Number], 
			[gr].[Code] As [Code], 
			[gr].[Name] AS [Name], 
			[gr].[LatinName] AS [LatinName], 
			[gr].[ParentGUID] AS [Parent] 
		FROM 
			[Gr000] AS [gr]
			INNER JOIN [dbo].[fnGetGroupsListByLevel](@GrpPtr,0) AS [g] ON [gr].[Guid] = [g].[Guid]
		ORDER BY
			[g].[Level] DESC, CASE @Sort WHEN 2 THEN [gr].[Code] WHEN 1 THEN [gr].[Name] WHEN 3 THEN [gr].[LatinName] ELSE '' END,[gr].[Number]
	ELSE
		SELECT 
			[gr].[GUID] AS [Number], 
			[gr].[Code] As [Code], 
			[gr].[Name] AS [Name], 
			[gr].[LatinName] AS [LatinName], 
			[gr].[ParentGUID] AS [Parent] 
		FROM 
			[Gr000] AS [gr]
			INNER JOIN [dbo].[fnGetGroupsOfGroupSorted](@GrpPtr,0) AS [g] ON [gr].[Guid] = [g].[Guid]
		ORDER BY
			[g].[Level] DESC, CASE @Sort WHEN 2 THEN [gr].[Code] WHEN 1 THEN [gr].[Name] WHEN 3 THEN [gr].[LatinName] ELSE '' END,[gr].[Number]
#########################################################
#END
