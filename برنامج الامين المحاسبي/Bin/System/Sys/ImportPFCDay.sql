#################################################################
CREATE PROCEDURE prcPFCPostBill
	@Date DATETIME = '1/1/1980',
	@Type BIT = 1,
	@PriceType INT = 128
AS
	SET NOCOUNT ON

	DECLARE @IncreaseBillType  UNIQUEIDENTIFIER   
	DECLARE @DecreaseBillType  UNIQUEIDENTIFIER   
	                                                                                                                                                                           
	SET @IncreaseBillType      = dbo.FnStrToGuid((SELECT [Value] FROM op000 WHERE [Name] = 'PFC_IncreaseBillType'))
	SET @DecreaseBillType      = dbo.FnStrToGuid((SELECT [Value] FROM op000 WHERE [Name] = 'PFC_DecreaseBillType'))

	CREATE TABLE #srcType (Guid UNIQUEIDENTIFIER)

	INSERT INTO #srcType
	SELECT IdType FROM ProfitCenterOptionsRepSrcs000

	INSERT INTO #srcType (Guid) VALUES (@IncreaseBillType), (@DecreaseBillType) 

	CREATE TABLE #Result
	( 
          [MatGUID]		[UNIQUEIDENTIFIER],  
          [Unity]       [FLOAT],
          [Price]       [FLOAT],
          [ExpireDate]  [DateTime],
          [Class]       [NVARCHAR](256) COLLATE ARABIC_CI_AI,
          [Qty]         [FLOAT],
          [Qty2]        [FLOAT],
          [Qty3]        [FLOAT]
	)
                 
	INSERT INTO #Result
	SELECT 
		biMatPtr, biUnity , biPrice, biExpireDate, biClassPtr, 
		SUM(CASE Qty + BonusQnt WHEN 0 THEN 1 ELSE Qty + BonusQnt END), 
		SUM(BI.Qty2), SUM(BI.Qty3)
	FROM 
		vwBuBi BU 
		INNER JOIN vwBillItems BI ON BU.biGUID = BI.GUID
		INNER JOIN #srcType SRC ON SRC.Guid = BU.buType
	WHERE 
		CAST(buDate AS DATE) = @Date AND btIsInput = @Type
	GROUP BY 
		biMatPtr, biUnity, biPrice, biExpireDate, biClassPtr
	ORDER BY 
		biMatPtr

	UPDATE #Result SET Price = dbo.fnGetMaterailPriceHistory(MatGUID, @Date, @PriceType, Unity);
	-----------------------------------------------------------------------------

	SELECT * FROM #Result
	-----------------------------------------------------------------------------

	SELECT 
		SNC.MatGUID, SNC.GUID, SNC.SN, bi.Unity, bi.Price, bi.ExpireDate, bi.ClassPtr AS [Class] 
	FROM 
		snt000 SNT 
		INNER JOIN snc000 SNC ON SNT.ParentGUID = SNC.GUID 
		INNER JOIN bu000 BU ON BU.GUID = SNT.buGuid
		INNER JOIN bt000 BT ON BU.TypeGUID = BT.GUID
		INNER JOIN #srcType SRC ON SRC.Guid = BT.GUID
		INNER JOIN bi000 BI on BI.GUID = SNT.biGUID
	WHERE 
		CAST(BU.Date AS DATE) = @Date AND BT.bIsInput = @Type
	ORDER BY 
		SNC.MatGUID, bi.Unity, bi.Price, bi.ExpireDate, bi.ClassPtr
#################################################################
CREATE PROCEDURE GetAccountDetailedBalance
	@AccGuid		UNIQUEIDENTIFIER,
	@DayDate		DATE
AS 
	SET NOCOUNT ON

	SELECT 
		SUM(EN.Debit) AS [Debit],
		SUM(EN.Credit) AS Credit,
		SUM(EN.Debit / en.CurrencyVal) AS [FixedDebit],
		SUM(EN.Credit / en.CurrencyVal) AS FixedCredit,
		EN.AccountGUID,
		EN.CurrencyGUID,
		MY.CurrencyVal
	INTO
		#Temp
	FROM
		en000 EN INNER JOIN my000 MY ON EN.CurrencyGUID = MY.GUID
	WHERE 
		EN.AccountGUID IN (SELECT Guid FROM fnGetAccountsList(@AccGuid,0))
		AND CAST (EN.[Date] AS DATE) <= @DayDate
	GROUP BY
		EN.AccountGUID,
		EN.CurrencyGUID,
		MY.CurrencyVal 

	DECLARE @Lang INT = dbo.fnConnections_GetLanguage();

	SELECT
		AC.GUID,
		CASE @Lang WHEN 0 THEN AC.Name ELSE (CASE AC.LatinName WHEN N'' THEN AC.Name ELSE AC.LatinName END) END  + N' - ' + CASE @Lang WHEN 0 THEN FAC.Name ELSE (CASE FAC.LatinName WHEN N'' THEN FAC.Name ELSE FAC.LatinName END) END AS [AccName],
		CASE @Lang WHEN 0 THEN MY.Name ELSE (CASE MY.LatinName WHEN N'' THEN MY.Name ELSE MY.LatinName END) END AS [CurrencyName],
		T.*
	FROM 
		#Temp AS T
		LEFT JOIN my000 MY ON MY.GUID = T.CurrencyGUID
		LEFT JOIN ac000 AC ON T.AccountGUID = AC.Guid
		LEFT JOIN ac000 FAC ON AC.ParentGUID = FAC.Guid
#################################################################
CREATE PROCEDURE GetStockCount
	@StoreGuid		UNIQUEIDENTIFIER = 0x00,
	@DayDate		DATE

AS 
	SET NOCOUNT ON
	SELECT SUM(((BI.biQty+ BI.biBonusQnt) * dbo.fnGetMaterialUnitFact(BI.biMatPtr, BI.biUnity)) * BI.buDirection) AS Balance
	FROM vwBuBi BI
	WHERE
	(@StoreGuid = 0x0  OR BI.biStorePtr = @StoreGuid)
	AND CAST (BI.buDate AS DATE) <= @DayDate
#################################################################
CREATE PROCEDURE GetExpensesAccounts
	@MainExpensesAcc	UNIQUEIDENTIFIER = 0x0
AS 
	SET NOCOUNT ON

	SELECT AC.* FROM  ac000 AC
	INNER JOIN fnGetAccountsList(@MainExpensesAcc, 1) F 
	ON F.GUID = AC.GUID
	ORDER BY F.[Path]
#################################################################
CREATE PROCEDURE UpdatePFCCurrency
	@DefaultCurrency	UNIQUEIDENTIFIER = 0x0
AS 
	SET NOCOUNT ON

	UPDATE op000 SET Value = @DefaultCurrency WHERE Name LIKE 'AmnCfg_DefaultCurrency'
	UPDATE ac000 SET CurrencyGUID = @DefaultCurrency WHERE CurrencyGUID NOT IN (SELECT [GUID] FROM my000)
	UPDATE bt000 SET DefCurrencyGUID = @DefaultCurrency WHERE DefCurrencyGUID NOT IN (SELECT [GUID] FROM my000)
	UPDATE et000 SET DefCurrency = @DefaultCurrency WHERE DefCurrency NOT IN (SELECT [GUID] FROM my000)
	UPDATE py000 SET CurrencyGUID = @DefaultCurrency WHERE CurrencyGUID NOT IN (SELECT [GUID] FROM my000)
#################################################################
CREATE PROCEDURE GetMatDetails
	@PFCGuid				UNIQUEIDENTIFIER,
	@StoreGuid				UNIQUEIDENTIFIER = 0x00,
	@DayDate				DATE,
	@LastClosedConsalidate	DATE
AS 
	SET NOCOUNT ON

	DECLARE @historyDayDate DATE =
	ISNULL( (SELECT Top(1) MTP.DATE	FROM  MaterialPriceHistory000 MTP
	WHERE MTP.DATE<= @DayDate ORDER BY DATE desc), '1/1/1980')

	SELECT 
		BI.biMatPtr MatGuid,
		SUM((BI.biQty + BI.biBonusQnt) * BI.buDirection) AS MatQty
	INTO
		#Temp
	FROM 
		vwBuBi BI
	WHERE
		(@StoreGuid = 0x0 OR BI.biStorePtr = @StoreGuid) AND
		CAST(BI.buDate AS DATE) <= @DayDate
	GROUP BY
		BI.biMatPtr
	---------------------------------------------------------------------

	IF(@DayDate > @LastClosedConsalidate)
	BEGIN
		SELECT
			T.*, mt.GUID, mt.Name, mt.LatinName, mt.Code, MT.*
		FROM
			GetPFCMaterialsList(@PFCGuid) PFCMat
			INNER JOIN mt000 MT ON PFCMat.MaterialGUID = MT.GUID
			LEFT JOIN #Temp AS T on PFCMat.MaterialGUID = T.MatGuid
		ORDER BY
			mt.Number,
			T.MatQty DESC
	END
	ELSE
	BEGIN
		SELECT
			T.*, mt.GUID, mt.Name, mt.LatinName, mt.Code, PH.*
		FROM
			GetPFCMaterialsList(@PFCGuid) PFCMat
			INNER JOIN mt000 MT ON PFCMat.MaterialGUID = MT.GUID
			LEFT JOIN MaterialPriceHistory000 PH ON MT.GUID = PH.MatGuid
			LEFT JOIN #Temp AS T on PFCMat.MaterialGUID = T.MatGuid
			WHERE PH.Date IS NULL OR PH.[Date] = @historyDayDate
		ORDER BY
			mt.Number,
			T.MatQty DESC
	END
#################################################################
CREATE PROCEDURE GetPFCMatDetails
	@DayDate		DATE
AS 
	SET NOCOUNT ON

	DECLARE @historyDayDate DATE =
	ISNULL( (SELECT Top(1) MTP.DATE	FROM  MaterialPriceHistory000 MTP
	WHERE MTP.DATE<= @DayDate ORDER BY DATE desc), '1/1/1980')

	SELECT 
		BI.biMatPtr MatGuid,
		SUM((BI.biQty + BI.biBonusQnt) * BI.buDirection) AS MatQty
	INTO
		#Temp
	FROM 
		vwBuBi BI
	WHERE
		CAST(BI.buDate AS DATE) <= @DayDate
	GROUP BY
		BI.biMatPtr
	---------------------------------------------------------------------

	SELECT
		T.*, mt.GUID, mt.Name, mt.LatinName, mt.Code, PH.*
	FROM
		mt000 MT
		LEFT JOIN MaterialPriceHistory000 PH ON MT.GUID = PH.MatGuid
		LEFT JOIN #Temp AS T on MT.GUID = T.MatGuid
		WHERE PH.Date IS NULL OR PH.[Date] = @historyDayDate
	ORDER BY
		mt.Number,
		T.MatQty DESC
#################################################################
CREATE PROCEDURE GetAccDetails
	@PFCGuid				UNIQUEIDENTIFIER,
	@AccGuid		UNIQUEIDENTIFIER = 0x00,
	@DayDate		DATE
AS 
	SET NOCOUNT ON

	DECLARE @PurchasingBillTypeGuid			UNIQUEIDENTIFIER   
	DECLARE @ReturnPurchasingBillTypeGuid	UNIQUEIDENTIFIER   
	DECLARE @ExpenseClosePayType			UNIQUEIDENTIFIER 
	
	SELECT 
		@PurchasingBillTypeGuid = DirectPurchasingTypeGuid, 
		@ReturnPurchasingBillTypeGuid = DirectReturnPurchasingTypeGuid, 
		@ExpenseClosePayType = MainExpensesVoucherAccGuid
	FROM SubProfitCenter000 WHERE Guid = @PFCGuid																							
	------------------------------------------------------------------------
	CREATE TABLE #Result
	(
		Guid			UNIQUEIDENTIFIER,
		Number			INT,
		Notes			NVARCHAR(1000),
		Debit			FLOAT,
		Credit			FLOAT,
		Balance			FLOAT,
		AccountGuid		UNIQUEIDENTIFIER,
		ContraAccGuid	UNIQUEIDENTIFIER,
		MatCode			NVARCHAR(255),
		MatName			NVARCHAR(255),
		ContraAccName	NVARCHAR(255),
		BuTypeGuid		UNIQUEIDENTIFIER,
		Type			INT
	)

	INSERT INTO #Result
	SELECT
		CE.Guid,
		CE.Number,
		EN.Notes,
		EN.Debit,
		EN.Credit,
		EN.Debit - EN.Credit AS Balance,
		EN.AccountGUID,
		EN.ContraAccGUID,
		MT.Code MatCode,
		MT.Name MatName,
		CASE EN.ContraAccGUID WHEN 0x0 THEN ' ' ELSE AC.Name END AS ContraAccName,
		BU.TypeGuid,
		CASE 
			WHEN BU.TypeGUID IN (@PurchasingBillTypeGuid, @ReturnPurchasingBillTypeGuid) OR SH.EntryGuid IS NOT NULL THEN 1
			WHEN CE.TypeGUID = @ExpenseClosePayType THEN 2
			WHEN UH.EntryGuid IS NOT NULL THEN 3
			ELSE 6
		END Type
	FROM en000 EN
		INNER JOIN fnGetAccountsList(@AccGuid,0) F ON EN.AccountGUID = F.GUID
		INNER JOIN ce000 CE ON EN.ParentGUID = CE.Guid
		LEFT JOIN ac000 AC ON EN.ContraAccGUID = AC.Guid
		LEFT JOIN bi000 BI ON EN.BiGUID = BI.GUID
		LEFT JOIN mt000 MT ON BI.MatGUID = MT.GUID
		LEFT JOIN er000 ER ON CE.GUID = ER.EntryGUID
		LEFT JOIN bu000 BU ON ER.ParentGUID = BU.GUID
		LEFT JOIN PFCShipmentBill000 SH ON CE.GUID = SH.EntryGuid
		LEFT JOIN PFCMaterialUpdateHistory000 UH ON CE.GUID = UH.EntryGuid
	WHERE 
		CAST (EN.Date AS DATE) = @DayDate
		AND (SH.ProfitCenterGUID IS NULL OR SH.ProfitCenterGUID = @PFCGuid)
	------------------------------------------------------------------------------

	INSERT INTO #Result
	SELECT
		R.Guid,
		R.Number,
		EN.Notes,
		EN.Credit,
		EN.Debit,
		EN.Credit - EN.Debit AS Balance,
		R.AccountGUID,
		R.ContraAccGUID,
		MT.Code MatCode,
		MT.Name MatName,
		R.ContraAccName,
		R.BuTypeGuid,
		4
	FROM 
		#Result R
		INNER JOIN en000 EN ON R.Guid = en.ParentGUID
		INNER JOIN SubProfitCenterBill_EN_Type000 T ON R.BuTypeGuid = T.TypeGuid
		LEFT JOIN bi000 BI ON EN.BiGUID = BI.GUID
		LEFT JOIN mt000 MT ON BI.MatGUID = MT.GUID
	WHERE 
		T.ParentGuid = @PFCGuid
		AND EN.ContraAccGUID = @AccGuid
		AND T.Type IN (1, 2)
	--------------------------------------------------------------------------------

	SELECT * FROM #Result
	ORDER BY Type, MatCode
#################################################################
CREATE PROCEDURE GetPFCAccDetails
	@AccGuid		UNIQUEIDENTIFIER = 0x00,
	@DayDate		DATE
AS 
	SET NOCOUNT ON

	DECLARE @PurchasingBillTypeGuid			UNIQUEIDENTIFIER   
	DECLARE @ReturnPurchasingBillTypeGuid	UNIQUEIDENTIFIER   
	DECLARE @ShipRecieveBillType			UNIQUEIDENTIFIER 
	DECLARE @ReturnSellBill					UNIQUEIDENTIFIER   
	
	SET @PurchasingBillTypeGuid			= dbo.FnStrToGuid((SELECT [Value] FROM op000 WHERE [Name] = 'PFC_PurchasingBillTypeGuid'))
	SET @ReturnPurchasingBillTypeGuid	= dbo.FnStrToGuid((SELECT [Value] FROM op000 WHERE [Name] = 'PFC_ReturnPurchasingBillTypeGuid'))																									
	SET @ShipRecieveBillType			= dbo.FnStrToGuid((SELECT [Value] FROM op000 WHERE [Name] = 'PFC_ShipRecieveBillType'))
	SET @ReturnSellBill					= dbo.FnStrToGuid((SELECT [Value] FROM op000 WHERE [Name] = 'PFC_ReturnSellBill'))
	------------------------------------------------------------------------
		
	DECLARE @ExpenseClosePayType	UNIQUEIDENTIFIER 

	SET @ExpenseClosePayType	= dbo.FnStrToGuid((SELECT [Value] FROM op000 WHERE [Name] = 'PFC_ExpenseClosePayType'))
	------------------------------------------------------------------------

	DECLARE @IncreaseBillTypeGUID UNIQUEIDENTIFIER
	DECLARE @DecreaseBillTypeGUID UNIQUEIDENTIFIER
              
	SET @IncreaseBillTypeGUID = dbo.FnStrToGuid((SELECT [Value] FROM op000 WHERE [Name] = 'PFC_IncreasePricesBillType'))
	SET @DecreaseBillTypeGUID = dbo.FnStrToGuid((SELECT [Value] FROM op000 WHERE [Name] = 'PFC_DecreasePricesBillType'))
	------------------------------------------------------------------------

	SELECT
		CE.Guid,
		CE.Number,
		EN.Notes,
		EN.Debit,
		EN.Credit,
		EN.Debit - EN.Credit AS Balance,
		EN.AccountGUID,
		EN.ContraAccGUID,
		bu.typeguid,
		MT.Code MatCode,
		MT.Name MatName,
		CASE EN.ContraAccGUID WHEN 0x0 THEN ' ' ELSE AC.Name END AS ContraAccName,
		CASE 
			WHEN BU.TypeGUID IN (@ShipRecieveBillType, @ReturnSellBill, @PurchasingBillTypeGuid, @ReturnPurchasingBillTypeGuid) THEN 1 
			WHEN CE.TypeGUID = @ExpenseClosePayType THEN 2
			WHEN BU.TypeGUID IN (@IncreaseBillTypeGUID, @DecreaseBillTypeGUID) THEN 3
			WHEN BU.TypeGUID IN (SELECT IdType FROM ProfitCenterOptionsRepSrcs000) THEN 5
			ELSE 6
		END [Type]
	FROM en000 EN
		INNER JOIN ce000 CE ON EN.ParentGUID = CE.Guid
		LEFT JOIN ac000 AC ON EN.ContraAccGUID = AC.Guid
		LEFT JOIN bi000 BI ON EN.BiGUID = BI.GUID
		LEFT JOIN mt000 MT ON BI.MatGUID = MT.GUID
		LEFT JOIN er000 ER ON CE.GUID = ER.EntryGUID
		LEFT JOIN bu000 BU ON ER.ParentGUID = BU.GUID
	WHERE 
		EN.AccountGUID IN (SELECT Guid FROM fnGetAccountsList(@AccGuid,0))
		AND CAST (EN.Date AS DATE) = @DayDate
	ORDER BY Type, MatCode
#################################################################
CREATE PROCEDURE GetAccContras
	@AccGuid		UNIQUEIDENTIFIER = 0x00,
	@CEGuid			UNIQUEIDENTIFIER = 0x00,
	@Debit          FLOAT,
	@Credit         FLOAT
AS 
	SET NOCOUNT ON

	SELECT
		EN.Notes,
		EN.Debit,
		EN.Credit,
		EN.Debit - EN.Credit AS Balance
	FROM en000 EN
		INNER JOIN ce000 CE ON EN.ParentGUID = CE.Guid
	WHERE 
		CE.Guid = @CEGuid
		AND EN.ContraAccGUID = @AccGuid
		AND EN.Credit = @Debit
		AND EN.Debit = @Credit
#################################################################
CREATE PROCEDURE GetMatStockCount
	@MatGuid		UNIQUEIDENTIFIER = 0x00,
	@StoreGuid		UNIQUEIDENTIFIER = 0x00,
	@DayDate		DATE
AS 
	SET NOCOUNT ON

	SELECT
		SUM((BI.biQty + BI.biBonusQnt) * BI.buDirection) AS MatQty
	FROM 
		vwBuBi BI
	WHERE
		(BI.biMatPtr = @MatGuid) AND
		(@StoreGuid = 0x0 OR BI.biStorePtr = @StoreGuid) AND
		CAST(BI.buDate AS DATE) <= @DayDate
##########################################################################################
CREATE FUNCTION GetMaterialUnitPrice
( 
		@MatGuid	UNIQUEIDENTIFIER,
		@PriceType	INT = 128,
		@Unit		INT = 1
)
	RETURNS FLOAT
AS BEGIN 

	DECLARE @Result FLOAT
	SET @Result = (
	SELECT CASE	WHEN @PriceType = 4 THEN (	CASE @Unit	WHEN 1 THEN Mt.Whole   
															WHEN 2 THEN Mt.Whole2     
															WHEN 3 THEN Mt.Whole3
												  
											END)

				WHEN @PriceType = 8 THEN (	CASE @Unit	WHEN 1 THEN Mt.Half   
															WHEN 2 THEN Mt.Half2     
															WHEN 3 THEN Mt.Half3
											END )

				WHEN @PriceType = 32 THEN (	CASE @Unit	WHEN 1 THEN Mt.Vendor   
															WHEN 2 THEN Mt.Vendor2     
															WHEN 3 THEN Mt.Vendor3
												 
											END )

				WHEN @PriceType = 16 THEN (	CASE @Unit	WHEN 1 THEN Mt.Export   
															WHEN 2 THEN Mt.Export2     
															WHEN 3 THEN Mt.Export3	  
											END )

				WHEN @PriceType = 64 THEN (	CASE @Unit	WHEN 1 THEN Mt.Retail   
															WHEN 2 THEN Mt.Retail2     
															WHEN 3 THEN Mt.Retail3								  
											END )

				WHEN @PriceType = 128 THEN(	CASE @Unit	WHEN 1 THEN Mt.EndUser   
															WHEN 2 THEN Mt.EndUser2     
															WHEN 3 THEN Mt.EndUser3   
											END )

				ELSE (	CASE @Unit	WHEN 1 THEN Mt.LastPrice   
										WHEN 2 THEN Mt.LastPrice2     
										WHEN 3 THEN Mt.LastPrice3   
						END	)
		END
		FROM
			Mt000 Mt   
		WHERE
			Mt.Guid = @MatGuid )
	RETURN isnull(@Result, 0.0) 
	END
#################################################################
CREATE PROCEDURE GetMatBalances
	@PriceType		INT
AS 
	SET NOCOUNT ON
	SELECT 
		BI.biMatPtr MatGuid,
		SUM((BI.biQty + BI.biBonusQnt) * dbo.GetMaterialUnitPrice(BI.biMatPtr, @PriceType, 1) * BI.buDirection) AS MatBalance
	INTO
		#Temp
	FROM 
		vwBuBi BI
	GROUP BY
		BI.biMatPtr
	
	SELECT
		mt.*, T.MatBalance
	FROM
		mt000 mt
		INNER JOIN #Temp AS T on mt.GUID = T.MatGuid
	WHERE
		T.MatBalance <> 0
	ORDER BY
		mt.Number
##########################################################################################
CREATE PROCEDURE prcGetPFCPurchasingBillNumber
		@Date DATETIME = '1/1/1980'
AS
	DECLARE @PurchasingBillTypeGuid			UNIQUEIDENTIFIER   
	DECLARE @ReturnPurchasingBillTypeGuid	UNIQUEIDENTIFIER   
																										
	SET @PurchasingBillTypeGuid			= dbo.FnStrToGuid((SELECT [Value] FROM op000 WHERE [Name] = 'PFC_PurchasingBillTypeGuid'))
	SET @ReturnPurchasingBillTypeGuid	= dbo.FnStrToGuid((SELECT [Value] FROM op000 WHERE [Name] = 'PFC_ReturnPurchasingBillTypeGuid'))
	
	SELECT buNumber Number, btIsInput IsInput, buType Type FROM vwBu
	WHERE 
		(buType = @PurchasingBillTypeGuid OR buType = @ReturnPurchasingBillTypeGuid) AND buDate = @Date
	ORDER BY IsInput DESC
#################################################################
CREATE PROCEDURE prcGetPFCPurchasingBill
		@Date DATETIME = '1/1/1980',
		@Type BIT
AS
	SET NOCOUNT ON
	DECLARE @Result TABLE( 
		[BillGUID]		[UNIQUEIDENTIFIER],  
		[MatGUID]		[UNIQUEIDENTIFIER],  
		[Unity]			[FLOAT],
		[Price]			[FLOAT],
		[ExpireDate]	[DateTime],
		[Class]			[NVARCHAR](256) COLLATE ARABIC_CI_AI,
		[Qty]			[FLOAT],
		[Bonus]			[FLOAT],
		[Qty2]          [FLOAT],
		[Qty3]          [FLOAT])

	DECLARE @PurchasingBillTypeGuid			UNIQUEIDENTIFIER   
	DECLARE @ReturnPurchasingBillTypeGuid	UNIQUEIDENTIFIER   
	
	SET @PurchasingBillTypeGuid			= dbo.FnStrToGuid((SELECT [Value] FROM op000 WHERE [Name] = 'PFC_PurchasingBillTypeGuid'))
	SET @ReturnPurchasingBillTypeGuid	= dbo.FnStrToGuid((SELECT [Value] FROM op000 WHERE [Name] = 'PFC_ReturnPurchasingBillTypeGuid'))
	
	SELECT buGUID BillGuid, buNotes, buCurrencyPtr, buCurrencyVal
	FROM vwBu BU 
	WHERE CAST(buDate AS DATE) = @Date AND btIsInput = @Type AND
	(buType = @PurchasingBillTypeGuid OR buType = @ReturnPurchasingBillTypeGuid)
	ORDER BY buGUID
 				
	INSERT INTO @Result
	SELECT buGUID, biMatPtr, biUnity , biPrice, biExpireDate, biClassPtr, CASE Qty WHEN 0 THEN 1 ELSE Qty END, CASE BonusQnt WHEN 0 THEN 1 ELSE BonusQnt END, BI.Qty2, BI.Qty3
	FROM vwBuBi BU INNER JOIN vwBillItems BI ON BU.biGUID = BI.GUID
	WHERE CAST(buDate AS DATE) = @Date AND btIsInput = @Type AND
	(buType = @PurchasingBillTypeGuid OR buType = @ReturnPurchasingBillTypeGuid)
	ORDER BY buGUID, biMatPtr

	SELECT * FROM @Result

	SELECT buGuid BillGuid, SNC.MatGUID, SNC.GUID, SNC.SN, bi.Unity, bi.Price, bi.ExpireDate, bi.ClassPtr AS [Class] FROM snt000 SNT 
	INNER JOIN snc000 SNC ON SNT.ParentGUID = SNC.GUID 
	INNER JOIN bu000 BU ON BU.GUID = SNT.buGuid
	INNER JOIN bt000 BT ON BU.TypeGUID = BT.GUID
	INNER JOIN bi000 BI on BI.GUID = SNT.biGUID
	WHERE CAST(BU.Date AS DATE) = @Date AND BT.bIsInput = @Type AND 
	(BU.TypeGUID = @PurchasingBillTypeGuid OR BU.TypeGUID = @ReturnPurchasingBillTypeGuid)
	ORDER BY buGuid, SNC.MatGUID, bi.Unity, bi.Price, bi.ExpireDate, bi.ClassPtr
##########################################################################################
CREATE FUNCTION fnGetMaterailPriceHistory
(
	@matGuid UNIQUEIDENTIFIER,
	@Date DATETIME,
	@priceType INT,
	@unity INT
)
RETURNS FLOAT
BEGIN

	RETURN (
		SELECT TOP(1) 
			CASE 
				WHEN @PriceType = 4 THEN CASE @unity WHEN 1 THEN Whole WHEN 2 THEN Whole2 WHEN 3 THEN Whole3 END
				WHEN @PriceType = 8 THEN CASE @unity WHEN 1 THEN Half WHEN 2 THEN Half2 WHEN 3 THEN Half3 END
				WHEN @PriceType = 32 THEN CASE @unity WHEN 1 THEN Vendor WHEN 2 THEN Vendor2 WHEN 3 THEN Vendor3 END
				WHEN @PriceType = 16 THEN CASE @unity WHEN 1 THEN Export WHEN 2 THEN Export2 WHEN 3 THEN Export3 END
				WHEN @PriceType = 64 THEN CASE @unity WHEN 1 THEN Retail WHEN 2 THEN Retail2 WHEN 3 THEN Retail3 END
				WHEN @PriceType = 128 THEN CASE @unity WHEN 1 THEN EndUser WHEN 2 THEN EndUser2 WHEN 3 THEN EndUser3 END
			END
		FROM 
			MaterialPriceHistory000 
		WHERE 
			DATE <= @Date AND MatGuid = @matGuid 
		ORDER BY 
			DATE DESC)
END
##########################################################################################
CREATE FUNCTION fnCanEditPFCBill
(
	@typeGuid UNIQUEIDENTIFIER,
	@date DATETIME
)
RETURNS BIT
AS
BEGIN
	IF EXISTS(
		SELECT P.GUID
		FROM SubProfitCenterBill_EN_Type000 t 
			INNER JOIN PFCPostedDays000 P ON p.PFCGuid = T.ParentGuid
			inner JOIN PFCDayStatus000 S ON S.PFCGUID = T.ParentGuid
		WHERE 
			T.TypeGuid = @typeGuid 
			AND P.Date = @date AND S.Date = @date
			AND s.CurrentAcc = 1 AND s.GoodStock = 1)
		RETURN 0

	RETURN 1
END
##########################################################################################
#END