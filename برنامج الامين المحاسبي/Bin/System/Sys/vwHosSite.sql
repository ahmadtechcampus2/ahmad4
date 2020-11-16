##############################
CREATE VIEW vwHosSite
AS
SELECT
			S.[Number], 
			S.[GUID], 
			S.[Code], 
			S.[Name], 
			S.[LatinName], 
			s.[Code] + '-' + CASE [dbo].[fnConnections_GetLanguage]() WHEN 1 THEN  S.[LatinName] ELSE S.[Name] END CodeName,
			S.[ParentGUID], 
			S.[TypeGUID], 
			S.[State], 
			S.[Security],
			s.[Status],
			s.[Desc],
			ISNULL(TY.PricePolicy, 0 ) AS PricePolicy,
			t.[Guid]		AS stGuid,
			t.[Code]		AS stCode,
			t.[Name]		AS stName,
			t.[LatinName]	AS stLatinName,
			t.[Notes]		AS stNotes,
			t.[Color]		AS stColor,
			t.[Security]	AS stSecurity,
			t.[CanUse]		AS stCanUse,
			t.[Type]		AS stType
FROM 
			[HosSite000] AS s 
			LEFT JOIN HosSiteType000 AS TY ON TY.Guid = s.TypeGuid
			LEFT JOIN [HosSiteStatus000] AS t ON s.[Status] = t.[Guid]
####################################################
CREATE FUNCTION fnGetEmptySites( @StartDate	[DATETIME],	@EndDate [DATETIME])
	RETURNS TABLE 
AS
	RETURN SELECT * FROM HosSite000 AS Site 
	WHERE Site.Guid Not IN 
	( 
		Select SiteGuid FROM hosReservationDetails000 WHERE 
			@StartDate BETWEEN FromDate AND ToDate
			AND @EndDate BETWEEN FromDate AND ToDate
	)
####################################################
#END