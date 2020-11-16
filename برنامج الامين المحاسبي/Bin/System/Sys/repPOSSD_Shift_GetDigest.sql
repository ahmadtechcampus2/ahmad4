################################################################################
CREATE PROCEDURE repPOSSD_Shift_GetDigest
-- Params -------------------------------   
@shiftGuid UNIQUEIDENTIFIER
-----------------------------------------   
AS
    SET NOCOUNT ON
------------------------------------------------------------------------
	
	DECLARE @language INT = [dbo].[fnConnections_getLanguage]()
	DECLARE @defaultCurrency UNIQUEIDENTIFIER = (SELECT [dbo].[fnGetDefaultCurr]())
	DECLARE @shiftEmployeeGuid UNIQUEIDENTIFIER = (SELECT EmployeeGUID FROM POSSDShift000 WHERE GUID = @shiftGUID)
	DECLARE @employeeExtraAccountGuid UNIQUEIDENTIFIER = (SELECT ExtraAccountGUID FROM POSSDEmployee000 WHERE Guid = @shiftEmployeeGuid)
	DECLARE @employeeMinusAccountGuid UNIQUEIDENTIFIER = (SELECT MinusAccountGUID FROM POSSDEmployee000 WHERE Guid = @shiftEmployeeGuid)
	
	DECLARE  @Temp TABLE ( TransactionType			INT,
							IsPayment				BIT,
							ExternalTransactionType INT,
							CurrencyGUID			UNIQUEIDENTIFIER,
							TransactionGUID			UNIQUEIDENTIFIER,
							CurrencyVal				FLOAT,
							AmountValue				FLOAT,
							sumAmount				FLOAT)

	 DECLARE @CurrencyTotals TABLE ( OperationType INT,
									 CurrencyGUID	 UNIQUEIDENTIFIER,
									 CurrencyTotal	 FLOAT,
									 CurrencyEQ		 FLOAT )

	DECLARE @TypeTotal TABLE ( TransactionType	INT,
							   TotalAmount	    FLOAT,
							    [Count]		    INT)

	--============================================================= Sales Transactions
	INSERT INTO @Temp
	SELECT 1, 0 AS IsPayment, 0, ISNULL(PC.CurrencyGUID, @defaultCurrency), PT.Guid, ISNULL(PC.CurrencyVal, 1), ISNULL(PC.Value, 0), ISNULL(PC.Value, 0) * ISNULL(Pc.CurrencyVal, 1) 
	FROM POSSDTicket000 PT 
	LEFT JOIN POSSDTicketCurrency000 PC ON PT.[GUID] = PC.TicketGUID  
	WHERE  ShiftGuid =@shiftGuid AND PT.[Type] = 0 AND PT.[State] = 0 AND (RelationType <> 1 AND pt.RelationType <> 2)
			  
	UNION ALL
	SELECT 1, 0 AS IsPayment, 0, @defaultCurrency, PT.[GUID], 1, Total, Total
	FROM POSSDTicket000 PT 
	WHERE  ShiftGuid = @shiftGuid AND PT.[Type] = 0 AND PT.[State] = 0 AND (RelationType = 1 OR pt.RelationType = 2)		  

	UNION ALL
	SELECT 1, 0 AS IsPayment, 0, @defaultCurrency, PT.[GUID], 1, TOI.DownPayment, TOI.DownPayment
	FROM POSSDTicket000 PT
	INNER JOIN POSSDTicketOrderInfo000 TOI ON PT.[GUID] = TOI.TicketGUID
	WHERE  PT.ShiftGuid = @shiftGuid AND PT.[Type] = 0 AND PT.[State] = 0

	UNION ALL
	SELECT 1, 0 AS IsPayment, 0, @defaultCurrency, PT.[GUID], 1, PC.Value, Pc.Value
	FROM POSSDTicket000 PT 
	INNER JOIN POSSDTicketBankCard000 PC ON PT.[GUID]= PC.TicketGUID  
	WHERE  ShiftGuid = @shiftGuid AND PT.[Type] = 0 AND PT.[State] = 0 AND (RelationType <> 1 AND pt.RelationType <> 2)
		  
	UNION ALL
	SELECT 1, 0 AS IsPayment, 0, @defaultCurrency, PT.[GUID], 1, PC.Amount, Pc.Amount
	FROM POSSDTicket000 PT 
	INNER JOIN POSSDTicketReturnCoupon000 PC ON PT.[GUID] = PC.TicketGUID  
	WHERE  ShiftGuid = @shiftGuid AND PT.[Type] = 0 AND PT.[State] = 0 AND (RelationType <> 1 AND pt.RelationType <> 2)

	--================================================= Return Sales transaction
	INSERT INTO @Temp
	SELECT 2, 0 AS IsPayment, 0, ISNULL(PC.CurrencyGUID, @defaultCurrency), PT.[GUID], PC.CurrencyVal, ISNULL(PC.Value, 0) * -1, ISNULL(PC.Value, 0) * ISNULL(Pc.CurrencyVal, 1) * -1
	FROM POSSDTicket000 PT LEFT JOIN POSSDTicketCurrency000 PC ON PT.[GUID] = PC.TicketGUID 
	WHERE PT.ShiftGuid = @shiftGuid AND PT.[Type] = 2 AND PT.[State] = 0 AND (RelationType <> 2 AND RelationType <> 1)

    UNION ALL
	SELECT 2, 0 AS IsPayment, 0, @defaultCurrency, PT.[GUID], 1, ISNULL(PC.Amount, 0) * -1, ISNULL(Pc.Amount,0) * -1
	FROM POSSDTicket000 PT 
	LEFT JOIN POSSDTicketReturnCoupon000 PC ON PT.[GUID] = PC.TicketGUID  
	WHERE  ShiftGuid =@shiftGuid AND PT.[Type] = 2 AND PT.[State] = 0 AND (RelationType <> 2 AND RelationType <> 1)

	UNION ALL
	SELECT 2, 0 AS IsPayment, 0, @defaultCurrency, PT.[GUID], 1, ISNULL(PT.Net, 0) * -1, ISNULL(PT.Net,0) * -1
	FROM POSSDTicket000 PT 
	WHERE  ShiftGuid =@shiftGuid AND PT.[Type] = 2 AND PT.[State] = 0 AND (RelationType = 2 OR RelationType = 1)

	--================================================= Add Deffered transaction information
	INSERT INTO @Temp
	SELECT 6, 0 AS IsPayment, 0, PC.CurrencyGUID, PT.[GUID], PC.CurrencyVal, value * -1, value * -1
	FROM POSSDTicket000 PT INNER JOIN POSSDTicketCurrency000 PC ON PT.[GUID] = PC.TicketGUID 
	WHERE PT.ShiftGuid = @shiftGuid AND PT.[Type] = 0 AND LaterValue <> 0 AND PayType = 2 AND PT.[State] = 0 
		
	--================================================= Add Deffered transaction information
	INSERT INTO @Temp
	SELECT 7, 0 AS IsPayment, 0, PC.CurrencyGUID, PT.[Guid], PC.CurrencyVal, value, value
	FROM POSSDTicket000 PT INNER JOIN POSSDTicketCurrency000 PC ON PT.[Guid] = PC.TicketGUID 
	WHERE PT.ShiftGuid = @shiftGuid AND PT.[Type] = 2 AND LaterValue <> 0 AND PayType = 2 AND PT.[State] = 0 

	--================================================= Add Bank card information  بطاقات مصرفية
    INSERT INTO @Temp
	SELECT 8, 0 AS IsPayment,0, @defaultCurrency ,PB.BankCardGUID, 1, PB.Value* -1, PB.Value * -1
	FROM POSSDTicket000 PT INNER JOIN POSSDTicketBankCard000 PB ON PT.[GUID] = PB.TicketGUID 
	WHERE PT.ShiftGuid = @shiftGuid AND PT.[Type] = 0 AND PT.[State] = 0
		 
	--================================================= Add Return Coupon Release information  تسليم قسائم مرتجع
    INSERT INTO @Temp
	SELECT 9, 0 AS IsPayment,0, @defaultCurrency ,PT.[GUID], 1, RC.Amount, RC.Amount 
	FROM POSSDTicket000 PT INNER JOIN POSSDTicketReturnCoupon000 RC ON PT.[GUID]  = Rc.TicketGUID
	WHERE PT.ShiftGuid = @shiftGuid AND PT.[State] = 0 AND RC.[Type] = 0 AND RC.IsReceipt = 0
		 
	--================================================= Add Return Card Release information  تسليم بطاقات مرتجع
    INSERT INTO @Temp
	SELECT 10, 0 AS IsPayment,0, @defaultCurrency ,PT.[GUID] , 1, RC.Amount, RC.Amount 
	FROM POSSDTicket000 PT INNER JOIN POSSDTicketReturnCoupon000 RC ON PT.[GUID]  = Rc.TicketGUID
	WHERE PT.ShiftGuid = @shiftGuid AND PT.[State] = 0 AND RC.[Type] = 1 AND RC.IsReceipt = 0

	--================================================= Add Return Coupon Receipt information استلام قسائم مرتجع
    INSERT INTO @Temp
	SELECT 11, 0 AS IsPayment,0, @defaultCurrency ,PT.[GUID] , 1, RC.Amount * -1, RC.Amount * -1
	FROM POSSDTicket000 PT INNER JOIN POSSDTicketReturnCoupon000 RC ON PT.[GUID]  = Rc.TicketGUID
	WHERE PT.ShiftGuid = @shiftGuid AND PT.[Type] = 0 AND PT.[State] = 0 AND RC.[Type] = 0 AND RC.IsReceipt = 1
		 
	--================================================= Add Return Coupon Receipt information  استلام بطاقات مرتجع
    INSERT INTO @Temp
	SELECT 12, 0 AS IsPayment,0, @defaultCurrency ,PT.[GUID] , 1, RC.Amount * -1, RC.Amount * -1
	FROM POSSDTicket000 PT INNER JOIN POSSDTicketReturnCoupon000 RC ON PT.[GUID]  = Rc.TicketGUID
	WHERE PT.ShiftGuid = @shiftGuid AND PT.[Type] = 0 AND PT.[State] = 0 AND RC.[Type] = 1 AND RC.IsReceipt = 1
		 
	--================================================= Add External Payment information  دفع خارجي
	INSERT INTO @Temp
	SELECT 16, IsPayment AS IsPayment, [Type],  CurrencyGUID, [GUID], CurrencyValue, Amount* -1, Amount * CurrencyValue * -1
	FROM POSSDExternalOperation000 
	WHERE ShiftGuid = @shiftGuid  AND [State] = 0 AND IsPayment = 1 AND [Type] <> 3 AND [Type] <> 6 AND [type] <> 0
		 
	--================================================= Add External Receivce information  تحصيل خارجي
	INSERT INTO @Temp
	SELECT 17, IsPayment AS IsPayment, [Type], CurrencyGUID, [GUID], CurrencyValue, Amount, Amount * CurrencyValue 
	FROM POSSDExternalOperation000 
	WHERE ShiftGuid = @shiftGuid AND [State] = 0 AND IsPayment = 0 AND [Type] <> 3 AND [Type] <> 6  AND [Type] <> 0
        
	--================================================= Add Central Cash Payemnt information  دفع للصندوق المركزي
	INSERT INTO @Temp
	SELECT 18, IsPayment AS IsPayment, [Type], CurrencyGUID, [GUID], CurrencyValue, Amount* -1, Amount * CurrencyValue * -1
	FROM POSSDExternalOperation000 
	WHERE ShiftGuid = @shiftGuid  AND [State] = 0 AND IsPayment = 1 AND [Type] = 3
        
	--================================================= Add Central Cash Receive information  قبض من الصندوق المركزي
	INSERT INTO @Temp
	SELECT 20, IsPayment AS IsPayment, [Type], CurrencyGUID, [GUID], CurrencyValue, Amount, Amount * CurrencyValue 
	FROM POSSDExternalOperation000 
	WHERE ShiftGuid = @shiftGuid  AND [State] = 0 AND IsPayment = 0 AND [Type] = 3
  
	 --================================================= Add Opening Cash information رصيد افتتاحي
	INSERT INTO @Temp 
	SELECT 15, IsPayment, [Type], CurrencyGUID, [GUID], CurrencyValue, Amount, Amount * CurrencyValue
	FROM POSSDExternalOperation000 
	WHERE ShiftGuid = @shiftGuid  AND GenerateState = 0 
	  
	--================================================= Add Cash Difference information فرق الصندوق
	INSERT INTO @Temp 
	SELECT 19, IsPayment, [Type], CurrencyGUID, [GUID], CurrencyValue, 
		CASE CreditAccountGUID WHEN @employeeExtraAccountGuid THEN Amount  ELSE Amount* -1 END,
		CASE CreditAccountGUID WHEN @employeeExtraAccountGuid THEN  Amount* CurrencyValue ELSE  Amount * CurrencyValue * -1 END
	FROM POSSDExternalOperation000 
	WHERE 
		ShiftGuid = @shiftGuid  
	AND  GenerateState = 1 AND Type = 6
	AND (CreditAccountGUID = @employeeExtraAccountGuid
	  OR DebitAccountGUID  = @employeeMinusAccountGuid)
	  
	--================================================= Add Continues Cash information رصيد مدور
	INSERT INTO @Temp 
	SELECT 21, IsPayment, [Type], CurrencyGUID, [GUID], CurrencyValue, Amount * -1, Amount * CurrencyValue* -1
	FROM POSSDExternalOperation000 
	WHERE ShiftGuid = @shiftGuid  AND GenerateState = 1 AND [Type] = 0

	 --================================================= Add Downpayment information رصيد الدفعة الأولى
	INSERT INTO @Temp 
	SELECT 22, 0 AS IsPayment, 7, ISNULL(TC.[CurrencyGUID], @defaultCurrency), OI.[GUID], ISNULL(TC.[CurrencyVal], 1), OI.[DownPayment] * -1, OI.[DownPayment] * -1
	FROM 
		POSSDOrderEvent000 OE 
		INNER JOIN POSSDTicketOrderInfo000 OI ON OE.OrderGUID = OI.[GUID]
		INNER JOIN POSSDTicket000 T ON OI.TicketGUID = T.[GUID]
		INNER JOIN POSSDShift000 SH ON OE.ShiftGUID = SH.[GUID]
		LEFT JOIN POSSDTicketCurrency000 TC ON TC.TicketGUID = T.[GUID]
	WHERE 
		OE.ShiftGUID = @shiftGuid
		AND OE.[Event] = 14
	
	--======================== RESULT ========================

	INSERT INTO @CurrencyTotals 
	SELECT 
		TransactionType,
		CurrencyGUID, 
		SUM(AmountValue), 
		SUM(sumAmount) 
	FROM @Temp 
	GROUP BY CurrencyGUID, TransactionType

	SELECT *,
	ROW_NUMBER() OVER (PARTITION BY TransactionType,TransactionGuid ORDER BY TransactionType ) AS TransactionRank 
	INTO #Temp2
	FROM @Temp


	INSERT INTO @TypeTotal
	SELECT 
		TransactionType,
		SUM(sumAmount) AS TotalAmount , 
		SUM(TransactionRank * CASE TransactionRank WHEN 1 THEN 1 ELSE 0 END) AS transactionCount
	FROM 
		#Temp2
	GROUP BY 
		TransactionType

	SELECT TT.*, CT.*, MY.Code AS CurrencyCode
	FROM 
		@TypeTotal TT 
		INNER JOIN @CurrencyTotals CT ON TT.TransactionType = CT.OperationType
		INNER JOIN my000 MY ON CT.CurrencyGUID = MY.[GUID]
#################################################################
#END

 

