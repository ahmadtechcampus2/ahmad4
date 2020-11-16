################################################################################
CREATE PROCEDURE prcPOSSD_Station_GetCustomers
	@posGuid UNIQUEIDENTIFIER
AS
BEGIN
	DECLARE @debitAccountGuid uniqueidentifier
	SELECT @debitAccountGuid=DebitAccGUID FROM POSSDStation000 WHERE [GUID] = @posGuid
	
	if(@debitAccountGuid = 0x00 OR @debitAccountGuid = NULL)
		return;

	DECLARE @IsGCCSystemEnabled INT = dbo.fnOption_GetInt('AmnCfg_EnableGCCTaxSystem', '0');

	SELECT DISTINCT 
	customers.GUID,
	CAST(customers.Number AS INT) Number , 
	customers.CustomerName, 
	customers.LatinName, 
	customers.Nationality,
	customers.Address,
	customers.Phone1,
	customers.Phone2,
	customers.FAX,
	customers.TELEX,
	customers.Notes,
	customers.EMail,
	customers.HomePage,
	customers.Prefix,
	customers.Suffix,
	customers.GPSX,
	customers.GPSY,
	customers.GPSZ,
	customers.Area,
	customers.City,
	customers.Street,
	customers.POBox,
	customers.ZipCode,
	customers.Mobile,
	customers.Pager,
	customers.Country,
	customers.Hoppies,
	customers.Gender,
	customers.[Certificate],
	customers.DateOfBirth,
	customers.Job,
	customers.JobCategory,
	customers.AccountGUID,
	customers.NSEMail1, 
	customers.NSEMail2, 
	customers.NSMobile1, 
	customers.NSMobile2,
	customers.Head ,
	customers.GCCLocationGUID,
	GCCCU.TaxCode,
	Case @IsGCCSystemEnabled WHEN 1 THEN GCCCU.TaxNumber ELSE customers.TaxNumber END AS TaxNumber,
	customers.DefaultAddressGUID AS DefaultAddressGUID
	FROM dbo.fnGetAccountsList(@debitAccountGuid, 0) accountList
	INNER JOIN vexCu customers	ON customers.AccountGUID = accountList.GUID
	INNER JOIN CustAddress000 custAd ON custAd.CustomerGUID = customers.GUID
	INNER JOIN POSSDStationAddressArea000 AddressArea	ON AddressArea.AreaGUID = custAd.AreaGUID and StationGUID = @posGuid
	LEFT JOIN GCCCustomerTax000  AS GCCCU  ON (GCCCU.CustGUID = customers.GUID)
END
#################################################################
#END