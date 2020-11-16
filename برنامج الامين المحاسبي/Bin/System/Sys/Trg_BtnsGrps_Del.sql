##################################################################################
CREATE TRIGGER trg_BtnsGrps_Del 
ON Bg000 
FOR DELETE
NOT FOR REPLICATION
AS
	DELETE FROM Bgi000 WHERE ParentID IN (SELECT Guid FROM Deleted)
##################################################################################
#END