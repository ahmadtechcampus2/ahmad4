################################################################################
CREATE PROCEDURE prcGetOrderDiscount
    @DiscountID [Uniqueidentifier], 
    @OrderID    [Uniqueidentifier],
    @OrderTotal [FLOAT] = -1
AS 
	SET NOCOUNT ON
	DECLARE  
		@IsDetailed 	[INT],
		@DiscountVal 	[FLOAT], 
		@DiscountType 	[INT],
		@RangeVal 		[FLOAT], 
		@RangeType 		[INT] 		


	SELECT 	@IsDetailed = [Detailed], 
		@DiscountVal = [Value], 
		@DiscountType = [Type] 
	FROM [DiscountTypes000] 
	WHERE [Guid] = @DiscountID
	
	SELECT 	@RangeVal = [Value], 
		@RangeType = [Type] 
	FROM [DiscountRange000] 
	WHERE ParentID = @DiscountID AND @OrderTotal between [from] and [to]

	IF (@IsDetailed = 0) 
	BEGIN  
		SELECT @IsDetailed detail, @DiscountVal value, @DiscountType type, @RangeVal RangeVal, @RangeType RangeType
		RETURN
	END 
	ELSE 
	BEGIN 
		SELECT @IsDetailed detail, @DiscountVal value, @DiscountType type, @RangeVal RangeVal, @RangeType RangeType
		SELECT  
			[Oi].[GUID], 
			[Oi].[Type], 
			[Oi].[Price], 
			[Oi].[Qty], 
			IsNull([fn].[DiscountVal], 0) discountValue, 
			IsNull([fn].[DiscountType], 0) discountType 
		FROM [POSOrderItemsTemp000] [Oi] 
		INNER JOIN (	
				SELECT 
					*  
				FROM [fnGetDiscountMats](@DiscountID) 
			   ) fn  ON [Oi].[MatID] = [fn].[Guid] 
		WHERE ([ParentID] = @OrderID) 
		ORDER BY [Number] 
		RETURN
	END 
###############################################################################
#END
