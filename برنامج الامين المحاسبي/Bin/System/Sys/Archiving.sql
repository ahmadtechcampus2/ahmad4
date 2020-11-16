###############################################################################
CREATE PROCEDURE prcArchiving_GetMatList
AS
	SET NOCOUNT ON
		
	CREATE TABLE [#SecViol] ([Type] [INT], [Cnt] [INT])
	CREATE TABLE [#Result](
			[Guid]		[UNIQUEIDENTIFIER],
			[Code]		[NVARCHAR](250) COLLATE ARABIC_CI_AI,
			[Name]		[NVARCHAR](250) COLLATE ARABIC_CI_AI,
			[LatinName]	[NVARCHAR](250) COLLATE ARABIC_CI_AI,
			[mtSecurity]	[INT]
		   	)
	
	INSERT INTO [#Result] 
	SELECT 
			[mt].[mtGuid], 
			[mt].[mtCode], 
			[mt].[mtName],
			[mt].[mtLatinName],
			[mt].[mtSecurity]
	FROM
			[vwmt] as [mt]
	WHERE ([mt].[mttype] <> 2) 
	
	EXEC [prcCheckSecurity]
	SELECT [Guid] ID,[Code],[Name],[LatinName] FROM [#Result] 
###########################################################################
CREATE PROCEDURE prcArchiving_GetGroupsList
AS
	SET NOCOUNT ON
		
	CREATE TABLE [#SecViol] ([Type] [INT], [Cnt] [INT])
	CREATE TABLE [#Result](
			[Guid]		[UNIQUEIDENTIFIER],
			[Code]		[NVARCHAR](250) COLLATE ARABIC_CI_AI,
			[Name]		[NVARCHAR](250) COLLATE ARABIC_CI_AI,
			[LatinName]	[NVARCHAR](250) COLLATE ARABIC_CI_AI,
			[grSecurity]	[INT]
		   	)
	
	INSERT INTO [#Result] 
	SELECT 
			[gr].[grGUID], 
			[gr].[grCode], 
			[gr].[grName],
			[gr].[grLatinName],
			[gr].[grSecurity]
	FROM
			[vwGr] as [gr]
	
	EXEC [prcCheckSecurity]
	SELECT [Guid] ID,[Code],[Name],[LatinName] FROM [#Result] 
###########################################################################
CREATE PROCEDURE prcArchiving_GetCheckTypesList
AS
	SET NOCOUNT ON
		
	CREATE TABLE [#SecViol] ([Type] [INT], [Cnt] [INT])
	CREATE TABLE [#Result](
			[Guid]		[UNIQUEIDENTIFIER],
			[Code]		[NVARCHAR](250) COLLATE ARABIC_CI_AI,
			[Name]		[NVARCHAR](250) COLLATE ARABIC_CI_AI,
			[LatinName]	[NVARCHAR](250) COLLATE ARABIC_CI_AI,
			[grSecurity]	[INT]
		   	)
	
	INSERT INTO [#Result] 
	SELECT 
			[nt].[ntGUID], 
			'', 
			[nt].[ntName],
			[nt].[ntLatinName],
			0
	FROM
			[vwNt] as [nt]
	
	SELECT [Guid] ID,[Code],[Name],[LatinName] FROM [#Result] 
###########################################################################
CREATE PROCEDURE prcArchiving_GetBanksList
AS
	SET NOCOUNT ON
		
	CREATE TABLE [#SecViol] ([Type] [INT], [Cnt] [INT])
	CREATE TABLE [#Result](
			[Guid]		[UNIQUEIDENTIFIER],
			[Code]		[NVARCHAR](250) COLLATE ARABIC_CI_AI,
			[Name]		[NVARCHAR](250) COLLATE ARABIC_CI_AI,
			[LatinName]	[NVARCHAR](250) COLLATE ARABIC_CI_AI,
			[bkSecurity]	[INT]
		   	)
	
	INSERT INTO [#Result] 
	SELECT 
			[bk].[GUID], 
			[bk].[Code], 
			[bk].[BankName],
			[bk].[BankLatinName],
			[bk].[Security]
	FROM
			[Bank000] as [bk]
	
	EXEC [prcCheckSecurity]
	SELECT [Guid] ID,[Code],[Name],[LatinName] FROM [#Result] 
###########################################################################
CREATE PROCEDURE prcArchiving_GetStoresList
AS
	SET NOCOUNT ON
		
	CREATE TABLE [#SecViol] ([Type] [INT], [Cnt] [INT])
	CREATE TABLE [#Result](
			[Guid]		[UNIQUEIDENTIFIER],
			[Code]		[NVARCHAR](250) COLLATE ARABIC_CI_AI,
			[Name]		[NVARCHAR](250) COLLATE ARABIC_CI_AI,
			[LatinName]	[NVARCHAR](250) COLLATE ARABIC_CI_AI,
			[stSecurity]  [INT]
		   	)
	
	INSERT INTO [#Result] 
	SELECT 
			[st].[stGUID], 
			[st].[stCode], 
			[st].[stName],
			[st].[stLatinName],
			[st].[stSecurity]
	FROM
			[vwSt] as [st]
	
	EXEC [prcCheckSecurity]
	SELECT [Guid] ID,[Code],[Name],[LatinName] FROM [#Result] 
###########################################################################
CREATE PROCEDURE prcArchiving_GetAccountsList
@Type INT, -- Normal = 1, Final = 2, Composite = 4, Cost = 8, All = 15
@HasSons INT -- DontHasSons = 0, HasSons = 1, All = 2
AS
	SET NOCOUNT ON
		
	CREATE TABLE [#SecViol] ([Type] [INT], [Cnt] [INT])
	CREATE TABLE [#Result](
			[Guid]		[UNIQUEIDENTIFIER],
			[Code]		[NVARCHAR](250) COLLATE ARABIC_CI_AI,
			[Name]		[NVARCHAR](250) COLLATE ARABIC_CI_AI,
			[LatinName]	[NVARCHAR](250) COLLATE ARABIC_CI_AI,
			[acSecurity]  [INT]
		   	)
	
	INSERT INTO [#Result] 
	SELECT 
			[ac].[acGUID], 
			[ac].[acCode], 
			[ac].[acName],
			[ac].[acLatinName],
			[ac].[acSecurity]
	FROM
			[vwAc] as [ac]
	WHERE (@Type & [ac].[acType] = [ac].[acType])
	AND(@HasSons = 2 OR(@HasSons = 0 AND [ac].[acNSons] = 0) OR(@HasSons = 1 AND [ac].[acNSons] > 0))
	
	EXEC [prcCheckSecurity]
	SELECT [Guid] ID,[Code],[Name],[LatinName] FROM [#Result] 
###########################################################################
CREATE PROCEDURE prcArchiving_GetCostsList
AS
	SET NOCOUNT ON
		
	CREATE TABLE [#SecViol] ([Type] [INT], [Cnt] [INT])
	CREATE TABLE [#Result](
			[Guid]		[UNIQUEIDENTIFIER],
			[Code]		[NVARCHAR](250) COLLATE ARABIC_CI_AI,
			[Name]		[NVARCHAR](250) COLLATE ARABIC_CI_AI,
			[LatinName]	[NVARCHAR](250) COLLATE ARABIC_CI_AI,
			[coSecurity]  [INT]
		   	)
	
	INSERT INTO [#Result] 
	SELECT 
			[co].[coGUID], 
			[co].[coCode], 
			[co].[coName],
			[co].[coLatinName],
			[co].[coSecurity]
	FROM
			[vwCo] as [co]
	
	EXEC [prcCheckSecurity]
	SELECT [Guid] ID,[Code],[Name],[LatinName] FROM [#Result] 
###########################################################################
CREATE PROCEDURE prcArchiving_GetUsersList
AS
	SET NOCOUNT ON
		
	CREATE TABLE [#SecViol] ([Type] [INT], [Cnt] [INT])
	CREATE TABLE [#Result](
			[Guid]		[UNIQUEIDENTIFIER],
			[Name]		[NVARCHAR](250) COLLATE ARABIC_CI_AI
		   	)
	
	INSERT INTO [#Result] 
	SELECT 
			[us].[usGUID], 
			[us].[usLoginName]
	FROM
			[vwUs] as [us]
	
	SELECT [Guid] ID,[Name] FROM [#Result] 
###########################################################################
CREATE PROCEDURE prcArchiving_GetCustomersList
AS
	SET NOCOUNT ON
		
	CREATE TABLE [#SecViol] ([Type] [INT], [Cnt] [INT])
	CREATE TABLE [#Result](
			[Guid]		[UNIQUEIDENTIFIER],
			[Name]		[NVARCHAR](250) COLLATE ARABIC_CI_AI,
			[LatinName]	[NVARCHAR](250) COLLATE ARABIC_CI_AI,
			[cuSecurity]  [INT]
		   	)
	
	INSERT INTO [#Result] 
	SELECT 
			[cu].[cuGUID], 
			[cu].[cuCustomerName],
			[cu].[cuLatinName],
			[cu].[cuSecurity]
	FROM
			[vwCu] as [cu]
	
	EXEC [prcCheckSecurity]
	SELECT [Guid] ID,[Name],[LatinName] FROM [#Result] 
###########################################################################
CREATE PROCEDURE prcArchiving_GetReportSourceList
AS
	SET NOCOUNT ON

	DECLARE @UserGUID [UNIQUEIDENTIFIER] = ( [dbo].[fnGetCurrentUserGUID]())

	CREATE TABLE [#Result](
			[ID]		[UNIQUEIDENTIFIER],
			[Code]		[NVARCHAR](250) COLLATE ARABIC_CI_AI,
			[Name]		[NVARCHAR](250) COLLATE ARABIC_CI_AI,
			[LatinName]	[NVARCHAR](250) COLLATE ARABIC_CI_AI,
			[SortFld]	[int]
		   	)

	--ENTRY TYPES
	INSERT INTO [#Result] 
	SELECT 
			[et].[GUID],
			'', 
			[et].[Name],
			[et].[LatinName],
			[et].[SortNum]
	FROM
			[et000] as [et]
	WHERE 
			NOT([dbo].[fnGetUserEntrySec_Browse](@UserGUID,et.GUID) < 1 AND [dbo].[fnGetUserEntrySec_Enter](@UserGUID,et.GUID) < 1)
	ORDER BY 
			([et].[SortNum])

	IF @@ROWCOUNT != 0
	BEGIN
		DECLARE @FldCounter INT =(select MAX([SortFld]) from #Result)+1
	
		--SEPARETOR
		INSERT INTO [#Result]  VALUES (0x0,'','','',@FldCounter) 
	END
	--BILL TYPES
	INSERT INTO [#Result] 
	SELECT 
			[bt].[GUID], 
			'', 
			[bt].[Name],
			[bt].[LatinName],
			[bt].[SortNum]+@FldCounter
	FROM
			[bt000] as [bt]
	WHERE 
			bt.Type = 1
			AND 
			NOT([dbo].[fnGetUserBillSec_Browse](@UserGUID,bt.GUID) < 1 AND [dbo].[fnGetUserBillSec_Enter](@UserGUID,bt.GUID) < 1)
	ORDER BY 
			[bt].[SortNum]

	IF @@ROWCOUNT != 0
	BEGIN
		SET @FldCounter  =(select MAX([SortFld]) from #Result)+1
	
		--SEPARETOR
		INSERT INTO [#Result]  VALUES (0x0,'','','',@FldCounter) 
	END

	--STANDRD BILL TYPES
	INSERT INTO [#Result] 
	SELECT Top(1)
			[bt].[GUID],
			'',  
			[bt].[Name],
			[bt].[LatinName],
			[bt].[SortNum]+@FldCounter
	FROM
			[bt000] as [bt]
	WHERE 
			[bt].Type = 2
			AND
			NOT([dbo].[fnGetUserBillSec_Browse](@UserGUID,bt.GUID) < 1 AND [dbo].[fnGetUserBillSec_Enter](@UserGUID,bt.GUID) < 1)
	ORDER BY 
			[bt].[SortNum]

	IF @@ROWCOUNT != 0
	BEGIN
		SET @FldCounter  =(select MAX([SortFld]) from #Result)+1
	
		--SEPARETOR
		INSERT INTO [#Result]  VALUES (0x0,'','','',@FldCounter) 
	END

	--NOTES TYPES
	INSERT INTO [#Result] 
	SELECT 
			[nt].[GUID],
			'',  
			[nt].[Name],
			[nt].[LatinName],
			[nt].[SortNum]+@FldCounter
	FROM
			[nt000] as [nt]
	WHERE 
			NOT([dbo].[fnGetUserNoteSec_Browse](@UserGUID,nt.GUID) < 1 AND [dbo].[fnGetUserNoteSec_Enter](@UserGUID,nt.GUID) < 1)

	ORDER BY 
			[nt].[SortNum]

	IF @@ROWCOUNT != 0
	BEGIN
		SET @FldCounter =(select MAX([SortFld]) from #Result)+1
	
		--SEPARETOR
		INSERT INTO [#Result]  VALUES (0x0,'','','',@FldCounter) 
	END

	--SELL ORDERS BILL TYPES
	INSERT INTO [#Result] 
	SELECT 
			[bt].[GUID], 
			'', 
			[bt].[Name],
			[bt].[LatinName],
			[bt].[SortNum]+@FldCounter
	FROM
			[bt000] as [bt]
	WHERE 
			[bt].Type = 5
			AND
			NOT([dbo].[fnGetUserBillSec_Browse](@UserGUID,bt.GUID) < 1 AND [dbo].[fnGetUserBillSec_Enter](@UserGUID,bt.GUID) < 1)
	ORDER BY 
			[bt].[SortNum]

	SET @FldCounter =(select MAX([SortFld]) from #Result)
	--PURCHASES ORDERS BILL TYPES
	INSERT INTO [#Result] 
	SELECT 
			[bt].[GUID],
			'',  
			[bt].[Name],
			[bt].[LatinName],
			[bt].[SortNum]+@FldCounter
	FROM
			[bt000] as [bt]
	WHERE 
			[bt].Type = 6
			AND
			NOT([dbo].[fnGetUserBillSec_Browse](@UserGUID,bt.GUID) < 1 AND [dbo].[fnGetUserBillSec_Enter](@UserGUID,bt.GUID) < 1)
	ORDER BY 
			[bt].[SortNum]

	IF @@ROWCOUNT != 0
	BEGIN
		SET @FldCounter  =(select MAX([SortFld]) from #Result)+1
	
		--SEPARETOR
		INSERT INTO [#Result]  VALUES (0x0,'','','',@FldCounter) 
	END

	DELETE TOP (1)  FROM [#Result] WHERE [SortFld] IN(SELECT MAX([SortFld]) FROM [#Result])

	SELECT [ID],[Code],[Name],[LatinName] FROM [#Result] ORDER BY ([SortFld])
###########################################################################
CREATE PROCEDURE prcArchiving_GetBranchList
AS
	SET NOCOUNT ON
		
	SELECT brGUID ID, brCode Code, brName Name, brLatinName LatinName FROM vwBr
###########################################################################
CREATE PROCEDURE prcArchiving_DeleteDocument
	@documentId UNIQUEIDENTIFIER
AS
	SET NOCOUNT ON

	BEGIN TRANSACTION [Trans]

	BEGIN TRY
	
		DELETE FROM DMSTblFile WHERE DocumentId = @documentId

		DELETE FROM DMSTblDocumentFieldValue WHERE DocumentID = @documentId

		DELETE FROM DMSTblDocument WHERE ID = @documentId

	COMMIT TRANSACTION [Trans]

	END TRY
	BEGIN CATCH
	  ROLLBACK TRANSACTION [Trans]
	END CATCH  
###########################################################################
CREATE PROCEDURE prcArchiving_GetCurrenciesList
AS
	SET NOCOUNT ON
		
	CREATE TABLE [#SecViol] ([Type] [INT], [Cnt] [INT])
	CREATE TABLE [#Result](
			[Guid]		[UNIQUEIDENTIFIER],
			[Code]		[NVARCHAR](250) COLLATE ARABIC_CI_AI,
			[Name]		[NVARCHAR](250) COLLATE ARABIC_CI_AI,
			[LatinName]	[NVARCHAR](250) COLLATE ARABIC_CI_AI,
			[acSecurity]  [INT]
		   	)
	
	INSERT INTO [#Result] 
	SELECT 
			[my].[myGUID], 
			[my].[myCode], 
			[my].[myName],
			[my].[myLatinName],
			[my].[mySecurity]
	FROM
			[vwMy] as my
	
	EXEC [prcCheckSecurity]
	SELECT [Guid] ID,[Code],[Name],[LatinName] FROM [#Result] 
###########################################################################
CREATE PROCEDURE prcArchiving_GetFormsList
AS
	SET NOCOUNT ON
		
	CREATE TABLE [#SecViol] ([Type] [INT], [Cnt] [INT])
	CREATE TABLE [#Result](
			[Guid]		[UNIQUEIDENTIFIER],
			[Code]		[NVARCHAR](250) COLLATE ARABIC_CI_AI,
			[Name]		[NVARCHAR](250) COLLATE ARABIC_CI_AI,
			[LatinName]	[NVARCHAR](250) COLLATE ARABIC_CI_AI,
			[acSecurity]  [INT]
		   	)
	
	INSERT INTO [#Result] 
	SELECT 
			[fm].[GUID], 
			[fm].[Code], 
			[fm].[Name],
			[fm].[LatinName],
			[fm].[Security]
	FROM
			[vcFm] as fm
	
	EXEC [prcCheckSecurity]
	SELECT [Guid] ID,[Code],[Name],[LatinName] FROM [#Result] 
###########################################################################
#END