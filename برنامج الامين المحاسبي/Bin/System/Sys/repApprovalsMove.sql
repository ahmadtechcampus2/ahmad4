##############################################################################
CREATE PROCEDURE repApprovalsMove
  @StartDate DATE,
  @EndDate   DATE,
  @StoreGuid UNIQUEIDENTIFIER = 0x0,
  @CustomerGuid UNIQUEIDENTIFIER = 0x0,
  @UserGuid UNIQUEIDENTIFIER = 0x0,
  @AccountGuid UNIQUEIDENTIFIER = 0x0,
  @CostGuid UNIQUEIDENTIFIER = 0x0,
  @OrderNumber INT,
  @OrderCond UNIQUEIDENTIFIER = 0x0,
  @OrderTypesSrc UNIQUEIDENTIFIER = 0x0
AS
  SET NOCOUNT ON
  DECLARE @Lang INT = dbo.fnConnections_GetLanguage();
  --Customers Temp Table
  CREATE TABLE #Cust
               (
                            [Guid] UNIQUEIDENTIFIER,
                            [Security] INT
               )
  --Order
  ---------------------    #OrderTypesTbl   ------------------------
  CREATE TABLE #OrderTypesTbl
               (
                            Type UNIQUEIDENTIFIER,
                            Sec         INT,
                            ReadPrice   INT,
                            UnPostedSec INT
               )
  INSERT INTO #OrderTypesTbl
  EXEC prcGetBillsTypesList2
    @OrderTypesSrc
  SELECT     bu.buGuid,
             Sum(bi.Qty) + Sum(bi.BonusQnt)    AS Qty,
             Sum(bi.BonusQnt) AS BonusQnt,
             Sum(bi.Discount) AS Discount,
             Sum(bi.Extra)    AS Extra,
             Sum(bi.Vat)      AS Vat
  INTO       #buTemp
  FROM       vwbu AS bu
  INNER JOIN #OrderTypesTbl TypesTbl
  ON         TypesTbl.[Type] = bu.buType
  INNER JOIN bi000 AS bi
  ON         bu.buGuid = bi.ParentGuid
  GROUP BY   bu.buGuid
  INSERT INTO #Cust
  EXEC prcGetCustsList
    @CustomerGuid,
    @AccountGuid,
    NULL
  IF ((@CustomerGuid = 0x0)
  AND
  (
    @AccountGuid = 0x0
  )
  )
  INSERT INTO #Cust VALUES
              (
                          0x0,
                          1
              )
  --Conditions Temp Table
  CREATE TABLE #CondOrder
               (
                            [Guid] UNIQUEIDENTIFIER,
                            [Security] INT
               )
  INSERT INTO #CondOrder
  EXEC prcGetOrdersList
    @OrderCond
  CREATE TABLE #CostTbl
               (
                            [Guid] UNIQUEIDENTIFIER
               )
  INSERT INTO #CostTbl
  SELECT *
  FROM   fnGetCostsList(@CostGuid)
  IF (@CostGuid = 0x0)
  INSERT INTO #CostTbl VALUES
              (
                          0x0
              )
    -- for Approvals_Force_Sequential Option(Orders_System_Options)
  DECLARE @ForceSequentialApproval INT = 0
  SELECT @ForceSequentialApproval = ISNULL(value, 0)
  FROM   [op000]
  WHERE  [name] = 'ForceSequentialApproval'
  --Get Results
  SELECT DISTINCT bu.buNumber AS NUMBER,
                  bu.buNotes,
                  bu.buGuid    AS OrderGuid,
                  bu.buCustPtr AS CustGuid,
                  bu.buType,
                  (bu.buTotal - bu.buTotalDisc + bu.buTotalExtra +bu.buVAT) AS Total,
                  buTemp.Qty                                            AS Qty,
                  buTemp.BonusQnt                                       AS TotalBonus,
                  buTemp.Discount                                       AS TotalDiscount,
                  buTemp.Extra                                          AS TotalExtra,
                  buTemp.Vat                                            AS TotalVat,
                  bt.btGuid                                             AS OrderTypeGuid,
                  bu.buDate                                             AS OrderDate,
                  st.stGuid                                             AS storeGUID,
                  (CASE @Lang WHEN 0 THEN bt.btName ELSE (CASE bt.btLatinName WHEN N'' THEN bt.btName ELSE bt.btLatinName END) END )+ ': ' + Cast (bu.buNumber AS NVARCHAR(10)) AS buName,
                  more.ADDATE                                           AS DelieveryDate,
                  (CASE @Lang WHEN 0 THEN cu.cuCustomerName ELSE (CASE cu.cuLatinName WHEN N'' THEN cu.cuCustomerName ELSE cu.cuLatinName END) END ) AS CustomerName,
                  (CASE @Lang WHEN 0 THEN co.NAME ELSE (CASE co.LatinName WHEN N'' THEN co.NAME ELSE co.LatinName END) END ) AS CostCenterName,
                  bu.buPayType                                          AS PaymentType,
                  (CASE @Lang WHEN 0 THEN my.myName ELSE (CASE my.myLatinName WHEN N'' THEN my.myName ELSE my.myLatinName END) END ) AS CurrencyName,
                  (CASE @Lang WHEN 0 THEN st.stName ELSE (CASE st.stLatinName WHEN N'' THEN st.stName ELSE st.stLatinName END) END ) AS StoreName,
                  st.stSecurity                                         AS StoreSecurity ,
                  cust.Security                                         AS CustSecurity,
                  bt.btType
                 
  INTO            #result
  FROM            vwbu bu
  INNER JOIN      #buTemp AS buTemp
  ON              buTemp.buGuid = bu.buGuid
  INNER JOIN      vwbt bt
  ON              bu.buType = bt.btGuid
  AND             bt.btType IN (5,
                                6)
  INNER JOIN      OrderApprovals000 oap
  ON              oap.OrderGuid = bu.buGuid
  OUTER APPLY     dbo.fnGetLastApprovalState(oap.GUID) AS oaps
  INNER JOIN      dbo.fnGetStoresList (@StoreGuid)     AS stl
  ON              stl.Guid = bu.buStorePtr
  INNER JOIN      vwst AS st
  ON              st.stGuid = stl.Guid
  INNER JOIN      #CostTbl AS col
  ON              col.Guid = bu.buCostPtr
  LEFT JOIN       co000 AS co
  ON              co.GUID = bu.buCostPtr
  INNER JOIN      #Cust AS cust
  ON              (
                                  bu.buCustPtr = cust.Guid)
  INNER JOIN      vwmy AS my
  ON              (
                                  bu.buCurrencyPtr = my.myGUID)
  INNER JOIN      #CondOrder AS cndO
  ON              cndO.Guid = bu.buGuid
  
  LEFT JOIN       vwcu AS cu
  ON              (
                                  cu.cuGuid = bu.buCustPtr)
  INNER JOIN      OrAddInfo000 AS more
  ON              more.parentGuid = bu.buGuid
  INNER JOIN      vwus AS us
  ON              us.usGuid = oap.UserGuid
  WHERE           (
                                  oaps.IsApproved <> 1
                  OR              oaps.IsApproved IS NULL )
  AND             (
                                  bu.buDate BETWEEN @StartDate AND             @EndDate)
  AND             (
                                  bu.buNumber = @OrderNumber
                  OR              @OrderNumber = 0)
  AND             (
                                  more.Finished <> 1) --Finished Orders
  AND             (
                                  more.Add1 <> 1) --Cancelled Orders
  AND             (
                                  us.usGuid = @UserGuid
                  OR              @UserGuid = 0x0)
  --Delete Orders That approved by Managers
  DELETE #result
  FROM        #result r
  INNER JOIN  MgrApp000 mngA
  ON          r.OrderGuid = mngA.OrderGuid
  CROSS APPLY dbo.fnGetLastApprovalState(mngA.GUID) AS oaps
  WHERE       oaps.IsApproved = 1
  ----------------------------------------
	--SECURITY
	CREATE TABLE #SecViol
		(
			Type INT
			,Cnt INT
		)  
	EXEC [prcCheckSecurity]    
	-------------------------------------
	--Get Order Details
	Declare @details TABLE(
		OrderGuid UNIQUEIDENTIFIER, 
		BIGuid UNIQUEIDENTIFIER,
		MatName NVARCHAR(250),
		MatUnity NVARCHAR(250) ,
		MatQty FLOAT,
		Price FLOAT,
		Total FLOAT,
		Bonus FLOAT,
		Discount FLOAT,
		Extra FLOAT,
		Vat FLOAT,
		BiTotalDiscountPercent FLOAT,
		BiTotalExtraPercent FLOAT,
		SumOfTotalDiscount FLOAT,
		SumOFTotalExtra FLOAT
	)

	--IF @ShowDetails = 1
	BEGIN 
	INSERT INTO @details 
		SELECT
			r.OrderGuid,
			bi.biGUID,
			mt.mtName,
			mt.mtUnity,
			bi.biQty,
			bi.biprice,
			bi.biQty * bi.biPrice,
			bi.biBonusQnt,
			bi.biDiscount,
			bi.biExtra,
			bi.biVAT,
			bi.BiTotalDiscountPercent,
			bi.BiTotalExtraPercent,
		   (bi.BiTotalDiscountPercent + bi.biDiscount) AS SumOfTotalDiscount,
		   (bi.BiTotalExtraPercent + bi.biExtra ) AS SumOFTotalExtra
		FROM #result r
			INNER JOIN vwbi AS bi ON bi.biParent = r.OrderGuid
			INNER JOIN vwMt AS mt ON mt.mtGUID = bi.biMatPtr
	END
	-----------------------------------------------------------------------	
	--Get Orders Approvals	
	SELECT
		   r.OrderGuid,
		   r.Number,     
		   oap.UserGuid, 
		   oap.Guid AS AppGuid, 
		   us.usLoginName AS UserName,  
		   oap.[Number] AS [Order],  
		   ISNULL(oaps.IsApproved, 0) AS Approved 
	INTO #Approvals
	FROM #result r
			INNER JOIN OrderApprovals000 oap ON oap.OrderGuid = r.OrderGuid
			OUTER APPLY dbo.fnGetLastApprovalState(oap.GUID) AS oaps 
			INNER JOIN vwus AS us ON us.usGuid = oap.UserGuid
	WHERE (oap.UserGuid = @UserGuid
	OR @UserGuid = 0x0)
	ORDER BY r.Number, [Order]
   
	-- #temp holds Order Numbers with the that must approve it
	CREATE TABLE #temp ([OrderGuid] UNIQUEIDENTIFIER, [Order] INT)	  
	IF @ForceSequentialApproval = 1
		BEGIN
			Insert INTO #temp SELECT OrderGuid,  
				Min([Order])
			FROM #Approvals AS o  
			WHERE Approved = 0
			GROUP BY OrderGuid  
		END
	ELSE
		BEGIN
			INSERT INTO #temp 
			SELECT OrderGuid
			, [Order] 
			FROM  #Approvals  o 
			WHERE Approved = 0		 
		END
	

	SELECT
		aps.OrderGUID,
		aps.UserGUID,
		aps.UserName,
		aps.[Order],
		aps.Approved [IsApproved],
		dbo.fnPreviousUsersApproved(aps.AppGuid, aps.OrderGUID) AS isPreviousUsersApproved
	INTO #OrderApprovals
	FROM #Approvals aps
	INNER JOIN #temp t ON aps.OrderGuid = t.OrderGuid
		AND aps.[Order] = t.[Order]
	WHERE 
		 1 = CASE WHEN  @ForceSequentialApproval = 1 THEN (SELECT dbo.fnPreviousUsersApproved(aps.AppGuid, aps.OrderGUID)) ELSE 1 END
	ORDER BY aps.Number, aps.[OrderGuid] , aps.[Order]

	--Delete Orders That has no approval
	IF @ForceSequentialApproval = 1
	BEGIN
		DELETE   
			#result   
		FROM   
			#result r   
			LEFT JOIN #OrderApprovals app  ON r.OrderGuid = app.OrderGuid  
			WHERE 
				app.UserGuid IS NULL
	END
	----------------------------------------
	-- Sorting Results
	SELECT   *
	FROM   #result AS r
	ORDER BY 
		r.OrderDate,
		r.Number
	----------------------------------------
	--Order Details
	BEGIN
		SELECT
			OrderGuid,
			BIGuid,
			MatName,
			MatUnity,
			MatQty,
			Price,
			Total,
			Bonus,
			Discount,
			Extra,
			Vat,
			BiTotalDiscountPercent,
			BiTotalExtraPercent,
			SumOfTotalDiscount,
			SumOFTotalExtra,
			(Total - SumOfTotalDiscount + SumOFTotalExtra + Vat) AS NetItemValue
		FROM @details
	END 
	----------------------------------------
	--Orders Approvals
	SELECT
	* 
	FROM #OrderApprovals
	----------------------------------------
	--Hidden Orders AS Security
	SELECT * FROM #SecViol  
####################################################################################
CREATE PROCEDURE prcOrderInsertUserApprovalState
  @OrderGuid UNIQUEIDENTIFIER ,
  @UserGuid UNIQUEIDENTIFIER ,
  @IsApproved BIT
AS
  --Auther  Abdulkareem
  --For insert user approvals as a chech in approvals report .
  SET NOCOUNT ON
  DECLARE @Number INT ,
    @CurrentUserGuid UNIQUEIDENTIFIER ,
    @ParentGuid UNIQUEIDENTIFIER ,
    @AlternativeUserGuid UNIQUEIDENTIFIER = 0x0
  SET @CurrentUserGuid = dbo.fnGetCurrentUserGUID();
  IF (@CurrentUserGuid = @UserGuid)
  BEGIN
    SELECT TOP 1
                @Number = ISNULL(Max(oap.Number) + 1, 1) ,
                @ParentGuid = oap.GUID
    FROM        OrderApprovals000 oap
    OUTER APPLY dbo.fnGetLastApprovalState(oap.GUID) AS oapstate
    WHERE       oap.OrderGuid = @OrderGuid
    AND         oap.UserGuid = @UserGuid
    GROUP BY    oap.GUID
  END
  ELSE
  BEGIN
    SELECT TOP 1
                @Number = ISNULL(Max(oap.Number) + 1, 1) ,
                @ParentGuid =          oap.GUID ,
                @AlternativeUserGuid = us.GUID
    FROM        OrderApprovals000 oap
    OUTER APPLY dbo.fnGetLastApprovalState(oap.GUID) AS oapstate
    LEFT JOIN   OrderAlternativeUsers000             AS us
    ON          us.UserGUID = oap.UserGuid
    WHERE       oap.OrderGuid = @OrderGuid
    AND         oap.UserGuid = @UserGuid
    AND         us.AlternativeUserGUID = @CurrentUserGuid
    GROUP BY    oap.GUID,
                us.GUID
    SET @UserGuid = @CurrentUserGuid
  END
  INSERT INTO OrderApprovalStates000
              (
                          Guid ,
                          NUMBER ,
                          ParentGuid ,
                          UserGuid ,
                          AlternativeUserGUID ,
                          IsApproved ,
                          OperationTime ,
                          ComputerName
              )
              VALUES
              (
                          Newid() ,
                          @Number ,
                          @ParentGuid ,
                          @UserGuid ,
                          @AlternativeUserGuid ,
                          @IsApproved ,
                          Getdate() ,
                          Host_name()
              )
####################################################################################
#END