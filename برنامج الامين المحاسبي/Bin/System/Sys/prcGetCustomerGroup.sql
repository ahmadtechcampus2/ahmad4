################################################################################
CREATE PROCEDURE NSGetCustomerGroupCustomer
	@groupGuid UNIQUEIDENTIFIER,
	@accountCustomers UNIQUEIDENTIFIER,
	@CondGuid UNIQUEIDENTIFIER
AS
BEGIN
	SET NOCOUNT ON

	CREATE TABLE [#SecViol]([Type] [INT], [Cnt] [INT])

	CREATE TABLE #customer ([Guid] UNIQUEIDENTIFIER, cuSecurity INT)
	INSERT INTO #customer EXEC prcGetCustsList 0x0, @accountCustomers, @CondGuid
	EXEC [prcCheckSecurity] @result = '#customer'

	SELECT CU.cuGUID, CU.cuCustomerName, CU.cuLatinName , CU.NSEmail1, CU.NSEmail2, CU.NSMobile1, NSMobile2,CU.NSNotSendSMS ,CU.NSNotSendEMAIL , CU.cuAccount As acGuid  from vwCu CU INNER JOIN #customer FCU ON FCU.[Guid] = CU.cuGUID WHERE CU.cuGUID NOT IN (SELECT customerGuid FROM NSCustomerGroupCustomer000 WHERE CustomerGroupGuid = @groupGuid)

	SELECT CU.CUGUID, CU.cuCustomerName, CU.cuLatinName, CU.NSEmail1, CU.NSEmail2, CU.NSMobile1, NSMobile2,CU.NSNotSendSMS ,CU.NSNotSendEMAIL , CU.cuAccount As acGuid 
	FROM NSCustomerGroupCustomer000 NC 
		INNER JOIN vwCu AS CU ON CU.cuGUID = NC.CustomerGuid AND nc.CustomerGroupGuid = @groupGuid
		INNER JOIN #customer FC ON cu.cuGUID = fc.[GUID]

	SELECT * FROM [#SecViol]
END
#################################################################
CREATE VIEW vwCustomerGroup
AS
	SELECT * FROM NSCustomerGroup000 WHERE Name <> ''
#################################################################
#END