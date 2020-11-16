#########################################################
CREATE PROCEDURE prcGetHostId
AS 
	SET NOCOUNT ON
	SELECT Host_Id() AS [HostId] 
#########################################################
#END
