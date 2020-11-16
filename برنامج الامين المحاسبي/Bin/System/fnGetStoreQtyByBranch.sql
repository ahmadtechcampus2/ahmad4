#########################################################
CREATE FUNCTION fnGetStoreQtyByBranch
(
	@MatGuid UNIQUEIDENTIFIER,
	@StoreGuid UNIQUEIDENTIFIER = 0x0,
	@BranchGuid UNIQUEIDENTIFIER = 0x0
) 
RETURNS FLOAT 
AS
BEGIN 
	RETURN
	( 
	SELECT 
		SUM((CASE btIsInput WHEN 1 THEN 1 ELSE -1 END) * (biQty + biBonusQnt)) AS Qnt 
	FROM 
		vwExtended_Bi 
	WHERE 
		biMatPtr = @MatGuid 
		AND (buIsPosted = 1)
		AND ((ISNULL(@BranchGuid, 0x0) = 0X0) OR (buBranch = @BranchGuid))
		AND ((ISNULL(@StoreGUID, 0x0) = 0X0) OR (biStorePtr = @StoreGUID))
	GROUP BY 
		CASE ISNULL(@BranchGuid, 0x0) WHEN 0x0 THEN 0x0 ELSE buBranch END,
		CASE ISNULL(@StoreGUID, 0x0) WHEN 0x0 THEN 0x0 ELSE biStorePtr END
	)
		
END;
#########################################################
#END 