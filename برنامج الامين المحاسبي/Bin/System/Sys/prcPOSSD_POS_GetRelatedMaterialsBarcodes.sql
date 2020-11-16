#################################################################
CREATE PROCEDURE prcPOSGetRelatedMaterialsBarcodes
 @POSCardGuid UNIQUEIDENTIFIER

AS
BEGIN

 DECLARE @Groups TABLE
	(
		Number int ,
		GroupGUID UNIQUEIDENTIFIER,  
		Name NVARCHAR(MAX),
		Code NVARCHAR(MAX),
		ParentGUID UNIQUEIDENTIFIER,  
		LatinName  NVARCHAR(MAX),
		PictureGUID UNIQUEIDENTIFIER,
		GroupIndex	INT 
	) 
	INSERT INTO @Groups (Number,GroupGUID, Name,Code, ParentGUID, LatinName, PictureGUID, GroupIndex)
	  EXEC prcPOSGetRelatedGroups @POSCardGuid

	DECLARE @Materials TABLE (MatGuid	UNIQUEIDENTIFIER)

   --Fetch materials related to POS   
	INSERT INTO @Materials(MatGuid)
		SELECT DISTINCT [GUID] 
		FROM @Groups groups  
		INNER JOIN mt000 mt ON mt.GroupGUID = groups.GroupGUID

	INSERT INTO @Materials(MatGuid)
		SELECT [mt].[GUID]
		FROM @Groups AS [grp]
		INNER JOIN [gri000] AS [gri] ON [gri].[GroupGuid] = [grp].[GroupGUID] AND [gri].[ItemType] = 1
		INNER JOIN [mt000] AS [mt] ON [mt].[GUID] = [gri].[MatGuid]
		
 --Get barcodes related to materials
  SELECT MB.Guid, MB.MatGuid, MB.MatUnit - 1 AS MatUnit, MB.Barcode, MB.IsDefault 
   FROM MatExBarcode000 MB 
   INNER JOIN  @Materials MT 
   ON MB.MatGuid = MT.MatGuid
   ORDER BY MB.MatGuid

END
#################################################################
#END 