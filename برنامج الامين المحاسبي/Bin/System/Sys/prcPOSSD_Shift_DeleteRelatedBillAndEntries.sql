#################################################################
CREATE PROCEDURE prcPOSSD_Shift_DeleteRelatedBillAndEntries
-- Params -------------------------------
	@ShiftGuid				UNIQUEIDENTIFIER
-----------------------------------------   
AS
BEGIN
 DECLARE @billGuid [UNIQUEIDENTIFIER]

 SELECT @billGuid = BillGUID FROM BillRel000 WHERE ParentGUID = @ShiftGuid
 
 EXEC prcBill_delete @billGuid
 EXEC prcBill_Delete_Entry @billGuid
 DELETE FROM BillRel000 WHERE BillGUID = @billGuid

 DECLARE @defferdEntryGuid UNIQUEIDENTIFIER, @externalOperationEntryGuid UNIQUEIDENTIFIER
	
	SELECT @defferdEntryGuid = EntryGuid FROM er000 WHERE ParentGuid = @ShiftGuid AND ParentType = 701
	SELECT @externalOperationEntryGuid = EntryGuid FROM er000 WHERE ParentGuid = @ShiftGuid AND ParentType = 702
	
	EXEC prcDisableTriggers  'ce000'
	EXEC prcDisableTriggers  'en000'
	EXEC prcDisableTriggers  'er000'
	IF ( ISNULL( @defferdEntryGuid, 0x0) <> 0x0)
	BEGIN 
		
		DELETE FROM ce000 WHERE Guid = @defferdEntryGuid
		DELETE FROM en000 WHERE ParentGuid = @defferdEntryGuid
		DELETE FROM er000 WHERE EntryGUID = @defferdEntryGuid
	END
	IF ( ISNULL( @externalOperationEntryGuid, 0x0) <> 0x0)
		 BEGIN
			DELETE FROM ce000 WHERE Guid = @externalOperationEntryGuid
			DELETE FROM en000 WHERE ParentGuid = @externalOperationEntryGuid
			DELETE FROM er000 WHERE EntryGUID = @externalOperationEntryGuid
    END	
		
		EXEC prcEnableTriggers 'ce000'
		EXEC prcEnableTriggers 'en000'
		EXEC prcEnableTriggers 'er000'
	
END
#################################################################
#END 