####################
CREATE TRIGGER trg_hosAnalysisItems000_Hos_CheckConstraints
	ON hosAnalysisItems000 FOR INSERT, UPDATE, DELETE 
	NOT FOR REPLICATION
AS 
/* 
This trigger checks: 
	- not to delete used analysis Items used in analysis card
*/ 
SET NOCOUNT ON 
	IF @@ROWCOUNT = 0 
		RETURN 
	IF NOT EXISTS(SELECT * FROM inserted) 
	BEGIN 
		insert into ErrorLog (level, type, c1, g1) 
			select 1, 0, 'AmnE0507: card already used in Analysis card...', d.guid 
			from hosAnalysis000 AS T inner join deleted d on T.GUID = d.Parentguid 
	END

/*
select * from hosAnalysisItems000
select * from hosAnalysis000
*/

####################
#END