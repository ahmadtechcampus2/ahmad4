#########################################################
CREATE VIEW vtUs
AS
	SELECT * FROM [us000]

#########################################################
CREATE VIEW vbUs
AS
	SELECT [us].*
	FROM [vtUs] AS [us]

#########################################################
CREATE VIEW vcUs
AS
	SELECT * FROM [vbUs]

#########################################################
CREATE VIEW vcUs0
AS
	SELECT * FROM [vcUs]
	WHERE [Type] = 0

#########################################################
CREATE VIEW vcUs1
AS
	SELECT * FROM [vcUs]
	WHERE [Type] = 1

#########################################################
CREATE VIEW vdUs
AS
	SELECT DISTINCT * FROM [vbUs]

#########################################################
CREATE VIEW vwUs
AS    
	SELECT
		[GUID] AS [usGUID],
		[Type] AS [usType],
		[Number] AS [usNumber],
		[LoginName] AS [usLoginName],
		[Password] AS [usPassword],
		[POSPassword] AS [usPOSPassword],
		[bAdmin] AS [usbAdmin],
		[MaxDiscount] AS [usMaxDiscount],
		[MinPrice] AS [usMinPrice],
		[bActive] AS [usbActive],
		[FirstName] AS [usFirstName],
		[LastName] AS [usLastName],
		[EMail] AS [usEMain],
		[WebSite] AS [usWebSite],
		[Organization] AS [usOrganization],
		[Department] AS [usDepartment],
		[Responsibility] AS [usResponsibility],
		[Address] AS [usAddress],
		[Phone1] AS [usPhone1],
		[Phone2] AS [usPhone2],
		[FixedDate] AS [usFixedDate],
		[MobilePhone] AS [usMobilePhone]
	FROM
		[vdUs]
		
#########################################################
#END