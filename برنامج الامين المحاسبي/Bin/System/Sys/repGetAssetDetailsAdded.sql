######################################################################3
CREATE PROC repGetAssetDetailsAdded @AssDetailGuid UNIQUEIDENTIFIER
AS
	SELECT * 
	FROM 
		vwAssAdded
	WHERE 
		axAssDetailGUID = @AssDetailGuid



######################################################################3
#END