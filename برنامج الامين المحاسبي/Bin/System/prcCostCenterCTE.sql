###########################
CREATE PROC GetMainCostCenterParents
@MainCostCenterGUID uniqueidentifier,
@ChildCostCenterGUID uniqueidentifier
AS
BEGIN

SET NOCOUNT ON;

With CostCardCTE ([GUID], [ParentGUID])
AS
(
	SELECT CostCenter.[GUID], CostCenter.[ParentGUID]
	FROM co000 AS CostCenter
	WHERE CostCenter.[GUID] = @MainCostCenterGUID

	UNION ALL 

	SELECT CostCenter.[GUID], CostCenter.[ParentGUID]
	FROM co000 AS CostCenter 
	JOIN CostCardCTE
	ON CostCenter.[GUID] = CostCardCTE.[ParentGUID]
	
)

SELECT [GUID] FROM CostCardCTE WHERE [GUID] = @ChildCostCenterGUID

END

###########################
#END

