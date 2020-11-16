################################################################################
CREATE PROC prcPOS_SO_Order_Simple_Apply
	@OrderGUID UNIQUEIDENTIFIER, 
	@SO_Type INT,
	@SO_GUID UNIQUEIDENTIFIER, 
	@SO_Qty FLOAT,
	@SO_Discount FLOAT,
	@SO_DiscountType INT,
	@SO_MatGUID UNIQUEIDENTIFIER,
	@SO_GroupGUID UNIQUEIDENTIFIER,
	@SO_Unit INT,
	@SO_ApplyOnce BIT,
	@SO_CheckExactQty BIT,
	@SO_IsIncludeGroups BIT,
	@IsReturned BIT = 0
AS 
	SET NOCOUNT ON

	IF @SO_Type = 0 -- Discount Special Offerr
	BEGIN
		EXEC prcPOS_SO_Order_Simple_Disc_Apply 
				@OrderGUID, 
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
	END ELSE BEGIN
		EXEC prcPOS_SO_Order_Simple_Offered_Apply 
				@OrderGUID, 
				@SO_GUID, 
				@SO_Qty,
				@SO_MatGUID,
				@SO_GroupGUID,
				@SO_Unit,
				@SO_ApplyOnce,
				@SO_CheckExactQty,
				@SO_IsIncludeGroups,
				@IsReturned
	END
####################################################################################
#END