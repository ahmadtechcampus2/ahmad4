#########################################################################
CREATE PROC repMatTreeReport
AS
	SET NOCOUNT ON 
	 
	CREATE TABLE [#SecViol](Type [INT], Cnt [INT]) 
	CREATE TABLE [#Result](  
			[GUID] [UNIQUEIDENTIFIER],  
			[ParentGUID] [UNIQUEIDENTIFIER],  
			[Code] [NVARCHAR](256) COLLATE ARABIC_CI_AI, 
			[Name] [NVARCHAR](256) COLLATE ARABIC_CI_AI, 
			[LatinName] [NVARCHAR](256) COLLATE ARABIC_CI_AI, 
			[Level] [INT], 
			[Path] [NVARCHAR](max) COLLATE ARABIC_CI_AI, 
			[Type] [INT], 
			[mtSecurity] [INT], 
			[grSecurity] [INT]) 	 
	 
	INSERT INTO [#Result]  
		SELECT  
			[Grp].[grGUID],  
			[Grp].[grParent], 
			[Grp].[grCode],  
			[Grp].[grName],   
			[Grp].[grLatinName], 
			[Gr].[Level], 
			[Gr].[Path], 
			0, -- Type 
			0, -- mtSecurity 
			[grSecurity] 			 
	FROM  
		[dbo].[fnGetGroupsOfGroupSorted](0x0, 1) AS [Gr]  
		INNER JOIN [vwGr] AS [Grp] ON [Gr].[GUID] = [Grp].[grGUID]
		INNER JOIN [gr000] AS [G] ON [G].[GUID] = [Grp].[grGUID]
	WHERE
		[G].[Kind] = 0	 
	-------------------------------------------------------------------------- 
	--EXEC [prcCheckSecurity] 
	-------------------------------------------------------------------------- 
	INSERT INTO [#Result]  
	SELECT 
		[mt].[mtGUID], 
		[mt].[mtGroup], 
		[mt].[mtCode], 
		[mt].[mtName], 
		[mt].[mtLatinName], 
		[gr].[level], 
		[gr].[Path], 
		1,	-- Type 
		[mt].[mtSecurity], 
		0 	--grSecurity 	 
	FROM  
		[#Result] AS [Gr]
		INNER JOIN [vwMt] AS [mt] ON [Gr].[GUID] = [mt].[mtGroup] 
	WHERE 
		[mt].[mttype] <> 2
		AND [mt].mtParent = 0x0
	ORDER BY
		[mt].[mtCode] 
	-- insert compostion materials
	INSERT INTO [#Result]  
	SELECT 
		[mt].[mtGUID], 
		[mt].[mtParent], 
		[mt].[mtCode], 
		[mt].[mtName], 
		[mt].[mtLatinName], 
		[mtParent].[level], 
		[mtParent].[Path], 
		1,	-- Type 
		[mt].[mtSecurity], 
		0 	--grSecurity 	 
	FROM  
		[#Result] AS [mtParent]
		INNER JOIN [vwMt] AS [mt] ON [mtParent].[GUID] = [mt].[mtParent] 
	WHERE 
		[mt].[mttype] <> 2
		AND [mt].mtParent <> 0x0
	ORDER BY
		[mt].[mtCode] 

	-------------------------------------------------------------------------- 
	--EXEC [prcCheckSecurity] 
	-------------------------------------------------------------------------- 	 
	SELECT  
		[GUID], 
		ISNULL([ParentGUID], 0x0) AS [ParentGUID], 
		[Code], 
		[Name], 
		[LatinName], 
		ISNULL([Level], 0) AS [Level], 
		[Path], 
		[Type] 
	FROM  
		[#Result]  
	ORDER BY  
		[Path], [Type] 
##########################################################################
#END