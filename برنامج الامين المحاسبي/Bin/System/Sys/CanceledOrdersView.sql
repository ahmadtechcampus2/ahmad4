###########################
CREATE VIEW CanceledOrdersView as 
	 SELECT  
		ord.number AS ordernumber,
		cancelationdate,
		SUM(ordi.qty*ordi.price+ordi.Added + ordi.tax - ordi.discount) AS total,
		us.loginname AS loginName,
		us.guid AS userGuid,
		ord.OldState AS OldState
	  FROM 
		RestDeletedOrders000 ord 
		join restDeletedOrderItems000 ordi ON ord.guid = ordi.Parentid 
		join us000 us ON us.guid = ord.userguid
	GROUP BY 
		ord.Number, ord.CancelationDate, loginName, us.guid, ord.OldState
###########################
#END