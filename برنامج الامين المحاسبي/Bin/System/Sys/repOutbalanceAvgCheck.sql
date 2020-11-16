#################################################################
CREATE PROCEDURE repOutbalanceAvgCheck
	@FilterMatGuid		UNIQUEIDENTIFIER, 
	@FilterGroupGuid	UNIQUEIDENTIFIER, 
	@FromPeriod			DATE,
	@Unit				INT, 
	@SortBy				INT, 
	@GroupByType		BIT, 
	@ShowCode			BIT,  
	@ShowUnit			BIT,
	@ShowMatching		BIT
AS 
	SET NOCOUNT ON; 
	
	DECLARE  
		@MatGuid			UNIQUEIDENTIFIER, 
		@PrevMatGuid		UNIQUEIDENTIFIER = 0x, 
		@PeriodID			INT, 
		@PrevPeriodID		INT = -1,
		@PeriodPrice		FLOAT,
		@PeriodQty			FLOAT, 
		@FPQty				FLOAT,
		@FPValue			FLOAT, 
		@PrevPeriodPrice	FLOAT = 0,
		@TotalQty			FLOAT = 0,
		@PeriodStartDate	DATE,
		@ToPeriod			DATE,
		@Lang				INT,
		@PrevPeriod			DATE,
		@StartPeriodDate	DATE;

	SET @ToPeriod = DATEADD(day, -1, DATEADD(month, MONTH(@FromPeriod), DATEADD(year, CAST(YEAR(@FromPeriod) AS VARCHAR(4))-1900,0))) /*Month Last Day*/
	SET @Lang = dbo.fnConnections_GetLanguage();
	SET @PrevPeriod = (SELECT CASE WHEN @FromPeriod = (SELECT CONVERT(DATETIME, [Value], 105) FROM [op000] WHERE [Name] = N'AmnCfg_FPDate') THEN @ToPeriod ELSE DATEADD(DAY,-1,@FromPeriod) END);

	CREATE TABLE #SecViol([Type] INT, Cnt INT);  
	CREATE TABLE #Material (Number UNIQUEIDENTIFIER, Security INT); 
	INSERT INTO  #Material EXEC prcGetMatsList @FilterMatGuid, @FilterGroupGuid; 
	
	CREATE TABLE #Result 
	(   
		PeriodID		INT,
		MatGuid			UNIQUEIDENTIFIER,
		TypeGuid		UNIQUEIDENTIFIER,
		TypeId			INT,
		Input			INT,
		Qty				FLOAT, 
		Value			FLOAT,
		PeriodPrice		FLOAT,
		PeriodType		INT,
		StartDate		DATE,
		MatSecurity		TINYINT
	);
	 
	/*
		Calculate quantity and value for bill types that affect cost excluding first period type
	*/
	INSERT INTO #Result
	SELECT 
		0,
		B.biMatPtr,
		B.buType,
		B.btBillType,
		B.btIsInput,
		B.biQty + B.biBonusQnt,
		B.biQty * B.biUnitPrice + (B.btExtraAffectCost * B.biUnitExtra * B.biQty) - (B.btDiscAffectCost * B.biUnitDiscount * B.biBillQty),
		0, 
		0,
		@FromPeriod,
		M.Security
	FROM
		vwExtended_bi B JOIN bt000 T ON B.buType = T.GUID
		JOIN #Material M ON B.biMatPtr = M.Number
	WHERE
		B.buIsPosted <> 0 AND B.btAffectCostPrice <> 0 
		AND NOT (T.Type = 2 AND T.SortNum = 1 AND T.BillType = 4)
		AND B.buDate BETWEEN @FromPeriod AND @ToPeriod;

	EXEC prcCheckSecurity;
	/*
		Calculate quantity and value for first period and last period
		using PeriodType column as discriminator
		1	first period
		2	last period
	*/
	DECLARE C CURSOR FAST_FORWARD FOR 
		WITH Bills AS 
		(
			SELECT 
				biMatPtr,
				SUM((CASE btIsInput WHEN 1 THEN 1 ELSE -1 END) * (biQty + biBonusQnt)) AS PeriodQty,
				SUM((biQty + biBonusQnt) * btIsInput - (biQty + biBonusQnt) * btIsOutput) AS Quantity,
				SUM(
					(CASE @PrevPeriod WHEN @ToPeriod THEN biUnitPrice ELSE [dbo].fnGetOutbalanceAveragePrice(biMatPtr, @PrevPeriod) END)
					* ISNULL((biQty + biBonusQnt) * btIsInput - (biQty + biBonusQnt) * btIsOutput, 0)
					) AS Price
			FROM
				vwExtended_bi Bi 
				JOIN bt000 T ON Bi.buType = T.GUID 
			WHERE
				 Bi.buDate <= @PrevPeriod 
				 AND Bi.buIsPosted = 1
				 AND ((@PrevPeriod = @ToPeriod AND T.SortNum = 1 AND T.Type = 2 AND T.BillType = 4) OR @PrevPeriod <> @ToPeriod)
			GROUP BY
	           biMatPtr
			HAVING
				SUM(ISNULL((biQty + biBonusQnt) * btIsInput - (biQty + biBonusQnt) * btIsOutput, 0)) <> 0
		),
		OAP AS
		(
			SELECT 
				MaterialGuid, 
				StartDate, 
				EndDate, 
				MIN(Price) Price 
			FROM 
				oap000 
			GROUP BY 
				MaterialGuid,
				StartDate, 
				EndDate 
		)
		SELECT
			0,
			M.[GUID],
			@FromPeriod,
			ISNULL(P.Price, 0) AS PeriodPrice,
			ISNULL(PeriodQty, 0),
            ISNULL(Quantity, 0),
            ISNULL(Bi.Price, 0)
        FROM
			fnGetMaterialsList(@FilterGroupGuid) M
			LEFT JOIN OAP AS P ON M.[GUID] = P.MaterialGuid AND p.StartDate BETWEEN @FromPeriod AND @ToPeriod
			LEFT JOIN Bills AS Bi ON Bi.biMatPtr = M.[GUID]
        WHERE
            (@FilterMatGuid = 0x0 OR @FilterMatGuid = M.[GUID]);

	OPEN C; 
	FETCH NEXT FROM C INTO @PeriodID, @MatGuid, @PeriodStartDate, @PeriodPrice, @PeriodQty, @FPQty, @FPValue;
	
	WHILE @@FETCH_STATUS = 0 
	BEGIN 
		IF @MatGuid <> @PrevMatGuid 
			SELECT @TotalQty = 0, @PrevPeriodID = -1, @PrevPeriodPrice = 0, @TotalQty = @PeriodQty;
		IF @PeriodStartDate >= @FromPeriod
		BEGIN
			INSERT INTO #Result(PeriodID, MatGuid, TypeGuid, TypeId, Qty, Value, PeriodPrice, PeriodType, StartDate) VALUES
			(
				@PeriodID,
				@MatGuid,
				0x, 
				4,
				CASE WHEN @PrevPeriodID = -1 THEN @FPQty ELSE @TotalQty END,
				CASE WHEN @PrevPeriodID = -1 THEN @FPValue ELSE @PrevPeriodPrice * (@TotalQty + @FPQty) END,
				@PeriodPrice,
				1,
				@PeriodStartDate
			),
			(
				@PeriodID, @MatGuid, 0x, 5,
				@TotalQty/* + @PeriodQty*/,
				(@TotalQty/* + @PeriodQty*/) * @PeriodPrice,
				@PeriodPrice,
				2,
				@PeriodStartDate
			);
		END
		SET @TotalQty += @PeriodQty;
		SELECT @PrevMatGuid = @MatGuid, @PrevPeriodID = @PeriodID, @PrevPeriodPrice = @PeriodPrice;
		FETCH NEXT FROM C INTO @PeriodID, @MatGuid, @PeriodStartDate, @PeriodPrice, @PeriodQty, @FPQty, @FPValue;
	END
	CLOSE C;
	DEALLOCATE C;

	UPDATE R
	SET 
		R.Qty = R.Qty / CASE 
							WHEN @Unit = 1 OR (@Unit = 3 AND mt.DefUnit = 2) THEN CASE WHEN mt.Unit2Fact = 0 THEN 1 ELSE mt.Unit2Fact END
							WHEN @Unit = 2 OR (@Unit = 3 AND mt.DefUnit = 3) THEN CASE WHEN mt.Unit3Fact = 0 THEN 1 ELSE mt.Unit3Fact END
							ELSE 1
						END,
		R.PeriodPrice = R.PeriodPrice * CASE 
				WHEN @Unit = 1 OR (@Unit = 3 AND mt.DefUnit = 2) THEN CASE WHEN mt.Unit2Fact = 0 THEN 1 ELSE mt.Unit2Fact END
				WHEN @Unit = 2 OR (@Unit = 3 AND mt.DefUnit = 3) THEN CASE WHEN mt.Unit3Fact = 0 THEN 1 ELSE mt.Unit3Fact END
				ELSE 1
			END
	FROM 
		#Result R
		INNER JOIN mt000 as mt ON mt.Guid = R.MatGuid;

	-- add materials that does not has movment in the current period
	INSERT INTO #Result
	SELECT DISTINCT
		0 as PeriodID,
		MatGuid,
		(SELECT TOP 1 TypeGuid FROM #Result WHERE TypeGuid IS NOT NULL) as TypeGuid,
		0 as TypeId,
		0 as Input,
		0 as Qty,
		0 as Value,
		0 as PeriodPrice,
		0 as PeriodType,
		StartDate,
		1 as MatSecurity
	FROM 
		#Result r 
		JOIN mt000 mt ON r.MatGuid = mt.Guid
	WHERE 
		TypeId IN(4, 5) AND NOT EXISTS(SELECT * FROM #Result WHERE TypeId IN(0, 1) AND MatGuid = r.MatGuid)
		AND r.Qty <> 0

	DECLARE @Sql NVARCHAR(MAX);
	SET @Sql = 'WITH R AS (SELECT MatGuid, ';
	IF @GroupByType = 1
		SET @Sql += 'TypeId,Input, ';
	ELSE
		SET @Sql += 'TypeGuid, ';
	SET @Sql += 'SUM(Qty) AS Qty, SUM(Value) AS Value, 0 AS PeriodType
			FROM #Result r
			WHERE PeriodType = 0 
			GROUP BY MatGuid, ';
	IF @GroupByType = 1
		SET @Sql += 'TypeId ,Input';
	ELSE
		SET @Sql += 'TypeGuid ';
	SET @Sql += ')
		SELECT
			R.MatGuid,
			CASE @Lang WHEN 0 THEN M.Name ELSE (CASE M.LatinName WHEN '''' THEN M.Name ELSE M.LatinName END) END AS MatName,
			CASE @Lang WHEN 0 THEN G.Name ELSE (CASE G.LatinName WHEN '''' THEN G.Name ELSE G.LatinName END) END AS GroupName ';
	
	IF @ShowCode = 1
		SET @Sql += ', M.Code AS MatCode ';
	IF @ShowUnit = 1
		SET @Sql += ', CASE 
							WHEN @Unit = 0 OR (@Unit = 3 AND M.DefUnit = 1) THEN M.Unity 
							WHEN @Unit = 1 OR (@Unit = 3 AND M.DefUnit = 2) THEN CASE WHEN M.Unit2Fact = 0 THEN M.Unity ELSE M.Unit2 END
							WHEN @Unit = 2 OR (@Unit = 3 AND M.DefUnit = 3) THEN CASE WHEN M.Unit3Fact = 0 THEN M.Unity ELSE M.Unit3 END
						END AS Unit'; 
	
	IF @GroupByType = 0
		SET @Sql += ', ISNULL(CASE @Lang WHEN 0 THEN T.Name ELSE (CASE T.LatinName WHEN '''' THEN T.Name ELSE T.LatinName END) END, N'''' )AS TypeName ,T.BillType, T.bIsInput';
	ELSE
		SET @Sql += ', R.TypeId, R.Input ';
			
	SET @Sql += ', R.Qty, R.Value FROM R '
	
	IF @ShowMatching = 0
		SET @Sql += ' JOIN (
			SELECT DISTINCT MatGuid
			FROM #Result
			WHERE PeriodType < 2
			GROUP BY MatGuid, PeriodID
			HAVING 
				(SUM(Value) = 0 AND SUM(PeriodPrice) = 0) 
				OR ABS(SUM(Value) / NULLIF(SUM(Qty), 0) - SUM(PeriodPrice) / NULLIF(SUM(CASE PeriodType WHEN 1 THEN 1 ELSE 0 END), 0)) > dbo.fnGetZeroValuePrice()
		) AS NoMatch ON R.MatGuid = NoMatch.MatGuid';
	SET @Sql += ' JOIN mt000 M ON R.MatGuid = M.GUID JOIN gr000 G ON G.GUID = M.GroupGUID ';
	
	IF @GroupByType = 0
		SET @Sql += 'LEFT JOIN bt000 T ON R.TypeGuid = T.GUID ';
	
	SET @Sql += ' ORDER BY GroupName, ';
	SET @Sql += CASE WHEN @SortBy = 0 AND @ShowCode = 1 THEN 'MatCode' ELSE 'MatName' END;
	EXEC sp_executesql @sql, N'@Lang AS INT, @Unit AS INT', @Lang = @Lang, @Unit = @Unit; 
 
	SELECT 
		R1.MatGuid,
		D1.Qty AS FPQty, 
		D1.Value AS FPValue, 
		D2.Qty AS LPQty, 
		D2.Value AS LPValue, 
		ISNULL(D3.PeriodPrice * CASE 
				WHEN @Unit = 1 OR (@Unit = 3 AND R1.DefUnit = 2) THEN R1.Unit2Fact
				WHEN @Unit = 2 OR (@Unit = 3 AND R1.DefUnit = 3) THEN R1.Unit3Fact
				ELSE 1
			END, 0) PeriodPrice
	FROM 
		(SELECT DISTINCT MatGuid, Unit2Fact, Unit3Fact, DefUnit FROM #Result R JOIN mt000 as mt on mt.Guid = R.MatGuid) R1
		CROSS APPLY (
			SELECT TOP 1 Qty, Value
			FROM #Result R 
			WHERE R.MatGuid = R1.MatGuid AND R.PeriodType = 1
			ORDER BY StartDate
			) AS D1 
		CROSS APPLY (
			SELECT TOP 1 Qty, Value
			FROM #Result R 
			WHERE R.MatGuid = R1.MatGuid AND R.PeriodType = 2
			ORDER BY StartDate DESC
		) AS D2
		CROSS APPLY (
			SELECT AVG(P.Price) AS PeriodPrice
			FROM 
				oap000 P 
			WHERE 
				P.MaterialGuid = R1.MatGuid 
				AND p.StartDate >= @FromPeriod 
				AND p.EndDate   <= @ToPeriod			
		) AS D3;

	SELECT * FROM #SecViol;
#################################################################
#END