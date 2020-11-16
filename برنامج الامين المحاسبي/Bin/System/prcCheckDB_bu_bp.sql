############################################################################################
CREATE PROCEDURE prcCheckDB_bu_bp
	@Correct [INT] = 0
AS
	-- correct: 
	IF @Correct <> 0 
	BEGIN 
		EXEC prcDisableTriggers 'bp000'
		UPDATE bp000 
		SET ParentDebitGUID = bu.GUID  
		FROM 
			bp000 bp 
			INNER JOIN en000 en ON en.GUID = bp.DebtGUID 
			INNER JOIN ce000 ce ON ce.GUID =  en.ParentGUID 
			INNER JOIN er000 er ON ce.GUID =  er.EntryGUID 
			INNER JOIN bu000 bu ON bu.GUID =  er.ParentGUID
		WHERE bp.ParentDebitGUID != bu.GUID  

		UPDATE bp000 
		SET ParentPayGUID = bu.GUID  
		FROM 
			bp000 bp 
			INNER JOIN en000 en ON en.GUID = bp.PayGUID 
			INNER JOIN ce000 ce ON ce.GUID =  en.ParentGUID 
			INNER JOIN er000 er ON ce.GUID =  er.EntryGUID 
			INNER JOIN bu000 bu ON bu.GUID =  er.ParentGUID
		WHERE bp.ParentPayGUID != bu.GUID  

		DELETE bp
		FROM 
			bp000 bp 
			LEFT JOIN bu000 bu ON bp.ParentDebitGUID = bu.guid 
		WHERE 
			bp.ParentDebitGUID != 0x0 AND bu.guid IS NULL

		DELETE bp
		FROM 
			bp000 bp 
			LEFT JOIN bu000 bu ON bp.ParentPayGUID = bu.guid 
		WHERE 
			bp.ParentPayGUID != 0x0 AND bu.guid IS NULL

		ALTER TABLE [bp000] ENABLE TRIGGER ALL 
	END 

############################################################################################
#END