#################################################################################
CREATE PROC repRestRushHours
	@StartDate DATETIME,
	@EndDate DATETIME,
	@GroupGUID UNIQUEIDENTIFIER,
	@MatGUID UNIQUEIDENTIFIER,
	@MatCond UNIQUEIDENTIFIER,
	@RushHoursType INT,			-- 1 orders count, 2 price, 3 mat qty
	@HorizantalAxisType INT,	-- 1 user, 2 order type, 3 weekly days
	@IsOuter BIT,
	@IsDelivery BIT,
	@IsTable BIT,
	@IsReturned BIT
AS 
	SET NOCOUNT ON 
	
	CREATE TABLE [#SecViol]( [Type] [INT], [Cnt] [INTEGER])
	CREATE TABLE [#MatTbl]( [MatGUID] [UNIQUEIDENTIFIER], [mtSecurity] [INT])  
	CREATE TABLE #Result([OrderGUID] [UNIQUEIDENTIFIER], [MatGUID] [UNIQUEIDENTIFIER], [mtSecurity] [INT],
		[OrderDate] DATETIME, [OrderType] [INT], [UserGUID] [UNIQUEIDENTIFIER], [Total] FLOAT, Qty FLOAT)
	CREATE TABLE #OrdersResult([OrderGUID] [UNIQUEIDENTIFIER], [OrderDate] DATETIME, [OrderType] [INT], 
		[UserGUID] [UNIQUEIDENTIFIER], [Total] FLOAT, Qty FLOAT)
	CREATE TABLE #FinalResult([Hour] INT, [WeekDay] [INT], [UserGUID] [UNIQUEIDENTIFIER], [OrderType] INT, [Amount] FLOAT)

	DECLARE @Hours TABLE([Hour] INT)
	DECLARE @counter INT 
	SET @counter = 1
	WHILE @counter < 25
	BEGIN 
		INSERT INTO @Hours SELECT @counter
		SET @counter = @counter + 1
	END 

	INSERT INTO [#MatTbl] EXEC [prcGetMatsList] @MatGUID, @GroupGUID, 0, @MatCond 
	INSERT INTO #Result
	SELECT 
		[o].[GUID],
		mt.MatGUID,
		mt.mtSecurity,
		o.[Closing],
		o.[Type],
		o.FinishCashierID,
		o.SubTotal,		-- ÇáÓÚÑ ÑÈãÇ íÎÊáÝ ÈÍÓÈ ÇáãæÇÏ ÇáãÎÊÇÑÉ
		oi.Qty			-- ãÚÇáÌÉ ÇáæÍÏÇÊ
	FROM 
		RestOrder000 [o]
		INNER JOIN [RestOrderItem000] [oi] ON [o].[GUID] = [oi].[ParentID]
		INNER JOIN [#MatTbl] [mt] ON [oi].MatID = mt.MatGUID
	WHERE
		([o].[Closing] BETWEEN @StartDate AND @EndDate)
		AND 
		(
			(@IsOuter = 1 AND [o].[Type] = 2) 
			OR 
			(@IsDelivery = 1 AND [o].[Type] = 3) 
			OR 
			(@IsTable = 1 AND [o].[Type] = 1) 
			OR 
			(@IsReturned = 1 AND [o].[Type] = 4)
		)

	EXEC prcCheckSecurity

	INSERT INTO #OrdersResult
	SELECT 
		[OrderGUID],
		[OrderDate], 
		[OrderType],
		[UserGUID],
		MAX([Total]),
		SUM(Qty)
	FROM 	
		#Result
	GROUP BY 
		[OrderGUID],
		[OrderDate], 
		[OrderType],
		[UserGUID]

	SET DATEFIRST 7

	INSERT INTO #FinalResult
	SELECT 
		h.[Hour],
		CASE @HorizantalAxisType
			WHEN 2 THEN 0
			WHEN 3 THEN ISNULL(DATEPART(dw, r.OrderDate), 0)
			ELSE 0
		END,
		CASE @HorizantalAxisType
			WHEN 2 THEN 0x0
			WHEN 3 THEN 0x0
			ELSE ISNULL(r.[UserGUID], 0x0)
		END,
		CASE @HorizantalAxisType
			WHEN 2 THEN ISNULL(r.OrderType, 0)
			WHEN 3 THEN 0
			ELSE 0
		END,
		CASE @RushHoursType
			WHEN 2 THEN ISNULL(SUM([Total]), 0)
			WHEN 3 THEN ISNULL(SUM([Qty]), 0)
			ELSE 
				ISNULL(
				SUM(CASE @HorizantalAxisType 
						WHEN 2 THEN CASE ISNULL(r.OrderType, 0) WHEN 0 THEN 0 ELSE 1 END
						WHEN 3 THEN CASE ISNULL(DATEPART(dw, r.OrderDate), 0) WHEN 0 THEN 0 ELSE 1 END
						ELSE CASE ISNULL(r.[UserGUID], 0x0) WHEN 0x0 THEN 0 ELSE 1 END
					END), 0)
		END 
	FROM 
		@Hours h
		LEFT JOIN #OrdersResult r ON h.[Hour] = DATEPART(hh, r.OrderDate)
	GROUP BY 
		h.[Hour], 
		CASE @HorizantalAxisType
			WHEN 2 THEN 0
			WHEN 3 THEN ISNULL(DATEPART(dw, r.OrderDate), 0)
			ELSE 0
		END,
		CASE @HorizantalAxisType
			WHEN 2 THEN 0x0
			WHEN 3 THEN 0x0
			ELSE ISNULL(r.[UserGUID], 0x0)
		END,
		CASE @HorizantalAxisType
			WHEN 2 THEN ISNULL(r.OrderType, 0)
			WHEN 3 THEN 0
			ELSE 0
		END
	
	IF @HorizantalAxisType = 3 -- week days
	BEGIN 
		SET @counter = 1
		WHILE @counter < 8
		BEGIN 
			INSERT INTO #FinalResult SELECT 1, @counter, 0x0, 1, 0
			SET @counter = @counter + 1
		END 
	END 

	SELECT 
		r.*,
		ISNULL(us.LoginName, '') AS LoginName
	FROM 
		#FinalResult r
		LEFT JOIN us000 us ON r.UserGUID = us.GUID 
	ORDER BY r.[Hour], r.[WeekDay], r.OrderType

	SELECT * FROM [#SecViol]
#################################################################################
#END
