#################################################################
CREATE PROCEDURE repCurBal
	@AccGUID 			[UNIQUEIDENTIFIER],
	@StartDate 			[DATETIME],
	@EndDate 			[DATETIME],
	@PrevStartDate 		[DATETIME],
	@PrevEndDate 		[DATETIME],
	@SortType			[INT],
	@IsPosted			[INT] = -1,
	@CurrPtr			[UNIQUEIDENTIFIER] =0X0,
	@ShowMainAcc		[INT] = 0,
	@ShowSubAcc			[INT] = 1,
	@ShowEmptyAcc		[INT] = 0,
	@EqCurr				[INT] = 0,
	@ShowBalancedAcc	[BIT] = 0,
	@AccCurr			[BIT] = 0,
	@CostGUID			[UNIQUEIDENTIFIER] = 0x00
AS 
	SET NOCOUNT ON
	DECLARE @Admin [INT],@UserGuid [UNIQUEIDENTIFIER]
	DECLARE @Level AS [INT] 
	DECLARE @SecBalPrice [INT] 
	DECLARE @ZeroValue [FLOAT]
	SET @ZeroValue = [dbo].[fnGetZeroValuePrice]()
	SET @SecBalPrice = [dbo].[fnGetUserAccountSec_readBalance]([dbo].[fnGetCurrentUserGuid]())
	CREATE TABLE [#SecViol]( [Type] [INT], [Cnt] [INTEGER])
	CREATE TABLE [#CostTbl]		( [Cost] [UNIQUEIDENTIFIER], [CostSec] [INT])
	INSERT INTO [#CostTbl] EXEC [prcGetCostsList] @CostGUID
	IF @CostGUID = 0X00
		INSERT INTO [#CostTbl] VALUES(0X00,0)
	CREATE TABLE [#ACC1] ([GUID] [UNIQUEIDENTIFIER], [Level] [INT], [Path] [VARCHAR](8000) COLLATE ARABIC_CI_AI,
	[acCode] NVARCHAR(250), [acName] NVARCHAR(250), [acLatinName] NVARCHAR(250), [acParent] [UNIQUEIDENTIFIER], [acSecurity] INT, [CurrencyGUID] [UNIQUEIDENTIFIER])
	CREATE TABLE [#S_Result] ([accPtr] [UNIQUEIDENTIFIER], [SUMDebit] FLOAT, [SUMCredit] FLOAT)
	CREATE TABLE [#Result]
	(
		[enAccount]			[UNIQUEIDENTIFIER],
		[FixedEnDebit]		[FLOAT],
		[FixedEnCredit]		[FLOAT],
		[enCurrencyPtr]		[UNIQUEIDENTIFIER],
		[enCurrencyVal]		[FLOAT],

		[enDate]			[DATETIME],
		[ceNumber]			[INT],
		[ceSecurity]		[INT],
		[AcSecurity]		[INT],
		[Empty]				[BIT],
		[AccCurRate]		[FLOAT]
	)
	INSERT INTO [#Result]
	(
		[enAccount],
		[FixedEnDebit],
		[FixedEnCredit],
		[enCurrencyPtr],
		[enCurrencyVal],
		[enDate],
		[ceNumber],
		[ceSecurity],
		[AcSecurity],
		[Empty],
		[AccCurRate]
	)
	SELECT
		[enAccount],
		[EnDebit],
		[EnCredit],
		CASE @EqCurr WHEN 0 THEN  [enCurrencyPtr] ELSE @CurrPtr END,
		CASE @EqCurr WHEN 0 THEN [enCurrencyVal] ELSE 1/[dbo].[fnCurrency_fix](1, [enCurrencyPtr], [enCurrencyVal], @CurrPtr, [enDate]) END,
		[enDate],
		[ceNumber],
		CASE WHEN @SecBalPrice > [ac].[Security] THEN 0 ELSE  [ceSecurity] END ,
		[ac].[Security],0,[dbo].[fnCurrency_fix](1, [enCurrencyPtr], [enCurrencyVal], [ac].[CurrencyGUID], [enDate])
		
	FROM
		([vwCeEn] AS [en] INNER JOIN [ac000] AS [ac] ON [en].[enAccount] = [ac].[GUID])
		INNER JOIN [dbo].[fnGetAcDescList]( @AccGUID) AS [a] ON [en].[enAccount] = [a].[GUID]
		INNER JOIN [#CostTbl] [co] ON [enCostPoint] = [Cost]
	WHERE
		([enDate] BETWEEN @StartDate AND @EndDate OR [enDate] BETWEEN @PrevStartDate AND @PrevEndDate)
		AND (@IsPosted = -1 OR [ceIsPosted] = @IsPosted)
	IF @ShowEmptyAcc = 1
	BEGIN
		INSERT INTO [#Result]
		(
			[enAccount],
			[FixedEnDebit],
			[FixedEnCredit],
			[enCurrencyPtr],
			[enCurrencyVal],
			[enDate],
			[ceNumber],
			[ceSecurity],
			[AcSecurity],
			[Empty],[AccCurRate]
		)
		SELECT
			[ac].[GUID],
			0,
			0,
			@CurrPtr,
			1,
			@StartDate,
			0,
			0,
			[ac].[Security],1,1
		FROM
			[ac000] AS [ac] 
			INNER JOIN [dbo].[fnGetAcDescList]( @AccGUID) AS [a] ON [ac].[GUID] = [a].[GUID]
		WHERE [ac].[GUID] NOT IN (SELECT [en].[enAccount] FROM [vwCeEn] AS [en] WHERE 
								([enDate] BETWEEN @StartDate AND @EndDate OR [enDate] BETWEEN @PrevStartDate AND @PrevEndDate)
								AND (@IsPosted = -1 OR [ceIsPosted] = @IsPosted)) 
								AND [ac].[NSons] = 0
								AND ([ac].[CurrencyGuid] = @CurrPtr OR @CurrPtr = 0x0)
	END
	EXEC [prcCheckSecurity]
--	SELECT *FROM #Result
	IF (@ShowBalancedAcc = 0)
		DELETE [r] FROM [#Result] AS [r]  INNER JOIN (SELECT [enAccount],[enCurrencyPtr] FROM [#Result] WHERE [Empty] = 0 GROUP BY [enAccount],[enCurrencyPtr]  HAVING ABS(SUM([FixedEnDebit]) - SUM([FixedEnCredit])) < @ZeroValue ) AS [r2] ON [r].[enAccount] = [r2].[enAccount] AND [r].[enCurrencyPtr]  = [r2].[enCurrencyPtr] 
		
	CREATE TABLE [#t_Result]
	(	
		[Number]					[UNIQUEIDENTIFIER],
		[acName]					[NVARCHAR](256) COLLATE ARABIC_CI_AI,
		[acLatinName]				[NVARCHAR](256) COLLATE ARABIC_CI_AI,
		[acCode]					[NVARCHAR](256) COLLATE ARABIC_CI_AI,
		[myName]					[NVARCHAR](256) COLLATE ARABIC_CI_AI,
		[enCurrencyPtr]				[UNIQUEIDENTIFIER],
		[acSecurity]				[INT],
		[TotalDebit]				[FLOAT],
		[TotalCredit]				[FLOAT],
		[TotalBal]					[FLOAT],
		[enCurrTotalDebit]			[FLOAT],
		[enCurrTotalCredit]			[FLOAT],
		[enCurrTotalBal]			[FLOAT],
		[PrevTotalDebit]			[FLOAT],
		[PrevTotalCredit]			[FLOAT],
		[PrevTotalBal]				[FLOAT],
		[PrevEnCurrTotalDebit]		[FLOAT],
		[PrevEnCurrTotalCredit]		[FLOAT],
		[PrevEnCurrTotalBal]		[FLOAT],
		[MainAcc]					[INT],
		[acParent]					[UNIQUEIDENTIFIER],
		[CurrAccGuid]				[UNIQUEIDENTIFIER],
		[enCurrAccTotalDebit]			[FLOAT],
		[enCurrAccTotalCredit]			[FLOAT],
		[PrevenCurrAccTotalDebit]		[FLOAT],
		[PrevenCurrAccTotalCredit]		[FLOAT],
		[acLevel]							[INT]
	)
	
	CREATE TABLE [#t_Bal]
	(
		[Number]			[UNIQUEIDENTIFIER],
		[enCurrencyPtr]		[UNIQUEIDENTIFIER],
		
	
		[TotalDebit]		[FLOAT],
		[TotalCredit]		[FLOAT],
		[TotalBal]			[FLOAT],
	
		[enCurrTotalDebit]	[FLOAT],
		[enCurrTotalCredit]	[FLOAT],
		[enCurrTotalBal]	[FLOAT],
		[enCurrAccTotalDebit]			[FLOAT],
		[enCurrAccTotalCredit]			[FLOAT]
		
	)
	
	CREATE TABLE [#t_PrevBal]
	(
		[Number]			[UNIQUEIDENTIFIER],
		[enCurrencyPtr]		[UNIQUEIDENTIFIER],
		[TotalDebit]		[FLOAT],
		[TotalCredit]		[FLOAT],
		[TotalBal]			[FLOAT],
		[enCurrTotalDebit]	[FLOAT],
		[enCurrTotalCredit]	[FLOAT],
		[enCurrTotalBal]	[FLOAT],
		[PrevenCurrAccTotalDebit]		[FLOAT],
		[PrevenCurrAccTotalCredit]		[FLOAT]
	)
	--- calc Prev Bal
	INSERT INTO [#t_PrevBal]
		SELECT
			[en].[enAccount] AS [Number],
			
			[en].[enCurrencyPtr],
	
	
			SUM( [en].[FixedEnDebit])	AS [TotalDebit],
			SUM( [en].[FixedEnCredit])	AS [TotalCredit],
			SUM( [en].[FixedEnDebit] - [en].[FixedEnCredit]) AS [TotalBal],
			
			SUM( [en].[FixedEnDebit] / (CASE [en].[enCurrencyVal] WHEN 0 THEN 1 ELSE [en].[enCurrencyVal] END)) ,
			SUM( [en].[FixedEnCredit] / (CASE [en].[enCurrencyVal] WHEN 0 THEN 1 ELSE [en].[enCurrencyVal] END)) ,
			SUM( [en].[FixedEnDebit] / (CASE [en].[enCurrencyVal] WHEN 0 THEN 1 ELSE [en].[enCurrencyVal] END) - [en].[FixedEnCredit] / (CASE [en].[enCurrencyVal] WHEN 0 THEN 1 ELSE [en].[enCurrencyVal] END)),
			SUM( [en].[FixedEnDebit]*[AccCurRate]),SUM( [en].[FixedEnCredit]*[AccCurRate])
		FROM
			[#Result] AS [en]
			
		WHERE
			([en].[enDate] BETWEEN @PrevStartDate AND @PrevEndDate)
			AND ((@CurrPtr =0X0) OR  [en].[enCurrencyPtr] = @CurrPtr)
		GROUP BY
			[en].[enAccount],
			
			[en].[enCurrencyPtr]
	
	---- calc bal
	INSERT INTO [#t_Bal]
		SELECT
			[en].[enAccount]		AS [Number],
			[en].[enCurrencyPtr],
			SUM( [en].[FixedEnDebit])	AS [TotalDebit],
			SUM( [en].[FixedEnCredit])	AS [TotalCredit],
			SUM( [en].[FixedEnDebit] - [en].[FixedEnCredit]) AS [TotalBal],
			
			SUM( [en].[FixedEnDebit] / (CASE [en].[enCurrencyVal] WHEN 0 THEN 1 ELSE [en].[enCurrencyVal] END)) AS [enCurrTotalDebit],
			SUM( [en].[FixedEnCredit] / (CASE [en].[enCurrencyVal] WHEN 0 THEN 1 ELSE [en].[enCurrencyVal] END)) AS [enCurrTotalCredit],
			SUM( [en].[FixedEnDebit] / (CASE [en].[enCurrencyVal] WHEN 0 THEN 1 ELSE [en].[enCurrencyVal] END) - [en].[FixedEnCredit] / (CASE [en].[enCurrencyVal] WHEN 0 THEN 1 ELSE [en].[enCurrencyVal] END)) AS [enCurrTotalBal],
			SUM( [en].[FixedEnDebit]*[AccCurRate]),SUM( [en].[FixedEnCredit]*[AccCurRate])
		FROM
			[#Result] AS [en]
			
		WHERE
			([en].[enDate] BETWEEN @StartDate AND @EndDate)
			AND ((@CurrPtr =0X0) OR  [en].[enCurrencyPtr] = @CurrPtr)
		GROUP BY
			[en].[enAccount],
			
			[en].[enCurrencyPtr]
	
	
	INSERT INTO [#t_Result]
	SELECT
		ISNULL( [rs1].[Number], [rs2].[Number]) AS [Number],
		[ac].[Name] AS [acName],
		[ac].[LatinName] AS [acLatinName],
		[ac].[Code] AS [acCode],
		[my].[myCode] AS [myName],
		ISNULL( [rs1].[enCurrencyPtr], [rs2].[enCurrencyPtr]) ,
		[ac].[Security],
		ISNULL( [rs1].[TotalDebit], 0 ),
		ISNULL( [rs1].[TotalCredit], 0 ),
		ISNULL( [rs1].[TotalBal], 0 ),
		ISNULL( [rs1].[enCurrTotalDebit], 0 ),
		ISNULL( [rs1].[enCurrTotalCredit], 0 ),
		ISNULL( [rs1].[enCurrTotalBal], 0 ),
	
		ISNULL( [rs2].[TotalDebit], 0 ),
		ISNULL( [rs2].[TotalCredit], 0 ),
		ISNULL( [rs2].[TotalBal], 0 ),
		ISNULL( [rs2].[enCurrTotalDebit], 0 ),
		ISNULL( [rs2].[enCurrTotalCredit], 0 ),
		ISNULL( [rs2].[enCurrTotalBal], 0 ),
		0,
		[ac].[ParentGuid],
		[ac].[CurrencyGUID],
		ISNULL([rs1].[enCurrAccTotalDebit],0),
		ISNULL([rs1].[enCurrAccTotalCredit],0),
		ISNULL([rs2].[PrevenCurrAccTotalDebit],0),
		ISNULL([rs2].[PrevenCurrAccTotalCredit],0),-1	
	FROM 
		([#t_Bal] AS [rs1] FULL JOIN [#t_PrevBal] AS [rs2] ON [rs1].[Number] = [rs2].[Number] AND [rs1].[enCurrencyPtr] = [rs2].[enCurrencyPtr])
		INNER JOIN [ac000] AS [ac] ON ISNULL( [rs1].[Number], [rs2].[Number])= [ac].[GUID]
		INNER JOIN [vwmy] AS [my] ON ISNULL( [rs1].[enCurrencyPtr], [rs2].[enCurrencyPtr]) = [my].[myGUID]
		
	
	IF  @ShowMainAcc = 1 
	BEGIN
		INSERT INTO [#ACC1] 
		SELECT [f].*, [Code] AS [acCode] , [Name] AS [acName], [LatinName] AS [acLatinName],[parentGuid] AS [acParent],[Security] AS [acSecurity],[CurrencyGUID]
		FROM [fnGetAccountsList](@AccGUID,0) AS [f] 
		INNER JOIN [ac000] AS [ac] ON [ac].[Guid] = [f].[guid]
		SELECT  @Level = Max([LEVEL]) FROM [#ACC1]
		WHILE @Level> =0
		BEGIN
			INSERT INTO [#t_Result]
				SELECT
					[ac].[Guid],
					[ac].[acName],
					[ac].[acLatinName],
					[ac].[acCode],
					[t].[myName],
					[t].[enCurrencyPtr],
					[ac].[acSecurity],
					SUM([t].[TotalDebit]),
					SUM([TotalCredit]),
					SUM([TotalBal]),
					SUM([enCurrTotalDebit]),
					SUM([enCurrTotalCredit]),
					SUM([enCurrTotalBal]),
					SUM([PrevTotalDebit]),
					SUM([PrevTotalCredit]),
					SUM([PrevTotalBal]),
					SUM([PrevEnCurrTotalDebit]),
					SUM([PrevEnCurrTotalCredit]),
					SUM([PrevEnCurrTotalBal]),
					1,
					[ac].[acParent],[ac].[CurrencyGUID],0,0,0,0,[ac].[Level]
			FROM [#t_Result] AS [t] INNER JOIN [ac000] AS [ac1] ON [t].[Number] = [ac1].[Guid]
			INNER JOIN [#ACC1] AS [ac] ON [ac1].[ParentGuid] = [ac].[Guid]
			WHERE [ac].[Level] = @Level
			GROUP BY
				[ac].[Guid],
					[ac].[acName],
					[ac].[acLatinName],
					[ac].[acCode],
					[t].[myName],
					[t].[enCurrencyPtr],
					[ac].[acSecurity],
					[ac].[acParent],[ac].[CurrencyGUID],[ac].[Level]
			
			SET @Level = @Level - 1	
		END
		SET @Admin = [dbo].[fnIsAdmin](ISNULL(@userGUID,0x00) )
		IF @Admin = 0
		BEGIN
			DECLARE @Updated [INT]
			
			SET @Updated = 1
			UPDATE [#t_Result] SET [acSecurity] = -1 WHERE [acSecurity] > [dbo].[fnGetUserAccountSec_Browse](@UserGuid)
			WHILE @Updated > 0
			BEGIN
				UPDATE [ac] SET  [acParent] = [ac2].[acParent] FROM [#t_Result] AS [ac] INNER JOIN [#t_Result] AS [ac2] ON [ac2].[Number] = [ac].[acParent] WHERE  [ac2].[acSecurity] = -1
				SET @Updated = @@ROWCOUNT
			END
			DELETE [#t_Result] WHERE [acSecurity] = -1
			IF @@ROWCOUNT <> 0
			BEGIN
				IF EXISTS(SELECT * FROM [#SecViol] WHERE [Type] = 5)
					INSERT INTO [#SecViol] VALUES(@Level,5)
			END
		END
		
			
	END
	IF (@SortType > 1) AND (@CurrPtr = 0X00)
	BEGIN
		INSERT INTO [#S_Result] SELECT [Number] AS [accPtr],SUM( [TotalDebit]) AS [SUMDebit],SUM( [TotalCredit]) AS [SUMCredit] FROM [#t_Result] GROUP BY [Number]
	END
	-----return results set

	DECLARE @s AS [NVARCHAR](2000)
	SET @s = ' 	
		SELECT 
			[Number],
			[acName],
			[acLatinName],
			[acCode],
			[t].[myName],
			[enCurrencyPtr],
			[MainAcc],
			SUM( [TotalDebit]) AS [TotalDebit],
			SUM( [TotalCredit]) AS [TotalCredit],
			SUM( [TotalBal]) AS [TotalBal],
			SUM( [enCurrTotalDebit]) AS [enCurrTotalDebit],
			SUM( [enCurrTotalCredit]) AS [enCurrTotalCredit],
			SUM( [enCurrTotalBal]) AS [enCurrTotalBal],
			SUM( [PrevTotalDebit]) AS [PrevTotalDebit],
			SUM( [PrevTotalCredit]) AS [PrevTotalCredit],
			SUM( [PrevTotalBal]) AS [PrevTotalBal],
			SUM( [PrevEnCurrTotalDebit]) AS [PrevEnCurrTotalDebit],
			SUM( [PrevEnCurrTotalCredit]) AS [PrevEnCurrTotalCredit],
			SUM( [PrevEnCurrTotalBal]) AS [PrevEnCurrTotalBal]'
	IF @AccCurr > 0
			SET @s = @s +',SUM([enCurrAccTotalDebit]) AS [enCurrAccTotalDebit],
			SUM([enCurrAccTotalCredit]) AS [enCurrAccTotalCredit],
			SUM([PrevenCurrAccTotalDebit]) AS	[PrevenCurrAccTotalDebit],
			SUM([PrevenCurrAccTotalCredit]) AS [PrevenCurrAccTotalCredit],[myCode]'
	IF (@SortType > 1) AND (@CurrPtr = 0X00)
		SET @s = @s + ' ,[SUMDebit],[SUMCredit] '
	--IF  (@ShowMainAcc = 1) 
		SET @s = @s + ' ,[acParent],[acLevel]'	
	SET @s = @s + ' FROM	[#t_Result] AS [t]'
	IF (@SortType > 1) AND (@CurrPtr = 0X00)
		SET @s = @s + ' INNER JOIN [#S_Result] AS [s] ON [s].[accPtr] = [Number] '	
	IF @AccCurr > 0
		SET @s = @s + ' INNER JOIN [vwmy] AS [my] ON [my].[myGuid] = [CurrAccGuid]' 
	IF @ShowSubAcc = 0 
		SET @s = @s + 'WHERE [MainAcc] = 1 '
	SET @s = @s +' 	GROUP BY '
	IF (@SortType > 1) AND (@CurrPtr = 0X00)
		SET @s = @s + ' [SUMDebit],[SUMCredit], '
	--IF  (@ShowMainAcc = 1) 
		SET @s = @s + '[acParent],[acLevel],'	
	IF @AccCurr > 0
			SET @s = @s +'[myCode],'
	SET @s = @s +'	[Number],
			[acName],
			[acLatinName],
			[acCode],
			[t].[myName],
			[enCurrencyPtr],
			[MainAcc]	ORDER BY [Number]'
	
	EXECUTE( @s)
	SELECT * FROM [#SecViol]
	SELECT [Code] AS [myName] FROM [my000] WHERE [Number] = 1
/*
	prcConnections_add2'„œÌ—'
	EXEC  [repCurBal] '00000000-0000-0000-0000-000000000000', '1/1/2004', '6/2/2005', '12/31/2003', '12/31/2003', 0, 1, '00000000-0000-0000-0000-000000000000', 0, 1, 0, 0 
*/
################################################################
#END