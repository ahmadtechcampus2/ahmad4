
#########################################################
CREATE VIEW vtCu
AS
	SELECT * FROM [cu000]

#########################################################
CREATE VIEW vbCu
AS
	SELECT [c].*
	FROM [vtCu] AS [c] INNER JOIN [vbAc] AS [a] ON [c].[AccountGUID] = [a].[GUID]

#########################################################
CREATE VIEW vcCu
AS
	SELECT * FROM [vbCu]
#########################################################
CREATE VIEW vdAddressCity
AS
	SELECT
		aci.*,
		ISNULL(aco.Name, '') AS CountryName,
		ISNULL(aco.LatinName, '') AS CountryLatinName
	FROM 
		AddressCity000 aci 
		LEFT JOIN AddressCountry000 aco ON aco.GUID = aci.ParentGUID 
#########################################################
CREATE VIEW vdAddressArea
AS
	SELECT
		aar.*,
		ISNULL(aci.GUID, 0x0) AS CityGUID,
		ISNULL(aci.Name, '') AS CityName,
		ISNULL(aci.LatinName, '') AS CityLatinName,
		ISNULL(aco.GUID, 0x0) AS CountryGUID,
		ISNULL(aco.Name, '') AS CountryName,
		ISNULL(aco.LatinName, '') AS CountryLatinName
	FROM 
		AddressArea000 aar 
		LEFT JOIN AddressCity000 aci ON aci.GUID = aar.ParentGUID 
		LEFT JOIN AddressCountry000 aco ON aco.GUID = aci.ParentGUID 
#########################################################
CREATE VIEW vwCustAddress
AS
	SELECT 
		CuAd.*,
		ISNULL(adci.GUID, 0x0) AS CityGUID,
		ISNULL(adco.GUID, 0x0) AS CountryGUID,
		ISNULL(adco.Name, '') AS [Country],
		ISNULL(adci.Name, '') AS [City],
		ISNULL(ada.Name, '') AS [Area],
		ISNULL(adco.latinName, '') AS [CountryLatinName],
		ISNULL(adci.latinName, '') AS [CityLatinName],
		ISNULL(ada.LatinName, '') AS [AreaLatinName]
	FROM 
		CustAddress000 CuAd 
		LEFT JOIN AddressArea000 ada ON ada.GUID = CuAd.AreaGUID
		LEFT JOIN AddressCity000 adci ON adci.GUID = ada.ParentGUID
		LEFT JOIN AddressCountry000 adco ON adco.GUID = adci.ParentGUID
	
#########################################################
CREATE VIEW vexCu
AS
	SELECT 
		CU.*,
		ISNULL(CuAd.Name, '') AS [AddressName],
		ISNULL(CuAd.LatinName, '') AS [AddressLatinName],
		ISNULL(CuAd.MoreDetails, '') AS [Address],
		ISNULL(CuAd.MoreDetails, '') AS [MoreDetails],
		ISNULL(CuAd.[Country], '') AS [Country],
		ISNULL(CuAd.[City], '') AS [City],
		ISNULL(CuAd.[Area], '') AS [Area],
		ISNULL(CuAd.Street, '') AS [Street],
		ISNULL(CuAd.[CountryGUID], 0x0) AS [CountryGUID],
		ISNULL(CuAd.[CityGUID], 0x0) AS [CityGUID],
		ISNULL(CuAd.[AreaGUID], 0x0) AS [AreaGUID],
		ISNULL(CuAd.BulidingNumber, '') AS [BulidingNumber],
		ISNULL(CuAd.FloorNumber, '') AS [FloorNumber],
		ISNULL(CuAd.POBox, '') AS [POBox],
		ISNULL(CuAd.ZipCode, '') AS [ZipCode],
		ISNULL(CuAd.GPSX, 0) AS [GPSX],
		ISNULL(CuAd.GPSY, 0) AS [GPSY],
		ISNULL(CuAd.GPSZ, 0) AS [GPSZ]
	FROM 
		vbCu CU
		LEFT JOIN vwCustAddress CuAd ON CU.DefaultAddressGUID = CuAd.GUID 
#########################################################
CREATE VIEW vdCu
AS
	SELECT cu.*,ac.acDebit,ac.acCredit,ac.acType FROM [vexCu] cu
	 INNER JOIN [vwAc] AS [ac]
		ON [ac].[acGUID] = [cu].[AccountGUID]
#########################################################
CREATE VIEW vdCu2
AS
	SELECT cu.*, ISNULL(custTax.TaxNumber,'') AS [GCCTaxNumber] FROM [vdCu] cu
	LEFT  JOIN GCCCustomerTax000 custTax 
	ON custTax.CustGUID = cu.GUID AND TaxType = 1 
	WHERE [bHide] = 0
#########################################################
CREATE VIEW vwCu
AS
	SELECT
		CU.[GUID] AS [cuGUID],
		[Number] AS [cuNumber],
		[CustomerName] AS [cuCustomerName],
		[Nationality] AS [cuNationality],
		[Address] AS [cuAddress],
		[Phone1] AS [cuPhone1],
		[Phone2] AS [cuPhone2],
		[FAX] AS [cuFAX],
		[TELEX] AS [cuTELEX],
		[Notes] AS [cuNotes],
		[UseFlag] AS [cuUseFlag],
		[PictureGUID] AS [cuPicture],
		[AccountGUID] AS [cuAccount],
		[CheckDate] AS [cuCheckDate],
		[Security] AS [cuSecurity],
		[Type] AS [cuType],
		[DiscRatio] AS [cuDiscRatio],
		[DefPrice] AS [cuDefPrice],
		[State] AS [cuState],
		[Street] AS [cuStreet],
		[Area] AS [cuArea],
		[LatinName] AS [cuLatinName], 
		[EMail] AS [cuEMail], 
		[HomePage] AS [cuHomePage], 
		[Prefix] AS [cuPrefix], 
		[Suffix] AS [cuSuffix], 
		[GPSX] AS [cuGPSX], 
		[GPSY] AS [cuGPSY], 
		[GPSZ] AS [cuGPSZ], 
		[City] AS [cuCity], 
		[POBox] AS [cuPOBox], 
		[ZipCode] AS [cuZipCode], 
		[Mobile] AS [cuMobile], 
		[Pager] AS [cuPager],
		[Country] AS [cuCountry],
		[Hoppies] AS [cuHobbies],
		[Gender] AS [cuGender],
		[Certificate] AS [cuCertificate],
		[DateOfBirth] AS [cuDateOfBirth],
		[Job] AS [cuJob],
		[JobCategory] AS [cuJobCategory],
		[UserFld1] AS [cuUserFld1],
		[UserFld2] AS [cuUserFld2],
		[UserFld3] AS [cuUserFld3],
		[UserFld4] AS [cuUserFld4],
		[BarCode] AS [cuBarCode],
		[GLNFlag] AS [cuGLNFlag],
		[bHide] AS [cuHide],
		[ContraDiscAccGUID] AS [CuContraDiscAccGUID],
		[ConditionalContraDiscAccGUID] AS [CuConditionalContraDiscAccGUID],
		[NSEmail1]  AS [NSEmail1],
		[NSEmail2]  AS [NSEmail2],
		[NSMobile1] AS [NSMobile1],
		[NSMobile2] AS [NSMobile2],
		[NSNotSendSMS] AS [NSNotSendSMS] ,
		[NSNotSendEmail] AS [NSNotSendEmail],
		ReverseCharges,
		GCCLocationGUID,
		GCCCountry,
		ISNULL(VAT.TaxCode, 0) AS VATTaxCode,
		ISNULL(VAT.TaxNumber, N'') AS VATTaxNumber,
		ISNULL(EX.TaxCode, 0) AS ExciseTaxCode,
		ISNULL(EX.TaxNumber, N'') AS ExciseTaxNumber,
		[MaxDebit] AS [cuMaxDebit],
		[Warn] AS [cuWarn],
		[ConsiderChecksInBudget] AS [cuConsiderChecksInBudget],
		[AddressName] AS cuAddressName,
		[AddressLatinName] AS cuAddressLatinName,
		[BulidingNumber] AS cuAddressBulidingNumber,
		[FloorNumber] AS cuAddressFloorNumber,
		[MoreDetails] AS cuAddressMoreDetails,		
		[Head] AS [cuHead],
		[CostGUID] AS [cuCostGUID],
		cu.ExemptFromTax AS cuExemptFromTax,
		cu.DefaultAddressGUID AS cuDefaultAddressGUID
	FROM
		vexCu AS cu
		LEFT JOIN GCCCustomerTax000 AS VAT ON cu.GUID = VAT.CustGUID AND VAT.TaxType = 1
		LEFT JOIN GCCCustomerTax000 AS EX ON cu.GUID = EX.CustGUID AND EX.TaxType = 2

#########################################################
#END