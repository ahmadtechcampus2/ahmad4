###############################################################################
CREATE PROCEDURE prcOrder_AutoDebtPay
	@OrderGUID UNIQUEIDENTIFIER,
	@IsDebitOrder BIT	-- 1 the order in debits table, 0 in payments table 
AS  
	SET NOCOUNT ON

	DECLARE  
		@c_pays CURSOR,
		@pay_guid UNIQUEIDENTIFIER, 
		@pay_CurrencyGuid UNIQUEIDENTIFIER, 
		@pay_CurrencyValue FLOAT, 
		@pay_Value FLOAT, 
		@pay_PaidValue FLOAT, 
		@pay_DebitType INT, 
		@pay_ParentGUID UNIQUEIDENTIFIER,

		@order_CurrencyGuid UNIQUEIDENTIFIER, 
		@order_CurrencyValue FLOAT, 
		@order_Value FLOAT, 
		@order_PaidValue FLOAT, 
		@order_DebitType INT, 
		@order_ParentGUID UNIQUEIDENTIFIER
		
	IF @IsDebitOrder = 0
	BEGIN 
		SELECT 
			@order_CurrencyGuid = CurrencyGuid,
			@order_CurrencyValue = CurrencyValue, 
			@order_Value = Value, 
			@order_DebitType = PaymentType, 
			@order_ParentGUID = ParentGUID,
			@order_PaidValue = PaidValue
		FROM 
			#PaymentsTbl
		WHERE 
			PaymentGUID = @OrderGUID 
		
		SET @c_pays = CURSOR FAST_FORWARD FOR
			SELECT DebitGUID, CurrencyGuid, CurrencyValue, Value, DebitType, ParentGUID, PaidValue
			FROM [#DebitTbl] 
			WHERE DebitType = 0 AND Value > PaidValue 
			ORDER BY [DebitDate], Number
	END ELSE BEGIN 
		SELECT 
			@order_CurrencyGuid = CurrencyGuid,
			@order_CurrencyValue = CurrencyValue, 
			@order_Value = Value, 
			@order_DebitType = DebitType, 
			@order_ParentGUID = ParentGUID,
			@order_PaidValue = PaidValue
		FROM 
			[#DebitTbl]
		WHERE 
			DebitGUID = @OrderGUID 

		SET @c_pays = CURSOR FAST_FORWARD FOR 
			SELECT PaymentGUID, CurrencyGuid, CurrencyValue, Value, PaymentType, ParentGUID, PaidValue
			FROM #PaymentsTbl 
			WHERE PaymentType = 0 AND Value > PaidValue 
			ORDER BY [PaymentDate], Number 
	END 

	SET @order_Value = @order_Value - @order_PaidValue
	IF @order_Value <= 0
		RETURN

	OPEN @c_pays FETCH NEXT FROM @c_pays INTO @pay_guid, @pay_CurrencyGuid, @pay_CurrencyValue, @pay_Value, @pay_DebitType, @pay_ParentGUID, @pay_PaidValue
	WHILE @@FETCH_STATUS = 0 
	BEGIN 
		IF @order_Value <= @pay_Value - @pay_PaidValue
		BEGIN 
			INSERT INTO [bp000] ([DebtGUID], [PayGUID], [PayType], [Val], [CurrencyGUID], [CurrencyVal], [RecType], [DebitType], ParentDebitGUID, ParentPayGUID, [PayVal], [PayCurVal]) 
			VALUES( @OrderGUID, @pay_guid, @order_DebitType, @order_Value * @order_CurrencyValue, @order_CurrencyGUID, 
					@order_CurrencyValue, 0, @pay_DebitType, @order_ParentGUID, @pay_ParentGUID, @order_Value * @pay_CurrencyValue, @pay_CurrencyValue)

			IF @IsDebitOrder = 0
			BEGIN 
				UPDATE [#DebitTbl] SET PaidValue = PaidValue + @order_Value WHERE DebitGUID = @pay_guid
				UPDATE [#PaymentsTbl] SET PaidValue = Value WHERE PaymentGUID = @OrderGUID
			END 
			ELSE BEGIN  
				UPDATE [#PaymentsTbl] SET PaidValue = PaidValue + @order_Value WHERE PaymentGUID = @pay_guid
				UPDATE [#DebitTbl] SET PaidValue = Value WHERE DebitGUID = @OrderGUID
			END 

			INSERT INTO #temp VALUES(@OrderGUID, @pay_guid)
			BREAK

		END ELSE BEGIN 
			SET @order_Value = @order_Value - (@pay_Value - @pay_PaidValue)

			INSERT INTO [bp000] ([DebtGUID], [PayGUID], [PayType], [Val], [CurrencyGUID], [CurrencyVal], [RecType], [DebitType], ParentDebitGUID, ParentPayGUID, [PayVal], [PayCurVal]) 
			VALUES( @OrderGUID, @pay_guid, @order_DebitType, (@pay_Value - @pay_PaidValue) * @order_CurrencyValue, @pay_CurrencyGUID, 
					@order_CurrencyValue, 0, @pay_DebitType, @order_ParentGUID, @pay_ParentGUID, (@pay_Value - @pay_PaidValue) * @pay_CurrencyValue, @pay_CurrencyValue)

			IF @IsDebitOrder = 0
			BEGIN 
				UPDATE [#DebitTbl] SET PaidValue = Value WHERE DebitGUID = @pay_guid
				UPDATE [#PaymentsTbl] SET PaidValue = PaidValue + (@pay_Value - @pay_PaidValue) WHERE PaymentGUID = @OrderGUID
			END 
			ELSE BEGIN  
				UPDATE [#PaymentsTbl] SET PaidValue = Value WHERE PaymentGUID = @pay_guid
				UPDATE [#DebitTbl] SET PaidValue = PaidValue + (@pay_Value - @pay_PaidValue) WHERE DebitGUID = @OrderGUID
			END 

			INSERT INTO #temp VALUES(@OrderGUID, @pay_guid)

			FETCH NEXT FROM @c_pays INTO @pay_guid, @pay_CurrencyGuid, @pay_CurrencyValue, @pay_Value, @pay_DebitType, @pay_ParentGUID, @pay_PaidValue
			IF @@FETCH_STATUS <> 0 
				BREAK 
		END 
	END CLOSE @c_pays deallocate @c_pays

###############################################################################
CREATE PROCEDURE prcEntry_AutoDebtPay
	@AccGuid	[UNIQUEIDENTIFIER],  
	@StartDate	[DATETIME],  
	@EndDate	[DATETIME],  
	@DebtType	[INT], -- 0: Credit, 1: Debit,  
	@CostGuid	[UNIQUEIDENTIFIER] = 0x00 , 
	@SrcGuid [UNIQUEIDENTIFIER],
	@ShowPaid		[INT],-- 1: Show Payment, 0 DontShow
	@ShowUnPaid		[INT],-- 1: Show UnPayment, 0 DontShow
	@ShowPartPaid	[INT],-- 1: Show Part Payment, 0 DontShow
	@Posted			[INT] = -1,
	@WithCost		[INT],
	@CustGuid		[UNIQUEIDENTIFIER] = 0x00
AS  
	SET NOCOUNT ON
	DECLARE  
		@c_Acc CURSOR,  
		@c_AccGuid [UNIQUEIDENTIFIER], 
		@c_CustGuid [UNIQUEIDENTIFIER],  
		@Cost [UNIQUEIDENTIFIER],  
		@c_Debt CURSOR,  
		@c_FetchStatus [INT],  
		@d_enGUID [UNIQUEIDENTIFIER], 
		@d_enCurrencyGUID [UNIQUEIDENTIFIER],  
		@d_enCurrencyVal [FLOAT],   
		@d_Debt [FLOAT],  
		@d_PaidValue [FLOAT], 
		@c_Pay CURSOR,  
		@p_FetchStatus [INT],  
		@p_enGUID [UNIQUEIDENTIFIER],  
		@p_enCurrencyGUID [UNIQUEIDENTIFIER],  
		@p_enCurrencyVal [FLOAT],  
		@p_Pay [FLOAT], 
		@p_PaidValue [FLOAT], 
		@DebitType [INT], 
		@PaymentType [INT],
		@d_ParentGUID [UNIQUEIDENTIFIER],
		@p_parentGUID [UNIQUEIDENTIFIER],
		@DefCurr [UNIQUEIDENTIFIER]--,
		--@WithCost	[INT]
	 
	 --SET @WithCost= (SELECT value FROM op000
		--WHERE name ='AmnCfg_LinkBillPaymentWithCost'
	 --)
	DECLARE @ShowOrderBills	[BIT]
	SET @ShowOrderBills = ISNULL((SELECT (CASE [Value] WHEN '1' THEN 1 ELSE 0 END) FROM op000 WHERE Name = 'AmnCfg_ShowOrderBills' AND UserGUID = [dbo].[fnGetCurrentUserGUID]()), 0)
	
	CREATE TABLE [#BillTbl]( [Type] [UNIQUEIDENTIFIER], [Security] [INT], [ReadPriceSecurity] [INT])    
	CREATE TABLE [#EntryTbl]( [Type] [UNIQUEIDENTIFIER], [Security] [INT])

	SET @DefCurr=(dbo.fnGetDefaultCurr())
	CREATE TABLE [#CostTbl]( [CostGUID] [UNIQUEIDENTIFIER], [Security] [INT])  
	CREATE TABLE [#CustTbl] ([CustGUID] [UNIQUEIDENTIFIER], [Security] [INT])
	INSERT INTO [#CostTbl] EXEC [prcGetCostsList] @CostGuid  
	INSERT INTO [#CustTbl] EXEC [prcGetCustsList] @CustGuid, @AccGuid, default

	IF (@CostGuid = 0X00)  
		INSERT INTO [#CostTbl] VALUES(0X00,0)  
	IF (@WithCost =0 ) 
		SET @c_Acc = CURSOR FAST_FORWARD FOR   
							SELECT [GUID],0x00,ISNULL([CustGUID],0x0) AS [CustGUID]
							FROM [fnGetAccountsList]( @AccGUID, DEFAULT)
									OUTER APPLY [#CustTbl] 
	ELSE 
	BEGIN
		SET @c_Acc = CURSOR FAST_FORWARD FOR   
							SELECT [GUID],[CostGuid],ISNULL([CustGUID],0x0)   AS [CustGUID]
							FROM [fnGetAccountsList]( @AccGUID, DEFAULT),[#CostTbl]
							OUTER APPLY [#CustTbl] 
	END

	Declare  @UserGUID [UNIQUEIDENTIFIER] = [dbo].[fnGetCurrentUserGUID]()  
	INSERT INTO [#EntryTbl] EXEC [prcGetNotesTypesList]  @SrcGuid, @UserGUID
	
	INSERT INTO [#BillTbl] EXEC [prcGetBillsTypesList] @SrcGuid, @UserGUID
	
	INSERT INTO [#EntryTbl] EXEC [prcGetEntriesTypesList] @SrcGuid, @UserGUID
	
	INSERT INTO [#EntryTbl] SELECT [Type], [Security] FROM [#BillTbl] 
	DECLARE @Zero FLOAT = [dbo].[fnGetZeroValuePrice]()

	OPEN @c_Acc FETCH FROM @c_Acc INTO @c_AccGuid, @Cost,@c_CustGuid  
	CREATE TABLE #DebitTbl (DebitGUID UNIQUEIDENTIFIER, CurrencyGuid UNIQUEIDENTIFIER, CurrencyValue FLOAT, Value FLOAT, DebitDate DATETIME, DebitType INT, ParentGUID UNIQUEIDENTIFIER,Number INT, PaidValue FLOAT) 
	CREATE TABLE #PaymentsTbl (PaymentGUID UNIQUEIDENTIFIER, CurrencyGuid UNIQUEIDENTIFIER, CurrencyValue FLOAT, Value FLOAT, PaymentDate DATETIME, PaymentType INT, ParentGUID UNIQUEIDENTIFIER,Number INT, PaidValue FLOAT) 
	CREATE TABLE #temp(DebitGUID UNIQUEIDENTIFIER,PaymentGUID UNIQUEIDENTIFIER)
	WHILE @@FETCH_STATUS = 0  
	BEGIN  
		DELETE #DebitTbl 
		INSERT #DebitTbl 
		SELECT   
			[en].[enGUID],
			[ac].[CurrencyGUID],
			CASE WHEN [en].[enCurrencyPtr] = [ac].[CurrencyGUID] THEN [en].[enCurrencyVal] ELSE [dbo].fnGetCurVal([ac].[CurrencyGUID], [en].[enDate]) END,
			((CASE [en].[enDebit] WHEN 0 THEN [en].[enCredit] ELSE [en].[enDebit] END) - ISNULL([bd].[bpVal], 0) - ISNULL([bp].[bpVal], 0))  /
				(CASE WHEN [en].[enCurrencyPtr] = [ac].[CurrencyGUID] THEN [en].[enCurrencyVal] ELSE 
					[dbo].fnGetCurVal([ac].[CurrencyGUID], [en].[enDate])
				END),
			[en].[enDate], 
			0,
			ISNULL(bu.guid, 0x0)
			,[ce].[Number], 0
		FROM  
			[vwEn] As [en]
			INNER JOIN [ac000] AS [ac] ON [en].[enAccount] = [ac].[GUID]
			INNER JOIN [#CostTbl] [co] ON [co].[CostGuid] = [en].[enCostPoint]   
			INNER JOIN [ce000] [ce] ON [ce].[GUID]= [en].[enParent]
			INNER JOIN [#EntryTbl] [ent] ON [ent].[Type] = [ce].[TypeGuid]  
			LEFT JOIN [vwBp_SumDebt] AS [bd] on [en].[enGUID] = [bd].[bpDebtGUID]  
			LEFT JOIN [vwBp_SumPay] AS [bp] on [en].[enGUID] = [bp].[bpPayGUID]  
			LEFT JOIN [er000] er ON er.EntryGUID = en.enParent
			LEFT JOIN [bu000] bu ON bu.GUID = er.ParentGUID 
		WHERE  
			[enAccount] = @c_AccGuid  
			AND
			[enCustomerGUID] = @c_CustGuid 
			AND  
			(@WithCost = 0 OR (enCostPoint = @Cost))  
			AND 
			((@DebtType = 0  AND [en].[enCredit] > 0 AND (ISNULL([bp].[bpVal], 0) + ISNULL([bd].[bpVal], 0)) < [en].[enCredit]) OR  
			(@DebtType = 1  AND [en].[enDebit]> 0 AND (ISNULL([bp].[bpVal], 0) + ISNULL([bd].[bpVal], 0)) < [en].[enDebit]))  
			AND  ([en].[enDate] BETWEEN @StartDate AND @EndDate)  
			AND ISNULL(er.ParentType,0) <> 2
			AND (@Posted = -1 OR ce.[Isposted] = @Posted)
			AND (@ShowUnPaid <> 0 OR ((ISNULL([bp].[bpVal], 0) + ISNULL([bd].[bpVal], 0)) - [en].[enCredit])> @Zero OR ((ISNULL([bp].[bpVal], 0) + ISNULL([bd].[bpVal], 0)) - [en].[EnDebit])> @Zero) 
			AND  (@ShowPartPaid	<> 0 OR ABS((ISNULL([bp].[bpVal], 0) + ISNULL([bd].[bpVal], 0)) - [en].[EnCredit]) < @Zero OR ABS((ISNULL([bp].[bpVal], 0) + ISNULL([bd].[bpVal], 0)) - [en].[EnDebit]) < @Zero )
	 
		UNION ALL 
		SELECT   
				[bu].[GUID],
				[ac].[CurrencyGUID],
				CASE WHEN [bu].[CurrencyGUID] = [ac].[CurrencyGUID] THEN [bu].[CurrencyVal] ELSE [dbo].fnGetCurVal([ac].[CurrencyGUID], [bu].[Date]) END,
			    ABS(dbo.fnCalcBillTotal(bu.Guid,@DefCurr)) - ISNULL([bp].[bpVal], 0) - ISNULL([bd].[bpVal], 0)  /
					(CASE WHEN [bu].[CurrencyGUID] = [ac].[CurrencyGUID] THEN [bu].[CurrencyVal] ELSE 
						[dbo].fnGetCurVal([ac].[CurrencyGUID], [bu].[Date])
					END),
				[bu].[Date], 
				0,
				0x0
				,bu.Number, 0
			FROM  
				[bu000] [bu]
				INNER JOIN [ac000] AS [ac] ON [bu].[CustAccGUID] = [ac].[GUID]
				INNER JOIN [#CostTbl] [co] ON [co].[CostGuid] = [bu].[CostGUID] 
				INNER JOIN [bt000] AS [bt] ON [bt].[guid]= [bu].[TypeGUID]
				INNER JOIN [#EntryTbl] [ent] ON [ent].[Type] = [bu].[TypeGUID] AND [ent].[Type]=[bt].[GUID]
				INNER JOIN [vwEr] As [er] on er.erParentGUID = bu.GUID
				INNER JOIN CE000 ce on ce.GUID= er.erEntryGUID
				LEFT JOIN [vwBp_SumDebt] AS [bd] on [bu].[GUID] = [bd].[bpDebtGUID]  
				LEFT JOIN [vwBp_SumPay] AS [bp] on [bu].[GUID] = [bp].[bpPayGUID]  
				LEFT JOIN (select distinct buguid, poguid from ori000 )ori ON bu.GUID = ori.BuGuid  
			WHERE  
				 [bu].[CustAccGUID] = @c_AccGuid 
				 AND
				 [bu].[CustGUID] = @c_CustGuid 
				AND (@WithCost = 0 OR [bu].[CostGUID] = @Cost)  
				AND ((@DebtType = 0  AND [bt].[bIsInput] > 0 ) OR  (@DebtType = 1  AND [bt].[bIsOutput]> 0 ))
				AND (ISNULL([bp].[bpVal], 0) + ISNULL([bd].[bpVal], 0)) < ABS(dbo.fnCalcBillTotal([bu].[Guid],@DefCurr))
				AND  bu.Date BETWEEN @StartDate AND @EndDate 
				AND (@ShowUnPaid <> 0 OR (ISNULL([bp].[bpVal], 0) + ISNULL([bd].[bpVal], 0)) <> 0 ) --€Ì— „”œœ
				AND (@ShowPartPaid	<> 0 
					OR ((ISNULL([bp].[bpVal], 0) + ISNULL([bd].[bpVal], 0)) <= 0
					OR  (ISNULL([bp].[bpVal], 0) + ISNULL([bd].[bpVal], 0)) >= dbo.fnCalcBillTotal(bu.GUID,@DefCurr))
					) --„”œœ Ã“∆Ì«
				AND (@Posted = -1 OR ce.[Isposted] = @Posted) 
				AND ((@ShowOrderBills = 1) OR ((@ShowOrderBills = 0) AND (ori.buGUID IS NULL)))
				AND bu.Guid NOT IN 
					(select distinct 
								o.BuGuid
							FROM ori000 o INNER JOIN (

							select	distinct
									p.BillGuid
		 
									from bp000 as b
									INNER JOIN vwOrderPayments p on p.PaymentGuid = b.DebtGUID or p.PaymentGuid= b.PayGUID
									) as ord on ord.BillGuid= o.POGUID
								where o.BuGuid <> 0x0)
			
		UNION ALL
		SELECT   
			[orp].[PaymentGUID],
			[ac].[CurrencyGUID],
			CASE WHEN [ac].[CurrencyGUID] = [bu].[buCurrencyPtr] THEN [bu].[buCurrencyVal] ELSE [dbo].fnGetCurVal([ac].[CurrencyGUID], [orp].[DueDate]) END,
			(orp.UpdatedValueWithCurrency - ISNULL( [bd].[bpVal], 0) - ISNULL( [bp].[bpVal], 0)) /
				(CASE WHEN [ac].[CurrencyGUID] = [bu].[buCurrencyPtr] THEN [bu].[buCurrencyVal] ELSE 
					[dbo].fnGetCurVal([ac].[CurrencyGUID], [orp].[DueDate])
				END),
			[orp].[PaymentDate], 
			1,
			orp.BillGuid
		    ,bu.buNumber, 0
		FROM  
			[#BillTbl] src
			INNER JOIN [bt000] [bt] ON [bt].[Guid] = [src].[Type]
			INNER JOIN [dbo].[fnBu_Fixed](@DefCurr) As [bu] on [bu].[buType] = [src].[Type] 
			INNER JOIN [vwOrderPayments] As [orp] on [bu].[buGuid] = [orp].[BillGuid] 
			INNER JOIN [#CostTbl] [co] ON [co].[CostGuid] = [bu].[buCostPtr]   
			INNER JOIN [ac000] As [ac] on [ac].[Guid] = @c_AccGuid
			LEFT JOIN [vwBp_SumDebt] AS [bd] on [orp].[PaymentGUID] = [bd].[bpDebtGUID]  
			LEFT JOIN [vwBp_SumPay] AS [bp] on [orp].[PaymentGUID] = [bp].[bpPayGUID]  
		WHERE  
			[buCustAcc] = @c_AccGuid 
			AND
			[buCustPtr] = @c_CustGuid  
			AND   
			(@WithCost = 0 OR (buCostPtr = @Cost))  
			AND 
			((@DebtType = 0  AND [bt].[bIsInput] > 0 ) OR (@DebtType = 1  AND [bt].[bIsInput] = 0)) 
			AND  
			(ISNULL([bp].[bpVal], 0) + ISNULL([bd].[bpVal], 0)) < [orp].PaymentValueWithCurrency
			AND  
			[orp].[DueDate] BETWEEN @StartDate AND @EndDate  
			AND (@ShowUnPaid <> 0 OR (ISNULL([bp].[bpVal], 0) + ISNULL([bd].[bpVal], 0)) <> 0 ) --€Ì— „”œœ
			AND (@ShowPartPaid	<> 0 
				OR ((ISNULL([bp].[bpVal], 0) + ISNULL([bd].[bpVal], 0)) <= 0
				OR  (ISNULL([bp].[bpVal], 0) + ISNULL([bd].[bpVal], 0)) >= [orp].PaymentValueWithCurrency))
			AND (@ShowOrderBills = 0)
			AND orp.PaymentGuid NOT IN (SELECT DISTINCT 
											o.PaymentGuid
										FROM vwOrderPayments o INNER JOIN (

										SELECT	DISTINCT
												p.POGUID
		 
												FROM bp000 as b
												INNER JOIN ori000 p on p.BuGuid = b.DebtGUID or p.BuGuid= b.PayGUID
												) as ord on ord.POGUID= o.BillGuid
											)

		DELETE #PaymentsTbl  
		INSERT #PaymentsTbl 
		SELECT   
			[en].[enGUID],   
			[ac].[CurrencyGUID],
			CASE WHEN [en].[enCurrencyPtr] = [ac].[CurrencyGUID] THEN [en].[enCurrencyVal] ELSE [dbo].fnGetCurVal([ac].[CurrencyGUID], [en].[enDate]) END,
			((CASE [en].[enDebit] WHEN 0 THEN [en].[enCredit] ELSE [en].[enDebit] END) - ISNULL([bd].[bpVal], 0) - ISNULL([bp].[bpVal], 0))  /
					(CASE WHEN [en].[enCurrencyPtr] = [ac].[CurrencyGUID] THEN [en].[enCurrencyVal] ELSE 
						[dbo].fnGetCurVal([ac].[CurrencyGUID], [en].[enDate])
					END),
			[en].[enDate], 
			0,
			ISNULL(bu.guid, 0x0)
			,[ce].[Number], 0
		FROM  
			[vwEn] As [en]  
			INNER JOIN [ac000] AS [ac] ON [en].[enAccount] = [ac].[GUID]
			INNER JOIN [#CostTbl] [co] ON [co].[CostGuid] = [en].[enCostPoint]   
			INNER JOIN [ce000] [ce] ON [ce].[GUID]= [en].[enParent]
			INNER JOIN [#EntryTbl] [ent] ON [ent].[Type] = [ce].[TypeGuid]    
			LEFT JOIN [vwBp_SumDebt] AS [bd] on [en].[enGUID] = [bd].[bpDebtGUID]  
			LEFT JOIN [vwBp_SumPay] AS [bp] on [en].[enGUID] = [bp].[bpPayGUID]  
			LEFT JOIN [er000] er ON er.EntryGUID = en.enParent
			LEFT JOIN [bu000] bu ON bu.GUID = er.ParentGUID 
		WHERE  
			[enAccount] = @c_AccGuid AND (@WithCost = 0 OR (enCostPoint = @Cost))
			AND
			[enCustomerGUID] = @c_CustGuid  
			AND 
			(( @DebtType = 0  AND [en].[enDebit] > 0 AND (ISNULL([bp].[bpVal], 0) + ISNULL([bd].[bpVal], 0)) < [en].[enDebit]) OR  
			( @DebtType = 1  AND [en].[enCredit] > 0 AND (ISNULL([bp].[bpVal], 0) + ISNULL([bd].[bpVal], 0)) < [en].[enCredit]))AND  
				([en].[enDate] BETWEEN @StartDate AND @EndDate) AND ISNULL(er.ParentType,0) <> 2
			 AND (@Posted = -1 OR [ce].[Isposted] = @Posted) 
				
		UNION ALL  
		SELECT   
				[bu].[GUID],
				[ac].[CurrencyGUID],
				CASE WHEN [bu].[CurrencyGUID] = [ac].[CurrencyGUID] THEN [bu].[CurrencyVal] ELSE [dbo].fnGetCurVal([ac].[CurrencyGUID], [bu].[Date]) END,
			    ABS(dbo.fnCalcBillTotal(bu.Guid,@DefCurr))- ISNULL([b].[bpVal], 0)  /
					(CASE WHEN [bu].[CurrencyGUID] = [ac].[CurrencyGUID] THEN [bu].[CurrencyVal] ELSE 
						[dbo].fnGetCurVal([ac].[CurrencyGUID], [bu].[Date])
					END)- ISNULL([bb].[bpVal], 0)  /
					(CASE WHEN [bu].[CurrencyGUID] = [ac].[CurrencyGUID] THEN [bu].[CurrencyVal] ELSE 
						[dbo].fnGetCurVal([ac].[CurrencyGUID], [bu].[Date])
					END),
				[bu].[Date], 
				0,
				0x0
				,bu.Number, 0
			FROM  
				[bu000] [bu]
				INNER JOIN [ac000] AS [ac] ON [bu].[CustAccGUID] = [ac].[GUID]
				INNER JOIN [#CostTbl] [co] ON [co].[CostGuid] = bu.CostGUID 
				INNER JOIN [bt000] AS [bt] ON [bt].[guid]= [bu].[TypeGUID]
				INNER JOIN [#EntryTbl] [ent] ON [ent].[Type] = [bu].[TypeGUID] AND [ent].[Type]=[bt].[GUID]
				INNER JOIN [vwEr] As [er] on er.erParentGUID = bu.GUID
				INNER JOIN CE000 ce on ce.GUID= er.erEntryGUID
				LEFT JOIN [vwBp_SumPay] [b] ON [bu].[GUID]= [b].[bpPayGUID] 
				LEFT JOIN [vwBp_SumDebt] AS [bb] on bu.GUID = [bb].[BpDebtGUID]
				LEFT JOIN (select distinct buguid, poguid from ori000 )ori ON bu.GUID = ori.BuGuid  	 
			WHERE  
				 BU.[CustAccGUID] = @c_AccGuid 
				AND (@WithCost = 0 OR [bu].[CostGUID] = @Cost)  
				AND ((@DebtType = 0  AND [bt].[bIsInput] = 0 ) OR (@DebtType = 1  AND [bt].[bIsInput] > 0))  
		        AND ISNULL( [b].[bpVal], 0) < ABS(dbo.fnCalcBillTotal([bu].[Guid],@DefCurr))
				AND [bu].[Date] BETWEEN @StartDate AND @EndDate
				AND (@Posted = -1 OR ce.[Isposted] = @Posted)
				AND ((@ShowOrderBills = 1) OR ((@ShowOrderBills = 0) AND (ori.buGUID IS NULL)))
  				AND bu.Guid not in 
					(select distinct 
								o.BuGuid
							FROM ori000 o inner join (

							select	distinct
									p.BillGuid
		 
									from bp000 as b
									INNER JOIN vwOrderPayments p on p.PaymentGuid = b.DebtGUID or p.PaymentGuid= b.PayGUID
									) as ord on ord.BillGuid= o.POGUID
								where o.BuGuid <> 0x0)
		UNION ALL  
		SELECT  
			[orp].[PaymentGUID], 
			[ac].[CurrencyGUID],
			CASE WHEN [ac].[CurrencyGUID] = [bu].[buCurrencyPtr] THEN [bu].[buCurrencyVal] ELSE [dbo].fnGetCurVal([ac].[CurrencyGUID], [orp].[DueDate]) END,
			(orp.UpdatedValueWithCurrency - ISNULL( [bd].[bpVal], 0) - ISNULL( [bp].[bpVal], 0)) /
				(CASE WHEN [ac].[CurrencyGUID] = [bu].[buCurrencyPtr] THEN [bu].[buCurrencyVal] ELSE 
					[dbo].fnGetCurVal([ac].[CurrencyGUID], [orp].[DueDate])
				END),
			[orp].[PaymentDate], 
			1,
			orp.BillGuid
			,bu.buNumber, 0
		FROM  
			[#BillTbl] src
			INNER JOIN [bt000] [bt] ON [bt].[Guid] = [src].[Type]
			INNER JOIN [dbo].[fnBu_Fixed](@DefCurr) As [bu] on [bu].[buType] = [src].[Type] 
			INNER JOIN [vwOrderPayments] As [orp] on [bu].[buGuid] = [orp].[BillGuid] 
			INNER JOIN [#CostTbl] [co] ON [co].[CostGuid] = [bu].[buCostPtr]   
			INNER JOIN [ac000] As [ac] on [ac].[Guid] = @c_AccGuid
			LEFT JOIN [vwBp_SumDebt] AS [bd] on [orp].[PaymentGUID] = [bd].[bpDebtGUID]  
			LEFT JOIN [vwBp_SumPay] [bp] ON [orp].[PaymentGUID]= [bp].[bpPayGUID] 
		where
			[buCustAcc] = @c_AccGuid  
			AND ((@DebtType = 0  AND [bt].[bIsInput] =  0) OR (@DebtType = 1  AND [bt].[bIsInput] > 0))
			AND (@WithCost = 0 OR (buCostPtr = @Cost))  
			AND [bu].[buDate] BETWEEN @StartDate AND @EndDate
			AND (ISNULL([bp].[bpVal], 0) + ISNULL([bd].[bpVal], 0)) < orp.UpdatedValueWithCurrency
			AND (@ShowOrderBills = 0)
			AND orp.PaymentGuid NOT IN (SELECT DISTINCT 
											o.PaymentGuid
										FROM vwOrderPayments o INNER JOIN (

										SELECT	DISTINCT
												p.POGUID
		 
												FROM bp000 as b
												INNER JOIN ori000 p on p.BuGuid = b.DebtGUID or p.BuGuid= b.PayGUID
												) as ord on ord.POGUID= o.BillGuid
											)
		
		DELETE #DebitTbl WHERE Value <= 0
		DELETE #PaymentsTbl WHERE Value <= 0
		
		SET @c_Debt = CURSOR FAST_FORWARD FOR SELECT DebitGUID, CurrencyGuid, CurrencyValue, Value, DebitType, ParentGUID FROM (SELECT  distinct * FROM #DebitTbl)as res ORDER BY [DebitDate], Number 
		SET @c_Pay = CURSOR FAST_FORWARD FOR  SELECT PaymentGUID, CurrencyGuid, CurrencyValue, Value, PaymentType, ParentGUID FROM(SELECT  distinct * FROM #PaymentsTbl )as res2 ORDER BY [PaymentDate], Number
	  
		OPEN @c_Debt   
		OPEN @c_Pay  

		FETCH FROM @c_Debt INTO @d_enGUID, @d_enCurrencyGUID, @d_enCurrencyVal, @d_Debt, @DebitType, @d_parentGUID
		IF @@FETCH_STATUS <> 0  
			GOTO NextAccount  
	  
		FETCH FROM @c_Pay INTO @p_enGUID, @p_enCurrencyGUID, @p_enCurrencyVal, @p_Pay, @PaymentType, @p_parentGUID
		IF @@FETCH_STATUS <> 0  
			GOTO NextAccount  
	  
		WHILE 1 = 1  
		BEGIN  
			SET @d_Debt = (SELECT TOP 1 (Value - [PaidValue]) FROM #DebitTbl WHERE DebitGuid = @d_enGUID)
			SET @p_Pay = (SELECT TOP 1 (Value - [PaidValue]) FROM #PaymentsTbl WHERE PaymentGUID = @p_enGUID)

			IF @d_Debt <= 0
			BEGIN 
				FETCH FROM @c_Debt INTO @d_enGUID, @d_enCurrencyGUID, @d_enCurrencyVal, @d_Debt, @DebitType, @d_parentGUID  
				IF @@FETCH_STATUS <> 0  
					GOTO NextAccount  
			END ELSE IF @p_Pay <= 0 
			BEGIN 
				FETCH FROM @c_Pay INTO @p_enGUID, @p_enCurrencyGUID, @p_enCurrencyVal, @p_Pay, @PaymentType, @p_parentGUID   
				IF @@FETCH_STATUS <> 0  
					GOTO NextAccount  
			END 
						
			IF (@PaymentType = @DebitType) AND (@PaymentType = 1)
			BEGIN 
				IF EXISTS (SELECT * FROM #DebitTbl WHERE DebitType = 0 AND Value > PaidValue)
				BEGIN 
					EXEC prcOrder_AutoDebtPay @p_enGUID, 0

					FETCH FROM @c_Pay INTO @p_enGUID, @p_enCurrencyGUID, @p_enCurrencyVal, @p_Pay, @PaymentType, @p_parentGUID   
					IF @@FETCH_STATUS <> 0  
						GOTO NextAccount  
				END ELSE IF EXISTS (SELECT * FROM #PaymentsTbl WHERE PaymentType = 0 AND Value > PaidValue)
				BEGIN 
					EXEC prcOrder_AutoDebtPay @d_enGUID, 1

					FETCH FROM @c_Debt INTO @d_enGUID, @d_enCurrencyGUID, @d_enCurrencyVal, @d_Debt, @DebitType, @d_parentGUID  
					IF @@FETCH_STATUS <> 0  
						GOTO NextAccount  
				END ELSE BEGIN 
					FETCH FROM @c_Debt INTO @d_enGUID, @d_enCurrencyGUID, @d_enCurrencyVal, @d_Debt, @DebitType, @d_parentGUID  
					IF @@FETCH_STATUS <> 0  
						GOTO NextAccount  
	  
					FETCH FROM @c_Pay INTO @p_enGUID, @p_enCurrencyGUID, @p_enCurrencyVal, @p_Pay, @PaymentType, @p_parentGUID   
					IF @@FETCH_STATUS <> 0  
						GOTO NextAccount  
				END 
			END ELSE 
			BEGIN 
				IF @d_Debt < @p_Pay 
				BEGIN 
					--SET @p_Pay = @p_Pay - @d_Debt 
					
					INSERT INTO [bp000] ([DebtGUID], [PayGUID], [PayType], [Val], [CurrencyGUID], [CurrencyVal], [RecType], [DebitType], ParentDebitGUID, ParentPayGUID, [PayVal], [PayCurVal], [Type]) 
					VALUES( @d_enGUID, @p_enGUID, @PaymentType, @d_Debt * @d_enCurrencyVal, @d_enCurrencyGUID, @d_enCurrencyVal, 0, @DebitType, @d_parentGUID, @p_parentGUID, @d_Debt * @p_enCurrencyVal, @p_enCurrencyVal, 0) 

					UPDATE [#DebitTbl] SET PaidValue = Value WHERE DebitGUID = @d_enGUID
					UPDATE [#PaymentsTbl] SET PaidValue = PaidValue + @d_Debt WHERE PaymentGUID = @p_enGUID
	 
					INSERT INTO #temp VALUES(@d_enGUID,@p_enGUID)
				
					FETCH FROM @c_Debt INTO @d_enGUID, @d_enCurrencyGUID, @d_enCurrencyVal, @d_Debt, @DebitType, @d_parentGUID  
					IF @@FETCH_STATUS <> 0 
						GOTO NextAccount  
	 
				END ELSE IF @d_Debt > @p_Pay 
				BEGIN 
					-- SET @d_Debt = @d_Debt - @p_Pay 
					
					INSERT INTO [bp000] ([DebtGUID], [PayGUID], [PayType], [Val], [CurrencyGUID], [CurrencyVal], [RecType], [DebitType], ParentDebitGUID, ParentPayGUID, [PayVal], [PayCurVal], [Type]) 
					VALUES( @d_enGUID, @p_enGUID, @PaymentType, @p_Pay * @d_enCurrencyVal, @p_enCurrencyGUID, @d_enCurrencyVal, 0, @DebitType, @d_parentGUID, @p_parentGUID, @p_Pay * @p_enCurrencyVal, @p_enCurrencyVal, 0) 

					UPDATE [#DebitTbl] SET PaidValue = PaidValue + @p_Pay WHERE DebitGUID = @d_enGUID
					UPDATE [#PaymentsTbl] SET PaidValue = Value WHERE PaymentGUID = @p_enGUID

					INSERT INTO #temp VALUES(@d_enGUID,@p_enGUID)

					FETCH FROM @c_Pay INTO @p_enGUID, @p_enCurrencyGUID, @p_enCurrencyVal, @p_Pay, @PaymentType, @p_parentGUID   
					IF @@FETCH_STATUS <> 0 
						GOTO NextAccount  
	 
				END ELSE -- @d_Debt = @p_Pay 
				BEGIN  
					INSERT INTO [bp000] ([DebtGUID], [PayGUID], [PayType], [Val], [CurrencyGUID], [CurrencyVal], [RecType], [DebitType], ParentDebitGUID, ParentPayGUID, [PayVal], [PayCurVal], [Type]) 
					VALUES( @d_enGUID, @p_enGUID, @PaymentType, @p_Pay * @d_enCurrencyVal, @p_enCurrencyGUID, @d_enCurrencyVal, 0, @DebitType, @d_parentGUID, @p_parentGUID, @p_Pay * @p_enCurrencyVal, @p_enCurrencyVal, 0) 
	  
					UPDATE [#DebitTbl] SET PaidValue = Value WHERE DebitGUID = @d_enGUID
					UPDATE [#PaymentsTbl] SET PaidValue = Value WHERE PaymentGUID = @p_enGUID

					INSERT INTO #temp VALUES(@d_enGUID,@p_enGUID)

					FETCH FROM @c_Debt INTO @d_enGUID, @d_enCurrencyGUID, @d_enCurrencyVal, @d_Debt, @DebitType, @d_parentGUID   
					IF @@FETCH_STATUS <> 0  
						GOTO NextAccount  
	  
					FETCH FROM @c_Pay INTO @p_enGUID, @p_enCurrencyGUID, @p_enCurrencyVal, @p_Pay, @PaymentType, @p_parentGUID     
					IF @@FETCH_STATUS <> 0  
						GOTO NextAccount  
				END  
			END 
		END  
		NextAccount:  
		CLOSE @c_Debt   
		CLOSE @c_Pay  
		FETCH FROM @c_Acc INTO @c_AccGuid, @Cost, @c_CustGuid
	    DEALLOCATE @c_Debt   
	    DEALLOCATE @c_Pay   
	END  
	CLOSE @c_Acc  
	DEALLOCATE @c_Acc  

	SELECT * FROM  #temp
###############################################################################
CREATE PROCEDURE prcEntry_ConnectDebtPay
	@DebtGuid	[UNIQUEIDENTIFIER],  
	@PayGuid	[UNIQUEIDENTIFIER],
	@Type		[INT] = 0,					-- 0: All except first pay and cheques, 1: first pay, 2: cheques
	@PayValue	FLOAT = 0
AS  
	DECLARE  
		@d_enGUID [UNIQUEIDENTIFIER], 
		@d_enCurrencyGUID [UNIQUEIDENTIFIER],  
		@d_enCurrencyVal [FLOAT], 
		@d_Debt [FLOAT],
		@p_enGUID [UNIQUEIDENTIFIER],  
		@p_enCurrencyGUID [UNIQUEIDENTIFIER],  
		@p_enCurrencyVal [FLOAT],  
		@d_parentGUID [UNIQUEIDENTIFIER],  
		@p_parentGUID [UNIQUEIDENTIFIER],  
		@p_Pay [FLOAT],  
		@Zero [FLOAT], 
		@DebitType [INT], 
		@PaymentType [INT],
		@DefCurr [UNIQUEIDENTIFIER],
		@d_CostGuid [UNIQUEIDENTIFIER] ,
		@p_CostGuid [UNIQUEIDENTIFIER] ,
		@LinkPaymentWithCost [INT]

	SET @DefCurr = dbo.fnGetDefaultCurr()
	SET @Zero = dbo.fnGetZeroValuePrice() 
	SELECT @LinkPaymentWithCost=value FROM op000 WHERE name ='AmnCfg_LinkBillPaymentWithCost'
	
	CREATE TABLE #DebitTbl (DebitGUID UNIQUEIDENTIFIER, CurrencyGuid UNIQUEIDENTIFIER, CurrencyValue FLOAT, Value FLOAT, DebitType INT, ParentGUID UNIQUEIDENTIFIER,CostGuid UNIQUEIDENTIFIER) 
	CREATE TABLE #PaymentsTbl (PaymentGUID UNIQUEIDENTIFIER, CurrencyGuid UNIQUEIDENTIFIER, CurrencyValue FLOAT, Value FLOAT,  PaymentType INT, ParentGUID UNIQUEIDENTIFIER,CostGuid UNIQUEIDENTIFIER) 

	INSERT INTO #DebitTbl
	SELECT   
		[en].[enGUID],
		[ac].[CurrencyGUID],
		CASE WHEN [en].[enCurrencyPtr] = [ac].[CurrencyGUID] THEN [en].[enCurrencyVal] ELSE [dbo].fnGetCurVal([ac].[CurrencyGUID], [en].[enDate]) END,
		((CASE [en].[enDebit] WHEN 0 THEN [en].[enCredit] ELSE [en].[enDebit] END) - ISNULL([bd].[bpVal], 0) - ISNULL([bp].[bpVal], 0))  /
			(CASE WHEN [en].[enCurrencyPtr] = [ac].[CurrencyGUID] THEN [en].[enCurrencyVal] ELSE 
				CASE ISNULL([dbo].fnGetCurVal([ac].[CurrencyGUID], [en].[enDate]), 0) WHEN 0 THEN 1 ELSE [dbo].fnGetCurVal([ac].[CurrencyGUID], [en].[enDate]) END
			END),
		0,
		ISNULL(bu.[GUID], 0x0) ,
		en.enCostPoint
	FROM  
		[vwEn] As [en]  
		INNER JOIN [ac000] AS [ac] ON [en].[enAccount] = [ac].[GUID]
		LEFT JOIN [vwBp_SumDebt] AS [bd] on [en].[enGUID] = [bd].[bpDebtGUID]  
		LEFT JOIN [vwBp_SumPay] AS [bp] on [en].[enGUID] = [bp].[bpPayGUID]  
		LEFT JOIN [er000] er ON er.EntryGUID = en.enParent
		LEFT JOIN [bu000] bu ON bu.GUID = er.ParentGUID 
	WHERE  
		[en].[enGUID] = @DebtGuid 
							 
	UNION ALL
	  
	SELECT   
		[bu].[GUID],
		[ac].[CurrencyGUID],
		CASE WHEN [bu].[CurrencyGUID] = [ac].[CurrencyGUID] THEN [bu].[CurrencyVal] ELSE [dbo].fnGetCurVal([ac].[CurrencyGUID], [bu].[Date]) END,
		(abs(dbo.fnCalcBillTotal([bu].[guid],@DefCurr)) - ISNULL([bp].[bpVal], 0) - ISNULL([bd].[bpVal], 0)) /
			(CASE WHEN [bu].[CurrencyGUID] = [ac].[CurrencyGUID] THEN [bu].[CurrencyVal] ELSE 
				CASE ISNULL([dbo].fnGetCurVal([ac].[CurrencyGUID], [bu].[Date]), 0) WHEN 0 THEN 1 ELSE [dbo].fnGetCurVal([ac].[CurrencyGUID], [bu].[Date]) END
			END),
		case when	ISNULL(ori.POGUID,0x0) <> 0x0 then 1 else 0 end,
		0x0,
		bu.CostGUID
	FROM   
		[bu000] [bu] 
		INNER JOIN [ac000] AS [ac]	 ON [bu].[CustAccGUID] = [ac].[GUID]
		LEFT JOIN [vwBp_SumDebt] AS [bd] on [bu].[GUID] = [bd].[bpDebtGUID]  
		LEFT JOIN [vwBp_SumPay] AS [bp] on [bu].[GUID] = [bp].[bpPayGUID]  
		LEFT JOIN (select distinct buguid, poguid from ori000 )ori ON bu.GUID = ori.BuGuid
	WHERE  
		[bu].[GUID] = @DebtGuid 
			  
	UNION ALL  
	SELECT   
		[orp].[PaymentGUID],
		[ac].[CurrencyGUID],
		CASE WHEN [ac].[CurrencyGUID] = [bu].[buCurrencyPtr] THEN [bu].[buCurrencyVal] ELSE [dbo].fnGetCurVal([ac].[CurrencyGUID], [orp].[DueDate]) END,
		(orp.UpdatedValueWithCurrency - ISNULL( [bd].[bpVal], 0) - ISNULL( [bp].[bpVal], 0)) /
				(CASE WHEN [ac].[CurrencyGUID] = [bu].[buCurrencyPtr] THEN [bu].[buCurrencyVal] ELSE 
					CASE ISNULL([dbo].fnGetCurVal([ac].[CurrencyGUID], [orp].[DueDate]), 0) WHEN 0 THEN 1 ELSE [dbo].fnGetCurVal([ac].[CurrencyGUID], [orp].[DueDate]) END
				END),
		1,
		orp.BillGuid,
		bu.buCostPtr
	FROM  
		[vwOrderPayments] As [orp]  
		INNER JOIN [vwbu] [bu] ON [bu].[buGuid] = [orp].[BillGuid] 
		INNER JOIN [ac000] AS [ac] ON [bu].[buCustAcc] = [ac].[GUID]
		LEFT JOIN [vwBp_SumDebt] AS [bd] on [orp].[PaymentGUID] = [bd].[bpDebtGUID]  
		LEFT JOIN [vwBp_SumPay] AS [bp] on [orp].[PaymentGUID] = [bp].[bpPayGUID]  
	WHERE  
		[orp].[PaymentGUID] = @DebtGuid AND orp.UpdatedValueWithCurrency <> 0


	INSERT INTO #PaymentsTbl
	SELECT   
		[en].[enGUID],
		[ac].[CurrencyGUID],
		CASE WHEN [en].[enCurrencyPtr] = [ac].[CurrencyGUID] THEN [en].[enCurrencyVal] ELSE [dbo].fnGetCurVal([ac].[CurrencyGUID], [en].[enDate]) END,
		((CASE [en].[enCredit] WHEN 0 THEN [en].[enDebit]  ELSE [en].[enCredit] END) - ISNULL([bd].[bpVal], 0) - ISNULL([bp].[bpVal], 0)) /
				(CASE WHEN [en].[enCurrencyPtr] = [ac].[CurrencyGUID] THEN [en].[enCurrencyVal] ELSE 
					CASE ISNULL([dbo].fnGetCurVal([ac].[CurrencyGUID], [en].[enDate]), 0) WHEN 0 THEN 1 ELSE [dbo].fnGetCurVal([ac].[CurrencyGUID], [en].[enDate]) END
				END),
		0,
		ISNULL(bu.[GUID], 0x0) ,
		en.enCostPoint
	FROM  
		[vwEn] As [en]  
		INNER JOIN [ac000] AS [ac] ON [en].[enAccount] = [ac].[GUID]
		-- LEFT JOIN [vwBp_SumPay] AS [b] on [en].[enGUID] = [b].[bpPayGUID]  
		LEFT JOIN [vwBp_SumDebt] AS [bd] on [en].[enGUID] = [bd].[bpDebtGUID]  
		LEFT JOIN [vwBp_SumPay] AS [bp] on [en].[enGUID] = [bp].[bpPayGUID]  
		LEFT JOIN [er000] er ON er.EntryGUID = en.enParent
		LEFT JOIN [bu000] bu ON bu.GUID = er.ParentGUID 
	WHERE  
			[en].[enGUID] = @PayGuid 
	UNION ALL  
	SELECT   
			[bu].[GUID],
			[ac].[CurrencyGUID],
			CASE WHEN [bu].[CurrencyGUID] = [ac].[CurrencyGUID] THEN [bu].[CurrencyVal] ELSE [dbo].fnGetCurVal([ac].[CurrencyGUID], [bu].[Date]) END,
			(abs(dbo.fnCalcBillTotal([bu].[guid],@DefCurr)) - ISNULL([b].[bpVal], 0) ) /
				(CASE WHEN [bu].[CurrencyGUID] = [ac].[CurrencyGUID] THEN [bu].[CurrencyVal] ELSE 
					CASE ISNULL([dbo].fnGetCurVal([ac].[CurrencyGUID], [bu].[Date]), 0) WHEN 0 THEN 1 ELSE [dbo].fnGetCurVal([ac].[CurrencyGUID], [bu].[Date]) END
				END)-ISNULL([bb].[bpVal], 0)  /
				(CASE WHEN [bu].[CurrencyGUID] = [ac].[CurrencyGUID] THEN [bu].[CurrencyVal] ELSE 
					CASE ISNULL([dbo].fnGetCurVal([ac].[CurrencyGUID], [bu].[Date]), 0) WHEN 0 THEN 1 ELSE [dbo].fnGetCurVal([ac].[CurrencyGUID], [bu].[Date]) END
				END),
		case when	ISNULL(ori.POGUID,0x0) <> 0x0 then 1 else 0 end,
			0x0
			,bu.CostGUID
		FROM   
			[bu000] [bu] 
			INNER JOIN [ac000] AS [ac]	 ON [bu].[CustAccGUID] = [ac].[GUID]
			LEFT JOIN [vwBp_SumDebt] AS [b] on bu.GUID = [b].[BpDebtGUID]  
			LEFT JOIN [vwBp_SumPay] AS [bb] on bu.GUID= [bb].[bpPayGUID]  
			LEFT JOIN (select distinct buguid, poguid from ori000 )ori ON bu.GUID = ori.BuGuid
		WHERE  
			[bu].[GUID] = @PayGuid 

	UNION ALL  
	SELECT   
		[orp].[PaymentGUID], 
		[ac].[CurrencyGUID],
		CASE WHEN [ac].[CurrencyGUID] = [bu].[buCurrencyPtr] THEN [bu].[buCurrencyVal] ELSE [dbo].fnGetCurVal([ac].[CurrencyGUID], [orp].[DueDate]) END,
		(orp.UpdatedValueWithCurrency - ISNULL([bd].[bpVal], 0) - ISNULL([bp].[bpVal], 0)) /
				(CASE WHEN [ac].[CurrencyGUID] = [bu].[buCurrencyPtr] THEN [bu].[buCurrencyVal] ELSE 
					CASE ISNULL([dbo].fnGetCurVal([ac].[CurrencyGUID], [orp].[DueDate]), 0) WHEN 0 THEN 1 ELSE [dbo].fnGetCurVal([ac].[CurrencyGUID], [orp].[DueDate]) END
				END),
		1, 
		orp.BillGuid,
		bu.buCostPtr
	FROM  
		[vwOrderPayments] As [orp]  
		INNER JOIN [vwbu] [bu] ON [bu].[buGuid] = [orp].[BillGuid] 
		INNER JOIN [ac000] AS [ac] ON [bu].[buCustAcc] = [ac].[GUID]
		LEFT JOIN [vwBp_SumDebt] AS [bd] on [orp].[PaymentGUID] = [bd].[bpDebtGUID]  
		LEFT JOIN [vwBp_SumPay] AS [bp] on [orp].[PaymentGUID] = [bp].[bpPayGUID]  
	WHERE  
			[orp].[PaymentGUID] = @PayGuid AND orp.UpdatedValueWithCurrency <> 0
  
	CREATE TABLE #bp_result([DebtGUID] UNIQUEIDENTIFIER, [PayGUID] UNIQUEIDENTIFIER)
  
	SELECT  @d_enGUID=DebitGUID, @d_enCurrencyGUID=CurrencyGuid, @d_enCurrencyVal=CurrencyValue, @d_Debt=Value, @DebitType=DebitType, @d_parentGUID=ParentGUID,@d_CostGuid=CostGuid from #DebitTbl
  
	SELECT  @p_enGUID=PaymentGUID, @p_enCurrencyGUID=CurrencyGuid, @p_enCurrencyVal=CurrencyValue, @p_Pay=Value  , @PaymentType=PaymentType, @p_parentGUID =ParentGUID,@p_CostGuid=CostGuid from #PaymentsTbl

	IF @LinkPaymentWithCost = 1
	BEGIN  
		IF @p_CostGuid <> @d_CostGuid 
		BEGIN
			SELECT * FROM #bp_result
			RETURN
		END
	END
	
	IF @PayValue > 0
	BEGIN
		IF (@PayValue < @d_Debt) AND (@PayValue < @p_Pay)
		BEGIN
			IF @p_Pay < @d_Debt
				SET @p_Pay = @PayValue
			ELSE 
				SET @d_Debt = @PayValue		
		END
	END

	IF @d_Debt < @p_Pay
	BEGIN  
		-- SET @p_Pay = @p_Pay - @d_Debt  
		IF (@d_Debt > @Zero) 
		BEGIN  
			INSERT INTO [bp000] ([DebtGUID], [PayGUID], [PayType], [Val], [CurrencyGUID], [CurrencyVal], [RecType], [DebitType], ParentDebitGUID, ParentPayGUID, [PayVal], [PayCurVal], [Type])  
			VALUES (@d_enGUID, @p_enGUID, @PaymentType, @d_Debt * @d_enCurrencyVal, @d_enCurrencyGUID, @d_enCurrencyVal, 0, @DebitType, @d_parentGUID, @p_parentGUID, @d_Debt * @p_enCurrencyVal, @p_enCurrencyVal, @Type)   
			IF @@ROWCOUNT != 0
				INSERT INTO #bp_result SELECT @d_enGUID, @p_enGUID
		END 
	END 
	ELSE IF @d_Debt > @p_Pay  
	BEGIN  
		-- SET @d_Debt = @d_Debt - @p_Pay  
		IF (@p_Pay > @Zero) 
		BEGIN  
			INSERT INTO [bp000] ([DebtGUID], [PayGUID], [PayType], [Val], [CurrencyGUID], [CurrencyVal], [RecType], [DebitType], ParentDebitGUID, ParentPayGUID, [PayVal], [PayCurVal], [Type])   
			VALUES (@d_enGUID, @p_enGUID, @PaymentType, @p_Pay * @d_enCurrencyVal, @p_enCurrencyGUID, @d_enCurrencyVal, 0, @DebitType, @d_parentGUID, @p_parentGUID, @p_Pay * @p_enCurrencyVal, @p_enCurrencyVal, @Type)    
			IF @@ROWCOUNT != 0
				INSERT INTO #bp_result SELECT @d_enGUID, @p_enGUID
		END
	END  
	ELSE -- @d_Debt = @p_Pay  
		IF (@d_Debt > @Zero)
		BEGIN  
			INSERT INTO [bp000] ([DebtGUID], [PayGUID], [PayType], [Val], [CurrencyGUID], [CurrencyVal], [RecType], [DebitType], ParentDebitGUID, ParentPayGUID, [PayVal], [PayCurVal], [Type])     
			VALUES (@d_enGUID, @p_enGUID, @PaymentType, @p_Pay * @d_enCurrencyVal, @p_enCurrencyGUID, @d_enCurrencyVal, 0, @DebitType, @d_parentGUID, @p_parentGUID, @p_Pay * @p_enCurrencyVal, @p_enCurrencyVal, @Type)   
			IF @@ROWCOUNT != 0
				INSERT INTO #bp_result SELECT @d_enGUID, @p_enGUID
		END  
	 
	SELECT * FROM #bp_result
###############################################################################
CREATE PROC prcDeleteBillPays
	@BillGUID [UNIQUEIDENTIFIER],
	@Type [INT]= 1
AS 
	SET NOCOUNT ON 

	DELETE bp000 WHERE (DebtGUID = @BillGUID OR PayGUID = @BillGUID) AND ((@Type = type ) OR (@Type = 1 ))
	DELETE bp000 WHERE payguid IS NULL AND paytype IS NULL 
###############################################################################
CREATE PROCEDURE prcDeletePayBills
	@AccGuid	[UNIQUEIDENTIFIER],
	@CostGuid	[UNIQUEIDENTIFIER],
	@Debit		[BIT],
	@StartDate		[DATETIME],
	@EndDate		[DATETIME],
	@SrcGuid [UNIQUEIDENTIFIER],
	@ShowOrderBills BIT
AS
	CREATE TABLE #TEMP (GUID UNIQUEIDENTIFIER)
	CREATE TABLE [#CostTbl]( [CostGUID] [UNIQUEIDENTIFIER], [Security] [INT]) 
	CREATE TABLE [#BillTbl]( [Type] [UNIQUEIDENTIFIER], [Security] [INT], [ReadPriceSecurity] [INT])    
	CREATE TABLE [#EntryTbl]( [Type] [UNIQUEIDENTIFIER], [Security] [INT])

	DECLARE @UserGUID [UNIQUEIDENTIFIER] = [dbo].[fnGetCurrentUserGUID]()  
	INSERT INTO [#EntryTbl] EXEC [prcGetNotesTypesList]  @SrcGuid, @UserGUID
	INSERT INTO [#BillTbl] EXEC [prcGetBillsTypesList] @SrcGuid, @UserGUID
	INSERT INTO [#EntryTbl] EXEC [prcGetEntriesTypesList] @SrcGuid, @UserGUID
	INSERT INTO [#EntryTbl] SELECT [Type], [Security] FROM [#BillTbl] 

	INSERT INTO [#CostTbl] EXEC [prcGetCostsList] @CostGuid 
	IF @CostGuid = 0X00
		INSERT INTO [#CostTbl] VALUES(0X00,0)

	INSERT INTO #TEMP
	SELECT [en].[GUID] 
	FROM 
		en000 en 
		INNER JOIN #CostTbl co ON en.CostGUID = co.CostGUID
		INNER JOIN CE000 ce on ce.guid = en.ParentGUID
		INNER JOIN [#EntryTbl] [ent] ON [ent].[Type] = ce.[TypeGUID]
		LEFT JOIN [er000] [er] ON [er].[EntryGUID] = [en].[ParentGUID]
	WHERE 
		(en.AccountGUID = @AccGuid) 
		AND ((@Debit > 0 AND en.Debit > 0) OR (@Debit = 0 AND en.Credit > 0)) 
		AND (ISNULL([er].[ParentType],0) <> 2)
		AND (en.Date BETWEEN  @StartDate AND @EndDate)

	INSERT INTO #TEMP
	SELECT [bu].[GUID] 
	FROM 
		[bu000] [bu] 
		INNER JOIN #CostTbl co ON bu.CostGUID = co.CostGUID
		INNER JOIN [bt000] [bt] ON [bt].[GUID] = [bu].[TypeGUID]
		INNER JOIN [#EntryTbl] [ent] ON [ent].[Type] = bu.TypeGUID
		LEFT JOIN (SELECT DISTINCT buGUID FROM ori000) ori ON ori.buGUID = bu.GUID
	WHERE 
		(bu.CustAccGUID = @AccGuid) 
		AND ((@Debit > 0 AND bt.bIsOutput > 0) OR (@Debit = 0 AND bt.bIsInput > 0)) 
		AND ([bu].[Date] BETWEEN @StartDate AND @EndDate)
		AND ((@ShowOrderBills = 1) OR ((@ShowOrderBills = 0) AND (ori.buGUID IS NULL)))
	
	IF @ShowOrderBills = 0
	INSERT INTO #TEMP
	SELECT orp.PaymentGUID 
	FROM 
		vwOrderPayments orp 
		INNER JOIN bu000 bu ON bu.GUID = orp.BillGUID
		INNER JOIN #CostTbl co ON bu.CostGUID = co.CostGUID
		INNER JOIN [bt000] [bt] ON [bt].[GUID] = [bu].[TypeGUID]
		INNER JOIN [#EntryTbl] [ent] ON [ent].[Type] = bu.TypeGUID
	WHERE (bu.CustAccGUID = @AccGuid)
		 AND ([bu].[Date] BETWEEN @StartDate AND @EndDate)
		
	DELETE p FROM bp000 p INNER JOIN #TEMP T ON (T.GUID = DebtGUID OR T.GUID = PayGUID) AND ISNULL(Type, 0) NOT IN (1,2)
###############################################################################
CREATE PROCEDURE prc_DeleteMaturity
		@RefGUID UNIQUEIDENTIFIER
AS 
	DELETE pt000 WHERE [refGuid] = @RefGUID 
	UPDATE ce000 SET isposted = 0 WHERE [Guid] = @RefGUID 
	DELETE ce000 WHERE [Guid] =  @RefGUID 
###############################################################################
CREATE PROCEDURE prc_InsertOrModifyMaturity
	@Update			[BIT],
	@TypeGuid		UNIQUEIDENTIFIER,
	@Branch			UNIQUEIDENTIFIER,
	@Debit			[BIT],
	@Acc			UNIQUEIDENTIFIER,
	@Contracc		UNIQUEIDENTIFIER,
	@Value			FLOAT,
	@CurrGuid		UNIQUEIDENTIFIER,
	@CurrVal		FLOAT,
	@Cost			UNIQUEIDENTIFIER,
	@refGuid		UNIQUEIDENTIFIER,
	@IsTransfered	BIT,
	@Date			DATETIME,
	@DueDate		DATETIME,
	@note			NVARCHAR(255),
	@EntryGuid1		UNIQUEIDENTIFIER,
	@EntryGuid2		UNIQUEIDENTIFIER,
	@Security		INT,
	@OriginDate		DATETIME
AS 
	BEGIN TRAN
	SELECT * INTO #bp  FROM [bp000] WHERE DebtGuid = @EntryGuid1
	IF @Update > 0
		EXEC prc_DeleteMaturity @refGuid
	DECLARE @Number INT ,@Value1 FLOAT,@Value2 FLOAT,@Guid [UNIQUEIDENTIFIER]
	IF (@TypeGuid =  0X00)
		SELECT @TypeGuid = [Guid]  FROM [bt000] WHERE TYPE = 2 AND SORTNUM = 1
	IF @Branch <> 0X00
		SELECT @Number = ISNULL(MAX(Number),0 ) + 1  FROM [ce000] WHERE [Branch] = @Branch
	ELSE
		SELECT @Number = ISNULL(MAX(Number),0 ) + 1  FROM [ce000] 
	 INSERT INTO  pt000 ([Guid],[Type],[RefGuid],[CustAcc],[CurrencyGUID],[CurrencyVal],[IsTransfered],TypeGuid,[DueDate],[Debit],[Credit],[OriginDate])
		VALUES(NEWID(),3,@RefGuid ,@Acc,@CurrGuid,@CurrVal,@IsTransfered,@TypeGuid,@DueDate,CASE @Debit WHEN 1 THEN @Value ELSE 0 END ,CASE @Debit WHEN 0 THEN @Value ELSE 0 END,@OriginDate )
	INSERT INTO  ER000(ParentGuid,EntryGuid,ParentType) VALUES( @RefGuid,@RefGuid,600)
	INSERT INTO ce000 (Guid,Type,Number,Branch,CurrencyGuid,CurrencyVal,[Date],Notes,Security,TypeGuid,PostDate) 
		VALUES (@RefGuid,1,@Number,@Branch,@CurrGuid,@CurrVal, @Date , @note ,@Security,@TypeGuid,@Date)
	INSERT INTO [en000] ([Guid],[AccountGuid],[ParentGuid],Number,CurrencyGuid,CurrencyVal,[Date],[ContraAccGUID],[CostGuid],notes,[Debit],[Credit])
		VALUES( @EntryGuid1,@Acc,@RefGuid,1,@CurrGuid,@CurrVal,@Date,@Contracc,@Cost,@note,CASE @Debit WHEN 1 THEN @Value ELSE 0 END ,CASE @Debit WHEN 0 THEN @Value ELSE 0 END)
	INSERT INTO [en000] ([Guid],[AccountGuid],[ParentGuid],Number,CurrencyGuid,CurrencyVal,[Date],[ContraAccGUID],[CostGuid],notes,[Debit],[Credit])
		VALUES( @EntryGuid2,@Contracc,@RefGuid,2,@CurrGuid,@CurrVal,@Date,@Acc,@Cost,@note,CASE @Debit WHEN 0 THEN @Value ELSE 0 END ,CASE @Debit WHEN 1 THEN @Value ELSE 0 END)
	UPDATE [ce000] SET ISPOSTED = 1 WHERE [Guid] = 	@RefGuid
	IF @Update > 0
	BEGIN
		SELECT @Value1 = SUM(pb.Val)-ABS(en.Debit - en.Credit) FROM #bp pb INNER JOIN en000 en on pb.DebtGuid = en.Guid GROUP BY en.Debit , en.Credit HAVING ABS(en.Debit - en.Credit) < SUM(pb.Val)
		IF @Value IS NULL
			SET @Value1 = 0
		WHILE (@Value1 > 0)
		BEGIN
			SELECT TOP 1 @Value2 = Val,@Guid = Guid FROM #bp 
			IF @Value2 IS NOT NULL 
			BEGIN
				IF @Value1 > @Value2
					DELETE #bp WHERE GUID = @Guid
				ELSE IF @Value1 < @Value2
					UPDATE #bp SET Val = @Value WHERE GUID = @Guid
				SET @Value1 = @Value1 - @Value2
			END
			ELSE
				BREAK
		END
		INSERT INTO bp000 SELECT * FROM #bp
	END
	COMMIT
###############################################################################
#END
