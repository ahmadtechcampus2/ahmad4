################################################################################
CREATE PROCEDURE prcPOSSD_Shift_GetShifts
-- Params -------------------------------
	@ShiftStartDate    DATETIME
-----------------------------------------   
AS
    SET NOCOUNT ON
------------------------------------------------------------------------
	DECLARE @language INT = [dbo].[fnConnections_getLanguage]()
	DECLARE @OpenShifts BIT = (CASE @ShiftStartDate WHEN '1980-01-01 00:00:00' THEN 1 ELSE 0 END)

	SELECT [GUID] 
	INTO #Shifts 
	FROM POSSDShift000
	WHERE 
		((@OpenShifts = 1 AND CloseDate IS NULL) 
	  OR (@OpenShifts = 0 AND CONVERT(DATE, OpenDate) = CONVERT(DATE, @ShiftStartDate)))

	--=================== TOTAL RECEIVE EXTERNAL OPERATIONS
	SELECT 
		SUM(EX.Amount * EX.CurrencyValue) AS ReceiveOperation, 
		SUM(EX.Amount * EX.CurrencyValue * CASE [Type] WHEN 0 THEN 1 ELSE 0 END) AS OpeningCash,
		SUM(EX.Amount * EX.CurrencyValue * CASE [Type] WHEN 6 THEN 1 ELSE 0 END) AS Cash,
		COUNT(*) AS ReceiveOperationCount,
		EX.ShiftGUID AS ShiftGUID
	INTO #ReceiveExternalOperation
	FROM 
		POSSDExternalOperation000 EX 
		INNER JOIN #Shifts SH ON EX.ShiftGUID = SH.[GUID]
	WHERE 
		EX.IsPayment = 0
		AND [State]  = 0
	GROUP BY 
		EX.ShiftGUID
		

	--=================== TOTAL PAYMENT EXTERNAL OPERATIONS
	SELECT 
		SUM(EX.Amount * EX.CurrencyValue) AS PaymentOperation,
		SUM(EX.Amount * EX.CurrencyValue * CASE [Type] WHEN 6 THEN 1 ELSE 0 END) AS Cash,
		SUM(EX.Amount * EX.CurrencyValue * CASE [Type] WHEN 3 THEN 1 ELSE 0 END) AS PayCentralBox,
		SUM(EX.Amount * EX.CurrencyValue * CASE [Type] WHEN 0 THEN 1 ELSE 0 END) AS FloatCash,
		COUNT(*) AS PaymentOperationCount,
		EX.ShiftGUID AS ShiftGUID
	INTO #PaymentExternalOperation
	FROM 
		POSSDExternalOperation000 EX 
		INNER JOIN #Shifts SH ON EX.ShiftGUID = SH.[GUID]
	WHERE 
		EX.IsPayment = 1
		AND [State]  = 0
	GROUP BY 
		EX.ShiftGUID

	--=================== TOTAL SALES TRANSACTION
	SELECT 
		COUNT(*)    AS TransactionsCount, 
		SUM(T.Net)  AS TransactionsTotal, 
		T.ShiftGUID AS ShiftGUID
	INTO #ShiftTotalSales
	FROM POSSDTicket000 T 
	INNER JOIN #Shifts S ON S.[GUID] = T.ShiftGUID
	WHERE 
		T.[Type] = 0
		AND T.[State]  = 0
	GROUP BY T.ShiftGUID

	--=================== TOTAL RETURN SALES TRANSACTION
	SELECT 
		COUNT(*)    AS TransactionsCount, 
		SUM(T.Net)  AS TransactionsTotal, 
		T.ShiftGUID AS ShiftGUID
	INTO #ShiftTotalReSales
	FROM POSSDTicket000 T 
	INNER JOIN #Shifts S ON S.[GUID] = T.ShiftGUID
	WHERE 
		T.[Type] = 2
		AND T.OrderType = 0
		AND T.[State] NOT IN (1, 2)
	GROUP BY T.ShiftGUID

	--=================== TOTAL NON CASH TRANSACTION
	DECLARE @ShfitGuid UNIQUEIDENTIFIER
	DECLARE @NonCashTemp TABLE ( TransactionType		 INT,
								 IsPayment				 INT,
								 ExternalTransactionType INT,
								 TransactionGUID		 UNIQUEIDENTIFIER,
								 TransactionsCount		 INT,
								 SumTransactionTotal	 FLOAT,
								 CurrencyGUID			 UNIQUEIDENTIFIER,
								 AmountValue		     FLOAT )

	DECLARE @NonCashTransactionTotal TABLE ( AmountValue FLOAT,
											ShiftGUID	 UNIQUEIDENTIFIER)

	DECLARE @Shifts CURSOR 
	SET @Shifts = CURSOR FAST_FORWARD FOR
	SELECT [GUID] AS ShfitGuid
	FROM #Shifts 
	OPEN @Shifts;	

		FETCH NEXT FROM @Shifts INTO @ShfitGuid;
		WHILE (@@FETCH_STATUS = 0)
		BEGIN  
			
			INSERT INTO @NonCashTemp
			EXEC [dbo].[prcPOSSD_Shift_GetShiftDigestInfo] @ShfitGuid

			DELETE @NonCashTemp WHERE TransactionType NOT IN (6, 7, 8, 9, 10, 11, 12)
			INSERT INTO @NonCashTransactionTotal
			SELECT SUM(AmountValue), @ShfitGuid FROM @NonCashTemp

			DELETE @NonCashTemp
			
		FETCH NEXT FROM @Shifts INTO @ShfitGuid;
		END

		CLOSE      @Shifts;
		DEALLOCATE @Shifts;

	

	--=================== RESULT
	SELECT 
		SH.[GUID],
		SH.StationGUID,
		SH.EmployeeGUID,
		CASE @language WHEN 0 THEN S.Name
					   ELSE CASE S.LatinName WHEN '' THEN S.Name 
											 ELSE S.LatinName END END           AS StationName,
		CASE @language WHEN 0 THEN E.Name
					   ELSE CASE E.LatinName WHEN '' THEN E.Name 
											 ELSE E.LatinName END END           AS EmployeeName,

		SH.Code																	AS Code,
		CASE WHEN SH.CloseDate IS NULL THEN 0 ELSE 1 END					    AS [State],
		SH.OpenDate															    AS OpenDate,
		ISNULL(SH.CloseDate,'1980-01-01')										AS CloseDate,
		ISNULL(TS.TransactionsCount, 0)											AS SalesCount,
		ISNULL(TS.TransactionsTotal, 0)											AS SalesTotal,
		ISNULL(TRS.TransactionsCount, 0)										AS ReturnSalesCount,
		ISNULL(TRS.TransactionsTotal, 0)										AS ReturnSalesTotal,
		ISNULL(REX.OpeningCash, 0)												AS OpeningCash,
		ISNULL(REX.ReceiveOperationCount, 0)									AS ReceiveOperationCount,
		ISNULL(REX.ReceiveOperation, 0)											AS ReceiveOperationTotal,
		ISNULL(PEX.PaymentOperationCount, 0)									AS PaymentOperationCount,
		ISNULL(PEX.PaymentOperation, 0)											AS PaymentOperationTotal,
		ISNULL(REX.ReceiveOperation, 0) - ISNULL(PEX.PaymentOperation, 0)		AS ExternalOperationAmount,
		ISNULL(TS.TransactionsTotal, 0) - ISNULL(TRS.TransactionsTotal, 0) + 
	    (ISNULL(REX.ReceiveOperation, 0) - ISNULL(PEX.PaymentOperation, 0))	+
		ISNULL(NonCash.AmountValue, 0)											AS Cash,
		ABS(ISNULL(REX.Cash, 0) - ISNULL(PEX.Cash, 0))							AS DeficitSurplus,
		CASE WHEN ISNULL(REX.Cash, 0) > ISNULL(PEX.Cash, 0) THEN 1 ELSE 0 END	AS CashType,
		ISNULL(PEX.PayCentralBox, 0)											AS PayCentralBox,
		ISNULL(PEX.FloatCash, 0)												AS FloatCash
	FROM 
		#Shifts SHR 
		INNER JOIN POSSDShift000 SH ON SHR.[GUID] = SH.[GUID]
		INNER JOIN POSSDStation000 S ON S.[GUID] = SH.StationGUID
		INNER JOIN POSSDEmployee000 E ON E.[GUID] = SH.EmployeeGUID
		LEFT JOIN  #ShiftTotalSales TS ON SH.[GUID] = TS.ShiftGUID
		LEFT JOIN  #ShiftTotalReSales TRS ON SH.[GUID] = TRS.ShiftGUID
		LEFT JOIN  #PaymentExternalOperation PEX ON SH.[GUID] = PEX.ShiftGUID
		LEFT JOIN  #ReceiveExternalOperation REX ON SH.[GUID] = REX.ShiftGUID
		LEFT JOIN  @NonCashTransactionTotal NonCash ON SH.[GUID] = NonCash.ShiftGUID
	ORDER BY
		SH.Code
#################################################################
#END

 

