###########################################################################
CREATE PROC prcCustAddress_GetAll
	@CustomerGUID [UNIQUEIDENTIFIER]
AS 
	SELECT 
		CA.*, 
		CASE CU.DefaultAddressGUID WHEN CA.GUID THEN 1 ELSE 0 END AS [IsDefault]
	FROM 
		vwCustAddress CA 
		INNER JOIN CU000 CU ON CA.CustomerGUID = CU.GUID 
	WHERE 
		CU.GUID = @CustomerGUID
	ORDER BY
		CA.Number
###########################################################################
CREATE PROC prcAddressWorkingDays_GetAll
	@AddressGUID [UNIQUEIDENTIFIER]
AS 
	SELECT *
	FROM 
		CustAddressWorkingDays000 WD
	WHERE 
		WD.AddressGUID = @AddressGUID
	ORDER BY
		WD.Number
###########################################################################
CREATE PROC prc_GetAddressInfo
	@AddressGuid			UNIQUEIDENTIFIER
AS 
	SELECT * 
	FROM 
		VwCustAddress 
	WHERE 
		Guid = @AddressGuid
###########################################################################
CREATE PROC prc_GetAddressWorkingDaysInfo
	@AddressGuid			UNIQUEIDENTIFIER
AS 
	SELECT * 
	FROM 
		CustAddressWorkingDays000 
	WHERE 
		AddressGuid = @AddressGuid AND WorkDays != 0 
	ORDER BY 
		Number
###########################################################################
#END
