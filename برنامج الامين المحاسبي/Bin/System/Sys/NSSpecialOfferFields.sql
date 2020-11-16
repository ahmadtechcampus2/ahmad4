################################################################################
CREATE FUNCTION NSGetCustomerInfoFromCustObject(@ObjectGuid UNIQUEIDENTIFIER)
RETURNS @receiver TABLE 
(
		[GUID]			UNIQUEIDENTIFIER,
		receiverName	CHAR(15),
		mailAddress1	NVARCHAR(100),
		smsAddress1		VARCHAR(20),
		mailAddress2	NVARCHAR(100),
		smsAddress2		VARCHAR(20),
		NSNotSendSMS			BIT,
		NSNotSendEmail			BIT
)
AS 
BEGIN
	INSERT INTO @receiver select 0x0, 'bill customer', cu.nsemail1, cu.nsmobile1, cu.nsemail2, cu.nsmobile2, cu.NSNotSendSMS, cu.NSNotSendEmail FROM cu000 CU
	where cu.GUID = @ObjectGuid
	RETURN
END
################################################################################
CREATE FUNCTION NSCustomerInfoFromCustObject(@ObjectGuid UNIQUEIDENTIFIER, @messageGuid UNIQUEIDENTIFIER)
RETURNS @customerInfo TABLE 
(
		CustomerName		NVARCHAR(255),
		CustomerLName       NVARCHAR(255),
		CustomerSuffix		NVARCHAR(255),
		CustomerPrefix		NVARCHAR(255)
)
AS 
BEGIN
	INSERT INTO @customerInfo
	SELECT CustomerName, LatinName, Suffix, Prefix from cu000 where [GUID] = @ObjectGuid
	RETURN
END
################################################################################
#END