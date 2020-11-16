############################################################################
CREATE PROCEDURE prcOrderCopyOrderInfo @OriginalOrderGuid UNIQUEIDENTIFIER
	, @NewOrderGuid UNIQUEIDENTIFIER
	, @NewOrderTypeGuid  UNIQUEIDENTIFIER
AS
/*
AUTHER: Abdulkareem Attiya
This Procedure we can used it for copy information page from type to another.
Last Edit in logic:
- Store all dates of today + DefaultDeliveryDays of order type (bt000. 
- Clear all the rest of information.   
*/
SET NOCOUNT ON;
 
DECLARE @Date DATE
SET @Date = (SELECT DATEADD(DAY, DefaultDeliveryDays, GETDATE()) AS [date] FROM bt000 WHERE [GUID] = @NewOrderTypeGuid)

INSERT INTO ORADDINFO000(GUID, ParentGuid, SADATE, SDDATE, SPDATE, SSDATE, AADATE, ADDATE, APDATE, ASDATE, PTDate, ExpectedDate, Add1, Add2)
	SELECT
		NEWID()
		, @NewOrderGuid
		, @Date --SADATE
		, @Date --SDDATE
		, @Date --SPDATE
		, @Date --SSDATE
		, @Date --AADATE
		, @Date --ADDATE
		, @Date --APDATE
		, @Date --ASDATE	
		, @Date --PTDate
		, @Date --ExpectedDate
		, '0'
		, '0'
	FROM dbo.ORADDINFO000
	WHERE ParentGuid = @OriginalOrderGuid

/*
prcOrderCopyDividedOrderInfo
'b116fe20-6830-4122-8e59-4392a08f7512'
,
'10bb2acf-d6e8-493c-a6e3-861804d33d2b'


select * FROM dbo.ORADDINFO000

delete from ORADDINFO000 where parentguid = '85FF16FF-CADB-4E3A-BF96-EACD395F9402'
*/

############################################################################
#END

