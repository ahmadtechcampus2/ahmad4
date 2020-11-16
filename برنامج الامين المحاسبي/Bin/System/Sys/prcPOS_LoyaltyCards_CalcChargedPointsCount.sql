##################################################################
CREATE PROC prcPOS_LoyaltyCards_CalcOrderItemsByQty
	@OrderGUID				UNIQUEIDENTIFIER,
	@LoyaltyCardTypeGUID	UNIQUEIDENTIFIER,
	@SystemType				TINYINT = 0,	-- 0: POS, 1: REST
	@IsTemp					BIT = 1
AS 
	SET NOCOUNT ON 

	DECLARE 
		@c					CURSOR,
		@Type				INT,
		@ItemGUID			UNIQUEIDENTIFIER,
		@ConditionValue		MONEY,
		@Value				MONEY,
		@Unit				INT,
		@ItemPointsCount	INT,
		@IsIncludeGroups	BIT 
	
	CREATE TABLE #OrderItems (GUID UNIQUEIDENTIFIER, ParentID UNIQUEIDENTIFIER, MatGUID UNIQUEIDENTIFIER, Qty MONEY, Unity INT, [State] INT, Type INT)
	CREATE TABLE #AppliedOrderItems (GUID UNIQUEIDENTIFIER)	
	CREATE TABLE #FilteredOrderItems (GUID UNIQUEIDENTIFIER, MatGUID UNIQUEIDENTIFIER, Qty MONEY)

	IF ISNULL(@SystemType, 0) = 1
	BEGIN 
		IF @IsTemp = 1
			INSERT INTO #OrderItems (GUID, ParentID, MatGUID, Qty, Unity, [State], Type)
			SELECT GUID, ParentID, MatID, Qty, Unity, 0, Type FROM RESTOrderItemTemp000 WHERE ParentID = @OrderGUID 
		ELSE 
			INSERT INTO #OrderItems (GUID, ParentID, MatGUID, Qty, Unity, [State], Type)
			SELECT GUID, ParentID, MatID, Qty, Unity, 0, Type FROM RESTOrderItem000 WHERE ParentID = @OrderGUID 
	END ELSE BEGIN 
		IF @IsTemp = 1
			INSERT INTO #OrderItems (GUID, ParentID, MatGUID, Qty, Unity, [State], Type)
			SELECT GUID, ParentID, MatID, Qty, Unity, [State], Type FROM POSOrderItemsTemp000 WHERE ParentID = @OrderGUID 
		ELSE 
			INSERT INTO #OrderItems (GUID, ParentID, MatGUID, Qty, Unity, [State], Type)
			SELECT GUID, ParentID, MatID, Qty, Unity, [State], Type FROM POSOrderItems000 WHERE ParentID = @OrderGUID 
	END 

	DECLARE 
		@PointsCount	INT,
		@Qty			MONEY,
		@delta			FLOAT

	SET @PointsCount =	0
	SET @Qty =			0
	SET @delta =		0.01

	SET @c = CURSOR FAST_FORWARD FOR 
		SELECT it.[Type], it.ItemGUID, CAST(it.ConditionValue AS MONEY), CAST(it.[Value] AS MONEY), it.Unit, it.PointsCount, t.IsIncludeGroups 
		FROM 
			POSLoyaltyCardTypeItem000 it
			INNER JOIN POSLoyaltyCardType000 t ON t.GUID = it.ParentGUID
		WHERE 
			t.GUID = @LoyaltyCardTypeGUID
			AND 
			t.Type = 2
		ORDER BY 
			it.Type, it.Number 

	OPEN @c FETCH NEXT FROM @c INTO @Type, @ItemGUID, @ConditionValue, @Value, @Unit, @ItemPointsCount, @IsIncludeGroups
	WHILE @@FETCH_STATUS = 0 
	BEGIN 
		DELETE #FilteredOrderItems

		INSERT INTO #FilteredOrderItems (GUID, MatGUID, Qty)
		SELECT 
			it.GUID, 
			it.MatGUID, 
			it.Qty * 
			CASE it.Unity 
				WHEN 2 THEN CASE mt.Unit2Fact WHEN 0 THEN 1 ELSE mt.Unit2Fact END
				WHEN 3 THEN CASE mt.Unit3Fact WHEN 0 THEN 1 ELSE mt.Unit3Fact END
				ELSE 1
			END / 
			CASE @Unit
				WHEN 2 THEN CASE mt.Unit2Fact WHEN 0 THEN 1 ELSE mt.Unit2Fact END
				WHEN 3 THEN CASE mt.Unit3Fact WHEN 0 THEN 1 ELSE mt.Unit3Fact END
				WHEN 4 THEN 
					CASE mt.DefUnit 
						WHEN 2 THEN CASE mt.Unit2Fact WHEN 0 THEN 1 ELSE mt.Unit2Fact END
						WHEN 3 THEN CASE mt.Unit3Fact WHEN 0 THEN 1 ELSE mt.Unit3Fact END
						ELSE 1
					END
				ELSE 1
			END 
		FROM 
			#OrderItems it 
			INNER JOIN mt000 mt ON mt.GUID = it.MatGUID
		WHERE 
			it.ParentID = @OrderGUID 
			AND 
			it.[State] = 0 
			AND 
			it.[Type] = 0
			AND 
			(
				((@Type = 0) AND (it.MatGUID = @ItemGUID))
				OR 
				((@Type = 1) AND (@IsIncludeGroups = 0) AND (mt.GroupGUID = @ItemGUID))
				OR 
				((@Type = 1) AND (@IsIncludeGroups = 1) AND EXISTS(SELECT 1 FROM [dbo].[fnGetGroupParents](mt.GroupGUID) WHERE [GUID] = @ItemGUID))
			)
			AND 
			NOT EXISTS(SELECT * FROM #AppliedOrderItems WHERE GUID = it.GUID)
		
		IF @@ROWCOUNT = 0
		BEGIN 
			-- SET @IsFound = 0
			FETCH NEXT FROM @c INTO @Type, @ItemGUID, @ConditionValue, @Value, @Unit, @ItemPointsCount, @IsIncludeGroups
			CONTINUE;
		END 

		SET @Qty = ISNULL((SELECT SUM(Qty) FROM #FilteredOrderItems), 0)
		IF @Qty - @ConditionValue < -[dbo].[fnGetZeroValueQTY]()
		BEGIN 
			-- SET @IsFound = 0
			FETCH NEXT FROM @c INTO @Type, @ItemGUID, @ConditionValue, @Value, @Unit, @ItemPointsCount, @IsIncludeGroups
			CONTINUE;
		END 

		SET @PointsCount = @PointsCount + (((CAST(@Qty AS FLOAT) + @delta) / CAST((CASE @Value WHEN 0 THEN 1 ELSE @Value END) AS FLOAT)) * @ItemPointsCount) 
		INSERT INTO #AppliedOrderItems ([GUID]) SELECT [GUID] FROM #FilteredOrderItems

		FETCH NEXT FROM @c INTO @Type, @ItemGUID, @ConditionValue, @Value, @Unit, @ItemPointsCount, @IsIncludeGroups
	END CLOSE @c DEALLOCATE @c 

	UPDATE #Result SET PointsCount = @PointsCount
##################################################################
CREATE PROC prcPOS_LoyaltyCards_CalcOrderItemsByPrice
	@OrderGUID				UNIQUEIDENTIFIER,
	@LoyaltyCardTypeGUID	UNIQUEIDENTIFIER,
	@SystemType				TINYINT = 0,	-- 0: POS, 1: REST
	@IsTemp					BIT = 1
AS 
	SET NOCOUNT ON 
	
	DECLARE 
		@c					CURSOR,
		@Type				INT,
		@ItemGUID			UNIQUEIDENTIFIER,
		@ConditionValue		MONEY,
		@Value				MONEY,
		@IsIncludeGroups	BIT 
	
	CREATE TABLE #OrderItems (
		GUID		UNIQUEIDENTIFIER, 
		ParentID	UNIQUEIDENTIFIER,
		MatGUID		UNIQUEIDENTIFIER,
		Qty			MONEY, 
		Price		MONEY,
		Discount	MONEY,
		Added		MONEY,
		Tax			MONEY,
		[State]		INT, 
		Type		INT )

	CREATE TABLE #AppliedOrderItems (GUID UNIQUEIDENTIFIER)
	CREATE TABLE #FilteredOrderItems (GUID UNIQUEIDENTIFIER, Price MONEY)

	IF ISNULL(@SystemType, 0) = 1
	BEGIN 
		IF @IsTemp = 1
			INSERT INTO #OrderItems (GUID, ParentID, MatGUID, Qty, Price, Discount, Added, Tax, [State], Type)
			SELECT GUID, ParentID, MatID, Qty, Price, Discount, Added, Tax, 0, Type FROM RESTOrderItemTemp000 WHERE ParentID = @OrderGUID 
		ELSE 
			INSERT INTO #OrderItems (GUID, ParentID, MatGUID, Qty, Price, Discount, Added, Tax, [State], Type)
			SELECT GUID, ParentID, MatID, Qty, Price, Discount, Added, Tax, 0, Type FROM RESTOrderItem000 WHERE ParentID = @OrderGUID 
	END ELSE BEGIN
		IF @IsTemp = 1
			INSERT INTO #OrderItems (GUID, ParentID, MatGUID, Qty, Price, Discount, Added, Tax, [State], Type)
			SELECT GUID, ParentID, MatID, Qty, Price, Discount, Added, Tax, [State], Type FROM POSOrderItemsTemp000 WHERE ParentID = @OrderGUID 
		ELSE 
			INSERT INTO #OrderItems (GUID, ParentID, MatGUID, Qty, Price, Discount, Added, Tax, [State], Type)
			SELECT GUID, ParentID, MatID, Qty, Price, Discount, Added, Tax, [State], Type FROM POSOrderItems000 WHERE ParentID = @OrderGUID 
	END 

	DECLARE 
		@CurrencyGUID		UNIQUEIDENTIFIER,
		@OrderCurrencyGUID	UNIQUEIDENTIFIER, 
		@OrderCurrencyValue	FLOAT,
		@OrderDate			DATE 

	SELECT TOP 1 
		@CurrencyGUID = CurrencyGUID
	FROM POSLoyaltyCardType000 
	WHERE GUID = @LoyaltyCardTypeGUID

	SELECT TOP 1 
		@OrderCurrencyGUID =	CurrencyID,
		@OrderCurrencyValue =	CurrencyValue,
		@OrderDate =			[Date]
	FROM #Order

	DECLARE @IsMainCurrency BIT = 0 
	IF EXISTS (SELECT 1 FROM my000 WHERE GUID = @CurrencyGUID AND CurrencyVal = 1)
		SET @IsMainCurrency = 1

	DECLARE 
		@PointsCount	INT,
		@Price			MONEY,
		@delta			FLOAT

	SET @PointsCount =	0
	SET @Price =		0
	SET @delta =		0.01

	SET @c = CURSOR FAST_FORWARD FOR 
		SELECT it.[Type], it.ItemGUID, CAST(it.ConditionValue AS MONEY), CAST(it.[Value] AS MONEY), t.IsIncludeGroups 
		FROM 
			POSLoyaltyCardTypeItem000 it
			INNER JOIN POSLoyaltyCardType000 t ON t.GUID = it.ParentGUID
		WHERE 
			t.GUID = @LoyaltyCardTypeGUID
			AND 
			t.Type = 1
		ORDER BY 
			it.Type, it.Number 

	OPEN @c FETCH NEXT FROM @c INTO @Type, @ItemGUID, @ConditionValue, @Value, @IsIncludeGroups
	WHILE @@FETCH_STATUS = 0 
	BEGIN 
		DELETE #FilteredOrderItems

		INSERT INTO #FilteredOrderItems (GUID, Price)
		SELECT 
			it.GUID, it.Qty * it.Price - it.Discount + it.Added
		FROM 
			#OrderItems it 
			INNER JOIN mt000 mt ON mt.GUID = it.MatGUID
		WHERE 
			it.ParentID = @OrderGUID 
			AND 
			it.[State] = 0 
			AND 
			it.[Type] = 0
			AND 
			(
				((@Type = 0) AND (it.MatGUID = @ItemGUID))
				OR 
				((@Type = 1) AND (@IsIncludeGroups = 0) AND (mt.GroupGUID = @ItemGUID))
				OR 
				((@Type = 1) AND (@IsIncludeGroups = 1) AND EXISTS(SELECT 1 FROM [dbo].[fnGetGroupParents](mt.GroupGUID) WHERE [GUID] = @ItemGUID))
			)
			AND 
			NOT EXISTS(SELECT * FROM #AppliedOrderItems WHERE GUID = it.GUID)
		
		IF @@ROWCOUNT = 0
		BEGIN 
			FETCH NEXT FROM @c INTO @Type, @ItemGUID, @ConditionValue, @Value, @IsIncludeGroups
			CONTINUE;
		END 

		SET @Price = ISNULL((SELECT SUM(Price) FROM #FilteredOrderItems), 0) 

		SET @Price = @Price / 
			(CASE @IsMainCurrency
				WHEN 1 THEN 1
				ELSE 
					(CASE 
						WHEN @CurrencyGUID = ISNULL(@OrderCurrencyGUID, 0x0) THEN @OrderCurrencyValue
						ELSE dbo.fnGetCurVal(@CurrencyGUID, @OrderDate) 
					END)
			END) 

		IF @Price - @ConditionValue < -[dbo].[fnGetZeroValuePrice]() 
		BEGIN 
			FETCH NEXT FROM @c INTO @Type, @ItemGUID, @ConditionValue, @Value, @IsIncludeGroups
			CONTINUE;
		END 

		SET @PointsCount = @PointsCount + ((CAST(@Price AS FLOAT) + @delta) / CAST((CASE @Value WHEN 0 THEN 1 ELSE @Value END) AS FLOAT))
		INSERT INTO #AppliedOrderItems ([GUID]) SELECT [GUID] FROM #FilteredOrderItems

		FETCH NEXT FROM @c INTO @Type, @ItemGUID, @ConditionValue, @Value, @IsIncludeGroups
	END CLOSE @c DEALLOCATE @c 

	UPDATE #Result SET PointsCount = @PointsCount
##################################################################
CREATE PROC prcPOS_LoyaltyCards_CalcChargedPointsCount
	@OrderGUID				UNIQUEIDENTIFIER,
	@LoyaltyCardGUID		UNIQUEIDENTIFIER,
	@LoyaltyCardTypeGUID	UNIQUEIDENTIFIER,
	@SystemType				TINYINT = 0,	-- 0: POS, 1: REST
	@IsTemp					BIT = 1
AS 
	SET NOCOUNT ON 

	CREATE TABLE #Result (ErrorNumber INT, PointsCount INT)
	
	INSERT INTO #Result (ErrorNumber, PointsCount) 
	SELECT 0, 0
	
	CREATE TABLE #Order (GUID UNIQUEIDENTIFIER, SubTotal MONEY, CurrencyID UNIQUEIDENTIFIER, CurrencyValue FLOAT, [Date] DATE)
	
	DECLARE @MainCurrencyGUID UNIQUEIDENTIFIER
	SET @MainCurrencyGUID = ISNULL((SELECT TOP 1 GUID FROM my000 WHERE CurrencyVal = 1 ORDER BY Number), 0x0)

	IF ISNULL(@SystemType, 0) = 1
	BEGIN 
		IF @IsTemp = 1
			INSERT INTO #Order SELECT GUID, SubTotal - Discount + Added, CASE ISNULL(CurrencyID, 0x0) WHEN 0x0 THEN @MainCurrencyGUID ELSE CurrencyID END, 1, [Date] FROM RESTOrderTemp000 WHERE GUID = @OrderGUID
		ELSE 
			INSERT INTO #Order SELECT GUID, SubTotal - Discount + Added, CASE ISNULL(CurrencyID, 0x0) WHEN 0x0 THEN @MainCurrencyGUID ELSE CurrencyID END, 1, [Date]  FROM RESTOrder000 WHERE GUID = @OrderGUID
	END ELSE BEGIN 
		IF @IsTemp = 1
			INSERT INTO #Order SELECT GUID, SubTotal - Discount + Added, CASE ISNULL(CurrencyID, 0x0) WHEN 0x0 THEN @MainCurrencyGUID ELSE CurrencyID END, 
				CASE ISNULL(CurrencyValue, 0) WHEN 0 THEN 1 ELSE CurrencyValue END, [Date] FROM POSOrderTemp000 WHERE GUID = @OrderGUID
		ELSE 
			INSERT INTO #Order SELECT GUID, SubTotal - Discount + Added, CASE ISNULL(CurrencyID, 0x0) WHEN 0x0 THEN @MainCurrencyGUID ELSE CurrencyID END, 
				CASE ISNULL(CurrencyValue, 0) WHEN 0 THEN 1 ELSE CurrencyValue END, [Date]  FROM POSOrder000 WHERE GUID = @OrderGUID
	END 

	IF NOT EXISTS (SELECT * FROM #Order)
	BEGIN 
		UPDATE #Result SET ErrorNumber = 41
		GOTO exitProc
	END 
	
	IF NOT EXISTS (SELECT * FROM POSLoyaltyCardType000 WHERE GUID = @LoyaltyCardTypeGUID AND IsInactive = 0)
	BEGIN 
		UPDATE #Result SET ErrorNumber = 2
		GOTO exitProc
	END 

	DECLARE 
		@Type			INT,
		@Value			MONEY,
		@PointValue		INT,
		@CurrencyGUID	UNIQUEIDENTIFIER

	SET @Type =			0
	SET @Value =		0
	SET @PointValue =	0
	
	SELECT TOP 1 
		@Type =			[Type],
		@Value =		CAST([Value] AS MONEY),
		@PointValue =	[PointValue],
		@CurrencyGUID = CurrencyGUID
	FROM POSLoyaltyCardType000 
	WHERE GUID = @LoyaltyCardTypeGUID

	DECLARE @IsMainCurrency BIT = 0 
	IF @MainCurrencyGUID = @CurrencyGUID
		SET @IsMainCurrency = 1

	IF @Type = 0	-- TOTAL
	BEGIN 
		DECLARE @SubTotal MONEY
		SELECT 
			@SubTotal = CAST(SubTotal AS MONEY) / 
				(CASE @IsMainCurrency
					WHEN 1 THEN 1
					ELSE 
						(CASE 
							WHEN @CurrencyGUID = ISNULL(CurrencyID, 0x0) THEN [CurrencyValue]
							ELSE dbo.fnGetCurVal(@CurrencyGUID, [Date])
						END)
				END)
		FROM #Order

		IF @SubTotal - @Value >= -[dbo].[fnGetZeroValuePrice]() 
		BEGIN 
			DECLARE @delta FLOAT = 0.01
			UPDATE #Result SET PointsCount = (CASE @PointValue WHEN 0 THEN 0 ELSE (CAST(@SubTotal AS FLOAT) + @delta) / CAST(@PointValue AS FLOAT) END) 
			GOTO exitProc
		END 
	END ELSE IF @Type = 1
	BEGIN 
		EXEC prcPOS_LoyaltyCards_CalcOrderItemsByPrice @OrderGUID, @LoyaltyCardTypeGUID, @SystemType, @IsTemp
	END ELSE IF @Type = 2
	BEGIN 
		EXEC prcPOS_LoyaltyCards_CalcOrderItemsByQty @OrderGUID, @LoyaltyCardTypeGUID, @SystemType, @IsTemp
	END
	exitProc:
		SELECT * FROM #Result
##################################################################
#END
