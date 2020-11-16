################################################################################
CREATE PROCEDURE prcPOSSD_RelatedSale_GetAllRelatedSaleMaterialsInPOS
-- Param -------------------------------   
	   @POSSDGuid UNIQUEIDENTIFIER,
	   @SaleType  INT
-----------------------------------------   
AS
BEGIN
	/*******************************************************************************************************
	Company : Syriansoft
	SP : prcPOSSD_RelatedSale_GetAllRelatedSaleMaterialsInPOS
	Purpose: get upsale products related to a spicific pos station
	How to Call:	EXEC prcPOSSD_RelatedSale_GetAllRelatedSaleMaterialsInPOS '3C2561FE-406C-446D-AFE3-6212319487F8',2 -- upsale
					EXEC prcPOSSD_RelatedSale_GetAllRelatedSaleMaterialsInPOS '3C2561FE-406C-446D-AFE3-6212319487F8',0 -- cross sale
	Create By: 											Created On: 
	Updated On:	Hanadi Salka							Updated By: 13-Nov-2019
	Change Note:
	********************************************************************************************************/

    SET NOCOUNT ON
	------------- RESULT -------------
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
	EXEC prcPOSSD_Station_GetGroups @POSSDGuid;	
	
	SELECT 
		RSM.[GUID]       AS [Guid],
  		RSM.Number       AS Number,
  		ME.MaterialGUID  AS ParentGuid,
  		RSM.MaterialGUID AS MaterialGuid
	FROM
		POSSDRelatedSaleMaterial000 RSM
		INNER JOIN POSSDMaterialExtended000 ME	ON RSM.ParentGUID		= ME.[GUID]
		INNER JOIN mt000 MT						ON RSM.MaterialGUID		= MT.[GUID]
		INNER JOIN @Groups POSGroup				ON POSGroup.GroupGuid	= MT.GroupGUID
	WHERE
		ME.[Type] = @SaleType
END
#################################################################
#END
