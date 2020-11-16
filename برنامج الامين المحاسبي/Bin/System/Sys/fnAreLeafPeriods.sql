###########################################################
CREATE FUNCTION fnAreLeafPeriods (@HandleGuid UNIQUEIDENTIFIER)
RETURNS INT
AS
BEGIN
RETURN (
	SELECT DISTINCT 
		(CASE WHEN COUNT([bdp].[ParentGuid]) > 0 THEN 0 ELSE 1 END) AS 'AreLeafPeriods'
	FROM
		bdp000 bdp INNER JOIN RepSrcs rs ON [rs].[IdType] = [bdp].[ParentGuid]
	WHERE
		[rs].[IdTbl] = @HandleGuid
	)
END
############################################################
#END