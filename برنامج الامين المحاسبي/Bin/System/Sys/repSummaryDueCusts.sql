##################################################################################
CREATE PROCEDURE repSummaryDueCusts
	@AccGUID 				UNIQUEIDENTIFIER,
	@CostGUID 				UNIQUEIDENTIFIER,	
	@SrcGuid 				UNIQUEIDENTIFIER,
	@StartDate 				DATETIME,
	@EndDate 				DATETIME,
	@PeriodType				INT, -- 1 Daily, 2 Weekly, 3 Monthly, 4 Quarter, 5 Yearly 
	@CurGUID				UNIQUEIDENTIFIER,
	@bShowEmptyPeriods		BIT = 0,
	@IsDontShowNotDeliverd	BIT = 0,
	@IsDiscountedRecieved	BIT = 0,
	@IsEndorsedRecieved		BIT = 0

AS
	SET NOCOUNT ON 
	DECLARE @UserId UNIQUEIDENTIFIER 
	SET @UserId = [dbo].[fnGetCurrentUserGUID]() 
	--------------------------  
	CREATE TABLE [#SecViol]( [Type] [INT], [Cnt] [INTEGER])  
	-------------------------- 
	CREATE TABLE [#BillTbl]( [Type] [UNIQUEIDENTIFIER] , [Security] [INT], [ReadPriceSecurity] [INT]) 
	INSERT INTO [#BillTbl] EXEC [prcGetBillsTypesList] @SrcGuid 
	-------------------------- 
	CREATE TABLE [#NotesTbl]([Type] [UNIQUEIDENTIFIER], [Security] [INT])  
	INSERT INTO [#NotesTbl] EXEC [prcGetNotesTypesList]  @SrcGuid, @UserID 
	--------------------------	 
	CREATE TABLE [#AccTbl]( [GUID] [UNIQUEIDENTIFIER], [Security] [INT], [Level] [INT]) 
	INSERT INTO [#AccTbl] EXEC prcGetAccountsList @AccGUID	 
	--------------------------	 
 	CREATE TABLE [#Cost_Tbl] ( [GUID] [UNIQUEIDENTIFIER])  
	INSERT INTO [#Cost_Tbl] SELECT [GUID] FROM [dbo].[fnGetCostsList]( @CostGUID)   
	IF ISNULL( @CostGUID, 0x0) = 0x0    
		INSERT INTO [#Cost_Tbl] VALUES(0x00)   
	--------------------------------------------------- 
	--------------------------------------------------- 
	CREATE TABLE [#ChecksResult] 
	( 
		[acGuid]		[UNIQUEIDENTIFIER], 
		[cuGuid]		[UNIQUEIDENTIFIER], 
		[acSecurity]	[INT], 
		[cuSecurity]	[INT], 
		[chCuid]		[UNIQUEIDENTIFIER], 
		[chType]		[UNIQUEIDENTIFIER], 
		[chSecurity]	[INT], 
		[Val]			[FLOAT], 
		[DueDate]		[DATETIME],
		[BillGuid]		[UNIQUEIDENTIFIER]  
	) 
	CREATE TABLE [#RecOrPaidChecksResult] 
	( 
		[acGuid]		[UNIQUEIDENTIFIER],
		[cuGuid]		[UNIQUEIDENTIFIER],  
		[acSecurity]	[INT],
		[chCuid]		[UNIQUEIDENTIFIER], 
		[chType]		[UNIQUEIDENTIFIER], 
		[chSecurity]	[INT], 
		[Val]			[FLOAT], 
		[DueDate]		[DATETIME],
		[BillGuid]		[UNIQUEIDENTIFIER]  
	) 
	CREATE TABLE [#BillsResult] 
	( 
		[acGuid]		[UNIQUEIDENTIFIER], 
		[cuGuid]		[UNIQUEIDENTIFIER],
		[acSecurity]	[INT], 
		[cuSecurity]	[INT], 
		[buGuid]		[UNIQUEIDENTIFIER], 
		[buType]		[UNIQUEIDENTIFIER], 
		[buSecurity]	[INT], 
		[buIsInput]		[BIT], 
		[Val]			[FLOAT], 
		[DueDate]		[DATETIME], 
		[bTTC]			[BIT] 
	) 
	-- Bills  

	IF YEAR(@StartDate) = 1980 
	BEGIN
		SET @StartDate = ( SELECT TOP 1 DueDate FROM pt000 WHERE [Type] = 3 ORDER BY DueDate ) 
		DECLARE @temp DATE = ( SELECT TOP 1 DueDate FROM ch000  ORDER BY DueDate )
		IF @temp < @StartDate 
			SET @StartDate = @temp 
		SET @StartDate = DATEFROMPARTS ( YEAR(@StartDate) , MONTH(@StartDate) , 1 )
	END

	INSERT INTO [#BillsResult] 
	SELECT  
		[ac].[Guid], 
		[bu].[buCustPtr],
		[ac].[Security], 
		ISNULL([vb].[Security],0),
		[bu].[buGuid], 
		[bu].[buType], 
		[bu].[buSecurity], 
		[b].[btIsInput], 
		(CASE [b].[btVatSystem] WHEN 2 THEN 0 ELSE  
		[dbo].[fnCurrency_fix]((CASE [ptDebit] WHEN 0 THEN [ptCredit] ELSE [ptDebit] END), 
		[bu].[buCurrencyPtr], [bu].[buCurrencyVal], @CurGUID, [bu].[buDate]) 
		END), 
		[pt].[ptDueDate], 
		(CASE [b].[btVatSystem] WHEN 2 THEN 1 ELSE 0 END) 
	FROM  
		[vwBu] [bu] 
		INNER JOIN [#BillTbl] AS [bt] ON [bu].[buType] = [bt].[Type]  
		INNER JOIN [vwbt] AS [b] ON [b].[btGUID] = [bt].[Type]  
		INNER JOIN [#AccTbl]  AS [ac] ON [bu].[buCustAcc] = [ac].[GUID] 
		INNER JOIN [vwPt] AS [pt] ON [bu].[buGuid] = [pt].[ptRefGUID] 
		INNER JOIN [#Cost_Tbl] AS [Cost] ON [bu].[buCostPtr] = [Cost].[GUID]
		LEFT JOIN [vbCu] AS vb  ON [bu].[buCustPtr]= vb.GUID
	WHERE  
		-- ([bu].[buIsposted] = 1) 
		-- AND  
		([ptDueDate] BETWEEN @StartDate AND @EndDate)
	UPDATE [#BillsResult] 
	SET [Val] =  
		( 
			[fnEx].[FixedBuTotal]  
			-  
			[fnEx].[FixedbuItemsDisc]  
			-  
			[fnEx].[FixedBuBonusDisc] 
			+  
			[fnEx].[FixedbuItemExtra]   
			+  
			(ISNULL((SELECT SUM([extra] - [discount])  FROM [di000] WHERE [parentGUID] = [r].[buGUID]), 0) * [fnEx].[FixedCurrencyFactor])) 
	FROM  
			[dbo].[fn_bubi_Fixed](@CurGUID) AS [fnEx] 
			INNER JOIN [#BillsResult] [r] ON [fnEx].[buGUID] = [r].[buGuid] 
	WHERE  
		[bTTC] = 1	
		
	INSERT INTO [#BillsResult] 
	SELECT  
		[ac].[Guid], 
		[en].[CustomerGUID],
		[ac].[Security], 
		ISNULL([vb].[Security],0),
		pt.RefGUID, 
		[pt].TypeGuid, 
		0, 
		[b].[btIsInput], 
		(CASE [b].[btVatSystem] WHEN 2 THEN 0 ELSE  
		[dbo].[fnCurrency_fix]((CASE pt.[Debit] WHEN 0 THEN pt.[Credit] ELSE pt.[Debit] END), 
		pt.CurrencyGUID, 
		pt.CurrencyVal, 
		@CurGUID, 
		CAST(TransferedInfo AS XML).value('/Date[1]','DATE')) 
		END), 
		[pt].[DueDate], 
		(CASE [b].[btVatSystem] WHEN 2 THEN 1 ELSE 0 END) 
	FROM  
		[pt000] pt
		INNER JOIN [#BillTbl] AS [bt] ON [pt].TypeGuid = [bt].[Type]  
		INNER JOIN [vwbt] AS [b] ON [b].[btGUID] = [bt].[Type]  
		INNER JOIN [#AccTbl]  AS [ac] ON [pt].CustAcc = [ac].[GUID] 
		INNER JOIN en000 en ON en.ParentGUID = pt.RefGUID AND en.AccountGUID = [ac].[GUID] 
		LEFT JOIN [vbCu] AS vb  ON [en].[CustomerGUID] = vb.GUID
	WHERE   
		([DueDate] BETWEEN @StartDate AND @EndDate)


	UPDATE [Res] 
		SET [Val] = [Res].[Val] - ISNULL( [BillDebt].[DebtVal], 0) 
	FROM 
		( 
			SELECT  
				[er].[erParentGUID] AS [BillGUID], 
				SUM( [bp].[FixedBpVal]) AS [DebtVal] 
			FROM 
				[vwCeEn] AS [entry]  
				INNER JOIN [vwEr] AS [er] ON [entry].[ceGUID] = [er].[erEntryGUID] 
				LEFT JOIN [dbo].[fnBp_Fixed]( @CurGUID, 1) AS [bp] ON [entry].[enGUID] = [bp].[BpDebtGUID] OR [entry].[enGUID] = [bp].[BpPayGUID]
			WHERE bptype = 0
			GROUP BY  
				[er].[erParentGUID]  
		) AS [BillDebt] 
		INNER JOIN [#BillsResult] AS [Res] ON [Res].[buGuid] = [BillDebt].[BillGUID] 
		
	-- ===================== Remove Bill Payments from BillValue ======================================
	UPDATE [#BillsResult]
		SET [Val] *= -1
	WHERE [buIsInput] = 1

	DECLARE @Bills_C CURSOR, @acGuid UNIQUEIDENTIFIER, @acSecurity INT, @buGuid UNIQUEIDENTIFIER,
	@buType UNIQUEIDENTIFIER, @buSecurity INT, @buIsInput BIT, @Val FLOAT, @DueDate DATETIME,
	@bTTC BIT

	SET @Bills_C = CURSOR FAST_FORWARD FOR SELECT [buGuid]  FROM [#BillsResult] ORDER BY [buGuid]

	CREATE TABLE [#BillPayments]
	(
		[AccountGuid] 	[UNIQUEIDENTIFIER],
		[CurrencyGuid]	[UNIQUEIDENTIFIER],
		[BillValue]		[FLOAT],
		[IsInput]		[INT],
		[BpEnGuid]		[UNIQUEIDENTIFIER],
		[BpIsDebit]		[INT],
		[BpPayType]		[INT],
		[BpValue]		[FLOAT],
		[BpCurrencyGuid]	[UNIQUEIDENTIFIER],
		[BpCurrencyValue]	[FLOAT],
		[BpRecType]			[INT],
		[BpFirstPayType]	[INT]
	)

	OPEN @Bills_C 
	FETCH NEXT FROM @Bills_C INTO @buGuid
	WHILE @@FETCH_STATUS = 0
	BEGIN  
		DELETE FROM [#BillPayments]

		INSERT INTO [#BillPayments] EXEC prcGetBillPayments @buGuid 

		UPDATE [Res]
			SET [Res].[Val] = [Res].[Val] + ISNULL( [BillPayments].[CheckValue], 0)
		FROM 
		(
			SELECT 
			SUM((CASE [Payments].IsInput WHEN 1 THEN -1 ELSE 1 END) *
				ISNULL([dbo].[fnCurrency_fix](  Payments.[BpValue], 
												Payments.[BpCurrencyGuid], 
												Payments.[BpCurrencyValue],
												@CurGUID, 
												BILL.[DueDate]),0)) AS CheckValue
			FROM [#BillPayments] Payments
			INNER JOIN [#BillsResult] AS BILL ON BILL.[buGuid] = @buGuid
		) AS [BillPayments]
		INNER JOIN [#BillsResult] AS [Res] ON [Res].[buGuid] = @buGuid


		FETCH NEXT FROM @Bills_C INTO @buGuid
	END
	CLOSE @Bills_C 
	DEALLOCATE @Bills_C
	-- ================================================================================================
	
	-- Checks 
	INSERT INTO [#ChecksResult] 
	SELECT  
		[ac].[Guid],
		[ch].[chCustomerGUID],
		[ac].[Security], 
		ISNULL([vb].[Security],0),
		[ch].[chGuid], 
		[ch].[chType], 
		[ch].[chSecurity], 
		(CASE [ch].[chDir] WHEN 2 THEN 1 ELSE -1 END) * [dbo].[fnCurrency_fix]( [ch].[chVal]-ISNULL([colch].[collectedValue],0), [ch].[chCurrencyPtr], [ch].[chCurrencyVal], @CurGUID, [ch].[chDate]) , 		
		[ch].[chDueDate],
		[ch].[chParent] 
	FROM  
		[vwCh] [ch] 
		INNER JOIN [#NotesTbl] AS [nt] ON [ch].[chType] = [nt].[Type]  
		INNER JOIN [#AccTbl]  AS [ac] ON [ch].[chAccount] = [ac].[GUID] 
		INNER JOIN [#Cost_Tbl] AS [Cost] ON [ch].[chCost1GUID] = [Cost].[GUID] 
		LEFT  JOIN [vwcolch] as [colch]on [ch].[chGUID] = [colch].[chGUID] 
		LEFT JOIN [vbCu] AS vb  ON [ch].[chCustomerGUID]= vb.GUID
	WHERE  
		([chDueDate] BETWEEN @StartDate AND @EndDate) 
		AND	( [chState] IN (0, 2, 7, 10)  OR ([chState] = 4 AND @IsEndorsedRecieved = 0) 
		OR ([chState] = 11 AND  @IsDiscountedRecieved = 0) OR ([chState] = 14 AND  @IsDontShowNotDeliverd  = 0))  
	 
 	-- ===============================================================================================================
	--[#RecOrPaidChecksResult]
	INSERT INTO [#RecOrPaidChecksResult] 
	SELECT  
		[ac].[Guid], 
		[ch].[chCustomerGUID],
		[ac].[Security], 
		[ch].[chGuid], 
		[ch].[chType], 
		[ch].[chSecurity], 
		(CASE [ch].[chDir] WHEN 2 THEN 1 ELSE -1 END) * [dbo].[fnCurrency_fix]( [ch].[chVal]-ISNULL([colch].[collectedValue],0), [ch].[chCurrencyPtr], [ch].[chCurrencyVal], @CurGUID, [ch].[chDate]), 		
		[ch].[chDueDate],
		[ch].[chParent] 
	FROM  
		[vwCh] [ch] 
		INNER JOIN [#NotesTbl] AS [nt] ON [ch].[chType] = [nt].[Type]  
		INNER JOIN [#AccTbl]  AS [ac] ON [ch].[chAccount] = [ac].[GUID] 
		INNER JOIN [#Cost_Tbl] AS [Cost] ON [ch].[chCost1GUID] = [Cost].[GUID] 
		LEFT  JOIN [vwcolch] as [colch]on [ch].[chGUID] = [colch].[chGUID] 
	WHERE  
		([chDueDate] BETWEEN @StartDate AND @EndDate) AND [chState] = 1
	-- ===============================================================================================================
	 
	UPDATE [Res]
		SET [Res].Val += ISNULL(CheckValue, 0)
	FROM
	(
		SELECT Ch.[BillGuid],
		SUM(ISNULL(ch.Val,0)) AS CheckValue
		From [#BillsResult] BILL 
		INNER JOIN [#RecOrPaidChecksResult] Ch ON Ch.[BillGuid] = BILL.[buGuid]
		GROUP BY Ch.[BillGuid]
	) AS ChBill
	INNER JOIN [#BillsResult] AS [Res] ON ChBill.[BillGuid] = [Res].[buGuid] 


	DELETE FROM [#BillsResult] WHERE Val = 0
	-- ===============================================================================================================
	EXEC [prcCheckSecurity] @result = '#BillsResult' 
	EXEC [prcCheckSecurity] @result = '#ChecksResult' 
	--------------------------------------------------- 
	--------------------------------------------------- 
	set LANGUAGE 'arabic'
	CREATE TABLE [#Result]( [id] INT, [AccGuid] UNIQUEIDENTIFIER,[cuGuid] UNIQUEIDENTIFIER, [Val] FLOAT) 
	INSERT INTO [#Result] 
	SELECT  
		[p].[Period],  
		[r].[acGuid], 
		[r].[cuGuid],
		[r].[Val]
	FROM  
		[#ChecksResult] AS [r]  
		INNER JOIN (SELECT * FROM [fnGetPeriod]( @PeriodType, @StartDate, @EndDate)) As [p] ON [r].[DueDate] between [p].[StartDate] and [p].[EndDate] 
	GROUP BY 
		[p].[Period], 
		[r].[cuGuid],
		[r].[acGuid],
		[r].[Val] 
		 
	INSERT INTO [#Result] 
	SELECT  
		[p].[Period],  
		[r].[acGuid], 
		[r].[cuGuid],
		[r].[Val]
	FROM  
		[#BillsResult] AS [r]  
		INNER JOIN (SELECT * FROM [fnGetPeriod]( @PeriodType, @StartDate, @EndDate)) As [p] ON [r].[DueDate] between [p].[StartDate] and [p].[EndDate]  
	GROUP BY 
		[p].[Period],
		[r].[cuGuid], 
		[r].[acGuid],
		[r].[Val]

	--------------------------------------------------- 
	--------------------------------------------------- 
	CREATE TABLE [#Res] 
	( 
		[id] INT,  
		[StartDate] DATETIME,  
		[EndDate] DATETIME, 
		[AccGuid] UNIQUEIDENTIFIER, 
		[CuGuid] UNIQUEIDENTIFIER,
		[Val] FLOAT 
	) 
	INSERT INTO [#Res] 
	SELECT  
		[P].[Period], 
		[P].[StartDate],  
		[P].[EndDate],  
		ISNULL( [AccGuid], 0x0), 
		ISNULL( [CuGuid], 0x0), 
		ISNULL( [r].[val], 0) 
	FROM 
		(SELECT * FROM [fnGetPeriod]( @PeriodType, @StartDate, @EndDate))AS [P] 
		LEFT JOIN ( SELECT [Id], [AccGuid],[CuGuid], SUM ([Val]) AS [Val] FROM [#Result] GROUP BY [Id],[CuGuid], [AccGuid]) AS [r] ON [P].[Period] = [r].[Id] 
	--------------------------------------------------- 
	--------------------------------------------------- 
	CREATE TABLE [#FinalResult] 
	( 
		[PeriodId] INT, 
		[StartDate] DATETIME,  
		[EndDate] DATETIME, 
		[AccGuid] UNIQUEIDENTIFIER, 
		[CuGuid] UNIQUEIDENTIFIER,
		[AccCode] NVARCHAR(250) COLLATE ARABIC_CI_AI, 
		[AccName] NVARCHAR(250) COLLATE ARABIC_CI_AI, 
		[AccLatinName] NVARCHAR(250) COLLATE ARABIC_CI_AI, 
		[CuName] NVARCHAR(250) COLLATE ARABIC_CI_AI, 
		[CuLatinName] NVARCHAR(250) COLLATE ARABIC_CI_AI,
		[Value] FLOAT 
	) 
	INSERT INTO [#FinalResult] 
	SELECT  
		[fr].[id],  
		[fr].[StartDate],  
		[fr].[EndDate], 
		[fr].[AccGuid],		 
		ISNULL(c.GUID,0x0), 
		ISNULL( [ac].[Code], ''), 
		ISNULL( [ac].[Name], ''), 
		ISNULL( [ac].[LatinName], ''),
		ISNULL( [c].CustomerName, ''), 
		ISNULL( [c].[LatinName], ''), 
		[fr].[Val] 
	FROM  
		[#Res] [fr] 
		LEFT JOIN [ac000] [ac] ON [ac].[Guid] = [fr].[AccGuid] 
		LEFT JOIN vbCu as c on c.AccountGUID= fr.AccGuid and c.GUID=fr.CuGuid
	
	IF @bShowEmptyPeriods = 0 
		SELECT * FROM [#FinalResult] WHERE [Value] <> 0 AND [AccName] <> '' ORDER BY [PeriodId], [AccName] 
	ELSE  
		SELECT * FROM [#FinalResult] ORDER BY [PeriodId], [AccName] 

	set LANGUAGE 'english'
	SELECT * FROM [#SecViol] 
##################################################################################
CREATE VIEW vwcolch AS 
SELECT [colch].[chGUID],[colch].[CurrencyGUID], [colch].[CurrencyVal], Sum([Colch].[Val]) AS collectedValue
FROM [ColCh000] AS [ColCh] 
GROUP BY [colch].[chGUID], [colch].[CurrencyGUID], [colch].[CurrencyVal]
##################################################################################
#END
