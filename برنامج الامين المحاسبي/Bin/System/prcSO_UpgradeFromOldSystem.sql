#########################################################
CREATE PROC prcSO_UpgradeFromOldSystem
AS
	-- Add This Column To Solve The Problem In Branch
	EXECUTE [prcAddIntFld]	'sm000', 'DiscountType'

-- Upgrade SpecailOffers data From Old tables to new tables
-------------------------------------------
---- SpecialOffers000
	INSERT INTO SpecialOffers000(
		[Guid],
		Number,
		Code,
		Name,
		LatinName,
		[Type],
		StartDate,
		EndDate,
		AccountGuid,
		CostGuid,
		IsAllBillTypes,
		CustCondGuid,
		IsActive,
		Class,
		[Group],
		ItemsCondition,
		OfferedItemsCondition,
		Quantity,
		Unit, 
		ItemsAccount,
		ItemsDiscountAccount,
		OfferedItemsAccount,
		OfferedItemsDiscountAccount,
		BranchMask,
		IsApplicableToCombine)
	SELECT
		sm.[GUID], 
		sm.Number, 
		CAST(sm.Number AS NVARCHAR(200))	AS Code,
		sm.Notes	AS Name,
		''		AS LatinName,
		sm.[Type] - 1, 
		sm.StartDate,
		sm.EndDate,
		sm.CustAccGuid		AS AccountGuid,
		sm.CostGuid,
		sm.bAllBt			AS IsAllBillTypes,
		sm.CustCondGuid,
		sm.bActive,
		sm.ClassStr,
		sm.GroupStr,
		0	AS ItemsConditions,
		0	AS OfferedItemsCondition,
		0	AS Quantity,
		0	AS Unit,
		sm.OfferAccGuid	AS ItemsAccount,
		0x0				AS ItemsDiscountAccount,
		sm.IOfferAccGuid	AS OfferedItemsAccount,	
		0x0				AS OfferedItemsDiscountAccount,
		sm.BranchMask,
		0				AS IsApplicableToCombine	
	FROM
		sm000	AS sm
		LEFT JOIN SpecialOffers000 AS so ON so.Guid = sm.Guid
	WHERE
		so.Guid IS NULL	

-------------------------------------------
---- SOItems
	INSERT INTO SOItems000(
		[GUID],
		SpecialOfferGuid,
		ItemType,
		ItemGuid,
		IsSpecified,
		IsIncludeGroups,
		Number,
		Quantity,
		Unit,
		PriceKind,
		PriceType,
		Price,
		DiscountType,
		Discount,
		OfferedItemGuid,
		BonusQuantity,
		DiscountRatio)	
	SELECT
		NEWID(),
		sm.GUID AS	SpecialOfferGuid,
		CASE MatCondGuid 
			WHEN 0x0 THEN 
				(CASE GroupGuid 
					WHEN 0x0 THEN 0 
					ELSE 1 
				END) 
			ELSE 2 
		END AS ItemType,
		CASE MatCondGuid
			WHEN 0x0 THEN 
				CASE GroupGuid
					WHEN 0x0 THEN MatGUID
					ELSE GroupGuid
				END
			ELSE MatCondGuid
		END AS ItemGuid,
		0 AS IsSpecifieid,
		bIncludeGroups AS IsIncludeGroup,
		@@ROWCOUNT,
		Qty,
		CASE MatGUID
			WHEN 0x0 THEN 
				CASE 
					WHEN Unity > 0 THEN Unity - 1
					ELSE 3
				END
			ELSE Unity
		END,
		0,
		sm.PriceType,
		0	AS Price,
		sm.DiscountType - 1	AS DiscountType,
		sm.Discount			AS Discount,
		0x0					AS OfferedItemGuid,
		0					AS BonusQuantity,
		0					AS DiscountRatio
	FROM
		sm000	AS sm
		LEFT JOIN SOItems000 AS so ON so.SpecialOfferGuid = sm.Guid
	WHERE 
		so.Guid IS Null
-------------------------------------------
---- SOOfferedItems
	INSERT INTO SOOfferedItems000(
		GUID, 
		SpecialOfferGuid,
		ItemType,
		ItemGuid,
		IsIncludeGroups,
		Number,
		Quantity,
		Unit,
		PriceKind,
		PriceType,
		Price,
		CurrencyGuid,
		CurrencyValue,
		IsBonus,
		DiscountType,
		Discount)	
	SELECT
		sd.GUID,
		ParentGuid	AS	SpecialOfferGuid,
		0			AS ItemType,				 
		MatGuid		AS ItemGuid,				 
		0			AS IsIncludeGroups,
		Item,
		Qty,
		Unity,
		-------
		PriceFlag + 1	AS PriceKind,
		PolicyType		AS PriceType,
		sd.Price			AS Price,
		-------
		sd.CurrencyGuid,
		sd.CurrencyVal,
		bBonus,
		0	AS DiscountType,
		0	AS Discount
	FROM
		sd000	AS sd
		LEFT JOIN SOOfferedItems000		AS so ON so.Guid = sd.Guid
	WHERE 
		so.Guid IS NULL	
-------------------------------------------
---- SOBillTypes
	INSERT INTO SOBillTypes000(
		GUID,
		SpecialOfferGuid,
		BillTypeGuid)
	SELECT
		sm.GUID,
		sm.ParentGuid,
		sm.BtGuid
	FROM
		smbt000	AS sm
		LEFT JOIN SOBillTypes000 AS so ON so.Guid = sm.Guid
	WHERE 
		so.Guid IS NULL	
		
-------------------------------------------
--Disable Triggers
	ALTER TABLE bi000 DISABLE TRIGGER trg_bi000_CheckConstraints
----------------------
--Update bills
	UPDATE bi
	SET bi.SOGuid = so.Guid
	FROM 
		bi000 bi
		INNER JOIN SOItems000 AS so ON so.SpecialOfferGUID = bi.SoGuid
	WHERE
		bi.SOType = 1


	UPDATE bi
	SET bi.SOGuid = so.[GUID]
	FROM
		bi000 bi
		INNER JOIN SOOfferedItems000 so ON so.SpecialOfferGUID = bi.SOGuid
	WHERE
		bi.MatGUID = so.ItemGUID
		
		
	UPDATE bi
	SET bi.SOGuid = so.[GUID]
	FROM
		bi000 bi
		INNER JOIN (
					SELECT soo.GUID, soo.SpecialOfferGUID
					FROM 
						SOOfferedItems000 soo 
						INNER JOIN SOItems000 soi ON soi.SpecialOfferGUID = soo.SpecialOfferGUID
					WHERE 
						soi.ItemType <> 0
						AND soo.ItemGUID = 0x0
					)so ON so.SpecialOfferGUID = bi.SOGuid
	
	ALTER TABLE bi000 ENABLE TRIGGER trg_bi000_CheckConstraints
#########################################################
#END
	
