#########################################
CREATE FUNCTION fnGetMtPriceByType (@PriceType FLOAT, @MatId UNIQUEIDENTIFIER, @Unit INT)
RETURNS FLOAT
AS
BEGIN
	RETURN (SELECT 
		CASE @PriceType
			WHEN 4 THEN
				CASE @Unit WHEN 1 THEN mt.Whole WHEN 2 THEN mt.Whole2 WHEN 3 THEN mt.Whole3 ELSE 0 END
			WHEN 8 THEN
				CASE @Unit WHEN 1 THEN mt.Half WHEN 2 THEN mt.Half2 WHEN 3 THEN mt.Half3 ELSE 0 END
			WHEN 32 THEN
				CASE @Unit WHEN 1 THEN mt.Vendor WHEN 2 THEN mt.Vendor2 WHEN 3 THEN mt.Vendor3 ELSE 0 END
			WHEN 16 THEN
				CASE @Unit WHEN 1 THEN mt.Export WHEN 2 THEN mt.Export2 WHEN 3 THEN mt.Export3 ELSE 0 END
			WHEN 64 THEN
				CASE @Unit WHEN 1 THEN mt.Retail WHEN 2 THEN mt.Retail2 WHEN 3 THEN mt.Retail3 ELSE 0 END
			WHEN 128 THEN
				CASE @Unit WHEN 1 THEN mt.EndUser WHEN 2 THEN mt.EndUser2 WHEN 3 THEN mt.EndUser3 ELSE 0 END
			WHEN 512 THEN
				CASE @Unit WHEN 1 THEN mt.LastPrice WHEN 2 THEN mt.LastPrice2 WHEN 3 THEN mt.LastPrice3 ELSE 0 END
			ELSE 0
			END
		FROM mt000 mt
			WHERE GUID = @MatId)
END
#########################################
CREATE PROCEDURE prcRestGetOptions
	@UserGUID UNIQUEIDENTIFIER = 0x0,
	@Computer NVARCHAR(250) = ''
AS
	SET NOCOUNT ON 
	DECLARE @ConfigGUID UNIQUEIDENTIFIER, @PriceType FLOAT
	SELECT @ConfigGUID = GUID FROM RestConfig000 where HostName = @Computer

	SET @PriceType = ISNULL((SELECT CAST ([Value] AS [FLOAT]) FROM [FileOP000] WHERE [Name] = 'AmnRest_InfoPriceType'), 0)

	SELECT Name, Value, 0 AS [Type] FROM FileOP000 WHERE Name like 'AmnRest%' 
	UNION 
	SELECT Name, Value, 1 AS [Type] FROM UserOP000 WHERE  Name like 'AmnRest%' AND UserID = @UserGUID
	UNION 
	SELECT Name, Value, 2 AS [Type] FROM PcOP000 WHERE  Name like 'AmnRest%' AND CompName = @Computer
	SELECT 
		* 
	FROM 
		POSInfos000 
	WHERE 
		ConfigID = @ConfigGUID
	ORDER BY 
		RowIndex, ColumnIndex
	CREATE TABLE #RestBG (
		[bgNumber] [float],
		[bgGUID] [uniqueidentifier],		
		[bgCaption] [nvarchar](256),
		[bgLatinCaption] [nvarchar](256),
		[bgPictureID] [uniqueidentifier],
		[bgType] [int],
		[bgConfigID] [uniqueidentifier],
		[bgGroupGUID] [uniqueidentifier],
		[bgIsAutoRefresh] [bit],
		[bgIsAutoCaption] [bit],
		[bgIsSegmentedMaterial] [bit],
		[bgIsCodeInsteadName] [bit],
		[bgWeekDays]		[INT],
		[bgFromTime]		[nvarchar](10),
		[bgToTime]		[nvarchar](10),
		[bgPictureName] [nvarchar](256),
		[bgBColor] [float],
		[bgFColor] [float],
		[bgIsThemeColors] [bit],
		[bgiNumber] [float],
		[bgiGuid] [uniqueidentifier],
		[bgiType] [int],
		[bgiParentID] [uniqueidentifier],
		[bgiCommand] [int],
		[bgiItemID] [uniqueidentifier],
		[bgiCaption] [nvarchar](256),
		[bgiLatinCaption] [nvarchar](256),
		[bgiPrice] [float],
		[bgiBColor] [float],
		[bgiFColor] [float],
		[bgiPictureID] [uniqueidentifier],
		[bgiPictureAlignment] [int],
		[bgiPictureFactor] [float],
		[bgiIsThemeColors] [bit],
		[bgiIsAutoCaption] [bit],
		[bgiPictureName] [nvarchar](256),
		[bgiHasSegments] [bit],
		[bgiIsCodeInsteadName] [bit] )
	INSERT INTO #RestBG
	SELECT 
		BG.Number bgNumber,
		BG.GUID bgGUID,
		BG.Caption bgCaption,
		BG.LatinCaption bgLatinCaption,
		BG.PictureID bgPictureID,
		BG.Type bgType,
		BG.ConfigID bgConfigID,	
		BG.GroupGUID bgGroupGUID,
		BG.IsAutoRefresh AS bgIsAutoRefresh,
		BG.IsAutoCaption AS bgIsAutoCaption,
		BG.IsSegmentedMaterial AS bgIsSegmentedMaterial,
		BG.IsCodeInsteadName AS bgIsCodeInsteadName,
		BG.WeekDays bgWeekDays,
		BG.FromTime bgFromTime,
		BG.ToTime bgToTime,
		ISNULL(bm.Name, '') bgPictureName,
		BG.BColor,
		BG.FColor,
		BG.IsThemeColors,
		BGI.Number bgiNumber,
		BGI.GUID bgiGUID,
		BGI.Type,
		BGI.ParentID,
		BGI.Command bgiCommand,
		BGI.ItemID bgiItemID,
		BGI.Caption bgiCaption,
		BGI.LatinCaption bgiLatinCaption,
		0,
		BGI.BColor bgiBColor,
		BGI.FColor bgiFColor,
		BGI.PictureID bgiPictureID,
		BGI.PictureAlignment bgiPictureAlignment,
		BGI.PictureFactor bgiPictureFactor,
		BGI.IsThemeColors bgiIsThemeColors,
		BGI.IsAutoCaption bgiIsAutoCaption,
		'' bgiPictureName,
		MT.HasSegments AS bgiHasSegments,
		BGI.IsCodeInsteadName AS bgiIsCodeInsteadName
	FROM 
		BG000 BG 
		INNER JOIN BGI000 BGI ON BGI.ParentID = BG.GUID
		LEFT JOIN bm000 bm ON bm.GUID = BG.PictureID
		LEFT JOIN mt000 mt ON mt.GUID = BGI.ItemID
		-- LEFT JOIN bm000 bm1 ON bm1.GUID = mt.PictureGUID
	WHERE 
		ConfigID = @ConfigGUID
		AND 
		bg.Type = 1 -- commands
	DECLARE @lang INT
	SET @lang = [dbo].[fnConnections_GetLanguage]()
	INSERT INTO #RestBG
	SELECT 
		BG.Number bgNumber,
		BG.GUID bgGUID,
		CASE WHEN BG.IsAutoCaption = 1 THEN gr.Name ELSE BG.Caption END AS bgCaption,
		CASE WHEN BG.IsAutoCaption = 1 THEN gr.LatinName ELSE BG.LatinCaption END AS bgLatinCaption,
		BG.PictureID bgPictureID,
		BG.Type bgType,
		BG.ConfigID bgConfigID,	
		BG.GroupGUID bgGroupGUID,
		BG.IsAutoRefresh AS bgIsAutoRefresh,
		BG.IsAutoCaption AS bgIsAutoCaption,
		BG.IsSegmentedMaterial AS bgIsSegmentedMaterial,
		BG.IsCodeInsteadName AS bgIsCodeInsteadName,
		BG.WeekDays bgWeekDays,
		BG.FromTime bgFromTime,
		BG.ToTime bgToTime,
		ISNULL(bm.Name, '') bgPictureName,
		BG.BColor,
		BG.FColor,
		BG.IsThemeColors,
		BGI.Number bgiNumber,
		BGI.GUID bgiGUID,
		BGI.Type,
		BGI.ParentID,
		BGI.Command bgiCommand,
		BGI.ItemID bgiItemID,
		CASE WHEN BGI.IsAutoCaption = 1 
				THEN (CASE @lang 
							WHEN 0 THEN MT.Name
							ELSE CASE MT.LatinName WHEN '' THEN MT.Name ELSE MT.LatinName END 
					END )  + 
						(CASE WHEN mt.Parent = 0x0 OR mt.Parent IS NULL 
								THEN '' 
								ELSE ' (' + (CASE WHEN BGI.IsCodeInsteadName = 1 THEN mt.Code ELSE mt.CompositionName END) + ')' END)
				ELSE BGI.Caption END AS bgiCaption,
		CASE WHEN BGI.IsAutoCaption = 1 
				THEN mt.LatinName + 
						(CASE WHEN mt.Parent = 0x0 OR mt.Parent IS NULL OR mt.LatinName = '' 
								THEN '' 
								ELSE ' (' + (CASE WHEN BGI.IsCodeInsteadName = 1 THEN mt.Code ELSE mt.CompositionLatinName END) + ')' END)
				ELSE BGI.LatinCaption END AS bgiLatinCaption,
		dbo.fnGetMtPriceByType (@PriceType, mt.GUID, mt.DefUnit) AS Price,
		BGI.BColor bgiBColor,
		BGI.FColor bgiFColor,
		BGI.PictureID bgiPictureID,
		BGI.PictureAlignment bgiPictureAlignment,
		BGI.PictureFactor bgiPictureFactor,
		BGI.IsThemeColors bgiIsThemeColors,
		BGI.IsAutoCaption bgiIsAutoCaption,
		ISNULL(bm1.Name, '') bgiPictureName,
		MT.HasSegments AS bgiHasSegments,
		BGI.IsCodeInsteadName AS bgiIsCodeInsteadName
	FROM 
		BG000 BG 
		INNER JOIN BGI000 BGI ON BGI.ParentID = BG.GUID
		INNER JOIN mt000 mt ON mt.GUID = BGI.ItemID
		LEFT JOIN gr000 gr ON gr.GUID = BG.GroupGUID		
		LEFT JOIN bm000 bm ON bm.GUID = BG.PictureID		
		LEFT JOIN bm000 bm1 ON bm1.GUID = mt.PictureGUID
	WHERE 
		ConfigID = @ConfigGUID
		AND 
		bg.Type = 0 -- materials
	IF EXISTS(SELECT * FROM #RestBG WHERE bgIsAutoRefresh = 1)
	BEGIN 
		DECLARE 
			@bgC CURSOR, 
			@bgGUID UNIQUEIDENTIFIER 
		
		DECLARE 
			@ItemNumber INT,
			@BColor INT,
			@FColor INT,
			@PictureFactor INT
		SET @bgC = CURSOR FAST_FORWARD FOR 
			SELECT [GUID] 
			FROM BG000 
			WHERE 
				ConfigID = @ConfigGUID 
				AND [Type] = 0
				AND IsAutoRefresh = 1
		OPEN @bgC FETCH NEXT FROM @bgC INTO @bgGUID
		WHILE @@FETCH_STATUS = 0
		BEGIN 
			SET @ItemNumber = NULL
			SELECT TOP 1 
				@ItemNumber = Number,
				@BColor = BColor,
				@FColor = FColor,
				@PictureFactor = PictureFactor
			FROM 
				BGI000 
			WHERE 
				ParentID = @bgGUID
			ORDER BY Number DESC 
			IF ISNULL(@ItemNumber, 0) = 0
			BEGIN 
				SET @ItemNumber = 0
				SET @BColor = 11194327
				SET @FColor = 0
				SET @PictureFactor = 60				
			END 
			INSERT INTO #RestBG
			SELECT 
				BG.Number bgNumber,
				BG.GUID bgGUID,
				BG.Caption AS bgCaption,
				BG.LatinCaption AS bgLatinCaption,
				BG.PictureID bgPictureID,
				BG.Type bgType,
				BG.ConfigID bgConfigID,	
				BG.GroupGUID bgGroupGUID,
				BG.IsAutoRefresh AS bgIsAutoRefresh,
				BG.IsAutoCaption AS bgIsAutoCaption,
				BG.IsSegmentedMaterial AS bgIsSegmentedMaterial,
				BG.IsCodeInsteadName AS bgIsCodeInsteadName,
				BG.WeekDays bgWeekDays,
				BG.FromTime bgFromTime,
				BG.ToTime bgToTime,
				ISNULL(bm.Name, '') bgPictureName,
				BG.BColor,
				BG.FColor,
				BG.IsThemeColors,
				@ItemNumber + (ROW_NUMBER() OVER(ORDER BY mt.Number ASC)),	-- bgiNumber
				NEWID(),				-- bgiGUID,
				0,						-- bgiType
				@bgGUID,
				0,						-- bgiCommand
				mt.GUID,				-- bgiItemID,
				((CASE @lang 
						WHEN 0 THEN MT.Name
						ELSE CASE MT.LatinName WHEN '' THEN MT.Name ELSE MT.LatinName END 
					END )
					 + (CASE WHEN mt.Parent = 0x0 OR mt.Parent IS NULL 
									THEN '' 
									ELSE ' (' + (CASE WHEN BG.IsCodeInsteadName = 1 THEN mt.Code ELSE mt.CompositionName END) + ')' END))
				AS bgiCaption,
				(mt.LatinName  + (CASE WHEN mt.Parent = 0x0 OR mt.Parent IS NULL OR mt.LatinName = '' 
										THEN '' 
										ELSE ' (' + (CASE WHEN BG.IsCodeInsteadName = 1 THEN mt.Code ELSE mt.CompositionLatinName END) + ')' END))
				AS bgiLatinCaption,					
				dbo.fnGetMtPriceByType (@PriceType, mt.GUID, mt.DefUnit),
				@BColor,				-- bgiBColor,
				@FColor,				-- bgiFColor,
				ISNULL(bm1.GUID, 0x0),	-- bgiPictureID,
				0,						-- bgiPictureAlignment,
				@PictureFactor,			-- bgiPictureFactor,
				1,						-- bgiIsThemeColors,
				1,						-- bgiIsAutoCaption
				ISNULL(bm1.Name, ''),   -- bgiPictureName
				MT.HasSegments AS bgiHasSegments,
				BGI.IsCodeInsteadName AS bgiIsCodeInsteadName	
			FROM 
				BG000 BG
				INNER JOIN gr000 gr ON gr.GUID = BG.GroupGUID		
				INNER JOIN mt000 mt ON mt.GroupGUID = gr.GUID
				LEFT JOIN BGI000 BGI ON BGI.ParentID = Bg.Guid AND BGI.ItemID = mt.GUID
				LEFT JOIN bm000 bm ON bm.GUID = BG.PictureID		
				LEFT JOIN bm000 bm1 ON bm1.GUID = mt.PictureGUID
			WHERE 
				bg.GUID = @bgGUID
				AND
				BGI.GUID IS NULL 
				AND 
				ISNULL(mt.bHide, 0) = 0
				AND ((mt.Parent = (CASE WHEN BG.IsSegmentedMaterial = 1 THEN 0x0 ELSE  mt.Parent END) OR mt.Parent IS NULL)
						AND ( mt.HasSegments <> (CASE WHEN BG.IsSegmentedMaterial = 0 THEN 1 ELSE 0 END )))
			ORDER BY 
				mt.Number
			FETCH NEXT FROM @bgC INTO @bgGUID
		END 
		CLOSE @bgc
		DEALLOCATE @bgc
		
	END 
	SELECT 
		* 
	FROM 
		#RestBG
	WHERE
		bgiCaption IS NOT NULL
	ORDER BY 
		bgTYPE, bgNumber, bgiNumber


#########################################
#END
