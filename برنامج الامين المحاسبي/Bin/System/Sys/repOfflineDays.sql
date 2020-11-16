#####################################################################
CREATE FUNCTION ListDates
(
     @StartDate datetime
    ,@EndDate   datetime 
)
RETURNS
@DateList table
(
    Date datetime
)
AS
BEGIN

IF ISDATE(@StartDate)!=1 OR ISDATE(@EndDate)!=1
BEGIN
    RETURN
END

DECLARE @TempDate DATETIME
SET @TempDate = @StartDate

WHILE (@TempDate <= @EndDate)
BEGIN	
	INSERT INTO @DateList (Date) VALUES (@TempDate)
	SET @TempDate = @TempDate + 1	
END

RETURN

END
#####################################################################
CREATE PROCEDURE repOfflineDays
	@StartDate [DATETIME] = '2/25/2012',
	@EndDate [DATETIME] = '2/27/2012',
	@ResourcesGUID [UNIQUEIDENTIFIER] = '796ab491-b90f-4196-86c8-a6107e129c1e',
	@ShowPostedBills [BIT] = 1,
	@ShowUnpostedBills [BIT] = 0,
	@ShowBillGenerateEntry [BIT] = 1,
	@ShowBillNotGenerateEntry [BIT] = 0,
	@ShowPostedPayments [BIT] = 0,
	@ShowUnpostedPayments [BIT] = 0
as
SET NOCOUNT ON  

DECLARE @UserGUID [UNIQUEIDENTIFIER]
SET @UserGUID = [dbo].[fnGetCurrentUserGUID]() 

CREATE TABLE [#SecViol]( [Type] [INT],[Cnt] [INT])      

DECLARE @BillPosetedOrNotPosted INT
IF (@ShowPostedBills = @ShowUnpostedBills)
	SET @BillPosetedOrNotPosted = -1
IF (@ShowPostedBills = 0 AND @ShowUnpostedBills <> 0)
	SET @BillPosetedOrNotPosted = 0
IF (@ShowPostedBills <> 0 AND @ShowUnpostedBills = 0)
	SET @BillPosetedOrNotPosted = 1	

DECLARE @PaymentPosetedOrNotPosted INT
IF (@ShowPostedPayments = @ShowUnpostedPayments)
	SET @PaymentPosetedOrNotPosted = -1
IF (@ShowPostedPayments = 0 AND @ShowUnpostedPayments <> 0)
	SET @PaymentPosetedOrNotPosted = 0
IF (@ShowPostedPayments <> 0 AND @ShowUnpostedPayments = 0)
	SET @PaymentPosetedOrNotPosted = 1	

CREATE TABLE [#Result] 
(      
	[OfflineDate] [DATETIME]
)  

IF (
	@ShowPostedBills > 0
	OR @ShowUnpostedBills > 0
	OR @ShowBillGenerateEntry > 0
	OR @ShowBillNotGenerateEntry > 0
	)
BEGIN
	CREATE TABLE [#BillTbl]( [Type] [UNIQUEIDENTIFIER], [Security] [INT], [ReadPriceSecurity] [INT])   
	INSERT INTO [#BillTbl] EXEC [prcGetBillsTypesList] @ResourcesGUID, @UserGUID 
	-- just bills whose genaret entry 
	IF (@ShowBillGenerateEntry <> 0 AND @ShowBillNotGenerateEntry = 0)	
	BEGIN
		INSERT INTO [#Result] 
			SELECT   
				bu.[buDate]		
			FROM 
				vwbu AS bu
				INNER JOIN vwer AS er ON bu.buguid = er.erParentGUId
				INNER JOIN [#BillTbl] AS bt ON bu.[buType] = bt.Type
			where (bu.budate BETWEEN @StartDate AND @EndDate)
			  AND (bu.buIsPosted = @BillPosetedOrNotPosted OR @BillPosetedOrNotPosted = -1)			  
	END	  
	------------------
	-- just bills whose not genaret entry  
	ELSE IF (@ShowBillGenerateEntry = 0 AND @ShowBillNotGenerateEntry <> 0)
	BEGIN
		INSERT INTO [#Result] 
			SELECT   
				bu.[buDate]		
			FROM 
				vwbu AS bu
				LEFT JOIN vwer AS er ON bu.buguid = er.erParentGUId				
				INNER JOIN [#BillTbl] AS bt ON bu.[buType] = bt.Type
			WHERE (bu.budate BETWEEN @StartDate AND @EndDate)
			  AND (bu.buIsPosted = @BillPosetedOrNotPosted OR @BillPosetedOrNotPosted = -1)	
			  AND (er.erguid IS NULL)
	END
	------------------------------------------
	-- all bills....whose whose genaret entry or not genaret entry 
	ELSE IF (@ShowBillGenerateEntry = @ShowBillNotGenerateEntry)
	BEGIN
		INSERT INTO [#Result] 
			SELECT   
				bu.[buDate]		
			FROM 
				vwbu AS bu				
				INNER JOIN [#BillTbl] AS bt ON bu.[buType] = bt.Type
			WHERE (bu.budate between @StartDate AND @EndDate)
			  AND (bu.buIsPosted = @BillPosetedOrNotPosted OR @BillPosetedOrNotPosted = -1)	
	END		
				
	DROP TABLE [#BillTbl]
END

IF (
	@ShowPostedPayments > 0
	or @ShowUnpostedPayments > 0
	)
BEGIN	
	CREATE TABLE [#EntryTbl]( [Type] [UNIQUEIDENTIFIER], [Security] [INT])  
	INSERT INTO [#EntryTbl] EXEC [prcGetEntriesTypesList] @ResourcesGUID, @UserGUID 	
	
	INSERT INTO [#Result] 
		SELECT   
			py.[pyDate]
		 FROM 
			vwpy AS py
			JOIN vwer AS er ON er.erparentguid = py.pyguid 
			JOIN vwce AS ce ON ce.ceguid = er.erentryguid
			INNER JOIN [#EntryTbl] AS et	ON py.[pyTypeguid] = et.Type
		WHERE (ce.cedate BETWEEN @StartDate AND @EndDate)
				AND (ce.ceIsPosted = @PaymentPosetedOrNotPosted OR @PaymentPosetedOrNotPosted = -1)
			
	INSERT INTO [#Result] 
		SELECT   
			ce.[ceDate]
		 FROM 
			vwce AS ce
			LEFT JOIN vwer AS er ON er.erentryguid = ce.ceguid
			WHERE (er.erguid IS NULL)
				AND (ce.cedate BETWEEN @StartDate AND @EndDate)
				AND (ce.ceIsPosted = @PaymentPosetedOrNotPosted OR @PaymentPosetedOrNotPosted = -1)
			
	DROP TABLE [#EntryTbl]
END	

Exec [prcCheckSecurity] @UserGUID 

IF ((SELECT COUNT(*) FROM [#Result]) > 0)
BEGIN
SELECT 
	d.Date AS OfflineDate 
FROM 
	dbo.ListDates(@StartDate, @EndDate) AS d
	LEFT JOIN [#Result] AS r ON Convert(NVARCHAR(20), r.OfflineDate, 112) = Convert(NVARCHAR(20), d.Date, 112)
WHERE r.OfflineDate IS NULL
END
ELSE
	SELECT * FROM [#Result]

SELECT * FROM  [#SecViol] 	
####################################################################