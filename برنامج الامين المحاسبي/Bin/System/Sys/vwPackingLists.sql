######################################################################
CREATE VIEW vtPackingLists
as 
	SELECT * FROM PackingLists000
######################################################################
CREATE VIEW vbPackingLists
as 
	SELECT * FROM vtPackingLists
######################################################################
CREATE FUNCTION fnPackingList_GetVolumeUnitFact(@VolumeUnit INT)
	RETURNS FLOAT
AS 
BEGIN 
	IF @VolumeUnit = -1 
		RETURN 0
	IF @VolumeUnit = 0	-- cm 3
		RETURN 1
	IF @VolumeUnit = 1	-- m 3
		RETURN 1000000
	IF @VolumeUnit = 2	-- inch 3
		RETURN 16.3869952805454
	IF @VolumeUnit = 3	-- foot 3 
		RETURN 28316.7278447824
	RETURN 1
END 
######################################################################
CREATE FUNCTION fnPackingList_GetWeightUnitFact(@VolumeUnit INT)
	RETURNS FLOAT
AS 
BEGIN 
	IF @VolumeUnit = -1 
		RETURN 0
	IF @VolumeUnit = 0	-- kg
		RETURN 1
	IF @VolumeUnit = 1	-- ounce
		RETURN 0.0283494925440835
	IF @VolumeUnit = 2	-- pound
		RETURN 0.453591880705335
	IF @VolumeUnit = 3	-- ton 
		RETURN 1000
	RETURN 1
END 
######################################################################
CREATE FUNCTION fnPackingList_GetTotalValues(@PackingListGUID UNIQUEIDENTIFIER)
	RETURNS TABLE
AS 
RETURN (
	SELECT 
		ISNULL(SUM(CASE ToPackage WHEN 0 THEN 0 ELSE (CASE bi.FromPackage WHEN 0 THEN 0 ELSE (ToPackage - bi.FromPackage + 1) END) END), 0) AS TotalContainersCount,
		ISNULL(SUM((CASE ToPackage WHEN 0 THEN 0 ELSE (CASE bi.FromPackage WHEN 0 THEN 0 ELSE (ToPackage - bi.FromPackage + 1) END) END) * bi.QuantityInPackage), 0) AS TotalPackedQnt,
		ISNULL(SUM((CASE ToPackage WHEN 0 THEN 0 ELSE (CASE bi.FromPackage WHEN 0 THEN 0 ELSE (ToPackage - bi.FromPackage + 1) END) END) * bi.QuantityInPackage * 
			(CASE bi.Volume WHEN 0 THEN (bi.[Length] * bi.[Width] * bi.[Height]) ELSE bi.Volume END) 
			* dbo.fnPackingList_GetVolumeUnitFact(ISNULL(bi.DimensionUnit, -1))), 0) AS TotalUsedVolume,
		ISNULL(SUM((CASE ToPackage WHEN 0 THEN 0 ELSE (CASE bi.FromPackage WHEN 0 THEN 0 ELSE (ToPackage - bi.FromPackage + 1) END) END) * bi.QuantityInPackage * 
			bi.GrossWeight * dbo.fnPackingList_GetWeightUnitFact(ISNULL(bi.WeightUnit, -1))), 0) AS TotalUsedWeight
		--ISNULL((SELECT SUM(BillVolume) FROM [dbo].[PackingListsBills000] WHERE PackingListGuid = @PackingListGUID), 0) AS TotalUsedVolume,
		--ISNULL((SELECT SUM(BillWight) FROM [dbo].[PackingListsBills000] WHERE PackingListGuid = @PackingListGUID),0) AS TotalUsedWeight
	FROM 
		[dbo].[PackingListsBills000] b
		INNER JOIN [dbo].[PackingListBis000] bi ON b.GUID = bi.ParentGUID 
		LEFT JOIN [dbo].[Packages000] p ON p.GUID = bi.PackageGUID
	WHERE 
		b.PackingListGuid = @PackingListGUID)
######################################################################
CREATE PROC prcPL_GetSamePackagesCount
	@PackingListGUID UNIQUEIDENTIFIER
AS 
	SET NOCOUNT ON 

	DECLARE 
		@c CURSOR,
		@FromPackage INT,
		@ToPackage INT 

	DECLARE @table TABLE(PackageNumber INT)

	SET @c = CURSOR FAST_FORWARD FOR 
		SELECT 
			bi.FromPackage, bi.ToPackage
		FROM 
			[dbo].[PackingListsBills000] b
			INNER JOIN [dbo].[PackingListBis000] bi ON b.GUID = bi.ParentGUID 
		WHERE 
			b.PackingListGuid = @PackingListGUID 
			
			AND 
			bi.FromPackage > 0 
			AND
			bi.ToPackage > 0
			 
	OPEN @c FETCH NEXT FROM @c INTO @FromPackage, @ToPackage
	WHILE @@FETCH_STATUS = 0
	BEGIN 
		DECLARE @PackageNumber INT 
		SET @PackageNumber = @FromPackage
		WHILE @PackageNumber <= @ToPackage
		BEGIN 
			INSERT INTO @table SELECT @PackageNumber
			SET @PackageNumber = @PackageNumber + 1
		END 
		FETCH NEXT FROM @c INTO @FromPackage, @ToPackage
	END 
	CLOSE @c
	DEALLOCATE @c
	SELECT ISNULL(COUNT(*), 0) AS PackagesCount
	FROM
		(SELECT * FROM @table GROUP BY PackageNumber HAVING COUNT(*) > 1 OR COUNT(*) = 1) c 
######################################################################
CREATE  PROC prcPL_GetSamePackagesCountForBill
	@PackingListGUID UNIQUEIDENTIFIER,
	@BillGUID UNIQUEIDENTIFIER = 0x0
AS 
	SET NOCOUNT ON 
	DECLARE 
		@c CURSOR,
		@FromPackage INT,
		@ToPackage INT 
	DECLARE @table TABLE(PackageNumber INT)
	SET @c = CURSOR FAST_FORWARD FOR 
		SELECT 
			bi.FromPackage, bi.ToPackage
		FROM 
			[dbo].[PackingListsBills000] b
			INNER JOIN [dbo].[PackingListBis000] bi ON b.GUID = bi.ParentGUID 
		WHERE 
			b.PackingListGuid = @PackingListGUID 
			AND 
			((@BillGUID = 0x0) OR (b.BillGUID <> @BillGuid))
			AND 
			bi.FromPackage > 0 
			AND
			bi.ToPackage > 0
			 
	OPEN @c FETCH NEXT FROM @c INTO @FromPackage, @ToPackage
	WHILE @@FETCH_STATUS = 0
	BEGIN 
		DECLARE @PackageNumber INT 
		SET @PackageNumber = @FromPackage

		WHILE @PackageNumber <= @ToPackage
		BEGIN 
			INSERT INTO @table SELECT @PackageNumber
			SET @PackageNumber = @PackageNumber + 1
		END 
		FETCH NEXT FROM @c INTO @FromPackage, @ToPackage
	END 
	CLOSE @c
	DEALLOCATE @c

	SELECT ISNULL(COUNT(*), 0) AS PackagesCount
	FROM
		(SELECT * FROM @table GROUP BY PackageNumber HAVING COUNT(*) > 1 ) c 
######################################################################
CREATE PROC prcPL_GetPackingList
	@PackingListGUID UNIQUEIDENTIFIER 
AS 
	SET NOCOUNT ON
	 
	CREATE TABLE #Tbl(PackagesCount INT)
	INSERT INTO #Tbl EXEC prcPL_GetSamePackagesCount @PackingListGUID

	SELECT 
		pl.*,
		ISNULL(pk.Name, '') AS DefPackageName,
		ISNULL(pk.LatinName, '') AS DefPackageLatinName,
		ISNULL((SELECT TOP 1 PackagesCount FROM #Tbl), 0) AS TotalContainersCount,
		ISNULL(plt.TotalPackedQnt, 0) AS TotalPackedQnt,
		ISNULL(plt.TotalUsedVolume, 0) AS TotalUsedVolume,
		ISNULL(plt.TotalUsedWeight, 0) AS TotalUsedWeight,
		(CASE 
			(SELECT TOP 1 [GUID] FROM [dbo].[PackingListsBills000] WHERE PackingListGUID = pl.GUID)
			WHEN NULL THEN 0
			ELSE 1
		END) AS IsRelatedToBills
	FROM 
		vbPackingLists pl
		LEFT JOIN Packages000 pk ON pl.DefPackageGUID = pk.GUID 
		CROSS APPLY dbo.fnPackingList_GetTotalValues(pl.GUID) as plt
	WHERE 
		pl.GUID = @PackingListGUID
######################################################################
CREATE FUNCTION fnContainer_IsUsed(@GUID UNIQUEIDENTIFIER)
	RETURNS BIT 
AS 
BEGIN 
	IF EXISTS(SELECT * FROM PackingLists000 WHERE ContainerGUID = @GUID)
		RETURN 1
	RETURN 0
END 
######################################################################
CREATE FUNCTION fnPackage_IsUsed(@GUID UNIQUEIDENTIFIER)
	RETURNS BIT 
AS 
BEGIN 
	IF EXISTS(SELECT * FROM PackingListBis000 WHERE PackageGUID = @GUID)
		RETURN 1
	RETURN 0
END 
######################################################################
CREATE VIEW vwContainers
AS 
	SELECT 
		*,
		dbo.fnContainer_IsUsed(GUID) AS IsUsed
	FROM 
		Containers000 
######################################################################
CREATE VIEW vwPackages
AS 
	SELECT 
		*,
		dbo.fnPackage_IsUsed(GUID) AS IsUsed
	FROM 
		Packages000 
######################################################################
CREATE PROCEDURE prcPackingListBill_GetTotalValues
	@PackingListGUID UNIQUEIDENTIFIER,
	@BillGuid UNIQUEIDENTIFIER
AS 
	SET NOCOUNT ON 

	CREATE TABLE #Tbl(PackagesCount INT)
	INSERT INTO #Tbl EXEC prcPL_GetSamePackagesCountForBill @PackingListGUID, @BillGuid

	SELECT 
		ISNULL(SUM(CASE ToPackage WHEN 0 THEN 0 ELSE (CASE bi.FromPackage WHEN 0 THEN 0 ELSE (ToPackage - bi.FromPackage + 1) END) END), 0) - ISNULL((SELECT TOP 1 PackagesCount FROM #Tbl), 0) AS TotalContainersCount,
		ISNULL(SUM((CASE ToPackage WHEN 0 THEN 0 ELSE (CASE bi.FromPackage WHEN 0 THEN 0 ELSE (ToPackage - bi.FromPackage + 1) END) END) * bi.QuantityInPackage), 0) AS TotalPackedQnt,
		--ISNULL(SUM((CASE ToPackage WHEN 0 THEN 0 ELSE (CASE bi.FromPackage WHEN 0 THEN 0 ELSE (ToPackage - bi.FromPackage + 1) END) END) * bi.QuantityInPackage * 
		--	(CASE bi.Volume WHEN 0 THEN (bi.[Length] * bi.[Width] * bi.[Height]) ELSE bi.Volume END) 
		--	* dbo.fnPackingList_GetVolumeUnitFact(ISNULL(bi.DimensionUnit, -1))), 0) AS TotalUsedVolume,
		ISNULL((SELECT SUM(BillVolume) FROM PackingListsBills000 WHERE PackingListGUID = @PackingListGUID AND BillGUID <> @BillGuid), 0) AS TotalUsedVolume,
		ISNULL(SUM((CASE ToPackage WHEN 0 THEN 0 ELSE (CASE bi.FromPackage WHEN 0 THEN 0 ELSE (ToPackage - bi.FromPackage + 1) END) END) * bi.QuantityInPackage * 
			bi.GrossWeight * dbo.fnPackingList_GetWeightUnitFact(ISNULL(bi.WeightUnit, -1))), 0) AS TotalUsedWeight
	FROM 
		[dbo].[PackingListsBills000] b
		INNER JOIN [dbo].[PackingListBis000] bi ON b.GUID = bi.ParentGUID 
		LEFT JOIN [dbo].[Packages000] p ON p.GUID = bi.PackageGUID
	WHERE 
		b.PackingListGuid = @PackingListGUID 
		AND 
		b.BillGUID <> @BillGuid
########################################################################
#END
