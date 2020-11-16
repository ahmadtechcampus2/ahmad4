#################################################################
CREATE FUNCTION fnPOSSD_StationOfflineMixModeHasOpenShift() 
RETURNS INT 
AS 
BEGIN 

DECLARE @rowsCount INT;
  -- Remove mix mode data transfer mode
  SET @rowsCount = (SELECT COUNT(*)
			   FROM [POSSDStation000] AS [Station] INNER JOIN [POSSDShift000] AS [Shift] ON ([Shift].StationGUID = [Station].GUID)
			   WHERE [Station].DataTransferMode = 1 
					 AND [Shift].CloseDate IS NULL
	           )

  RETURN  @rowsCount
END
#################################################################
#END 