#########################################################################
CREATE FUNCTION fnGetLeafPeriods(@PeriodGuid  [UNIQUEIDENTIFIER]) 
	RETURNS @Result TABLE ([PeriodGuid] [UNIQUEIDENTIFIER]) 
AS BEGIN 
	INSERT INTO @Result		
	SELECT 
		[GUID] 
	FROM fnGetPeriodList(@PeriodGuid, 1)
	WHERE NSons = 0
	RETURN
END
#########################################################################
#END