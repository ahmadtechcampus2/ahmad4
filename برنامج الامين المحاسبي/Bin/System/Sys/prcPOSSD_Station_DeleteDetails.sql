#############################################
CREATE PROCEDURE prcPOSSD_Station_DeleteDetails(
	@StationGUID UNIQUEIDENTIFIER,
	@ExcludeDelete INT)

AS
    SET NOCOUNT ON
	
	DELETE POSSDStationGroup000			          WHERE StationGUID = @StationGUID	
	-- delete the record if exclude delete = 1, to avoid delete it in update operation
	IF @ExcludeDelete = 1
		DELETE POSSDStationDevice000		          WHERE StationGUID = @StationGUID
	DELETE POSSDStationEmployee000		          WHERE StationGUID = @StationGUID
	DELETE POSSDStationSalesman000		          WHERE StationGUID = @StationGUID
	DELETE POSSDStationResale000		          WHERE StationGUID = @StationGUID
	DELETE POSSDStationCurrency000		          WHERE StationGUID = @StationGUID
	DELETE POSSDStationBankCard000		          WHERE StationGUID = @StationGUID
	DELETE POSSDStationPrintDesign000	          WHERE StationGUID = @StationGUID
	DELETE POSSDStationOption000		          WHERE StationGUID = @StationGUID
	DELETE POSSDStationReturnCouponSettings000    WHERE StationGUID = @StationGUID
	DELETE POSSDStationOrder000				      WHERE StationGUID = @StationGUID
	DELETE POSSDStationDeliveryArea000		      WHERE StationGUID = @StationGUID
	DELETE POSSDStationDrivers000			      WHERE StationGUID = @StationGUID
	DELETE POSSDStationOrderAssociatedStations000 WHERE StationGUID = @StationGUID
	DELETE POSSDStationAddressArea000			  WHERE StationGUID = @StationGUID
	DELETE POSSDStationStores000				  WHERE StationGUID = @StationGUID
##############################################
#END
