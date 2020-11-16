#########################################################
CREATE VIEW vtTrnDeposit
AS
	SELECT * FROM TrnDeposit000
#########################################################
CREATE VIEW vbTrnDeposit
AS
	SELECT v.*
	FROM 
		vtTrnDeposit AS v
		INNER JOIN vwBr AS br ON v.BranchGUID = br.brGUID OR V.BranchGUID = 0x
#########################################################
CREATE VIEW vwTrnDeposit
AS
	SELECT * 
	FROM vbTrnDeposit
	WHERE
		(
			(OwnerUserGuid = 0x OR OwnerUserGuid = dbo.fnGetCurrentUserGUID()) 
			OR [dbo].[fnGetUserSec](dbo.fnGetCurrentUserGUID(), 536932693, 0x0, 1, 0) >= 1
		)
		AND [dbo].[fnGetUserSec](dbo.fnGetCurrentUserGUID(), 536933632, TypeGuid, 1, 1) >= 1
		AND Type = 1
#########################################################
CREATE VIEW vwTrnWithDrawal
AS
	SELECT * 
	FROM vbTrnDeposit
	WHERE
		(
			(OwnerUserGuid = 0x OR OwnerUserGuid = dbo.fnGetCurrentUserGUID()) 
			OR [dbo].[fnGetUserSec](dbo.fnGetCurrentUserGUID(), 536932694, 0x0, 1, 0) >= 1
		)
		AND [dbo].[fnGetUserSec](dbo.fnGetCurrentUserGUID(), 536933632, TypeGuid, 1, 1) >= 1
		And Type = 2
########################################################	
#END