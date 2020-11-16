CREATE FUNCTION fnGetFGroupParent(@StartGUID [UNIQUEIDENTIFIER]) 
	RETURNS [UNIQUEIDENTIFIER] 
AS BEGIN 
/* 
This function: 
	- returns a Final Parent of a given group GUID
*/ 
	DECLARE @ParentGUID [UNIQUEIDENTIFIER] 
	DECLARE @GroupGUID [UNIQUEIDENTIFIER] 
	SET @GroupGUID = @StartGUID
	SELECT @ParentGUID = [ParentGUID] FROM [gr000] WHERE [GUID] = @StartGUID
	WHILE @@ROWCOUNT <> 0 AND @ParentGUID <> @StartGUID
	BEGIN 
		IF( @ParentGUID != 0x0)
			SET @GroupGUID = @ParentGUID
		if( @ParentGUID = 0x0)
			BREAK
		SELECT @ParentGUID = [ParentGUID] FROM [gr000] WHERE [GUID] = @ParentGUID 
	END 
--	PRINT @GroupGUID

	RETURN @GroupGUID
END 
