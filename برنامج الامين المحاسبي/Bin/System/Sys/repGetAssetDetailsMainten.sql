###########################################################################
CREATE PROC repGetAssetDetailsMainten @AssDetailGuid UNIQUEIDENTIFIER
AS
	SELECT * 
	FROM 
		vwAssMainten
	WHERE 
		axAssDetailGUID = @AssDetailGuid

###########################################################################
#END