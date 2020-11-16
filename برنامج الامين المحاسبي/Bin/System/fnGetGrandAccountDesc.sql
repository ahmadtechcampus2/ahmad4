#########################################################
CREATE FUNCTION fnGetGrandAccountName( @accGuid UNIQUEIDENTIFIER)
	RETURNS NVARCHAR(250)
AS 
BEGIN 
	IF ISNULL(@accGuid, 0x0) = 0x0
		RETURN ''

	DECLARE @ParentGUID UNIQUEIDENTIFIER 
	SET @ParentGUID = (SELECT [ParentGUID] FROM [AC000] WHERE [GUID] = @accGuid)
	IF ISNULL( @ParentGUID, 0x0) = 0x0 
		RETURN ''

	SET @ParentGUID = (SELECT [ParentGUID] FROM [AC000] WHERE [GUID] = @ParentGUID)
	IF ISNULL( @ParentGUID, 0x0) = 0x0 
		RETURN ''

	RETURN ( SELECT TOP 1 ISNULL( [Name], '') FROM [AC000] WHERE [GUID] = @ParentGUID)
END 	
		
#########################################################
#END
