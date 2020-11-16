################################################################################
CREATE PROC	prcPL_GetBillItems
	@PackingListGUID UNIQUEIDENTIFIER,
	@BillGUID UNIQUEIDENTIFIER
AS 
	SET NOCOUNT ON 

	CREATE TABLE #BillItems(
		ItemGUID UNIQUEIDENTIFIER, 
		[ItemNumber] INT, 
		[MatGUID] UNIQUEIDENTIFIER,
		[MatCode] NVARCHAR(250), 
		[MatName] NVARCHAR(250), 
		[MatLatinName] NVARCHAR(250),
		[Unity] [INT],
		[UnityName] NVARCHAR(250), 
		[ItemQty] FLOAT, 
		[ItemBonusQnt] FLOAT, 
		-----------------
		[UnpackedQuantity] FLOAT,
		FromPackage INT, 
		ToPackage INT, 
		QuantityInPackage FLOAT,
		PackageGUID UNIQUEIDENTIFIER, 
		PackageName NVARCHAR(250), 
		PackageLatinName NVARCHAR(250),
		-----------------
		--DefaultDimensionUnit INT, 
		--[DefaultLength] FLOAT, [DefaultWidth] FLOAT, [DefaultHeight] FLOAT, 
		--DefaultWeightUnit INT, 
		--[DefaultGrossWeight] FLOAT, [DefaultNetWeight] FLOAT, [DefaultDrainedWeight] FLOAT, 
		-----------------
		DimensionUnit INT, [Length] FLOAT, [Width] FLOAT, [Height] FLOAT, Volume FLOAT,
		WeightUnit INT, [GrossWeight] FLOAT, [NetWeight] FLOAT, [DrainedWeight] FLOAT, 
		-----------------
		[PackageListItemGUID] UNIQUEIDENTIFIER,
		[Notes] NVARCHAR(500), 
		[PackagedNumber] INT, 
		IsPacked [BIT],
		[CompositionName] NVARCHAR(250), 
		[CompositionLatinName] NVARCHAR(250))

	INSERT INTO #BillItems
	SELECT 
		bi.GUID,
		bi.[ItemNumber],
		bi.[MatPtr],
		bi.[MatCode],
		bi.[MatName],
		bi.[LatinName],
		bi.Unity,
		bi.[UnityName],
		bi.[Qty],
		bi.[BonusQnt],
		--------------------------------------
		bi.[Qty] + bi.[BonusQnt], 0, 0, 0, 
		0x0, '', '',
		--------------------------------------
		--ISNULL(dw.Dimension, 0), 
		--ISNULL(dw.UnitLength, 0), ISNULL(dw.UnitWidth, 0), ISNULL(dw.Unitheight, 0),
		--ISNULL(dw.[Weight], 0), 
		--ISNULL(dw.UnitGrossWeight, 0), ISNULL(dw.UnitNetWeight, 0), ISNULL(dw.UnitDrainedWeight, 0),
		--------------------------------------
		ISNULL(dw.Dimension, 0), ISNULL(dw.UnitLength, 0), ISNULL(dw.UnitWidth, 0), ISNULL(dw.Unitheight, 0), 0, 
		ISNULL(dw.[Weight], 0), ISNULL(dw.UnitGrossWeight, 0), ISNULL(dw.UnitNetWeight, 0), ISNULL(dw.UnitDrainedWeight, 0),
		--------------------------------------
		0x0, '', 0, 0,
		bi.[CompositionName],
		bi.[CompositionLatinName]
	FROM 
		[vwBillItems] bi 
		LEFT JOIN [mtdw000] dw ON bi.[MatPtr] = dw.MatGuid AND bi.Unity = (dw.NumUnit + 1)
	WHERE 
		bi.[BillNumber] = @BillGUID
		AND 
		bi.[MatType] = 0 -- ãÓÊæÏÚíÉ

	UPDATE #BillItems 
	SET 
		PackageGUID = pk.GUID, 
		PackageName = pk.Name, 
		PackageLatinName = pk.LatinName 
	FROM 
		[Packages000] pk 
		INNER JOIN PackingLists000 pl ON pk.[GUID] = pl.DefPackageGUID
	WHERE 
		pl.GUID = @PackingListGUID

	UPDATE #BillItems
	SET [UnpackedQuantity] = bi.[UnpackedQuantity] - plbi.[PackedQuantity]
	FROM 
		#BillItems bi
		INNER JOIN 
			(SELECT plb.BiGUID, SUM((plb.[ToPackage] - plb.[FromPackage] + 1) * plb.QuantityInPackage) AS [PackedQuantity] 
				FROM 
					#BillItems b 
					INNER JOIN [dbo].[PackingListBis000] plb ON b.[ItemGUID] = plb.BiGUID 
					INNER JOIN [PackingListsBills000] bu ON bu.GUID = plb.ParentGUID
				WHERE bu.PackingListGUID != @PackingListGUID GROUP BY plb.BiGUID) plbi ON bi.[ItemGUID] = plbi.BiGUID

	INSERT INTO #BillItems
	SELECT 
		bi.ItemGUID,
		bi.[ItemNumber],
		bi.[MatGUID],
		bi.[MatCode],
		bi.[MatName],
		bi.[MatLatinName],
		bi.Unity,
		bi.[UnityName],
		bi.[ItemQty],
		bi.[ItemBonusQnt],
		----------------------
		-- (plbi.[ToPackage] - plbi.[FromPackage] + 1) * plbi.QuantityInPackage,
		bi.[UnpackedQuantity],
		plbi.FromPackage, 
		plbi.ToPackage, 
		plbi.QuantityInPackage,
		ISNULL(pk.GUID, 0x0), 
		ISNULL(pk.Name, ''), 
		ISNULL(pk.LatinName, ''), 

		--bi.DefaultDimensionUnit, 
		--bi.[DefaultLength], 
		--bi.[DefaultWidth], 
		--bi.[DefaultHeight], 
		--bi.DefaultWeightUnit, 
		--bi.[DefaultGrossWeight], 
		--bi.[DefaultNetWeight], 
		--bi.[DefaultDrainedWeight],

		plbi.DimensionUnit, 
		plbi.[Length], 
		plbi.[Width], 
		plbi.[Height], 
		plbi.Volume,
		plbi.WeightUnit, 
		plbi.[GrossWeight], 
		plbi.[NetWeight], 
		plbi.[DrainedWeight],
		 
		plbi.[GUID],
		plbi.[Notes], 
		plbi.[Number], 
		1,
		bi.[CompositionName],
		bi.[CompositionLatinName]
	FROM 
		#BillItems bi 
		INNER JOIN [dbo].[PackingListBis000] plbi ON bi.[ItemGUID] = plbi.BiGUID
		INNER JOIN [dbo].[PackingListsBills000] bu ON bu.[GUID] = plbi.ParentGUID
		INNER JOIN [dbo].[vbPackingLists] pl ON pl.[GUID] = bu.PackingListGUID
		LEFT JOIN [Packages000] pk ON plbi.PackageGUID = pk.[GUID] 
	WHERE 
		pl.[GUID] = @PackingListGUID
		AND 
		plbi.FromPackage > 0 AND plbi.ToPackage > 0 AND plbi.QuantityInPackage > 0

	DECLARE @c CURSOR 
	DECLARE 
		@guid UNIQUEIDENTIFIER,
		@biguid UNIQUEIDENTIFIER,
		@prev_biguid UNIQUEIDENTIFIER,
		@packQuantity FLOAT,
		@FromPackage INT, 
		@ToPackage INT, 		
		@QuantityInPackage FLOAT 
		 
	SET @prev_biguid = 0x0
	SET @packQuantity = 0

	SET @c = CURSOR FAST_FORWARD FOR SELECT ItemGUID, [PackageListItemGUID], FromPackage, ToPackage, QuantityInPackage FROM #BillItems WHERE IsPacked = 1 ORDER BY [ItemNumber], [PackagedNumber] 
	OPEN @c FETCH NEXT FROM @c INTO @biguid, @guid, @FromPackage, @ToPackage, @QuantityInPackage
	WHILE @@FETCH_STATUS = 0
	BEGIN 
		IF @prev_biguid = @biguid
		BEGIN
			UPDATE #BillItems SET [UnpackedQuantity] = [UnpackedQuantity] - @packQuantity WHERE [PackageListItemGUID] = @guid
			SET @packQuantity = @packQuantity + ((@ToPackage - @FromPackage + 1) * @QuantityInPackage)
		END ELSE 
		BEGIN 
			SET @prev_biguid = @biguid
			SET @packQuantity = (@ToPackage - @FromPackage + 1) * @QuantityInPackage
		END 
		FETCH NEXT FROM @c INTO @biguid, @guid, @FromPackage, @ToPackage, @QuantityInPackage
	END CLOSE @c DEALLOCATE @c 

	UPDATE #BillItems
	SET [UnpackedQuantity] = bi.[ItemQty] + bi.[ItemBonusQnt] - plbi.[PackedQuantity]
	FROM 
		#BillItems bi
		INNER JOIN 
			(SELECT plb.BiGUID, SUM((plb.[ToPackage] - plb.[FromPackage] + 1) * plb.QuantityInPackage) AS [PackedQuantity] 
				FROM #BillItems b INNER JOIN [dbo].[PackingListBis000] plb
				ON b.[ItemGUID] = plb.BiGUID WHERE IsPacked = 0 GROUP BY plb.BiGUID) plbi ON bi.[ItemGUID] = plbi.BiGUID
	WHERE IsPacked = 0		
	
	DELETE #BillItems WHERE [UnpackedQuantity] <= 0

	SELECT * FROM #BillItems ORDER BY [ItemNumber], IsPacked DESC, [PackagedNumber]
################################################################################
CREATE PROCEDURE GetAllBillCustItem
	@PackingListGUID UNIQUEIDENTIFIER,
	@CustGuid UNIQUEIDENTIFIER,
	@detailed INT,
	@Sort int = 1
AS
	SET NOCOUNT ON
	
	CREATE TABLE #BillItems(
		ItemGUID UNIQUEIDENTIFIER, 
		[ItemNumber] INT, 
		[MatGUID] UNIQUEIDENTIFIER,
		[MatCode] NVARCHAR(250), 
		[MatName] NVARCHAR(250), 
		[MatLatinName] NVARCHAR(250),
		[UnityName] NVARCHAR(250), 
		[ItemQty] FLOAT, 
		[ItemBonusQnt] FLOAT, 
		-----------------
		[UnpackedQuantity] FLOAT,
		FromPackage INT, 
		ToPackage INT, 
		QuantityInPackage FLOAT,
		PackageGUID UNIQUEIDENTIFIER, 
		PackageName NVARCHAR(250), 
		PackageLatinName NVARCHAR(250),
		-----------------
		-- DefaultDimensionUnit INT, 
		[DefaultLength] FLOAT, [DefaultWidth] FLOAT, [DefaultHeight] FLOAT, 
		-- DefaultWeightUnit INT, 
		[DefaultGrossWeight] FLOAT, [DefaultNetWeight] FLOAT, [DefaultDrainedWeight] FLOAT, 
		-----------------
		DimensionUnit INT, [Length] FLOAT, [Width] FLOAT, [Height] FLOAT, Volume FLOAT,
		WeightUnit INT, [GrossWeight] FLOAT, [NetWeight] FLOAT, [DrainedWeight] FLOAT, 
		-----------------
		[PackageListItemGUID] UNIQUEIDENTIFIER,
		[Notes] NVARCHAR(500), 
		[PackagedNumber] INT, 
		IsPacked [BIT],
		[CompositionName] NVARCHAR(250), 
		[CompositionLatinName] NVARCHAR(250))

	INSERT INTO #BillItems
	SELECT 
		bi.GUID,
		bi.[ItemNumber],
		bi.[MatPtr],
		bi.[MatCode],
		bi.[MatName],
		bi.[LatinName],
		bi.[UnityName],
		bi.[Qty],
		bi.[BonusQnt],
		--------------------------------------
		bi.[Qty] + bi.[BonusQnt], 0, 0, 0, 
		0x0, '', '',
		--------------------------------------
		-- ISNULL(dw.Dimension, 0), 
		ISNULL(dw.UnitLength, 0), ISNULL(dw.UnitWidth, 0), ISNULL(dw.Unitheight, 0),
		-- ISNULL(dw.[Weight], 0), 
		ISNULL(dw.UnitGrossWeight, 0), ISNULL(dw.UnitNetWeight, 0), ISNULL(dw.UnitDrainedWeight, 0),
		--------------------------------------
		ISNULL(dw.Dimension, 0), ISNULL(dw.UnitLength, 0), ISNULL(dw.UnitWidth, 0), ISNULL(dw.Unitheight, 0), 0, 
		ISNULL(dw.[Weight], 0), ISNULL(dw.UnitGrossWeight, 0), ISNULL(dw.UnitNetWeight, 0), ISNULL(dw.UnitDrainedWeight, 0),
		--------------------------------------
		0x0, '', 0, 0,
		bi.[CompositionName],
		bi.[CompositionLatinName]
	FROM 
		[vwBillItems] bi 
		LEFT JOIN [mtdw000] dw ON bi.[MatPtr] = dw.MatGuid AND bi.Unity = (dw.NumUnit + 1)
	WHERE 
		
		bi.[MatType] = 0 -- ãÓÊæÏÚíÉ

	UPDATE #BillItems 
	SET 
		PackageGUID = pk.GUID, 
		PackageName = pk.Name, 
		PackageLatinName = pk.LatinName 
	FROM 
		(SELECT TOP 1 * FROM [Packages000] ORDER BY Number) pk

	UPDATE #BillItems
	SET [UnpackedQuantity] =plbi.[PackedQuantity]
	FROM 
		#BillItems bi
		INNER JOIN 
			(SELECT plb.BiGUID, SUM((plb.[ToPackage] - plb.[FromPackage] + 1) * plb.QuantityInPackage) AS [PackedQuantity] FROM #BillItems b INNER JOIN [dbo].[PackingListBis000] plb
				ON b.[ItemGUID] = plb.BiGUID GROUP BY plb.BiGUID) plbi ON bi.[ItemGUID] = plbi.BiGUID
	IF(@detailed = 1)
	BEGIN
	SELECT * FROM (
	SELECT 
		bi.[MatCode],
		bi.[MatName],
		bi.[MatLatinName],
		bi.[UnityName],

		(plbi.[ToPackage] - plbi.[FromPackage] + 1) * plbi.QuantityInPackage packedQuantity,
		plbi.FromPackage, 
		plbi.ToPackage, 
		plbi.QuantityInPackage,
		CASE WHEN ISNULL(plbi.Volume,0) =0 THEN ISNULL(plbi.[Length]*plbi.[Width]*plbi.[Height],0) ELSE  ISNULL(plbi.Volume,0) END * ISNULL(plbi.[ToPackage]-plbi.[FromPackage] + 1,0)  * ISNULL(plbi.QuantityInPackage ,0) *  dbo.fnPackingList_GetVolumeUnitFact(ISNULL(plbi.DimensionUnit, -1)) SumDim,
		ISNULL(plbi.[ToPackage]-plbi.[FromPackage] + 1,0) * ISNULL(plbi.QuantityInPackage ,0)* 	ISNULL(plbi.[GrossWeight],0) * dbo.fnPackingList_GetWeightUnitFact(ISNULL(plbi.WeightUnit, -1)) SumW,
			
		t.Abbrev,
		t.LatinAbbrev,
		bb.Number,
		cu.CustomerName,
		bi.[CompositionName],
		bi.[CompositionLatinName]
	FROM 
		#BillItems bi 
		INNER JOIN [dbo].[PackingListBis000] plbi ON bi.[ItemGUID] = plbi.BiGUID
		INNER JOIN [dbo].[PackingListsBills000] bu ON bu.[GUID] = plbi.ParentGUID
		INNER JOIN [dbo].[vbPackingLists] pl ON pl.[GUID] = bu.PackingListGUID
		INNER JOIN bu000 bb on bb.GUID =bu.BillGUID
		INNER JOIN bt000 t on bb.TypeGUID=t.GUID 
		INNER JOIN cu000 cu on cu.GUID=bb.CustGUID
	WHERE 
		pl.[GUID] = @PackingListGUID
		AND (@CustGuid = bb.CustGUID OR @CustGuid =0x0) 
		) as res
	ORDER BY 
			case WHEN @sort=1 THEN MatName END,
			case WHEN @sort=2 THEN packedQuantity END,
			case WHEN @sort=3 THEN CustomerName END,
			case When @sort=4 THEN Abbrev END
	END
	ELSE
	BEGIN
	select * from 
		(SELECT 
			[MatCode],
			[MatName],
			[MatLatinName],
			[UnityName],
			SUM(packedQuantity) packedQuantity,
			SUM(countx) countpackage,
			sum(QuantityInPackage) QuantityInPackage,
			Sum(SumDim) SumDim,
			Sum(Sumw) SumW
			FROM (SELECT 
						bi.[MatCode],
						bi.[MatName],
						bi.[MatLatinName],
						bi.[UnityName],

						(plbi.[ToPackage] - plbi.[FromPackage] + 1) * plbi.QuantityInPackage packedQuantity,
						(plbi.[ToPackage] - plbi.[FromPackage] + 1) countx,
						plbi.QuantityInPackage,
						CASE WHEN ISNULL(plbi.Volume,0) =0 THEN ISNULL(plbi.[Length]*plbi.[Width]*plbi.[Height],0) ELSE  ISNULL(plbi.Volume,0) END * ISNULL(plbi.[ToPackage]-plbi.[FromPackage] + 1,0)  * ISNULL(plbi.QuantityInPackage ,0) *  dbo.fnPackingList_GetVolumeUnitFact(ISNULL(plbi.DimensionUnit, -1)) SumDim,
			
			ISNULL(plbi.[ToPackage]-plbi.[FromPackage] + 1,0) * ISNULL(plbi.QuantityInPackage ,0)* 	ISNULL(plbi.[GrossWeight],0) * dbo.fnPackingList_GetWeightUnitFact(ISNULL(plbi.WeightUnit, -1)) SumW
			FROM 
					#BillItems bi 
					INNER JOIN [dbo].[PackingListBis000] plbi ON bi.[ItemGUID] = plbi.BiGUID
					INNER JOIN [dbo].[PackingListsBills000] bu ON bu.[GUID] = plbi.ParentGUID
					INNER JOIN [dbo].[vbPackingLists] pl ON pl.[GUID] = bu.PackingListGUID
					INNER JOIN bu000 bb ON bb.GUID =bu.BillGUID
					INNER JOIN bt000 t  ON bb.TypeGUID=t.GUID 
					INNER JOIN cu000 cu ON cu.GUID=bb.CustGUID
			WHERE 
				pl.[GUID] = @PackingListGUID
				AND (@CustGuid = bb.CustGUID OR @CustGuid =0x0) )AS res
		 GROUP BY
			[MatCode],
			[MatName],
			[MatLatinName],
			[UnityName])as res
	ORDER BY 
			case WHEN @sort=1 THEN MatName END,
			case WHEN @sort=2 THEN packedQuantity END
	END

	EXEC prcPL_GetSamePackagesCount @PackingListGUID
################################################################################
CREATE  PROCEDURE GetAllPackingListForBill
@BillGuid UNIQUEIDENTIFIER='4B48A3A4-36D6-4671-AD13-160DFB6D4992'
AS
	SET NOCOUNT ON
	
	SELECT 
		 Guid,
		 Number,
		 Date,
		 Code,
		 co_name,
		 co_LatinName,
		 Sum(SumDim) as SumDim,
		 Sum(SumW) as SumWe,
		 Sum(Countpk) SumCount,
	
		 VolumeUnit,
		 plWeightUnit
	FROM
		(SELECT 
			pl.GUID,
			pl.Number,
			pl.Code,
			pl.Date,
			ISNULL(co.name,'') co_name,
			ISNULL(co.LatinName,'') co_LatinName,	
			CASE WHEN ISNULL(plbi.Volume,0) =0 THEN ISNULL(plbi.[Length]*plbi.[Width]*plbi.[Height],0) ELSE  ISNULL(plbi.Volume,0) END * ISNULL(plbi.[ToPackage]-plbi.[FromPackage] + 1,0)  * ISNULL(plbi.QuantityInPackage ,0) *  dbo.fnPackingList_GetVolumeUnitFact(ISNULL(plbi.DimensionUnit, -1)) SumDim,
			
			ISNULL(plbi.[ToPackage]-plbi.[FromPackage] + 1,0) * ISNULL(plbi.QuantityInPackage ,0)* 	ISNULL(plbi.[GrossWeight],0) * dbo.fnPackingList_GetWeightUnitFact(ISNULL(plbi.WeightUnit, -1)) SumW,
			
			ISNULL(plbi.[ToPackage]-plbi.[FromPackage] + 1,0)  Countpk
			,pl.VolumeUnit
			,pl.WeightUnit plWeightUnit
		FROM 
			[dbo].[vbPackingLists] pl 
			INNER JOIN  [dbo].[PackingListsBills000] bu ON pl.[GUID] = bu.PackingListGUID AND bu.BillGUID=@BillGuid
			LEFT JOIN [dbo].[PackingListBis000] plbi ON   bu.[GUID] = plbi.ParentGUID
			LEFT JOIN [Containers000] co ON pl.ContainerGUID = co.[GUID] ) AS Res
		GROUP BY
				 Guid,
				 Number,
				 date,
				 Code,
				 co_name,
				 co_LatinName,
				
				 VolumeUnit,
				 plWeightUnit
		ORDER BY number

	SELECT ISNULL(Sum(sumq)-(select sum(CASE Bi.Unity	WHEN 1 THEN (Bi.Qty+Bi.BonusQnt)    
											WHEN 2 THEN ((Bi.Qty+Bi.BonusQnt)/[Unit2Fact])      
											WHEN 3 THEN ((Bi.Qty+Bi.BonusQnt)/[Unit3Fact])   
							END)  from bi000 bi 
		inner join mt000 mt on bi.MatGUID = mt.guid
				where bi.ParentGUID = @BillGuid),1) as stateq
					FROM(SELECT  pkbi.QuantityInPackage*((ToPackage-FromPackage)+1)as sumq,
									Pk.BillGUID ,
									pk.PackingListGUID,
									pkbi.BiGuid
					    FROM PackingListsBills000  Pk
							INNER JOIN packingListBis000 pkbi ON pkbi.ParentGUID=pk.GUID and pk.BillGUID=@BillGuid
							)as res

###################################################################################
CREATE PROCEDURE prc_GetAllitemBillPk
@BillGuid UNIQUEIDENTIFIER='4B48A3A4-36D6-4671-AD13-160DFB6D4992'
AS
	SET NOCOUNT ON
	SELECT 
	Code,
	Name,
	LatinName,
	Unity,
	SUM(packedQuantity) packedQuantity,
	qty
	FROM(
		SELECT 
			mt.Code,
			mt.Name,
			mt.LatinName,
			case when  bi.Unity = 1 then mt.Unity when bi.Unity = 2 then mt.Unit2 else mt.Unit3 end as Unity,
			(plbi.[ToPackage] - plbi.[FromPackage] + 1) * plbi.QuantityInPackage packedQuantity,
			(CASE Bi.Unity	WHEN 1 THEN (Bi.Qty+Bi.BonusQnt)    
							WHEN 2 THEN ((Bi.Qty+Bi.BonusQnt)/[Unit2Fact])      
							WHEN 3 THEN ((Bi.Qty+Bi.BonusQnt)/[Unit3Fact]) END)  as qty 
		FROM 
			bi000  bi
			INNER JOIN [dbo].[PackingListBis000] plbi ON bi.GUID= plbi.BiGUID
			INNER JOIN [dbo].[PackingListsBills000] bu ON bu.[GUID] = plbi.ParentGUID
			INNER JOIN [dbo].[vbPackingLists] pl ON pl.[GUID] = bu.PackingListGUID
			INNER JOIN mt000 mt ON mt.guid =bi.MatGUID
		WHERE 
			bu.BillGUID=@BillGuid
		)AS res

		GROUP BY 
				Code,
				Name,
				LatinName,
				Unity,
				qty
###################################################################################
CREATE PROCEDURE prc_FilledMaterials
@Bill UNIQUEIDENTIFIER
AS
	SET NOCOUNT ON

	CREATE TABLE #BillItems(
		ItemGUID UNIQUEIDENTIFIER, 
		[ItemNumber] INT, 
		[MatGUID] UNIQUEIDENTIFIER,
		[MatCode] NVARCHAR(250), 
		[MatName] NVARCHAR(250), 
		[MatLatinName] NVARCHAR(250),
		[UnityName] NVARCHAR(250), 
		[ItemQty] FLOAT, 
		[ItemBonusQnt] FLOAT, 
		-----------------
		[UnpackedQuantity] FLOAT,
		FromPackage INT, 
		ToPackage INT, 
		QuantityInPackage FLOAT,
		PackageGUID UNIQUEIDENTIFIER, 
		PackageName NVARCHAR(250), 
		PackageLatinName NVARCHAR(250),
		-----------------
		-- DefaultDimensionUnit INT, 
		[DefaultLength] FLOAT, [DefaultWidth] FLOAT, [DefaultHeight] FLOAT, 
		-- DefaultWeightUnit INT, 
		[DefaultGrossWeight] FLOAT, [DefaultNetWeight] FLOAT, [DefaultDrainedWeight] FLOAT, 
		-----------------
		DimensionUnit INT, [Length] FLOAT, [Width] FLOAT, [Height] FLOAT, Volume FLOAT,
		WeightUnit INT, [GrossWeight] FLOAT, [NetWeight] FLOAT, [DrainedWeight] FLOAT, 
		-----------------
		[PackageListItemGUID] UNIQUEIDENTIFIER,
		[Notes] NVARCHAR(500), 
		[PackagedNumber] INT, 
		IsPacked [BIT])

	INSERT INTO #BillItems
	SELECT 
		bi.GUID,
		bi.[ItemNumber],
		bi.[MatPtr],
		bi.[MatCode],
		bi.[MatName],
		bi.[LatinName],
		bi.[UnityName],
		bi.[Qty],
		bi.[BonusQnt],
		--------------------------------------
		bi.[Qty] + bi.[BonusQnt], 0, 0, 0, 
		0x0, '', '',
		--------------------------------------
		-- ISNULL(dw.Dimension, 0), 
		ISNULL(dw.UnitLength, 0), ISNULL(dw.UnitWidth, 0), ISNULL(dw.Unitheight, 0),
		-- ISNULL(dw.[Weight], 0), 
		ISNULL(dw.UnitGrossWeight, 0), ISNULL(dw.UnitNetWeight, 0), ISNULL(dw.UnitDrainedWeight, 0),
		--------------------------------------
		ISNULL(dw.Dimension, 0), ISNULL(dw.UnitLength, 0), ISNULL(dw.UnitWidth, 0), ISNULL(dw.Unitheight, 0), 0, 
		ISNULL(dw.[Weight], 0), ISNULL(dw.UnitGrossWeight, 0), ISNULL(dw.UnitNetWeight, 0), ISNULL(dw.UnitDrainedWeight, 0),
		--------------------------------------
		0x0, '', 0, 0
	FROM 
		[vwBillItems] bi 
		LEFT JOIN [mtdw000] dw ON bi.[MatPtr] = dw.MatGuid AND bi.Unity = (dw.NumUnit + 1)
	WHERE 
		
		bi.[MatType] = 0 -- ãÓÊæÏÚíÉ

	UPDATE #BillItems 
	SET 
		PackageGUID = pk.GUID, 
		PackageName = pk.Name, 
		PackageLatinName = pk.LatinName 
	FROM 
		(SELECT TOP 1 * FROM [Packages000] ORDER BY Number) pk

	UPDATE #BillItems
	SET [UnpackedQuantity] =plbi.[PackedQuantity]
	FROM 
		#BillItems bi
		INNER JOIN 
			(SELECT plb.BiGUID, SUM((plb.[ToPackage] - plb.[FromPackage] + 1) * plb.QuantityInPackage) AS [PackedQuantity] FROM #BillItems b INNER JOIN [dbo].[PackingListBis000] plb
				ON b.[ItemGUID] = plb.BiGUID GROUP BY plb.BiGUID) plbi ON bi.[ItemGUID] = plbi.BiGUID

	--select * from [PackingListsBills000]
		SELECT 
			plGuid,
			Number,
			MatCode,
			MatGUID,
			[MtName],
			[MatLatinName],
			[UnityName],
			SUM(packedQuantity) packedQuantity,
			SUM(countx) countpackage,
			sum(QuantityInPackage) QuantityInPackage,
			Sum(SumDim)  SumDim,
			Sum(Sumw) SumW,
			VolumeUnit,
			WeightUnit,
			FromPackage,
			ToPackage
			FROM (SELECT
						pl.guid plGuid,
						pl.Number,
						bi.MatCode,
						bi.MatGUID,
						bi.[MatName] as MtName,
						bi.[MatLatinName],
						bi.[UnityName],
						pl.VolumeUnit,
						pl.WeightUnit,
						(plbi.[ToPackage] - plbi.[FromPackage] + 1) * plbi.QuantityInPackage packedQuantity,
						(plbi.[ToPackage] - plbi.[FromPackage] + 1) countx,
						plbi.QuantityInPackage,
						(CASE WHEN ISNULL(plbi.Volume,0) =0 THEN ISNULL(plbi.[Length]*plbi.[Width]*plbi.[Height],0) ELSE  ISNULL(plbi.Volume,0) END * ISNULL(plbi.[ToPackage]-plbi.[FromPackage] + 1,0)  * ISNULL(plbi.QuantityInPackage ,0) *  dbo.fnPackingList_GetVolumeUnitFact(ISNULL(plbi.DimensionUnit, -1)) ) SumDim,
			
						(ISNULL(plbi.[ToPackage]-plbi.[FromPackage] + 1,0) * ISNULL(plbi.QuantityInPackage ,0)* 	ISNULL(plbi.[GrossWeight],0) * dbo.fnPackingList_GetWeightUnitFact(ISNULL(plbi.WeightUnit, -1)) ) SumW,
						plbi.FromPackage, 
						plbi.ToPackage 
						
			FROM 
					#BillItems bi 
					INNER JOIN [dbo].[PackingListBis000] plbi ON bi.[ItemGUID] = plbi.BiGUID
					INNER JOIN [dbo].[PackingListsBills000] bu ON bu.[GUID] = plbi.ParentGUID
					INNER JOIN [dbo].[vbPackingLists] pl ON pl.[GUID] = bu.PackingListGUID
					INNER JOIN bu000 bb ON bb.GUID =bu.BillGUID
			WHERE 
				 bu.BillGUID=@Bill)AS res
		 GROUP BY
		 plGuid,
			Number,
			MatGUID,
			[MtName],
			[MatLatinName],
			[UnityName],
			FromPackage,
			ToPackage,
			MatCode,
			VolumeUnit,
			WeightUnit

	ORDER BY 
			Number,
			MtName
###################################################################################
CREATE FUNCTION getCountContainerWeight(@pk UNIQUEIDENTIFIER)
RETURNS int   
AS 
BEGIN 
	DECLARE @count int=0,@From INT,@To INT,@pag UNIQUEIDENTIFIER
	DECLARE @TempPk TABLE(number int,pag UNIQUEIDENTIFIER)
	DECLARE db_PK CURSOR FOR  SELECT
		DISTINCT
			plbi.[FromPackage] ,
			plbi.[ToPackage] ,
			plbi.PackageGUID 
		FROM 
			[dbo].[vbPackingLists] pl
			INNER JOIN [dbo].[PackingListsBills000] bu ON pl.[GUID] = bu.PackingListGUID
		    INNER JOIN [dbo].[PackingListBis000] plbi  ON bu.[GUID] = plbi.ParentGUID
		WHERE pl.GUID=@pk  and 1=(select 1 from Packages000 p where guid=plbi.PackageGUID)
	
	OPEN db_PK   
	FETCH NEXT FROM db_PK INTO @From,@To,@pag  
	
	WHILE @@FETCH_STATUS = 0   
	BEGIN   
		   WHILE @From <= @To
		   BEGIN
			IF(NOT EXISTS (SELECT * FROM @TempPk WHERE number=@From and pag=@pag) )
				INSERT INTO @TempPk(number,pag) SELECT @From,@pag
				SET @From+=1;
		   END
		 FETCH NEXT FROM db_PK INTO  @From,@To,@pag  
	END   
	CLOSE db_PK   
	DEALLOCATE db_PK

	SET @count=ISNULL((select sum(countx*Weight2* dbo.fnPackingList_GetWeightUnitFact(ISNULL(WeightUnit2, -1))) from (SELECT count(*) countx,pag from @TempPk
	group by pag) as res inner join Packages000 on  pag=guid),0)

	return @count;
END
###################################################################################
CREATE FUNCTION getCountPk(@Guid UNIQUEIDENTIFIER)
RETURNS INT   
AS 
BEGIN 
	DECLARE @count int=0,@From INT,@To INT
	DECLARE @TempPk TABLE(number int)
	DECLARE db_PK CURSOR FOR  SELECT
		DISTINCT
			plbi.[FromPackage] ,
			plbi.[ToPackage]  
		FROM 
			[dbo].[vbPackingLists] pl
			INNER JOIN [dbo].[PackingListsBills000] bu ON pl.[GUID] = bu.PackingListGUID
		    INNER JOIN [dbo].[PackingListBis000] plbi  ON bu.[GUID] = plbi.ParentGUID
		WHERE pl.GUID=@Guid
	
	OPEN db_PK   
	FETCH NEXT FROM db_PK INTO @From,@To  
	
	WHILE @@FETCH_STATUS = 0   
	BEGIN   
		   WHILE @From <= @To
		   BEGIN
			IF(NOT EXISTS (SELECT * FROM @TempPk WHERE number=@From) )
				INSERT INTO @TempPk(number) SELECT @From
				SET @From+=1;
		   END
		 FETCH NEXT FROM db_PK INTO  @From,@To  
	END   
	CLOSE db_PK   
	DEALLOCATE db_PK

	SET @count=(select count(*) FROM @TempPk)
	RETURN @count;
END
###################################################################################
CREATE FUNCTION getCountContainerVolume(@pk UNIQUEIDENTIFIER)
RETURNS int   
AS 
BEGIN 
	DECLARE @count int=0,@From INT,@To INT,@pag UNIQUEIDENTIFIER
	DECLARE @TempPk TABLE(number int,pag UNIQUEIDENTIFIER)
	DECLARE db_PK CURSOR FOR  SELECT
		distinct
			plbi.[FromPackage] ,
			plbi.[ToPackage] ,
			plbi.PackageGUID 
		FROM 
			[dbo].[vbPackingLists] pl
			INNER JOIN [dbo].[PackingListsBills000] bu ON pl.[GUID] = bu.PackingListGUID
		    INNER JOIN [dbo].[PackingListBis000] plbi  ON bu.[GUID] = plbi.ParentGUID
		where pl.GUID=@pk  and 1=(select 1 from Packages000 p where guid=plbi.PackageGUID and p.FromPackage=0)
	
	OPEN db_PK   
	FETCH NEXT FROM db_PK INTO @From,@To,@pag  
	
	WHILE @@FETCH_STATUS = 0   
	BEGIN   
		   WHILE @From <= @To
		   BEGIN
			IF(NOT EXISTS (SELECT * FROM @TempPk WHERE number=@From and pag=@pag) )
				INSERT INTO @TempPk(number,pag) SELECT @From,@pag
				SET @From+=1;
		   END
		 FETCH NEXT FROM db_PK INTO  @From,@To,@pag  
	END   
	CLOSE db_PK   
	DEALLOCATE db_PK

	SET @count=ISNULL((select sum(countx*Volume* dbo.fnPackingList_GetVolumeUnitFact(ISNULL(Volume, -1))) from (SELECT count(*) countx,pag from @TempPk
	group by pag) as res INNER JOIN Packages000 on  pag=guid),0)

	return @count;
END
###################################################################################
CREATE FUNCTION fnGetBillState(@BillGuid UNIQUEIDENTIFIER)
RETURNS INT
AS 
BEGIN
DECLARE @quantity INT

SET  @quantity= (SELECT ISNULL(Sum(sumq)-(select sum(CASE Bi.Unity	WHEN 1 THEN (Bi.Qty+Bi.BonusQnt)    
											WHEN 2 THEN ((Bi.Qty+Bi.BonusQnt)/[Unit2Fact])      
											WHEN 3 THEN ((Bi.Qty+Bi.BonusQnt)/[Unit3Fact])   
							END)  from bi000 bi 
		inner join mt000 mt on bi.MatGUID = mt.guid
				where bi.ParentGUID = @BillGuid),1) as stateq
					FROM(SELECT  pkbi.QuantityInPackage*((ToPackage-FromPackage)+1)as sumq,
									Pk.BillGUID ,
									pk.PackingListGUID,
									pkbi.BiGuid
					    FROM PackingListsBills000  Pk
							INNER JOIN packingListBis000 pkbi ON pkbi.ParentGUID=pk.GUID and pk.BillGUID=@BillGuid
							)as res)
	RETURN 	@quantity						
END
###################################################################################
CREATE PROCEDURE PrcCustomerPackingList
	@CustGuid UNIQUEIDENTIFIER,
	@ptBill UNIQUEIDENTIFIER,
	@buNumber INT,
	@pkNumberFrom INT,
	@pkNumberTo INT,
	@CondGuid UNIQUEIDENTIFIER ,
	@FromDate DATETIME,
	@ToDate	  DATETIME,
	@stateUnpacked INT,
	@statePacked INT,
	@statePart INT

AS
	SET NOCOUNT ON 

	CREATE TABLE #Pk(PkGuid UNIQUEIDENTIFIER)
	INSERT INTO #Pk EXEC prcPackingsList @CondGuid 
		
	DECLARE  @UserGUID UNIQUEIDENTIFIER
	SET @UserGUID = [dbo].[fnGetCurrentUserGUID]()

	CREATE TABLE [#BillTbl]( [Type] UNIQUEIDENTIFIER, [Security] INT, [ReadPriceSecurity] INT)
	INSERT INTO [#BillTbl] EXEC [prcGetBillsTypesList] @ptBill, @UserGUID  

	CREATE TABLE #BillItems(
		ItemGUID UNIQUEIDENTIFIER, 
		[ItemNumber] INT, 
		[MatGUID] UNIQUEIDENTIFIER,
		[MatCode] NVARCHAR(250), 
		[MatName] NVARCHAR(250), 
		[MatLatinName] NVARCHAR(250),
		[UnityName] NVARCHAR(250), 
		[ItemQty] FLOAT, 
		[ItemBonusQnt] FLOAT, 
		-----------------
		[UnpackedQuantity] FLOAT,
		FromPackage INT, 
		ToPackage INT, 
		QuantityInPackage FLOAT,
		PackageGUID UNIQUEIDENTIFIER, 
		PackageName NVARCHAR(250), 
		PackageLatinName NVARCHAR(250),
		-----------------
		-- DefaultDimensionUnit INT, 
		[DefaultLength] FLOAT, [DefaultWidth] FLOAT, [DefaultHeight] FLOAT, 
		-- DefaultWeightUnit INT, 
		[DefaultGrossWeight] FLOAT, [DefaultNetWeight] FLOAT, [DefaultDrainedWeight] FLOAT, 
		-----------------
		DimensionUnit INT, [Length] FLOAT, [Width] FLOAT, [Height] FLOAT, Volume FLOAT,
		WeightUnit INT, [GrossWeight] FLOAT, [NetWeight] FLOAT, [DrainedWeight] FLOAT, 
		-----------------
		[PackageListItemGUID] UNIQUEIDENTIFIER,
		[Notes] NVARCHAR(500), 
		[PackagedNumber] INT, 
		IsPacked [BIT])


	INSERT INTO #BillItems
	SELECT 
		bi.GUID,
		bi.[ItemNumber],
		bi.[MatPtr],
		bi.[MatCode],
		bi.[MatName],
		bi.[LatinName],
		bi.[UnityName],
		bi.[Qty],
		bi.[BonusQnt],
		--------------------------------------
		bi.[Qty] + bi.[BonusQnt], 0, 0, 0, 
		0x0, '', '',
		--------------------------------------
		-- ISNULL(dw.Dimension, 0), 
		ISNULL(dw.UnitLength, 0), ISNULL(dw.UnitWidth, 0), ISNULL(dw.Unitheight, 0),
		-- ISNULL(dw.[Weight], 0), 
		ISNULL(dw.UnitGrossWeight, 0), ISNULL(dw.UnitNetWeight, 0), ISNULL(dw.UnitDrainedWeight, 0),
		--------------------------------------
		ISNULL(dw.Dimension, 0), ISNULL(dw.UnitLength, 0), ISNULL(dw.UnitWidth, 0), ISNULL(dw.Unitheight, 0), 0, 
		ISNULL(dw.[Weight], 0), ISNULL(dw.UnitGrossWeight, 0), ISNULL(dw.UnitNetWeight, 0), ISNULL(dw.UnitDrainedWeight, 0),
		--------------------------------------
		0x0, '', 0, 0
	FROM 
		[vwBillItems] bi 
		LEFT JOIN [mtdw000] dw ON bi.[MatPtr] = dw.MatGuid AND bi.Unity = (dw.NumUnit + 1)
	WHERE 
		
		bi.[MatType] = 0 -- ãÓÊæÏÚíÉ

	UPDATE #BillItems 
	SET 
		PackageGUID = pk.GUID, 
		PackageName = pk.Name, 
		PackageLatinName = pk.LatinName 
	FROM 
		(SELECT TOP 1 * FROM [Packages000] ORDER BY Number) pk

	UPDATE #BillItems
	SET [UnpackedQuantity] =plbi.[PackedQuantity]
	FROM 
		#BillItems bi
		INNER JOIN 
			(SELECT plb.BiGUID, SUM((plb.[ToPackage] - plb.[FromPackage] + 1) * plb.QuantityInPackage) AS [PackedQuantity] FROM #BillItems b INNER JOIN [dbo].[PackingListBis000] plb
				ON b.[ItemGUID] = plb.BiGUID GROUP BY plb.BiGUID) plbi ON bi.[ItemGUID] = plbi.BiGUID

	SELECT 
		plNumber,
		plCode,
		plGuid,
		pldate,
		plNotes,
		brguid,
		brn,
		brl,
		ISNULL(contGuid,0x0) contGuid,
		ContName,
		contLatine,
		Volume,
		VolumeUnit,
		Weight,
		WeightUnit,
		Sum(SumDim) SumDim,
		SUM(SumW)	SumW,
		Sum(packedQuantity) packedQuantity,
		dbo.getCountPk(plGuid)  countpackage,
		dbo.getCountContainerWeight(plguid)+SUM(SumW) as mysumW,
		(SELECT SUM(BillVolume) FROM PackingListsBills000 WHERE PackingListGUID = plguid) as myDim 
		into #resultPk
	FROM 
		(SELECT
			pl.Number plnumber,
			pl.Code plCode,
			pl.Guid plguid,
			pl.Date pldate,
			pl.Notes AS plNotes,
			pl.Branch brguid,
			br.Name AS brn,
			br.LatinName AS brl,
			cont.GUID contGuid,
			cont.Name AS ContName,
			cont.LatinName AS contLatine,
			pl.Volume,
			pl.VolumeUnit,
			pl.Weight,
			pl.WeightUnit,
			(CASE WHEN ISNULL(plbi.Volume,0) =0 THEN ISNULL(plbi.[Length]*plbi.[Width]*plbi.[Height],0) ELSE  ISNULL(plbi.Volume,0) END * ISNULL(plbi.[ToPackage]-plbi.[FromPackage] + 1,0)  * ISNULL(plbi.QuantityInPackage ,0) *  dbo.fnPackingList_GetVolumeUnitFact(ISNULL(plbi.DimensionUnit, -1)) )SumDim,
			(ISNULL(plbi.[ToPackage]-plbi.[FromPackage] + 1,0) * ISNULL(plbi.QuantityInPackage ,0)* 	ISNULL(plbi.[GrossWeight],0) * dbo.fnPackingList_GetWeightUnitFact(ISNULL(plbi.WeightUnit, -1)) )SumW,
			(plbi.[ToPackage] - plbi.[FromPackage] + 1) * plbi.QuantityInPackage packedQuantity,
			(CASE WHEN ISNULL(plbi.Volume,0) =0 THEN ISNULL(plbi.[Length]*plbi.[Width]*plbi.[Height],0) ELSE  ISNULL(plbi.Volume,0) END * ISNULL(plbi.[ToPackage]-plbi.[FromPackage] + 1,0)  * ISNULL(plbi.QuantityInPackage ,0) *  dbo.fnPackingList_GetVolumeUnitFact(ISNULL(plbi.DimensionUnit, -1)) )*(CASE WHEN pag.FromPackage = 0 THEN 0 ELSE 1 END) SumDimD
			
		FROM 
			[dbo].[vbPackingLists] pl
			LEFT JOIN [dbo].[PackingListsBills000] bu ON pl.[GUID] = bu.PackingListGUID
		    LEFT JOIN [dbo].[PackingListBis000] plbi  ON bu.[GUID] = plbi.ParentGUID
			Left Join Packages000 pag on pag.GUID=plbi.PackageGUID
			LEFT JOIN #BillItems bi ON bi.[ItemGUID] = plbi.BiGUID	
			LEFT JOIN bu000 bb on bb.GUID =bu.BillGUID
			LEFT JOIN bt000 t on bb.TypeGUID=t.GUID 
			LEFT JOIN Containers000 cont on cont.GUID = pl.ContainerGUID  
			LEFT JOIN br000 br on br.GUID= pl.Branch 
		WHERE 
			pl.[GUID] in (select pkGuid from #Pk)
			AND (@CustGuid = bb.CustGUID OR @CustGuid =0x0)  
			AND (t.GUID in(select type from [#BillTbl] ) or @ptBill =0x0)
			AND (pl.Number >= @pkNumberFrom )
			AND (pl.Number <= @pkNumberTo or @pkNumberTo = 0)
			AND (bb.Number = @buNumber or @buNumber =0)
			AND (pl.Date BETWEEN @FromDate AND @ToDate)
	
		)AS res
	GROUP BY 
		plnumber,
		plCode,
		plguid,
		pldate,
		brguid,
		brn,
		brl,
		contGuid,
		ContName,
		contLatine,
		Volume,
		VolumeUnit,
		Weight,
		WeightUnit,
		plNotes

		SELECT 
			Number,
			plGuid,
			MatCode,
			ISNULL(MatGUID,0x0) MatGUID,
			[MtName],
			[MatLatinName],
			[UnityName],
			SUM(packedQuantity) packedQuantity,
			SUM(countx) countpackage,
			sum(QuantityInPackage) QuantityInPackage,
			Sum(SumDim)  SumDim,
			Sum(Sumw) SumW,
			VolumeUnit,
			WeightUnit,
			FromPackage,
			ToPackage,
			CustomerName as CuName,
			LatinName,
			cuGuid,
			AbbrevBill,
			LatinAbbrevBill,
			NumberBill,
			BillGUID,
			pgname,
			pgLatinName,
			pgVolume,
			pgVolumeUnit,
			pgWeight2,
			pgWeightUnit2,
			IsFromPackage,
			BillStateFlag
			into #resultBill
			FROM (SELECT 
						pl.GUID plGuid,
						pl.Number,
						bi.MatCode,
						bi.MatGUID,
						bi.[MatName] as MtName,
						bi.[MatLatinName],
						t.Abbrev AbbrevBill,
						t.LatinAbbrev LatinAbbrevBill,
						bb.Number NumberBill,
						bi.[UnityName],
						pl.VolumeUnit,
						pl.WeightUnit,
						ISNULL((plbi.[ToPackage] - plbi.[FromPackage] + 1) * plbi.QuantityInPackage ,0)packedQuantity,
						ISNULL((plbi.[ToPackage] - plbi.[FromPackage] + 1) ,0)countx,
						ISNULL(plbi.QuantityInPackage,0) QuantityInPackage,
						(CASE WHEN ISNULL(plbi.Volume,0) =0 THEN ISNULL(plbi.[Length]*plbi.[Width]*plbi.[Height],0) ELSE  ISNULL(plbi.Volume,0) END * ISNULL(plbi.[ToPackage]-plbi.[FromPackage] + 1,0)  * ISNULL(plbi.QuantityInPackage ,0) *  dbo.fnPackingList_GetVolumeUnitFact(ISNULL(plbi.DimensionUnit, -1)) ) SumDim,
			
						(ISNULL(plbi.[ToPackage]-plbi.[FromPackage] + 1,0) * ISNULL(plbi.QuantityInPackage ,0)* 	ISNULL(plbi.[GrossWeight],0) * dbo.fnPackingList_GetWeightUnitFact(ISNULL(plbi.WeightUnit, -1)) ) SumW,
						ISNULL(plbi.FromPackage,0) FromPackage, 
						ISNULL(plbi.ToPackage,0) ToPackage,
						cu.CustomerName,
						cu.LatinName,
						cu.GUID cuGuid,
						bu.BillGUID,
						pg.Name AS pgname,
						pg.LatinName AS pgLatinName,
						ISNULL(pg.Volume,0) pgVolume,
						ISNULL(pg.VolumeUnit,0) pgVolumeUnit,
						ISNULL(pg.Weight2,0) pgWeight2,
						ISNULL(pg.WeightUnit2,0) pgWeightUnit2,
						ISNULL(pg.FromPackage,0) IsFromPackage,
						dbo.fnGetBillState(BillGUID) as BillStateFlag		
			FROM 
			[dbo].[PackingListsBills000] bu LEFT JOIN  [dbo].[PackingListBis000] plbi ON  bu.[GUID] = plbi.ParentGUID
				LEFT JOIN	#BillItems bi 
					  ON bi.[ItemGUID] = plbi.BiGUID
					LEFT JOIN [Packages000] pg on pg.GUID=plbi.PackageGUID
					INNER JOIN [dbo].[vbPackingLists] pl ON pl.[GUID] = bu.PackingListGUID
					INNER JOIN bu000 bb ON bb.GUID =bu.BillGUID
					INNER JOIN cu000 cu ON cu.GUID= bb.CustGUID
					INNER JOIN bt000 t on bb.TypeGUID=t.GUID 
			WHERE 
			pl.[GUID] in (select pkGuid from #Pk)
			AND (@CustGuid = bb.CustGUID OR @CustGuid =0x0)  
			AND (t.GUID in(select type from [#BillTbl] ) or @ptBill =0x0)
			AND (pl.Number >= @pkNumberFrom )
			AND (pl.Number <= @pkNumberTo or @pkNumberTo = 0)
			AND (bb.Number = @buNumber or @buNumber =0)
			AND (pl.Date BETWEEN @FromDate AND @ToDate)			
			)AS res
			WHERE	  
					  (@statePacked=1 AND (BillStateFlag=0)) 
					OR(@statePart=1 AND (BillStateFlag < 0))
					OR(@stateUnpacked=1 AND (BillStateFlag = 1))
						
						  
		 GROUP BY
			Number,
			MatGUID,
			[MtName],
			[MatLatinName],
			[UnityName],
			FromPackage,
			ToPackage,
			MatCode,
			VolumeUnit,
			WeightUnit,
			CustomerName,
			LatinName,
			cuGuid,
			plGuid,
			AbbrevBill,
			LatinAbbrevBill,
			NumberBill,
			BillGUID,
			pgname,
			pgLatinName,
			pgVolume,
			pgVolumeUnit,
			pgWeight2,
			pgWeightUnit2,
			IsFromPackage,
			BillStateFlag
	ORDER BY 
			cuGuid,
			Number,
			MtName


	IF  @stateUnpacked = 1 AND 
		@statePacked = 1 AND 
		@statePart = 1
	BEGIN
		SELECT  * From #resultPk
	END
	ELSE 
	BEGIN 
		SELECT  * From #resultPk k
		 WHERE EXISTS (select plguid from #resultBill b where b.plGuid=k.plguid)
	END 

	SELECT * FROM #resultBill
###################################################################################
CREATE PROC Prc_Packing_planogram
@pk UNIQUEIDENTIFIER='0F58D909-90B6-4C27-88F2-AAB031B1DE05'
AS
	SET NOCOUNT ON 

	DECLARE @FromPackage INT,
			@ToPackage	 INT

	SELECT 
		   @FromPackage=Min(FromPackage),
		   @ToPackage=Max(ToPackage) 
	FROM 
			PackingListsBills000 bill INNER JOIN 
			PackingListBis000 bi ON bill.GUID=bi.ParentGUID
	WHERE bill.PackingListGUID = @pk


	CREATE TABLE #BillItems(
		ItemGUID UNIQUEIDENTIFIER, 
		[ItemNumber] INT, 
		[MatGUID] UNIQUEIDENTIFIER,
		[MatCode] NVARCHAR(250), 
		[MatName] NVARCHAR(250), 
		[MatLatinName] NVARCHAR(250),
		[UnityName] NVARCHAR(250) COLLATE Arabic_CI_AI, 
		[ItemQty] FLOAT, 
		[ItemBonusQnt] FLOAT, 
		-----------------
		[UnpackedQuantity] FLOAT,
		FromPackage INT, 
		ToPackage INT, 
		QuantityInPackage FLOAT,
		PackageGUID UNIQUEIDENTIFIER, 
		PackageName NVARCHAR(250), 
		PackageLatinName NVARCHAR(250),
		-----------------
		-- DefaultDimensionUnit INT, 
		[DefaultLength] FLOAT, [DefaultWidth] FLOAT, [DefaultHeight] FLOAT, 
		-- DefaultWeightUnit INT, 
		[DefaultGrossWeight] FLOAT, [DefaultNetWeight] FLOAT, [DefaultDrainedWeight] FLOAT, 
		-----------------
		DimensionUnit INT, [Length] FLOAT, [Width] FLOAT, [Height] FLOAT, Volume FLOAT,
		WeightUnit INT, [GrossWeight] FLOAT, [NetWeight] FLOAT, [DrainedWeight] FLOAT, 
		-----------------
		[PackageListItemGUID] UNIQUEIDENTIFIER,
		[Notes] NVARCHAR(500), 
		[PackagedNumber] INT, 
		IsPacked [BIT])


	INSERT INTO #BillItems
	SELECT 
		bi.GUID,
		bi.[ItemNumber],
		bi.[MatPtr],
		bi.[MatCode],
		bi.[MatName],
		bi.[LatinName],
		bi.UnityName,
		bi.[Qty],
		bi.[BonusQnt],
		--------------------------------------
		bi.[Qty] + bi.[BonusQnt], 0, 0, 0, 
		0x0, '', '',
		--------------------------------------
		-- ISNULL(dw.Dimension, 0), 
		ISNULL(dw.UnitLength, 0), ISNULL(dw.UnitWidth, 0), ISNULL(dw.Unitheight, 0),
		-- ISNULL(dw.[Weight], 0), 
		ISNULL(dw.UnitGrossWeight, 0), ISNULL(dw.UnitNetWeight, 0), ISNULL(dw.UnitDrainedWeight, 0),
		--------------------------------------
		ISNULL(dw.Dimension, 0), ISNULL(dw.UnitLength, 0), ISNULL(dw.UnitWidth, 0), ISNULL(dw.Unitheight, 0), 0, 
		ISNULL(dw.[Weight], 0), ISNULL(dw.UnitGrossWeight, 0), ISNULL(dw.UnitNetWeight, 0), ISNULL(dw.UnitDrainedWeight, 0),
		--------------------------------------
		0x0, '', 0, 0
	FROM 
		[vwBillItems] bi 
		LEFT JOIN [mtdw000] dw ON bi.[MatPtr] = dw.MatGuid AND bi.Unity = (dw.NumUnit + 1)
	WHERE 
		
		bi.[MatType] = 0 -- ãÓÊæÏÚíÉ

	UPDATE #BillItems 
	SET 
		PackageGUID = pk.GUID, 
		PackageName = pk.Name, 
		PackageLatinName = pk.LatinName 
	FROM 
		(SELECT TOP 1 * FROM [Packages000] ORDER BY Number) pk

	UPDATE #BillItems
	SET [UnpackedQuantity] =plbi.[PackedQuantity]
	FROM 
		#BillItems bi
		INNER JOIN 
			(SELECT plb.BiGUID, SUM((plb.[ToPackage] - plb.[FromPackage] + 1) * plb.QuantityInPackage) AS [PackedQuantity] FROM #BillItems b INNER JOIN [dbo].[PackingListBis000] plb
				ON b.[ItemGUID] = plb.BiGUID GROUP BY plb.BiGUID) plbi ON bi.[ItemGUID] = plbi.BiGUID

		
		CREATE 
		TABLE #result
			(
				MatGUID UNIQUEIDENTIFIER,
				MtName NVARCHAR(250),
				[MatLatinName] NVARCHAR(250),
				pName NVARCHAR(250),
				pLatinName NVARCHAR(250),
				pVolume FLOAT,
				pWeight FLOAT,
				pVolumeUnit INT,
				pWeightUnit INT,
				QuantityInPackage FLOAT,
				SumDim FLOAT,
				SumW FLOAT,
				CustomerName NVARCHAR(250),
				cLatinName NVARCHAR(250),
				cuGuid UNIQUEIDENTIFIER,
				PkID INT,
				qtyPk FLOAT,
				pW2 FLOAT,
				PW2U INT
			)
	WHILE (@FromPackage <=@ToPackage)
	BEGIN

	INSERT INTO #result
		SELECT 
				MatGUID,
				MtName + ' ' + CompositionName + ' ' + unitname,
				[MatLatinName] + ' ' + CompositionLatinName + ' ' + unitname,
				pName,
				pLatinName,
				pVolume,
				pWeight,
				pVolumeUnit,
				pWeightUnit,
				Sum(QuantityInPackage),
				Sum(SumDim),
				Sum(SumW),
				CustomerName,
				cLatinName,
				cuGuid,
				PkID,
				
				SUM(CASE DefUnit 
							WHEN 1 THEN qty
							WHEN 2 THEN qty2
							WHEN 3 THEN qty3 
						END ) ,
				Weight2,
				WeightUnit2

			FROM(

				SELECT 
						bi.MatGUID,
						bi.[MatName] as MtName,
						bi.[MatLatinName],
						p.Name pName,
						p.LatinName pLatinName,
						p.Volume pVolume,
						p.Weight pWeight,
						p.VolumeUnit pVolumeUnit,
						p.WeightUnit pWeightUnit,
						plbi.QuantityInPackage,
						(CASE WHEN ISNULL(plbi.Volume,0) =0 THEN ISNULL(plbi.[Length]*plbi.[Width]*plbi.[Height],0) ELSE  ISNULL(plbi.Volume,0) END   * ISNULL(plbi.QuantityInPackage ,0) *  dbo.fnPackingList_GetVolumeUnitFact(ISNULL(plbi.DimensionUnit, -1)) ) SumDim,
						(ISNULL(plbi.QuantityInPackage ,0)* 	ISNULL(plbi.[GrossWeight],0) * dbo.fnPackingList_GetWeightUnitFact(ISNULL(plbi.WeightUnit, -1)) ) SumW,
						cu.CustomerName,
						cu.LatinName cLatinName,
						cu.GUID cuGuid,
						@FromPackage as PkID,
						CASE  
							WHEN  bi.UnityName=mt.Unit2 THEN plbi.QuantityInPackage * (CASE WHEN [mt].[Unit2Fact] = 0 THEN 1 ELSE [mt].[Unit2Fact] END) 
							When  bi.UnityName=mt.Unit3  THEN plbi.QuantityInPackage *(CASE WHEN [mt].[Unit3Fact] = 0 THEN 1 ELSE [mt].[Unit3Fact] END)   
							ELSE  plbi.QuantityInPackage
						END as qty,

						CASE bi.UnityName  
							WHEN mt.Unity THEN plbi.QuantityInPackage / (CASE WHEN [mt].[Unit2Fact] = 0 THEN 1 ELSE [mt].[Unit2Fact] END) 
							When mt.Unit3  THEN plbi.QuantityInPackage *(CASE WHEN [mt].[Unit3Fact] = 0 THEN 1 ELSE [mt].[Unit3Fact] END)   
							ELSE  [bi].QuantityInPackage
						END as qty2,

						CASE 
							WHEN  bi.UnityName=mt.Unity THEN plbi.QuantityInPackage / (CASE WHEN [mt].[Unit3Fact] = 0 THEN 1 ELSE [mt].[Unit3Fact] END) 
							When  bi.UnityName=mt.Unit2 THEN plbi.QuantityInPackage /(CASE WHEN [mt].[Unit3Fact] = 0 THEN 1 ELSE [mt].[Unit3Fact] END)   
							ELSE  plbi.QuantityInPackage
						END as qty3,
						CASE mt.DefUnit 
								WHEN 1 THEN mt.Unity
								WHEN 2 THEN mt.Unit2
								WHEN 3 THEN mt.Unit3 
							END as unitname,
						mt.DefUnit,
						p.Weight2,
						p.WeightUnit2, 
						mt.CompositionName as CompositionName,
						mt.CompositionLatinName as CompositionLatinName
						
					FROM 
							#BillItems bi 
							INNER JOIN [dbo].[PackingListBis000] plbi ON bi.[ItemGUID] = plbi.BiGUID
							INNER JOIN [dbo].[PackingListsBills000] bu ON bu.[GUID] = plbi.ParentGUID
							INNER JOIN [dbo].[vbPackingLists] pl ON pl.[GUID] = bu.PackingListGUID
							INNER JOIN bu000 bb ON bb.GUID =bu.BillGUID
							INNER JOIN cu000 cu ON cu.GUID= bb.CustGUID
							INNER JOIN bt000 t on bb.TypeGUID=t.GUID 
							INNER JOIN Packages000 p on p.GUID = plbi.PackageGUID
							INNER JOIN Mt000 mt on mt.GUID= bi.MatGUID
					WHERE 
						pl.[GUID] =@pk
						AND (@FromPackage  >= plbi.FromPackage AND @FromPackage <=plbi.ToPackage)
			)AS res
		group by 
				MatGUID,
				MtName ,
				[MatLatinName],
				pName,
				pLatinName,
				pVolume,
				pWeight,
				pVolumeUnit,
				pWeightUnit,
				CustomerName,
				cLatinName,
				cuGuid,
				PkID,
				unitname,
				Weight2,
				WeightUnit2, 
				CompositionName,
				CompositionLatinName
					

		SET @FromPackage=@FromPackage + 1

		END
		

		SELECT * FROM #result
		ORDER BY pkid		
##################################################################################
CREATE PROCEDURE GetListPackedMat
@PackingListGUID UNIQUEIDENTIFIER,
@CustGuid UNIQUEIDENTIFIER,
@BillGuid UNIQUEIDENTIFIER
AS
	SET NOCOUNT ON
	
	CREATE TABLE #BillItems(
		ItemGUID UNIQUEIDENTIFIER, 
		[Unity] INT,
		[ItemNumber] INT, 
		[MatGUID] UNIQUEIDENTIFIER,
		[MatCode] NVARCHAR(250), 
		[MatName] NVARCHAR(250), 
		[MatLatinName] NVARCHAR(250),
		[UnityName] NVARCHAR(250), 
		[ItemQty] FLOAT, 
		[ItemBonusQnt] FLOAT, 
		-----------------
		[UnpackedQuantity] FLOAT,
		FromPackage INT, 
		ToPackage INT, 
		QuantityInPackage FLOAT,
		PackageGUID UNIQUEIDENTIFIER, 
		-----------------
		-- DefaultDimensionUnit INT, 
		[DefaultLength] FLOAT, [DefaultWidth] FLOAT, [DefaultHeight] FLOAT, 
		-- DefaultWeightUnit INT, 
		[DefaultGrossWeight] FLOAT, [DefaultNetWeight] FLOAT, [DefaultDrainedWeight] FLOAT, 
		-----------------
		DimensionUnit INT, [Length] FLOAT, [Width] FLOAT, [Height] FLOAT, Volume FLOAT,
		WeightUnit INT, [GrossWeight] FLOAT, [NetWeight] FLOAT, [DrainedWeight] FLOAT, 
		-----------------
		[PackageListItemGUID] UNIQUEIDENTIFIER,
		[Notes] NVARCHAR(500), 
		[PackagedNumber] INT, 
		IsPacked [BIT])
	INSERT INTO #BillItems
	SELECT 
		bi.GUID,
		bi.[Unity],
		bi.[ItemNumber],
		bi.[MatPtr],
		bi.[MatCode],
		bi.[MatName],
		bi.[LatinName],
		bi.[UnityName],
		bi.[Qty],
		bi.[BonusQnt],
		--------------------------------------
		bi.[Qty] + bi.[BonusQnt], 0, 0, 0, 
		0x0,
		--------------------------------------
		-- ISNULL(dw.Dimension, 0), 
		ISNULL(dw.UnitLength, 0), ISNULL(dw.UnitWidth, 0), ISNULL(dw.Unitheight, 0),
		-- ISNULL(dw.[Weight], 0), 
		ISNULL(dw.UnitGrossWeight, 0), ISNULL(dw.UnitNetWeight, 0), ISNULL(dw.UnitDrainedWeight, 0),
		--------------------------------------
		ISNULL(dw.Dimension, 0), ISNULL(dw.UnitLength, 0), ISNULL(dw.UnitWidth, 0), ISNULL(dw.Unitheight, 0), 0, 
		ISNULL(dw.[Weight], 0), ISNULL(dw.UnitGrossWeight, 0), ISNULL(dw.UnitNetWeight, 0), ISNULL(dw.UnitDrainedWeight, 0),
		--------------------------------------
		0x0,
		bi.Notes, 
		0,
		0
	FROM 
		[vwBillItems] bi 
		LEFT JOIN [mtdw000] dw ON bi.[MatPtr] = dw.MatGuid AND bi.Unity = (dw.NumUnit + 1)
	WHERE 
		bi.[MatType] = 0

	UPDATE bi
	SET 
		PackageGUID = plbi.PackageGUID
	FROM #BillItems AS bi
		INNER JOIN [PackingListBis000] plbi ON bi.[ItemGUID] = plbi.BiGUID

	UPDATE #BillItems
	SET [UnpackedQuantity] =plbi.[PackedQuantity]
	FROM 
		#BillItems bi
		INNER JOIN 
			(SELECT plb.BiGUID, SUM((plb.[ToPackage] - plb.[FromPackage] + 1) * plb.QuantityInPackage) AS [PackedQuantity] FROM #BillItems b INNER JOIN [dbo].[PackingListBis000] plb
				ON b.[ItemGUID] = plb.BiGUID GROUP BY plb.BiGUID) plbi ON bi.[ItemGUID] = plbi.BiGUID
	
	SELECT * FROM (
	SELECT 
		bi.MatGUID,
		bi.[MatCode],
		bi.[MatName],
		bi.[MatLatinName],
		bi.Unity,
		bi.[UnityName],
		bi.ItemQty,
		plbi.FromPackage, 
		plbi.ToPackage, 
		plbi.ToPackage - plbi.FromPackage + 1 AS PkQnt,
		plbi.QuantityInPackage,
		(plbi.[ToPackage] - plbi.[FromPackage] + 1) * plbi.QuantityInPackage packedQuantity,
		bi.ItemQty - bi.UnpackedQuantity AS UnpackedQuantity,
		p.Name AS PackageName,
		p.LatinName AS PackageLatinName,
		p.Volume AS PackageVolume, 
		bi.DimensionUnit,
		plbi.[Length],
		plbi.[Width],
		plbi.[Height],
		CASE WHEN ISNULL(plbi.Volume,0) =0 THEN ISNULL(plbi.[Length]*plbi.[Width]*plbi.[Height],0) ELSE  ISNULL(plbi.Volume,0) END * dbo.fnPackingList_GetVolumeUnitFact(ISNULL(plbi.DimensionUnit, -1)) AS SumDim,
		CASE WHEN ISNULL(plbi.Volume,0) =0 THEN ISNULL(plbi.[Length]*plbi.[Width]*plbi.[Height],0) ELSE  ISNULL(plbi.Volume,0) END * ISNULL(plbi.[ToPackage]-plbi.[FromPackage] + 1,0)  * ISNULL(plbi.QuantityInPackage ,0) *  dbo.fnPackingList_GetVolumeUnitFact(ISNULL(plbi.DimensionUnit, -1))  AS SumDimT, 
		bi.WeightUnit,
		p.Weight2,
		plbi.GrossWeight,
		plbi.NetWeight,
		plbi.DrainedWeight,
	   ISNULL(plbi.[ToPackage]-plbi.[FromPackage] + 1,0) * ISNULL(plbi.QuantityInPackage ,0)* 	ISNULL(plbi.[GrossWeight],0) * dbo.fnPackingList_GetWeightUnitFact(ISNULL(plbi.WeightUnit, -1)) SumW,
	  (ISNULL(plbi.[ToPackage]-plbi.[FromPackage] + 1,0) * ISNULL(plbi.QuantityInPackage ,0)* 	ISNULL(plbi.[GrossWeight],0)+ p.Weight2) * dbo.fnPackingList_GetWeightUnitFact(ISNULL(plbi.WeightUnit, -1) ) SumWP,
	   ISNULL(plbi.Notes, '') AS Notes
	FROM 
		#BillItems bi 
		INNER JOIN [dbo].[PackingListBis000] plbi ON bi.[ItemGUID] = plbi.BiGUID
		INNER JOIN [dbo].[PackingListsBills000] bu ON bu.[GUID] = plbi.ParentGUID
		INNER JOIN [dbo].[vbPackingLists] pl ON pl.[GUID] = bu.PackingListGUID
		INNER JOIN bu000 bb ON bb.GUID =bu.BillGUID
		INNER JOIN Packages000 p ON bi.PackageGUID = p.GUID
	WHERE 
		pl.[GUID] = @PackingListGUID
		AND (@CustGuid = 0x0 OR @CustGuid = bb.CustGUID) 
		AND (@BillGuid =0x0 OR @BillGuid = bb.GUID) 
		) as res
	ORDER BY MatName
##################################################################################
CREATE PROCEDURE GetListPackedTotal
	@PackingListGUID UNIQUEIDENTIFIER,
	@BillGUID UNIQUEIDENTIFIER,
	@CustomerGUID UNIQUEIDENTIFIER
AS
	SET NOCOUNT ON

	DECLARE @BillVolume FLOAT

	SELECT @BillVolume = SUM(BillVolume) FROM PackingListsBills000 WHERE PackingListGUID = @PackingListGUID

SELECT SUM(l.ToPackage - l.FromPackage + 1) AS PackageCount,SUM((ToPackage - l.FromPackage + 1) * QuantityInPackage) AS Quntity ,
SUM(CASE WHEN ISNULL(l.Volume ,0) = 0 THEN ISNULL([Length] * [Width] * [Height],0) ELSE  ISNULL(l.Volume ,0) END * ISNULL([ToPackage] - l.FromPackage + 1,0)  * ISNULL(QuantityInPackage ,0) * dbo.fnPackingList_GetVolumeUnitFact(ISNULL(DimensionUnit, -1))) AS SumDim,
@BillVolume AS TSumDim,
SUM(ISNULL([ToPackage] - l.FromPackage + 1,0) * ISNULL(QuantityInPackage ,0) * ISNULL([GrossWeight] ,0) * dbo.fnPackingList_GetWeightUnitFact(ISNULL(l.WeightUnit, -1))) AS SumW,
SUM(ISNULL(GrossWeight *((l.ToPackage - l.FromPackage +1)* l.QuantityInPackage ),0)) AS GrossWeight,
SUM(ISNULL(NetWeight * ((l.ToPackage - l.FromPackage +1)* l.QuantityInPackage ),0)) AS NetWeight,
SUM(ISNULL(DrainedWeight * ((l.ToPackage - l.FromPackage +1)* l.QuantityInPackage ),0)) AS DrainedWeight,
SUM(ISNULL(p.Weight2 * (ToPackage - l.FromPackage + 1),0)) AS EmptyWight
FROM PackingListBis000 AS l
INNER JOIN Packages000 AS p on l.PackageGUID = p.GUID
WHERE ParentGUID IN
(SELECT GUID FROM PackingListsBills000 WHERE PackingListGUID = @PackingListGUID AND (@BillGUID = 0x OR BillGUID =  @BillGUID)
AND (@CustomerGUID = 0x OR BillGUID IN (SELECT GUID FROM bu000 WHERE CustGUID = @CustomerGUID))
)

##################################################################################
#END

