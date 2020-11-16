##########################################################################
CREATE VIEW vwTrnTRNUSERCASHAcc
AS
	SELECT [trn].*,[ac].[acSecurity] FROM [TRNUSERCASH000] AS [trn] INNER JOIN [vwAc] AS [ac] ON [ac].[acGuid] =[trn].[AccountGuid]
##########################################################################
CREATE VIEW vwTrnTRNUSERCASHCost
AS
	SELECT	
		[trn].*,
		[Co].[CoSecurity] 
	FROM [TRNUSERCASHCOST000] AS [trn] INNER JOIN [vwCo] AS [co] 
		ON [co].[CoGuid] =[trn].[CostGuid]
##########################################################################
#END