################################################################################
CREATE PROCEDURE repOrderInformation
	@OrderGuid [UNIQUEIDENTIFIER]
AS
	-- ������� ����� 
	SET NOCOUNT ON 
	
	SELECT 
		*
	FROM 
		vwOrderInformation
	WHERE 
		ParentGuid = @OrderGuid 
################################################################################
#END
