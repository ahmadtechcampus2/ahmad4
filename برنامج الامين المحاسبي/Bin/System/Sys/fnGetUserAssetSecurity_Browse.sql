######################################################
CREATE FUNCTION fnGetUserAssetDetailsSec (@UserGUID [UNIQUEIDENTIFIER], @PermType [INT])
	RETURNS [INT]
AS BEGIN
	RETURN [dbo].[fnGetUserSec](@UserGUID, 0x200070B0, 0x0, 1, @PermType)
END
######################################################
CREATE FUNCTION fnGetUserAssetDetailsSec_Browse (@UserGUID [UNIQUEIDENTIFIER])
	RETURNS [INT]
AS BEGIN
	RETURN [dbo].[fnGetUserAssetDetailsSec] (@UserGUID, 1)
END
######################################################
CREATE FUNCTION fnGetUserAssetAddSec (@UserGUID [UNIQUEIDENTIFIER], @PermType [INT])
	RETURNS [INT]
AS BEGIN
	RETURN [dbo].[fnGetUserSec](@UserGUID, 0x20007090, 0x0, 1, @PermType)
END
######################################################
CREATE FUNCTION fnGetUserAssetAddSec_Browse (@UserGUID [UNIQUEIDENTIFIER])
	RETURNS [INT]
AS BEGIN
	RETURN [dbo].[fnGetUserAssetAddSec] (@UserGUID, 1)
END
######################################################
CREATE FUNCTION fnGetUserAssetDedSec (@UserGUID [UNIQUEIDENTIFIER], @PermType [INT])
	RETURNS [INT]
AS BEGIN
	RETURN [dbo].[fnGetUserSec](@UserGUID, 0x200070A0, 0x0, 1, @PermType)
END
######################################################
CREATE FUNCTION fnGetUserAssetDedSec_Browse (@UserGUID [UNIQUEIDENTIFIER])
	RETURNS [INT]
AS BEGIN
	RETURN [dbo].[fnGetUserAssetDedSec](@UserGUID, 1)
END
######################################################
CREATE FUNCTION fnGetUserAssetMainSec (@UserGUID [UNIQUEIDENTIFIER], @PermType [INT])
	RETURNS [INT]
AS BEGIN
	RETURN [dbo].[fnGetUserSec](@UserGUID, 0x20007070, 0x0, 1, @PermType)
END
######################################################
CREATE FUNCTION fnGetUserAssetMainSec_Browse (@UserGUID [UNIQUEIDENTIFIER])
	RETURNS [INT]
AS BEGIN
	RETURN [dbo].[fnGetUserAssetMainSec](@UserGUID, 1)
END
######################################################
CREATE FUNCTION fnGetUserAssetDepSec (@UserGUID [UNIQUEIDENTIFIER], @PermType [INT])
	RETURNS [INT]
AS BEGIN
	RETURN [dbo].[fnGetUserSec](@UserGUID, 0x200070C0, 0x0, 1, @PermType)
END
######################################################
CREATE FUNCTION fnGetUserAssetDepSec_Browse (@UserGUID [UNIQUEIDENTIFIER])
	RETURNS [INT]
AS BEGIN
	RETURN [dbo].[fnGetUserAssetDepSec] (@UserGUID, 1)
END
######################################################
CREATE FUNCTION fnGetUserAssetExcludeSec (@UserGUID [UNIQUEIDENTIFIER], @PermType [INT])
	RETURNS [INT]
AS BEGIN
	RETURN [dbo].[fnGetUserSec](@UserGUID, 0x20007103, 0x0, 1, @PermType)
END
######################################################
CREATE FUNCTION fnGetUserAssetExcludeSec_Browse (@UserGUID [UNIQUEIDENTIFIER])
	RETURNS [INT]
AS BEGIN
	RETURN [dbo].[fnGetUserAssetExcludeSec](@UserGUID, 1)
END
######################################################
CREATE FUNCTION fnGetUserAssetExchSec (@UserGUID [UNIQUEIDENTIFIER], @PermType [INT])
	RETURNS [INT]
AS BEGIN
	RETURN [dbo].[fnGetUserSec](@UserGUID, 0x20007116, 0x0, 1, @PermType)
END
######################################################
CREATE FUNCTION fnGetUserAssetExchSec_Browse (@UserGUID [UNIQUEIDENTIFIER])
	RETURNS [INT]
AS BEGIN
	RETURN [dbo].[fnGetUserAssetExchSec](@UserGUID, 1)
END
######################################################
CREATE FUNCTION fnGetUserAssetContSec (@UserGUID [UNIQUEIDENTIFIER], @PermType [INT])
	RETURNS [INT]
AS BEGIN
	RETURN [dbo].[fnGetUserSec](@UserGUID, 0x20007117, 0x0, 1, @PermType)
END
######################################################
CREATE FUNCTION fnGetUserAssetContSec_Browse (@UserGUID [UNIQUEIDENTIFIER])
	RETURNS [INT]
AS BEGIN
	RETURN [dbo].[fnGetUserAssetContSec](@UserGUID, 1)
END
######################################################
CREATE FUNCTION fnGetUserAssetStartPossSec (@UserGUID [UNIQUEIDENTIFIER], @PermType [INT])
	RETURNS [INT]
AS BEGIN
	RETURN [dbo].[fnGetUserSec](@UserGUID, 0x20007119, 0x0, 1, @PermType)
END
######################################################
CREATE FUNCTION fnGetUserAssetStartPossSec_Browse (@UserGUID [UNIQUEIDENTIFIER])
	RETURNS [INT]
AS BEGIN
	RETURN [dbo].[fnGetUserAssetStartPossSec](@UserGUID, 1)
END
######################################################
#END