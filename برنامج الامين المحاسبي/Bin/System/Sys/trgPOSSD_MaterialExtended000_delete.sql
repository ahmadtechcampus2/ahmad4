################################################################################
CREATE TRIGGER trg_POSSDMaterialExtended000_delete
    ON POSSDMaterialExtended000
    FOR DELETE
AS 
	IF @@ROWCOUNT = 0 RETURN
	SET NOCOUNT ON	

    DELETE POSSDRelatedSaleMaterial000 WHERE ParentGUID IN (SELECT [GUID] FROM deleted)
#################################################################
#END
