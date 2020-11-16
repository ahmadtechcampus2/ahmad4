#########################################################
CREATE VIEW vwUi
AS    
	SELECT	
		[GUID] AS [uiGUID],
		[UserGUID] AS [uiUserGUID],
		[SubId] AS [uiSubId],
		[ReportId] AS [uiReportId],
		[Permission] AS  [uiPermission],
		[PermType] AS [uiPermType],
		[System] AS [uiSystem]
	FROM
		[ui000]

#########################################################
#END