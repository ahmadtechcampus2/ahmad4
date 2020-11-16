##########################################################################
CREATE PROC repGetCheckedBal
	@AccGUID [UNIQUEIDENTIFIER], 
	@CostGUID [UNIQUEIDENTIFIER] = 0x0,
	@CurrencyGUID [UNIQUEIDENTIFIER], 
	@ShowRealBal [INT] = 0,
	@CustGUID [UNIQUEIDENTIFIER]
AS  
	SET NOCOUNT ON;  

	CREATE TABLE [#CustTbl] ([GUID] [UNIQUEIDENTIFIER], [Security] [INT])
	INSERT INTO  [#CustTbl] EXEC [dbo].[prcGetCustsList] @CustGUID, @AccGUID, 0x0
	IF @CustGUID = 0x0
  		INSERT INTO  [#CustTbl] SELECT 0x0, 0

	CREATE TABLE [#Result]( 
		[GUID] [UNIQUEIDENTIFIER], 
		[AccGuid] [UNIQUEIDENTIFIER], 
		[usName] [NVARCHAR](250) COLLATE Arabic_CI_AI, 
		[Debit] [FLOAT], 
		[Credit] [FLOAT], 
		[RealBal] [FLOAT], 
		[CheckedToDate] [DATETIME], 
		[CheckDate] [DATETIME], 
		[Notes]	[NVARCHAR](250) COLLATE Arabic_CI_AI, 
		[CostGuid] [UNIQUEIDENTIFIER],
		[CustGuid] [UNIQUEIDENTIFIER],
		[CustName]	[NVARCHAR](250) COLLATE Arabic_CI_AI,
		[AccCode]	[NVARCHAR](250) COLLATE Arabic_CI_AI,
		[AccLevel]	[INT],
		[CoCode]	[NVARCHAR](250) COLLATE Arabic_CI_AI) 

	IF @CostGUID = 0x0 
		INSERT INTO [#Result]
		SELECT 
			[acc].[guid], 
			[acc].[AccGuid], 
			[us].[usLoginName], 
			[dbo].[fnCurrency_fix]( [acc].[Debit], [acc].[CurrencyGUID], [acc].[CurrencyVal], @CurrencyGUID, [acc].[Date]), 
			[dbo].[fnCurrency_fix]( [acc].[Credit], [acc].[CurrencyGUID], [acc].[CurrencyVal], @CurrencyGUID, [acc].[Date]), 
			0, 
			[acc].[CheckedToDate], 
			[acc].[Date], 
			[acc].[Notes],
			0x0,
			[cu].[GUID],
			CASE dbo.fnConnections_GetLanguage() WHEN 0 THEN [vwcu].[cuCustomerName] ELSE (CASE [vwcu].[cuLatinName] WHEN '' THEN [vwcu].[cuCustomerName] ELSE [vwcu].[cuLatinName] END) END,
			[vwac].[acCode],
			[ac].[Level],
			''
		FROM  
			[CheckAcc000] [acc]
			INNER JOIN [vwUs] [us] ON [us].[usGUID] = [acc].[UserGUID] 
			INNER JOIN [dbo].[fnGetAccountsList]( @AccGUID, DEFAULT) [ac] ON [ac].[GUID] = [acc].[AccGUID] 
			INNER JOIN [vwac] [vwac] ON [vwac].[acGUID] = [acc].[AccGUID] 
			INNER JOIN [#CustTbl] [cu] ON [cu].[GUID] = [acc].[CustGUID] 
			LEFT JOIN [vwCu] [vwcu] ON [vwcu].[cuAccount] = [acc].[AccGUID] AND [vwcu].[cuGUID] = [acc].[CustGUID]
		WHERE 
			[acc].[CostGUID] = 0x0

	ELSE 
		INSERT INTO [#Result]
		SELECT 
			[acc].[guid], 
			[acc].[AccGuid], 
			[us].[usLoginName], 
			[dbo].[fnCurrency_fix]( [acc].[Debit], [acc].[CurrencyGUID], [acc].[CurrencyVal], @CurrencyGUID, [acc].[Date]), 
			[dbo].[fnCurrency_fix]( [acc].[Credit], [acc].[CurrencyGUID], [acc].[CurrencyVal], @CurrencyGUID, [acc].[Date]), 
			0, 
			[acc].[CheckedToDate], 
			[acc].[Date], 
			[acc].[Notes],
			[acc].[CostGUID],
			[acc].[CustGUID],
			CASE dbo.fnConnections_GetLanguage() WHEN 0 THEN [vwcu].[cuCustomerName] ELSE (CASE [vwcu].[cuLatinName] WHEN '' THEN [vwcu].[cuCustomerName] ELSE [vwcu].[cuLatinName] END) END,
			[vwac].[acCode],
			[ac].[Level],
			[vwco].[coCode]
		FROM  
			[CheckAcc000] [acc]
			INNER JOIN [vwus] [us] ON [us].[usGUID] = [acc].[UserGUID] 
			INNER JOIN [dbo].[fnGetAccountsList]( @AccGUID, DEFAULT) [ac] ON [ac].[GUID] = [acc].[AccGUID] 
			INNER JOIN [vwac] [vwac] ON [vwac].[acGUID] = [acc].[AccGUID] 
			INNER JOIN [vwco] [vwco] ON [vwco].[coGUID] = [acc].[CostGUID] 
			INNER JOIN [#CustTbl] [cu] ON [cu].[GUID] = [acc].[CustGUID]  
			LEFT JOIN [vwCu] [vwcu] ON [vwcu].[cuAccount] = [acc].[AccGUID] AND [vwcu].[cuGUID] = [acc].[CustGUID]
		WHERE 
			[vwco].[coGUID] = @CostGUID
		
	IF @ShowRealBal = 1 
		IF @CostGUID = 0x0 
			UPDATE [#Result] 
			SET [RealBal] = [dbo].[fnAccCust_getBalance]( [AccGuid], @CurrencyGUID, DEFAULT, [CheckedToDate], @CostGUID, [CustGuid]) 
		ELSE 
			UPDATE [#Result] 
			SET [RealBal] = [dbo].[fnCost_getBalance]( [AccGuid], @CostGUID, @CurrencyGUID, DEFAULT, [CheckedToDate], [CustGuid])
	SELECT * FROM [#Result] ORDER BY [CheckedToDate], [AccLevel], [AccCode], [CustName], [CoCode]
###############################################################################
#END
