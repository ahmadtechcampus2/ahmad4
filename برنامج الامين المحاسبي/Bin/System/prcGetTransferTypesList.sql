#######################
CREATE PROC prcGetTransferTypesList
	@IsCurrentBranchOnly 	INT = 0,
	@CurBranch				UNIQUEIDENTIFIER = 0x0
AS 
	--SET NOCOUNT ON
	--SELECT 
		--[Guid], 
		--[Name] 
	--FROM 
		--TrnTransferTypes000 AS T
	--WHERE 
		--(@IsCurrentBranchOnly = 0) 
		--OR ( T.SourceBranchGuid = @CurBranch) 
		--OR ( @CurBranch = 0x0) 
		--OR ( T.SourceBranchGuid IN ( SELECT [GUID] FROM fnGetBranchParents( @CurBranch)))
	--ORDER BY
		--SortNum
 
/*
EXEC prcGetTransferTypesList
*/
########################
#END 