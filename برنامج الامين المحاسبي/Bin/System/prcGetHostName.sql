#########################################################
CREATE PROCEDURE prcGetHostName
AS 
	SET NOCOUNT ON
	SELECT Host_Name() AS [HostName] 
#########################################################
#END
