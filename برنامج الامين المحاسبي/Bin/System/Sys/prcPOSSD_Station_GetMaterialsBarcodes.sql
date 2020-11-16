#################################################################
CREATE PROCEDURE prcPOSSD_Station_GetMaterialsBarcodes
 @POSCardGuid UNIQUEIDENTIFIER

AS
BEGIN
	/*******************************************************************************************************
	Company : Syriansoft
	SP : prcPOSSD_Station_GetMaterialsBarcodes
	Purpose: get products barcode for a specific pos station 
	How to Call: EXEC prcPOSSD_Station_GetMaterialsBarcodes '3C2561FE-406C-446D-AFE3-6212319487F8'
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
		Groupkind   TINYINT
	) 
	INSERT INTO @Groups (Number,GroupGUID, Name,Code, ParentGUID, LatinName, PictureGUID, GroupIndex, Groupkind)
	EXEC prcPOSSD_Station_GetGroups @POSCardGuid;

	DECLARE @Materials TABLE (MatGuid	UNIQUEIDENTIFIER);
   --Fetch materials related to POS   
	INSERT INTO @Materials(MatGuid)
		SELECT MT.[GUID]
		FROM @Groups AS GR  
		INNER JOIN mt000 AS MT ON mt.GroupGUID = GR.GroupGUID
		WHERE MT.HasSegments = 1 OR MT.Parent = 0x0 
		GROUP BY MT.GUID
			
	INSERT INTO @Materials(MatGuid)
		SELECT [mt].[GUID]
		FROM @Groups AS gr
		INNER JOIN [gri000] AS [gri] ON ([gri].[GroupGuid] = [gr].[GroupGUID] AND [gri].[ItemType] = 1)
		INNER JOIN [mt000] AS [mt] ON [mt].[GUID] = [gri].[MatGuid]
		LEFT JOIN @Materials AS TMPMT ON (TMPMT.MatGuid = MT.GUID)		
		WHERE  TMPMT.MatGuid IS NULL AND mt.HasSegments = 1 OR mt.Parent = 0x0 
		GROUP BY MT.GUID

	--Get barcodes related to materials
	SELECT MB.Guid, MB.MatGuid, MB.MatUnit - 1 AS MatUnit, MB.Barcode, MB.IsDefault 
	FROM MatExBarcode000 MB INNER JOIN  @Materials MT   ON (MB.MatGuid = MT.MatGuid)
	--************************************************************************************************
	-- Insert sub items of compound item ( material  segmentation)	
	UNION
	SELECT newid() AS [Guid], me.MaterialId AS MatGuid, 0 AS MatUnit, mt.BarCode, 1
		FROM MaterialElements000 AS me INNER JOIN mt000 AS mt ON (mt.[GUID] = me.[MaterialId])
		INNER JOIN mt000 AS pmt ON (pmt.[GUID] = mt.[Parent])
		INNER JOIN @Groups AS grp ON (grp.[GroupGUID] = pmt.GroupGUID)
		GROUP BY me.MaterialId, mt.BarCode  
END
#################################################################
#END 