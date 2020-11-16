##################################################################################
CREATE VIEW vwPOSSDSpecialOffer
AS
SELECT [GUID]
      ,[Number]
      ,[Name]
      ,[LatinName]
      ,[Type]
      ,[Discount]
      ,[IsDiscountPercentage]
      ,[MaxQty]
      ,[ExpireQty]
      ,[IsNotifyWhenclosetoOffer]
      ,[IsCompoundWithOffers]
      ,[IsAppliedOnValueMultiplies]
      ,[IsDateRange]
      ,[IsTimeRange]
      ,[StartDate]
	  ,CASE WHEN [IsTimeLinkedToDate] = 1 THEN [StartDate] + CAST(CAST([StartTime] AS TIME) AS DATETIME) ELSE [StartDate] END AS [StartDateTime]
      ,[EndDate]
	  ,CASE WHEN [IsTimeLinkedToDate] = 1 THEN [EndDate] + CAST(CAST([EndTime] AS TIME) AS DATETIME) ELSE [EndDate] END AS [EndDateTime]
      ,[StartTime]
      ,[EndTime]
      ,[Saturday]
      ,[Sunday]
      ,[Monday]
      ,[Tuesday]
      ,[Wednesday]
      ,[Thursday]
      ,[Friday]
      ,[OfferQty]
      ,[GrantQty]
      ,[IsTimeLinkedToDate]
	  ,[IsAppliedToAllStations]
	  ,[OfferSpentAmount]
	  ,(CASE
			WHEN [IsForcedToStop] <> 0 THEN 4
			WHEN [ExpireQty] <> 0 AND ((SELECT dbo.fnPOSSD_Station_IsOfferStillAvailable([GUID], [Type])) = 0) THEN 3 
			WHEN [IsDateRange] = 0 THEN 2 
			WHEN [IsDateRange] = 1 AND StartDate IS NOT NULL AND EndDate IS NULL THEN 1
			WHEN [IsDateRange] = 1 AND [IsTimeLinkedToDate] = 1 
				AND [EndDate] + CAST(CAST([EndTime] AS TIME) AS DATETIME) < GETDATE() THEN 3
			WHEN [IsDateRange] = 1 AND [IsTimeLinkedToDate] = 1 
				AND [StartDate] + CAST(CAST([StartTime] AS TIME) AS DATETIME) > GETDATE() THEN 2
			WHEN [IsDateRange] = 1 AND [IsTimeLinkedToDate] = 1 
				AND [StartDate] + CAST(CAST([StartTime] AS TIME) AS DATETIME) < GETDATE() THEN 1
			WHEN [IsDateRange] = 1 
				AND CONVERT(DATE, [EndDate], 120) < CONVERT(DATE, GETDATE(), 120) THEN 3
			WHEN [IsDateRange] = 1 
				AND CONVERT(DATE, [StartDate], 120) > CONVERT(DATE, GETDATE(), 120) THEN 2
			WHEN [IsDateRange] = 1 
				AND CONVERT(DATE, [StartDate], 120) <= CONVERT(DATE, GETDATE(), 120) THEN 1
		END) AS [State]
  FROM [dbo].[POSSDSpecialOffer000]
##################################################################################
#END