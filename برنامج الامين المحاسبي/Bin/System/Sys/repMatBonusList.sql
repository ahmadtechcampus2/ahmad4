################################################################################
## 
CREATE PROC repMatBonusList
	@NowDate [DATETIME],
	@bIsEffect [BIT] = 0,
	@bUsedOnly [BIT] = 0,
	@bGroupsOnly [BIT] = 0,
	@bOrgizionOnly [BIT] = 0,
	@orderType [INT] = 0
AS
	SET NOCOUNT ON
	
	DECLARE @S AS [NVARCHAR](max)
	SET @S = '
	SELECT [sm].*, [mt].[mtCode] as [MtCode], [mt].[mtName] as [MtName] FROM [sm000] [sm] INNER JOIN [vwMt] [mt] ON [sm].[MatGUID] = [mt].[mtGUID] 
	WHERE 
		(( ' + CAST(@bIsEffect AS [NVARCHAR](1)) + ' = 0) OR (''' + CAST(@NowDate AS [NVARCHAR](250)) + ''' BETWEEN [sm].[StartDate] AND [sm].[EndDate])) AND  
		(( ' + CAST(@bUsedOnly AS [NVARCHAR](1)) + ' = 0) OR ( [sm].[GUID] IN (SELECT DISTINCT [soGUID] FROM [bi000]))) AND
		( '  + CAST(@bGroupsOnly AS [NVARCHAR](1)) + ' = 0) AND 
		(( ' + CAST( @bOrgizionOnly AS [NVARCHAR](1)) + ' = 0) OR ( [sm].[Type] = 2)) 

	UNION ALL 
	SELECT [sm].*, [gr].[grCode], [gr].[grName] FROM [sm000] [sm] INNER JOIN [vwGr] [gr] ON [sm].[GroupGUID] = [gr].[grGUID] 
	WHERE 
		(( ' + CAST(@bIsEffect AS [NVARCHAR](1)) + ' = 0) OR (''' + CAST(@NowDate AS [NVARCHAR](250)) + ''' BETWEEN [sm].[StartDate] AND [sm].[EndDate])) AND 
		(( ' + CAST(@bUsedOnly AS [NVARCHAR](1)) + ' = 0) OR ( [sm].[GUID] IN (SELECT DISTINCT [soGUID] FROM [bi000]))) AND
		(( ' + CAST( @bOrgizionOnly AS [NVARCHAR](1)) + ' = 0) OR ( [sm].[Type] = 2)) 

	ORDER BY' 

	IF (@orderType = 1)
		SET @S = @S + ' [MtName]' 
	ELSE IF (@orderType = 2) 
		SET @S = @S + ' [sm].[StartDate]' 
	ELSE IF (@orderType = 3) 
		SET @S = @S + ' [sm].[EndDate]' 
	ELSE IF (@orderType = 4)	 
		SET @S = @S + ' [sm].[Notes]' 
	ELSE  
		SET @S = @S + ' [MtCode]' 
	EXECUTE(@S)
###################################################################################
#END
