##################################################################################
CREATE PROCEDURE repDistCustStock
	@StartDate			[DATETIME],
	@EndDate			[DATETIME],
	@HiGuid				[UNIQUEIDENTIFIER],       
	@DistGuid			[UNIQUEIDENTIFIER],       
	@CustAccGuid		[UNIQUEIDENTIFIER],       
	@CustsCT			[UNIQUEIDENTIFIER],      
	@CustsTCH			[UNIQUEIDENTIFIER],      
	@MatGuid			[UNIQUEIDENTIFIER],      
	@GroupGuid			[UNIQUEIDENTIFIER],
	@UseUnit			[INT],
	@ShowGroups			[BIT],
	@ShowMats			[BIT]
AS
	SET NOCOUNT ON
	------ 
	CREATE TABLE [#SecViol]([Type] [INT], [Cnt] [INTEGER]) 
	-------------------------------------------------------------------------------------      
	------ Custs List For This Report --------------------------------------------------- 
	CREATE TABLE [#Custs]   ( [GUID] [UNIQUEIDENTIFIER], [Security] [INT])          
	INSERT INTO  [#Custs]	EXEC prcGetDistGustsList @DistGuid, @CustAccGuid, 0x00, @HiGuid   
	----- 
	DELETE #Custs WHERE GUID NOT IN 
	(
		SELECT cu.Guid FROM #Custs AS cu 
		LEFT JOIN  [DistCe000] 	AS [Dc]   ON [Dc].[CustomerGuid] = [cu].[Guid]    
		INNER JOIN [RepSrcs]	AS [rCT]  ON [rCT].[IdType]  = ISNULL([Dc].[CustomerTypeGuid], 0x00) AND [rCT].[idTbl] = @CustsCT 
		INNER JOIN [RepSrcs]	AS [rTCH] ON [rTCH].[IdType] = ISNULL([Dc].[TradeChannelGuid], 0x00) AND [rTCH].[idTbl] = @CustsTCH 
	)
	-----------------------------------------------------------------------------------  
	------ Mats List For This Report --------------------------------------------------- 
	CREATE TABLE [#Mats]	( [MatGuid] [UNIQUEIDENTIFIER], [mtSecurity] [INT])  
	INSERT INTO [#Mats]		EXEC [prcGetMatsList] @MatGUID, @GroupGUID  
	--------- Groups & Mats List
	CREATE TABLE [#MatsList]( 
		Guid			UNIQUEIDENTIFIER, 
		Code			NVARCHAR(255),
		Name			NVARCHAR(255),
		LatinName		NVARCHAR(255),
		UnitName		NVARCHAR(255),
		UnitFact		FLOAT,
		Security		INT, 
		Path			NVARCHAR(1000), 
		Level			INT, 
		ParentGuid		UNIQUEIDENTIFIER,
	)  
	--------- Groups List
	INSERT INTO #MatsList (Guid, Code, Name, LatinName, UnitName, UnitFact, Security, Path, Level, ParentGuid)
	SELECT gr.Guid, gr.Code, gr.Name, gr.LatinName, '', 1, gr.Security, fn.Path, fn.Level, gr.ParentGuid From fnGetGroupsOfGroupSorted(@GroupGuid, 1) AS fn INNER JOIN gr000 as gr on gr.Guid = fn.Guid
	--------- Mats List
	INSERT INTO #MatsList (Guid, Code, Name, LatinName, UnitName, UnitFact, Security, Path, Level, ParentGuid)
	SELECT 
		mt.Guid, 
		mt.Code, 
		mt.Name, 
		mt.LatinName,
		UnitName = CASE @UseUnit WHEN 0 THEN mt.Unity 
								 WHEN 1 THEN CASE mt.Unit2Fact WHEN 0 THEN mt.Unity ELSE mt.Unit2 END 
								 WHEN 2 THEN CASE mt.Unit3Fact WHEN 0 THEN mt.Unity ELSE mt.Unit3 END 
								 WHEN 3 THEN CASE mt.DefUnit WHEN 1 THEN Unity WHEN 2 THEN Unit2 ELSE Unit3 END 
								 WHEN 4 THEN mt.Unity 
				   END,
		UnitFact = CASE @UseUnit WHEN 0 THEN 1 
								 WHEN 1 THEN CASE mt.Unit2Fact WHEN 0 THEN 1 ELSE mt.Unit2Fact END 
								 WHEN 2 THEN CASE mt.Unit3Fact WHEN 0 THEN 1 ELSE mt.Unit3Fact END 
								 WHEN 3 THEN CASE mt.DefUnit WHEN 1 THEN 1 WHEN 2 THEN Unit2Fact ELSE Unit3Fact END 
								 WHEN 4 THEN 1
				   END,
		mtSecurity, 
		mtl.Path + '0.9999', 
		mtl.Level + 1, 
		mt.GroupGuid
	FROM 
		#Mats AS mt1
		INNER JOIN mt000 AS mt ON mt1.MatGuid = mt.Guid
		INNER JOIN #MatsList AS mtl ON mtl.Guid = mt.GroupGuid
	-----------------------------------------------------------------------------------  
	----- Last Cust Stock Date
	CREATE TABLE #LastCustVisits(CustGuid UNIQUEIDENTIFIER, MatGuid UNIQUEIDENTIFIER, VisitDate DATETIME) 
	INSERT INTO #LastCustVisits(CustGuid, MatGuid, VisitDate) 
	SELECT CustomerGuid, MatGuid, Max([Date]) FROM DistCm000 WHERE Date BETWEEN @StartDate AND @EndDate GROUP BY CustomerGuid, MatGuid
	-------------------------------------------------------------------------------------
	------------ CustStockDetail
	CREATE TABLE #CustStockDetails(
		CustGuid		UNIQUEIDENTIFIER,
		MatGuid			UNIQUEIDENTIFIER,
		VisitDate		DATETIME,
		CustStock		FLOAT,
		CustSales		FLOAT,
		Consume			FLOAT,	-- Old(CustStock+CustSales) - New(CustStock)	«·„Œ“Ê‰ «·„” Â·ﬂ
		DaysNum			INT,	-- New(VisitDate) - Old(VisitDate)				⁄œœ «·√Ì«„
		DayAvgConsume	FLOAT,	-- Consume / DayAvgConsume						„⁄œ· «·«” Â·«ﬂ «·ÌÊ„Ì
		Type			INT,		-- 1 Last Cust Stock   -- 2 Old Cust Stock To Calc Avg Consumption 
		Unity			INT
	)

	DECLARE	@OldCustGuid	UNIQUEIDENTIFIER,
			@OldMatGuid		UNIQUEIDENTIFIER,
			@OldVisitDate	DATETIME,
			@OldStock		FLOAT,
			@OldSales		FLOAT,
			@Consume		FLOAT,
			@DaysNum		FLOAT,	
			@DaysAvgConsume	FLOAT
	SET @OldCustGuid = 0x00
	SET @OldMatGuid = 0x00
	SET @OldVisitDate = '01-01-1980'

	DECLARE @C			CURSOR,			 
			@CCustGuid	UNIQUEIDENTIFIER,
			@CMatGuid	UNIQUEIDENTIFIER,
			@CVisitDate	DATETIME,
			@CStock		FLOAT,
			@CSales		FLOAT,
			@CType		INT,
			@Unity		INT
			
	SET @C = CURSOR FAST_FORWARD FOR
		SELECT cm.CustomerGuid, cm.MatGuid, cm.Date, cm.Qty, cm.Target, CASE cm.Date WHEN lv.VisitDate THEN 1 ELSE 2 END, cm.Unity
		FROM 
			DistCm000 AS cm 
			INNER JOIN #LastCustVisits AS lv ON lv.CustGuid = cm.CustomerGuid AND lv.MatGuid = cm.MatGuid -- AND cm.Date > DATEADD(d, -90, lv.VisitDate) AND cm.Date <= lv.VisitDate 
			INNER JOIN #Custs	AS cu ON cu.Guid = cm.CustomerGuid
			INNER JOIN #Mats		AS mt ON mt.MatGuid = cm.MatGuid
		WHERE cm.Date BETWEEN @StartDate AND @EndDate --WHERE cm.Date > DATEADD(d, -90, lv.VisitDate) AND cm.Date <= lv.VisitDate 
		ORDER BY cm.CustomerGuid, cm.MatGuid, cm.Date
	OPEN @C FETCH FROM @C INTO @CCustGuid, @CMatGuid, @CVisitDate, @CStock, @CSales, @CType, @Unity
	WHILE @@FETCH_STATUS = 0
	BEGIN
		IF (@OldCustGuid <> @CCustGuid OR @OldMatGuid <> @CMatGuid)
		BEGIN
			SET @Consume = 0;
			SET @DaysNum = 0;
			SET @DaysAvgConsume = 0;
			IF @OldCustGuid <> @CCustGuid	SET @OldCustGuid = @CCustGuid
			IF @OldMatGuid <> @CMatGuid		SET @OldMatGuid = @CMatGuid
		END
		ELSE IF (@OldCustGuid = @CCustGuid AND @OldMatGuid = @CMatGuid)
		BEGIN
			SET @Consume = @OldStock + @OldSales - @CStock
			SET @DaysNum = DATEDIFF(d, @OldVisitDate, @CVisitDate)	
			IF @DaysNum = 0 SET @DaysAvgConsume = @Consume ELSE SET @DaysAvgConsume = @Consume / @DaysNum
		END
		SET @OldStock = @CStock
		SET @OldSales = @CSales
		SET @OldVisitDate = @CVisitDate

		INSERT INTO #CustStockDetails( CustGuid, MatGuid, VisitDate, CustStock, CustSales, Consume, DaysNum, DayAvgConsume, Type, Unity)
		VALUES ( @CCustGuid, @CMatGuid, @CVisitDate, @CStock,  @CSales, @Consume, @DaysNum, @DaysAvgConsume, @CType, @Unity) 

		FETCH FROM @C INTO @CCustGuid, @CMatGuid, @CVisitDate, @CStock, @CSales, @CType ,@Unity
	END
	CLOSE @C DEALLOCATE @C
	-------------------------------------------------------------------------------------
	------------ CustStockTotals
	CREATE TABLE #CustStockTotals(
		CustGuid			UNIQUEIDENTIFIER,
		MatGuid				UNIQUEIDENTIFIER,
		VisitDate			DATETIME,
		LastStock			FLOAT,
		DayAvgConsume		FLOAT,		-- „⁄œ· «·«” Â·«ﬂ «·ÌÊ„Ì
		LastStockDays		FLOAT,		-- ¬Œ— „Œ“Ê‰ Ìﬂ›Ì ·„œ… øø ÌÊ„
		ExpectedStock		FLOAT,		-- «·„Œ“Ê‰ «·„ Êﬁ⁄
		ExpectedStockDays	FLOAT,		-- «·„Œ“Ê‰ «·„ Êﬁ⁄ Ìﬂ›Ì ·„œ… øø ÌÊ„
		Unity				INT
	)
	INSERT INTO #CustStockTotals( 
		CustGuid, 
		MatGuid, 
		VisitDate, 
		LastStock, 
		DayAvgConsume, 
		LastStockDays, 
		ExpectedStock, 
		ExpectedStockDays,
		Unity
	) 
	SELECT 
		CustGuid,
		MatGuid,
		VisitDate,
		(CustStock+CustSales),
		0,0,0,0,
		Unity
	FROM
		#CustStockDetails 
	WHERE 
		Type = 1
  
	UPDATE #CustStockTotals 
		SET DayAvgConsume		= csd.DayAvgConsume,
			LastStockDays		= CASE csd.DayAvgConsume  WHEN 0 THEN 0 ELSE LastStock /csd.DayAvgConsume END,
			ExpectedStock		= CASE LastStock WHEN 0 THEN 0 ELSE LastStock - (DATEDIFF(d, cst.VisitDate, @EndDate) * csd.DayAvgConsume) END,
			ExpectedStockDays	= CASE LastStock WHEN 0 THEN 0 ELSE 
										CASE csd.DayAvgConsume  WHEN 0 THEN 0 ELSE (LastStock - (DATEDIFF(d, cst.VisitDate, @EndDate) * csd.DayAvgConsume)) /csd.DayAvgConsume END
								  END	
	FROM #CustStockTotals AS cst
		INNER JOIN (SELECT CustGuid, MatGuid, SUM(DayAvgConsume) / CASE (COUNT(DayAvgConsume)-1) WHEN 0 THEN 1 ELSE (COUNT(DayAvgConsume)-1) END AS DayAvgConsume
					FROM #CustStockDetails
					GROUP By CustGuid, MatGuid
					) AS csd ON csd.CustGuid = cst.CustGuid AND csd.MatGuid = cst.MatGuid
	------------------------------------------------------------------------------------------
	-------------------- End Results 
	CREATE TABLE #Result(
		CustGuid			UNIQUEIDENTIFIER,
		CustName			NVARCHAR(255),
		CustLatinName		NVARCHAR(255),
		ParentGuid			UNIQUEIDENTIFIER,
		Guid				UNIQUEIDENTIFIER,
		Code				NVARCHAR(255),
		Name				NVARCHAR(255),
		LatinName			NVARCHAR(255),
		UnitName			NVARCHAR(100),
		VisitDate			DATETIME,
		LastStock			FLOAT,
		DayAvgConsume		FLOAT,		-- „⁄œ· «·«” Â·«ﬂ «·ÌÊ„Ì
		LastStockDays		FLOAT,		-- ¬Œ— „Œ“Ê‰ Ìﬂ›Ì ·„œ… øø ÌÊ„
		ExpectedStock		FLOAT,		-- «·„Œ“Ê‰ «·„ Êﬁ⁄
		ExpectedStockDays	FLOAT,		-- «·„Œ“Ê‰ «·„ Êﬁ⁄ Ìﬂ›Ì ·„œ… øø ÌÊ„
		Path				NVARCHAR(1000),
		Type				INT		-- 2 Mats  1 Groups
	)	
	DECLARE @MaxLevel	AS INT
	SELECT @MaxLevel = MAX(Level) FROM #MatsList
	---------- Results For Mats
	IF @UseUnit <> 4
	BEGIN
		INSERT INTO #Result( CustGuid, CustName, CustLatinName, ParentGuid, Guid, Code, Name, LatinName, UnitName, VisitDate, LastStock, DayAvgConsume, LastStockDays, ExpectedStock, ExpectedStockDays, Path, Type	)
		SELECT 
			cst.CustGuid,
			cu.CustomerName,
			cu.LatinName,
			mt.ParentGuid,
			cst.MatGuid,
			mt.Code,
			mt.Name,
			mt.LatinName,
			mt.UnitName,
			cst.VisitDate,
			SUM(LastStock / mt.UnitFact),
			DayAvgConsume, 
			SUM(LastStockDays), 
			SUM(ExpectedStock  / mt.UnitFact), 
			SUM(ExpectedStockDays),
			mt.Path,
			2	-- Mats Result
		FROM
			#CustStockTotals	AS cst
			INNER JOIN cu000 AS cu ON cu.Guid = cst.CustGuid
			INNER JOIN #MatsList AS mt ON mt.Guid = cst.MatGuid
			GROUP BY 
			cst.CustGuid,
			cu.CustomerName,
			cu.LatinName,
			mt.ParentGuid,
			cst.MatGuid,
			mt.Code,
			mt.Name,
			mt.LatinName,
			mt.UnitName,
			cst.VisitDate,
			DayAvgConsume, 
			mt.Path
			
		END
		ELSE
		BEGIN
			INSERT INTO #Result( CustGuid, CustName, CustLatinName, ParentGuid, Guid, Code, Name, LatinName, UnitName, VisitDate, LastStock, DayAvgConsume, LastStockDays, ExpectedStock, ExpectedStockDays, Path, Type	)
			SELECT 
				cst.CustGuid,
				cu.CustomerName,
				cu.LatinName,
				mt.ParentGuid,
				cst.MatGuid,
				mt.Code,
				mt.Name,
				mt.LatinName,
				CASE cst.Unity WHEN 1 THEN m.Unity WHEN 2 THEN CASE m.Unit2Fact WHEN 0 THEN m.Unity ELSE m.Unit2 END WHEN 3 THEN CASE m.Unit3Fact WHEN 0 THEN m.Unity ELSE m.Unit3 END END,
				cst.VisitDate,
				LastStock / CASE cst.Unity WHEN 1 THEN 1 WHEN 2 THEN CASE m.Unit2Fact WHEN 0 THEN 1 ELSE m.Unit2Fact END WHEN 3 THEN CASE m.Unit3Fact WHEN 0 THEN 1 ELSE m.Unit3Fact END END, 
				DayAvgConsume, 
				LastStockDays, 
				ExpectedStock  / CASE cst.Unity WHEN 1 THEN 1 WHEN 2 THEN CASE m.Unit2Fact WHEN 0 THEN 1 ELSE m.Unit2Fact END WHEN 3 THEN CASE m.Unit3Fact WHEN 0 THEN 1 ELSE m.Unit3Fact END END, 
				ExpectedStockDays,
				mt.Path,
				2	-- Mats Result
			FROM
				#CustStockTotals	AS cst
				INNER JOIN cu000 AS cu ON cu.Guid = cst.CustGuid
				INNER JOIN #MatsList AS mt ON mt.Guid = cst.MatGuid
				INNER JOIN mt000 AS m ON m.GUID = cst.MatGuid
		END
	---------- Results For Groups
	WHILE (@MaxLevel >= 0) AND (@ShowGroups = 1)
	BEGIN
		INSERT INTO #Result( CustGuid, CustName, CustLatinName, ParentGuid, Guid, Code, Name, LatinName, UnitName, VisitDate, LastStock, DayAvgConsume, LastStockDays, ExpectedStock, ExpectedStockDays, Path, Type	)
		SELECT 
			r.CustGuid,
			r.CustName,
			r.CustLatinName,
			gr.ParentGuid,
			gr.Guid,
			gr.Code,
			gr.Name,
			gr.LatinName,
			'', 	
			'01-01-1980',
			SUM(LastStock), 
			Avg(DayAvgConsume), 
			AVG(LastStockDays), 
			SUM(ExpectedStock), 
			CASE @UseUnit WHEN 4 THEN SUM(ExpectedStock) * gr.UnitFact /Avg(DayAvgConsume) ELSE AVG(ExpectedStockDays) END,
			gr.Path,
			1	-- Groups Result
		FROM
			#Result	AS r
			INNER JOIN #MatsList	AS gr ON gr.Guid = r.ParentGuid	
		WHERE gr.Level = @MaxLevel
		GROUP BY
			r.CustGuid, r.CustName, r.CustLatinName, gr.ParentGuid, gr.Guid, gr.Code, gr.Name, gr.LatinName ,gr.UnitFact , gr.Path

		SET @MaxLevel = @MaxLevel - 1
	END
	--------------------------------------------------------------
	--------------- REPORT RESULTS 
	SELECT 
		CustGuid, CustName, CustLatinName, Guid, Code, Name, LatinName, UnitName, VisitDate, LastStock, DayAvgConsume, LastStockDays, ExpectedStock, ExpectedStockDays, Type			 
	FROM 
		#Result 
	WHERE 
		(@ShowMats = 1 AND Type = 2) OR (@ShowGroups = 1 AND Type = 1)
	ORDER BY 
		CustGuid, Path, Name
	-----------------
	SELECT * FROM [#SecViol]
	--------------------------------------------------------------

/*
EXEC repDistCustStock '07-01-2008', '08-01-2008', 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 3, 1, 1

*/
#############################
#END 