################################################################
##please don't change vbCo to vwco cause it will make a problem

CREATE view vwExtended_co
AS
select 
	*,
 	(SELECT COUNT(*) FROM [co000] WHERE [parentGuid] = [co].[guid]) AS [NSons]
FROM
	[vbCo] as [co]
/*
prcGetSubCosts
*/

-- select * from vwExtended_co
######################################################################
#END