###########################################################################
CREATE FUNCTION fnGetDefaultAccountsByEntryGUID
( 
	@EntryGUID UNIQUEIDENTIFIER
)
RETURNS 
@table TABLE
(
	DefaultMatsAccount UNIQUEIDENTIFIER,
	DefaultDiscountsAccount UNIQUEIDENTIFIER,
	DefaultAdditionsAccount UNIQUEIDENTIFIER,
	DefaultVATAccount UNIQUEIDENTIFIER,
	DefaultCostAccount UNIQUEIDENTIFIER,
	DefaultStockAccount UNIQUEIDENTIFIER,
	DefaultBonusAccount UNIQUEIDENTIFIER,
	DefaultBonusContraAccount UNIQUEIDENTIFIER,
	DefaultCashesAccount UNIQUEIDENTIFIER
) 
AS 
BEGIN 

	-- «·Õ”«»«  «·«› —«÷Ì… „‰ ‰«›–… „“Ìœ
	DECLARE @FirstLevelAccounts TABLE
	(
		DefaultMatsAccount UNIQUEIDENTIFIER,
		DefaultDiscountsAccount UNIQUEIDENTIFIER,
		DefaultExtrasAccount UNIQUEIDENTIFIER,
		DefaultVATAccount UNIQUEIDENTIFIER,
		DefaultCostAccount UNIQUEIDENTIFIER,
		DefaultStockAccount UNIQUEIDENTIFIER,
		DefaultBonusAccount UNIQUEIDENTIFIER,
		DefaultBonusContraAccount UNIQUEIDENTIFIER,
		DefaultCashesAccount UNIQUEIDENTIFIER
	)
	-- «·Õ”«»«  «·«› —«÷Ì… ›Ì ≈œ«—… «·„” Œœ„Ì‰ - Õ”«»«  «·›Ê« Ì—
	DECLARE @SecondLevelAccounts TABLE
	(
		DefaultMatsAccount UNIQUEIDENTIFIER,
		DefaultDiscountsAccount UNIQUEIDENTIFIER,
		DefaultExtrasAccount UNIQUEIDENTIFIER,
		DefaultVATAccount UNIQUEIDENTIFIER,
		DefaultCostAccount UNIQUEIDENTIFIER,
		DefaultStockAccount UNIQUEIDENTIFIER,
		DefaultBonusAccount UNIQUEIDENTIFIER,
		DefaultBonusContraAccount UNIQUEIDENTIFIER,
		DefaultCashesAccount UNIQUEIDENTIFIER
	)
	-- «·Õ”«»«  «·«› —«÷Ì… ›Ì »ÿ«ﬁ… „«œ…
	DECLARE @ThirdLevelAccounts TABLE
	(
		DefaultMatsAccount UNIQUEIDENTIFIER,
		DefaultDiscountsAccount UNIQUEIDENTIFIER,
		DefaultExtrasAccount UNIQUEIDENTIFIER,
		DefaultVATAccount UNIQUEIDENTIFIER,
		DefaultCostAccount UNIQUEIDENTIFIER,
		DefaultStockAccount UNIQUEIDENTIFIER,
		DefaultBonusAccount UNIQUEIDENTIFIER,
		DefaultBonusContraAccount UNIQUEIDENTIFIER,
		DefaultCashesAccount UNIQUEIDENTIFIER
	)
	-- «·Õ”«»«  «·«› —«÷Ì… ›Ì »ÿ«ﬁ… „Ã„Ê⁄…
	DECLARE @FourthLevelAccounts TABLE
	(
		DefaultMatsAccount UNIQUEIDENTIFIER,
		DefaultDiscountsAccount UNIQUEIDENTIFIER,
		DefaultExtrasAccount UNIQUEIDENTIFIER,
		DefaultVATAccount UNIQUEIDENTIFIER,
		DefaultCostAccount UNIQUEIDENTIFIER,
		DefaultStockAccount UNIQUEIDENTIFIER,
		DefaultBonusAccount UNIQUEIDENTIFIER,
		DefaultBonusContraAccount UNIQUEIDENTIFIER,
		DefaultCashesAccount UNIQUEIDENTIFIER
	)
	-- «·Õ”«»«  «·«› —«÷Ì… ›Ì ‰„ÿ «·›« Ê—…
	DECLARE @FifthLevelAccounts TABLE
	(
		DefaultMatsAccount UNIQUEIDENTIFIER,
		DefaultDiscountsAccount UNIQUEIDENTIFIER,
		DefaultExtrasAccount UNIQUEIDENTIFIER,
		DefaultVATAccount UNIQUEIDENTIFIER,
		DefaultCostAccount UNIQUEIDENTIFIER,
		DefaultStockAccount UNIQUEIDENTIFIER,
		DefaultBonusAccount UNIQUEIDENTIFIER,
		DefaultBonusContraAccount UNIQUEIDENTIFIER,
		DefaultCashesAccount UNIQUEIDENTIFIER
	)
---------------------------------------------------------------------------------
---------------------------------------------------------------------------------
	INSERT INTO @FirstLevelAccounts
	SELECT TOP 1 
		bu.buMatAcc,
		bu.buItemsDiscAcc,
		bu.buItemsExtraAccGUID,
		bu.buVATAccGUID,
		bu.buCostAccGUID,
		bu.buStockAccGUID,
		bu.buBonusAccGUID ,
		bu.buBonusContraAccGUID,
		0x0
	FROM
		vwbu AS bu
		INNER JOIN er000 AS er ON er.ParentGUID = bu.buGUID 
		INNER JOIN vwceen AS ce ON er.EntryGUID = ce.ceGUID
	WHERE 
		ce.ceGUID = @EntryGUID
	--------------------------------
	INSERT INTO @SecondLevelAccounts
	SELECT TOP 1 
		ma.maMatAccGUID,
		ma.maDiscAccGUID,
		ma.maExtraAccGUID,
		ma.maVATAccGUID,
		ma.maCostAccGUID,
		ma.maStoreAccGUID,
		ma.maBonusAccGUID ,
		ma.maBonusContraAccGUID,
		ma.maCashAccGUID
	FROM
		vwMa AS ma
		INNER JOIN vwUs AS us ON ma.maObjGUID = us.usGUID 
		INNER JOIN vwbu AS bu ON bu.buType = ma.maBillTypeGUID
		INNER JOIN er000 AS er ON er.ParentGUID = bu.buGUID 
		INNER JOIN vwceen AS ce ON er.EntryGUID = ce.ceGUID
	WHERE 
		us.usGUID = dbo.fnGetCurrentUserGUID()
		AND 
		ce.ceGUID = @EntryGUID
	-------------------------------
	INSERT INTO @ThirdLevelAccounts
	SELECT TOP 1 
		ma.maMatAccGUID,
		ma.maDiscAccGUID,
		ma.maExtraAccGUID,
		ma.maVATAccGUID,
		ma.maCostAccGUID,
		ma.maStoreAccGUID,
		ma.maBonusAccGUID ,
		ma.maBonusContraAccGUID,
		ma.maCashAccGUID
	FROM
		vwMa AS ma
		INNER JOIN vwMt AS mt ON ma.maObjGUID = mt.mtGUID 
		INNER JOIN vwbu AS bu ON bu.buType = ma.maBillTypeGUID
		INNER JOIN er000 AS er ON er.ParentGUID = bu.buGUID 
		INNER JOIN vwceen AS ce ON er.EntryGUID = ce.ceGUID
	WHERE 
		ce.ceGUID = @EntryGUID
		AND 
		ma.maType = 1
	--------------------------------
	INSERT INTO @FourthLevelAccounts
	SELECT TOP 1 
		ma.maMatAccGUID,
		ma.maDiscAccGUID,
		ma.maExtraAccGUID,
		ma.maVATAccGUID,
		ma.maCostAccGUID,
		ma.maStoreAccGUID,
		ma.maBonusAccGUID ,
		ma.maBonusContraAccGUID,
		ma.maCashAccGUID
	FROM
		vwMa AS ma
		INNER JOIN vwbu AS bu ON bu.buType = ma.maBillTypeGUID
		INNER JOIN er000 AS er ON er.ParentGUID = bu.buGUID 
		INNER JOIN vwceen AS ce ON er.EntryGUID = ce.ceGUID
	WHERE 
		ce.ceGUID = @EntryGUID
		AND 
		ma.maType = 2
	-------------------------------
	INSERT INTO @FifthLevelAccounts
	SELECT TOP 1
		bt.btDefBillAcc,
		bt.btDefDiscAcc,
		bt.btDefExtraAcc,
		bt.btDefVATAcc,
		bt.btDefCostAcc,
		bt.btDefStockAcc,
		bt.btDefBonusAccGuid ,
		bt.btDefBonusContraAccGUID,
		bt.btDefCashAcc
	FROM
		vwExtended_bi AS bi 
		INNER JOIN vwbt AS bt ON bi.buType = bt.btGUID 
		INNER JOIN er000 AS er ON er.ParentGUID = bi.buGUID 
		INNER JOIN vwceen AS ce ON er.EntryGUID = ce.ceGUID
	WHERE 
		ce.ceGUID = @EntryGUID
---------------------------------------------------------------------------------
---------------------------------------------------------------------------------
	-- Fill the result table
	INSERT INTO @table
	SELECT
		CASE WHEN (SELECT IsNull(DefaultMatsAccount, 0x0) FROM @FirstLevelAccounts) <> 0x0 THEN (SELECT DefaultMatsAccount FROM @FirstLevelAccounts)
			ELSE (CASE 
					WHEN (SELECT IsNull(DefaultMatsAccount, 0x0) FROM @SecondLevelAccounts) <> 0x0 THEN (SELECT DefaultMatsAccount FROM @SecondLevelAccounts)
					ELSE (CASE 
							WHEN (SELECT IsNull(DefaultMatsAccount, 0x0) FROM @ThirdLevelAccounts) <> 0x0 THEN (SELECT DefaultMatsAccount FROM @ThirdLevelAccounts)
							ELSE (CASE 
									WHEN (SELECT IsNull(DefaultMatsAccount, 0x0) FROM @FourthLevelAccounts) <> 0x0 THEN (SELECT DefaultMatsAccount FROM @FourthLevelAccounts)
									ELSE (SELECT IsNull(DefaultMatsAccount, 0x0) FROM @FifthLevelAccounts)
									END)
							END)
					END) 
			END,
		CASE WHEN (SELECT IsNull(DefaultDiscountsAccount, 0x0) FROM @FirstLevelAccounts) <> 0x0 THEN (SELECT DefaultDiscountsAccount FROM @FirstLevelAccounts)
			ELSE (CASE 
					WHEN (SELECT IsNull(DefaultDiscountsAccount, 0x0) FROM @SecondLevelAccounts) <> 0x0 THEN (SELECT DefaultDiscountsAccount FROM @SecondLevelAccounts)
					ELSE (CASE 
							WHEN (SELECT IsNull(DefaultDiscountsAccount, 0x0) FROM @ThirdLevelAccounts) <> 0x0 THEN (SELECT DefaultDiscountsAccount FROM @ThirdLevelAccounts)
							ELSE (CASE 
									WHEN (SELECT IsNull(DefaultDiscountsAccount, 0x0) FROM @FourthLevelAccounts) <> 0x0 THEN (SELECT DefaultDiscountsAccount FROM @FourthLevelAccounts)
									ELSE (SELECT IsNull(DefaultDiscountsAccount, 0x0) FROM @FifthLevelAccounts)
									END)
							END)
					END) 
			END,
		CASE WHEN (SELECT IsNull(DefaultExtrasAccount, 0x0) FROM @FirstLevelAccounts) <> 0x0 THEN (SELECT DefaultExtrasAccount FROM @FirstLevelAccounts)
			ELSE (CASE 
					WHEN (SELECT IsNull(DefaultExtrasAccount, 0x0) FROM @SecondLevelAccounts) <> 0x0 THEN (SELECT DefaultExtrasAccount FROM @SecondLevelAccounts)
					ELSE (CASE 
							WHEN (SELECT IsNull(DefaultExtrasAccount, 0x0) FROM @ThirdLevelAccounts) <> 0x0 THEN (SELECT DefaultExtrasAccount FROM @ThirdLevelAccounts)
							ELSE (CASE 
									WHEN (SELECT IsNull(DefaultExtrasAccount, 0x0) FROM @FourthLevelAccounts) <> 0x0 THEN (SELECT DefaultExtrasAccount FROM @FourthLevelAccounts)
									ELSE (SELECT IsNull(DefaultExtrasAccount, 0x0) FROM @FifthLevelAccounts)
									END)
							END)
					END) 
			END,
		CASE WHEN (SELECT IsNull(DefaultVATAccount, 0x0) FROM @FirstLevelAccounts) <> 0x0 THEN (SELECT DefaultVATAccount FROM @FirstLevelAccounts)
			ELSE (CASE 
					WHEN (SELECT IsNull(DefaultVATAccount, 0x0) FROM @SecondLevelAccounts) <> 0x0 THEN (SELECT DefaultVATAccount FROM @SecondLevelAccounts)
					ELSE (CASE 
							WHEN (SELECT IsNull(DefaultVATAccount, 0x0) FROM @ThirdLevelAccounts) <> 0x0 THEN (SELECT DefaultVATAccount FROM @ThirdLevelAccounts)
							ELSE (CASE 
									WHEN (SELECT IsNull(DefaultVATAccount, 0x0) FROM @FourthLevelAccounts) <> 0x0 THEN (SELECT DefaultVATAccount FROM @FourthLevelAccounts)
									ELSE (SELECT IsNull(DefaultVATAccount, 0x0) FROM @FifthLevelAccounts)
									END)
							END)
					END) 
			END,
		CASE WHEN (SELECT IsNull(DefaultCostAccount, 0x0) FROM @FirstLevelAccounts) <> 0x0 THEN (SELECT DefaultCostAccount FROM @FirstLevelAccounts)
			ELSE (CASE 
					WHEN (SELECT IsNull(DefaultCostAccount, 0x0) FROM @SecondLevelAccounts) <> 0x0 THEN (SELECT DefaultCostAccount FROM @SecondLevelAccounts)
					ELSE (CASE 
							WHEN (SELECT IsNull(DefaultCostAccount, 0x0) FROM @ThirdLevelAccounts) <> 0x0 THEN (SELECT DefaultCostAccount FROM @ThirdLevelAccounts)
							ELSE (CASE 
									WHEN (SELECT IsNull(DefaultCostAccount, 0x0) FROM @FourthLevelAccounts) <> 0x0 THEN (SELECT DefaultCostAccount FROM @FourthLevelAccounts)
									ELSE (SELECT IsNull(DefaultCostAccount, 0x0) FROM @FifthLevelAccounts)
									END)
							END)
					END) 
			END,
		CASE WHEN (SELECT IsNull(DefaultStockAccount, 0x0) FROM @FirstLevelAccounts) <> 0x0 THEN (SELECT DefaultStockAccount FROM @FirstLevelAccounts)
			ELSE (CASE 
					WHEN (SELECT IsNull(DefaultStockAccount, 0x0) FROM @SecondLevelAccounts) <> 0x0 THEN (SELECT DefaultStockAccount FROM @SecondLevelAccounts)
					ELSE (CASE 
							WHEN (SELECT IsNull(DefaultStockAccount, 0x0) FROM @ThirdLevelAccounts) <> 0x0 THEN (SELECT DefaultStockAccount FROM @ThirdLevelAccounts)
							ELSE (CASE 
									WHEN (SELECT IsNull(DefaultStockAccount, 0x0) FROM @FourthLevelAccounts) <> 0x0 THEN (SELECT DefaultStockAccount FROM @FourthLevelAccounts)
									ELSE (SELECT IsNull(DefaultStockAccount, 0x0) FROM @FifthLevelAccounts)
									END)
							END)
					END) 
			END,
		CASE WHEN (SELECT IsNull(DefaultBonusAccount, 0x0) FROM @FirstLevelAccounts) <> 0x0 THEN (SELECT DefaultBonusAccount FROM @FirstLevelAccounts)
			ELSE (CASE 
					WHEN (SELECT IsNull(DefaultBonusAccount, 0x0) FROM @SecondLevelAccounts) <> 0x0 THEN (SELECT DefaultBonusAccount FROM @SecondLevelAccounts)
					ELSE (CASE 
							WHEN (SELECT IsNull(DefaultBonusAccount, 0x0) FROM @ThirdLevelAccounts) <> 0x0 THEN (SELECT DefaultBonusAccount FROM @ThirdLevelAccounts)
							ELSE (CASE 
									WHEN (SELECT IsNull(DefaultBonusAccount, 0x0) FROM @FourthLevelAccounts) <> 0x0 THEN (SELECT DefaultBonusAccount FROM @FourthLevelAccounts)
									ELSE (SELECT IsNull(DefaultBonusAccount, 0x0) FROM @FifthLevelAccounts)
									END)
							END)
					END) 
			END,
		CASE WHEN (SELECT IsNull(DefaultBonusContraAccount, 0x0) FROM @FirstLevelAccounts) <> 0x0 THEN (SELECT DefaultBonusContraAccount FROM @FirstLevelAccounts)
			ELSE (CASE 
					WHEN (SELECT IsNull(DefaultBonusContraAccount, 0x0) FROM @SecondLevelAccounts) <> 0x0 THEN (SELECT DefaultBonusContraAccount FROM @SecondLevelAccounts)
					ELSE (CASE 
							WHEN (SELECT IsNull(DefaultBonusContraAccount, 0x0) FROM @ThirdLevelAccounts) <> 0x0 THEN (SELECT DefaultBonusContraAccount FROM @ThirdLevelAccounts)
							ELSE (CASE 
									WHEN (SELECT IsNull(DefaultBonusContraAccount, 0x0) FROM @FourthLevelAccounts) <> 0x0 THEN (SELECT DefaultBonusContraAccount FROM @FourthLevelAccounts)
									ELSE (SELECT IsNull(DefaultBonusContraAccount, 0x0) FROM @FifthLevelAccounts)
									END)
							END)
					END) 
			END,
		CASE WHEN (SELECT IsNull(DefaultCashesAccount, 0x0) FROM @FirstLevelAccounts) <> 0x0 THEN (SELECT DefaultCashesAccount FROM @FirstLevelAccounts)
			ELSE (CASE 
					WHEN (SELECT IsNull(DefaultCashesAccount, 0x0) FROM @SecondLevelAccounts) <> 0x0 THEN (SELECT DefaultCashesAccount FROM @SecondLevelAccounts)
					ELSE (CASE 
							WHEN (SELECT IsNull(DefaultCashesAccount, 0x0) FROM @ThirdLevelAccounts) <> 0x0 THEN (SELECT DefaultCashesAccount FROM @ThirdLevelAccounts)
							ELSE (CASE 
									WHEN (SELECT IsNull(DefaultCashesAccount, 0x0) FROM @FourthLevelAccounts) <> 0x0 THEN (SELECT DefaultCashesAccount FROM @FourthLevelAccounts)
									ELSE (SELECT IsNull(DefaultCashesAccount, 0x0) FROM @FifthLevelAccounts)
									END)
							END)
					END) 
			END

	RETURN
END
###########################################################################
CREATE FUNCTION fnGetMatDataAvgPrice
(
	@ceGUID UNIQUEIDENTIFIER,
	@mtGUID UNIQUEIDENTIFIER
)
RETURNS FLOAT
AS
BEGIN
	DECLARE @Result FLOAT

	SELECT 
		TOP 1 @Result = (CASE WHEN ISNULL(vbi.biQty, 0) <> 0 THEN en.enDebit / vbi.biQty ELSE 0 END) 
	FROM 
		vwEr er
		INNER JOIN vwExtended_en en ON er.erEntryGUID = en.ceGUID
		INNER JOIN vwExtended_bi vbi ON er.erParentGUID = vbi.buGuid AND vbi.biGUID = en.enBiGUID
	WHERE
		((en.enAccount = (SELECT DefaultCostAccount FROM [dbo].[fnGetDefaultAccountsByEntryGUID](@ceGUID)))
		OR (en.enAccount = (SELECT DefaultStockAccount FROM [dbo].[fnGetDefaultAccountsByEntryGUID](@ceGUID))))
		AND 
		(en.enDebit <> 0)
		AND
		(en.ceGUID = @ceGUID)
		AND
		(vbi.biMatPtr = @mtGUID)
	
	RETURN @Result
END
###########################################################################
#END
