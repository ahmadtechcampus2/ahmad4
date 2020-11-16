########################################################
CREATE PROCEDURE prcDistHi_delete
	@guid [UNIQUEIDENTIFIER]
AS
	DELETE [DistHi000] WHERE [guid] = @guid
########################################################
#END 
