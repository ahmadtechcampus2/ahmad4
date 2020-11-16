###########################################################
### «‰Õ—«› Œÿ…

CREATE PROCEDURE repManPlanTun
( 
		@MaterialGuid UNIQUEIDENTIFIER = 0x0,
		@GroupGuid    UNIQUEIDENTIFIER = 0x0,
		@FormGuid	  UNIQUEIDENTIFIER = 0x0, 
		@CostGuid	  UNIQUEIDENTIFIER = 0x0, 
		@StartDate    DATETIME = '1-1-1900' , 
		@EndDate      DATETIME,
		@CostDetails  int = 0,
		@PlanState	  int = 0,
		@OrderBy	  int = 0,
		@GroupBy	  int = 0
)		 
AS 
SET NOCOUNT ON 

DECLARE @Lang INT = [dbo].[fnConnections_GetLanguage]();

SELECT 
	fm.Code FormCode,
	CASE WHEN @Lang > 0 THEN CASE WHEN fm.LatinName = '' THEN fm.Name ELSE fm.LatinName END ELSE fm.Name END FormName,
	CASE WHEN @Lang > 0 THEN CASE WHEN co.LatinName = '' THEN co.Name ELSE co.LatinName END ELSE co.Name END CostName,
	CASE WHEN @Lang > 0 THEN CASE WHEN gr.LatinName = '' THEN gr.Name ELSE gr.LatinName END ELSE gr.Name END GroupName,
	CASE WHEN @Lang > 0 THEN CASE WHEN mt.LatinName = '' THEN mt.Name ELSE mt.LatinName END ELSE mt.Name END MaterialName,
	mi.MatGUID,
	Sum(mi.Qty * ps.Qty) PlannedQuantity,
	ISNULL
	(
		(
			SELECT Sum(bi.Qty) ActualQuantity
			FROM mn000 InnerMn
				INNER JOIN mb000 mb ON mb.ManGUID = InnerMn.GUID
				INNER JOIN bi000 bi ON bi.ParentGUID = mb.BillGUID
				INNER JOIN bu000 bu ON bi.ParentGUID = bu.GUID
			WHERE InnerMn.Type = 1 AND
				  mb.Type = 1 AND
				  InnerMn.FormGuid = fm.Guid AND
				  bi.MatGUID = mi.MatGuid AND
				  (bu.Date BETWEEN @StartDate AND @EndDate) AND
				  (InnerMn.InCostGUID = mn.InCostGUID OR @CostDetails = 0)
			GROUP BY InnerMn.FormGUID, bi.MatGUID
		)
	, 0) ActualQuantity
INTO #Tmp
FROM MI000 mi
	INNER JOIN mt000 mt ON mt.GUID = mi.MatGUID
	INNER JOIN gr000 gr ON gr.GUID = mt.GroupGUID
	INNER JOIN mn000 mn ON mn.Guid = mi.ParentGUID 
	INNER JOIN fm000 fm ON fm.GUID = mn.FormGUID
	INNER JOIN PSI000 ps ON ps.FormGuid = fm.GUID
	LEFT JOIN co000 co ON mn.InCostGUID = co.GUID 
WHERE 
	mn.Type = 0 AND
	mi.Type = 0 AND
	(mi.MatGUID = @MaterialGuid OR @MaterialGuid = 0x0) AND
	(mt.GroupGUID = @GroupGuid OR @GroupGuid = 0x0) AND
	(mn.FormGUID = @FormGuid OR @FormGuid = 0x0) AND
	(mn.InCostGUID = @CostGuid OR @CostGuid = 0x0) AND
	(ps.StartDate BETWEEN @StartDate AND @EndDate) AND
	(ps.State != 2 OR @PlanState = 0)
GROUP BY fm.Guid, fm.Code, 
		CASE WHEN @Lang > 0 THEN CASE WHEN fm.LatinName = '' THEN fm.Name ELSE fm.LatinName END ELSE fm.Name END,
		mn.InCostGUID,
		CASE WHEN @Lang > 0 THEN CASE WHEN co.LatinName = '' THEN co.Name ELSE co.LatinName END ELSE co.Name END,
		CASE WHEN @Lang > 0 THEN CASE WHEN gr.LatinName = '' THEN gr.Name ELSE gr.LatinName END ELSE gr.Name END,
		mi.MatGuid,
		CASE WHEN @Lang > 0 THEN CASE WHEN mt.LatinName = '' THEN mt.Name ELSE mt.LatinName END ELSE mt.Name END
UNION  -- ·œ„Ã Õ«·… ⁄„·Ì«   ’‰Ì⁄ »œÊ‰ Œÿ…
SELECT 
	fm.Code FormCode,
	CASE WHEN @Lang > 0 THEN CASE WHEN fm.LatinName = '' THEN fm.Name ELSE fm.LatinName END ELSE fm.Name END FormName,
	CASE WHEN @Lang > 0 THEN CASE WHEN co.LatinName = '' THEN co.Name ELSE co.LatinName END ELSE co.Name END CostName,
	CASE WHEN @Lang > 0 THEN CASE WHEN gr.LatinName = '' THEN gr.Name ELSE gr.LatinName END ELSE gr.Name END GroupName,
	CASE WHEN @Lang > 0 THEN CASE WHEN mt.LatinName = '' THEN mt.Name ELSE mt.LatinName END ELSE mt.Name END MaterialName,
	mi.MatGUID,
	0 PlannedQuantity,
	Sum(bi.Qty) ActualQuantity
FROM MI000 mi
	INNER JOIN mt000 mt ON mt.GUID = mi.MatGUID
	INNER JOIN gr000 gr ON gr.GUID = mt.GroupGUID
	INNER JOIN mn000 mn ON mn.Guid = mi.ParentGUID 
	INNER JOIN fm000 fm ON fm.GUID = mn.FormGUID
	INNER JOIN mn000 mn2 ON mn2.FormGuid = fm.GUID -- «·‰„Ê–Ã «·√’·Ì
	INNER JOIN mb000 mb ON mb.ManGUID = mn.GUID
	INNER JOIN bi000 bi ON bi.ParentGUID = mb.BillGUID AND bi.MatGUID = mi.MatGUID
	INNER JOIN bu000 bu ON bu.GUID = bi.ParentGUID
	LEFT JOIN co000 co ON mn.InCostGUID = co.GUID 
WHERE 
	mn.Type = 1 AND
	mn2.Type = 0 AND
	mi.Type = 0 AND
	mb.Type = 1 AND
	(mi.MatGUID = @MaterialGuid OR @MaterialGuid = 0x0) AND
	(mt.GroupGUID = @GroupGuid OR @GroupGuid = 0x0) AND
	(mn.FormGUID = @FormGuid OR @FormGuid = 0x0) AND
	(mn.InCostGUID = @CostGuid OR @CostGuid = 0x0) AND
	(mn.InCostGUID <> mn2.InCostGUID AND @CostDetails = 1) AND
	(bu.Date BETWEEN @StartDate AND @EndDate)
GROUP BY CASE WHEN @Lang > 0 THEN CASE WHEN co.LatinName = '' THEN co.Name ELSE co.LatinName END ELSE co.Name END,
		fm.Guid,
		fm.Code,
		CASE WHEN @Lang > 0 THEN CASE WHEN fm.LatinName = '' THEN fm.Name ELSE fm.LatinName END ELSE fm.Name END,
		mn.InCostGUID,
		CASE WHEN @Lang > 0 THEN CASE WHEN gr.LatinName = '' THEN gr.Name ELSE gr.LatinName END ELSE gr.Name END,
		mi.MatGuid,
		CASE WHEN @Lang > 0 THEN CASE WHEN mt.LatinName = '' THEN mt.Name ELSE mt.LatinName END ELSE mt.Name END
		
IF @GroupBy = 0-- »œÊ‰  Ã„Ì⁄
BEGIN
	SELECT 
		t.*,
		PlannedQuantity - ActualQuantity Deviation,
		ISNULL((ActualQuantity / NULLIF(PlannedQuantity, 0)) * 100, 0) UsePercentage,
		ISNULL(((PlannedQuantity - ActualQuantity) / NULLIF(PlannedQuantity, 0)) * 100, 0) NonUsePercentage
	INTO #Tmp2
	FROM #Tmp t

		-- Ordering
	IF @OrderBy =0
		SELECT * FROM #Tmp2 ORDER BY MaterialName
	ELSE IF @OrderBy = 1
		SELECT * FROM #Tmp2 ORDER BY FormCode, MaterialName
	ELSE
		SELECT * FROM #Tmp2 ORDER BY FormName, MaterialName
END
ELSE
BEGIN
	CREATE Table #Result
	(
		FormCode nvarchar(255),
		FormName nvarchar(255),
		CostName nvarchar(255),
		GroupName nvarchar(255),
		MaterialName nvarchar(255),
		PlannedQuantity Float,
		ActualQuantity Float,
	)

	IF @GroupBy = 1--  Ã„Ì⁄ Õ”» «·‰„Ê–Ã
	BEGIN
		INSERT INTO #Result
		SELECT 
			t.FormCode,
			t.FormName,
			t.CostName,
			'' GroupName,
			'' MaterialName,
			Sum(PlannedQuantity) PlannedQuantity,
			Sum(ActualQuantity) ActualQuantity
		FROM #Tmp t
		GROUP BY FormCode, FormName, CostName
	END
	 IF @GroupBy = 2--  Ã„Ì⁄ Õ”» «·„Ã„Ê⁄…
	BEGIN
		INSERT INTO #Result
		SELECT 
			'' FormCode,
			'' FormName,
			'' CostName,
			t.GroupName,
			'' MaterialName,
			Sum(PlannedQuantity) PlannedQuantity,
			Sum(ActualQuantity) ActualQuantity
		FROM #Tmp t
		GROUP BY GroupName
	END
	ELSE IF @GroupBy = 3--  Ã„Ì⁄ Õ”» „—ﬂ“ «·ﬂ·›…
	BEGIN
		INSERT INTO #Result
		SELECT 
			'' FormCode,
			'' FormName,
			t.CostName,
			'' MaterialName,
			'' GroupName,
			Sum(PlannedQuantity) PlannedQuantity,
			Sum(ActualQuantity) ActualQuantity
		FROM #Tmp t
		GROUP BY CostName
	END

	SELECT 
		*,
		PlannedQuantity - ActualQuantity Deviation,
		ISNULL((ActualQuantity / NULLIF(PlannedQuantity, 0)) * 100, 0) UsePercentage,
		ISNULL(((PlannedQuantity - ActualQuantity) / NULLIF(PlannedQuantity, 0)) * 100, 0) NonUsePercentage
	FROM #Result

END

###########################################################
#END
