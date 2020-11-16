#########################################################
CREATE PROCEDURE FindNewInvoices
	@TypeGuid [UNIQUEIDENTIFIER],
	@Number [FLOAT],
	@CustGuid [UNIQUEIDENTIFIER],
	@StoreGuid [UNIQUEIDENTIFIER],
	@CostGuid [UNIQUEIDENTIFIER],
	@StartDate		[DATETIME],
	@EndDate		[DATETIME],
	@Unpacked  [INT],
	@Partially_packed [INT],
	@Branch [UNIQUEIDENTIFIER],
	@pk [UNIQUEIDENTIFIER]
AS
		SELECT
			b.Guid buGuid,
			t.Abbrev  as Abbrev,
			Cast(b.Number AS nvarchar(250)) buNumber,
		    case when t.LatinAbbrev='' then t.Abbrev else t.LatinAbbrev end as Abbrev2,
			b.Date buDate,
			cu.CustomerName,
			dbo.fnCalcBillTotal(b.GUID,0x0) total,
			st.Name storeName,
			case when st.LatinName='' then st.Name else t.LatinName end storeName2,
			co.Name costName,
			case when co.LatinName ='' then co.Name else co.LatinName  end costname2,
			ISNULL(sumq,1) as state,
			(select count(*) from PackingListsBills000
			  where BillGUID=b.guid ) as countx
		FROM bu000 b
			INNER JOIN bt000 t on t.GUID=b.TypeGUID 
			INNER JOIN st000 st ON st.GUID= b.StoreGUID
			INNER JOIN cu000 cu ON cu.GUID = b.CustGUID
			LEFT JOIN co000 co ON co.GUID = b.CostGUID
			LEFT JOIN (SELECT SUM(pkbi.QuantityInPackage*((ToPackage-FromPackage)+1)) as sumq,Pk.BillGUID 
					    FROM PackingListsBills000  Pk
							INNER JOIN packingListBis000 pkbi ON pkbi.ParentGUID=pk.GUID
							WHERE pk.PackingListGUID <> @pk
					    GROUP BY Pk.BillGUID
						)as pk on pk.BillGUID = b.GUID
		WHERE 
			(@CostGuid = b.CostGUID OR ISNULL(@CostGuid,0x0)=0x0)
			AND(@StoreGuid = b.StoreGUID OR ISNULL(@StoreGuid,0x0)=0x0)
			AND(@CustGuid=b.CustGUID OR ISNULL(@CustGuid,0x0)=0x0)
			AND(b.Date BETWEEN @StartDate AND @EndDate)	
			AND(@Number = b.Number OR @Number=0)
			AND (b.TypeGUID=@TypeGuid OR (@TypeGuid = 0x0 AND cast(b.TypeGUID as nvarchar(250)) in (select value from op000 where name like 'AmnCfg_PackList_BillType_%')))
			AND (b.Branch = @Branch OR ISNULL(@Branch,0x0) = 0x0)
			AND (b.GUID NOT IN(SELECT BillGuid from PackingListsBills000 where PackingListGUID = @pk) or ISNULL(@pk,0x0)=0x0)
			AND ISNULL(sumq,0) - (select sum(CASE Bi.Unity	WHEN 1 THEN (Bi.Qty+Bi.BonusQnt)    
											WHEN 2 THEN ((Bi.Qty+Bi.BonusQnt)/[Unit2Fact])      
											WHEN 3 THEN ((Bi.Qty+Bi.BonusQnt)/[Unit3Fact])   
							END)   from bi000 bi
					inner join mt000 mt on bi.MatGUID = mt.guid
				where bi.ParentGUID = b.GUID) < 0
			AND ((@Partially_packed = 0 AND ISNULL(Pk.BillGuid,0x0) = 0x0 AND @Unpacked=1) OR (@Unpacked=0 AND @Partially_packed = 1 AND ISNULL(Pk.BillGuid,0x0) <> 0x0) OR (@Partially_packed = 1 AND @Unpacked=1)) 
			AND dbo.fnGetUserBillSec_Browse([dbo].[fnGetCurrentUserGUID](), b.typeguid)>0
			AND b.GUID IN (SELECT bu.Guid 
								from bu000 bu INNER JOIN bi000 bi ON bi.ParentGUID= bu.GUID
								INNER JOIN mt000 mt on mt.GUID = bi.MatGUID
								where mt.type=0
						   ) 
						   
			ORDER BY   budate,Abbrev,bunumber
####################################################################
CREATE PROCEDURE GetBillInfo
	@BillGuid [UNIQUEIDENTIFIER],
	@Guid [UNIQUEIDENTIFIER]
AS
	SELECT
		b.Guid buGuid,
		 t.Abbrev  as Abbrev,
		Cast(b.Number AS nvarchar(250)) buNumber,
	   case when t.LatinAbbrev='' then t.Abbrev else t.LatinAbbrev end as Abbrev2,
		b.Date buDate,
		cu.CustomerName,
		cu.Guid CustomerGuid,
		dbo.fnCalcBillTotal(b.GUID,0x0) total,
		st.Name storeName,
		case when st.LatinName='' then st.Name else t.LatinName end storeName2,
		co.Name costName,
		case when co.LatinName ='' then co.Name else co.LatinName  end costname2,
		@Guid pkGuid,
		ISNULL(sumq - (select sum(CASE Bi.Unity	WHEN 1 THEN (Bi.Qty+Bi.BonusQnt)    
											WHEN 2 THEN ((Bi.Qty+Bi.BonusQnt)/[Unit2Fact])      
											WHEN 3 THEN ((Bi.Qty+Bi.BonusQnt)/[Unit3Fact])   
							END)  from bi000 bi
		inner join mt000 mt on bi.MatGUID = mt.guid
				where bi.ParentGUID = b.GUID
 ) ,1)as state

		FROM bu000 b
			INNER JOIN bt000 t on t.GUID=b.TypeGUID 
			INNER JOIN st000 st ON st.GUID= b.StoreGUID
			INNER JOIN cu000 cu ON cu.GUID = b.CustGUID
			LEFT JOIN ( 
				SELECT Sum(sumq)as sumq,BillGUID
					FROM(SELECT  pkbi.QuantityInPackage*((ToPackage-FromPackage)+1)as sumq,
									Pk.BillGUID ,
									pk.PackingListGUID,
									pkbi.BiGuid
					    FROM PackingListsBills000  Pk
							INNER JOIN packingListBis000 pkbi ON pkbi.ParentGUID=pk.GUID
					)as res 
					group by res.BillGUID
			  ) as pk on pk.BillGuid=b.GUID
			LEFT JOIN co000 co ON co.GUID = b.CostGUID
		WHERE b.GUID= @BillGuid
####################################################################
CREATE PROCEDURE GetMatDimensionWeight
 @MtGuid [UNIQUEIDENTIFIER]=0x0
 as
	SELECT * FROM MTDW000
	WHERE MatGuid = @MtGuid
	ORDER BY NumUnit
######################################################################
CREATE PROCEDURE prcPL_GetBillItemsForBill
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
		bi.[BillNumber] = @BillGUID
		AND 
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

	INSERT INTO #BillItems
	SELECT 
		bi.ItemGUID,
		bi.[ItemNumber],
		bi.[MatGUID],
		bi.[MatCode],
		bi.[MatName],
		bi.[MatLatinName],
		bi.[UnityName],
		bi.[ItemQty],
		bi.[ItemBonusQnt],
		----------------------
		(plbi.[ToPackage] - plbi.[FromPackage] + 1) * plbi.QuantityInPackage,
		plbi.FromPackage, 
		plbi.ToPackage, 
		plbi.QuantityInPackage,
		ISNULL(pk.GUID, 0x0), 
		ISNULL(pk.Name, ''), 
		ISNULL(pk.LatinName, ''), 

		-- bi.DefaultDimensionUnit, 
		bi.[DefaultLength], 
		bi.[DefaultWidth], 
		bi.[DefaultHeight], 
		-- bi.DefaultWeightUnit, 
		bi.[DefaultGrossWeight], 
		bi.[DefaultNetWeight], 
		bi.[DefaultDrainedWeight],

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
	
	SELECT 
		MatName,
		UnityName,
		FromPackage,
		ToPackage,
		QuantityInPackage, 
		SUM(UnpackedQuantity) packedQuantity,
		DimensionUnit,
		WeightUnit,
		Volume,
		Length,
		Width,
		Height,
		GrossWeight,
		MatGUID,
		CompositionName,
		CompositionLatinName
	FROM #BillItems 
		WHERE ToPackage > 0 AND FromPackage > 0 and QuantityInPackage > 0
	GROUP BY 
		MatGUID,
		MatName,
		UnityName,
		FromPackage,
		ToPackage,
		QuantityInPackage,
		DimensionUnit,
		WeightUnit,
		Volume,
		Length,
		Width,
		Height,
		GrossWeight,
		CompositionName,
		CompositionLatinName
	ORDER BY MatName
########################################################################################
CREATE PROCEDURE GetAllCustomerPk
@pk UNIQUEIDENTIFIER
AS
	SET NOCOUNT ON
	SELECT 
		distinct
			cust.Guid,
			cust.CustomerName 
	FROM cu000  cust INNER JOIN 
	bu000 bu on bu.CustGUID= cust.GUID
	Inner Join 
	PackingListsBills000 b on b.BillGUID=bu.GUID and b.PackingListGUID=@pk
#########################################################################
#END