####################################################################################################################
CREATE  PROC repOutbalanceAvgPriceList
	@MatGuid		UNIQUEIDENTIFIER=0x0, 
	@GroupGuid		UNIQUEIDENTIFIER=0x0, 
	@FromPeriod		DATE='1-1-2016', 
	@ToPeriod		DATE='12-12-2016', 
	@Unit			INT=0, 
	@SortBy			INT=0, 
	@ShowCode		BIT=0, 
	@ShowGroup		BIT=0, 
	@ShowBalance	BIT=1 
AS 
	SET NOCOUNT ON; 
	
	CREATE TABLE #Materials 
	( 
		Guid		UNIQUEIDENTIFIER, 
		Security	INT 
	); 
	 
	INSERT INTO  #Materials EXEC prcGetMatsList @MatGuid, @GroupGuid; 
	
	DECLARE	@PeriodsNames	NVARCHAR(MAX), 
			@Sql			NVARCHAR(MAX),
			@Period			DATE = @FromPeriod,
			@Lang			INT = dbo.fnConnections_GetLanguage();

	SET @PeriodsNames = '[' + CAST(@FromPeriod AS nvarchar) + ']';

	WHILE @Period < @ToPeriod
	BEGIN
		SET @Period = DATEADD(M, 1, @Period);
		SET @PeriodsNames += ', [' + CAST(@Period AS nvarchar) + ']';
	END
	
	SET @Sql = 'SELECT Guid, Name MtName, '; 
	 
	IF @ShowCode = 1 SET @Sql += 'Code, '; 
	IF @ShowGroup = 1	SET @Sql += 'GroupName, '; 
	IF @ShowBalance = 1 SET @Sql += 'Qty, Unit, '; 
	SET @Sql +=  ' Period,price
		FROM 
		( 
			SELECT M.mtGuid AS Guid, 
				CASE @Lang WHEN 0 THEN M.mtName ELSE (CASE M.mtLatinName WHEN '''' THEN M.mtName ELSE M.mtLatinName END) END AS Name, 
				M.mtCode AS Code, '; 
	IF @ShowGroup = 1	SET @Sql += 'CASE @Lang WHEN 0 THEN G.Name ELSE (CASE G.LatinName WHEN '''' THEN G.Name ELSE G.LatinName END) END AS GroupName, '; 
	 
	IF @ShowBalance = 1  
	BEGIN 
		IF @Unit = 0 
			SET @Sql += 'M.mtQty AS Qty, M.mtUnity AS Unit, '; 
		ELSE IF @Unit = 1 
			SET @Sql += 'M.mtQty / CASE M.mtUnit2Fact WHEN 0 THEN 1 ELSE M.mtUnit2Fact END AS Qty, M.mtUnit2 AS Unit, '; 
		ELSE IF @Unit = 2 
			SET @Sql += 'M.mtQty / CASE M.mtUnit3Fact WHEN 0 THEN 1 ELSE M.mtUnit3Fact END AS Qty, M.mtUnit3 AS Unit, '; 
		ELSE 
			SET @Sql += 'M.mtQty / CASE M.mtDefUnitFact WHEN 0 THEN 1 ELSE M.mtDefUnitFact END AS Qty, M.mtDefUnitName AS Unit, '; 
	END 
	IF @Unit = 0 
		SET @Sql += 'P.Price, '; 
	ELSE IF @Unit = 1 
		SET @Sql += 'P.Price * M.mtUnit2Fact AS Price, '; 
	ELSE IF @Unit = 2 
		SET @Sql += 'P.Price * M.mtUnit3Fact AS Price, '; 
	ELSE 
		SET @Sql += 'P.Price * M.mtDefUnitFact AS Price, '; 
	 
	SET @Sql += 'CAST(P.StartDate AS DATE) AS Period 
			FROM oap000 P  
				JOIN vwMt M ON M.mtGUID = P.MaterialGuid 
				JOIN #Materials F ON F.Guid = M.mtGuid'; 
	 
	IF @ShowGroup = 1 SET @Sql += ' JOIN gr000 G ON G.GUID = M.mtGroup' 
		 
	SET @Sql += ' 
			WHERE P.StartDate BETWEEN @FromPeriod AND @ToPeriod
		) AS D 
		
		ORDER BY '; 
	IF @SortBy = 0 
		SET @Sql += 'Name'; 
	ELSE 
		SET @Sql += 'Code'; 

	EXEC sp_executesql @sql, N'@Lang AS INT, @FromPeriod DATE, @ToPeriod DATE', 
		@Lang = @Lang, @FromPeriod = @FromPeriod, @ToPeriod = @ToPeriod;  
####################################################################################################################
#END