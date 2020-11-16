#########################################################
CREATE TRIGGER trg_HospFile_Insert ON HosPFile000 FOR INSERT
NOT FOR REPLICATION
As 
SET NOCOUNT ON 
DECLARE 
	@StayAcc UNIQUEIDENTIFIER, 
	@SiteGUID UNIQUEIDENTIFIER
IF (EXISTS (SELECT 1 FROM hosStay000 st INNER JOIN [INSERTED]  ON   st.FileGUID =  INSERTED.GUID) )
	RETURN
select @StayAcc = cast(Value As UNIQUEIDENTIFIER) from op000 where Name = 'HosCfg_File_StayAcc'		
declare @CurrencyGuid UNIQUEIDENTIFIER
declare @CurrencyVal float
select @CurrencyGuid = Value from op000 where name = 'AmnCfg_DefaultCurrency'     
SELECT @CurrencyVal = CurrencyVal from my000 where Guid = @CurrencyGuid

DECLARE @stayGuid UNIQUEIDENTIFIER
set @stayGuid = newID()

INSERT INTO hosStay000 
(	GUID, 
	FileGUID, 
	StartDate, 
	EndDate, 
	Cost, 
	OtherCost, 
	Discount, 
	Notes, 
	Security, 
	SiteGuid, 
	AccGuid,
	CurrencyGuid,
	CurrencyVal	
)
SELECT 
	@stayGuid,
	[INSERTED].GUID,
	[INSERTED].DateIn,
	--'1900-01-01 00:00:00.000', -- insert date 1900
	'2100', -- INSERT UDEFINED DATE
	0,
	0,
	0,
	'',
	1,
	[INSERTED].SiteGuid,
	@StayAcc,
	@CurrencyGuid,
	@CurrencyVal
FROM [INSERTED]

--Update HosSite000  Set State = 2 WHERE Guid = @SiteGUID
DECLARE @Guid UNIQUEIDENTIFIER
select @guid =  guid from INSERTED
UPDATE HOSPFILE000 SET FirstStayGuid = @stayGuid where guid = @guid
##############################################
#END
