#########################################################
CREATE TRIGGER trg_en000_update_DistVd 
	ON en000 FOR DELETE, INSERT
	NOT FOR REPLICATION
AS 
/* 
This trigger: 
  - is used to update the related en.guid in distvd000.objectguid
*/ 
	IF @@rowcount = 0 RETURN
	SET NOCOUNT ON
	--Execute the following when deleting the records to be modified from en000
	IF EXISTS(SELECT TOP 1 * FROM deleted)
	BEGIN
		UPDATE DistVd000
			SET ObjectGuid = d.AccountGuid
		FROM DistVd000 AS vd
		INNER JOIN deleted AS d ON d.Guid = vd.ObjectGuid
	END
	--Execute the following when inserting the records to be modified into en000
	IF EXISTS(SELECT TOP 1 * FROM inserted)
	BEGIN
		UPDATE DistVd000
			SET ObjectGuid = i.Guid
		FROM DistVd000 AS vd
		INNER JOIN inserted AS i ON i.AccountGuid = vd.ObjectGuid
	END
#########################################################	
#END