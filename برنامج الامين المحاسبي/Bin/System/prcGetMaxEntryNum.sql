###############################################################
CREATE PROCEDURE prcGetMaxEntryNum
AS
	SET NOCOUNT ON
	SELECT ISNULL(MAX([Number]), 0) AS [Max] FROM [ce000]
##############################################################
#END