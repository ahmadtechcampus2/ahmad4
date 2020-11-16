################################################
CREATE PROCEDURE prcEmptyingSiteStatus
	@ReservationGuid 	UNIQUEIDENTIFIER
AS 
SET NOCOUNT ON 
	DECLARE @StatusGuid_Close		UNIQUEIDENTIFIER
	SELECT @StatusGuid_Close = [Value] FROM [op000] WHERE Name = 'HosCfg_Site_Status_OnClose'
	UPDATE hosSite000 SET Status = @StatusGuid_Close 
		FROM hosSite000 AS S INNER JOIN hosReservationDetails000 AS D ON S.Guid = D.SiteGuid
		-- INNER JOIN hosReservation000 AS v ON v.Guid = D.ParentGuid
		WHERE D.ParentGuid = @ReservationGuid

/*
select * from hosReservation000 
select * from hosReservationDetails000
select * from hosSite000

EXEC prcEmptyingSiteStatus 0x0
*/
################################################
CREATE PROC prcEmployeeCardIsUsed
	@Guid uniqueidentifier 
AS 
SET NOCOUNT ON 
if not exists (select * from  hospfile000 where doctorGuid = @guid) 
	if not exists (select * from  hosgeneraltest000 where WorkerGuid = @guid) 
		if not exists (select * from  vwHosSurgery where DocGuid = @guid) 
			select 0 AS USED -- not used  
		else 
			select 11 AS USED-- surgery  
	else 
			select 12 AS USED -- GeneralTest 
else 
	select 13	AS USED-- File  
################################################
#END

