#############################################################################

CREATE FUNCTION JOCfnGetManufactoryUnitName (@Manufactory UNIQUEIDENTIFIER, @Unit INT)
RETURNS NVARCHAR(250)
BEGIN

	
	DECLARE @ProductionUnitOne UNIQUEIDENTIFIER = (SELECT ProductionUnitOne From Manufactory000 WHERE Guid = @Manufactory)
	DECLARE @ProductionUnitTwo UNIQUEIDENTIFIER = (SELECT ProductionUnitTwo From Manufactory000 WHERE Guid = @Manufactory)

	RETURN (SELECT Unit.Name FROM JOCProductionUnit000 Unit
	WHERE Unit.GUID = CASE WHEN @Unit = 1 THEN @ProductionUnitOne WHEN ISNULL(@ProductionUnitTwo, 0x0) = 0x0 THEN @ProductionUnitOne ELSE @ProductionUnitTwo END
		)
END
#############################################################################

CREATE VIEW JOCvwGeneralCostItems 
-- «·„Ê«œ  «·„” Œœ„… ›Ì ›Ê« Ì— √„— «· ‘€Ì· + «·„—«Õ· «· Ì  „  «·⁄„·Ì… ›ÌÂ«
AS
SELECT 
materials.MatName
,materials.Code
,materials.MatLatinName
,materials.SNFlag
,materials.ExpireFlag
,Bill.biGUID
,Bill.biQty
,Bill.biPrice
,Bill.biUnity
,Bill.buType
,Bill.biNumber
,Bill.biMatPtr
,Bill.biExpireDate
,Bill.biClassPtr
,Bill.biNotes
,CASE WHEN Bill.biUnity = 1 THEN mt.Unity WHEN Bill.biUnity = 2 THEN mt.Unit2 ELSE mt.Unit3 END AS biUnitName
,CASE WHEN Bill.biUnity = 2 THEN mt.Unit2Fact WHEN Bill.biUnity = 3 THEN mt.Unit3Fact ELSE 1 END  AS biUnitFactor
,items.StageGuid 
,items.ParentGuid
,items.CostType
,JobOrder.JobOrderGuid
,JobOrder.JobOrderNumber
,JobOrder.JobOrderOperatingBOM
,JobOrder.JobOrderManufactoryGuid
,JobOrder.JobOrderProductionLine
,JobOrder.ManufactoryMatRequestBillType
,JobOrder.ManufactoryMatReturnBillType
,JobOrder.ManufactoryFinishedGoodsBillType
,JobOrder.ManufactoryInTransBillType
,JobOrder.ManufactoryOutTransBillType
,JobOrder.UseStages
 FROM JOCGeneralCostItems000 items 
INNER JOIN vwBuBi Bill ON items.BillItemGuid = Bill.biGUID
INNER JOIN JocVwJobOrder JobOrder ON JobOrder.JobOrderAccount = Bill.buCustAcc
INNER JOIN JocVwMaterialsWithAlternatives materials ON Bill.biMatPtr = materials.[GUID]
INNER JOIN mt000 mt on Bill.biMatPtr = mt.[GUID]
#############################################################################

CREATE VIEW JOCvwGeneralCostItemsQuantities
--«·„Ê«œ «·„” Œœ„… ›Ì ›Ê« Ì— √Ê«„— «· ‘€Ì· + „Ã„Ê⁄ ﬂ„Ì«  «·’—› Ê «·„— Ã⁄ Ê «·„‰«ﬁ·… Õ”» «·„—«Õ·
AS
SELECT 
items.JobOrderGuid
,items.JobOrderNumber
,items.biNumber			AS Number
,items.biMatPtr			AS MaterialGuid
,items.MatName			AS MaterialName 
,items.StageGuid		AS StageGuid

,SUM(items.biQty * CASE   WHEN (items.buType = items.ManufactoryMatRequestBillType ) THEN 1 ELSE 0 END ) AS ExpensedQty 
,SUM(items.biQty * CASE   WHEN (items.buType = items.ManufactoryMatReturnBillType ) THEN 1 ELSE 0 END ) AS ReturnedQty 
,SUM(items.biQty * CASE   WHEN (items.buType = items.ManufactoryOutTransBillType ) THEN 1 ELSE 0 END)  AS OutTransQty 
,SUM(items.biQty * CASE   WHEN (items.buType = items.ManufactoryInTransBillType ) THEN 1 ELSE 0 END ) AS InTransQty 


,SUM(items.biQty * CASE WHEN (items.buType = items.ManufactoryMatRequestBillType OR items.buType = ManufactoryOutTransBillType) 
						 THEN 1 ELSE 0 END)  AS TotalOutQty
,SUM(items.biQty * CASE WHEN (items.buType = items.ManufactoryMatReturnBillType OR items.buType = ManufactoryInTransBillType) 
						 THEN 1 ELSE 0 END)  AS TotalInQty

,SUM(items.biQty * CASE WHEN (items.buType = items.ManufactoryMatRequestBillType OR items.buType = ManufactoryOutTransBillType) THEN 1
								WHEN (items.buType = items.ManufactoryMatReturnBillType OR items.buType = ManufactoryInTransBillType) THEN -1
						 ELSE 0 END ) AS NetQty
,SUM(items.biPrice * (items.biQty / items.biUnitFactor) * CASE WHEN (items.buType = items.ManufactoryMatRequestBillType OR items.buType = ManufactoryOutTransBillType) THEN 1
								WHEN (items.buType = items.ManufactoryMatReturnBillType OR items.buType = ManufactoryInTransBillType) THEN -1
						 ELSE 0 END)  AS NetExchange
FROM JOCvwGeneralCostItems items
GROUP BY 
items.JobOrderGuid
,items.JobOrderNumber
,items.biMatPtr
,items.biNumber
,items.MatName
,items.StageGuid
,items.buType
,items.ManufactoryInTransBillType
,items.ManufactoryOutTransBillType
,items.ManufactoryMatRequestBillType
,items.ManufactoryMatReturnBillType
,items.UseStages
#############################################################################
CREATE VIEW JOCvwJobOrderRawMaterialsWithoutDist
AS

SELECT 
RawMaterialGuid
,OperatingBOMGuid 
,Max(Quantity)	AS Quantity 
,MAX(Unit) AS Unit
,MAX(CostRank) AS CostRank
,StageGuid
,MAX(AllocationType) AS AllocationType
,MAX(RawMaterialIndex) AS RawMaterialIndex

FROM JOCOperatingBOMRawMaterials000 
GROUP BY 
RawMaterialGuid, OperatingBOMGuid,StageGuid
#############################################################################
CREATE VIEW JOCvwJobOrderRawMaterials
AS
--ÕﬁÊ· ‰„«–Ã √Ê«„— «· €‘Ì· + „⁄—› Õﬁ· √„— «· ‘€Ì·
SELECT 
MT.GUID					AS MaterialGuid
,MT.Code					AS MaterialCode
,MT.Name				AS MaterialName
,MT.LatinName			AS MaterialLatinName
,RawMaterials.Quantity	AS RawMatQty
,RawMaterials.Unit				AS Unit
,CASE WHEN RawMaterials.Unit = 1 THEN 	materials.Unity WHEN RawMaterials.Unit = 2 THEN materials.Unit2 ELSE materials.Unit3 END	AS UnitName
,CASE  WHEN RawMaterials.Unit = 2 THEN materials.Unit2Fact WHEN  RawMaterials.Unit = 3 THEN materials.Unit3Fact ELSE 1 END	AS UnitFactor
,RawMaterials.StageGuid				AS StageGuid
,RawMaterials.RawMaterialIndex			AS BOMIndex
,materials.ExpireFlag
,materials.ClassFlag
,materials.SNFlag
,JobOrder.JobOrderGuid
,JobOrder.JobOrderInstanceProductionQuantity AS BOMProductionQty
,Stages.Name    AS StageName
,PLStages.SerialOrder AS StageIndex
,RawMaterials.AllocationType AS DistMethod
,materials.HasAlterMat
 FROM JOCvwJobOrderRawMaterialsWithoutDist RawMaterials 
INNER JOIN mt000 Mt ON MT.GUID = RawMaterials.RawMaterialGuid
INNER JOIN JocVwMaterialsWithAlternatives materials ON materials.GUID = RawMaterials.RawMaterialGuid
INNER JOIN JocVwJobOrder JobOrder ON RawMaterials.OperatingBOMGuid = JobOrder.JobOrderOperatingBOM
LEFT JOIN  JOCStages000 Stages ON Stages.[GUID]=RawMaterials.StageGuid
LEFT JOIN JOCProductionLineStages000 PLStages ON PLStages.ParentGUID = JobOrder.JobOrderProductionLine AND PLStages.StageGuid = Stages.[GUID]
#############################################################################
CREATE VIEW vwMaterialInventory
AS

SELECT 
	Bill.biMatPtr	AS MaterialGuid
	,Bill.buStorePtr AS StoreGuid
	,SUM(Bill.biQty * (CASE WHEN Bill.buIsPosted = 0 THEN 0 WHEN Bill.btIsInput = 1 THEN 1  ELSE -1 END)) AS Qty
	FROM vwBuBi Bill
	GROUP BY
	Bill.biMatPtr
	,Bill.buStorePtr
#############################################################################

CREATE VIEW JOCvwBillItemsQtys
--„Ã„Ê⁄ ﬂ„Ì«  «·„Ê«œ «·„” Œœ„… ›Ì ›Ê« Ì— √Ê«„— «· ‘€Ì· 
AS
SELECT 
MaterialGuid
,StageGuid
,JobOrderGuid 
,SUM(ISNULL(NetQty,0)) NetQty
,SUM(ISNULL(items.ExpensedQty,0)) ExpensedQty
,SUM(ISNULL(items.ReturnedQty,0)) ReturnedQty
,SUM(ISNULL(items.InTransQty,0)) TransInQty
,SUM(ISNULL(items.OutTransQty,0)) TransOutQty
,SUM(ISNULL(items.TotalOutQty,0))	TotalOutQty
,SUM(ISNULL(items.TotalInQty	,0))	TotalInQty
,SUM(ISNULL(items.NetExchange,0))	NetExchange
 FROM JOCvwGeneralCostItemsQuantities items
GROUP BY 
MaterialGuid
,MaterialName
,StageGuid
,JobOrderGuid
#############################################################################

CREATE VIEW JOCvwJobOrderRawMaterialsQuantities
--„Ê«œ ‰„Ê–Ã √„— «· ‘€Ì· + ’«›Ì «·ﬂ„Ì«  «·„” Œœ„… ›Ì «·›Ê« Ì— + „⁄—› Õﬁ· √„— «· ‘€Ì·
AS
	SELECT  
		materials.MaterialGuid	
		,materials.MaterialCode		
		,materials.MaterialName			
		,materials.MaterialLatinName	
		,materials.RawMatQty 
		,materials.RawMatQty * dbo.JOCfngetMaterialUnitFactor(materials.MaterialGuid, materials.Unit) AS RawMatQty1 --Qty with unit 1
		,materials.Unit	
		,materials.UnitName		
		,materials.UnitFactor	
		,materials.StageGuid	
		,materials.StageName		
		,materials.JobOrderGuid
		,materials.BOMIndex
		,materials.ExpireFlag
		,materials.ClassFlag
		,materials.SNFlag
		,JobOrder.JobOrderReplicasCount 
		,materials.RawMatQty * JobOrder.JobOrderReplicasCount  AS JobOrderRequiredQty
		,(CASE materials.DistMethod 
			   WHEN 1 THEN (SELECT dbo.JOCfnGetRawMaterialTotalDirectRequiredQty(materials.JobOrderGuid, materials.MaterialGuid, materials.StageGuid)) 
			   ELSE (SELECT dbo.JOCfnGetRawMaterialTotalInDirectRequiredQty(materials.JobOrderGuid, materials.MaterialGuid, materials.StageGuid))
		  END) AS JobOrderRequiredQty1
		,materials.BOMProductionQty
		,materials.StageIndex 
		,JobOrder.JobOrderBOM 
		,JobOrder.JobOrderManufactoryGuid
		,JobOrder.JobOrderProductionLine
		,JobOrder.JobOrderStartDate
		,JobOrder.JobOrderEndDate 
		,JobOrder.JobOrderStatus
		,JobOrder.JobOrderOperatingBOM
		,SUM(ISNULL(Cost.NetQty,0))  NetQty
		,SUM(ISNULL(Cost.NetQty,0))  / materials.UnitFactor AS BOMNetQty
		,SUM(ISNULL(Cost.ExpensedQty,0))	ExpensedQty
		,SUM(ISNULL(Cost.ReturnedQty,0))	ReturnedQty
		,SUM(ISNULL(Cost.TransInQty,0))		TransInQty
		,SUM(ISNULL(Cost.TransOutQty,0))	TransOutQty
		,SUM(ISNULL(Cost.TotalOutQty,0))	TotalOutQty
		,SUM(ISNULL(Cost.TotalInQty	,0))	TotalInQty
		,SUM(ISNULL(Cost.NetExchange,0))	NetExchange
		,materials.DistMethod
		,materials.HasAlterMat
	FROM JOCvwJobOrderRawMaterials materials
		INNER JOIN JocVwJobOrder JobOrder On materials.JobOrderGuid = JobOrder.JobOrderGuid
		LEFT JOIN JOCvwBillItemsQtys Cost ON materials.JobOrderGuid= Cost.JobOrderGuid AND materials.MaterialGuid = Cost.MaterialGuid AND materials.StageGuid = Cost.StageGuid
	GROUP BY
		materials.MaterialGuid	
		,materials.MaterialCode		
		,materials.MaterialName			
		,materials.MaterialLatinName	
		,materials.RawMatQty
		,materials.Unit				
		,materials.UnitName		
		,materials.UnitFactor	
		,materials.StageGuid
		,materials.StageName			
		,materials.JobOrderGuid
		,materials.BOMIndex
		,materials.ExpireFlag
		,materials.ClassFlag
		,materials.SNFlag
		,materials.BOMProductionQty
		,materials.RawMatQty
		,materials.StageIndex
		,materials.DistMethod
		,materials.HasAlterMat
		,Cost.NetQty
		,Cost.ExpensedQty
		,Cost.ReturnedQty
		,Cost.TotalInQty
		,Cost.TotalOutQty
		,Cost.NetExchange
		,JobOrder.JobOrderReplicasCount
		,JobOrder.JobOrderInstanceProductionQuantity
		,JobOrder.JobOrderBOM 
		,JobOrder.JobOrderManufactoryGuid
		,JobOrder.JobOrderProductionLine
		,JobOrder.JobOrderStartDate
		,JobOrder.JobOrderEndDate 
		,JobOrder.JobOrderStatus
		,JobOrder.JobOrderOperatingBOM
#############################################################################

CREATE VIEW JOCvwMaterialRequestion
AS
SELECT Requestion.[Guid]
		,JobOrder.* 
		,bu.*
FROM JOCVwJobOrder JobOrder
INNER JOIN DirectMatRequestion000 Requestion ON Requestion.JobOrder = JobOrder.JobOrderGuid
INNER JOIN vwBu Bu ON Requestion.Bill = Bu.buGUID
#############################################################################

CREATE VIEW JOCvwMaterialRequestionItems
AS
SELECT 
materials.MaterialGuid	
,materials.MaterialCode		
,materials.MaterialName			
,materials.MaterialLatinName
,items.biGUID AS biGuid
,ISNULL(materials.RawMatQty,0) as RawMatQty
,ISNULL(materials.RawMatQty1,0) as RawMatQty1
,ISNULL(items.biUnity, materials.Unit) AS Unit	
,ISNULL(items.biUnitName, materials.UnitName) AS UnitName
,ISNULL(items.biUnitFactor, materials.UnitFactor) AS UnitFactor
,materials.StageGuid	
,materials.StageIndex
,materials.JobOrderGuid
,materials.BOMIndex
,materials.ExpireFlag
,materials.ClassFlag
,materials.SNFlag
,materials.JobOrderRequiredQty
,materials.JobOrderRequiredQty1
,materials.NetQty
,ISNULL(items.biQty,0)	AS Qty
,ISNULL(items.biExpireDate,'1-1-1980')	AS ExpiryDate
,ISNULL(items.biClassPtr,'')	AS ClassPtr
,requestion.Guid	AS RequestionGuid
,materials.DistMethod  
,materials.HasAlterMat      
FROM JOCvwJobOrderRawMaterialsQuantities materials
INNER JOIN DirectMatRequestion000 requestion ON requestion.JobOrder = materials.JobOrderGuid
LEFT JOIN JOCvwGeneralCostItems items ON requestion.Guid = items.ParentGuid AND materials.materialGuid = items.biMatPtr AND materials.StageGuid = items.StageGuid
WHERE (requestion.StageGuid = materials.StageGuid OR requestion.StageGuid = 0x0)
#############################################################################

CREATE VIEW JOCvwMaterialReturn
AS
SELECT MatReturn.[Guid]
		,JobOrder.* 
		,bu.*
FROM JOCVwJobOrder JobOrder
INNER JOIN DirectMatReturn000 MatReturn ON MatReturn.JobOrder = JobOrder.JobOrderGuid
INNER JOIN vwBu Bu ON MatReturn.Bill = Bu.buGUID
#############################################################################

CREATE VIEW JOCvwMaterialReturnItems
AS
SELECT 
materials.MaterialGuid	
,materials.MaterialCode		
,materials.MaterialName			
,materials.MaterialLatinName	
,items.biGUID
,ISNULL(items.biUnity, materials.Unit) AS Unit			
,ISNULL(items.biUnitName, materials.UnitName) AS UnitName
,ISNULL(items.biUnitFactor, materials.UnitFactor) AS UnitFactor
,materials.StageGuid
,materials.StageIndex	
,materials.JobOrderGuid
,materials.BOMIndex
,materials.ExpireFlag
,materials.ClassFlag
,materials.SNFlag
,materials.NetQty
,ISNULL(items.biQty,0)	AS Qty
,ISNULL(items.biExpireDate,'1-1-1980')	AS ExpiryDate
,ISNULL(items.biClassPtr,'')	AS ClassPtr
,matReturn.Guid	AS ReturnGuid
,materials.DistMethod AS DistMethod
,materials.HasAlterMat
FROM JOCvwJobOrderRawMaterialsQuantities materials
INNER JOIN DirectMatReturn000 matReturn ON matReturn.JobOrder = materials.JobOrderGuid
LEFT JOIN JOCvwGeneralCostItems items ON matReturn.Guid = items.ParentGuid AND materials.materialGuid = items.biMatPtr AND materials.StageGuid = items.StageGuid
WHERE (matReturn.StageGuid = materials.StageGuid OR matReturn.StageGuid = 0x0)
#############################################################################

CREATE FUNCTION JOCfnGetJobOrderTransItems(@Src UNIQUEIDENTIFIER, @Dest UNIQUEIDENTIFIER)
RETURNS TABLE
RETURN (
			SELECT 
			src.*
			FROM JOCvwJobOrderRawMaterialsQuantities src
			INNER JOIN JOCvwJobOrderRawMaterialsQuantities dest
			ON src.MaterialGuid = dest.MaterialGuid AND src.StageGuid = dest.StageGuid
			WHERE src.JobOrderGuid = @Src
			AND dest.JobOrderGuid = @Dest
			AND src.NetQty > 0
		)
#############################################################################

CREATE VIEW JOCvwJobOrderTransItems
AS
SELECT 
DISTINCT
src.MaterialGuid
,src.MaterialName
,src.MaterialCode
,src.MaterialLatinName
,src.Unit
,src.UnitFactor
,src.UnitName
,src.NetQty
,src.BOMNetQty
,src.JobOrderGuid AS Source
,src.StageGuid
,src.SNFlag
,src.ExpireFlag
,src.ClassFlag
,src.BomIndex
,dest.JobOrderGuid AS Dest
,src.HasAlterMat
FROM JOCvwJobOrderRawMaterialsQuantities src
INNER JOIN JOCvwJobOrderRawMaterialsQuantities dest
ON src.MaterialGuid = dest.MaterialGuid --AND src.StageGuid = dest.StageGuid
WHERE src.TotalOutQty > 0
#############################################################################
CREATE VIEW Joc_Vw_JobOrderStages
AS 
SELECT ST.*,JO.Guid AS JobOrder FROM JobOrder000 AS JO
LEFT  JOIN JOCBOM000 AS JOBOM ON JOBOM.GUID=JO.FormGuid
LEFT  JOIN ProductionLine000 AS PrdLine ON  JO.ProductionLine=PrdLine.Guid 
INNER JOIN JOCBOMStages000 AS BOMS ON JOBOM.GUID=BOMS.JOCBOMGuid AND BOMS.ProductionLineGuid=PrdLine.Guid
INNER JOIN JOCStages000 AS ST ON BOMS.StageGuid=ST.GUID
#############################################################################

CREATE VIEW JOCvwJobOrderStages
AS
SELECT 
materials.JobOrderGuid 
,materials.MaterialGuid
,Stages.[Guid] AS StageGuid
,Stages.[Name] AS StageName
,Stages.LatinName AS StageLatinName
,Stages.Security AS StagesSecurity
FROM JOCvwJobOrderRawMaterials materials 
INNER JOIN JOCStages000 Stages ON materials.StageGuid = Stages.[GUID]
#############################################################################

CREATE VIEW JOCvwTransItems
AS
SELECT 
items.biMatPtr		AS MaterialGuid
,items.biUnity		AS Unit
,items.biUnitName	AS UnitName
,items.biUnitFactor AS UnitFactor
,items.biQty		AS Qty
,items.biExpireDate	AS ExpireDate
,items.biClassPtr	AS ClassPtr
,items.StageGuid	AS StageGuid
,trans.Src			AS SourceJobOrder
,items.CostType		AS CostType
,items.biGUID		AS biGuid
,trans.Dest			AS DestJobOrder
,trans.[Guid]		AS TransGuid
 FROM JOCvwGeneralCostItems items 
INNER JOIN JocTrans000 trans ON items.ParentGuid = trans.[Guid]

#############################################################################

CREATE VIEW JOCvwOutTransItems
--„‰ŸÊ— ÌÊ÷Õ ÕﬁÊ· ›Ê« Ì— «·„‰«ﬁ·«  «·Œ«—Ã… + «·„—Õ·… «·„’—Ê› „‰Â« + «·„—Õ·… «·„’—Ê› «·ÌÂ«
AS
SELECT 
items.biMatPtr		AS MaterialGuid
,(SELECT items2.StageGuid FROM JOCvwGeneralCostItems items2 WHERE items2.ParentGuid = items.ParentGuid AND  items2.biMatPtr = items.biMatPtr AND items2.CostType = 2 AND items2.biNotes = items.biNotes ) AS SrcStageGuid
,items.StageGuid	AS DestStageGuid
,mt.Name			as matName
,items.biUnity		AS Unit
,items.biUnitName	AS UnitName
,items.biUnitFactor AS UnitFactor
,items.biQty		AS Qty
,items.biExpireDate	AS ExpireDate
,items.biClassPtr	AS ClassPtr
,trans.Src			AS SourceJobOrder
,items.CostType		AS CostType
,items.biGUID		AS biGuid
,items.biNotes
,trans.Dest			AS DestJobOrder
,trans.[Guid]		AS TransGuid
 FROM JOCvwGeneralCostItems items 
INNER JOIN JocTrans000 trans ON items.ParentGuid = trans.[Guid]
INNER JOIN mt000 mt ON mt.GUID = items.biMatPtr
WHERE items.CostType = 3

#############################################################################

CREATE VIEW JocVwProducedMaterials
AS

SELECT BOM.Guid [Guid], Code ,  Name , LatinName from JOCBOM000 BOM 
#############################################################################
Create VIEW JocVwJobOrderStagesData
AS
SELECT stages.Guid StageGuid, stages.Name StageName,stages.LatinName StageLatineName,JO.Guid JobOrderGuid,joStages.Qty,joStages.SampleQty ,joStages.Unit StageQtyUnit ,PLStages.SerialOrder,PLStages.StageType
  FROM   JOCStages000 stages   INNER JOIN  JOCJobOrderStages000 joStages    on   stages.GUID = joStages.StageGuid  
                               INNER JOIN  JobOrder000  JO on JO.Guid = joStages.JobOrderGuid
							   INNER JOIN   ProductionLine000 PLine on JO.ProductionLine = PLine.Guid
							   INNER JOIN   JOCProductionLineStages000 PLStages on PLStages.ParentGUID = PLine.Guid  and  stages.GUID = PLStages.StageGuid
#############################################################################
CREATE VIEW JOCvwFinishedGoodsAndRawMaterials
AS
SELECT rawMaterials.MatPtr AS rawMaterialGuid, spoilage.FinishedProductGuid finishedGoodGuid, spoilage.SpoilageMaterial
FROM JOCBOMRawMaterials000 rawMaterials
INNER JOIN JOCBOMSpoilage000 spoilage
ON rawMaterials.JOCBOMGuid = spoilage.BOMGuid
#############################################################################

CREATE VIEW JOCvwRawMaterialsAndSpoiledMaterials
AS
SELECT rawMaterials.MatPtr AS rawMaterialGuid, spoilage.SpoilageMaterial spoilageMaterialGuid
FROM JOCBOMRawMaterials000 rawMaterials
INNER JOIN JOCBOMSpoilage000 spoilage
ON rawMaterials.JOCBOMGuid = spoilage.BOMGuid
#############################################################################
CREATE VIEW JOCJobOrdersBOMFinishedGoods
AS
SELECT 
JO.Guid AS JobOrderGuid
,BOMFG.MaterialGuid AS FinishedGoodGuid
,BOMFG.Quantity AS Quantity
FROM JOCOperatingBOMFinishedGoods000 BOMFG 
INNER JOIN JOCJobOrderOperatingBOM000 OBOM ON OBOM.Guid = BOMFG.OperatingBOMGuid
INNER JOIN JobOrder000 JO ON JO.OperatingBOMGuid =  OBOM.Guid 
#############################################################################
CREATE VIEW JOCvwJobOrderFinishedGoodsBillItemsQtys
--⁄—÷ ﬂ„Ì… «·«‰ «Ã «·„”·„… »«·ÊÕœ… «·«Ê·Ì Ê ÊÕœ… «·‰„Ê–Ã Ê ÊÕœ«  «·„’‰⁄
AS
SELECT 
JobOrder.JobOrderGuid,
JobOrder.JobOrderOperatingBOM AS OperatingBOMGuid,
finishedgoods.MaterialGuid,
(CASE Manuf.UsedProductionUnit WHEN Manuf.ProductionUnitOne THEN 1 ELSE 2 END) AS ManufUsedUnit,
SUM (Bills.biQty) AS Quantity, -- ﬂ„Ì… «·«‰ «Ã »«·ÊÕœ… «·√Ê·Ì
SUM (Bills.biQty) / (CASE finishedGoods.Unit WHEN 2 THEN MT.Unit2Fact WHEN 3 THEN MT.Unit3Fact ELSE 1 END) AS QuantityWithBomUnit, -- ﬂ„Ì… «·«‰ «Ã »ÊÕœ… «·‰„Ê–Ã

(CASE BOMUnit.Prod1ConvMatUnit 
			WHEN 1 THEN BOMUnit.Prod1ToMatUnitConvFactor 
			WHEN 2 THEN  (BOMUnit.Prod1ToMatUnitConvFactor / MT.Unit2Fact)
			ELSE (BOMUnit.Prod1ToMatUnitConvFactor / MT.Unit3Fact) END) * SUM (Bills.biQty)  
			AS FirstProductionUnityQty, -- ﬂ„Ì… «·«‰ «Ã »ÊÕœ… «·„’‰⁄ «·«Ê·Ì 
	
CASE WHEN Manuf.ProductionUnitTwo = 0x0 THEN 0 
			ELSE 
				(CASE BOMUnit.Prod2ConvMatUnit 
					WHEN 1 THEN BOMUnit.Prod2ToMatUnitConvFactor 
					WHEN 2 THEN  (BOMUnit.Prod2ToMatUnitConvFactor / MT.Unit2Fact)
					ELSE (BOMUnit.Prod2ToMatUnitConvFactor / MT.Unit3Fact) END)* SUM (Bills.biQty) 
			END 
			AS SecondProductionUnityQty -- ﬂ„Ì… «·«‰ «Ã »ÊÕœ… «·„’‰⁄ «·À«‰Ì… 

FROM 
vwBuBi Bills 
INNER JOIN JocVwJobOrder JobOrder ON Bills.buCustAcc = JobOrder.JobOrderAccount
LEFT JOIN Manufactory000 Manuf ON Manuf.Guid = JobOrder.JobOrderManufactoryGuid
LEFT JOIN JOCOperatingBOMFinishedGoods000 finishedGoods ON finishedGoods.OperatingBOMGuid = JobOrder.JobOrderOperatingBOM AND (Bills.biMatPtr = finishedGoods.MaterialGuid OR Bills.biMatPtr = finishedGoods.SpoilageMaterial)
LEFT JOIN JOCBOMUnits000 BOMUnit  ON BOMUnit.MatPtr = finishedGoods.MaterialGuid 
LEFT JOIN mt000 MT ON BOMUnit.MatPtr = MT.GUID

WHERE JobOrder.ManufactoryFinishedGoodsBillType = Bills.buType
GROUP BY 
finishedgoods.MaterialGuid
,JobOrder.JobOrderGuid
,JobOrder.JobOrderOperatingBOM
,BOMUnit.Prod1ConvMatUnit
,BOMUnit.Prod2ConvMatUnit
,BomUnit.Prod1ToMatUnitConvFactor
,BomUnit.Prod2ToMatUnitConvFactor
,MT.Unit2Fact,MT.Unit3Fact
,Manuf.UsedProductionUnit
,Manuf.ProductionUnitOne
,Manuf.ProductionUnitTwo
,finishedGoods.Guid
,finishedGoods.Unit
#############################################################################
CREATE VIEW JOCvwJobOrderProductsStandardQuantity
-- Õ”«» «·ﬂ„Ì… «·„⁄Ì«—Ì… ·ﬂ· „«œ… ›Ì Õ«·…  Ê“Ì⁄ «·ﬂ·› »ÿ—Ìﬁ… „»«‘—…
AS
SELECT 
	(CASE BOMRaw.AllocationType 
	WHEN 0 THEN 0 
	ELSE 
	(BOMRaw.Quantity * (CASE BOMRaw.Unit WHEN 2 THEN Mt.Unit2Fact WHEN 3 THEN Mt.Unit3Fact ELSE 1 END) --ﬂ„Ì… «·„«œ… «·√Ê·Ì… ›Ì «·‰„Ê–Ã
	* 
	(BOMRaw.FinishedGoodPercentage / 100)-- ‰”»…  Ê“Ì⁄ «·„«œ… «·√Ê·Ì… ⁄·Ì «·„‰ Ã «· «„
	/ 
	BOMFG.Quantity-- ﬂ„Ì… «·„‰ Ã «· «„ ›Ì «·‰„Ê–Ã
	* 
	VwFGBillItems.QuantityWithBomUnit-- ﬂ„Ì… «·«‰ «Ã «·›⁄·Ì »ÊÕœ… «·‰„Ê–Ã
	)END)
	AS StandardQuantity,

MT.Name AS RawMaterialName,
MT.GUID AS RawMaterialGuid,
RawQty.NetQty AS NetQty,
RawQty.NetExchange AS NetExchange,
VwFGBillItems.*,
BOMRaw.AllocationType AS DistMethod,
BOMRaw.StageGuid


FROM 
JOCOperatingBOMRawMaterials000 BOMRaw 
INNER JOIN JOCOperatingBOMFinishedGoods000 BOMFG ON BOMRaw.FinishedProductGuid = BOMFG.MaterialGuid AND BOMRaw.OperatingBOMGuid = BOMFG.OperatingBOMGuid
INNER JOIN mt000 Mt ON Mt.GUID = BOMRaw.RawMaterialGuid
INNER JOIN mt000 MtFG ON MtFG.GUID = BOMRaw.FinishedProductGuid
INNER JOIN JOCJobOrderOperatingBOM000  JOBOM ON JOBOM.Guid = BOMRaw.OperatingBOMGuid
INNER JOIN JOCBOM000 BOM ON BOM.GUID = JOBOM.BOMGuid
INNER JOIN JOCBOMUnits000 BOMUnit  ON BOMUnit.BOMGUID = BOM.GUID AND BOMUnit.MatPtr = BOMRaw.FinishedProductGuid
INNER JOIN JobOrder000 JO ON JO.OperatingBOMGuid = BOMRaw.OperatingBOMGuid
INNER JOIN Manufactory000 Manufactory ON Manufactory.Guid = JO.ManufactoryGUID
INNER JOIN JOCvwJobOrderRawMaterialsQuantities RawQty ON RawQty.JobOrderGuid = JO.Guid AND RawQty.MaterialGuid = BOMRaw.RawMaterialGuid  AND RawQty.StageGuid = BOMRaw.StageGuid
INNER JOIN JOCvwJobOrderFinishedGoodsBillItemsQtys VwFGBillItems ON VwFGBillItems.MaterialGuid = BOMFG.MaterialGuid AND VwFGBillItems.JobOrderGuid = JO.Guid
#############################################################################
CREATE VIEW JOCvwJobOrderTotalProductsStandardQuantity
-- Õ”«» „Ã„Ê⁄ «·ﬂ„Ì… «·„⁄Ì«—Ì… ·ﬂ· „«œ… «Ê·Ì… ›Ì Õ«·…  Ê“Ì⁄ «·ﬂ·› »ÿ—Ìﬁ… „»«‘—…
AS
SELECT 
SUM(StandardQuantity) AS TotalStandardQuantity,
RawMaterialGuid,
JobOrderGuid,
StageGuid

FROM JOCvwJobOrderProductsStandardQuantity StandardQty
 
GROUP BY 
StandardQty.RawMaterialGuid,
StandardQty.JobOrderGuid,
StageGuid
#############################################################################
CREATE VIEW JOCvwJobOrderFinishedGoodsItemsSellPrice
AS
--Õ”«» «·ﬁÌ„… «·»Ì⁄Ì… ··„‰ Ã«  «· «„… ›Ì «Ê«„— «· ‘€Ì·
SELECT 
 (CASE WHEN Manuf.UsedProductionUnit = Manuf.ProductionUnitOne THEN 1 ELSE 2 END) usedUnit,
BOMUnit.Prod1ToMatUnitConvFactor, 
BOMUnit.Prod2ToMatUnitConvFactor, 
BillItems.QuantityWithBomUnit * BOMFG.Price AS FinishedGoodsSellPrice,
BillItems.JobOrderGuid,
BOMFG.MaterialGuid AS FinishedGoodsGuid,
BOMFG.OperatingBOMGuid 

FROM 

JOCvwJobOrderFinishedGoodsBillItemsQtys BillItems
INNER JOIN JobOrder000 JO ON BillItems.JobOrderGuid = JO.Guid
INNER JOIN JOCJobOrderOperatingBOM000 JOCBOM ON JOCBOM.GUID = JO.OperatingBOMGuid
INNER JOIN JOCBOM000 BOM ON BOM.GUID = JOCBOM.BOMGuid
INNER JOIN JOCBOMUnits000 BOMUnit  ON BOMUnit.BOMGUID = BOM.GUID AND BOMUnit.MatPtr = BillItems.MaterialGuid
INNER JOIN mt000 MT ON BOMUnit.MatPtr = MT.GUID
LEFT JOIN Manufactory000 Manuf ON Manuf.Guid = JO.ManufactoryGUID
LEFT JOIN JOCOperatingBOMFinishedGoods000 BOMFG ON BOMFG.MaterialGuid = BillItems.MaterialGuid AND BOMFG.OperatingBOMGuid = jo.OperatingBOMGuid
LEFT JOIN JOCJobOrderOperatingBOM000 JOBom ON JOBom.Guid = BOMFG.OperatingBOMGuid
#############################################################################

CREATE VIEW JOCvwJobOrderDirectLaborsDetails
AS
SELECT Details.*, JobOrder.Guid AS JobOrderGuid FROM DirectLaborAllocationDetail000 Details 
JOIN DirectLaborAllocation000 Allocation on Details.JobOrderDistributedCost = Allocation.Guid
INNER JOIN JobOrder000 JobOrder ON Allocation.JobOrder = JobOrder.Guid
#############################################################################
CREATE VIEW JOCvwDiectLaborsCostDistribution
	AS  
		SELECT DLA.JobOrder
			   ,DLD.Employee AS WorkerGuid
			   ,Worker.Name	AS WorkerName
			   ,CASE BOMI.UseStages WHEN 1 THEN  DIS.Hours ELSE SUM(dld.WorkingHours) END TotalWorkingHours
			   ,CASE BOMI.UseStages WHEN 1 THEN  DIS.Hours * DLD.WorkingHourCost  ELSE SUM(DLD.WorkingHours * DLD.WorkingHourCost) END TotalWorkingHoursCost
			   ,DLD.WorkingHourCost WorkingHourCost
			   ,ISNULL(DIS.StageGuid, 0x0) As StageGUID
		FROM [DirectLaborAllocation000] DLA
		INNER JOIN [DirectLaborAllocationDetail000] DLD ON DLA.Guid = DLD.JobOrderDistributedCost
		LEFT JOIN [JOCWorkers000] Worker ON Worker.Guid = DLD.Employee
		LEFT JOIN [VwJOCWorkHoursDistribution] DIS ON DIS.ParentGuid=DLD.Guid
		LEFT JOIN [JobOrder000] AS JO ON JO.Guid=DLA.JobOrder
		LEFT JOIN [JOCJobOrderOperatingBOM000] AS BOMI ON BOMI.Guid=JO.OperatingBOMGuid
		GROUP BY DLA.JobOrder
				,DLD.Employee
				,Worker.Name
				,DLD.WorkingHourCost
				,DIS.StageGuid 
				,BOMI.UseStages
				,DIS.[Hours]

#############################################################################
CREATE VIEW JOCvwTerminatedJobOrderDirectMaterials
-- «» «·„Ê«œ «·√Ê·Ì… ·√Ê«„— «· ‘€Ì· «·„‰ ÂÌ…
AS
SELECT joborderMaterials.*,
 mt.mtName AS RawMaterialName
,mt.mtCode AS RawMaterialCode
,mt.mtLatinName AS RawMaterialLatinName
, CASE joborderMaterials.Unit  WHEN 1 THEN mt.mtUnity WHEN 2 then mt.mtUnit2 ELSE mt.mtUnit3 END AS RawMaterialUnitName
,CASE ISNULL(alternatives.MatGUID, 0x0) WHEN 0x0 THEN 0 ELSE 1 END AS HasAlternatives
FROM JOCJobOrderDirectMaterials000 joborderMaterials 
INNER JOIN vwMt mt on mt.[mtGUID] = joborderMaterials.RawMaterialGuid
LEFT JOIN AlternativeMatsItems000 alternatives ON mt.mtGUID = alternatives.MatGUID

#############################################################################
CREATE VIEW JOCvwJobOrderDeliveredSpoiledMaterials
--√ﬁ·«„ ›Ê« Ì— „Ê«œ «· ·› ·√Ê«„— «· ‘€Ì·
AS
SELECT 
mt.mtGUID AS MaterialGuid
,finishedgoods.MaterialIndex As MaterialIndex
,joborder.JobOrderGuid AS JobOrderGuid
,billItems.biQty Qty
,finishedgoods.Unit
 ,finishedgoods.MaterialGuid AS FinishedProductGuid
,billitems.biQty / (CASE finishedgoods.unit WHEN 2 THEN mt.mtUnit2Fact WHEN 3 then mt.mtUnit3Fact ELSE 1 END) AS QtyByBomUnit
FROM JocVwJobOrder joborder
JOIN vwBuBi billItems ON billItems.buCustAcc = joborder.JobOrderAccount AND joborder.ManufactoryFinishedGoodsBillType = billItems.buType
JOIN JOCOperatingBOMFinishedGoods000 finishedgoods ON joborder.JobOrderOperatingBOM = finishedgoods.OperatingBOMGuid AND billItems.biMatPtr = finishedgoods.SpoilageMaterial
JOIN vwMt mt ON mt.mtGUID = billItems.biMatPtr 
#############################################################################
CREATE VIEW JOCvwJobOrderDeliveredFlawlessMaterials
--√ﬁ·«„ ›Ê« Ì— «·„Ê«œ «·„‰ Ã…«·”·Ì„… «·„”·„… ·√Ê«„— «· ‘€Ì·
AS
SELECT 
mt.mtGUID AS MaterialGuid
,finishedgoods.MaterialIndex As MaterialIndex
,joborder.JobOrderGuid AS JobOrderGuid
,billItems.biQty Qty
,finishedgoods.Unit BOMUnit
,billItems.biQty / (CASE finishedgoods.Unit WHEN 2 THEN mt.mtUnit2Fact WHEN 3 THEN mt.mtUnit3Fact ELSE 1 END) AS QtyByBomUnit
FROM JocVwJobOrder joborder
JOIN vwBuBi billItems ON billItems.buCustAcc = joborder.JobOrderAccount AND joborder.ManufactoryFinishedGoodsBillType = billItems.buType
JOIN JOCOperatingBOMFinishedGoods000 finishedgoods ON joborder.JobOrderOperatingBOM = finishedgoods.OperatingBOMGuid AND billItems.biMatPtr = finishedgoods.MaterialGuid
JOIN vwMt mt ON mt.mtGUID = billItems.biMatPtr 
#############################################################################
CREATE VIEW JOCvwJobOrderTotalDeliveredSpoiledMaterials
--„Ã„Ê⁄ √ﬁ·«„ ›Ê« Ì— «· ·› ·√Ê«„— «· ‘€Ì·
AS

SELECT
 deliveredBills.MaterialGuid,
 deliveredBills.FinishedProductGuid AS FinishedProductGuid
 ,deliveredBills.JobOrderGuid
, CASE WHEN Joborder.ManufactoryProductionUnitOne = JobOrder.ManufactoryUsedProductionUnit THEN 1 ELSE 2 END AS ManfacturingUsedUnit,
 SUM (deliveredBills.Qty) AS Quantity,

	(CASE BOMUnit.Prod1ConvMatUnit WHEN 1 THEN BOMUnit.Prod1ToMatUnitConvFactor 
			WHEN 2 THEN  (BOMUnit.Prod1ToMatUnitConvFactor / MT.Unit2Fact)
			ELSE (BOMUnit.Prod1ToMatUnitConvFactor / MT.Unit3Fact) END) * SUM (deliveredBills.Qty) AS 
			FirstProductionUnityQty
			,
			CASE WHEN JobOrder.ManufactoryPRoductionUnitTwo = 0x0 THEN 0 ELSE 
				(CASE BOMUnit.Prod2ConvMatUnit WHEN 1 THEN BOMUnit.Prod2ToMatUnitConvFactor 
					WHEN 2 THEN  (BOMUnit.Prod2ToMatUnitConvFactor / MT.Unit2Fact)
					ELSE (BOMUnit.Prod2ToMatUnitConvFactor / MT.Unit3Fact) END)* SUM (deliveredBills.Qty) 
			END 
					AS SecondProductionUnityQty
FROM JOCvwJobOrderDeliveredSpoiledMaterials deliveredBills
INNER JOIN JOCBOMUnits000 BOMUnit on BOMUnit.MatPtr = deliveredBills.FinishedProductGuid
INNER JOIN mt000 mt ON mt.GUID = deliveredBills.MaterialGuid
INNER JOIN JocVwJobOrder JobOrder ON JobOrder.JobOrderGuid = deliveredBills.JobOrderGuid
GROUP BY 
deliveredBills.MaterialGuid
,deliveredBills.FinishedProductGuid
,BOMUnit.Prod1ConvMatUnit
,BOMUnit.Prod2ConvMatUnit
,BOMUnit.Prod2ToMatUnitConvFactor
,BOMUnit.Prod1ToMatUnitConvFactor
,mt.Unit2Fact
,mt.Unit3Fact
,JobOrder.ManufactoryPRoductionUnitTwo
,JobOrder.ManufactoryProductionUnitOne
,JobOrder.ManufactoryUsedProductionUnit
,deliveredBills.JobOrderGuid
#############################################################################
CREATE VIEW JOCvwOperatingBOMRawMaterials
AS
SELECT rawmaterials.*, joborder.JobOrderGuid, joborder.JobOrderBOM AS BOMGuid FROM JOCOperatingBOMRawMaterials000 rawmaterials
INNER JOIN JocVwJobOrder joborder ON rawmaterials.OperatingBOMGuid = joborder.JobOrderOperatingBOM
#############################################################################
CREATE VIEW JOCvwOperatingBOMRawMaterialsAndFinishedGoods
AS
SELECT rawMaterials.RawMaterialGuid AS RawMaterialGuid, 
finishedgoods.MaterialGuid AS FinishedProductGuid,
finishedgoods.SpoilageMaterial AS SpoilageMaterial
FROM JOCOperatingBOMRawMaterials000 rawMaterials
INNER JOIN JOCOperatingBOMFinishedGoods000 finishedgoods ON rawMaterials.OperatingBOMGuid = finishedgoods.OperatingBOMGuid
#############################################################################
CREATE VIEW JOCvwMaintenanceGeneralCosts
--ﬂ·›  «» ⁄«„ ›Ì √„— «· ‘€Ì· (Œ«’ »«·’Ì«‰… ›ﬁÿ)”
AS
SELECT
		FinishedGoods.MaterialGuid AS MaterialGuid,
		0 AS RequiredQty,
		FinishedGoods.Unit AS Unit,
		(CASE	WHEN FinishedGoods.Unit = 2 THEN Unit2 
				WHEN FinishedGoods.Unit = 3 THEN mt.Unit3 ELSE Unity END )AS UnitName,
		0	AS TotalDirectMaterials,
		0	AS TotalDirectLabors,
		0	AS TotalMOH,
		0	AS TotalProductionCost,
		ISNULL(SUM(FinishedGoodsQtys.Quantity) / CASE WHEN FinishedGoods.Unit = 2 THEN mt.Unit2Fact WHEN FinishedGoods.Unit = 3 THEN mt.Unit3Fact ELSE 1 END, 0) AS ActualProduction,
		0 AS UnitCost, 
		0 AS ProductionQuantity , -- Labors Hours, Production Qty or machine hours. 
		FinishedGoods.Price AS SellPrice, 
		0  AS SellValue,
		FinishedGoods.MaterialIndex,
		JobOrder.Guid as joborderguid,
		0 AS TotalDirectExpenses
	FROM JOCOperatingBOMFinishedGoods000 FinishedGoods 
	INNER JOIN mt000 mt ON FinishedGoods.[MaterialGuid] = mt.[GUID] --OR FinishedGoods.SpoilageMaterial = mt.[GUID]
	INNER JOIN JobOrder000 JobOrder ON (FinishedGoods.[OperatingBOMGuid] = JobOrder.[OperatingBOMGuid])	
	LEFT JOIN JOCvwJobOrderFinishedGoodsBillItemsQtys FinishedGoodsQtys ON FinishedGoodsQtys.MaterialGuid = FinishedGoods.[MaterialGuid] AND JobOrder.[Guid] = FinishedGoodsQtys.[JobOrderGuid] 
	GROUP BY 
		FinishedGoods.MaterialGuid
		,FinishedGoods.Unit
		,mt.Unit2
		,mt.Unit3
		,mt.Unity
		,mt.Unit2Fact
		,mt.Unit3Fact
		,FinishedGoods.Price
		,JobOrder.PlannedProductionQty
		,FinishedGoods.Quantity
		,FinishedGoods.MaterialIndex
		,JobOrder.Guid
#############################################################################
CREATE VIEW JOCvwOperatingBOMFinishedGoods
AS
SELECT 
fg.*,
opbom.BOMGuid AS BOMGuid
FROM JOCOperatingBOMFinishedGoods000 fg
JOIN JOCJobOrderOperatingBOM000 opbom ON fg.OperatingBOMGuid = opbom.Guid
#############################################################################

#END
