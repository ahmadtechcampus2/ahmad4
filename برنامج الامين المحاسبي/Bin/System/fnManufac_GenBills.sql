#########################################################
CREATE PROC prcManufac_GenBills
	@ManufacGUID UNIQUEIDENTIFIER
AS

/*
this procedure
	- generate bills for a given manufacturing guid
	- deletes any old bill found for the given manufacturing guid
*/

	SET NOCOUNT ON

	DECLARE
		@OutBillGUID UNIQUEIDENTIFIER,
		@OutBillTypeGUID UNIQUEIDENTIFIER,
		@InBillGUID UNIQUEIDENTIFIER,
		@InBillTypeGUID UNIQUEIDENTIFIER,
		@TotalExtra FLOAT

	-- output
	SELECT
		@OutBillGUID = NEWID(),
		@InBillGUID = NEWID(),
		@OutBillTypeGUID = (SELECT GUID FROM bt000 WHERE Type = 2 AND SortNum = 6),
		@InBillTypeGUID = (SELECT GUID FROM bt000 WHERE Type = 2 AND SortNum = 5),
		@TotalExtra = (SELECT SUM(Extra) FROM mx000 WHERE ParentGUID = @ManufacGUID)

	INSERT INTO bu000(
			Number, Cust_Name, Date, CurrencyVal, Notes, Total, PayType, TotalDisc, TotalExtra, ItemsDisc, BonusDisc, FirstPay, Profits, 
			IsPosted, Security, Vendor, SalesManPtr, Branch, VAT, GUID, TypeGUID, CustGUID, CurrencyGUID, StoreGUID, CustAccGUID, 
			MatAccGUID, ItemsDiscAccGUID, BonusDiscAccGUID, FPayAccGUID, CostGUID, UserGUID, CheckTypeGUID)
		SELECT
			Number,
			'',
			OutDate,
			CurrencyVal,
			Notes,
			TotalPrice,
			1, -- payType
			0, -- totalDisc
			@TotalExtra,
			0, -- itemsDisc
			0, -- bonusDisc
			0, -- firstPay
			0, -- profits
			0, -- isPosted
			Security,
			0, -- vendor
			0, -- salesManPtr
			BranchGUID,
			0, -- vat
			@OutBillGUID,
			@OutBillTypeGUID,
			ISNULL((SELECT GUID FROM cu000 WHERE AccountGUID = OutTempAccGUID), 0x0), -- CustGUID
			CurrencyGUID,
			OutStoreGUID,	
			OutTempAccGUID,
			OutAccountGUID,
			0x0, -- ItemsDiscAccGUID
			0x0, -- bonusDiscAccGUID
			0x0, -- FPayAccGUID
			OutCostGUID,
			0x0, -- userGUID
			0x0 -- CheckTypeGUID
		FROM mn000
		WHERE GUID = @ManufacGUID


		UNION

		SELECT
			Number,
			'',
			InDate,
			CurrencyVal,
			Notes,
			TotalPrice,
			1, -- payType
			0,
			@TotalExtra,
			0, -- itemsDisc
			0, -- bonusDisc
			0, -- firstPay
			0, -- profits
			0, -- isPosted
			Security,
			0, -- vendor
			0, -- salesManPtr
			BranchGUID,
			0, -- vat
			@InBillGUID,
			@InBillTypeGUID,
			ISNULL((SELECT GUID FROM cu000 WHERE AccountGUID = InTempAccGUID), 0x0), -- CustGUID
			CurrencyGUID,
			InStoreGUID,	
			InTempAccGUID,
			InAccountGUID,
			0x0, -- ItemsDiscAccGUID
			0x0, -- bonusDiscAccGUID
			0x0, -- FPayAccGUID
			InCostGUID,
			0x0, -- userGUID
			0x0 -- CheckTypeGUID
		FROM mn000
		WHERE GUID = @ManufacGUID

	-- insert bi
	INSERT INTO bi000(
			Number, Qty, [Order], OrderQnt, Unity, Price, BonusQnt, Discount, BonusDisc, Extra, CurrencyVal, Notes, Profits, 
			Num1, Num2, Qty2, Qty3, ClassPtr, ExpireDate, ProductionDate, Length, Width, Height, VAT, VATRatio, 
			ParentGUID, MatGUID, CurrencyGUID, StoreGUID, CostGUID)
		SELECT
			mi.Number,
			mi.Qty,
			0, -- order
			0, -- order qnt
			mi.Unity,
			CASE PriceType WHEN 0 THEN mt.LastPrice WHEN 1 THEN mt.AvgPrice WHEN 2 THEN mt.MaxPrice ELSE Price END,
			0, -- bonusQnt
			0, -- discount
			0, -- bonusDisc
			0, -- extra
			mi.CurrencyVal,
			mi.Notes,
			0, -- profits,
			0, -- num1
			0, -- num2
			mi.Qty2,
			mi.Qty3,
			mi.Class,
			mi.[ExpireDate],
			mi.ProductionDate,
			mi.Length,
			mi.Width,
			mi.Height,
			0,
			0,
			@OutBillGUID,
			mi.MatGUID,
			mi.CurrencyGUID,
			mi.StoreGUID,
			mi.CostGUID
		FROM mi000 AS mi INNER JOIN mt000 mt ON mi.MatGUID = mt.GUID
		WHERE mi.ParentGUID = @ManufacGUID AND mi.type = 1

		UNION

		SELECT
			Number,
			Qty,
			0, -- order
			0, -- order qnt
			Unity,
			ISNULL((SELECT TotalPrice FROM mn000 WHERE GUID = @ManufacGUID), 0) * Percentage / 100, -- PriceType
			0, -- bonusQnt
			0, -- discount
			0, -- bonusDisc
			0, -- extra
			CurrencyVal,
			Notes,
			0, -- profits,
			0, -- num1
			0, -- num2
			Qty2,
			Qty3,
			Class,
			[ExpireDate],
			ProductionDate,
			Length,
			Width,
			Height,
			0,
			0,
			@InBillGUID,
			MatGUID,
			CurrencyGUID,
			StoreGUID,
			CostGUID
		FROM mi000
		WHERE ParentGUID = @ManufacGUID AND type = 0

	INSERT INTO di000(
			Number, Discount, Extra, CurrencyVal, Notes, Flag, ClassPtr, 
			ParentGUID, AccountGUID, CurrencyGUID, CostGUID, ContraAccGUID)
		SELECT
			Number,
			Discount,
			Extra,
			CurrencyVal,
			Notes,
			Flag,
			Class,
			@OutBillGUID,
			AccountGUID,
			CurrencyGUID,
			CostGUID,
			ContraAccGUID
		FROM mx000
		WHERE ParentGUID = @ManufacGUID

	-- post bills:
	UPDATE bu000 SET IsPosted = 1 WHERE GUID IN (@OutBillGUID, @InBillGUID)

	-- generate entry
	EXEC prcBill_GenEntry @OutBillGUID
	EXEC prcBill_GenEntry @InBillGUID
 
 #########################################################