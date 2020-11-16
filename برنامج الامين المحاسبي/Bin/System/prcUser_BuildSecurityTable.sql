#########################################################
CREATE PROCEDURE prcUser_BuildSecurityTable
	@userGUID [UNIQUEIDENTIFIER] = NULL 
AS 
/* 
This procedure: 
	- builds user security profile from us000 and ui000. a use security profile is the a combination of usx and uix tables 
	- inserts the summary of us and ui data in usx and uix 
	- considers option AmnCfg_PessimisticSecurity in table op000 when building the security profile. 
	- also calls prcUser_BuildBillAccounts. 
*/ 
	SET NOCOUNT ON 
	IF isnull( @userGUID, 0x0) = 0x0
		SET @userGUID = [dbo].[fnGetCurrentuserGUID]() 
	IF isnull( @userGUID, 0x0) = 0x0
		RETURN 
	declare @dirty int 
	SELECT @dirty = [Dirty] FROM [us000] WHERE [GUID] = @userGUID
	IF  @dirty <> 0
	BEGIN
		EXECUTE [prcUser_RebuildSecurityTable] @userGUID
	END
	-- build user bill accounts into ma000 type 5 
	EXECUTE [prcUser_BuildBillAccounts] @userGUID 

#########################################################
#END