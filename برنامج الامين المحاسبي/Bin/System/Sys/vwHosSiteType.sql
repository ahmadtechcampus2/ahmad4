##############################
CREATE VIEW vwHosSiteType
AS
SELECT
			Number, 
			GUID, 
			Code, 
			Name, 
			LatinName, 
			ResPer, 
			Price, 
			PricePolicy,
			Notes, 
			Security
	FROm HosSiteType000

##############################
#END