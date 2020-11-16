################################################################################
## 
CREATE PROC repSOGetBillTypes
	@smGUID [UNIQUEIDENTIFIER]
AS 
SET NOCOUNT ON
SELECT [btGuid] FROM [smbt000]  
WHERE [parentguid] = @smGUID
###################################################################################
#END
