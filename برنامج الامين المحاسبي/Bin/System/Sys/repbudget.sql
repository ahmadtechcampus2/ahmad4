################################################################################
## ÌÕ÷— »Ì«‰«  ·ﬂ‘› «·„Ê«“‰…
CREATE PROCEDURE repBudget   
	@AccPtr AS [UNIQUEIDENTIFIER],-- —ﬁ„ «·Õ”«»   
	@Warn AS [VARCHAR](10), --‰Ê⁄ «· Õ–Ì— 0: »œÊ‰ 1: „œÌ‰ 2: œ«∆‰  
	@CheckAll AS [INT],-- ‰Ê⁄ «·Õ”«»«   
	-- 0 Ã„Ì⁄ «·Õ”«»«    
	-- 1 «·Õ”«»«  «· Ì ·Â« „Ê«“‰…  
	-- 2 «·Õ”«»«  «· Ì  Ã«Ê“  «·„Ê«“‰…
	@CurGUID AS [UNIQUEIDENTIFIER], --«·⁄„·…  
	@CurVal AS [INT], --«· ⁄«œ·  
	@StartDate AS [DATETIME], -- «—ÌŒ «·»œ¡   
	@EndDate AS [DATETIME], -- «—ÌŒ «·‰Â«Ì…  
	@Without BIT = 0, 
	@abbrv BIT =0 
AS   
	SET NOCOUNT ON 
	DECLARE @UserGUID [UNIQUEIDENTIFIER], @UserEnSec [INT]   
	Set @UserGUID = [dbo].[fnGetCurrentUserGUID]()   
	Set @UserEnSec = [dbo].[fnGetUserEntrySec_Browse]( @UserGUID, DEFAULT) 
	--Set @UserAccSec = dbo.fnGetUserAccountSec_Browse( @UserGUID) 
	CREATE TABLE [#AccTbl]( [AccGuid] [UNIQUEIDENTIFIER], [Security] [INT], [Lvl] [INT])     
	CREATE TABLE [#SecViol]( [Type] [INT], [Cnt] [INT])     
	CREATE TABLE [#Warn]( [Type] [INT])     
	CREATE TABLE #ACC2 (Guid [UNIQUEIDENTIFIER], Code NVARCHAR(250), Name NVARCHAR(250), LatinName NVARCHAR(250),
		Warn FLOAT, CurrencyGuid [UNIQUEIDENTIFIER], CurrencyVal FLOAT, MaxDebit FLOAT, Debit FLOAT, Credit FLOAT, [Security] INT) 
	 
	CREATE TABLE
		[#Result](
					[Debit]			[FLOAT],
					[Credit]		[FLOAT],
					[MaxDebit]		[FLOAT],
					[MaxDebitWarned][FLOAT],
					[Account]		[UNIQUEIDENTIFIER],
					[AccSecurity]	[TINYINT],
					[EntryDate]		[DATETIME],
					[Security]		[INT],
					[UserSecurity]	[INT]   
				)

	CREATE TABLE     
		[#PeriodicResult](
					[Period]			[INT],
					[Debit]				[FLOAT],
					[Credit]			[FLOAT],
					[MovementBalance]	[FLOAT],
					[Balance]			[FLOAT],
					[Percent]			[FLOAT],
					[Reminder]			[FLOAT],
					[MaxDebit]			[FLOAT],
					[MaxDebitWarned]	[FLOAT],
					[Account]			[UNIQUEIDENTIFIER],
					[Code]				[NVARCHAR](250),
					[Name]				[NVARCHAR](250),
					[LatinName]			[NVARCHAR](250),
					[Warn]				[FLOAT],
					[CurrencyGuid]		[UNIQUEIDENTIFIER],
					[CurrencyVal]		[FLOAT],
				)

	CREATE TABLE [#Periods] ([Period] [INT], [SubPeriodCounter] [INT], [SubPeriodRun] [INT], [StartDate] [DATETIME], [EndDate] [DATETIME])  
	IF (@abbrv = 1)  
		INSERT INTO  [#Periods] VALUES (1, 1, 1, @StartDate, @EndDate)
	ELSE  
		INSERT INTO  [#Periods] SELECT * FROM fnGetPeriod(3, @StartDate, @EndDate)  

	INSERT INTO [#AccTbl] EXEC [prcGetAccountsList] @AccPtr 

	INSERT INTO #ACC2 
	SELECT  ac.Guid,
		ac.Code,
		ac.Name,
		ac.LatinName,
		ac.Warn,
		ac.CurrencyGuid,
		ac.CurrencyVal,
		ac.MaxDebit,
		ac.Debit,
		ac.Credit,
		[act].[Security] 
	FROM ac000 ac INNER JOIN [#AccTbl]  AS [act] ON ac.Guid = [act].[AccGUID]  
	WHERE  [Type] = 1 AND NSons <= 0 

	INSERT INTO [#Warn] SELECT CAST( [Data] AS [INT]) FROM [dbo].[fnTextToRows]( @Warn) 

	IF @CheckAll = 1 OR @CheckAll = 2
		INSERT INTO [#Result]
		SELECT
			COALESCE(SUM([Ce].[FixedEnDebit]), 0),
			COALESCE(SUM([Ce].[FixedEnCredit]), 0),
			CASE [act].[Warn] WHEN 0 THEN 0 ELSE [act].[MaxDebit] END,
			CASE [act].[Warn] WHEN 0 THEN 0
							WHEN 1 THEN [act].[MaxDebit]
							WHEN 2 THEN -[act].[MaxDebit]
							ELSE NULL END,
			[act].[GUID],
			[act].[Security],
			CASE @abbrv WHEN 0 THEN [Ce].[enDate] ELSE @EndDate end,
			COALESCE([Ce].[ceSecurity], 0),
			@UserEnSec
		FROM
			[dbo].fnCeEn_Fixed(@CurGUID) AS [Ce]
			RIGHT JOIN [#ACC2] AS [act] ON [ce].[enAccount] = [act].[GUID]
			INNER JOIN [#Warn] AS [w] ON [act].[Warn] = [w].[Type]
		WHERE
			(@CheckAll = 1 AND [act].[Warn] <> 0) OR
			(@CheckAll = 2 AND (
				([act].[Warn] = 1 AND ([act].[Debit] - [act].[Credit]) > [act].[MaxDebit] AND ([act].[Debit] - [act].[Credit]) > 0) OR
				([act].[Warn] = 2 AND ([act].[Debit] - [act].[Credit]) < -[act].[MaxDebit] AND ([act].[Debit] - [act].[Credit]) < 0)
								)
			)
		GROUP BY
			CASE [act].[Warn] WHEN 0 THEN 0 ELSE [act].[MaxDebit] END,
			CASE [act].[Warn] WHEN 0 THEN 0
							WHEN 1 THEN [act].[MaxDebit]
							WHEN 2 THEN -[act].[MaxDebit]
							ELSE NULL END,
			[act].[GUID],
			[act].[Security],
			CASE @abbrv WHEN 0 THEN [Ce].[enDate] ELSE @EndDate end,
			[Ce].[ceSecurity]
	ELSE
		INSERT INTO [#Result]
		SELECT
			SUM([Ce].[FixedEnDebit]),
			SUM([Ce].[FixedEnCredit]),
			CASE [act].[Warn] WHEN 0 THEN 0 ELSE [act].[MaxDebit] END,
			CASE [act].[Warn] WHEN 0 THEN 0
							WHEN 1 THEN [act].[MaxDebit]
							WHEN 2 THEN -[act].[MaxDebit]
							ELSE NULL END,
			[Ce].[enAccount],
			[act].[Security],
			CASE @abbrv WHEN 0 THEN [Ce].[enDate] ELSE @EndDate end,
			[Ce].[ceSecurity],
			@UserEnSec
		FROM
			[dbo].fnCeEn_Fixed(@CurGUID) As [Ce]
			INNER JOIN [#ACC2]  AS [act] ON [ce].[enAccount] = [act].[GUID]
			INNER JOIN [#Warn] AS [w] ON [act].[Warn] = [w].[Type]
		WHERE
			[enDate] BETWEEN @StartDate AND @EndDate
		GROUP BY
			CASE [act].[Warn] WHEN 0 THEN 0 ELSE [act].[MaxDebit] END,
			CASE [act].[Warn] WHEN 0 THEN 0
							WHEN 1 THEN [act].[MaxDebit]
							WHEN 2 THEN -[act].[MaxDebit]
							ELSE NULL END,
			[Ce].[enAccount],
			[act].[Security],
			CASE @abbrv WHEN 0 THEN [Ce].[enDate] ELSE @EndDate end,
			[Ce].[ceSecurity]

	EXEC [prcCheckSecurity] @UserGUID 

	IF (@abbrv = 1)
		SELECT
		sum([res].[Debit]) AS [Debit],
		sum([res].[Credit]) AS [Credit],
		sum([res].[Debit]) - sum([res].[Credit]) AS [Balance],
		CASE [ac].Warn WHEN 0 THEN 0
						ELSE [res].[MaxDebitWarned] - (sum([res].[Debit]) - sum([res].[Credit]))
						END AS [Reminder],
		[res].[Account],
		[ac].Code,
		[ac].Name,
		[ac].LatinName,
		[ac].Warn,
		[ac].CurrencyGuid,
		[ac].CurrencyVal,
		[res].MaxDebit
		FROM [#Result] AS [res]
		INNER JOIN [#ACC2] AS [ac] ON [ac].[GUID] = [res].[Account]
		group by 
		[MaxDebitWarned],
		[res].[Account],
		[ac].Code,
		[ac].Name,
		[ac].LatinName,
		[ac].Warn,
		[ac].CurrencyGuid,
		[ac].CurrencyVal,
		[res].MaxDebit
	ELSE
	BEGIN
		INSERT INTO [#PeriodicResult]
		SELECT
		[per].[Period],
		SUM([res].[Debit]),
		SUM([res].[Credit]),
		SUM([res].[Debit]) - SUM([res].[Credit]),
		0,-- [Balance]: to be calculated later
		0,-- [Percent]: to be calculated later
		0,-- [Reminder]: to be calculated later
		[res].[MaxDebit],
		CASE [ac].[Warn] WHEN 0 THEN 0
							WHEN 1 THEN [res].[MaxDebit]
							WHEN 2 THEN -[res].[MaxDebit]
							ELSE NULL END,
		[res].[Account],
		[ac].[Code],
		[ac].[Name],
		[ac].[LatinName],
		[ac].[Warn],
		[ac].[CurrencyGuid],
		[ac].[CurrencyVal]
		FROM [#Periods] AS[per]
		INNER JOIN [#Result] AS [res] ON ([EntryDate] between [StartDate] and [EndDate] OR EntryDate IS NULL)
		INNER JOIN [#ACC2] AS [ac] ON [ac].[GUID] = [res].[Account]
		GROUP BY
		[per].[Period],
		[per].[StartDate],
		[per].[EndDate],
		[res].[Account],
		[ac].Code,
		[ac].Name,
		[ac].LatinName,
		[ac].Warn,
		[ac].CurrencyGuid,
		[ac].CurrencyVal,
		[res].MaxDebit

		SELECT
		DISTINCT
		[MaxDebit],
		[MaxDebitWarned],
		[Account],
		[Code],
		[Name],
		[LatinName],
		[Warn],
		[CurrencyGuid],
		[CurrencyVal]
		INTO [#PeriodicResultDistinctAccounts]
		FROM [#PeriodicResult]
		
		DECLARE @P INT = 1, @LastPeriod INT
		SELECT @LastPeriod = MAX([Period]) FROM [#Periods]
		WHILE @P <= @LastPeriod
		BEGIN
			INSERT INTO [#PeriodicResult]
			SELECT
			@p,
			0,
			0,
			0,
			0,
			0,
			0,
			[MaxDebit],
			[MaxDebitWarned],
			[Account],
			[Code],
			[Name],
			[LatinName],
			[Warn],
			[CurrencyGuid],
			[CurrencyVal]
			FROM [#PeriodicResultDistinctAccounts]
			WHERE [Account] NOT IN (SELECT [Account] FROM [#PeriodicResult] WHERE [Period] = @p)

			SET @p = @p + 1
		END

		-- calc Percent and Reminder for first period
		UPDATE [res]
		SET
		[Percent] = CASE [MaxDebitWarned] WHEN 0 THEN 1 ELSE [MovementBalance] / [MaxDebitWarned] END,
		[Reminder] = [MaxDebitWarned] - [MovementBalance]
		FROM [#PeriodicResult] AS [res]
		WHERE [Period] = 1 AND [MaxDebit] != 0

		DECLARE @CurrentPeriod INT = 1, @MaxPeriod INT
		SELECT @MaxPeriod = MAX([Period]) FROM [#PeriodicResult]
		WHILE @CurrentPeriod < @MaxPeriod
		BEGIN
		-- calc Percent and Reminder period by period
		UPDATE [res]
		SET
		[Percent] = CASE [MaxDebitWarned] WHEN 0 THEN [res2].[Percent] ELSE ([MaxDebitWarned] - [res2].[Reminder] + [MovementBalance]) / [MaxDebitWarned] END,
		[Reminder] = [res2].[Reminder] - [MovementBalance]
		FROM [#PeriodicResult] AS [res]
		INNER JOIN
		(
			SELECT [Account], [Percent], [Reminder] FROM [#PeriodicResult]
			WHERE [Period] = @CurrentPeriod AND [MaxDebit] != 0
		) AS [res2]	ON [res2].[Account] = [res].[Account]
		WHERE [res].[Period] = @CurrentPeriod + 1
		-- calc Balance period by period
		UPDATE [res]
		SET
		[Balance] = [Balance] + [res2].[MovementBalance]
		FROM [#PeriodicResult] AS [res]
		INNER JOIN
		(
			SELECT [Account], [MovementBalance] FROM [#PeriodicResult]
			WHERE [Period] = @CurrentPeriod
		) AS [res2]	ON [res2].[Account] = [res].[Account]
		WHERE [res].[Period] = @CurrentPeriod + 1

		SET @CurrentPeriod = @CurrentPeriod + 1

		END

		SELECT * FROM [#PeriodicResult]
		ORDER BY [Period]

	END
	
	SELECT * FROM [#SecViol]  
	   
	
	/*
	prcConnections_add2 '„œÌ—'
	 [repBudget] '00000000-0000-0000-0000-000000000000', '1,2 ,0 ', 1, '4d5ef24b-7b12-41c0-abcf-e701fb5dfd40', 1.000000, '1/1/2010 0:0:0.0', '3/7/2010 23:59:26.287', 0
	*/ 
################################################################################
#End