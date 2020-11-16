######################################################
CREATE FUNCTION fnPOSSD_PrintDesign_IsItemFound(@PrintDesginGUID UNIQUEIDENTIFIER, @ItemKey INT)
	RETURNS BIT
AS
BEGIN 
	IF EXISTS (
		SELECT 
			* 
		FROM 
			POSSDPrintDesign000 d 
			INNER JOIN POSSDPrintDesignSection000 s ON d.GUID = s.ParentGUID 
			INNER JOIN POSSDPrintDesignSectionItem000 i ON s.GUID = i.ParentGUID
		WHERE 
			d.GUID = @PrintDesginGUID AND i.[Key] = @ItemKey)
			
			RETURN 1
	
	RETURN 0
END
######################################################
#END