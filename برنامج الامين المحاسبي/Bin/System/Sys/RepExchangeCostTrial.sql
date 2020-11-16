#################################################
CREATE  PROCEDURE RepExchangeCostTrial
	@AccGUID AS [UNIQUEIDENTIFIER], 
	@CostGUID AS [UNIQUEIDENTIFIER], 
	@Class AS [NVARCHAR](256), 
	@StartDate AS [DATETIME], 
	@EndDate AS [DATETIME], 
	@CurGUID AS [UNIQUEIDENTIFIER], 
	@CurVal AS [FLOAT],
	@CostLevel AS [INT] =0,
	@AcLevel AS [INT] =0,
	@coSorted AS [INT] = 0,
	@AcSorted AS [INT] = 1,
	@HrAxe	AS  [INT] = 1,
	@Lang	[INT] = 0
AS 
	DECLARE @Admin [INT]
	SET NOCOUNT ON
	DECLARE @UserGUID [UNIQUEIDENTIFIER], @UserEnSec [INT] 
	DECLARE @c CURSOR;
	DECLARE @G [UNIQUEIDENTIFIER],@L [INT]
	DECLARE @MaxLevel [INT]
		
	Set @UserGUID = [dbo].[fnGetCurrentUserGUID]()  
	Set @UserEnSec = [dbo].[fnGetUserEntrySec_Browse](@UserGUID, DEFAULT)
	CREATE TABLE [#SecViol]( [Type] [INT], [Cnt] [INT])    
	CREATE TABLE [#AccTbl]( [Number] [UNIQUEIDENTIFIER], [Security] [INT], [Lvl] [INT])  
	CREATE TABLE [#CostTbl]( [Number] [UNIQUEIDENTIFIER], [Security] [INT])  
	CREATE TABLE [#Result]
		( 
			[CostPoint]		[UNIQUEIDENTIFIER], 
			[CostSecurity]	[INT], 
			[Account]		[UNIQUEIDENTIFIER], 
			[AccSecurity]	[INT], 
			[Debit]			[FLOAT], 
			[Credit]		[FLOAT], 
			[Security]		[INT],  
			[UserSecurity]	[INT],
			[coParent]		[UNIQUEIDENTIFIER], 
			[coPath]		[NVARCHAR](1000),
			[coLevel]		[INT],
			[acParent]		[UNIQUEIDENTIFIER], 
			[acPath]		[NVARCHAR](1000),
			[acLevel]		[INT],
			[Flag]			[INT] DEFAULT 0,
			[Code]		[NVARCHAR](256) COLLATE ARABIC_CI_AI, 
			[Name]		[NVARCHAR](256) COLLATE ARABIC_CI_AI,
			[Currency] 	[UNIQUEIDENTIFIER]
		) 
	
	INSERT INTO [#AccTbl] EXEC [prcGetAccountsList] @AccGUID 
	INSERT INTO [#CostTbl] EXEC [prcGetCostsList] @CostGUID 
	
	SELECT [f].[GUID] AS [GUID], [Level],[Path],[ParentGuid],[co1].[Security]
	INTO [#CostTbl2] 
	FROM [fnGetCostsListWithLevel](@CostGUID,@coSorted) AS [f] 
	INNER JOIN [co000] AS [co] ON [co].[Guid] = [f].[Guid]
	INNER JOIN [#CostTbl] AS [co1] ON [co].[Guid] = [co1].[Number]
	
	CREATE CLUSTERED INDEX [TRLCOcoInd] ON [#CostTbl2]([GUID])

	SELECT [f].[GUID] AS [GUID], [Level],[Path],[ParentGuid],[ac1].[Security], ac.CurrencyGuid as AcCurrencyGuid
	INTO [#AccTbl2]
	FROM [fnGetAccountsList](@AccGUID,@AcSorted) AS [f] 
	INNER JOIN [ac000] AS [ac] ON [ac].[Guid] = [f].[Guid]
	INNER JOIN [#AccTbl] AS [ac1] ON [ac1].[Number] = [ac].[Guid]
	
	CREATE CLUSTERED INDEX [TRLCOacInd] ON [#AccTbl2]([GUID])


	INSERT INTO [#Result] 
		SELECT  
			[en].[enCostPoint], 
			[co].[Security], 
			[en].[enAccount],   
			[ac].[Security], 
			dbo.fnCurrency_Fix(en.enDebit, en.encurrencyPTR, en.encurrencyval, ac.AcCurrencyGuid, en.endate),
			dbo.fnCurrency_Fix(en.enCredit, en.encurrencyptr, en.encurrencyval, ac.AcCurrencyGuid, en.endate),
			[ce].[ceSecurity], 
			@UserEnSec,
			[co].[ParentGuid],
			[co].[Path],[co].[Level],[ac].[ParentGuid],[ac].[Path],[ac].[Level],0,'','',
			ac.AcCurrencyGuid	
		FROM  	
			vwen as en
			inner join vwce as ce on ce.ceguid = en.enparent
			INNER JOIN [#CostTbl2] AS [co]   on co.guid = en.enCostPoint 
			INNER JOIN [#AccTbl2] AS [ac]   ON [en].[enAccount] = [ac].[GUID]

		WHERE  
		( @Class = '' OR [enClass] = @Class ) AND 
		[EnDate] BETWEEN @StartDate AND @EndDate  
		ORDER BY  
		[EnDate]  
	EXEC [prcCheckSecurity] @UserGuid 
	SET @UserGuid = [dbo].[fnGetCurrentUserGUID]()

	SET @Admin = [dbo].[fnIsAdmin](ISNULL(@userGUID,0x00) )

	IF @Admin = 0
	BEGIN
		DECLARE @CoSecurity [INT]	
		SET @CoSecurity = [dbo].[fnGetUserCostSec_Browse](@UserGuid)
		SET @MaxLevel = 1
		WHILE @MaxLevel > 0
		BEGIN
			UPDATE [co] SET [ParentGuid] = [c].[ParentGuid],[Level] = [co].[Level] -1 FROM [#CostTbl2] AS [co] INNER JOIN [#CostTbl2] AS [c] ON [co].[ParentGuid] = [c].[Guid] WHERE [c].[Security] > @CoSecurity
			SET @MaxLevel = @@RowCount

		END
		UPDATE [r] SET [coParent] = [co].[ParentGuid],[coLevel] = [co].[Level] + 1  FROM [#Result] AS [r]  INNER JOIN [#CostTbl2] AS [co] ON [r].[coParent] = [co].[Guid]
		WHERE [co].[Security] > @CoSecurity 
		DELETE [#CostTbl2] WHERE [Security] > @CoSecurity
		
	END
	SELECT @MaxLevel = MAX([Level]) FROM [#CostTbl2]
	WHILE @MaxLevel >= 0
	BEGIN
		INSERT INTO [#Result]([CostPoint],[Account],[Debit],[Credit],[coParent],[coPath],[coLevel],[acParent],[acPath],[acLevel])
			SELECT [co].[Guid],[Account],SUM([Debit]),SUM([Credit]),[co].[ParentGuid],[co].[Path],[co].[Level],[acParent],[acPath],[acLevel]
			FROM [#Result] AS [r] INNER JOIN [#CostTbl2] AS [co] ON [r].[coParent] = [co].[Guid]
			WHERE [r].[coLevel] =  @MaxLevel
			GROUP BY [co].[Guid],[Account],[co].[ParentGuid],[co].[Path],[co].[Level],[acParent],[acPath],[acLevel]
		SET @MaxLevel = @MaxLevel - 1
	END 
	IF @Admin = 0
	BEGIN
		DECLARE @AccSecurity [INT]	
		SET @AccSecurity = [dbo].[fnGetUserAccountSec_Browse](@UserGuid)
		SET @MaxLevel = 1
		WHILE @MaxLevel > 0
		BEGIN
			UPDATE [ac] SET [ac].[ParentGuid] = [a].[ParentGuid],[Level] = [ac].[Level] -1 FROM [#AccTbl2] AS [ac] INNER JOIN [#AccTbl2] AS [a] ON [ac].[ParentGuid] = [a].[Guid] WHERE [a].[Security] > @AccSecurity
			SET @MaxLevel = @@RowCount

		END
		UPDATE [r] SET [acParent] = [ac].[ParentGuid],[acLevel] = [ac].[Level] + 1  FROM [#Result] AS [r]  INNER JOIN [#AccTbl2] AS [ac] ON [r].[acParent] = [ac].[Guid]
		WHERE [ac].[Security] > @AccSecurity 
		DELETE [#AccTbl2] WHERE [Security] > @AccSecurity
		IF EXISTS(SELECT * FROM [#SecViol] WHERE [Type] = 5)
			INSERT INTO [#SecViol] VALUES(@@RowCount,5)
		
	END
	SELECT @MaxLevel = MAX([Level]) FROM [#AccTbl2]
	WHILE @MaxLevel >= 0
	BEGIN
		INSERT INTO [#Result]([CostPoint],[Account],[Debit],[Credit],[coParent],[coPath],[coLevel],[acParent],[acPath],[acLevel])
			SELECT [CostPoint],[ac].[Guid],SUM([Debit]),SUM([Credit]),[coParent],[coPath],[coLevel],[ac].[ParentGuid],[ac].[Path],[ac].[Level]
			FROM [#Result] AS [r] INNER JOIN [#AccTbl2] AS [ac] ON [r].[acParent] = [ac].[Guid]
			WHERE [r].[acLevel] =  @MaxLevel
			GROUP BY [CostPoint],[ac].[Guid],[coParent],[coPath],[coLevel],[ac].[ParentGuid],[ac].[Path],[ac].[Level]
		SET @MaxLevel = @MaxLevel - 1
	END 
	IF @HrAxe = 1
	BEGIN
		INSERT INTO #RESULT([CostPoint],[coPath],[coLevel],[Code],[Name],[Flag],[acLevel] )
			SELECT  [co2].[GUID],[co2].[Path], [co2].[Level],[co].[Code],CASE @Lang WHEN 0 THEN [co].[Name] ELSE CASE [co].[LAtinName] WHEN '' THEN  [co].[Name] ELSE [co].[LatinName] END  END , -1,0 
			FROM [#CostTbl2] AS [co2] 
			INNER JOIN [co000] AS [co] ON [co2].[Guid] =  [co].[Guid]
			INNER JOIN [#RESULT] as [r] ON [r].[CostPoint] =  [co].[Guid]
			ORDER BY CASE @coSorted WHEN 0 THEN [co].[Code] ELSE [co].[Name] END
		UPDATE [r] SET [Name] = CASE @Lang WHEN 0 THEN [ac].[Name] ELSE CASE [ac].[LatinName] WHEN '' THEN  [ac].[Name] ELSE [ac].[LatinName] END  END ,[Code] = [ac].[Code] FROM [#Result] AS [r] INNER JOIN [ac000] AS [ac] ON [ac].[Guid] = [r].[Account]
	END
	ELSE
	BEGIN
		INSERT INTO #RESULT([Account],[acPath],[acLevel],[Code],[Name],[Flag],[coLevel] )
			SELECT  [ac2].[GUID],[ac2].[Path], [ac2].[Level],[ac].[Code],CASE @Lang WHEN 0 THEN [ac].[Name] ELSE CASE [ac].[LatinName] WHEN '' THEN  [ac].[Name] ELSE [ac].[LatinName] END  END  , -1,0 
			FROM [#AccTbl2] AS [ac2] 
			INNER JOIN [ac000] AS [ac] ON [ac2].[Guid] =  [ac].[Guid]
			INNER JOIN [#RESULT] as [r] ON [r].[Account] =  [ac].[Guid]
			ORDER BY CASE @acSorted WHEN 0 THEN [AC].[Code] ELSE [AC].[Name] END
		UPDATE [r] SET [Name] = CASE @Lang WHEN 0 THEN [co].[Name] ELSE CASE [co].[LAtinName] WHEN '' THEN  [co].[Name] ELSE [co].[LatinName] END  END,[Code] = [co].[Code] FROM [#Result] AS [r] INNER JOIN [co000] AS [co] ON [co].[Guid] = [r].[CostPoint]
		
	END
	
	SELECT 
		[r].[CostPoint], 
		[r].[Account],
		SUM([Debit]) AS [Debit],
		SUM([Credit]) AS [Credit],
		[coLevel],
		[acLevel],
		[Code],
		[Name],
		[Flag],
		[Currency],
		CASE @HrAxe WHEN 1 THEN [acPath] ELSE  [coPath] END AS Path
	FROM [#Result] AS [r] 

	WHERE ([acLevel] < @AcLevel OR @AcLevel = 0) AND (@CostLevel =0  OR [coLevel] < @CostLevel )
	GROUP BY [r].[CostPoint], [r].[Account], [coLevel], [acLevel],[coPath], [acPath],[Code],[Name],[Flag],Currency
	ORDER BY [Flag]
	,CASE @HrAxe WHEN 1 THEN [coPath] ELSE [acPath] END, CASE @HrAxe WHEN 1 THEN [acPath] ELSE [coPath] END    
	, CASE @HrAxe WHEN 1 THEN  CASE @acSorted WHEN 0 THEN [Code] ELSE [Name] END  ELSE CASE @coSorted WHEN 0 THEN [Code] ELSE [Name] END END   
	SELECT * FROM [#SecViol] 
/*
	PRCcONNECTIONS_ADD2 'ãÏíÑ'
	EXEC [RepCostTrial] 'eb18e0fe-c7d8-44a1-8c48-e66134a9b630', '00000000-0000-0000-0000-000000000000', '', '5/1/2006  0:0:0:0', '7/23/2007  0:0:0:0', '374cdc4d-d5c2-413b-9436-a905996c06ad', 1.000000, 1, 3, 1, 1, 1, 0
*/

#################################
#END