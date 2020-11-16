##################################################################
CREATE FUNCTION fnPOS_LoyaltyCards_GetAvailablePointsCount (@LoyaltyCardGUID UNIQUEIDENTIFIER)
	RETURNS INT 	
AS BEGIN 

	DECLARE 
		@PointsExpire			INT,	
		@PointsCalcDaysCount	INT

	SET @PointsExpire = 0
	SET @PointsCalcDaysCount = 0

	SET @PointsExpire =			[dbo].[fnOption_GetInt]('AmnCfg_LoyaltyCards_PointsAvailability',	'0')
	SET @PointsCalcDaysCount =	[dbo].[fnOption_GetInt]('AmnCfg_LoyaltyCards_PointsAddedAfter',		'0')

	DECLARE @today DATE 
	SET @today = GETDATE()

	RETURN ISNULL((
	SELECT 
		SUM(bct.PointsCount - bct.PaidPointsCount)
	FROM 
		POSLoyaltyCardTransaction000 bct
		INNER JOIN POSLoyaltyCard000 bc					ON bc.GUID	= bct.LoyaltyCardGUID
		INNER JOIN POSLoyaltyCardClassification000 bcc	ON bcc.GUID	= bc.ClassificationGUID
	WHERE 
		--bc.IsInactive = 0
		--AND 
		--@today BETWEEN bc.StartDate AND bc.EndDate 
		--AND 
		bc.[GUID] = @LoyaltyCardGUID
		AND 
		bct.[State] = 0 -- charged only
		AND
        (
            (ISNULL(@PointsCalcDaysCount, 0) = 0)
            OR
            ((@PointsCalcDaysCount != 0) AND (DATEADD(dd, @PointsCalcDaysCount, CONVERT(DATE, bct.OrderDate)) <= @today))
        )
        AND
        (
            (ISNULL(@PointsExpire, 0) = 0)
            OR
            ((@PointsExpire != 0) AND (DATEDIFF(dd, DATEADD(dd, @PointsCalcDaysCount, CONVERT(DATE, bct.OrderDate)), @today) <= @PointsExpire)))
        ), 0)		
END 
##################################################################
CREATE FUNCTION fnPOS_LoyaltyCards_GetNotDuePointsCount (@LoyaltyCardGUID UNIQUEIDENTIFIER)
	RETURNS INT 	
AS BEGIN 

	DECLARE @PointsCalcDaysCount	INT
	SET @PointsCalcDaysCount = 0
	SET @PointsCalcDaysCount =	[dbo].[fnOption_GetInt]('AmnCfg_LoyaltyCards_PointsAddedAfter',		'0')
	IF ISNULL(@PointsCalcDaysCount, 0) <= 0
		RETURN 0

	DECLARE @today DATE 
	SET @today = GETDATE()

	RETURN ISNULL((
	SELECT 
		SUM(bct.PointsCount - bct.PaidPointsCount)
	FROM 
		POSLoyaltyCardTransaction000 bct
		INNER JOIN POSLoyaltyCard000 bc					ON bc.GUID	= bct.LoyaltyCardGUID
		INNER JOIN POSLoyaltyCardClassification000 bcc	ON bcc.GUID	= bc.ClassificationGUID
	WHERE 
		bc.IsInactive = 0
		AND 
		@today BETWEEN bc.StartDate AND bc.EndDate 
		AND 
		bc.[GUID] = @LoyaltyCardGUID
		AND 
		bct.[State] = 0 -- charged only
		AND
		((@PointsCalcDaysCount > 0) AND (DATEADD(dd, @PointsCalcDaysCount, CONVERT(DATE, bct.OrderDate)) > @today))), 0)		
END 
##################################################################
#END
