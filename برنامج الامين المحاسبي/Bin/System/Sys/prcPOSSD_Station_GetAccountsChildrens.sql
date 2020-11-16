################################################################################
CREATE PROCEDURE prcPOSSD_Station_GetAccountsChildrens
@parentAccount      UNIQUEIDENTIFIER
AS
BEGIN
	SELECT  
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
			@parentAccount AS ParentGuid,
			AC.Code AS AccountCode
	FROM 
			dbo.fnGetAccountsList(@parentAccount, 0) accountList
			INNER JOIN ac000 AC ON AC.GUID = accountList.GUID
			LEFT JOIN cu000 customers	ON customers.AccountGUID = accountList.GUID
	WHERE 
			AC.NSons = 0
	GROUP BY AC.Name, AC.Code, AC.GUID, AC.LatinName , AC.NSons, customers.GUID, customers.Number, customers.CustomerName, customers.LatinName, customers.NSEMail1, customers.NSMobile1,customers.NSMobile2
	
END
#################################################################
#END 