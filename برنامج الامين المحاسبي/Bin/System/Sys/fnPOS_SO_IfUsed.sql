###################################
CREATE FUNCTION fnPOS_SO_IfUsed(@SpecialOfferGUID [UNIQUEIDENTIFIER])
	RETURNS BIT 
AS BEGIN 
	DECLARE @IsUsed BIT = 0
	IF EXISTS(SELECT 1 FROM [POSOrderItemsTemp000] WHERE [SpecialOfferID] = @SpecialOfferGUID)
		SET @IsUsed = 1 
	IF (@IsUsed = 0) AND EXISTS(SELECT 1 FROM [POSOrderItems000] WHERE [SpecialOfferID] = @SpecialOfferGUID)
		SET @IsUsed = 1 
	RETURN @IsUsed
END 
###################################
#END
