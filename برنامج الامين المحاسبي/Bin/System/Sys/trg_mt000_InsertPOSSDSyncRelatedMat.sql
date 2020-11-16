################################################################################
CREATE TRIGGER trg_mt000_InsertPOSSDSyncRelatedMat
   ON  MT000
   AFTER INSERT 
AS 
BEGIN
	/*******************************************************************************************************
	Company : Syriansoft
	SP : trg_mt000_InsertPOSSDSyncRelatedMat
	Purpose: insert new items that are related to the groups associated with POS for smart devices
	Create By: Hanadi Salka													Created On: 28 Aug 2019
	Updated On:																Updated By:
	Change Note:
	********************************************************************************************************/
	DECLARE @CreatedOn				DATETIME = SYSUTCDATETIME();
	DECLARE @IsModifiedDataSync		INT = -1;
	DECLARE @Groups TABLE (
						   StationGUID	UNIQUEIDENTIFIER,
						   DeviceID  NVARCHAR(250),
						   Guid   UNIQUEIDENTIFIER,  
						   Name		   NVARCHAR(300),						   
						   ParentGUID  UNIQUEIDENTIFIER, 						   
						   Level  INT)	;
	-- DO NOT INSERT ITEMS THAT HAS PARENT COMPOUND ITEM
	IF NOT EXISTS(SELECT * FROM [inserted] WHERE [Parent] = 0x0)
	RETURN;
	-- ******************************************************************************************************
	-- GET ALL GROUPS IN POSSTATION
	WITH GroupTree (StationGUID, DeviceID, Guid,Name, ParentGUID,Level)
	AS
	(
	   SELECT POSGR.StationGUID, POSD.DeviceID , GR.Guid, GR.Name, GR.ParentGUID, 0 AS Tree 
	   FROM gr000 AS GR INNER JOIN POSSDStationGroup000 AS POSGR ON (POSGR.GroupGUID = GR.GUID)	  
	   INNER JOIN POSSDStationDevice000 AS POSD ON (POSGR.StationGUID = POSD.StationGUID)   
	   UNION ALL
	   SELECT GrTree.StationGUID, GrTree.DeviceID, GR.GUID, GR.Name, GR.ParentGUID , GrTree.Level + 1
	   FROM gr000 AS GR  JOIN GROUPTree AS GrTree ON (GR.ParentGUID = GrTree.Guid)
	)
	INSERT INTO @Groups(StationGUID, DeviceID, Guid, Name, ParentGUID, Level)
	SELECT 
		GR.StationGUID, GR.DeviceID, GR.Guid, GR.Name, GR.ParentGUID, GR.Level
	FROM GroupTree AS GR;

	WITH GroupCompundTree (StationGUID, DeviceID, Guid,Name, ParentGUID,Level)
	AS
	(
	   SELECT POSGR.StationGUID, POSD.DeviceID,GRD.Guid, GRD.Name, GRD.ParentGUID, 0 AS Tree 
	   FROM gr000 AS GR INNER JOIN POSSDStationGroup000  AS POSGR ON (POSGR.GroupGUID = GR.GUID)
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


	-- *********************************************************************************************
	-- INSERT NEW MATERIAL INTO POSSDStationSyncModifiedData
	INSERT INTO POSSDStationSyncModifiedData000
		(GUID, StationGuid, DeviceID, RelatedToObject, ReleatedToObjectGuid, IsNewDataSync, CreatedOn, UpdatedOn, IsModifiedDataSync)
	SELECT 
	NEWID() AS GUID,
	GrTree.StationGUID,
	GrTree.DeviceID,
	'Mt000' AS RelatedToObject,
	N.GUID AS ReleatedToObjectGuid, 
	0 AS IsDataSync,
	@CreatedOn,
	@CreatedOn,
	@IsModifiedDataSync
	FROM @Groups AS  GrTree INNER JOIN inserted AS N ON (N.GroupGUID = GrTree.GUID)	
	WHERE N.Parent = 0x0
	GROUP BY StationGUID,GrTree.DeviceID, N.GUID;
END
#################################################################
CREATE TRIGGER trg_POSSDStationGroup000_InsertPOSSDSyncRelatedMat   ON  POSSDStationGroup000   AFTER INSERT 
AS 
BEGIN
	/*******************************************************************************************************
	Company : Syriansoft
	SP : trg_POSSDStationGroup000_InsertPOSSDSyncRelatedMat
	Purpose: insert new items that are related to the groups associated with POS for smart devices
	Create By: Hanadi Salka													Created On: 28 Aug 2019
	Updated On:																Updated By:
	Change Note:
	********************************************************************************************************/
	DECLARE @CreatedOn		DATETIME = SYSUTCDATETIME();
	DECLARE @IsModifiedDataSync		INT = -1;
	DECLARE @Groups TABLE (
						   StationGUID	UNIQUEIDENTIFIER,
						   DeviceID  NVARCHAR(250),
						   Guid   UNIQUEIDENTIFIER,  
						   Name		   NVARCHAR(300),						   
						   ParentGUID  UNIQUEIDENTIFIER, 						   
						   Level  INT)	;
	-- ******************************************************************************************************
	-- GET ALL GROUPS IN POSSTATION		
	WITH GroupTree (StationGUID, DeviceID, Guid,Name, ParentGUID,Level)
	AS
	(
	   SELECT POSGR.StationGUID, POSD.DeviceID, GR.Guid, GR.Name, GR.ParentGUID, 0 AS Tree 
	   FROM gr000 AS GR INNER JOIN inserted  AS POSGR ON (POSGR.GroupGUID = GR.GUID)	
	   INNER JOIN POSSDStationDevice000 AS POSD ON (POSGR.StationGUID = POSD.StationGUID)   
	   UNION ALL
	   SELECT GrTree.StationGUID, GrTree.DeviceID,GR.GUID, GR.Name, GR.ParentGUID , GrTree.Level + 1
	   FROM gr000 AS GR  JOIN GROUPTree AS GrTree ON (GR.ParentGUID = GrTree.Guid)
	)
	INSERT INTO @Groups(StationGUID, DeviceID, Guid, Name, ParentGUID, Level)
	SELECT 
		GR.StationGUID, GR.DeviceID, GR.Guid, GR.Name, GR.ParentGUID, GR.Level
	FROM GroupTree AS GR;
	
	WITH GroupCompundTree (StationGUID, DeviceID, Guid,Name, ParentGUID,Level)
	AS
	(
	   SELECT POSGR.StationGUID, POSD.DeviceID,GRD.Guid, GRD.Name, GRD.ParentGUID, 0 AS Tree 
	   FROM gr000 AS GR INNER JOIN inserted  AS POSGR ON (POSGR.GroupGUID = GR.GUID)
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
	
	-- *********************************************************************************************
	-- INSERT NEW GROUP INTO POSSDStationSyncModifiedData
	INSERT INTO POSSDStationSyncModifiedData000 
		(GUID, StationGuid, DeviceID, RelatedToObject, ReleatedToObjectGuid, IsNewDataSync, CreatedOn, UpdatedOn, IsModifiedDataSync)
	SELECT 
	NEWID() AS GUID,
	GrTree.StationGUID,
	GrTree.DeviceID,
	'GR000' AS RelatedToObject,
	GR.GUID AS ReleatedToObjectGuid, 
	0 AS IsDataSync,
	@CreatedOn,
	@CreatedOn,
	@IsModifiedDataSync
	FROM @Groups AS  GrTree INNER JOIN gr000 AS GR ON (GR.GUID = GrTree.Guid)
	LEFT JOIN POSSDStationSyncModifiedData000 AS SSD ON (SSD.StationGuid = GrTree.StationGUID AND SSD.DeviceID = GrTree.DeviceID AND SSD.RelatedToObject ='GR000' AND SSD.ReleatedToObjectGuid = GR.GUID)
	WHERE SSD.ReleatedToObjectGuid IS NULL
	GROUP BY GrTree.StationGUID, GrTree.DeviceID, GR.GUID;
	-- *********************************************************************************************
	-- INSERT NEW MATERIAL INTO POSSDStationSyncModifiedData
	INSERT INTO POSSDStationSyncModifiedData000 
		(GUID, StationGuid, DeviceID, RelatedToObject, ReleatedToObjectGuid, IsNewDataSync, CreatedOn, UpdatedOn, IsModifiedDataSync)
	SELECT 
	NEWID() AS GUID,
	GrTree.StationGUID,
	GrTree.DeviceID,
	'Mt000' AS RelatedToObject,
	MT.GUID AS ReleatedToObjectGuid, 
	0 AS IsDataSync,
	@CreatedOn,
	@CreatedOn,
	@IsModifiedDataSync
	FROM @Groups AS  GrTree INNER JOIN mt000 AS MT ON (MT.GroupGUID = GrTree.Guid)
	LEFT JOIN POSSDStationSyncModifiedData000 AS SSD ON (SSD.StationGuid = GrTree.StationGUID AND SSD.DeviceID = GrTree.DeviceID AND SSD.RelatedToObject ='Mt000' AND SSD.ReleatedToObjectGuid = MT.GUID)
	WHERE MT.Parent = 0x0 AND SSD.ReleatedToObjectGuid IS NULL
	GROUP BY GrTree.StationGUID, GrTree.DeviceID, MT.GUID;

	-- INSERT NEW MATERIAL INTO POSSDStationSyncModifiedData
	INSERT INTO POSSDStationSyncModifiedData000 
		(GUID, StationGuid, DeviceID, RelatedToObject, ReleatedToObjectGuid, IsNewDataSync, CreatedOn, UpdatedOn, IsModifiedDataSync)
	SELECT 
	NEWID() AS GUID,
	GrTree.StationGUID,
	GrTree.DeviceID,
	'Mt000' AS RelatedToObject,
	MT.GUID AS ReleatedToObjectGuid, 
	0 AS IsDataSync,
	@CreatedOn,
	@CreatedOn,
	@IsModifiedDataSync
	FROM @Groups AS  GrTree INNER JOIN gri000 AS GRI ON (GRI.GroupGuid = GrTree.Guid)
	INNER JOIN mt000 AS MT ON (MT.GUID = GRI.MatGuid AND GRI.ItemType = 1)
	LEFT JOIN POSSDStationSyncModifiedData000 AS SSD ON (SSD.StationGuid = GrTree.StationGUID AND SSD.DeviceID = GrTree.DeviceID AND SSD.RelatedToObject ='Mt000' AND SSD.ReleatedToObjectGuid = MT.GUID)
	WHERE MT.Parent = 0x0 AND SSD.ReleatedToObjectGuid IS NULL
	GROUP BY GrTree.StationGUID, GrTree.DeviceID, MT.GUID;
END
#################################################################
CREATE TRIGGER trg_POSSDStationGroup000_DeletePOSSDSyncRelatedMat   ON  POSSDStationGroup000
   FOR DELETE
AS 
BEGIN
	/*******************************************************************************************************
	Company : Syriansoft
	SP : trg_POSSDStationGroup000_InsertPOSSDSyncRelatedMat
	Purpose: insert new items that are related to the groups associated with POS for smart devices
	Create By: Hanadi Salka													Created On: 28 Aug 2019
	Updated On:																Updated By:
	Change Note:
	********************************************************************************************************/
	
	DECLARE @Groups TABLE (
						   StationGUID	UNIQUEIDENTIFIER,
						   DeviceID  NVARCHAR(250),
						   Guid   UNIQUEIDENTIFIER,  
						   Name		   NVARCHAR(300),						   
						   ParentGUID  UNIQUEIDENTIFIER, 						   
						   Level  INT)	;
	-- ******************************************************************************************************
	-- GET ALL GROUPS IN POSSTATION
	WITH GroupTree (StationGUID, DeviceID, Guid,Name, ParentGUID,Level)
	AS
	(
	   SELECT POSGR.StationGUID, POSD.DeviceID, GR.Guid, GR.Name, GR.ParentGUID, 0 AS Tree 
	   FROM gr000 AS GR INNER JOIN deleted  AS POSGR ON (POSGR.GroupGUID = GR.GUID)	
	   INNER JOIN POSSDStationDevice000 AS POSD ON (POSGR.StationGUID = POSD.StationGUID)   
	   UNION ALL
	   SELECT GrTree.StationGUID, GrTree.DeviceID,GR.GUID, GR.Name, GR.ParentGUID , GrTree.Level + 1
	   FROM gr000 AS GR  JOIN GROUPTree AS GrTree ON (GR.ParentGUID = GrTree.Guid)
	)
	INSERT INTO @Groups(StationGUID, DeviceID, Guid, Name, ParentGUID, Level)
	SELECT 
		GR.StationGUID, GR.DeviceID, GR.Guid, GR.Name, GR.ParentGUID, GR.Level
	FROM GroupTree AS GR;
	
	WITH GroupCompundTree (StationGUID, DeviceID, Guid,Name, ParentGUID,Level)
	AS
	(
	   SELECT POSGR.StationGUID, POSD.DeviceID,GRD.Guid, GRD.Name, GRD.ParentGUID, 0 AS Tree 
	   FROM gr000 AS GR INNER JOIN deleted  AS POSGR ON (POSGR.GroupGUID = GR.GUID)
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
	
	-- *********************************************************************************************
	-- DELETE GROUPS
	DELETE [POSSDStationSyncModifiedData000] FROM [POSSDStationSyncModifiedData000] AS [SSD] INNER JOIN gr000 AS GR ON (SSD.[RelatedToObject] = 'GR000' AND GR.GUID = SSD.ReleatedToObjectGuid)
	INNER JOIN @Groups AS  GrTree ON (GrTree.Guid = GR.GUID)
	WHERE SSD.StationGUID = GrTree.StationGUID;	
	
	-- DELETE ITEMS RELATED TO GROUP
	DELETE [POSSDStationSyncModifiedData000] FROM [POSSDStationSyncModifiedData000] AS [SSD] INNER JOIN mt000 AS MT ON (SSD.[RelatedToObject] = 'MT000' AND MT.GUID = SSD.ReleatedToObjectGuid)
	INNER JOIN @Groups AS  GrTree ON (GrTree.Guid = MT.GroupGUID)
	WHERE SSD.StationGUID = GrTree.StationGUID;	
	
	-- DELETE ITEMS RELATED TO COLLECTIVE  GROUP
	DELETE [POSSDStationSyncModifiedData000] FROM [POSSDStationSyncModifiedData000] AS [SSD] INNER JOIN mt000 AS MT ON (SSD.[RelatedToObject] = 'MT000' AND MT.GUID = SSD.ReleatedToObjectGuid)
	INNER JOIN gri000 AS GRI ON (MT.GUID = GRI.MatGuid AND GRI.ItemType = 1)
	INNER JOIN @Groups AS  GrTree ON (GrTree.Guid = GRI.GroupGUID)
	WHERE SSD.StationGUID = GrTree.StationGUID;			
END
#################################################################
CREATE TRIGGER trg_mt000_UpdatePOSSDSyncRelatedMat
   ON  MT000
   FOR UPDATE 
AS 
BEGIN
	/*******************************************************************************************************
	Company : Syriansoft
	SP : trg_mt000_UpdatePOSSDSyncRelatedMat
	Purpose: insert new items that are related to the groups associated with POS for smart devices if not exist or 
			update the modified flag of existing row
	Create By: Hanadi Salka													Created On: 28 Aug 2019
	Updated On:																Updated By:
	Change Note:
	********************************************************************************************************/
	DECLARE @CreatedOn				DATETIME = SYSUTCDATETIME();
	DECLARE @IsModifiedDataSync				INT = 0;
	DECLARE @IsModifiedDefaultDataSync		INT = -1;
	DECLARE @Groups TABLE (
						   StationGUID	UNIQUEIDENTIFIER,
						   DeviceID  NVARCHAR(250),
						   Guid   UNIQUEIDENTIFIER,  
						   Name		   NVARCHAR(300),						   
						   ParentGUID  UNIQUEIDENTIFIER, 						   
						   Level  INT)	;

	-- DO NOT INSERT ITEMS THAT HAS PARENT COMPOUND ITEM
	IF NOT EXISTS(SELECT * FROM [inserted] WHERE [Parent] = 0x0)
	RETURN;
	-- ******************************************************************************************************
	-- GET ALL GROUPS IN POSSTATION
	WITH GroupTree (StationGUID, DeviceID, Guid,Name, ParentGUID,Level)
	AS
	(
	   SELECT POSGR.StationGUID, POSD.DeviceID , GR.Guid, GR.Name, GR.ParentGUID, 0 AS Tree 
	   FROM gr000 AS GR INNER JOIN POSSDStationGroup000 AS POSGR ON (POSGR.GroupGUID = GR.GUID)	  
	   INNER JOIN POSSDStationDevice000 AS POSD ON (POSGR.StationGUID = POSD.StationGUID)   
	   UNION ALL
	   SELECT GrTree.StationGUID, GrTree.DeviceID, GR.GUID, GR.Name, GR.ParentGUID , GrTree.Level + 1
	   FROM gr000 AS GR  JOIN GROUPTree AS GrTree ON (GR.ParentGUID = GrTree.Guid)
	)
	INSERT INTO @Groups(StationGUID, DeviceID, Guid, Name, ParentGUID, Level)
	SELECT 
		GR.StationGUID, GR.DeviceID, GR.Guid, GR.Name, GR.ParentGUID, GR.Level
	FROM GroupTree AS GR;

	WITH GroupCompundTree (StationGUID, DeviceID, Guid,Name, ParentGUID,Level)
	AS
	(
	   SELECT POSGR.StationGUID, POSD.DeviceID,GRD.Guid, GRD.Name, GRD.ParentGUID, 0 AS Tree 
	   FROM gr000 AS GR INNER JOIN POSSDStationGroup000  AS POSGR ON (POSGR.GroupGUID = GR.GUID)
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

	-- *********************************************************************************************
	-- INSERT NEW MATERIAL INTO POSSDStationSyncModifiedData IF NOT EXISTS
	INSERT INTO POSSDStationSyncModifiedData000
		(GUID, StationGuid, DeviceID, RelatedToObject, ReleatedToObjectGuid, IsNewDataSync, CreatedOn, UpdatedOn, IsModifiedDataSync)
	SELECT 
	NEWID() AS GUID,
	GrTree.StationGUID,
	GrTree.DeviceID,
	'Mt000' AS RelatedToObject,
	N.GUID AS ReleatedToObjectGuid, 
	1 AS IsNewDataSync,
	@CreatedOn,
	@CreatedOn,
	@IsModifiedDefaultDataSync
	FROM @Groups AS  GrTree  INNER JOIN inserted AS N ON (N.GroupGUID = GrTree.GUID)
	LEFT JOIN 	POSSDStationSyncModifiedData000 AS SSD ON (SSD.StationGuid = GrTree.StationGUID AND SSD.DeviceID = GrTree.DeviceID AND SSD.RelatedToObject = 'Mt000' AND SSD.ReleatedToObjectGuid = N.GUID)	
	WHERE N.Parent = 0x0 AND SSD.ReleatedToObjectGuid IS NULL
	GROUP BY GrTree.StationGUID,GrTree.DeviceID, N.GUID;
	-- UPDATE THE MODIFIED FLAG OF EXISTING RECORD
	UPDATE POSSDStationSyncModifiedData000 
	SET 
		IsModifiedDataSync = 0,
		UpdatedOn = @CreatedOn
	FROM @Groups AS  GrTree  INNER JOIN inserted AS N ON (N.GroupGUID = GrTree.GUID)
	INNER JOIN POSSDStationSyncModifiedData000 AS SSD  ON (SSD.StationGuid = GrTree.StationGUID AND SSD.DeviceID = GrTree.DeviceID AND SSD.RelatedToObject = 'Mt000' AND N.GUID = SSD.ReleatedToObjectGuid );	
END
#################################################################
CREATE TRIGGER trg_gr000_UpdatePOSSDSyncRelatedMat  ON  gr000   FOR UPDATE 
AS 
BEGIN
	/*******************************************************************************************************
	Company : Syriansoft
	SP : trg_gr000_UpdatePOSSDSyncRelatedMat
	Purpose: insert new items and groups  that are related to the groups associated with POS for smart devices
	Create By: Hanadi Salka													Created On: 19 Nov 2019
	Updated On:																Updated By:
	Change Note:
	********************************************************************************************************/

	DECLARE @CreatedOn						DATETIME = SYSUTCDATETIME();
	DECLARE @IsDataSync						INT = 0;
	DECLARE @IsModifiedDefaultDataSync		INT = -1;
	DECLARE @Count							INT = 0;
	DECLARE @Groups							TABLE (StationGUID		UNIQUEIDENTIFIER,
													DeviceID		NVARCHAR(250),
													Guid			UNIQUEIDENTIFIER,  
													Name			NVARCHAR(300),						   
													ParentGUID		UNIQUEIDENTIFIER, 						   
													Level			INT);

	DECLARE @GrpWithDiffParent		TABLE ( Guid   UNIQUEIDENTIFIER, OldParentGuid UNIQUEIDENTIFIER, NewParentGuid UNIQUEIDENTIFIER);	
	DECLARE @GrpWithSameParent		TABLE ( Guid   UNIQUEIDENTIFIER);
	DECLARE @GuidList				VARCHAR(MAX);	

	-- *****************************************************************************
	-- get the group that has change in parent group
	INSERT INTO @GrpWithDiffParent(GUID, OldParentGuid, NewParentGuid)
	SELECT IGR.GUID, dgr.ParentGUID, IGR.ParentGUID
	FROM inserted AS IGR INNER JOIN deleted AS DGR ON (DGR.GUID = IGR.GUID)
	WHERE IGR.ParentGUID != DGR.ParentGUID;

	-- *****************************************************************************
	-- get the group that has no change in parent group
	INSERT INTO @GrpWithSameParent(GUID)
	SELECT IGR.GUID
	FROM inserted AS IGR INNER JOIN deleted AS DGR ON (DGR.GUID = IGR.GUID)
	WHERE IGR.ParentGUID = DGR.ParentGUID;
	-- *************************************************************************************
	-- Update the group info , if no change in the parent group
	SELECT @Count = COUNT(*) FROM @GrpWithSameParent;
	IF @Count > 0 
		BEGIN
			SELECT @GuidList = COALESCE(@GuidList + ',','') + CAST(Guid AS VARCHAR(40))
			FROM @GrpWithSameParent
			INSERT INTO @Groups(StationGUID,DeviceID,Guid,Name,ParentGUID)
			EXEC prcPOSSD_Station_GetRelatedChildGroup @GuidList;
			INSERT INTO @Groups(StationGUID,DeviceID,Guid,Name,ParentGUID)
			EXEC prcPOSSD_Station_GetRelatedParentGroup @GuidList;
			-- INSERT NEW GROUPS
			INSERT INTO POSSDStationSyncModifiedData000 
				(GUID, StationGuid, DeviceID, RelatedToObject, ReleatedToObjectGuid, IsNewDataSync, CreatedOn, UpdatedOn, IsModifiedDataSync)
			SELECT 
				NEWID() AS GUID,
				GrTree.StationGUID,
				GrTree.DeviceID,
				'GR000' AS RelatedToObject,
				GrTree.GUID AS ReleatedToObjectGuid, 
				@IsDataSync AS IsDataSync,
				@CreatedOn,
				@CreatedOn,
				@IsModifiedDefaultDataSync
			FROM @Groups AS  GrTree 
			LEFT JOIN POSSDStationSyncModifiedData000 AS SSD ON (SSD.StationGuid = GrTree.StationGUID AND SSD.DeviceID = GrTree.DeviceID AND SSD.RelatedToObject ='GR000' AND SSD.ReleatedToObjectGuid = GrTree.GUID)
			WHERE SSD.ReleatedToObjectGuid IS NULL
			GROUP BY GrTree.StationGUID, GrTree.DeviceID, GrTree.GUID;

			-- UPDATE THE MODIFIED FLAG OF EXISTING RECORD
			UPDATE POSSDStationSyncModifiedData000 
			SET 
				IsModifiedDataSync = @IsDataSync,
				UpdatedOn = @CreatedOn
			FROM @Groups AS  GrTree 
			INNER JOIN POSSDStationSyncModifiedData000 AS SSD  ON (SSD.StationGuid = GrTree.StationGUID AND SSD.DeviceID = GrTree.DeviceID AND SSD.RelatedToObject = 'GR000' AND GrTree.GUID = SSD.ReleatedToObjectGuid );	

		END;
	-- *************************************************************************************
	-- If there is change in the parent group, there will be change in hierarchial of the group  
	SELECT @Count = COUNT(*) FROM @GrpWithDiffParent;
	IF @Count > 0 
		BEGIN
			-- ****************************************************************
			-- Get old parent hierarchial and delete it
			SELECT @GuidList = COALESCE(@GuidList + ',','') + CAST(OldParentGuid AS VARCHAR(40))
			FROM @GrpWithDiffParent;
			-- Remove old data
			DELETE FROM @Groups;
			INSERT INTO @Groups(StationGUID,DeviceID,Guid,Name,ParentGUID)
			EXEC prcPOSSD_Station_GetRelatedParentGroup @GuidList;
			-- DELETE GROUPS
			DELETE SSD
			FROM POSSDStationSyncModifiedData000 SSD INNER JOIN @Groups AS  SGR ON (SSD.RelatedToObject ='GR000' AND SSD.ReleatedToObjectGuid = SGR.Guid)
			-- DELETE MATERIALS
			DELETE SSD
			FROM POSSDStationSyncModifiedData000 SSD INNER JOIN MT000 AS MT ON (SSD.RelatedToObject ='MT000'  AND MT.GUID = SSD.ReleatedToObjectGuid)
			INNER JOIN  @Groups AS  SGR ON (SGR.Guid = MT.GroupGUID);
			
			-- ****************************************************************************************
			-- get new parent hierarchial and insert it
			SELECT @GuidList = COALESCE(@GuidList + ',','') + CAST(NewParentGuid AS VARCHAR(40))
			FROM @GrpWithDiffParent;
			-- Remove old data
			DELETE FROM @Groups;
			INSERT INTO @Groups(StationGUID, DeviceID, Guid, Name, ParentGUID)
			EXEC prcPOSSD_Station_GetRelatedParentGroup @GuidList;
			-- INSERT NEW GROUPS AGAIN
			INSERT INTO POSSDStationSyncModifiedData000 
				(GUID, StationGuid, DeviceID, RelatedToObject, ReleatedToObjectGuid, IsNewDataSync, CreatedOn, UpdatedOn, IsModifiedDataSync)
			SELECT 
				NEWID() AS GUID,
				GrTree.StationGUID,
				GrTree.DeviceID,
				'GR000' AS RelatedToObject,
				GrTree.GUID AS ReleatedToObjectGuid, 
				@IsDataSync AS IsDataSync,
				@CreatedOn,
				@CreatedOn,
				@IsModifiedDefaultDataSync
			FROM @Groups AS  GrTree 
			LEFT JOIN POSSDStationSyncModifiedData000 AS SSD ON (SSD.StationGuid = GrTree.StationGUID AND SSD.DeviceID = GrTree.DeviceID AND SSD.RelatedToObject ='GR000' AND SSD.ReleatedToObjectGuid = GrTree.GUID)
			WHERE SSD.ReleatedToObjectGuid IS NULL
			GROUP BY GrTree.StationGUID, GrTree.DeviceID, GrTree.GUID;

			-- ****************************************************************************************
			-- INSERT NEW MATERIALS
			INSERT INTO POSSDStationSyncModifiedData000 
				(GUID, StationGuid, DeviceID, RelatedToObject, ReleatedToObjectGuid, IsNewDataSync, CreatedOn, UpdatedOn, IsModifiedDataSync)
			SELECT 
			NEWID() AS GUID,
			GrTree.StationGUID,
			GrTree.DeviceID,
			'Mt000' AS RelatedToObject,
			MT.GUID AS ReleatedToObjectGuid, 
			@IsDataSync	 AS IsDataSync,
			@CreatedOn,
			@CreatedOn,
			@IsModifiedDefaultDataSync
			FROM @Groups AS  GrTree INNER JOIN mt000 AS MT ON (MT.GroupGUID = GrTree.Guid)
			LEFT JOIN POSSDStationSyncModifiedData000 AS SSD ON (SSD.StationGuid = GrTree.StationGUID AND SSD.DeviceID = GrTree.DeviceID AND SSD.RelatedToObject ='Mt000' AND SSD.ReleatedToObjectGuid = MT.GUID)
			WHERE MT.Parent = 0x0 AND SSD.ReleatedToObjectGuid IS NULL
			GROUP BY GrTree.StationGUID, GrTree.DeviceID, MT.GUID;

			-- ***********************************************************************************************************
			-- get child hierarchial of currrent group
			SELECT @GuidList = COALESCE(@GuidList + ',','') + CAST(Guid AS VARCHAR(40))
			FROM @GrpWithDiffParent;
			-- Remove old data
			DELETE FROM @Groups;
			INSERT INTO @Groups(StationGUID, DeviceID, Guid, Name, ParentGUID)
			EXEC prcPOSSD_Station_GetRelatedChildGroup @GuidList;
			-- DELETE GROUPS
			DELETE SSD
			FROM POSSDStationSyncModifiedData000 SSD INNER JOIN @Groups AS  SGR ON (SSD.RelatedToObject ='GR000' AND SSD.ReleatedToObjectGuid = SGR.Guid)
			INNER JOIN @GrpWithDiffParent AS GDP ON (GDP.Guid = SGR.Guid)
			WHERE GDP.Guid != SGR.Guid;
			-- DELETE MATERIALS
			DELETE SSD
			FROM POSSDStationSyncModifiedData000 SSD INNER JOIN MT000 AS MT ON (SSD.RelatedToObject ='MT000'  AND MT.GUID = SSD.ReleatedToObjectGuid)
			INNER JOIN  @Groups AS  SGR ON (SGR.Guid = MT.GroupGUID)
			INNER JOIN @GrpWithDiffParent AS GDP ON (GDP.Guid = SGR.Guid)
			WHERE GDP.Guid != SGR.Guid;
			
			-- ****************************************************************************************
			SELECT @GuidList = COALESCE(@GuidList + ',','') + CAST(NewParentGuid AS VARCHAR(40))
			FROM @GrpWithDiffParent;
			-- Remove old data
			DELETE FROM @Groups;
			INSERT INTO @Groups(StationGUID, DeviceID, Guid, Name, ParentGUID)
			EXEC prcPOSSD_Station_GetRelatedChildGroup @GuidList;
			-- INSERT NEW GROUPS AGAIN
			INSERT INTO POSSDStationSyncModifiedData000 
				(GUID, StationGuid, DeviceID, RelatedToObject, ReleatedToObjectGuid, IsNewDataSync, CreatedOn, UpdatedOn, IsModifiedDataSync)
			SELECT 
				NEWID() AS GUID,
				GrTree.StationGUID,
				GrTree.DeviceID,
				'GR000' AS RelatedToObject,
				GrTree.GUID AS ReleatedToObjectGuid, 
				@IsDataSync AS IsDataSync,
				@CreatedOn,
				@CreatedOn,
				@IsModifiedDefaultDataSync
			FROM @Groups AS  GrTree 
			LEFT JOIN POSSDStationSyncModifiedData000 AS SSD ON (SSD.StationGuid = GrTree.StationGUID AND SSD.DeviceID = GrTree.DeviceID AND SSD.RelatedToObject ='GR000' AND SSD.ReleatedToObjectGuid = GrTree.GUID)
			WHERE SSD.ReleatedToObjectGuid IS NULL
			GROUP BY GrTree.StationGUID, GrTree.DeviceID, GrTree.GUID;

			-- ****************************************************************************************
			-- INSERT NEW MATERIALS
			INSERT INTO POSSDStationSyncModifiedData000 
				(GUID, StationGuid, DeviceID, RelatedToObject, ReleatedToObjectGuid, IsNewDataSync, CreatedOn, UpdatedOn, IsModifiedDataSync)
			SELECT 
			NEWID() AS GUID,
			GrTree.StationGUID,
			GrTree.DeviceID,
			'Mt000' AS RelatedToObject,
			MT.GUID AS ReleatedToObjectGuid, 
			@IsDataSync	 AS IsDataSync,
			@CreatedOn,
			@CreatedOn,
			@IsModifiedDefaultDataSync
			FROM @Groups AS  GrTree INNER JOIN mt000 AS MT ON (MT.GroupGUID = GrTree.Guid)
			LEFT JOIN POSSDStationSyncModifiedData000 AS SSD ON (SSD.StationGuid = GrTree.StationGUID AND SSD.DeviceID = GrTree.DeviceID AND SSD.RelatedToObject ='Mt000' AND SSD.ReleatedToObjectGuid = MT.GUID)
			WHERE MT.Parent = 0x0 AND SSD.ReleatedToObjectGuid IS NULL
			GROUP BY GrTree.StationGUID, GrTree.DeviceID, MT.GUID;
		END;
	-- ******************************************************************************************************
END;
#################################################################
CREATE TRIGGER trg_gri000_InsertPOSSDSyncRelatedMat  ON  GRI000   AFTER INSERT 
AS 
BEGIN
	/*******************************************************************************************************
	Company : Syriansoft
	SP : trg_gri000_InsertPOSSDSyncRelatedMat
	Purpose: insert new items that are related to the groups associated with POS for smart devices
	Create By: Hanadi Salka													Created On: 05 DEC 2019
	Updated On:																Updated By:
	Change Note:
	********************************************************************************************************/
	DECLARE @CreatedOn						DATETIME = SYSUTCDATETIME();
	DECLARE @IsModifiedDataSync				INT = -1;
	DECLARE @GuidList						VARCHAR(MAX);	
	DECLARE @Groups							TABLE (StationGUID		UNIQUEIDENTIFIER,
													DeviceID		NVARCHAR(250),
													Guid			UNIQUEIDENTIFIER,  
													Name			NVARCHAR(300),						   
													ParentGUID		UNIQUEIDENTIFIER);  
	DECLARE @Count							INT = 0;
	-- ******************************************************************************************************
	-- GET ALL GROUPS IN POSSTATION		
	SELECT @GuidList = COALESCE(@GuidList + ',','') + CAST(IGRI.GroupGuid AS VARCHAR(40))	
	FROM inserted AS IGRI;

	SELECT @GuidList = COALESCE(@GuidList + ',','') + CAST(IGRI.MatGuid AS VARCHAR(40))	
	FROM inserted AS IGRI
	WHERE IGRI.ItemType = 0;

	INSERT INTO @Groups(StationGUID,DeviceID,Guid,Name,ParentGUID)
			EXEC prcPOSSD_Station_GetRelatedChildGroup @GuidList;

	SELECT 
		@Count = COUNT(*)
	FROM @Groups;

	IF	@Count > 0 
		BEGIN
			-- *********************************************************************************************			
			-- INSERT NEW MATERIAL INTO POSSDStationSyncModifiedData
			INSERT INTO POSSDStationSyncModifiedData000 
				(GUID, StationGuid, DeviceID, RelatedToObject, ReleatedToObjectGuid, IsNewDataSync, CreatedOn, UpdatedOn, IsModifiedDataSync)
			SELECT 
			NEWID() AS GUID,
			GrTree.StationGUID,
			GrTree.DeviceID,
			'Mt000' AS RelatedToObject,
			MT.GUID AS ReleatedToObjectGuid, 
			0 AS IsDataSync,
			@CreatedOn,
			@CreatedOn,
			@IsModifiedDataSync
			FROM @Groups AS  GrTree INNER JOIN mt000 AS MT ON (MT.GroupGUID = GrTree.Guid)
			LEFT JOIN POSSDStationSyncModifiedData000 AS SSD ON (SSD.StationGuid = GrTree.StationGUID AND SSD.DeviceID = GrTree.DeviceID AND SSD.RelatedToObject ='Mt000' AND SSD.ReleatedToObjectGuid = MT.GUID)
			WHERE MT.Parent = 0x0 AND SSD.ReleatedToObjectGuid IS NULL
			GROUP BY GrTree.StationGUID, GrTree.DeviceID, MT.GUID;
			-- *********************************************************************************************
			-- INSERT NEW MATERIAL INTO POSSDStationSyncModifiedData
			INSERT INTO POSSDStationSyncModifiedData000 
				(GUID, StationGuid, DeviceID, RelatedToObject, ReleatedToObjectGuid, IsNewDataSync, CreatedOn, UpdatedOn, IsModifiedDataSync)
			SELECT 
			NEWID() AS GUID,
			GrTree.StationGUID,
			GrTree.DeviceID,
			'Mt000' AS RelatedToObject,
			MT.GUID AS ReleatedToObjectGuid, 
			0 AS IsDataSync,
			@CreatedOn,
			@CreatedOn,
			@IsModifiedDataSync
			FROM @Groups AS  GrTree INNER JOIN gri000 AS GRI ON (GRI.GroupGuid = GrTree.Guid)
			INNER JOIN mt000 AS MT ON (MT.GUID = GRI.MatGuid AND GRI.ItemType = 1)
			LEFT JOIN POSSDStationSyncModifiedData000 AS SSD ON (SSD.StationGuid = GrTree.StationGUID AND SSD.DeviceID = GrTree.DeviceID AND SSD.RelatedToObject ='Mt000' AND SSD.ReleatedToObjectGuid = MT.GUID)
			WHERE MT.Parent = 0x0 AND SSD.ReleatedToObjectGuid IS NULL
			GROUP BY GrTree.StationGUID, GrTree.DeviceID, MT.GUID;
		END;
END;
#################################################################
CREATE TRIGGER trg_gri000_DeletePOSSDSyncRelatedMat  ON  GRI000   FOR DELETE
AS 
BEGIN
	/*******************************************************************************************************
	Company : Syriansoft
	SP : trg_gri000_InsertPOSSDSyncRelatedMat
	Purpose: Delete the deleted item from POSSDStationSyncModifiedData000 also
	Create By: Hanadi Salka													Created On: 05 DEC 2019
	Updated On:																Updated By:
	Change Note:
	********************************************************************************************************/
	DECLARE @CreatedOn						DATETIME = SYSUTCDATETIME();
	DECLARE @IsModifiedDataSync				INT = -1;
	DECLARE @GuidList						VARCHAR(MAX);	
	DECLARE @Groups							TABLE (StationGUID		UNIQUEIDENTIFIER,
													DeviceID		NVARCHAR(250),
													Guid			UNIQUEIDENTIFIER,  
													Name			NVARCHAR(300),						   
													ParentGUID		UNIQUEIDENTIFIER);  
	DECLARE @Count							INT = 0;
	-- ******************************************************************************************************
	-- GET ALL GROUPS IN POSSTATION		
	SELECT @GuidList = COALESCE(@GuidList + ',','') + CAST(DGRI.GroupGuid AS VARCHAR(40))	
	FROM deleted AS DGRI;

	SELECT @GuidList = COALESCE(@GuidList + ',','') + CAST(DGRI.MatGuid AS VARCHAR(40))	
	FROM deleted AS DGRI
	WHERE DGRI.ItemType = 0;

	INSERT INTO @Groups(StationGUID,DeviceID,Guid,Name,ParentGUID)
			EXEC prcPOSSD_Station_GetRelatedChildGroup @GuidList;
	SELECT 
		@Count = COUNT(*)
	FROM @Groups;
	IF	@Count > 0 
		BEGIN	
			-- DELETE GROUP
			DELETE [POSSDStationSyncModifiedData000] FROM [POSSDStationSyncModifiedData000] AS [SSD] INNER JOIN gr000 AS GR ON (SSD.[RelatedToObject] = 'GR000' AND GR.GUID = SSD.ReleatedToObjectGuid)
			INNER JOIN @Groups AS  GrTree ON (GrTree.Guid = GR.GUID)
			WHERE SSD.StationGUID = GrTree.StationGUID;	

			

			-- DELETE ITEMS RELATED TO GROUP
			DELETE [POSSDStationSyncModifiedData000] FROM [POSSDStationSyncModifiedData000] AS [SSD] INNER JOIN mt000 AS MT ON (SSD.[RelatedToObject] = 'MT000' AND MT.GUID = SSD.ReleatedToObjectGuid)
			INNER JOIN @Groups AS  GrTree ON (GrTree.Guid = MT.GroupGUID)
			WHERE SSD.StationGUID = GrTree.StationGUID;	

			-- DELETE ITEMS RELATED TO COLLECTIVE  GROUP
			DELETE [POSSDStationSyncModifiedData000] FROM [POSSDStationSyncModifiedData000] AS [SSD] INNER JOIN mt000 AS MT ON (SSD.[RelatedToObject] = 'MT000' AND MT.GUID = SSD.ReleatedToObjectGuid)
			INNER JOIN gri000 AS GRI ON (MT.GUID = GRI.MatGuid AND GRI.ItemType = 1)
			INNER JOIN @Groups AS  GrTree ON (GrTree.Guid = GRI.GroupGUID)

			-- DELETE ITEMS RELATED TO COLLECTIVE  GROUP
			DELETE [POSSDStationSyncModifiedData000] FROM [POSSDStationSyncModifiedData000] AS [SSD] INNER JOIN mt000 AS MT ON (SSD.[RelatedToObject] = 'MT000' AND MT.GUID = SSD.ReleatedToObjectGuid)
			INNER JOIN deleted AS GRI ON (MT.GUID = GRI.MatGuid AND GRI.ItemType = 1);			
					
		END;	
END
#################################################################
#END
