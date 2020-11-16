################################################################################
CREATE PROCEDURE repEntryTax  
	@AccPtr AS [UNIQUEIDENTIFIER]= 0X00,
	@CostPtr AS [UNIQUEIDENTIFIER] = 0X00,
	@EntrySources AS [UNIQUEIDENTIFIER] = 0X00,
	@EntryCond	AS	[UNIQUEIDENTIFIER] = 0X0,
	@CurGUID AS [UNIQUEIDENTIFIER],
	@StartDate AS [DATETIME],  
	@EndDate AS [DATETIME],
	@CustGuid AS [UNIQUEIDENTIFIER] = 0x00
AS
  SET NOCOUNT ON 
 
    CREATE TABLE [#AccTbl]( [Number] [UNIQUEIDENTIFIER], [Security] [INT], [Lvl] [INT])  
	CREATE TABLE [#CostTbl]( [Number] [UNIQUEIDENTIFIER], [Security] [INT]) 
	CREATE TABLE [#SrcEntry]( [Type] UNIQUEIDENTIFIER, [Security] INT) 

	INSERT INTO [#AccTbl] EXEC [prcGetAccountsList] @AccPtr  
	INSERT INTO [#CostTbl] EXEC [prcGetCostsList] @CostPtr
	IF ISNULL( @CostPtr, 0x0) = 0x0      
		INSERT INTO [#CostTbl] VALUES(0x00 , 0)  
	INSERT INTO [#SrcEntry] EXEC [prcGetEntriesTypesList] @EntrySources
	INSERT INTO [#SrcEntry] EXEC [prcGetNotesTypesList]  @EntrySources

	CREATE TABLE [#Result]
	(
		[CeNumber] [INT], 
		[ceGuid] [UNIQUEIDENTIFIER],
		[oppositeAccGuid] [UNIQUEIDENTIFIER],  
		[oppositeAccName] [NVARCHAR](250) COLLATE ARABIC_CI_AI,
		[costGuid] [UNIQUEIDENTIFIER],
		[costName] [NVARCHAR](250) COLLATE ARABIC_CI_AI, 
		[costCode] [NVARCHAR](250) COLLATE ARABIC_CI_AI,  		 
		[type] [NVARCHAR](250) COLLATE ARABIC_CI_AI,  
		[branchGuid] [UNIQUEIDENTIFIER],
		[branchName] [NVARCHAR](250) COLLATE ARABIC_CI_AI,  
		[customerName] [NVARCHAR](250) COLLATE ARABIC_CI_AI,  
		[valueWithoutTax] [FLOAT],
		[ceAddedValue] [FLOAT],
		[CePostDate] [DATETIME], 
		[entryName] [NVARCHAR] (250) COLLATE ARABIC_CI_AI,
		[accountGuid] [UNIQUEIDENTIFIER], 
		[accountName] [NVARCHAR] (250) COLLATE ARABIC_CI_AI,  
		[CeNotes] [NVARCHAR](250) COLLATE ARABIC_CI_AI,
		[ceCurrencyPtr]   [UNIQUEIDENTIFIER],
		[ceDate] [DATETIME],
		[custGuid]	[UNIQUEIDENTIFIER],
		[PaymentGUID] [UNIQUEIDENTIFIER]
	)
	
	DECLARE @lang INT 
	SET @lang = [dbo].[fnConnections_GetLanguage]()

	INSERT INTO [#Result]
		SELECT  
				[ce].[number] ,
				[ce].[guid],
				[en].[contraaccguid],
				CASE @lang WHEN 0 THEN [ac].[name] ELSE (CASE [ac].[Latinname] WHEN '' THEN [ac].[name] ELSE [ac].[Latinname] END) END,
				[en].[costguid],
				ISNULL(CASE @lang WHEN 0 THEN [co].[name] ELSE (CASE [co].[LatinName] WHEN '' THEN [co].[name] ELSE [co].[LatinName] END) END, ''),
				[co].[Code],
				ISNULL([en].[class], ''),
				[ce].[branch],
				ISNULL(CASE @lang WHEN 0 THEN [br].[name] ELSE (CASE [br].[LatinName] WHEN '' THEN [br].[name] ELSE [br].[LatinName] END) END, ''),
				ISNULL(CASE @lang WHEN 0 THEN [cu].[CustomerName] ELSE (CASE [cu].[LatinName] WHEN '' THEN [cu].[CustomerName] ELSE [cu].[LatinName] END) END, ''),
				([dbo].[fnCurrency_fix]([en].debit - [en].credit, [en].[Currencyguid], [en].[CurrencyVal], @CurGUID, [en].[Date])),
				([dbo].[fnCurrency_fix]((([en].[Debit] - [en].[Credit]) * [en].[AddedValue] / (100)), [en].[Currencyguid], [en].[CurrencyVal], @CurGUID, [en].[Date])),
				[ce].[postdate],
				CASE @lang WHEN 0 THEN [et].[name] ELSE (CASE [et].[LatinName] WHEN '' THEN [et].[name] ELSE [et].[LatinName] END) END + ':' + CAST (py.Number AS NVARCHAR(10)),
				[en].accountguid,
				CASE @lang WHEN 0 THEN [ac1].[name] ELSE (CASE [ac1].LatinName WHEN '' THEN [ac1].[name] ELSE [ac1].LatinName END) END,
				ISNULL([en].[notes],''),
				[ce].[currencyGuid],
				[ce].[Date],
				ISNULL([cu].[GUID], 0x0),
				py.GUID 
	FROM 
			py000 py
			INNER JOIN [et000] et ON [py].[TypeGUID] = [et].[GUID]
			INNER JOIN [#SrcEntry] SrcEntry ON [SrcEntry].[Type] = [et].[GUID] 
			INNER JOIN [er000] er ON [er].[ParentGUID] = [py].[GUID]  
			INNER JOIN [ce000] ce ON [er].[EntryGUID] = [ce].[GUID]
			INNER JOIN [en000] en ON [en].[ParentGUID] = [ce].[GUID]
			INNER JOIN [#AccTbl] AccTbl ON [AccTbl].[Number] = [en].[AccountGUID]
			INNER JOIN [ac000] ac1 ON [en].[AccountGUID] = [ac1].[GUID]
			LEFT JOIN  [br000] br ON [ce].[Branch] = [br].[GUID]
			INNER JOIN [#CostTbl] CostTbl ON [en].[CostGUID] = [CostTbl].[Number]
			Left JOIN  [co000] co  ON [co].[GUID] = [CostTbl].[Number]
			LEFT JOIN  [ac000] ac ON  [en].[contraaccguid] = [ac].[GUID]
			LEFT JOIN  [cu000] cu ON [cu].[GUID] = [en].[CustomerGUID] 

		WHERE [en].[Date] BETWEEN @StartDate AND @EndDate
			  AND [ac1].[IsUsingAddedValue] = 1
			  AND et.TaxType != 0 
			  AND (ISNULL(@CustGuid, 0x0) = 0x0 OR [en].[CustomerGUID] = @CustGuid)
	DECLARE @str NVARCHAR(2000)
	SET @str = 'SELECT R.* FROM  [#Result] AS R '

	IF(@EntryCond <> 0x0)
	BEGIN
		SET @str = @str + ' WHERE ' + dbo.fnGetEntryConditionStr('R', @EntryCond, @CurGUID)
	END
	EXEC (@str)

################################################################################
#END