####################################################
################ Distributor Orders ################
CREATE PROC prcDistInitOrderOfDistributor
	@DistributorGUID uniqueidentifier    
AS
	SET NOCOUNT ON         
	------------------------------------    
	DECLARE	@OrderBtGuid 		UNIQUEIDENTIFIER,   
			@OrderTsGuid 		UNIQUEIDENTIFIER,   
			@DistStGuid 		UNIQUEIDENTIFIER,   
			@ExportTransfer 	BIT,
			@PriceType 			INT,
			@AutoGenOrder		BIT

	SELECT	@OrderBtGuid	= ISNULL( [BillTypeGuid], 0x0),     
			@OrderTsGuid	= ISNULL( [TransferTypeGuid], 0x0),
			@ExportTransfer	= ISNULL( [ExportTransfer], 0),     
			@AutoGenOrder	= ISNULL( [AutoGenOrder], 0),     
			@PriceType		= ISNULL( [PriceType], 0)     
 	FROM    
		DistOrders000 
	WHERE     
		DistGuid = @DistributorGUID     

	SELECT @DistStGuid = StoreGuid FROM Distributor000 WHERE Guid = @DistributorGuid
	---------------------------------------------
	DELETE FROM DistDeviceBi000 WHERE ParentGuid IN (SELECT Guid FROM DistDeviceBu000 WHERE DistributorGuid = @DistributorGuid)
	DELETE FROM DistDeviceBu000 WHERE DistributorGuid = @DistributorGuid
	IF @ExportTransfer = 1
	BEGIN
		DECLARE @buGuid	UNIQUEIDENTIFIER
		SELECT TOP 1 @buGuid = Guid FROM bu000 WHERE TypeGuid = @OrderTsGuid AND StoreGuid = @DistStGuid ORDER BY DATE DESC, Number DESC
		IF ISNULL(@buGuid, 0x00) <> 0x00
		BEGIN

			INSERT INTO DistDeviceBu000 (
				Guid, DistributorGuid, TypeGuid, Number, CustomerGuid, 
				Date, Notes, Total, TotalDisc, TotalItemDisc, TotalExtra, PayType, 
				FirstPay, Deleted, Posted, VisitGuid, StoreGuid, IsSync, IsOrder
			)
			SELECT 
				Guid, @DistributorGuid, TypeGuid, Number, CustGuid, 
				Date, Notes, Total, TotalDisc, ItemsDisc, TotalExtra, PayType, 
				FirstPay, 1, 1, 0x00,  StoreGuid, 0, 1
			FROM 
				bu000 
			WHERE 
				GUID = @buGuid
			INSERT INTO DistDeviceBi000 (
				Guid, ParentGuid, MatGuid, Number, Qty, BonusQty, Unity, Price, Discount, Extra, Notes, ProNumber, ProType
			)
			SELECT 
				Guid, ParentGuid, MatGuid, Number, Qty, BonusQnt, Unity, Price, Discount, Extra, Notes, 0, 0
			FROM 
				bi000
			WHERE 
				ParentGuid = @buGuid

			--- Order Bill Type
			INSERT INTO  DistDeviceBt000 (
				btGUID, DistributorGUID, SortNum, Name, Abbrev, BillType, DefPrice, bIsInput, bIsOutput, bNoEntry, bNoPost, bPrintReceipt, Type, StoreGUID
			)
			SELECT 
				GUID, @DistributorGUID, SortNum, Name, Abbrev, BillType, @PriceType, bIsInput, bIsOutput, bNoEntry, bNoPost, bPrintReceipt, 100, DefStoreGUID
			FROM bt000 
			WHERE
				GUID = @OrderTsGuid
		END
	END
	---------------------------------------------
	IF @AutoGenOrder = 1
	BEGIN
		UPDATE DistDeviceMt000 
			SET OrderQty	= od.Qty,
				OrderUnity	= od.Unity
		FROM 
			DistOrders000 AS om
			INNER JOIN DistOrdersDetails000 AS Od ON od.ParentGuid = om.Guid
			INNER JOIN DistDeviceMt000 AS mt ON mt.mtGuid = od.MatGuid AND om.DistGuid = mt.DistributorGuid
		WHERE 
			om.DistGuid = @DistributorGuid

		--- Order Bill Type
		INSERT INTO  DistDeviceBt000 (
			btGUID, DistributorGUID, SortNum, Name, Abbrev, BillType, DefPrice, bIsInput, bIsOutput, bNoEntry, bNoPost, bPrintReceipt, Type, StoreGUID
		)
		SELECT 
			GUID, @DistributorGUID, SortNum, Name, Abbrev, BillType, @PriceType, bIsInput, bIsOutput, bNoEntry, bNoPost, bPrintReceipt, 100, DefStoreGUID
		FROM bt000 
		WHERE
			Guid = @OrderBtGuid

	END

/*
EXEC prcDistInitOrderOfDistributor '06826D4F-E81B-4DF0-AC22-438A09F68C93'
*/
####################################################
CREATE PROC prcDistGenOrderTransfer
	@DistributorGuid	UNIQUEIDENTIFIER,
	@OrderBuGuid		UNIQUEIDENTIFIER
AS
	SET NOCOUNT ON
	
	DECLARE	@TsStOutGuid		UNIQUEIDENTIFIER,			
			@TsStInGuid			UNIQUEIDENTIFIER,			
			@TsTypeInGuid		UNIQUEIDENTIFIER,
			@TsTypeOutGuid		UNIQUEIDENTIFIER,
			@AutoGenTransfer	BIT,
			@OutNegative		BIT,
			@AutoPostTransfer	BIT

	SELECT 
			@TsStOutGuid		= StoreTransferGuid, 
			@TsTypeInGuid		= TransferTypeGuid, 
			@AutoGenTransfer	= AutoGenTransfer, 
			@OutNegative		= OutNegative,
			@AutoPostTransfer	= AutoPostTransfer
	FROM DistOrders000 WHERE DistGuid = @DistributorGuid
			
	SELECT @TsStInGuid = StoreGuid From Distributor000 WHERE Guid = @DistributorGuid

	IF @AutoGenTransfer = 0
		RETURN 

	SELECT @TsTypeOutGuid = OutTypeGuid FROM tt000 WHERE InTypeGuid = @TsTypeInGuid
	------------------- Get Mats Orders
	CREATE TABLE #TsMats(
		biGuid		UNIQUEIDENTIFIER,
		biQty		FLOAT,
		msQty		FLOAT,
		Qty			FLOAT,
		Notes		NVARCHAR(200) COLLATE ARABIC_CI_AI	
	)
	IF @OutNegative = 1 
	BEGIN
		INSERT INTO #TsMats( biGuid, biQty, msQty, Qty, Notes )
		SELECT 
			bi.Guid,
			bi.Qty,
			0,
			bi.Qty,
			''
		FROM 
			bi000 AS bi
		WHERE 
			ParentGuid   = @OrderBuGuid
	END
	ELSE
	BEGIN
		INSERT INTO #TsMats( biGuid, biQty, msQty, Qty, Notes )
		SELECT 
			bi.Guid,
			bi.Qty,
			ms.Qty,
			CASE	WHEN ISNULL(ms.Qty, 0) - bi.Qty >= 0 THEN bi.Qty	
					WHEN ISNULL(ms.Qty, 0) - bi.Qty < 0 THEN ms.Qty			
			END,
			CASE	WHEN ISNULL(ms.Qty, 0) - bi.Qty >= 0 THEN ''	
					WHEN ISNULL(ms.Qty, 0) - bi.Qty < 0  THEN  'ÇáßãíÉ ÇáãØáæÈÉ ãä ÇáãäÏæÈ /' + CAST(bi.Qty AS NVARCHAR(10)) + '/ ÛíÑ ãæÌæÏÉ'
			END
		FROM 
			bi000 AS bi
			INNER JOIN ms000 AS ms ON ms.MatGuid = bi.MatGuid	
		WHERE 
			ParentGuid   = @OrderBuGuid		AND		ms.StoreGuid = @TsStOutGuid 
	END

-- SELECT * FROM #TsMats
	IF NOT EXISTS (SELECT * FROM #TsMats WHERE Qty > 0)
		RETURN 
	------------------------------------------------------------------------------
	------------------------------- SAVE TRANSFERS -------------------------------
	DECLARE @OutBillGuid	UNIQUEIDENTIFIER,
			@InBillGuid		UNIQUEIDENTIFIER,
			@Number			INT
	SET @OutBillGuid = newId()
	SET @InBillGuid = newId()
	SELECT @Number = MAX(Number) FROM bu000 WHERE TypeGuid = @TsTypeOutGuid
	SET @Number = ISNULL(@Number, 0) + 1
	-------------- SAVE TS
	INSERT INTO Ts000(OutBillGuid, InBillGuid)	VALUES (@OutBillGuid, @InBillGuid)
	-------------- SAVE OutBill
	INSERT INTO bu000 (   
		Number, Cust_Name, Date, CurrencyVal, Notes, Total, PayType, TotalDisc, TotalExtra, ItemsDisc, BonusDisc, FirstPay, 
		Profits, IsPosted, Security, Vendor, SalesManPtr,	Branch, VAT, GUID, TypeGUID, CustGUID, CurrencyGUID, StoreGUID, 
		CustAccGUID, MatAccGUID, ItemsDiscAccGUID, BonusDiscAccGUID, FPayAccGUID, CostGUID, UserGUID, CheckTypeGUID, TextFld1, 
		TextFld2, TextFld3, TextFld4, RecState, ItemsExtra, ItemsExtraAccGUID, CostAccGUID, StockAccGUID, VATAccGUID,  
		BonusAccGUID, BonusContraAccGUID, IsPrinted  
	)   
 	SELECT   
		@Number, Cust_Name, Date, CurrencyVal, 'ØáÈíÉ ãäÏæÈ', Total, PayType, TotalDisc, TotalExtra, ItemsDisc, BonusDisc, FirstPay,        
		Profits, 0, Security, Vendor, SalesManPtr, Branch, VAT, @OutBillGuid, @TsTypeOutGUID, CustGUID, CurrencyGUID, @TsStOutGUID,        
		CustAccGUID, MatAccGUID, ItemsDiscAccGUID, BonusDiscAccGUID, FPayAccGUID, CostGUID, UserGUID, CheckTypeGUID, TextFld1,        
		TextFld2, TextFld3, TextFld4, RecState, ItemsExtra, ItemsExtraAccGUID, CostAccGUID, StockAccGUID, VATAccGUID, 
		BonusAccGUID, BonusContraAccGUID, 0
	FROM bu000 WHERE Guid = @OrderBuGuid

	INSERT INTO Bi000 (   
		Number, Qty, [Order], OrderQnt, Unity, Price, BonusQnt, Discount, BonusDisc, Extra, CurrencyVal, 
		Notes, Profits, Num1, Num2, Qty2, Qty3, ClassPtr, ExpireDate, ProductionDate, Length, Width, Height,        
		GUID, VAT, VATRatio, ParentGUID, MatGUID, CurrencyGUID, StoreGUID, CostGUID, SOType, SOGuid       
	)   
	SELECT   
		Number,	mt.Qty, [Order], OrderQnt, Unity, Price, BonusQnt, Discount, BonusDisc, Extra, CurrencyVal,        
		mt.Notes, Profits, Num1, Num2, Qty2, Qty3, ClassPtr, ExpireDate, ProductionDate, Length, Width, Height,        
		newId(), VAT, VATRatio, @OutBillGuid, bi.MatGUID, CurrencyGUID, @TsStOutGUID, CostGUID, SOType, SOGuid       
	FROM 
		bi000 AS bi
		INNER JOIN #TsMats AS mt ON mt.biGuid = bi.Guid
	WHERE 
		ParentGuid  = @OrderBuGuid	AND mt.Qty > 0
	-------------- SAVE InBill
	INSERT INTO bu000 (   
		Number, Cust_Name, Date, CurrencyVal, Notes, Total, PayType, TotalDisc, TotalExtra, ItemsDisc, BonusDisc, FirstPay, 
		Profits, IsPosted, Security, Vendor, SalesManPtr,	Branch, VAT, GUID, TypeGUID, CustGUID, CurrencyGUID, StoreGUID, 
		CustAccGUID, MatAccGUID, ItemsDiscAccGUID, BonusDiscAccGUID, FPayAccGUID, CostGUID, UserGUID, CheckTypeGUID, TextFld1, 
		TextFld2, TextFld3, TextFld4, RecState, ItemsExtra, ItemsExtraAccGUID, CostAccGUID, StockAccGUID, VATAccGUID,  
		BonusAccGUID, BonusContraAccGUID, IsPrinted  
	)   
 	SELECT   
		@Number, Cust_Name, Date, CurrencyVal, 'ØáÈíÉ ãäÏæÈ', Total, PayType, TotalDisc, TotalExtra, ItemsDisc, BonusDisc, FirstPay,        
		Profits, 0, Security, Vendor, SalesManPtr, Branch, VAT, @InBillGuid, @TsTypeInGUID, CustGUID, CurrencyGUID, @TsStInGUID,        
		CustAccGUID, MatAccGUID, ItemsDiscAccGUID, BonusDiscAccGUID, FPayAccGUID, CostGUID, UserGUID, CheckTypeGUID, TextFld1,        
		TextFld2, TextFld3, TextFld4, RecState, ItemsExtra, ItemsExtraAccGUID, CostAccGUID, StockAccGUID, VATAccGUID, 
		BonusAccGUID, BonusContraAccGUID, 0
	FROM bu000 WHERE Guid = @OrderBuGuid

	INSERT INTO Bi000 (   
		Number, Qty, [Order], OrderQnt, Unity, Price, BonusQnt, Discount, BonusDisc, Extra, CurrencyVal, 
		Notes, Profits, Num1, Num2, Qty2, Qty3, ClassPtr, ExpireDate, ProductionDate, Length, Width, Height,        
		GUID, VAT, VATRatio, ParentGUID, MatGUID, CurrencyGUID, StoreGUID, CostGUID, SOType, SOGuid       
	)   
	SELECT   
		Number,	mt.Qty, [Order], OrderQnt, Unity, Price, BonusQnt, Discount, BonusDisc, Extra, CurrencyVal,        
		mt.Notes, Profits, Num1, Num2, Qty2, Qty3, ClassPtr, ExpireDate, ProductionDate, Length, Width, Height,        
		newId(), VAT, VATRatio, @InBillGuid, bi.MatGUID, CurrencyGUID, @TsStInGUID, CostGUID, SOType, SOGuid       
	FROM 
		bi000 AS bi
		INNER JOIN #TsMats AS mt ON mt.biGuid = bi.Guid
	WHERE 
		ParentGuid  = @OrderBuGuid	AND mt.Qty > 0
	------------------------------------------------------------------------------
	---------------- Post Transfer
	IF @AutoPostTransfer = 1
	BEGIN
		ALTER TABLE ms000 DISABLE TRIGGER trg_ms000_CheckBalance 
		UPDATE bu000 SET IsPosted = 1 WHERE Guid = @OutBillGuid
		UPDATE bu000 SET IsPosted = 1 WHERE Guid = @InBillGuid
		ALTER TABLE ms000 ENABLE TRIGGER trg_ms000_CheckBalance
	END

	------------------------------------------------------------------------------
/*
EXEC prcDistGenOrderTransfer '06826D4F-E81B-4DF0-AC22-438A09F68C93', '3EFDBD8C-76CC-421D-8E17-6F39BA845865'
*/
####################################################
#END