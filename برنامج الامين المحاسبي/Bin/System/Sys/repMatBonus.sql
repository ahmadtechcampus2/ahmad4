#######################################################################################
## repSpecialOffer 
#######################################################################################
CREATE PROCEDURE prcIsMatCondVerified
	@CondGUID UNIQUEIDENTIFIER, 
	@mtGUID UNIQUEIDENTIFIER
AS 
	SET NOCOUNT ON 
	DECLARE @result INT 
	SET @result = 0	
	DECLARE 
		@sql NVARCHAR(max),
		@Cond NVARCHAR(max)
	
	SET @Cond = 	dbo.fnGetConditionStr2( NULL , @CondGUID)
	IF ISNULL( @Cond, '') != ''
	BEGIN 
		CREATE TABLE [#R]( [found] BIT)
		SET @sql = ' 
			SET NOCOUNT ON 
			IF EXISTS ( SELECT * FROM [vwMtGr]'
			IF CHARINDEX( '<<>>', @Cond) > 0
			BEGIN
				Declare @CF_Table NVARCHAR(255) 
				SELECT @CF_Table = CFGroup_Table FROM CFMapping000 WHERE Orginal_Table = 'mt000'
				SET @sql = @sql +'  LEFT JOIN '+@CF_Table+' ON vwmtgr.mtGUID = '+@CF_Table+'.orginal_guid'
				SET @Cond = REPLACE(@Cond,'<<>>','')
			END
			SET @Sql = @Sql +' WHERE ((' + @Cond + ') AND ([mtGuid] = ''' + CAST( @mtGUID AS NVARCHAR(250)) + ''')))
				INSERT INTO [#R] SELECT 1
			ELSE 
				INSERT INTO [#R] SELECT 0 '
		EXEC (@sql)
		IF EXISTS ( SELECT * FROM [#R] WHERE [found] = 1)
			SET @result = 1
	END 
	RETURN @result

#######################################################################################
CREATE PROCEDURE prcIsCustCondVerified
	@CondGUID UNIQUEIDENTIFIER, 
	@cuGUID UNIQUEIDENTIFIER
AS 
	SET NOCOUNT ON 
	DECLARE @result INT 
	SET @result = 0	
	DECLARE @sql NVARCHAR(max)
	SET @sql = 	dbo.fnGetCustConditionStr( @CondGUID)
	IF ISNULL( @sql, '') != ''
	BEGIN 
		CREATE TABLE [#R]( [found] BIT)

		SET @sql = ' 
			SET NOCOUNT ON 

			IF EXISTS ( SELECT * FROM [vwCu] WHERE ' + @sql + ' AND [cuGuid] = ''' + CAST( @cuGUID AS NVARCHAR(250)) + ''')
				INSERT INTO [#R] SELECT 1
			ELSE 
				INSERT INTO [#R] SELECT 0 '
		EXEC (@sql)
		IF EXISTS ( SELECT * FROM [#R] WHERE [found] = 1)
			SET @result = 1
	END 
	RETURN @result

#######################################################################################
CREATE PROCEDURE repSpecialOffer
	@Qty [FLOAT],
	@buDate [DATETIME],
	@mtGuid [UNIQUEIDENTIFIER],
	@Unit [INT],
	@btGuid [UNIQUEIDENTIFIER], 
	@cuGuid [UNIQUEIDENTIFIER] = 0x0,
	@coGuid [UNIQUEIDENTIFIER] = 0x0
AS
	SET NOCOUNT ON
	
	IF NOT EXISTS ( SELECT TOP 1 [GUID] FROM [SM000])	
		RETURN 

	CREATE TABLE [#Result]
	(
		[Guid] UNIQUEIDENTIFIER,
		[Number] FLOAT,
		[Type] INT,
		[MatPtr1] UNIQUEIDENTIFIER, 
		[Qty1] FLOAT, 
		[Unity1] INT, 
		[StartDate] DATETIME, 
		[EndDate] DATETIME, 
		[Notes] NVARCHAR(250) COLLATE ARABIC_CI_AI, 
		[Main] BIT,
		[GroupGUID] UNIQUEIDENTIFIER,
		[bIncludeGroups] BIT,
		[PriceType] INT,
		[Discount] FLOAT,
		[CustAccGUID] UNIQUEIDENTIFIER,
		[OfferAccGUID] UNIQUEIDENTIFIER,
		[IOfferAccGUID] UNIQUEIDENTIFIER,
		[bAllBt] INT,
		[MatPtr2] UNIQUEIDENTIFIER,
		[Qty2] FLOAT, 
		[Unity2] FLOAT, 
		[Price] FLOAT, 
		[Flag] INT, 
		[CurPtr] UNIQUEIDENTIFIER,
		[CurVal] FLOAT, 
		[Policy] INT,
		[bBonus] BIT
	)

	CREATE TABLE [#Accounts]( [GUID] [UNIQUEIDENTIFIER])
	DECLARE @acGUID [UNIQUEIDENTIFIER]
	SELECT @acGUID = [cuAccount] FROM [vwCu] WHERE [cuGuid] = @cuGuid
	IF ISNULL( @cuGuid, 0x0) != 0x0 
	BEGIN
		INSERT INTO [#Accounts] SELECT @acGUID
		INSERT INTO [#Accounts] SELECT [GUID] FROM [dbo].[fnGetAccountParents]( @acGUID)
		INSERT INTO [#Accounts] SELECT [ParentGUID] FROM [ci000] WHERE [SonGUID] = @acGUID
	END 

	CREATE TABLE [#CostTbl]( [CostGuid] [UNIQUEIDENTIFIER]) 
	IF ISNULL( @coGuid, 0x0) != 0x0 
	BEGIN
		INSERT INTO [#CostTbl] SELECT @coGuid
		INSERT INTO [#CostTbl] SELECT [GUID] FROM [dbo].[fnGetCostParents]( @coGuid)
	END 

	IF ISNULL( @coGuid, 0x0) = 0x0 
	BEGIN 
		INSERT INTO [#CostTbl] SELECT [coGuid] FROM [vwCo]
		INSERT INTO [#CostTbl] SELECT 0x0
	END 	

	DECLARE 
		@C CURSOR,
		@smGUID UNIQUEIDENTIFIER,
		@smMatGUID UNIQUEIDENTIFIER,
		@smGroupGUID UNIQUEIDENTIFIER,
		@smMatCond UNIQUEIDENTIFIER,
		@smIncludeGroups BIT,
		@smAccountGUID UNIQUEIDENTIFIER,
		@smCustCond UNIQUEIDENTIFIER,
		@smCostGUID UNIQUEIDENTIFIER
	
	DECLARE 
		@found BIT,
		@g UNIQUEIDENTIFIER

	SET @C = CURSOR FAST_FORWARD FOR 
		SELECT [Guid], [MatGUID], [GroupGUID], [bIncludeGroups], [MatCondGUID], [CustAccGUID], [CustCondGUID], [CostGUID]
		FROM 
			[sm000] [sm]
		WHERE 
			([bActive] = 1)
			AND ((@buDate = '1/1/1980') OR ( @buDate BETWEEN [dbo].[fnGetDateFromDT]( [StartDate]) AND [dbo].[fnGetDateFromDT]( [EndDate])))
			AND(( @Qty = -1) OR 
			( @Qty * (SELECT CASE @Unit WHEN 2 THEN ( CASE WHEN [mtUnit2Fact] = 0 THEN 1 ELSE [mtUnit2Fact] END) WHEN 3 THEN ( CASE WHEN [mtUnit3Fact] = 0 THEN 1 ELSE [mtUnit3Fact] END) ELSE 1 END FROM [vwMt] WHERE [mtGUID] = @mtGuid) / 
			( SELECT CASE [Unity] WHEN 2 THEN ( CASE WHEN [mtUnit2Fact] = 0 THEN 1 ELSE [mtUnit2Fact] END) WHEN 3 THEN ( CASE WHEN [mtUnit3Fact] = 0 THEN 1 ELSE [mtUnit3Fact] END) ELSE 1 END FROM [vwMt] WHERE [mtGUID] = @mtGuid) >= [Qty]))
			AND( [bAllBt] = 1 OR @btGuid = 0x0 OR @btGuid IN( SELECT [btGuid] FROM [smBt000] WHERE [ParentGUID] = [sm].[Guid]))
			AND( [CostGUID] = 0x0 OR [CostGUID] IN( SELECT [CostGuid] FROM [#CostTbl]))
	------------------------------------------------------------
	------------------------------------------------------------

	OPEN @C FETCH NEXT FROM @C INTO @smGUID, @smMatGUID, @smGroupGUID, @smIncludeGroups, @smMatCond, @smAccountGUID, @smCustCond, @smCostGUID
	WHILE @@FETCH_STATUS = 0
	BEGIN 

		DECLARE @bMat BIT, @bAcc BIT 

		SET @bMat = 0

		IF (@smMatGUID = @mtGuid) AND (@mtGuid != 0x0)
			SET @bMat = 1
		ELSE BEGIN 
			SELECT @g = [mtGroup] FROM [vwMt] WHERE [mtGUID] = @mtGuid
			IF @smMatCond = 0x0
			BEGIN
				IF @smGroupGUID = 0x0 
					SET @bMat = 0
				ELSE BEGIN

					IF @smIncludeGroups = 0
					BEGIN 
						IF @smGroupGUID = @g 
							SET @bMat = 1
					END ELSE BEGIN 
						IF (EXISTS (SELECT [Guid] FROM [dbo].[fnGetGroupParents]( @g) WHERE [GUID] = @smGroupGUID)) OR (@smGroupGUID = @g)
							SET @bMat = 1							
					END 
				END 
			END ELSE BEGIN 
				EXEC @found = prcIsMatCondVerified @smMatCond, @mtGuid

				IF @smGroupGUID = 0x0
				BEGIN 
					SET @bMat = @found
				END ELSE BEGIN 
					IF @smIncludeGroups = 0
					BEGIN 
						IF (@smGroupGUID = @g) AND (@found = 1)
							SET @bMat = 1
					END ELSE BEGIN 
						IF ((EXISTS (SELECT [Guid] FROM [dbo].[fnGetGroupParents]( @g) WHERE [GUID] = @smGroupGUID)) OR (@smGroupGUID = @g)) AND (@found = 1)
							SET @bMat = 1							
					END 
				END 
			END 
		END 

		IF @bMat = 1
		BEGIN 
			SET @bAcc = 0
			IF ISNULL( @smCustCond, 0x0) = 0x0
			BEGIN 
				IF (@smAccountGUID = 0x0) OR EXISTS( SELECT * FROM [#Accounts] WHERE [GUID] = @smAccountGUID)
					SET @bAcc = 1
			END ELSE BEGIN 

				EXEC @found = prcIsCustCondVerified @smCustCond, @cuGuid
				IF ((@smAccountGUID = 0x0) OR EXISTS( SELECT * FROM [#Accounts] WHERE [GUID] = @smAccountGUID)) AND @found = 1 
					SET @bAcc = 1
			END 

			IF @bAcc = 1
			BEGIN 
				INSERT INTO [#Result]
				SELECT 
					[smGuid],
					[smNumber],
					[smType],
					[smMatPtr], 
					[smQty], 
					[smUnity], 
					[smStartDate], 
					[smEndDate], 
					[smNotes], 
					[smbAddMain],
					[smGroupGUID],
					[smbIncludeGroups],
					[smPriceType],
					[smDiscount],
					[smCustAccGUID],
					[smOfferAccGUID],
					[smIOfferAccGUID],
					[smbAllBt],
					[sdMatPtr], 
					[sdQty], 
					[sdUnity], 
					[sdPrice], 
					[sdPriceFlag], 
					[sdCurrencyPtr], 
					[sdCurrencyVal], 
					[sdPolicyType],
					[sdBonus]
				FROM 	
					[vwSmSd]
				WHERE 
					[smGuid] = @smGUID
			END 
		END 
		FETCH NEXT FROM @C INTO @smGUID, @smMatGUID, @smGroupGUID, @smIncludeGroups, @smMatCond, @smAccountGUID, @smCustCond, @smCostGUID
	END 
	CLOSE @C DEALLOCATE @C  

	SELECT TOP 1 * FROM [#Result] ORDER BY [Number] DESC

#######################################################################################
CREATE PROCEDURE repGetMaterialsBonus
	@mtGUID UNIQUEIDENTIFIER, 
	@acGUID UNIQUEIDENTIFIER, 
	@coGUID UNIQUEIDENTIFIER, 
	@useFlasg INT,
	@effectFlasg INT,
	@typeFlasg INT
AS 

	SET NOCOUNT ON 
	
	CREATE TABLE [#Result]
	(
		[smGuid] UNIQUEIDENTIFIER
	)

	DECLARE 
		@C CURSOR,
		@smGuid UNIQUEIDENTIFIER,
		@smMatGuid UNIQUEIDENTIFIER,
		@smGroupGuid UNIQUEIDENTIFIER,
		@smIncludeGroups BIT,
		@smMatCond UNIQUEIDENTIFIER,
		@smAccountGuid UNIQUEIDENTIFIER,
		@smCostGuid UNIQUEIDENTIFIER,
		@smCustCond UNIQUEIDENTIFIER


	CREATE TABLE [#Custs]
	(	
		[cuGuid] UNIQUEIDENTIFIER,
		[cuSecurity] INT 
	)

	DECLARE 
		@found BIT,
		@g UNIQUEIDENTIFIER


	SET @C = CURSOR FAST_FORWARD FOR 
		SELECT 
			[guid], [MatGuid], [GroupGuid], [bIncludeGroups], [MatCondGuid], [CustAccGuid], [CostGuid], [CustCondGUID]
		FROM 
			[sm000]
		WHERE 
			(
				(@typeFlasg = 3) 
				OR 
				((@typeFlasg = 1) AND ([Type] = 1))
				OR 
				((@typeFlasg = 2) AND ([Type] = 2))
			)
			AND 
			(
				(@effectFlasg = 3)
				OR 
				((@effectFlasg = 1) AND ((GetDate() BETWEEN [StartDate] AND [EndDate]) AND ([bActive] = 1)))
				OR 
				((@effectFlasg = 2) AND ((GetDate() NOT BETWEEN [StartDate] AND [EndDate]) OR ([bActive] = 0)))
			)
			AND 
			(
				(@useFlasg = 3)
				OR 
				((@useFlasg = 1) AND (dbo.fnIsMatBonusUsed([guid]) = 1))
				OR 
				((@useFlasg = 2) AND (dbo.fnIsMatBonusUsed([guid]) = 0))
			)
			AND 
				((@coGUID = 0x0) OR ([CostGUID] IN (SELECT [GUID] FROM [dbo].[fnGetCostsList]( @coGUID))))

	
	OPEN @C FETCH NEXT FROM @C INTO 
		@smGuid, @smMatGuid, @smGroupGuid, @smIncludeGroups, @smMatCond, @smAccountGuid, @smCostGuid, @smCustCond

	WHILE @@FETCH_STATUS = 0
	BEGIN 
		
		DECLARE @bMat BIT, @bAcc BIT 

		SET @bMat = 0


		IF (@mtGuid = 0x0) OR ((@smMatGUID = @mtGuid) AND (@mtGuid != 0x0))
			SET @bMat = 1
		ELSE BEGIN 
			SELECT @g = [mtGroup] FROM [vwMt] WHERE [mtGUID] = @mtGuid
			IF @smMatCond = 0x0
			BEGIN
				IF @smGroupGUID = 0x0 
					SET @bMat = 0
				ELSE BEGIN

					IF @smIncludeGroups = 0
					BEGIN 
						IF @smGroupGUID = @g 
							SET @bMat = 1
					END ELSE BEGIN 
						IF (EXISTS (SELECT [Guid] FROM [dbo].[fnGetGroupParents]( @g) WHERE [GUID] = @smGroupGUID)) OR (@smGroupGUID = @g)
							SET @bMat = 1							
					END 
				END 
			END ELSE BEGIN 
				EXEC @found = prcIsMatCondVerified @smMatCond, @mtGuid

				IF @smGroupGUID = 0x0
				BEGIN 
					SET @bMat = @found
				END ELSE BEGIN 
					IF @smIncludeGroups = 0
					BEGIN 
						IF (@smGroupGUID = @g) AND (@found = 1)
							SET @bMat = 1
					END ELSE BEGIN 
						IF ((EXISTS (SELECT [Guid] FROM [dbo].[fnGetGroupParents]( @g) WHERE [GUID] = @smGroupGUID)) OR (@smGroupGUID = @g)) AND (@found = 1)
							SET @bMat = 1							
					END 
				END 
			END 
		END 

		IF @bMat = 1
		BEGIN 
			SET @bAcc = 0
			IF @acGUID = 0x0
				SET @bAcc = 1
			ELSE BEGIN
				IF ISNULL( @smCustCond, 0x0) = 0x0
				BEGIN 
					IF ((@smAccountGUID = 0x0) OR EXISTS( SELECT * FROM [dbo].[fnGetAccountsList]( @acGUID, DEFAULT) WHERE [guid] = @smAccountGUID))
						SET @bAcc = 1
				END ELSE BEGIN 
					DELETE [#Custs]
					INSERT INTO [#Custs] EXEC [prcGetCustsList] 0x0, @acGuid, @smCustCond

					IF (EXISTS( 
						SELECT * FROM 
							[#Custs] [c] 
							INNER JOIN [vwCu] [cu] ON [c].[cuGuid] = [cu].[cuGuid] 
							INNER JOIN [vwAc] [ac] ON [ac].[acGuid] = [cu].[cuAccount]
						WHERE 
							[acGuid] = @smAccountGUID))
							
							SET @bAcc = 1
				END 
			END 

			IF @bAcc = 1
			BEGIN 
				INSERT INTO [#Result] 
				SELECT 
					@smGuid

			END 
		END 
		FETCH NEXT FROM @C INTO 
			@smGuid, @smMatGuid, @smGroupGuid, @smIncludeGroups, @smMatCond, @smAccountGuid, @smCostGuid, @smCustCond
	END 
	CLOSE @C DEALLOCATE @c 

	SELECT 
		DISTINCT 
		[r].[smGuid] AS [smGuid],
		[sm].[Notes] AS [smDesc],
		[sm].[Type] AS [smType],
		[dbo].[fnIsMatBonusUsed]( [sm].[guid]) AS [smUsed],
		(CASE [sm].[bActive] 
			WHEN 1 THEN (CASE WHEN GetDate() BETWEEN [StartDate] AND [EndDate] THEN 1 ELSE 0 END) 
			ELSE 0
		END) AS [smEffected],

		[mt].[mtGuid] AS [mtGuid],
		[mt].[mtCode] AS [mtCode],
		(CASE dbo.fnConnections_GetLanguage() 
			WHEN 0 THEN  + [mt].[mtName] 
			ELSE 
				(CASE [mt].[mtLatinName] 
					WHEN '' THEN [mt].[mtName]
					ELSE [mt].[mtLatinName]
				END)
		END) AS [mtName], 

		[gr].[grGuid] AS [grGuid],
		[gr].[grCode] AS [grCode],
		(CASE dbo.fnConnections_GetLanguage() 
			WHEN 0 THEN  + [gr].[grName] 
			ELSE 
				(CASE [gr].[grLatinName] 
					WHEN '' THEN [gr].[grName]
					ELSE [gr].[grLatinName]
				END)
		END) AS [grName], 

		[co].[coGuid] AS [coGuid],
		[co].[coCode] AS [coCode],
		(CASE dbo.fnConnections_GetLanguage() 
			WHEN 0 THEN  + [co].[coName] 
			ELSE 
				(CASE [co].[coLatinName] 
					WHEN '' THEN [co].[coName]
					ELSE [co].[coLatinName]
				END)
		END) AS [coName], 
					
		[ac].[acGuid] AS [acGuid],
		[ac].[acCode] AS [acCode],
		(CASE dbo.fnConnections_GetLanguage() 
			WHEN 0 THEN  + [ac].[acName] 
			ELSE 
				(CASE [ac].[acLatinName] 
					WHEN '' THEN [ac].[acName]
					ELSE [ac].[acLatinName]
				END)
		END) AS [acName], 

		[cuc].[cndName] AS [CustCondName],
		[mtc].[cndName] AS [MatCondName]
	FROM 
		[#Result] [r]
		INNER JOIN [sm000] [sm] ON [sm].[Guid] = [r].[smGuid]
		INNER JOIN (SELECT [mtGuid], [mtCode], [mtName], [mtLatinName] FROM [vwMt] UNION ALL SELECT 0x0, '', '', '') [mt] ON [mt].[mtGuid] = [sm].[MatGuid]
		INNER JOIN (SELECT [grGuid], [grCode], [grName], [grLatinName] FROM [vwGr] UNION ALL SELECT 0x0, '', '', '') [gr] ON [gr].[grGuid] = [sm].[GroupGuid]
		INNER JOIN (SELECT [coGuid], [coCode], [coName], [coLatinName] FROM [vwCo] UNION ALL SELECT 0x0, '', '', '') [co] ON [co].[coGuid] = [sm].[CostGuid]
		INNER JOIN (SELECT [acGuid], [acCode], [acName], [acLatinName] FROM [vwAc] UNION ALL SELECT 0x0, '', '', '') [ac] ON [ac].[acGuid] = [sm].[CustAccGuid]
		INNER JOIN (SELECT [cndGuid], [cndName] FROM [vwConditions] UNION ALL SELECT 0x0, '') [cuc] ON [cuc].[cndGuid] = [sm].[CustCondGuid]
		INNER JOIN (SELECT [cndGuid], [cndName] FROM [vwConditions] UNION ALL SELECT 0x0, '') [mtc] ON [mtc].[cndGuid] = [sm].[MatCondGuid]

#######################################################################################
CREATE PROCEDURE repMatBonusMove
	@StartDate 			[DATETIME],
	@EndDate 			[DATETIME],
	@SrcTypesguid		[UNIQUEIDENTIFIER],
	@NotesContain 		[NVARCHAR](256),
	@NotesNotContain	[NVARCHAR](256),
	@MatBonusGUID		[UNIQUEIDENTIFIER] = 0x0,
	@StoreGUID			[UNIQUEIDENTIFIER] = 0x0,
	@CostGUID			[UNIQUEIDENTIFIER] = 0x0
AS 
	SET NOCOUNT ON 

	CREATE TABLE [#SecViol]( [Type] [INT], [Cnt] [INTEGER])
	CREATE TABLE [#BillsTypesTbl]( [TypeGuid] [UNIQUEIDENTIFIER], [UserSecurity] [INTEGER], [UserReadPriceSecurity] [INTEGER], [UnpostedSecurity] [INTEGER])
	CREATE TABLE [#StoreTbl]([StoreGuid] [UNIQUEIDENTIFIER], [Security] [INT])
	CREATE TABLE [#CostTbl]( [CostGuid] [UNIQUEIDENTIFIER], [Security] [INT])

	INSERT INTO [#BillsTypesTbl]	EXEC [prcGetBillsTypesList2] 	@SrcTypesguid
	INSERT INTO [#StoreTbl]		 	EXEC [prcGetStoresList] 		@StoreGUID 
	INSERT INTO [#CostTbl]			EXEC [prcGetCostsList] 			@CostGUID 

	IF ISNULL( @CostGuid, 0x0) = 0x0
		INSERT INTO [#CostTbl] VALUES (0x0,0)

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
		[smGuid]				[UNIQUEIDENTIFIER]
		-- [smType]				[INT]
	)

	DECLARE @SQL NVARCHAR(max)
	SET @SQL = '
	INSERT INTO [#Result] 
	SELECT 
		[bu].[buGuid],
		[bu].[buSecurity],
		[bu].[buType],
		[bi].[biStorePtr],
		[bi].[biCostPtr],
		[bi].[biSOGuid]
		-- [bi].[biSOType]
	FROM 
		[vwbu] [bu]
		INNER JOIN [vwbi] [bi] ON [bu].[buGuid] = [bi].[biParent]
		INNER JOIN [#BillsTypesTbl] [bt] ON [bu].[buType] = [bt].[TypeGuid]
		INNER JOIN [#CostTbl] [co] ON [co].[CostGuid] = [bi].[biCostPtr]
		INNER JOIN [#StoreTbl] [st] ON [st].[StoreGuid] = [bi].[biStorePtr] 
	WHERE 
		([bu].[buIsPosted] = 1)
		AND 
		([bi].[biSOType] = 1)
		AND 
		([bu].[buDate] BETWEEN ' + [dbo].[fnDateString]( @StartDate) + ' AND ' + [dbo].[fnDateString]( @EndDate) + ')

		AND 
		(( ''' + CAST( @MatBonusGUID AS NVARCHAR(250)) + ''' = ''00000000-0000-0000-0000-000000000000'') OR ([bi].[biSOGuid] = ''' + CAST( @MatBonusGUID AS NVARCHAR(250)) + '''))' 

		IF @NotesContain <>  ''
			 SET @SQL = @SQL + ' AND (([bu].[buNotes] LIKE ''%'' + '''+ @NotesContain + ''' +''%'') OR ([bi].[biNotes] LIKE ''%'' + ''' + @NotesContain + ''' + ''%''))' 
		IF @NotesNotContain <> ''
			SET @SQL = @SQL + ' AND (([bu].[buNotes] NOT LIKE ''%'' + ''' + @NotesNotContain + ''' + ''%'') AND ([bi].[biNotes] NOT LIKE ''%''+  ''' + @NotesNotContain + ''' + ''%'')))'	 

	EXEC(@SQL)

	EXEC [prcCheckSecurity]

	SELECT 
		[r].[buGuid] AS [BillGuid],
		[bu].[buNumber] AS [BillNumber],
		[bu].[buNotes] AS [BillNotes],
		(CASE [dbo].[fnConnections_GetLanguage]() WHEN 0 THEN [bu].[btAbbrev] ELSE [bu].[btLatinAbbrev] END) AS [BillTypeAbbrev],
		[bu].[buDate] AS [BillDate],
		[sm].[Guid] AS [SOGuid],
		[sm].[Notes] AS [SODesc]
	FROM 
		[#Result] [r]
		INNER JOIN [vwBu] [bu] ON [r].[buGuid] = [bu].[buGuid]
		INNER JOIN [sm000] [sm] ON [sm].[Guid] = [r].[smGuid]

	SELECT * FROM [#SecViol]
#######################################################################################
#END

