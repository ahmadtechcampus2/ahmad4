##################################################################
CREATE PROC prcPOS_LoyaltyCards_GetPaidInfo
	@LoyaltyCardTypeGUID	UNIQUEIDENTIFIER,
	@LoyaltyCardGUID		UNIQUEIDENTIFIER
AS 
	SET NOCOUNT ON 

	CREATE TABLE #Result (ErrorNumber INT, AvailablePointsCount INT)

	INSERT INTO #Result EXEC prcPOS_LoyaltyCards_GetAvailabePointsCount @LoyaltyCardTypeGUID, @LoyaltyCardGUID

	DECLARE 
		@MinimumValue	INT,
		@SpendPoint		FLOAT 

	SELECT 
		@MinimumValue =	MinimumValue, 
		@SpendPoint =	SpendPoint
	FROM 
		POSLoyaltyCardType000
	WHERE 
		[GUID] = @LoyaltyCardTypeGUID

	SELECT 
		*,
		@MinimumValue AS	MinimumValue,
		@SpendPoint AS		SpendPoint
	FROM 
		#Result
##################################################################
#END
