###########################################################################
CREATE PROCEDURE prcModifyBonus
	@MatGuid UNIQUEIDENTIFIER,
	@GrpGuid UNIQUEIDENTIFIER,
	@MatCondGuid	UNIQUEIDENTIFIER,
	@Bonus			FLOAT,
	@BonusOne		FLOAT
AS 
	BEGIN TRAN
	SET NOCOUNT ON
	CREATE TABLE [#Mat] ( [mtGUID] [UNIQUEIDENTIFIER], [mtSecurity] [INT])
	DECLARE @UserGuid	UNIQUEIDENTIFIER  
	INSERT INTO [#Mat] EXEC [prcGetMatsList]  @MatGuid, @GrpGuid,-1,@MatCondGuid
	DECLARE @Sec [INT]
	SET @UserGuid = dbo.fnGetCurrentUserGUID()
	SET @Sec = dbo.fnGetUserMaterialSec_Update(@UserGuid)
	DELETE [#Mat] WHERE [mtSecurity] > @Sec
	UPDATE mt SET Bonus = @Bonus,BonusOne = @BonusOne FROM [mt000] mt INNER JOIN [#Mat] a ON a.[mtGUID] = mt.Guid
	IF EXISTS(SELECT * FROM op000 WHERE [Name] = 'AmnCfg_UseLogging' AND [Value] = '1')
		INSERT INTO [log000](guid,DrvRID,RecGUID,Operation,Computer,UserGUID,LogTime)
			SELECT newid(),268537856,[mtGUID],3,HOST_ID(),@UserGuid,GETDATE() FROM [#Mat]
	COMMIT
	SELECT mt.Code,mt.Guid,mt.Name,mt.LatinName FROM [mt000] mt INNER JOIN [#Mat] a ON a.[mtGUID] = mt.Guid
-- [prcModifyBonus] '00000000-0000-0000-0000-000000000000', '6c493a5d-7bf5-4a48-9156-1fa32fbb9a04', '00000000-0000-0000-0000-000000000000', 8.000000, 1.000000
################################################################################
#END

	
	