#########################################################
CREATE VIEW vwTrnSimpleExchangeTypes
AS  
	SELECT	* FROM  vtTrnExchangeTypes 
	where type = 0
#########################################################
CREATE VIEW vwTrnComplexExchangeTypes
AS  
	SELECT	* FROM  vtTrnExchangeTypes 
	where type = 1
#########################################################
#END