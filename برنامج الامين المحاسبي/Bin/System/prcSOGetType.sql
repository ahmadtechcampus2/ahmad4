########################################################
CREATE PROCEDURE prcSOGetType
	@smGuid [UNIQUEIDENTIFIER]
AS
	SELECT TOP 1 type FROM sm000 WHERE guid = @smGuid

########################################################
#END    
