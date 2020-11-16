########################################################
CREATE TRIGGER trg_ax000_useFlag
	ON dbo.ax000 FOR INSERT, UPDATE, DELETE 
	NOT FOR REPLICATION

AS 

/* 
This trigger: 
  - updates UseFlag of ad000. 
*/ 
	IF @@ROWCOUNT = 0 RETURN 
	SET NOCOUNT ON 
	 
	IF EXISTS(SELECT * FROM deleted) 
	BEGIN 
		IF UPDATE( ADGUID) 
			UPDATE ad000 SET UseFlag = UseFlag - 1 FROM ad000 AS a INNER JOIN deleted AS d ON a.GUID = d.ADGUID
	END 
	 
	IF EXISTS(SELECT * FROM inserted) 
	BEGIN 
		IF UPDATE(ADGUID) 
			UPDATE ad000 SET UseFlag = UseFlag + 1 FROM ad000 AS a INNER JOIN inserted AS i ON a.GUID = i.ADGUID 
	END 
#########################################################
#END