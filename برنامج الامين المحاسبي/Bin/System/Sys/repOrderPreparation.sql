#########################################################################
CREATE PROC repOrderPreparation
	@OrderGUID  UNIQUEIDENTIFIER 
AS 
	SET NOCOUNT ON
	
	SELECT
		mt.Code [MtCode], 
		mt.Guid [MtGuid], 
		mt.Name [MtName], 
		mt.LatinName [MtLatinName], 
		ppo.OrderNum [PrepCode], 
		ppo.IsNotAvailableQuantity, 
		bt.Name [TypeName], 
		cu.CustomerName [SupplierName], 
		ppo.Guid [PPoGUID], 
		bi.Qty [Quantity]
	FROM
		ppi000 ppi
		INNER JOIN ppo000 ppo ON ppo.GUID = ppi.PPOGuid 	
		INNER JOIN bu000 bu ON bu.GUID = ppi.SOGuid 
		INNER JOIN bi000 bi ON bi.GUID = ppi.SOIGuid 
		INNER JOIN mt000 mt ON mt.GUID = ppi.MatGuid
		INNER JOIN bt000 bt ON bt.GUID = ppo.TypeGUID
		INNER JOIN cu000 cu ON cu.GUID = ppo.Supplier
	WHERE
		bu.GUID = @OrderGuid 	
		AND 
		ppo.TypeGuid != 0x0 
	ORDER BY
		ppo.Number, 
		ppo.GUID, 
		bi.Number 

#########################################################################
#END
