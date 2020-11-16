#include upgrade_core.sql

#########################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002011
AS
	DECLARE @RetVal [INT]
	
	EXECUTE @RetVal = [prcAddGUIDFld] 'mn000', 'BranchGUID'
	IF @RetVal = 0
		RETURN
	
	EXECUTE [prcAddBitFld] 'bt000', 'bMergeCustItems'
	EXECUTE [prcAddBitFld] 'bt000', 'bMergeDiscItems'
	EXECUTE [prcAddBitFld] 'bt000', 'bMergeMatItems' 
	

	EXECUTE [prcAlterFld] 'mc0000', 'Asc3', 'VARCHAR (4000) COLLATE ARABIC_CI_AI', 0, ''''''
	EXECUTE [prcDropTrigger] 'trg_ac000_Order'
	
	EXECUTE [prcExecuteSQL] 
		'UPDATE [bt000] SET [bMergeCustItems] = %0, [bMergeDiscItems] = %0, [bMergeMatItems] = %0',
		[dbo.fnOption_GetBit('AmnCfg_ShortEntries', 0)]
		
#########################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002015
AS
	EXECUTE [prcDropProcedure] 'prcRepost_ce' -- renamed to prcEntry_RePost
	EXECUTE [prcDropProcedure] 'prcRepost_bu' -- renamed to prcBill_RePost
	EXECUTE [prcDropProcedure] 'prcReprice_bu' -- renamed to prcBill_RePrice

#########################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002024
AS
	DECLARE @RetVal [INT]

	EXECUTE @RetVal = [prcAddBitFld] 'bt000', 'bMergeDiscInCust'

	IF @RetVal = 0
		RETURN

	EXECUTE ('UPDATE [bt000] SET [bMergeDiscInCust] = 0')

#########################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002031
AS
	DECLARE @RetVal [INT]
	
	-- bt000
	EXECUTE [prcDropFld] 'bt000', 'bMergeCustItems'
	EXECUTE [prcDropFld] 'bt000', 'bMergeDiscItems'
	EXECUTE [prcDropFld] 'bt000', 'bMergeMatItems'
	EXECUTE [prcDropFld] 'bt000', 'bMergeDiscInCust'
	EXECUTE [prcAddBitFld] 'bt000', 'bShortEntry'
	EXECUTE [prcAddBitFld] 'bt000', 'bPayTerms'

	-- pg000:
	-- EXECUTE prcLog 'Upgrading pg000'
	-- EXECUTE prcAddLookupGUIDFld 'pg000', 'PictureGUID', 'Picture', DEFAULT, 'bm000'

	-- pk000:
	-- EXECUTE prcLog 'Upgrading pk000'
	-- EXECUTE prcAddLookupGUIDFld 'pk000', 'PictureGUID', 'Picture', DEFAULT, 'bm000'

	-- mt000
	EXECUTE @RetVal = [prcAddIntFld] 'mt000', 'DefUnit'
	IF @RetVal = 0
		RETURN
		
	EXECUTE ('UPDATE [mt000] SET [DefUnit] = ISNULL( ([Flag] / 256) + 1, 0), [Flag] = CAST([Flag] AS [INT]) & 255')

#########################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002038
AS
	EXECUTE [prcRenameFld] 'ma000', 'matGUID', 'objGUID'
	
#########################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002048
AS
	DECLARE @RetVal [INT]
	
	EXECUTE [prcAddIntFld] 'er000', 'ParentNumber'
	EXECUTE @RetVal = [prcAddGUIDFld] 'ce000', 'TypeGUID'
	IF @RetVal = 0
		RETURN

	EXEC('
		UPDATE [er000] SET [parentNumber] = [x].[Number] FROM [er000] AS [e] INNER JOIN [bu000] AS [x] ON [e].[parentGUID] = [x].[GUID]
		UPDATE [er000] SET [parentNumber] = [x].[Number] FROM [er000] AS [e] INNER JOIN [ch000] AS [x] ON [e].[parentGUID] = [x].[GUID]
		UPDATE [er000] SET [parentNumber] = [x].[Number] FROM [er000] AS [e] INNER JOIN [py000] AS [x] ON [e].[parentGUID] = [x].[GUID]

		ALTER TABLE [ce000] DISABLE TRIGGER ALL
		UPDATE [ce000] SET [typeGUID] = ISNULL([x].[typeGUID], 0x0) FROM [ce000] AS [c] INNER JOIN [er000] AS [e] ON [c].[GUID] = [e].[entryGUID] INNER JOIN [bu000] AS [x] ON [e].[parentGUID] = [x].[GUID]
		UPDATE [ce000] SET [typeGUID] = ISNULL([x].[typeGUID], 0x0) FROM [ce000] AS [c] INNER JOIN [er000] AS [e] ON [c].[GUID] = [e].[entryGUID] INNER JOIN [ch000] AS [x] ON [e].[parentGUID] = [x].[GUID]
		UPDATE [ce000] SET [typeGUID] = ISNULL([x].[typeGUID], 0x0) FROM [ce000] AS [c] INNER JOIN [er000] AS [e] ON [c].[GUID] = [e].[entryGUID] INNER JOIN [py000] AS [x] ON [e].[parentGUID] = [x].[GUID]
		ALTER TABLE [ce000] ENABLE TRIGGER ALL')

#########################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002067
AS
	-- fix ma000 bug, where billType where missing
	ALTER TABLE [ac000] DISABLE TRIGGER ALL
	ALTER TABLE [ma000] DISABLE TRIGGER ALL

	DELETE [ma000]
		FROM [ma000] AS [m] LEFT JOIN [bt000] AS [b] ON [m].[BillTypeGUID] = [b].[GUID]
		WHERE [b].[GUID] iS NULL
	
#########################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002072
AS
	-- delete old assets files
	IF [dbo].[fnObjectExists]( 'as000.OutAccGUID') <> 0 OR [dbo].[fnObjectExists]( 'as000.OutAccPtr') <> 0
		EXEC( 'DROP TABLE [as000]')

	IF [dbo].[fnObjectExists]( 'ag000.OutAccGUID') <> 0 OR [dbo].[fnObjectExists]( 'ag000.OutAccPtr') <> 0
		EXEC( 'DROP TABLE [ag000]')

#########################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002073
AS
	-- delete old assets files
	IF [dbo].[fnObjectExists]( 'ax000.Num1') <> 0 
		EXEC( 'DROP TABLE [ax000]')

#########################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002076
AS
	EXECUTE [prcAddIntFld] 'dp000', 'EntryNum'
	EXECUTE [prcAddGUIDFld] 'bt000', 'DefCostGUID'
	EXECUTE [prcDropFld] 'dd000', 'Date'

#########################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002078
AS
	EXECUTE [prcDropTrigger] 'trg_mt000_delete_ma'
	EXECUTE [prcDropTrigger] 'trg_mt000_Asset_insert'
	EXECUTE [prcDropTrigger] 'trg_mt000_delete_ASSET'

#########################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002080
AS
	IF [dbo].[fnObjectExists]('dp000.branchGUID') = 0
		EXECUTE [prcDropFld] 'dp000', 'EntryNum'
	
	EXECUTE [prcAddGUIDFld] 'dp000', 'BranchGUID'
	EXECUTE [prcAddGUIDFld] 'dp000', 'CostGUID'
	EXECUTE [prcAddIntFld] 'dp000', 'EntryNum'
	
	EXECUTE [prcAddFloatFld] 'dd000', 'Percent'
	EXECUTE [prcAddFloatFld] 'dd000', 'AddedVal'
	EXECUTE [prcAddFloatFld] 'dd000', 'DeductVal'
	EXECUTE [prcAddFloatFld] 'dd000', 'TotalDep'
	EXECUTE [prcAddFloatFld] 'dd000', 'CurrAssVal'
	EXECUTE [prcAddFloatFld] 'dd000', 'ReCalcVal'
	EXECUTE [prcAddDateFld] 'dd000', 'FromDate'

	
#########################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002083
AS
	EXECUTE [prcAddBitFld] 'dbcd', 'ExcludeEntries'
	EXECUTE [prcAddCharFld]	'dbcd', 'ExcludedEntriesNumbers', 2000
	EXECUTE [prcAddBitFld] 'dbcd', 'ExcludeFPBills'

#########################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002087
AS
/*
this procedure:
	- re-creates dbcd and dbcdd in order to fix column and primary key and forign key problem
	- has an ordering, where deletion of child is prior of parent, while creation of parent is prior of child
*/

	-- remove child
	IF EXISTS(SELECT * FROM [INFORMATION_SCHEMA].[TABLES] WHERE [TABLE_NAME] = 'dbcdd' AND [TABLE_TYPE] = 'BASE TABLE')
		DROP TABLE [dbcdd]

	-- remove parent
	IF EXISTS(SELECT * FROM [INFORMATION_SCHEMA].[TABLES] WHERE [TABLE_NAME] = 'dbcd' AND [TABLE_TYPE] = 'BASE TABLE')
		DROP TABLE [dbcd]

	-- create parent
	CREATE TABLE [dbo].[dbcd] (
		[GUID]  [UNIQUEIDENTIFIER] ROWGUIDCOL  NOT NULL DEFAULT NEWID() PRIMARY KEY,
		[ParentGUID] [UNIQUEIDENTIFIER] NOT NULL ,
		[dbid] [INT] NOT NULL ,
		[order] [INT] NOT NULL DEFAULT 0,
		[ExcludeEntries] [BIT] NOT NULL DEFAULT 0,
		[ExcludeFPBills] [BIT] NOT NULL DEFAULT 0,
		CONSTRAINT [FK_dbcd_dbc] FOREIGN KEY (ParentGUID) REFERENCES dbc ([GUID]) ON DELETE CASCADE)

	-- create child
	CREATE TABLE [dbo].[dbcdd] (
		[ParentGUID] [UNIQUEIDENTIFIER] NOT NULL ,
		[EntryGUID] [UNIQUEIDENTIFIER] NOT NULL,
		CONSTRAINT [FK_dbcdd_dbcd] FOREIGN KEY (ParentGUID) REFERENCES dbcd ([GUID]) ON DELETE CASCADE)

#########################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002090
AS
	EXECUTE [prcAddBitFld] 'bt000', 'bCostToCust'

#########################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002092
AS
	EXECUTE [prcAddBitFld] 'pl000', 'bExportSerialNum'
	EXECUTE [prcAddBitFld] 'pl000', 'bExportEmptyMaterial'

#########################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002093
AS
	EXECUTE [prcAddBitFld] 'bt000', 'bCostToCust'

#########################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002094
AS	
	EXECUTE [prcAddFloatFld] 'ad000', 'ScrapValue'

#########################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002098
AS
	EXECUTE [prcAddBitFld] 'nt000', 'bPayable', 1
	EXECUTE [prcAddBitFld] 'nt000', 'bReceivable', 1

#########################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002100
AS			
	-- can't use INFORMATION_SCHEMA on a database other than the current, so use 
	IF EXISTS (SELECT * FROM [amnconfig]..[sysobjects] WHERE [xtype] = 'U' AND [name] = 'gus')
		DROP TABLE [amnconfig]..[gus]

#########################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002101
AS		
	EXECUTE [prcAddIntFld] 'bt000', 'VATSystem', 1
	EXECUTE [prcAddBitFld] 'mt000', 'bHide'

#########################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002103
AS
	IF [dbo].[fnObjectExists]('bt000.VATSys') <> 0
		EXECUTE [prcRenameFld] 'bt000', 'VATSys', 'VATSystem'

#########################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002104
AS
	EXECUTE [prcAddGUIDFld] 'lg000', 'SubGUID'
	EXECUTE [prcAddIntFld] 'lg000', 'RecNum'
	EXECUTE [prcAddIntFld] 'lg000', 'OperationType'
	IF [dbo].[fnObjectExists]('bt000.VATSys') <> 0
		EXECUTE [prcRenameFld] 'bt000', 'VATSys', 'VATSystem'

#########################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002105
AS
	IF [dbo].[fnObjectExists]('bt000.VATSys') <> 0
		EXECUTE [prcRenameFld] 'bt000', 'VATSys', 'VATSystem'

	EXECUTE [prcDropTrigger] 'trg_bu000_general'		-- replaced with trg_bu000_useFlag
	EXECUTE [prcDropTrigger] 'trg_bu000_update'		-- replaced with trg_bu000_post
	EXECUTE [prcDropTrigger] 'trg_bt000_general'		-- replaced with trg_bt000_useFlag
	EXECUTE [prcDropTrigger] 'trg_ch000_general'		-- replaced with trg_ch000_useFlag
	EXECUTE [prcDropTrigger] 'trg_di000_general'		-- replaced with trg_di000_useFlag
	EXECUTE [prcDropTrigger] 'trg_ma000_general'	-- replaced with trg_ma000_useFlag
	EXECUTE [prcDropTrigger] 'trg_nt000_general'		-- replaced with trg_nt000_useFlag
	EXECUTE [prcDropTrigger] 'trg_as000_general'		-- replaced with trg_as000_useFlag
	EXECUTE [prcDropTrigger] 'trg_ce000_update'		-- replaced with trg_ce000_post
	EXECUTE [prcDropTrigger] 'trg_ci000_general'		-- replaced with trg_ci000_useFlag
	EXECUTE [prcDropTrigger] 'trg_cu000_general'		-- replaced with trg_cu000_useFlag
	EXECUTE [prcDropTrigger] 'trg_en000_general'		-- replaced with trg_en000_useFlag
	EXECUTE [prcDropTrigger] 'trg_et000_general'		-- replaced with trg_et000_useFlag
	EXECUTE [prcDropTrigger] 'trg_mn000_general'	-- replaced with trg_mn000_useFlag
	EXECUTE [prcDropTrigger] 'trg_py000_general'		-- replaced with trg_py000_useFlag
	EXECUTE [prcDropTrigger] 'trg_st000_general'		-- replaced with trg_st000_useFlag
	EXECUTE [prcDropTrigger] 'trg_vn000_general'		-- replaced with trg_vn000_useFlag
	EXECUTE [prcDropTrigger] 'trg_en000_general'		-- replaced with trg_en000_useFlag

	-- upgrade branches:
	-- upgrade tables:
	EXECUTE prcAddBigIntFld 'ac000', 'branchMask'
	EXECUTE prcAddBigIntFld 'my000', 'branchMask'
	EXECUTE prcAddBigIntFld 'st000', 'branchMask'
	EXECUTE prcAddBigIntFld 'co000', 'branchMask'
	EXECUTE prcAddBigIntFld 'bt000', 'branchMask'
	EXECUTE prcAddBigIntFld 'et000', 'branchMask'
	EXECUTE prcAddBigIntFld 'nt000', 'branchMask'
	EXECUTE prcAddBigIntFld 'gr000', 'branchMask'
	EXECUTE prcAddBigIntFld 'fm000', 'branchMask'
	EXECUTE prcAddBigIntFld 'mt000', 'branchMask'

	-- move data from bl to BRTs
	IF [dbo].[fnObjectExists]('bl000') <> 0
	BEGIN
		DECLARE
			@c CURSOR,
			@tableName [VARCHAR](128),
			@SQL [VARCHAR](2000)

		SET @c = CURSOR FAST_FORWARD FOR SELECT [tableName] FROM [brt] WHERE [SingleBranch] = 0

		OPEN @c FETCH FROM @c INTO @tableName
		WHILE @@FETCH_STATUS = 0
		BEGIN
			SET @SQL = '
				SET NOCOUNT ON
				
				ALTER TABLE %0 DISABLE TRIGGER ALL
				
				UPDATE %0 SET [branchMask] = 0
				
				DECLARE
					@c CURSOR,
					@guid [UNIQUEIDENTIFIER],
					@mask [BIGINT],
					@SQL [VARCHAR](2000)
				
				SET @c = CURSOR FAST_FORWARD FOR 
					SELECT [t].[GUID], [dbo].[fnPowerOf2]([br].[number])
					FROM [br000] AS [br] INNER JOIN [bl000] AS [bl] ON [br].[guid] = [bl].[branchguid] INNER JOIN %0 AS [t] ON [bl].[refGuid] = [t].[guid]
				
				OPEN @c FETCH FROM @c INTO @guid, @mask
				
				WHILE @@FETCH_STATUS = 0
				BEGIN
					UPDATE %0 SET [branchMask] = [branchMask] | @mask WHERE [GUID] = @guid
					FETCH FROM @c INTO @guid, @mask
				END
				
				CLOSE @c DEALLOCATE @c
				
				ALTER TABLE %0 ENABLE TRIGGER ALL'
		
			EXECUTE [prcExecuteSql] @SQL, @tableName
			FETCH FROM @c INTO @tableName
		END

		CLOSE @c DEALLOCATE @c
		DROP TABLE [bl000]
	END
	
	EXECUTE [prcDropFld] 'brt', 'Type'

	EXECUTE [prcDropFunction] 'fnGetDefaultBranch' -- replaced with fnBranch_getDefaultGUID
	
#########################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002106
AS
	-- drop old bl triggers:
	DECLARE
		@c CURSOR,
		@name [VARCHAR](128)

	SET @c = CURSOR FAST_FORWARD FOR SELECT [name] FROM [sysobjects] WHERE [name] LIKE '%bl' AND [xtype] = 'TR'

	OPEN @c FETCH FROM @c INTO @name

	WHILE @@FETCH_STATUS = 0
	BEGIN
		EXECUTE [prcDropTrigger] @name
		FETCH FROM @c INTO @name
	END

	CLOSE @c DEALLOCATE @c



#########################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002107
AS
	EXECUTE [prcAddGUIDFld] 'as000', 'ExpensesAccGUID'

#########################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002113
AS
	EXECUTE [prcDropTrigger] 'trg_as000_delete'
	EXECUTE [prcDropTrigger] 'trg_ac000_delete'
	
#########################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002115
AS
	EXECUTE [prcDropProcedure] 'prcBranch_OptimizeViews' -- it was renamed to prcBranch_Optimize
	
	EXECUTE [prcAddGUIDFld] 'as000', 'RevaluationAccGUID'
	EXECUTE [prcAddGUIDFld] 'as000', 'CapitalProfitAccGUID'
	EXECUTE [prcAddGUIDFld] 'as000', 'CapitalLossAccGUID'

#########################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002120
AS
	EXECUTE [prcAddIntFld] 'et000', 'FldCurEqu', -1

#########################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002123
AS
	EXECUTE [prcAddIntFld] 'et000', 'FldCurEqu', -1

#########################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002125
AS
	EXECUTE [prcDropFld] 'mn000', 'form'

  
#########################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002130
AS
	DECLARE @SQL AS [VARCHAR](500)
	DECLARE @RetVal AS [INT]
	EXECUTE @RetVal = [prcAddCharFld] 'br000', 'Prefix', 150
	IF @RetVal <> 0
	BEGIN
		SET @SQL = 'UPDATE [br000] SET [Prefix] = Code'
		EXECUTE [prcExecuteSql] @SQL
	END


#########################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002157
AS
	
	EXECUTE ('	
	update [brt] set [className] = ''Account'' where [tableName] = ''ac000''
	update [brt] set [className] = ''CostJob'' where [tableName] = ''co000''
	update [brt] set [className] = ''CostJob'' where [tableName] = ''co000''
	update [brt] set [className] = ''Material'' where [tableName] = ''mt000''
	update [brt] set [className] = ''Group'' where [tableName] = ''gr000''
	update [brt] set [className] = ''Store'' where [tableName] = ''st000''
	update [brt] set [className] = ''ManForm'' where [tableName] = ''fm000''
	update [brt] set [className] = ''BillTemplate'' where [tableName] = ''bt000''
	update [brt] set [className] = ''EntryTemplate'' where [tableName] = ''et000''
	update [brt] set [className] = ''NoteTemplate'' where [tableName] = ''nt000''
	update [brt] set [className] = ''Currency'' where [tableName] = ''my000''
	update [brt] set [className] = ''Bill'' where [tableName] = ''bu000''
	update [brt] set [className] = ''Entry'' where [tableName] = ''ce000''
	update [brt] set [className] = ''Note'' where [tableName] = ''ch000''
	update [brt] set [className] = ''Payment'' where [tableName] = ''py000''
	update [brt] set [className] = ''Order'' where [tableName] = ''or000''
	update [brt] set [className] = ''Manufac'' where [tableName] = ''mn000''')


#########################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002183
AS
	EXECUTE [prcAddBitFld] 'et000', 'ShowDiscGrid'
	EXECUTE [prcAddBitFld] 'et000', 'CostForBothAcc'

#########################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002201
AS
	EXECUTE [prcAddBitFld] 'tt000', 'ExtraBelongsToIn'
	EXECUTE [prcAddBitFld] 'tt000', 'ExtraBelongsToOut'
	EXECUTE [prcAddBitFld] 'tt000', 'DiscBelongsToIn'
	EXECUTE [prcAddBitFld] 'tt000', 'DiscBelongsToOut'

#########################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002229
AS
	EXECUTE [prcAddGUIDFld] 'hosPatient000', 'PersonGUID'
	EXECUTE [prcAddGUIDFld] 'hosFile000', 'AccGUID'
	EXECUTE [prcDropFld] 'hosEmployee000', 'AddToGUID'
	EXECUTE [prcAddIntFld] 'hosEmployee000', 'WorkNature'
	EXECUTE [prcAddGUIDFld] 'hosEmployee000', 'AccGUID'
	EXECUTE [prcAddGUIDFld] 'hosFile000', 'AccGUID'

#########################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002238
AS
	EXECUTE [prcAddFloatFld] 'hosGeneralTest000', 'Discount'
	EXECUTE [prcAddIntFld] 'hosGeneralTest000', 'Type'
	EXECUTE [prcAddGUIDFld] 'hosGeneralTest000', 'AccGUID'
	EXECUTE [prcAddGUIDFld] 'hosGeneralTest000', 'EntryGUID'
	EXECUTE [prcAddGUIDFld] 'hosGeneralTest000', 'FileGUID'
	EXECUTE [prcAddGUIDFld] 'hosGeneralTest000', 'OperationGUID'
	EXECUTE [prcAddCharFld] 'hosGeneralTest000', 'Result', 250
	EXECUTE [prcAddFloatFld] 'hosGeneralTest000', 'Cost'

	EXECUTE [prcDropFld] 'hosGeneralTest000', 'FldFileGUID'
	EXECUTE [prcDropFld] 'hosGeneralTest000', 'FldOperationGUID'
	EXECUTE [prcDropFld] 'hosGeneralTest000', 'GeneralTestResult'
	EXECUTE [prcDropFld] 'hosGeneralTest000', 'FldCost'

	EXECUTE [prcAddIntFld] 'hosGeneralTest000', 'Security'	
	EXECUTE [prcAddIntFld] 'hosGeneralTest000', 'Type'

#########################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002251
AS	
	EXECUTE [prcAddCharFld] 'hosSurgery000', 'Name', 250
	EXECUTE [prcAddGUIDFld] 'hosSurgery000', 'SiteGuid'	

#########################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002255
AS
	EXECUTE [prcAddGUIDFld] 'oi000', 'ItemBillType'

	EXECUTE [prcAlterFld] 'hosEmployee000', 'speciality', 'VARCHAR (100) COLLATE ARABIC_CI_AI', 0, ''''''
#########################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002265
AS

	EXECUTE [prcAddFloatFld] 'HosSurgery000', 'RoomCost'
	
	EXECUTE [prcAddCharFld] 'oi000', 'Notes', 250
	

#########################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002278
AS
	EXECUTE [prcAddGUIDFld] 'HosFSurgery000', 'PatientBillGuid'
	EXECUTE [prcAddGUIDFld] 'HosFSurgery000', 'SurgeryBillGuid'
	EXECUTE [prcAddGUIDFld] 'HosFSurgery000', 'RoomCostEntryGUID'
	EXECUTE [prcAddGUIDFld] 'HosFSurgery000', 'WorkersEntryGUID'

	EXECUTE [prcAddIntFld] 'HosSurgeryMat000', 'Type'

#########################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002282
AS

	EXECUTE [prcAddIntFld] 'hosDailyFollowing000', 'Type'
	EXECUTE [prcAddCharFld] 'ch000', 'Notes2', 250
	EXECUTE [prcAddCharFld] 'bu000', 'TextFld1', 150
	EXECUTE [prcAddCharFld] 'bu000', 'TextFld2', 150
	EXECUTE [prcAddCharFld] 'bu000', 'TextFld3', 150
	EXECUTE [prcAddCharFld] 'bu000', 'TextFld4', 150
	


#########################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002306
AS	
	-- remove an old trigger:
	EXEC [prcDropTrigger] 'trg_ac000_ChkDuplicateCode'

	EXEC [prcAddGUIDFld] 'hosPFile000', 'MedConsEntryGUID'
	EXEC [prcAddGUIDFld] 'hosCons000', 'FileGUID'
	EXEC [prcAddGUIDFld] 'hosCons000', 'DoctorGUID'
	EXEC [prcAddFloatFld] 'hosCons000', 'Cost'




#########################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002315
AS	

	EXECUTE [prcAddFloatFld] 'or000', 'Payment'
	EXECUTE [prcAddIntFld] 'or000', 'Version'
	EXECUTE [prcAddGUIDFld] 'or000', 'AccountGUID'	
	EXECUTE [prcAddFloatFld] 'or000', 'GroupTax'
	EXECUTE [prcAddGUIDFld] 'or000', 'currencyGuid'
	EXECUTE [prcAddFloatFld] 'or000', 'currencyVal'
	EXECUTE [prcAddGUIDFld] 'or000', 'otGuid'
	EXECUTE [prcAddBitFld] 'or000', 'GenNotes'
	EXECUTE [prcAddFloatFld] 'or000', 'Vat'
	EXECUTE [prcAddIntFld] 'or000', 'counter'	
	EXECUTE [prcAddFloatFld] 'or000', 'ItemDisc'	
	EXECUTE [prcAddIntFld] 'od000', 'security'

--====================================================================================
	--this upgrade is to put deptGuid instead of department in tables: tb000 and or000.
	--alse it updates op000

	-- study a case when an upgrade with SHIFT is in progress:
	if [dbo].[fnObjectExists]( 'tb000.department') = 0
		return -- no need to process any thing, just skip
		
	declare @sql [varchar](8000)
	
	EXECUTE [prcAddGUIDFld] 'tb000', 'departGuid'
	EXECUTE [prcAddGUIDFld] 'or000', 'departGuid'	

	set @sql = '

	declare
		@c cursor,
		@depName [varchar](255),
		@table [varchar](128),
		@field [varchar](128),
		@NewField [varchar](128),
		@g [UNIQUEIDENTIFIER],
		@num [int]

	-- fix op000:
	set @c = cursor fast_forward for 
				select distinct ''tb000'', ''departGuid'',''department'', [department] from [tb000] where [department] != ''''
				union -- don''t use ALL here, we wont distinct values from unions
				select distinct ''or000'', ''departGuid'',''department'', cast([department] as [varchar](50)) as [department] from [or000] where [department] != 0

	open @c fetch from @c into @table, @field, @NewField, @depName

	begin tran

	while @@fetch_status = 0
	begin
		set @g = (select top 1 [guid] from [od000] where [name] = @depName)
		if @g is null
		begin
			set @g = newid()
			set @num = isnull(@num, 0) + 1
			insert into [od000] ([number] , [guid], [code], [name], [latinName], [notes], [security])
				select @num, @g, @num, @depName, @depName, '''', 1
		end  

		EXECUTE [prcExecuteSql] ''update %0 set %1 = ''''{%3}'''' where %2 = ''''%4'''''', @table, @field, @NewField, @g, @depName
		fetch from @c into @table, @field, @NewField, @depName
	end	
	
	close @c deallocate @c

	-- update the new field in op000 table 
	UPDATE [op000] SET [value] = ''''
		WHERE [name] in (''amnPos_DepartmentName'', ''amnPos_DepartmentNum'')
	
	commit tran'

	EXECUTE (@sql)

	EXECUTE [prcDropFld] 'tb000', 'department'
	EXECUTE [prcDropFld] 'or000', 'department'

#########################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002316
AS	
	EXEC [prcAddFloatFld] 'or000', 'TotalRSales'
	EXEC [prcAddFloatFld] 'or000', 'ItemDiscRSales'

#########################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002337
AS	
	EXEC [prcAddGUIDFld] 'hosAnalysisOrderDetail000', 'ParentGUID'
	
#########################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002352
AS
	DECLARE @SQL AS [VARCHAR](1000)
	-- fix up wrong saved VAT in TTC system
	IF [dbo].[fnObjectExists]( 'et000.MenuName') <> 0
	BEGIN
		ALTER TABLE [bi000] DISABLE TRIGGER ALL
		EXECUTE [prcExecuteSQL] ' 
		UPDATE  
			[bi000]
		SET  
			[bi000].[VAT] = [bi000].[VAT] / (CASE [Qty] WHEN 0 THEN 1 ELSE [Qty] END)  
		FROM [bi000]
		INNER JOIN  
			[bu000] AS [bu] ON [bi000].[ParentGUID] = [bu].[GUID]
			INNER JOIN [bt000] AS [bt] ON 
				[bt].[GUID] = [bu].[TypeGUID]
		WHERE  
			[bt].[VATSystem] = 2 -- TTC 
		' 
		ALTER TABLE [bi000] DISABLE TRIGGER ALL
	END

	-- add MenuName to et000
	EXECUTE [prcAddCharFld] 'et000', 'MenuName', 150
	EXECUTE [prcAddCharFld] 'et000', 'MenuLatinName', 150
	
	-- add BonusAccGuid to bt000
	EXECUTE [prcAddGUIDFld] 'bt000', 'DefBonusAccGUID'

	-- add BonusAccGuid to ma000	
	EXECUTE [prcAddGUIDFld] 'ma000', 'BonusAccGUID'
#########################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002353
AS		
	-- add BonusAccGuid to bt000
	EXECUTE [prcAddGUIDFld] 'bt000', 'DefBonusContraAccGUID'
	EXECUTE [prcAddIntFld] 'bt000', 'DefBonusPrice', 0

	-- add BonusAccGuid to ma000	
	EXECUTE [prcAddGUIDFld] 'ma000', 'BonusContraAccGUID'
#########################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002356
AS		
	-- add BonusAccGuid to bt000
	EXECUTE [prcRenameFld] 'bt000', 'DefBonusContraAcc', 'DefBonusContraAccGUID'

#########################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002357
AS		
	EXECUTE [prcAddGUIDFld] 'hosanalysisOrderdetail000', 'MainAnalysis'
	EXECUTE [prcAddBitFld] 'hosanalysisOrderdetail000', 'State'
	
	EXECUTE [prcAddGUIDFld] 'hosRadioGraphyOrderdetail000', 'MainRadioGraphy'
	EXECUTE [prcAddBitFld] 'hosRadioGraphyOrderdetail000', 'State'

#########################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002368
AS
	EXECUTE [prcAddGUIDFld] 'hosAnalysisOrder000', 'PayGuid'
	EXECUTE [prcAddGUIDFld] 'hosRadioGraphyOrder000', 'PayGuid'
	EXECUTE [prcAddFloatFld] 'hosAnalysis000', 'ExternalPrice'


#########################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002369 
AS	
	EXECUTE [prcAddCharFld] 'pg000', 'ComputerName', 250

#########################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002376 
AS	
	EXECUTE [prcAddFloatFld] 'hosOperation000', 'Cost'
	EXECUTE [prcAddIntFld] 'hosOperation000', 'Type'
	EXECUTE [prcAddCharFld] 'hosOperation000', 'Notes', 250	
	EXECUTE [prcAddIntFld] 'hosOperation000', 'Security'
	
#########################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002378 
AS	
	EXECUTE [prcAddGUIDFld] 'HosSurgeryTimeCost000', 'TypeGuid'
	
	-- add special offer flds to bi000
	EXECUTE [prcAddIntFld] 'bi000', 'SOType'
	EXECUTE [prcAddGUIDFld] 'bi000', 'SOGuid'


#########################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002381
AS	
	EXECUTE [prcAddGUIDFld] 'hosFSurgery000', 'OperationGuid'

	DECLARE @result [int]

	EXECUTE @result = [prcAddIntFld] 'bu000', 'RecState'
	IF @result != 0
		EXECUTE ('
			BEGIN TRAN
			ALTER TABLE [bu000] DISABLE TRIGGER ALL
			UPDATE [bu000] SET [recState] = 1 WHERE [recState] = 0
			ALTER TABLE [bu000] ENABLE TRIGGER ALL
			commit tran')


#########################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002383
AS
	EXECUTE [prcAddGUIDFld] 'HosSurgeryTimeCost000', 'TypeGuid'
	EXECUTE [prcAddGUIDFld] 'HosPatient000', 'Kind'

#########################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002386
AS
	EXECUTE [prcDropFld] 'HosPatient000', 'Kind'
	EXECUTE [prcAddGUIDFld] 'hosFSurgery000', 'AnesthetistEntryGuid'
	EXECUTE [prcAddCharFld] 'HosPatient000', 'Kind', 250	

#########################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002391
AS
	if [dbo].[fnObjectExists]( 'bt000.MenuName') <> 0
	BEGIN
		EXECUTE [prcExecuteSQL] ' 
		ALTER TABLE [bi000] DISABLE TRIGGER ALL
		UPDATE [i] SET [vat] = [i].[vat] * [qty]
			FROM [bi000] [i] INNER JOIN [bu000] [u] 
				ON [i].[parentGuid] = [u].[guid] INNER JOIN [bt000] [t] ON 
				[u].[typeGuid] = [t].[guid]
			WHERE [t].[VatSystem] = 2 -- TTC
		ALTER TABLE [bi000] ENABLE TRIGGER ALL
		'
	END
		-- add MenuName to bt000
	EXECUTE [prcAddCharFld] 'bt000', 'MenuName', 150
	EXECUTE [prcAddCharFld] 'bt000', 'MenuLatinName', 150
#########################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002393
AS
		-- add MenuName to bt000
	EXECUTE [prcAddCharFld] 'bt000', 'MenuName', 150
	EXECUTE [prcAddCharFld] 'bt000', 'MenuLatinName', 150
#########################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002394
AS
	EXECUTE [prcAddDateFld] 'or000', 'OpeningTime'
	EXECUTE [prcAddDateFld] 'or000', 'ClosingTime'


#########################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002396
AS
	exec [prcDropProcedure] 'prcGetAnalysisTree'
	exec prcDropView 'vwAnalysis'

#########################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002400
AS	
	EXEC [prcDropFld] 'bt000', 'custAcc'	

#########################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002417
AS
	EXECUTE [prcAddIntFld] 'pk000', 'LinkOrder'
	EXECUTE [prcAddIntFld] 'or000', 'IsPrinted'
	EXECUTE [prcAddGUIDFld] 'ot000', 'InReadyAccGUID'
	EXECUTE [prcAddGUIDFld] 'ot000', 'OutRawAccGUID'
	EXECUTE [prcAddGUIDFld] 'HosRadioGraphyOrder000', 'PayGuid'
	EXECUTE [prcAddGUIDFld] 'HosRadioGraphyOrder000', 'DoctorGUID'
	EXECUTE [prcAddGUIDFld] 'ad000', 'billGuid'
	EXECUTE [prcAddIntFld] 'ad000', 'useFlag'

#########################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002421
AS
	DECLARE @result AS [int]
	EXECUTE [prcAddBitFld] 'nt000', 'bCanGenColEnt'
	EXECUTE [prcAddBitFld] 'nt000', 'bCanGenEndEnt'
	EXECUTE @result = [prcAddBitFld] 'nt000', 'bCanGenRetEnt'
	IF @result = 0
		RETURN
	
	ALTER TABLE [nt000]
	DISABLE TRIGGER ALL 
	EXECUTE ('
		UPDATE [nt000] 
		SET 
		[bCanGenColEnt] = ISNULL(([bAutoEntry] & [bCanCollect]), 1), 
		[bCanGenEndEnt] = ISNULL(([bAutoEntry] & [bCanEndorse]), 1), 
		[bCanGenRetEnt] = ISNULL(([bAutoEntry] & [bCanReturn]), 1)')

	ALTER TABLE [nt000]
	ENABLE TRIGGER ALL 
	


#########################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002424
AS
	EXECUTE [prcAddIntFld] 'HosRadioGraphyMats000', 'Type'
	EXECUTE [prcAddGUIDFld] 'HosRadioGraphyOrder000', 'BillGUID'

#########################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002429
AS
	EXECUTE [prcAddGUIDFld] 'mt000', 'OldGUID'
	EXECUTE [prcAddGUIDFld] 'mt000', 'NewGUID'
#########################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002432
AS
	EXECUTE [prcAddGUIDFld] 'pk000', 'ContraAccGUID'
	EXECUTE [prcAddIntFld] 'pk000', 'DefPrice'
	EXECUTE [prcAddIntFld] 'pk000', 'PayType'
	EXECUTE [prcAddGUIDFld] 'or000', 'ContraAccGUID'
	EXECUTE [prcAddIntFld] 'or000', 'DefPrice'
	EXECUTE [prcAddIntFld] 'or000', 'BillPayType'

	EXECUTE [prcAddGUIDFld] 'sm000', 'GroupGUID'
	EXECUTE [prcAddBitFld] 'sm000', 'bIncludeGroups'
	EXECUTE [prcAddIntFld] 'sm000', 'PriceType', 128
	EXECUTE [prcAddFloatFld] 'sm000', 'Discount'

	EXECUTE [prcAddIntFld] 'HosSiteStatus000', 'Type'
	EXECUTE [prcAddGUIDFld] 'HosReservation000', 'Status'
	EXECUTE [prcAddGUIDFld] 'HosRadioGraphyOrder000', 'StatusGUID'
	EXECUTE [prcAddGUIDFld] 'HosSite000', 'STATUS'

	Delete from [pk000] WHERE [keyCmd] = 297
	Delete from [pk000] WHERE [keyCmd] = 298
	Delete from [pk000] WHERE [keyCmd] = 218
#########################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002453
AS
	EXECUTE [prcAddIntFld] 'mt000', 'Assemble'
#########################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002441
AS
	EXECUTE [prcAddFloatFld] 'HosRadioGraphyOrderDetail000', 'Price'
	EXECUTE [prcAddFloatFld] 'HosRadioGraphyOrderDetail000', 'Discount'

	EXECUTE [prcAddFloatFld] 'hosConsumed000', 'Price'
	EXECUTE [prcAddFloatFld] 'hosConsumed000', 'Qty'
	EXECUTE [prcAddFloatFld] 'hosConsumed000', 'Discount'
	EXECUTE	[prcAddGUIDFld]  'HosPFile000', 'ConsumedBillGUID'
#########################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002448
AS
	EXECUTE [prcDropFld] 'oi000', 'CurrencyVal'
	EXECUTE [prcDropFld] 'oi000', 'CurrencyGuid'	
	-----------------------------------------------------------------	
	EXECUTE [prcAddIntFld] 'oi000', 'soType'
	EXECUTE [prcAddGUIDFld] 'oi000', 'soGuid'
	-----------------------------------------------------------------
	EXECUTE [prcAddIntFld] 'ot000', 'SystemType'
	EXECUTE [prcAddGUIDFld] 'ot000', 'DrawerAccGuid'
	EXECUTE [prcAddGUIDFld] 'ot000', 'CurDrawerAccGuid'

	EXEC ('
		IF EXISTS( SELECT * FROM [op000] WHERE [name] = ''AmnPOS_DRAWERACCNAME'') 
			UPDATE
				[ot000] 
			SET
				[drawerAccGuid] = ISNULL(
					(SELECT 
						TOP 1 CAST([value] AS [UNIQUEIDENTIFIER]) 
					FROM 
						[op000] 
					WHERE 
						[name]  = ''AmnPOS_DRAWERACCNAME'' AND [computer] = [typeName]), 
				0x0)  
		-------------------	
		DELETE FROM [op000] WHERE [name]  = ''AmnPOS_DRAWERACCNAME''
		-------------------
		IF EXISTS( SELECT * FROM [op000] WHERE [name] = ''AmnPOS_CurDrawerAcc'') 
			UPDATE
				[ot000] 
			SET
				[curDrawerAccGuid]  = ISNULL(
					(SELECT 
						TOP 1 CAST([value] AS [UNIQUEIDENTIFIER]) 
					FROM
						[op000] 
					WHERE
						[name]  = ''AmnPOS_CurDrawerAcc'' AND [computer] = [typeName]), 
					0x0)
		-------------------	
		DELETE FROM [op000] WHERE [name]  = ''AmnPOS_CurDrawerAcc''
		-------------------
		')

#########################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002458
AS
	EXECUTE [prcAddGUIDFld] 'ot000', 'SpBTSaleGUID'
	EXECUTE [prcAddGUIDFld] 'ot000', 'SpBTRSaleGUID'
	EXECUTE [prcAddGUIDFld] 'ot000', 'SpBTInReadyGUID'
	EXECUTE [prcAddGUIDFld] 'ot000', 'SpBTOutRawGUID'
	EXECUTE [prcAddGUIDFld] 'ot000', 'SpInReadyAccGUID'
	EXECUTE [prcAddGUIDFld] 'ot000', 'SpOutRawAccGUID'	
	
	EXECUTE [prcAddBitFld] 'or000', 'UseSpecialType'
	
	EXECUTE [prcDropFld] 'or000', 'SaleBillGUID'
	EXECUTE [prcDropFld] 'or000', 'RSaleBillGUID'	
	
	declare @SqlString [varchar](2000)
	SET @SqlString = '	
	if exists(select * from [ot000] where [Type] = 2)
	begin		
		declare @t_ot table (
			[BtSaleGuid] [UNIQUEIDENTIFIER],
			[BtRSaleGuid] [UNIQUEIDENTIFIER],
			[BtInReadyGuid] [UNIQUEIDENTIFIER],
			[BTOutRawGuid] [UNIQUEIDENTIFIER],
			[InReadyAccGuid] [UNIQUEIDENTIFIER],
			[OutRawAccGuid] [UNIQUEIDENTIFIER],
			[typeName] [varchar](250)  COLLATE ARABIC_CI_AI
		)
		
		insert into @t_ot 
			select 
				[BTSaleGUID],
				[BTRSaleGUID],
				[BTInReadyGUID],
				[BTOutRawGUID],
				[InReadyAccGuid],
				[OutRawAccGuid],
				[typeName]
			from [ot000] where [type] = 2
		if @@RowCount > 0 
		begin
			update [ot] set
				[SpBTSaleGuid] = [t].[BTSaleGuid],
				[SpBTRSaleGuid] = [t].[BTRSaleGuid],
				[SpBTInReadyGuid] = [t].[BTInReadyGuid],
				[SpBTOutRawGuid] = [t].[BTOutRawGuid],
				[SpInReadyAccGuid] = [t].[InReadyAccGuid],
				[SpOutRawAccGuid] = [t].[OutRawAccGuid]
			from [ot000] [ot] inner join @t_ot [t] on [ot].[typeName] = [t].[typeName] 
			where [ot].[type] = 0
			
			-- update or000
			update [o] set 
					[UseSpecialType] = 1,
					[otGuid] = (select [Guid] from [ot000] where [type] = 0 and [typeName] = [ot].[TypeName])  			
			from [or000] [o] inner join [ot000] [ot] on [o].[otGuid] = [ot].[Guid] 
			where [ot].[Type] = 2
			
			-- delete special bills Type from ot000
			delete [ot000] where [type] = 2

		end		
	end
			
	update [ot] set
			[systemType] = case [o].[value] when 2 then 1 else 0 end
		from [ot000] [ot] inner join [op000] [o] on [o].[Computer] = [ot].[typeName]
		where [ot].[Type] = 0 and [o].[name] = ''AmnPOS_systemType''
	
	-- update systemType in ot000	
	delete [op000] where [name] = ''AmnPOS_DRAWERACCNAME'' or [name] = ''AmnPOS_CurDrawerAcc'' or [name] = ''AmnPOS_systemType''
	'
	EXECUTE (@SqlString)

#########################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002461
AS
	EXECUTE [prcAddGUIDFld] 'br000', 'ParentGUID'
	
#########################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002484
AS
	EXECUTE [prcAddGUIDFld] 'DisGroup000', 'Type'
	
#########################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002489
AS
	EXECUTE [prcAddFloatFld] 'oi000', 'MatPrice'
#########################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002492
AS
	EXECUTE [prcAddFloatFld] 'ad000', 'DailyRental'
#########################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002504
AS
	EXECUTE [prcAddFloatFld] 'DistVan000', 'Capacity'
	EXECUTE [prcAddCharFld]  'DistCe000', 'Contract', 250

	--EXECUTE [prcAddFloatFld]  'DistDisc000', 'Type'
	EXECUTE [prcAddFloatFld]  'DistDisc000', 'Percent'
	EXECUTE [prcAddFloatFld]  'DistDisc000', 'CondValue'
	EXECUTE [prcAddGUIDFld]   'DistDisc000', 'DiscAccGUID'
	EXECUTE [prcDropFld] 'DistDisc000', 'Type'
	EXECUTE [prcAddIntFld] 'DistDisc000', 'DiscType'
#########################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002509
AS
	EXECUTE [prcAddGUIDFld] 'ot000', 'POSTransfierGUID'
#########################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002510
AS
	EXECUTE [prcAddFloatFld] 'DisGeneralTarget000', 'SalesQty'
	EXECUTE [prcAddCharFld] 'DisGeneralTarget000', 'SalesUnity', 100
#########################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002513
AS
	EXECUTE [prcAddGUIDFld] 'Distributor000', 'PrimSalesmanGUID'
	EXECUTE [prcAddGUIDFld] 'Distributor000', 'AssisSalesmanGUID'	
#########################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002514
AS
	EXECUTE [prcDropFld] 'Distributor000', 'CostGuid'
	EXECUTE [prcAddIntFld] 'Distributor000', 'TypeGuid'
	EXECUTE [prcDropFld] 'DistSalesMan000', 'Security'	
	EXECUTE [prcAddGUIDFld] 'DistSalesMan000', 'CostGUID'	
	EXECUTE [prcAddGUIDFld] 'DistSalesMan000', 'AccGUID'	
	EXECUTE [prcAddIntFld] 'DistSalesMan000', 'Security'	
	EXECUTE [prcAddFloatFld] 'DistCe000', 'MaxDebt'	
#########################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002515
AS
	EXECUTE [prcAddIntFld] 'DistCe000', 'Contracted'
	EXECUTE [prcDropFld] 'DistCommIncentive000', 'PerioGuid'
	EXECUTE [prcAddGUIDFld] 'DistCommIncentive000', 'PeriodGuid'
	EXECUTE [prcAddFloatFld] 'DistSalesMan000', 'TypeGuid'
#########################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002516
AS
	EXECUTE [prcAddBitFld] 'hossite000', 'bMultiPatient'
#########################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002517
AS
	EXECUTE [prcAddGUIDFld] 'DistCommissionPrice000', 'PeriodGuid'
	EXECUTE [prcAddGUIDFld] 'Distdistributortarget000', 'CurGuid'
	EXECUTE [prcAddFloatFld] 'Distdistributortarget000', 'CurVal'
	EXECUTE [prcAddGUIDFld] 'bdp000', 'ParentGuid'
#########################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002520
AS
	EXECUTE [prcAddFloatFld] 'HosAnalysisOrder000', 'Total'
#########################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002526
AS
	alter table [bt000] disable trigger all
	alter table [bu000] disable trigger all
	
	IF [dbo].[fnObjectExists]( 'bt000.FldDisc') <> 0 
		BEGIN
			EXECUTE [prcRenameFld] 'bt000', 'FldDisc', 'FldDiscValue'
			EXECUTE [prcRenameFld] 'bt000', 'FldExtra', 'FldExtraValue'
			EXECUTE [prcExecuteSQL] 'UPDATE bt000 SET FldDiscRatio = FldDiscValue, FldDiscValue = FldDiscRatio'
		END
	EXECUTE [prcAddFloatFld] 'bu000', 'ItemsExtra'
	EXECUTE [prcAddGUIDFld] 'bu000', 'ItemsExtraAccGUID'

	alter table [bt000] enable trigger all
	alter table [bu000] enable trigger all
		
#########################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002527
AS
	EXECUTE [prcAddIntFld] 'HosPatient000', 'Gender'
	EXECUTE [prcAddFloatFld] 'hosAnalysis000', 'ExternalPrice'
	EXECUTE [prcAddFloatFld] 'Distributor000', 'VisitPerDay'
#########################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002532
AS
	EXECUTE [prcAddFloatFld] 'DisGeneralTarget000', 'Unit'
	EXECUTE [prcAddFloatFld] 'DisGeneralTarget000', 'SalesUnit'

	EXECUTE [prcDropFld] 'DisGeneralTarget000', 'Unity'
	EXECUTE [prcDropFld] 'DisGeneralTarget000', 'SalesUnity'
	EXECUTE [prcAddIntFld] 'DistMe000', 'State'

#########################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002533
AS
	EXECUTE [prcAlterFld] 'hosradiographyorderdetail000', 'Result', 'VARCHAR (4000) COLLATE ARABIC_CI_AI', 0, ''''''

#########################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002536
AS
	EXECUTE [prcAddFloatFld] 'DistCustMatTarget000', 'ExpectedCustTarget'
	-- EXECUTE ('ALTER TABLE DisGeneralTarget000 ALTER COLUMN Unit FLOAT NOT NULL ')	
	-- EXECUTE ('ALTER TABLE DisGeneralTarget000 ALTER COLUMN SalesUnit FLOAT NOT NULL ')	

	EXECUTE [prcDropFld] 'DisTCHTarget000', 'Unity'
	EXECUTE [prcAddFloatFld] 'DisTCHTarget000', 'Unit'
#########################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002544
AS
	EXECUTE [prcDropFld] 'distdistributorTarget000', 'TargetUnity'	
	EXECUTE [prcDropFld] 'distdistributorTarget000', 'GeneralTargetQty'
	EXECUTE [prcDropFld] 'distdistributorTarget000', 'GeneralTargetUnity'
#########################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002547
AS
	EXECUTE [prcAddGUIDFld] 'DistDisc000', 'MatGuid'
	EXECUTE [prcAddDateFld] 'DistDisc000', 'StartDate'
	EXECUTE [prcAddDateFld] 'DistDisc000', 'EndDate'
	EXECUTE [prcAddIntFld] 'DistDisc000', 'OneTime'
	EXECUTE [prcAddIntFld] 'DistDisc000', 'ChangeVal'
	EXECUTE [prcAddCharFld] 'DistCe000', 'Barcode', 100

	IF [dbo].[fnObjectExists]( 'DistOffers000') <> 0 
		EXEC( 'DROP TABLE [DistOffers000]')
	EXECUTE [prcAddIntFld] 'DistTr000', 'State'
#########################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002548
AS
	EXECUTE [prcDropFld]  'DistDisc000','FldDistDiscMatGuid'
	EXECUTE [prcAddGUIDFld] 'DistDisc000', 'MatGuid'

####################################################	
CREATE PROCEDURE prcUpgradeDatabase_From10002554
AS
	IF NOT EXISTS (SELECT * FROM [ui000] WHERE [PermType] = 9)
		BEGIN
			INSERT INTO [ui000] ([UserGuid], [ReportID], [SubID], [System], [PermType], [Permission]) 
				SELECT [ui].[UserGuid], [ui].[ReportID], [ui].[SubID], [ui].[System], [ui].[PermType] + 8, [ui].[Permission] FROM [ui000] AS [ui]
				INNER JOIN [bt000] AS [bt] on [ui].[SubID] = [bt].[GUID]
				WHERE [PermType] >= 1 AND [PermType] <= 3 AND [System] = 1
		END
####################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002561
AS
	EXECUTE [prcAddFloatFld] 'DistDistributorTarget000', 'Number'
	EXECUTE [prcAddFloatFld] 'DistMe000', 'Volume'
	EXECUTE [prcDropFld] 'DistCustMatTarget000', 'Unity'
	EXECUTE [prcAddIntFld] 'DistCustMatTarget000', 'Unit'
	EXECUTE [prcAddGUIDFld] 'DistCustTarget000', 'DistGUID'
####################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002562
AS		
	EXECUTE [prcAddGUIDFld] 'hosStay000', 'SiteGuid'
	EXECUTE [prcAddIntFld] 'DistPromotions000', 'Type'
	EXECUTE [prcAddIntFld] 'DistPromotions000', 'DiscType'
			
####################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002563
AS
	EXECUTE [prcAddIntFld] 'DistDisc000', 'Security'

####################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002564
AS	
	EXECUTE [prcAddGUIDFld] 'hosStay000', 'AccGuid'

####################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002581
AS
-- prcAddBigIntFld
	EXECUTE [prcAddIntFld] 'Distributor000', 'ItemDiscType'
####################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002584
AS
	EXECUTE [prcAddIntFld] 'DistCe000', 'OrderInRoute'
	
####################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002585
AS
	EXECUTE [prcAddBitFld] 'us000', 'Dirty', 1
####################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002586
AS
	EXECUTE [prcAddCharFld] 'InvReconcileHeader000', 'Desc', 250
	EXECUTE [prcAddIntFld] 'InvReconcileItem000', 'Num'
	EXECUTE [prcAddIntFld] 'InvReconcileHeader000', 'Num'
	
	EXECUTE [prcAddGUIDFld] 'InvReconcileHeader000', 'UserGUID'
	EXECUTE [prcAddCharFld] 'InvReconcileHeader000', 'Note', 250
	
####################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002590 
AS
	EXECUTE [prcAddFloatFld] 'or000', 'DiscCardValue'


####################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002597
AS
	EXECUTE [prcAddGUIDFld] 'hosConsumed000', 'StoreGUID'
####################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002598
AS
	EXECUTE [prcAddCharFld] 'cu000', 'BarCode', 100
	EXECUTE [prcDropFld] 'DistCe000', 'Barcode'

####################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002604
AS	
	EXECUTE [prcAddIntFld] 'cu000', 'GLNFlag'
####################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002605
AS
	EXECUTE [prcAlterFld] 'as000', 'LifeExp', 'FLOAT', 0, '0'
####################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002608
AS
	EXECUTE [prcAddFloatFld] 'mt000', 'Order'

###################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002610
AS
	EXECUTE [prcAddFloatFld] 'HosSurgeryMat000', 'Unity'
	EXECUTE [prcAddFloatFld] 'HosRadioGraphyMats000', 'Unity'
###################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002613
AS
	EXECUTE [prcAddFloatFld] 'mt000', 'OrderLimit'
	IF [dbo].[fnObjectExists]('mt000' + '.' + '[Order]') <> 0
		EXECUTE [prcExecuteSQL] 
			'UPDATE [mt000] SET [OrderLimit] = [Order]'
	EXECUTE [prcDropFld] 'mt000', '[Order]'
		
###################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002614
AS
 	EXECUTE [prcAddGUIDFld] 'ori000', 'BuGUID'
	EXECUTE [prcAddGUIDFld] 'ori000', 'TypeGUID'

###################################################	
CREATE PROCEDURE prcUpgradeDatabase_From10002617
AS
	EXECUTE [prcAddIntFld] 'oit000', 'PostQty'
	
###################################################	
CREATE PROCEDURE prcUpgradeDatabase_From10002621
AS
	IF [dbo].[fnObjectExists]( 'bt000.bCashBill') = 0 
	BEGIN
		ALTER TABLE BT000 DISABLE TRIGGER ALL
		EXECUTE [prcAddBitFld] 'bt000', 'bCashBill'
		EXECUTE [prcExecuteSQL] 'UPDATE [bt000] SET [bCashBill] = [bPOSBill]'
		ALTER TABLE BT000 ENABLE TRIGGER ALL
	END
	
###################################################		
CREATE PROCEDURE prcUpgradeDatabase_From10002625
AS
	EXECUTE [prcExecuteSQL] 'UPDATE ori SET ori.TypeGuid = oit.Guid FROM ori000 ori INNER JOIN oit000 oit ON oit.Number = ori.Type'
###################################################		
CREATE PROCEDURE prcUpgradeDatabase_From10002629
AS
	EXECUTE [prcAddGUIDFld] 'Distributor000', 'CustomersAccGUID'
###################################################		
CREATE PROCEDURE prcUpgradeDatabase_From10002636
AS
	EXECUTE [prcAddGUIDFld] 'bu000', 'CostAccGUID'
	EXECUTE [prcAddGUIDFld] 'bu000', 'StockAccGUID'
	EXECUTE [prcAddGUIDFld] 'bu000', 'VATAccGUID'
	EXECUTE [prcAddGUIDFld] 'bu000', 'BonusAccGUID'
	EXECUTE [prcAddGUIDFld] 'bu000', 'BonusContraAccGUID'
	
###################################################		
CREATE PROCEDURE prcUpgradeDatabase_From10002643
AS
		EXECUTE [prcAddBitFld] 'Distributor000', 'AutoPostBill'
		EXECUTE [prcAddBitFld] 'Distributor000', 'AutoGenBillEntry'
		EXECUTE [prcAddBitFld] 'Distributor000', 'AccessByBarcode'
		EXECUTE [prcAddBitFld] 'Distributor000', 'UseStockOfCust'
		EXECUTE [prcAddBitFld] 'Distributor000', 'UseShelfShare'
		EXECUTE [prcAddBitFld] 'Distributor000', 'UseActivity'
		EXECUTE [prcAddBitFld] 'Distributor000', 'NoOvertakeMaxDebit'
	
###################################################		
CREATE PROCEDURE prcConvertClassFld 
	@TableName [VARCHAR](128),
	@ColumnName [VARCHAR](128)
AS 
	DECLARE @RetVal [INT]

	EXECUTE @RetVal = [prcAlterFld] @TableName, @ColumnName, '[VARCHAR] (250) COLLATE ARABIC_CI_AI', 0, ''''''

	IF @RetVal <> 0 
	BEGIN
		EXECUTE ('ALTER TABLE ' + @TableName + ' DISABLE TRIGGER ALL')
		EXECUTE ('UPDATE ' + @TableName + ' SET ' + @ColumnName + ' = '''' WHERE ' + @ColumnName + ' = ''0''')
		EXECUTE ('ALTER TABLE ' + @TableName + ' ENABLE TRIGGER ALL')
	END
	
###################################################		
CREATE PROCEDURE prcUpgradeDatabase_From10002645
AS
	EXECUTE [prcConvertClassFld] 'bi000', 'ClassPtr'
	EXECUTE [prcConvertClassFld] 'di000', 'ClassPtr'
	EXECUTE [prcConvertClassFld] 'en000', 'Class'
	EXECUTE [prcConvertClassFld] 'mi000', 'Class'
	EXECUTE [prcConvertClassFld] 'mx000', 'Class'
	EXECUTE [prcAddDateFld] 'DistCe000', 'ContractDate'

	-- Moving Fld From GosSite to HosSiteType	
	EXECUTE [prcDropFld] 'hossite000', 'bMultiPatient'
	EXECUTE [prcAddBitFld] 'hossiteType000', 'bMultiPatient', '1'

	EXECUTE [prcAddGUIDFld] 'HosPFile000', 'BedGUID'
	EXECUTE [prcAddGUIDFld] 'HosPFile000', 'FirstStayGUID'
	EXECUTE [prcAddBitFld] 'hosStay000', 'IsAuto'
###################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002646
AS
	EXECUTE [prcAddGUIDFld] 'hosStay000', 'BedGuid'
###################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002647
AS
	-- upgrade the item security system when it's installed in the database
	
	IF EXISTS(SELECT * FROM [INFORMATION_SCHEMA].[TABLES] WHERE [TABLE_NAME] = 'is000' AND [TABLE_TYPE] = 'BASE TABLE')
	begin
		EXEC [prcDropTrigger] 'trg_ac000_ItemSecurity'
		EXEC [prcDropTrigger] 'trg_co000_ItemSecurity'
		EXEC [prcDropTrigger] 'trg_st000_ItemSecurity'
		EXEC [prcDropTrigger] 'trg_mt000_ItemSecurity'
		EXEC [prcDropTrigger] 'trg_gr000_ItemSecurity'

		IF [dbo].[fnObjectExists]( 'is000.ObjGuid') <> 0
		BEGIN
			EXEC [prcExecuteSQL] 'update isn set
				Mask1 = isn.Mask1 | um.Mask1,
				Mask2 = isn.Mask2 | um.Mask2, 
				Mask3 = isn.Mask3 | um.Mask3,
				Mask4 = isn.Mask4 | um.Mask4
			from 
				isx000 isn
				inner join
					( SELECT
						isOld.ObjGuid,
						SUM( CASE WHEN  u.Number between 1 and 63 THEN dbo.fnGetBranchMask( u.Number) ELSE 0 END) Mask1,
						SUM( CASE WHEN  u.Number between 64 and 127 THEN dbo.fnGetBranchMask( u.Number - 63) ELSE 0 END) Mask2,
						SUM( CASE WHEN  u.Number between 128 and 191  THEN dbo.fnGetBranchMask( u.Number - 127) ELSE 0 END) Mask3,
						SUM( CASE WHEN  u.Number between 192 and 255  THEN dbo.fnGetBranchMask( u.Number - 191) ELSE 0 END) Mask4
					FROM
						us000 u inner join is000 isOld on u.Guid = isOld.UserGuid
					WHERE
						u.Type = 0
					Group By isOld.ObjGuid ) um on um.ObjGuid = isn.ObjGuid'
		END
		/*
		declare @EnableItemSec [bit]
		select @EnableItemSec = [dbo].[fnOption_get]( 'EnableItemSecurity', '0')
		
		if( @EnableItemSec = 0)
		begin
			DELETE [op000] WHERE [name] = 'EnableItemSecurity'
			INSERT INTO [op000] ([name], [value]) VALUES( 'EnableItemSecurity', '1')
		end
		
		EXEC [prcExecuteSQL] 'exec sp_rename ''is000'', ''issOld'''
		*/
	end
###################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002648
AS
	EXECUTE [prcAddGUIDFld] 'HosAnalysisOrder000', 'BillGuid'
###################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002650
AS
	EXECUTE [prcAddIntFld] 'DistVI000', 'EntryStockOfCust'
	EXECUTE [prcAddIntFld] 'DistVI000', 'EntryVisibility'
###################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002651
AS
	IF EXISTS(SELECT * FROM [INFORMATION_SCHEMA].[TABLES] WHERE [TABLE_NAME] = 'hosBedTest000')
		EXEC [prcExecuteSQL] 'exec sp_rename ''hosBedTest000'', ''hosClinicalTest000'''
###################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002662
AS 
	EXECUTE [prcAddGUIDFld] 'sm000', 'CustAccGUID'
	EXECUTE [prcAddGUIDFld] 'sm000', 'OfferAccGUID'
	EXECUTE [prcAddBitFld] 'sm000', 'bAllBt', 1
	EXECUTE [prcAddGUIDFld] 'sm000', 'IOfferAccGUID'
	EXECUTE [prcAddFloatFld] 'cp000', 'DiscValue'
	EXECUTE [prcAddFloatFld] 'cp000', 'ExtraValue'
	
###################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002665
AS 
	EXECUTE [prcAddGUIDFld] 'HosSurgeryMat000', 'CurrencyGuid'
	EXECUTE [prcAddFloatFld] 'HosSurgeryMat000', 'CurrencyVal'
	EXECUTE [prcAddGUIDFld] 'HosSurgeryMat000', 'StoreGUID'
###################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002669
AS 
	EXECUTE [prcAddBitFld] 'Distributor000', 'CustBalanceByJobCost', 0
	EXECUTE [prcAddBitFld] 'Distributor000', 'UseCustTarget', 0
	EXECUTE [prcAddBitFld] 'Distributor000', 'OutNegative', 0
###################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002675
AS 
	EXECUTE [prcAddGUIDFld] 'gbt000', 'ParentID'
###################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002676
AS 
	EXECUTE [prcAddBitFld] 'Distributor000', 'CanChangePrice', 0
	EXECUTE [prcAddBitFld] 'Distributor000', 'ShowCustInfo', 0
	EXECUTE [prcAddBitFld] 'Distributor000', 'ShowTodayRoute', 0
	EXECUTE [prcAlterFld] 'df000', 'AsBarCode', 'INT', 1, '0'
###################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002677
AS 
	EXECUTE [prcAlterFld] 'df000', 'AsBarCode', 'INT', 1, '0'
###################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002678
AS
	EXECUTE [prcDropFld] 'InvReconcileHeader000', 'Name' 
###################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002685 
AS 
	EXECUTE [prcAddFloatFld] 'DistDisc000', 'CondValueTo'
	EXECUTE [prcAddGUIDFld] 'DistDisc000', 'GroupGuid'

	EXECUTE [prcAddGUIDFld] 'DiscountCard000', 'State'
	EXECUTE [prcAddGUIDFld] 'DiscountCard000', 'Type'
###################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002691 
AS 

	EXECUTE [prcAddFloatFld] 'hosConsumed000', 'Unity'
	EXECUTE [prcAddGUIDFld] 'hosConsumed000', 'CurrencyGuid'
	EXECUTE [prcAddFloatFld] 'hosConsumed000', 'CurrencyVal'


	EXECUTE [prcAddGUIDFld] 'TrnTransferTypes000', 'SourceBranchGUID'
	EXECUTE [prcAddGUIDFld] 'TrnTransferTypes000', 'DestinationBranchGUID'
	EXECUTE prcAddBigIntFld 'trnTransferTypes000', 'branchMask'
	EXECUTE prcAddBigIntFld 'trntransfervoucher000', 'branchMask'
	EXECUTE [prcAddGUIDFld] 'TrnBranch000', 'BranchStoreGUID'
	EXECUTE [prcAddGUIDFld] 'TrnBranch000', 'CurrencyGUID'
	EXECUTE [prcAddFloatFld] 'TrnBranch000', 'CurrencyVal'
	EXECUTE [prcAddCharFld] 'TrnBranch000', 'BranchChief', 250
	EXECUTE [prcAddGUIDFld] 'TrnBranch000', 'BranchChiefAccGUID'
	EXECUTE [prcAddCharFld] 'TrnBranch000', 'Company', 250
	EXECUTE [prcAddCharFld] 'TrnBranch000', 'City', 250
	EXECUTE [prcAddCharFld] 'TrnBranch000', 'Address', 250
	EXECUTE [prcAddCharFld] 'TrnBranch000', 'Phon1', 250
	EXECUTE [prcAddCharFld] 'TrnBranch000', 'Phon2', 250
	EXECUTE [prcAddCharFld] 'TrnBranch000', 'Fax', 250
	EXECUTE [prcAddCharFld] 'TrnBranch000', 'EMail', 250

	EXECUTE [prcAddFloatFld] 'TrnTransferVoucher000', 'InternalNum'	
	EXECUTE [prcAddCharFld] 'TrnBranch000', 'State', 250
	EXECUTE prcAddBigIntFld 'TrnSenderReceiver000', 'branchMask'
	EXECUTE prcAddBigIntFld 'TrnOffice000', 		'branchMask'	
	EXECUTE [prcAddGUIDFld] 'trntransfervoucher000', 'OfficeGuid'
	IF EXISTS ( SELECT * FROM   [sysobjects] WHERE [name] = 'FK_TrnWages_TrnWagesItem' AND [type] = 'F')
    	ALTER TABLE [TrnWagesItem000] DROP CONSTRAINT [FK_TrnWages_TrnWagesItem]
 	
	IF EXISTS(SELECT * FROM [INFORMATION_SCHEMA].[TABLES] WHERE [TABLE_NAME] = 'TrnWages000' AND [TABLE_TYPE] = 'BASE TABLE')
		IF NOT EXISTS ( SELECT * FROM [TrnWages000])
			DROP TABLE [TrnWages000]	
	
	EXECUTE [prcAddGUIDFld] 'TrnGenerator000', 'SourceBranchGuid'
	EXECUTE [prcAddGUIDFld] 'TrnGenerator000', 'DestBranchGuid'
	EXECUTE [prcAlterFld] 'TrnStatementItems000', 'Notes', 'VARCHAR (250) COLLATE ARABIC_CI_AI', 0, ''''''

	EXECUTE [prcAddBitFld] 'TrnTransferVoucher000', 'Cashed'
	EXECUTE [prcAddBitFld] 'TrnTransferVoucher000', 'paid'
	EXECUTE [prcAddBitFld] 'TrnTransferVoucher000', 'Notified'
	EXECUTE [prcAddFloatFld] 'TrnTransferVoucher000', 'MustCashedAmount'
	EXECUTE [prcAddIntFld] 'TrnWages000', 'Type'
	EXECUTE [prcAddFloatFld] 'TrnStatement000', 'TotalInCur2'
	EXECUTE [prcAddFloatFld] 'TrnBranch000', 	'BranchMask'
	EXECUTE [prcAddFloatFld] 'Trncommission000', 'BranchMask'
	EXECUTE [prcAddFloatFld] 'TrnRatio000', 'BranchMask'
	EXECUTE [prcAddFloatFld] 'TrnWages000', 'BranchMask'
	EXECUTE [prcAddGUIDFld] 'trnStatement000', 'Branch'
	EXECUTE [prcAddGUIDFld] 'TrnBranch000', 'DiscountAcc'
	EXECUTE [prcAddGUIDFld] 'TrnBranch000', 'ExtraAcc'
	EXECUTE [prcAddIntFld] 'TrnWages000', 'Type'
	EXECUTE [prcAddIntFld] 'trnStoppedTrance000', 'State'
	EXECUTE [prcAddIntFld] 'TrnTransferTypes000', 'ReturnCapability'
	EXECUTE [prcAddGUIDFld] 'TrnTransferTypes000', 'ReturnTrType'
	EXECUTE [prcAddFloatFld] 'TrnSenderReceiver000', 'DiscountRatio'
	EXECUTE [prcAddIntFld] 'TrnSenderReceiver000', 'Type'
	
	EXECUTE [prcAddGUIDFld] 'trnStatementItems000', 'TransferTypeGuid'
	
	EXECUTE [prcAddGUIDFld] 'trnTransferVoucher000', 'StatementGuid'
	EXECUTE [prcAddIntFld] 'trnTransferVoucher000', 'IsFromStatement'
	EXECUTE [prcAddIntFld] 'TrnStatement000', 'IsGeneratd'
	EXECUTE [prcAddFloatFld] 'trnStatementItems000', 'Discount'
	EXECUTE [prcAddIntFld] 'TrnTransferTypes000', 'PrintInternalVoucher'
	EXECUTE [prcAddIntFld] 'TrnTransferTypes000', 'PrintVoucher'
	EXECUTE [prcAddFloatFld] 'trnStatementItems000', 'MustCashedAmount'
	EXECUTE [prcAddFloatFld] 'trnStatementItems000', 'MustPaidAmount'
	EXECUTE [prcAddIntFld] 'trnStatementItems000', 'IsVoucherGenerated'
	EXECUTE [prcAddGUIDFld] 'trnStatementTypes000', 'Cur1'
	EXECUTE [prcAddGUIDFld] 'trnStatementTypes000', 'Cur2'
	EXECUTE [prcAddIntFld] 'trnStatementItems000', 'VoucherState'
	EXECUTE [prcAddIntFld] 'TrnTransferVoucher000', 'PreviousState'
	EXECUTE [prcAlterFld] 'TrnTransferVoucher000', 'Notes', 'VARCHAR (250) COLLATE ARABIC_CI_AI', 0, ''''''
	EXECUTE [prcAddGUIDFld] 'trnStatementItems000', 'TransferVoucherGuid'
	EXECUTE [prcAddGUIDFld] 'trntransferVoucher000', 'OriginalVoucherGuid'
	EXECUTE [prcAddIntFld] 'trntransferVoucher000', 'IsReturned'
	EXECUTE [prcAddGUIDFld] 'trnBranch000', 'ReturnAcc'
	EXECUTE [prcAddIntFld] 'trntransferVoucher000', 'IsFromReturned'
	EXECUTE [prcAddGUIDFld] 'trntransferVoucher000', 'CashAccGuid'
	EXECUTE [prcAlterFld] 'TrnBranch000', 'BranchMask', 'BIGINT', 0, '0'
	EXECUTE [prcAlterFld] 'Trncommission000', 'BranchMask', 'BIGINT', 0, '0'
	EXECUTE [prcAlterFld] 'TrnRatio000', 'BranchMask', 'BIGINT', 0, '0'
	EXECUTE [prcAlterFld] 'TrnWages000', 'BranchMask', 'BIGINT', 0, '0'
	EXECUTE [prcDropFldConstraints] 'trnstatementItems000', 'security'
	EXECUTE [prcDropFld] 'trnstatementItems000', 'security'
	EXECUTE [prcAddGUIDFld] 'TrnTransferVoucher000', 'PayBranch'
	EXECUTE [prcAddIntFld] 'trntransfervoucher000', 'IsSent'
	EXECUTE [prcAddGUIDFld] 'TrnVoucherPayInfo000', 'ActualReceiverGUID'

	EXECUTE [prcAddDateFld] 'trntransfervoucher000', 'TrnTime'
	EXECUTE [prcAddDateFld] 'trntransfervoucher000', 'CashDate'	
	EXECUTE [prcAddDateFld] 'trntransfervoucher000', 'CashTime'	
	EXECUTE [prcAddDateFld] 'trntransfervoucher000', 'NotifyDate'
	EXECUTE [prcAddDateFld] 'trntransfervoucher000', 'NotifyTime'
	EXECUTE [prcAddDateFld] 'trntransfervoucher000', 'PayTime'
	EXECUTE [prcAddDateFld] 'TrnNotify000', 'Time'
	EXECUTE [prcAddIntFld] 'TrnTransferTypes000', 'ShowStatementNo'
	EXECUTE [prcAddIntFld] 'TrnTransferTypes000', 'ShowOriginalVoucherCode'
	EXECUTE [prcAddIntFld] 'trnStatementTypes000', 'bGenerateVoucher'
	EXECUTE [prcAddGUIDFld] 'trnStatementTypes000', 'CreditAcc'
	EXECUTE [prcAddGUIDFld] 'trnStatementItems000', 'CreditAcc'
	EXECUTE prcAddBigIntFld 'trnTransferTypes000', 'PaybranchMask'
	EXECUTE prcAddBigIntFld 'trnTransferTypes000', 'CashbranchMask'
 	EXECUTE [prcAddGUIDFld] 'TrnTransferTypes000', 'MainPayBranchGUID'
	EXECUTE [prcAddGUIDFld] 'TrnTransferTypes000', 'MainCashBranchGUID'
	EXECUTE [prcAddCharFld] 'trnBranch000', 'BranchServerName', 250		
	EXECUTE [prcAddGUIDFld] 'TrnStatement000', 'SourceAcc'
	EXECUTE [prcAddGUIDFld] 'TrnStatement000', 'DestAcc'
	EXECUTE [prcAddCharFld] 'TrnSenderReceiver000', 'Mobile', 100
	EXECUTE [prcAddCharFld] 'trnBranch000', 'BranchSDFFileName', 250		
	EXECUTE [prcAddIntFld] 'trntransfervoucher000', 'LockFlag'
	EXECUTE prcAddBigIntFld 'trnTransferTypes000', 'AddbranchMask'
	EXECUTE [prcAddCharFld] 'trnBranch000', 'BranchDialUpConName', 250		


	EXECUTE [prcAddGUIDFld] 'trntransfervoucher000', 'CashBranch'
	EXECUTE [prcAddGUIDFld] 'trntransfervoucher000', 'AddBranch'
	EXECUTE [prcAddGUIDFld] 'trntransfervoucher000', 'NotifyBranch'
	EXECUTE [prcAddCharFld] 'TrnTransferTypes000', 'MenuName', 250
	EXECUTE [prcAddCharFld] 'TrnTransferTypes000', 'MenuLatinName', 250
	EXECUTE [prcAddCharFld] 'TrnStatementTypes000', 'MenuName', 250
	EXECUTE [prcAddCharFld] 'TrnStatementTypes000', 'MenuLatinName', 250
###################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002700
AS 
	-- By Ali: For fixing upgrade errors found in some older versions of the program
	EXECUTE [prcRenameFld] 'kn000', 'LinesCount', 'LineCount'
	EXECUTE [prcAddIntFld] 'kn000', 'LineCount'
###################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002702
AS 
	EXECUTE	[prcAddGUIDFld]  'hosConsumed000', 'ParentGuid'
	EXECUTE [prcAddDateFld] 'hosConsumedMaster000', 'Date'

###################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002706
AS 
	EXECUTE	[prcAddGUIDFld]  'HosRadioGraphyMats000', 'StoreGUID'

	EXECUTE	[prcAddGUIDFld]  'hosAnalysis000', 'CurrencyGuid'
	EXECUTE [prcAddFloatFld] 'hosAnalysis000', 'CurrencyVal'

	EXECUTE	[prcAddGUIDFld]  'hosRadioGraphy000', 'CurrencyGuid'
	EXECUTE [prcAddFloatFld] 'hosRadioGraphy000', 'CurrencyVal'


	EXECUTE	[prcAddGUIDFld]  'HosRadioGraphyOrder000', 'CurrencyGuid'
	EXECUTE [prcAddFloatFld] 'HosRadioGraphyOrder000', 'CurrencyVal'

	EXECUTE	[prcAddGUIDFld]  'HosAnalysisOrder000', 'CurrencyGuid'
	EXECUTE [prcAddFloatFld] 'HosAnalysisOrder000', 'CurrencyVal'

	IF [dbo].[fnObjectExists]('Hosconsumed000.CurrencyGuid') = 0
		EXECUTE [prcDropFld] 'Hosconsumed000', 'CurrencyGuid'
	IF [dbo].[fnObjectExists]('Hosconsumed000.CurrencyVal') = 0
		EXECUTE [prcDropFld] 'Hosconsumed000', 'CurrencyVal'


###################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002708
AS 
	EXECUTE	[prcAddGUIDFld]  'hosFSurgery000', 'CurrencyGuid'
	EXECUTE [prcAddFloatFld] 'hosFSurgery000', 'CurrencyVal'
	EXECUTE [prcAddCharFld]	'HosSite000', 'Desc', 256

	EXECUTE [prcAddGUIDFld] 'HosPFile000', 'Branch'

	EXECUTE [prcAddGUIDFld] 'HosAnalysisOrder000', 'Branch'
	EXECUTE [prcAddGUIDFld] 'HosRadioGraphyOrder000', 'Branch'

###################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002709
AS 
	IF NOT EXISTS( SELECT * FROM [CheckAcc000])
	BEGIN 
		DECLARE @USER [UNIQUEIDENTIFIER]
		SELECT TOP 1 @USER = [GUID] FROM [US000] WHERE [bAdmin] = 1
		SET @USER = ISNULL(@USER, (SELECT TOP 1 [GUID] FROM [US000]))

		DECLARE @CURRENCY [UNIQUEIDENTIFIER]
		SELECT TOP 1 @CURRENCY = [GUID] FROM [MY000] WHERE [Number] = 1

		INSERT INTO [CheckAcc000]
		(
			[GUID],
			[AccGUID],
			[UserGUID],
			[Debit],
			[Credit],
			[CurrencyGUID],
			[CurrencyVal],
			[CheckedToDate],
			[Date],
			[Notes]
		)
		SELECT 
			NEWID(), 
			[GUID],
			@USER,
			0, 
			0, 
			@CURRENCY,
			1,
			[CheckDate],
			GETDATE(),
			''
		FROM [AC000]
	END 	



	EXECUTE [prcAddFloatFld] 'trnStatementItems000', 'NetWages'

	EXECUTE [prcAddGUIDFld] 'hosPatient000', 'PictureGUID'


###################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002710
AS 
	EXECUTE [prcAddFloatFld] 'DiscountTypes000', 'DonateCond'

###################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002711
AS 
	EXECUTE [prcDropFld]  'Ng000', 'PrepareTime'
	EXECUTE [prcAddIntFld]'Ng000', 'PrepareTime'
	UPDATE Ng000 SET PrepareTime = Price

	DELETE FROM [Brt] WHERE [TableName] = 'TrnOffice000'

###################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002715
AS 
	EXECUTE prcAddBigIntFld 'DiscountCard000', 'branchMask'
	EXECUTE prcAddBigIntFld 'DiscountTypesCard000', 'branchMask'
	EXECUTE prcAddBigIntFld 'DiscountCardStatus000', 'branchMask'

###################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002718
AS	
	EXECUTE [prcDropFld] 'Tb000', 'branchMask'
	EXECUTE [prcDropFld] 'vn000', 'branchMask'	
	EXECUTE [prcDropFld] 'od000', 'branchMask'
	EXECUTE [prcDropFld] 'Kn000', 'branchMask'
###################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002719
AS	
	EXECUTE	[prcAddGUIDFld]  'TrnVoucherPayInfo000', 'CurrencyGuid'
	EXECUTE [prcAddFloatFld] 'TrnVoucherPayInfo000', 'CurrencyVal'

	EXECUTE [prcAddDateFld]  'hosOperation000', 'date'
	EXECUTE	[prcAddGUIDFld]  'hosOperation000', 'CurrencyGuid'
	EXECUTE	[prcAddFloatFld]  'hosOperation000', 'CurrencyVal'

	EXECUTE	[prcAddIntFld]  'Oi000', 'IsPrinted'
	
	EXECUTE	[prcAddIntFld]  'Oit000', 'PostToBill'
	EXECUTE [prcExecuteSQL] 'UPDATE oit000 SET  PostToBill = PostQty'
###################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002720
AS
	EXECUTE	[prcAddIntFld]  'DistCt000', 'PossibilityItemDisc'
###################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002721
AS
	EXECUTE	[prcAddBitFld]  'Distributor000', 'UseCustLastPrice'

###################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002722
AS
	EXECUTE	[prcAddIntFld]  'DiscountTypes000', 'Detailed'
	EXECUTE [prcDropFld]	'DiscountTypes000', '[Group]'
	EXECUTE [prcDropFld]	'DiscountTypes000', '[Percent]'
###################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002724
AS
	EXECUTE	[prcAddIntFld]  'DiscountTypesItems000', 'DiscountType'
	EXECUTE [prcDropFld]	'DiscountTypesItems000', '[Percent]'
###################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002726
AS
	--IF( fnObjectExists( 'trg_brt_CheckConstraints') <> 0)
	--	EXECUTE [prcExecuteSQL] 'ALTER TABLE [brt] DISABLE TRIGGER [trg_brt_CheckConstraints]'
	DELETE [brt] WHERE [TableName] = 'gr000' OR [TableName] = 'TrnStatement000' OR [TableName] = 'TrnTransferVoucher000'
	--IF( fnObjectExists( 'trg_brt_CheckConstraints') <> 0)
	--	EXECUTE [prcExecuteSQL] 'ALTER TABLE [brt] DISABLE TRIGGER [trg_brt_CheckConstraints]'
###################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002728
AS
	EXECUTE [prcDropFld]	'abd000', 'Type'
###################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002731
AS
	EXECUTE	[prcAddIntFld]  'rg000', 'Number'
	EXECUTE	[prcAddIntFld]  're000', 'Number'
###################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002734
AS
	IF ( [dbo].[fnObjectExists]('prh000.Height') = 0)
	BEGIN
		EXECUTE	[prcDropFld]  'prh000', 'Contents'
		EXECUTE [prcAddFloatFld] 'prh000', 'Height', 0
		EXECUTE	[prcAddBlobFld]  'prh000', 'HdrContents'
	END
	EXECUTE [prcAddBitFld] 'Distributor000', 'ExportAllCustDetailFlag', 0
	EXECUTE [prcAddBitFld] 'Distributor000', 'CustBarcodeHasValidate', 0
	EXECUTE [prcAddCharFld]	'DistCe000', 'Notes', 1000
###################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002742
AS
	-------------------------------------------------------------------------
	IF [dbo].[fnObjectExists]( 'DistCe000.DistributorGuid') <> 0 
	EXEC('
		CREATE TABLE [#DistTbl] ([DistGuid] [UNIQUEIDENTIFIER], [DistCode] [VARCHAR](255) COLLATE Arabic_CI_AI, [DistName] [VARCHAR](255) COLLATE Arabic_CI_AI, [CiGuid] [UNIQUEIDENTIFIER])
		INSERT INTO [#DistTbl] (DistGuid, DistCode, DistName)
			SELECT Ce.DistributorGuid, D.Code, D.Name
			FROM DistCE000 AS Ce INNER JOIN Distributor000 AS D ON D.Guid = Ce.DistributorGuid
			GROUP BY Ce.DistributorGuid, D.Code, D.Name

		CREATE TABLE [#AccTbl] ([DistGuid] [UNIQUEIDENTIFIER], [AccGuid] [UNIQUEIDENTIFIER], [CustGuid] [UNIQUEIDENTIFIER], [Route1] [INT], [Route2] [INT], [Route3] [INT], [Route4] [INT])
		INSERT INTO [#AccTbl] 
			SELECT Ce.DistributorGuid, Cu.CuAccount, Ce.CustomerGuid, Ce.Route1, Ce.Route2, Ce.Route3, Ce.Route4 
			FROM DistCE000 AS Ce 
			INNER JOIN vwCu AS Cu ON Cu.CuGuid = Ce.CustomerGuid

		DECLARE @CMain		Cursor,
			@CDetail	Cursor,
			@DistGuid	UNIQUEIDENTIFIER,
			@CiGuid		UNIQUEIDENTIFIER,
			@AccGuid	UNIQUEIDENTIFIER,
			@DistCode	VARCHAR(255),
			@DistName	VARCHAR(255),
			@AccName	VARCHAR(255),
			@AccCode	VARCHAR(255),
			@CheckDate	DATETIME,
			@Number		INT
	
		SET @CMain = CURSOR FAST_FORWARD FOR 
			SELECT DistGuid, DistCode, DistName FROM #DistTbl
		OPEN @CMain FETCH FROM @CMain INTO @DistGuid, @DistCode, @DistName
		WHILE @@FETCH_STATUS = 0 
		BEGIN 
			SET @CiGuid = newId()
			SET @AccCode = ''8000'' + @DistCode
			SET @AccName = @DistName
			SELECT @Number = MAX(Number) + 1 FROM Ac000	
			SELECT TOP 1 @CheckDate = CheckDate FROM Ac000	
		        -- Create Aggregate Accounts
			INSERT INTO Ac000 
				(Number,     Code,     Name,     CDate, NSons, CurrencyVal, CheckDate, Security, Type, State,    Guid, ParentGuid, FinalGuid, CurrencyGuid, BranchGuid, BranchMask)
			VALUES
				(@Number, @AccCode, @AccName, GetDate(), 0,     0,          @CheckDate, 1,        4,    0,    @CiGuid, 0x00,       0x00,      0x00,         0x00,       0)
				-- Create Aggregate Sons Accounts
				SET @CDetail = CURSOR FAST_FORWARD FOR 
					SELECT AccGuid FROM #AccTbl WHERE DistGuid = @DistGuid
				OPEN @CDetail FETCH FROM @CDetail INTO @AccGuid
				WHILE @@FETCH_STATUS = 0 
				BEGIN 
					SELECT @Number = MAX(ISNULL(Item,0)) + 1 FROM Ci000	WHERE ParentGuid = @CiGuid
					INSERT INTO Ci000 	(Item, Guid, ParentGuid, SonGuid)
					VALUES			(@Number, newID(), @CiGuid, @AccGuid)	
							   
					FETCH FROM @CDetail INTO @AccGuid
				END
				CLOSE @CDetail DEALLOCATE @CDETAIL 
			-- Update DistAccCust To Take Aggregate Account
			UPDATE Distributor000 SET CustomersAccGuid = @CiGuid WHERE Guid = @DistGuid
				 
			FETCH FROM @CMain INTO @DistGuid, @DistCode, @DistName
		END -- @c loop 
		CLOSE @CMain DEALLOCATE @CMain 

		-- Move Dist Lines From DistCe To DistLines
		DELETE FROM DistDistributionLines000
		INSERT INTO DistDistributionLines000 (Guid, DistGuid, CustGuid, Route1, Route2, Route3, Route4)
			SELECT NewID(), [DistGuid], [CustGuid], [Route1], [Route2], [Route3], [Route4]
			FROM [#AccTbl]

		-- Delete Columns
		EXEC [dbo].[prcDropFld] ''DistCe000'', ''DistributorGUID''
		EXEC [dbo].[prcDropFld] ''DistCe000'', ''Route1''
		EXEC [dbo].[prcDropFld] ''DistCe000'', ''Route2''
		EXEC [dbo].[prcDropFld] ''DistCe000'', ''Route3''
		EXEC [dbo].[prcDropFld] ''DistCe000'', ''Route4''
		EXEC [dbo].[prcDropFld] ''DistCe000'', ''MaxDebt''
	')
	-------------------------------------------------------------------------
	
	EXECUTE [prcAddFld]  'DistCustTarget000' , 'CurGuid', 'uniqueidentifier'
	EXECUTE [prcAddFld]  'DistCustTarget000' , 'CurVal', 'FLOAT'
	EXEC 
	( '	UPDATE dbo.DistCustTarget000 
		SET 	CurGuid = ( SELECT Guid FROM My000 WHERE Number = 1 ),
				CurVal  = ( SELECT CurrencyVal FROM My000 WHERE Number = 1 )
		WHERE ISNULL(CurGuid, 0x00) = 0x00 '
	)
###################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002743
AS
	EXECUTE [prcAddIntFld] 'Distributor000', 'DefaultPayType'
	EXECUTE [prcAddCharFld] 'Distributor000', 'DistributorPassword', 250
	EXECUTE [prcAddCharFld] 'Distributor000', 'SupervisorPassword', 250

###################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002749
AS
	EXECUTE [prcAddIntFld] 'DistDisc000', 'Security'

####################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002766 
AS
	EXECUTE [prcAddCharFld] 'ad000', 'Site', 250
	EXECUTE [prcAddCharFld] 'ad000', 'Guarantee', 250
	EXECUTE [prcAddDateFld] 'ad000', 'Guarantee_BeginDate'
	EXECUTE [prcAddDateFld] 'ad000', 'Guarantee_EndDate'
	EXECUTE [prcAddCharFld] 'ad000', 'Department', 250
	EXECUTE [prcAddFloatFld] 'InvReconcileItem000', 'Qty2'
	EXECUTE [prcAddFloatFld] 'InvReconcileItem000', 'StkQty2'
	EXECUTE [prcAddFloatFld] 'InvReconcileItem000', 'Qty3'
	EXECUTE [prcAddFloatFld] 'InvReconcileItem000', 'StkQty3'
###################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002774 
AS
	EXECUTE [prcAddIntFld] 'PalmBu', 'VisitIndex'
	EXECUTE [prcAddIntFld] 'PalmCm', 'VisitIndex'
	EXECUTE [prcAddIntFld] 'PalmEn', 'VisitIndex'
###################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002778 
AS
	EXECUTE [prcAddIntFld] 'DistPromotions000', 'Type'
	EXECUTE [prcAddIntFld] 'DistPromotions000', 'DiscType'
	EXECUTE [prcAddIntFld] 'HosReservation000', 'State'
	EXECUTE [prcAddIntFld] 'dp000', 'CalcMethod'
	EXECUTE [prcAddCharFld] 'ad000', 'BarCode', 250
###################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002783
AS
	EXECUTE	[prcAddGUIDFld]  'hosGeneralOperation000', 'accGuid'
###################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002786  
AS
	EXECUTE [prcAddGUIDFld] 'DistDeviceBu000', 'VisitGUID'
	EXECUTE [prcAddGUIDFld] 'DistDeviceEn000', 'VisitGUID'
	EXECUTE [prcAddGUIDFld] 'hosRadioGraphy000', 'TypeGUID'
##########################################################################
Create PROCEDURE prcUpgradeDatabase_From10002787 
AS
	IF NOT EXISTS ( SELECT * FROM SYSOBJECTS WHERE NAME = 'PS000')
	return 
	
	--if their is no data in old table just return 
	IF NOT  EXISTS ( SELECT * FROM PS000)
		return
	EXECUTE ('
	DECLARE @newParentGuid UNIQUEIDENTIFIER 

	--a new  parent guid for all current ps record that will be moved to psi 
	--this guid will occupy two places in ps.guid and in psi.parentguid 
	SET @newParentGuid = NEWID()


	--Define a cursor for old mnps000 table 
	DECLARE @PSCURSOR CURSOR 
	SET  @PSCURSOR = CURSOR  FORWARD_ONLY FOR 
	SELECT * FROM PS000
	OPEN @PSCURSOR

	-- variable for old ps table 
	DECLARE	 @GUID UNIQUEIDENTIFIER ,
			 @Number INT ,
			 @Code VARCHAR(100),		 
			 @Name varchar(250), 
			 @LatinName varchar(250), 
			 @FormGuid UNIQUEIDENTIFIER,
			 @Qty varchar(250),	
			 @StartDate DATETIME,
			 @EndDate DATETIME,
			 @Note VARCHAR(250),
			 @priority INT 
		

	FETCH NEXT FROM @PSCURSOR INTO 
	@GUID ,  @Number , @Code , @Name , @LatinName, @FormGuid , @Qty , @StartDate,
	@EndDate , @Note , @priority 

	--two variable that will hols storeguid from ( bt000 when bill type is out , 
	-- or from form default out store stored in  mn000 table ) 
	DECLARE @DefOutStore UNIQUEIDENTIFIER	 , @OutStoreGuid UNIQUEIDENTIFIER

	-- get default store from bt000
	SELECT  @DefOutStore = DefStoreGuid 
	FROM BT000 
	WHERE Type = 2 AND SortNum = 6

	SET @DefOutStore = ISNULL(@DefOutStore,0x00)

	-- ps startDate should be preivous  to all it children and endDate should be later to all children 
	-- and this is the job of @TempStartDate , TempEndDate variable 
	DECLARE @TempStartDate DateTime , @TempEndDate DateTime 
	--initalized two variable to current local time 
	SET @TempStartDate = GetDate()
	Set @TempEndDate = GetDate()

	WHILE @@FETCH_STATUS = 0 
	BEGIN 		 

	SELECT
		@OutStoreGuid = OutStoreGuid 
	FROM 
		mn000 
	WHERE 
		formguid = @FormGuid and type = 0
		
	SET @OutStoreGuid  = ISNULL( @OutStoreGuid ,@DefOutStore)

	INSERT INTO 
		psi000(
			[Guid], 
			[Code], 
			[StartDate], 
			[EndDate], 
			[Qty], 
			[FormGuid], 
			[Priority], 
			[StoreGuid],
			[Notes],
			[State],
			[ParentGuid])
	VALUES (
			NEWID(),
			@code,
			@startdate,
			@enddate,
			@qty,
			@FormGuid,
			@priority,
			@OutStoreGuid,
			@note,
			2,
			@newParentGuid)

	IF @TempStartDate > @startdate
		SET @TempStartDate  = @startdate

	IF @TempEndDate < @enddate 
		SET @TempEndDate = @enddate 

	FETCH NEXT FROM @PSCURSOR INTO 
		@GUID , @Number , @Code , @Name , @LatinName, @FormGuid , @Qty , @StartDate,
		@EndDate , @Note , @Priority 

	END 
	
	CLOSE 	@PSCURSOR
	DEALLOCATE @PSCURSOR

	INSERT INTO MNPS000(Guid, Code, StartDate, EndDate, State, Security, BranchGuid)
	VALUES(@newParentGuid,''000001'',@TempStartDate,@TempEndDate,
	''manufacturing plans before upgrade'',0,1,0x00)
	')

##########################################################################
Create PROCEDURE prcUpgradeDatabase_From10002789 
AS 
	EXECUTE [prcAddGUIDFld] 'DistDeviceVi000', 'DistributorGUID'
	EXECUTE [prcAddIntFld]	'HosSiteType000', 'PricePolicy'
	EXECUTE ('UPDATE HosSiteType000 SET PricePolicy = 0 ')
##########################################################################
Create PROCEDURE prcUpgradeDatabase_From10002811 
AS 
	EXECUTE [prcAddIntFld]	'DistDeviceMt000', 'SNFlag'
	EXECUTE [prcAddIntFld]	'DistDeviceMt000', 'ForceInSN'
	EXECUTE [prcAddIntFld]	'DistDeviceMt000', 'ForceOutSN'
##########################################################################
Create PROCEDURE prcUpgradeDatabase_From10002821 
AS 
	EXECUTE [prcAddBigIntFld] 'Distributor000', 'branchMask'
	EXECUTE [prcAddBigIntFld] 'DistHi000', 'branchMask'
	EXECUTE [prcAddBigIntFld] 'DistSalesman000', 'branchMask'
	EXECUTE [prcAddBigIntFld] 'DistVan000', 'branchMask'
	EXECUTE [prcAddGUIDFld] 'DisGeneralTarget000', 'BranchGUID'
	EXECUTE [prcAddGUIDFld] 'DistCustMatTarget000', 'BranchGUID'
	EXECUTE [prcAddGUIDFld] 'DistCustTarget000', 'BranchGUID'
	EXECUTE [prcAddGUIDFld] 'DistDistributorTarget000', 'BranchGUID'
##########################################################################
Create PROCEDURE prcUpgradeDatabase_From10002822 
AS 
	EXECUTE [prcDropFld] 'Distributor000', 'branchMask'
	EXECUTE [prcAddBigIntFld] 'Distributor000', 'branchMask'
##########################################################################
Create PROCEDURE prcUpgradeDatabase_From10002823 
AS 
	DELETE FROM brt WHERE TableName = 'Distributor000'
##########################################################################
Create PROCEDURE prcUpgradeDatabase_From10002824
AS 
	EXECUTE [prcAddGUIDFld] 'DisTChTarget000', 'BranchGUID'
	EXECUTE [prcAddGUIDFld] 'DistCustClassesTarget000', 'BranchGUID'
##########################################################################
Create PROCEDURE prcUpgradeDatabase_From10002827
AS 
	EXECUTE [prcDropTrigger] 'trg_ce000_post'
##########################################################################
Create PROCEDURE prcUpgradeDatabase_From10002828
AS 
	EXECUTE [prcAddBitFld] 'bu000', 'IsPrinted'
	EXECUTE [prcAddGUIDFld] 'HosPFile000', 'ReservationGuid'
##########################################################################
Create PROCEDURE prcUpgradeDatabase_From10002832
AS 
		EXECUTE [prcAddGUIDFld] 'AbD000', 'Branch'
		EXECUTE [prcAddGUIDFld]		'HosTreatmentPlan000', 'BillGuid'
		EXECUTE [prcAddCharFld]		'HosTreatmentPlan000', 'Code', 100
		EXECUTE [prcAddIntFld]		'HosTreatmentPlanDetails000', 'Status'
		EXECUTE [prcAddFloatFld]	'HosTreatmentPlanDetails000', 'Dose'
##########################################################################
Create PROCEDURE prcUpgradeDatabase_From10002835
AS 
		EXECUTE [prcAddIntFld]		'HosTreatmentPlan000', 'unity'
		EXECUTE [prcAddIntFld]		'HosTreatmentPlanDetails000', 'unity'
##########################################################################
Create PROCEDURE prcUpgradeDatabase_From10002837
AS 
		EXECUTE [prcAddIntFld]		'HosPFile000', 'ClinicalTestSecurity'
		EXECUTE [prcAddIntFld]		'HosPFile000', 'StaySecurity'
		EXECUTE [prcAddIntFld]		'HosPFile000', 'GeneralOperationSecurity'
		EXECUTE [prcAddIntFld]		'HosPFile000', 'MedConsSecurity'
		EXECUTE [prcAddIntFld]		'HosPFile000', 'DoctorFollowingSecurity'
		EXECUTE [prcAddIntFld]		'HosPFile000', 'NurseFollowingSecurity'
		EXECUTE [prcAddIntFld]		'HosPFile000', 'ConsumedSecurity'
		EXECUTE [prcAddGUIDFld]		'DistCC000', 'CustStateGuid'
		EXECUTE [prcAddIntFld]		'ad000', 'Security'
		EXECUTE [prcAddGUIDFld]		'ad000', 'BrGuid'
		EXECUTE [prcAddGUIDFld]		'ad000', 'CoGuid'
		EXECUTE ('UPDATE ad000 SET Security = 1')
		
##########################################################################
Create PROCEDURE prcUpgradeDatabase_From10002838
AS 
		EXECUTE [prcAddGUIDFld]		'DistDisc000', 'MatTemplateGuid'
		EXECUTE [prcDropFld] 		'DistSalesMan000', 'CurrSaleMan'	
##########################################################################
Create PROCEDURE prcUpgradeDatabase_From10002846
AS 
		EXECUTE [prcAddGUIDFld]		'hosConsumedMaster000', 'BillGUID'
		EXECUTE [prcAddFloatFld] 	'HosgeneralOperation000', 'WorkerFee'	
		EXECUTE [prcAddGUIDFld] 	'hosGeneraltest000', 'WorkerGUID'	
		EXECUTE [prcAddGUIDFld] 	'hosGeneraltest000', 'CurrencyGuid'	
		EXECUTE [prcAddFloatFld] 	'hosGeneraltest000', 'CurrencyVal'
		EXECUTE [prcAddFloatFld] 	'hosGeneraltest000', 'WorkerFee'	
		EXECUTE [prcAddGUIDFld] 	'hosConsumedMaster000', 'BillGuid'	
##########################################################################
Create PROCEDURE prcUpgradeDatabase_From10002847
AS 
		EXECUTE [prcAddGUIDFld]		'hosStay000', 'EntryGuid'
		EXECUTE [prcAddGUIDFld] 	'hosStay000', 'CurrencyGuid'	
		EXECUTE [prcAddFloatFld] 	'hosStay000', 'CurrencyVal'	
##########################################################################
Create PROCEDURE prcUpgradeDatabase_From10002856
AS 
		EXECUTE [prcAddGUIDFld]		'HosRadioGraphyOrder000', 'EntryGuid'
		EXECUTE [prcAddIntFld]		'ad000', 'Status'
		EXECUTE [prcExecuteSQL]		'UPDATE ad000 SET status = 1'
##########################################################################
Create PROCEDURE prcUpgradeDatabase_From10002859
AS 
		EXECUTE [prcAddGUIDFld]		'HosReservationDetails000', 'FileGuid'
		EXECUTE [prcAddGUIDFld]		'HosReservationDetails000', 'PayGuid'
		EXECUTE [prcAddGUIDFld]		'HosReservationDetails000', 'CurrencyGuid'
		EXECUTE [prcAddFloatFld]	'HosReservationDetails000', 'CurrencyVal'
		EXECUTE [prcAddIntFld]		'HosReservationDetails000', 'IsConfirm'
##########################################################################
Create PROCEDURE prcUpgradeDatabase_From10002864
AS
	EXECUTE [prcAddIntFld]	'HosSiteType000', 'PricePolicy'
##########################################################################	
Create PROCEDURE prcUpgradeDatabase_From10002872
AS
	EXECUTE [prcAddDateFld] 'DistDistributionLines000', 'Route1Time'
	EXECUTE [prcAddDateFld] 'DistDistributionLines000', 'Route2Time'
	EXECUTE [prcAddDateFld] 'DistDistributionLines000', 'Route3Time'
	EXECUTE [prcAddDateFld] 'DistDistributionLines000', 'Route4Time'
	EXECUTE [prcAddCharFld]	'DistDeviceCu000', 'RouteTime', 10
	EXECUTE [prcAddIntFld]	'DistDeviceCu000', 'SortID'
##########################################################################	
Create PROCEDURE prcUpgradeDatabase_From10002874
AS
	EXECUTE [prcAddGUIDFld]	'dp000', 'AccGUID'
	EXECUTE [prcAddGUIDFld]	'dp000', 'AccuAccGUID'
##########################################################################	
Create PROCEDURE prcUpgradeDatabase_From10002876
AS	
	EXECUTE [prcAddGUIDFld]	'AssetExclude000', 'BillTypeGuid'
	EXEC [prcAlterFld] 'prs000','LeftMargin','FLOAT'
	EXEC [prcAlterFld] 'prs000','TopMargin','FLOAT'
	EXEC [prcAlterFld] 'prs000','BottomMargin','FLOAT'
	EXEC [prcAlterFld] 'prs000','RightMargin','FLOAT'
##########################################################################	
Create PROCEDURE prcUpgradeDatabase_From10002882
AS	
	EXEC prcAddIntFld 	'DistDeviceBt000', 'Type'
	EXEC prcAddGUIDFld 	'DistDeviceBt000', 'StoreGUID'
	EXEC prcAddGUIDFld 	'DistDeviceBu000', 'StoreGUID'
	EXEC prcAddGUIDFld 	'DistDeviceCu000', 'StoreGUID'
	EXEC prcAddCHARFld 	'DistDeviceCu000', 'Notes', 250
	EXEC prcAddCHARFld 	'DistDeviceNewCu000', 'NewNotes', 250
##########################################################################	
Create PROCEDURE prcUpgradeDatabase_From10002884
AS	
	EXEC prcAddIntFld 	'HosPFile000', 'FileType'
	EXEC prcAddFloatFld 'DistCuSt000', 'Number' 
	EXEC prcAddDateFld  'DistCuSt000', 'PriceFromDate'
	EXEC prcAddDateFld  'DistCuSt000', 'PriceToDate'
	EXEC prcAddFloatFld 'DistCuSt000', 'Commission'
##########################################################################	
Create PROCEDURE prcUpgradeDatabase_From10002892
AS	
	EXEC [prcAddGUIDFld]	'DistCC000', 'MatShowGuid'
##########################################################################	
Create PROCEDURE prcUpgradeDatabase_From10002894
AS	
	Exec prcAddGuidFld   'DistDeviceMt000', 'MatTemplateGuid'
	Exec prcAddGuidFld   'DistDeviceDiscDetail000', 'MatTemplateGuid'
	Exec prcAddFloatFld  'DistDeviceCu000', 'AroundBalance'
	Exec prcAddDATEFld   'DistDeviceCu000', 'LastBuDate'
	Exec prcAddFloatFld  'DistDeviceCu000', 'LastBuTotal'
	Exec prcAddFloatFld  'DistDeviceCu000', 'LastBuFirstPay'
	Exec prcAddDAteFld   'DistDeviceCu000', 'LastEnDate'
	Exec prcAddFloatFld  'DistDeviceCu000', 'LastEnTotal'
##########################################################################	
Create PROCEDURE prcUpgradeDatabase_From10002895
AS	
	EXEC prcAddIntFld 'DistDeviceStatement000', 'LineType'
	EXEC prcAddBitFld 'Distributor000', 'CanChangeCustBarcode'
##########################################################################	
Create PROCEDURE prcUpgradeDatabase_From10002899
AS	
	EXEC prcAddGUIDFld 'DistDeviceBT000', 'btGUID'
	EXEC prcAddGUIDFld 'DistDeviceET000', 'etGUID'
	EXEC prcAddGUIDFld 'DistDeviceTT000', 'ttGUID'
	EXEC prcAddGUIDFld 'DistDeviceCu000', 'cuGUID'
	EXEC prcAddCharFld 'DistDeviceCu000', 'CustomerType', 250
	EXEC prcAddCharFld 'DistDeviceCu000', 'TradeChannel', 250
	EXEC prcAddGUIDFld 'DistDeviceST000', 'stGUID'
	EXEC prcAddGUIDFld 'DistDeviceGR000', 'grGUID'
	EXEC prcAddGUIDFld 'DistDeviceMT000', 'mtGUID'
##########################################################################
Create PROCEDURE prcUpgradeDatabase_From10002924
AS	
	EXEC prcAddIntFld 'ni000', 'Type'
	EXEC ( 'UPDATE Ni000 SET Type = 0' )
	EXEC prcAddIntFld 'distdd000', 'ObjectNumber'	
##########################################################################
Create PROCEDURE prcUpgradeDatabase_From10002929
AS	
	EXEC prcAddCharFld 'Pl000', 'DistributorPassword', 20
	EXEC prcAddCharFld 'Pl000', 'SupervisorPassword', 20
	EXEC prcAddCharFld 'Pl000', 'License', 50
##########################################################################
Create PROCEDURE prcUpgradeDatabase_From10002936
AS	
	Exec prcAddbitFld 'DistCt000', 'PayTypeCashOnly'
##########################################################################
Create PROCEDURE prcUpgradeDatabase_From10002937
AS	
	EXEC prcDisableTriggers  'ce000'
	EXEC prcDisableTriggers  'en000'
	EXEC prcDisableTriggers  'er000'
	EXEC prcDisableTriggers  'bu000'
	EXEC prcDisableTriggers  'bi000'
	EXEC ('
			declare @Ce_GUID  TABLE (Guid UNIQUEIDENTIFIER)
			declare @Er_GUID  TABLE (Guid UNIQUEIDENTIFIER,EntryGUID UNIQUEIDENTIFIER,ParentGUID UNIQUEIDENTIFIER,t float,number float)
			insert @Ce_GUID select ce.guid from bu000 bu
				inner join er000 er on er.parentGUID=bu.GUID
				inner join ce000 ce on ce.GUID = er.EntryGuid
			where  exists (select count(*) as c from er000 er inner join bu000 b on b.guid=er.parentguid where b.guid=bu.guid group by er.parentguid having count(*)>1 )
				and ce.number not in 
				(
					select min(c.number)  from er000 er 
						inner join bu000 b on b.guid=er.parentguid 
						inner join ce000 c on c.guid=er.entryguid
					where b.guid=bu.guid group by er.parentguid
				)
			insert @Er_GUID select * from er000 where EntryGUID in (select * from @Ce_GUID)
			delete er000 where EntryGUID in ( select * from @Ce_GUID)
			insert into billrel000 select Guid, 200, ParentGUID, EntryGUID,number from @Er_GUID
		 ')
	EXEC prcEnableTriggers 'ce000' 
	EXEC prcEnableTriggers 'en000' 
	EXEC prcEnableTriggers 'er000' 
	EXEC prcEnableTriggers 'bu000' 
	EXEC prcEnableTriggers 'bi000'
##########################################################################
Create PROCEDURE prcUpgradeDatabase_From10002943
AS	
	Exec prcAddGUIDFld 'TB000', 'ORDER_GUID'
	Exec prcAddIntFld  'TB000', 'LOCKED'
##########################################################################
Create PROCEDURE prcUpgradeDatabase_From10002952
AS	
	EXEC prcAddIntFld	'Distributor000',  'PrintPrice'
	EXEC prcAddFloatFld 'DistDeviceMt000', 'Price5'
	EXEC prcAddFloatFld 'DistDeviceMt000', 'Price6'
	EXEC prcAddFloatFld 'DistDeviceMt000', 'Price5Unit2'
	EXEC prcAddFloatFld 'DistDeviceMt000', 'Price6Unit2'
	EXEC prcAddFloatFld 'DistDeviceMt000', 'Price5Unit3'
	EXEC prcAddFloatFld 'DistDeviceMt000', 'Price6Unit3'
	EXEC prcAddBitFld	'DistDeviceVi000', 'UseCustBarcode', '0'
	EXEC prcAddBitFld	'DistVi000',	   'UseCustBarcode', '0'
##########################################################################
Create PROCEDURE prcUpgradeDatabase_From10002956
AS	
	EXEC prcAddGuidFld 'DistCe000', 'StoreGuid'
##########################################################################
Create PROCEDURE prcUpgradeDatabase_From10002959
AS
	EXEC prcAddGuidFld 'RS000', 'BranchGUID'
##########################################################################
Create PROCEDURE prcUpgradeDatabase_From10002962
AS
	EXECUTE prcAddBigIntFld 'vn000', 'branchMask'
	EXECUTE prcAddBigIntFld 'od000', 'branchMask'
	EXECUTE prcAddBigIntFld 'kn000', 'branchMask'
	EXECUTE prcAddBigIntFld 'tb000', 'branchMask'
	EXECUTE prcAddBigIntFld 'posspecialoffer000', 'branchMask'
	EXECUTE prcAddBigIntFld 'ng000', 'branchMask'
##########################################################################
Create PROCEDURE prcUpgradeDatabase_From10002967
AS
	EXEC prcAddIntFld  'DistDeviceCu000', 'DefPrice'
	EXEC prcAddCharFld 'DistDeviceCu000', 'Phone', 20
	EXEC prcAddCharFld 'DistDeviceCu000', 'Mobile', 20

	Exec prcAddFld 'DistDeviceNewCu000', 'Name',			 '[VARCHAR](100) COLLATE ARABIC_CI_AI DEFAULT ('''') '
	Exec prcAddFld 'DistDeviceNewCu000', 'Area',			 '[VARCHAR](50) COLLATE ARABIC_CI_AI DEFAULT ('''') '
	Exec prcAddFld 'DistDeviceNewCu000', 'Street',			 '[VARCHAR](50) COLLATE ARABIC_CI_AI DEFAULT ('''') '
	Exec prcAddFld 'DistDeviceNewCu000', 'Phone',			 '[VARCHAR](20) COLLATE ARABIC_CI_AI DEFAULT ('''') '
	Exec prcAddFld 'DistDeviceNewCu000', 'Mobile',			 '[VARCHAR](20) COLLATE ARABIC_CI_AI DEFAULT ('''') '
	Exec prcAddFld 'DistDeviceNewCu000', 'PersonalName',	 '[VARCHAR](100) COLLATE ARABIC_CI_AI DEFAULT ('''') '
	Exec prcAddFld 'DistDeviceNewCu000', 'CustomerTypeGuid', '[UNIQUEIDENTIFIER] DEFAULT (0x00)'
	Exec prcAddFld 'DistDeviceNewCu000', 'TradeChannelGuid', '[UNIQUEIDENTIFIER] DEFAULT (0x00)'
	Exec prcAddFld 'DistDeviceNewCu000', 'Contracted',		 '[BIT] DEFAULT (0)'
##########################################################################
Create PROCEDURE prcUpgradeDatabase_From10002969
AS
	Exec prcAddGUIDFld 'od000', 'CaptinGuid'
##########################################################################
Create PROCEDURE prcUpgradeDatabase_From10002977
AS
	EXECUTE [prcAddGUIDFld]		'Dp000', 'MatGuid'
	EXECUTE [prcAddGUIDFld]		'Dp000', 'GroupGuid'
	EXECUTE [prcAddGUIDFld]		'Dp000', 'StoreGuid'
	EXECUTE [prcAddFloatFld]	'DD000', 'PrevDep'
#########################################################################
Create PROCEDURE prcUpgradeDatabase_From10002984
AS
Declare @sql  varchar(1000)
set @sql = ' CREATE TABLE [#Result] 
	(
		[GUID] [UNIQUEIDENTIFIER],
		[Security] [INT]
	)
	Declare @c cursor, @GroupKeys UniqueIdentifier,@Group UniqueIdentifier 
	
	SET @c = CURSOR FAST_FORWARD READ_ONLY FOR 
	select guid, grpguid from pg000 where type=1

	OPEN @c FETCH FROM @c INTO @GroupKeys,@Group
	delete pk000 where parentguid=@GroupKeys

	while @@fetch_status = 0
	begin
		delete #result
		INSERT INTO [#Result] exec [prcGetGroupsList] @Group

		insert into pk000 (number, type, guid, keyname, matguid, pictureguid, parentguid) SELECT
		mt.[Number],
		1,
		newid(),
		mt.[Name],
		mt.[GUID],
		mt.[PictureGuid],
		@GroupKeys
		FROM
		mt000 mt INNER JOIN [#Result] AS [gr] ON [GroupGuid] = [gr].[GUID]
		Order By mt.name
	FETCH next FROM @c INTO @GroupKeys,@Group
	end 
	CLOSE @c
	DEALLOCATE @c
	drop table #result'
exec( @Sql)
#########################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002986
AS
	EXEC prcAddFld 'DistVd000', 'CustNotes', '[VARCHAR](100) COLLATE ARABIC_CI_AI DEFAULT ('''') '
	EXEC prcAddFld 'DistVd000', 'DistNotes', '[VARCHAR](100) COLLATE ARABIC_CI_AI DEFAULT ('''') '
	EXEC prcAddGUIDFld 'DistCg000', 'CompanyGuid'
	EXEC prcAddGUIDFld 'DistCg000', 'VisitGuid'
	EXEC prcAddGUIDFld 'DistCm000', 'VisitGuid'
	EXEC('
			UPDATE DistVd000 SET CustNotes = '''' WHERE CustNotes IS Null
			UPDATE DistVd000 SET DistNotes = '''' WHERE DistNotes IS Null
		')
#########################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002989
AS
	EXEC prcAddbitFld 'DistDeviceBu000', 'IsSync'
	EXEC prcAddbitFld 'DistDeviceEn000', 'IsSync'
#########################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002995
AS
	EXEC prcAddIntFld 'DistDeviceCm000', 'Unity'
#########################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10002999
AS
	EXEC prcAddGUIDFld 'AssetExclude000', 'ProfitAccGuid'
	EXEC prcAddGUIDFld 'AssetExclude000', 'LossAccGuid'

#########################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10012006
AS
	EXEC prcAddIntFld  'DistPromotions000', 'CondType'
	EXEC prcAddIntFld  'DistPromotions000', 'FreeType'
	EXEC prcAddbitFld  'DistPromotions000', 'IsActive', 1
	EXEC prcAddIntFld  'DistPromotionsDetail000', 'Unity', 1
	EXEC prcAddbitFld  'Distributor000', 'ExportOffers'
	EXEC prcAddbitFld  'Distributor000', 'CheckBillOffers'
	EXEC prcAddbitFld  'Distributor000', 'CanAddBonus', 1
	EXEC prcAddbitFld  'Distributor000', 'AddMatByBarcode'

#########################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10012007
AS	
	EXEC prcAddFloatFld 'DistPromotionsBudget000', 'RealPromQty' 
	EXEC prcAddIntFld 'DistDeviceBi000', 'ProNumber'	
	EXEC prcAddIntFld 'DistDeviceBi000', 'ProType'		
	EXEC prcAddIntFld 'DistDevicePro000', 'ProNumber'	
	EXEC prcAddIntFld 'DistDevicePro000', 'CondType'	
	EXEC prcAddIntFld 'DistDevicePro000', 'FreeType'		
	EXEC prcAddIntFld 'DistDeviceProDetail000', 'Unity', 1

#########################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10012014
AS
	EXEC prcAddbitFld  'Distributor000', 'CanUpdateOffer' 
	EXEC prcAddbitFld  'DistPromotions000' , 'ChkExactlyQty'
	EXEC prcAddbitFld  'DistDevicePro000' , 'ChkExactlyQty'
#########################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10012016
AS
	EXEC prcAddBitFld	'DistDeviceBu000', 'IsOrder'
	EXEC prcAddFloatFld 'DistDeviceMt000', 'OrderQty'
	EXEC prcAddIntFld	'DistDeviceMt000', 'OrderUnity'
	EXEC prcDropFld		'DistDeviceBu000', 'TripGuid'
	EXEC prcDropFld		'DistDeviceBu000', 'EntryGuid'
#########################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10012017
AS	
	EXEC prcAddBitFld	'DistOrders000'  , 'AutoPostTransfer'
#########################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10012021
AS	
	EXEC prcAddBitFld	'Distributor000'  , 'ExportAfterZeroAcc'
#########################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10012022
AS	
	EXEC prcAddBitFld	'Distributor000'  , 'ExportExpireDates'
	EXEC prcAddBitFld	'Distributor000'  , 'FIFOExpireDate'
	EXEC prcAddBitFld	'Distributor000'  , 'ExportClasses'
#########################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10012023
AS	
	EXEC prcDropFld		'Distributor000'  , 'ExportExpireDates'
	EXEC prcDropFld		'Distributor000'  , 'FIFOExpireDate'
	EXEC prcDropFld		'Distributor000'  , 'ExportClasses'
#########################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10012024
AS	
	EXEC prcAddFloatFld 'ori000', 'BonusPostedQty'
#########################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10012029
AS	
	EXEC prcAddBitFld	'Distributor000'  , 'CanAddCustomer'
	EXEC prcAddBitFld	'Distributor000'  , 'ChangeCustCard'
#########################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10012033
AS	
	EXEC prcAddBitFld 'Distributor000', 'IsSync'
	Exec prcAddFloatFld 'DistDeviceMt000', 'BonusOne'
	Exec prcAddFloatFld 'DistDeviceMt000', 'Bonus'
#########################################################################
#END
