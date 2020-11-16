################################################################################
CREATE PROCEDURE repCashContraMovement
	@AccGuid			UNIQUEIDENTIFIER = 0x0,
	@ContraAccGuid		UNIQUEIDENTIFIER = 0x0,
	@StartDate 			DATETIME,  
	@EndDate 			DATETIME,
	@CurPtr				UNIQUEIDENTIFIER = 0x0,     
	@CostGUID 			UNIQUEIDENTIFIER = 0x0, -- 0 all costs so don't Check cost or list of costs  	
	@MaxLevel			INT = 0,
	@Posted				INT = -1,
	@ShowMainAcc        BIT = 0,
	@ShowSubAcc			BIT = 1,
	@IncludeEmpty		BIT = 1
AS
	SET NOCOUNT ON

	CREATE TABLE [#CostTbl]( [CostGUID] UNIQUEIDENTIFIER, [Security] INT)
	CREATE TABLE [#AccTbl]( [Guid] [UNIQUEIDENTIFIER], [Lvl] [INT], [Path] NVARCHAR(2000))  
	CREATE TABLE [#ContraAccTbl]( [Guid] [UNIQUEIDENTIFIER], [Lvl] [INT], Path NVARCHAR(2000))  

	INSERT INTO [#CostTbl]	EXEC [prcGetCostsList] 	@CostGUID 
	IF @CostGUID = 0x0
		INSERT INTO [#CostTbl] VALUES(0x0, 0) 

	INSERT INTO [#AccTbl] SELECT * FROM dbo.fnGetAccountsList(@AccGuid, 1)
	IF @AccGuid = 0x0
		INSERT INTO [#AccTbl] (GUID, Lvl) VALUES (0x0, 0)

	INSERT INTO [#ContraAccTbl] SELECT * FROM dbo.fnGetAccountsList(@ContraAccGuid, 1)
	IF @ContraAccGuid = 0x0
		INSERT INTO [#ContraAccTbl] (GUID, Lvl) VALUES (0x0, 0)

	CREATE TABLE [#RESULT]
	(
		[CashAccount]						UNIQUEIDENTIFIER,
		[CashParentGuid]					UNIQUEIDENTIFIER,
		[CashAccountName]					NVARCHAR(225) COLLATE ARABIC_CI_AI,
		[CashAccountCurrencyGUID]			UNIQUEIDENTIFIER,
		[CashAccountCurrencyName]			NVARCHAR(225) COLLATE ARABIC_CI_AI,
		[CashAccountCurrencyLatinName]		NVARCHAR(225) COLLATE ARABIC_CI_AI,
		[CashAccountCurrencyValue]			FLOAT,
		[ContraAccount]						UNIQUEIDENTIFIER,
		[ContraAccountName]					NVARCHAR(225) COLLATE ARABIC_CI_AI,
		[ContraParentGuid]					UNIQUEIDENTIFIER,
		[ContraParentName]					NVARCHAR(225) COLLATE ARABIC_CI_AI,
		[ContraAccountCurrencyGUID]			UNIQUEIDENTIFIER,
		[ContraAccountCurrencyName]			NVARCHAR(225) COLLATE ARABIC_CI_AI,
		[ContraAccountCurrencyLatinName]	NVARCHAR(225) COLLATE ARABIC_CI_AI,
		[ContraAccountCurrencyValue]		FLOAT,
		[OpeningBalance]					FLOAT,-- «·—’Ìœ «·«›  «ÕÌ
		[OpeningBalanceRatio]				FLOAT,
		[OpeningBalanceInAccountCurrency]	FLOAT,
		[Receives]							FLOAT,-- «·„ﬁ»Ê÷« 
		[ReceivesRatio]						FLOAT,
		[ReceivesInAccountCurrency]			FLOAT,
		[Payments]							FLOAT,-- «·„œ›Ê⁄« 
		[PaymentsRatio]						FLOAT,
		[PaymentsInAccountCurrency]			FLOAT,
		[MovementBalance]					FLOAT,-- —’Ìœ «·Õ—ﬂ…
		[MovementBalanceRatio]				FLOAT,
		[MovementBalanceInAccountCurrency]	FLOAT,
		[ClosingBalance]					FLOAT, -- «·—’Ìœ «·Œ «„Ì
		[ClosingBalanceRatio]				FLOAT,
		[ClosingBalanceInAccountCurrency]	FLOAT,
		[CurrentBalance]					FLOAT, --«·—’Ìœ «·Õ«·Ì
		[CurrentBalanceInAccountCurrency]	FLOAT,
		[Level]								INT,
		[Path]								NVARCHAR(225) COLLATE ARABIC_CI_AI,
		[Nsons]								INT,
		[Type]								INT,
		[IsEmpty]							BIT
	)
	-----------------------------------------------------------------------------------
	----------------- ≈œŒ«· Õ”«» «·‰ﬁœÌ…
	INSERT INTO #RESULT (	[CashAccount], 
							[CashAccountName], 
							[CashAccountCurrencyGUID], 
							[CashAccountCurrencyName], 
							[CashAccountCurrencyLatinName], 
							[CashAccountCurrencyValue],
							[CashParentGuid], 
							[Level], 
							[Path], 
							[Nsons], 
							[Type],
							[IsEmpty],
							[ContraAccount],
							[ContraAccountName],
							[ContraParentGuid],
							[ContraParentName],
							[OpeningBalance],
							[OpeningBalanceRatio],
							[OpeningBalanceInAccountCurrency],
							[Receives],
							[ReceivesRatio],
							[ReceivesInAccountCurrency],
							[Payments],
							[PaymentsRatio],
							[PaymentsInAccountCurrency],
							[MovementBalance],
							[MovementBalanceRatio],
							[MovementBalanceInAccountCurrency],
							[ClosingBalance],
							[ClosingBalanceRatio],
							[ClosingBalanceInAccountCurrency],
							[CurrentBalance],
							[CurrentBalanceInAccountCurrency])
	SELECT		
				[AC].[GUID], 
				[AC].Name, 
				[AC].[CurrencyGUID], 
				my.[Name], 
				my.[LatinName],
				AC.[CurrencyVal], 
				[AC].ParentGUID, 
				[FAC].Lvl, 
				[FAC].[Path], 
				[AC].NSons, 
				1,
				0,
				0x0,
				N'',
				0x0,
				N'',
				0,
				0,
				0,
				0,
				0,
				0,
				0,
				0,
				0,
				0,
				0,
				0,
				0,
				0,
				0,
				0,
				0
	FROM 
		#AccTbl [FAC] 
		INNER JOIN ac000 AS [AC] ON [AC].[GUID] = [FAC].[GUID] 
		INNER JOIN my000 AS my ON AC.CurrencyGUID = my.[GUID]
	WHERE 
		AC.[Type] <> 4

	---------------------------------------------------------------------------------
	-------------------Õ”«» «·√—’œ… «·≈›  «ÕÌ… ·Õ”«»«  «·‰ﬁœÌ…
	-- ≈Õ÷«— ﬁÌ„…  «—ÌŒ √Ê· «·„œ…
	-- ≈Õ÷«— ‰„ÿ «·”‰œ «·«›  «ÕÌ ﬂ„« ÂÊ „⁄—› ›Ì  Œ’«∆’ «·ﬁÊ«∆„ «·„«·Ì…
	-- ≈Õ÷«— »Ì«‰«  √Ê· ﬁÌœ „‰ «·‰„ÿ «·—«Ã⁄ Ê» «—ÌŒ √Ê· «·„œ… Ê ﬂÊ‰ ÂÌ «·√—’œ… «·«›  «ÕÌ…
	-- ≈Õ÷«— —’Ìœ «·Õ—ﬂ… ﬁ»·  «—ÌŒ »œ«Ì… «·› —… ÊÃ„⁄Â „⁄ «·—’Ìœ «·≈›  «ÕÌ
	DECLARE @PeriodStartDate DATE
	SET @PeriodStartDate = (SELECT CONVERT(DATETIME, [Value]) FROM op000 WHERE [Name] ='AmnCfg_FPDate')
	DECLARE @OpeningEntryType UNIQUEIDENTIFIER   
	SET @OpeningEntryType = (SELECT [Value] FROM op000 WHERE [Name] ='FSCfg_OpeningEntryType')
	UPDATE #RESULT SET	[OpeningBalance] = G.[OpeningBalance],
						[OpeningBalanceRatio] = G.[OpeningBalance], -- to avoid keeping it NULL
						[OpeningBalanceInAccountCurrency] = CASE WHEN G.acCurrencyVal <> 0 THEN G.[OpeningBalance] / G.acCurrencyVal ELSE 0 END
	FROM
		(
		SELECT 
			[AC].[GUID] AccountGuid, 
			SUM(ISNULL(EN.enDebit, 0) - ISNULL(EN.enCredit, 0)) OpeningBalance, 
			vAc.acCurrencyVal AS acCurrencyVal
		FROM 
			#AccTbl [AC] 
			INNER JOIN vwAc vAc ON AC.[GUID] = vAc.[acGUID]
			LEFT JOIN vwCeEn [EN] ON [EN].enAccount = [AC].[GUID]
		WHERE 
			[EN].enDate = @PeriodStartDate

			AND
			@OpeningEntryType = [EN].ceTypeGUID
		GROUP BY 
			[AC].[GUID], 
			vAc.acCurrencyVal
		) AS G
	WHERE #RESULT.[CashAccount] = G.AccountGuid

	UPDATE #RESULT SET	[OpeningBalance] = ISNULL([OpeningBalance], 0) + ISNULL(G1.BalanceBeforeStartDate, 0), 
						[OpeningBalanceInAccountCurrency] = CASE WHEN G1.acCurrencyVal <> 0 THEN (ISNULL([OpeningBalance], 0) + ISNULL(G1.BalanceBeforeStartDate, 0)) / G1.acCurrencyVal ELSE 0 END
	FROM
		(
		SELECT 
			[AC].[GUID] AccountGuid,
			SUM(ISNULL(En.enDebit, 0) - ISNULL(En.enCredit, 0)) BalanceBeforeStartDate,
			vAc.acCurrencyVal AS acCurrencyVal
		FROM 
			#AccTbl [AC] 
			INNER JOIN vwAc vAc ON AC.[GUID] = vAc.[acGUID]
			LEFT JOIN vwCeEn [EN] ON [EN].enAccount = [AC].[GUID]
		WHERE 
			([EN].enDate < @StartDate)
			AND 
			(@Posted = -1 OR [EN].[ceIsPosted] = @Posted)
			AND
			[EN].ceTypeGUID <> @OpeningEntryType
		GROUP BY 
			[AC].[GUID],
			vAc.acCurrencyVal
		) AS G1
	WHERE #RESULT.[CashAccount] = G1.AccountGuid

	----------------------------------------------------------------------------------
	------------------- Õ”«» «·—’Ìœ «·Õ«·Ì ·Õ”«»«  «·‰ﬁœÌ…
	UPDATE #RESULT SET	[CurrentBalance] = G.[CurrentBalance],
						[CurrentBalanceInAccountCurrency] = CASE WHEN acCurrencyVal <> 0 THEN G.CurrentBalance / acCurrencyVal ELSE 0 END
	FROM
		(
		SELECT 
			[AC].[GUID] AccountGuid, 
			SUM(ISNULL(EN.enDebit, 0) - ISNULL(EN.enCredit, 0)) [CurrentBalance], 
			vAc.acCurrencyVal AS acCurrencyVal
		FROM 
			#AccTbl [AC] 
			INNER JOIN vwAc vAc ON AC.[GUID] = vAc.[acGUID]
			LEFT JOIN vwCeEn [EN] ON [EN].enAccount = [AC].[GUID]
		WHERE 
			([EN].enDate <= @EndDate)
			AND (@Posted = -1 OR [EN].[ceIsPosted] = @Posted)
		GROUP BY [AC].[GUID], vAc.acCurrencyVal) AS G
	WHERE #RESULT.[CashAccount] = G.AccountGuid
	-----------------------------------------------------------------------------------
	-------------------- ≈œŒ«· «·Õ”«»«  «·„ﬁ«»·… ·Õ”«»«  «·‰ﬁœÌ…
	INSERT INTO #RESULT (
						[CashAccount], 
						[ContraAccount], 
						[ContraAccountName], 
						[ContraParentGuid], 
						[ContraParentName],
						[ContraAccountCurrencyGUID],
						[ContraAccountCurrencyName],
						[ContraAccountCurrencyLatinName],
						[ContraAccountCurrencyValue],
						[Nsons], 
						[Level], 
						[Type])
	SELECT DISTINCT 
		[CONAC].[GUID], 
		[AC].[GUID], 
		[AC].Name, 
		[AC].ParentGUID, 
		[PAC].Name, 
		my.[GUID],
		my.[Name],
		my.[LatinName],
		AC.[CurrencyVal],
		[AC].NSons, 
		[FAC].Lvl, 
		2
	FROM 
		#ContraAccTbl [FAC] 
		INNER JOIN ac000 AS [AC] ON [AC].[GUID] = [FAC].[GUID]
		LEFT JOIN ac000 [PAC] ON [AC].ParentGUID = [PAC].[GUID]
		INNER JOIN en000 [EN] ON EN.AccountGUID = [FAC].[GUID]
		INNER JOIN [#CostTbl] [CO] ON [CO].[CostGUID] = [EN].CostGUID
		INNER JOIN #AccTbl [CONAC] ON EN.ContraAccGUID = [CONAC].[GUID]
		INNER JOIN my000 my ON [AC].CurrencyGUID = my.[GUID]
	-------------------------------------------------------------------------------------
	--------------------- Õ”«» √—’œ… Õ—ﬂ«  «·Õ”«»«  «·„ﬁ«»·…
	UPDATE #RESULT SET	[Receives] = G.Credit, [Payments] = G.Debit,
						[ReceivesRatio] = G.Credit, [PaymentsRatio] = G.Debit,
						[ReceivesInAccountCurrency] = CASE WHEN G.acCurrencyVal <> 0 THEN G.Credit / ISNULL(acCurrencyVal, 1) ELSE 0 END, 
						[PaymentsInAccountCurrency] = CASE WHEN G.acCurrencyVal <> 0 THEN G.Debit /  ISNULL(acCurrencyVal, 1) ELSE 0 END,
						[MovementBalance] = G.Credit - G.Debit, [MovementBalanceRatio] = G.Credit - G.Debit,
						[MovementBalanceInAccountCurrency] = CASE WHEN G.acCurrencyVal <> 0 THEN (G.Credit - G.Debit) /  ISNULL(acCurrencyVal, 1) ELSE 0 END
	FROM
		(SELECT 
			[AC].[GUID] AccountGuid, 
			EN.enContraAcc, 
			SUM(ISNULL(EN.enDebit, 0)) Debit, 
			SUM(ISNULL(EN.enCredit, 0)) Credit,
			[vAc].[acCurrencyVal] AS acCurrencyVal
		FROM 
			#ContraAccTbl [AC]
			INNER JOIN vwCeEn [EN] ON [EN].enAccount = [AC].[GUID]
			LEFT JOIN vwAc vAc ON EN.enContraAcc = vAc.[acGUID]
			INNER JOIN [#CostTbl] [CO] ON [CO].[CostGUID] = [EN].enCostPoint
		WHERE 
			[EN].enDate BETWEEN @StartDate AND @EndDate
			AND (@Posted = -1 OR [EN].[ceIsPosted] = @Posted)

		GROUP BY 
			[AC].[GUID], 
			EN.enContraAcc,
			[vAc].[acCurrencyVal]) AS G
	WHERE #RESULT.[CashAccount] = G.enContraAcc AND #RESULT.[ContraAccount] = G.AccountGuid
	-----------------------------------------------------------------------------------
	----------------------Õ”«» „Ã„Ê⁄ √—’œ… Õ—ﬂ«  «·Õ”«»«  «·„ﬁ«»·… ÊÊ÷⁄Â« ›Ì Õ”«» «·‰ﬁœÌ…
	UPDATE #RESULT SET	[Receives] = G.Receives, 
						[Payments] = G.Payments, 
						[ReceivesRatio] = G.Receives, 
						[PaymentsRatio] = G.Payments,
						[ReceivesInAccountCurrency] = G.ReceivesInAccountCurrency,
						[PaymentsInAccountCurrency] = G.PaymentsInAccountCurrency,
						[MovementBalance] = G.Receives - G.Payments,
						[MovementBalanceRatio] = G.Receives - G.Payments,
						[MovementBalanceInAccountCurrency] = (G.ReceivesInAccountCurrency - G.PaymentsInAccountCurrency)
	FROM
		(SELECT 
			CashAccount, 
			SUM(ISNULL(Receives, 0)) Receives, 
			SUM(ISNULL(Payments, 0)) Payments,
			SUM(ISNULL(ReceivesInAccountCurrency, 0)) ReceivesInAccountCurrency, 
			SUM(ISNULL(PaymentsInAccountCurrency, 0)) PaymentsInAccountCurrency
		FROM 
			#RESULT
		GROUP BY CashAccount) AS G
	WHERE #RESULT.[CashAccount] = G.CashAccount AND [Type] = 1
	-----------------------------------------------------------------------------------
	-------------------- Õ”«» ﬁÌ„ «·Õ”«»«  «·—∆Ì”Ì… ·Õ”«»«  «·‰ﬁœÌ…
	DECLARE @level INT
	SET @Level = (SELECT MAX([Level]) FROM #RESULT WHERE [Type] = 1)  
		WHILE @Level >= 0   
		BEGIN     
			UPDATE #RESULT SET  [Receives] = [SumReceives],
								[Payments] = [SumPayments],
								[OpeningBalance] = [SumOpeningBalance],
								[MovementBalance] = [SumMovementBalance],
								[ClosingBalance] = [SumClosingBalance],
								[CurrentBalance] = [SumCurrentBalance],
								[ReceivesInAccountCurrency] = [SumReceivesInAccountCurrency],
								[PaymentsInAccountCurrency] = [SumPaymentsInAccountCurrency],
								[OpeningBalanceInAccountCurrency] = [SumOpeningBalanceInAccountCurrency],
								[MovementBalanceInAccountCurrency] = [SumMovementBalanceInAccountCurrency],
								[ClosingBalanceInAccountCurrency] = [SumClosingBalanceInAccountCurrency],
								[CurrentBalanceInAccountCurrency] = [SumCurrentBalanceInAccountCurrency],
								[Nsons] = [COUNT]
				FROM  (   
						SELECT  
							[CashParentGuid],  
							SUM(ISNULL([Receives], 0)) AS [SumReceives],
							SUM(ISNULL([Payments], 0)) AS [SumPayments],
							SUM(ISNULL([OpeningBalance], 0)) AS [SumOpeningBalance],
							SUM(ISNULL([MovementBalance], 0)) AS [SumMovementBalance],
							SUM(ISNULL([ClosingBalance], 0)) AS [SumClosingBalance],
							SUM(ISNULL([CurrentBalance], 0)) AS [SumCurrentBalance],
							SUM(ISNULL([ReceivesInAccountCurrency], 0)) AS [SumReceivesInAccountCurrency],
							SUM(ISNULL([PaymentsInAccountCurrency], 0)) AS [SumPaymentsInAccountCurrency],
							SUM(ISNULL([OpeningBalanceInAccountCurrency], 0)) AS [SumOpeningBalanceInAccountCurrency],
							SUM(ISNULL([MovementBalanceInAccountCurrency], 0)) AS [SumMovementBalanceInAccountCurrency],
							SUM(ISNULL([ClosingBalanceInAccountCurrency], 0)) AS [SumClosingBalanceInAccountCurrency],
							SUM(ISNULL([CurrentBalanceInAccountCurrency], 0)) AS [SumCurrentBalanceInAccountCurrency],
							COUNT(*) [COUNT]
						FROM  
							[#RESULT]       
						WHERE   
							[Level] = @Level
						GROUP BY  
							[CashParentGuid]  
						) AS [Sons] -- sum sons  
				WHERE 	#RESULT.[CashAccount] = SONS.[CashParentGuid]
			SET @Level = @Level - 1  
		END 
    -------------------------------------------------------------------------------------------
	------------------------------ ≈œŒ«· «·Õ”«»«  «·—∆Ì”Ì… ··Õ”«»«  «·„ﬁ«»·… Õ”» «·„” ÊÏ «·„ÿ·Ê»
	IF(@ShowMainAcc = 1)
	BEGIN
		SET @Level = (SELECT MAX([Level]) FROM #RESULT WHERE [TYPE] = 2)  
		WHILE @Level > 0   
		BEGIN   
			INSERT INTO  #RESULT  ([CashAccount], [ContraAccount], [ContraAccountName], [ContraParentGuid], [ContraParentName], [Receives], [Payments], [ReceivesInAccountCurrency], [PaymentsInAccountCurrency], [level], [Nsons], [Type]) 
			SELECT 
				SONS.[CashAccount], SONS.[ContraParentGuid], SONS.[ContraParentName], PARENT.[GUID], PARENT.Name,  
				[SumPrevReceives], [SumPrevPayments], 
				[SumPrevReceivesInAccountCurrency], [SumPrevPaymentsInAccountCurrency],
				@level - 1, [COUNT], 3
			FROM  (   
					SELECT  
						[CashAccount],
						[ContraParentGuid],  
						[ContraParentName],
						SUM(ISNULL([Receives], 0)) AS [SumPrevReceives],
						SUM(ISNULL([Payments], 0)) AS [SumPrevPayments],
						SUM(ISNULL([ReceivesInAccountCurrency], 0)) AS [SumPrevReceivesInAccountCurrency],
						SUM(ISNULL([PaymentsInAccountCurrency], 0)) AS [SumPrevPaymentsInAccountCurrency],
						COUNT(*) [COUNT]
					FROM  
						[#RESULT]
					WHERE   
						[Level] = @Level AND [Type] > 1
					GROUP BY  [CashAccount], [ContraParentGuid], [ContraParentName]
					) AS [Sons] -- sum sons  
				LEFT JOIN ac000 [AC] ON SONS.[ContraParentGuid] = AC.[GUID]
				LEFT JOIN ac000 [PARENT] ON PARENT.[GUID] = AC.ParentGUID
			SET @Level = @Level - 1
		END 
	END

	IF(@ShowSubAcc = 0)
	BEGIN
		DELETE #RESULT WHERE [Type] = 2
	END
	-------------------------------------------------------------------------------------
	--------------------- Õ”«» «·—’Ìœ «·Œ «„Ì
	UPDATE #RESULT SET	[ClosingBalance] = ISNULL(r.[MovementBalance], 0) + ISNULL(r.[OpeningBalance], 0),
						[ClosingBalanceRatio] = ISNULL(r.[MovementBalance], 0) + ISNULL(r.[OpeningBalance], 0),
						[ClosingBalanceInAccountCurrency] = ISNULL(r.[MovementBalanceInAccountCurrency], 0) + ISNULL(r.[OpeningBalanceInAccountCurrency], 0)
	FROM
		#RESULT r
	-----------------------------------------------------------------------------------
	--------------------------- Õ”«» «·‰”» «·„∆ÊÌ…
	DECLARE @MainAccOpeningBalance FLOAT
	DECLARE	@MainAccReceives FLOAT
	DECLARE	@MainAccPayments FLOAT
	DECLARE	@MainAccMovementBalance FLOAT
	DECLARE	@MainAccClosingBalance FLOAT
	
	SELECT
		@MainAccOpeningBalance = [OpeningBalance],
		@MainAccReceives = [Receives],
		@MainAccPayments = [Payments],
		@MainAccMovementBalance = [MovementBalance],
		@MainAccClosingBalance = [ClosingBalance]
	FROM
		#RESULT
	WHERE
		[CashAccount] = @AccGUID
	
	UPDATE 
		#RESULT 
	SET	
		[OpeningBalanceRatio] = (CASE WHEN @MainAccOpeningBalance <> 0 THEN ([OpeningBalance] * 100) / @MainAccOpeningBalance ELSE 0 END),
		[ReceivesRatio] = (CASE WHEN @MainAccReceives <> 0 THEN ([Receives] * 100) / @MainAccReceives ELSE 0 END),
		[PaymentsRatio] = (CASE WHEN @MainAccPayments <> 0 THEN ([Payments] * 100) / @MainAccPayments ELSE 0 END),
		[MovementBalanceRatio] = (CASE WHEN @MainAccMovementBalance <> 0 THEN ([MovementBalance] * 100) / @MainAccMovementBalance ELSE 0 END),
		[ClosingBalanceRatio] = (CASE WHEN @MainAccClosingBalance <> 0 AND [Type] <> 2 THEN ([ClosingBalance] * 100) / @MainAccClosingBalance ELSE 0 END)
						
	FROM #RESULT
	-----------------------------------------------------------------------------------
	---------------------------  ⁄ÌÌ‰ «·√”ÿ— «·›«—€…
	UPDATE 
		#RESULT 
	SET	
		IsEmpty = (CASE WHEN (ISNULL([OpeningBalance], 0) = 0) AND (ISNULL([Receives], 0) = 0) AND (ISNULL([Payments], 0) = 0) THEN 1 ELSE 0 END)
	FROM #RESULT r
	-----------------------------------------------------------------------------------
	--------------------------- ⁄—÷ «·‰ ÌÃ… «·—∆Ì”Ì…
	SELECT --*
		[CashAccount],
		ISNULL([CashParentGuid], 0x00) AS [CashParentGuid],
		ISNULL([CashAccountName], '') AS [CashAccountName],
		ISNULL([CashAccountCurrencyGUID], 0x00) AS [CashAccountCurrencyGUID],			
		ISNULL([CashAccountCurrencyName], '') AS [CashAccountCurrencyName],			
		ISNULL([CashAccountCurrencyLatinName], '') AS [CashAccountCurrencyLatinName],
		ISNULL([CashAccountCurrencyValue], 0) AS [CashAccountCurrencyValue],
		ISNULL([ContraAccount], 0x00) AS [ContraAccount],
		ISNULL([ContraAccountName], '') AS [ContraAccountName],
		ISNULL([ContraParentGuid], 0x00) AS [ContraParentGuid],
		ISNULL([ContraParentName], '') AS [ContraParentName],
		ISNULL([ContraAccountCurrencyGUID], 0x00) AS [ContraAccountCurrencyGUID],
		ISNULL([ContraAccountCurrencyName], '') AS [ContraAccountCurrencyName],
		ISNULL([ContraAccountCurrencyLatinName], '') AS [ContraAccountCurrencyLatinName],
		ISNULL([ContraAccountCurrencyValue], 0) AS [ContraAccountCurrencyValue],
		ISNULL([OpeningBalance], 0) AS [OpeningBalance],
		ISNULL([OpeningBalanceRatio], 0) AS [OpeningBalanceRatio],
		ISNULL([OpeningBalanceInAccountCurrency], 0) AS [OpeningBalanceInAccountCurrency],
		ISNULL([Receives], 0) AS [Receives],
		ISNULL([ReceivesRatio], 0) AS [ReceivesRatio],
		ISNULL([ReceivesInAccountCurrency], 0) AS [ReceivesInAccountCurrency],
		ISNULL([Payments], 0) AS [Payments],
		ISNULL([PaymentsRatio], 0) AS [PaymentsRatio],
		ISNULL([PaymentsInAccountCurrency], 0) AS [PaymentsInAccountCurrency],
		ISNULL([MovementBalance], 0) AS [MovementBalance],
		ISNULL([MovementBalanceRatio], 0) AS [MovementBalanceRatio],
		ISNULL([MovementBalanceInAccountCurrency], 0) AS [MovementBalanceInAccountCurrency],
		ISNULL([ClosingBalance], 0) AS [ClosingBalance],
		ISNULL([ClosingBalanceRatio], 0) AS [ClosingBalanceRatio],
		ISNULL([ClosingBalanceInAccountCurrency], 0) AS [ClosingBalanceInAccountCurrency],
		ISNULL([CurrentBalance], 0) AS [CurrentBalance],
		ISNULL([CurrentBalanceInAccountCurrency], 0) AS [CurrentBalanceInAccountCurrency],
		[Level] + 1 AS [Level],
		ISNULL(r.[Path], '0') AS [Path],
		[Nsons],
		[Type],
		[IsEmpty]
	FROM 
		#RESULT r
		LEFT JOIN [#ContraAccTbl] CONTRASORTED ON r.ContraAccount = CONTRASORTED.[GUID]
		LEFT JOIN [#AccTbl] CASHSORTED ON r.CashAccount = CASHSORTED.[GUID]
	WHERE 
		(
		([Type] = 1) 
		OR 
		([Nsons] = 0 AND @ShowSubAcc = 1)
		OR
		((@MaxLevel = 0) OR (([LEVEL] + 1 <= @MaxLevel) AND (@MaxLevel > 0) AND ([Type] <> 1)))
		)
		AND
		((@IncludeEmpty = 1) OR (@IncludeEmpty = 0 AND IsEmpty <> 1) OR ([CashAccount] = @AccGuid))
		AND
		((@ShowMainAcc = 0) OR (@ShowMainAcc = 1 AND ([Type] <> 3 
														OR 
														([Type] = 3 AND [Level] = 0) 
														OR 
														([Type] = 3 AND [Level] > 0 AND @ShowSubAcc = 1)
														)))
		AND
		((@ShowSubAcc = 0) OR (@ShowSubAcc = 1 AND ([Type] = 1 
													OR 
													([Type] = 2 AND (@ShowMainAcc = 0 OR (@ShowMainAcc = 1 AND (@MaxLevel = 0 OR (@MaxLevel > 0 AND [Level] < @MaxLevel))))) 
													OR 
													([Type] = 3 AND [Level] = 0 AND @ShowMainAcc = 1) --Õ”«»«  „ﬁ«»·… »«·„” ÊÏ «·√Ê·
													OR
													([Type] = 3 AND [Level] > 0)
													)))

	ORDER BY 
		CASHSORTED.[Path], CONTRASORTED.[Path]
	-----------------------------------------------------------------------------------
	-------------------------- ›Õ’ «–« ﬂ«‰ Â‰«ﬂ ﬁÌÊœ  ÕÊÌ Õ”«»«  ‰ﬁœÌ… „‰ €Ì— „ﬁ«»·« 
	-- „⁄ ÷—Ê—… «” À‰«¡ ”‰œ «·ﬁÌœ «·«›  «ÕÌ
	-- ·« ÌÕ ”» «·”ÿ— „‰ «·‰ ÌÃ… ≈·« ≈–« ﬂ«‰ Õ”«» «·‰ﬁœÌ… ·Ì” ·Â „ﬁ«»· Ê√Õœ «·Õ”«»«  «·»«ﬁÌ… ⁄·Ï «·√ﬁ· ·Ì” ·Â Õ”«» „ﬁ«»· 
		Exec prcGetCashContraMovementEntry   @AccGuid, @StartDate, @EndDate 			
###################################################################################
CREATE Procedure prcGetCashContraMovementEntry
	@AccGuid			UNIQUEIDENTIFIER = 0x0,
	@StartDate 			DATETIME,  
	@EndDate 			DATETIME
	
AS
	SET NOCOUNT ON 

	DECLARE @OpeningEntry [UNIQUEIDENTIFIER]

	SET @OpeningEntry = (SELECT Value FROM op000 WHERE Name = 'FSCfg_OpeningEntryType')

	SELECT [Guid] AS acGuid INTO #accountTbl FROM dbo.fnGetAccountsList(@AccGuid,1) 

	-----«Œ Ì«— √ﬁ·«„ «·”‰œ«  «· Ì  ÕÊÌ Õ”«»«  «·‰ﬁœÌ… «·„ÿ·Ê» ⁄„· „⁄«Ì‰… ·Â«
	SELECT ceGUID, ceNumber, ceDate, enAccount, enContraAcc,enDate, enDebit, enCredit, 0 AS AccSum, 0 AS ContraAccSum
	INTO
		 #Entries
	FROM 
		vwCeEn CE
	WHERE
	    (ISNULL(@OpeningEntry, 0x0) = 0x0 OR  
		(ISNULL(@OpeningEntry, 0x0) <> 0x0 AND ceTypeGUID <> @OpeningEntry))
		 AND [CE].enDate BETWEEN @StartDate AND @EndDate	
		 AND ([CE].enAccount IN (SELECT * FROM #accountTbl) OR [CE].enContraAcc IN (SELECT * FROM #accountTbl))			

	UPDATE #Entries SET AccSum = AccountSum 
	FROM
		 (SELECT ceGUID, enAccount,  SUM(ISNULL(enDebit, 0) - ISNULL(enCredit, 0)) AS AccountSum
		  FROM 
				#Entries INNER JOIN #accountTbl ON #Entries.enAccount = #accountTbl.acGuid
		  GROUP BY 
				ceGUID,
				enAccount
				) AS EN
	WHERE
		EN.ceGUID = #Entries.ceGUID AND EN.enAccount = #Entries.enAccount

	UPDATE #Entries SET ContraAccSum = EN.ContraSum 
	FROM
		(SELECT ceGUID, enContraAcc,  SUM(ISNULL(enDebit, 0) - ISNULL(enCredit, 0)) AS ContraSum
		FROM 
				#Entries INNER JOIN #accountTbl ON #Entries.enContraAcc = #accountTbl.acGuid
		  GROUP BY 
				ceGUID,
				enContraAcc
		) AS EN
		WHERE 
		   EN.ceGUID = #Entries.ceGUID AND EN.enContraAcc = #Entries.enAccount
 

	SELECT Distinct E.ceGUID, E.ceNumber, E.ceDate, E.enAccount,(E.AccSum + E.ContraAccSum) AS BalanceDifference,
	ac.Code + ' - ' + ac.Name AS enAccountName 
	FROM
		#Entries E 
		LEFT JOIN ac000 ac ON E.enAccount = ac.[GUID]
	WHERE
		enAccount IN (SELECT * from #accountTbl) AND (AccSum + ContraAccSum) <> 0
	
	SELECT NSons from ac000 WHERE GUID =  @AccGuid
###################################################################################
#END 	
