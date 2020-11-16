###############################################################################
CREATE FUNCTION fnGetIsUserPermittedOnStores (@HandleGuid UNIQUEIDENTIFIER)
RETURNS INT
AS
BEGIN
	RETURN
	(
		SELECT (CASE WHEN MAX(StoreIsParent) = 1 THEN -3 
				ELSE (	CASE WHEN MIN(BranchStoreSecurity) = 0 THEN -2 
						ELSE (	CASE WHEN MIN(BrowseSecurity) = 0 THEN -1
								ELSE 1 
								END) 
						END) 
				END) AS StoresListPermission 
		FROM (
			SELECT 
				rs.IdType,
				(CASE WHEN st.[Security] <= (CASE WHEN (dbo.fnIsAdmin(dbo.fnGetCurrentUserGUID()) = 1) THEN 3 ELSE dbo.fnGetUserStoreSec_Browse(dbo.fnGetCurrentUserGUID()) END) THEN 1 ELSE 0 END) AS BrowseSecurity,
				(CASE WHEN ([dbo].[fnOption_get]('EnableBranches', '0') = 0 OR st.[branchMask] & dbo.fnGetUserBranchMask() <> 0 ) THEN 1 ELSE 0 END) AS BranchStoreSecurity,
				(CASE WHEN (SELECT TOP 1 COUNT(ParentGUID) FROM st000 WHERE ParentGUID = rs.IdType) > 0 THEN 1 ELSE 0 END) AS StoreIsParent --at least has one child
			FROM
				RepSrcs rs
				INNER JOIN st000 st ON st.[GUID] = rs.IdType
			WHERE
				rs.IdTbl = @HandleGuid
		) ABC
	)
END
###############################################################################
#END
