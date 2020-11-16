###########################################################################
CREATE VIEW vwRestDeliveryFees
AS  
SELECT rdf.[Number]
      ,rdf.[Guid]
      ,rdf.[AreaGuid]
	  ,ar.Name + ' - ' + ar.CityName AS [AreaName]
	  ,ar.LatinName + ' - ' + ar.CityLatinName AS [AreaLatinName]
      ,rdf.[DeliveryFee]
  FROM [dbo].[RestDeliveryFees000] rdf
  INNER JOIN 
  vdAddressArea ar ON ar.[GUID] = rdf.AreaGuid
###########################################################################
#END