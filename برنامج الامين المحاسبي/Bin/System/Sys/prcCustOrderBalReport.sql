################################################################
CREATE PROCEDURE prcCustOrderBalReport
  -- Params ---------------------------   
  @Cust               UNIQUEIDENTIFIER = 0x00,
  @AccountGuid        UNIQUEIDENTIFIER = 0x00,
  @Cost               UNIQUEIDENTIFIER = 0x00,
  @CurGUID            UNIQUEIDENTIFIER = 0x00,
  @PayType            INT = 0,
  @StartDate          DATETIME = '1/1/1980',
  @EndDate            DATETIME = '1/1/2020',
  @OrderTypesSrc      UNIQUEIDENTIFIER = 0x00,
  @OrderCond          UNIQUEIDENTIFIER = 0x00,
  @ShowFinishedOrders BIT = 0 --ÊÖãíä ÇáØáÈíÇÊ ÇáãäÊåíÉ  
-------------------------------------   
AS
    SET NOCOUNT ON
	DECLARE @Lang INT = dbo.fnConnections_GetLanguage();
    ------------------------------------------------------------------      
    CREATE TABLE #CustTbl
      (
         CustGuid UNIQUEIDENTIFIER,
         Security INT
      )
    INSERT INTO #CustTbl
    EXEC prcGetCustsList
      @Cust,
      @AccountGuid,
      NULL
    IF ISNULL(@Cust, 0x0) = 0x0
      INSERT INTO #CustTbl
      VALUES     (0x0,
                  1)
    -------------------------------------------------------------------   
    CREATE TABLE #OrderTypesTbl
      (
         Type        UNIQUEIDENTIFIER,
         Sec         INT,
         ReadPrice   INT,
         UnPostedSec INT
      )
    INSERT INTO #OrderTypesTbl
    EXEC prcGetBillsTypesList2
      @OrderTypesSrc
    -------------------------------------------------------------------        
    CREATE TABLE #OrdersTbl
      (
         OrderGuid UNIQUEIDENTIFIER,
         Security  INT
      )
    INSERT INTO #OrdersTbl
                (OrderGuid,
                 Security)
    EXEC prcGetOrdersList
      @OrderCond
    -------------------------------------------------------------------------   
    CREATE TABLE [#CostTbl]
      (
         [CostGuid] [UNIQUEIDENTIFIER],
         [Security] [INT],
         [Name]     [NVARCHAR](256) COLLATE ARABIC_CI_AI
      )
    INSERT INTO [#CostTbl]
                ([CostGuid],
                 [Security])
    EXEC [dbo].[prcGetCostsList]
      @Cost
    IF ( ISNULL(@Cost, 0X0) = 0X0 )
      INSERT INTO [#CostTbl]
      VALUES      (0X0,
                   0,
                   '')
    ------------------------------------------------------------------------- 
    SELECT (CASE @Lang WHEN 0 THEN vw.btName ELSE (CASE vw.btLatinName WHEN N'' THEN vw.btName ELSE vw.btLatinName END) END ) + '-'
           + Cast(vw.buNumber AS NVARCHAR(10))            buName,
           vw.buGUID,
           vw.biGUID,
           vw.biNumber,
           vw.biMatPtr,
           (CASE @Lang WHEN 0 THEN vw.MtName ELSE (CASE vw.mtLatinName WHEN N'' THEN vw.MtName ELSE vw.mtLatinName END) END )    MtName,
		   vw.MtCode									  MtCode,
           vw.buPayType,
           cut.AccountGUID                                buCustAcc,
           acc.Code + '-' +  (CASE @Lang WHEN 0 THEN acc.NAME ELSE (CASE acc.LatinName WHEN N'' THEN acc.NAME ELSE acc.LatinName END) END )  COLLATE ARABIC_CI_AI buCustAccName,
           (CASE @Lang WHEN 0 THEN cut.CustomerName ELSE (CASE cut.LatinName WHEN N'' THEN cut.CustomerName ELSE cut.LatinName END) END )   buCustName,
           vw.biBillQty,
           ( CASE vw.biUnity
               WHEN 1 THEN vw.MtUnity
               WHEN 2 THEN vw.MtUnit2
               WHEN 3 THEN vw.MtUnit3
             END )                                        biUnitName,
           ( CASE vw.biUnity
               WHEN 1 THEN 1
               WHEN 2 THEN
                 CASE vw.mtUnit2Fact
                   WHEN 0 THEN 1
                   ELSE vw.mtUnit2Fact
                 END
               WHEN 3 THEN
                 CASE vw.mtUnit3Fact
                   WHEN 0 THEN 1
                   ELSE vw.mtUnit3Fact
                 END
             END )                                        biUnitFact,
           (dbo.fnCurrency_fix(vw.biUnitPrice, vw.buCurrencyPtr, vw.buCurrencyVal, @CurGUID, vw.buDate)) up,
           vw.btVATSystem,
           vw.biVATr,
           vw.buCurrencyPtr,
           vw.buCurrencyVal,
           vw.buDate,
           vw.btIsInput,         
           inf.Finished,
           ( ( CASE inf.Finished
                 WHEN 1 THEN 0
                 ELSE vw.biUnitPrice
               END ) * vw.biBillQty )                     AS biTotal,
           Sum(CASE
                 WHEN oit.QtyStageCompleted = 1 THEN ( CASE
                                                         WHEN ori.[Type] = 0 THEN ori.Qty / ( CASE vw.biUnity
                                                                                                WHEN 2 THEN
                                                                                                  CASE vw.mtUnit2Fact
                                                                                                    WHEN 0 THEN 1
                                                                                                    ELSE vw.mtUnit2Fact
                                                                                                  END
                                                                                                WHEN 3 THEN
                                                                                                  CASE vw.mtUnit3Fact
                                                                                                    WHEN 0 THEN 1
                                                                                                    ELSE vw.mtUnit3Fact
                                                                                                  END
                                                                                                ELSE 1
                                                                                              END )
                                                         ELSE 0
                                                       END )
                 ELSE 0
               END)                                       AS biAcheivedQty,			 
			   SUM(ori.BonusPostedQty) AS BonusPostedQty
    INTO   #Ordered_temp
    FROM   vwExtended_bi vw
           INNER JOIN #OrderTypesTbl bt
                   ON bt.Type = vw.buType
           INNER JOIN #OrdersTbl bu
                   ON bu.OrderGuid = vw.buGUID
           INNER JOIN #CustTbl cu
                   ON cu.CustGuid = vw.buCustPtr
           INNER JOIN cu000 cut
                   ON cu.CustGuid = cut.GUID
           INNER JOIN #CostTbl co
                   ON co.[CostGuid] = vw.biCostPtr
           LEFT JOIN ac000 acc
                  ON acc.GUID = cut.AccountGUID
           INNER JOIN ori000 ori
                   ON ori.POIGUID = vw.biGUID
                      AND ori.POGUID = vw.buGUID
           INNER JOIN oit000 oit
                   ON oit.GUID = ori.TypeGuid
           INNER JOIN ORADDINFO000 inf
                   ON inf.ParentGuid = vw.buGUID
    WHERE  vw.buPayType = ( CASE @PayType
                              WHEN -1 THEN vw.buPayType
                              ELSE @PayType
                            END )
           AND vw.buDate BETWEEN @StartDate AND @EndDate
           AND ( ( inf.Finished = 0 )
                  OR ( inf.Finished IN ( 1, 2 )
                       AND @ShowFinishedOrders = 1 ) )
           AND inf.Add1 = '0'
           AND ( ( oit.QtyStageCompleted = 0 )
                  OR ( oit.QtyStageCompleted = 1
                       AND ori.Qty > 0 ) )
    GROUP  BY (CASE @Lang WHEN 0 THEN vw.btName ELSE (CASE vw.btLatinName WHEN N'' THEN vw.btName ELSE vw.btLatinName END) END )  + '-'
              + Cast(vw.buNumber AS NVARCHAR(10)),
              vw.buGUID,
              vw.biGUID,
              vw.biNumber,
              vw.biMatPtr,
             (CASE @Lang WHEN 0 THEN vw.MtName ELSE (CASE vw.mtLatinName WHEN N'' THEN vw.MtName ELSE vw.mtLatinName END) END ) ,
			  vw.MtCode,
              vw.buPayType,
              cut.AccountGUID,
             acc.Code + '-' +  (CASE @Lang WHEN 0 THEN acc.NAME ELSE (CASE acc.LatinName WHEN N'' THEN acc.NAME ELSE acc.LatinName END) END ) COLLATE ARABIC_CI_AI,
               (CASE @Lang WHEN 0 THEN cut.CustomerName ELSE (CASE cut.LatinName WHEN N'' THEN cut.CustomerName ELSE cut.LatinName END) END ) ,
              vw.biBillQty,
              ( CASE vw.biUnity
                  WHEN 1 THEN vw.MtUnity
                  WHEN 2 THEN vw.MtUnit2
                  WHEN 3 THEN vw.MtUnit3
                END ),
              ( CASE vw.biUnity
                  WHEN 1 THEN 1
                  WHEN 2 THEN
                    CASE vw.mtUnit2Fact
                      WHEN 0 THEN 1
                      ELSE vw.mtUnit2Fact
                    END
                  WHEN 3 THEN
                    CASE vw.mtUnit3Fact
                      WHEN 0 THEN 1
                      ELSE vw.mtUnit3Fact
                    END
                END ),
              vw.biUnitPrice,
              vw.btVATSystem,
              vw.biVATr,
              vw.buCurrencyPtr,
              vw.buCurrencyVal,
              vw.buDate,
              vw.btIsInput,
              inf.Finished            
    ---------------------------------------------------------------------------------- 
    SELECT vw.buName,
           vw.buGUID,
           vw.biGUID,
           vw.biNumber,
           vw.biMatPtr,
           vw.MtName,
		   vw.MtCode,
           vw.buPayType,
           vw.buCustAcc,
           vw.buCustAccName,
           vw.buCustName,
           vw.biBillQty,
           ( dbo.fnCurrency_fix(vw.up * ( 1 + vw.biVATr / 100 ) * vw.biUnitFact * vw.biBillQty, vw.buCurrencyPtr, vw.buCurrencyVal, @CurGUID, vw.buDate) )                      AS biOrderedTotal,
           vw.biUnitName,
           vw.biAcheivedQty,
           ( dbo.fnCurrency_fix(vw.up * ( 1 + vw.biVATr / 100 ) * vw.biUnitFact * vw.biAcheivedQty, vw.buCurrencyPtr, vw.buCurrencyVal, @CurGUID, vw.buDate) )                  AS biAcheivedPrice,
           ( dbo.fnCurrency_fix(vw.up * ( 1 + vw.biVATr / 100 ) * vw.biUnitFact, vw.buCurrencyPtr, vw.buCurrencyVal, @CurGUID, vw.buDate) )                                     AS biUnitPrice,
           vw.biUnitFact,
           vw.buDate,
           vw.btIsInput,
           vw.Finished,
           ( CASE
               WHEN ( vw.biBillQty - vw.biAcheivedQty > 0 ) THEN ( vw.biBillQty - vw.biAcheivedQty )
               ELSE 0
             END )                                                                                                                                                              biRemainedQty,
           ( dbo.fnCurrency_fix(CASE vw.Finished
                                  WHEN 0 THEN vw.up
                                  ELSE 0
                                END * ( 1 + vw.biVATr / 100 ) * vw.biUnitFact * ( CASE
                                                                                    WHEN ( vw.biBillQty > vw.biAcheivedQty ) THEN ( vw.biBillQty - vw.biAcheivedQty )
                                                                                    ELSE 0
                                                                                  END ), vw.buCurrencyPtr, vw.buCurrencyVal, @CurGUID, vw.buDate) ) AS biRemainedPrice,		   
		   vw.BonusPostedQty		  
           ---- Discount is Remained Qty Discount = biDiscountRatio * biRemainedPrice 
           --( vw.biDiscount / CASE vw.biTotal
           --                    WHEN 0 THEN 1
           --                    ELSE vw.biTotal
           --                  END ) * ( dbo.fnCurrency_fix(vw.up * ( 1 + vw.biVATr / 100 ) * vw.biUnitFact * ( CASE
           --                                                                                                     WHEN ( vw.biBillQty > vw.biAcheivedQty ) THEN ( vw.biBillQty - vw.biAcheivedQty )
           --                                                                                                     ELSE 0
           --                                                                                                   END ), vw.buCurrencyPtr, vw.buCurrencyVal, @CurGUID, vw.buDate) ) AS Discount,
           --( vw.biDiscount / CASE vw.biTotal
           --                    WHEN 0 THEN 1
           --                    ELSE vw.biTotal
           --                  END )                                                                                                                                              AS DiscountRatio,
           ---- Extra is Only for Remained Qty = biExtraRatio * biRemainedPrice 
           --( vw.biExtra / CASE vw.biTotal
           --                 WHEN 0 THEN 1
           --                 ELSE vw.biTotal
           --               END ) * ( dbo.fnCurrency_fix(vw.up * ( 1 + vw.biVATr / 100 ) * vw.biUnitFact * ( CASE
           --                                                                                                  WHEN ( vw.biBillQty > vw.biAcheivedQty ) THEN ( vw.biBillQty - vw.biAcheivedQty )
           --                                                                                                  ELSE 0
           --                                                                                                END ), vw.buCurrencyPtr, vw.buCurrencyVal, @CurGUID, vw.buDate) )    AS Extra,
           --( vw.biExtra / CASE vw.biTotal
           --                 WHEN 0 THEN 1
           --                 ELSE vw.biTotal
           --               END )                                                                                                                                                 AS ExtraRatio
    INTO   #Ordered
    FROM   #Ordered_temp vw
    ------------------------------------------------------------------------------   
	DECLARE @RemainedPrieAccBal TABLE
      (
         CustAccGuid		UNIQUEIDENTIFIER,
         btIsInput			INT,
         RemainedPrice		FLOAT
      )
	INSERT INTO @RemainedPrieAccBal
	SELECT ORD1.buCustAcc, ORD1.btIsInput, buRemainedPrice
    FROM   #Ordered AS ORD1,
           (SELECT ORD2.buGUID,
                   ( CASE ORD2.Finished
                       WHEN 0 THEN Sum(ORD2.biRemainedQty / ( CASE
                                                                WHEN ORD2.biUnitFact = 0 THEN 1
                                                                ELSE ORD2.biUnitFact
                                                              END ) * ORD2.biUnitPrice)
                       ELSE 0
                     END ) AS buRemainedPrice
            FROM   #Ordered AS ORD2
            GROUP  BY ORD2.buGUID,
                      ORD2.Finished) O
    WHERE  O.buGUID = ORD1.buGUID
    ORDER  BY buCustAccName,
              buDate,
              buName,
              biNumber


    DECLARE @AccBal TABLE
      (
         buCustAccGuid UNIQUEIDENTIFIER,
         buCustAccName NVARCHAR(255) COLLATE ARABIC_CI_AI,
         buCustName    NVARCHAR(255) COLLATE ARABIC_CI_AI,
         buCustAccBal  FLOAT,
		 InputRemainedPrice float,
		 OutputRemainedPrice float
      )
    INSERT INTO @AccBal
    SELECT DISTINCT ord.buCustAcc,
                    ord.buCustAccName,
                    ord.buCustName,
                    0,
					0,
					0
    FROM   #Ordered ord
    UPDATE @AccBal
    SET    buCustAccBal = (SELECT dbo.fnAccount_getBalance(buCustAccGuid, @CurGUID, '1/1/1980', NULL, @Cost))
    -------------------------------------------------------------------------------           
    SELECT ord.buCustAccName,
           ord.buName,
           ord.biNumber,
           ord.buDate,
           ord.biGUID,
           ord.buGUID,
           ori.TypeGuid StateGuid,
           Sum(ori.Qty) StateQty
    INTO   #StatesQty
    FROM   #Ordered ord
           INNER JOIN ori000 ori
                   ON ord.biGUID = ori.POIGuid
    GROUP  BY ord.buCustAccName,
              ord.buName,
              ord.biNumber,
              ord.buDate,
              ord.biGUID,
              ord.buGUID,
              ori.TypeGuid,
              ord.biBillQty

	------------------------------------------------------------------------------- 	
	------- fill Materials (order details) table
	SELECT ORD1.*,
		   ORD1.mtName + ' - ' + ORD1.mtCode AS Material,
           buRemainedPrice,
		   ((bi.FixedTotalDiscountPercent * biRemainedQty) / biBillQty) AS TotalDiscount,
		   ((bi.FixedTotalExtraPercent * biRemainedQty) / biBillQty) AS TotalExtra,
		   (((bi.FixedTotalDiscountPercent * biRemainedQty) / biBillQty) + ((biRemainedQty / biBillQty) * bi.FixedBiDiscount)) AS SumOfDiscounts,
		   (((bi.FixedTotalExtraPercent * biRemainedQty) / biBillQty) + ((biRemainedQty / biBillQty) * bi.FixedBiExtra)) AS SumOfExtras
	INTO #OrderDetails
    FROM   #Ordered AS ORD1
	        INNER JOIN [dbo].[fn_bubi_Fixed](@CurGUID) bi ON ORD1.biGUID =  BI.biGUID,
           (SELECT ORD2.buGUID,
                   ( CASE ORD2.Finished
                       WHEN 0 THEN Sum(ORD2.biRemainedQty / ( CASE
                                                                WHEN ORD2.biUnitFact = 0 THEN 1
                                                                ELSE ORD2.biUnitFact
                                                              END ) * ORD2.biUnitPrice)
                       ELSE 0
                     END ) AS buRemainedPrice
            FROM   #Ordered AS ORD2
            GROUP  BY ORD2.buGUID,
                      ORD2.Finished) O			
    WHERE  O.buGUID = ORD1.buGUID
    ORDER  BY buCustAccName,
              buDate,
              buName,
              biNumber

	------- fill Orders table
	SELECT OD.* , 
		   bi.FixedBiPrice									 AS biPriceWithoutTax,
		   bi.FixedBiPrice * OD.biRemainedQty				 AS Value,
		   (biRemainedQty / biBillQty) * bi.FixedBiDiscount AS Discount,
		   (biRemainedQty / biBillQty) * bi.FixedBiExtra	 AS Extra,
		   (biRemainedQty / biBillQty) * bi.FixedBiVAT		 AS Tax
	INTO #Orders
	FROM #OrderDetails OD 
	INNER JOIN [dbo].[fn_bubi_Fixed](@CurGUID) bi ON OD.biGUID =  bi.biGUID
	ORDER  BY OD.buCustAccName,
              OD.buDate,
              OD.buName,
              OD.biNumber  
	  
	--------------------------------------------------------------------------------
	DECLARE @netTotalPrice TABLE
      (
         CustAccGuid		UNIQUEIDENTIFIER,
         netTotal			FLOAT,
		 btIsInput			INT
      )
	  INSERT INTO @netTotalPrice
	  SELECT buCustAcc																					AS CustGuid,
	  		 CASE Finished WHEN 0 THEN SUM(Value) + SUM(SumOfExtras) + SUM(Tax) -  SUM(SumOfDiscounts) ELSE 0 END	AS OrderNet,
			 btIsInput

	  FROM #Orders
	  GROUP BY buGUID,
			   buName,
			   buCustAcc,
			   buDate,
			   btIsInput,
			   buPayType,
			   Finished


		DECLARE @GUID UNIQUEIDENTIFIER
		DECLARE @TempTable TABLE (Id UNIQUEIDENTIFIER)
		INSERT INTO @TempTable (Id)
		SELECT CustAccGuid FROM @RemainedPrieAccBal

		WHILE EXISTS (SELECT * FROM @TempTable)
		BEGIN
			SELECT Top 1 @GUID = Id FROM @TempTable

			UPDATE @AccBal
			SET InputRemainedPrice = (SELECT SUM(netTotal) FROM @netTotalPrice WHERE CustAccGuid = @GUID AND btIsInput = 1)
			WHERE buCustAccGuid = @GUID

			UPDATE @AccBal
			SET OutputRemainedPrice = (SELECT SUM(netTotal) FROM @netTotalPrice WHERE CustAccGuid = @GUID AND btIsInput = 0)
			WHERE buCustAccGuid = @GUID

			DELETE FROM @TempTable WHERE Id = @GUID
		END
    --------------------------------------------------------------------------------   
    --								R E S U L T S								  --
    --------------------------------------------------------------------------------    
    -- Balances --
	--------------
    SELECT buCustAccGuid,
		   buCustAccName,
		   buCustName, 
		   buCustAccBal, 
		   ISNULL(InputRemainedPrice, 0)														AS InputRemainedPrice, 
		   ISNULL(OutputRemainedPrice, 0)														AS OutputRemainedPrice,
		   ISNULL(OutputRemainedPrice, 0) - ISNULL(InputRemainedPrice, 0)						AS MovementBalance,
		   (ISNULL(OutputRemainedPrice, 0) - ISNULL(InputRemainedPrice, 0)) + buCustAccBal		AS FinalBalance
    FROM   @AccBal
    ORDER  BY buCustAccName
	------------
    -- States --
	------------  
    SELECT oit.GUID,
           oit.NAME      oitName,
           oit.LatinName oitLatinName,
           oit.Type      oitType,
           oit.PostQty   oitSerial
    FROM   oit000 oit
    WHERE  oit.GUID IN (SELECT StateGuid
                        FROM   #StatesQty)
    ORDER  BY oit.Type ,--DESC,
              oit.PostQty
	-------------------
    -- order details --
	-------------------
	SELECT OD.* , 
		   bi.FixedBiPrice																				AS biPriceWithoutTax,
		   bi.FixedBiPrice * OD.biRemainedQty															AS Value,
		   (biRemainedQty / biBillQty) * bi.FixedBiDiscount											AS Discount,
		   (biRemainedQty / biBillQty) * bi.FixedBiExtra												AS Extra,		  
		   (biRemainedQty / biBillQty) * bi.FixedBiVAT													AS Tax,
		   ((bi.FixedBiPrice * OD.biRemainedQty)
		      - (((bi.FixedTotalDiscountPercent * biRemainedQty) / biBillQty) + ((biRemainedQty / biBillQty) * bi.FixedBiDiscount)) 
			  + (((bi.FixedTotalExtraPercent * biRemainedQty) / biBillQty) + ((biRemainedQty / biBillQty) * bi.FixedBiExtra)) 
			  + ((biRemainedQty / biBillQty) * bi.FixedBiVAT)
		   ) AS NetRemainingValue,   
		   (bi.biBonusQnt  - OD.BonusPostedQty) / OD.biUnitFact AS RemainingBonusQty		
	FROM #OrderDetails OD 
	INNER JOIN [dbo].[fn_bubi_Fixed](@CurGUID) bi ON OD.biGUID =  BI.biGUID
	ORDER  BY OD.buCustAccName,
              OD.buDate,
              OD.buName,
              OD.biNumber
	------------
	-- Orders --
	------------
	SELECT buGUID			AS OrderGuid,
		   buCustAcc		AS CustGuid,
		   buName			AS OrderName,
		   buDate			AS OrderDate,
		   SUM(Discount)	AS TotalDiscount,
		   SUM(Extra)		AS TotalExtra,
		   SUM(Value)		AS OrderTotalPrice,
		   buPayType		AS OrderPayType,
		   btIsInput,
		   Finished,
		   CASE Finished WHEN 0 THEN SUM(Value) + SUM(SumOfExtras) + SUM(Tax) -  SUM(SumOfDiscounts) ELSE 0 END  AS OrderNet
	  FROM #Orders
	  GROUP BY buGUID,
			   buName,
			   buCustAcc,
			   buDate,
			   btIsInput,
			   buPayType,
			   Finished
   -----------------
   -- order State --
   -----------------  
    SELECT ORD1.biGUID, ORD1.buGUID, ORD1.biUnitName, ORD1.biBillQty, ORD1.biAcheivedQty, ORD1.biRemainedQty, ORD1.biMatPtr,
		   ORD1.mtName + ' - ' + ORD1.mtCode AS Material
    FROM   #Ordered AS ORD1,
           (SELECT ORD2.buGUID,
                   ( CASE ORD2.Finished
                       WHEN 0 THEN Sum(ORD2.biRemainedQty / ( CASE
                                                                WHEN ORD2.biUnitFact = 0 THEN 1
                                                                ELSE ORD2.biUnitFact
                                                              END ) * ORD2.biUnitPrice)
                       ELSE 0
                     END ) AS buRemainedPrice
            FROM   #Ordered AS ORD2
            GROUP  BY ORD2.buGUID,
                      ORD2.Finished) O
    WHERE  O.buGUID = ORD1.buGUID
    ORDER  BY buCustAccName,
              buDate,
              buName,
              biNumber
	----------------
    -- states qty --  
	----------------
	SELECT *
    FROM   #StatesQty
    ORDER  BY buCustAccName,
              buDate,
              buName,
              biNumber

################################################################ 
#END