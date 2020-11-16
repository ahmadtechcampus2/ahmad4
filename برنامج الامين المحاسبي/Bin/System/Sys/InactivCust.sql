################################################################################
CREATE PROCEDURE repCustNoMove 
	@AccountGUID		UNIQUEIDENTIFIER,
	@CurrencyGUID		UNIQUEIDENTIFIER, 
	@CurrencyVal		INT, 
	@StartDate			DATETIME, 
	@EndDate			DATETIME, 
	@BillSources		UNIQUEIDENTIFIER, 
	@EntrySources		UNIQUEIDENTIFIER, 
	@HideClosed			INT,
	@CostGUID			UNIQUEIDENTIFIER,
	@ShowEmptyCust		INT,
	@GroupGUID			UNIQUEIDENTIFIER,
	@MaterialGUID		UNIQUEIDENTIFIER,
	@StoreGUID			UNIQUEIDENTIFIER,
	@ShowCustCard		INT,
	@CustCondGUID		UNIQUEIDENTIFIER,
	@CustGUID			UNIQUEIDENTIFIER = 0x0
AS 
	SET NOCOUNT ON
	
	CREATE TABLE [#CustTbl](
		[CustGUID] UNIQUEIDENTIFIER,
		[Security] INT,
		[CustAccGUID] UNIQUEIDENTIFIER)
		
	INSERT INTO [#CustTbl]( [CustGUID], [Security]) EXEC [prcGetCustsList] NULL, NULL, @CustCondGUID 
	UPDATE ct SET ct.[CustAccGUID] = cu.[cuAccount] FROM vwcu cu INNER JOIN [#CustTbl] ct ON ct.[CustGUID] = cu.[cuGUID]
	
	CREATE TABLE [#AccTbl]( [GUID] UNIQUEIDENTIFIER, [CustGUID] UNIQUEIDENTIFIER)
	
	IF @ShowCustCard = 0
		INSERT INTO [#AccTbl]( [GUID])
		SELECT
			[fn].[GUID]
		FROM 
			[dbo].[fnGetAccountsList]( @AccountGUID, DEFAULT) [fn]
			INNER JOIN [vwAc] [Ac] ON [fn].[GUID] = [Ac].[acGUID]
			--RIGHT JOIN [#CustTbl] [cu] ON [fn].[GUID] = case @CustCondGUID when 0x00 then [fn].[GUID] else [cu].[CustAccGUID] end
			
		WHERE
			[Ac].[acNSons] = 0
	ELSE
		INSERT INTO [#AccTbl]
		SELECT [GUID], [cu].[CustGUID]
		FROM
			[dbo].[fnGetAccountsList]( @AccountGUID, DEFAULT) [fn]
			RIGHT JOIN [#CustTbl] [cu] ON [fn].[GUID] = [cu].[CustAccGUID]
	------------------------------------ 
	CREATE TABLE [#SrcBill] ( [Type] UNIQUEIDENTIFIER, [Sec] INT, [ReadPrice] INT, [UnPostedSec]INT)  
	INSERT INTO [#SrcBill] EXEC [prcGetBillsTypesList2] @BillSources
	------------------------------------ 
	CREATE TABLE [#Mat] ( [mtGUID] UNIQUEIDENTIFIER, [mtSecurity] INT)
	INSERT INTO [#Mat] EXEC [prcGetMatsList]  @MaterialGUID, @GroupGUID 
	----------------------------
	CREATE TABLE [#Store] ( [GUID] UNIQUEIDENTIFIER)
	INSERT INTO  [#Store] SELECT [GUID] FROM [fnGetStoresList]( @StoreGUID)
	----------------------------
	CREATE TABLE [#SrcEntry]( [Type] UNIQUEIDENTIFIER, [Security] INT)
	INSERT INTO [#SrcEntry] EXEC [prcGetNotesTypesList]  @EntrySources
	INSERT INTO [#SrcEntry] EXEC [prcGetEntriesTypesList] @EntrySources
	----------------------------
	DECLARE @CostTbl TABLE( [GUID] UNIQUEIDENTIFIER)
	INSERT INTO @CostTbl  SELECT [GUID] FROM [dbo].[fnGetCostsList]( @CostGUID)
	IF ISNULL( @CostGUID, 0x0) = 0x0   
		INSERT INTO @CostTbl VALUES(0x0)  
	CREATE TABLE [#SecViol]([Type] INT, [Cnt] INT) 
	CREATE TABLE [#OldAccTbl]( [GUID] UNIQUEIDENTIFIER, [Security] INT, [UserSecurity] INT, [UserUnPostedSec] INT, [CustGuid] UNIQUEIDENTIFIER)
	
	IF @ShowCustCard = 1
		BEGIN
			INSERT INTO [#OldAccTbl]( [GUID], [CustGuid], [Security], [UserSecurity]) 
			SELECT DISTINCT
				[Acc].[GUID],
				[Acc].[CustGUID], 
				[buSecurity],
				CASE [Bill].[buIsPosted]
					WHEN 1 THEN [SrcBill].[Sec] 
					ELSE [SrcBill].[UnPostedSec] 
				END
			FROM
				[vwExtended_bi] AS [Bill]
				INNER JOIN [#SrcBill] AS [SrcBill] ON [buType] = [SrcBill].[Type]
				INNER JOIN [#AccTbl] AS [Acc] ON [Acc].[CustGUID] = [Bill].[buCustPtr]
				INNER JOIN @CostTbl AS [cost] ON [Bill].[biCostPtr] = [cost].[GUID]
				INNER JOIN [#Mat] AS [mt] ON [mt].[mtGUID] = [Bill].[biMatPtr]
				INNER JOIN [#Store] AS [st] ON [st].[GUID] = [Bill].[biStorePtr]
			WHERE
				[buDate] BETWEEN @StartDate AND @EndDate
				AND [buIsPosted] = 1
		END
	ELSE
		BEGIN
			INSERT INTO [#OldAccTbl]( [GUID], [CustGuid], [Security], [UserSecurity]) 
			SELECT DISTINCT  
				[buCustAcc],
				[buCustAcc],
				[buSecurity],
				CASE [Bill].[buIsPosted]
					WHEN 1 THEN [SrcBill].[Sec]
					ELSE [SrcBill].[UnPostedSec]
				END
			FROM
				[vwExtended_bi] AS [Bill]
				INNER JOIN [#SrcBill] AS [SrcBill] ON [buType] = [SrcBill].[Type]
				INNER JOIN [#AccTbl] AS [Acc] ON [Acc].[GUID] = [Bill].[buCustAcc]
				INNER JOIN @CostTbl AS [cost] ON [Bill].[biCostPtr] = [cost].[GUID]
				INNER JOIN [#Mat] AS [mt] ON [mt].[mtGUID] = [Bill].[biMatPtr]
				INNER JOIN [#Store] AS [st] ON [st].[GUID] = [Bill].[biStorePtr]
			WHERE
				[buDate] BETWEEN @StartDate AND @EndDate
				AND [buIsPosted] = 1
		END
	INSERT INTO [#OldAccTbl]( [GUID], [CustGuid])
	SELECT
		DISTINCT [Acc].[GUID], [cu].[cuGUID] 
	FROM
		[vwExtended_en] AS [Ce]
		INNER JOIN [#SrcEntry] AS [SrcEntry] ON [Ce].[ceTypeGUID] = [SrcEntry].[Type]
		INNER JOIN [#AccTbl] AS [Acc] ON [Acc].[GUID] = [Ce].[enAccount]
		INNER JOIN @CostTbl AS [Cost] ON [Ce].[enCostPoint] = [Cost].[GUID]
		INNER JOIN vwcu AS [cu] ON [cu].[cuGUID] = [ce].[enCustomerGUID]
	WHERE
		[ceDate] BETWEEN @StartDate AND @EndDate
		
	----------------------------------------------------------------------- 
	EXEC [prcCheckSecurity] @result = '#OldAccTbl', @Check_AccBalanceSec = 1 
	------------------------------------------------------------------------ 
	
	CREATE TABLE [#Result](
		[AccGUID]			UNIQUEIDENTIFIER,
		[Debit]				FLOAT,
		[Credit]			FLOAT,
		[AccCurrencyDebit]	FLOAT,
		[AccCurrencyCredit] FLOAT,
		[AccSecurity]		INT,
		[IsClosed]			INT,
		[IsEmpty]			INT,
		[CustGuid]			UNIQUEIDENTIFIER,
		[CustName]          NVARCHAR(512)  COLLATE ARABIC_CI_AI
		)
		
	INSERT INTO [#Result]
	SELECT
		[Acc].[GUID],
		t.Debit,
		t.Credit,
		t1.Debit,
		t1.Credit,
		[vac].[acSecurity],
		0,
		0,
		[cu].[cuGUID],
		[cu].[cuCustomerName]
	FROM
		[#AccTbl] AS [Acc]
		INNER JOIN [vwAc] [vac] ON [vac].[acGUID] = [Acc].[GUID]	
		LEFT JOIN  [vwCu] AS [cu] ON [cu].[cuAccount] = [Acc].[GUID]
		CROSS APPLY [fnAccount_Customer_getDebitCredit]( [Acc].[GUID], @CurrencyGUID, [cu].[cuGUID] ) t
		CROSS APPLY [fnAccount_Customer_getDebitCredit]( [Acc].[GUID], [vac].[acCurrencyPtr], [cu].[cuGUID] )  t1 
		LEFT JOIN  [#OldAccTbl] AS [OldAcc] ON [OldAcc].[GUID] = [Acc].[GUID] AND [OldAcc].[CustGuid]  = [cu].[cuGUID] 
	WHERE
		[OldAcc].[GUID] IS NULL
		AND ISNULL([cu].[cuGUID], 0x0) = CASE WHEN ISNULL(@CustGUID, 0x0) <> 0x0 THEN @CustGUID ELSE ISNULL([cu].[cuGUID], 0x0)END 
		AND @StartDate < @EndDate
	
	IF @ShowEmptyCust = 1
	BEGIN
		UPDATE [#Result]
		SET [IsEmpty] = 1
		WHERE ([Debit] = 0) AND ([Credit] = 0)
	END
	ELSE IF @ShowEmptyCust = 0
	BEGIN 
		DELETE [#Result]
		WHERE ([Debit] = 0) AND ([Credit] = 0)
	END
	IF @HideClosed = 0
	BEGIN
		UPDATE [#Result]
		SET [IsClosed] = 1
		WHERE (([Debit] <> 0) AND ([Credit] <> 0)) AND ([Debit] - [Credit] = 0)
	END
	ELSE IF @HideClosed  = 1
	BEGIN
		DELETE [#Result]
		WHERE (([Debit] <> 0) AND ([Credit] <> 0)) AND ([Debit] - [Credit] = 0)
	END
	---------------------------------------------------------------------------------------	 
	EXEC [prcCheckSecurity] @Check_AccBalanceSec = 1 
	---------------------------------------------------------------------------------------	 
	
	----------------------- Main Result ----------------------------------------------------		
	SELECT DISTINCT
		[Ac].[acGUID] AS [AccGuid],
		ISNULL( [Res].[CustGuid], 0x0) As [CuGUID],
		SUM( [Res].[Debit]) AS [Debit], 
		SUM( [Res].[Credit]) AS [Credit],
		SUM( [Res].[AccCurrencyDebit] - [Res].[AccCurrencyCredit]) AS [DefCurrencyBalance],
		[IsEmpty],
		[IsClosed],
		[Res].[CustName],
		[AC].[acName],
		[AC].[acCode],
		[my].[Name] AS [AcCurrency]
	FROM  
		[#Result] AS [Res] 
		INNER JOIN [vwAc] AS [Ac] ON [Res].[AccGUID] = [Ac].[acGUID]
		INNER JOIN [my000] AS [my] ON [my].[GUID] = [ac].[acCurrencyPtr]
		LEFT JOIN [vwCu] AS [cu] ON [Res].[AccGUID] = [cu].[cuAccount]
	WHERE
		ISNULL([cu].[cuGUID], 0x0)= CASE WHEN ISNULL(@CustGUID, 0x0) <> 0x0 THEN @CustGUID ELSE ISNULL([cu].[cuGUID], 0x0)END 
	GROUP BY 
		[AC].[acName],
		[Res].[CustName],
		[Ac].[acGUID],
		[Res].[CustGuid],
		ISNULL( [cu].[cuGUID], 0x0),
		ISNULL( [my].[Code], ''''),
		[IsEmpty],
		[IsClosed],
		[ac].[acCode],
		[my].[Name]
	ORDER BY
		[AC].[AcName], [Res].[CustName]
		---------------------------------------------------------------------------------------	
	SELECT * FROM [#SecViol]
################################################################################
#END
