#######################################################################
CREATE PROCEDURE prcCalcCustsTargets
	@PeriodGUID		UNIQUEIDENTIFIER, 
	@UseUnit		INT, 
	@RepType		INT, 
	@ShowEmptyMat	INT = 1, 
	@MatGroup		UNIQUEIDENTIFIER = 0x0, 
	@BranchGuid		UNIQUEIDENTIFIER = 0x0, 
	@PeriodsSrc		UNIQUEIDENTIFIER = 0x0 
AS     
	SET NOCOUNT ON  
	DECLARE @PeriodStartDate DATETIME,  
		 	@StartDate 		 DATETIME,  
			@EndDate 		 DATETIME,  
			@CurrencyGUID 	 UNIQUEIDENTIFIER,  
			@brEnabled		 INT, 
			@BranchMask		 BIGINT 
	SELECT @PeriodStartDate = StartDate FROM vwPeriods WHERE GUID = @PeriodGUID  
	SELECT @EndDate   = DATEADD(day, -1, @PeriodStartDate)  
	SELECT @StartDate = DATEADD(month, -6, @EndDate)  
	SELECT @CurrencyGUID = GUID From my000 WHERE Number = 1  
	SET @brEnabled = [dbo].[fnOption_get]('EnableBranches', '1')  
	CREATE TABLE #MatTbl	( GUID UNIQUEIDENTIFIER)    
	CREATE TABLE #CustTbl	( GUID UNIQUEIDENTIFIER, TradeChannelGUID UNIQUEIDENTIFIER, CustomerTypeGUID UNIQUEIDENTIFIER, DistGUID UNIQUEIDENTIFIER)    
	 
	SELECT @BranchMask = brBranchMask FROM vwbr WHERE brGuid = @BranchGuid 
	INSERT INTO #CustTbl     
	SELECT DISTINCT    
		cu.cuGUID,    
		ISNULL(ce.TradeChannelGUID, 0x0),    
		ISNULL(ce.CustomerTypeGUID, 0x0),    
		0x00    
	FROM     
		vwCu AS cu 
		INNER JOIN vwac AS ac ON ac.acGuid = cu.cuAccount 
		LEFT JOIN DistCe000 AS ce ON cu.cuGUID = ce.CustomerGUID     
	WHERE     
		ISNULL(ce.State, 0) <> 1 
		AND ((acBranchMask & @BranchMask <> 0 AND @brEnabled = 1) OR 
			(@brEnabled <> 1)) 
	INSERT INTO #MatTbl     
	SELECT     
		mt.mtGUID    
	FROM     
		vwMt AS mt    
	Where	(brBranchMask & @BranchMask <> 0 AND @brEnabled = 1) OR 
			(@brEnabled <> 1) 
	CREATE TABLE #CustMatMonthSales(CustGUID UNIQUEIDENTIFIER, MatGUID UNIQUEIDENTIFIER, [Month] INT, SalesQty FLOAT, BranchGUID UNIQUEIDENTIFIER)    
	CREATE TABLE #PeriodsTbl (GUID UNIQUEIDENTIFIER, StartDate DATETIME, EndDate DATETIME)  
	IF(ISNULL(@PeriodsSrc, 0x0) = 0x0)  
	BEGIN
		INSERT INTO #CustMatMonthSales    
			SELECT    
			bi.buCustPtr,    
			bi.biMatPtr,    
			DatePart(Month, bi.buDate),    
			Sum( CASE bi.btBillType WHEN 1 THEN bi.biQty WHEN 3 THEN bi.biQty * -1 ELSE 0 END),    
			CASE @brEnabled WHEN 1 THEN bi.buBranch ELSE 0x0 END    
		FROM    
			vwExtended_bi AS bi    
			INNER JOIN #CustTbl AS cu ON cu.GUID = bi.buCustPtr    
			INNER JOIN #MatTbl AS mt ON mt.GUID = bi.biMatPtr    
		WHERE    
			bi.buDate BETWEEN @StartDate AND @EndDate	AND    
			-- bi.btIsInput = 0 	AND    
			bi.btType = 1 AND (bi.btBillType = 1 OR bi.btBillType = 3) AND     
			(bi.buBranch = @BranchGuid OR @BranchGuid = 0x0)    
		GROUP BY    
			bi.buCustPtr,    
			bi.biMatPtr,    
			DatePart(Month, bi.buDate),    
			CASE @brEnabled WHEN 1 THEN bi.buBranch ELSE 0x0 END


		INSERT INTO #PeriodsTbl  
			SELECT  
				p.Guid,  
				p.StartDate,  
				p.EndDate  
			FROM vwperiods AS p  
			INNER JOIN (SELECT TOP 1 * FROM disgeneraltarget000) AS gt ON gt.PeriodsMask & dbo.fnPowerOf2(p.Number - 1) <> 0
			WHERE gt.PeriodGuid = @PeriodGuid AND gt.BranchGuid = @BranchGuid AND gt.PeriodsMask <> 0
	END  
	ELSE  
	BEGIN  
		INSERT INTO #PeriodsTbl  
			SELECT  
				p.Guid,  
				p.StartDate,  
				p.EndDate  
			FROM vwperiods AS p  
			INNER JOIN RepSrcs AS rs ON rs.IdType = p.Guid AND rs.IdTbl = @PeriodsSrc   
	END  
	----
	IF EXISTS (SELECT TOP 1 * FROM #PeriodsTbl)
	BEGIN
		DELETE FROM #CustMatMonthSales
		DECLARE @C CURSOR,  
			@CPeriodGuid	UNIQUEIDENTIFIER,  
			@CStartDate		DATETIME,  
			@CEndDate		DATETIME  
	SET @C = CURSOR FAST_FORWARD FOR SELECT Guid, StartDate, EndDate FROM #PeriodsTbl  
	OPEN @C FETCH FROM @C INTO @CPeriodGuid, @CStartDate, @CEndDate    
	WHILE @@FETCH_STATUS = 0    
		BEGIN     
			INSERT INTO #CustMatMonthSales    
				SELECT    
					bi.buCustPtr,    
					bi.biMatPtr,    
					DatePart(Month, bi.buDate),    
					Sum( CASE bi.btBillType WHEN 1 THEN bi.biQty WHEN 3 THEN bi.biQty * -1 ELSE 0 END),    
					CASE @brEnabled WHEN 1 THEN bi.buBranch ELSE 0x0 END    
				FROM    
					vwExtended_bi AS bi    
					INNER JOIN #CustTbl AS cu ON cu.GUID = bi.buCustPtr    
					INNER JOIN #MatTbl AS mt ON mt.GUID = bi.biMatPtr    
				WHERE    
					bi.buDate BETWEEN @CStartDate AND @CEndDate	AND    
					-- bi.btIsInput = 0 	AND    
					bi.btType = 1 AND (bi.btBillType = 1 OR bi.btBillType = 3) AND     
					(bi.buBranch = @BranchGuid OR @BranchGuid = 0x0)    
				GROUP BY    
					bi.buCustPtr,    
					bi.biMatPtr,    
					DatePart(Month, bi.buDate),    
					CASE @brEnabled WHEN 1 THEN bi.buBranch ELSE 0x0 END  
			FETCH FROM @C INTO @CPeriodGuid, @CStartDate, @CEndDate    
		END	    
	CLOSE @C DEALLOCATE @C    
	END
--------  
	CREATE TABLE #CustMatSales( CustGUID UNIQUEIDENTIFIER, MatGUID UNIQUEIDENTIFIER, MonthCount INT, SalesQty FLOAT, MatSalesAvgQty float, StaticMatSalesAvgQty float, MatTargetQty float, TradeChannelTarget FLOAT, BranchGUID UNIQUEIDENTIFIER)    
	INSERT INTO #CustMatSales    
	SELECT    
		CustGUID,    
		MatGUID,    
		Count([Month]),    
		Sum(SalesQty),    
		0,    
		0,    
		0,    
		0,    
		BranchGuid    
	FROM    
		#CustMatMonthSales    
	GROUP BY    
		CustGUID,    
		MatGUID,    
		BranchGuid    
	------------------------------   
	--To get the mats with no previous move   
	IF(@ShowEmptyMat = 1 AND @RepType = 1)   
	BEGIN   
	INSERT INTO #CustMatSales    
		SELECT    
			0x0,    
			mt.Guid,   
			1,    
			0,	   
			0,    
			0,    
			0,    
			0,    
			@BranchGuid   
		FROM   
			#MatTbl AS mt   
			INNER JOIN mt000 AS mt2 ON mt.Guid = mt2.Guid   
		WHERE	mt.Guid NOT IN (SELECT MatGuid FROM #CustMatSales)   
			AND (mt2.GroupGuid = @MatGroup OR @MatGroup = 0x0)   
	END   
	IF(@ShowEmptyMat = 1 AND @RepType = 2)   
	BEGIN   
	INSERT INTO #CustMatSales    
		SELECT    
			ct.Guid,    
			mt.Guid,   
			1,    
			0,	   
			0,    
			0,    
			0,    
			0,    
			@BranchGuid   
		FROM   
			#MatTbl AS mt   
			INNER JOIN mt000 AS mt2 ON mt.Guid = mt2.Guid   
			INNER JOIN distchtarget000 AS tch ON tch.MatGuid = mt.Guid   
			INNER JOIN #CustTbl AS ct ON tch.TchGuid = ct.TradeChannelGUID 
		WHERE	mt.Guid NOT IN (SELECT MatGuid FROM #CustMatSales)   
			AND (mt2.GroupGuid = @MatGroup OR @MatGroup = 0x0)   
	--Insert the materials without tradechannel assigned 
--	INSERT INTO #CustMatSales    
--		SELECT    
--			ct.Guid,    
--			mt.Guid,   
--			1,    
--			0,	   
--			0,    
--			0,    
--			0,    
--			0,    
--			@BranchGuid   
--		FROM   
--			#MatTbl AS mt   
--			INNER JOIN mt000 AS mt2 ON mt.Guid = mt2.Guid   
--			INNER JOIN #CustTbl AS ct ON ct.Guid <> 0x0 
--		WHERE	mt.Guid NOT IN (SELECT MatGuid FROM #CustMatSales)   
--			AND (mt2.GroupGuid = @MatGroup OR @MatGroup = 0x0)   
	END   
	CREATE TABLE #MatSales( MatGUID UNIQUEIDENTIFIER, SalesAvgQty FLOAT, BranchGUID UNIQUEIDENTIFIER)    
	INSERT INTO #MatSales   
	SELECT   
		MatGUID,   
		Sum(SalesQty / MonthCount),   
		BranchGuid   
	FROM   
		#CustMatSales   
	GROUP BY   
		MatGUID, BranchGuid   
	if (@RepType = 1 )   
	------ Type 1 ------------------------------------------    
	begin   
		IF(ISNULL(@PeriodsSrc, 0x0) = 0x0)
		BEGIN
			SELECT	@StartDate AS StartDate,
					@EndDate AS EndDate,
					0 AS PeriodsMask
		END
		ELSE
		BEGIN
			DECLARE @PeriodsMask INT,
					@C2 CURSOR
			SET @PeriodsMask = 0
			SET @C2 = CURSOR FAST_FORWARD FOR SELECT Guid FROM #PeriodsTbl
			OPEN @C2 FETCH FROM @C2 INTO @CPeriodGuid
			WHILE @@FETCH_STATUS = 0
				BEGIN
					SELECT @PeriodsMask = @PeriodsMask + [dbo].[fnPowerOf2]([Number] - 1) FROM vwPeriods WHERE Guid = @CPeriodGuid
					FETCH FROM @C2 INTO @CPeriodGuid
				END
				CLOSE @C2
				DEALLOCATE @C2

			SELECT	'1980-01-01' AS StartDate,
					'1980-01-01' AS EndDate,
					@PeriodsMask AS PeriodsMask
		END

		SELECT    
			s.[MatGUID],   
			mt.[mtCode],   
			mt.[mtName],   
			s.[SalesAvgQty] / mt.unUnitFact AS SalesAvgQty,   
			mt.unUnit AS Unit,   
			mt.unUnitFact AS UnitFact,   
			mt.unUnitName AS UnitName   
		FROM   
			#MatSales AS s   
			INNER JOIN fnMtByUnit(@UseUnit) AS mt ON mt.mtGUID = s.MatGUID   
		ORDER BY LEN(mt.[mtCode]), mt.[mtCode]   
	End   
	------ Type 2 ------------------------------------------    
	ELSE    
	BEGIN    
		DECLARE @CustCnt INT   
		SELECT @CustCnt =  COUNT(*) FROM #CustTbl   
		UPDATE #CustMatSales    
		SET    
			MatSalesAvgQty = ms.SalesAvgQty    
		FROM    
			#MatSales AS ms    
			INNER JOIN #CustMatSales AS cms ON cms.MatGUID = ms.MatGUID AND cms.BranchGuid = ms.BranchGuid    
		UPDATE #CustMatSales    
		SET    
			StaticMatSalesAvgQty = mt.SalesQty,   
			MatTargetQty = mt.Qty,   
			TradeChannelTarget = mt.Qty /	CASE (SELECT COUNT(*) FROM #CustTbl AS ct   
												INNER JOIN distchtarget000 AS tch ON tch.TchGuid = ct.TradeChannelGUID AND tch.MatGuid = mt.MatGuid)   
											WHEN 0 THEN @CustCnt 
											ELSE (SELECT COUNT(*) FROM #CustTbl AS ct   
												INNER JOIN distchtarget000 AS tch ON tch.TchGuid = ct.TradeChannelGUID AND tch.MatGuid = mt.MatGuid)   
											END 
		FROM    
			vwDisGeneralTarget AS mt    
			INNER JOIN #CustMatSales AS cms ON cms.MatGUID = mt.MatGUID AND mt.PeriodGUID = @PeriodGUID AND (mt.BranchGuid = cms.BranchGuid OR @brEnabled = 0)    
		--------- From Type Target    
		/*CREATE TABLE #CustTypeMatTarget(CustGUID uniqueidentifier, MatGUID uniqueidentifier, Target float, BranchGuid Uniqueidentifier)    
		INSERT INTO #CustTypeMatTarget    
		SELECT    
			ce.CustomerGUID,    
			t.MatGUID,    
			Max(t.Qty),    
			CASE @brEnabled WHEN 1 THEN t.BranchGuid ELSE 0x0 END    
		FROM    
			vwDisTChTarget AS t    
			INNER JOIN DistCe000 AS ce ON (ce.TradeChannelGUID = t.TCHGUID OR ce.CustomerTypeGUID = t.TCHGUID) AND ce.State = 0    
			INNER JOIN vwCu		 AS cu ON cu.cuGuid = ce.CustomerGUID    
			INNER JOIN vwAc		 AS ac ON ac.acGuid = cu.cuAccount    
		WHERE    
			t.BranchGUID = @BranchGUID OR @BranchGUID = 0x0    
		GROUP BY     
			ce.CustomerGUID,    
			t.MatGUID,    
			CASE @brEnabled WHEN 1 THEN t.BranchGuid ELSE 0x0 END    
	    
		UPDATE #CustMatSales    
		SET    
			TradeChannelTarget = tt.Target    
		FROM    
			#CustTypeMatTarget AS tt    
			INNER JOIN #CustMatSales AS cms ON cms.MatGUID = tt.MatGUID AND cms.CustGUID = tt.CustGUID And cms.BranchGUID = tt.BranchGUID    
		INSERT INTO #CustMatSales    
		SELECT    
			tt.CustGUID,     
			tt.MatGUID ,     
			0,    
			0,     
			0,     
			0,     
			0,    
			tt.Target,    
			tt.BranchGuid    
		FROM    
			#CustTypeMatTarget AS tt    
			LEFT JOIN #CustMatSales AS cms ON cms.MatGUID = tt.MatGUID AND cms.CustGUID = tt.CustGUID AND cms.BranchGUID = tt.BranchGUID    
		WHERE    
			cms.CustGUID IS null */   
		    
		SELECT	    
			[ac].[acCode] 	AS acCode,    
			[ac].[acName] 	AS acName,    
			[mt].[mtCode] 	AS mtCode,    
			[mt].[mtName] 	AS mtName,    
			[s].[CustGUID],    
			[s].MatGUID,    
			[s].SalesQty / mt.unUnitFact	AS CustSalesQty,     
			[s].MonthCount					AS CustMonthCount,    
			((CASE [MonthCount] WHEN 0 THEN 0 ELSE ([s].[SalesQty] / [s].[MonthCount]) END) / mt.unUnitFact) AS CustSalesAvgQty,    
			[MatSalesAvgQty] / mt.unUnitFact		AS MatSalesAvgQty,    
			[StaticMatSalesAvgQty] / mt.unUnitFact	AS StaticMatSalesAvgQty,    
			((CASE [MatSalesAvgQty] WHEN 0 THEN 0 ELSE ((CASE [MonthCount] WHEN 0 THEN 0 ELSE ([s].[SalesQty] / [s].[MonthCount]) END) / MatSalesAvgQty)END)) AS CustPercent,    
			[MatTargetQty] / mt.unUnitFact			AS MatTargetQty,    
			[TradeChannelTarget] / mt.unUnitFact		AS CustTradeChannelTarget,    
			((CASE StaticMatSalesAvgQty WHEN 0 THEN [TradeChannelTarget] ELSE ((CASE [MatSalesAvgQty] WHEN 0 THEN 0 ELSE ((CASE [MonthCount] WHEN 0 THEN 0 ELSE ([s].[SalesQty] / [s].[MonthCount]) END) / MatSalesAvgQty)END) * [MatTargetQty]) END) / mt.unUnitFact) AS CustTarget,    
			mt.unUnitName				AS UnitName,    
			mt.unUnit					AS Unit,    
			mt.UnUnitFact				AS UnitFact,    
			[dbo].[fnDistGetDistsForCust] (Cu.cuGuid)		AS [AllDistNames],    
			ISNULL(s.BranchGuid, 0x0) AS BranchGuid,    
			ISNULL(br.Name, '') AS BranchName       
		FROM     
			[#CustMatSales] AS s    
			INNER JOIN [vwCu] AS [cu] ON [cu].[cuGUID] = [s].[CustGUID]    
			INNER JOIN [vwAc] AS [ac] ON [ac].[acGUID] = [cu].[cuAccount]    
			INNER JOIN fnMtByUnit(@UseUnit) AS mt ON [mt].[mtGUID] = [s].[MatGUID]    
			INNER JOIN #CustTbl AS ct ON [ct].[Guid] = [cu].[cuGuid]    
			LEFT JOIN br000	AS br ON br.Guid = s.BranchGuid    
		ORDER BY    
			LEN([mt].[mtCode]), [mt].[mtCode], Len([ac].[acCode]), [ac].[acCode]    
	END 
/*  
Exec prcConnections_Add2 '„œÌ—'  
Exec prcCalcCustsTargets '4AA629EC-053F-4E54-BE4E-328D53FF5369', 1, 2, 0x0  
select * from vwPeriods  
*/
############################################################################
CREATE PROCEDURE prcGetCustsTargets
	@PeriodGUID		UNIQUEIDENTIFIER,
	@UseUnit		INT,
	@BranchGUID		UNIQUEIDENTIFIER,
	@SortOrder		INT -- 1:sort by material, 2:sort by customer
AS
	SET NOCOUNT ON

	SELECT  
		d.GUID,  
		d.PeriodGUID,  
		d.CustGUID,  
		d.MatGUID,  
		d.CustRatio			AS CustPercent,
		d.CustTarget		AS CustTarget,
		d.Notes,  
		d.Security,  
		d.ExpectedCustTarget, 
		mt.mtName			AS mtName,
		mt.mtCode			AS mtCode, 
		c.cucustomerName	AS acName,
		c.acCode			AS acCode, 
		mt.unUnitName		AS UnitName, 
		mt.unUnit			AS Unit, 
		mt.UnUnitFact		AS UnitFact, 
		[dbo].[fnDistGetDistsForCust] (C.cuGuid)		AS [AllDistNames], 
		ISNULL(d.BranchGuid, 0x0) AS BranchGUID, 
		ISNULL(br.Name, '')	AS branchName

	FROM
		vbDistCustMatTarget AS d 
		INNER JOIN vwCuAc AS c ON d.CustGuid = c.cuGuid
		INNER JOIN fnMtByUnit(@UseUnit) AS mt ON [mt].[mtGUID] = [d].[MatGUID]
		LEFT JOIN br000 AS br ON br.Guid = d.BranchGuid
	WHERE
		d.PeriodGUID = @PeriodGUID AND
		(d.BranchGuid = @BranchGuid OR @BranchGuid = 0x0)
	ORDER BY 
		CASE @SortOrder 
			when 1 then [mt].[mtCode]
			when 2 then [c].[acCode]
		END,
		CASE @SortOrder 
			when 1 then [c].[acCode]
			when 2 then [mt].[mtCode]
		END
/*
Exec prcConnections_Add2 '„œÌ—'
prcGetCustsTargets '47E64183-1B63-407C-9366-91E1E24BE22B', 1
*/
#######################################################################
CREATE PROCEDURE prcDistDeleteGeneralTarget
	@PeriodGUID		UNIQUEIDENTIFIER,
	@BranchGUID		UNIQUEIDENTIFIER,
	@MatGroup		UNIQUEIDENTIFIER
AS
	SET NOCOUNT ON
	DELETE FROM disgeneraltarget000 
	WHERE MatGuid IN (SELECT mtGuid 
						FROM vwmt AS mt 
						INNER JOIN disgeneraltarget000 AS gt ON gt.MatGuid = mt.mtGuid 
						WHERE (mt.mtGroup = @MatGroup AND gt.SalesQty = 0) OR (@MatGroup = 0x0 AND gt.SalesQty = 0) OR gt.SalesQty <> 0) 
		AND PeriodGuid = @PeriodGuid 
		AND BranchGuid = @BranchGuid 
/* 
exec prcDistDeleteGeneralTarget 'D9DA4937-EE64-4EA0-A69B-34DA84282D85', 0x0, '0E31D41F-9DED-4C26-A5CF-12B22B5A8140' 
*/ 
############################################################################
#END