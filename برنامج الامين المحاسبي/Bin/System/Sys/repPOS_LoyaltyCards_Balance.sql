################################################################################
CREATE PROC repPOS_LoyaltyCards_LOC_Balance  
	@LoyaltyCardGUID [UNIQUEIDENTIFIER],
	@ClassificationGUID [UNIQUEIDENTIFIER],
	@IsInactive INT,
	@FilterOnStartDate BIT,
	@StartDate DATETIME, 
	@EndDate DATETIME
AS
	SET NOCOUNT ON

	SELECT		
		tr.OrderTotal, 
		tr.PointsCount,
		tr.PaidPointsCount,	
		tr.PointsCount - tr.PaidPointsCount - lc.[AvailablePointsCount]
							- lc.[NotDuePointsCount] AS [ExpiredPointsCount],
		lc.[AvailablePointsCount] AS [PointsBalance],
		lc.*
	FROM 
		(SELECT 
			dbo.fnPOS_LoyaltyCards_GetAvailablePointsCount (lc.GUID) AS [AvailablePointsCount], 
			dbo.fnPOS_LoyaltyCards_GetNotDuePointsCount (lc.GUID) AS [NotDuePointsCount], 
			lc.*,
			lcc.Name AS [ClassificationName],
			lcc.LatinName AS [ClassificationLatinName]
		 FROM POSLoyaltyCard000 lc
		 INNER JOIN POSLoyaltyCardClassification000 lcc ON lc.ClassificationGUID = lcc.GUID 
		 WHERE 
			( @LoyaltyCardGUID = 0x0 OR lc.GUID = @LoyaltyCardGUID )
			AND 
			( @ClassificationGUID = 0x0 OR ClassificationGUID = @ClassificationGUID )
			AND
			( @FilterOnStartDate = 0 OR (StartDate BETWEEN @StartDate AND @EndDate) )		
			AND
			( @IsInactive = -1 OR IsInactive = @IsInactive ) 
		) lc 
		CROSS APPLY
		(
			SELECT 
				SUM(tr.OrderTotal)		AS [OrderTotal], 
				SUM(tr.PointsCount)		AS [PointsCount],
				SUM(tr.PaidPointsCount) AS [PaidPointsCount]
			FROM POSLoyaltyCardTransaction000 tr
			WHERE 
				LoyaltyCardGUID = lc.GUID
				AND 
				[State] = 0
			GROUP BY LoyaltyCardGUID
		) tr
#######################################################################################
CREATE PROC repPOS_LoyaltyCards_Balance  
	@LoyaltyCardGUID [UNIQUEIDENTIFIER],
	@ClassificationGUID [UNIQUEIDENTIFIER],
	@IsInactive INT,
	@FilterOnSubscriptionDate BIT,
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

	SET @CmdText = N'EXEC ' + @CentralizedDBName + N'repPOS_LoyaltyCards_LOC_Balance 
	@LoyaltyCardGUID, @ClassificationGUID, @IsInactive, @FilterOnSubscriptionDate, @StartDate, @EndDate  '

	EXEC sp_executesql @CmdText,
		N'@LoyaltyCardGUID [UNIQUEIDENTIFIER],
		  @ClassificationGUID [UNIQUEIDENTIFIER],
		  @IsInactive INT,
		  @FilterOnSubscriptionDate BIT,
		  @StartDate DATETIME, 
		  @EndDate DATETIME',
		  @LoyaltyCardGUID = @LoyaltyCardGUID, @ClassificationGUID = @ClassificationGUID,
		  @IsInactive = @IsInactive, @FilterOnSubscriptionDate = @FilterOnSubscriptionDate, 
		  @StartDate = @StartDate, @EndDate = @EndDate 
		  
	exitproc:
		SELECT @ErrorNumber AS ErrorNumber
#######################################################################################
#END
