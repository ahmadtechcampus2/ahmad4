################################################################################
CREATE FUNCTION allotmentRecycle()
RETURNS @Result TABLE([GUID] UNIQUEIDENTIFIER)
AS
BEGIN
	DECLARE @openDate DATETIME, @endDate DATETIME
	
	SELECT @endDate = [dbo].[fnDate_Amn2Sql]([VALUE]) FROM [op000] WHERE [NAME] = 'AmnCfg_EPDate'
	
	INSERT INTO @Result
	SELECT
		al.[GUID]
	FROM
		Allotment000 al
		INNER JOIN Allocations000 aloc ON al.GUID = aloc.AllotmentGuid
	WHERE
		aloc.ToMonth > @endDate
		
	RETURN
END
#########################################################################
CREATE FUNCTION allocationsRecycle()
RETURNS @Result TABLE([GUID] UNIQUEIDENTIFIER)
AS
BEGIN
	DECLARE @openDate DATETIME, @endDate DATETIME
	
	SELECT @endDate = [dbo].[fnDate_Amn2Sql]([VALUE]) FROM [op000] WHERE [NAME] = 'AmnCfg_EPDate'
	
	INSERT INTO @Result
	SELECT
		aloc.[Guid]
	FROM
		Allocations000 aloc
		INNER JOIN Allotment000 al ON al.GUID = aloc.AllotmentGuid
	WHERE
		aloc.ToMonth > @endDate
		
	RETURN
	
END
################################################################################
#END