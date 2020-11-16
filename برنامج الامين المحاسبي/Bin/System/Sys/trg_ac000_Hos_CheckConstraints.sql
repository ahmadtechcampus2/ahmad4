############################
create TRIGGER trg_ac000_Hos_CheckConstraints
	ON ac000 FOR INSERT, UPDATE, DELETE 
	NOT FOR REPLICATION
AS 

/* 
This trigger checks: 
	- not to delete used Account centers in Doctor Employee Card
*/
	SET NOCOUNT ON 
	IF @@ROWCOUNT = 0 
		RETURN 
	IF NOT EXISTS(SELECT * FROM inserted) 
	BEGIN 
		insert into ErrorLog (level, type, c1, g1) 
			select 1, 0, 'AmnE0510: card already used in Doctor Employee Card', d.guid 
			from hosEmployee000 e inner join deleted d on e.AccGuid = d.guid 
	END	 

/*
select * from hosEmployee000
*/

############################
#END
