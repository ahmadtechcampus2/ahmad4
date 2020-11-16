#########################################################
CREATE FUNCTION fnDistGetRouteNumOfDate( 
	@CurrentDate DATETIME)
RETURNS INT
AS BEGIN  
	DECLARE @RouteCount		INT,   
			@RouteNum 		INT,   
			@RouteDate 		DATETIME,   
			@Route	 		INT

	SET @Route = -1
	IF NOT EXISTS (SELECT Date FROM DistCalendar000 WHERE State = 1 AND Date = [dbo].[fnGetDateFromDT](@CurrentDate) )	-- For Holiday Day
	BEGIN
		SELECT @RouteCount = dbo.fnOption_GetInt('DistCfg_Coverage_RouteCount', '0')  
		SELECT @RouteDate = [dbo].[fnDate_Amn2Sql](Value) FROM op000 WHERE Name = 'DistCfg_Coverage_RouteDate'  
		SET @RouteCount = ISNULL(@RouteCount, 6)
		SET @RouteDate = ISNULL( @RouteDate, @CurrentDate)
		IF @RouteDate <= @CurrentDate
		BEGIN
			SET @RouteNum = 1  
			SET @Route = @RouteNum + (CASE @RouteCount WHEN 0 THEN 0 ELSE ( (DateDiff( dd, @RouteDate, @CurrentDate) - (SELECT COUNT(Number) FROM DistCalendar000 WHERE State = 1 AND Date BETWEEN @RouteDate AND @CurrentDate)) % @RouteCount ) END)
		END
		ELSE
		BEGIN
			SET @RouteNum = @RouteCount + 1
			SET @Route = @RouteNum - (CASE @RouteCount WHEN 0 THEN 0 ELSE ( ( DateDiff( dd, @CurrentDate, @RouteDate) - (SELECT COUNT(Number) FROM DistCalendar000 WHERE State = 1 AND Date BETWEEN @CurrentDate AND @RouteDate )) % @RouteCount ) END) 
		END
	END

	if @Route > @RouteCount 
		SET @Route = 1
	RETURN @Route
END
#########################################################
CREATE FUNCTION fnDistCalcExpectedCov (
	@RealDaysNum AS INT, @RouteCount AS INT, @Route1 AS INT, @Route2  AS INT, @Route3 As INT, @Route4 As INT
)
RETURNS INT
AS
BEGIN
	DECLARE @Result		INT,
			@SumRoute	INT

	SET @SumRoute = (CASE ISNULL(@Route1,0) WHEN 0 THEN 0 ELSE 1  end) + (case ISNULL(@Route2,0) WHEN 0 THEN 0 ELSE 1  end) + (case ISNULL(@Route3,0) WHEN 0 THEN 0 ELSE 1  end) + (case ISNULL(@Route4,0) WHEN 0 THEN 0 ELSE 1  END)
	IF @SumRoute <> 0
	BEGIN
		SET @Result =   ((@RealDaysNum / @RouteCount) * @SumRoute)     
						+ ( CASE 	WHEN	( (@RealDaysNum % @RouteCount) > (@RouteCount / @SumRoute) )      
								THEN	( (@RealDaysNum % @RouteCount) / (@RouteCount / @SumRoute) )     
				     		ELSE	0     
							END     
						  )     
	END	
	ELSE
		SET @Result = 0
		
	RETURN @Result
END
#########################################################
CREATE FUNCTION fnDistCalcExpectedCovBetweenDates (
	@StartDate	AS DATETIME, 
	@EndDate	AS DATETIME,  
	@Route1		AS INT, 
	@Route2		AS INT, 
	@Route3		As INT, 
	@Route4		As INT
)
RETURNS INT
AS
BEGIN
	DECLARE @Result		INT
	SELECT @Result = COUNT([Date]) FROM fnDistGetRoutesNumListBetweenDates (@StartDate, @EndDate)
	WHERE 
		Route = @Route1 OR Route = @Route2 OR Route = @Route3 OR Route = @Route4

	RETURN @Result
END

-- SELECT dbo.fnDistCalcExpectedCovBetweenDates ('05-01-2008', '05-20-2008', 1, 2, 0, 0)

#########################################################
CREATE FUNCTION fnDistGetCustVisitState (@DistGUID uniqueidentifier, @CustGUID uniqueidentifier, @VisitDate DATETIME)
RETURNS INT -- 1 Visit From Route  2 Visit From Out Route
AS
BEGIN
	DECLARE @RouteNum	AS INT,
			@State		AS INT  
		
	SELECT @RouteNum = dbo.fnDistGetRouteNumOfDate(@VisitDate)

	IF EXISTS	(
					SELECT CustGUID  FROM DistDistributionLines000
					WHERE
						(DistGUID = @DistGUID)	AND (CustGuid = @CustGuid) AND 
						(@RouteNum   = Route1 OR @RouteNum = Route2 OR @RouteNum = Route3 OR @RouteNum = Route4)
				)
		SET @State = 1
	ELSE
		SET @State = 2

	RETURN @State 
END
#########################################################
CREATE FUNCTION fnDistGetRoutesNumListOfDate (@Date DateTime) 
RETURNS @RoutesLst TABLE (Date DateTIME, Route INT) 
AS 
BEGIN 
	DECLARE @RouteNum	INT, 
			@RouteCnt	INT,
			@R			INT

	SELECT @RouteCnt = dbo.fnOption_GetInt('DistCfg_Coverage_RouteCount', '0')   

	SET @R = 0
	WHILE @R < @RouteCnt 
	BEGIN
		SET @RouteNum = dbo.fnDistGetRouteNumOfDate(@Date) 
		IF @RouteNum <> -1	-- Holiday Day
		BEGIN
			INSERT INTO @RoutesLst (Date, Route) SELECT @Date, @RouteNum
			SET @R = @R + 1 
		END
		SET @Date = @Date + 1
	END
	RETURN 
END 

/*
SELECT Date, Route FROM fnDistGetRoutesNumListOfDate ('01-13-2008')
*/
#########################################################
CREATE FUNCTION fnDistGetRoutesNumListBetweenDates (@StartDate DATETIME, @EndDate DATETIME) 
RETURNS @RoutesLst TABLE ([Date] DateTIME, Route INT) 
AS 
BEGIN 
	DECLARE @RouteNum	INT 

	WHILE @StartDate <= @EndDate 
	BEGIN
		SET @RouteNum = dbo.fnDistGetRouteNumOfDate(@StartDate) 
		IF @RouteNum <> -1	-- Holiday Day
			INSERT INTO @RoutesLst (Date, Route) SELECT @StartDate, @RouteNum
		SET @StartDate = @StartDate + 1
	END
	RETURN 
END 

/*
SELECT Date, Route FROM fnDistGetRoutesNumListOfDate ('05-01-2008')
SELECT Date, Route FROM fnDistGetRoutesNumListBetweenDates ('05-01-2008', '05-20-2008')
*/
#########################################################
CREATE FUNCTION fnDistGetVisitDateForCust( 
	@DistGuid UNIQUEIDENTIFIER, @CustGuid UNIQUEIDENTIFIER, @FromDate DATETIME) 
RETURNS DATETIME
AS 
BEGIN   

	DECLARE @Route1	INT, 
			@Route2	INT,
			@Route3	INT,
			@Route4	INT,
			@VisitDate	DATETIME

	SET @Route1 = 0
	SET @Route2 = 0
	SET @Route3 = 0
	SET @Route4 = 0

	SELECT @Route1 = Route1, @Route2 = Route2, @Route3 = Route3, @Route4 = Route4 FROM DistDistributionLines000 
	WHERE DistGuid = @DistGuid AND CustGuid = @CustGuid  

	SELECT TOP 1 @VisitDate = [Date] FROM fnDistGetRoutesNumListOfDate (@FromDate) 
	WHERE Route = @Route1 OR Route = @Route2 OR Route = @Route3 OR Route = @Route4
	ORDER BY [Date]

	RETURN @VisitDate
END 
#########################################################
CREATE FUNCTION fnDistGetDistPrices (@DistGUID uniqueidentifier)  
RETURNS  
	@Prices TABLE (ID INT IDENTITY(1, 1), PriceName NVARCHAR(100), PriceID INT, Notes NVARCHAR(100))  
AS  
BEGIN  
	DECLARE @LstPrices	INT	
	SELECT @LstPrices = ObjectNumber FROM DistDD000 WHERE DistributorGuid = @DistGUID AND ObjectType = 5 

	IF 0x001 & @lstPrices > 0 INSERT INTO @Prices (PriceName, PriceId, Notes) VALUES('Whole',   1, '«·Ã„·…'		)
	IF 0x002 & @lstPrices > 0 INSERT INTO @Prices (PriceName, PriceId, Notes) VALUES('Half',    2, '‰’› «·Ã„·…'	)
	IF 0x004 & @lstPrices > 0 INSERT INTO @Prices (PriceName, PriceId, Notes) VALUES('Vendor',  3, '«·„Ê“⁄'		)
	IF 0x008 & @lstPrices > 0 INSERT INTO @Prices (PriceName, PriceId, Notes) VALUES('Export',  4, '«· ’œÌ—'	)
	IF 0x010 & @lstPrices > 0 INSERT INTO @Prices (PriceName, PriceId, Notes) VALUES('Retail',  5, '«·„›—ﬁ'		)
	IF 0x020 & @lstPrices > 0 INSERT INTO @Prices (PriceName, PriceId, Notes) VALUES('EndUser', 6, '«·„” Â·ﬂ'	)
	RETURN  
END  

/*
Select * From dbo.fnDistGetDistPrices( '562D942F-D2DE-46DD-8278-FE97B55E6FB3'	)
*/
#########################################################
CREATE FUNCTION fnDistGetDistBalance( @DistGuid UNIQUEIDENTIFIER)  
	RETURNS FLOAT
AS 
BEGIN   
	DECLARE @DistBalance FLOAT
	DECLARE @ExportAfterZeroAcc BIT
	
	SELECT 
		@ExportAfterZeroAcc = d.ExportAfterZeroAcc,
		@DistBalance = a.Debit - a.Credit
	FROM 
		Distributor000 AS d
		INNER JOIN DistSalesMan000 AS s ON s.Guid = d.PrimSalesManGuid
		INNER JOIN Ac000 AS a ON a.Guid = s.AccGuid
	WHERE 
		d.Guid = @DistGuid

	IF @ExportAfterZeroAcc = 1
		SET @DistBalance = ISNULL(@DistBalance, 0)
	ELSE
		SET @DistBalance = 0

	RETURN @DistBalance
END   

-- Select dbo.fnDistGetDistBalance(0x00)
#########################################################
#END 