#################################################################
CREATE PROCEDURE prcPOSSD_Station_GetSpecialOffers
-- Param -------------------------------   
	   @StationGUID UNIQUEIDENTIFIER
-----------------------------------------   
AS 
BEGIN 
SELECT DISTINCT 
	   so.[GUID]
      ,so.[Number]
      ,so.[Name]
      ,so.[LatinName]
      ,so.[Type]
      ,so.[Discount]
      ,so.[IsDiscountPercentage]
      ,so.[MaxQty]
      ,so.[ExpireQty]
      ,so.[IsNotifyWhenclosetoOffer]
      ,so.[IsCompoundWithOffers]
      ,so.[IsAppliedOnValueMultiplies]
      ,so.[IsDateRange]
      ,so.[IsTimeRange]
      ,so.[StartDate]
	  ,so.[StartDateTime]
      ,so.[EndDate]
	  ,so.[EndDateTime]
      ,so.[StartTime]
      ,so.[EndTime]
      ,so.[Saturday]
      ,so.[Sunday]
      ,so.[Monday]
      ,so.[Tuesday]
      ,so.[Wednesday]
      ,so.[Thursday]
      ,so.[Friday]
      ,so.[OfferQty]
      ,so.[GrantQty]
      ,so.[IsTimeLinkedToDate]
	  ,so.[IsAppliedToAllStations]
	  ,so.[OfferSpentAmount]
	  ,so.[State]
	  ,IsNull(SSO.IsSynchronized , 0) AS IsSynchronized
		FROM vwPOSSDSpecialOffer SO LEFT JOIN POSSDStationSpecialOffer000 SSO ON SO.GUID = SSO.SpecialOfferGUID AND SSO.StationGUID = @StationGUID
	WHERE (SO.State = 1  OR SO.State = 2) 
	  AND ( SSO.StationGUID IN (CASE	WHEN SO.IsAppliedToAllStations = 0 THEN  @StationGUID END )
	       OR SO.IsAppliedToAllStations = 1)
END  
#################################################################
#END 