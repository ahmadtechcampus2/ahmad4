##############################################
CREATE FUNCTION fnPOS_LoyaltyCards_ClassUsedFlag(@GUID [UNIQUEIDENTIFIER])
	RETURNS [INT] 
AS BEGIN 
	DECLARE @result [INT]

	SET @result = 0 

	IF EXISTS (SELECT * FROM [POSLoyaltyCard000] WHERE ClassificationGUID = @GUID)
		SET @result = 1

	IF EXISTS (SELECT * FROM [POSLoyaltyCardType000] WHERE ClassificationGUID = @GUID)
		SET @result = 2

	RETURN @result
END 
##############################################
CREATE FUNCTION fnPOS_LoyaltyCards_CardUsedFlag(@GUID [UNIQUEIDENTIFIER])
	RETURNS [INT] 
AS BEGIN 
	DECLARE @result [INT]

	SET @result = 0 

	IF EXISTS (SELECT * FROM [POSOrder000] WHERE LoyaltyCardGUID = @GUID AND PointsCount > 0)
		SET @result = 1
	IF EXISTS (SELECT * FROM [RESTOrder000] WHERE LoyaltyCardGUID = @GUID AND PointsCount > 0)
		SET @result = 2
	IF EXISTS (SELECT * FROM [POSLoyaltyCardTransaction000] WHERE LoyaltyCardGUID = @GUID)
		SET @result = 3
	IF EXISTS (SELECT * FROM [POSPaymentsPackagePoints000] WHERE LoyaltyCardGUID = @GUID)
		SET @result = 4

	RETURN @result
END 
##############################################
#END
