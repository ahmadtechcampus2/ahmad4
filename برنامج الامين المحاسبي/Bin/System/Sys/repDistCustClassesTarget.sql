###########################################################
####################		repDistCustClassesTarget
CREATE   PROC repDistCustClassesTarget
	@PeriodGuid		[UNIQUEIDENTIFIER],      
	@EndDate		[DATETIME],       
	@CurGuid		[UNIQUEIDENTIFIER], 
	@HiGuid			[UNIQUEIDENTIFIER],       
	@DistGuid		[UNIQUEIDENTIFIER],       
	@CustAccGuid		[UNIQUEIDENTIFIER],       
	@TemplatesGuid		[UNIQUEIDENTIFIER],
	@TemplatesCnt		[INT],
	@ClassesGuid		[UNIQUEIDENTIFIER],
	@SortFlag		[INT]		-- 0 Class	1 Target	2 Acheived	3 Remain	4 Rate
AS       
	SET NOCOUNT ON      
	CREATE TABLE [#SecViol]	( [Type]	[INT], [Cnt]	[INT] )     

	CREATE TABLE [#Custs]   ( [GUID] [UNIQUEIDENTIFIER], [Security] [INT])          
	INSERT INTO  [#Custs] (Guid, Security)  EXEC prcGetDistGustsList @DistGuid, @CustAccGuid, 0x00, @HiGuid   
	IF (@DistGuid = 0x00 AND @CustAccGuid =  0x00 AND @HiGuid = 0x00)  
		DELETE FROM #Custs WHERE GUID NOT IN ( SELECT CustGuid FROM DistDistributionLines000)
	
	EXEC [prcCheckSecurity]  @result = '#Custs'     

	CREATE TABLE #MatTemplates	(Guid UNIQUEIDENTIFIER, Number INT, Name NVARCHAR(255), GroupGuid UNIQUEIDENTIFIER )
	INSERT INTO #MatTemplates 
		SELECT Guid, Number, Name, GroupGuid
		FROM DistMatTemplates000 
		WHERE (Guid IN (SELECT IdType FROM RepSrcs WHERE idTbl = @TemplatesGuid)) OR (@TemplatesGuid = 0x00)
	

	CREATE TABLE #CustTemplates
		(
			CustGuid	UNIQUEIDENTIFIER,
			MatTemplateNumber	INT,	
			MatTemplateGuid	UNIQUEIDENTIFIER,
			MatTemplateName	NVARCHAR(255) COLLATE ARABIC_CI_AI,
		)

	INSERT INTO #CustTemplates
	    	SELECT Cu.Guid, t.Number, t.Guid, t.Name
	 		FROM #Custs AS Cu CROSS JOIN DistMatTemplates000	 AS t	
			ORDER By Cu.Guid, t.Number

---------------------------------------------------------------------------------------   
-------------- Get Target For Each Class
	CREATE TABLE #ClassTargets
		(
			Guid				UNIQUEIDENTIFIER,
			PeriodGuid			UNIQUEIDENTIFIER,
			CustClassGuid		UNIQUEIDENTIFIER,
			CustClassName		NVARCHAR(255) COLLATE ARABIC_CI_AI,
			CustClassNumber		INT,	
			MatTemplateGuid		UNIQUEIDENTIFIER,
			MatTemplateName		NVARCHAR(255) COLLATE ARABIC_CI_AI,
			MatTemplateNumber	INT,
			CurGuid				UNIQUEIDENTIFIER,	
			CurVal				FLOAT,
			TargetVal			FLOAT,
			Flag				INT,
			PeriodName			NVARCHAR(100) COLLATE ARABIC_CI_AI,
			BranchGuid			UNIQUEIDENTIFIER,
			BranchName			NVARCHAR(255) COLLATE ARABIC_CI_AI,
			BranchNumber		INT
		)
	
	INSERT INTO #ClassTargets Exec prcDistGetCustClassesTarget @PeriodGuid, 0 -- 'D503D055-EF9C-47D6-B88E-16FCCEA7FF8C'
	
---------------------------------------------------------------------------------		
---------  Calc Bill Totals To Get AchivedVal

	CREATE TABLE #Bills
		(
			CustGuid	UNIQUEIDENTIFIER,
			MatTemplateGuid	UNIQUEIDENTIFIER,
			Totals		FLOAT,
			Flag		INT
		)

	DECLARE	@StartDate	DATETIME,	
		@CurVal		FLOAT

	SELECT @StartDate = StartDate FROM vwPeriods	WHERE Guid = @PeriodGuid
	SELECT @CurVal = ISNULL(CurrencyVal, 1) FROM my000 WHERE Guid = @CurGuid

		 INSERT INTO #Bills
			SELECT 
				Cu.Guid,
				Fn.TemplateGuid, 
				CASE bt.btIsOutput 	WHEN 1 THEN  (FixedBiTotal) 
							       ELSE -(FixedBiTotal) 
				END,
				0 		
			FROM 
				#Custs	AS Cu
				INNER JOIN dbo.fnExtended_bi_Fixed( @CurGuid) 	AS bu ON bu.buCustPtr = Cu.Guid
				INNER JOIN vwBt 				AS bt ON bt.btGUID = bu.buType 
				INNER JOIN fnDistGetMatTemplates(0x00) 		AS Fn ON Fn.MatGuid = bu.biMatPtr
				INNER JOIN #MatTemplates 			AS mt ON mt.Guid = Fn.TemplateGuid
			WHERE 
				bt.btType = 1	AND		
				bu.buDate BETWEEN @StartDate AND @EndDate	

-- select * from #Bills

	EXEC [prcCheckSecurity]  @result = '#Bills'

	INSERT INTO #Bills
		SELECT
			CustGuid, MatTemplateGuid, SUM(Totals), 1
		FROM #Bills 
		GROUP BY CustGuid, MatTemplateGuid
	
	DELETE FROM #Bills WHERE Flag = 0
---------------------------------------------------------------------------------		
	CREATE TABLE #Result
		(
			CustGuid		UNIQUEIDENTIFIER,
			CustName		NVARCHAR(255) COLLATE ARABIC_CI_AI,
			MatTemplateGuid		UNIQUEIDENTIFIER,
			MatTemplateName		NVARCHAR(255) COLLATE ARABIC_CI_AI,
			MatTemplateNumber	INT,
			CustClassGuid		UNIQUEIDENTIFIER,
			CustClassName		NVARCHAR(255) COLLATE ARABIC_CI_AI,
			TargetVal		FLOAT,
			AchievedVal		FLOAT
		)

	INSERT INTO #Result
		SELECT 
			c.cuGuid,
			c.cuCustomerName,
			Cu.MatTemplateGuid,
			Cu.MatTemplateName,
			Cu.MatTemplateNumber,
			ISNULL(Ct.CustClassGuid, 0x00), 
			ISNULL(Ct.CustClassName, ''),
			-- ISNULL(Ct.TargetVal, 0) / ISNULL(@CurVal, 1),
			SUM(ISNULL(Ct.TargetVal, 0) / ISNULL(@CurVal, 1)),
			ISNULL(bi.Totals, 0)
		FROM	
			#CustTemplates		AS cu
			INNER JOIN vwCu		AS c  ON c.cuGuid = cu.CustGuid
			LEFT JOIN DistCc000	AS Cc ON Cc.CustGuid = cu.CustGuid AND Cc.MatTemplateGuid = cu.MatTemplateGuid
			LEFT JOIN #ClassTargets AS Ct ON Cc.MatTemplateGuid = Ct.MatTemplateGuid AND Cc.CustClassGuid = Ct.CustClassGuid
			INNER JOIN #MatTemplates	AS T  ON T.Guid = cu.MatTemplateGuid
			LEFT JOIN #Bills	AS bi ON bi.CustGuid = cu.CustGuid AND bi.MatTemplateGuid = cu.MatTemplateGuid 	
		-- New
		WHERE 		
			@TemplatesCnt <> 1  OR
			(ISNULL(Ct.CustClassGuid, 0x00) IN (SELECT IdType FROM RepSrcs WHERE idTbl = @ClassesGuid))
		GROUP By 
			c.cuGuid,
			c.cuCustomerName,
			Cu.MatTemplateGuid,
			Cu.MatTemplateName,
			Cu.MatTemplateNumber,
			ISNULL(Ct.CustClassGuid, 0x00), 
			ISNULL(Ct.CustClassName, ''),
			ISNULL(bi.Totals, 0)
			
	DECLARE @sql NVARCHAR(1000)
	SET @sql = ' SELECT * FROM #Result ORDER BY '
	IF @TemplatesCnt = 1
	BEGIN
		IF @SortFlag = 0 	
			SET @sql = @sql + ' CustClassName'
		IF @SortFlag = 1 	
			SET @sql = @sql + ' TargetVal'
		IF @SortFlag = 2 	
			SET @sql = @sql + ' AchievedVal'
		IF @SortFlag = 3 	
			SET @sql = @sql + ' TargetVal - AchievedVal'
		IF @SortFlag = 4 	
			SET @sql = @sql + ' CASE TargetVal WHEN 0 THEN AchievedVal ELSE AchievedVal * 100 / TargetVal END'
		SET @sql = @sql + ' ,CustGuid, MatTemplateNumber '
	END
	ELSE
		SET @sql = @sql + ' CustGuid, MatTemplateNumber '
	EXEC (@sql)
	SELECT * FROM #MatTemplates ORDER BY Number

/*
Exec prcConnections_Add2 '„œÌ—'
Exec  [repDistCustClassesTarget] '8533f4a1-ee67-43e9-9137-502634063e7f', '10/31/2006', 'e7199e19-4db4-4fe1-8e60-2e12636b8fae', '00000000-0000-0000-0000-000000000000', '0800c09d-7a2f-4ceb-8d06-a82eda211dea', '00000000-0000-0000-0000-000000000000', '2f5825ca-ce60-4f70-94bb-725eb2da0ebd', 2, 'c6cff780-019f-4a14-bfa0-55e6d4197143', 0 
*/
###########################################################
#END
