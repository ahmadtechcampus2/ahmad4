##############################
CREATE PROCEDURE prcCalcQuarterTarget
	@PeriodGuid		UNIQUEIDENTIFIER, 
	@CustTypes		NVARCHAR(max), 
	@PricePolicy	INT, 
	@CurGuid		UNIQUEIDENTIFIER, 
	@CurVal 		FLOAT, 
	@UseUnit		INT 
AS 
	SET NOCOUNT ON 
	------------------------------------------ 
	CREATE TABLE #PeriodsList 
	(  
		Name 		NVARCHAR(256) COLLATE ARABIC_CI_AI, 
		Code 		NVARCHAR(256) COLLATE ARABIC_CI_AI, 
		LatinName 	NVARCHAR(256) COLLATE ARABIC_CI_AI, 
		NSons		FLOAT, 
		PeriodGuid 	UNIQUEIDENTIFIER, 
		StartDate	DATETIME, 
		EndDate		DATETIME,	 
		Sort		INT	IDENTITY (1, 1) 
	) 
	INSERT INTO #PeriodsList EXEC prcGetPeriodList  @PeriodGuid,1,0
	------------------------------------------ 
	CREATE TABLE #CustTypes(TypeGuid UNIQUEIDENTIFIER) 
	INSERT INTO #CustTypes SELECT CAST(Data AS UNIQUEIDENTIFIER) FROM fnTextToRows( @CustTypes) 	
	------------------------------------------ 
	-- process Target 
	CREATE TABLE #Result 
	( 
		CustGuid			UNIQUEIDENTIFIER, 
		cuCustomerName		NVARCHAR(256) COLLATE ARABIC_CI_AI, 
		PeriodSort			INT, 
		PeriodGuid			UNIQUEIDENTIFIER, 
		PeriodName			NVARCHAR(256) COLLATE ARABIC_CI_AI, 
		PeriodCode			NVARCHAR(256) COLLATE ARABIC_CI_AI, 
		CustTarget			FLOAT 
	) 
	INSERT INTO #Result 
	SELECT 
		cm.CustGuid, 
		cu.cuCustomerName, 
		Pr.Sort, 
		Pr.PeriodGuid, 
		pr.Name AS PeriodName, 
		pr.Code AS PeriodCode, 
		SUM(cm.TotalCustTarget / cm.CurVal * @CurVal) 
	FROM 
		vwDistCustTarget AS cm 
		INNER JOIN distce000 AS ce ON cm.CustGuid = ce.CustomerGuid 
		INNER JOIN distct000 AS t ON ce.CustomerTypeGuid = t.Guid 
		LEFT JOIN vwCu AS cu ON cu.cuGuid = cm.CustGuid 
		INNER JOIN #CustTypes AS ct ON ct.TypeGuid = t.Guid
		INNER JOIN #PeriodsList AS pr ON Pr.PeriodGuid = cm.PeriodGuid 
	GROUP BY 
		cm.CustGuid, 
		cu.cuCustomerName, 
		Pr.Sort, 
		Pr.PeriodGuid, 
		pr.Name, 
		pr.Code 

	--process Sales  
	CREATE TABLE #PeriodsPrices 
	( 
		PeriodGuid	UNIQUEIDENTIFIER, 
		MatGuid		UNIQUEIDENTIFIER, 
		MatPrice	FLOAT
	) 
	DECLARE @c CURSOR, 
			@Period UNIQUEIDENTIFIER, 
			@PriceType INT,
			@date		DATETIME
	SET @date = getdate()		 
			 
	SET @c = CURSOR FOR SELECT PeriodGuid FROM #PeriodsList 
	OPEN @c FETCH FROM @c INTO @Period 
	WHILE @@FETCH_STATUS = 0 
	BEGIN 
		SELECT TOP 1 @PriceType = PriceType FROM vwDistCustTarget WHERE PeriodGuid = @Period 
		INSERT INTO #PeriodsPrices 
		SELECT 
			@Period, 
			m.mtGUID,
			m.mtPrice 
		FROM dbo.fnGetMtPricesWithSec (@PriceType, @PricePolicy, @UseUnit, @CurGuid, @date) AS m 
		 
		FETCH FROM @c INTO @Period 
	END
	CLOSE @c
	DEALLOCATE @c
	 
	CREATE TABLE #SalesResult 
	( 
		CustGuid			UNIQUEIDENTIFIER, 
		cuCustomerName		NVARCHAR(256) COLLATE ARABIC_CI_AI, 
		PeriodSort			INT, 
		PeriodGuid			UNIQUEIDENTIFIER, 
		PeriodName			NVARCHAR(256) COLLATE ARABIC_CI_AI, 
		PeriodCode			NVARCHAR(256) COLLATE ARABIC_CI_AI, 
		ActualSales			FLOAT DEFAULT(0) 
	) 
	INSERT INTO #SalesResult 
	SELECT 
		cm.CustGuid, 
		cu.cuCustomerName, 
		Pr.Sort, 
		Pr.PeriodGuid, 
		pr.Name AS PeriodName, 
		pr.Code AS PeriodCode, 
		SUM(CASE rv.btBillType WHEN 3 THEN -1 ELSE 1 END * rv.BiQty * pp.MatPrice) 
	FROM 
		dbo.fnExtended_bi_Fixed( @CurGUID) AS rv  
		INNER JOIN #PeriodsList AS pr ON rv.buDate between pr.StartDate and pr.EndDate
		INNER JOIN (select distinct CustGUID from vwDistCustTarget) AS cm ON rv.buCustPtr = cm.CustGuid 
		INNER JOIN distce000 AS ce ON rv.buCustPtr = ce.CustomerGuid
		INNER JOIN distct000 AS t ON ce.CustomerTypeGuid = t.Guid 
		LEFT JOIN vwCu AS cu ON cu.cuGuid = rv.buCustPtr 
		INNER JOIN #CustTypes AS ct ON ct.TypeGuid = t.Guid 
		INNER JOIN #PeriodsPrices AS pp ON pp.PeriodGuid = pr.PeriodGuid and pp.MatGuid = rv.biMatPtr
	WHERE 
		rv.btType = 1 
		AND( (btBillType = 1) OR ( btBillType = 3)) 
	GROUP BY 
		cm.CustGuid, 
		cu.cuCustomerName, 
		Pr.Sort, 
		Pr.PeriodGuid, 
		pr.Name, 
		pr.Code
		
	-- return Result set
	CREATE TABLE #Res 
	( 
		CustGuid			UNIQUEIDENTIFIER, 
		cuCustomerName		NVARCHAR(256) COLLATE ARABIC_CI_AI, 
		PeriodTarget_1		FLOAT DEFAULT (0), 
		PeriodSales_1		FLOAT DEFAULT (0), 
		PeriodTarget_2		FLOAT DEFAULT (0), 
		PeriodSales_2		FLOAT DEFAULT (0), 
		PeriodTarget_3		FLOAT DEFAULT (0), 
		PeriodSales_3		FLOAT DEFAULT (0), 
		TotalCustTarget		FLOAT DEFAULT (0), 
		TotalCustSales		FLOAT DEFAULT (0) 
	) 

	-- process Periods -- Add distinct period and then Update  
	INSERT INTO #Res 
	( 
		CustGuid, 
		cuCustomerName 
	) 
	SELECT DISTINCT  
		CustGuid, 
		cuCustomerName 
	FROM 
		#Result 
	-- select *from #PeriodsList 
	DECLARE @Pr UNIQUEIDENTIFIER 
	DECLARE @Cnt INT 
	SET @Cnt = 1 
	DECLARE c CURSOR FOR Select TOP 3 PeriodGuid FROM #PeriodsList ORDER BY Sort 
	OPEN c 
	FETCH NEXT FROM c INTO @Pr 
	WHILE @@FETCH_STATUS = 0 
	BEGIN 
		-- Target Price 
		DECLARE @s NVARCHAR(2000) 
		SET @s = 'UPDATE #Res SET PeriodTarget_' + CAST( @Cnt AS NVARCHAR)   
		SET @s = @s  + ' = CustTarget' 
		SET @s = @s + ' FROM #Result AS r INNER JOIN #Res AS s ON r.CustGuid = s.CustGuid WHERE PeriodGuid = ''' + CONVERT (NVARCHAR(100) , @Pr) + '''' 
		--Print @s 
		EXECUTE( @s) 
		-- Actual Price 
		SET @s = 'UPDATE #Res SET PeriodSales_' + CAST( @Cnt AS NVARCHAR)   
		SET @s = @s  + ' = ActualSales' 
		SET @s = @s + ' FROM #SalesResult AS r INNER JOIN #Res AS s ON r.CustGuid = s.CustGuid WHERE PeriodGuid = ''' + CONVERT (NVARCHAR(100) , @Pr) + '''' 
		--Print @s 
		EXECUTE( @s) 
		SET @Cnt = @Cnt + 1 
		FETCH NEXT FROM c INTO @Pr 
	END 
	CLOSE c 
	DEALLOCATE c 
	-- «·Õ’Ê· ⁄·Ï «·≈Ã„«·Ì 
	UPDATE #Res  
		SET TotalCustTarget = (PeriodTarget_1 + PeriodTarget_2 + PeriodTarget_3), 
			TotalCustSales = ( PeriodSales_1 + PeriodSales_2 + PeriodSales_3) 
	FROM #Res 
	SELECT * FROM #Res 
	 
	SELECT TOP 3 Name FROM #PeriodsList ORDER BY sort 
########################
#END