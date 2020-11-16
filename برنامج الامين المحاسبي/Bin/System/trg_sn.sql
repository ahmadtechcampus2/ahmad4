######################################################
CREATE TRIGGER trg_sn000_insert_ASSET
	ON sn000 FOR INSERT 
	NOT FOR REPLICATION
AS 
	IF @@ROWCOUNT = 0 RETURN 
	SET NOCOUNT ON 
	INSERT INTO AD000
		SELECT 
			Ins.GUID,
			ass.GUID,
			Ins.SN,
			0,
			0x0,
			0,
			0,
			0x0,
			0,
			0,
			0,
			0,
			0,
			''
		FROM
			inserted AS Ins 
			INNER JOIN mt000 AS mt
			ON ins.MatGUID = mt.GUID
			INNER JOIN AS000 AS ass
			ON mt.GUID = ass.ParentGUID
			--INNER JOIN bu000 AS bu
			--ON Ins.InGUID = bu.GUID
		WHERE 
			mt.Type = 2

	UPDATE AD SET
		InVal = BiIn.Price,-- must sum val of item
		InCurrencyGUID = BiIn.CurrencyGUID,
		InCurrencyVal = BiIn.CurrencyVal
	FROM 
		AD000 AS AD INNER JOIN Inserted AS Ins
		ON AD.GUID = Ins.GUID
		INNER JOIN BI000 AS BiIn 
		ON Ins.InGUID = BiIn.GUID

	UPDATE AD SET
		OutVal = BiOut.Price,-- must sum val of item
		OutCurrencyGUID = BiOut.CurrencyGUID,
		OutCurrencyVal = BiOut.CurrencyVal
	FROM 
		AD000 AS AD INNER JOIN Inserted AS Ins
		ON AD.GUID = Ins.GUID
		INNER JOIN BI000 AS BiOut
		ON Ins.OutGUID = BiOut.GUID
######################################################
CREATE TRIGGER trg_sn000_Delete_ASSET
	ON sn000 FOR DELETE
	NOT FOR REPLICATION
AS 
	IF @@ROWCOUNT = 0 RETURN 
	SET NOCOUNT ON 
	DELETE AD
		FROM
			Deleted AS del
			INNER JOIN mt000 AS mt
			ON del.MatGUID = mt.GUID
			INNER JOIN AD000 AS AD 
			ON del.GUID = AD.GUID
		WHERE 
			mt.Type = 2
#######################################################
#END