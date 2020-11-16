############################################################
CREATE PROCEDURE PrcDeleteDirectExpensesEntry
	@ParentGUID UNIQUEIDENTIFIER,
	@DeleteAll INT = 0 
AS
	SET NOCOUNT ON 
	ALTER TABLE ce000 DISABLE TRIGGER trg_ce000_CheckConstraints ;

	IF(@DeleteAll = 0)
	BEGIN

		DELETE CE
		FROM CE000 AS CE 
			INNER JOIN ER000 AS ER ON ER.EntryGuid = CE.GUID 
		WHERE  ER.ParentGUID = @ParentGUID

		DELETE JOCBOMJobOrderEntry000 FROM JOCBOMJobOrderEntry000 WHERE PyGUID = @ParentGUID
	
	END
	ELSE
	BEGIN 

		DELETE CE
		FROM CE000 AS CE 
			INNER JOIN JOCBOMJobOrderEntry000 AS JobOrderEntry ON JobOrderEntry.JobOrderGUID = @ParentGUID
			INNER JOIN ER000 AS ER ON ER.EntryGuid = CE.GUID
		WHERE  ER.ParentGUID = JobOrderEntry.PyGUID

		DELETE JOCBOMJobOrderEntry000 FROM JOCBOMJobOrderEntry000 WHERE JobOrderGUID = @ParentGUID

	END

	ALTER TABLE ce000 ENABLE TRIGGER trg_ce000_CheckConstraints 
################################################################################
#END