##################################################################################
CREATE TRIGGER trg_Analysis_Delete ON HosAnalysis000 FOR DELETE
NOT FOR REPLICATION
AS
	SET NOCOUNT ON 
	DELETE  HosAnaDet000 FROM HosAnaDet000 s 
	INNER JOIN deleted d ON  s.parentGuid = d.guid  
##################################################################################
#END
