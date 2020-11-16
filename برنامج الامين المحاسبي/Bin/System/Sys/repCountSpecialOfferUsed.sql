####################################################################
CREATE PROC repCountSpecialOfferUsed
	@smGuid [UNIQUEIDENTIFIER]
AS 
	SET NOCOUNT ON
	SELECT COUNT(*) AS [biCount] FROM [bi000] where [soGuid] = @smGuid
####################################################################
#END