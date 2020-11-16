###############################################
CREATE PROCEDURE prcOutbalanceAveragePrice
	@StartDate DATE,
	@EndDate DATE,
	@GroupGuid UNIQUEIDENTIFIER,
	@IgnoreEmptyMaterials BIT
AS
	SET NOCOUNT ON
	
	DECLARE @EOMonth DATE = DATEADD(D, -1, DATEADD(M, 1, @StartDate)), @FPDate DATE;
		
	SET @EndDate = DATEADD(D, -1, DATEADD(M, 1, @EndDate));
	SET @FPDate = [dbo].[fnDate_Amn2Sql]([dbo].[fnOption_get]('AmnCfg_FPDate', default));

	DECLARE @Ignored TABLE(
		MaterialGuid UNIQUEIDENTIFIER,
		Quantity FLOAT);

	WHILE (@StartDate < @EndDate)
	BEGIN

		DELETE @Ignored;

		INSERT INTO @Ignored
		SELECT
			M.Guid AS MaterialGuid,
			ISNULL(SUM((biQty + biBonusQnt) * btIsInput - (biQty + biBonusQnt) * btIsOutput), 0) AS Quantity
		FROM
			fnGetMaterialsList(@GroupGuid) M
			LEFT JOIN vwExtended_bi Bi ON Bi.biMatPtr = M.[GUID]
		WHERE
			MONTH(@FPDate) = MONTH(@StartDate) AND YEAR(@FPDate) = YEAR(@StartDate) 
			AND (buDate BETWEEN @StartDate AND @EndDate OR Bi.biMatPtr IS NULL)
			AND (Bi.buIsPosted = 1 OR Bi.biMatPtr IS NULL)
			AND @IgnoreEmptyMaterials = 1
		GROUP BY
			M.Guid
		HAVING 
			ISNULL(SUM((biQty + biBonusQnt) * btIsInput - (biQty + biBonusQnt) * btIsOutput), 0) = 0;

		IF (@IgnoreEmptyMaterials = 1 AND MONTH(@FPDate) = MONTH(@StartDate) AND YEAR(@FPDate) = YEAR(@StartDate))
		BEGIN
			DELETE FROM oap000 
			WHERE 
				StartDate BETWEEN @StartDate AND EndDate 
				AND MaterialGuid NOT IN (SELECT MaterialGuid FROM @Ignored);
		END
		ELSE
		BEGIN
			DELETE oap000 WHERE StartDate BETWEEN @StartDate AND EndDate 
		END

		INSERT INTO oap000
		SELECT 
			s.MaterialGuid,
			@StartDate,
			@EOMonth,
			ISNULL(s.Price, 0),
			newID()
		FROM 
			fnCalcOutbalanceAveragePrice(@StartDate, @EOMonth, 0x0, @GroupGuid) AS s
		WHERE
			((@IgnoreEmptyMaterials = 1 AND NOT EXISTS(SELECT * FROM @Ignored i WHERE i.MaterialGuid = s.MaterialGuid)) OR @IgnoreEmptyMaterials = 0)
			--LEFT JOIN @Ignored i ON ((i.MaterialGuid <> s.MaterialGuid AND @IgnoreEmptyMaterials = 1) OR @IgnoreEmptyMaterials = 0);

		SET @StartDate = DATEADD(M, 1, @StartDate);
		SET @EOMonth = DATEADD(D, -1, DATEADD(M, 1, @StartDate));
	END
############################################### 
#END