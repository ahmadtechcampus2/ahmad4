##################################################################
CREATE PROCEDURE PrcTrnUserTree
AS  
	SET NOCOUNT ON 

	SELECT * FROM [fnGetTrnUserList]( 1) ORDER BY Path
##################################################################
#END