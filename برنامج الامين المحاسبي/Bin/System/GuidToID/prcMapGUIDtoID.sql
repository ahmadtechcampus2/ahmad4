--------------------------------------------------------
USE master
GO
--------------------------------------------------------
-- *** Create database AmnDB_DataOnly
PRINT GETDATE()
PRINT 'AmnDB_DataOnly: Creating database and related objects'
IF NOT EXISTS( SELECT name FROM sys.databases WHERE name = 'AmnDB_DataOnly')
	CREATE DATABASE [AmnDB_DataOnly]
GO
--------------------------------------------------------
USE AmnDB_DataOnly
GO

--------------------------------------------------------
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'prcCreateSchema'))
	DROP PROCEDURE prcCreateSchema
GO
--------------------------------------------------------
-- *** Create Schema on AmnDB_DataOnly
CREATE PROCEDURE prcCreateSchema
	@SchemaName VARCHAR(128)
AS
	DECLARE @SQL VARCHAR(128)
	SET @SQL = 'CREATE SCHEMA [' + @SchemaName + ']'
	IF NOT EXISTS( SELECT name FROM sys.schemas WHERE name = @SchemaName)
		EXECUTE (@SQL)
		
GO
--------------------------------------------------------
PRINT GETDATE()
PRINT 'LogDB: Creating database and related objects'
IF EXISTS( SELECT name FROM sys.databases WHERE name = 'LogDB')
	DROP DATABASE [LogDB]
--------------------------------------------------------
-- *** Create database LogDB
CREATE DATABASE [LogDB]
GO
--------------------------------------------------------
USE [LogDB]
GO
--------------------------------------------------------
-- *** Create table PrintLog on LogDB
CREATE TABLE [dbo].[PrintLog](
	[id] [timestamp] NOT NULL,
	[Printed] [varchar](250) NULL,
	[LogTime] [datetime] NOT NULL,
	[SPID] [int] NOT NULL,
	[User] [varchar](128) NOT NULL,
	[ComputerName] [varchar](128) NOT NULL,
 CONSTRAINT [PK_PrintLog] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
--------------------------------------------------------
ALTER TABLE [dbo].[PrintLog] ADD  CONSTRAINT [DF_PrintLog_LogTime]  DEFAULT (getdate()) FOR [LogTime]
GO

ALTER TABLE [dbo].[PrintLog] ADD  CONSTRAINT [DF_PrintLog_SPID]  DEFAULT (@@spid) FOR [SPID]
GO

ALTER TABLE [dbo].[PrintLog] ADD  CONSTRAINT [DF_PrintLog_User]  DEFAULT (suser_sname()) FOR [User]
GO

ALTER TABLE [dbo].[PrintLog] ADD  CONSTRAINT [DF_PrintLog_ComputerName]  DEFAULT (host_name()) FOR [ComputerName]
GO

--------------------------------------------------------
-- *** Create view vwPrintLog on LogDB
CREATE VIEW [dbo].[vwPrintLog]
AS
	WITH pl AS
	(
		SELECT 
			ROW_NUMBER() OVER( ORDER BY id) AS number, 
			p1.* 
		FROM 
			PrintLog p1 
	)
	SELECT 
		p1.*, 
		p2.Printed AS p2Printed,
		ISNULL(p2.LogTime, GETDATE()) AS NextLogTime
	FROM 
		pl p1 LEFT JOIN pl p2 
		ON p1.Number+1 = p2.Number 
GO
--------------------------------------------------------
-- *** Create view vwPrintLogEx on LogDB
CREATE VIEW [dbo].[vwPrintLogEx]
AS
	SELECT 
		*,  
		DATEDIFF(	second, 
					LogTime,
					NextLogTime) AS Duration,
		CAST( DATEDIFF(	second, 
						LogTime,
						NextLogTime) / 60 AS VARCHAR) + ':' + 
		RIGHT( '00' + CAST( DATEDIFF(	second, 
						LogTime,
						NextLogTime) % 60 AS VARCHAR(2)), 2) AS Duration2
		
	FROM vwPrintLog

GO
--------------------------------------------------------
-- *** Create procedure prcPrint on LogDB
CREATE PROCEDURE [dbo].[prcPrint] @msg VARCHAR(250)
AS
	SET NOCOUNT ON
	DECLARE @PrintMsg VARCHAR(250)
	SET @PrintMsg = '> ' + CONVERT( VARCHAR(25), GETDATE(), 120) + ': ' + @msg
	INSERT INTO [dbo].PrintLog (Printed) VALUES( @msg)
	PRINT @PrintMsg
GO
--------------------------------------------------------
PRINT GETDATE()
PRINT 'LogDB: Created and ready now'
GO
--------------------------------------------------------
--EXECUTE [LogDB].[dbo].[prcPrint] 'Restoring database AmnDB004: Start'
--RESTORE DATABASE [AmnDB004] FROM  DISK = N'C:\TEMP\AmnDB004_Before_Upgrade.bak' WITH  FILE = 1,  NOUNLOAD,  REPLACE
--EXECUTE [LogDB].[dbo].[prcPrint] 'Restoring database AmnDB004: Done'
--GO
--USE [AmnDB004]
GO
--------------------------------------------------------
-- *** Restore backup  
--EXECUTE [LogDB].[dbo].[prcPrint] 'Restoring database AmnDB-Unisyria-ID: Start'
--RESTORE DATABASE [AmnDB-Unisyria-ID] FROM DISK = N'C:\Work\Archive\AmnData\Tue-HQ\HQ_MDA.DAT' WITH  FILE = 1,  NOUNLOAD,  REPLACE
--EXECUTE [LogDB].[dbo].[prcPrint] 'Restoring database AmnDB-Unisyria-ID: Done'
--USE [AmnDB-Unisyria-ID]
EXECUTE [LogDB].[dbo].[prcPrint] 'Restoring database _Empty : Start'

RESTORE DATABASE [AmnDb002_ID] 
FROM  DISK = N'D:\Ameen\DataBackUp\„” Êœ⁄«  523.dat' WITH  FILE = 1, 
 NOUNLOAD,  STATS = 10
GO
EXECUTE [LogDB].[dbo].[prcPrint] 'Restoring database [AmnDb002_ID]: Done'
GO
USE Amndb002_ID
GO 
--------------------------------------------------------
--EXECUTE [LogDB].[dbo].[prcPrint] 'Restoring database AmnDB_BHirfi: Start'
--RESTORE DATABASE [AmnDB_BHirfi] FROM DISK = N'C:\Work\Archive\AmnData\Bashar-Hirfi\f2011\ASUS-PC_AmnDb007_2011_4_1_11_26_35.dat' WITH  FILE = 1,  NOUNLOAD,  REPLACE
--EXECUTE [LogDB].[dbo].[prcPrint] 'Restoring database AmnDB_BHirfi: Done'
--GO
--USE [AmnDB_BHirfi]
--GO 
--------------------------------------------------------
IF [dbo].fnObjectExists('prcLog') <> 0
	DROP PROCEDURE prcLog
GO
--------------------------------------------------------
-- *** Create procedure prcLog on goal database
CREATE PROCEDURE [dbo].[prcLog] 
	@txt [varchar](8000) = '',  
	@param0 [varchar](128) = null,  
	@param1 [varchar](128) = null,  
	@param2 [varchar](128) = null,  
	@param3 [varchar](128) = null,  
	@param4 [varchar](128) = null,  
	@param5 [varchar](128) = null,  
	@param6 [varchar](128) = null, 
	@param7 [varchar](128) = null, 
	@param8 [varchar](128) = null, 
	@param9 [varchar](128) = null 
AS  
	SET NOCOUNT ON 
	set @txt = [dbo].[fnFormatString] (@txt, @param0, @param1, @param2, @param3, @param4, @param5, @param6, @param7, @param8, @param9) 
	DECLARE @text AS [VARCHAR](8000) 
	SET @text = REPLICATE( '.', @@NESTLEVEL) 
	SET @text = @text + LEFT(@txt, 8000) 
	EXECUTE [LogDB].[dbo].[prcPrint] @text
		 
GO
--------------------------------------------------------
IF [dbo].fnObjectExists('prcReportDuration') <> 0
	DROP PROCEDURE prcReportDuration
GO
--------------------------------------------------------
-- *** Create procedure prcReportDuration on goal database
CREATE PROCEDURE [dbo].[prcReportDuration]
	@Msg VARCHAR(100),
	@StartTime DATETIME
AS
	DECLARE @EndTime DATETIME = GETDATE()
	DECLARE @Duration INT = DATEDIFF( millisecond, @StartTime, @EndTime)
	DECLARE @m INT = @Duration / (60 * 1000)
	DECLARE @s INT = (@Duration - (@m * (60 * 1000))) / 1000
	DECLARE @ms INT = @Duration - ((@m * (60 * 1000)) + (@s * 1000))
	DECLARE @DurationString VARCHAR(200)
	SET @DurationString = 'Duration of: [' + @Msg + '] -> ' + 
		RIGHT( '00' + CAST( @m AS VARCHAR), 2) + ':' + 
		RIGHT( '00' + CAST( @s AS VARCHAR), 2) + ':' +
		RIGHT( '000' + CAST( @ms AS VARCHAR), 3)
	EXECUTE [prcLog] @DurationString	
GO
--------------------------------------------------------
IF [dbo].fnObjectExists('prcDropFldConstraints') <> 0
	DROP PROCEDURE prcDropFldConstraints
GO
--------------------------------------------------------
-- *** Create procedure prcDropFldConstraints on goal database
CREATE PROCEDURE [dbo].[prcDropFldConstraints] 
	@Table [VARCHAR](128), 
	@Column [VARCHAR](128) 
AS 
	DECLARE @DF AS [VARCHAR](128) 
	DECLARE @c CURSOR 
	DECLARE @SQL VARCHAR(250)
	 
	SET @SQL = 'prcDropFldConstraints: ' + @Table + '.' + @Column 
	EXECUTE [prcLog] @SQL 
	-- remove the Full Brackets if any: 
	SET @Column = REPLACE(REPLACE(@Column, ']', ''), '[', '') 
	-- Dropping defaults and constraints 
	SET @c = CURSOR FAST_FORWARD FOR  
		SELECT [obj].[name] 
		FROM  
			[SYSOBJECTS] [obj]  
			INNER JOIN [SYSCONSTRAINTS] [con] ON [obj].[id] = [con].[constid] 
			INNER JOIN [SYSCOLUMNS] [col] ON [col].[colid] = [con].[colid] AND [con].[id] = [col].[id]  
		WHERE  
			[obj].[parent_obj] = OBJECT_ID( @Table) AND [col].[NAME] = @Column 
	-- SELECT [name] FROM [sysobjects] WHERE COL_NAME( [parent_obj], [info]) = @Column AND [parent_obj] = OBJECT_ID(@Table) 
	OPEN @c FETCH FROM @c INTO @DF 
	WHILE @@FETCH_STATUS = 0 
	BEGIN 
		SET @SQL = 'ALTER TABLE [dbo].[' + @Table + '] DROP CONSTRAINT ' + @DF
		EXECUTE prcExecuteSQL @SQL 
		FETCH FROM @c INTO @DF 
	END 
	-- Dropping indexes 
	SET @c = CURSOR FAST_FORWARD FOR  
	SELECT [name] FROM sysindexes AS i INNER JOIN sysindexkeys AS k ON i.id = k.id AND i.indid = k.indid 
	WHERE OBJECT_ID( @Table) = i.id AND COL_NAME( k.id, k.colid) = @Column AND 
		  [name] NOT LIKE '_WA_Sys%' 
	OPEN @c FETCH FROM @c INTO @DF 
	WHILE @@FETCH_STATUS = 0 
	BEGIN 
		SET @SQL = 'DROP INDEX [dbo].[' + @Table + '].[' + @DF + ']'
		EXEC prcExecuteSQL @SQL
		FETCH FROM @c INTO @DF 
	END 
	CLOSE @c DEALLOCATE @c 
GO
----------------------------------------------------------------------------
IF dbo.fnObjectExists( 'prcExecuteSQL') <> 0
	DROP PROCEDURE prcExecuteSQL
GO
--------------------------------------------------------
-- *** Create procedure prcExecuteSQL on goal database
CREATE PROCEDURE [dbo].[prcExecuteSQL]  
	@sql [varchar](8000),  
	@param0 [varchar](2000) = null,  
	@param1 [varchar](2000) = null,  
	@param2 [varchar](2000) = null,  
	@param3 [varchar](2000) = null,  
	@param4 [varchar](2000) = null,  
	@param5 [varchar](2000) = null,  
	@param6 [varchar](2000) = null, 
	@param7 [varchar](2000) = null, 
	@param8 [varchar](2000) = null, 
	@param9 [varchar](2000) = null, 
	@caller [varchar](128) = null 
AS   
	SET NOCOUNT ON  
	 
	DECLARE 
		@nestLevel [int], 
		@logMsg [varchar](8000) 
	SET @nestLevel = @@nestLevel - 1 
	SET @sql = [dbo].[fnFormatString] (@sql, @param0, @param1, @param2, @param3, @param4, @param5, @param6, @param7, @param8, @param9)  
	SET @logMsg = 'prcExecutingSQL: ' + @sql 
	EXECUTE [prcLog] @logMsg 
	EXECUTE (@sql)	 
	RETURN @@error 
GO
--------------------------------------------------------
IF [dbo].fnObjectExists('prcAddFld') <> 0
	DROP PROCEDURE prcAddFld
GO
--------------------------------------------------------
-- *** Create procedure prcAddFld on goal database
CREATE PROCEDURE [dbo].[prcAddFld] 
	@Table [VARCHAR](128), 
	@Column [VARCHAR](128), 
	@Type [VARCHAR](128) 
AS 
	SET NOCOUNT ON 
	 
	DECLARE @Sql AS [VARCHAR](500) 
	SET @Sql =  'prcAddFld: ' + @table + '.' + @column + ' (' + @type + ')' 
	EXEC [prcLog] @Sql 
	-- assure that the table exists, and the column doesn't: 
	IF [dbo].[fnObjectExists](@Table + '.' + @Column) <> 0 --OR [dbo].[fnTblExists](@Table) = 0 
	BEGIN 
		EXEC [prcLog] '-Field Already Exists' 
		RETURN 0 
	END 
	SET @Sql = 'ALTER TABLE [' + @Table + '] ADD [' + @Column + '] ' + @Type 
	EXECUTE prcExecuteSQL  @Sql 
	EXEC [prcLog] '-Field Added' 
	RETURN 1 
GO
--------------------------------------------------------
IF [dbo].fnObjectExists('prcAddRecIDFld') <> 0
	DROP PROCEDURE prcAddRecIDFld
GO
--------------------------------------------------------
-- *** Create procedure prcAddRecIDFld on goal database
CREATE PROCEDURE [dbo].[prcAddRecIDFld] 
	@Table [VARCHAR](128), 
	@Column [VARCHAR](128) 
AS 
	SET NOCOUNT ON 
	 
	DECLARE @RetVal AS [INT] = 0
	IF [dbo].fnObjectExists ( '[' + @Table +'].[GUID]') <> 0
	BEGIN
		EXECUTE prcDropFldIndex @Table, 'GUID'
		EXECUTE prcDropFldConstraints @Table, 'GUID'
	END
	IF [dbo].fnObjectExists ( '[' + @Table +'].[' + @Column + ']') = 0
	BEGIN
		EXECUTE @RetVal = [prcAddFld] @Table, @Column, '[INT] NOT NULL IDENTITY (1, 1)' 
		DECLARE @PKString VARCHAR(100)
		SET @PKString = 'PK__' + @Table + '__1'
		EXECUTE prcExecuteSQL 'ALTER TABLE %0 ADD CONSTRAINT %1 PRIMARY KEY CLUSTERED ( %2 )', @Table, @PKString, @Column
	END
	RETURN @RetVal 
GO
-----------------------------------------------------------------------------------
IF [dbo].fnObjectExists('prcAddFKFld') <> 0
	DROP PROCEDURE prcAddFKFld
GO
-----------------------------------------------------------------------------------
-- *** Create procedure prcAddFKFld on goal database
CREATE PROCEDURE [dbo].[prcAddFKFld]
	@Table VARCHAR(128),
	@Fld VARCHAR(128),
	@Chk INT = 1
AS
	DECLARE 
		@Sql AS [VARCHAR](500), 
		@RetVal AS [INT] 
		 
	IF @Chk = 1
		SET @Sql = '[INT] NOT NULL DEFAULT 0' 
	ELSE
		SET @Sql = '[INT] NULL DEFAULT NULL' 
	EXECUTE @RetVal = [prcAddFld] @Table, @Fld, @Sql 
	RETURN @RetVal 
GO
-----------------------------------------------------------------------------------
IF [dbo].fnObjectExists('prcMapFK') <> 0
	DROP PROCEDURE prcMapFK
GO
-----------------------------------------------------------------------------------
--
-- Example:
--     EXECUTE prcMapFK 'bi000', 'MatGUID', 'MatID', '__ID', 'mt000', 'GUID', '__ID'
------------------------------------------------------------------------------------
-- *** Create procedure prcMapFK on goal database
CREATE PROCEDURE prcMapFK
	@DetailTable			[VARCHAR](128), -- 'bi000'
	@DetailFKGuidFld		[VARCHAR](128), -- 'MatGUID'
	@DetailFKIDFld			[VARCHAR](128), -- 'MatID'
	@MasterTable			[VARCHAR](128), -- 'mt000'
	@MasterFKGuidFld		[VARCHAR](128) = 'GUID',
	@Chk					INT,
	@Criteria				[VARCHAR](512) = NULL,
	@DropLookupFlds			[BIT] = 1,
	@PostScript				[VARCHAR](8000) = NULL
AS
	SET NOCOUNT ON
	DECLARE @StartTime DATETIME = GETDATE()
	EXECUTE prcLog '>> MapFK : %0.%1 [%2] -> %3.%4', @DetailTable, @DetailFKGuidFld, @DetailFKIDFld, @MasterTable, @MasterFKGuidFld
	DECLARE
		@SQL [VARCHAR](8000),
		@RetVal AS [INT],
		@FldCreated AS [INT]

	-- add IdFld:
	-- disable tables' triggers:
	EXECUTE [prcExecuteSQL] 'ALTER TABLE %0 DISABLE TRIGGER ALL', @DetailTable --bi000

	EXECUTE @RetVal = [prcAddRecIDFld] @DetailTable, '__ID'
	EXECUTE @RetVal = [prcAddRecIDFld] @MasterTable, '__ID'
	EXECUTE @FldCreated = prcAddFKFld @DetailTable, @DetailFKIDFld, @Chk -- bi000.MatID

	-- map:
	IF [dbo].[fnObjectExists](@DetailTable + '.' + @DetailFKGuidFld) <> 0  -- bi000.MatGUID
	BEGIN
		SET @SQL = 'UPDATE [' + @DetailTable + /*bi000*/'] SET [' + @DetailFKIDFld /*MatID*/
			+ '] = ISNULL([lu].[__ID], 0) FROM [' + @DetailTable /*bi000*/+ '] INNER JOIN ' + @MasterTable /*mt000*/+ ' AS [lu] ON ['
			+ @DetailTable /*bi000*/+ '].[' + @DetailFKGuidFld /*MatGUID*/+ '] = [lu].[' + @MasterFKGuidFld /*GUID*/+']'

		-- check for criteria:
		IF ISNULL(@Criteria, '') <> ''
			SET @SQL = @SQL + ' WHERE ' + @Criteria

		EXECUTE [prcExecuteSQL] @SQL
	END

	-- execute post-script, if any:
	IF @PostScript IS NOT NULL
		EXEC (@PostScript)

	-- drop old lookup fields:
	IF @DropLookupFlds <> 0
	BEGIN
		IF ISNULL(@DetailFKGuidFld, '') <> '' EXEC [prcDropFld] @DetailTable, @DetailFKGuidFld -- 'bi000', 'MatGUID'
	END

	IF @FldCreated <> 0
		BEGIN
		-- Create index 
		EXECUTE [prcExecuteSQL] 'CREATE NONCLUSTERED INDEX IDX_%0_%1__ ON [dbo].[%0] (%1)', @DetailTable, @DetailFKIDFld -- 'bi000', 'MatID'
		
		-- Create foreign key
		DECLARE @Check VARCHAR(20)
		IF @Chk = 0
			SET @Check = 'WITH NOCHECK'
		ELSE
			SET @Check = ''
			
		EXECUTE [prcExecuteSQL] 'ALTER TABLE [dbo].[%0] %3 ADD CONSTRAINT FK_%0_%2_%1_ID FOREIGN KEY ( [%2]) REFERENCES [dbo].[%1] ( [__ID]) ON UPDATE NO ACTION ON DELETE NO ACTION', 
		@DetailTable, @MasterTable, @DetailFKIDFld, @Check
	END
	
	-- enable table triggers:
	EXECUTE [prcExecuteSQL] 'ALTER TABLE %0 ENABLE TRIGGER ALL', @DetailTable --bi000

	SET @SQL = 'prcMapFK: ['+ @DetailTable +'].['+ @DetailFKIDFld +']'
	EXECUTE [prcReportDuration] @SQL, @StartTime
	RETURN 1
GO
-----------------------------------------------------------------------------------
IF [dbo].fnObjectExists('prcMapFK2') <> 0
	DROP PROCEDURE prcMapFK2
GO
-----------------------------------------------------------------------------------
--
-- Example:
--     EXECUTE prcMapFK2 'bi000', 'Mat', 'mt000'
------------------------------------------------------------------------------------
-- *** Create procedure prcMapFK2 on goal database
CREATE PROCEDURE prcMapFK2
	@Table					[VARCHAR](128), -- 'bi000'
	@OldFld					[VARCHAR](128), -- 'Mat'
	@LookupTable			[VARCHAR](128), -- 'mt000'
	@Chk					INT
AS
	SET NOCOUNT ON
	DECLARE @OldGUIDFld VARCHAR(128) = @OldFld + 'GUID'
	DECLARE @NewIDFld VARCHAR(128) = @OldFld + 'ID'
	EXECUTE prcMapFK @Table, @OldGUIDFld, @NewIDFld, @LookupTable, DEFAULT, @Chk
GO
------------------------------------------------------------------------------------
IF [dbo].fnObjectExists('prcCopyTableContent') <> 0
	DROP PROCEDURE prcCopyTableContent 
GO
------------------------------------------------------------------------------------
-- *** Create procedure prcCopyTableContent on goal database
CREATE PROCEDURE prcCopyTableContent 
	@Table VARCHAR(128),
	@Suffix VARCHAR(100)
AS
	DECLARE @DbName VARCHAR(128) = 'AmnDB_DataOnly'
	DECLARE @Schema VARCHAR(128)
	SET @Schema = DB_NAME()
	EXECUTE [AmnDB_DataOnly].[dbo].[prcCreateSchema] @Schema
	EXECUTE prcExecuteSQL '
		IF  EXISTS (SELECT * FROM [%0].sys.objects WHERE object_id = OBJECT_ID(N''[%0].[%1].[%2-%3]''))
			DROP TABLE [%0].[%1].[%2-%3]', @DbName, @Schema, @Table, @Suffix
	EXECUTE prcExecuteSQL 'SELECT * INTO [%0].[%1].[%2-%3] FROM [%2]', @DbName, @Schema, @Table, @Suffix
	RETURN
GO
------------------------------------------------------------------------------------
IF [dbo].fnObjectExists('prcMoveTablesTo') <> 0
	DROP PROCEDURE prcMoveTablesTo
GO
------------------------------------------------------------------------------------
-- *** Create procedure prcMoveTablesTo on goal database
CREATE PROCEDURE prcMoveTablesTo 
	@Suffix VARCHAR(100)
AS
	EXECUTE prcLog 'prcMoveTablesTo: %0', @Suffix
	DECLARE @DbName VARCHAR(128) = 'AmnDB_DataOnly'
	IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = @DbName)
		EXECUTE prcExecuteSQL 'CREATE DATABASE [%0]', @DbName
	EXECUTE prcCopyTableContent 'bi000', @Suffix
	EXECUTE prcCopyTableContent 'bu000', @Suffix
	EXECUTE prcCopyTableContent 'ac000', @Suffix
	EXECUTE prcCopyTableContent 'en000', @Suffix
	EXECUTE prcCopyTableContent 'ce000', @Suffix
	EXECUTE prcCopyTableContent 'gr000', @Suffix
	EXECUTE prcCopyTableContent 'mt000', @Suffix
	EXECUTE prcCopyTableContent 'er000', @Suffix
	EXECUTE prcCopyTableContent 'lg000', @Suffix
	EXECUTE prcCopyTableContent 'cp000', @Suffix
	RETURN
GO
------------------------------------------------------------------------------------
IF [dbo].fnObjectExists('fnGetFk_OLD') <> 0
	DROP FUNCTION fnGetFK_OLD
GO
------------------------------------------------------------------------------------
-- *** Create FUNCTION fnGetFk_OLD on goal database
CREATE FUNCTION fnGetFk_OLD (@FK_Prefix VARCHAR(120))
RETURNS VARCHAR(128)
AS
BEGIN
	RETURN  @FK_Prefix + 'GUID'
END	

GO
------------------------------------------------------------------------------------
IF [dbo].fnObjectExists('fnGetFk_New') <> 0
	DROP FUNCTION fnGetFk_New
GO
------------------------------------------------------------------------------------
-- *** Create FUNCTION fnGetFk_New on goal database
CREATE FUNCTION fnGetFk_New(@FK_Prefix VARCHAR(120))
RETURNS VARCHAR(128)
AS
BEGIN
	RETURN  @FK_Prefix + 'ID'
END	
GO

------------------------------------------------------------------------------------
IF [dbo].fnObjectExists('prcPrepareMapTable') <> 0
	DROP PROCEDURE prcPrepareMapTable
GO
------------------------------------------------------------------------------------
-- *** Create procedure prcPrepareMapTable on goal database
CREATE PROCEDURE prcPrepareMapTable
AS
	IF dbo.fnObjectExists(N'upMapTable') <> 0
		DROP TABLE upMapTable
	
	CREATE TABLE upMapTable
	(
		ID					INT NOT NULL IDENTITY( 1, 1),

		DetailTbl			VARCHAR(128) NOT NULL,
		FK_OLD				VARCHAR(128) NOT NULL,
		FK_NEW				VARCHAR(128) NOT NULL,
		Drop_FK_OLD			BIT DEFAULT 1,
		
		MasterTbl			VARCHAR(128) NOT NULL,
		PK_OLD				VARCHAR(128) NOT NULL DEFAULT 'GUID',
		PK_NEW				VARCHAR(128) NOT NULL DEFAULT '__ID',

		CheckInt			INT NOT NULL,
		Criteria			[VARCHAR](512) DEFAULT NULL
	)
	
	-- bi000 table
	INSERT INTO upMapTable 
	(
		DetailTbl, FK_OLD, FK_NEW, MasterTbl, CheckInt
	)
	VALUES
	('bi000', dbo.fnGetFK_OLD('Mat'), dbo.fnGetFK_NEW('Mat'), 'mt000', 1)
	,('bi000', 'ParentGUID', 'BuID', 'bu000', 1)
	,('bi000', dbo.fnGetFK_OLD('Currency'), dbo.fnGetFK_NEW('Currency'), 'my000',1)
	,('bi000', dbo.fnGetFK_OLD('Store'), dbo.fnGetFK_NEW('Store'), 'st000', 1)
	,('bi000', dbo.fnGetFK_OLD('Cost'), dbo.fnGetFK_NEW('Cost'), 'Co000', 0)
	,('bi000', dbo.fnGetFK_OLD('SO'), dbo.fnGetFK_NEW('SO'), 'sm000', 0)
	
	-- bu000 table
	INSERT INTO upMapTable 
	(
		DetailTbl, FK_OLD, FK_NEW, MasterTbl, CheckInt
	)
	VALUES
	('bu000', dbo.fnGetFK_OLD('Type'), dbo.fnGetFK_NEW('Type'), 'bt000', 1)
	,('bu000', dbo.fnGetFK_OLD('Cust'), dbo.fnGetFK_NEW('Cust'), 'cu000' ,0)
	,('bu000', dbo.fnGetFK_OLD('Currency'), dbo.fnGetFK_NEW('Currency'), 'my000', 1)
	,('bu000', dbo.fnGetFK_OLD('Store'), dbo.fnGetFK_NEW('Store'), 'st000', 1)
	,('bu000', dbo.fnGetFK_OLD('Cost'), dbo.fnGetFK_NEW('Cost'), 'co000', 0)
	,('bu000', dbo.fnGetFK_OLD('User'), dbo.fnGetFK_NEW('User'), 'us000', 0) --??? should be 1
	,('bu000', dbo.fnGetFK_OLD('CustAcc'), dbo.fnGetFK_NEW('CustAcc'), 'ac000', 0) -- ??? should be 1 
	,('bu000', dbo.fnGetFK_OLD('MatAcc'), dbo.fnGetFK_NEW('MatAcc'), 'ac000', 0)
	,('bu000', dbo.fnGetFK_OLD('ItemsDiscAcc'), dbo.fnGetFK_NEW('ItemsDiscAcc'), 'ac000', 0)
	,('bu000', dbo.fnGetFK_OLD('BonusDiscAcc'), dbo.fnGetFK_NEW('BonusDiscAcc'), 'ac000', 0)
	,('bu000', dbo.fnGetFK_OLD('FPayAcc'), dbo.fnGetFK_NEW('FPayAcc'), 'ac000', 0)
	,('bu000', dbo.fnGetFK_OLD('CheckType'), dbo.fnGetFK_NEW('CheckType'), 'nt000', 0)
	,('bu000', dbo.fnGetFK_OLD('ItemsExtraAcc'), dbo.fnGetFK_NEW('ItemsExtraAcc'), 'ac000', 0)
	,('bu000', dbo.fnGetFK_OLD('CostAcc'), dbo.fnGetFK_NEW('CostAcc'), 'ac000', 0)
	,('bu000', dbo.fnGetFK_OLD('StockAcc'), dbo.fnGetFK_NEW('StockAcc'), 'ac000', 0)
	,('bu000', dbo.fnGetFK_OLD('VATAcc'), dbo.fnGetFK_NEW('VATAcc'), 'ac000', 0)
	,('bu000', dbo.fnGetFK_OLD('BonusAcc'), dbo.fnGetFK_NEW('BonusAcc'), 'ac000', 0)
	,('bu000', dbo.fnGetFK_OLD('BonusContraAcc'), dbo.fnGetFK_NEW('BonusContraAcc'), 'ac000', 0)
	
	-- ac000 table
	INSERT INTO upMapTable 
	(
		DetailTbl, FK_OLD, FK_NEW, MasterTbl, CheckInt
	)
	VALUES
	('ac000', dbo.fnGetFK_OLD('Parent'), dbo.fnGetFK_NEW('Parent'), 'ac000', 0)
	,('ac000', dbo.fnGetFK_OLD('Final'), dbo.fnGetFK_NEW('Final'), 'ac000', 0)
	,('ac000', dbo.fnGetFK_OLD('Currency'), dbo.fnGetFK_NEW('Currency'), 'my000', 0) -- should be 1 for normal accounts
	,('ac000', dbo.fnGetFK_OLD('Branch'), dbo.fnGetFK_NEW('Branch'), 'br000', 0)
	
	-- en000 table
	INSERT INTO upMapTable 
	(
		DetailTbl, FK_OLD, FK_NEW, MasterTbl, CheckInt
	)
	VALUES
	('en000', 'ParentGUID', 'CeID', 'ce000', 1)
	,('en000', dbo.fnGetFK_OLD('Currency'), dbo.fnGetFK_NEW('Currency'), 'my000', 1)
	,('en000', dbo.fnGetFK_OLD('Account'), dbo.fnGetFK_NEW('Account'), 'ac000', 1)
	,('en000', dbo.fnGetFK_OLD('Cost'), dbo.fnGetFK_NEW('Cost'), 'co000', 0)
	,('en000', dbo.fnGetFK_OLD('ContraAccount'), dbo.fnGetFK_NEW('ContraAccount'), 'ac000', 0)
	

	-- ce000 table
	INSERT INTO upMapTable 
	(
		DetailTbl, FK_OLD, FK_NEW, MasterTbl, CheckInt
	)
	VALUES
	('ce000', 'Branch', 'BranchID', 'br000', 0)
	,('ce000', dbo.fnGetFK_OLD('Currency'), dbo.fnGetFK_NEW('Currency'), 'my000', 1)
	
	-- gr000 table
	INSERT INTO upMapTable 
	(
		DetailTbl, FK_OLD, FK_NEW, MasterTbl, CheckInt
	)
	VALUES
	('gr000', dbo.fnGetFK_OLD('Parent'), dbo.fnGetFK_NEW('Parent'), 'gr000', 0)
	
	-- mt000 table
	INSERT INTO upMapTable 
	(
		DetailTbl, FK_OLD, FK_NEW, MasterTbl, CheckInt
	)
	VALUES
	('mt000', dbo.fnGetFK_OLD('Group'), dbo.fnGetFK_NEW('Group'), 'gr000', 1)
	,('mt000', dbo.fnGetFK_OLD('Picture'), dbo.fnGetFK_NEW('Picture'), 'bm000', 0)
	,('mt000', dbo.fnGetFK_OLD('Currency'), dbo.fnGetFK_NEW('Currency'), 'my000', 1)
	,('mt000', dbo.fnGetFK_OLD('Old'), dbo.fnGetFK_NEW('Old'), 'mt000', 0) -- oldguid
	,('mt000', dbo.fnGetFK_OLD('New'), dbo.fnGetFK_NEW('New'), 'mt000', 0) -- newguid
	
	-- er000 table
	INSERT INTO upMapTable 
	(
		DetailTbl, FK_OLD, FK_NEW, MasterTbl, CheckInt, Criteria
	)
	VALUES
	('er000', dbo.fnGetFK_OLD('Entry'), dbo.fnGetFK_NEW('Entry'), 'ce000', 1, NULL)
	--('er000', dbo.fnGetFK_OLD('Parent'), dbo.fnGetFK_NEW('Parent'), 'bu000', 0, ),
	-- with out build foriegn key constraint
	
	-- lg000 table
	INSERT INTO upMapTable 
	(
		DetailTbl, FK_OLD, FK_NEW, MasterTbl, CheckInt
	)
	VALUES
	('lg000', dbo.fnGetFK_OLD('User'), dbo.fnGetFK_NEW('User'), 'us000', 1)
	--EXECUTE prcMapFK2 'lg000', 'Rec', '???ce000' 
	,('lg000', dbo.fnGetFK_OLD('Acc'), dbo.fnGetFK_NEW('Acc'), 'ac000', 0)
	,('lg000', dbo.fnGetFK_OLD('Cust'), dbo.fnGetFK_NEW('Cust'), 'cu000', 0)
	,('lg000', dbo.fnGetFK_OLD('Mat'), dbo.fnGetFK_NEW('Mat'), 'mt000', 0)
	,('lg000', dbo.fnGetFK_OLD('Grp'), dbo.fnGetFK_NEW('Grp'), 'gr000', 0)
	,('lg000', dbo.fnGetFK_OLD('Store'), dbo.fnGetFK_NEW('Store'), 'st000', 0)
	,('lg000', dbo.fnGetFK_OLD('Cost'), dbo.fnGetFK_NEW('Cost'), 'co000', 0)
	,('lg000', 'Branch', 'BranchID', 'br000', 0)
	----EXECUTE prcMapFK2 'lg000', 'Other', '???co000' 
	,('lg000', dbo.fnGetFK_OLD('Currency'), dbo.fnGetFK_NEW('Currency'), 'my000', 1)
	----EXECUTE prcMapFK2 'lg000', 'Sub', '???co000' 
	
	-- cp000 table
	INSERT INTO upMapTable 
	(
		DetailTbl, FK_OLD, FK_NEW, MasterTbl, CheckInt
	)
	VALUES
	('cp000', dbo.fnGetFK_OLD('Cust'), dbo.fnGetFK_NEW('Cust'), 'cu000', 0) -- ??? should be 1
	,('cp000', dbo.fnGetFK_OLD('Mat'), dbo.fnGetFK_NEW('Mat'), 'mt000', 0)
	,('cp000', dbo.fnGetFK_OLD('Currency'), dbo.fnGetFK_NEW('Currency'), 'my000', 0)-- ??? should be 1

GO
------------------------------------------------------------------------------------
DECLARE @Schema VARCHAR(128)
	SET @Schema = DB_NAME()
	
EXECUTE prcExecuteSQL '
	IF  EXISTS (SELECT * FROM [AmnDB_DataOnly].sys.objects 
	WHERE object_id = OBJECT_ID(N''[AmnDB_DataOnly].[%0].[PrintLog]''))
	DROP TABLE [AmnDB_DataOnly].[%0].[PrintLog]', @Schema
GO
	
------------------------------------------------------------------------------------
IF [dbo].fnObjectExists('prcUpgdateDBtoIDs') <> 0
	DROP PROCEDURE prcUpgdateDBtoIDs
GO
------------------------------------------------------------------------------------
-- *** Create procedure prcUpgdateDBtoIDs on goal database
CREATE PROCEDURE prcUpgdateDBtoIDs
AS
	-- *** Prepare the table list for upgrade	
	EXECUTE prcPrepareMapTable	

	EXECUTE prcMoveTablesTo '1'

	-- ** Update wrong values fields if needed 
	--   such as: random CurrencyGUID in ac000 if the account is collective
	--            account
	-- EXECUTE prcUpdateWrongValuesInFields

	-- ** Check integrity of foreign key in the database
	-- EXECUTE prcCheckMapTableIntegrity
	-- return if there are errors

	-- ** Add new ID foreign key field for each table
	-- EXECUTE prcAddNewIDFKFields

	-- ** Update new ID fields from old GUID fields
	-- EXECUTE prcMapFK Fields

	-- ** Delete old GUID foreign keys
	-- EXECUTE prcDeleteOldGUIDFKFields

	-- ** Finally if there is no errors delete temporary upgrade tables
	-- prcCleanUpAfterKFUpgarde
		
	DECLARE 
		@LastDetailTbl	VARCHAR(128)
		,@StartTime		DATETIME	
		,@DetailTbl		VARCHAR(128)
		,@FK_OLD		VARCHAR(128)
		,@FK_NEW		VARCHAR(128)
		,@Drop_FK_OLD	BIT 
		
		,@MasterTbl		VARCHAR(128)
		,@PK_OLD		VARCHAR(128)
		,@PK_NEW		VARCHAR(128)
		,@CheckInt		VARCHAR(128)
		,@Criteria		VARCHAR(512)

	SELECT 
		DetailTbl
		,FK_OLD
		,FK_NEW
		,Drop_FK_OLD
		,MasterTbl
		,PK_OLD
		,PK_NEW
		,CheckInt
		,Criteria	
	FROM upMapTable
	
	DECLARE mapping_cursor CURSOR FOR
	SELECT 
		DetailTbl
		,FK_OLD
		,FK_NEW
		,Drop_FK_OLD
		,MasterTbl
		,PK_OLD
		,PK_NEW
		,CheckInt
		,Criteria	

	FROM upMapTable
	ORDER BY [ID]

	OPEN mapping_cursor
	FETCH NEXT FROM mapping_cursor INTO 
		@DetailTbl
		,@FK_OLD
		,@FK_NEW
		,@Drop_FK_OLD
		,@MasterTbl
		,@PK_OLD
		,@PK_NEW
		,@CheckInt
		,@Criteria
		
	WHILE  @@FETCH_STATUS = 0
	BEGIN
	
		IF (@LastDetailTbl <> @DetailTbl OR @LastDetailTbl = '')
		BEGIN
			IF (@LastDetailTbl <> '')
			BEGIN
				DECLARE @string VARCHAR(200)
				SET @string = '>>>>>>>>>>> Upgrade ' + @LastDetailTbl
				EXECUTE [prcReportDuration] @string, @StartTime
			END
			
			SET @StartTime = GETDATE()
		END	

		SET @LastDetailTbl = @DetailTbl
		
		
		EXECUTE prcMapFK
					@DetailTbl, 
					@FK_OLD, 
					@FK_NEW, 
					@MasterTbl, 
					@PK_OLD, 
					@CheckInt, 
					@Criteria, 
					@Drop_FK_OLD, 
					NULL -- post script
		
		FETCH NEXT FROM mapping_cursor INTO
			@DetailTbl
			,@FK_OLD
			,@FK_NEW
			,@Drop_FK_OLD
			,@MasterTbl
			,@PK_OLD
			,@PK_NEW
			,@CheckInt
			,@Criteria
	END

	CLOSE mapping_cursor
	DEALLOCATE mapping_cursor
	
	EXECUTE prcLog 'Finished'
	
	EXECUTE prcMoveTablesTo '2' 
	
	SELECT * from [LogDB].[dbo].[vwPrintLogEx] WHERE printed like '%Duration%'
	SELECT * from [LogDB].[dbo].[vwPrintLogEx] WHERE printed like '%Upgrade%'

	DECLARE @SQL VARCHAR(200)
	SET @SQL = 'SELECT * INTO [AmnDB_DataOnly].[' + DB_NAME() + '].[PrintLog] FROM [LogDB].[dbo].[PrintLog]'
	EXECUTE (@SQL) -- NOT prcExecuteSQL
GO
------------------------------------------------------------------------------------
-- *** Execute upgrade procedure on goal database
EXECUTE prcUpgdateDBtoIDs
