####################################################################
CREATE PROCEDURE prcDistCalcGeneralTargetRev
	@PeriodGUID		UNIQUEIDENTIFIER,
	@BranchGUID		UNIQUEIDENTIFIER
AS
	SET NOCOUNT ON
	SELECT
		SUM(CustTarget) AS NewTarget,
		MatGuid
	INTO #NewMatTargets
	FROM distcustmattarget000 AS ct
	WHERE PeriodGuid = @PeriodGUID AND BranchGuid = @BranchGUID
	GROUP BY MatGuid
	
	UPDATE disgeneraltarget000
		SET Qty = NewTarget
		FROM disgeneraltarget000 AS gt
		INNER JOIN #NewMatTargets AS nt ON gt.MatGuid = nt.MatGuid
		WHERE	PeriodGuid = @PeriodGUID AND
				BranchGuid = @BranchGUID
####################################################################
CREATE PROCEDURE prcDistCalcMatCustTargetRev
	@DistGuid		UNIQUEIDENTIFIER,
	@PeriodGUID		UNIQUEIDENTIFIER,
	@BranchGUID		UNIQUEIDENTIFIER
AS
	SET NOCOUNT ON

	DECLARE @PriceType INT,
			@CurGuid UNIQUEIDENTIFIER,
			@EPDate DATETIME

	SELECT TOP 1 @PriceType = PriceType FROM vbDistCustTarget WHERE PeriodGuid = @PeriodGuid AND BranchGuid = @BranchGuid AND DistGuid = @DistGuid
	SELECT TOP 1 @CurGuid = CurGuid FROM vbDistCustTarget WHERE PeriodGuid = @PeriodGuid AND BranchGuid = @BranchGuid AND DistGuid = @DistGuid
	SELECT @EPDate = GETDATE()
	SET @PriceType = @PriceType * 2

	DECLARE @TotalMaterialsSales FLOAT
	SELECT @TotalMAterialsSales = SUM(ExpectedCustTarget) FROM vbDistCustMatTarget WHERE PeriodGuid = @PeriodGUID AND BranchGuid = @BranchGUID
	
	CREATE TABLE #MaterialsSales (MatGuid UNIQUEIDENTIFIER, MatSales FLOAT)
	INSERT INTO #MaterialsSales
	(
		MatGuid,
		MatSales
	)
	SELECT
		MatGuid,
		SUM(ExpectedCustTarget)
	FROM vbDistCustMatTarget
	WHERE PeriodGuid = @PeriodGUID AND BranchGuid = @BranchGUID
	GROUP BY MatGuid

	SELECT
		DistGuid,
		CustGuid,
		TotalCustTarget AS NewTarget,
		TotalCustCalcedTarget AS OldTarget
	INTO #CustTargets
	FROM vbDistCustTarget AS ct
	WHERE PeriodGuid = @PeriodGUID AND BranchGuid = @BranchGUID

	SELECT DISTINCT
		CASE ct.OldTarget 
			 WHEN 0 THEN ms.MatSales / (CASE @TotalMaterialsSales WHEN 0 THEN 1 ELSE @TotalMaterialsSales END)
			 ELSE (cmt.ExpectedCustTarget * dct.CustDistRatio) / (CASE(ct.OldTarget/ CASE m.mtPrice WHEN 0 THEN 1 ELSE m.mtPrice END)WHEN 0 THEN 1 ELSE (ct.OldTarget/ CASE m.mtPrice WHEN 0 THEN 1 ELSE m.mtPrice END)END) 
		END AS MatPercent ,
		cmt.MatGuid,
		ct.Custguid,
		ct.DistGuid
	INTO #MatCustPercent
	FROM #CustTargets AS ct
	INNER JOIN vbDistCustMatTarget AS cmt ON ct.CustGuid = cmt.CustGuid
	INNER JOIN DistCustTarget000 AS dct ON ct.CustGuid = dct.CustGuid
	LEFT JOIN #MaterialsSales AS ms ON cmt.MatGuid = ms.MatGuid
	INNER JOIN [dbo].[fnGetMtPricesWithSec] (@PriceType, 0, 0, @CurGuid, @EPDate) AS m ON m.mtGuid = cmt.MatGuid
	WHERE cmt.PeriodGuid = @PeriodGUID AND cmt.BranchGuid = @BranchGUID
	ORDER BY ct.Custguid

	select
		cmt.CustGuid,
		cmt.MatGuid,
		ISNULL(SUM(((ct.NewTarget - ct.OldTarget) / CASE m.mtPrice WHEN 0 THEN 1 ELSE m.mtPrice END) * cp.MatPercent), 0) AS Target
	INTO #FinalTargets
	FROM distcustmattarget000 AS cmt
	INNER JOIN #MatCustPercent AS cp ON cmt.CustGuid = cp.CustGuid AND cmt.MatGuid = cp.MatGuid
	INNER JOIN #CustTargets AS ct ON cmt.CustGuid = ct.CustGuid
	INNER JOIN [dbo].[fnGetMtPricesWithSec] (@PriceType, 0, 0, @CurGuid, @EPDate) AS m ON m.mtGuid = cmt.MatGuid
	GROUP BY
		cmt.MatGuid, cmt.CustGuid

	UPDATE distcustmattarget000
		SET CustTarget = cmt.ExpectedCustTarget + ft.Target
	FROM distcustmattarget000 AS cmt
	INNER JOIN #FinalTargets AS ft ON cmt.CustGuid = ft.CustGuid AND cmt.MatGuid = ft.MatGuid
/*
exec prcDistCalcMatCustTargetRev '130FEBED-C9B4-4093-972C-C619D8A5B7B3', 'E478E48C-718B-48E3-B79A-5FB7ECAF68C7' 
*/
####################################################################
CREATE PROCEDURE prcDistCalcCustTargetRev
	@PeriodGUID		UNIQUEIDENTIFIER,
	@BranchGUID		UNIQUEIDENTIFIER
AS
	SET NOCOUNT ON
	CREATE TABLE #DistributorTarget (DistGuid UNIQUEIDENTIFIER, OldTarget FLOAT, NewTarget FLOAT, TargetDifference FLOAT)
	CREATE TABLE #DistOldTarget (DistGuid UNIQUEIDENTIFIER, OldTarget FLOAT)
	CREATE TABLE #CustPercent (CustGuid UNIQUEIDENTIFIER, CustPercent FLOAT, TargetDiff FLOAT)

	INSERT INTO #DistOldTarget
	(
		DistGuid,
		OldTarget
	)
	SELECT
		DistGuid,
		SUM(TotalCustTarget)
	FROM distcusttarget000
	WHERE PeriodGuid = @PeriodGuid AND BranchGuid = @BranchGuid
	GROUP BY DistGuid

	INSERT INTO #DistributorTarget
	(
		DistGuid,
		OldTarget,
		NewTarget,
		TargetDifference
	)
	SELECT
		dt.DistGuid,
		ot.OldTarget,
		dt.GeneralTargetVal,
		dt.GeneralTargetVal - ot.OldTarget
	FROM DistDistributorTarget000 AS dt
	INNER JOIN #DistOldTarget AS ot ON dt.DistGuid = ot.DistGuid
	WHERE PeriodGuid = @PeriodGuid AND BranchGuid = @BranchGuid

	DECLARE @C CURSOR,
			@DistGuid UNIQUEIDENTIFIER,
			@OldTarget FLOAT,
			@NewTarget FLOAT,
			@Difference FLOAT

	SET @C = CURSOR FOR SELECT DistGuid, OldTarget, NewTarget, TargetDifference FROM #DistributorTarget
	OPEN @C
	FETCH @C INTO @DistGuid, @OldTarget, @NewTarget, @Difference
	WHILE @@FETCH_STATUS = 0
	BEGIN
		IF(@Difference <> 0)
		BEGIN
			--Claculate the percent of each customer target to the total target of the distributor
			INSERT INTO #CustPercent
			(
				CustGuid,
				CustPercent,
				TargetDiff
			)
			SELECT
				ct.CustGuid,
				ct.TotalCustTarget / @OldTarget,
				0
			FROM DistCustTarget000 AS ct
			WHERE ct.DistGuid = @DistGuid AND PeriodGuid = @PeriodGuid AND BranchGuid = @BranchGuid

			--Claculate the difference in the target of each customer based on the calculate percent
			UPDATE #CustPercent
				SET TargetDiff = @Difference * CustPercent

			--Add the Target Difference to the customers targets
			UPDATE DistCustTarget000
				SET TotalCustTarget = ct.TotalCustTarget + cp.TargetDiff
			FROM DistCustTarget000 AS ct
			INNER JOIN #CustPercent AS cp ON ct.CustGuid = cp.CustGuid
			WHERE ct.DistGuid = @DistGuid AND PeriodGuid = @PeriodGuid AND BranchGuid = @BranchGuid
		END

		FETCH @C INTO @DistGuid, @OldTarget, @NewTarget, @Difference
	END
	CLOSE @C
	DEALLOCATE @C
/*
exec prcDistCalcCustTargetRev '130FEBED-C9B4-4093-972C-C619D8A5B7B3', 'E478E48C-718B-48E3-B79A-5FB7ECAF68C7' 
*/
####################################################################
#END