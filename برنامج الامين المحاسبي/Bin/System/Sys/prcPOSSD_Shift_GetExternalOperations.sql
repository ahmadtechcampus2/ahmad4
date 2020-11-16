################################################################################
CREATE PROCEDURE prcPOSSD_Shift_GetExternalOperations
-- Params -------------------------------   
	@ShiftGUID				UNIQUEIDENTIFIER = 0x0,
    @FromNumber			    INT				 = 0,
	@ToNumber				INT				 = 0,
	@ConditionType			INT				 = 0,
	@FirstConditionValue	FLOAT			 = 0.000000,
	@SecondConditionValue	FLOAT			 = 0.000000,
	@AccountGuid			UNIQUEIDENTIFIER = 0x0,
	@ExternalOperationState INT				 = 8,
	@Note					NVARCHAR(250)	 = '',
	@TypeFlag				INT				 = 8388606

		
-----------------------------------------   
AS
    SET NOCOUNT ON
------------------------------------------------------------------------
	DECLARE @ReceiveBalance			       INT = 2
	DECLARE @ReceiveDebit			       INT = 4
	DECLARE @ReceiveCredit			       INT = 8
	DECLARE @ReceiveCentralCash		       INT = 16
	DECLARE @ReceiveExpense			       INT = 32
	DECLARE @ReceiveIncome			       INT = 64
	DECLARE @ReceiveCash			       INT = 128
	DECLARE @PayBalance				       INT = 256
	DECLARE @PayDebit				       INT = 512
	DECLARE @PayCredit				       INT = 1024
	DECLARE @PayCentralCash			       INT = 2048
	DECLARE @PayExpense				       INT = 4096
	DECLARE @PayIncome				       INT = 8192
	DECLARE @PayCash				       INT = 16384
	DECLARE @ReceiveOrderDownPayment       INT = 32768
	DECLARE @ReceiveOrderDriverPayment     INT = 65536
	DECLARE @PayOrderDownPayment           INT = 131072
	DECLARE @PayOrderDriverPayment	       INT = 262144
	DECLARE @PayDownPayment			       INT = 524288
	DECLARE @PaySettlementDriverPayment    INT = 1048576
	DECLARE @ReceiveRemainingDriverPayment INT = 2097152
	DECLARE @PayRemainingDriverPayment	   INT = 4194304

	DECLARE @Lang INT = [dbo].[fnConnections_getLanguage]()

------------------------------- EXTERNAL OPERATIONS
	SELECT	EO.[Guid],
			EO.Number,
			EO.[State],
			EO.IsPayment,
			EO.[Type],
			EO.DebitAccountGUID				AS DebitAccountGuid,
			EO.CreditAccountGUID			AS CreditAccountGuid,
			DAC.Code + ' - ' + CASE @Lang WHEN 0 THEN DAC.Name 
										  ELSE CASE DAC.LatinName WHEN '' THEN DAC.Name
																  ELSE DAC.LatinName END END  AS DebitAccount,
			
			CAC.Code + ' - ' + CASE @Lang WHEN 0 THEN CAC.Name 
										  ELSE CASE CAC.LatinName WHEN '' THEN CAC.Name
																  ELSE CAC.LatinName END END  AS CreditAccount,
			ISNULL(CASE @Lang WHEN 0 THEN CU.CustomerName 
							  ELSE CASE CU.LatinName WHEN '' THEN CU.CustomerName
													 ELSE CU.LatinName END END, '')		      AS CustomerName,
			CASE @Lang WHEN 0 THEN MY.Name 
					   ELSE CASE MY.LatinName WHEN '' THEN MY.Name 
											  ELSE MY.LatinName END END						  AS Currency,
			EO.Amount * EO.CurrencyValue    AS Amount,
			EO.CurrencyValue,
			EO.Amount					    AS CurrencyAmount,
			EO.[Date],
			EO.Note,
			ISNULL(SCC.CentralBoxReceiptId, 0) AS CentralBoxReceiptId,
			POSD.DeviceName,
			POSD.DeviceID
	INTO #ExternalOperationsResult
	FROM 
		POSSDExternalOperation000 EO
		LEFT JOIN POSSDShiftCashCurrency000 SCC ON EO.ShiftGUID = SCC.ShiftGUID AND EO.CurrencyGUID = SCC.CurrencyGUID
		LEFT JOIN ac000 DAC ON EO.DebitAccountGUID  = DAC.[GUID]
		LEFT JOIN ac000 CAC ON EO.CreditAccountGUID = CAC.[GUID]
		LEFT JOIN my000 MY  ON EO.CurrencyGUID      =  MY.[GUID]
		LEFT JOIN cu000 CU  ON EO.CustomerGUID		=  CU.[GUID]
		LEFT JOIN POSSDShift000 SH                   ON EO.ShiftGUID = SH.[GUID]
		LEFT JOIN POSSDStationDevice000 AS POSD	   ON (POSD.DeviceID = EO.DeviceID	AND POSD.StationGUID = SH.StationGUID)		
	WHERE 
		EO.ShiftGUID  = @ShiftGUID
		AND    ((EO.DebitAccountGUID  IN (SELECT [GUID] FROM [dbo].[fnGetAccountsList](@AccountGuid,0)))
			 OR	(EO.CreditAccountGUID IN (SELECT [GUID] FROM [dbo].[fnGetAccountsList](@AccountGuid,0))) )
		AND	    (EO.Number >= @FromNumber   OR @FromNumber   = 0)
		AND     (EO.Number <= @ToNumber     OR @ToNumber     = 0)
		AND	   ((EO.Amount > @FirstConditionValue AND @ConditionType =0)
			 OR (EO.Amount < @FirstConditionValue AND @ConditionType =1) 
			 OR (EO.Amount = @FirstConditionValue AND @ConditionType =2)
			 OR((EO.Amount BETWEEN @FirstConditionValue AND @SecondConditionValue) AND  @ConditionType =3))
		AND	   ((EO.[State] = 0  AND @ExternalOperationState & 2 = 2)
			 OR (EO.[State] = 1  AND @ExternalOperationState & 4 = 4))
		AND     (@Note	   = ''  OR EO.Note  LIKE  '%'+ @Note + '%')
		AND	  (((EO.[Type] = 0   AND EO.IsPayment = 0) AND (@TypeFlag & @ReceiveBalance	               = @ReceiveBalance))		 
			OR ((EO.[Type] = 1   AND EO.IsPayment = 0) AND (@TypeFlag & @ReceiveDebit		           = @ReceiveDebit))	
			OR ((EO.[Type] = 2   AND EO.IsPayment = 0) AND (@TypeFlag & @ReceiveCredit	               = @ReceiveCredit))
			OR ((EO.[Type] = 3   AND EO.IsPayment = 0) AND (@TypeFlag & @ReceiveCentralCash            = @ReceiveCentralCash))
			OR ((EO.[Type] = 4   AND EO.IsPayment = 0) AND (@TypeFlag & @ReceiveExpense	               = @ReceiveExpense))
			OR ((EO.[Type] = 5   AND EO.IsPayment = 0) AND (@TypeFlag & @ReceiveIncome	               = @ReceiveIncome))
			OR ((EO.[Type] = 6   AND EO.IsPayment = 0) AND (@TypeFlag & @ReceiveCash		           = @ReceiveCash))
			OR ((EO.[Type] = 7   AND EO.IsPayment = 0) AND (@TypeFlag & @ReceiveOrderDownPayment       = @ReceiveOrderDownPayment))
			OR ((EO.[Type] = 9   AND EO.IsPayment = 0) AND (@TypeFlag & @ReceiveOrderDriverPayment     = @ReceiveOrderDriverPayment))
			OR ((EO.[Type] = 11  AND EO.IsPayment = 0) AND (@TypeFlag & @ReceiveRemainingDriverPayment = @ReceiveRemainingDriverPayment))
			OR ((EO.[Type] = 0   AND EO.IsPayment = 1) AND (@TypeFlag & @PayBalance                    = @PayBalance))
			OR ((EO.[Type] = 1   AND EO.IsPayment = 1) AND (@TypeFlag & @PayDebit                      = @PayDebit))
			OR ((EO.[Type] = 2   AND EO.IsPayment = 1) AND (@TypeFlag & @PayCredit                     = @PayCredit))
			OR ((EO.[Type] = 3   AND EO.IsPayment = 1) AND (@TypeFlag & @PayCentralCash                = @PayCentralCash))
			OR ((EO.[Type] = 4   AND EO.IsPayment = 1) AND (@TypeFlag & @PayExpense                    = @PayExpense))
			OR ((EO.[Type] = 5   AND EO.IsPayment = 1) AND (@TypeFlag & @PayIncome                     = @PayIncome))
			OR ((EO.[Type] = 6   AND EO.IsPayment = 1) AND (@TypeFlag & @PayCash                       = @PayCash))
			OR ((EO.[Type] = 7   AND EO.IsPayment = 1) AND (@TypeFlag & @PayOrderDownPayment           = @PayOrderDownPayment))
			OR ((EO.[Type] = 9   AND EO.IsPayment = 1) AND (@TypeFlag & @PayOrderDriverPayment         = @PayOrderDriverPayment))
			OR ((EO.[Type] = 8   AND EO.IsPayment = 1) AND (@TypeFlag & @PayDownPayment		           = @PayDownPayment))
			OR ((EO.[Type] = 10  AND EO.IsPayment = 1) AND (@TypeFlag & @PaySettlementDriverPayment    = @PaySettlementDriverPayment))
			OR ((EO.[Type] = 11  AND EO.IsPayment = 1) AND (@TypeFlag & @PayRemainingDriverPayment     = @PayRemainingDriverPayment))   )
		  
			 
------------------------------- RECEIVE EXTERNAL OPERATIONS TOTALS
	SELECT [Type]		     AS OperationType,
		   COUNT(Amount)     AS OperationCount, 
		   SUM(Amount * CurrencyValue)       AS OperationTotal		   
	INTO #ReceiveExternalOperationsTotals
	FROM POSSDExternalOperation000
	WHERE ShiftGUID  = @ShiftGUID
	AND   IsPayment  = 0
	AND   [State]    = 0 
	GROUP BY [Type]

	--------- add total of receive external operations totals
	INSERT INTO #ReceiveExternalOperationsTotals VALUES(
		12,
		(SELECT ISNULL(SUM(OperationCount), 0) FROM #ReceiveExternalOperationsTotals),
		(SELECT ISNULL(SUM(OperationTotal), 0) FROM #ReceiveExternalOperationsTotals)
	)


------------------------------- PAY EXTERNAL OPERATIONS TOTALS
	SELECT [Type]		     AS OperationType,
		   COUNT(Amount)     AS OperationCount, 
		   SUM(Amount * CurrencyValue)       AS OperationTotal 
	INTO #PayExternalOperationsTotals
	FROM POSSDExternalOperation000
	WHERE ShiftGUID  = @ShiftGUID
	AND   IsPayment  = 1
	AND   [State]    = 0 
	GROUP BY [Type]

	--------- add total of pay external operations totals
	INSERT INTO #PayExternalOperationsTotals VALUES(
		12,
		(SELECT ISNULL(SUM(OperationCount), 0) FROM #PayExternalOperationsTotals),
		(SELECT ISNULL(SUM(OperationTotal), 0) FROM #PayExternalOperationsTotals)
	)


------------------------------- FINAL NET TOTAL
DECLARE @AllExternalOperationsCount	INT
SET     @AllExternalOperationsCount = (SELECT COUNT(Amount) FROM POSSDExternalOperation000 WHERE ShiftGUID = @ShiftGUID AND [State] = 0)
DECLARE @AllExternalOperationsTotal FLOAT 
SET     @AllExternalOperationsTotal = (SELECT ISNULL(SUM(Amount * CurrencyValue), 0) FROM POSSDExternalOperation000 WHERE ShiftGUID = @ShiftGUID AND IsPayment = 0 AND [State] = 0) 
								    - (SELECT ISNULL(SUM(Amount * CurrencyValue), 0) FROM POSSDExternalOperation000 WHERE ShiftGUID = @ShiftGUID AND IsPayment = 1 AND [State] = 0)


--------------------  R E S U L T S  --------------------
SELECT * FROM #ExternalOperationsResult		   ORDER BY Number
SELECT * FROM #ReceiveExternalOperationsTotals ORDER BY OperationType
SELECT * FROM #PayExternalOperationsTotals     ORDER BY OperationType
SELECT @AllExternalOperationsCount AS AllExternalOperationsCount,
	   @AllExternalOperationsTotal AS AllExternalOperationsTotal
#################################################################
#END