##################################################################
CREATE PROC prcPromotionsCustType
		@PromotionGuid Uniqueidentifier
AS
	SET NOCOUNT ON 
	DECLARE @Ta TABLE ( CustTypeGuid 	Uniqueidentifier, Name NVARCHAR(250) COLLATE ARABIC_CI_AI, LatinName NVARCHAR(250)) 
	INSERT INTO  @Ta  
		VALUES (0X0, 'ָֿזה', 'Without')

	INSERT INTO  @Ta 
	SELECT 	Guid,  
			Name,
			LatinName
	FROM distct000

	SELECT 	CHK = (CASE WHEN PromotionCT.CustTypeGuid IS NULL THEN 0 ELSE 1 END),
			T.CustTypeGuid,  
			Name,
			LatinName
	FROM @Ta AS T  
	LEFT JOIN (SELECT CustTypeGuid FROM DistPromotionsCustType000 WHERE ParentGuid = @PromotionGuid ) AS PromotionCT   
				ON T.CustTypeGuid = PromotionCT.CustTypeGuid
###########################################################
#END
