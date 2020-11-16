################################################################################
CREATE PROCEDURE prcPOSSD_Station_GetStores
-- Params -------------------------------   
	@StationGuid		UNIQUEIDENTIFIER
-----------------------------------------   
AS
    SET NOCOUNT ON
------------------------------------------------------------------------
	DECLARE @language INT = [dbo].[fnConnections_getLanguage]()

	DECLARE @NULLABLEGUID UNIQUEIDENTIFIER
	SET @NULLABLEGUID = 0x0

	SELECT
		SS.Number					AS Number,
		SS.StoreGUID				AS StoreGUID,
		ST.Code						AS Code,
		CASE @language WHEN 0 THEN ST.Name
				   ELSE CASE ST.LatinName WHEN '' THEN ST.Name 
										  ELSE ST.LatinName END END AS Name,
		@NULLABLEGUID			    AS MainStoreGUID

	FROM 
		POSSDStationStores000 SS
		INNER JOIN st000 ST ON ST.GUID = SS.StoreGUID
	WHERE
		SS.StationGUID = @StationGuid
	
	ORDER BY 
		SS.Number
#################################################################
#END
