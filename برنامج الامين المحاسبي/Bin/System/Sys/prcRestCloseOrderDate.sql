###########################
CREATE PROCEDURE prcRestCloseOrderDate
AS
SET NOCOUNT ON

DECLARE @bit bit,
	  @Increment INT,
	  @date DATETIME,
	  @newDate DATETIME
	  
SET @Bit = 0
SET @date = GETDATE()

SELECT  @Bit = CASE VALUE WHEN '0' THEN 0 ELSE 1 END FROM fileop000 WHERE Name='AmnRest_UseCloseDate' 

IF @Bit = 0
BEGIN
	SELECT @date AS CloseDate
END
ELSE
BEGIN
  SELECT  @Increment = CAST(VALUE AS INT) FROM fileop000 WHERE Name='AmnRest_CloseDateHour'  
  SET @newDate = Dateadd(HOUR, -1 * @Increment, @date)	 
  
  IF DATEPART(Day, @newDate) <> DATEPART(Day, @date)
  BEGIN
	SELECT  @newDate  AS CloseDate
  END
  ELSE
  BEGIN
    SELECT @date AS CloseDate
  END
END
###########################
#END