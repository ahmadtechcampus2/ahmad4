#########################################################
CREATE PROCEDURE prcGetMaterialTargets
	@matGuid			UNIQUEIDENTIFIER = 0x0
AS
BEGIN
	DECLARE @IsBranchesEnabled BIT
	DECLARE @BranchMask BIGINT
	DECLARE @UserGUID UNIQUEIDENTIFIER
	
	SET @UserGUID = [dbo].[fnGetCurrentUserGUID]()
	SET @IsBranchesEnabled = [dbo].[fnOption_get]('EnableBranches', '0')
	SELECT @BranchMask = [BranchMask] from [Connections] WHERE [UserGUID] = @UserGUID
	SELECT
		vw.[GUID],
		vw.[mtGuid],
		vw.[MatCode],
		vw.[MatName],
		vw.[MatLatinName],
		vw.[MatSec],
		vw.[stGuid],
		vw.[StoreName],
		vw.[StoreCode],
		vw.[bdpGuid],
		vw.[PeriodName],
		vw.[PeriodCode],
		vw.[TargetQty],
		vw.[SalesPrice],
		vw.[TargetPrice],
		(CASE	WHEN @IsBranchesEnabled = 1
				THEN (CASE	WHEN (st.[branchMask] & ISNULL(@BranchMask, 0)) <> 0
							THEN 1
							ELSE 0
					  END)
				ELSE -9
		 END) AS BranchStoreSecurity,
		(CASE	WHEN (st.[Security] <= [dbo].fnGetUserStoreSec_Browse(@UserGUID))
				THEN 1
				ELSE 0
		 END) AS StoreSecurity
	FROM 
		[dbo].[vwMatTargets] vw
		INNER JOIN [st000] st ON st.[GUID] = vw.[stGuid]
	WHERE
		(mtGuid = @matGuid)
	ORDER BY 
		PeriodStartDate DESC, 
		StoreCode DESC
END
#########################################################
#END