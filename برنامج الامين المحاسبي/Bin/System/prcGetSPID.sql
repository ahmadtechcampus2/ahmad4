#########################################################
CREATE PROCEDURE prcGetSPID
AS
	SELECT [dbo].[fnGetSPID]() AS [SPID]
#########################################################
CREATE PROCEDURE prcGetHOSTIDNAME
AS
	SELECT HOST_NAME() + HOST_ID() AS [HostIDName]
#########################################################
#END