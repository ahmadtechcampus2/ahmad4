##############################################################################
CREATE PROCEDURE repApprovalsMoveByDate @StartDate                DATE,
                                        @EndDate                  DATE,
                                        @StoreGuid                UNIQUEIDENTIFIER = 0x0,
                                        @CustomerGuid             UNIQUEIDENTIFIER = 0x0,
                                        @UserGuid                 UNIQUEIDENTIFIER = 0x0,
                                        @AccountGuid              UNIQUEIDENTIFIER = 0x0,
                                        @CostGuid                 UNIQUEIDENTIFIER = 0x0,
                                        @OrderNumber              INT = 0,
                                        @OrderCond                UNIQUEIDENTIFIER = 0x0,
                                        @OrderTypesSrc            UNIQUEIDENTIFIER = 0x0,
                                        @ShowActiveOrders         BIT = 1,
                                        @ShowFinished             BIT = 1,
                                        @ShowCancelled            BIT = 1,
                                        @ShowUnApprovedOperations BIT = 0
                                     
AS
    SET NOCOUNT ON;
    -------Store Table----------------------------------------------------------   
    DECLARE @Lang INT = dbo.fnConnections_GetLanguage();
	DECLARE @StoreTbl TABLE
      (
         [GUID] [UNIQUEIDENTIFIER]
      )
    INSERT INTO @StoreTbl
    SELECT [Guid]
    FROM   [fnGetStoresList](@StoreGUID)
    -------------------------------------------------------------------  
    -------------------------   #CustTbl   ---------------------------   
    -- ط¬ط¯ظˆظ„ ط§ظ„ط²ط¨ط§ط¦ظ† ط§ظ„طھظٹ طھط­ظ‚ظ‚ ط§ظ„ط´ط±ظˆط·   
    CREATE TABLE #CustTbl
      (
         CustGuid UNIQUEIDENTIFIER,
         Security INT
      )
    INSERT INTO #CustTbl
    EXEC prcGetCustsList
      @CustomerGuid,
      @AccountGuid,
      0x0
    IF ISNULL(@CustomerGuid, 0x0) = 0x00
      INSERT INTO #CustTbl
      VALUES     (0x0,
                  1)
    -------------------------------------------------------------------   
    -------------------------   #CostTbl   --------------------------- 
    CREATE TABLE [#CostTbl]
      (
         [CostGUID] UNIQUEIDENTIFIER,
         [Security] INT
      )
    INSERT INTO [#CostTbl]
    EXEC [prcGetCostsList]
      @CostGUID
    IF @costGuid = 0x00
      INSERT INTO #CostTbl
      VALUES      (0x00,
                   0)
    -------------------------   #OrdersCondTbl   ----------------------  
    --  ط¬ط¯ظˆظ„ ط§ظ„ط·ظ„ط¨ظٹط§طھ ط§ظ„طھظٹ طھط­ظ‚ظ‚ ط§ظ„ط´ط±ظˆط·   
    CREATE TABLE #OrdersCondTbl
      (
         OrderGuid UNIQUEIDENTIFIER,
         Security  INT
      )
    INSERT INTO #OrdersCondTbl
                (OrderGuid,
                 Security)
    EXEC prcGetOrdersList
      @OrderCond
    -------------------------------------------------------------------   
    CREATE TABLE #RESULT_2
      (
         OrderGuid         UNIQUEIDENTIFIER,
         UserGuid          UNIQUEIDENTIFIER,
         UserName          NVARCHAR(250) COLLATE ARABIC_CI_AI,
         ApprovalDate      DATETIME,
         IsApproved        BIT,
         ComputerName      NVARCHAR(250) COLLATE ARABIC_CI_AI,
         IsAlternativeUser BIT
      )
    IF @ShowUnApprovedOperations = 1
      BEGIN
          INSERT INTO #RESULT_2
          SELECT OrderGuid,
                 oas.UserGuid,
                 us.LoginName AS UserName,
                 OperationTime,
                 IsApproved,
                 ComputerName,
                 CASE AlternativeUserGUID
                   WHEN 0x0 THEN 0
                   ELSE 1
                 END
          FROM   OrderApprovals000 oa
                 INNER JOIN OrderApprovalStates000 oas
                         ON oa.GUID = oas.ParentGUID
                 INNER JOIN us000 us
                         ON us.GUID = oas.UserGUID
          WHERE  ( ( @UserGuid = 0x0 )
                    OR ( oas.UserGuid = @UserGuid ) )
          ORDER  BY oa.Number,
                    oas.Number
          INSERT INTO #RESULT_2
          SELECT OrderGuid,
                 oas.UserGuid,
                 us.LoginName AS UserName,
                 OperationTime,
                 IsApproved,
                 ComputerName,
                 CASE AlternativeUserGUID
                   WHEN 0x0 THEN 0
                   ELSE 1
                 END
          FROM   MgrApp000 mapp
                 INNER JOIN OrderApprovalStates000 oas
                         ON mapp.GUID = oas.ParentGUID
                 INNER JOIN us000 us
                         ON us.[GUID] = oas.UserGuid
          WHERE  ( ( @UserGuid = 0x0 )
                    OR ( oas.UserGuid = @UserGuid ) )
      END
    ELSE
      BEGIN
          INSERT INTO #RESULT_2
          SELECT OrderGuid,
                 oas.UserGuid,
                 us.LoginName AS UserName,
                 OperationTime,
                 IsApproved,
                 ComputerName,
                 CASE AlternativeUserGUID
                   WHEN 0x0 THEN 0
                   ELSE 1
                 END
          FROM   OrderApprovals000 oa
                 CROSS APPLY dbo.fnGetLastApprovalState(oa.GUID) AS oas
                 INNER JOIN us000 us
                         ON us.GUID = oas.UserGUID
          WHERE  ( ( @UserGuid = 0x0 )
                    OR ( oas.UserGuid = @UserGuid ) )
                 AND oas.IsApproved = 1
          ORDER  BY oa.Number,
                    oas.Number
          INSERT INTO #RESULT_2
          SELECT OrderGuid,
                 oas.UserGuid,
                 us.LoginName AS UserName,
                 OperationTime,
                 IsApproved,
                 ComputerName,
                 CASE AlternativeUserGUID
                   WHEN 0x0 THEN 0
                   ELSE 1
                 END
          FROM   MgrApp000 mapp
                 CROSS APPLY dbo.fnGetLastApprovalState(mapp.GUID) AS oas
                 INNER JOIN us000 us
                         ON us.[GUID] = oas.UserGuid
          WHERE  ( ( @UserGuid = 0x0 )
                    OR ( oas.UserGuid = @UserGuid ) )
                 AND oas.IsApproved = 1
      END
    SELECT DISTINCT bu.[buGUID]                                AS OrderGuid,
                    bu.buType                                  AS OrderTypeGuid,
                    bu.[buNumber]                              AS OrderNumber,
                    bu.[buDate]                                AS OrderDate,
                    ((CASE @Lang WHEN 0 THEN bt.[Abbrev] ELSE (CASE bt.LatinAbbrev WHEN N'' THEN bt.[Abbrev] ELSE bt.LatinAbbrev END) END )+ CONVERT(NVARCHAR(10), bu.[buNumber]) ) AS OrderFormatted,
                    bu.[buCust_Name]                           AS CustomerName,
					(CASE @Lang WHEN 0 THEN st.Name ELSE (CASE st.LatinName WHEN N'' THEN st.Name ELSE st.LatinName END) END ) AS StoreName,
                    (CASE @Lang WHEN 0 THEN co.NAME ELSE (CASE co.LatinName WHEN N'' THEN co.NAME ELSE co.LatinName END) END ) AS CostCenterName,
                    (CASE
                        WHEN ( oinf.Finished = 1 ) THEN 1 -- FINISHED
                        ELSE ( CASE
                                 WHEN oinf.Add1 = 1 THEN 2 -- CANCELLED
                                 ELSE 0 -- ACTIVE
                               END )
                      END )                                    AS OrderState
                    ,bu.buCustPtr  AS CustGuid
    INTO   #result1
    FROM   vwBu bu
           INNER JOIN #RESULT_2 rslt2
                   ON rslt2.OrderGuid = bu.buGUID
           INNER JOIN bt000 bt
                   ON bt.[GUID] = bu.buType
           INNER JOIN ORADDINFO000 oinf
                   ON oinf.[ParentGuid] = bu.buGUID
           INNER JOIN st000 st
                   ON st.[GUID] = bu.buStorePtr
           INNER JOIN @StoreTbl st2
                   ON st2.[GUID] = bu.buStorePtr
           INNER JOIN RepSrcs rs
                   ON [IdType] = bu.buType
           LEFT JOIN co000 co
                  ON co.[GUID] = bu.buCostPtr
           INNER JOIN [#CostTbl] co2
                   ON co2.CostGuid = bu.buCostPtr
           INNER JOIN #CustTbl AS cu
                   ON cu.CustGuid = bu.buCustPtr
           INNER JOIN #OrdersCondTbl oc
                   ON oc.OrderGuid = bu.buGUID
    WHERE  bu.buDate BETWEEN @StartDate AND @EndDate
           AND ( ( @OrderNumber = 0 )
                  OR ( bu.[buNumber] = @OrderNumber ) )
           AND ( rs.IdTbl = @OrderTypesSrc )
           AND (
               --INCLUDE ACTIVE ORDERS
               ( ( @ShowActiveOrders = 1 )
                 AND ( oinf.Finished = 0 )
                 AND ( oinf.Add1 = 0 ) )
                OR
               --INCLUDE FINISHED ORDERS
               ( ( @ShowFinished = 1 )
                 AND ( ( oinf.Finished = 1 )
                        OR ( oinf.Finished = 2 ) ) )
                OR
               --INCLUDE CANCELLED ORDERS
               ( ( @ShowCancelled = 1 )
                 AND ( oinf.Add1 = 1 ) ) )
    -- IF @UserGuid = 0x0
    -- BEGIN
    -- 2 RESULT SETS
 
          -- Sort by OrderDate first
          SELECT *
          FROM   #result1
          ORDER  BY OrderDate,
                    CustomerName
          SELECT rs2.*
          FROM   #RESULT_2 rs2
                 INNER JOIN #result1 rs1
                         ON rs1.OrderGuid = rs2.OrderGuid
          ORDER  BY rs1.OrderDate,
                    rs1.OrderGuid,
                    rs1.CustomerName,
                    rs2.ApprovalDate
############################################################################## #END