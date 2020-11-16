##########################################################################
CREATE PROCEDURE prcCopyFaoriteAccToNewUser
	@SrcUser	UNIQUEIDENTIFIER,
	@DistUser	UNIQUEIDENTIFIER,
	@profId		INT,
	@PanelId	INT
AS 
	SET NOCOUNT ON
	DECLARE @Name NVARCHAR(100),@MaxId [INT]
	
	SELECT @Name = [Value] FROM op000 where name like 'AmnCfg_HTML_CustomProfile_' + CAST(@profId as NVARCHAR(10))+ '_Name' AND 	UserGuid = @SrcUser
	IF EXISTS(SELECT  * FROM op000 where name like 'AmnCfg_HTML_CustomProfile%' AND UserGuid = @DistUser AND VALUE = @Name)
	BEGIN
		SELECT -2 [Result]
		RETURN 
	END
	
	SELECT @MaxId = max(CAST(SUBSTRING(name ,LEN('AmnCfg_HTML_CustomProfile_') + 1, LEN(name) - len('_Name') - LEN('AmnCfg_HTML_CustomProfile_')) AS INT))
	FROM [op000] 
	WHERE 
		[name] like 'AmnCfg_HTML_CustomProfile%' AND name like '%_Name' AND name not like '%_PanelName'
		AND UserGuid = @DistUser
	IF @MaxId IS NULL
		SET @MaxId = 1
	ELSE 
		SET @MaxId = @MaxId + 1

	
	INSERT INTO [op000] (Name,Value,PrevValue,Computer,Type,OwnerGUID,UserGUID)
	SELECT REPLACE(name,CAST(@profId as NVARCHAR(10)),CAST(@MaxId as NVARCHAR(10))) 
	,case when Value like 'AmnCfg_HTML_CustomPanel%' THEN 'AmnCfg_HTML_CustomPanel_' + CAST(@PanelId as NVARCHAR(10)) + '_Name' ELSE Value END 
	,PrevValue,HOST_NAME(),Type,@DistUser,@DistUser
	FROM [op000] 
	WHERE 
	[name] like 'AmnCfg_HTML_CustomProfile_' + CAST(@profId as NVARCHAR(10)) + '%' 	AND 	ownerGuid = @SrcUser

	INSERT INTO [op000] (Name,Value,PrevValue,Computer,Type,OwnerGUID,UserGUID)
	SELECT
	[name],[Value],[PrevValue],HOST_NAME(),Type,@DistUser,@DistUser
	FROM [op000] WHERE name like 'AmnCfg_FavReps_Dlg_%' and name like '%' + @Name + '%' AND ownerGuid = @SrcUser
	update [op000] SET [Value] = CAST((CAST ([Value] AS INT) +1) AS NVARCHAR(10)) where name = 'ProfileCnt' and userguid = @DistUser
	IF @@ROWCOUNT = 0
		INSERT INTO [op000] (Name,Value,PrevValue,Computer,Type,OwnerGUID,UserGUID)
			SELECT 'ProfileCnt','1','0',HOST_NAME(),1,@DistUser,@DistUser
	SELECT @MaxId [Result]

--exec  [prcCopyFaoriteAccToNewUser] 'b68012b8-1eaa-44e2-b56c-3345c2bd5a9f', 'ea8d2584-5b09-41ff-8f5a-923cd614b702', 15, 6
##########################################################################
CREATE PROCEDURE prcCopyCustomPanelToUser
	@SrcUser	UNIQUEIDENTIFIER,
	@DistUser	UNIQUEIDENTIFIER,
	@TabId		INT,
	@CustomId	INT
AS 
	SET NOCOUNT ON
	 
	DECLARE @Name NVARCHAR(100), @MaxId INT;
	
	SELECT @Name = Value FROM op000 WHERE Name LIKE 'AmnCfg_HTML_CustomPanel_' + CAST(@CustomId as NVARCHAR(10)) + '_Name' AND UserGuid = @SrcUser;
	
	IF EXISTS(SELECT * FROM op000 WHERE Name LIKE 'AmnCfg_HTML_CustomPanel%' AND UserGuid = @DistUser AND VALUE = @Name)
	BEGIN
		SELECT -2 [Result]
		RETURN 
	END

	SELECT @MaxId = ISNULL(CAST(MAX(SUBSTRING(Name, LEN('AmnCfg_HTML_CustomPanel_') + 1, LEN(Name) - LEN('AmnCfg_HTML_CustomPanel_') - LEN('_Name'))) AS INT), 0) + 1 
	FROM op000 
	WHERE Name LIKE 'AmnCfg[_]HTML[_]CustomPanel[_][0-9]%[_]Name' AND UserGuid =  @DistUser;
	
	INSERT INTO op000(Name, Value, PrevValue, Computer, Type, OwnerGUID, UserGUID)
	SELECT 
		REPLACE(Name, CAST(@CustomId as NVARCHAR(10)), CAST(@MaxId as NVARCHAR(10))),
		CASE WHEN Value LIKE 'AmnCfg_HTML_CustomTab_%' THEN 'AmnCfg_HTML_CustomTab_' + CAST(@TabId as NVARCHAR(10)) + '_Name' ELSE Value END,
		PrevValue, HOST_NAME(), Type, @DistUser, @DistUser
	FROM op000
	WHERE Name LIKE 'AmnCfg_HTML_CustomPanel_' + CAST(@CustomId as NVARCHAR(10)) + '%' AND OwnerGUID = @SrcUser;

	UPDATE op000
	SET PrevValue = Value, Value = CAST(Value AS INT) + 1
	WHERE Name = 'PanelCnt' AND UserGUID = @DistUser;

	SELECT 1 [Result];
##########################################################################
CREATE PROCEDURE prcCopyTabToUser
	@SrcUser	UNIQUEIDENTIFIER,
	@DistUser	UNIQUEIDENTIFIER,
	@TabId		INT
AS 
	SET NOCOUNT ON 
	DECLARE @Name NVARCHAR(100), @MaxId [INT];
	
	SELECT @Name = [Value] FROM op000 where Name like 'AmnCfg_HTML_CustomTab_' + CAST(@TabId as NVARCHAR(10))+ '_Name' AND 	UserGuid = @SrcUser;

	IF EXISTS(SELECT * FROM op000 where Name like 'AmnCfg_HTML_CustomTab_%' AND UserGuid = @DistUser AND VALUE = @Name)
	BEGIN
		SELECT -2 [Result]
		RETURN 
	END

	SELECT @MaxId = ISNULL(CAST(MAX(SUBSTRING(Name,LEN('AmnCfg_HTML_CustomTab_') + 1, LEN(Name) - LEN('AmnCfg_HTML_CustomTab_') - LEN('_Name'))) AS INT), 0) + 1
	FROM op000 WHERE Name LIKE 'AmnCfg[_]HTML[_]CustomTab[_][0-9]%[_]Name' AND [UserGuid] =  @DistUser

	INSERT INTO [op000](Name, Value, PrevValue, Computer, Type, OwnerGUID, UserGUID)
	SELECT REPLACE(Name, CAST(@TabId as NVARCHAR(10)), CAST(@MaxId as NVARCHAR(10))), Value, PrevValue, HOST_NAME(), Type, @DistUser, @DistUser
	FROM [op000] 
	WHERE [Name] LIKE 'AmnCfg_HTML_CustomTab_' + CAST(@TabId as NVARCHAR(10)) + '%' AND	ownerGuid = @SrcUser;
	
	SELECT 1 [Result];

##########################################################################
#END