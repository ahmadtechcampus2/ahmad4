################################################################################
CREATE view VwRepHosGeneralOp
as
select 
	g.guid,
	op.[Name],
	AC.[Name] as OpAccount,
	g.[date],
	g.cost,
	g.notes,
	g.discount,
	g.workerfee,
	--g.workerfee * 100 / g.cost as ratio,
	IsNull(p.[Name],'') as workerName,
	IsNull(c.GUID,0X0) as CurrencyGuid,
	IsNull(c.[Name],'') as CurrencyName


from 	hosgeneraltest000 g
	INNER JOIN hosGeneraloperation000 as op on op.Guid = g.OperationGuid 
	left JOIN hosemployee000 as em on em.Guid = g.workerGuid
	left JOIN hosperson000 as p on p.Guid = em.personGuid
	INNER JOIN AC000 AS ac on AC.Guid = g.accGuid
	left JOIN my000 as c on c.Guid = g.CurrencyGuid

################################################################################
#END