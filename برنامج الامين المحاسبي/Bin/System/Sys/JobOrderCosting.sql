######################################################
CREATE VIEW vwReadyMaterials
      AS  
            SELECT 
                  Mt.Guid
                  ,Mt.Code
                  ,Mt.Name
                  ,Mt.LatinName
            FROM Mn000 Mn
            INNER JOIN Mi000 Mi ON Mi.ParentGuid = Mn.Guid
            INNER JOIN Mt000 Mt ON Mt.Guid = Mi.MatGuid
            WHERE Mn.Type = 0 AND Mi.Type = 0
######################################################
CREATE VIEW VwJocBomProductionLinesWithUnit
AS
SELECT BomLine.*, ManufactoryGuid ,
CASE WHEN BomLine.ProductionCapacityUnit=1 THEN Mt.Unity 
WHEN BomLine.ProductionCapacityUnit=2 THEN Mt.Unit2
WHEN BomLine.ProductionCapacityUnit=3 THEN Mt.Unit3 
WHEN BomLine.ProductionCapacityUnit=4 THEN Unt1.Name 
WHEN BomLine.ProductionCapacityUnit=5 THEN Unt2.Name 
ELSE '' END AS UnitName
FROM JOCBOMProductionLines000 AS BomLine
LEFT JOIN JOCBOM000 AS Bom ON BomLine.JOCBOMGuid=Bom.GUID
LEFT JOIN mt000 AS Mt ON Bom.MatPtr=Mt.GUID
LEFT JOIN 	ProductionLine000 AS Prd
ON Prd.Guid =BomLine.ProductionLineGuid
LEFT JOIN Manufactory000 AS Man
ON Man.Guid =Prd.ManufactoryGUID
LEFT JOIN JOCProductionUnit000  AS Unt1
ON Man.ProductionUnitOne=Unt1.GUID
LEFT JOIN JOCProductionUnit000  AS Unt2
ON Man.ProductionUnitTwo=Unt2.GUID
######################################################
CREATE VIEW vwRawMaterials
      AS  
            SELECT DISTINCT
				Mt.Guid
               ,Mt.Code
               ,Mt.Name
               ,Mt.LatinName
               FROM  
				Mi000 Mi INNER JOIN Mt000 Mt ON Mt.Guid = Mi.MatGuid
				WHERE Mi.Type <> 0  

######################################################
CREATE PROCEDURE JOCPrcGetProductionCapacityUnit 
	  @ProductionLineGuid AS [UNIQUEIDENTIFIER]
AS
SET NOCOUNT ON 

	SELECT  Units.Name AS UnitName, Units.GUID Unit FROM Manufactory000 Manufactory 
	INNER JOIN ProductionLine000 ProductionLine ON Manufactory.Guid = ProductionLine.ManufactoryGUID
	INNER JOIN JOCProductionUnit000 Units ON Manufactory.ProductionUnitOne = Units.GUID OR Manufactory.ProductionUnitTwo = Units.GUID
	WHERE ProductionLine.Guid = @ProductionLineGuid
	ORDER BY Manufactory.ProductionUnitOne
######################################################
CREATE PROCEDURE GetProductionLineManufactoryName 
 @ProductionLineGuid UNIQUEIDENTIFIER
AS
SET NOCOUNT ON
select Name from Manufactory000 
	where [Guid] IN (Select ManufactoryGUID from ProductionLine000 where [Guid] = @ProductionLineGuid)
######################################################
CREATE VIEW vwJobOrderDistributedCosts
	AS  
		SELECT 
			DLA.JobOrder
			,DLA.Date
			,DLA.Entry
			, SUM( DLD.WorkingHours * DLD.WorkingHourCost ) TotalCosts
		FROM DirectLaborAllocation000 DLA
		INNER JOIN DirectLaborAllocationDetail000 DLD ON DLA.Guid = DLD.JobOrderDistributedCost		GROUP BY DLA.JobOrder
				,DLA.Date
				,DLA.Entry
######################################################
CREATE PROCEDURE GetProductionLineBOMsInfo
	@ProductionLine UNIQUEIDENTIFIER
AS
	SET NOCOUNT ON
CREATE TABLE  #RESULT  
	(
		BOMGuid UNIQUEIDENTIFIER,
		BOMName	NVARCHAR(250),
		ProductionLineCapacity FLOAT ,
		ProductionLineCapacityUnit INT,
		ProductionLineCapacityUnitName NVARCHAR(250)
	) 
	
INSERT INTO #RESULT 
	SELECT JOCBOMGuid, Name,ProductionCapacity,1,UnitName
		 FROM 
			 VwJocBomProductionLinesWithUnit AS BOMPRD 
			 INNER JOIN 
			 JOCBOM000 AS BOM 
		 ON BOM.GUID=BOMPRD.JOCBOMGuid
	WHERE BOMPRD.ProductionLineGuid=@ProductionLine
	ORDER BY(BOM.Number)
	
SELECT * FROM #RESULT 
######################################################
CREATE VIEW JocVwProductionLineStagesItems
AS
	SELECT ST.Name AS Name, St.LatinName as LatinName, St.Code AS StageCode, PST.*
	  FROM
		JOCProductionLineStages000 AS PST
		INNER JOIN JOCStages000 AS ST
		ON ST.GUID=PST.StageGuid
######################################################
CREATE VIEW VwJOCWorkHoursDistribution
AS
SELECT WorkHours.* ,Stage.Name AS StageName FROM JOCWorkHoursDistribution000 AS WorkHours
INNER JOIN JOCStages000 AS Stage 
ON Stage.GUID= WorkHours.StageGuid
######################################################
CREATE VIEW vwJobOrderEmployeeDetails
	AS  
		SELECT DLA.JobOrder
			   ,DLD.Employee
			   ,Worker.Name
			   ,CASE WHEN BOMI.UseStages=1 THEN  SUM(DIS.Hours) ELSE SUM(DLD.WorkingHours) END WorkingHours
			   ,CASE WHEN BOMI.UseStages=1 THEN  SUM(DIS.Hours * DLD.WorkingHourCost)  ELSE SUM(DLD.WorkingHours * DLD.WorkingHourCost) END Total
			   ,DLD.WorkingHourCost WorkingHourCost
			   ,DIS.StageName As StageName
			   ,DIS.StageGuid As StagegUID
		FROM [DirectLaborAllocation000] DLA
		INNER JOIN [DirectLaborAllocationDetail000] DLD ON DLA.Guid = DLD.JobOrderDistributedCost
		LEFT JOIN [JOCWorkers000] Worker ON Worker.Guid = DLD.Employee
		LEFT JOIN [VwJOCWorkHoursDistribution] DIS ON DIS.ParentGuid=DLD.Guid
		LEFT JOIN [JobOrder000] AS JO ON JO.Guid=DLA.JobOrder
		LEFT JOIN [JOCJobOrderOperatingBOM000] AS BOMI ON BOMI.BOMGuid=JO.OperatingBOMGuid
		GROUP BY DLA.JobOrder
				,DLD.Employee
				,Worker.Name
				,DLD.WorkingHourCost
				,DIS.StageName
				,DIS.StageGuid 
				,BOMI.UseStages
######################################################				
CREATE PROCEDURE PrcGetJobOrderWorkingHoursDataInOnDay 
       @WorkerGuid AS [UNIQUEIDENTIFIER], @Date AS [DATETIME] ,@JobOrderGuid AS [UNIQUEIDENTIFIER]
AS
BEGIN
SET NOCOUNT ON 
            SELECT WorkingHours ,JO.Number AS JONUMBER
                  FROM DirectLaborAllocationDetail000 AS DLAD 
                  INNER JOIN DirectLaborAllocation000 AS DLA ON DLA.Guid = DLAD.JobOrderDistributedCost
                  INNER JOIN JobOrder000 AS JO ON JO.Guid=DLA.JobOrder
            WHERE DLAD.Employee = @WorkerGuid
                  AND DLA.Date = @Date
                  AND DLA.JobOrder <>@JobOrderGuid
END 
######################################################
CREATE PROCEDURE  RepJobOrderMaterialsInStoreWithUnitOne
		@Materials 				UNIQUEIDENTIFIER, 
		@Store					UNIQUEIDENTIFIER
AS 
SET NOCOUNT ON  

SELECT
	BiSt.biMatPtr AS MatGuid
	,SUM(BiSt.biQty * CASE BiSt.btBillType WHEN 0 THEN 1 WHEN 3 THEN 1 WHEN 4 THEN 1 ELSE -1 END ) Stock
FROM vwExtended_bi_st AS BiSt
	INNER JOIN [RepSrcs] AS [r] ON BiSt.biMatPtr = [r].[IdType]
WHERE BiSt.biStorePtr = @Store
	  AND [IdTbl] = @Materials
GROUP BY
	BiSt.biMatPtr	
######################################################				
CREATE  PROCEDURE  RepJobOrderDirectMaterials
		@JobOrder 					UNIQUEIDENTIFIER, 
		@CalcQtyNeededForJobOrder	INT = 0
AS    
    SET NOCOUNT ON      
    
DECLARE @FineshedGood					[UNIQUEIDENTIFIER]     
DECLARE @JobOrderAccount				[UNIQUEIDENTIFIER]     
DECLARE @JobOrderCostCenter				[UNIQUEIDENTIFIER]     
DECLARE @JobOrderBranch					[UNIQUEIDENTIFIER]     
DECLARE @JobOrderPlannedProductionQty	[FLOAT]    
DECLARE @FineshedGoodQty             	[FLOAT]    
  
SELECT   @FineshedGood					=	bom.MatPtr
		,@JobOrderAccount				=	Jo.Account   
		,@JobOrderCostCenter			=	Jo.CostCenter   
		,@JobOrderBranch				=	Jo.Branch   
		,@JobOrderPlannedProductionQty	=	Jo.PlannedProductionQty   
		,@FineshedGoodQty               =   bomIns.ProductionQuantity
FROM JobOrder000 Jo 
INNER JOIN JOCBOMInstance000 bomIns ON bomIns.JobOrderGuid = Jo.Guid
INNER JOIN JOCBOM000 bom ON bomIns.OriginalBOMGuid = bom.Guid
WHERE Jo.Guid = @JobOrder 

    DECLARE @OutBillType		[UNIQUEIDENTIFIER]     
    DECLARE @ReturnBillType		[UNIQUEIDENTIFIER]           
    DECLARE @OutTransBillType	[UNIQUEIDENTIFIER]     
    DECLARE @InTransBillType	[UNIQUEIDENTIFIER]   
	SELECT  @OutBillType = MatRequestBillType, @ReturnBillType = MatReturnBillType,
		@OutTransBillType = OutTransBillType, @InTransBillType = InTransBillType
			FROM Manufactory000 Mu INNER JOIN JobOrder000 Jo ON Mu.[Guid] = Jo.[ManufactoryGUID]
			WHERE Jo.[Guid] = @JobOrder
    CREATE TABLE #JobOrderMaterials (   
	    Material					UNIQUEIDENTIFIER  
	    ,MaterialCode				NVARCHAR (255) COLLATE ARABIC_CI_AI   
	    ,GroupCode	     			NVARCHAR (255) COLLATE ARABIC_CI_AI   
	    ,MaterialName				NVARCHAR (255) COLLATE ARABIC_CI_AI   
	    ,MaterialLatinName			NVARCHAR (255) COLLATE ARABIC_CI_AI   
	    ,RequisitionQty				FLOAT   
	    ,ReternedQty				FLOAT     
	    ,TransInQty 				FLOAT   
	    ,TransOutQty				FLOAT   
	    ,NetQty						FLOAT   
	    ,NetValue					FLOAT   
	    ,QuantityNeededForJobOrder	FLOAT   
		,ExpireFlag                 BIT
		,SNFlag						BIT
		,ForceInSN					BIT
		,ForceOutSN					BIT
    )   
    INSERT INTO #JobOrderMaterials   
	    SELECT	Mt.Guid   
			    ,Mt.Code 
			    ,gr.Code 
			    ,Mt.MatName   
			    ,Mt.MatLatinName  
			    ,SUM( Bi.Qty * CASE Bu.TypeGuid WHEN @OutBillType THEN 1 ELSE 0 END ) /dbo.JocFnGetMaterialFactorial (Mt.Guid , Bi.Unity)  
			    ,SUM( Bi.Qty * CASE Bu.TypeGuid WHEN @ReturnBillType THEN 1 ELSE 0 END )/dbo.JocFnGetMaterialFactorial (Mt.Guid , Bi.Unity)  
			    ,SUM( Bi.Qty * CASE Bu.TypeGuid WHEN @InTransBillType THEN 1 ELSE 0 END ) /dbo.JocFnGetMaterialFactorial (Mt.Guid , Bi.Unity)   
			    ,SUM( Bi.Qty * CASE Bu.TypeGuid WHEN @OutTransBillType THEN 1 ELSE 0 END ) /dbo.JocFnGetMaterialFactorial (Mt.Guid , Bi.Unity)  
			    ,0   
			    ,SUM( Bi.Qty * Bi.Price * CASE Bu.TypeGuid WHEN @OutBillType THEN 1 WHEN @OutTransBillType THEN 1 ELSE 0 END )  
				- SUM( Bi.Qty * Bi.Price * CASE Bu.TypeGuid WHEN @ReturnBillType THEN 1 WHEN @InTransBillType THEN 1 ELSE 0 END )   
			    ,0   
				,Mt.ExpireFlag
				,Mt.SNFlag
				,Mt.ForceInSN
				,Mt.ForceOutSN  
	    FROM Bi000 Bi    
		    INNER JOIN Bu000 Bu ON Bu.Guid = Bi.ParentGuid   
		    INNER JOIN JocVwMaterialsWithAlternatives Mt ON Bi.MatGuid = Mt.Guid  
		    INNER JOIN gr000 gr ON gr.Guid = mt.GroupGuid  
	    WHERE Bu.CustAccGuid	= @JobOrderAccount   
		    AND Bu.CostGuid		= @JobOrderCostCenter   
		    AND Bu.Branch		= @JobOrderBranch   
		    AND Bu.TypeGuid IN (@OutBillType, @ReturnBillType, @InTransBillType, @OutTransBillType)    	   
	    GROUP BY Mt.Guid   
			    ,Mt.Code 
			    ,gr.Code 
			    ,Mt.MatName   
			    ,Mt.MatLatinName 
				,Mt.ExpireFlag 
				,Mt.SNFlag
				,Mt.ForceInSN
				,Mt.ForceOutSN
				, Bi.Unity
    
    UPDATE #JobOrderMaterials  
    SET NetQty = RequisitionQty + TransOutQty - (ReternedQty + TransInQty)   
    
    IF (@CalcQtyNeededForJobOrder = 1)   
    BEGIN      	  
	    INSERT INTO #JobOrderMaterials   
		    SELECT   
				    Mt.Guid   
				    ,Mt.Code 
			        ,gr.Code 
				    ,Mt.MatName   
				    ,Mt.MatLatinName   
				    ,0   
				    ,0   
				    ,0   
				    ,0   
				    ,0   
				    ,0   
				    ,0   
					,Mt.ExpireFlag  
					,Mt.SNFlag
					,Mt.ForceInSN
					,Mt.ForceOutSN
		    FROM JOCBOMRawMaterials000 rawMats  
		         INNER JOIN JocVwMaterialsWithAlternatives Mt ON rawMats.MatPtr = Mt.Guid  
		         INNER JOIN gr000 gr ON gr.Guid = mt.GroupGuid  
				 INNER JOIN JOCBOMInstance000 bomIns ON bomIns.GUID = rawMats.JOCBOMGuid and bomIns.JobOrderGuid = @JobOrder 
		    WHERE Mt.[Guid] NOT IN (SELECT Material FROM #JobOrderMaterials)   
			    AND ParentGuid = @JobOrder   
			    AND	MT.Type = 1 

		    UPDATE #JobOrderMaterials   
			SET QuantityNeededForJobOrder = (ISNULL(rawMats.RawMatQuantity,0) * @JobOrderPlannedProductionQty) / @FineshedGoodQty 
			,RequisitionQty=RequisitionQty/dbo.JocFnGetMaterialFactorial (Material, rawMats.Unit)
			,ReternedQty = ReternedQty / dbo.JocFnGetMaterialFactorial (Material, rawMats.Unit) 
			,TransInQty = TransInQty / dbo.JocFnGetMaterialFactorial (Material, rawMats.Unit)
			,TransOutQty = TransOutQty / dbo.JocFnGetMaterialFactorial (Material, rawMats.Unit)
			,NetQty = RequisitionQty + TransOutQty - (ReternedQty + TransInQty)
		    FROM #JobOrderMaterials JOCMat   
			LEFT JOIN ( JOCBOMRawMaterials000 rawMats  
		    Inner JOIN JOCBOMInstance000 bomIns ON bomIns.GUID = rawMats.JOCBOMGuid  AND bomIns.JobOrderGuid = @JobOrder)  ON rawMats.MatPtr = JOCMat.Material  			   
    END   
     
    SELECT @JobOrder JobOrder
    ,FormMat.RMUNIT AS MaterialUnit,CASE WHEN FormMat.RMUNIT=1 THEN Mt.Unity WHEN FormMat.RMUNIT=2 THEN Unit2 WHEN FormMat.RMUNIT=3 THEN Unit3 ELSE '' END AS  MaterialUintName
    ,JOM.* , CASE ISNULL(JOM.Material,0x0) WHEN 0x0 THEN 0 ELSE 1 END InForm
    FROM #JobOrderMaterials JOM 
	 LEFT JOIN
        (
	        SELECT rawMats.MatPtr, rawMats.GridIndex,rawMats.Unit AS RMUNIT
	        FROM JOCBOMRawMaterials000 rawMats
			inner join JOCBOMInstance000 bomI on rawMats.JOCBOMGuid =bomI.GUID and bomI.JobOrderGuid = @JobOrder
        )FormMat ON JOM.Material = FormMat.MatPtr
        INNER JOIN mt000 AS Mt ON Mt.GUID=FormMat.MatPtr
    ORDER BY FormMat.GridIndex
######################################################
CREATE PROCEDURE  RepEmployeesDistributionInJobOrders
		@JobOrder 				UNIQUEIDENTIFIER, 
		@ProductionLine			UNIQUEIDENTIFIER,
		@Employee				UNIQUEIDENTIFIER,
		@FromDate				DATETIME,
		@ToDate					DATETIME,
		@Manufactory			UNIQUEIDENTIFIER,
		@BOM					UNIQUEIDENTIFIER,
		@ShowDetailesStages		BIT
AS 
SET NOCOUNT ON

SELECT
	JO.Guid JobOrder
	,JO.Number
	,JO.Name JobOrderName
	,Worker.GUID WorkerGuid
	,Worker.Name EmployeeName
	,Worker.LatinName EmployeeLatinName
	,DLAD.Employee
	,DLAD.WorkingHourCost
	,CASE @ShowDetailesStages WHEN 1 THEN LaborInfo.TotalWorkingHours ELSE DLAD.WorkingHours END WorkingHours
	,DLAD.WorkingHourCost * (CASE @ShowDetailesStages WHEN 1 THEN LaborInfo.TotalWorkingHours ELSE DLAD.WorkingHours end) AS TotalWorkingHourCost
	,DLA.Date
	,factory.Name ManufactoryName
	,ProductionLine.Name ProductionLineName
	,ProductionLine.Guid ProductionLineGuid
	,BOM.Name BOMName
	,Ce.Number CeNumber
	,Ce.GUID EntryGuid
	,Stages.Name StageName
	,Stages.GUID StageGuid
	,factory.InsertNumber AS FactoryNumber
FROM JobOrder000 JO
	INNER JOIN DirectLaborAllocation000 DLA ON JO.Guid = DLA.JobOrder
	INNER JOIN DirectLaborAllocationDetail000 DLAD ON DLA.Guid = DLAD.JobOrderDistributedCost
	LEFT JOIN JOCWorkers000 Worker ON Worker.Guid = DLAD.Employee
	INNER JOIN Manufactory000 factory ON factory.Guid = JO.ManufactoryGUID
	INNER JOIN ProductionLine000 ProductionLine ON ProductionLine.Guid = JO.ProductionLine
	INNER JOIN JOCJobOrderOperatingBOM000 JobBom ON JobBom.Guid = JO.OperatingBOMGuid
	INNER JOIN JOCBOM000 BOM ON Bom.GUID = JobBom.BOMGuid
	INNER JOIN ce000 Ce ON ce.GUID = DLA.Entry
	LEFT JOIN JOCvwDiectLaborsCostDistribution LaborInfo ON @ShowDetailesStages = 1 AND LaborInfo.WorkerGuid = Worker.GUID  and LaborInfo.JobOrder =jo.Guid
	LEFT JOIN JOCStages000 Stages ON @ShowDetailesStages = 1 AND Stages.GUID = LaborInfo.StageGuid 
WHERE
		( ISNULL(@JobOrder, 0x0) = 0x0 OR JO.Guid = @JobOrder  )
	AND ( ISNULL(@ProductionLine, 0x0) = 0x0 OR JO.ProductionLine = @ProductionLine  )
	AND ( ISNULL(@Employee, 0x0) = 0x0 OR DLAD.Employee = @Employee  )
	AND ( ISNULL(@Manufactory, 0x0) = 0x0 OR JO.ManufactoryGUID = @Manufactory  )
	AND ( ISNULL(@BOM, 0x0) = 0x0 OR JobBom.BOMGuid = @BOM  )
	AND ( DLA.Date BETWEEN @FromDate AND @ToDate )
######################################################
CREATE PROCEDURE  RepJobOrderMaterialsInStore
		@Materials 				UNIQUEIDENTIFIER, 
		@Store					UNIQUEIDENTIFIER
AS 
SET NOCOUNT ON  

SELECT
	MatGuid
	,SUM(Qty * CASE Bt.BillType WHEN 0 THEN 1 WHEN 3 THEN 1 WHEN 4 THEN 1 ELSE -1 END ) Stock
FROM Bi000 Bi
	INNER JOIN Bu000 Bu on Bu.Guid = Bi.ParentGuid
	INNER JOIN Bt000 Bt ON Bt.Guid = Bu.TypeGuid
	INNER JOIN [RepSrcs] AS [r] ON Bi.MatGuid = [r].[IdType]
WHERE Bi.StoreGuid = @Store
	  AND [IdTbl] = @Materials
GROUP BY
	MatGuid	
######################################################
CREATE PROCEDURE  RepJobOrderMaterialsRequestionDetails 
		@JobOrder 					UNIQUEIDENTIFIER = 0x0 
AS 
    SET NOCOUNT ON 
    
    DECLARE @FineshedGood					[UNIQUEIDENTIFIER]    
DECLARE @JobOrderAccount				[UNIQUEIDENTIFIER]    
DECLARE @JobOrderCostCenter				[UNIQUEIDENTIFIER]    
DECLARE @JobOrderBranch					[UNIQUEIDENTIFIER]    
DECLARE @JobOrderPlannedProductionQty	[FLOAT]    
SELECT  @FineshedGood					=	bom.MatPtr
		,@JobOrderAccount				=	Jo.Account  
		,@JobOrderCostCenter			=	Jo.CostCenter  
		,@JobOrderBranch				=	Jo.Branch  
		,@JobOrderPlannedProductionQty	=	Jo.PlannedProductionQty  
FROM JobOrder000 Jo
INNER JOIN JOCBOM000 bom ON jo.FormGuid = bom.Guid
WHERE Jo.Guid = @JobOrder
        
    DECLARE @OutBillType		[UNIQUEIDENTIFIER]    
    DECLARE @ReturnBillType		[UNIQUEIDENTIFIER]          
    DECLARE @OutTransBillType	[UNIQUEIDENTIFIER]    
    DECLARE @InTransBillType	[UNIQUEIDENTIFIER]  
     
  SELECT  @OutBillType = MatRequestBillType, @ReturnBillType = MatReturnBillType,
		  @OutTransBillType = OutTransBillType, @InTransBillType = InTransBillType
		  FROM Manufactory000 Mu INNER JOIN JobOrder000 Jo ON Mu.[Guid] = Jo.[ManufactoryGUID]
		  WHERE Jo.[Guid] = @JobOrder
    
    CREATE TABLE #JobOrderMaterials ( 
	    MaterialId				UNIQUEIDENTIFIER  
	    ,MaterialCode			NVARCHAR (255) COLLATE ARABIC_CI_AI  
	    ,GroupCode	     		NVARCHAR (255) COLLATE ARABIC_CI_AI  
	    ,MaterialName			NVARCHAR (255) COLLATE ARABIC_CI_AI 
	    ,MaterialLatinName		NVARCHAR (255)
		,MaterialUnit			INT
		,MaterialUnitName		NVARCHAR(255)
		,ExpensedQty			FLOAT
	    ,NetExchange			FLOAT 
		,ExpireFlag             BIT
		,SNFlag					BIT
		,ForceInSN				BIT
		,ForceOutSN				BIT
    ) 
    
    INSERT INTO #JobOrderMaterials 
	    SELECT	Mt.Guid 
			    ,Mt.Code
			    ,gr.Code
			    ,Mt.MatName 
			    ,Mt.MatLatinName 
				,Bi.Unity
				,CASE WHEN Bi.Unity = 1 THEN Mt.Unity WHEN Bi.Unity = 2 THEN Mt.Unit2 WHEN Bi.Unity = 3 THEN Mt.Unit3 ELSE '' END
				,SUM(Bi.Qty * CASE Bu.TypeGuid WHEN @OutBillType THEN 1 WHEN @OutTransBillType THEN 1 ELSE 0 END)/dbo.JocFnGetMaterialFactorial (Mt.Guid , Bi.Unity) /dbo.JocFnGetMaterialFactorial (Mt.Guid , Bi.Unity) AS ExpensedQty
			    ,SUM(Bi.Qty * CASE Bu.TypeGuid WHEN @OutBillType THEN 1 WHEN @OutTransBillType THEN 1 WHEN @ReturnBillType THEN -1 WHEN @InTransBillType THEN -1 ELSE 0 END) /dbo.JocFnGetMaterialFactorial (Mt.Guid , Bi.Unity) AS NetExchange
	            ,Mt.ExpireFlag  
				,Mt.SNFlag
				,Mt.ForceInSN
				,Mt.ForceOutSN
	    FROM Bi000 Bi  
		    INNER JOIN Bu000 Bu ON Bu.Guid = Bi.ParentGuid 
		    INNER JOIN JocVwMaterialsWithAlternatives Mt ON Bi.MatGuid = Mt.Guid 
		    INNER JOIN St000 St ON St.Guid = Bi.StoreGuid 
		    INNER JOIN gr000 gr ON gr.Guid = mt.GroupGuid 
	    WHERE Bu.CustAccGuid	= @JobOrderAccount 
		    AND Bu.CostGuid		= @JobOrderCostCenter 
		    AND Bu.Branch		= @JobOrderBranch 
		    AND Bu.TypeGuid IN (@OutBillType, @ReturnBillType, @OutTransBillType, @InTransBillType) 
	    GROUP BY Mt.Guid 
			    ,Mt.Code
			    ,gr.Code
			    ,Mt.MatName 
			    ,Mt.MatLatinName    
				,Mt.ExpireFlag   
				,Mt.SNFlag
				,Mt.ForceInSN
				,Mt.ForceOutSN
				,Bi.Unity
				,Mt.Unity
				,Mt.Unit2
				,Mt.Unit3

    SELECT JOM.* 
    FROM 
        #JobOrderMaterials JOM  
        LEFT JOIN
        (
	        SELECT rawMats.MatPtr, rawMats.GridIndex,rawMats.Unit AS rawMaterialUnit
	        FROM JOCBOMRawMaterials000 rawMats
			INNER JOIN JOCBOMInstance000 bomI ON rawMats.JOCBOMGuid = bomI.[GUID] and bomI.JobOrderGuid = @JobOrder
        )	FormMat ON JOM.MaterialId = FormMat.MatPtr
        INNER JOIN mt000 AS Mt ON Mt.GUID=FormMat.MatPtr
    ORDER BY FormMat.GridIndex
######################################################
CREATE FUNCTION fnGetEmployeeWorkingHoursInJobOrderOnDay 
      ( @WorkerGuid AS [UNIQUEIDENTIFIER], @Date AS [DATETIME]) 
      RETURNS TABLE 
      AS 
            RETURN (
            SELECT SUM(WorkingHours) WorkingHours
                  FROM DirectLaborAllocationDetail000 AS DLAD 
                  INNER JOIN DirectLaborAllocation000 AS DLA ON DLA.Guid = DLAD.JobOrderDistributedCost
            WHERE DLAD.Employee = @WorkerGuid
                  AND DLA.Date = @Date
            GROUP BY DLAD.Employee, DLA.Date
            ) 
######################################################
CREATE FUNCTION FnGetFormProductionLines
(
    @Form UNIQUEIDENTIFIER
)  
RETURNS TABLE 
AS 
RETURN 
( 
	SELECT DISTINCT pl.* 
	FROM ProductionLine000 pl 
	INNER JOIN ProductionLineGroup000 plg on pl.Guid = plg.ProductionLine 
	INNER JOIN Mi000 Mi ON Mi.MatGuid IN (SELECT MtGuid FROM [dbo].[fnGetMatsOfGroups](plg.GroupGuid))
	INNER JOIN Mn000 Mn ON Mn.Guid = Mi.ParentGuid
	WHERE  
		(Mn.FormGuid = @Form OR ISNULL(@Form, 0x0) = 0x0)
		AND Mn.Type = 0
		AND Mi.Type = 0
) 
######################################################
CREATE FUNCTION FnGetProductionLineForms
( 
    @ProductionLine UNIQUEIDENTIFIER 
)   
RETURNS TABLE  
AS  
RETURN  
(  
	SELECT DISTINCT Fm.*  
	FROM ProductionLine000 pl  
	INNER JOIN ProductionLineGroup000 plg on pl.Guid = plg.ProductionLine  
	INNER JOIN Mi000 Mi ON Mi.MatGuid IN (SELECT MtGuid FROM [dbo].[fnGetMatsOfGroups](plg.GroupGuid)) 
	INNER JOIN Mn000 Mn ON Mn.Guid = Mi.ParentGuid 
	INNER JOIN Fm000 Fm ON Fm.Guid = Mn.FormGuid 
	WHERE   
		(ISNULL(@ProductionLine, 0x0) = 0x0 OR Pl.Guid = @ProductionLine)
		AND Mn.Type = 0 
		AND Mi.Type = 0 
)  
######################################################
Create FUNCTION FnGetProductionLineBOMs
( 
    @ProductionLine UNIQUEIDENTIFIER 
)   
RETURNS TABLE  
AS  
RETURN  
(  
	SELECT DISTINCT BOM.*  
	FROM JOCBOM000 AS BOM 
	INNER JOIN JOCBOMProductionLines000 AS BOMLine
	ON BOM.Guid = BOMLine.JOCBOMGuid   
	
	WHERE   
	@ProductionLine=CASE WHEN  ISNULL (@ProductionLine,0x0)=0x0  THEN 0x0 ELSE BOMLine.ProductionLineGuid END
)
######################################################
Create FUNCTION FnGetFactoryBOMs
( 
    @Factory UNIQUEIDENTIFIER 
)   
RETURNS TABLE  
AS  
RETURN  
(  
	SELECT DISTINCT BOM.*  
	FROM JOCBOM000 AS BOM 
	INNER JOIN JOCBOMProductionLines000 AS BOMLine
	INNER JOIN ProductionLine000 pl on BOMLine.ProductionLineGuid = pl.Guid
	ON BOM.Guid = BOMLine.JOCBOMGuid   
	
	WHERE   
	@Factory = CASE WHEN  ISNULL (@Factory,0x0)=0x0  THEN 0x0 ELSE pl.ManufactoryGUID END
)
######################################################
CREATE PROCEDURE prcGetSharedRawMaterials
(
    @src UNIQUEIDENTIFIER, 
    @dest UNIQUEIDENTIFIER
)
AS
    SET NOCOUNT ON
    
    CREATE TABLE #SrcMaterials ( 
	    MaterialId				UNIQUEIDENTIFIER  
	    ,MaterialCode			NVARCHAR (255) COLLATE ARABIC_CI_AI  
	    ,GroupCode	     		NVARCHAR (255) COLLATE ARABIC_CI_AI  
	    ,MaterialName			NVARCHAR (255) COLLATE ARABIC_CI_AI 
	    ,MaterialLatinName		NVARCHAR (255) COLLATE ARABIC_CI_AI 
		,MaterialUnit			INT
		,MaterialUnitName		NVARCHAR(250)
		,ExpensedQty			FLOAT
	    ,NetExchange			FLOAT 
		,ExpireFlag             BIT
		,SNFlag					BIT
		,ForceInSN				BIT
		,ForceOutSN				BIT
    )
    
    INSERT INTO #SrcMaterials EXEC RepJobOrderMaterialsRequestionDetails @src
    
    SELECT 
        src.MatPtr MatGuid,
        dest.MatCode,
        dest.MatName,
        dest.MatLatinName,
        src.SrcJobQty,
        dest.GroupCode,
		src.ExpireFlag ExpireFlag,
		src.SNFlag,
		src.ForceInSN,
		src.ForceOutSN
    FROM
        (
            SELECT rawMats.MatPtr,  ISNULL(s.NetExchange, 0) SrcJobQty ,mt.ExpireFlag  ExpireFlag,rawMats.GridIndex GridIndex
			,mt.SNFlag AS SNFlag , mt.ForceInSN AS ForceInSN  ,mt.ForceOutSN AS ForceOutSN
            FROM  JOCBOMRawMaterials000 rawMats  
		    inner JOIN JOCBOMInstance000 bomIns ON bomIns.GUID = rawMats.JOCBOMGuid  AND bomIns.JobOrderGuid = @src
			INNER JOIN mt000 mt ON rawMats.MatPtr = mt.[GUID]
			LEFT JOIN #SrcMaterials s ON rawMats.MatPtr = s.MaterialId 
        ) src
        INNER JOIN
        (
            SELECT rawMats.MatPtr, mt.Code MatCode, mt.MatName MatName, mt.MatLatinName MatLatinName, Gr.Code GroupCode
            FROM  JOCBOMRawMaterials000 rawMats  
		    INNER JOIN JOCBOMInstance000 bomIns ON bomIns.GUID = rawMats.JOCBOMGuid  AND bomIns.JobOrderGuid = @dest
			INNER JOIN JocVwMaterialsWithAlternatives mt ON mt.Guid = rawMats.MatPtr
			INNER JOIN Gr000 Gr ON Gr.Guid = Mt.GroupGuid
        ) dest
        ON
        src.MatPtr = dest.MatPtr order by src.GridIndex 
######################################################
CREATE PROCEDURE prcIsJobOrderTransBill(@BillGuid UNIQUEIDENTIFIER)
AS
    SET NOCOUNT ON
    
    IF (EXISTS(
            SELECT InBill
            FROM JocTrans000
            WHERE InBill = @BillGuid            
            UNION            
            SELECT OutBill
            FROM JocTrans000
            WHERE OutBill = @BillGuid
            )
     )
        SELECT 1 AS IsTransferBill
     ELSE
        SELECT 0 AS IsTransferBill
######################################################
CREATE PROC prcJobOrderIndirectExpenseBudget
	@FromPeriod			[UNIQUEIDENTIFIER] = 0x0,
	@ToPeriod			[UNIQUEIDENTIFIER] = 0x0,
	@DetailedAccs		[INT] = 1,
	@DetailedMats		[INT] = 1,
	@ShowEmtpyAccounts	[INT] = 1,
	@ShowEmptyMaterials	[INT] = 1,
	@cost [INT] = 0,
	@Save				[INT] = 0
AS  
	SET NOCOUNT ON  
	  
	Declare @S Date,@E Date;
	DECLARE @IsAnnual	[INT] 
	SET @S = [dbo].[fnDate_Amn2Sql]([dbo].[fnOption_get]('AmnCfg_FPDate', DEFAULT)) 
	SET @E = [dbo].[fnDate_Amn2Sql]([dbo].[fnOption_get]('AmnCfg_EPDate', DEFAULT))
	SELECT @IsAnnual = CAST([VALUE] AS INT) FROM op000 WHERE [NAME] ='AmnCfg_JobOrdersWorkAnnualy' 

	IF(IsNull(@IsAnnual,-1 ) = -1)
		return

	CREATE TABLE #Periods
	(prGuid [UNIQUEIDENTIFIER],
	 PrName  NVARCHAR(MAX),
	 prStartDate DATETIME,
	 PrEndDate DATETIME
	 )

		DECLARE @FromDate	DATETIME  
			DECLARE @ToDate		DATETIME  

			IF(ISNULL(@FromPeriod, 0x0) <> 0x0)  
				SELECT @FromDate = StartDate FROM Bdp000 WHERE Guid = @FromPeriod  
			ELSE  
				SET @FromDate = '1-1-1980'  
		  
			IF(ISNULL(@ToPeriod, 0x0) <> 0x0)  
				SELECT @ToDate = EndDate FROM Bdp000 WHERE Guid = @ToPeriod  
			ELSE  
				SET @ToDate = '1-1-2050'  


	IF  @IsAnnual = 0
	BEGIN
		
	  
		INSERT INTO #Periods 
			SELECT  
					Guid		PrGuid  
					,Name		PrName  
					,StartDate	PrStartDate  
					,EndDate	PrEndDate  
	 
			FROM Bdp000  
			WHERE  (StartDate BETWEEN @FromDate AND @ToDate)  
				AND Guid NOT IN (SELECT ParentGuid FROM Bdp000)  

				
	END
	ELSE
	BEGIN 
		
		INSERT INTO #Periods
		SELECT  
				newID()		PrGuid  
				,'prName'	PrName  
				,@S			PrStartDate  
				,@E			PrEndDate  	
	END  
	 
	SELECT   
		 Pl.Guid	PlGuid  
		,Pl.Name	PlName  
		,ISNULL(PrGuid, 0x0) PrGuid  
		,ISNULL(PrName, '') PrName  
		,Acc.Guid RowGuid  
		,Acc.Name RowName  
		,CAST(1 AS FLOAT) RowType  
		,SUM(  
			CASE @IsAnnual 
				WHEN 1 THEN ISNULL(AccountsBalances.Balance, 0)  
				ELSE   ISNULL(PeriodBalance.Balance, 0) 
			END  
		) EstCost  
		,( SELECT ISNULL(SUM(ISNULL(Debit - Credit, 0)), 0) FROM En000 
					WHERE AccountGuid = Acc.Guid AND  
						(  
								Date BETWEEN pl.PrStartDate AND pl.PrEndDate    
						)  
		) ActCost  
		,CAST(0.0 AS FLOAT) Diff  
		,CAST(0.0 AS FLOAT) Percentage  
		,CAST(0.0 AS FLOAT) Slope  
		,CAST(0.0 AS FLOAT) Init  
		,CAST(0.0 AS FLOAT) RSQ  
	INTO #Result  
	FROM 
		(SELECT * FROM #Periods p,ProductionLine000 Pl  ) as pl
	INNER JOIN  
	(  
		SELECT Guid, Name  
		FROM  Ac000  
		WHERE GUID NOT IN (SELECT ParentGuid FROM Ac000)  
			AND Guid NOT IN (SELECT DISTINCT ParentGuid FROM ci000)  
	)Acc ON Acc.Guid IN (SELECT Guid FROM dbo.fnGetAccountsList(Pl.ExpensesAccount, 0)) 
	
	LEFT JOIN  
	(  
		SELECT   
			Abd.PeriodGuid PeriodGuid 
			,Bdp.prName PeriodName 
			,Bdp.prStartDate PeriodStartDate 
			,Bdp.prEndDate PeriodEndDate 
			,Ab.AccGuid  
			,SUM(ISNULL(Abd.Debit, 0)) - SUM(ISNULL(Abd.Credit, 0)) Balance  
		FROM Ab000 Ab  
		INNER JOIN Abd000 Abd ON Ab.Guid = Abd.ParentGuid  
		INNER JOIN #Periods Bdp ON Bdp.prGuid = Abd.PeriodGuid  
		
		GROUP BY  
				Abd.PeriodGuid
				,Ab.AccGuid 
				,Bdp.prName
				,Bdp.prStartDate
				,Bdp.prEndDate
	)PeriodBalance ON PeriodBalance.AccGuid = Acc.Guid   AND pl.prGuid = PeriodBalance.PeriodGuid 
				
	LEFT JOIN  
	(  
		SELECT Guid AccountGuid  
			,MaxDebit * CASE Warn WHEN 2 THEN -1 ELSE 1 END Balance  
		FROM Ac000  
	)AccountsBalances ON AccountsBalances.AccountGuid = Acc.Guid--,
	where  
	((@IsAnnual = 0 AND( prGuid = PeriodBalance.PeriodGuid or PeriodBalance.PeriodGuid IS NULL)) OR @IsAnnual <> 0)
	GROUP BY
			 Pl.Guid  
			,Pl.Name  
			,Acc.Guid  
			,Acc.Name  
			,prGuid  
			,PrName  
			,PrStartDate  
			,PrEndDate  
	  


	INSERT INTO #Result  
	SELECT   
		PlGuid
		,PlName
		,PrGuid
		,PrName
		,0x0
		,''
		,1.5
		,SUM(EstCost)
		,SUM(ActCost)
		,CAST(0.0 AS FLOAT) Diff  
		,CAST(0.0 AS FLOAT) Percentage  
		,CAST(0.0 AS FLOAT) Slope  
		,CAST(0.0 AS FLOAT) Init  
		,CAST(0.0 AS FLOAT) RSQ 
	FROM #Result
	GROUP BY PlGuid, PlName, PrGuid, PrName



IF @IsAnnual = 1
	 INSERT INTO #Result 
			SELECT 
	 
				Pl.Guid  
				, Pl.Name  
				,ISNULL(PrGuid, 0x0)    
				,ISNULL(PrName, '')  
				,Mt.Guid  
				,Mt.Name  
				,2  
				,SUM( Jo.PlannedProductionQty * MaterialsConversionFactor.ConversionFactor) 
				,SUM(CASE  
					WHEN  
					 ISNULL(Jo.InBillGuid, 0x0) <> 0x0 
							
					THEN ISNULL(Bi.Qty, Jo.ActualProductionQty) 
					ELSE 0  
					END) * MaterialsConversionFactor.ConversionFactor 
				,0.0  
				,0.0  
				,0.0  
				,0.0  
				,0.0  
			FROM JobOrder000 Jo  
			INNER JOIN ProductionLine000 Pl ON Pl.Guid = Jo.ProductionLine  and Jo.EndDate BETWEEN @FromDate AND @E
			INNER JOIN Mi000 Mi ON Mi.ParentGuid = Jo.Guid AND Mi.Type = 0  
			INNER JOIN Mt000 Mt ON Mt.Guid = Mi.MatGuid 
			LEFT JOIN Bu000 Bu ON Bu.CustAccGuid = Jo.Account AND Bu.Notes LIKE '%' + Jo.Name + '%' AND Bu.Guid = Jo.InBillGuid 
			LEFT JOIN Bi000 Bi ON Bi.ParentGuid = Bu.Guid AND Mt.Guid = Bi.MatGuid
			INNER JOIN  
			(  
				SELECT Mt.Guid MatGuid, PLG.ProductionLine, PLG.ConversionFactor   
				FROM ProductionLineGroup000 PLG  
				INNER JOIN Mt000 Mt ON Mt.Guid IN (SELECT MtGuid FROM [dbo].[fnGetMatsOfGroups](PLG.GroupGuid))  
				GROUP BY Mt.Guid, PLG.ProductionLine, PLG.ConversionFactor   
			)MaterialsConversionFactor ON MaterialsConversionFactor.MatGuid = Mt.Guid AND MaterialsConversionFactor.ProductionLine = Pl.Guid 
			,#Periods p   
			GROUP BY Pl.Guid  
					,Pl.Name  
					,Mt.Guid  
					,Mt.Name  
					,p.prGuid  
					,prName  
					,MaterialsConversionFactor.ConversionFactor  
ELSE
	BEGIN
		;WITH Periods AS
		(
			SELECT 
				Bdp.Guid prguid, 
				Bdp.Name prname, 
				Jo.Guid JobOrderGuid,
				Bdp.StartDate,
				Bdp.EndDate,
				CASE WHEN jo.startdate between Bdp.startdate and Bdp.enddate THEN jo.PlannedProductionQty ELSE 0 END AS PlannedProductionQty,
				CASE WHEN jo.EndDate between Bdp.startdate and Bdp.enddate THEN jo.ActualProductionQty ELSE 0 END AS ActualProductionQty
			FROM Bdp000 Bdp  
			INNER JOIN JobOrder000 Jo ON (jo.startdate between Bdp.startdate and Bdp.enddate) OR (jo.EndDate between Bdp.startdate and Bdp.enddate)
			WHERE
				 Bdp.Guid IN (SELECT PrGuid FROM #Periods) 
			
				  
		)
		 INSERT INTO #Result 
			SELECT 
	 
				Pl.Guid  
				, Pl.Name  
				,ISNULL(p.PrGuid, 0x0)    
				,ISNULL(p.PrName, '')  
				,Mt.Guid  
				,Mt.Name  
				,2  
			 
			,Sum( ISNULL(p.PlannedProductionQty,0) * MaterialsConversionFactor.ConversionFactor)
			,SUM(CASE  
					WHEN ISNULL(Jo.InBillGuid, 0x0) <> 0x0 AND jo.endDate <= p.EndDate THEN
						ISNULL(Bi.Qty, p.ActualProductionQty)
					ELSE 0  
				END) * MaterialsConversionFactor.ConversionFactor 
				,0.0  
				,0.0  
				,0.0  
				,0.0  
				,0.0 
			FROM JobOrder000 Jo
			 
			INNER JOIN ProductionLine000 Pl ON Pl.Guid = Jo.ProductionLine
			INNER JOIN Mi000 Mi ON Mi.ParentGuid = Jo.Guid AND Mi.Type = 0  
			INNER JOIN Mt000 Mt ON Mt.Guid = Mi.MatGuid 
			LEFT JOIN Bu000 Bu ON Bu.CustAccGuid = Jo.Account AND Bu.Notes LIKE '%' + Jo.Name + '%' AND Bu.Guid = Jo.InBillGuid 
			LEFT JOIN Bi000 Bi ON Bi.ParentGuid = Bu.Guid AND Mt.Guid = Bi.MatGuid
			LEFT JOIN Periods P ON P.JobOrderGuid = Jo.Guid 
			INNER JOIN  
			(  
				SELECT Mt.Guid MatGuid, PLG.ProductionLine, PLG.ConversionFactor   
				FROM ProductionLineGroup000 PLG  
				INNER JOIN Mt000 Mt ON Mt.Guid IN (SELECT MtGuid FROM [dbo].[fnGetMatsOfGroups](PLG.GroupGuid))  
				GROUP BY Mt.Guid, PLG.ProductionLine, PLG.ConversionFactor   
			)MaterialsConversionFactor ON MaterialsConversionFactor.MatGuid = Mt.Guid AND MaterialsConversionFactor.ProductionLine = Pl.Guid 
			GROUP BY Pl.Guid  
					,Pl.Name  
					,Mt.Guid  
					,Mt.Name  
					,p.prGuid  
					,p.prname  
					,MaterialsConversionFactor.ConversionFactor  

	END	
	INSERT INTO #Result  
		SELECT   
				PlGuid  
				,PlName  
				,PrGuid  
				,PrName  
				,0x0  
				,''  
				,3  
				,Sum(EstCost)  
				,Sum(ActCost)  
				,0.0  
				,0.0  
				,0.0  
				,0.0  
				,0.0  
		FROM #Result  
		WHERE RowType = 2  
		GROUP BY PlGuid, PlName, PrGuid, PrName  
		  
	DECLARE @IndirectCostsAccount UNIQUEIDENTIFIER  
	SELECT @IndirectCostsAccount = CAST(Value AS UNIQUEIDENTIFIER) FROM Op000 WHERE Name = 'AmnCfg_JocIndirectCostsAccount'  
	  
	INSERT INTO #Result  
		SELECT   
			0x0  
			,'ÌÌÌÌÌÌÌÌ'  
			,ISNULL(PrGuid, 0x0) 
			,ISNULL(PrName, '') 
			,Ac.Guid  
			,Ac.Name  
			,4  
			,(  
				CASE @IsAnnual  
					WHEN 1 THEN (SELECT MaxDebit * CASE Warn WHEN 2 THEN -1 ELSE 1 END FROM Ac000 WHERE Guid = Ac.Guid)  
					ELSE ISNULL(PeriodBalance.Balance, 0)  
				END  
			)  
			,( SELECT ISNULL(SUM(ISNULL(Debit - Credit, 0)), 0) FROM En000 
					WHERE AccountGuid = Ac.Guid AND  
						(  
								Date BETWEEN PrStartDate AND PrEndDate    
						) 
			 ) 
			,0.0  
			,0.0  
			,0.0  
			,0.0  
			,0.0  
		FROM (select * from #Periods p,dbo.fnGetAccountsList(@IndirectCostsAccount, 0) Account  ) as Account
		INNER JOIN Ac000 Ac ON Ac.Guid = Account.Guid  
		LEFT JOIN En000 En ON Ac.Guid = En.AccountGuid AND En.Date BETWEEN @FromDate AND @ToDate 
		LEFT JOIN  
		(  
			SELECT    
				Abd.PeriodGuid PeriodGuid  
				,Bdp.prName PeriodName  
				,Ab.AccGuid   
				,SUM(ISNULL(Abd.Debit, 0)) - SUM(ISNULL(Abd.Credit, 0)) Balance   
			FROM Ab000 Ab   
			INNER JOIN Abd000 Abd ON Ab.Guid = Abd.ParentGuid   
			INNER JOIN #Periods Bdp ON Bdp.prGuid = Abd.PeriodGuid   
			
			GROUP BY   
					Abd.PeriodGuid
					,Ab.AccGuid  
					,Bdp.prName
					,Bdp.prStartDate
					,Bdp.prEndDate
				)PeriodBalance ON PeriodBalance.AccGuid = Ac.Guid and  prGuid = PeriodBalance.PeriodGuid 
				
		WHERE Account.Guid NOT IN ( SELECT ParentGuid FROM Ac000 ) 
		GROUP BY PrGuid  
				,PrName  
				,Ac.Guid  
				,Ac.Name  
				,PeriodBalance.Balance  
				,prStartDate
				,PrEndDate

	INSERT INTO #Result  
	SELECT   
		0x0  
		,'ÌÌÌÌÌÌÌÌ'  
		,PrGuid  
		,PrName  
		,0x0  
		,''  
		,5  
		,SUM(EstCost)  
		,SUM(ActCost)  
		,0.0  
		,0.0  
		,0.0  
		,0.0  
		,0.0  
	FROM #Result  
	WHERE RowType = 4  
	GROUP BY PrGuid  
			,PrName  
	  
	INSERT INTO #Result  
	SELECT   
		Res.PlGuid  
		,Res.PlName  
		,Res.PrGuid  
		,Res.PrName  
		,0x0  
		,''  
		,6  
		,ISNULL(Res1.EstCost * CASE ISNULL(MaterialsTotals.TotalEstCost, 0) WHEN 0 THEN 0 ELSE (Res.EstCost / MaterialsTotals.TotalEstCost) END, 0)    
		,ISNULL(Res1.ActCost * CASE ISNULL(MaterialsTotals.TotalActCost, 0) WHEN 0 THEN 0 ELSE (Res.ActCost / MaterialsTotals.TotalActCost) END, 0)   
		,0.0  
		,0.0  
		,0.0  
		,0.0  
		,0.0  
	FROM #Result Res  
	LEFT JOIN   
	(  
		SELECT PrGuid, EstCost, ActCost   
		FROM #Result   
		WHERE RowType = 5  
	)Res1 ON Res.PrGuid = Res1.PrGuid  
	LEFT JOIN   
	(  
		SELECT   
			PrGuid  
			,SUM(EstCost) TotalEstCost  
			,SUM(ActCost) TotalActCost  
		FROM #Result   
		WHERE RowType = 3   
		GROUP BY PrGuid  
	)MaterialsTotals ON MaterialsTotals.PrGuid = Res.PrGuid  
	WHERE Res.RowType = 3  
	GROUP BY Res.PlGuid  
			,Res.PlName  
			,Res.PrGuid  
			,Res.PrName  
			,Res.EstCost  
			,Res.ActCost  
			,Res1.EstCost  
			,Res1.ActCost  
			,MaterialsTotals.TotalEstCost  
			,MaterialsTotals.TotalActCost  
	  
	  
	INSERT INTO #Result  
	SELECT  
		PlGuid  
		,PlName  
		,PrGuid  
		,PrName  
		,0x0  
		,''  
		,7  
		,SUM(EstCost)  
		,SUM(ActCost)  
		,0.0  
		,0.0  
		,0.0  
		,0.0  
		,0.0	  
	FROM #Result  
	WHERE RowType = 1 OR RowType = 6  
	GROUP By PlGuid  
			,PlName  
			,PrGuid  
			,PrName  




	INSERT INTO #Result  
	SELECT   
		Res.PlGuid  
		,Res.PlName  
		,Res.PrGuid  
		,Res.PrName  
		,0x0  
		,''  
		,8  
		,CASE Res.EstCost WHEN 0 THEN 0 ELSE ProductionLineTotals.EstCost / Res.EstCost END  
		,CASE Res.ActCost WHEN 0 THEN 0 ELSE ProductionLineTotals.ActCost / Res.ActCost END  
		,0.0  
		,0.0  
		,0.0  
		,0.0  
		,0.0  
	FROM #Result Res  
	INNER JOIN   
	(  
		SELECT  
			PlGuid  
			,PrGuid  
			,SUM(EstCost) EstCost  
			,SUM(ActCost) ActCost  
		FROM #Result  
		WHERE RowType = 7  
		GROUP BY PlGuid  
				,PrGuid  
	)ProductionLineTotals ON ProductionLineTotals.PlGuid = Res.PlGuid AND ProductionLineTotals.PrGuid = Res.PrGuid  
	WHERE Res.RowType = 3  
	GROUP BY Res.PlGuid  
			,Res.PlName  
			,Res.PrGuid  
			,Res.PrName  
			,Res.EstCost  
			,Res.ActCost  
			,ProductionLineTotals.EstCost  
			,ProductionLineTotals.ActCost  
	  
	INSERT INTO #Result  
		SELECT  
			0x0  
			,'ÌÌÌÌÌÌÌÌ'  
			,PrGuid  
			,PrName  
			,0x0  
			,''  
			,9  
			,SUM(EstCost)  
			,SUM(ActCost)  
			,0  
			,0  
			,0  
			,0  
			,0  
	FROM #Result  
	WHERE RowType = 3  
	GROUP BY PrGuid, PrName  
	  

	  
	INSERT INTO #Result  
		SELECT  
			0x0  
			,'ÌÌÌÌÌÌÌÌ'  
			,PrGuid  
			,PrName  
			,0x0  
			,''  
			,10  
			,SUM(EstCost)  
			,SUM(ActCost)  
			,0  
			,0  
			,0  
			,0  
			,0  
	FROM #Result  
	WHERE RowType = 7  
	GROUP BY PrGuid, PrName  
	  
	INSERT INTO #Result  
		SELECT  
			0x0  
			,'ÌÌÌÌÌÌÌÌ'  
			,r.PrGuid  
			,r.PrName  
			,0x0  
			,''  
			,11  
			,SUM(CASE r2.EstCost WHEN 0 THEN 0 ELSE r.EstCost / r2.EstCost END)  
			,SUM(CASE r2.ActCost WHEN 0 THEN 0 ELSE r.ActCost / r2.ActCost END) 
			,0  
			,0  
			,0  
			,0  
			,0  
	FROM #Result r 
	INNER JOIN #Result r2 ON r.PrGuid = r2.PrGuid AND r.RowName = r2.RowName 
	WHERE r.RowType = 10 AND r2.RowType = 9 
	GROUP BY r.PrGuid, r.PrName 
	  
	IF(@DetailedAccs = 0)  
	BEGIN  
		INSERT INTO #Result  
		SELECT  
			PlGuid  
			,PlName  
			,PrGuid  
			,PrName  
			,Ac.Guid  
			,Ac.Code + '-' + Ac.Name  
			,12  
			,SUM(EstCost)  
			,SUM(ActCost)  
			,0.0  
			,0.0  
			,0.0  
			,0.0  
			,0.0  
		FROM #Result r   
		INNER JOIN ProductionLine000 Pl ON Pl.Guid = r.PlGuid  
		INNER JOIN Ac000 Ac ON Ac.Guid = Pl.ExpensesAccount  
		WHERE RowType = 1  
		GROUP BY PlGuid  
				,PlName  
				,PrGuid  
				,PrName  
				,Ac.Guid  
				,Ac.Code  
				,Ac.Name  
			  
		DELETE FROM #Result WHERE RowType = 1  
		UPDATE #Result SET RowType = 1 WHERE RowType = 12  
		  
		DECLARE @IndirectCostsAccountCodeName NVARCHAR(255)  
		SELECT @IndirectCostsAccountCodeName = Code + '-' + Name FROM Ac000 WHERE Guid = @IndirectCostsAccount  
		  
		INSERT INTO #Result  
		SELECT  
			0x0  
			,'ÌÌÌÌÌÌÌÌ'  
			,PrGuid  
			,PrName  
			,@IndirectCostsAccount  
			,@IndirectCostsAccountCodeName  
			,12  
			,SUM(EstCost)  
			,SUM(ActCost)  
			,0.0  
			,0.0  
			,0.0  
			,0.0  
			,0.0  
		FROM #Result r   
		WHERE RowType = 4  
		GROUP BY PrGuid  
				,PrName  
		  
		DELETE FROM #Result WHERE RowType = 4  
		UPDATE #Result SET RowType = 4 WHERE RowType = 12  
	END  
	
	/* HERE  */
	
	INSERT INTO #Result  
		SELECT  
			0x0  
			,'ÌÌÌÌÌÌÌÌ'  
			,r.PrGuid  
			,r.PrName  
			,0x0  
			,''  
			,12  
			,CASE r2.EstCost WHEN 0 THEN 0 ELSE r3.EstCost / r2.EstCost END
			,CASE r2.ActCost WHEN 0 THEN 0 ELSE r3.ActCost / r2.ActCost END
			,0  
			,0  
			,0  
			,0  
			,0  
	FROM #Result r 
	INNER JOIN #Result r2 ON r.PrGuid = r2.PrGuid AND r2.RowType = 9 -- „Ã„Ê⁄ «·≈‰ «Ã »«··Ì —
	INNER JOIN 
	(
		SELECT
		PrGuid
		,SUM(EstCost) EstCost
		,SUM(ActCost) ActCost
		FROM #Result
		WHERE RowType = 5
		GROUP BY PrGuid
	)
	r3 ON r.PrGuid = r3.PrGuid -- „Ã„Ê⁄ «·‰›ﬁ«  €Ì— «·„»«‘—…
	
	GROUP BY r.PrGuid, r.PrName, r2.EstCost, r2.ActCost, r3.EstCost, r3.ActCost
	  
	IF(@DetailedMats = 0)  
		DELETE FROM #Result WHERE RowType = 2  
	ELSE IF(@ShowEmptyMaterials = 0)
		DELETE FROM #Result WHERE RowType = 2 AND EstCost = 0 AND ActCost = 0
	
	
	IF(@ShowEmtpyAccounts = 0 AND @cost = 0)
	BEGIN
		DELETE FROM #Result WHERE (RowType = 1 or RowType = 4)
									AND ActCost = 0	
	END
	IF(@ShowEmtpyAccounts = 0 AND @cost = 1)
	BEGIN
		DELETE FROM #Result WHERE (RowType = 1  or RowType = 4)
								 AND EstCost = 0 
	END
	IF(@ShowEmtpyAccounts = 0 AND @cost = 2)
	BEGIN
	
		DELETE FROM #Result WHERE (RowType = 1  or RowType = 4)
									AND EstCost = 0 
									AND ActCost = 0	
	END


	DELETE FROM  #Result
		WHERE prGuid NOT IN(SELECT prGuid from #REsult where RowType = 1 )
			  AND prname <> ''

	  
	/*  
		Rearrange The RowTypes  
	*/  
	  
	UPDATE #Result SET RowType = RowType + 20  
	  
	UPDATE #Result SET [RowType] = CASE [RowType] WHEN 21 THEN 1 
										      WHEN 21.5 THEN 1.5
										      WHEN 26 THEN 2
										      WHEN 27 THEN 3
										      WHEN 22 THEN 4
										      WHEN 23 THEN 5
										      WHEN 28 THEN 6
										      WHEN 24 THEN 7
										      WHEN 25 THEN 8
										      WHEN 29 THEN 9
										      WHEN 30 THEN 10
										      WHEN 31 THEN 11
										      WHEN 32 THEN 12
											  END

	/*  
		End Of Rearrange THE RowTypes  
	*/  
	

	INSERT INTO #Result  
	SELECT  
		0x0  
		,''  
		,ISNULL(PrGuid, 0x0)
		,ISNULL(PrName, '')  
		,0x0  
		,''  
		,0  
		,0  
		,0  
		,0  
		,0  
		,0  
		,0  
		,0  
	FROM #Result  
	WHERE ISNULL(PrGuid, 0x0) <> 0x0
	GROUP BY PrGuid, PrName  
	
	DECLARE @RadomGuidForNullPeriod UNIQUEIDENTIFIER
	SET @RadomGuidForNullPeriod = NEWID()
	
	INSERT INTO #Result VALUES
		(
		0x0  
		,''  
		,@RadomGuidForNullPeriod
		,''
		,0x0  
		,''  
		,0  
		,0  
		,0  
		,0  
		,0  
		,0  
		,0  
		,0  
		)
	  
	SELECT  
		Res.PlGuid  
		,Res.RowType  
		,Res.RowGuid  
		,SUM( ( Res2.ActCost - X.Value ) * ( Res.ActCost - Y.Value ) ) / CASE SUM ( ( Res2.ActCost - X.Value ) * ( Res2.ActCost - X.Value ) ) WHEN 0 THEN 1 ELSE SUM ( ( Res2.ActCost - X.Value ) * ( Res2.ActCost - X.Value ) ) END Slope  
		,Y.Value - ( X.Value * /* Slope */ ( SUM( ( Res2.ActCost - X.Value ) * ( Res.ActCost - Y.Value ) ) / CASE SUM ( ( Res2.ActCost - X.Value ) * ( Res2.ActCost - X.Value ) ) WHEN 0 THEN 1 ELSE SUM ( ( Res2.ActCost - X.Value ) * ( Res2.ActCost - X.Value ) ) END ) ) Init  
		,SUM( ( Res2.ActCost - X.Value ) * ( Res.ActCost - Y.Value ) ) / CASE SQRT( SUM( ( Res2.ActCost - X.Value ) * ( Res2.ActCost - X.Value ) ) * SUM( ( Res.ActCost - Y.Value ) * ( Res.ActCost - Y.Value ) ) ) WHEN 0 THEN 1 ELSE SQRT( SUM( ( Res2.ActCost - X.Value ) * ( Res2.ActCost - X.Value ) ) * SUM( ( Res.ActCost - Y.Value ) * ( Res.ActCost - Y.Value ) ) ) END RSQ  
	INTO #StatisticsTbl  
	FROM #Result Res   
	INNER JOIN #Result Res2 ON Res.PlGuid = Res2.PlGuid AND Res.PrGuid = Res2.PrGuid AND Res2.RowType = 5  
	INNER JOIN   
	(  
		SELECT   
			PlGuid  
			,AVG(ActCost) Value  
		FROM #Result  
		WHERE RowType = 5  
		GROUP BY PlGuid  
	)X ON Res.PlGuid = X.PlGuid  
	INNER JOIN  
	(  
		SELECT   
			PlGuid  
			,RowGuid  
			,AVG(ActCost) Value  
		FROM #Result  
		WHERE RowType IN (1, 2, 3, 7)  
		GROUP BY PlGuid, RowGuid  
	)Y ON Res.PlGuid = Y.PlGuid AND Res.RowGuid = Y.RowGuid  
	  
	WHERE Res.RowType IN (1, 2, 3, 7)  
	GROUP BY Res.PlGuid  
			,Res.RowType  
			,Res.RowGuid  
			,X.Value  
			,Y.Value  
	  
	UPDATE #Result  
	SET Slope = StatisticsTbl.Slope  
		,Init = StatisticsTbl.Init  
		,RSQ = StatisticsTbl.RSQ  
	FROM #Result Res  
	INNER JOIN #StatisticsTbl StatisticsTbl ON Res.PlGuid = StatisticsTbl.PlGuid AND Res.RowType = StatisticsTbl.RowType AND Res.RowGuid = StatisticsTbl.RowGuid  
	
	/*
	 Totals Culomn
	*/
	
	INSERT INTO #Result  
	SELECT  
		PlGuid
		,PlName
		,@RadomGuidForNullPeriod
		,''
		,RowGuid  
		,RowName
		,RowType
		,CASE  
			WHEN RowType IN (4, 5, 9) THEN SUM(EstCost) ELSE CASE @IsAnnual 
												WHEN 0 THEN SUM(EstCost) 
												ELSE AVG(EstCost)
											END 
		END
		,SUM(ActCost)
		,CASE @IsAnnual WHEN 0 THEN SUM(EstCost) ELSE AVG(EstCost) END - SUM(ActCost)
		,CASE SUM(EstCost) WHEN 0 THEN 0 ELSE 100 * (SUM(EstCost) - SUM(ActCost)) / SUM(EstCost) END
		,0  
		,0  
		,0  
	FROM #Result  
	WHERE ISNULL(PrGuid, 0x0) <> 0x0 AND RowType <> 0
	GROUP BY PlGuid, PlName, RowGuid, RowName, RowType
	
	


	UPDATE #Result SET EstCost = r2.EstCost
	FROM #Result r1
	INNER JOIN 
	(
		SELECT
			PlGuid
			,PrGuid
			,SUM(EstCost) EstCost
		FROM #Result
		WHERE RowType IN (1, 2)
			AND PrGuid = @RadomGuidForNullPeriod
		GROUP BY PlGuid, PrGuid
	) r2 ON r1.PlGuid = r2.PlGuid AND r1.PrGuid = r2.PrGuid
	WHERE RowType = 3 AND r1.PrGuid = @RadomGuidForNullPeriod AND r2.PrGuid = @RadomGuidForNullPeriod
	
	UPDATE #Result SET 
		EstCost = CASE r2.EstCost WHEN 0 THEN 0 ELSE r3.EstCost / r2.EstCost END
		,ActCost = CASE r2.ActCost WHEN 0 THEN 0 ELSE r3.ActCost / r2.ActCost END
	FROM #Result r1
	INNER JOIN 
	(
		SELECT
			PlGuid
			,PrGuid
			,EstCost
			,ActCost
		FROM #Result
		WHERE RowType = 5
			AND PrGuid = @RadomGuidForNullPeriod
	) r2 ON r1.PlGuid = r2.PlGuid AND r1.PrGuid = r2.PrGuid
	INNER JOIN 
	(
		SELECT
			PlGuid
			,PrGuid
			,EstCost
			,ActCost
		FROM #Result
		WHERE RowType = 3
			AND PrGuid = @RadomGuidForNullPeriod
	) r3 ON r1.PlGuid = r3.PlGuid AND r1.PrGuid = r2.PrGuid
	WHERE r1.PrGuid = @RadomGuidForNullPeriod
		AND RowType = 6
	
	UPDATE #Result SET 
		EstCost = r2.EstCost
		,ActCost = r2.ActCost
	FROM #Result r1
	INNER JOIN 
	(
		SELECT
			PlGuid
			,PrGuid
			,EstCost
			,ActCost
		FROM #Result
		WHERE RowType = 3
			AND PrGuid = @RadomGuidForNullPeriod
	) r2 ON r2.PrGuid = r1.PrGuid
	WHERE r2.PrGuid = @RadomGuidForNullPeriod
		AND RowType = 10

	IF @IsAnnual = 0
	BEGIN
		 UPDATE #Result
			SET	 EstCost=(SELECT SUM(EstCost) from #Result where PrName<>'' and RowType = 10)
				, ActCost=(SELECT SUM(ActCost) from #Result where PrName<>'' and RowType = 10)
				, Diff = (SELECT SUM(Diff) from #Result where PrName<>'' and RowType = 10)
			where PrName =''  and RowType=10	
	END
	ELSE
	BEGIN

	

	 UPDATE #Result
			SET	 EstCost=(SELECT SUM(EstCost) from #Result where PrName = '' and RowType = 3 and PrGuid <> 0x0)
				, ActCost=(SELECT SUM(ActCost) from #Result where PrName = '' and RowType = 3  and PrGuid <> 0x0)
				, Diff = (SELECT SUM(Diff) from #Result where PrName ='' and RowType = 3  and PrGuid <> 0x0)
			where PrName =''  and RowType=10	
	END	

	UPDATE #Result SET 
		EstCost = CASE r2.EstCost WHEN 0 THEN 0 ELSE r3.EstCost / r2.EstCost END
		,ActCost = CASE r2.ActCost WHEN 0 THEN 0 ELSE r3.ActCost / r2.ActCost END
	FROM #Result r1
	INNER JOIN 
	(
		SELECT
			PlGuid
			,PrGuid
			,EstCost
			,ActCost
		FROM #Result
		WHERE RowType = 9
			AND PrGuid = @RadomGuidForNullPeriod
	)r2 ON r2.PrGuid = r1.PrGuid
	INNER JOIN 
	(
		SELECT
			PlGuid
			,PrGuid
			,EstCost
			,ActCost
		FROM #Result
		WHERE RowType = 10
			AND PrGuid = @RadomGuidForNullPeriod
	)r3 ON r3.PrGuid = r1.PrGuid
	WHERE r2.PrGuid = @RadomGuidForNullPeriod
		AND RowType = 11
	
	
	DELETE FROM #Result
	WHERE ISNULL(PrGuid, 0x0) = 0x0 AND RowType <> 1
	
	IF(@IsAnnual = 1 AND @Save = 0)
		DELETE FROM #Result WHERE PrGuid <> @RadomGuidForNullPeriod
	
	/*
	 End Of Totals Culomn
	*/
	
	UPDATE #Result SET Diff = CAST(ActCost - EstCost AS FLOAT)  
	UPDATE #Result SET Percentage = 100 * Diff / EstCost WHERE EstCost <> 0  

	
	/*************************************************************************************/
	/*********Õ”«» «·„Ã„Ê⁄ »”ÿ— „Ã„Ê⁄ ﬂ·›… «··Ì — „‰ «·‰›ﬁ«  «·⁄«„… **************/
	/*****
	 „Ã„Ê⁄ «·‰›ﬁ«  «·⁄«„… ·ﬂ· «·√‘Â—
	 				/
	 „Ã„Ê⁄ «·≈‰ «Ã «·„ﬁœ— »«··Ì — ·ﬂ· «·√‘Â—
	 *****/	


	UPDATE #Result SET EstCost = r.EstCost 
					, ActCost = r.ActCost
					, Diff = r.ActCost - r.EstCost
					, Percentage = ((r.ActCost - r.EstCost) /case r.EstCost when 0 then 1 else r.EstCost end ) * 100
	FROM 
	(SELECT 
		 (r1.EstCost / r2.EstCost) AS EstCost
		,(r1.ActCost / r2.ActCost) AS ActCost
	FROM #result r1
		INNER JOIN #result r2 ON r1.PrGuid = r2.PrGuid AND r2.[RowType] = 9  
	WHERE r1.[RowType] = 8 AND r1.PrGuid = @RadomGuidForNullPeriod  
	) AS r
	WHERE PrGuid = @RadomGuidForNullPeriod AND [RowType] = 12
	/*************************************************************************************/		
	IF(@Save = 0)
		SELECT Res.* FROM #Result Res  
		LEFT JOIN #Periods Bdp ON Bdp.prGuid = Res.PrGuid  
		ORDER BY PlName/**/, RowType, RowName, CASE WHEN ISNULL(Bdp.prGuid, 0x0) = 0x0 THEN '1-1-2050' ELSE Bdp.prStartDate END  
	  
	ELSE IF(@Save = 2 OR @Save = 4)
	BEGIN  	  
		INSERT INTO PlCosts000  
		SELECT  
			PlGuid  
			,PrGuid  
			,CASE @Save WHEN 2 THEN EstCost ELSE 0 END  
			,CASE @Save WHEN 4 THEN ActCost ELSE 0 END  
		FROM #Result  
		WHERE RowType = 6
			AND PlGuid NOT IN (SELECT ProductionLine FROM PlCosts000 WHERE ProductionLine = PlGuid AND Period = PrGuid)  
			AND PrGuid <> @RadomGuidForNullPeriod

		UPDATE PlCosts000  
		SET   
			EstimatedCost = CASE @Save WHEN 2 THEN Result.EstCost ELSE PlCosts.EstimatedCost END  
			,ActualCost = CASE @Save WHEN 4 THEN Result.ActCost ELSE PlCosts.ActualCost END  
		FROM PlCosts000 PlCosts  
		INNER JOIN #Result Result ON PlCosts.ProductionLine = Result.PlGuid AND PlCosts.Period = Result.PrGuid  
		WHERE Result.RowType = 6
			AND PrGuid <> @RadomGuidForNullPeriod
	END  
		  
	ELSE IF(@Save = 1 OR @Save = 3)
		IF(@IsAnnual = 1)
		BEGIN
			
			UPDATE ProductionLine000  
				SET EstimatedCost = CASE @Save WHEN 1 THEN Result.EstCost ELSE Pl.EstimatedCost END  
					,ActualCost = CASE @Save WHEN 3 THEN Result.ActCost ELSE Pl.ActualCost END  
			FROM ProductionLine000 Pl  
			INNER JOIN #Result Result ON Pl.Guid = Result.PlGuid  
			WHERE Result.RowType = 6		  
				AND PrGuid = @RadomGuidForNullPeriod

		END
		ELSE
		BEGIN
			
			INSERT INTO PlCosts000  
			SELECT  
				r.PlGuid  
				,r.PrGuid  
				,CASE @Save WHEN 1 THEN r.EstCost ELSE 0 END  
				,CASE @Save WHEN 3 THEN r.ActCost ELSE 0 END  
			FROM 
			(
				SELECT r1.PlGuid, r2.PrGuid, r1.EstCost, r1.ActCost
				FROM #Result r1
				INNER JOIN #Result r2 ON r1.PlGuid = r2.PlGuid
				WHERE r1.PrGuid = @RadomGuidForNullPeriod
					AND r1.PlGuid NOT IN (SELECT ProductionLine FROM PlCosts000 WHERE ProductionLine = r1.PlGuid AND Period = r2.PrGuid)
					AND r1.RowType = 6 
					AND r2.RowType = 6
					AND r2.PrGuid <> @RadomGuidForNullPeriod
			) r
			
			UPDATE PlCosts000  
			SET   
				EstimatedCost = CASE @Save WHEN 1 THEN Result.EstCost ELSE PlCosts.EstimatedCost END  
				,ActualCost = CASE @Save WHEN 3 THEN Result.ActCost ELSE PlCosts.ActualCost END  
			FROM PlCosts000 PlCosts  
			INNER JOIN 
			(
				SELECT r1.PlGuid, r2.PrGuid, r1.EstCost, r1.ActCost
				FROM #Result r1
				INNER JOIN #Result r2 ON r1.PlGuid = r2.PlGuid
				WHERE r1.PrGuid = @RadomGuidForNullPeriod
					AND r1.RowType = 6 
					AND r2.RowType = 6
			)Result ON PlCosts.ProductionLine = Result.PlGuid AND PlCosts.Period = Result.PrGuid  
			
			
		END
######################################################
CREATE PROCEDURE prcJobOrdersReport
	  @FactoryGuid      AS [UNIQUEIDENTIFIER]	= 0x0,
	  @ProductionLine	AS [UNIQUEIDENTIFIER]	= 0x0,
	  @Bom				AS [UNIQUEIDENTIFIER]	= 0x0,
	  @FromDate			AS [DATETIME]			,
	  @ToDate			AS [DATETIME]			,
	  @FldsFlag			AS [INT]				= 1
AS 

DECLARE @Lang [INT]
SELECT @Lang = dbo.fnConnections_GetLanguage()

	CREATE TABLE #TOTALCOSTS 
	(
		JobOrderGuid						 [UNIQUEIDENTIFIER],
		RequiredQty							 [FLOAT],
		laborCost							 [FLOAT],
		TotalDirectMaterials				 [FLOAT],
		TotalMOH							 [FLOAT],
		DeviationMOH						 [FLOAT],
		TotalDirectExpenses					 [FLOAT],
		ActualProductionUsingManufactoryUnit [FLOAT],
		MachineHours						 [FLOAT],
		LaborHours							 [FLOAT],
		calcMethod							 [INT],
		IsActive							 [INT]
	)

	INSERT INTO #TOTALCOSTS (JobOrderGuid , RequiredQty, calcMethod, IsActive)
	SELECT 
		JobOrder.Guid,
		SUM(cost.RequiredQty),
		Man.MohAllocationBase,
		joborder.IsActive
	FROM JobOrder000 joborder
		INNER JOIN JOCJobOrderCosts000 cost ON cost.JobOrderGuid = joborder.Guid
		INNER JOIN Manufactory000 Man ON Man.Guid = joborder.ManufactoryGUID
		WHERE 	(Man.Guid =  @FactoryGuid OR @FactoryGuid = 0x0) 
			AND (joborder.ProductionLine = @ProductionLine OR @ProductionLine = 0x0)
			AND (joborder.FormGuid = @Bom OR @Bom = 0x0)
	GROUP BY 	
		JobOrder.Guid,
		Man.MohAllocationBase,
		Man.EstimatedCostCalcBase,
		joborder.IsActive

		SELECT 
			 Bu.Guid AS BuGuid,
			 Bu.Date,
			 jo.Guid AS jobOrderGuid
			INTO #Bills FROM JobOrder000 Jo
			INNER JOIN Bu000 Bu ON Bu.CustAccGuid = Jo.Account
			INNER JOIN 
			( SELECT DISTINCT
						FinishedGoodsBillType 
			  FROM Manufactory000 Mu 
			  INNER JOIN JobOrder000 Jo ON Mu.[Guid] = Jo.[ManufactoryGUID]
			  WHERE (Jo.[ManufactoryGUID] = @FactoryGuid OR @FactoryGuid = 0x0) 
				AND (Jo.ProductionLine = @ProductionLine OR @ProductionLine = 0x0)
				AND (Jo.FormGuid = @Bom OR @Bom = 0x0)
			) AS BillType ON Bu.TypeGUID = BillType.FinishedGoodsBillType
				WHERE (Jo.[ManufactoryGUID] = @FactoryGuid OR @FactoryGuid = 0x0) 
				  AND (Jo.ProductionLine = @ProductionLine OR @ProductionLine = 0x0)
				  AND (Jo.FormGuid = @Bom OR @Bom = 0x0)
			ORDER BY jo.Guid

	;WITH CTE_WorkersHours AS 
	(
		SELECT 
			src.JobOrder AS JobOrder,
			 CASE WHEN Man.EstimatedCostCalcBase = 0 THEN SUM(src.LaborCost * plcost.EstimatedCost)
			 ELSE SUM(src.LaborCost) * pline.EstimatedCost END  MohTotalcost,
			 CASE WHEN Man.EstimatedCostCalcBase = 0 THEN SUM(src.LaborCost * (plcost.ActualCost -  plcost.EstimatedCost))
			 ELSE SUM(src.LaborCost) * (pline.ActualCost - pline.EstimatedCost ) END Deviationcost
			 FROM 
			(SELECT Allocations.Date,
					Allocations.JobOrder,
					SUM(WorkersDetials.WorkingHours) LaborCost
				FROM DirectLaborAllocationDetail000  WorkersDetials
				INNER JOIN [DirectLaborAllocation000] Allocations ON Allocations.Guid = WorkersDetials.JobOrderDistributedCost
				GROUP BY Allocations.Date , Allocations.JobOrder
			) AS src
			INNER JOIN JobOrder000 jobOrder ON jobOrder.Guid = src.JobOrder
			INNER JOIN Manufactory000 Man ON Man.Guid = jobOrder.ManufactoryGUID
			LEFT JOIN ProductionLine000 pline ON pline.Guid = jobOrder.ProductionLine
			LEFT JOIN Plcosts000 plcost ON plcost.ProductionLine =  pline.Guid AND (MONTH(plcost.StartPeriodDate) = MONTH(src.Date) AND YEAR(plcost.StartPeriodDate) = YEAR(src.Date)) 
			WHERE (Man.Guid =  @FactoryGuid OR @FactoryGuid = 0x0) 
			  AND (joborder.ProductionLine = @ProductionLine OR @ProductionLine = 0x0)
			  AND (joborder.FormGuid = @Bom OR @Bom = 0x0)
		GROUP by 
			src.JobOrder, 
			Man.EstimatedCostCalcBase,
			pline.EstimatedCost,
			pline.ActualCost
	)

	,CTE_MachinesHours AS 
	(
		SELECT 
			src.JobOrder,
			 CASE WHEN Man.EstimatedCostCalcBase = 0 THEN SUM(src.WorkingMachinsHours * plcost.EstimatedCost)
			 ELSE SUM(src.WorkingMachinsHours) * pline.EstimatedCost END  MohTotalcost,
			 CASE WHEN Man.EstimatedCostCalcBase = 0 THEN SUM(src.WorkingMachinsHours * (plcost.ActualCost -  plcost.EstimatedCost))
			 ELSE SUM(src.WorkingMachinsHours) * (pline.ActualCost - pline.EstimatedCost ) END Deviationcost
		FROM 
		(SELECT JobOrderGuid AS JobOrder,
				     PeriodDate AS Date,
				     SUM(PeriodWorkingMachinsHours) AS WorkingMachinsHours
		FROM JOCJobOrderGeneralExpenses000
		GROUP BY 
			JobOrderGuid,
			PeriodDate
		) AS src
		INNER JOIN JobOrder000 jobOrder ON jobOrder.Guid = src.JobOrder
		INNER JOIN Manufactory000 Man ON Man.Guid = jobOrder.ManufactoryGUID
		LEFT JOIN ProductionLine000 pline ON pline.Guid = jobOrder.ProductionLine
		LEFT JOIN Plcosts000 plcost ON plcost.ProductionLine =  pline.Guid AND (MONTH(plcost.StartPeriodDate) = MONTH(src.Date) AND YEAR(plcost.StartPeriodDate) = YEAR(src.Date)) 
		WHERE (Man.Guid =  @FactoryGuid OR @FactoryGuid = 0x0) 
		  AND (joborder.ProductionLine = @ProductionLine OR @ProductionLine = 0x0)
		  AND (joborder.FormGuid = @Bom OR @Bom = 0x0)
		GROUP by 
			src.JobOrder, 
			Man.EstimatedCostCalcBase,
			pline.EstimatedCost,
			pline.ActualCost
	 )

	 ,CTE_QtyMoh AS
	 (
		SELECT 
			src.JobOrder,
			 CASE WHEN Man.EstimatedCostCalcBase = 0 THEN SUM(CASE WHEN Man.ProductionUnitOne = Man.UsedProductionUnit THEN  src.Qty1 ELSE src.Qty2 END * plcost.EstimatedCost)
			 ELSE SUM(CASE WHEN Man.ProductionUnitOne = Man.UsedProductionUnit THEN  src.Qty1 ELSE src.Qty2 END) * pline.EstimatedCost END  MohTotalcost,
			 CASE WHEN Man.EstimatedCostCalcBase = 0 THEN SUM(CASE WHEN Man.ProductionUnitOne = Man.UsedProductionUnit THEN  src.Qty1 ELSE src.Qty2 END * (plcost.ActualCost -  plcost.EstimatedCost))
			 ELSE SUM(CASE WHEN Man.ProductionUnitOne = Man.UsedProductionUnit THEN  src.Qty1 ELSE src.Qty2 END) * (pline.ActualCost - pline.EstimatedCost ) END Deviationcost
		FROM (SELECT Bills.Date ,
					 Bills.jobOrderGuid AS JobOrder,
					 SUM(bi.Qty * bomunit.Prod1ToMatUnitConvFactor) AS Qty1,
					 SUM(bi.Qty * bomunit.Prod2ToMatUnitConvFactor) AS Qty2
			 FROM #Bills AS Bills
			 INNER JOIN bi000 AS bi ON bi.ParentGUID = Bills.BuGuid
			 INNER JOIN JobOrder000 jo on jo.Guid = Bills.jobOrderGuid
			 INNER join JOCBOM000 bom ON bom.GUID = jo.FormGuid
			 INNER JOIN JOCBOMUnits000 bomunit ON bomunit.BOMGUID = bom.GUID AND bi.MatGUID = bomunit.MatPtr
			 WHERE (jo.ManufactoryGUID =  @FactoryGuid OR @FactoryGuid = 0x0) 
			   AND (jo.ProductionLine = @ProductionLine OR @ProductionLine = 0x0)
			   AND (jo.FormGuid = @Bom OR @Bom = 0x0)
			 GROUP BY
			 	Bills.Date ,
			 	Bills.jobOrderGuid
			) AS src
			INNER JOIN JobOrder000 jobOrder ON jobOrder.Guid = src.JobOrder
			INNER JOIN Manufactory000 Man ON Man.Guid = jobOrder.ManufactoryGUID
			LEFT JOIN ProductionLine000 pline ON pline.Guid = jobOrder.ProductionLine
			LEFT JOIN Plcosts000 plcost ON plcost.ProductionLine =  pline.Guid AND (MONTH(plcost.StartPeriodDate) = MONTH(src.Date) AND YEAR(plcost.StartPeriodDate) = YEAR(src.Date)) 
			 WHERE (Man.Guid=  @FactoryGuid OR @FactoryGuid = 0x0) 
			   AND (jobOrder.ProductionLine = @ProductionLine OR @ProductionLine = 0x0)
			   AND (jobOrder.FormGuid = @Bom OR @Bom = 0x0)
		GROUP by 
			src.JobOrder, 
			Man.EstimatedCostCalcBase,
			pline.EstimatedCost,
			pline.ActualCost
	 )

	--Update All For UnFinished JobOrders

	UPDATE Total
		SET ActualProductionUsingManufactoryUnit =  ISNUll(JobOrderQTY.ActualQty, 0) ,
			TotalDirectMaterials                 =	ISNULL(DirctMat.DirectMaterial, 0),
			laborCost							 =	ISNULL(LaborHoursCost.laborHoursCost, 0) ,
			LaborHours							 =	ISNULL(LaborHoursCost.TotalLaborHours, 0),
			MachineHours						 =	ISNULL(Machine.MachineWorkingHours, 0),
			TotalDirectExpenses					 =	ISNULL(DirectExpense.DirectExpenses, 0),
			DeviationMOH						 =	CASE Total.calcMethod
												    WHEN 0 
													THEN 
													   CASE WHEN ABS(ISNULL(QtyMoh.Deviationcost, 0)) = ISNULL(QtyMoh.MohTotalcost, 0) THEN 0 ELSE ISNULL(QtyMoh.Deviationcost, 0) END
													WHEN 1 
													 THEN 
													   CASE WHEN ABS(ISNULL(WorkersMoh.Deviationcost, 0)) = ISNULL(WorkersMoh.MohTotalcost, 0) THEN 0 ELSE ISNULL(WorkersMoh.Deviationcost, 0) END
													ELSE 
													   CASE WHEN ABS(ISNULL(MachinesMoh.Deviationcost, 0)) = ISNULL(MachinesMoh.MohTotalcost, 0) THEN 0 ELSE ISNULL(MachinesMoh.Deviationcost, 0) END END,
			TotalMOH							 = CASE Total.calcMethod 
												   WHEN 0 
												    THEN ISNULL(QtyMoh.MohTotalcost, 0)
												   WHEN 1 
												    THEN ISNULL(WorkersMoh.MohTotalcost, 0) 
												   ELSE 
												    ISNULL(MachinesMoh.MohTotalcost, 0) END
		FROM #TOTALCOSTS Total

		LEFT JOIN 
		(SELECT JobOrderGuid,
				CASE WHEN ManufUsedUnit = 1 THEN SUM( FirstProductionUnityQty) ELSE SUM( SecondProductionUnityQty) END AS ActualQty
		 FROM JOCvwJobOrderFinishedGoodsBillItemsQtys 
		 GROUP BY JobOrderGuid, ManufUsedUnit
		) AS JobOrderQTY ON JobOrderQTY.JobOrderGuid = Total.JobOrderGuid 	

		LEFT JOIN 
		(SELECT JobOrderGuid,
				SUM(NetExchange) AS DirectMaterial
		 FROM JOCvwGeneralCostItemsQuantities
		 GROUP BY JobOrderGuid	
		) AS DirctMat ON DirctMat.JobOrderGuid = Total.JobOrderGuid

		LEFT JOIN 
		(SELECT JobOrder,
				SUM(TotalWorkingHoursCost) AS laborHoursCost,
				SUM(TotalWorkingHours) AS TotalLaborHours
		FROM JOCvwDiectLaborsCostDistribution
		GROUP BY JobOrder
		) AS LaborHoursCost ON LaborHoursCost.JobOrder = Total.JobOrderGuid

		LEFT JOIN 
		(SELECT JobOrderGuid,
				SUM(PeriodWorkingMachinsHours) AS MachineWorkingHours
		FROM JOCJobOrderGeneralExpenses000
		WHERE MOHEntryGuid = 0x0 AND DeviationEntryGuid = 0x0
		GROUP BY JobOrderGuid
		) AS Machine ON Machine.JobOrderGuid = Total.JobOrderGuid

		LEFT JOIN 
		(SELECT ExpenseEntry.JobOrderGUID,
		   SUM(CASE WHEN StageGuid = 0x0 THEN TotalExpenses ELSE Expense END) AS DirectExpenses 
		FROM JOCBOMDirectExpenseItems000 Item
		INNER JOIN JOCBOMJobOrderEntry000 ExpenseEntry ON Item.ParentGuid = ExpenseEntry.GUID 
		GROUP BY ExpenseEntry.JobOrderGUID
		) AS DirectExpense ON DirectExpense.JobOrderGUID = Total.JobOrderGuid

	   LEFT JOIN CTE_WorkersHours AS WorkersMoh ON WorkersMoh.JobOrder = Total.JobOrderGuid AND Total.calcMethod = 1
	   LEFT JOIN CTE_MachinesHours AS MachinesMoh ON MachinesMoh.JobOrder = Total.JobOrderGuid AND Total.calcMethod = 2
	   LEFT JOIN CTE_QtyMoh AS QtyMoh ON QtyMoh.JobOrder = Total.JobOrderGuid AND Total.calcMethod = 0

	   IF(@FldsFlag & 1 <> 1)
	   BEGIN
		UPDATE #TOTALCOSTS 
			SET 
			laborCost							 = 0,
			TotalDirectMaterials				 = 0,
			TotalMOH							 = 0,
			DeviationMOH						 = 0,
			TotalDirectExpenses					 = 0,
			ActualProductionUsingManufactoryUnit = 0,
			MachineHours 					= 0, 
			LaborHours	=0						 
		FROM #TOTALCOSTS 
		WHERE IsActive = 1
	   END

	SELECT 
	   Jo.Guid
	  ,Jo.Name
	  ,Jo.Number
	  ,Man.InsertNumber												AS FactoryNumber
	  ,jo.ManufactoryGUID
	  ,jo.FormGuid													AS FormGuid
	  ,jo.ProductionLine											AS ProductionLineGuid
	  ,Jo.Account													AS AccountGuid
	  ,jo.Store														AS StoreGuid
	  ,jo.Branch													AS BranchGuid
	  ,TotalCosts.RequiredQty										AS PlannedQty
	  ,TotalCosts.ActualProductionUsingManufactoryUnit				AS ActualQty
	  ,Jo.StartDate
	  ,jo.TargetEndDate
	  ,Jo.EndDate
	  ,''															AS StatusName
	  ,''															AS FactoryAllocationBaseName
	  ,''															AS FactoryEstimationName
	  ,Man.EstimatedCostCalcBase
	  ,Jo.IsActive Status,
	  TotalCosts.calcMethod											AS MohAllocationBase
	  ,CASE WHEN @Lang <> 0 AND Man.LatineName <> '' 
			THEN  Man.LatineName ELSE Man.Name END					AS ManufacturyName
	  ,CASE WHEN @Lang <> 0 AND Fm.LatinName <> '' 
			THEN  Fm.LatinName ELSE Fm.Name END						AS FormName
	  ,CASE WHEN @Lang <> 0 AND pl.LatinName <> '' 
			THEN  pl.LatinName ELSE pl.Name END						AS ProductionLineName
	  ,CASE WHEN @Lang <> 0 AND ac.LatinName <> '' 
			THEN   ac.Code + ''+ ac.LatinName ELSE ac.Code + '-' + ac.Name  END	AS AccountName
	  ,CASE WHEN @Lang <> 0 AND St.LatinName <> '' 
			THEN  St.LatinName ELSE St.Name END						AS StoreName
	  ,ISNULL(CASE WHEN @Lang <> 0 AND Br.LatinName <> '' 
			  THEN  Br.LatinName ELSE Br.Name END, '')  AS BranchName
	  ,ISNULL(CASE WHEN @Lang <> 0 AND plUnits.LatinName <> '' 
			  THEN  plUnits.LatinName ELSE plUnits.Name END, '')   AS UsedProductionLineUnit
	  ,TotalCosts.TotalDirectMaterials AS DirectMaterialsCost
	  ,CASE TotalCosts.ActualProductionUsingManufactoryUnit WHEN 0 THEN 0 ELSE TotalCosts.TotalDirectMaterials / TotalCosts.ActualProductionUsingManufactoryUnit END AS UnitCostFromDirectMaterials
	  ,TotalCosts.laborCost AS Wages
	  ,CASE TotalCosts.ActualProductionUsingManufactoryUnit WHEN 0 THEN 0 ELSE TotalCosts.laborCost / TotalCosts.ActualProductionUsingManufactoryUnit END AS UnitCostFromLabors
	  ,TotalCosts.TotalMOH AS Moh
	  ,CASE TotalCosts.ActualProductionUsingManufactoryUnit WHEN 0 THEN 0 ELSE (TotalCosts.TotalMOH) / TotalCosts.ActualProductionUsingManufactoryUnit END AS UnitCostFromMoh
	  ,CASE WHEN TotalCosts.LaborHours = 0 THEN 0 ELSE TotalCosts.laborCost / TotalCosts.LaborHours END AS CostOfWorkHour
	  ,TotalCosts.LaborHours  AS WorkersHours
	  ,TotalCosts.MachineHours AS MachineHours
	  ,CASE WHEN TotalCosts.MachineHours = 0 THEN 0 ELSE (TotalCosts.TotalDirectMaterials + TotalCosts.TotalDirectExpenses + TotalCosts.laborCost + TotalCosts.TotalMOH + TotalCosts.DeviationMOH) / TotalCosts.MachineHours  END AS CostOfMachineHours
	  ,TotalCosts.TotalDirectExpenses AS TotalDirectExpenses
	  ,CASE TotalCosts.ActualProductionUsingManufactoryUnit WHEN 0 THEN 0 ELSE TotalCosts.TotalDirectExpenses / TotalCosts.ActualProductionUsingManufactoryUnit END AS UnitCostFromDirectExpenses
	  ,TotalCosts.DeviationMOH AS DerivationValue
	  ,TotalCosts.TotalMOH + TotalCosts.DeviationMOH AS NetMoh
	  ,TotalCosts.TotalDirectMaterials + TotalCosts.TotalDirectExpenses + TotalCosts.laborCost + TotalCosts.TotalMOH + TotalCosts.DeviationMOH AS TotalCost
	  ,CASE WHEN TotalCosts.ActualProductionUsingManufactoryUnit = 0 THEN 0 ELSE (TotalCosts.TotalDirectMaterials + TotalCosts.TotalDirectExpenses + TotalCosts.laborCost + TotalCosts.TotalMOH + TotalCosts.DeviationMOH) / TotalCosts.ActualProductionUsingManufactoryUnit END AS UnitCostFromTotalCost
	FROM JobOrder000 Jo
	INNER JOIN Manufactory000 AS Man ON Man.Guid = Jo.ManufactoryGUID
	INNER JOIN ProductionLine000 Pl ON Pl.Guid = Jo.ProductionLine
	INNER JOIN JOCProductionUnit000 AS plUnits ON plUnits.GUID = Man.UsedProductionUnit
	INNER JOIN ac000 ac ON ac.GUID = jo.Account
	INNER JOIN JOCBOM000 Fm ON Fm.Guid = Jo.FormGuid
	INNER JOIN St000 St ON St.Guid = Jo.Store
	INNER JOIN #TOTALCOSTS TotalCosts ON jo.Guid = TotalCosts.JobOrderGuid
	LEFT JOIN Br000 Br ON Br.Guid = Jo.Branch
	WHERE (Man.Guid=  @FactoryGuid OR @FactoryGuid = 0x0) 
		  AND (Jo.ProductionLine = @ProductionLine OR @ProductionLine = 0x0)
		  AND (Jo.FormGuid = @Bom OR @Bom = 0x0)
		  AND ((jo.IsActive = 1 AND @FldsFlag & 4 = 4 )
		  OR  (jo.IsActive = 0 AND @FldsFlag & 2 = 2 ))
		  AND jo.StartDate BETWEEN @FromDate AND @ToDate
######################################################
CREATE PROC PrcGetProductionCosts
	  @FactoryGuid      AS [UNIQUEIDENTIFIER]	= 0x0,
	  @ProductionLine	AS [UNIQUEIDENTIFIER]	= 0x0,
	  @MatGuid			AS [UNIQUEIDENTIFIER]	= 0x0,
	  @GrGuid           AS [UNIQUEIDENTIFIER]	= 0x0,
	  @StartDate		AS [DATETIME]			,
	  @EndDate			AS [DATETIME]			
 AS 
	SET NOCOUNT ON
	DECLARE @Lang [INT]
	 SELECT @Lang = dbo.fnConnections_GetLanguage()
	SELECT 
		   Mt.mtGUID AS MatGuid,
		  CASE WHEN @Lang <> 0 AND Mt.mtLatinName <> '' THEN  Mt.mtLatinName ELSE Mt.mtName END AS MatName ,
		  CASE WHEN @Lang <> 0 AND Mt.grLatinName <> '' THEN  Mt.grLatinName ELSE Mt.grName END  AS GrName,
		   Mt.grGUID AS GrGuid,
		   CASE WHEN JobOrderCosts.BOMUnit = 1 THEN Mt.mtUnity WHEN JobOrderCosts.BOMUnit = 2 THEN Mt.mtUnit2 ELSE Mt.mtUnit3 END                    AS MatUnit,
			JobOrderCosts.RequiredQty                  AS PlannedMatQty,
			JobOrderCosts.ActualProductionUsingBOMUnit AS ActualQty,
			JobOrder.Guid							   AS JobOrderGuid,
			JobOrder.Name                              AS JobOrderName,
			JobOrder.Number							   AS JobOrderNumber,
			JobOrder.StartDate,
			JobOrder.EndDate,
			JobOrder.TargetEndDate,
			JobOrder.Account						   AS AccountGuid,
			CASE WHEN @Lang <> 0 AND ac.LatinName <> '' THEN  ac.LatinName ELSE ac.Name END AS AccoutName, 
			st.GUID	AS StoreGuid,
			CASE WHEN @Lang <> 0 AND st.LatinName  <> '' THEN  st.LatinName  ELSE st.Name END AS StName,
			CASE WHEN @Lang <> 0 AND ISNULL(br.LatinName, '' ) <> ''THEN  ISNULL(br.LatinName, '' ) ELSE ISNULL(br.Name, '' ) END AS BrName,
			Man.Guid AS FactoryGuid,
			CASE WHEN @Lang <> 0 AND Man.LatineName <> '' THEN  Man.LatineName ELSE Man.Name END 	AS FactoryName,
			pl.Guid										AS PlGuid,
			CASE WHEN @Lang <> 0 AND pl.LatinName <> '' THEN  pl.LatinName ELSE pl.Name END	AS PlName,
			JobOrderCosts.TotalDirectExpenses,
			JobOrderCosts.TotalProductionCost,
			JobOrderCosts.UnitCost,
			JobOrderCosts.TotalMOH,
			JobOrderCosts.TotalDirectMaterials,
			JobOrderCosts.TotalDirectLabors,
			CASE WHEN JobOrderCosts.ActualProductionUsingBOMUnit = 0 THEN 0 ELSE JobOrderCosts.TotalDirectLabors / JobOrderCosts.ActualProductionUsingBOMUnit END  AS UnitCostFromLabor,
			CASE WHEN JobOrderCosts.ActualProductionUsingBOMUnit = 0 THEN 0 ELSE JobOrderCosts.TotalDirectExpenses / JobOrderCosts.ActualProductionUsingBOMUnit END  AS UnitCostFromDirExp,
			CASE WHEN JobOrderCosts.ActualProductionUsingBOMUnit = 0 THEN 0 ELSE JobOrderCosts.TotalMOH / JobOrderCosts.ActualProductionUsingBOMUnit END			 AS UnitCostFromMoh,
			CASE WHEN JobOrderCosts.ActualProductionUsingBOMUnit = 0 THEN 0 ELSE JobOrderCosts.TotalDirectMaterials / JobOrderCosts.ActualProductionUsingBOMUnit END AS UnitCostFromDirMt,
			Man.EstimatedCostCalcBase,
			Man.MohAllocationBase,
			CASE WHEN @Lang <> 0 AND Bom.LatinName  <> '' THEN  Bom.LatinName ELSE Bom.Name END AS BomName,
			Bom.GUID AS BomGuid,
			'' AS MohAllocationBaseName,
			'' AS EstimatedCostCalcBaseName,
			Man.InsertNumber AS FactoryNumber
	FROM JOCJobOrderCosts000 AS JobOrderCosts
		INNER JOIN JobOrder000 AS JobOrder ON JobOrder.Guid = JobOrderCosts.JobOrderGuid
		INNER JOIN Manufactory000 AS Man ON Man.Guid = JobOrder.ManufactoryGUID
		INNER JOIN ProductionLine000 AS Pl ON pl.Guid = JobOrder.ProductionLine
		INNER JOIN JOCBOM000 AS Bom ON Bom.GUID = JobOrder.FormGuid
		INNER JOIN ac000 AS ac ON ac.GUID = JobOrder.Account
		INNER JOIN vwMtGr AS Mt ON mt.mtGUID = JobOrderCosts.FinishedMaterialGuid
		INNER JOIN St000 As st ON st.GUID = JobOrder.Store
		LEFT JOIN br000 AS br ON br.GUID = JobOrder.Branch 
	 WHERE (Man.Guid = @FactoryGuid OR @FactoryGuid = 0x0)
	   AND (pl.Guid = @ProductionLine OR @ProductionLine = 0x0)
	   AND (mt.mtGUID = @MatGuid OR @MatGuid = 0x0)
	   AND (mt.grGUID = @GrGuid OR @GrGuid = 0x0)
	   AND (JobOrder.EndDate BETWEEN @StartDate AND @EndDate)
	   AND JobOrder.IsActive = 0
######################################################
CREATE PROCEDURE  RepGetJobOrderBills
		@JobOrder 					UNIQUEIDENTIFIER 
AS   
SET NOCOUNT ON    
	
DECLARE @InBillType			[UNIQUEIDENTIFIER]
DECLARE @OutBillType		[UNIQUEIDENTIFIER]
DECLARE @ReturnBillType		[UNIQUEIDENTIFIER]
DECLARE @TRANS_IN			[UNIQUEIDENTIFIER]
DECLARE @TRANS_OUT			[UNIQUEIDENTIFIER]


 SELECT @InBillType = FinishedGoodsBillType, 
		@OutBillType = MatRequestBillType, 
		@ReturnBillType = MatReturnBillType,
		@TRANS_OUT = OutTransBillType, 
		@TRANS_IN = InTransBillType
		FROM Manufactory000 Mu 
		INNER JOIN JobOrder000 Jo ON Mu.[Guid] = Jo.[ManufactoryGUID]
		WHERE Jo.[Guid] = @JobOrder

SELECT 
	Bu.Guid
	,Bu.Number
	,Bu.Date
	,CASE Bu.TypeGuid WHEN @OutBillType THEN 1 WHEN @ReturnBillType THEN 2 WHEN @TRANS_IN THEN 3 WHEN @TRANS_OUT THEN 4 ELSE 0 END BillType
	,SUM(Bi.Qty) Qty
	,Bu.Total
	,Bt.Guid TypeGuid
	,Bt.Name TypeName
	, (CASE  Bu.GUID WHEN Requestion.Bill THEN Requestion.Number WHEN Ret.Bill THEN Ret.Number WHEN SrcTrn.InBill THEN SrcTrn.Number WHEN DestTrn.OutBill THEN DestTrn.Number END) AS CardNumber
FROM JobOrder000 Jo
INNER JOIN Bu000 Bu ON Bu.CustAccGuid = Jo.Account
INNER JOIN Bt000 Bt ON Bt.Guid = Bu.TypeGuid
INNER JOIN Bi000 Bi ON Bu.Guid = Bi.ParentGuid
LEFT JOIN	DirectMatRequestion000 AS Requestion ON Requestion.JobOrder = Jo.Guid AND Requestion.Bill = Bu.GUID
LEFT JOIN	JocTrans000 AS SrcTrn ON SrcTrn.Src = Jo.Guid AND SrcTrn.InBill = Bu.GUID
LEFT JOIN	JocTrans000 AS DestTrn ON DestTrn.Dest = Jo.Guid AND DestTrn.OutBill = Bu.GUID
LEFT JOIN	DirectMatReturn000 AS Ret ON Ret.JobOrder = Jo.Guid AND Ret.Bill = Bu.GUID

WHERE Jo.Guid = @JobOrder
	AND Bu.TypeGuid <> @InBillType
GROUP BY
	Bu.Guid
	,Bu.Number
	,Bu.Date
	,Bu.TypeGuid
	,Bu.Total
	,Bt.Guid
	,Bt.Name
	,Requestion.Bill
	,Requestion.Number
	,Ret.Bill
	,Ret.Number
	,SrcTrn.InBill
	,SrcTrn.Number
	,DestTrn.OutBill
	,DestTrn.Number
######################################################
CREATE PROC prcJobOrderBillDelete
	@GUID [UNIQUEIDENTIFIER]
AS
/*
this procedure:
	- is responsible for deleting a bill
	- unposts before deleting
	- depends on triggers to do related cleaning
*/
	SET NOCOUNT ON
	-- unpost first:
	UPDATE [bu000] SET [IsPosted] = 0 FROM [bu000] WHERE [GUID] = @GUID

	-- delete bill:
	DELETE [bu000] WHERE [GUID] = @GUID
######################################################
Create  PROCEDURE prcGetJobOrderMaterialInfo
	@MatGUID [UNIQUEIDENTIFIER] = 0x0,
	@JobOrderGUID [UNIQUEIDENTIFIER] = 0x0,
	@bGroupStore [BIT] = 0,
	@bGroupExpireDate [BIT] = 0,
	@bGroupClass [BIT] = 0,
	@bCost [BIT] = 0,
	@StGUID [UNIQUEIDENTIFIER] = 0x0	
AS 
-----------------------------------------------
-- This procedure returns info about a material used in job order bills  
-----------------------------------------------
	SET NOCOUNT ON   
-----------------------------------------------
-- Creating temporary tables 
-----------------------------------------------
 
	CREATE TABLE [#Result]
	(
		[MatGUID] [UNIQUEIDENTIFIER],
		[StoreGUID] [UNIQUEIDENTIFIER],
		[ExpireDate] [DATETIME],
		[Class] [NVARCHAR](250) COLLATE ARABIC_CI_AI,
		[CostGUID] [UNIQUEIDENTIFIER],
		[MatQty] [FLOAT]
	)
  
    CREATE TABLE [#jobOrderBills]
	(
		Guid [UNIQUEIDENTIFIER],
		Number int,
		Date DATETIME,
		BillType int,	
		Qty float,
		Total float,
		TypeGuid [UNIQUEIDENTIFIER],
		TypeName NVARCHAR(250),
		CardNumber int
		
	)

	INSERT INTO [#jobOrderBills] EXEC RepGetJobOrderBills @JobOrderGUID


	INSERT INTO [#Result] 
		SELECT 
			biMatPtr, 
			CASE @bGroupStore 
				WHEN 1 THEN [b].[biStorePtr] END, 
			CASE @bGroupExpireDate 
				WHEN 1 THEN [b].[biExpireDate] END, 
			CASE @bGroupClass 
				WHEN 1 THEN [b].[biClassPtr] END, 
			CASE @bCost
				WHEN 1 THEN ISNULL( [b].[biCostPtr], 0x0)	END, 
			SUM(-1*buDirection *([b].[biQty] + [b].[biBonusQnt]) ) 

		FROM  [#jobOrderBills] JObills inner join [vwBuBi] [b] on JObills.Guid =[b].buGUID

		WHERE  
			(biMatPtr = @MatGUID)
			AND ([b].[buisposted] = 1) 
			AND (([b].[biStorePtr] = @StGUID) OR (@StGUID = 0x0)) 
		GROUP BY 
			biMatPtr, 
			CASE @bGroupStore 
				WHEN 1 THEN [b].[biStorePtr] END, 
			CASE @bGroupExpireDate 
				WHEN 1 THEN [b].[biExpireDate] END, 
			CASE @bGroupClass 
				WHEN 1 THEN [b].[biClassPtr] END, 
			CASE @bCost 
				WHEN 1 THEN ISNULL([b].[biCostPtr], 0x0) END 
			
	DECLARE @Lang INT 
	SET @Lang = (SELECT [dbo].[fnConnections_GetLanguage]())
		SELECT 
			ISNULL([r].[StoreGUID], 0x0) [StoreGUID], 
			ISNULL([st].[stCode], '') [StoreCode], 
			( CASE @Lang
				WHEN 0 THEN 
					CASE ISNULL([st].[stName], '')
						WHEN '' THEN ISNULL([st].[stLatinName], '')
						ELSE [st].[stName]
					END 	
				WHEN 1 THEN 
					CASE ISNULL([st].[stLatinName], '')
						WHEN '' THEN ISNULL([st].[stName], '')
						ELSE [st].[stLatinName]
					END 
				END 
			) [StoreName],
			CASE [Mt].ExpireFlag WHEN 1 THEN ISNULL([r].[ExpireDate], '')  END [ExpireDate], 
			ISNULL([r].[Class], '') [Class], 
			ISNULL([r].[CostGUID], 0x0) [CostGUID], 
			ISNULL([co].[coCode], '') [CostCode], 
			( CASE @Lang
				WHEN 0 THEN 
					CASE ISNULL([co].[coName], '')
						WHEN '' THEN ISNULL([co].[coLatinName], '')
						ELSE [co].[coName]
					END 
				WHEN 1 THEN 
					CASE ISNULL([co].[coLatinName], '')
						WHEN '' THEN ISNULL([co].[coName], '')
						ELSE [co].[coLatinName]
					END 
				END 
			) [CostName],
			[r].[MatQty] [MatQty]
		FROM
			[#Result] [r] 
			LEFT JOIN [vwst] [st] ON [r].[StoreGUID] = [st].[stGUID]
			LEFT JOIN [vwco] [co] ON [r].[CostGUID] = [co].[coGUID]
			INNER JOIN mt000 [Mt] on [Mt].GUID = [r].[MatGUID] 
		WHERE
			[r].[MatQty] <> 0
		ORDER BY 
			[ExpireDate], [Class], [MatQty], [StoreCode]
######################################################
CREATE PROCEDURE prcMatBOMInfo
	 @MatGuid     UNIQUEIDENTIFIER
AS
BEGIN
	
	SET NOCOUNT ON;

	if [dbo].[fnObjectExists]('JOCBOMFinishedGoods000') <>0  SELECT Guid  from JOCBOMFinishedGoods000 where MatPtr=@MatGuid
END
#########################################################
Create PROCEDURE prcGetBOMActiveJobOrdersFactories
(
   @BOMGuid UNIQUEIDENTIFIER
)
AS
Begin
    SET NOCOUNT ON
    
    SELECT  jo.ManufactoryGUID   
    FROM JOCBOM000 bom inner join JobOrder000 jo on bom.GUID  = @BOMGuid AND jo.FormGuid =  bom.GUID  
	End
#########################################################
CREATE PROCEDURE  prcGetJobOrderOutBillsCount
@JobOrder 	UNIQUEIDENTIFIER 
AS   
BEGIN

  SET NOCOUNT ON

  select (SELECT COUNT([GUID]) FROM DirectMatRequestion000 MaterialRequestion 
	WHERE MaterialRequestion.JobOrder = @JobOrder)
   +
  (SELECT COUNT([GUID])  FROM JocTrans000 JocTrans 
	WHERE JocTrans.Dest = @JobOrder ) AS OutBillCount

END 
#########################################################
CREATE PROCEDURE  GetRequestionMaterials
	@DirectMaterialRequestionGuid UNIQUEIDENTIFIER = 0X0
AS
	SET NOCOUNT ON;

	CREATE TABLE #CurrentRequestionCardData 
	(
		DirectMatRequestionGuid		UNIQUEIDENTIFIER
		,MaterialGuid				UNIQUEIDENTIFIER 
		,MaterialCode				NVARCHAR (255) COLLATE ARABIC_CI_AI   
		,MaterialName				NVARCHAR (255) COLLATE ARABIC_CI_AI  
		,MaterialLatinName			NVARCHAR (255) COLLATE ARABIC_CI_AI  
		,BOMRawMaterialQuantity		FLOAT
		,MaterialUnit				INT
		,MaterialUintName			NVARCHAR(100)
		,RequiredExpensedQty		FLOAT
		,NetQty						FLOAT
		,ExpiryDate					DATETIME
		,ExpiryFlag					BIT
		,ClassPtr					NVARCHAR(250)
	)

	CREATE TABLE #BomData --> Result
	(
		DirectMatRequestionGuid		UNIQUEIDENTIFIER
		,MaterialGuid				UNIQUEIDENTIFIER 
		,MaterialIndex				INT
		,MaterialCode				NVARCHAR (255) COLLATE ARABIC_CI_AI   
		,MaterialName				NVARCHAR (255) COLLATE ARABIC_CI_AI  
		,MaterialLatinName			NVARCHAR (255) COLLATE ARABIC_CI_AI  
		,MaterialUnit				INT
		,MaterialUintName			NVARCHAR(100)
		,BOMRawMaterialQuantity		FLOAT
		,JobOrderRequiredQty		FLOAT
		,RequiredExpensedQty		FLOAT
		,NetQty				FLOAT
		,ExpiryDate					DATETIME
		,ExpiryFlag					BIT
		,ClassPtr					NVARCHAR(250)
		,SNFlag						BIT
		,ForceInSN					BIT
		,ForceOutSN					BIT
	)

	--Get Current MatRequestion Bill Data
	INSERT INTO #CurrentRequestionCardData
	SELECT MatRequest.[Guid]
			  ,Mt.GUID	AS MaterialGuid
			  ,Mt.Code	AS MaterialCode
			  ,Mt.MatName	AS MaterialName
			  ,Mt.MatLatinName	AS MaterialLatinName
			  ,0
			  ,Bi.Unity
			  ,CASE WHEN Bi.Unity=1 THEN Mt.Unity WHEN Bi.Unity=2 THEN Mt.Unit2 WHEN Bi.Unity=3 THEN Mt.Unit3 ELSE '' END
			  ,ISNULL(Bi.Qty, 0) AS RequiredExpensedQty
			  ,0 NetQty 
			  ,Bi.[ExpireDate]	AS ExpiryDate
			  ,Mt.ExpireFlag	AS ExpiryFlag
			  ,Bi.ClassPtr	
		  FROM DirectMatRequestion000 MatRequest
		  INNER JOIN bu000 Bu ON MatRequest.Bill = Bu.[GUID]
		  INNER JOIN bi000 Bi ON Bi.[ParentGUID] = Bu.[GUID]
		  INNER JOIN JocVwMaterialsWithAlternatives Mt ON Bi.MatGUID = Mt.[GUID]
		 WHERE MatRequest.[Guid] = @DirectMaterialRequestionGuid
	
	--Getting JobOrder's Bill Of Material's Data
	INSERT INTO #BomData
	SELECT 
	0x0
	,Materials.[GUID]
	,BomMat.GridIndex
	,Materials.Code
	,Materials.MatName
	,Materials.MatLatinName
	,BomMat.Unit  
	,CASE WHEN  BomMat.Unit = 1 THEN Materials.Unity WHEN  BomMat.Unit = 2 THEN Materials.Unit2 WHEN  BomMat.Unit = 3 THEN Materials.Unit3 ELSE '' END
	,BomMat.RawMatQuantity
	,ISNULL(Jo.PlannedProductionQty * BomMat.RawMatQuantity / BomInst.ProductionQuantity, 0) --/ (dbo.JocFnGetMaterialFactorial(Materials.GUID, BomMat.Unit))  AS JobOrderRequiredQty
	,0
	,ISNULL(SUM(Bi.Qty * (CASE WHEN (Mu.MatRequestBillType = Bu.TypeGUID OR Mu.OutTransBillType = Bu.TypeGUID) THEN 1 
							WHEN (Mu.MatReturnBillType = Bu.TypeGUID OR Mu.InTransBillType = Bu.TypeGUID) THEN -1 
							ELSE 0 END)) 
						--/ (dbo.JocFnGetMaterialFactorial(Materials.GUID, BomMat.Unit))
	,0) 
	,CONVERT(DATETIME, '1-1-1980', 105)
	,Materials.ExpireFlag
	,''
	,Materials.SNFlag						
	,Materials.ForceInSN					
	,Materials.ForceOutSN					
	FROM JOCBOMRawMaterials000 BomMat 
	INNER JOIN JOCBOMInstance000 BomInst ON BomInst.[GUID] = BomMat.[JOCBOMGuid]
	INNER JOIN JocVwMaterialsWithAlternatives Materials ON Materials.[GUID] = BomMat.[MatPtr]
	INNER JOIN JobOrder000 Jo ON BomInst.JobOrderGuid = Jo.[Guid]
	iNNER JOIN Manufactory000 Mu ON Mu.Guid = Jo.ManufactoryGUID
	INNER JOIN DirectMatRequestion000 MatRequestion ON Jo.[Guid] = MatRequestion.[JobOrder]
	INNER JOIN bu000 Bu ON Bu.CustAccGUID = Jo.Account
	LEFT JOIN bi000 Bi ON Bi.ParentGUID = Bu.GUID AND Materials.[GUID] = Bi.MatGUID
	WHERE MatRequestion.[Guid] = @DirectMaterialRequestionGuid
	GROUP BY
		Materials.GUID
		,Materials.Code
		,Materials.MatName
		,Materials.MatLatinName
		,Materials.ExpireFlag	
		,Jo.PlannedProductionQty
		,BomMat.RawMatQuantity
		,BomInst.ProductionQuantity	
		,BomMat.GridIndex
		,Materials.SNFlag	
		,Materials.ForceInSN
		,Materials.ForceOutSN
		,BomMat.Unit
		,BomMat.GridIndex
		,Materials.Unity
		,Materials.Unit2
		,Materials.Unit3
	ORDER BY
		BomMat.GridIndex

	--Updating BOM's Data From the Bills that 
	UPDATE #BomData
	SET #BomData.DirectMatRequestionGuid = CurrentCard.DirectMatRequestionGuid
	,#BomData.ExpiryDate = CurrentCard.ExpiryDate
	,#BomData.ClassPtr = CurrentCard.ClassPtr
	,#BomData.MaterialUnit = CASE WHEN ISNULL(CurrentCard.MaterialUnit, 0) = 0 THEN #BomData.MaterialUnit ELSE CurrentCard.MaterialUnit END
	,#BomData.MaterialUintName = CASE WHEN ISNULL(CurrentCard.MaterialUnit, 0) = 0 THEN #BomData.MaterialUintName ELSE CurrentCard.MaterialUintName END
	,#BomData.RequiredExpensedQty = CurrentCard.RequiredExpensedQty / (dbo.JocFnGetMaterialFactorial(#BomData.MaterialGuid, CurrentCard.MaterialUnit))
	,#BomData.JobOrderRequiredQty = #BomData.JobOrderRequiredQty / (dbo.JocFnGetMaterialFactorial(#BomData.MaterialGuid, CurrentCard.MaterialUnit)) * (dbo.JocFnGetMaterialFactorial(#BomData.MaterialGuid, #BomData.MaterialUnit))
	FROM #CurrentRequestionCardData CurrentCard
	INNER JOIN #BomData ON #BomData.MaterialGuid = CurrentCard.MaterialGuid

	UPDATE #BomData
	SET
	#BomData.NetQty = #BomData.NetQty / (dbo.JocFnGetMaterialFactorial(#BomData.MaterialGuid, #BomData.MaterialUnit))

	SELECT * FROM #BomData

	DROP TABLE #CurrentRequestionCardData
	DROP TABLE #BomData
#########################################################

CREATE PROC prcGetDirectMatReturnData
	@DirectMatReturnGuid UNIQUEIDENTIFIER
AS
	SET NOCOUNT ON;
	CREATE TABLE #BillData 
	(
		[Guid]						UNIQUEIDENTIFIER
		,MaterialGuid				UNIQUEIDENTIFIER 
		,MaterialCode				NVARCHAR (255) COLLATE ARABIC_CI_AI   
		,MaterialName				NVARCHAR (255) COLLATE ARABIC_CI_AI  
		,MaterialLatinName			NVARCHAR (255) 
		,MaterialUnit				INT
		,MaterialUnitName			NVARCHAR(255)  
		,ExpensedQty				FLOAT
		,NetExchange				FLOAT
		,QtyToBeReturned			FLOAT
		,ExpiryDate					DATETIME
		,ExpiryFlag					BIT
		,ClassPtr					NVARCHAR(250)
	)
	CREATE TABLE #Result 
	(
		[Guid]						UNIQUEIDENTIFIER
		,MaterialGuid				UNIQUEIDENTIFIER 
		,MaterialIndex				INT
		,MaterialCode				NVARCHAR (255) COLLATE ARABIC_CI_AI   
		,MaterialName				NVARCHAR (255) COLLATE ARABIC_CI_AI  
		,MaterialLatinName			NVARCHAR (255)
		,MaterialUnit				INT
		,MaterialUnitName			NVARCHAR(255)  
		,ExpensedQty				FLOAT
		,NetExchange				FLOAT
		,QtyToBeReturned			FLOAT
		,ExpiryDate					DATETIME
		,ExpiryFlag					BIT
		,ClassPtr					NVARCHAR(250)
		,SNFlag						BIT
		,ForceInSN					BIT
		,ForceOutSN					BIT
	)
	
	INSERT INTO #BillData
	SELECT MatReturn.[Guid]
		  ,Mt.GUID	AS MaterialGuid
		  ,Mt.Code	AS MaterialCode
		  ,Mt.MatName	AS MaterialName
		  ,Mt.MatLatinName	AS MaterialLatinName
		  ,Bi.Unity
		  ,CASE WHEN Bi.Unity = 1 THEN Mt.Unity WHEN Bi.Unity = 2 THEN Mt.Unit2 WHEN Bi.Unity = 3 THEN Mt.Unit3 ELSE '' END
		  ,0 AS ExpensedQty
		  ,0 AS NetExchange
		  ,Bi.Qty AS QtyToBeReturned
		  ,Bi.[ExpireDate]	AS ExpiryDate
		  ,Mt.ExpireFlag	AS ExpiryFlag
		  ,Bi.ClassPtr	
	  FROM DirectMatReturn000 MatReturn
	  INNER JOIN bu000 Bu ON MatReturn.Bill = Bu.[GUID]
	  INNER JOIN bi000 Bi ON Bi.[ParentGUID] = Bu.[GUID]
	  INNER JOIN JocVwMaterialsWithAlternatives Mt ON Bi.MatGUID = Mt.[GUID]
	  WHERE MatReturn.[Guid] = @DirectMatReturnGuid

	  --Bom's Data
	  INSERT INTO #Result
	  SELECT
	   MatReturn.Guid AS Guid
	   ,Mt.GUID		AS MaterialGuid
	   ,BomMat.GridIndex
	   ,Mt.Code		AS MaterialCode	
	   ,Mt.MatName		AS MaterialName
	   ,Mt.MatLatinName	AS MaterialLatinName
	   ,BomMat.Unit
	   ,CASE WHEN BomMat.Unit = 1 THEN Mt.Unity WHEN BomMat.Unit = 2 THEN Mt.Unit2 WHEN BomMat.Unit = 3 THEN Mt.Unit3 ELSE '' END
	   ,ISNULL
	   ( 
		 SUM(Bi.Qty* CASE WHEN (BU.TypeGUID = Mu.MatRequestBillType OR Bu.TypeGUID = Mu.OutTransBillType) THEN 1 ELSE 0 END )
		  ,0
		) AS ExpensedQty
	   ,ISNULL
	   ( 
		 SUM(Bi.Qty* CASE WHEN (BU.TypeGUID = Mu.MatRequestBillType OR Bu.TypeGUID = Mu.OutTransBillType) THEN 1
						  WHEN (Bu.TypeGUID = Mu.MatReturnBillType OR Bu.TypeGUID = Mu.InTransBillType) THEN -1
						    ELSE 0 END ) ,0) 
			AS NetExchange
		,0 AS QtyToBeReturned
		,CONVERT(DATETIME, '1-1-1980', 105) AS ExpiryDate
		,Mt.ExpireFlag AS ExpiryFlag
		,'' AS ClassPtr
		,Mt.SNFlag AS SNFlag
		,Mt.ForceInSN AS ForceInSN
		,Mt.ForceOutSN AS ForceOutSN
	  FROM  DirectMatReturn000 MatReturn 
	  INNER JOIN JOCBOMInstance000 BomInst ON BomInst.JobOrderGuid = MatReturn.JobOrder
	  INNER JOIN JOCBOMRawMaterials000 BomMat ON BomMat.JOCBOMGuid = BomInst.GUID
	  INNER JOIN JocVwMaterialsWithAlternatives Mt ON BomMat.MatPtr = Mt.GUID
	  INNER JOIN JobOrder000 Jo ON Jo.Guid = MatReturn.JobOrder
	  INNER JOIN bu000 BU ON BU.CustAccGUID = Jo.Account
	  INNER JOIN Manufactory000 Mu ON MatReturn.Manufactory = Mu.Guid
	  LEFT JOIN bi000 Bi ON Bi.ParentGUID = BU.[GUID] AND Bi.MatGUID = Mt.GUID
	  WHERE MatReturn.Guid = @DirectMatReturnGuid
	  GROUP BY 
		Mt.GUID
		,Mt.Code
		,Mt.MatName
		,Mt.MatLatinName
		,Mt.ExpireFlag
		,MatReturn.Guid
		,BomMat.GridIndex
		,Mt.SNFlag
		,Mt.ForceInSN
		,Mt.ForceOutSN
		,BomMat.Unit
		,Mt.Unity
		,Mt.Unit2
		,Mt.Unit3
	ORDER BY
		BomMat.GridIndex

	UPDATE #Result 
		SET 
			#Result.ExpiryDate = #BillData.ExpiryDate
			,#Result.ClassPtr = #BillData.ClassPtr
			,#Result.MaterialUnit = CASE WHEN ISNULL(#BillData.MaterialUnit, 0) = 0 THEN #Result.MaterialUnit ELSE #BillData.MaterialUnit END
			,#Result.MaterialUnitName = CASE WHEN ISNULL(#BillData.MaterialUnit, 0) = 0 THEN #Result.MaterialUnitName ELSE #BillData.MaterialUnitName END
			,#Result.ExpensedQty = #Result.ExpensedQty / (dbo.JocFnGetMaterialFactorial(#Result.MaterialGuid, #BillData.MaterialUnit)) * (dbo.JocFnGetMaterialFactorial(#Result.MaterialGuid, #Result.MaterialUnit))
			,#Result.NetExchange = #Result.NetExchange / (dbo.JocFnGetMaterialFactorial(#Result.MaterialGuid, #BillData.MaterialUnit))
			,#Result.QtyToBeReturned = #BillData.QtyToBeReturned /(dbo.JocFnGetMaterialFactorial(#Result.MaterialGuid, #BillData.MaterialUnit))
		FROM #BillData
		INNER JOIN #Result ON #BillData.MaterialGuid = #Result.MaterialGuid
		

	SELECT * FROM #Result --WHERE #Result.QtyToBeReturned > 0

	DROP TABLE #BillData
	DROP TABLE #Result
#########################################################
CREATE Procedure prcBOMFactoriesAllocationBases
	@BOMGUID UNIQUEIDENTIFIER
AS
BEGIN

select m.MohAllocationBase  MohAllocationBase  
from Manufactory000  m inner Join ProductionLine000 pl            on  m.Guid = pl.ManufactoryGUID
                       inner join JOCBOMProductionLines000  BOMpl on  BOMpl.ProductionLineGuid = pl.Guid 
where BOMpl.JOCBOMGuid = @BOMGUID

END
#########################################################
CREATE PROCEDURE GetBOMInstanceProducedMatUnit 
		@OriginalBOMGuid UNIQUEIDENTIFIER,
		@JobOrderGuid UNIQUEIDENTIFIER 
AS  
BEGIN

SET NOCOUNT ON 

SELECT CASE ISNULL(bomIns.ProducedMatUnit,bom.ProducedMatUnit) WHEN 1 THEN mat.Unity WHEN 2  THEN mat.Unit2  WHEN 3  THEN mat.Unit3 END  UnitName 
 FROM  (select * from JOCBOM000 where  JOCBOM000.GUID = @OriginalBOMGuid ) bom LEFT JOIN 
       (select * from JOCBOMInstance000 where  JOCBOMInstance000.JobOrderGuid = @JobOrderGuid)  bomIns 
	         ON bom.GUID = bomIns.OriginalBOMGuid 
	    INNER JOIN mt000 mat  on bom.MatPtr = mat.GUID  

END
#########################################################
CREATE PROCEDURE prcGetMatStoreQtyForRequestion 
	@MatGUID [UNIQUEIDENTIFIER] = 0x0,
	@bGroupStore [BIT] = 0,
	@bGroupExpireDate [BIT] = 0,
	@bGroupClass [BIT] = 0,
	@bCost [BIT] = 0,
	@StGUID [UNIQUEIDENTIFIER] = 0x0	
AS 

	SET NOCOUNT ON   
 
	CREATE TABLE [#Result]
	(
		[MatGUID] [UNIQUEIDENTIFIER],
		[StoreGUID] [UNIQUEIDENTIFIER],
		[ExpireDate] [DATETIME],
		[Class] [NVARCHAR](250) COLLATE ARABIC_CI_AI,
		[CostGUID] [UNIQUEIDENTIFIER],
		[MatQty] [FLOAT]
	)
  
	 

	INSERT INTO [#Result] 
		SELECT 
			biMatPtr, 
			CASE @bGroupStore 
				WHEN 1 THEN [b].[biStorePtr] END, 
			CASE @bGroupExpireDate 
				WHEN 1 THEN [b].[biExpireDate] END, 
			CASE @bGroupClass 
				WHEN 1 THEN [b].[biClassPtr] END, 
			CASE @bCost
				WHEN 1 THEN ISNULL( [b].[biCostPtr], 0x0)	END, 
			SUM(buDirection *([b].[biQty] + [b].[biBonusQnt]) ) 
		FROM
			[vwBuBi] [b]
		WHERE  
			(biMatPtr = @MatGUID)
			AND ([b].[buisposted] = 1) 
			AND (([b].[biStorePtr] = @StGUID) OR (@StGUID = 0x0)) 
		GROUP BY 
			biMatPtr, 
			CASE @bGroupStore 
				WHEN 1 THEN [b].[biStorePtr] END, 
			CASE @bGroupExpireDate 
				WHEN 1 THEN [b].[biExpireDate] END, 
			CASE @bGroupClass 
				WHEN 1 THEN [b].[biClassPtr] END, 
			CASE @bCost 
				WHEN 1 THEN ISNULL([b].[biCostPtr], 0x0) END 
			
	DECLARE @Lang INT 
	SET @Lang = (SELECT [dbo].[fnConnections_GetLanguage]())

		SELECT 
			ISNULL([r].[StoreGUID], 0x0) [StoreGUID], 
			ISNULL([st].[stCode], '') [StoreCode], 
			( CASE @Lang
				WHEN 0 THEN 
					CASE ISNULL([st].[stName], '')
						WHEN '' THEN ISNULL([st].[stLatinName], '')
						ELSE [st].[stName]
					END 	
				WHEN 1 THEN 
					CASE ISNULL([st].[stLatinName], '')
						WHEN '' THEN ISNULL([st].[stName], '')
						ELSE [st].[stLatinName]
					END 
				END 
			) [StoreName],

			CASE [Mt].ExpireFlag WHEN 1 THEN ISNULL([r].[ExpireDate], '')  END [ExpireDate], 
			ISNULL([r].[Class], '') [Class], 
			ISNULL([r].[CostGUID], 0x0) [CostGUID], 
			ISNULL([co].[coCode], '') [CostCode], 
			( CASE @Lang
				WHEN 0 THEN 
					CASE ISNULL([co].[coName], '')
						WHEN '' THEN ISNULL([co].[coLatinName], '')
						ELSE [co].[coName]
					END 
				WHEN 1 THEN 
					CASE ISNULL([co].[coLatinName], '')
						WHEN '' THEN ISNULL([co].[coName], '')
						ELSE [co].[coLatinName]
					END 
				END 
			) [CostName],
			[r].[MatQty] [MatQty]
		FROM
			[#Result] [r] 
			LEFT JOIN [vwst] [st] ON [r].[StoreGUID] = [st].[stGUID]
			LEFT JOIN [vwco] [co] ON [r].[CostGUID] = [co].[coGUID]
			INNER JOIN mt000 [Mt] on [Mt].GUID = [r].[MatGUID] 
		ORDER BY 
			[ExpireDate], [Class], [MatQty], [StoreCode]
#########################################################
CREATE PROCEDURE  RepGetJobOrderFinishedGoodsBills
		@JobOrder 					UNIQUEIDENTIFIER 
AS   
SET NOCOUNT ON    
	
DECLARE @InBillType			[UNIQUEIDENTIFIER]

 SELECT @InBillType = FinishedGoodsBillType 
		FROM Manufactory000 Mu 
		INNER JOIN JobOrder000 Jo ON Mu.[Guid] = Jo.[ManufactoryGUID]
		WHERE Jo.[Guid] = @JobOrder

SELECT 
	 Bu.Guid
	,Bu.Number
	,Bu.Date
FROM JobOrder000 Jo
INNER JOIN Bu000 Bu ON Bu.CustAccGuid = Jo.Account
WHERE Jo.Guid = @JobOrder AND Bu.TypeGuid = @InBillType
ORDER BY Bu.Number
#########################################################
CREATE PROCEDURE GetMatQuantityForExpityDate
	@MatGUID		UNIQUEIDENTIFIER = 0x00,
	@ExpireDate		DATE
AS 
	SELECT SUM(buDirection *([b].[biQty] + [b].[biBonusQnt]) )  Qty
FROM
	[vwBuBi] [b]
WHERE  
	(biMatPtr = @MatGUID)
	AND ([b].[buisposted] = 1) 
	AND ([b].biExpireDate = @ExpireDate)
	GROUP BY 
	biMatPtr, 
	[b].[biExpireDate]
#########################################################
CREATE PROCEDURE GetMatQuantityForClass
	@MatGUID		UNIQUEIDENTIFIER = 0x00,
	@Class	        nvarchar(250)
AS 
SELECT SUM(buDirection *([b].[biQty] + [b].[biBonusQnt]) )  Qty
FROM [vwBuBi] [b]
WHERE  
	(biMatPtr = @MatGUID)
	AND ([b].[buisposted] = 1) 
	AND ([b].biClassPtr = @Class)
	GROUP BY 
	biMatPtr, 
	[b].[biClassPtr]
#########################################################
CREATE PROCEDURE GetJobOrdersProcessingLevels
     @CostProcessingLevel  [INT] = -1,
	 @FactoryGuid          [UNIQUEIDENTIFIER] = 0x0,
	 @ProdLineGuid         [UNIQUEIDENTIFIER] = 0x0,
	 @BOMGuid              [UNIQUEIDENTIFIER] = 0x0,
	 @StartDate		       [DATETIME],
	 @EndDate		       [DATETIME] 
AS
	SET NOCOUNT ON

	DECLARE @Lang [INT]
	SELECT @Lang =  dbo.fnConnections_GetLanguage()

	 SELECT  
			jo.Guid						   AS JobOrderGuid,
			BOMins.CostRank                AS CostProcessingLevel,
			Theortical.cost				   AS BOMCostProcessingLevel,
			jo.Name						   AS JobOrderName,
			CASE WHEN @Lang <> 0 AND mf.LatineName <> '' THEN mf.LatineName ELSE mf.Name END  AS ManufactoryName,
			CASE WHEN @Lang <> 0 AND pl.LatinName <> '' THEN pl.LatinName ELSE pl.Name END    AS ProductionLineName,
			CASE WHEN @Lang <> 0 AND BOM.LatinName <> '' THEN BOM.LatinName ELSE BOM.Name END AS BOMName,
			jo.StartDate AS JobOrderStartDate,
			jo.EndDate   AS JobOrderEndDate,
			jo.Number    AS JobOrderNumber,
			pl.Guid      AS ProductionLineGuid,
			BOM.GUID     AS BomGuid,
			mf.InsertNumber AS FactoryNumber
	 FROM  JobOrder000 jo 
	 INNER JOIN ProductionLine000 pl on jo.ProductionLine = pl.Guid 
	 INNER JOIN Manufactory000 mf on pl.ManufactoryGUID = mf.Guid
	 LEFT JOIN JOCJobOrderOperatingBOM000 BOMins on jo.OperatingBOMGuid = BOMins.Guid
	 LEFT JOIN JOCBOM000 BOM on BOMins.BOMGuid = BOM.GUID
	 INNER JOIN 
	 (	SELECT 
			MAX(CostRank) + 1 AS cost,
			RawMat.JOCBOMGuid
		FROM JOCOperatingBOMRawMaterials000 AS opRawCostRank 
		INNER JOIN JOCBOMRawMaterials000 AS RawMat ON RawMat.MatPtr = opRawCostRank.RawMaterialGuid
		GROUP BY RawMat.JOCBOMGuid
		) AS Theortical ON Theortical.JOCBOMGuid = bom.GUID 
	WHERE 
		(BOMins.CostRank = @CostProcessingLevel OR @CostProcessingLevel = -1)
	AND	(jo.IsActive = 0)	
	AND (mf.Guid = @FactoryGuid OR @FactoryGuid = 0x0)  
	AND (pl.Guid = @ProdLineGuid OR @ProdLineGuid = 0x0)   
	AND (BOM.GUID = @BOMGuid OR @BOMGuid = 0x0)  
	AND (jo.StartDate BETWEEN  @StartDate AND @EndDate)  

#########################################################
CREATE  Procedure GetProductionStagesDeviationAnalysis
     @ProducedMaterial AS [UNIQUEIDENTIFIER] = 0x0,
	 @FactoryGuid AS [UNIQUEIDENTIFIER] = 0x0,
	 @ProdLineGuid AS [UNIQUEIDENTIFIER] = 0x0,
	 @Unit AS int = 1,
	 @StartDate	[DATETIME] = '1/1/1980',
	 @EndDate	[DATETIME] = '1/1/2050'
AS
SET NOCOUNT ON

CREATE TABLE #StagesDeviation
	(
	 ManufactoryName     nvarchar(250),
	 ManufactoryLatinName     nvarchar(250),
	 ProductionLineName  nvarchar(250),
	 ProductionLineLatinName  nvarchar(250),
	 JobOrderGuid uniqueidentifier,
	 JobOrderStartDate datetime,
	 JobOrderNumber float,
	 BOMGuid uniqueidentifier,
	 ProducedMatGuid uniqueidentifier,
	 ProducedMatUnit int,
	 MainStageQty float,
	 ActualProductionQty float,
	 TotalDeviation float,
	 TotalSamplesQty float,
	 DeliveryDeviation float
	 )
	 
INSERT INTO #StagesDeviation 
	SELECT  mf.Name,mf.LatineName,pl.Name,pl.LatinName,
			jo.Guid JobOrderGuid, jo.StartDate,jo.Number,BOM.GUID BOMGuid,BOM.MatPtr ,BOM.ProducedMatUnit,0.0,0.0,0.0,0.0,0.0
	 FROM  JobOrder000 jo INNER JOIN ProductionLine000 pl on jo.ProductionLine = pl.Guid 
	                      INNER JOIN Manufactory000 mf on pl.ManufactoryGUID =mf.Guid
						  INNER JOIN JOCBOM000 BOM on BOM.GUID =jo.FormGuid
						--  INNER JOIN JOCBOMInstance000 BOMIns on BOMIns.JobOrderGuid = jo.Guid

	WHERE 
	    (mf.Guid = @FactoryGuid OR @FactoryGuid = 0x0)  
	AND (pl.Guid = @ProdLineGuid OR @ProdLineGuid = 0x0)   
	--AND (BOM.MatPtr = @ProducedMaterial OR @ProducedMaterial = 0x0)  
	AND (jo.StartDate>= @StartDate) 
	AND (jo.StartDate<= @EndDate)
	--AND BOMIns.StagesEnabled = 1
	
	Declare @factor int
	--alter table  #StagesDeviation add col1 int
	if @Unit = 1 or @Unit = 2 or @Unit =3 
	   set @factor = 1
    else
	   set @factor = 2

--update #StagesDeviation set ActualProductionQty = ISNULL((select Qty from JocFnGetActualProductionQty (JobOrderGuid,ProducedMatUnit)),0.0),    
--                            MainStageQty = ISNULL((select Qty from JocVwJobOrderStagesData data where data.StageType=0 and data.JobOrderGuid = #StagesDeviation.JobOrderGuid ),0.0)
--update #StagesDeviation set	TotalDeviation = MainStageQty-ActualProductionQty,
--	TotalSamplesQty =ISNULL((select sum(data.SampleQty) from JocVwJobOrderStagesData data where data.JobOrderGuid = #StagesDeviation.JobOrderGuid),0.0)



SELECT  ManufactoryName,ManufactoryLatinName,ProductionLineName,ProductionLineLatinName,JobOrderGuid,
        JobOrderStartDate,JobOrderNumber,BOMGuid,MainStageQty,ActualProductionQty,TotalDeviation,TotalSamplesQty,DeliveryDeviation 
		from #StagesDeviation 

SELECT Distinct StageGuid,StageName,StageLatineName, SerialOrder from JocVwJobOrderStagesData  where StageType >0 order by SerialOrder

SELECT * from JocVwJobOrderStagesData  order by jobOrderGuid,SerialOrder 
#########################################################
CREATE VIEW vwAlternativeMaterials
      AS  
         SELECT DISTINCT
				Mt.Guid
               ,Mt.Code
               ,Mt.Name
               ,Mt.LatinName
            FROM 
					AlternativeMatsItems000 Altmat INNER JOIN Mt000 mt ON Altmat.MatGuid = mt.Guid
######################################################
CREATE PROC prcUpdateFormsMxCostCenters
AS
UPDATE mx
SET mx.CostGUID = 0x0
FROM mx000 mx
JOIN MN000 mn ON mx.ParentGUID = mn.GUID AND mn.Type = 0

######################################################
#END
