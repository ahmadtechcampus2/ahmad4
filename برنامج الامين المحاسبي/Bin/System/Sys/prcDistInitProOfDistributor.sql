##########################################################################
CREATE PROCEDURE prcDistInitProOfDistributor
		@DistributorGUID uniqueidentifier
AS       
	SET NOCOUNT ON       
	DELETE DistDevicePro000 WHERE DistributorGuid = @DistributorGuid
	DELETE DistDeviceProBudget000 WHERE DistributorGuid = @DistributorGuid
	DELETE DistDeviceProDetail000 WHERE DistributorGuid = @DistributorGuid
	DELETE DistDeviceCtd000 WHERE DistributorGuid = @DistributorGuid AND ObjectType = 2 -- Promotions
	DECLARE @condType int
	DECLARE @freeType int
	DECLARE @condUnity int
	DECLARE @freeUnity int
	DECLARE @Unity int
	DECLARE @type int
	DECLARE @qty float
	DECLARE @matGuid uniqueidentifier
	DECLARE @proGuid uniqueidentifier
	DECLARE @ExportOffers BIT
	SELECT @ExportOffers = ExportOffers FROM Distributor000 Where Guid = @DistributorGUID
	IF @ExportOffers = 0 
		RETURN  
	INSERT INTO DistDevicePro000(
		[DistributorGUID] ,
		[ProGuid] ,
		[Name] ,
		[StartDate] ,
		[EndDate] ,
		[CondQty] ,
		[FreeQty] ,
		[ProBudget],
		[ProQty],
		[ProNumber],
		[CondType],
		[FreeType],
		[ChkExactlyQty],
		[ImagePath],
		[CondUnity],
		[FreeUnity]
		)
	SELECT 
		@DistributorGUID,
		Pr.Guid,
		Pr.Name,
		Pr.FDate,
		Pr.LDate,
		Pr.CondQty,
		Pr.FreeQty,
		Bg.Qty,
		Bg.RealPromQty,
		Pr.Number,
		Pr.CondType,
		Pr.FreeType,	
		Pr.ChkExactlyQty,
		Pr.ImagePath,
		Pr.CondUnity,
		Pr.FreeUnity
	FROM 
		DistPromotions000	AS Pr
		INNER JOIN DistPromotionsBudget000 AS Bg ON Pr.Guid = Bg.ParentGuid AND Bg.Qty-RealPromQty > 0
	WHERE 
		dbo.fnGetDateFromDt(GetDate()) BETWEEN Pr.FDate AND Pr.LDate AND
		Bg.DistributorGUID = @DistributorGUID	AND
		Pr.IsActive = 1
	DECLARE cur CURSOR FOR
	SELECT 
			[Pr].[ProGuid],
			[PrD].[MatGUID],
			[PrD].[Qty],
			[PrD].[Unity],
			[PrD].[Type],
						
			[Pr].[CondType],
			[Pr].[FreeType],
			[Pr].[FreeUnity],
			[Pr].[condUnity]
		FROM 
			DistDevicePro000 AS Pr
			INNER JOIN DistPromotionsDetail000 AS PrD ON [PrD].[ParentGUID] = [Pr].[proGuid]
			LEFT JOIN DistDeviceMt000 AS mt ON [PrD].[MatGUID] = [mt].[mtGuid] AND mt.DistributorGuid = @DistributorGuid
			LEFT JOIN DistDeviceGr000 AS gr ON [PrD].[MatGUID] = [gr].[grGuid] AND gr.DistributorGuid = @DistributorGuid
		WHERE 
			[Pr].[DistributorGuid] = @DistributorGuid
			AND (mt.Guid IS NOT NULL OR gr.Guid IS NOT NULL)
		
	OPEN cur
	FETCH NEXT FROM cur INTO @proGuid, @matGuid, @qty, @Unity, @type, @condType, @freeType, @freeUnity, @condUnity
	WHILE @@Fetch_Status = 0 
	BEGIN
		if (@condType = 1 and @type = 0)
			INSERT INTO DistDeviceProDetail000(
			[DistributorGUID],
			[ParentGUID],
			[MatGUID],
			[Qty],
			[Unity],	
			[Type]
			)
			Values 
				 (@DistributorGuid, @proGuid, @matGuid, @qty, @condUnity, @type)
		else
			if (@freeType = 1 and @type = 1)
				INSERT INTO DistDeviceProDetail000(
				[DistributorGUID],
				[ParentGUID],
				[MatGUID],
				[Qty],
				[Unity],	
				[Type]
				)
				Values
				  (@DistributorGuid, @proGuid, @matGuid, @qty, @freeUnity, @type)
			else 
				INSERT INTO DistDeviceProDetail000(
					[DistributorGUID],
					[ParentGUID],
					[MatGUID],
					[Qty],
					[Unity],	
					[Type]
					)
					Values
						 (@DistributorGuid, @proGuid, @matGuid, @qty, @Unity, @type)
		
			
		Fetch Next From cur Into @proGuid, @matGuid, @qty, @Unity, @type, @condType, @freeType, @freeUnity, @condUnity
	END
	CLOSE cur
	DEALLOCATE cur
	-- Delete Promotions Which Haven't Mats Loaded
	DELETE DistDevicePro000 
	WHERE 
		DistributorGuid = @DistributorGuid AND 
		ProGuid NOT IN (Select ParentGuid From DistDeviceProDetail000 WHERE DistributorGuid = @DistributorGuid)
	INSERT INTO DistDeviceCtd000(
		[DistributorGUID],
		[ParentGUID],
		[Number],
		[ObjectGUID],

		[ObjectType]	-- ! For Discount	2 For Promotions
	)
	SELECT 
		@DistributorGUID,
		[PCt].[CustTypeGUID],
		1,
		[Pr].[ProGUID],
		2	-- Promotions
	FROM 
		DistDevicePro000	AS Pr
		INNER JOIN DistPromotionsCustType000 AS PCt On [Pr].[ProGUID] = [PCt].[ParentGUID]
	WHERE 
		[Pr].[DistributorGUID] = @DistributorGUID

		INSERT INTO DistDeviceProBudget000(
		[DistributorGUID] ,
		[ProGuid] ,
		[ProQty]
		)
	SELECT 
		Pr.DistributorGUID	,
		Pr.ParentGUID,
		Pr.RealPromQty
	
	FROM 
		DistPromotionsBudget000	AS Pr
	WHERE 
		Pr.DistributorGUID = @DistributorGUID

/*
EXEC prcDistInitProOfDistributor 'F6ADB10A-0DE6-40A0-94D5-04409EFA8293'
*/
##########################################################################
##END