###############################################################################
##  ﬁ—Ì— «·Õ”«»«  «·„ÿ«»ﬁ…
## exec repMatchAcc '1-1-2002','12-12-2002',3,0,1,1,1
##
##	1 = Account Checked Date Between Start And End Date
##	2 = Account Checked Date Not Between Start And End Date
##
CREATE PROCEDURE repMatchAcc
	@StartDate	[DATETIME],  
	@EndDate	[DATETIME],  
	@AccGUID	[UNIQUEIDENTIFIER] ,  
	@CurGUID	[UNIQUEIDENTIFIER] ,  
	@CurVal		[INT],  
	@Type		[INT],
	@ShowBalAcc [INT] = 1,
	@CustCondGuid		[UNIQUEIDENTIFIER],
	@CustGUID	[UNIQUEIDENTIFIER]
AS  
	SET NOCOUNT ON 
	CREATE TABLE [#SecViol]([Type] [INT], [Cnt] [INT])
	CREATE TABLE [#acc]([GUID] [UNIQUEIDENTIFIER], [Level] [INT] DEFAULT 0, [Path] [VARCHAR](8000) COLLATE ARABIC_CI_AI)
	CREATE TABLE [#CustTbl]( [CustGuid] [UNIQUEIDENTIFIER], [Security] [INT], [CustAccGuid] [UNIQUEIDENTIFIER])   
	CREATE TABLE [#chkAcc]([AccGUID] [UNIQUEIDENTIFIER], [chDate] DATETIME, [CustGuid] [UNIQUEIDENTIFIER])
	CREATE TABLE [#IdBal]([RBal] FLOAT, [accountGuid] [UNIQUEIDENTIFIER], [customerGuid] [UNIQUEIDENTIFIER])
    
	CREATE TABLE [#Result](  
		[AccPtr]  		[UNIQUEIDENTIFIER],   
		[CustPtr] 		[UNIQUEIDENTIFIER],   
		[Debit]			[FLOAT], 
		[Credit]		[FLOAT], 
		[AccSecurity] 	[INT], 
		[CustSecurity] 	[INT],
		[chkDate]		[DATETIME],
		[BalChkDate]	[FLOAT],
		[Identity]		[INT] DEFAULT 1,
		[UserName]		[NVARCHAR](256) COLLATE ARABIC_CI_AI,
		[Note]			[NVARCHAR](256) COLLATE ARABIC_CI_AI
		 )
	CREATE TABLE [#chk2]
		(
			[AccGUID]	[UNIQUEIDENTIFIER],   
			[Bal]		[FLOAT], 
			[CurBal]	[FLOAT],
			[UserGuid]  	[UNIQUEIDENTIFIER],
			[UserName]	[NVARCHAR](256) COLLATE ARABIC_CI_AI,
			[Note]		[NVARCHAR](256) COLLATE ARABIC_CI_AI,
			[Identity]	[INT] DEFAULT 1,
			[chkDate]	[DATETIME],
			[CustGUID]	[UNIQUEIDENTIFIER]
		)
	--
	INSERT INTO [#CustTbl] ( [CustGuid], [Security]) EXEC [prcGetCustsList] 	@CustGUID, @AccGUID, @CustCondGuid 
	UPDATE ct SET ct.[CustAccGuid] = cu.[cuAccount] from [vwcu] cu inner join [#CustTbl] ct on ct.[CustGuid] = cu.[cuGuid]
	--
	INSERT INTO [#acc] SELECT * FROM [dbo].[fnGetAccountsList]( @AccGUID , DEFAULT) [fn]
	IF @CustCondGuid <> 0X00
		DELETE [A] FROM [#acc] A
		LEFT JOIN [#CustTbl] [cu] ON [A].[Guid] = [cu].[CustAccGuid]
		WHERE [cu].[CustAccGuid] IS NULL
	
	IF (@CustGUID = 0x0)
		INSERT INTO [#CustTbl] SELECT 0x0, 0, [a].[Guid] FROM [#acc] [a] WHERE [a].[GUID] NOT IN (SELECT [CustAccGuid] FROM [#CustTbl])
	
	CREATE INDEX [accIn] ON [#acc]([GUID])
	---Mach AccTable
	INSERT INTO [#chkAcc]
	SELECT [AccGUID],MAX([CheckedToDate]) AS [chDate], ISNULL([Ac].[CustGUID], 0x0) 
	  FROM [dbo].[CheckAcc000] AS [Ac] 
		   INNER JOIN [#acc] AS [fnAc] ON [fnAc].[Guid] = [Ac].[AccGUID] 
		   INNER JOIN [#CustTbl] [cu] ON [cu].[CustAccGuid] = [fnAc].[Guid] AND [cu].[CustGuid] = [Ac].[CustGUID] 
	 WHERE [CheckedToDate] BETWEEN  @StartDate  AND @EndDate
	 GROUP BY [AccGUID], [Ac].[CustGUID] 
	
	--CREATE CLUSTERED INDEX [machaccchkind] ON  ([#chkAcc] 
	INSERT INTO  [#Result] ([AccPtr],[CustPtr],[Debit],[Credit],[AccSecurity],[CustSecurity],[chkDate])
		SELECT  
			[ac].[Guid] ,  
			ISNULL([cu].[CustGuid], 0x0) , 
			ISNULL(SUM(FixedEnDebit),0),
			ISNULL(SUM(FixedEnCredit),0), 
			[ac].[Security], 
			ISNULL([cu].[Security], 0),
			ISNULL([chDate],'1/1/1980')
		FROM  
			(([ac000] AS [AC] 
			INNER JOIN  [#acc] AS [fnAc] ON [fnAc].[Guid] = [Ac].[Guid]
			INNER JOIN [#CustTbl] [cu] ON [cu].[CustAccGuid] = [fnAc].[Guid]  
			LEFT JOIN [fnCeEn_fixed](@CurGUID) AS [en] ON [en].[enAccount] = [Ac].[Guid]))
			LEFT JOIN [#chkAcc] AS [chk] ON [chk].[AccGUID] =  [Ac].[Guid] AND [chk].[CustGuid] = [cu].[CustGuid]
		WHERE  
			(  
				( @Type = 1 AND ([chk].[AccGUID] IS NOT NULL )) 
				OR( @Type = 2 AND ([chk].[AccGUID] IS NULL  ))  
			)  
			AND  [Ac].[Type] <> 2 AND  [Ac].[NSons] = 0 
		GROUP BY 
			[ac].[Guid],  
			ISNULL([cu].[CustGuid], 0x0), 
			[ac].[Security], 
			ISNULL([cu].[Security], 0),
			ISNULL([chDate],'1/1/1980')
	IF (@Type = 1)
	BEGIN
		INSERT  INTO [#chk2] 
			SELECT [acCh].[AccGUID],[Debit]-[Credit],[dbo].[fnCurrency_fix]([Debit]-[Credit],[CurrencyGUID],[CurrencyVal], @CurGUID,[CheckedToDate]),[UserGUID],'',[Notes],1,[acCh].[CheckedToDate], [acCh].[CustGUID] 
			FROM [CheckAcc000] AS [acCh] INNER JOIN [#chkAcc] AS [chk] ON [acCh].[AccGUID] = [chk].[AccGUID] AND  [acCh].[CheckedToDate] = [chk].[chDate] AND [acCh].[CustGUID] = [chk].[CustGuid]
				INSERT INTO [#IdBal]
				SELECT 
						sum([e].[debit]) - sum([e].[credit]) AS [RBal],
						[e].[AccountGUID],
						[e].[CustomerGUID]
				FROM [en000] [e] 
				INNER JOIN [ce000] [c] on [e].[parentGuid] = [c].[guid] 
				INNER JOIN [#chk2] AS [ch] ON [e].[accountGuid] = [ch].[AccGUID] AND [e].[CustomerGUID] = [ch].[CustGUID]
				WHERE [c].[isPosted] <> 0 AND [e].[Date] <= [chkDate] 
				GROUP BY [e].[accountGuid], [e].[CustomerGUID]
				UPDATE [ch] SET [Identity] = 0 FROM [#chk2] AS [ch] INNER JOIN  [#IdBal] AS [id] ON [ID].[accountGuid] = [ch].[AccGUID] AND [id].[customerGuid] = [ch].[CustGUID]
				WHERE [ch].[Bal] <> [id].[RBal]

				UPDATE [ch] SET [UserName] = [LogInName] FROM [#chk2] AS [ch] INNER JOIN [us000] AS [us] ON [us].[Guid] = [ch].[UserGuid]

			UPDATE [r] SET [BalChkDate] = [CurBal],[Identity] = [ch].[Identity],[UserName] = [ch].[UserName],[Note] = [ch].[Note]
			FROM [#Result] AS [r] INNER JOIN [#chk2] AS [ch] ON [r].[AccPtr] = [ch].[AccGUID] AND [r].[CustPtr] = [ch].[CustGUID]
	END	
	-------------------------------------------------------------- 
	EXEC [prcCheckSecurity] @Check_AccBalanceSec = 1 
	--------------------------------------------------------------	 
	SELECT  
		[ac].[acGuid] AS [AccPtr],  
		[ac].[acCode] AS [AccCode],  
		[ac].[acName] AS [AccName],  
		[ac].[acLatinName] AS [AccLName], 
		[Res].[chkDate] AS [CheckDate], 
		ISNULL( [Cu].[cuNumber], 0) AS [CustPtr], 
		ISNULL( [Cu].[cuGuid], 0x0) AS [CustGuid], 

		CASE [ac].[acWarn]  
			WHEN 2 THEN -[Res].[Debit] - [Res].[Credit] 
			ELSE [Res].[Debit] - [Res].[Credit] 
		END AS [Balanc],
		[Res].[BalChkDate],
		[Res].[Identity],
		[Res].[UserName],
		[Res].[Note],
		CASE [dbo].[fnConnections_getLanguage]() WHEN 0 THEN [Cu].[cuCustomerName] ELSE CASE ISNULL([Cu].[cuLatinName], '') WHEN '' THEN [Cu].[cuCustomerName] ELSE [Cu].[cuLatinName] END END AS [CustName]	 
	FROM 
		[#Result] AS [Res] INNER JOIN [VWAC] AS [AC] 
		ON [Res].[AccPtr] = [Ac].[acGuid] 
		LEFT JOIN [VWCu] AS [Cu] 
		ON [ac].[acGuid] = [Cu].[cuAccount] AND [Res].[CustPtr] = [Cu].[cuGUID]
	WHERE ((@ShowBalAcc = 1) OR ABS(CASE [ac].[acWarn]  
			WHEN 2 THEN -[Res].[Debit] - [Res].[Credit] 
			ELSE [Res].[Debit] - [Res].[Credit] 
		END) > [dbo].[fnGetZeroValuePrice]())
###############################################################################
#END