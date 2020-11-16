################################################################################
CREATE PROCEDURE prcGetMatByUnitBarcode
	@Barcode	nvarchar(256)
AS 
SET NOCOUNT ON

	SELECT 
		MtGuid,
		CASE 	WHEN @Barcode = mtBarcode THEN 	1
				WHEN @Barcode = mtBarcode2 THEN 2
				WHEN @Barcode = mtBarcode3 THEN 3
		END AS Unit
	FROM vwMt
	WHERE 	(mtBarcode = 	@Barcode)
	OR		(mtBarcode2 = 	@Barcode)
	OR		(mtBarcode3 = 	@Barcode)

################################################################################
CREATE PROCEDURE prcPOSSD_Station_GetMaterialImageList
 @POSCardGuid UNIQUEIDENTIFIER,
@PageSize INT = 20,
@PageIndex INT = 0
AS
BEGIN	
	/*******************************************************************************************************
	Company : Syriansoft
	SP : prcPOSSD_Station_GetMaterialImageList
	Purpose: get products image for a specific pos station 
	How to Call: EXEC prcPOSSD_Station_GetMaterialImageList '3C2561FE-406C-446D-AFE3-6212319487F8',10000,0
	Create By: 											Created On: 
	Updated On:	Hanadi Salka							Updated By: 12-Nov-2019
	Change Note:
	********************************************************************************************************/
	DECLARE @Groups TABLE (Number	   INT,
						   GroupGUID   UNIQUEIDENTIFIER,  
						   Name		   NVARCHAR(MAX),
						   Code		   NVARCHAR(MAX),
						   ParentGUID  UNIQUEIDENTIFIER,  
						   LatinName   NVARCHAR(MAX),
						   PictureGUID UNIQUEIDENTIFIER,
						   GroupIndex  INT,
						   Groupkind   TINYINT);	
	DECLARE @Count	INT = 0;
	-- ******************************************************************************************
	-- Declare Temp tables 
	DECLARE @Materials TABLE (MatGuid	UNIQUEIDENTIFIER);
	INSERT INTO @Groups (Number,GroupGUID, Name,Code, ParentGUID, LatinName, PictureGUID, GroupIndex, Groupkind)
	EXEC prcPOSSD_Station_GetGroups @POSCardGuid		
	
	INSERT INTO @Materials(MatGuid)
	SELECT [mt].[GUID]
	FROM @Groups AS [grp]
	INNER JOIN [gri000] AS [gri] ON ([gri].[GroupGuid] = [grp].[GroupGUID] AND [gri].[ItemType] = 1)
	INNER JOIN [mt000] AS [mt] ON ([mt].[GUID] = [gri].[MatGuid]);
	
    -- ********************************************************************************
	INSERT INTO @Materials(MatGuid)	
	SELECT MT.GUID
	FROM @Groups AS  GrTree INNER JOIN mt000 AS MT ON (MT.GroupGUID = GrTree.GroupGUID)
	LEFT JOIN @Materials AS TMPMT ON (TMPMT.MatGuid = MT.GUID)
	WHERE TMPMT.MatGuid IS NULL;	
	-- Check if there is data, if yes , display it otherwise display emty data
	SELECT @Count = COUNT(*) FROM @Materials FMT;
	IF @Count > 0 
	BEGIN
		SELECT @Count = COUNT(*)
		FROM @Materials FMT INNER JOIN mt000 AS MT ON (MT.Parent = FMT.MatGuid );
		IF @Count > 0 
		BEGIN	
			SELECT		
				MT.Number AS SourceNumber,
				MT.Code AS SourceCode,
				MT.PictureGUID AS ImageGuid,
				MT.GUID AS SourceGuid,
				BM.Name AS ImageFilePath
			FROM @Materials FMT INNER JOIN mt000 AS MT ON (MT.GUID = FMT.MatGuid)
			INNER JOIN bm000 AS BM on (BM.GUID = MT.PictureGUID) 
			WHERE BM.Name IS NOT NULL AND LEN(BM.NAME) > 0
			UNION ALL
			SELECT		
				MT.Number AS SourceNumber,
				MT.Code AS SourceCode,
				MT.PictureGUID AS ImageGuid,
				MT.GUID AS SourceGuid,
				BM.Name AS ImageFilePath
			FROM @Materials FMT INNER JOIN mt000 AS MT ON (MT.Parent = FMT.MatGuid )
			INNER JOIN bm000 AS BM on (BM.GUID = MT.PictureGUID)
			WHERE BM.Name IS NOT NULL AND LEN(BM.NAME) > 0
			ORDER BY Number OFFSET (@PageSize * @PageIndex)  ROWS FETCH NEXT @PageSize ROWS ONLY;
		END
		ELSE
		BEGIN
			SELECT		
				MT.Number AS SourceNumber,
				MT.Code AS SourceCode,
				MT.PictureGUID AS ImageGuid,
				MT.GUID AS SourceGuid,
				BM.Name AS ImageFilePath
			FROM @Materials FMT INNER JOIN mt000 AS MT ON (MT.GUID = FMT.MatGuid)
			INNER JOIN bm000 AS BM on (BM.GUID = MT.PictureGUID) 
			WHERE BM.Name IS NOT NULL AND LEN(BM.NAME) > 0
			ORDER BY Number OFFSET (@PageSize * @PageIndex)  ROWS FETCH NEXT @PageSize ROWS ONLY;
		END	
	END
	ELSE
	BEGIN
		SELECT		
			MT.Number AS SourceNumber,
			MT.Code AS SourceCode,
			MT.PictureGUID AS ImageGuid,
			MT.GUID AS SourceGuid,
			BM.Name AS ImageFilePath
		FROM mt000 AS MT 
		INNER JOIN bm000 AS BM on (BM.GUID = MT.PictureGUID) 
		WHERE 1 != 2;
	END
END
################################################################################
CREATE PROCEDURE prcPOSSD_Station_GetGroupImageList
 @POSCardGuid UNIQUEIDENTIFIER,
 @PageSize INT = 20,
 @PageIndex INT = 0
AS
BEGIN
	/*******************************************************************************************************
	Company : Syriansoft
	SP : prcPOSSD_Station_GetGroupImageList
	Purpose: get group image for a specific pos station 
	How to Call: EXEC prcPOSSD_Station_GetGroupImageList '3C2561FE-406C-446D-AFE3-6212319487F8',10000,0
	Create By: 											Created On: 
	Updated On:	Hanadi Salka							Updated By: 12-Nov-2019
	Change Note:
	********************************************************************************************************/
	DECLARE @Groups TABLE (Number	   INT,
						   GroupGUID   UNIQUEIDENTIFIER,  
						   Name		   NVARCHAR(MAX),
						   Code		   NVARCHAR(MAX),
						   ParentGUID  UNIQUEIDENTIFIER,  
						   LatinName   NVARCHAR(MAX),
						   PictureGUID UNIQUEIDENTIFIER,
						   GroupIndex  INT,
						   Groupkind   TINYINT)	
	
	INSERT INTO @Groups (Number,GroupGUID, Name,Code, ParentGUID, LatinName, PictureGUID, GroupIndex, Groupkind)
	EXEC prcPOSSD_Station_GetGroups @POSCardGuid	

	SELECT		
		GRP.Number AS SourceNumber,
		GRP.Code AS SourceCode,
		GRP.PictureGUID AS ImageGuid,
		GRP.GroupGUID AS SourceGuid,
		BM.Name AS ImageFilePath
	FROM @Groups AS GRP INNER JOIN bm000 AS BM on (BM.GUID = GRP.PictureGUID) 
	ORDER BY Number OFFSET (@PageSize * @PageIndex)  ROWS FETCH NEXT @PageSize ROWS ONLY;	
END
################################################################################
CREATE PROCEDURE prcPOSSD_Station_GetCurrencyImageList
	@StationGUID UNIQUEIDENTIFIER,
	@PageSize INT = 20,
	@PageIndex INT = 0
AS
BEGIN
    SET NOCOUNT ON
	SELECT 
		my.GUID AS SourceGuid,
		MY.Code AS SourceCode,		
		Number AS SourceNumber,
		my.PictureGUID  AS ImageGuid, 
		BM.Name AS ImageFilePath
	 FROM my000 my 
		  LEFT JOIN mh000 mh ON my.GUID = mh.CurrencyGUID 
		  LEFT JOIN POSSDStationCurrency000 RC ON my.GUID = RC.CurrencyGUID AND StationGUID = @StationGUID
		  INNER JOIN bm000 AS BM on (BM.GUID = my.PictureGUID) 	
	 WHERE (RC.IsUsed = 1 OR my.CurrencyVal = 1) 
			AND (EXISTS (SELECT 1 FROM mh000 WHERE CurrencyGUID = my.GUID) 
				  AND (mh.Date = (SELECT MAX ([Date]) FROM mh000 mhe GROUP BY CurrencyGUID HAVING CurrencyGUID = mh.CurrencyGUID )) 
				  OR (NOT EXISTS (SELECT 1 FROM mh000 WHERE CurrencyGUID = my.GUID)))
	 ORDER BY Number OFFSET (@PageSize * @PageIndex)  ROWS FETCH NEXT @PageSize ROWS ONLY;
END;
################################################################################
#END