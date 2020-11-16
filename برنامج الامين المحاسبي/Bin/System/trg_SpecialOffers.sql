#########################################################
CREATE TRIGGER trg_SOItems000_CheckConstraints
	ON [SOItems000] FOR DELETE
	NOT FOR REPLICATION
AS
/*
This trigger checks:
	- not to delete used special offer Items
*/
	IF @@ROWCOUNT = 0
		RETURN
	SET NOCOUNT ON
	INSERT INTO [ErrorLog] ([level], [type], [c1], [g1], [i1])
	SELECT 	
		1, 
		0, 
		'AmnE1065: Can''t delete Special offer item(s), it''s being used ...', 
		guid, 
		(SELECT TOP 1 Number FROM bi000 WHERE soGuid = [guid])
	FROM [deleted]
	WHERE  
		(SELECT TOP 1 ISNULL(GUID, 0x0) FROM bi000 WHERE soGuid = [guid]) <> 0x0
#########################################################
CREATE TRIGGER trg_SOOfferedItems000_CheckConstraints
	ON [SOOfferedItems000] FOR DELETE
	NOT FOR REPLICATION
AS
/*
This trigger checks:
	- not to delete used special offer Offered Items
*/
	IF @@ROWCOUNT = 0
		RETURN
	SET NOCOUNT ON

	INSERT INTO [ErrorLog] ([level], [type], [c1], [g1], [i1])
	SELECT 
		1, 
		0, 
		'AmnE1066: Can''t delete Special offer offered item(s), it''s being used ...', 
		guid, 
		(SELECT TOP 1 Number FROM bi000 WHERE soGuid = [guid])
	FROM 
		[deleted]
	WHERE 
		(SELECT TOP 1 ISNULL(GUID, 0x0) FROM bi000 WHERE soGuid = [guid]) <> 0x0
#########################################################
CREATE TRIGGER trg_TempBills000_delete 
	ON TempBills000 FOR DELETE 
	NOT FOR REPLICATION
AS 

	IF @@ROWCOUNT = 0 RETURN  
	SET NOCOUNT ON  
	
	DELETE TempBillItems000
	FROM  
		TempBillItems000 tb
		INNER JOIN deleted d ON d.[GUID] = tb.BillGUID
#########################################################
#END