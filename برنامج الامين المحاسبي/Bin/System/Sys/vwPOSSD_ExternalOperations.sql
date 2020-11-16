################################################################################
CREATE VIEW vwPOSSDExternalOperations
AS
	SELECT EO.*, 
		CAC.Name AS CreditAccountName,
		CAC.LatinName AS CreditAccountLatinName,
		DAC.Name AS DebitAccountName,
		DAC.LatinName AS DebitAccountLatinName   
	FROM 
		[dbo].POSSDExternalOperation000 EO
		INNER JOIN ac000 CAC ON EO.CreditAccountGUID = CAC.GUID
		INNER JOIN ac000 DAC ON EO.DebitAccountGUID = DAC.GUID
#################################################################
#END
