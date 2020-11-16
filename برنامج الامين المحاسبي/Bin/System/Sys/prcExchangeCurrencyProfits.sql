###################################
CREATE  Proc prcExchangeCurrencyProfits
		@SourceRepGuid UNIQUEIDENTIFIER,
		@Currency UNIQUEIDENTIFIER,
		@FromDate DATETIME,
		@ToDate	DATETIME,
		@SortBy INT = 0-- 0 date, 1 cur and date, 2 ty and date, 3 cur ty date, 4 ty cur date
AS
	
SET NOCOUNT ON
CREATE TABLE #Res
		(
			ExTypeGuid UNIQUEIDENTIFIER,
			ExTypeName NVARCHAR(250)	COLLATE ARABIC_CI_AI , 
			Currency UNIQUEIDENTIFIER,
			ExGuid UNIQUEIDENTIFIER,
			CeGuid UNIQUEIDENTIFIER,
			[Date] DATETIME,
			ExNumber INT,
			CeNumber INT,
			BaseCurrAmount FLOAT,
			sellsAmount FLOAT,
			SellsCostAmount FLOAT,
			CurrVal FLOAT,
			CurrAvg FLOAT,
			profit	FLOAT
		)
		

	INSERT INTO #Res
	SELECT * FROM FnTrnExchaneprofits(@SourceRepGuid, @FromDate, @ToDate, @Currency)

	IF (@SortBy = 0)
		SELECT 	* 
		FROM #res
		ORDER BY date
	ELSE IF (@SortBy = 1)
		SELECT 	fn.* 
		FROM #res AS fn
		INNER JOIN my000 AS my ON my.guid = fn.currency  
		ORDER BY my.number, fn.[date]

	ELSE IF (@SortBy = 2)
		SELECT 	fn.* 
		FROM #res AS fn
		INNER JOIN trnExchangeTypes000 AS t ON t.guid = fn.extypeguid 
		ORDER BY t.sortnum, fn.[date]

	ELSE IF (@SortBy = 3)
		SELECT 	fn.* 
		FROM #res AS fn 
		INNER JOIN my000 AS my ON my.guid = fn.currency  
		INNER JOIN trnExchangeTypes000 AS t ON t.guid = fn.extypeguid 
		ORDER BY my.number, t.sortnum, fn.[date]
	ELSE IF (@SortBy = 4)
		SELECT 	fn.*
		FROM #Res AS fn 
		INNER JOIN my000 AS my ON my.guid = fn.currency  
		INNER JOIN trnExchangeTypes000 AS t ON t.guid = fn.extypeguid 
		ORDER BY  t.sortnum, my.number, fn.[date]

	CREATE TABLE #Sums
		(Currency UNIQUEIDENTIFIER, type UNIQUEIDENTIFIER, typeName NVARCHAR(200) COLLATE ARABIC_CI_AI , profit FLOAT)

	-- „Ã«„Ì⁄ «·⁄„·« 
	INSERT INTO #sums
	SELECT 
		Currency, 0x0,'',SUM(profit) AS SumProfits
	FROM #Res 
	GROUP BY(Currency) 	
	
	--„Ã«„Ì⁄ «·√‰„«ÿ 
	INSERT INTO #sums
	SELECT 
		0x0, ExTypeGuid, ExTypeName,SUM(profit) AS SumProfits
	FROM #Res 
	GROUP BY ExTypeGuid, ExTypeName 
	
	-- „Ã«„Ì⁄ «·√‰„«ÿ Ê«·⁄„·« 
	INSERT INTO #sums
	SELECT 
		currency, ExTypeGuid, ExTypeName,SUM(profit) AS SumProfits
	FROM #Res 
	GROUP BY currency, ExTypeGuid, ExTypeName

	SELECT * FROM #sums
###############################################
#END