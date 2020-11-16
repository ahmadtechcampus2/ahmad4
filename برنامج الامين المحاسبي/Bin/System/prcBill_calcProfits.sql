###########################################################################
CREATE PROCEDURE prcBill_calcProfits
	@GUID [UNIQUEIDENTIFIER]
AS
/*
This procedure:
	- updates the profits at bi000 and bu000 for unposted bills, called explicity 
*/
	SET NOCOUNT ON

	IF NOT EXISTS (
		SELECT * 
		FROM 
			bu000 bu 
			INNER JOIN bt000 bt ON bt.GUID = bu.TypeGUID 
		WHERE 
			bu.GUID = @GUID 
			AND 
			bu.IsPosted = 0
			AND 
			bt.bAffectProfit = 1)
	BEGIN 
		RETURN
	END 

	-- declare cursors and input variables:
	DECLARE
		@c						CURSOR,
		@mtAvgPrice				[FLOAT],
		@biGUID					[UNIQUEIDENTIFIER],
		@biMatPtr				[UNIQUEIDENTIFIER],
		@biQty					[FLOAT],
		@biBonusQnt				[FLOAT],
		@biUnitPrice			[FLOAT],
		@biUnitDiscount			[FLOAT],
		@biUnitExtra			[FLOAT]

	DECLARE
		@btInputBill			[BIT],
		@btExtraAffectProfit	[BIT],
		@btDiscAffectProfit		[BIT]

	SELECT 
		@btInputBill =			bt.[bIsInput],
		@btExtraAffectProfit =	bt.bExtraAffectProfit,
		@btDiscAffectProfit =	bt.bDiscAffectProfit
	FROM 
		bu000 bu
		INNER JOIN bt000 bt ON bt.GUID = bu.TypeGUID 
	WHERE bu.GUID = @GUID

	-- helpfull vars:
	DECLARE
		@Direction	[INT],
		@SumProfits	[FLOAT],
		@Profit		[FLOAT]

	-- prepare @Direction and reset profits:
	SET @Direction = -1 * ((@btInputBill * 2) - 1)
	SET @SumProfits = 0

	-- get securiy info:
	SET @c = CURSOR FAST_FORWARD FOR
			SELECT
				[biGUID],
				[biMatPtr],
				[biQty],
				[biBonusQnt],
				[biUnitPrice],
				[biUnitDiscount],
				[biUnitExtra]
			FROM
				[dbo].[vwExtended_bi]
			WHERE
				[buGUID] = @GUID
	OPEN @c FETCH FROM @c INTO @biGUID, @biMatPtr, @biQty, @biBonusQnt, @biUnitPrice, @biUnitDiscount, @biUnitExtra

	-- start @c loop
	WHILE @@FETCH_STATUS = 0
	BEGIN  
		SELECT	@mtAvgPrice = ISNULL([AvgPrice], 0)
		FROM	[mt000]
		WHERE	[GUID] = @biMatPtr  

		SET @Profit = [dbo].[fnGetProfit] (@biQty, @biBonusQnt, @mtAvgPrice, @biUnitPrice, @biUnitExtra, @biUnitDiscount, @btExtraAffectProfit, @btDiscAffectProfit)
		SET @SumProfits = @SumProfits + @Profit

		UPDATE [bi000] 
		SET 
			[Profits] =			@Profit,
			[UnitCostPrice] =	ISNULL(@mtAvgPrice, 0)
		WHERE [GUID] = @biGUID

		FETCH FROM @c INTO @biGUID, @biMatPtr, @biQty, @biBonusQnt, @biUnitPrice, @biUnitDiscount, @biUnitExtra
	END CLOSE @c DEALLOCATE @c -- @c loop

	-- update bu000 profits:
	UPDATE [bu000] SET [Profits] = @SumProfits WHERE [GUID] = @GUID
###########################################################################
#END
