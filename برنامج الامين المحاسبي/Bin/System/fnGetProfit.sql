###########################################################################
CREATE FUNCTION fnGetProfit(
		@Qnt					[FLOAT],
		@BonusQnt				[FLOAT],
		@AvgPrice				[FLOAT],
		@UnitPrice				[FLOAT],
		@UnitExtra				[FLOAT],
		@UnitDiscount			[FLOAT],
		@ExtraAffectsProfit		[BIT],
		@DiscountAffectsProfit	[BIT]
	)
	RETURNS [FLOAT]
AS BEGIN
	RETURN
		(@Qnt * (@UnitPrice  - @AvgPrice + @UnitExtra * @ExtraAffectsProfit - @UnitDiscount * @DiscountAffectsProfit) - (@AvgPrice * @BonusQnt))
END

###########################################################################
#END