###########################
CREATE TRIGGER trgRestOrder_Delete On RestOrder000
FOR DELETE
NOT FOR REPLICATION
 AS 
	IF 
		EXISTS (SELECT 1 FROM deleted WHERE ISNULL(PointsCount, 0) > 0) OR 
		EXISTS (
			SELECT 1 
			FROM 
				deleted d 
				INNER JOIN POSPaymentsPackage000 pp ON pp.GUID = d.PaymentsPackageID
				INNER JOIN POSPaymentsPackagePoints000 po ON pp.GUID = po.ParentGUID)
	BEGIN 
		DECLARE @orders TABLE (GUID UNIQUEIDENTIFIER)
		
		INSERT INTO @orders (GUID)
		SELECT GUID FROM deleted WHERE ISNULL(PointsCount, 0) > 0

		INSERT INTO @orders (GUID)
		SELECT d.GUID  
		FROM 
			deleted d 
			INNER JOIN POSPaymentsPackage000 pp ON pp.GUID = d.PaymentsPackageID
			INNER JOIN POSPaymentsPackagePoints000 po ON pp.GUID = po.ParentGUID
		WHERE d.GUID NOT IN (SELECT GUID FROM @orders)

		CREATE TABLE #Errors (ErrorNumber INT)
		DECLARE 
			@c		CURSOR,
			@guid	UNIQUEIDENTIFIER
		SET @c = CURSOR FAST_FORWARD FOR SELECT GUID FROM @orders
		OPEN @c FETCH NEXT FROM @c INTO @guid
		WHILE @@FETCH_STATUS = 0
		BEGIN 	
			DELETE #Errors

			INSERT INTO #Errors EXEC prcPOS_LoyaltyCards_CancelChargedPoints @guid
			IF EXISTS (SELECT * FROM #Errors WHERE ErrorNumber > 0)
				INSERT INTO [ErrorLog]( [level], [type], [c1]) SELECT 1, 0, 'AmnE0951: Error in cancel loyalty card''s points '

			FETCH NEXT FROM @c INTO @guid
		END CLOSE @c DEALLOCATE @c
	END 
	DELETE [RestOrderItem000] WHERE ParentID IN (SELECT GUID FROM DELETED)
	DELETE [RestDiscTax000] WHERE ParentID IN (SELECT GUID FROM DELETED)
	DELETE [RestOrderTable000]  WHERE ParentID IN (SELECT GUID FROM DELETED)
	DELETE [RestOrderDiscountCard000] WHERE ParentID IN (SELECT GUID FROM DELETED)
	DELETE BillRel000 WHERE  ParentGUID IN (SELECT GUID FROM DELETED)
###########################
CREATE TRIGGER trgRestConfigure_Delete ON restconfig000
FOR DELETE 
NOT FOR REPLICATION
AS
	DELETE bg000 WHERE configid IN (SELECT GUID FROM DELETED)
	DELETE posinfos000 WHERE configid IN (SELECT GUID FROM DELETED)
###########################
#END