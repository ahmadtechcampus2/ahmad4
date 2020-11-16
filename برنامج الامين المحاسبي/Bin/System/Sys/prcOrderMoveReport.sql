################################################################
CREATE FUNCTION fnGetOrderOrigin (@OrderGuid AS UNIQUEIDENTIFIER)
RETURNS UNIQUEIDENTIFIER
AS
  BEGIN
      DECLARE @Origin AS UNIQUEIDENTIFIER

      SET @Origin = @OrderGuid

      DECLARE @Resume AS BIT

      SET @Resume = 1

      WHILE @Resume = 1
        BEGIN
            DECLARE @Parent AS UNIQUEIDENTIFIER

            SET @Parent = 0x0

            SELECT @Parent = ParentGuid
            FROM   orrel000
            WHERE  ORGuid = @Origin

            IF ISNULL(@Parent, 0x0) = 0x0
              SET @Resume = 0
            ELSE
              SET @Origin = @Parent
        END

      RETURN @Origin
  END 
################################################################
CREATE PROCEDURE prcOrdersTree @g UNIQUEIDENTIFIER,
                               @l INT
AS
    INSERT INTO ORDER_MOVE_TmpTable
    VALUES      (@g,
                 @l)

    SET @l = @l + 1

    DECLARE @sc CURSOR

    SET @sc = CURSOR
    FOR SELECT REL.OrGuid,
               BU.Number
        FROM   OrRel000 REL
               INNER JOIN bu000 BU
                       ON BU.Guid = REL.OrGuid
        WHERE  ParentGuid = @g
        ORDER  BY BU.Number

    DECLARE @sg AS UNIQUEIDENTIFIER
    DECLARE @n AS INT

    OPEN @sc

    FETCH NEXT FROM @sc INTO @sg, @n

    WHILE @@FETCH_STATUS = 0
      BEGIN
          EXEC prcOrdersTree
            @sg,
            @l

          FETCH NEXT FROM @sc INTO @sg, @n
      END 
	  CLOSE @sc
	  DEALLOCATE @sc
################################################################
CREATE PROCEDURE prcOrderMove @OrderGuid    UNIQUEIDENTIFIER = 0x0,
                              @MaterialGuid UNIQUEIDENTIFIER = 0x0,
                              @Unit         INT = 0,
                              @OrderCFlds   NVARCHAR (Max) = ''
AS
  BEGIN
      SET NOCOUNT ON
	  DECLARE @Lang INT = dbo.fnConnections_GetLanguage();
      -- FIRST RESULT SET (ORDER STATES)
      SELECT [GUID],
             [Number],
             [Name],
             [LatinName]
      FROM   oit000
      WHERE  type = (SELECT CASE bt.Type
                              WHEN 5 THEN 1
                              ELSE 0
                            END
                     FROM   bt000 bt
                            INNER JOIN bu000 bu
                                    ON bu.TypeGuid = bt.Guid
                     WHERE  bu.Guid = @OrderGuid)
      ORDER  BY [Number]
          ;  WITH MAIN_DATA
                 AS (
                    -- SEED PART 
                    SELECT 0                              AS OrderLevel,
                           @OrderGuid                     AS OrderGuid,
                           bu.[TypeGUID]                  AS OrderTypeGUID,
                           bt.Name						  AS OrderName,
                           bu.[Number]                    AS OrderNumber,
                           CONVERT(UNIQUEIDENTIFIER, 0x0) AS DirectParent --0x0 for seed order (could be buggy in case the @OrderGuid is already generated from another order) 
                           ,
                           CONVERT(VARCHAR(250), '')      AS DirectParentName,
                           CONVERT(INT, 0)                AS DirectParentNumber
                    FROM   bu000 bu
                           INNER JOIN bt000 bt
                                   ON bu.TypeGUID = bt.[GUID]
                    WHERE  BU.[GUID] = @OrderGuid
                     --ORDERS GENERATED BY THE PASSED ORDER 
                     UNION ALL
                     -- RECURSIVE PART 
                     SELECT agg.OrderLevel + 1                                               AS OrderLevel,
                            orel.ORGUID                                                      AS OrderGuid,
                            bt.[GUID]                                                        AS OrderTypeGUID,
                            bt.[Name]                                                        AS OrderName,
                            bu.[Number]                                                      AS OrderNumber,
                            agg.OrderGuid                                                    AS DirectParent,
                            CONVERT(VARCHAR(250), agg.[OrderName] + ' : '
                                                  + CONVERT(VARCHAR(10), agg.[OrderNumber])) AS DirectParentName,
                            agg.[OrderNumber]                                                AS DirectParentNumber
                     FROM   ORREL000 orel
                            INNER JOIN MAIN_DATA agg
                                    ON agg.OrderGuid = orel.ParentGuid
                            INNER JOIN bu000 bu
                                    ON bu.[GUID] = orel.ORGUID
                            INNER JOIN bt000 bt
                                    ON bt.[GUID] = bu.[TypeGUID])
            SELECT OrderLevel,
                   OrderGuid,
                   vwBi.[buNumber]                                              AS OrderNumber,
                   vwBi.[buNotes]                                               AS OrderNotes,
                   vwBi.[buDate]                                                AS OrderDate,
                   vwBi.[buType]                                                AS OrderTypeGuid,
                   (CASE @Lang WHEN 0 THEN bt.Name ELSE (CASE bt.LatinName WHEN N'' THEN bt.Name ELSE bt.LatinName END) END )  + ' : '
                   + CONVERT(VARCHAR(10), vwBi.[buNumber])                      AS OrderName,
                   ( CASE
                       WHEN ( oinf.Finished = 1 ) THEN 1 -- FINISHED 
                       ELSE ( CASE
                                WHEN oinf.Add1 = 1 THEN 2 -- CANCELLED 
                                ELSE 0 -- ACTIVE 
                              END )
                     END )                                                      AS OrderStatus,
                   DirectParent,
                   DirectParentName,
                   DirectParentNumber,
                   vwBi.[biStorePtr]                                            AS StoreGuid,
                   (CASE @Lang WHEN 0 THEN st.Name ELSE (CASE st.LatinName WHEN N'' THEN st.Name ELSE st.LatinName END) END ) AS StoreName,
                   vwBi.[biCostPtr]                                             AS CostGuid,
                  (CASE @Lang WHEN 0 THEN co.NAME ELSE (CASE co.LatinName WHEN N'' THEN co.NAME ELSE co.LatinName END) END )  AS CostName,
                   vwBi.[buCustPtr]                                             AS CustGuid,
                   vwBi.[buCust_Name]                                           AS CustName,
                   vwBi.[biMatPtr]                                              AS MatGuid,
                   (CASE @Lang WHEN 0 THEN mt.Name ELSE (CASE mt.LatinName WHEN N'' THEN mt.Name ELSE mt.LatinName END) END )   AS MtName,
                   ( vwbi.biQty / ( CASE @Unit
                                      WHEN 0 THEN 1
                                      WHEN 1 THEN ISNULL(CASE vwBi.[mtUnit2Fact]
                                                           WHEN 0 THEN 1
                                                           ELSE vwBi.[mtUnit2Fact]
                                                         END, 1)
                                      WHEN 2 THEN ISNULL(CASE vwBi.[mtUnit3Fact]
                                                           WHEN 0 THEN 1
                                                           ELSE vwBi.[mtUnit3Fact]
                                                         END, 1)
                                      ELSE ISNULL(CASE vwBi.[mtDefUnitFact]
                                                    WHEN 0 THEN 1
                                                    ELSE vwBi.[mtDefUnitFact]
                                                  END, 1)
                                    END ) )                                     AS MatOrderedQty,
       ( vwbi.biQty * vwBi.biUnitPrice ) / ( vwbi.biQty / ( CASE @Unit
                                                                          WHEN 0 THEN 1
                                                                          WHEN 1 THEN ISNULL(CASE vwBi.[mtUnit2Fact]
                                                                                               WHEN 0 THEN 1
                                                                                               ELSE vwBi.[mtUnit2Fact]
                                                                                             END, 1)
                                                                          WHEN 2 THEN ISNULL(CASE vwBi.[mtUnit3Fact]
                                                                                               WHEN 0 THEN 1
                                                                                               ELSE vwBi.[mtUnit3Fact]
                                                                                             END, 1)
                                                                          ELSE ISNULL(CASE vwBi.[mtDefUnitFact]
                                                                                        WHEN 0 THEN 1
                                                                                        ELSE vwBi.[mtDefUnitFact]
                                                                                      END, 1)
                                                                        END ) ) AS MatUnitPrice,
                   ( CASE @Unit
                       WHEN 0 THEN vwBi.[mtUnity]
                       WHEN 1 THEN vwBi.[mtUnit2]
                       WHEN 2 THEN vwBi.[mtUnit3]
                       ELSE vwBi.[mtDefUnitName]
                     END )                                                      AS UnitName,
					vwbi.biQty * vwBi.biUnitPrice                                AS MatTotalPrice,
                   ( vwBi.[biBonusQnt] / ( CASE @Unit
                                             WHEN 0 THEN 1
                                             WHEN 1 THEN ISNULL(CASE vwBi.[mtUnit2Fact]
                                                                  WHEN 0 THEN 1
                                                                  ELSE vwBi.[mtUnit2Fact]
                                                                END, 1)
                                             WHEN 2 THEN ISNULL(CASE vwBi.[mtUnit3Fact]
                                                                  WHEN 0 THEN 1
                                                                  ELSE vwBi.[mtUnit3Fact]
                                                                END, 1)
                                             ELSE ISNULL(CASE vwBi.[mtDefUnitFact]
                                                           WHEN 0 THEN 1
                                                           ELSE vwBi.[mtDefUnitFact]
                                                         END, 1)
                                           END ) )                              AS MatBonus,
                   ori.TypeGuid                                                 AS StateGuid,
                   Sum(ori.Qty / ( CASE @Unit
                                     WHEN 0 THEN 1
                                     WHEN 1 THEN ISNULL(CASE vwBi.[mtUnit2Fact]
                                                          WHEN 0 THEN 1
                                                          ELSE vwBi.[mtUnit2Fact]
                                                        END, 1)
                                     WHEN 2 THEN ISNULL(CASE vwBi.[mtUnit3Fact]
                                                          WHEN 0 THEN 1
                                                          ELSE vwBi.[mtUnit3Fact]
                                                        END, 1)
                                     ELSE ISNULL(CASE vwBi.[mtDefUnitFact]
                                                   WHEN 0 THEN 1
                                                   ELSE vwBi.[mtDefUnitFact]
                                                 END, 1)
                                   END ))                                       AS MatStateQty,
								   vwBi.biGUID,
			vwBi.biDiscount AS Discount,
			vwBi.biExtra    AS Extra,
			vwBi.biVAT      AS Tax,
			vwBi.biTotalDiscountPercent,
			vwBi.biTotalExtraPercent,
			(vwBi.biTotalDiscountPercent + vwBi.biDiscount)  AS SumOfTotalDiscount,
			(vwBi.biTotalExtraPercent + vwBi.biExtra) AS SumOfTotalExtra
            INTO   #MAINDATADETAILED
            FROM   MAIN_DATA main
                   INNER JOIN vwExtended_bi vwBi
                           ON main.OrderGuid = vwBi.buGUID
                   INNER JOIN bt000 bt
                           ON bt.[GUID] = vwBi.[buType]
                   LEFT JOIN ORADDINFO000 oinf
                          ON oinf.[ParentGuid] = vwBi.[buGUID]
                   INNER JOIN ori000 ori
                           ON ori.POIGUID = vwBi.biGUID
                   LEFT JOIN st000 st
                          ON st.[GUID] = vwBi.[biStorePtr]
                   LEFT JOIN co000 co
                          ON co.[GUID] = vwBi.[biCostPtr]
                   LEFT JOIN mt000 mt
                          ON mt.[GUID] = vwbi.[biMatPtr]
            WHERE  ( ( @MaterialGuid = 0x00 )
                      OR ( mt.[GUID] = @MaterialGuid ) )
            GROUP  BY OrderLevel,
                      OrderGuid,
                      vwBi.[buNumber],
                      vwBi.[buNotes],
                      vwBi.[buDate],
                      vwBi.[buType],
                      (CASE @Lang WHEN 0 THEN bt.Name ELSE (CASE bt.LatinName WHEN N'' THEN bt.Name ELSE bt.LatinName END) END )  + ' : '
                      + CONVERT(VARCHAR(10), vwBi.[buNumber]),
                      bt.[Name],
                      ( CASE
                          WHEN ( oinf.Finished = 1 ) THEN 1 -- FINISHED 
                          ELSE ( CASE
                                   WHEN oinf.Add1 = 1 THEN 2 -- CANCELLED 
                                   ELSE 0 -- ACTIVE 
                                 END )
                        END ),
                      DirectParent,
                      DirectParentName,
                      DirectParentNumber,
                      vwBi.[biStorePtr],
                      (CASE @Lang WHEN 0 THEN st.Name ELSE (CASE st.LatinName WHEN N'' THEN st.Name ELSE st.LatinName END) END ),
                      vwBi.[biCostPtr],
                     (CASE @Lang WHEN 0 THEN co.NAME ELSE (CASE co.LatinName WHEN N'' THEN co.NAME ELSE co.LatinName END) END ),
                      vwBi.[buCustPtr],
                      vwBi.[buCust_Name],
                      vwBi.[biMatPtr],
                     (CASE @Lang WHEN 0 THEN mt.Name ELSE (CASE mt.LatinName WHEN N'' THEN mt.Name ELSE mt.LatinName END) END ),
                      ( vwbi.biQty / ( CASE @Unit
                                         WHEN 0 THEN 1
                                         WHEN 1 THEN ISNULL(CASE vwBi.[mtUnit2Fact]
                                                              WHEN 0 THEN 1
                                                              ELSE vwBi.[mtUnit2Fact]
                                                            END, 1)
                                         WHEN 2 THEN ISNULL(CASE vwBi.[mtUnit3Fact]
                                                              WHEN 0 THEN 1
                                                              ELSE vwBi.[mtUnit3Fact]
                                                            END, 1)
                                         ELSE ISNULL(CASE vwBi.[mtDefUnitFact]
                                                       WHEN 0 THEN 1
                                                       ELSE vwBi.[mtDefUnitFact]
                                                     END, 1)
                                       END ) ),
                      ( vwbi.biQty * vwBi.biUnitPrice ) / ( vwbi.biQty / ( CASE @Unit
                                                                             WHEN 0 THEN 1
                                                                             WHEN 1 THEN ISNULL(CASE vwBi.[mtUnit2Fact]
                                                                                                  WHEN 0 THEN 1
                                                                                                  ELSE vwBi.[mtUnit2Fact]
                                                                                                END, 1)
                                                                             WHEN 2 THEN ISNULL(CASE vwBi.[mtUnit3Fact]
                                                                                                  WHEN 0 THEN 1
                                                                                                  ELSE vwBi.[mtUnit3Fact]
                                                                                                END, 1)
                                                                             ELSE ISNULL(CASE vwBi.[mtDefUnitFact]
                                                                                           WHEN 0 THEN 1
                                                                                           ELSE vwBi.[mtDefUnitFact]
                                                                                         END, 1)
                                                                           END ) ),
                      ( CASE @Unit
                          WHEN 0 THEN vwBi.[mtUnity]
                          WHEN 1 THEN vwBi.[mtUnit2]
                          WHEN 2 THEN vwBi.[mtUnit3]
                          ELSE vwBi.[mtDefUnitName]
                        END ),
                      ( ( vwbi.biQty * vwBi.biUnitPrice ) / ( CASE @Unit
                                                                WHEN 0 THEN 1
                                                                WHEN 1 THEN ISNULL(CASE vwBi.[mtUnit2Fact]
                                                                                     WHEN 0 THEN 1
                                                                                     ELSE vwBi.[mtUnit2Fact]
                                                                                   END, 1)
                                                                WHEN 2 THEN ISNULL(CASE vwBi.[mtUnit3Fact]
                                                                                     WHEN 0 THEN 1
                                                                                     ELSE vwBi.[mtUnit3Fact]
                                                                                   END, 1)
                                                                ELSE ISNULL(CASE vwBi.[mtDefUnitFact]
                                                                              WHEN 0 THEN 1
                                                                              ELSE vwBi.[mtDefUnitFact]
                                                                            END, 1)
                                                              END ) ),
                      vwbi.biQty * vwBi.biUnitPrice,
                      ( vwBi.[biBonusQnt] / ( CASE @Unit
                                                WHEN 0 THEN 1
                                                WHEN 1 THEN ISNULL(CASE vwBi.[mtUnit2Fact]
                                                                     WHEN 0 THEN 1
                                                                     ELSE vwBi.[mtUnit2Fact]
                                                                   END, 1)
                                                WHEN 2 THEN ISNULL(CASE vwBi.[mtUnit3Fact]
                                                                     WHEN 0 THEN 1
                                                                     ELSE vwBi.[mtUnit3Fact]
                                                                   END, 1)
                                                ELSE ISNULL(CASE vwBi.[mtDefUnitFact]
                                                              WHEN 0 THEN 1
                                                              ELSE vwBi.[mtDefUnitFact]
                                                            END, 1)
                                              END ) ),
                      ori.TypeGuid, vwBi.biGUID ,vwBi.biDiscount, vwBi.biExtra, vwBi.biVAT,
					  vwBi.biTotalDiscountPercent,
					  vwBi.biTotalExtraPercent
					  
            SELECT OrderLevel,
                   OrderGuid,
                   OrderNumber,
                   OrderNotes,
                   OrderDate,
                   OrderTypeGuid,
                   OrderName,
                   OrderStatus,
                   DirectParent,
                   DirectParentName,
                   DirectParentNumber,
                   StoreGuid,
                   StoreName,
                   CostGuid,
                   CostName,
                   CustGuid,
                   CustName,
                   MatGuid,
                   MtName,
                   MatOrderedQty,
                   UnitName,
                   MatUnitPrice,
                   MatTotalPrice,
                   MatBonus,
                   StateGuid,
                   MatStateQty
            FROM   #MAINDATADETAILED
            ORDER  BY OrderLevel,
                      OrderNumber,
                      MtName
        ;    WITH MAIN_DATA
                 AS (
                    -- SEED PART 
                    SELECT 0                              AS OrderLevel,
                           @OrderGuid                     AS OrderGuid,
                           bu.[TypeGUID]                  AS OrderTypeGUID,
                           bt.[Name]                      AS OrderName,
                           bu.[Number]                    AS OrderNumber,
                           CONVERT(UNIQUEIDENTIFIER, 0x0) AS DirectParent --0x0 for seed order (could be buggy in case the @OrderGuid is already generated from another order) 
                           ,
                           CONVERT(VARCHAR(250), '')      AS DirectParentName,
                           CONVERT(INT, 0)                AS DirectParentNumber
                    FROM   bu000 bu
                           INNER JOIN bt000 bt
                                   ON bu.TypeGUID = bt.[GUID]
                    WHERE  BU.[GUID] = @OrderGuid
                     --ORDERS GENERATED BY THE PASSED ORDER 
                     UNION ALL
                     -- RECURSIVE PART 
                     SELECT agg.OrderLevel + 1                                               AS OrderLevel,
                            orel.ORGUID                                                      AS OrderGuid,
                            bt.[GUID]                                                        AS OrderTypeGUID,
                            bt.[Name]                                                        AS OrderName,
                            bu.[Number]                                                      AS OrderNumber,
                            agg.OrderGuid                                                    AS DirectParent,
                            CONVERT(VARCHAR(250), agg.[OrderName] + ' : '
                                                  + CONVERT(VARCHAR(10), agg.[OrderNumber])) AS DirectParentName,
                            agg.[OrderNumber]                                                AS DirectParentNumber
                     FROM   ORREL000 orel
                            INNER JOIN MAIN_DATA agg
                                    ON agg.OrderGuid = orel.ParentGuid
                            INNER JOIN bu000 bu
                                    ON bu.[GUID] = orel.ORGUID
                            INNER JOIN bt000 bt
                                    ON bt.[GUID] = bu.[TypeGUID])
            SELECT OrderLevel,
                   OrderGuid,
                   vwBi.[buNumber]                         AS OrderNumber,
                   vwBi.[buNotes]                          AS OrderNotes,
                   vwBi.[buDate]                           AS OrderDate,
                   vwBi.[buType]                           AS OrderTypeGuid,
                  (CASE @Lang WHEN 0 THEN bt.Name ELSE (CASE bt.LatinName WHEN N'' THEN bt.Name ELSE bt.LatinName END) END )+ ' : '
                   + CONVERT(VARCHAR(10), vwBi.[buNumber]) AS OrderName,
                   ( CASE
                       WHEN ( oinf.Finished = 1 ) THEN 1 -- FINISHED 
                       ELSE ( CASE
                                WHEN oinf.Add1 = 1 THEN 2 -- CANCELLED 
                                ELSE 0 -- ACTIVE 
                              END )
                     END )                                 AS OrderStatus,
                   DirectParent,
                   DirectParentName,
                   DirectParentNumber,
                   vwBi.[biStorePtr]                       AS StoreGuid,
                   st.[Name]                               AS StoreName,
                   vwBi.[biCostPtr]                        AS CostGuid,
                   ISNULL(co.[Name], '')                   AS CostName,
                   vwBi.[buCustPtr]                        AS CustGuid,
                   vwBi.[buCust_Name]                      AS CustName,
                   vwBi.[biMatPtr]                         AS MatGuid,
                   mt.[Name]                               AS MtName,
                   ( vwbi.biQty / ( CASE @Unit
                                      WHEN 0 THEN 1
                                      WHEN 1 THEN ISNULL(CASE vwBi.[mtUnit2Fact]
                                                           WHEN 0 THEN 1
                                                           ELSE vwBi.[mtUnit2Fact]
                                                         END, 1)
                                      WHEN 2 THEN ISNULL(CASE vwBi.[mtUnit3Fact]
                                                           WHEN 0 THEN 1
                                                           ELSE vwBi.[mtUnit3Fact]
                                                         END, 1)
                                      ELSE ISNULL(CASE vwBi.[mtDefUnitFact]
                                                    WHEN 0 THEN 1
                                                    ELSE vwBi.[mtDefUnitFact]
                                                  END, 1)
                                    END ) )                AS MatOrderedQty,
                   vwBi.[biUnitPrice]                      AS MatUnitPrice,
                   ( CASE @Unit
                       WHEN 0 THEN vwBi.[mtUnity]
                       WHEN 1 THEN vwBi.[mtUnit2]
                       WHEN 2 THEN vwBi.[mtUnit3]
                       ELSE vwBi.[mtDefUnitName]
                     END )                                 AS UnitName,
                   Sum(vwbi.biQty * vwBi.biUnitPrice)      AS MatTotalPrice,
                   Sum(vwBi.[biBonusQnt] / ( CASE @Unit
                                               WHEN 0 THEN 1
                                               WHEN 1 THEN ISNULL(CASE vwBi.[mtUnit2Fact]
                                                                    WHEN 0 THEN 1
                                                                    ELSE vwBi.[mtUnit2Fact]
                                                                  END, 1)
                                               WHEN 2 THEN ISNULL(CASE vwBi.[mtUnit3Fact]
                                                                    WHEN 0 THEN 1
                                                                    ELSE vwBi.[mtUnit3Fact]
                                                                  END, 1)
                                               ELSE ISNULL(CASE vwBi.[mtDefUnitFact]
                                                             WHEN 0 THEN 1
                                                             ELSE vwBi.[mtDefUnitFact]
                                                           END, 1)
                                             END ))        AS MatBonus,
					vwBi.buTotalDisc ,
					vwBi.buTotalExtra, 
					vwBi.buTotalTaxValue AS TotalTax
            INTO   #MAINDATAGGREGATE
            FROM   MAIN_DATA main
                   INNER JOIN vwExtended_bi vwBi
                           ON main.OrderGuid = vwBi.buGUID
                   INNER JOIN bt000 bt
                           ON bt.[GUID] = vwBi.[buType]
                   LEFT JOIN ORADDINFO000 oinf
                          ON oinf.[ParentGuid] = vwBi.[buGUID]
                   LEFT JOIN st000 st
                          ON st.[GUID] = vwBi.[biStorePtr]
                   LEFT JOIN co000 co
                          ON co.[GUID] = vwBi.[biCostPtr]
                   LEFT JOIN mt000 mt
                          ON mt.[GUID] = vwbi.[biMatPtr]
            GROUP  BY OrderLevel,
                      OrderGuid,
                      vwBi.[buNumber],
                      vwBi.[buNotes],
                      vwBi.[buDate],
                      vwBi.[buType],
                     (CASE @Lang WHEN 0 THEN bt.Name ELSE (CASE bt.LatinName WHEN N'' THEN bt.Name ELSE bt.LatinName END) END )+ ' : '
                      + CONVERT(VARCHAR(10), vwBi.[buNumber]),
                      ( CASE
                          WHEN ( oinf.Finished = 1 ) THEN 1 -- FINISHED 
                          ELSE ( CASE
                                   WHEN oinf.Add1 = 1 THEN 2 -- CANCELLED 
                                   ELSE 0 -- ACTIVE 
                                 END )
                        END ),
                      DirectParent,
                      DirectParentName,
                      DirectParentNumber,
                      vwBi.[biStorePtr],
                      st.[Name],
                      vwBi.[biCostPtr],
                      ISNULL(co.[Name], ''),
                      vwBi.[buCustPtr],
                      vwBi.[buCust_Name],
                      vwBi.[biMatPtr],
                      mt.[Name],
                      ( vwbi.biQty / ( CASE @Unit
                                         WHEN 0 THEN 1
                                         WHEN 1 THEN ISNULL(CASE vwBi.[mtUnit2Fact]
                                                              WHEN 0 THEN 1
                                                              ELSE vwBi.[mtUnit2Fact]
                                                            END, 1)
                                         WHEN 2 THEN ISNULL(CASE vwBi.[mtUnit3Fact]
                                                              WHEN 0 THEN 1
                                                              ELSE vwBi.[mtUnit3Fact]
                                                            END, 1)
                                         ELSE ISNULL(CASE vwBi.[mtDefUnitFact]
                                                       WHEN 0 THEN 1
                                                       ELSE vwBi.[mtDefUnitFact]
                                                     END, 1)
                                       END ) ),
                      vwBi.[biUnitPrice],
                      ( CASE @Unit
                          WHEN 0 THEN vwBi.[mtUnity]
                          WHEN 1 THEN vwBi.[mtUnit2]
                          WHEN 2 THEN vwBi.[mtUnit3]
                          ELSE vwBi.[mtDefUnitName]
                        END ),
						vwBi.buTotalDisc ,
					    vwBi.buTotalExtra,
						vwBi.buTotalTaxValue
						

            SELECT DISTINCT OrderLevel,
                            OrderGuid,
                            OrderNumber,
                            OrderNotes,
                            OrderDate,
                            OrderTypeGuid,
                            OrderName,
                            OrderStatus,
                            DirectParent,
                            DirectParentName,
                            DirectParentNumber,
                            StoreGuid,
                            StoreName,
                            CostGuid,
                            CostName,
                            CustGuid,
                            CustName,
                            SUM(MatOrderedQty) AS OrderedQty,
                            SUM(MatBonus)      AS BonusQty,
                            SUM(MatTotalPrice) AS Total,
							buTotalDisc,
							buTotalExtra,
							TotalTax
            FROM   #MAINDATAGGREGATE
            GROUP  BY OrderLevel,
                      OrderGuid,
                      OrderNumber,
                      OrderNotes,
                      OrderDate,
                      OrderTypeGuid,
                      OrderName,
                      OrderStatus,
                      DirectParent,
                      DirectParentName,
                      DirectParentNumber,
                      StoreGuid,
                      StoreName,
                      CostGuid,
                      CostName,
                      CustGuid,
                      CustName,
					  buTotalDisc,
					  buTotalExtra,
					  TotalTax
            ORDER  BY OrderLevel,
                      OrderNumber
	   SELECT DISTINCT 
					  M.MatGuid,
					  M.MtName,
					  M.MatOrderedQty,
					  M.UnitName,
					  M.MatUnitPrice,
					  m.MatTotalPrice,
					  M.MatBonus,
					  M.OrderGuid,
					  M.OrderName,
					  M.OrderLevel,
					  M.OrderNumber,
					  M.StoreGuid,
					  M.StoreName,
					  M.CostGuid,
					  M.CostName,
					  M.CustGuid,
					  M.CustName,
					  M.biGUID, 
					  M.Discount,
					  M.Extra,
					 (M.Discount / CASE M.MatTotalPrice WHEN 0 THEN 1 ELSE  M.MatTotalPrice END) AS DiscountRatio,
					 (M.Extra / CASE M.MatTotalPrice WHEN 0 THEN 1 ELSE  M.MatTotalPrice END)  AS ExtraRatio,
					  M.Tax,
					  M.biTotalDiscountPercent,
					  M.biTotalExtraPercent,
					  M.SumOfTotalDiscount,
					  M.SumOfTotalExtra,
					  (M.MatTotalPrice - M.SumOfTotalDiscount + M.SumOfTotalExtra + M.Tax) AS NetItemValue
	    FROM   #MAINDATADETAILED M
		ORDER  BY M.OrderLevel,
				  M.OrderNumber,
				  M.MtName
  END 

################################################################
#END		