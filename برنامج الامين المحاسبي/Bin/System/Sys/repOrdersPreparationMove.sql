#########################################################################
CREATE PROCEDURE repOrdersPreparationMove @StartDate               DATETIME = '2000-1-1',
                                          @EndDate                 DATETIME = '2200-12-31',
                                          @SupplierGUID            UNIQUEIDENTIFIER = 0x0,
                                          @MaterialGUID            UNIQUEIDENTIFIER = 0x0,
                                          @GroupGUID               UNIQUEIDENTIFIER = 0x0,
                                          @PreparationGUID         UNIQUEIDENTIFIER = 0x0 --The preparation Guid from symbol
                                          ,
                                          @SourcesGUID             UNIQUEIDENTIFIER = 0x0,
                                          @IsOrderGenerated        BIT = 1 --The preparation that generate purchase order. 
                                          ,
                                          @IsOrderNotGenerated     BIT = 1,
                                          @Unit                    INT = 1 -- 1: Unit1, 2: Unit2, 3: Unit3, other values: Default Unit
                                          ,
                                          @GroupQuantityByMaterial BIT = 0,
                                          @IsGrouped               BIT = 0,
										  @IsDetialsOfOrdersStages BIT = 0,
										  @IsShowOrderEnded        BIT = 0
AS
    SET NOCOUNT ON
    -------------------------------------------------------------------
    -- المواد التي يملك المستخدم صلاحية عليها
    CREATE TABLE #MatTble
      (
         MatGuid    UNIQUEIDENTIFIER,
         mtSecurity INT
      )
    INSERT INTO #MatTble
                (MatGuid,
                 mtSecurity)
    EXEC [prcGetMatsList]
      @MaterialGuid,
      @GroupGuid,
      -1 /*@MatType*/,
      0x0/*@MatCond*/
    -------------------------------------------------------------------
    ---------------------    #OrderTypesTbl   ------------------------
    -- جدول أنواع الطلبيات التي تم اختيارها في قائمة أنواع الطلبات
    CREATE TABLE #OrderTypesTbl
      (
         TYPE        UNIQUEIDENTIFIER,
         Sec         INT,
         ReadPrice   INT,
         UnPostedSec INT
      )
    INSERT INTO #OrderTypesTbl
    EXEC prcGetBillsTypesList2
      @SourcesGUID
    -------------------------------------------------------------------		
    DECLARE @CurrentLanguage BIT = 0
    SET @CurrentLanguage = (SELECT dbo.fnConnections_GetLanguage())
    -------------------------------------------------------------------		
	CREATE TABLE #StatesResult
	(
		StateName NVARCHAR(1000),
		StateGuid UNIQUEIDENTIFIER,
		StateQty FLOAT,
		StateType INT,
		PostQty FLOAT,
		PurchaseOrderGuid UNIQUEIDENTIFIER,
		SellOrderGuid UNIQUEIDENTIFIER
	)
	-------------------------------------------------------------------		
    SELECT ppi.ppoGuid                                                                                                                 PPOGuid,
		  
           PPi.biMatPtr                                                                                                                MaterialGuid,
           ppi.mtCode                                                                                                                  MaterialCode,
           --ppi.ppoPOGuid buGuid,
           CASE @CurrentLanguage
             WHEN 0 THEN ppi.mtName
             ELSE ppi.mtLatinName
           END                                                                                                                         MaterialName,
           ppi.ppoNumber                                                                                                               PreparationNumber,
           CAST(ISNULL(CASE @CurrentLanguage
                    WHEN 0 THEN cu.CustomerName
                    ELSE cu.LatinName
                  END, '') AS NVARCHAR (MAX))                                                                                          PreparationCustomerName,
           ppi.ppoOrderNum                                                                                                             PreparationCode,
           ppi.ppoDate                                                                                                                 PreparationDate,
           ( CASE
               WHEN ppi.ppiQuantity <> 0 THEN ( ppi.ppiQuantity * ppi.mtUnitFact ) / ( CASE @Unit
                                                                                         WHEN 1 THEN 1
                                                                                         WHEN 2 THEN
                                                                                           CASE
                                                                                             WHEN ppi.mtUnit2Fact <> 0 THEN ppi.mtUnit2Fact
                                                                                             ELSE 1
                                                                                           END
                                                                                         WHEN 3 THEN
                                                                                           CASE
                                                                                             WHEN ppi.mtUnit3Fact <> 0 THEN ppi.mtUnit3Fact
                                                                                             ELSE 1
                                                                                           END
                                                                                         ELSE ppi.mtDefUnitFact
                                                                                       END )
               ELSE ppi.biQty
             END )                                                                                                                     Quantity,
           ( CASE @Unit
               WHEN 1 THEN
                 CASE ppi.mtUnitFact
                   WHEN 0 THEN ppi.MtUnity
                   ELSE ppi.MtUnity
                 END
               WHEN 2 THEN
                 CASE ppi.mtUnit2Fact
                   WHEN 0 THEN ppi.MtUnity
                   ELSE ppi.MtUnit2
                 END
               WHEN 3 THEN
                 CASE ppi.mtUnit3Fact
                   WHEN 0 THEN ppi.MtUnity
                   ELSE ppi.MtUnit3
                 END
               ELSE ppi.mtDefUnitName
             END )                                                                                                                     UnityName,
           CASE
             WHEN ppi.ppoPOGuid <> 0x00 THEN 1
             ELSE 0
           END                                                                                                                         IsPosted,
           CAST(ISNULL(CASE @CurrentLanguage WHEN 0 THEN ppi.btName ELSE (SELECT LatinName FROM bt000 WHERE [guid] = ppi.buType) END + ': '
                  + Cast(ppi.buNumber AS NVARCHAR(100)), '') AS NVARCHAR(MAX))                                                         AS SellOrderFormattedNumber,
           ppi.buDate                                                                                                                  SellOrderDate,
           CASE @CurrentLanguage
             WHEN 0 THEN SellCust.CustomerName
             ELSE SellCust.LatinName
           END                                                                                                                         SellOrderCustomerName,
           ppi.ppoPOGuid                                                                                                               PurchaseOrderGuid,
           ppi.buGuid AS SellOrderGuid,
		   CAST(ISNULL(CASE @CurrentLanguage WHEN 0 THEN ppi.OtName ELSE ppi.OtLatinName END + ': ' + Cast(bu.Number AS NVARCHAR(100)), '') AS NVARCHAR(MAX)) PurchaseOrderFormattedNumber,
           ISNULL(bu.[Date], '1-1-1980')                                                                                               AS PurchaseOrderDate,
           ISNULL(POInfo.ExpectedDate, '1-1-1980')                                                                                     AS DeliveryDate,
           ppi.biNotes                                                                                                                 ItemNotes,
           CASE
             WHEN ppi.biCostPtr <> 0x00 THEN ppi.biCostPtr
             ELSE ppi.buCostPtr
           END                                                                                                                         CostCenterDescription,
           ppi.biClassPtr                                                                                                              Class,
           ISNULL(bu.CostGUID, 0x00)                                                                                                   AS PurchaseOrderCost,
           CAST(ISNULL(CASE @CurrentLanguage
                    WHEN 0 THEN costTbl.NAME
                    ELSE costTbl.LatinName
                  END, '') AS NVARCHAR(MAX))                                                                                           AS CostCenterName,
           ppi.PreparationDate                                                                                                         ItemPreparationDate,
           ( ppi.BiBillQty * ppi.mtUnitFact ) / ( CASE @Unit
                                                    WHEN 1 THEN 1
                                                    WHEN 2 THEN
                                                      CASE
                                                        WHEN ppi.mtUnit2Fact <> 0 THEN ppi.mtUnit2Fact
                                                        ELSE 1
                                                      END
                                                    WHEN 3 THEN
                                                      CASE
                                                        WHEN ppi.mtUnit3Fact <> 0 THEN ppi.mtUnit3Fact
                                                        ELSE 1
                                                      END
                                                    ELSE ppi.mtDefUnitFact
                                                  END )                                                                                SellQuantity,
           ISNULL(( vwBi.BiBillQty * vwBi.mtUnitFact ) / ( CASE @Unit
                                                             WHEN 1 THEN 1
                                                             WHEN 2 THEN
                                                               CASE
                                                                 WHEN vwBi.mtUnit2Fact <> 0 THEN vwBi.mtUnit2Fact
                                                                 ELSE 1
                                                               END
                                                             WHEN 3 THEN
                                                               CASE
                                                                 WHEN vwBi.mtUnit3Fact <> 0 THEN vwBi.mtUnit3Fact
                                                                 ELSE 1
                                                               END
                                                             ELSE vwBi.mtDefUnitFact
                                                           END ), 0)                                                                   PurchaseQuantity,
           CASE @CurrentLanguage
             WHEN 0 THEN CAST(ISNULL(SellBuCust.CustomerName, '') AS NVARCHAR(MAX))
             ELSE CAST(ISNULL(SellBuCust.LatinName, '') AS NVARCHAR(MAX))
           END                                                                                                                         PurchaseSupplierName
    INTO   #Result
    FROM   vwPPOrderBiItems ppi
           INNER JOIN #MatTble Mat
                   ON Mat.MatGuid = ppi.biMatPtr
           INNER JOIN #OrderTypesTbl SellOrderTypes
                   ON SellOrderTypes.[Type] = ppi.buType
           LEFT JOIN cu000 AS cu
                  ON cu.GUID = ppi.ppoSupplier
           LEFT JOIN cu000 AS SellCust
                  ON SellCust.GUID = ppi.buCustPtr -- íæÌÏ ØáÈÇÊ ãÍÖÑÉ ÈØÑíÞÉ ÏÝÚ äÞÏì ÈÏæä ÚãáÇÁ
           LEFT JOIN bu000 AS bu
                  ON bu.GUID = ppi.ppoPOGuid
           LEFT JOIN ORADDINFO000 AS POInfo
                  ON POInfo.ParentGuid = ppi.ppoPOGuid
           LEFT JOIN co000 AS costTbl
                  ON costTbl.GUID = ( CASE
                                        WHEN ppi.biCostPtr <> 0x00 THEN ppi.biCostPtr
                                        ELSE ppi.buCostPtr
                                      END )
           LEFT JOIN vwExtended_Bi vwBi
                  ON vwbi.buGUID = ppi.ppoPOGuid
                     AND ( ppi.biMatPtr = vwBi.biMatPtr )
           LEFT JOIN cu000 AS SellBuCust
                  ON SellBuCust.GUID = vwBi.buCustPtr
    WHERE  ppi.ppoDate BETWEEN @StartDate AND @EndDate
           AND ppi.ppoGuid = CASE @preparationGUID
                               WHEN 0x00 THEN ppi.ppoGuid
                               ELSE @preparationGUID
                             END
           AND ( ppi.ppoPOGuid = 0x00
                  OR ppi.ppoPOTypeGuid IN (SELECT [TYPE]
                                           FROM   #OrderTypesTbl) )
		 AND (POInfo.Finished = (CASE @IsShowOrderEnded 
									WHEN 0 THEN 0 
									ELSE  POInfo.Finished  END) OR POInfo.Finished IS NULL)
		 AND (POInfo.Add1 = 0 OR POInfo.Add1 IS NULL)
    ----------------------------------------------------------------------------------------------
	IF @IsDetialsOfOrdersStages = 1 
		BEGIN
			INSERT INTO #StatesResult
			SELECT DISTINCT
				   (CASE @CurrentLanguage 
						 WHEN 0 THEN oit.Name 
						 ELSE(CASE oit.LatinName
								   WHEN N'' THEN oit.Name 
								   ELSE oit.LatinName 
						      END)
				   END ) AS StateName, 
				   ori.TypeGuid AS StateGuid, 
				  (ori.Qty /(CASE @Unit
								  WHEN 0 THEN (CASE bi.biUnity
													WHEN 2 THEN (CASE mt.Unit2Fact WHEN 0  THEN 1 ELSE mt.Unit2Fact END) 
													WHEN 3 THEN (CASE mt.Unit3Fact WHEN 0  THEN 1 ELSE mt.Unit3Fact END) 
													ELSE 1
											   END)
						          WHEN 1 THEN 1 
						          WHEN 2 THEN (CASE mt.Unit2Fact WHEN 0 THEN 1 ELSE mt.Unit2Fact END) 
						          WHEN 3 THEN (CASE mt.Unit3Fact WHEN 0 THEN 1 ELSE mt.Unit3Fact END) 
						          ELSE (CASE mt.DefUnit WHEN 1 THEN 1  WHEN 2 THEN mt.Unit2Fact WHEN 3 THEN mt.Unit3Fact ELSE 1 END) 
						     END) 
						    ) AS StateQty,
				  oit.[Type],
				  oit.PostQty,
				  res.PurchaseOrderGuid,
				  res.SellOrderGuid
			FROM #Result AS res
			     INNER JOIN vwExtended_bi AS bi ON bi.buGUID = res.PurchaseOrderGuid OR bi.buGUID = res.SellOrderGuid
				 INNER JOIN #MatTble AS MAT ON MAT.MatGuid = bi.biMatPtr 
				 INNER JOIN mt000 AS MT ON MT.[GUID] = MAT.MatGuid
				 INNER JOIN ORI000 AS ori ON ori.POIGuid = bi.biGUID  
				 INNER JOIN oit000 AS oit ON oit.[Guid] = ori.TypeGuid	
		END
		----------------------------------------------------------------------------------------------
    -- جلب المواد الموجودة في الطلب والتي لم تدخل ضمن التحضير ولكن تم اضافتها للطلب بعد الترحيل
    SELECT bi.biGUID BiGuid,
		   bi.biMatPtr,
           bi.mtCode,
           CASE @CurrentLanguage
             WHEN 0 THEN mtName
             ELSE mtLatinName
           END                                                   MatName,
           CASE @Unit
             WHEN 1 THEN bi.MtUnity
             WHEN 2 THEN bi.MtUnit2
             WHEN 3 THEN bi.MtUnit3
             ELSE bi.mtDefUnitName
           END                                                   UnityName,
           bi.buGUID,
           bi.buFormatedNumber,
           bi.buDate,
           co.Number                                             coNumber,
           ISNULL(( bi.BiBillQty * bi.mtUnitFact ) / ( CASE @Unit
                                                         WHEN 1 THEN 1
                                                         WHEN 2 THEN
                                                           CASE
                                                             WHEN bi.mtUnit2Fact <> 0 THEN bi.mtUnit2Fact
                                                             ELSE 1
                                                           END
                                                         WHEN 3 THEN
                                                           CASE
                                                             WHEN bi.mtUnit3Fact <> 0 THEN bi.mtUnit3Fact
                                                             ELSE 1
                                                           END
                                                         ELSE bi.mtDefUnitFact
                                                       END ), 0) PurchaseQuantity,
           bi.biNotes,
           bi.biClassPtr,
           bi.biCostPtr,
           ppo.Guid                                              ppoGuid,
           ppo.Number                                            ppoNumber,
           ppo.OrderNum                                          ppoOrderNum,
           ppo.Date                                              ppoDate,
           CASE
             WHEN ppo.POGuid <> 0x00 THEN 1
             ELSE 0
           END                                                   IsPosted,
           CAST(ISNULL(CASE @CurrentLanguage
                    WHEN 0 THEN co.NAME
                    ELSE co.LatinName
                  END, '') AS NVARCHAR(MAX))                                      costCenterName
    INTO   #temp
    FROM   vwExtended_bi bi
           LEFT JOIN co000 co
                  ON co.GUID = bi.biCostPtr
           INNER JOIN ppo000 ppo
                   ON ppo.POGuid = bi.buGUID
    WHERE  bi.biMatPtr NOT IN (SELECT ppi.biMatPtr
                               FROM   vwPPOrderBiItems ppi
                                      INNER JOIN vwExtended_bi bi
                                              ON bi.buGUID = ppi.ppoPOGuid)
    INSERT INTO #Result
                (PPOGuid,
                 MaterialGuid,
                 MaterialCode,
                 MaterialName,
                 PreparationNumber,
                 PreparationCustomerName,
                 PreparationCode,
                 PreparationDate,
                 ItemPreparationDate,
                 Quantity,
                 UnityName,
                 IsPosted,
                 PurchaseOrderGuid,
                 PurchaseOrderFormattedNumber,
                 PurchaseOrderDate,
                 DeliveryDate,
                 PurchaseQuantity,
                 SellQuantity,
                 PurchaseSupplierName,
                 SellOrderFormattedNumber,
                 SellOrderDate,
                 SellOrderCustomerName,
                 ItemNotes,
                 CostCenterDescription,
                 Class,
                 PurchaseOrderCost,
                 CostCenterName)
    SELECT ppoGuid,
           biMatPtr,
           mtCode,
           MatName,
           ppoNumber,
           '',
           ppoOrderNum,
           ppoDate,
           '',
           0,
           UnityName,
           IsPosted,
           buGuid,
           buFormatedNumber,
           '',
           '',
           PurchaseQuantity,
           0,
           '',
           '',
           '',
           '',
           biNotes,
           0x0,
           biClassPtr,
           biCostPtr,
           costCenterName
    FROM   #temp
    -------------------------------------------------------------------	
    IF ( @IsOrderGenerated <> @IsOrderNotGenerated )
      DELETE FROM #Result
      WHERE  ( IsPosted = 0
               AND @IsOrderGenerated = 1 )
              OR ( IsPosted = 1
                   AND @IsOrderNotGenerated = 1 )
    -------------------------------------------------------------------	
    -------------------------------------------------------------------
    IF( @IsGrouped = 1
         OR @GroupQuantityByMaterial = 1 )
      BEGIN
          --تعديل كميات المواد المكررة
          SELECT Count(MaterialGuid) CountMatGuid,
                 MaterialGuid
          INTO   #TempCount
          FROM   #Result
          GROUP  BY PPOGUID,
                    MaterialGuid
          HAVING Count(MaterialGuid) > 1
          UPDATE #Result
          SET    PurchaseQuantity = PurchaseQuantity / T.CountMatGuid
          FROM   #Result R
                 INNER JOIN #TempCount t
                         ON T.MaterialGuid = R.MaterialGuid
      END
    IF ( @GroupQuantityByMaterial = 1 ) -- عند خيار تجميع كميات الموادالمكررة
	BEGIN
      SELECT PPOGuid,
			   MaterialGuid,
			   MaterialCode,
			   MaterialName,
			   PreparationNumber,
			   CAST(ISNULL(PreparationCustomerName,'')AS NVARCHAR (MAX)) As PreparationCustomerName,
			   PreparationCode,
			   PreparationDate,
			   SUM(Quantity) Quantity,
			   UnityName, 
			   IsPosted,
			   PurchaseOrderGuid,
			   CAST(ISNULL(PurchaseOrderFormattedNumber,'')AS NVARCHAR (MAX)) AS PurchaseOrderFormattedNumber,
			   PurchaseOrderDate,
			   DeliveryDate,
			   SUM(PurchaseQuantity) PurchaseQuantity,
			   SUM(SellQuantity) SellQuantity,
			   PurchaseSupplierName
		FROM   #Result
		GROUP BY
			   PPOGuid,
			   MaterialGuid,
			   MaterialCode,
			   MaterialName,
			   PreparationNumber,
			   PreparationCustomerName,
			   PreparationCode,			   
			   PreparationDate,
			   UnityName, 
			   IsPosted,
			   PurchaseOrderGuid,
			   PurchaseOrderFormattedNumber,
			   PurchaseOrderDate,
			   DeliveryDate,
			   PurchaseSupplierName
		ORDER BY PreparationNumber
      END
    ELSE IF @IsGrouped = 1 --عند خيار عرض تجميعى
      BEGIN
          SELECT MaterialGuid,
                 MaterialCode,
                 MaterialName,
                 UnityName,
                 Sum(Quantity)         Quantity,
                 Sum(PurchaseQuantity) PurchaseQuantity,
                 Sum(SellQuantity)     SellQuantity
          FROM   #Result
          GROUP  BY MaterialGuid,
                    MaterialCode,
                    MaterialName,
                    UnityName
          ORDER  BY MaterialCode
      END
    ELSE
      BEGIN
        SELECT * FROM #Result  
				ORDER BY PreparationNumber 
      END 

	IF ( @IsDetialsOfOrdersStages = 1 )
		BEGIN
			 SELECT DISTINCT
					S.StateName ,
					S.StateType ,
					S.PostQty
			 FROM #StatesResult S
			 ORDER BY
				  S.StateType,
				  S.PostQty
			
			SELECT * 
			FROM #StatesResult 		
		END
#########################################################################
#END