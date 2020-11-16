###########################################################################
###«·Õ”«»«  «·„›÷·…
###
CREATE PROCEDURE repGetFavoriteAccounts
	@UserGUID			[UNIQUEIDENTIFIER],
	@Sort				[INT], -- 0 code, 1 name, 2 bal
	@SortType			[INT], -- 0Asc, 1Desc
	@ShBalanced			[INT], --1 true
	@ShCustsOnly		[INT], 
	@ShAccsBalMore		[INT],
	@BalMore			[FLOAT],
	@ShAccsBalLess		[INT],
	@BalLess			[FLOAT],
	@IncludeUnPosted	[BIT] = 0,
	@BananceToDay		[BIT] = 0
AS 
	SET NOCOUNT ON 
	
	DECLARE 
		@c CURSOR,
		@GUID		[UNIQUEIDENTIFIER],
		@CurrGUID	[UNIQUEIDENTIFIER],
		@CostGUID	[UNIQUEIDENTIFIER],
		@Perm		[INT]
		
	SET @Perm = [dbo].[fnGetUserSec]([dbo].[fnGetCurrentUserGUID](), 0x1001B000, 0x0, 1, 1)
	
	CREATE TABLE [#SecViol]( [Type] [INT], [Cnt] [INT])  
	
	CREATE TABLE [#AccTbL](
		[AccGUID]		[UNIQUEIDENTIFIER],
		[Security]		[INT],
		[AccName]		NVARCHAR(256)  COLLATE ARABIC_CI_AI,  
		[AccLatinName]	NVARCHAR(256)  COLLATE ARABIC_CI_AI,
 		[AccCode]		NVARCHAR(256)  COLLATE ARABIC_CI_AI,
 		[NSons]			[INT],
 		[CurrGUID]		[UNIQUEIDENTIFIER],
 		[AccType]		[INT]	DEFAULT 0,
 		[CostGUID]		[UNIQUEIDENTIFIER],
 		[Num]			[INT])
 		
	CREATE TABLE [#AccTbL2](
		[AccGUID]			[UNIQUEIDENTIFIER],
		[AccpParentGUID]	[UNIQUEIDENTIFIER],
		[CurrGUID]			[UNIQUEIDENTIFIER],
		[CostGUID]			[UNIQUEIDENTIFIER],
		[CostParentGUID]	[UNIQUEIDENTIFIER])
		
	CREATE TABLE [#EnBal](
		[AccGUID]		[UNIQUEIDENTIFIER],
		[CostGUID]		[UNIQUEIDENTIFIER],
		[Bal]			[FLOAT],
 		[ceSecurity]	[INT],
		[ceTypeGUID]	[UNIQUEIDENTIFIER],
 		[Cost]			[UNIQUEIDENTIFIER])
 		
	CREATE TABLE [#Result](
		[AccGUID]		[UNIQUEIDENTIFIER],
		[acSecurity]	[INT],
		[AccName]		NVARCHAR(256)  COLLATE ARABIC_CI_AI,
		[AccLatinName]	NVARCHAR(256)  COLLATE ARABIC_CI_AI,  
 		[AccCode]		NVARCHAR(256)  COLLATE ARABIC_CI_AI,
 		[Bal]			[FLOAT],
 		[ceSecurity]	[INT],
 		[CurrCode]		NVARCHAR(256)  COLLATE ARABIC_CI_AI,
 		[CostGUID]		[UNIQUEIDENTIFIER],
 		[Num]			[INT])

	CREATE TABLE [#FinalResult](
		[AccGUID]		[UNIQUEIDENTIFIER],
		[AccName]		NVARCHAR(256)  COLLATE ARABIC_CI_AI,
		[AccLatinName]	NVARCHAR(256)  COLLATE ARABIC_CI_AI,  
 		[AccCode]		NVARCHAR(256)  COLLATE ARABIC_CI_AI,
 		[Bal]			[FLOAT],
 		[CurrCode]		NVARCHAR(256)  COLLATE ARABIC_CI_AI,
 		[CostGUID]		[UNIQUEIDENTIFIER],
 		[Num]			[INT])
 		
	INSERT INTO [#AccTbL]
	SELECT 
		ISNULL([acGUID], 0x0),
		ISNULL([acSecurity], 0),
		ISNULL([acName], ''), 
		ISNULL(CASE [acLatinName] WHEN '' THEN [acName] ELSE [acLatinName] END, ''),
		ISNULL([acCode], ''),
		ISNULL([acNSons], 0),
		[ac].[acCurrencyPtr],
		ISNULL([acType], 1),
		ISNULL ([fa].[CostGUID], 0x0),
		[fa].[Num]
	FROM
		[vwAc] AS [ac]
		RIGHT JOIN [FavAcc000] AS [fa] ON [ac].[acGUID] = [fa].[AccGUID]
	WHERE 
		[fa].[UserGUID] = @UserGUID 
		AND (([fa].[AccGUID] = '00000000-0000-0000-0000-000000000000') OR [ac].[acGUID] IS NOT NULL)

	SELECT @CurrGUID = [GUID] from [my000] WHERE [CurrencyVal] = 1
	UPDATE [#AccTbL] SET [CurrGUID] = @CurrGUID WHERE [AccType] = 4 OR [AccGUID] = 0x0
	
	INSERT INTO [#AccTbL2] 
	SELECT 
		[accGUID],
		[accGUID],
		[CurrGUID],
		0x0,
		[CostGUID] 
	FROM
		[#AccTbL]
	WHERE 
		[AccGUID] = 0x0 
		AND [CostGUID] IS NOT NULL
	
	SET @c = CURSOR FAST_FORWARD FOR 
	SELECT 
		[accGUID],
		[CurrGUID],
		[CostGUID] 
	FROM 
		[#AccTbL]
		
	OPEN @c
	FETCH @c INTO @GUID, @CurrGUID, @CostGUID
	WHILE @@FETCH_STATUS = 0 
	BEGIN
		INSERT INTO [#AccTbL2]
		SELECT 
			[GUID],
			@GUID,
			@CurrGUID,
			0x0,
			@CostGUID 
		FROM
			[fnGetAcDescList](@GUID)
		FETCH @c INTO @GUID, @CurrGUID, @CostGUID
	END
	
	CLOSE @c
	
	DELETE acc2
	FROM 
		[#AccTbL2] acc2 
		LEFT JOIN  [vwCo] co ON co.coGUID = acc2.[CostParentGUID]
	WHERE  
		acc2.[CostParentGUID] <> 0x0 
		AND co.coGUID IS NULL
		
	SET @c = CURSOR FAST_FORWARD FOR
				SELECT DISTINCT [CostParentGUID] FROM [#AccTbL2] WHERE  [CostParentGUID] <> 0x0
	OPEN @c
	FETCH @c INTO @GUID
	WHILE @@FETCH_STATUS = 0 
	BEGIN
		INSERT INTO [#AccTbL2]
		SELECT 
			[AccGUID],
			[AccpParentGUID],
			[CurrGUID],
			fn.GUID,
			[CostParentGUID] 
		FROM 
			[#AccTbL2] acc2,
			dbo.fnGetCostsList(@GUID) fn
		WHERE 
			[CostParentGUID] = @GUID
			
		DELETE [#AccTbL2] WHERE [CostParentGUID] = @GUID AND [CostGUID] = 0x0
		FETCH @c INTO @GUID
	END
	
	CLOSE @c
	DEALLOCATE @c

	INSERT INTO [#EnBal]
	SELECT 
		[AccpParentGUID],
		[CostParentGUID],
		SUM( 
			ISNULL([dbo].[fnCurrency_Fix](
						[en].[enDebit], 
						[en].[enCurrencyptr], 
						[en].[enCurrencyVal], 
						[ac].[CurrGUID], 
						[en].[enDate]) 
					- [dbo].[fnCurrency_Fix](
						[en].[enCredit],
						[en].[enCurrencyptr], 
						[en].[enCurrencyVal], 
						[ac].[CurrGUID], 
						[en].[enDate])
			, 0)
		),
		[en].[ceSecurity],
		[en].[ceTypeGUID],
		[CostParentGUID] 
	FROM 
		[#AccTbL2] AS [ac] 
		INNER JOIN [vwCeEn] AS [en] ON [en].[enAccount] = [AccGUID]
	WHERE 
		(([CostGUID] = [enCostPoint]) OR ([CostGUID] = 0x0))
		AND (((@IncludeUnPosted = 0) AND ([en].[ceIsPosted] = 1)) OR (@IncludeUnPosted = 1))
		AND (((@BananceToDay = 1) AND ([en].[ceDate] <= GetDate())) OR (@BananceToDay = 0))
	GROUP BY 
		[AccpParentGUID],
		[en].[ceSecurity],
		[en].[ceTypeGUID],
		[CostParentGUID]

	INSERT INTO [#EnBal]
	SELECT 
		[AccpParentGUID],
		[CostParentGUID],
		SUM( 
			ISNULL([dbo].[fnCurrency_Fix](
						[en].[enDebit], 
						[en].[enCurrencyptr], 
						[en].[enCurrencyVal], 
						@CurrGUID, 
						[en].[enDate]) 
					- [dbo].[fnCurrency_Fix](
						[en].[enCredit],
						[en].[enCurrencyptr], 
						[en].[enCurrencyVal], 
						@CurrGUID, 
						[en].[enDate])
			, 0)
		), 
		[en].[ceSecurity],
		[en].[ceTypeGUID],
		[CostParentGUID] 
	FROM 
		([#AccTbL2] AS [ac] 
		INNER JOIN [vwCeEn] AS [en] ON [en].[encostpoint] = [CostGUID])
		INNER JOIN [vbAc] v ON v.GUID = [en].[enAccount]
	WHERE 
		[AccpParentGUID] = 0x0
		AND [CostParentGUID] <> 0x0
		AND [v].[Security] <= [dbo].[fnGetUserAccountSec_Browse](@UserGUID)
		AND (((@IncludeUnPosted = 0) AND ([en].[ceIsPosted] = 1)) OR (@IncludeUnPosted = 1))
		AND (((@BananceToDay = 1) AND ([en].[ceDate] <= GetDate())) OR (@BananceToDay = 0))
	GROUP BY 
		[AccpParentGUID],
		[en].[ceSecurity],
		[en].[ceTypeGUID],
		[CostParentGUID]
		
	DECLARE @SecBalPrice [INT] 
	SET @SecBalPrice = [dbo].[fnGetUserAccountSec_readBalance]([dbo].[fnGetCurrentUserGUID]())
	
	INSERT INTO [#Result]
	SELECT
		[ac].[AccGUID],
		[ac].[Security],
		[ac].[AccName],
		[ac].[AccLatinName],
		[ac].[AccCode],
		ISNULL([en].[Bal], 0),
		-- WHEN en.ceTypeGUID = 0x0 THEN row is added by Manual Entry.
		-- Security value (-3) is used to protect rows not added by manual entry (ﬁÌœ ÌœÊÌ) from being deleted using Entry Security comparison
		(CASE WHEN en.ceTypeGUID = 0x0 
			THEN [en].[ceSecurity] 
			ELSE -3 
		END) AS ceSecurity, 
		[my].[myCode],
		ISNULL([ac].[CostGUID], 0x0),
		[ac].[Num]
	FROM
		[#AccTbL] AS [ac]
		LEFT JOIN [#EnBal] AS [en] ON [en].[AccGUID] = [ac].[AccGUID] AND [ac].[CostGUID] = ISNULL([en].[Cost], 0x0)
		INNER JOIN [vwmy] AS [my] ON [my].[myGUID] = [ac].[CurrGUID]
	WHERE
		[ac].[Security] <= @SecBalPrice

	IF @SecBalPrice > 0
		UPDATE [#Result] SET [ceSecurity] = 0 WHERE [acSecurity] > @SecBalPrice
	
	EXEC [prcCheckSecurity]

	INSERT INTO [#FinalResult]
	SELECT 	
		[AccGUID],			
		[AccName],		
		[AccLatinName],	
		[AccCode],		
		SUM([Bal]) AS [Bal]	,			
		[CurrCode]	,	
		[CostGUID]	,	
		[Num]	
	FROM [#RESULT] 
	GROUP BY 
		[AccGUID],			
		[AccName],		
		[AccLatinName],	
		[AccCode],	
		[CurrCode]	,	
		[CostGUID]	,	
		[Num]

	DECLARE @sql NVARCHAR(1000)
	SET @sql = 
	'SELECT
		[AccGUID],
		[AccName],
		[AccLatinName],
		[AccCode],
		[Bal] AS [Balance],
		[CurrCode], 
		ISNULL([coCode], '''') AS [coCode],
		ISNULL([coName], '''') AS [coName],
		ISNULL(CASE [coLatinName] WHEN '''' THEN [coName] ELSE [coLatinName] END, '''') [coLatinName],
		[CostGUID]
	FROM 
		[#FinalResult] [Res]
		LEFT JOIN [vwCo] AS [co] ON [co].[coGUID] = [CostGUID]
	WHERE 
		ISNULL([coSecurity], 0) <= ' +  CAST(@Perm AS NVARCHAR(100))
	IF @ShCustsOnly = 1
		SET @sql = @sql + ' AND [Res].[AccGUID] IN (SELECT AccountGUID FROM cu000)'
	IF @ShAccsBalMore = 1
		SET @sql = @sql + ' AND ABS([Bal]) > ' + CAST( @BalMore AS NVARCHAR(15))
	IF @ShAccsBalLess = 1
		SET @sql = @sql + ' AND ABS([Bal]) < ' + CAST( @BalLess AS NVARCHAR(15))
	IF @ShBalanced = 0
		SET @sql = @sql + 'AND ABS([Bal]) <> 0'
	IF @Sort = 0
		SET @sql = @sql + 'ORDER BY [Num]'
	IF @Sort = 1
		SET @sql = @sql + 'ORDER BY AccCode'
	IF @Sort = 2
		SET @sql = @sql + 'ORDER BY AccName'
	IF @Sort = 3
		SET @sql = @sql + 'ORDER BY Balance'
	IF @Sort <> 0
	BEGIN
	IF @SortType = 1
		SET @sql = @sql + ' DESC'
	END
	EXEC (@sql)
/*
prcConnections_add2 '„œÌ—'
[repGetFavoriteAccounts] 'b5368dc5-81e7-4c13-9fae-027372da7871', 2, 1, 1, 0, 0, 0, 1, 0
select * from favAcc000
*/
#########################################################################
#END