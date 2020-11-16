################################################################################
CREATE PROCEDURE prcPOSSD_ReTransfer
-- Params -------------------------------
	@DestDBName	NVARCHAR(255)
AS
    SET NOCOUNT ON
------------------------------------------------------------
	DECLARE @Str NVARCHAR(MAX)
	DECLARE @FirstPeriodNewData DATETIME
	CREATE TABLE #TicketToBeDeleted ( TicketGUID UNIQUEIDENTIFIER )
	CREATE TABLE #CouponToBeDeleted ( CouponGUID UNIQUEIDENTIFIER )

	--=========================== RETRANSFER RETURN COUPON
	-------- Delete Return Coupon
	DECLARE @params NVARCHAR(256) = N'@FirstPeriodNewData DATETIME OUTPUT'
	SET @Str = 'SELECT @FirstPeriodNewData = CAST(Value AS DATETIME) FROM ' + @DestDBName + '.[dbo].[op000] WHERE name LIKE ''%AmnCfg_FPDate%'''
	EXEC sp_executesql @Str, @params, @FirstPeriodNewData = @FirstPeriodNewData OUTPUT

	SET @Str  = ' INSERT INTO #CouponToBeDeleted'
	SET @Str += ' SELECT [GUID] '
	SET @Str += ' FROM ' + @DestDBName + '..[POSSDReturnCoupon000] '
	SET @Str += ' WHERE [GUID] IN (SELECT [GUID] FROM POSSDReturnCoupon000)'
	EXEC sp_executesql @Str

	SET @Str = ' DELETE ' + @DestDBName + '..[POSSDReturnCoupon000] WHERE [GUID] IN (SELECT CouponGUID FROM #CouponToBeDeleted)'
	EXEC sp_executesql @Str

	-------- Insert Return Coupon
	SET @Str  = ' INSERT INTO ' + @DestDBName + '..[POSSDReturnCoupon000] (GUID, Amount, ExpiryDays, TransactionDate, CustomerGUID, ReturnSettingsGUID, Code, Type, ProcessedExpiryCoupon)'
	SET @Str += ' SELECT GUID, Amount, ExpiryDays, TransactionDate, CustomerGUID, ReturnSettingsGUID, Code, Type, ProcessedExpiryCoupon FROM  POSSDReturnCoupon000 WHERE'
	SET @Str += ' (DATEADD(DAY, ExpiryDays, CAST(TransactionDate AS DATE))) >= '+CHAR(39)+CAST(@FirstPeriodNewData AS NVARCHAR(36))+CHAR(39)+' AND ProcessedExpiryCoupon IS NULL AND GUID NOT IN (SELECT ReturnCouponGUID FROM POSSDTicketReturnCoupon000 WHERE IsReceipt = 1) '
	EXEC sp_executesql @Str

	--=========================== RETRANSFER ORDER
	-------- Delete Order
	SET @Str  = ' INSERT INTO #TicketToBeDeleted'
	SET @Str += ' SELECT [GUID] '
	SET @Str += ' FROM '+@DestDBName+'..[POSSDTicket000] '
	SET @Str += ' WHERE [STATE] = 5 AND [GUID] IN (SELECT [GUID] FROM POSSDTicket000)'
	EXEC sp_executesql @Str
	
	SET @Str = 'DELETE ' + @DestDBName + '..[POSSDTicket000] WHERE [GUID] IN (SELECT TicketGUID FROM #TicketToBeDeleted)'
	EXEC sp_executesql @Str

	SET @Str = 'DELETE ' + @DestDBName + '..[POSSDTicketItem000] WHERE TicketGUID IN (SELECT TicketGUID FROM #TicketToBeDeleted)'
	EXEC sp_executesql @Str

	SET @Str = 'DELETE ' + @DestDBName + '..[POSSDTicketOrderInfo000] WHERE TicketGUID IN (SELECT TicketGUID FROM #TicketToBeDeleted)'
	EXEC sp_executesql @Str

	-------- Insert Order
	SET @Str  = ' INSERT INTO ' + @DestDBName + '..[POSSDTicket000] (GUID, Number, Code, ShiftGUID, CustomerGUID, Note, DiscValue, IsDiscountPercentage, AddedValue, IsAdditionPercentage, Total, State, 
	CollectedValue, LaterValue, Net, OpenDate, PaymentDate, TaxTotal, Type, SalesmanGUID, RelatedTo, RelationType, RelatedFrom, RelatedFromInfo, SpecialOfferGUID, TaxType, bIsPrinted, 
	IsTaxCalculationBeforeAddition, IsTaxCalculationBeforeDiscount, OrderType, DeviceID, GCCLocationGUID, NetIsRounded, IsDiscountPercentageBeforRounding, IsAdditionPercentageBeforRounding, 
	DiscountValueBeforRounding, AdditionValueBeforRounding)'
	SET @Str +=' SELECT GUID, Number, Code, ShiftGUID, CustomerGUID, Note, DiscValue, IsDiscountPercentage, AddedValue, IsAdditionPercentage, Total, State,	
	CollectedValue, LaterValue, Net, OpenDate, PaymentDate, TaxTotal, Type, SalesmanGUID, RelatedTo, RelationType, RelatedFrom, RelatedFromInfo, SpecialOfferGUID, TaxType, bIsPrinted, 
	IsTaxCalculationBeforeAddition, IsTaxCalculationBeforeDiscount, OrderType, DeviceID, GCCLocationGUID, NetIsRounded, IsDiscountPercentageBeforRounding, IsAdditionPercentageBeforRounding, 
	DiscountValueBeforRounding, AdditionValueBeforRounding FROM  POSSDTicket000 WHERE [State] = 5'
	SET @Str += ' AND [GUID] NOT IN (SELECT [GUID] FROM ' + @DestDBName + '..[POSSDTicket000])'
	EXEC sp_executesql @Str

	SET @Str  = ' INSERT INTO ' + @DestDBName + '..[POSSDTicketItem000] (GUID, Number, TicketGUID, MatGUID, Qty, Price, Value, Unit, DiscountValue, ItemShareOfTotalDiscount, IsDiscountPercentage,	
	AdditionValue, ItemShareOfTotalAddition, IsAdditionPercentage, PriceType, IsManualPrice, UnitType, PresentQty, Tax, TaxRatio, SpecialOfferGUID, SpecialOfferQty, 
	ReturnedQty, NumberOfSpecialOfferApplied, SpecialOfferSlideGUID, TaxCode)'
	SET @Str += ' SELECT GUID, Number, TicketGUID, MatGUID, Qty, Price, Value, Unit, DiscountValue, ItemShareOfTotalDiscount, IsDiscountPercentage,	AdditionValue, ItemShareOfTotalAddition,
	IsAdditionPercentage, PriceType, IsManualPrice, UnitType, PresentQty, Tax, TaxRatio, SpecialOfferGUID, SpecialOfferQty, ReturnedQty, NumberOfSpecialOfferApplied, SpecialOfferSlideGUID, 
	TaxCode FROM POSSDTicketItem000 WHERE TicketGUID IN (SELECT [GUID] FROM POSSDTicket000 WHERE [State] = 5)'
	SET @Str += ' AND [GUID] NOT IN (SELECT [GUID] FROM ' + @DestDBName + '..[POSSDTicketItem000])'
	EXEC sp_executesql @Str

	SET @Str  = ' INSERT INTO ' + @DestDBName + '..[POSSDTicketOrderInfo000]([GUID], Number, TicketGUID,	ETD, EDD, DriverGUID, DownPayment, DeliveryFee, TripGUID, IsEDDDefined, AreaGUID, CustomerAddressGUID, StationGUID)'
	SET @Str += ' SELECT [GUID], Number, TicketGUID, ETD, EDD, DriverGUID, DownPayment, DeliveryFee, TripGUID, IsEDDDefined, AreaGUID, CustomerAddressGUID, StationGUID '
	SET @Str += ' FROM POSSDTicketOrderInfo000 '
	SET @Str += ' WHERE TicketGUID IN (SELECT [GUID] FROM POSSDTicket000 WHERE [State] = 5)'
	SET @Str += ' AND [GUID] NOT IN (SELECT [GUID] FROM ' + @DestDBName + '..[POSSDTicketOrderInfo000])'
	EXEC sp_executesql @Str

	--=========================== Station
	DECLARE @UpdatePreTransferedData BIT
	SET @UpdatePreTransferedData = 1

	SET @Str = '[GUID] IN (SELECT [GUID] FROM [POSSDStation000]) '
	EXEC [prcCopyTbl] @DestDBName, 'POSSDStation000', @Str, 1, 0, @UpdatePreTransferedData

	SET @Str = 'StationGUID IN (SELECT StationGUID FROM [POSSDStationAddressArea000]) '
	EXEC [prcCopyTbl] @DestDBName, 'POSSDStationAddressArea000', @Str, 1, 0, @UpdatePreTransferedData

	SET @Str = 'StationGUID IN (SELECT StationGUID FROM [POSSDStationBankCard000]) '
	EXEC [prcCopyTbl] @DestDBName, 'POSSDStationBankCard000', @Str, 1, 0, @UpdatePreTransferedData

	SET @Str = 'StationGUID IN (SELECT StationGUID FROM [POSSDStationCurrency000]) '
	EXEC [prcCopyTbl] @DestDBName, 'POSSDStationCurrency000', @Str, 1, 0, @UpdatePreTransferedData

	SET @Str = 'StationGUID IN (SELECT StationGUID FROM [POSSDStationDeliveryArea000]) '
	EXEC [prcCopyTbl] @DestDBName, 'POSSDStationDeliveryArea000', @Str, 1, 0, @UpdatePreTransferedData

	SET @Str = 'StationGUID IN (SELECT StationGUID FROM [POSSDStationDevice000]) '
	EXEC [prcCopyTbl] @DestDBName, 'POSSDStationDevice000', @Str, 1, 0, @UpdatePreTransferedData

	SET @Str = 'StationGUID IN (SELECT StationGUID FROM [POSSDStationDrivers000]) '
	EXEC [prcCopyTbl] @DestDBName, 'POSSDStationDrivers000', @Str, 1, 0, @UpdatePreTransferedData
	
	SET @Str = 'StationGUID IN (SELECT StationGUID FROM [POSSDStationEmployee000]) '
	EXEC [prcCopyTbl] @DestDBName, 'POSSDStationEmployee000', @Str, 1, 0, @UpdatePreTransferedData

	SET @Str = 'StationGUID IN (SELECT StationGUID FROM [POSSDStationGroup000]) '
	EXEC [prcCopyTbl] @DestDBName, 'POSSDStationGroup000', @Str, 1, 0, @UpdatePreTransferedData

	SET @Str = 'StationGUID IN (SELECT StationGUID FROM [POSSDStationOption000]) '
	EXEC [prcCopyTbl] @DestDBName, 'POSSDStationOption000', @Str, 1, 0, @UpdatePreTransferedData

	SET @Str = 'StationGUID IN (SELECT StationGUID FROM [POSSDStationOrder000]) '
	EXEC [prcCopyTbl] @DestDBName, 'POSSDStationOrder000', @Str, 1, 0, @UpdatePreTransferedData

	SET @Str = 'StationGUID IN (SELECT StationGUID FROM [POSSDStationOrderAssociatedStations000]) '
	EXEC [prcCopyTbl] @DestDBName, 'POSSDStationOrderAssociatedStations000', @Str, 1, 0, @UpdatePreTransferedData

	SET @Str = 'StationGUID IN (SELECT StationGUID FROM [POSSDStationResale000]) '
	EXEC [prcCopyTbl] @DestDBName, 'POSSDStationResale000', @Str, 1, 0, @UpdatePreTransferedData

	SET @Str = 'StationGUID IN (SELECT StationGUID FROM [POSSDStationReturnCouponSettings000]) '
	EXEC [prcCopyTbl] @DestDBName, 'POSSDStationReturnCouponSettings000', @Str, 1, 0, @UpdatePreTransferedData

	SET @Str = 'StationGUID IN (SELECT StationGUID FROM [POSSDStationReturnStations000]) '
	EXEC [prcCopyTbl] @DestDBName, 'POSSDStationReturnStations000', @Str, 1, 0, @UpdatePreTransferedData

	SET @Str = 'StationGUID IN (SELECT StationGUID FROM [POSSDStationSalesman000]) '
	EXEC [prcCopyTbl] @DestDBName, 'POSSDStationSalesman000', @Str, 1, 0, @UpdatePreTransferedData

	SET @Str = 'StationGUID IN (SELECT StationGUID FROM [POSSDStationSpecialOffer000]) '
	EXEC [prcCopyTbl] @DestDBName, 'POSSDStationSpecialOffer000', @Str, 1, 0, @UpdatePreTransferedData

	SET @Str = 'StationGUID IN (SELECT StationGUID FROM [POSSDStationStores000]) '
	EXEC [prcCopyTbl] @DestDBName, 'POSSDStationStores000', @Str, 1, 0, @UpdatePreTransferedData

	SET @Str = 'StationGUID IN (SELECT StationGUID FROM [POSSDStationSyncModifiedData000]) '
	EXEC [prcCopyTbl] @DestDBName, 'POSSDStationSyncModifiedData000', @Str, 1, 0, @UpdatePreTransferedData

	--=========================== RETRANSFER Employee
	SET @Str = 'GUID IN (SELECT GUID FROM [POSSDEmployee000]) '
	EXEC [prcCopyTbl] @DestDBName, 'POSSDEmployee000', @Str, 1, 0, @UpdatePreTransferedData

	SET @Str = 'EmployeeGUID IN (SELECT EmployeeGUID FROM [POSSDEmployeePermissions000]) '
	EXEC [prcCopyTbl] @DestDBName, 'POSSDEmployeePermissions000', @Str, 1, 0, @UpdatePreTransferedData

	--=========================== RETRANSFER Salesman
	SET @Str = 'GUID IN (SELECT GUID FROM [POSSDSalesman000]) '
	EXEC [prcCopyTbl] @DestDBName, 'POSSDSalesman000', @Str, 1, 0, @UpdatePreTransferedData

	--===========================RETRANSFER Driver
	SET @Str = 'GUID IN (SELECT GUID FROM [POSSDDriver000]) '
	EXEC [prcCopyTbl] @DestDBName, 'POSSDDriver000', @Str, 1, 0, @UpdatePreTransferedData

	--=========================== RETRANSFER BankCard
	SET @Str = 'StationGUID IN (SELECT StationGUID FROM [POSSDStationBankCard000]) '
	EXEC [prcCopyTbl] @DestDBName, 'POSSDStationBankCard000', @Str, 1, 0, @UpdatePreTransferedData

	--=========================== RETRANSFER Material Extended
	SET @Str = 'GUID IN (SELECT GUID FROM [POSSDMaterialExtended000]) '
	EXEC [prcCopyTbl] @DestDBName, 'POSSDMaterialExtended000', @Str, 1, 0, @UpdatePreTransferedData
	
	SET @Str = 'ParentGUID IN (SELECT [ParentGUID] From POSSDRelatedSaleMaterial000) '
    EXEC [prcCopyTbl] @DestDBName, 'POSSDRelatedSaleMaterial000', @Str, 1, 0, @UpdatePreTransferedData

	--------------------------------- PRINT --------------------------------- 
	--=========================== Print Design
	SET @Str = 'StationGUID IN (SELECT StationGUID FROM [POSSDStationPrintDesign000]) '
	EXEC [prcCopyTbl] @DestDBName, 'POSSDStationPrintDesign000', @Str, 1, 0, @UpdatePreTransferedData

	EXEC [prcCopyTbl] @DestDBName, 'POSSDStationPrintDesignType000', '', 0, 1, 0
	
	SET @Str = 'GUID IN (SELECT GUID FROM [POSSDPrintDesign000]) '
	EXEC [prcCopyTbl] @DestDBName, 'POSSDPrintDesign000', @Str, 1, 0, @UpdatePreTransferedData

	SET @Str = 'ParentGUID IN (SELECT ParentGUID FROM [POSSDPrintDesignSection000]) '
	EXEC [prcCopyTbl] @DestDBName, 'POSSDPrintDesignSection000', @Str, 1, 0, @UpdatePreTransferedData

	SET @Str = 'ParentGUID IN (SELECT ParentGUID FROM [POSSDPrintDesignSectionItem000]) '
	EXEC [prcCopyTbl] @DestDBName, 'POSSDPrintDesignSectionItem000', @Str, 1, 0, @UpdatePreTransferedData

	--=========================== Additional Copy Print Setting Header
	SET @Str = 'GUID IN (SELECT GUID FROM [POSSDAdditionalCopyPrintSettingHeader000]) '
	EXEC [prcCopyTbl] @DestDBName, 'POSSDAdditionalCopyPrintSettingHeader000', @Str, 1, 0, @UpdatePreTransferedData
	
	SET @Str = 'AdditionalCopyPSGUID IN (SELECT AdditionalCopyPSGUID FROM [POSSDAdditionalCopyPrintSettingDetail000]) '
	EXEC [prcCopyTbl] @DestDBName, 'POSSDAdditionalCopyPrintSettingDetail000', @Str, 1, 0, @UpdatePreTransferedData

	SET @Str  = 'StationGUID IN (SELECT StationGUID FROM [POSSDRelatedAdditionalCopyPrintSetting000]) '
	SET @Str += 'AND AdditionalCopyPSGUID IN (SELECT AdditionalCopyPSGUID FROM [POSSDRelatedAdditionalCopyPrintSetting000])'
	EXEC [prcCopyTbl] @DestDBName, 'POSSDRelatedAdditionalCopyPrintSetting000', @Str, 1, 0, 1

#################################################################
#END
