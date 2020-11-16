##############################################
CREATE FUNCTION fnPOS_LoyaltyCards_TypeIsUsed(@GUID [UNIQUEIDENTIFIER])
	RETURNS [BIT] 
AS BEGIN 
	DECLARE @result [BIT]

	SET @result = 0 

	IF EXISTS (SELECT * FROM [POSOrderTemp000] WHERE LoyaltyCardTypeGUID = @GUID)
		SET @result = 1

	IF (@result = 0) AND EXISTS (SELECT * FROM [POSOrder000] WHERE LoyaltyCardTypeGUID = @GUID)
		SET @result = 1

	IF (@result = 0) AND EXISTS (SELECT * FROM [RestOrderTemp000] WHERE LoyaltyCardTypeGUID = @GUID)
		SET @result = 1

	IF (@result = 0) AND EXISTS (SELECT * FROM [RestOrder000] WHERE LoyaltyCardTypeGUID = @GUID)
		SET @result = 1
	
	RETURN @result
END 
##############################################
#END
