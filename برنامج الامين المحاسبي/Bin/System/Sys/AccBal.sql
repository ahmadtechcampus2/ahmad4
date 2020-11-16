################################################################################
CREATE PROCEDURE repAccBalRep
	@StartDate			[DATETIME],
	@EndDate			[DATETIME],
	@AccountGUID		[UNIQUEIDENTIFIER],
	@CustomerGUID		[UNIQUEIDENTIFIER],
	@CurGUID			[UNIQUEIDENTIFIER],
	@CurVal				[FLOAT],
	@Contain			[NVARCHAR](200),
	@NotContain			[NVARCHAR](200),
	@Type				[INT],			-- 0 All Accounts, 1 Debit Only, 2 Credit Only, 3 Exceeded Max Balace Only 
	@ShowZero			[INT],
	@PrevBalance		[INT],
	@CostGuid			[UNIQUEIDENTIFIER],
	@SrcGuid			[UNIQUEIDENTIFIER] = 0X0,
	@ShowTaxRelated		[BIT],
	@ShowNotTaxRelated	[BIT],
	@ShowDetaildCustomerAccount	[BIT] = 0
AS
	--  ﬁ—Ì— √—’œ… «·Õ”«»« 
	SET NOCOUNT ON 
	CREATE TABLE #Accounts ([GUID] [UNIQUEIDENTIFIER], [Level] [INT], [Path] [VARCHAR](8000), 
							[acSecurity] INT, acType INT, acNsons INT, acNotes NVARCHAR(250))
	INSERT INTO 
		#Accounts 
	SELECT 
		a.*,
		ac.acsecurity,
		ac.acType,
		ac.acNsons,
		ac.acNotes
	FROM 
		[dbo].[fnGetAcDescList](@AccountGUID) a 
		INNER JOIN 	vwac ac ON a.guid = ac.acguid
	WHERE 
	    [ac].[isUsingAddedValue] = @ShowTaxRelated OR NOT [ac].[isUsingAddedValue] = @ShowNotTaxRelated
	
	DECLARE  @UserGUID UNIQUEIDENTIFIER
	SET @UserGUID = [dbo].[fnGetCurrentUserGUID]()
	
	CREATE TABLE [#BillTbl]( [Type] UNIQUEIDENTIFIER, [Security] INT, [ReadPriceSecurity] INT)
	CREATE TABLE [#EntryTbl]( [Type] UNIQUEIDENTIFIER, [Security] INT)   
	
	INSERT INTO [#EntryTbl] EXEC [prcGetNotesTypesList]  @SrcGuid, @UserGUID
	INSERT INTO [#BillTbl] EXEC [prcGetBillsTypesList] @SrcGuid, @UserGUID       
	INSERT INTO [#EntryTbl] EXEC [prcGetEntriesTypesList] @SrcGuid, @UserGUID
	INSERT INTO [#EntryTbl] SELECT [Type], [Security] FROM [#BillTbl]   
	DECLARE @Cost_Tbl TABLE( [GUID] UNIQUEIDENTIFIER) 
	INSERT INTO @Cost_Tbl SELECT [GUID] FROM [dbo].[fnGetCostsList]( @CostGUID)
	IF ISNULL(@CostGUID, 0x0) = 0x0   
		INSERT INTO @Cost_Tbl VALUES(0x0)  
	-----------------------------------------------------------
	CREATE TABLE [#SecViol]([Type] INT, [Cnt] INT)
 
	CREATE TABLE [#Result](
		[AccountGUID]	UNIQUEIDENTIFIER, 
		[Debit]			FLOAT,
		[Credit]		FLOAT,
		[Security]		INT,
		[UserSecurity]	INT,
		[AccSecurity]	INT,
		[CustomerGuid]	UNIQUEIDENTIFIER)

	CREATE TABLE [#EndResult](
		[AccountGUID]	UNIQUEIDENTIFIER, 
		[Debit]			FLOAT,
		[Credit]		FLOAT,
		[AccMaxDebit]	FLOAT,
		[MaxCredit]		FLOAT,
		[Balanc]		FLOAT,
		[PrevBalance]	FLOAT,
		[CustomerGuid]	UNIQUEIDENTIFIER)
	DECLARE @Sec INT
	SET @Sec = [dbo].[fnGetUserEntrySec_Browse](@UserGUID, 0x0)
	INSERT INTO [#Result]
	SELECT
		[ac].[Guid],
		[fn].[FixedEnDebit],
		[fn].[FixedEnCredit],
		[fn].[ceSecurity],
		ISNULL(src.[Security], @Sec),
		[ac].[acSecurity],
		CASE @ShowDetaildCustomerAccount WHEN 1 THEN [fn].[enCustomerGUID] ELSE ISNULL(@CustomerGUID, 0x0) END
	FROM
		([dbo].[fnExtended_En_Fixed_Src]( @SrcGuid, @CurGUID) AS [fn]
		INNER JOIN #Accounts AS [ac] ON [fn].[enAccount] = [ac].[Guid]
		INNER JOIN @Cost_Tbl AS [Cost] ON [fn].[enCostPoint] = [Cost].[GUID])
		LEFT JOIN [#EntryTbl] src ON [fn].[ParentTypeGUID] = src.[Type]
	WHERE
		[fn].[enDate] BETWEEN @StartDate AND @EndDate
		AND (@CustomerGUID = 0x0 OR [fn].[enCustomerGUID] = @CustomerGUID)
		AND [fn].[ceIsPosted] = 1
		AND [ac].[acType] <> 2 AND  [ac].[acNSons] = 0
		AND (@Contain = '' OR [ac].[acNotes] LIKE '%' + @Contain + '%')
		AND (@NotContain = '' OR [ac].[acNotes] NOT LIKE '%' + @NotContain + '%')

	EXEC [prcCheckSecurity] @Check_AccBalanceSec = 1
	----------------------------------------------------------
	IF @ShowDetaildCustomerAccount = 1
	BEGIN
		IF ISNULL(@CustomerGUID, 0x0) <> 0x0
		BEGIN
			DELETE [r] 
			FROM [#Result] AS [r]
			INNER JOIN [ac000] [ac] ON [r].[AccountGuid] = [ac].[Guid]
			LEFT JOIN [cu000] [cu] ON [r].[CustomerGuid] = [cu].[Guid] AND [cu].[AccountGuid] = [ac].[Guid]
			WHERE [cu].[AccountGuid] IS NULL
		END
		ELSE
		BEGIN
			UPDATE [r]
				SET [r].[CustomerGuid] = 0x0
				FROM [#Result] AS [r]
				INNER JOIN [ac000] [ac] ON [r].[AccountGuid] = [ac].[Guid]
				LEFT JOIN [cu000] [cu] ON [r].[CustomerGuid] = [cu].[Guid] AND [cu].[AccountGuid] = [ac].[Guid]
				WHERE [cu].[AccountGuid] IS NULL
		END
	END
	----------------------------------------------------------
	INSERT INTO [#EndResult]
	SELECT 
		[r].[AccountGUID],
		SUM([r].[Debit]),
		SUM([r].[Credit]),
		0,--AccMaxDebit
		0,--MaxCredit
		CASE [ac].[acWarn]
			WHEN 2 THEN - (SUM([r].[Debit]) - SUM([r].[Credit]))
			ELSE  SUM( [r].[Debit]) - SUM( [r].[Credit])
		END,
		0,
		[r].[CustomerGuid]
	FROM
		[#Result] As [r] 
		INNER JOIN [vwAc] AS [ac] ON [r].[AccountGUID] = [ac].[acGUID]
	GROUP BY
		[r].[AccountGUID],
		[ac].[acWarn],
		[r].[CustomerGuid]
	-------------------------------------------------------------------------------	
	IF @PrevBalance	<> 0    
	BEGIN    
		CREATE TABLE [#PrevBalance]( 
			[AccGUID]		UNIQUEIDENTIFIER, 
			[enDebit]		FLOAT, 
			[enCredit]		FLOAT, 
			[acSecurity]	INT) 
		INSERT INTO [#PrevBalance] 
		SELECT
			[CE].[enAccount],
			[CE].[FixedEnDebit],
			[CE].[FixedEnCredit],
			[acc].[acSecurity]
		FROM    
			[dbo].[fnExtended_En_Fixed_Src]( @SrcGuid, @CurGUID) AS [CE]
			INNER JOIN #Accounts AS [Acc] On [Acc].[Guid] = [CE].[enAccount]   
			INNER JOIN @Cost_Tbl AS [Cost] ON [CE].[enCostPoint] = [Cost].[GUID]
		WHERE    
			[CE].[enDate] < @StartDate
			AND [CE].[ceIsPosted] = 1
		-------------------------------------------------- 
		EXEC [prcCheckSecurity] @result = '#PrevBalance', @Check_AccBalanceSec = 1
		-------------------------------------------------- 
		DECLARE @Prev_Balance TABLE( 
			[AccGUID]	UNIQUEIDENTIFIER,  
			[enDebit]	FLOAT, 
			[enCredit]	FLOAT)    
			  
		INSERT INTO @Prev_Balance  
		SELECT    
			[AccGUID],
			SUM( [enDebit]),
			SUM( [enCredit])
		FROM    
			[#PrevBalance]
		GROUP BY     
			[AccGUID]
		-----------------------------------------------------------------    
		UPDATE [er]
		SET [PrevBalance] = ([pb].[enDebit] - [pb].[enCredit])    
		FROM    
			[#EndResult] AS [er] 
			INNER JOIN @Prev_Balance AS [pb] ON [er].[AccountGUID] = [pb].[AccGUID]
	END    
	-------------------------------------------------------------------------------
	UPDATE [Res]
	SET
		[Res].[Debit] = CASE WHEN [Res].[Debit] > [Res].[Credit] THEN [Res].[Debit]-[Res].[Credit] ELSE 0 END,
		[Res].[Credit] = CASE WHEN [Res].[Credit] > [Res].[Debit] THEN [Res].[Credit]-[Res].[Debit] ELSE 0 END,
		[AccMaxDebit] = CASE ISNULL(Res.CustomerGuid, 0x0) WHEN 0x0 THEN
								 (CASE [ac].[Warn]	WHEN 2 THEN 0 
										ELSE [dbo].[fnCurrency_fix]( [ac].[MaxDebit], [ac].[CurrencyGuid], [ac].[CurrencyVal], @CurGUID, @EndDate) END)
							ELSE 
								(CASE [cu].[Warn]	WHEN 2 THEN 0 
										ELSE [dbo].[fnCurrency_fix]( [cu].[MaxDebit], [ac].[CurrencyGuid], [ac].[CurrencyVal], @CurGUID, @EndDate) END)
							END,
		[MaxCredit] = CASE ISNULL(Res.CustomerGuid, 0x0) WHEN 0x0 THEN
								(CASE [ac].[Warn] WHEN 1 THEN 0
										ELSE [dbo].[fnCurrency_fix]( [ac].[MaxDebit], [ac].[CurrencyGuid], [ac].[CurrencyVal], @CurGUID, @EndDate) END)
							ELSE 
								(CASE [cu].[Warn]	WHEN 1 THEN 0
										ELSE [dbo].[fnCurrency_fix]( [cu].[MaxDebit], [ac].[CurrencyGuid], [ac].[CurrencyVal], @CurGUID, @EndDate) END)
							END
	FROM [#EndResult] AS [Res]
	INNER JOIN [ac000] AS [ac] ON [Res].[AccountGUID] = [ac].[Guid]
	LEFT JOIN [cu000] AS [cu] ON [Res].[CustomerGuid] = [cu].[Guid]
	-------------------------------------------------------------------------------
	SELECT
		[Res].[AccountGUID] AS [AccPtr],
		[ac].[Name] AS [AcName],
		[ac].[LatinName] AS [AcLatinName],
		[cu].[CustomerName] AS [CustName],
		[cu].[LatinName] AS [CustLName],
		[ac].[Code] AS [AcCode],
		[AccMaxDebit],
		[AccMaxDebit] - [MaxCredit] AS [AccMaxBalance],
		(CASE WHEN [ac].[Warn] = 0	THEN 0
									ELSE ABS([AccMaxDebit]-[MaxCredit])-(CASE WHEN [ac].[Warn] = 2	THEN [Res].[Credit]-[Res].[Debit]
																									ELSE [Res].[Debit]-[Res].[Credit]
																									END)
									END) AS [DiffMaxBalance],
		[ac].[Warn] AS [AccWarn],
		[ac].[Notes] AS [AccNotes],
		[Res].[Debit] AS [SumDebit],
		[Res].[Credit] AS [SumCredit],
		[Res].[PrevBalance]	AS [PrevBalance]
	FROM
		[#EndResult] AS [Res] 
		INNER JOIN [ac000] AS [ac] ON [Res].[AccountGUID] = [ac].[Guid]
		LEFT JOIN [cu000] AS [cu] ON (@ShowDetaildCustomerAccount = 1 AND [Res].[CustomerGuid] = [cu].[GUID])
	WHERE
		(@Type = 0 /*all accounts*/ AND ((@ShowZero = 1) OR ((@ShowZero = 0) AND (Res.Balanc <> 0))))
		OR (@Type = 1 /*debit*/ AND ([Res].[Debit] - [Res].[Credit])  > 0 AND ((@ShowZero = 1) OR ((@ShowZero = 0) AND ([Res].[Balanc] <> 0))))
		OR (@type = 2 /*credit*/ AND ([Res].[Debit] - [Res].[Credit])  < 0 AND ((@ShowZero = 1) OR (@ShowZero = 0 AND ([Res].[Balanc] <> 0))))
		OR (@type = 3 /*exceeded max balance*/ AND [ac].[Warn] <> 0 AND [dbo].[fnCurrency_fix]( [ac].[MaxDebit], [ac].[CurrencyGuid], [ac].[CurrencyVal], @CurGUID, @EndDate) <= [Res].[Balanc])
	SELECT * FROM [#SecViol]
################################################################################
#END
