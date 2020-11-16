######################################################
CREATE PROCEDURE prcCheckAssetSecurity
	@UserGUID [UNIQUEIDENTIFIER] = NULL,
	@result [NVARCHAR](128) = '#Result',
	@secViol [NVARCHAR](128) = '#secViol',
	@type [INT] = 0
AS	
BEGIN
	SET NOCOUNT ON;
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

	EXEC [prcCheckSecurity_userSec] @result, @secViol, 1

	-- AssetDetail Security
	EXEC [prcCheckSecurity_browesSec] @userGUID, @result, @secViol, 'adSecurity', 'adGUID, adGuid', 'fnGetUserAssetDetailsSec_Browse', DEFAULT, 10

	-- Asset Add Security
	EXEC [prcCheckSecurity_browesSec] @userGUID, @result, @secViol, 'addSecurity', 'axGUID, axGuid, buGuid', 'fnGetUserAssetAddSec_Browse', DEFAULT, 11

	-- Asset Deduct Security
	EXEC [prcCheckSecurity_browesSec] @userGUID, @result, @secViol, 'dedSecurity', 'axGUID, axGuid, buGuid', 'fnGetUserAssetDedSec_Browse', DEFAULT, 11

	-- Asset Maintain Security
	EXEC [prcCheckSecurity_browesSec] @userGUID, @result, @secViol, 'mainSecurity', 'axGUID, axGuid, buGuid', 'fnGetUserAssetMainSec_Browse', DEFAULT, 11

	-- Asset Deprecation Security
	EXEC [prcCheckSecurity_browesSec] @userGUID, @result, @secViol, 'dpSecurity', 'dpGUID, dpGuid, buGuid', 'fnGetUserAssetDepSec_Browse', DEFAULT, 13

	-- Asset Exchange Security
	EXEC [prcCheckSecurity_browesSec] @userGUID, @result, @secViol, 'apSecurity', 'apGUID, apGuid, buGuid', 'fnGetUserAssetExchSec_Browse', DEFAULT, 14

	-- Asset Utilize Contract Security
	EXEC [prcCheckSecurity_browesSec] @userGUID, @result, @secViol, 'conSecurity', 'conGUID, conGuid, buGuid', 'fnGetUserAssetContSec_Browse', DEFAULT, 15

	-- Asset StartDate Possession Security
	EXEC [prcCheckSecurity_browesSec] @userGUID, @result, @secViol, 'asdSecurity', 'conGUID, conGuid, buGuid', 'fnGetUserAssetStartPossSec_Browse', DEFAULT, 16

	DELETE FROM [#SecViol] WHERE [Cnt] = 0
	DROP TABLE [#fields]
END
######################################################
#END