########################################################
CREATE PROCEDURE prcCurrency_delete
	@guid [UNIQUEIDENTIFIER]
AS
	delete [my000] where [guid] = @guid
 
########################################################
#END    