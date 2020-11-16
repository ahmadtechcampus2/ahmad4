################
CREATE TRIGGER trg_hosRadioGraphy000_Hos_CheckConstraints
	ON hosRadioGraphy000 FOR INSERT, UPDATE, DELETE 
	NOT FOR REPLICATION
AS 
/* 
This trigger checks: 
	- not to delete used Site used in Patient dossier
*/ 
SET NOCOUNT ON 
	IF @@ROWCOUNT = 0 
		RETURN 
	IF NOT EXISTS(SELECT * FROM inserted) 
	BEGIN 
		insert into ErrorLog (level, type, c1, g1) 
			select 1, 0, 'AmnE0505: card already used in RadioGraphy Order...', d.guid 
			from hosRadioGraphyOrderDetail000 AS T inner join deleted d on T.RadioGraphyGUID = d.guid 
	END

/*
select * from hosRadioGraphy000
select * from hosRadioGraphyOrderDetail000
hosRadioGraphyOrder000
*/
#################
#END