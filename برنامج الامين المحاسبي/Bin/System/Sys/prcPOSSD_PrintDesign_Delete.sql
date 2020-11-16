#########################################################
CREATE PROC prcPOSSD_PrintDesign_Delete
	@GUID UNIQUEIDENTIFIER
AS
	SET NOCOUNT ON 

	DELETE POSSDPrintDesign000 WHERE [GUID] = @GUID

	
	DELETE bm 
	FROM 
		bm000 bm 
		INNER JOIN POSSDPrintDesignSectionItem000 item  ON bm.GUID = item.GUID 
		INNER JOIN POSSDPrintDesignSection000 sec ON item.ParentGUID = sec.GUID
	WHERE 
		sec.[ParentGUID] = @GUID

	DELETE item
	FROM 
		POSSDPrintDesignSectionItem000 item
		INNER JOIN POSSDPrintDesignSection000 sec ON item.ParentGUID = sec.GUID
	WHERE 
		sec.[ParentGUID] = @GUID

	DELETE POSSDPrintDesignSection000 WHERE [ParentGUID] = @GUID
#########################################################
#END
