################################################################################
CREATE TRIGGER trgDiscountTypesOnDelete
ON DiscountTypes000
FOR DELETE 
NOT FOR REPLICATION
AS
BEGIN
SET NOCOUNT ON
	DELETE DiscountTypesItems000 WHERE ParentGuid IN (SELECT Guid FROM Deleted)
END
################################################################################
#END