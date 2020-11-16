#####################################################################
CREATE FUNCTION fnGetBillMaterialsCost(@MaterialGuid UNIQUEIDENTIFIER, @GroupGuid UNIQUEIDENTIFIER,
@CurrencyGUID UNIQUEIDENTIFIER, @EndDate Date) 
RETURNS @Result TABLE ( 
	BiGuid		UNIQUEIDENTIFIER, 
	Cost		FLOAT, 
	Profit		FLOAT, 
	BuGuid		UNIQUEIDENTIFIER ) 
AS 
BEGIN 
	DECLARE  
		@BuGUID		UNIQUEIDENTIFIER,
		@BiGuid			UNIQUEIDENTIFIER, 
		@MatGuid		UNIQUEIDENTIFIER, 
		@PrevMatGuid	UNIQUEIDENTIFIER, 
		@Price			FLOAT, 
		@Qty			FLOAT, 
		@AggQty			FLOAT, 
		@Value			FLOAT, 
		@Cost			FLOAT, 
		@Profit			FLOAT,
		@Discount		FLOAT, 
		@Extra			FLOAT, 
		@Bonus			FLOAT, 
		@AffectCost		INT, 
		@AffectDiscount	INT, 
		@AffectExtra	INT, 
		@ExtraAffectsProfit INT ,  
		@DiscAffectsProfit	INT,
		@Direction		INT,
		@biLCDisc		FLOAT,
		@biLCExtra		FLOAT,
		@bNeg		BIT;

	IF @CurrencyGUID = 0x0 
		SET @CurrencyGUID = dbo.fnGetDefaultCurr()

	DECLARE C CURSOR FAST_FORWARD FOR 
		SELECT 
			 buGUID, biGUID, biMatPtr, FixedbiUnitPrice, biQty, FixedbiUnitDiscount, FixedbiUnitExtra, biBonusQnt, 
			btDirection, btAffectCostPrice, btDiscAffectCost, btExtraAffectCost, btDiscAffectProfit, btExtraAffectProfit, 
			FixedbiLCExtra, FixedbiLCDisc
		FROM 
			dbo.fnExtended_bi_Fixed(@CurrencyGUID) bi
			INNER JOIN dbo.fnGetBillsTypesList2(0x0, 0x0, 1) bt ON bt.[GUID] = bi.buType 
			JOIN dbo.fnGetMaterials(@MaterialGuid, @GroupGuid) M ON bi.biMatPtr = M.Guid
		WHERE 
			(buIsPosted > 0 OR btAffectProfit = 1) AND CAST(buDate AS DATE) <= @EndDate
		ORDER BY 
			biMatPtr, buDate, [bt].[PriorityNum], bt.[SortNumber], bi.[buNumber], bt.[SamePriorityOrder], bi.biNumber
	OPEN C; 
	FETCH NEXT FROM C INTO  
		@BuGUID, @BiGuid, @MatGuid, @Price, @Qty, @Discount, @Extra, @Bonus, @Direction, @AffectCost, @AffectDiscount, @AffectExtra, @DiscAffectsProfit, @ExtraAffectsProfit, @biLCExtra, @biLCDisc; 

	SET @PrevMatGuid = 0x0; 

	WHILE @@FETCH_STATUS = 0 
	BEGIN 
		IF @MatGuid <> @PrevMatGuid 
			SELECT @Value = 0, @AggQty = 0, @Cost = 0;
		
		DECLARE @DiscExtra FLOAT = @AffectExtra * @Extra - @AffectDiscount * @Discount ;
		 
		IF @AffectCost = 0 
		BEGIN 
			SET @AggQty = @AggQty + @Direction * (@Qty + @Bonus)  
		END
		ELSE 
		BEGIN
			IF @AggQty >= 0
			BEGIN
				IF @Qty > 0
					SET @Value = (@Cost * @AggQty) + (@Direction * @Qty * (@Price + @DiscExtra))
				ELSE IF @Qty = 0
					SET @Value = (@Cost * @AggQty) + (@Direction * @DiscExtra)
			END
			ELSE
				IF @Direction = 1 
				BEGIN
					IF @Qty > 0	
						SET @Value = @Qty * (@Price + @DiscExtra)
					ELSE IF @Qty = 0
						SET @Value =  (@Direction * @DiscExtra)	
				END

			IF @AggQty < 0
				SET @bNeg = 1
			ELSE
				SET @bNeg = 0

			SET @AggQty = @AggQty + @Direction * (@Qty + @Bonus)
			SET @Value = @Value - @biLCDisc + @biLCExtra

			IF @Value > 0 
			BEGIN
				IF ( @AggQty > 0) AND @bNeg = 0
					SET @Cost = @Value / @AggQty
				ELSE IF (@Qty > 0) AND (@Direction = 1) 
				BEGIN
				IF (@Qty + @Bonus) > 0
					SET @Cost = @Qty * (@Price + @DiscExtra) / (@Qty + @Bonus)
				END
			END
			ELSE
			BEGIN
				IF (@Qty + @Bonus) > 0
					SET @Cost = @Qty * (@Price + @DiscExtra) / (@Qty + @Bonus)		
			END
			SET @Value = 0
		END 

		SET @Profit = [dbo].[fnGetProfit](@Qty, @Bonus, @Cost, @Price, @Extra, @Discount, @ExtraAffectsProfit, @DiscAffectsProfit)
		INSERT INTO @Result VALUES(@BiGuid, ISNULL(@Cost, 0), @Profit , @BuGuid); 
		SET @PrevMatGuid = @MatGuid; 
		FETCH NEXT FROM C INTO  
			@BuGUID, @BiGuid, @MatGuid, @Price, @Qty, @Discount, @Extra, @Bonus, @Direction, @AffectCost, @AffectDiscount, @AffectExtra, @DiscAffectsProfit, @ExtraAffectsProfit, @biLCExtra, @biLCDisc; 
	END CLOSE C DEALLOCATE C

	RETURN; 
END 
#####################################################################
CREATE FUNCTION fnGetMaterials (
	@MatGuid UNIQUEIDENTIFIER, 
	@GroupGuid UNIQUEIDENTIFIER) RETURNS TABLE 
AS
RETURN
      SELECT M.mtGUID AS Guid
      FROM vwMt M JOIN dbo.fnGetGroupsList(@GroupGuid) G ON G.GUID = M.mtGroup
      WHERE @MatGuid = 0x OR M.mtGUID = @MatGuid;
#####################################################################
#END