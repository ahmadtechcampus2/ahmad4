################################################################################
CREATE FUNCTION NSGetUsersInfo(@users VARCHAR(MAX))
RETURNS @receiver TABLE 
(
		[GUID]			UNIQUEIDENTIFIER,
		receiverName	CHAR(15),
		mailAddress		NVARCHAR(100),
		smsAddress		VARCHAR(20)
)
AS 
BEGIN
	DECLARE @xmlUsers XML = CAST(@users AS XML)

	INSERT INTO @receiver SELECT us.usGUID, 'bill customer', us.usEMain, us.usMobilePhone
	FROM vwUs us INNER JOIN @xmlUsers.nodes('/Users/User') T(c)
    ON us.usGUID = T.c.value('./@Guid', 'UNIQUEIDENTIFIER')
	WHERE usType = 0
	RETURN
END
################################################################################
CREATE FUNCTION fnNSChecksEmptyCondtions(
	@eventConditonGuid UNIQUEIDENTIFIER,
	@objectGuid UNIQUEIDENTIFIER)
RETURNS BIT AS
BEGIN 
	RETURN 1
END
################################################################################
#END

