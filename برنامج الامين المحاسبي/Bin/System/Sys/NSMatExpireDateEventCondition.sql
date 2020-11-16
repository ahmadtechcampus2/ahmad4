################################################################################
CREATE FUNCTION fnNSCheckMatExpireDateEventCondtions(
	@eventConditonGuid UNIQUEIDENTIFIER,
	@fromDate DATETIME)
RETURNS @object TABLE 
(
	[GUID]	UNIQUEIDENTIFIER
)
BEGIN 
	DECLARE @beforeDays INT
	SELECT @beforeDays =  DC.BeforeDays FROM NSScheduleEventCondition000 DC WHERE DC.EventConditionGuid = @eventConditonGuid

	INSERT INTO @object SELECT MatPtr FROM fnGetMatsExpireDateInfo (@beforeDays , @fromDate) GROUP BY MatPtr
	RETURN
END 
################################################################################
#END
		