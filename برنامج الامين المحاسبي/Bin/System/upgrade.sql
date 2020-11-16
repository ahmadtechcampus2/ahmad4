#include upgrade_core.sql

###############################################################################
CREATE PROC prcUpgrade_AddOldFlds
AS
	EXECUTE [prcAddIntFld] 'bt000', 'number'
	EXECUTE [prcAddIntFld] 'bt000', 'defStore'
	EXECUTE [prcAddIntFld] 'bt000', 'defStockAcc'
	EXECUTE [prcAddIntFld] 'bt000', 'defCostAcc'
	EXECUTE [prcAddIntFld] 'bt000', 'defBillAcc'
	EXECUTE [prcAddIntFld] 'bt000', 'defDiscAcc'
	EXECUTE [prcAddIntFld] 'bt000', 'defExtraAcc'
	EXECUTE [prcAddIntFld] 'bt000', 'defCashAcc'
	EXECUTE [prcAddIntFld] 'bt000', 'defVATAcc'
	EXECUTE [prcAddIntFld] 'bt000', 'custAcc'
	EXECUTE [prcAddIntFld] 'et000', 'number'
	EXECUTE [prcAddIntFld] 'et000', 'defAcc'
	EXECUTE [prcAddIntFld] 'nt000', 'number'
	EXECUTE [prcAddIntFld] 'nt000', 'defPayAcc'
	EXECUTE [prcAddIntFld] 'nt000', 'defrecAcc'
	EXECUTE [prcAddIntFld] 'nt000', 'defColAcc'
	EXECUTE [prcAddIntFld] 'nt000', 'costPtr'
	--EXECUTE [prcAddIntFld] 'or000', 'saleBillNum'

###############################################################################
CREATE PROC prcUpgradeDatabase_From10001000
AS
	EXECUTE [prcUpgrade_AddOldFlds]
	DECLARE @c CURSOR,@TblName SYSNAME,@ConstName SYSNAME,@Sql VARCHAR(1000)
	SET @c = CURSOR FAST_FORWARD FOR 
		SELECT a.Name,c.Name FROM SYSOBJECTS a inner join SYSCONSTRAINTS b on b.constid = a.id INNER JOIN SYSOBJECTS c ON c.id = b.id
		where a.xtype = 'pk' AND C.NAME LIKE '%000'
	OPEN @c FETCH NEXT FROM @c INTO @ConstName,@TblName
	WHILE (@@FETCH_STATUS = 0)
	BEGIN
		SET @Sql = 'ALTER TABLE ' + @TblName + ' DROP CONSTRAINT ' + @ConstName
		EXEC [prcLog] @Sql
		EXEC (@Sql)
		FETCH NEXT FROM @c INTO @ConstName,@TblName
	END
	CLOSE @c
	DEALLOCATE @c
	EXECUTE [prcFlag_set] 2 -- user must check billTypes

#########################################################
CREATE PROCEDURE prcUpgradeDatabase_From10001012
AS
/*
This procedure:
	- upgrades from version 10001012 to 10001013
	- is usually called from prcUpgradeDatabase procedure
*/

	-- see ac000:
	EXECUTE [prcDropTrigger] 'trgPostAccountBalance'

	EXECUTE [prcDropTrigger] 'trgAccountParentChanges'

	-- see bi000:
	EXECUTE [prcDropTrigger] 'trgBillItems'

	EXECUTE [prcDropTrigger] 'trgUpdateBillItem'


	-- see bu000:
	EXECUTE [prcDropTrigger] 'trgPostBillInsert'

	EXECUTE [prcDropTrigger] 'trgPostBillDelete'

	EXECUTE [prcDropTrigger] 'trgPostBillUpdate'

	EXECUTE [prcDropTrigger] 'trg_bu000_update_Posting'


	-- see ce000:
	EXECUTE [prcDropTrigger] 'trgPostEnteryDelete'

	EXECUTE [prcDropTrigger] 'trgPostEnteryUpdate'

	EXECUTE [prcDropTrigger] 'trgPostEnteryInsert'

	-- see en000:
	EXECUTE [prcDropTrigger] 'trgUpdateCEBalance'

	-- see procedures
	EXECUTE [prcDropProcedure] 'prc_bu_ManagePosting'

##########################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10001013
AS
/*
This procedure:
	- upgrades from version 10001013 to 10001014
	- is usually called from prcUpgradeDatabase procedure
*/
	EXECUTE [prcDropTrigger] 'trg_ce000_CheckConstraints'

##########################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10001015
AS
/*
	- adds new flieds to mt and bi
	- updates new bi CostPtr field.
	- had to execute as string due to syntax error when compiling CostPtr before creating it
*/
	EXECUTE [prcAddBitFld] 'mt000', 'ExpireFlag'
	EXECUTE [prcAddBitFld] 'mt000', 'ProductionFlag'
	EXECUTE [prcAddBitFld] 'mt000', 'Unit2FactFlag'
	EXECUTE [prcAddBitFld] 'mt000', 'Unit3FactFlag'
	EXECUTE [prcAddCharFld] 'mt000', 'BarCode2', 100
	EXECUTE [prcAddCharFld] 'mt000', 'BarCode3', 100

	EXECUTE [prcAddFloatFld] 'bi000', 'Qty2'
	EXECUTE [prcAddFloatFld] 'bi000', 'Qty3'
	EXECUTE [prcAddFloatFld] 'bi000', 'CostPtr'
	EXECUTE [prcAddFloatFld] 'bi000', 'ClassPtr'
	EXECUTE [prcAddDateFld] 'bi000', 'ExpireDate'
	EXECUTE [prcAddDateFld] 'bi000', 'ProductionDate'
	EXECUTE [prcAddFloatFld] 'bi000', 'Length'
	EXECUTE [prcAddFloatFld] 'bi000', 'Width'
	EXECUTE [prcAddFloatFld] 'bi000', 'Height'
	EXECUTE ('
		ALTER TABLE [bi000] DISABLE TRIGGER ALL
		UPDATE [bi000] SET [CostPtr] = [bu000].[CostPtr]
			FROM [bi000] INNER JOIN [bu000] ON [bi000].[Type] = [bu000].[Type] AND [bi000].[Parent] = [bu000].[Number]
			WHERE [bu000].[CostPtr] IS NOT NULL AND [bu000].[CostPtr] <> 0
		ALTER TABLE [bi000] ENABLE TRIGGER ALL')

##########################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10001018
AS
/*
This procedure:
	- adds SN flieds to mt
	- adds GUID to bi
*/
	-- alter mt000 add SN fields
	EXECUTE [prcAddBitFld] 'mt000', 'SNFlag'
	EXECUTE [prcAddBitFld] 'mt000', 'ForceInSN'
	EXECUTE [prcAddBitFld] 'mt000', 'ForceOutSN'

	-- add guid to bi
	EXECUTE [prcAddROWGUIDCOLFld] 'bi000'

##########################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10001020
AS
/*
This procedure:
	- adds new fields for ch000 table
	- ?? ??? ???????
*/
	EXECUTE [prcAddCharFld] 'ch000', 'IntNumber', 100
	EXECUTE [prcAddCharFld] 'ch000', 'FileInt', 100
	EXECUTE [prcAddCharFld] 'ch000', 'FileExt', 100
	EXECUTE [prcAddDateFld] 'ch000', 'FileDate'
	EXECUTE [prcAddCharFld] 'ch000', 'OrgName', 100

##########################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10001025
AS
/*
This procedure:
	- drops tables: br, kn, or, oi, vn and tb; clears mc related entries; adds fields to gr.
*/
	SET NOCOUNT ON
	EXECUTE [prcDropTableIfEmpty] 'br000'
	--EXECUTE [prcDropTableIfEmpty] 'kn000'
	--EXECUTE [prcDropTableIfEmpty] 'or000'
	--EXECUTE [prcDropTableIfEmpty] 'oi000'
	--EXECUTE [prcDropTableIfEmpty] 'vn000'
	--EXECUTE [prcDropTableIfEmpty] 'tb000'

	DELETE FROM [mc000] WHERE [TYPE] = 4 AND [Number] BETWEEN 33 AND 39 AND [Number] <> 35

	EXECUTE [prcAddROWGUIDCOLFld] 'gr000'
	EXECUTE [prcAddIntFld] 'gr000', 'Type'

##########################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10001026
AS
/*
This procedure:
	- drops tables: add parent field to oi (order items) table.
*/
	--EXECUTE [prcAddGUIDFld] 'oi000', 'Parent'

##########################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10001028
AS
/*
This procedure:
	- add:
			FinishUser to or000.
			Vendor and Salesman to en000.
			VAT to mt000 and gr000
*/
	--EXECUTE [prcAddIntFld] 'or000', 'FinishUser'
	EXECUTE [prcAddIntFld] 'en000', 'Vendor'
	EXECUTE [prcAddIntFld] 'en000', 'SalesMan'
	EXECUTE [prcAddFloatFld] 'mt000', 'VAT'
	EXECUTE [prcAddFloatFld] 'gr000', 'VAT'

##########################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10001034
AS
/*
This procedure:
	- adds: LinesCount integer field to kn000
*/
	--EXECUTE [prcAddIntFld] 'kn000', 'LinesCount'

##########################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10001035
AS
/*
This procedure:
	- adds: PrinterID integer field to kn000
*/
	--EXECUTE [prcAddIntFld] 'kn000', 'PrinterId'

##########################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10001036
AS
/*
This procedure:
	- adds: StorePtr integer field to sm000 and oi000
*/
	EXECUTE [prcAddIntFld] 'sm000', 'StorePtr'
	--EXECUTE [prcAddIntFld] 'oi000', 'StorePtr'

##########################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10001038
AS
/*
This procedure:
	- adds: ExpectedTime datetime field to or000, and Color, Provenance, Quality, Model to mt000
	- drops: trg_ce000_insert and trg_bi000_buStatisticsUpdater
*/
	--EXECUTE [prcAddDateFld] 'or000', 'ExpectedTime'
	EXECUTE [prcAddCharFld] 'mt000', 'Color', 100
	EXECUTE [prcAddCharFld] 'mt000', 'Provenance', 100
	EXECUTE [prcAddCharFld] 'mt000', 'Quality', 100
	EXECUTE [prcAddCharFld] 'mt000', 'Model', 100

	EXECUTE [prcDropTrigger] 'trg_ce000_insert'
	EXECUTE [prcDropTrigger] 'trg_bi000_buStatisticsUpdater'

##########################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10001040
AS
/*
This procedure:
	- adds: Branch to or000, bu000 and ce000.
	- adds: VAT to bu000 and bi000.
	- adds: LatinName, eMail, HomePage, PreFix, Suffix, GPSX, GPSY, GPSZ, Area, City, Street, POBox, Cellular, Pager to cu000
*/
	--EXECUTE [prcAddGUIDFld] 'or000', 'Branch'
	EXECUTE [prcAddGUIDFld] 'ce000', 'Branch'
	EXECUTE [prcAddGUIDFld] 'bu000', 'Branch'
	EXECUTE [prcAddFloatFld] 'bu000', 'VAT'
	EXECUTE [prcAddFloatFld] 'bi000', 'VAT'
	EXECUTE [prcAddCharFld] 'cu000', 'LatinName', 250
	EXECUTE [prcAddCharFld] 'cu000', 'eMail', 250
	EXECUTE [prcAddCharFld] 'cu000', 'HomePage', 250
	EXECUTE [prcAddCharFld] 'cu000', 'Prefix', 100
	EXECUTE [prcAddCharFld] 'cu000', 'Suffix', 100
	EXECUTE [prcAddFloatFld] 'cu000', 'GPSX'
	EXECUTE [prcAddFloatFld] 'cu000', 'GPSY'
	EXECUTE [prcAddFloatFld] 'cu000',	'GPSZ'
	EXECUTE [prcAddCharFld] 'cu000', 'Area', 100
	EXECUTE [prcAddCharFld] 'cu000', 'City', 100
	EXECUTE [prcAddCharFld] 'cu000', 'Street', 100
	EXECUTE [prcAddCharFld] 'cu000', 'POBox', 100
	EXECUTE [prcAddCharFld] 'cu000', 'ZipCode', 100
	EXECUTE [prcAddCharFld] 'cu000', 'Mobile', 100
	EXECUTE [prcAddCharFld] 'cu000', 'Pager', 100

##########################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10001041
AS
	-- DECLARE @DF VARCHAR(250)
	-- Added by Ali
	-- Should not modify table schema if it has data
	--DECLARE @RetVal AS [INT]
	--IF( ([dbo].[fnObjectExists]('kn000') = 1) AND 
	--	([dbo].[fnObjectExists]('kn000.LinesCount') = 1))
	--BEGIN
	--	EXECUTE [prcDropFld] 'kn000', 'PrinterID'
	--	EXECUTE [prcDropFld] 'kn000', 'LinesCount'
	--	EXECUTE [prcDropFld] 'kn000', 'LineCount'
	--	EXECUTE [prcAddIntFld] 'kn000', 'PrinterID'
	--	EXECUTE [prcAddIntFld] 'kn000', 'LineCount'
	--END
##########################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10001043
AS
/*
This procedure:
	- changes the type of departmenet in tb000 from int to varchar
	- moves bills templates from mc to bt000
	- moves entries templates from mc to et000
	- moves notes templates from mc to nt000
*/
	--EXECUTE [prcAlterFld] 'tb000', 'Department', 'VARCHAR (250) COLLATE ARABIC_CI_AI', 0, ''''''

-- Bills Templates:
	IF EXISTS(SELECT * FROM [mc000] WHERE [Type] IN (1, 2))
	BEGIN
		ALTER TABLE [bt000] DISABLE TRIGGER ALL
		EXECUTE [prcUpgrade_AddOldFlds]
		DELETE FROM [bt000]
		EXEC( '
		INSERT INTO [bt000]
				(
				[Type],
				[Number],
				[Name],
				[LatinName],
				[Abbrev],
				[LatinAbbrev],
				[DefStore],
				[DefStockAcc],
				[DefCostAcc],
				[DefBillAcc],
				[Color1],
				[Color2],
				[fldName],
				[fldQty],
				[fldBonus],
				[fldUnity],
				[fldUnitPrice],
				[fldTotalPrice],
				[fldStore],
				[fldDisc],
				[fldNotes],
				[bIsInput],
				[bIsOutput],
				[bAffectLastPrice],
				[bAffectCostPrice],
				[bAffectProfit],
				[bAffectCustPrice],
				[bDiscAffectCost],
				[bExtraAffectCost],
				[bAutoEntry],
				[bAutoPost],
				[bAutoEntryPost],
				[bExtraToCash],
				[bNoCostFld],
				[bNoVendorFld],
				[bNoSalesManFld],
				[bBarCodeBill],
				[bContInv],
				[bNoEntry],
				[bNoPost],
				[bPOSBill],
				[DefDiscAcc],
				[DefExtraAcc],
				[DefCashAcc],
				[bPrintReceipt],
				[bDiscAffectProfit],
				[bExtraAffectProfit],
				[fldQty2],
				[fldQty3],
				[fldProdDate],
				[fldExpireDate],
				[fldCostPtr],
				[fldStat],
				[fldLength],
				[fldWidth],
				[fldHeight],
				[BillType]
				)

			SELECT
				[Type],
				[Number],
				[asc1],
				[asc1],
				[asc2],
				[asc2],
				[asc4],
				[ParentType],
				[ParentNumber],
				[num1],
				[num2],
				[num3],
				CAST(CAST([Num4] AS [INT]) & 0x00000001 AS [INT]) / 0x00000001,
				CAST(CAST([Num4] AS [INT]) & 0x00000002 AS [INT]) / 0x00000002,
				CAST(CAST([Num4] AS [INT]) & 0x00000004 AS [INT]) / 0x00000004,
				CAST(CAST([Num4] AS [INT]) & 0x00000008 AS [INT]) / 0x00000008,
				CAST(CAST([Num4] AS [INT]) & 0x00000010 AS [INT]) / 0x00000010,
				CAST(CAST([Num4] AS [INT]) & 0x00000020 AS [INT]) / 0x00000020,
				CAST(CAST([Num4] AS [INT]) & 0x00000040 AS [INT]) / 0x00000040,
				CAST(CAST([Num4] AS [INT]) & 0x00000080 AS [INT]) / 0x00000080,
				CAST(CAST([Num4] AS [INT]) & 0x00000100 AS [INT]) / 0x00000100,
				CAST(CAST([Num4] AS [INT]) & 0x00000400 AS [INT]) / 0x00000400,
				CAST(CAST([Num4] AS [INT]) & 0x00000800 AS [INT]) / 0x00000800,
				CAST(CAST([Num4] AS [INT]) & 0x00001000 AS [INT]) / 0x00001000,
				CAST(CAST([Num4] AS [INT]) & 0x00002000 AS [INT]) / 0x00002000,
				CAST(CAST([Num4] AS [INT]) & 0x00004000 AS [INT]) / 0x00004000,
				CAST(CAST([Num4] AS [INT]) & 0x00008000 AS [INT]) / 0x00008000,
				CAST(CAST([Num4] AS [INT]) & 0x00010000 AS [INT]) / 0x00010000,
				CAST(CAST([Num4] AS [INT]) & 0x00020000 AS [INT]) / 0x00020000,
				CAST(CAST([Num4] AS [INT]) & 0x00040000 AS [INT]) / 0x00040000,
				CAST(CAST([Num4] AS [INT]) & 0x00080000 AS [INT]) / 0x00080000,
				CAST(CAST([Num4] AS [INT]) & 0x00100000 AS [INT]) / 0x00100000,
				CAST(CAST([Num4] AS [INT]) & 0x00200000 AS [INT]) / 0x00200000,
				CAST(CAST([Num4] AS [INT]) & 0x00800000 AS [INT]) / 0x00800000,
				CAST(CAST([Num4] AS [INT]) & 0x02000000 AS [INT]) / 0x02000000,
				CAST(CAST([Num4] AS [INT]) & 0x02000000 AS [INT]) / 0x02000000,
				CAST(CAST([Num4] AS [INT]) & 0x04000000 AS [INT]) / 0x04000000,
				CAST(CAST([Num4] AS [INT]) & 0x08000000 AS [INT]) / 0x08000000,
				CAST(CAST([Num4] AS [INT]) & 0x10000000 AS [INT]) / 0x10000000,
				CAST(CAST([Num4] AS [INT]) & 0x20000000 AS [INT]) / 0x20000000,
				CAST(CAST([Num4] AS [INT]) & 0x40000000 AS [INT]) / 0x40000000,
				[num5],
				[num6],
				[num7],
				CAST(CAST([Item] AS [INT]) & 0x00000001 AS [INT]) / 0x00000001,
				CAST(CAST([Item] AS [INT]) & 0x00000002 AS [INT]) / 0x00000002,
				CAST(CAST([Item] AS [INT]) & 0x00000004 AS [INT]) / 0x00000004,
				CAST(CAST([Item] AS [INT]) & 0x00000008 AS [INT]) / 0x00000008,
				CAST(CAST([Item] AS [INT]) & 0x00000010 AS [INT]) / 0x00000010,
				CAST(CAST([Item] AS [INT]) & 0x00000020 AS [INT]) / 0x00000020,
				CAST(CAST([Item] AS [INT]) & 0x00000040 AS [INT]) / 0x00000040,
				CAST(CAST([Item] AS [INT]) & 0x00000080 AS [INT]) / 0x00000080,
				CAST(CAST([Item] AS [INT]) & 0x00000100 AS [INT]) / 0x00000100,
				(CAST(CAST([Item] AS [INT]) & 0x00000200 AS [INT]) / 0x00000200) | (CAST(CAST([Item] AS [INT]) & 0x00000400 AS [INT]) / 0x00000400),
				(CAST(CAST([Item] AS [INT]) & 0x00000200 AS [INT]) / 0x00000200) | (CAST(CAST([Item] AS [INT]) & 0x00000400 AS [INT]) / 0x00000400),
				CAST(CAST([Item] AS [INT]) & 0x00000400 AS [INT]) / 0x00000400,
				(CAST(CAST([Item] AS [INT]) & 0x0000F000 AS [INT]) / 0x0000F000) - 1
			FROM
				[mc000]
			WHERE
				[Type] IN (1, 2)')
		DELETE FROM [mc000] WHERE [Type] IN (1, 2)
		ALTER TABLE [bt000] ENABLE TRIGGER ALL
	END

-- Entries Templates:
	IF EXISTS(SELECT * FROM [mc000] WHERE [Type] = 5)
	BEGIN
		ALTER TABLE [et000] DISABLE TRIGGER ALL
		DELETE FROM [et000]
		EXEC('
		INSERT INTO [et000]
				(
				[EntryType],
				[Number],
				[Name],
				[LatinName],
				[Abbrev],
				[LatinAbbrev],
				[DbTerm],
				[CrTerm],
				[DefAcc],
				[Color1],
				[Color2],
				[fldAccName],
				[fldDebit],
				[fldCredit],
				[fldNotes],
				[fldCurName],
				[fldCurVal],
				[fldStat],
				[fldCostPtr],
				[fldDate],
				[bAcceptCostAcc],
				[bDetailed],
				[bAutoPost]
				)

			SELECT
				3,
				[Number],
				[asc1],
				[asc1],
				[asc2],
				[asc2],
				[asc4],
				[asc5],
				[num1],
				[num2],
				[num3],
				CAST(CAST([Num4] AS [INT]) & 0x00000001 AS [INT]) / 0x00000001,
				CAST(CAST([Num4] AS [INT]) & 0x00000002 AS [INT]) / 0x00000002,
				CAST(CAST([Num4] AS [INT]) & 0x00000004 AS [INT]) / 0x00000004,
				CAST(CAST([Num4] AS [INT]) & 0x00000008 AS [INT]) / 0x00000008,
				CAST(CAST([Num4] AS [INT]) & 0x00000010 AS [INT]) / 0x00000010,
				CAST(CAST([Num4] AS [INT]) & 0x00000020 AS [INT]) / 0x00000020,
				CAST(CAST([Num4] AS [INT]) & 0x00000040 AS [INT]) / 0x00000040,
				CAST(CAST([Num4] AS [INT]) & 0x00000080 AS [INT]) / 0x00000080,
				CAST(CAST([Num4] AS [INT]) & 0x00000100 AS [INT]) / 0x00000100,
				CAST(CAST([Num4] AS [INT]) & 0x00008000 AS [INT]) / 0x00008000,
				CAST(CAST([Num4] AS [INT]) & 0x00010000 AS [INT]) / 0x00010000,
				CAST(CAST([Num4] AS [INT]) & 0x00020000 AS [INT]) / 0x00020000
			FROM
				[mc000]
			WHERE
				[Type] = 5')
		DELETE FROM [mc000] WHERE [Type] = 5
		ALTER TABLE [et000] ENABLE TRIGGER ALL
	END


-- Notes Templates:
	IF EXISTS(SELECT * FROM [mc000] WHERE [Type] = 7)
	BEGIN
		ALTER TABLE [nt000] DISABLE TRIGGER ALL
		DELETE FROM [nt000]
		EXEC('
		INSERT INTO [nt000]
				(
				[NoteType],
				[Number],
				[Name],
				[LatinName],
				[Abbrev],
				[LatinAbbrev],
				[bAutoEntry],
				[DefPayAcc],
				[DefRecAcc]
				)

			SELECT
				3,
				[Number],
				[asc1],
				[asc1],
				[asc2],
				[asc2],
				CAST(CAST([Num1] AS [INT]) & 0x00000001 AS [INT]) / 0x00000001,
				[num2],
				[num3]
			FROM
				[mc000]
			WHERE
				[Type] = 7')
		DELETE FROM [mc000] WHERE [Type] = 7
		ALTER TABLE [nt000] ENABLE TRIGGER ALL
	END


##########################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10001045
AS
/*
This procedure:
	- adds new fields to or000
	- delete unnecessary trigger from ac000
*/

	--EXECUTE [prcAddDateFld] 'or000', 'ExpDeliveryTime'
	--EXECUTE [prcAddDateFld] 'or000', 'ExpWaitingTime'

	EXECUTE [prcDropTrigger] 'trg_ac000_ParentChanges'

##########################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10001046
AS
/*
This procedure:
	-- delete unnecessary trigger from ac000
*/

	EXECUTE [prcDropTrigger] 'trg_ac000_Update'

##########################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10001047
AS
/*
This procedure:
	-- add new field to cp000
	-- and recreate the new index
*/
	EXECUTE [prcAddIntFld] 'cp000', 'Unity'

	DECLARE @DF [VARCHAR](255)

	/*
	SET @DF = (SELECT [Name] FROM [SYSOBJECTS] WHERE [Name] LIKE 'PK__cp00%')
	IF @DF IS NOT NULL
		EXECUTE ( 'ALTER TABLE cp000 DROP CONSTRAINT ' + @DF)
	*/
	EXECUTE [prcDropFldIndex] 'cp000', 'CustPtr'
	EXECUTE [prcDropFldConstraints] 'cp000', 'MatPtr'
	EXECUTE [prcDropFldConstraints] 'cp000', 'Price'

	ALTER TABLE [cp000] ADD PRIMARY KEY  CLUSTERED ([CustPtr], [MatPtr], [Unity])  ON [PRIMARY]

##########################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10001048
AS
/*
This procedure:
	-- delete unnecessary trigger from ac000
*/
	EXECUTE [prcDropTrigger] 'trg_ac000_Update'

##########################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10001050
AS
/*
This procedure:
	-- add new security field to st000
	-- fix security value for gr000
*/
	EXECUTE [prcAddIntFld] 'st000', 'Security', 1

	ALTER TABLE [gr000] DISABLE TRIGGER ALL
	UPDATE [gr000] SET [Security] = 1 WHERE [Security] = 0 OR [Security] IS NULL
	ALTER TABLE [gr000] ENABLE TRIGGER ALL

##########################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10001051
AS
/*
This procedure:
	-- add new price fields to mt000
*/
	EXECUTE [prcAddFloatFld] 'mt000', 'Whole2'
	EXECUTE [prcAddFloatFld] 'mt000', 'Half2'
	EXECUTE [prcAddFloatFld] 'mt000', 'Retail2'
	EXECUTE [prcAddFloatFld] 'mt000', 'EndUser2'
	EXECUTE [prcAddFloatFld] 'mt000', 'Export2'
	EXECUTE [prcAddFloatFld] 'mt000', 'Vendor2'
	EXECUTE [prcAddFloatFld] 'mt000', 'MaxPrice2'
	EXECUTE [prcAddFloatFld] 'mt000', 'LastPrice2'
	EXECUTE [prcAddFloatFld] 'mt000', 'Whole3'
	EXECUTE [prcAddFloatFld] 'mt000', 'Half3'
	EXECUTE [prcAddFloatFld] 'mt000', 'Retail3'
	EXECUTE [prcAddFloatFld] 'mt000', 'EndUser3'
	EXECUTE [prcAddFloatFld] 'mt000', 'Export3'
	EXECUTE [prcAddFloatFld] 'mt000', 'Vendor3'
	EXECUTE [prcAddFloatFld] 'mt000', 'MaxPrice3'
	EXECUTE [prcAddFloatFld] 'mt000', 'LastPrice3'

##########################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10001052
AS
/*
This procedure:
	-- drop unwanted price fields from mt000
*/
	EXECUTE [prcDropFld] 'mt000', 'LastPriceDate2'
	EXECUTE [prcDropFld] 'mt000', 'LastPriceDate3'


##########################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10001054
AS
/*
This procedure:
	-- add GUID fields to all tables that does not have one.
	-- add CostPtr and ClassPtr fields to di000
	-- add Latin[Name] field for all tabled that does not have one.
*/
	EXECUTE [prcAddROWGUIDCOLFld] 'mt000'
	EXECUTE [prcAddROWGUIDCOLFld] 'cu000'
	EXECUTE [prcAddROWGUIDCOLFld] 'bu000'
	EXECUTE [prcAddROWGUIDCOLFld] 'di000'
	EXECUTE [prcAddIntFld] 'di000', 'CostPtr'
	EXECUTE [prcAddIntFld] 'di000', 'ClassPtr'
	EXECUTE [prcAddROWGUIDCOLFld] 'ch000'
	EXECUTE [prcAddROWGUIDCOLFld] 'py000'
	EXECUTE [prcAddCharFld] 'st000', 'LatinName', 250
	EXECUTE [prcAddROWGUIDCOLFld] 'st000'
	EXECUTE [prcAddCharFld] 'gr000', 'LatinName', 250
	EXECUTE [prcAddCharFld] 'my000', 'LatinName', 250
	EXECUTE [prcAddCharFld] 'my000', 'LatinPartName', 250
	EXECUTE [prcAddROWGUIDCOLFld] 'my000'
	EXECUTE [prcAddROWGUIDCOLFld] 'bm000'
	EXECUTE [prcAddCharFld] 'ac000', 'LatinName', 250
	EXECUTE [prcAddROWGUIDCOLFld] 'ac000'
	EXECUTE [prcAddROWGUIDCOLFld] 'ce000'
	EXECUTE [prcAddROWGUIDCOLFld] 'en000'
	EXECUTE [prcAddCharFld] 'fm000', 'LatinName', 250
	EXECUTE [prcAddROWGUIDCOLFld] 'fm000'
	EXECUTE [prcAddROWGUIDCOLFld] 'mi000'
	EXECUTE [prcAddROWGUIDCOLFld] 'mn000'
	EXECUTE [prcAddCharFld] 'co000', 'LatinName', 250
	EXECUTE [prcAddROWGUIDCOLFld] 'co000'
	--EXECUTE [prcAddROWGUIDCOLFld] 'km000'
	EXECUTE [prcAddROWGUIDCOLFld] 'sm000'
	EXECUTE [prcAddROWGUIDCOLFld] 'sd000'
	EXECUTE [prcAddROWGUIDCOLFld] 'as000'

##########################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10001056
AS
/*
This procedure:
*/
	DECLARE @SQL [VARCHAR](8000)

	IF [dbo].[fnObjectExists]('ma000.DiscAcc') <> 0
		RETURN

	CREATE TABLE  [#ma](
		[Type]		[INT],
		[Number]	[INT],
		[BillType]	[INT] DEFAULT 0,
		[MatAcc]	[INT] DEFAULT 0,
		[DiscAcc]	[INT] DEFAULT 0,
		[ExtraAcc]	[INT] DEFAULT 0,
		[VATAcc]	[INT] DEFAULT 0,
		[StoreAcc]	[INT] DEFAULT 0,
		[CostAcc]	[INT] DEFAULT 0)

	SET @SQL = '
	INSERT INTO [#ma] ([Type], [Number], [BillType], [MatAcc])
		SELECT	1, [MatPtr], [Type], [Account]
		FROM	[ma000]
		WHERE	[Type] BETWEEN 1 AND 1024

	INSERT INTO [#ma] ([Type], [Number], [BillType], [MatAcc])
		SELECT	2, [MatPtr], [Type] - 1024, [Account]
		FROM	[ma000]
		WHERE	[Type] BETWEEN 1025 AND 8192

	INSERT INTO [#ma] ([Type], [Number], [BillType], [CostAcc])
		SELECT	1, [MatPtr], [Type] - 8192, [Account]
		FROM	[ma000]
		WHERE	[Type] BETWEEN 8193 AND 9216

	INSERT INTO [#ma] ([Type], [Number], [BillType], [CostAcc])
		SELECT	2, [MatPtr], [Type] - 9216, [Account]
		FROM	[ma000]
		WHERE	[Type] BETWEEN 9217 AND 16384

	INSERT INTO [#ma] ([Type], [Number], [BillType], [StoreAcc])
		SELECT	1, [MatPtr], [Type] - 16384, [Account]
		FROM	[ma000]
		WHERE	[Type] BETWEEN 16385 AND 17408

	INSERT INTO [#ma] ([Type], [Number], [BillType], [StoreAcc])
		SELECT	2, [MatPtr], [Type] - 17408, [Account]
		FROM	[ma000]
		WHERE	[Type] >= 17409

	DROP TABLE [ma000]'

	EXECUTE [prcExecuteSQL] @SQL

	SET @SQL = '
	CREATE TABLE [dbo].[ma000](
		[Type]		[INT] NOT NULL,
		[Number]	[INT] NOT NULL,
		[BillType]	[INT] NOT NULL,
		[MatAcc]	[INT] NOT NULL,
		[DiscAcc]	[INT] NOT NULL,
		[ExtraAcc]	[INT] NOT NULL,
		[VATAcc]	[INT] NOT NULL,
		[StoreAcc]	[INT] NOT NULL,
		[CostAcc]	[INT] NOT NULL
			PRIMARY KEY ([Type], [Number], [BillType]))'

	EXECUTE [prcExecuteSQL] @SQL

	SET @SQL = 'INSERT INTO [ma000] ([Type], [Number], [BillType], [MatAcc], [StoreAcc], [CostAcc], [DiscAcc], [ExtraAcc], [VATAcc])
		SELECT [Type], [Number], [BillType], MAX([MatAcc]), MAX([StoreAcc]), MAX([CostAcc]), 0, 0, 0
		FROM [#ma]
		GROUP BY [Type], [Number], [BillType]

	ALTER TABLE [bt000] DISABLE TRIGGER ALL

	UPDATE [bt000] SET [DefVATAcc] = [DefExtraAcc] WHERE [DefVATAcc] = 0

	ALTER TABLE [bt000] ENABLE TRIGGER ALL

	DROP TABLE [#ma]'
	EXECUTE [prcExecuteSQL] @SQL

##########################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10001057
AS
/*
This procedure:
	- upgrades from version 10001057 to 10001058.
	- is usually called from prcUpgradeDatabase procedure.
*/
	DECLARE @RetVal AS [INTEGER]
	EXECUTE @RetVal = [prcAddFloatFld] 'bi000', 'VATRatio'
	IF @RetVal = 0
		RETURN
	
	-- ALTER TABLE bi000 ADD VATRatio FLOAT NOT NULL DEFAULT 0
	ALTER TABLE [bi000] DISABLE TRIGGER ALL
	EXECUTE ('UPDATE [bi000] SET [VATRatio] = [VAT]')

	EXEC('UPDATE [bi000] SET [VAT] = CASE
				WHEN [bi].[Qty] = 0 OR
						[bu].[Total] = 0 OR
						[bi].[Qty] IS NULL OR
						[bu].[Total] IS NULL OR
						[bu].[TotalDisc] IS NULL OR
						[bu].[TotalExtra] IS NULL OR
						[bi].[Discount] IS NULL OR
						[bi].[Extra] IS NULL
						THEN 0
				ELSE
				([bi].[VATRatio] * (([bi].[Price] * [bi].[Qty]) - (((([bi].[Price] / [bi].[Qty]) / [bu].[Total]) * [bu].[TotalDisc]) + [bi].[Discount])+(((([bi].[Price] / [bi].[Qty]) / [bu].[Total]) * [bu].[TotalExtra]) + [bi].[Extra]))) / 100
				END
			FROM [bu000] AS [bu] INNER JOIN [bi000] AS [bi] ON [bu].[Type] = [bi].[Type] AND [bu].[Number] = [bi].[Parent]')
	ALTER TABLE [bi000] ENABLE TRIGGER ALL

	ALTER TABLE [bu000] DISABLE TRIGGER ALL
	EXEC( 'UPDATE [bu000] SET [VAT] = ISNULL((SELECT Sum ([VAT]) FROM [bi000] WHERE [bi000].[Type] = [bu].[Type] AND [bi000].[Parent] = [bu].[Number]), 0)
		FROM [bu000] AS [bu]
		WHERE [bu].[VAT] <> ISNULL((SELECT Sum ([VAT]) FROM [bi000] WHERE [bi000].[Type] = [bu].[Type] AND [bi000].[Parent] = [bu].[Number]), 0)')
	ALTER TABLE [bu000] ENABLE TRIGGER ALL

##########################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10001064
AS
/*
This procedure:
	- upgrades from version 10001064 to 10001065.
	- is usually called from prcUpgradeDatabase procedure.
*/
	EXECUTE [prcAddFloatFld] 'mi000', 'Qty2'
	EXECUTE [prcAddFloatFld] 'mi000', 'Qty3'

	ALTER TABLE [bu000] DISABLE TRIGGER ALL
	UPDATE [bu000] SET [Security] = 1 WHERE [Security] = 0
	ALTER TABLE [bu000] ENABLE TRIGGER ALL

	ALTER TABLE [ce000] DISABLE TRIGGER ALL
	UPDATE [ce000] SET [Security] = 1 WHERE [Security] = 0
	ALTER TABLE [ce000] ENABLE TRIGGER ALL

	EXECUTE [prcAddIntFld] 'et000', 'FldContraAcc'
	EXECUTE [prcAddIntFld] 'en000', 'ContraAcc'

##########################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10001065
AS
/*
This procedure:
	- upgrades from version 10001065 to 10001066.
	- is usually called from prcUpgradeDatabase procedure.
*/
	EXECUTE [prcAddIntFld] 'di000', 'ContraAcc'
	EXECUTE [prcAddBitFld] 'bt000', 'bCostToItems'

##########################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10001069
AS
/*
This procedure:
	- upgrades from version 10001069 to 10001070.
	- is usually called from prcUpgradeDatabase procedure.
*/

	ALTER TABLE [bt000] DISABLE TRIGGER ALL

	EXECUTE [prcAddBitFld] 'bt000', 'bCostToItems'

	IF [dbo].[fnObjectExists]( 'bt000.DiscToItems') <> 0
		BEGIN
			EXEC('
				UPDATE [bt000] SET [bCostToItems] = ISNULL([DiscToItems], 0)
				EXECUTE [prcDropFld] ''bt000'', ''DiscToItems''
				')
		END

	EXECUTE [prcAddBitFld] 'bt000', 'bGenContraAcc'

	ALTER TABLE [bt000] ENABLE TRIGGER ALL

##########################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10001081
AS
/*
This procedure:
	- upgrades from version 10001081 to 10001082.
	- is usually called from prcUpgradeDatabase procedure.
*/
	-- delete tables
	DELETE FROM [mc000] WHERE [Type] = 4

	-- move users:
	IF EXISTS(SELECT * FROM [mc000] WHERE [Type] = 0)
	BEGIN
		ALTER TABLE [us000] DISABLE TRIGGER ALL -- this will help solving a bug when upgrading from converted paradox database over an existing ameen database
		DELETE [us000]
		INSERT INTO [us000] ([Number], [LoginName], [Password]) SELECT [Number], [Asc2], [Asc1] FROM [mc000] WHERE [Type] = 0
		DELETE [mc000] WHERE [Type] = 0

		UPDATE [us000] SET
				[bAdmin] = 			CASE (SELECT [Num1] FROM [mc000] WHERE [Type] = 6 AND [Number] = [us].[Number] AND [Item] = 1)	WHEN 3 THEN 1 WHEN 2 THEN 1	WHEN 1 THEN 1	ELSE 0 END,
				[MaxDiscount] = 	ISNULL((SELECT [Num1] FROM [mc000] WHERE [Type] = 6 AND [Number] = [us].[Number] AND [Item] = 8192), 0),
				[MinPrice] = 		ISNULL((SELECT [Num1] FROM [mc000] WHERE [Type] = 6 AND [Number] = [us].[Number] AND [Item] = 8193), 0),
				[bActive] = 		1
		FROM [us000] AS [us]
		ALTER TABLE [us000] ENABLE TRIGGER ALL

		-- re-create ui000 using the old structure.
		DROP TABLE [ui000]
		CREATE TABLE [ui000] (
			[GUID]  [uniqueidentifier] ROWGUIDCOL  NOT NULL DEFAULT (newid()),
			[UserGUID] [uniqueidentifier] NOT NULL ,
			[ReportId] [float] NOT NULL DEFAULT (0),
			[Enter] [int] NOT NULL DEFAULT (0),
			[Browse] [int] NOT NULL DEFAULT (0),
			[Modify] [int] NOT NULL DEFAULT (0),
			[Delete] [int] NOT NULL DEFAULT (0),
			[Post] [int] NOT NULL DEFAULT (0),
			[GenEntry] [int] NOT NULL DEFAULT (0),
			[PostEntry] [int] NOT NULL DEFAULT (0),
			[ChangePrice] [int] NOT NULL DEFAULT (0),
			[ReadPrice] [int] NOT NULL DEFAULT (0),
			[SubId] [uniqueidentifier] NULL ,
			PRIMARY KEY  CLUSTERED ([GUID]))

		EXEC('
					INSERT INTO [ui000] ([UserGUID], [ReportId], [Enter], [Browse], [Modify], [Delete], [Post], [GenEntry], [PostEntry], [ChangePrice], [ReadPrice])
						SELECT
							(SELECT [GUID] FROM [us000] WHERE [Number] = [mc].[Number]), -- UserGUID
							ISNULL([Item], 0), -- ReportId
							ISNULL([Num1], 0), -- Enter
							ISNULL([Num3], 0), -- Browse
							ISNULL([Num2], 0), -- Modify
							ISNULL([Num4], 0), -- Delete
							ISNULL([Num5], 0), -- Post
							ISNULL([Num6], 0), -- GenEntry
							ISNULL([Num7], 0), -- PostEnty
							ISNULL([Num8], 0), -- ChangePrice
							ISNULL([ParentType], 0) -- ReadPrice
						FROM
							[mc000] AS [mc]
						WHERE
							[Type] = 6 AND [Item] NOT IN (1, 8192, 8193)
					DELETE [mc000] WHERE [Type] = 6')
	END

	-- move shortcuts:
	IF EXISTS(SELECT * FROM [mc000] WHERE [Type] = 10)
	BEGIN
		DELETE [sh000]
		INSERT INTO [sh000] ([Number], [Type], [Key], [Text], Cmd16, Cmd32)
			SELECT [Item], [ParentType], [ParentNumber], [Asc1], [Num1], [Num2]
			FROM [mc000]
			WHERE [Type] = 10
		DELETE [mc000] WHERE [Type] = 10
	END

##########################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10001084
AS
	-- 1. Delete unused fields from sm000 Special Offers
	ALTER TABLE [sm000] DISABLE TRIGGER ALL

	EXECUTE [prcDropFld] 'sm000', 'Num1'
	EXECUTE [prcDropFld] 'sm000', 'Num2'
	EXECUTE [prcDropFld] 'sm000', 'Num3'
	EXECUTE [prcDropFld] 'sm000', 'Num4'
	EXECUTE [prcDropFld] 'sm000', 'Num5'
	EXECUTE [prcDropFld] 'sm000', 'Num6'
	EXECUTE [prcDropFld] 'sm000', 'Str1'
	EXECUTE [prcDropFld] 'sm000', 'Str2'
	EXECUTE [prcDropFld] 'sm000', 'Str3'
	EXECUTE [prcDropFld] 'sm000', 'Str4'
	EXECUTE [prcDropFld] 'sm000', 'Date2' -- Don't delete Date1

	-- 2. Add new fields to sm000
	EXECUTE [prcAddBitFld] 'sm000', 'bAddMain'

	ALTER TABLE [sm000] ENABLE TRIGGER ALL

	-- 3. Delete unused fields from sd000 Special Offer Items
	ALTER TABLE [sd000] DISABLE TRIGGER ALL

	EXECUTE [prcDropFld] 'sd000', 'Num1'
	EXECUTE [prcDropFld] 'sd000', 'Num2'
	EXECUTE [prcDropFld] 'sd000', 'Num3'
	EXECUTE [prcDropFld] 'sd000', 'Num4'
	EXECUTE [prcDropFld] 'sd000', 'Num5'
	EXECUTE [prcDropFld] 'sd000', 'Num6'
	EXECUTE [prcDropFld] 'sd000', 'Str1'
	EXECUTE [prcDropFld] 'sd000', 'Str2'
	EXECUTE [prcDropFld] 'sd000', 'Str3'
	EXECUTE [prcDropFld] 'sd000', 'Str4'
	EXECUTE [prcDropFld] 'sd000', 'Date1'
	EXECUTE [prcDropFld] 'sd000', 'Date2'

	-- 4. Add new fields to sd000
	EXECUTE [prcAddIntFld] 'sd000', 'PriceFlag'
	EXECUTE [prcAddIntFld] 'sd000', 'CurrencyPtr'
	EXECUTE [prcAddFloatFld] 'sd000', 'CurrencyVal'
	EXECUTE [prcAddIntFld] 'sd000', 'PolicyType'

	ALTER TABLE [sd000] ENABLE TRIGGER ALL

	-- 5. Copy products ingredients from sm000 into ng000 and ni00
	-- first, check to see if ng000 is in the old structure.
	-- there is a case where ng is not created yet in the db, when opened in GUID ver, its created with a new stucture using MatGUID, StoreGUID, ... et.
	-- such cases nothing is to be made.
	/*IF [dbo].[fnObjectExists]('ng000.MatPtr') <> 0 AND EXISTS( SELECT * FROM [sm000] WHERE [Type] = 2)
		EXECUTE( '
			DELETE [ng000]
			DELETE [ni000]
			INSERT INTO
					[ng000]( [Number], [MatPtr], [PrepareTime], [StorePtr], [Price], [Qty], [Notes])
				SELECT
					[Number], [MatPtr], [Date1], [StorePtr], [Price], [Qty], [Notes]
				FROM
					[sm000]
				WHERE
					[Type] = 2

			INSERT INTO
					[ni000]( [Number], [Parent], [MatPtr], [Qty], [Unity], [Notes])
				SELECT
					[Item], [Number], [MatPtr], [Qty], [Unity], [Notes]
				FROM
					[sd000]
				WHERE
					[Type] = 2

		-- 6. Delete products ingredients from sm000
				DELETE FROM [sm000] WHERE [Type] = 2
				DELETE FROM [sd000] WHERE [Type] = 2')*/

	-- 6. Copy special offers from mc000 into sm000 and sd000
	-- IF EXISTS( SELECT * FROM mc000 WHERE [Type] = 15)
	-- BEGIN
	--	INSERT INTO
	--		sm000 ( [Number], [
	-- END
	-- 6. Delete sepcial offers from mc000
	DELETE FROM [mc000] WHERE [Type] = 15
	-- 7. Copy Taxes from mc000 into tx000
	IF EXISTS (SELECT * FROM [mc000] WHERE [Type] = 22)
	BEGIN
		EXECUTE ('
		DELETE FROM [tx000]
		INSERT INTO
			[tx000] ([Number], [Type], [GroupGUID], [Val1], [Val2], [Val3], [Val4], [Val5])
		SELECT
			[Item], 1, [gr000].[GUID], [Num1], [Num2], [Num3], [Num4], [Num5]
		FROM
			[mc000] inner join [gr000] ON [mc000].[ParentType] = [gr000].[Number]
		WHERE [mc000].[Type] = 22
		')
	-- 8. Delete Taxed from mc000
		DELETE FROM [mc000] WHERE [Type] = 22
	END
	DELETE FROM [mc000] WHERE [Type] = 19 -- POSSecurity

##########################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10001086
AS
	--EXECUTE [prcAddIntFld] 'ng000', 'Security', 1

##########################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10001087
AS
	EXECUTE [prcAddCharFld] 'cu000', 'Country', 100
	EXECUTE [prcAddCharFld] 'cu000', 'Hoppies', 100
	EXECUTE [prcAddCharFld] 'cu000', 'Gender', 100
	EXECUTE [prcAddCharFld] 'cu000', 'Certificate', 100
	EXECUTE [prcAddDateFld] 'cu000', 'DateOfBirth'
	EXECUTE [prcAddCharFld] 'cu000', 'Job', 100
	EXECUTE [prcAddCharFld] 'cu000', 'JobCategory', 100
	EXECUTE [prcAddCharFld] 'cu000', 'UserFld1', 100
	EXECUTE [prcAddCharFld] 'cu000', 'UserFld2', 100
	EXECUTE [prcAddCharFld] 'cu000', 'UserFld3', 100
	EXECUTE [prcAddCharFld] 'cu000', 'UserFld4', 100

##########################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10001089
AS
	/* This procedure fixes a bug in saving bills if Store field is not
	   visible and the store is different from the store specified in the
	   bill.
	*/
	ALTER TABLE [bi000] DISABLE TRIGGER ALL
	EXECUTE('
	UPDATE
		[bi000]
	SET
		[StorePtr] = [bu].[StorePtr]
	FROM
		[bi000] INNER JOIN [bu000] AS [bu] ON
		[bi000].[Type] = [bu].[Type] AND
		[bi000].[Parent] = [bu].[Number] INNER JOIN [bt000] AS [bt] ON
		[bu].[Type] = (([bt].[Type] - 1) * 256 + [bt].[Number])
	WHERE
		[bt].[FldStore] <= 0')
	ALTER TABLE [bi000] ENABLE TRIGGER ALL

##########################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10001091
AS
	/* This procedure fixes a bug in saving groups and setting parent as
	   -1 instead of 0
	*/
	UPDATE [gr000] SET [Parent] = 0 WHERE [Parent] = -1

##########################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10001094
AS
	--This procedure adds new fields CostPtr1, CostPtr2 to ch000

	DECLARE @RetVal AS [INT]
	
	EXECUTE [prcAddIntFld] 'ch000', 'CostPtr1'
	EXECUTE @RetVal = [prcAddIntFld] 'ch000', 'CostPtr2'
	IF @RetVal = 0
		RETURN

	EXECUTE( '
			UPDATE
				[ch000]
			SET
				[CostPtr1] = [en].[CostPoint], [CostPtr2] = [en].[CostPoint]
			FROM
				[ch000] INNER JOIN [ce000]
				ON [ch000].[CEntry1] = [ce000].[Number]
				AND [ce000].[Type] = 1 INNER JOIN [en000] AS [en] ON
				[en].[Type] = [ce000].[Type] AND [en].[Parent] = [ce000].[Number]')

##########################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10001095
AS
	-- This procedure adds new field AccPtr2 to ch000
	EXECUTE [prcAddIntFld] 'ch000', 'AccPtr2'

##########################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10001107
AS
	-- This procedure Fixes the CustJob missing field

	IF [dbo].[fnObjectExists]('cu000.Job') = 0
	BEGIN
		EXECUTE [prcDropFld] 'cu000', 'JobCatagory'
		EXECUTE [prcDropFld] 'cu000', 'UserFld1'
		EXECUTE [prcDropFld] 'cu000', 'UserFld2'
		EXECUTE [prcDropFld] 'cu000', 'UserFld3'
		EXECUTE [prcDropFld] 'cu000', 'UserFld4'

		EXECUTE [prcAddCharFld] 'cu000', 'Job', 100
		EXECUTE [prcAddCharFld] 'cu000', 'JobCategory', 100
		EXECUTE [prcAddCharFld] 'cu000', 'UserFld1', 100
		EXECUTE [prcAddCharFld] 'cu000', 'UserFld2', 100
		EXECUTE [prcAddCharFld] 'cu000', 'UserFld3', 100
		EXECUTE [prcAddCharFld] 'cu000', 'UserFld4', 100
	END

##########################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10001115
AS
	-- This procedure Adds new fields to oi000 and or000
	DECLARE @CurVal As [FLOAT]

	SELECT @CurVal = [CurrencyVal] FROM [my000] WHERE [Number] = 1

	--EXECUTE [prcAddIntFld] 'oi000', 'CurPtr', 1
	--EXECUTE [prcAddFloatFld] 'oi000', 'CurVal', @CurVal
	--EXECUTE [prcAddDateFld] 'oi000', 'ExpireDate'
	--EXECUTE [prcAddDateFld] 'oi000', 'ProductionDate'
	--EXECUTE [prcAddFloatFld] 'oi000', 'Length'
	--EXECUTE [prcAddFloatFld] 'oi000', 'Width'
	--EXECUTE [prcAddFloatFld] 'oi000', 'Height'
	--EXECUTE [prcAddFloatFld] 'or000', 'Payment'

###############################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10001146
AS
	-- this was put to re[Name] field Provenace to Provenance
	-- the procedure also deals with the unexplained case were both Provenace and Provenance existed ... wich did accure.
	EXECUTE [prcRenameFld] 'mt000', 'Provenace', 'Provenance'
	EXECUTE [prcDropFld] 'mt000', 'Provenace'

#########################################################
CREATE PROCEDURE prcUpgradeDatabase_From10001183
AS
	-- call the upgrade procedure resposible for adding field PayType to or000 and fixing its value
	DECLARE
		@SalesBills [VARCHAR](50),
		@CashAcc [VARCHAR](50),
		@FreeAcc [VARCHAR](50),
		@ManagementAcc [VARCHAR](50)

	SELECT
		@SalesBills = ISNULL((SELECT TOP 1 [Value] FROM [op000] WHERE [Name] = 'AmnPOS_SalesBills'), '0'), 
		@CashAcc = ISNULL((SELECT TOP 1 [Value] FROM [op000] WHERE [Name] = 'AmnPOS_DRAWERACCNAME'), '0'), 
		@FreeAcc = ISNULL((SELECT TOP 1 [Value] FROM [op000] WHERE [Name] = 'AmnPOS_FREEACCNAME'), '0'),
		@ManagementAcc	= ISNULL((SELECT TOP 1 [Value] FROM [op000] WHERE [Name] = 'AmnPOS_MANAGMENTACC'), '0')

	--EXECUTE [prcAddIntFld] 'or000', 'PayType', 0

--	if exists(select * from [sysobjects] where [Name] = 'or000' and [xtype] = 'u')
		--EXECUTE ('
		--	UPDATE [o] SET [PayType] = (CASE [b].[CustAcc] WHEN ' + @CashAcc + ' THEN 1 WHEN ' + @FreeAcc + ' THEN 3 WHEN ' + @ManagementAcc + ' THEN 4 ELSE 5 END)
		--		FROM [or000] AS [o] INNER JOIN [bu000] AS [b] ON [o].[SaleBillNum] = [b].[Number]
		--		WHERE 
		--			[o].[OrderState] = 1
		--			AND [b].[Type] = ' + @SalesBills)

#########################################################
CREATE PROCEDURE prcUpgradeDatabase_From10001999
AS
/*
This procedure:
	- upgardes to GUID.
*/

	-- ac000:
	EXECUTE [prcLog] 'Upgrading ac000'
	ALTER TABLE [ac000] DISABLE TRIGGER ALL
	EXEC [prcDropTrigger] 'trg_ac000_checkConstraints'
	EXEC [prcDropTrigger] 'trg_ac000_general'
	EXEC [prcDropTrigger] 'trg_ac000_Order'
	EXEC [prcDropTrigger] 'trg_ac000_ChkDuplicateCode'
	EXEC [prcDropTrigger] 'trg_ac000_delete'
	EXECUTE [prcAddLookupGUIDFld] 'ac000', 'ParentGUID', 'Parent', DEFAULT, 'ac000'
	EXECUTE [prcAddLookupGUIDFld] 'ac000', 'FinalGUID', 'Final', DEFAULT, 'ac000'
	EXECUTE [prcAddLookupGUIDFld] 'ac000', 'CurrencyGUID', 'CurrencyPtr', DEFAULT, 'my000'
	EXECUTE [prcDropFld] 'ac000', 'Branch'
	EXECUTE [prcAddGUIDFld] 'ac000', 'BranchGUID'
	
	-- bi000:
	EXECUTE [prcLog] 'Upgrading bi000'
	EXECUTE [prcAddLookupGUIDFld] 'bi000', 'ParentGUID', 'Type', 'Parent', 'bu000', 'Type', 'Number'
	EXECUTE [prcAddLookupGUIDFld] 'bi000', 'MatGUID', 'MatPtr', DEFAULT, 'mt000'
	EXECUTE [prcAddLookupGUIDFld] 'bi000', 'CurrencyGUID', 'CurrencyPtr', DEFAULT, 'my000'
	EXECUTE [prcAddLookupGUIDFld] 'bi000', 'StoreGUID', 'StorePtr', DEFAULT, 'st000'
	EXECUTE [prcAddLookupGUIDFld] 'bi000',  'CostGUID', 'CostPtr', DEFAULT, 'co000'

	-- bt000:
	EXECUTE [prcLog] 'Upgrading bt000'
	EXECUTE [prcDropTrigger] 'trg_bt000_general'
	EXECUTE [prcAddLookupGUIDFld] 'bt000', 'DefStoreGUID', 'DefStore', DEFAULT, 'st000'
	EXECUTE [prcAddLookupGUIDFld] 'bt000', 'DefBillAccGUID', 'DefBillAcc', DEFAULT, 'ac000'
	EXECUTE [prcAddLookupGUIDFld] 'bt000', 'DefCashAccGUID', 'DefCashAcc', DEFAULT, 'ac000'
	EXECUTE [prcAddLookupGUIDFld] 'bt000', 'DefDiscAccGUID', 'DefDiscAcc', DEFAULT, 'ac000'
	EXECUTE [prcAddLookupGUIDFld] 'bt000', 'DefExtraAccGUID', 'DefExtraAcc', DEFAULT, 'ac000'
	EXECUTE [prcAddLookupGUIDFld] 'bt000', 'DefVATAccGUID', 'DefVATAcc', DEFAULT, 'ac000'
	EXECUTE [prcAddLookupGUIDFld] 'bt000', 'DefCostAccGUID', 'DefCostAcc', DEFAULT, 'ac000'
	EXECUTE [prcAddLookupGUIDFld] 'bt000', 'DefStockAccGUID', 'DefStockAcc', DEFAULT, 'ac000'
	EXECUTE [prcAddBitFld] 'bt000', 'bMergeCustItems'
	EXECUTE [prcAddBitFld] 'bt000', 'bMergeDiscItems'
	EXECUTE [prcAddBitFld] 'bt000', 'bMergeMatItems'
	ALTER TABLE [bt000] DISABLE TRIGGER ALL
	EXECUTE [prcExecuteSQL] 'UPDATE [bt000] SET [bMergeCustItems] = %0, [bMergeDiscItems] = %0, [bMergeMatItems] = %0', [dbo.fnOption_GetBit('AmnCfg_ShortEntries', 0)]
	EXECUTE ('UPDATE [bt000] SET [SortNum] = [Number], [bCostToItems] = ~bCostToItems')
	ALTER TABLE [bt000] ENABLE TRIGGER ALL

	-- bu000:
	EXECUTE [prcLog] 'Upgrading bu000'
	EXECUTE [prcAddLookupGUIDFld] 'bu000', 'TypeGUID', 'Type', DEFAULT, 'bt000', 'Number', DEFAULT, 'bu000.Type < 256 AND lu.Type = 1', 0
	EXECUTE [prcAddLookupGUIDFld] 'bu000', 'TypeGUID', 'Type', DEFAULT, 'bt000', 'Number+255', DEFAULT, 'bu000.Type >= 256 AND lu.Type = 2', 0
	
	EXECUTE [prcAddLookupGUIDFld] 'bu000', 'CustGUID', 'CustPtr', DEFAULT, 'cu000'
	EXECUTE [prcAddLookupGUIDFld] 'bu000', 'CurrencyGUID', 'CurrencyPtr', DEFAULT, 'my000'
	EXECUTE [prcAddLookupGUIDFld] 'bu000', 'StoreGUID', 'StorePtr', DEFAULT, 'st000'
	EXECUTE [prcAddLookupGUIDFld] 'bu000', 'CustAccGUID', 'CustAcc', DEFAULT, 'ac000'
	EXECUTE [prcAddLookupGUIDFld] 'bu000', 'MatAccGUID', 'MatAcc', DEFAULT, 'ac000'
	EXECUTE [prcAddLookupGUIDFld] 'bu000', 'ItemsDiscAccGUID', 'ItemsDiscAcc', DEFAULT, 'ac000'
	EXECUTE [prcAddLookupGUIDFld] 'bu000', 'BonusDiscAccGUID', 'BonusDiscAcc', DEFAULT, 'ac000'
	EXECUTE [prcAddLookupGUIDFld] 'bu000', 'FPayAccGUID', 'FPayAcc', DEFAULT, 'ac000'
	EXECUTE [prcAddLookupGUIDFld] 'bu000', 'CostGUID', 'CostPtr', DEFAULT, 'co000'
	EXECUTE [prcAddGUIDFld] 'bu000', 'UserGUID'
	EXECUTE [prcAddLookupGUIDFld] 'bu000', 'CheckTypeGUID', 'PayType', DEFAULT, 'nt000', 'Number + 1', DEFAULT, 'PayType >= 2', 0, 'UPDATE bu000 SET PayType = 2 WHERE PayType > 2'
	EXECUTE [prcLinkER] 'bu000', 'FPayEntry'
	EXECUTE [prcLinkER] 'bu000', 'CEntry'
	EXECUTE [prcDropFld] 'bu000', 'BDiscPtr'
	EXECUTE [prcDropFld] 'bu000', 'AdnPtr'
	
	EXECUTE ('
		ALTER TABLE [bu000] DISABLE TRIGGER ALL
		UPDATE [bu000] SET [userGUID] = ISNULL(u.[GUID], 0x0) FROM [bu000] AS b INNER JOIN [us000] u ON b.[salesmanPtr] = u.[number] WHERE b.[salesmanPtr] IS NOT NULL
		ALTER TABLE [bu000] ENABLE TRIGGER ALL')

	-- ce000:
	EXECUTE [prcLog] 'Upgrading ce000'
	EXECUTE [prcAddLookupGUIDFld] 'ce000', 'CurrencyGUID', 'CurrencyPtr', DEFAULT, 'my000'
	EXECUTE [prcDropFld] 'ce000', 'ParentType'
	EXECUTE [prcDropFld] 'ce000', 'ParentNumber'

	-- ch000:
	EXECUTE [prcLog] 'Upgrading ch000'
	EXECUTE [prcAddLookupGUIDFld] 'ch000', 'TypeGUID', 'Type', DEFAULT, 'nt000'
	EXECUTE [prcAddLookupGUIDFld] 'ch000', 'ParentGUID', 'ParentType', 'Parent', 'bu000', 'Type + 1', 'Number', DEFAULT, 0
	EXECUTE [prcAddLookupGUIDFld] 'ch000', 'AccountGUID', 'Account', DEFAULT, 'ac000'
	EXECUTE [prcAddLookupGUIDFld] 'ch000', 'CurrencyGUID', 'CurrencyPtr', DEFAULT, 'my000'
	EXECUTE [prcAddLookupGUIDFld] 'ch000', 'Cost1GUID', 'CostPtr1', DEFAULT, 'co000'
	EXECUTE [prcAddLookupGUIDFld] 'ch000', 'Cost2GUID', 'CostPtr2', DEFAULT, 'co000'
	EXECUTE [prcAddLookupGUIDFld] 'ch000', 'Account2GUID', 'AccPtr2', DEFAULT, 'ac000'
	EXECUTE [prcAddGUIDFld] 'ch000', 'BranchGUID'
	EXECUTE [prcDropFld] 'ch000', 'ParentType'
	EXECUTE [prcDropFld] 'ch000', 'Parent'
	EXECUTE [prcLinkER] 'ch000', 'CEntry1'
	EXECUTE [prcLinkER] 'ch000', 'CEntry2'

	-- ci000
	EXECUTE [prcLog] 'Upgrading ci000'
	EXECUTE [prcAddROWGUIDCOLFld] 'ci000'
	EXECUTE [prcAddLookupGUIDFld] 'ci000', 'ParentGUID', 'Number', DEFAULT, 'ac000'
	EXECUTE [prcAddLookupGUIDFld] 'ci000', 'SonGUID', 'Num1', DEFAULT, 'ac000',DEFAULT, DEFAULT, DEFAULT, 0

	-- co000:
	EXECUTE [prcLog] 'Upgrading co000'
	EXECUTE [prcAddLookupGUIDFld] 'co000', 'ParentGUID', 'Parent', DEFAULT, 'co000'

	-- cp000:
	EXECUTE [prcLog] 'Upgrading cp000'
	EXECUTE [prcAddROWGUIDCOLFld] 'cp000'
	EXECUTE [prcAddLookupGUIDFld] 'cp000', 'CustGUID', 'CustPtr', DEFAULT, 'cu000'
	EXECUTE [prcAddLookupGUIDFld] 'cp000', 'MatGUID', 'MatPtr', DEFAULT, 'mt000'

	-- cu000:
	EXECUTE [prcLog] 'Upgrading cu000'
	EXECUTE [prcAddLookupGUIDFld] 'cu000', 'PictureGUID', 'Picture', DEFAULT, 'bm000'
	EXECUTE [prcAddLookupGUIDFld] 'cu000', 'AccountGUID', 'Account', DEFAULT, 'ac000'

	-- di000:
	EXECUTE [prcLog] 'Upgrading di000'
	EXECUTE [prcAddLookupGUIDFld] 'di000', 'ParentGUID', 'Type', 'Parent', 'bu000', 'Type', 'Number'
	EXECUTE [prcAddLookupGUIDFld] 'di000', 'AccountGUID', 'Account', DEFAULT, 'ac000'
	EXECUTE [prcAddLookupGUIDFld] 'di000', 'CurrencyGUID', 'CurrencyPtr', DEFAULT, 'my000'
	EXECUTE [prcAddLookupGUIDFld] 'di000', 'CostGUID', 'CostPtr', DEFAULT, 'co000'
	EXECUTE [prcAddLookupGUIDFld] 'di000', 'ContraAccGUID', 'ContraAcc', DEFAULT, 'ac000'
	
	-- en000:
	EXECUTE [prcLog] 'Upgrading en000'
	EXECUTE [prcAddLookupGUIDFld] 'en000', 'ParentGUID', 'Type', 'Parent', 'ce000', 'Type', 'Number'
	EXECUTE [prcAddLookupGUIDFld] 'en000', 'AccountGUID', 'Account', DEFAULT, 'ac000'
	EXECUTE [prcAddLookupGUIDFld] 'en000', 'CurrencyGUID', 'CurrencyPtr', DEFAULT, 'my000'
	EXECUTE [prcAddLookupGUIDFld] 'en000', 'CostGUID', 'CostPoint', DEFAULT, 'co000'
	EXECUTE [prcAddLookupGUIDFld] 'en000', 'ContraAccGUID', 'ContraAcc', DEFAULT, 'ac000'
	EXECUTE [prcDropTrigger] 'trg_en000_checkConstraints'
	EXECUTE [prcDropTrigger] 'trg_en000_ceStatisticsUpdater'

	-- et000:
	EXECUTE [prcLog] 'Upgrading et000'
	EXECUTE [prcDropTrigger] 'trg_et000_general'
	EXECUTE [prcAddLookupGUIDFld] 'et000', 'DefAccGUID', 'DefAcc', DEFAULT, 'ac000'
	EXECUTE ('
		ALTER TABLE [et000] DISABLE TRIGGER ALL
		UPDATE [et000] SET [SortNum] = [Number]
		UPDATE [et000] SET [EntryType] = 0 WHERE [EntryType] <> 0
		ALTER TABLE [et000] ENABLE TRIGGER ALL')

	-- fm000, mn000 and mi000:
	-- Added By Raouf
	EXECUTE( '
		DECLARE @MaxNum int
		SELECT @MaxNum = Max(Number) + 1 FROM MN000
		Update [fm000] SET [Number] = [Number] + @MaxNum
		Update [mi000] SET [Parent] = [Parent] + @MaxNum where [Type] = 1
		Update [mn000] SET [Form] = [Form] + @MaxNum')
	------------------
	IF [dbo].[fnObjectExists]('mn000.number') <> 0 EXECUTE [prcLog] 'mn000.number OK' ELSE EXECUTE [prcLog] 'mn000.number MISSING'
	IF [dbo].[fnObjectExists]('fm000.number') <> 0 EXECUTE [prcLog] 'fm000.number OK' ELSE EXECUTE [prcLog] 'fm000.number MISSING'
	EXECUTE [prcAddLookupGUIDFld] 'mn000', 'FormGUID', 'Form', DEFAULT, 'fm000', DEFAULT, DEFAULT, DEFAULT, 0
	EXECUTE [prcDropTrigger] 'trg_mn000_general'
	EXECUTE [prcDropTrigger] 'trg_mn000_delete'
	EXEC('INSERT INTO [mn000]([GUID], [Type], [Number], [FormGUID], [Date], [Notes], [Flags], [CurrencyPtr], [CurrencyVal], [Security], [StorePtr], [RawStore], [InCost], [OutCost]) SELECT [GUID], 0, [Number], [GUID], [Date], [Notes], [Flags], [Num1], [Num2], [Security], [InStore], [OutStore], [InCost], [OutCost] FROM [fm000]')
	EXECUTE [prcDropFld] 'fm000', 'Date'
	EXECUTE [prcDropFld] 'fm000', 'Notes'
	EXECUTE [prcDropFld] 'fm000', 'Flags'
	EXECUTE [prcDropFld] 'fm000', 'Num1'
	EXECUTE [prcDropFld] 'fm000', 'Num2'
	EXECUTE [prcDropFld] 'fm000', 'Num3'
	EXECUTE [prcDropFld] 'fm000', 'Security'
	EXECUTE [prcDropFld] 'fm000', 'InStore'
	EXECUTE [prcDropFld] 'fm000', 'OutStore'
	EXECUTE [prcDropFld] 'fm000', 'InCost'
	EXECUTE [prcDropFld] 'fm000', 'OutCost'

	-- completing mn000:
	EXECUTE [prcLog] 'Upgrading mn000'
	EXECUTE [prcAddLookupGUIDFld] 'mn000', 'InStoreGUID', 'StorePtr', DEFAULT, 'st000'
	EXECUTE [prcAddLookupGUIDFld] 'mn000', 'OutStoreGUID', 'RawStore', DEFAULT, 'st000'
	EXECUTE [prcAddLookupGUIDFld] 'mn000', 'InAccountGUID', 'Account', DEFAULT, 'ac000'
	EXECUTE [prcAddLookupGUIDFld] 'mn000', 'OutAccountGUID', 'OutAcc', DEFAULT, 'ac000'
	EXECUTE [prcAddLookupGUIDFld] 'mn000', 'InCostGUID', 'InCost', DEFAULT, 'co000'
	EXECUTE [prcAddLookupGUIDFld] 'mn000', 'OutCostGUID', 'OutCost', DEFAULT, 'co000'
	EXECUTE [prcAddLookupGUIDFld] 'mn000', 'InTempAccGUID', 'InTmpAcc', DEFAULT, 'ac000'
	EXECUTE [prcAddLookupGUIDFld] 'mn000', 'OutTempAccGUID', 'OutTmpAcc', DEFAULT, 'ac000'
	EXECUTE [prcAddLookupGUIDFld] 'mn000', 'CurrencyGUID', 'CurrencyPtr', DEFAULT, 'my000'
	EXECUTE [prcAddFloatFld] 'mn000', 'Lot'
	EXECUTE [prcAddFloatFld] 'mn000', 'ProductionTime'
	EXEC('UPDATE [mn000] SET [Lot] = Num1, [ProductionTime] = Num2')
	EXEC('DELETE [mb000] FROM [mb000] INNER JOIN [mn000] ON [mn000].[GUID] = [mb000].[ManGUID]')
	EXEC('INSERT INTO [mb000] ([Type], [ManGUID], [BillGUID]) SELECT 1, [m].[GUID], [b].[GUID] FROM [mn000] AS [m] INNER JOIN [bu000] AS [b] ON [m].[InPtr] = [b].[Number] WHERE [b].[Type] = 260')
	EXEC('INSERT INTO [mb000] ([Type], [ManGUID], [BillGUID]) SELECT 0, [m].[GUID], [b].[GUID] FROM [mn000] AS [m] INNER JOIN [bu000] AS [b] ON [m].[OutPtr] = [b].[Number] WHERE [b].[Type] = 261')
	EXECUTE [prcAddGUIDFld] 'mn000', 'BranchGUID'
	EXECUTE [prcDropFld] 'mn000', 'Num1'
	EXECUTE [prcDropFld] 'mn000', 'Num2'
	EXECUTE [prcDropFld] 'mn000', 'Num3'
	EXECUTE [prcDropFld] 'mn000', 'Num4'
	EXECUTE [prcDropFld] 'mn000', 'Num5'
	EXECUTE [prcDropFld] 'mn000', 'Num6'
	EXECUTE [prcDropFld] 'mn000', 'InPtr'
	EXECUTE [prcDropFld] 'mn000', 'OutPtr'

	-- mi000:
	EXECUTE [prcLog] 'Upgrading mi000'
	EXECUTE [prcAddLookupGUIDFld] 'mi000', 'ParentGUID', 'Parent', DEFAULT, 'mn000', DEFAULT, DEFAULT, 'mi000.Type = 2', 0, 'UPDATE mi000 SET ParentGUID = fm.GUID FROM mi000 AS mi INNER JOIN fm000 fm ON mi.Parent = fm.Number WHERE mi.Type = 1'
	EXEC('UPDATE [mi000] SET [num2] = [MatPtr] WHERE [itemType] IN (3, 4)')
	EXECUTE [prcAddLookupGUIDFld] 'mi000', 'MatGUID', 'MatPtr', DEFAULT, 'mt000'
	EXECUTE [prcAddLookupGUIDFld] 'mi000', 'StoreGUID', 'StorePtr', DEFAULT, 'st000'
	EXECUTE [prcAddLookupGUIDFld] 'mi000', 'CurrencyGUID', 'CurrencyPtr', DEFAULT, 'my000'
	EXECUTE [prcAddDateFld] 'mi000', 'ExpireDate'
	EXECUTE [prcAddDateFld] 'mi000', 'ProductionDate'
	EXECUTE [prcAddFloatFld] 'mi000', 'Length'
	EXECUTE [prcAddFloatFld] 'mi000', 'Width'
	EXECUTE [prcAddFloatFld] 'mi000', 'Height'
	EXECUTE [prcAddGUIDFld] 'mi000', 'CostGUID'
	EXECUTE [prcAddFloatFld] 'mi000', 'Percentage'
	EXEC('
		UPDATE [mi000] SET [Percentage] = [Price] WHERE [ItemType] = 1
		UPDATE [mi000] SET [Price] = [Num1] WHERE [ItemType] IN (1, 2)
		INSERT INTO [mx000] ([Type], [Number], [Discount], [Extra], [CurrencyVal], [Flag], [Class], [ParentGUID], [AccountGUID], [CurrencyGUID], [CostGUID], [ContraAccGUID])
				SELECT [ItemType] - 3, [Number], 0, [Unity], [CurrencyVal], 0, [Class], [ParentGUID], (SELECT [GUID] FROM [ac000] WHERE [number] = [mi000].[num2]), [CurrencyGUID], ISNULL((SELECT [GUID] FROM [co000] WHERE [Number] = [mi000].[Price]), 0x0), 0x0
				FROM [mi000] WHERE [ItemType] IN (3, 4)
		DELETE [mi000] WHERE [ItemType] IN (3, 4)
		UPDATE [mi000] SET [num1] = [ItemType] - 1')
	EXECUTE [prcDropFld] 'mi000', 'ItemType'
	EXEC('UPDATE mi000 SET Type = num1') -- using num1 was entended to avoid primary key duplication exception.
	EXECUTE [prcDropFld] 'mi000', 'Num1'
	EXECUTE [prcDropFld] 'mi000', 'Num2'
	EXECUTE [prcDropFld] 'mi000', 'Num3'
	EXECUTE [prcDropFld] 'mi000', 'Num4'
	EXECUTE [prcDropFld] 'mi000', 'Num5'
	EXECUTE [prcDropFld] 'mi000', 'Parent'
	-- Added By Raouf
	EXECUTE ('UPDATE MI000 SET Qty = mi.Qty * mt.Unit2Fact FROM mi000 AS mi, MT000 AS mt WHERE mi.MatGUID = mt.GUID AND mi.UNity = 2')
	EXECUTE ('UPDATE MI000 SET Qty = mi.Qty * mt.Unit3Fact FROM mi000 AS mi, MT000 AS mt WHERE mi.MatGUID = mt.GUID AND mi.UNity = 3')

	-----------------
	-- gr000:
	EXECUTE [prcLog] 'Upgrading gr000'
	EXECUTE [prcAddLookupGUIDFld] 'gr000', 'ParentGUID', 'Parent', DEFAULT, 'gr000'

	-- ki000:
	--EXECUTE [prcLog] 'Upgrading ki000'
	--EXECUTE [prcAddLookupGUIDFld] 'ki000', 'ParentGUID', 'Parent', DEFAULT, 'km000'
	--EXECUTE [prcAddLookupGUIDFld] 'ki000', 'MatGUID', 'MatPtr', DEFAULT, 'mt000'

	-- km000:
	--EXECUTE [prcLog] 'Upgrading km000'
	--EXECUTE [prcAddLookupGUIDFld] 'km000', 'BillGUID', 'BillType', 'BillNumber', 'ce000', 'Type', 'Number'

	-- ma000:
	EXECUTE [prcLog] 'Upgrading ma000'
	EXECUTE [prcAddLookupGUIDFld] 'ma000', 'MatGUID', 'Number', DEFAULT, 'mt000', DEFAULT, DEFAULT, 'ma000.Type = 1', 0
	EXECUTE ('
		ALTER TABLE [ma000] DISABLE TRIGGER ALL
		UPDATE [ma000] SET [MatGUID] = ISNULL([g].[GUID], 0x0) FROM [ma000] AS [m] INNER JOIN [gr000] AS [g] ON [m].[Number] = [g].[Number] WHERE [m].[Type] = 2
		ALTER TABLE [ma000] ENABLE TRIGGER ALL')
	EXECUTE [prcAddLookupGUIDFld] 'ma000', 'BillTypeGUID', 'BillType', DEFAULT, 'bt000', 'Number', DEFAULT, 'lu.Type = 1'
	EXECUTE [prcAddLookupGUIDFld] 'ma000', 'MatAccGUID', 'MatAcc', DEFAULT, 'ac000'
	EXECUTE [prcAddLookupGUIDFld] 'ma000', 'DiscAccGUID', 'DiscAcc', DEFAULT, 'ac000'
	EXECUTE [prcAddLookupGUIDFld] 'ma000', 'ExtraAccGUID', 'ExtraAcc', DEFAULT, 'ac000'
	EXECUTE [prcAddLookupGUIDFld] 'ma000', 'VATAccGUID', 'VATAcc', DEFAULT, 'ac000'
	EXECUTE [prcAddLookupGUIDFld] 'ma000', 'StoreAccGUID', 'StoreAcc', DEFAULT, 'ac000'
	EXECUTE [prcAddLookupGUIDFld] 'ma000', 'CostAccGUID', 'CostAcc', DEFAULT, 'ac000'
	EXECUTE [prcAddROWGUIDCOLFld] 'ma000'
	EXECUTE [prcDropFld] 'ma000', 'Number'
	ALTER TABLE [ma000] ENABLE TRIGGER ALL
	
	-- ms000:
	EXECUTE [prcLog] 'Upgrading ms000'
	EXECUTE [prcAddROWGUIDCOLFld] 'ms000'
	EXECUTE [prcAddLookupGUIDFld] 'ms000', 'StoreGUID', 'StorePtr', DEFAULT, 'st000'
	EXECUTE [prcAddLookupGUIDFld] 'ms000', 'MatGUID', 'MatPtr', DEFAULT, 'mt000'

	-- mt000:
	EXECUTE [prcLog] 'Upgrading mt000'
	EXECUTE [prcAddLookupGUIDFld] 'mt000', 'GroupGUID', '[Group]', DEFAULT, 'gr000'
	EXECUTE [prcAddLookupGUIDFld] 'mt000', 'PictureGUID', 'Picture', DEFAULT, 'bm000'

	EXECUTE [prcAddLookupGUIDFld] 'mt000', 'CurrencyGUID', 'CurrencyPtr', DEFAULT, 'my000'
	EXECUTE [prcAddIntFld] 'mt000', 'DefUnit'
	EXECUTE ('
		ALTER TABLE [mt000] DISABLE TRIGGER ALL
		UPDATE [mt000] SET [DefUnit] = ISNULL( ([Flag] / 256) + 1, 0), [Flag] = CAST([Flag] AS [INT]) & 255
		ALTER TABLE [mt000] ENABLE TRIGGER ALL')

	-- mtc will be fixed from prcInitDatabase

	-- nt000:
	EXECUTE [prcLog] 'Upgrading nt000'
	EXECUTE [prcAddLookupGUIDFld] 'nt000', 'DefPayAccGUID', 'DefPayAcc', DEFAULT, 'ac000'
	EXECUTE [prcAddLookupGUIDFld] 'nt000', 'DefRecAccGUID', 'DefrecAcc', DEFAULT, 'ac000'
	EXECUTE [prcAddLookupGUIDFld] 'nt000', 'DefColAccGUID', 'DefColAcc', DEFAULT, 'ac000'
	EXECUTE [prcAddLookupGUIDFld] 'nt000', 'CostGUID', 'CostPtr', DEFAULT, 'co000'
	EXECUTE [prcAddBitFld] 'nt000', 'bCanCollect'
	EXECUTE [prcAddBitFld] 'nt000', 'bCanEndorse'
	EXECUTE [prcAddBitFld] 'nt000', 'bCanReturn'
	EXECUTE [prcAddBitFld] 'nt000', 'bTransfer'

	EXECUTE ('
		ALTER TABLE [nt000] DISABLE TRIGGER ALL
		UPDATE [nt000] SET [SortNum] = [Number]
		ALTER TABLE [nt000] ENABLE TRIGGER ALL')
	
	-- op000:
	EXECUTE [prcLog] 'Upgrading op000'
	ALTER TABLE [op000] ALTER COLUMN [Value] [VARCHAR](2000)
	ALTER TABLE [op000] ALTER COLUMN [PrevValue] [VARCHAR](2000)
	EXECUTE [prcAddLookupGUIDFld] 'op000', 'OwnerGUID', 'Owner', DEFAULT, 'us000'
	EXECUTE [prcAddLookupGUIDFld] 'op000', 'UserGUID', '[User]', DEFAULT, 'us000', DEFAULT, DEFAULT, DEFAULT, 1, 'UPDATE [op000] SET OwnerGUID = 0x0'

	EXECUTE [prcLog] 'Upgrading [op000] data'
	UPDATE [op000] SET [Name] = 'AmnPOS_[PREPARE]PCustAddress' WHERE [Name] = 'AmnPOS_[PREPARE]PFLD1'
	UPDATE [op000] SET [Name] = 'AmnPOS_[PREPARE]PVendName' WHERE [Name] = 'AmnPOS_[PREPARE]PFLD2'
	UPDATE [op000] SET [Name] = 'AmnPOS_[PREPARE]PBarcode' WHERE [Name] = 'AmnPOS_[PREPARE]PFLD3'
	UPDATE [op000] SET [Name] = 'AmnPOS_[PREPARE]PLatinName' WHERE [Name] = 'AmnPOS_[PREPARE]PFLD4'	
	UPDATE [op000] SET [Name] = 'AmnPOS_[PREPARE]PArea' WHERE [Name] = 'AmnPOS_[PREPARE]PFLD5'
	UPDATE [op000] SET [Name] = 'AmnPOS_[PREPARE]PIngredient' WHERE [Name] = 'AmnPOS_[PREPARE]PFLD6'
	UPDATE [op000] SET [Name] = 'AmnPOS_[PREPARE]PMatGroup' WHERE [Name] = 'AmnPOS_[PREPARE]PFLD7'
	UPDATE [op000] SET [Name] = 'AmnPOS_[STARTPREPARE]PCustAddress' WHERE [Name] = 'AmnPOS_[STARTPREPARE]PFLD1'
	UPDATE [op000] SET [Name] = 'AmnPOS_[STARTPREPARE]PVendName' WHERE [Name] = 'AmnPOS_[STARTPREPARE]PFLD2'
	UPDATE [op000] SET [Name] = 'AmnPOS_[STARTPREPARE]PBarcode' WHERE [Name] = 'AmnPOS_[STARTPREPARE]PFLD3'
	UPDATE [op000] SET [Name] = 'AmnPOS_[STARTPREPARE]PLatinName' WHERE [Name] = 'AmnPOS_[STARTPREPARE]PFLD4'
	UPDATE [op000] SET [Name] = 'AmnPOS_[STARTPREPARE]PArea' WHERE [Name] = 'AmnPOS_[STARTPREPARE]PFLD5'
	UPDATE [op000] SET [Name] = 'AmnPOS_[STARTPREPARE]PIngredient' WHERE [Name] = 'AmnPOS_[STARTPREPARE]PFLD6'
	UPDATE [op000] SET [Name] = 'AmnPOS_[STARTPREPARE]PMatGroup' WHERE [Name] = 'AmnPOS_[STARTPREPARE]PFLD7'
	UPDATE [op000] SET [Name] = 'AmnPOS_[FINISHPREPARE]PCustAddress' WHERE [Name] = 'AmnPOS_[FINISHPREPARE]FLD1'
	UPDATE [op000] SET [Name] = 'AmnPOS_[FINISHPREPARE]PVendName' WHERE [Name] = 'AmnPOS_[FINISHPREPARE]FLD2'	
	UPDATE [op000] SET [Name] = 'AmnPOS_[FINISHPREPARE]PBarcode' WHERE [Name] = 'AmnPOS_[FINISHPREPARE]FLD3'	
	UPDATE [op000] SET [Name] = 'AmnPOS_[FINISHPREPARE]PLatinName' WHERE [Name] = 'AmnPOS_[FINISHPREPARE]FLD4'	
	UPDATE [op000] SET [Name] = 'AmnPOS_[FINISHPREPARE]PArea' WHERE [Name] = 'AmnPOS_[FINISHPREPARE]FLD5'
	UPDATE [op000] SET [Name] = 'AmnPOS_[FINISHPREPARE]PIngredient' WHERE [Name] = 'AmnPOS_[FINISHPREPARE]FLD6'
	UPDATE [op000] SET [Name] = 'AmnPOS_[FINISHPREPARE]PMatGroup' WHERE [Name] = 'AmnPOS_[FINISHPREPARE]FLD7'
	UPDATE [op000] SET [Name] = 'AmnPOS_[STARTDELIVERY]PCustAddress' WHERE [Name] = 'AmnPOS_[STARTDELIVERY]FLD1'
	UPDATE [op000] SET [Name] = 'AmnPOS_[STARTDELIVERY]PVendName' WHERE [Name] = 'AmnPOS_[STARTDELIVERY]FLD2'
	UPDATE [op000] SET [Name] = 'AmnPOS_[STARTDELIVERY]PBarcode' WHERE [Name] = 'AmnPOS_[STARTDELIVERY]FLD3'
	UPDATE [op000] SET [Name] = 'AmnPOS_[STARTDELIVERY]PLatinName' WHERE [Name] = 'AmnPOS_[STARTDELIVERY]FLD4'
	UPDATE [op000] SET [Name] = 'AmnPOS_[STARTDELIVERY]PArea' WHERE [Name] = 'AmnPOS_[STARTDELIVERY]FLD5'
	UPDATE [op000] SET [Name] = 'AmnPOS_[STARTDELIVERY]PIngredient' WHERE [Name] = 'AmnPOS_[STARTDELIVERY]FLD6'
	UPDATE [op000] SET [Name] = 'AmnPOS_[STARTDELIVERY]PMatGroup' WHERE [Name] = 'AmnPOS_[STARTDELIVERY]FLD7'
	UPDATE [op000] SET [Name] = 'AmnPOS_[FINISHDELIVERY]PCustAddress' WHERE [Name] = 'AmnPOS_[FINISHDELIVERY]FLD1'
	UPDATE [op000] SET [Name] = 'AmnPOS_[FINISHDELIVERY]PVendName' WHERE [Name] = 'AmnPOS_[FINISHDELIVERY]FLD2'
	UPDATE [op000] SET [Name] = 'AmnPOS_[FINISHDELIVERY]PBarcode' WHERE [Name] = 'AmnPOS_[FINISHDELIVERY]FLD3'
	UPDATE [op000] SET [Name] = 'AmnPOS_[FINISHDELIVERY]PLatinName' WHERE [Name] = 'AmnPOS_[FINISHDELIVERY]FLD4'
	UPDATE [op000] SET [Name] = 'AmnPOS_[FINISHDELIVERY]PArea' WHERE [Name] = 'AmnPOS_[FINISHDELIVERY]FLD5'
	UPDATE [op000] SET [Name] = 'AmnPOS_[FINISHDELIVERY]PIngredient' WHERE [Name] = 'AmnPOS_[FINISHDELIVERY]FLD6'
	UPDATE [op000] SET [Name] = 'AmnPOS_[FINISHDELIVERY]PMatGroup' WHERE [Name] = 'AmnPOS_[FINISHDELIVERY]FLD7'
	UPDATE [op000] SET [Name] = 'AmnPOS_[ENDORDER]PCustAddress' WHERE [Name] = 'AmnPOS_[ENDORDER]FLD1'
	UPDATE [op000] SET [Name] = 'AmnPOS_[ENDORDER]PVendName' WHERE [Name] = 'AmnPOS_[ENDORDER]FLD2'
	UPDATE [op000] SET [Name] = 'AmnPOS_[ENDORDER]PBarcode' WHERE [Name] = 'AmnPOS_[ENDORDER]FLD3'
	UPDATE [op000] SET [Name] = 'AmnPOS_[ENDORDER]PLatinName' WHERE [Name] = 'AmnPOS_[ENDORDER]FLD4'
	UPDATE [op000] SET [Name] = 'AmnPOS_[ENDORDER]PArea' WHERE [Name] = 'AmnPOS_[ENDORDER]FLD5'
	UPDATE [op000] SET [Name] = 'AmnPOS_[ENDORDER]PIngredient' WHERE [Name] = 'AmnPOS_[ENDORDER]FLD6'
	UPDATE [op000] SET [Name] = 'AmnPOS_[ENDORDER]PMatGroup' WHERE [Name] = 'AmnPOS_[ENDORDER]FLD7'
	UPDATE [op000] SET [Name] = 'AmnPOS_[PRODUCTWINOW]PCustAddress' WHERE [Name] = 'AmnPOS_[PRODUCTWINOW]FLD1'
	UPDATE [op000] SET [Name] = 'AmnPOS_[PRODUCTWINOW]PVendName' WHERE [Name] = 'AmnPOS_[PRODUCTWINOW]FLD2'
	UPDATE [op000] SET [Name] = 'AmnPOS_[PRODUCTWINOW]PBarcode' WHERE [Name] = 'AmnPOS_[PRODUCTWINOW]FLD3'
	UPDATE [op000] SET [Name] = 'AmnPOS_[PRODUCTWINOW]PLatinName' WHERE [Name] = 'AmnPOS_[PRODUCTWINOW]FLD4'
	UPDATE [op000] SET [Name] = 'AmnPOS_[PRODUCTWINOW]PArea' WHERE [Name] = 'AmnPOS_[PRODUCTWINOW]FLD5'
	UPDATE [op000] SET [Name] = 'AmnPOS_[PRODUCTWINOW]PIngredient' WHERE [Name] = 'AmnPOS_[PRODUCTWINOW]FLD6'
	UPDATE [op000] SET [Name] = 'AmnPOS_[PRODUCTWINOW]PMatGroup' WHERE [Name] = 'AmnPOS_[PRODUCTWINOW]FLD7'
	UPDATE [op000] SET [Name] = 'AmnPOS_[ORDERWINDOW]PCustAddress' WHERE [Name] = 'AmnPOS_[ORDERWINDOW]FLD1'
	UPDATE [op000] SET [Name] = 'AmnPOS_[ORDERWINDOW]PVendName' WHERE [Name] = 'AmnPOS_[ORDERWINDOW]FLD2'
	UPDATE [op000] SET [Name] = 'AmnPOS_[ORDERWINDOW]PBarcode' WHERE [Name] = 'AmnPOS_[ORDERWINDOW]FLD3'
	UPDATE [op000] SET [Name] = 'AmnPOS_[ORDERWINDOW]PLatinName' WHERE [Name] = 'AmnPOS_[ORDERWINDOW]FLD4'
	UPDATE [op000] SET [Name] = 'AmnPOS_[ORDERWINDOW]PArea' WHERE [Name] = 'AmnPOS_[ORDERWINDOW]FLD5'
	UPDATE [op000] SET [Name] = 'AmnPOS_[ORDERWINDOW]PIngredient' WHERE [Name] = 'AmnPOS_[ORDERWINDOW]FLD6'
	UPDATE [op000] SET [Name] = 'AmnPOS_[ORDERWINDOW]PMatGroup' WHERE [Name] = 'AmnPOS_[ORDERWINDOW]FLD7'
	
	IF [dbo].[fnObjectExists]('et000.number') <> 0
		EXEC('
		UPDATE [op000] SET [Value] = ISNULL((SELECT TOP 1 [GUID] FROM [et000] WHERE [Number] = (SELECT TOP 1 CAST([Value] AS INT) FROM [op000] WHERE [Name] = ''AmnPOS_EarRECEIVEPAY'' AND [computer] = o.[computer])), 0x0) FROM [op000] AS [o] WHERE [Name] = ''AmnPOS_EarRECEIVEPAY''
		UPDATE [op000] SET [Value] = ISNULL((SELECT TOP 1 [GUID] FROM [et000] WHERE [Number] = (SELECT TOP 1 CAST([Value] AS INT) FROM [op000] WHERE [Name] = ''AmnPOS_EarRETRIEVEPAY'' AND [computer] = o.[computer])), 0x0) FROM [op000] AS [o]  WHERE [Name] = ''AmnPOS_EarRETRIEVEPAY''')

	IF [dbo].[fnObjectExists]('ac000.number') <> 0
		EXECUTE ('
		UPDATE [op000] SET [Value] = ISNULL((SELECT TOP 1 [GUID] FROM [ac000] WHERE [Number] = (SELECT TOP 1 CAST([Value] AS [INT]) FROM [op000] WHERE [Name] = ''AmnPOS_RESETACC'' AND computer = o.computer)), 0x0) FROM [op000] AS [o] WHERE [Name] = ''AmnPOS_RESETACC''
		UPDATE [op000] SET [Value] = ISNULL((SELECT TOP 1 [GUID] FROM [ac000] WHERE [Number] = (SELECT TOP 1 CAST([Value] AS [INT]) FROM [op000] WHERE [Name] = ''AmnPOS_FREEACCNAME'' AND computer = o.computer)), 0x0) FROM [op000] AS [o] WHERE [Name] = ''AmnPOS_FREEACCNAME''
		UPDATE [op000] SET [Value] = ISNULL((SELECT TOP 1 [GUID] FROM [ac000] WHERE [Number] = (SELECT TOP 1 CAST([Value] AS [INT]) FROM [op000] WHERE [Name] = ''AmnPOS_CUSTACCNAME'' AND computer = o.computer)), 0x0) FROM [op000] AS [o] WHERE [Name] = ''AmnPOS_CUSTACCNAME''
		UPDATE [op000] SET [Value] = ISNULL((SELECT TOP 1 [GUID] FROM [ac000] WHERE [Number] = (SELECT TOP 1 CAST([Value] AS [INT]) FROM [op000] WHERE [Name] = ''AmnPOS_DAMAGEDACC'' AND computer = o.computer)), 0x0) FROM [op000] AS [o] WHERE [Name] = ''AmnPOS_DAMAGEDACC''
		UPDATE [op000] SET [Value] = ISNULL((SELECT TOP 1 [GUID] FROM [ac000] WHERE [Number] = (SELECT TOP 1 CAST([Value] AS [INT]) FROM [op000] WHERE [Name] = ''AmnPOS_CurDrawerAcc'' AND computer = o.computer)), 0x0) FROM [op000] AS [o] WHERE [Name] = ''AmnPOS_CurDrawerAcc''
		UPDATE [op000] SET [Value] = ISNULL((SELECT TOP 1 [GUID] FROM [ac000] WHERE [Number] = (SELECT TOP 1 CAST([Value] AS [INT]) FROM [op000] WHERE [Name] = ''AmnPOS_DRAWERACCNAME'' AND computer = o.computer)), 0x0) FROM [op000] AS [o] WHERE [Name] = ''AmnPOS_DRAWERACCNAME''
		UPDATE [op000] SET [Value] = ISNULL((SELECT TOP 1 [GUID] FROM [ac000] WHERE [Number] = (SELECT TOP 1 CAST([Value] AS [INT]) FROM [op000] WHERE [Name] = ''AmnPOS_EQUALDRAWERACC'' AND computer = o.computer)), 0x0) FROM [op000] AS [o] WHERE [Name] = ''AmnPOS_EQUALDRAWERACC''
		UPDATE [op000] SET [Value] = ISNULL((SELECT TOP 1 [GUID] FROM [ac000] WHERE [Number] = (SELECT TOP 1 CAST([Value] AS [INT]) FROM [op000] WHERE [Name] = ''AmnPOS_MANAGMENTACC'' AND computer = o.computer)), 0x0) FROM [op000] AS [o] WHERE [Name] = ''AmnPOS_MANAGMENTACC''
		UPDATE [op000] SET [Value] = ISNULL((SELECT TOP 1 [GUID] FROM [ac000] WHERE [Number] = (SELECT TOP 1 CAST([Value] AS [INT]) FROM [op000] WHERE [Name] = ''AmnPOS_EarRETRIEVEACC'' AND computer = o.computer)), 0x0) FROM [op000] AS [o] WHERE [Name] = ''AmnPOS_EarRETRIEVEACC''
		UPDATE [op000] SET [Value] = ISNULL((SELECT TOP 1 [GUID] FROM [ac000] WHERE [Number] = (SELECT TOP 1 CAST([Value] AS [INT]) FROM [op000] WHERE [Name] = ''AmnPOS_EarRECEIVEACC'' AND computer = o.computer)), 0x0) FROM [op000] AS [o] WHERE [Name] = ''AmnPOS_EarRECEIVEACC''')
		
	IF [dbo].[fnObjectExists]('st000.number') <> 0
		EXECUTE ('UPDATE [op000] SET [Value] = ISNULL((SELECT TOP 1 GUID FROM [st000] WHERE [Number] = (SELECT TOP 1 CAST([Value] AS [INT]) FROM [op000] WHERE [Name] = ''AmnPOS_ATTACHMENTST	'' AND [computer] = [o].[computer])), 0x0) FROM [op000] AS [o] WHERE [Name] = ''AmnPOS_ATTACHMENTST''')
		
	IF [dbo].[fnObjectExists]('gr000.number') <> 0
		EXECUTE ('		
		UPDATE [op000] SET [Value] = ISNULL((SELECT TOP 1 [GUID] FROM [gr000] WHERE [Number] = (SELECT TOP 1 CAST([Value] AS [INT]) FROM [op000] WHERE [Name] = ''AmnPOS_FOODHOLDS'' AND [computer] = [o].[computer])), 0x0) FROM [op000] AS o WHERE [Name] = ''AmnPOS_FOODHOLDS''
		UPDATE [op000] SET [Value] = ISNULL((SELECT TOP 1 [GUID] FROM [gr000] WHERE [Number] = (SELECT TOP 1 CAST([Value] AS [INT]) FROM [op000] WHERE [Name] = ''AmnPOS_FOODEXTRA'' AND [computer] = [o].[computer])), 0x0) FROM [op000] AS o WHERE [Name] = ''AmnPOS_FOODEXTRA''')
		
	IF [dbo].[fnObjectExists]('br000.number') <> 0
		EXECUTE ('UPDATE [op000] SET [Value] = ISNULL((SELECT TOP 1 [GUID] FROM [br000] WHERE [Number] = (SELECT TOP 1 CAST([Value] AS [INT]) FROM [op000] WHERE [Name] = ''AmnPOS_DefBranchGUID'' AND [computer] = [o].[computer])), 0x0) FROM [op000] AS [o] WHERE [Name] = ''AmnPOS_DefBranchGUID''')

	--IF [dbo].[fnObjectExists]('kn000.number') <> 0	
	--	EXECUTE ('
	--	UPDATE [op000] SET [Value] = ISNULL((SELECT TOP 1 [GUID] FROM [kn000] WHERE [Number]  = (SELECT TOP 1 CAST([Value] AS [INT]) FROM [op000] WHERE [Name] = ''AmnPOS_CurKitGUID'' AND [computer] = [o].[computer])), 0x0) FROM [op000] AS [o] WHERE [Name] = ''AmnPOS_CurKitGUID''
	--	UPDATE [op000] SET [Value] = ISNULL((SELECT TOP 1 [GUID] FROM [kn000] WHERE [Number]  = (SELECT TOP 1 CAST([Value] AS [INT]) FROM [op000] WHERE [Name] = ''AmnPOS_DefKitGUID'' AND [computer] = [o].[computer])), 0x0) FROM [op000] AS [o] WHERE [Name] = ''AmnPOS_DefKitGUID''')
		
	IF [dbo].[fnObjectExists]('bt000.number') <> 0	
		EXECUTE ('
		UPDATE [op000] SET [Value] = ISNULL((SELECT TOP 1 [GUID] FROM [bt000] WHERE Type =1 and [Number]  = (SELECT TOP 1 CAST([Value] AS [INT]) FROM [op000] WHERE [Name] = ''AmnPOS_SalesBills'' AND [computer] = [o].[computer])), 0x0) FROM [op000] AS o WHERE [Name] = ''AmnPOS_SalesBills''
		UPDATE [op000] SET [Value] = ISNULL((SELECT TOP 1 [GUID] FROM [bt000] WHERE Type =1 and [Number]  = (SELECT TOP 1 CAST([Value] AS [INT]) FROM [op000] WHERE [Name] = ''AmnPOS_SalesRBills'' AND [computer] = [o].[computer])), 0x0) FROM [op000] AS o WHERE [Name] = ''AmnPOS_SalesRBills''
		UPDATE [op000] SET [Value] = ISNULL((SELECT TOP 1 [GUID] FROM [bt000] WHERE Type =1 and [Number]  = (SELECT TOP 1 CAST([Value] AS [INT]) FROM [op000] WHERE [Name] = ''AmnPOS_ROWMATOBills'' AND [computer] = [o].[computer])), 0x0) FROM [op000] AS o WHERE [Name] = ''AmnPOS_ROWMATOBills''
		UPDATE [op000] SET [Value] = ISNULL((SELECT TOP 1 [GUID] FROM [bt000] WHERE Type =1 and [Number]  = (SELECT TOP 1 CAST([Value] AS [INT]) FROM [op000] WHERE [Name] = ''AmnPOS_RMATIBills'' AND [computer] = [o].[computer])), 0x0) FROM [op000] AS o WHERE [Name] = ''AmnPOS_RMATIBills''')

	-- po000:
	EXECUTE [prcLog] 'Upgrading po000'
	
	----------------------------------------------------------------------------------
	-- pp000:
	EXECUTE [prcLog] 'Upgrading pp000'

	-- py000:
	EXECUTE [prcLog] 'Upgrading py000'
	EXECUTE [prcAddLookupGUIDFld] 'py000', 'TypeGUID', 'Type', DEFAULT, 'et000'
	EXECUTE [prcAddLookupGUIDFld] 'py000', 'AccountGUID', 'Account', DEFAULT, 'ac000'
	EXECUTE [prcAddLookupGUIDFld] 'py000', 'CurrencyGUID', 'CurrencyPtr', DEFAULT, 'my000'
	EXECUTE [prcAddGUIDFld] 'py000', 'BranchGUID'
	EXECUTE [prcLinkER] 'py000', 'CEntry'

	-- sd000:
	EXECUTE [prcLog] 'Upgrading sd000'
	EXECUTE [prcAddLookupGUIDFld] 'sd000', 'ParentGUID', 'Type', 'Number', 'sm000', 'Type', 'Number'
	EXECUTE [prcAddLookupGUIDFld] 'sd000', 'MatGUID', 'MatPtr', DEFAULT, 'mt000'
	EXECUTE [prcAddLookupGUIDFld] 'sd000', 'CurrencyGUID', 'CurrencyPtr', DEFAULT, 'my000'

	-- sh000
	EXECUTE [prcLog] 'Upgrading sh000'
	EXECUTE [prcAddGUIDFld] 'sh000', 'CmdGUID'

	-- sm000:
	EXECUTE [prcLog] 'Upgrading sm000'
	EXECUTE [prcAddLookupGUIDFld] 'sm000', 'MatGUID', 'MatPtr', DEFAULT, 'mt000'
	EXECUTE [prcAddLookupGUIDFld] 'sm000', 'StoreGUID', 'StorePtr', DEFAULT, 'st000'

	-- sn000:
	EXECUTE [prcLog] 'Upgrading sn000'
	EXECUTE [prcAddLookupGUIDFld] 'sn000', 'MatGUID', 'MatPtr', DEFAULT, 'mt000'

	-- st000:
	EXECUTE [prcLog] 'Upgrading st000'
	EXECUTE [prcAddLookupGUIDFld] 'st000', 'ParentGUID', 'Parent', DEFAULT, 'st000'
	EXECUTE [prcAddLookupGUIDFld] 'st000', 'AccountGUID', 'Account', DEFAULT, 'ac000'
	EXECUTE [prcAddIntFld] 'st000', 'Type'
	
	-- ui000:
	EXECUTE [prcLog] 'Upgrading ui000'
	SELECT * INTO [ui_old] FROM [ui000]
	TRUNCATE TABLE [ui000]

	EXECUTE [prcDropFld] 'ui000', 'Enter'
	EXECUTE [prcDropFld] 'ui000', '[Browse]'
	EXECUTE [prcDropFld] 'ui000', '[Modify]'
	EXECUTE [prcDropFld] 'ui000', '[Delete]'
	EXECUTE [prcDropFld] 'ui000', 'Post'
	EXECUTE [prcDropFld] 'ui000', 'GenEntry'
	EXECUTE [prcDropFld] 'ui000', 'PostEntry'
	EXECUTE [prcDropFld] 'ui000', 'ChangePrice'
	EXECUTE [prcDropFld] 'ui000', 'ReadPrice'

	EXECUTE [prcAddGUIDFld] 'ui_old', 'SubID'
	EXECUTE [prcAddGUIDFld] 'ui000', 'SubID'
	EXECUTE [prcAddIntFld] 'ui000', 'System'
	EXECUTE [prcAddIntFld] 'ui000', 'PermType'
	EXECUTE [prcAddIntFld] 'ui000', 'Permission'

	EXEC('
		-- standard bills:
		DECLARE	@RID_BILL [INT]
	
		SET @RID_BILL = 0x10010000

		UPDATE [ui_old] SET [SubID] = ISNULL((SELECT [GUID] FROM [bt000] WHERE [Number] = 1 AND [Type] = 2), 0x0), [ReportID] = @RID_BILL WHERE [ReportID] = CAST(0x401 AS [INT])
		UPDATE [ui_old] SET [SubID] = ISNULL((SELECT [GUID] FROM [bt000] WHERE [Number] = 2 AND [Type] = 2), 0x0), [ReportID] = @RID_BILL WHERE [ReportID] = CAST(0x401 AS [INT])
		UPDATE [ui_old] SET [SubID] = ISNULL((SELECT [GUID] FROM [bt000] WHERE [Number] = 3 AND [Type] = 2), 0x0), [ReportID] = @RID_BILL WHERE [ReportID] = CAST(0x402 AS [INT])
		UPDATE [ui_old] SET [SubID] = ISNULL((SELECT [GUID] FROM [bt000] WHERE [Number] = 4 AND [Type] = 2), 0x0), [ReportID] = @RID_BILL WHERE [ReportID] = CAST(0x402 AS [INT])
		UPDATE [ui_old] SET [SubID] = ISNULL((SELECT [GUID] FROM [bt000] WHERE [Number] = 5 AND [Type] = 2), 0x0), [ReportID] = @RID_BILL WHERE [ReportID] = CAST(0x200020E0 AS [INT]) -- RID_FORMINBILL
		UPDATE [ui_old] SET [SubID] = ISNULL((SELECT [GUID] FROM [bt000] WHERE [Number] = 6 AND [Type] = 2), 0x0), [ReportID] = @RID_BILL WHERE [ReportID] = CAST(0x200020D0 AS [INT]) -- RID_FORMOUTBILL
		UPDATE [ui_old] SET [SubID] = ISNULL((SELECT [GUID] FROM [bt000] WHERE [Number] = 7 AND [Type] = 2), 0x0), [ReportID] = @RID_BILL WHERE [ReportID] = @RID_BILL
		UPDATE [ui_old] SET [SubID] = ISNULL((SELECT [GUID] FROM [bt000] WHERE [Number] = 8 AND [Type] = 2), 0x0), [ReportID] = @RID_BILL WHERE [ReportID] = CAST(0x403 AS [INT])

		-- non-standard bills:
		UPDATE [t] SET [SubID] = [b].[GUID], [ReportID] = @RID_BILL FROM [ui_old] AS [t] INNER JOIN [bt000] AS [b] ON [b].[Number] = [t].[ReportID] - CAST(0x800 AS [INT]) WHERE [t].[ReportID] BETWEEN CAST(0x800 AS [INT]) AND CAST(0x8FF AS [INT]) AND [b].[Type] = 1

		-- entries:
		UPDATE [t] SET [SubID] = [e].[GUID], [ReportID] = CAST(0x10016000 AS [INT]) FROM [ui_old] AS [t] INNER JOIN [et000] AS [e] ON [e].[Number] = [t].[ReportID] - CAST(0x10016000 AS [INT]) WHERE [t].[ReportID] BETWEEN CAST(0x10016000 AS [INT]) AND CAST(0x10016FFF AS [INT])

		-- notes:
		UPDATE [t] SET [SubID] = [n].[GUID], [ReportID] = CAST(0x10015000 AS [INT]) FROM [ui_old] AS [t] INNER JOIN [nt000] AS [n] ON [n].[Number] = [t].[ReportID] - CAST(0x10015000 AS [INT]) WHERE [t].[ReportID] BETWEEN CAST(0x10015000 AS [INT]) AND CAST(0x10015FFF AS [INT])

		-- for others: 
		-- no modification required, as following insertion and deletion will do
		
		-- insert:
		INSERT INTO [ui000] ([UserGUID], [ReportID], [SubID], [System], [PermType], [Permission])
			SELECT [UserGUID], [ReportID], ISNULL([SubID], 0x0), 1, 0, ISNULL([Enter],			0) FROM [ui_old] UNION ALL
			SELECT [UserGUID], [ReportID], ISNULL([SubID], 0x0), 1, 1, ISNULL([Browse],			0) FROM [ui_old] UNION ALL
			SELECT [UserGUID], [ReportID], ISNULL([SubID], 0x0), 1, 2, ISNULL([Modify],			0) FROM [ui_old] UNION ALL
			SELECT [UserGUID], [ReportID], ISNULL([SubID], 0x0), 1, 3, ISNULL([Delete],			0) FROM [ui_old] UNION ALL
			SELECT [UserGUID], [ReportID], ISNULL([SubID], 0x0), 1, 4, ISNULL([Post],			0) FROM [ui_old] UNION ALL
			SELECT [UserGUID], [ReportID], ISNULL([SubID], 0x0), 1, 5, ISNULL([GenEntry],		0) FROM [ui_old] UNION ALL
			SELECT [UserGUID], [ReportID], ISNULL([SubID], 0x0), 1, 7, ISNULL([ChangePrice],	0) FROM [ui_old] UNION ALL
			SELECT [UserGUID], [ReportID], ISNULL([SubID], 0x0), 1, 8, ISNULL([ReadPrice],		0)	 FROM [ui_old]

		DELETE FROM [ui000] WHERE [Permission] = 0
	')
	DROP TABLE [ui_old]

	-- us000:
	EXECUTE [prcLog] 'Upgrading us000'
	EXECUTE [prcAddIntFld] 'us000', 'Type'

	-- drop redundant columns:
	EXECUTE [prcLog] 'Dropping redundant columns'
	EXECUTE [prcDropFld] 'bm000', 'Number'	
	EXECUTE [prcDropFld] 'bu000', 'Type'
	EXECUTE [prcDropFld] 'bt000', 'Number'
	EXECUTE [prcDropFld] 'et000', 'Number'
	EXECUTE [prcDropFld] 'ci000', 'Type'
	EXECUTE [prcDropFld] 'ci000', 'Number'
	EXECUTE [prcDropFld] 'ma000', 'Number'
	EXECUTE [prcDropFld] 'nt000', 'Number'
	EXECUTE [prcDropFld] 'mn000', 'Form'

	-- create lg
	EXECUTE [prcLog] 'Creating new lg000'
	EXECUTE prcRenameTable 'lg000', 'lg000_old'
	CREATE TABLE [dbo].[lg000] (
			[GUID] [UNIQUEIDENTIFIER] ROWGUIDCOL PRIMARY KEY,
			[LogTime] [DATETIME],
			[UserGUID] [UNIQUEIDENTIFIER],
			[Computer] [VARCHAR](250) COLLATE ARABIC_CI_AI,
			[Operation] [INT],
			[RepId] [INT],
			[RecGUID] [UNIQUEIDENTIFIER],
			[AccGUID] [UNIQUEIDENTIFIER],
			[CustGUID] [UNIQUEIDENTIFIER],
			[MatGUID] [UNIQUEIDENTIFIER],
			[GrpGUID] [UNIQUEIDENTIFIER],
			[StoreGUID] [UNIQUEIDENTIFIER],
			[CostGUID] [UNIQUEIDENTIFIER],
			[Branch] [UNIQUEIDENTIFIER],
			[OtherGUID] [UNIQUEIDENTIFIER],
			[CurrencyGUID] [UNIQUEIDENTIFIER],
			[CurrencyVal] [FLOAT],
			[StartDate] [DATETIME],
			[EndDate] [DATETIME],
			[MatCondId] [INT],
			[CustCondId] [INT],
			[Notes] [VARCHAR](250) COLLATE ARABIC_CI_AI,
			[Category] [INT])

	CREATE INDEX [lg000ndx1] ON [lg000] (LogTime) WITH FILLFACTOR = 90
	CREATE INDEX [lg000ndx2] ON [lg000] (UserGUID) WITH FILLFACTOR = 90
	CREATE INDEX [lg000ndx3] ON [lg000] (Operation) WITH FILLFACTOR = 90
	CREATE INDEX [lg000ndx4] ON [lg000] (RecGUID) WITH FILLFACTOR = 90

	EXECUTE [prcFlag_set] 1 -- re-index

#########################################################
#END