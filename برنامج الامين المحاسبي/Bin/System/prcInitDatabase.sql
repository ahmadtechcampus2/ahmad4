#########################################################
CREATE PROC prcInitDatabase
AS
	SET XACT_ABORT OFF 
	IF OBJECT_ID( N'ErrorLog', N'U') IS NOT NULL
		DROP TABLE [ErrorLog]
	CREATE TABLE [dbo].[ErrorLog](
						[Type] [INT],
						[i1] [INT] DEFAULT 0,
						[c1] [NVARCHAR](400) COLLATE ARABIC_CI_AI DEFAULT '',
						[c2] [NVARCHAR](400) COLLATE ARABIC_CI_AI DEFAULT '',
						[f1] [FLOAT]  DEFAULT 0,
						[f2] [FLOAT]  DEFAULT 0,
						[g1] [UNIQUEIDENTIFIER] DEFAULT NULL,
						[g2] [UNIQUEIDENTIFIER] DEFAULT NULL,
						[level] [INT] NOT NULL DEFAULT 0,
						[spid] [INT] NOT NULL DEFAULT @@spid,
						[HostId] [NVARCHAR](128) COLLATE ARABIC_CI_AI NOT NULL DEFAULT HOST_ID(),
						[HostName] [NVARCHAR](255) COLLATE ARABIC_CI_AI NOT NULL DEFAULT HOST_NAME())

	CREATE TABLE #conns([SPID] [INT], [UserGUID] [UNIQUEIDENTIFIER], [Exclusive] [INT], 
						[HostId] [NVARCHAR](128) COLLATE ARABIC_CI_AI, [HostName] [NVARCHAR](255) COLLATE ARABIC_CI_AI)
	IF OBJECT_ID( N'Connections', N'U') IS NOT NULL
	BEGIN
		/*
		-----------------------------------------------------------
		-- Commented by Ali
		-- Not needed: upgrade is only done when in exclusive mode
		-----------------------------------------------------------
		-- Save connection info into temp #conns
		INSERT INTO #conns
		SELECT 
			[SPID],
			[UserGUID],
			[Exclusive], 
			CASE WHEN COLUMNPROPERTY( OBJECT_ID(N'[dbo].[Connections]'), 'HostId', 'ColumnId') IS NULL THEN HOST_ID() ELSE [HostId] END,
			CASE WHEN COLUMNPROPERTY( OBJECT_ID(N'[dbo].[Connections]'), 'HostName', 'ColumnId') IS NULL THEN HOST_NAME() ELSE [HostName] END
		FROM 
			Connections
		*/
			DROP TABLE Connections
	END 

	CREATE TABLE [dbo].[Connections](
		[SPID] [INT] NOT NULL DEFAULT @@SPID,
		[login_time] [datetime] NOT NULL DEFAULT GETDATE(),
		[UserGUID] [UNIQUEIDENTIFIER] NOT NULL,
		[Language] [INT] NOT NULL DEFAULT 0, -- 0 arabic, 1 english
		[Exclusive] [INT] NOT NULL DEFAULT 0,
		[Start] [DATETIME] NOT NULL DEFAULT GETDATE(),
		[BranchMask] [BIGINT] NOT NULL DEFAULT 0xFFFFFFFFFFFFFFFF,
		[UserNumber] [INT] NOT NULL DEFAULT 0,
		[HostId] [NVARCHAR](128) COLLATE ARABIC_CI_AI NOT NULL DEFAULT HOST_ID(),
		[HostName] [NVARCHAR](255) COLLATE ARABIC_CI_AI NOT NULL DEFAULT HOST_NAME(),
		[IgnoreWarnings] [BIT] NOT NULL DEFAULT 0
		PRIMARY KEY CLUSTERED 
		(
			[HostId], 
			[HostName]
		) ON [PRIMARY]
	)
	CREATE  INDEX [Conndx1] ON [Connections]([SPID]) ON [PRIMARY]
	CREATE  INDEX [Conndx2] ON [Connections]([UserNumber]) ON [PRIMARY]
		
	--Used By Smart Report Related Data
	IF TYPE_ID(N'KeysTable') IS NOT NULL
	BEGIN 
		EXECUTE [prcDropUserDefinedTypeDependencies] N'KeysTable'
		DROP TYPE KeysTable
	END	

	IF TYPE_ID(N'KeysTable') IS NULL
		CREATE TYPE KeysTable AS TABLE([Ordinal] [INT], [ID] [UNIQUEIDENTIFIER] NULL)
	-----------------------------------------
		
	/*
	-------------------------------------------
	-- Commented by Ali
	-- See my comments above
	-------------------------------------------
	INSERT INTO Connections([SPID], [UserGUID], [Exclusive], [HostId], [HostName])
	SELECT [SPID], [UserGUID], [Exclusive], [HostId], [HostName] FROM [#conns]
	*/
	IF OBJECT_ID( N'RepSrcs', N'U') IS NOT NULL
		DROP TABLE [RepSrcs]

	-- create report sources table:
	CREATE TABLE [dbo].[RepSrcs](
		[GUID] [UNIQUEIDENTIFIER] NOT NULL PRIMARY KEY DEFAULT NEWID(),
		[SPID] [INT] NOT NULL DEFAULT @@SPID,
		[IdTbl] [UNIQUEIDENTIFIER] NOT NULL,
		[IdType] [UNIQUEIDENTIFIER] NOT NULL,
		[IdSubType] [INT] NOT NULL DEFAULT 0,
		[StartNum] [INT] DEFAULT 0,
		[EndNum] [INT] DEFAULT 0,
		[CreateDate] [DATETIME] DEFAULT GETDATE(),
		[HostId] [NVARCHAR](128) COLLATE ARABIC_CI_AI NOT NULL DEFAULT HOST_ID(),
		[HostName] [NVARCHAR](255) COLLATE ARABIC_CI_AI NOT NULL DEFAULT HOST_NAME())

	IF OBJECT_ID( N'InsertedSn', N'U') IS NOT NULL
		DROP TABLE [InsertedSn]

	-- create Inserted Serial Number table To optimize searching Sn Bills:
	CREATE TABLE [dbo].[InsertedSn](
		[IdTbl] [uniqueidentifier] NOT NULL,
		[SN] [NVARCHAR](255) COLLATE Arabic_CI_AI NULL DEFAULT (''),
		[Number] [int] default 0 ,
		[CreatedDate] DATETIME DEFAULT GETDATE()
		
		PRIMARY KEY CLUSTERED 
		(
			[IdTbl],[Number]
		) ON [PRIMARY]
	) ON [PRIMARY]

	IF OBJECT_ID( N'TEMPSN', N'U') IS NOT NULL
		DROP TABLE [TEMPSN]
	--Creat Temporary Table for SN Cards And transe
	CREATE TABLE [dbo].[TEMPSN]
	(
		[ID] INT ,
		[Guid] UNIQUEIDENTIFIER,
		[SN] NVARCHAR(100) COLLATE Arabic_CI_AI,
		[MatGuid] UNIQUEIDENTIFIER,
		[stGuid] UNIQUEIDENTIFIER,
		[biGuid] UNIQUEIDENTIFIER
		 PRIMARY KEY  CLUSTERED 
		(
			[ID],[Guid],[biGuid]
		)  ON [PRIMARY]

	)ON [PRIMARY]	
	
	IF OBJECT_ID( N'dbcRepSrcs', N'U') IS NOT NULL
		DROP TABLE [dbcRepSrcs]
	CREATE TABLE [dbo].[dbcRepSrcs](
		[GUID] [UNIQUEIDENTIFIER] NOT NULL PRIMARY KEY DEFAULT NEWID(),
		[DBID] [INT] NOT NULL,
		[SPID] [INT] NOT NULL DEFAULT @@SPID,
		[IdTbl] [UNIQUEIDENTIFIER] NOT NULL,
		[IdType] [UNIQUEIDENTIFIER] NOT NULL,
		[IdSubType] [INT] NOT NULL DEFAULT 0,
		[StartNum] [INT] DEFAULT 0,
		[EndNum] [INT] DEFAULT 0,
		[CreateDate] [DATETIME] DEFAULT GETDATE(),
		[HostId] [NVARCHAR](128) COLLATE ARABIC_CI_AI NOT NULL DEFAULT HOST_ID(),
		[HostName] [NVARCHAR](255) COLLATE ARABIC_CI_AI NOT NULL DEFAULT HOST_NAME())

	-- create user extended infornation
	IF OBJECT_ID( N'usx', N'U') IS NULL
	BEGIN
		CREATE TABLE [dbo].[usx] (
			[guid] [UNIQUEIDENTIFIER] NOT NULL PRIMARY KEY,
			[bAdmin] [BIT],
			[maxDiscount] [FLOAT],
			[minPrice] [INT],
			[bActive] [BIT],
			[branchReadMask] [BIGINT],
			[branchWriteMask] [BIGINT],
			[maxPrice] [INT])
		CREATE  INDEX [usxndx1] ON [usx]([branchReadMask]) ON [PRIMARY]
		CREATE  INDEX [usxndx2] ON [usx]([branchWriteMask]) ON [PRIMARY]
	END
	
	IF OBJECT_ID( N'uix', N'U') IS NULL
	BEGIN
		CREATE TABLE [dbo].[uix] (
			[GUID]  [UNIQUEIDENTIFIER] ROWGUIDCOL NOT NULL DEFAULT NEWID(),
			[UserGUID] [UNIQUEIDENTIFIER] NULL ,
			[ReportID] [FLOAT] NULL DEFAULT 0,
			[SubID] [UNIQUEIDENTIFIER] NOT NULL DEFAULT 0x0,
			[System] [INT] NOT NULL DEFAULT 1,
			[PermType] [INT] NOT NULL DEFAULT 0,
			[Permission] [INT] NOT NULL DEFAULT 0
			PRIMARY KEY  CLUSTERED([GUID])  ON [PRIMARY])
		CREATE  INDEX [uixndx1] ON [uix]([UserGUID], [ReportID], [SubID], [PermType]) ON [PRIMARY]
	END

	-- create branches related tables:
	IF OBJECT_ID( N'brt', N'U') IS NULL
		CREATE TABLE [dbo].[brt] (
			[GUID] [UNIQUEIDENTIFIER] NOT NULL DEFAULT NEWID() PRIMARY KEY,
			[ClassName] [NVARCHAR](128) COLLATE ARABIC_CI_AI not null,
			[TableName] [NVARCHAR](128) COLLATE ARABIC_CI_AI NOT NULL,
			[ListingFunctionName] [NVARCHAR](128) COLLATE ARABIC_CI_AI NOT NULL DEFAULT '',
			[SingleBranch] [BIT] NOT NULL DEFAULT 0, -- when 0, table can relate to multiple branches, ie ac000. when 1 table has a BranchGUID field.
			[SingleBranchFldName] [NVARCHAR](128) COLLATE ARABIC_CI_AI NOT NULL DEFAULT 'Branch',
			[Name] [NVARCHAR](128) COLLATE ARABIC_CI_AI NOT NULL DEFAULT '',
			[LatinName] [NVARCHAR](128) COLLATE ARABIC_CI_AI NOT NULL DEFAULT '')
		-- create unique indexes on ID and TableName
	
	ELSE IF NOT EXISTS(select top 1 * from [syscolumns] where [name] = 'ClassName' and [id] = object_id('brt'))
		alter table [dbo].[brt] add [className] [NVARCHAR](128) COLLATE ARABIC_CI_AI not null default ''
	

	-- create items security related tables:
	IF OBJECT_ID( N'isrt', N'U')  IS NULL
		CREATE TABLE [dbo].[isrt] (
			[GUID] [UNIQUEIDENTIFIER] NOT NULL DEFAULT NEWID() PRIMARY KEY,
			[ClassName] [NVARCHAR](128) COLLATE ARABIC_CI_AI NOT NULL DEFAULT '',
			[TableName] [NVARCHAR](128) COLLATE ARABIC_CI_AI NOT NULL,
			[ListingFunctionName] [NVARCHAR](128) COLLATE ARABIC_CI_AI NOT NULL DEFAULT '',
			[Name] [NVARCHAR](128) COLLATE ARABIC_CI_AI NOT NULL DEFAULT '',
			[LatinName] [NVARCHAR](128) COLLATE ARABIC_CI_AI NOT NULL DEFAULT '',
			[ParentFldName] [NVARCHAR](128) COLLATE ARABIC_CI_AI NOT NULL DEFAULT '')

	-- create strigns table:
	IF OBJECT_ID( N'strings', N'U') IS NOT NULL
		Drop Table [strings]
	IF OBJECT_ID( N'strings', N'U') IS NULL
		CREATE TABLE [dbo].[strings] (
			[code] [NVARCHAR](128) COLLATE ARABIC_CI_AI NOT NULL PRIMARY KEY,
			[arabic] [NVARCHAR](256) COLLATE ARABIC_CI_AI NOT NULL,
			[english] [NVARCHAR](256) COLLATE Latin1_General_CI_AI NOT NULL DEFAULT '',
			[french] [NVARCHAR](256) COLLATE French_CI_AI NOT NULL DEFAULT ''
			)

	-- create database collections tables: used for reports that spans over multiple db files.
	IF OBJECT_ID( N'dbc', N'U') IS NULL
	BEGIN
		-- database collections
		CREATE TABLE [dbo].[dbc] (
			[GUID] [UNIQUEIDENTIFIER] NOT NULL DEFAULT NEWID() PRIMARY KEY, 
			[Name] [NVARCHAR](128) COLLATE ARABIC_CI_AI NOT NULL DEFAULT '',
			[LatinName] [NVARCHAR](128) NOT NULL DEFAULT '',
			[Description] [NVARCHAR](2000) COLLATE ARABIC_CI_AI NOT NULL DEFAULT '',
			[LatinDescription] [NVARCHAR](2000) COLLATE ARABIC_CI_AI NOT NULL DEFAULT '')
	
		-- database collections details
		CREATE TABLE [dbo].[dbcd] (
			[GUID]  [UNIQUEIDENTIFIER] ROWGUIDCOL  NOT NULL DEFAULT NEWID() PRIMARY KEY,
			[ParentGUID] [UNIQUEIDENTIFIER] NOT NULL ,
			[dbid] [INT] NOT NULL ,
			[order] [INT] NOT NULL DEFAULT 0,
			[ExcludeEntries] [BIT] NOT NULL DEFAULT 0,
			[ExcludeFPBills] [BIT] NOT NULL DEFAULT 0,
			CONSTRAINT [FK_dbcd_dbc] FOREIGN KEY ([ParentGUID]) REFERENCES dbc ([GUID]) ON DELETE CASCADE)

		-- database collections details
		CREATE TABLE [dbo].[dbcdd] (
			[ParentGUID] [UNIQUEIDENTIFIER] NOT NULL ,
			[EntryGUID] [UNIQUEIDENTIFIER] NOT NULL,
			PRIMARY KEY CLUSTERED([parentGUID], [entryGUID]),
			CONSTRAINT [FK_dbcdd_dbcd] FOREIGN KEY ([ParentGUID]) REFERENCES [dbcd] ([GUID]) ON DELETE CASCADE)
	END

	-- create excluded guids table: (used from dbcd)
	IF OBJECT_ID( N'ex', N'U') IS NULL
		CREATE TABLE [dbo].[ex] ([GUID] [UNIQUEIDENTIFIER] NOT NULL PRIMARY KEY)

	-- create CheckDBProc table:
	IF OBJECT_ID( N'checkDBProc', N'U') IS NOT NULL
		DROP TABLE [checkDBProc]

	CREATE TABLE [dbo].[checkDBProc] (
		[code] [NVARCHAR](128) COLLATE ARABIC_CI_AI NOT NULL PRIMARY KEY,
		[name] [NVARCHAR](128) COLLATE ARABIC_CI_AI NOT NULL,
		[description] [NVARCHAR](256) COLLATE ARABIC_CI_AI NOT NULL DEFAULT '',
		[latinName] [NVARCHAR](128) COLLATE ARABIC_CI_AI NOT NULL DEFAULT '',
		[latinDescription] [NVARCHAR](256) COLLATE ARABIC_CI_AI NOT NULL DEFAULT '',
		[procName] [NVARCHAR](128) COLLATE ARABIC_CI_AI NOT NULL,
		[Type] [INT] NOT NULL DEFAULT (0))

	EXECUTE [prcLog_Clear]
#########################################################
#END