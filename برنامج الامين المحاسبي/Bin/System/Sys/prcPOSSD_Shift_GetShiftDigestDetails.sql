#################################################################
CREATE PROCEDURE prcPOSSD_Shift_GetShiftDigestDetails
@shiftGUID [UNIQUEIDENTIFIER]
AS
BEGIN

	DECLARE @shiftEmployeeGuid		  UNIQUEIDENTIFIER = (SELECT EmployeeGUID	  FROM POSSDShift000	WHERE [GUID] = @shiftGUID)
	DECLARE @employeeExtraAccountGuid UNIQUEIDENTIFIER = (SELECT ExtraAccountGUID FROM POSSDEmployee000 WHERE [GUID] = @shiftEmployeeGuid)
	DECLARE @employeeMinusAccountGuid UNIQUEIDENTIFIER = (SELECT MinusAccountGUID FROM POSSDEmployee000 WHERE [GUID] = @shiftEmployeeGuid)
	DECLARE @posGuid				  UNIQUEIDENTIFIER = (SELECT StationGUID	  FROM POSSDShift000	WHERE [GUID] = @shiftGUID)
	DECLARE @defaultCurrency		  UNIQUEIDENTIFIER = (SELECT [dbo].[fnGetDefaultCurr]())

	--======== Currencies
	SELECT 
		1 AS TransactionType, 
		PT.[GUID] AS TransactionGuid, 
		0 AS ExternalTransactionType, 
		0 AS IsPayment, 
		PT.Number AS Number, 
		PT.OpenDate AS OpenDate, 
		PT.PaymentDate AS CloseDate, 
		ABS(PT.Net) AS Amount, 
		PT.CustomerGuid AS CustomerGuid, 
		ISNULL(PC.value, 0) AS PartialAmount, 
		ISNULL(PC.CurrencyGUID, @defaultCurrency) AS CurrencyGUID, 
		ISNULL(PC.CurrencyVal, 1) AS CurrencyValue, 
		'' AS CouponExpireDate, 
		'' AS CouponCode
	FROM 
		POSSDTicket000 PT 
		LEFT JOIN POSSDTicketCurrency000 PC ON PT.[GUID] = PC.TicketGUID
	WHERE 
		ShiftGuid = @shiftGUID 
		AND PT.[Type] = 0 
		AND PT.[State] = 0 
		AND (RelationType <> 1 AND pt.RelationType <> 2)
	
	--======== Default Currency
	UNION ALL
	SELECT 
		1 TransactionType, 
		PT.[GUID] TransactionGuid, 
		0 ExternalTransactionType, 
		0 IsPayment, 
		PT.Number AS Number, 
		PT.OpenDate AS OpenDate, 
		PT.PaymentDate AS CloseDate, 
		ABS(PT.Total) AS Amount, 
		PT.CustomerGuid AS CustomerGuid, 
		ISNULL(PT.Total, 0) AS PartialAmount, 
		@defaultCurrency CurrencyGUID, 
		1 CurrencyValue, 
		'' CouponExpireDate, 
		'' CouponCode
	FROM 
		POSSDTicket000 PT
	WHERE 
		ShiftGuid = @shiftGUID 
		AND PT.[Type] = 0 
		AND PT.[State] = 0 
		AND (RelationType = 1 OR pt.RelationType = 2)
	
	--======== Order DownPayment
	UNION ALL
	SELECT 
		1 TransactionType, 
		PT.[GUID] TransactionGuid, 
		0 ExternalTransactionType, 
		0 IsPayment, 
		PT.Number AS Number, 
		PT.OpenDate AS OpenDate, 
		PT.PaymentDate AS CloseDate, 
		ABS(PT.Total) AS Amount, 
		PT.CustomerGuid AS CustomerGuid, 
		ISNULL(TOI.DownPayment, 0) AS PartialAmount, 
		@defaultCurrency CurrencyGUID, 
		1 CurrencyValue, 
		'' CouponExpireDate, 
		'' CouponCode
	FROM 
		POSSDTicket000 PT
		INNER JOIN POSSDTicketOrderInfo000 TOI ON TOI.TicketGUID = PT.[GUID]
	WHERE 
		PT.ShiftGuid = @shiftGUID 
		AND PT.[Type] = 0 
		AND PT.[State] = 0

	--======== BankCard
	UNION ALL
	SELECT 
		1 TransactionType, 
		PT.[GUID] TransactionGuid, 
		0 ExternalTransactionType, 
		0 IsPayment,  
		Number AS Number, 
		OpenDate AS OpenDate, 
		PaymentDate AS CloseDate, 
		ABS(Net) AS Amount, 
		CustomerGuid AS CustomerGuid, 
		ISNULL(value, 0) AS PartialAmount,
		@defaultCurrency CurrencyGUID, 
		1 CurrencyValue, 
		'' CouponExpireDate, 
		'' CouponCode
	FROM 
		POSSDTicket000 PT 
		LEFT JOIN POSSDTicketBankCard000 PC ON PT.[GUID] = PC.TicketGUID   
	WHERE 
		ShiftGuid = @shiftGUID  
		AND PT.[Type] = 0 
		AND PT.[State] = 0  
		AND (RelationType <> 1 AND pt.RelationType <> 2)

	--======== Return Coupon
	UNION ALL
	SELECT 
		1 TransactionType, 
		PT.[GUID] TransactionGuid, 
		0 ExternalTransactionType, 
		0 IsPayment,  
		Number AS Number, 
		OpenDate AS OpenDate, 
		PaymentDate AS CloseDate, 
		ABS(Net) AS Amount, 
		CustomerGuid AS CustomerGuid, 
		ISNULL(Amount, 0) AS PartialAmount, 
		@defaultCurrency CurrencyGUID, 
		1 CurrencyValue, 
		'' CouponExpireDate, 
		'' CouponCode
	FROM 
		POSSDTicket000 PT 
		LEFT JOIN POSSDTicketReturnCoupon000 RC ON PT.[GUID] = RC.TicketGUID   
	WHERE 
		ShiftGuid = @shiftGUID  
		AND PT.[Type] = 0 
		AND PT.[State] = 0  
		AND (RelationType <> 1 AND pt.RelationType <> 2)
	
	--======================================================================================== Return Sale transaction
	UNION ALL
	SELECT 2 TransactionType, PT.Guid TransactionGuid, 0 ExternalTransactionType, 0 IsPayment,  Number AS Number, OpenDate AS OpenDate, PaymentDate AS CloseDate, Net * -1 AS Amount, CustomerGuid AS CustomerGuid, ISNULL(value, 0) * -1 AS PartialAmount, ISNULL(CurrencyGUID, @defaultCurrency) CurrencyGUID, ISNULL(CurrencyVal, 1) CurrencyValue, '' CouponExpireDate, '' CouponCode
	FROM POSSDTicket000 PT 
	LEFT JOIN POSSDTicketCurrency000 PC ON PT.Guid = PC.TicketGUID   
	WHERE ShiftGuid = @shiftGUID  AND PT.Type = 2 AND PT.State = 0 AND RelationType <> 2 AND RelationType <> 1

	UNION ALL
	SELECT 2 TransactionType, PT.Guid TransactionGuid, 0 ExternalTransactionType, 0 IsPayment,  Number AS Number, OpenDate AS OpenDate, PaymentDate AS CloseDate, Net * -1 AS Amount, CustomerGuid AS CustomerGuid, ISNULL(Net, 0) * -1 AS PartialAmount,  @defaultCurrency CurrencyGUID, 1 CurrencyValue, '' CouponExpireDate, '' CouponCode
	FROM POSSDTicket000 PT  
	WHERE ShiftGuid = @shiftGUID  AND PT.Type = 2 AND PT.State = 0 AND (RelationType = 2 OR RelationType = 1 )

	UNION ALL
	SELECT 2 TransactionType, PT.Guid TransactionGuid, 0 ExternalTransactionType, 0 IsPayment,  Number AS Number, OpenDate AS OpenDate, PaymentDate AS CloseDate, Net * -1 AS Amount, CustomerGuid AS CustomerGuid, ISNULL(Amount, 0) * -1 AS PartialAmount, @defaultCurrency CurrencyGUID, 1 CurrencyValue, '' CouponExpireDate, '' CouponCode
	FROM POSSDTicket000 PT 
	LEFT JOIN POSSDTicketReturnCoupon000 RC ON PT.Guid = RC.TicketGUID   
	WHERE ShiftGuid = @shiftGUID  AND PT.Type = 2 AND PT.State = 0  AND RelationType <> 2 AND RelationType <> 1
	
	--======================================================================================== Deffered transaction
	UNION ALL
	SELECT 6 TransactionType,PT.Guid TransactionGuid, 0 ExternalTransactionType, 0 IsPayment, Number AS Number, OpenDate AS OpenDate, PaymentDate AS CloseDate, Net AS Amount, CustomerGuid AS CustomerGuid, LaterValue * -1 AS PartialAmount, @defaultCurrency CurrencyGUID, 1 CurrencyValue, '' CouponExpireDate, '' CouponCode
	FROM POSSDTicket000 PT 
	WHERE ShiftGuid = @shiftGUID  AND PT.Type = 0 AND LaterValue <> 0

	--======================================================================================== Deffered return sale transaction
	UNION ALL
	SELECT 7 TransactionType,Guid TransactionGuid,0 ExternalTransactionType, 0 IsPayment, Number AS Number, OpenDate AS OpenDate, PaymentDate AS CloseDate, Net AS Amount, CustomerGuid AS CustomerGuid, LaterValue  AS PartialAmount, @defaultCurrency CurrencyGUID, 1 CurrencyValue, '' CouponExpireDate, '' CouponCode
	FROM POSSDTicket000 PT 
	WHERE ShiftGuid = @shiftGUID  AND PT.Type = 2 AND LaterValue <> 0

	--======================================================================================== Bank card
	UNION ALL
	SELECT 8 TransactionType,PB.BankCardGUID TransactionGuid,0 ExternalTransactionType, 0 IsPayment, Number AS Number, OpenDate AS OpenDate, PaymentDate AS CloseDate, Net AS Amount, CustomerGuid AS CustomerGuid, Value * -1 AS PartialAmount, @defaultCurrency CurrencyGUID, 1 CurrencyValue, '' CouponExpireDate, '' CouponCode
	FROM POSSDTicket000 PT 
	INNER JOIN POSSDTicketBankCard000 PB ON PT.Guid = PB.TicketGUID 
	WHERE ShiftGuid = @shiftGUID  AND PT.Type = 0 AND PT.State = 0

	--======================================================================================== Add Return Coupon Release information  تسليم قسائم مرتجع
	UNION ALL
	SELECT 9 TransactionType, PT.GUID TransactionGuid, 0 ExternalTransactionType, 0 IsPayment, Number AS Number, OpenDate AS OpenDate, PaymentDate AS CloseDate, Net AS Amount, PT.CustomerGuid AS CustomerGuid, Rc.Amount AS PartialAmount, @defaultCurrency CurrencyGUID, 1 CurrencyValue, dateadd(dd,R.ExpiryDays,R.TransactionDate) CouponExpireDate, R.Code CouponCode
	FROM POSSDTicket000 PT 
	INNER JOIN POSSDTicketReturnCoupon000 RC ON PT.Guid = Rc.TicketGUID
	INNER JOIN POSSDReturnCoupon000 R ON RC.ReturnCouponGUID = R.GUID
	WHERE PT.ShiftGuid = @shiftGuid AND PT.State = 0 AND RC.Type = 0 AND RC.IsReceipt = 0

	--======================================================================================== Add Return Card Release information  تسليم بطاقات مرتجع
	UNION ALL
	SELECT 10 TransactionType, PT.GUID TransactionGuid, 0 ExternalTransactionType, 0 IsPayment, Number AS Number, OpenDate AS OpenDate, PaymentDate AS CloseDate, Net AS Amount, PT.CustomerGuid AS CustomerGuid, RC.Amount AS PartialAmount, @defaultCurrency CurrencyGUID, 1 CurrencyValue, dateadd(dd,R.ExpiryDays,R.TransactionDate) CouponExpireDate, R.Code CouponCode
	FROM POSSDTicket000 PT 
	INNER JOIN POSSDTicketReturnCoupon000 RC ON PT.Guid = Rc.TicketGUID
	INNER JOIN POSSDReturnCoupon000 R ON RC.ReturnCouponGUID = R.GUID
	WHERE PT.ShiftGuid = @shiftGuid AND PT.State = 0 AND RC.Type = 1 AND RC.IsReceipt = 0
    
	--======================================================================================== Add Return Coupon Receipt information  أستلام قسائم مرتجع    
	UNION ALL
	SELECT 11 TransactionType, PT.GUID TransactionGuid, 0 ExternalTransactionType, 0 IsPayment, Number AS Number, OpenDate AS OpenDate, PaymentDate AS CloseDate, Net AS Amount, PT.CustomerGuid AS CustomerGuid, RC.Amount * -1 AS PartialAmount, @defaultCurrency CurrencyGUID, 1 CurrencyValue, dateadd(dd,R.ExpiryDays,R.TransactionDate) CouponExpireDate, R.Code CouponCode
	FROM POSSDTicket000 PT 
	INNER JOIN POSSDTicketReturnCoupon000 RC ON PT.Guid = Rc.TicketGUID
	INNER JOIN POSSDReturnCoupon000 R ON RC.ReturnCouponGUID = R.GUID
	WHERE PT.ShiftGuid = @shiftGuid AND PT.Type = 0 AND PT.State = 0 AND RC.Type = 0 AND RC.IsReceipt = 1

	--======================================================================================== Add Return Coupon Receipt information  أستلام قسائم مرتجع    
	UNION ALL
	SELECT 12 TransactionType, OI.GUID TransactionGuid, 0 ExternalTransactionType, 0 IsPayment, OI.Number AS Number, OE.[Date] AS OpenDate, OE.[Date] AS CloseDate, -OI.DownPayment AS Amount, T.CustomerGuid AS CustomerGuid, 0 AS PartialAmount, @defaultCurrency CurrencyGUID, 1 CurrencyValue, '' CouponExpireDate, '1122' CouponCode
	FROM 
		POSSDOrderEvent000 OE 
		INNER JOIN POSSDTicketOrderInfo000 OI ON OE.OrderGUID = OI.[GUID]
		INNER JOIN POSSDTicket000 T on T.GUID = OI.TicketGUID
	WHERE OE.ShiftGUID = @shiftGuid and OE.[Event] = 14

	--======================================================================================== Add Return Coupon Receipt information  استلام بطاقات مرتجع
	UNION ALL
	SELECT 13 TransactionType, PT.GUID TransactionGuid, 0 ExternalTransactionType, 0 IsPayment, Number AS Number, OpenDate AS OpenDate, PaymentDate AS CloseDate, Net AS Amount, PT.CustomerGuid AS CustomerGuid, RC.Amount * -1 AS PartialAmount, @defaultCurrency CurrencyGUID, 1 CurrencyValue, dateadd(dd,R.ExpiryDays,R.TransactionDate) CouponExpireDate, R.Code CouponCode
	FROM POSSDTicket000 PT 
	INNER JOIN POSSDTicketReturnCoupon000 RC ON PT.Guid = Rc.TicketGUID
	INNER JOIN POSSDReturnCoupon000 R ON RC.ReturnCouponGUID = R.GUID
	WHERE PT.ShiftGuid = @shiftGuid AND PT.Type = 0 AND PT.State = 0 AND RC.Type = 1 AND RC.IsReceipt = 1

	--======================================================================================== External Payment
	UNION ALL
	SELECT 17 TransactionType,Guid TransactionGuid,type ExternalTransactionType, IsPayment IsPayment, Number AS Number, Date AS OpenDate, [Date] AS CloseDate, Amount AS Amount, 0x0 CustomerGuid, Amount* -1 AS PartialAmount, CurrencyGUID CurrencyGUID, CurrencyValue CurrencyValue, '' CouponExpireDate, '' CouponCode
	FROM POSSDExternalOperation000  
	WHERE ShiftGuid = @shiftGUID AND State =0 AND IsPayment = 1 AND Type <> 3 AND Type <> 6 AND Type <> 0

	--======================================================================================== External Receivce
	UNION ALL
	SELECT 18 TransactionType,Guid TransactionGuid,type ExternalTransactionType, IsPayment IsPayment, Number AS Number, Date AS OpenDate, [Date] AS CloseDate, Amount AS Amount, 0x0 CustomerGuid, Amount AS PartialAmount, CurrencyGUID CurrencyGUID, CurrencyValue CurrencyValue, '' CouponExpireDate, '' CouponCode
	FROM POSSDExternalOperation000  
	WHERE ShiftGuid = @shiftGUID AND State =0 AND IsPayment = 0 AND Type <> 3 AND Type <> 6

	--======================================================================================== Central Cash Payemnt
	UNION ALL
	SELECT 19 TransactionType,Guid TransactionGuid,type ExternalTransactionType, IsPayment IsPayment, Number AS Number, Date AS OpenDate, [Date] AS CloseDate, Amount AS Amount, 0x0 CustomerGuid, Amount* -1 AS PartialAmount, CurrencyGUID CurrencyGUID, CurrencyValue CurrencyValue, '' CouponExpireDate, '' CouponCode
	FROM POSSDExternalOperation000  
	WHERE ShiftGuid = @shiftGUID AND State =0 AND IsPayment = 1 AND Type = 3
    
	--======================================================================================== Central Cash Receive
	UNION ALL
	SELECT 21 TransactionType,Guid TransactionGuid,type ExternalTransactionType, IsPayment IsPayment, Number AS Number, [Date] AS OpenDate, [Date] AS CloseDate, Amount AS Amount, 0x0 CustomerGuid, Amount AS PartialAmount, CurrencyGUID CurrencyGUID, CurrencyValue CurrencyValue, '' CouponExpireDate, '' CouponCode
	FROM POSSDExternalOperation000  
	WHERE ShiftGuid = @shiftGUID AND State =0 AND IsPayment = 0 AND Type = 3    
 
	--======================================================================================== افتتاحي
	UNION ALL
	SELECT 16 TransactionType,Guid TransactionGuid,type ExternalTransactionType, IsPayment IsPayment,Number AS Number, [Date] AS OpenDate, [Date] AS CloseDate, Amount AS Amount, 0x0 CustomerGuid , Amount AS PartialAmount, CurrencyGUID CurrencyGUID, CurrencyValue CurrencyValue, '' CouponExpireDate, '' CouponCode
	FROM POSSDExternalOperation000 
	WHERE ShiftGuid = @shiftGuid  AND GenerateState = 0

	--======================================================================================== فرق صندوق  
	UNION ALL
	SELECT 20 TransactionType,Guid TransactionGuid,type ExternalTransactionType,IsPayment IsPayment, Number AS Number, [Date] AS OpenDate, [Date] AS CloseDate, CASE CreditAccountGUID WHEN @employeeExtraAccountGuid THEN Amount  ELSE Amount  END AS Amount, 0x0 CustomerGuid, CASE CreditAccountGUID WHEN @employeeExtraAccountGuid THEN  Amount  ELSE  Amount *-1 END AS PartialAmount, CurrencyGUID CurrencyGUID, CurrencyValue CurrencyValue, '' CouponExpireDate, '' CouponCode
	FROM POSSDExternalOperation000  
	WHERE ShiftGuid = @shiftGuid  AND GenerateState = 1 
	AND ( CreditAccountGUID = @employeeExtraAccountGuid OR DebitAccountGUID = @employeeMinusAccountGuid )

	--======================================================================================== مدور
	UNION ALL
	SELECT 22 TransactionType,Guid TransactionGuid, type ExternalTransactionType, IsPayment IsPayment, Number AS Number, [Date] AS OpenDate, [Date] AS CloseDate, Amount AS Amount, 0x0 CustomerGuid , Amount* -1 AS PartialAmount, CurrencyGUID, CurrencyValue, '' CouponExpireDate, '' CouponCode
	FROM POSSDExternalOperation000 
	WHERE ShiftGuid = @shiftGuid  AND GenerateState = 1 AND [Type] = 0


ORDER BY Number
END
#################################################################
#END 