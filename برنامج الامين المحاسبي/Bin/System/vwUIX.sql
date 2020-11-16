#########################################################
CREATE VIEW vwUIX
AS    
	SELECT	
		[GUID] AS [uiGUID],
		[UserGUID] AS [uiUserGUID],
		[SubID] AS [uiSubID],
		[ReportID] AS [uiReportID],
		[Permission] AS [uiPermission],
		[PermType] AS [uiPermType],
		[System] AS [uiSystem]
	FROM
		[uix]

#########################################################
#END