#########################################################
CREATE View vwRT
AS
	SELECT
		[GUID] AS [rtGUID],
		[ChildGUID] AS [rtChildGUID],
		[ParentGUID] AS [rtParentGUID]
	FROM
		[rt000]

#########################################################
#END