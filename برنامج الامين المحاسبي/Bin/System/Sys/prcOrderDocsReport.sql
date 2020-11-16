################################################################
CREATE PROCEDURE prcOrderDocsReport @Acc            UNIQUEIDENTIFIER = 0x0,
                                    @StoreGuid      UNIQUEIDENTIFIER = 0x0,
                                    @CostGuid       UNIQUEIDENTIFIER = 0x0,
                                    @TypeGuid       UNIQUEIDENTIFIER = 0x0,
                                    @DocGuid        UNIQUEIDENTIFIER = 0x0,
                                    @OrderNumber    INT = 0,
                                    @OrderCode      NVARCHAR(255) = '',
                                    @StartDate      DATETIME = '1/1/1980',
                                    @EndDate        DATETIME = '12/30/1980',
                                    @SortBy         INT = 0,
                                    @OrderCondition UNIQUEIDENTIFIER = 0x0,
                                    @ShowOptions    INT = 0
AS
  BEGIN
      SET NOCOUNT ON

      -------------------------------------------------------------------	    
      -------------------------   #OrdersTbl   --------------------------     
      --  ÌÏæá ÇáØáÈíÇÊ ÇáÊí ÊÍÞÞ ÇáÔÑæØ   
      CREATE TABLE #OrdersTbl
        (
           OrderGuid UNIQUEIDENTIFIER,
           Security  INT
        )

      INSERT INTO #OrdersTbl
                  (OrderGuid,
                   Security)
      EXEC prcGetOrdersList
        @OrderCondition

      ---------------------------------------------------------------------    
      ---------------------    #OrderAttachments   ------------------------   
      -- ÌÏæá ÃäæÇÚ ÇáãáÝÇÊ ÇáãÑÝÞÉ ÇáÊí Êã ÇÎÊíÇÑåÇ Ýí ÞÇÆãÉ ÇáãáÝÇÊ ÇáãÑÝÞÉ   
      SELECT IdType [Type]
      INTO   #OrderAttachments
      FROM   RepSrcs
      WHERE  IdTbl = @DocGuid

      --select [Type] from #OrderAttachments
      --------------------------------------------------------------------- 
      -------------------------   #CustTbl   ---------------------------   
      -- ÌÏæá ÇáÒÈÇÆä ÇáÊí ÊÍÞÞ ÇáÔÑæØ   
      CREATE TABLE #CustTbl
        (
           CustGuid UNIQUEIDENTIFIER,
           Security INT
        )

      INSERT INTO #CustTbl
      EXEC prcGetCustsList
        NULL,
        @Acc,
        0x00

      IF ISNULL(@Acc, 0x0) = 0x0
        INSERT INTO #CustTbl
        VALUES      (0x0,
                     1)

      ---------------------    @StoreTbl   --------------------------------  
      -- ÌÏæá ÇáãÓÊæÏÚÇÊ 	
      DECLARE @StoreTbl TABLE
        (
           StoreGuid UNIQUEIDENTIFIER
        )

      INSERT INTO @StoreTbl
      SELECT Guid
      FROM   fnGetStoresList(@StoreGuid)

      -------------------------------------------------------------------   
      ---------------------    @CostTbl   --------------------------------    
      -- ÌÏæá ãÑÇßÒ ÇáßáÝÉ   
      DECLARE @CostTbl TABLE
        (
           CostGuid UNIQUEIDENTIFIER
        )

      INSERT INTO @CostTbl
      SELECT Guid
      FROM   fnGetCostsList(@CostGuid)

      IF ISNULL(@CostGuid, 0x0) = 0x0
        INSERT INTO @CostTbl
        VALUES      (0x0)

      ------------------------------------------------------------------- 
      --Get All Orders which Achieve Report Conditions
      SELECT bt.[GUID]                          OrderTypeGuid,
             BT.Abbrev + ' _'
             + CONVERT(NVARCHAR(10), BU.Number) AS OrderName,
             bu.Number                          OrderNumber,
             bu.[GUID]                          AS OrderGuid,
             bu.[Date]                          AS OrderDate,
             bu.StoreGUID,
             ISNULL(storetbl.NAME, N'')         StoreName,
             bu.CostGUID,
             ISNULL(Costtbl.NAME, N'')          CostName,
             bu.Notes                           AS OrderNotes,
             bu.Number                          numOrder,
             OrderInfo.ADDATE,
             Custtbl.CustomerName,
             Docs.[GUID]                        DocGuid,
             Docs.NAME                          DocName,
             Docs.LatinName                     AS DocLatinName,
             ISNULL (dach.Achieved, 0)          Achieved,
             dach.[Path]
      INTO   #Result
      FROM   bt000 bt
             INNER JOIN bu000 bu
                     ON bt.[GUID] = bu.TypeGuid
             INNER JOIN #OrdersTbl Orders
                     ON Orders.OrderGuid = BU.[GUID]
             INNER JOIN ORADDINFO000 OrderInfo
                     ON OrderInfo.ParentGuid = BU.Guid
                        AND OrderInfo.Finished = 0
                        AND OrderInfo.Add1 = 0
             INNER JOIN #CustTbl Custs
                     ON bu.CustGuid = Custs.CustGuid
             INNER JOIN @CostTbl Costs
                     ON bu.CostGuid = Costs.CostGuid
             INNER JOIN @StoreTbl store
                     ON bu.StoreGUID = store.StoreGuid
             LEFT JOIN co000 costtbl
                    ON bu.CostGuid = costtbl.[GUID]
             INNER JOIN st000 storetbl
                     ON storetbl.[GUID] = bu.StoreGUID
             LEFT JOIN cu000 Custtbl
                    ON Custtbl.[GUID] = Custs.CustGuid
             INNER JOIN OrDocVs000 dvs
                     ON dvs.TypeGuid = bt.[Guid]
             INNER JOIN ORDOC000 Docs
                     ON dvs.DocGuid = Docs.[GUID]
             LEFT JOIN DocAch000 dach
                    ON dach.DocGuid = dvs.DocGuid
                       AND dach.OrderGuid = bu.[GUID]
             INNER JOIN #OrderAttachments arch
                     ON Docs.[GUID] = arch.[Type]
                        AND dvs.DocGuid = arch.[Type]
      WHERE  BT.Guid = ( CASE @TypeGuid
                           WHEN '00000000-0000-0000-0000-000000000000' THEN BT.Guid
                           ELSE @TypeGuid
                         END )
             AND bt.Type IN ( 5, 6 )
             AND bu.DATE BETWEEN @StartDate AND @EndDate
             AND BU.Number = ( CASE @OrderNumber
                                 WHEN 0 THEN BU.Number
                                 ELSE @OrderNumber
                               END )
             AND BU.Notes = ( CASE @OrderCode
                                WHEN '' THEN BU.Notes
                                ELSE @OrderCode
                              END )
      ORDER  BY bt.SortNum,
                bu.Number

      -----------------------------------------------------------
      --Delete Orders which don't Achieve Report Show Conditions
      DECLARE @count INT = (SELECT Count([Type])
         FROM   #OrderAttachments)

      IF (( @count > 1
             OR ( @ShowOptions & 2 ) = 0 ))
        BEGIN
            DECLARE @DelStr NVARCHAR(MAX) = '		
				DELETE o 
				FROM #Result o 
					CROSS APPLY( SELECT r.OrderGuid, AVG(CONVERT(float,r.Achieved)) [status]
								 FROM #Result r
								 WHERE OrderGuid = o.OrderGuid
								 GROUP BY r.OrderGuid
								 HAVING ' + CASE WHEN ((@ShowOptions & 1) = 0) THEN ' AVG(CONVERT(float, Achieved)) = 0 OR ' ELSE ' ' END --For Not Achieved Orders
              + CASE WHEN ((@ShowOptions & 2) = 0) THEN ' AVG(CONVERT(float, Achieved)) NOT IN (0 , 1) OR ' ELSE ' ' END --For Partially Achieved Orders 
              + CASE WHEN ((@ShowOptions & 4) = 0) THEN ' AVG(CONVERT(float, Achieved)) = 1 ' ELSE ' AVG(CONVERT(float, Achieved)) < -100 ' END --For Fully Achieved Orders
              + ' ) st '

            EXEC (@DelStr)
        END

      -----------------------------------------------------------
      --Get Final Result
      DECLARE @string NVARCHAR(MAX) = 'SELECT r.* 
		 FROM #Result r 
			INNER JOIN #OrderAttachments arch ON r.DocGuid = arch.[Type]'
        + ' ORDER BY ' + CASE @SortBy WHEN 0 THEN 'customername' WHEN 1 THEN 'OrderDate' WHEN 2 THEN 'OrderNumber' WHEN 3 THEN 'addate' ELSE 'customername ' END

      EXEC (@string)
  END 
################################################################ 
#END