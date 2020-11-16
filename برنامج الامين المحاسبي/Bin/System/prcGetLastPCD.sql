######################################################### 
CREATE PROC prcGetLastPCD	
	@StartDate [DATETIME],
	@EndDate [DATETIME],
	@AccPtr [UNIQUEIDENTIFIER],
	@CurrencyGuid [UNIQUEIDENTIFIER],
	@CostPtr [UNIQUEIDENTIFIER],
	@ShowLastDebit [BIT],
	@ShowLastCredit [BIT],
	@ShowLastPay [BIT]
AS 
	SET NOCOUNT ON 
	
	CREATE TABLE [#SecViol1]([Type] [INT], [Cnt] [INT])
	CREATE TABLE [#Result1]( [Type] [INT], [LastPay] [FLOAT], [Date] [DATETIME], [ceSecurity] [INT])
	-- Type: 1Credit 2Debit 3Pay
		
	DECLARE @Cost_Tbl TABLE( [GUID] [UNIQUEIDENTIFIER]) 
	INSERT INTO @Cost_Tbl  SELECT [GUID] FROM [dbo].[fnGetCostsList]( @CostPtr)  
	IF ISNULL( @CostPtr, 0x0) = 0x0   
		INSERT INTO @Cost_Tbl VALUES(0x0)

	-- LastDebit	type 1
	IF @ShowLastDebit != 0
	BEGIN 
		INSERT INTO [#Result1]
		SELECT TOP 1
			1,
			[dbo].[fnCurrency_fix]( [enDebit], [enCurrencyPtr], [enCurrencyVal], @CurrencyGuid , @EndDate),
			[enDate],
			[ceSecurity]
		FROM
			[vwExtended_en] [en]
			INNER JOIN @Cost_Tbl [co] ON [en].[enCostPoint] = [co].[Guid]
		WHERE
			([enDate] BETWEEN @StartDate AND @EndDate)
			AND( [enCredit] = 0)
			AND( [enAccount] = @AccPtr)
		ORDER BY [enDate] DESC
	END 
	
	-- LastCredit	type 2
	IF @ShowLastCredit != 0
	BEGIN 
		INSERT INTO [#Result1]
		SELECT TOP 1
			2,
			[dbo].[fnCurrency_fix]( [enCredit], [enCurrencyPtr], [enCurrencyVal], @CurrencyGuid , @EndDate),
			[enDate],
			[ceSecurity]
		FROM
			[vwExtended_en] [en]
			INNER JOIN @Cost_Tbl [co] ON [en].[enCostPoint] = [co].[Guid]
		WHERE
			([enDate] BETWEEN @StartDate AND @EndDate)
			AND( [enDebit] = 0)
			AND( [enAccount] = @AccPtr)
		ORDER BY [enDate] DESC
	END 


	-- LastPay	type 3
	IF @ShowLastPay != 0
	BEGIN 
		CREATE TABLE [#Tbl]( [Type] [INT], [LastPay] [FLOAT], [Date] [DATETIME], [ceSecurity] [INT])

		INSERT INTO [#Tbl]
		SELECT TOP 1
			3,
			[dbo].[fnCurrency_fix]( [enCredit], [enCurrencyPtr], [enCurrencyVal], @CurrencyGuid , @EndDate),
			[enDate],
			[ceSecurity]
		FROM
			[vwExtended_en] AS [en]
			INNER JOIN [vwEr] AS [er] ON [en].[ceGuid] = [er].[erEntryGuid]  
			INNER JOIN [vwPy] AS [py] ON [er].[erParentGuid] = [py].[pyGuid]
			INNER JOIN @Cost_Tbl [co] ON [en].[enCostPoint] = [co].[Guid]
		WHERE
			([enDate] BETWEEN @StartDate AND @EndDate)
			AND( [enDebit] = 0) 
			AND( [enAccount] = @AccPtr)
		ORDER BY [enDate] DESC

		INSERT INTO [#Tbl]
		SELECT TOP 1
			3,
			[dbo].[fnCurrency_fix]( [enCredit], [enCurrencyPtr], [enCurrencyVal], @CurrencyGuid , @EndDate),
			[enDate],
			[ceSecurity]
		FROM
			[vwExtended_en] AS [en]
			INNER JOIN @Cost_Tbl [co] ON [en].[enCostPoint] = [co].[Guid]
			LEFT JOIN [vwEr] AS [er] ON [en].[ceGuid] = [er].[erEntryGuid]  
		WHERE
			([enDate] BETWEEN @StartDate AND @EndDate)
			AND [erParentGuid] IS NULL
			AND( [enDebit] = 0)
			AND( [enAccount] = @AccPtr)
		ORDER BY [enDate] DESC

		INSERT INTO [#Result1]
		SELECT 
			TOP 1 * 
		FROM 
			[#Tbl]
		ORDER BY 
			[Date] DESC
	END 

	EXEC [prcCheckSecurity] @result = '#Result1', @secViol = '#SecViol1'
	SELECT @AccPtr AS [AccGUID], @CostPtr AS [CostGUID], * FROM [#Result1] ORDER BY [Date] DESC

#########################################################
#END
