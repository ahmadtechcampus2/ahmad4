##################################################################
CREATE TRIGGER trg_Audit000_insert
	ON [Audit000] FOR INSERT
	NOT FOR REPLICATION
AS
	IF @@ROWCOUNT = 0 RETURN  
	SET NOCOUNT ON  

	DECLARE @auditForManufacture BIT =  (SELECT [dbo].fnOption_GetBit('AmncfBillOfManufactureIsAudited' , DEFAULT ))
	DECLARE @auditForBill		 BIT =  (SELECT [dbo].fnOption_GetBit('AmncfEntryOfBillIsAudited'		, DEFAULT ))
	DECLARE @chkauditForBill	 BIT =  (SELECT [dbo].fnOption_GetBit('AmncfCheckOfBillIsAudited'		, DEFAULT ))

	SELECT AuditRelGuid , AuditGuidType 
	INTO #Audit_Temp 
	FROM inserted

	IF @auditForManufacture = 1 AND EXISTS(SELECT AuditRelGuid FROM #Audit_Temp WHERE AuditGuidType  = 11 /*AUDIT_MANUFACTURE*/  )
	BEGIN
		--Insert into temporary table the bills of manufacture which are not audited before 
		SELECT  BillGuid
		INTO #Audit_Bill
		FROM #Audit_Temp
		INNER JOIN mb000 mb ON #Audit_Temp.AuditRelGuid = mb.ManGUID
		INNER JOIN bu000 bu ON mb.BillGUID = bu.Guid
		WHERE NOT  EXISTS( SELECT GUID FROM Audit000 WHERE  Audit000.AuditRelGuid = BillGuid)

		DELETE FROM #Audit_Temp WHERE AuditGuidType = 11

		INSERT INTO Audit000 ([GUID],[UserGuid],[AuditRelGuid] , [AuditGuidType] , [AuditDate]) 
		SELECT   NEWID(), [dbo].fnGetCurrentUserGUID() , BillGuid , 1 , GETDATE() 
		FROM #Audit_Bill 

		DROP TABLE #Audit_Bill 
	END 

	CREATE TABLE #Audit_Entry ( EntryGuid UNIQUEIDENTIFIER)
	CREATE TABLE #Audit_Check ( CheckGuid UNIQUEIDENTIFIER)

	IF (@chkauditForBill = 1 OR @auditForBill = 1) AND EXISTS(SELECT AuditRelGuid FROM #Audit_Temp WHERE AuditGuidType  = 1 /*AUDIT_BILL*/ )
	BEGIN
		
		--Insert into temporary table the entries of bills which are not audited before 
		IF @auditForBill = 1
			INSERT INTO #Audit_Entry
			SELECT EntryGuid
			FROM #Audit_Temp t
			INNER JOIN bu000 bu ON bu.GUID = t.AuditRelGuid
			INNER JOIN er000 er ON er.ParentGUID = bu.GUID
			INNER JOIN ce000 ce ON ce.GUID = er.EntryGUID
			AND NOT EXISTS( SELECT GUID FROM Audit000 WHERE  Audit000.AuditRelGuid = ce.GUID)

		IF @chkauditForBill = 1
			INSERT INTO #Audit_Check 
			SELECT ch.GUID
			FROM #Audit_Temp t
			INNER JOIN bu000 bu ON bu.GUID = t.AuditRelGuid
			INNER JOIN ch000 ch ON  ch.ParentGUID = bu.GUID
			AND NOT EXISTS( SELECT GUID FROM Audit000 WHERE  Audit000.AuditRelGuid = ch.GUID)
	
		DELETE FROM #Audit_Temp WHERE AuditGuidType = 1

		INSERT INTO Audit000 ([GUID],[UserGuid],[AuditRelGuid] , [AuditGuidType] , [AuditDate]) 
		SELECT  NEWID(), [dbo].fnGetCurrentUserGUID() , EntryGuid , 3 , GETDATE()
		FROM #Audit_Entry
		UNION ALL 
		SELECT  NEWID(), [dbo].fnGetCurrentUserGUID() , CheckGuid , 5 , GETDATE()
		FROM #Audit_Check		
	END 

	IF  EXISTS(SELECT AuditRelGuid FROM #Audit_Temp WHERE AuditGuidType  = 7 /*AUDIT_PAYMENT*/ )
	BEGIN

		INSERT INTO #Audit_Entry
		SELECT EntryGuid
		FROM #Audit_Temp t
		INNER JOIN py000 py ON py.GUID = t.AuditRelGuid
		INNER JOIN er000 er ON er.ParentGUID = py.GUID
		INNER JOIN ce000 ce ON ce.GUID = er.EntryGUID

		DELETE FROM #Audit_Temp WHERE AuditGuidType = 7

		INSERT INTO Audit000 ([GUID],[UserGuid],[AuditRelGuid] , [AuditGuidType] , [AuditDate]) 
		SELECT  NEWID(), [dbo].fnGetCurrentUserGUID() , EntryGuid , 3 , GETDATE()
		FROM #Audit_Entry
		
	END

	DROP TABLE #Audit_Entry 
	DROP TABLE #Audit_Temp

#######################################################################################
CREATE TRIGGER trg_Audit000_delete
	ON [Audit000] FOR DELETE
	NOT FOR REPLICATION
AS
	IF @@ROWCOUNT = 0 RETURN  
	SET NOCOUNT ON  

	DECLARE @auditForManufacture BIT =  (SELECT [dbo].fnOption_GetBit('AmncfBillOfManufactureIsAudited' , DEFAULT ))
	DECLARE @auditForBill		 BIT =  (SELECT [dbo].fnOption_GetBit('AmncfEntryOfBillIsAudited'		, DEFAULT ))
	DECLARE @chkAuditForBill	 BIT =  (SELECT [dbo].fnOption_GetBit('AmncfCheckOfBillIsAudited'		, DEFAULT ))

	SELECT AuditRelGuid , AuditGuidType 
	INTO #Audit_Temp 
	FROM deleted

	IF @auditForManufacture = 1 AND EXISTS(SELECT AuditRelGuid FROM #Audit_Temp WHERE AuditGuidType  = 11 /*AUDIT_MANUFACRTURE*/  )
		BEGIN
		--Insert into temporary table the bills of manufacture which are  audited 
		SELECT   [BillGuid]
		INTO #Audit_Bill
		FROM #Audit_Temp
		INNER JOIN mb000 mb ON #Audit_Temp.AuditRelGuid = mb.ManGUID
		INNER JOIN bu000 bu ON mb.BillGUID = bu.Guid

		DELETE FROM #Audit_Temp WHERE AuditGuidType = 11

		DELETE au FROM Audit000 au
		INNER JOIN #Audit_Bill b ON b.BillGuid  = au.AuditRelGuid 

		DROP TABLE #Audit_Bill 
	END 

	CREATE TABLE #Audit_Entry (EntryGuid UNIQUEIDENTIFIER)
	CREATE TABLE #Audit_Check ( CheckGuid UNIQUEIDENTIFIER)

	IF (@chkauditForBill = 1 OR @auditForBill = 1) AND EXISTS(SELECT AuditRelGuid FROM #Audit_Temp WHERE AuditGuidType  = 1 /*AUDIT_BILL*/ )
	BEGIN

		IF @auditForBill = 1
			INSERT INTO #Audit_Entry
			SELECT EntryGuid  
			FROM #Audit_Temp t
			INNER JOIN bu000 bu ON bu.GUID = t.AuditRelGuid
			INNER JOIN er000 er ON er.ParentGUID = bu.GUID
			INNER JOIN ce000 ce ON ce.GUID = er.EntryGUID

		IF @chkauditForBill = 1
			INSERT INTO #Audit_Check 
			SELECT ch.GUID
			FROM #Audit_Temp t
			INNER JOIN bu000 bu ON bu.GUID = t.AuditRelGuid
			INNER JOIN ch000 ch ON  ch.ParentGUID = bu.GUID
		
		DELETE FROM #Audit_Temp WHERE AuditGuidType = 1

		DELETE au FROM  Audit000 au 
		WHERE 
			EXISTS(SELECT 1 FROM #Audit_Check WHERE CheckGuid = au.AuditRelGuid )
			OR
			EXISTS(SELECT 1 FROM #Audit_Entry e WHERE e.EntryGuid = au.AuditRelGuid)
	END 

	IF  EXISTS(SELECT AuditRelGuid FROM #Audit_Temp WHERE AuditGuidType  = 7 /*AUDIT_PAYMENT*/ )
	BEGIN
		INSERT INTO #Audit_Entry
		SELECT EntryGuid  
		FROM #Audit_Temp t
		INNER JOIN py000 py ON py.GUID = t.AuditRelGuid
		INNER JOIN er000 er ON er.ParentGUID = py.GUID
		INNER JOIN ce000 ce ON ce.GUID = er.EntryGUID
		
		DELETE FROM #Audit_Temp WHERE AuditGuidType = 7

		DELETE au FROM  Audit000 au 
		INNER JOIN #Audit_Entry e ON au.AuditRelGuid = e.EntryGuid 	
	END

	DROP TABLE #Audit_Temp
	DROP TABLE #Audit_Entry 
#######################################################################################
#END