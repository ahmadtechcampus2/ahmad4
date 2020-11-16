#########################################################
CREATE VIEW vtTrnCloseCashier
AS
	SELECT * FROM TrnCloseCashier000
#########################################################
CREATE VIEW vbTrnCloseCashier
AS
	SELECT [v].*
	FROM [vtTrnCloseCashier] AS [v] INNER JOIN [vwBr] AS [br] ON [v].[BranchGUID] = [br].[brGUID]
###########################
CREATE VIEW CloseCashierWithoutCenter
AS
SELECT [v].*
	FROM vbTrnCloseCashier AS [v] 

 WHERE IsCenter=0 AND ExchangeTypeGUID =0x0
################################################################
CREATE VIEW vbTrnCloseCashierExchange
AS
	SELECT [v].*
	FROM vbTrnCloseCashier AS [v] 
	 WHERE IsCenter=0 AND UserGuid =0x0
################################################################
CREATE VIEW vbTrnCloseCashierCenter
As
	SELECT [v].*
	FROM vbTrnCloseCashier AS [v] 
	WHERE IsCenter=1
#########################################################
CREATE VIEW vcTrnCloseCashier
AS
	SELECT * FROM [vbTrnCloseCashier]
#########################################################
CREATE VIEW vdTrnCloseCashier
AS
	SELECT * FROM [vbTrnCloseCashier]
#########################################################

CREATE VIEW vwTrnCloseCashier
AS
	SELECT * FROM [vbTrnCloseCashier]
#########################################################
CREATE FUNCTION fbTrnCloseCashierCenter
	( @CenterGuid UNIQUEIDENTIFIER)
RETURNS TABLE
AS
	RETURN 
	(
	SELECT vb.* FROM CloseCashierWithoutCenter vb
	where CenterGuid=@CenterGuid
	)
###############################################################
CREATE VIEW vbTrnCenter
AS
	SELECT [v].*
	FROM TrnCenter000 AS [v] INNER JOIN TrnBranch000 tr on [v].[BranchGUID] =tr.GUID
	INNER JOIN [vwBr] AS [br] ON  tr.[AmnBranchGUID]=br.[brGUID]
##############################################################
#END