#########################################################
CREATE TRIGGER tr_RecostMaterials000_INSERT_UPDATE
ON RecostMaterials000 AFTER INSERT, UPDATE
NOT FOR REPLICATION
AS

	IF (@@ROWCOUNT = 0)
		RETURN;

	SET NOCOUNT ON;

	;WITH CTE (MaterialId, CostId, FirstCostDate)
	AS
	(
		SELECT  bi.biMatPtr, 
		i.[Guid], 
		ISNULL(dbo.fnGetMaterialFirstCostDate(bi.biMatPtr), '1980-1-1')
		FROM vwBuBi bi
		RIGHT JOIN inserted i ON bi.buGUID = i.OutBillGuid
	)
	UPDATE mt 
	SET mt.FirstCostDate = CTE.FirstCostDate
	FROM mt000 mt
	JOIN CTE ON mt.[GUID] = CTE.MaterialId
#########################################################

CREATE TRIGGER tr_RecostMaterials000_DELETE
ON RecostMaterials000 AFTER DELETE
NOT FOR REPLICATION
AS

	IF (@@ROWCOUNT = 0)
		RETURN;

	SET NOCOUNT ON;

	;WITH CTE (MaterialId, CostId, FirstCostDate)
	AS
	(
		SELECT  bi.biMatPtr, 
		d.[Guid], 
		ISNULL(dbo.fnGetMaterialFirstCostDate(bi.biMatPtr), '1980-1-1')
		FROM vwBuBi bi
		RIGHT JOIN deleted d ON bi.buGUID = d.OutBillGuid
	)
	UPDATE mt 
	SET mt.FirstCostDate = CTE.FirstCostDate
	FROM mt000 mt
	JOIN CTE ON mt.[GUID] = CTE.MaterialId
#########################################################
#END