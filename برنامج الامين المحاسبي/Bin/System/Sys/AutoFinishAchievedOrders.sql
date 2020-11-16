########################################################################################
CREATE PROCEDURE AutoFinishAchievedOrders  
	@OrdersList UNIQUEIDENTIFIER 
AS  
    ----------------------------------------------------- 
	SELECT IdType AS OrderGuid 
	INTO #Orders 
	FROM RepSrcs 
	WHERE IdTbl = @OrdersList 
	----------------------------------------------------- 
	SELECT  
		bu.Guid      AS OrderGuid,  
		SUM(bi.Qty)  AS OrderQty 
	INTO #OrderedQtys 
	FROM  
				   bu000  AS bu  
		INNER JOIN bi000  AS bi  ON bi.ParentGuid = bu.Guid 
		INNER JOIN #Orders AS O ON O.OrderGuid = bu.Guid 
	GROUP BY bu.Guid 
	----------------------------------------------------- 
	SELECT  
		ori.POGuid   AS OrderGuid, 
		SUM(CASE dbo.fnIsFinalState(bt.Guid, oit.Guid) WHEN 1 THEN ori.Qty ELSE 0 END) AS AchievedQty 
	INTO #AchievedOrders 
	FROM 
		bt000 bt
		INNER JOIN bu000   bu  ON bt.GUID = bu.TypeGUID
		INNER JOIN ori000  ori ON ori.POGUID = bu.GUID
		INNER JOIN oit000  oit ON oit.Guid = ori.TypeGuid
		INNER JOIN #Orders O   ON O.OrderGuid = ori.POGuid 
	GROUP BY ori.POGuid 
	------------------------------------------------------ 
	UPDATE OrAddInfo000 
		SET Finished = 2 
		WHERE ParentGuid IN (SELECT oq.OrderGuid  
                             FROM #OrderedQtys AS oq INNER JOIN #AchievedOrders AS ao  
								  ON oq.OrderGuid = ao.OrderGuid AND ao.AchievedQty >= oq.OrderQty) 
	------------------------------------------------------ 
########################################################################################
CREATE PROCEDURE prcOrders_CheckAccountBudget
	@AccountGUID	UNIQUEIDENTIFIER, 
	@CurrGUID		UNIQUEIDENTIFIER, 
	@OrderGUID		UNIQUEIDENTIFIER,
	@GrandTotal		FLOAT, 
	@BillType		INT
AS  
	SET NOCOUNT ON 
	 
    DECLARE @AccBudget FLOAT 
    SELECT @AccBudget = 
		(CASE @BillType  
			WHEN 1 THEN (CASE ac.Warn WHEN 1 THEN dbo.fnCurrency_Fix(ac.MaxDebit, ac.CurrencyGUID, ac.CurrencyVal, @CurrGuid, NULL) ELSE -1 END) 
            WHEN 2 THEN (CASE ac.Warn WHEN 2 THEN dbo.fnCurrency_Fix(ac.MaxDebit, ac.CurrencyGUID, ac.CurrencyVal, @CurrGuid, NULL) ELSE -1 END)                              
		END) 
    FROM ac000 ac
    WHERE GUID = @AccountGUID 
	IF ISNULL(@AccBudget, -1) = -1 
		RETURN 

	DECLARE @AccBalance FLOAT 
	DECLARE @SalesOrdersTotal FLOAT 
	DECLARE @PurchaseOrdersTotal FLOAT 
	DECLARE @DelivariedSalesOrdersTotal FLOAT 
	DECLARE @DelivariedPurchaseOrdersTotal FLOAT

	CREATE TABLE #OrdersBills
	(
		OrderGuid UNIQUEIDENTIFIER,
		BillGuid UNIQUEIDENTIFIER,
		BillCustAccGuid UNIQUEIDENTIFIER,
		Total FLOAT
	)

	;WITH orderbillsItems AS
	(
		SELECT bi.buGUID buGUID,
			bi.biGUID biGUID,
			bi.buCustAcc buCustAccGuid,
			biBillQty biQty,
			biUnitPrice biUnitPrice,
			biUnitExtra biUnitExtra,
			biUnitDiscount biUnitDiscount,
			biBonusDisc biBonusDisc,
			biVAT biVAT,
			biBonusQnt biBonusQnt
		FROM vwExtended_bi bi
		INNER JOIN ori000 ori ON ori.BuGuid = bi.buGUID
	)

	INSERT INTO #OrdersBills
	SELECT OrderGuid, 
	bi.BillGuid,
	bi.BillCustAccGuid,
    Sum(( bi.BiQty * ( bi.BiPrice + BiExtra - BiDiscount ) ) + ( BiVat ) - ( biBonusDisc )) AS BillTotal
    FROM   (SELECT DISTINCT ori.oriPOGUID             AS OrderGuid,
                            bi.buGUID                 AS BillGuid,
                            bi.biQty                  AS BiQty,
                            ISNULL(bi.biUnitPrice, 0) AS BiPrice,
                            ISNULL(bi.biUnitExtra, 0) AS BiExtra,
                            ISNULL(biUnitDiscount, 0) AS BiDiscount,
                            ISNULL(bi.biBonusDisc, 0) AS biBonusDisc,
                            ISNULL(bi.biVAT, 0)       AS BiVat,
							ISNULL(bi.biBonusQnt, 0)  AS BiBonusQnt,
							bi.buCustAccGuid AS BillCustAccGuid
    FROM   orderbillsItems bi
           INNER JOIN vwORI ori ON bi.biGUID = ori.oriBiGUID
           INNER JOIN oit000 oit ON ori.oriTypeGuid = oit.[Guid]
    WHERE  oit.QtyStageCompleted = 1
           AND (ori.oriQty > 0 OR ori.oriBonusPostedQty > 0)
           AND ori.oriType = 0
		   ) bi
    GROUP  BY bi.orderGuid,
              bi.BillGuid,
			  bi.BillCustAccGuid

	SELECT 
		@AccBalance = ISNULL(Debit - Credit, 0)
	FROM 
		dbo.fnAccount_getDebitCredit(@AccountGuid, @CurrGuid) 

	SELECT @SalesOrdersTotal = ISNULL(SUM(Total), 0)
	FROM bu000 bu
	INNER JOIN ORADDINFO000 ordInf ON bu.GUID = ordInf.ParentGuid
	INNER JOIN bt000 bt ON bu.TypeGUID = bt.GUID
	WHERE bu.GUID <> @OrderGuid AND bt.BillType = 5 AND 
	bu.CustAccGUID =  @AccountGuid AND PayType = 1 AND
	ordInf.Add1 = 0 AND ordInf.Finished = 0 

	SELECT @DelivariedSalesOrdersTotal = ISNULL(SUM(ordBill.Total), 0)
	FROM #OrdersBills ordBill
	INNER JOIN bu000 bu ON bu.Guid = ordBill.OrderGuid
	INNER JOIN ORADDINFO000 ordInf ON bu.GUID = ordInf.ParentGuid
	INNER JOIN bt000 bt ON bu.TypeGUID = bt.GUID
	WHERE ordBill.BillCustAccGuid = @AccountGuid AND bt.BillType = 5 AND
	ordInf.Add1 = 0 AND ordInf.Finished = 0 
	
	SET @SalesOrdersTotal = @SalesOrdersTotal - @DelivariedSalesOrdersTotal
	
	SELECT @PurchaseOrdersTotal = ISNULL(SUM(Total), 0)
	FROM bu000 bu
	INNER JOIN ORADDINFO000 ordInf ON bu.GUID = ordInf.ParentGuid
	INNER JOIN bt000 bt ON bu.TypeGUID = bt.GUID
	WHERE bu.GUID <> @OrderGuid AND bt.BillType = 4 AND bu.CustAccGUID =  @AccountGuid AND PayType = 1 AND
	ordInf.Add1 = 0 AND ordInf.Finished = 0 

	SELECT @DelivariedPurchaseOrdersTotal = ISNULL(SUM(ordBill.Total), 0)
	FROM #OrdersBills ordBill
	INNER JOIN bu000 bu ON bu.Guid = ordBill.OrderGuid
	INNER JOIN ORADDINFO000 ordInf ON bu.GUID = ordInf.ParentGuid
	INNER JOIN bt000 bt ON bu.TypeGUID = bt.GUID
	WHERE ordBill.BillCustAccGuid = @AccountGuid AND bt.BillType = 4 AND
	ordInf.Add1 = 0 AND ordInf.Finished = 0  

	SET @PurchaseOrdersTotal = @PurchaseOrdersTotal - @DelivariedPurchaseOrdersTotal

	SET @AccBalance = @AccBalance + @SalesOrdersTotal - @PurchaseOrdersTotal
						   
    DECLARE @NewBalance FLOAT 
    SET @NewBalance = @AccBalance + CASE @BillType WHEN 1 THEN @GrandTotal ELSE -1 * @GrandTotal END
     
    IF ((@AccBudget > -1) AND (abs(@NewBalance) > @AccBudget)) 
		SELECT abs(@AccBalance) AS AccBalance, abs(@AccBudget) AS AccBudget, abs(@NewBalance) AS NewBalance 
		
########################################################################################
CREATE FUNCTION fnGetFinishedState
(
	@OrderGuid UNIQUEIDENTIFIER
)
RETURNS INT 
AS 
BEGIN
  DECLARE @FinishedState INT
  DECLARE @OrderFinishedState INT
  DECLARE @OrderQty FLOAT
  DECLARE @AchievedQty FLOAT;
	
	SELECT 
		@OrderQty = SUM(bi.Qty),
		@AchievedQty = SUM(CASE dbo.fnIsFinalState(bt.Guid, oit.Guid) WHEN 1 THEN ori.Qty ELSE 0 END),
		@OrderFinishedState = orinfo.finished
	FROM 
		bt000 bt
		INNER JOIN bu000   bu  ON bt.GUID = bu.TypeGUID
		INNER JOIN bi000  AS bi  ON bi.ParentGuid = bu.Guid 
		INNER JOIN ori000  ori ON ori.POGUID = bu.GUID
		INNER JOIN Oraddinfo000 orinfo ON orinfo.parentGuid = bu.Guid
		INNER JOIN oit000  oit ON oit.Guid = ori.TypeGuid
	WHERE
		bu.Guid = @OrderGuid
	GROUP BY 
		ori.POGuid,
		orinfo.finished

		IF (@OrderFinishedState IN (1,2))
			SET @FinishedState = 2
		ELSE
		BEGIN
			IF (@AchievedQty = 0)
				SET @FinishedState = 0
			ELSE
			IF(@AchievedQty < @OrderQty)
				SET @FinishedState = 1
		END	
					
   RETURN @FinishedState
END
########################################################################################
CREATE FUNCTION fnGetPaymentState 
(
	@OrderGuid UNIQUEIDENTIFIER
)
RETURNS INT 
AS 
BEGIN
  DECLARE @PayType INT
  DECLARE @PaymentState INT
  DECLARE @TotalValue FLOAT
  DECLARE @PaidValue FLOAT;

  SELECT @PayType = PayType FROM bu000 WHERE GUID = @OrderGuid
 
  IF(@PayType = 0)
   SET @PaymentState = 2
  ELSE
  BEGIN
    SELECT 
		@TotalValue = SUM(Pay.[UpdatedValueWithCurrency])
	FROM 
		vworderpayments AS PAY
		INNER JOIN vwBu AS BU ON BU.buGUID = PAY.BillGuid
	WHERE
		BU.buGUID = @OrderGuid
	GROUP BY
		BU.buGUID

	SELECT
		 @PaidValue = SUM(ISNULL(bp.Val, 0))
	FROM
	     bp000 AS bp
		 INNER JOIN vworderpayments AS PAY ON PAY.PaymentGuid = bp.DebtGUID OR PAY.PaymentGuid = bp.PayGUID
		 INNER JOIN vwBu AS BU ON BU.buGUID = PAY.BillGuid
	WHERE
		BU.buGUID = @OrderGuid
	GROUP BY
		BU.buGUID

		IF (ISNULL(@PaidValue,0) = 0)
			SET @PaymentState = 0
		ELSE
		BEGIN
			IF(ISNULL(@TotalValue - @PaidValue,0) > 10.e-9 AND ISNULL(@PaidValue,0) < @TotalValue)
				SET @PaymentState = 1
			ELSE
				SET @PaymentState = 2
		END
	END
  					  
   RETURN @PaymentState
END
########################################################################################
CREATE FUNCTION fnGetOrderPaymentsValue (@OrderGuid UNIQUEIDENTIFIER)
RETURNS FLOAT
AS
  BEGIN
      DECLARE @PayType INT
      DECLARE @PaidValue FLOAT;

      SELECT @PayType = PayType
      FROM   bu000
      WHERE  GUID = @OrderGuid

      IF( @PayType <> 0 )
        BEGIN
            SELECT @PaidValue = ISNULL(Sum(( CASE
                                               WHEN bp.CurrencyGUID <> BU.buCurrencyPtr THEN ( CASE
                                                                                                 WHEN bp.CurrencyVal = 1 THEN bp.Val / BU.buCurrencyVal
                                                                                                 ELSE bp.Val
                                                                                               END )
                                               ELSE bp.Val / BU.buCurrencyVal
                                             END )), 0)
            FROM   bp000 AS bp
                   INNER JOIN vworderpayments AS PAY
                           ON PAY.PaymentGuid = bp.DebtGUID
                               OR PAY.PaymentGuid = bp.PayGUID
                   INNER JOIN vwBu AS BU
                           ON BU.buGUID = PAY.BillGuid
            WHERE  BU.buGUID = @OrderGuid
            GROUP  BY BU.buGUID
        END

      RETURN @PaidValue
  END 
########################################################################################
CREATE FUNCTION fnGetPostedBillValue (@OrderGuid UNIQUEIDENTIFIER)
RETURNS FLOAT
AS
  BEGIN
      DECLARE @TotalPosted FLOAT;

	  -------------ÌÏæá ÝæÇÊíÑ ÇáØáÈíÉ ÇáãÏæÑÉ æÛíÑ ÇáãÏæÑÉ------------
        DECLARE @orderbills TABLE 
        (
            buGUID         UNIQUEIDENTIFIER,
            buType         UNIQUEIDENTIFIER,
            btAbbrev       NVARCHAR(250),
            buNumber       FLOAT,
            buCostPtr      UNIQUEIDENTIFIER,
            buDate         DATETIME,
            buStorePtr     UNIQUEIDENTIFIER,
            buTotal        FLOAT,
            buTotalExtra   FLOAT,
            buTotalDisc    FLOAT,
            buBonusDisc    FLOAT,
            biGUID         UNIQUEIDENTIFIER,
            biStorePtr     UNIQUEIDENTIFIER,
            biCostPtr      UNIQUEIDENTIFIER,
            biUnity        FLOAT,
            biMatPtr       UNIQUEIDENTIFIER,
            biQty          FLOAT,
            biPrice        FLOAT,
            biUnitPrice    FLOAT,
            biClassPtr     NVARCHAR(250),
			biUnitDiscount FLOAT,
			biUnitExtra FLOAT,
			biBonusDisc FLOAT,
			biVAT FLOAT,
			biCurrencyVal FLOAT,
			biExpireDate DATETIME)

	  ---------------ÇáÝæÇÊíÑ ÇáãÏæÑÉ ---------------------------
		DECLARE @X xml 

		INSERT INTO @orderbills
		SELECT  x.r.value('(buGUID)[1]', 'uniqueidentifier') as [buGuid],
		  x.r.value('(buType)[1]', 'uniqueidentifier') as [buType],
		  x.r.value('(btAbbrev)[1]', 'NVARCHAR(250)') as [btAbbrev],
		  x.r.value('(buNumber)[1]', 'FLOAT') as [buNumber],
		  x.r.value('(buCostPtr)[1]', 'uniqueidentifier') as [buCostPtr],
		  x.r.value('(buDate)[1]', 'DATETIME') as [buDate],
		  x.r.value('(buStorePtr)[1]', 'uniqueidentifier') as [buStorePtr],
		  x.r.value('(buTotal)[1]', 'FLOAT') as [buTotal],
		  x.r.value('(buTotalExtra)[1]', 'FLOAT') as [buTotalExtra],
		  x.r.value('(buTotalDisc)[1]', 'FLOAT') as [buTotalDisc],
		  x.r.value('(buBonusDisc)[1]', 'FLOAT') as [buBonusDisc],
		  x.r.value('(biGUID)[1]', 'uniqueidentifier') as [biGuid],
		  x.r.value('(biStorePtr)[1]', 'uniqueidentifier') as [biStorePtr],
		  x.r.value('(biCostPtr)[1]', 'uniqueidentifier') as [biCostPtr],
		  x.r.value('(biUnity)[1]', 'FLOAT') as [biUnity],
		  x.r.value('(biMatPtr)[1]', 'uniqueidentifier') as [biMatPtr],
		  x.r.value('(biQty)[1]', 'FLOAT') as [biQty],
		  x.r.value('(biPrice)[1]', 'FLOAT') as [biPrice],
		  x.r.value('(biUnitPrice)[1]', 'FLOAT') as [biUnitPrice],
		  x.r.value('(biClassPtr)[1]', 'NVARCHAR(250)') as [biClassPtr],
		  x.r.value('(biUnitDiscount)[1]', 'FLOAT') as [biUnitDiscount],
		  x.r.value('(biUnitExtra)[1]', 'FLOAT') as [biUnitExtra],
		  x.r.value('(biBonusDisc)[1]', 'FLOAT') as [biBonusDisc],
		  x.r.value('(biVAT)[1]', 'FLOAT') as [biVat],
		  x.r.value('(biCurrencyVal)[1]', 'FLOAT') as [biCurrencyVal],
		  x.r.value('(biExpireDate)[1]', 'DATETIME') as [biExpireDate]
		FROM   
		  @X.nodes('/OrderBills') as x(r)
	  
	  -----------------------------ÇáÝæÇÊíÑ ÛíÑ ÇáãÏæÑÉ----------------------
          INSERT INTO @orderbills
          SELECT buGUID,
				buType,
				btAbbrev,
				buNumber,
				buCostPtr,
				buDate,
				buStorePtr,
				buTotal,
				buTotalExtra,
				buTotalDisc,
				buBonusDisc,
				biGUID,
				biStorePtr,
				biCostPtr,
				biUnity,
				biMatPtr,
				biQty,
				biPrice,
				biUnitPrice,
				biClassPtr,
				biUnitDiscount,
				biUnitExtra,
				biBonusDisc,
				biVAT,
				biCurrencyVal,
				biExpireDate
          FROM   vwExtended_bi bi
          WHERE  bi.buGUID IN (SELECT BuGuid
                               FROM   ori000 ori
                               WHERE  ori.POGUID = @OrderGuid)
				
   	---------------ÍÓÇÈ ÇáãÌãæÚ ÇáãÍÞÞ ááØáÈíÉ -------------------------
          SELECT @TotalPosted = Sum(( bi.BiQty * ( bi.BiPrice + BiExtra - BiDiscount)) + (BiVat))
          FROM   (SELECT DISTINCT ori.oriPOGUID             AS orderGuid,
                                  bi.buGUID                 AS BillGuid,
                                  bi.biGuid                 AS BiGuid,
                                  bi.biQty                  AS BiQty,
								  ISNULL(bi.biUnitPrice, 0) AS BiPrice,
								  ISNULL(bi.biUnitExtra, 0) AS BiExtra,
								  ISNULL(biUnitDiscount, 0) AS BiDiscount,
								  ISNULL(bi.biBonusDisc, 0) AS biBonusDisc,
								  ISNULL(bi.biVAT, 0)       AS BiVat
                  FROM   @orderbills bi
                         INNER JOIN vwORI ori
                                 ON bi.biGUID = ori.oriBiGUID
                         INNER JOIN oit000 oit
                                 ON ori.oriTypeGuid = oit.[Guid]
                  WHERE  oit.QtyStageCompleted = 1
                         AND ori.oriQty > 0
                         AND ori.oriType = 0
				AND ori.oriPOGUID = @OrderGuid) bi
          GROUP  BY bi.orderGuid

		SET @TotalPosted = ISNULL(@TotalPosted, 0)

      RETURN @TotalPosted
  END 
########################################################################################
CREATE FUNCTION fnIsOrderMaterialsRepeated
(
	@OrderGuid UNIQUEIDENTIFIER,
	@MatGuid UNIQUEIDENTIFIER
)
RETURNS BIT 
AS 
BEGIN
  DECLARE @RepeatedMaterials BIT = 0
  DECLARE @TotalCount INT
  DECLARE @DistinctCount INT;

      SELECT @TotalCount = Count(*)
      FROM   vwExtended_bi
      WHERE  buGuid = @OrderGuid
             AND biMatPtr = ( CASE ISNULL(@MatGuid, 0x0)
                                WHEN 0x0 THEN biMatPtr
                                ELSE @MatGuid
                              END )

      SELECT @DistinctCount = Count(*)
      FROM   (SELECT DISTINCT biMatPtr
              FROM   vwExtended_bi
              WHERE  buGuid = @OrderGuid
                     AND biMatPtr = ( CASE ISNULL(@MatGuid, 0x0)
                                        WHEN 0x0 THEN biMatPtr
                                        ELSE @MatGuid
                                      END )) AS bi
  
      IF ( @TotalCount > @DistinctCount )
   SET @RepeatedMaterials = 1

   RETURN @RepeatedMaterials
END
########################################################################################
#END

