###############################################################################
CREATE PROCEDURE prcSO_GetBillMultiItems
	@BillGUID UNIQUEIDENTIFIER
AS
	SET NOCOUNT ON

	DECLARE
		@BillTypeGUID UNIQUEIDENTIFIER,
		@BillDate DATETIME,
		@BillCostGUID UNIQUEIDENTIFIER,
		@BillCustGUID UNIQUEIDENTIFIER,
		@BillAccountGUID UNIQUEIDENTIFIER,
		@BillCurrencyGUID UNIQUEIDENTIFIER,
		@IsFound BIT,
		@lang INT 
		
	SET @lang = [dbo].[fnConnections_GetLanguage]()

	SELECT TOP 1
		@BillTypeGUID = [BillTypeGUID],
		@BillDate = [Date],
		@BillCostGUID = [CostGUID],
		@BillCustGUID = [CustomerGUID],
		@BillCurrencyGUID = [CurrencyGUID]
	FROM 
		TempBills000 
	WHERE
		[GUID] = @BillGUID


	SELECT TOP 1 @BillAccountGUID = AccountGUID FROM cu000 WHERE [GUID] = @BillCustGUID
	
	
	CREATE TABLE [#ApplicableSO](
		soGUID UNIQUEIDENTIFIER,
		soCode NVARCHAR(250),
		soName NVARCHAR(250) COLLATE ARABIC_CI_AI,
		soCount INT,
		soType INT,
		soItemsCondition INT,
		soOfferedItemsCondition INT,  
		soRequiredQuantity FLOAT,
		soUnit INT,
		soGroup INT,		-- SOGroup in the TempBillItems000 
		soIsApplicable BIT, -- Is the special offer aplicable to achieve without any conflict 
		soIsAchieved BIT, 
		groupGUID UNIQUEIDENTIFIER,
		groupDescription NVARCHAR(250),
		groupIsSpecified BIT,
		groupRequiredQuantity FLOAT,
		groupUnit INT,
		groupUnitName NVARCHAR(250),
		groupType INT, -- item or offered item
		groupItemType INT,
		groupPriceKind INT,
		groupPriceType INT,
		groupPrice FLOAT,
		groupDiscountType INT, 
		groupDiscount FLOAT,
		groupIsApplicable BIT,
		groupOfferedItemGUID UNIQUEIDENTIFIER,
		itemNumber INT,
		itemQuantity FLOAT,
		itemUnit INT,
		itemUnitName NVARCHAR(250),
		itemUnitFact FLOAT,
		itemPrice FLOAT,
		itemDiscount FLOAT,
		itemIsBouns BIT,
		itemBounsQuantity FLOAT,
		itemMaterialGuid UNIQUEIDENTIFIER,
		itemDescription NVARCHAR(250),
		itemMustDivided BIT,
		itemReservedQuantity FLOAT)
	
	SELECT 
		[GUID], 
		CustCondGUID,
		ItemsCondition, 
		OfferedItemsCondition,
		IsApplicableToCombine,
		Quantity,
		Unit
	INTO 
		[#so] 
	FROM 
		vwSpecialOffers [so]
	WHERE 
		(IsActive = 1) AND ([Type] = 2) /*multi items*/ AND (@BillDate BETWEEN StartDate AND EndDate)
		AND 
		((IsAllBillTypes = 1) OR ((IsAllBillTypes = 0) AND (@BillTypeGUID IN (SELECT BillTypeGUID FROM SOBillTypes000 WHERE [SpecialOfferGUID] = so.GUID))))
		AND
		((CostGUID = 0x0) OR ((CostGUID != 0x0) AND (@BillCostGUID = CostGUID)))
		AND 
		((AccountGUID = 0x0) OR ((AccountGUID != 0x0) AND (AccountGUID IN (SELECT [GUID] FROM [dbo].[fnGetAccountsList](@BillAccountGUID, DEFAULT)))))
	
	IF EXISTS(SELECT * FROM [#so] WHERE CustCondGUID != 0x0)
	BEGIN 
		DECLARE 
			@soCursor CURSOR,
			@CustCondGUID UNIQUEIDENTIFIER,
			@soGUID UNIQUEIDENTIFIER
		
		SET @soCursor = CURSOR FAST_FORWARD FOR SELECT [GUID], CustCondGUID FROM [#so] WHERE CustCondGUID != 0x0
		OPEN @soCursor FETCH NEXT FROM @soCursor INTO @soGUID, @CustCondGUID
		WHILE @@FETCH_STATUS = 0
		BEGIN 
			EXEC @IsFound = prcIsCustCondVerified @CustCondGUID, @BillCustGUID
			IF @IsFound = 0
				DELETE [#so] WHERE [GUID] = @soGUID 
			
			FETCH NEXT FROM @soCursor INTO @soGUID, @CustCondGUID
		END 
		CLOSE @soCursor DEALLOCATE @soCursor
	END 
	
	IF EXISTS(SELECT * FROM [#so])
	BEGIN 
		DECLARE 
			@ApplicableSOCursor CURSOR,
			@GroupCursor CURSOR,
			@MaterialCursor CURSOR,
			@SpecialOfferGUID UNIQUEIDENTIFIER,
			@soItemsCondition TINYINT,
			@soOfferedItemsCondition TINYINT,
			@soIsApplicableToCombine BIT,
			@soQuantity FLOAT,
			@soUnit TINYINT,
			@groupGUID UNIQUEIDENTIFIER,
			@MaterialGUID UNIQUEIDENTIFIER,
			@IsAchieved BIT, 
			@ItemType TINYINT, -- 0 Product, 1 Group, 2 Product Condition 
			@ItemGUID UNIQUEIDENTIFIER,
			@IsSpecified BIT,
			@IsIncludeGroups BIT,
			@GroupQuantity FLOAT,
			@GroupUnit TINYINT,
			@Number INT,
			@Quantity FLOAT,
			@Unit INT,
			@Price FLOAT,
			@ItemPartType TINYINT -- 0 item, 1 offered item 
		
		CREATE TABLE #Items(
			SpecialOfferGUID UNIQUEIDENTIFIER,
			GroupGUID UNIQUEIDENTIFIER,
			MaterialGUID UNIQUEIDENTIFIER,
			Number FLOAT,
			Quantity FLOAT,
			Unit INT,
			Price FLOAT,
			ItemUnitFact FLOAT,
			GroupUnitFact FLOAT)
			
		CREATE TABLE #Groups(
			SpecialOfferGUID UNIQUEIDENTIFIER,
			GroupGUID UNIQUEIDENTIFIER,
			RequiredQuantity FLOAT,
			Unit TINYINT,
			IsSpecified BIT, 
			ItemType TINYINT,
			GroupCount TINYINT,
			IsAchieved BIT,
			IsChecked BIT,
			ItemPartType TINYINT) -- 0 item, 1 offered item
			
		CREATE TABLE #BillItems(
			SpecialOfferGUID UNIQUEIDENTIFIER,
			GroupGUID UNIQUEIDENTIFIER,
			MaterialGUID UNIQUEIDENTIFIER,
			Number INT,
			Quantity FLOAT,
			Unit INT,
			Price FLOAT,
			ItemUnitFact FLOAT,
			GroupUnitFact FLOAT,
			GroupFlag BIT,
			SpecialOfferFlag BIT,
			MustDivided BIT,
			ReservedQuantity FLOAT,
			SOGroup INT,
			ApplyCount INT)
		
		SET @ApplicableSOCursor = CURSOR FAST_FORWARD FOR SELECT [GUID], ItemsCondition, OfferedItemsCondition, IsApplicableToCombine, Quantity, Unit FROM [#so]
		OPEN @ApplicableSOCursor FETCH NEXT FROM @ApplicableSOCursor INTO @SpecialOfferGUID, @soItemsCondition, @soOfferedItemsCondition, @soIsApplicableToCombine, @soQuantity, @soUnit
		WHILE @@FETCH_STATUS = 0
		BEGIN 
			SET @IsAchieved = 1
			TRUNCATE TABLE #Groups
			TRUNCATE TABLE #Items
			TRUNCATE TABLE #BillItems
			
			SET @GroupCursor = CURSOR FAST_FORWARD FOR 
				SELECT 
					[GUID], 
					ItemType, 
					ItemGUID, 
					IsSpecified, 
					IsIncludeGroups, 
					CASE @soItemsCondition
						WHEN 1 THEN @soQuantity
						ELSE Quantity
					END, 
					Unit,
					0
				FROM 
					[SOItems000] 
				WHERE 
					[SpecialOfferGUID] = @SpecialOfferGUID
				UNION ALL 
				SELECT 
					[GUID], 
					ItemType, 
					ItemGUID, 
					0,
					0,
					Quantity, 
					Unit,
					1
				FROM 
					[SOOfferedItems000] 
				WHERE 
					[SpecialOfferGUID] = @SpecialOfferGUID
				
			OPEN @GroupCursor FETCH NEXT FROM @GroupCursor INTO @groupGUID, @ItemType, @ItemGUID, @IsSpecified, @IsIncludeGroups, @GroupQuantity, @GroupUnit, @ItemPartType 
			WHILE @@FETCH_STATUS = 0 AND @IsAchieved = 1
			BEGIN 
				IF @ItemType != 2 -- the item is not condition 
				BEGIN
					INSERT INTO #Items
					SELECT
						@SpecialOfferGUID,
						@groupGUID,
						bi.MaterialGUID,
						bi.Number,
						bi.Quantity,
						bi.Unit,
						bi.Price,
						1,
						1
					FROM 
						TempBillItems000 bi
						LEFT JOIN (
							SELECT soi.GUID, s.IsApplicableToCombine 
							FROM 
								vwSpecialOffers s 
								INNER JOIN  
								SOItems000 soi ON soi.SpecialOfferGUID = s.GUID) so ON so.GUID = bi.SOContractItemGUID
								LEFT JOIN vwMt ON bi.MaterialGUID = vwMt.mtGUID
					WHERE 
						bi.BillGuid = @BillGUID 
						AND 
						(((ISNULL(so.IsApplicableToCombine, 0) = 0) AND (bi.SOContractItemGUID = 0x0)) OR (ISNULL(so.IsApplicableToCombine, 0) = 1))
						AND
						bi.SOItemGUID = 0x0
						AND 
						(
							((@ItemType = 0) AND ((bi.MaterialGUID = @ItemGUID) OR (vwMt.mtParent = @ItemGUID)))
							OR 
							(
								(@ItemType = 1) AND 
								(
									((@IsIncludeGroups = 0) AND (
																  (bi.MaterialGUID IN (SELECT [GUID] FROM mt000 WHERE GroupGUID = @ItemGUID))
																	OR
																  (bi.MaterialGUID IN(SELECT [Matguid] FROM gri000 WHERE GroupGUID = @ItemGUID))
																)
									)
									OR 
									((@IsIncludeGroups = 1) AND (
																  (bi.MaterialGUID IN (SELECT [GUID] FROM mt000 WHERE GroupGUID IN (SELECT GUID FROM [dbo].[fnGetGroupsOfGroup](@ItemGUID))))
																  OR
																  (bi.MaterialGUID IN (SELECT Matguid FROM gri000 WHERE GroupGUID IN (SELECT GUID FROM [dbo].[fnGetGroupsOfGroup](@ItemGUID))))
																  
																)
									)
								)
							)
						)
				END ELSE BEGIN 
					SET @MaterialCursor = CURSOR FAST_FORWARD FOR 
					SELECT 
						bi.MaterialGUID,
						bi.Number,
						bi.Quantity,
						bi.Unit,
						bi.Price
					FROM 
						TempBillItems000 bi
						LEFT JOIN 
						(
							SELECT soi.GUID, s.IsApplicableToCombine 
							FROM 
								vwSpecialOffers s 
								INNER JOIN  
								SOItems000 soi ON soi.SpecialOfferGUID = s.GUID) so ON so.GUID = bi.SOContractItemGUID
					WHERE 
						bi.BillGuid = @BillGUID 
						AND 
						(((ISNULL(so.IsApplicableToCombine, 0) = 0) AND (bi.SOContractItemGUID = 0x0)) OR (ISNULL(so.IsApplicableToCombine, 0) = 1))
						AND
						bi.SOItemGUID = 0x0
					
					OPEN @MaterialCursor FETCH NEXT FROM @MaterialCursor INTO @MaterialGUID, @Number, @Quantity, @Unit, @Price
					WHILE @@FETCH_STATUS = 0
					BEGIN
						EXEC @IsFound = prcIsMatCondVerified @ItemGUID, @MaterialGUID
						IF @IsFound = 1
						BEGIN 
							INSERT INTO #Items
							SELECT
								@SpecialOfferGUID,
								@groupGUID,
								@MaterialGUID,
								@Number,
								@Quantity,
								@Unit,
								@Price,
								1,
								1
						END

						FETCH NEXT FROM @MaterialCursor INTO @MaterialGUID, @Number, @Quantity, @Unit, @Price
					END CLOSE @MaterialCursor DEALLOCATE @MaterialCursor
				END
				
				IF NOT EXISTS(SELECT * FROM #Items WHERE GroupGUID = @groupGUID)
				BEGIN
					IF (@ItemPartType = 0) OR ((@ItemPartType = 1) AND (@soOfferedItemsCondition = 1))
						SET @IsAchieved = 0
					ELSE
						INSERT INTO #Groups
						SELECT 
							@SpecialOfferGUID,
							@GroupGUID,
							@GroupQuantity, 
							@GroupUnit,
							@IsSpecified,
							@ItemType,
							0,
							0,
							0,
							@ItemPartType
						
				END ELSE BEGIN 
				INSERT INTO #Groups
				SELECT 
					@SpecialOfferGUID,
					@GroupGUID,
					@GroupQuantity, 
					@GroupUnit,
					@IsSpecified,
					@ItemType,
					0,
					0,
					0,
					@ItemPartType
					
				END 
				FETCH NEXT FROM @GroupCursor INTO @groupGUID, @ItemType, @ItemGUID, @IsSpecified, @IsIncludeGroups, @GroupQuantity, @GroupUnit, @ItemPartType
			END CLOSE @GroupCursor DEALLOCATE @GroupCursor
			
			DECLARE @Count INT 
			SET @Count = 0

			IF @IsAchieved = 1
			BEGIN 
				UPDATE #Items
				SET 
					ItemUnitFact = (CASE it.Unit WHEN 2 THEN (CASE WHEN mt.Unit2Fact = 0 THEN 1 ELSE mt.Unit2Fact END) WHEN 3 THEN (CASE WHEN mt.Unit3Fact = 0 THEN 1 ELSE mt.Unit3Fact END) ELSE 1 END),
					GroupUnitFact = 
						(CASE (CASE @soItemsCondition WHEN 0 THEN gr.Unit ELSE @soUnit END)
							WHEN 2 THEN (CASE WHEN mt.Unit2Fact = 0 THEN 1 ELSE mt.Unit2Fact END) 
							WHEN 3 THEN (CASE WHEN mt.Unit3Fact = 0 THEN 1 ELSE mt.Unit3Fact END) 
							WHEN 4 THEN 
								(CASE mt.DefUnit 
									WHEN 2 THEN (CASE WHEN mt.Unit2Fact = 0 THEN 1 ELSE mt.Unit2Fact END) 
									WHEN 3 THEN (CASE WHEN mt.Unit3Fact = 0 THEN 1 ELSE mt.Unit3Fact END) 
									ELSE 1
								END)
							ELSE 1 
						END)
				FROM 
					#Items it
					INNER JOIN #Groups gr on it.GroupGUID = gr.GroupGUID 
					INNER JOIN mt000 mt on mt.GUID = it.MaterialGUID
					
				EXEC prcSO_CheckBillMultiItems @SpecialOfferGUID, @soItemsCondition, @soOfferedItemsCondition, @soQuantity, @IsAchieved OUT, @Count OUT
			END
			
			IF @IsAchieved = 1
			BEGIN 			
				INSERT INTO [#ApplicableSO]
				SELECT 
					so.[GUID],
					so.Code,
					(CASE @lang WHEN 0 THEN so.Name ELSE (CASE so.LatinName WHEN '' THEN so.Name ELSE so.LatinName END) END),
					@Count,
					so.[Type],
					so.ItemsCondition,
					so.OfferedItemsCondition,
					so.Quantity,----
					so.Unit,
					it.SOGroup, --soGroup
					1, --soIsApplicable
					0, --soIsAchieved
					it.GroupGUID, --groupGUID
					(CASE soi.ItemType
						WHEN 0 THEN (SELECT Code + ' - ' + (CASE @lang WHEN 0 THEN [Name] ELSE (CASE LatinName WHEN '' THEN Name ELSE LatinName END) END) FROM mt000 WHERE [GUID] = soi.ItemGUID) 
						WHEN 1 THEN (SELECT Code + ' - ' + (CASE @lang WHEN 0 THEN [Name] ELSE (CASE LatinName WHEN '' THEN Name ELSE LatinName END) END) FROM gr000 WHERE [GUID] = soi.ItemGUID)
						WHEN 2 THEN (SELECT Name FROM Cond000 WHERE [GUID] = soi.ItemGUID)
						ELSE ''
					END), --groupDescription
					soi.IsSpecified,
					soi.Quantity,
					soi.Unit,
					(CASE soi.ItemType
						WHEN 0 THEN 
							(SELECT 
								CASE soi.Unit 
									WHEN 1 THEN Unity
									WHEN 2 THEN Unit2
									WHEN 3 THEN Unit3
									ELSE ''
								END
							 FROM
								mt000
							WHERE
								[GUID] = soi.ItemGUID)
						ELSE ''
					END),
					0, -- itemType
					soi.ItemType,
					0, -- Price Kind 
					0, -- price Type
					0, -- Price
					soi.DiscountType, -- Discount type
					CASE soi.DiscountType 
						WHEN 1 THEN soi.Discount * it.ApplyCount
						ELSE soi.Discount
					END, -- Discount
					0, -- IsApplicable
					soi.OfferedItemGUID,
					it.Number,
					it.Quantity,
					it.Unit,
					(SELECT 
						CASE it.Unit
							WHEN 1 THEN Unity
							WHEN 2 THEN Unit2
							WHEN 3 THEN Unit3
							ELSE ''
						END
					FROM
						mt000
					WHERE
						[GUID] = it.MaterialGUID),
					(CASE it.Unit WHEN 2 THEN (CASE WHEN mt.Unit2Fact = 0 THEN 1 ELSE mt.Unit2Fact END) WHEN 3 THEN (CASE WHEN mt.Unit3Fact = 0 THEN 1 ELSE mt.Unit3Fact END) ELSE 1 END),
					it.Price,
					0,
					0, --IsBouns
					0,
					it.MaterialGUID,				
					mt.Code + ' - ' + (CASE @lang WHEN 0 THEN mt.Name ELSE (CASE mt.LatinName WHEN '' THEN mt.Name ELSE mt.LatinName END) END),
					it.MustDivided,
					it.ReservedQuantity
				FROM 
					#BillItems it
					INNER JOIN vwSpecialOffers so ON so.GUID = it.SpecialOfferGUID
					INNER JOIN SOItems000  soi ON soi.GUID = it.GroupGUID 
					INNER JOIN mt000 mt ON mt.GUID = it.MaterialGUID
					
				INSERT INTO [#ApplicableSO]
				SELECT 
					so.[GUID],
					so.Code,
					(CASE @lang WHEN 0 THEN so.Name ELSE (CASE so.LatinName WHEN '' THEN so.Name ELSE so.LatinName END) END),
					@Count,
					so.[Type],
					so.ItemsCondition,
					so.OfferedItemsCondition,
					so.Quantity,
					so.Unit,
					it.SOGroup,
					1,
					0,
					
					it.GroupGUID,
					(CASE soi.ItemType 
						WHEN 0 THEN (SELECT Code + ' - ' + (CASE @lang WHEN 0 THEN [Name] ELSE (CASE LatinName WHEN '' THEN Name ELSE LatinName END) END) FROM mt000 WHERE [GUID] = soi.ItemGUID)
						WHEN 1 THEN (SELECT Code + ' - ' + (CASE @lang WHEN 0 THEN [Name] ELSE (CASE LatinName WHEN '' THEN Name ELSE LatinName END) END) FROM gr000 WHERE [GUID] = soi.ItemGUID)
						WHEN 2 THEN (SELECT Name FROM Cond000 WHERE [GUID] = soi.ItemGUID)
						ELSE ''
					END),
					0,
					soi.Quantity,
					soi.Unit,
					(CASE soi.ItemType
						WHEN 0 THEN 
							(SELECT 
								CASE soi.Unit 
									WHEN 1 THEN Unity
									WHEN 2 THEN Unit2
									WHEN 3 THEN Unit3
									ELSE ''
								END
							 FROM
								mt000
							WHERE
								[GUID] = soi.ItemGUID)
						ELSE ''
					END),
					1, -- offered item
					soi.ItemType,
					0,
					0,
					0,
					soi.DiscountType,
					CASE soi.DiscountType 
						WHEN 1 THEN soi.Discount * it.ApplyCount
						ELSE soi.Discount
					END,
					0,
					0x0, -- OfferedItemGUID
					it.Number,
					it.Quantity,
					it.Unit,
					(SELECT 
						CASE it.Unit
							WHEN 1 THEN Unity
							WHEN 2 THEN Unit2
							WHEN 3 THEN Unit3
							ELSE ''
						END
					FROM
						mt000
					WHERE
						[GUID] = it.MaterialGUID),
					(CASE it.Unit WHEN 2 THEN (CASE WHEN mt.Unit2Fact = 0 THEN 1 ELSE mt.Unit2Fact END) WHEN 3 THEN (CASE WHEN mt.Unit3Fact = 0 THEN 1 ELSE mt.Unit3Fact END) ELSE 1 END),
					CASE soi.PriceKind
						WHEN 0 THEN it.Price -- None
						WHEN 1 THEN 0 -- Zero
						WHEN 2 THEN soi.Price -- Specified
						WHEN 3 THEN [dbo].[fnExtended_mt_Price_fixed](soi.PriceType, 0, it.Unit - 1, @BillCurrencyGUID, @BillDate, [mt].[GUID])
					END,
					0,
					soi.IsBonus,
					0,
					it.MaterialGUID,
					mt.Code + ' - ' + (CASE @lang WHEN 0 THEN mt.Name ELSE (CASE mt.LatinName WHEN '' THEN mt.Name ELSE mt.LatinName END) END),
					it.MustDivided,
					it.ReservedQuantity
				FROM 
					#BillItems it
					INNER JOIN vwSpecialOffers so ON so.GUID = it.SpecialOfferGUID
					INNER JOIN SOOfferedItems000 soi ON soi.GUID = it.GroupGUID 
					INNER JOIN mt000 mt ON mt.GUID = it.MaterialGUID
			END 
			FETCH NEXT FROM @ApplicableSOCursor INTO @SpecialOfferGUID, @soItemsCondition, @soOfferedItemsCondition, @soIsApplicableToCombine, @soQuantity, @soUnit
		END CLOSE @ApplicableSOCursor DEALLOCATE @ApplicableSOCursor
	END 
	
	IF EXISTS(SELECT * FROM TempBillItems000 WHERE BillGUID = @BillGUID AND SOItemGUID != 0x0)
	BEGIN 
		INSERT INTO [#ApplicableSO]
		SELECT 
			so.[GUID],
			so.Code,
			(CASE @lang WHEN 0 THEN so.Name ELSE (CASE so.LatinName WHEN '' THEN so.Name ELSE so.LatinName END) END),
			0,
			so.[Type],
			so.ItemsCondition,
			so.OfferedItemsCondition,
			so.Quantity,
			so.Unit,
			it.SOGroup,
			1,
			1,
			
			soi.GroupGUID,
			'',
			0,
			0,
			0,
			'',
			soi.PartType,
			0,
			0, --pricKind
			soi.PartType, --priceType 
			it.Price, --Price
			soi.DiscountType, --DiscountType
			soi.Discount, --Discount
			0, --IsApplicable
			soi.OfferedItemGUID, --OfferedITemGuid			
			it.Number,
			it.Quantity,
			it.Unit,
			'',
			(CASE it.Unit WHEN 2 THEN (CASE WHEN mt.Unit2Fact = 0 THEN 1 ELSE mt.Unit2Fact END) WHEN 3 THEN (CASE WHEN mt.Unit3Fact = 0 THEN 1 ELSE mt.Unit3Fact END) ELSE 1 END),
			it.Price,
			soi.Discount, --Discount
			soi.IsBonus, --IsBouns
			it.BounsQuantity,
			it.MaterialGUID, --MaterialGuid
			'', --ItemsDescription
			0, 
			0
		FROM 
			TempBillItems000 it
			INNER JOIN (
			SELECT GUID [GroupGUID], 1 AS PartType, Quantity, Unit, SpecialOfferGUID, Discount, DiscountType, PriceKind, PriceType, Price, IsBonus, 0x0 AS OfferedItemGUID FROM SOOfferedItems000 UNION ALL 
			SELECT GUID [GroupGUID], 0 AS PartType, Quantity, Unit, SpecialOfferGUID, Discount, DiscountType, PriceKind, PriceType, Price, 0 AS IsBonus, OfferedItemGUID FROM SOItems000) soi ON soi.[GroupGUID] = it.SOItemGUID
			INNER JOIN mt000 mt ON mt.GUID = it.MaterialGUID
			INNER JOIN vwSpecialOffers so ON so.GUID = soi.SpecialOfferGUID
		WHERE
			it.BillGUID = @BillGUID 
			AND it.SOItemGUID != 0x0
	END
	
	IF EXISTS(SELECT * FROM #ApplicableSO)
	BEGIN
		UPDATE apSO
		SET itemDiscount = 
			CASE groupDiscountType
				WHEN 0 THEN groupDiscount --ratio
				WHEN 1 THEN 
					(groupDiscount / 
						CASE (SELECT SUM(itemPrice * (CASE (CASE itemMustDivided WHEN 0 THEN itemQuantity ELSE itemReservedQuantity END) WHEN 0 THEN 1 ELSE (CASE itemMustDivided WHEN 0 THEN itemQuantity ELSE itemReservedQuantity END) END)) [Total] FROM #ApplicableSO WHERE groupGUID = apSO.groupGUID GROUP BY groupGUID) 
							WHEN 0 THEN 1 
							ELSE (SELECT SUM(itemPrice * (CASE (CASE itemMustDivided WHEN 0 THEN itemQuantity ELSE itemReservedQuantity END) WHEN 0 THEN 1 ELSE (CASE itemMustDivided WHEN 0 THEN itemQuantity ELSE itemReservedQuantity END) END)) [Total] FROM #ApplicableSO WHERE groupGUID = apSO.groupGUID GROUP BY groupGUID) 
						END) * 100
				WHEN 2 THEN 
					CASE ISNULL((itemPrice * (CASE soIsAchieved WHEN 0 THEN itemReservedQuantity ELSE (CASE (CASE itemMustDivided WHEN 0 THEN itemQuantity ELSE itemReservedQuantity END) WHEN 0 THEN 1 ELSE (CASE itemMustDivided WHEN 0 THEN itemQuantity ELSE itemReservedQuantity END) END) END)), 0) 
						WHEN 0 THEN 0 
						ELSE 
							(
								((groupDiscount / 100) * ISNULL((SELECT itemPrice * (CASE (CASE itemMustDivided WHEN 0 THEN itemQuantity ELSE itemReservedQuantity END) WHEN 0 THEN 1 ELSE (CASE itemMustDivided WHEN 0 THEN itemQuantity ELSE itemReservedQuantity END) END) FROM #ApplicableSO WHERE groupGUID = apSO.groupOfferedItemGUID AND soGroup = apSO.soGroup AND soIsAchieved = 0), 0))
								* 
								(itemPrice * (CASE (CASE itemMustDivided WHEN 0 THEN itemQuantity ELSE itemReservedQuantity END) WHEN 0 THEN 1 ELSE (CASE itemMustDivided WHEN 0 THEN itemQuantity ELSE itemReservedQuantity END) END))
								/
								(SELECT SUM((CASE itemPrice WHEN 0 THEN 1 ELSE itemPrice END) * (CASE (CASE itemMustDivided WHEN 0 THEN itemQuantity ELSE itemReservedQuantity END) WHEN 0 THEN 1 ELSE (CASE itemMustDivided WHEN 0 THEN itemQuantity ELSE itemReservedQuantity END) END)) FROM #ApplicableSO so WHERE so.groupGUID = apSO.groupGUID GROUP BY so.groupGUID)
							) * 100 / ((CASE itemPrice WHEN 0 THEN 1 ELSE itemPrice END) * (CASE (CASE itemMustDivided WHEN 0 THEN itemQuantity ELSE itemReservedQuantity END) WHEN 0 THEN 1 ELSE (CASE itemMustDivided WHEN 0 THEN itemQuantity ELSE itemReservedQuantity END) END))
					END
				WHEN 3 THEN 
					CASE ISNULL((itemPrice * (CASE soIsAchieved WHEN 0 THEN itemReservedQuantity ELSE (CASE itemQuantity WHEN 0 THEN 1 ELSE (CASE itemMustDivided WHEN 0 THEN itemQuantity ELSE itemReservedQuantity END) END) END)), 0) 
						WHEN 0 THEN 0 
						ELSE
							(
								((groupDiscount / 100) * ISNULL((SELECT SUM(itemPrice * (CASE itemMustDivided WHEN 0 THEN itemQuantity ELSE itemReservedQuantity END)) FROM #ApplicableSO WHERE soGUID = apSO.soGUID AND groupType = 1 AND soGroup = apSO.soGroup AND soIsAchieved = 0), 0))
								* 
								(itemPrice * (CASE (CASE itemMustDivided WHEN 0 THEN itemQuantity ELSE itemReservedQuantity END) WHEN 0 THEN 1 ELSE (CASE itemMustDivided WHEN 0 THEN itemQuantity ELSE itemReservedQuantity END) END))
								/
								(SELECT SUM((CASE itemPrice WHEN 0 THEN 1 ELSE itemPrice END) * (CASE (CASE itemMustDivided WHEN 0 THEN itemQuantity ELSE itemReservedQuantity END) WHEN 0 THEN 1 ELSE (CASE itemMustDivided WHEN 0 THEN itemQuantity ELSE itemReservedQuantity END) END)) FROM #ApplicableSO so WHERE so.groupGUID = apSO.groupGUID GROUP BY so.groupGUID)
							) * 100 / ((CASE itemPrice WHEN 0 THEN 1 ELSE itemPrice END) * (CASE (CASE itemMustDivided WHEN 0 THEN itemQuantity ELSE itemReservedQuantity END) WHEN 0 THEN 1 ELSE (CASE itemMustDivided WHEN 0 THEN itemQuantity ELSE itemReservedQuantity END) END))
							
						END
			END 
		FROM 
			#ApplicableSO apSO
		WHERE 
			soIsAchieved = 0
	END

	SELECT 
		* 
	FROM 
		[#ApplicableSO]
	ORDER BY
		soCode,
		soGUID,
		soIsAchieved,
		groupGUID
################################################################################
#END
