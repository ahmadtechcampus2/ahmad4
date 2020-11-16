#########################################################
## CREATE VIEW vwEnAc
## AS
## /*
## This view is used in entry browsing, 
## so that Al-Ameen can manage the security of accounts within the entry.
## -- By Ali: This view not used at all
## */
##	SELECT
##		[e].*,
##		[a].[acSecurity]
##	FROM
##		[vwEn] [e] INNER JOIN [vwAc] [a] ON [e].[enAccount] = [a].[acGuid]
##		
#########################################################
#END 