################################################################################
CREATE PROCEDURE prcPOSSD_Station_GetCustomerSupplierAddress
-- Params -------------------------------   
	@StationGuid		UNIQUEIDENTIFIER,
	@IsCustomer			BIT -- 1 :return customer , 0 :retrun suplier 
-----------------------------------------   
AS
    SET NOCOUNT ON
------------------------------------------------------------------------
	CREATE TABLE  #POSSDCustomerSupplier 
	(
		GUID UNIQUEIDENTIFIER,
		Number INT,
		CustomerName NVARCHAR(250), 
		LatinName NVARCHAR(250), 
		Nationality NVARCHAR(250),
		Address NVARCHAR(250),
		Phone1 NVARCHAR(250),
		Phone2 NVARCHAR(250),
		FAX NVARCHAR(250),
		TELEX NVARCHAR(250),
		Notes NVARCHAR(250),
		EMail NVARCHAR(250),
		HomePage NVARCHAR(250),
		Prefix NVARCHAR(250),
		Suffix NVARCHAR(250),
		GPSX NVARCHAR(250),
		GPSY NVARCHAR(250),
		GPSZ NVARCHAR(250),
		Area NVARCHAR(250),
		City NVARCHAR(250),
		Street NVARCHAR(250),
		POBox NVARCHAR(250),
		ZipCode NVARCHAR(250),
		Mobile NVARCHAR(250),
		Pager NVARCHAR(250),
		Country NVARCHAR(250),
		Hoppies NVARCHAR(250),
		Gender NVARCHAR(250),
		[Certificate] NVARCHAR(250),
		DateOfBirth DATETIME,
		Job NVARCHAR(250),
		JobCategory NVARCHAR(250),
		AccountGUID UNIQUEIDENTIFIER,
		NSEMail1 NVARCHAR(250), 
		NSEMail2 NVARCHAR(250), 
		NSMobile1 NVARCHAR(250), 
		NSMobile2 NVARCHAR(250),
		Head NVARCHAR(250),
		GCCLocationGUID UNIQUEIDENTIFIER,
		TaxCode NVARCHAR(250),
		TaxNumber INT,
		DefaultAddressGUID UNIQUEIDENTIFIER
	)
	IF @IsCustomer = 1
		INSERT INTO #POSSDCustomerSupplier EXEC prcPOSSD_Station_GetCustomers @StationGuid;
	IF @IsCustomer = 0
	BEGIN
		ALTER TABLE #POSSDCustomerSupplier
		DROP COLUMN Head, GCCLocationGUID, TaxCode, TaxNumber;

		INSERT INTO #POSSDCustomerSupplier EXEC prcPOSSD_Station_GetSuppliers @StationGuid;
	END
	SELECT 
		custAd.Number,
		custAd.GUID as Guid,
		custAd.Name,
		custAd.LatinName,
		custAd.CustomerGUID,
		custAd.AreaGUID,
		custAd.Street,
		custAd.BulidingNumber,
		custAd.FloorNumber,
		custAd.MoreDetails,
		custAd.POBox,
		custAd.ZipCode,
		custAd.GPSX,
		custAd.GPSY,
		custAd.GPSZ
	FROM 
		CustAddress000 custAd
	INNER JOIN #POSSDCustomerSupplier POSCust ON POSCust.GUID = custAd.CustomerGUID 
	INNER JOIN POSSDStationAddressArea000 AddressArea ON AddressArea.AreaGUID = custAd.AreaGUID AND AddressArea.StationGUID = @StationGuid

#################################################################
#END
