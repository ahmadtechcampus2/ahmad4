###############################################################################
CREATE PROC prcPOSSD_PrintDesign_InitType
AS
BEGIN

	IF NOT EXISTS(SELECT* FROM POSSDStationPrintDesignType000 WHERE DesignType = 1)
		INSERT INTO POSSDStationPrintDesignType000 VALUES(NEWID(), 1, 'Delivery', 1)

	IF NOT EXISTS(SELECT* FROM POSSDStationPrintDesignType000 WHERE DesignType = 2)
		INSERT INTO POSSDStationPrintDesignType000 VALUES(NEWID(), 2, 'Pickup', 2)
	
	IF NOT EXISTS(SELECT* FROM POSSDStationPrintDesignType000 WHERE DesignType = 3)
		INSERT INTO POSSDStationPrintDesignType000 VALUES(NEWID(), 3, 'DriverSummary', 3)

END
###################################################################################
#END
