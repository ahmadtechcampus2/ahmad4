################################################################
CREATE PROCEDURE prcGetBonusPostedQty (@biGuid UNIQUEIDENTIFIER)
AS 
	SET NOCOUNT ON

	SELECT 
		ORI.POIGuid         AS biGuid, 
		SUM(BonusPostedQty) AS BonusPosted 
	FROM 
		ori000 AS ORI
	WHERE
		 ORI.POIGuid = @biGuid
	GROUP BY 
		ORI.POIGuid
################################################################
#END	