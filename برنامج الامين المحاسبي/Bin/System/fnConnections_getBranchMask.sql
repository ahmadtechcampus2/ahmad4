######################################################### 
CREATE FUNCTION fnConnections_getBranchMask()
	returns [BIGINT]
AS BEGIN
	RETURN (ISNULL( (SELECT [branchMask] FROM [connections] WHERE [HostName] = HOST_NAME() AND [HostId] = HOST_ID()), -1))
END

#########################################################
#END
