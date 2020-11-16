################################################################
CREATE FUNCTION fnGetInitialState (@TypeGuid UNIQUEIDENTIFIER)
RETURNS UNIQUEIDENTIFIER
AS
  BEGIN
      RETURN
        (SELECT TOP 1 OIT.Guid AS FinalStateGuid
         FROM   oit000 OIT
                INNER JOIN oitvs000 OITVS
                        ON OIT.Guid = OITVS.ParentGuid
         WHERE  OITVS.OtGuid = @TypeGuid
                AND OITVS.Selected = 1
         ORDER  BY OIT.PostQty ASC)
  END 
################################################################
CREATE PROCEDURE prcOrdersPostedRep @Acc           UNIQUEIDENTIFIER,-- 1 ������  
                                    @Cost          UNIQUEIDENTIFIER,-- 2 ���� ������  
                                    @CustCond      UNIQUEIDENTIFIER = 0x00,-- 3 ���� ������  
                                    @OrderCond     UNIQUEIDENTIFIER = 0x00,-- 4 ���� �����  
                                    @OrderTypesSrc UNIQUEIDENTIFIER,-- 5 ����� �������  
                                    @StartDate     DATETIME,-- 6 ����� �������  
                                    @EndDate       DATETIME,-- 7 ����� �������  
                                    @OptionView    INT,
                                    @CustFldsFlag  BIGINT = 0,--������ �����    0=�� ����   1= ����� ����  ���� 2= ����� ���� ���� 
                                    @OrderFldsFlag BIGINT = 0,
                                    @CustCFlds     NVARCHAR (max) = '',
                                    @OrderCFlds    NVARCHAR (max) = ''
AS
    SET NOCOUNT ON
	DECLARE @Lang INT = dbo.fnConnections_GetLanguage();

    ---------------------    #OrderTypesTbl   ------------------------   
    -- ���� ����� �������� ���� �� �������� �� ����� ����� �������   
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
    -------------------------------------------------------------------	    
    -------------------------   #OrdersTbl   --------------------------     
    --  ���� �������� ���� ���� ������   
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

    -------------------------------------------------------------------    
    -------------------------------------------------------------------     
    -------------------------   #CustTbl   ---------------------------   
    -- ���� ������� ���� ���� ������   
    CREATE TABLE #CustTbl
      (
         CustGuid UNIQUEIDENTIFIER,
         Security INT
      )
    INSERT INTO #CustTbl
    EXEC prcGetCustsList
      NULL,
      @Acc,
      @CustCond
    IF ISNULL(@Acc, 0x0) = 0x0
      INSERT INTO #CustTbl
      VALUES     (0x0,
                  1)

    -------------------------------------------------------------------   
    -------------------------------------------------------------------   
    -- ���� ����� ������   
    DECLARE @CostTbl TABLE
      (
         CostGuid UNIQUEIDENTIFIER
      )
    INSERT INTO @CostTbl
    SELECT Guid
    FROM   fnGetCostsList(@Cost)
    IF ISNULL(@Cost, 0x0) = 0x0
      INSERT INTO @CostTbl
      VALUES     (0x0)

    ------------------------------------------------------------------- 
    SELECT bt.GUID                        TypeGuid,
           bt.NAME                        TypeName,
           bu.Number                      OrderNumber,
           dbo.fnGetInitialState(bt.GUID) InitialState,
           0                              AS InitialQty,
           dbo.fnGetFinalState(bt.Guid)   FinalState,
           0                              AS FinalQty,
           bu.GUID                        OrderGuid,
           bi.GUID                        ItemGuid,
           bi.MatGUID,
           bi.Qty                         OrderedQty,
           bu.Number                      numOrder,
          (CASE @Lang WHEN 0 THEN bt.abbrev ELSE (CASE bt.LatinAbbrev WHEN N'' THEN bt.abbrev ELSE bt.LatinAbbrev END) END )  nameOrder
    INTO   #orders
    FROM   bt000 bt
           INNER JOIN bu000 bu
                   ON bt.GUID = bu.TypeGUID
           INNER JOIN bi000 bi
                   ON bi.ParentGUID = bu.GUID
           INNER JOIN #OrderTypesTbl
                   ON bt.GUID = #OrderTypesTbl.Type
           INNER JOIN @CostTbl AS Costs
                   ON bu.CostGuid = Costs.CostGuid
           INNER JOIN #CustTbl AS Custs
                   ON bu.CustGuid = Custs.CustGuid
           INNER JOIN #OrdersTbl AS Orders
                   ON Orders.OrderGuid = BU.Guid
    WHERE  bt.Type IN ( 5, 6 )
           AND bu.Date BETWEEN @StartDate AND @EndDate
    ORDER  BY bt.NAME,
              bu.Number

    UPDATE #orders
    SET    InitialQty = (SELECT ISNULL(Sum(Qty), 0)
                         FROM   ori000
                         WHERE  POIGUID = ItemGuid
                                AND TypeGuid = InitialState),
           FinalQty = (SELECT ISNULL(Sum(Qty), 0)
                       FROM   ori000
                       WHERE  POIGUID = ItemGuid
                              AND TypeGuid = FinalState)

    --SELECT * FROM #orders 
    SELECT TypeGuid,
           TypeName,
           OrderNumber,
           OrderGuid,
           numOrder,
           nameOrder,
           ISNULL(Sum(OrderedQty), 0) OrderedQty,
           ISNULL(Sum(InitialQty), 0) InitialQty,
           ISNULL(Sum(FinalQty), 0)   FinalQty
    INTO   #Res
    FROM   #orders
    GROUP  BY TypeGuid,
              TypeName,
              OrderNumber,
              OrderGuid,
              numOrder,
              nameOrder

    EXEC GetOrderFlds
      @OrderFldsFlag,
      @OrderCFlds

    EXEC GetCustFlds
      @CustFldsFlag,
      @CustCFlds

    SELECT r.*,
           bu.Cust_Name,
           bu.Number,
           bu.Date billdate,
           bu.Total,
           bu.Security,
           C.*,
           O.*
    INTO   #Result
    FROM   #Res r
           INNER JOIN bu000 bu
                   ON bu.GUID = r.OrderGuid
           LEFT JOIN ##CustFlds C
                  ON C.CustFldGuid = bu.CustGuid
           INNER JOIN ##OrderFlds O
                   ON O.OrderFldGuid = r.OrderGuid

/*******************************************************************************/
    /* ---------------------------����� �� ��� ����� �� ����-----------------------*/
    SELECT *
    INTO   #FinalResult
    FROM   #Result r
           INNER JOIN ORADDINFO000 AS OrderInfo
                   ON OrderInfo.ParentGuid = r.OrderGuid
                      AND OrderInfo.Finished = 0 /*����� ��� �����*/
                      AND OrderInfo.Add1 = 0/*����� ��� ����*/

    /******************************************************************************/
    IF ( @OptionView = 0 ) -- �� ����  
      SELECT *, nameOrder + ' - ' + convert(Nvarchar(250), numOrder) AS Orders
      FROM   #FinalResult r
      WHERE  r.OrderedQty = r.InitialQty
    ELSE IF ( @OptionView = 1 )--�����  ���� ���� 
      SELECT *, nameOrder + ' - ' + convert(Nvarchar(250), numOrder) AS Orders
      FROM   #FinalResult r
      WHERE  r.OrderedQty > r.InitialQty
             AND r.OrderedQty > r.FinalQty
    ELSE-- ����� ���� ����    
      SELECT *, nameOrder + ' - ' + convert(Nvarchar(250), numOrder) AS Orders
      FROM   #FinalResult r
      WHERE  r.OrderedQty = r.FinalQty 
################################################################
#END	
