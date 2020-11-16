########################################################
CREATE PROCEDURE prcDisTChTarget_delete
	@guid [UNIQUEIDENTIFIER]
AS
	DELETE [DisTChTarget000] WHERE [guid] = @guid
########################################################
#END 
