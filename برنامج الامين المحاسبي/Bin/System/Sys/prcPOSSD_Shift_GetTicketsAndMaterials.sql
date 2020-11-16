################################################################################
CREATE PROCEDURE prcPOSSD_Shift_GetTicketsAndMaterials
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
	DECLARE @language INT = [dbo].[fnConnections_getLanguage]()
	DECLARE @IsOrder  BIT = 0
	DECLARE @IsGCCTaxSystemEnable BIT = ISNULL((SELECT Value FROM op000 WHERE Name = 'AmnCfg_EnableGCCTaxSystem'), 0)
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
		SELECT @TicketsType = [Type] + 1,
			   @IsOrder		= (CASE OrderType WHEN 0 THEN 0 ELSE 1 END)
		FROM POSSDTicket000 
		WHERE [GUID] = @TicketGuid
	END
	IF(@TicketsType = 1)
	BEGIN
		-- Sales tickets
		INSERT INTO #TicketItemCalcDiscAndExtra EXEC prcPOSSD_Ticket_GetTicketItemsCalcDiscAndExtra 0;
	END
	IF(@TicketsType = 3)
	BEGIN
		-- Sales Return tickets
		INSERT INTO #TicketItemCalcDiscAndExtra EXEC prcPOSSD_Ticket_GetTicketItemsCalcDiscAndExtra 2;
	END

	------------------------------------------------------------------------
	SELECT 
		Items.TicketGuid, 
		SUM(TICDE.Discount) AS IDiscVal,
		SUM(TICDE.Addition) AS IExtrVal
	INTO 
		#TempItem
	FROM 
		#TicketItemCalcDiscAndExtra TICDE
		LEFT JOIN POSSDTicketItem000 Items ON TICDE.ItemGuid = Items.[Guid]
		LEFT JOIN mt000 MT ON Items.MatGuid = MT.[GUID]
	WHERE 
		(Items.TicketGuid = @TicketGuid   OR @TicketGuid   = 0x0)
		AND   (MatGuid          = @MaterialGUID OR @MaterialGUID = 0x0)
		AND   (MT.GroupGUID     = @GroupGUID    OR @GroupGUID    = 0x0)
	GROUP BY Items.TicketGuid

	------------------------------- RETURN COUPON & RETURN CARD
	DECLARE @IsReceipt INT = (CASE @TicketsType WHEN 1 THEN 1 ELSE 0 END)
	CREATE TABLE #TicketWithReturnCoupon 
	(
		TicketGUID UNIQUEIDENTIFIER,
		ReturnCouponAmount FLOAT,
		ReturnCardAmount FLOAT,
		ReturnCouponCode NVARCHAR(250),
		ReturnCardCode NVARCHAR(250)
	)

	-- ReturnCoupon
	INSERT INTO #TicketWithReturnCoupon
	SELECT 
		T.TicketGUID,
	    TRC.Amount  AS ReturnCouponAmount,
	    0 AS ReturnCardAmount,
		RC.Code AS ReturnCouponCode,
	    '' AS ReturnCardCode		
	FROM 
		#TempItem T 
		INNER JOIN POSSDTicketReturnCoupon000 TRC ON T.TicketGUID = TRC.TicketGUID
		INNER JOIN POSSDReturnCoupon000       RC  ON TRC.ReturnCouponGUID = RC.[GUID]
	WHERE TRC.IsReceipt = @IsReceipt AND TRC.[Type] = 0
	
	-- ReturnCard
	UPDATE #TicketWithReturnCoupon
		SET ReturnCardAmount = TRC.Amount,
			ReturnCardCode =  RC.Code
	FROM #TicketWithReturnCoupon ret
		INNER JOIN #TempItem T ON T.TicketGUID = ret.TicketGUID
		INNER JOIN POSSDTicketReturnCoupon000 TRC ON T.TicketGUID = TRC.TicketGUID
		INNER JOIN POSSDReturnCoupon000       RC  ON TRC.ReturnCouponGUID = RC.[GUID]
	WHERE TRC.IsReceipt = @IsReceipt AND TRC.[Type] = 1
	INSERT INTO #TicketWithReturnCoupon
	SELECT 
		T.TicketGUID,
		0 AS ReturnCouponAmount,
	    TRC.Amount AS ReturnCardAmount,
		''  AS ReturnCouponCode,
	    RC.Code  AS ReturnCardCode
	FROM 
		#TempItem T 
		INNER JOIN POSSDTicketReturnCoupon000 TRC ON T.TicketGUID = TRC.TicketGUID
		INNER JOIN POSSDReturnCoupon000       RC  ON TRC.ReturnCouponGUID = RC.[GUID]
	WHERE TRC.IsReceipt = @IsReceipt AND TRC.[Type] = 1 AND
	T.TicketGUID NOT IN (SELECT TicketGUID FROM #TicketWithReturnCoupon)

	------------------------------- RECEIVE COUPON & RECEIVE CARD for sale tickets
	CREATE TABLE #TicketWithReceiveCoupon
	(
		TicketGUID UNIQUEIDENTIFIER,
		ReceiveCouponAmount FLOAT,
		ReceiveCardAmount FLOAT,
		ReceiveCouponCode NVARCHAR(250),
		ReceiveCardCode NVARCHAR(250)
	)
	IF(@TicketsType = 1)
	BEGIN
		-- ReturnCoupon
		INSERT INTO #TicketWithReceiveCoupon
		SELECT 
			T.TicketGUID,
			TRC.Amount  AS ReturnCouponAmount,
			0 AS ReturnCardAmount,
			RC.Code AS ReturnCouponCode,
			'' AS ReturnCardCode		
		FROM 
			#TempItem T 
			INNER JOIN POSSDTicketReturnCoupon000 TRC ON T.TicketGUID = TRC.TicketGUID
			INNER JOIN POSSDReturnCoupon000       RC  ON TRC.ReturnCouponGUID = RC.[GUID]
		WHERE TRC.IsReceipt = 0 AND TRC.[Type] = 0
	
		-- ReturnCard
		UPDATE #TicketWithReceiveCoupon
			SET ReceiveCardAmount = TRC.Amount,
				ReceiveCardCode =  RC.Code
		FROM #TicketWithReceiveCoupon ret
			INNER JOIN #TempItem T ON T.TicketGUID = ret.TicketGUID
			INNER JOIN POSSDTicketReturnCoupon000 TRC ON T.TicketGUID = TRC.TicketGUID
			INNER JOIN POSSDReturnCoupon000       RC  ON TRC.ReturnCouponGUID = RC.[GUID]
		WHERE TRC.IsReceipt = 0 AND TRC.[Type] = 1
		INSERT INTO #TicketWithReceiveCoupon
		SELECT 
			T.TicketGUID,
			0 AS ReturnCouponAmount,
			TRC.Amount AS ReturnCardAmount,
			''  AS ReturnCouponCode,
			RC.Code  AS ReturnCardCode
		FROM 
			#TempItem T 
			INNER JOIN POSSDTicketReturnCoupon000 TRC ON T.TicketGUID = TRC.TicketGUID
			INNER JOIN POSSDReturnCoupon000       RC  ON TRC.ReturnCouponGUID = RC.[GUID]
		WHERE TRC.IsReceipt = 0 AND TRC.[Type] = 1 AND
		T.TicketGUID NOT IN (SELECT TicketGUID FROM #TicketWithReceiveCoupon)
	END

	------------------------------- RETURN SALE EXCHANGE TICKET
	DECLARE @RESaleExchangeTicketGuid UNIQUEIDENTIFIER = 0x0
	IF(@TicketGuid <> 0x0 AND @TicketsType = 1)
	BEGIN
		SET @RESaleExchangeTicketGuid = ( SELECT TOP 1 [GUID] FROM POSSDTicket000 WHERE RelatedTo = @TicketGuid )
	END
	
	------------------------------- TICKETS PERMISSIONS
	CREATE TABLE #TicketPermissions
	(
		TicketGUID UNIQUEIDENTIFIER,
		ApprovesCount INT
	)
	INSERT INTO #TicketPermissions 
	SELECT t.[GUID], COUNT(op.[SupervisorGUID]) AS ApprovesCount
	FROM POSSDTicket000 t 
	INNER JOIN POSSDTicketItem000 ti ON ti.[TicketGUID] = t.[GUID] 
	INNER JOIN POSSDOperationPermission000 op ON op.RecordGUID = t.[GUID] 
			OR op.RecordGUID = ti.[GUID] 
	GROUP BY t.[GUID]

	------------------------------- Orders collected from the driver
	SELECT O.[GUID]
	INTO #OrdersCollectedFromDriver 
	FROM 
		POSSDTicketOrderInfo000 O
		INNER JOIN #TempItem T ON O.TicketGUID = T.TicketGUID
		CROSS APPLY (SELECT [dbo].[fnPOSSD_Order_IsCollectedFromDriver](O.[GUID]) AS IsCollectedFromDriver) AS fn
	WHERE fn.IsCollectedFromDriver = 1

	------------------------------- TICKETS 
	SELECT 
		TICKET.[GUID]																 AS [GUID],
		TICKET.Number																 AS Number,
		TICKET.Code																	 AS Code,
		ISNULL(ApprovesCount, 0)													 AS ApprovesCount,
		TotalItems.IDiscVal															 AS DiscValue,
		TotalItems.IExtrVal															 AS AddedValue,
		ISNULL(TICKET.TaxTotal, 0)													 AS TaxTotal,
		ISNULL(TICKET.Total, 0)														 AS Total,
		ISNULL(ABS(TICKET.Net), 0)													 AS NetValue,
		CASE WHEN OC.[GUID] IS NULL 
			 THEN ISNULL(TICKET.CollectedValue, 0) + ISNULL([ORDER].DownPayment, 0)
			 ELSE 0  END															  AS CollectedValue,
		ISNULL(TCURR.Value, 0)														  AS LaterValue,
		TICKET.OpenDate																  AS OpenDate,
		ISNULL(TICKET.PaymentDate, '1980-01-01 00:00:00')							  AS CloseDate,
		TICKET.[State]																  AS TicketState,
		TICKET.RelationType															  AS RelationType,
		TICKET.OrderType															  As OrderType,
		CAST(ISNULL(RelatedTicket.Number, 0) AS NVARCHAR(250))						  AS RelatedToNumber,
		ISNULL(RelatedTicket.Net, 0)												  AS RelatedTicketValue,
		CAST(SH.Code AS NVARCHAR(250))												  AS ShiftCode,
		Emp.Name																	  AS EmployeeName,
		TICKET.Note																	  AS Note,
		ISNULL(COUPON.ReturnCouponAmount, 0)										  AS ReturnCouponAmount,
		ISNULL(COUPON.ReturnCardAmount, 0)											  AS ReturnCardAmount,
		ISNULL(COUPON.ReturnCouponCode, '')											  AS ReturnCouponCode,
		ISNULL(COUPON.ReturnCardCode, '')											  AS ReturnCardCode,
		ISNULL(RECECOUP.ReceiveCouponAmount, 0)										  AS ReceiveCouponAmount,
		ISNULL(RECECOUP.ReceiveCardAmount, 0)										  AS ReceiveCardAmount,
		ISNULL(RECECOUP.ReceiveCouponCode, '')										  AS ReceiveCouponCode,
		ISNULL(RECECOUP.ReceiveCardCode, '')										  AS ReceiveCardCode,
		ISNULL(SALESMAN.[GUID], 0x0)												  AS SalesmanGUID,
		ISNULL(SALESMAN.Name, '')													  AS Salesman,
		ISNULL(CO.Code,'') + ' - ' + ISNULL(CO.Name, '')							  AS CostCenter,
		ISNULL([ORDER].Number, 0)													  AS OrderNumber,
		ISNULL([ORDER].DeliveryFee, 0)												  AS DeliveryFee,
		ISNULL([ORDER].DownPayment, 0)												  AS DownPayment, 

		CASE WHEN OC.[GUID] IS NULL THEN 0
								    ELSE 1 END										  AS IsOrderCollectedFromDriver,

		CASE @TicketGuid WHEN 0x0 THEN ISNULL(ReSaleRelatedTicket.[GUID], 0x0) 
						 ELSE (CASE @TicketsType WHEN 1 THEN @RESaleExchangeTicketGuid
												 ELSE ISNULL(ReSaleRelatedTicket.[GUID], 0x0) END)  END AS RelatedToGuid,

		CASE @language   WHEN 0   THEN CU.CustomerName
					     ELSE CASE CU.LatinName WHEN '' THEN CU.CustomerName 
											    ELSE CU.LatinName END END                               AS CustomerAcc,
		POSD.DeviceName,
		POSD.DeviceID,
		CASE @language   WHEN 0   THEN GCCLOC.Name
					     ELSE CASE LEN(GCCLOC.LatinName) WHEN 0 THEN GCCLOC.Name 
					     ELSE GCCLOC.LatinName END END    AS GCCLOCName

	INTO #TicketsResult
	FROM	    
		POSSDTicket000   TICKET 
		INNER JOIN  #TempItem TotalItems               ON TICKET.[GUID]           = TotalItems.TicketGuid
		LEFT  JOIN  #TicketWithReturnCoupon COUPON     ON TICKET.[GUID]		      = COUPON.TicketGUID
		LEFT  JOIN  #TicketWithReceiveCoupon RECECOUP  ON TICKET.[GUID]		      = RECECOUP.TicketGUID
		LEFT  JOIN  POSSDTicketCurrency000  TCURR      ON TICKET.[GUID]           = TCURR.TicketGUID AND TCURR.PayType = 2 --Later pay type
		LEFT  JOIN  POSSDTicket000 RelatedTicket       ON TICKET.[GUID]			  = RelatedTicket.RelatedTo
		LEFT  JOIN  POSSDTicket000 ReSaleRelatedTicket ON TICKET.RelatedTo		  = ReSaleRelatedTicket.[GUID]
		LEFT  JOIN  cu000 CU		                   ON TICKET.CustomerGUID     = CU.[GUID]
		LEFT  JOIN  POSSDShift000 SH                   ON TICKET.ShiftGUID        = SH.[GUID]
		LEFT  JOIN  POSSDStation000 [Card]	           ON SH.StationGUID	      = [Card].[Guid]
		LEFT  JOIN  POSSDEmployee000 Emp		       ON SH.EmployeeGUID         = Emp.[Guid]
		LEFT  JOIN  POSSDSalesman000 SALESMAN	       ON TICKET.SalesmanGUID     = SALESMAN.[GUID]
		LEFT  JOIN  co000 CO					       ON SALESMAN.CostCenterGUID = CO.[GUID]
		LEFT  JOIN  POSSDTicketOrderInfo000 [ORDER]    ON [ORDER].TicketGUID	  = TICKET.[GUID]
		LEFT  JOIN  #OrdersCollectedFromDriver OC	   ON OC.[GUID] = [ORDER].[GUID]
		LEFT  JOIN  #TicketPermissions tp			   ON tp.TicketGUID			  = TICKET.[GUID]
		LEFT  JOIN  POSSDStationDevice000 AS POSD	   ON (POSD.DeviceID		  = TICKET.DeviceID	AND POSD.StationGUID = SH.StationGUID)
		LEFT  JOIN  GCCCustLocations000 AS GCCLOC	   ON (GCCLOC.GUID		  = TICKET.GCCLocationGUID)
	WHERE    
				 (TICKET.ShiftGUID = @ShiftGuid OR @ShiftGuid = 0x0)
		AND		 ((@TicketsType > 0 AND TICKET.[Type] = (@TicketsType-1)) OR @TicketsType = 0)
		AND		 (TICKET.CustomerGuid  =  @CustomerGUID OR @CustomerGUID = 0x0)
		AND		 (TICKET.Number >= @FromNumber   OR @FromNumber   = 0)
		AND      (TICKET.Number <= @ToNumber     OR @ToNumber     = 0)
		AND		((ISNULL(TICKET.Total, 0) - ISNULL(TICKET.DiscValue, 0) + ISNULL(TICKET.AddedValue, 0) > @FirstConditionValue AND @ConditionType = 0)
			  OR (ISNULL(TICKET.Total, 0) - ISNULL(TICKET.DiscValue, 0) + ISNULL(TICKET.AddedValue, 0) < @FirstConditionValue AND @ConditionType = 1) 
			  OR (ISNULL(TICKET.Total, 0) - ISNULL(TICKET.DiscValue, 0) + ISNULL(TICKET.AddedValue, 0) = @FirstConditionValue AND @ConditionType = 2)
			  OR((ISNULL(TICKET.Total, 0) - ISNULL(TICKET.DiscValue, 0) + ISNULL(TICKET.AddedValue, 0) BETWEEN @FirstConditionValue AND @SecondConditionValue) AND  @ConditionType = 3) )
		AND		((TICKET.LaterValue     = 0 AND TICKET.CollectedValue != 0 AND @PayType & 2 = 2 )
			  OR (TICKET.CollectedValue = 0 AND TICKET.LaterValue     != 0 AND @PayType & 4 = 4 )
			  OR (TICKET.LaterValue    != 0 AND TICKET.CollectedValue != 0 AND @PayType & 8 = 8)
			  OR (TICKET.LaterValue     = 0 AND TICKET.CollectedValue  = 0 AND @PayType = 14))
		AND		((TICKET.[State] = 0 AND @TicketState & 2 = 2)
			  OR ((TICKET.[State] = 1 OR TICKET.[State] = -1) AND @TicketState & 4 = 4)
			  OR (TICKET.[State] = 2 AND @TicketState & 8 = 8)
			  OR (TICKET.[State] IN (5,6,7)  AND @IsOrder = 1))
		AND      (@TicketNote	 = '' OR TICKET.Note  LIKE  '%'+ @TicketNote + '%')
		AND      ((TICKET.OrderType = 0 OR (TICKET.OrderType > 0 AND TICKET.[State] = 0))
			  OR  (@IsOrder = 1))

------------------------------- MTERILAS
	SELECT 
		TItems.MatGuid																	 AS MatGuid,
		MT.mtCode + ' - ' + MT.mtName  													 AS MatName,
		SUM(TItems.Qty)																	 AS Quantity,
		SUM(TItems.Value) / SUM(TItems.Qty) 											 AS Price,
		SUM(TItems.Value)																 AS Value,
		SUM(TICDE.ItemDiscount)															 AS ItemDiscount,
		SUM(TICDE.totalDiscount)														 AS TotalDiscount,
		SUM(TICDE.Discount)																 AS ValueDiscount,
		SUM(TICDE.ItemAddition)															 AS ItemExtra,
		SUM(TICDE.totalAddition)														 AS TotalExtra,
		SUM(TICDE.Addition)																 AS ValueExtra,
		SUM(TItems.Tax)																	 AS Tax,
		SUM(TItems.Value) - SUM(TICDE.Discount) + SUM(TICDE.Addition) + SUM(TItems.Tax)  AS NetBalance,
		CASE TItems.UnitType WHEN 0 THEN MT.mtUnity
							 WHEN 1 THEN MT.mtUnit2
							 WHEN 2 THEN MT.mtUnit3 END					                 AS Unit,
		TItems.UnitType													                 AS UnitIndex,
		ISNULL(TR.SalesmanGUID, 0x0)													 AS SalesmanGUID,
		ISNULL(TR.CostCenter, '')										                 AS CostCenter,
		CASE @language WHEN 0 THEN MT.mtCompositionName
					   ELSE CASE ISNULL(MT.mtCompositionLatinName,'') WHEN '' THEN MT.mtCompositionName 
																	  ELSE MT.mtCompositionLatinName  END END	AS CompositionName,
		ISNULL(GCCTC.Code, '') AS TaxCodeDesc
	INTO
		#MaterialsResult
	FROM	   
		POSSDTicketItem000 TItems
		INNER JOIN #TicketsResult TR				 ON TItems.TicketGUID = TR.[GUID]
		LEFT  JOIN #TicketItemCalcDiscAndExtra TICDE ON TItems.[Guid]     = TICDE.ItemGuid
		LEFT  JOIN vwmt	MT							 ON TItems.MatGUID	  = MT.mtGUID
		LEFT  JOIN GCCTaxCoding000 GCCTC ON @IsGCCTaxSystemEnable = 1 AND GCCTC.TaxCode = TItems.TaxCode
	WHERE 
		(TItems.MatGuid = @MaterialGUID OR @MaterialGUID = 0x0)
	AND (MT.mtGroup     = @GroupGUID    OR @GroupGUID    = 0x0)   
	GROUP BY   
		TItems.MatGuid,
		MT.mtName,
		MT.mtCode,
		TItems.UnitType,
		MT.mtUnity,
		MT.mtUnit2,
		MT.mtUnit3,
		TR.CostCenter,
		TR.SalesmanGUID,
		CASE @language WHEN 0 THEN MT.mtCompositionName 
					   ELSE CASE ISNULL(MT.mtCompositionLatinName,'') WHEN '' THEN MT.mtCompositionName 
																	  ELSE MT.mtCompositionLatinName  END END,	
		GCCTC.Code

	--======================================================================================

	DECLARE @TicketPays TABLE ( TicketGUID				UNIQUEIDENTIFIER,
								RecordGUID				UNIQUEIDENTIFIER,
								IsCurrency				BIT,
								IsBankCard				BIT,
								IsExchangeTicket		BIT,
								OrderPaymentType		INT, -- 0 isNotOrder, 1 DownPayment, 2 DriverPayment
								DriverName				NVARCHAR(50),
								[PayType]				INT, -- 1 cash else later
								[Value]					FLOAT,
								[CurrencyValue]			FLOAT,
								[Code]					NVARCHAR(32),
								IsMainCurrency			BIT,
								IsReturnCouponReceipt	INT,
								IsReturnCoupon			INT,
								IsReturnCard			INT,
								CouponExpiryDate		DATETIME )

	-- Order collected from driver --
	INSERT INTO @TicketPays
		SELECT
			t.GUID,														
			my.GUID,													
			1,															
			0,															
			0,															
			0,															
			'',															
			cu.PayType,													
			cu.[Value],													
			CASE my.CurrencyVal WHEN 1 THEN 1 ELSE cu.[CurrencyVal] END,
			0,															
			CASE my.CurrencyVal WHEN 1 THEN 1 ELSE 0 END,				
			0,															
			0,															
			0,															
			NULL														
		FROM 		
			my000 my
			INNER JOIN POSSDTicketCurrency000 cu ON my.GUID = cu.CurrencyGUID
			INNER JOIN #TicketsResult t ON t.GUID = cu.TicketGUID
		WHERE
			t.IsOrderCollectedFromDriver = 0
		ORDER BY my.Number 

	-- Bank cards --
	INSERT INTO @TicketPays
		SELECT
			t.GUID,		
			b.GUID,		
			0,			
			1,			
			0,			
			0,			
			'',			
			1, -- cash	
			tb.[Value],	
			1,			
			tb.CheckNumber,
			0,			
			0,			
			0,			
			0,			
			NULL		
		FROM 		
			BankCard000 b 
			INNER JOIN POSSDTicketBankCard000 tb ON b.GUID = tb.BankCardGUID 
			INNER JOIN #TicketsResult t ON t.GUID = tb.TicketGUID 
		ORDER BY 
		b.Number

	-- Return coupon --
	INSERT INTO @TicketPays
		SELECT 																							   
			T.[GUID],																					  
			RC.ReturnSettingsGUID,																		  
			0,																							  
			0,																							  
			0,																							  
			0,																							  
			'',																							  
			1,																							  
			TRC.Amount,																					  
			1,																							  
			RC.Code,																					  
			0,																							  
			TRC.IsReceipt,																				  
			CASE RC.Type WHEN 0 THEN 1 ELSE 0 END,														  
			CASE Rc.Type WHEN 1 THEN 1 ELSE 0 END,														  
			(CASE RC.ExpiryDays WHEN 0 THEN NULL ELSE DATEADD(DAY, RC.ExpiryDays, RC.TransactionDate) END)
		FROM 
			#TicketsResult T 
			INNER JOIN POSSDTicketReturnCoupon000 TRC ON T.[GUID] = TRC.TicketGUID
			INNER JOIN POSSDReturnCoupon000       RC  ON TRC.ReturnCouponGUID = RC.[GUID]	

	-- exchange ticket --
	INSERT INTO @TicketPays
		SELECT 
			T.[GUID],							
			TICKET.[GUID],						
			0,									
			0,									
			1,									
			0,									
			'',									
			1,									
			TICKET.Net,							
			1,									
			CAST(TICKET.Number AS NVARCHAR(250)),
			0,									
			0,									
			0,									
			0,									
			NULL								
		FROM 
			#TicketsResult T 
			INNER JOIN POSSDTicket000 TICKET ON T.RelatedToGuid = TICKET.[GUID]
	
	-- Down payment --
	INSERT INTO @TicketPays
		SELECT 
			T.[GUID],											
			[ORDER].[GUID],										
			0,													
			0,													
			0,													
			1,													
			'',													
			1,													
			[ORDER].DownPayment,								
			(CASE [ORDER].DownPayment WHEN 0 THEN 0 ELSE 1 END),
			CAST([ORDER].Number AS NVARCHAR(50)),				
			0,													
			0,													
			0,													
			0,													
			NULL												
		FROM 
			#TicketsResult T 
			INNER JOIN POSSDTicketOrderInfo000 [ORDER] ON [ORDER].TicketGUID = T.[GUID]

	-- Driver payment --
	INSERT INTO @TicketPays
		SELECT 
			T.[GUID],																			
			[ORDER].[GUID],																		
			0,																					
			0,																					
			0,																					
			2,																					
			DRIVER.Name,																		
			1,																					
			(CASE ISNULL(OE.[Event], -1) WHEN -1 THEN 0 ELSE T.Total - [ORDER].DownPayment END),
			(CASE ISNULL(OE.[Event], -1) WHEN -1 THEN 0 ELSE 1 END),							
			CAST([ORDER].Number AS NVARCHAR(50)),												
			0,																					
			0,																					
			0,																					
			0,																					
			NULL																				
		FROM 
			#TicketsResult T 
			INNER JOIN POSSDTicketOrderInfo000 [ORDER] ON [ORDER].TicketGUID = T.[GUID]
			INNER JOIN POSSDDriver000 DRIVER ON DRIVER.[GUID] = [ORDER].DriverGUID
			LEFT JOIN  POSSDOrderEvent000 OE ON OE.OrderGUID = [ORDER].[GUID] AND OE.[Event] = 12--event collect order value from driver 

------------------------------- MATERIAL WITH SERIAL NUMBERS
	SELECT 
		DISTINCT TI.MatGUID
	INTO 
		#MaterialsWithSerialNumbers
	FROM 
		POSSDTicketItemSerialNumbers000 SN
		INNER JOIN POSSDTicketItem000 TI ON SN.TicketItemGUID = TI.[GUID]
		INNER JOIN #TicketsResult T ON TI.TicketGUID = T.[GUID]

	--------------------  R E S U L T S  --------------------
	-- TICKETS
	SELECT * FROM #TicketsResult ORDER BY Number

	-- MATERIALS
	SELECT 
		MR.*,
		(CASE ISNULL(WSN.MatGUID, 0x0) WHEN 0x0 THEN 0 ELSE 1 END) AS HasSerialNumbers
		FROM 
		#MaterialsResult MR 
		LEFT JOIN #MaterialsWithSerialNumbers WSN ON MR.MatGuid = WSN.MatGUID
		ORDER BY MatName

	-- TICKETS PAYTYPES
	SELECT * FROM @TicketPays

	-- MATERIALS TOTALS FOR ONE TICKET
	IF(@TicketGuid != 0x0)
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
	END
	ELSE 
	BEGIN

		-- TICKETS TOTALS
		SELECT SUM(Total)			   AS TicketTotalValue,
			   SUM(DiscValue)		   AS TicketTotalDiscount,
			   SUM(AddedValue)         AS TicketTotalAdded,
			   SUM(TaxTotal)           AS TicketTotalTax,
			   SUM(NetValue)		   AS TicketTotalNet,
			   SUM(CollectedValue)     AS TicketTotalCollected,
			   SUM(LaterValue)         AS TicketTotalLater,
			   SUM(ReturnCouponAmount) AS TicketTotalReturnCoupon,
			   SUM(ReturnCardAmount)   AS TicketTotalReturnCard
		FROM #TicketsResult

		-- MATERIALS TOTALS FOR ALL TICKETS
		SELECT SUM(Value)			AS MaterialTotalValue,
			   SUM(ValueDiscount)   AS MaterialTotalDiscount,
			   SUM(ValueExtra)		AS MaterialTotalExtra,
			   SUM(NetBalance)		AS MaterialTotalNet,
			   SUM(Tax)				AS MaterialTotalTax
		FROM #MaterialsResult

		-- TICKET PAY TOTALS
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
			SUM(CASE IsBankCard WHEN 1 THEN [Value] ELSE 0 END) AS TotalBanks
		FROM 
			@TicketPays
	END
#################################################################
#END
