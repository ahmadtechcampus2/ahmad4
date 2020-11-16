################################################################################
CREATE VIEW vtTrnUserConfig
AS
	SELECT * FROM TrnUserConfig000
################################################################################
CREATE VIEW vbTrnUserConfig
AS
	SELECT 
		vtTrnUserConfig.* 
	FROM 
		vtTrnUserConfig
		INNER JOIN vwBr ON vwBr.brGUID = vtTrnUserConfig.TrnBranchGuid OR TrnBranchGuid = 0x0
################################################################################
CREATE VIEW vwTrnUserConfig
AS
	SELECT * FROM vbTrnUserConfig
###################################################################################
#END 	
