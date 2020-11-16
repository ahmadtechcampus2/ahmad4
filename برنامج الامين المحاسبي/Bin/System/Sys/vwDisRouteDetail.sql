##################################################################################
Create view vwDisRouteDetail
AS

	SELECT Ac.Code + '-' + Ac.Name Route
	FROM DistributionRouteDetail000 Dr 
	LEFT JOIN Ac000 Ac On Dr.AccountGuid = Ac.Guid
##################################################################################
#END

