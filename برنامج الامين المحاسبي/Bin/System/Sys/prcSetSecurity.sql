##########################################################
CREATE PROC prcBillsSetSecurity
	@btGuid UNIQUEIDENTIFIER,
	@startDate DATETIME,
	@endDate DATETIME,
	@sec INT,
	@bAffectEntries BIT = 1
AS 
	SET NOCOUNT ON 

	IF @sec < 1 SET @sec = 1
	IF @sec > 3	SET @sec = 3

	EXEC prcDisableTriggers 'bu000', 1
	UPDATE [bu000] 
	SET [Security] = @sec 
	WHERE 
		([Date] BETWEEN @startDate AND @endDate)
		AND 
		([TypeGUID] = @btGuid) 
		AND 
		([Security] <> @sec)
	IF EXISTS(SELECT * FROM vwBuMb bm JOIN vwBu b on bm.Guid=b.buGUID WHERE b.buType = @btGuid)
		UPDATE MN000 SET [Security] = @sec WHERE ([Security] <> @sec) and ([Date] BETWEEN @startDate AND @endDate)
	EXEC prcEnableTriggers 'bu000'

	IF @bAffectEntries = 1
	BEGIN 
		EXEC prcDisableTriggers 'ce000', 0
		UPDATE [ce000]
		SET [Security] = @sec
		FROM 
			[ce000] [ce]
			INNER JOIN [er000] [er] ON [er].[EntryGUID] = [ce].[GUID]
			INNER JOIN [bu000] [bu] ON [er].[ParentGUID] = [bu].[GUID]
		WHERE 
			([bu].[Date] BETWEEN @startDate AND @endDate)
			AND 
			([bu].[TypeGUID] = @btGuid) 
			AND 
			([bu].[Security] = @sec)
			AND 
			([ce].[Security] <> @sec)

		EXEC prcEnableTriggers 'ce000'
	END
##########################################################
CREATE PROC prcPaysSetSecurity
	@SrcGuid UNIQUEIDENTIFIER, 
	@startDate DATETIME,
	@endDate DATETIME,
	@sec INT,
	@bAffectEntries BIT = 1
AS 
	SET NOCOUNT ON 

	CREATE TABLE [#EntryTbl]( [Type] [UNIQUEIDENTIFIER], [Security] [INT]) 
	INSERT INTO [#EntryTbl] EXEC [prcGetEntriesTypesList] @SrcGuid 

	IF @sec < 1 SET @sec = 1
	IF @sec > 3	SET @sec = 3

	EXEC prcDisableTriggers 'py000', 1
	UPDATE [py000] 
	SET [Security] = @sec 
	FROM 
		[py000] [py]
		INNER JOIN [#EntryTbl] [Src] On [Src].[Type] = [py].[TypeGuid]
	WHERE 
		([py].[Date] BETWEEN @startDate AND @endDate)
		AND
		([py].[Security] <> @sec)
	EXEC prcEnableTriggers 'py000'
	
	IF @bAffectEntries = 1
	BEGIN 
		EXEC prcDisableTriggers 'ce000', 0

		UPDATE [ce000]
		SET [Security] = @sec
		FROM 
			[ce000] [ce]
			INNER JOIN [er000] [er] ON [er].[EntryGUID] = [ce].[GUID]
			INNER JOIN [py000] [py] ON [er].[ParentGUID] = [py].[GUID]
			INNER JOIN [#EntryTbl] [Src] On [Src].[Type] = [py].[TypeGuid]
		WHERE 
			([py].[Date] BETWEEN @startDate AND @endDate)
			AND 
			([py].[Security] = @sec)
			AND 
			([ce].[Security] <> @sec)

		EXEC prcEnableTriggers 'ce000'
	END	
##########################################################	
CREATE  procedure prcListUserMessage
	@UserGUID [UNIQUEIDENTIFIER],
	@CurrentDate [DateTime] = '1/1/2070',
	@ReadStatus [INT] = 2,
	@Priority [int] = 4,
	@Type [int] = 4,
	@OrderBy [INT] = 3
AS
	SET NOCOUNT ON 
	
	DECLARE @SQL [NVARCHAR](max) 

	SET @Sql = 'SELECT [MSGHEADER000].[Sender],[MSGHEADER000].[Body],[MSGHEADER000].[Title],[MSGHEADER000].
	[Priority],[MSGHEADER000].[Type] , [MSGDETAIL000].*, [us000].[LoginName] FROM [MSGHEADER000]INNER JOIN 
	[MSGDETAIL000] ON ([MSGHEADER000].[Guid]= [MSGDETAIL000].[MsgGUID])INNER JOIN [us000] ON ([us000].[GUID] = [MSGHEADER000].[Sender]) 
	WHERE  [MSGDETAIL000].[ReciverGUID] = '''+ CAST(@UserGUID AS NVARCHAR(250)) +''''
	
	IF (@ReadStatus = 0)
	BEGIN
		SET @sql = @sql + ' and [MSGDETAIL000].[ReadStatus] = 1'
	END
	
	IF (@ReadStatus  = 1 )
	BEGIN
	 SET @sql = @sql + ' and [MSGDETAIL000].[ReadStatus] = 0'
	END
	
	IF (@Priority IN(0,1,2))
	BEGIN
	SET @Sql= @sql + ' and [MSGHEADER000].[Priority] = ' + CAST(@Priority AS NVARCHAR(250)) + '' 
	END
	
	IF (@Type IN (0,1,2) )
	BEGIN 
	SET @Sql= @sql + 'and [MSGHEADER000].[Type] = ' + CAST(@Type AS NVARCHAR(250)) + '' 
	END 
SET @Sql = @sql +'and [MSGHEADER000].[SendDate] <=''' + CAST (@CurrentDate AS NVARCHAR (250))+ ''''
IF ( @ORDERBY = 0)
BEGIN
	SET @SQL = @SQL + 'ORDER BY [US000].[LOGINNAME]'
END

IF ( @ORDERBY = 1)
BEGIN
	SET @SQL = @SQL +'ORDER BY [MSGHEADER000].[PRIORITY]' 
END

IF ( @ORDERBY = 2)
BEGIN
	SET @SQL = @SQL +'ORDER BY [MSGHEADER000].[TYPE]' 
END
EXECUTE  (@Sql)
##########################################################
CREATE PROCEDURE prcGetUserMessageCount
	@UserGUID [UNIQUEIDENTIFIER]
AS
	SET NOCOUNT ON 

	SELECT 
		COUNT ([msgheader000].[Number]) AS [Count] 
	FROM 
		[msgheader000], [msgdetail000]
	WHERE	
		([msgheader000].[GUID] = [msgdetail000].[msgGUID])
		AND ([msgdetail000].[ReciverGUID] = @UserGUID) 
		AND ([msgdetail000].[ReadStatus] = 0)
##########################################################
CREATE PROCEDURE prcShowMessage 
	@MessageGUID [UNIQUEIDENTIFIER]
AS
	SET NOCOUNT ON 

	SELECT 
		[MSGHEADER000].[Sender],
		[MSGHEADER000].[Body],
		[MSGHEADER000].[Title],
		[MSGHEADER000].[SendDate],
		[MSGHEADER000].[Priority],
		[MSGHEADER000].[Type] ,
		[MSGDETAIL000].*,
		[us000].[loginName] 
	FROM 
		[MSGHEADER000]
		INNER JOIN [MSGDETAIL000] ON ([MSGHEADER000].[Guid]= [MSGDETAIL000].[MsgGUID])
		INNER JOIN [us000] ON ([us000].[GUID] = [MSGHEADER000].[Sender]) 
	WHERE
		[MSGDETAIL000].[MsgGUID] = @MessageGUID
##########################################################
CREATE VIEW vwUserMessage
AS 
	SELECT 
		[MsgHeader].[Number],
		[MsgHeader].[Sender],
		[MsgHeader].[Body],
		[MsgHeader].[Title],
		[MsgHeader].[SendDate],
		[MsgHeader].[Priority],
		[MsgHeader].[Type],
		[MsgDetail].[GUID] AS [DetailGUID],
		[MsgDetail].[MsgGUID] AS [Guid],
		[MsgDetail].[ReciverGUID],
		[MsgDetail].[ReadStatus],
		[us].[LoginName]
	FROM 
		[MsgHeader000] AS [MsgHeader],
		[MsgDetail000] AS [MsgDetail], 
		[us000] AS [us]
	WHERE 
		([MsgHeader].[Guid]= [MsgDetail].[MsgGUID] )
		AND	([MsgHeader].[Sender] = [us].[GUID])
		AND ([MsgDetail].[ReciverGUID] =  [dbo].fnGetCurrentUserGUID())
##########################################################	
CREATE PROC prcChecksSetSecurity
	@ntGuid UNIQUEIDENTIFIER,
	@startDate DATETIME,
	@endDate DATETIME,
	@sec INT,
	@bAffectEntries BIT = 1
AS 
	SET NOCOUNT ON 

	IF @sec < 1 SET @sec = 1
	IF @sec > 3	SET @sec = 3

	EXEC prcDisableTriggers 'ch000', 1
	UPDATE [ch000] 
	SET [Security] = @sec 
	WHERE 
		([Date] BETWEEN @startDate AND @endDate)
		AND 
		([TypeGUID] = @ntGuid)
		AND
		([Security] <> @sec)

	EXEC prcEnableTriggers 'ch000'

	IF @bAffectEntries = 1
	BEGIN 
		EXEC prcDisableTriggers 'ce000', 0
		UPDATE [ce000]
		SET [Security] = @sec
		FROM 
			[ce000] [ce]
			INNER JOIN [er000] [er] ON [er].[EntryGUID] = [ce].[GUID]
			INNER JOIN [ch000] [ch] ON [er].[ParentGUID] = [ch].[GUID]
		WHERE 
			([ch].[Date] BETWEEN @startDate AND @endDate)
			AND 
			([ch].[TypeGUID] = @ntGuid) 
			AND 
			([ch].[Security] = @sec)
			AND 
			([ce].[Security] <> @sec)

		EXEC prcEnableTriggers 'ce000'
	END
##########################################################
CREATE PROC prcCheckForUnReadMessages
	@UserGuid UNIQUEIDENTIFIER = 0x0,
	@ReadStatus INT = 0
AS 
	SET NOCOUNT ON 

	SELECT 
		COUNT(*) AS [MsgCount], 
		[ReciverGuid],
		[ReadStatus]
	FROM 
		[MsgDetail000] [Msg]
		INNER JOIN [us000] [us] ON [us].[GUID] = [Msg].[ReciverGuid]
	WHERE 
		[ReadStatus] = @ReadStatus
		And [ReciverGuid] = @UserGuid
	Group By
		[ReciverGuid],
		[ReadStatus]
##########################################################
CREATE PROC prcGetManufactureBillsType
	@StartDate DateTime,
	@EndDate DateTime
AS 
	SET NOCOUNT ON 

	SELECT 
		(SELECT 
			DISTINCT [buType] FROM vwBu 
		  WHERE 
		    [buGUID] IN(SELECT[BillGUID] FROM mb000 mb INNER JOIN mn000 mn ON mn.GUID = mb.ManGUID
		                 WHERE [mb].[Type] < 2 AND mn.Date between @StartDate AND @EndDate) 
		  AND[btIsInput] = 1) AS InputBill,
		(SELECT 
			DISTINCT[buType] FROM vwBu 
		 WHERE
		    [buGUID] IN(SELECT[BillGUID] FROM mb000 mb INNER JOIN mn000 mn ON mn.GUID = mb.ManGUID
		                 WHERE [mb].[Type] < 2 AND mn.Date between @StartDate AND @EndDate) 
		  AND[btIsOutput] = 1) AS OutputBill,
		(SELECT
			 DISTINCT[buType] FROM vwBu 
		 WHERE
		     [buGUID] IN(SELECT[BillGUID] FROM mb000 mb INNER JOIN mn000 mn ON mn.GUID = mb.ManGUID
		                  WHERE [mb].[Type] = 2 AND mn.Date between @StartDate AND @EndDate)) AS SemiConduct_OutputBill
##############################
#END
