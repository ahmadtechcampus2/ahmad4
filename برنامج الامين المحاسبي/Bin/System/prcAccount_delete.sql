########################################################
CREATE PROCEDURE prcAccount_delete
	@guid [UNIQUEIDENTIFIER]
AS
	delete [cu000] where [AccountGuid] = @guid
	delete [ac000] where [guid] = @guid
########################################################
#END 
