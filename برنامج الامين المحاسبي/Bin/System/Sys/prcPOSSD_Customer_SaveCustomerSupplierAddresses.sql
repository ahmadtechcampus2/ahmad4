################################################################################
CREATE PROCEDURE prcPOSSD_Customer_SaveCustomerSupplierAddresses
-- Params -------------------------------   
	@CustomerAddressesXMLDoc XML
-----------------------------------------   
AS
    SET NOCOUNT ON
------------------------------------------------------------------------

DECLARE @tempAdderss TABLE (Guid UNIQUEIDENTIFIER)

INSERT INTO @tempAdderss
SELECT 
	Addresses.CustomerAddress.query('Guid').value('.', 'UNIQUEIDENTIFIER')
FROM  
	@CustomerAddressesXMLDoc.nodes('ArrayOfCustomerAddressModel/CustomerAddressModel') AS Addresses(CustomerAddress)

DELETE 
	CA
FROM 
	CustAddress000 CA
	INNER JOIN @tempAdderss TempCA ON CA.GUID = TempCA.Guid


INSERT INTO CustAddress000
SELECT
    Addresses.CustomerAddress.query('Number').value('.', 'INT'),
    Addresses.CustomerAddress.query('Guid').value('.', 'UNIQUEIDENTIFIER'),
    Addresses.CustomerAddress.query('Name').value('.', 'NVARCHAR(250)'),
    Addresses.CustomerAddress.query('LatinName').value('.', 'NVARCHAR(250)'),
    Addresses.CustomerAddress.query('CustomerGUID').value('.', 'UNIQUEIDENTIFIER'),
    Addresses.CustomerAddress.query('AreaGUID').value('.', 'UNIQUEIDENTIFIER'),
    Addresses.CustomerAddress.query('Street').value('.', 'NVARCHAR(100)'),
    Addresses.CustomerAddress.query('BulidingNumber').value('.', 'NVARCHAR(100)'),
    Addresses.CustomerAddress.query('FloorNumber').value('.', 'NVARCHAR(100)'),
	Addresses.CustomerAddress.query('MoreDetails').value('.', 'NVARCHAR(1000)'),
	Addresses.CustomerAddress.query('POBox').value('.', 'NVARCHAR(100)'),
	Addresses.CustomerAddress.query('ZipCode').value('.', 'NVARCHAR(250)'),
	Addresses.CustomerAddress.query('GPSX').value('.', 'FLOAT'),
	Addresses.CustomerAddress.query('GPSY').value('.', 'FLOAT'),
	Addresses.CustomerAddress.query('GPSZ').value('.', 'FLOAT')

FROM  @CustomerAddressesXMLDoc.nodes('ArrayOfCustomerAddressModel/CustomerAddressModel') AS Addresses(CustomerAddress)

#################################################################
#END