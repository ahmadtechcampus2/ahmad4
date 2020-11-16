###########################
CREATE TRIGGER trgRestOrderTemp_Update On RestOrderTemp000
FOR UPDATE
 NOT FOR REPLICATION
 AS 

DECLARE @Number FLOAT, @OID FLOAT, @DID UNIQUEIDENTIFIER, @UID UNIQUEIDENTIFIER, @ID UNIQUEIDENTIFIER
	SELECT @Number = ISNULL(MAX(Number), 0) FROM RestCommand000
	--DELETE RestCommand000 WHERE ID IN (SELECT GUID FROM INSERTED)	
	DECLARE cur CURSOR FOR SELECT CashierID,GUID,DepartmentID,Number FROM INSERTED WHERE State<>1 AND State<>7
	OPEN cur FETCH FROM cur INTO @UID, @ID, @DID,@OID
	WHILE @@fetch_status=0
	BEGIN
		SET @Number = @Number + 1
		INSERT INTO RestCommand000 (Number, Department, [User], Type, Command, ID,Value) 
			SELECT @Number, @DID, @UID, 1, 2, @ID,@OID
		FETCH NEXT FROM cur INTO @UID, @ID, @DID,@OID
	END
	CLOSE cur DEALLOCATE cur
###########################
#END