#########################################################
CREATE TRIGGER trg_Cons000_delete  
	ON hosCons000 FOR DELETE ,UPDATE 
	NOT FOR REPLICATION
AS 
	DELETE  hosConsDet000 FROM 	hosConsDet000 s INNER JOIN deleted d ON 
		s.parentGuid = d.guid 
		

#########################################################
#END