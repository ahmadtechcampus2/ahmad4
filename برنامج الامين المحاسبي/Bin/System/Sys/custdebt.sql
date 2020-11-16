################################################################################
## تقرير أرصدة الزبائن
CREATE PROCEDURE repCustBalRep  
	@StartDate			[DATETIME],    
	@EndDate			[DATETIME],    
	@AccGUID			[UNIQUEIDENTIFIER],    
	@CurGUID			[UNIQUEIDENTIFIER],    
	@CurVal				[INT],    
	@Contain			[NVARCHAR](200),    
	@NotContain			[NVARCHAR](200),    
	@Type				[INT],    
	@ShowZero			[INT],    
	@MorDebit			[FLOAT],    
	@MorCredit			[FLOAT],  
	@Oper				[INT], 
	@CostGuid			[UNIQUEIDENTIFIER],  
	@bCostDetails		[BIT] = 0, 
	@CustCondGuid		[UNIQUEIDENTIFIER] = 0x0, -- New Parameter to check Customer Conditions, Notes: it was not exists 
	@withoutMaxDebitBal [BIT],
	@CustGUID			[UNIQUEIDENTIFIER]
AS
	SET NOCOUNT ON;
	DECLARE
		@SQL NVARCHAR(MAX),
		@CoCount INT,
		@UserGUID UNIQUEIDENTIFIER
	SET @UserGUID = [dbo].[fnGetCurrentUserGUID]()
	
	CREATE TABLE [#SecViol]([Type] [INT], [Cnt] [INT]) 
	CREATE TABLE [#CustTable]([cuNumber] [UNIQUEIDENTIFIER], [cuSec] [INT])
	CREATE TABLE [#BillTbl]( [Type] UNIQUEIDENTIFIER, [Security] INT, [ReadPriceSecurity] INT)
	CREATE TABLE [#EntryTbl]( [Type] UNIQUEIDENTIFIER, [Security] INT)   
	
	INSERT INTO [#BillTbl] EXEC [prcGetBillsTypesList] 0x0, @UserGUID
	INSERT INTO [#EntryTbl] EXEC [prcGetEntriesTypesList] 0x0, @UserGUID
	INSERT INTO [#EntryTbl] SELECT [Type], [Security] FROM [#BillTbl]   
	INSERT INTO [#CustTable] EXEC [prcGetCustsList] @CustGUID, @AccGUID ,@CustCondGuid 
	IF (@withoutMaxDebitBal = 1)	SET @Type = 0
	SELECT 
		a.[cuNumber],
		a.[cuSec],
		c.security [acSecurity],
		accountGuid,
		ISNULL(b.Warn, 0) [cuWarn],
		ISNULL(b.MaxDebit, 0) [cuMaxDebit],
		c.Code [acCode],
		c.Name [acName],
		c.LatinName [acLatinName],
		CurrencyGuid [acCurrencyPtr],
		CurrencyVal [acCurrencyVal],
		b.Notes [cuNotes],
		b.DefPrice,
		b.CustomerName [CustName],    
		b.LatinName  [CustLName]
	INTO
		[#CustTable2]
	FROM
		[#CustTable] a  
		INNER JOIN [cu000] b ON b.Guid = a.cuNumber
		INNER JOIN [ac000] c ON c.Guid = b.accountGuid
	WHERE
		(@Contain = '' OR [B].[Notes] LIKE '%'+ @Contain + '%')
		AND
		(@NotContain = '' OR [B].[Notes] NOT LIKE '%'+ @NotContain + '%')
		
	CREATE CLUSTERED INDEX sdafsad ON [#CustTable2](accountGuid) 
	
	DECLARE 
		@ZERO [FLOAT]    
		
	SET @ZERO = [dbo].[fnGetZeroValuePrice]()    
	  
	DECLARE @Cost_Tbl TABLE([GUID] [UNIQUEIDENTIFIER]) 
	
	INSERT INTO @Cost_Tbl
	SELECT 
		[GUID]
	FROM 
		[dbo].[fnGetCostsList](@CostGUID)
	
	SET @CoCount = @@ROWCOUNT
	
	IF ISNULL(@CostGUID, 0x0) = 0x0
		INSERT INTO @Cost_Tbl VALUES(0x0)
		
	CREATE TABLE [#Result](
		[AccPtr]		[UNIQUEIDENTIFIER], 
		[CostGUID]		[UNIQUEIDENTIFIER], 
		[Debit]			[FLOAT],   
		[Credit]		[FLOAT],   
		[AccSecurity]	[INT],   
		[CustSecurity]	[INT], 
		[ceGuid]		[UNIQUEIDENTIFIER],
		[enDate]		[DATETIME], 
		[ceNumber]		[INT],
		[Note]			[NVARCHAR](1000) COLLATE ARABIC_CI_AI,
		[Security]		[INT],
		[UserSecurity]	[INT],
		[CustGuid]		[UNIQUEIDENTIFIER])
	
	CREATE TABLE [#EndResult](
		[AccPtr]			[UNIQUEIDENTIFIER], 
		[CostGUID]			[UNIQUEIDENTIFIER], 
		[Debit]				[FLOAT],   
		[Credit]			[FLOAT],   
		[Balanc]			[FLOAT],  
		[PrevBalance]		[FLOAT],  
		[PrevBal]			[FLOAT], 
		[LastDebit]			[FLOAT], 
		[LastDebitDate]		[DATETIME],  
		[LastCredit]		[FLOAT], 
		[LastCreditDate]	[DATETIME],
		[LastPay]			[FLOAT], 
		[LastPayDate]		[DATETIME], 
		[Used]				[BIT],
		[LastDebitNote]		[NVARCHAR](1000) COLLATE ARABIC_CI_AI,
		[LastCreditNote]	[NVARCHAR](1000) COLLATE ARABIC_CI_AI,
		[CustGUID]			[UNIQUEIDENTIFIER]
		)
		
	INSERT INTO [#Result] 
	SELECT   
		[Cust].[accountGuid], 
		[vwEx].[enCostPoint], 
		SUM([vwEx].[FixedEnDebit]), 
		SUM([vwEx].[FixedEnCredit]), 	
		[acSecurity], 
		[Cust].[cuSec], 
		[vwEx].[ceGuid],  
		[vwEx].[enDate], 
		[vwEx].[ceNumber],
		[vwEx].[enNotes],
		[vwEx].[ceSecurity],
		[enSrc].[Security],
		[Cust].[cuNumber]
	FROM   
		dbo.fnCeEn_Fixed(@CurGUID ) As [vwEx]
		INNER JOIN [#CustTable2] As [Cust] ON [Cust].[cuNumber] = [vwEx].[enCustomerGUID] AND [Cust].[accountGuid] = [vwEx].[EnAccount]   
		INNER JOIN @Cost_Tbl As [Cost] ON [vwEx].[enCostPoint] = [Cost].[GUID]  
		LEFT JOIN [#EntryTbl] [enSrc] ON [vwEx].ceTypeGUID = [enSrc].[Type]
	WHERE
		[vwEx].[enDate] BETWEEN @StartDate AND @EndDate
		AND
		[vwEx].[ceIsPosted] = 1 
	GROUP BY 
		[Cust].[cuNumber],
		[Cust].[accountGuid], 
		[vwEx].[enCostPoint], 
		[acSecurity], 
		[Cust].[cuSec], 
		[vwEx].[ceGuid],  
		[vwEx].[enDate],
		[vwEx].[ceNumber],
		[vwEx].[enNotes],
		[vwEx].[ceSecurity],
		[enSrc].[Security]
		
	IF( @ShowZero = 1)  
	BEGIN  
		INSERT INTO [#Result]   
		SELECT   
			[ac].[AccountGuid],  
			0x0, 
			0,  
			0, 
			[ac].[acSecurity],  
			[ac].[cuSec],  
			0x0, 
			'01-01-1980',
			0,
			'',
			0,
			0,
			[ac].[cuNumber] 
		FROM 
			dbo.fnCeEn_Fixed(@CurGUID ) As [vwEx]
			INNER JOIN @Cost_Tbl As [Cost] ON [vwEx].[enCostPoint] = [Cost].[GUID]
			RIGHT JOIN [#CustTable2] As [ac] ON [ac].[cuNumber] = [vwEx].[enCustomerGUID] AND [ac].[accountGuid] = [vwEx].[EnAccount]
			LEFT JOIN ( SELECT DISTINCT [CustGUID], [AccPtr] FROM [#Result]) [Res] ON [Res].[CustGuid] = [ac].[cuNumber]--[Res].[AccPtr] = [AccountGuid]
		WHERE
			[Res].[AccPtr] IS NULL 
		GROUP BY 
			[ac].[cuNumber],
			[ac].[accountGuid], 
			[acSecurity], 
			[ac].[cuSec]
		HAVING
			(SUM(ISNULL([vwEx].[FixedEnDebit], 0)) - SUM(ISNULL([vwEx].[FixedEnCredit], 0))) = 0 
	END
	
	EXEC [prcCheckSecurity] @Check_AccBalanceSec = 1   
	
	INSERT INTO [#EndResult]   
		SELECT    
			[Res].[AccPtr], 
			(CASE @bCostDetails WHEN 1 THEN [Res].[CostGUID] ELSE 0x0 END), 
			SUM( [Res].[Debit]),   
			SUM( [Res].[Credit]),   
			(
			CASE [cu].[cuWarn]
				WHEN 2 THEN -( SUM( [Res].[Debit]) - SUM( [Res].[Credit]))
				ELSE SUM( [Res].[Debit]) - SUM( [Res].[Credit])
			END),  
			0,
			0,
			0,
			GETDATE(),
			0,
			GETDATE(), 
			0,
			GETDATE(),
			0 ,
			'',
			'',
			[Res].[CustGuid]
		FROM   
			[#Result] As [Res]
			INNER JOIN [#CustTable2] [cu] ON [Res].[CustGuid] = [cu].[cuNumber]--[Res].[AccPtr] = [cu].[accountGuid]
		GROUP BY
			[Res].[CustGuid],
			[Res].[AccPtr],
			(
			CASE @bCostDetails 
				WHEN 1 THEN [Res].[CostGUID] 
				ELSE 0x0 
			END),
			[cu].[cuWarn]
--------------------------------------------------------------------------------------------------------------------------------------------- 
-- this block to calaculate prev balances
--------------------------------------------------------------------------------------------------------------------------------------------- 			
		CREATE TABLE [#Prev_B_Res](  
			[AccGUID] 		[UNIQUEIDENTIFIER], 
			[CostGUID]		[UNIQUEIDENTIFIER], 
			[enDebit]		[FLOAT],   
			[enCredit]		[FLOAT],   
			[acSecurity]	[INT],
			[CustGUID]		[UNIQUEIDENTIFIER])
			
		INSERT INTO [#Prev_B_Res]
		SELECT      
			[CE].[enAccount],
			[CE].[enCostPoint],
			SUM([CE].[FixedEnDebit]),
			SUM([CE].[FixedEnCredit]),
			[Cust].[acSecurity],
			[Cust].[cuNumber]
		FROM  
			dbo.fnCeEn_Fixed(@CurGUID) As [CE]
			INNER JOIN [#CustTable2] As [Cust] ON [Cust].[cuNumber] = [CE].[enCustomerGUID] AND [Cust].[accountGuid] = [CE].[EnAccount]       
			INNER JOIN @Cost_Tbl As [Cost] ON [CE].[enCostPoint] = [Cost].[GUID]  
		WHERE      
			[CE].[enDate] < @StartDate  
			AND [CE].[ceIsPosted] = 1  
		GROUP BY  
			[Cust].[cuNumber],
			[CE].[enAccount], 
			[CE].[enCostPoint], 
			[Cust].[acSecurity]
		--------------------------------------------------   
		EXEC [prcCheckSecurity] @result = '#Prev_B_Res'  , @Check_AccBalanceSec = 1
		--------------------------------------------------   
		DECLARE @Prev_Balance TABLE(
			[AccGUID] 	[UNIQUEIDENTIFIER],    
			[CostGUID]	[UNIQUEIDENTIFIER],			 
			[enDebit]	[FLOAT],   
			[enCredit]	[FLOAT],
			[CustGUID]	[UNIQUEIDENTIFIER])      
			    
		INSERT INTO @Prev_Balance    
		SELECT
			[AccGUID], 
			(
			CASE @bCostDetails 
				WHEN 1 THEN [CostGUID] 
				ELSE 0X0 
			END),
			SUM([enDebit]),
			SUM([enCredit]),
			[CustGUID]
		FROM
			[#Prev_B_Res]
		GROUP BY
			[CustGUID],
			[AccGUID],
			(
			CASE @bCostDetails 
				WHEN 1 THEN [CostGUID] 
				ELSE 0x0 
			END)
		    
		-----------------------------------------------------------------      
		UPDATE [Balanc]  
		SET 	 
			[PrevBalance] = [PrevBal].[enDebit] - [PrevBal].[enCredit],  
			[PrevBal] = (CASE [Cust].[cuWarn]  
							WHEN 2 THEN -( [PrevBal].[enDebit]- [PrevBal].[enCredit])   
							ELSE  [PrevBal].[enDebit] - [PrevBal].[enCredit]   
						END)  
		FROM  
			[#EndResult] AS [Balanc]   
			INNER JOIN @Prev_Balance AS [PrevBal] ON [Balanc].[CustGUID] = [PrevBal].[CustGUID] AND [Balanc].[CostGUID] = [PrevBal].[CostGUID] 
			INNER JOIN [#CustTable2] As [Cust] ON [Cust].[cuNumber] = [Balanc].[CustGUID]       
--------------------------------------------------------------------------------------------------------------------------------------------- 
-- this block instead of [prcGetLastPCD] (تعمل نفس العمل) 
--------------------------------------------------------------------------------------------------------------------------------------------- 
		UPDATE [e]
		SET [LastPay] = ISNULL((SELECT TOP 1 [Credit] 
								FROM [#Result] AS  [en] 
								INNER JOIN [Er000] AS [er] ON [en].[ceGuid] = [er].[EntryGuid] 
								INNER JOIN [vwPy] AS [py] ON [er].[ParentGuid] = [py].[pyGuid] 
								WHERE [CustGuid] = [e].[CustGUID]/*[AccPtr] = [e].[AccPtr]*/ AND [Credit] > 0 
								ORDER BY [enDate] DESC,[ceNumber] DESC),0),
		[LastPayDate] = ISNULL((SELECT TOP 1 [enDate] 
								FROM [#Result] AS  [en] 
								INNER JOIN [Er000] AS [er] ON [en].[ceGuid] = [er].[EntryGuid] 
								INNER JOIN [vwPy] AS [py] ON [er].[ParentGuid] = [py].[pyGuid] 
								WHERE  [CustGuid] = [e].[CustGUID]/*[AccPtr] = [e].[AccPtr]*/ AND [Credit] > 0 
								ORDER BY [enDate] DESC),'1/1/1980')	  	  
		FROM  [#EndResult] AS [e] 
		
		UPDATE [e]  
		SET [LastDebit] = ISNULL((SELECT TOP 1 [Debit] 
									FROM [#Result]
									WHERE  [CustGuid] = [e].[CustGUID]/*[AccPtr] = [e].[AccPtr]*/ AND [Debit] > 0 
									ORDER BY [enDate] DESC,[ceNumber] DESC),0), 
		[LastDebitDate] = ISNULL((SELECT TOP 1 [enDate] 
									FROM [#Result] 
									WHERE  [CustGuid] = [e].[CustGUID]/*[AccPtr] = [e].[AccPtr]*/ AND [Debit] > 0 
									ORDER BY [enDate] DESC),'1/1/1980')	   
		FROM  [#EndResult] AS [e] 
		
		UPDATE [e]  
		SET [LastCredit] = ISNULL((SELECT TOP 1 [Credit] 
									FROM [#Result] 
									WHERE  [CustGuid] = [e].[CustGUID]/*[AccPtr] = [e].[AccPtr]*/ AND [Credit] > 0 
									ORDER BY [enDate] DESC,[ceNumber] DESC),0), 
		[LastCreditDate] = ISNULL((SELECT TOP 1 [enDate] 
									FROM [#Result] 
									WHERE  [CustGuid] = [e].[CustGUID]/*[AccPtr] = [e].[AccPtr]*/ AND [Credit] > 0 
									ORDER BY [enDate] DESC),'1/1/1980')	  	  
		FROM  [#EndResult] AS [e] 
		
		UPDATE [e]  
		SET [LastDebitNote] = ISNULL((SELECT TOP 1 Note 
										FROM [#Result] 
										WHERE  [CustGuid] = [e].[CustGUID]/*[AccPtr] = [e].[AccPtr]*/ and Debit > 0 
										ORDER BY [enDate] DESC,[ceNumber] DESC), '')
		FROM  [#EndResult] AS [e] 
		
		UPDATE [e]  
		SET [LastCreditNote] = ISNULL((SELECT TOP 1 Note 
										FROM [#Result] 
										WHERE  [CustGuid] = [e].[CustGUID]/*[AccPtr] = [e].[AccPtr]*/ and Credit > 0 
										ORDER BY [enDate] DESC,[ceNumber] DESC), '')
		FROM  [#EndResult] AS [e] 
	
		SET @Sql = '	
		SELECT
			[Cust].[accountGUID] As [AccPtr],
			[Cust].[acCode] As [AccCode],
			[Cust].[acName] As [AccName],
			[Cust].[acLatinName] As [AccLName], 
			[co].[coGUID] As [coGUID],  
			(CASE [co].[coCode] WHEN '''' THEN '''' ELSE [co].[coCode] + ''-'' END) +  
			(CASE [dbo].[fnConnections_GetLanguage]() WHEN 0 THEN [co].[coName] ELSE (CASE [co].[coLatinName] WHEN '''' THEN [co].[coName] ELSE [co].[coLatinName] END) END) AS [coCodeName], 
			[Cust].[cuNumber] As [CustPtr],
			[Cust].[CustName] As [CuName],    
			[Cust].[CustLName] As [CustLName],    
			[Cust].[DefPrice] As [CuDefPrice],
			ISNULL([dbo].[fnCurrency_fix]( [Cust].[cuMaxDebit], [Cust].[acCurrencyPtr], [Cust].[acCurrencyVal], ''' + CAST(@CurGUID AS NVARCHAR(36))+ ''',' + dbo.fnDateString(@endDate) +'), 0) As [CuMaxDebit],
			[Cust].[cuWarn] As [CuWarn],    
			ISNULL([Res].[Debit], 0) As [SumDebit],    
			ISNULL([Res].[Credit], 0) As [SumCredit], 
			ISNULL( [Res].[PrevBalance], 0) As [PrevBalance],  
			[Res].[LastDebit] AS [LastDebit], 
			[Res].[LastDebitDate] AS [LastDebitDate],  
			[Res].[LastCredit] AS [LastCredit], 
			[Res].[LastCreditDate] AS [LastCreditDate],  
			[Res].[LastPay] AS [LastPay], 
			[Res].[LastPayDate] AS [LastPayDate],
			[Res].[LastDebitNote] AS [LastDebitNote],
			[Res].[LastCreditNote] AS [LastCreditNote]
		FROM      
			[#CustTable2] As [Cust] 
			INNER JOIN [#EndResult] As [Res] ON [Res].[CustGuid] = [Cust].[cuNumber] '
------------------------------------------------------------------------------------------------------- 
	DECLARE @CharOper AS NVARCHAR(3)
	BEGIN
		IF @Oper = 0
			SET @CharOper = '> '
		ELSE IF @Oper = 1
				SET @CharOper = '< '
			Else
				SET @CharOper = '= '
	END
	
		SET @Sql = @Sql + ' INNER JOIN ( SELECT [coGUID], [coCode], [coName], [coLatinName] FROM [vwCo] UNION ALL SELECT 0x0, '''', '''', '''') AS [co] ON [co].[coGUID] = [Res].[CostGUID]' 
	 
		 
	IF @type = 0 AND @ShowZero = 0 
		SET @Sql = @Sql + ' WHERE     ABS( [Res].[Debit] -  [Res].[Credit] )  >' + CAST(@ZERO AS NVARCHAR(15)) 
	ELSE IF	@type = 1 
	BEGIN 
		SET @Sql = @Sql + 'WHERE ([Res].[Credit] - [Res].[Debit]) < 0 ' 
		IF @ShowZero = 0 
			SET @Sql = @Sql + 'AND ABS( [Res].[Credit] - [Res].[Debit]) > ' + CAST(@ZERO AS NVARCHAR(15)) 
 	END 
	ELSE IF	@type = 2 
	BEGIN 
		SET @Sql = @Sql + 'WHERE ([Res].[Debit] - [Res].[Credit]) < 0 ' 
		IF @ShowZero = 0 
			SET @Sql = @Sql + 'AND ABS( [Res].[Debit] - [Res].[Credit]) >' + CAST(@ZERO AS NVARCHAR(15)) 
	END 
	ELSE IF	@type = 3		 
		SET @Sql = @Sql + ' WHERE [Cust].[cuWarn] <> 0 AND [dbo].[fnCurrency_fix]( [Cust].[cuMaxDebit], [Cust].[acCurrencyPtr], [Cust].[acCurrencyVal], ''' + CAST(@CurGUID AS NVARCHAR(36)) +''' , ' + dbo.fnDateString(@endDate) + ') < ([Res].[Balanc]+ [Res].[PrevBal]) '  
	ELSE IF	@type = 4 
	BEGIN	 
		SET @Sql = @Sql + 'WHERE ([Res].[Debit] - [Res].[Credit]) ' + @CharOper + CAST( @MorDebit AS NVARCHAR(15)) + ' AND [Res].[Debit] > [Res].[Credit]'
		IF @ShowZero = 0 
			SET @Sql = @Sql + 'AND ABS( [Res].[Debit] - [Res].[Credit]) >' + CAST(@ZERO AS NVARCHAR(15))   
	END 
	ELSE IF	@type = 5 
	BEGIN	 
		SET @Sql = @Sql + 'WHERE  ([Res].[Credit] - [Res].[Debit]) ' + @CharOper + CAST (@MorCredit AS NVARCHAR(15)) + ' AND [Res].[Credit] > [Res].[Debit]'
		IF @ShowZero = 0 
			SET @Sql = @Sql + 'AND ABS( [Res].[Debit] - [Res].[Credit]) >' + CAST(@ZERO AS NVARCHAR(15))   
	END
	IF @withoutMaxDebitBal = 1  
			SET @Sql = @Sql + ' AND ([dbo].[fnCurrency_fix]( [Cust].[cuMaxDebit], [Cust].[acCurrencyPtr], [Cust].[acCurrencyVal], ''' + CAST(@CurGUID AS NVARCHAR(36))+ ''',' + dbo.fnDateString(@endDate) +')  = 0) ' 
						 
	EXEC (@SQL) 
	SELECT * FROM [#SecViol] 
/* 
prcConnections_Add2 'مدير' 
[repCustBalRep] '1/1/2008 0:0:0.0', '5/1/2008 23:59:59.998', '00000000-0000-0000-0000-000000000000', 'b991bfc8-5c90-4555-9ab6-86bb1420f3eb', 1.000000, '', '', 0, 0, 0.000000, 0.000000, '00000000-0000-0000-0000-000000000000', 0, 1, 0, 1, 13, 0, '00000000-0000-0000-0000-000000000000', '' 
*/ 

################################################################################
#END
