###########################
CREATE TRIGGER trgRestOrderTemp_Delete On RestOrderTemp000
FOR DELETE
NOT FOR REPLICATION
 AS 

DECLARE @Number FLOAT, @OID FLOAT, @DID UNIQUEIDENTIFIER, @UID UNIQUEIDENTIFIER, @ID UNIQUEIDENTIFIER

	DELETE [RestOrderItemTemp000] WHERE ParentID IN (SELECT GUID FROM DELETED)
	DELETE [RestDiscTaxTemp000] WHERE ParentID IN (SELECT GUID FROM DELETED)
	DELETE [RestOrderTableTemp000] WHERE ParentID IN (SELECT GUID FROM DELETED)
	DELETE [RestOrderDiscountCardTemp000] WHERE ParentID IN (SELECT GUID FROM DELETED)

	SELECT @Number = ISNULL(MAX(Number), 0) FROM RestCommand000
	DELETE RestCommand000 WHERE ID IN (SELECT GUID FROM DELETED)	
	DECLARE cur CURSOR FOR SELECT CashierID,GUID,DepartmentID, Number FROM DELETED
	OPEN cur FETCH FROM cur INTO @UID, @ID, @DID,@OID
	WHILE @@fetch_status=0
	BEGIN
		SET @Number = @Number + 1
		INSERT INTO RestCommand000 (Number, Department, [User], Type, Command, ID,Value) 
			SELECT @Number, @DID, @UID, 1, 3, @ID,@OID
		FETCH NEXT FROM cur INTO @UID, @ID, @DID,@OID
	END
	CLOSE cur DEALLOCATE cur
###########################
CREATE TRIGGER trgRestOrderTemp_Insert On RestOrderTemp000
FOR INSERT 
NOT FOR REPLICATION
AS 

DECLARE @Number FLOAT, @OID FLOAT, @DID UNIQUEIDENTIFIER, @UID UNIQUEIDENTIFIER, @ID UNIQUEIDENTIFIER

	SELECT @Number = ISNULL(MAX(Number), 0) FROM RestCommand000
	DECLARE cur CURSOR FOR SELECT CashierID,GUID,DepartmentID,Number FROM INSERTED
	OPEN cur FETCH FROM cur INTO @UID, @ID, @DID,@OID
	WHILE @@fetch_status=0
	BEGIN
		SET @Number = @Number + 1
		INSERT INTO RestCommand000 (Number, Department, [User], Type, Command, ID,Value) 
			SELECT @Number, @DID, @UID, 1, 1, @ID,@OID
		FETCH NEXT FROM cur INTO @UID, @ID, @DID,@OID
	END
	CLOSE cur DEALLOCATE cur
###########################
#END