#############################################################################
CREATE TRIGGER JOCBOM000_AfterUpdateTrigger 
	   ON [dbo].[JOCBOM000]
	   AFTER UPDATE
	   NOT FOR REPLICATION
AS
	BEGIN
		SET NOCOUNT ON
			ALTER TABLE JOCJobOrderOperatingBOM000 DISABLE TRIGGER JOCtrOperatingBOM_ForInsertUpdate
			
			UPDATE JOCBOM
			SET JOCBOM.UseSpoilage = BOM.UseSpoilage
			FROM JOCJobOrderOperatingBOM000 JOCBOM INNER JOIN JOCBOM000 BOM ON JOCBOM.BOMGuid = BOM.GUID
			WHERE JOCBOM.UseSpoilage <> BOM.UseSpoilage

			ALTER TABLE JOCJobOrderOperatingBOM000 ENABLE TRIGGER JOCtrOperatingBOM_ForInsertUpdate
	END
#############################################################################