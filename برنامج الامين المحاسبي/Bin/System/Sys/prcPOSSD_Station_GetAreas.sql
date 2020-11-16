################################################################################
CREATE PROCEDURE prcPOSSD_Station_GetAreas
-- Params -------------------------------   
	@StationGuid		UNIQUEIDENTIFIER
-----------------------------------------   
AS
    SET NOCOUNT ON
------------------------------------------------------------------------

	SELECT
		A.Number,					
		A.GUID as Guid,	
		A.Code,
		A.Name,
		A.LatinName,
		A.ParentGUID
	FROM 
		POSSDStationAddressArea000 POS
		INNER JOIN AddressArea000 A ON A.GUID = POS.AreaGUID
	WHERE 
		POS.StationGUID = @StationGuid

#################################################################
#END
