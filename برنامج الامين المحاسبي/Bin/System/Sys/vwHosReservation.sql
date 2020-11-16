####################################
CREATE VIEW vwHosReservation
AS 
SELECT   
    r.[Number], 
    r.[GUID], 
    r.[Code], 
    r.[AccGuid], 
    r.[Date], 
    r.[Notes], 
    r.[Status], 
    CASE [dbo].[fnConnections_GetLanguage]() WHEN 1 THEN a.[acLatinName] ELSE a.[acName]  END AS AcName 
FROM [HosReservation000] r INNER JOIN [vwAc] AS a ON r.[AccGuid] = a.[acGuid]
#####################################
CREATE VIEW vwHosReservationDetails
AS 
SELECT 
    RD.[Guid], 
    RD.[SiteGuid], 
    RD.[ParentGuid] ReservationGuid, 
    RD.[ParentGuid] ParentGuid, 
    S.[Code]  SiteCode, 
    CASE [dbo].[fnConnections_GetLanguage]() WHEN 1 THEN S.[LatinName] ELSE S.[Name] END AS [SiteName], 
    S.[LatinName] SiteLatinName, 
    S.[TypeGuid] AS SiteTypeGuid, 
    RD.[PatientGuid], 
    S.[Code] PatientCode, 
    CASE [dbo].[fnConnections_GetLanguage]() WHEN 1 THEN P.[LatinName] ELSE P.[Name] END AS [PatientName], 
    S.[LatinName] PatientLatinName, 
    RD.[FromDate], 
    RD.[ToDate], 
    RD.[Pay], 
    RD.[Discount], 
    RD.[Notes], 
    R.State
FROM 
    [HosReservationDetails000]  RD INNER JOIN [HosReservation000] R ON RD.ParentGuid = R.GUID
	  			LEFT JOIN [hosSITE000] S ON RD.[SiteGUID]  = S.[GUID] 
				INNER JOIN [vwHosPatient] P ON P.[GUID]     = RD.[PatientGUID] 
#####################################
#END