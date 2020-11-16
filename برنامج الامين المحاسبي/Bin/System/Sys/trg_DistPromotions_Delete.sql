##################################################################################
CREATE TRIGGER trg_DistPromotions_Delete ON DistPromotions000 FOR DELETE
NOT FOR REPLICATION
AS
	DELETE DistPromotionsDetail000 
		FROM DistPromotionsDetail000 AS pd INNER JOIN deleted AS d ON pd.ParentGuid = d.Guid
	DELETE DistPromotionsBudget000 
		FROM DistPromotionsBudget000 AS pb INNER JOIN deleted AS d ON pb.ParentGuid = d.Guid
	DELETE DistPromotionsCustType000 
		FROM DistPromotionsCustType000 AS pc INNER JOIN deleted AS d ON pc.ParentGuid = d.Guid
##################################################################################
#END
