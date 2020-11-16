##############################################
CREATE PROC prcGetEntryNumByParentGuid
	@ParentGuid		UNIQUEIDENTIFIER
AS
	SET NOCOUNT ON
	
	DECLARE @Number FLOAT
	
	SELECT @Number = ISNULL(Number, 0) From ce000 WHERE Guid = ( SELECT EntryGuid FROM er000 WHERE PArentGuid = @ParentGuid )

	IF @Number IS NULL
		SET @Number = 0
	SELECT @Number AS Number
############################################
#END 