#############################################################################
CREATE PROCEDURE repOrderBills @OrderGuid UNIQUEIDENTIFIER = 0X0
AS 
    SET nocount ON
DECLARE @language [INT] = [dbo].[fnConnections_getLanguage]() 

CREATE TABLE #Result(
	OrderGuid UNIQUEIDENTIFIER,
	BuGuid UNIQUEIDENTIFIER,
	BuTypeGuid UNIQUEIDENTIFIER,
	BuCurrencyGuid UNIQUEIDENTIFIER,
	BuCurrencyVal FLOAT,
	BuCustAcc UNIQUEIDENTIFIER,
	BuDate DATETIME,
	BuNumber FLOAT,
	BuName NVARCHAR(255),
	BuTotal FLOAT,
	BuTotalQty FLOAT,
	IsRecycled BIT,
	Paied FLOAT,
	Remaining FLOAT,
	NotesType INT,
	BuTotalBouns FLOAT,
	BillNotes NVARCHAR(1000) COLLATE ARABIC_CI_AI,
	BuLcGuid UNIQUEIDENTIFIER,
	BuLcName NVARCHAR(255) COLLATE ARABIC_CI_AI,
	BuLcState BIT)
	
 CREATE TABLE #orderbills
      (
         buGUID         UNIQUEIDENTIFIER,
         buType         UNIQUEIDENTIFIER,
         buVat          FLOAT,
		 buCurrencyGuid UNIQUEIDENTIFIER,
         buCurrencyVal  FLOAT,
         btAbbrev       NVARCHAR(250),
         buNumber       FLOAT,
         buCostPtr      UNIQUEIDENTIFIER,
         buDate         DATE,
         buStorePtr     UNIQUEIDENTIFIER,
		 buCustAcc      UNIQUEIDENTIFIER,
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
         biBillQty      FLOAT,
         biPrice        FLOAT,
         biUnitPrice    FLOAT,
         biClassPtr     NVARCHAR(250),
         biDiscount     FLOAT,
         biExtra        FLOAT,
         biBonusDisc    FLOAT,
         biVAT          FLOAT,
         biUnitDiscount FLOAT,
         biUnitExtra    FLOAT,
         biCurrencyVal  FLOAT,
         biExpireDate   DATETIME,
		 biBonusQnt     FLOAT,
		 billNotes NVARCHAR(1000) COLLATE ARABIC_CI_AI,
		 buLcGuid UNIQUEIDENTIFIER,
		 buLcName NVARCHAR(250) COLLATE ARABIC_CI_AI,
		 buLcState BIT
      )
	
	DECLARE @X xml 
    SELECT @X = BillXmlData
    FROM   TrnOrdBu000
    WHERE  OrderGuid = @OrderGuid
	--Old bills from transfered file
    INSERT INTO #orderbills
    SELECT x.r.value('(buGUID)[1]', 'uniqueidentifier')     AS [buGuid],
           x.r.value('(buType)[1]', 'uniqueidentifier')     AS [buType],
           x.r.value('(buVat)[1]', 'FLOAT')                 AS [buVat],
		   x.r.value('(buCurrencyPtr)[1]', 'uniqueidentifier')  AS [buCurrencyPtr],
           x.r.value('(buCurrencyVal)[1]', 'FLOAT')         AS [buCurrencyVal],
           x.r.value('(btAbbrev)[1]', 'NVARCHAR(250)')      AS [btAbbrev],
           x.r.value('(buNumber)[1]', 'FLOAT')              AS [buNumber],
           x.r.value('(buCostPtr)[1]', 'uniqueidentifier')  AS [buCostPtr],
           x.r.value('(buDate)[1]', 'DATETIME')             AS [buDate],
           x.r.value('(buStorePtr)[1]', 'uniqueidentifier') AS [buStorePtr],
		   x.r.value('(buCustAcc)[1]', 'uniqueidentifier')  AS [buCustAcc],
           x.r.value('(buTotal)[1]', 'FLOAT')               AS [buTotal],
           x.r.value('(buTotalExtra)[1]', 'FLOAT')          AS [buTotalExtra],
           x.r.value('(buTotalDisc)[1]', 'FLOAT')           AS [buTotalDisc],
           x.r.value('(buBonusDisc)[1]', 'FLOAT')           AS [buBonusDisc],
           x.r.value('(biGUID)[1]', 'uniqueidentifier')     AS [biGuid],
           x.r.value('(biStorePtr)[1]', 'uniqueidentifier') AS [biStorePtr],
           x.r.value('(biCostPtr)[1]', 'uniqueidentifier')  AS [biCostPtr],
           x.r.value('(biUnity)[1]', 'FLOAT')               AS [biUnity],
           x.r.value('(biMatPtr)[1]', 'uniqueidentifier')   AS [biMatPtr],
           x.r.value('(biQty)[1]', 'FLOAT')                 AS [biQty],
           x.r.value('(biBillQty)[1]', 'FLOAT')             AS [biBillQty],
           x.r.value('(biPrice)[1]', 'FLOAT')               AS [biPrice],
           x.r.value('(biUnitPrice)[1]', 'FLOAT')           AS [biUnitPrice],
           x.r.value('(biClassPtr)[1]', 'NVARCHAR(250)')    AS [biClassPtr],
           x.r.value('(biDiscount)[1]', 'FLOAT')            AS [biDiscount],
           x.r.value('(biExtra)[1]', 'FLOAT')               AS [biExtra],
           x.r.value('(biBonusDisc)[1]', 'FLOAT')           AS [biBonusDisc],
           x.r.value('(biVat)[1]', 'FLOAT')                 AS [biVat],
           x.r.value('(biUnitDiscount)[1]', 'FLOAT')        AS [biUnitDiscount],
           x.r.value('(biUnitExtra)[1]', 'FLOAT')           AS [biUnitExtra],
           x.r.value('(biCurrencyVal)[1]', 'FLOAT')         AS [biCurrencyVal],
           x.r.value('(biExpireDate)[1]', 'DATETIME')       AS [biExpireDate],
		   x.r.value('(biBonusQnt)[1]', 'FLOAT')            AS [biBonusQnt],
		   x.r.value('(billNotes)[1]', 'NVARCHAR(1000)')		AS [billNotes],
		   x.r.value('(buLcGuid)[1]', 'uniqueidentifier')   AS [buLcGuid],
		   x.r.value('(buLcName)[1]', 'NVARCHAR(250)') +'-'+ x.r.value('(buLcNumber)[1]', 'NVARCHAR(250)')	As [buLcName],
		   x.r.value('(buLcState)[1]', 'BIT')				As [buLcState]
    FROM   @X.nodes('/OrderBills') AS x(r)

	-- New bills 
	INSERT INTO #orderbills
    SELECT  bi.buGUID buGUID,
			buType,
			buVat,
			buCurrencyPtr,
			buCurrencyVal,
			btAbbrev,
			buNumber,
			buCostPtr,
			buDate,
			buStorePtr,
			buCustAcc,
			buTotal,
			buTotalExtra,
			buTotalDisc,
			buBonusDisc,
			bi.biGUID,
			biStorePtr,
			biCostPtr,
			biUnity,
			biMatPtr,
			biQty,
			biBillQty,
			biPrice,
			biUnitPrice,
			biClassPtr,
			biDiscount,
			biExtra,
			biBonusDisc,
			biVAT,
            biUnitDiscount,
            biUnitExtra,
			biCurrencyVal,
			biExpireDate,
			biBonusQnt,
			buNotes,
		    lc.GUID,
			(CASE 
				WHEN @Language <> 0 AND lc.LatinName <> '' THEN lc.LatinName  ELSE lc.Name
			 END) + '-' + Convert(nvarchar(255), lc.Number) AS LcName,
			 lc.State
		FROM vwExtended_bi bi
		INNER JOIN ori000 ori ON ori.BuGuid = bi.buGUID
		INNER JOIN oit000 oit ON oit.guid = ori.TypeGuid
		LEFT JOIN LC000 lc ON bi.buLCGUID = lc.GUID
		WHERE ori.POGuid = @OrderGuid

    SELECT bi.BillGuid,
           Sum(( bi.BiQty * ( bi.BiPrice + BiExtra - BiDiscount ) ) + ( BiVat )
               -
               ( biBonusDisc ))    AS buTotal,
           Sum(Bi.BiQty / ( CASE bi.BiUnity
				WHEN 1 THEN 1 
                              WHEN 2 THEN
                                CASE
                                  WHEN bi.Unit2Fact <> 0 THEN bi.Unit2Fact
                                  ELSE 1
                                END
                              WHEN 3 THEN
                                CASE
                                  WHEN bi.Unit3Fact <> 0 THEN bi.Unit3Fact
                                  ELSE 1
                                END
                            END )) AS Qty,

			Sum(Bi.BiBonusQnt / ( CASE bi.BiUnity
				WHEN 1 THEN 1 
                              WHEN 2 THEN
                                CASE
                                  WHEN bi.Unit2Fact <> 0 THEN bi.Unit2Fact
                                  ELSE 1
                                END
                              WHEN 3 THEN
                                CASE
                                  WHEN bi.Unit3Fact <> 0 THEN bi.Unit3Fact
                                  ELSE 1
                                END
                            END )) AS BonusQnt
    INTO   #billtotal
    FROM   (SELECT DISTINCT ori.oriPOGUID             AS orderGuid,
                            bi.buGUID                 AS BillGuid,
                            bi.biGuid                 AS BiGuid,
                            bi.biUnity                AS BiUnity,
                            bi.biQty                  AS BiQty,
                            mt.Unit2Fact              AS Unit2Fact,
                            mt.Unit3Fact              AS Unit3Fact,
                            ISNULL(bi.biUnitPrice, 0) AS BiPrice,
                            ISNULL(bi.biUnitExtra, 0) AS BiExtra,
                            ISNULL(biUnitDiscount, 0) AS BiDiscount,
                            ISNULL(bi.biBonusDisc, 0) AS biBonusDisc,
                            ISNULL(bi.biVAT, 0)       AS BiVat,
							bi.biBonusQnt             AS BiBonusQnt,
							bi.buLcGuid				  AS BuLcGuid,
							bi.buLcName				  AS BuLcName,
							bi.buLcState			  AS BuLcState
            FROM   #orderbills bi
                   INNER JOIN mt000 mt
                           ON mt.GUID = bi.biMatPtr
                   INNER JOIN vwORI ori
                           ON bi.biGUID = ori.oriBiGUID
                   INNER JOIN oit000 oit
                           ON ori.oriTypeGuid = oit.[Guid]
            WHERE  oit.QtyStageCompleted = 1
                   AND (ori.oriQty > 0 OR ori.oriBonusPostedQty > 0)
                   AND ori.oriType = 0
                   AND ori.oriPOGUID = @OrderGuid) bi
    GROUP  BY bi.orderGuid,
              bi.BillGuid
	INSERT INTO #Result
    SELECT DISTINCT ori.POGUID,
                    bi.buGuid         buGuid,
				    bi.buType         buTypeGuid,
					bi.buCurrencyGuid,
					bi.buCurrencyVal,
					bi.buCustAcc,
                    bi.buDate         buDate,
                    bi.buNumber       buNumber,
                    ( CASE
                        WHEN [oit].[operation] <> 3 THEN
                          CASE
                            WHEN [oit].[operation] = 2 THEN
                              CASE
                                WHEN [ori].[bIsRecycled] = 0 THEN
                                Substring ([ori].[Notes], 4,
                                Len([ori].[Notes]))
                                ELSE [ori].[Notes]
                              END
                            ELSE [ori].[Notes]
                          END
                        ELSE ''
                      END )           AS BuName,
                    billTotal.buTotal / bi.buCurrencyVal  buTotal,
                    billTotal.Qty     TotalQty,
                    ori.bIsRecycled   IsRecycled,
					0,
					0,
					0,
					billTotal.BonusQnt     TotalBonusQnt ,
					bi.billNotes,
					(CASE ori.bIsRecycled WHEN 0 THEN  bi.buLcGuid ELSE TransInfo.LcGuid END),
					(CASE bIsRecycled
						WHEN 0 THEN bi.buLcName
						Else
						(CASE
							WHEN @Language <> 0 AND TransInfo.LcLatinName <> '' THEN TransInfo.LcLatinName  ELSE TransInfo.LcName
						 END) + '-' + Convert(nvarchar(255), TransInfo.LcNumber)
					 END),
					  CASE bIsRecycled WHEN 0 THEN bi.buLcState ELSE TransInfo.LcState END
    FROM   #orderbills bi
           INNER JOIN #billtotal billTotal
                   ON billTotal.BillGuid = bi.buGUID
           INNER JOIN ori000 ori
                   ON ori.BuGuid = bi.buGUID
                      AND ori.BiGuid = bi.biGUID
		   INNER JOIN bu000 bu 
				   ON bu.GUID = ori.POGUID
           INNER JOIN oit000 oit
                   ON oit.guid = ori.TypeGuid
		   LEFT JOIN TransferedOrderBillsInfo000 TransInfo ON TransInfo.TransferOriBuGuid = ori.BuGuid
    WHERE  (ori.Qty > 0 OR ori.BonusPostedQty > 0) AND oit.QtyStageCompleted = 1 
	AND ori.POGuid = @OrderGuid
    GROUP  BY ori.POGUID,
	bi.buGuid, 
	bi.buType,
			  bi.buCurrencyGuid,
			  bi.buCurrencyVal,
			  bi.buCustAcc,
	bi.buDate, 
	bi.buNumber, 
              ( CASE
                  WHEN [oit].[operation] <> 3 THEN
                    CASE
                      WHEN [oit].[operation] = 2 THEN
                        CASE
                          WHEN [ori].[bIsRecycled] = 0 THEN
                          Substring ([ori].[Notes], 4,
                          Len([ori].[Notes]))
                          ELSE [ori].[Notes]
                        END
                      ELSE [ori].[Notes]
                    END
                  ELSE ''
                END ),
              billTotal.buTotal,
              billTotal.Qty,
			  billTotal.BonusQnt,
	ori.bIsRecycled,
	bi.buLcGuid,
	bi.buLcName,
	bi.billNotes,
	bi.buLcState,
	TransInfo.LcGuid,
	TransInfo.LcLatinName,
	TransInfo.LcName,
	TransInfo.LcNumber,
	TransInfo.LcState
    ORDER  BY bi.buDate
	DECLARE @ConnectType INT = 0 
	----------------------—»ÿ «·œ›⁄«  Ì „ „‰ «·ÿ·»Ì…-------------------
	SELECT @ConnectType = 1
	WHERE EXISTS (SELECT * FROM bp000 bp 
								INNER JOIN vwOrderPayments pay ON pay.PaymentGuid = bp.DebtGUID OR pay.PaymentGuid = bp.PayGUID
								WHERE pay.BillGuid = @OrderGuid)
	-----------------------—»ÿ «·œ›⁄«  Ì „ „‰ ›Ê« Ì— «·ÿ·»Ì…---------------
	SELECT @ConnectType = 2
	WHERE EXISTS (SELECT * FROM bp000 bp 
				   WHERE bp.DebtGUID IN (SELECT buGUID FROM #orderbills)
				   OR bp.PayGUID IN (SELECT buGUID FROM #orderbills))
   ------------------------------------------------------------------------------
	DECLARE @OrdGuid UNIQUEIDENTIFIER,
			@BuGuid UNIQUEIDENTIFIER,
	        @BuTotal FLOAT, 
			@BuCurrencyGuid UNIQUEIDENTIFIER,
			@BuCurrencyVal FLOAT,
			@BuCustAccGuid UNIQUEIDENTIFIER, 
			@BuDate DATE
	
	IF (@ConnectType = 1)
	BEGIN
		UPDATE #Result SET Paied = pay.PaiedValue, Remaining = pay.RemainingValue, NotesType = pay.NoteType
		FROM
		#Result r
		INNER JOIN (SELECT * FROM dbo.fnOrdrerBillPayments(@OrderGuid, 0x0)) pay ON pay.BillGuid = r.BuGuid
	END
	
	IF (@ConnectType = 2)
	BEGIN
		CREATE TABLE #Bills(
			OrderGuid UNIQUEIDENTIFIER,
			OrderDate Date,
			OrderNumber INT,
			BillValue FLOAT,
			Paied FLOAT)
		DECLARE @AccountCurrencyGUID UNIQUEIDENTIFIER,
				@Paied FLOAT,
				@OrderCount INT
			
		DECLARE j CURSOR FOR SELECT OrderGuid, BuGuid, BuTotal, BuCurrencyGuid, BuCurrencyVal, BuDate FROM #Result   
		OPEN j  
		FETCH NEXT FROM j INTO @OrdGuid, @BuGuid, @BuTotal, @BuCurrencyGuid, @BuCurrencyVal, @BuDate
		WHILE @@FETCH_STATUS = 0 
		BEGIN 
			SELECT @OrderCount = COUNT(DISTINCT POGUID) FROM ori000 WHERE BuGuid = @BuGuid
			SELECT TOP 1
				@AccountCurrencyGUID = ac.CurrencyGUID 
			FROM 
				bu000 bu 
				INNER JOIN ac000 ac ON ac.GUID = bu.CustAccGUID
			WHERE 
				bu.GUID = @BuGuid
			SET @Paied =  
				(SELECT SUM((CASE WHEN @BuGuid = DebtGUID THEN Val / (CASE CurrencyVal WHEN 0 THEN 1 ELSE CurrencyVal END) 
						ELSE PayVal / (CASE PayCurVal WHEN 0 THEN 1 ELSE PayCurVal END) END) 
					* (CASE WHEN @BuCurrencyGuid = @AccountCurrencyGUID THEN @BuCurrencyVal ELSE [dbo].fnGetCurVal(@AccountCurrencyGUID, @BuDate) END))
					/  @BuCurrencyVal AS Amount
			FROM 
				bp000 
			WHERE 
				((DebtGUID = @BuGuid) OR (PayGUID = @BuGuid)))
			IF( @Paied > 0)
			 BEGIN
				IF(@OrderCount = 1)
				 BEGIN
					UPDATE #Result SET Paied = @Paied, 
					Remaining = @BuTotal - @Paied, NotesType = 1 WHERE BuGuid = @BuGuid
				 END
				ELSE
				 BEGIN
					DECLARE @OrdGuid1 UNIQUEIDENTIFIER,
							@BillValue FLOAT 
               
					INSERT INTO #Bills
					SELECT ori.POGUID,
							bu.Date,
							bu.Number,
							Sum(( bi.BiQty * ( bi.biUnitPrice + bi.biUnitExtra - bi.biUnitDiscount ) ) + ( bi.biVAT ) - ( bi.biBonusDisc )) 
								/ CASE bi.buCurrencyVal WHEN 0 THEN 1 ELSE bi.buCurrencyVal END AS buTotal,
							0
					FROM
							ori000 ori
							INNER JOIN bu000 bu ON bu.Guid = ori.POGUID
							INNER JOIN vwExtended_bi bi ON bi.biGUID = ori.BiGuid
					WHERE
							ori.BuGuid = @BuGuid AND (ori.Qty > 0 OR ori.BonusPostedQty > 0)
					GROUP BY 
							ori.POGUID,
							bu.Date,
							bu.Number,
							bi.buCurrencyVal
					
					DECLARE k CURSOR FOR SELECT OrderGuid, BillValue FROM #Bills ORDER BY OrderDate, OrderNumber ASC
					OPEN k  
					FETCH NEXT FROM k INTO @OrdGuid1, @BillValue
					WHILE @@FETCH_STATUS = 0 
					BEGIN
						IF(@Paied <> 0 AND @Paied >= @BillValue)
						BEGIN
							Update #Bills SET Paied = @BillValue WHERE OrderGuid = @OrdGuid1
							SET @Paied -= @BillValue
						END
						ELSE IF (@Paied <> 0 AND @Paied < @BillValue)
						BEGIN
							Update #Bills SET Paied = @Paied WHERE OrderGuid = @OrdGuid1
							SET @Paied = 0
						END
						FETCH NEXT FROM k INTO @OrdGuid1, @BillValue
					END
					CLOSE k 
					DEALLOCATE k 
			 
					SELECT @Paied = Paied FROM #Bills WHERE OrderGuid = @OrderGuid
					UPDATE #Result SET Paied = @Paied, Remaining = @BuTotal - @Paied, NotesType = CASE WHEN @Paied <> 0 THEN 1 ELSE 0 END WHERE BuGuid = @BuGuid
					DELETE FROM #Bills
				 END
			 END
		  FETCH NEXT FROM j INTO @OrdGuid, @BuGuid, @BuTotal, @BuCurrencyGuid, @BuCurrencyVal, @BuDate
		END
		CLOSE j 
		DEALLOCATE j
	END
	
	SELECT * FROM #Result
	ORDER BY BuNumber
#############################################################################
CREATE FUNCTION fnOrdrerBillPayments( @OrderGuid [UNIQUEIDENTIFIER]=0x0 , @BillGuid [UNIQUEIDENTIFIER] = 0x0)
RETURNS @Result TABLE
(OrderGuid UNIQUEIDENTIFIER,
	BillGuid UNIQUEIDENTIFIER,
	BillCustAccGuid UNIQUEIDENTIFIER,
	BillValue FLOAT,
	PaiedValue FLOAT,
	RemainingValue FLOAT,
	NoteType INT
	)
AS
BEGIN
DECLARE @orderbillsTrn TABLE 
      (
         buGUID         UNIQUEIDENTIFIER,
         buType         UNIQUEIDENTIFIER,
         buVat          FLOAT,
		 buCurrencyGuid UNIQUEIDENTIFIER,
         buCurrencyVal  FLOAT,
         btAbbrev       NVARCHAR(250),
         buNumber       FLOAT,
         buCostPtr      UNIQUEIDENTIFIER,
         buDate         DATE,
         buStorePtr     UNIQUEIDENTIFIER,
		 buCustAcc      UNIQUEIDENTIFIER,
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
         biBillQty      FLOAT,
         biPrice        FLOAT,
         biUnitPrice    FLOAT,
         biClassPtr     NVARCHAR(250),
         biDiscount     FLOAT,
         biExtra        FLOAT,
         biBonusDisc    FLOAT,
         biVAT          FLOAT,
         biUnitDiscount FLOAT,
         biUnitExtra    FLOAT,
         biCurrencyVal  FLOAT,
         biExpireDate   DATETIME
      )
	 
	DECLARE @X xml 

    SELECT @X = BillXmlData
    FROM   TrnOrdBu000
    WHERE  OrderGuid = @OrderGuid

    INSERT INTO @orderbillsTrn
    SELECT x.r.value('(buGUID)[1]', 'uniqueidentifier')     AS [buGuid],
           x.r.value('(buType)[1]', 'uniqueidentifier')     AS [buType],
           x.r.value('(buVat)[1]', 'FLOAT')                 AS [buVat],
		   x.r.value('(buCurrencyPtr)[1]', 'uniqueidentifier')  AS [buCurrencyPtr],
           x.r.value('(buCurrencyVal)[1]', 'FLOAT')         AS [buCurrencyVal],
           x.r.value('(btAbbrev)[1]', 'NVARCHAR(250)')      AS [btAbbrev],
           x.r.value('(buNumber)[1]', 'FLOAT')              AS [buNumber],
           x.r.value('(buCostPtr)[1]', 'uniqueidentifier')  AS [buCostPtr],
           x.r.value('(buDate)[1]', 'DATETIME')             AS [buDate],
           x.r.value('(buStorePtr)[1]', 'uniqueidentifier') AS [buStorePtr],
		   x.r.value('(buCustAcc)[1]', 'uniqueidentifier')  AS [buCustAcc],
           x.r.value('(buTotal)[1]', 'FLOAT')               AS [buTotal],
           x.r.value('(buTotalExtra)[1]', 'FLOAT')          AS [buTotalExtra],
           x.r.value('(buTotalDisc)[1]', 'FLOAT')           AS [buTotalDisc],
           x.r.value('(buBonusDisc)[1]', 'FLOAT')           AS [buBonusDisc],
           x.r.value('(biGUID)[1]', 'uniqueidentifier')     AS [biGuid],
           x.r.value('(biStorePtr)[1]', 'uniqueidentifier') AS [biStorePtr],
           x.r.value('(biCostPtr)[1]', 'uniqueidentifier')  AS [biCostPtr],
           x.r.value('(biUnity)[1]', 'FLOAT')               AS [biUnity],
           x.r.value('(biMatPtr)[1]', 'uniqueidentifier')   AS [biMatPtr],
           x.r.value('(biQty)[1]', 'FLOAT')                 AS [biQty],
           x.r.value('(biBillQty)[1]', 'FLOAT')             AS [biBillQty],
           x.r.value('(biPrice)[1]', 'FLOAT')               AS [biPrice],
           x.r.value('(biUnitPrice)[1]', 'FLOAT')           AS [biUnitPrice],
           x.r.value('(biClassPtr)[1]', 'NVARCHAR(250)')    AS [biClassPtr],
           x.r.value('(biDiscount)[1]', 'FLOAT')            AS [biDiscount],
           x.r.value('(biExtra)[1]', 'FLOAT')               AS [biExtra],
           x.r.value('(biBonusDisc)[1]', 'FLOAT')           AS [biBonusDisc],
           x.r.value('(biVat)[1]', 'FLOAT')                 AS [biVat],
           x.r.value('(biUnitDiscount)[1]', 'FLOAT')        AS [biUnitDiscount],
           x.r.value('(biUnitExtra)[1]', 'FLOAT')           AS [biUnitExtra],
           x.r.value('(biCurrencyVal)[1]', 'FLOAT')         AS [biCurrencyVal],
           x.r.value('(biExpireDate)[1]', 'DATETIME')       AS [biExpireDate]
    FROM   @X.nodes('/OrderBills') AS x(r)
	


	IF(ISNULL(@OrderGuid, 0x0) = 0x0 AND ISNULL(@BillGuid, 0x0) = 0x0)
		RETURN;
	--------------›Ì Õ«· ﬂ«‰ «·—»ÿ ﬁœ  „ „‰ «·›« Ê—…------------------
	IF EXISTS (SELECT * FROM bp000 bp WHERE bp.DebtGUID = @BillGuid OR bp.PayGUID = @BillGuid)
		RETURN;   
	--------------›Ì Õ«· ·« ÌÊÃœ œ›⁄«  „— »ÿ… »«·ÿ·»Ì… «·Õ«·Ì…------------------
	IF NOT EXISTS (SELECT * FROM bp000 bp WHERE bp.ParentDebitGUID = @OrderGuid OR bp.ParentPayGUID = @OrderGuid)
		RETURN;
	-------------------------------------------------------------------------------
	DECLARE @Orders TABLE(OrderGuid UNIQUEIDENTIFIER)
	DECLARE @TempBills TABLE(OrderGuid UNIQUEIDENTIFIER,
							 BillGuid UNIQUEIDENTIFIER,
							 BillCustAccGuid UNIQUEIDENTIFIER,
							 BillValue FLOAT,
							 PaiedValue FLOAT,
							 RemainingValue FLOAT,
							 NoteType INT,
							 number INT,
							 trn INT
							 )
	DECLARE @FinalBills TABLE(OrderGuid UNIQUEIDENTIFIER,
							 BillGuid UNIQUEIDENTIFIER,
							 BillCustAccGuid UNIQUEIDENTIFIER,
							 BillValue FLOAT,
							 PaiedValue FLOAT,
							 RemainingValue FLOAT,
							 NoteType INT,
							 number INT
							 )
	DECLARE		@OrdGuid UNIQUEIDENTIFIER,
				@TotalPayment FLOAT,
				@OrderCurGUID UNIQUEIDENTIFIER,
				@OrderCurVal FLOAT,
				@OrderCustAccGuid UNIQUEIDENTIFIER,
				@trn INT,
				@BuGuid UNIQUEIDENTIFIER,
				@BuTotal FLOAT, 
				@BuCurrencyGuid UNIQUEIDENTIFIER,
				@BuCurrencyVal FLOAT,
				@BuCustAccGuid UNIQUEIDENTIFIER, 
				@BuDate DATE,
				@ConnectFlag BIT = 1,
	            @Ord_Cursor CURSOR,
				@Bill_Cursor CURSOR
------------------------ÃœÊ· «·ÿ·»Ì«  «· Ì  Ê·œ  ⁄‰Â« «·›« Ê—… «·Õ«·Ì…---------------
	IF(ISNULL(@OrderGuid, 0x0) = 0x0 AND ISNULL(@BillGuid, 0x0) <> 0x0)
	BEGIN
	    INSERT INTO @Orders
		SELECT DISTINCT
			POGUID
		FROM 
			ori000 ori
		WHERE
			ori.BuGuid = @BillGuid AND ori.Qty > 0

	END
	ELSE
	BEGIN
		INSERT INTO @Orders(OrderGuid) VALUES (@OrderGuid)
	END
	------------›Ì Õ«· ﬂ«‰  «·›« Ê—… €Ì— „Ê·œ… „‰ ÿ·»Ì…------------
	IF NOT EXISTS(SELECT * FROM @Orders)
		RETURN;
	------------›Ì Õ«· ﬂ«‰  «·ÿ·»Ì… √Ê «·ÿ·»Ì«  «·Õ«·Ì… ·Ì” ·Â« œ›⁄«  „”œœ…-----------
	IF NOT EXISTS(SELECT * FROM bp000 WHERE ParentDebitGUID IN (SELECT OrderGuid FROM @Orders)
	               OR ParentPayGUID IN (SELECT OrderGuid FROM @Orders))
		RETURN;
	--------------------------------------------------------------------

	SET @Ord_Cursor = CURSOR FAST_FORWARD FOR  SELECT OrderGuid FROM @Orders  
	OPEN @Ord_Cursor  
	FETCH NEXT FROM @Ord_Cursor INTO @OrdGuid
	WHILE @@FETCH_STATUS = 0  
	BEGIN
		INSERT @TempBills 
		SELECT POGUID,
			   ori.BuGuid,
			   bi.buCustAcc,
			   Sum(( bi.BiQty * ( bi.biUnitPrice + bi.biUnitExtra - bi.biUnitDiscount ) ) + ( bi.biVAT ) - ( bi.biBonusDisc ))
				/ CASE bi.buCurrencyVal WHEN 0 THEN 1 ELSE bi.buCurrencyVal END,
			   0,
			   0,
			   0,
			   bi.buNumber,
			   0
		FROM
			   ori000 ori
			   INNER JOIN oit000 oit ON oit.GUID = ori.TypeGuid
			   INNER JOIN vwExtended_bi bi ON bi.biGUID = ori.BiGuid
		WHERE 
			    ori.Qty > 0 
			    AND ori.POGUID = @OrdGuid
			    AND oit.QtyStageCompleted = 1
		GROUP BY
			   POGUID,
			   ori.BuGuid,
			   bi.buCustAcc,
			   bi.buCurrencyVal,
			   bi.buNumber

		INSERT @TempBills 
		SELECT POGUID,
			   ori.BuGuid,
			   t.buCustAcc,
			   Sum(( t.BiQty * ( t.biUnitPrice + t.biUnitExtra - t.biUnitDiscount ) ) + ISNULL(t.biVAT,0 ) - ISNULL( t.biBonusDisc ,0))
				/ CASE t.buCurrencyVal WHEN 0 THEN 1 ELSE t.buCurrencyVal END,
			   0,
			   0,
			   0,
			   t.buNumber,
			   1
		FROM
			   ori000 ori
			   INNER JOIN oit000 oit ON oit.GUID = ori.TypeGuid
			   INNER join @orderbillsTrn t ON t.biGUID=ori.BiGuid
		WHERE 
			    ori.Qty > 0 
			    AND ori.POGUID = @OrdGuid
			    AND oit.QtyStageCompleted = 1
		GROUP BY
			   POGUID,
			   ori.BuGuid,
			   t.buCustAcc,
			   t.buCurrencyVal,
			   t.buNumber
		
		SELECT @OrderCurGUID = CurrencyGUID, @OrderCurVal = CurrencyVal, @OrderCustAccGuid = CustAccGUID FROM bu000 WHERE GUID = @OrdGuid
		SELECT
			@TotalPayment = SUM([FixedBpVal]) 
		FROM
			vworderpayments AS Pay
			INNER JOIN [fnBp_Fixed](@OrderCurGUID, @OrderCurVal) bp ON bp.BpPayGUID = Pay.PaymentGuid OR bp.BpDebtGUID = Pay.PaymentGuid
		WHERE
			Pay.billGuid = @OrdGuid
		GROUP BY
			Pay.BillGuid
		IF (@TotalPayment <> 0)
		BEGIN 
			SET @Bill_Cursor = CURSOR FAST_FORWARD FOR  SELECT BillGuid, BillValue, BillCustAccGuid,trn FROM @TempBills order by number     
			OPEN @Bill_Cursor   
			FETCH NEXT FROM @Bill_Cursor  INTO @BuGuid, @BuTOtal, @BuCustAccGuid,@trn
			WHILE @@FETCH_STATUS = 0  
			BEGIN
				IF (@TotalPayment <> 0)
				BEGIN
					IF(@BuCustAccGuid <> @OrderCustAccGuid)
					BEGIN
						Update @TempBills SET NoteType = 3 WHERE BillGuid = @BuGuid
						SET @ConnectFlag = 0
					END
					IF NOT EXISTS(SELECT EntryGUID FROM er000 WHERE ParentGUID = @BuGuid) AND @trn=0
					BEGIN
					
						Update @TempBills SET NoteType = 4 WHERE BillGuid = @BuGuid
						SET @ConnectFlag = 0
					END
				
					IF(@TotalPayment >= @BuTotal AND @ConnectFlag = 1)
					BEGIN
						Update @TempBills SET PaiedValue = @BuTotal, NoteType = 2 WHERE BillGuid = @BuGuid
						SET @TotalPayment -= @BuTotal 
					END
					ELSE IF (@TotalPayment < @BuTotal AND @ConnectFlag = 1)
					BEGIN
						Update @TempBills SET PaiedValue = @TotalPayment, NoteType = 2 WHERE BillGuid = @BuGuid
						SET @TotalPayment = 0
					END
				END
				SET @ConnectFlag = 1
				FETCH NEXT FROM @Bill_Cursor  INTO  @BuGuid, @BuTOtal, @BuCustAccGuid,@trn
			END	
		END
		
	INSERT
	    @FinalBills 
	SELECT 
		OrderGuid ,
		BillGuid ,
		BillCustAccGuid ,
		BillValue ,
		PaiedValue ,
		RemainingValue ,
		NoteType ,
		number
	FROM 
		@TempBills b 
	WHERE 
		b.OrderGuid = CASE ISNULL(@OrderGuid, 0x0) WHEN 0x0 THEN b.OrderGuid ELSE @OrderGuid END
		AND b.BillGuid = CASE ISNULL(@BillGuid, 0x0) WHEN 0x0 THEN b.BillGuid ELSE @BillGuid END
	DELETE FROM @TempBills
	FETCH NEXT FROM @Ord_Cursor INTO  @OrdGuid
	END
	
	CLOSE @Bill_Cursor  
	DEALLOCATE @Bill_Cursor 
	CLOSE @Ord_Cursor  
	DEALLOCATE @Ord_Cursor 
	------------------Õ”«» «·„”œœ Ê«·»«ﬁÌ ·›« Ê—… „⁄Ì‰… ---------------
	IF(@BillGuid <> 0x0 AND @OrderGuid = 0x0)
	BEGIN
		INSERT @Result 
		SELECT 
		      0x0,
			  BillGuid,
			  b.BillCustAccGuid,
			  SUM(b.BillValue),
			  SUM(b.PaiedValue),
			  SUM(b.BillValue) - SUM(b.PaiedValue),
			  2
		FROM @FinalBills b
		GROUP BY
		      BillGuid,
			  b.BillCustAccGuid
		END
	ELSE
	BEGIN
		INSERT @Result 
		SELECT 
		      b.OrderGuid,
			  b.BillGuid,
			  b.BillCustAccGuid,
			  b.BillValue,
			  b.PaiedValue,
			  b.BillValue - b.PaiedValue,
			  b.NoteType
		FROM @FinalBills b
	END
	RETURN
END
#############################################################################
CREATE FUNCTION fnBillOfOrder_GetPaiedValue(@BillGuid [UNIQUEIDENTIFIER])
	RETURNS FLOAT 
AS 
BEGIN 
	RETURN ISNULL((SELECT SUM(PaiedValue) FROM dbo.fnOrdrerBillPayments(DEFAULT, @BillGuid)), 0)
END 
#############################################################################
CREATE PROCEDURE prcGetBillsItems2
@OrderGuid [uniqueidentifier],
@BillGuid [uniqueidentifier],
@BillType [uniqueidentifier]
AS 
	SET NOCOUNT ON 
	DECLARE @temp table 
	( 
		[GUID] [uniqueidentifier]
	) 
	 
 
	BEGIN 
		INSERT @temp SELECT 
			bu.[GUID] 
		FROM
			bu000 bu
		WHERE
				bu.[GUID] = @BillGuid
				and dbo.fnGetUserBillSec_Browse([dbo].[fnGetCurrentUserGUID](), bu.typeguid)>0
		ORDER BY bu.typeGuid, bu.number 
	END 
	CREATE TABLE #OrderBills(
	buGUID UNIQUEIDENTIFIER,
	buType UNIQUEIDENTIFIER,
	buVat FLOAT,
	buCurrencyVal FLOAT,
	btAbbrev NVARCHAR(250),
	buNumber FLOAT,
	buCostPtr UNIQUEIDENTIFIER,
	buDate DATETIME,
	buStorePtr UNIQUEIDENTIFIER,
	buTotal FLOAT,
	buTotalExtra FLOAT,
	buTotalDisc FLOAT,
	buBonusDisc FLOAT,
	biGUID UNIQUEIDENTIFIER,
	biStorePtr UNIQUEIDENTIFIER,
	biCostPtr UNIQUEIDENTIFIER,
	biUnity FLOAT,
	biMatPtr UNIQUEIDENTIFIER,
	biQty FLOAT,
	biBillQty FLOAT,
	biPrice FLOAT,
	biUnitPrice FLOAT,
	biClassPtr NVARCHAR(250),
	biDiscount FLOAT,
	biExtra FLOAT,
	biBonusDisc FLOAT,
	biVAT FLOAT,
	biCurrencyVal FLOAT,
	biExpireDate DATETIME,
	biBonusQnt  FLOAT,
	biBillBonusQnt FLOAT
	)
	
	DECLARE @X xml 
	SELECT @X = BillXmlData from TrnOrdBu000 Where OrderGuid = @OrderGuid
	--Old bills from transfered file
	INSERT INTO #OrderBills
	SELECT  x.r.value('(buGUID)[1]', 'uniqueidentifier') as [buGuid],
		x.r.value('(buType)[1]', 'uniqueidentifier') as [buType],
		x.r.value('(buVat)[1]', 'FLOAT') as [buVat],
		x.r.value('(buCurrencyVal)[1]', 'FLOAT') as [buCurrencyVal],
		x.r.value('(btAbbrev)[1]', 'NVARCHAR(250)') as [btAbbrev],
		x.r.value('(buNumber)[1]', 'FLOAT') as [buNumber],
		x.r.value('(buCostPtr)[1]', 'uniqueidentifier') as [buCostPtr],
		x.r.value('(buDate)[1]', 'DATETIME') as [buDate],
		x.r.value('(buStorePtr)[1]', 'uniqueidentifier') as [buStorePtr],
		x.r.value('(buTotal)[1]', 'FLOAT') as [buTotal],
		x.r.value('(buTotalExtra)[1]', 'FLOAT') as [buTotalExtra],
		x.r.value('(buTotalDisc)[1]', 'FLOAT') as [buTotalDisc],
		x.r.value('(buBonusDisc)[1]', 'FLOAT') as [buBonusDisc],
		x.r.value('(biGuid)[1]', 'uniqueidentifier') as [biGuid],
		x.r.value('(biStorePtr)[1]', 'uniqueidentifier') as [biStorePtr],
		x.r.value('(biCostPtr)[1]', 'uniqueidentifier') as [biCostPtr],
		x.r.value('(biUnity)[1]', 'FLOAT') as [biUnity],
		x.r.value('(biMatPtr)[1]', 'uniqueidentifier') as [biMatPtr],
		x.r.value('(biQty)[1]', 'FLOAT') as [biQty],
		x.r.value('(biBillQty)[1]', 'FLOAT') as [biBillQty],
		x.r.value('(biPrice)[1]', 'FLOAT') as [biPrice],
		x.r.value('(biUnitPrice)[1]', 'FLOAT') as [biUnitPrice],
		x.r.value('(biClassPtr)[1]', 'NVARCHAR(250)') as [biClassPtr],
		x.r.value('(biDiscount)[1]', 'FLOAT') as [biDiscount],
		x.r.value('(biExtra)[1]', 'FLOAT') as [biExtra],
		x.r.value('(biBonusDisc)[1]', 'FLOAT') as [biBonusDisc],
		x.r.value('(biVat)[1]', 'FLOAT') as [biVat],
		x.r.value('(biCurrencyVal)[1]', 'FLOAT') as [biCurrencyVal],
		x.r.value('(biExpireDate)[1]', 'DATETIME') as [biExpireDate],
		x.r.value('(biBonusQnt)[1]', 'FLOAT')        AS [biBonusQnt],
		x.r.value('(biBillBonusQnt)[1]', 'FLOAT')     AS [biBillBonusQnt]
		FROM   
				@X.nodes('/OrderBills') as x(r)
		
	-- New bills 
	INSERT INTO #OrderBills
		SELECT 
			bi.buGUID
			buGUID,
			buType,
			buVat,
			buCurrencyVal,
			btAbbrev,
			buNumber,
			buCostPtr,
			buDate,
			buStorePtr,
			buTotal,
			buTotalExtra,
			buTotalDisc,
			buBonusDisc,
			bi.biGUID,
			biStorePtr,
			biCostPtr,
			biUnity,
			biMatPtr,
			biQty,
			biBillQty,
			biPrice,
			biUnitPrice,
			biClassPtr,
			biDiscount,
			biExtra,
			biBonusDisc,
			biVAT,
			biCurrencyVal,
			biExpireDate ,
			biBonusQnt,
			biBillBonusQnt
		FROM vwExtended_bi bi
		WHERE bi.[buGUID] IN (SELECT [GUID] FROM @temp) AND bi.biGUID IN (SELECT BiGuid FROM ori000 WHERE POGUID = @OrderGuid)
		ORDER BY bi.biNumber
	DELETE FROM #OrderBills
	WHERE buGUID <> @BillGuid
	SELECT
	bi.buGUID AS BillGuid,
	mt.[Guid] AS [MatGuid],
	bi.buDate [buDate],
	bi.buNumber [buNumber],
	mt.code AS [MatCode],
	mt.name AS [MatName],
	ISNULL(mt.LatinName, '') AS [MatLatinName],
	mt.CompositionName AS [CompositionName],
	mt.CompositionLatinName AS [CompositionLatinName],
	bi.biBillQty AS [MatQty],
	bi.biPrice/bi.buCurrencyVal AS [MatPrice],
	bi.biBillQty*bi.biPrice/bi.buCurrencyVal AS [MatTotal], 
	CASE  WHEN bi.biUnity = 1 THEN mt.[BarCode] WHEN bi.biUnity = 2 THEN mt.[BarCode2] ELSE mt.[BarCode3] END AS [BarCode], 
	ISNULL(mt.[Dim], '') AS [Dim], 
	ISNULL(mt.[Origin], '') AS [Origin], 
	ISNULL(mt.[Pos], '') AS [Pos], 
	ISNULL(mt.[Company], '') AS [Company], 
	ISNULL(mt.[Color], '') AS [Color], 
	ISNULL(mt.[Provenance], '') AS [Provenance], 
	ISNULL(mt.[Quality], '') AS [Quality], 
	ISNULL(mt.[Model], '') AS [Model], 
	ISNULL(gr.[Name], '')  AS [group] ,
	ISNULL(gr.[LatinName], '')  [Latingroup] ,
		
	bi.biDiscount AS Disc,
	CASE WHEN (bi.biPrice != 0 AND bi.biQty != 0 )  THEN (bi.biDiscount / (bi.biQty*bi.biPrice/bi.buCurrencyVal)) * 100 ELSE 0 END AS PercntDisc,
	bi.biExtra AS Extra,
	CASE WHEN (bi.biPrice != 0 AND bi.biQty != 0 )  THEN (bi.biExtra / (bi.biQty*bi.biPrice/bi.buCurrencyVal) ) * 100  ELSE 0 END AS PercntExtra,
	bi.biVat AS VAT,
	CASE bi.biUnity 
			WHEN 1 THEN  mt.Unity  
			WHEN 2 THEN  mt.Unit2 
			WHEN 3 THEN  mt.Unit3   
	END AS UnityName,
	bi.biBillBonusQnt AS [MatBonusQnt]
	FROM #OrderBills bi
	INNER JOIN mt000 mt ON mt.[guid]=bi.biMatPtr
	LEFT  JOIN gr000 gr ON mt.GroupGuid=gr.[guid] 
	ORDER BY bi.buDate, bi.buNumber
#############################################################################
#END
