################################################################################
CREATE PROC prcPOS_SO_Order_Mixed_Apply
	@OrderGUID UNIQUEIDENTIFIER, 
	@SO_Type INT,
	@SO_GUID UNIQUEIDENTIFIER, 
	@SO_Qty MONEY,
	@SO_Discount MONEY,
	@SO_DiscountType INT,
	@SO_MatGUID UNIQUEIDENTIFIER,
	@SO_GroupGUID UNIQUEIDENTIFIER,
	@SO_Unit INT,
	@SO_ApplyOnce BIT,
	@SO_CheckExactQty BIT,
	@SO_IsIncludeGroups BIT,
	@SO_Condition INT,
	@SO_AccountGUID UNIQUEIDENTIFIER,
	@SO_MatAccountGUID UNIQUEIDENTIFIER,
	@SO_DiscAccountGUID UNIQUEIDENTIFIER,
	@SO_DivDiscount INT,
	@SO_Mode INT,
	@IsReturned BIT = 0
AS 
	SET NOCOUNT ON

	SELECT 
		oi.Number AS ItemNumber, 
		oi.GUID AS ItemGUID, 
		CAST(oi.Qty AS MONEY) AS ItemQty, 
		oi.Unity AS ItemUnit, 
		oi.BillType AS ItemBillGUID, 
		
		mt.GUID AS mtGUID, 
		mt.GroupGUID AS GroupGUID, 
		mt.Unit2Fact, 
		mt.Unit3Fact, 
		
		sod.GUID AS SOD_GUID, 
		sod.MatID AS SOD_MatGUID, 
		sod.Number AS SOD_Number, 
		CAST(sod.Qty AS MONEY) AS SOD_Qty, 
		sod.Unit AS SOD_Unit, 
		sod.[Group] AS SOD_Group,

		CASE oi.Unity 
			WHEN 2 THEN CASE mt.Unit2Fact WHEN 0 THEN 1 ELSE mt.Unit2Fact END
			WHEN 3 THEN CASE mt.Unit3Fact WHEN 0 THEN 1 ELSE mt.Unit3Fact END
			ELSE 1
		END AS ItemUnitFact,

		CASE @SO_Unit
			WHEN 1 THEN CASE mt.Unit2Fact WHEN 0 THEN 1 ELSE mt.Unit2Fact END
			WHEN 2 THEN CASE mt.Unit3Fact WHEN 0 THEN 1 ELSE mt.Unit3Fact END
			ELSE 1
		END AS SO_UnitFact,

		sod.[Group] AS IsGroup,
		
		CASE sod.Unit
			WHEN 2 THEN CASE mt.Unit2Fact WHEN 0 THEN 1 ELSE mt.Unit2Fact END
			WHEN 3 THEN CASE mt.Unit3Fact WHEN 0 THEN 1 ELSE mt.Unit3Fact END
			ELSE 1
		END AS SOD_UnitFact
	INTO #SO_OrderItems
	FROM 
		dbo.fnPOS_SO_GetAvailableOrderItems(@OrderGUID, @IsReturned) oi
		INNER JOIN mt000 mt ON oi.MatID = mt.GUID 
		INNER JOIN SpecialOfferDetails000 sod ON ((sod.[Group] = 0 AND (mt.GUID = sod.MatID OR mt.Parent = sod.MatID)) OR (sod.[Group] = 1 AND ((mt.GroupGUID = sod.MatID) OR (@SO_IsIncludeGroups = 1 AND EXISTS(SELECT 1 FROM [dbo].[fnGetGroupParents](mt.GroupGUID) WHERE [GUID] = sod.MatID)))))
	WHERE 
		oi.ParentID = @OrderGUID 
		AND oi.SpecialOfferID = 0x0 
		AND sod.ParentID = @SO_GUID
	
	IF EXISTS (SELECT ItemGUID FROM #SO_OrderItems GROUP BY ItemGUID HAVING COUNT(*) > 1)
	BEGIN 
		;WITH y AS 
		(
			SELECT rn = ROW_NUMBER() OVER 
			(PARTITION BY oi.ItemGUID ORDER BY oi.IsGroup, oi.SOD_Number)
			FROM 
				#SO_OrderItems oi 
				-- INNER JOIN (SELECT ItemGUID FROM #SO_OrderItems GROUP BY ItemGUID HAVING COUNT(*) > 1) g on g.ItemGUID = oi.ItemGUID
		)
		DELETE y WHERE rn > 1;
	END 

	IF @SO_Type = 0 
		EXEC prcPOS_SO_Order_Mixed_Disc_Apply
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
	ELSE 
		EXEC prcPOS_SO_Order_Mixed_Offered_Apply
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
####################################################################################
#END
