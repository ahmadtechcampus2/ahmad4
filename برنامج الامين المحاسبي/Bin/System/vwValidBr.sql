###############################################################################
CREATE View vwValidBr
AS
	SELECT *
	FROM br000 AS br INNER JOIN vwUIX_OfCurrentUser AS ui	ON br.GUID = ui.uiSubId
	WHERE CAST( ui.uiReportId AS BIGINT) = 0x1001F000
	
################################################################################
#END