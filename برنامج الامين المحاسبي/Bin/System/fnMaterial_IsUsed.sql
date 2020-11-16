###########################################################################
CREATE FUNCTION fnMaterial_IsUsed( @MatGUID [UNIQUEIDENTIFIER])
	RETURNS [INT]
AS BEGIN
/*
this function:
	- returns a constant integer representing the existance of a given material in database tables.
	- is usually called from trg_mt000_CheckConstraints.
*/
	DECLARE @result [INT]
	SET @result = 0
	
	-- اختبار تواجد المادة في الطلبيات 
	IF EXISTS(select distinct bi.MatGUID from bi000 as bi join ORADDINFO000 as o on bi.ParentGUID = O.ParentGuid  WHERE [MatGUID] = @MatGUID
		OR MatGuid IN (SELECT [GUID] FROM mt000 WHERE Parent = @MatGUID))
		RETURN  0x000113
	-- اختبار تواجد المادة في نماذج التصنيع
	IF EXISTS(SELECT * FROM [mi000] WHERE [MatGUID] = @MatGUID OR MatGuid IN (SELECT [GUID] FROM mt000 WHERE Parent = @MatGUID))
		RETURN  0x000102
	-- اختبار تواجد المادة في بطاقات التكليف
	IF EXISTS(SELECT bi.MatGUID from RecostMaterials000 AS R JOIN bi000 as bi ON bi.ParentGuid = R.OutBillGuid WHERE [MatGUID] = @MatGUID
		OR MatGuid IN (SELECT [GUID] FROM mt000 WHERE Parent = @MatGUID))
		RETURN  0x000114
	-- اختبار تواجد لمادة في المواد التجميعية
	IF [dbo].[fnObjectExists]('md000') <> 0 
	BEGIN
		IF EXISTS(SELECT * FROM [md000] WHERE [MatGUID] = @MatGUID OR MatGuid IN (SELECT [GUID] FROM mt000 WHERE Parent = @MatGUID))
			RETURN  0x000103
	END
	--ELSE
	--	SET @result = 0
	--اختبار تواجد المادة في مجموعة تجميعية 
	 IF EXISTS(SELECT * FROM [gri000] WHERE [MatGUID] = @MatGUID OR MatGuid IN (SELECT [GUID] FROM mt000 WHERE Parent = @MatGUID))
			RETURN  0x000115
	--اختبار تواجد المادة في عروض التوزيع 
	 IF EXISTS(SELECT * FROM [DistPromotionsDetail000] WHERE [MatGUID] = @MatGUID OR MatGuid IN (SELECT [GUID] FROM mt000 WHERE Parent = @MatGUID))
			RETURN  0x000116
	-- اختبار تواجد المادة في نقاط البيع  
	 IF EXISTS(SELECT * FROM [SpecialOfferDetails000] WHERE [MatID] = @MatGUID OR MatID IN (SELECT [GUID] FROM mt000 WHERE Parent = @MatGUID))
			RETURN  0x000117
	-- اختبار تواجد المادة في بطاقة البدائل  
	 IF EXISTS(SELECT * FROM [AlternativeMatsItems000] WHERE [MatGUID] = @MatGUID OR MatGuid IN (SELECT [GUID] FROM mt000 WHERE Parent = @MatGUID))
			RETURN  0x000118
	-- اختبار تواجد المادة في الفواتير
	IF EXISTS(SELECT * FROM [bi000] WHERE [MatGUID] = @MatGUID OR MatGuid IN (SELECT [GUID] FROM mt000 WHERE Parent = @MatGUID))
		RETURN  0x000101
	-- اختبار تواجد المادة في العروض الخاصة
	IF EXISTS(SELECT * FROM [SpecialOffer000] WHERE [MatID] = @MatGUID OR MatID IN (SELECT [GUID] FROM mt000 WHERE Parent = @MatGUID))
			RETURN  0x000130
    
	IF [dbo].[fnObjectExists]('hosConsumed000') <> 0 
	BEGIN
		IF EXISTS( SELECT * FROM [hosConsumed000] WHERE [MatGuid] = @MatGUID OR MatGuid IN (SELECT [GUID] FROM mt000 WHERE Parent = @MatGUID)) 
			RETURN 0x000104
	END
	IF [dbo].[fnObjectExists]('HosSurgeryMat000') <> 0 
	BEGIN
		IF EXISTS( SELECT * FROM [HosSurgeryMat000] WHERE [MatGuid] = @MatGUID OR MatGuid IN (SELECT [GUID] FROM mt000 WHERE Parent = @MatGUID))
			RETURN  0x000105
	END
	IF [dbo].[fnObjectExists]('HosRadioGraphyMats000') <> 0 
	BEGIN
		IF EXISTS( SELECT * FROM [HosRadioGraphyMats000] WHERE [MatGuid] = @MatGUID OR MatGuid IN (SELECT [GUID] FROM mt000 WHERE Parent = @MatGUID))
			RETURN  0x000106
	END
	
	IF EXISTS( SELECT * FROM [sm000] WHERE [MatGuid] = @MatGUID OR MatGuid IN (SELECT [GUID] FROM mt000 WHERE Parent = @MatGUID))
		RETURN  0x000107
	IF EXISTS( SELECT * FROM [sd000] WHERE [MatGuid] = @MatGUID OR MatGuid IN (SELECT [GUID] FROM mt000 WHERE Parent = @MatGUID))
		RETURN  0x000108
	IF [dbo].[fnObjectExists]('bgi000') <> 0 
	BEGIN
		IF EXISTS( SELECT * FROM [bgi000] WHERE [ItemID] = @MatGUID OR ItemID IN (SELECT [GUID] FROM mt000 WHERE Parent = @MatGUID))
			RETURN  0x000111
	END
	IF [dbo].[fnObjectExists]('RestOrderItemTemp000') <> 0 
	BEGIN
		IF EXISTS( SELECT * FROM [RestOrderItemTemp000] WHERE [MatID] = @MatGUID OR [MatID] IN (SELECT [GUID] FROM mt000 WHERE Parent = @MatGUID))
			RETURN  0x000112
	END
	IF [dbo].[fnObjectExists]('RestOrderItem000') <> 0 
	BEGIN
		IF EXISTS( SELECT * FROM [RestOrderItem000] WHERE [MatID] = @MatGUID OR [MatID] IN (SELECT [GUID] FROM mt000 WHERE Parent = @MatGUID))
			RETURN  0x000112
	END
	IF [dbo].[fnObjectExists]('JOCBOMFinishedGoods000') <> 0 
	BEGIN
		IF EXISTS( SELECT * FROM [JOCBOMFinishedGoods000] WHERE [MatPtr] = @MatGUID OR MatPtr IN (SELECT [GUID] FROM mt000 WHERE Parent = @MatGUID))
			RETURN  0x000119
	END
	IF [dbo].[fnObjectExists]('JOCBOMRawMaterials000') <> 0 
	BEGIN
		IF EXISTS( SELECT * FROM [JOCBOMRawMaterials000] WHERE [MatPtr] = @MatGUID OR MatPtr IN (SELECT [GUID] FROM mt000 WHERE Parent = @MatGUID))
			RETURN  0x000120
	END
	IF [dbo].[fnObjectExists]('JOCBOMSpoilage000') <> 0 
	BEGIN
		IF EXISTS( SELECT * FROM [JOCBOMSpoilage000] WHERE [SpoilageMaterial] = @MatGUID OR [SpoilageMaterial] IN (SELECT [GUID] FROM mt000 WHERE Parent = @MatGUID))
			RETURN  0x000121
	END
	IF [dbo].[fnObjectExists]('JOCOperatingBOMFinishedGoods000') <> 0 
	BEGIN
		IF EXISTS( SELECT * FROM [JOCOperatingBOMFinishedGoods000] WHERE [MaterialGuid] = @MatGUID OR MaterialGuid IN (SELECT [GUID] FROM mt000 WHERE Parent = @MatGUID))
			RETURN  0x000122
	END
	IF [dbo].[fnObjectExists]('JOCOperatingBOMFinishedGoods000') <> 0 
	BEGIN
		IF EXISTS( SELECT * FROM [JOCOperatingBOMFinishedGoods000] WHERE [SpoilageMaterial] = @MatGUID OR SpoilageMaterial IN (SELECT [GUID] FROM mt000 WHERE Parent = @MatGUID))
			RETURN  0x000123
	END
	IF [dbo].[fnObjectExists]('MaterialAlternatives000') <> 0 
	BEGIN
		IF EXISTS( SELECT * FROM [MaterialAlternatives000] WHERE [MatAltGuid] = @MatGUID OR MatAltGuid IN (SELECT [GUID] FROM mt000 WHERE Parent = @MatGUID))
			RETURN  0x000124
	END
	IF [dbo].[fnObjectExists]('OfferedItems000') <> 0 
	BEGIN
		IF EXISTS( SELECT * FROM [OfferedItems000] WHERE [MatID] = @MatGUID OR [MatID] IN (SELECT [GUID] FROM mt000 WHERE Parent = @MatGUID))
			RETURN  0x000125
	END
	
	---------عروض خاصة---
	IF [dbo].[fnObjectExists]('SOOfferedItems000') <> 0 
	BEGIN
		IF EXISTS( SELECT * FROM [SOOfferedItems000] WHERE [ItemGUID] = @MatGUID OR [ItemGUID] IN (SELECT [GUID] FROM mt000 WHERE Parent = @MatGUID))
			RETURN  0x000126
	END
	
	IF [dbo].[fnObjectExists]('soConditionalDiscounts000') <> 0 
	BEGIN
		IF EXISTS( SELECT * FROM [soConditionalDiscounts000] WHERE [ItemGUID] = @MatGUID OR [ItemGUID] IN (SELECT [GUID] FROM mt000 WHERE Parent = @MatGUID))
			RETURN  0x000127
	END
	
	IF [dbo].[fnObjectExists]('SOItems000') <> 0 
	BEGIN
		IF EXISTS( SELECT * FROM [SOItems000] WHERE [ItemGUID] = @MatGUID OR [ItemGUID] IN (SELECT [GUID] FROM mt000 WHERE Parent = @MatGUID))
			RETURN  0x000128
	END
	
	IF @result IS NULL 
		SET @result = 0
	
	RETURN @result
END


###########################################################################

CREATE FUNCTION fnGetParentBill(@BillGuid UNIQUEIDENTIFIER = 0x0)
	RETURNS [UNIQUEIDENTIFIER]
AS BEGIN
	DECLARE @ParentGUID [UNIQUEIDENTIFIER]	
	IF EXISTS(SELECT * FROM ORi000 WHERE BuGuid = @BillGuid)
	BEGIN
		SELECT @ParentGUID = BuGuid FROM ORi000 WHERE BuGuid = @BillGuid
	END
	ELSE IF  EXISTS(SELECT * FROM [BillRelations000] WHERE [BillGuid] = @BillGuid)	
	BEGIN
		SELECT @ParentGUID = BillGuid FROM [BillRelations000] WHERE BillGuid = @BillGuid
	END
	ELSE IF  EXISTS(SELECT * FROM [BillRelations000] WHERE RelatedBillGuid = @BillGuid)	
	BEGIN
		SELECT @ParentGUID = BillGuid FROM [BillRelations000] WHERE RelatedBillGuid = @BillGuid
	END
	ELSE IF  EXISTS(SELECT * FROM [MB000]  WHERE [BillGUID] = @BillGuid)
	BEGIN
		SELECT @ParentGUID = BillGUID FROM [MB000]  WHERE [BillGUID] = @BillGuid
	END
	RETURN @ParentGUID
END

###########################################################################
#END