########################################
## prcDistGetCustClassification
CREATE   PROC prcDistGetCustClassification
	@DistGuid	UNIQUEIDENTIFIER,
	@AccGuid		UNIQUEIDENTIFIER
AS

	SET NOCOUNT ON
	IF ISNULL(@DistGuid, 0x0) = 0x0 AND ISNULL(@AccGuid, 0x0) = 0x0
	BEGIN
		RETURN
	END
	CREATE TABLE [#SecViol]	( [Type] 	[INT], 		    [Cnt]	[INT] )     
	CREATE TABLE [#Cust] 	( [CustGuid] 	UNIQUEIDENTIFIER, [Security] INT )       
	CREATE TABLE [#Dist] 	( [DistGUID] 	UNIQUEIDENTIFIER, [Security] [INT])       

	INSERT INTO [#Cust]  ( [CustGuid], [Security]) EXEC prcGetDistGustsList @DistGuid, @AccGuid  
	INSERT INTO [#Dist] EXEC GetDistributionsList @DistGuid , 0x00

	EXEC [prcCheckSecurity]  @result = '#Cust'    
	
	IF (SELECT COUNT(*) FROM #Cust) = 0
		INSERT INTO #Cust
		SELECT 
			GUID, SECURITY FROM cu000 
		WHERE GUID = @AccGuid

	CREATE TABLE #CustTemplates
	(
		CustGuid		UNIQUEIDENTIFIER,
		MatTemplateNumber	INT,	
		MatTemplateGuid	UNIQUEIDENTIFIER,
		MatTemplateName	NVARCHAR(255) COLLATE ARABIC_CI_AI,
	)

	INSERT INTO #CustTemplates
    	SELECT Cu.CustGuid, t.Number, t.Guid, t.Name
 		FROM #Cust AS Cu CROSS JOIN DistMatTemplates000	 AS t	
		ORDER By CustGuid, Number

-- select * from #CustTemplates Order By CustGuid

	CREATE TABLE #Result
	(
		Number			INT,
		Guid			UNIQUEIDENTIFIER,	
		DistGuid		UNIQUEIDENTIFIER,	
		CustGuid		UNIQUEIDENTIFIER,
		CustName		NVARCHAR(255) COLLATE ARABIC_CI_AI,
		MatTemplateGuid		UNIQUEIDENTIFIER,
		MatTemplateName		NVARCHAR(255) COLLATE ARABIC_CI_AI,
		MatTemplateNumber	INT,
		CustClassGuid		UNIQUEIDENTIFIER,
		CustClassName		NVARCHAR(255) COLLATE ARABIC_CI_AI,
		CustClassNumber		INT,
		CustStateGuid		UNIQUEIDENTIFIER,
		CustStateName		NVARCHAR(255) COLLATE ARABIC_CI_AI,
		CustStateNumber		INT,
		MatShowGuid		UNIQUEIDENTIFIER,
		MatShowName		NVARCHAR(255) COLLATE ARABIC_CI_AI,
		MatShowNumber		INT,
		Flag			INT
	)

	INSERT INTO #Result 
		SELECT 	
			ISNULL(Cc.Number, 0),
			ISNULL(Cc.Guid, 0x00),
			D.DistGuid,
			vCu.CuGuid,
			vCu.cuCustomerName,
			cu.MatTemplateGuid, -- ISNULL(Dd.ObjectGuid, 0x00),--tp.Guid,
			cu.MatTemplateName,			
			cu.MatTemplateNumber,			
			ISNULL(Cl.Guid, 0x00),
			ISNULL(Cl.Name, ''),
			ISNULL(Cl.Number, 0),
			ISNULL(Cs.Guid, 0x00),
			ISNULL(Cs.Name, ''),
			ISNULL(Cs.Number, 0),
			ISNULL(Msm.Guid, 0x00),
			ISNULL(Msm.Name, ''),
			ISNULL(Msm.Number, 0),
			1 -- CASE ISNULL(Dd.ObjectGuid, 0x00) WHEN 0x00 THEN 0 ELSE 1 END
		FROM 
			#CustTemplates AS Cu 
			INNER JOIN vwCu AS vCu ON vCu.cuGuid  = Cu.CustGuid 
			LEFT JOIN #Cust AS Cust ON Cust.CustGuid = vCu.cuGuid 
			LEFT JOIN DistDistributionLines000 AS Dl ON Dl.CustGuid = Cu.CustGuid AND (Dl.DistGuid = @DistGuid OR @DistGuid = 0x0) 
			LEFT JOIN #Dist AS D ON D.DistGuid = Dl.DistGuid 
			LEFT  JOIN DistDd000	  AS Dd  ON Dd.DistributorGuid = D.DistGuid AND Dd.ObjectType = 3	AND Dd.ObjectGuid = cu.MatTemplateGuid	 
			LEFT  JOIN DistCC000	  AS Cc  ON Cc.CustGuid = vCu.cuGuid AND Cc.MatTemplateGuid = cu.MatTemplateGuid	 
			LEFT  JOIN DistCustClasses000	AS Cl  ON Cl.Guid = CC.CustClassGuid 
			LEFT  JOIN DistCustStates000	AS Cs  ON Cs.Guid = CC.CustStateGuid 
			LEFT  JOIN DistMatShowingMethods000		AS Msm  ON Msm.Guid = Cc.MatShowGuid 

	SELECT * FROM #Result ORDER BY CustGuid, MatTemplateNumber
/*
EXEC prcDistGetCustClassification 'C68D5493-FE3F-4C2A-B740-09BF463725C5', 0x00
EXEC prcDistGetCustClassification 0x00, 0x00
*/
########################################
## prcDistGetCustClassesTarget
CREATE PROC prcDistGetCustClassesTarget
	@PeriodGuid 		UNIQUEIDENTIFIER,
	@ScanRelatedTarget	INT = 0,
	@GetRelatedPeriod	INT = 0,
	@GetTargetPeriod	INT = 0
AS
	SET NOCOUNT ON

	CREATE TABLE #Targets
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
			BranchGUID			UNIQUEIDENTIFIER,
			BranchName			NVARCHAR(100) COLLATE ARABIC_CI_AI,
			BranchNumber		INT
		)	

	INSERT INTO #Targets
		SELECT 
			Cc.Guid, Cc.PeriodGuid, Cc.CustCLassGuid, Cc.CustClassName, Cc.CustClassNumber,
			Cc.MatTemplateGuid, Cc.MatTemplateName, Cc.MatTemplateNumber, Cc.CurGuid, Cc.CurVal,
			Cc.TargetVal, 1, pd.Name, ISNULL(Cc.BranchGUID, 0x0),  ISNULL(br.Name, ''), ISNULL(br.Number, 0)
		FROM vwDistCustClassesTarget AS Cc
			INNER JOIN vwPeriods AS pd ON pd.Guid = Cc.PeriodGuid
			LEFT JOIN br000	AS br ON br.GUID = Cc.BranchGUID
		WHERE PeriodGuid = @PeriodGuid

	CREATE TABLE #Classes
		(
			Number		INT,
			GUID		UNIQUEIDENTIFIER,
			Name		NVARCHAR(255) COLLATE ARABIC_CI_AI,
			New			INT
		)

	INSERT INTO #Classes 	
		SELECT Number, Guid , Name, 1 FROM DistCustClasses000 
		WHERE Guid NOT IN (SELECT CustClassGuid FROM #Targets)
	INSERT INTO #Classes
		SELECT DISTINCT CustClassNumber, CustClassGuid, CustClassName, 0 
		FROM #Targets	

	CREATE TABLE #Templates
		(
			Number		INT,
			GUID		UNIQUEIDENTIFIER,
			Name		NVARCHAR(255) COLLATE ARABIC_CI_AI,
			New		INT
		)

	INSERT INTO #Templates 	
		SELECT Number, Guid , Name, 1 FROM DistMatTemplates000 
		WHERE Guid NOT IN (SELECT MatTemplateGuid FROM #Targets)
	INSERT INTO #Templates
		SELECT DISTINCT MatTemplateNumber, MatTemplateGuid, MatTemplateName, 0
		FROM #Targets	


	DECLARE @C			CURSOR,
			@Number		INT,
			@Guid		UNIQUEIDENTIFIER,
			@Name		NVARCHAR(255),
			@CurGuid	UNIQUEIDENTIFIER,
			@CurVal		FLOAT,	
			@New		INT

	DECLARE @C_BR		CURSOR,
			@brGuid		UNIQUEIDENTIFIER,
			@brName		NVARCHAR(255),
			@brNumber	INT

	SELECT TOP 1 @CurGuid = CurGuid, @CurVal = CurVal FROM #Targets

	SET @C = CURSOR FAST_FORWARD FOR
		SELECT Number, Guid, Name, New FROM #Templates
	OPEN @C FETCH FROM @C INTO @Number, @Guid, @Name, @New
	WHILE @@FETCH_STATUS = 0
	BEGIN
		SET @C_BR = CURSOR FAST_FORWARD FOR
			SELECT brGuid, brName, brNumber FROM vwbr
		OPEN @C_br FETCH FROM @C_br INTO @brGuid, @brName, @brNumber
		WHILE @@FETCH_STATUS = 0
		BEGIN
			IF @New = 1 
			BEGIN
				INSERT INTO #Targets(	Guid, PeriodGuid, CustClassGuid, CustClassName, CustClassNumber, 
							MatTemplateGuid, MatTemplateName, MatTemplateNumber, 
							CurGuid, CurVal, TargetVal, Flag, PeriodName, BranchGUID, BranchName, BranchNumber
						    )
					SELECT 		newId(), @PeriodGuid, Guid, Name, Number, 
							@Guid, @Name, @Number,
							@CurGuid, @CurVal, 0, 1, '', @brGuid, @brName, @brNumber
					FROM #Classes -- WHERE New = 0
			END
			ELSE
				INSERT INTO #Targets(	Guid, PeriodGuid, CustClassGuid, CustClassName, CustClassNumber, 
							MatTemplateGuid, MatTemplateName, MatTemplateNumber, 
							CurGuid, CurVal, TargetVal, Flag, PeriodName, BranchGUID, BranchName, BranchNumber
						    )
					SELECT 		newId(), @PeriodGuid, Guid, Name, Number, 
							@Guid, @Name, @Number,
							@CurGuid, @CurVal, 0, 1, '', @brGuid, @brName, @brNumber
					FROM #Classes WHERE New = 1
			FETCH FROM @C_br INTO @brGuid, @brName, @brNumber
		END		
		FETCH FROM @C INTO @Number, @Guid, @Name, @New
	END
	CLOSE @C_BR
	DEALLOCATE @C_BR
	CLOSE @C DEALLOCATE @C 

-- select * from #Targets
-----------------------------------------------------------------------------------------
------ Chcek If There are another Periods which relateds with this period is dates and take Targets 
	IF (@ScanRelatedTarget = 1)
	BEGIN
		CREATE TABLE #TargetPeriods 
			(	
				PeriodGUID 	UNIQUEIDENTIFIER, 
				PeriodName 	NVARCHAR(100) COLLATE ARABIC_CI_AI,
				StartDate	DATETIME,
				EndDate		DATETIME
			)
		CREATE TABLE #RelatedTargets
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
				BranchGUID			UNIQUEIDENTIFIER,
				BranchName			NVARCHAR(100) COLLATE ARABIC_CI_AI,
				BranchNumber		INT			
			)	
	
		DECLARE @StartDate	DATETIME,
			@EndDate	DATETIME,
			@PeriodName	NVARCHAR(100) 

		SELECT @StartDate = StartDate, @EndDate = EndDate, @PeriodName = Name FROM vwPeriods WHERE Guid = @PeriodGuid
		
		DECLARE @Len INT
		SET @Len = LEN('DistCfg_Target_CurPeriod')
	
		INSERT INTO #TargetPeriods
			SELECT ISNULL(CAST(Value AS uniqueidentifier), 0x0), pd.Name, pd.StartDate, pd.EndDate 
			FROM op000 AS op
				INNER JOIN vwPeriods AS pd ON pd.Guid = op.Value
			WHERE LEFT(op.Name, @Len) = 'DistCfg_Target_CurPeriod'

		INSERT INTO #RelatedTargets
			SELECT 
				Cc.Guid, Cc.PeriodGuid, Cc.CustCLassGuid, Cc.CustClassName, Cc.CustClassNumber,
				Cc.MatTemplateGuid, Cc.MatTemplateName, Cc.MatTemplateNumber, Cc.CurGuid, Cc.CurVal,
				Cc.TargetVal, 0, pd.Name, ISNULL(br.GUID, 0x0), ISNULL(br.Name, ''), IsNull(br.Number, 0)   
			FROM vwDistCustClassesTarget  	AS Cc
				INNER JOIN vwPeriods 	AS pd ON pd.Guid = Cc.PeriodGuid
				LEFT JOIN #TargetPeriods AS tpd ON tpd.PeriodGuid = Cc.PeriodGuid
				LEFT JOIN br000 AS br ON br.GUID = Cc.BranchGUID
			WHERE 
				( @GetTargetPeriod = 0 OR tpd.PeriodGuid IS NOT NULL)	AND
				( Cc.PeriodGuid <> @PeriodGuid ) AND
				(
					( (pd.StartDate BETWEEN @StartDate AND @EndDate)   AND (pd.EndDate BETWEEN @StartDate AND @EndDate))	OR
					( (@StartDate BETWEEN pd.StartDate AND pd.EndDate) AND (@EndDate BETWEEN pd.StartDate AND pd.EndDate) )
				)
-- select * from #RelatedTargets

		UPDATE Tr 
			SET 	Flag = 0,
				TargetVal = Rt.TargetVal,
				PeriodGuid = CASE @GetRelatedPeriod WHEN 0 THEN Tr.PeriodGuid ELSE Rt.PeriodGuid END,
				PeriodName = CASE @GetRelatedPeriod WHEN 0 THEN Tr.PeriodName ELSE Rt.PeriodName END	
		FROM #Targets AS Tr 
		INNER JOIN #RelatedTargets AS Rt ON Tr.CustCLassGuid = Rt.CustClassGuid AND 
											Tr.MatTemplateGuid = Rt.MatTemplateGuid AND 
											Rt.TargetVal <> 0	AND
											Tr.BranchGUID = Rt.BranchGUID
	/*
		INSERT INTO #Targets 
			SELECT Rt.* 
			FROM #RelatedTargets AS Rt 
				LEFT JOIN #Targets AS Tr ON Tr.CustCLassGuid = Rt.CustClassGuid AND Tr.MatTemplateGuid = Rt.MatTemplateGuid -- AND Rt.TargetVal <> 0
			WHERE Tr.Guid IS NULL AND Rt.TargetVal <> 0
	*/
	END

	SELECT * FROM #Targets ORDER BY CustClassNumber, BranchNumber, MatTemplateNumber


/*
Exec prcConnections_Add2 '„œÌ—'
EXEC prcDistGetCustClassesTarget '8533F4A1-EE67-43E9-9137-502634063E7F', 1, 1 
*/
########################################
#END
