#########################################################
CREATE VIEW vtLCMain
AS
	SELECT * FROM LCMain000
###########################################################################
CREATE VIEW vbLCMain
AS
	SELECT [LCMain].* 
	FROM [vtLCMain] AS [LCMain] WHERE [LCMain].[branchMask] & [dbo].[fnConnections_getBranchMask]() <> 0
###########################################################################
CREATE VIEW vwLCMain
AS
	SELECT * FROM vbLCMain 
###########################################################################
#END