########################################
## prcDistCheckAmeenUser
CREATE PROC prcDistCheckAmeenUser
	@UserName	nvarchar(250)
AS
	SET NOCOUNT ON
	DECLARE @T TABLE (GUID uniqueidentifier)
	IF EXISTS(SELECT * FROM US000 WHERE LoginName = @UserName)
		INSERT INTO @T SELECT GUID FROM US000 WHERE LoginName = @UserName
	ELSE
		INSERT INTO @T SELECT 0x0
	SELECT * FROM @T
#############################
#END
