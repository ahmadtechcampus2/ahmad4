####################################################################################
CREATE TRIGGER trg_POSSDStation_delete
	ON POSSDStation000 FOR DELETE 
	NOT FOR REPLICATION
AS 
	IF @@ROWCOUNT = 0 
		RETURN 
	SET NOCOUNT ON 
	DELETE rel FROM POSSDStationGroup000 rel INNER JOIN [deleted] [d] ON d.GUID = rel.StationGUID
	DELETE rel FROM POSSDStationDevice000 rel INNER JOIN [deleted] [d] ON d.GUID = rel.StationGUID
	DELETE rel FROM POSSDStationEmployee000 rel INNER JOIN [deleted] [d] ON d.GUID = rel.StationGUID
	DELETE rel FROM POSSDStationSalesman000 rel INNER JOIN [deleted] [d] ON d.GUID = rel.StationGUID
	DELETE rel FROM POSSDStationResale000 rel INNER JOIN [deleted] [d] ON d.GUID = rel.StationGUID 
	DELETE rel FROM POSSDStationCurrency000 rel INNER JOIN [deleted] [d] ON d.GUID = rel.StationGUID 
	DELETE rel FROM POSSDStationBankCard000 rel INNER JOIN [deleted] [d] ON d.GUID = rel.StationGUID  
	DELETE rel FROM POSSDStationPrintDesign000 rel INNER JOIN [deleted] [d] ON d.GUID = rel.StationGUID 
	DELETE rel FROM POSSDStationOption000 rel INNER JOIN [deleted] [d] ON d.GUID = rel.StationGUID 
	-- ***********************************************************************************************
	-- Delete the additional copy print settings related to  the POS station : Begin	
	DELETE detail FROM POSSDAdditionalCopyPrintSettingDetail000 AS detail 
	INNER JOIN POSSDAdditionalCopyPrintSettingHeader000 AS header ON (detail.AdditionalCopyPSGUID = header.GUID) 
	INNER JOIN POSSDRelatedAdditionalCopyPrintSetting000 AS rel on (header.GUID = rel.AdditionalCopyPSGUID)
	INNER JOIN [deleted] [d] ON  (rel.StationGUID = d.GUID)

	DELETE header FROM POSSDAdditionalCopyPrintSettingHeader000 AS header 
	INNER JOIN POSSDRelatedAdditionalCopyPrintSetting000 AS rel on (header.GUID = rel.AdditionalCopyPSGUID)
	INNER JOIN [deleted] [d] ON  (rel.StationGUID = d.GUID)

	DELETE rel FROM POSSDRelatedAdditionalCopyPrintSetting000 rel INNER JOIN [deleted] [d] ON d.GUID = rel.StationGUID 
	-- Delete the additional copy print settings related to  the POS station: End
	-- ***********************************************************************************************
####################################################################################
#END
