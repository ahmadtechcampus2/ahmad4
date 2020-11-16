################################################################################
CREATE PROCEDURE prcPOS_SO_Order_Apply
	@OrderGUID UNIQUEIDENTIFIER,
	@IsReturned BIT = 0
AS
	SET NOCOUNT ON

	CREATE TABLE [#Accounts] ([GUID] [UNIQUEIDENTIFIER])
	
	DECLARE
		@OrderCustGUID UNIQUEIDENTIFIER,
		@OrderUserBillsGUID UNIQUEIDENTIFIER

	SELECT 
		@OrderCustGUID = CustomerID,
		@OrderUserBillsGUID = UserBillsID
	FROM 
		POSOrderTemp000
	WHERE GUID = @OrderGUID

	UPDATE oi
	SET
		oi.SpecialOfferID = 0x0,
		oi.Discount = 0,
		oi.SOGroup = 0
	OUTPUT inserted.Guid, 1, 0x0 INTO #OfferedItems
	FROM 
		POSOrderItemsTemp000 oi
		INNER JOIN dbo.fnPOS_SO_GetAvailableOrderItems(@OrderGUID, @IsReturned) fn ON oi.GUID = fn.GUID
	WHERE
		ISNULL(oi.SpecialOfferID, 0x0) != 0x0
		AND 
		oi.OfferedItem != 1

	UPDATE oi
	SET oi.SOGroup = 0
	FROM POSOrderItemsTemp000 oi
	WHERE
		oi.ParentID = @OrderGUID AND
		ISNULL(oi.SpecialOfferID, 0x0) = 0x0 AND 
		ISNULL(oi.SOGroup, 0) != 0

	DELETE FROM oi	
	OUTPUT deleted.Guid, 2, 0x0 INTO #OfferedItems
	FROM 
		POSOrderItemsTemp000 oi
		INNER JOIN dbo.fnPOS_SO_GetAvailableOrderItems(@OrderGUID, @IsReturned) fn ON oi.GUID = fn.GUID
	WHERE oi.OfferedItem = 1 

	UPDATE oi
	SET Number = h.Number							
	FROM 
		POSOrderItemsTemp000 oi
		INNER JOIN (SELECT GUID, ROW_NUMBER() OVER(ORDER BY Number, SOGroup) AS Number FROM POSOrderItemsTemp000 WHERE [ParentID] = @OrderGUID) h 
			ON h.GUID = oi.GUID
	WHERE oi.Number != h.Number

	DECLARE @SO_GUID UNIQUEIDENTIFIER,
			@SO_CustomerGUID UNIQUEIDENTIFIER,
			@SO_CustCondGUID UNIQUEIDENTIFIER,
			@SO_AccountGUID UNIQUEIDENTIFIER,
			@SO_MatAccountGUID UNIQUEIDENTIFIER,
			@SO_DiscAccountGUID UNIQUEIDENTIFIER,
			@SO_DivDiscount INT,
			@SO_Type INT,
			@SO_Condition INT,
			@SO_Qty MONEY,
			@SO_Discount FLOAT,
			@SO_DiscountType INT,
			@SO_Mode INT,
			@SO_MatGUID UNIQUEIDENTIFIER,
			@SO_GroupGUID UNIQUEIDENTIFIER,
			@SO_Unit INT,
			@SO_ApplyOnce BIT,
			@SO_CheckExactQty BIT,
			@SO_IsIncludeGroups BIT 

	DECLARE @OfferCursor CURSOR 
	SET @OfferCursor = CURSOR FAST_FORWARD FOR
		SELECT
			Guid, CustomersAccountID, CustCondID, AccountID, MatAccountID, DiscountAccountID, DivDiscount, Type, Condition, 
			Qty, Discount, DiscountType, OfferMode, MatID, GroupID, Unit, ApplayOnce, CheckExactQty, IsIncludeGroups
		FROM vwPOSSpecialOffer
		WHERE Active = 1 AND (CAST(GETDATE() AS DATE) BETWEEN StartDate AND EndDate)
		ORDER BY OfferIndex DESC

	OPEN @OfferCursor FETCH NEXT FROM @OfferCursor INTO 
			@SO_GUID,
			@SO_CustomerGUID,
			@SO_CustCondGUID,
			@SO_AccountGUID,
			@SO_MatAccountGUID,
			@SO_DiscAccountGUID,
			@SO_DivDiscount,
			@SO_Type,
			@SO_Condition,
			@SO_Qty,
			@SO_Discount,
			@SO_DiscountType,
			@SO_Mode,
			@SO_MatGUID,
			@SO_GroupGUID,
			@SO_Unit,
			@SO_ApplyOnce,
			@SO_CheckExactQty,
			@SO_IsIncludeGroups

	WHILE @@FETCH_STATUS = 0  
	BEGIN
		IF @SO_CustomerGUID <> 0x0 OR @SO_CustCondGUID <> 0x0
		BEGIN
			IF NOT EXISTS (SELECT * FROM [#Accounts])
			BEGIN
				DECLARE @acGUID [UNIQUEIDENTIFIER]
				SELECT @acGUID = [cuAccount] FROM [vwCu] WHERE [cuGuid] = @OrderCustGUID
				IF ISNULL(@OrderCustGUID, 0x0) != 0x0
				BEGIN  
					INSERT INTO [#Accounts] SELECT @acGUID
					INSERT INTO [#Accounts] SELECT [GUID] FROM [dbo].[fnGetAccountParents] (@acGUID)
					INSERT INTO [#Accounts] SELECT [ParentGUID] FROM [ci000] WHERE [SonGuid] = @acGUID
				END
			END 

			DECLARE @checkCusts BIT = 0
			DECLARE @found BIT = 0
			IF ISNULL(@SO_CustomerGUID, 0x0) != 0x0
			BEGIN    
				IF EXISTS (SELECT * FROM [#Accounts] WHERE [GUID] = @SO_CustomerGUID)   
					SET @checkCusts = 1   
			END ELSE BEGIN
				EXEC @found = prcIsCustCondVerified @SO_CustCondGUID, @OrderCustGUID   
				IF ((@SO_CustomerGUID = 0x0) OR EXISTS (SELECT * FROM [#Accounts] WHERE [GUID] = @SO_CustomerGUID)) AND @found = 1    
					SET @checkCusts = 1   
			END    

			IF @checkCusts = 0
			BEGIN
				FETCH NEXT FROM @OfferCursor   
					INTO 
						@SO_GUID,
						@SO_CustomerGUID,
						@SO_CustCondGUID,
						@SO_AccountGUID,
						@SO_MatAccountGUID,
						@SO_DiscAccountGUID,
						@SO_DivDiscount,
						@SO_Type,
						@SO_Condition,
						@SO_Qty,
						@SO_Discount,
						@SO_DiscountType,
						@SO_Mode,
						@SO_MatGUID,
						@SO_GroupGUID,
						@SO_Unit,
						@SO_ApplyOnce,
						@SO_CheckExactQty,
						@SO_IsIncludeGroups
				CONTINUE;
			END
		END

		IF @SO_DiscAccountGUID = 0x0 OR @SO_MatAccountGUID = 0x0 OR @SO_AccountGUID = 0x0
			SELECT 
				@SO_DiscAccountGUID =	(CASE @SO_DiscAccountGUID WHEN 0x0 THEN DefDiscAccGUID ELSE @SO_DiscAccountGUID END),
				@SO_AccountGUID =		(CASE @SO_AccountGUID WHEN 0x0 THEN DefBillAccGUID ELSE @SO_AccountGUID END),
				@SO_MatAccountGUID =	(CASE @SO_MatAccountGUID WHEN 0x0 THEN DefDiscAccGUID ELSE @SO_MatAccountGUID END)
			FROM bt000 WHERE GUID =	(SELECT TOP 1 CASE @IsReturned WHEN 0 THEN SalesID ELSE ReturnedID END FROM POSUserBills000 WHERE GUID = @OrderUserBillsGUID)

		-- Check If Mode Simple Or Mixed
		IF @SO_Mode != 0 -- Simple
		BEGIN
			EXEC prcPOS_SO_Order_Simple_Apply
					@OrderGUID, 
					@SO_Type,
					@SO_GUID, 
					@SO_Qty,
					@SO_Discount,
					@SO_DiscountType,
					@SO_MatGUID,
					@SO_GroupGUID,
					@SO_Unit,
					@SO_ApplyOnce,
					@SO_CheckExactQty,
					@SO_IsIncludeGroups,
					@IsReturned
		END
		ELSE -- Mixed
		BEGIN
			EXEC prcPOS_SO_Order_Mixed_Apply
					@OrderGUID, 
					@SO_Type,
					@SO_GUID, 
					@SO_Qty,
					@SO_Discount,
					@SO_DiscountType,
					@SO_MatGUID,
					@SO_GroupGUID,
					@SO_Unit,
					@SO_ApplyOnce,
					@SO_CheckExactQty,
					@SO_IsIncludeGroups,
					@SO_Condition,
					@SO_AccountGUID,
					@SO_MatAccountGUID,
					@SO_DiscAccountGUID,
					@SO_DivDiscount,
					@SO_Mode,
					@IsReturned
		END
		FETCH NEXT FROM @OfferCursor   
		INTO 
			@SO_GUID, 
			@SO_CustomerGUID,
			@SO_CustCondGUID,
			@SO_AccountGUID,
			@SO_MatAccountGUID,
			@SO_DiscAccountGUID,
			@SO_DivDiscount,
			@SO_Type,
			@SO_Condition,
			@SO_Qty,
			@SO_Discount,
			@SO_DiscountType,
			@SO_Mode,
			@SO_MatGUID,
			@SO_GroupGUID,
			@SO_Unit,
			@SO_ApplyOnce,
			@SO_CheckExactQty,
			@SO_IsIncludeGroups
	END CLOSE @OfferCursor DEALLOCATE @OfferCursor
####################################################################################
#END
