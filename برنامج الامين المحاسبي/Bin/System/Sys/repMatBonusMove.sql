#######################################################################################
CREATE PROCEDURE repMatBonusMove
	@StartDate 			[DATETIME],
	@EndDate 			[DATETIME],
	@SrcTypesguid		[UNIQUEIDENTIFIER],
	@MatBonusGUID		[UNIQUEIDENTIFIER] = 0x0,	
	@MatGuid 			[UNIQUEIDENTIFIER] = 0x0, 
	@GroupGuid 			[UNIQUEIDENTIFIER] = 0x0,
	@PostedValue		[INT] = -1, -- 0, 1 , -1
	@NotesContain 		[NVARCHAR](256) = '',
	@NotesNotContain	[NVARCHAR](256) = '',
	@CustGuid 			[UNIQUEIDENTIFIER] = 0x0, 
	@StoreGuid 			[UNIQUEIDENTIFIER] = 0x0, --0 all stores so don't check store or list of stores 
	@CostGuid 			[UNIQUEIDENTIFIER] = 0x0, -- 0 all costs so don't Check cost or list of costs 
	@AccGuid			[UNIQUEIDENTIFIER] = 0x0, 
	@Flag				[INT] = 0,
	@CustCond			[UNIQUEIDENTIFIER] = 0x0,
	@BillCond			[UNIQUEIDENTIFIER] = 0x0,		
	@MatCond			[UNIQUEIDENTIFIER] = 0x0,
	@BonusType			[INT] = 0
AS 
	SET NOCOUNT ON 

	CREATE TABLE [#SecViol]( [Type] [INT], [Cnt] [INTEGER])

	CREATE TABLE [#BillsTypesTbl]( [TypeGuid] [UNIQUEIDENTIFIER], [UserSecurity] [INTEGER], [UserReadPriceSecurity] [INTEGER], [UnpostedSecurity] [INTEGER])
	INSERT INTO [#BillsTypesTbl]	EXEC [prcGetBillsTypesList2] 	@SrcTypesguid

	CREATE TABLE [#CostTbl]( [CostGuid] [UNIQUEIDENTIFIER], [Security] [INT])
	INSERT INTO [#CostTbl] EXEC [prcGetCostsList] @CostGUID 
	IF ISNULL( @CostGuid, 0x0) = 0x0
		INSERT INTO [#CostTbl] VALUES (0x0,0)
	
	IF ISNULL( @MatBonusGUID, 0x0) = 0x0
	BEGIN 
		CREATE TABLE [#MatTbl]( [MatGuid] UNIQUEIDENTIFIER, [mtSecurity] INT)
		INSERT INTO [#MatTbl] EXEC [prcGetMatsList] @MatGuid, @GroupGuid, -1, @MatCond
	END 		
	
	CREATE TABLE [#StoreTbl]( [StoreGuid] [UNIQUEIDENTIFIER], [Security] [INT])
	INSERT INTO [#StoreTbl]		 	EXEC [prcGetStoresList] 		@StoreGUID 

	CREATE TABLE [#CustTbl]( [CustGuid] [UNIQUEIDENTIFIER], [Security] [INT])
	INSERT INTO [#CustTbl] EXEC [prcGetCustsList] @CustGuid, @AccGuid, @CustCond
	
	SELECT 
		[CustGuid], 
		[c].[Security],
		[CustomerName] AS [cuCustomerName], 
		(CASE [LatinName] WHEN '' THEN [CustomerName] ELSE [LatinName] END) AS [cuLatinName]
	INTO  
		[#CustTbl2]
	FROM 
		[#CustTbl] AS [C] 
		INNER JOIN [cu000] AS [cu] ON [cu].[Guid] = [CustGuid]
		
	IF ISNULL( @CustGuid, 0x0) = 0x0 AND ISNULL( @AccGuid, 0x0) = 0x0 AND @CustCond = 0x0
		INSERT INTO [#CustTbl2] VALUES( 0x0, 0, '', '') 

	IF @NotesContain IS NULL
		SET @NotesContain = '' 
	IF @NotesNotContain IS NULL 
		SET @NotesNotContain = '' 

	CREATE TABLE [#Result] 
	( 
		[buGuid]				[UNIQUEIDENTIFIER],
		[buSecurity]			[INT],
		[buType] 				[UNIQUEIDENTIFIER],
		[biStoreGuid]			[UNIQUEIDENTIFIER],
		[biCostGuid]			[UNIQUEIDENTIFIER],
		[smGuid]				[UNIQUEIDENTIFIER],
		[CustGuid]				[UNIQUEIDENTIFIER]
	)

	DECLARE 
		@SQL NVARCHAR(max),
		@Criteria NVARCHAR(max)
		SET @Criteria = ''
		
	SET @SQL = '
	INSERT INTO [#Result] 
	SELECT 
		DISTINCT 
		[bi].[buGuid],
		[bi].[buSecurity],
		[bi].[buType],
		[bi].[biStorePtr],
		[bi].[biCostPtr],
		[bi].[biSOGuid],
		[cu].[CustGuid]
	FROM
		[vwExtended_bi_address] [bi]
		INNER JOIN [#BillsTypesTbl] [bt] ON [bi].[buType] = [bt].[TypeGuid]
		INNER JOIN [#CostTbl] [co] ON [co].[CostGuid] = [bi].[biCostPtr]
		INNER JOIN [#StoreTbl] [st] ON [st].[StoreGuid] = [bi].[biStorePtr] 
		INNER JOIN [#CustTbl2] AS [cu] ON [cu].[CustGuid] = [bi].[buCustPtr]'
	IF ISNULL( @MatBonusGUID, 0x0) = 0x0
		SET @SQL = @SQL + '
		INNER JOIN [#MatTbl] AS [mt] ON [bi].[biMatPtr] = [mt].[MatGuid]'
	
	IF @BillCond <> 0X00
	BEGIN
		DECLARE @CurrencyGUID UNIQUEIDENTIFIER
		SET @CurrencyGUID = (SELECT TOP 1 [guid] FROM [my000] WHERE [CurrencyVal] = 1)
		SET @Criteria = [dbo].[fnGetBillConditionStr]( NULL,@BillCond,@CurrencyGUID)
		IF @Criteria <> '' AND RIGHT ( RTRIM (@Criteria) , 4 ) ='<<>>'
		BEGIN	
			SET @Criteria = REPLACE(@Criteria ,'<<>>','')		
			DECLARE @CFTableName NVARCHAR(255)
			Set @CFTableName = (SELECT CFGroup_Table From CFMapping000 Where Orginal_Table = 'bu000' )
			SET @SQL = @SQL + ' INNER JOIN ['+ @CFTableName +'] ON [bi].[buGuid] = ['+ @CFTableName +'].[Orginal_Guid] '			
		END
	END


	SET @SQL = @SQL + '
	WHERE 
		([bi].[buDate] BETWEEN ' + [dbo].[fnDateString]( @StartDate) + ' AND ' + [dbo].[fnDateString]( @EndDate) + ')'
		IF( @PostedValue <> -1)
			SET @SQL = @SQL + ' AND [bi].[buIsPosted] = ' + CAST( @PostedValue AS NVARCHAR(2))

		SET @SQL = @SQL + '		
		AND 
		(
			([bi].[biSOGuid] <> 0x0) AND 
			(( ''' + CAST( @MatBonusGUID AS NVARCHAR(250)) + ''' = ''00000000-0000-0000-0000-000000000000'')
			OR 
			([bi].[biSOGuid] = ''' + CAST( @MatBonusGUID AS NVARCHAR(250)) + '''))
		)' 

		IF @NotesContain <>  ''
			 SET @SQL = @SQL + ' AND (([bi].[buNotes] LIKE ''%'' + '''+ @NotesContain + ''' +''%'') OR ([bi].[biNotes] LIKE ''%'' + ''' + @NotesContain + ''' + ''%''))' 
		IF @NotesNotContain <> ''
			SET @SQL = @SQL + ' AND (([bi].[buNotes] NOT LIKE ''%'' + ''' + @NotesNotContain + ''' + ''%'') AND ([bi].[biNotes] NOT LIKE ''%''+  ''' + @NotesNotContain + ''' + ''%'')))'
		
		IF @Criteria <> ''
		BEGIN
			SET @Criteria = ' AND (' + @Criteria + ')'
			SET @SQL = @SQL + @Criteria
		END

	EXEC(@SQL)

	EXEC [prcCheckSecurity]

	SET @SQL = '
	SELECT 
		[r].[buGuid] AS [BillGuid],
		[bu].[buNumber] AS [BillNumber],
		[bu].[buNotes] AS [BillNotes],
		(CASE [dbo].[fnConnections_GetLanguage]() WHEN 0 THEN [bu].[btAbbrev] ELSE [bu].[btLatinAbbrev] END) AS [BillTypeAbbrev],
		[bu].[buDate] AS [BillDate],
		[sm].[Guid] AS [SOGuid],
		[sm].[Notes] AS [SODesc], 
		[sm].[Type] AS [SOType], '
		IF [dbo].[fnConnections_GetLanguage]() = 0
			SET @SQL = @SQL + 'ISNULL( [st].[Name], '''') AS [stName] '
		ELSE
			SET @SQL = @SQL + 'ISNULL( CASE [st].[LatinName] WHEN ' + '''' + ''' THEN [st].[Name] ELSE [st].[LatinName] END,'''')  [stName] '

		IF (@Flag & 1) != 0
			SET @SQL = @SQL + ', ISNULL( [cu].[CustomerName], '''') AS [CustomerName] '

		IF (@Flag & 4) != 0
		BEGIN
			IF [dbo].[fnConnections_GetLanguage]() = 0
				SET @SQL = @SQL + ', ISNULL( [co].[Name], '''') AS [coName] '
			ELSE
				SET @SQL = @SQL + ', ISNULL( CASE [co].[LatinName] WHEN ' + '''' + ''' THEN [co].[Name] ELSE [co].[LatinName] END,'''')  [coName] '
		END

		IF (@Flag & 8) != 0
		BEGIN
			IF [dbo].[fnConnections_GetLanguage]() = 0
				SET @SQL = @SQL + ', ISNULL( [br].[Name], '''') AS [brName] '
			ELSE
				SET @SQL = @SQL + ', ISNULL( CASE [br].[LatinName] WHEN ' + '''' + ''' THEN [br].[Name] ELSE [br].[LatinName] END,'''')  [brName] '
		END
	
	SET @SQL = @SQL + '
	FROM 
		[#Result] [r]
		INNER JOIN [vwBu] [bu] ON [r].[buGuid] = [bu].[buGuid]
		INNER JOIN [sm000] [sm] ON [sm].[Guid] = [r].[smGuid] 
		INNER JOIN [st000] [st] ON [st].[Guid] = [r].[biStoreGuid] '
		IF (@Flag & 1) != 0
			SET @SQL = @SQL + ' LEFT JOIN [cu000] [cu] ON [cu].[Guid] = [r].[CustGUID] '

		IF (@Flag & 4) != 0
			SET @SQL = @SQL + ' LEFT JOIN [co000] [co] ON [co].[Guid] = [r].[biCostGuid] '

		IF (@Flag & 8) != 0
			SET @SQL = @SQL + ' LEFT JOIN [br000] [br] ON [br].[Guid] = [bu].[buBranch] '			
	SET @SQL = @SQL + '
	WHERE 
	(( ' + CAST( @BonusType AS NVARCHAR(10)) + ' = 0) OR ([sm].[Type] = ' + CAST( @BonusType AS NVARCHAR(10)) + '))
	ORDER BY 
		[bu].[buDate],
		[bu].[buNumber] '

	EXEC(@SQL)	

	SELECT * FROM [#SecViol]
#######################################################################################
#END

