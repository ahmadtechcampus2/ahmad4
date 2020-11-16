#############################################################################
CREATE FUNCTION fn_GetJobOrder (@FactoryGuid UNIQUEIDENTIFIER)
RETURNS TABLE
AS
RETURN (SELECT * FROM JobOrder000 J WHERE J.ManufactoryGUID = @FactoryGuid )
#############################################################################

CREATE FUNCTION fn_GetProductionLine (@FactoryGuid UNIQUEIDENTIFIER)
RETURNS TABLE
AS
RETURN (SELECT * FROM ProductionLine000 P WHERE P.ManufactoryGUID = @FactoryGuid)
#############################################################################

CREATE FUNCTION fn_GetJocTrans (@FactoryGuid UNIQUEIDENTIFIER)
RETURNS TABLE
AS
RETURN (SELECT * FROM JocTrans000 J WHERE J.Manufactory = @FactoryGuid )
#############################################################################

CREATE FUNCTION fn_GetFactoryDirectLaborAcc()
RETURNS TABLE
AS
RETURN ( 
		 SELECT * from ac000 Acc
		 WHERE (Acc.[Type]  = 8 OR (Acc.NSons <= 0 AND Acc.[Type] <> 4)) 
		 AND Acc.[Guid] NOT IN (SELECT DirectLaborsAcc From Manufactory000 union SELECT MohAcc From Manufactory000  )
		 AND Guid NOT in (SELECT ShiftControlGUID From POSSDStation000) AND 
		             Guid NOT in (SELECT ContinuesCashGUID From POSSDStation000)
		 )
#############################################################################

CREATE FUNCTION JOCfn_GetFactoryMohAcc()
RETURNS TABLE
AS
RETURN ( 
		  SELECT DISTINCT acc1.* from ac000 acc1
		 INNER JOIN ac000 acc2 ON acc1.[GUID] = acc2.ParentGUID
		 WHERE acc1.Type <> 8 
		 AND acc1.Type <> 4
		 AND acc1.GUID NOT IN (SELECT MohAcc From Manufactory000  union SELECT DirectLaborsAcc From Manufactory000 UNION SELECT MOHIndirectAcc FROM Manufactory000 )
		 )
#############################################################################

CREATE FUNCTION fn_GetFactoryIndirectMohAcc(@MOHAccGuid UNIQUEIDENTIFIER)
RETURNS TABLE
AS
RETURN ( 
		 SELECT DISTINCT acc1.* from ac000 acc1
		 INNER JOIN ac000 acc2 ON acc1.[GUID] = acc2.ParentGUID
		 WHERE acc1.Type <> 8 
		 AND acc1.Type <> 4
		 AND acc1.ParentGuid = @MOHAccGuid
		 AND acc1.Guid  NOT IN ( SELECT MOHIndirectAcc FROM Manufactory000 UNION SELECT MohAcc FROM Manufactory000 UNION SELECT DirectLaborsAcc From Manufactory000  )
		)

#############################################################################

CREATE FUNCTION fn_GetFactoryInProcessAcc()
RETURNS TABLE
AS
RETURN ( 
		 SELECT * from ac000 Acc
		 WHERE Acc.NSons > 0
		 AND Acc.[Guid] NOT IN (SELECT InProcessAcc From Manufactory000)
		)

#############################################################################
CREATE FUNCTION fn_GetDirectExpensesAcc(@ManufactoryGuid UNIQUEIDENTIFIER,@ProductionLineGuid UNIQUEIDENTIFIER)
RETURNS TABLE
AS
RETURN ( 
		 SELECT * from ac000 Acc
		 WHERE Acc.ParentGUID IN ( SELECT GUID FROM [dbo].[fnGetAccountsList]( (SELECT MOHAcc FROM Manufactory000 WHERE GUID=@ManufactoryGuid), 1) )
		 AND Acc.GUID NOT IN	( SELECT GUID FROM [dbo].[fnGetAccountsList]( (SELECT MOHIndirectAcc FROM Manufactory000 WHERE GUID=@ManufactoryGuid), 1) )
		 AND Acc.GUID NOT IN	(SELECT ExpensesAccount FROM ProductionLine000 WHERE GUID <> @ProductionLineGuid)
		 AND ACC.GUID IN		(SELECT ParentGUID FROM ac000 )
		 AND Acc.[Type]  <> 8
		 AND Acc.[Type] <> 4
		)
#############################################################################
CREATE FUNCTION fn_GetDeviationAcc(@ManufactoryGuid UNIQUEIDENTIFIER,@ProductionLineGuid UNIQUEIDENTIFIER)
RETURNS TABLE
AS
RETURN ( 
		 SELECT * from ac000 Acc
		 WHERE Acc.ParentGUID IN ( SELECT GUID FROM [dbo].[fnGetAccountsList]( (SELECT MOHAcc FROM Manufactory000 WHERE GUID=@ManufactoryGuid), 1) )
		 AND Acc.GUID NOT IN	( SELECT GUID FROM [dbo].[fnGetAccountsList]( (SELECT MOHIndirectAcc FROM Manufactory000 WHERE GUID=@ManufactoryGuid), 1) )
		 AND Acc.GUID NOT IN	(SELECT DeviationAccount FROM ProductionLine000 WHERE GUID <> @ProductionLineGuid)
		 AND Acc.GUID NOT IN	(SELECT IndustrialAccount FROM ProductionLine000 )
		 AND ACC.GUID NOT IN	(SELECT ParentGUID FROM ac000 )
		 AND Acc.[Type]  <> 8
		 AND Acc.[Type] <> 4
		)

#############################################################################
CREATE FUNCTION fn_GetIndustrialAcc(@ManufactoryGuid UNIQUEIDENTIFIER,@ProductionLineGuid UNIQUEIDENTIFIER)
RETURNS TABLE
AS
RETURN ( 
		 SELECT * from ac000 Acc
		 WHERE Acc.ParentGUID IN ( SELECT GUID FROM [dbo].[fnGetAccountsList]( (SELECT MOHAcc FROM Manufactory000 WHERE GUID=@ManufactoryGuid), 1) )
		 AND Acc.GUID NOT IN	( SELECT GUID FROM [dbo].[fnGetAccountsList]( (SELECT MOHIndirectAcc FROM Manufactory000 WHERE GUID=@ManufactoryGuid), 1) )
		 AND Acc.GUID NOT IN	(SELECT IndustrialAccount FROM ProductionLine000 WHERE GUID <> @ProductionLineGuid)
		 AND Acc.GUID NOT IN	(SELECT DeviationAccount FROM ProductionLine000 )
		 AND ACC.GUID NOT IN	(SELECT ParentGUID FROM ac000 )
		 AND Acc.[Type]  <> 8
		 AND Acc.[Type] <> 4
		)

#############################################################################

CREATE FUNCTION fn_GetProductionLineInProcessAcc(@FactoryGuid uniqueidentifier)
RETURNS TABLE
AS
RETURN (
		 SELECT Acc.* FROM ac000 Acc 
		 INNER JOIN Manufactory000 MU ON Acc.ParentGUID = MU.InProcessAcc
		 WHERE MU.[Guid] = @FactoryGuid 
		 AND Acc.[GUID] NOT IN (SELECT P.InProcessAccGuid FROM ProductionLine000 P)
		)
#############################################################################

CREATE FUNCTION fnGetJobOrderInProcessAcc(@ProductionLineGuid uniqueidentifier)
RETURNS TABLE
AS
RETURN (SELECT Acc.* FROM ac000 Acc 
		INNER JOIN ProductionLine000 Pl ON Acc.ParentGUID = Pl.InProcessAccGuid
		WHERE Pl.[Guid] = @ProductionLineGuid
		 AND Acc.[GUID] NOT IN (SELECT Account FROM JobOrder000)
		)
#############################################################################

CREATE FUNCTION fnGetDirectMatRequestionTblByFactory(@FactoryGuid uniqueidentifier)
RETURNS TABLE
AS
RETURN (SELECT * FROM DirectMatRequestion000 DirectMat WHERE Manufactory = @FactoryGuid)
#############################################################################

CREATE FUNCTION fnGetDirectMatRequestionTblByJobOrder(@JobOrderGuid uniqueidentifier)
RETURNS TABLE
AS
RETURN (SELECT * FROM DirectMatRequestion000 DirectMat WHERE JobOrder = @JobOrderGuid)
#############################################################################

CREATE FUNCTION fnGetDirectMatReturnTblByJobOrder(@JobOrderGuid uniqueidentifier)
RETURNS TABLE
AS
RETURN (SELECT * FROM DirectMatReturn000 DirectMat WHERE JobOrder = @JobOrderGuid)
#############################################################################

CREATE FUNCTION fnGetDirectMatReturnTblByFactory(@FactoryGuid uniqueidentifier)
RETURNS TABLE
AS
RETURN (SELECT * FROM DirectMatReturn000 DirectMat WHERE Manufactory = @FactoryGuid)
#############################################################################

CREATE FUNCTION JocfnGetReturnMaterialSerialNumbers (@MaterialGuid UNIQUEIDENTIFIER, @JobOrderGuid UNIQUEIDENTIFIER)
RETURNS TABLE
AS
RETURN	(
		 SELECT snc.[GUID], snc.[SN] FROM snc000 snc 
		 INNER JOIN snt000 snt ON snc.[GUID] = snt.ParentGUID
		 INNER JOIN ((SELECT Bill FROM DirectMatRequestion000 Requestion WHERE Requestion.JobOrder = @JobOrderGuid) UNION (SELECT OutBill AS Bill FROM JocTrans000 Trans WHERE Trans.Dest = @JobOrderGuid)) RequestionAndTrans
		 ON snt.buGuid = RequestionAndTrans.Bill
		 AND snc.MatGUID = @MaterialGuid
		 WHERE snc.SN NOT IN (SELECT SerialNumbers.sn FROM vcSNs SerialNumbers
								INNER JOIN (
											(SELECT Bill FROM DirectMatReturn000 MatReturn)
											UNION 
											(SELECT InBill AS Bill FROM JocTrans000 WHERE Src = @JobOrderGuid )
											) MatReturn ON SerialNumbers.buGuid = MatReturn.Bill
							)
		)
#############################################################################

CREATE FUNCTION JocFnIsFactoryUnitUsed (@FactoryGuid UNIQUEIDENTIFIER)
RETURNS TABLE
AS
RETURN	(
			SELECT productionLines.[GUID] FROM JOCBOMProductionLines000 BomProductionLines 
			INNER JOIN ProductionLine000 productionLines ON BomProductionLines.[ProductionLineGuid] = productionLines.[Guid]
			WHERE productionLines.ManufactoryGUID = @FactoryGuid
		)
#############################################################################

CREATE FUNCTION JocFnMaterialInventory (@MaterialGuid UNIQUEIDENTIFIER, @JobOrderGuid UNIQUEIDENTIFIER ,@BillGuid UNIQUEIDENTIFIER, @UINT INT)
RETURNS TABLE
AS
RETURN	(
				SELECT 
				SUM(bi.Qty * CASE WHEN (bu.TypeGUID = Manufactory.MatRequestBillType OR bu.TypeGUID = Manufactory.OutTransBillType) THEN 1
										 WHEN (bu.TypeGUID = Manufactory.MatReturnBillType OR bu.TypeGUID = Manufactory.InTransBillType )THEN -1
										 ELSE 0 END
						  ) / dbo.JocFnGetMaterialFactorial(bi.MatGUID, @UINT)
					 AS Quantity
				FROM bi000 bi
				INNER JOIN bu000 bu ON bu.[GUID] = bi.ParentGUID
				INNER JOIN JobOrder000 JobOrder On JobOrder.Account = bu.CustAccGUID
				INNER JOIN Manufactory000 Manufactory ON Manufactory.[Guid] = JobOrder.ManufactoryGUID
				WHERE JobOrder.[Guid] = @JobOrderGuid
				AND bi.MatGUID = @MaterialGuid
				AND bu.[GUID] <> @BillGuid
				AND (bu.TypeGUID = Manufactory.MatRequestBillType OR bu.TypeGUID =  Manufactory.MatReturnBillType 
					 OR bu.TypeGUID =  Manufactory.InTransBillType OR bu.TypeGUID = Manufactory.OutTransBillType )
				GROUP BY
				bi.MatGUID
		)


#############################################################################

CREATE FUNCTION JocfnGetDirectMaterialSerialNumbers (@MaterialGuid UNIQUEIDENTIFIER, @StoreGuid UNIQUEIDENTIFIER)
RETURNS TABLE
AS
RETURN  (	SELECT DISTINCT snc.[GUID], snc.SN  FROM snc000 snc
			INNER JOIN snt000 snt ON snc.[GUID] = snt.ParentGUID
			INNER JOIN bu000 bu ON snt.buGuid = bu.[GUID]
			INNER JOIN bt000 bt ON bt.[GUID] = bu.TypeGUID
			WHERE snc.MatGUID = @MaterialGuid 
			AND bu.StoreGUID = @StoreGuid
			AND bt.bIsInput = 1
			AND snc.Qty > 0
		)
#############################################################################

CREATE FUNCTION JocfnReadSerialNumbers (@biGuid UNIQUEIDENTIFIER)
RETURNS TABLE
AS
RETURN	(	SELECT SNC.Guid, SNC.SN FROM SNC000 SNC 
			INNER JOIN SNT000 SNT ON SNC.[Guid] = SNT.[ParentGuid]
			WHERE (SNT.biGuid = @biGuid)
		)
#############################################################################

CREATE FUNCTION JocFnGetTransfereByJobOrder (@JobOrderGuid UNIQUEIDENTIFIER)
RETURNS TABLE
AS
RETURN	(SELECT * FROM JocTrans000 trans WHERE Src = @JobOrderGuid)
#############################################################################

CREATE FUNCTION JOCfnGetProducedMaterialUnitFactor(@MaterialGuid UNIQUEIDENTIFIER, @MaterialUnit FLOAT ,@ProductionUnit FLOAT)
RETURNS FLOAT
AS
BEGIN
	DECLARE @MaterialUnitFactor FLOAT = (SELECT dbo.JOCfngetMaterialUnitFactor(@MaterialGuid, @MaterialUnit))
	DECLARE @ProductionUnitOneConv FLOAT = (SELECT bom.Prod1ConvMatUnit FROM JOCBOM000 bom Where bom.MatPtr = @MaterialGuid)
	DECLARE @ProductionUnitTwoConv FLOAT = (SELECT bom.Prod2ConvMatUnit FROM JOCBOM000 bom Where bom.MatPtr = @MaterialGuid)
	DECLARE @ProductionUnitOneConvFactor FLOAT = (SELECT bom.Prod1ToMatUnitConvFactor FROM JOCBOM000 bom Where bom.MatPtr = @MaterialGuid)
	DECLARE @ProductionUnitTwoConvFactor FLOAT = (SELECT bom.Prod2ToMatUnitConvFactor FROM JOCBOM000 bom Where bom.MatPtr = @MaterialGuid)

	DECLARE @ProductUnitFactor FLOAT = ( CASE WHEN @ProductionUnit = 1 THEN dbo.JOCfngetMaterialUnitFactor(@MaterialGuid, @ProductionUnitOneConv)  
	WHEN @ProductionUnit = 2 AND @ProductionUnitTwoConvFactor =0  THEN dbo.JOCfngetMaterialUnitFactor(@MaterialGuid, @ProductionUnitOneConv)  ELSE dbo.JOCfngetMaterialUnitFactor(@MaterialGuid, @ProductionUnitTwoConv) END )
	DECLARE @FactoryUnitConFactor FLOAT = (  CASE WHEN @ProductionUnit = 1 THEN @ProductionUnitOneConvFactor WHEN @ProductionUnit = 2 AND @ProductionUnitTwoConvFactor =0  THEN @ProductionUnitOneConvFactor ELSE @ProductionUnitTwoConvFactor  END )


	RETURN (
			SELECT (@MaterialUnitFactor * @FactoryUnitConFactor)/@ProductUnitFactor
			)	
END
#############################################################################

CREATE FUNCTION JOCfnGetBOMActualProduction(@JobOrderGuid UNIQUEIDENTIFIER,  @BOMMaterialGuid UNIQUEIDENTIFIER, @ComboUnit INT)
RETURNS FLOAT
AS
BEGIN
	DECLARE @ActualProduction FLOAT = (SELECT Qty FROM dbo.JocFnGetActualProductionQty(@JobOrderGuid, 1)) ;
	
	IF(@ComboUnit = 4 OR @ComboUnit = 5) --æÍÏÇÊ ÇáãÕäÚ
	BEGIN
		RETURN @ActualProduction * (SELECT dbo.JOCfnGetProducedMaterialUnitFactor(@BOMMaterialGuid, 1, @ComboUnit - 3))
	END

	IF(@ComboUnit = 6) --ÇáæÍÏÉ ÇáÇÝÊÑÇÖíÉ
	BEGIN
	RETURN  @ActualProduction / (SELECT dbo.JOCfngetMaterialUnitFactor(@BOMMaterialGuid,(SELECT DefUnit FROM mt000 WHERE [GUID] = @BOMMaterialGuid)))
	END

	RETURN  @ActualProduction / (SELECT dbo.JOCfngetMaterialUnitFactor(@BOMMaterialGuid, @ComboUnit )) --æÍÏÇÊ ÇáãÇÏÉ 

END


#############################################################################

CREATE PROCEDURE JocPrcIsRequestionSerialNumberValid 
@MaterialGuid UNIQUEIDENTIFIER,
@SerialNumber NVARCHAR(100)
,@JobOrderAccountGuid UNIQUEIDENTIFIER

AS
	SET NOCOUNT ON

	SELECT SerialNumbers.[guid], SerialNumbers.sn FROM vcSNs SerialNumbers
	INNER JOIN bu000 bu ON bu.GUID = SerialNumbers.buGuid
	WHERE SerialNumbers.MatGuid = @MaterialGuid
	AND SerialNumbers.buGuid IN ((SELECT Bill FROM DirectMatReturn000) UNION (SELECT InBill AS Bill FROM JocTrans000) UNION (SELECT OutBill AS Bill FROM JocTrans000))
	AND SerialNumbers.sn = @SerialNumber
	AND bu.CustAccGUID = @JobOrderAccountGuid


#############################################################################

CREATE PROCEDURE JocPrcIsReturnNumberValid 
@MaterialGuid UNIQUEIDENTIFIER,
@SerialNumber NVARCHAR(100)
AS
	SET NOCOUNT ON

	DECLARE @RequestionAndTransCnt INT, @ReturnCnt INT

	SELECT @RequestionAndTransCnt =  ISNULL(COUNT(snt.buGuid), 0) FROM snc000 snc 
								 INNER JOIN snt000 snt on snc.[GUID] = snt.ParentGUID
								 INNER JOIN bu000 bu ON snt.buGuid = bu.[GUID]
								 WHERE snt.buGuid IN ((SELECT Bill FROM DirectMatRequestion000) UNION (SELECT InBill FROM JocTrans000) )
								 AND snc.SN = @SerialNumber
	
	SELECT @ReturnCnt =  ISNULL(COUNT (snt.[buGuid]), 0) FROM snc000 snc 
							 INNER JOIN snt000 snt on snc.[GUID] = snt.ParentGUID
							 INNER JOIN bu000 bu ON snt.buGuid = bu.[GUID]
							 WHERE snt.buGuid IN (SELECT Bill From DirectMatReturn000 )
							 AND snc.SN = @SerialNumber

	IF(@ReturnCnt >= @RequestionAndTransCnt)
	BEGIN
		SELECT 1
	END	

#############################################################################

CREATE FUNCTION JocFnGetJobOrderQuantities (@JobOrderGuid UNIQUEIDENTIFIER, @MaterialGuid UNIQUEIDENTIFIER)
RETURNS TABLE
AS
RETURN (
			SELECT @JobOrderGuid AS JobOrderGuid
			,SUM(bi.Qty *  CASE WHEN bu.TypeGUID = factory.MatRequestBillType THEN 1 ELSE 0 END) AS TotalExpensedQty
			,SUM(bi.Qty *  CASE WHEN bu.TypeGUID = factory.MatReturnBillType THEN 1 ELSE 0 END) AS TotalReturnedQty
			,SUM(bi.Qty *  CASE WHEN bu.TypeGUID = factory.OutTransBillType THEN 1 ELSE 0 END) AS TotalTransOutQty
			,SUM(bi.Qty *  CASE WHEN bu.TypeGUID = factory.InTransBillType THEN 1 ELSE 0 END) AS TotalTransInQty 
			,SUM(bi.Qty *  CASE WHEN (bu.TypeGUID = factory.OutTransBillType OR bu.TypeGUID = factory.MatRequestBillType)  THEN 1 ELSE 0 END) AS TotalOut
			,SUM(bi.Qty *  CASE WHEN (bu.TypeGUID = factory.InTransBillType OR bu.TypeGUID = factory.MatReturnBillType)  THEN 1 ELSE 0 END) AS TotalIn

			,SUM(bi.Qty *  CASE WHEN (bu.TypeGUID = factory.OutTransBillType OR bu.TypeGUID = factory.MatRequestBillType) THEN 1 
								WHEN  (bu.TypeGUID = factory.InTransBillType OR bu.TypeGUID = factory.MatReturnBillType) THEN -1 
								ELSE 0 END) AS NetQty
			,SUM((bi.Price * bi.Qty / dbo.JocFnGetMaterialFactorial(bi.MatGuid, bi.Unity)) * CASE WHEN (bu.TypeGUID = factory.OutTransBillType OR bu.TypeGUID = factory.MatRequestBillType) THEN 1 
										  WHEN  (bu.TypeGUID = factory.InTransBillType OR bu.TypeGUID = factory.MatReturnBillType) THEN -1 
										  ELSE 0 END) AS NetExchange

			FROM bi000 bi 
			INNER JOIN bu000 bu ON bi.ParentGUID = bu.[GUID]
			INNER JOIN JobOrder000 JobOrder ON bu.CustAccGUID = JobOrder.Account
			INNER JOIN Manufactory000 factory ON JobOrder.ManufactoryGUID = factory.[Guid]
			WHERE JobOrder.[Guid] = @JobOrderGuid
			AND bi.[MatGUID] = @MaterialGuid
			GROUP BY 
			JobOrder.[Guid]
		)
#############################################################################
CREATE FUNCTION JocFnGetJobOrderQuantitiesForStage (@JobOrderGuid UNIQUEIDENTIFIER, @MaterialGuid UNIQUEIDENTIFIER, @StageGuid UNIQUEIDENTIFIER)
RETURNS TABLE
AS
RETURN (
		SELECT SUM(NetQty)  AS NetQty FROM JOCvwJobOrderRawMaterialsQuantities 
		WHERE MaterialGuid= @MaterialGuid 
		AND 
		StageGuid=@StageGuid
		AND 
		JobOrderGuid=@JobOrderGuid
		GROUP BY 
		StageGuid
		)
#############################################################################

CREATE FUNCTION JocFnGetMaterialUnitName(@UNIT FLOAT, @MaterialGuid UNIQUEIDENTIFIER)
RETURNS NVARCHAR(100)
AS
BEGIN
	DECLARE @UnitName NVARCHAR(100)

	SELECT @UnitName = (SELECT CASE WHEN @UNIT = 2 AND mt.Unit2Fact != 0 THEN mt.Unit2 WHEN @UNIT = 3 AND mt.Unit3Fact != 0 THEN mt.Unit3  WHEN @UNIT=6 THEN 
	(CASE WHEN mt.DefUnit=1 THEN mt.Unity WHEN mt.DefUnit= 2 THEN mt.Unit2 ELSE mt.Unit3 END)
	ELSE   mt.Unity END
						  FROM mt000 mt
						  where mt.[GUID] = @MaterialGuid
						  )
	RETURN @UnitName
END
#############################################################################

CREATE FUNCTION JOCfnGetProdComboUnitName(@ProductUnit INT, @ManufactoryGUID UNIQUEIDENTIFIER, @MaterialGuid UNIQUEIDENTIFIER)
RETURNS NVARCHAR(250)
AS
BEGIN



IF(@ProductUnit = 4 OR @ProductUnit = 5)
	RETURN (dbo.JOCfnGetManufactoryUnitName(@ManufactoryGuid, @ProductUnit - 3))

RETURN dbo.JocFnGetMaterialUnitName(@ProductUnit, @MaterialGuid)
END
#############################################################################

CREATE VIEW JOCJobOrdersBOMRawMaterials
AS
SELECT 
JobOrder.JobOrderGuid
,BomOperatingBOM.[GUID]		AS	BomInstanceGuid
,BomOperatingBOM.BOMGuid
,Materials.[GUID]		AS	MaterialGuid
,Materials.Code			AS MaterialCode
,Materials.Name			AS	MaterialName
,Materials.LatinName	AS	MaterialLatinName
,Materials.ExpireFlag	AS ExpireFlag
,Materials.SNFlag		AS SNFlag
,RawMaterials.Unit		AS MaterialUnit
,RawMaterials.RawMaterialIndex	
,CASE WHEN RawMaterials.Unit = 1 THEN Materials.Unity WHEN RawMaterials.Unit = 2 THEN Materials.Unit2 ELSE Materials.Unit3 END AS MaterialUnitName
,(RawMaterials.Quantity * Joborder.JobOrderReplicasCount)	AS QuantityNeededForJobOrder
,RawMaterials.Quantity	AS MaterialQuantity
,RawMaterials.StageGuid		AS StageGuid
,Stages.Name			AS StageName
,Stages.LatinName		AS StageLatinName
,ISNULL((SELECT TotalExpensedQty FROM JocFnGetJobOrderQuantities(JobOrder.JobOrderGuid, Materials.[GUID])) / dbo.JocFnGetMaterialFactorial(Materials.[GUID], RawMaterials.Unit),0)	AS ExpensedQty
,ISNULL((SELECT TotalReturnedQty FROM JocFnGetJobOrderQuantities(JobOrder.JobOrderGuid, Materials.[GUID])) / dbo.JocFnGetMaterialFactorial(Materials.[GUID], RawMaterials.Unit),0)	AS ReturnedQty
,ISNULL((SELECT TotalTransOutQty FROM JocFnGetJobOrderQuantities(JobOrder.JobOrderGuid, Materials.[GUID])) / dbo.JocFnGetMaterialFactorial(Materials.[GUID], RawMaterials.Unit),0)	AS TransOutQty
,ISNULL((SELECT TotalTransInQty FROM JocFnGetJobOrderQuantities(JobOrder.JobOrderGuid, Materials.[GUID])) / dbo.JocFnGetMaterialFactorial(Materials.[GUID], RawMaterials.Unit),0)	AS TransInQty	
,ISNULL((SELECT NetQty FROM JocFnGetJobOrderQuantities(JobOrder.JobOrderGuid, Materials.[GUID])) / dbo.JocFnGetMaterialFactorial(Materials.[GUID], RawMaterials.Unit),0) 			AS NetQty		
,ISNULL((SELECT NetExchange FROM JocFnGetJobOrderQuantities(JobOrder.JobOrderGuid, Materials.[GUID])),0)	AS NetExchange																				   
FROM JOCvwJobOrderRawMaterialsWithoutDist RawMaterials
INNER JOIN JOCJobOrderOperatingBOM000 BomOperatingBOM ON RawMaterials.OperatingBOMGuid = BomOperatingBOM.[GUID]
INNER JOIN JocVwJobOrder JobOrder ON BomOperatingBOM.Guid = JobOrder.JobOrderBOM
INNER JOIN JocVwMaterialsWithAlternatives Materials ON RawMaterials.RawMaterialGuid = Materials.[GUID]
LEFT JOIN JOCStages000 Stages ON Stages.GUID = RawMaterials.StageGuid
#############################################################################

CREATE PROC JocPrcGetJobOrderMaterialsOnRequestion
	@JobOrderGuid UNIQUEIDENTIFIER = 0X0
AS
BEGIN
	SET NOCOUNT ON;
	CREATE TABLE #Result 
	(
		 MaterialGuid				UNIQUEIDENTIFIER  
		,MaterialIndex				INT
	    ,MaterialCode				NVARCHAR (255) COLLATE ARABIC_CI_AI   
	    ,MaterialName				NVARCHAR (255) COLLATE ARABIC_CI_AI   
	    ,MaterialLatinName			NVARCHAR (255)
		,MaterialUnit				INT
		,MaterialUnitName			NVARCHAR(100)
		,BOMRawMaterialQuantity		FLOAT
		,ExpensedQty				FLOAT
		,ReturnedQty				FLOAT   
		,TransOutQty				FLOAT
		,TransInQty					FLOAT
	    ,NetQty						FLOAT
		,NetExchange				FLOAT
	    ,QuantityNeededForJobOrder	FLOAT   
		,ExpireFlag                 BIT
		,SNFlag						BIT
		,ForceInSN					BIT
		,ForceOutSN					BIT
		,StageGuid					UNIQUEIDENTIFIER
	)

	INSERT INTO #Result 
	SELECT 
		Materials.[GUID]
		,JobOrderMaterials.GridIndex
		,Materials.Code
		,Materials.MatName
		,Materials.LatinName
		,JobOrderMaterials.Unit
		,dbo.JocFnGetMaterialUnitName(JobOrderMaterials.Unit, Materials.[GUID])
		,JobOrderMaterials.RawMatQuantity 
		,ISNULL((SELECT TotalExpensedQty FROM JocFnGetJobOrderQuantities(@JobOrderGuid, Materials.[GUID])) / dbo.JocFnGetMaterialFactorial(Materials.[GUID], JobOrderMaterials.Unit),0)
		,ISNULL((SELECT TotalReturnedQty FROM JocFnGetJobOrderQuantities(@JobOrderGuid, Materials.[GUID])) / dbo.JocFnGetMaterialFactorial(Materials.[GUID], JobOrderMaterials.Unit),0)
		,ISNULL((SELECT TotalTransOutQty FROM JocFnGetJobOrderQuantities(@JobOrderGuid, Materials.[GUID])) / dbo.JocFnGetMaterialFactorial(Materials.[GUID], JobOrderMaterials.Unit),0)
		,ISNULL((SELECT TotalTransInQty FROM JocFnGetJobOrderQuantities(@JobOrderGuid, Materials.[GUID])) / dbo.JocFnGetMaterialFactorial(Materials.[GUID], JobOrderMaterials.Unit),0)
		,ISNULL((SELECT NetQty FROM JocFnGetJobOrderQuantities(@JobOrderGuid, Materials.[GUID])) / dbo.JocFnGetMaterialFactorial(Materials.[GUID], JobOrderMaterials.Unit),0) 
		,ISNULL((SELECT NetExchange FROM JocFnGetJobOrderQuantities(@JobOrderGuid, Materials.[GUID])),0)
		,(JobOrderMaterials.RawMatQuantity * JobOrder.PlannedProductionQty / JobOrderInstance.ProductionQuantity)
		,Materials.ExpireFlag
		,Materials.SNFlag
		,Materials.ForceInSN
		,Materials.ForceOutSN
		,JobOrderMaterials.Stage
	FROM JOCBOMRawMaterials000 JobOrderMaterials
	INNER JOIN JOCBOMInstance000 JobOrderInstance ON JobOrderInstance.[GUID] = JobOrderMaterials.JOCBOMGuid
	INNER JOIN JobOrder000 JobOrder ON JobOrderInstance.JobOrderGuid = JobOrder.[Guid]
	LEFT JOIN JocVwMaterialsWithAlternatives Materials ON Materials.[GUID] = JobOrderMaterials.MatPtr
	WHERE JobOrder.[Guid] = @JobOrderGuid
	GROUP BY
	Materials.[GUID]
	,Materials.Code
	,Materials.MatName
	,Materials.LatinName
	,Materials.ExpireFlag
	,Materials.SNFlag
	,Materials.ForceInSN
	,Materials.ForceOutSN
	,Materials.GroupGUID
	,JobOrderMaterials.Unit
	,JobOrderMaterials.RawMatQuantity
	,JobOrderInstance.ProductionQuantity
	,JobOrder.PlannedProductionQty
	,JobOrderMaterials.GridIndex
	,JobOrderMaterials.Stage


	SELECT * FROM #Result ORDER BY MaterialIndex
	DROP TABLE #Result
END
#############################################################################
CREATE VIEW JOCvwJobOrderRequestionAndOutTrans
AS
SELECT Guid, Bill, JobOrder FROM DirectMatRequestion000
UNION 
SELECT Guid, OutBill AS Bill, Dest AS JobOrder FROM JocTrans000

#############################################################################

CREATE PROC JocPrcGetJobOrderMaterialsOnReturn
@JobOrderGuid UNIQUEIDENTIFIER = 0X0
AS
BEGIN
	SET NOCOUNT ON;
	CREATE TABLE #Result 
	(
		 MaterialGuid				UNIQUEIDENTIFIER  
		,MaterialIndex				INT
	    ,MaterialCode				NVARCHAR (255) COLLATE ARABIC_CI_AI   
	    ,MaterialName				NVARCHAR (255) COLLATE ARABIC_CI_AI   
	    ,MaterialLatinName			NVARCHAR (255)
		,MaterialUnit				INT
		,MaterialUnitName			NVARCHAR(100)   
	    ,NetQty						FLOAT   
	    ,ExpensedQty				FLOAT   
		,ExpireFlag                 BIT
		,SNFlag						BIT
		,ForceInSN					BIT
		,ForceOutSN					BIT
	)

	INSERT INTO #Result 
	SELECT DISTINCT
		Materials.[GUID]
		,JobOrderMaterials.GridIndex
		,Materials.Code
		,Materials.MatName
		,Materials.LatinName
		,JobOrderMaterials.Unit
		,dbo.JocFnGetMaterialUnitName(JobOrderMaterials.Unit, Materials.[GUID])
		,ISNULL((SELECT NetQty FROM JocFnGetJobOrderQuantities(@JobOrderGuid, Materials.[GUID])) / dbo.JocFnGetMaterialFactorial(Materials.[GUID], JobOrderMaterials.Unit),0)
		,ISNULL((SELECT TotalOut FROM JocFnGetJobOrderQuantities(@JobOrderGuid, Materials.[GUID]))/ dbo.JocFnGetMaterialFactorial(Materials.[GUID], JobOrderMaterials.Unit) ,0) 
		,Materials.ExpireFlag
		,Materials.SNFlag
		,Materials.ForceInSN
		,Materials.ForceOutSN
	FROM JOCBOMRawMaterials000 JobOrderMaterials
	INNER JOIN JOCBOMInstance000 JobOrderInstance ON JobOrderMaterials.JOCBOMGuid = JobOrderInstance.[GUID]
	INNER JOIN JobOrder000 JobOrder ON JobOrderInstance.JobOrderGuid = JobOrder.[Guid]
	INNER JOIN JOCvwJobOrderRequestionAndOutTrans RequestionAndTrans ON RequestionAndTrans.JobOrder = JobOrder.[GUID]
	INNER JOIN Manufactory000 factory ON JobOrder.ManufactoryGUID = factory.[Guid]
	INNER JOIN JocVwMaterialsWithAlternatives Materials ON Materials.[GUID] = JobOrderMaterials.MatPtr
	WHERE JobOrder.[Guid] = @JobOrderGuid
	GROUP BY
	Materials.[GUID]
	,Materials.Code
	,Materials.MatName
	,Materials.LatinName
	,Materials.ExpireFlag
	,Materials.SNFlag
	,Materials.ForceInSN
	,Materials.ForceOutSN
	,Materials.GroupGUID
	,JobOrderMaterials.Unit
	,JobOrderMaterials.RawMatQuantity
	,JobOrderMaterials.GridIndex


	SELECT * FROM #Result  WHERE #Result.ExpensedQty > 0 ORDER BY MaterialIndex
	DROP TABLE #Result
END
#############################################################################

CREATE PROC JocPrcGetJobOrderTransSharedMaterials
@SourceJobOrderGuid UNIQUEIDENTIFIER
,@DestJobOrderGuid UNIQUEIDENTIFIER
AS
BEGIN
	SET NOCOUNT ON;
	CREATE TABLE #Src 
	(
		 MaterialGuid				UNIQUEIDENTIFIER  
		,MaterialIndex				INT
	    ,MaterialCode				NVARCHAR (255) COLLATE ARABIC_CI_AI   
	    ,MaterialName				NVARCHAR (255) COLLATE ARABIC_CI_AI   
	    ,MaterialLatinName			NVARCHAR (255)
		,MaterialUnit				INT
		,MaterialUnitName			NVARCHAR(100)
		,BOMRawMaterialQuantity		FLOAT
		,ExpensedQty				FLOAT
		,ReturnedQty				FLOAT   
		,TransOutQty				FLOAT
		,TransInQty					FLOAT
	    ,NetQty						FLOAT
		,NetExchange				FLOAT
	    ,QuantityNeededForJobOrder	FLOAT   
		,ExpireFlag                 BIT
		,SNFlag						BIT
		,ForceInSN					BIT
		,ForceOutSN					BIT
	)

	CREATE TABLE #Dest 
	(
		 MaterialGuid				UNIQUEIDENTIFIER  
		,MaterialIndex				INT
	    ,MaterialCode				NVARCHAR (255) COLLATE ARABIC_CI_AI   
	    ,MaterialName				NVARCHAR (255) COLLATE ARABIC_CI_AI   
	    ,MaterialLatinName			NVARCHAR (255)
		,MaterialUnit				INT
		,MaterialUnitName			NVARCHAR(100)
		,BOMRawMaterialQuantity		FLOAT
		,ExpensedQty				FLOAT
		,ReturnedQty				FLOAT   
		,TransOutQty				FLOAT
		,TransInQty					FLOAT
	    ,NetQty						FLOAT
		,NetExchange				FLOAT
	    ,QuantityNeededForJobOrder	FLOAT   
		,ExpireFlag                 BIT
		,SNFlag						BIT
		,ForceInSN					BIT
		,ForceOutSN					BIT
	)

	INSERT INTO #Src EXEC JocPrcGetJobOrderMaterialsOnRequestion @SourceJobOrderGuid
	INSERT INTO #Dest EXEC JocPrcGetJobOrderMaterialsOnRequestion @DestJobOrderGuid

	SELECT #Src.* FROM #Src 
	INNER JOIN #Dest ON #Src.MaterialGuid = #Dest.MaterialGuid

	DROP TABLE #Src
	DROP TABLE #Dest
END
#############################################################################

CREATE FUNCTION JocFnGetNetQtyWithExpiryDateAndClass (@JobOrder UNIQUEIDENTIFIER, @MaterialGuid UNIQUEIDENTIFIER, @ExpireDate DATETIME , @ClassPtr NVARCHAR(256), @Unit INT)
RETURNS TABLE
AS
RETURN	(
			SELECT Bill.biExpireDate, ISNULL(SUM (Bill.biQty * CASE WHEN (Bill.buType = Factory.MatRequestBillType OR Bill.buType = Factory.OutTransBillType) THEN 1
											WHEN (Bill.buType = Factory.MatReturnBillType OR Bill.buType = Factory.InTransBillType) THEN -1 
											ELSE 0 END) , 0)
											/dbo.JOCfngetMaterialUnitFactor(bill.biMatPtr, @Unit) AS NetQty
			FROM vwBuBi Bill
			INNER JOIN JobOrder000 JobOrder ON Bill.buCustAcc = JobOrder.Account
			INNER JOIN Manufactory000 Factory ON JobOrder.ManufactoryGUID = Factory.[Guid]
			WHERE JobOrder.[Guid]= @JobOrder
			AND Bill.biMatPtr = @MaterialGuid
			AND Bill.biExpireDate =  @ExpireDate
			AND Bill.biClassPtr = @ClassPtr
			GROUP BY
			bill.biMatPtr
			,Bill.biExpireDate
			,Bill.biClassPtr
		)
#############################################################################

CREATE FUNCTION JocFnGetMaterialInventoryWithBomUnit(
 @JobOrderGuid UNIQUEIDENTIFIER 
)
	RETURNS @Result TABLE 
	(
	 MaterialGuid		  UNIQUEIDENTIFIER,
	 MaterialName		  NVARCHAR(250) COLLATE ARABIC_CI_AI,
	 MaterialLatinName	  NVARCHAR(250) COLLATE ARABIC_CI_AI,
	 MaterialCode		  NVARCHAR(100),
	 ConsumedQuantity     FLOAT,
	 Price				  FLOAT,
	 BOMQuantity		  FLOAT,
	 UnitName			  NVARCHAR(100),
	 ProductionQtyInBOM	  FLOAT,
	 ProducedMatUnit	  INT,
	 ActualProductionQty  FLOAT,
	 GridIndex			  INT
	)  
		
BEGIN
----------------------- Select BOM Materials ----------------------------------------
INSERT INTO @Result
SELECT
	 BOMMat.GUID ,
	 Mt.MatName,
	 Mt.MatLatinName,
	 Mt.Code,
	ISNULL((SELECT NetQty FROM JocFnGetJobOrderQuantities(@JobOrderGuid, Mt.[GUID])) / dbo.JocFnGetMaterialFactorial(Mt.[GUID], BOMMat.Unit),0) ,
	ISNULL((SELECT NetExchange FROM JocFnGetJobOrderQuantities(@JobOrderGuid, Mt.[GUID])),0),
	BOMMat.RawMatQuantity ,
	CASE WHEN BOMMat.Unit=1 THEN Mt.Unity WHEN BOMMat.Unit=2 THEN Mt.Unit2 ELSE Mt.Unit3 END,
	BOMI.ProductionQuantity,
	BOMI.ProducedMatUnit,
	0,
	BOMMat.GridIndex
FROM JOCBOMRawMaterials000  BOMMat 
	LEFT JOIN JocVwMaterialsWithAlternatives Mt ON BOMMat.MatPtr = Mt.Guid 
	LEFT JOIN JOCBOMInstance000 BOMI ON BOMI.GUID=BOMMat.JOCBOMGuid
WHERE BOMI.JobOrderGuid=@JobOrderGuid
    GROUP BY  BOMMat.GUID,  
			  Mt.MatName,
			  Mt.MatLatinName,
			  Mt.Code,
			  BOMMat.Unit,
			  Mt.Guid,
			  BOMMat.Unit,
			  Mt.Unity,
			  Mt.Unit2,
			  Mt.Unit3,
			  RawMatQuantity,
			  BOMI.ProductionQuantity,
			  BOMI.ProducedMatUnit,
			  BOMMat.GridIndex
	ORDER BY  BOMMat.GridIndex

------------------------------Update Actual Qty--------------------------------------
UPDATE @Result SET ActualProductionQty=(SELECT Qty FROM  JocFnGetActualProductionQty(@JobOrderGuid,ProducedMatUnit))

	RETURN 
END
#############################################################################
CREATE PROCEDURE JocPrcGetRawMaterialDeviation
@JobOrderGuid UNIQUEIDENTIFIER 
AS
BEGIN
SET NOCOUNT ON 
	CREATE TABLE [#Result]
	( 
		[MaterialGuid]		[UNIQUEIDENTIFIER], 
		[MaterialName]		[NVARCHAR](250) COLLATE ARABIC_CI_AI,
		[MaterialLatinName]	[NVARCHAR](250) COLLATE ARABIC_CI_AI,
		[MaterialUnitName]	[NVARCHAR](100),
		[MaterialCode]		[NVARCHAR](100),
		[StandardQuantity]	[FLOAT], 
		[ConsumedQuantity]	[FLOAT], 
		[Deviation]			[FLOAT],
		[DeviationRatio]	[FLOAT],
		[Price]				[FLOAT],
		[DeviationValue]	[FLOAT],
		[GridIndex]			[INT]
	)

	-------------------- Fill Result With Materials Before Calculating Deviation Value ----------------
	INSERT INTO [#Result]
	SELECT BOMMats.MaterialGuid,BOMMats.MaterialName,BOMMats.MaterialLatinName,
		BOMMats.UnitName,BOMMats.MaterialCode,
		(BOMMats.BOMQuantity*BOMMats.ActualProductionQty)/BOMMats.ProductionQtyInBOM,
		BOMMats.ConsumedQuantity,0,0,
		CASE WHEN BOMMats.ConsumedQuantity=0 THEN 0 ELSE(BOMMats.Price/BOMMats.ConsumedQuantity) END,0,BOMMats.[GridIndex]
	FROM  JocFnGetMaterialInventoryWithBomUnit(@JobOrderGuid) AS BOMMats

	--------------------------------------- Calculate Deviation ---------------------------------------
	UPDATE #Result SET Deviation=(ConsumedQuantity-StandardQuantity)
	UPDATE #Result SET DeviationRatio=(Deviation/StandardQuantity)*100,
	DeviationValue=Deviation*Price
	----------------------------------------------------------------------------------------------------
	SELECT * FROM #Result ORDER BY GridIndex

END
#############################################################################
CREATE FUNCTION JocFnRawMaterialDeviation ( @JobOrderGuid UNIQUEIDENTIFIER )

RETURNS  @RESULT TABLE 
	(
		[MaterialGuid]		[UNIQUEIDENTIFIER], 
		[MaterialName]		[NVARCHAR](250) COLLATE ARABIC_CI_AI,
		[MaterialLatinName]	[NVARCHAR](250) COLLATE ARABIC_CI_AI,
		[MaterialUnit]		[INT],
		[MaterialUnitName]	[NVARCHAR](100),
		[MaterialCode]		[NVARCHAR](100),
		[StandardQuantity]	[FLOAT], 
		[ConsumedQuantity]	[FLOAT], 
		[Deviation]			[FLOAT],
		[DeviationRatio]	[FLOAT],
		[Price]				[FLOAT],
		[DeviationValue]	[FLOAT],
		[GridIndex]			[INT],
		[UnitDeviation]		[FLOAT],
		[StageGuid]			[UNIQUEIDENTIFIER],
		[StageName]			[NVARCHAR](250),
		[ActualProduction]	[FLOAT]
	) 
	
AS 
BEGIN
	INSERT INTO @RESULT 
		SELECT
			RawMat.MaterialGuid 
			,RawMat.MaterialName
			,RawMat.MaterialLatinName 
			,RawMat.Unit
			,RawMat.UnitName 
			,RawMat.MaterialCode 
			,(RawMat.RawMatQty *RawMat.JobOrderReplicasCount) 
			,RawMat.BOMNetQty 
			,RawMat.BOMNetQty - ((RawMat.RawMatQty *RawMat.JobOrderReplicasCount))--CONSUMED QTY /STANDARDQTY = DEVIATION
			,0
			,CASE WHEN RawMat.BOMNetQty=0 THEN 0 ELSE(RawMat.NetExchange/RawMat.BOMNetQty) END
			,0
			,RawMat.BOMIndex
			,0
			,RawMat.StageGuid
			,RawMat.StageName
			,RawMat.JobOrderReplicasCount
		FROM JOCvwJobOrderRawMaterialsQuantities  AS RawMat
		WHERE RawMat.JobOrderGuid=@JobOrderGuid
	UPDATE @Result SET DeviationRatio=(Deviation/StandardQuantity)*100,
		DeviationValue=Deviation*Price, UnitDeviation=(Deviation*Price)/ActualProduction
	RETURN
END 
#############################################################################
CREATE PROCEDURE Joc_SP_StagesCost
@JobOrderGuid UNIQUEIDENTIFIER
AS 
SET NOCOUNT ON  
CREATE TABLE [#Result]
		 ( 
			[StageGuid]			[UNIQUEIDENTIFIER], 
			[StageName]			[NVARCHAR](250) COLLATE ARABIC_CI_AI,
			[StageLatinName]	[NVARCHAR](250) COLLATE ARABIC_CI_AI,
			[MaterialValue]		[FLOAT],
			[UnitCost]			[FLOAT],
			[StandardValue]		[FLOAT],
			[Deviation]			[FLOAT],
			[UnitDeviation]		[FLOAT],
			[Labors]			[FLOAT],
			[UnitLabor]			[FLOAT],
			[TotalPrimaryCost]  [FLOAT],
			[MaterialsAndLabors][FLOAT]
	    )

INSERT INTO #Result 
	SELECT ST.GUID
		,ST.Name
		,ST.LatinName 
		,SUM(MatsInfo.ConsumedQuantity*MatsInfo.Price)
		,SUM(MatsInfo.ConsumedQuantity*MatsInfo.Price)/MatsInfo.ActualProduction
		,SUM(MatsInfo.StandardQuantity*MatsInfo.Price)
		,SUM(MatsInfo.ConsumedQuantity*MatsInfo.Price)-SUM(MatsInfo.StandardQuantity*MatsInfo.Price)
		,(SUM(MatsInfo.ConsumedQuantity*MatsInfo.Price)-SUM(MatsInfo.StandardQuantity*MatsInfo.Price))/MatsInfo.ActualProduction
		,CASE WHEN ISNULL(Labors.Total,0.0)=0.0 THEN 0 ELSE Labors.Total END 
		,CASE WHEN ISNULL(Labors.Total,0.0)=0.0 THEN 0 ELSE Labors.Total/MatsInfo.ActualProduction END 
		,CASE WHEN ISNULL(Labors.Total,0.0)=0.0 THEN SUM(MatsInfo.ConsumedQuantity*MatsInfo.Price) ELSE Labors.Total+SUM(MatsInfo.ConsumedQuantity*MatsInfo.Price) END 
		,CASE WHEN ISNULL(Labors.Total,0.0)=0.0 THEN (SUM(MatsInfo.ConsumedQuantity*MatsInfo.Price)/MatsInfo.ActualProduction) ELSE (SUM(MatsInfo.ConsumedQuantity*MatsInfo.Price)/MatsInfo.ActualProduction)+(Labors.Total/MatsInfo.ActualProduction) END
	FROM Joc_Vw_JobOrderStages AS ST
	LEFT JOIN (SELECT SUM(Total) AS Total,StagegUID FROM vwJobOrderEmployeeDetails WHERE JobOrder=@JobOrderGuid GROUP BY StagegUID ) AS Labors ON Labors.StagegUID=ST.GUID  
	LEFT JOIN RawMaterialDeviation(@JobOrderGuid) AS MatsInfo ON  MatsInfo.StageGuid=ST.GUID
	WHERE ST.JobOrder=@JobOrderGuid -- AND MatsInfo.StageGuid=Labors.StagegUID
	GROUP BY 
	ST.GUID
	,ST.Name
	,ST.LatinName
	,MatsInfo.ActualProduction
	,Labors.Total

SELECT * FROM #Result
#############################################################################
CREATE FUNCTION JocFnIsMaterialUsedInBill (@JobOrderGuid UNIQUEIDENTIFIER)
RETURNS TABLE
AS
RETURN	(
			SELECT TOP 1 Bill.buGUID FROM vwBuBi Bill
			INNER JOIN JocVwJobOrder JobOrder ON Bill.buCustAcc = JobOrder.JobOrderAccount
			WHERE JobOrder.JobOrderGuid = @JobOrderGuid 
			AND (JobOrder.ManufactoryMatRequestBillType = Bill.buType OR JobOrder.ManufactoryOutTransBillType = Bill.buType)
		)

#############################################################################

CREATE FUNCTION JocFnGetJobOrderOutSerialNumbers (@JobOrderGuid UNIQUEIDENTIFIER, @MaterialGuid UNIQUEIDENTIFIER)
RETURNS TABLE
AS
RETURN	(
			SELECT SerialNumbers.[guid], SerialNumbers.sn FROM vcSNs SerialNumbers
			INNER JOIN 
			((SELECT [Guid], [Bill], JobOrder FROM DirectMatRequestion000) UNION (SELECT [Guid], InBill AS Bill, Dest AS JobOrder FROM JocTrans000)) AS tbl 
				ON SerialNumbers.buGuid = tbl.Bill

			WHERE tbl.JobOrder = @JobOrderGuid
			AND SerialNumbers.MatGuid = @MaterialGuid
		)
#############################################################################

CREATE FUNCTION JocFnGetRequestionSerialNumbers (@JobOrderGuid UNIQUEIDENTIFIER, @MaterialGuid UNIQUEIDENTIFIER, @StoreGuid UNIQUEIDENTIFIER)
RETURNS TABLE
AS
RETURN	(
			SELECT [GUID], [SN] FROM fncSN(@MaterialGuid, @StoreGuid, '') SerialNumbers
			WHERE SerialNumbers.Guid NOT IN (SELECT [GUID] FROM JocFnGetJobOrderOutSerialNumbers(@JobOrderGuid, @MaterialGuid))
		)
#############################################################################

CREATE FUNCTION JocfnGetTranstMaterialSerialNumbers (@MaterialGuid UNIQUEIDENTIFIER, @SrcJobOrderGuid UNIQUEIDENTIFIER, @DestJobOrderGuid UNIQUEIDENTIFIER)
RETURNS TABLE
AS
RETURN  (	
			SELECT SerialNumbers.guid, SerialNumbers.sn FROM vcSNs SerialNumbers
			INNER JOIN snc000 snc ON snc.GUID = SerialNumbers.guid
			INNER JOIN JOCvwJobOrderRequestionAndOutTrans RequestionAndTrans ON RequestionAndTrans.Bill = SerialNumbers.buGuid
			WHERE RequestionAndTrans.JobOrder = @SrcJobOrderGuid
			AND SerialNumbers.MatGuid = @MaterialGuid
			AND SerialNumbers.guid NOT IN (SELECT guid FROM JocFnGetJobOrderOutSerialNumbers(@DestJobOrderGuid, @MaterialGuid))
			AND SerialNumbers.guid NOT IN (SELECT vcSNs.guid from vcSNs INNER JOIN (SELECT Bill FROM 
																					DirectMatReturn000 MatReturn 
																					WHERE MatReturn.JobOrder = @SrcJobOrderGuid
																					UNION ALL
																					SELECT InBill AS Bill FROM JocTrans000 
																					WHERE JocTrans000.Src = @SrcJobOrderGuid) AS ReturnAndTrans
																					ON vcSNs.buGuid = ReturnAndTrans.Bill)
		)
#############################################################################
CREATE PROC JOCprcIsTransSerialNumberValid 
@DestJobOrderGuid UNIQUEIDENTIFIER, 
@MaterialGUid UNIQUEIDENTIFIER, 
@SerialNumber NVARCHAR(100)
AS

SET NOCOUNT ON
	
	SELECT SerialNumbers.[guid], SerialNumbers.sn FROM vcSNs SerialNumbers
	INNER JOIN JocTrans000 JocTrans ON SerialNumbers.buGuid = JocTrans.OutBill
	WHERE SerialNumbers.MatGuid = @MaterialGuid
	AND SerialNumbers.buGuid IN ((SELECT Bill FROM DirectMatReturn000) UNION (SELECT InBill FROM JocTrans000))
	AND SerialNumbers.sn = @SerialNumber
	AND JocTrans.Dest = @DestJobOrderGuid

#############################################################################
CREATE FUNCTION JOCfnGetManufactoriesTbl (@Count INT)
RETURNS TABLE
RETURN
	(
		SELECT TOP (@Count) * FROM Manufactory000
		ORDER BY Number
	)
#############################################################################
CREATE PROC JOCDeleteJobOrderRelatedBills
(
	@JobOrderAccount UNIQUEIDENTIFIER,
	@JobOrderCostCenter UNIQUEIDENTIFIER,
	@JobOrderBranch UNIQUEIDENTIFIER

)
AS

		Update  bu000 set IsPosted = 0 where bu000.CustAccGUID = @JobOrderAccount and 
		        bu000.CostGUID = @JobOrderCostCenter and bu000.Branch = @JobOrderBranch
		DELETE FROM bu000  where bu000.CustAccGUID = @JobOrderAccount and 
		        bu000.CostGUID = @JobOrderCostCenter and bu000.Branch = @JobOrderBranch
#############################################################################

CREATE PROC JOCprcGetJobOrderCostBills
@JobOrderAccGuid			UNIQUEIDENTIFIER
AS
SET NOCOUNT ON;

SELECT bu.[buGUID] AS [GUID] FROM vwBu bu
INNER JOIN JocVwJobOrder JobOrder ON bu.buCustAcc = JobOrder.JobOrderAccount
WHERE bu.buCustAcc = @JobOrderAccGuid
AND bu.buType <> JobOrder.ManufactoryFinishedGoodsBillType

#############################################################################

CREATE PROC JOCprcGetJobOrders
@ManufatcoryGuid UNIQUEIDENTIFIER = 0x0
,@ProductionLineGuid UNIQUEIDENTIFIER = 0x0
,@BOMGuid			UNIQUEIDENTIFIER = 0x0
,@StartPEriod		DATETIME
,@EndPeriod			DATETIME
,@IsActive			INT -- 0 Isfinished , 1 unfinished, 2 both
AS

SET NOCOUNT ON;

SELECT JobOrder.JobOrderGuid, JobOrder.JobOrderName, joborder.JobOrderStartDate, joborder.JobOrderEndDate, DATEADD(d, -1, DATEADD(m, DATEDIFF(m, 0, @EndPeriod) + 1, 0)) FROM JocVwJobOrder JobOrder 
INNER JOIN JOCJobOrderOperatingBOM000 bom ON JobOrder.JobOrderOperatingBOM = bom.Guid
WHERE (JobOrder.JobOrderManufactoryGuid = @ManufatcoryGuid OR @ManufatcoryGuid = 0x0)
AND (JobOrder.JobOrderProductionLine = @ProductionLineGuid OR @ProductionLineGuid = 0x0)
AND (JobOrder.JobOrderBOM = @BOMGuid OR @BOMGuid = 0x0)
AND (JobOrder.JobOrderStartDate >= (DATEADD(month, DATEDIFF(month, 0, @StartPEriod), 0)))
AND (JobOrder.JobOrderEndDate <= (DATEADD(d, -1, DATEADD(m, DATEDIFF(m, 0, @EndPeriod) + 1, 0))))
AND (JobOrder.JobOrderStatus = CASE WHEN  @IsActive = 1 OR @IsActive = 0 THEN @IsActive ELSE JobOrderStatus END) --0 Finished 1 Is not finished
ORDER BY bom.CostRank


#############################################################################
CREATE FUNCTION fn_CheckExistingJobOrderUsingBOMProductionLine
(@ProductionLine uniqueidentifier,@BOMGuid uniqueidentifier)
RETURNS TABLE
AS
RETURN (
		 SELECT JO.* FROM JobOrder000 AS JO 
		 INNER JOIN JOCJobOrderOperatingBOM000 AS BOMI
		 ON BOMI.Guid=JO.OperatingBOMGuid
		 WHERE 
		 BOMI.BOMGuid=@BOMGuid
		 AND
		 JO.ProductionLine=@ProductionLine
		 AND 
		 BOMI.UseStages=1
		)
#############################################################################

CREATE PROC JOCprcGetTransItems
@TransGuid UNIQUEIDENtIFIER
AS
SET NOCOUNT ON
DECLARE @Source UNIQUEIDENTIFIER = (SELECT Src FROM JocTrans000 WHERE [Guid] =	@TransGuid)
DECLARE @Dest UNIQUEIDENTIFIER = (SELECT Dest FROM JocTrans000 WHERE [Guid] = @TransGuid)
CREATE TABLE #Result
(
	 MaterialGuid		UNIQUEIDENTIFIER
	 ,biGuid			UNIQUEIDENTIFIER
	 ,MaterialCode		NVARCHAR(250)
	 ,MaterialName		NVARCHAR(250)
	 ,MaterialLatinname	NVARCHAR(250)
	 ,Unit				FLOAT
	 ,UnitName			NVARCHAR(250)
	 ,UnitFactor		FLOAT
	 ,SNFlag			BIT
	 ,ExpireFlag		BIT
	 ,ClassFlag			BIT
	 ,NetQty			FLOAT
	 ,SrcStage			UNIQUEIDENTIFIER
	 ,TransDestStage	UNIQUEIDENTIFIER
	 ,Qty				FLOAT
	 ,ExpireDate		DATETIME
	 ,ClassPtr			NVARCHAR(250)
	 ,SourceJobOrder	UNIQUEIDENTIFIER
	 ,DestJobOrder		UNIQUEIDENTIFIER
	 ,TransGuid			UNIQUEIDENTIFIER
	 ,BomIndex			INT
	 ,HasAlterMat		BIT
)
INSERT INTO #Result
SELECT 
materials.MaterialGuid
,0x0
,materials.MaterialCode
,materials.MaterialName
,materials.MaterialLatinName
,materials.Unit
,materials.UnitName
,materials.UnitFactor
,materials.SNFlag
,materials.ExpireFlag
,materials.ClassFlag
,materials.NetQty
,materials.StageGuid
,0x0
,0
,'1-1-1980'
,''
,@Source
,@Dest
,@TransGuid
,materials.BomIndex
,materials.HasAlterMat
FROM JOCvwJobOrderTransItems materials
WHERE materials.Source = @Source AND materials.Dest = @Dest
SELECT items.* 
INTO #transBillItems
FROM JOCvwOutTransItems items
WHERE items.TransGuid = @TransGuid
UPDATE result 
SET 
result.Qty =			ISNULL(items.Qty, result.Qty)
,result.Unit =			ISNULL(items.Unit, result.Unit)
,result.UnitName =		ISNULL(items.UnitName, result.UnitName)
,result.UnitFactor =	ISNULL(items.UnitFactor, result.UnitFactor)
,result.ExpireDate =	ISNULL(items.ExpireDate, '1-1-1980')
,result.ClassPtr =		ISNULL(items.ClassPtr, result.ClassPtr)
,result.TransDestStage= ISNULL(items.DestStageGuid, 0x0)
,result.biGuid =		ISNULL(items.biGuid, 0x0)
FROM #Result result
LEFT JOIN #transBillItems items ON result.MaterialGuid = items.MaterialGuid AND result.SrcStage = items.SrcStageGuid

SELECT * FROM #Result ORDER BY BomIndex

#############################################################################

CREATE FUNCTION JOCfnGetJobOrderStages(@JobOrderGuid UNIQUEIDENTIFIER, @MaterialGuid UNIQUEIDENTIFIER)
RETURNS TABLE
AS
RETURN (
		SELECT
		materials.StageGuid AS [Guid]
		,materials.StageName
		,Stages.LatinName AS StageLatinName
		FROM
		JOCvwJobOrderRawMaterialsQuantities materials
		INNER JOIN JOCStages000 Stages ON Stages.GUID = materials.StageGuid
		WHERE
		materials.JobOrderGuid = @JobOrderGuid
		AND materials.MaterialGuid = @MaterialGuid
		)

#############################################################################

CREATE FUNCTION Joc_Fn_GetQtyWithChoosenUnit(
@ProductionQty		  FLOAT
,@QtyUnit			  INT
,@MatGuid			  UNIQUEIDENTIFIER
,@SelectedUnit		  INT
,@ProdToUnitConvFact  FLOAT
,@ProdMatUnit		  INT
)

RETURNS FLOAT
BEGIN
	IF @SelectedUnit = 0 OR @SelectedUnit = 1 OR @SelectedUnit =2
		RETURN (@ProductionQty/ dbo.JOCfngetMaterialUnitFactor(@MatGuid, @QtyUnit))* (CASE WHEN dbo.JOCfngetMaterialUnitFactor(@MatGuid, @SelectedUnit)=0 THEN dbo.JOCfngetMaterialUnitFactor(@MatGuid, 1) ELSE dbo.JOCfngetMaterialUnitFactor(@MatGuid, @SelectedUnit) END )
	ELSE IF @SelectedUnit = 4 OR @SelectedUnit = 5 
		RETURN(((@ProductionQty/ dbo.JOCfngetMaterialUnitFactor(@MatGuid, @QtyUnit))*dbo.JOCfngetMaterialUnitFactor(@MatGuid, @ProdMatUnit))/@ProdToUnitConvFact)

		RETURN(((@ProductionQty/ dbo.JOCfngetMaterialUnitFactor(@MatGuid, @QtyUnit))*dbo.JOCfngetMaterialUnitFactor(@MatGuid,(SELECT DefUnit FROM mt000 WHERE GUID=@MatGuid))))
END

#############################################################################
CREATE PROCEDURE Joc_SP_TotalRawMaterialDeviation
	@BOM				  UNIQUEIDENTIFIER,
	@MatGroup			  UNIQUEIDENTIFIER,
	@StageGuid			  UNIQUEIDENTIFIER,
	@Manufactory		  UNIQUEIDENTIFIER,
	@ProductionLine		  UNIQUEIDENTIFIER,
	@StartDate			  DATE,
	@EndDate			  DATE

AS
SET NOCOUNT ON
	---------------------------------------------
	CREATE TABLE #Result
	(
		MatName					 NVARCHAR(250),
		MatLatinName			 NVARCHAR(250),
		MatCode					 NVARCHAR(100),
		MatGuid					 UNIQUEIDENTIFIER,
		ManufactoryGuid			 UNIQUEIDENTIFIER,
		GroupName				 NVARCHAR(250),
		GroupLatinName			 NVARCHAR(250),
		GroupCode				 NVARCHAR(100),
		GroupGuid				 UNIQUEIDENTIFIER,
		UnitName				 NVARCHAR(100),
		ProductionUnit			 NVARCHAR(100),
		ActualProductionQty		 FLOAT,
		StandardQty				 FLOAT,
		ConsumedQty				 FLOAT,
		StandardQtyByProductionUnit	FLOAT,
		ConsumedQtyByProductionUnit	FLOAT,
		QuantamDeviation		 FLOAT,
		QuantamDeviationInUnit	 FLOAT,
		DeviationRatio			 FLOAT,
		StandardValue			 FLOAT,
		ConsumedValue			 FLOAT,
		StandardValueByProductionUnit	FLOAT,
		ConsumedValueByProductionUnit	FLOAT,
		DeviationValue			 FLOAT,
		DeviationValueInUnit	 FLOAT,
		PercentageDeviationValue FLOAT,
		Price					 FLOAT,
		StageName				NVARCHAR(250)
	)
	---------------------------------------------
	CREATE TABLE #TempResult --MATERIALS EXIST MARE THAN ONE TIME ACCORDING TO JOBORDER
	(
		MatName					 NVARCHAR(250),
		MatLatinName			 NVARCHAR(250),
		MatCode					 NVARCHAR(100),
		MatGuid					 UNIQUEIDENTIFIER,
		ManufactoryGuid			 UNIQUEIDENTIFIER,
		GroupName				 NVARCHAR(250),
		GroupLatinName			 NVARCHAR(250),
		GroupCode				 NVARCHAR(100),
		GroupGuid				 UNIQUEIDENTIFIER,
		UnitName				 NVARCHAR(100),
		ProductionUnit			 NVARCHAR(100),
		ActualProductionQty		 FLOAT,
		StandardQty				 FLOAT,
		ConsumedQty				 FLOAT,
		Price					 FLOAT,
		StageName				NVARCHAR(250)
	)
	---------------------------------------------

	INSERT INTO #TempResult
		SELECT 
			 materials.MatName
			,materials.MatLatinName
			,materials.Code
			,materials.GUID
			,manufact.Guid
			,MaterialGr.Name
			,MaterialGr.LatinName
			,MaterialGr.Code
			,MaterialGr.GUID
			,MatsQty.UnitName
			,Unit.Name
			,(SELECT SUM(Qty) FROM JOCfnGetJobOrderTotalProductsQtys(MatsQty.JobOrderGuid, 1))
			,(CASE MatsQty.DistMethod  
				WHEN 0 THEN (SELECT SUM(StandardQuantity) FROM  JOCfngetStandardQty(MatsQty.MaterialGuid, MatsQty.JobOrderGuid, MatsQty.StageGuid)) 
				ELSE StanderdQty.TotalStandardQuantity 
			 END )
			,(MatBill.TotalOutQty - MatBill.TotalInQty) * MatsQty.UnitFactor
			,(CASE WHEN MatsQty.BOMNetQty=0 THEN 0 ELSE(MatsQty.NetExchange) END)
			,MatsQty.StageName
		FROM JOCvwJobOrderRawMaterialsQuantities AS MatsQty
			INNER JOIN JocVwMaterialsWithAlternatives materials ON materials.GUID = MatsQty.MaterialGuid
			INNER JOIN gr000 AS MaterialGr  ON MaterialGr.GUID = materials.GroupGUID
			INNER JOIN Manufactory000 AS manufact ON manufact.GUID = MatsQty.JobOrderManufactoryGuid
			INNER JOIN JOCProductionUnit000 Unit ON Unit.GUID = manufact.UsedProductionUnit
			INNER JOIN JOCvwBillItemsQtys MatBill ON MatBill.MaterialGuid = MatsQty.MaterialGuid and MatsQty.JobOrderGuid = MatBill.JobOrderGuid and MatBill.StageGuid = MatsQty.StageGuid
			INNER JOin JOCvwJobOrderTotalProductsStandardQuantity StanderdQty ON StanderdQty.RawMaterialGuid = MatsQty.MaterialGuid and StanderdQty.JobOrderGuid = StanderdQty.JobOrderGuid and StanderdQty.StageGuid = MatsQty.StageGuid
			INNER JOIN JOCBOM000 AS BOM ON BOM.GUID = MatsQty.JobOrderBOM
		WHERE
			MatsQty.JobOrderStatus=0
			AND
			@BOM=CASE WHEN  ISNULL (@BOM,0x0)=0x0  THEN 0x0 ELSE BOM.GUID  END
			AND
			@MatGroup=CASE WHEN  ISNULL (@MatGroup,0x0)=0x0  THEN 0x0 ELSE MaterialGr.GUID END
			AND
			@StageGuid=CASE WHEN  ISNULL (@StageGuid,0x0)=0x0  THEN 0x0 ELSE MatsQty.StageGuid END
			AND
			@Manufactory=CASE WHEN  ISNULL (@Manufactory,0x0)=0x0  THEN 0x0 ELSE MatsQty.JobOrderManufactoryGuid END
			AND
			@ProductionLine=CASE WHEN  ISNULL (@ProductionLine,0x0)=0x0  THEN 0x0 ELSE MatsQty.JobOrderProductionLine END
			AND 
			MatsQty.JobOrderEndDate >= @StartDate AND MatsQty.JobOrderEndDate <= @EndDate
		GROUP BY 
			materials.MatName
			,materials.MatLatinName
			,materials.Code
			,materials.GUID
			,MaterialGr.Name
			,MaterialGr.LatinName
			,MaterialGr.Code
			,MaterialGr.GUID
			,MatsQty.JobOrderGuid
			,MatsQty.StageName
			,MatsQty.UnitName
			,Unit.Name
			,Unit.Number
			,MatsQty.UnitFactor
			,StanderdQty.TotalStandardQuantity
			,MatsQty.MaterialGuid
			,MatsQty.StageGuid
			,MatsQty.DistMethod 
			,MatBill.TotalOutQty 
			,MatBill.TotalInQty
			,MatsQty.BOMNetQty
			,MatsQty.NetExchange
			,manufact.Guid
			-------------------------------------------------------
	INSERT INTO #Result
		SELECT 
			 MatName
			,MatLatinName
			,MatCode
			,MatGuid
			,ManufactoryGuid
			,GroupName
			,GroupLatinName
			,GroupCode
			,GroupGuid
			,UnitName
			,ProductionUnit
			,SUM(ActualProductionQty)
			,SUM(StandardQty) 
			,SUM(ConsumedQty)
			,0
			,0
			,0
			,0
			,0
			,0
			,0
			,0
			,0
			,0
			,0
			,0
			,SUM(Price)
			,StageName
		FROM #TempResult
		GROUP BY 
			 MatName
			,MatLatinName
			,MatCode
			,MatGuid
			,GroupName
			,GroupLatinName
			,GroupCode
			,GroupGuid
			,UnitName
			,StageName
			,ProductionUnit
			,ManufactoryGuid
			-------------------------------------------------------
	UPDATE Result SET QuantamDeviation = (CASE WHEN abs(Result.ConsumedQty- Result.StandardQty) > 10.e-9  Then Result.ConsumedQty- Result.StandardQty ELSE 0 END)
					  ,QuantamDeviationInUnit = (CASE WHEN abs(Result.ConsumedQty- Result.StandardQty) > 10.e-9  Then Result.ConsumedQty- Result.StandardQty ELSE 0 END) / Result.ActualProductionQty
					  ,DeviationRatio = ((CASE WHEN abs(Result.ConsumedQty- Result.StandardQty) > 10.e-9  Then Result.ConsumedQty- Result.StandardQty ELSE 0 END) / Result.StandardQty) * 100
					  ,Price=CASE WHEN Price = 0 THEN 0 ELSE(Result.Price / Result.ConsumedQty) END
					  FROM #Result Result

	UPDATE Result SET StandardValue = Result.StandardQty * Result.Price
					  ,ConsumedValue = Result.ConsumedQty * Result.Price
					  ,DeviationValue = Result.QuantamDeviation * Result.Price
					  ,DeviationValueInUnit = (Result.QuantamDeviation * Result.Price) / Result.ActualProductionQty
					  FROM #Result Result

	UPDATE Result SET StandardValueByProductionUnit = Result.StandardValue / Result.ActualProductionQty
					  ,ConsumedValueByProductionUnit = Result.ConsumedValue / Result.ActualProductionQty
					  ,PercentageDeviationValue = (Result.DeviationValue / Result.StandardValue)
					  ,StandardQtyByProductionUnit = Result.StandardQty / Result.ActualProductionQty
					  ,ConsumedQtyByProductionUnit = Result.ConsumedQty / Result.ActualProductionQty
					  FROM #Result Result
SELECT * FROM #Result
#############################################################################
CREATE FUNCTION JOCfnGetJobOrderNumbers(@MaterialGUid UNIQUEIDENTIFIER, @ManufactoryGuid UNIQUEIDENTIFIER, @ProductionLineGuid UNIQUEIDENTIFIER
										, @BOMGuid UNIQUEIDENTIFIER ,
										@StageGuid UNIQUEIDENTIFIER, @StartDate DATETIME, @EndDate DATETIME)
RETURNS INT
AS
BEGIN
	RETURN  (
			SELECT COUNT( DISTINCT JobOrder.JobOrderGuid)
			FROM JOCvwJobOrderRawMaterialsQuantities materials
			INNER JOIN JocVwJobOrder JobOrder ON materials.JobOrderGuid = JobOrder.JobOrderGuid
			WHERE materials.MaterialGuid = @MaterialGuid
			AND (materials.StageGuid = @StageGuid OR @StageGuid = 0x0)
			AND (JobOrder.JobOrderManufactoryGuid = @ManufactoryGuid OR @ManufactoryGuid = 0x0)
			AND (JobOrder.JobOrderBOM = @BOMGuid OR @BOMGuid = 0x0)
			AND (JobOrder.JobOrderProductionLine = @ProductionLineGuid OR @ProductionLineGuid = 0x0)
			AND (JobOrder.JobOrderEndDate BETWEEN @StartDate AND @EndDate)
			AND (JobOrder.JobOrderStatus = 0)
			GROUP BY materials.MaterialGuid
			)
END
#############################################################################

CREATE PROC JOCprcRawMaterialDeviationsRpt
@MaterialGuid			UNIQUEIDENTIFIER
,@BOMGuid				UNIQUEIDENTIFIER = 0x0
,@ManufactoryGuid		UNIQUEIDENTIFIER = 0x0
,@ProductionLineGuid	UNIQUEIDENTIFIER = 0x0
,@StageGuid				UNIQUEIDENTIFIER = 0x0
,@StartDate				DATETIME
,@EndDate				DATETIME
,@RawMaterialUnit		INT
,@ProductUnit			INT
AS

SET NOCOUNT ON;

DECLARE @RawMaterialUnitFactor FLOAT = (SELECT dbo.JOCfngetMaterialUnitFactor(@MaterialGuid, CASE WHEN @RawMaterialUnit = 3 THEN (SELECT DefUnit FROM mt000 WHERE guid = @MaterialGuid) ELSE  @RawMaterialUnit + 1 END))

CREATE TABLE #Result
(
	ManufactoryName				NVARCHAR(250)
	,ManufactoryLatinName		NVARCHAR(250)
	,ProductionLineName			NVARCHAR(250)
	,ProductionLatinName		NVARCHAR(250)
	,JobOrderStartDate			DATETIME
	,JobOrderGuid				UNIQUEIDENTIFIER
	,JobOrderNumber				INT
	,JobOrderName				NVARCHAR(250)
	,BOMName					NVARCHAR(250)
	,BOMLatinName				NVARCHAR(250)
	,StageName					NVARCHAR(250)
	,ActualProduction			FLOAT
	,ActualProductionUnit		NVARCHAR(50)
	,StandardQty				FLOAT
	,NetQty						FLOAT
	,DeviationAmount			FLOAT
	,DeviationPercentageAmount	FLOAT
	,Price						FLOAT
	,StandardValue				FLOAT
	,NetExchange				FLOAT
	,DeviationValue				FLOAT
	,DeviationPercentageValue	FLOAT
	,RateOfDeviationAmount		FLOAT
	,RateOfDeviationValue		FLOAT
)


INSERT INTO #Result
SELECT 
JobOrder.ManufactoryName 
,JobOrder.ManufactoryLatinName
,JobOrder.ProductionLineName
,JobOrder.ProductionLineLatinName
,JobOrder.JobOrderStartDate
,JobOrder.JobOrderGuid
,JobOrder.JobOrderNumber
,JobOrder.JobOrderName
,JobOrder.BOMName
,JobOrder.BOMLatinName
,materials.StageName
,1--(dbo.JOCfnGetBOMActualProduction(JobOrder.JobOrderGuid, bom.MatPtr, @ProductUnit)) --ÇáÅäÊÇÌ ÇáÝÚáí
,1--dbo.JOCfnGetProdComboUnitName(@ProductUnit, JobOrder.JobOrderManufactoryGuid, bom.MatPtr)  --æÍÏÉ ÇáÅäÊÇÌ
,(materials.RawMatQty1 / @RawMaterialUnitFactor) * (JobOrder.JobOrderReplicasCount ) --ÇáßãíÉ ÇáãÚíÇÑíÉ
,materials.NetQty / @RawMaterialUnitFactor --ÇáßãíÉ ÇáãÕÑæÝÉ Ãæ ÇáãÓÊåáßÉ
,0 --ÇáÇäÍÑÇÝ
,0 --ÇáÇäÍÑÇÝ%
,materials.NetExchange / (materials.NetQty / @RawMaterialUnitFactor) --ÇáÓÚÑ
,0   --ÇáÞíãÉ ÇáãÚíÇÑíÉ
,(materials.NetExchange) / @RawMaterialUnitFactor --ÇáÞíãÉ ÇáãÕÑæÝÉ
,0 --ÞíãÉ ÇáÇäÍÑÇÝ
,0  --ÞíãÉ ÇáÇäÍÑÇÝ%
,0 --ßãíÉ ÇáÇäÍÑÇÝ È ÇáæÍÏÉ
,0 --ÞíãÉ ÇáÇäÍÑÇÝ È ÇáæÍÏÉ
FROM JOCvwJobOrderRawMaterialsQuantities materials 
INNER JOIN JocVwJobOrder JobOrder ON materials.JobOrderGuid = JobOrder.JobOrderGuid
INNER JOIN JOCBOM000 bom ON JobOrder.JobOrderBOM = bom.GUID
WHERE 
(materials.MaterialGuid = @MaterialGuid OR @ManufactoryGuid = 0x0)
AND (materials.StageGuid = @StageGuid OR @StageGuid = 0x0)
AND (JobOrder.JobOrderManufactoryGuid = @ManufactoryGuid OR @ManufactoryGuid = 0x0)
AND (JobOrder.JobOrderBOM = @BOMGuid OR @BOMGuid = 0x0)
AND (JobOrder.JobOrderProductionLine = @ProductionLineGuid OR @ProductionLineGuid = 0x0)
AND (JobOrder.JobOrderEndDate BETWEEN @StartDate AND @EndDate)
AND (JobOrder.JobOrderStatus = 0)

UPDATE result 
SET 
result.DeviationAmount =NetQty- StandardQty 
,result.DeviationPercentageAmount = ((NetQty- StandardQty) / StandardQty)*100
,result.StandardValue =  StandardQty * Price
,result.NetExchange = NetQty*Price
FROM #Result result 

UPDATE result 
SET 
result.DeviationValue =  NetExchange-StandardValue
,result.DeviationPercentageValue = (( NetExchange-StandardValue) / StandardValue)*100
,result.RateOfDeviationAmount =  DeviationAmount / ActualProduction
,result.RateOfDeviationValue = (NetExchange - StandardValue ) / ActualProduction
FROM #Result result 

select * from #Result
#############################################################################
CREATE FUNCTION JOC_FN_GetMainStageForMaterialBOM(@MaterialGuid UNIQUEIDENTIFIER , @Lang INT)
RETURNS TABLE
AS 
RETURN (SELECT TOP 1  CASE WHEN  @Lang=1 THEN ST.LatinName ELSE ST.Name END AS StageName FROM JOCBOM000 AS BOM 
INNER JOIN JOCBOMStages000 AS BOMST ON BOMST.JOCBOMGuid=BOM.GUID
INNER JOIN JOCProductionLineStages000 AS PRST ON PRST.StageGuid=BOMST.StageGuid
INNER JOIN JOCStages000 AS ST ON ST.GUID=PRST.StageGuid
WHERE BOM.MatPtr=@MaterialGuid
AND 
PRST.SerialOrder=0 ) 
#############################################################################
CREATE FUNCTION fn_GetManufactoriesNamesUsedBom(@BOMGuid UNIQUEIDENTIFIER,@ManufactoryUnit INT,@Lang INT)
RETURNS TABLE
AS
RETURN ( 
		 SELECT DISTINCT CASE WHEN @Lang= 1 AND NOT ISNULL( MN.LatineName,'')='' THEN MN.LatineName ELSE MN.NAME END  AS ManufactoryName from Manufactory000 MN
		 INNER JOIN JobOrder000 AS JO ON JO.ManufactoryGUID=MN.Guid
		 INNER JOIN JOCBOM000 AS BOM ON BOM.GUID=JO.FormGuid
		 WHERE BOM.GUID=@BOMGuid
		 AND MN.MohAllocationBase=0 --ÇÓÇÓ ÊæÒíÚ ÇáäÝÞÇÊ åæ ßãíÉ ÇáÇäÊÇÌ
		 AND MN.UsedProductionUnit= (CASE WHEN @ManufactoryUnit =1 THEN MN.ProductionUnitOne ELSE MN.ProductionUnitTwo END )

		)
#############################################################################
CREATE FUNCTION fn_GetSearchedJobOrder(@ManufactoryGuid UNIQUEIDENTIFIER,@Status BIT)
RETURNS TABLE
AS
RETURN ( 
		 SELECT * from JobOrder000 JO
		 WHERE (ManufactoryGUID = @ManufactoryGuid AND IsActive = CASE WHEN  @Status = 1 THEN 1 ELSE JO.IsActive END ) OR (@ManufactoryGuid = 0x0) 
		)

#############################################################################

CREATE PROCEDURE  MatItemsCountInJobOrderBills
		@JobOrder 					UNIQUEIDENTIFIER = 0x0 ,
		@matGuid                    UNIQUEIDENTIFIER = 0x0 , 
		@stageGuid                  UNIQUEIDENTIFIER = 0x0 
AS 
SET NOCOUNT ON 
    
select TotalOutQty from JOCvwJobOrderRawMaterialsQuantities 
WHERE JobOrderGuid = @JobOrder and MaterialGuid = @matGuid
and  (@stageGuid= 0x0 or StageGuid = @stageGuid)
#############################################################################
CREATE PROC JOCprcGetBOMMaterialHierarchy
@FinishedGoodGuid UNIQUEIDENTIFIER = 0x0
AS
-- íÞæã ÈÅÑÌÇÚ ÇáãæÇÏ ÇáÃæáíÉ ÇáÏÇÎáíÉ Ýí ÕäÚ ÇáãÇÏÉ ÇáãäÊÌÉ ÇáãÍÏÏÉ
SET NOCOUNT ON;

With
CTE(MaterialGuid, [Level])
AS
(
	SELECT DISTINCT MatPtr ,1
	FROM JOCBOMFinishedGoods000 vwMaterials
	where vwMaterials.MatPtr = @FinishedGoodGuid

	UNION ALL

	SELECT  vwMaterials.rawMaterialGuid, cte.[Level] + 1
	FROM JOCvwFinishedGoodsAndRawMaterials vwMaterials
	INNER JOIN CTE ON vwMaterials.finishedGoodGuid = CTE.MaterialGuid
)

 SELECT DISTINCT mt.GUID, mt.Name, CTE.[Level] AS [Level] FROM CTE inner join mt000 mt ON mt.GUID = CTE.MaterialGuid

#############################################################################
CREATE PROC JOCprcGetBOMMaterialSpoilageHierarchy
@FinishedGoodGuid UNIQUEIDENTIFIER = 0x0
AS
--íÞæã ÈÅÑÌÇÚ ÇáãæÇÏ ÇáÃæáíÉ ÇáÏÇÎáÉ Ýí ÕäÇÚÉ ãÇÏÉ ÇáÊáÝ ÇáãÍÏÏÉ
SET NOCOUNT ON;
With
CTE(MaterialGuid, [Level])
AS
(
	SELECT DISTINCT  SpoilageMaterial 
	,1
	FROM JOCBOMSpoilage000 vwMaterials
	where vwMaterials.FinishedProductGuid = @FinishedGoodGuid OR vwMaterials.SpoilageMaterial = @FinishedGoodGuid
	UNION ALL
	SELECT  vwMaterials.rawMaterialGuid, cte.[Level] + 1
	FROM JOCvwFinishedGoodsAndRawMaterials vwMaterials
	INNER JOIN CTE ON vwMaterials.SpoilageMaterial = CTE.MaterialGuid
)
 SELECT DISTINCT mt.GUID, mt.Name, CTE.[Level] AS [Level] FROM CTE inner join mt000 mt ON mt.GUID = CTE.MaterialGuid
#############################################################################

CREATE FUNCTION JOCfnGetJobOrderTotalProductsQtys(@JobOrderGuid UNIQUEIDENTIFIER, @ProductionUnit INT)
RETURNS TABLE
AS
-- ãÌãæÚ ßãíÇÊ ÇáÅäÊÇÌ ãä ÇáãäÊÌÇÊ ÇáÊÇãÉ Ýí ÃãÑ ÇáÊÔÛíá ÈæÍÏÉ ÇáãÕäÚ
RETURN(
	SELECT
	(CASE @ProductionUnit WHEN 1 THEN SUM(items.FirstProductionUnityQty)
		WHEN 2 THEN SUM(items.SecondProductionUnityQty)
		ELSE SUM(items.Quantity)
	END) AS Qty
	FROM JOCvwJobOrderFinishedGoodsBillItemsQtys items
	WHERE JobOrderGuid = @JobOrderGuid
)

######################################################################
CREATE FUNCTION JOCfnGetJobOrderTotalProductsSellPrice(@JobOrderGuid UNIQUEIDENTIFIER)
RETURNS FLOAT
AS
BEGIN 
	DECLARE @TotalProductsSellPrice FLOAT = (SELECT
	SUM(items.FinishedGoodsSellPrice)
	FROM JOCvwJobOrderFinishedGoodsItemsSellPrice items
	WHERE JobOrderGuid = @JobOrderGuid)

	RETURN  @TotalProductsSellPrice
END
######################################################################
CREATE FUNCTION JOCfnCalcJobOrderDirectLabrs(@JobOrderGuid UNIQUEIDENTIFIER = 0x0, @WithStages BIT = 0)
RETURNS TABLE
AS
RETURN(

SELECT	Workers.[Employee] AS WorkerGuid, 
		(CASE WHEN (@WithStages = 0) THEN 0x00 ELSE StagesDist.[StageGuid] END)AS StageGuid, 
		(CASE WHEN (@WithStages = 0) THEN '' ELSE StagesDist.[StageName] END)AS StageName,
		(CASE WHEN (@WithStages = 0) THEN '' ELSE Stages.[LatinName] END)AS StageLatinName ,
		Workers.[WorkingHourCost] AS WorkingHourCost,
		(CASE	WHEN (@WithStages = 0)
				THEN SUM(Workers.[WorkingHours])
				ELSE SUM(StagesDist.[Hours])
				END) AS TotalWorkingHours,
		(CASE	WHEN (@WithStages = 0)
				THEN (SUM(Workers.[WorkingHours]) * WorkingHourCost)
				ELSE (SUM(StagesDist.[Hours]) * Workers.[WorkingHourCost]) END) AS [DistWorkerLabor]
FROM DirectLaborAllocation000 AS Labors
INNER JOIN DirectLaborAllocationDetail000 AS Workers ON Workers.[JobOrderDistributedCost] = Labors.[Guid]
LEFT JOIN VwJOCWorkHoursDistribution AS StagesDist ON StagesDist.[ParentGuid] = Workers.[Guid]
LEFT JOIN JOCStages000 AS Stages ON Stages.[GUID] = StagesDist.[StageGuid]
WHERE Labors.[JobOrder] = @JobOrderGuid
GROUP BY 
	Workers.[Employee], 
	StagesDist.[StageGuid], 
	StagesDist.[StageName], 
	Stages.[LatinName],
	Workers.[WorkingHourCost]

)

######################################################################

CREATE PROCEDURE prcGetInDirectLaborsDistQty
(	@JobOrderGuid UNIQUEIDENTIFIER,
	@WithStages BIT = 0
)
AS
BEGIN
	SET NOCOUNT ON;

	CREATE TABLE [#WorkersLabors]
    ( 
		[WorkerGuid]		[UNIQUEIDENTIFIER], 
		[StageGuid]			[UNIQUEIDENTIFIER], 
		[StageName]			[NVARCHAR](Max),
		[StageLatinName]	[NVARCHAR](max),
		[WorkingHourCost]	[FLOAT],
		[TotalWorkingHours] [FLOAT],
		[DistWorkerLabor]	[FLOAT]
    )

	INSERT INTO [#WorkersLabors]
		SELECT * FROM [dbo].[JOCfnCalcJobOrderDirectLabrs](@JobOrderGuid, @WithStages)

	DECLARE @ProductionUnit INT

	SELECT  @ProductionUnit =
				(CASE WHEN (Factory.UsedProductionUnit = Factory.ProductionUnitTwo) 
					THEN 2 ELSE 1  END)  
	FROM JobOrder000 AS JobOrder
	INNER JOIN Manufactory000 AS Factory ON  Factory.[Guid] = JobOrder.[ManufactoryGUID]
	WHERE JobOrder.[Guid] = @JobOrderGuid

	DECLARE @TotalQty FLOAT 
	SELECT  @TotalQty = SUM(Qty) FROM [dbo].[JOCfnGetJobOrderTotalProductsQtys] (@JobOrderGuid, @ProductionUnit)

	-------------------------------- Result Table -------------------------------------------------------
	CREATE TABLE [#WorkersIndirectLaborsDist]
	( 
		[DinishedGoodGuid]		[UNIQUEIDENTIFIER], --1
		[WorkerGuid]			[UNIQUEIDENTIFIER], --2
		[StageGuid]				[UNIQUEIDENTIFIER], --3
		[StageName]				[NVARCHAR](Max),	--4
		[StageLatinName]		[NVARCHAR](max),	--5
		[DistWorkerLabor]		[FLOAT],			--6
		[InDirectValue]			[FLOAT],			--7
		[WorkingHourCost]		[FLOAT]				--8
	)

	INSERT INTO [#WorkersIndirectLaborsDist]
		SELECT  MaterialGuid, 
			Labors.[WorkerGuid],
			( Case @WithStages when 1 then Labors.[StageGuid] ELSE 0x00 END), 
			( Case @WithStages when 1 then Labors.[StageName] ELSE '' END),
			( Case @WithStages when 1 then Labors.[StageLatinName] ELSE '' END),
			Labors.[DistWorkerLabor],
			(CASE WHEN @TotalQty = 0 THEN 0 
				WHEN @ProductionUnit = 1 
				THEN ( (ViewQty.FirstProductionUnityQty / @TotalQty) * Labors.[DistWorkerLabor] )
				ELSE ( (ViewQty.SecondProductionUnityQty / @TotalQty) * Labors.[DistWorkerLabor] )
				END) AS InDirectValue,
			Labors.[WorkingHourCost]
		FROM JOCvwJobOrderFinishedGoodsBillItemsQtys AS ViewQty
		CROSS JOIN [#WorkersLabors] AS Labors
		WHERE JobOrderGuid =  @JobOrderGuid
	---------------------------------------------------------------------------------------------------

	SELECT * FROM [#WorkersIndirectLaborsDist]

	DROP TABLE [#WorkersLabors]
	DROP TABLE [#WorkersIndirectLaborsDist]

END
######################################################################

CREATE PROCEDURE prcGetInDirectLaborsDistPrice
(	@JobOrderGuid UNIQUEIDENTIFIER,
	@WithStages BIT = 0
)
AS
BEGIN
	SET NOCOUNT ON;

	CREATE TABLE [#WorkersLabors]
    ( 
		[WorkerGuid]		[UNIQUEIDENTIFIER], 
		[StageGuid]			[UNIQUEIDENTIFIER], 
		[StageName]			[NVARCHAR](Max),
		[StageLatinName]	[NVARCHAR](max),
		[WorkingHourCost]	[FLOAT],
		[TotalWorkingHours] [FLOAT],
		[DistWorkerLabor]	[FLOAT]
    )

	INSERT INTO [#WorkersLabors]
		SELECT * FROM [dbo].[JOCfnCalcJobOrderDirectLabrs](@JobOrderGuid, @WithStages)
		
		
	CREATE TABLE [#FinishedGoodsSellPrices]
	(
		FinishedGoodsGuid		[UNIQUEIDENTIFIER], 
		OperatingBOMGuid		[UNIQUEIDENTIFIER], 
		FinishedGoodsSellPrice	[FLOAT]
	)

	INSERT INTO [#FinishedGoodsSellPrices]
		SELECT	SellPrices.[FinishedGoodsGuid],
				SellPrices.[OperatingBOMGuid],
				SellPrices.[FinishedGoodsSellPrice]
		FROM JOCvwJobOrderFinishedGoodsItemsSellPrice as SellPrices
		WHERE SellPrices.[JobOrderGuid] = @JobOrderGuid
		
	DECLARE @TotalSellPrice FLOAT
	SET @TotalSellPrice = dbo.JOCfnGetJobOrderTotalProductsSellPrice(@JobOrderGuid)

	CREATE TABLE [#WorkersLaborsSellPriceDist]
	( 
		[DinishedGoodGuid]		[UNIQUEIDENTIFIER], 
		[WorkerGuid]			[UNIQUEIDENTIFIER], 
		[StageGuid]				[UNIQUEIDENTIFIER], 
		[StageName]				[NVARCHAR](Max),
		[StageLatinName]		[NVARCHAR](max),
		[DistWorkerLabor]		[FLOAT],
		[InDirectValue]			[FLOAT],
		[WorkingHourCost]		[FLOAT]
	)
	
	INSERT INTO [#WorkersLaborsSellPriceDist]
		SELECT  MaterialGuid, 
			Labors.[WorkerGuid],
			( Case @WithStages when 1 then Labors.[StageGuid] ELSE 0x00 END), 
			( Case @WithStages when 1 then Labors.[StageName] ELSE '' END),
			( Case @WithStages when 1 then Labors.[StageLatinName] ELSE '' END),
			Labors.[DistWorkerLabor],
			(0) AS InDirectValue,
			Labors.[WorkingHourCost]
	FROM JOCvwJobOrderFinishedGoodsBillItemsQtys AS ViewQty 
	CROSS JOIN [#WorkersLabors] AS Labors
	WHERE JobOrderGuid =  @JobOrderGuid
	
	IF(@TotalSellPrice != 0)
	BEGIN
		UPDATE [#WorkersLaborsSellPriceDist]
			SET [InDirectValue] = (((SellPrices.[FinishedGoodsSellPrice] / @TotalSellPrice) * PriceDist.[DistWorkerLabor])) 
		FROM [#WorkersLaborsSellPriceDist] as PriceDist
		INNER JOIN [#FinishedGoodsSellPrices] AS SellPrices ON SellPrices.[FinishedGoodsGuid] = PriceDist.[DinishedGoodGuid]
	END
	
	SELECT * FROM [#WorkersLaborsSellPriceDist]
	
	DROP TABLE [#WorkersLabors]
	DROP TABLE [#FinishedGoodsSellPrices]
	DROP TABLE [#WorkersLaborsSellPriceDist]
END
######################################################################
CREATE FUNCTION JOCfnCalcJobOrderDirectCostDist(@JobOrderGuid UNIQUEIDENTIFIER = 0x0)
RETURNS TABLE
AS
-- ÍÓÇÈ ÊæÒíÚ ÇáßáÝ ÇáãÈÇÔÑÉ ááãæÇÏ ÇáÇæáíå Úáí ÇáãäÊÌÇÊ ÇáÊÇãÉ
RETURN(

SELECT 
(CASE ProdStandardQuantity.DistMethod WHEN 0 THEN 0 ELSE 
	CASE TotalProdStandardQuantity.TotalStandardQuantity WHEN 0 THEN 0 
	ELSE (ProdStandardQuantity.StandardQuantity/TotalProdStandardQuantity.TotalStandardQuantity* ProdStandardQuantity.NetExchange)END END)
	AS CostDist,

ProdStandardQuantity.StandardQuantity AS StandardQuantity,
TotalProdStandardQuantity.TotalStandardQuantity,
ProdStandardQuantity.NetExchange,
ProdStandardQuantity.MaterialGuid AS FinshedGoodsGuid,
ProdStandardQuantity.RawMaterialGuid,
ProdStandardQuantity.JobOrderGuid,
ProdStandardQuantity.StageGuid,
ProdStandardQuantity.DistMethod,
Mt.Code AS MaterialCode,
CASE [dbo].[fnConnections_GetLanguage]() WHEN 0 THEN Mt.Name ELSE (CASE Mt.LatinName WHEN '''' THEN Mt.Name ELSE Mt.LatinName END) END AS MaterialName


FROM 
JOCvwJobOrderProductsStandardQuantity	AS ProdStandardQuantity
INNER JOIN mt000 Mt ON Mt.GUID = ProdStandardQuantity.MaterialGuid
LEFT JOIN JOCvwJobOrderTotalProductsStandardQuantity	AS TotalProdStandardQuantity 
			ON ProdStandardQuantity.RawMaterialGuid=TotalProdStandardQuantity.RawMaterialGuid 
			AND ProdStandardQuantity.JobOrderGuid=TotalProdStandardQuantity.JobOrderGuid
			AND ProdStandardQuantity.StageGuid=TotalProdStandardQuantity.StageGuid

WHERE ProdStandardQuantity.JobOrderGuid = (CASE @JobOrderGuid WHEN 0x0 THEN ProdStandardQuantity.JobOrderGuid ELSE @JobOrderGuid END)
)
######################################################################
CREATE FUNCTION JOCfnCalcJobOrderInDirectCostDist(@JobOrderGuid UNIQUEIDENTIFIER = 0x0)
RETURNS TABLE
AS
-- ÍÓÇÈ ÊæÒíÚ ÇáßáÝ ÇáÛíÑ ãÈÇÔÑÉ ááãæÇÏ ÇáÇæáíå Úáí ÇáãäÊÌÇÊ ÇáÊÇãÉ
RETURN(

SELECT 
ISNULL((
	CASE RawQty.DistMethod WHEN 1 THEN 0 ELSE (
	CASE JOBom.JointCostsAllocationType WHEN 0 THEN
		((CASE FGBillItems.ManufUsedUnit WHEN 1 THEN FGBillItems.FirstProductionUnityQty ELSE FGBillItems.SecondProductionUnityQty END) /
		(SELECT MIN(Qty) FROM JOCfnGetJobOrderTotalProductsQtys(RawQty.JobOrderGuid ,FGBillItems.ManufUsedUnit)) * RawQty.NetExchange )
	ELSE 
		(FGBillItemsSellPrice.FinishedGoodsSellPrice /
		( dbo.JOCfnGetJobOrderTotalProductsSellPrice(RawQty.JobOrderGuid)) * RawQty.NetExchange )
	END)
	END 
),0) AS CostDist,

RawQty.NetExchange,
BOMRaw.FinishedProductGuid AS FinshedGoodsGuid,
BOMRaw.RawMaterialGuid ,
RawQty.JobOrderGuid,
RawQty.StageGuid,
RawQty.DistMethod,
Mt.Code AS MaterialCode,
CASE [dbo].[fnConnections_GetLanguage]() WHEN 0 THEN Mt.Name ELSE (CASE Mt.LatinName WHEN '''' THEN Mt.Name ELSE Mt.LatinName END) END AS MaterialName

FROM JOCOperatingBOMRawMaterials000 BOMRaw
INNER JOIN mt000 Mt ON Mt.GUID = BOMRaw.FinishedProductGuid
LEFT JOIN JOCvwJobOrderRawMaterialsQuantities RawQty ON BOMRaw.RawMaterialGuid = RawQty.MaterialGuid AND RawQty.JobOrderOperatingBOM = BOMRaw.OperatingBOMGuid AND RawQty.StageGuid = BOMRaw.StageGuid
LEFT JOIN JOCvwJobOrderFinishedGoodsBillItemsQtys FGBillItems ON FGBillItems.JobOrderGuid = RawQty.JobOrderGuid AND FGBillItems.MaterialGuid = BOMRaw.FinishedProductGuid
LEFT JOIN JOCvwJobOrderFinishedGoodsItemsSellPrice FGBillItemsSellPrice ON FGBillItemsSellPrice.JobOrderGuid = RawQty.JobOrderGuid AND FGBillItemsSellPrice.FinishedGoodsGuid = BOMRaw.FinishedProductGuid
LEFT JOIN JOCJobOrderOperatingBOM000 JOBom ON JOBom.Guid = BOMRaw.OperatingBOMGuid

WHERE RawQty.JobOrderGuid = (CASE @JobOrderGuid WHEN 0x0 THEN RawQty.JobOrderGuid ELSE @JobOrderGuid END)
)
######################################################################
CREATE FUNCTION JOCfnCalcJobOrderCostDist(@JobOrderGuid UNIQUEIDENTIFIER = 0x0)
RETURNS TABLE
AS
--ÍÓÇÈ ÊæíÚ ßáÝ ÇáãæÇÏ ÇáÇæáíå Úáí ÇáãäÊÌÇÊ ÇáÊÇãÉ
RETURN(

SELECT 
DirectCostDist.RawMaterialGuid,
DirectCostDist.StageGuid,
DirectCostDist.FinshedGoodsGuid,
DirectCostDist.MaterialName,
DirectCostDist.MaterialCode,
(CASE DirectCostDist.DistMethod WHEN 1 THEN DirectCostDist.CostDist ELSE InDirectCostDist.CostDist END) AS CostDist,
DirectCostDist.JobOrderGuid

FROM JOCfnCalcJobOrderDirectCostDist(@JobOrderGuid) AS DirectCostDist
INNER JOIN  JOCfnCalcJobOrderInDirectCostDist(@JobOrderGuid) AS InDirectCostDist
	ON DirectCostDist.JobOrderGuid = InDirectCostDist.JobOrderGuid
	AND DirectCostDist.RawMaterialGuid = InDirectCostDist.RawMaterialGuid
	AND DirectCostDist.StageGuid = InDirectCostDist.StageGuid
	AND DirectCostDist.FinshedGoodsGuid = InDirectCostDist.FinshedGoodsGuid

)
######################################################################
CREATE FUNCTION JOCfnGetJobOrderMOH(@JobOrderGuid UNIQUEIDENTIFIER)
--Calculate JobOrder MOH
RETURNS FLOAT
AS
	BEGIN
		 RETURN 
		 (
			SELECT SUM(PeriodTotalMoh) 
			FROM JOCJobOrderGeneralExpenses000
			WHERE JobOrderGuid = @JobOrderGuid
			GROUP BY JobOrderGuid
		 )
	END
######################################################################
CREATE VIEW JOCvwJobOrdersMOH
AS
SELECT
		JobOrder.JobOrderGuid,
		--Get the Production Line Estimation Cost
		CASE WHEN JobOrder.ManufactoryEstimatedCostCalcBase = 1 THEN JobOrder.ProductionLineEstimatedCost
		ELSE Costs.EstimatedCost END 
		*
		-- Total Qty or Total Working Hours or Machine Hours. 
		CASE WHEN JobOrder.ManufactoryMOHAllocationBase = 0 THEN (SELECT Qty FROM JOCfnGetJobOrderTotalProductsQtys(JobOrder.JobOrderGuid, (CASE WHEN JobOrder.ManufactoryUsedProductionUnit = JobOrder.ManufactoryProductionUnitOne THEN 1 ELSE 2 END)))
		WHEN JobOrder.ManufactoryMOHAllocationBase = 1 THEN (SELECT SUM(WorkingHours) FROM JOCvwJobOrderDirectLaborsDetails details  WHERE details.JobOrderGuid = JobOrder.JobOrderGuid GROUP BY details.JobOrderGuid )
		ELSE JobOrder.JobOrderOperatingMachineHours END
		AS MOH
	 FROM JocVwJobOrder JobOrder 
	 INNER JOIN Plcosts000 Costs ON JobOrder.JobOrderProductionLine = Costs.ProductionLine
	 WHERE  JobOrder.JobOrderStartDate BETWEEN Costs.StartPeriodDate AND Costs.EndPeriodDate
	 AND JobOrder.JobOrderStatus = 0

######################################################################
CREATE VIEW JOCvwOperatingBOMMaterialsPercentages
AS
SELECT Materials.MaterialGuid, 
OperatingBOM.Guid,
Quantities.JobOrderGuid AS JobOrderGuid,
CASE WHEN OperatingBOM.JointCostsAllocationType = 0 THEN 
		(CASE WHEN Quantities.ManufUsedUnit = 1 THEN FirstProductionUnityQty / (SELECT MIN(Qty) FROM JOCfnGetJobOrderTotalProductsQtys(Quantities.JobOrderGuid, 1) )
		ELSE (SecondProductionUnityQty / (SELECT MIN(Qty) FROM JOCfnGetJobOrderTotalProductsQtys(Quantities.JobOrderGuid, 2)) )END)
	ELSE (Prices.FinishedGoodsSellPrice /  dbo.JOCfnGetJobOrderTotalProductsSellPrice(Prices.JobOrderGuid))
	END AS Percentage

 FROM JOCOperatingBOMFinishedGoods000 Materials 
INNER JOIN JOCJobOrderOperatingBOM000 OperatingBOM ON Materials.OperatingBOMGuid = OperatingBOM.Guid
INNER JOIN JOCvwJobOrderFinishedGoodsBillItemsQtys Quantities ON Quantities.MaterialGuid = Materials.MaterialGuid AND Quantities.OperatingBOMGuid = OperatingBOM.Guid
INNER JOIN JOCvwJobOrderFinishedGoodsItemsSellPrice Prices ON Prices.FinishedGoodsGuid = Materials.MaterialGuid AND Prices.OperatingBOMGuid = OperatingBOM.Guid	
######################################################################

CREATE  VIEW JOCvwJobOrderMaterialsMOHCosts
AS
SELECT	Materials.FinishedProductGuid,
		IndirectAllocation.JobOrderGuid,
		CASE WHEN Materials.MOHAllocationType = 1 THEN (Materials.MOHPercentage / (SUM(MOHPercentage)  OVER (PARTITION BY JobOrderGuid))) * dbo.JOCfnGetJobOrderMOH(IndirectAllocation.JobOrderGuid) 
		ELSE dbo.JOCfnGetJobOrderMOH(IndirectAllocation.JobOrderGuid) * IndirectAllocation.Percentage END
		AS Percentage
FROM JOCOperatingBOMWagesAndMOH000 Materials 
INNER JOIN JOCvwOperatingBOMMaterialsPercentages IndirectAllocation ON IndirectAllocation.Guid = Materials.OperatingBOMGuid AND IndirectAllocation.MaterialGuid = Materials.FinishedProductGuid  

######################################################################
CREATE PROC JOCprcCalculateJobOrderCosts
@JobOrderGuid UNIQUEIDENTIFIER = 0x0
AS
	SET NOCOUNT ON;
		CREATE TABLE [#RawMaterialsCosts]
	(
		RawMaterialGuid		UNIQUEIDENTIFIER, 
		StageGuid			UNIQUEIDENTIFIER, 
		FinishedGoodGuid	UNIQUEIDENTIFIER,
		MaterialName		NVARCHAR(250),
		MaterialCode		NVARCHAR(250),
		CostDist			FLOAT,
		JobOrderGuid		UNIQUEIDENTIFIER
	)
	CREATE TABLE [#DirectLaborsCosts]
	( 
		[FinishedGoodGuid]		[UNIQUEIDENTIFIER], --1
		[WorkerGuid]			[UNIQUEIDENTIFIER], --2
		[StageGuid]				[UNIQUEIDENTIFIER], --3
		[StageName]				[NVARCHAR](Max),	--4
		[StageLatinName]		[NVARCHAR](max),	--5
		[DistWorkerLabor]		[FLOAT],			--6
		[InDirectValue]			[FLOAT],			--7
		[WorkingHourCost]		[FLOAT]				--8
	)
	CREATE TABLE [#MOHCosts]
	(
		FinishedGoodGuid	UNIQUEIDENTIFIER,
		JobOrderGUID		UNIQUEIDENTIFIER,
		Percentage			FLOAT
	)
	CREATE TABLE[#GeneralCosts]
	(
		MaterialGuid			UNIQUEIDENTIFIER,
		RequiredQty				FLOAT,
		Unit					INT,
		UnitName				NVARCHAR(250),
		TotalDirectMaterials	FLOAT,
		TotalDirectLabors		FLOAT,
		TotalMOH				FLOAT,
		TotalProductionCost		FLOAT, 
		ActualProduction		FLOAT,
		UnitCost				FLOAT,
		ProductionQuantity		FLOAT,
		SellPrice				FLOAT,
		SellValue				FLOAT,
		MaterialIndex			INT,
		TotalDirectExpenses		MONEY
	)
	CREATE TABLE #SpoilageCosts
	(
		TotalProductionCost			FLOAT,
		TotalProductionQty			FLOAT, 
		ProductionUnit				INT,
		ProductionUnitCost			FLOAT,
		FlawLessQty					FLOAT, 
		SpoilageQty					FLOAT,
		NormalSpoilageQty			FLOAT,
		AbnormalSpoilageQty			FLOAT,
		FlawlessUnitCost			FLOAT,
		TotalSpoilageCost			FLOAT,
		SpoilageSellPrice			FLOAT,
		DeliveredSpoilageValue		FLOAT,
		NormalSpoilageNetCost		FLOAT,
		AbnormalSpoilageNetCost		FLOAT,
		SpoilageMaterialGuid		UNIQUEIDENTIFIER,
		FinishedProductGuid			UNIQUEIDENTIFIER,
		StandardSpoilageQty			FLOAT,
		StandardSpoilagePercentage	FLOAT
	)
	---Implementation. 
	INSERT INTO [#RawMaterialsCosts] SELECT * FROM JOCfnCalcJobOrderCostDist(@JobOrderGuid)
	EXECUTE JOCprcCalculateJobOrderDirectLaborsCosts @JobOrderGuid
	INSERT INTO [#MOHCosts] SELECT * FROM JOCvwJobOrderMaterialsMOHCosts WHERE JobOrderGuid = @JobOrderGuid
	
	INSERT INTO #GeneralCosts
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
		SUM(FinishedGoodsQtys.Quantity) / CASE WHEN FinishedGoods.Unit = 2 THEN mt.Unit2Fact WHEN FinishedGoods.Unit = 3 THEN mt.Unit3Fact ELSE 1 END AS ActualProduction,
		0 AS UnitCost, --UnitCost,
		0 AS ProductionQuantity , -- Labors Hours, Production Qty or machine hours. 
		FinishedGoods.Price AS SellPrice, 
		0  AS SellValue,-- SellValue
		FinishedGoods.MaterialIndex,
		0
	FROM JOCOperatingBOMFinishedGoods000 FinishedGoods 
	INNER JOIN mt000 mt ON FinishedGoods.[MaterialGuid] = mt.[GUID] --OR FinishedGoods.SpoilageMaterial = mt.[GUID]
	INNER JOIN JOCvwJobOrderFinishedGoodsBillItemsQtys FinishedGoodsQtys ON FinishedGoodsQtys.MaterialGuid = FinishedGoods.[MaterialGuid] --OR FinishedGoodsQtys.MaterialGuid = FinishedGoods.SpoilageMaterial
	INNER JOIN JobOrder000 JobOrder ON (JobOrder.[Guid] = FinishedGoodsQtys.[JobOrderGuid] AND FinishedGoods.[OperatingBOMGuid] = JobOrder.[OperatingBOMGuid])
	WHERE FinishedGoodsQtys.JobOrderGuid = @JobOrderGuid 
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
		,FinishedGoods.MaterialIndex

	
	Update #GeneralCosts 
	SET TotalDirectMaterials = (SELECT SUM(CostDist) FROM #RawMaterialsCosts
		where FinishedGoodGuid = Gen.MaterialGuid)
	FROM #GeneralCosts as Gen
	Update #GeneralCosts 
	SET TotalDirectLabors = (SELECT SUM(InDirectValue) FROM #DirectLaborsCosts
		where FinishedGoodGuid = Gen.MaterialGuid)
	FROM #GeneralCosts as Gen
		
	Update #GeneralCosts 
	SET TotalMOH = (SELECT SUM(Percentage) FROM [#MOHCosts]
		where FinishedGoodGuid = Gen.MaterialGuid)
	FROM #GeneralCosts as Gen

	Update #GeneralCosts 
	SET TotalProductionCost = (TotalDirectMaterials + TotalDirectLabors + TotalMOH)
	FROM #GeneralCosts as Gen

	SELECT 
	SUM(Result.TotalExpenses) AS TotalExpenses,
	Result.MatGuid 
	INTO #DirectExpenses
	FROM (
		   SELECT DISTINCT items.TotalExpenses  ,items.MatGuid , items.ParentGuid
		   FROM JOCBOMJobOrderEntry000 AS ENTRY 
		   INNER JOIN  JOCBOMDirectExpenseItems000 AS items ON items.ParentGuid = entry.GUID 
		   WHERE entry.JobOrderGUID = @JobOrderGuid
		) AS Result
	GROUP BY MatGuid 

	UPDATE #GeneralCosts
	SET TotalDirectExpenses  = DE.TotalExpenses
	FROM #GeneralCosts AS Gen
	INNER JOIN #DirectExpenses AS DE ON DE.MatGuid = Gen.MaterialGuid

	UPDATE #GeneralCosts 
	SET TotalProductionCost = (TotalProductionCost +  DirectExpense.TotalExpenses)
	FROM #GeneralCosts as Gen
	INNER JOIN #DirectExpenses AS DirectExpense ON DirectExpense.MatGuid = Gen.MaterialGuid

	UPDATE #GeneralCosts 
		SET UnitCost = TotalProductionCost / ActualProduction, 
		SellValue = ActualProduction * SellPrice,
		ProductionQuantity = ( CASE WHEN FinishedGoodsQtys.ManufUsedUnit = 1 THEN  FinishedGoodsQtys.FirstProductionUnityQty ELSE  FinishedGoodsQtys.SecondProductionUnityQty END )
	FROM #GeneralCosts AS Costs
	INNER JOIN JOCvwJobOrderFinishedGoodsBillItemsQtys FinishedGoodsQtys ON Costs.MaterialGuid = FinishedGoodsQtys.MaterialGuid
	where FinishedGoodsQtys.JobOrderGuid = @JobOrderGuid

	UPDATE GeneralCosts
	SET  GeneralCosts.RequiredQty = JobOrderCosts.RequiredQty
	FROM #GeneralCosts GeneralCosts INNER JOIN JOCJobOrderCosts000 JobOrderCosts ON JobOrderCosts.FinishedMaterialGuid = GeneralCosts.MaterialGuid

	--SpoilageCosts Implementation
	--//================================================================================================================================
	--//================================================================================================================================
	INSERT INTO #SpoilageCosts
	SELECT
	 generalCosts.TotalProductionCost,
	 generalCosts.ActualProduction,
	 generalCosts.Unit,
	 generalcosts.UnitCost,
	 0,
	 0,
	 0,
	 0,
	 0,
	 0,
	 CASE WHEN bomFinishedGoods.SpoilageSellPrice < generalcosts.UnitCost THEN bomFinishedGoods.SpoilageSellPrice ELSE generalcosts.UnitCost END,
	 0,
	 0,
	 0,
	 bomFinishedGoods.SpoilageMaterial,
	 bomFinishedGoods.MaterialGuid,
	 bomFinishedGoods.SpoilageQty,
	 bomFinishedGoods.SpoilagePercentage / 100
	FROM #GeneralCosts generalCosts
	INNER JOIN JOCOperatingBOMFinishedGoods000 bomFinishedGoods ON generalCosts.MaterialGuid = bomFinishedGoods.MaterialGuid
	INNER JOIN JocVwJobOrder JobOrder ON bomFinishedGoods.OperatingBOMGuid = JobOrder.JobOrderOperatingBOM
	WHERE JobOrder.JobOrderGuid = @JobOrderGuid AND JobOrder.UseSpoilage = 1


	UPDATE #SpoilageCosts
	SET FlawLessQty = ISNULL((SELECT SUM(deliveredMaterials.QtyByBomUnit)
	FROM JOCvwJobOrderDeliveredFlawlessMaterials deliveredMaterials 
	GROUP BY deliveredMaterials.MaterialGuid,
	deliveredMaterials.JobOrderGuid
	HAVING  #SpoilageCosts.FinishedProductGuid = deliveredMaterials.MaterialGuid
	AND deliveredMaterials.JobOrderGuid = @JobOrderGuid
	
	), 0)
	,SpoilageQty = ISNULL((SELECT SUM(deliveredMaterials.QtyByBomUnit)
	FROM JOCvwJobOrderDeliveredSpoiledMaterials deliveredMaterials 
	GROUP BY deliveredMaterials.MaterialGuid,
		deliveredMaterials.JobOrderGuid
	HAVING  #SpoilageCosts.SpoilageMaterialGuid = deliveredMaterials.MaterialGuid
	AND deliveredMaterials.JobOrderGuid = @JobOrderGuid
	),0)


	-- ßãíÉ ÇáÊáÝ ÇáØÈíÚí
	UPDATE #SpoilageCosts 
	SET NormalSpoilageQty = CASE 
			WHEN (#SpoilageCosts.SpoilageQty = 0) THEN 0
			WHEN (#SpoilageCosts.SpoilageQty < (#SpoilageCosts.StandardSpoilageQty + (#SpoilageCosts.TotalProductionQty * #SpoilageCosts.StandardSpoilagePercentage)))
			THEN #SpoilageCosts.SpoilageQty
			ELSE (#SpoilageCosts.StandardSpoilageQty + (#SpoilageCosts.TotalProductionQty * #SpoilageCosts.StandardSpoilagePercentage))
			END


	--ßãíÉ ÇáÊáÝ ÛíÑ ÇáØÈíÚí
	UPDATE #SpoilageCosts 
	SET AbnormalSpoilageQty = CASE WHEN (#SpoilageCosts.SpoilageQty < (#SpoilageCosts.StandardSpoilageQty + (#SpoilageCosts.TotalProductionQty * #SpoilageCosts.StandardSpoilagePercentage)))
								  THEN 0 ELSE (#SpoilageCosts.SpoilageQty - #SpoilageCosts.NormalSpoilageQty ) END

	--ÅÌãÇáí ßáÝÉ ÇáÊáÝ
	, TotalSpoilageCost = SpoilageQty * ProductionUnitCost

	--ÞíãÉ ÇáÊáÝ ÇáãÓáã ááãÓÊæÏÚ
	,DeliveredSpoilageValue = SpoilageQty * SpoilageSellPrice

	--ÕÇÝí ßáÝÉ ÇáÊáÝ ÇáØÈíÚí
	,NormalSpoilageNetCost = (ProductionUnitCost - SpoilageSellPrice) * NormalSpoilageQty

	--ÕÇÝí ßáÝÉ ÇáÊáÝ ÛíÑ ÇáØÈíÚí
	UPDATE #SpoilageCosts
	SET AbnormalSpoilageNetCost = (ProductionUnitCost - SpoilageSellPrice) * AbnormalSpoilageQty

	--ßáÝÉ ÇáæÍÏÉ ÇáÓáíãÉ
	UPDATE #SpoilageCosts
	SET FlawlessUnitCost =  CASE WHEN FlawLessQty > 0 THEN (TotalProductionCost - DeliveredSpoilageValue - AbnormalSpoilageNetCost) / FlawLessQty ELSE 0 END

	--//================================================================================================================================
	--//================================================================================================================================


	
	SELECT * FROM #RawMaterialsCosts
	SELECT * FROM #DirectLaborsCosts
	SELECT * FROM #GeneralCosts ORDER BY MaterialIndex
	SELECT * FROM [#SpoilageCosts]
	
	DROP TABLE [#RawMaterialsCosts]
	DROP TABLE [#DirectLaborsCosts]
	DROP TABLE [#MOHCosts]
	DROP TABLE [#GeneralCosts]
	DROP TABLE [#SpoilageCosts]

######################################################################

CREATE PROC JOCprcCalculateJobOrderDirectLaborsCosts(@JobOrderGuid UNIQUEIDENTIFIER = 0x0)
AS
BEGIN
	DECLARE @FinishedGoodsCount INT
	DECLARE @WithStages BIT
	DECLARE @JobOrderIsActive BIT
	DECLARE @JointCostMethod BIT
	DECLARE @DirectLaborsDistMethod BIT

	SET @FinishedGoodsCount = 0
	SET @WithStages = 1
	SET @JobOrderIsActive = 1
	SET @JointCostMethod = 0 -- 0: ProductionQty , 1:ProductionSellValue
	SET @DirectLaborsDistMethod = 0 -- 0: InDirect, 1: Direct

	---------- @FinishedGoodsCount -----------------------------------------------------------------------
	------------------------------------------------------------------------------------------------------
	SELECT @FinishedGoodsCount = Count(FinishedGoods.[MaterialGuid]) FROM JobOrder000 AS JobOrder
	INNER JOIN JOCJobOrderOperatingBOM000 AS OperatingBOM ON JobOrder.[OperatingBOMGuid] = OperatingBOM.[Guid]
	INNER JOIN JOCOperatingBOMFinishedGoods000 AS FinishedGoods ON FinishedGoods.[OperatingBOMGuid] = OperatingBOM.[Guid]
	where JobOrder.[Guid] = @JobOrderGuid
	------------------------------------------------------------------------------------------------------

	------- @WithStages and @JobOrderIsActive-------------------------------------------------------------
	------------------------------------------------------------------------------------------------------
	Select Top 1 @WithStages = (BOM.StagesEnabled & BOM.UseStagesInRequestionAndLabor), 
				 @JobOrderIsActive = JobOrder.[IsActive]  
	FROM JobOrder000 JobOrder
	INNER JOIN  JOCJobOrderOperatingBOM000 OperatingBOM ON JobOrder.[OperatingBOMGuid] = OperatingBOM.[Guid]
	INNER JOIN	JOCBOM000 BOM ON OperatingBOM.[BOMGuid] = BOM.[GUID]
	where JobOrder.[Guid] = @JobOrderGuid
	------------------------------------------------------------------------------------------------------


	------- @DirectLaborsDistMethod and @JointCostMethod--------------------------------------------------
	------------------------------------------------------------------------------------------------------
	SELECT @DirectLaborsDistMethod = Labors.[WagesAllocationType],
			@JointCostMethod =  OperatingBOM.[JointCostsAllocationType]
	FROM JOCOperatingBOMWagesAndMOH000 Labors
	INNER JOIN JOCJobOrderOperatingBOM000 OperatingBOM ON Labors.[OperatingBOMGuid] = OperatingBOM.[Guid]
	INNER JOIN JobOrder000 JobOrder ON JobOrder.[OperatingBOMGuid] = OperatingBOM.[Guid]
	WHERE JobOrder.[Guid] = @JobOrderGuid
	------------------------------------------------------------------------------------------------------


	if( @DirectLaborsDistMethod = 0 OR @FinishedGoodsCount = 1)
	BEGIN

		IF(@JointCostMethod = 0)
		BEGIN
			INSERT INTO [#DirectLaborsCosts] 
				EXECUTE prcGetInDirectLaborsDistQty @JobOrderGuid, @WithStages
		END
		ELSE IF (@JointCostMethod = 1)
		BEGIN
			INSERT INTO [#DirectLaborsCosts] 
				EXECUTE prcGetInDirectLaborsDistPrice @JobOrderGuid, @WithStages
		END

	END

	IF(@DirectLaborsDistMethod = 1)
	BEGIN

		INSERT INTO [#DirectLaborsCosts]
			EXEC JOCprcCalculateDirectLaborsDirectDist @JobOrderGuid , @WithStages
	
	END

END

######################################################################
CREATE PROC JOCprcCalculateDirectLaborsDirectDist
(
	@JobOrderGuid	UNIQUEIDENTIFIER = 0x0,
	@WithStages		BIT = 0
)
AS
BEGIN

	CREATE TABLE [#WorkersLabors]
	( 
		[WorkerGuid]		[UNIQUEIDENTIFIER], 
		[StageGuid]			[UNIQUEIDENTIFIER], 
		[StageName]			[NVARCHAR](Max),
		[StageLatinName]	[NVARCHAR](max),
		[WorkingHourCost]	[FLOAT],
		[TotalWorkingHours] [FLOAT],
		[DistWorkerLabor]	[FLOAT]
	)

	INSERT INTO [#WorkersLabors]
		SELECT * FROM [dbo].[JOCfnCalcJobOrderDirectLabrs](@JobOrderGuid, @WithStages)

	
	CREATE TABLE [#FinishedGoodsDirectPercentages]
	( 
		[FinishedGoodGuid]		[UNIQUEIDENTIFIER],
		[Percentages]			[FLOAT]
	)

	INSERT INTO [#FinishedGoodsDirectPercentages]
		SELECT Labors.[FinishedProductGuid] , Labors.[WagesPercentage]
		FROM JOCOperatingBOMWagesAndMOH000 Labors
		INNER JOIN JOCJobOrderOperatingBOM000 OperatingBOM ON Labors.[OperatingBOMGuid] = OperatingBOM.[Guid]
		INNER JOIN JobOrder000 JobOrder ON JobOrder.[OperatingBOMGuid] = OperatingBOM.[Guid]
		WHERE JobOrder.[Guid] = @JobOrderGuid


	DECLARE @ToBeDeletedPercentage [FLOAT]
	SET @ToBeDeletedPercentage = 0

	SELECT @ToBeDeletedPercentage = SUM(Percentages.[Percentages])
	FROM [#FinishedGoodsDirectPercentages] Percentages
	INNER JOIN [JOCvwJobOrderFinishedGoodsBillItemsQtys] BillQtys ON BillQtys.[MaterialGuid] = Percentages.[FinishedGoodGuid]
	where JobOrderGuid = @JobOrderGuid

	SET @ToBeDeletedPercentage = 100.0 - @ToBeDeletedPercentage

	IF(@ToBeDeletedPercentage <> 0.0 )
	BEGIN
		UPDATE [#FinishedGoodsDirectPercentages]
			SET [Percentages] = [Percentages] + (@ToBeDeletedPercentage * ([Percentages] / (100- @ToBeDeletedPercentage)))
		FROM [#FinishedGoodsDirectPercentages] AS Percentage

		UPDATE [#FinishedGoodsDirectPercentages]
			SET [Percentages] = 0.0
		FROM [#FinishedGoodsDirectPercentages] 
		WHERE ([FinishedGoodGuid] NOT IN  
				(	SELECT [FinishedGoodGuid] 
					FROM [#FinishedGoodsDirectPercentages] Percentages
					INNER JOIN [JOCvwJobOrderFinishedGoodsBillItemsQtys] BillQtys ON BillQtys.[MaterialGuid] = Percentages.[FinishedGoodGuid]
					WHERE JobOrderGuid = @JobOrderGuid)
			  )
	END

	SELECT	Percentages.[FinishedGoodGuid] AS FinishedGoodGuid,
			Labors.[WorkerGuid] AS WorkerGuid,
			( Case @WithStages when 1 then Labors.[StageGuid] ELSE 0x00 END) AS StageGuid, 
			( Case @WithStages when 1 then Labors.[StageName] ELSE '' END) AS StageName,
			( Case @WithStages when 1 then Labors.[StageLatinName] ELSE '' END) AS StageLatinName,
			Labors.[DistWorkerLabor] AS DistWorkerLabor,
			((Labors.[DistWorkerLabor] * Percentages.[Percentages]) / 100.0) AS InDirectValue,
			Labors.[WorkingHourCost] AS WorkingHourCost
	FROM [#FinishedGoodsDirectPercentages] AS Percentages
	CROSS JOIN [#WorkersLabors] AS Labors


	DROP TABLE [#WorkersLabors]
	DROP TABLE [#FinishedGoodsDirectPercentages]

END
######################################################################
CREATE PROC JOCInsertDirectMaterialsCosts
@JobOrderGuid UNIQUEIDENTIFIER = 0x0
AS
	
		INSERT INTO JOCJobOrderDirectMaterials000 
		(JobOrderGuid, RawMaterialGuid, FinishedGoodGuid, StageGuid, AllocationType, Unit, ExpensedQty, ReturnedQty, NetQty, NetValue, FinishedGoodCost)
		(
			SELECT 
				@JobOrderGuid, 
				BOMRawMaterials.MaterialGuid, 
				0x0, 
				BOMRawMaterials.StageGuid, 
				BOMRawMaterials.DistMethod,
				BOMRawMaterials.Unit,
				BOMRawMaterials.ExpensedQty,
				BOMRawMaterials.ReturnedQty,
				BOMRawMaterials.NetQty,
				BOMRawMaterials.NetExchange,
				0
				FROM JOCvwJobOrderRawMaterialsQuantities BOMRawMaterials 
				WHERE BOMRawMaterials.JobOrderGuid = @JobOrderGuid AND (BOMRawMaterials.ExpensedQty > 0 OR BOMRawMaterials.TransOutQty > 0 OR BOMRawMaterials.ReturnedQty > 0 OR BOMRawMaterials.TransInQty > 0)
		)
######################################################################
CREATE PROC JOCprcUpdateDirectMaterialsCosts
@JobOrderGuid UNIQUEIDENTIFIER = 0x0
AS

	DELETE FROM JOCJobOrderDirectMaterials000 WHERE JobOrderGuid = @JobOrderGuid
	
	EXEC JOCInsertDirectMaterialsCosts @JobOrderGuid
######################################################################
CREATE PROCEDURE JOCprcRawMaterialsDeviationReport
(	@JobOrderGuid [UNIQUEIDENTIFIER], 
	@OperatingBomGuid [UNIQUEIDENTIFIER]
)
AS
-- ÊÞÑíÑ ÅäÍÑÇÝÇÊ ÇáãæÇÏ ÇáÃæáíÉ
BEGIN

	DECLARE @Result AS TABLE
	(
		[RawMatGuid]					[UNIQUEIDENTIFIER],
		[RawMatCode]					[NVARCHAR](255) COLLATE ARABIC_CI_AI,
		[RawMatName]					[NVARCHAR](255) COLLATE ARABIC_CI_AI,
		[RawMatLatinName]				[NVARCHAR](255),
		[RawMatIndex]					[INT],
		[RawMatGroupGuid]				[UNIQUEIDENTIFIER],
		[RawMatGroupName]				[NVARCHAR](255) COLLATE ARABIC_CI_AI,
		[RawMatGroupLatinName]			[NVARCHAR](255),
		[FinishedProdGuid]				[UNIQUEIDENTIFIER],
		[FinishedProdCode]				[NVARCHAR](255) COLLATE ARABIC_CI_AI,
		[FinishedProdName]				[NVARCHAR](255) COLLATE ARABIC_CI_AI,
		[FinishedProdLatinName]			[NVARCHAR](255),
		[FinishedProdIndex]				[INT],
		[StageGuid]						[UNIQUEIDENTIFIER],
		[StageCode]						[NVARCHAR](255) COLLATE ARABIC_CI_AI,
		[StageName]						[NVARCHAR](255) COLLATE ARABIC_CI_AI,
		[StageLatinName]				[NVARCHAR](255),
		[RawMatUnit]					[INT],
		[RawMatUnitName]				[NVARCHAR](100),
		[FinishedProdBOMUnit]			[INT],
		[FinishedProdBOMUnitName]		[NVARCHAR](100),
		[StandardQty]					[FLOAT],
		[ActualProductionQty]			[FLOAT],
		[DeviationQty]					[FLOAT],
		[FinishedProdActualProdBOMUnit]	[FLOAT],
		[StandardQtyBOMUnit]			[FLOAT],
		[ActualProductionQtyBOMUnit]	[FLOAT],
		[DeviationQtyBOMUnit]			[FLOAT],
		[Price]							[FLOAT],
		[StandardValue]					[FLOAT],
		[ActualProdValue]				[FLOAT],
		[DeviationValue]				[FLOAT],
		[StandardValueBOMUnit]			[FLOAT],
		[ActualProdValueBOMUnit]		[FLOAT],
		[DeviationValueBOMUnit]			[FLOAT],
		[DeviationPercentage]			[FLOAT]					
	)

	DECLARE @StandardQty AS TABLE
	(
		[RawMatGuid]		[UNIQUEIDENTIFIER],
		[FinishedProdGuid]	[UNIQUEIDENTIFIER],
		[StageGuid]			[UNIQUEIDENTIFIER],
		[RawMatUnit]		[FLOAT],
		[RawMatUnitName]	[NVARCHAR](250),
		[StandardQty]		[FLOAT]
	)

	DECLARE @ActualProduction AS TABLE
	(
		[RawMatGuid]				[UNIQUEIDENTIFIER],
		[FinishedProdGuid]			[UNIQUEIDENTIFIER],
		[StageGuid]					[UNIQUEIDENTIFIER],
		[RawMatUnit]				[FLOAT],
		[RawMatUnitName]			[NVARCHAR](250),
		[ActualProductionQty]		[FLOAT],
		[Price]						[FLOAT]
	)

	DECLARE @FinishedProdBomQtys AS TABLE
	(
		[FinishedProdGuid]		[UNIQUEIDENTIFIER],
		[FinishedProdQty1]		[FLOAT]
	)

	DECLARE @JointCostMethod BIT
	SET @JointCostMethod = 0 -- 0: ProductionQty , 1:ProductionSellValue
	DECLARE @UseProductionUnit INT
	SET @UseProductionUnit = -1

	SELECT @UseProductionUnit = (CASE UsedProductionUnit WHEN ProductionUnitOne THEN 1 WHEN ProductionUnitTwo THEN 2 END)
	FROM JobOrder000 JO
	INNER JOIN Manufactory000 Manufactory ON Manufactory.[Guid] = JO.[ManufactoryGUID]
	WHERE JO.[Guid] = @JobOrderGuid

	---------------------------------- @JointCostMethod--------------------------------------------------
	------------------------------------------------------------------------------------------------------
	SELECT @JointCostMethod =  OperatingBOM.[JointCostsAllocationType]
	FROM JOCJobOrderOperatingBOM000 OperatingBOM
	WHERE OperatingBOM.[Guid] = @OperatingBomGuid
	------------------------------------------------------------------------------------------------------
	DELETE FROM @StandardQty
	-- Çáßãíå ÇáãÚíÇÑíå Ýí ÍÇáÉ ÇáÊæÒíÚ ÇáãÈÇÔÑÉ
	INSERT INTO @StandardQty
		SELECT	RawQty.[RawMaterialGuid], 
				RawMats.[FinishedProductGuid],
				RawQty.[StageGuid],
				RawMats.[Unit],
				'',
				RawQty.[StandardQuantity] -- ÈæÍÏÉ ÇáãÇÏÉ ÇáÇæáì
		FROM JOCvwJobOrderProductsStandardQuantity RawQty
		INNER JOIN JOCOperatingBOMRawMaterials000 RawMats 
			ON RawMats.[OperatingBOMGuid] = RawQty.[OperatingBOMGuid] 
				AND RawMats.[StageGuid] = RawQty.[StageGuid]
				AND RawMats.[FinishedProductGuid] = RawQty.[MaterialGuid]
				AND RawMats.[RawMaterialGuid] = RawQty.[RawMaterialGuid]
				AND RawMats.[AllocationType] = RawQty.[DistMethod]
		WHERE 
			RawQty.[JobOrderGuid] = @JobOrderGuid 
			AND RawQty.[OperatingBOMGuid] = @OperatingBomGuid
			AND RawQty.[DistMethod] = 1 -- ØÑíÞÉ ÇáÊæÒíÚ: ãÈÇÔÑ

	----- ßãíÉ ÇáãäÊÌ ÇáÊÇã Ýí ÇáäãæÐÌ ÈæÍÏÉ ÇáãÕäÚ ÇáÃæáì -----------------------------------------------------------
	INSERT INTO @FinishedProdBomQtys
		SELECT	FinishedProdBomQtys.[MaterialGuid],
				FinishedProdBomQtys.[FirstProductionUnityQty]
		FROM JocVwJobOrderFinishedGoodsOperatingBOMQtys AS FinishedProdBomQtys
		WHERE FinishedProdBomQtys.[JobOrderGuid] = @JobOrderGuid AND FinishedProdBomQtys.[OperatingBomGuid] = @OperatingBomGuid
	----------------------------------------------------------------------------------------------------------------------
	
	----------------- ãÌãæÚ ÇáÃäÊÇÌ ÇáÊÇã Ýí ÇáäãæÐÌ -------------------------------------------------------------------
	DECLARE @TotalFinishedProdBOMQtys [FLOAT]
	SELECT @TotalFinishedProdBOMQtys = SUM([FinishedProdQty1]) FROM @FinishedProdBomQtys
	-----------------------------------------------------------------------------------------------------------------------

	------ ãÌãæÚ ßãíÇÊ ÇáÅäÊÇÌ ãä ÇáãäÊÌÇÊ ÇáÊÇãÉ Ýí ÃãÑ ÇáÊÔÛíá ÈæÍÏÉ ÇáãÕäÚ ÇáÇæáì --------------------------------
	DECLARE @TotalQty FLOAT 
	SELECT  @TotalQty = SUM(Qty) FROM [dbo].[JOCfnGetJobOrderTotalProductsQtys] (@JobOrderGuid, 1)
	------------------------------------------------------------------------------------------------------------------------
	
	IF(@JointCostMethod = 0)
		BEGIN			
			------ Çáßãíå ÇáãÚíÇÑíå Ýí ÍÇáÉ ÇáÊæÒíÚ ÛíÑ ÇáãÈÇÔÑÉ - ßãíÉ ÅäÊÇÌ -----------------------------------
			INSERT INTO @StandardQty
				SELECT OpertBomRaw.[RawMaterialGuid], 
					OpertBomRaw.[FinishedProductGuid], 
					OpertBomRaw.[StageGuid],
					OpertBomRaw.[Unit],
					'',
					ActualProd.[FirstProductionUnityQty]  --  ßãíÉ ÇáÅäÊÇÌ ÇáÝÚáí ãä ÇáãäÊÌ ÇáÊÇã Ýí ÃãÑ ÇáÊÔÛíá
					*
					(	(	
							OpertBomRaw.[Quantity] 
							* 
							(CASE OpertBomRaw.[Unit] WHEN 2 THEN Mt.Unit2Fact WHEN 3 THEN Mt.Unit3Fact ELSE 1 END)
						) -- ßãíÉ ÇáãÇÏÉ ÇáÃæáíÉ Ýí ÇáäãæÐÌ ÈÇáæÍÏÉ ÇáÃæáì ááãÇÏÉ
						/ 
						@TotalFinishedProdBOMQtys -- ãÌãæÚ ßãíÉ ÇáÅäÊÇÌ Ýí ÇáäãæÐÌ
					)
			FROM JOCOperatingBOMRawMaterials000 OpertBomRaw
			INNER JOIN	JOCvwJobOrderFinishedGoodsBillItemsQtys AS ActualProd ON 
						(ActualProd.[MaterialGuid] = OpertBomRaw.[FinishedProductGuid] 
						AND OpertBomRaw.[OperatingBOMGuid] = ActualProd.[OperatingBOMGuid])
			INNER JOIN mt000 AS MT ON (OpertBomRaw.[RawMaterialGuid] = MT.[GUID])
			WHERE 
				OpertBomRaw.[OperatingBOMGuid] = @OperatingBomGuid
				AND  ActualProd.[JobOrderGuid] = @JobOrderGuid
				AND OpertBomRaw.[AllocationType] = 0 -- ØÑíÞÉ ÇáÊæÒíÚ: ÛíÑ ãÈÇÔÑ
			-----------------------------------------------------------------------------------------------------------
		END
	ELSE IF(@JointCostMethod = 1)
		BEGIN
		------ Çáßãíå ÇáãÚíÇÑíå Ýí ÍÇáÉ ÇáÊæÒíÚ ÛíÑ ÇáãÈÇÔÑÉ - ÞíãÉ ÈíÚíÉ -----------------------------------
			DECLARE @TotalBOMSellPrice [FLOAT]
			
			SELECT @TotalBOMSellPrice = SUM(FinishedGoodsBOMSellPrice.[FinishedGoodsSellPrice]) 
			FROM JOCvwJobOrderOperatingBOMFinishedGoodsSellPrice FinishedGoodsBOMSellPrice
			WHERE	FinishedGoodsBOMSellPrice.[JobOrderGuid] = @JobOrderGuid 
				AND FinishedGoodsBOMSellPrice.[OperatingBOMGuid] = @OperatingBomGuid
			
			INSERT INTO @StandardQty
					SELECT OpertBomRaw.[RawMaterialGuid], 
						OpertBomRaw.[FinishedProductGuid], 
						OpertBomRaw.[StageGuid],
						OpertBomRaw.[Unit],
						'',
						(	ActualProd.[FirstProductionUnityQty]  --  ßãíÉ ÇáÅäÊÇÌ ÇáÝÚáí ãä ÇáãäÊÌ ÇáÊÇã Ýí ÃãÑ ÇáÊÔÛíá
							* 
							FinishedGoodsBOMSellPrice.[FinishedGoodsSellPrice] -- ÇáÞíãÉ ÇáÈíÚíÉ ááãäÊÌ ÇáÊÇã Ýí ÇáäãæÐÌ ÈÓÚÑ ÃãÑ ÇáÊÔÛíá
							* 
							OpertBomRaw.[Quantity]-- ßãíÉ ÇáãÇÏÉ ÇáÃæáíÉ Ýí ÇáäãæÐÌ
						) 
						/  
						(	@TotalBOMSellPrice -- ãÌãæÚ ÞíãÉ ÇáÅäÊÇÌ Ýí ÇáäãæÐÌ ÈÓÚÑ ÃãÑ ÇáÊÔÛíá
							* 
							FinishedBomQty.[FinishedProdQty1] -- ßãíÉ ÇáãäÊÌ ÇáÊÇã Ýí ÇáäãæÐÌ
						)

					FROM JOCOperatingBOMRawMaterials000 [OpertBomRaw]
					INNER JOIN	JOCvwJobOrderFinishedGoodsBillItemsQtys AS [ActualProd] ON 
								(ActualProd.[MaterialGuid] = OpertBomRaw.[FinishedProductGuid] 
								AND OpertBomRaw.[OperatingBOMGuid] = ActualProd.[OperatingBOMGuid] )
					INNER JOIN JOCvwJobOrderOperatingBOMFinishedGoodsSellPrice [FinishedGoodsBOMSellPrice] ON 
						(FinishedGoodsBOMSellPrice.[FinishedGoodsGuid] = ActualProd.[MaterialGuid]
						AND FinishedGoodsBOMSellPrice.[OperatingBOMGuid] = ActualProd.[OperatingBOMGuid])
					INNER JOIN @FinishedProdBomQtys FinishedBomQty ON FinishedBomQty.[FinishedProdGuid] = OpertBomRaw.[FinishedProductGuid] 
					WHERE 
						OpertBomRaw.[OperatingBOMGuid] = @OperatingBomGuid
						AND ActualProd.[JobOrderGuid] = @JobOrderGuid
						AND FinishedGoodsBOMSellPrice.[JobOrderGuid] = @JobOrderGuid
						AND FinishedGoodsBOMSellPrice.[OperatingBOMGuid] = @OperatingBomGuid
						AND OpertBomRaw.[AllocationType] = 0 -- ØÑíÞÉ ÇáÊæÒíÚ: ÛíÑ ãÈÇÔÑ
		------------------------------------------------------------------------------------------------------------
		END
	
	------------ ÇáÃäÊÇÌ ÇáÝÚáí ãä ÊÇÈ ÇáãæÇÏ ÇáÈÇÔÑÉ -----------------------------------------
	INSERT INTO @ActualProduction
		SELECT	ActualProd.[RawMaterialGuid],
				ActualProd.[FinishedGoodGuid],
				ActualProd.[StageGuid],
				OpertBomRaw.[Unit],
				'',
				(ActualProd.[FinishedGoodCost] / ActualProd.[NetValue]) * ActualProd.[NetQty],
				(ActualProd.[NetValue] / ISNULL(ActualProd.[NetQty], 1))
		FROM JOCJobOrderDirectMaterials000 AS ActualProd
		INNER JOIN JOCOperatingBOMRawMaterials000 OpertBomRaw ON 
			OpertBomRaw.[RawMaterialGuid] = ActualProd.[RawMaterialGuid]
			AND OpertBomRaw.[FinishedProductGuid] = ActualProd.[FinishedGoodGuid]
			AND OpertBomRaw.[StageGuid] = ActualProd.[StageGuid]
		WHERE OpertBomRaw.[OperatingBOMGuid] = @OperatingBomGuid
		AND ActualProd.[JobOrderGuid] = @JobOrderGuid
	--------------------------------------------------------------------------------------------

	INSERT INTO @Result ([RawMatGuid], [FinishedProdGuid], [StageGuid],  [RawMatUnit], [FinishedProdBOMUnit], 
							[StandardQty], [ActualProductionQty], [DeviationQty], [Price], [DeviationPercentage])
		SELECT	StandardQty.[RawMatGuid],
				StandardQty.[FinishedProdGuid],
				StandardQty.[StageGuid],
				StandardQty.[RawMatUnit],
				ISNULL(FinishedGoods.[Unit], 1),
				StandardQty.[StandardQty],
				ActualQty.[ActualProductionQty],
				(ActualQty.[ActualProductionQty] - StandardQty.[StandardQty]),
				ActualQty.[Price],
				CASE ISNULL(StandardQty.[StandardQty], 0) WHEN 0 THEN 0.0
				ELSE ((ActualQty.[ActualProductionQty] - StandardQty.[StandardQty]) / StandardQty.[StandardQty])
				END
		FROM @StandardQty AS StandardQty
		INNER JOIN @ActualProduction AS ActualQty 
			ON ( StandardQty.[RawMatGuid] =  ActualQty.[RawMatGuid] 
					AND StandardQty.[FinishedProdGuid] = ActualQty.[FinishedProdGuid] 
					AND StandardQty.[StageGuid] = ActualQty.[StageGuid] )
		INNER JOIN JOCOperatingBOMFinishedGoods000 AS FinishedGoods 
		ON FinishedGoods.[MaterialGuid] = ActualQty.[FinishedProdGuid] AND FinishedGoods.[OperatingBOMGuid] = @OperatingBomGuid

	 ----------------------------------------- ÇáßãíÇÊ ÈæÍÏÉ ÇáäãæÐÌ----------------------------------------------------------
	 UPDATE Result
		SET [FinishedProdActualProdBOMUnit]  =  (	SELECT ISNULL(
															SUM(ActualProd.[Quantity] / 
															ISNULL((CASE FinishedGoods.[Unit] WHEN 2 THEN Mt.[Unit2Fact] WHEN 3 THEN MT.[Unit3Fact] ELSE 1 END), 1))
															, 1) 
													FROM JOCvwJobOrderFinishedGoodsBillItemsQtys ActualProd 
													INNER JOIN JOCOperatingBOMFinishedGoods000 AS FinishedGoods 
														ON (FinishedGoods.[MaterialGuid] = ActualProd.[MaterialGuid]  AND FinishedGoods.[OperatingBOMGuid] = ActualProd.[OperatingBOMGuid])
													INNER JOIN dbo.mt000 AS MT ON MT.[GUID] = ActualProd.[MaterialGuid]
													WHERE ActualProd.[JobOrderGuid] = @JobOrderGuid
														AND ActualProd.[OperatingBOMGuid] = @OperatingBomGuid
														AND ActualProd.[MaterialGuid] = Result.[FinishedProdGuid]	
												)
		FROM @Result AS Result	
	
	
	UPDATE  @Result
		SET [StandardQtyBOMUnit]			= [StandardQty] / [FinishedProdActualProdBOMUnit],
			[ActualProductionQtyBOMUnit]	= [ActualProductionQty] / [FinishedProdActualProdBOMUnit],
			[DeviationQtyBOMUnit]			= [DeviationQty] / [FinishedProdActualProdBOMUnit] 
	------------------------------------------------------------------------------------------------ 

	--------------- ÇáÞíã -------------------------------------------------------------------------
	UPDATE @Result
		SET [StandardValue]		= [StandardQty] * [Price],
			[ActualProdValue]	= [ActualProductionQty] * [Price],
			[DeviationValue]	= [DeviationQty] * [Price]


	Update @Result
		SET [StandardValueBOMUnit]		= [StandardValue] / [FinishedProdActualProdBOMUnit],
			[ActualProdValueBOMUnit]	= [ActualProdValue] / [FinishedProdActualProdBOMUnit],
			[DeviationValueBOMUnit]		= [DeviationValue] / [FinishedProdActualProdBOMUnit]
	------------------------------------------------------------------------------------------------


	UPDATE res
		SET [RawMatCode]		= ISNULL(RawMat.[Code], ''),
			[RawMatName]		= ISNULL(RawMat.[Name], ''),
			[RawMatLatinName]	= ISNULL(RawMat.[LatinName], ''),
			[RawMatIndex]		= ISNULL(RawIndex.[RawMaterialIndex] , 0),
			[RawMatGroupGuid]		= ISNULL(MatGroup.GUID, 0x0),
			[RawMatGroupName]		= ISNULL(MatGroup.Name, ''),
			[RawMatGroupLatinName]	= ISNULL(MatGroup.LatinName, ''),
			[FinishedProdCode]	= ISNULL(FinishedProd.[Code], ''),
			[FinishedProdName]	= ISNULL(FinishedProd.[Name], ''),
			[FinishedProdLatinName] = ISNULL(FinishedProd.[LatinName], ''),
			[FinishedProdIndex]		= ISNULL(FinishedProdIndex.[MaterialIndex], 0 ),
			[StageCode]		 = ISNULL(Stages.[Code], ''),
			[StageName]		 = ISNULL(Stages.[Name], ''),
			[StageLatinName] = ISNULL(Stages.[LatinName], ''),
			[FinishedProdBOMUnitName] = (CASE res.[FinishedProdBOMUnit] 
													WHEN 2 THEN 
														(CASE ISNULL(FinishedProd.[Unit2], '') WHEN '' THEN ISNULL(FinishedProd.[Unity], '') ELSE FinishedProd.[Unit2] END)
													WHEN 3 THEN 
														(CASE ISNULL(FinishedProd.[Unit3], '') WHEN '' THEN ISNULL(FinishedProd.[Unity], '') ELSE FinishedProd.[Unit3] END)
													ELSE ISNULL(FinishedProd.[Unity], '')
											END),
			[RawMatUnitName] = (CASE res.[RawMatUnit] 
										WHEN 2 THEN 
											(CASE ISNULL(RawMat.[Unit2], '') WHEN '' THEN ISNULL(RawMat.[Unity], '') ELSE RawMat.[Unit2] END)
										WHEN 3 THEN 
											(CASE ISNULL(RawMat.[Unit3], '') WHEN '' THEN ISNULL(RawMat.[Unity], '') ELSE RawMat.[Unit3] END)
										ELSE ISNULL(RawMat.[Unity], '')
								END) 
	FROM @Result AS res
	INNER JOIN mt000 RawMat ON RawMat.[GUID] = res.[RawMatGuid]
	INNER JOIN mt000 FinishedProd ON FinishedProd.[GUID] = res.[FinishedProdGuid]
	INNER JOIN gr000 MatGroup ON MatGroup.GUID = RawMat.[GroupGUID]
	INNER JOIN JOCOperatingBOMRawMaterials000 RawIndex 
		ON RawIndex.[RawMaterialGuid] = res.[RawMatGuid] AND RawIndex.[OperatingBOMGuid] = @OperatingBomGuid
	INNER JOIN JOCOperatingBOMFinishedGoods000 FinishedProdIndex 
		ON FinishedProdIndex.[MaterialGuid] = res.[FinishedProdGuid] AND FinishedProdIndex.[OperatingBOMGuid] = @OperatingBomGuid
	LEFT JOIN JOCStages000 Stages ON Stages.[GUID] = res.[StageGuid]

	SELECT  Res.*,
		   BOM.GUID  BomGuid,
		   @JobOrderGuid JobOrderGuid,
		   ProductionLine.Guid ProductionLineGuid
	FROM @Result Res 
	INNER JOIN JobOrder000  JobOrder ON JobOrder.Guid = @JobOrderGuid
	INNER JOIN JOCJobOrderOperatingBOM000 JOcBom ON JOcBom.Guid = @OperatingBomGuid
	INNER JOIN JOCBOM000 BOM ON BOM.GUID = JOcBom.BOMGuid 
	INNER JOIN ProductionLine000 ProductionLine ON ProductionLine.Guid = JobOrder.ProductionLine 
	ORDER BY [RawMatIndex], [StageName], [FinishedProdIndex] 
END
######################################################################
CREATE FUNCTION fn_GetManufactoryFinishedJobOrders
	(	@ManufactoryGuid UNIQUEIDENTIFIER,
		@ProductionLineGuid UNIQUEIDENTIFIER = 0x00
	)
RETURNS TABLE
AS
RETURN ( 
			SELECT * FROM JobOrder000
			WHERE [ManufactoryGUID] = @ManufactoryGuid 
			AND (@ProductionLineGuid = 0x00 OR [ProductionLine] = @ProductionLineGuid) 
			AND [IsActive] = 0
		)
######################################################################
CREATE FUNCTION fn_GetFinishedJobOrdersDeliveredQtys
(	
	@ManuFactoryGuid		[UNIQUEIDENTIFIER],
	@UsedProductionUnitNum	[INT],
	@UsedProductionUnitGuid [UNIQUEIDENTIFIER],
	@StartDate				[DateTime],
	@EndDate				[DateTime]
)
RETURNS @ProductionQtys TABLE 
(
	[JobOrderGuid]				[UNIQUEIDENTIFIER],
	[JobOrderProductionLine]	[UNIQUEIDENTIFIER],
	[PeriodId]					[INT],
	[ProductionQty]				[FLOAT]
) 
BEGIN
 
 	DECLARE @Periods TABLE
	(
		[PeriodId]	[INT], 
		[StartDate] [DATETIME], 
		[EndDate]	[DATETIME]
	) 
	
	INSERT INTO @Periods SELECT [Period],[StartDate],[EndDate] FROM [dbo].[fnGetPeriod](3, @StartDate, @EndDate) 

 INSERT INTO @ProductionQtys
		SELECT	JobOrder.[JobOrderGuid],
				JobOrder.[JobOrderProductionLine],
				Periods.[PeriodId],
				CASE @UsedProductionUnitNum WHEN 1 THEN
					(CASE BOMUnit.Prod1ConvMatUnit 
						WHEN 1 THEN BOMUnit.Prod1ToMatUnitConvFactor 
						WHEN 2 THEN  (BOMUnit.Prod1ToMatUnitConvFactor / MT.Unit2Fact)
						ELSE (BOMUnit.Prod1ToMatUnitConvFactor / MT.Unit3Fact) 
					END) 
					* SUM (Bills.biQty)
				ELSE 
					(CASE WHEN @UsedProductionUnitGuid = 0x0 THEN 0 ELSE 
						(CASE BOMUnit.Prod2ConvMatUnit 
							WHEN 1 THEN BOMUnit.Prod2ToMatUnitConvFactor 
							WHEN 2 THEN  (BOMUnit.Prod2ToMatUnitConvFactor / MT.Unit2Fact)
							ELSE (BOMUnit.Prod2ToMatUnitConvFactor / MT.Unit3Fact) 
						END)
						* SUM (Bills.biQty) 
					END) 
				END AS ProductionQty
		FROM vwBuBi Bills 
		INNER JOIN JocVwJobOrder JobOrder ON Bills.[buCustAcc] = JobOrder.[JobOrderAccount]
		LEFT JOIN JOCOperatingBOMFinishedGoods000 FinishedGoods 
			ON FinishedGoods.[OperatingBOMGuid] = JobOrder.[JobOrderOperatingBOM] 
			AND (Bills.[biMatPtr] = finishedGoods.[MaterialGuid] OR Bills.[biMatPtr] = FinishedGoods.[SpoilageMaterial] )
		LEFT JOIN JOCBOMUnits000 BOMUnit  ON BOMUnit.[MatPtr] = FinishedGoods.[MaterialGuid] 
		LEFT JOIN mt000 MT ON BOMUnit.[MatPtr] = MT.[GUID]
		LEFT JOIN @Periods Periods ON Bills.[buDate] BETWEEN Periods.[StartDate] AND Periods.[EndDate]
		WHERE (JobOrder.[ManufactoryFinishedGoodsBillType] = Bills.[buType]) 
				AND (Bills.[buDate] BETWEEN @StartDate AND @EndDate) 
				AND JobOrder.[JobOrderStatus] = 0 -- OnlyFinishedJobOrders
				AND JobOrder.[JobOrderManufactoryGuid] = @ManuFactoryGuid
		GROUP BY 
		JobOrder.[JobOrderGuid],
		JobOrder.[JobOrderProductionLine],
		Periods.[PeriodId], 
		BOMUnit.[Prod1ConvMatUnit],
		BOMUnit.[Prod2ConvMatUnit],
		BomUnit.[Prod1ToMatUnitConvFactor],
		BomUnit.[Prod2ToMatUnitConvFactor],
		MT.[Unit2Fact], 
		MT.[Unit3Fact],
		FinishedGoods.[Guid]

RETURN

END
######################################################################
CREATE FUNCTION JocFnGetIndirectManufacturalCostsProductionQty
(
	@FacturyGuid			[UNIQUEIDENTIFIER],
	@UsedProductionUnitNum	[INT],
	@UsedProductionUnitGuid [UNIQUEIDENTIFIER],
	@StartDate				[DateTime], 
	@EndDate				[DateTime] 
)
RETURNS @ProductionQtys TABLE 
(
	[ProductionLineGuid]	[UNIQUEIDENTIFIER],
	[ProductionQty]			[FLOAT],
	[PeriodId]				[INT],
	[SumProdQtyPerPeriod]	[FLOAT],
	[ProductionQtyPercent]	[FLOAT]
)  
		
BEGIN

	INSERT INTO @ProductionQtys
		SELECT	Qtys.[JobOrderProductionLine] AS ProductionLineGuid,
				SUM(Qtys.[ProductionQty]) AS ProductionQty,
				Qtys.[PeriodId],
				0.0,
				0.0  
		FROM fn_GetFinishedJobOrdersDeliveredQtys(@FacturyGuid, @UsedProductionUnitNum, @UsedProductionUnitGuid, @StartDate, @EndDate) Qtys
		GROUP BY Qtys.[JobOrderProductionLine], Qtys.[PeriodId] 

	UPDATE Prod
		SET Prod.[SumProdQtyPerPeriod] = (	SELECT SUM(Qtys.[ProductionQty]) 
											FROM @ProductionQtys Qtys
											WHERE Prod.[PeriodId] = Qtys.[PeriodId] )
	FROM @ProductionQtys Prod

	UPDATE @ProductionQtys
		SET [ProductionQtyPercent] = [ProductionQty] / [SumProdQtyPerPeriod]


RETURN 

END

######################################################################
CREATE FUNCTION JocFnGetIndirectManufacturalCostsWorkersHours
(
	@FacturyGuid			[UNIQUEIDENTIFIER],
	@StartDate				[DateTime], 
	@EndDate				[DateTime] 
)
RETURNS @WorkersHours TABLE 
(
	[ProductionLineGuid]	[UNIQUEIDENTIFIER],
	[WorkingHours]			[FLOAT],
	[PeriodId]				[INT],
	[SumWorkingHoursPerPeriod]	[FLOAT],
	[WorkingHoursPercent]	[FLOAT]
)  
		
BEGIN

	 DECLARE @Periods TABLE
	(
		[PeriodId]	[INT], 
		[StartDate] [DATETIME], 
		[EndDate]	[DATETIME]
	) 
	
	INSERT INTO @Periods SELECT [Period],[StartDate],[EndDate] FROM [dbo].[fnGetPeriod](3, @StartDate, @EndDate) 


	INSERT INTO @WorkersHours
		SELECT	JobOrder.[ProductionLine], 
				SUM(LaborAllocDetail.[WorkingHours]), 
				Periods.[PeriodId],
				0.0, 0.0 
		FROM DirectLaborAllocationDetail000 LaborAllocDetail
		INNER JOIN DirectLaborAllocation000 LaborAlloc ON LaborAlloc.[Guid] = LaborAllocDetail.[JobOrderDistributedCost]
		INNER JOIN JobOrder000 JobOrder ON JobOrder.[Guid] = LaborAlloc.[JobOrder]
		INNER JOIN @Periods Periods ON LaborAlloc.[Date] BETWEEN Periods.[StartDate] AND Periods.[EndDate]
		WHERE JobOrder.[IsActive] = 0 AND JobOrder.[ManufactoryGUID] = @FacturyGuid
		AND LaborAlloc.[Date] BETWEEN @StartDate AND @EndDate
		GROUP BY JobOrder.[ProductionLine], Periods.[PeriodId]
	
	UPDATE WorkHours
		SET WorkHours.[SumWorkingHoursPerPeriod] = (	SELECT SUM(WHours.[WorkingHours]) 
														FROM @WorkersHours WHours
														WHERE WorkHours.[PeriodId] = WHours.[PeriodId] )
	FROM @WorkersHours WorkHours
	UPDATE @WorkersHours
	SET [WorkingHoursPercent] = [WorkingHours] / [SumWorkingHoursPerPeriod]
RETURN
END
######################################################################
CREATE FUNCTION JocFnGetIndirectManufacturalCostsOperMachinesHours
(
	@FacturyGuid			[UNIQUEIDENTIFIER],
	@StartDate				[DateTime], 
	@EndDate				[DateTime] 
)
RETURNS @MachinesHours TABLE 
(
	[ProductionLineGuid]	[UNIQUEIDENTIFIER],
	[MachineHours]			[FLOAT],
	[PeriodId]				[INT],
	[SumMachineHoursPerPeriod]	[FLOAT],
	[MachineHoursPercent]	[FLOAT]
)  
		
BEGIN

	DECLARE @Periods TABLE
	(
		[PeriodId]	[INT], 
		[StartDate] [DATETIME], 
		[EndDate]	[DATETIME]
	) 
		
	INSERT INTO @Periods SELECT [Period],[StartDate],[EndDate] FROM [dbo].[fnGetPeriod](3, @StartDate, @EndDate) 
	
	INSERT INTO @MachinesHours
	SELECT	JobOrder.[ProductionLine], 
			SUM(EX.PeriodWorkingMachinsHours), 
			[Periods].[PeriodId],
			0.0,
			0.0  
	FROM JOCJobOrderGeneralExpenses000 EX 
	INNER JOIN @Periods [Periods] ON EX.PeriodDate BETWEEN [Periods].[StartDate] AND [Periods].[EndDate]
	INNER JOIN JobOrder000 JobOrder ON JobOrder.Guid = EX.JobOrderGuid
	WHERE 
		JobOrder.[ManufactoryGUID] = @FacturyGuid 
		 AND 
		JobOrder.[IsActive] = 0
		 AND 
		EX.PeriodDate BETWEEN @StartDate AND @EndDate
	GROUP BY JobOrder.[ProductionLine],
	         [Periods].[PeriodId]
	
	
	UPDATE MachinesHours
	SET MachinesHours.[SumMachineHoursPerPeriod] = (SELECT SUM(MHours.[MachineHours]) 
													FROM @MachinesHours MHours
													WHERE MachinesHours.[PeriodId] = MHours.[PeriodId]
												   )
	FROM @MachinesHours MachinesHours
	
	UPDATE @MachinesHours
	SET [MachineHoursPercent] = [MachineHours] / [SumMachineHoursPerPeriod]
	WHERE [SumMachineHoursPerPeriod] <> 0
	
	UPDATE @MachinesHours
	SET [MachineHoursPercent] = 0
	WHERE [SumMachineHoursPerPeriod] = 0
	
	RETURN
END
######################################################################
CREATE PROC JOCprcIndirectExpensesAnalysesReport
(
		@FacturyGuid		[UNIQUEIDENTIFIER], 
		@StartDate			[DateTime], 
		@EndDate			[DateTime],
		@CurGuid			[UNIQUEIDENTIFIER],
		@ShowSubAccounts	[BIT],
		@ShowStatistics  	[INT] = 0,
		@Save				[INT] = 0
)
AS
	SET NOCOUNT ON
BEGIN
	DECLARE @UsedProductionUnitGuid [UNIQUEIDENTIFIER], @UsedProductionUnitNum [INT],
			@MOHAllocationBase	[INT] -- 0: ProductionQty, 1: WorkersHours, 2: MachineHours

	SET @UsedProductionUnitGuid = (SELECT UsedProductionUnit FROM Manufactory000 WHERE [GUID] = @FacturyGuid)
	SET @UsedProductionUnitNum = 
		(SELECT CASE UsedProductionUnit WHEN ProductionUnitTwo THEN 2 ELSE 1 END FROM  Manufactory000 WHERE [GUID] = @FacturyGuid)
	SET @MOHAllocationBase = (SELECT [MohAllocationBase] FROM Manufactory000 WHERE [GUID] = @FacturyGuid)

	DECLARE @Periods TABLE
	(
		[PeriodId]	[INT], 
		[StartDate] [DATETIME], 
		[EndDate]	[DATETIME]
	) 
	
	-- Get monthly periods
	INSERT INTO @Periods SELECT [Period],[StartDate],[EndDate] FROM [dbo].[fnGetPeriod](3, @StartDate, @EndDate) 

	-- ===== Main Expenses accounts for production lines =======
	DECLARE @ExpensesAccounts AS TABLE
	(
		[ProductionLineGuid]	[UNIQUEIDENTIFIER],
		[ExpensesAccountGuid]	[UNIQUEIDENTIFIER],
		[Processed]				[BIT]
	)

	INSERT INTO @ExpensesAccounts
		SELECT ProdLine.[Guid], ProdLine.[ExpensesAccount], 0
		FROM fn_GetProductionLine(@FacturyGuid) ProdLine
	-- =========================================================

	DECLARE @DirectExpensesAccounts AS TABLE 
	(
		[ProductionLineGuid]	[UNIQUEIDENTIFIER],
		[AccountGuid]			[UNIQUEIDENTIFIER],
		[AccountParent]			[UNIQUEIDENTIFIER],
		[AccountLevel]			[INT],
		[AccountName]			[NVARCHAR](250) COLLATE ARABIC_CI_AI,
		[AccountLatinName]		[NVARCHAR](250) COLLATE ARABIC_CI_AI, 
		[AccountCode]			[NVARCHAR](250)	COLLATE ARABIC_CI_AI
	)

	DECLARE @Cnt [INT]
	SET @Cnt = (SELECT COUNT(*) FROM @ExpensesAccounts WHERE [Processed] = 0)
	-- ========= Get Sub accounts for production lines expenses accounts =========================================================
	WHILE @Cnt > 0
	BEGIN
		DECLARE @ProductionLine [UNIQUEIDENTIFIER], @ExpensesAccount [UNIQUEIDENTIFIER]
		SET @ProductionLine = (SELECT TOP 1 [ProductionLineGuid] FROM @ExpensesAccounts WHERE [Processed] = 0)
		SET @ExpensesAccount = (SELECT [ExpensesAccountGuid] FROM @ExpensesAccounts WHERE [ProductionLineGuid] = @ProductionLine)
	
		INSERT INTO @DirectExpensesAccounts
				SELECT @ProductionLine, Account.[GUID], Account.[ParentGUID], Account.[Level], Account.[Name], 
						Account.[LatinName], Account.[Code]
				FROM fnGetAccountsTree() AS Account
				INNER JOIN fnGetAccountsList(@ExpensesAccount, 1) AS AccountList
					ON AccountList.[GUID] = Account.[GUID]
		UPDATE @ExpensesAccounts
			SET [Processed] = 1
		WHERE [ProductionLineGuid] = @ProductionLine AND [ExpensesAccountGuid] = @ExpensesAccount
		SET @Cnt = (SELECT COUNT(*) FROM @ExpensesAccounts WHERE [Processed] = 0)
	END

	-- ==================== Manufactory Indirect ExpensesAccounts ========================================
	DECLARE @IndirectExpAccounts AS TABLE 
	(
		[AccountGuid]			[UNIQUEIDENTIFIER],
		[AccountParent]			[UNIQUEIDENTIFIER],
		[AccountLevel]			[INT],
		[AccountName]			[NVARCHAR](250) COLLATE ARABIC_CI_AI,
		[AccountLatinName]		[NVARCHAR](250) COLLATE ARABIC_CI_AI, 
		[AccountCode]			[NVARCHAR](250)	COLLATE ARABIC_CI_AI
	)

	DECLARE @IndirectExpensesAccGuid [UNIQUEIDENTIFIER]
	SET @IndirectExpensesAccGuid = (SELECT [MOHIndirectAcc] FROM Manufactory000 WHERE [GUID] = @FacturyGuid)

	INSERT INTO @IndirectExpAccounts
		SELECT aclist.[GUID] , ac.[acParent] , aclist.[Level] , ac.[acName], ac.[acLatinName], ac.[acCode]
		FROM fnGetAccountsList(@IndirectExpensesAccGuid, 0) aclist
		INNER JOIN vwAc ac ON ac.[acGUID] = aclist.[GUID]

	-- ========= Indirect Expenses accounts for manufactory + direct expenses accounts for production lines ================
	DECLARE @AccountsBalances AS TABLE
	(
		[ProductionLineGuid]	[UNIQUEIDENTIFIER],
		[AccountGuid]			[UNIQUEIDENTIFIER],
		[AccountParent]			[UNIQUEIDENTIFIER],
		[AccountLevel]			[INT],
		[AccountName]			[NVARCHAR](250) COLLATE ARABIC_CI_AI,
		[AccountLatinName]		[NVARCHAR](250) COLLATE ARABIC_CI_AI, 
		[AccountCode]			[NVARCHAR](250)	COLLATE ARABIC_CI_AI,
		[PeriodId]				[INT], 
		[StartDate]				[DATETIME], 
		[EndDate]				[DATETIME],
		[Balance]				[FLOAT],
		[EstimationBalance]			[FLOAT]
	)
			
	INSERT INTO @AccountsBalances
		SELECT *, 0, 0
		FROM @DirectExpensesAccounts ac
		CROSS JOIN  @Periods per 
	
	INSERT INTO @AccountsBalances
		SELECT 0x00, *, 0, 0
		FROM @IndirectExpAccounts InDirectExp
		CROSS JOIN  @Periods per

	--Update Estimated InDirectaccounts
		UPDATE AccBal
			SET	AccBal.EstimationBalance = ISNULL(InDirectEstCost.OldEstimatedCost, 0)
		FROM @AccountsBalances AS AccBal 
			INNER JOIN JOCFactoryIndirectExpensesAccounts000 AS InDirectEstCost ON InDirectEstCost.AccountGuid = AccBal.AccountGuid 									
			AND InDirectEstCost.StartPeriodDate = AccBal.StartDate
		WHERE InDirectEstCost.FactoryGuid = @FacturyGuid 
	-- ================================================================================================================
	--Update EstimatedCost Directaccounts
		UPDATE AccBal
			SET	AccBal.EstimationBalance = ISNULL(DirectEstCost.OldEstimatedCost, 0)
		FROM @AccountsBalances AS AccBal 
			INNER JOIN JOCPlDirectExpensesAccounts000 AS DirectEstCost ON DirectEstCost.AccountGuid = AccBal.AccountGuid 
			AND DirectEstCost.StartPeriodDate = AccBal.StartDate 
			WHERE AccBal.ProductionLineGuid = DirectEstCost.PlGuid
	-- ================================Update Total Estimation for parentAccounts================================================================================

	;WITH Tree AS 
	(   SELECT ProductionLineGuid,
			   AccountGuid,
			   AccountParent,
			   PeriodId,
			   EstimationBalance
		FROM @AccountsBalances
		WHERE AccountParent <> 0x0
		UNION ALL

		SELECT 
		 acc.ProductionLineGuid,
		 acc.AccountGuid ,
		 acc.AccountParent,
		 acc.PeriodId,
		 acc.EstimationBalance + t.EstimationBalance AS EstimationBalance
		 FROM @AccountsBalances AS acc
		INNER JOIN Tree AS t ON t.AccountParent= acc.AccountGuid
		WHERE  t.PeriodId = acc.PeriodId  AND t.ProductionLineGuid = acc.ProductionLineGuid
	) 

	UPDATE Dest
		SET EstimationBalance = ISNULL(src.EstimationBalance, Dest.EstimationBalance)
	FROM @AccountsBalances AS Dest
	INNER JOIN(SELECT SUM(EstimationBalance) AS EstimationBalance,
					  AccountGuid,
					  AccountParent,
					  PeriodId,
					  ProductionLineGuid
			  FROM Tree 
			  GROUP by 
			  AccountGuid,
			 AccountParent,
			 PeriodId,
			 ProductionLineGuid
			 ) AS src ON src.AccountGuid = Dest.AccountGuid 
					 AND src.PeriodId = Dest.PeriodId 
					 AND src.ProductionLineGuid = Dest.ProductionLineGuid

	IF(@ShowSubAccounts = 0)
		DELETE FROM @AccountsBalances WHERE AccountGuid NOT IN (SELECT AccountParent FROM @AccountsBalances)

	-- =============================== Calculate Balances =============================================================
	UPDATE Acc
		SET [Balance] = dbo.fnAccount_getBalance(Acc.[AccountGuid], @CurGuid, Acc.[StartDate], Acc.[EndDate] , 0x00)
	FROM @AccountsBalances As Acc
	
	--================================================================================================================

	DECLARE @Result AS TABLE
	(
		[ProductionLineGuid]			[UNIQUEIDENTIFIER],
		[ProductionLineNumber]			[FLOAT],
		[ProductionLineName]			[NVARCHAR](250) COLLATE ARABIC_CI_AI, 
		[ProductionLineLatinName]		[NVARCHAR](250) COLLATE ARABIC_CI_AI,
		[ProductionLineCode]			[NVARCHAR](250)	COLLATE ARABIC_CI_AI,
		[AccountGuid]					[UNIQUEIDENTIFIER],
		[AccountParent]					[UNIQUEIDENTIFIER],
		[AccountLevel]					[INT],
		[AccountName]					[NVARCHAR](250) COLLATE ARABIC_CI_AI, 
		[AccountLatinName]				[NVARCHAR](250) COLLATE ARABIC_CI_AI, 
		[AccountCode]					[NVARCHAR](250)	COLLATE ARABIC_CI_AI,
		[PeriodId]						[INT], 
		[StartDate]						[DATETIME], 
		[EndDate]						[DATETIME],
		[ActualExpenses]				[FLOAT],
		[ManufactoryIndirectExpenses]	[FLOAT],
		[LineType]						[INT] ,-- MainAccount = 0, SubAccount, IndirectExpenses, TotalExpenses, MOHAllocationValue, MOHAllocationValPerUnit
		[EstimatedExpenses]				[FLOAT],
		[AllocationValue]				[FLOAT],
		[Slope]							[FLOAT] default  0,
		[Intercept]						[FLOAT] default  0,
		[RSQ]							[FLOAT] default  0
	)

	INSERT INTO @Result
		SELECT	[ProductionLineGuid], 0, '', '', '', [AccountGuid], [AccountParent], [AccountLevel], [AccountName], 
				[AccountLatinName],
				[AccountCode],
				[PeriodId],
				[StartDate],
				[EndDate],
				[Balance],
				0,
				1,
				[EstimationBalance],
				0, 0, 0, 0
		FROM @AccountsBalances

	UPDATE @Result
		SET [ManufactoryIndirectExpenses] = BAL.[Balance]
	FROM @Result AS Res
	INNER JOIN @AccountsBalances AS BAL ON BAL.[PeriodId] = Res.[PeriodId]
	WHERE BAL.[ProductionLineGuid] = 0x00 AND Res.[ProductionLineGuid] != 0x00 AND BAL.[AccountGuid] = @IndirectExpensesAccGuid
	
	-- =============================== Update Line type for main accounts=============================
	UPDATE Res
		SET [LineType] = 0
	FROM @Result AS Res
	INNER JOIN @ExpensesAccounts MainExpAccounts ON MainExpAccounts.[ExpensesAccountGuid] = Res.[AccountGuid]

	UPDATE Res
		SET [LineType] = 0
	FROM @Result AS Res
	WHERE Res.[AccountGuid] = @IndirectExpensesAccGuid 
	-- ===============================================================================================
	
	DECLARE @LastAccLevelTable AS TABLE
	(
		[ProductionLineGuid]				[UNIQUEIDENTIFIER],
		[PeriodId]							[INT],
		[StartDate]							[DATETIME], 
		[EndDate]							[DATETIME],
		[LastAccLevel]						[INT]
	)

	INSERT INTO @LastAccLevelTable
		SELECT Res.[ProductionLineGuid],
			   Res.[PeriodId],
			   Res.[StartDate],
			   Res.[EndDate],
			   Max(Res.[AccountLevel]) 
		FROM @Result Res
		WHERE Res.[ProductionLineGuid] != 0x00
		GROUP BY 
		Res.[ProductionLineGuid],
		Res.[PeriodId],
		Res.[StartDate],
		Res.[EndDate]

	---- ==================================== äÝÞÇÊ ÕäÇÚíÉ ÚÇãÉ ÛíÑ ãÈÇÔÑÉ ááÎØ =====================================
	DECLARE @MOHAllocationValues AS TABLE
	(
		[ProductionLineGuid]		[UNIQUEIDENTIFIER],
		[MOHAllocationValue]		[FLOAT],
		[PeriodId]					[INT],
		[SumMOHAllocValPerPeriod]	[FLOAT],
		[MOHAllocationValuePercent]	[FLOAT]
	)
	
	IF(@MOHAllocationBase = 0) -- ProductionQty
	BEGIN
		INSERT INTO @MOHAllocationValues
			SELECT * FROM JocFnGetIndirectManufacturalCostsProductionQty(@FacturyGuid, @UsedProductionUnitNum, @UsedProductionUnitGuid, @StartDate, @EndDate)
	END

	IF(@MOHAllocationBase = 1) -- WorkersHours
	BEGIN
		INSERT INTO @MOHAllocationValues
			SELECT * FROM JocFnGetIndirectManufacturalCostsWorkersHours(@FacturyGuid, @StartDate, @EndDate)
	END

	IF(@MOHAllocationBase = 2) -- MachineHours
	BEGIN
		INSERT INTO @MOHAllocationValues
			SELECT * FROM JocFnGetIndirectManufacturalCostsOperMachinesHours(@FacturyGuid, @StartDate, @EndDate)
	END
	
	DECLARE @ProductionLineInDirectExpenses AS TABLE
	(
		[ProductionLineGuid]				[UNIQUEIDENTIFIER],
		[PeriodId]							[INT],
		[StartDate]							[DATETIME], 
		[EndDate]							[DATETIME],
		[Expenses]							[FLOAT],
		[EstimatedExpenses]					[FLOAT]
	)

	INSERT INTO @ProductionLineInDirectExpenses
		SELECT Res.[ProductionLineGuid], Res.[PeriodId], Res.[StartDate], Res.[EndDate], 0.0 ,0.0 
		FROM @Result Res 
		WHERE Res.[ProductionLineGuid] != 0x00
		GROUP BY Res.[ProductionLineGuid], Res.[PeriodId], Res.[StartDate], Res.[EndDate]

	UPDATE @ProductionLineInDirectExpenses
		SET [Expenses] = Res.[ManufactoryIndirectExpenses] * MOH.[MOHAllocationValuePercent]
	FROM @ProductionLineInDirectExpenses AS Expenses
	INNER JOIN @Result AS Res 
		ON Res.[ProductionLineGuid] = Expenses.[ProductionLineGuid] AND Res.[PeriodId] = Expenses.[PeriodId]
	INNER JOIN @MOHAllocationValues AS MOH ON (MOH.[ProductionLineGuid] = Res.[ProductionLineGuid] AND Res.[PeriodId] = MOH.[PeriodId] ) 

	--------------------Update Portion Of Line From Estimated expense--------------------------------------------------------------------------------------
	UPDATE @ProductionLineInDirectExpenses
		SET [EstimatedExpenses] = ISNULL(Src.OldEstimatedCost, 0)
	FROM @ProductionLineInDirectExpenses AS Expenses
	INNER JOIN JOCPlDirectExpensesAccounts000 AS Src ON Expenses.ProductionLineGuid = Src.PlGuid AND Expenses.StartDate = src.StartPeriodDate
	WHERE src.AccountType = 2
	-------------------------------------------------------------------------------------------------------
	INSERT INTO @Result
		SELECT	Expenses.[ProductionLineGuid],
				 0,
				 '',
				 '',
				 '',
				 0x00,
				 0x00, 
				AccLevel.[LastAccLevel] + 1,
				'InDirectExpenses',
				'',
				'',
				Expenses.[PeriodId],
				Expenses.[StartDate],
				Expenses.[EndDate],
				Expenses.[Expenses],
				Expenses.[Expenses],
				2,
				Expenses.[EstimatedExpenses],
				0, 0, 0, 0
		FROM @ProductionLineInDirectExpenses Expenses
		INNER JOIN @LastAccLevelTable AS AccLevel ON AccLevel.[ProductionLineGuid] = Expenses.[ProductionLineGuid]
		AND AccLevel.[PeriodId] = Expenses.[PeriodId]

	---- ======================== Total production line expenses ===========================================================
	DECLARE @ProdLineTotalExpenses AS TABLE
	(
		[ProductionLineGuid]	[UNIQUEIDENTIFIER],
		[MaxAccountLevel]		[INT],
		[PeriodId]				[INT],
		[StartDate]				[DATETIME], 
		[EndDate]				[DATETIME],
		[TotalExpenses]			[FLOAT],
		[EstimatedTotalExpenses] [FLOAT]
	)

	INSERT INTO @ProdLineTotalExpenses
		SELECT	Res.[ProductionLineGuid],
				0,
				Res.[PeriodId],
				Res.[StartDate],
				Res.[EndDate],
				dbo.fnAccount_getBalance(Res.[AccountGuid], @CurGuid, Res.[StartDate], Res.[EndDate] , 0x00),
				0
		FROM @Result AS Res
		INNER JOIN @ExpensesAccounts AS ExpAcc ON ExpAcc.[ExpensesAccountGuid] = Res.[AccountGuid]

	UPDATE @ProdLineTotalExpenses
		SET [TotalExpenses] = [TotalExpenses] + InDirectExp.[Expenses]
	FROM @ProdLineTotalExpenses Expenses
	INNER JOIN @ProductionLineInDirectExpenses AS InDirectExp 
		ON InDirectExp.[ProductionLineGuid] = Expenses.[ProductionLineGuid] 
		AND InDirectExp.[PeriodId] = Expenses.[PeriodId]

	UPDATE @ProdLineTotalExpenses
		SET [MaxAccountLevel] = AccLevel.[LastAccLevel] + 2
	FROM @ProdLineTotalExpenses TotExp
	INNER JOIN @LastAccLevelTable AccLevel ON AccLevel.[ProductionLineGuid] = TotExp.[ProductionLineGuid]
		AND AccLevel.[PeriodId] = TotExp.[PeriodId]
		
	UPDATE @ProdLineTotalExpenses
		SET [EstimatedTotalExpenses] = ISNULL(src.OldEstimatedCost , 0)
	FROM @ProdLineTotalExpenses TotExp
	INNER JOIN JOCPlDirectExpensesAccounts000 AS Src ON Src.[PlGuid] = TotExp.[ProductionLineGuid] AND Src.StartPeriodDate = TotExp.StartDate
	WHERE src.AccountType = 3

	INSERT INTO @Result
		SELECT DISTINCT	Expenses.[ProductionLineGuid], 0, '', '', '', 0x00, 0x00, 
				Expenses.[MaxAccountLevel], 'TotalExpenses', '', '', 
				Expenses.[PeriodId], Expenses.[StartDate], Expenses.[EndDate], Expenses.[TotalExpenses], Expenses.[TotalExpenses], 3, Expenses.EstimatedTotalExpenses, 0, 0, 0, 0
		FROM @ProdLineTotalExpenses Expenses

	---- ========== ÚÏÏ ÓÇÚÇÊ ÇáÃÌæÑ ÇáãÈÇÔÑÉ. / ÚÏÏ ÓÇÚÇÊ ÊÔÛíá ÇáÂáÇÊ. / ßãíÉ ÇáÅäÊÇÌ ÈæÍÏÉ ÃÓÇÓ ÇáÊæÒíÚ Ýí ÇáãÕäÚ. ========

	INSERT INTO @Result
		SELECT DISTINCT	AccLevel.[ProductionLineGuid], 0, '', '', '', 0x00, 0x00,
				AccLevel.[LastAccLevel] + 3, 
				CASE @MOHAllocationBase 
					WHEN 0 THEN 'TotalProdQty'
					WHEN 1 THEN 'TotalWorkingHours' 
					ELSE 'TotalMachinesHours' 
				END, '', '',
				AccLevel.[PeriodId], AccLevel.[StartDate], AccLevel.[EndDate], 
				ISNULL(MOH.[MOHAllocationValue], 0.0), ISNULL(MOH.[MOHAllocationValue], 0.0), 4,
				ISNULL(Src.OldEstimatedCost , 0), 0, 0, 0, 0
		FROM @LastAccLevelTable AccLevel
		LEFT JOIN @MOHAllocationValues MOH ON AccLevel.[ProductionLineGuid] = MOH.[ProductionLineGuid]
			AND AccLevel.[PeriodId] = MOH.[PeriodId]
		LEFT JOIN JOCPlDirectExpensesAccounts000 AS Src ON AccLevel.[ProductionLineGuid] = Src.PlGuid AND AccLevel.StartDate = src.StartPeriodDate AND src.AccountType = 4

	---- =========== ßáÝÉ ÓÇÚÉ ÇáÃÌæÑ ÇáãÈÇÔÑÉ. / ßáÝÉ ÓÇÚÉ ÊÔÛíá ÇáÂáÇÊ. / ßáÝÉ æÍÏÉ ÃÓÇÓ ÇáÊæÒíÚ Ýí ÇáãÕäÚ. ================
	INSERT INTO @Result
		SELECT DISTINCT	Expenses.[ProductionLineGuid], 0, '', '', '', 0x00, 0x00, 
				AccLevel.[LastAccLevel] + 4, 'ExpensesPerUnit', '', '', 
				Expenses.[PeriodId], Expenses.[StartDate], Expenses.[EndDate], 
				CASE ISNULL(MOH.[MOHAllocationValue], 0) WHEN 0 THEN 0 ELSE  Expenses.[TotalExpenses] / MOH.[MOHAllocationValue] END, 
				0.0, 5 , ISNULL(Src.OldEstimatedCost , 0), ISNULL(MOH.[MOHAllocationValue], 0), 0, 0, 0
		FROM @ProdLineTotalExpenses Expenses
		INNER JOIN @LastAccLevelTable AccLevel ON AccLevel.[ProductionLineGuid] = Expenses.ProductionLineGuid
			AND AccLevel.[PeriodId] = Expenses.[PeriodId]
		LEFT JOIN @MOHAllocationValues MOH ON AccLevel.[ProductionLineGuid] = MOH.[ProductionLineGuid]
			AND AccLevel.[PeriodId] = MOH.[PeriodId]
		LEFT JOIN JOCPlDirectExpensesAccounts000 AS Src ON AccLevel.[ProductionLineGuid] = Src.PlGuid AND AccLevel.StartDate = src.StartPeriodDate AND src.AccountType = 5

---- ===========================================================================================================================

	UPDATE Res
		SET Res.[ProductionLineName] = ProdLine.[Name],
			Res.[ProductionLineCode] = ProdLine.[Code],
			Res.[ProductionLineLatinName] = ProdLine.[LatinName],
			Res.[ProductionLineNumber] = ProdLine.[Number]
	FROM @Result Res
	INNER JOIN ProductionLine000 ProdLine ON Res.[ProductionLineGuid] = ProdLine.[Guid]

	DECLARE @MaxProdLineNumber FLOAT
	SET @MaxProdLineNumber = (SELECT Max(Number) FROM ProductionLine000 where ManufactoryGUID = @FacturyGuid)

	Update Res
		SET Res.[ProductionLineNumber] = @MaxProdLineNumber + 1
	FROM @Result Res
	WHERE Res.[ProductionLineGuid] = 0x00

	UPDATE Res
		SET Res.[AccountName] = Ac.[acName],
			Res.[AccountCode] = Ac.[acCode],
			Res.[AccountLatinName] = Ac.[acLatinName]
	FROM @Result Res
	INNER JOIN vwAc Ac ON Res.[AccountGuid] = Ac.[acGUID]
	
--------------المؤشرات الاحصائية----------------------------
	IF(@ShowStatistics & 16 <> 0)
	BEGIN	
		SELECT ProductionLineGuid,
			   AccountName,
			   AccountGuid,
			   AVG(ActualExpenses) AS Average
		INTO #AVG FROM @Result
		 GROUP BY  ProductionLineGuid,
				   AccountName,
				   AccountGuid

		DECLARE @Average FLOAT = (SELECT SUM(Average) Average FROM #AVG WHERE AccountName IN ('TotalProdQty', 'TotalWorkingHours', 'TotalMachinesHours') 
																	  AND AccountGuid = 0x0)
		SELECT 
			Res.ProductionLineGuid,
		    Res.AccountGuid,
		    Res.AccountName,
		    Res.StartDate AS Period,
		    Res.ActualExpenses - CASE WHEN Res.ProductionLineGuid <> 0x0 THEN average.Average ELSE @Average END AS [x- x'],
		    POWER(Res.ActualExpenses - CASE WHEN Res.ProductionLineGuid <> 0x0 THEN average.Average ELSE @Average END, 2) AS [(x- x')2]
		INTO #GenralDirect 
		FROM @Result AS Res
			INNER JOIN #AVG AS average ON average.ProductionLineGuid = Res.ProductionLineGuid
										 AND average.AccountGuid = Res.AccountGuid 
										 AND average.AccountName = Res.AccountName
		-----------------Slope_And_RSQ--------------------------------
			SELECT  
				CASE WHEN y.ProductionLineGuid <> 0x0 THEN( CASE WHEN SUM(x.[(x- x')2]) = 0 THEN 0 ELSE SUM(x.[x- x'] * y.[x- x']) / SUM(x.[(x- x')2]) END) 
				ELSE (CASE WHEN SUM(xIndirect.[(x- x')2]) = 0 THEN 0 ELSE SUM(xIndirect.[x- x'] * y.[x- x']) / SUM(xIndirect.[(x- x')2]) END) END AS Slope ,
				CASE WHEN y.ProductionLineGuid <> 0x0 THEN(CASE WHEN POWER(SUM(y.[(x- x')2] ) * SUM(x.[(x- x')2]), .5) = 0 THEN 0 ELSE SUM(x.[x- x'] * y.[x- x']) / POWER(SUM(y.[(x- x')2] ) * SUM(x.[(x- x')2]), .5) END) 
				ELSE (CASE WHEN POWER(SUM(y.[(x- x')2] ) * SUM(xIndirect.[(x- x')2]), .5) = 0 THEN 0 ELSE SUM(xIndirect.[x- x'] * y.[x- x']) / POWER(SUM(y.[(x- x')2] ) * SUM(xIndirect.[(x- x')2]), .5) END) END AS RSQ,
				y.ProductionLineGuid,
				y.AccountName,
				y.AccountGuid
			INTO #Slope FROM #GenralDirect AS y
			INNER JOIN #GenralDirect AS x ON x.ProductionLineGuid = y.ProductionLineGuid AND x.Period = y.Period 
				AND x.AccountName IN ('TotalProdQty','TotalWorkingHours' ,'TotalMachinesHours') AND x.AccountGuid = 0x0
			LEFT JOIN #GenralDirect AS xIndirect ON xIndirect.ProductionLineGuid = 0x0 AND xIndirect.AccountGuid = y.AccountGuid
			GROUP BY y.ProductionLineGuid,
					 y.AccountName,
					 y.AccountGuid

		--------Intercept-------
		UPDATE @Result 
		SET Intercept = IntCept.intercept,
			RSQ       = IntCept.RSQ,
			Slope     = IntCept.Slope
		FROM @Result AS Res
		INNER JOIN (
		SELECT 
			average.Average - (Slp.Slope * avGen.Average) AS intercept,
			Slp.Slope,
			Slp.RSQ,
			average.ProductionLineGuid,
			average.AccountGuid,
			average.AccountName
		FROM #AVG AS average
		INNER JOIN #AVG AS avGen ON avGen.ProductionLineGuid = average.ProductionLineGuid AND avGen.AccountName IN ('TotalProdQty','TotalWorkingHours' ,'TotalMachinesHours') AND avGen.AccountGuid = 0x0
		INNER JOIN #Slope AS Slp ON average.ProductionLineGuid = Slp.ProductionLineGuid AND average.AccountGuid = Slp.AccountGuid AND average.AccountName = Slp.AccountName) AS IntCept ON IntCept.ProductionLineGuid = Res.ProductionLineGuid AND res.AccountGuid = IntCept.AccountGuid AND Res.AccountName = IntCept.AccountName
	END

	SELECT * 
	FROM @Result Res
	ORDER BY Res.[ProductionLineNumber], Res.[AccountLevel], Res.[AccountCode], Res.[PeriodId]

	IF(@Save = 1)
		RETURN
	---- ========== Footer Result ============================================================
	DECLARE @FooterResult AS TABLE
	(
		[AccountName]		[NVARCHAR](250),
		[PeriodId]			[INT],
		[ActualExpenses]	[FLOAT],
		[EstimatedExpenses] [FLOAT],
		[Slope]				[FLOAT] default  0,
		[Intercept]			[FLOAT] default  0,
		[RSQ]				[FLOAT] default  0
	)
	INSERT INTO @FooterResult
		SELECT	'1 - TotalExpenses', [PeriodId], SUM([ActualExpenses]), SUM([EstimatedExpenses]), 0, 0, 0 FROM @Result Res
		WHERE Res.[LineType] = 0
		GROUP BY [PeriodId]

	INSERT INTO @FooterResult
		SELECT '2 - TotalMOHAllocationValues', [PeriodId], SUM([ActualExpenses]), SUM([EstimatedExpenses]), 0, 0, 0 FROM @Result Res
		WHERE Res.[AccountName] = 'TotalProdQty' OR Res.[AccountName] = 'TotalWorkingHours' OR Res.[AccountName] = 'TotalMachinesHours'
		GROUP BY [PeriodId]
	
	INSERT INTO @FooterResult
		SELECT '3 - TotalExpensesPerUnit', [PeriodId], 0 , 0, 0, 0, 0
		FROM @Result Res
		WHERE Res.[AccountName] = 'ExpensesPerUnit' 
		GROUP BY [PeriodId]

	UPDATE Footer
		SET [ActualExpenses] = (SELECT [ActualExpenses] FROM @FooterResult Res1 WHERE [AccountName] = '1 - TotalExpenses' AND Res1.[PeriodId] = Footer.[PeriodId]),
			[EstimatedExpenses] =  (SELECT [EstimatedExpenses] FROM @FooterResult Res1 WHERE [AccountName] = '1 - TotalExpenses' AND Res1.[PeriodId] = Footer.[PeriodId])
	FROM @FooterResult Footer
	WHERE Footer.[AccountName] = '3 - TotalExpensesPerUnit'

	UPDATE Footer
		SET Footer.[ActualExpenses] = Footer.[ActualExpenses] / 
									ISNULL((	
											SELECT CASE [ActualExpenses] WHEN 0 THEN 1 ELSE [ActualExpenses] END FROM @FooterResult Res1 
											WHERE Res1.[AccountName] = '2 - TotalMOHAllocationValues' AND Res1.[PeriodId] = Footer.[PeriodId]
										), 1) ,
		Footer.[EstimatedExpenses] = Footer.[EstimatedExpenses] / 
									ISNULL((	
											SELECT CASE [EstimatedExpenses] WHEN 0 THEN 1 ELSE [EstimatedExpenses] END FROM @FooterResult Res1 
											WHERE Res1.[AccountName] = '2 - TotalMOHAllocationValues' AND Res1.[PeriodId] = Footer.[PeriodId]
										), 1)
	FROM @FooterResult Footer
	WHERE Footer.[AccountName] = '3 - TotalExpensesPerUnit'

	UPDATE Footer
		SET [ActualExpenses] = 0
	FROM @FooterResult Footer
	INNER JOIN @FooterResult Footer2 ON Footer.[PeriodId] = Footer2.[PeriodId]
	WHERE Footer.[AccountName] = '3 - TotalExpensesPerUnit'
	AND Footer2.[AccountName] = '2 - TotalMOHAllocationValues' AND Footer2.[ActualExpenses] = 0
	
	IF(@ShowStatistics & 16 <> 0)
	BEGIN	

		SELECT 
			AVG(ActualExpenses) AS Average,
			AccountName
		INTO #FooterResultAvg
		FROM @FooterResult
		GROUP BY AccountName
	
		;WITH Cte AS
		(
			SELECT 
				y.ActualExpenses - FootAvg.Average AS [x-x'],
				POWER((y.ActualExpenses - FootAvg.Average), 2) AS [(x-x')2], 
				y.AccountName,
				y.PeriodId
			FROM @FooterResult AS y
			INNER JOIN #FooterResultAvg AS FootAvg ON FootAvg.AccountName = y.AccountName
		)
	
		, Slope_RSQ AS
		( 
			SELECT 
				CASE WHEN SUM(x.[(x-x')2]) = 0 THEN 0 ELSE SUM(x.[x-x'] * y.[x-x']) / SUM(x.[(x-x')2]) END AS slp,
				CASE WHEN POWER(SUM(x.[(x-x')2]) * SUM(x.[(x-x')2]) , .5) = 0 THEN 0 ELSE SUM(x.[x-x'] * y.[x-x']) / POWER(SUM(x.[(x-x')2]) * SUM(x.[(x-x')2]) , .5) END AS RsQ,
				y.AccountName
			FROM Cte AS y
				INNER JOIN Cte AS x ON x.PeriodId = y.PeriodId 
				WHERE x.AccountName IN ('2 - TotalMOHAllocationValues', '2 - TotalProdQty', '2 - TotalMachinesHours') 
			GROUP BY y.AccountName
		)

		UPDATE Res 
		SET Res.Slope = slRs.slp,
			Res.RSQ = slRs.RsQ,
			Res.Intercept = (FootAvg.Average - (slRs.slp * FootAvgx.Average))
		FROM @FooterResult AS Res
		INNER JOIN #FooterResultAvg AS FootAvg ON FootAvg.AccountName = Res.AccountName
		INNER JOIN Slope_RSQ AS slRs ON slRs.AccountName = Res.AccountName
		LEFT JOIN Slope_RSQ AS x ON x.AccountName IN ('2 - TotalMOHAllocationValues', '2 - TotalProdQty', '2 - TotalMachinesHours') 
		LEFT JOIN #FooterResultAvg AS FootAvgx ON FootAvgx.AccountName IN ('2 - TotalMOHAllocationValues', '2 - TotalProdQty', '2 - TotalMachinesHours') 
	END
	SELECT * FROM @FooterResult ORDER BY [AccountName], [PeriodId]
-- ===================================================================================================================
END

######################################################################
CREATE FUNCTION JOCfnCheckProductionLinePeriods(@StartDate DATETIME, @EndDate DATETIME, @ProductionLineGuid UNIQUEIDENTIFIER)
RETURNS BIT
AS
BEGIN

	DECLARE @PeriodsCount INT = (SELECT COUNT(*) FROM Plcosts000 cost  
								WHERE cost.ProductionLine = @ProductionLineGuid	
								AND cost.StartPeriodDate BETWEEN (DATEADD(month, DATEDIFF(month, 0, @StartDate), 0)) AND (DATEADD(d, -1, DATEADD(m, DATEDIFF(m, 0, @EndDate) + 1, 0)))) 

	DECLARE @MonthsCount INT = DATEDIFF(MONTH, @StartDate, @EndDate);

	RETURN CASE WHEN @MonthsCount = 0 THEN 1 WHEN @PeriodsCount = @MonthsCount + 1 THEN 1 ELSE 0 END
				
END
######################################################################

CREATE FUNCTION JOCfnCalcJobOrdersDirectLabrs
(	
	@ManufactoryGuid	[UNIQUEIDENTIFIER] = 0x00,
	@JobOrderGuid		[UNIQUEIDENTIFIER] = 0x00,
	@StartDate			[DATETIME] = '1/1/1980',
	@EndDate			[DATETIME] = '1/1/1980',
	@CostRank			[INT] = -1
)
RETURNS TABLE
AS
RETURN
(
	SELECT	Labors.[JobOrder] AS JobOrderGuid,
			Workers.[Employee] AS WorkerGuid, 
			(CASE WHEN ((BOM.[StagesEnabled] & BOM.[UseStagesInRequestionAndLabor]) = 0) 
				THEN 0x00 ELSE StagesDist.[StageGuid] END)AS StageGuid, 
			(CASE WHEN ((BOM.[StagesEnabled] & BOM.[UseStagesInRequestionAndLabor]) = 0) 
				THEN '' ELSE StagesDist.[StageName] END)AS StageName,
			(CASE WHEN ((BOM.[StagesEnabled] & BOM.[UseStagesInRequestionAndLabor]) = 0) 
				THEN '' ELSE Stages.[LatinName] END)AS StageLatinName ,
			Workers.[WorkingHourCost] AS WorkingHourCost,
			(CASE	WHEN ((BOM.[StagesEnabled] & BOM.[UseStagesInRequestionAndLabor]) = 0)
					THEN SUM(Workers.[WorkingHours])
					ELSE SUM(StagesDist.[Hours])
					END) AS TotalWorkingHours,
			(CASE	WHEN ((BOM.[StagesEnabled] & BOM.[UseStagesInRequestionAndLabor]) = 0)
					THEN (SUM(Workers.[WorkingHours]) * [WorkingHourCost])
					ELSE (SUM(StagesDist.[Hours]) * Workers.[WorkingHourCost]) END) AS [DistWorkerLabor]
	FROM DirectLaborAllocation000 AS Labors
	INNER JOIN DirectLaborAllocationDetail000 AS Workers ON Workers.[JobOrderDistributedCost] = Labors.[Guid]
	LEFT JOIN VwJOCWorkHoursDistribution AS StagesDist ON StagesDist.[ParentGuid] = Workers.[Guid]
	LEFT JOIN JOCStages000 AS Stages ON Stages.[GUID] = StagesDist.[StageGuid]
	LEFT JOIN JobOrder000 AS JobOrder ON JobOrder.[GUID] =  Labors.[JobOrder]
	LEFT JOIN JOCJobOrderOperatingBOM000 OperatingBOM ON JobOrder.[OperatingBOMGuid] = OperatingBOM.[Guid]
	LEFT JOIN JOCBOM000 BOM ON OperatingBOM.[BOMGuid] = BOM.[GUID]
	WHERE   (JobOrder.[IsActive] = 0) -- Finished Job Orders
		AND (@StartDate = '1/1/1980' OR JobOrder.[StartDate] >= (DATEADD(month, DATEDIFF(month, 0, @StartDate), 0)))
		AND (@EndDate = '1/1/1980' OR JobOrder.[EndDate] <= (DATEADD(d, -1, DATEADD(m, DATEDIFF(m, 0, @EndDate) + 1, 0))))
		AND (@JobOrderGuid = 0x00 OR @JobOrderGuid = JobOrder.[Guid])
		AND (@ManufactoryGuid = 0x00 OR JobOrder.[ManufactoryGUID] = @ManufactoryGuid )
		AND (@CostRank = -1 OR OperatingBOM.[CostRank] = @CostRank)
	GROUP BY 
		Labors.[JobOrder],
		(BOM.[StagesEnabled] & BOM.[UseStagesInRequestionAndLabor]),
		Workers.[Employee], 
		StagesDist.[StageGuid], 
		StagesDist.[StageName], 
		Stages.[LatinName],
		Workers.[WorkingHourCost]
)
######################################################################
CREATE PROCEDURE prcGetJobOrdersInDirectLaborsDistPrice
(
	@ManufactoryGuid	[UNIQUEIDENTIFIER] = 0x00,
	@JobOrderGuid		[UNIQUEIDENTIFIER] = 0x00,
	@StartDate			[DATETIME] = '1/1/1980',
	@EndDate			[DATETIME] = '1/1/1980',
	@CostRank			[INT] = -1
)
AS
BEGIN
	SET NOCOUNT ON;

	CREATE TABLE [#WorkersLabors]
    ( 
		[JobOrderGuid]		[UNIQUEIDENTIFIER],
		[WorkerGuid]		[UNIQUEIDENTIFIER], 
		[StageGuid]			[UNIQUEIDENTIFIER], 
		[StageName]			[NVARCHAR](Max),
		[StageLatinName]	[NVARCHAR](max),
		[WorkingHourCost]	[FLOAT],
		[TotalWorkingHours] [FLOAT],
		[DistWorkerLabor]	[FLOAT]
    )

	INSERT INTO [#WorkersLabors]
		SELECT	DirectLabors.[JobOrderGuid],
				DirectLabors.[WorkerGuid],
				DirectLabors.[StageGuid],
				DirectLabors.[StageName],
				DirectLabors.[StageLatinName],
				DirectLabors.[WorkingHourCost],
				DirectLabors.[TotalWorkingHours],
				DirectLabors.[DistWorkerLabor]
		FROM [dbo].[JOCfnCalcJobOrdersDirectLabrs](@ManufactoryGuid, @JobOrderGuid, @StartDate, @EndDate, @CostRank) DirectLabors
		INNER JOIN JobOrder000 JobOrder ON JobOrder.[GUID] = DirectLabors.[JobOrderGuid]
		INNER JOIN JOCJobOrderOperatingBOM000 AS OperatingBOM ON JobOrder.[OperatingBOMGuid] = OperatingBOM.[Guid]
		WHERE OperatingBOM.[JointCostsAllocationType] = 1 -- SellValue
		AND JobOrder.[IsActive] = 0 -- finished jobOrders only

	CREATE TABLE [#FinishedGoodsSellPrices]
	(
		[JobOrderGuid]				[UNIQUEIDENTIFIER], 
		[FinishedGoodsGuid]			[UNIQUEIDENTIFIER], 
		[OperatingBOMGuid]			[UNIQUEIDENTIFIER], 
		[FinishedGoodsSellPrice]	[FLOAT]
	)

	INSERT INTO [#FinishedGoodsSellPrices]
		SELECT	SellPrices.[JobOrderGuid],
				SellPrices.[FinishedGoodsGuid],
				SellPrices.[OperatingBOMGuid],
				SellPrices.[FinishedGoodsSellPrice]
		FROM JOCvwJobOrderFinishedGoodsItemsSellPrice as SellPrices
		INNER JOIN [#WorkersLabors] Labors ON Labors.[JobOrderGuid] = SellPrices.[JobOrderGuid]
		INNER JOIN JOCOperatingBOMWagesAndMOH000 Dist 
			ON Dist.[FinishedProductGuid] = SellPrices.[FinishedGoodsGuid]
				AND Dist.[OperatingBOMGuid] = SellPrices.[OperatingBOMGuid]
		WHERE Dist.[WagesAllocationType] = 0 -- In direct allocation 
		
	CREATE TABLE [#JobOrdersTotalSellPrices]
	(
		[JobOrderGuid]			[UNIQUEIDENTIFIER],
		[TotalSellPrice]		[FLOAT]
	)

	INSERT INTO [#JobOrdersTotalSellPrices]
		SELECT DISTINCT [JobOrderGuid], 0 FROM [#WorkersLabors]
	
	UPDATE SellPrices
		SET [TotalSellPrice] = (	SELECT SUM(items.[FinishedGoodsSellPrice]) 
									FROM JOCvwJobOrderFinishedGoodsItemsSellPrice items
									WHERE items.[JobOrderGuid] = SellPrices.[JobOrderGuid]	)
	FROM [#JobOrdersTotalSellPrices] SellPrices

	CREATE TABLE [#WorkersLaborsSellPriceDist]
	( 
		[JobOrderGuid]			[UNIQUEIDENTIFIER],
		[FinishedGoodGuid]		[UNIQUEIDENTIFIER], 
		[WorkerGuid]			[UNIQUEIDENTIFIER],
		[StageGuid]				[UNIQUEIDENTIFIER], 
		[StageName]				[NVARCHAR](Max),	
		[StageLatinName]		[NVARCHAR](max),	
		[DistWorkerLabor]		[FLOAT],			
		[InDirectValue]			[FLOAT],			
		[WorkingHourCost]		[FLOAT]				
	)
	
	INSERT INTO [#WorkersLaborsSellPriceDist]
		SELECT	Labors.[JobOrderGuid], 
				FinishedGoods.[FinishedGoodGuid], 
				Labors.[WorkerGuid],
				(Labors.[StageGuid]), 
				(Labors.[StageName]),
				(Labors.[StageLatinName]),
				Labors.[DistWorkerLabor],
				(0) AS InDirectValue,
				Labors.[WorkingHourCost] 
	--FROM JOCvwJobOrderFinishedGoodsBillItemsQtys AS ViewQty 
	FROM JOCJobOrdersBOMFinishedGoods FinishedGoods
	INNER JOIN [#WorkersLabors] AS Labors ON Labors.[JobOrderGuid] = FinishedGoods.[JobOrderGuid]
	
	UPDATE [#WorkersLaborsSellPriceDist]
		SET [InDirectValue] = ISNULL(CASE TotalPrice.[TotalSellPrice] WHEN 0 THEN 0 ELSE
								(((SellPrices.[FinishedGoodsSellPrice] /  TotalPrice.[TotalSellPrice]) * PriceDist.[DistWorkerLabor]))
								END, 0) 
	FROM [#WorkersLaborsSellPriceDist] as PriceDist
	INNER JOIN [#FinishedGoodsSellPrices] AS SellPrices 
		ON SellPrices.[FinishedGoodsGuid] = PriceDist.[FinishedGoodGuid]  AND SellPrices.[JobOrderGuid] = PriceDist.[JobOrderGuid]
	INNER JOIN [#JobOrdersTotalSellPrices] AS TotalPrice ON TotalPrice.[JobOrderGuid] = PriceDist.[JobOrderGuid]
	
	SELECT * FROM [#WorkersLaborsSellPriceDist]
	
	DROP TABLE [#WorkersLabors]
	DROP TABLE [#FinishedGoodsSellPrices]
	DROP TABLE [#WorkersLaborsSellPriceDist]
	DROP TABLE [#JobOrdersTotalSellPrices]

END
######################################################################
CREATE FUNCTION JOCfnGetJobOrdersTotalProductsQtys()
RETURNS TABLE
AS
-- ãÌãæÚ ßãíÇÊ ÇáÅäÊÇÌ ãä ÇáãäÊÌÇÊ ÇáÊÇãÉ Ýí ÃæÇãÑ ÇáÊÔÛíá ÈæÍÏÉ ÇáãÕäÚ
RETURN(
	SELECT
			items.[JobOrderGuid],
			items.[ManufUsedUnit],
			(CASE items.[ManufUsedUnit] WHEN 1 THEN SUM(items.FirstProductionUnityQty)
				WHEN 2 THEN SUM(items.SecondProductionUnityQty)
				ELSE SUM(items.Quantity)
			END) AS Qty
	FROM JOCvwJobOrderFinishedGoodsBillItemsQtys items
	Group BY items.[JobOrderGuid], items.[ManufUsedUnit]
)
######################################################################
CREATE PROCEDURE prcGetJobOrdersInDirectLaborsDistQty
(	
	@ManufactoryGuid	[UNIQUEIDENTIFIER] = 0x00,
	@JobOrderGuid		[UNIQUEIDENTIFIER] = 0x00,
	@StartDate			[DATETIME] = '1/1/1980',
	@EndDate			[DATETIME] = '1/1/1980',
	@CostRank			[INT] = -1
)
AS
BEGIN
	SET NOCOUNT ON;

	CREATE TABLE [#WorkersLabors]
    ( 
		[JobOrderGuid]		[UNIQUEIDENTIFIER], 
		[WorkerGuid]		[UNIQUEIDENTIFIER], 
		[StageGuid]			[UNIQUEIDENTIFIER], 
		[StageName]			[NVARCHAR](Max),
		[StageLatinName]	[NVARCHAR](max),
		[WorkingHourCost]	[FLOAT],
		[TotalWorkingHours] [FLOAT],
		[DistWorkerLabor]	[FLOAT]
    )

	INSERT INTO [#WorkersLabors]
		SELECT * FROM [dbo].[JOCfnCalcJobOrdersDirectLabrs](@ManufactoryGuid, @JobOrderGuid, @StartDate, @EndDate, @CostRank)

	CREATE TABLE [#JobOrdersTotalProductionQtys]
	(
		[JobOrderGuid]			[UNIQUEIDENTIFIER],
		[UsedProductionUnit]	[INT],
		[TotalProductionQty]	[FLOAT]
	)

	INSERT INTO [#JobOrdersTotalProductionQtys]
		SELECT TotalQtys.[JobOrderGuid], TotalQtys.[ManufUsedUnit], TotalQtys.[Qty] 
		FROM JOCfnGetJobOrdersTotalProductsQtys() AS TotalQtys
		INNER JOIN JobOrder000 JobOrder ON JobOrder.[Guid] = TotalQtys.[JobOrderGuid]
		INNER JOIN JOCJobOrderOperatingBOM000 AS OperatingBOM ON JobOrder.[OperatingBOMGuid] = OperatingBOM.[Guid]
		WHERE JobOrder.[IsActive] = 0 -- Finished Job Orders
			AND (@StartDate =  '1/1/1980' OR JobOrder.[StartDate] >= (DATEADD(month, DATEDIFF(month, 0, @StartDate), 0)))
			AND (@EndDate = '1/1/1980' OR JobOrder.[EndDate] <= (DATEADD(d, -1, DATEADD(m, DATEDIFF(m, 0, @EndDate) + 1, 0))))
			AND (@CostRank = -1 OR OperatingBOM.[CostRank] = @CostRank)
			AND OperatingBOM.[JointCostsAllocationType] = 0 -- ProductionQty

	-- =============== Result Table ================
	CREATE TABLE [#WorkersIndirectLaborsDist]
	( 
		[JobOrderGuid]			[UNIQUEIDENTIFIER], 
		[FinishedGoodGuid]		[UNIQUEIDENTIFIER], 
		[WorkerGuid]			[UNIQUEIDENTIFIER], 
		[StageGuid]				[UNIQUEIDENTIFIER], 
		[StageName]				[NVARCHAR](Max),	
		[StageLatinName]		[NVARCHAR](max),	
		[DistWorkerLabor]		[FLOAT],			
		[InDirectValue]			[FLOAT],			
		[WorkingHourCost]		[FLOAT]				
	)
	-- ================================================

	-----------------------------------------------------------------------------------------------------------------------
	--INSERT INTO [#WorkersIndirectLaborsDist]
	--	SELECT	ViewQty.[JobOrderGuid],
	--			ViewQty.[MaterialGuid], 
	--			Labors.[WorkerGuid],
	--			Labors.[StageGuid], 
	--			Labors.[StageName],
	--			Labors.[StageLatinName],
	--			Labors.[DistWorkerLabor],
	--			(CASE WHEN TotalQty.[TotalProductionQty] = 0 THEN 0 
	--				WHEN TotalQty.[UsedProductionUnit] = 1 
	--				THEN ((ViewQty.FirstProductionUnityQty  / TotalQty.[TotalProductionQty]) * Labors.[DistWorkerLabor])
	--				ELSE ((ViewQty.SecondProductionUnityQty / TotalQty.[TotalProductionQty]) * Labors.[DistWorkerLabor])
	--			END) AS InDirectValue,
	--			Labors.[WorkingHourCost]
	--	FROM JOCvwJobOrderFinishedGoodsBillItemsQtys AS ViewQty
	--	INNER JOIN [#JobOrdersTotalProductionQtys] TotalQty ON TotalQty.[JobOrderGuid] = ViewQty.[JobOrderGuid]
	--	INNER JOIN [#WorkersLabors] AS Labors ON Labors.[JobOrderGuid] =  ViewQty.[JobOrderGuid]
	--	INNER JOIN JOCOperatingBOMWagesAndMOH000 Dist 
	--		ON Dist.[FinishedProductGuid] = ViewQty.[MaterialGuid]
	--			AND Dist.[OperatingBOMGuid] = ViewQty.[OperatingBOMGuid]
	--	WHERE Dist.[WagesAllocationType] = 0 -- In direct allocation 
	-----------------------------------------------------------------------------------------------------------------------

	------------------------------------------------------------------------------------
	INSERT INTO [#WorkersIndirectLaborsDist]
		SELECT 
			FinishedGoods.[JobOrderGuid],
			FinishedGoods.[FinishedGoodGuid], 
			Labors.[WorkerGuid],
			Labors.[StageGuid], 
			Labors.[StageName],
			Labors.[StageLatinName],
			Labors.[DistWorkerLabor], 
			0,
			Labors.[WorkingHourCost]
		FROM JOCJobOrdersBOMFinishedGoods FinishedGoods
		INNER JOIN [#WorkersLabors] AS Labors ON Labors.[JobOrderGuid] = FinishedGoods.[JobOrderGuid]
		INNER JOIN JobOrder000 AS JO ON JO.[Guid] = Labors.[JobOrderGuid]
		INNER JOIN [#JobOrdersTotalProductionQtys] JOTotal ON JOTotal.[JobOrderGuid] = JO.[Guid]
		INNER JOIN [JOCOperatingBOMWagesAndMOH000] AS Dist ON   
			Dist.[FinishedProductGuid] = FinishedGoods.[FinishedGoodGuid]
			AND JO.[OperatingBOMGuid] = Dist.[OperatingBOMGuid]

	-- ========================== Update Indirect value =================================
	Update [#WorkersIndirectLaborsDist]
		SET [InDirectValue] = ISNULL((CASE WHEN TotalQty.[TotalProductionQty] = 0 THEN 0 
								WHEN TotalQty.[UsedProductionUnit] = 1 
								THEN ((ViewQty.FirstProductionUnityQty  / TotalQty.[TotalProductionQty]) * Labors.[DistWorkerLabor])
								ELSE ((ViewQty.SecondProductionUnityQty / TotalQty.[TotalProductionQty]) * Labors.[DistWorkerLabor])
								END), 0)
	FROM [#WorkersIndirectLaborsDist] InDirectDist
	INNER JOIN JOCvwJobOrderFinishedGoodsBillItemsQtys AS ViewQty ON
		ViewQty.[MaterialGuid] = InDirectDist.[FinishedGoodGuid]
		AND ViewQty.[JobOrderGuid] = InDirectDist.[JobOrderGuid]
	INNER JOIN [#JobOrdersTotalProductionQtys] TotalQty ON TotalQty.[JobOrderGuid] = ViewQty.[JobOrderGuid]
	INNER JOIN [#WorkersLabors] AS Labors 
		ON Labors.[JobOrderGuid] =  ViewQty.[JobOrderGuid]
		AND Labors.[StageGuid]   = InDirectDist.[StageGuid]
		AND Labors.[WorkerGuid] = InDirectDist.[WorkerGuid]
		AND Labors.[WorkingHourCost] = InDirectDist.[WorkingHourCost]
	INNER JOIN JOCOperatingBOMWagesAndMOH000 Dist 
		ON Dist.[FinishedProductGuid] = ViewQty.[MaterialGuid]
			AND Dist.[OperatingBOMGuid] = ViewQty.[OperatingBOMGuid]
	WHERE Dist.[WagesAllocationType] = 0 -- In direct allocation 
	------------------------------------------------------------------------------------


	SELECT * FROM [#WorkersIndirectLaborsDist] 
	ORDER BY JobOrderGuid, FinishedGoodGuid, WorkerGuid, StageGuid

	DROP TABLE [#WorkersLabors]
	DROP TABLE [#WorkersIndirectLaborsDist]
	DROP TABLE [#JobOrdersTotalProductionQtys]
END
######################################################################
CREATE PROC JOCprcUpdateJobOrderFinishedGoodsPercentages(@JobOrderGuid	[UNIQUEIDENTIFIER])
AS
BEGIN
	SET NOCOUNT ON;
	DECLARE @ToBeDeletedPercentage [FLOAT]
	SET @ToBeDeletedPercentage = 0
	
	SELECT @ToBeDeletedPercentage = SUM(Percentages.[Percentages])
	FROM [#FinishedGoodsDirectPercentages] Percentages
	INNER JOIN [JOCvwJobOrderFinishedGoodsBillItemsQtys] BillQtys 
		ON BillQtys.[MaterialGuid] = Percentages.[FinishedGoodGuid] AND BillQtys.[JobOrderGuid] = Percentages.[JobOrderGuid]
	WHERE BillQtys.[JobOrderGuid] = @JobOrderGuid AND Percentages.[JobOrderGuid] = @JobOrderGuid
	
	SET @ToBeDeletedPercentage = ISNULL((100.0 - @ToBeDeletedPercentage), 0.0)
	
	IF( @ToBeDeletedPercentage <> 0.0)
	BEGIN
		UPDATE [#FinishedGoodsDirectPercentages]
			SET [Percentages] = [Percentages] + (@ToBeDeletedPercentage * ([Percentages] / (100- @ToBeDeletedPercentage)))
		FROM [#FinishedGoodsDirectPercentages] AS Percentage
		WHERE Percentage.[JobOrderGuid] = @JobOrderGuid
		
		UPDATE FGPercentage
			SET [Percentages] = 0.0
		FROM [#FinishedGoodsDirectPercentages] AS FGPercentage
		WHERE (
				[FinishedGoodGuid] NOT IN  
				(	SELECT [FinishedGoodGuid] 
					FROM [#FinishedGoodsDirectPercentages] Percentages
					INNER JOIN [JOCvwJobOrderFinishedGoodsBillItemsQtys] BillQtys 
						ON BillQtys.[MaterialGuid] = Percentages.[FinishedGoodGuid]
						AND BillQtys.[JobOrderGuid] = Percentages.[JobOrderGuid]
					WHERE Percentages.[JobOrderGuid] = @JobOrderGuid
				)
			  )
			  AND FGPercentage.[JobOrderGuid] = @JobOrderGuid			 
	END
END
######################################################################
CREATE PROC JOCprcCalculateJobOrdersDirectLaborsDirectDist
(
	@ManufactoryGuid	[UNIQUEIDENTIFIER] = 0x00,
	@JobOrderGuid		[UNIQUEIDENTIFIER] = 0x00,
	@StartDate			[DATETIME] = '1/1/1980',
	@EndDate			[DATETIME] = '1/1/1980',
	@CostRank			[INT] = -1
)
AS
BEGIN

	CREATE TABLE [#WorkersLabors]
	( 
		[JobOrderGuid]		[UNIQUEIDENTIFIER],
		[WorkerGuid]		[UNIQUEIDENTIFIER], 
		[StageGuid]			[UNIQUEIDENTIFIER], 
		[StageName]			[NVARCHAR](Max),
		[StageLatinName]	[NVARCHAR](max),
		[WorkingHourCost]	[FLOAT],
		[TotalWorkingHours] [FLOAT],
		[DistWorkerLabor]	[FLOAT]
	)

	INSERT INTO [#WorkersLabors]
		SELECT * FROM [dbo].[JOCfnCalcJobOrdersDirectLabrs](@ManufactoryGuid, @JobOrderGuid, @StartDate, @EndDate, @CostRank)

	CREATE TABLE [#FinishedJobOrders]
	(
		[JobOrderGuid]			[UNIQUEIDENTIFIER],
		[Processed]				[BIT]
	)

	INSERT INTO [#FinishedJobOrders]
		SELECT [GUID], 0 
		FROM JobOrder000
		WHERE [IsActive] = 0 
		AND (@JobOrderGuid = 0x00 OR [Guid] = @JobOrderGuid)
		AND (@StartDate =  '1/1/1980' OR [StartDate] >= (DATEADD(month, DATEDIFF(month, 0, @StartDate), 0)))
		AND (@EndDate = '1/1/1980' OR [EndDate] <= (DATEADD(d, -1, DATEADD(m, DATEDIFF(m, 0, @EndDate) + 1, 0))))
		AND (@ManufactoryGuid = 0x00 OR ManufactoryGUID = @ManufactoryGuid)

	CREATE TABLE [#FinishedGoodsDirectPercentages]
	( 
		[JobOrderGuid]			[UNIQUEIDENTIFIER],
		[FinishedGoodGuid]		[UNIQUEIDENTIFIER],
		[Percentages]			[FLOAT]
	)

	INSERT INTO [#FinishedGoodsDirectPercentages]
		SELECT JobOrder.[GUID], Labors.[FinishedProductGuid] , Labors.[WagesPercentage]
		FROM JOCOperatingBOMWagesAndMOH000 Labors
		INNER JOIN JOCJobOrderOperatingBOM000 OperatingBOM ON Labors.[OperatingBOMGuid] = OperatingBOM.[Guid]
		INNER JOIN JobOrder000 JobOrder ON JobOrder.[OperatingBOMGuid] = OperatingBOM.[Guid]
		INNER JOIN [#FinishedJobOrders] FinishedJobOrders ON FinishedJobOrders.[JobOrderGuid] = JobOrder.[Guid]
		WHERE 
			Labors.[WagesAllocationType] = 1 -- Direct Dist
			AND (@CostRank = -1 OR OperatingBOM.[CostRank] = @CostRank)
	
	DECLARE @Cnt INT, @CurrentJobOrderGuid UNIQUEIDENTIFIER

	SET @Cnt = (SELECT COUNT(*) FROM [#FinishedJobOrders] WHERE [Processed] = 0)
	
	WHILE @Cnt > 0
	BEGIN
		SET @CurrentJobOrderGuid = (SELECT TOP 1 [JobOrderGuid] FROM [#FinishedJobOrders] WHERE [Processed] = 0)

		EXEC JOCprcUpdateJobOrderFinishedGoodsPercentages @CurrentJobOrderGuid

		UPDATE [#FinishedJobOrders]
			SET [Processed] = 1
		WHERE [JobOrderGuid] = @CurrentJobOrderGuid

		SET @Cnt = (SELECT COUNT(*) FROM [#FinishedJobOrders] WHERE [Processed] = 0)
	END

	SELECT	Labors.[JobOrderGuid],
			Percentages.[FinishedGoodGuid] AS FinishedGoodGuid,
			Labors.[WorkerGuid] AS WorkerGuid,
			Labors.[StageGuid] AS StageGuid, 
			Labors.[StageName] AS StageName,
			Labors.[StageLatinName] AS StageLatinName,
			Labors.[DistWorkerLabor] AS DistWorkerLabor,
			((Labors.[DistWorkerLabor] * Percentages.[Percentages]) / 100.0) AS DirectValue,
			Labors.[WorkingHourCost] AS WorkingHourCost
	FROM [#FinishedGoodsDirectPercentages] AS Percentages
	INNER JOIN [#WorkersLabors] AS Labors ON Labors.[JobOrderGuid] = Percentages.[JobOrderGuid]

	DROP TABLE [#WorkersLabors]
	DROP TABLE [#FinishedGoodsDirectPercentages]
	DROP TABLE [#FinishedJobOrders]

END
######################################################################
CREATE PROC JOCprcCalculateJobOrdersDirectLaborsCosts
(
	@ManufactoryGuid	[UNIQUEIDENTIFIER] = 0x00,
	@JobOrderGuid		[UNIQUEIDENTIFIER] = 0x00,
	@StartDate			[DATETIME] = '1/1/1980',
	@EndDate			[DATETIME] = '1/1/1980',
	@CostRank			[INT] = -1
)
AS
BEGIN
	SET NOCOUNT ON;

	------------------------------------------------------------------------------------------------------
	CREATE TABLE [#JobOrdersInfo]
	(
		[JobOrderGuid]				[UNIQUEIDENTIFIER],
		[FinishedGoodsCount]		[INT],
		[WithStages]				[BIT],
		[IsActive]					[BIT],
		[JointCostMethod]			[BIT],	-- 0: ProductionQty , 1:ProductionSellValue
		[DirectLaborsDistMethod]	[BIT]	-- 0: InDirect,		  1: Direct	
	)

	INSERT INTO [#JobOrdersInfo]
		SELECT  JobOrder.[GUID],
				Count(FinishedGoods.[MaterialGuid]),
				(BOM.[StagesEnabled] & BOM.[UseStagesInRequestionAndLabor]), 
				JobOrder.[IsActive],
				OperatingBOM.[JointCostsAllocationType],
				Labors.[WagesAllocationType] 
		FROM JobOrder000 AS JobOrder
		INNER JOIN JOCJobOrderOperatingBOM000 AS OperatingBOM ON JobOrder.[OperatingBOMGuid] = OperatingBOM.[Guid]
		INNER JOIN JOCOperatingBOMFinishedGoods000 AS FinishedGoods ON FinishedGoods.[OperatingBOMGuid] = OperatingBOM.[Guid]
		INNER JOIN JOCBOM000 BOM ON OperatingBOM.[BOMGuid] = BOM.[GUID]
		INNER JOIN JOCOperatingBOMWagesAndMOH000 Labors ON Labors.[FinishedProductGuid] = FinishedGoods.[MaterialGuid]
			AND Labors.[OperatingBOMGuid] = OperatingBOM.[Guid]
		WHERE 
			JobOrder.[IsActive] = 0 
			AND (@ManufactoryGuid = 0x00 OR JobOrder.[ManufactoryGUID] = @ManufactoryGuid)
			AND (@JobOrderGuid = 0x00 OR JobOrder.[Guid] = @JobOrderGuid)
			AND (@StartDate = '1/1/1980' OR JobOrder.[StartDate] >= (DATEADD(month, DATEDIFF(month, 0, @StartDate), 0)))
			AND (@EndDate = '1/1/1980' OR JobOrder.[EndDate] <= (DATEADD(d, -1, DATEADD(m, DATEDIFF(m, 0, @EndDate) + 1, 0))))
			AND (@CostRank = -1 OR OperatingBOM.[CostRank] = @CostRank)
		GROUP BY JobOrder.[Guid], (BOM.[StagesEnabled] & BOM.[UseStagesInRequestionAndLabor]), JobOrder.[IsActive],
			OperatingBOM.[JointCostsAllocationType], Labors.[WagesAllocationType]
	------------------------------------------------------------------------------------------------------

	--=======================================================
	CREATE TABLE [#DirectLaborsCostsDistQty]
	( 
		[JobOrderGuid]			[UNIQUEIDENTIFIER],
		[FinishedGoodGuid]		[UNIQUEIDENTIFIER], 
		[WorkerGuid]			[UNIQUEIDENTIFIER], 
		[StageGuid]				[UNIQUEIDENTIFIER], 
		[StageName]				[NVARCHAR](Max),	
		[StageLatinName]		[NVARCHAR](max),	
		[DistWorkerLabor]		[FLOAT],			
		[InDirectValue]			[FLOAT],			
		[WorkingHourCost]		[FLOAT]				
	)

	INSERT INTO [#DirectLaborsCostsDistQty]
		EXEC prcGetJobOrdersInDirectLaborsDistQty @ManufactoryGuid, @JobOrderGuid, @StartDate, @EndDate, @CostRank
	--=======================================================

	--=======================================================
	CREATE TABLE [#DirectLaborsCostsSellPrice]
	( 
		[JobOrderGuid]			[UNIQUEIDENTIFIER],
		[FinishedGoodGuid]		[UNIQUEIDENTIFIER], 
		[WorkerGuid]			[UNIQUEIDENTIFIER], 
		[StageGuid]				[UNIQUEIDENTIFIER], 
		[StageName]				[NVARCHAR](Max),	
		[StageLatinName]		[NVARCHAR](max),	
		[DistWorkerLabor]		[FLOAT],			
		[InDirectValue]			[FLOAT],			
		[WorkingHourCost]		[FLOAT]				
	)

	INSERT INTO [#DirectLaborsCostsSellPrice]
		EXEC prcGetJobOrdersInDirectLaborsDistPrice @ManufactoryGuid, @JobOrderGuid, @StartDate, @EndDate, @CostRank
	--=======================================================

	--=======================================================
	CREATE TABLE [#DirectLaborsCostsDirectDist]
	( 
		[JobOrderGuid]			[UNIQUEIDENTIFIER],
		[FinishedGoodGuid]		[UNIQUEIDENTIFIER], 
		[WorkerGuid]			[UNIQUEIDENTIFIER], 
		[StageGuid]				[UNIQUEIDENTIFIER], 
		[StageName]				[NVARCHAR](Max),	
		[StageLatinName]		[NVARCHAR](max),	
		[DistWorkerLabor]		[FLOAT],			
		[DirectValue]			[FLOAT],			
		[WorkingHourCost]		[FLOAT]				
	)

	INSERT INTO [#DirectLaborsCostsDirectDist]
		EXEC JOCprcCalculateJobOrdersDirectLaborsDirectDist @ManufactoryGuid, @JobOrderGuid, @StartDate, @EndDate, @CostRank
	--=======================================================

	-- ============= Final Result Table =====================
	CREATE TABLE [#ResultCosts]
	( 
		[JobOrderGuid]			[UNIQUEIDENTIFIER],
		[FinishedGoodGuid]		[UNIQUEIDENTIFIER], 
		[WorkerGuid]			[UNIQUEIDENTIFIER], 
		[StageGuid]				[UNIQUEIDENTIFIER], 
		[StageName]				[NVARCHAR](Max),	
		[StageLatinName]		[NVARCHAR](max),	
		[DistWorkerLabor]		[FLOAT],			
		[DistValue]				[FLOAT],			
		[WorkingHourCost]		[FLOAT]				
	)
	-- =====================================================
	
	-- =====================================================================================================
	INSERT INTO [#ResultCosts]
		SELECT	DistQty.[JobOrderGuid],
				DistQty.[FinishedGoodGuid],
				DistQty.[WorkerGuid],
				CASE (JobOrder.[WithStages]) WHEN 0 THEN 0x00 ELSE ISNULL(DistQty.[StageGuid], 0x00) END,
				CASE (JobOrder.[WithStages]) WHEN 0 THEN '' ELSE ISNULL(DistQty.[StageName], '') END,
				CASE (JobOrder.[WithStages]) WHEN 0 THEN '' ELSE ISNULL(DistQty.[StageLatinName], '') END,
				ISNULL(DistQty.[DistWorkerLabor], 0),
				ISNULL(DistQty.[InDirectValue], 0),
				ISNULL(DistQty.[WorkingHourCost], 0)			 
		FROM [#JobOrdersInfo] JobOrder
		INNER JOIN [#DirectLaborsCostsDistQty] DistQty ON JobOrder.[JobOrderGuid] = DistQty.[JobOrderGuid]
		WHERE   ( JobOrder.[DirectLaborsDistMethod] = 0 OR JobOrder.[FinishedGoodsCount] = 1 )
			AND ( JobOrder.[JointCostMethod] = 0 )

	-- =====================================================================================================

	-- =====================================================================================================
	INSERT INTO [#ResultCosts]
		SELECT	DistPrice.[JobOrderGuid],
				DistPrice.[FinishedGoodGuid],
				DistPrice.[WorkerGuid],
				CASE (JobOrder.[WithStages]) WHEN 0 THEN 0x00 ELSE ISNULL(DistPrice.[StageGuid], 0x00) END,
				CASE (JobOrder.[WithStages]) WHEN 0 THEN '' ELSE ISNULL(DistPrice.[StageName], '') END,
				CASE (JobOrder.[WithStages]) WHEN 0 THEN '' ELSE ISNULL(DistPrice.[StageLatinName], '') END,
				ISNULL(DistPrice.[DistWorkerLabor], 0),
				ISNULL(DistPrice.[InDirectValue], 0),
				ISNULL(DistPrice.[WorkingHourCost], 0)			 
		FROM [#JobOrdersInfo] JobOrder
		INNER JOIN [#DirectLaborsCostsSellPrice] DistPrice ON JobOrder.[JobOrderGuid] = DistPrice.[JobOrderGuid]
		WHERE   ( JobOrder.[DirectLaborsDistMethod] = 0 OR JobOrder.[FinishedGoodsCount] = 1 )
			AND ( JobOrder.[JointCostMethod] = 1 )
	-- =====================================================================================================

	-- =====================================================================================================
	INSERT INTO [#ResultCosts]
		SELECT	DirectDist.[JobOrderGuid],
				DirectDist.[FinishedGoodGuid],
				DirectDist.[WorkerGuid],
				CASE (JobOrder.[WithStages]) WHEN 0 THEN 0x00 ELSE ISNULL(DirectDist.[StageGuid], 0x00) END,
				CASE (JobOrder.[WithStages]) WHEN 0 THEN '' ELSE ISNULL(DirectDist.[StageName], '') END,
				CASE (JobOrder.[WithStages]) WHEN 0 THEN '' ELSE ISNULL(DirectDist.[StageLatinName], '') END,
				ISNULL(DirectDist.[DistWorkerLabor], 0),
				ISNULL(DirectDist.[DirectValue], 0),
				ISNULL(DirectDist.[WorkingHourCost], 0)			 
		FROM [#JobOrdersInfo] JobOrder
		INNER JOIN [#DirectLaborsCostsDirectDist] DirectDist ON JobOrder.[JobOrderGuid] = DirectDist.[JobOrderGuid]
		WHERE JobOrder.[DirectLaborsDistMethod] = 1 
	-- =====================================================================================================

	INSERT INTO [#DirectLaborsCosts]
		SELECT * FROM  [#ResultCosts]

	DROP TABLE [#JobOrdersInfo]
	DROP TABLE [#ResultCosts]
	DROP TABLE [#DirectLaborsCostsDistQty]
	DROP TABLE [#DirectLaborsCostsSellPrice]
	DROP TABLE [#DirectLaborsCostsDirectDist]
END

######################################################################
CREATE FUNCTION  JOCfnGetOperaingBOMHierarchy(@MaterialGuid UNIQUEIDENTIFIER)
RETURNS TABLE
RETURN (
--íÞæã ÈÅÑÌÇÚ ÇáãæÇÏ äÕÝ ÇáãÕäÚÉ ááãÇÏÉ ÇáãÏÎáÉ Ýí äãÇÐÌ ÃæÇãÑ ÇáÊÔÛíá
WITH CTE (MaterialGuid, [Level])
AS
(
	SELECT DISTINCT CASE @MaterialGuid WHEN finishedgoods.MaterialGuid THEN MaterialGuid ELSE finishedgoods.SpoilageMaterial END, 0
	FROM JOCOperatingBOMFinishedGoods000 finishedgoods
	WHERE finishedgoods.MaterialGuid = @MaterialGuid OR finishedgoods.SpoilageMaterial = @MaterialGuid 


	UNION ALL

	SELECT opMaterials.RawMaterialGuid, cte.[Level] + 1
	FROM JOCvwOperatingBOMRawMaterialsAndFinishedGoods opMaterials
	INNER JOIN CTE ON opMaterials.FinishedProductGuid = CTE.MaterialGuid OR opMaterials.SpoilageMaterial = CTE.MaterialGuid
)
SELECT DISTINCT mt.GUID, mt.Name, CTE.[Level] AS [CostRank] FROM CTE inner join mt000 mt ON mt.GUID = CTE.MaterialGuid
)
######################################################################
CREATE PROC JOCprcGetOperaingBOMHierarchy
@MaterialGuid UNIQUEIDENTIFIER
AS
--íÞæã ÈÅÑÌÇÚ ÇáãæÇÏ äÕÝ ÇáãÕäÚÉ ááãÇÏÉ ÇáãÏÎáÉ Ýí äãÇÐÌ ÃæÇãÑ ÇáÊÔÛíá
SET NOCOUNT ON;

SELECT * FROM JOCfnGetOperaingBOMHierarchy(@MaterialGuid)
######################################################################

CREATE PROC JOCprcMntAuditJobOrdersCostRanks
AS

DISABLE TRIGGER JOCtrOperatingBOM_ForInsertUpdate ON JOCJobOrderOperatingBOM000;
DISABLE TRIGGER JOCtrOperatingBOM_ForDelete ON JOCJobOrderOperatingBOM000;

SELECT 
	jo.GUID  AS JobOrderGuid
	,bom.[Guid] AS OperatingBOMGuid
INTO #TempJobOrders
FROM JobOrder000 jo
INNER JOIN JOCJobOrderOperatingBOM000 bom on jo.OperatingBOMGuid = bom.[Guid]
WHERE
 jo.IsActive = 0


SELECT
	jo.JobOrderGuid AS JobOrderGuid, 
	jo.OperatingBOMGuid AS OperatingBOMGuid,
	fg.MaterialGuid AS FinishedProductGuid,
	fg.SpoilageMaterial AS SpoilageMaterialGuid,
	(SELECT MAX(CostRank) FROM JOCfnGetOperaingBOMHierarchy(fg.MaterialGuid)) AS CostRank
INTO #TempJobOrdersActualCostRanks
FROM JOCOperatingBOMFinishedGoods000 fg
INNER JOIN #TempJobOrders jo ON fg.OperatingBOMGuid = jo.OperatingBOMGuid


CREATE TABLE #TempJobOrdersRawMaterials
(
	RawMaterialGuid	UNIQUEIDENTIFIER,
	CostRank		INT
)

INSERT INTO #TempJobOrdersRawMaterials
	SELECT DISTINCT RawMaterialGuid, ISNULL(
	(
		SELECT MAX(CostRank) FROM #TempJobOrdersActualCostRanks t WHERE t.FinishedProductGuid = rm.RawMaterialGuid OR t.SpoilageMaterialGuid = rm.RawMaterialGuid
	)
	,0) AS CostRank 
FROM JOCOperatingBOMRawMaterials000 rm
INNER JOIN #TempJobOrders jo ON rm.OperatingBOMGuid = jo.OperatingBOMGuid


UPDATE r 
SET CostRank = t.CostRank
from JOCOperatingBOMRawMaterials000 r
INNER JOIN #TempJobOrdersRawMaterials t ON r.RawMaterialGuid = t.RawMaterialGuid

UPDATE JOCJobOrderOperatingBOM000 
SET CostRank = (SELECT MAX(CostRank) + 1 FROM JOCOperatingBOMRawMaterials000 WHERE OperatingBOMGUID = JOCJobOrderOperatingBOM000.[Guid])

UPDATE  JOCBOM000
SET ActualCostProcessingLevel = (SELECT MAX(CostRank) FROM JOCJobOrderOperatingBOM000 WHERE BOMGuid = JOCBOM000.[GUID])


DROP TABLE #TempJobOrders;
DROP TABLE #TempJobOrdersActualCostRanks;
DROP TABLE #TempJobOrdersRawMaterials;

ENABLE TRIGGER JOCtrOperatingBOM_ForInsertUpdate ON JOCJobOrderOperatingBOM000;
ENABLE TRIGGER JOCtrOperatingBOM_ForDelete ON JOCJobOrderOperatingBOM000;
######################################################################
CREATE PROC JOCprcRecalculateJobOrdersDirectLaborsCosts
(
	@ManufactoryGUid	UNIQUEIDENTIFIER = 0x00,
	@StartPeriod		DATETIME = '1/1/1980',
	@EndPeriod			DATETIME = '1/1/1980',
	@CostRank			INT = -1
)
AS
-- Recalculate Direct Labors costs for all finished job orders and save them in JOCJobOrderDirectLabors000
BEGIN
	CREATE TABLE [#DirectLaborsCosts]
	( 
		[JobOrderGuid]			[UNIQUEIDENTIFIER],
		[FinishedGoodGuid]		[UNIQUEIDENTIFIER], 
		[WorkerGuid]			[UNIQUEIDENTIFIER], 
		[StageGuid]				[UNIQUEIDENTIFIER], 
		[StageName]				[NVARCHAR](Max),	
		[StageLatinName]		[NVARCHAR](max),	
		[DistWorkerLabor]		[FLOAT],			
		[InDirectValue]			[FLOAT],			
		[WorkingHourCost]		[FLOAT]				
	)
	EXEC JOCprcCalculateJobOrdersDirectLaborsCosts @ManufactoryGuid, 0x00, @StartPeriod, @EndPeriod, @CostRank
	
	CREATE TABLE [#JobOrdersDirectLabors]
	(
		[WorkerGuid]			[UNIQUEIDENTIFIER],
		[MaterialGuid]			[UNIQUEIDENTIFIER],
		[StageGuid]				[UNIQUEIDENTIFIER],
		[NumberOfHours]			[FLOAT],
		[TotalWorkingHoursCost]	[FLOAT],
		[MaterialCost]			[FLOAT],
		[WorkerIndex]			[INT],
		[MaterialIndex]			[INT],
		[JobOrderGuid]			[UNIQUEIDENTIFIER]
	) 
	
	INSERT INTO [#JobOrdersDirectLabors]
		SELECT 
			CurrDirectLabors.[WorkerGuid],
			CurrDirectLabors.[FinishedGoodGuid],
			CurrDirectLabors.[StageGuid],
			MatWorkerIndex.[NumberOfHours],
			MatWorkerIndex.[TotalWorkingHoursCost],
			CurrDirectLabors.[InDirectValue],
			MatWorkerIndex.[WorkerIndex],
			MatWorkerIndex.[MaterialIndex],
			CurrDirectLabors.[JobOrderGuid]
		FROM [#DirectLaborsCosts] CurrDirectLabors
		INNER JOIN JOCJobOrderDirectLabors000 MatWorkerIndex
			ON CurrDirectLabors.[JobOrderGuid] = MatWorkerIndex.[JobOrderGuid]
			AND CurrDirectLabors.[WorkerGuid] = MatWorkerIndex.[WorkerGuid]
			AND CurrDirectLabors.[StageGuid] = MatWorkerIndex.[StageGuid]
			AND CurrDirectLabors.[FinishedGoodGuid] = MatWorkerIndex.[MaterialGuid]
			AND CurrDirectLabors.[WorkingHourCost] = (MatWorkerIndex.[TotalWorkingHoursCost] / MatWorkerIndex.[NumberOfHours] )

	DELETE FROM JOCJobOrderDirectLabors000 where JobOrderGuid IN (SELECT DISTINCT labors.[JobOrderGuid] FROM [#JobOrdersDirectLabors] labors)
	
	INSERT INTO JOCJobOrderDirectLabors000
		SELECT 
			dc.[WorkerGuid],
			dc.[MaterialGuid],
			dc.[StageGuid],
			dc.[NumberOfHours],
			dc.[TotalWorkingHoursCost],
			dc.[MaterialCost],
			dc.[WorkerIndex],
			dc.[MaterialIndex],
			dc.[JobOrderGuid] 
		FROM [#JobOrdersDirectLabors] dc
	
	DROP TABLE [#DirectLaborsCosts]
	DROP TABLE [#JobOrdersDirectLabors]
END


######################################################################

CREATE PROC JOCprcCalculateOutBalanceAveragePrice
@i	INT,
@StartPeriod DATETIME,
@EndPeriod	DATETIME
AS
	
	EXEC prcOutbalanceAveragePrice @StartPeriod, @EndPeriod, 0x00, 0
	
	SELECT 
		rm.RawMaterialGuid, 
		rm.CostRank,
		rm.StartDate,
		rm.EndDate,
		ISNULL(o.Price, 0) AS AveragePrice
	INTO ##TempRawMaterialsOutBalanceAvgPrices
	FROM oap000 o
	INNER JOIN #TempRawMaterials rm ON rm.RawMaterialGuid = o.MaterialGuid AND rm.StartDate  BETWEEN  o.StartDate AND o.EndDate
	WHERE rm.CostRank = @i

######################################################################
CREATE PROC JOCprcUpdateJobOrdersRawMaterialsBills
@RawMaterialCostRank INT,
@SrcGuid	UNIQUEIDENTIFIER,
@StartPeriod	DATETIME,
@EndPeriod		DATETIME
AS

	EXEC prcDisableTriggers	'bi000' 

	UPDATE bi000
	SET Price = trm.AveragePrice
	FROM bi000 bi
	JOIN vwBuBi ON vwBuBi.biGUID = bi.[GUID]
	JOIN ##TempJobOrders tmp ON tmp.JobOrderAccount = vwbubi.buCustAcc
	JOIN ##TempRawMaterialsOutBalanceAvgPrices trm ON trm.RawMaterialGuid = vwbubi.biMatPtr AND vwBuBi.buDate BETWEEN trm.StartDate AND trm.EndDate
	WHERE vwBuBi.buType IN (SELECT BillTypeGuid FROM #TempManufactoryBillTypes)
	AND trm.CostRank = @RawMaterialCostRank

	EXEC prcEnableTriggers 'bi000'
	-- ÅÚÇÏÉ ÍÓÇÈ ãÌÇãíÚ ÇáÝæÇÊíÑ 
	EXEC [prcCheckDB_bu_Sums] 1 

	EXEC prcBill_reGenEntry @SrcGuid, @StartPeriod, @EndPeriod

######################################################################

CREATE PROC JOCprcMntUpdateJobOrdersDeliveryBills
@StartPeriod	DATETIME,
@EndPeriod		DATETIME,
@ManufactoryGuid	UNIQUEIDENTIFIER,
@CostRank			INT
AS

	DECLARE @SrcGuid UNIQUEIDENTIFIER = NEWID();

	INSERT INTO RepSrcs (IdTbl, IdType, IdSubType)
	SELECT @SrcGuid,m.FinishedGoodsBillType, 2 FROM Manufactory000 m
	WHERE (m.[Guid] = @ManufactoryGuid OR @ManufactoryGuid = 0x0)


	SELECT 
	jo.JobOrderGuid,
	jo.JobOrderManufactoryGuid,
	jo.ManufactoryFinishedGoodsBillType,
	jo.UseSpoilage,
	jo.JobOrderAccount,
	jo.JobOrderOperatingBOM
	INTO #TempJobOrders
	FROM JocVwJobOrder jo
	WHERE (jo.JobOrderManufactoryGuid = @ManufactoryGuid OR @ManufactoryGuid = 0x0)
	AND jo.OperatingBOMCostRank = @CostRank

	EXEC prcDisableTriggers	'bi000' 

	--ÊÓÚíÑ ãæÇÏ ÇáãäÊÌ ÇáÊÇã

	UPDATE bi000
	SET Price = CASE tmp.UseSpoilage 
	WHEN 0 
		THEN c.UnitCost * (dbo.JocFnGetMaterialFactorial(bi.MatGUID, bi.Unity) / dbo.JocFnGetMaterialFactorial(bi.MatGUID, c.BOMUnit))
		ELSE s.FlawlessUnitCost * (dbo.JocFnGetMaterialFactorial(bi.MatGUID, bi.Unity) / dbo.JocFnGetMaterialFactorial(bi.MatGUID, c.BOMUnit)) END
	FROM bi000 bi
	JOIN vwBuBi ON vwBuBi.biGUID = bi.[GUID]
	JOIN #TempJobOrders tmp ON tmp.ManufactoryFinishedGoodsBillType= vwBuBi.buType AND vwBuBi.buCustAcc = tmp.JobOrderAccount
	LEFT JOIN JOCJobOrderCosts000 c ON c.JobOrderGuid = tmp.JobOrderGuid AND c.FinishedMaterialGuid = bi.MatGUID
	LEFT JOIN JOCJobOrderSpoilage000 s ON s.JobOrderGuid = tmp.JobOrderGuid AND bi.MatGUID = s.FinishedProductGuid

	--ÊÓÚíÑ ÃÞáÇã ÇáÊáÝ

	UPDATE bi000
	SET Price = s.SpoilageSellPrice * (dbo.JocFnGetMaterialFactorial(bi.MatGUID, bi.Unity) / dbo.JocFnGetMaterialFactorial(bi.MatGUID, f.SpoilageUnit))
	FROM bi000 bi
	JOIN vwBuBi ON vwBuBi.biGUID = bi.[GUID]
	JOIN #TempJobOrders tmp ON tmp.ManufactoryFinishedGoodsBillType= vwBuBi.buType AND vwBuBi.buCustAcc = tmp.JobOrderAccount
	JOIN JOCJobOrderSpoilage000 s ON s.JobOrderGuid = tmp.JobOrderGuid AND s.SpoilageMaterialGuid = bi.MatGUID
	JOIN JOCOperatingBOMFinishedGoods000 f ON f.SpoilageMaterial = s.SpoilageMaterialGuid AND tmp.JobOrderOperatingBOM = f.OperatingBOMGuid


	EXEC prcEnableTriggers 'bi000'
	EXEC [prcCheckDB_bu_Sums] 1 

	EXEC prcBill_reGenEntry @SrcGuid, @StartPeriod, @EndPeriod


	DELETE FROM RepSrcs WHERE IdTbl = @SrcGuid
	DROP TABLE #TempJobOrders


######################################################################

CREATE PROC JOCprcRecalculateJobOrdersCosts
	@ManufactoryGUid	UNIQUEIDENTIFIER,
	@StartPeriod		DATETIME,
	@EndPeriod			DATETIME,
	@CostRank			INT = -1
AS
BEGIN

	SET NOCOUNT ON;

	SET @StartPeriod = (DATEADD(month, DATEDIFF(month, 0, @StartPEriod), 0));
	SET @EndPeriod = (DATEADD(d, -1, DATEADD(m, DATEDIFF(m, 0, @EndPeriod) + 1, 0)));

	CREATE TABLE #TempJobOrders
	(
		JobOrderGuid		UNIQUEIDENTIFIER,
		JobOrderOperatingBOM	UNIQUEIDENTIFIER,
		UseSpoilage			BIT
	)


	CREATE TABLE #DirectMaterialsCosts
	(
		JobOrderGuid		UNIQUEIDENTIFIER,
		RawMaterialGuid		UNIQUEIDENTIFIER, 
		FinishedGoodGuid	UNIQUEIDENTIFIER,
		StageGuid			UNIQUEIDENTIFIER, 
		AllocationType		INT,
		Unit				INT,
		ExpensedQty			FLOAT,
		ReturnedQty			FLOAT,
		NetQty				FLOAT,
		NetValue			FLOAT,
		RawIndex			INT,
		FinishedIndex		INT,
		FinishedGoodCost	FLOAT
	)

	CREATE TABLE [#DirectLabors]
	(
		[WorkerGuid]			UNIQUEIDENTIFIER,
		[MaterialGuid]			UNIQUEIDENTIFIER,
		[StageGuid]				UNIQUEIDENTIFIER,
		[NumberOfHours]			FLOAT,
		[TotalWorkingHoursCost]	FLOAT,
		[MaterialCost]			FLOAT,
		[WorkerIndex]			INT,
		[MaterialIndex]			INT,
		[JobOrderGuid]			UNIQUEIDENTIFIER
	) 

	CREATE TABLE [#MOHCosts]
	(
		FinishedGoodGuid	UNIQUEIDENTIFIER,
		JobOrderGUID		UNIQUEIDENTIFIER,
		Percentage			FLOAT
	)

	CREATE TABLE[#GeneralCosts]
	(
		MaterialGuid			UNIQUEIDENTIFIER,
		RequiredQty				FLOAT,
		Unit					INT,
		UnitName				NVARCHAR(250),
		TotalDirectMaterials	FLOAT,
		TotalDirectLabors		FLOAT,
		TotalMOH				FLOAT,
		TotalProductionCost		FLOAT, 
		ActualProduction		FLOAT,
		UnitCost				FLOAT,
		ProductionQuantity		FLOAT,
		SellPrice				FLOAT,
		SellValue				FLOAT,
		MaterialIndex			INT,
		JobOrderGuid			UNIQUEIDENTIFIER,
		TotalDirectExpenses		MONEY
	)

	CREATE TABLE #SpoilageCosts
	(
		TotalProductionCost			FLOAT,
		TotalProductionQty			FLOAT, 
		ProductionUnit				INT,
		ProductionUnitCost			FLOAT,
		FlawLessQty					FLOAT, 
		SpoilageQty					FLOAT,
		NormalSpoilageQty			FLOAT,
		AbnormalSpoilageQty			FLOAT,
		FlawlessUnitCost			FLOAT,
		TotalSpoilageCost			FLOAT,
		SpoilageSellPrice			FLOAT,
		DeliveredSpoilageValue		FLOAT,
		NormalSpoilageNetCost		FLOAT,
		AbnormalSpoilageNetCost		FLOAT,
		SpoilageMaterialGuid		UNIQUEIDENTIFIER,
		FinishedProductGuid			UNIQUEIDENTIFIER,
		StandardSpoilageQty			FLOAT,
		StandardSpoilagePercentage	FLOAT,
		JobOrderGuid				UNIQUEIDENTIFIER
	)



	--JobOrders

	INSERT INTO #TempJobOrders
	SELECT jo.JobOrderGuid,
	jo.JobOrderOperatingBOM,
	jo.UseSpoilage
	 FROM JocVwJobOrder jo
	WHERE (jo.JobOrderManufactoryGuid = @ManufactoryGUid OR @ManufactoryGUid = 0x0)
	AND jo.JobOrderStartDate >= @StartPeriod
	AND jo.JobOrderEndDate <= @EndPeriod
	AND (jo.OperatingBOMCostRank = @CostRank OR @CostRank = -1)

	--====================================================================================================================
	--Direct Materials

	INSERT INTO #DirectMaterialsCosts 
		SELECT vw.JobOrderGuid,
		fn.RawMaterialGuid,
		fn.FinshedGoodsGuid,
		fn.StageGuid,
		vw.DistMethod,
		vw.Unit,
		vw.ExpensedQty,
		vw.ReturnedQty,
		vw.NetQty,
		vw.NetExchange,
		rm.RawMaterialIndex,
		rm.FinishedProductIndex,
		fn.CostDist
		FROM JOCvwJobOrderRawMaterialsQuantities vw
		INNER JOIN #TempJobOrders jo ON jo.JobOrderGuid = vw.JobOrderGuid
		INNER JOIN JOCfnCalcJobOrderCostDist(0x0) fn
		 ON vw.JobOrderGuid = fn.JobOrderGuid AND vw.MaterialGuid = fn.RawMaterialGuid AND vw.StageGuid = fn.StageGuid
		INNER JOIN JOCOperatingBOMRawMaterials000 rm 
		 ON rm.RawMaterialGuid = fn.RawMaterialGuid AND rm.FinishedProductGuid = fn.FinshedGoodsGuid AND rm.StageGuid = fn.StageGuid AND jo.JobOrderOperatingBOM = rm.OperatingBOMGuid
		 WHERE 
		  (vw.ExpensedQty > 0 OR vw.ReturnedQty > 0 OR vw.TransOutQty > 0 OR vw.TransInQty > 0)


	DELETE FROM JOCJobOrderDirectMaterials000 
	WHERE JobOrderGuid IN (SELECT JobOrderGuid FROM #DirectMaterialsCosts)

	INSERT INTO JOCJobOrderDirectMaterials000
	SELECT 
	dm.JobOrderGuid,
	dm.RawMaterialGuid,
	dm.FinishedGoodGuid,
	dm.StageGuid,
	dm.AllocationType,
	dm.Unit,
	dm.ExpensedQty,
	dm.ReturnedQty,
	dm.NetQty,
	dm.NetValue,
	dm.RawIndex,
	dm.FinishedIndex,
	dm.FinishedGoodCost
	FROM #DirectMaterialsCosts dm

	--===========================================================================================
	--Direct labors

	EXEC JOCprcRecalculateJobOrdersDirectLaborsCosts @ManufactoryGUid, @StartPeriod, @EndPeriod, @CostRank

	INSERT INTO [#DirectLabors]
		SELECT 
			[WorkerGuid], 
			[MaterialGuid],
			[StageGuid],
			[NumberOfHours],
			[TotalWorkingHoursCost],
			[MaterialCost],
			[WorkerIndex],
			[MaterialIndex],
			[JobOrderGuid] 
		FROM JOCJobOrderDirectLabors000

	--==================================================================================================

	INSERT INTO [#MOHCosts] 
	SELECT vw.* FROM JOCvwJobOrderMaterialsMOHCosts vw
	INNER JOIN #TempJobOrders jo ON vw.JobOrderGuid = jo.JobOrderGuid

	--==================================================================================================
	--General Costs

	INSERT INTO #GeneralCosts
	SELECT vw.*
    FROM JOCvwMaintenanceGeneralCosts vw 
	INNER JOIN #TempJobOrders j ON j.JobOrderGuid = vw.JobOrderGuid


	UPDATE #GeneralCosts 
	SET TotalDirectMaterials = (SELECT SUM(FinishedGoodCost) FROM #DirectMaterialsCosts
		WHERE #GeneralCosts.JobOrderGuid = #DirectMaterialsCosts.JobOrderGuid 
		AND #GeneralCosts.MaterialGuid = #DirectMaterialsCosts.FinishedGoodGuid)


	UPDATE #GeneralCosts 
	SET TotalDirectLabors = (SELECT SUM(tmp.MaterialCost) FROM #DirectLabors tmp
	WHERE tmp.MaterialGuid = #GeneralCosts.MaterialGuid AND tmp.JobOrderGuid = #GeneralCosts.JobOrderGuid)
		
	Update #GeneralCosts 
	SET TotalMOH = (SELECT SUM(Percentage) FROM [#MOHCosts]
	WHERE FinishedGoodGuid = #GeneralCosts.MaterialGuid AND #GeneralCosts.JobOrderGuid = #MOHCosts.JobOrderGUID)

	UPDATE GENERAL
	SET GENERAL.TotalDirectExpenses = COSTS.TotalDirectExpenses,
		GENERAL.RequiredQty = COSTS.RequiredQty
	FROM #GeneralCosts GENERAL 
	INNER JOIN JOCJobOrderCosts000 COSTS ON GENERAL.JobOrderGuid = COSTS.JobOrderGuid AND GENERAL.MaterialGuid = COSTS.FinishedMaterialGuid

	Update #GeneralCosts 
	SET TotalProductionCost = (TotalDirectMaterials + TotalDirectLabors + TotalMOH + ISNULL(TotalDirectExpenses, 0))

	UPDATE #GeneralCosts 
	SET UnitCost = TotalProductionCost / ActualProduction, 
		SellValue = ActualProduction * SellPrice

	UPDATE #GeneralCosts 
	SET ProductionQuantity = 
		(CASE WHEN FinishedGoodsQtys.ManufUsedUnit = 1 THEN  FinishedGoodsQtys.FirstProductionUnityQty ELSE  FinishedGoodsQtys.SecondProductionUnityQty END )
	FROM #GeneralCosts AS Costs
	INNER JOIN JOCvwJobOrderFinishedGoodsBillItemsQtys FinishedGoodsQtys 
	ON Costs.MaterialGuid = FinishedGoodsQtys.MaterialGuid AND FinishedGoodsQtys.JobOrderGuid = Costs.JobOrderGuid
	
	DELETE COSTS
	FROM JOCJobOrderCosts000 COSTS 
	INNER JOIN #GeneralCosts GENERAL ON COSTS.JobOrderGuid = GENERAL.JobOrderGuid

	INSERT INTO JOCJobOrderCosts000
	SELECT g.JobOrderGuid,
		   g.MaterialGuid,
		   g.RequiredQty,
		   g.Unit,
		   g.TotalDirectMaterials,
		   g.TotalDirectLabors,
		   g.TotalMOH,
		   g.TotalProductionCost,
		   g.ActualProduction,
		   g.UnitCost,
		   g.ProductionQuantity,
		   g.SellPrice,
		   g.SellValue,
		   g.TotalDirectExpenses
	 FROM #GeneralCosts g

	--==================================================================================================
	--
	--Spoilage

	INSERT INTO #SpoilageCosts
	SELECT
	 generalCosts.TotalProductionCost,
	 generalCosts.ActualProduction,
	 generalCosts.Unit,
	 generalcosts.UnitCost,
	 0,
	 0,
	 0,
	 0,
	 0,
	 0,
	 CASE WHEN bomFinishedGoods.SpoilageSellPrice < generalcosts.UnitCost THEN bomFinishedGoods.SpoilageSellPrice ELSE generalcosts.UnitCost END,
	 0,
	 0,
	 0,
	 bomFinishedGoods.SpoilageMaterial,
	 bomFinishedGoods.MaterialGuid,
	 bomFinishedGoods.SpoilageQty,
	 bomFinishedGoods.SpoilagePercentage / 100
	 ,generalcosts.JobOrderGuid
	FROM #GeneralCosts generalCosts
	INNER JOIN #TempJobOrders JobOrder ON joborder.JobOrderGuid = generalCosts.JobOrderGuid
	INNER JOIN JOCOperatingBOMFinishedGoods000 bomFinishedGoods ON generalCosts.MaterialGuid = bomFinishedGoods.MaterialGuid AND bomFinishedGoods.OperatingBOMGuid = JobOrder.JobOrderOperatingBOM
	WHERE JobOrder.UseSpoilage = 1

	
	UPDATE #SpoilageCosts
	SET FlawLessQty = 
		ISNULL(	(SELECT SUM(deliveredMaterials.QtyByBomUnit)
				FROM JOCvwJobOrderDeliveredFlawlessMaterials deliveredMaterials 
				GROUP BY deliveredMaterials.MaterialGuid,
				deliveredMaterials.JobOrderGuid
				HAVING  #SpoilageCosts.FinishedProductGuid = deliveredMaterials.MaterialGuid
				AND deliveredMaterials.JobOrderGuid = #SpoilageCosts.JobOrderGuid
	
				), 0)

	,SpoilageQty = 
		ISNULL( (SELECT SUM(deliveredMaterials.QtyByBomUnit)
		FROM JOCvwJobOrderDeliveredSpoiledMaterials deliveredMaterials 
		GROUP BY deliveredMaterials.MaterialGuid,
			deliveredMaterials.JobOrderGuid
		HAVING  #SpoilageCosts.SpoilageMaterialGuid = deliveredMaterials.MaterialGuid
		AND deliveredMaterials.JobOrderGuid = #SpoilageCosts.JobOrderGuid
	),0)

		-- ßãíÉ ÇáÊáÝ ÇáØÈíÚí
	UPDATE #SpoilageCosts 
	SET NormalSpoilageQty = CASE 
			WHEN (#SpoilageCosts.SpoilageQty = 0) THEN 0
			WHEN (#SpoilageCosts.SpoilageQty < (#SpoilageCosts.StandardSpoilageQty + (#SpoilageCosts.TotalProductionQty * #SpoilageCosts.StandardSpoilagePercentage)))
			THEN #SpoilageCosts.SpoilageQty
			ELSE (#SpoilageCosts.StandardSpoilageQty + (#SpoilageCosts.TotalProductionQty * #SpoilageCosts.StandardSpoilagePercentage))
			END

	--ßãíÉ ÇáÊáÝ ÛíÑ ÇáØÈíÚí
	UPDATE #SpoilageCosts 
	SET AbnormalSpoilageQty = CASE WHEN (#SpoilageCosts.SpoilageQty < (#SpoilageCosts.StandardSpoilageQty + (#SpoilageCosts.TotalProductionQty * #SpoilageCosts.StandardSpoilagePercentage)))
								  THEN 0 ELSE (#SpoilageCosts.SpoilageQty - #SpoilageCosts.NormalSpoilageQty ) END
	--ÅÌãÇáí ßáÝÉ ÇáÊáÝ
	, TotalSpoilageCost = SpoilageQty * ProductionUnitCost

	--ÞíãÉ ÇáÊáÝ ÇáãÓáã ááãÓÊæÏÚ
	,DeliveredSpoilageValue = SpoilageQty * SpoilageSellPrice

	--ÕÇÝí ßáÝÉ ÇáÊáÝ ÇáØÈíÚí
	,NormalSpoilageNetCost = (ProductionUnitCost - SpoilageSellPrice) * NormalSpoilageQty

	--ÕÇÝí ßáÝÉ ÇáÊáÝ ÛíÑ ÇáØÈíÚí
	UPDATE #SpoilageCosts
	SET AbnormalSpoilageNetCost = (ProductionUnitCost - SpoilageSellPrice) * AbnormalSpoilageQty

	--ßáÝÉ ÇáæÍÏÉ ÇáÓáíãÉ
	UPDATE #SpoilageCosts
	SET FlawlessUnitCost =  CASE WHEN FlawLessQty > 0 THEN (TotalProductionCost - DeliveredSpoilageValue - AbnormalSpoilageNetCost) / FlawLessQty ELSE 0 END

	

	DELETE FROM JOCJobOrderSpoilage000
	WHERE JobOrderGuid IN (SELECT JobOrderGuid FROM #SpoilageCosts)


	INSERT INTO JOCJobOrderSpoilage000
	SELECT 
	s.FinishedProductGuid,
	s.SpoilageMaterialGuid,
	s.TotalProductionCost,
	s.TotalProductionQty,
	s.ProductionUnit,
	s.ProductionUnitCost,
	s.FlawLessQty,
	s.SpoilageQty,
	s.NormalSpoilageQty,
	s.AbnormalSpoilageQty,
	s.FlawlessUnitCost,
	s.TotalSpoilageCost,
	s.SpoilageSellPrice,
	s.DeliveredSpoilageValue,
	s.NormalSpoilageNetCost,
	s.AbnormalSpoilageNetCost,
	s.JobOrderGuid,
	f.MaterialIndex
	FROM #SpoilageCosts s
	INNER JOIN #TempJobOrders jo ON jo.JobOrderGuid = s.JobOrderGuid
	INNER JOIN JOCOperatingBOMFinishedGoods000 f ON s.FinishedProductGuid = f.MaterialGuid AND jo.JobOrderOperatingBOM = f.OperatingBOMGuid


	DROP TABLE [#DirectMaterialsCosts]
	DROP TABLE [#DirectLabors]
	DROP TABLE #MOHCosts
	DROP TABLE #GeneralCosts
	DROP TABLE #SpoilageCosts
END
######################################################################

CREATE PROC JOCprcMntRegenerateJobOrdersBills
@ManufactoryGuid	UNIQUEIDENTIFIER,
@StartPeriod		DATETIME,
@EndPeriod			DATETIME

--ÅÚÇÏÉ ÊæáíÏ ÝæÇÊíÑ ÃæÇãÑ ÇáÊÔÛíá æÍÓÇÈ ßáÝåÇ Úáì ãÓÊæì ÑÊÈ ÃæÇãÑ ÇáÊÔÛíá
--1- get raw materials sorted by costranks
--2- calculate out balance average prices for every rank. 
--3- update joc raw materials bills .
--4- recalculate joborders' costs that.
--5- regenerate finished goods bills. 
AS
	SET NOCOUNT ON

	SET @StartPeriod =  (DATEADD(month, DATEDIFF(month, 0, @StartPEriod), 0))
	SET @EndPeriod = (DATEADD(d, -1, DATEADD(m, DATEDIFF(m, 0, @EndPeriod) + 1, 0)))

	SELECT  
		jo.JobOrderGuid,
		jo.JobOrderOperatingBOM,
		jo.JobOrderAccount
	INTO ##TempJobOrders
	FROM JocVwJobOrder jo
	WHERE jo.JobOrderStartDate >= @StartPeriod 
	AND jo.JobOrderEndDate <= @EndPeriod
	AND jo.JobOrderStatus = 0
	AND (jo.JobOrderManufactoryGuid = @ManufactoryGuid OR @ManufactoryGuid = 0x0)


	SELECT DISTINCT 
		rm.RawMaterialGuid,
		rm.CostRank,
		p.StartDate AS StartDate,
		p.EndDate AS EndDate
	INTO #TempRawMaterials
	FROM JOCOperatingBOMRawMaterials000 rm 
	JOIN ##TempJobOrders jo ON rm.OperatingBOMGuid = jo.JobOrderOperatingBOM
	CROSS JOIN [dbo].[fnGetPeriod](3, @StartPeriod, @EndPeriod)  p
	ORDER BY rm.CostRank

	CREATE TABLE #TempManufactoryBillTypes
	(
		ManufactoryGuid	UNIQUEIDENTIFIER,
		BillTypeGuid	UNIQUEIDENTIFIER
	)

	INSERT INTO #TempManufactoryBillTypes
	SELECT [Guid], [MatRequestBillType] FROM Manufactory000 WHERE ([Guid] = @ManufactoryGuid OR @ManufactoryGuid = 0x0)
	UNION ALL
	SELECT [Guid], [MatReturnBillType] FROM Manufactory000 WHERE ([Guid] = @ManufactoryGuid OR @ManufactoryGuid = 0x0)
	UNION ALL
	SELECT [Guid], [InTransBillType] FROM Manufactory000 WHERE ([Guid] = @ManufactoryGuid OR @ManufactoryGuid = 0x0)	
	UNION ALL
	SELECT [Guid], [OutTransBillType] FROM Manufactory000 WHERE ([Guid] = @ManufactoryGuid OR @ManufactoryGuid = 0x0)

	DECLARE @SrcGuid UNIQUEIDENTIFIER = NEWID();

	INSERT INTO RepSrcs (IdTbl, IdType, IdSubType)
	SELECT @SrcGuid,tmp.BillTypeGuid, 2 FROM #TempManufactoryBillTypes tmp
	--=============================================================================================================================


	DECLARE @i INT = 0;
	DECLARE @RankCount INT = (SELECT MAX(CostRank) FROM #TempRawMaterials)

	WHILE @i <= @RankCount
	BEGIN
		
		EXEC JOCprcCalculateOutBalanceAveragePrice @i, @StartPeriod, @EndPeriod

		EXEC JOCprcUpdateJobOrdersRawMaterialsBills @i, @SrcGuid, @StartPeriod, @EndPeriod
		
		DECLARE @JobOrderCostRank INT = @i + 1
		EXEC JOCprcRecalculateJobOrdersCosts @ManufactoryGuid, @StartPeriod, @EndPeriod, @JobOrderCostRank

		EXEC JOCprcMntUpdateJobOrdersDeliveryBills @StartPeriod, @EndPeriod, @ManufactoryGuid, @JobOrderCostRank

		SET @i = @i + 1

		DROP TABLE ##TempRawMaterialsOutBalanceAvgPrices
	END


DELETE FROM RepSrcs WHERE IdTbl = @SrcGuid
	
DROP TABLE ##TempJobOrders
DROP TABLE #TempManufactoryBillTypes
DROP TABLE #TempRawMaterials
######################################################################
CREATE PROC CheckFinishedMatOnDirectExpenesIfNotProduced
	@JobOrederGuid	UNIQUEIDENTIFIER
	AS
	SET NOCOUNT ON
		SELECT TOP 1 items.MatGuid , items.ParentGuid
		  FROM JOCBOMJobOrderEntry000 AS ENTRY 
		   INNER JOIN  JOCBOMDirectExpenseItems000 AS items ON items.ParentGuid = entry.GUID 
		   WHERE entry.JobOrderGUID = @JobOrederGuid
		   AND items.TotalExpenses <> 0 
		   AND items.MatGuid NOT IN (SELECT MaterialGuid FROM JOCvwJobOrderFinishedGoodsBillItemsQtys WHERE entry.JobOrderGUID = @JobOrederGuid)

######################################################################
CREATE PROCEDURE JOCprcGetMOHPlanUserApprovals
	@ManufactoryGuid UNIQUEIDENTIFIER,
	@FromMohPlan INT
AS
	DECLARE @IsInforceSequenceOfApprovals BIT
	
	IF(@FromMohPlan = 1)
	BEGIN
		IF EXISTS(SELECT * FROM JOCMOHPlanUsersApproval000 WHERE ManufatoryGuid = @ManufactoryGuid)
		BEGIN
			SELECT TOP 1 @IsInforceSequenceOfApprovals = IsInforceSequenceOfApprovals 
			FROM JOCMOHPlanUsersApproval000
			WHERE ManufatoryGuid = @ManufactoryGuid
			SELECT 
				US.[GUID] UserGuid,
				US.LoginName,
				MOHUS.UserOrder,
				@IsInforceSequenceOfApprovals AS IsInforceSequenceOfApprovals,
				MOHUS.Approved,
				MOHUS.Date,
				MOHUS.Time,
				MOHUS.PcName
			FROM JOCMOHPlanUsersApproval000 MOHUS 
			INNER JOIN us000 US ON MOHUS.UserGuid = US.[GUID] 
			WHERE MOHUS.ManufatoryGuid = @ManufactoryGuid
			ORDER BY MOHUS.UserOrder 
			RETURN 
		END
	END
	SELECT TOP 1 @IsInforceSequenceOfApprovals = IsInforceSequenceOfApprovals 
	FROM JOCFactoryUsersApproval000
	WHERE ManufatoryGuid = @ManufactoryGuid
	SELECT 
		  US.[GUID] UserGuid,
		  US.LoginName,
		  (CASE ISNULL(MOHUS.UserOrder, 0) 
				WHEN 0 THEN 10000
				ELSE MOHUS.UserOrder 
		   END) UserOrder,
		  (CASE ISNULL(MOHUS.UserGuid , 0x0) 
				WHEN 0x0 THEN 0 
				ELSE 1 
		   END) AS IsUserChecked,
		  (CASE @IsInforceSequenceOfApprovals
			    WHEN 0 THEN 0 
				ELSE 1 
		   END) AS IsInforceSequenceOfApprovals,
			0 AS Approved,
		    '1980-01-01' AS Date,
		    '' AS Time,
			'' AS PcName
	FROM JOCFactoryUsersApproval000 MOHUS 
	RIGHT JOIN us000 US ON MOHUS.UserGuid = US.[GUID] AND MOHUS.ManufatoryGuid = @ManufactoryGuid
	WHERE [Type] = 0 AND IsInactive = 0 AND (@FromMohPlan = 0 OR (@FromMohPlan = 1 AND MOHUS.UserGuid IS NOT NULL))
	ORDER BY UserOrder, US.Number
######################################################################
CREATE PROCEDURE JOCprcAddMOHPlanUserApprovals
	@ManufactoryGuid UNIQUEIDENTIFIER,
	@UserGuid UNIQUEIDENTIFIER,
	@Approved	INT
AS
	SET NOCOUNT ON
	UPDATE JOCMOHPlanUsersApproval000
	SET Approved = @Approved,
		Date	 = CASE WHEN @Approved = 1 THEN GETDATE()ELSE '1-1-1980' END,
		Time	 = CASE WHEN @Approved = 1 THEN CONVERT(NVARCHAR, GETDATE(), 108) ELSE '' END,
		PcName   = CASE WHEN @Approved = 1 THEN HOST_NAME()ELSE '' END
	WHERE ManufatoryGuid = @ManufactoryGuid AND UserGuid = @UserGuid
######################################################################
CREATE PROCEDURE JOCprcModifyJobOrderMachinesWorkingHours
	@FactoryGuid UNIQUEIDENTIFIER
AS
	SET NOCOUNT ON
	BEGIN
		UPDATE JobOrder000 
		SET OperatingMachinesHours = 0 
		WHERE ManufactoryGUID = @FactoryGuid

		UPDATE W 
		SET W.PeriodWorkingMachinsHours = 0
		FROM JOCJobOrderGeneralExpenses000 W
		INNER JOIN JobOrder000 J ON W.JobOrderGuid = J.Guid
		WHERE J.ManufactoryGUID = @FactoryGuid
	END
######################################################################
CREATE PROCEDURE JOCprcCheckExpensesAccount
@plGuid UNIQUEIDENTIFIER,
@AccGuid UNIQUEIDENTIFIER
AS
	SET NOCOUNT ON
	BEGIN
		SELECT pl.Guid , pl.Name , pl.LatinName 
		FROM ProductionLine000 AS pl 
		INNER JOIN (SELECT GUID 
					FROM [dbo].[fnGetAccountsList](@AccGuid, 1) 
					WHERE GUID <> 0x0 ) AS Src ON Src.GUID = pl.ExpensesAccount 
		WHERE pl.Guid <> @plGuid

		SELECT pl.Guid , pl.Name , pl.LatinName  
		FROM ProductionLine000 AS pl 
		INNER JOIN (SELECT GUID 
					FROM [dbo].[fnGetAccountParents](@AccGuid)
					WHERE GUID <> 0x0 ) AS Src ON Src.GUID = pl.ExpensesAccount 
		WHERE pl.Guid <> @plGuid
	END
######################################################################
CREATE FUNCTION JOCfngetStandardQty(@MaterialGuid UNIQUEIDENTIFIER, @JobOrderGuid UNIQUEIDENTIFIER,  @StageGuid UNIQUEIDENTIFIER)
RETURNS TABLE
RETURN 
	(Select Distinct (CASE MatsQty.DistMethod 
			   WHEN 1 THEN StanderdQty.TotalStandardQuantity
			   ELSE 
					CASE OperatingBom.JointCostsAllocationType 
						WHEN 0 THEN (MatsQty.RawMatQty * MatsQty.UnitFactor * BillItems.FirstProductionUnityQty) 
					   					 /
					   			    ISNULL((SELECT dbo.JOCfnGetBOMFiniShedMatsTotalQty(MatsQty.JobOrderGuid, MatsQty.JobOrderOperatingBOM)), 1)
					     WHEN 1 THEN 
									(FinishedGoodsBOMSellPrice.FinishedGoodsSellPrice * MatsQty.RawMatQty * MatsQty.UnitFactor)
					  					/ 
					  				(ISNULL((SELECT dbo.JOCfnGetTotalBOMSellPrice(MatsQty.JobOrderOperatingBOM, MatsQty.JobOrderGuid)), 1))
										/
									ISNULL((SELECT dbo.JOCfnGetFinishedProdBOMQty(FinishedGoodsBOMSellPrice.FinishedGoodsGuid)), 1)
									*
									BillItems.FirstProductionUnityQty
				    END
		  END) AS StandardQuantity
		  FROM JOCvwJobOrderRawMaterialsQuantities AS MatsQty
		  INNER JOIN JOCvwJobOrderTotalProductsStandardQuantity StanderdQty ON StanderdQty.RawMaterialGuid = MatsQty.MaterialGuid and StanderdQty.JobOrderGuid = StanderdQty.JobOrderGuid and StanderdQty.StageGuid = MatsQty.StageGuid
		  INNER JOIN JOCJobOrderOperatingBOM000 OperatingBom ON  OperatingBom.guid = MatsQty.JobOrderOperatingBOM
		  INNER JOIN JOCJobOrderDirectMaterials000 AS ActualProd ON MatsQty.JobOrderGuid = ActualProd.JobOrderGuid AND MatsQty.MaterialGuid = ActualProd.RawMaterialGuid And MatsQty.StageGuid = ActualProd.StageGuid
		  INNER JOIN JOCvwJobOrderFinishedGoodsBillItemsQtys BillItems ON ActualProd.JobOrderGuid = BillItems.JobOrderGuid AND ActualProd.FinishedGoodGuid = BillItems.MaterialGuid
		  INNER JOIN JOCvwJobOrderOperatingBOMFinishedGoodsSellPrice FinishedGoodsBOMSellPrice ON FinishedGoodsBOMSellPrice.OperatingBOMGuid = MatsQty.JobOrderOperatingBOM AND FinishedGoodsBOMSellPrice.JobOrderGuid = MatsQty.JobOrderGuid
																								AND FinishedGoodsBOMSellPrice.FinishedGoodsGuid = ActualProd.FinishedGoodGuid
		  WHERE 
				MatsQty.MaterialGuid = @MaterialGuid 
				AND 
				MatsQty.JobOrderGuid = @JobOrderGuid 
				AND 
				MatsQty.StageGuid = @StageGuid)
######################################################################
CREATE PROCEDURE prcResetProductionLinesCosts
	@StartDate DATETIME  =  '1-1-1980',
	@EndDate DATETIME  =  '1-1-1980',
	@DataBase NVARCHAR (MAX)

AS 
	SET NOCOUNT ON 
	
	IF LEFT(@DataBase, 1) <> N'['
	BEGIN
		SET @DataBase = N'[' + @DataBase + N']';
	END

	DECLARE @Sql NVARCHAR(MAX) = ' DELETE FROM ' + @DataBase + '..Plcosts000 '

	SET @Sql = @Sql + ' INSERT INTO ' + @DataBase+ '..Plcosts000 (ProductionLine, StartPeriodDate, EndPeriodDate, EstimatedCost, ActualCost) 
	SELECT pl.ProductionLine,
		   per.StartDate,
		   per.EndDate,
		   0,
		   0
	FROM (SELECT DISTINCT ProductionLine FROM Plcosts000) AS pl
	 CROSS JOIN dbo.fnGetPeriod(3,'''+ CAST(@StartDate AS NVARCHAR) + ''' , ''' +  CAST(@EndDate AS NVARCHAR) +''' ) AS per '
	SET @Sql = @Sql + ' UPDATE ' + @DataBase + '..ProductionLine000 SET ActualCost = 0 , EstimatedCost = 0'
	
	 EXEC(@Sql)
######################################################################
CREATE PROCEDURE Joc_Prc_TotalOneRawMaterialDeviation
	@BOM				  UNIQUEIDENTIFIER,
	@MatGuid			  UNIQUEIDENTIFIER,
	@Manufactory		  UNIQUEIDENTIFIER,
	@ProductionLine		  UNIQUEIDENTIFIER,
	@StartDate			  DATE,
	@EndDate			  DATE
AS
SET NOCOUNT ON
	---------------------------------------------
		CREATE TABLE #Result
	(
		JobOrderGuid             UNIQUEIDENTIFIER,
		JobOrderNumber		     INT,
		JobOrderName		     NVARCHAR(250),
		JobOrderStartDate	     DATE,
		JobOrderTargetEndDate    DATE,
		JobOrderEndDate			 DATE,
		ManufactoryName		     NVARCHAR(250),
		FactoryNumber			 INT,
		BOMName					 NVARCHAR(250),
		ProuductionLineName		 NVARCHAR(250),
		ProuductionLineGuid      UNIQUEIDENTIFIER,
		MatGuid					 UNIQUEIDENTIFIER,
		GroupGuid				 UNIQUEIDENTIFIER,
		ProductionUnit			 NVARCHAR(100),
		ActualProductionQty		 FLOAT,
		StandardQty				 FLOAT,
		ConsumedQty				 FLOAT,
		StandardQtyByProductionUnit	FLOAT,
		ConsumedQtyByProductionUnit	FLOAT,
		QuantamDeviation		 FLOAT,
		QuantamDeviationInUnit	 FLOAT,
		DeviationRatio			 FLOAT,
		StandardValue			 FLOAT,
		ConsumedValue			 FLOAT,
		StandardValueByProductionUnit	FLOAT,
		ConsumedValueByProductionUnit	FLOAT,
		DeviationValue			 FLOAT,
		DeviationValueInUnit	 FLOAT,
		PercentageDeviationValue FLOAT,
		Price					 FLOAT
	)
	---------------------------------------------
	CREATE TABLE #TempResult --MATERIALS EXIST MARE THAN ONE TIME ACCORDING TO JOBORDER
	(
		JobOrderGuid             UNIQUEIDENTIFIER,
		JobOrderNumber		     INT,
		JobOrderName		     NVARCHAR(250),
		JobOrderStartDate	     DATE,
		JobOrderTargetEndDate    DATE,
		JobOrderEndDate			 DATE,
		manufactName		     NVARCHAR(250),
		FactoryNumber			 INT,
		BOMName					 NVARCHAR(250),
		ProuductionLineName		 NVARCHAR(250),
		ProuductionLineGuid      UNIQUEIDENTIFIER,
		MatGuid					 UNIQUEIDENTIFIER,
		GroupGuid				 UNIQUEIDENTIFIER,
		ProductionUnit			 NVARCHAR(100),
		ActualProductionQty		 FLOAT,
		StandardQty				 FLOAT,
		ConsumedQty				 FLOAT,
		Price					 FLOAT
	)
	---------------------------------------------
	INSERT INTO #TempResult
		SELECT
			JobOrder.Guid
			,JobOrder.Number
			,JobOrder.Name
			,JobOrder.StartDate
			,JobOrder.TargetEndDate
			,JobOrder.EndDate
			,manufact.Name
			,manufact.InsertNumber
			,BOM.Name
			,ProductionLine.Name
			,ProductionLine.Guid
			,materials.GUID
			,MaterialGr.GUID
			,Unit.Name
			,ActualQuantity.Qty
			,(CASE MatsQty.DistMethod  
				WHEN 0 THEN (SELECT  dbo.JOCfngetTotalStandardQty(MatsQty.MaterialGuid, MatsQty.JobOrderGuid, MatsQty.StageGuid))
				ELSE StanderdQty.TotalStandardQuantity 
			 END )
			,(MatBill.TotalOutQty - MatBill.TotalInQty) * MatsQty.UnitFactor
			, (CASE WHEN MatsQty.BOMNetQty=0 THEN 0 ELSE(MatsQty.NetExchange) END)
		FROM JOCvwJobOrderRawMaterialsQuantities AS MatsQty
			INNER JOIN JocVwMaterialsWithAlternatives materials ON materials.GUID = MatsQty.MaterialGuid
			INNER JOIN gr000 AS MaterialGr  ON MaterialGr.GUID = materials.GroupGUID
			INNER JOIN Manufactory000 AS manufact ON manufact.GUID = MatsQty.JobOrderManufactoryGuid
			INNER JOIN JOCProductionUnit000 Unit ON Unit.GUID = manufact.UsedProductionUnit
			INNER JOIN JOCvwBillItemsQtys MatBill ON MatBill.MaterialGuid = MatsQty.MaterialGuid and MatsQty.JobOrderGuid = MatBill.JobOrderGuid and MatBill.StageGuid = MatsQty.StageGuid
			INNER JOin JOCvwJobOrderTotalProductsStandardQuantity StanderdQty ON StanderdQty.RawMaterialGuid = MatsQty.MaterialGuid and StanderdQty.JobOrderGuid = StanderdQty.JobOrderGuid and StanderdQty.StageGuid = MatsQty.StageGuid
			INNER JOIN JOCBOM000 AS BOM ON BOM.GUID = MatsQty.JobOrderBOM
			INNER JOIN JobOrder000 JobOrder ON  JobOrder.Guid = MatsQty.JobOrderGuid
			INNER JOIN ProductionLine000 ProductionLine ON ProductionLine.Guid = JobOrder.ProductionLine
			CROSS APPLY JOCfnGetJobOrderTotalProductsQtys(MatsQty.JobOrderGuid, 1) AS ActualQuantity
		WHERE
			MatsQty.JobOrderStatus=0
			AND
			@BOM=CASE WHEN  ISNULL (@BOM,0x0)=0x0  THEN 0x0 ELSE BOM.GUID  END
			AND
			@Manufactory=CASE WHEN  ISNULL (@Manufactory,0x0)=0x0  THEN 0x0 ELSE MatsQty.JobOrderManufactoryGuid END
			AND
			@ProductionLine=CASE WHEN  ISNULL (@ProductionLine,0x0)=0x0  THEN 0x0 ELSE MatsQty.JobOrderProductionLine END
			AND 
			@MatGuid = StanderdQty.RawMaterialGuid
			AND 
			MatsQty.JobOrderEndDate >= @StartDate AND MatsQty.JobOrderEndDate <= @EndDate
			Group By
			JobOrder.Guid
			,JobOrder.Number
			,JobOrder.Name
			,JobOrder.StartDate
			,JobOrder.TargetEndDate
			,JobOrder.EndDate
			,manufact.Name
			,manufact.InsertNumber
			,BOM.Name
			,ProductionLine.Name
			,ProductionLine.Guid
			,materials.GUID
			,MaterialGr.GUID
			,Unit.Name
			,MatsQty.MaterialGuid
			,MatsQty.JobOrderGuid
			,MatsQty.StageGuid
			,MatsQty.DistMethod  
			,StanderdQty.TotalStandardQuantity 
			,MatBill.TotalOutQty
			,MatBill.TotalInQty
			,MatsQty.UnitFactor
			,MatsQty.BOMNetQty
			,MatsQty.NetExchange
			,ActualQuantity.Qty
			-------------------------------------------------------
	INSERT INTO #Result
		SELECT 
			JobOrderGuid            
			,JobOrderNumber		    
			,JobOrderName		    
			,JobOrderStartDate	    
			,JobOrderTargetEndDate   
			,JobOrderEndDate			
			,manufactName
			,FactoryNumber		    
			,BOMName
			,ProuductionLineName
			,ProuductionLineGuid
			,MatGuid					
			,GroupGuid
			,ProductionUnit
			,ActualProductionQty
			,SUM(StandardQty) 
			,SUM(ConsumedQty)
			,0
			,0
			,0
			,0
			,0
			,0
			,0
			,0
			,0
			,0
			,0
			,0
			,SUM(Price)
		FROM #TempResult
		GROUP BY 
			JobOrderGuid            
			,JobOrderNumber		    
			,JobOrderName		    
			,JobOrderStartDate	    
			,JobOrderTargetEndDate   
			,JobOrderEndDate			
			,manufactName		    
			,FactoryNumber		    
			,BOMName
			,MatGuid
			,GroupGuid
			,ProductionUnit
			,ProuductionLineName
			,ProuductionLineGuid
			,ActualProductionQty
			-------------------------------------------------------
	UPDATE Result SET QuantamDeviation = (CASE WHEN abs(Result.ConsumedQty- Result.StandardQty) > 10.e-9  Then Result.ConsumedQty- Result.StandardQty ELSE 0 END)
					  ,QuantamDeviationInUnit = (CASE WHEN abs(Result.ConsumedQty- Result.StandardQty) > 10.e-9  Then Result.ConsumedQty- Result.StandardQty ELSE 0 END) / Result.ActualProductionQty
					  ,DeviationRatio = ((CASE WHEN abs(Result.ConsumedQty- Result.StandardQty) > 10.e-9  Then Result.ConsumedQty- Result.StandardQty ELSE 0 END) / Result.StandardQty) * 100
					  ,Price=CASE WHEN Price = 0 THEN 0 ELSE(Result.Price / Result.ConsumedQty) END
					  FROM #Result Result

	UPDATE Result SET StandardValue = Result.StandardQty * Result.Price
					  ,ConsumedValue = Result.ConsumedQty * Result.Price
					  ,DeviationValue = Result.QuantamDeviation * Result.Price
					  ,DeviationValueInUnit = (Result.QuantamDeviation * Result.Price) / Result.ActualProductionQty
					  FROM #Result Result

	UPDATE Result SET StandardValueByProductionUnit = Result.StandardValue / Result.ActualProductionQty
					  ,ConsumedValueByProductionUnit = Result.ConsumedValue / Result.ActualProductionQty
					  ,PercentageDeviationValue = (Result.DeviationValue / Result.StandardValue)
					  ,StandardQtyByProductionUnit = Result.StandardQty / Result.ActualProductionQty
					  ,ConsumedQtyByProductionUnit = Result.ConsumedQty / Result.ActualProductionQty
					  FROM #Result Result
SELECT * FROM #Result
######################################################################
Create FUNCTION JOCfngetTotalStandardQty(@MaterialGuid UNIQUEIDENTIFIER, @JobOrderGuid UNIQUEIDENTIFIER,  @StageGuid UNIQUEIDENTIFIER)
RETURNS FLOAT
AS 
	BEGIN
		RETURN
			(
				SELECT SUM(StandardQuantity) 
				FROM  JOCfngetStandardQty(@MaterialGuid, @JobOrderGuid, @StageGuid)
			)
END
######################################################################
CREATE FUNCTION JOCfnGetJobOrderSumTotalProductsQtys(@JobOrderGuid UNIQUEIDENTIFIER, @ProductionUnit INT)
RETURNS FLOAT
AS
BEGIN
		RETURN
			(
				SELECT SUM(Qty) 
				FROM  JOCfnGetJobOrderTotalProductsQtys(@JobOrderGuid, @ProductionUnit)
			)
END
######################################################################
#END
