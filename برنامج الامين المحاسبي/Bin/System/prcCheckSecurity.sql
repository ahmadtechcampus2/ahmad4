###############################################################################
CREATE PROCEDURE prcCheckSecurity
	@UserGUID [UNIQUEIDENTIFIER] = NULL,
	@Check_MatBalanceSec [BIT] = 0,
	@Check_AccBalanceSec [BIT] = 0,
	@result [NVARCHAR](128) = '#Result',
	@secViol [NVARCHAR](128) = '#secViol'
AS	
	SET NOCOUNT ON


	-- skip for admins:
	SET @UserGUID = ISNULL(@userGUID, [dbo].[fnGetCurrentUserGUID]())

	IF [dbo].[fnIsAdmin](@UserGUID) <> 0 RETURN
	
	-- check presence of @result and @secViol:
	IF [dbo].[fnObjectExists](@result) * [dbo].[fnObjectExists](@secViol) = 0
	BEGIN
		RAISERROR( 'AmnE0200: redundant table(s) missing: %s and/or %s', 16, 1, @result, @secViol)
		RETURN
	END

	-- initiat:
	CREATE TABLE [#fields]([Name] [NVARCHAR](128) COLLATE ARABIC_CI_AI)
	INSERT INTO [#fields]
			SELECT * FROM [fnGetTableColumns](@result)

	-- manage Excluded entries and bills (usualy needed when deeling with DBCs)
	IF EXISTS(SELECT * FROM [#fields] WHERE [name] = 'GUID')
		 EXEC('DELETE [t] FROM ' + @result + ' [t] INNER JOIN [ex] ON [t].[GUID] = [ex].[GUID]')
	
	IF EXISTS(SELECT * FROM [#fields] WHERE [name] = 'ceGUID')
		EXEC ('DELETE [t] FROM ' + @result + ' [t] INNER JOIN [ex] ON [t].[ceGUID] = [ex].[GUID]')

	IF EXISTS(SELECT * FROM [#fields] WHERE [name] = 'buGUID')
		EXEC ('DELETE [t] FROM ' + @result + '[t] INNER JOIN [ex] ON [t].[buGUID] = [ex].[GUID]')

	-- check 3.2.1: Security vs UserSecurity:
	EXEC [prcCheckSecurity_userSec] @result, @secViol, 1

	-- check 3.2.2: UserReadPriceSecurity vs prices columns:
	EXEC [prcCheckSecurity_readPriceSec] @result, @secViol, 2

	-- check 3.2.3: Account Security
	EXEC [prcCheckSecurity_browesSec] @userGUID, @result, @secViol, 'acSecurity, accSecurity, accountSecurity', 'acGUID, accGUID, accountGUID', 'fnGetUserAccountSec_Browse', 'fnAccount_HSecList', 3

	-- check 3.2.4: Customer Security
	EXEC [prcCheckSecurity_browesSec] @userGUID, @result, @secViol, 'cuSecurity, CustSecurity, CustomerSecurity', 'cuGuid, CustGUID, CustomerGUID', 'fnGetUserCustomerSec_Browse', DEFAULT, 4

	-- check 3.2.5: CostSecurity
	EXEC [prcCheckSecurity_browesSec] @userGUID, @result, @secViol, 'coSecurity, CostSecurity', 'coGuid, CostGUID', 'fnGetUserCostSec_Browse', 'fnCost_HSecList', 5

	-- check 3.2.6: StoreSecurity
	EXEC [prcCheckSecurity_browesSec] @userGUID, @result, @secViol, 'stSecurity, StoreSecurity', 'stGUID, storeGUID', 'fnGetUserStoreSec_Browse', 'fnStore_HSecList', 6

	-- check 3.2.7: MatSecurity
	EXEC [prcCheckSecurity_browesSec] @userGUID, @result, @secViol, 'MatSecurity, MaterialSecurity, mtSecurity', 'mtGuid, matGUID, materialGUID', 'fnGetUserMaterialSec_Browse', DEFAULT, 7

	-- check 3.2.8: GroupSecurity
	EXEC [prcCheckSecurity_browesSec] @userGUID, @result, @secViol, 'grSecurity, GroupSecurity', 'grGUID, groupGUID', 'fnGetUserGroupSec_Browse', 'fnGroup_HSecList', 8

	-- check 3.2.9: EntrySecurity:
	EXEC [prcCheckSecurity_browesSec] @userGUID, @result, @secViol, 'ceSecurity, enSecurity, EntrySecurity', DEFAULT, 'fnGetUserEntrySec_Browse', DEFAULT, 9, 1

/*
the following types are reserved for prcDatabase_collection violations:
	- check type 100: needs updating.
	- check type 101: user is not defined.
	- check type 102: error in password.
*/

	DELETE FROM [#SecViol] WHERE [Cnt] = 0

	DROP TABLE [#fields]

###############################################################################
#END