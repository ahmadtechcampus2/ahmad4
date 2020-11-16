###############################################################################
CREATE PROCEDURE prcSO_CheckBillMultiItems
	@soGUID UNIQUEIDENTIFIER,
	@ItemsCondition TINYINT,		-- 0 By Item, 1 General
	@OfferedItemsCondition TINYINT, -- 0 OR, 1 AND
	@SpecialOfferQuantity FLOAT, 
	@IsAchieved BIT OUT,
	@AppliedCount INT OUT
AS
	--ÊÞæã ÇáÅÌÑÇÆíÉ ÈÝÍÕ ÇÍÊãÇáíÉ ÊØÈíÞ ÇáÚÑÖ ÇáÎÇÕ æÚÏÏ ãÑÇÊ ÊØÈíÞå
	--prcGetSpecialOffers åÐå ÇáÅÌÑÇÆíÉ áÇ ÊÚãá ÈÔßá ãÓÊÞá æÅäãÇ ÊÚãá ÈÔßá ãÓÇÚÏ áÅÌÑÇÆíÉ ÊÞæã ÈÇÓÊÏÚÇÆåÇ æåí 
	SET NOCOUNT ON 

	DECLARE
		@c_offered_groups CURSOR,
		@c_offered_group_items CURSOR,
		@c_so_groups CURSOR,		
		@c_so_group_items CURSOR,	
		@offered_group_guid UNIQUEIDENTIFIER,
		@offered_group_quantity FLOAT,		
		@og_item_number INT,
		@og_item_quantity FLOAT,
		@og_item_unit INT,
		@og_item_price FLOAT,
		@og_item_material_guid UNIQUEIDENTIFIER,
		@og_item_item_unit_fact FLOAT,
		@og_item_group_unit_fact FLOAT,
		@so_group_guid UNIQUEIDENTIFIER,		
		@so_group_quantity FLOAT,
		@so_group_parttype TINYINT,
		@so_group_isspecified BIT,
		@so_group INT,
		@item_quantity FLOAT,
		@item_unit INT,
		@item_number INT,
		@item_price FLOAT,
		@item_order INT,
		@item_material_guid UNIQUEIDENTIFIER,
		@item_item_unit_fact FLOAT,
		@item_group_unit_fact FLOAT,
		@continue BIT,
		@IsGroupAchieved BIT,
		@IsSumQuantityAchieved BIT,
		@item_isdivided BIT

	SET @so_group = 0
	
	SET @c_offered_groups = CURSOR FAST_FORWARD FOR
		SELECT 
			GroupGUID,
			RequiredQuantity 
		FROM 
			[#Groups]
		WHERE 
			(ItemPartType = 1)
			AND 
			((@OfferedItemsCondition = 1 /*OR*/) OR ((@OfferedItemsCondition = 0) AND (GroupGUID = (SELECT TOP 1 [GroupGUID] FROM [#Groups] WHERE ItemPartType = 1))))

	OPEN @c_offered_groups FETCH NEXT FROM @c_offered_groups INTO @offered_group_guid, @offered_group_quantity
	WHILE @@FETCH_STATUS = 0
	BEGIN
		SET @c_offered_group_items = CURSOR FAST_FORWARD FOR
			SELECT
				MaterialGUID,
				Number,
				(CASE GroupUnitFact WHEN 0 THEN 0 ELSE CAST((Quantity * ItemUnitFact) AS FLOAT) / GroupUnitFact END) AS [ItemQuantity],
				Unit,
				Price,
				ItemUnitFact,
				GroupUnitFact
			FROM
				#Items
			WHERE
				GroupGUID = @offered_group_guid
			ORDER BY
				[ItemQuantity] DESC 

		OPEN @c_offered_group_items FETCH NEXT FROM @c_offered_group_items INTO @og_item_material_guid, @og_item_number, @og_item_quantity, @og_item_unit, @og_item_price, @og_item_item_unit_fact, @og_item_group_unit_fact
		
		WHILE @@FETCH_STATUS = 0 AND @IsAchieved = 1
		BEGIN
			DECLARE
				@i_count INT, 
				@f_count FLOAT, 
				@sum FLOAT
				
			SET @IsGroupAchieved = 1
			SET @IsSumQuantityAchieved = 0
			SET @sum = 0
			
			SELECT @i_count = @og_item_quantity / @offered_group_quantity
			SELECT @f_count = @og_item_quantity / @offered_group_quantity
			
			IF @i_count > 0 AND (@i_count = @f_count)
			BEGIN 
				SET @c_so_groups = CURSOR FAST_FORWARD FOR 
					SELECT 
						GroupGUID, 
						RequiredQuantity,
						IsSpecified,
						ItemPartType -- GroupType	
					FROM 
						#Groups 
					WHERE 
						GroupGUID != @offered_group_guid
						AND
						(((@OfferedItemsCondition = 1) AND (ItemPartType = 0)) OR (@OfferedItemsCondition = 0)) 
					ORDER BY 
						ItemType,
						ItemPartType
						-- GroupType, /*items first*/
						-- ItemType
					
				OPEN @c_so_groups FETCH NEXT FROM @c_so_groups INTO @so_group_guid, @so_group_quantity, @so_group_isspecified, @so_group_parttype
				WHILE @@FETCH_STATUS = 0 AND (@IsGroupAchieved = 1 OR @IsSumQuantityAchieved = 1)
				BEGIN 
					SET @continue = 1
					IF @ItemsCondition = 0
						SET @sum = 0

					SET @c_so_group_items = CURSOR FAST_FORWARD FOR
						SELECT
							0 AS [Ord],
							it.MaterialGUID,
							it.Number,
							(((MAX(it.Quantity) - SUM(CASE ISNULL(MustDivided, -1) WHEN 1 THEN ISNULL(ReservedQuantity, 0) ELSE 0 END)) * MAX(it.ItemUnitFact)) / MAX(it.GroupUnitFact)) AS [ItemQuantity],
							/*						
							SUM((CASE it.GroupUnitFact 
								WHEN 0 THEN CAST(((it.Quantity - (CASE ISNULL(MustDivided, -1) WHEN 1 THEN ISNULL(ReservedQuantity, 0) ELSE 0 END) * it.ItemUnitFact)) AS FLOAT) 
								ELSE CAST(((it.Quantity - (CASE ISNULL(MustDivided, -1) WHEN 1 THEN ISNULL(ReservedQuantity, 0) ELSE 0 END) * it.ItemUnitFact)) AS FLOAT) / it.GroupUnitFact 
							END)) AS [ItemQuantity],
							*/
							MAX(it.Unit),
							MAX(it.Price),
							MAX(it.ItemUnitFact),
							MAX(it.GroupUnitFact),
							(CASE ISNULL(bi.MustDivided, 0) WHEN 0 THEN 0 ELSE 1 END) AS IsDivided 
						FROM 
							#Items it
							LEFT JOIN #BillItems bi ON it.Number = bi.Number
						WHERE 
							it.GroupGUID = @so_group_guid
							AND 
							it.Number != @og_item_number
							AND 
							(bi.GroupGUID IS NULL OR ((ISNULL(bi.MustDivided, 0) = 1) AND ISNULL(bi.ReservedQuantity, 0) > 0))
							/*
							AND 
							(CASE it.GroupUnitFact 
								WHEN 0 THEN CAST((it.Quantity - (CASE ISNULL(MustDivided, -1) WHEN 1 THEN ISNULL(ReservedQuantity, 0) ELSE 0 END) * it.ItemUnitFact) AS FLOAT) 
								ELSE CAST((it.Quantity - (CASE ISNULL(MustDivided, -1) WHEN 1 THEN ISNULL(ReservedQuantity, 0) ELSE 0 END) * it.ItemUnitFact) AS FLOAT) / it.GroupUnitFact 
							END) */
						GROUP BY
							it.Number,
							it.MaterialGUID,
							ISNULL(bi.MustDivided, 0)
						HAVING 
							(((MAX(it.Quantity) - SUM(CASE ISNULL(MustDivided, -1) WHEN 1 THEN ISNULL(ReservedQuantity, 0) ELSE 0 END)) * MAX(it.ItemUnitFact)) / MAX(it.GroupUnitFact)) < @i_count * @so_group_quantity
						UNION ALL 	
						SELECT
							1 AS [Ord],
							it.MaterialGUID,
							it.Number,
							/*
							SUM((CASE it.GroupUnitFact 
									WHEN 0 THEN CAST((it.Quantity - (CASE ISNULL(MustDivided, -1) WHEN 1 THEN ISNULL(ReservedQuantity, 0) ELSE 0 END) * it.ItemUnitFact) AS FLOAT) 
									ELSE CAST((it.Quantity - (CASE ISNULL(MustDivided, -1) WHEN 1 THEN ISNULL(ReservedQuantity, 0) ELSE 0 END) * it.ItemUnitFact) AS FLOAT) / it.GroupUnitFact 
							END) * -1) AS [ItemQuantity],
							*/
							(((MAX(it.Quantity) - SUM(CASE ISNULL(MustDivided, -1) WHEN 1 THEN ISNULL(ReservedQuantity, 0) ELSE 0 END)) * MAX(it.ItemUnitFact)) / MAX(it.GroupUnitFact)) * -1 AS [ItemQuantity],
							MAX(it.Unit),
							MAX(it.Price),
							MAX(it.ItemUnitFact),
							MAX(it.GroupUnitFact),
							(CASE ISNULL(bi.MustDivided, 0) WHEN 0 THEN 0 ELSE 1 END) AS IsDivided 
						FROM 
							#Items it
							LEFT JOIN #BillItems bi ON it.Number = bi.Number
						WHERE 
							it.GroupGUID = @so_group_guid
							AND 
							it.Number != @og_item_number
							AND 
							(bi.GroupGUID IS NULL OR ((ISNULL(bi.MustDivided, 0) = 1) AND ISNULL(bi.ReservedQuantity, 0) > 0))
							/*
							AND 
							(CASE it.GroupUnitFact 
								WHEN 0 THEN CAST((it.Quantity - (CASE ISNULL(MustDivided, -1) WHEN 1 THEN ISNULL(ReservedQuantity, 0) ELSE 0 END) * it.ItemUnitFact) AS FLOAT) 
								ELSE CAST((it.Quantity - (CASE ISNULL(MustDivided, -1) WHEN 1 THEN ISNULL(ReservedQuantity, 0) ELSE 0 END) * it.ItemUnitFact) AS FLOAT) / it.GroupUnitFact 
							END) >= @i_count * @so_group_quantity 
							*/
						GROUP BY
							it.Number,
							it.MaterialGUID,
							ISNULL(bi.MustDivided, 0)
						HAVING 
							(((MAX(it.Quantity) - SUM(CASE ISNULL(MustDivided, -1) WHEN 1 THEN ISNULL(ReservedQuantity, 0) ELSE 0 END)) * MAX(it.ItemUnitFact)) / MAX(it.GroupUnitFact)) >= @i_count * @so_group_quantity 
						ORDER BY 
							[Ord] DESC, 
							[ItemQuantity] DESC
							
					OPEN @c_so_group_items FETCH NEXT FROM @c_so_group_items INTO @item_order, @item_material_guid, @item_number, @item_quantity, @item_unit, @item_price, @item_item_unit_fact, @item_group_unit_fact, @item_isdivided
					WHILE @@FETCH_STATUS = 0 AND @continue = 1
					BEGIN
						SET @item_quantity = (CASE WHEN @item_quantity < 0 THEN -1 * @item_quantity ELSE @item_quantity END) 
						
						IF (((@so_group_parttype = 0) AND (@sum = 0) AND (@item_quantity >= (@i_count * (CASE @ItemsCondition WHEN 0 THEN @so_group_quantity ELSE @SpecialOfferQuantity END))))
							OR 
							((@so_group_parttype = 1) AND (@item_quantity = (@i_count * @so_group_quantity))))
						BEGIN						
							INSERT INTO #BillItems SELECT @soGUID, @so_group_guid, @item_material_guid, @item_number, @item_quantity, @item_unit, @item_price, @item_item_unit_fact, @item_group_unit_fact, 1, 0, 
								CASE @item_isdivided WHEN 1 THEN 1 ELSE (CASE WHEN (@item_quantity > (@i_count * (CASE @ItemsCondition WHEN 0 THEN @so_group_quantity ELSE @SpecialOfferQuantity END))) THEN 1 ELSE 0 END) END,
								CASE @item_isdivided WHEN 1 THEN (@i_count * (CASE @ItemsCondition WHEN 0 THEN @so_group_quantity ELSE @SpecialOfferQuantity END)) ELSE 
									(CASE WHEN (@item_quantity > (@i_count * (CASE @ItemsCondition WHEN 0 THEN @so_group_quantity ELSE @SpecialOfferQuantity END))) 
										THEN (@i_count * (CASE @ItemsCondition WHEN 0 THEN @so_group_quantity ELSE @SpecialOfferQuantity END)) 
										ELSE @item_quantity END) END, 0, @i_count
								
								
							SET @continue = 0
						END ELSE BEGIN 
							IF (@so_group_parttype = 0) AND (@so_group_isspecified = 0)
							BEGIN
							
								SET @sum = @sum + @item_quantity
								INSERT INTO #BillItems SELECT @soGUID, @so_group_guid, @item_material_guid, @item_number, @item_quantity, @item_unit, @item_price, @item_item_unit_fact, @item_group_unit_fact, 0, 0,
									CASE @item_isdivided WHEN 1 THEN 1 ELSE (CASE WHEN @sum > (@i_count * (CASE @ItemsCondition WHEN 0 THEN @so_group_quantity ELSE @SpecialOfferQuantity END)) THEN 1 ELSE 0 END) END,
									CASE WHEN @sum >= (@i_count * (CASE @ItemsCondition WHEN 0 THEN @so_group_quantity ELSE @SpecialOfferQuantity END)) THEN (@i_count * (CASE @ItemsCondition WHEN 0 THEN @so_group_quantity ELSE @SpecialOfferQuantity END)) - (@sum - @item_quantity) ELSE @item_quantity END,
									0, @i_count

								IF @sum >= (@i_count * (CASE @ItemsCondition WHEN 0 THEN @so_group_quantity ELSE @SpecialOfferQuantity END))
								BEGIN
									UPDATE #BillItems SET GroupFlag = 1 WHERE GroupGUID = @so_group_guid 
									SET @continue = 0
								END 
							END
						END 	
						FETCH NEXT FROM @c_so_group_items INTO @item_order, @item_material_guid, @item_number, @item_quantity, @item_unit, @item_price, @item_item_unit_fact, @item_group_unit_fact, @item_isdivided
					END
					
					IF (@continue = 1) AND (@ItemsCondition = 0)
						SET @IsGroupAchieved = 0

					IF (@continue = 0) AND (@ItemsCondition = 1)  
						SET @IsSumQuantityAchieved = 1

				FETCH NEXT FROM @c_so_groups INTO @so_group_guid, @so_group_quantity, @so_group_isspecified, @so_group_parttype
				END CLOSE @c_so_groups DEALLOCATE @c_so_groups
			
				IF (@IsGroupAchieved = 0 AND @ItemsCondition = 0) OR (@IsSumQuantityAchieved = 0 AND  @ItemsCondition = 1)
				BEGIN 
					DELETE #BillItems WHERE SpecialOfferFlag = 0
				END ELSE BEGIN 
					UPDATE #BillItems SET SpecialOfferFlag = 1, SOGroup = @so_group WHERE SpecialOfferFlag = 0
					INSERT INTO #BillItems SELECT @soGUID, @offered_group_guid, @og_item_material_guid, @og_item_number, @og_item_quantity, @og_item_unit, @og_item_price, @og_item_item_unit_fact, @og_item_group_unit_fact, 1, 1, 0, 0, @so_group, @i_count
					SET @so_group = @so_group + 1
					
					SET @AppliedCount = @AppliedCount + @i_count
				END 
			END
			FETCH NEXT FROM @c_offered_group_items INTO @og_item_material_guid, @og_item_number, @og_item_quantity, @og_item_unit, @og_item_price, @og_item_item_unit_fact, @og_item_group_unit_fact
		END CLOSE @c_offered_group_items DEALLOCATE @c_offered_group_items

		FETCH NEXT FROM @c_offered_groups INTO @offered_group_guid, @offered_group_quantity		
	END CLOSE @c_offered_groups DEALLOCATE @c_offered_groups

	IF NOT EXISTS (SELECT * FROM #BillItems)
		SET @IsAchieved = 0
################################################################################
#END
