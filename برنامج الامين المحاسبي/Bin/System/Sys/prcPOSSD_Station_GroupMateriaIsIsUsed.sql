################################################################################
CREATE PROCEDURE prcPOSSD_Station_GroupMateriaIsIsUsed
-- Param -------------------------------   
	@GroupToBeVerified				UNIQUEIDENTIFIER
-----------------------------------------   
AS
    SET NOCOUNT ON
------------------------------------------------------------------------
	DECLARE @GroupTemp TABLE (GroupGuid UNIQUEIDENTIFIER)


	INSERT INTO @GroupTemp SELECT @GroupToBeVerified;
	INSERT INTO @GroupTemp SELECT [GUID] FROM [dbo].[fnGetGroupParents](@GroupToBeVerified) WHERE [GUID] <> 0x0;
	INSERT INTO @GroupTemp SELECT GroupGuid FROM gri000 WHERE MatGuid = @GroupToBeVerified;

	IF((SELECT COUNT(GT.GroupGuid) FROM @GroupTemp GT INNER JOIN POSSDStationGroup000 RP ON GT.GroupGuid = RP.GroupGUID) > 0)
		SELECT 1 AS IsUsed;
	ELSE 
		SELECT 0 AS IsUsed;
#################################################################
#END
