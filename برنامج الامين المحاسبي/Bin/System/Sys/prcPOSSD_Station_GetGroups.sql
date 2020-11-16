#################################################################
CREATE PROCEDURE prcPOSSD_Station_GetGroups @POSCardGuid UNIQUEIDENTIFIER
AS
BEGIN
	DECLARE @Groups TABLE
	(
		Number		INT,
		GroupGUID	UNIQUEIDENTIFIER,  
		Name		NVARCHAR(MAX),
		Code		NVARCHAR(MAX),
		ParentGUID	UNIQUEIDENTIFIER,  
		LatinName	NVARCHAR(MAX),
		PictureGUID UNIQUEIDENTIFIER,
		GroupIndex	INT		
	);

	WITH GroupTree (Number,Guid,Name,Code, ParentGUID,LatinName,PictureGUID,Level)
	AS
	(
	   SELECT GR.Number,GR.Guid, GR.Name, GR.Code, GR.ParentGUID, GR.LatinName, GR.PictureGUID, 0 AS Tree
	   FROM gr000 AS GR INNER JOIN POSSDStationGroup000  AS POSGR ON (POSGR.GroupGUID = GR.GUID)
	   WHERE POSGR.StationGUID = @POSCardGuid   
	   UNION ALL
	   SELECT GR.Number,GR.Guid, GR.Name, GR.Code, GR.ParentGUID, GR.LatinName, GR.PictureGUID,GrTree.Level
	   FROM gr000 AS GR  JOIN GROUPTree AS GrTree ON (GR.ParentGUID = GrTree.Guid)
	)
	 
	INSERT INTO @Groups(Number, GroupGUID, Name, Code, ParentGUID, LatinName, PictureGUID, GroupIndex)
	SELECT 
		Number,Guid,Name,Code, ParentGUID,LatinName,PictureGUID,Level
	FROM GroupTree;

	WITH GroupCompundTree (Number,Guid,Name,Code, ParentGUID,LatinName,PictureGUID,Level)
	AS
	(
	   SELECT GRD.Number,GRD.Guid, GRD.Name, GRD.Code, GRD.ParentGUID, GRD.LatinName, GRD.PictureGUID, 0 AS Tree
	   FROM gr000 AS GR INNER JOIN POSSDStationGroup000  AS POSGR ON (POSGR.GroupGUID = GR.GUID)
	   INNER JOIN gri000 AS GRI ON (GRI.GroupGuid = GR.GUID)
	   INNER JOIN gr000 AS GRD ON (GRD.GUID = GRI.MatGuid AND GRI.ItemType = 0)
	   WHERE  POSGR.StationGUID = @POSCardGuid AND GR.KIND = 1		   
	   UNION ALL
	   SELECT GR.Number,GR.Guid, GR.Name, GR.Code, GR.ParentGUID, GR.LatinName, GR.PictureGUID, GrTree.Level
	   FROM gr000 AS GR  JOIN GroupCompundTree AS GrTree ON (GR.ParentGUID = GrTree.Guid)   
	 
	)	
	
	INSERT INTO @Groups(Number, GroupGUID, Name, Code, ParentGUID, LatinName, PictureGUID, GroupIndex)
	SELECT 
		GRT.Number, GRT.Guid, GRT.Name, GRT.Code, GRT.ParentGUID, GRT.LatinName, GRT.PictureGUID, GRT.Level
	FROM GroupCompundTree AS GRT 
	LEFT JOIN @Groups AS GR ON (GR.GroupGUID = GRT.Guid )
	WHERE GR.GroupGUID IS NULL;

	WITH GroupCompundWithCompoundTree (Number,Guid,Name,Code, ParentGUID,LatinName,PictureGUID,Level)
	AS
	(
	   SELECT GR.Number,GR.Guid, GR.Name, GR.Code, GR.ParentGUID, GR.LatinName, GR.PictureGUID, 0 AS Tree
	   FROM gri000 AS GRI INNER JOIN @Groups  AS POSGR ON (POSGR.GroupGUID = GRI.MatGuid AND GRI.ItemType = 0)
	   INNER JOIN gr000 AS GR ON (GR.GUID = GRI.MatGuid )	
	   UNION ALL
	   SELECT GR.Number,GR.Guid, GR.Name, GR.Code, GR.ParentGUID, GR.LatinName, GR.PictureGUID, GrTree.Level
	   FROM gri000 AS GRI  JOIN GroupCompundWithCompoundTree AS GrTree ON (GRI.GroupGuid = GrTree.Guid) 
	   INNER JOIN gr000 AS GR ON (GR.GUID = GRI.MatGuid AND GRI.ItemType = 0 )
	)	
	INSERT INTO @Groups(Number, GroupGUID, Name, Code, ParentGUID, LatinName, PictureGUID, GroupIndex)
	SELECT 
		GCWCT.Number, GCWCT.Guid, GCWCT.Name, GCWCT.Code, GCWCT.ParentGUID, GCWCT.LatinName, GCWCT.PictureGUID, GCWCT.Level
	FROM GroupCompundWithCompoundTree AS GCWCT 
	LEFT JOIN @Groups AS GR ON (GR.GroupGUID = GCWCT.Guid )
	WHERE GR.GroupGUID IS NULL;
	SELECT 
		SGR.Number,
		SGR.GroupGUID,  
		SGR.Name,
		SGR.Code,
		SGR.ParentGUID,  
		SGR.LatinName,
		SGR.PictureGUID ,		
		0 AS GroupIndex,
		GR.KIND AS Groupkind
	 FROM @Groups AS SGR INNER JOIN gr000 AS GR ON (GR.GUID = SGR.GroupGUID)
	 GROUP BY SGR.Number,
		SGR.GroupGUID,  
		SGR.Name,
		SGR.Code,
		SGR.ParentGUID,  
		SGR.LatinName,
		SGR.PictureGUID,
		GR.KIND;
END
#################################################################
CREATE PROCEDURE prcPOSSD_Station_GetNewGroup
@POSCardGuid UNIQUEIDENTIFIER,
@DeviceId NVARCHAR(250),
@DataAction NVARCHAR(5),
@PageSize	 INT = 200,
@PageIndex	 INT = 0
AS
BEGIN
	
	/*******************************************************************************************************
	Company : Syriansoft
	SP : prcPOSSD_Station_GetNewGroup
	Purpose: get all new items that are related to a specific POS Station
	How to Call: EXEC prcPOSSD_Station_GetNewGroup '3C2561FE-406C-446D-AFE3-6212319487F8','bcT5wzaMH7IkPgGQBlQClXtinXcSnh0uJ4Pu1OSgccA=','CU',1000,0
	Create By: Hanadi Salka													Created On: 28 Oct 2019
	Updated On:																Updated By:
	Change Note:
	********************************************************************************************************/
	DECLARE @Groups TABLE
	(
		Number int ,
		GroupGUID UNIQUEIDENTIFIER,  
		Name NVARCHAR(MAX),
		Code NVARCHAR(MAX),
		ParentGUID UNIQUEIDENTIFIER,  
		LatinName  NVARCHAR(MAX),
		PictureGUID UNIQUEIDENTIFIER,
		GroupIndex	INT,
		Groupkind	TINYINT
	) 
	-- *******************************************************************************************
	-- Get the group related to the pos station
	INSERT INTO @Groups (Number,GroupGUID, Name,Code, ParentGUID, LatinName, PictureGUID, GroupIndex, Groupkind)
	EXEC prcPOSSD_Station_GetGroups @POSCardGuid;	
	-- **************************************************************
	-- GET NEW GROUPS
	IF @DataAction = 'C'
		BEGIN
			SELECT	
				gr.Number,
				gr.GUID AS GroupGUID,
				gr.Name AS Name,
				gr.Code AS Code,
				gr.ParentGUID AS ParentGUID,
				gr.LatinName AS LatinName,
				gr.PictureGUID AS PictureGUID,
				0 AS GroupIndex,
				GR.Kind AS Groupkind
			FROM POSSDStationSyncModifiedData000 AS NGR
			INNER JOIN gr000 gr ON ((NGR.RelatedToObject = 'GR000') AND (gr.[GUID] = NGR.ReleatedToObjectGuid ))
			INNER JOIN @Groups AS SGRP ON (gr.GUID = SGRP.GroupGUID)
			INNER JOIN POSSDStationDevice000 AS POSD ON (NGR.StationGuid = POSD.StationGUID  AND POSD.DeviceID = NGR.DeviceID)			
			WHERE NGR.StationGuid = @POSCardGuid
					AND NGR.DeviceID = @DeviceId
					AND NGR.IsNewDataSync = 0
					AND POSD.ActiveFlag = 1		
			ORDER BY Number OFFSET (@PageSize * @PageIndex)  ROWS FETCH NEXT @PageSize ROWS ONLY;		
		END;
	ELSE IF @DataAction = 'U'
		BEGIN
			SELECT	
				gr.Number,
				gr.GUID AS GroupGUID,
				gr.Name AS Name,
				gr.Code AS Code,
				gr.ParentGUID AS ParentGUID,
				gr.LatinName AS LatinName,
				gr.PictureGUID AS PictureGUID,
				0 AS GroupIndex,
				GR.Kind AS Groupkind
			FROM POSSDStationSyncModifiedData000 AS NGR
			INNER JOIN gr000 gr ON ((NGR.RelatedToObject = 'GR000') AND (gr.[GUID] = NGR.ReleatedToObjectGuid ))
			INNER JOIN @Groups AS SGRP ON (gr.GUID = SGRP.GroupGUID)
			INNER JOIN POSSDStationDevice000 AS POSD ON (NGR.StationGuid = POSD.StationGUID  AND POSD.DeviceID = NGR.DeviceID)			
			WHERE NGR.StationGuid = @POSCardGuid
					AND NGR.DeviceID = @DeviceId
					AND NGR.IsModifiedDataSync = 0
					AND POSD.ActiveFlag = 1		
			ORDER BY Number OFFSET (@PageSize * @PageIndex)  ROWS FETCH NEXT @PageSize ROWS ONLY;		
		END;
	ELSE IF @DataAction = 'CU'
		BEGIN
			SELECT	
				gr.Number,
				gr.GUID AS GroupGUID,
				gr.Name AS Name,
				gr.Code AS Code,
				gr.ParentGUID AS ParentGUID,
				gr.LatinName AS LatinName,
				gr.PictureGUID AS PictureGUID,
				0 AS GroupIndex,
				GR.Kind AS Groupkind
			FROM POSSDStationSyncModifiedData000 AS NGR
			INNER JOIN gr000 gr ON ((NGR.RelatedToObject = 'GR000') AND (gr.[GUID] = NGR.ReleatedToObjectGuid ))
			INNER JOIN @Groups AS SGRP ON (gr.GUID = SGRP.GroupGUID)
			INNER JOIN POSSDStationDevice000 AS POSD ON (NGR.StationGuid = POSD.StationGUID  AND POSD.DeviceID = NGR.DeviceID)			
			WHERE NGR.StationGuid = @POSCardGuid
					AND NGR.DeviceID = @DeviceId
					AND (NGR.IsNewDataSync = 0 OR NGR.IsModifiedDataSync = 0)
					AND POSD.ActiveFlag = 1		
			ORDER BY Number OFFSET (@PageSize * @PageIndex)  ROWS FETCH NEXT @PageSize ROWS ONLY;		
		END;
END
#################################################################
CREATE PROCEDURE prcPOSSD_Station_GetNewGroupImageList
 @POSCardGuid UNIQUEIDENTIFIER,
 @DeviceId NVARCHAR(250),
 @DataAction NVARCHAR(5),
 @PageSize INT = 20,
 @PageIndex INT = 0
AS
BEGIN
	/*******************************************************************************************************
	Company : Syriansoft
	SP : prcPOSSD_Station_GetNewGroupImageList
	Purpose: get group image for a specific pos station 
	How to Call: EXEC prcPOSSD_Station_GetNewGroupImageList '3C2561FE-406C-446D-AFE3-6212319487F8','bcT5wzaMH7IkPgGQBlQClXtinXcSnh0uJ4Pu1OSgccA=','C',1000,0
	Create By: 											Created On: 
	Updated On:	Hanadi Salka							Updated By: 12-Nov-2019
	Change Note:
	********************************************************************************************************/
	DECLARE @Groups TABLE
	(
		Number int ,
		GroupGUID UNIQUEIDENTIFIER,  
		Name NVARCHAR(MAX),
		Code NVARCHAR(MAX),
		ParentGUID UNIQUEIDENTIFIER,  
		LatinName  NVARCHAR(MAX),
		PictureGUID UNIQUEIDENTIFIER,
		GroupIndex	INT,
		Groupkind	TINYINT
	) 
	-- *******************************************************************************************
	-- Get the group related to the pos station
	INSERT INTO @Groups (Number,GroupGUID, Name,Code, ParentGUID, LatinName, PictureGUID, GroupIndex, Groupkind)
	EXEC prcPOSSD_Station_GetGroups @POSCardGuid;	

	IF @DataAction = 'C'
	BEGIN
		SELECT		
			GRP.Number AS SourceNumber,
			GRP.Code AS SourceCode,
			GRP.PictureGUID AS ImageGuid,
			GRP.GUID AS SourceGuid,
			BM.Name AS ImageFilePath
		FROM POSSDStationSyncModifiedData000 AS NGR
		INNER JOIN gr000 AS GRP ON ((NGR.RelatedToObject = 'GR000') AND (GRP.[GUID] = NGR.ReleatedToObjectGuid ))
		INNER JOIN @Groups AS SGRP ON (GRP.GUID = SGRP.GroupGUID)
		INNER JOIN bm000 AS BM on (BM.GUID = GRP.PictureGUID) 
		INNER JOIN POSSDStationDevice000 AS POSD ON (NGR.StationGuid = POSD.StationGUID  AND POSD.DeviceID = NGR.DeviceID)			
		WHERE NGR.StationGuid = @POSCardGuid
				AND NGR.DeviceID = @DeviceId
				AND NGR.IsNewDataSync = 0
				AND POSD.ActiveFlag = 1		
		ORDER BY GRP.Number OFFSET (@PageSize * @PageIndex)  ROWS FETCH NEXT @PageSize ROWS ONLY;
	END;
	ELSE IF @DataAction = 'U'
	BEGIN
		SELECT		
			GRP.Number AS SourceNumber,
			GRP.Code AS SourceCode,
			GRP.PictureGUID AS ImageGuid,
			GRP.GUID AS SourceGuid,
			BM.Name AS ImageFilePath
		FROM POSSDStationSyncModifiedData000 AS NGR
		INNER JOIN gr000 AS GRP ON ((NGR.RelatedToObject = 'GR000') AND (GRP.[GUID] = NGR.ReleatedToObjectGuid ))
		INNER JOIN @Groups AS SGRP ON (GRP.GUID = SGRP.GroupGUID)
		INNER JOIN bm000 AS BM on (BM.GUID = GRP.PictureGUID) 
		INNER JOIN POSSDStationDevice000 AS POSD ON (NGR.StationGuid = POSD.StationGUID  AND POSD.DeviceID = NGR.DeviceID)			
		WHERE NGR.StationGuid = @POSCardGuid
				AND NGR.DeviceID = @DeviceId
				AND NGR.IsModifiedDataSync = 0
				AND POSD.ActiveFlag = 1		
		ORDER BY GRP.Number OFFSET (@PageSize * @PageIndex)  ROWS FETCH NEXT @PageSize ROWS ONLY;
	END;	
	ELSE IF @DataAction = 'CU'
	BEGIN
		SELECT		
			GRP.Number AS SourceNumber,
			GRP.Code AS SourceCode,
			GRP.PictureGUID AS ImageGuid,
			GRP.GUID AS SourceGuid,
			BM.Name AS ImageFilePath
		FROM POSSDStationSyncModifiedData000 AS NGR
		INNER JOIN gr000 AS GRP ON ((NGR.RelatedToObject = 'GR000') AND (GRP.[GUID] = NGR.ReleatedToObjectGuid ))
		INNER JOIN @Groups AS SGRP ON (GRP.GUID = SGRP.GroupGUID)
		INNER JOIN bm000 AS BM on (BM.GUID = GRP.PictureGUID) 
		INNER JOIN POSSDStationDevice000 AS POSD ON (NGR.StationGuid = POSD.StationGUID  AND POSD.DeviceID = NGR.DeviceID)			
		WHERE NGR.StationGuid = @POSCardGuid
				AND NGR.DeviceID = @DeviceId
				AND (NGR.IsNewDataSync = 0 OR NGR.IsModifiedDataSync = 0)
				AND POSD.ActiveFlag = 1		
		ORDER BY GRP.Number OFFSET (@PageSize * @PageIndex)  ROWS FETCH NEXT @PageSize ROWS ONLY;
	END;	
END;
#################################################################
CREATE PROCEDURE prcPOSSD_Station_GetRelatedChildGroup @GroupGuidList NVARCHAR(MAX)
AS
BEGIN
	/*******************************************************************************************************
	Company : Syriansoft
	SP : prcPOSSD_Station_GetRelatedGroup
	Purpose: Get releated group of pos station based on the list of group guid
	Create By: Hanadi Salka													Created On: 19 Nov 2019
	Updated On:																Updated By:
	Change Note:
	********************************************************************************************************/
	DECLARE @Groups					TABLE (StationGUID	UNIQUEIDENTIFIER,
										   DeviceID		NVARCHAR(250),
										   Guid			UNIQUEIDENTIFIER,  
										   Name			NVARCHAR(300),						   
										   ParentGUID	UNIQUEIDENTIFIER, 						   
										   Level  INT);
	DECLARE @GroupGuid			TABLE ( Guid   UNIQUEIDENTIFIER);
	DECLARE @ChildGuid			TABLE ( Guid   UNIQUEIDENTIFIER);
	DECLARE @Count				INT;		
	-- *******************************************************************
	-- convert comma seprated list into rows for inner join
	INSERT INTO @GroupGuid(Guid)
	SELECT *
	FROM dbo.FnStringLibSplitString (@GroupGuidList, ',');
	-- ****************************************************************************************
	WITH GroupChildTree (Guid,Name, ParentGUID,Level)
	AS
	(
	   SELECT GR.Guid, GR.Name, GR.ParentGUID, 0 AS Tree 
	   FROM gr000 AS GR INNER JOIN @GroupGuid  AS IGR ON (IGR.GUID = GR.GUID)	   
	   UNION ALL
	   SELECT GR.GUID, GR.Name, GR.ParentGUID , GrTree.Level + 1
	   FROM gr000 AS GR  JOIN GroupChildTree AS GrTree ON (GR.ParentGUID = GrTree.Guid)
	)
	INSERT INTO @ChildGuid(Guid)
	SELECT 
		GR.Guid
	FROM GroupChildTree AS GR;	
	
	-- ****************************************************************************************
	-- get the group and their children
	WITH GroupTree (StationGUID, DeviceID, Guid,Name, ParentGUID,Level)
	AS
	(
	   SELECT POSGR.StationGUID, POSD.DeviceID, GR.Guid, GR.Name, GR.ParentGUID, 0 AS Tree 
	   FROM gr000 AS GR INNER JOIN @ChildGuid  AS DGR ON (DGR.GUID = GR.GUID)
	   INNER JOIN POSSDStationGroup000 AS POSGR ON (POSGR.GroupGUID = GR.GUID)	  	
	   INNER JOIN POSSDStationDevice000 AS POSD ON (POSGR.StationGUID = POSD.StationGUID)   
	   UNION ALL
	   SELECT GrTree.StationGUID, GrTree.DeviceID,GR.GUID, GR.Name, GR.ParentGUID , GrTree.Level + 1
	   FROM gr000 AS GR  JOIN GROUPTree AS GrTree ON (GR.ParentGUID = GrTree.Guid)
	)
	INSERT INTO @Groups(StationGUID, DeviceID, Guid, Name, ParentGUID, Level)
	SELECT 
		GR.StationGUID, GR.DeviceID, GR.Guid, GR.Name, GR.ParentGUID, GR.Level
	FROM GroupTree AS GR;
	
	-- ****************************************************************************************
	-- get the collective group and their children
	WITH GroupCompundTree (StationGUID, DeviceID, Guid, Name, ParentGUID, Level)
	AS
	(
	   SELECT POSGR.StationGUID, POSD.DeviceID,GRD.Guid, GRD.Name, GRD.ParentGUID, 0 AS Tree 
	   FROM gr000 AS GR INNER JOIN @ChildGuid  AS DGR ON (DGR.GUID = GR.GUID)
	   INNER JOIN POSSDStationGroup000 AS POSGR ON (POSGR.GroupGUID = GR.GUID)	  
	   INNER JOIN POSSDStationDevice000 AS POSD ON (POSGR.StationGUID = POSD.StationGUID)
	   INNER JOIN gri000 AS GRI ON (GRI.GroupGuid = GR.GUID)
	   INNER JOIN gr000 AS GRD ON (GRD.GUID = GRI.MatGuid AND GRI.ItemType = 0)
	   WHERE  GR.KIND = 1		   
	   UNION ALL
	   SELECT GrTree.StationGUID, GrTree.DeviceID,GR.Guid, GR.Name, GR.ParentGUID, GrTree.Level + 1
	   FROM gr000 AS GR  JOIN GroupCompundTree AS GrTree ON (GR.ParentGUID = GrTree.Guid)   
	 
	)
	INSERT INTO @Groups(StationGUID,DeviceID, Guid, Name, ParentGUID, Level)
	SELECT 
		GRT.StationGUID, GRT.DeviceID,GRT.Guid,GRT.Name,GRT.ParentGUID,GRT.Level
	FROM GroupCompundTree AS GRT 
	LEFT JOIN @Groups AS GR ON (GR.GUID = GRT.Guid )
	WHERE GR.GUID IS NULL;


	WITH GroupCompundTree (StationGUID, DeviceID, Guid, Name, ParentGUID, Level)
	AS
	(
	   SELECT POSGR.StationGUID, POSD.DeviceID,GR.Guid, GR.Name, GR.ParentGUID, 0 AS Tree 
	   FROM gr000 AS GR INNER JOIN @ChildGuid  AS DGR ON (DGR.GUID = GR.GUID)
	   INNER JOIN gri000 AS GRI ON (GRI.MATGuid = GR.GUID AND GRI.ItemType = 0)
	   INNER JOIN POSSDStationGroup000 AS POSGR ON (POSGR.GroupGUID = GRI.GroupGuid)	  
	   INNER JOIN POSSDStationDevice000 AS POSD ON (POSGR.StationGUID = POSD.StationGUID)	
	   UNION ALL
	   SELECT GrTree.StationGUID, GrTree.DeviceID,GR.Guid, GR.Name, GR.ParentGUID, GrTree.Level + 1
	   FROM gr000 AS GR  JOIN GroupCompundTree AS GrTree ON (GR.ParentGUID = GrTree.Guid)   
	 
	)
	INSERT INTO @Groups(StationGUID,DeviceID, Guid, Name, ParentGUID, Level)
	SELECT 
		GRT.StationGUID, GRT.DeviceID,GRT.Guid,GRT.Name,GRT.ParentGUID,GRT.Level
	FROM GroupCompundTree AS GRT 
	LEFT JOIN @Groups AS GR ON (GR.GUID = GRT.Guid )
	WHERE GR.GUID IS NULL;

	-- ****************************************************************************************
	-- get the collective group and their children level two
	WITH GroupCompundWithCompoundTree (StationGUID, DeviceID, Guid,Name, ParentGUID,Level)
	AS
	(
	   SELECT POSGR.StationGUID, POSD.DeviceID,GR.Guid, GR.Name, GR.ParentGUID, 0 AS Tree 
	   FROM gri000 AS GRI INNER JOIN @Groups  AS POSGR ON (POSGR.GUID = GRI.MatGuid AND GRI.ItemType = 0)
	   INNER JOIN POSSDStationDevice000 AS POSD ON (POSGR.StationGUID = POSD.StationGUID)
	   INNER JOIN gr000 AS GR ON (GR.GUID = GRI.MatGuid )	
	   UNION ALL
	   SELECT GrTree.StationGUID, GrTree.DeviceID,GR.Guid, GR.Name, GR.ParentGUID, GrTree.Level + 1	  
	   FROM gri000 AS GRI  JOIN GroupCompundWithCompoundTree AS GrTree ON (GRI.GroupGuid = GrTree.Guid) 
	   INNER JOIN gr000 AS GR ON (GR.GUID = GRI.MatGuid AND GRI.ItemType = 0 )
	)	
	INSERT INTO @Groups(StationGUID,DeviceID, Guid, Name, ParentGUID, Level)
	SELECT 
		GCWCT.StationGUID, GCWCT.DeviceID, GCWCT.Guid, GCWCT.Name, GCWCT.ParentGUID, GCWCT.Level	
	FROM GroupCompundWithCompoundTree AS GCWCT 
	LEFT JOIN @Groups AS GR ON (GR.GUID = GCWCT.Guid )
	WHERE GR.GUID IS NULL;
	-- ********************************************************
	-- get all groups group by pos station, device and group
	SELECT @Count	= COUNT(*) FROM @Groups;
	IF @Count > 0 
		BEGIN
			SELECT 
			StationGUID, DeviceID, Guid,Name, ParentGUID
			FROM @Groups
			UNION 
			SELECT 
				POSGR.StationGUID,
				POSGR.DeviceID,
				PGR.Guid,
				GR.Name,
				GR.ParentGUID
			FROM @ChildGuid AS PGR INNER JOIN GR000 AS GR ON (GR.GUID = PGR.Guid)
			CROSS JOIN @Groups AS POSGR 	  
		END;
	ELSE
		SELECT 
		StationGUID, DeviceID, Guid,Name, ParentGUID
		FROM @Groups;
END;
#################################################################
CREATE PROCEDURE prcPOSSD_Station_GetRelatedParentGroup @GroupGuidList NVARCHAR(MAX)
AS
BEGIN
	/*******************************************************************************************************
	Company : Syriansoft
	SP : prcPOSSD_Station_GetRelatedGroup
	Purpose: Get releated group of pos station based on the list of group guid
	Create By: Hanadi Salka													Created On: 19 Nov 2019
	Updated On:																Updated By:
	Change Note:
	********************************************************************************************************/
	DECLARE @Groups					TABLE (StationGUID	UNIQUEIDENTIFIER,
										   DeviceID		NVARCHAR(250),
										   Guid			UNIQUEIDENTIFIER,  
										   Name			NVARCHAR(300),						   
										   ParentGUID	UNIQUEIDENTIFIER, 						   
										   Level  INT);

	DECLARE @GroupGuid			TABLE ( Guid   UNIQUEIDENTIFIER);
	DECLARE @ParentGuid			TABLE ( Guid   UNIQUEIDENTIFIER);
	DECLARE @Count				INT;			
	-- *******************************************************************
	-- convert comma seprated list into rows for inner join
	INSERT INTO @GroupGuid(Guid)
	SELECT *
	FROM dbo.FnStringLibSplitString (@GroupGuidList, ',');
	
	WITH GroupParentTree ( Guid,Name, ParentGUID,Level)
	AS
	(
	   SELECT GR.Guid, GR.Name, GR.ParentGUID, 0 AS Tree 
	   FROM gr000 AS GR INNER JOIN @GroupGuid  AS IGR ON (IGR.GUID = GR.GUID)	   	  	
	    
	   UNION ALL
	   SELECT GR.GUID, GR.Name, GR.ParentGUID , GrTree.Level + 1
	   FROM gr000 AS GR  JOIN GroupParentTree AS GrTree ON ((GR.Guid = GrTree.ParentGUID) AND (GrTree.ParentGuid IS NOT NULL OR  GrTree.ParentGuid != '00000000-0000-0000-0000-000000000000'))
	)
	INSERT INTO @ParentGuid(Guid)
	SELECT 
		GR.Guid
	FROM GroupParentTree AS GR;	
	-- ****************************************************************************************
	-- get the group and their children
	WITH GroupTree (StationGUID, DeviceID, Guid,Name, ParentGUID,Level)
	AS
	(
	   SELECT POSGR.StationGUID, POSD.DeviceID, GR.Guid, GR.Name, GR.ParentGUID, 0 AS Tree 
	   FROM gr000 AS GR INNER JOIN @ParentGuid  AS DGR ON (DGR.GUID = GR.GUID)
	   INNER JOIN POSSDStationGroup000 AS POSGR ON (POSGR.GroupGUID = GR.GUID)	  	
	   INNER JOIN POSSDStationDevice000 AS POSD ON (POSGR.StationGUID = POSD.StationGUID)   
	   UNION ALL
	   SELECT GrTree.StationGUID, GrTree.DeviceID,GR.GUID, GR.Name, GR.ParentGUID , GrTree.Level + 1
	   FROM gr000 AS GR  JOIN GROUPTree AS GrTree ON ((GR.Guid = GrTree.ParentGUID) )
	)

	INSERT INTO @Groups(StationGUID, DeviceID, Guid, Name, ParentGUID, Level)
	SELECT 
		GR.StationGUID, GR.DeviceID, GR.Guid, GR.Name, GR.ParentGUID, GR.Level
	FROM GroupTree AS GR;
	
	-- ****************************************************************************************
	-- get the collective group and their children
	WITH GroupCompundTree (StationGUID, DeviceID, Guid,Name, ParentGUID,Level)
	AS
	(
	   SELECT POSGR.StationGUID, POSD.DeviceID,GRD.Guid, GRD.Name, GRD.ParentGUID, 0 AS Tree 
	   FROM gr000 AS GR INNER JOIN @ParentGuid  AS DGR ON (DGR.GUID = GR.GUID)
	   INNER JOIN POSSDStationGroup000 AS POSGR ON (POSGR.GroupGUID = GR.GUID)	  
	   INNER JOIN POSSDStationDevice000 AS POSD ON (POSGR.StationGUID = POSD.StationGUID)
	   INNER JOIN gri000 AS GRI ON (GRI.GroupGuid = GR.GUID)
	   INNER JOIN gr000 AS GRD ON (GRD.GUID = GRI.MatGuid AND GRI.ItemType = 0)
	   WHERE  GR.KIND = 1		   
	   UNION ALL
	   SELECT GrTree.StationGUID, GrTree.DeviceID,GR.Guid, GR.Name, GR.ParentGUID, GrTree.Level + 1
	   FROM gr000 AS GR  JOIN GroupCompundTree AS GrTree ON ((GR.Guid = GrTree.ParentGUID) AND (GrTree.ParentGuid IS NOT NULL AND  GrTree.ParentGuid != '00000000-0000-0000-0000-000000000000'  ))   
	 
	)
	INSERT INTO @Groups(StationGUID,DeviceID, Guid, Name, ParentGUID, Level)
	SELECT 
		GRT.StationGUID, GRT.DeviceID,GRT.Guid,GRT.Name,GRT.ParentGUID,GRT.Level
	FROM GroupCompundTree AS GRT 
	LEFT JOIN @Groups AS GR ON (GR.GUID = GRT.Guid )
	WHERE GR.GUID IS NULL;

	-- ****************************************************************************************
	-- get the collective group and their children level two
	WITH GroupCompundWithCompoundTree (StationGUID, DeviceID, Guid,Name, ParentGUID,Level)
	AS
	(
	   SELECT POSGR.StationGUID, POSD.DeviceID,GR.Guid, GR.Name, GR.ParentGUID, 0 AS Tree 
	   FROM gri000 AS GRI INNER JOIN @Groups  AS POSGR ON (POSGR.GUID = GRI.MatGuid AND GRI.ItemType = 0)
	   INNER JOIN POSSDStationDevice000 AS POSD ON (POSGR.StationGUID = POSD.StationGUID)
	   INNER JOIN gr000 AS GR ON (GR.GUID = GRI.MatGuid )	
	   UNION ALL
	   SELECT GrTree.StationGUID, GrTree.DeviceID,GR.Guid, GR.Name, GR.ParentGUID, GrTree.Level + 1	  
	   FROM gri000 AS GRI  JOIN GroupCompundWithCompoundTree AS GrTree ON (GRI.GroupGuid = GrTree.Guid) 
	   INNER JOIN gr000 AS GR ON (GR.GUID = GRI.MatGuid AND GRI.ItemType = 0 )
	)	
	INSERT INTO @Groups(StationGUID,DeviceID, Guid, Name, ParentGUID, Level)
	SELECT 
		GCWCT.StationGUID, GCWCT.DeviceID, GCWCT.Guid, GCWCT.Name, GCWCT.ParentGUID, GCWCT.Level	
	FROM GroupCompundWithCompoundTree AS GCWCT 
	LEFT JOIN @Groups AS GR ON (GR.GUID = GCWCT.Guid )
	WHERE GR.GUID IS NULL;

	-- ********************************************************
	-- get all groups group by pos station, device and group
	/*SELECT * 
	FROM @Groups;*/
	SELECT @Count	= COUNT(*) FROM @Groups;
	IF @Count > 0 
		BEGIN
			SELECT 
			StationGUID, DeviceID, Guid,Name, ParentGUID
			FROM @Groups
			UNION 
			SELECT 
				POSGR.StationGUID,
				POSGR.DeviceID,
				PGR.Guid,
				GR.Name,
				GR.ParentGUID
			FROM @ParentGuid AS PGR INNER JOIN GR000 AS GR ON (GR.GUID = PGR.Guid)
			CROSS JOIN @Groups AS POSGR 	  
		END;
	ELSE
		SELECT 
		StationGUID, DeviceID, Guid,Name, ParentGUID
		FROM @Groups;
END;
#################################################################
#END 