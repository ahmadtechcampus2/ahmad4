###############################################################################
CREATE  FUNCTION fnGetDatePeriod(  
					@PeriodType [INT],   
					@StartDate [DATETIME],   
					@EndDate [DATETIME])   
	RETURNS @t Table([Period] [INT], [StartDate] [DATETIME],[EndDate] [DATETIME])   
AS BEGIN   
/*   
@PeriodType:    
	1: Daily   
	2: Weekly   
	3: Monthly   
*/   
	DECLARE   
	@PeriodCounter	[INT],   
	@PeriodStart	[DATETIME],   
	@PeriodEnd		[DATETIME]  
	SET @PeriodCounter 		= 1   
	SET @PeriodStart 		= @StartDate   
	WHILE @PeriodStart <= @EndDate   
	BEGIN   
		IF @PeriodType = 1 -- daily  
		BEGIN   
			SET @PeriodEnd = DATEADD(day, 1 , @PeriodStart)   
		END   
		IF @PeriodType = 2 -- weekly  
		BEGIN   
			IF ((6 - DATEPART(dw, @PeriodStart))<>0)  
			BEGIN 
				SET @PeriodEnd = DATEADD(day, (6 - DATEPART(dw, @PeriodStart)), @PeriodStart)   
			END 
			ELSE 
			BEGIN 
				SET @PeriodEnd = DATEADD(week, 1, @PeriodStart)   
			END 
		END   
		IF @PeriodType = 3 -- monthly  
		BEGIN 
			IF ((DATEPART (dd, @PeriodStart) ) <>1 )  
			BEGIN 
				SET @PeriodEnd = DATEADD(day, DATEDIFF(dd,@PeriodStart,DATEADD(month, 1, @PeriodStart))-Day(@PeriodStart)+1, @PeriodStart)   
			END 
			ELSE 
			BEGIN 
				SET @PeriodEnd = DATEADD(month, 1, @PeriodStart)  
			END   
		END   
		SET @PeriodEnd = DATEADD(day, -1, @PeriodEnd)   
		IF @PeriodEnd > @EndDate SET @PeriodEnd = @EndDate   
		INSERT INTO @t VALUES(@PeriodCounter, @PeriodStart, @PeriodEnd)   
		SET @PeriodStart = DATEADD(day, 1, @PeriodEnd)   
		SET @PeriodCounter = @PeriodCounter + 1   
	END   
	RETURN   
END   
/*   
select *from us000   
prcConnections_add '5133A956-022D-44BF-85BC-FE57228AE960'   
select datepart( week, '2/1/2003')   
SELECT * FROM dbo.fnGetDatePeriod( 2, '1/25/2002', '7/5/2003')  

--SELECT @@DATEFIRST
SET DATEFIRST 2
SELECT * FROM fnGetDatePeriod (2,'1/25/2002', '7/5/2003')
*/
###############################################################################
#END