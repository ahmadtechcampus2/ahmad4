######################################################### 
CREATE PROC prcConnections_setBranchMask
	@mask [BIGINT] = 0
AS
	UPDATE [connections] SET [branchMask] = @mask WHERE [HostName] = HOST_NAME() AND [HostId] = HOST_ID()

#########################################################
#END
