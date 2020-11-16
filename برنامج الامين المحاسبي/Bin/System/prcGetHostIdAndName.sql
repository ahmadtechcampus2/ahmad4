#########################################################
CREATE PROCEDURE prcGetHostIdAndName
AS 
	SET NOCOUNT ON
	SELECT Host_Name() AS [HostName], Host_Id() AS [HostId] 
#########################################################
#END
