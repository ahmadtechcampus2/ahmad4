################################################################################
CREATE PROCEDURE prcPOSSD_Shift_GenerateTicketsBill
	@billTypeID  UNIQUEIDENTIFIER,
	@shiftGuid   UNIQUEIDENTIFIER,
	@TicketsType INT = 0, -- 0: Sales, 1: Purchases, 2: ReturnedSales, 3: Returned Purchases 
	@PostBill	 INT = 1, -- 0: not post, 1: post
	@returnValue INT = 1 OUTPUT
AS
BEGIN 
DECLARE @storeGuid			UNIQUEIDENTIFIER,
		@shiftCode			INT,
		@userGuid			UNIQUEIDENTIFIER,
		@posName			NVARCHAR(250),
		@shiftControl		UNIQUEIDENTIFIER,
		@billID				UNIQUEIDENTIFIER,
		@billNumber			INT,
		@language			INT = [dbo].[fnConnections_getLanguage](), 
		@CurrencyValue		FLOAT,
		@CurrencyID			UNIQUEIDENTIFIER,
		@billAccountID		UNIQUEIDENTIFIER,
		@discountAccountID	UNIQUEIDENTIFIER,
		@extraAccountID		UNIQUEIDENTIFIER,
		@vatSystem			INT,
		@autoPost			BIT,
		@autoEntry			BIT,
		@snGuid				UNIQUEIDENTIFIER,
		@costID				UNIQUEIDENTIFIER,
		@customerName		NVARCHAR(250),
		@deferredAccount	UNIQUEIDENTIFIER,
		@userNumber			FLOAT,
		@billItemsTotal		FLOAT,
		@billItemsDiscount  FLOAT,
		@billItemsAdded		FLOAT,
		@billItemsTax		FLOAT,
		@isVatTax			INT,-- 0:NoTax, 1:VAT, 2:TTC
		@profits			FLOAT,
		@btaxBeforeExtra	BIT = (SELECT taxBeforeExtra	FROM bt000 WHERE GUID = @billTypeID),
		@btaxBeforeDiscount BIT = (SELECT taxBeforeDiscount FROM bt000 WHERE GUID = @billTypeID),
		@ShiftNumber		INT,
		@billItemID			UNIQUEIDENTIFIER,
	    @billNote			NVARCHAR(250),
		@employeeName		NVARCHAR(250),
		@expirationDate		DATETIME = '1/1/1980',
		@productionDate		DATETIME = '1/1/1980',
		@entryNum			INT,
		@Result				INT,
		@count				INT 	

		DECLARE @CustomerGuid UNIQUEIDENTIFIER = 0x0
		DECLARE @IsGCCTaxSystemEnable BIT = ISNULL((SELECT Value FROM op000 WHERE Name = 'AmnCfg_EnableGCCTaxSystem'), 0)
		IF(@IsGCCTaxSystemEnable = 1)
		BEGIN
			SET @CustomerGuid = (SELECT CustAccGuid FROM bt000 WHERE [GUID] = @billTypeID)
		END

------------------------------------------------------------------
	SET @customerName = ''
	SET @Result = 0
------------------------------------------------------------------

	SELECT @currencyID = ISNULL([Value], 0x0) 
	FROM [OP000] 
	WHERE [Name] = 'AmnCfg_DefaultCurrency'
			
	SELECT @currencyValue = ISNULL([CurrencyVal], 0) 
	FROM [MY000] 
	WHERE [Guid] = @currencyID

------------------------------------------------------------------

	SELECT  
		@billAccountID	   = ISNULL([DefBillAccGUID], 0x0),
        @discountAccountID = ISNULL([DefDiscAccGuid], 0x0),
        @extraAccountID	   = ISNULL([DefExtraAccGuid], 0x0),
        @vatSystem		   = ISNULL([VATSystem], 0),
        @autoPost		   = ISNULL([bAutoPost], 0),
        @autoEntry		   = ISNULL([bAutoEntry], 0),
        @costID			   = ISNULL(DefCostGUID, 0x0),
		@isVatTax		   = CASE VATSystem WHEN 0 THEN 0 WHEN 1 THEN 1 ELSE 2 END 
	FROM 
		[BT000]
	WHERE 
		[Guid] = @billTypeID

------------------------------------------------------------------

	SET @userGuid = [dbo].[fnGetCurrentUserGUID]()
	SELECT @userNumber = NUMBER FROM [Us000] WHERE [Guid] = @UserGuid

------------------------------------------------------------------


	SELECT @billNumber = ISNULL(MAX([Number]), 0) + 1
	FROM [BU000]
	WHERE [TypeGuid] = @BillTypeID 
	SET @BillNumber = ISNULL(@BillNumber, 1)
	SET @BillID = NEWID()

	SELECT @deferredAccount = ISNULL([DefCashAccGUID], 0x0)
	FROM [BT000]
	WHERE [Guid] = @billTypeID

	
	SELECT 	 
		@storeGuid = bt.DefStoreGUID, 
		@posName = CAST(posCard.Code AS NVARCHAR(250)) + '-' + CASE @language WHEN 0 THEN posCard.Name ELSE CASE posCard.LatinName WHEN '' THEN posCard.Name ELSE posCard.LatinName END END,
		@shiftcontrol= posCard.ShiftControlGUID, 
		@shiftCode = posShift.Code,
		@shiftNumber = posShift.Number,
		@employeeName = CASE @language WHEN 0 THEN ISNULL(posEmployee.Name, '') ELSE ISNULL(posEmployee.LatinName, '') END
	FROM 
		bt000 bt 
		INNER JOIN POSSDStation000 posCard  ON (CASE @TicketsType WHEN 2 THEN posCard.SaleReturnBillTypeGUID ELSE posCard.SaleBillTypeGUID END) = bt.[GUID]
		INNER JOIN POSSDShift000 posShift ON posShift.StationGUID = posCard.[GUID]
		INNER JOIN POSSDEmployee000 posEmployee ON posShift.EmployeeGUID = posEmployee.[GUID]
	WHERE 
		posShift.[GUID] = @shiftGuid

	
------------------------------------------------------------------

	DECLARE @TicketItemCalcDiscAndExtra TABLE ( ItemGuid			UNIQUEIDENTIFIER,
												TicketGuid			UNIQUEIDENTIFIER,
												ValueToDiscount		FLOAT,
												ValueToAdd			FLOAT,
												ValueAfterCalc		FLOAT,
												totalDiscount		FLOAT,
												ItemDiscount		FLOAT,
												Discount			FLOAT,
												totalAddition		FLOAT,
												ItemAddition		FLOAT,
												Addition			FLOAT )
	INSERT INTO @TicketItemCalcDiscAndExtra EXEC prcPOSSD_Ticket_GetTicketItemsCalcDiscAndExtra @TicketsType
 
------------------------------------------------------------------
	SELECT
		TItems.MatGuid													AS MatGuid,
		TItems.[GUID]													AS TicketItemGuid,
		TItems.Qty														AS Quantity,
		TItems.Price													AS Price,
		TItems.Value													AS Value,
		CASE @IsGCCTaxSystemEnable WHEN 1 THEN 0 ELSE TItems.Tax END	AS Tax,
		TICDE.ItemDiscount												AS ItemDiscount,
		TICDE.totalDiscount												AS TotalDiscount,
		TICDE.Discount													AS ValueDiscount,
		TICDE.ItemAddition												AS ItemExtra,
		TICDE.totalAddition												AS TotalExtra,
		TICDE.Addition													AS ValueExtra,
		CASE TItems.UnitType WHEN 0 THEN MT.mtUnity
						     WHEN 1 THEN MT.mtUnit2
						     WHEN 2 THEN MT.mtUnit3 END					AS Unit,
		CASE TItems.UnitType WHEN 1 THEN ISNULL([MT].mtUnit2Fact, 1)
							 WHEN 2 THEN ISNULL([MT].mtUnit3Fact, 1)
							 ELSE 1 END 								AS UnitFactor,
		 TItems.UnitType+1												AS UnitIndex,
		0.0																AS VatRatio,
		MT.mtName														AS mtName,
		MT.mtCode														AS mtCode,
		MT.mtVat														AS mtVat,
		ISNULL(SM.CostCenterGUID, 0x0)									AS CostCenterGUID
	INTO 
		#TicketItemResult
	FROM	   
		POSSDTicketItem000 TItems
	    INNER JOIN POSSDTicket000 Ticket			 ON Ticket.[GUID]		= TItems.TicketGUID
	    LEFT  JOIN @TicketItemCalcDiscAndExtra TICDE ON TItems.[GUID]       = TICDE.ItemGuid
	    LEFT  JOIN vwmt MT						     ON TItems.MatGUID      = MT.mtGUID
	    LEFT  JOIN POSSDSalesman000 SM				 ON Ticket.SalesmanGUID = SM.[GUID]
	WHERE 
		Ticket.[State]   = 0 
	AND Ticket.ShiftGUID = @shiftGuid 
	AND Ticket.[Type]    = @TicketsType



	SELECT 
		MatGuid														AS MatGuid,
		SUM(Quantity)												AS Quantity,
		SUM(Price)													AS Price,
		SUM(Value)													AS Value,
		CASE @IsGCCTaxSystemEnable WHEN 1 THEN 0 ELSE SUM(Tax)  END AS Tax,
		SUM(ItemDiscount)											AS ItemDiscount,
		SUM(TotalDiscount)											AS TotalDiscount,
		SUM(ValueDiscount)											AS ValueDiscount,
		SUM(ItemExtra)												AS ItemExtra,
		SUM(TotalExtra)												AS TotalExtra,
		SUM(ValueExtra)												AS ValueExtra,
		Unit														AS Unit,
		UnitFactor													AS UnitFactor,
		UnitIndex													AS UnitIndex,
		0.0															AS VatRatio,
		ISNULL(CostCenterGUID, 0x0)									AS CostGUID,
		NEWID()														AS BiGuid
	INTO 
		#MaterialsResult
	FROM 
		#TicketItemResult
	GROUP BY 
		MatGuid,
		mtName,
		mtCode,
		Unit,
		UnitFactor,
		UnitIndex,
		mtVat,
		CostCenterGUID


	SELECT 
		@billItemsTotal    = SUM(MT.Price),
		@billItemsDiscount = SUM(MT.ValueDiscount),
		@billItemsAdded    = SUM(MT.ValueExtra),
		@billItemsTax      = CASE @IsGCCTaxSystemEnable WHEN 1 THEN 0 ELSE SUM(MT.Tax) END
	FROM 
		#MaterialsResult MT
	
	SET @profits = @billItemsTotal - @billItemsDiscount + @billItemsAdded

------------------------------------------------------------------

	SET @billNote = [dbo].[fnStrings_get]('POS\BILLGENERATED', @language)+' '+ CONVERT(nvarchar(255), @shiftCode)
				   +[dbo].[fnStrings_get]('POS\TOPOSCARD', @language) +': '+@posName+'. '
				   +[dbo].[fnStrings_get]('POS\SHIFTEMPLOYEE', @language)+': '+@employeeName
		
	IF EXISTS(SELECT * FROM #MaterialsResult)
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
           @CustomerGuid,--CustGUID
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

------------------------------------------------------------------
	
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
	(SELECT			ROW_NUMBER() OVER (ORDER BY (SELECT NULL)),
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
					MT.BiGuid,--@BillItemID,
					CASE @IsGCCTaxSystemEnable WHEN 1 THEN 0 ELSE MT.Tax END,
					CASE @IsGCCTaxSystemEnable WHEN 1 THEN 0 ELSE
					((MT.Tax * 100) / CASE (MT.Value 
										- 
										CASE @btaxBeforeDiscount WHEN 0 THEN Mt.ValueDiscount ELSE 0 END
										+
										CASE @btaxBeforeExtra WHEN 0 THEN  MT.ValueExtra ELSE 0 END) WHEN 0 THEN 1 ELSE (MT.Value 
										- 
										CASE @btaxBeforeDiscount WHEN 0 THEN Mt.ValueDiscount ELSE 0 END
										+
										CASE @btaxBeforeExtra WHEN 0 THEN  MT.ValueExtra ELSE 0 END) END
										) END, -- VATRatio
					@billID, --ParentGUID
					ISNULL(MT.MatGuid, 0x0)AS [MatID],-- AS [MatID],
					@currencyID, --CurrencyGUID
					@StoreGuid,--StoreGUID
					MT.CostGUID,-- [SalesmanID],
					0, --SOType
					0x0,--[SpecialOfferID],
					0 --Count
	FROM  #MaterialsResult MT 
	GROUP BY MT.MatGuid, MT.UnitIndex,Mt.UnitFactor, Mt.Quantity,MT.Value,MT.ValueDiscount, MT.ValueExtra, MT.Tax,Mt.VatRatio, MT.CostGUID, MT.BiGuid
		)

------------------------------------------------------------------
	
	INSERT INTO BillRel000 ([GUID], [Type], [BillGUID], [ParentGUID], [ParentNumber])
	VALUES(NEWID(), 1, @BillID, @shiftGuid, @ShiftNumber) 
	
	--------------------INSERT SERIAL NUMBER----------------

	DECLARE @ExistSerialNumbers INT = 0

	SELECT 
		@ExistSerialNumbers = COUNT(*)
	FROM 
		POSSDTicketItemSerialNumbers000 SN 
	    INNER JOIN POSSDTicketItem000 TI ON TI.[GUID] = SN.TicketItemGUID
	    INNER JOIN POSSDTicket000 T      ON T.[GUID]  = TI.TicketGUID
	    INNER JOIN POSSDShift000 S       ON S.[GUID]  = T.ShiftGUID
	WHERE 
		S.[GUID]  = @shiftGuid
	AND T.[State] = 0
	AND T.[Type]  = @TicketsType

	IF(@ExistSerialNumbers > 0)
	BEGIN

		SELECT 
			SN.*,
			NEWID()    AS ParentGuid,
			TI.MatGUID AS MatGUID
		INTO #SNTemp
		FROM 
			POSSDTicketItemSerialNumbers000 SN 
			INNER JOIN POSSDTicketItem000 TI ON TI.[GUID] = SN.TicketItemGUID
			INNER JOIN POSSDTicket000 T      ON T.[GUID]  = TI.TicketGUID
			INNER JOIN POSSDShift000 S       ON S.[GUID]  = T.ShiftGUID
			
		WHERE 
			S.[GUID]  = @shiftGuid
		AND T.[State] = 0
		AND T.[Type]  = @TicketsType


		INSERT INTO snc000 ([GUID], [SN], [MatGUID], [Qty])
		SELECT 
			SN.ParentGuid, 
			SN.SN, 
			SN.MatGUID, 
			@PostBill
		FROM 
			#SNTemp SN
			LEFT JOIN  snc000 SNC ON SNC.MatGUID = SN.MatGUID AND SNC.SN = SN.SN 
		WHERE 
			SNC.[GUID] IS NULL


		UPDATE 
			#SNTemp 
		SET 
			ParentGuid =  snc.[GUID] 
		FROM 
			#SNTemp st 
			INNER JOIN snc000 snc ON st.SN = snc.SN AND st.MatGUID = snc.MatGUID
	


		INSERT INTO snt000 ([GUID], Item, biGUID, stGUID, ParentGUID, Notes, buGuid)
		SELECT 
			NEWID(),
			SN.Number,
			MR.BiGuid,
			@StoreGuid,
			SN.ParentGuid,
			'',
			@billID
		FROM 
			#TicketItemResult TIR 
			INNER JOIN #MaterialsResult MR ON TIR.MatGuid            = MR.MatGuid 
											  AND TIR.Unit           = MR.Unit
											  AND TIR.UnitFactor     = MR.UnitFactor
											  AND TIR.UnitIndex      = MR.UnitIndex
											  AND TIR.CostCenterGUID = MR.CostGUID
			INNER JOIN #SNTemp SN ON SN.TicketItemGUID = TIR.TicketItemGuid
	END

	--------------------GenerateEntry-----------------------
	SELECT @entryNum = ISNULL(MAX(number), 0) + 1 FROM ce000	
	
	IF (@autoPost = 1 AND @PostBill = 1)
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

		EXECUTE [prcBill_GenEntry] @billID, @entryNum, 0, 0, 0, 0, 1, 0, 0, 1

		EXEC prcEnableTriggers 'ce000'
		EXEC prcEnableTriggers 'en000'
		EXEC prcEnableTriggers 'er000'

	END 
	COMMIT
	END
	
	SELECT @count = COUNT(*)  FROM BillRel000 WHERE BillGUID = @BillID
    SELECT @ResultMaterial = COUNT(*) FROM #MaterialsResult

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
#END
