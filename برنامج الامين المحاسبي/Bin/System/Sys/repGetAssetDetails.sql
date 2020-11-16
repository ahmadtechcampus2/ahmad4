################################################################
CREATE PROC repGetAssetDetails @AssGUID UNIQUEIDENTIFIER
AS 
	SELECT 
		* 
	FROM 
		vwAD
	WHERE 
		adAssGuid = @AssGUID
	ORDER BY
		Len(adSn),
		adSn
################################################################
#END
