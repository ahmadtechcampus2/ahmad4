################################################################################
CREATE PROCEDURE prcPOSSD_Station_GetCreditOrDebitAccountsChildren
@parentAccount      UNIQUEIDENTIFIER,
@stationGuid		UNIQUEIDENTIFIER
AS
BEGIN
	SELECT DISTINCT 
			AC.Code  As AccountCode,
			AC.Name  AS AccountName,
			AC.LatinName  AS  AccountLatinName,
			AC.GUID AS AccountGuid,
			AC.NSons AS NSons,
			customers.GUID AS CustomerGuid, 
			customers.Number AS CustomerNumber,  
			customers.CustomerName AS CustomerName, 
			customers.LatinName AS CustomerLatinName, 
			
			customers.NSEMail1 AS EMail, 
			customers.NSMobile1 AS Phone1, 
			customers.NSMobile2 AS Phone2,
			@parentAccount AS ParentGuid
	FROM 
			dbo.fnGetAccountsList(@parentAccount, 0) accountList
			INNER JOIN ac000 AC ON AC.GUID = accountList.GUID
			LEFT JOIN cu000 customers	ON customers.AccountGUID = accountList.GUID
			INNER JOIN CustAddress000 custAd ON custAd.CustomerGUID = customers.GUID
			INNER JOIN POSSDStationAddressArea000 AddressArea	ON AddressArea.AreaGUID = custAd.AreaGUID AND StationGUID = @stationGuid
	WHERE 
			AC.NSons = 0
END
#################################################################
#END 