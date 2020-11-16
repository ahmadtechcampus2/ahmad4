########################################################
CREATE  VIEW vwHosCHECKS
AS 

SELECT  
	nt.GUID     AS GUID,
	hfile.GUID  AS FileGUID,
	ch.GUID     AS CheckGUID,
	ch.Date     AS Date,
	ch.Val      AS Val,
	ch.State    AS State,
	nt.Name     AS Name,
	ch.Security As Security 
FROM ch000 AS ch
	INNER JOIN hospfile000 hfile 
		ON ((ch.AccountGUID = hfile.AccGuid ) 
		AND (ch.Cost1GUID = hfile.CostGuid))
	INNER JOIN nt000 AS nt       
		ON (ch.TypeGuid = nt.Guid)
########################################################
#END