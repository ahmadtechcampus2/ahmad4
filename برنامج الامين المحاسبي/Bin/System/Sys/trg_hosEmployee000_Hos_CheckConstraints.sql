###############
CREATE TRIGGER trg_hosEmployee000_Hos_CheckConstraints
	ON hosEmployee000 FOR INSERT, UPDATE, DELETE 
	NOT FOR REPLICATION
AS 
/* 
This trigger checks: 
	- not to delete used Operation used in Patient dossier 
*/ 
SET NOCOUNT ON 
	IF @@ROWCOUNT = 0 
		RETURN 
	IF NOT EXISTS(SELECT * FROM inserted) 
	BEGIN 
		insert into ErrorLog (level, type, c1, g1) 
			select 1, 0, 'AmnE0502: card already used in Patient dossier...', d.guid 
			from HosPFile000 AS T inner join deleted d on T.DoctorGuid = d.guid 
	END

/*
select * from hosEmployee000
select * from HosPFile000
*/
###############
#END