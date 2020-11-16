################################################################################
CREATE PROCEDURE prcPOS_SO_Item_Apply
	@ItemGUID UNIQUEIDENTIFIER,
	@IsCanceled BIT,
	@IsReturned BIT = 0
AS
	SET NOCOUNT ON

	CREATE TABLE [#Accounts] ([GUID] [UNIQUEIDENTIFIER])

	DECLARE
		@OrderGUID UNIQUEIDENTIFIER,
		@OrderCustGUID UNIQUEIDENTIFIER,
		@OrderUserBillsGUID UNIQUEIDENTIFIER,
		@ItemBillGUID UNIQUEIDENTIFIER,
		@ItemMatGUID UNIQUEIDENTIFIER,
		@ItemGroupGUID UNIQUEIDENTIFIER,
		@ItemQty MONEY,
		@ItemType INT,
		@ItemMatUnitFact2 FLOAT,
		@ItemMatUnitFact3 FLOAT,
		@ItemOfferGUID UNIQUEIDENTIFIER,
		@ItemUnit INT,
		@ItemSOGroup INT,
		@ItemCompositionParentGuid UNIQUEIDENTIFIER

	SELECT 
		@OrderGUID = ord.GUID,
		@OrderCustGUID = ord.CustomerID,
		@OrderUserBillsGUID = ord.UserBillsID,
		@ItemMatGUID = ordi.MatID,
		@ItemQty = CAST(ordi.Qty AS MONEY),
		@ItemType = ordi.[Type],
		@ItemBillGUID = ordi.BillType,
		@ItemOfferGUID = ISNULL(ordi.SpecialOfferID, 0x0),
		@ItemUnit = ordi.Unity,
		@ItemSOGroup = ISNULL(ordi.SOGroup, 0),
		@ItemGroupGUID = mt.GroupGUID,
		@ItemMatUnitFact2 = CASE ISNULL(mt.Unit2Fact, 0) WHEN 0 THEN 1 ELSE mt.Unit2Fact END, 
		@ItemMatUnitFact3 = CASE ISNULL(mt.Unit3Fact, 0) WHEN 0 THEN 1 ELSE mt.Unit3Fact END,
		@ItemCompositionParentGuid = mt.Parent
	FROM 
		POSOrderTemp000 ord
		INNER JOIN POSOrderItemsTemp000 ordi ON ord.GUID = ordi.ParentID
		INNER JOIN mt000 mt ON mt.GUID = ordi.MatID
	WHERE ordi.GUID = @ItemGUID

	IF @ItemOfferGUID <> 0x0
	BEGIN
		IF EXISTS (SELECT 1 FROM vwPOSSpecialOffer WHERE [GUID] = @ItemOfferGUID AND OfferMode = 0)
		BEGIN 
			UPDATE oi
			SET
				oi.SpecialOfferID = 0x0,
				oi.Discount = 0,
				oi.SOGroup = 0
			OUTPUT inserted.GUID, 1, 0x0 INTO #OfferedItems
			FROM POSOrderItemsTemp000 oi
			WHERE
				oi.ParentID = @OrderGUID 
				AND SpecialOfferID = @ItemOfferGUID
				AND SOGroup = @ItemSOGroup
				AND OfferedItem != 1
		END			

		DELETE FROM POSOrderItemsTemp000
		OUTPUT deleted.GUID, 2, 0x0 
		INTO #OfferedItems
		WHERE ParentID = @OrderGUID AND OfferedItem = 1 AND SpecialOfferID = @ItemOfferGUID AND SOGroup = @ItemSOGroup

		IF @IsCanceled = 0
		BEGIN 
			UPDATE oi
			SET
				oi.SpecialOfferID = 0x0,
				oi.Discount = 0,
				oi.SOGroup = 0
			OUTPUT inserted.GUID, 1, 0x0 INTO #OfferedItems
			FROM POSOrderItemsTemp000 oi
			WHERE
				oi.GUID = @ItemGUID
				AND
				ISNULL(oi.SpecialOfferID, 0x0) != 0x0
		END
	END

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
		GUID, CustomersAccountID, CustCondID, AccountID, MatAccountID, DiscountAccountID, DivDiscount, Type, Condition, 
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

	WHILE @@FETCH_STATUS = 0 AND NOT EXISTS(SELECT 1 FROM POSOrderItemsTemp000 WHERE GUID = @ItemGUID AND ISNULL(SpecialOfferId, 0x0) != 0x0) 
	BEGIN
		DECLARE @continue BIT = 0
		IF @SO_ApplyOnce = 1 AND EXISTS(SELECT 1 FROM dbo.fnPOS_SO_GetAvailableOrderItems(@OrderGUID, @IsReturned) WHERE SpecialOfferId = @SO_GUID)
			SET @continue = 1

		IF @continue = 0 AND (ISNULL(@SO_CustomerGUID, 0x0) != 0x0 OR ISNULL(@SO_CustCondGUID, 0x0) != 0x0)
		BEGIN
			IF NOT EXISTS (SELECT * FROM [#Accounts])
			BEGIN
				DECLARE @acGUID [UNIQUEIDENTIFIER]
				SELECT @acGUID = AccountGUID FROM cu000 WHERE GUID = @OrderCustGUID
				IF ISNULL(@OrderCustGUID, 0x0) != 0x0
				BEGIN  
					INSERT INTO [#Accounts] SELECT @acGUID
					INSERT INTO [#Accounts] SELECT [GUID] FROM [dbo].[fnGetAccountParents] (@acGUID)
					INSERT INTO [#Accounts] SELECT [ParentGUID] FROM [ci000] WHERE [SonGUID] = @acGUID
				END
			END 

			SET @continue = 1
			
			IF ISNULL(@SO_CustomerGUID, 0x0) != 0x0   
			BEGIN    
				IF EXISTS (SELECT * FROM [#Accounts] WHERE [GUID] = @SO_CustomerGUID)   
					SET @continue = 0   
			END ELSE BEGIN
				DECLARE @found BIT = 0
				EXEC @found = prcIsCustCondVerified @SO_CustCondGUID, @OrderCustGUID   
				IF ((@SO_CustomerGUID = 0x0) OR EXISTS (SELECT * FROM [#Accounts] WHERE [GUID] = @SO_CustomerGUID)) AND @found = 1    
					SET @continue = 0
			END    
		END
		IF @continue = 1
		BEGIN
			FETCH NEXT FROM @OfferCursor   
				INTO @SO_GUID,
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

		IF @SO_DiscAccountGUID = 0x0 OR @SO_MatAccountGUID = 0x0 OR @SO_AccountGUID = 0x0
			SELECT 
				@SO_DiscAccountGUID =	(CASE @SO_DiscAccountGUID WHEN 0x0 THEN DefDiscAccGUID ELSE @SO_DiscAccountGUID END),
				@SO_AccountGUID =		(CASE @SO_AccountGUID WHEN 0x0 THEN DefBillAccGUID ELSE @SO_AccountGUID END),
				@SO_MatAccountGUID =	(CASE @SO_MatAccountGUID WHEN 0x0 THEN DefDiscAccGUID ELSE @SO_MatAccountGUID END)
			FROM bt000 WHERE GUID =	(SELECT TOP 1 CASE @IsReturned WHEN 0 THEN SalesID ELSE ReturnedID END FROM POSUserBills000 WHERE GUID = @OrderUserBillsGUID)

		-- Check If Mode Simple Or Mixed
		IF @SO_Mode != 0 -- Simple
		BEGIN IF @IsCanceled != 1 BEGIN 
			EXEC prcPOS_SO_Item_Simple_Apply 
					@ItemGUID, 
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
		END END ELSE -- Mixed
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

		FETCH NEXT FROM @OfferCursor   
		INTO @SO_GUID, 
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
