###########################################################################
CREATE PROCEDURE repCheckDueDate
	@AccPtr					[UNIQUEIDENTIFIER],
	@SrcGuid				[UNIQUEIDENTIFIER], 
	@StartDate				[DATETIME],  
	@EndDate				[DATETIME],     
	@CurPtr					[UNIQUEIDENTIFIER],     
	@Dir					[INT] = -1,
	@Col					[INT] = 0,
	@ColType				[INT] = 0,
	@CostPtr				[UNIQUEIDENTIFIER] = 0X0,
	@IsEndorsedRecieved		[BIT] = 0,
	@IsDiscountedRecieved	[BIT] = 0,
	@IsDontShowNotDeliverd	[BIT] = 0,
	@BankGuid				[UNIQUEIDENTIFIER],
	@stateChkList           [INT],
	@Str					[NVARCHAR] (MAX) = '',
	@ColByTupe				[INT] = 0,
	@bCustOnly				[INT] = 0,
	@EditStartDate			[DATETIME] = '1/1/1980',
	@EditEndDate			[DATETIME] = NULL,
	@CurrPtr				[UNIQUEIDENTIFIER] = 0X0,
	@emptyPeriods			[BIT] = 0,
	@CustGuid				[UNIQUEIDENTIFIER] = 0X0
AS
	SET NOCOUNT ON;
	IF @EditEndDate IS NULL 
		SELECT @EditEndDate = [dbo].[fnDate_Amn2Sql]( [VALUE]) FROM [op000] WHERE [NAME] = 'AmnCfg_EPDate'
	
	DECLARE @UserId [UNIQUEIDENTIFIER]
	DECLARE @Sql NVARCHAR(4000)
	
	DECLARE @Date [DateTime] ,@Date2 [DateTime] 
	CREATE TABLE [#SecViol]( [Type] [INT], [Cnt] [INTEGER]) 
	CREATE TABLE [#CostTbl]( [CostGUID] [UNIQUEIDENTIFIER], [Security] [INT])
	CREATE TABLE [#AccTbl]( [GUID] [UNIQUEIDENTIFIER], [Security] [INT],[Level] [INT])
	CREATE TABLE [#NotesTbl]([Type] [UNIQUEIDENTIFIER], [Security] [INT]) 
	CREATE TABLE [#Period] ([BDate] DATETIME,[EDate] DATETIME )
	CREATE TABLE [#CustTbl] ([GUID] [UNIQUEIDENTIFIER], [Security] [INT])
      --
	CREATE TABLE [#RESULT]
	(
		[chCuide]			[UNIQUEIDENTIFIER],
		[chType]			[UNIQUEIDENTIFIER],
		[ParentGuid]		[UNIQUEIDENTIFIER],
		[acGuid]			[UNIQUEIDENTIFIER],
		[Security]			[INT],
		[acSecurity]		[INT],
		[chSecurity]		[INT],
		[Val]				[FLOAT],
		[Dir]				[INT],
		[DueDate]			[DATETIME],
		[Note]				[NVARCHAR](256) COLLATE ARABIC_CI_AI,
		[Number]			[NVARCHAR](256),
		[CollectedValue]	[FLOAT],
		[CheckCurrency]		[UNIQUEIDENTIFIER],
		[BankName]			[NVARCHAR](256)  COLLATE ARABIC_CI_AI,
		[chPayble]			[INT],
		[chRecivable]		[INT],
		[StateName]         [INT],
		[CustGuid]			[UNIQUEIDENTIFIER]
	)
	SET @UserId = [dbo].[fnGetCurrentUserGUID]()     
	INSERT INTO [#NotesTbl] EXEC [prcGetNotesTypesList]  @SrcGuid, @UserID 
	INSERT INTO [#AccTbl] EXEC prcGetAccountsList @AccPtr
	INSERT INTO [#CostTbl] EXEC [prcGetCostsList] @CostPtr
	INSERT INTO [#CustTbl] EXEC [prcGetCustsList] @CustGuid, @AccPtr, 0x0
	
	IF @CostPtr = 0X00
		INSERT INTO [#CostTbl] VALUES (0X00,1)
	ELSE
		INSERT INTO [#CostTbl]
		SELECT GUID,SECURITY FROM co000
		WHERE GUID = @CostPtr
		
	IF @AccPtr = 0X00
	BEGIN
		INSERT INTO [#AccTbl] (guid,level)
		SELECT GUID,0 FROM ac000 WHERE GUID NOT IN (SELECT GUID FROM [#AccTbl])
	END
	
	IF @CustGuid = 0X00 AND @bCustOnly = 0
		INSERT INTO [#CustTbl] VALUES (0X00,1)
		
	CREATE CLUSTERED INDEX SDFSDAF ON [#AccTbl]( [GUID])
SET @sql = 'declare @st INT = ' + CAST(@stateChkList AS Varchar(250))
Set @sql = @sql + ' 
	INSERT INTO [#RESULT]
	SELECT 
		[ch].[chGuid],
		[ch].[chType],
		[ch].[chParent],
		[ch].[chAccount],
		[chSecurity],
		[ac].[Security],
		[nt].[Security],
		[dbo].[fnCurrency_fix]([ch].[chVal],[ch].[chCurrencyPtr],[ch].[chCurrencyVal], ''' + cast(@CurPtr as NVARCHAR(36) )+ ''', [ch].[chDate]),
		[ch].[chDir],
		[ch].[chDueDate],
		[ch].[chNotes],
		CAST([ch].[chNumber] as NVARCHAR(MAX))+'':''+[ch].[chNum],
		[dbo].[fnCurrency_fix]([Collect].[Val],[ch].[chCurrencyPtr],[ch].[chCurrencyVal], ''' + cast(@CurPtr as NVARCHAR(36) )+ ''', [ch].[chDate]),
		[ch].[chCurrencyPtr],
		[b].[BankName],
		0,
		0,
		[ch].[chstate],
		[ch].[chCustomerGUID] 
	FROM
		[vwCh] AS [ch] 
		INNER JOIN [#NotesTbl] AS [nt] ON [ch].[chType] = [nt].[Type] 
		JOIN [#AccTbl]  AS [ac] ON [ac].[GUID] = [ch].[chAccount] 
		JOIN [#CostTbl] AS [co] ON [chCost1GUID] = [co].[CostGUID]
		JOIN [#CustTbl] AS [cut] ON [cut].[GUID] = [ch].[chCustomerGUID] 
		LEFT JOIN [vwCu] AS [cu] ON [cu].[cuAccount] = [ac].[GUID] AND [cu].[cuGUID] = [ch].[chCustomerGUID] 
		LEFT JOIN [ColCh000] as [collect] on [Collect].[chGUID] = [CH].[chGUID] 
		LEFT JOIN [BANK000] AS [b]	ON [b].[GUID] = [CH].[chBankGuid]
	WHERE 
		 ( ' + cast(@Dir as NVARCHAR(36))+' = -1 OR [chDir] = '+ cast (@Dir as NVARCHAR(36))+')'
		 +Case YEAR(@StartDate) WHEN 1980 THEN '' ELSE 'AND [chDueDate] >= '+ [dbo].[fnDateString](@StartDate ) END
		+Case YEAR(@EndDate) WHEN 1980 THEN '' ELSE 'AND [chDueDate] <=' + [dbo].[fnDateString]( @EndDate )END
		+'AND	( (@st & 64 = 64 AND chDir= 2 AND [chState] = 0  ) OR (@st & 1 = 1 AND chDir= 1 AND [chState] = 0  ) OR (@st & 256 = 256 AND [chState] = 2  and chDir=2) OR (@st & 32 = 32 AND [chState] = 2  and chDir=1) OR (@st & 2 = 2 AND [chState] = 7) OR (@st & 8 = 8 AND [chState] = 10) OR ( (@st & 4 = 4 AND [chState] = 4) AND '
		+ cast (@IsEndorsedRecieved as Nvarchar(1)) + ' = 0) OR ((@st & 16 = 16 AND [chState] = 11 ) AND '
		+ cast (@IsDiscountedRecieved  as Nvarchar(1)) + ' = 0) OR ((@st & 128 = 128 AND [chState] = 14) AND ' 
		+ cast (@IsDontShowNotDeliverd as Nvarchar(1)) + ' = 0)) AND ( [chDate] BETWEEN '
	    + [dbo].[fnDateString] (@EditStartDate )+' AND '+[dbo].[fnDateString](@EditEndDate )+')'
	if ( @CurrPtr <> 0x0)
		Set @sql = @sql + 'AND [ch].[chCurrencyPtr] = ''' + cast ( @CurrPtr  as NVARCHAR(36))+'''' 
	if ( @BankGuid <> 0x0)
		Set @sql = @sql + 'AND [ch].[chBankGuid] = ''' + cast ( @BankGuid  as NVARCHAR(36))+'''' 
	EXEC( @sql)
	EXEC [prcCheckSecurity]
	IF (@Col = 1)
	BEGIN
		Set @Date = @StartDate   
		IF @ColType = 0
		BEGIN
			While(@Date <= @EndDate)
			Begin
				INSERT INTO [#Period] VALUES(@Date,@Date)
				SET @Date = @Date + 1
			END 
		END
		ELSE IF  @ColType = 1
		BEGIN
			set LANGUAGE 'arabic'
			INSERT INTO [#Period] SELECT [StartDate],[EndDate] FROM [dbo].[fnGetPeriod](2, @StartDate, @EndDate) --2 mean the col is weekly
			set LANGUAGE 'english' 
		END
		ELSE
			INSERT INTO [#Period] SELECT * FROM [fnGetStrToPeriod](@STR )
	END
	DELETE FROM #RESULT  WHERE ( Val-(select Sum([CollectedValue])from #RESULT as r2 where r2.chCuide=#RESULT.chCuide ))<=0
	IF @Col = 0
	BEGIN 
		Set @sql = ' 
		SELECT
			[r].[chCuide],
			[r].[ParentGuid],
			[r].[acGuid],
			[r].[Val],
			[r].[Dir],
			[r].[DueDate],
			[r].[Note],
			[r].[Number],
			[r].[BankName],
			[r].[StateName],
			[ac].[Code] AS [acCode],
			[ac].[Name] AS [acName],
			[ac].[LatinName] AS [acLatinName],
			[nt].[Name] AS [ntName],
			[nt].[LatinName] AS  [ntLatinName],
			[nt].[Abbrev] AS [ntAbbrev],
			[nt].[LatinAbbrev] AS [ntLatinAbbrev],
			Sum(ISNULL([CollectedValue], 0)) AS [CollectedValue],
			[cu].[GUID] AS [CustPtr],
			CASE dbo.fnConnections_GetLanguage() WHEN 0 THEN [cu].[CustomerName] ELSE (CASE [cu].[LatinName] WHEN '''' THEN [cu].[CustomerName] ELSE [cu].[LatinName] END) END AS CustName '
		
		Set @sql = @sql + 
			'FROM 
			[#Result] AS [r] 
			INNER JOIN [ac000] AS [ac] ON [r].[acGuid] = [ac].[Guid]
			INNER JOIN [nt000] AS [nt] ON [r].[chType] = [nt].[Guid]'
			
		if @bCustOnly = 1 
			set @sql = @sql + 'INNER JOIN [cu000] AS [cu] ON [ac].[GUID] = [cu].[AccountGUID] AND [r].[CustGuid] = [cu].[GUID]'
		else
			set @sql = @sql + 'LEFT JOIN [cu000] AS [cu] ON [ac].[GUID] = [cu].[AccountGUID] AND [r].[CustGuid] = [cu].[GUID]'
			
		Set @sql = @sql + '
			GROUP BY 
				[r].[chCuide],
				[r].[ParentGuid],
				[r].[acGuid],
				[r].[Val],
				[r].[Dir],
				[r].[DueDate],
				[r].[Note],
				[r].[Number],
				[r].[BankName],
				[r].[StateName],
				[ac].[Code],
				[ac].[Name],
				[ac].[LatinName],
				[nt].[Name],
				[nt].[LatinName],
				[nt].[Abbrev],
				[nt].[LatinAbbrev],
				[cu].[GUID],
				[cu].[CustomerName],
				[cu].[LatinName]  '
		set @sql = @sql + '
		ORDER BY [ac].[Code], [r].[Number]' 
		EXEC (@sql)
		
	END
	ELSE
	BEGIN
		SET @Sql = 
			'SELECT 
				SUM(CASE [Dir] WHEN 1 THEN [Val] ELSE 0 END) AS [CashVal],
				SUM(CASE [Dir] WHEN 2 THEN [Val] ELSE 0 END) AS [PaidVal],
				SUM(CASE [Dir] WHEN 1 THEN isnull([CollectedValue], 0) ELSE 0 END) AS [CashCollectedValue],
				SUM(CASE [Dir] WHEN 2 THEN isnull([CollectedValue], 0) ELSE 0 END ) AS [PaidCollectedValue],
				[r].[chPayble],
				[r].[chRecivable]'
		SET @Sql = @Sql + ',[BDate] AS [StatrtDate],[EDate] AS [EndDate]'
		IF (@ColByTupe = 1)
			SET @Sql = @Sql + ',[r].[chType]'
		SET @Sql = @Sql + ', [r].[Dir] as [Direction]' 
		SET @Sql = @Sql + ' FROM [#Result] AS [r] '
		
		    IF @EmptyPeriods = 0
			SET @Sql = @Sql + ' INNER JOIN [#Period] AS [P] ON [DueDate] BETWEEN [BDate] AND [EDate]'
			ELSE
			SET @Sql = @Sql + ' RIGHT JOIN [#Period] AS [P] ON [DueDate] BETWEEN [BDate] AND [EDate]'
		SET @Sql = @Sql + ' GROUP BY '	
		SET @Sql = @Sql + '[BDate],[EDate]'
		IF (@ColByTupe = 1)
			SET @Sql = @Sql + ',[r].[chType]'
		SET @SQl = @Sql + ', [r].[Dir], [r].[chPayble], [r].[chRecivable]' 
		SET @Sql = @Sql + ' ORDER BY '	
			SET @Sql = @Sql + '[BDate],[EDate]'
		IF (@ColByTupe = 1)
			SET @Sql = @Sql + ',[r].[chType]'

		EXEC (@Sql)
		IF (@ColByTupe = 1)
		BEGIN
			SELECT DISTINCT 
				[nt].[Name] AS [ntName],
				[nt].[LatinName] AS  [ntLatinName],
				[r].[chType],
				[r].[chPayble], 
				[r].[chRecivable]
			FROM [#Result] AS [r] 
			INNER JOIN [nt000] AS [nt] ON [r].[chType] = [nt].[Guid]
			ORDER BY [r].[chType]
		END
		
--select * from #Period 		
	END
	SELECT * FROM [#SecViol]
/*
	prcConnections_add2 'ãÏíÑ'
	exec  [repCheckDueDate] '00000000-0000-0000-0000-000000000000', '92ebed34-8237-419e-a7e4-8db55670b66d', '1/1/2006 0:0:0.0', '10/25/2010 23:59:34.230', '08267a47-99fe-11d9-bee1-00e07dc0d524', -1, 1, 2, '00000000-0000-0000-0000-000000000000', '1-1-2006 0:0,1-31-2006 23:59,2-1-2006 0:0,2-28-2006 23:59,3-1-2006 0:0,3-31-2006 23:59,4-1-2006 0:0,4-30-2006 23:59,5-1-2006 0:0,5-31-2006 23:59,6-1-2006 0:0,6-30-2006 23:59,7-1-2006 0:0,7-31-2006 23:59,8-1-2006 0:0,8-31-2006 23:59,9-1-2006 0:0,9-30-2006 23:59,10-1-2006 0:0,10-31-2006 23:59,11-1-2006 0:0,11-30-2006 23:59,12-1-2006 0:0,12-31-2006 23:59,1-1-2007 0:0,1-31-2007 23:59,2-1-2007 0:0,2-28-2007 23:59,3-1-2007 0:0,3-31-2007 23:59,4-1-2007 0:0,4-30-2007 23:59,5-1-2007 0:0,5-31-2007 23:59,6-1-2007 0:0,6-30-2007 23:59,7-1-2007 0:0,7-31-2007 23:59,8-1-2007 0:0,8-31-2007 23:59,9-1-2007 0:0,9-30-2007 23:59,10-1-2007 0:0,10-31-2007 23:59,11-1-2007 0:0,11-30-2007 23:59,12-1-2007 0:0,12-31-2007 23:59,1-1-2008 0:0,1-31-2008 23:59,2-1-2008 0:0,2-29-2008 23:59,3-1-2008 0:0,3-31-2008 23:59,4-1-2008 0:0,4-30-2008 23:59,5-1-2008 0:0,5-31-2008 23:59,6-1-2008 0:0,6-30-2008 23:59,7-1-2008 0:0,7-31-2008 23:59,8-1-2008 0:0,8-31-2008 23:59,9-1-2008 0:0,9-30-2008 23:59,10-1-2008 0:0,10-31-2008 23:59,11-1-2008 0:0,11-30-2008 23:59,12-1-2008 0:0,12-31-2008 23:59,1-1-2009 0:0,1-31-2009 23:59,2-1-2009 0:0,2-28-2009 23:59,3-1-2009 0:0,3-31-2009 23:59,4-1-2009 0:0,4-30-2009 23:59,5-1-2009 0:0,5-31-2009 23:59,6-1-2009 0:0,6-30-2009 23:59,7-1-2009 0:0,7-31-2009 23:59,8-1-2009 0:0,8-31-2009 23:59,9-1-2009 0:0,9-30-2009 23:59,10-1-2009 0:0,10-31-2009 23:59,11-1-2009 0:0,11-30-2009 23:59,12-1-2009 0:0,12-31-2009 23:59,1-1-2010 0:0,1-31-2010 23:59,2-1-2010 0:0,2-28-2010 23:59,3-1-2010 0:0,3-31-2010 23:59,4-1-2010 0:0,4-30-2010 23:59,5-1-2010 0:0,5-31-2010 23:59,6-1-2010 0:0,6-30-2010 23:59,7-1-2010 0:0,7-31-2010 23:59,8-1-2010 0:0,8-31-2010 23:59,9-1-2010 0:0,9-30-2010 23:59,10-1-2010 0:0,10-25-2010 23:59', 0, 0, 0, '1/1/2006 0:0:0.0', '10/25/2010 0:0:0.0', '00000000-0000-0000-0000-000000000000', 1
	SELECT GUID,* FROM MY000
*/
############################################################
#END
