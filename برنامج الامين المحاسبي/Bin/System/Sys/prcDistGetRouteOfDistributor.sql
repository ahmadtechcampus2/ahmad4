########################################
## prcDistGetRouteOfDistributor
CREATE PROC prcDistGetRouteOfDistributor
	@DistributorGUID	uniqueidentifier, 
	@RouteNum		int
AS 
	CREATE TABLE #Route(CustomerGUID uniqueidentifier, RouteTime dateTime) 
	DECLARE @CustAccGUID uniqueidentifier
	SELECT @CustAccGUID = CustomersAccGUID FROM Distributor000 WHERE GUID = @DistributorGUID
	SET @CustAccGUID = ISNULL(@CustAccGUID, 0x00)
	if (@CustAccGUID <> 0x00)
	begin
	
		INSERT INTO #Route  
			SELECT cu.GUID  , case @RouteNum 
						when ex.Route1 then ex.Route1Time 
						when ex.Route2 then ex.Route2Time
						when ex.Route3 then ex.Route3Time
						when ex.Route4 then ex.Route4Time
					  END  AS RouteTime	
			FROM  
				CU000 AS cu
				INNER JOIN (SELECT GUID FROM fnGetAccountsList(@CustAccGUID, 0) GROUP BY GUID) AS ce ON ce.GUID = cu.AccountGUID
				INNER JOIN DistDistributionLines000 AS ex ON ex.CustGUID = cu.GUID 
			WHERE 
				(ex.DistGUID = @DistributorGUID) AND (@RouteNum = ex.Route1 OR @RouteNum = ex.Route2 OR @RouteNum = ex.Route3 OR @RouteNum = ex.Route4)
	end
	
	SELECT * FROM #Route
########################################
## fnDistGetRouteOfDistributor
CREATE FUNCTION fnDistGetRouteOfDistributor (@DistributorGUID uniqueidentifier, @RouteNum int)
RETURNS @Route TABLE (CustomerGUID uniqueidentifier, RouteTime DATETIME)
AS
BEGIN
	DECLARE @CustAccGUID uniqueidentifier
	SELECT @CustAccGUID = CustomersAccGUID FROM Distributor000 WHERE GUID = @DistributorGUID
	SET @CustAccGUID = ISNULL(@CustAccGUID, 0x00)
	IF (@CustAccGUID <> 0x00)
	BEGIN
		INSERT INTO @Route 
		SELECT 
			cu.GUID,  
			RouteTime = CASE @RouteNum 
							WHEN ex.Route1 THEN Route1Time  
							WHEN ex.Route2 THEN Route2Time
							WHEN ex.Route3 THEN Route3Time
							WHEN ex.Route4 THEN Route4Time
						END
		FROM 
			CU000 AS cu 
			INNER JOIN DistDistributionLines000 AS  ex ON ex.CustGUID = cu.GUID
			INNER JOIN (SELECT GUID FROM fnGetAccountsList(@CustAccGUID, 0) GROUP BY GUID) AS ce ON ce.GUID = cu.AccountGUID
		WHERE
			( ex.DistGUID = @DistributorGUID )	 AND
			( @RouteNum   = ex.Route1 OR @RouteNum = ex.Route2 OR @RouteNum = ex.Route3 OR @RouteNum = ex.Route4 )
		ORDER BY cu.CustomerName
	END
	RETURN
END
########################################
## fnDistCalendarWeekDays
CREATE FUNCTION fnDistCalendarWeekDays (@Date DateTime)
RETURNS NVARCHAR(255)
AS
BEGIN
    DECLARE @DayName NVARCHAR(10) Set @DayName = ''
    DECLARE @res NVARCHAR(255)    Set @res = ''
        
	DECLARE cur		CURSOR    
    FOR 
    SELECT 
    	DATENAME(dw, [Date]) AS DATENAME
    FROM 
        DISTCalendar000
    Where 
        [Date] BETWEEN @Date AND @Date+7
    ORDER BY 
        [Date]    
	
    OPEN cur 
    FETCH NEXT FROM cur INTO @DayName
    WHILE @@FETCH_STATUS = 0           
	BEGIN    
		Set @res = @res + @DayName + '-'
        
                    		 
		FETCH NEXT FROM cur INTO @DayName
	END 
	CLOSE cur 
    DEALLOCATE cur
    
    return @res
END
########################################
## prcDistGetRouteDays
CREATE PROCEDURE prcDistGetRouteDays
AS
BEGIN
	SET NOCOUNT ON
	
	DECLARE
		@FirstRouteDate DATE,
		@RouteCount INT,
		@EndPeriodDate DATE,
		@TempRouteDate DATE,
		@TempNumber INT;
		
	DECLARE @Result Table(
		[Date] DATE,
		Number INT);
		
	SELECT @FirstRouteDate = [dbo].[fnDate_Amn2Sql](Value) FROM op000 WHERE Name = 'DistCfg_Coverage_RouteDate';
	SELECT @EndPeriodDate = [dbo].[fnDate_Amn2Sql](Value) FROM op000 WHERE Name = 'AmnCfg_EPDate';
	SELECT @RouteCount = dbo.fnOption_GetInt('DistCfg_Coverage_RouteCount', '0');
	SET @TempNumber = 1;
	
	SET @TempRouteDate = @FirstRouteDate;
	
	WHILE (@TempRouteDate <= @EndPeriodDate)
	BEGIN
		IF @TempNumber > @RouteCount
			SET @TempNumber = 1;
				
		IF NOT EXISTS(SELECT * FROM DISTCalendar000 WHERE Date = @TempRouteDate)
		BEGIN
			INSERT INTO @Result VALUES(@TempRouteDate, @TempNumber);
			SET @TempNumber = @TempNumber + 1;
		END
		ELSE
			INSERT INTO @Result VALUES(@TempRouteDate, 0);
			
		
		SET @TempRouteDate = DATEADD(DAY, 1, @TempRouteDate);
	END
	
	SELECT * FROM @Result
END
#############################
#END
