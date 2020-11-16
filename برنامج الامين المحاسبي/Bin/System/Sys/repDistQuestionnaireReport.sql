##################################################################################
CREATE PROCEDURE repDistQuestionnaireReport
	@HierarchyGuid		UNIQUEIDENTIFIER, 
	@DistGuid			UNIQUEIDENTIFIER, 
	@CustGuid			UNIQUEIDENTIFIER = 0x0, 
	@QuestionnaireGuid	UNIQUEIDENTIFIER = 0x0, 
	@StartDate			DATETIME, 
	@EndDate			DATETIME, 
	@ResultType			INT, -- 1:Detailed, 2:Grouped 
	@ShowRecordedVisits	BIT, 
	@ShowNotRecordedVisits	BIT 
AS 
	SET NOCOUNT ON 
	CREATE TABLE #DistTbl(DistGuid UNIQUEIDENTIFIER, distSecurity INT) 
	INSERT INTO #DistTbl EXEC GetDistributionsList @DistGuid, @HierarchyGuid 
	-- Detailed Result Set 
	IF @ResultType = 1 
	BEGIN 
		--------- Get Visits States ----------- 
		CREATE TABLE #TotalVisitsStates (VisitGuid UNIQUEIDENTIFIER, CustGuid UNIQUEIDENTIFIER, DistGuid UNIQUEIDENTIFIER, State INT, VisitDate DATETIME) -- State: 1 Active , 0 Inactive  
		INSERT INTO #TotalVisitsStates EXEC prcDistGetVisitsState @StartDate, @EndDate, @HierarchyGuid, @DistGuid, 0, 0x0  

		Create Table #Result1 
		( 
			DistGuid			UNIQUEIDENTIFIER, 
			DistName			NVARCHAR(250), 
			CustGuid			UNIQUEIDENTIFIER, 
			CustName			NVARCHAR(250), 
			VisitGuid			UNIQUEIDENTIFIER, 
			VisitDate			DATETIME, 
			VisitState			BIT, 
			QuestionnaireGuid	UNIQUEIDENTIFIER, 
			QuestionnaireName	NVARCHAR(250), 
			QuestionGuid		UNIQUEIDENTIFIER,
			Question			NVARCHAR(250),
			Answer				NVARCHAR(250) 
		) 		 
		INSERT INTO #Result1 
		SELECT 
			d1.DistGuid, 
			d2.Name, 
			vi.CustGuid, 
			cu.CustomerName, 
			vi.VisitGuid, 
			vi.VisitDate, 
			vi.State, 
			q.Guid,
			q.name, 
			qu.Guid,
			qu.Text, 
			ISNULL(qa.Answer, '') 
		FROM #DistTbl AS d1 
			INNER JOIN Distributor000 AS d2 ON d1.DistGuid = d2.Guid 
			INNER JOIN #TotalVisitsStates AS vi ON d1.DistGuid = vi.DistGuid 
			INNER JOIN cu000 AS cu ON vi.CustGuid = cu.Guid
			CROSS JOIN DistQuestionnaire000 AS q 
			INNER JOIN DistQuestQuestion000 AS qu ON qu.ParentGuid = q.Guid 
			LEFT JOIN DistQuestAnswers000 AS qa ON vi.VisitGuid = qa.VisitGuid AND qa.QuestGuid = qu.Guid AND cu.Guid = qa.CustGuid
		WHERE 
		  (qu.ParentGuid = @QuestionnaireGuid OR @QuestionnaireGuid = 0x0)
		  AND (d2.Guid = @DistGuid OR @DistGuid = 0x0)
		  AND (vi.CustGuid = @CustGuid OR @CustGuid = 0x0) 
		  AND (((q.StartDate BETWEEN @StartDate AND @EndDate) AND (q.EndDate BETWEEN @StartDate AND @EndDate))
		      OR((@StartDate BETWEEN q.StartDate AND q.EndDate) AND(@EndDate BETWEEN q.StartDate AND q.EndDate))) 

		IF @ShowRecordedVisits = 0 
		BEGIN 
			DELETE FROM #Result1 WHERE Answer <> '' 
		END 
		 
		IF @ShowNotRecordedVisits = 0 
		BEGIN 
			DELETE FROM #Result1 WHERE Answer = '' 
		END 
		IF @ShowNotRecordedVisits = 1 
		BEGIN 
			DELETE #Result1 
			FROM #Result1 AS r1 
			INNER JOIN DistQuestionnaire000 AS q ON r1.QuestionnaireGuid = q.Guid 
			WHERE (r1.QuestionnaireGuid <> @QuestionnaireGuid AND @QuestionnaireGuid <> 0x0)
			   AND r1.VisitDate NOT BETWEEN q.StartDate AND q.EndDate 
		END 
		-- Return #Result1 
		SELECT * FROM #Result1 
		ORDER BY 
			DistName, 
			CustName,
			VisitDate,
			VisitState,
			QuestionnaireGuid,
			QuestionnaireName, 			
			QuestionGuid,
			Question
	END 
	-- Grouped Result Set 
	IF @ResultType = 2 
	BEGIN 
		-- Get the count of recorded questions 
		CREATE TABLE #QuestionsCount 
		( 
			QuestionGuid	UNIQUEIDENTIFIER, 
			QuestionCount	INT 
		) 
		INSERT INTO #QuestionsCount 
		SELECT 
			qa.QuestGuid, 
			Count(1) 
		FROM DistQuestAnswers000 AS qa 
		INNER JOIN DistQuestQuestion000 AS qu ON qu.Guid = qa.QuestGuid 
		INNER JOIN DistVi000 AS vi ON vi.Guid = qa.VisitGuid 
		INNER JOIN DistTr000 AS tr ON tr.Guid = vi.TripGuid 
		WHERE (tr.Date BETWEEN @StartDate AND @EndDate) AND qu.Type = 1 
		GROUP BY qa.QuestGuid 
	
		-- Fill the result table 
		CREATE TABLE #Result2 
		( 
			QuestionnaireGuid			UNIQUEIDENTIFIER, 
			QuestionnaireName			NVARCHAR(250), 
			QuestionGuid			UNIQUEIDENTIFIER, 
			QuestionText			NVARCHAR(250), 
			TotalRecordedQuestions	FLOAT, 
			Answer					NVARCHAR(250), 
			AnswerCount				FLOAT, 
			AnswerPercent			FLOAT 
		) 
		INSERT INTO #Result2 
		SELECT 
			q.QuestGuid,
			q.QuestName,
			q.QuestionGuid, 
			q.QuestionText, 
			qc.QuestionCount, 
			ISNULL(q.Answer, ''), 
			COUNT(ISNULL(q.Answer, 0)), 
			0 
		FROM #QuestionsCount AS qc 
		INNER JOIN VwDistQuestAnswers AS q ON q.QuestionGuid = qc.QuestionGuid
		INNER JOIN DistVi000 AS vi ON vi.Guid = q.VisitGuid 
		INNER JOIN DistTr000 AS tr ON tr.Guid = vi.TripGuid 
		INNER JOIN  #DistTbl AS d1 ON d1.DistGuid = tr.DistributorGuid		
		WHERE ((q.StartDate BETWEEN @StartDate AND @EndDate) AND (q.EndDate BETWEEN @StartDate AND @EndDate)) 
		  AND (tr.Date BETWEEN @StartDate AND @EndDate) 
		  AND (tr.DistributorGuid IN (SELECT DistGuid FROM #DistTbl)) 
		  AND (q.QuestGuid = @QuestionnaireGuid OR @QuestionnaireGuid = 0x0)
		  AND q.Type = 1 
		GROUP BY 
			q.QuestGuid, 
			q.QuestName, 
			q.QuestionGuid, 
			q.QuestionText, 
			qc.QuestionCount, 
			q.Answer 		
		ORDER BY
			q.QuestName, 
			q.QuestionText, 
			q.Answer	
			
		UPDATE #Result2 
		SET 
			AnswerPercent = Case TotalRecordedQuestions When 0 THEN 0 ELSE AnswerCount / TotalRecordedQuestions  END
	
		-- Return #Result1 
		SELECT * FROM #Result2 
		-- Get the max number of answers 
		SELECT MAX(c.AnswersCount) AS MaxCount FROM (SELECT COUNT(*) AS AnswersCount FROM #Result2 GROUP BY QuestionGuid) as c 
	END 
################################################################################
#END	