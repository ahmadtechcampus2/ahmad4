######################################################################################
CREATE FUNCTION fnGetDefaultCurr()
	RETURNS UNIQUEIDENTIFIER
AS
BEGIN
	RETURN (
				SELECT TOP 1 GUID FROM MY000 WHERE CurrencyVal = 1 ORDER BY Number
		   )
END
######################################################################################
CREATE FUNCTION fnCalcBillTotal(
	@buGuid [uniqueidentifier],
	@CurGUID [uniqueidentifier] = 0x0)
RETURNS FLOAT 
AS
BEGIN
	DECLARE 
		@total [float],
		@AccGuid [uniqueidentifier]
	IF ISNULL(@CurGUID, 0x0) = 0x0
		SET @CurGUID = dbo.fnGetDefaultCurr()

	SET @AccGuid = (SELECT CustAccGUID FROM bu000 WHERE Guid = @buGuid)
	SET @total = (SELECT ABS(SUM(en.FixedEnCredit) - SUM(en.FixedEnDebit)) 
				FROM 
					er000 er 
					INNER JOIN [dbo].[fnExtended_En_Fixed](@CurGUID) [en]  ON en.ceGUID = er.EntryGUID AND en.enAccount = @AccGuid
				WHERE 
					 er.ParentGUID = @buGuid
					 AND en.enGUID NOT IN (
											SELECT 
												en.GUID 
											FROM 
												en000 en 
												INNER JOIN ce000 ce ON ce.Guid = en.ParentGUID
												INNER JOIN er000 er ON er.EntryGUID = ce.GUID
												INNER JOIN bu000 bu ON bu.GUID = er.ParentGUID
												INNER JOIN bt000 bt ON bt.GUID = bu.TypeGUID
											WHERE
												er.ParentType = 2 AND bu.GUID = @buGuid
												AND ((bt.bIsInput = 1 AND en.Credit = 0) OR (bt.bIsOutput = 1 AND en.Debit = 0))
												AND (en.ContraAccGUID = bu.FPayAccGUID AND en.ContraAccGUID <> 0x00)
												AND (en.AccountGUID = bu.CustAccGUID))
				  GROUP BY en.ceGUID )
	RETURN @total
END
######################################################################################
CREATE PROCEDURE prcCheckBillPaySec
AS
	DECLARE @UserGUID UNIQUEIDENTIFIER	 
	SET @UserGUID = ISNULL(@userGUID, [dbo].[fnGetCurrentUserGUID]())

	IF [dbo].[fnIsAdmin](@UserGUID) > 0
		RETURN

	DECLARE @Cnt INT
	SET @Cnt = 0
	SELECT GUID Type,[dbo].[fnGetUserBillSec_Browse](@UserGUID,GUID) Posted,[dbo].[fnGetUserBillSec_BrowseUnPosted] (@UserGUID,GUID) UnPostedSec
	INTO #SEC
	FROM BT000
	DELETE [r] FROM
	[#Result] [r] 
	INNER JOIN [BU000] b ON b.Guid = r.[ParentGUID]
	INNER JOIN #SEC sec ON sec.Type = b.TypeGuid
	WHERE  [ParentType] = 2 AND b.Security > CASE IsPosted WHEN 1 THEN Posted ELSE UnPostedSec END
	SET @Cnt = @Cnt + @@RowCount
	TRUNCATE TABLE #SEC
	INSERT INTO #SEC SELECT GUID Type,
	[dbo].[fnGetUserEntrySec_Browse](@UserGUID,GUID),0 FROM [et000]
	DELETE [r] FROM
	[#Result] [r] 
	INNER JOIN [py000] b ON b.Guid = r.[ParentGUID]
	INNER JOIN #SEC sec ON sec.Type = b.TypeGuid
	WHERE  [ParentType] = 4 AND b.Security >  Posted 
	SET @Cnt = @Cnt + @@RowCount
	
	TRUNCATE TABLE #SEC
	INSERT INTO #SEC SELECT GUID Type,
	[dbo].[fnGetUserNoteSec_Browse](@UserGUID,GUID),0 FROM [nt000]
	
	DELETE [r] FROM
	[#Result] [r] 
	INNER JOIN [ch000] b ON b.Guid = r.[ParentGUID]
	INNER JOIN #SEC sec ON sec.Type = b.TypeGuid
	WHERE  [ParentType] IN(5,6,7) AND b.Security >  Posted 
	SET @Cnt = @Cnt + @@RowCount
	IF (@Cnt > 0)
		INSERT INTO [#SecViol] VALUES(1,@Cnt)
	DELETE [#Result] WHERE [AccSecurity] > [dbo].[fnGetUserAccountSec_Browse](@UserGUID)
	SET @Cnt =  @@RowCount
	IF (@Cnt > 0)
		INSERT INTO [#SecViol] VALUES(1,@Cnt) 
######################################################################################
CREATE PROCEDURE repBillPayment_Debt
		@AccGUID 		[UNIQUEIDENTIFIER],
		@CurGUID 		[UNIQUEIDENTIFIER],
		@CurVAL 		[FLOAT],
		@DebtType		[INT],-- 0 Credit, 1: Debit
		@ShowPaid		[INT],-- 1: Show Payment, 0 DontShow
		@ShowUnPaid		[INT],-- 1: Show UnPayment, 0 DontShow
		@ShowPartPaid	[INT],-- 1: Show Part Payment, 0 DontShow
		@StartDate		[DATETIME],
		@EndDate		[DATETIME],
		@SrcGuid		[UNIQUEIDENTIFIER] = 0x00,
		@CostGuid		[UNIQUEIDENTIFIER] = 0x00,
		@Sort			[INT] = 0,
		@Branch			[UNIQUEIDENTIFIER] = 0x00,
		@Posted			[INT] = -1,
		@CustGUID		[UNIQUEIDENTIFIER] = 0x00
AS 
	SET NOCOUNT ON
	
	DECLARE 
		@UserGUID [UNIQUEIDENTIFIER],
		@UserSecurity [INT],
		@Zero FLOAT 
		
	DECLARE @ShowOrderBills	[BIT]
	SET @ShowOrderBills = ISNULL((SELECT (CASE [Value] WHEN '1' THEN 1 ELSE 0 END) FROM op000 WHERE Name = 'AmnCfg_ShowOrderBills' AND UserGUID = [dbo].[fnGetCurrentUserGUID]()), 0)
	
	CREATE TABLE [#AccTbl]([AccGUID] [UNIQUEIDENTIFIER], [Security] [INT], [Level] [INT])
	
	CREATE TABLE [#DebtTbl]( 
		[enGUID]		[UNIQUEIDENTIFIER],
		[coCode]		[NVARCHAR](250) COLLATE ARABIC_CI_AI,
		[coName]		[NVARCHAR](250) COLLATE ARABIC_CI_AI,
		[coLatinName]	[NVARCHAR](250) COLLATE ARABIC_CI_AI,
		[Class]			[NVARCHAR](255) COLLATE ARABIC_CI_AI)
		 
	CREATE TABLE [#SecViol]( [Type] [INT], [Cnt] [INTEGER]) 
	CREATE TABLE [#BillTbl]( [Type] [UNIQUEIDENTIFIER], [Security] [INT], [ReadPriceSecurity] [INT])    
	CREATE TABLE [#EntryTbl]( [Type] [UNIQUEIDENTIFIER], [Security] [INT])
	CREATE TABLE [#CostTbl]( [CostGUID] [UNIQUEIDENTIFIER], [Security] [INT])
	CREATE TABLE [#BranchTbl]( [GUID] [UNIQUEIDENTIFIER] , [Security] [INT],[Name] [NVARCHAR](250)) 
	CREATE TABLE [#Result](
		[AccGUID]				[UNIQUEIDENTIFIER],  
		[AccSecurity]			[INT],  
		[AccName]				[NVARCHAR](500),   
		[AccCode]				[NVARCHAR](500),
		[AccLatinName]			[NVARCHAR](500),  
		[Security]				[INT], 
		[UserSecurity]			[INT], 
		[Date]					[DATETIME], 
		[ParentGUID]			[UNIQUEIDENTIFIER], 
		[ParentType]			[INT],
		[ceNumber]				[INT],
		[enGUID]				[UNIQUEIDENTIFIER], 
		[ceGUID]				[UNIQUEIDENTIFIER], 
		[Debit]					[FLOAT],
		[Credit]				[FLOAT],
		[ContraAcc]				[UNIQUEIDENTIFIER],
		[Val]					[FLOAT],
		[Note]					[NVARCHAR](1000), 
		[DueDate]				[DATETIME],
		[coCode]				[NVARCHAR](500),
		[coName]				[NVARCHAR](500),
		[coLatinName]			[NVARCHAR](500),
		[brName]				[NVARCHAR](500),
		[CostGUID]				[UNIQUEIDENTIFIER],
		[Class]					[NVARCHAR](500),
		[Vendor]				[FLOAT],
		[SalesMan]				[FLOAT],
		[PaymentType]			[INT],	-- 1 order bill, 0 except
		[PaymentFormattedNumber][NVARCHAR](255), -- if PaymentType 1 then get the formatted number 
		[enNumber] INT,
		[CustName]				[NVARCHAR](500), 
		[CustLatinName]				[NVARCHAR](500),  
		[CustGUID]				[UNIQUEIDENTIFIER],
	    [BpGUID]					[UNIQUEIDENTIFIER])

	INSERT INTO [#BranchTbl]
	SELECT 
		[f].[Guid],
		[Security],
		[Name]
	FROM
		[fnGetBranchesList](@Branch) [f]
		INNER JOIN [br000] [br] on [f].[guid] = [Br].[Guid]
		
	SET @Zero = [dbo].[fnGetZeroValuePrice]()
	
	IF (@Branch = 0X0)
		INSERT INTO [#BranchTbl] VALUES (0X00,0,'')
		
	INSERT INTO [#CostTbl] EXEC [prcGetCostsList] @CostGuid
	
	DECLARE @MainAcc [BIT]
	
	IF (@AccGUID <> 0x00) AND EXISTS(SELECT * FROM [ac000] WHERE [ParentGuid] = @AccGUID)
		SET @MainAcc = 1
	ELSE 
		SET @MainAcc = 0
		
	IF (@CostGuid = 0X0)
	BEGIN
		INSERT INTO [#CostTbl] VALUES(0X00,0)
	END
	
	SET @UserGUID = [dbo].[fnGetCurrentUserGUID]()  
	
	INSERT INTO [#EntryTbl] EXEC [prcGetNotesTypesList]  @SrcGuid, @UserGUID
	
	INSERT INTO [#BillTbl] EXEC [prcGetBillsTypesList] @SrcGuid, @UserGUID
	
	INSERT INTO [#EntryTbl] EXEC [prcGetEntriesTypesList] @SrcGuid, @UserGUID
	
	INSERT INTO [#EntryTbl] SELECT [Type], [Security] FROM [#BillTbl] 
	
	SET @UserSecurity = [dbo].[fnGetUserEntrySec_Browse]( @UserGUID, default) 

	INSERT INTO [#AccTbl] EXEC [prcGetAccountsList] @AccGUID 	
	IF @MainAcc > 0
	BEGIN
		DECLARE @cg UNIQUEIDENTIFIER  
		SELECT @cg = CurrencyGUID FROM ac000 WHERE guid = @AccGUID

		DELETE tbl
		FROM 
			[#AccTbl] tbl
			INNER JOIN ac000 ac ON ac.GUID = tbl.AccGUID 
		WHERE ac.CurrencyGUID != @cg 
	END 

	DECLARE @lang INT 
		SET @lang = [dbo].[fnConnections_GetLanguage]()

	SELECT 
		[CostGUID],
		a.[Security],
		ISNULL([Code],'') [coCode],
		ISNULL([Name],'') [coName],
		ISNULL([LatinName],'') [coLatinName]
	INTO 
		[#CostTbl2]
	FROM 
		[#CostTbl] a 
		LEFT JOIN [co000] b ON [CostGUID] = b.Guid
	--«ﬁ·«„ ”‰œ«  «·„œÌ‰… √Ê «·œ«∆‰… »«” À‰«¡ «·›Ê« Ì—
	INSERT INTO [#DebtTbl]
	SELECT
		[en].[enGUID],
		[coCode],
		[coName],
		[coLatinName],
		enClass
	FROM 
		[dbo].[fnExtended_En_Fixed]( @CurGUID) As [en]  
		INNER JOIN [#AccTbl] As [ac] on [en].[enAccount] = [ac].[AccGUID] 
		INNER JOIN [#EntryTbl] [ent] ON [ent].[Type] = [en].[ceTypeGuid]
		INNER JOIN [#CostTbl2] [co] ON [co].[CostGuid] = [en].[enCostPoint]
		LEFT JOIN [fnBp_Fixed](@CurGUID, @CurVal) [b1] ON [en].[enGUID] = [b1].[bpDebtGUID] 
		LEFT JOIN [fnBp_Fixed](@CurGUID, @CurVal) [b2] ON [en].[enGUID] = [b2].[BpPayGUID]
		LEFT JOIN [vwEr] As [er] on [en].[ceGUID] = [er].[erEntryGUID]
	WHERE 
		(@Posted = -1 OR [ceIsposted] = @Posted)
		AND
		((@DebtType = 0  AND [en].[FixedEnCredit] > 0) OR (@DebtType = 1  AND [en].[FixedEnDebit] > 0))
		AND 
		(@ShowPaid <> 0 OR ([en].[FixedEnCredit] - ISNULL( ISNULL(b1.[FixedBpVal],b2.[FixedBpVal]), 0)) >  @Zero OR ([en].[FixedEnDebit] - ISNULL(ISNULL(b1.[FixedBpVal],b2.[FixedBpVal]), 0)) >  @Zero)
		AND 
		(@ShowUnPaid <> 0 OR (ISNULL( ISNULL(b1.[FixedBpVal],b2.[FixedBpVal]), 0) - [en].[FixedEnCredit])> @Zero OR (ISNULL( ISNULL(b1.[FixedBpVal],b2.[FixedBpVal]), 0) - [en].[FixedEnDebit])> @Zero) 
		AND 
		(@ShowPartPaid	<> 0 OR ABS(ISNULL( ISNULL(b1.[FixedBpVal],b2.[FixedBpVal]), 0) - [en].[FixedEnCredit]) < @Zero OR ABS(ISNULL( ISNULL(b1.[FixedBpVal],b2.[FixedBpVal]), 0) - [en].[FixedEnDebit]) < @Zero )
		AND
		[en].[enDate] BETWEEN @StartDate AND @EndDate
		AND 
		(ISNULL(er.erParentType,0) <> 2) --‘—ÿ «” À‰«¡ «·›Ê« Ì—
	
	
	INSERT INTO [#Result]
	SELECT	
	distinct 
		[ac].[AccGUID],  
		[ac].[Security],  
		[en].[acName],  
		[en].[acCode], 
		[en].[acLatinName],   
		[en].[ceSecurity],  
		@UserSecurity,  
		[en].[enDate],  
		[er].[erParentGuid], 
		[er].[erParentType], 
		[en].[ceNumber],  
		[en].[enGUID],  
		[en].[ceGUID], 
		[en].[FixedEnDebit], 
		[en].[FixedEnCredit], 
		[en].[enContraAcc],
		CASE 
			WHEN [en].ceCurrencyPtr = ISNULL([b1].BpCurrencyGUID,[b2].BpCurrencyGUID) AND @CurGUID <> [en].ceCurrencyPtr THEN (ISNULL(ISNULL([b1].[FixedBpVal],[b2].[FixedBpVal]), 0) / CASE ISNULL([b1].BpCurrencyVal,[b2].BpCurrencyVal) WHEN 0 THEN 1 ELSE ISNULL([b1].BpCurrencyVal,[b2].BpCurrencyVal) END) * en.ceCurrencyVal
			ELSE ISNULL(ISNULL([b1].[FixedBpVal],[b2].[FixedBpVal]), 0)
		END,
		[en].[enNotes],
		ISNULL([pt].[DueDate],'1/1/1980'),
		[coCode],
		[coName],
		[coLatinName],
		[br].[Name],
		[enCostPoint],
		Class,
		0, 
		0,
		0, 
		'',
		[en].[enNumber],
		[cu].[cuCustomerName],
		[cu].[cuLatinName],
		[cu].[cuGUID],
		ISNULL([b1].[BpGUID],[b2].[BpGUID])
	FROM
		[dbo].[fnExtended_En_Fixed](@CurGUID) [en]  
		INNER JOIN [#AccTbl] [ac] ON [en].[enAccount] = [ac].[AccGUID]
		INNER JOIN [#DebtTbl] [d] ON [en].[enGUID] = [d].[enGUID] 
		LEFT JOIN [fnBp_Fixed](@CurGUID, @CurVal) [b1] ON [en].[enGUID] = [b1].[bpDebtGUID]
		LEFT JOIN [fnBp_Fixed](@CurGUID, @CurVal) [b2] ON [en].[enGUID] = [b2].[BpPayGUID]
		LEFT JOIN [vwEr] [er] ON [en].[ceGUID] = [er].[erEntryGUID]
		LEFT JOIN [pt000] [pt] ON  [pt].[refguid] = [er].[erParentGUID]		
		INNER JOIN [#BranchTbl] [br] ON br.[Guid] = [en].[ceBranch]
		LEFT JOIN [vwCu] [cu] ON [cu].[cuGUID] = [en].[enCustomerGUID]
  
	------ÃœÊ· «·›Ê« Ì— 
	INSERT INTO [#Result]
	SELECT 
		distinct
		[AccGUID],  
		acc.[Security],  
		acc.[Name],  
		acc.[Code], 
		acc.[LatinName],   
		ce.[Security],  
		@UserSecurity,  
		bu.[Date],  
		[erParentGuid], 
		[erParentType], 
		ce.[Number],
		0x0,
		ce.[GUID], 
		dbo.fnCalcBillTotal(bu.GUID,@CurGUID), 
		dbo.fnCalcBillTotal(bu.GUID,@CurGUID), 
		0x0,
	    CASE 
			WHEN ce.CurrencyGUID = ISNULL([b1].BpCurrencyGUID,[b2].BpCurrencyGUID) AND @CurGUID <> ce.CurrencyGUID THEN (ISNULL(ISNULL([b1].[FixedBpVal],[b2].[FixedBpVal]), 0) / CASE ISNULL([b1].BpCurrencyVal,[b2].BpCurrencyVal) WHEN 0 THEN 1 ELSE ISNULL([b1].BpCurrencyVal,[b2].BpCurrencyVal) END) * ce.CurrencyVal
			ELSE ISNULL(bpPart.SumTotal,0)
		END,
		bu.Notes,
		ISNULL([pt].[DueDate],'1/1/1980') AS ptDueDate,
		[coCode],
		[coName],
		[coLatinName],
		[br].[Name],
		co.[CostGUID],
		'',
		[bu].[Vendor],
		[bu].[SalesManPtr],
		0,
		(CASE @lang 
				WHEN 0 THEN bt.Abbrev
				ELSE (CASE bt.LatinAbbrev WHEN '' THEN bt.Abbrev ELSE bt.LatinAbbrev END)
			END) + ': ' + CAST(bu.Number AS NVARCHAR(10)),
		ce.[Number],
		[bu].Cust_Name,
		[cu].[cuLatinName],
		[bu].[CustGUID],
		0x0
	FROM
		[#EntryTbl] [ent] INNER JOIN bt000 bt  ON [ent].[Type] = bt.guid  AND (( @DebtType = 0  AND bt.bIsInput > 0) OR ( @DebtType = 1  AND bt.bIsOutput > 0))
		INNER JOIN [bu000] [bu] on bt.GUID=bu.TypeGUID
		INNER JOIN [#AccTbl] As [ac] on bu.CustAccGUID= [ac].[AccGUID] 
		INNER JOIN [vwEr] As [er] on er.erParentGUID = bu.GUID  AND er.erParentType = 2
		INNER JOIN ac000 acc on acc.GUID= ac.AccGUID
		INNER JOIN [#CostTbl2] [co] ON [co].[CostGUID] = bu.CostGUID
		INNER JOIN [#BranchTbl] [br] ON br.Guid = [bu].[Branch]
		INNER JOIN CE000 ce on ce.GUID= er.erEntryGUID
		LEFT JOIN oit000 oit on oit.BillGuid= bu.TypeGUID
		LEFT  JOIN [pt000] [pt] ON  [pt].[refguid] = [er].[erParentGUID]
		LEFT JOIN [fnBp_Fixed](@CurGUID, @CurVal) [b1] ON [erParentGUID] = [b1].[bpDebtGUID]
		LEFT JOIN [fnBp_Fixed](@CurGUID, @CurVal) [b2] ON erParentGUID= [b2].[BpPayGUID]
		LEFT JOIN (SELECT DISTINCT buGUID FROM ori000) ori ON ori.buGUID = bu.GUID
		LEFT JOIN vwCu cu  ON cu.cuGUID = bu.CustGUID
		LEFT JOIN 
				(
					SELECT 
						SUM([FixedBpVal]) SumTotal,
						[bu].[GUID] AS buGuid
					FROM 
						[fnBp_Fixed](@CurGUID, @CurVal)
						INNER JOIN [bu000] As bu ON [bu].[GUID] = [bpDebtGUID] OR [bu].[GUID] = BpPayGUID
					GROUP BY 
						[bu].[GUID]
				) AS bpPart
				ON bpPart.buGuid = bu.GUID
	WHERE 
		  (@Posted = -1 OR [ce].[Isposted] = @Posted) 
		 AND ( [bu].[Date] BETWEEN @StartDate AND @EndDate )
		 AND (@ShowPaid <> 0 OR (dbo.fnCalcBillTotal(bu.GUID,@CurGUID) - ISNULL( [bpPart].[SumTotal], 0))  > @Zero ) --„”œœ
		 AND (@ShowUnPaid <> 0 OR ISNULL(bpPart.SumTotal, 0) <> 0 ) --€Ì— „”œœ
		 AND (@ShowPartPaid	<> 0 
				OR (ISNULL(bpPart.SumTotal, 0) <= 0
				OR  ISNULL(bpPart.SumTotal, 0) >= dbo.fnCalcBillTotal(bu.GUID,@CurGUID))
			 ) --„”œœ Ã“∆Ì«
		AND ((@ShowOrderBills = 1) OR ((@ShowOrderBills = 0) AND (ori.buGUID IS NULL)))
		AND NOT EXISTS
		(select  
					o.BuGuid
				FROM ori000 o inner join (
				select	distinct
						p.BillGuid
		 
						from bp000 as b
						INNER JOIN vwOrderPayments p on p.PaymentGuid = b.DebtGUID
				UNION ALL	
				select	distinct
						p.BillGuid
		 
						from bp000 as b
						INNER JOIN vwOrderPayments p on p.PaymentGuid= b.PayGUID
				) as ord on ord.BillGuid= o.POGUID
					where o.BuGuid <> 0x0 AND bu.Guid =o.BuGuid)
	DECLARE @defCurrency UNIQUEIDENTIFIER
	SELECT @defCurrency = [myGUID] FROM vwMy WHERE myCurrencyVal = 1
			
		
	IF @ShowOrderBills = 0
	BEGIN 
	IF EXISTS (SELECT * FROM [#BillTbl] [src] INNER JOIN [bt000] [bt] ON [bt].[Guid] = [src].[Type] WHERE ([bt].[Type] = 5) OR ([bt].[Type] = 6))
	BEGIN 

		INSERT INTO [#Result]
		SELECT	
		distinct 
			[ac].[AccGUID],  
			[ac].[Security],  
			[acc].[Name],  
			[acc].[Code], 
			[acc].[LatinName],   
			3,						-- ? [en].[ceSecurity],  
			@UserSecurity,  
			orp.PaymentDate,  
			[bu].buGUID,			-- ? [er].[erParentGuid], 
			2,						-- ? [er].[erParentType], 
			[bu].[buNumber],  
			[orp].[PaymentGuid],	-- [en].[enGUID],  
			[orp].[PaymentGuid],	-- [en].[ceGUID], 
			(CASE WHEN @CurGUID <> 0x00 AND @CurVal <> 0 THEN orp.UpdatedValueWithCurrency / @CurVal ELSE orp.UpdatedValue END),
			(CASE WHEN @CurGUID <> 0x00 AND @CurVal <> 0 THEN orp.UpdatedValueWithCurrency / @CurVal ELSE orp.UpdatedValue END),
			0x0,					-- [en].[enContraAcc],
			CASE WHEN ISNULL(bp1.bpCurrencyGUID,bp2.bpCurrencyGUID) <> @defCurrency AND bu.buCurrencyPtr = @defCurrency THEN 
				(ISNULL(ISNULL([bp1].[FixedBpVal],[bp2].[FixedBpVal]), 0) / ISNULL([bp1].BpCurrencyVal,[bp2].BpCurrencyVal)) * @CurVAL 
			ELSE
				ISNULL(bpPart.SumTotal,0)
			END,
			-- 0,
			[bu].[buNotes],
			[orp].[DueDate],
			[coCode],
			[coName],
			[coLatinName],
			[br].[Name],
			[bu].[buCostPtr],
			'',
			[bu].[buVendor],
			[bu].[buSalesManPtr],
			1,
			(CASE @lang 
				WHEN 0 THEN bt.Abbrev
				ELSE (CASE bt.LatinAbbrev WHEN '' THEN bt.Abbrev ELSE bt.LatinAbbrev END)
			END) + ': ' + CAST(bu.buNumber AS NVARCHAR(10)),
			[bu].[buNumber],
			[cu].[cuCustomerName],
			[cu].[cuLatinName],
			[cu].[cuGUID],
			0x0
		FROM
			[#BillTbl] [src]
			INNER JOIN [bt000] [bt] ON [bt].[Guid] = [src].[Type] AND (((@DebtType = 0  AND [bt].[bIsInput] > 0) OR (@DebtType = 1  AND [bt].[bIsInput] = 0)))
			INNER JOIN [dbo].[fnBu_Fixed](@CurGUID) As [bu] on [bu].[buType] = [src].[Type]
			INNER JOIN [vwOrderPayments] As [orp] on [bu].[buGuid] = [orp].[BillGuid]
			INNER JOIN [#AccTbl] As [ac] on [bu].[buCustAcc] = [ac].[AccGUID] 
			INNER JOIN [ac000] As [acc] on [acc].[Guid] = [ac].[AccGUID] 
			INNER JOIN [#CostTbl2] [co] ON [co].[CostGuid] = [bu].[buCostPtr]
			INNER JOIN [#BranchTbl] [br] ON br.[Guid] = [bu].[buBranch]
			LEFT JOIN [fnBp_Fixed](@CurGUID, @CurVal) As [bp1] ON [orp].[PaymentGuid] = [bp1].[bpDebtGUID]
			LEFT JOIN [fnBp_Fixed](@CurGUID, @CurVal) As [bp2] ON [orp].[PaymentGuid] = [bp2].[BpPayGUID]
			LEFT JOIN [vwCu] [cu] ON [cu].[cuAccount] = [acc].[GUID]
			LEFT JOIN 
					(
						SELECT 
							SUM([FixedBpVal]) SumTotal,
							o.PaymentGuid
						FROM 
							[fnBp_Fixed](@CurGUID, @CurVal)
							INNER JOIN [vwOrderPayments] As o ON o.[PaymentGuid] = [bpDebtGUID] 
						GROUP BY 
							o.PaymentGuid
						union all
						SELECT 
							SUM([FixedBpVal]) SumTotal,
							o.PaymentGuid
						FROM 
							[fnBp_Fixed](@CurGUID, @CurVal)
							INNER JOIN [vwOrderPayments] As o ON  o.[PaymentGuid] = BpPayGUID
						GROUP BY 
							o.PaymentGuid
					) AS bpPart
					ON bpPart.PaymentGuid = orp.PaymentGuid
		WHERE 
			(@ShowPaid <> 0 OR (orp.UpdatedValue - ISNULL(bpPart.SumTotal, 0)) >  @Zero)
			AND 
			(@ShowUnPaid <> 0 OR ISNULL(bpPart.SumTotal, 0) <> 0)
			AND 
			(	
				@ShowPartPaid <> 0 
				OR (ISNULL(bpPart.SumTotal, 0) <= 0 
				OR ISNULL(bpPart.SumTotal, 0) >= orp.UpdatedValue)
			)
			AND
			[bu].[buDate] BETWEEN @StartDate AND @EndDate
			AND
			orp.UpdatedValueWithCurrency <> 0
			AND  NOT EXISTS (SELECT  
											o.PaymentGuid
									FROM vwOrderPayments o INNER JOIN (
										SELECT	DISTINCT
												p.POGUID
												FROM bp000 as b
												INNER JOIN ori000 p on p.BuGuid = b.DebtGUID
												union all
												SELECT	DISTINCT
												p.POGUID
												FROM bp000 as b
												INNER JOIN ori000 p on p.BuGuid = b.PayGUID
												) as ord on ord.POGUID= o.BillGuid 
												WHERE orp.PaymentGuid=PaymentGuid
											)
											
			
			
	END 
	END 
	
	
	UPDATE r 
	SET DueDate = ch.DueDate ,
		PaymentFormattedNumber=doc
	FROM 
	er000 er
		INNER JOIN [#Result] r   ON er.EntryGuid = ceGuid 
		INNER JOIN ( SELECT MIN(DueDate) DueDate
							,v.Guid
							,parentGuid
							 ,(CASE @lang 
				WHEN 0 THEN nt.Abbrev
				ELSE (CASE nt.LatinAbbrev WHEN '' THEN nt.Abbrev ELSE nt.LatinAbbrev END)
			END) + ': ' + CAST(v.Number AS NVARCHAR(10)) as doc
			
			 FROM  nt000 nt inner join vbch v on nt.GUID=v.TypeGUID WHERE  v.STATE = 0  GROUP BY v.Guid,v.Number,nt.LatinAbbrev,nt.Abbrev,parentGuid) ch ON ch.[GUID] = er.ParentGuid 
	WHERE 
		r.DueDate = '1/1/1980' 
		AND 
		er.ParentType IN(5, 6, 7, 8)

		UPDATE res
			SET PaymentFormattedNumber=(CASE @lang WHEN 0 THEN [et].[Abbrev] ELSE (CASE [et].[LatinAbbrev] WHEN '' THEN [et].[Abbrev] ELSE [et].[LatinAbbrev] END) END) + 
							+ ': ' + CAST(py.Number AS VARCHAR(10)) 
		FROM 
		#result res
		INNER JOIN [py000] AS [py] ON [res].[ParentGUID] = [py].[GUID]  
		INNER JOIN [et000] AS [et] ON [py].[TypeGUID] = [et].[Guid]  

		UPDATE res
			SET PaymentFormattedNumber = dbo.fnStrings_get('Entry', DEFAULT) + ': ' + CAST(res.ceNumber AS NVARCHAR(10))
		FROM 
		#result res
		where PaymentFormattedNumber=''


	SELECT  
		@MainAcc AS MainAcc,
		[AccGUID],  
		[AccName],  
		[AccCode],
		[AccLatinName],  
		[Date], 
		[ParentGUID], 
		[ParentType], 
		[ceNumber], 
		[enGUID], 
		[ceGUID], 
		[Debit], 
		[Credit],
		[ContraAcc],
		SUM( [Val]) AS [Val],
		[Note] AS [Notes],
		[DueDate],
		[coCode],
		[coName],
		[coLatinName],
		[brName],
		[CostGUID],
		[Class],
		[Vendor],
		[SalesMan],
		[PaymentType],
		[PaymentFormattedNumber],
		[CustName],
		[CustLatinName],
		[CustGUID]
	FROM 
		[#Result] 
	WHERE
		ISNULL([CustGUID], 0x0) = CASE WHEN ISNULL(@CustGUID, 0x0) <> 0x0 THEN @CustGUID ELSE ISNULL([CustGUID], 0x0)  END
	GROUP BY  
		[AccCode],
		[AccGUID],
		[AccName],
		[AccLatinName],
		[Date],
		[ParentGUID],
		[ParentType],
		[ceNumber],
		[enGUID],
		[ceGUID],
		[Debit],
		[Credit],
		[ContraAcc],
		[Note],
		[DueDate],
		[coCode],
		[coName],
		[coLatinName],
		[brName],
		[CostGUID],
		[Class],
		[Vendor],
		[SalesMan],
		[PaymentType],
		[PaymentFormattedNumber],
		[enNumber],
		[CustName], 
		[CustGUID],
		[ceNumber],
		[CustName],
		[CustLatinName], 
		[CustGUID]

	HAVING (@DebtType = 1 AND ((ABS(Debit - SUM ([Val])) = 0 AND @ShowPaid = 1) OR (ABS(Debit - SUM ([Val])) > 0))) OR (@DebtType = 0 AND ((ABS(Credit - SUM ([Val])) = 0 AND @ShowPaid = 1) OR (ABS(Credit - SUM ([Val])) > 0)))
	ORDER BY
		[AccCode],
		[AccGUID],
		CASE @Sort 
			WHEN 0 THEN [Date] 
			ELSE [DueDate]
		END,
		[ceNumber],
		[enNumber]
		
		
	SELECT * FROM [#SecViol]
###############################################################
CREATE PROCEDURE repBillPayment_Pay
		@AccGUID 		[UNIQUEIDENTIFIER],
		@CurGUID 		[UNIQUEIDENTIFIER],
		@CurVAL 		[FLOAT],
		@DebtType		[INT],-- 0 Credit, 1: Debit
		@StartDate		[DATETIME],
		@EndDate		[DATETIME],
		@CostGuid		[UNIQUEIDENTIFIER] = 0x00,
		@Branch			[UNIQUEIDENTIFIER] = 0x00,
		@SrcGuid		[UNIQUEIDENTIFIER] = 0x00,
		@Posted			[INT] = -1,
		@CustGUID  	    [UNIQUEIDENTIFIER] = 0x00
AS 
	SET NOCOUNT ON

	DECLARE @UserGUID 	[UNIQUEIDENTIFIER], @UserSecurity [INT],@Zero FLOAT
	DECLARE @ShowOrderBills	[BIT]
	SET @ShowOrderBills = ISNULL((SELECT (CASE [Value] WHEN '1' THEN 1 ELSE 0 END) FROM op000 WHERE Name = 'AmnCfg_ShowOrderBills' AND UserGUID = [dbo].[fnGetCurrentUserGUID]()), 0)
	SET @Zero = [dbo].[fnGetZeroValuePrice]()
	CREATE TABLE [#AccTbl]( [AccGUID] [UNIQUEIDENTIFIER], [Security] [INT], [Level] [INT]) 
	CREATE TABLE [#SecViol]( [Type] [INT], [Cnt] [INTEGER])  
	CREATE TABLE [#BillTbl]( [Type] [UNIQUEIDENTIFIER], [Security] [INT], [ReadPriceSecurity] [INT])    
	CREATE TABLE [#EntryTbl]( [Type] [UNIQUEIDENTIFIER], [Security] [INT])
	CREATE TABLE [#CostTbl]( [CostGUID] [UNIQUEIDENTIFIER], [Security] [INT])
	CREATE TABLE [#BranchTbl]( [GUID] [UNIQUEIDENTIFIER] , [Security] [INT],[Name] [NVARCHAR](250)) 
	INSERT INTO [#BranchTbl]		SELECT [f].[Guid],[Security],[Name] FROM [fnGetBranchesList](@Branch) [f] INNER JOIN [br000] [br] on [f].[guid] = [Br].[Guid]
	IF (@Branch = 0X00)
		INSERT INTO [#BranchTbl] VALUES (0X00,0,'')
	SET @UserGUID = [dbo].[fnGetCurrentUserGUID]()  
	INSERT INTO [#EntryTbl] EXEC [prcGetNotesTypesList]  @SrcGuid, @UserGUID    
	   
	INSERT INTO [#BillTbl] EXEC [prcGetBillsTypesList] @SrcGuid,@UserGUID
	INSERT INTO [#EntryTbl] EXEC [prcGetEntriesTypesList] @SrcGuid,@UserGUID
	
	INSERT INTO [#EntryTbl] SELECT [Type] , [Security]  FROM [#BillTbl] 
	CREATE TABLE [#Result](  
		[AccGUID]				[UNIQUEIDENTIFIER],  
		[AccSecurity]			[INT],  
		[AccName]				[NVARCHAR](255),  
		[AccCode]				[NVARCHAR](255),  
		[Security]				[INT],	
		[UserSecurity]			[INT], 
		[Date]					[DATETIME], 
		[ParentGUID]			[UNIQUEIDENTIFIER], 
		[ParentType]			[INT], 
		[ceNumber]				[INT], 
		[enGUID]				[UNIQUEIDENTIFIER], 
		[ceGUID]				[UNIQUEIDENTIFIER], 
		[Debit]					[FLOAT], 
		[Credit]				[FLOAT], 
		[Notes]					[NVARCHAR](1000),
		[Val]					[FLOAT],
		[accLatinName]			[NVARCHAR](250),
		[coCode]				[NVARCHAR](250),
		[coName]				[NVARCHAR](250),
		[coLatinName]			[NVARCHAR](250),
		[brName]				[NVARCHAR](250),
		[CostGUID]				[UNIQUEIDENTIFIER],
		[Class]					[NVARCHAR](255),
		[DueDate]				[DATETIME],
		[SalesMan]				[FLOAT],
		[Vendor]				[FLOAT],
		[PaymentType]			[INT],	-- 1 order bill, 0 except
		[PaymentFormattedNumber][NVARCHAR](255), -- if PaymentType 1 then get the formatted number 
		[CustGUID]			[UNIQUEIDENTIFIER],
		[CustName]			[NVARCHAR](250),
		[CustLatinName]		[NVARCHAR](250))


	SET @UserGUID = [dbo].[fnGetCurrentUserGUID]() 
	SET @UserSecurity = [dbo].[fnGetUserEntrySec_Browse]( @UserGUID, default) 

	INSERT INTO [#AccTbl] EXEC [prcGetAccountsList] @AccGUID 
	DECLARE @MainAcc [BIT]
	IF (@AccGUID <> 0x00) AND EXISTS(SELECT * FROM [ac000] WHERE [ParentGuid] = @AccGUID)
		SET @MainAcc = 1
	ELSE 
		SET @MainAcc = 0

	INSERT INTO [#CostTbl] EXEC [prcGetCostsList] @CostGuid
	IF (@CostGuid = 0X00)
	BEGIN
		INSERT INTO [#CostTbl] VALUES (0X00, 0)
	END

	IF @MainAcc > 0
	BEGIN
		DECLARE @cg UNIQUEIDENTIFIER  
		SELECT @cg = CurrencyGUID FROM ac000 WHERE guid = @AccGUID

		DELETE tbl
		FROM 
			[#AccTbl] tbl
			INNER JOIN ac000 ac ON ac.GUID = tbl.AccGUID 
		WHERE ac.CurrencyGUID != @cg 
	END 
		
	SELECT [CostGUID], a.[Security],ISNULL([Code],'') [coCode],ISNULL([Name],'') [coName],ISNULL([LatinName],'') [coLatinName]
	INTO [#CostTbl2]
	FROM [#CostTbl] a LEFT JOIN [co000] b ON [CostGUID] = b.Guid

	DECLARE @lang INT 
		SET @lang = [dbo].[fnConnections_GetLanguage]()
	
	INSERT INTO [#Result] 
	SELECT	 
		[ac].[AccGUID],  
		[ac].[Security],  
		[en].[acName],  
		[en].[acCode],  
		[en].[ceSecurity],  
		@UserSecurity,  
		[en].[enDate],  
		[er].[erParentGuid], 
		[er].[erParentType], 
		[en].[ceNumber],  
		[en].[enGUID],  
		[en].[ceGUID],  
		[en].[FixedEnDebit], 
		[en].[FixedEnCredit], 
		[en].[enNotes], 
		ISNULL([bd].[FixedBpVal], 0) +ISNULL([bp].[FixedBpVal], 0),
		[acLatinName],
		[coCode],
		[coName],
		[coLatinName],
		[br].[Name],
		[enCostPoint],
		enclass,
		'1/1/1980',
		0,
		0,
		0,
		'',
		cu.cuGUID,
		cu.cuCustomerName,
		cu.cuLatinName

	FROM [dbo].[fnExtended_En_Fixed]( @CurGUID) As [en]  
		INNER JOIN [#AccTbl] As [ac] on [en].[enAccount] = [ac].[AccGUID] 
		INNER JOIN [#CostTbl2] [co] ON [CostGUID] = [en].[enCostPoint]
		INNER JOIN [#EntryTbl] [ent] ON [ent].[Type] = [en].[ceTypeGuid]
		LEFT JOIN fnBpDebt_Fixed(@CurGUID, @CurVal) As [bd] on [en].[enGUID] = [bd].[BpDebtGUID]
		LEFT JOIN fnBpPay_Fixed(@CurGUID, @CurVal) As [bp] on [en].[enGUID] = [bp].[BpPayGUID]
		LEFT JOIN [vwEr] As [er] on [en].[ceGUID] = [er].[erEntryGUID] 
		INNER JOIN [#BranchTbl] [br] ON br.Guid = [en].[ceBranch]
		LEFT JOIN [vwCu] [cu] ON cu.cuGUID = en.enCustomerGUID
	WHERE 
		(@Posted = -1 OR [ceIsposted] = @Posted) AND
		(( @DebtType = 0  AND [en].[FixedEnDebit] > @Zero AND ([en].[FixedEnDebit] - ISNULL([bd].[FixedBpVal], 0) - ISNULL([bp].[FixedBpVal], 0)) > @Zero ) OR 
		( @DebtType = 1  AND [en].[FixedEnCredit] > @Zero AND ([en].[FixedEnCredit] - ISNULL([bd].[FixedBpVal], 0) - ISNULL([bp].[FixedBpVal], 0)) > @Zero ))AND 
		[en].[enDate] BETWEEN @StartDate AND @EndDate 
		AND ISNULL(er.erParentType, 0) <> 2
	ORDER BY [acCode],[ac].[AccGUID],[enDate]


	INSERT INTO [#Result] 
	SELECT	 
			[ac].[AccGUID],  
			[ac].[Security],  
			[acc].[Name],  
			[acc].[Code],  
			[ce].[Security],  
			@UserSecurity,  
			[bu].[Date],  
			[er].[erParentGuid], 
			[er].[erParentType], 
			[ce].[Number],
			0x0,   
			[ce].[GUID],  
			dbo.fnCalcBillTotal(bu.GUID,@CurGUID), 
			dbo.fnCalcBillTotal(bu.GUID,@CurGUID), 
			[bu].[Notes] as ceNotes, 
	        ISNULL([bd].[FixedBpVal], 0) + ISNULL([bp].[FixedBpVal], 0),
			[acc].[LatinName],
			[coCode],
			[coName],
			[coLatinName],
			[br].[Name],
			co.[CostGUID],
			'',
			'1/1/1980',
			[bu].[SalesManPtr],
			[bu].[Vendor],
			0,
			(CASE @lang 
				WHEN 0 THEN bt.Abbrev
				ELSE (CASE bt.LatinAbbrev WHEN '' THEN bt.Abbrev ELSE bt.LatinAbbrev END)
			END) + ': ' + CAST(bu.Number AS NVARCHAR(10)),
			cu.cuGUID,
			cu.cuCustomerName,
			cu.cuLatinName
		FROM [bu000] [bu]
			INNER JOIN [#AccTbl] As [ac] on bu.CustAccGUID= [ac].[AccGUID] 
			INNER JOIN ac000 acc on acc.GUID= ac.AccGUID
			INNER JOIN [#CostTbl2] [co] ON [co].[CostGUID] = bu.CostGUID
			INNER JOIN [#EntryTbl] [ent] ON [ent].[Type] = [bu].TypeGUID
			INNER JOIN [vwEr] As [er] on er.erParentGUID = bu.GUID
			INNER JOIN [#BranchTbl] [br] ON br.Guid = [bu].[Branch]
			INNER JOIN CE000 ce on ce.GUID= er.erEntryGUID
			INNER JOIN bt000 bt on bu.TypeGUID=bt.GUID
			LEFT  JOIN (SELECT DISTINCT buGUID FROM ori000) ori ON ori.buGUID = bu.GUID
			LEFT JOIN fnBpDebt_Fixed(@CurGUID, @CurVal) AS [bd] ON [erParentGUID] = [bd].[BpDebtGUID]
			LEFT JOIN fnBpPay_Fixed(@CurGUID, @CurVal)	AS [bp]	ON [erParentGUID] = [bp].[BpPayGUID]
			LEFT JOIN [vwCu] [cu] ON cu.cuGUID = bu.CustGUID
		WHERE 
			(@Posted = -1 OR [ce].[Isposted] = @Posted) 
			AND ISNULL(er.erParentType ,0) = 2
			AND (( @DebtType = 0  AND bt.bIsOutput > 0 AND (  dbo.fnCalcBillTotal(bu.GUID,@CurGUID) - ISNULL([bd].[FixedBpVal], 0) - ISNULL([bp].[FixedBpVal], 0)) > @Zero ) OR 
			( @DebtType = 1  AND bt.bIsInput > 0 AND  ( dbo.fnCalcBillTotal(bu.GUID,@CurGUID) - ISNULL([bd].[FixedBpVal], 0) - ISNULL([bp].[FixedBpVal], 0)) > @Zero ))
			AND ( [bu].[Date] BETWEEN @StartDate AND @EndDate )
		AND ((@ShowOrderBills = 1) OR ((@ShowOrderBills = 0) AND (ori.buGUID IS NULL)))
		AND NOT EXISTS
		(select  
					o.BuGuid
				FROM ori000 o inner join (
				select	distinct
						p.BillGuid
		 
						from bp000 as b
						INNER JOIN vwOrderPayments p on p.PaymentGuid = b.DebtGUID
				UNION ALL	
				select	distinct
						p.BillGuid
		 
						from bp000 as b
						INNER JOIN vwOrderPayments p on p.PaymentGuid= b.PayGUID
				) as ord on ord.BillGuid= o.POGUID
					where o.BuGuid <> 0x0 AND bu.Guid =o.BuGuid)


	IF @ShowOrderBills = 0
	BEGIN 
	IF EXISTS (SELECT * FROM [#BillTbl] [src] INNER JOIN [bt000] [bt] ON [bt].[Guid] = [src].[Type] WHERE ([bt].[Type] = 5) OR ([bt].[Type] = 6))
	BEGIN 
	
		INSERT INTO [#Result]
		SELECT
			[ac].[AccGUID],  
			[ac].[Security],  
			[acc].[Name],  
			[acc].[Code],  
			3,
			@UserSecurity,  
			[bu].[buDate],  
			[bu].buGUID,			-- ? [er].[erParentGuid], 
			2,						-- ? [er].[erParentType], 
			[bu].[buNumber],  
			[orp].[PaymentGuid],	-- [en].[enGUID],  
			0x0,					-- [en].[ceGUID], 
			orp.UpdatedValueWithCurrency, 
			orp.UpdatedValueWithCurrency, 
			[bu].[buNotes],
			ISNULL( [bp].[FixedBpVal], 0) + ISNULL( [bpp].[FixedBpVal], 0), 
			[acc].[LatinName],
			[coCode],
			[coName],
			[coLatinName],
			[br].[Name],
			[bu].[buCostPtr],
			'',
			'1/1/1980',
			[bu].[buSalesManPtr],
			[bu].[buVendor],
			1,
			(CASE @lang 
				WHEN 0 THEN bt.Abbrev
				ELSE (CASE bt.LatinAbbrev WHEN '' THEN bt.Abbrev ELSE bt.LatinAbbrev END)
			END) + ': ' + CAST(bu.buNumber AS NVARCHAR(10)),
			cu.cuGUID,
			cu.cuCustomerName,
			cu.cuLatinName

		FROM
			[#BillTbl] [src]
			INNER JOIN [bt000] [bt] ON [bt].[Guid] = [src].[Type]
			INNER JOIN [dbo].[fnBu_Fixed](@CurGUID) As [bu] on [bu].[buType] = [src].[Type]
			INNER JOIN [vwOrderPayments] As [orp] on [bu].[buGuid] = [orp].[BillGuid]
			INNER JOIN [#AccTbl] As [ac] on [bu].[buCustAcc] = [ac].[AccGUID] 
			INNER JOIN [ac000] As [acc] on [acc].[Guid] = [ac].[AccGUID] 
			INNER JOIN [#CostTbl2] [co] ON [co].[CostGuid] = [bu].[buCostPtr]
			INNER JOIN [#BranchTbl] [br] ON br.[Guid] = [bu].[buBranch]
			LEFT JOIN [fnBpDebt_Fixed](@CurGUID, @CurVal) As [bp] on [orp].[PaymentGuid] = [bp].[bpDebtGUID] 
			LEFT JOIN fnBpPay_Fixed(@CurGUID, @CurVal)	AS [bpp] ON [orp].[PaymentGuid] = [bpp].[BpPayGUID]
			LEFT JOIN [vwCu] [cu] ON cu.cuGUID = [bu].buCustPtr
		WHERE 
			((@DebtType = 0  AND [bt].[bIsInput] =  0) OR (@DebtType = 1  AND [bt].[bIsInput] > 0))
			AND 
			(orp.UpdatedValueWithCurrency > @Zero AND (orp.UpdatedValueWithCurrency- (ISNULL( [bp].[FixedBpVal], 0)+ISNULL(bpp.FixedBpVal,0))) > @Zero ) -- OR 
			-- (@DebtType = 1  AND [bu].[FixedBuTotal] > @Zero AND ([bu].[FixedBuTotal]- ISNULL( [bp].[FixedBpVal], 0)) > @Zero ))
			AND [bu].[buDate] BETWEEN @StartDate AND @EndDate
			AND
			 orp.UpdatedValueWithCurrency <> 0
			AND  NOT EXISTS (SELECT  
											o.PaymentGuid
									FROM vwOrderPayments o INNER JOIN (
										SELECT	DISTINCT
												p.POGUID
												FROM bp000 as b
												INNER JOIN ori000 p on p.BuGuid = b.DebtGUID
												union all
												SELECT	DISTINCT
												p.POGUID
												FROM bp000 as b
												INNER JOIN ori000 p on p.BuGuid = b.PayGUID
												) as ord on ord.POGUID= o.BillGuid 
												WHERE orp.PaymentGuid=PaymentGuid
											)

	END 
	END 

	EXEC prcCheckBillPaySec

	UPDATE r SET DueDate = pt.DueDate FROM [#Result] r INNER JOIN pt000 PT ON pt.RefGUID = r.ParentGuid WHERE ParentType = 2
	
	UPDATE r SET DueDate = ch.DueDate,
	PaymentFormattedNumber=doc
	FROM 
	er000 er
		INNER JOIN [#Result] r   ON er.EntryGuid = ceGuid 
		INNER JOIN ( SELECT MIN(DueDate) DueDate
							,v.Guid
							,parentGuid
							 ,(CASE @lang 
				WHEN 0 THEN nt.Abbrev
				ELSE (CASE nt.LatinAbbrev WHEN '' THEN nt.Abbrev ELSE nt.LatinAbbrev END)
			END) + ': ' + CAST(v.Number AS NVARCHAR(10)) as doc
			
			 FROM  nt000 nt inner join vbch v on nt.GUID=v.TypeGUID WHERE  v.STATE = 0  GROUP BY v.Guid,v.Number,nt.LatinAbbrev,nt.Abbrev,parentGuid) ch ON ch.[GUID] = er.ParentGuid 
	WHERE 
		r.DueDate = '1/1/1980' 
		AND 
		er.ParentType IN(5, 6, 7, 8)


	UPDATE res
			SET PaymentFormattedNumber=(CASE @lang WHEN 0 THEN [et].[Abbrev] ELSE (CASE [et].[LatinAbbrev] WHEN '' THEN [et].[Abbrev] ELSE [et].[LatinAbbrev] END) END) + 
							+ ': ' + CAST(py.Number AS VARCHAR(10)) 
		FROM 
		#result res
		INNER JOIN [py000] AS [py] ON [res].[ParentGUID] = [py].[GUID]  
		INNER JOIN [et000] AS [et] ON [py].[TypeGUID] = [et].[Guid]  

		UPDATE res
			SET PaymentFormattedNumber = dbo.fnStrings_get('Entry', DEFAULT) + ': ' + CAST(res.ceNumber AS NVARCHAR(10))
		FROM 
		#result res
		where PaymentFormattedNumber=''
	
	SELECT * FROM [#Result] WHERE  ISNULL(CustGUID, 0X0) = CASE WHEN ISNULL(@CustGUID, 0X0) <> 0X0 THEN @CustGUID ELSE ISNULL(CustGUID, 0X0) END ORDER BY [AccCode], [Date], ceNumber, [Notes]
	SELECT * FROM [#SecViol]
######################################################################################
CREATE FUNCTION fn_getRelatedPays
(		@EnGUID 		[UNIQUEIDENTIFIER],--biil or enEntry or orderPayment
		@CurGUID 		[UNIQUEIDENTIFIER],
		@CurVAL 		[FLOAT],
		@CustGuid       [UNIQUEIDENTIFIER] = 0x0)

	RETURNS @Result TABLE
	(
		[AccGUID]					[UNIQUEIDENTIFIER], 
		[AccSecurity]				[INT],   
		[AccName]					[NVARCHAR](255),  
		[CustName]					[NVARCHAR](255), 
		[CustGUID]					[UNIQUEIDENTIFIER], 
		[AccCode]					[NVARCHAR](255),  
		[Security]					[INT], 
		[UserSecurity]				[INT], 
		[Date]						[DATETIME], 
		[ParentGUID]				[UNIQUEIDENTIFIER], 
		[ParentType]				[INT], 
		[ceNumber]					[INT], 
		[enGUID]					[UNIQUEIDENTIFIER], 
		[ceGUID]					[UNIQUEIDENTIFIER], 
		[bpGUID]					[UNIQUEIDENTIFIER], 
		[Debit]						[FLOAT], 
		[Credit]					[FLOAT], 
		[Notes]						[NVARCHAR](1000),
		[Val]						[FLOAT] ,
		[enCostPoint]				[UNIQUEIDENTIFIER],
		[coName]					[NVARCHAR](255),
		[coLatinName]				[NVARCHAR](255),
		[coCode]					[NVARCHAR](255),
		[class]						[NVARCHAR](255),
		[PaymentFormattedNumber]	[NVARCHAR](255))
	
	AS BEGIN
		DECLARE @ShowOrderBills	[BIT]
		SET @ShowOrderBills = ISNULL((SELECT (CASE [Value] WHEN '1' THEN 1 ELSE 0 END) FROM op000 WHERE Name = 'AmnCfg_ShowOrderBills' AND UserGUID = [dbo].[fnGetCurrentUserGUID]()), 0)
		DECLARE @UserGUID 	[UNIQUEIDENTIFIER], @UserSecurity [INT] 	DECLARE @lang INT 
		
		SET @lang = [dbo].[fnConnections_GetLanguage]()
		SET @UserGUID = [dbo].[fnGetCurrentUserGUID]() 
		SET @UserSecurity = [dbo].[fnGetUserEntrySec_Browse](@UserGUID, default) 

		INSERT INTO @Result
		SELECT	 
			[en].[acGUID],
			[en].[acSecurity],  
			[en].[acName],
			ISNULL([cu].[cuCustomerName], ''), 
			ISNULL([cu].[cuGUID], 0x0), 
			[en].[acCode],  
			[en].[ceSecurity],  
			@UserSecurity,  
			[en].[enDate],  
			[er].[erParentGuid], 
			ISNULL( [er].[erParentType], 0), 
			[en].[ceNumber],  
			[en].[enGUID],  
			[en].[ceGUID], 
			[b].[GUID], 
			[en].[FixedEnDebit], 
			[en].[FixedEnCredit], 
			[en].[enNotes], 
			case when b.CurrencyGUID = @CurGUID then ISNULL( [b].val, 0)/b.CurrencyVal ELSE  ISNULL( [b].val, 0)/@CurVAL END,
			en2.CostGuid,
			ISNULL(coName,'') coName,
			ISNULL(coLatinName,'') coLatinName,
			ISNULL(coCode,'') coCode,
			enclass,
			''
		FROM 
			[dbo].[fnExtended_En_Fixed]( @CurGUID) As [en]  
			INNER JOIN bp000 As [b] on (([en].[enGUID] = [b].[PayGUID] AND [b].[PayGUID] != @EnGUID) OR ([en].[enGUID] = [b].[DebtGUID] AND [b].[DebtGUID] != @EnGUID))
			INNER JOIN [en000] en2 on (([en2].[GUID] = [b].[PayGUID] AND [b].[PayGUID] != @EnGUID) OR ([en2].[GUID] = [b].[DebtGUID] AND [b].[DebtGUID] != @EnGUID))
			LEFT JOIN [vwEr] As [er] on [en].[ceGUID] = [er].[erEntryGUID]
			LEFT JOIN [vwCo] [co] ON coGuid =  en2.CostGuid
			LEFT JOIN [vwCu] [cu] ON [cu].[cuGUID] = en2.CustomerGUID
		WHERE 
			[b].[DebtGUID] = @EnGUID OR [b].[PayGUID] = @EnGUID
		
		INSERT INTO @Result 
		SELECT	 
			[ac].[GUID],
			[ac].[Security],  
			[ac].[Name],
			ISNULL([cu].[cuCustomerName], ''), 
			ISNULL([cu].[cuGUID], 0x0), 
			[ac].[Code],  
			[bu].[Security],  
			@UserSecurity,  
			[bu].[Date],  
			[bu].[GUID], 
			ISNULL( [er].[erParentType], 0), 
			[bu].[Number],  
			0x0,  
			[er].[erEntryGUID], 
			[b].[GUID], 
			dbo.fnCalcBillTotal(bu.guid,@CurGUID),
			dbo.fnCalcBillTotal(bu.guid,@CurGUID),
			[bu].[Notes], 
			case when b.CurrencyGUID = @CurGUID then ISNULL( [b].val, 0)/b.CurrencyVal ELSE  ISNULL( [b].val, 0)/@CurVAL END,
			[co].[coGUID],
			ISNULL(coName,'') coName,
			ISNULL(coLatinName,'') coLatinName,
			ISNULL(coCode,'') coCode,
			'',
			(CASE @lang 
					WHEN 0 THEN BT.Abbrev
					ELSE (CASE bt.LatinAbbrev WHEN '' THEN bt.Abbrev ELSE bt.LatinAbbrev END)
				END) + ': ' + CAST(bu.Number AS NVARCHAR(10))
		FROM 
			[bu000] [bu]  
			INNER JOIN [bt000] [bt] ON [bt].[Guid] = bu.[TypeGUID] 
			INNER JOIN vwer [er] ON [er].[erParentGUID] = [bu].[GUId]
			INNER JOIN bp000 As [b] ON (([bu].[GUID] = [b].[PayGUID] AND [b].[PayGUID] != @EnGUID) OR (bu.GUID = [b].[DebtGUID] AND [b].[DebtGUID] != @EnGUID))
			INNER JOIN ac000 ac ON bu.CustAccGUID = ac.GUID
			LEFT JOIN vwCu cu ON cu.cuGUID = bu.CustGUID
			LEFT JOIN (SELECT DISTINCT buGUID FROM ori000) ori ON ori.buGUID = bu.GUID
			LEFT JOIN [vwCo] [co] ON coGuid =  bu.CostGUID
		WHERE 
			([b].[DebtGUID] = @EnGUID OR [b].[PayGUID] = @EnGUID)
		

		INSERT INTO @Result
		SELECT	 
			[ac].[acGUID],
			[ac].[acSecurity],  
			[ac].[acName],
			ISNULL([cu].[cuCustomerName], ''), 
			ISNULL([cu].[cuGUID], 0x0), 
			[ac].[acCode],  
			3, -- [en].[ceSecurity],  
			@UserSecurity,  
			[bu].[buDate],  
			[bu].buGUID, 
			2,					-- ISNULL([er].[erParentType], 0), 
			[bu].[buNumber],  
			[orp].[PaymentGuid],
			0x0,				-- [en].[ceGUID], 
			[b].[bpGUID], 
			[bu].FixedBuTotal, 
			[bu].FixedBuTotal, 
			[bu].[buNotes], 
			ISNULL([b].[FixedBpVal], 0),
			bu.buCostPtr,
			ISNULL(coName,'') coName,
			ISNULL(coLatinName,'') coLatinName,
			ISNULL(coCode,'') coCode,
			'',
			(CASE @lang 
					WHEN 0 THEN BU.BTAbbrev
					ELSE (CASE bu.btLatinAbbrev WHEN '' THEN bu.btAbbrev ELSE bu.btLatinAbbrev END)
				END) + ': ' + CAST(bu.buNumber AS NVARCHAR(10))
		FROM 
			[dbo].[fnBu_Fixed](@CurGUID) As [bu] 
			INNER JOIN [vwAc] ac ON ac.acGUID = [bu].buCustAcc
			INNER JOIN [vwOrderPayments] AS [orp] on [bu].[buGuid] = [orp].[BillGuid]
			INNER JOIN [fnBp_Fixed]( @CurGUID, @CurVal) As [b] on [orp].[PaymentGuid] = [b].[BpPayGUID] or orp.PaymentGuid = b.[BpDebtGUID]
			LEFT JOIN [vwCu] cu ON cu.cuGUID = bu.buCustPtr
			LEFT JOIN [vwCo] [co] ON coGuid =  bu.buCostPtr
		WHERE 
			([b].[bpDebtGUID] = @EnGUID or b.BpPayGUID=@EnGUID) AND orp.PaymentGuid <> @EnGUID
			
		UPDATE Res
		SET 
			PaymentFormattedNumber = (CASE @lang WHEN 0 THEN [et].[Abbrev]
									  ELSE (CASE [et].[LatinAbbrev] WHEN '' THEN [et].[Abbrev] 
									  ELSE [et].[LatinAbbrev] END) END) + ': ' + CAST(py.Number AS VARCHAR(10)) 
		FROM 
			@Result Res
			INNER JOIN [py000] AS [py] ON [res].[ParentGUID] = [py].[GUID]  
			INNER JOIN [et000] AS [et] ON [py].[TypeGUID] = [et].[Guid]  

		UPDATE Res
		SET 
			PaymentFormattedNumber = dbo.fnStrings_get('Entry', DEFAULT) + ': ' + CAST(Res.ceNumber AS NVARCHAR(10))
		FROM 
			@Result Res
		WHERE 
			PaymentFormattedNumber=''

		UPDATE Res 
		SET 
			PaymentFormattedNumber = doc
		FROM 
			er000 er
			INNER JOIN @Result Res ON er.EntryGuid = ceGuid 
			INNER JOIN (SELECT 
							MIN(DueDate) DueDate
							,v.Guid
							,parentGuid
							,(CASE @lang WHEN 0 THEN nt.Abbrev
							  ELSE (CASE nt.LatinAbbrev WHEN '' THEN nt.Abbrev 
							  ELSE nt.LatinAbbrev END) END) + ': ' + CAST(v.Number AS NVARCHAR(10)) as doc
						FROM  
							nt000 nt 
							INNER JOIN vbch v on nt.GUID=v.TypeGUID 
						WHERE 
							v.STATE = 0 GROUP BY v.Guid, v.Number, nt.LatinAbbrev, nt.Abbrev,parentGuid) ch ON ch.[GUID] = er.ParentGuid 
		WHERE 
			er.ParentType IN(5, 6, 7, 8)
		RETURN
	END
######################################################################################
CREATE PROCEDURE repBillPayment_DebtPay
		@EnGUID 		[UNIQUEIDENTIFIER],--biil or enEntry or orderPayment
		@CurGUID 		[UNIQUEIDENTIFIER],
		@CurVAL 		[FLOAT],
		@CustGuid       [UNIQUEIDENTIFIER] = 0x0

AS 
	SET NOCOUNT ON
	CREATE TABLE [#SecViol]
	( 
		[Type]						[INT],
		[Cnt]						[INTEGER])  

	CREATE TABLE [#Result]
	(
		[AccGUID]					[UNIQUEIDENTIFIER], 
		[AccSecurity]				[INT],   
		[AccName]					[NVARCHAR](255),  
		[CustName]					[NVARCHAR](255), 
		[CustGUID]					[UNIQUEIDENTIFIER], 
		[AccCode]					[NVARCHAR](255),  
		[Security]					[INT], 
		[UserSecurity]				[INT], 
		[Date]						[DATETIME], 
		[ParentGUID]				[UNIQUEIDENTIFIER], 
		[ParentType]				[INT], 
		[ceNumber]					[INT], 
		[enGUID]					[UNIQUEIDENTIFIER], 
		[ceGUID]					[UNIQUEIDENTIFIER], 
		[bpGUID]					[UNIQUEIDENTIFIER], 
		[Debit]						[FLOAT], 
		[Credit]					[FLOAT], 
		[Notes]						[NVARCHAR](1000),
		[Val]						[FLOAT] ,
		[enCostPoint]				[UNIQUEIDENTIFIER],
		[coName]					[NVARCHAR](255),
		[coLatinName]				[NVARCHAR](255),
		[coCode]					[NVARCHAR](255),
		[class]						[NVARCHAR](255),
		[PaymentFormattedNumber]	[NVARCHAR](255))

	INSERT INTO [#Result] EXEC prcGetRelatedPays @EnGUID, @CurGUID, @CurVAL, @CustGuid
	EXEC prcCheckBillPaySec

	SELECT * FROM [#Result] WHERE CustGUID = CASE WHEN ISNULL(@CustGuid, 0x0) <> 0x0 THEN @CustGuid ELSE CustGUID END ORDER BY [AccCode], [Date], ceNumber, [Notes]
	SELECT * FROM [#SecViol]  
#####################################################################################
CREATE PROCEDURE deleteDebtBill
@DebtGuid UNIQUEIDENTIFIER
as

		IF EXISTS(SELECT * FROM BP000 WHERE DebtGUID=@DebtGuid)
		BEGIN
			DELETE FROM BP000
				WHERE DebtGUID=@DebtGuid AND Type = 0
		END
		ELSE 
			DELETE FROM BP000
				WHERE PayGUID=@DebtGuid AND Type = 0
########################################################################################
CREATE PROCEDURE repBillPayment_DebtRes
		@AccGUID 		[UNIQUEIDENTIFIER],
		@CurGUID 		[UNIQUEIDENTIFIER],
		@CurVAL 		[FLOAT],
		@DebtType		[INT],-- 0 Credit, 1: Debit
		@ShowPaid		[INT],-- 1: Show Payment, 0 DontShow
		@ShowUnPaid		[INT],-- 1: Show UnPayment, 0 DontShow
		@ShowPartPaid	[INT],-- 1: Show Part Payment, 0 DontShow
		@StartDate		[DATETIME],
		@EndDate		[DATETIME],
		@SrcGuid		[UNIQUEIDENTIFIER] = 0x00,
		@CostGuid		[UNIQUEIDENTIFIER] = 0x00,
		@Sort			[INT] = 0,
		@Branch			[UNIQUEIDENTIFIER] = 0x00,
		@Posted			[INT] = -1,
		@lang [INT]=0,
		@m_PayDetails [INT]=1
	
AS 
	SET NOCOUNT ON
	DECLARE 
		@UserGUID [UNIQUEIDENTIFIER],
		@UserSecurity [INT],
		@Zero FLOAT ,
		@MainAcc [BIT]

	DECLARE @ShowOrderBills	[BIT]
	SET @ShowOrderBills = ISNULL((SELECT (CASE [Value] WHEN '1' THEN 1 ELSE 0 END) FROM op000 WHERE Name = 'AmnCfg_ShowOrderBills' AND UserGUID = [dbo].[fnGetCurrentUserGUID]()), 0)
	
	CREATE TABLE [#AccTbl]([AccGUID] [UNIQUEIDENTIFIER], [Security] [INT], [Level] [INT])
	
	CREATE TABLE [#DebtTbl]( 
		[enGUID]		[UNIQUEIDENTIFIER],
		[coCode]		[NVARCHAR](250) COLLATE ARABIC_CI_AI,
		[coName]		[NVARCHAR](250) COLLATE ARABIC_CI_AI,
		[coLatinName]	[NVARCHAR](250) COLLATE ARABIC_CI_AI,
		[Class]			[NVARCHAR](255) COLLATE ARABIC_CI_AI)
		 
	CREATE TABLE [#SecViol]( [Type] [INT], [Cnt] [INTEGER]) 
	CREATE TABLE [#BillTbl]( [Type] [UNIQUEIDENTIFIER], [Security] [INT], [ReadPriceSecurity] [INT])    
	CREATE TABLE [#EntryTbl]( [Type] [UNIQUEIDENTIFIER], [Security] [INT])
	CREATE TABLE [#CostTbl]( [CostGUID] [UNIQUEIDENTIFIER], [Security] [INT])
	CREATE TABLE [#BranchTbl]( [GUID] [UNIQUEIDENTIFIER] , [Security] [INT],[Name] [NVARCHAR](250)) 
	CREATE TABLE [#Result](
		[AccGUID]				[UNIQUEIDENTIFIER],  
		[AccSecurity]			[INT],  
		[AccName]				[NVARCHAR](250),  
		[AccCode]				[NVARCHAR](250),
		[AccLatinName]			[NVARCHAR](250),  
		[Security]				[INT], 
		[UserSecurity]			[INT], 
		[Date]					[DATETIME], 
		[ParentGUID]			[UNIQUEIDENTIFIER], 
		[ParentType]			[INT],
		[ceNumber]				[INT],
		[enGUID]				[UNIQUEIDENTIFIER], 
		[ceGUID]				[UNIQUEIDENTIFIER], 
		[Debit]					[FLOAT],
		[Credit]				[FLOAT],
		[ContraAcc]				[UNIQUEIDENTIFIER],
		[Val]					[FLOAT],
		[Note]					[NVARCHAR](255), 
		[DueDate]				[DATETIME],
		[coCode]				[NVARCHAR](250),
		[coName]				[NVARCHAR](250),
		[coLatinName]			[NVARCHAR](250),
		[brName]				[NVARCHAR](250),
		[CostGUID]				[UNIQUEIDENTIFIER],
		[Class]					[NVARCHAR](255),
		[Vendor]				[FLOAT],
		[SalesMan]				[FLOAT],
		[PaymentType]			[INT],	-- 1 order bill, 0 except
		[PaymentFormattedNumber][NVARCHAR](MAX), -- if PaymentType 1 then get the formatted number 
		[enNumber] INT,
		RowNumber INT) 

	INSERT INTO [#BranchTbl]
	SELECT 
		[f].[Guid],
		[Security],
		[Name]
	FROM
		[fnGetBranchesList](@Branch) [f]
		INNER JOIN [br000] [br] on [f].[guid] = [Br].[Guid]
		
	SET @Zero = [dbo].[fnGetZeroValuePrice]()
	
	IF (@Branch = 0X0)
		INSERT INTO [#BranchTbl] VALUES (0X00,0,'')
		
	INSERT INTO [#CostTbl] EXEC [prcGetCostsList] @CostGuid

	IF (@AccGUID <> 0x00) AND EXISTS(SELECT * FROM [ac000] WHERE [ParentGuid] = @AccGUID)
		SET @MainAcc = 1
	ELSE 
		SET @MainAcc = 0
		
	IF (@CostGuid = 0X0)
	BEGIN
		INSERT INTO [#CostTbl] VALUES(0X00,0)
	END
	
	SET @UserGUID = [dbo].[fnGetCurrentUserGUID]()  
	
	INSERT INTO [#EntryTbl] EXEC [prcGetNotesTypesList]  @SrcGuid, @UserGUID
	INSERT INTO [#BillTbl] EXEC [prcGetBillsTypesList] @SrcGuid, @UserGUID
	INSERT INTO [#EntryTbl] EXEC [prcGetEntriesTypesList] @SrcGuid, @UserGUID
	INSERT INTO [#EntryTbl] SELECT [Type], [Security] FROM [#BillTbl] 
	SET @UserSecurity = [dbo].[fnGetUserEntrySec_Browse]( @UserGUID, default) 
	INSERT INTO [#AccTbl] EXEC [prcGetAccountsList] @AccGUID 	
	IF @MainAcc > 0
	BEGIN
		DELETE tbl
		FROM 
			[#AccTbl] tbl
			INNER JOIN ac000 ac ON ac.GUID = tbl.AccGUID 
		WHERE ac.CurrencyGUID != (SELECT CurrencyGUID FROM ac000 WHERE guid = @AccGUID) 
	END 

	SELECT 
		[CostGUID],
		a.[Security],
		ISNULL([Code],'') [coCode],
		ISNULL([Name],'') [coName],
		ISNULL([LatinName],'') [coLatinName]
	INTO 
		[#CostTbl2]
	FROM 
		[#CostTbl] a 
		LEFT JOIN [co000] b ON [CostGUID] = b.Guid
	--«ﬁ·«„ ”‰œ«  «·„œÌ‰… √Ê «·œ«∆‰… »«” À‰«¡ «·›Ê« Ì—
	INSERT INTO [#DebtTbl]
	SELECT
	distinct
		[en].[enGUID],
		[coCode],
		[coName],
		[coLatinName],
		enClass
	FROM 
		[dbo].[fnExtended_En_Fixed]( @CurGUID) As [en]  
		INNER JOIN [#AccTbl] As [ac] on [en].[enAccount] = [ac].[AccGUID] 
		INNER JOIN [#EntryTbl] [ent] ON [ent].[Type] = [en].[ceTypeGuid]
		INNER JOIN [#CostTbl2] [co] ON [co].[CostGuid] = [en].[enCostPoint]
		LEFT JOIN [fnBp_Fixed](@CurGUID, @CurVal) [b] ON [b].[bpDebtGUID] = [en].[enGUID]  OR [b].[BpPayGUID]=[en].[enGUID]
		LEFT JOIN [vwEr] As [er] on [en].[ceGUID] = [er].[erEntryGUID]
	WHERE 
		(@Posted = -1 OR [ceIsposted] = @Posted)
		AND
		((@DebtType = 0  AND [en].[FixedEnCredit] > 0) OR (@DebtType = 1  AND [en].[FixedEnDebit] > 0))
		AND 
		(@ShowPaid <> 0 OR ([en].[FixedEnCredit] - ISNULL( [b].[FixedBpVal], 0)) >  @Zero OR ([en].[FixedEnDebit] - ISNULL([b].[FixedBpVal], 0)) >  @Zero)
		AND 
		(@ShowUnPaid <> 0 OR (ISNULL( [b].[FixedBpVal], 0) - [en].[FixedEnCredit])> @Zero OR (ISNULL( [b].[FixedBpVal], 0) - [en].[FixedEnDebit])> @Zero) 
		AND 
		(@ShowPartPaid	<> 0 OR ABS(ISNULL( [b].[FixedBpVal], 0) - [en].[FixedEnCredit]) < @Zero OR ABS(ISNULL( [b].[FixedBpVal], 0) - [en].[FixedEnDebit]) < @Zero )
		AND
		[en].[enDate] BETWEEN @StartDate AND @EndDate
		AND 
		(ISNULL(er.erParentType,0) <> 2) --‘—ÿ «” À‰«¡ «·›Ê« Ì—

	INSERT INTO [#Result]
	SELECT	
		[ac].[AccGUID],  
		[ac].[Security],  
		[en].[acName],  
		[en].[acCode], 
		[en].[acLatinName],   
		[en].[ceSecurity],  
		@UserSecurity,  
		[en].[enDate],  
		[er].[erParentGuid], 
		[er].[erParentType], 
		[en].[ceNumber],  
		[en].[enGUID],  
		[en].[ceGUID], 
		[en].[FixedEnDebit], 
		[en].[FixedEnCredit], 
		[en].[enContraAcc],
		CASE 
			WHEN [en].ceCurrencyPtr = [b].BpCurrencyGUID AND @CurGUID <> [en].ceCurrencyPtr THEN (ISNULL([b].[FixedBpVal], 0) / CASE [b].BpCurrencyVal WHEN 0 THEN 1 ELSE [b].BpCurrencyVal END) * en.ceCurrencyVal
			ELSE ISNULL([b].[FixedBpVal], 0)
		END,
		[en].[enNotes],
		ISNULL([pt].[DueDate],'1/1/1980'),
		[coCode],
		[coName],
		[coLatinName],
		[br].[Name],
		[enCostPoint],
		Class,
		0, 
		0,
		0, 
		'',
		[en].[enNumber],0
	FROM
		[dbo].[fnExtended_En_Fixed](@CurGUID) [en]  
		INNER JOIN [#AccTbl] [ac] ON [en].[enAccount] = [ac].[AccGUID]
		INNER JOIN [#DebtTbl] [d] ON [en].[enGUID] = [d].[enGUID] 
		LEFT JOIN [fnBp_Fixed](@CurGUID, @CurVal) [b] ON [en].[enGUID] = [b].[bpDebtGUID] OR [en].[enGUID] = [b].[BpPayGUID]
		LEFT JOIN [vwEr] [er] ON [en].[ceGUID] = [er].[erEntryGUID]
		LEFT JOIN [pt000] [pt] ON  [pt].[refguid] = [er].[erParentGUID]
		INNER JOIN [#BranchTbl] [br] ON br.[Guid] = [en].[ceBranch]

		 
			------ÃœÊ· «·›Ê« Ì— 
	INSERT INTO [#Result]
	SELECT 
		distinct
		[AccGUID],  
		acc.[Security],  
		acc.[Name],  
		acc.[Code], 
		acc.[LatinName],   
		ce.[Security],  
		@UserSecurity,  
		bu.[Date],  
		[erParentGuid], 
		[erParentType], 
		ce.[Number],
		0x0,
		ce.[GUID], 
		dbo.fnCalcBillTotal(bu.GUID,@CurGUID), 
		dbo.fnCalcBillTotal(bu.GUID,@CurGUID), 
		0x0,
	    CASE 
			WHEN ce.CurrencyGUID = [b].BpCurrencyGUID AND @CurGUID <> ce.CurrencyGUID THEN (ISNULL([b].[FixedBpVal], 0) / CASE [b].BpCurrencyVal WHEN 0 THEN 1 ELSE [b].BpCurrencyVal END) * ce.CurrencyVal
			ELSE ISNULL(bpPart.SumTotal,0)
		END,
		bu.Notes,
		ISNULL([pt].[DueDate],'1/1/1980') AS ptDueDate,
		[coCode],
		[coName],
		[coLatinName],
		[br].[Name],
		co.[CostGUID],
		'',
		[bu].[Vendor],
		[bu].[SalesManPtr],
		0,
		(CASE @lang 
				WHEN 0 THEN bt.Abbrev
				ELSE (CASE bt.LatinAbbrev WHEN '' THEN bt.Abbrev ELSE bt.LatinAbbrev END)
			END) + ': ' + CAST(bu.Number AS NVARCHAR(10)),
		ce.[Number],0
	FROM
		 [#EntryTbl] [ent] INNER JOIN bt000 bt  ON [ent].[Type] = bt.guid  AND (( @DebtType = 0  AND bt.bIsInput > 0) OR ( @DebtType = 1  AND bt.bIsOutput > 0))
		INNER JOIN [bu000] [bu] on bt.GUID=bu.TypeGUID
		INNER JOIN [#AccTbl] As [ac] on bu.CustAccGUID= [ac].[AccGUID] 
		INNER JOIN [vwEr] As [er] on er.erParentGUID = bu.GUID  AND er.erParentType = 2
		INNER JOIN ac000 acc on acc.GUID= ac.AccGUID
		INNER JOIN [#CostTbl2] [co] ON [co].[CostGUID] = bu.CostGUID
		INNER JOIN [#BranchTbl] [br] ON br.Guid = [bu].[Branch]
		INNER JOIN CE000 ce on ce.GUID= er.erEntryGUID
		LEFT JOIN oit000 oit on oit.BillGuid= bu.TypeGUID
		LEFT  JOIN [pt000] [pt] ON  [pt].[refguid] = [er].[erParentGUID]
		LEFT JOIN [fnBp_Fixed](@CurGUID, @CurVal) [b] ON [erParentGUID] = [b].[bpDebtGUID] OR erParentGUID= [b].[BpPayGUID]
		LEFT JOIN (SELECT DISTINCT buGUID FROM ori000) ori ON ori.buGUID = bu.GUID
		LEFT JOIN 
				(
					SELECT 
						SUM([FixedBpVal]) SumTotal,
						[bu].[GUID] AS buGuid
					FROM 
						[fnBp_Fixed](@CurGUID, @CurVal)
						INNER JOIN [bu000] As bu ON [bu].[GUID] = [bpDebtGUID] OR [bu].[GUID] = BpPayGUID
					GROUP BY 
						[bu].[GUID]
				) AS bpPart
				ON bpPart.buGuid = bu.GUID
	WHERE 
		  (@Posted = -1 OR [ce].[Isposted] = @Posted) 
		 AND ( [bu].[Date] BETWEEN @StartDate AND @EndDate )
		 AND (@ShowPaid <> 0 OR (dbo.fnCalcBillTotal(bu.GUID,@CurGUID) - ISNULL( [bpPart].[SumTotal], 0))  > @Zero ) --„”œœ
		 AND (@ShowUnPaid <> 0 OR ISNULL(bpPart.SumTotal, 0) <> 0 ) --€Ì— „”œœ
		 AND (@ShowPartPaid	<> 0 
				OR (ISNULL(bpPart.SumTotal, 0) <= 0
				OR  ISNULL(bpPart.SumTotal, 0) >= dbo.fnCalcBillTotal(bu.GUID,@CurGUID))
			 ) --„”œœ Ã“∆Ì«
		AND ((@ShowOrderBills = 1) OR ((@ShowOrderBills = 0) AND (ori.buGUID IS NULL)))
		AND NOT EXISTS
		(select  
					o.BuGuid
				FROM ori000 o inner join (
				select	distinct
						p.BillGuid
		 
						from bp000 as b
						INNER JOIN vwOrderPayments p on p.PaymentGuid = b.DebtGUID
				UNION ALL	
				select	distinct
						p.BillGuid
		 
						from bp000 as b
						INNER JOIN vwOrderPayments p on p.PaymentGuid= b.PayGUID
				) as ord on ord.BillGuid= o.POGUID
					where o.BuGuid <> 0x0 AND bu.Guid =o.BuGuid)
	
	 
	DECLARE @defCurrency UNIQUEIDENTIFIER
	SELECT @defCurrency = [myGUID] FROM vwMy WHERE myCurrencyVal = 1

	IF @ShowOrderBills = 0
	BEGIN 
	IF EXISTS (SELECT * FROM [#BillTbl] [src] INNER JOIN [bt000] [bt] ON [bt].[Guid] = [src].[Type] WHERE ([bt].[Type] = 5) OR ([bt].[Type] = 6))
	BEGIN 
		INSERT INTO [#Result]
		SELECT	
			distinct
			[ac].[AccGUID],  
			[ac].[Security],  
			[acc].[Name],  
			[acc].[Code], 
			[acc].[LatinName],   
			3,						-- ? [en].[ceSecurity],  
			@UserSecurity,  
			orp.PaymentDate,  
			[bu].buGUID,			-- ? [er].[erParentGuid], 
			2,						-- ? [er].[erParentType], 
			[bu].[buNumber],  
			[orp].[PaymentGuid],	-- [en].[enGUID],  
			[orp].[PaymentGuid],	-- [en].[ceGUID], 
			(CASE WHEN @CurGUID <> 0x00 AND @CurVal <> 0 THEN orp.UpdatedValueWithCurrency / @CurVal ELSE orp.UpdatedValue END),
			(CASE WHEN @CurGUID <> 0x00 AND @CurVal <> 0 THEN orp.UpdatedValueWithCurrency / @CurVal ELSE orp.UpdatedValue END),
			0x0,					-- [en].[enContraAcc],
			CASE WHEN bp.bpCurrencyGUID <> @defCurrency AND bu.buCurrencyPtr = @defCurrency THEN 
				(ISNULL([bp].[FixedBpVal], 0) / [bp].BpCurrencyVal) * @CurVAL 
			ELSE
				ISNULL([bp].[FixedBpVal], 0)
			END,
			-- 0,
			[bu].[buNotes],
			[orp].[DueDate],
			[coCode],
			[coName],
			[coLatinName],
			[br].[Name],
			[bu].[buCostPtr],
			'',
			[bu].[buVendor],
			[bu].[buSalesManPtr],
			1,
			(CASE @lang 
				WHEN 0 THEN bt.Abbrev
				ELSE (CASE bt.LatinAbbrev WHEN '' THEN bt.Abbrev ELSE bt.LatinAbbrev END)
			END) + ': ' + CAST(bu.buNumber AS NVARCHAR(10)),
			[bu].[buNumber],0
		FROM
			[#BillTbl] [src]
			INNER JOIN [bt000] [bt] ON [bt].[Guid] = [src].[Type] AND (((@DebtType = 0  AND [bt].[bIsInput] > 0) OR (@DebtType = 1  AND [bt].[bIsInput] = 0)))
			INNER JOIN [dbo].[fnBu_Fixed](@CurGUID) As [bu] on [src].[Type]= [bu].[buType] 
			INNER JOIN [#AccTbl] As [ac] on [ac].[AccGUID] =[bu].[buCustAcc] 
			INNER JOIN [vwOrderPayments]  As [orp] on [orp].[BillGuid]=[bu].[buGuid] 
			INNER JOIN [ac000] As [acc] on [acc].[Guid] = [ac].[AccGUID] 
			INNER JOIN [#CostTbl2] [co] ON [co].[CostGuid] = [bu].[buCostPtr]
			INNER JOIN [#BranchTbl] [br] ON br.[Guid] = [bu].[buBranch]
			LEFT JOIN [fnBp_Fixed](@CurGUID, @CurVal) As [bp] on( [orp].[PaymentGuid] = [bp].[bpDebtGUID] OR [orp].[PaymentGuid] = [bp].BpPayGUID ) 
			LEFT JOIN 
					(
						SELECT 
							SUM([FixedBpVal]) SumTotal,
							o.PaymentGuid
						FROM 
							[fnBp_Fixed](@CurGUID, @CurVal)
							INNER JOIN [vwOrderPayments] As o ON o.[PaymentGuid] = [bpDebtGUID] 
						GROUP BY 
							o.PaymentGuid
						union all
						SELECT 
							SUM([FixedBpVal]) SumTotal,
							o.PaymentGuid
						FROM 
							[fnBp_Fixed](@CurGUID, @CurVal)
							INNER JOIN [vwOrderPayments] As o ON  o.[PaymentGuid] = BpPayGUID
						GROUP BY 
							o.PaymentGuid
					) AS bpPart
					ON bpPart.PaymentGuid = orp.PaymentGuid
		WHERE 
			(@ShowPaid <> 0 OR (orp.UpdatedValue - ISNULL(bpPart.SumTotal, 0)) >  @Zero)
			AND 
			(@ShowUnPaid <> 0 OR ISNULL(bpPart.SumTotal, 0) <> 0)
			AND 
			(	
				@ShowPartPaid <> 0 
				OR (ISNULL(bpPart.SumTotal, 0) <= 0 
				OR ISNULL(bpPart.SumTotal, 0) >= orp.UpdatedValue)
			)
			AND
			[bu].[buDate] BETWEEN @StartDate AND @EndDate
			AND
			orp.UpdatedValueWithCurrency <> 0
			AND  NOT EXISTS (SELECT  
											o.PaymentGuid
									FROM vwOrderPayments o INNER JOIN (
										SELECT	DISTINCT
												p.POGUID
												FROM bp000 as b
												INNER JOIN ori000 p on p.BuGuid = b.DebtGUID
												union all
												SELECT	DISTINCT
												p.POGUID
												FROM bp000 as b
												INNER JOIN ori000 p on p.BuGuid = b.PayGUID
												) as ord on ord.POGUID= o.BillGuid 
												WHERE orp.PaymentGuid=PaymentGuid
											)
											 
		
	END 
	END 

	UPDATE r 
	SET DueDate = ch.DueDate ,
		PaymentFormattedNumber=doc
	FROM 
	er000 er
		INNER JOIN [#Result] r   ON er.EntryGuid = ceGuid 
		INNER JOIN ( SELECT MIN(DueDate) DueDate
							,v.Guid
							,parentGuid
							 ,(CASE @lang 
				WHEN 0 THEN nt.Abbrev
				ELSE (CASE nt.LatinAbbrev WHEN '' THEN nt.Abbrev ELSE nt.LatinAbbrev END)
			END) + ': ' + CAST(v.Number AS NVARCHAR(10)) as doc
			
			 FROM  nt000 nt inner join vbch v on nt.GUID=v.TypeGUID WHERE  v.STATE = 0  GROUP BY v.Guid,v.Number,nt.LatinAbbrev,nt.Abbrev,parentGuid) ch ON ch.[GUID] = er.ParentGuid 
	WHERE 
		r.DueDate = '1/1/1980' 
		AND 
		er.ParentType IN(5, 6, 7, 8)

		UPDATE res
			SET PaymentFormattedNumber=(CASE @lang WHEN 0 THEN [et].[Abbrev] ELSE (CASE [et].[LatinAbbrev] WHEN '' THEN [et].[Abbrev] ELSE [et].[LatinAbbrev] END) END) + 
							+ ': ' + CAST(py.Number AS VARCHAR(10)) 
		FROM 
		#result res
		INNER JOIN [py000] AS [py] ON [res].[ParentGUID] = [py].[GUID]  
		INNER JOIN [et000] AS [et] ON [py].[TypeGUID] = [et].[Guid]  

		UPDATE res
			SET PaymentFormattedNumber = dbo.fnStrings_get('Entry', DEFAULT) + ': ' + CAST(res.ceNumber AS NVARCHAR(10))
		FROM 
		#result res
		where PaymentFormattedNumber=''

	SELECT  
		@MainAcc AS MainAcc,
		[AccGUID],   
		[AccCode],
		CASE @Lang WHEN 0 THEN AccName ELSE CASE [AccLatinName] WHEN '' THEN AccName ELSE [AccLatinName] END END as AccName,
		[Date], 
		ISNULL([ParentGUID],0x0) [ParentGUID], 
		ISNULL([ParentType],0x0) [ParentType], 
		[ceNumber], 
		[enGUID], 
		[ceGUID], 
		ISNULL([Debit],0) [Debit], 
		ISNULL([Credit],0) [Credit],
		[ContraAcc],
		SUM( [Val]) AS [Val],
		[Note] AS [Notes],
		[DueDate],
		[coCode],
		CASE @Lang WHEN 0 THEN [coName] ELSE CASE [coLatinName] WHEN '' THEN [coName] ELSE [coLatinName] END END as [coName],
		[brName],
		[CostGUID],
		[Class],
		[Vendor],
		[SalesMan],
		ISNULL([PaymentType],0) [PaymentType],
		[PaymentFormattedNumber],
		RowNumber 
	INTO #FinalResult
	FROM 
		[#Result] 
	GROUP BY  
		[AccCode],
		[AccGUID],
		[AccName],
		[AccLatinName],
		[Date],
		[ParentGUID],
		[ParentType],
		[ceNumber],
		[enGUID],
		[ceGUID],
		[Debit],
		[Credit],
		[ContraAcc],
		[Note],
		[DueDate],
		[coCode],
		[coName],
		[coLatinName],
		[brName],
		[CostGUID],
		[Class],
		[Vendor],
		[SalesMan],
		[PaymentType],
		[PaymentFormattedNumber],
		[enNumber],
		RowNumber
		HAVING (@DebtType = 1 AND ((ABS(Debit - SUM ([Val])) = 0 AND @ShowPaid = 1) OR (ABS(Debit - SUM ([Val])) > 0))) OR (@DebtType = 0 AND ((ABS(Credit - SUM ([Val])) = 0 AND @ShowPaid = 1) OR (ABS(Credit - SUM ([Val])) > 0)))
	ORDER BY
		[AccCode],
		[AccGUID],
		CASE @Sort 
			WHEN 0 THEN [Date] 
			ELSE [DueDate]
		END,
		[ceNumber],
		[enNumber]

		;WITH cte_RowNumber AS
		(
		  SELECT *
			, new_row_id=ROW_NUMBER() OVER (ORDER BY ceNumber )
		  FROM #FinalResult
		)
		
		UPDATE cte_RowNumber
		SET RowNumber = new_row_id

		SELECT 
				*,case when @DebtType = 1 then debit else credit end as DEBTCol
				,case when abs(val- case when @DebtType = 1 then debit else credit end) < 10.e-9 then (case when @DebtType = 1 then debit else credit end) else val end as PAIDCOL
				,case when abs(val- case when @DebtType = 1 then debit else credit end) < 10.e-9 then 2  else case when (case when @DebtType = 1 then debit else credit end) - val > 0 then (case when val = 0 then 0 else 1 end )else 0 end end as flag
				,case when abs(val- case when @DebtType = 1 then debit else credit end) < 10.e-9 then 0 else (case when @DebtType = 1 then debit else credit end) - val end as LEFTCOL
				,ISNULL((SELECT CASE @Lang WHEN 0 THEN Name ELSE CASE [LatinName] WHEN '' THEN Name ELSE [LatinName] END END from ac000 where guid=ContraAcc),'') as ACC
			FROM 
				#FinalResult 

	IF @m_PayDetails =1
	BEGIN
	CREATE TABLE [#Result2] (
		[AccGUID] [UNIQUEIDENTIFIER], 
		[AccSecurity] [INT],   
		[AccName] [NVARCHAR](255),  
		[AccCode] [NVARCHAR](255),  
		[Security] [INT], 
		[UserSecurity] [INT], 
		[Date] [DATETIME], 
		[ParentGUID] [UNIQUEIDENTIFIER], 
		[ParentType] [INT], 
		[ceNumber] [INT], 
		[enGUID] [UNIQUEIDENTIFIER], 
		[ceGUID] [UNIQUEIDENTIFIER], 
		[bpGUID] [UNIQUEIDENTIFIER], 
		[Debit] [FLOAT], 
		[Credit] [FLOAT], 
		[Notes] [NVARCHAR](1000),
		[Val] [FLOAT] ,
		enCostPoint UNIQUEIDENTIFIER,
		coName	[NVARCHAR](255),
		coCode	[NVARCHAR](255),
		class	[NVARCHAR](255),
		RowNumber INT,
		PaymentFormattedNumber [NVARCHAR](MAX)) 

		;WITH PaymentTable as
		(
			(SELECT (CASE 
								WHEN enguid = 0x0 THEN 
								[ParentGUID] ELSE [enGUID] END) as PGuid
							,RowNumber
						FROM  #FinalResult)
		)
		INSERT INTO [#Result2] 
		SELECT	
		
			[en].[acGUID],
			[en].[acSecurity],  
			[en].[acName],  
			[en].[acCode],  
			[en].[ceSecurity],  
			@UserSecurity,  
			[en].[enDate],  
			[er].[erParentGuid], 
			ISNULL( [er].[erParentType], 0), 
			[en].[ceNumber],  
			[en].[enGUID],  
			[en].[ceGUID], 
			[b].[GUID], 
			[en].[FixedEnDebit], 
			[en].[FixedEnCredit], 
			[en].[enNotes], 
			case when b.CurrencyGUID = @CurGUID then ISNULL( [b].val, 0)/b.CurrencyVal ELSE  ISNULL( [b].val, 0)/@CurVAL END,
			en2.CostGuid,
			CASE @Lang WHEN 0 THEN ISNULL(coName,'') ELSE CASE ISNULL(coLatinName,'')  WHEN '' THEN ISNULL(coName,'')ELSE ISNULL(coLatinName,'')  END END as [coName],
			ISNULL(coCode,'') coCode,
			enclass,
			RowNumber,
			''
		FROM 
			 PaymentTable INNER JOIN bp000 As [b] on  [b].[DebtGUID] = PGuid --OR [b].[PayGUID] = k 
			INNER JOIN [dbo].[fnExtended_En_Fixed]( @CurGUID) As [en]   on ((  [b].[PayGUID]=[en].[enGUID] AND [b].[PayGUID] != PGuid) )--OR ([b].[DebtGUID] =[en].[enGUID] AND [b].[DebtGUID] != k))
			INNER JOIN [en000] en2 on (([b].[PayGUID]=[en2].[GUID]   AND [b].[PayGUID] != PGuid) )--OR ( [b].[DebtGUID] =[en2].[GUID] AND [b].[DebtGUID] != k))
			LEFT JOIN [vwEr] As [er] on   [er].[erEntryGUID]=[en].[ceGUID]
			LEFT JOIN [vwCo] [co] ON coGuid =  en2.CostGuid
		UNION ALL	
		SELECT	
			[en].[acGUID],
			[en].[acSecurity],  
			[en].[acName],  
			[en].[acCode],  
			[en].[ceSecurity],  
			@UserSecurity,  
			[en].[enDate],  
			[er].[erParentGuid], 
			ISNULL( [er].[erParentType], 0), 
			[en].[ceNumber],  
			[en].[enGUID],  
			[en].[ceGUID], 
			[b].[GUID], 
			[en].[FixedEnDebit], 
			[en].[FixedEnCredit], 
			[en].[enNotes], 
			case when b.CurrencyGUID = @CurGUID then ISNULL( [b].val, 0)/b.CurrencyVal ELSE  ISNULL( [b].val, 0)/@CurVAL END,
			en2.CostGuid,
			CASE @Lang WHEN 0 THEN ISNULL(coName,'') ELSE CASE ISNULL(coLatinName,'')  WHEN '' THEN ISNULL(coName,'')ELSE ISNULL(coLatinName,'')  END END as [coName],
			ISNULL(coCode,'') coCode,
			enclass,
			RowNumber,
			''
		FROM 
			 PaymentTable INNER JOIN bp000 As [b] on  [b].[PayGUID] = PGuid 
			INNER JOIN [dbo].[fnExtended_En_Fixed]( @CurGUID) As [en]   on ([b].[DebtGUID] =[en].[enGUID] AND [b].[DebtGUID] != PGuid)
			INNER JOIN [en000] en2 on (( [b].[DebtGUID] =[en2].[GUID] AND [b].[DebtGUID] != PGuid))
			LEFT JOIN [vwEr] As [er] on   [er].[erEntryGUID]=[en].[ceGUID]
			LEFT JOIN [vwCo] [co] ON coGuid =  en2.CostGuid
		UNION ALL
			SELECT	 
			[ac].[GUID],
			[ac].[Security],  
			[ac].[Name],  
			[ac].[Code],  
			[bu].[Security],  
			@UserSecurity,  
			[bu].[Date],  
			[bu].[GUID], 
			ISNULL( [er].[erParentType], 0), 
			[bu].[Number],  
			0x0,  
			[er].[erEntryGUID], 
			[b].[GUID], 
			dbo.fnCalcBillTotal(bu.guid,@CurGUID),
			dbo.fnCalcBillTotal(bu.guid,@CurGUID),
			[bu].[Notes], 
			case when b.CurrencyGUID = @CurGUID then ISNULL( [b].val, 0)/b.CurrencyVal ELSE  ISNULL( [b].val, 0)/@CurVAL END,
			[co].[coGUID],
			CASE @Lang WHEN 0 THEN ISNULL(coName,'') ELSE CASE ISNULL(coLatinName,'')  WHEN '' THEN ISNULL(coName,'')ELSE ISNULL(coLatinName,'')  END END as [coName],
			ISNULL(coCode,'') coCode,
			'',
			RowNumber--@Row
			,(CASE @lang 
				WHEN 0 THEN BT.Abbrev
				ELSE (CASE bt.LatinAbbrev WHEN '' THEN bt.Abbrev ELSE bt.LatinAbbrev END)
			END) + ': ' + CAST(bu.Number AS NVARCHAR(10))
		FROM 
		 PaymentTable 
			INNER JOIN bp000 As [b] on [b].[DebtGUID] = PGuid --OR [b].[PayGUID] = k 
			INNER JOIN [bu000] [bu]  on ((  [b].[PayGUID] =[bu].[GUID] AND [b].[PayGUID] != PGuid)) --OR (  [b].[DebtGUID] =bu.GUID AND [b].[DebtGUID] != k))
			INNER JOIN [bt000] [bt] ON [bt].[Guid] = bu.[TypeGUID] 
			INNER JOIN vwer [er] on [er].[erParentGUID] = [bu].[GUId]
			INNER JOIN ac000 ac on bu.CustAccGUID = ac.GUID
			LEFT JOIN (SELECT DISTINCT buGUID FROM ori000) ori ON ori.buGUID = bu.GUID
			LEFT JOIN [vwCo] [co] ON coGuid =  bu.CostGUID
		UNION ALL 
		SELECT	 
			[ac].[GUID],
			[ac].[Security],  
			[ac].[Name],  
			[ac].[Code],  
			[bu].[Security],  
			@UserSecurity,  
			[bu].[Date],  
			[bu].[GUID], 
			ISNULL( [er].[erParentType], 0), 
			[bu].[Number],  
			0x0,  
			[er].[erEntryGUID], 
			[b].[GUID], 
			dbo.fnCalcBillTotal(bu.guid,@CurGUID),
			dbo.fnCalcBillTotal(bu.guid,@CurGUID),
			[bu].[Notes], 
			case when b.CurrencyGUID = @CurGUID then ISNULL( [b].val, 0)/b.CurrencyVal ELSE  ISNULL( [b].val, 0)/@CurVAL END,
			[co].[coGUID],
			CASE @Lang WHEN 0 THEN ISNULL(coName,'') ELSE CASE ISNULL(coLatinName,'')  WHEN '' THEN ISNULL(coName,'')ELSE ISNULL(coLatinName,'')  END END as [coName],
			ISNULL(coCode,'') coCode,
			'',
			RowNumber--@Row
			,(CASE @lang 
				WHEN 0 THEN BT.Abbrev
				ELSE (CASE bt.LatinAbbrev WHEN '' THEN bt.Abbrev ELSE bt.LatinAbbrev END)
			END) + ': ' + CAST(bu.Number AS NVARCHAR(10))
		FROM 
		 PaymentTable 
			INNER JOIN bp000 As [b] on  [b].[PayGUID] = PGuid 
			INNER JOIN [bu000] [bu]  on  (  [b].[DebtGUID] =bu.GUID AND [b].[DebtGUID] != PGuid)
			INNER JOIN [bt000] [bt] ON [bt].[Guid] = bu.[TypeGUID] 
			INNER JOIN vwer [er] on [er].[erParentGUID] = [bu].[GUId]
			INNER JOIN ac000 ac on bu.CustAccGUID = ac.GUID
			LEFT JOIN (SELECT DISTINCT buGUID FROM ori000) ori ON ori.buGUID = bu.GUID
			LEFT JOIN [vwCo] [co] ON coGuid =  bu.CostGUID
		UNION ALL
		SELECT	
		distinct 
			[ac].[acGUID],
			[ac].[acSecurity],  
			[ac].[acName],  
			[ac].[acCode],  
			3, -- [en].[ceSecurity],  
			@UserSecurity,  
			[bu].[buDate],  
			[bu].buGUID, 
			2,					-- ISNULL([er].[erParentType], 0), 
			[bu].[buNumber],  
			[orp].[PaymentGuid],
			0x0,				-- [en].[ceGUID], 
			[b].[bpGUID], 
			[bu].FixedBuTotal, 
			[bu].FixedBuTotal, 
			[bu].[buNotes], 
			ISNULL([b].[FixedBpVal], 0),
			bu.buCostPtr,
			CASE @Lang WHEN 0 THEN ISNULL(coName,'') ELSE CASE ISNULL(coLatinName,'')  WHEN '' THEN ISNULL(coName,'')ELSE ISNULL(coLatinName,'')  END END as [coName],
			ISNULL(coCode,'') coCode,
			'',
			RowNumber,
			(CASE @lang 
				WHEN 0 THEN BU.BTAbbrev
				ELSE (CASE bu.btLatinAbbrev WHEN '' THEN bu.btAbbrev ELSE bu.btLatinAbbrev END)
			END) + ': ' + CAST(bu.buNumber AS NVARCHAR(10))
		FROM 
		[vwOrderPayments]  As [orp]
		INNER JOIN [dbo].[fnBu_Fixed](@CurGUID) As [bu] ON [orp].[BillGuid] =[bu].[buGuid] 
		INNER JOIN [fnBp_Fixed]( @CurGUID, @CurVal) As [b] ON [orp].[PaymentGuid] = [b].[BpPayGUID] --or orp.PaymentGuid = b.[BpDebtGUID]
		INNER JOIN  PaymentTable  ON ([b].[bpDebtGUID] = PGuid or b.BpPayGUID=PGuid )and orp.PaymentGuid <> PGuid			
		INNER JOIN [vwAc] ac ON ac.acGUID = [bu].buCustAcc 
		LEFT JOIN [vwCo] [co] ON coGuid =  bu.buCostPtr
		UNION ALL 
		SELECT	
		distinct 
			[ac].[acGUID],
			[ac].[acSecurity],  
			[ac].[acName],  
			[ac].[acCode],  
			3, -- [en].[ceSecurity],  
			@UserSecurity,  
			[bu].[buDate],  
			[bu].buGUID, 
			2,					-- ISNULL([er].[erParentType], 0), 
			[bu].[buNumber],  
			[orp].[PaymentGuid],
			0x0,				-- [en].[ceGUID], 
			[b].[bpGUID], 
			[bu].FixedBuTotal, 
			[bu].FixedBuTotal, 
			[bu].[buNotes], 
			ISNULL([b].[FixedBpVal], 0),
			bu.buCostPtr,
			CASE @Lang WHEN 0 THEN ISNULL(coName,'') ELSE CASE ISNULL(coLatinName,'')  WHEN '' THEN ISNULL(coName,'')ELSE ISNULL(coLatinName,'')  END END as [coName],
			ISNULL(coCode,'') coCode,
			'',
			RowNumber,
			(CASE @lang 
				WHEN 0 THEN BU.BTAbbrev
				ELSE (CASE bu.btLatinAbbrev WHEN '' THEN bu.btAbbrev ELSE bu.btLatinAbbrev END)
			END) + ': ' + CAST(bu.buNumber AS NVARCHAR(10))
		FROM 
		[vwOrderPayments]  As [orp]
		INNER JOIN [dbo].[fnBu_Fixed](@CurGUID) As [bu] ON [orp].[BillGuid] =[bu].[buGuid]
		INNER JOIN [fnBp_Fixed]( @CurGUID, @CurVal) As [b] ON [orp].[PaymentGuid] = [b].[BpPayGUID] --or orp.PaymentGuid = b.[BpDebtGUID]
		INNER JOIN  PaymentTable  ON ([b].[bpDebtGUID] = PGuid or b.BpPayGUID=PGuid )and orp.PaymentGuid <> PGuid			
		INNER JOIN [vwAc] ac ON ac.acGUID = [bu].buCustAcc 
		LEFT JOIN [vwCo] [co] ON coGuid =  bu.buCostPtr

		EXEC prcCheckBillPaySec
	
		UPDATE res
			SET PaymentFormattedNumber=(CASE @lang WHEN 0 THEN [et].[Abbrev] ELSE (CASE [et].[LatinAbbrev] WHEN '' THEN [et].[Abbrev] ELSE [et].[LatinAbbrev] END) END) + 
							+ ': ' + CAST(py.Number AS VARCHAR(10)) 
		FROM 
		#result2 res
		INNER JOIN [py000] AS [py] ON [res].[ParentGUID] = [py].[GUID]  
		INNER JOIN [et000] AS [et] ON [py].[TypeGUID] = [et].[Guid]  

		UPDATE res
			SET PaymentFormattedNumber = dbo.fnStrings_get('Entry', DEFAULT) + ': ' + CAST(res.ceNumber AS NVARCHAR(10))
		FROM 
		#result2 res
		where PaymentFormattedNumber=''


	UPDATE r 
	SET 
		PaymentFormattedNumber=doc
	FROM 
	er000 er
		INNER JOIN [#Result2] r   ON er.EntryGuid = ceGuid 
		INNER JOIN ( SELECT MIN(DueDate) DueDate
							,v.Guid
							,parentGuid
							 ,(CASE @lang 
				WHEN 0 THEN nt.Abbrev
				ELSE (CASE nt.LatinAbbrev WHEN '' THEN nt.Abbrev ELSE nt.LatinAbbrev END)
			END) + ': ' + CAST(v.Number AS NVARCHAR(10)) as doc
			
			 FROM  nt000 nt inner join vbch v on nt.GUID=v.TypeGUID WHERE  v.STATE = 0  GROUP BY v.Guid,v.Number,nt.LatinAbbrev,nt.Abbrev,parentGuid) ch ON ch.[GUID] = er.ParentGuid 
	WHERE 
		er.ParentType IN(5, 6, 7, 8)


		SELECT distinct *
		, val as PAIDCOL
		 FROM #Result2
		ORDER BY RowNumber
	END
	SELECT * FROM [#SecViol]
######################################################################################
CREATE PROC prcGetRelatedPays
	@EnGUID 		[UNIQUEIDENTIFIER],--biil or enEntry or orderPayment
	@CurGUID 		[UNIQUEIDENTIFIER],
	@CurVAL 		[FLOAT],
	@CustGuid       [UNIQUEIDENTIFIER] = 0x0
AS
	SET NOCOUNT ON

	CREATE TABLE #R
	(
		[AccGUID]					[UNIQUEIDENTIFIER], 
		[AccSecurity]				[INT],   
		[AccName]					[NVARCHAR](255),  
		[CustName]					[NVARCHAR](255), 
		[CustGUID]					[UNIQUEIDENTIFIER], 
		[AccCode]					[NVARCHAR](255),  
		[Security]					[INT], 
		[UserSecurity]				[INT], 
		[Date]						[DATETIME], 
		[ParentGUID]				[UNIQUEIDENTIFIER], 
		[ParentType]				[INT], 
		[ceNumber]					[INT], 
		[enGUID]					[UNIQUEIDENTIFIER], 
		[ceGUID]					[UNIQUEIDENTIFIER], 
		[bpGUID]					[UNIQUEIDENTIFIER], 
		[Debit]						[FLOAT], 
		[Credit]					[FLOAT], 
		[Notes]						[NVARCHAR](1000),
		[Val]						[FLOAT] ,
		[enCostPoint]				[UNIQUEIDENTIFIER],
		[coName]					[NVARCHAR](255),
		[coLatinName]				[NVARCHAR](255),
		[coCode]					[NVARCHAR](255),
		[class]						[NVARCHAR](255),
		[PaymentFormattedNumber]	[NVARCHAR](255))
	
	DECLARE @ShowOrderBills	[BIT]
	SET @ShowOrderBills = ISNULL((SELECT (CASE [Value] WHEN '1' THEN 1 ELSE 0 END) FROM op000 WHERE Name = 'AmnCfg_ShowOrderBills' AND UserGUID = [dbo].[fnGetCurrentUserGUID]()), 0)
	DECLARE @UserGUID 	[UNIQUEIDENTIFIER], @UserSecurity [INT] 	DECLARE @lang INT 
		
	SET @lang = [dbo].[fnConnections_GetLanguage]()
	SET @UserGUID = [dbo].[fnGetCurrentUserGUID]() 
	SET @UserSecurity = [dbo].[fnGetUserEntrySec_Browse](@UserGUID, default) 

	SELECT 
		[GUID],
		CASE WHEN DebtGUID = @EnGUID THEN PayGUID ELSE DebtGUID END AS PGuid,
		CurrencyGUID,
		CurrencyVal,
		Val
	INTO #BP
	FROM bp000 
	WHERE 
		@EnGUID IN(DebtGUID, PayGUID)

	INSERT INTO #R
	SELECT	 
		[en].[acGUID],
		[en].[acSecurity],  
		[en].[acName],
		ISNULL([cu].[cuCustomerName], ''), 
		ISNULL([cu].[cuGUID], 0x0), 
		[en].[acCode],  
		[en].[ceSecurity],  
		@UserSecurity,  
		[en].[enDate],  
		[er].[erParentGuid], 
		ISNULL( [er].[erParentType], 0), 
		[en].[ceNumber],  
		[en].[enGUID],  
		[en].[ceGUID], 
		[b].[GUID], 
		[en].[FixedEnDebit], 
		[en].[FixedEnCredit], 
		[en].[enNotes], 
		case when b.CurrencyGUID = @CurGUID then ISNULL( [b].val, 0)/b.CurrencyVal ELSE  ISNULL( [b].val, 0)/@CurVAL END,
		en.enCostPoint,
		ISNULL(coName,'') coName,
		ISNULL(coLatinName,'') coLatinName,
		ISNULL(coCode,'') coCode,
		enclass,
		''
	FROM 
		[dbo].[fnExtended_En_Fixed]( @CurGUID) As [en]  
		INNER JOIN #BP AS [b] ON b.PGuid = en.enGUID AND en.enGUID <> @EnGUID
		LEFT JOIN [vwEr] As [er] on [en].[ceGUID] = [er].[erEntryGUID]
		LEFT JOIN [vwCo] [co] ON coGuid =  en.enCostPoint
		LEFT JOIN [vwCu] [cu] ON [cu].[cuGUID] = en.enCustomerGUID
		
	INSERT INTO #R 
	SELECT	 
		[ac].[GUID],
		[ac].[Security],  
		[ac].[Name],
		ISNULL([cu].[cuCustomerName], ''), 
		ISNULL([cu].[cuGUID], 0x0), 
		[ac].[Code],  
		[bu].[Security],  
		@UserSecurity,  
		[bu].[Date],  
		[bu].[GUID], 
		ISNULL( [er].[erParentType], 0), 
		[bu].[Number],  
		0x0,  
		[er].[erEntryGUID], 
		[b].[GUID], 
		dbo.fnCalcBillTotal(bu.guid,@CurGUID),
		dbo.fnCalcBillTotal(bu.guid,@CurGUID),
		[bu].[Notes], 
		case when b.CurrencyGUID = @CurGUID then ISNULL( [b].val, 0)/b.CurrencyVal ELSE  ISNULL( [b].val, 0)/@CurVAL END,
		[co].[coGUID],
		ISNULL(coName,'') coName,
		ISNULL(coLatinName,'') coLatinName,
		ISNULL(coCode,'') coCode,
		'',
		(CASE @lang 
				WHEN 0 THEN BT.Abbrev
				ELSE (CASE bt.LatinAbbrev WHEN '' THEN bt.Abbrev ELSE bt.LatinAbbrev END)
			END) + ': ' + CAST(bu.Number AS NVARCHAR(10))
	FROM 
		[bu000] [bu]  
		INNER JOIN [bt000] [bt] ON [bt].[Guid] = bu.[TypeGUID] 
		INNER JOIN vwer [er] ON [er].[erParentGUID] = [bu].[GUId]
		--INNER JOIN bp000 As [b] ON (([bu].[GUID] = [b].[PayGUID] AND [b].[PayGUID] != @EnGUID) OR (bu.GUID = [b].[DebtGUID] AND [b].[DebtGUID] != @EnGUID))
		INNER JOIN #BP AS [b] ON b.PGuid = bu.GUID AND bu.GUID <> @EnGUID
		INNER JOIN ac000 ac ON bu.CustAccGUID = ac.GUID
		LEFT JOIN vwCu cu ON cu.cuGUID = bu.CustGUID
		LEFT JOIN (SELECT DISTINCT buGUID FROM ori000) ori ON ori.buGUID = bu.GUID
		LEFT JOIN [vwCo] [co] ON coGuid =  bu.CostGUID
		
	INSERT INTO #R
	SELECT	 
		[ac].[acGUID],
		[ac].[acSecurity],  
		[ac].[acName],
		ISNULL([cu].[cuCustomerName], ''), 
		ISNULL([cu].[cuGUID], 0x0), 
		[ac].[acCode],  
		3, -- [en].[ceSecurity],  
		@UserSecurity,  
		[bu].[buDate],  
		[bu].buGUID, 
		2,					-- ISNULL([er].[erParentType], 0), 
		[bu].[buNumber],  
		[orp].[PaymentGuid],
		0x0,				-- [en].[ceGUID], 
		[b].[GUID], 
		[bu].FixedBuTotal, 
		[bu].FixedBuTotal, 
		[bu].[buNotes], 
		--ISNULL([b].[FixedBpVal], 0),
		case when b.CurrencyGUID = @CurGUID then ISNULL( [b].val, 0)/b.CurrencyVal ELSE  ISNULL( [b].val, 0)/@CurVAL END,
		bu.buCostPtr,
		ISNULL(coName,'') coName,
		ISNULL(coLatinName,'') coLatinName,
		ISNULL(coCode,'') coCode,
		'',
		(CASE @lang 
				WHEN 0 THEN BU.BTAbbrev
				ELSE (CASE bu.btLatinAbbrev WHEN '' THEN bu.btAbbrev ELSE bu.btLatinAbbrev END)
			END) + ': ' + CAST(bu.buNumber AS NVARCHAR(10))
	FROM 
		[dbo].[fnBu_Fixed](@CurGUID) As [bu] 
		INNER JOIN [vwAc] ac ON ac.acGUID = [bu].buCustAcc
		INNER JOIN [vwOrderPayments] AS [orp] on [bu].[buGuid] = [orp].[BillGuid]
		--INNER JOIN [fnBp_Fixed]( @CurGUID, @CurVal) As [b] on [orp].[PaymentGuid] = [b].[BpPayGUID] or orp.PaymentGuid = b.[BpDebtGUID]
		INNER JOIN #BP AS [b] ON b.PGuid = orp.PaymentGuid AND orp.PaymentGuid <> @EnGUID
		LEFT JOIN [vwCu] cu ON cu.cuGUID = bu.buCustPtr
		LEFT JOIN [vwCo] [co] ON coGuid =  bu.buCostPtr
			
	UPDATE Res
	SET 
		PaymentFormattedNumber = (CASE @lang WHEN 0 THEN [et].[Abbrev]
									ELSE (CASE [et].[LatinAbbrev] WHEN '' THEN [et].[Abbrev] 
									ELSE [et].[LatinAbbrev] END) END) + ': ' + CAST(py.Number AS VARCHAR(10)) 
	FROM 
		#R Res
		INNER JOIN [py000] AS [py] ON [res].[ParentGUID] = [py].[GUID]  
		INNER JOIN [et000] AS [et] ON [py].[TypeGUID] = [et].[Guid]  
	UPDATE Res
	SET 
		PaymentFormattedNumber = dbo.fnStrings_get('Entry', DEFAULT) + ': ' + CAST(Res.ceNumber AS NVARCHAR(10))
	FROM 
		#R Res
	WHERE 
		PaymentFormattedNumber=''
	UPDATE Res 
	SET 
		PaymentFormattedNumber = doc
	FROM 
		er000 er
		INNER JOIN #R Res ON er.EntryGuid = ceGuid 
		INNER JOIN (SELECT 
						MIN(DueDate) DueDate
						,v.Guid
						,parentGuid
						,(CASE @lang WHEN 0 THEN nt.Abbrev
							ELSE (CASE nt.LatinAbbrev WHEN '' THEN nt.Abbrev 
							ELSE nt.LatinAbbrev END) END) + ': ' + CAST(v.Number AS NVARCHAR(10)) as doc
					FROM  
						nt000 nt 
						INNER JOIN vbch v on nt.GUID=v.TypeGUID 
					WHERE 
						v.STATE = 0 GROUP BY v.Guid, v.Number, nt.LatinAbbrev, nt.Abbrev,parentGuid) ch ON ch.[GUID] = er.ParentGuid 
	WHERE 
		er.ParentType IN(5, 6, 7, 8)

	SELECT * FROM #R
########################################################################################
#END

