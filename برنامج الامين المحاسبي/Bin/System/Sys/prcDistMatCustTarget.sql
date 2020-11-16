#######################################################################
CREATE PROCEDURE prcDistCalcMatCustTarget  
	@SrcGUID		UNIQUEIDENTIFIER,
	@PeriodGUID		UNIQUEIDENTIFIER,
	@PeriodLst		UNIQUEIDENTIFIER,
	@AccGUID		UNIQUEIDENTIFIER,
	@GroupGUID		UNIQUEIDENTIFIER,
	@MatGUID		UNIQUEIDENTIFIER,
	@UseUnit		INT, 
	@PricePolicy	INT, 
	@PriceType		INT,
	@CurGuid		UNIQUEIDENTIFIER, 
	@CurVal 		FLOAT, 
	@AddedPrcnt		FLOAT,  
	@ShowGroup		INT,
	@ShowMat		INT,
	@IgnorePriods	INT,
	@BranchGuid		UNIQUEIDENTIFIER = 0x0
	
AS 
--select * from #aa
	SET NOCOUNT ON
----------------------------------------------
DECLARE @PeriodStartDate DATETIME,  
		 	@StartDate 		 DATETIME, 
			@EndDate 		 DATETIME, 
			@CurrencyGUID 	 UNIQUEIDENTIFIER, 
			@brEnabled		 INT 
----------------------------------------------
DECLARE @EPDate DATETIME,
		@MounthCnt INT ,
		@LEVEL INT , 
		@MAXLevel INT
	SELECT @EPDate = GETDATE()
----------------------------------------------

	CREATE TABLE [#Periods] (GUID UNIQUEIDENTIFIER, startDate DATETIME, endDate DATETIME)
	INSERT INTO [#Periods] 
	SELECT p.GUID, p.StartDate, p.EndDate
	FROM vwPeriods AS p 
	INNER JOIN [RepSrcs]	AS [rCT]  ON [rCT].[IdType]  = p.GUID AND [rCT].[idTbl] = @PeriodLst

	CREATE TABLE [#Mats]	( [MatGuid] [UNIQUEIDENTIFIER], [mtSecurity] [INT])   
	INSERT INTO  [#Mats]		EXEC [prcGetMatsList] @MatGUID, @GroupGUID   

	CREATE TABLE #Custs		( GUID UNIQUEIDENTIFIER,  [custSecurity] [INT]) 
	INSERT INTO  #Custs		EXEC [prcGetCustsList] 0x0, @AccGUID

	DELETE #Custs 
	FROM #Custs AS cu INNER JOIN DistCe000 AS ce ON cu.GUID = ce.CustomerGUID AND ISNULL(ce.State, 0) = 1

	--------- Groups & Mats List 
	CREATE TABLE [#MatsList](  
		Guid			UNIQUEIDENTIFIER,  
		Code			NVARCHAR(255), 
		Name			NVARCHAR(255), 
		LatinName		NVARCHAR(255), 
		MatPrice		FLOAT,
		Unit			INT,
		UnitName		NVARCHAR(255), 
		UnitFact		FLOAT, 
		Security		INT,  
		Path			NVARCHAR(1000),  
		Level			INT,  
		ParentGuid		UNIQUEIDENTIFIER,
		Type			INT,    -- 1 For Mat 2 For Group 
	)   

	--------- Groups List 
		INSERT INTO #MatsList (Guid, Code, Name, LatinName, MatPrice, Unit, UnitName, UnitFact, Security, Path, Level, ParentGuid, Type) 
		SELECT DISTINCT  gr.Guid, gr.Code, gr.Name, gr.LatinName, 0, 1, '', 1, gr.Security, fn.Path, fn.Level, gr.ParentGuid , 2
		From fnGetGroupsOfGroupSorted(@GroupGuid, 1) AS fn 
		INNER JOIN gr000 as gr on gr.Guid = fn.Guid 
		INNER JOIN mt000 AS mts ON mts.GroupGuid = gr.GUID
		INNER JOIN [#Mats] AS mt ON mt.MatGuid = mts.GUID

	--------- Mats List 
		INSERT INTO #MatsList (Guid, Code, Name, LatinName, MatPrice, Unit, UnitName, UnitFact, Security, Path, Level, ParentGuid, Type) 
		SELECT  
			mt.Guid,  
			mt.Code,  
			mt.Name,  
			mt.LatinName,
			CASE @PriceType  
				WHEN  0x4   THEN whole 
				WHEN  0x8   THEN half 
				WHEN  0x10  THEN export 
				WHEN  0x20  THEN vendor 
				WHEN  0x40  THEN retail 
				WHEN  0x80  THEN enduser
		    END AS MatPrice, 
			Unit	 = CASE @UseUnit WHEN 3 THEN mt.DefUnit   
									 ELSE @UseUnit + 1 
						END,  
			UnitName = CASE @UseUnit WHEN 0 THEN mt.Unity  
									 WHEN 1 THEN CASE mt.Unit2Fact WHEN 0 THEN mt.Unity ELSE mt.Unit2 END  
									 WHEN 2 THEN CASE mt.Unit3Fact WHEN 0 THEN mt.Unity ELSE mt.Unit3 END  
									 ELSE CASE mt.DefUnit WHEN 1 THEN Unity WHEN 2 THEN Unit2 ELSE Unit3 END  
					   END, 
			UnitFact = CASE @UseUnit WHEN 0 THEN 1  
									 WHEN 1 THEN CASE mt.Unit2Fact WHEN 0 THEN 1 ELSE mt.Unit2Fact END  
									 WHEN 2 THEN CASE mt.Unit3Fact WHEN 0 THEN 1 ELSE mt.Unit3Fact END  
									 ELSE CASE mt.DefUnit WHEN 1 THEN 1 WHEN 2 THEN Unit2Fact ELSE Unit3Fact END  
					   END, 
			mtSecurity,  
			fn.Path /*+ '0.9999'*/,  
			fn.Level + 1 ,
			mt.GroupGuid,
			1	
		FROM  
			#Mats AS mt1 
			INNER JOIN mt000 AS mt ON mt1.MatGuid = mt.Guid 
			INNER JOIN fnGetGroupsOfGroupSorted(@GroupGuid, 1) AS fn ON fn.Guid = mt.GroupGuid 
			INNER JOIN gr000 AS gr ON fn.Guid = gr.guid

	CREATE TABLE #CustMatMonthSales(CustGUID UNIQUEIDENTIFIER, MatGUID UNIQUEIDENTIFIER, [PeriodGuid] UNIQUEIDENTIFIER, SalesQty FLOAT, Sales FLOAT, BranchGUID UNIQUEIDENTIFIER) 
	INSERT INTO #CustMatMonthSales 
	SELECT 
		cu.GUID, 
		mt.MatGUID, 
		p.GUID,
		Sum( /*CASE bi.btBillType WHEN 1 THEN bi.biQty  WHEN 3 THEN*/ (bi.biQty * (-1) * bi.buDirection)/* ELSE 0 END*/),
		Sum( /*CASE bi.btBillType WHEN 1 THEN bi.biQty * bi.biPrice WHEN 3 THEN */(bi.biQty * bi.biPrice * (-1) * bi.buDirection)/* ELSE 0 END*/), 
		CASE @brEnabled WHEN 1 THEN bi.buBranch ELSE 0x0 END 
	FROM 
		vwbubi /*vwExtended_bi*/ AS bi 
		INNER JOIN #Custs AS cu ON cu.GUID = bi.buCustPtr 
		INNER JOIN #Mats AS mt ON mt.MatGUID = bi.biMatPtr 
		INNER JOIN [#Periods] AS p ON bi.buDate BETWEEN p.startDate AND p.endDate
		INNER JOIN [RepSrcs]	AS [rCT]  ON [rCT].[IdType]  = bi.buType AND [rCT].[idTbl] = @SrcGuid
	WHERE 
		(bi.buBranch = @BranchGuid OR @BranchGuid = 0x0) 
	GROUP BY 
		cu.GUID, 
		mt.MatGUID, 
		p.GUID,
		CASE @brEnabled WHEN 1 THEN bi.buBranch ELSE 0x0 END	
------------------------------------------
		SET @MounthCnt = (SELECT  COUNT(DISTINCT CAST( Guid AS NVARCHAR(40)))FROM [#Periods])
------------------------------------------	
	CREATE TABLE #CustMatSales(CustGUID UNIQUEIDENTIFIER, MatGUID UNIQUEIDENTIFIER, GroupGUID UNIQUEIDENTIFIER, MnthCnt INT, SalesQty FLOAT, Sales FLOAT, mtPrice FLOAT, BranchGUID UNIQUEIDENTIFIER) 
	INSERT INTO #CustMatSales 
	SELECT CustGUID, MatGUID, mtl.ParentGuid, COUNT(DISTINCT CAST( periodGuid AS NVARCHAR(40))), SUM(SalesQty)  AS SalesQty ,SUM(Sales), mtl.MatPrice,BranchGUID
	FROM  #CustMatMonthSales AS cm /*INNER JOIN [dbo].[fnGetMtPricesWithSec] (@PriceType, @PricePolicy, @UseUnit, @CurGuid, @EPDate) AS m
	ON cm.MatGUID = m.mtGUID*/
	INNER JOIN #MatsList AS mtl ON mtl.GUID = cm.MatGUID
	GROUP BY CustGUID, MatGUID, mtl.ParentGuid, mtl.MatPrice, mtl.UnitFact,  BranchGUID
------------------------------------------
	CREATE TABLE #NewCusts (GUID  UNIQUEIDENTIFIER)
	INSERT INTO #NewCusts 
	SELECT DISTINCT cu.GUID
	FROM [#Custs] AS cu LEFT JOIN #CustMatSales AS cms ON cu.guid = cms.CustGUID 
	WHERE cms.CustGUID IS NULL
	
	CREATE TABLE #NewMats   (GUID  UNIQUEIDENTIFIER)
	INSERT INTO #NewMats   
	SELECT DISTINCT mtl.GUID
	FROM #MatsList AS mtl LEFT JOIN #CustMatSales AS cms ON mtl.Guid = cms.MatGUID
	WHERE cms.MatGUID IS NULL
	CREATE TABLE #NewGroups   (GUID  UNIQUEIDENTIFIER)
	
	
	CREATE TABLE #Results  (
			CustGUID		UNIQUEIDENTIFIER,
			CustName		NVARCHAR(255), 
			MatGuid			UNIQUEIDENTIFIER,  
			MatCode			NVARCHAR(255), 
			MatName			NVARCHAR(255), 
			MatLatinName	NVARCHAR(255),
			MatPrice		FLOAT, 
			grGUID			UNIQUEIDENTIFIER,
			grCode			NVARCHAR(255),
			grName			NVARCHAR(255), 
			grLatinName		NVARCHAR(255),
			Unit			INT, 
			UnitName		NVARCHAR(255), 
			UnitFact		FLOAT,
			SalesQty		FLOAT,
			SalesVal		FLOAT,
			MnthCnt			INT, 
			Security		INT,  
			Path			NVARCHAR(255),  
			Level			INT,
			ParentGuid		UNIQUEIDENTIFIER, 
		)



	IF @ShowGroup = 1
	BEGIN			
		INSERT INTO #Results
			SELECT cms.CustGUID, cu.CustomerName, 0x0, '', '', '', 0,mtl.GUID, mtl.Code, mtl.Name, mtl.LatinName, 1,'', 1,
				   SUM(cms.SalesQty), SUM(cms.Sales), MAX(cms.MnthCnt), mtl.Security, mtl.Path, mtl.Level, mtl.ParentGuid
			FROM #CustMatSales AS cms INNER JOIN #MatsList AS mtl ON cms.GroupGUID = mtl.GUID 
				 INNER JOIN cu000 AS cu on cu.GUID = cms.CustGUID
			GROUP BY cms.CustGUID, cu.CustomerName, mtl.GUID, mtl.Code, mtl.Name, mtl.LatinName, 
						mtl.Security, mtl.Path, mtl.Level , mtl.ParentGuid
		
		SELECT @Level = MAX(Level) FROM #MatsList
		SET @Level = @Level - 1		 
		SET @MaxLevel = @Level
		WHILE @Level >= 0 
		BEGIN
			INSERT INTO #Results
			SELECT r.CustGUID, cu.CustomerName, 0x0, '', '', '', 0, mtl.GUID, mtl.Code, mtl.Name, mtl.LatinName, 1, '', 1,
				   SUM(r.SalesQty), SUM(r.SalesVal), MAX( r.MnthCnt), mtl.Security, mtl.Path, mtl.Level, mtl.ParentGUID
			FROM #Results AS r INNER JOIN #MatsList AS mtl ON r.ParentGuid = mtl.GUID 
				 INNER JOIN cu000 AS cu on cu.GUID = r.CustGUID
			WHERE r.Level = @Level
			GROUP BY r.CustGUID, cu.CustomerName, mtl.GUID, mtl.Code, mtl.Name, mtl.LatinName, 
						mtl.Security, mtl.Path, mtl.Level , mtl.ParentGuid
			SET @Level = @Level -1
		END

		INSERT INTO #NewGroups
		SELECT DISTINCT mtl.GUID
		FROM #MatsList AS mtl LEFT JOIN #Results AS r ON mtl.GUID = r.grGUID
		WHERE r.grGUID IS NULL AND mtl.Type = 2
------------------------------
		INSERT INTO #Results
		SELECT DISTINCT c.CustGUID, c.CustName, m.MatGUID, m.MatCode, m.MatName, m.MatLatinName,ISNULL(m.MatPrice,0),
						m.grGUID, m.grCode, m.grName, m.grLatinName, m.Unit, m.UnitName, m.UnitFact,
						0, 0, 0, m.Security, m.Path, m.Level, m.ParentGuid
		FROM #Results AS c , #Results AS m
		WHERE 
			  m.grGUID NOT IN (SELECT grGUID FROM #Results WHERE CustGuid = c.CustGuid)
------------------------------
		INSERT INTO #Results
		SELECT DISTINCT c.GUID, cu.CustomerName, 0x0, '', '', '', 0, mtl.GUID, mtl.Code, mtl.Name, mtl.LatinName, 1, '', 1,
				   0, 0, 0, mtl.Security, mtl.Path, mtl.Level, mtl.ParentGUID
			FROM #NewGroups AS nm INNER JOIN #MatsList AS mtl ON nm.Guid = mtl.GUID
				  , [#Custs] AS c , cu000 AS cu 
			WHERE mtl.Type = 2 AND c.GUID = cu.GUID 
			
	END

	IF @ShowMat = 1
	BEGIN
		INSERT INTO #Results
		SELECT cms.CustGUID, cu.CustomerName, mtl.GUID, mtl.Code, mtl.Name, mtl.LatinName, mtl.MatPrice, gr.GUID, gr.Code, gr.Name, gr.LatinName,
			   mtl.Unit, mtl.UnitName, mtl.UnitFact, cms.SalesQty, cms.Sales, cms.MnthCnt, mtl.Security, mtl.Path, mtl.Level, mtl.ParentGuid
		FROM   #CustMatSales AS cms INNER JOIN #MatsList AS mtl ON cms.MatGUID = mtl.GUID	
									INNER JOIN gr000 AS gr ON gr.GUID = mtl.ParentGuid
									INNER JOIN cu000 AS cu on cu.GUID = cms.CustGUID
-----------------------------------
		INSERT INTO #Results
		SELECT DISTINCT c.CustGUID, c.CustName, m.MatGUID, m.MatCode, m.MatName, m.MatLatinName, m.MatPrice,
						m.grGUID, m.grCode, m.grName, m.grLatinName, m.Unit, m.UnitName, m.UnitFact,
						0, 0, 0, m.Security, m.Path, m.Level, m.ParentGuid
		FROM #Results AS c , #Results AS m
		WHERE 
			  m.MatGuid NOT IN (SELECT MatGuid FROM #Results WHERE CustGuid = c.CustGuid)

-----------------------------------
		INSERT INTO #Results
		SELECT DISTINCT c.GUID, cu.CustomerName, mtl.GUID, mtl.Code, mtl.Name, mtl.LatinName, mtl.MatPrice, gr.GUID, gr.Code, gr.Name, gr.LatinName,
				mtl.Unit, mtl.UnitName, mtl.UnitFact,0, 0, 0, mtl.Security, mtl.Path, mtl.Level, mtl.ParentGUID
			FROM #NewMats AS nm INNER JOIN #MatsList AS mtl ON nm.Guid = mtl.GUID
								INNER JOIN gr000 AS gr ON gr.GUID = mtl.ParentGuid
								/*INNER JOIN [dbo].[fnGetMtPricesWithSec] (@PriceType, @PricePolicy, @UseUnit, @CurGuid, @EPDate) AS m
								ON mtl.GUID = m.mtGUID*/
							    , [#Custs] AS c , cu000 AS cu
			WHERE mtl.Type = 1 AND c.GUID = cu.GUID

	END


	INSERT INTO #Results
	SELECT DISTINCT nc.GUID, cu.CustomerName, r.MatGuid, r.MatCode, r.MatName, r.MatLatinName, r.MatPrice, 
				    r.grGuid, r.grCode, r.grName, r.grLatinName, r.Unit, r.UnitName, r.UnitFact, 0, 0, 0,
					r.Security, r.Path, r.Level, r.ParentGuid
	FROM #NewCusts AS nc INNER JOIN cu000 AS cu ON nc.GUID = cu.GUID CROSS JOIN #Results AS r 
	

SELECT  DISTINCT CustGUID, CustName, MatGuid, MatCode, MatName, MatLatinName, MatPrice, 
				 grGUID , grCode, grName, grLatinName, Unit, UnitName, UnitFact,
				 SalesQty , SalesVal /*/ @CurVal*/ AS SalesVal, 
				 CASE @IgnorePriods WHEN 1 THEN 
					CASE MnthCnt WHEN 0 THEN 0 ELSE SalesQty / MnthCnt END 
				  ELSE 
					CASE @MounthCnt WHEN 0 THEN 0 ELSE SalesQty / @MounthCnt END
				  END AS AvgQty,
				 CASE @IgnorePriods WHEN 1 THEN 
					CASE MnthCnt WHEN 0 THEN 0 ELSE SalesVal  / MnthCnt END 
				  ELSE 
					CASE @MounthCnt WHEN 0 THEN 0 ELSE SalesVal / @MounthCnt END					
				  END AS AvgVal,
				  path
FROM #Results ORDER BY custGuid, grGuid, MatGuid
	
	
	
	
/*
EXEC   [prcCalcCustsMatsTargets] '33111fff-b61c-4b83-9e29-76925c235d4f', '4747ef23-4554-44bb-a4ab-30ef60d80e6e', 'e19ccafe-1ca5-44d3-9513-0e72d90dc71f', '25730057-6fc8-4498-bd41-7bd05320ffc7', '9fe0341c-ba7a-4d55-9c88-0b21ee83df66', '00000000-0000-0000-0000-000000000000', 1, 0, 128, '2433cf8c-6703-4206-92c0-bcf60ad28a72', 1.000000, 0.000000, 0, 1, 0
*/

#######################################################################
CREATE PROCEDURE prcDistGetMatCustTarget
	@PeriodGUID		UNIQUEIDENTIFIER,
	@MatGUID		UNIQUEIDENTIFIER,
	@GroupGUID		UNIQUEIDENTIFIER,
	@AccGUID		UNIQUEIDENTIFIER,
	@PriceType		INT,
	@UseUnit		INT,
	@ShowMats		INT = 0
AS

	SET NOCOUNT ON
	CREATE TABLE #cust (guid UNIQUEIDENTIFIER, Sec int)
	INSERT INTO  #cust  EXEC [prcGetCustsList] 0x0, @AccGUID
IF @ShowMats <> 0
 BEGIN
	CREATE TABLE #Mats (guid UNIQUEIDENTIFIER, Sec int)
	INSERT INTO  #Mats EXEC [prcGetMatsList] @MatGUID, @GroupGUID
	SELECT mct.CustGUID, cu.CustomerName AS CustName, gr.GUID AS grGuid, gr.Code AS grCode, gr.Name AS grName, gr.LatinName AS grLatinName,
		   mct.MatGUID, mt.Code AS MatCode, mt.Name AS MatName, mt.LatinName AS MatLatinName,
		   CASE @ShowMats WHEN 0 THEN 0 ELSE
		   CASE @PriceType  
			WHEN  0x4   THEN whole 
			WHEN  0x8   THEN half 
			WHEN  0x10  THEN export 
			WHEN  0x20  THEN vendor 
			WHEN  0x40  THEN retail 
			WHEN  0x80  THEN enduser
		   END 
		End AS MatPrice,
		Unit	 =  CASE @ShowMats WHEN 0 THEN 1 ELSE
					CASE @UseUnit WHEN 3 THEN mt.DefUnit   
									 ELSE @UseUnit + 1 
					END
				END,  
		UnitName = CASE @ShowMats WHEN 0 THEN '' ELSE
					CASE @UseUnit WHEN 0 THEN mt.Unity  
	       					   WHEN 1 THEN CASE mt.Unit2Fact WHEN 0 THEN mt.Unity ELSE mt.Unit2 END  
							   WHEN 2 THEN CASE mt.Unit3Fact WHEN 0 THEN mt.Unity ELSE mt.Unit3 END  
							   ELSE CASE mt.DefUnit WHEN 1 THEN Unity WHEN 2 THEN Unit2 ELSE Unit3 END  
					END
			     END, 
		 UnitFact = CASE @ShowMats WHEN 0 THEN 1 ELSE
					CASE @UseUnit WHEN 0 THEN 1  
							   WHEN 1 THEN CASE mt.Unit2Fact WHEN 0 THEN 1 ELSE mt.Unit2Fact END  
							   WHEN 2 THEN CASE mt.Unit3Fact WHEN 0 THEN 1 ELSE mt.Unit3Fact END  
							   ELSE CASE mt.DefUnit WHEN 1 THEN 1 WHEN 2 THEN Unit2Fact ELSE Unit3Fact END  
					END
				END, 
		mct.SalesQty, mct.SalesVal, mct.AvgQty, mct.AvgVal, mct.TargetQty , mct.TargetVal 
			   
	
	FROM DistMatCustTarget000 AS mct INNER JOIN mt000 AS mt ON mct.MatGuid = mt.Guid
		 INNER JOIN gr000 AS gr ON mct.GroupGuid = gr.Guid
		 INNER JOIN cu000 AS cu ON mct.CustGuid = cu.Guid
		 INNER JOIN fnGetGroupsOfGroupSorted(@GroupGuid, 1) AS fn ON mct.GroupGUID = fn.Guid
		 INNER JOIN #Mats AS m ON m.Guid = mct.MatGuid
	WHERE mct.PeriodGuid = @PeriodGuid --AND (mct.MatGUID = @MatGUID OR mct.GroupGUID = @GroupGUID) 
		  AND mct.CustGUID IN (SELECT GUID FROM #cust)
    ORDER BY mct.CustGUID, gr.Guid, mct.MatGuid
 END
 ELSE
  BEGIN
	CREATE TABLE #Groups (guid UNIQUEIDENTIFIER, Sec int)
    INSERT INTO  #Groups  EXEC [prcGetGroupsList] @GroupGUID

	SELECT mct.CustGUID, cu.CustomerName AS CustName, gr.GUID AS grGuid, gr.Code AS grCode, gr.Name AS grName, gr.LatinName AS grLatinName,
		   0x0 AS MatGUID, '' AS MatCode, '' AS MatName, '' AS MatLatinName, 0 AS MatPrice,1 AS Unit, '' AS	UnitName , 
		   1 AS UnitFact ,
		   mct.SalesQty, mct.SalesVal, mct.AvgQty, mct.AvgVal, mct.TargetQty , mct.TargetVal 
			   
	FROM DistMatCustTarget000 AS mct INNER JOIN gr000 AS gr ON mct.GroupGuid = gr.Guid
		 INNER JOIN cu000 AS cu ON mct.CustGuid = cu.Guid
		 INNER JOIN fnGetGroupsOfGroupSorted(@GroupGuid, 1) AS fn ON mct.GroupGUID = fn.Guid
		 INNER JOIN #Groups AS Grp ON Grp.Guid = mct.GroupGUID
	WHERE mct.PeriodGuid = @PeriodGuid --AND (mct.GroupGUID IN (SELECT GUID FROM #Groups)) 
		  AND mct.CustGUID IN (SELECT GUID FROM #cust)
		  AND (ISNULL(mct.MatGuid,0x0) = 0x0) 
    ORDER BY mct.CustGUID, gr.GUID, MatGuid
 END

#######################################################################
CREATE PROCEDURE prcDistDeleteMatCustTarget
	@PeriodGUID		UNIQUEIDENTIFIER,
	@MatGUID		UNIQUEIDENTIFIER,
	@GroupGUID		UNIQUEIDENTIFIER,
	@AccGUID		UNIQUEIDENTIFIER,
    @showMats		INT
AS 
	SET NOCOUNT ON
	CREATE TABLE #custs (guid UNIQUEIDENTIFIER, Sec int)
	INSERT INTO  #custs  EXEC [prcGetCustsList] 0x0, @AccGUID
    
    IF @showMats = 0
      BEGIN
		CREATE TABLE #Groups (guid UNIQUEIDENTIFIER, Sec int)
		INSERT INTO  #Groups  EXEC [prcGetGroupsList] @GroupGUID
		
		DELETE DistMatCustTarget000
		FROM DistMatCustTarget000 AS mct INNER JOIN #Groups AS gr ON mct.GroupGUID = gr.GUID
			 INNER JOIN #custs AS cu ON mct.CustGuid = cu.Guid
		WHERE PeriodGuid = @PeriodGuid AND (ISNULL(MatGuid, 0x0) = 0x0) 
      END
    ELSE 
	  BEGIN
		 CREATE TABLE #Mats (guid UNIQUEIDENTIFIER, Sec int)
		 INSERT INTO  #Mats EXEC [prcGetMatsList] @MatGUID, @GroupGUID 

		 DELETE DistMatCustTarget000
		 FROM DistMatCustTarget000 AS mct INNER JOIN #Mats AS m ON mct.MatGUID = m.GUID
			 INNER JOIN #custs AS cu ON mct.CustGuid = cu.Guid
		WHERE PeriodGuid = @PeriodGuid /*AND (ISNULL(MatGuid, 0x0) = 0x0)
		 WHERE PeriodGuid = @PeriodGuid AND (MatGuid = @MatGUID) AND (GroupGUID = @GroupGUID) 
		  AND CustGUID IN (SELECT GUID FROM #custs)  */ 
      END

#######################################################################