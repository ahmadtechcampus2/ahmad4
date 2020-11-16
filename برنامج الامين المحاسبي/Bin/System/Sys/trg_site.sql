#########################################################
CREATE  TRIGGER trg_Site000_delete
	ON hosSite000 FOR DELETE
AS 
SET NOCOUNT ON 
	DECLARE @Guid UNIQUEIDENTIFIER	
	SELECT @Guid = deleted.Guid FROM deleted


	if (dbo.fnSite_IsUsed(@Guid) <> 0)
		INSERT INTO [ErrorLog] ([level], [type], [c1], [g1]) 
		SELECT 1, 0, 'AmnE0520: Site Used ...', @Guid 
	
#########################################################
#END