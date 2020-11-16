###########################################################################
CREATE PROCEDURE prcupdateenNote
	@Guid UNIQUEIDENTIFIER,
	@Note NVARCHAR(255)
AS 
	EXEC prcDisableTriggers	'en000'
	UPDATE en000 SET Notes = @Note WHERE [GUID] = @Guid
	ALTER TABLE en000 ENABLE TRIGGER ALL
###########################################################################
CREATE PROCEDURE prcupdateceNote
	@Guid UNIQUEIDENTIFIER,
	@Note NVARCHAR(255)
AS 
	EXEC prcDisableTriggers	'ce000' 
	UPDATE ce000 SET Notes = @Note WHERE [GUID] = @Guid 
	ALTER TABLE ce000 ENABLE TRIGGER ALL
	DECLARE @Parent UNIQUEIDENTIFIER 
	SELECT @Parent = PARENTGUID  FROM [er000] WHERE [ParentTYPE] = 4 AND EntryGuid = @Guid 
	IF @Parent IS NOT NULL 
	BEGIN 
		EXEC prcDisableTriggers	'PY000' 
		UPDATE py000 SET Notes = @Note WHERE [GUID] = @Parent 
		ALTER TABLE py000 ENABLE TRIGGER ALL	 
	END 
###########################################################################
CREATE PROCEDURE prcupdatebuNote
	@Guid UNIQUEIDENTIFIER,
	@Note NVARCHAR(255)
AS 
	EXEC prcDisableTriggers	'bu000'
	UPDATE bu000 SET Notes = @Note WHERE [GUID] = @Guid
	ALTER TABLE bu000 ENABLE TRIGGER ALL
###########################################################################
CREATE PROCEDURE prcupdatebiNote
	@Guid UNIQUEIDENTIFIER,
	@Note NVARCHAR(255)
AS 
	EXEC prcDisableTriggers	'bi000'
	UPDATE bi000 SET Notes = @Note WHERE [GUID] = @Guid
	ALTER TABLE bi000 ENABLE TRIGGER ALL
###########################################################################
CREATE PROCEDURE prcupdateNotes
	@Guid UNIQUEIDENTIFIER,
	@Note NVARCHAR(255),
	@i TINYINT = 0,
	@Str NVARCHAR(100),
	@OP TINYINT = 3,
	@LgType TINYINT = 2
AS
	DECLARE @Branch UNIQUEIDENTIFIER,@UserGuid UNIQUEIDENTIFIER,@OriginalGuid UNIQUEIDENTIFIER
	BEGIN TRAN
	IF @i = 20 
		EXEC prcupdateceNote @Guid,@Note
	ELSE IF @i = 21
		EXEC prcupdateenNote @Guid,@Note
	ELSE IF @i = 22
		EXEC prcupdatebuNote @Guid,@Note
	ELSE IF @i = 23
		EXEC prcupdatebiNote @Guid,@Note
	COMMIT
	IF EXISTS(SELECT * FROM OP000 WHERE [NAME] ='AmnCfg_UseLogging' AND [Value] = 1) 
    BEGIN 
		SET @UserGuid = [dbo].[fnGetCurrentUserGUID]() 
		IF @i = 1
			SELECT @OriginalGuid = ParentGuid FROM en000 WHERE Guid = @Guid
		ELSE IF @i = 3
			SELECT @OriginalGuid = ParentGuid FROM BI000 WHERE Guid = @Guid
		ELSE
			SET @OriginalGuid = @Guid
		IF @i = 1 OR @i = 0
			SELECT @Branch = Branch FROM bu000 WHERE GUID = @OriginalGuid
		ELSE
			SELECT @Branch = Branch FROM CE000 WHERE GUID = @OriginalGuid
        INSERT INTO  LoG000 (Computer,GUID,LogTime,RecGUID,Operation,OperationType,UserGUID) 
        VALUES( host_Name(),NEWID(),GETDATE(),@OriginalGuid,@LgType,@OP,@UserGUID )
      END
###########################################################################
CREATE PROCEDURE prcGetNote
	@Guid UNIQUEIDENTIFIER,
	@i TINYINT = 0
AS 
	IF @i = 20
		SELECT Notes FROM ce000 WHERE Guid = @Guid
	ELSE IF @i = 21
		SELECT Notes FROM en000 WHERE Guid = @Guid
	ELSE IF @i = 22
		SELECT Notes FROM bu000 WHERE Guid = @Guid
	ELSE IF @i = 24
		SELECT NOTES FROM CH000 WHERE Guid =@Guid
	ELSE 
		SELECT Notes FROM bi000 WHERE Guid = @Guid
###########################################################################
CREATE PROCEDURE prcupdateCHNote
	@Guid UNIQUEIDENTIFIER,
	@Note NVARCHAR(MAX)
AS 
	UPDATE ch000 SET Notes = @Note WHERE [GUID] = @Guid

	UPDATE en
	SET Notes=@Note
	FROM en000 en INNER JOIN  er000 er  ON en.ParentGUID= er.EntryGUID
	WHERE ParentType = 5 AND er.ParentGUID =@Guid and en.credit > 0
	
	UPDATE ce
	SET Notes=@Note
	FROM ce000 ce INNER JOIN er000 er ON ce.GUID= er.EntryGUID
	WHERE ParentType = 5 AND er.ParentGUID =@Guid

##########################################################################
#END 