################################################################################
CREATE PROCEDURE prcGetShiftDetailsTickets
-- Params ------------------------------- 
	@TicketGuid				UNIQUEIDENTIFIER	= 0x0,  
	@TicketsType			INT = 0, -- 0: All, 1: Sales, 2: Purchases, 3: ReturnedSales, 4: Returned Purchases 
	@ShiftGuid				UNIQUEIDENTIFIER	= 0x0,
	@FromNumber				INT					= 0,
	@ToNumber				INT					= 0,
	@PayType				INT					= 14,
	@ConditionType			INT					= 0,
	@FirstConditionValue	FLOAT				= 0.000000,
	@SecondConditionValue	FLOAT				= 0.000000,
	@CustomerGUID			UNIQUEIDENTIFIER	= 0x0,
	@MaterialGUID			UNIQUEIDENTIFIER	= 0x0,
	@GroupGUID				UNIQUEIDENTIFIER	= 0x0,
	@TicketState			INT					= 14,
	@TicketNote				NVARCHAR(250)		= ''
AS
    SET NOCOUNT ON
	------------------------------------------------------------------------
	CREATE TABLE #TicketItemCalcDiscAndExtra
	(
		ItemGuid				UNIQUEIDENTIFIER,
		TicketGuid				UNIQUEIDENTIFIER,
		ValueToDiscount			FLOAT,
		ValueToAdd				FLOAT,
		ValueAfterCalc			FLOAT,
		totalDiscount			FLOAT,
		ItemDiscount			FLOAT,
		Discount				FLOAT,
		totalAddition			FLOAT,
		ItemAddition			FLOAT,
		Addition				FLOAT
	)
	IF(@TicketGuid <> 0x0)
	BEGIN
		SET @TicketsType = (SELECT [Type] FROM POSTicket000 WHERE [Guid] = @TicketGuid) + 1
	END

	IF(@TicketsType = 1)
	BEGIN
		-- Sales tickets
		INSERT INTO #TicketItemCalcDiscAndExtra EXEC prcPOSGetTicketItemsWithCalcDiscAndExtra 0;
	END

	IF(@TicketsType = 3)
	BEGIN
		-- Sales Return tickets
		INSERT INTO #TicketItemCalcDiscAndExtra EXEC prcPOSGetTicketItemsWithCalcDiscAndExtra 2;
	END
	------------------------------------------------------------------------
	SELECT Items.TicketGuid, 
		   SUM(TICDE.Discount) AS IDiscVal,
		   SUM(TICDE.Addition) AS IExtrVal
	INTO #TempItem
	FROM 
		#TicketItemCalcDiscAndExtra TICDE
		LEFT JOIN POSTicketItem000 Items ON TICDE.ItemGuid = Items.[Guid]
		LEFT JOIN mt000 MT ON Items.MatGuid = MT.[GUID]
	WHERE 
		(Items.TicketGuid = @TicketGuid   OR @TicketGuid   = 0x0)
		AND   (MatGuid          = @MaterialGUID OR @MaterialGUID = 0x0)
		AND   (MT.GroupGUID     = @GroupGUID    OR @GroupGUID    = 0x0)
	GROUP BY Items.TicketGuid
	------------------------------- TICKETS
	SELECT 
		TICKET.[GUID]											AS [GUID],
		TICKET.Number											AS Number,
		TotalItems.IDiscVal										AS DiscValue,
		TotalItems.IExtrVal										AS AddedValue,
		ISNULL(TICKET.TaxTotal, 0)								AS TaxTotal,
		ISNULL(TICKET.Total, 0)									AS Total,
		ISNULL(TICKET.Net, 0)									AS NetValue,
		ISNULL(TICKET.CollectedValue, 0)						AS CollectedValue,
		ISNULL(TICKET.LaterValue, 0)							AS LaterValue,
		TICKET.OpenDate											AS OpenDate,
		ISNULL(TICKET.PaymentDate, '1980-01-01 00:00:00')		AS CloseDate,
		CU.acCode + ' - ' + CU.acName							AS CustomerAcc,
		TICKET.[State]											AS TicketState,
		CAST(SH.Code AS NVARCHAR(250))							AS ShiftCode,
		Emp.Name												AS EmployeeName,
		TICKET.Note												AS Note
	INTO #TicketsResult
	FROM	    
		POSTicket000   TICKET 
		INNER JOIN  #TempItem      TotalItems  ON TICKET.[Guid]       = TotalItems.TicketGuid
		LEFT  JOIN  vwCuAc	       CU          ON TICKET.CustomerGuid = CU.cuGUID
		LEFT  JOIN  POSShift000    SH          ON TICKET.ShiftGuid    = SH.[GUID]
		LEFT  JOIN  POSCard000     [Card]	   ON SH.POSGuid		  = [Card].[Guid]
		LEFT  JOIN  POSEmployee000 Emp		   ON SH.EmployeeId       = Emp.[Guid]
	WHERE    
		(TICKET.ShiftGuid = @ShiftGuid	 OR @ShiftGuid    = 0x0)
		AND		 ((@TicketsType > 0 AND TICKET.Type = (@TicketsType-1)) OR @TicketsType = 0)
		AND		 (CustomerGuid  =  @CustomerGUID OR @CustomerGUID = 0x0)
		AND		 (TICKET.Number >= @FromNumber   OR @FromNumber   = 0)
		AND      (TICKET.Number <= @ToNumber     OR @ToNumber     = 0)
		AND		((ISNULL(TICKET.Total, 0) - ISNULL(TICKET.DiscValue, 0) + ISNULL(TICKET.AddedValue, 0) > @FirstConditionValue AND @ConditionType =0)
			  OR (ISNULL(TICKET.Total, 0) - ISNULL(TICKET.DiscValue, 0) + ISNULL(TICKET.AddedValue, 0) < @FirstConditionValue AND @ConditionType =1) 
			  OR (ISNULL(TICKET.Total, 0) - ISNULL(TICKET.DiscValue, 0) + ISNULL(TICKET.AddedValue, 0) = @FirstConditionValue AND @ConditionType =2)
			  OR((ISNULL(TICKET.Total, 0) - ISNULL(TICKET.DiscValue, 0) + ISNULL(TICKET.AddedValue, 0) BETWEEN @FirstConditionValue AND @SecondConditionValue) AND  @ConditionType =3) )
		AND		((TICKET.LaterValue     = 0 AND TICKET.CollectedValue != 0 AND @PayType & 2 = 2 )
			  OR (TICKET.CollectedValue = 0 AND TICKET.LaterValue     != 0 AND @PayType & 4 = 4 )
			  OR (TICKET.LaterValue    != 0 AND TICKET.CollectedValue != 0 AND @PayType & 8 = 8)
			  OR (TICKET.LaterValue     = 0 AND TICKET.CollectedValue  = 0 AND @PayType = 14))
		AND		((TICKET.[State] = 0 AND @TicketState & 2 = 2)
			  OR (TICKET.[State] = 1 AND @TicketState & 4 = 4)
			  OR (TICKET.[State] = 2 AND @TicketState & 8 = 8))
		AND      (@TicketNote	 = '' OR TICKET.Note  LIKE  '%'+ @TicketNote + '%')
------------------------------- MTERILAS
	SELECT 
		TItems.MatGuid																	 AS MatGuid,
		MT.mtCode + ' - ' + MT.mtName  													 AS MatName,
		SUM(TItems.Qty)																	 AS Quantity,
		SUM(TItems.Value) / SUM(TItems.Qty) 											 AS Price,
		SUM(TItems.Value)																 AS Value,
		SUM(TICDE.ItemDiscount)															 AS ItemDiscount,
		SUM(TICDE.totalDiscount)														 AS  TotalDiscount,
		SUM(TICDE.Discount)																 AS ValueDiscount,
		SUM(TICDE.ItemAddition)															 AS ItemExtra,
		SUM(TICDE.totalAddition)														 AS TotalExtra,
		SUM(TICDE.Addition)																 AS ValueExtra,
		SUM(TItems.Tax)																	 AS Tax,
		SUM(TItems.Value) - SUM(TICDE.Discount) + SUM(TICDE.Addition) + SUM(TItems.Tax)  AS NetBalance,
		CASE TItems.UnitType WHEN 0 THEN MT.mtUnity
								WHEN 1 THEN MT.mtUnit2
								WHEN 2 THEN MT.mtUnit3 END					AS Unit,
		TItems.UnitType													AS UnitIndex

	INTO #MaterialsResult
	FROM	   
		POSTicketItem000 TItems
		INNER JOIN #TicketsResult TR				 ON TItems.TicketGuid = TR.[GUID]
		LEFT  JOIN #TicketItemCalcDiscAndExtra TICDE ON TItems.[Guid]     = TICDE.ItemGuid
		LEFT  JOIN vwmt	MT							 ON TItems.MatGuid	  = MT.mtGUID
	WHERE 
		(TItems.MatGuid = @MaterialGUID OR @MaterialGUID = 0x0)
		AND   (MT.mtGroup     = @GroupGUID    OR @GroupGUID    = 0x0)   
	GROUP BY   TItems.MatGuid,
			   MT.mtName,
			   MT.mtCode,
			   TItems.UnitType,
			   MT.mtUnity,
			   MT.mtUnit2,
			   MT.mtUnit3

	DECLARE @TicketPays TABLE (
		TicketGUID UNIQUEIDENTIFIER,
		RecordGUID UNIQUEIDENTIFIER,
		IsCurrency BIT,
		[PayType] INT, -- 1 cash else later
		[Value] FLOAT,
		[CurrencyValue] FLOAT,
		[BankCheckNumber] NVARCHAR(32),
		IsMainCurrency BIT)

	INSERT INTO @TicketPays
	SELECT
		t.GUID, 
		my.GUID,
		1,
		cu.PayType,
		cu.[Value],
		CASE my.CurrencyVal WHEN 1 THEN 1 ELSE cu.[CurrencyVal] END,
		0,
		CASE my.CurrencyVal WHEN 1 THEN 1 ELSE 0 END
	FROM 		
		my000 my
		INNER JOIN POSSDTicketCurrency000 cu ON my.GUID = cu.CurrencyGUID
		INNER JOIN #TicketsResult t ON t.GUID = cu.TicketGUID 
	ORDER BY my.Number 

	INSERT INTO @TicketPays
	SELECT
		t.GUID,
		b.GUID,
		0,
		1, -- cash
		tb.[Value],
		1,
		tb.CheckNumber,
		0
	FROM 		
		BankCard000 b 
		INNER JOIN POSSDTicketBank000 tb ON b.GUID = tb.BankGUID 
		INNER JOIN #TicketsResult t ON t.GUID = tb.TicketGUID 
	ORDER BY 
		b.Number

	--------------------  R E S U L T S  --------------------
	-- TICKETS
	SELECT * FROM #TicketsResult ORDER BY Number
	-- MATERIALS
	SELECT * FROM #MaterialsResult ORDER BY MatName
	-- TICKETS PAYTYPES
	SELECT * FROM @TicketPays

	-- MATERIALS TOTALS FOR ONE TICKET
	if(@TicketGuid != 0x0)
	BEGIN
		SELECT  
			SUM(Value)					AS TotalValues,  
			SUM(ItemDiscount)			AS TotalItemsDisc,
			SUM(TotalDiscount)			AS TotalTotalsDisc,
			SUM(ValueDiscount)			AS TotalValuesDisc,
			SUM(ItemExtra)				AS TotalItemsExtr,
			SUM(TotalExtra)				AS TotalTotalsExtr,
			SUM(ValueExtra)				AS TotalValuesExtr,
			SUM(Tax)					AS TotalTax,
			SUM(NetBalance)				AS TotalNetBalance
		FROM #MaterialsResult
	END ELSE BEGIN
		-- TICKETS TOTALS
		SELECT SUM(Total)			AS TicketTotalValue,
			   SUM(DiscValue)		AS TicketTotalDiscount,
			   SUM(AddedValue)      AS TicketTotalAdded,
			   SUM(TaxTotal)        AS TicketTotalTax,
			   SUM(NetValue)		AS TicketTotalNet,
			   SUM(CollectedValue)  AS TicketTotalCollected,
			   SUM(LaterValue)      AS TicketTotalLater
		FROM #TicketsResult

		-- MATERIALS TOTALS FOR ALL TICKETS
		SELECT SUM(Value)			AS MaterialTotalValue,
			   SUM(ValueDiscount)   AS MaterialTotalDiscount,
			   SUM(ValueExtra)		AS MaterialTotalExtra,
			   SUM(NetBalance)		AS MaterialTotalNet,
			   SUM(Tax)				AS MaterialTotalTax
		FROM #MaterialsResult

		SELECT 
			SUM(CASE IsCurrency 
					WHEN 0 THEN 0 
					ELSE (	CASE [PayType] 
								WHEN 1 THEN ( CASE IsMainCurrency WHEN 1 THEN [Value] * [CurrencyValue] ELSE 0 END )
								ELSE 0 
							END) 
				END) AS TotalCashMainCurrency,
			SUM(CASE IsCurrency 
					WHEN 0 THEN 0 
					ELSE (	CASE [PayType] 
								WHEN 3 THEN ( CASE IsMainCurrency WHEN 1 THEN 0 ELSE [Value] * [CurrencyValue] END )
								ELSE 0
							END) 
				END) AS TotalCurrencies,
			SUM(CASE IsCurrency WHEN 0 THEN [Value] ELSE 0 END) AS TotalBanks
		FROM 
			@TicketPays
	END
################################################################################
CREATE PROCEDURE prcGetShiftDetailsExternalOperations
-- Params -------------------------------   
	@ShiftGuid				UNIQUEIDENTIFIER = 0x0,
    @FromNumber			    INT				 = 0,
	@ToNumber				INT				 = 0,
	@ConditionType			INT				 = 0,
	@FirstConditionValue	FLOAT			 = 0.000000,
	@SecondConditionValue	FLOAT			 = 0.000000,
	@AccountGuid			UNIQUEIDENTIFIER = 0x0,
	@ExternalOperationState INT				 = 8,
	@Note					NVARCHAR(250)	 = '',
	@TypeFlag				INT				 = 32766
-----------------------------------------   
AS
    SET NOCOUNT ON
------------------------------------------------------------------------
	DECLARE @ReceiveBalance     INT = 2
	DECLARE @ReceiveDebit       INT = 4
	DECLARE @ReceiveCredit      INT = 8
	DECLARE @ReceiveCentralCash INT = 16
	DECLARE @ReceiveExpense     INT = 32
	DECLARE @ReceiveIncome      INT = 64
	DECLARE @ReceiveCash        INT = 128
	DECLARE @PayBalance         INT = 256
	DECLARE @PayDebit           INT = 512
	DECLARE @PayCredit          INT = 1024
	DECLARE @PayCentralCash     INT = 2048
	DECLARE @PayExpense         INT = 4096
	DECLARE @PayIncome          INT = 8192
	DECLARE @PayCash            INT = 16384

	DECLARE @Lang				INT = 0  --  0-arabic, 1-latin
	EXEC    @Lang = [dbo].fnConnections_GetLanguage

------------------------------- EXTERNAL OPERATIONS
	SELECT	EO.[Guid],
			EO.Number,
			EO.[State],
			EO.IsPayment,
			EO.[Type],
			EO.DebitAccount                  AS DebitAccountGuid,
			DAC.Code + ' - ' + DAC.Name	     AS DebitAccount,
			EO.CreditAccount		         AS CreditAccountGuid,
			CAC.Code + ' - ' + CAC.Name      AS CreditAccount,
			EO.Amount * EO.CurrencyValue     AS Amount,
			CASE @Lang WHEN 0 THEN MY.Name ELSE CASE MY.LatinName WHEN '' THEN MY.Name ELSE MY.LatinName END END AS Currency,
			EO.CurrencyValue,
			EO.Amount						 AS CurrencyAmount,
			EO.[Date],
			EO.Note

	INTO #ExternalOperationsResult
	FROM POSExternalOperations000 EO
	LEFT JOIN ac000 DAC ON EO.DebitAccount  = DAC.[GUID]
	LEFT JOIN ac000 CAC ON EO.CreditAccount = CAC.[GUID]
	LEFT JOIN my000 MY  ON EO.CurrencyGUID  =  MY.[GUID]

	WHERE ShiftGuid  = @ShiftGuid
	AND    ((EO.DebitAccount  IN (SELECT [GUID] FROM [dbo].[fnGetAccountsList](@AccountGuid,0)))
		 OR	(EO.CreditAccount IN (SELECT [GUID] FROM [dbo].[fnGetAccountsList](@AccountGuid,0))) )
	AND	    (EO.Number >= @FromNumber   OR @FromNumber   = 0)
	AND     (EO.Number <= @ToNumber     OR @ToNumber     = 0)
	AND	   ((EO.Amount > @FirstConditionValue AND @ConditionType =0)
		 OR (EO.Amount < @FirstConditionValue AND @ConditionType =1) 
		 OR (EO.Amount = @FirstConditionValue AND @ConditionType =2)
		 OR((EO.Amount BETWEEN @FirstConditionValue AND @SecondConditionValue) AND  @ConditionType =3))
	AND	   ((EO.[State] = 0 AND @ExternalOperationState & 2 = 2)
		 OR (EO.[State] = 1 AND @ExternalOperationState & 4 = 4))
	AND     (@Note	   = '' OR EO.Note  LIKE  '%'+ @Note + '%')
	AND	  (((EO.[Type] = 0 AND EO.IsPayment = 0) AND (@TypeFlag & @ReceiveBalance	  =	@ReceiveBalance))		 
		OR ((EO.[Type] = 1 AND EO.IsPayment = 0) AND (@TypeFlag & @ReceiveDebit		  =	@ReceiveDebit))	
		OR ((EO.[Type] = 2 AND EO.IsPayment = 0) AND (@TypeFlag & @ReceiveCredit	  =	@ReceiveCredit))
		OR ((EO.[Type] = 3 AND EO.IsPayment = 0) AND (@TypeFlag & @ReceiveCentralCash = @ReceiveCentralCash))
		OR ((EO.[Type] = 4 AND EO.IsPayment = 0) AND (@TypeFlag & @ReceiveExpense	  =	@ReceiveExpense))
		OR ((EO.[Type] = 5 AND EO.IsPayment = 0) AND (@TypeFlag & @ReceiveIncome	  =	@ReceiveIncome))
		OR ((EO.[Type] = 6 AND EO.IsPayment = 0) AND (@TypeFlag & @ReceiveCash		  =	@ReceiveCash))
		OR ((EO.[Type] = 0 AND EO.IsPayment = 1) AND (@TypeFlag & @PayBalance         = @PayBalance))
		OR ((EO.[Type] = 1 AND EO.IsPayment = 1) AND (@TypeFlag & @PayDebit           = @PayDebit))
		OR ((EO.[Type] = 2 AND EO.IsPayment = 1) AND (@TypeFlag & @PayCredit          = @PayCredit))
		OR ((EO.[Type] = 3 AND EO.IsPayment = 1) AND (@TypeFlag & @PayCentralCash     = @PayCentralCash))
		OR ((EO.[Type] = 4 AND EO.IsPayment = 1) AND (@TypeFlag & @PayExpense         = @PayExpense))
		OR ((EO.[Type] = 5 AND EO.IsPayment = 1) AND (@TypeFlag & @PayIncome          = @PayIncome))
		OR ((EO.[Type] = 6 AND EO.IsPayment = 1) AND (@TypeFlag & @PayCash            = @PayCash)))
		  


------------------------------- RECEIVE EXTERNAL OPERATIONS TOTALS
	SELECT [Type]		     AS OperationType,
		   COUNT(Amount)     AS OperationCount, 
		   SUM(Amount)       AS OperationTotal		   
	INTO #ReceiveExternalOperationsTotals
	FROM POSExternalOperations000
	WHERE ShiftGuid  = @ShiftGuid
	AND   IsPayment  = 0
	AND   [State]    = 0 
	GROUP BY [Type]

	--------- add total of receive external operations totals
	INSERT INTO #ReceiveExternalOperationsTotals VALUES(
		7,
		(SELECT ISNULL(SUM(OperationCount), 0) FROM #ReceiveExternalOperationsTotals),
		(SELECT ISNULL(SUM(OperationTotal), 0) FROM #ReceiveExternalOperationsTotals)
	)

------------------------------- PAY EXTERNAL OPERATIONS TOTALS
	SELECT [Type]		     AS OperationType,
		   COUNT(Amount)     AS OperationCount, 
		   SUM(Amount)       AS OperationTotal 
	INTO #PayExternalOperationsTotals
	FROM POSExternalOperations000
	WHERE ShiftGuid  = @ShiftGuid
	AND   IsPayment  = 1
	AND   [State]    = 0 
	GROUP BY [Type]

	--------- add total of pay external operations totals
	INSERT INTO #PayExternalOperationsTotals VALUES(
		7,
		(SELECT ISNULL(SUM(OperationCount), 0) FROM #PayExternalOperationsTotals),
		(SELECT ISNULL(SUM(OperationTotal), 0) FROM #PayExternalOperationsTotals)
	)

------------------------------- FINAL NET TOTAL
DECLARE @AllExternalOperationsCount	INT
SET     @AllExternalOperationsCount = (SELECT COUNT(Amount) FROM POSExternalOperations000 WHERE ShiftGuid = @ShiftGuid AND [State] = 0)

DECLARE @AllExternalOperationsTotal FLOAT 
SET     @AllExternalOperationsTotal = (SELECT ISNULL(SUM(Amount), 0) FROM POSExternalOperations000 WHERE ShiftGuid = @ShiftGuid AND IsPayment = 0 AND [State] = 0) 
								    - (SELECT ISNULL(SUM(Amount), 0) FROM POSExternalOperations000 WHERE ShiftGuid = @ShiftGuid AND IsPayment = 1 AND [State] = 0)

--------------------  R E S U L T S  --------------------

SELECT * FROM #ExternalOperationsResult		   ORDER BY Number
SELECT * FROM #ReceiveExternalOperationsTotals ORDER BY OperationType
SELECT * FROM #PayExternalOperationsTotals     ORDER BY OperationType
SELECT @AllExternalOperationsCount AS AllExternalOperationsCount,
	   @AllExternalOperationsTotal AS AllExternalOperationsTotal

################################################################################
CREATE PROCEDURE prcPOSSDGetMaterialExtended
-- Param --------------------------------
	   @MaterialExtendedType         INT
----------------------------------------- 
AS
    SET NOCOUNT ON
------------------------------------------------------------------------

SELECT ME.[GUID]				 AS MatExtendedGuid,
	   ME.Number				 AS Number,
	   ME.MaterialGUID			 AS MatGuid,
	   MT.Code + ' - ' + MT.Name AS MaterialStr,prcRelatedToPOSSDShift
	   ME.Question				 AS Question,
	   ME.LatinQuestion			 AS LatinQuestion
FROM POSSDMaterialExtended000 ME
INNER JOIN mt000 MT ON ME.MaterialGUID = MT.[GUID]
WHERE ME.[Type] = @MaterialExtendedType
ORDER BY ME.Number
################################################################################
CREATE PROCEDURE prcPOSSDGetRelatedSaleMaterial
-- Param -------------------------------   
	   @ParentGuid UNIQUEIDENTIFIER
-----------------------------------------   
AS
    SET NOCOUNT ON
------------------------------------------------------------------------

SELECT RSM.MaterialGUID AS  MaterialGUID,
	   MT.Code +' - '+MT.Name AS Material
FROM POSSDRelatedSaleMaterial000 RSM 
INNER JOIN POSSDMaterialExtended000 ME ON RSM.ParentGUID = ME.[GUID]
INNER JOIN mt000 MT ON RSM.MaterialGUID = MT.[GUID]
WHERE RSM.ParentGUID = @ParentGuid
################################################################################
CREATE TRIGGER trg_POSSDMaterialExtended000_delete
    ON POSSDMaterialExtended000
    FOR DELETE
AS 
	IF @@ROWCOUNT = 0 RETURN
	SET NOCOUNT ON	

    DELETE POSSDRelatedSaleMaterial000 WHERE ParentGUID IN (SELECT [GUID] FROM deleted)
################################################################################
CREATE PROCEDURE prcPOSGetTicketItemsWithCalcDiscAndExtra
-----------------------------------------  
	@TicketsType INT = 0 -- 0: Sales, 1: Purchases, 2: ReturnedSales, 3: Returned Purchases  
AS
    SET NOCOUNT ON
------------------------------------------------------------------------
SELECT 
  ticketItems.[Guid],
  TicketGuid,
  (CASE ticketItems.IsDiscountPercentage WHEN 0 THEN ISNULL(DiscountValue, 0) ELSE ISNULL(DiscountValue, 0) * (Value - (PresentQty * (Value/Qty))) / 100 END) + (PresentQty * (Value/Qty))			 AS ValueToDiscount,
  (CASE ticketItems.IsAdditionPercentage WHEN 0 THEN ISNULL(AdditionValue, 0) ELSE ISNULL(AdditionValue, 0) * Value / 100 END)																		 AS ValueToAdd,
  Value - ((CASE ticketItems.IsDiscountPercentage WHEN 0 THEN ISNULL(DiscountValue, 0) ELSE ISNULL(DiscountValue, 0) * (Value - (PresentQty * (Value/Qty))) / 100 END) + (PresentQty * (Value/Qty)))
  	    +  (CASE ticketItems.IsAdditionPercentage WHEN 0 THEN ISNULL(AdditionValue, 0) ELSE ISNULL(AdditionValue, 0) * Value / 100 END)																 AS ValueAfterCalc,
  ItemShareOfTotalDiscount,
  ItemShareOfTotalAddition
INTO #TicketItemWithCalcValue
FROM POSTicketItem000 ticketItems
INNER JOIN POSTicket000 ticket ON ticket.[Guid] = ticketItems.[TicketGuid]
WHERE ticket.[Type] = @TicketsType


SELECT TicketGuid, 
	   SUM(ValueToDiscount) AS ItemsTotalDiscount,
	   SUM(ValueToAdd)		AS ItemsTotalAddition
INTO #TotalsItemDiscAndExtra
FROM #TicketItemWithCalcValue
GROUP BY TicketGuid


SELECT TicketGuid, 
	   (CASE T.IsDiscountPercentage WHEN 0 THEN ISNULL(T.DiscValue,  0) ELSE ISNULL(TIDE.ItemsTotalDiscount, 0) * ISNULL(T.DiscValue,  0) / 100 END) TotalDiscount,
	   (CASE T.IsAdditionPercentage WHEN 0 THEN ISNULL(T.AddedValue, 0) ELSE ISNULL(TIDE.ItemsTotalAddition, 0) * ISNULL(T.AddedValue, 0) / 100 END) TotalAddition
INTO #TotalDiscAndExtra
FROM	   POSTicket000 T 
INNER JOIN #TotalsItemDiscAndExtra TIDE ON T.[Guid] = TIDE.TicketGuid
WHERE T.[Type] = @TicketsType


SELECT TICV.[Guid], TICV.TicketGuid, TICV.ValueToDiscount, TICV.ValueToAdd, TICV.ValueAfterCalc,
   --CASE TIDE.ItemsTotalDiscount WHEN 0 THEN 0 ELSE TDE.TotalDiscount * TICV.ValueAfterCalc / TIDE.ItemsTotalDiscount END						 AS totalDiscount,
   TICV.ItemShareOfTotalDiscount																												 AS totalDiscount,
   TICV.ValueToDiscount																															 AS ItemDiscount,
  --(CASE TIDE.ItemsTotalDiscount WHEN 0 THEN 0 ELSE TDE.TotalDiscount * TICV.ValueAfterCalc / TIDE.ItemsTotalDiscount END) + TICV.ValueToDiscount AS Discount
   TICV.ItemShareOfTotalDiscount + TICV.ValueToDiscount																							 AS Discount,
   
   
   --CASE TIDE.ItemsTotalAddition WHEN 0 THEN 0 ELSE TDE.TotalAddition * TICV.ValueAfterCalc / TIDE.ItemsTotalAddition END					     AS totalAddition,
   TICV.ItemShareOfTotalAddition																												 AS totalAddition,
   TICV.ValueToAdd																															     AS ItemAddition,
  --(CASE TIDE.ItemsTotalAddition WHEN 0 THEN 0 ELSE TDE.TotalAddition * TICV.ValueAfterCalc / TIDE.ItemsTotalAddition END) + TICV.ValueToAdd      AS Addition
   TICV.ItemShareOfTotalAddition + TICV.ValueToAdd																								 AS Addition

FROM	  #TicketItemWithCalcValue TICV
LEFT JOIN #TotalsItemDiscAndExtra TIDE ON TICV.TicketGuid = TIDE.TicketGuid
LEFT JOIN #TotalDiscAndExtra TDE	   ON TICV.TicketGuid = TDE.TicketGuid 

################################################################################
CREATE PROCEDURE POSprcTicketGenerateEntry
-- Params -------------------------------
	@ShiftGuid				UNIQUEIDENTIFIER,
	@TicketsType INT = 0 -- 0: Sales, 1: Purchases, 2: ReturnedSales, 3: Returned Purchases  
-----------------------------------------   
AS
    SET NOCOUNT ON
------------------------------------------------------------------------
	DECLARE @EN TABLE (	[Number]			[INT], 
						[Date]				[DATETIME], 
						[Debit]				[FLOAT], 
						[Credit]			[FLOAT], 
						[Notes]				[NVARCHAR](255) COLLATE ARABIC_CI_AI, 
						[CurrencyVal]		[FLOAT],
						[GUID]				[UNIQUEIDENTIFIER], 
						[ParentGUID]		[UNIQUEIDENTIFIER], 
						[accountGUID]		[UNIQUEIDENTIFIER], 
						[CurrencyGUID]		[UNIQUEIDENTIFIER], 
						[ContraAccGUID]		[UNIQUEIDENTIFIER])
			   
	DECLARE @CE TABLE ( [Type] [INT] ,
						[Number] [INT],
						[Date] [datetime] ,
						[Debit] [float],
						[Credit] [FLOAT],
						[Notes] [NVARCHAR](1000) ,
						[CurrencyVal] [FLOAT],
						[IsPosted] [INT],
						[State] [INT],
						[Security] [INT],
						[Num1] [FLOAT],
						[Num2] [FLOAT],
						[Branch] [UNIQUEIDENTIFIER],
						[GUID] [UNIQUEIDENTIFIER],
						[CurrencyGUID] [UNIQUEIDENTIFIER],
						[TypeGUID] [UNIQUEIDENTIFIER],
						[IsPrinted] [BIT],
						[PostDate] [DATETIME])


	DECLARE  @ER TABLE( [GUID] [UNIQUEIDENTIFIER],
						[EntryGUID] [UNIQUEIDENTIFIER],
						[ParentGUID] [UNIQUEIDENTIFIER],
						[ParentType] [INT],
						[ParentNumber] [INT])


	DECLARE @Number			            INT = 0
	DECLARE @ParentType					INT
	DECLARE @LaterValue		            FLOAT
	DECLARE @Note			            NVARCHAR(250)
	DECLARE @AccGuid		            UNIQUEIDENTIFIER
	DECLARE @ShiftControlAccGUID        UNIQUEIDENTIFIER
	DECLARE @DefCurrencyGUID			UNIQUEIDENTIFIER 
	DECLARE @EntryGUID					UNIQUEIDENTIFIER 
	DECLARE @MaxCENumber				INT
	DECLARE @EntryNote					NVARCHAR(1000)
	DECLARE @language					INT
	DECLARE @txt_EntryInShiftTickets	NVARCHAR(250)
	DECLARE @txt_ToPOS					NVARCHAR(250)
	DECLARE @txt_ShiftEmployee			NVARCHAR(250)
	DECLARE @txt_CustomerEntry			NVARCHAR(250)
	DECLARE @txt_InShift				NVARCHAR(250)


	 SET @ParentType = CASE @TicketsType WHEN 2 THEN 704 ELSE 701 END

	 SET @language = [dbo].[fnConnections_getLanguage]() 
	 SET @txt_EntryInShiftTickets = 
			CASE @TicketsType WHEN 2 THEN [dbo].[fnStrings_get]('POS\ENTRYINSHIFTRETSALESTICKETS', @language) 
			ELSE [dbo].[fnStrings_get]('POS\ENTRYINSHIFTTICKETS', @language) END

	SET @txt_CustomerEntry		  = 
			CASE @TicketsType WHEN 2 THEN [dbo].[fnStrings_get]('POS\CUSTOMERENTRYOUT', @language) 
			ELSE [dbo].[fnStrings_get]('POS\CUSTOMERENTRY', @language) END

	 SET @txt_ToPOS				  = [dbo].[fnStrings_get]('POS\TOPOSCARD',			 @language)
	 SET @txt_ShiftEmployee		  = [dbo].[fnStrings_get]('POS\SHIFTEMPLOYEE',		 @language) 
	 SET @txt_InShift			  = [dbo].[fnStrings_get]('POS\INSHIFT',			 @language) 

	 SET @EntryNote = ( SELECT @txt_EntryInShiftTickets +' '+ CAST(S.Code AS NVARCHAR(250)) +' '+ @txt_ToPOS + C.Name +'. '+@txt_ShiftEmployee  +': '+  E.Name
						FROM POSShift000 S
						LEFT JOIN POSCard000 C ON S.POSGuid = C.[Guid]
						LEFT JOIN POSEmployee000 E ON S.EmployeeId = E.[Guid]
						WHERE S.[Guid] =  @ShiftGuid )

	 SET @MaxCENumber     = ISNULL((SELECT MAX(Number) FROM ce000), 0) + 1
	 SET @DefCurrencyGUID = (SELECT TOP 1 [GUID] FROM my000 WHERE CurrencyVal = 1 ORDER BY [Number])
	 SET @EntryGUID       = NEWID()

	INSERT INTO @CE
	SELECT 1																						   AS [Type],
		   @MaxCENumber					    														   AS Number,
		   GETDATE()																				   AS [Date],
		   (SELECT SUM(LaterValue) FROM POSTicket000 WHERE [ShiftGuid] = @ShiftGuid AND [State]  = 0) AS Debit,
		   (SELECT SUM(LaterValue) FROM POSTicket000 WHERE [ShiftGuid] = @ShiftGuid AND [State]  = 0) AS Credit,
		   @EntryNote																				   AS Notes,
		   1																						   AS  CurrencyVal,
		   1																						   AS IsPosted,
		   0																						   AS [State],
		   1																						   AS [Security],
		   0																						   AS Num1,
		   0																						   AS Num2,
		   0x0																						   AS Branch,
		   @EntryGUID																				   AS [GUID],
		   @DefCurrencyGUID																			   AS CurrencyGUID,
		   '00000000-0000-0000-0000-000000000000'													   AS TypeGUID,
		   0																						   AS IsPrinted,
		   GETDATE()																				   AS PostDate



	DECLARE AllShiftTickets		  CURSOR FOR	
	SELECT  
			T.LaterValue,
			@txt_CustomerEntry +' '+ AC.cuCustomerName +  @txt_InShift + CAST(S.Code AS NVARCHAR(250)) +' '+ @txt_ToPOS + C.Name +'. '+ @txt_ShiftEmployee +': '+ E.Name,
			AC.acGUID AS accountGUID,
			C.ShiftControl AS ShiftControlAccGUID
	FROM POSTicket000 T
	LEFT JOIN POSShift000 S    ON T.ShiftGuid    = S.[Guid]
	LEFT JOIN POSCard000  C    ON S.POSGuid      = C.[Guid]
	LEFT JOIN vwCuAc	  AC   ON T.CustomerGuid = AC.cuGUID
	LEFT JOIN POSEmployee000 E ON S.EmployeeId   = E.[Guid]
	WHERE T.ShiftGuid = @ShiftGuid
		AND	T.Type = @TicketsType
		AND	T.[State]  = 0
		AND	T.LaterValue != 0

	DECLARE @DebitAcountGUID UNIQUEIDENTIFIER, @CreditAccountGUID UNIQUEIDENTIFIER

	OPEN AllShiftTickets;	

	FETCH NEXT FROM AllShiftTickets INTO @LaterValue, @Note, @AccGuid, @ShiftControlAccGUID;
	WHILE (@@FETCH_STATUS = 0)
	BEGIN  
		SET @Number = @Number + 1;

		SET @DebitAcountGUID = CASE @TicketsType WHEN 2 THEN @ShiftControlAccGUID ELSE @AccGuid END
		SET @CreditAccountGUID = CASE @TicketsType WHEN 2 THEN @AccGuid ELSE @ShiftControlAccGUID END

		INSERT INTO @EN
		SELECT @Number AS Number,
				GETDATE() AS [Date],
				@LaterValue AS Debit,
				0 AS Credit,
				@Note AS Note,
				1 AS CurrencyVal,
				NEWID() AS [GUID],
				@EntryGUID AS ParentGUID,
				@DebitAcountGUID AS accountGUID,
				@DefCurrencyGUID AS CurrencyGUID,
				@CreditAccountGUID AS ContraAccGUID
		
		SET @Number = @Number + 1;
			
		INSERT INTO @EN
		SELECT	@Number AS Number,
				GETDATE() AS [Date],
				0 AS Debit,
				@LaterValue AS Credit,
				@Note AS Note,
				1 AS CurrencyVal,
				NEWID() AS [GUID],
				@EntryGUID AS ParentGUID,
				@CreditAccountGUID AS accountGUID,
				@DefCurrencyGUID AS CurrencyGUID,
				@DebitAcountGUID AS ContraAccGUID


	   FETCH NEXT FROM AllShiftTickets INTO @LaterValue, @Note, @AccGuid, @ShiftControlAccGUID;
	END

	CLOSE      AllShiftTickets;
	DEALLOCATE AllShiftTickets;

	INSERT INTO @ER
	SELECT NEWID()	  AS [GUID],
		   @EntryGUID AS EntryGUID,
		   @ShiftGuid AS ParentGUID,
		   @ParentType	AS ParentType,
		   S.Code	  AS ParentNumber
	FROM POSShift000 S
	WHERE S.[Guid]  = @ShiftGuid
	


	IF((SELECT COUNT(*) FROM @EN) > 0)
	BEGIN
	
		EXEC prcDisableTriggers 'ce000', 0
	    EXEC prcDisableTriggers 'en000', 0
	    EXEC prcDisableTriggers 'er000', 0
	
	
			INSERT INTO ce000 
			SELECT * FROM @CE
	
			INSERT INTO [en000] (
			[Number],			
			[Date],			
			[Debit],			
			[Credit],			
			[Notes],		
			[CurrencyVal],
			[GUID],		
			[ParentGUID],	
			[accountGUID],
			[CurrencyGUID],
			[ContraAccGUID]) 
			SELECT * FROM @EN
	
			INSERT INTO er000
			SELECT * FROM @ER
	
	
		EXEC prcEnableTriggers 'ce000'	
		EXEC prcEnableTriggers 'en000'
		EXEC prcEnableTriggers 'er000'
	
	END
	
	DECLARE @CheckGenerateEntry			   INT = (	SELECT COUNT(*) 
													FROM er000 ER
													INNER JOIN ce000 CE ON ER.EntryGUID = CE.[GUID]
													INNER JOIN en000 EN ON CE.[GUID] = EN.ParentGUID
													WHERE ER.ParentGUID = @ShiftGuid
													AND ER.ParentType = @ParentType	)
	
	DECLARE @CheckIfShiftHasFilteredTicket INT = ( SELECT COUNT(*)
												   FROM POSTicket000
												   WHERE [ShiftGuid] = @ShiftGuid
												   AND	[Type] = @TicketsType
												   AND	[State] = 0
												   AND	[LaterValue] != 0 )
	
	
	IF(@CheckGenerateEntry > 0 OR @CheckIfShiftHasFilteredTicket = 0)
	BEGIN
		SELECT 1 AS IsGenerated
	END
	ELSE
	BEGIN
		SELECT 0 AS IsGenerated
	END

################################################################################
CREATE PROCEDURE POSprcExternalOperationGenerateEntry
-- Params -------------------------------
	@ShiftGuid				UNIQUEIDENTIFIER
-----------------------------------------   
AS
    SET NOCOUNT ON
------------------------------------------------------------------------
DECLARE @EN  TABLE ([Number]			[INT] , 
					[Date]				[DATETIME], 
					[Debit]				[FLOAT], 
					[Credit]			[FLOAT], 
					[Notes]				[NVARCHAR](255) COLLATE ARABIC_CI_AI, 
					[CurrencyVal]		[FLOAT],
					[GUID]				[UNIQUEIDENTIFIER], 
					[ParentGUID]		[UNIQUEIDENTIFIER], 
					[accountGUID]		[UNIQUEIDENTIFIER], 
					[CurrencyGUID]		[UNIQUEIDENTIFIER], 
					[ContraAccGUID]		[UNIQUEIDENTIFIER]	 )
				   
DECLARE @CE TABLE (
	[Type] [INT] ,
	[Number] [INT],
	[Date] [datetime] ,
	[Debit] [float],
	[Credit] [FLOAT],
	[Notes] [NVARCHAR](1000) ,
	[CurrencyVal] [FLOAT],
	[IsPosted] [INT],
	[State] [INT],
	[Security] [INT],
	[Num1] [FLOAT],
	[Num2] [FLOAT],
	[Branch] [UNIQUEIDENTIFIER],
	[GUID] [UNIQUEIDENTIFIER],
	[CurrencyGUID] [UNIQUEIDENTIFIER],
	[TypeGUID] [UNIQUEIDENTIFIER],
	[IsPrinted] [BIT],
	[PostDate] [DATETIME]
	)
	
DECLARE  @ER TABLE(
	[GUID] [UNIQUEIDENTIFIER],
	[EntryGUID] [UNIQUEIDENTIFIER],
	[ParentGUID] [UNIQUEIDENTIFIER],
	[ParentType] [INT],
	[ParentNumber] [INT])
	
DECLARE @Number								INT = 0
DECLARE @EntryGUID							UNIQUEIDENTIFIER 
DECLARE @MaxCENumber						INT
DECLARE @Amount								FLOAT
DECLARE @Note								NVARCHAR(250)
DECLARE @DebitAccount						UNIQUEIDENTIFIER
DECLARE @CreditAccount						UNIQUEIDENTIFIER
DECLARE @CurrencyGUID						UNIQUEIDENTIFIER
DECLARE @CurrencyValue						FLOAT
DECLARE @DefCurrencyGUID					UNIQUEIDENTIFIER
DECLARE @EntryNote							NVARCHAR(1000)
DECLARE @language							INT
DECLARE @txt_EntryInShiftExternalOperation	NVARCHAR(250)
DECLARE @txt_ToPOS							NVARCHAR(250)
DECLARE @txt_ShiftEmployee					NVARCHAR(250)
DECLARE @txt_Shift							NVARCHAR(250)
DECLARE @ShiftControlAccount				UNIQUEIDENTIFIER

SET @EntryGUID						   = NEWID()
SET @MaxCENumber					   = ISNULL((SELECT MAX(Number) FROM ce000), 0) + 1
SET @DefCurrencyGUID				   = (SELECT TOP 1 [GUID] FROM my000 WHERE CurrencyVal = 1 ORDER BY [Number])
SET @language						   = [dbo].[fnConnections_getLanguage]() 
SET @txt_EntryInShiftExternalOperation = [dbo].[fnStrings_get]('POS\ENTRYINSHIFTEXTERNALOPERATIONS', @language)
SET @txt_ToPOS						   = [dbo].[fnStrings_get]('POS\TOPOSCARD', @language)
SET @txt_ShiftEmployee				   = [dbo].[fnStrings_get]('POS\SHIFTEMPLOYEE', @language) 
SET @txt_Shift						   = [dbo].[fnStrings_get]('POS\SHIFT', @language) 

SET @EntryNote	= ( SELECT @txt_EntryInShiftExternalOperation +  CAST(S.Code AS NVARCHAR(250)) + @txt_ToPOS + C.Name +'. '+ @txt_ShiftEmployee +': '+ E.Name
					FROM POSShift000 S
					LEFT JOIN POSCard000 C	   ON S.POSGuid	   = C.[Guid]
					LEFT JOIN POSEmployee000 E ON S.EmployeeId = E.[Guid]
					WHERE S.[Guid] =  @ShiftGuid )  

SELECT @ShiftControlAccount = ShiftControl 
FROM POSCard000 POSCard
INNER JOIN POSShift000 POSShift ON POSCard.[GUID] = POSShift.[POSGuid]
WHERE POSShift.[GUID] = @ShiftGuid
------------------------------------------------------------------------------------------------------------------

-- ce with default currecny
INSERT INTO @CE
SELECT 1																								   AS [Type],
	   @MaxCENumber					    																   AS Number,
	   GETDATE()																						   AS [Date],
	   (SELECT SUM(Amount) FROM POSExternalOperations000 WHERE [ShiftGuid] = @ShiftGuid AND [State] != 1)  AS Debit,
	   (SELECT SUM(Amount) FROM POSExternalOperations000 WHERE [ShiftGuid] = @ShiftGuid AND [State] != 1)  AS Credit,
	   @EntryNote																				           AS Notes,
	   1																						           AS  CurrencyVal,
	   1																						           AS IsPosted,
	   0																						           AS [State],
	   1																						           AS [Security],
	   0																						           AS Num1,
	   0																						           AS Num2,
	   0x0																						           AS Branch,
	   @EntryGUID																				           AS [GUID],
	   @DefCurrencyGUID																			           AS CurrencyGUID,
	   '00000000-0000-0000-0000-000000000000'													           AS TypeGUID,
	   0																						           AS IsPrinted,
	   GETDATE()																				           AS PostDate


DECLARE AllShiftExternalOperations  CURSOR FOR	
SELECT  
		EO.Amount,
		ISNULL(EO.Note, '') +  ' - ' + @txt_Shift + CAST(S.Code AS NVARCHAR(250)) + @txt_ToPOS + C.Name +'. '+ @txt_ShiftEmployee +': '+ E.Name,
		EO.DebitAccount AS DebitAccount,
		EO.CreditAccount AS  CreditAccount,
		EO.CurrencyGUID,
		EO.CurrencyValue
FROM POSExternalOperations000 EO
LEFT JOIN POSShift000 S    ON EO.ShiftGuid = S.[Guid]
LEFT JOIN POSCard000 C	   ON S.POSGuid	   = C.[Guid]
LEFT JOIN POSEmployee000 E ON S.EmployeeId = E.[Guid]
WHERE EO.ShiftGuid = @ShiftGuid
AND	  EO.[State]  != 1
OPEN AllShiftExternalOperations;
	
	FETCH NEXT FROM AllShiftExternalOperations INTO @Amount, @Note, @DebitAccount, @CreditAccount, @CurrencyGUID, @CurrencyValue;
	WHILE (@@FETCH_STATUS = 0)
	BEGIN  
		SET @Number = @Number + 1;

		DECLARE @DebitAmount FLOAT = @Amount * @CurrencyValue,
				@CreditAmount FLOAT = @Amount * @CurrencyValue,
				@DebitCurrencyGuid UNIQUEIDENTIFIER = @CurrencyGUID, 
				@DeditCurrencyValue FLOAT = @CurrencyValue,
				@CreditCurrencyGuid UNIQUEIDENTIFIER = @CurrencyGUID, 
				@CreditCurrencyValue FLOAT = @CurrencyValue

		IF(@DebitAccount = @ShiftControlAccount)
		BEGIN
			SET @DebitCurrencyGuid = @DefCurrencyGUID
			SET @DeditCurrencyValue = 1
		END

		IF(@CreditAccount = @ShiftControlAccount)
		BEGIN
			SET @CreditCurrencyGuid = @DefCurrencyGUID
			SET @CreditCurrencyValue = 1
		END


	   -- Debit line ---
	   INSERT INTO @EN
	   SELECT @Number AS Number,
			  GETDATE() AS [Date],
			  @DebitAmount AS Debit,
			  0 AS Credit,
			  @Note AS Note,
			  @DeditCurrencyValue AS CurrencyVal,
			  NEWID() AS [GUID],
			  @EntryGUID AS ParentGUID,
			  @DebitAccount AS accountGUID,
			  @DebitCurrencyGuid AS CurrencyGUID,
			  @CreditAccount AS ContraAccGUID

			  
	     SET @Number = @Number + 1;
	  
	  -- Credit line --
	   INSERT INTO @EN
	   SELECT @Number AS Number,
			  GETDATE() AS [Date],
			  0 AS Debit,
			  @CreditAmount AS Credit,
			  @Note AS Note,
			  @CreditCurrencyValue AS CurrencyVal,
			  NEWID() AS [GUID],
			  @EntryGUID AS ParentGUID,
			  @CreditAccount AS accountGUID,
			  @CreditCurrencyGuid AS CurrencyGUID,
			  @DebitAccount AS ContraAccGUID
			  
	   FETCH NEXT FROM AllShiftExternalOperations INTO @Amount, @Note, @DebitAccount, @CreditAccount, @CurrencyGUID, @CurrencyValue;
	END
	
	CLOSE      AllShiftExternalOperations;
	DEALLOCATE AllShiftExternalOperations;

INSERT INTO @ER
SELECT NEWID()	  AS [GUID],
	   @EntryGUID AS EntryGUID,
	   @ShiftGuid AS ParentGUID,
	   702		  AS ParentType,
	   S.Code	  AS ParentNumber
FROM POSShift000 S
	   WHERE S.[Guid]  = @ShiftGuid

DECLARE @ResultEntry INT
DECLARE @sqlCommand NVARCHAR(256), @sqlCommand2 NVARCHAR(256)
DECLARE @tableCe NVARCHAR(256)
DECLARE @tableEn NVARCHAR(256)
DECLARE @tableEr NVARCHAR(256)
DECLARE @Result INT  

SET @tableCe ='ce000'
SET @tableEn ='en000'
SET @tableEr ='er000'

SET @ResultEntry = 0 

IF((SELECT COUNT(*) FROM @EN) > 0)
BEGIN
   BEGIN TRANSACTION

		SET @sqlCommand =
		    'EXEC prcDisableTriggers '+@tableCe+', 0  
			 EXEC prcDisableTriggers '+@tableEn+', 0  
			 EXEC prcDisableTriggers '+@tableEr+', 0'
		 EXECUTE sp_executesql @sqlCommand 
				
				INSERT INTO ce000 
				SELECT * FROM @CE
		
				INSERT INTO [en000] (
				[Number],			
				[Date],			
				[Debit],			
				[Credit],			
				[Notes],		
				[CurrencyVal],
				[GUID],		
				[ParentGUID],	
				[accountGUID],
				[CurrencyGUID],
				[ContraAccGUID]) 
				SELECT * FROM @EN
		
				INSERT INTO er000
				SELECT * FROM @ER

		SET @sqlCommand2 = 
		    'EXEC prcEnableTriggers '+@tableCe+'   
			 EXEC prcEnableTriggers '+@tableEn+'    
			 EXEC prcEnableTriggers '+@tableEr+''
		 EXECUTE sp_executesql @sqlCommand2 
   COMMIT
END


DECLARE @CheckGenerateEntry							 INT = (  SELECT COUNT(*) 
															  FROM er000 ER
															  INNER JOIN ce000 CE ON ER.EntryGUID = CE.[GUID]
															  INNER JOIN en000 EN ON CE.[GUID] = EN.ParentGUID
															  WHERE ER.ParentGUID = @ShiftGuid
															  AND ER.ParentType = 702 )

DECLARE @CheckIfShiftHasNotCanceledExternalOperations INT = ( SELECT COUNT(*)
															  FROM POSExternalOperations000
															  WHERE ShiftGuid  = @ShiftGuid
															  AND	  [State]  != 1 )


IF(@CheckGenerateEntry > 0 OR @CheckIfShiftHasNotCanceledExternalOperations = 0)
BEGIN
	 SET @Result =1
END
ELSE
BEGIN
	 SET @Result =0
END
SELECT @Result	 AS Result  
################################################################################
CREATE PROCEDURE prcPOSSD_Shift_BankCardsGenEntry
-- Params -------------------------------
	@ShiftGuid				UNIQUEIDENTIFIER
-----------------------------------------   
AS
    SET NOCOUNT ON
------------------------------------------------------------------------
	DECLARE @EN TABLE( [Number]			INT , 
					   [Date]			DATETIME,
					   [Debit]			FLOAT, 
					   [Credit]			FLOAT, 
					   [Notes]			NVARCHAR(255), 
					   [CurrencyVal]	FLOAT,
					   [GUID]			UNIQUEIDENTIFIER, 
					   [ParentGUID]		UNIQUEIDENTIFIER, 
					   [accountGUID]	UNIQUEIDENTIFIER, 
					   [CurrencyGUID]	UNIQUEIDENTIFIER,
					   [CostGUID]		UNIQUEIDENTIFIER,
					   [ContraAccGUID]  UNIQUEIDENTIFIER )
			   
	DECLARE @CE TABLE( [Type]		    INT,
					   [Number]		    INT,
					   [Date]		    DATETIME,
					   [Debit]		    FLOAT,
					   [Credit]		    FLOAT,
					   [Notes]		    NVARCHAR(1000) ,
					   [CurrencyVal]    FLOAT,
					   [IsPosted]	    INT,
					   [State]		    INT,
					   [Security]	    INT,
					   [Num1]		    FLOAT,
					   [Num2]	        FLOAT,
					   [Branch]		    UNIQUEIDENTIFIER,
					   [GUID]		    UNIQUEIDENTIFIER,
					   [CurrencyGUID]   UNIQUEIDENTIFIER,
					   [TypeGUID]		UNIQUEIDENTIFIER,
					   [IsPrinted]	    BIT,
					   [PostDate]		DATETIME )

	DECLARE @ER TABLE( [GUID]		    UNIQUEIDENTIFIER,
					   [EntryGUID]	    UNIQUEIDENTIFIER,
					   [ParentGUID]	    UNIQUEIDENTIFIER,
					   [ParentType]	    INT,
					   [ParentNumber]   INT )

	DECLARE @ENNumber			        INT = 0
	DECLARE @ENValue		            FLOAT
	DECLARE @ENNote			            NVARCHAR(250)
	DECLARE @AccGuid		            UNIQUEIDENTIFIER
	DECLARE @ShiftControlAccGUID        UNIQUEIDENTIFIER
	DECLARE @DefCurrencyGUID			UNIQUEIDENTIFIER 
	DECLARE @EntryGUID					UNIQUEIDENTIFIER 
	DECLARE @BranchGuid				    UNIQUEIDENTIFIER
	DECLARE @CostGUID				    UNIQUEIDENTIFIER
	DECLARE @NewCENumber				INT
	DECLARE @EntryNote					NVARCHAR(1000)


	DECLARE @language			INT
	DECLARE @txt_BankSaleEntry	NVARCHAR(250)
	DECLARE @txt_POSShift		NVARCHAR(250)
	DECLARE @txt_POSEmployee	NVARCHAR(250)
	DECLARE @txt_BankCard		NVARCHAR(250)
	DECLARE @txt_SalesType		NVARCHAR(250)
	SET @language = [dbo].[fnConnections_getLanguage]() 
	SET @txt_BankSaleEntry = [dbo].[fnStrings_get]('POSSD\BANK_SALE_ENTRY',     @language) 
	SET @txt_POSShift	   = [dbo].[fnStrings_get]('POSSD\BANK_ENTRY_SHIFT',    @language)
	SET @txt_POSEmployee   = [dbo].[fnStrings_get]('POSSD\BANK_ENTRY_EMPLOYEE', @language) 
	SET @txt_BankCard	   = [dbo].[fnStrings_get]('POSSD\BANK_CARD',           @language) 
	SET @txt_SalesType	   = [dbo].[fnStrings_get]('POSSD\SALES_TYPE',          @language) 


	 SET @EntryNote = ( SELECT @txt_BankSaleEntry + CAST(C.Code AS NVARCHAR(250)) + @txt_POSShift + CAST(S.Code AS NVARCHAR(250)) + @txt_POSEmployee + 
												CASE @language WHEN 0 THEN E.Name ELSE CASE E.LatinName WHEN '' THEN E.Name ELSE E.LatinName END END  
						FROM POSShift000 S
						LEFT JOIN POSCard000 C ON S.POSGuid = C.[Guid]
						LEFT JOIN POSEmployee000 E ON S.EmployeeId = E.[Guid]
						WHERE S.[Guid] =  @ShiftGuid )
	
	 SET @BranchGuid      = (SELECT TOP 1 [GUID] FROM br000 ORDER BY Number)
	 SET @NewCENumber     = (SELECT ISNULL(MAX(Number), 0) + 1 FROM ce000  WHERE Branch = ISNULL(@BranchGuid, 0x0))
	 SET @DefCurrencyGUID = (SELECT TOP 1 [GUID] FROM my000 WHERE CurrencyVal = 1 ORDER BY [Number])
	 SET @EntryGUID       = NEWID()
	 SET @CostGUID        = 0x0

	INSERT INTO @CE
	SELECT 1																					 AS [Type],
		   @NewCENumber					    													 AS Number,
		   GETDATE()																			 AS [Date],

		   (SELECT SUM(TB.Value) 
			FROM POSTicket000 T INNER JOIN POSSDTicketBank000 TB ON T.[Guid] = TB.TicketGUID 
			WHERE T.ShiftGuid = @ShiftGuid AND T.[State]  = 0 )						             AS Debit,

		   (SELECT SUM(TB.Value) 
			FROM POSTicket000 T INNER JOIN POSSDTicketBank000 TB ON T.[Guid] = TB.TicketGUID 
			WHERE T.ShiftGuid = @ShiftGuid AND T.[State]  = 0 )									 AS Credit,

		   @EntryNote																			 AS Notes,
		   1																					 AS  CurrencyVal,
		   0																					 AS IsPosted,
		   0																					 AS [State],
		   1																					 AS [Security],
		   0																					 AS Num1,
		   0																					 AS Num2,
		   ISNULL(@BranchGuid, 0x0)																 AS Branch,
		   @EntryGUID																			 AS [GUID],
		   @DefCurrencyGUID																		 AS CurrencyGUID,
		   0x0																					 AS TypeGUID,
		   0																					 AS IsPrinted,
		   GETDATE()																			 AS PostDate



	DECLARE @AllShiftTicketsPayByBankCards CURSOR 
	SET @AllShiftTicketsPayByBankCards = CURSOR FAST_FORWARD FOR
	SELECT  TB.Value,
			@txt_BankCard + 
			CASE @language WHEN 0 THEN B.Name ELSE CASE B.LatinName WHEN '' THEN B.Name ELSE B.LatinName END END + 
			@txt_POSShift + CAST(S.Code AS NVARCHAR(250)) + @txt_SalesType + CAST(T.Number AS NVARCHAR(250)) +
			@txt_POSEmployee + CASE @language WHEN 0 THEN E.Name ELSE CASE E.LatinName WHEN '' THEN E.Name ELSE E.LatinName END END,
			B.ReceiveAccGUID AS accountGUID,
			C.ShiftControl   AS ShiftControlAccGUID
	FROM POSTicket000 T
	INNER JOIN POSSDTicketBank000 TB ON T.[Guid]	   = TB.TicketGUID
	LEFT JOIN  POSShift000        S  ON T.ShiftGuid    = S.[Guid]
	LEFT JOIN  POSCard000         C  ON S.POSGuid      = C.[Guid]
	LEFT JOIN  vwCuAc	          AC ON T.CustomerGuid = AC.cuGUID
	LEFT JOIN  POSEmployee000     E  ON S.EmployeeId   = E.[Guid]
	LEFT JOIN  BankCard000        B  ON TB.BankGUID	   = B.[GUID]
	WHERE T.ShiftGuid = @ShiftGuid
	AND	  T.[State]  = 0
	OPEN @AllShiftTicketsPayByBankCards;	

		FETCH NEXT FROM @AllShiftTicketsPayByBankCards INTO @ENValue, @ENNote, @AccGuid, @ShiftControlAccGUID;
		WHILE (@@FETCH_STATUS = 0)
		BEGIN  
			SET @ENNumber = @ENNumber + 1;

		   INSERT INTO @EN
		   SELECT @ENNumber				AS Number,
				  GETDATE()				AS [Date],
				  @ENValue				AS Debit,
				  0						AS Credit,
				  @ENNote				AS Note,
				  1						AS CurrencyVal,
				  NEWID()				AS [GUID],
				  @EntryGUID			AS ParentGUID,
				  @AccGuid				AS accountGUID,
				  @DefCurrencyGUID		AS CurrencyGUID,
				  @CostGUID				AS CostGUID,
				  @ShiftControlAccGUID	AS ContraAccGUID
		

			 SET @ENNumber = @ENNumber + 1;

		   INSERT INTO @EN
		   SELECT @ENNumber				AS Number,
				  GETDATE()				AS [Date],
				  0						AS Debit,
				  @ENValue				AS Credit,
				  @ENNote				AS Note,
				  1						AS CurrencyVal,
				  NEWID()				AS [GUID],
				  @EntryGUID			AS ParentGUID,
				  @ShiftControlAccGUID	AS accountGUID,
				  @DefCurrencyGUID		AS CurrencyGUID,
				  @CostGUID				AS CostGUID,
				  @AccGuid				AS ContraAccGUID

		FETCH NEXT FROM @AllShiftTicketsPayByBankCards INTO @ENValue, @ENNote, @AccGuid, @ShiftControlAccGUID;
		END

		CLOSE      @AllShiftTicketsPayByBankCards;
		DEALLOCATE @AllShiftTicketsPayByBankCards;

	INSERT INTO @ER
	SELECT NEWID()	  AS [GUID],
		   @EntryGUID AS EntryGUID,
		   @ShiftGuid AS ParentGUID,
		   703		  AS ParentType,
		   S.Code	  AS ParentNumber
	 FROM POSShift000 S
	 WHERE S.[Guid]  = @ShiftGuid

	------------- FINAL ENSERT -------------

	IF((SELECT COUNT(*) FROM @EN) > 0)
	BEGIN

			INSERT INTO ce000 ( [Type],
							    [Number],
							    [Date],
							    [Debit],
							    [Credit],
							    [Notes],
							    [CurrencyVal],
							    [IsPosted],
							    [State],
							    [Security],
							    [Num1],
							    [Num2],
							    [Branch],
							    [GUID],
							    [CurrencyGUID],
							    [TypeGUID],
							    [IsPrinted],
							    [PostDate] ) SELECT * FROM @CE

			INSERT INTO en000 ( [Number],			
								[Date],
								[Debit],
								[Credit],			
								[Notes],		
								[CurrencyVal],
								[GUID],		
								[ParentGUID],	
								[accountGUID],
								[CurrencyGUID],
								[CostGUID],
								[ContraAccGUID] ) SELECT * FROM @EN

			INSERT INTO er000 ( [GUID],
							    [EntryGUID],
							    [ParentGUID],
							    [ParentType],
							    [ParentNumber] ) SELECT * FROM @ER


			EXEC prcConnections_SetIgnoreWarnings 1
			UPDATE ce000 SET [IsPosted] = 1 WHERE [GUID] = @EntryGUID
			EXEC prcConnections_SetIgnoreWarnings 0
	END

	DECLARE @CheckGenerateEntry INT = (	SELECT COUNT(*) 
										FROM er000 ER
										INNER JOIN ce000 CE ON ER.EntryGUID = CE.[GUID]
										INNER JOIN en000 EN ON CE.[GUID]    = EN.ParentGUID
										WHERE ER.ParentGUID = @ShiftGuid
										AND ER.ParentType = 703	)

	DECLARE @HasBankCardTickets INT = ( SELECT COUNT(*)
										FROM POSTicket000 T
										INNER JOIN POSSDTicketBank000 TB ON T.[Guid] = TB.TicketGUID
										WHERE T.ShiftGuid = @ShiftGuid AND T.[State] = 0)
	IF( @CheckGenerateEntry > 0 OR @HasBankCardTickets = 0 )
	BEGIN
		SELECT 1 AS IsGenerated
	END
	ELSE
	BEGIN
		SELECT 0 AS IsGenerated
	END
################################################################################
CREATE FUNCTION fnPOSAccountIsUsedInOperationsAccounts
(
	   @CurrentPOS		          UNIQUEIDENTIFIER,
       @AccountToBeVerified		  UNIQUEIDENTIFIER,

	   @CentralAccOfTheCurrentPOS UNIQUEIDENTIFIER,
	   @DebitAccOfTheCurrentPOS   UNIQUEIDENTIFIER,
	   @CreditAccOfTheCurrentPOS  UNIQUEIDENTIFIER,
	   @ExpenseAccOfTheCurrentPOS UNIQUEIDENTIFIER,
	   @IncomeAccOfTheCurrentPOS  UNIQUEIDENTIFIER
)
RETURNS BIT
AS
BEGIN
       
	DECLARE @CentralAcc UNIQUEIDENTIFIER
	DECLARE @DebitAcc   UNIQUEIDENTIFIER
	DECLARE @CreditAcc  UNIQUEIDENTIFIER
	DECLARE @ExpenseAcc UNIQUEIDENTIFIER
	DECLARE @IncomeAcc  UNIQUEIDENTIFIER

	DECLARE AllPOSOperationsAccounts  CURSOR FOR	
	SELECT  CentralAccGUID,
			DebitAccGUID,
			CreditAccGUID,
			ExpenseAccGUID,
			IncomeAccGUID
	FROM POSCard000
	WHERE [GUID] != @CurrentPOS
	UNION ALL
	SELECT @CentralAccOfTheCurrentPOS,
		   @DebitAccOfTheCurrentPOS,
		   @CreditAccOfTheCurrentPOS,
		   @ExpenseAccOfTheCurrentPOS,
		   @IncomeAccOfTheCurrentPOS 

	OPEN AllPOSOperationsAccounts;	

	FETCH NEXT FROM AllPOSOperationsAccounts INTO @CentralAcc, @DebitAcc, @CreditAcc, @ExpenseAcc, @IncomeAcc;
	WHILE (@@FETCH_STATUS = 0)
	BEGIN  
	
	IF((@CentralAcc != 0x0) AND (@AccountToBeVerified IN (SELECT [GUID] FROM [dbo].[fnGetAccountsList](@CentralAcc, 1))))
		RETURN 1

	IF((@DebitAcc   != 0x0) AND (@AccountToBeVerified IN (SELECT [GUID] FROM [dbo].[fnGetAccountsList](@DebitAcc, 1))))
		RETURN 1

	IF((@CreditAcc  != 0x0) AND (@AccountToBeVerified IN (SELECT [GUID] FROM [dbo].[fnGetAccountsList](@CreditAcc, 1))))
		RETURN 1

	IF((@ExpenseAcc != 0x0) AND (@AccountToBeVerified IN (SELECT [GUID] FROM [dbo].[fnGetAccountsList](@ExpenseAcc, 1))))
		RETURN 1 

	IF((@IncomeAcc  != 0x0) AND (@AccountToBeVerified IN (SELECT [GUID] FROM [dbo].[fnGetAccountsList](@IncomeAcc, 1))))
		RETURN 1

	FETCH NEXT FROM AllPOSOperationsAccounts INTO @CentralAcc, @DebitAcc, @CreditAcc, @ExpenseAcc, @IncomeAcc;
	END

	CLOSE      AllPOSOperationsAccounts;
	DEALLOCATE AllPOSOperationsAccounts;

	RETURN 0

END
################################################################################
CREATE FUNCTION fnCheckIfAccUsedInPOSSmartDeviceOptions()
RETURNS @SmartDevicesOptionsAccountsList TABLE 
(
		[GUID]	UNIQUEIDENTIFIER
)
AS 
BEGIN
       
	DECLARE @CentralAccGUID UNIQUEIDENTIFIER
	DECLARE @DebitAccGUID   UNIQUEIDENTIFIER
	DECLARE @CreditAccGUID  UNIQUEIDENTIFIER
	DECLARE @ExpenseAccGUID UNIQUEIDENTIFIER
	DECLARE @IncomeAccGUID  UNIQUEIDENTIFIER

	DECLARE AllPOSOperationsAccounts  CURSOR FOR	
	SELECT  CentralAccGUID,
			DebitAccGUID,
			CreditAccGUID,
			ExpenseAccGUID,
			IncomeAccGUID
	FROM POSCard000 
	OPEN AllPOSOperationsAccounts;	

	FETCH NEXT FROM AllPOSOperationsAccounts INTO @CentralAccGUID, @DebitAccGUID, @CreditAccGUID, @ExpenseAccGUID, @IncomeAccGUID;
	WHILE (@@FETCH_STATUS = 0)
	BEGIN  
	
	IF(@CentralAccGUID != 0x0)
		INSERT INTO  @SmartDevicesOptionsAccountsList ([GUID]) (SELECT [GUID] 
															    FROM dbo.fnGetAccountsList(@CentralAccGUID, 0) 
																WHERE [GUID] NOT IN (SELECT [Guid] FROM @SmartDevicesOptionsAccountsList))

	IF(@DebitAccGUID   != 0x0)
		INSERT INTO  @SmartDevicesOptionsAccountsList ([GUID]) (SELECT [GUID] 
																FROM dbo.fnGetAccountsList(@DebitAccGUID  , 0) 
																WHERE [GUID] NOT IN (SELECT [Guid] FROM @SmartDevicesOptionsAccountsList))

	IF(@CreditAccGUID  != 0x0)
		INSERT INTO  @SmartDevicesOptionsAccountsList ([GUID]) (SELECT [GUID] 
																FROM dbo.fnGetAccountsList(@CreditAccGUID , 0) 
																WHERE [GUID] NOT IN (SELECT [Guid] FROM @SmartDevicesOptionsAccountsList))

	IF(@ExpenseAccGUID != 0x0)
		INSERT INTO  @SmartDevicesOptionsAccountsList ([GUID]) (SELECT [GUID] 
																FROM dbo.fnGetAccountsList(@ExpenseAccGUID, 0) 
																WHERE [GUID] NOT IN (SELECT [Guid] FROM @SmartDevicesOptionsAccountsList))

	IF(@IncomeAccGUID  != 0x0)
		INSERT INTO  @SmartDevicesOptionsAccountsList ([GUID]) (SELECT [GUID] 
																FROM dbo.fnGetAccountsList(@IncomeAccGUID , 0) 
																WHERE [GUID] NOT IN (SELECT [Guid] FROM @SmartDevicesOptionsAccountsList))

	FETCH NEXT FROM AllPOSOperationsAccounts INTO  @CentralAccGUID, @DebitAccGUID, @CreditAccGUID, @ExpenseAccGUID, @IncomeAccGUID;
	END

	CLOSE      AllPOSOperationsAccounts;
	DEALLOCATE AllPOSOperationsAccounts;

	RETURN

END
################################################################################
CREATE PROCEDURE prcPOSSDGetRelatedSaleMaterials
-- Param -------------------------------   
	   @POSSDGuid UNIQUEIDENTIFIER,
	   @SaleType  INT
-----------------------------------------   
AS
    SET NOCOUNT ON
------------------------------------------------------------------------

--DECLARE @Tbl TABLE ([Guid]		  UNIQUEIDENTIFIER PRIMARY KEY,
--					 Number       INT,
--					 ParentGuid   UNIQUEIDENTIFIER,
--					 MaterialGuid UNIQUEIDENTIFIER)
-- SELECT * FROM @Tbl

 CREATE TABLE #POSSDMatGroup (GroupGuid UNIQUEIDENTIFIER)


 INSERT INTO #POSSDMatGroup 
		SELECT GroupGuid 
		FROM POSRelatedGroups000 
		WHERE POSGuid = @POSSDGuid

 INSERT INTO #POSSDMatGroup 
   		SELECT DISTINCT  fn.[GUID] FROM POSRelatedGroups000 RG 
		CROSS APPLY (SELECT f.[GUID] FROM [dbo].[fnGetGroupParents](RG.GroupGuid) f) fn
		WHERE fn.[GUID] <> 0x0
		AND RG.POSGuid = @POSSDGuid

	
------------------- RESULT

  SELECT RSM.[GUID]         AS [Guid], 
  	     RSM.Number         AS Number, 
  	     ME.MaterialGUID    AS ParentGuid, 
  	     RSM.MaterialGUID   AS MaterialGuid 
  FROM POSSDRelatedSaleMaterial000 RSM
  INNER JOIN POSSDMaterialExtended000 ME ON RSM.ParentGUID	   = ME.[GUID]
  INNER JOIN mt000 MT					 ON RSM.MaterialGUID   = MT.[GUID]
  INNER JOIN #POSSDMatGroup POSGroup	 ON POSGroup.GroupGuid = MT.GroupGUID
  WHERE ME.[Type] = @SaleType
################################################################################
CREATE FUNCTION fnPOSSDOperationsAccountIsUsedInSinglePOS
-- Param ----------------------------------------------------------
	  ( @ShiftControlAccToBeVerified   UNIQUEIDENTIFIER,
		@ContinuesCashAccToBeVerified  UNIQUEIDENTIFIER,

		@CentralAccOfTheCurrentPOS     UNIQUEIDENTIFIER,
	    @DebitAccOfTheCurrentPOS       UNIQUEIDENTIFIER,
	    @CreditAccOfTheCurrentPOS      UNIQUEIDENTIFIER,
	    @ExpenseAccOfTheCurrentPOS     UNIQUEIDENTIFIER,
	    @IncomeAccOfTheCurrentPOS      UNIQUEIDENTIFIER  )
-- Return ----------------------------------------------------------
RETURNS @Result TABLE(AccName NVARCHAR(50), AccGuid UNIQUEIDENTIFIER)
--------------------------------------------------------------------
AS 
BEGIN

	DECLARE @AccountTemp TABLE(OperationsAcc UNIQUEIDENTIFIER, AccGuid UNIQUEIDENTIFIER)

	IF(@CentralAccOfTheCurrentPOS <> 0x0) INSERT INTO @AccountTemp SELECT @CentralAccOfTheCurrentPOS, fn.[GUID] FROM [dbo].[fnGetAccountsList](@CentralAccOfTheCurrentPOS, 1) fn
	IF(@DebitAccOfTheCurrentPOS   <> 0x0) INSERT INTO @AccountTemp SELECT @DebitAccOfTheCurrentPOS,   fn.[GUID] FROM [dbo].[fnGetAccountsList](@DebitAccOfTheCurrentPOS,   1) fn
	IF(@CreditAccOfTheCurrentPOS  <> 0x0) INSERT INTO @AccountTemp SELECT @CreditAccOfTheCurrentPOS,  fn.[GUID] FROM [dbo].[fnGetAccountsList](@CreditAccOfTheCurrentPOS,  1) fn
	IF(@ExpenseAccOfTheCurrentPOS <> 0x0) INSERT INTO @AccountTemp SELECT @ExpenseAccOfTheCurrentPOS, fn.[GUID] FROM [dbo].[fnGetAccountsList](@ExpenseAccOfTheCurrentPOS, 1) fn
	IF(@IncomeAccOfTheCurrentPOS  <> 0x0) INSERT INTO @AccountTemp SELECT @IncomeAccOfTheCurrentPOS,  fn.[GUID] FROM [dbo].[fnGetAccountsList](@IncomeAccOfTheCurrentPOS,  1) fn

	IF EXISTS(SELECT * FROM @AccountTemp WHERE AccGuid = @ShiftControlAccToBeVerified)
	BEGIN
		INSERT INTO @Result SELECT '"' + ac.Code +' - '+ ac.Name + '"', at.OperationsAcc from ac000 ac INNER JOIN @AccountTemp at ON ac.[GUID] = at.OperationsAcc WHERE at.AccGuid = @ShiftControlAccToBeVerified
	END

	IF EXISTS(SELECT * FROM @AccountTemp WHERE AccGuid = @ContinuesCashAccToBeVerified)
	BEGIN
		INSERT INTO @Result SELECT '"' + ac.Code +' - '+ ac.Name + '"', at.OperationsAcc from ac000 ac INNER JOIN @AccountTemp at ON ac.[GUID] = at.OperationsAcc WHERE at.AccGuid = @ContinuesCashAccToBeVerified
	END

RETURN
END
################################################################################
CREATE FUNCTION fnPOSSDOperationsAccountIsUsedInAllPOS
-- Param ----------------------------------------------------------
	  ( @CurrentPOS					 UNIQUEIDENTIFIER,
	    @CurrentPOSShiftControlAcc   UNIQUEIDENTIFIER,
		@CurrentPOSContinuesCashAcc  UNIQUEIDENTIFIER,

		@CentralAcc     UNIQUEIDENTIFIER,
	    @DebitAcc       UNIQUEIDENTIFIER,
	    @CreditAcc      UNIQUEIDENTIFIER,
	    @ExpenseAcc     UNIQUEIDENTIFIER,
	    @IncomeAcc      UNIQUEIDENTIFIER  )
-- Return ----------------------------------------------------------
RETURNS @Result TABLE(AccName NVARCHAR(50), AccGuid UNIQUEIDENTIFIER)
--------------------------------------------------------------------
AS 
BEGIN

	DECLARE @TempPOSCard TABLE (ShiftControlAcc   UNIQUEIDENTIFIER, ContinuesCashAcc  UNIQUEIDENTIFIER)
	INSERT INTO @TempPOSCard SELECT ShiftControl, ContinuesCash FROM POSCard000 WHERE [Guid] <> @CurrentPOS
	INSERT INTO @TempPOSCard SELECT @CurrentPOSShiftControlAcc, @CurrentPOSContinuesCashAcc

	INSERT INTO @Result
	SELECT TOP 1 fn.* 
	FROM @TempPOSCard POSCard 
	CROSS APPLY dbo.[fnPOSSDOperationsAccountIsUsedInSinglePOS](POSCard.ShiftControlAcc, 
																POSCard.ContinuesCashAcc, 
																@CentralAcc, 
																@DebitAcc, 
																@CreditAcc, 
																@ExpenseAcc, 
																@IncomeAcc) fn


RETURN
END
################################################################################
CREATE PROCEDURE prcPOSSDGroupMatIsUsedInPOSSmartDevices
-- Param -------------------------------   
	@GroupToBeVerified				UNIQUEIDENTIFIER
-----------------------------------------   
AS
    SET NOCOUNT ON
------------------------------------------------------------------------
	DECLARE @GroupTemp TABLE (GroupGuid UNIQUEIDENTIFIER)


	INSERT INTO @GroupTemp SELECT @GroupToBeVerified;
	INSERT INTO @GroupTemp SELECT [GUID] FROM [dbo].[fnGetGroupParents](@GroupToBeVerified) WHERE [GUID] <> 0x0;
	INSERT INTO @GroupTemp SELECT GroupGuid FROM gri000 WHERE MatGuid = @GroupToBeVerified;

	IF((SELECT COUNT(GT.GroupGuid) FROM @GroupTemp GT INNER JOIN POSRelatedGroups000 RP ON GT.GroupGuid = RP.GroupGuid) > 0)
		SELECT 1 AS IsUsed;
	ELSE 
		SELECT 0 AS IsUsed;
################################################################################
CREATE FUNCTION fnBillTypeIsUsedInPOSSmartDevices (@BillType UNIQUEIDENTIFIER)
RETURNS TABLE
AS
RETURN	(
			SELECT S.POSGuid
			FROM POSCard000 C
			INNER JOIN POSShift000 S ON C.[Guid] = S.POSGuid
			WHERE SaleBillType = @BillType
		)
################################################################################
CREATE FUNCTION fnCustomerHasAnOpenTicketInPOSSmartDevices (@CustomerGuid UNIQUEIDENTIFIER)
RETURNS TABLE
AS 
RETURN	(
			SELECT TOP 1 C.Name AS POSName
			FROM POSTicket000 T
			INNER JOIN POSShift000 S ON T.ShiftGuid  = S.[Guid]
			INNER JOIN POSCard000  C ON S.POSGuid	= C.[Guid]
			WHERE T.CustomerGuid = @CustomerGuid
			AND   S.CloseDate IS NULL
		)
################################################################################
CREATE PROCEDURE prcPOSControlAccountOutsideMoves
-- Params -------------------------------   
	@POSGuid				UNIQUEIDENTIFIER,
	@POSAccount				UNIQUEIDENTIFIER,
	@StartDate				DATETIME,
	@EndDate				DATETIME
-----------------------------------------   
AS
    SET NOCOUNT ON
------------------------------------------------------------------------
DECLARE @EntryGeneratedFromPOSSalesReturnTicket  INT = 704
DECLARE @EntryGeneratedFromPOSBankCardTicket     INT = 703
DECLARE @EntryGeneratedFromPOSExternalOperations INT = 702
DECLARE @EntryGeneratedFromPOSTicket			 INT = 701

SELECT BRel.BillGUID AS BillGUID
INTO #BillGeneratedFromPOS
FROM POSShift000 S
INNER JOIN BillRel000 BRel ON S.[GUID] = BRel.ParentGUID
WHERE POSGuid = @POSGuid


 DECLARE @Lang	INT
 EXEC @Lang = [dbo].fnConnections_GetLanguage;

 SELECT 
	
 	EN.[Date]									AS EnDate,
 	Ce.Number									AS CeNumber,
 	Ce.[GUID]									AS CeGuid,
	EN.[GUID]									AS EnGuid,
	BU.[GUID]									AS BuGuid,
	CH.[GUID]									AS ChGuid,
 	EN.Notes									AS EnNotes,
 	EN.AccountGUID								AS AccountGuid,
 	EN.Debit									AS Debit,
 	EN.Credit									AS Credit,
 	((EN.Debit - EN.Credit) / EN.CurrencyVal)	AS MoveBalance ,
 	(CASE ER.ParentType WHEN 2 THEN CASE @Lang WHEN 0 THEN BT.Abbrev ELSE CASE BT.LatinAbbrev WHEN '' THEN BT.Abbrev ELSE BT.LatinAbbrev END END 
 					    WHEN 5 THEN CASE @Lang WHEN 0 THEN NT.Abbrev ELSE CASE NT.LatinAbbrev WHEN '' THEN NT.Abbrev ELSE NT.LatinAbbrev END END + ': ' + CH.Num 
 					    WHEN 4 THEN CASE @Lang WHEN 0 THEN ET.Abbrev ELSE CASE ET.LatinAbbrev WHEN '' THEN ET.Abbrev ELSE ET.LatinAbbrev END END
 					    ELSE '' END ) + ': ' + CAST(ER.ParentNumber AS nvarchar(100)) AS Name,
 
 	EN.CurrencyVal								AS EnCurrencyVal,
 	MY.Code										AS EnCurrencyCode,
 	ISNULL(ER.ParentType, 1)					AS CeParentType,
 	BT.BillType									AS BillType,
 	ER.ParentGUID								AS ParentGuid,
 	ER.ParentNumber								AS ParentNumber,
 	CE.TypeGUID									AS CeTypeGuid

 FROM 
 	ce000  CE 			 
 	INNER JOIN en000 EN	 ON CE.[GUID]	 = EN.ParentGuid
 	LEFT  JOIN ac000 AC  ON AC.[GUID]	 = EN.AccountGUID
 	LEFT  JOIN et000 ET	 ON CE.TypeGUID	 = ET.[GUID]
 	LEFT  JOIN er000 ER	 ON ER.EntryGUID = CE.[GUID]
 	LEFT  JOIN bu000 BU	 ON BU.[GUID]	 = ER.ParentGUID
 	LEFT  JOIN bt000 BT  ON BT.[GUID]	 = BU.TypeGUID
 	LEFT  JOIN my000 MY  ON MY.[GUID]	 = EN.CurrencyGUID
 	LEFT  JOIN ch000 CH  ON CH.[GUID]	 = ER.ParentGUID
 	LEFT  JOIN nt000 NT  ON NT.[GUID]	 = CH.TypeGUID
 
 WHERE EN.AccountGuid = @POSAccount
 AND   ER.ParentType NOT IN 
	(@EntryGeneratedFromPOSExternalOperations, @EntryGeneratedFromPOSTicket, @EntryGeneratedFromPOSBankCardTicket, @EntryGeneratedFromPOSSalesReturnTicket)
 AND   ISNULL(BU.[GUID], 0x0) NOT IN (SELECT BillGUID FROM #BillGeneratedFromPOS)
 AND   EN.[Date] BETWEEN @StartDate AND @EndDate
 
 ORDER BY EN.[Date] ,Ce.[Number] 
################################################################################
CREATE PROCEDURE GetPosRelatedCustomers
	@posGuid UNIQUEIDENTIFIER
AS
BEGIN
	DECLARE @debitAccountGuid uniqueidentifierprcPOSSDGroupMatIsUsedInPOSSmartDevices
	SELECT @debitAccountGuid=DebitAccGUID FROM POSCard000 WHERE Guid = @posGuid
	
	if(@debitAccountGuid = 0x00 OR @debitAccountGuid = NULL)
		return;
	SELECT DISTINCT customers.GUID, CAST(customers.Number AS INT) Number , 
	customers.CustomerName, 
	customers.LatinName, 
	customers.AccountGUID,
	customers.NSEMail1 AS EMail, 
	customers.NSMobile1 AS Phone1, 
	customers.NSMobile2 AS Phone2
	FROM dbo.fnGetAccountsList(@debitAccountGuid, 0) accountList
	INNER JOIN cu000 customers
	ON customers.AccountGUID = accountList.GUID			
END
################################################################################
CREATE View PosExternalOperationsView
AS
SELECT EO.*, 
	CAC.Name AS CreditAccountName,
	CAC.LatinName AS CreditAccountLatinName,
	DAC.Name AS DebitAccountName,
	DAC.LatinName AS DebitAccountLatinName   
FROM 

[dbo].[PosExternalOperations000] EO
INNER JOIN ac000 CAC ON EO.CreditAccount = CAC.GUID
INNER JOIN ac000 DAC ON EO.DebitAccount = DAC.GUID

################################################################################
CREATE PROCEDURE prcRelatedToPOSSDShift
-- Param -------------------------------   
	   @CurrentBill UNIQUEIDENTIFIER
-----------------------------------------   
AS
    SET NOCOUNT ON
------------------------------------------------------------------------

SELECT BR.[GUID] FROM BillRel000 BR 
INNER JOIN POSShift000 POSShift ON BR.ParentGUID = POSShift.[Guid]
WHERE BR.BillGUID = @CurrentBill
################################################################################
CREATE PROCEDURE prcPOSGenerateBillForTickets
	@billTypeID [UNIQUEIDENTIFIER],
	@shiftGuid [UNIQUEIDENTIFIER],
	@TicketsType INT = 0, -- 0: Sales, 1: Purchases, 2: ReturnedSales, 3: Returned Purchases 
	@returnValue INT = 1 OUTPUT
AS
BEGIN 
DECLARE @storeGuid [UNIQUEIDENTIFIER],
		@shiftCode [INT],
		@userGuid  [UNIQUEIDENTIFIER],
		@posName [NVARCHAR](250),
		@shiftControl [UNIQUEIDENTIFIER],
		@billID [UNIQUEIDENTIFIER],
		@billNumber INT,
		@language [INT] = [dbo].[fnConnections_getLanguage](), 
		@CurrencyValue [FLOAT],
		@CurrencyID [UNIQUEIDENTIFIER],
		@billAccountID [UNIQUEIDENTIFIER],
		@discountAccountID [UNIQUEIDENTIFIER],
		@extraAccountID [UNIQUEIDENTIFIER],
		@vatSystem [INT],
		@autoPost [BIT],
		@autoEntry [BIT],
		@snGuid [UNIQUEIDENTIFIER],
		@costID [UNIQUEIDENTIFIER],
		@customerName [NVARCHAR](250),
		@deferredAccount [UNIQUEIDENTIFIER],
		@userNumber [FLOAT],
		@billItemsTotal [FLOAT],--Total For Ticket
		@billItemsDiscount [FLOAT], -- TicketItem Discount for Ticket
		@billItemsAdded  [FLOAT], -- äÓÈÉ ÇáÅÖÇÝÉ ãä ÇáÅÖÇÝíå ÇáÅÌãÇáíÉ
		@billItemsTax [FLOAT],
		@isVatTax [INT],-- 0 There is No Tax--- 1 VAT ---- ELSE TTc
		@profits [FLOAT],
		@btaxBeforeExtra [BIT] = (SELECT taxBeforeExtra FROM bt000 WHERE GUID = @billTypeID), -- total tax ratio
		@btaxBeforeDiscount [BIT] = (SELECT taxBeforeDiscount FROM bt000 WHERE GUID = @billTypeID), -- total tax ratio
		@ShiftNumber [INT],
		@billItemID [UNIQUEIDENTIFIER],
	    @billNote [NVARCHAR](250),
		@employeeName [NVARCHAR](250),
		@expirationDate [datetime] = '1/1/1980',
		@productionDate [datetime] = '1/1/1980',
		@entryNum INT,
		@Result INT,
		@count INT 	
------------------------------------------------
SET @customerName = ''
SET @Result = 0
------------------------------------------------------------------
SELECT @currencyID = ISNULL([Value], 0x0) 
	FROM [OP000] WHERE [Name] = 'AmnCfg_DefaultCurrency'
			
SELECT @currencyValue = ISNULL([CurrencyVal], 0) 
	FROM [MY000] WHERE [Guid] = @currencyID
------------------------------------------------------------------
SELECT  @billAccountID = ISNULL([DefBillAccGUID], 0x0),
        @discountAccountID = ISNULL([DefDiscAccGuid], 0x0),
        @extraAccountID = ISNULL([DefExtraAccGuid], 0x0),
        @vatSystem = ISNULL([VATSystem], 0),
        @autoPost = ISNULL([bAutoPost], 0),
        @autoEntry = ISNULL([bAutoEntry], 0),
        @costID = ISNULL(DefCostGUID, 0x0),
		@isVatTax = CASE VATSystem WHEN 0 THEN 0 WHEN 1 THEN 1 ELSE 2 END 
FROM [BT000]
WHERE [Guid] = @billTypeID

--------------------------------------------------------------------
SET @userGuid = [dbo].[fnGetCurrentUserGUID]()
SELECT @userNumber = NUMBER FROM [Us000] WHERE [Guid] = @UserGuid
------------------------------------------------------------------

----------ÍÓÇÈ ÑÞã ÇáÝÇÊæÑÉ ----------
SELECT @billNumber = ISNULL(MAX([Number]), 0) + 1
	FROM [BU000]
	WHERE [TypeGuid] = @BillTypeID 
	SET @BillNumber = ISNULL(@BillNumber, 1)
	SET @BillID = NEWID()

SELECT @deferredAccount = ISNULL([DefCashAccGUID], 0x0)
		FROM [BT000]
		WHERE [Guid] = @billTypeID

	--ÇáÍÕæá Úáì ÇáãÓÊæÏÚ æÚáì ÍÓÇÈ ÑÞÇÈÉ ÇáæÑÏíÉ 
	SELECT 	 @storeGuid = bt.DefStoreGUID, 
			 @posName = CASE @language WHEN 0 THEN ISNULL(posCard.Name, '') ELSE ISNULL(posCard.LatineName, '') END,
			 @shiftcontrol= posCard.ShiftControl, 
			 @shiftCode = posShift.Code,
			 @shiftNumber = posShift.Number,
			 @employeeName = CASE @language WHEN 0 THEN ISNULL(posEmployee.Name, '') ELSE ISNULL(posEmployee.LatinName, '') END
	FROM bt000 bt INNER JOIN POSCard000 posCard  ON posCard.SaleBillType = bt.GUID
			      INNER JOIN POSShift000 posShift ON posShift.POSGuid = posCard.Guid
				  INNER JOIN POSEmployee000 posEmployee ON posShift.EmployeeId = posEmployee.Guid
	WHERE ((@TicketsType = 0 AND posCard.SaleBillType =@billTypeID ) 
		OR (@TicketsType = 2 AND posCard.SaleReturnBillType =@billTypeID ))
		AND posShift.Guid = @shiftGuid

	
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------		   
DECLARE @TicketItemCalcDiscAndExtra Table
  (
	ItemGuid				UNIQUEIDENTIFIER,
	TicketGuid				UNIQUEIDENTIFIER,
	ValueToDiscount			FLOAT,
	ValueToAdd				FLOAT,
	ValueAfterCalc			FLOAT,
	totalDiscount			FLOAT,
	ItemDiscount			FLOAT,
	Discount				FLOAT,
	totalAddition			FLOAT,
	ItemAddition			FLOAT,
	Addition				FLOAT
  )
 INSERT INTO @TicketItemCalcDiscAndExtra EXEC prcPOSGetTicketItemsWithCalcDiscAndExtra @TicketsType
 
--------------------------------------------------------------
	DECLARE @MaterialsResult TABLE
	(
		MatGuid   UNIQUEIDENTIFIER,
		Quantity  FLOAT, 
		Price	  FLOAT,
		Value	  FLOAT,
		Tax       FLOAT,	
		ItemDiscount FLOAT,
		TotalDiscount FLOAT,
		ValueDiscount FLOAT,
		ItemExtra FLOAT,
		TotalExtra FLOAT,
		ValueExtra FLOAT,
		Unit	NVARCHAR(250),
		UnitFactor FLOAT, 
		UnitIndex FLOAT,
		VatRatio FLOAT
	)
--------------------------------------------------------------
	INSERT INTO @MaterialsResult
	SELECT 
			TItems.MatGuid													AS MatGuid,
			SUM(TItems.Qty)													AS Quantity,
			SUM(TItems.Price)												AS Price,
			SUM(TItems.Value)												AS Value,
			SUM(TItems.Tax)													AS Tax,
			SUM(TICDE.ItemDiscount)											AS ItemDiscount,
			SUM(TICDE.totalDiscount)										AS TotalDiscount,
			SUM(TICDE.Discount)												AS ValueDiscount,
			SUM(TICDE.ItemAddition)											AS ItemExtra,
			SUM(TICDE.totalAddition)										AS TotalExtra,
			SUM(TICDE.Addition)												AS ValueExtra,
			CASE TItems.UnitType WHEN 0 THEN MT.mtUnity
							 WHEN 1 THEN MT.mtUnit2
							 WHEN 2 THEN MT.mtUnit3 END						AS Unit,
		   	CASE TItems.UnitType 
						WHEN 1 THEN ISNULL([MT].mtUnit2Fact, 1)
						WHEN 2 THEN ISNULL([MT].mtUnit3Fact, 1)
						ELSE 1 END 								AS UnitFactor,
			 TItems.UnitType+1									AS UnitIndex,
			0.0													AS VatRatio			
	FROM	   POSTicketItem000 TItems
	INNER JOIN POSTicket000 Ticket ON Ticket.Guid= TItems.TicketGuid
	LEFT  JOIN @TicketItemCalcDiscAndExtra TICDE ON TItems.[Guid] = TICDE.ItemGuid
	LEFT  JOIN vwmt			  MT ON TItems.MatGuid	  = MT.mtGUID
	WHERE Ticket.State = 0 AND Ticket.ShiftGuid = @shiftGuid AND Ticket.Type = @TicketsType
	GROUP BY   TItems.MatGuid,
			   MT.mtName,
			   MT.mtCode,
			   TItems.UnitType,
			   MT.mtUnity,
			   MT.mtUnit2,
			   MT.mtUnit3,
			   MT.mtUnit2Fact,
			   MT.mtUnit3Fact,
			   MT.mtVat
	SELECT  
			@billItemsTotal = SUM(MT.Price),
			@billItemsDiscount = SUM(MT.ValueDiscount),
			@billItemsAdded = SUM(MT.ValueExtra),
			@billItemsTax = SUM(MT.Tax)
	FROM @MaterialsResult MT
	
SET @profits = @billItemsTotal - @billItemsDiscount + @billItemsAdded
------------------------------------------------------------------
SET @billNote  = [dbo].[fnStrings_get]('POS\BILLGENERATED', @language)+' '+ CONVERT(nvarchar(255), @shiftCode)
							  +[dbo].[fnStrings_get]('POS\TOPOSCARD', @language) +': '+@posName+'. '
							  +[dbo].[fnStrings_get]('POS\SHIFTEMPLOYEE', @language)+': '+@employeeName
		
IF EXISTS(SELECT * FROM @MaterialsResult)
BEGIN 
BEGIN TRANSACTION
			INSERT INTO [BU000]([Number],
	                    [Cust_Name], 
		                [Date], 
						[CurrencyVal], 
						[Notes], 
						[Total],
						[PayType], 
						[TotalDisc], 
						[TotalExtra], 
						[ItemsDisc], 
						[BonusDisc],
						[FirstPay], 
						[Profits], 
						[IsPosted], 
						[Security], 
						[Vendor], 
						[SalesManPtr], 
						[Branch], 
						[VAT], 
						[GUID], 
						[TypeGUID], 
						[CustGUID],
						[CurrencyGUID], 
						[StoreGUID], 
						[CustAccGUID], 
						[MatAccGUID], 
						[ItemsDiscAccGUID], 
						[BonusDiscAccGUID], 
						[FPayAccGUID], 
						[CostGUID],
						[UserGUID], 
						[CheckTypeGUID], 
						[TextFld1], 
						[TextFld2], 
						[TextFld3],
						[TextFld4], 
						[RecState], 
						[ItemsExtra], 
						[ItemsExtraAccGUID], 
						[CostAccGUID], 
						[StockAccGUID], 
						[VATAccGUID], 
						[BonusAccGUID],
						[BonusContraAccGUID])
	VALUES(@BillNumber,--Number
		   @customerName,--Cust_Name
		   GetDate(),--Date
		   @currencyValue,
		   @billNote,--Notes
		   @billItemsTotal,--Total 
           0,--PayType
           @billItemsDiscount,--TotalDisc
           @billItemsAdded,--TotalExtra
           @billItemsDiscount,--ItemsDisc
           0,--BonusDisc
           0,--FirstPay
           @Profits,--Profits
           0,--IsPosted
           1,--Security
           0,--Vendor
           @userNumber,--SalesManPtr
           0x0,--Branch
           @billItemsTax,--@salesOrderItemsTax + @orderTax,--VAT
           @billID,--GUID
           @billTypeID,--TypeGUID
           0x0,--CustGUID
           @currencyID,--CurrencyGUID
           @storeGuid,--StoreGUID
           @shiftControl,--CustAccGUID
           0x0,--MatAccGUID
           0x0,--ItemsDiscAccGUID
           @discountAccountID,--BonusDiscAccGUID
           0x0,--FPayAccGUID
           @costID,--CostGUID
           @userGuid,--UserGUID
           0x0,--CheckTypeGUID
           '',--TextFld1
           '',--TextFld2
           '',--TextFld3
           '',--TextFld4
           0,--RecState
           @billItemsAdded,--ItemsExtra
           0x0,--ItemsExtraAccGUID
           0x0,--CostAccGUID
           0x0,--StockAccGUID
           0x0,--VATAccGUID
           0x0,--BonusAccGUID
           0x0)--BonusContraAccGUID
	------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	
	INSERT INTO [BI000]([Number], 
					 [Qty], 
					 [Order],  
					 [OrderQnt],  
					 [Unity],  
					 [Price],  
					 [BonusQnt],  
					 [Discount],  
					 [BonusDisc],  
					 [Extra],  
					 [CurrencyVal],  
					 [Notes],  
					 [Profits],  
					 [Num1],  
					 [Num2],  
					 [Qty2],  
					 [Qty3],  
					 [ClassPtr],  
					 [ExpireDate],  
					 [ProductionDate],  
					 [Length],  
					 [Width],  
					 [Height],  
					 [GUID],  
					 [VAT],  
					 [VATRatio],  
					 [ParentGUID],  
					 [MatGUID],  
					 [CurrencyGUID],  
					 [StoreGUID],  
					 [CostGUID],  
					 [SOType],  
					 [SOGuid],  
					 [Count])	
	(SELECT			row_number() over (order by (select NULL)),
					Mt.UnitFactor* MT.Quantity AS Qty,
					0, --Order
					0, --OrderQnt
					MT.UnitIndex  as Unity,
					MT.Value/ MT.Quantity,-- ÇáÅÝÑÇÏí
					0, --BonusQnt
					MT.ValueDiscount AS [Discount],
					0, --BonusDisc
					MT.ValueExtra  AS [Added],
					@currencyValue, --CurrencyVal
					'',--ISNULL([Item].[Note], '') AS [Note],
					@Profits, --Profits
					0, --Num1
					0, --Num2
					0, --Qty2
					0, --Qty3
					0x0,--ClassPtr, --ClassPtr
					@expirationDate,--[Item].[ExpirationDate] AS [ExpirationDate],
					@productionDate,--[Item].[ProductionDate] AS [ProductionDate],
					0, --Length
					0, --Width
					0, --Height
					NEWID(),--@BillItemID,
					MT.Tax,--ISNULL([Item].[Tax], 0) AS [VAT],
					((MT.Tax * 100) / (MT.Value 
										- 
										CASE @btaxBeforeDiscount WHEN 0 THEN Mt.ValueDiscount ELSE 0 END
										+
										CASE @btaxBeforeExtra WHEN 0 THEN  MT.ValueExtra ELSE 0 END)
										), -- VATRatio
					@billID, --ParentGUID
					ISNULL(MT.MatGuid, 0x0)AS [MatID],-- AS [MatID],
					@currencyID, --CurrencyGUID
					@StoreGuid,--StoreGUID
					0x0,-- [SalesmanID],
					0, --SOType
					0x0,--[SpecialOfferID],
					0 --Count
	FROM  @MaterialsResult MT 
	GROUP BY MT.MatGuid, MT.UnitIndex,Mt.UnitFactor, Mt.Quantity,MT.Value,MT.ValueDiscount, MT.ValueExtra, MT.Tax,Mt.VatRatio
		)
	---------------------------------------------------------------------
	
	INSERT INTO [BillRel000]
		   ([GUID]
		   ,[Type]
		   ,[BillGUID]
		   ,[ParentGUID]
		   ,[ParentNumber])
	 VALUES(NEWID(), --GUID
			1,	--Type
			@BillID, --BillGUID
			@shiftGuid, --ParentGUID
			@ShiftNumber) --ParentNumber
	
	--------------------GenerateEntry-----------------------
	SELECT @entryNum = ISNULL(MAX(number), 0) + 1 FROM ce000	
	
	IF @autoPost = 1
	BEGIN
		EXECUTE [prcBill_Post1] @BillID, 1
	END
	
	DECLARE @ResultMaterial INT
	
	DECLARE @tableCe NVARCHAR(256) ='ce000'
	DECLARE @tableEn NVARCHAR(256) ='en000'
	DECLARE @tableEr NVARCHAR(256) ='er000'
	
	SET @ResultMaterial = 0 
			
	IF @autoEntry = 1
	BEGIN
		EXEC prcDisableTriggers 'ce000', 0
		EXEC prcDisableTriggers 'en000', 0
		EXEC prcDisableTriggers 'er000', 0

		EXECUTE [prcBill_GenEntry] @billID, @entryNum

		EXEC prcEnableTriggers 'ce000'
		EXEC prcEnableTriggers 'en000'
		EXEC prcEnableTriggers 'er000'

	END 
	COMMIT
	END
	
	SELECT @count = COUNT(*)  FROM BillRel000 WHERE BillGUID = @BillID
    SELECT @ResultMaterial = COUNT(*) FROM @MaterialsResult

	IF (@count > 0  OR @ResultMaterial = 0)
	BEGIN
		SET @Result =1
	END
	ELSE 
		SET @Result = 0

SET @returnValue = @Result

RETURN @Result

END
#################################################################
CREATE PROCEDURE prcPOSGetBillRelatedToTheShift
-- Params -------------------------------   
	@ShiftGuid				UNIQUEIDENTIFIER,
	@BillType				INT = 0 -- 0:All, 1: Sales, 2: Purchases, 3: ReturnedSales, 4: Returned Purchases 
-----------------------------------------   
AS
    SET NOCOUNT ON
------------------------------------------------------------------------
DECLARE @SalesBillType UNIQUEIDENTIFIER,
		@SalesReturnBillType UNIQUEIDENTIFIER,
		@PurchasesBillType UNIQUEIDENTIFIER,
		@PurchasesReturnBillType UNIQUEIDENTIFIER

SELECT @SalesBillType = pos.SaleBillType,
		@SalesReturnBillType = pos.SaleReturnBillType,
		@PurchasesBillType = pos.PurchaseBillType,
		@PurchasesReturnBillType = pos.PurchaseReturnBillType 
FROM POSCard000 pos
INNER JOIN POSShift000 shifts ON shifts.[POSGuid] = pos.[Guid]
WHERE shifts.[Guid] = @ShiftGuid

SELECT BR.BillGUID  AS BillGuid,
	   BU.Number    AS BillNumber,
	   BU.TypeGUID  AS BillTypeGuid
		
FROM  BillRel000 BR 
INNER JOIN bu000 BU ON BR.BillGUID = BU.[GUID]
WHERE ParentGUID     = @ShiftGuid 
AND 
(
	@BillType = 0
	OR (@BillType = 1 AND @SalesBillType = BU.[TypeGUID])
	OR (@BillType = 2 AND @PurchasesBillType = BU.[TypeGUID])
	OR (@BillType = 3 AND @SalesReturnBillType = BU.[TypeGUID])
	OR (@BillType = 4 AND @PurchasesReturnBillType = BU.[TypeGUID])
) 
#################################################################
CREATE FUNCTION PosIsAuthorized
(
       @shiftGuid uniqueidentifier,
       @posEmployeeGuid uniqueidentifier,
       @deviceId nvarchar(50)
)fnPOSSDOperationsAccountIsUsedInAllPOS
RETURNS BIT
AS
BEGIN
       
       DECLARE @isAuthorized BIT
       SET @isAuthorized = 0;

       IF (EXISTS(
                           SELECT TOP 1 *
                           FROM POSShiftDetails000

                           WHERE ShiftGuid =  @shiftGuid AND POSUSer = @posEmployeeGuid AND DeviceID = @deviceId

                           AND (EntryDate = (SELECT MAX(EntryDate) FROM POSShiftDetails000 WHERE ShiftGuid =  @shiftGuid AND POSUser = @posEmployeeGuid))
                           ORDER BY EntryDate DESC)
              )
       BEGIN
              SET @isAuthorized = 1;
       END
       
       RETURN @isAuthorized
END
#################################################################
CREATE PROCEDURE IsTherePOSAccountOutsidePosMoves
(
  @posGuid UNIQUEIDENTIFIER,
  @Result BIT  OUTPUT
)
AS
BEGIN
	SET @Result = 0
	DECLARE @count INT, @controlAccount UNIQUEIDENTIFIER, @floatAccount UNIQUEIDENTIFIER,
	@openingDate DATETIME, @closeDate DATETIME, @res BIT = 0
	DECLARE @MovesOutPOS Table 
	(EnDate	DATETIME,
	CeNumber INT,
	CeGuid	UNIQUEIDENTIFIER,
	EnGuid	UNIQUEIDENTIFIER,
	BuGuid	UNIQUEIDENTIFIER,
	ChGuid	UNIQUEIDENTIFIER,
	EnNotes	NVARCHAR(MAX),
	AccountGuid	UNIQUEIDENTIFIER,
	Debit	FLOAT,
	Credit	FLOAT,
	MoveBalance	FLOAT,
	Name	NVARCHAR(256),
	EnCurrencyVal	FLOAT,
	EnCurrencyCode	NVARCHAR(256),
	CeParentType	INT,
	BillType	INT,
	ParentGuid	UNIQUEIDENTIFIER,
	ParentNumber	INT,
	CeTypeGuid	UNIQUEIDENTIFIER
	)
	SELECT @controlAccount = ShiftControl From POSCard000 WHERE Guid = @posGuid
	SELECT @floatAccount = ContinuesCash From POSCard000 WHERE Guid = @posGuid
	SELECT @openingDate = CONVERT(DATETIME, Value) From op000 WHERE Name = 'AmnCfg_FPDate'
	SELECT @closeDate = CONVERT(DATETIME, Value) From op000 WHERE Name = 'AmnCfg_EPDate'
	
	INSERT INTO @MovesOutPOS
	  EXEC prcPOSControlAccountOutsideMoves @posGuid, @controlAccount, @openingDate, @closeDate
	
	INSERT INTO @MovesOutPOS
	  EXEC prcPOSControlAccountOutsideMoves @posGuid, @floatAccount, @openingDate, @closeDate
	
	SELECT @count = COUNT(*) FROM @MovesOutPOS
	
	IF(@count > 0)
	 SET @Result = 1
   
END
#################################################################
#END
