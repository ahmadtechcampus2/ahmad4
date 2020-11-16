#########################################################
CREATE TRIGGER trg_er000_delete ON [er000] FOR DELETE
	NOT FOR REPLICATION

AS

	IF @@rowcount = 0 RETURN
	SET NOCOUNT ON

	DECLARE
		@c CURSOR,
		@g [UNIQUEIDENTIFIER]
	
	SET @c = CURSOR FAST_FORWARD FOR SELECT [entryGuid] FROM [deleted]

	OPEN @c FETCH FROM @c INTO @g
	
	WHILE @@fetch_status = 0
	BEGIN
		EXEC [prcEntry_delete] @g
		FETCH FROM @c INTO @g
	END
	
	CLOSE @c DEALLOCATE @c
######################################################### 
CREATE TRIGGER trg_er000_insert ON [er000] FOR INSERT
	NOT FOR REPLICATION
As
	IF @@rowcount = 0 RETURN
	SET NOCOUNT ON
	DECLARE @auditForBill		 BIT =  (SELECT [dbo].fnOption_GetBit('AmncfEntryOfBillIsAudited' , DEFAULT ))
	INSERT INTO Audit000 ([GUID],[UserGuid],[AuditRelGuid] , [AuditGuidType] , [AuditDate]) 
	SELECT NEWID() , [dbo].fnGetCurrentUserGUID() , EntryGuid , 3 , GETDATE()
	FROM inserted
	INNER JOIN Audit000 au ON 
	( au.AuditRelGuid = inserted.ParentGUID AND  @auditForBill = 1  AND AuditGuidType = 1 ) 
	WHERE NOT EXISTS(SELECT [GUID] FROM Audit000 WHERE AuditRelGuid = EntryGuid) 
######################################################### 