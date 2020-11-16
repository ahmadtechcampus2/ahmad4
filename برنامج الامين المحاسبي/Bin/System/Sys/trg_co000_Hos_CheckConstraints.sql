#######################################
CREATE TRIGGER trg_co000_Hos_CheckConstraints
	ON co000 FOR INSERT, UPDATE, DELETE
	NOT FOR REPLICATION
AS
/*
This trigger checks:
	- not to delete used cost centers in Patient dossier
*/
SET NOCOUNT ON 
	IF @@ROWCOUNT = 0
		RETURN
	IF NOT EXISTS(SELECT * FROM inserted)
	BEGIN
		insert into ErrorLog (level, type, c1, g1)
			select 1, 0, 'AmnE0098: card already used in Patient Card...', d.guid
			from HosPFile000 e inner join deleted d on e.CostGuid = d.guid


	END	

#######################################
#END