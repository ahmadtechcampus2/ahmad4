#########################################################
CREATE TRIGGER trg_AddressCountry000_CheckConstraints
	ON [AddressCountry000] FOR DELETE
	NOT FOR REPLICATION

AS
	IF @@ROWCOUNT = 0 RETURN
	SET NOCOUNT ON

	IF EXISTS (SELECT * FROM AddressCity000 aci INNER JOIN deleted d ON d.GUID = aci.ParentGUID)
	BEGIN 
		INSERT INTO [ErrorLog] ([level], [type], [c1], [g1])
		SELECT
			1,
			0,
			'AmnE0981: Can''t delete Country, it''s being used in City',
			d.GUID 
		FROM 
			AddressCity000 aci INNER JOIN deleted d ON d.GUID = aci.ParentGUID
	END 
#########################################################
CREATE TRIGGER trg_AddressCity000_CheckConstraints
	ON [AddressCity000] FOR DELETE
	NOT FOR REPLICATION

AS
	IF @@ROWCOUNT = 0 RETURN
	SET NOCOUNT ON

	IF EXISTS (SELECT * FROM AddressArea000 aar INNER JOIN deleted d ON d.GUID = aar.ParentGUID)
	BEGIN 
		INSERT INTO [ErrorLog] ([level], [type], [c1], [g1])
		SELECT
			1,
			0,
			'AmnE0982: Can''t delete City, it''s being used in Area',
			d.GUID 
		FROM 
			AddressArea000 aar INNER JOIN deleted d ON d.GUID = aar.ParentGUID
	END 
#########################################################
CREATE TRIGGER trg_AddressArea000_CheckConstraints
	ON [AddressArea000] FOR DELETE
	NOT FOR REPLICATION

AS
	IF @@ROWCOUNT = 0 RETURN
	SET NOCOUNT ON

	IF EXISTS (SELECT * FROM CustAddress000 ca INNER JOIN deleted d ON d.GUID = ca.AreaGUID)
	BEGIN 
		INSERT INTO [ErrorLog] ([level], [type], [c1], [g1])
		SELECT
			1,
			0,
			'AmnE0983: Can''t delete Area, it''s being used in customer address',
			d.GUID 
		FROM 
			CustAddress000 ca INNER JOIN deleted d ON d.GUID = ca.AreaGUID
	END 

	IF EXISTS (SELECT * FROM RestDriverAddress000 da INNER JOIN deleted d ON d.GUID = da.AddressGUID)
	BEGIN 
		INSERT INTO [ErrorLog] ([level], [type], [c1], [g1])
		SELECT
			1,
			0,
			'AmnE0984: Can''t delete Area, it''s being used in rest driver card',
			d.GUID 
		FROM 
			RestDriverAddress000 da INNER JOIN deleted d ON d.GUID = da.AddressGUID
	END 

#########################################################
CREATE TRIGGER trg_CustAddress000_CheckConstraints
	ON [CustAddress000] FOR DELETE
	NOT FOR REPLICATION

AS
	IF @@ROWCOUNT = 0 RETURN
	SET NOCOUNT ON

	IF EXISTS (SELECT * FROM bu000 bu INNER JOIN deleted d ON d.GUID = bu.CustomerAddressGUID)
	BEGIN 
		INSERT INTO [ErrorLog] ([level], [type], [c1], [g1])
		SELECT
			1,
			0,
			'AmnE0985: Can''t delete cust address, it''s being used in bill',
			d.GUID 
		FROM 
			bu000 bu INNER JOIN deleted d ON d.GUID = bu.CustomerAddressGUID
	END 
	IF EXISTS (SELECT * FROM POSOrder000 ord INNER JOIN deleted d ON d.GUID = ord.CustomerAddressID)
		OR EXISTS (SELECT * FROM POSOrderTemp000 ord INNER JOIN deleted d ON d.GUID = ord.CustomerAddressID)
	BEGIN 
		INSERT INTO [ErrorLog] ([level], [type], [c1], [g1])
		SELECT
			1,
			0,
			'AmnE0986: Can''t delete cust address, it''s being used in pos order',
			d.GUID 
		FROM 
			POSOrder000 ord INNER JOIN deleted d ON d.GUID = ord.CustomerAddressID

		INSERT INTO [ErrorLog] ([level], [type], [c1], [g1])
		SELECT
			1,
			0,
			'AmnE0986: Can''t delete cust address, it''s being used in pos order',
			d.GUID 
		FROM 
			POSOrderTemp000 ord INNER JOIN deleted d ON d.GUID = ord.CustomerAddressID
	END 

	IF EXISTS (SELECT * FROM RestOrder000 ord INNER JOIN deleted d ON d.GUID = ord.CustomerAddressID)
		OR EXISTS (SELECT * FROM RestOrderTemp000 ord INNER JOIN deleted d ON d.GUID = ord.CustomerAddressID)
	BEGIN 
		INSERT INTO [ErrorLog] ([level], [type], [c1], [g1])
		SELECT
			1,
			0,
			'AmnE0987: Can''t delete cust address, it''s being used in rest order',
			d.GUID 
		FROM 
			RestOrder000 ord INNER JOIN deleted d ON d.GUID = ord.CustomerAddressID

		INSERT INTO [ErrorLog] ([level], [type], [c1], [g1])
		SELECT
			1,
			0,
			'AmnE0987: Can''t delete cust address, it''s being used in rest order',
			d.GUID 
		FROM 
			RestOrderTemp000 ord INNER JOIN deleted d ON d.GUID = ord.CustomerAddressID
	END 
#########################################################
#END
