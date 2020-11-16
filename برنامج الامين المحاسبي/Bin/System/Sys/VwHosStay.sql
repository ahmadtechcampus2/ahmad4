##########################################
CREATE VIEW VwHosStay
	AS
	SELECT
	d.[Number] 			AS StayNumber,  
	d.[GUID]	  		AS StayGUID, 
	d.[FileGUID] 		AS StayFileGUID, 
	d.[StartDate] 		AS StayStartDate, 
	d.[EndDate] 		AS StayEndDate, 
	d.[Cost] 			AS StayCost, 
	d.[OtherCost]		AS StayOtherCost, 
	d.[Discount] 		AS StayDiscount, 
	d.[Notes] 			AS StayNotes, 
	d.[Security]		AS StaySecurity, 
	d.[SiteGuid]		AS StaySiteGuid, 
	d.[AccGuid]			AS StayAccGuid, 
	d.[IsAuto]			AS StayIsAuto, 
	d.[BedGuid]			AS StayBedGuid, 
	s.[Guid]			AS SiteGuid, 
	s.[Code]			AS SiteCode, 
	s.[Name]			AS SiteName, 
	s.[LatinName]		AS SiteLatinName, 
	s.[ParentGuid]		AS SiteParentGuid, 
	s.[TypeGuid]		AS SiteTypeGuid, 
	s.[State]			AS SiteState, 
	s.[Security]		AS SiteSecurity, 
	s.[Status]			AS SiteStatus, 
	s.[Desc]			AS SiteDesc,
	d.[EntryGuid]		AS StayEntryGuid, 
	d.[CurrencyGuid]	AS StayCurrencyGuid, 
	d.[CurrencyVal]		AS StayCurrencyVal ,
	d.[PersonCount]		AS StayPersonCount,	
	Type.[Name]			As SiteTypeName,
	Type.[Code]			As SiteTypeCode
		
FROM [HosStay000] AS d  
INNER JOIN fnHosSite(0x0) AS s ON d.[SiteGUID] = s.[Guid]
INNER JOIN HosSiteType000  As Type ON Type.Guid = s.TypeGuid	
########################################
#END
