#####################################################################
CREATE PROCEDURE PrcFillRateOrder @Acc           [UNIQUEIDENTIFIER] = 0x0,
                                  @Mt            AS [UNIQUEIDENTIFIER] = 0x0,
                                  @Gr            AS [UNIQUEIDENTIFIER] = 0x0,
                                  @Store         AS [UNIQUEIDENTIFIER] = 0x0,
                                  @Cost          [UNIQUEIDENTIFIER] = 0x0,
                                  @ReportSource  UNIQUEIDENTIFIER = 0x00,
                                  @OrderNumber   INT = 0,
                                  @FromDate      DATETIME = '1/1/1980',
                                  @ToDate        DATETIME = '1/1/2100',
                                  @UseUnit       [INT] = 1,
                                  @isFinished    BIT = 0,
                                  @isActive      BIT = 0,
                                  @OrderCond     UNIQUEIDENTIFIER = 0x00
AS
    SET NOCOUNT ON
	DECLARE @Lang INT = dbo.fnConnections_GetLanguage();
    --///////////////////////////////////////////////////////////////////////////////     
    -------Bill Resource ---------------------------------------------------------           
    CREATE TABLE #Src
      (
         Guid           UNIQUEIDENTIFIER,
         Sec            INT,
         ReadPrice      INT,
         UnPostedSec    INT,
         OrderName      NVARCHAR(25) COLLATE ARABIC_CI_AI DEFAULT '',
         OrderLatinName NVARCHAR(25) COLLATE ARABIC_CI_AI DEFAULT ''
      )
    INSERT INTO #Src
                (Guid,
                 Sec,
                 ReadPrice,
                 UnPostedSec)
    EXEC prcGetBillsTypesList2
      @ReportSource
    UPDATE src
    SET    OrderName = bt.Abbrev,
           OrderLatinName = bt.LatinAbbrev
    FROM   #Src AS src
           INNER JOIN bt000 AS bt
                   ON src.Guid = bt.guid
    -------Customer Table----------------------------------------------------------         
    CREATE TABLE [#CustTbl]
      (
         [CusGuid] [UNIQUEIDENTIFIER],
         [cuSec]   [INT]
      )
    INSERT INTO [#CustTbl]
    EXEC [prcGetCustsList]
      @Acc,
      NULL,
      NULL
    IF ISNULL(@Acc, 0x0) = 0x0
      BEGIN
          INSERT INTO [#CustTbl]
          VALUES     ( 0x0,
                       1)
      END
    -------Mat Table----------------------------------------------------------         
    CREATE TABLE [#MatTbl]
      (
         [mtGuid]     [UNIQUEIDENTIFIER],
         [mtSecurity] [INT]
      )
    INSERT INTO [#MatTbl]
    EXEC [prcGetMatsList]
      @Mt,
      @Gr,
      -1,
      NULL
    -------Store Table----------------------------------------------------------         
    DECLARE @StoreTbl TABLE
      (
         [stGuid] [UNIQUEIDENTIFIER],
         [stCode] NVARCHAR(255) COLLATE ARABIC_CI_AI,
         [stName] NVARCHAR(255) COLLATE ARABIC_CI_AI
      )
    INSERT INTO @StoreTbl
    SELECT [f].[Guid],
           [st].[Code],
           [st].[Name]
    FROM   [fnGetStoresList](@Store) AS [f]
           INNER JOIN [st000] AS [st]
                   ON [st].[Guid] = [f].[Guid]
    -------Cost Table-----------------------------------------------------------     
    DECLARE @CostTbl TABLE
      (
         [CostGUID] [UNIQUEIDENTIFIER]
      )
    INSERT INTO @CostTbl
    SELECT [Guid]
    FROM   [fnGetCostsList](@Cost)
    IF ISNULL(@Cost, 0x0) = 0x0
      INSERT INTO @CostTbl
      VALUES     ( 0x0)
    -------OrderCond Table---------------------------------------------------------- 
    CREATE TABLE #OrderCond
      (
         OrderGuid UNIQUEIDENTIFIER,
         Security  INT
      )
    INSERT INTO #OrderCond
                (OrderGuid,
                 Security)
    EXEC prcGetOrdersList
      @OrderCond
    -------------------------------------------------------------------         
    SELECT bubi.buGUID                            OrderGuid,
           bt.OrderName + ': '
           + Cast (bubi.buNumber AS NVARCHAR(10)) AS OrderName,
           bt.OrderLatinName + ': '
           + Cast(bubi.buNumber AS NVARCHAR(10))  AS OrderLatinName,
           bubi.buNumber,
           bubi.buDate                            AS OrderDate,
           bubi.buCustPtr,
           bubi.buCust_Name,
           bubi.buCostPtr,
           bubi.buStorePtr,
           ISNULL(co.NAME,N'')                    coName,
           ISNULL(co.LatinName ,N'')                          coLatinName,
           st.NAME                                stName,
           st.LatinName                           stLatinName,
           bubi.biGuid                            AS BiGuid,
           mt.Guid                                AS MatGuid,
           mt.Code + '-' + (CASE @Lang WHEN 0 THEN mt.Name ELSE (CASE mt.LatinName WHEN N'' THEN mt.Name ELSE mt.LatinName END) END ) AS MatName,
           mt.NAME                                AS materialName,
           Sum(CASE dbo.fnIsFinalState(bt.Guid, oit.Guid)
                 WHEN 1 THEN ori.Qty / ( CASE @UseUnit
                                           WHEN 1 THEN 1
                                           WHEN 2 THEN ( CASE mt.Unit2Fact
                                                           WHEN 0 THEN 1
                                                           ELSE mt.Unit2Fact
                                                         END )
                                           WHEN 3 THEN ( CASE mt.Unit3Fact
                                                           WHEN 0 THEN 1
                                                           ELSE mt.Unit3Fact
                                                         END )
                                           ELSE ( CASE mt.DefUnit
                                                    WHEN 1 THEN 1
                                                    WHEN 2 THEN mt.Unit2Fact
                                                    WHEN 3 THEN mt.Unit3Fact
                                                    ELSE 1
                                                  END )
                                         END )
                 ELSE 0
               END)                               AS RecievedQty,
           --SUM(CASE dbo.fnGetFinalState(bt.Guid) WHEN oit.Guid THEN ori.Qty ELSE 0 END ) AS RecievedQty
           ( CASE @UseUnit
               WHEN 1 THEN mt.Unity
               WHEN 2 THEN ( CASE
                               WHEN mt.Unit2Fact <> 0 THEN mt.Unit2
                               ELSE mt.Unity
                             END )
               WHEN 3 THEN ( CASE
                               WHEN mt.Unit3Fact <> 0 THEN mt.Unit3
                               ELSE mt.Unity
                             END )
               ELSE
                 CASE mt.DefUnit
                   WHEN 2 THEN ( CASE
                                   WHEN mt.Unit2Fact <> 0 THEN mt.Unit2
                                   ELSE mt.Unity
                                 END )
                   WHEN 3 THEN ( CASE
                                   WHEN mt.Unit3Fact <> 0 THEN mt.Unit3
                                   ELSE mt.Unity
                                 END )
                   ELSE mt.Unity
                 END
             END )                                AS [Unity],
           OInfo.Finished                         Finished,
           OInfo.Add1                             CLOSED
    INTO   #Result1
    FROM   #Src bt
           INNER JOIN vwBuBi bubi
                   ON bt.Guid = bubi.buType
           INNER JOIN #OrderCond cond
                   ON cond.OrderGuid = bubi.buGUID
           INNER JOIN mt000 mt
                   ON mt.Guid = bubi.biMatPtr
           INNER JOIN ori000 ori
                   ON bubi.biGUID = ori.POIGuid
           INNER JOIN oit000 oit
                   ON oit.Guid = ori.TypeGuid
           INNER JOIN ORADDINFO000 OInfo
                   ON bubi.buGUID = OInfo.ParentGuid
           INNER JOIN @CostTbl AS Costs
                   ON bubi.buCostPtr = Costs.CostGUID
           INNER JOIN #CustTbl AS Custs
                   ON bubi.buCustPtr = Custs.CusGuid
           INNER JOIN @StoreTbl AS Stores
                   ON bubi.buStorePtr = Stores.stGuid
           INNER JOIN #MatTbl AS mat
                   ON bubi.biMatPtr = mat.mtGuid
           INNER JOIN st000 AS st
                   ON st.GUID = bubi.biStorePtr
           LEFT JOIN co000 AS co
                  ON co.GUID = bubi.biCostGuid
    WHERE  ( @OrderNumber = 0
              OR bubi.buNumber = @OrderNumber )
           AND ( OInfo.Finished = ( CASE
                                      WHEN @isFinished = 0
                                           AND @isActive = 1 THEN 0
                                      WHEN @isFinished = 1
                                           AND @isActive = 0 THEN 1
                                    END )
                  OR ( @isFinished = 1
                       AND @isActive = 1 ) )
           AND bubi.buDate BETWEEN @FromDate AND @ToDate
           AND ori.Qty > 0
    GROUP  BY bubi.buGUID,
              bubi.biGUID,
              mt.Guid,
              mt.Code + '-' + (CASE @Lang WHEN 0 THEN mt.Name ELSE (CASE mt.LatinName WHEN N'' THEN mt.Name ELSE mt.LatinName END) END ) ,
              mt.NAME,
              bt.OrderName,
              bt.OrderLatinName,
              bubi.buNumber,
              bubi.buDate,
              bubi.buCustPtr,
              bubi.buCust_Name,
              bubi.buCostPtr,
              bubi.buStorePtr,
              co.NAME,
              co.LatinName,
              st.NAME,
              st.LatinName,
              OInfo.Finished,
              OInfo.Add1,
              mt.DefUnit,
              mt.Unity,
              mt.Unit2,
              mt.Unit2Fact,
              mt.Unit3,
              mt.Unit3Fact
    SELECT bi.Guid               AS BiGuid,
           bi.MatGuid            AS MatGuid,
           Sum(bi.Qty / ( CASE @UseUnit
                            WHEN 1 THEN 1
                            WHEN 2 THEN ( CASE mt.Unit2Fact
                                            WHEN 0 THEN 1
                                            ELSE mt.Unit2Fact
                                          END )
                            WHEN 3 THEN ( CASE mt.Unit3Fact
                                            WHEN 0 THEN 1
                                            ELSE mt.Unit3Fact
                                          END )
                            ELSE ( CASE mt.DefUnit
                                     WHEN 1 THEN 1
                                     WHEN 2 THEN mt.Unit2Fact
                                     WHEN 3 THEN mt.Unit3Fact
                                     ELSE 1
                                   END )
                          END )) AS OrderedQty
    INTO   #Result2
    FROM   #Src bt
           INNER JOIN bu000 bu
                   ON bt.Guid = bu.TypeGuid
           INNER JOIN #OrderCond cond
                   ON cond.OrderGuid = bu.Guid
           INNER JOIN bi000 bi
                   ON bu.Guid = bi.ParentGuid
           INNER JOIN ORADDINFO000 OInfo
                   ON bu.Guid = OInfo.ParentGuid
           INNER JOIN mt000 mt
                   ON mt.Guid = bi.MatGuid
    WHERE  ( @OrderNumber = 0
              OR bu.Number = @OrderNumber )
           AND ( OInfo.Finished = ( CASE
                                      WHEN @isFinished = 0
                                           AND @isActive = 1 THEN 0
                                      WHEN @isFinished = 1
                                           AND @isActive = 0 THEN 1
                                    END )
                  OR ( @isFinished = 1
                       AND @isActive = 1 ) )
           AND bu.[Date] BETWEEN @FromDate AND @ToDate
    GROUP  BY bi.Guid,
              bi.MatGuid
    DECLARE @SQL AS NVARCHAR(2000)
          SET @SQL= '
		SELECT DISTINCT
		    R1.OrderGuid,
			R1.BiGuid,   
			R1.MatGuid,   
			R1.MatName,   
			R1.RecievedQty, 
			R2.OrderedQty, 
			(R1.RecievedQty/ R2.OrderedQty)  AS FILLRATE,   
			R1.OrderName,   
			R1.OrderLatinName,  
			R1.buNumber,  
			R1.OrderDate,  
			R1.materialName,
			R1.Unity,
			R1.buCustPtr,
			R1.buCust_Name,
			R1.coName,
			R1.coLatinName,
			R1.stName,
			R1.stLatinName,
			R1.buCostPtr,
			R1.buStorePtr,
			ISNULL(R1.Finished, 0) AS Finished,
			ISNULL(R1.CLOSED, 0) AS CLOSED 
		FROM   
			#Result1 R1   
			INNER JOIN #Result2 R2 ON R1.BiGuid= R2.BiGuid AND  R1.MatGuid = R2.MatGuid '
          SET @SQL= @SQL + 'ORDER BY materialName' 
		  EXEC(@SQL)

######################################################################### 
#END