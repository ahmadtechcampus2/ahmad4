#######################################################################################
CREATE PROCEDURE prcSO_CheckBillBonusSales
	@Qty		[FLOAT],
	@buDate		[DATETIME],
	@itemGuid	[UNIQUEIDENTIFIER],
	@Unit		[INT],
	@btGuid		[UNIQUEIDENTIFIER],
	@cuGuid		[UNIQUEIDENTIFIER] = 0x0,
	@coGuid		[UNIQUEIDENTIFIER] = 0x0
AS  
	SET NOCOUNT ON  
	
	IF NOT EXISTS(SELECT TOP 1 [GUID] FROM [SpecialOffers000])
		BEGIN
			RETURN
		END
	
	DECLARE 
		@soItemTypeMaterial INT,
		@soItemTypeGroup INT,
		@soItemTypeMaterialCondtion INT
						
	SET @soItemTypeMaterial = 0
	SET @soItemTypeGroup = 1
	SET @soItemTypeMaterialCondtion = 2
	
	DECLARE 
		@ItemDefUnit INT,
		@ItemDefUnitName NVARCHAR(500)

	SELECT 
		@ItemDefUnit = mtDefUnit,
		@ItemDefUnitName = mtDefUnitName		
	FROM 
		vwMt 
	WHERE mtGUID = @itemGuid

	CREATE TABLE [#Result] (
		[Guid] UNIQUEIDENTIFIER,  
		[Number] FLOAT,  
		[Type] INT,  
		[StartDate] DATETIME,   
		[EndDate] DATETIME,   
		[Name] NVARCHAR(250) COLLATE ARABIC_CI_AI,
		[CanOfferedSelected] BIT,
		[SOIGUID] UNIQUEIDENTIFIER,
		[ItemGUID] UNIQUEIDENTIFIER,   
		[ItemQty] FLOAT,   
		[ItemUnit] INT,   
		[bIncludeGroups] BIT,  
		[ItemPriceKind] INT,   
		[ItemPriceType] INT,  
		[ItemDiscType] INT,
		[ItemDiscount] FLOAT,
		[ItemPrice] FLOAT,
		
		[CustAccGUID] UNIQUEIDENTIFIER,  
		[OfferAccGUID] UNIQUEIDENTIFIER,  
		[IOfferAccGUID] UNIQUEIDENTIFIER,  
		[bAllBt] INT,
		
		[SOOfferedGUID] UNIQUEIDENTIFIER,  
		[ItemOrd] INT,  
		[MatPtr2] UNIQUEIDENTIFIER,  
		[Qty2] FLOAT,  
		[UnityName] NVARCHAR(250) COLLATE ARABIC_CI_AI, 
		[Unity2] FLOAT,   
		[OItemPrice] FLOAT,   
		[OItemPriceKind] INT,   
		[CurPtr] UNIQUEIDENTIFIER,  
		[CurVal] FLOAT,   
		[OItemPriceType] INT,  
		[OItemIsBonus] BIT)
		
	CREATE TABLE [#Accounts]( [GUID] [UNIQUEIDENTIFIER])
	
	DECLARE @acGUID [UNIQUEIDENTIFIER]
	
	SELECT @acGUID = [cuAccount] FROM [vwCu] WHERE [cuGuid] = @cuGuid  
	
	IF ISNULL(@cuGuid, 0x0) != 0x0
	BEGIN  
		INSERT INTO [#Accounts] SELECT @acGUID
		INSERT INTO [#Accounts] SELECT [GUID] FROM [dbo].[fnGetAccountParents]( @acGUID)
		INSERT INTO [#Accounts] SELECT [ParentGUID] FROM [ci000] WHERE [SonGuid] = @acGUID
	END
	
	CREATE TABLE [#CostTbl]([CostGuid] [UNIQUEIDENTIFIER])
	
	IF ISNULL(@coGuid, 0x0) != 0x0
	BEGIN
		INSERT INTO [#CostTbl] SELECT @coGuid
		INSERT INTO [#CostTbl] SELECT [GUID] FROM [dbo].[fnGetCostParents]( @coGuid)
	END
	
	DECLARE @gGroup [UNIQUEIDENTIFIER]
	
	SELECT @gGroup = [mtGroup] FROM [vwMt] WHERE [mtGUID] = @itemGuid  
	 
	INSERT INTO [#Result]  
	SELECT    
		[soGuid],   
		[soNumber],   
		[soType],   
		[soStartDate],    
		[soEndDate],    
		[soName],    
		[soCanOfferedSelected],
		[SOIGUID], 
		[SOItemGUID],    
		[SOItemQty],    
		[SOItemUnit], 
		[sOIsIncludeGroups],   
		[SOItemPriceKind],   
		[soItemPriceType],   
		[SOItemDiscType], 
		[sOItemDiscount],  
		[SOItemPrice],
		[soCustAccGUID],   
		[sOItemsAccount],   
		[sOOfferedItemsAccount],  
		[soAllBillTypes],  
		 
		[SOOfferedGUID],  
		[SOOfferedNumber],  
		(CASE [soType]    
			WHEN 1 THEN [SOOfferedItemGUID]    
			ELSE (CASE ISNULL( [SOOfferedItemGUID], 0x0) WHEN 0x0 THEN @itemGuid ELSE [SOOfferedItemGUID] END)   
		END),   
		[SOOfferedQty],  
		CASE ISNULL( [SOOfferedItemGUID], 0x0) 
			WHEN 0x0 THEN ISNULL(@ItemDefUnitName, '')
		ELSE 
			ISNULL(
			(CASE [SOOfferedUnity]
				-- WHEN 1 THEN om.Unity
				WHEN 2 THEN om.Unit2
				WHEN 3 THEN om.Unit3
				ELSE om.Unity
			 END), '')
		END,  
		(CASE [soType]    
			WHEN 1 THEN [SOOfferedUnity]    
			ELSE (CASE ISNULL( [SOOfferedItemGUID], 0x0) WHEN 0x0 THEN ISNULL(@ItemDefUnit, 1) ELSE [SOOfferedUnity] END)   
		END),   
		[SOOfferedPrice],    
		[SOOfferedPriceKind],    
		[SOOfferedCurrencyPtr],    
		CASE [SOOfferedCurrencyVal]
			WHEN 0 THEN 1
			ELSE [SOOfferedCurrencyVal]
		END,
		[SOOfferedPriceType],  
 		[SOOfferedIsBonus]  
	FROM
		[vwSO_Items_OfferedItems] AS SO
		LEFT JOIN vwMt AS MT ON SO.SOItemGUID = mt.mtGUID OR (ISNULL(mt.mtParent,0x0) <> 0x0 AND SO.SOItemGUID = mt.mtParent)
		LEFT JOIN mt000 AS om ON SO.SOOfferedItemGUID = om.GUID
		LEFT JOIN gr000 AS GR ON GR.GUID = SO.SOItemGUID AND GR.Kind = 1
	WHERE 
		(soType = 0 /*SO_OFFERS*/ OR soType = 1 /*SO_SALES*/ )  
		AND
		(  
			([soCustCondGUID] = 0x0) AND ([SOItemGUID] = 0x0 OR [SOITemType] <> 2)
		)  
		AND   
		(
			ISNULL(@itemGuid, 0x0) = 0x0
			OR   
			(mt.mtGUID = @itemGuid AND [SOITemType] = 0)   
			OR
			(  
				
				([SOItemGUID] != 0x0 AND [SOITemType] = 1)  
				AND 
				(
					(
						GR.GUID IS NOT NULL
						AND 
						EXISTS(SELECT * FROM dbo.fnGetMatOfGroupList([SOItemGUID]) WHERE GUID = @itemGuid)
					)
					OR
					[SOItemGUID] =    
					(CASE [SOIsIncludeGroups]    
						WHEN 0 THEN (@gGroup)   
						ELSE (SELECT CASE WHEN  @gGroup = [SOItemGUID] THEN @gGroup ELSE (SELECT [GUID] FROM [dbo].[fnGetGroupParents](@gGroup) WHERE [GUID] = SOItemGUID) END)  
					END)  
				) 
			)  
		)   
		AND
		[soActive] = 1
		AND
		( 
			(@buDate = '1/1/1980') OR (@buDate BETWEEN [dbo].[fnGetDateFromDT]([soStartDate]) AND [dbo].[fnGetDateFromDT]([soEndDate]))
		)   
		AND
		( 
			(@Qty = -1)
			OR
			(@Qty * (SELECT CASE @Unit 
							WHEN 2 THEN (CASE WHEN [mtUnit2Fact] = 0 THEN 1 ELSE [mtUnit2Fact] END)
							WHEN 3 THEN (CASE WHEN [mtUnit3Fact] = 0 THEN 1 ELSE [mtUnit3Fact] END)
							ELSE 1 
						END 
					FROM [vwMt] WHERE [mtGUID] = @itemGuid)
					/    
					(SELECT CASE [soItemUnit]
								WHEN 2 THEN (CASE WHEN [mtUnit2Fact] = 0 THEN 1 ELSE [mtUnit2Fact] END)
								WHEN 3 THEN (CASE WHEN [mtUnit3Fact] = 0 THEN 1 ELSE [mtUnit3Fact] END)
								WHEN 4 THEN (CASE WHEN [mtDefUnitFact] = 0 THEN 1 ELSE [mtDefUnitFact] END)
								ELSE 1 
							END 
						FROM [vwMt] WHERE [mtGUID] = @itemGuid) >= [SOItemQty])
		)
		AND([soAllBillTypes] = 1 OR (@btGuid <> 0x0 AND EXISTS(SELECT * FROM SOBillTypes000 WHERE BillTypeGUID = @btGuid AND SpecialOfferGUID = [soGUID])))
		AND([soCustAccGUID] = 0x0 OR [soCustAccGUID] IN( SELECT [GUID] FROM [#Accounts]))   
		AND([soCostGUID] = 0x0 OR [soCostGUID] IN( SELECT [CostGuid] FROM [#CostTbl]))  

	IF NOT EXISTS( SELECT * FROM [#Result])  
	BEGIN   
		DECLARE    
			@C CURSOR,   
			@soGUID UNIQUEIDENTIFIER,   
			@soItemGUID UNIQUEIDENTIFIER,   
			@soItemType INT, 
			@soIncludeGroups BIT,   
			@soAccountGUID UNIQUEIDENTIFIER,   
			@soCustCond UNIQUEIDENTIFIER,
			@found BIT,
			@g UNIQUEIDENTIFIER
			
		SET @C = CURSOR FAST_FORWARD FOR
			SELECT 
				[so].[Guid],
				[SOItems].[ItemGuid],  
				[SOItems].[ItemType],  
				[SOItems].[IsIncludeGroups],  
				[so].[AccountGuid],  
				[so].[CustCondGuid]  
			FROM    
				[SpecialOffers000] [so]   
				INNER JOIN [SOItems000] [SOItems] ON [SOItems].[SpecialOfferGuid] = [so].[Guid]
			WHERE
				(([so].[Type] = 0 /*SO_OFFERS*/) OR ([so].[Type]= 1 /*SO_SALES*/ ))  
				AND 
				([so].[IsActive] = 1)   
				AND ((@buDate = '1/1/1980') OR ( @buDate BETWEEN [dbo].[fnGetDateFromDT]( [so].[StartDate]) AND [dbo].[fnGetDateFromDT]( [so].[EndDate])))   
				AND 
					((@Qty = -1) 
					OR    
					(@Qty * (SELECT CASE @Unit WHEN 2 THEN (CASE WHEN [mtUnit2Fact] = 0 THEN 1 ELSE [mtUnit2Fact] END) WHEN 3 THEN (CASE WHEN [mtUnit3Fact] = 0 THEN 1 ELSE [mtUnit3Fact] END) ELSE 1 END FROM [vwMt] WHERE [mtGUID] = @itemGuid) /    
					(SELECT CASE [SOItems].[Unit] WHEN 2 THEN (CASE WHEN [mtUnit2Fact] = 0 THEN 1 ELSE [mtUnit2Fact] END) WHEN 3 THEN (CASE WHEN [mtUnit3Fact] = 0 THEN 1 ELSE [mtUnit3Fact] END) 
						WHEN 4 THEN (CASE WHEN [mtDefUnitFact] = 0 THEN 1 ELSE [mtDefUnitFact] END) ELSE 1 END FROM [vwMt] WHERE [mtGUID] = @itemGuid) >= [SOItems].[Quantity]))   
				AND( [so].[IsAllBillTypes] = 1 OR @btGuid = 0x0 OR @btGuid IN( SELECT [BillTypeGUID] FROM [SOBillTypes000] WHERE [SpecialOfferGUID] = [so].[Guid]))   
				AND( [CostGUID] = 0x0 OR [CostGUID] IN( SELECT [CostGuid] FROM [#CostTbl]))   
				AND( ([so].[CustCondGUID] != 0x0) OR ([SOItems].[ItemGuid] != 0x0))   
			ORDER BY so.Number DESC
		------------------------------------------------------------   
		------------------------------------------------------------   
		OPEN @C FETCH NEXT FROM @C INTO @soGUID, @soItemGUID, @soItemType, @soIncludeGroups, @soAccountGUID, @soCustCond   
		
		WHILE (@@FETCH_STATUS = 0) AND NOT EXISTS( SELECT * FROM [#Result])  
		BEGIN    
			DECLARE @bMat BIT, @bAcc BIT    
			SET @bMat = 0   
			IF (@soItemGUID = @itemGuid AND @soItemType = 0) AND (@itemGuid != 0x0)   
				SET @bMat = 1   
			ELSE BEGIN    
				SELECT @g = [mtGroup] FROM [vwMt] WHERE [mtGUID] = @itemGuid   
				IF (@soItemGUID = 0x0 AND @soItemType = 2) 
				BEGIN   
					IF (@soItemGUID = 0x0 AND @soItemType = 1 ) 
						SET @bMat = 0   
					ELSE BEGIN   
						IF @soIncludeGroups = 0   
						BEGIN    
							IF @soItemGUID = @g    
								SET @bMat = 1   
						END ELSE BEGIN    
							IF (EXISTS (SELECT [Guid] FROM [dbo].[fnGetGroupParents]( @g) WHERE [GUID] = /*@smGroupGUID*/ @soItemGUID)) OR (/*@smGroupGUID*/ @soItemGUID = @g)   
								SET @bMat = 1							   
						END    
					END    
				END ELSE BEGIN    
					EXEC @found = prcIsMatCondVerified @soItemGUID, @itemGuid
					
					IF @soItemGUID <> 0x0 AND @soItemType = @soItemTypeMaterialCondtion
					BEGIN
						SET @bMat = @found
					END
					ELSE
					BEGIN
						IF (@soItemGUID = 0x0 AND @soItemType = @soItemTypeGroup) 
						BEGIN    
							SET @bMat = @found   
						END ELSE BEGIN    
							IF @soIncludeGroups = 0   
							BEGIN    
								IF (@soItemGUID = @g) AND (@found = 1 OR @soItemType <> @soItemTypeMaterialCondtion)
									SET @bMat = 1   
							END ELSE BEGIN    
								IF ((EXISTS (SELECT [Guid] FROM [dbo].[fnGetGroupParents]( @g) WHERE [GUID] = /*@smGroupGUID*/@soItemGUID)) OR (/*@smGroupGUID*/@soItemGUID = @g)) 
									SET @bMat = 1							   
							END    
						END
					END
				END
			END    
			IF @bMat = 1   
			BEGIN    
				SET @bAcc = 0   
				IF ISNULL( @soCustCond, 0x0) = 0x0   
				BEGIN    
					IF (@soAccountGUID = 0x0) OR EXISTS( SELECT * FROM [#Accounts] WHERE [GUID] = @soAccountGUID)   
						SET @bAcc = 1   
				END ELSE BEGIN    
					EXEC @found = prcIsCustCondVerified @soCustCond, @cuGuid   
					IF ((@soAccountGUID = 0x0) OR EXISTS( SELECT * FROM [#Accounts] WHERE [GUID] = @soAccountGUID)) AND @found = 1    
						SET @bAcc = 1   
				END    
				IF @bAcc = 1   
				BEGIN    
					INSERT INTO [#Result]   
					SELECT    
						[soGuid],   
						[soNumber],   
						[soType],   
						[soStartDate],    
						[soEndDate],    
						[soName],    
						[soCanOfferedSelected], 
						[SOIGUID], 
						[SOItemGUID],    
						[SOItemQty],    
						[SOItemUnit],    
						[SOIsIncludeGroups],
						[SOItemPriceKind],
						[SOItemPriceType],   
						[SOItemDiscType],
						[sOItemDiscount],
						[SOItemPrice],
						[soCustAccGUID],   
						[soItemsAccount],   
						[soOfferedItemsAccount],   
						[soAllBillTypes],  
						 
						[SOOfferedGUID],  
						[SOOfferedNumber],   
						(CASE [soType]    
							WHEN 1 THEN [SOOfferedItemGUID]    
							ELSE (CASE ISNULL( [SOOfferedItemGUID], 0x0) WHEN 0x0 THEN @itemGuid ELSE [SOOfferedItemGUID] END)   
						END),   
						[SOOfferedQty],    
						CASE ISNULL( [SOOfferedItemGUID], 0x0) 
							WHEN 0x0 THEN ISNULL(@ItemDefUnitName, '')
						ELSE 
							ISNULL(
							(CASE [SOOfferedUnity]
								-- WHEN 1 THEN om.Unity
								WHEN 2 THEN om.Unit2
								WHEN 3 THEN om.Unit3
								ELSE om.Unity
							 END), '')
						END,  
						(CASE [soType]    
							WHEN 1 THEN [SOOfferedUnity]    
							ELSE (CASE ISNULL( [SOOfferedItemGUID], 0x0) WHEN 0x0 THEN ISNULL(@ItemDefUnit, 1) ELSE [SOOfferedUnity] END)   
						END),   
						[SOOfferedPrice],    
						[SOOfferedPriceKind],    
						[SOOfferedCurrencyPtr],    
						CASE [SOOfferedCurrencyVal]
							WHEN 0 THEN 1
							ELSE [SOOfferedCurrencyVal]
						END,
						[SOOfferedPriceType],   
						[SOOfferedIsBonus]   
					FROM 	   
						[vwSO_Items_OfferedItems] AS SO
						LEFT JOIN mt000 AS om ON SO.SOOfferedItemGUID = om.GUID
						LEFT JOIN vwMt AS MT ON SO.SOItemGUID = mt.mtGUID OR (ISNULL(mt.mtParent,0x0) <> 0x0 AND SO.SOItemGUID = mt.mtParent)
					WHERE  
						((soType = 0 /*SO_OFFERS*/) OR (soType = 1 /*SO_SALES*/ ))  
						AND
						([soGuid] = @soGUID   )
				END    
			END    
			FETCH NEXT FROM @C INTO @soGUID, @soItemGUID, @soItemType,@soIncludeGroups, @soAccountGUID, @soCustCond   
		END    
		CLOSE @C DEALLOCATE @C     
	END   
	IF (@Qty <> -1) AND EXISTS(SELECT * FROM [#Result] WHERE [Type] = 1)
	BEGIN 
		SELECT 
			*,
			CASE 
				WHEN Type != 1 OR [ItemPriceKind] != 2 OR ItemPrice = 0 THEN 0
				ELSE ItemPrice *
                    (SELECT 
                            (CASE @Unit
                                WHEN 2 THEN (CASE WHEN [mtUnit2Fact] = 0 THEN 1 ELSE [mtUnit2Fact] END)
                                WHEN 3 THEN (CASE WHEN [mtUnit3Fact] = 0 THEN 1 ELSE [mtUnit3Fact] END)
                                WHEN 4 THEN (CASE WHEN [mtDefUnitFact] = 0 THEN 1 ELSE [mtDefUnitFact] END)
                                ELSE 1 
                            END 
                            * [dbo].[fnGetCurVal] (mtCurrencyPtr, @buDate)
                            /
                            CASE [ItemUnit]
                                WHEN 2 THEN (CASE WHEN [mtUnit2Fact] = 0 THEN 1 ELSE [mtUnit2Fact] END)
                                WHEN 3 THEN (CASE WHEN [mtUnit3Fact] = 0 THEN 1 ELSE [mtUnit3Fact] END)
                                WHEN 4 THEN (CASE WHEN [mtDefUnitFact] = 0 THEN 1 ELSE [mtDefUnitFact] END)
                                ELSE 1 
                            END )
                    FROM [vwMt] WHERE [mtGUID] = @itemGuid)  
			END AS [UnitSpecifiedPrice]
		FROM 
			[#Result] WHERE [Type] = 1 
		ORDER BY 
			([ItemQty] * (SELECT CASE [ItemUnit]
									WHEN 2 THEN (CASE WHEN [mtUnit2Fact] = 0 THEN 1 ELSE [mtUnit2Fact] END)
									WHEN 3 THEN (CASE WHEN [mtUnit3Fact] = 0 THEN 1 ELSE [mtUnit3Fact] END)
									WHEN 4 THEN (CASE WHEN [mtDefUnitFact] = 0 THEN 1 ELSE [mtDefUnitFact] END)
									ELSE 1 
								END 
						FROM [vwMt] WHERE [mtGUID] = @itemGuid)) DESC, [Number] DESC
		RETURN
	END 
	SELECT *, 0 AS [UnitSpecifiedPrice] FROM [#Result] ORDER BY [Number] DESC, [ItemOrd]
#######################################################################################
#END
