#################################################################
CREATE PROCEDURE prcPOSSD_Shift_GetShiftDigestInfo
		@shiftGuid  [UNIQUEIDENTIFIER]
AS
BEGIN
DECLARE @SalesTicketTotal [FLOAT] ,
	@SalesTicketTotalCount [INT] ,
	@GrantingDebit [FLOAT] ,
	@GrantingDebitCount [INT],
	@ExternalPayment [FLOAT] ,
	@ExternalPaymentCount [INT],
	@ExternalReceivce [FLOAT],
	@ExternalReceivceCount [INT],
	@CentralCashPayemnt [FLOAT],
	@CentralCashPayemntCount [INT],
	@CentralCashReceive [FLOAT],
	@CentralCashReceiveCount [INT],
	@CashDifference [FLOAT],
	@OpeningAmount [FLOAT],
	@FloatingAmount [FLOAT],
	@CashDifferenceCount [INT],
	@OpeningAmountCount [INT],
	@FloatingAmountCount [INT],
	@CurrentCash [FLOAT] ,
	@ExternalOperationsCash [FLOAT],
	@ExternalOperationsCashCount [INT],
	@currencyGUID UNIQUEIDENTIFIER,
	@shiftCach FLOAT,
	@ContinuesCash FLOAT,
	@ContinuesCashCurVal FLOAT,
	@OpeningCash FLOAT,
	@OpeningCashCurVal FLOAT,
	@CountedCash  FLOAT,
	@SumOpeningCash FLOAT,
	@SumContinuesCash FLOAT,
	@SumCashDifference FLOAT,
	@posGuid [UNIQUEIDENTIFIER] = (SELECT StationGUID FROM POSSDShift000 WHERE Guid = @shiftGuid),
    @defaultCurrency UNIQUEIDENTIFIER = (SELECT [dbo].[fnGetDefaultCurr]())
	DECLARE @shiftEmployeeGuid UNIQUEIDENTIFIER = (SELECT EmployeeGUID FROM POSSDShift000 WHERE GUID = @shiftGUID)
 DECLARE @employeeExtraAccountGuid UNIQUEIDENTIFIER = (SELECT ExtraAccountGUID FROM POSSDEmployee000 WHERE Guid = @shiftEmployeeGuid)
 DECLARE @employeeMinusAccountGuid UNIQUEIDENTIFIER = (SELECT MinusAccountGUID FROM POSSDEmployee000 WHERE Guid = @shiftEmployeeGuid)
 DECLARE  @Temp TABLE
		  (
		    TransactionType INT,
			IsPayment BIT,
			ExternalTransactionType INT,
			CurrencyGUID [UNIQUEIDENTIFIER],
			TransactionGUID [UNIQUEIDENTIFIER],
			CurrencyVal FLOAT,
			AmountValue FLOAT,
			sumAmount FLOAT
		  )
		  -- Add Sale transaction information
		  INSERT INTO @Temp
			  SELECT 1, 0 AS IsPayment, 0, ISNULL(PC.CurrencyGUID, @defaultCurrency), PT.Guid, ISNULL(PC.CurrencyVal, 1), ISNULL(PC.Value, 0), ISNULL(PC.Value, 0) * ISNULL(Pc.CurrencyVal, 1) 
			   FROM POSSDTicket000 PT 
			   LEFT JOIN POSSDTicketCurrency000 PC ON PT.Guid = PC.TicketGUID  
			   WHERE  ShiftGuid =@shiftGuid AND PT.Type = 0 AND PT.State = 0 AND (RelationType <> 1 AND pt.RelationType <> 2)
			  
			   UNION ALL
		       SELECT 1, 0 AS IsPayment, 0, @defaultCurrency, PT.Guid, 1, Total, Total
			   FROM POSSDTicket000 PT 
			   WHERE  ShiftGuid =@shiftGuid AND PT.Type = 0 AND PT.State = 0 AND (RelationType = 1 OR pt.RelationType = 2)
		  

			   UNION ALL
		       SELECT 1, 0 AS IsPayment, 0, @defaultCurrency, PT.[GUID], 1, TOI.DownPayment, TOI.DownPayment
			   FROM POSSDTicket000 PT
			   INNER JOIN POSSDTicketOrderInfo000 TOI ON PT.[GUID] = TOI.TicketGUID
			   WHERE  PT.ShiftGuid = @shiftGuid AND PT.[Type] = 0 AND PT.[State] = 0




			   UNION ALL
		       SELECT 1, 0 AS IsPayment, 0, @defaultCurrency, PT.Guid, 1, PC.Value, Pc.Value
			   FROM POSSDTicket000 PT 
			   INNER JOIN POSSDTicketBankCard000 PC ON PT.Guid = PC.TicketGUID  
			   WHERE  ShiftGuid =@shiftGuid AND PT.Type = 0 AND PT.State = 0 AND (RelationType <> 1 AND pt.RelationType <> 2)
		  
		      UNION ALL
		       SELECT 1, 0 AS IsPayment, 0, @defaultCurrency, PT.Guid, 1, PC.Amount, Pc.Amount
			   FROM POSSDTicket000 PT 
			   INNER JOIN POSSDTicketReturnCoupon000 PC ON PT.Guid = PC.TicketGUID  
			   WHERE  ShiftGuid =@shiftGuid AND PT.Type = 0 AND PT.State = 0 AND (RelationType <> 1 AND pt.RelationType <> 2)

		  -- Add Return Sale transaction information
		  INSERT INTO @Temp
			  SELECT 2, 0 AS IsPayment, 0, ISNULL(PC.CurrencyGUID, @defaultCurrency), PT.Guid, PC.CurrencyVal, ISNULL(PC.Value, 0) * -1, ISNULL(PC.Value, 0) * ISNULL(Pc.CurrencyVal, 1) * -1
			   FROM POSSDTicket000 PT LEFT JOIN POSSDTicketCurrency000 PC ON PT.Guid = PC.TicketGUID 
			   WHERE PT.ShiftGuid = @shiftGuid AND PT.Type = 2 AND PT.State = 0 AND (RelationType <> 2 AND RelationType <> 1)
              UNION ALL
		       SELECT 2, 0 AS IsPayment, 0, @defaultCurrency, PT.Guid, 1, ISNULL(PC.Amount, 0) * -1, ISNULL(Pc.Amount,0) * -1
			   FROM POSSDTicket000 PT 
			   LEFT JOIN POSSDTicketReturnCoupon000 PC ON PT.Guid = PC.TicketGUID  
			   WHERE  ShiftGuid =@shiftGuid AND PT.Type = 2 AND PT.State = 0 AND (RelationType <> 2 AND RelationType <> 1)
			   UNION ALL
		       SELECT 2, 0 AS IsPayment, 0, @defaultCurrency, PT.Guid, 1, ISNULL(PT.Net, 0) * -1, ISNULL(PT.Net,0) * -1
			   FROM POSSDTicket000 PT 
			   WHERE  ShiftGuid =@shiftGuid AND PT.Type = 2 AND PT.State = 0 AND (RelationType = 2 OR RelationType = 1)

	      -- Add Deffered transaction information
		  INSERT INTO @Temp
			  SELECT 6, 0 AS IsPayment, 0, PC.CurrencyGUID, PT.Guid, PC.CurrencyVal, value * -1, value * -1
			   FROM POSSDTicket000 PT INNER JOIN POSSDTicketCurrency000 PC ON PT.Guid = PC.TicketGUID 
			   WHERE PT.ShiftGuid = @shiftGuid AND PT.Type = 0 AND LaterValue <> 0 AND PayType = 2 AND PT.State = 0 
		
		 -- Add Deffered transaction information
		  INSERT INTO @Temp
			  SELECT 7, 0 AS IsPayment, 0, PC.CurrencyGUID, PT.Guid, PC.CurrencyVal, value, value
			   FROM POSSDTicket000 PT INNER JOIN POSSDTicketCurrency000 PC ON PT.Guid = PC.TicketGUID 
			   WHERE PT.ShiftGuid = @shiftGuid AND PT.Type = 2 AND LaterValue <> 0 AND PayType = 2 AND PT.State = 0 

		 -- Add Bank card information  بطاقات مصرفية
          INSERT INTO @Temp
			  SELECT 8, 0 AS IsPayment,0, @defaultCurrency ,PB.BankCardGUID, 1, PB.Value* -1, PB.Value * -1
			   FROM POSSDTicket000 PT INNER JOIN POSSDTicketBankCard000 PB ON PT.Guid = PB.TicketGUID 
			   WHERE PT.ShiftGuid = @shiftGuid AND PT.Type = 0 AND PT.State = 0
		 
		  -- Add Return Coupon Release information  تسليم قسائم مرتجع
          INSERT INTO @Temp
			  SELECT 9, 0 AS IsPayment,0, @defaultCurrency ,PT.GUID, 1, RC.Amount, RC.Amount 
			   FROM POSSDTicket000 PT INNER JOIN POSSDTicketReturnCoupon000 RC ON PT.Guid = Rc.TicketGUID
			   WHERE PT.ShiftGuid = @shiftGuid AND PT.State = 0 AND RC.Type = 0 AND RC.IsReceipt = 0
		 
		  -- Add Return Card Release information  تسليم بطاقات مرتجع
          INSERT INTO @Temp
			  SELECT 10, 0 AS IsPayment,0, @defaultCurrency ,PT.GUID, 1, RC.Amount, RC.Amount 
			   FROM POSSDTicket000 PT INNER JOIN POSSDTicketReturnCoupon000 RC ON PT.Guid = Rc.TicketGUID
			   WHERE PT.ShiftGuid = @shiftGuid AND PT.State = 0 AND RC.Type = 1 AND RC.IsReceipt = 0

		 -- Add Return Coupon Receipt information استلام قسائم مرتجع
          INSERT INTO @Temp
			  SELECT 11, 0 AS IsPayment,0, @defaultCurrency ,PT.GUID, 1, RC.Amount * -1, RC.Amount * -1
			   FROM POSSDTicket000 PT INNER JOIN POSSDTicketReturnCoupon000 RC ON PT.Guid = Rc.TicketGUID
			   WHERE PT.ShiftGuid = @shiftGuid AND PT.Type = 0 AND PT.State = 0 AND RC.Type = 0 AND RC.IsReceipt = 1

	      INSERT INTO @Temp
			  SELECT 12, 0 AS IsPayment,0, @defaultCurrency ,OI.GUID, 1, OI.DownPayment * -1, OI.DownPayment * -1
			FROM 
				POSSDOrderEvent000 OE 
				INNER JOIN POSSDTicketOrderInfo000 OI ON OE.OrderGUID = OI.[GUID]
				INNER JOIN POSSDTicket000 T on T.GUID = OI.TicketGUID
			WHERE OE.ShiftGUID = @shiftGuid and OE.[Event] = 14
		 
		 -- Add Return Coupon Receipt information  استلام بطاقات مرتجع
          INSERT INTO @Temp
			  SELECT 13, 0 AS IsPayment,0, @defaultCurrency ,PT.GUID, 1, RC.Amount * -1, RC.Amount * -1
			   FROM POSSDTicket000 PT INNER JOIN POSSDTicketReturnCoupon000 RC ON PT.Guid = Rc.TicketGUID
			   WHERE PT.ShiftGuid = @shiftGuid AND PT.Type = 0 AND PT.State = 0 AND RC.Type = 1 AND RC.IsReceipt = 1
		 
		  -- Add External Payment information  دفع خارجي
		  INSERT INTO @Temp
			  SELECT 17, IsPayment AS IsPayment, [Type],  CurrencyGUID, Guid, CurrencyValue, Amount* -1, Amount * CurrencyValue * -1
			   FROM POSSDExternalOperation000 
	           WHERE ShiftGuid = @shiftGuid  AND State =0 AND IsPayment = 1 AND Type <> 3 AND Type <> 6 AND type <> 0
		 
		 -- Add External Receivce information  تحصيل خارجي
		  INSERT INTO @Temp
			  SELECT 18, IsPayment AS IsPayment, [Type], CurrencyGUID, Guid, CurrencyValue, Amount, Amount * CurrencyValue 
			   FROM POSSDExternalOperation000 
	           WHERE ShiftGuid = @shiftGuid AND State =0 AND IsPayment = 0 AND Type <> 3 AND Type <> 6  AND Type <> 0
        
		-- Add Central Cash Payemnt information  دفع للصندوق المركزي
		  INSERT INTO @Temp
			  SELECT 19, IsPayment AS IsPayment, [Type], CurrencyGUID, Guid, CurrencyValue, Amount* -1, Amount * CurrencyValue * -1
			   FROM POSSDExternalOperation000 
	           WHERE ShiftGuid = @shiftGuid  AND State = 0 AND IsPayment = 1 AND Type = 3
        
		-- Add Central Cash Receive information  قبض من الصندوق المركزي
		  INSERT INTO @Temp
			  SELECT 21, IsPayment AS IsPayment, [Type], CurrencyGUID, Guid, CurrencyValue, Amount, Amount * CurrencyValue 
			   FROM POSSDExternalOperation000 
	           WHERE ShiftGuid = @shiftGuid  AND State =0 AND IsPayment = 0 AND Type = 3
  
	   --Add Opening Cash information رصيد افتتاحي
	     INSERT INTO @Temp SELECT 16 , IsPayment, Type , CurrencyGUID, Guid, CurrencyValue, Amount, Amount * CurrencyValue
			               FROM POSSDExternalOperation000 
	                       WHERE ShiftGuid = @shiftGuid  AND GenerateState = 0 
	  
	   --Add Cash Difference information فرق الصندوق
		INSERT INTO @Temp 
		SELECT 20 , IsPayment, Type , CurrencyGUID, Guid, CurrencyValue, CASE CreditAccountGUID WHEN @employeeExtraAccountGuid THEN Amount  ELSE Amount* -1 END,
		 CASE CreditAccountGUID WHEN @employeeExtraAccountGuid THEN  Amount* CurrencyValue ELSE  Amount * CurrencyValue * -1 END
		 FROM POSSDExternalOperation000 
	                       WHERE ShiftGuid = @shiftGuid  AND GenerateState = 1 AND Type = 6
						   AND (
						        CreditAccountGUID = @employeeExtraAccountGuid
						        OR DebitAccountGUID = @employeeMinusAccountGuid
							    )
	  
	   --Add Continues Cash information رصيد مدور
	    INSERT INTO @Temp SELECT 22 , IsPayment, [Type] , CurrencyGUID, [Guid], CurrencyValue, Amount * -1, Amount * CurrencyValue* -1
		 FROM POSSDExternalOperation000 
	                       WHERE ShiftGuid = @shiftGuid  AND GenerateState = 1 AND [Type] = 0
						   --AND ( DebitAccountGUID IN (SELECT FloatCachAccGUID FROM POSSDStationCurrency000 RC WHERE StationGUID = @posGuid  
								 --                 UNION  (SELECT ContinuesCashGUID FROM POSSDStation000 WHERE Guid = @posGuid)) )
		
	SELECT DISTINCT TransactionType, IsPayment, ExternalTransactionType, TransactionGUID,
	COUNT( TransactionGUID) OVER (PARTITION BY TransactionType) TransactionsCount,
	(CASE TransactionType WHEN 8 THEN (SUM (sumAmount) OVER (PARTITION BY  TransactionType, TransactionGUID)) ELSE (SUM (sumAmount) OVER (PARTITION BY  TransactionType)) END )SumTransactionTotal,
	CurrencyGUID,
	(CASE TransactionType WHEN 8 THEN (SUM (AmountValue) OVER (PARTITION BY  TransactionType, CurrencyGUID, TransactionGUID)) ELSE (SUM(AmountValue) OVER (PARTITION BY  TransactionType, CurrencyGUID)) END )AmountValue
    FROM @Temp 
END
#################################################################
#END 