############################################
CREATE FUNCTION fnPOSSD_RelatedSale_CheckQuestionMaterialDuplicated
-- Param ----------------------------------------------------------
	  ( @materialExtendedGuid UNIQUEIDENTIFIER ,@extendedGuid UNIQUEIDENTIFIER)
-- Return ----------------------------------------------------------
RETURNS INT
--------------------------------------------------------------------
AS 
BEGIN 
	DECLARE @materialExtendedParentGuid UNIQUEIDENTIFIER
	DECLARE @type INT = 0
	
	SELECT @materialExtendedParentGuid = parent		   
	FROM mt000 
	WHERE
		GUID = @materialExtendedGuid

	IF @materialExtendedParentGuid = 0x0
		SELECT @type = Type FROM vwPOSSDMaterialExtended WHERE MaterialGUID = @materialExtendedGuid OR Parent = @materialExtendedGuid AND GUID <> @extendedGuid 
		
	SELECT @type = Type  FROM vwPOSSDMaterialExtended WHERE MaterialGUID = @materialExtendedGuid OR MaterialGUID = @materialExtendedParentGuid AND GUID <> @extendedGuid
	
	RETURN ISNULL(@type,0)
END
############################################
#END