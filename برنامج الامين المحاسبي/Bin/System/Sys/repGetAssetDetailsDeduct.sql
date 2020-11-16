##########################################################################
CREATE PROC repGetAssetDetailsDeduct @AssDetailGuid UNIQUEIDENTIFIER
AS
	SELECT * 
	FROM 
		vwAssDeduct
	WHERE 
		axAssDetailGUID = @AssDetailGuid


##########################################################################
#END