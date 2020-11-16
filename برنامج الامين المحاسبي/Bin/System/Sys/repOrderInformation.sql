################################################################################
CREATE PROCEDURE repOrderInformation
	@OrderGuid [UNIQUEIDENTIFIER]
AS
	-- „⁄·Ê„«  ÿ·»Ì… 
	SET NOCOUNT ON 
	
	SELECT 
		*
	FROM 
		vwOrderInformation
	WHERE 
		ParentGuid = @OrderGuid 
################################################################################
#END
