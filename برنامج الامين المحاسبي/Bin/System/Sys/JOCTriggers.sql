#############################################################################
CREATE TRIGGER JOCtrOperatingBOM_ForInsertUpdate
ON JOCJobOrderOperatingBOM000
AFTER INSERT, UPDATE
AS
DECLARE @CostRank INT
DECLARE @BomGuid UNIQUEIDENTIFIER = (SELECT BOMGuid from inserted)
SELECT @CostRank = ISNULL((SELECT CostRank FROM JOCfnGetBOMActualCostRank(@BomGuid)), 0)

IF(@CostRank > 0)
	UPDATE JOCBOM000 SET ActualCostProcessingLevel = @CostRank WHERE GUID = @BomGuid
ELSE
	UPDATE JOCBOM000 SET ActualCostProcessingLevel = (SELECT CostProcessingLevel FROM JOCBOM000 WHERE GUID = @BomGuid) WHERE Guid = @BOMGuid
#############################################################################

CREATE TRIGGER JOCtrOperatingBOM_ForDelete
ON JOCJobOrderOperatingBOM000
AFTER DELETE
AS
DECLARE @CostRank INT
DECLARE @BomGuid UNIQUEIDENTIFIER = (SELECT BOMGuid from deleted)
SELECT @CostRank = ISNULL((SELECT CostRank FROM JOCfnGetBOMActualCostRank(@BomGuid)), 0)

IF(@CostRank > 0)
	UPDATE JOCBOM000 SET ActualCostProcessingLevel = @CostRank WHERE GUID = @BomGuid
ELSE
	UPDATE JOCBOM000 SET ActualCostProcessingLevel = (SELECT CostProcessingLevel FROM JOCBOM000 WHERE [GUID] = @BomGuid) WHERE Guid = @BOMGuid
#############################################################################

CREATE TRIGGER JOCtrg_DirectMatRequestion_Delete
ON DirectMatRequestion000 FOR DELETE
NOT FOR REPLICATION
AS
DELETE JOCGeneralCostItems000 FROM JOCGeneralCostItems000 AS items
INNER JOIN deleted ON items.ParentGuid = [deleted].Guid

#############################################################################
CREATE TRIGGER JOCtrg_DirectMatReturn000_Delete
ON DirectMatReturn000 FOR DELETE
NOT FOR REPLICATION
AS
DELETE JOCGeneralCostItems000 FROM JOCGeneralCostItems000 AS items
INNER JOIN deleted ON items.ParentGuid = [deleted].Guid

#############################################################################
CREATE TRIGGER JOCtrg_JOCTrans000_Delete
ON JOCTrans000 FOR DELETE
NOT FOR REPLICATION
AS
DELETE JOCGeneralCostItems000 FROM JOCGeneralCostItems000 AS items
INNER JOIN deleted ON items.ParentGuid = [deleted].Guid
#############################################################################
--CREATE TRIGGER JOC_DirectMatRequestion_trgUpdateDirectMaterialsCosts
--ON DirectMatRequestion000
--AFTER INSERT, UPDATE, DELETE
--AS
--BEGIN
--	--Insert
--	DECLARE @InsertedJobOrderGuid UNIQUEIDENTIFIER = 0x0;
--	DECLARE @DeletedJobOrder UNIQUEIDENTIFIER = 0x0

--	IF EXISTS (SELECT * FROM inserted) AND NOT EXISTS (SELECT * FROM deleted)
--	BEGIN
--		SELECT @InsertedJobOrderGuid = JobOrder FROM inserted

--		DELETE FROM JOCJobOrderDirectMaterials000 WHERE JobOrderGuid = @InsertedJobOrderGuid
--		EXEC JOCInsertDirectMaterialsCosts @InsertedJobOrderGuid

--	END

--	--Delete
--	IF NOT EXISTS (SELECT * FROM inserted) AND EXISTS (SELECT * FROM deleted)
--	BEGIN
--		DELETE FROM JOCJobOrderDirectMaterials000 WHERE JobOrderGuid = @DeletedJobOrder
--		EXEC JOCInsertDirectMaterialsCosts @DeletedJobOrder
--	END

--	--Update
--	IF EXISTS (SELECT * FROM inserted) AND EXISTS (SELECT * FROM deleted)
--	BEGIN
--		SELECT @DeletedJobOrder = JobOrder FROM deleted
--		SELECT @InsertedJobOrderGuid = JobOrder FROM inserted

--		DELETE FROM JOCJobOrderDirectMaterials000 WHERE JobOrderGuid = @DeletedJobOrder
--		EXEC JOCInsertDirectMaterialsCosts @DeletedJobOrder

--		DELETE FROM JOCJobOrderDirectMaterials000 WHERE JobOrderGuid = @InsertedJobOrderGuid
--		EXEC JOCInsertDirectMaterialsCosts @InsertedJobOrderGuid

--	END
--END
#############################################################################
--CREATE TRIGGER JOC_DirectMatReturn_trgUpdateDirectMaterialsCosts
--ON DirectMatReturn000
--AFTER INSERT, UPDATE, DELETE
--AS
--BEGIN
--	--Insert
--	DECLARE @InsertedJobOrderGuid UNIQUEIDENTIFIER = 0x0;
--	DECLARE @DeletedJobOrder UNIQUEIDENTIFIER = 0x0

--	IF EXISTS (SELECT * FROM inserted) AND NOT EXISTS (SELECT * FROM deleted)
--	BEGIN
--		SELECT @InsertedJobOrderGuid = JobOrder FROM inserted

--		DELETE FROM JOCJobOrderDirectMaterials000 WHERE JobOrderGuid = @InsertedJobOrderGuid
--		EXEC JOCInsertDirectMaterialsCosts @InsertedJobOrderGuid

--	END

--	--Delete
--	IF NOT EXISTS (SELECT * FROM inserted) AND EXISTS (SELECT * FROM deleted)
--	BEGIN
--		DELETE FROM JOCJobOrderDirectMaterials000 WHERE JobOrderGuid = @DeletedJobOrder
--		EXEC JOCInsertDirectMaterialsCosts @DeletedJobOrder
--	END

--	--Update
--	IF EXISTS (SELECT * FROM inserted) AND EXISTS (SELECT * FROM deleted)
--	BEGIN
--		SELECT @DeletedJobOrder = JobOrder FROM deleted
--		SELECT @InsertedJobOrderGuid = JobOrder FROM inserted

--		DELETE FROM JOCJobOrderDirectMaterials000 WHERE JobOrderGuid = @DeletedJobOrder
--		EXEC JOCInsertDirectMaterialsCosts @DeletedJobOrder

--		DELETE FROM JOCJobOrderDirectMaterials000 WHERE JobOrderGuid = @InsertedJobOrderGuid
--		EXEC JOCInsertDirectMaterialsCosts @InsertedJobOrderGuid

--	END
--END
#############################################################################
--CREATE TRIGGER JOC_JOCTrans_trgUpdateDirectMaterialsCosts
--ON JOCTrans000
--AFTER INSERT, UPDATE, DELETE
--AS
--BEGIN
--	--Insert
--	DECLARE @FromInsertedJobOrderGuid UNIQUEIDENTIFIER = 0x0;
--	DECLARE @FromDeletedJobOrder UNIQUEIDENTIFIER = 0x0
--	DECLARE @ToInsertedJobOrderGuid UNIQUEIDENTIFIER = 0x0;
--	DECLARE @ToDeletedJobOrder UNIQUEIDENTIFIER = 0x0


--	IF EXISTS (SELECT * FROM inserted) AND NOT EXISTS (SELECT * FROM deleted)
--	BEGIN
--		SELECT @FromInsertedJobOrderGuid = Src FROM inserted
--		SELECT @ToInsertedJobOrderGuid = Dest FROM inserted

--		DELETE FROM JOCJobOrderDirectMaterials000 WHERE JobOrderGuid = @FromInsertedJobOrderGuid
--		EXEC JOCInsertDirectMaterialsCosts @FromInsertedJobOrderGuid

--		DELETE FROM JOCJobOrderDirectMaterials000 WHERE JobOrderGuid = @ToInsertedJobOrderGuid
--		EXEC JOCInsertDirectMaterialsCosts @ToInsertedJobOrderGuid

--	END

--	--Delete
--	IF NOT EXISTS (SELECT * FROM inserted) AND EXISTS (SELECT * FROM deleted)
--	BEGIN
--		SELECT @FromDeletedJobOrder = Src FROM deleted
--		SELECT @ToDeletedJobOrder = Dest FROM deleted

--		DELETE FROM JOCJobOrderDirectMaterials000 WHERE JobOrderGuid = @FromInsertedJobOrderGuid
--		EXEC JOCInsertDirectMaterialsCosts @FromInsertedJobOrderGuid

--		DELETE FROM JOCJobOrderDirectMaterials000 WHERE JobOrderGuid = @ToInsertedJobOrderGuid
--		EXEC JOCInsertDirectMaterialsCosts @ToInsertedJobOrderGuid
--	END

--	--Update
--	IF EXISTS (SELECT * FROM inserted) AND EXISTS (SELECT * FROM deleted)
--	BEGIN
--		SELECT @FromDeletedJobOrder = Src FROM deleted
--		SELECT @ToDeletedJobOrder = Dest FROM deleted

--		SELECT @FromDeletedJobOrder = Src FROM inserted
--		SELECT @ToDeletedJobOrder = Dest FROM inserted

--		DELETE FROM JOCJobOrderDirectMaterials000 WHERE JobOrderGuid = @FromDeletedJobOrder
--		EXEC JOCInsertDirectMaterialsCosts @FromDeletedJobOrder

--		DELETE FROM JOCJobOrderDirectMaterials000 WHERE JobOrderGuid = @ToDeletedJobOrder
--		EXEC JOCInsertDirectMaterialsCosts @ToDeletedJobOrder

--		DELETE FROM JOCJobOrderDirectMaterials000 WHERE JobOrderGuid = @FromDeletedJobOrder
--		EXEC JOCInsertDirectMaterialsCosts @FromDeletedJobOrder

--		DELETE FROM JOCJobOrderDirectMaterials000 WHERE JobOrderGuid = @ToDeletedJobOrder
--		EXEC JOCInsertDirectMaterialsCosts @ToDeletedJobOrder
--	END
--END
#############################################################################