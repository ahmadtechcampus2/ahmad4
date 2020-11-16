#############################################################################
CREATE FUNCTION JOCfnGetRawMaterialDirectRequiredQty
(
	@JobOrderGuid UNIQUEIDENTIFIER,
	@RawMaterialGuid UNIQUEIDENTIFIER,
	@StageGuid UNIQUEIDENTIFIER
)
--Õ”«» «·ﬂ„Ì… «·„ÿ·Ê»… „‰ «·„«œ… «·«Ê·Ì… ·ﬂ· „«œ…  «„… »«·ÿ—Ìﬁ… «·„»«‘—… 
RETURNS TABLE
AS	
		RETURN
		(
			SELECT 
				(
					CASE RawMaterial.AllocationType 
						 WHEN 1 THEN
									 (RawMaterial.Quantity * (CASE RawMaterial.Unit WHEN 2 THEN Mt.Unit2Fact WHEN 3 THEN Mt.Unit3Fact ELSE 1 END))
										*
								     (RawMaterial.FinishedGoodPercentage / 100)
										/
									 (FIN.Quantity * (CASE FIN.Unit WHEN 2 THEN MTFin.Unit2Fact WHEN 3 THEN MTFin.Unit3Fact ELSE 1 END))
										*
									 (COST.RequiredQty * (CASE FIN.Unit WHEN 2 THEN MTFin.Unit2Fact WHEN 3 THEN MTFin.Unit3Fact ELSE 1 END))
						 ELSE 0
					END
				) RawMatRequeredQty
			FROM JOCOperatingBOMRawMaterials000 RawMaterial
				 INNER JOIN mt000 Mt ON Mt.GUID = RawMaterial.RawMaterialGuid	
				 INNER JOIN JOCBOMFinishedGoods000 Fin ON RawMaterial.FinishedProductGuid = fin.MatPtr
				 INNER JOIN mt000 MTFin ON MTFin.GUID = fin.MatPtr
				 INNER JOIN JOCJobOrderCosts000 COST ON COST.FinishedMaterialGuid = Fin.MatPtr
			WHERE 
				 RawMaterialGuid = @RawMaterialGuid 
				  AND 
				 COST.JobOrderGuid = @JobOrderGuid
				  AND
				 StageGuid = @StageGuid
		)
######################################################################
CREATE FUNCTION JOCfnGetRawMaterialTotalDirectRequiredQty
(
		@JobOrderGuid UNIQUEIDENTIFIER,
		@RawMaterialGuid UNIQUEIDENTIFIER,
		@StageGuid UNIQUEIDENTIFIER
)
--„Ã„Ê⁄ «·ﬂ„Ì… «·„ÿ·Ê»… „‰ «·„«œ… «·«Ê·ÌÂ ·ﬂ· «·„Ê«œ «· «„… ›Ì ‰„Ê–Ã «· ‘€Ì·
RETURNS FLOAT
AS
	BEGIN
		RETURN
	(
		SELECT SUM(RawMatRequeredQty)
		FROM JOCfnGetRawMaterialDirectRequiredQty(@JobOrderGuid, @RawMaterialGuid, @StageGuid)
	)
	END
######################################################################
CREATE FUNCTION JOCfnGetFinishedMatRequiredQty
(
	@MatGuid UNIQUEIDENTIFIER,
	@JobOrderGuid UNIQUEIDENTIFIER
)
RETURNS FLOAT 
AS
	BEGIN		
		RETURN
		(		
			SELECT 
				 RequiredQty * (CASE FIN.Unit WHEN 2 THEN MT.Unit2Fact WHEN 3 THEN MT.Unit3Fact ELSE 1 END)
			FROM JOCJobOrderCosts000 COST
				 INNER JOIN mt000 MT ON MT.[GUID] = COST.FinishedMaterialGuid
				 INNER JOIN JOCBOMFinishedGoods000 FIN ON FIN.MatPtr = COST.FinishedMaterialGuid
			WHERE 
				 JobOrderGuid = @JobOrderGuid AND FinishedMaterialGuid = @MatGuid			
		)
	END 
#############################################################################
CREATE VIEW JocVwJobOrder
AS
	SELECT 
		JobOrder.Guid							AS JobOrderGuid
		,JobOrder.Number						AS JobOrderNumber
		,JobOrder.Name							AS JobOrderName
		,JobOrder.FormGuid						AS JobOrderBOM
		,OperatingBOM.[GUID]					AS JobOrderOperatingBOM
		,JobOrder.ProductionLine				AS JobOrderProductionLine
		,JobOrder.Account						AS JobOrderAccount
		,JobOrder.Store							AS JobOrderStore
		,JobOrder.PlannedProductionQty			AS JobOrderReplicasCount
		,JobOrder.StartDate						AS JobOrderStartDate
		,JobOrder.EndDate						AS JobOrderEndDate
		,JobOrder.OperatingMachinesHours		AS JobOrderOperatingMachineHours
		,JobOrder.IsActive						AS JobOrderStatus
		,JobOrder.Security						AS JobOrderSecurity
		,JobOrder.GlobalCostsEntry				AS JobOrderGlobalCostEntry
		,JobOrder.Branch						AS JobOrderBranch
		,JobOrder.CostCenter					AS JobOrderCostCenter
		,JobOrder.DerivationEntryGuid			AS JobOrderDerivationEntryGuid
		,JobOrder.ManufactoryGUID				AS JobOrderManufactoryGuid
		,JobOrder.UseHrConnection				AS JobOrderUseHrConnection
		,JobOrder.SNDesignGuid					AS JobOrderSNDesignGuid
		,JobOrder.PlannedProductionQty			AS JobOrderInstanceProductionQuantity
		,OperatingBOM.UseStages					AS UseStages
		,OperatingBOM.UseSpoilage				AS UseSpoilage
		,OperatingBOM.CostRank					AS OperatingBOMCostRank
		,Manufactory.Number						AS ManufactoryNumber
		,Manufactory.Code						AS ManufactoryCode
		,Manufactory.Name						AS ManufactoryName
		,Manufactory.LatineName					AS ManufactoryLatinName
		,Manufactory.DirectLaborsAcc			AS ManufactoryDirectLaborsAcc
		,Manufactory.MOHAcc						AS ManufactoryMOHAcc
		,Manufactory.InProcessAcc				AS ManufactoryInProcessAcc
		,Manufactory.FinishedGoodsBillType		AS ManufactoryFinishedGoodsBillType
		,Manufactory.MatRequestBillType			AS ManufactoryMatRequestBillType
		,Manufactory.MatReturnBillType			AS ManufactoryMatReturnBillType
		,Manufactory.InTransBillType			AS ManufactoryInTransBillType
		,Manufactory.OutTransBillType			AS ManufactoryOutTransBillType
		,Manufactory.MohAllocationBase			AS ManufactoryMOHAllocationBase
		,Manufactory.EstimatedCostCalcBase		AS ManufactoryEstimatedCostCalcBase
		,Manufactory.ShowClass					AS ManufactoryShowclass
		,Manufactory.ShowExpiryDate				AS ManufactoryShowExpiryDate
		,Manufactory.IsMOHManualSave			AS ManufactoryRegisterMOHManually
		,Manufactory.HR_Connection_Activate		AS ManufactoryIsConnectionActive
		,Manufactory.HR_DepatmentGuid			AS ManufactoryHrDepartment
		,Manufactory.InStoreGuid				AS ManufactoryInStoreGuid
		,Manufactory.OutStoreGuid				AS ManufactoryRequestionStoreGuid
		,Manufactory.TransStoreGuid				AS ManufactoryTransStoreGuid
		,Manufactory.ProductionUnitOne			AS ManufactoryProductionUnitOne
		,Manufactory.ProductionUnitTwo			AS ManufactoryPRoductionUnitTwo
		,Manufactory.UsedProductionUnit			AS ManufactoryUsedProductionUnit
		,Manufactory.Security					AS ManufactorySecurity
		,Manufactory.JointCostMethod			AS ManufactoryJoinCostMethod
		,ProductionLine.Number					AS ProductionLineNumber
		,ProductionLine.Code					AS ProductionLineCode
		,ProductionLine.Name					AS ProductionLineName
		,ProductionLine.LatinName				AS ProductionLineLatinName
		,ProductionLine.Security				AS ProductionLineSecurity
		,ProductionLine.InProcessAccGuid		AS ProductionLineInProcessAcc
		,ProductionLine.ActualCost				AS ProductionLineActualCost
		,ProductionLine.ExpensesAccount			AS ProductionLineExpensesAccount
		,ProductionLine.EstimatedCost			AS ProductionLineEstimatedCost
		,ProductionLine.CalculationMethod		AS ProductionLineCalculationMethod
		,ProductionLine.IndustrialAccount		AS ProductionLineIndustrialAcc
		,ProductionLine.DeviationAccount		AS ProductionLineDeviationAccount
		,ProductionLine.ProductionCapacity		AS ProductionLineProductionCapacity	
		,ProductionLine.SNDesignGuid			AS ProductionLineSNDesignGuid	
		,Bom.Name								AS BOMName
		,Bom.LatinName							AS BOMLatinName				
	FROM JobOrder000 JobOrder	
		 INNER JOIN Manufactory000 Manufactory ON JobOrder.ManufactoryGUID = Manufactory.[Guid]
		 INNER JOIN ProductionLine000 ProductionLine ON JobOrder.ProductionLine = ProductionLine.[Guid]
		 INNER JOIN JOCJobOrderOperatingBOM000 OperatingBOM ON OperatingBOM.Guid = JobOrder.OperatingBOMGuid
		 INNER JOIN JOCBOM000 Bom ON JobOrder.FormGuid = Bom.[GUID]
#############################################################################
CREATE VIEW JocVwJobOrderFinishedGoodsOperatingBOMQtys
AS
(
	SELECT  JobOrder.JobOrderGuid, 
			JobOrder.JobOrderOperatingBOM AS OperatingBOMGuid, 
			FinishedGoods.[MaterialGuid] AS MaterialGuid, 
			(CASE Manuf.UsedProductionUnit WHEN Manuf.ProductionUnitOne THEN 1 ELSE 2 END) AS ManufUsedUnit, 
			
			ISNULL((CASE FinishedGoods.Unit WHEN 2 THEN 
					MT.Unit2Fact WHEN 3 THEN MT.Unit3Fact ELSE 1 END), 1) * FinishedGoods.[Quantity] AS Quantity,

			FinishedGoods.[Quantity]AS QuantityWithBomUnit,
			
			(CASE BOMUnit.Prod1ConvMatUnit WHEN 1 
				THEN BOMUnit.Prod1ToMatUnitConvFactor WHEN 2 
				THEN (BOMUnit.Prod1ToMatUnitConvFactor / MT.Unit2Fact) 
				ELSE (BOMUnit.Prod1ToMatUnitConvFactor / MT.Unit3Fact) 
			END)
			* ISNULL((CASE FinishedGoods.Unit WHEN 2 THEN 
					MT.Unit2Fact WHEN 3 THEN MT.Unit3Fact ELSE 1 END), 1)
			* (FinishedGoods.[Quantity]) AS FirstProductionUnityQty, 
        				 
			CASE WHEN Manuf.ProductionUnitTwo = 0x0 
			THEN 0 
			ELSE (	CASE BOMUnit.Prod2ConvMatUnit WHEN 1 
						THEN BOMUnit.Prod2ToMatUnitConvFactor WHEN 2 
						THEN (BOMUnit.Prod2ToMatUnitConvFactor / MT.Unit2Fact)
						ELSE (BOMUnit.Prod2ToMatUnitConvFactor / MT.Unit3Fact) 
					END) 
			*  ISNULL((CASE FinishedGoods.Unit WHEN 2 THEN 
					MT.Unit2Fact WHEN 3 THEN MT.Unit3Fact ELSE 1 END), 1)
			* (FinishedGoods.[Quantity]) END AS SecondProductionUnityQty

	FROM JOCOperatingBOMFinishedGoods000 AS FinishedGoods 
		 INNER JOIN dbo.JocVwJobOrder AS JobOrder ON JobOrder.[JobOrderOperatingBOM] = FinishedGoods.[OperatingBOMGuid] 
		 INNER JOIN dbo.JOCBOMUnits000 AS BOMUnit ON BOMUnit.MatPtr = FinishedGoods.[MaterialGuid] 
		 INNER JOIN dbo.mt000 AS MT ON BOMUnit.MatPtr = MT.GUID 
		 LEFT OUTER JOIN dbo.Manufactory000 AS Manuf ON Manuf.Guid = JobOrder.JobOrderManufactoryGuid
)
######################################################################
CREATE VIEW JOCvwJobOrderOperatingBOMFinishedGoodsSellPrice
AS
(
	SELECT	
		QuantityWithBomUnit * BOMFG.Price AS FinishedGoodsSellPrice, 
		FinishedGoods.[JobOrderGuid], 
		BOMFG.MaterialGuid AS FinishedGoodsGuid, 
		BOMFG.OperatingBOMGuid					 
	FROM dbo.JocVwJobOrderFinishedGoodsOperatingBOMQtys AS FinishedGoods 
		 INNER JOIN  dbo.JobOrder000 AS JO ON FinishedGoods.[JobOrderGuid] = JO.Guid 
		 INNER JOIN dbo.JOCJobOrderOperatingBOM000 AS JOCBOM ON JOCBOM.[Guid] = JO.[OperatingBOMGuid] 
		 INNER JOIN dbo.JOCBOMUnits000 AS BOMUnit ON BOMUnit.[BOMGUID] = JOCBOM.[BOMGuid] AND BOMUnit.[MatPtr] = FinishedGoods.[MaterialGuid] 
		 INNER JOIN dbo.mt000 AS MT ON BOMUnit.[MatPtr] = MT.[GUID] 
		 LEFT OUTER JOIN dbo.Manufactory000 AS Manuf ON Manuf.[Guid] = JO.[ManufactoryGUID] 
		 LEFT OUTER JOIN dbo.JOCOperatingBOMFinishedGoods000 AS BOMFG 
			ON BOMFG.[MaterialGuid] = FinishedGoods.[MaterialGuid] AND BOMFG.[OperatingBOMGuid] = JO.[OperatingBOMGuid] 
)
######################################################################
CREATE FUNCTION JOCfnGetBOMFiniShedMatsTotalQty
(
	@JobOrderGuid UNIQUEIDENTIFIER,
	@OperatingBomGuid UNIQUEIDENTIFIER
)
RETURNS FLOAT
AS 
	BEGIN
		RETURN
		(
			SELECT
				  CASE SUM(FinishedProdBomQtys.Quantity)
					   WHEN 0 THEN 1 
					   ELSE SUM(FinishedProdBomQtys.Quantity)
				  END
			FROM JocVwJobOrderFinishedGoodsOperatingBOMQtys AS FinishedProdBomQtys
			WHERE 
				 FinishedProdBomQtys.[JobOrderGuid] = @JobOrderGuid 
				  AND 
				 FinishedProdBomQtys.[OperatingBomGuid] = @OperatingBomGuid
		)
	END
######################################################################
CREATE FUNCTION JOCfnGetTotalBOMSellPrice
(
	@BOMGuid UNIQUEIDENTIFIER,
	@JobOrderGuid UNIQUEIDENTIFIER
)
RETURNS FLOAT
AS
	BEGIN
		RETURN
		(
			SELECT 
				  CASE SUM(FinPrice.[FinishedGoodsSellPrice]) 
					   WHEN 0 THEN 1 
					   ELSE SUM(FinPrice.[FinishedGoodsSellPrice]) 
				  END
			FROM JOCvwJobOrderOperatingBOMFinishedGoodsSellPrice FinPrice
			WHERE
				FinPrice.[JobOrderGuid] = @JobOrderGuid AND FinPrice.[OperatingBOMGuid] = @BOMGuid
		)
	END
######################################################################
CREATE FUNCTION JOCfnGetFinishedProdBOMQty
(
	@MatGuid UNIQUEIDENTIFIER
)
RETURNS FLOAT
AS
	BEGIN
		RETURN
		(
			SELECT 
				 CASE Fin.Quantity * (CASE Fin.Unit WHEN 2 THEN MT.Unit2Fact WHEN 3 THEN MT.Unit3Fact ELSE 1 END)
					  WHEN 0 THEN 1
					  ELSE Fin.Quantity * (CASE Fin.Unit WHEN 2 THEN MT.Unit2Fact WHEN 3 THEN MT.Unit3Fact ELSE 1 END)
				 END
			FROM JOCBOMFinishedGoods000 Fin
			INNER JOIN mt000 MT ON MT.GUID = Fin.MatPtr
			WHERE Fin.MatPtr = @MatGuid
		)
	END
######################################################################
CREATE FUNCTION JOCfnGetRawMaterialInDirectRequiredQty
(
	@JobOrderGuid UNIQUEIDENTIFIER,
	@RawMaterialGuid UNIQUEIDENTIFIER,
	@StageGuid UNIQUEIDENTIFIER
)
RETURNS TABLE
AS	
		RETURN
		(
			SELECT
					(CASE MAN.JointCostMethod 
						  WHEN 0 THEN 
									((RAWM.Quantity * (CASE RAWM.Unit WHEN 2 THEN Mt.Unit2Fact WHEN 3 THEN Mt.Unit3Fact ELSE 1 END))
						 				 / 
						 			 ISNULL((SELECT dbo.JOCfnGetBOMFiniShedMatsTotalQty(JO.[Guid], JO.OperatingBOMGuid)), 1)
						 				 *
						 			 (SELECT dbo.JOCfnGetFinishedMatRequiredQty(cost.FinishedMaterialGuid, JO.[Guid]))
						 			 )				 
						  ELSE  
						 		   ((RAWM.Quantity * (CASE RAWM.Unit WHEN 2 THEN Mt.Unit2Fact WHEN 3 THEN Mt.Unit3Fact ELSE 1 END))
						 		   		*
						 		   	 FinPrice.[FinishedGoodsSellPrice]
						 		   		/
						 		   	ISNULL((SELECT dbo.JOCfnGetTotalBOMSellPrice(JO.OperatingBOMGuid, jo.[Guid])), 1)
						 		   		/
						 		   	ISNULL((SELECT dbo.JOCfnGetFinishedProdBOMQty(COST.FinishedMaterialGuid)), 1)
						 		   		*
						 		   	(SELECT dbo.JOCfnGetFinishedMatRequiredQty(COST.FinishedMaterialGuid, JO.[Guid]))
						 		   )													
					END)  RawMatRequeredQty
			FROM JOCOperatingBOMRawMaterials000 RAWM 
				 INNER JOIN JobOrder000 JO ON JO.OperatingBOMGuid = RAWM.OperatingBOMGuid
				 INNER JOIN Manufactory000 MAN ON MAN.[Guid] = JO.ManufactoryGUID
				 INNER JOIN JOCOperatingBOMFinishedGoods000 BOMFG ON RAWM.FinishedProductGuid = BOMFG.MaterialGuid AND RAWM.OperatingBOMGuid = BOMFG.OperatingBOMGuid
				 INNER JOIN mt000 Mt ON Mt.[GUID] = RAWM.RawMaterialGuid	
				 INNER JOIN mt000 MtFG ON MtFG.[GUID] = RAWM.FinishedProductGuid	
				 INNER JOIN JOCJobOrderCosts000 COST ON COST.JobOrderGuid = JO.[Guid]	 
				 INNER JOIN JOCvwJobOrderOperatingBOMFinishedGoodsSellPrice FinPrice ON FinPrice.FinishedGoodsGuid = COST.FinishedMaterialGuid
			WHERE 
				 RawMaterialGuid = @RawMaterialGuid 
				  AND 
				 JO.[Guid] = @JobOrderGuid	
				  AND 
				 StageGuid = @StageGuid		
			GROUP BY 
					(CASE RAWM.Unit WHEN 2 THEN Mt.Unit2Fact WHEN 3 THEN Mt.Unit3Fact ELSE 1 END),
					RAWM.Quantity,
					MAN.JointCostMethod,
					COST.FinishedMaterialGuid,
					JO.[Guid],
					FinPrice.FinishedGoodsSellPrice,
					JO.OperatingBOMGuid
		)
######################################################################
CREATE FUNCTION JOCfnGetRawMaterialTotalInDirectRequiredQty
(
	@JobOrderGuid UNIQUEIDENTIFIER,
	@RawMaterialGuid UNIQUEIDENTIFIER,
	@StageGuid UNIQUEIDENTIFIER
)
RETURNS FLOAT
AS 
	BEGIN
		RETURN
		(
			SELECT SUM(RawMatRequeredQty) RawMatRequeredQty
			FROM JOCfnGetRawMaterialInDirectRequiredQty(@JobOrderGuid, @RawMaterialGuid, @StageGuid)
		)
	END
######################################################################