########################################
CREATE PROCEDURE prcDistGetVistsByEntries
	@DistGuid	UNIQUEIDENTIFIER,
	@Date		DATETIME
AS
	SET NOCOUNT ON 
	SELECT  
		ce.Guid AS Guid,  
		d.Guid AS DistGuid,  
		ce.Date,  
		CAST(ce.Number AS NCHAR) AS Number,  
		et.Name AS Type,  
		et.LatinName AS LatinType  
	INTO #TempTbl  
	FROM en000 AS en  
	INNER JOIN ce000 AS ce ON en.ParentGuid = ce.Guid  
	INNER JOIN et000 AS et ON ce.TypeGuid = et.Guid  
	INNER JOIN Distsalesman000 AS ds ON ds.AccGuid = en.AccountGuid  
	INNER JOIN Distributor000 AS d ON d.PrimSalesmanGuid = ds.Guid  
	WHERE d.Guid = @DistGuid AND ce.Date = @Date  
	SELECT DISTINCT  
		en.Guid AS EnGuid,  
		tmp.Guid AS CeGuid, 
		tmp.DistGuid,  
		cu.Guid AS CustGuid,  
		cu.CustomerName AS CustName,  
		tmp.Date,  
		tmp.Number,  
		tmp.Type,  
		tmp.LatinType  
	FROM en000 AS en  
	INNER JOIN #TempTbl AS tmp ON en.ParentGuid = tmp.Guid  
	INNER JOIN cu000 AS cu ON en.AccountGuid = cu.AccountGuid  
	WHERE en.Guid NOT IN (SELECT ObjectGuid FROM DistVd000 WHERE VistGuid IN (SELECT Guid FROM DistVi000))
	ORDER BY CustGuid
#############################
#END