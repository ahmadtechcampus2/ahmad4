########################################
CREATE PROCEDURE prcDistGetVistsByBills
	@DistGuid	UNIQUEIDENTIFIER,
	@Date		DATETIME
AS
	SET NOCOUNT ON 	    
	SELECT  
			bu.Guid,  
			d.Guid AS DistGuid,  
			bu.CustGuid,  
			bu.Cust_Name AS CustName,  
			bu.Date,  
			CAST(bu.Number AS NCHAR) AS Number,  
			bt.Name AS Type,  
			bt.LatinName AS LatinType  
		FROM bu000 AS bu  
		INNER JOIN bt000 AS bt ON bu.TypeGuid = bt.Guid  
		INNER JOIN Distsalesman000 AS ds ON ds.CostGuid = bu.CostGuid  
		INNER JOIN Distributor000 AS d ON d.PrimSalesmanGuid = ds.Guid  
		WHERE d.Guid = @DistGuid AND bu.Date = @Date AND bu.Guid NOT IN (SELECT ObjectGuid FROM DistVd000 WHERE VistGuid IN (SELECT Guid FROM DistVi000))  
		ORDER BY CustGuid
#############################
#END