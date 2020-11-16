################################################################################
CREATE TRIGGER POSOrderTemp_Delete ON POSOrderTemp000  FOR DELETE
	NOT FOR REPLICATION
AS
	IF @@ROWCOUNT = 0 RETURN 
	SET NOCOUNT ON 	 

	DELETE POSOrderItemsTemp000			WHERE ParentID IN (SELECT GUID FROM DELETED)
	DELETE POSOrderDiscountTemp000		WHERE ParentID IN (SELECT GUID FROM DELETED)
	DELETE POSOrderAddedTemp000			WHERE ParentID IN (SELECT GUID FROM DELETED)
	DELETE POSOrderDiscountCardTemp000	WHERE ParentID IN (SELECT GUID FROM DELETED)
################################################################################
CREATE TRIGGER trgPOSOrder_Delete on POSOrder000 for DELETE
	NOT FOR REPLICATION
AS 
	IF @@ROWCOUNT = 0 RETURN 
	SET NOCOUNT ON 	 

	IF ISNULL (Object_ID('trg_bu000_pos_constraint'), -1) > 0
		EXEC('ALTER TABLE bu000 DISABLE TRIGGER trg_bu000_pos_constraint') 

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

	DELETE POSPaymentLink000		WHERE ParentGUID IN (SELECT [GUID] FROM DELETED) 
	DELETE billrel000				WHERE parentguid IN (SELECT [GUID] FROM DELETED) 
	DELETE POSPaymentsPackage000	WHERE GUID IN (SELECT PaymentsPackageID FROM DELETED)
	DELETE POSOrderAdded000			WHERE ParentID IN (SELECT [GUID] FROM DELETED) 
	DELETE POSOrderDiscount000		WHERE ParentID IN (SELECT [GUID] FROM DELETED) 
	DELETE POSOrderitems000			WHERE ParentID IN (SELECT [GUID] FROM DELETED) 
	DELETE POSOrderDiscountCard000	WHERE ParentID IN (SELECT [GUID] FROM DELETED) 
	IF ISNULL(Object_ID('trg_bu000_pos_constraint'), -1) > 0
		EXEC('ALTER TABLE bu000 ENABLE TRIGGER trg_bu000_pos_constraint')
################################################################################
CREATE TRIGGER trgPOSPaymentLink_Delete ON POSPaymentLink000 FOR DELETE
	NOT FOR REPLICATION
AS
	IF @@ROWCOUNT = 0 RETURN 
	SET NOCOUNT ON 	 

	-- Delete entry for deferred and currency
	DECLARE @ID UNIQUEIDENTIFIER
	
	SELECT DISTINCT en.ParentGUID 
	INTO #Entries
	FROM 
		DELETED link 
		INNER JOIN En000 en ON en.GUID = link.EntryGuid
	WHERE link.Type = 10 OR link.Type = 1

	IF EXISTS (SELECT * FROM #Entries)
	BEGIN 
		DECLARE @enCursorCurrency CURSOR

		SET @enCursorCurrency = CURSOR FAST_FORWARD FOR SELECT ParentGUID FROM #Entries

		OPEN @enCursorCurrency 
		FETCH NEXT FROM @enCursorCurrency INTO @ID
		WHILE @@FETCH_STATUS = 0 
		BEGIN 
			EXEC prcEntry_Delete @ID
			FETCH NEXT FROM @enCursorCurrency INTO @ID
		END
		CLOSE @enCursorCurrency DEALLOCATE @enCursorCurrency 
	END 

	DELETE #Entries
	INSERT INTO #Entries
	SELECT DISTINCT er.ParentGUID 
	FROM 
		DELETED link 
		INNER JOIN En000 en ON en.GUID = link.EntryGuid
		INNER JOIN Ce000 ce ON en.ParentGUID = ce.guid
		INNER JOIN er000 er ON er.EntryGUID = ce.guid
	WHERE link.Type = 4

	IF EXISTS (SELECT * FROM #Entries)
	BEGIN 
		DECLARE @enCursorCheck CURSOR 
		SET @enCursorCheck = CURSOR FAST_FORWARD FOR SELECT ParentGUID FROM #Entries

		OPEN @enCursorCheck 
		FETCH NEXT FROM @enCursorCheck INTO @ID
		WHILE @@FETCH_STATUS = 0 
		BEGIN 
			DELETE ch000 WHERE GUID = @ID
			FETCH NEXT FROM @enCursorCheck INTO @ID
		END CLOSE @enCursorCheck DEALLOCATE @enCursorCheck
	END
################################################################################
#END