########################################
CREATE VIEW vwDistCommPoint
AS
	SELECT
		Guid  AS CommPointGUID,
		HtGuid AS  CommPointHtGuid,
		Efficiency AS CommPointEfficiency,
		Target AS  CommPointTarget,
		Priority AS  CommPointPriority,
		Incentive AS CommPointIncentive
	FROM DistCommPoint000
########################################	
CREATE VIEW vwDistCommIncentive
AS
	SELECT
		GUID AS DistCommIncGUID,
		PeriodGuid AS DistCommIncPeriodGuid,
		DistGuid AS DistCommIncDistGuid,
		IncPoint AS DistCommIncIncPoint
	FROM DistCommIncentive000
########################################	
CREATE VIEW vwDistCommissionPrice
AS
	SELECT
		Guid  AS CommPrGuid,
		HtGuid AS CommPrHtGuid,
		PointFrom AS CommPointFrom,
		Price AS CommPointPrice,
		CurrencyGuid AS CommPrCurrencyGuid,
		CurrencyVal AS CommPrCurrencyVal,
		PeriodGuid	 AS CommPrPeriodGuid
	FROM DistCommissionPrice000
########################################	
CREATE VIEW vwDistPrPoint
AS 
	SELECT
		GUID AS PrPointGUID ,
		PrFrom AS PrPointPrFrom ,
		PrTo AS PrPointPrTo ,
		POINT AS PrPointPOINT
	FROM DistPrPoint000
######################################
#END
