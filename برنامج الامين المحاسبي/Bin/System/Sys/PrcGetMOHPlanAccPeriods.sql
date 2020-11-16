############################################################
CREATE PROCEDURE PrcGetMOHPlanAccPeriods
	@PlOrFactoryGUID UNIQUEIDENTIFIER,
	@AccGuid UNIQUEIDENTIFIER,
	@Isdirect INT
AS
	SET NOCOUNT ON 
	if(@Isdirect = 0)
	BEGIN
		SELECT * FROM JOCFactoryIndirectExpensesAccounts000 
		WHERE FactoryGuid = @PlOrFactoryGUID  AND AccountGuid = @AccGuid 
		ORDER BY StartPeriodDate
	END
	ELSE IF(@Isdirect = 1)
	BEGIN
		SELECT * FROM JOCPlDirectExpensesAccounts000 
		WHERE PlGuid = @PlOrFactoryGUID  AND AccountGuid = @AccGuid 
		ORDER BY StartPeriodDate
	END
	ELSE
	BEGIN
		SELECT * FROM JOCPlDirectExpensesAccounts000 
		WHERE PlGuid = @PlOrFactoryGUID AND AccountType = 4
		ORDER BY StartPeriodDate
	END
################################################################################
CREATE PROCEDURE PrcGetMOHPlanAccounts
	@AccGUID UNIQUEIDENTIFIER
AS
	SET NOCOUNT ON
	SELECT ac.* 
	FROM  dbo.[fnGetAccountsList] ( @AccGUID, 1) AS list
	INNER JOIN ac000 AS ac ON ac.GUID = list.GUID WHERE ac.NSons = 0  ORDER BY ac.Code 
################################################################################
CREATE PROCEDURE PrcCheckForDeviation
	@FactoryGuid UNIQUEIDENTIFIER
AS

	IF EXISTS((SELECT 1 FROM JOCFactoryIndirectExpensesAccounts000 WHERE (EstimatedCost - OldEstimatedCost) <> 0 AND FactoryGuid = @FactoryGuid)) 
	  OR EXISTS(SELECT 1 FROM JOCPlDirectExpensesAccounts000 AS PLCOSTS
				INNER JOIN ProductionLine000 AS Pl ON pl.Guid = PLCOSTS.PlGuid AND Pl.ManufactoryGUID = @FactoryGuid
				WHERE (PLCOSTS.EstimatedCost - PLCOSTS.OldEstimatedCost) <> 0 AND (PLCOSTS.AccountType = 0 OR PLCOSTS.AccountType = 4))
	BEGIN
		SELECT 1 
	END

################################################################################
CREATE PROCEDURE PrcSaveEstimatedCostsToProductionLines
	@FactoryGuid UNIQUEIDENTIFIER
AS
	SET NOCOUNT ON
		UPDATE pl
			SET pl.estimatedcost = mohplcosts.EstimatedCost
		FROM Plcosts000 AS pl
			INNER JOIN ProductionLine000 AS pline ON pline.Guid = pl.ProductionLine
			INNER JOIN JOCPlDirectExpensesAccounts000 AS mohplcosts ON mohplcosts.PlGuid = pl.ProductionLine AND mohplcosts.StartPeriodDate = pl.StartPeriodDate 
		WHERE mohplcosts.AccountType = 5 AND pline.ManufactoryGUID = @FactoryGuid

		INSERT INTO Plcosts000 (ProductionLine, StartPeriodDate, EndPeriodDate, EstimatedCost, ActualCost)
		SELECT 
				JocMoh.PlGuid,
				JocMoh.StartPeriodDate,
				JocMoh.EndPeriodDate,
				JocMoh.EstimatedCost,
				0
		FROM JOCPlDirectExpensesAccounts000 AS JocMoh
			LEFT JOIN Plcosts000 AS pl ON pl.ProductionLine = JocMoh.PlGuid AND pl.StartPeriodDate = JocMoh.StartPeriodDate 
			INNER JOIN ProductionLine000 AS pline ON pline.Guid = JocMoh.PlGuid
		WHERE JocMoh.AccountType = 5  AND pline.ManufactoryGUID = @FactoryGuid AND pl.StartPeriodDate IS NULL
			
		UPDATE ProductionLine000
			SET EstimatedCost = ISNULL(jocmoh.TotalEstimatedValue, 0)
		FROM ProductionLine000 AS pline
			INNER JOIN JOCPlDirectExpensesAccounts000 AS jocmoh ON jocmoh.PlGuid = pline.Guid 
		WHERE jocmoh.AccountType = 5 AND pline.ManufactoryGUID = @FactoryGuid 
################################################################################
CREATE PROC PrcResetActualCost
	@FactoryGuid [UNIQUEIDENTIFIER]
	AS 
	SET NOCOUNT ON

	UPDATE pl
			SET pl.ActualCost = 0,
				pl.IsActualCostSaved = 0
		FROM Plcosts000 AS pl
			INNER JOIN ProductionLine000 AS pline ON pline.Guid = pl.ProductionLine
		WHERE  (pline.ManufactoryGUID = @FactoryGuid OR @FactoryGuid = 0x0)

		UPDATE pl
			SET pl.ActualCost = 0,
				PL.IsActualCostSaved = 0
		FROM ProductionLine000 AS pl
		WHERE (pl.ManufactoryGUID = @FactoryGuid OR @FactoryGuid = 0x0)
################################################################################
CREATE PROC PrcSaveActualCost
	@FactoryGuid [UNIQUEIDENTIFIER],
	@CurGuid	 [UNIQUEIDENTIFIER],
	@IsSaveActualInEstimated [INT] = 0
	AS 
	SET NOCOUNT ON

	CREATE  TABLE #Result
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
		[LineType]						[INT] ,
		[EstimatedExpenses]				[FLOAT],
		[AllocationValue]				[FLOAT],
		[Slope]                         [FLOAT] default  0,
        [Intercept]                     [FLOAT] default  0,
        [RSQ]                           [FLOAT] default  0
	)
	DECLARE @EndPeriodDate [DATETIME],
	@FirstPeriodDate [DATETIME] 

	SET @FirstPeriodDate =(SELECT CAST(Value AS DATETIME) FROM op000 WHERE Name ='AmnCfg_FPDate')
	SET @EndPeriodDate =(SELECT CAST(Value AS DATETIME) FROM op000 WHERE Name ='AmnCfg_EPDate')

	INSERT INTO #Result
	 EXEC JOCprcIndirectExpensesAnalysesReport @FactoryGuid, @FirstPeriodDate, @EndPeriodDate, @CurGuid, 0, 0, 1

	DECLARE @Sql NVARCHAR (MAX) = ''

	SET @Sql = 'UPDATE pl SET '
	IF(@IsSaveActualInEstimated = 1)
		SET @Sql = @Sql + ' EstimatedCost = Res.ActualExpenses , ' 

	SET @Sql = @Sql + ' ActualCost = Res.ActualExpenses,
								IsActualCostSaved = CASE Res.AllocationValue WHEN 0 THEN 0 ELSE 1 END ' 
	
	SET @Sql = @Sql + 'FROM Plcosts000 pl INNER JOIN (SELECT ActualExpenses , ProductionLineGuid, StartDate, ISNULL(AllocationValue, 0) AllocationValue FROM #Result WHERE LineType = 5 ) Res On Res.ProductionLineGuid = pl.ProductionLine AND Res.StartDate = pl.StartPeriodDate'
	
	SELECT ProductionLineGuid,
		CASE WHEN SUM(CASE WHEN LineType = 3 THEN 0 ELSE ActualExpenses END) = 0 
			THEN 0 
			ELSE 
				SUM(CASE WHEN LineType = 4 THEN 0 ELSE ActualExpenses END)/ SUM(CASE WHEN LineType = 3 THEN 0 ELSE ActualExpenses END) END AS ActualExpenses  
		INTO #totalCosts 
		FROM #Result
		WHERE LineType IN (3, 4)
		GROUP BY ProductionLineGuid

	SET @Sql = @Sql + ' UPDATE Pline SET '
	IF(@IsSaveActualInEstimated = 1)
		SET @Sql = @Sql + ' EstimatedCost = total.ActualExpenses , ' 

	SET @Sql = @Sql + ' ActualCost = total.ActualExpenses ,
								IsActualCostSaved = 1' 

	SET @Sql = @Sql + ' FROM ProductionLine000 Pline INNER JOIN #totalCosts total ON total.ProductionLineGuid = Pline.Guid'
	EXEC (@Sql)

################################################################################
#END