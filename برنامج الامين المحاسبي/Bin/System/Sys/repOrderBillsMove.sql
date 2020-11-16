#########################################################################
CREATE PROCEDURE repOrderBillsMove @OrderGuid     UNIQUEIDENTIFIER = 0x0,
                                   @MaterialGuid  UNIQUEIDENTIFIER = 0x0,
                                   -- 1: UNIT1, 2: UNIT2, 3: UNIT3, OTHER: DEFAULT UNIT 
                                   @UseUnit       INT = 1,
                                   @ReportSources UNIQUEIDENTIFIER = 0x0,
                                   @CurrencyGUID  [UNIQUEIDENTIFIER] = 0x0
AS
  BEGIN
      SET NOCOUNT ON;
	  DECLARE @Lang INT = dbo.fnConnections_GetLanguage();
       BEGIN
            SELECT [buGuid]                                                                                                             AS OrderGuid,
                   (CASE @Lang WHEN 0 THEN [buFormatedNumber] ELSE (CASE [buLatinFormatedNumber] WHEN N'' THEN [buFormatedNumber] ELSE [buLatinFormatedNumber] END) END ) AS FormattedName,
                   [buDate]                                                                                                             AS Date,
                   [biMatPtr]                                                                                                           AS MaterialGuid,
                   (CASE @Lang WHEN 0 THEN [mtName] ELSE (CASE mtLatinName WHEN N'' THEN [mtName] ELSE mtLatinName END) END )           AS MaterialName,
               
                   ( CASE @UseUnit
                       WHEN 1 THEN [biQty]
                       WHEN 2 THEN [biQty] / ( CASE
                                                 WHEN mtUnit2Fact = 0 THEN 1
                                                 ELSE mtUnit2Fact
                                               END )
                       WHEN 3 THEN [biQty] / ( CASE
                                                 WHEN mtUnit3Fact = 0 THEN 1
                                                 ELSE mtUnit3Fact
                                               END )
                       ELSE [biQty] / ( CASE
                                          WHEN mtDefUnitFact = 0 THEN 1
                                          ELSE mtDefUnitFact
                                        END )
                     END )                                                                                                              AS ItemQuantity,
                   ( [dbo].[fnCurrency_fix]([biPrice], [biCurrencyPtr], [biCurrencyVal], @CurrencyGUID, [buDate]) * [biQty] ) / ( CASE @UseUnit
                                                                                                                                    WHEN 1 THEN [biQty]
                                                                                                                                    WHEN 2 THEN [biQty] / ( CASE
                                                                                                                                                              WHEN mtUnit2Fact = 0 THEN 1
                                                                                                                                                              ELSE mtUnit2Fact
                                                                                                                                                            END )
                                                                                                                                    WHEN 3 THEN [biQty] / ( CASE
                                                                                                                                                              WHEN mtUnit3Fact = 0 THEN 1
                                                                                                                                                              ELSE mtUnit3Fact
                                                                                                                                                            END )
                                                                                                                                    ELSE [biQty] / ( CASE
                                                                                                                                                       WHEN mtDefUnitFact = 0 THEN 1
                                                                                                                                                       ELSE mtDefUnitFact
                                                                                                                                                     END )
                                                                                                                                  END ) AS ItemPrice,
                   ( [dbo].[fnCurrency_fix]([biPrice], [biCurrencyPtr], [biCurrencyVal], @CurrencyGUID, [buDate]) * [biQty] )           AS ItemTotal,
                   ( CASE @UseUnit
                       WHEN 1 THEN [mtUnity]
                       WHEN 2 THEN [mtUnit2]
                       WHEN 3 THEN [mtUnit3]
                       ELSE [mtDefUnitName]
                     END )                                                                                                              AS ItemUnit,
                   [biCostPtr]                                                                                                          AS CostGuid,
                  (CASE @Lang WHEN 0 THEN co.NAME ELSE (CASE co.LatinName WHEN N'' THEN co.NAME ELSE co.LatinName END) END )            AS CostName,
                   [biStorePtr]                                                                                                         AS StoreGuid,
                  (CASE @Lang WHEN 0 THEN st.Name ELSE (CASE st.LatinName WHEN N'' THEN st.Name ELSE st.LatinName END) END )            AS StoreName,
                   [biNotes]                                                                                                            AS Notes,
                   ( [biBonusQnt] / ( CASE @UseUnit
                                        WHEN 1 THEN 1
                                        WHEN 2 THEN ( CASE
                                                        WHEN mtUnit2Fact = 0 THEN 1
                                                        ELSE mtUnit2Fact
                                                      END )
                                        WHEN 3 THEN ( CASE
                                                        WHEN mtUnit3Fact = 0 THEN 1
                                                        ELSE mtUnit3Fact
                                                      END )
                                        ELSE ( CASE
                                                 WHEN mtDefUnitFact = 0 THEN 1
                                                 ELSE mtDefUnitFact
                                               END )
                                      END ) )                                                                                           AS BonusQuantity,
                   vwbi.biclassptr                                                                                                      [Class],
                   vwbi.biexpiredate                                                                                                    [ExpireDate],
				   0	AS RecType,
				   [dbo].[fnCurrency_fix]([vwbi].[biDiscount], [biCurrencyPtr], [biCurrencyVal], @CurrencyGUID, [buDate]) AS BiDiscount,
				   [dbo].[fnCurrency_fix]([vwbi].[biExtra], [biCurrencyPtr], [biCurrencyVal], @CurrencyGUID, [buDate]) AS BiExtra,
				   [dbo].[fnCurrency_fix]([vwbi].[biTotalDiscountPercent], [biCurrencyPtr], [biCurrencyVal], @CurrencyGUID, [buDate]) AS BiTotalDiscountPercent,
				   [dbo].[fnCurrency_fix]([vwbi].[biTotalExtraPercent], [biCurrencyPtr], [biCurrencyVal], @CurrencyGUID, [buDate]) AS BiTotalExtraPercent,
				   [dbo].[fnCurrency_fix](([vwbi].[biTotalDiscountPercent] + [vwbi].[biDiscount]), [biCurrencyPtr], [biCurrencyVal], @CurrencyGUID, [buDate]) AS SumOfDiscounts,
				   [dbo].[fnCurrency_fix](([vwbi].[biTotalExtraPercent] + [vwbi].[biExtra]), [biCurrencyPtr], [biCurrencyVal], @CurrencyGUID, [buDate]) AS SumOfExtras,
				   [dbo].[fnCurrency_fix](([vwbi].[biVat]), [biCurrencyPtr], [biCurrencyVal], @CurrencyGUID, [buDate]) AS Tax,
				   ([dbo].[fnCurrency_fix]((([biPrice] * [biQty]) 
											  - ([vwbi].[biTotalDiscountPercent] + [vwbi].[biDiscount]) 
											  + ([vwbi].[biTotalExtraPercent] + [vwbi].[biExtra]) 
											  + ([vwbi].[biVat]))
											 , [biCurrencyPtr], [biCurrencyVal], @CurrencyGUID, [buDate])
				   ) AS ItemNet
            FROM   vwExtended_bi vwbi
                   LEFT JOIN co000 co
                          ON co.[GUID] = vwbi.[biCostPtr]
                   LEFT JOIN st000 st
                          ON st.[GUID] = vwbi.[biStorePtr]
            WHERE  [btType] IN ( 5, 6 )
                   AND [buGUID] = @OrderGuid
                   AND ( ( @MaterialGuid = 0x0 )
                          OR ( biMatPtr = @MaterialGuid ) )

			UNION 
			 SELECT [buGuid]                                                                                                             AS BillGuid,
                  (CASE @Lang WHEN 0 THEN [buFormatedNumber] ELSE (CASE [buLatinFormatedNumber] WHEN N'' THEN [buFormatedNumber] ELSE [buLatinFormatedNumber] END) END ) AS FormattedName,
                   [buDate]                                                                                                             AS Date,
                   [biMatPtr]                                                                                                           AS MaterialGuid,
                   [mtName]                                                                                                             AS MaterialName,
                   ( CASE @UseUnit
                       WHEN 1 THEN [biQty]
                       WHEN 2 THEN [biQty] / ( CASE
                                                 WHEN mtUnit2Fact = 0 THEN 1
                                                 ELSE mtUnit2Fact
                                               END )
                       WHEN 3 THEN [biQty] / ( CASE
                                                 WHEN mtUnit3Fact = 0 THEN 1
                                                 ELSE mtUnit3Fact
                                               END )
                       ELSE [biQty] / ( CASE
                                          WHEN mtDefUnitFact = 0 THEN 1
                                          ELSE mtDefUnitFact
                                        END )
                     END )                                                                                                              AS ItemQuantity,
                   ( [biQty] * [dbo].[fnCurrency_fix]([biPrice], [biCurrencyPtr], [biCurrencyVal], @CurrencyGUID, [buDate]) ) / ( CASE @UseUnit
                                                                                                                                    WHEN 1 THEN [biQty]
                                                                                                                                    WHEN 2 THEN [biQty] / ( CASE
                                                                                                                                                              WHEN mtUnit2Fact = 0 THEN 1
                                                                                                                                                              ELSE mtUnit2Fact
                                                                                                                                                            END )
                                                                                                                                    WHEN 3 THEN [biQty] / ( CASE
                                                                                                                                                              WHEN mtUnit3Fact = 0 THEN 1
                                                                                                                                                              ELSE mtUnit3Fact
                                                                                                                                                            END )
                                                                                                                                    ELSE [biQty] / ( CASE
                                                                                                                                                       WHEN mtDefUnitFact = 0 THEN 1
                                                                                                                                                       ELSE mtDefUnitFact
                                                                                                                                                     END )
                                                                                                                                  END ) AS ItemPrice,
                   ( [dbo].[fnCurrency_fix]([biPrice], [biCurrencyPtr], [biCurrencyVal], @CurrencyGUID, [buDate]) * [biQty] )           AS ItemTotal,
                   ( CASE @UseUnit
                       WHEN 1 THEN [mtUnity]
                       WHEN 2 THEN [mtUnit2]
                       WHEN 3 THEN [mtUnit3]
                       ELSE [mtDefUnitName]
                     END )                                                                                                              AS ItemUnit,
                   [biCostPtr]                                                                                                          AS CostGuid,
                   ISNULL(co.[Name], '')                                                                                                AS CostName,
                   [biStorePtr]                                                                                                         AS StoreGuid,
                   ISNULL(st.[Name], '')                                                                                                AS StoreName,
                   [biNotes]                                                                                                            AS Notes,
                   ( [biBillBonusQnt] / ( CASE @UseUnit
                                            WHEN 1 THEN 1
                                            WHEN 2 THEN ( CASE
                                                            WHEN mtUnit2Fact = 0 THEN 1
                                                            ELSE mtUnit2Fact
                                                          END )
                                            WHEN 3 THEN ( CASE
                                                            WHEN mtUnit3Fact = 0 THEN 1
                                                            ELSE mtUnit3Fact
                                                          END )
                                            ELSE ( CASE
                                                     WHEN mtDefUnitFact = 0 THEN 1
                                                     ELSE mtDefUnitFact
                                                   END )
                                          END ) )                                                                                       AS BonusQuantity,
                   vwbi.biclassptr                                                                                                      [Class],
                   vwbi.biexpiredate                                                                                                    [ExpireDate],
				   1	AS RecType,
				   [dbo].[fnCurrency_fix]([vwbi].[biDiscount], [biCurrencyPtr], [biCurrencyVal], @CurrencyGUID, [buDate]) AS BiDiscount,
				   [dbo].[fnCurrency_fix]([vwbi].[biExtra], [biCurrencyPtr], [biCurrencyVal], @CurrencyGUID, [buDate]) AS BiExtra,
				   [dbo].[fnCurrency_fix]([vwbi].[biTotalDiscountPercent], [biCurrencyPtr], [biCurrencyVal], @CurrencyGUID, [buDate]) AS BiTotalDiscountPercent,
				   [dbo].[fnCurrency_fix]([vwbi].[biTotalExtraPercent], [biCurrencyPtr], [biCurrencyVal], @CurrencyGUID, [buDate]) AS BiTotalExtraPercent,
				   [dbo].[fnCurrency_fix](([vwbi].[biTotalDiscountPercent] + [vwbi].[biDiscount]), [biCurrencyPtr], [biCurrencyVal], @CurrencyGUID, [buDate]) AS SumOfDiscounts,
				   [dbo].[fnCurrency_fix](([vwbi].[biTotalExtraPercent] + [vwbi].[biExtra]), [biCurrencyPtr], [biCurrencyVal], @CurrencyGUID, [buDate]) AS SumOfExtras,
				   [dbo].[fnCurrency_fix](([vwbi].[biVat]), [biCurrencyPtr], [biCurrencyVal], @CurrencyGUID, [buDate]) AS Tax,
				   ([dbo].[fnCurrency_fix]((([biPrice] * [biQty]) 
											  - ([vwbi].[biTotalDiscountPercent] + [vwbi].[biDiscount]) 
											  + ([vwbi].[biTotalExtraPercent] + [vwbi].[biExtra]) 
											  + ([vwbi].[biVat]))
											 , [biCurrencyPtr], [biCurrencyVal], @CurrencyGUID, [buDate])
				   ) AS ItemNet
            FROM   vwExtended_bi vwbi
                   LEFT JOIN co000 co
                          ON co.[GUID] = vwbi.[biCostPtr]
                   LEFT JOIN st000 st
                          ON st.[GUID] = vwbi.[biStorePtr]
            WHERE  ( ( @MaterialGuid = 0x0 )
                      OR ( [biMatPtr] = @MaterialGuid ) )
                   AND [buGUID] IN (SELECT ori.BuGuid
                                    FROM   ori000 ori
                                    WHERE  BuGuid <> 0x0
                                           AND POGUID = @OrderGuid
                                           AND BuGuid IN (SELECT bu.[GUID]
                                                          FROM   bu000 bu
                                                                 INNER JOIN RepSrcs rs
                                                                         ON [IdType] = bu.TypeGUID
                                                          WHERE  rs.IdTbl = @ReportSources))
            ORDER  BY RecType, [buDate], FormattedName
        END 
		----------------------------------------------------------------------------------------------------------------------------------------------------------------------
        BEGIN
            SELECT [buGuid]                                                                                                    AS OrderGuid,
				   0x0																										   AS BillGuid,	
				   [buGUID]																									   AS ParentGuid,			
                  (CASE @Lang WHEN 0 THEN [buFormatedNumber] ELSE (CASE [buLatinFormatedNumber] WHEN N'' THEN [buFormatedNumber] ELSE [buLatinFormatedNumber] END) END )  AS FormattedName,
                   [buDate]                                                                                                    AS Date,
                   [buCust_Name]                                                                                               AS CustomerName,
                   Sum(CASE @UseUnit
                         WHEN 1 THEN [biQty]
                         WHEN 2 THEN [biQty] / ( CASE
                                                   WHEN mtUnit2Fact = 0 THEN 1
                                                   ELSE mtUnit2Fact
                                                 END )
                         WHEN 3 THEN [biQty] / ( CASE
                                                   WHEN mtUnit3Fact = 0 THEN 1
                                                   ELSE mtUnit3Fact
                                                 END )
                         ELSE [biQty] / ( CASE
                                            WHEN mtDefUnitFact = 0 THEN 1
                                            ELSE mtDefUnitFact
                                          END )
                       END)                                                                                                    AS TotalQuantity,
                   SUM([dbo].[fnCurrency_fix](([biPrice] * [biQty]) 
												+ ([vwbi].[biTotalExtraPercent] + [vwbi].[biExtra]) 
												+ ([vwbi].[biVat]) 
												- ([vwbi].[biTotalDiscountPercent] + [vwbi].[biDiscount])
											   , [biCurrencyPtr], [biCurrencyVal], @CurrencyGUID, [buDate])
				      ) AS TotalValue,
                   [buCostPtr]                                                                                                 AS CostGuid,
                   ISNULL(co.[Name], '')                                                                                       AS CostName,
                   [buStorePtr]                                                                                                AS StoreGuid,
                   ISNULL(st.[Name], '')                                                                                       AS StoreName,
                   [buNotes]                                                                                                   AS Notes,
                   Sum([biBillBonusQnt] / ( CASE @UseUnit
                                              WHEN 1 THEN 1
                                              WHEN 2 THEN ( CASE
                                                              WHEN mtUnit2Fact = 0 THEN 1
                                                              ELSE mtUnit2Fact
                                                            END )
                                              WHEN 3 THEN ( CASE
                                                              WHEN mtUnit3Fact = 0 THEN 1
                                                              ELSE mtUnit3Fact
                                                            END )
                                              ELSE ( CASE
                                                       WHEN mtDefUnitFact = 0 THEN 1
                                                       ELSE mtDefUnitFact
                                                     END )
                                            END ))                                                                             AS BonusQuantity,
                   vwbi.biclassptr                                                                                             [Class],
                   vwbi.biexpiredate                                                                                           [ExpireDate]
            FROM   vwExtended_bi vwbi
                   LEFT JOIN co000 co
                          ON co.[GUID] = vwbi.[buCostPtr]
                   LEFT JOIN st000 st
                          ON st.[GUID] = vwbi.[buStorePtr]
            WHERE  [btType] IN ( 5, 6 )
                   AND [buGUID] = @OrderGuid
                   AND ( ( @MaterialGuid = 0x0 )
                          OR ( biMatPtr = @MaterialGuid ) )
            GROUP  BY [buGuid],
                      [buType],
                     (CASE @Lang WHEN 0 THEN [buFormatedNumber] ELSE (CASE [buLatinFormatedNumber] WHEN N'' THEN [buFormatedNumber] ELSE [buLatinFormatedNumber] END) END ),
                      [buDate],
                      [buCust_Name],
                      [buCostPtr],
                      ISNULL(co.[Name], ''),
                      [buStorePtr],
                      ISNULL(st.[Name], ''),
                      [buNotes],
                      vwbi.biclassptr,
                      vwbi.biexpiredate
			UNION

            SELECT 0x0																											AS OrderGuid,
				   [buGuid]																										AS BillGuid,	
				   [buGUID]																									    AS ParentGuid,
                  (CASE @Lang WHEN 0 THEN [buFormatedNumber] ELSE (CASE [buLatinFormatedNumber] WHEN N'' THEN [buFormatedNumber] ELSE [buLatinFormatedNumber] END) END ) AS FormattedName,
                   [buDate]																										AS Date,
				   [buCust_Name]																								AS CustomerName,
                   Sum(CASE @UseUnit
                         WHEN 1 THEN [biQty]
                         WHEN 2 THEN [biQty] / ( CASE
                                                   WHEN mtUnit2Fact = 0 THEN 1
                                                   ELSE mtUnit2Fact
                                                 END )
                         WHEN 3 THEN [biQty] / ( CASE
                                                   WHEN mtUnit3Fact = 0 THEN 1
                                                   ELSE mtUnit3Fact
                                                 END )
                         ELSE [biQty] / ( CASE
                                            WHEN mtDefUnitFact = 0 THEN 1
                                            ELSE mtDefUnitFact
                                          END )
                       END)                                                                                                    AS TotalQuantity,
                    SUM([dbo].[fnCurrency_fix](([biPrice] * [biQty]) 
												+ ([vwbi].[biTotalExtraPercent] + [vwbi].[biExtra]) 
												+ ([vwbi].[biVat]) 
												- ([vwbi].[biTotalDiscountPercent] + [vwbi].[biDiscount])
											   , [biCurrencyPtr], [biCurrencyVal], @CurrencyGUID, [buDate])
				       ) AS TotalValue,
                   [buCostPtr]                                                                                                 AS CostGuid,
                   ISNULL(co.[Name], '')                                                                                       AS CostName,
                   [buStorePtr]                                                                                                AS StoreGuid,
                   ISNULL(st.[Name], '')                                                                                       AS StoreName,
                   [buNotes]                                                                                                   AS Notes,
                   Sum([biBillBonusQnt] / ( CASE @UseUnit
                                              WHEN 1 THEN 1
                                              WHEN 2 THEN ( CASE
                                                              WHEN mtUnit2Fact = 0 THEN 1
                                                              ELSE mtUnit2Fact
                                                            END )
                                              WHEN 3 THEN ( CASE
                                                              WHEN mtUnit3Fact = 0 THEN 1
                                                              ELSE mtUnit3Fact
                                                            END )
                                              ELSE ( CASE
                                                       WHEN mtDefUnitFact = 0 THEN 1
                                                       ELSE mtDefUnitFact
                                                     END )
                                            END ))                                                                             AS BonusQuantity,
                   vwbi.biclassptr                                                                                             [Class],
                   vwbi.biexpiredate                                                                                           [ExpireDate]
            FROM   vwExtended_bi vwbi
                   LEFT JOIN co000 co
                          ON co.[GUID] = vwbi.[buCostPtr]
                   LEFT JOIN st000 st
                          ON st.[GUID] = vwbi.[buStorePtr]
            WHERE  ( ( @MaterialGuid = 0x0 )
                      OR ( [biMatPtr] = @MaterialGuid ) )
                   AND [buGUID] IN (SELECT ori.BuGuid
                                    FROM   ori000 ori
                                    WHERE  BuGuid <> 0x0
                                           AND POGUID = @OrderGuid
                                           AND BuGuid IN (SELECT bu.[GUID]
                                                          FROM   bu000 bu
                                                                 INNER JOIN RepSrcs rs
                                                                         ON [IdType] = bu.TypeGUID
                                                          WHERE  rs.IdTbl = @ReportSources))
            GROUP  BY [buGuid],
                     (CASE @Lang WHEN 0 THEN [buFormatedNumber] ELSE (CASE [buLatinFormatedNumber] WHEN N'' THEN [buFormatedNumber] ELSE [buLatinFormatedNumber] END) END ) ,
                      [buDate],
                      [buCust_Name],
                      [buCostPtr],
                      ISNULL(co.[Name], ''),
                      [buStorePtr],
                      ISNULL(st.[Name], ''),
                      [buNotes],
                      vwbi.biclassptr,
                      vwbi.biexpiredate
			ORDER BY  buDate, OrderGuid DESC, FormattedName
        END
  END 
#########################################################################