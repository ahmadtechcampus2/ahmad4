##################
CREATE TRIGGER trg_hosSiteStatus000_Hos_CheckConstraints
	ON hosSiteStatus000 FOR INSERT, UPDATE, DELETE 
	NOT FOR REPLICATION
AS 
/* 
This trigger checks: 
	- not to delete used Site status used in Site card
*/ 
SET NOCOUNT ON 
	IF @@ROWCOUNT = 0 
		RETURN 
	IF NOT EXISTS(SELECT * FROM inserted) 
	BEGIN 
		insert into ErrorLog (level, type, c1, g1) 
			select 1, 0, 'AmnE0503: card already used in Site Card, cant delete...', d.guid 
			from hosSite000 AS T inner join deleted d on T.Status = d.guid 
	END

/*
select * from hosSiteStatus000
select * from hosSite000
*/
#############
#END