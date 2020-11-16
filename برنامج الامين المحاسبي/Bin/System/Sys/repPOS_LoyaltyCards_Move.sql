################################################################################
CREATE PROC repPOS_LoyaltyCards_LOC_Move
	@LoyaltyCardGUID	[UNIQUEIDENTIFIER],
	@ClassificationGUID	[UNIQUEIDENTIFIER],
	@StartDate			[DATETIME], 
	@EndDate			[DATETIME]
AS
	SET NOCOUNT ON
	
	DECLARE @fileName [NVARCHAR](128) 
	SET @fileName = (SELECT TOP 1 CAST(VALUE AS [NVARCHAR](50)) FROM [sys].[fn_listextendedproperty]( 'AmnDBName', NULL, NULL, NULL, NULL, NULL, NULL))

	SELECT 
		lc.*,
		lct.OrderDate AS									OrderDate,
		lct.OrderNumber AS									OrderNumber,
		lct.PointsValue AS									PointsValue,
		lct.OrderTotal AS									OrderTotal,
		IIF(lct.[State] = 0 , 1, -1) * lct.PointsCount AS	[PointsCount],
		lct.PaidPointsCount AS								PaidPointsCount,
		ISNULL(cs.DBName, lct.DBName) AS					[DBName],

		CASE ISNULL(cs.FileName, '')
			WHEN '' THEN (CASE WHEN lct.DBName = DB_NAME() THEN @fileName ELSE lct.DBName END)
			ELSE cs.FileName
		END AS												[FileName],
		lct.[State] AS										[State],
		lct.BranchName AS									BranchName, 
		lct.BranchLatinName AS								BranchLatinName,
		lcc.Name AS											[ClassificationName],
		lcc.LatinName AS									[ClassificationLatinName]
	FROM
		POSLoyaltyCardTransaction000 lct
		INNER JOIN POSLoyaltyCard000 lc ON lc.GUID = lct.LoyaltyCardGUID
		INNER JOIN POSLoyaltyCardClassification000 lcc ON lc.ClassificationGUID = lcc.GUID 
		LEFT  JOIN POSLoyaltyCardSource000 cs ON cs.DBName = lct.DBName
	WHERE
		( @LoyaltyCardGUID = 0x0 OR lc.GUID = @LoyaltyCardGUID )
		AND
		( @ClassificationGUID = 0x0 OR lc.ClassificationGUID = @ClassificationGUID )
		AND
		OrderDate BETWEEN @StartDate AND @EndDate  
	ORDER BY 
		OrderDate, OrderNumber
#######################################################################################
CREATE PROC repPOS_LoyaltyCards_Move 
	@LoyaltyCardGUID [UNIQUEIDENTIFIER],
	@ClassificationGUID [UNIQUEIDENTIFIER],
	@StartDate DATETIME, 
	@EndDate DATETIME
AS
	SET NOCOUNT ON

	DECLARE @ErrorNumber INT = 0 
	DECLARE @CentralizedDBName NVARCHAR(250)

	SELECT TOP 1
		@ErrorNumber =			ISNULL(ErrorNumber, 0),
		@CentralizedDBName =	ISNULL(CentralizedDBName, '')
	FROM 
		dbo.fnPOS_LoyaltyCards_CheckSystem (0x0)

	IF @ErrorNumber > 0 
		GOTO exitproc

	DECLARE @CmdText NVARCHAR(MAX)

	SET @CmdText = N'EXEC ' + @CentralizedDBName + N'repPOS_LoyaltyCards_LOC_Move
	@LoyaltyCardGUID, @ClassificationGUID, @StartDate, @EndDate  '

	EXEC sp_executesql @CmdText,
		N'@LoyaltyCardGUID [UNIQUEIDENTIFIER],
		  @ClassificationGUID [UNIQUEIDENTIFIER],
		  @StartDate DATETIME, 
		  @EndDate DATETIME',
		  @LoyaltyCardGUID = @LoyaltyCardGUID, @ClassificationGUID = @ClassificationGUID,
		  @StartDate = @StartDate, @EndDate = @EndDate 
		  
	exitproc:
		SELECT @ErrorNumber AS ErrorNumber
#######################################################################################
#END
