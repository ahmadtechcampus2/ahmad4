##############################################
CREATE FUNCTION fnPOS_LoyaltyCards_TypeAvailability(@GUID [UNIQUEIDENTIFIER])
	RETURNS [INT] 
AS 
BEGIN 
	DECLARE @result [INT]

	SET @result = 0 

	IF EXISTS (SELECT * FROM [POSLoyaltyCardType000] WHERE ClassificationGUID = @GUID AND IsInactive = 0 )
	BEGIN
		SET @result = 1
		Return @result
	END
	
	IF EXISTS (SELECT * FROM [POSLoyaltyCardType000] WHERE ClassificationGUID = @GUID AND IsInactive = 1 )
		SET @result = 2

	RETURN @result
END 
##############################################
#END
