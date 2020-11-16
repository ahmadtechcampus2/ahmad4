#########################################################
CREATE VIEW vwAreasFromPOSSDAndCustomers
AS
	SELECT Area FROM POSSDStationDeliveryArea000
	UNION 
	SELECT Area FROM vexCu
#########################################################
#end