################################################################################
CREATE PROCEDURE GetPosRelatedCustomers
	@posGuid UNIQUEIDENTIFIER
AS
BEGIN
	DECLARE @debitAccountGuid uniqueidentifier
	SELECT @debitAccountGuid=DebitAccGUID FROM POSCard000 WHERE Guid = @posGuid
	
	if(@debitAccountGuid = 0x00 OR @debitAccountGuid = NULL)
		return;
	SELECT DISTINCT customers.GUID, CAST(customers.Number AS INT) Number , 
	customers.CustomerName, 
	customers.LatinName, 
	customers.AccountGUID,
	customers.NSEMail1 AS EMail, 
	customers.NSMobile1 AS Phone1, 
	customers.NSMobile2 AS Phone2
	FROM dbo.fnGetAccountsList(@debitAccountGuid, 0) accountList
	INNER JOIN cu000 customers
	ON customers.AccountGUID = accountList.GUID			
END
#################################################################
#END
