#################################################################################
CREATE TRIGGER trgRestDriver_Delete ON RestVendor000
	FOR DELETE 
	NOT FOR REPLICATION
AS 
	IF @@ROWCOUNT = 0 RETURN 
	SET NOCOUNT ON 

	DELETE RestDriverAddress000 
	FROM 
		RestDriverAddress000 rda
		INNER JOIN deleted d ON d.GUID = rda.DriverGUID 
#################################################################################
#END
