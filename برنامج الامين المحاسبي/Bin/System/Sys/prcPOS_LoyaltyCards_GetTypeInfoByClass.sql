##################################################################
CREATE PROC prcPOS_LoyaltyCards_GetTypeInfoByClass
	@LoyaltyCardClassificationGuid UNIQUEIDENTIFIER
AS 
	SET NOCOUNT ON 

	SELECT TOP 1 
		*		
	FROM 
		vwPOSLoyaltyCardtype
	WHERE 
		ClassificationGUID = @LoyaltyCardClassificationGuid
		AND 
		IsInactive = 0	
#######################################################################################
#END
