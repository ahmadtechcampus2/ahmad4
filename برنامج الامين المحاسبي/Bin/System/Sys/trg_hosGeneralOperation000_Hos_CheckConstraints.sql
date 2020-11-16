################################
CREATE TRIGGER trg_hosGeneralOperation000_Hos_CheckConstraints
	ON hosGeneralOperation000 FOR INSERT, UPDATE, DELETE
	NOT FOR REPLICATION 
AS 
/* 
This trigger checks: 
	- not to delete used General Operation used in Patient dossier 
*/ 
SET NOCOUNT ON 
	IF @@ROWCOUNT = 0 
		RETURN 
	IF NOT EXISTS(SELECT * FROM inserted) 
	BEGIN 
		insert into ErrorLog (level, type, c1, g1) 
			select 1, 0, 'AmnE0500: card already used in Patient dossier...', d.guid 
			from hosGeneralTest000 AS T inner join deleted d on T.OperationGuid = d.guid 
			inner join HosPFile000 AS e  ON e.Guid = T.FileGuid  
	END

/*
ÃÚãÇá ÚÇãÉ
select * from hosGeneralOperation000
select * from HosPFile000
select * from hosGeneralTest000

*/
###############################
#END