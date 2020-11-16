#include upgrade_core.sql
#include prcDeleteArchivingUnUsedData.sql
###################################################
CREATE PROCEDURE prcUpgradeDatabase_From10009000
AS 
	SET NOCOUNT ON 
	EXEC prcDisableTriggers 'mt000', 1
	EXECUTE prcAddGUIDFld 'DistDeviceEn000', 'CurrencyGuid'
	EXECUTE prcAddFloatFld 'DistDeviceEn000', 'CurrencyVal', 1
	EXECUTE PrcAddBitFld  'Distributor000', 'ShowNearbyCustomersOnly', 0
	EXECUTE [prcAddIntFld] 'Distributor000', 'NewCustomerDefaultPrice', 1
	EXECUTE [prcAddBitFld] 'Distributor000', 'CanUseExpenses', 1
	EXECUTE [prcAlterFld] 'Distributor000', 'CanUseExpenses', 'int'

	IF  NOT EXISTS (
		SELECT * FROM sys.objects 
				WHERE object_id = OBJECT_ID(N'DistExpenses000') AND type in (N'U'))
	BEGIN
		CREATE TABLE DistExpenses000(
					Number int, 
					GUID uniqueidentifier Unique, 
					Name varchar(255), 
					LatinName varchar(255), 
					Code varchar(255), 
					AccountGUID uniqueidentifier, 
					EntryTypeGUID uniqueidentifier, 
					Security int)
	END

	-- prcUpgradeDatabase_From10003595
	EXEC [prcAddFloatFld] 'OrderPayments000', 'UpdatedValue'
	EXEC [prcAddGUIDFld] 'ori000', 'PostGuid'
	EXEC [prcAddIntFld]  'ori000', 'PostNumber'
	EXEC [prcAddGUIDFld] 'ori000', 'BiGuid'
	
	IF [dbo].[fnObjectExists]('bt000.TotalDiscRegardlessItemDisc') =  0
	BEGIN 
		insert Into op000 values (NEWID(),'NotShowBillAfterPost',0, 0, '' ,NULL, 0, 0x0, 0x0 )
		insert Into op000 values (NEWID(),'NoRepeatedMaterials',0, 0, '' ,NULL, 0, 0x0, 0x0 )

		UPDATE UI000
		SET Permission = 0
		WHERE ReportId IN (536965944, 536965945)
	END 

	EXEC prcAddBitFld			'bt000', 'TotalDiscRegardlessItemDisc'
	EXEC prcAddBitFld			'bt000', 'TotalExtraRegardlessItemExtra'
	IF [dbo].[fnObjectExists]('bt000.taxBeforeExtra') = 0
	BEGIN
		EXEC prcAddBitFld	'bt000', 'taxBeforeExtra';	
		EXEC ('UPDATE bt000 SET taxBeforeExtra = CASE WHEN BillType = 1 OR BillType = 3 OR BillType = 5 THEN 0 ELSE taxBeforeDiscount END')
	END
	--------------------------------------------
	-- SMF Project
	--------------------------------------------
	EXEC('
	IF NOT EXISTS(SELECT * FROM [msdb].[dbo].[syscategories] WHERE [name] = N''[Ameen SJ]'')
		EXECUTE [msdb].[dbo].[sp_add_category] @name = N''[Ameen SJ]''
	
	DECLARE 
		@job_id UNIQUEIDENTIFIER,
		@job_name NVARCHAR(250)

	IF EXISTS (SELECT * FROM msdb.dbo.sysjobs WHERE name LIKE ''![Ameen %'' ESCAPE ''!'')
	BEGIN
		SELECT TOP 1 @job_id = job_id, @job_name = name FROM msdb.dbo.sysjobs 
		WHERE 
			((name LIKE ''![Ameen ABJ!]%'' ESCAPE ''!'') OR (name LIKE ''![Ameen CPJ!]%'' ESCAPE ''!'') OR (name LIKE ''![Ameen RCJ!]%'' ESCAPE ''!'') 
				OR (name LIKE ''![Ameen ShrinkDBJ!]%'' ESCAPE ''!'') OR (name LIKE ''![Ameen REINDEX!]%'' ESCAPE ''!'')
			)
			AND 
			(name LIKE ''%!['' + db_name() + ''!]%'' ESCAPE ''!'') 

		WHILE ISNULL(@job_id, 0x0) != 0x0
		BEGIN
			DECLARE @temp_name NVARCHAR(200)
			SET @temp_name = @job_name 

			SET @temp_name = REPLACE(@temp_name, ''[Ameen ABJ]'', ''Backup DB'')
			SET @temp_name = REPLACE(@temp_name, ''[Ameen CPJ]'', ''Reprice Materials'')
			SET @temp_name = REPLACE(@temp_name, ''[Ameen RCJ]'', ''Check Accounts'')
			SET @temp_name = REPLACE(@temp_name, ''[Ameen ShrinkDBJ]'', ''Shrink DB'')
			SET @temp_name = REPLACE(@temp_name, ''[Ameen REINDEX]'', ''Reindex DB'')
												
			SET @temp_name = REPLACE(@temp_name, ''[D]'', '' Daily'')
			SET @temp_name = REPLACE(@temp_name, ''[W]'', '' Weekly'')
			SET @temp_name = REPLACE(@temp_name, ''[M]'', '' Monthly'')

			SET @temp_name = REPLACE(@temp_name, ''['' + db_name() + '']'', '''')
			
			SET @temp_name = ''[Ameen SJ]['' + db_name() + '']'' + @temp_name
			EXEC msdb.[dbo].[sp_update_job] @job_id = @job_id, @new_name = @temp_name, @description = N''Job added from Al-Ameen Program.'', @category_name = N''[Ameen SJ]''

			DECLARE @step_id INT, @step_uid UNIQUEIDENTIFIER, @ignoreLastPriceAndCost NVARCHAR(10)

			SELECT TOP 1 @step_id = step_id, @step_uid = step_uid FROM msdb.dbo.sysjobsteps WHERE job_id = @job_id ORDER BY step_id

			IF ISNULL(@step_id, 0) != 0
			BEGIN
				IF (@job_name LIKE ''![Ameen CPJ!]%'' ESCAPE ''!'')
				BEGIN 
					DECLARE @command NVARCHAR(250) 
					SET @command = (SELECT command FROM msdb.dbo.sysjobsteps WHERE job_id = @job_id AND step_id = @step_id)
					IF ISNULL(@command, '''') != ''''
						SET @ignoreLastPriceAndCost = SUBSTRING(@command, LEN(@command), 1)
				END 

				DECLARE 
					@new_step_name NVARCHAR(500),
					@new_command NVARCHAR(500)
				
				SET @new_step_name = 
						(CASE 
							WHEN (@job_name LIKE ''![Ameen ABJ!]%'' ESCAPE ''!'') THEN ''Backup DB''
							WHEN (@job_name LIKE ''![Ameen CPJ!]%'' ESCAPE ''!'') THEN ''Reprice Materials''
							WHEN (@job_name LIKE ''![Ameen RCJ!]%'' ESCAPE ''!'') THEN ''Check Accounts''
							WHEN (@job_name LIKE ''![Ameen ShrinkDBJ!]%'' ESCAPE ''!'') THEN ''Shrink DB''
							WHEN (@job_name LIKE ''![Ameen REINDEX!]%'' ESCAPE ''!'') THEN ''Reindex DB''
							ELSE ''''
						END)
				SET @new_command = 
						(CASE 
							WHEN (@job_name LIKE ''![Ameen ABJ!]%'' ESCAPE ''!'') THEN ''EXEC prc_SJ_Backup @TaskID = '''' + CAST(@step_uid AS NVARCHAR(250)) + ''''''
							WHEN (@job_name LIKE ''![Ameen CPJ!]%'' ESCAPE ''!'') THEN ''EXEC prc_SJ_RepriceMaterials @TaskID = '''' + CAST(@step_uid AS NVARCHAR(250)) + ''''''
							WHEN (@job_name LIKE ''![Ameen RCJ!]%'' ESCAPE ''!'') THEN ''EXEC prcEntry_rePost''
							WHEN (@job_name LIKE ''![Ameen ShrinkDBJ!]%'' ESCAPE ''!'') THEN ''EXEC prc_SJ_ShrinkDB @TaskID = '''' + CAST(@step_uid AS NVARCHAR(250)) + ''''''
							WHEN (@job_name LIKE ''![Ameen REINDEX!]%'' ESCAPE ''!'') THEN ''EXEC prcReIndexDatabase''
							ELSE ''''
						END)					
				
				EXEC msdb.[dbo].[sp_update_jobstep] @job_id = @job_id, @step_id = @step_id, @step_name = @new_step_name, @command = @new_command

				IF (@job_name LIKE ''![Ameen ABJ!]%'' ESCAPE ''!'')
				BEGIN
					DECLARE @BAK_NUM NVARCHAR(10)
					IF (@job_name LIKE ''![Ameen ABJ!]![D!]%'' ESCAPE ''!'')
						SET @BAK_NUM = (SELECT TOP 1 Value FROM op000 WHERE Name = ''AmnCfg_DailyBackupNum'' AND Type = 0)
					IF (@job_name LIKE ''![Ameen ABJ!]![W!]%'' ESCAPE ''!'')
						SET @BAK_NUM = (SELECT TOP 1 Value FROM op000 WHERE Name = ''AmnCfg_WeeklyBackupNum'' AND Type = 0)
					IF (@job_name LIKE ''![Ameen ABJ!]![M!]%'' ESCAPE ''!'')
						SET @BAK_NUM = (SELECT TOP 1 Value FROM op000 WHERE Name = ''AmnCfg_MonthlyBackupNum'' AND Type = 0)
					IF ISNULL(@BAK_NUM, '''') != ''''
					BEGIN
						INSERT INTO ScheduledJobOptions000(GUID, JobGUID, TaskGUID, Name, Value) 
						SELECT NEWID(), @job_id, CAST(@step_uid AS NVARCHAR(250)), ''BAK_Num'', @BAK_NUM
					END
				END
				IF (@job_name LIKE ''![Ameen CPJ!]%'' ESCAPE ''!'')
				BEGIN
					IF (ISNULL(@ignoreLastPriceAndCost, '''') IN (''0'', ''1''))
					BEGIN 
						INSERT INTO ScheduledJobOptions000(GUID, JobGUID, TaskGUID, Name, Value) 
						SELECT NEWID(), @job_id, CAST(@step_uid AS NVARCHAR(250)), ''REPM_PreserveLast'', @ignoreLastPriceAndCost
					END ELSE BEGIN
						INSERT INTO ScheduledJobOptions000(GUID, JobGUID, TaskGUID, Name, Value) 
						SELECT NEWID(), @job_id, CAST(@step_uid AS NVARCHAR(250)), ''REPM_PreserveLast'', ''0''
					END
				END
			END 

			SET @job_id = NULL
			SET @job_name = NULL

			SELECT TOP 1 @job_id = job_id, @job_name = name FROM msdb.dbo.sysjobs 
			WHERE 
				((name LIKE ''![Ameen ABJ!]%'' ESCAPE ''!'') OR (name LIKE ''![Ameen CPJ!]%'' ESCAPE ''!'') OR (name LIKE ''![Ameen RCJ!]%'' ESCAPE ''!'') 
					OR (name LIKE ''![Ameen ShrinkDBJ!]%'' ESCAPE ''!'') OR (name LIKE ''![Ameen REINDEX!]%'' ESCAPE ''!'')
				)
				AND 
				(name LIKE ''%!['' + db_name() + ''!]%'' ESCAPE ''!'') 
		END
	END');

	
	EXEC prcAddIntFld 'bt000', 'FldClassPrice'
	EXEC prcAddFloatFld 'bi000', 'ClassPrice'
	EXEC prcAddFloatFld 'bi000', 'MatCurVal'
    EXECUTE [prcAddBitFld]  'mt000', 'ClassFlag'
    EXECUTE [prcAddBitFld]  'mt000', 'ForceInClass'
	IF [dbo].[fnObjectExists]('mt000.ForceOutClass') =  0
	BEGIN
        EXECUTE [prcAddBitFld]  'mt000', 'ForceOutClass'
		EXEC(N'UPDATE BLItems000 SET FldIndex = FldIndex + 1 WHERE FldIndex > 1081');
		EXEC(N'UPDATE mt SET ClassFlag = 1 FROM mt000 mt INNER JOIN bi000 bi ON bi.MatGUID = mt.GUID WHERE bi.[ClassPtr] != ''''')
		
		-- Adding COSTING Menu to permissions with ReportId = 5385...
		UPDATE ui000 SET ReportId = ReportId + 1 WHERE ReportId BETWEEN 5385 AND 5400
		UPDATE uix SET ReportID = ReportID + 1 WHERE ReportID BETWEEN 5385 AND 5400
	END 
      
	EXECUTE [prcAddBitFld] 'mt000', 'DisableLastPrice'
	EXECUTE [prcAddFloatFld] 'mt000', 'LastPriceCurVal', 1
	EXEC prcAddDateFld 'cp000', 'Date'

	EXEC('
	DECLARE @fp_date DATE 
	SELECT @fp_date = [dbo].[fnDate_Amn2Sql]([dbo].[fnOption_get](''AmnCfg_FPDate'', default)) 
	SET @fp_date = ISNULL(@fp_date, GETDATE())

	DECLARE 
		@c CURSOR,
		@mtGuid [UNIQUEIDENTIFIER]

	SET @c = CURSOR FAST_FORWARD FOR 
			SELECT GUID FROM mt000

	OPEN @c FETCH FROM @c INTO @mtGuid
	WHILE @@FETCH_STATUS = 0
	BEGIN
		DECLARE @buDate DATE, @biPrice FLOAT, @biUnitFact FLOAT, @buCurrencyGUID UNIQUEIDENTIFIER, @buCurrencyVal FLOAT, @mtCurrencyGUID UNIQUEIDENTIFIER
		SET @buDate = NULL

		SELECT TOP 1 
			@buDate = bu.date,
			@biPrice = [bi].[Price],
			@biUnitFact = 
				(CASE [bi].[Unity]
					WHEN 2 THEN (CASE [mt].[Unit2FactFlag] WHEN 0 THEN [mt].[Unit2Fact] ELSE bi.[Qty] / (CASE bi.[Qty2] WHEN 0 THEN 1 ELSE bi.[Qty2] END) END)
					WHEN 3 THEN (CASE [mt].[Unit3FactFlag] WHEN 0 THEN [mt].[Unit3Fact] ELSE bi.[Qty] / (CASE bi.[Qty3] WHEN 0 THEN 1 ELSE bi.[Qty3] END) END)
					ELSE 1
				END),
			@buCurrencyGUID = bu.CurrencyGUID,
			@buCurrencyVal = bu.CurrencyVal,
			@mtCurrencyGUID = mt.CurrencyGUID
		FROM
			bu000 bu 
			INNER JOIN bi000 bi ON bu.GUID = bi.ParentGUID 
			INNER JOIN mt000 mt ON mt.GUID = bi.MatGUID 
			INNER JOIN bt000 bt ON bt.GUID = bu.TypeGUID 
		WHERE 
			bt.bAffectLastPrice = 1 
			AND 
			bi.matguid = @mtGuid
		ORDER BY 
			bu.date DESC,
			bt.[SortFlag] DESC,
			bu.Number DESC,
			bi.Number DESC

		DECLARE @LastPriceStr NVARCHAR(MAX);
		IF (@buDate IS NULL)
		BEGIN 
            UPDATE mt000 SET DisableLastPrice = 0, 
				LastPriceDate = CASE WHEN LastPriceDate < @fp_date THEN  
					@fp_date ELSE LastPriceDate END, LastPriceCurVal = CASE CurrencyVal WHEN 0 THEN 1 ELSE CurrencyVal END 
				WHERE guid = @mtGuid;
           
		END ELSE BEGIN 
			DECLARE @LastPrice FLOAT 
			DECLARE @LastPrice_CurrencyVal FLOAT 
				
			SET @LastPrice = (CASE @biUnitFact WHEN 0 THEN 0 ELSE @biPrice / @biUnitFact END)
			SET @LastPrice_CurrencyVal = @buCurrencyVal

			IF @buCurrencyGUID <> @mtCurrencyGUID
			BEGIN 
				DECLARE @mtCurrencyVal_ByDate FLOAT 
				SET @mtCurrencyVal_ByDate = [dbo].fnGetCurVal(@mtCurrencyGUID, @buDate);
				IF ISNULL(@mtCurrencyVal_ByDate, 0) <> 0
				BEGIN 
					SET @LastPrice_CurrencyVal = @mtCurrencyVal_ByDate
					--SET @LastPrice = @LastPrice* @buCurrencyVal/ @mtCurrencyVal_ByDate
				END
			END 
			UPDATE mt000 
					SET [DisableLastPrice] = 1,
					[LastPriceDate] =@buDate,
					[LastPrice] =@LastPrice,
					[LastPrice2] = @LastPrice * Unit2Fact,
					[LastPrice3] =@LastPrice * Unit3Fact, 
					[LastPriceCurVal] = @LastPrice_CurrencyVal
			WHERE 
					[GUID] = @mtGuid;
		END
		FETCH FROM @c INTO @mtGuid
	END CLOSE @c DEALLOCATE @c ');

	EXEC('DELETE [cp] 
	FROM 
		[cp000] [cp] 
		INNER JOIN 
		(
			SELECT
				[buCustPtr], [biMatPtr]
			FROM 
				[vwExtended_bi]
			WHERE 
				( [btAffectCustPrice] <> 0) 
				AND 
				( [buIsPosted] <> 0) 
				AND 
				( [biUnitPrice] <> 0) 
				AND 
				( [buCustPtr] <> 0x0)
			GROUP BY 
				[buCustPtr], [biMatPtr]
		) [bi]  
		ON ([cp].[CustGuid] = [bi].[buCustPtr]) AND ([cp].[MatGuid] = [bi].[biMatPtr])
	
	CREATE TABLE [#cp] 
	( 
            [CeNumber]        [INT],
            [CustGUID]        [UNIQUEIDENTIFIER], 
            [CurrencyGUID]    [UNIQUEIDENTIFIER], 
            [CurrencyVal]     [FLOAT],
            [MatGUID]         [UNIQUEIDENTIFIER], 
            [BiPrice]         [FLOAT], 
            [BiDiscount]      [FLOAT], 
            [BiExtra]         [FLOAT],
            [Unity]                 [FLOAT],
            [Date]                  DATETIME
	) 
	
	;WITH Bill AS
	(
		SELECT
			xbi.buGUID,
			ce.Number AS ceNumber,
			xbi.buCustPtr,
			xbi.biMatPtr,
			xbi.biUnity,
			xbi.buDate
		FROM [vwExtended_bi] xbi
			INNER JOIN bi000 bi ON bi.[guid] = xbi.[biGuid]	
			INNER JOIN er000 er ON xbi.buGuid = er.ParentGuid
			INNER JOIN ce000 ce ON ce.[guid] = er.EntryGuid
		WHERE  
			(xbi.[btAffectCustPrice] <> 0)
			AND (xbi.[buIsPosted] <> 0)  
				AND   (xbi.[biUnitPrice] <> 0)  
			AND (xbi.[buCustPtr] <> 0x0) 
	)
	INSERT INTO #cp
	SELECT DISTINCT
		ceNumber,
		buCustPtr,
		0x0 CurrencyGUID,
		0,
		biMatPtr,
		0,
		0,
		0,
		biUnity,
		buDate
	FROM
		Bill AS B1
	WHERE 
		B1.buDate = (SELECT MAX(buDate) FROM Bill WHERE buCustPtr = B1.buCustPtr AND biMatPtr = B1.biMatPtr AND biUnity = B1.biUnity)
		AND B1.ceNumber = (SELECT MAX(ceNumber) FROM Bill WHERE buCustPtr = B1.buCustPtr AND biMatPtr = B1.biMatPtr AND biUnity = B1.biUnity AND buDate = B1.buDate)
	
	UPDATE #cp
	SET
		[CurrencyVal] = CASE WHEN mt.CurrencyGuid = xbi.buCurrencyPtr THEN xbi.buCurrencyVal ELSE dbo.fnGetCurVal(mt.CurrencyGuid, xbi.buDate) END,
		[CurrencyGUID] = mt.CurrencyGuid,
		[BiPrice] = (xbi.[biUnitPrice] *  CASE xbi.[btVATSystem]  WHEN 2 THEN  (1 + (xbi.biVATr / 100)) ELSE 1 END) *	 
			(CASE xbi.[biUnity] 
				WHEN 2 THEN xbi.[mtUnit2Fact]  
				WHEN 3 THEN xbi.[mtUnit3Fact]  
				ELSE 1  
			END), 
		[BiDiscount] = xbi.biDiscount, 
		[BiExtra] = xbi.biExtra 
	FROM 
		[vwExtended_bi] xbi
		INNER JOIN mt000 mt ON mt.[Guid] = xbi.biMatPtr
		INNER JOIN bi000 bi ON bi.[guid] = xbi.[biGuid]	
		INNER JOIN er000 er ON xbi.buGuid = er.ParentGuid
		INNER JOIN ce000 ce ON ce.[guid] = er.EntryGuid
		INNER JOIN #cp cp ON
			(ce.Number = cp.[CeNumber])
			AND (xbi.buCustPtr = cp.[CustGUID])
			AND (xbi.biMatPtr = cp.[MatGUID])
			AND (xbi.biUnity = cp.[Unity])
			AND (xbi.buDate = cp.[Date])

	INSERT INTO cp000 (
		[Price],
		[Unity],
		[CustGUID],
		[MatGUID],
		[DiscValue],
		[ExtraValue],
		[CurrencyVal],
		[CurrencyGUID],
		[Date])
	SELECT DISTINCT
		[BiPrice],
		[Unity],
		[CustGUID],
		[MatGUID],
		[BiDiscount],
		[BiExtra],
		[CurrencyVal],
		[CurrencyGUID],
		Date
	FROM
		#cp')

	IF NOT EXISTS (SELECT * FROM op000 WHERE name = 'CanselCheckingAvailableSpace' AND Value = '1')
	BEGIN 
		IF NOT EXISTS (SELECT * FROM op000 WHERE name = 'NumberDaysAfterShrink')
		BEGIN 
			INSERT INTO op000([GUID], Name, Value, [Type])
			SELECT NEWID(), 'NumberDaysAfterShrink', '10', 0
		END 	
		IF NOT EXISTS (SELECT * FROM op000 WHERE name = 'NumberDaysOFShrink')
		BEGIN 
			INSERT INTO op000([GUID], Name, Value, [Type])
			SELECT NEWID(), 'NumberDaysOFShrink', '7', 0
		END 	
		IF NOT EXISTS (SELECT * FROM op000 WHERE name = 'AllowedWaste')
		BEGIN 
			INSERT INTO op000([GUID], Name, Value, [Type])
			SELECT NEWID(), 'AllowedWaste', '75', 0
		END 	
	END
	
	-- prcUpgradeDatabase_From10003597
	--------------------------------------------
	-- ANM01 Project 
	--------------------------------------------
	EXECUTE prcAddBitFld 'di000', 'IsValue'
	EXECUTE prcAddBitFld 'di000', 'IsRatio'
    EXECUTE	[prcAddFld]	'gri000', 'ItemType', 'TINYINT NOT NULL DEFAULT 0'
    EXECUTE	prcAddIntFld 'us000', 'MaxPrice', 1
	EXECUTE prcAddIntFld 'usx', 'MaxPrice', 1
	EXECUTE	prcAddIntFld 'UserMaxDiscounts000', 'MaxPrice', 1
	EXECUTE	[prcAddBitFld]	'bt000', 'bCostToDiscount'
	EXECUTE	[prcAddBitFld]	'bt000', 'NoAddExistBill'
	EXECUTE	[prcAddBitFld]	'bt000', 'bForceCustomer'
	EXECUTE	[prcAddBitFld]	'bt000', 'bCentringCustomerAccount'
	EXECUTE	[prcAddGUIDFld]	'bt000',  'DefaultGroupGUID'
	EXECUTE	[prcAddGUIDFld]	'bt000', 'DefMainAccount'
	EXECUTE prcAddIntFld  'Allocations000', 'DistPayNum'
    EXECUTE prcAddIntFld  'Allocations000', 'RestPayNum'
	EXECUTE prcAddCharFld 'Allocations000', 'Note', 250
	EXECUTE prcAddDateFld 'Allocations000', 'StartDistDate'
	EXECUTE prcAddGUIDFld 'Allocations000', 'CostDebitGuid'
	EXECUTE prcAddCharFld 'Allocations000', 'CostDebitName',250
	EXECUTE prcAddGUIDFld 'Allocations000', 'CostCreditGuid'
	EXECUTE prcAddCharFld 'Allocations000', 'CostCreditName',250
	EXECUTE prcAddIntFld  'Allocations000', 'CirclePayNum'
	EXECUTE [prcAlterFld] 'Allocations000', 'EntryGenrated', 'BIT'
	EXECUTE	[prcAddBitFld]	'bt000', 'bContraCostToDiscount'
	EXECUTE [prcAddGUIDFld] 'MN000','StepCost'
	EXECUTE prcAddCharFld 'ProductionLine000', 'LatinName', 250
	EXECUTE prcAddGUIDFld 'ProductionLine000', 'ManufactoryGUID'
	EXECUTE prcAddGUIDFld 'ProductionLine000', 'InProcessAccGuid'
	EXECUTE prcAddGUIDFld 'ProductionLine000', 'SNDesignGuid'
	EXECUTE prcAddGUIDFld 'JobOrder000', 'ManufactoryGUID'
	EXECUTE PrcAddBitFld  'JobOrder000', 'UseHrConnection'
	EXECUTE prcAddGUIDFld 'JobOrder000', 'SNDesignGuid'
	EXECUTE prcAddGUIDFld 'JocTrans000', 'Manufactory'
	EXEC prcEnableTriggers 'mt000'

	IF NOT EXISTS(SELECT * FROM mc000 WHERE [Type] = 9000 AND [Asc1] = 'Inactive All Users')
	BEGIN
		INSERT INTO mc000([Type], [Asc1])
		VALUES(9000, 'Inactive All Users');
	END
######################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10009001
AS  
	SET NOCOUNT ON 
	EXEC [prcAddCharFld]  'cu000', 'NSMobile1'	, 100 
	EXEC [prcAddCharFld]  'cu000', 'NSMobile2'	, 100
	EXEC [prcAddCharFld]  'cu000', 'NSEMail1'		, 250
	EXEC [prcAddCharFld]  'cu000', 'NSEMail2'		, 250
	EXEC [prcAddBitFld]   'cu000', 'NSNotSendSMS' , 1
	EXEC [prcAddBitFld]   'cu000', 'NSNotSendEmail', 1
	EXEC [prcAddCharFld]  'us000', 'MobilePhone'	, 100
	EXEC [prcAddIntFld] 'cu000', 'NSEmailUse'
	EXEC [prcAddIntFld] 'cu000', 'NSSmsUse'
	EXEC [prcAddCharFld] 'specialOffers000' ,'EmailMessageTemplate', 4000
	EXEC [prcAddCharFld] 'specialOffers000' ,'SmsMessageTemplate', 4000
	EXEC [prcAddFloatFld] 'mt000' ,'PrevQty',0
	EXECUTE [prcAddFloatFld] 'InvReconcileItem000', 'UnitDet1', 0
	EXECUTE [prcAddFloatFld] 'InvReconcileItem000', 'UnitDet2', 0
	EXECUTE [prcAddFloatFld] 'InvReconcileItem000', 'UnitDet3', 0

	EXEC [prcAddGUIDFld] 'BPOptions000', 'ConfigurationID'
######################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10009002
AS
	SET NOCOUNT ON 
	DELETE FROM brt	WHERE TableName = 'km000'

	EXEC [prcAddFloatFld] 'OrderPayments000', 'UpdatedValue'
	EXEC [prcAddGUIDFld] 'ori000', 'PostGuid'
	EXEC [prcAddIntFld]  'ori000', 'PostNumber'
	EXEC [prcAddGUIDFld] 'ori000', 'BiGuid'
	
	insert Into op000 values (NEWID(),'NotShowBillAfterPost',0, 0, '' ,NULL, 0, 0x0, 0x0 )

	insert Into op000 values (NEWID(),'NoRepeatedMaterials',0, 0, '' ,NULL, 0, 0x0, 0x0 )

	UPDATE UI000
	SET Permission = 0
	WHERE ReportId IN (536965944, 536965945)

	-- CMPT project
	IF [dbo].[fnObjectExists]('bp000.Type') =  0
	BEGIN
		EXECUTE prcAddIntFld 'bp000', 'Type'

		EXEC ('UPDATE bp000
				SET    DebtGUID = er.ParentGUID
				FROM   bp000 bp
					   INNER JOIN en000 en
							   ON en.GUID = bp.DebtGUID
					   INNER JOIN ce000 ce
							   ON ce.Guid = en.ParentGUID
					   INNER JOIN er000 er
							   ON er.EntryGUID = ce.GUID
					   INNER JOIN bu000 bu
							   ON bu.GUID = er.ParentGUID
					   INNER JOIN bt000 bt
							   ON bt.GUID = bu.TypeGUID
				WHERE  er.ParentType = 2
					   AND ( ( bt.bIsInput = 1
							   AND en.Credit <> 0 )
							  OR ( bt.bIsOutput = 1
								   AND en.Debit <> 0 ) )

				UPDATE bp000
				SET    PayGUID = er.ParentGUID
				FROM   bp000 bp
					   INNER JOIN en000 en
							   ON en.GUID = bp.PayGUID
					   INNER JOIN ce000 ce
							   ON ce.Guid = en.ParentGUID
					   INNER JOIN er000 er
							   ON er.EntryGUID = ce.GUID
					   INNER JOIN bu000 bu
							   ON bu.GUID = er.ParentGUID
					   INNER JOIN bt000 bt
							   ON bt.GUID = bu.TypeGUID
				WHERE  er.ParentType = 2
					   AND ( ( bt.bIsInput = 1
							   AND en.Credit <> 0 )
							  OR ( bt.bIsOutput = 1
								   AND en.Debit <> 0 ) )

				----------------تعديل نوع الدفعةالأولى و ربطها مع الفاتورة المتولدة عنها -----------------
				UPDATE bp000
				SET    DebtGUID = bu.GUID,
					   Val = CASE en.Debit
							   WHEN 0 THEN en.Credit
							   ELSE en.Debit
							 END,
					   PayVal = CASE en.Debit
								  WHEN 0 THEN en.Credit
								  ELSE en.Debit
								END,
					   Type = 1
				FROM   bp000 bp
					   INNER JOIN en000 en
							   ON en.GUID = bp.PayGUID
					   INNER JOIN ce000 ce
							   ON ce.Guid = en.ParentGUID
					   INNER JOIN er000 er
							   ON er.EntryGUID = ce.GUID
					   INNER JOIN bu000 bu
							   ON bu.GUID = er.ParentGUID
					   INNER JOIN bt000 bt
							   ON bt.GUID = bu.TypeGUID
				WHERE  er.ParentType = 2
					   AND ( ( bt.bIsInput = 1
							   AND en.Credit = 0 )
							  OR ( bt.bIsOutput = 1
								   AND en.Debit = 0 ) )
					   AND ( en.ContraAccGUID = bu.FPayAccGUID )
					   AND ( en.AccountGUID = bu.CustAccGUID )

				UPDATE bp000
				SET    PayGUID = bu.GUID,
					   Val = CASE en.Debit
							   WHEN 0 THEN en.Credit
							   ELSE en.Debit
							 END,
					   PayVal = CASE en.Debit
								  WHEN 0 THEN en.Credit
								  ELSE en.Debit
								END,
					   Type = 1
				FROM   bp000 bp
					   INNER JOIN en000 en
							   ON en.GUID = bp.DebtGUID
					   INNER JOIN ce000 ce
							   ON ce.Guid = en.ParentGUID
					   INNER JOIN er000 er
							   ON er.EntryGUID = ce.GUID
					   INNER JOIN bu000 bu
							   ON bu.GUID = er.ParentGUID
					   INNER JOIN bt000 bt
							   ON bt.GUID = bu.TypeGUID
				WHERE  er.ParentType = 2
					   AND ( ( bt.bIsInput = 1
							   AND en.Credit = 0 )
							  OR ( bt.bIsOutput = 1
								   AND en.Debit = 0 ) )
					   AND ( en.ContraAccGUID = bu.FPayAccGUID )
					   AND ( en.AccountGUID = bu.CustAccGUID )

				INSERT INTO bp000
							(GUID,
							 DebtGuid,
							 PayGuid,
							 PayType,
							 Val,
							 CurrencyGuid,
							 CurrencyVal,
							 RecType,
							 DebitType,
							 ParentDebitGUID,
							 ParentPayGUID,
							 PayVal,
							 PayCurVal,
							 Type)
				SELECT Newid(),
					   bu.GUID,
					   en.GUID,
					   0,
					   CASE en.Debit
						 WHEN 0 THEN en.Credit
						 ELSE en.Debit
					   END,
					   bu.CurrencyGUID,
					   bu.CurrencyVal,
					   0,
					   0,
					   bu.GUID,
					   0x0,
					   CASE en.Debit
						 WHEN 0 THEN en.Credit
						 ELSE en.Debit
					   END,
					   bu.CurrencyVal,
					   1
				FROM   en000 en
					   INNER JOIN ce000 ce
							   ON ce.Guid = en.ParentGUID
					   INNER JOIN er000 er
							   ON er.EntryGUID = ce.GUID
					   INNER JOIN bu000 bu
							   ON bu.GUID = er.ParentGUID
					   INNER JOIN bt000 bt
							   ON bt.GUID = bu.TypeGUID
				WHERE  er.ParentType = 2
					   AND ( ( bt.bIsInput = 1
							   AND en.Credit = 0 )
							  OR ( bt.bIsOutput = 1
								   AND en.Debit = 0 ) )
					   AND ( en.ContraAccGUID = bu.FPayAccGUID )
					   AND ( en.AccountGUID = bu.CustAccGUID )
					   AND ( NOT EXISTS (SELECT *
										 FROM   bp000
										 WHERE  ( DebtGUID = bu.GUID
												  AND PayGUID = en.GUID )
												 OR ( PayGUID = bu.GUID
													  AND DebtGUID = en.GUID )) )

				---------- تعديل نوع الأوراق المالية المتولدة عن الفاتورة وربطها مع الفاتورة المتولدة عنها-----------
				UPDATE bp000
				SET    DebtGUID = bu.GUID,
					   Val = CASE en.Debit
							   WHEN 0 THEN en.Credit
							   ELSE en.Debit
							 END,
					   PayVal = CASE en.Debit
								  WHEN 0 THEN en.Credit
								  ELSE en.Debit
								END,
					   Type = 2
				FROM   bp000 bp
					   INNER JOIN en000 en
							   ON en.GUID = bp.PayGUID
					   INNER JOIN ce000 ce
							   ON ce.GUID = en.ParentGUID
					   INNER JOIN er000 er
							   ON er.EntryGUID = ce.GUID
					   INNER JOIN ch000 ch
							   ON ch.Guid = er.ParentGUID
					   INNER JOIN bu000 bu
							   ON bu.GUID = ch.ParentGUID
				WHERE  er.ParentType = 5

				UPDATE bp000
				SET    PayGUID = bu.GUID,
					   Val = CASE en.Debit
							   WHEN 0 THEN en.Credit
							   ELSE en.Debit
							 END,
					   PayVal = CASE en.Debit
								  WHEN 0 THEN en.Credit
								  ELSE en.Debit
								END,
					   Type = 2
				FROM   bp000 bp
					   INNER JOIN en000 en
							   ON en.GUID = bp.DebtGUID
					   INNER JOIN ce000 ce
							   ON ce.GUID = en.ParentGUID
					   INNER JOIN er000 er
							   ON er.EntryGUID = ce.GUID
					   INNER JOIN ch000 ch
							   ON ch.Guid = er.ParentGUID
					   INNER JOIN bu000 bu
							   ON bu.GUID = ch.ParentGUID
				WHERE  er.ParentType = 5

				INSERT INTO bp000
							(GUID,
							 DebtGuid,
							 PayGuid,
							 PayType,
							 Val,
							 CurrencyGuid,
							 CurrencyVal,
							 RecType,
							 DebitType,
							 ParentDebitGUID,
							 ParentPayGUID,
							 PayVal,
							 PayCurVal,
							 Type)
				SELECT Newid(),
					   bu.GUID,
					   en.GUID,
					   0,
					   CASE en.Debit
						 WHEN 0 THEN en.Credit
						 ELSE en.Debit
					   END,
					   bu.CurrencyGUID,
					   bu.CurrencyVal,
					   0,
					   0,
					   bu.GUID,
					   0x0,
					   CASE en.Debit
						 WHEN 0 THEN en.Credit
						 ELSE en.Debit
					   END,
					   bu.CurrencyVal,
					   2
				FROM   en000 en
					   INNER JOIN ce000 ce
							   ON ce.GUID = en.ParentGUID
					   INNER JOIN er000 er
							   ON er.EntryGUID = ce.GUID
					   INNER JOIN ch000 ch
							   ON ch.Guid = er.ParentGUID
					   INNER JOIN bu000 bu
							   ON bu.GUID = ch.ParentGUID
				WHERE  er.ParentType = 5
					   AND ( en.AccountGUID = bu.CustAccGUID )
					   AND ( NOT EXISTS (SELECT *
										 FROM   bp000
										 WHERE  ( DebtGUID = bu.GUID
												  AND PayGUID = en.GUID )
												 OR ( PayGUID = bu.GUID
													  AND DebtGUID = en.GUID )) )

				---------------حذف الدفعات المرتبطة بأسطر الحسم من سند الفاتورة------------
				DELETE bp
				FROM   bp000 bp
					   INNER JOIN en000 en
							   ON en.GUID = bp.PayGUID
					   INNER JOIN ce000 ce
							   ON ce.Guid = en.ParentGUID
					   INNER JOIN er000 er
							   ON er.EntryGUID = ce.GUID
					   INNER JOIN bu000 bu
							   ON bu.GUID = er.ParentGUID
					   INNER JOIN bt000 bt
							   ON bt.GUID = bu.TypeGUID
				WHERE  er.ParentType = 2
					   AND ( ( bt.bIsInput = 1
							   AND en.Credit = 0 )
							  OR ( bt.bIsOutput = 1
								   AND en.Debit = 0 ) )
					   AND ( en.ContraAccGUID <> bu.FPayAccGUID )
					   AND ( en.AccountGUID = bu.CustAccGUID ) 
				')

	EXEC('
	CREATE FUNCTION fnGetOrDate(@OrAddInfoGuid UNIQUEIDENTIFIER , @DateType TINYINT)
	RETURNS DATE
	AS
	BEGIN
		RETURN (
		SELECT 
			CASE @DateType 
				WHEN 0 THEN SSDATE  -- الشحن المقترح
				WHEN 1 THEN SADATE  -- الوصول المقترح
				WHEN 2 THEN SDDATE  -- التسليم المقترح
				WHEN 3 THEN ASDATE  -- الشحن المتفق عليه
				WHEN 4 THEN AADATE  -- الوصول المتفق عليه 
				WHEN 5 THEN ADDATE  -- التسليم المتفق عليه
				WHEN 6 THEN SPDATE  -- الاعتماد
				WHEN 7 THEN APDATE  -- التسليم المتوقع
			END
		FROM ORADDINFO000
		WHERE Guid = @OrAddInfoGuid)		
	END ')

	EXEC('
	CREATE VIEW vORP
	AS 
		SELECT 
		[bu].[buGuid] AS BillGuid,
		[o].[Guid] AS OrderGuid,
		[bu].[buDate] AS DueDate,

		p.[Guid] AS PaymentGuid,
		p.Number AS PaymentNumber,
		CASE WHEN o.PTType = 3 THEN 2 ELSE 
			CASE WHEN o.PTType = 0 THEN 0 ELSE 1 END
		END AS PaymentType, -- 0 = none, 1 = one payment, 2 = multipayments
		CASE WHEN p.[Guid] IS NULL THEN ((bu.buTotal + bu.buTotalExtra + bu.buVat) - (bu.buTotalDisc  + bu.buBonusDisc)) ELSE p.Value END / buCurrencyVal  AS PaymentValue,
		CASE WHEN p.[Guid] IS NULL THEN ((bu.buTotal + bu.buTotalExtra + bu.buVat) - (bu.buTotalDisc  + bu.buBonusDisc)) ELSE p.Value END AS PaymentValueWithCurrency,
		CASE o.PTType
			WHEN 1 THEN DATEADD(DAY, o.[PTDaysCount], dbo.fnGetOrDate(o.GUID, o.PTOrderDate))
			WHEN 2 THEN o.PTDate
			WHEN 3 THEN p.PayDate
			ELSE [dbo].fnGetOrDate(o.GUID, o.PTOrderDate)
		END AS PaymentDate,
		p.UpdatedValue AS UpdatedValueWithCurrency,
		p.UpdatedValue / buCurrencyVal  AS UpdatedValue
	FROM 
		vwbu bu 
		INNER JOIN vwbt bt ON [bt].[btGuid] = [bu].[buType]
		INNER JOIN orAddInfo000 [o] ON [o].[ParentGuid] = [bu].[buGuid] 
		LEFT JOIN OrderPayments000 p ON p.BillGuid = bu.[buGuid]
	WHERE 
		bu.[buPayType] = 1 
	')


		UPDATE b
		SET b.[ParentDebitGUID] = orp.[BillGuid]
		FROM vORP orp
		INNER JOIN bp000 b ON b.[DebtGUID] = orp.[PaymentGuid]

		UPDATE b
		SET b.[ParentPayGUID] = orp.[BillGuid]
		FROM vORP orp
		INNER JOIN bp000 b ON b.[PayGUID] = orp.[PaymentGuid]

		IF OBJECT_ID('dbo.km000', 'U') IS NOT NULL 
		BEGIN
			EXEC prcDropTable 'km000'
			EXEC prcDropTable 'ki000'
			EXEC prcDropView 'vtKM'
			EXEC prcDropView 'vbKM'
			EXEC prcDropView 'vcKM'
			EXEC prcDropView 'vwKM'
		END
		DELETE FROM brt	WHERE tablename='km000'


		IF (NOT EXISTS(SELECT * FROM op000
		WHERE Name = 'AmnCfg_UPDATEORDERPAYMENTSANDPOST'))
	BEGIN
		EXEC prcExecuteSQL 'UPDATE OrderPayments000 SET UpdatedValue = Value'
		EXEC prcExecuteSQL 'SELECT * into	#tempPaymentGuid from vORP

		SELECT * from #tempPaymentGuid
						INSERT INTO OrderPayments000 (GUID , BillGuid, Number, PayDate, Value, Percentage, UpdatedValue) 
								SELECT 
								NEWID(),
								[o].[ParentGuid],
								1,
								CASE o.PTType
									WHEN 1 THEN DATEADD(DAY, o.[PTDaysCount], dbo.fnGetOrDate(o.GUID, o.PTOrderDate))
									WHEN 2 THEN o.PTDate
									ELSE [dbo].fnGetOrDate(o.GUID, o.PTOrderDate)
								END ,
								buTotal,
								100,
								buTotal
							FROM 
								vwbu bu 
								INNER JOIN vwbt bt ON [bt].[btGuid] = [bu].[buType]
								INNER JOIN orAddInfo000 [o] ON [o].[ParentGuid] = [bu].[buGuid] 
							WHERE 
								bu.[buPayType] = 1 AND o.PTType <> 3
								AND [o].[ParentGuid] NOT IN (SELECT BillGuid FROM OrderPayments000)
					
					EXECUTE sp_refreshview ''vORP''

					SELECT orp.paymentGuid as Guid,orp2.PaymentGuid as guid2
					 INTO #GUIDs FROM vORP orp2 INNER JOIN #tempPaymentGuid  orp
					  ON orp.BillGuid=orp2.BillGuid AND orp2.DueDate=orp.DueDate 
					  AND orp2.OrderGuid=orp.OrderGuid
					  AND orp2.PaymentDate=orp.paymentDate AND orp.PaymentValue= orp2.PaymentValue AND orp.PaymentDate= orp2.PaymentDate

					  begin transaction

						select * from #GUIDs
  						UPDATE b
						SET b.[DebtGUID] = orp.guid2
						FROM #GUIDs orp
						INNER JOIN bp000 b ON b.[DebtGUID] = orp.Guid

						UPDATE b
						SET b.[PayGUID] = orp.guid2
						FROM #GUIDs orp
						INNER JOIN bp000 b ON b.[PayGUID] = orp.Guid
						Commit
						'
		EXEC prcExecuteSQL '

		SELECT * into	#tempPaymentGuid from vORP
			CREATE TABLE #Result(
				OrderGuid UNIQUEIDENTIFIER,
				PaymentGUID UNIQUEIDENTIFIER,
				[Date] DATE,
				Total FLOAT,
				Dif FLOAT,
				Finished INT);
		
			;WITH TotalPosted AS
			(
				SELECT
					ori.POGUID AS OrderGuid,
					Sum(( bi.BiQty * ( bi.BiPrice + BiExtra - BiDiscount ) ) + ( BiVat )- ( biBonusDisc ))  AS TotalPosted
				FROM
					vwExtended_bi bi
					  INNER JOIN ori000 ori
                           ON bi.biGUID = ori.BiGUID
                   INNER JOIN oit000 oit
                           ON ori.TypeGuid = oit.[Guid]
				WHERE
					oit.QtyStageCompleted = 1 AND ori.Qty > 0 AND ori.Type = 0
				GROUP BY
					ori.POGUID
			),
			TotalPayment AS 
			(
				SELECT
					p.BillGuid AS OrderGuid,
					SUM(p.UpdatedValue) AS TotalPayment
				FROM
					OrderPayments000 p
				GROUP BY
					P.BillGuid
			)
			INSERT INTO #Result
			SELECT  
				bu.buGUID,
				PAY.[Guid], 
				PAY.[PayDate],
				Pay.[UpdatedValue] / bu.[buCurrencyVal],
				(Payment.TotalPayment -  Posted.TotalPosted)/ bu.[buCurrencyVal],
				orinfo.finished
			FROM  
				vwBu AS Bu 
				JOIN TotalPosted Posted ON bu.buGUID = Posted.OrderGuid
				JOIN TotalPayment Payment ON bu.buGUID = Payment.OrderGuid
				INNER JOIN OrderPayments000 AS PAY ON PAY.BillGuid = Bu.buGUID 
				INNER JOIN OrAddInfo000 AS orinfo ON orinfo.[ParentGUID] = bu.[buGUID]
			WHERE  
				Pay.[UpdatedValue] <> 0
				AND orinfo.Add1 <> 1 
			ORDER BY 
				PAY.[PayDate] DESC
			
			DECLARE @OrderGUID uniqueidentifier,
					@PaymentGUID uniqueidentifier,
					@Date Date,
					@Total Float,
					@Dif Float,
					@Finished INT
			
					DECLARE i CURSOR FOR SELECT OrderGuid,PaymentGUID, Date, Total, Dif, Finished FROM #Result   
					OPEN i  
						FETCH NEXT FROM i INTO @OrderGUID,@PaymentGUID, @Date, @Total, @Dif, @Finished 
						DECLARE @OldGuid uniqueidentifier = 0x0
						DECLARE @DifValue Float
			
						WHILE @@FETCH_STATUS = 0  
						BEGIN  
						IF (@OldGuid <> @OrderGUID)
							Begin
								SET @OldGuid = @OrderGUID
								SET @DifValue = @Dif
							End 
							IF (@DifValue < 0)
							BEGIN
								SET @DifValue = ABS(@Dif) 
								UPDATE OrderPayments000 SET UpdatedValue = UpdatedValue + @DifValue WHERE Guid = @PaymentGUID
								SET @DifValue = 0
							END
							ELSE IF (@DifValue <> 0) AND (@DifValue >= @Total AND @Total <> 0)AND(@Finished <> 0)
							Begin
								SET @DifValue -= @Total	
								IF EXISTS (SELECT * FROM bp000 WHERE DebtGUID = @PaymentGUID)
								BEGIN
									DELETE FROM bp000 WHERE DebtGUID = @PaymentGUID
								END			
								UPDATE OrderPayments000 SET Updatedvalue = 0 WHERE Guid = @PaymentGUID
							END
							ELSE IF (@DifValue <> 0) AND (@DifValue < @Total AND @Total <> 0)AND(@Finished <> 0)
							BEGIN
								SET @Total -= @DifValue
								SET @DifValue = 0
								IF EXISTS (SELECT * FROM bp000 WHERE DebtGUID = @PaymentGUID)
								BEGIN
									DELETE FROM bp000 WHERE DebtGUID = @PaymentGUID
								END	
								UPDATE OrderPayments000 SET UpdatedValue = @Total WHERE Guid = @PaymentGUID
							END 
							FETCH NEXT FROM i INTO  @OrderGuid,@PaymentGUID, @Date, @Total, @Dif, @Finished
						END  
					CLOSE i  
					DEALLOCATE i 

					EXECUTE sp_refreshview ''vORP''

					SELECT orp.paymentGuid as Guid,orp2.PaymentGuid as guid2
					 INTO #GUIDs FROM vORP orp2 INNER JOIN #tempPaymentGuid  orp
					  ON orp.BillGuid=orp2.BillGuid AND orp2.DueDate=orp.DueDate 
					  AND orp2.OrderGuid=orp.OrderGuid
					  AND orp2.PaymentDate=orp.paymentDate AND orp.PaymentValue= orp2.PaymentValue AND orp.PaymentDate= orp2.PaymentDate

					  select * from #GUIDs
  						UPDATE b
						SET b.[DebtGUID] = orp.guid2
						FROM #GUIDs orp
						INNER JOIN bp000 b ON b.[DebtGUID] = orp.Guid

						UPDATE b
						SET b.[PayGUID] = orp.guid2
						FROM #GUIDs orp
						INNER JOIN bp000 b ON b.[PayGUID] = orp.Guid
					
					'

	  EXEC prcExecuteSQL '
	  SELECT * into	#tempPaymentGuid from vORP
	  CREATE TABLE #Result(
				Number1 INT,
				Number2 INT,
				Guid1 UNIQUEIDENTIFIER,
				Guid2 UNIQUEIDENTIFIER,
				OrderGuid UNIQUEIDENTIFIER,
				POIGUID UNIQUEIDENTIFIER,
				PostDate DATE,
				FromStateGuid UNIQUEIDENTIFIER,
				ToStateGuid UNIQUEIDENTIFIER,
				BuGuid UNIQUEIDENTIFIER,
				Qty1 float,
				Qty2 float,
				Operation INT,
			);
		
			INSERT INTO #Result
			SELECT DISTINCT
				o.oriNumber,
				previousState.Number,
				o.oriGUID,
				previousState.GUID,
				o.oriPOGUID,
				o.oriPOIGuid,
				o.oriDATE,
				previousState.TypeGuid,
				o.oriTypeGuid,
				CASE oit1.operation WHEN 3 THEN 0x0 ELSE o.oriBuGuid END,
				o.oriQty,
				previousState.Qty,
				oit1.operation
			FROM
				vwOri o
				INNER JOIN ori000 previousState ON previousState.POIGUID = [o].oriPOIGuid AND previousState.Number = [o].oriNumber - 1
				LEFT JOIN oit000 oit1 ON oit1.[GUID] = o.oriTypeGuid
				LEFT JOIN vwBu bu ON bu.buGUID = o.oriBuGUID
			WHERE
				[o].[oriTypeGuid] <> [previousState].[TypeGuid] AND ABS(o.oriQty) = ABS(previousState.Qty)
			order by
				o.oriPOGUID,
				o.oriDATE DESC,
				o.oriNumber,
				CASE oit1.operation WHEN 3 THEN 0x0 ELSE o.oriBuGuid END,
				previousState.TypeGuid,
				o.oriTypeGuid

			DECLARE @Number INT,
					@GUID uniqueidentifier,
					@OrderGUID uniqueidentifier,
					@PostDate DATETIME,
					@FromStateGUID uniqueidentifier,
					@ToStateGUID uniqueidentifier,
					@BuGUID uniqueidentifier
					
					DECLARE i CURSOR FOR SELECT Number1, GUID1, OrderGuid, PostDate, FromStateGuid, ToStateGuid, BuGuid FROM #Result   
					OPEN i  
						FETCH NEXT FROM i INTO @Number, @GUID, @OrderGUID, @PostDate, @FromStateGUID, @ToStateGUID, @BuGUID 
						DECLARE @OldOrderGuid uniqueidentifier = 0x0,
								@OldPostDate DATETIME,
								@OldFromStateGUID uniqueidentifier = 0x0,
								@OldToStateGUID uniqueidentifier = 0x0,
								@OldBuGUID uniqueidentifier = 0x0,
								@PostGUID uniqueidentifier = 0x0,
								@PostNumber INT = 0
			
						WHILE @@FETCH_STATUS = 0  
						BEGIN  
						IF (@OldOrderGuid <> @OrderGUID OR @OldPostDate <> @PostDate OR @OldFromStateGUID <> @FromStateGUID
						 OR @OldToStateGUID <> @ToStateGUID OR @OldBuGUID <> @BuGUID)
							Begin
							IF(@OldOrderGuid <> @OrderGUID)
								SET @PostNumber = 0
								
							IF(((@OldBuGUID <> @BuGUID) AND (@OldBuGUID <> 0x0 OR @BuGUID <> 0x0)) 
							   OR (@OldPostDate <> @PostDate) OR (@OldBuGUID = 0x0 AND @BuGUID = 0x0 AND (@OldFromStateGUID <> @FromStateGUID OR @OldToStateGUID <> @ToStateGUID)))
							BEGIN
								SET @PostNumber += 1
								SET @PostGUID = NEWID()
								IF(@BuGUID <> 0x0)
								BEGIN
									UPDATE ori000 SET PostGuid = @PostGUID, PostNumber = @PostNumber 
									WHERE 
										POGUID = @OrderGuid AND Date = @PostDate AND BuGuid = @BuGUID
								END
								ELSE IF(@BuGUID = 0x0)
								BEGIN
									UPDATE ori000 SET PostGuid = @PostGUID, PostNumber = @PostNumber 
									WHERE 
										POGUID = @OrderGuid 
										AND (GUID IN (SELECT Guid1 FROM #Result 
											 WHERE 
											  OrderGuid = @OrderGuid AND PostDate = @PostDate
											   AND FromStateGuid = @FromStateGUID AND ToStateGuid = @ToStateGUID)
											   OR
											 GUID IN (SELECT Guid2 FROM #Result 
											 WHERE 
											  OrderGuid = @OrderGuid AND PostDate = @PostDate
											   AND FromStateGuid = @FromStateGUID AND ToStateGuid = @ToStateGUID
											   ))
							  END 
							END
						
							SET @OldOrderGuid = @OrderGUID
							SET @OldPostDate = @PostDate
							SET @OldFromStateGUID = @FromStateGUID
							SET @OldToStateGUID = @ToStateGUID
							SET @OldBuGUID = @BuGUID
							End 
							
							FETCH NEXT FROM i INTO  @Number, @GUID, @OrderGUID, @PostDate,  @FromStateGuid, @ToStateGuid, @BuGUID
						END  
					CLOSE i  
					DEALLOCATE i
					
					EXECUTE sp_refreshview ''vORP''

					SELECT orp.paymentGuid as Guid,orp2.PaymentGuid as guid2
					 INTO #GUIDs FROM vORP orp2 INNER JOIN #tempPaymentGuid  orp
					  ON orp.BillGuid=orp2.BillGuid AND orp2.DueDate=orp.DueDate 
					  AND orp2.OrderGuid=orp.OrderGuid
					  AND orp2.PaymentDate=orp.paymentDate AND orp.PaymentValue= orp2.PaymentValue AND orp.PaymentDate= orp2.PaymentDate

					  select * from #GUIDs
  					UPDATE b
						SET b.[DebtGUID] = orp.guid2
						FROM #GUIDs orp
						INNER JOIN bp000 b ON b.[DebtGUID] = orp.Guid

						UPDATE b
						SET b.[PayGUID] = orp.guid2
						FROM #GUIDs orp
						INNER JOIN bp000 b ON b.[PayGUID] = orp.Guid
					'

					insert Into op000 values (NEWID(),'AmnCfg_UPDATEORDERPAYMENTSANDPOST',0, 0, '' ,NULL, 0, 0x0, 0x0 )
			END

			IF (NOT EXISTS(SELECT * FROM op000 WHERE Name = 'AmnCfg_UPDATEORITABLE'))
			BEGIN
				EXEC prcExecuteSQL '
				
				SELECT * into	#tempPaymentGuid from vORP
				CREATE TABLE #Bills1(
					GUID UNIQUEIDENTIFIER,
					POIGUID UNIQUEIDENTIFIER,
					OrderGuid UNIQUEIDENTIFIER,
					BuGuid UNIQUEIDENTIFIER,
					Note NVARCHAR(255)
					);
				CREATE TABLE #Bills2(
							GUID UNIQUEIDENTIFIER,
							POIGUID UNIQUEIDENTIFIER,
							OrderGuid UNIQUEIDENTIFIER,
							BuGuid UNIQUEIDENTIFIER
							);
			  -----جدول أقلام الترحيل التي تحوي فواتير تحوي مواد مكررة------			
				INSERT INTo #Bills1 
				SELECT 
					ori.GUID, 
					POIGUID, 
					POGUID, 
					ori.BuGuid,
					bt.Abbrev + '':'' + CAST(bu.Number AS NVARCHAR(10)) + '':'' + CAST(bi.Number + 1 AS NVARCHAR(10))
				from 
					ori000 ori
					INNER JOIN bu000 bu ON bu.GUID = ori.POGUID
					INNER JOIN bt000 bt ON bt.GUID = bu.TypeGUID
					INNER JOIN bi000 bi ON bi.GUID = ori.POIGUID
					INNER JOIN bu000 bu2 ON bu2.GUID = ori.BuGuid
				WHERE
					ori.BuGuid <> 0x0 AND
					((SELECT COUNT(*) FROM vwExtended_bi bi WHERE bi.buGuid = bu2.Guid) > (SELECT COUNT(*) FROM (SELECT DISTINCT biMatPtr FROM vwExtended_bi bi WHERE bi.buGuid = Bu2.Guid) AS bi))
			  ---------جدول أقلام الترحيل التي تحوي فواتير لا تحوي مواد مكررة-------------------
				INSERT INTo #Bills2
				SELECT 
					ori.GUID, 
					POIGUID, 
					POGUID, 
					ori.BuGuid
				from 
					ori000 ori
					INNER JOIN bu000 bu ON bu.GUID = ori.BuGuid
				WHERE
					ori.BuGuid <> 0x0 AND
					((SELECT COUNT(*) FROM vwExtended_bi bi WHERE bi.buGuid = bu.GUID) <= (SELECT COUNT(*) FROM (SELECT DISTINCT biMatPtr FROM vwExtended_bi bi WHERE bi.buGuid = bu.GUID) AS bi))
			  ------------إعطاء قيمة للعمود الجديد في حال كان سطر الترحيل غير مرتبط بفاتورة----------------------
			  UPDATE ori000 SET BiGuid = 0x0 WHERE BuGuid = 0x0
			  ------------إعطاء قيمة للعمود الجديد في جدول الترحيل عندما تكون الفاتورة تحوي مواد مكررة------------ 
				 UPDATE ori000 SET BiGuid = bi.GUID
				 FROM 
				 bi000 bi2 
				 INNER JOIN ori000 ori ON bi2.GUID = ori.POIGUID
				 INNER JOIN #Bills1 bill ON bill.GUID = ori.GUID
				 INNER JOIN bu000 bu on bu.GUID = ori.BuGuid
				 INNER JOIN bi000 bi ON bi.ParentGUID = ori.BuGuid AND bi.Notes Like bill.Note COLLATE DATABASE_DEFAULT
				------------إعطاء قيمة للعمود الجديد في جدول الترحيل عندما تكون الفاتورة لا تحوي مواد مكررة------------ 
				 UPDATE ori000 SET BiGuid = bi.GUID
				 FROM 
				 bi000 bi2 
				 INNER JOIN ori000 ori ON bi2.GUID = ori.POIGUID
				 INNER JOIN #Bills2 bill ON bill.GUID = ori.GUID
				 INNER JOIN bu000 bu on bu.GUID = ori.BuGuid
				 INNER JOIN bi000 bi ON bi.ParentGUID = ori.BuGuid AND bi.MatGUID = bi2.MatGUID
				 
				 EXECUTE sp_refreshview ''vORP''

					SELECT orp.paymentGuid as Guid,orp2.PaymentGuid as guid2
					 INTO #GUIDs FROM vORP orp2 INNER JOIN #tempPaymentGuid  orp
					  ON orp.BillGuid=orp2.BillGuid AND orp2.DueDate=orp.DueDate 
					  AND orp2.OrderGuid=orp.OrderGuid
					  AND orp2.PaymentDate=orp.paymentDate AND orp.PaymentValue= orp2.PaymentValue AND orp.PaymentDate= orp2.PaymentDate

					  select * from #GUIDs
  					UPDATE b
						SET b.[DebtGUID] = orp.guid2
						FROM #GUIDs orp
						INNER JOIN bp000 b ON b.[DebtGUID] = orp.Guid

						UPDATE b
						SET b.[PayGUID] = orp.guid2
						FROM #GUIDs orp
						INNER JOIN bp000 b ON b.[PayGUID] = orp.Guid
				 '
				
					insert Into op000 values (NEWID(),'AmnCfg_UPDATEORITABLE',0, 0, '' ,NULL, 0, 0x0, 0x0 )
			END
	END 

######################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10009003
AS
	SET NOCOUNT ON 
	EXECUTE PrcAddBitFld 'Distributor000', 'ShowNearbyCustomersOnly', 0
	EXECUTE [prcAddIntFld] 'Distributor000', 'NewCustomerDefaultPrice', 1
	EXECUTE [prcAddBitFld] 'Distributor000', 'CanUseExpenses', 1
	EXECUTE [prcAlterFld] 'Distributor000', 'CanUseExpenses', 'int'

	EXECUTE [prcAddIntFld] 'TrnUserConfig000', 'Security', 1

	EXEC prcAddBitFld			'bt000', 'TotalDiscRegardlessItemDisc'
	EXEC prcAddBitFld			'bt000', 'TotalExtraRegardlessItemExtra'
	IF [dbo].[fnObjectExists]('bt000.taxBeforeExtra') = 0
	BEGIN
		EXEC prcAddBitFld	'bt000', 'taxBeforeExtra';	
		EXEC ('UPDATE bt000 SET taxBeforeExtra = CASE WHEN BillType = 1 OR BillType = 3 OR BillType = 5 THEN 0 ELSE taxBeforeDiscount END')
	END

	EXECUTE [prcAddDateFld]		'TrnSenderReceiver000', 'DocumentExpiryDate'
	EXECUTE [prcAddDateFld]		'TrnVoucherPayInfo000', 'DocumentExpiryDate'


	--توزيع
	EXEC prcAddIntFld 'DistCm000','Unity','1'

	EXEC prcAddFloatFld 'bi000', 'TotalDiscountPercent'
	EXEC prcAddFloatFld 'bi000', 'TotalExtraPercent'

	-- التصنيع
	EXEC prcAddBitFld 'mx000', 'IsValue','0'
	EXEC prcAddBitFld 'mx000', 'IsRatio','0'
		
	EXEC ('UPDATE mx000  SET IsRatio = 1 WHERE Extra <> 0 and Discount <> 0')
	EXEC ('UPDATE mx000  SET IsValue = 1 WHERE Extra <> 0 and Discount = 0')
-----
	IF (NOT EXISTS (SELECT * FROM bt000 WHERE [Type] = 2 AND SortNum = 1 ))
	AND (dbo.fnOption_GetInt('PFC_IsBelongToProfitCenter', '0') = 1)
	BEGIN
		DECLARE @deffAccount UNIQUEIDENTIFIER = (SELECT [GUID] FROM ac000 WHERE Number = 4)
		DECLARE @deffCurrency UNIQUEIDENTIFIER = (SELECT [GUID] FROM my000 WHERE CurrencyVal = 1)

		INSERT INTO bt000 ([Type], [GUID], SortNum, BillType, Name, LatinName, Abbrev, LatinAbbrev
			,Color1, Color2, DefPrice, DefCostPrice, bIsInput, bAffectCostPrice, bAffectLastPrice, bNoEntry 
			,bAutoPost, bNoCostFld, bNoVendorFld, FldName, FldUnitPrice, FldTotalPrice, FldQty, DefBillAccGUID, DefBonusPrice, DefCurrencyGUID)
		VALUES (2, NEWID(), 1, 4, N'بضاعة أول المدة', N'First Period Inventory', N'ب. و. مدة', N'F.P.Inv.',  16316655, 12895356,
				1, -1, 1, 1, 1, 1, 1, 1, 1, 1, 3, 4, 2, @deffAccount, 0, @deffCurrency)
	END

	EXEC prcAddGUIDFld 'BPOptions000', 'ConfigurationID'
######################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10009006
AS	
	SET NOCOUNT ON 
	EXEC prcAddFloatFld 'Packages000', 'Weight2'
	EXEC prcAddIntFld 'Packages000', 'WeightUnit2'
	EXEC prcAddBitFld 'Packages000', 'FromPackage'
	EXEC prcAddFloatFld 'PackingListsBills000', 'BillVolume'
	EXEC prcAddFloatFld 'PackingListsBills000', 'BillWight'
	EXEC prcAddBitFld 'bu000', 'CalcBillVat'

	EXEC('
		UPDATE PA
		SET PatientGuid = F.[PatientGUID]
		FROM 
			hosPatientAccounts000 AS PA
			JOIN hosPFile000 AS F ON PA.PatientGuid = F.PatientGUID AND F.FileType = 0')

	IF NOT EXISTS (SELECT * FROM ui000 WHERE ReportId = 536925623)
	BEGIN
		INSERT INTO ui000
		SELECT NEWID(),u.GUID ,536925623 ,0x ,1 ,0 ,1 FROM us000 AS u WHERE bAdmin <> 1
		INSERT INTO ui000
		SELECT NEWID(),u.GUID ,536925624 ,0x ,1 ,0 ,1 FROM us000 AS u WHERE bAdmin <> 1
		INSERT INTO ui000
		SELECT NEWID(),u.GUID ,536925625 ,0x ,1 ,0 ,1 FROM us000 AS u WHERE bAdmin <> 1

		UPDATE us000 SET Dirty = 1 WHERE bAdmin <> 1
	END
######################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10009007
AS
	SET NOCOUNT ON 
	EXEC prcAddGuidFld	'TrnExchange000', 'CancelEntryGuid'
	EXEC prcAddGuidFld	'TrnExchange000', 'UserGuid'
	EXEC prcAddGuidFld	'TrnUserConfig000', 'CurrentAccountGuid'
	EXEC prcAddGuidFld	'TrnUserConfig000', 'RoundAccountGuid'
	EXEC prcAddBitFld	'TrnUserConfig000', 'HideFromSearch'
	EXEC prcDropFld		'TRNDeposit000', 'GroupCurrencyAccGUID'
	EXEC prcAddGuidFld	'TRNDeposit000', 'CurrencyGUID'
	EXEC prcAddGuidFld	'TRNDeposit000', 'CurrencyAccGUID'
	EXEC prcAddGuidFld	'TrnDeposit000', 'OwnerUserGuid'
	EXEC prcDropFld		'TrnDepositDetail000', 'currencyGuid' 
	EXEC prcDropFld		'TrnDepositDetail000', 'currencyAvg' 
	EXEC prcAddGuidFld  'TrnDepositDetail000', 'AccGuid' 
	EXEC prcAddCharFld  'TrnDepositDetail000', 'Notes', 500 
	EXEC prcAddBitFld	'TrnTransferVoucher000', 'CanBePayidAtDistBranchOnly'
	EXEC prcAddGuidFld	'TrnCenter000', 'ManagementCurrencyAccountGuid'
	EXEC prcAddGuidFld	'TrnCenter000', 'CurrencyAccountGuidCenter'
	EXEC prcAddGuidFld	'TrnCloseCashier000', 'UserGuid'
	EXEC prcAddGuidFld	'TrnCloseCashier000', 'CenterGuid'
	EXEC prcAddGuidFld	'TrnCloseCashier000', 'OwnerUserGuid'
	EXEC prcAddBitFld	'TrnCloseCashier000', 'IsCenter'
	EXEC prcAddCharFld	'TrnVoucherPayInfo000', 'ActualRecieverFatherName', 50
	EXEC prcAddCharFld	'TrnVoucherPayInfo000', 'ActualRecieverLastName', 50

	IF NOT EXISTS (SELECT * FROM TrDocType000)
	BEGIN
		INSERT INTO TrDocType000 SELECT NEWID(),IdentityType FROM TrnSenderReceiver000 WHERE IdentityType <> ''  GROUP BY IdentityType
		INSERT INTO TrDocType000 SELECT NEWID(),IdentityType FROM TrnCustomer000 WHERE IdentityType <> '' AND IdentityType NOT IN (SELECT Name FROM TrDocType000) GROUP BY IdentityType
	END
	
	IF EXISTS(SELECT * FROM TrnTransferVoucher000)
	BEGIN
		DECLARE @cnt INT = 0,
				@mask INT = 0
		SELECT @cnt = count(*) - 1 from br000
		while @cnt >= 0
		BEGIN
			SET @mask = @mask | POWER(2, @cnt)
			SET @cnt -= 1
		END
		UPDATE TrnTransferVoucher000 
		SET 
			branchMask = @mask
		WHERE 
			SourceType = 1
			AND DestinationType = 1
	END

	-- POS Enhas Project
	EXEC prcAddIntFld 'ds000', 'BackgroundColor', '16777215'
	EXEC prcAddBitFld 'RestOrderItem000', 'IsNew'
	EXEC prcAddFloatFld 'RestOrderItem000', 'QtyDiff'
	EXEC prcAddBitFld 'RestOrderItemTemp000', 'IsNew'
	EXEC prcAddFloatFld 'RestOrderItemTemp000', 'QtyDiff'
	EXEC prcAddBitFld 'RestDeletedOrderItems000', 'IsNew'
	EXEC prcAddFloatFld 'RestDeletedOrderItems000', 'QtyDiff'	
	EXEC prcAddDateFld 'RestOrderTemp000', 'LastAdditionDate'
	EXEC prcAddDateFld 'RestOrder000', 'LastAdditionDate'
	EXEC ('UPDATE RestOrderTemp000 SET LastAdditionDate = Opening')
	EXEC ('UPDATE RestOrder000 SET LastAdditionDate = Opening')
	
	EXEC prcAddIntFld 'POSInfos000', 'ColorsIndex', '0'
	EXEC prcAddBitFld 'bgi000', 'IsThemeColors'	
	EXEC prcAddBitFld 'bgi000', 'IsAutoCaption'	
	
	EXEC prcAddBitFld 'RestDiscTax000', 'IsOrderRound'
	EXEC prcAddBitFld 'RestDiscTaxTemp000', 'IsOrderRound'

	EXEC prcAddGUIDFld 'bg000', 'GroupGUID'	
	EXEC prcAddBitFld 'bg000', 'IsAutoRefresh'	
	EXEC prcAddBitFld 'bg000', 'IsAutoCaption'	

	EXEC prcAddGUIDFld 'RestOrder000', 'CustomerAddressID'	
	EXEC prcAddGUIDFld 'RestOrderTemp000', 'CustomerAddressID'	
	EXEC prcAddBitFld 'RestVendor000', 'IsAllAddress'	
	EXEC ('UPDATE RestVendor000 SET IsAllAddress = 1 WHERE Type = 0')
	
	EXEC('UPDATE df
	SET 
		[Type] = 540,
		BackColor = 12505678
	FROM 
		df000 df
		INNER JOIN ds000 ds ON ds.guid = df.ParentGUID
	WHERE 
		ds.Type = 6 
		AND 
		df.Type = 525')

	EXEC('UPDATE df
	SET 
		[Type] = 541,
		BackColor = 7656245
	FROM 
		df000 df
		INNER JOIN ds000 ds ON ds.guid = df.ParentGUID
	WHERE 
		ds.Type = 6 
		AND 
		df.Type = 526')
######################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10009008
AS 
	SET NOCOUNT ON 
	EXEC prcAddGuidFld	'TrnStatementTypes000', 'ExchangeCurrency2'
	EXEC [prcRenameFld] 'ChequeHistory000', 'EntryRelType ',  'EntryRelType'

	DECLARE @Command  NVARCHAR(1000)
	
	SELECT @Command = 'ALTER TABLE reportstate000 DROP CONSTRAINT ' + d.name
		FROM sys.tables t
			JOIN    sys.default_constraints d
				ON d.parent_object_id = t.object_id
			JOIN    sys.columns c
				ON c.object_id = t.object_id
				AND c.column_id = d.parent_column_id
			WHERE t.name = 'ReportState000'
				AND c.name = 'State'
	EXECUTE (@Command)
	
	ALTER TABLE ReportState000 
		ALTER COLUMN [State] NTEXT 
	ALTER TABLE ReportState000 
		ADD CONSTRAINT DF__ReportSta__State__019GBZ7E DEFAULT N'' FOR [State]
	
	DELETE FROM op000 WHERE Name = 'TrnCfg_OutTrnDefPrintType'
	DELETE FROM op000 WHERE Name = 'TrnCfg_InTrnDefPrintType'

	EXEC [prcAddCharFld] 'Allocations000', 'AccountName', 250
	EXEC [prcAddCharFld] 'Allocations000', 'CounterAccountName', 250
	EXEC prcDropFld 'Allocations000', 'AllocNumber'
	
######################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10009009
AS 
	SET NOCOUNT ON 
	EXEC prcAddGuidFld	'DistDeviceCu000', 'AccountGuid'

	INSERT INTO MatExBarcode000 (Guid, MatGuid, MatUnit, Barcode, IsDefault)
	SELECT Newid(), mt.Guid, 1 , mt.Barcode, 1 
	FROM   mt000 mt 
	WHERE mt.Barcode <>'' AND NOT EXISTS (select mtBarcode.Barcode from   MatExBarcode000 mtBarcode)

	INSERT INTO MatExBarcode000 (Guid, MatGuid, MatUnit, Barcode, IsDefault)
	SELECT Newid(), mt.Guid, 2 ,  CASE mx.Barcode WHEN NULL THEN mt.Barcode2 ELSE mt.Barcode2 + '2' END, 1
	FROM mt000 mt 
	LEFT JOIN MatExBarcode000 mx ON mx.Barcode = mt.Barcode2 AND mx.MatGuid = mt.GUID 
	WHERE mt.Barcode2 <>'' AND NOT EXISTS (select mx.Barcode from MatExBarcode000 mx WHERE (Barcode = mt.Barcode2 + '2' OR Barcode = mt.Barcode2) AND mx.MatGuid = mt.GUID)

	INSERT INTO MatExBarcode000(Guid, MatGuid, MatUnit, Barcode, IsDefault)
	SELECT Newid(), mt.Guid, 3 ,  CASE mx.Barcode WHEN NULL THEN mt.Barcode3 ELSE mt.Barcode3 + '3' END, 1
	FROM mt000 mt 
	LEFT JOIN MatExBarcode000 mx ON mx.Barcode = mt.Barcode3 AND mx.MatGuid = mt.GUID 
	WHERE mt.Barcode3 <>'' AND NOT EXISTS (SELECT mx.Barcode FROM MatExBarcode000 mx WHERE (Barcode = mt.Barcode3 + '3' OR Barcode = mt.Barcode3) AND mx.MatGuid = mt.GUID)
	
	
######################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10009011
AS 
	SET NOCOUNT ON 
	EXEC [prcAddCharFld]	'TrnSenderReceiver000', 'ActualName', 250
	EXEC [prcAddGuidFld] 'DistDeviceCu000', 'AccountGuid'
	EXEC [prcAddIntFld] 'DistDeviceCu000', 'PayTermsDays', 0
	EXEC [prcAddBitFld] 'DistDeviceCu000', 'HasBillsMustBePaid', 0
	EXEC [prcAddBitFld] 'DistDeviceBt000', 'UseSalesTax'
	EXEC [prcAddBitFld] 'DistDeviceBt000', 'CalcTaxBeforeDiscount'
	EXEC [prcAddBitFld] 'DistDeviceBt000', 'CalcTaxBeforeExtra'
	EXEC [prcAddBitFld] 'DistDeviceBt000', 'ApplyTaxOnGifts'
	EXEC [prcAddBitFld] 'DistDeviceBt000', 'IncludeTTCDiffOnSales'
	EXEC [prcAddIntFld] 'DistDeviceBt000', 'PayTermsDays', 0
	EXEC [prcAddBitFld] 'DistDeviceBt000', 'PayTerms', 0
	EXEC [prcAddCharFld] 'DistDeviceBt000', 'LatinName' , 250
	EXEC [prcAddCharFld] 'DistDeviceCu000', 'LatinName' , 250
	EXEC [prcAddFloatFld] 'DistDeviceBi000', 'VATRatio'
	EXEC [prcAddFloatFld] 'DistDeviceBi000', 'TotalDiscountPercent'
	EXEC [prcAddFloatFld] 'DistDeviceBi000', 'TotalExtraPercent'

	EXEC('

	UPDATE bt000 SET Abbrev = LEFT(Abbrev, 9) WHERE LEN(Abbrev) > 9
	UPDATE bt000 SET LatinAbbrev = LEFT(LatinAbbrev, 9) WHERE LEN(LatinAbbrev) > 9


	;WITH Duplications 
	AS
	(
		SELECT  Abbrev, COUNT(*) AS Cnt
		FROM bt000 bt 
		WHERE ((Abbrev != '''') AND (Abbrev IS NOT NULL))
		GROUP BY Abbrev, Type
		HAVING COUNT(*) > 1
	),
	LatinDuplications AS
	(
		SELECT  LatinAbbrev, COUNT(*) AS Cnt
		FROM bt000 bt 
		WHERE ((LatinAbbrev != '''') AND (LatinAbbrev IS NOT NULL))
		GROUP BY LatinAbbrev, Type
		HAVING COUNT(*) > 1
	)
	UPDATE bt000 
	SET Abbrev =  CASE WHEN Abbrev IN (SELECT Abbrev FROM Duplications) THEN  LEFT(CAST(ABS(CAST(CAST(NEWID() as BINARY(10)) as int)) as varchar(max)) + ''00000000'',9) ELSE Abbrev END
	,LatinAbbrev = CASE WHEN LatinAbbrev IN (SELECT LatinAbbrev FROM LatinDuplications) THEN  LEFT(CAST(ABS(CAST(CAST(NEWID() as BINARY(10)) as int)) as varchar(max)) + ''00000000'',9) ELSE LatinAbbrev END

	')
######################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10009014
AS 
	SET NOCOUNT ON 
	IF EXISTS (SELECT * FROM sys.objects WHERE [name] = N'trg_Mat000_insertMatBarcode' AND [type] = 'TR')
	BEGIN
		  DROP TRIGGER [dbo].[trg_Mat000_insertMatBarcode]
	END
	EXEC prcAddFloatFld 'DistDeviceBi000', 'TotalDiscountPercent'
	EXEC prcAddFloatFld 'DistDeviceBi000', 'TotalExtraPercent'
######################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10009015
AS 
	SET NOCOUNT ON 
	EXEC prcAddBitFld 'Bi000', 'IsDiscountValue'
	EXEC prcAddBitFld 'Bi000', 'IsExtraValue'
	EXEC prcAddGuidFld 'AssetPossessionsForm000', 'ParentGuid'
	EXEC prcAddIntFld 'AssetPossessionsForm000', 'Number2'
	EXEC prcAddBitFld 'AssetStartDatePossessions000' , 'IsTransfered' , 0
	-- To Update Asset Possessions Number
	EXEC('UPDATE AssetPossessionsForm000
	SET Number2 = Number
		WHERE Number2 = 0');
######################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10009016
AS 
	SET NOCOUNT ON 
	--Reformatting Date Options According to Al-Ameen's DB Date Format
	EXEC prcDisableTriggers 'op000'

	UPDATE OP000 
	SET Value = CONVERT (date, Value, 105)
	WHERE Name IN ('AmnCfg_FPDate', 'AmnCfg_StopDate', 'AmnCfg_BillStopDate', 'AmnCfg_EPDate', 'DistCfg_Coverage_RouteDate')
	AND (CHARINDEX('-', Value) < 5)  --TRY_CONVERT(date, Value, 102) IS NULL

	ALTER TABLE op000 ENABLE TRIGGER ALL

	UPDATE bt000
	SET bAffectLastPrice = 1
	WHERE BillType = 4 AND SortNum = 0

	UPDATE op000 SET UserGUID = OwnerGUID, Type = 1 WHERE name like'AmnCfg_HTML_CustomProfile_%_RID'

######################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10009020
AS 
	SET NOCOUNT ON 

	DECLARE @ConstraintName NVARCHAR(250)
	SELECT  @ConstraintName = dc.name FROM sys.default_constraints dc WHERE  dc.name LIKE '%DF__lg000__Notes%'	
	EXEC('ALTER TABLE lg000 DROP CONSTRAINT ' + @ConstraintName)

	ALTER TABLE lg000 ALTER COLUMN Notes NVARCHAR(300)
    ALTER TABLE lg000 ADD DEFAULT ('') FOR Notes

######################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10009021
AS 

	EXEC('INSERT INTO MatExBarcode000 (Guid, MatGuid, MatUnit, Barcode, IsDefault)
	 SELECT Newid(), mt.Guid, 1 , mt.Barcode, 1 
		 FROM   mt000 mt 
	WHERE mt.Barcode <>'''' AND NOT EXISTS (select mtBarcode.Barcode 
											from  MatExBarcode000 mtBarcode 
											where mtBarcode.MatGuid = mt.GUID
											and   mtBarcode.MatUnit = 1)');

	EXEC('INSERT INTO MatExBarcode000 (Guid, MatGuid, MatUnit, Barcode, IsDefault)
	SELECT Newid(), mt.Guid, 2 ,  mt.Barcode2, 1
		FROM mt000 mt 
	WHERE mt.Barcode2 <>'''' AND NOT EXISTS (select mtBarcode.Barcode 
											from  MatExBarcode000 mtBarcode 
											where mtBarcode.MatGuid = mt.GUID
											and   mtBarcode.MatUnit = 2)');

	EXEC('INSERT INTO MatExBarcode000 (Guid, MatGuid, MatUnit, Barcode, IsDefault)
	SELECT Newid(),  mt.Guid, 3 ,  mt.Barcode3, 1 
		 FROM mt000 mt 
    WHERE mt.Barcode3 <>'''' AND NOT EXISTS (select mtBarcode.Barcode 
											from  MatExBarcode000 mtBarcode 
											where mtBarcode.MatGuid = mt.GUID
											and   mtBarcode.MatUnit = 3)');
	
	-- For Delete Duplicated Barcode In The Same Unit
	EXEC(';WITH DupBar AS
	(SELECT 
	Barcode, MatGuid, MatUnit 
		FROM MatExBarcode000
			GROUP BY
				Barcode,
				MatGuid,
				MatUnit
			HAVING COUNT(*) > 1
			)
	DELETE Bar
		FROM MatExBarcode000 AS Bar
		INNER JOIN DupBar ON Bar.MatGuid = DupBar.MatGuid AND Bar.MatUnit = DupBar.MatUnit AND Bar.Barcode = DupBar.Barcode
			WHERE Bar.GUID NOT IN (SELECT TOP 1 GUID FROM MatExBarcode000 AS br
			INNER JOIN DupBar ON br.MatGuid = DupBar.MatGuid AND br.MatUnit = DupBar.MatUnit AND br.Barcode = DupBar.Barcode)

	-- For Update Duplicated Barcode In The Same Mat
	;WITH DupBar AS
	(SELECT
		Barcode, MatGuid, COUNT(*) AS Cnt
		FROM
			MatExBarcode000
		GROUP BY
			Barcode, MatGuid
		HAVING
			COUNT(*) > 1)
		UPDATE Bar 
			SET Bar.Barcode = Bar.Barcode + CAST(Bar.MatUnit AS NVARCHAR(200))
			FROM MatExBarcode000 AS Bar
			INNER JOIN DupBar ON DupBar.MatGuid = Bar.MatGuid
				WHERE Bar.MatUnit != 1

	-- For Update Duplicated Barcode with the same barcode only
	IF EXISTS(select m1.*,m2.* from MatExBarcode000 m1 join MatExBarcode000 m2 ON m1.Barcode = m2.Barcode AND m1.GUID <> m2.GUID)
	BEGIN
		UPDATE B
		SET B.Barcode = B.Barcode + R.RN
		FROM 
			MatExBarcode000 AS B
			JOIN MatExBarcode000 AS B2 ON B.Barcode = B2.Barcode AND B.Guid <> B2.Guid
			CROSS APPLY (SELECT CAST((ABS(CHECKSUM(NEWID())) % 14) AS NVARCHAR(50)) +CAST((ABS(CHECKSUM(B.MatGUID)) % 17) AS NVARCHAR(50)) AS RN) AS R
	END
	IF EXISTS(select m1.*,m2.* from MatExBarcode000 m1 join MatExBarcode000 m2 ON m1.Barcode = m2.Barcode AND m1.GUID <> m2.GUID)
	BEGIN
		UPDATE B
		SET B.Barcode = B.Barcode + R.RN
		FROM 
			MatExBarcode000 AS B
			JOIN MatExBarcode000 AS B2 ON B.Barcode = B2.Barcode AND B.Guid <> B2.Guid
			CROSS APPLY (SELECT CAST((ABS(CHECKSUM(B.Guid)) % 20) AS NVARCHAR(50)) +CAST((ABS(CHECKSUM(B.MatGUID)) % 20) AS NVARCHAR(50)) AS RN) AS R
	END');
	
	 EXEC('IF  EXISTS ( SELECT * FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS where CONSTRAINT_TYPE=''UNIQUE''
						AND CONSTRAINT_NAME =''barcode_uniqueConstraint'') 
	 BEGIN 
		ALTER TABLE MatExBarcode000 DROP CONSTRAINT barcode_uniqueConstraint
	 END
	 IF((SELECT Value from op000 where name =''AmnCfg_MatUniqueBarcode'') = ''1'')
		ALTER TABLE MatExBarcode000 ADD CONSTRAINT barcode_uniqueConstraint UNIQUE NONCLUSTERED (Barcode)
	 ELSE
		ALTER TABLE MatExBarcode000 ADD CONSTRAINT barcode_uniqueConstraint UNIQUE NONCLUSTERED (Barcode, MatGuid)');

######################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10009022
AS 
	EXEC prcAddIntFld  'bg000', 'WeekDays', '127'
	EXEC prcAddCharFld 'bg000', 'FromTime', 10, '00:00' 
	EXEC prcAddCharFld 'bg000', 'ToTime', 10, '23:59'

######################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10009025
AS 
-- MODIFY REPLICATION TRIGGERS START
SELECT Triggers.id AS TriggerId,
	   Tables.Name TableName,
       Triggers.name TriggerName,
       Comments.Text TriggerText
INTO #Triggers
FROM      sysobjects Triggers
      Inner Join sysobjects Tables On Triggers.parent_obj = Tables.id
      Inner Join syscomments Comments On Triggers.id = Comments.id
WHERE      Triggers.xtype = 'TR'
      And Triggers.name LIKE '%_replicBinder%' -- AND Tables.xtype = 'U'
ORDER BY Tables.Name, Triggers.name

DECLARE @TriggerText NVARCHAR(MAX),@TriggerId INT
WHILE EXISTS(SELECT 1 FROM #Triggers)
BEGIN
SET @TriggerId = (SELECT TOP 1 TriggerId FROM #Triggers)
SET @TriggerText = (SELECT TOP 1 TriggerText FROM #Triggers)
	
	SET @TriggerText = REPLACE(@TriggerText,'for insert, delete, update
as
if @@rowcount = 0','for insert, delete, update
NOT FOR REPLICATION
as
if @@rowcount = 0'); 

SET @TriggerText = REPLACE(@TriggerText,'CREATE','ALTER')

EXEC(@TriggerText);
DELETE FROM #Triggers WHERE TriggerId = @TriggerId
END

DROP TABLE #Triggers
-- MODIFY REPLICATION TRIGGERS END
######################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10009026
AS
	--EXECUTE prcAddGUIDFld 'oap000', 'Guid'
	exec [prcAddFld] 'oap000',  'Guid', '[UNIQUEIDENTIFIER]  ROWGUIDCOL '
	exec [prcAddFld] 'posPaymentLink000',  'guid', '[UNIQUEIDENTIFIER] ROWGUIDCOL  '
	--EXECUTE prcAddGUIDFld 'posPaymentLink000', 'guid'

	exec ('update oap000 set guid=newID()')
	exec ('update PosPaymentLink000 set guid=newID()')

	EXEC [prcAddFld] 'BillNumberOrder000',  'NumberOrderGuid', '[UNIQUEIDENTIFIER]'
	EXEC ('UPDATE BillNumberOrder000 SET NumberOrderGuid = NEWID()')

	EXECUTE prcAddFld 'DistDeviceST000',  'LatinName' , '[VARCHAR](250) COLLATE ARABIC_CI_AI DEFAULT ('''') '
	EXECUTE prcAddFld 'DistDeviceNewCu000',  'LatinName' , '[VARCHAR](250) COLLATE ARABIC_CI_AI DEFAULT ('''') '
######################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10009027
AS
	--JOC
	EXEC prcDropFld 'Plcosts000','Period'
	EXEC prcAddDateFld 'Plcosts000','StartPeriodDate'
	EXEC prcAddDateFld 'Plcosts000','EndPeriodDate'
	EXEC prcAddCharFld 'JOCStages000','Code',250
	EXEC prcAddIntFld 'Manufactory000','JointCostMethod','0'
	EXEC prcAddIntFld 'Manufactory000','PriceType','0'
	EXEC prcAddGUIDFld 'JobOrder000', 'OperatingBOMGuid'
	EXEC prcAddGUIDFld 'JobOrder000', 'SpoilageEntryGuid'
	EXEC prcAddFloatFld 'JobOrder000', 'EstimatedCost', 0
	EXEC prcAddFloatFld 'JobOrder000', 'ActualCost', 0
	EXEC prcAddBitFld 'JobOrder000', 'UseSpoilage', 0

	EXEC [prcAddFld] 'oap000',  'Guid', '[UNIQUEIDENTIFIER]  ROWGUIDCOL '
	EXEC [prcAddFld] 'posPaymentLink000',  'guid', '[UNIQUEIDENTIFIER] ROWGUIDCOL  '

	EXEC('update oap000 set guid=newID()')
	EXEC('update PosPaymentLink000 set guid=newID()')

	EXEC[prcAddFld] 'BillNumberOrder000',  'NumberOrderGuid', '[UNIQUEIDENTIFIER]'
	EXEC('UPDATE BillNumberOrder000 SET NumberOrderGuid = NEWID()')

	EXECUTE prcAddFld 'DistDeviceST000',  'LatinName' , '[VARCHAR](250) COLLATE ARABIC_CI_AI DEFAULT ('''') '
	EXECUTE prcAddFld 'DistDeviceNewCu000',  'LatinName' , '[VARCHAR](250) COLLATE ARABIC_CI_AI DEFAULT ('''') '
	

    --For Fix MatExBarcode Index
	CREATE  TABLE tempDT(
		[Guid] [uniqueidentifier] ROWGUIDCOL  NOT NULL DEFAULT (newid()),
		[Number] [int] NOT NULL,
		[MatGuid] [uniqueidentifier] NULL DEFAULT (0x00),
		[MatUnit] [int] NULL DEFAULT ((0)),
		[Barcode] [nvarchar](250) NULL DEFAULT (''),
		[IsDefault] [int] NULL DEFAULT ((0)) )

	IF (COL_LENGTH('MatExBarcode000','Number') IS NULL)
	 BEGIN
		DECLARE @index int = -1
		DECLARE @rawMatUnit int, @tempUnit int, @rawIsDefault int 
		DECLARE @rawGuid uniqueidentifier, @rawMatGuid uniqueidentifier, @materialGuid uniqueidentifier;
		DECLARE @rawBarcode NVARCHAR(250)

		DECLARE db_cursor CURSOR FOR  
			SELECT * FROM MatExBarcode000 order by MatGuid, MatUnit, IsDefault DESC
	
		OPEN db_cursor   
			FETCH NEXT FROM db_cursor INTO @rawGuid, @rawMatGuid, @rawMatUnit, @rawBarcode,  @rawIsDefault
			SET @tempUnit = @rawMatUnit
			SET @materialGuid = @rawMatGuid

		WHILE @@FETCH_STATUS = 0   
		BEGIN   
			IF (@tempUnit = @rawMatUnit AND @materialGuid = @rawMatGuid)
			BEGIN
				SET @index = @index + 1
				INSERT INTO tempDT 
				 SELECT @rawGuid, @index, @rawMatGuid, @rawMatUnit, @rawBarcode, @rawIsDefault 
			END
			ELSE
			BEGIN
				SET @tempUnit = @rawMatUnit
				SET @materialGuid = @rawMatGuid
				SET @index =  0
				INSERT INTO tempDT 
				 SELECT @rawGuid, @index, @rawMatGuid, @rawMatUnit, @rawBarcode, @rawIsDefault 
			END
    
		  FETCH NEXT FROM db_cursor INTO @rawGuid, @rawMatGuid, @rawMatUnit, @rawBarcode,  @rawIsDefault
		END   

	 CLOSE db_cursor   
	 DEALLOCATE db_cursor
   END
  ELSE
	BEGIN
		DECLARE @sql NVARCHAR(250) 
		SET @sql = 'INSERT INTO tempDT   
					SELECT Guid, Number, MatGuid, MatUnit, Barcode, IsDefault FROM MatExBarcode000'
		EXECUTE sp_executesql @sql
	END
	
	DELETE [MatExBarcode000]
	drop table MatExBarcode000

	CREATE TABLE MatExBarcode000(
	[Guid] [uniqueidentifier] ROWGUIDCOL  NOT NULL DEFAULT (newid()),
	[Number] [int] NULL DEFAULT ((0)),
	[MatGuid] [uniqueidentifier] NULL DEFAULT (0x00),
	[MatUnit] [int] NULL DEFAULT ((0)),
	[Barcode] [nvarchar](250) NULL DEFAULT (''),
	[IsDefault] [int] NULL DEFAULT ((0)),
	
	PRIMARY KEY CLUSTERED([Guid] ASC)
	WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]) ON [PRIMARY]
	
	IF((SELECT Value from op000 where name ='AmnCfg_MatUniqueBarcode') = '1')
		ALTER TABLE MatExBarcode000 ADD CONSTRAINT barcode_uniqueConstraint UNIQUE NONCLUSTERED (Barcode)
	ELSE
		ALTER TABLE MatExBarcode000 ADD CONSTRAINT barcode_uniqueConstraint UNIQUE NONCLUSTERED (Barcode, MatGuid)

		SET @sql = 'INSERT INTO MatExBarcode000   
					SELECT Guid, Number, MatGuid, MatUnit, Barcode, IsDefault FROM tempDT'
		EXECUTE sp_executesql @sql

	DROP TABLE tempDT

	EXECUTE [prcAlterFld] 'DistDeviceStatement000', 'ItemNumber', 'NVARCHAR(1000)', 0, ''''''



######################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10009029
AS
	EXEC prcAddBitFld	'TrnStatementTypes000', 'bAutoGenOutStatement'
	EXEC prcAddGuidFld	'TrnStatementTypes000', 'RecieverOfficeGuid'
	EXEC prcAddFloatFld	'TrnStatementTypes000', 'RecieverOfficeWagesRatio'
	EXEC prcAddGuidFld	'TrnStatementTypes000', 'OutStatementType'
	EXEC prcAddGuidFld	'TrnStatementTypes000', 'TransferCurrencyGuid'

	EXEC prcAddGuidFld  'TrnStatement000', 'RecieverOffice'
	EXEC prcAddGuidFld  'TrnStatement000', 'OutStatementType'
	EXEC prcAddIntFld   'TrnStatement000', 'OutStatementNumber'
	EXEC prcAddGuidFld  'TrnStatement000', 'TransferCurrencyGuid'
	EXEC prcAddFloatFld 'TrnStatement000', 'TransferCurrencyVal'
	
	EXEC prcAddFloatFld 'TrnStatementItems000', 'TransferAmount'
	EXEC prcAddGuidFld 'TrnStatementItems000', 'TransferCurrencyGuid'
	EXEC prcAddFloatFld 'TrnStatementItems000', 'TransferCurrencyVal'
	EXEC prcAddFloatFld 'TrnStatementItems000', 'TransferWages'
	EXEC prcAddGuidFld 'TrnTransferVoucher000', 'CheckTypeGuid'

	Declare @UpdateSQl VARCHAR(500) 
	SET @UpdateSQl = 
	' DECLARE @DefCurGuid UNIQUEIDENTIFIER ' +
	' SELECT @DefCurGuid =  Guid FROM my000 WHERE Currencyval = 1 ' +

	' UPDATE TrnStatement000 ' +
	' SET ' +
		' TransferCurrencyGuid = @DefCurGuid,' +
		' TransferCurrencyVal = 1 ' +
	' WHERE ' +
		' TransferCurrencyGuid = 0x0 ' +

	' UPDATE TrnStatementItems000 ' +
	' SET  ' +
		' TransferCurrencyGuid = @DefCurGuid, ' +
		' TransferCurrencyVal = 1 ' +
	' WHERE ' +
		' TransferCurrencyGuid = 0x0 ' 
	EXEC(@UpdateSQl)

	EXEC prcDisableTriggers 'ORADDINFO000', 1

	UPDATE ORADDINFO000
	SET 
		Add1 = '0'
	WHERE
		Add1 IS NULL

	 UPDATE ORADDINFO000
	SET 
		Finished = 0
	WHERE
		Finished IS NULL

	EXEC prcEnableTriggers 'ORADDINFO000'
	
######################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10009034
AS		
	IF EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name = 'prcRpl_packages_unBindAll')
	AND EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name = 'prcRpl_ExecuteSQL')
	BEGIN
			IF OBJECT_ID('amnconfig.dbo.msglog') IS NULL
			BEGIN
				EXEC('CREATE TABLE [amnconfig].dbo.[msglog]([dbname] NVARCHAR(MAX), [caller] NVARCHAR(MAX), [nestlevel] INT, [message]NVARCHAR(MAX), [details]NVARCHAR(MAX), [status] NCHAR(3), [exitcode] INT)');
			END
			EXEC('EXEC prcRpl_packages_unBindAll')

			declare
			@c cursor,
			@schema sysname,
			@owner sysname


			-- drop replication procedures:
			set @c = cursor fast_forward for select name from sysobjects where (name like 'prcRpl_%' or name like '%_copyToDB' or name like '%_echo' ) and ( name <> 'prcRpl_ExecuteSQL' and name <> 'prcRplLog' )

			open @c fetch from @c into  @schema

			while @@fetch_status = 0
			begin
			EXEC ('DROP PROCEDURE '+ @schema)
			fetch from @c into @schema
			end

			close @c

			-- drop functions:
			set @c = cursor fast_forward for select name from sysobjects where name like 'fnRpl_%'

			open @c fetch from @c into  @schema

			while @@fetch_status = 0
			begin
			EXEC ( 'DROP FUNCTION '+ @schema)	

			fetch from @c into @schema
			end


			-- drop views:
			set @c = cursor fast_forward for select name from sysobjects where name like 'vwRpl_%'

			open @c fetch from @c into  @schema

			while @@fetch_status = 0
			begin
				exec ( 'drop view ' + @schema)
				fetch from @c into @schema
			end


			-- drop forienKeys:
			set @c = cursor fast_forward for select name, object_name(parent_obj) from sysobjects where name like 'fk_rpl_%'

			open @c fetch from @c into  @schema, @owner

			while @@fetch_status = 0
			begin
			EXEC('exec prcRpl_ExecuteSQL ''alter table [dbo].[%0] drop constraint [%1]'', ' + @owner + ', ' + @schema + ',@bInsertIntoMsgLog=0')
			fetch from @c into @schema, @owner
			end

			close @c


			-- drop tables, trigger will be included:
			set @c = cursor fast_forward for select name from sysobjects where name like 'rpl_%'

			open @c fetch from @c into  @schema

			while @@fetch_status = 0
			begin
			EXEC  ('DROP TABLE '+ @schema)	
			fetch from @c into @schema
			end

			close @c deallocate @c


			-- drop triggers:
			set @c = cursor fast_forward for select name from sysobjects where name like 'trg_rpl_%'

			open @c fetch from @c into  @schema

			while @@fetch_status = 0
			begin
			EXEC  ('DROP TRIGGER ' + @schema)
			fetch from @c into @schema
			end

			close @c deallocate @c

			-- remove extended properties:
			if exists(select * from sysobjects where id = object_id('sysproperties'))
			begin
			if exists(select * from sysproperties where name = 'rpl_role')
			exec sp_dropextendedproperty 'rpl_role'
			End
			Else
			Begin
			if exists(select * from sys.extended_properties where name = 'rpl_role')
			exec sp_dropextendedproperty 'rpl_role'
			End
	END
######################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10009035
AS
	
	IF [dbo].[fnObjectExists]('mt000.FirstCostDate') =  0
	BEGIN
	
		IF NOT EXISTS(SELECT * FROM mc000 WHERE Number = 1024 AND Asc1 = 'ReCalcBillCP' AND Num1 = 1)
		BEGIN
			INSERT INTO mc000(Number, Asc1, Num1) VALUES (1024, 'ReCalcBillCP', 1)
		END
	END 

	EXEC prcAddDateFld 'mt000', 'FirstCostDate'

	EXEC('
		  ;WITH CTE (MaterialId, CostId, FirstCostDate)
		  AS
		  (
		  	SELECT  bi.biMatPtr, 
		  	i.[Guid], 
		  	( SELECT ISNULL(MIN(rm.Date), ''1980-1-1'') FROM vwBuBi innerbi 
			  JOIN RecostMaterials000 rm ON innerbi.buGUID = rm.OutBillGuid
			  WHERE innerbi.biMatPtr = bi.biMatPtr
			)
		  	FROM vwBuBi bi
		  	RIGHT JOIN RecostMaterials000 i ON bi.buGUID = i.OutBillGuid
		  )
		  UPDATE mt 
		  SET mt.FirstCostDate = CTE.FirstCostDate
		  FROM mt000 mt
		  JOIN CTE ON mt.[GUID] = CTE.MaterialId	
	')
######################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10009043
AS
BEGIN
	EXEC [prcAddFloatFld] 'bu000', 'TotalSalesTax'
	EXEC PrcDropFld	'TrnStatementTypes000', 'ExchangeCurrency2'

	EXEC('

		UPDATE bu000 SET TotalSalesTax = tax.TotalSalesTax
		FROM(
		 SELECT	bu.[GUID ]BillGuid,	SUM(
			CASE  TAX.ValueType
				WHEN 0 THEN [VALUE]
			Else  
				CASE TAX.[TaxType]
					WHEN 1 THEN -1 *
						CASE bt.taxBeforeDiscount
							WHEN 0 THEN 
								(bu.Total - bu.TotalDisc + bu.TotalExtra)* TAX.[VALUE] / 100
							ELSE
								(bu.Total * TAX.[VALUE]) / 100
							END
					ELSE
						CASE bt.taxBeforeDiscount
							WHEN 0 THEN 
								(bu.Total - bu.TotalDisc + bu.TotalExtra)* TAX.[VALUE] / 100
							ELSE
							(bu.Total * TAX.[VALUE]) / 100
							END
					END
				END) TotalSalesTax
		FROM  salestax000 Tax
		INNER JOIN bt000 bt ON bt.[GUID] = Tax.BillTypeGuid
		INNER JOIN bu000 bu ON bu.TypeGUID = bt.[GUID]
		GROUP BY bu.[GUID]) Tax
		WHERE [GUID] = Tax.BillGuid AND bu000.TotalSalesTax = 0
	')
END
######################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10009063
AS
	-- GCC System
	EXEC [prcAddIntFld] 'et000', 'TaxType'

	IF [dbo].[fnObjectExists]('et000.IsUsingAddedValue') <> 0
	BEGIN
		EXEC ('UPDATE et000 SET TaxType = CASE IsUsingAddedValue WHEN 1 THEN 2 ELSE 0 END')
		EXEC [prcDropFld] 'et000', 'IsUsingAddedValue'
	END

	EXEC [prcAddGUIDFld] 'et000', 'TaxAccountGUID'
	EXEC [prcAddIntFld]  'et000', 'FldTaxValue'

	EXEC [prcAddGUIDFld] 'bt000', 'CustAccGuid'
	EXEC [prcAddBitFld] 'bt000', 'UseExciseTax'
	EXEC [prcAddGUIDFld] 'bt000', 'ExciseAccGUID'
	EXEC [prcAddGUIDFld] 'bt000', 'ExciseContraAccGUID'
	EXEC [prcAddBitFld] 'bt000', 'UseReverseCharges'
	EXEC [prcAddGUIDFld] 'bt000', 'ReverseChargesAccGUID'
	EXEC [prcAddGUIDFld] 'bt000', 'ReverseChargesContraAccGUID'
	EXEC [prcAddIntFld] 'bt000', 'FldPurchaseValue'
	EXEC [prcAddIntFld] 'bt000', 'FldReverseChargeTax'
	EXEC [prcAddIntFld] 'bt000', 'FldExciseTaxVal'
	EXEC [prcAddGUIDFld] 'bt000', 'DefaultLocationGUID'
	
	EXEC [prcAddIntFld]  'et000', 'FldTaxValue'
	EXEC [prcAddIntFld]  'et000', 'FldLC'

	EXEC [prcAddIntFld] 'bi000', 'TaxCode'
	EXEC [prcAddFloatFld] 'bi000', 'ExciseTaxVal'
	EXEC [prcAddFloatFld] 'bi000', 'PurchaseVal'
	EXEC [prcAddFloatFld] 'bi000', 'ReversChargeVal'
	EXEC [prcAddFloatFld] 'bi000', 'ExciseTaxPercent'
	EXEC [prcAddFloatFld] 'bi000', 'ExciseTaxCode'
	EXEC [prcAddFloatFld] 'bi000', 'LCDisc'
	EXEC [prcAddFloatFld] 'bi000', 'LCExtra'
		 
	EXEC [prcAddFloatFld] 'bu000', 'TotalExciseTax'
	EXEC [prcAddGUIDFld] 'bu000', 'RefundedBillGUID'
	EXEC [prcAddBitFld] 'bu000', 'IsTaxPayedByAgent'
	EXEC [prcAddGUIDFld] 'bu000', 'LCGUID'
	EXEC [prcAddIntFld] 'bu000', 'LCType'
	EXEC [prcAddGUIDFld] 'bu000', 'ReversChargeReturn'
	EXEC [prcAddCharFld] 'bu000', 'ReturendBillNumber', 500
	EXEC [prcAddDateFld] 'bu000', 'ReturendBillDate'
		 
	EXEC [prcAddIntFld] 'en000', 'Type'
	EXEC [prcAddGUIDFld] 'en000', 'LCGUID'
		 
	EXEC [prcAddGUIDFld] 'cu000', 'GCCLocationGUID'
	EXEC [prcAddCharFld] 'cu000', 'GCCCountry', 250
	EXEC [prcAddBitFld]  'cu000', 'ReverseCharges'
		 
	EXEC [prcAddCharFld] 'LC000', 'Notes', 250
	EXEC [prcAddDateFld] 'LC000', 'ExpCloseDate'
		 
	EXEC [prcAddFloatFld] 'RestOrderItemTemp000', 'Vat'
	EXEC [prcAddFloatFld] 'RestOrderItem000', 'Vat'
	EXEC [prcAddFloatFld] 'RestDeletedOrderItems000', 'Vat'
	EXEC [prcAddFloatFld] 'RestOrderItemTemp000', 'VatRatio'
	EXEC [prcAddFloatFld] 'RestOrderItem000', 'VatRatio'
	EXEC [prcAddFloatFld] 'RestDeletedOrderItems000', 'VatRatio'
	EXEC [prcAddCharFld] 'POSOrder000', 'ReturendBillNumber', 500
	EXEC [prcAddCharFld] 'POSOrderTemp000', 'ReturendBillNumber', 500
	EXEC [prcAddDateFld] 'POSOrder000', 'ReturendBillDate'
	EXEC [prcAddDateFld] 'POSOrderTemp000', 'ReturendBillDate'

	IF NOT EXISTS (SELECT * FROM UsPasHistory000)
		INSERT INTO UsPasHistory000
		SELECT NEWID(), ROW_NUMBER() OVER (ORDER BY Number), GUID, GETDATE(), LoginName, Password FROM us000
	
######################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10009065
AS
	EXEC [prcAddDateFld] 'GCCTaxSettings000', 'SubscriptionDate'
		 
	EXEC [prcAddIntFld] 'DistDeviceCu000', 'TaxCode'
	EXEC [prcAddCharFld] 'DistDeviceEt000', 'LatinName' , 250
		 
	EXEC [prcAddCharFld] 'DistDeviceNewCU000', 'Address' , 250
	EXEC [prcAddCharFld] 'DistDeviceNewCU000', 'Pager' , 250
	EXEC [prcAddCharFld] 'DistDeviceNewCU000', 'Phone2' , 250
	EXEC [prcAddCharFld] 'DistDeviceNewCU000', 'ZipCode' , 250
		 			  
	EXEC [prcAddCharFld] 'DistDeviceCU000', 'Address' , 250
	EXEC [prcAddCharFld] 'DistDeviceCU000', 'Pager' , 250
	EXEC [prcAddCharFld] 'DistDeviceCU000', 'Phone2' , 250
	EXEC [prcAddCharFld] 'DistDeviceCU000', 'ZipCode' , 250
		 			   
	EXEC [prcAddCharFld] 'DistCustUpdates000', 'Address' , 250
	EXEC [prcAddCharFld] 'DistCustUpdates000', 'pager' , 250
	EXEC [prcAddCharFld] 'DistCustUpdates000', 'Phone2' , 250
	EXEC [prcAddCharFld] 'DistCustUpdates000', 'ZipCode' , 250
		 
	EXECUTE [prcAddGuidFld] 'Distributor000', 'UserGuid'
	EXEC [prcAddIntFld] 'Distributor000', 'LastSalesNumber'	
	EXEC [prcAddIntFld] 'Distributor000', 'LastReturnNumber'

	EXEC [prcAddBitFld] 'bt000', 'IsPriceIncludeTax'
	EXEC [prcAddIntFld] 'bt000', 'FldPriceIncludedTax'
	EXEC [prcAddBitFld] 'bt000', 'IsPriceOfferBill'
	EXEC [prcAddGUIDFld] 'en000', 'LCGUID'

	---- التصنيع
	DECLARE 
		@c CURSOR,
		@formGuid UNIQUEIDENTIFIER

	SET @c = CURSOR FAST_FORWARD FOR 
			SELECT GUID FROM FM000

	OPEN @c FETCH FROM @c INTO @formGuid
	WHILE @@FETCH_STATUS = 0
	BEGIN
		

		DECLARE @discount FLOAT 

		SET @discount = (
						 SELECT Top 1 ISNULL(Discount, 0) AS Discount
						   FROM MX000 MX INNER JOIN MN000 MN ON MN.GUID = MX.ParentGUID
									     INNER JOIN FM000 FM ON FM.GUID = MN.FormGUID
						  WHERE MX.Type = 1 AND MN.Type = 0  AND FM.GUID = @formGuid
						)

		UPDATE MX000
		SET Discount = @discount
			FROM  MN000 MN  INNER JOIN FM000 FM ON FM.GUID = MN.FormGUID
			WHERE  MN.Type = 1  AND 
				   FM.GUID = @formGuid AND 
				   MX000.Type = 1 AND 
				   mn.GUID= MX000.ParentGUID
		
		

		SET @discount = (
							SELECT Top 1 ISNULL(Discount, 0) AS Discount
								FROM MX000 MX INNER JOIN MN000 MN ON MN.GUID = MX.ParentGUID
										  INNER JOIN FM000 FM ON FM.GUID = MN.FormGUID
							WHERE MX.Type = 0 AND MN.Type = 0  AND FM.GUID = @formGuid AND MN.FormGUID = @formGuid
						)
		
		UPDATE MX000
		SET Discount = @discount
			FROM  MN000 MN  INNER JOIN FM000 FM ON FM.GUID = MN.FormGUID
		WHERE  MN.Type = 1  AND 
			   FM.GUID = @formGuid AND 
			   MX000.Type = 0 AND 
			   mn.GUID= MX000.ParentGUID
		
		
		
		FETCH FROM @c INTO @formGuid
	END 
	CLOSE @c 
	DEALLOCATE @c 

	EXEC ('UPDATE MX000  SET IsRatio = 0 ')
	EXEC ('UPDATE MX000  SET IsValue = 0 ')

	EXEC ('UPDATE MX000  SET IsRatio = 1 WHERE Extra <> 0 and Discount <> 0')
	EXEC ('UPDATE MX000  SET IsValue = 1 WHERE Extra <> 0 and Discount = 0')
######################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10009066
AS
	IF OBJECT_ID ('trg_bu000_DeleteRestOrderLinks', 'TR') IS NOT NULL 
		DROP TRIGGER trg_bu000_DeleteRestOrderLinks
######################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10009068
AS
	EXEC prcAddGUIDFld 'TrnTransferCompanyCard000', 'ExecutorGuid'
######################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10009069
AS
	EXECUTE [prcAlterFld] 'Allotment000', 'Notes', 'NVARCHAR(MAX)'

	EXEC [prcAddGUIDFld] 'nt000', 'DefCurrencyGuid'
	EXEC [prcAddIntFld]  'nt000', 'IsfreezingCurrency'

	EXEC [prcAddCharFld] 'lbt000', 'MenuName',250
	EXEC [prcAddCharFld] 'lbt000', 'MenuLatinName',250

	EXEC [prcAddCharFld] 'hbt000', 'MenuName',250
	EXEC [prcAddCharFld] 'hbt000', 'MenuLatinName',250
	
	EXEC [prcAddGuidFld] 'AssetPossessionsForm000', 'InStoreGuid'
	EXEC [prcAddGuidFld] 'AssetPossessionsForm000', 'OutStoreGuid'
	EXEC [prcAddGuidFld] 'AssetPossessionsForm000', 'TransTypeGuid'
	EXEC [prcAddGuidFld] 'AssetPossessionsForm000', 'TransBillGuid'

	UPDATE mt000 SET ForceInClass = 0, ForceOutClass = 0  WHERE ClassFlag = 0;

	Exec('

  BEGIN
	INSERT INTO ui000 
	SELECT NEWID(), U.UserGuid, ReportId, U.SubId, System, 14, 0
	FROM (SELECT DISTINCT UserGuid, ReportId, SubId, System FROM ui000 WHERE ReportId = 268500992) AS U
	WHERE NOT EXISTS(select * from ui000 where ReportId = 268500992 AND PermType =14 AND UserGUID = U.UserGUID);

	INSERT INTO ui000 
	SELECT NEWID(), U.UserGuid, ReportId, U.SubId, System, 15, 0
	FROM (SELECT DISTINCT UserGuid, ReportId, SubId, System FROM ui000 WHERE ReportId = 268500992) AS U
	WHERE NOT EXISTS(select * from ui000 where ReportId = 268500992 AND PermType =15 AND UserGUID = U.UserGUID);

	INSERT INTO ui000 
	SELECT NEWID(), U.UserGuid, ReportId, U.SubId, System, 16, 0
	FROM (SELECT DISTINCT UserGuid, ReportId, SubId, System FROM ui000 WHERE ReportId = 268500992) AS U
	WHERE NOT EXISTS(select * from ui000 where ReportId = 268500992 AND PermType =16 AND UserGUID = U.UserGUID);

	INSERT INTO ui000 
	SELECT NEWID(), U.UserGuid, ReportId, U.SubId, System, 17, 0
	FROM (SELECT DISTINCT UserGuid, ReportId, SubId, System FROM ui000 WHERE ReportId = 268500992) AS U
	WHERE NOT EXISTS(select * from ui000 where ReportId = 268500992 AND PermType =17 AND UserGUID = U.UserGUID);
  END

	UPDATE U
	  SET U.Permission = U2.Permission
      FROM
	      ui000 AS U
	 JOIN ui000 AS U2 ON U.ReportId = U2.ReportId AND U2.PermType = 10 AND U.SubId = U2.SubId AND U.UserGUID = U2.UserGUID 
	 WHERE 
	 U.ReportId = 268500992
     AND (U.PermType = 14 OR U.PermType =15 OR U.PermType = 16 OR U.PermType = 17)');

	 Exec('
   UPDATE us000
	 SET Dirty = 1 
     WHERE
	 bAdmin <> 1');

	 EXEC [prcAddBitFld] 'ac000', 'HideInSearch', 0

	EXECUTE prcAddGUIDFld 'Allocations000', 'CurrencyGuid'
	EXECUTE prcAddGUIDFld 'AssetUtilizeContract000', 'TransContractGuid'
	EXECUTE prcAddGUIDFld 'AssetUtilizeContract000', 'TransCloseGuid'
	EXECUTE prcAddGUIDFld 'evs000', 'OrderGuid'
	EXEC    prcAddIntFld  'st000', 'PrinterId'

	EXEC('
			UPDATE EVS
			SET
				OrderGuid = bu.GUID
		FROM
			EVS000 AS EVS
			JOIN bu000 AS bu ON bu.TypeGUID = EVS.POTypeGuid AND bu.Number = EVS.PONumber 
			WHERE 
				bu.CustGUID = EVS.SupplierGuid
				AND
				EVS.Date = (SELECT MAX(Date) FROM EVS000 WHERE POTypeGuid = EVS.POTypeGuid AND PONumber = EVS.PONumber AND SupplierGuid = EVS.SupplierGuid)	AND ISNULL(OrderGuid, 0x) = 0x');

	EXEC [prcAddGuidFld] 'bi000', 'RelatedTo'

	EXEC prcAddBitFld 'BillRelations000', 'IsRefundFromBill'
	EXEC [prcAddCharFld] 'BillRelations000', 'RefundFromBillDB', 50
	EXEC prcAddBitFld 'BillRelations000', 'IsPrevYearRefund'

	DECLARE @Command  NVARCHAR(1000)
	
    SELECT @Command = 'ALTER TABLE EVSI000 DROP CONSTRAINT ' + d.name
	FROM sys.tables t
		JOIN    sys.default_constraints d
			ON d.parent_object_id = t.object_id
		JOIN    sys.columns c
			ON c.object_id = t.object_id
			AND c.column_id = d.parent_column_id
		WHERE t.name = 'EVSI000'
			AND c.name = 'Degree'
    EXECUTE (@Command)

    ALTER TABLE [dbo].[EVSI000]
    ALTER COLUMN Degree FLOAT 

    ALTER TABLE EVSI000 
    ADD CONSTRAINT DF__EVSI000__DEGREE__019GG767E DEFAULT 0 FOR Degree

	EXEC('UPDATE nt000
	SET DefCurrencyGuid = (SELECT TOP 1 GUID FROM MY000 WHERE CurrencyVal = 1)
	WHERE DefCurrencyGuid = 0x0');

	EXEC('UPDATE POSCheckItem000
	SET CurID = nt.DefCurrencyGuid, CurVal = ISNULL(mh.CurrencyVal,my.CurrencyVal) 
	FROM POSCheckItem000 ch
	INNER JOIN nt000 nt ON ch.CheckID = nt.[GUID]
	INNER JOIN my000 my ON nt.DefCurrencyGuid = my.[GUID]
	LEFT JOIN mh000 mh ON mh.CurrencyGUID = nt.DefCurrencyGuid AND mh.[Date] = (SELECT MAX([Date]) FROM mh000 WHERE CurrencyGUID = nt.DefCurrencyGuid and [date] <= GETDATE())');

	EXEC [prcAddGUIDFld] 'ts000', 'OriginGUID'
	EXEC [prcAddIntFld]  'ts000', 'OriginType'
	EXEC [prcAddIntFld]  'ts000', 'OriginNumber'
	
	EXEC [prcAddCharFld] 'bg000', 'LatinCaption', 256;
	EXEC [prcAddCharFld] 'bgi000', 'LatinCaption', 256;

	EXEC('UPDATE bg000
	SET LatinCaption = gr.LatinName
	FROM bg000 bg
	INNER JOIN gr000 gr ON gr.[GUID] = bg.GroupGUID
	WHERE bg.GroupGUID <> 0x0 AND bg.IsAutoCaption = 1');

	-- Start Upgrad Log File
	IF NOT EXISTS(SELECT * FROM log000)
	BEGIN
		INSERT INTO log000
			SELECT GUID, LogTime, UserGUID, Computer, CASE Operation WHEN 3 THEN 2 ELSE Operation END, OperationType, RecGUID, LogTime, RecNum, SubGUID, Notes, RepId, '' FROM lg000

		UPDATE log000
			SET OperationType = 12
			WHERE (DrvRId = 4096 AND OperationType IN (0, 4)) OR Operation = 2048
	END
######################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10009071
AS
	IF EXISTS(SELECT * FROM op000 WHERE Name = 'HosCfg_IsBriefEntry')
	BEGIN
		UPDATE op000 
		SET Name ='HosCfg_IsBriefEntry' ,
		Value = CASE WHEN Value = 0 THEN 1 ELSE 0 END 
		WHERE Name = 'HosCfg_CANCELSHOURTCATENTRY'
	END

	EXECUTE [prcAlterFld] 'log000', 'Notes', 'NVARCHAR(1000)'

	-- GCC R2
	IF [dbo].[fnObjectExists]('en000.CustomerGUID') =  0
	BEGIN 
		EXEC prcAddGUIDFld 'en000', 'CustomerGUID'
		EXEC ('
			ALTER TABLE en000 DISABLE TRIGGER ALL

			UPDATE en000 
			SET CustomerGUID = cu.GUID 
			FROM 
				en000 en 
				INNER JOIN ac000 ac ON en.AccountGUID = ac.GUID 
				INNER JOIN cu000 cu ON cu.AccountGUID = ac.GUID 
			WHERE 
				ISNULL(en.CustomerGUID, 0x0) = 0x0	

			UPDATE en000 
			SET Type = CASE et.TaxType WHEN 1 THEN 101 WHEN 2 THEN 102 ELSE en.Type END
			FROM 
				en000 en 
				INNER JOIN ce000 ce ON en.ParentGUID = ce.GUID 
				INNER JOIN er000 er ON er.EntryGUID = ce.GUID 
				INNER JOIN py000 py ON er.ParentGUID = py.GUID 
				INNER JOIN et000 et ON py.TypeGUID = et.GUID
			WHERE 
				ISNULL(en.ParentVATGuid, 0x0) != 0x0

			ALTER TABLE en000 ENABLE TRIGGER ALL ')
	END

	EXEC prcAddFloatFld 'cu000', 'Debit'

	IF [dbo].[fnObjectExists]('cu000.Credit') =  0
	BEGIN 
		EXEC prcAddFloatFld 'cu000', 'Credit'
		-- EXEC prcEntry_Repost 1
	END 

	IF [dbo].[fnObjectExists]('et000.FldCustomerName') =  0
	BEGIN 
		EXEC prcAddIntFld 'et000', 'FldCustomerName'
		EXEC('UPDATE et000 SET 
				-- FldAccName = CASE WHEN FldAccName <= 0 THEN , 
				FldDebit = CASE WHEN FldDebit > FldAccName THEN FldDebit + 1 ELSE FldDebit END, 
				FldCredit = CASE WHEN FldCredit > FldAccName THEN FldCredit + 1 ELSE FldCredit END, 
				FldNotes = CASE WHEN FldNotes > FldAccName THEN FldNotes + 1 ELSE FldNotes END,  
				FldCurName = CASE WHEN FldCurName > FldAccName THEN FldCurName + 1 ELSE FldCurName END,  
				FldCurVal = CASE WHEN FldCurVal > FldAccName THEN FldCurVal + 1 ELSE FldCurVal END,  
				FldStat = CASE WHEN FldStat > FldAccName THEN FldStat + 1 ELSE FldStat END,  
				FldCostPtr = CASE WHEN FldCostPtr > FldAccName THEN FldCostPtr + 1 ELSE FldCostPtr END,  
				FldDate = CASE WHEN FldDate > FldAccName THEN FldDate + 1 ELSE FldDate END,  
				FldVendor = CASE WHEN FldVendor > FldAccName THEN FldVendor + 1 ELSE FldVendor END,  
				FldSalesMan = CASE WHEN FldSalesMan > FldAccName THEN FldSalesMan + 1 ELSE FldSalesMan END,  
				FldAccParent = CASE WHEN FldAccParent > FldAccName THEN FldAccParent + 1 ELSE FldAccParent END,  
				FldAccFinal = CASE WHEN FldAccFinal > FldAccName THEN FldAccFinal + 1 ELSE FldAccFinal END,  
				FldAccCredit = CASE WHEN FldAccCredit > FldAccName THEN FldAccCredit + 1 ELSE FldAccCredit END,  
				FldAccDebit = CASE WHEN FldAccDebit > FldAccName THEN FldAccDebit + 1 ELSE FldAccDebit END,  
				FldAccBalance = CASE WHEN FldAccBalance > FldAccName THEN FldAccBalance + 1 ELSE FldAccBalance END,  
				FldContraAcc = CASE WHEN FldContraAcc > FldAccName THEN FldContraAcc + 1 ELSE FldContraAcc END,   
				FldCurEqu = CASE WHEN FldCurEqu > FldAccName THEN FldCurEqu + 1 ELSE FldCurEqu END,   
				FldAddedValue = CASE WHEN FldAddedValue > FldAccName THEN FldAddedValue + 1 ELSE FldAddedValue END,
				FldTaxValue = CASE WHEN FldTaxValue > FldAccName THEN FldTaxValue + 1 ELSE FldTaxValue END,
				FldLC = CASE WHEN FldLC > FldAccName THEN FldLC + 1 ELSE FldLC END,
				FldCustomerName = FldAccName + 1')
	END
	-- END GCC R2
	EXEC prcAddBitFld 'LCRelatedExpense000', 'IsTransfared'
	EXEC prcAddCharFld 'LCRelatedExpense000', 'LCName', 250
	EXEC prcAddGUIDFld 'LCRelatedExpense000', 'AccountGUID'
	EXEC prcAddDateFld 'LCRelatedExpense000', 'Date'
	EXEC prcAddFloatFld 'LCRelatedExpense000', 'NetVal'
	EXEC prcAddGUIDFld 'LCRelatedExpense000', 'CurGUID'
	EXEC prcAddFloatFld 'LCRelatedExpense000', 'CurVal'
	EXEC prcAddCharFld 'LCRelatedExpense000', 'Note', 250
	EXEC prcAddBitFld  'LC000', 'IsTransfared'

	
	IF [dbo].[fnObjectExists]('ch000.CustomerGuid') =  0
	BEGIN 
		EXEC prcAddGUIDFld 'ch000', 'CustomerGuid'
		EXEC('UPDATE ch SET CustomerGuid = cu.GUID
				FROM ch000 AS ch INNER JOIN cu000 cu ON cu.AccountGUID = ch.AccountGUID 
			')
	END
	
	IF [dbo].[fnObjectExists]('ch000.EndorseCustGUID') =  0
	BEGIN 
		EXEC prcAddGUIDFld 'ch000', 'EndorseCustGUID'
		EXEC('UPDATE ch SET EndorseCustGUID = cu.GUID
				FROM ch000 AS ch INNER JOIN cu000 cu ON cu.AccountGUID = ch.EndorseAccGUID 
			')
	END
	
	IF [dbo].[fnObjectExists]('ChequeHistory000.DebitCustomer') = 0
	BEGIN
		EXEC prcAddGUIDFld 'ChequeHistory000', 'DebitCustomer'
		EXEC('UPDATE cheq SET DebitCustomer = cu.GUID
				FROM ChequeHistory000 AS cheq INNER JOIN cu000 cu ON cu.AccountGUID = cheq.DebitAccount
			')
	END
		
	IF [dbo].[fnObjectExists]('ChequeHistory000.CreditCustomer') = 0
	BEGIN
		EXEC prcAddGUIDFld 'ChequeHistory000', 'CreditCustomer'
		EXEC('UPDATE cheq SET CreditCustomer = cu.GUID
				FROM ChequeHistory000 AS cheq INNER JOIN cu000 cu ON cu.AccountGUID = cheq.CreditAccount
			')	
	END

	EXEC prcAddGUIDFld 'et000', 'ReverseChargesAccGUID'
	EXEC prcAddGUIDFld 'et000', 'ReverseChargesContraAccGUID'
	EXEC prcAddBitFld 'et000', 'UseReverseCharges'

	EXEC prcAddIntFld 'et000', 'FldGCCOriginDate'
	EXEC prcAddIntFld 'et000', 'FldGCCOriginNumber'

	EXEC prcAddDateFld 'en000', 'GCCOriginDate'
	EXEC prcAddCharFld 'en000', 'GCCOriginNumber', 250 

	IF [dbo].[fnObjectExists]('CheckAcc000.CustGUID') = 0
	BEGIN
		EXEC prcAddGUIDFld 'CheckAcc000', 'CustGUID'
		EXEC('UPDATE ac SET CustGUID = cu.GUID
				FROM CheckAcc000 AS ac INNER JOIN cu000 cu ON cu.AccountGUID = ac.AccGUID
			')	
	END

	EXEC prcDropTable 'lbf000'	
	EXEC prcDropTable 'lbRel000'	
	EXEC prcDropTable 'lbt000'	
	EXEC prcDropTable 'lbtf000'	

	EXEC prcDropView 'vtLBt'
	EXEC prcDropView 'vbLBt'
	EXEC prcDropView 'vcLBt'
	EXEC prcDropView 'vwLBt'
	EXEC prcDropView 'vwExtended_LBT'

	EXEC prcDropFunction 'fnIsLCBill'
	EXEC prcDropFunction 'fnLCBtFld_IsUsed'
	EXEC prcDropFunction 'fnGetLCFields'
	EXEC prcDropFunction 'fnLCBillType_IsUsed'
	EXEC prcDropFunction 'fnLOCBillType_IsUsed'
	EXEC prcDropFunction 'fnGetLOCFields'
	EXEC prcDropFunction 'fnLOCBtFld_IsUsed'
	EXEC prcDropFunction  'fnIsLOCBill'
	
	EXEC prcDropProcedure 'repDailyTurnOver'

	EXEC('UPDATE po SET DeferredAccount = cu.GUID
			FROM POSPaymentsPackage000 AS po INNER JOIN cu000 cu ON cu.AccountGUID = po.DeferredAccount
		')

	IF [dbo].[fnObjectExists]('RestEntry000.CustomerID') = 0
	BEGIN
		EXEC prcAddGUIDFld 'RestEntry000', 'CustomerID'
		EXEC('UPDATE rest SET CustomerID = cu.GUID
				FROM RestEntry000 AS rest INNER JOIN cu000 cu ON cu.AccountGUID = rest.AccID
			')	
	END

	EXEC('UPDATE [op] SET [value] = [cu].[GUID], [name] = ''AmnRest_MediatorCustID''
			FROM [UserOp000] [op] INNER JOIN cu000 [cu] ON [cu].[AccountGUID] = [op].[value]
		   WHERE [name] LIKE ''AmnRest_MediatorAccID''	

		  UPDATE rest SET MediatorAccID = cu.GUID
			FROM RestConfig000 AS rest INNER JOIN cu000 cu ON cu.AccountGUID = rest.MediatorAccID
	
		  UPDATE rest SET MediatorAccName = cu.CustomerName
			FROM RestConfig000 AS rest INNER JOIN cu000 cu ON cu.AccountGUID = rest.MediatorAccID
		
		  UPDATE [op] SET [value] = [cu].[GUID], [name] = ''AmnPOS_MediatorCustID''
			FROM [UserOp000] [op] INNER JOIN cu000 [cu] ON [cu].[AccountGUID] = [op].[value]
		   WHERE [name] LIKE ''AmnPOS_MediatorAccID''	
	  
		  UPDATE po SET MediatorAccID = cu.GUID
			FROM POSConfig000 AS po INNER JOIN cu000 cu ON cu.AccountGUID = po.MediatorAccID
		')

	IF [dbo].[fnObjectExists]('POSPayRecieveTable000.CustomerGUID') = 0
	BEGIN
		EXEC prcAddGUIDFld 'POSPayRecieveTable000', 'CustomerGUID'
		EXEC('UPDATE pos SET CustomerGUID = cu.GUID
				FROM POSPayRecieveTable000 AS pos INNER JOIN cu000 cu ON cu.AccountGUID = pos.FromAccGUID
			   WHERE pos.Type = 1
			  UPDATE pos SET CustomerGUID = cu.GUID
				FROM POSPayRecieveTable000 AS pos INNER JOIN cu000 cu ON cu.AccountGUID = pos.ToAccGUID
			   WHERE pos.Type = 2
			')	
	END

	EXECUTE prcAddFloatFld 'cu000', 'MaxDebit'
	EXECUTE prcAddFloatFld 'cu000', 'Warn'
		
	EXECUTE prcAddFloatFld 'bi000', 'CustomsRate'
	EXECUTE prcAddBitFld 'bu000', 'ImportViaCustoms'
	EXECUTE prcAddIntFld 'bt000', 'FldCustomsRate'

	EXECUTE prcAddDateFld 'GCCTaxSettings000', 'PaymentsSubscriptionDate'
	EXECUTE prcAddBitFld 'GCCTaxSettings000', 'ForceNumberingByBillType'
######################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10009072
AS
	UPDATE bt000
		SET bNoEntry = 1
	WHERE [TYPE] = 2 AND [SortNum] = 1 AND bNoEntry = 0

	DELETE FROM op000 
		WHERE 
		(Name = 'AmnCostRep_CationQtyNotEnough' OR
		Name = 'AmnCostRep_ShowUnits' OR
		Name = 'AmnCostRep_ShowExpireDate' OR
		Name = 'AmnCostRep_ShowClass' OR
		Name = 'AmnCostRep_AutoStateChange' OR
		Name = 'AmnCostRep_repeatLOT' OR
		Name = 'AmnCostRep_mandatoryLOT' OR
		Name = 'AmnCostRep_ShowExpireDate' OR
		Name = 'AmnCostRep_ShowClass' OR
		Name = 'AmnCostRep_ShowPrice' OR
		Name = 'AmnCostRep_PricePol' OR
		Name = 'AmnCostRep_UseOfProductionsStepsFeature' OR
		Name = 'AmnCostRep_UseCostCenter' OR
		Name = 'AmnCostRep_WithoutCostCenter' OR
		Name = 'AmnCostRep_ForceCostCenterInManForm')AND 
		[Type] = 2

	EXEC('UPDATE op000 
		SET Value = CAST((CAST(Value AS BIGINT) | 1073779534) AS NVARCHAR(200))
		WHERE name=''ChkCollect_FldFlag''');

######################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10009073
AS
	SET NOCOUNT ON 

	IF EXISTS(SELECT * FROM op000 WHERE name LIKE N'AmnCfg_HTML_CustomPanel_%_TemplateName' AND Value=N'الطلبات')
	BEGIN
		UPDATE op000
		SET Value = N'الطلبيات'
		WHERE name LIKE N'AmnCfg_HTML_CustomPanel_%_TemplateName' AND Value = N'الطلبات'
	END

	-- CMPT04 - 01
	IF NOT EXISTS (SELECT * FROM UserOP000 WHERE Name = 'AmnRest_AdjustAccIDDec')
	BEGIN
		INSERT INTO UserOP000 SELECT NEWID(), UserID, 'AmnRest_AdjustAccIDDec', Value
			FROM UserOP000 WHERE NAME = 'AmnRest_AdjustAccID'
	END

	IF NOT EXISTS (SELECT * FROM UserOP000 WHERE Name = 'AmnPOS_AdjustAccIDDec')
	BEGIN
		INSERT INTO UserOP000 SELECT NEWID(), UserID, 'AmnPOS_AdjustAccIDDec', Value
			FROM UserOP000 WHERE NAME = 'AmnPOS_AdjustAccID'
	END

	IF EXISTS (SELECT * FROM GCCTaxCoding000)
	BEGIN 
		UPDATE GCCTaxCoding000 SET Number = 101 WHERE TaxCode = 7 AND Number != 101
		UPDATE GCCTaxCoding000 SET Number = 102 WHERE TaxCode = 8 AND Number != 102
		UPDATE GCCTaxCoding000 SET Number = 103 WHERE TaxCode = 9 AND Number != 103
		UPDATE GCCTaxCoding000 SET Number = 104 WHERE TaxCode = 10 AND Number != 104
		UPDATE GCCTaxCoding000 SET Number = 105 WHERE TaxCode = 11 AND Number != 105

		IF NOT EXISTS (SELECT * FROM GCCTaxCoding000 WHERE TaxCode = 12)
			INSERT INTO GCCTaxCoding000 (Number, GUID, Code, Name, LatinName, TaxType, TaxCode, TaxRatio)
			SELECT 7, NEWID(), N'PU', N'مبيعات المواطنين (الصحة/التعليم/المسكن الأول)', N'Private Healthcare/Private Education/First house sales to citizens', 1, 12, 0

		IF NOT EXISTS (SELECT * FROM GCCTaxCoding000 WHERE TaxCode = 13)
			INSERT INTO GCCTaxCoding000 (Number, GUID, Code, Name, LatinName, TaxType, TaxCode, TaxRatio)
			SELECT 8, NEWID(), N'XP', N'الصادرات', N'Exports', 1, 13, 0
	END 

	IF [dbo].[fnObjectExists]('bi000.OrginalTaxCode') =  0
	BEGIN 
		EXEC prcAddIntFld 'bi000', 'OrginalTaxCode';
		EXECUTE [prcFlag_set] 1 -- re-index
		EXEC('UPDATE op000 SET Value =''0'' WHERE Name LIKE ''AmnCfg_PrintOption_%AutoPrint''')
	END 

	IF ([dbo].[fnObjectExists]('AccCostNewRatio000.CustomerGUID') =  0)
	BEGIN 
		EXEC prcAddGUIDFld 'AccCostNewRatio000', 'CustomerGUID';

		EXEC ('	UPDATE  ac
					SET ac.CustomerGUID = (cu.GUID ) 
					FROM   
						AccCostNewRatio000 ac  
						INNER JOIN (   
							SELECT  ac.SonGUID,count (*) AS cnt  
							FROM AccCostNewRatio000 AS ac
							GROUP BY ac.SonGUID 
							HAVING count (*) = 1 ) AS cust
						ON ac.SonGUID = cust.SonGUID
						INNER JOIN cu000 AS cu ON cu.AccountGUID = cust.SonGUID
				') 
	END

	IF ([dbo].[fnObjectExists]('ci000.CustomerGUID') =  0)
	BEGIN 
		EXEC prcAddGUIDFld 'ci000', 'CustomerGUID';
		EXEC ('	UPDATE  ci
			SET ci.CustomerGUID = (cu.GUID ) 
				FROM   
					ci000 ci  
					INNER JOIN (   
						SELECT  cu.SonGUID,count (*) AS cnt  
						FROM ci000 AS cu
						GROUP BY cu.SonGUID 
						HAVING count (*) = 1 ) AS cust ON ci.SonGUID = cust.SonGUID
						INNER JOIN cu000 AS cu ON cu.AccountGUID = cust.SonGUID') 
	END

	IF [dbo].[fnObjectExists]('ax000.CustomerGUID') =  0
	BEGIN
		EXEC prcAddGUIDFld 'ax000', 'CustomerGUID'
		EXEC ('UPDATE   ax
				SET ax.CustomerGUID = cu.GUID
				FROM   
				ax000 ax  
				INNER JOIN (   
					SELECT  cu.AccountGUID,count (*) as cnt  
					FROM cu000 as cu
					GROUP BY cu.AccountGUID 
					HAVING COUNT(*) = 1) cust ON ax.AccGUID = cust.AccountGUID
					INNER JOIN cu000 AS cu ON cu.AccountGUID = cust.AccountGUID')
	END 

	IF [dbo].[fnObjectExists]('us000.IsInactive') =  0
	BEGIN
		EXECUTE	prcAddBitFld 'us000', 'IsInactive'
		IF EXISTS(SELECT * FROM mc000 WHERE [Type] = 9000 AND [Asc1] = 'Inactive All Users')
		BEGIN
			EXEC ('UPDATE us000
				       SET IsInactive = 1
				   WHERE bAdmin = 0 AND Type = 0')
		END
	END
	DELETE FROM mc000 WHERE [Type] = 9000 AND [Asc1] = 'Inactive All Users'
	-- END CMPT04 - 01
	IF((SELECT MAX(IncomeType) FROM ac000) <= 17)
	BEGIN
		UPDATE ac000 SET IncomeType = IncomeType + 1
		WHERE IncomeType > 11 
	END
######################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10009500
AS 
	IF([dbo].[fnObjectExists]('prcPOSCheckOptions') = 1)
		DROP PROC prcPOSCheckOptions

	EXEC prcAddBitFld 'Distributor000', 'AutoNewCustToRoute'
	EXEC prcAddIntFld 'DistDeviceNewCu000', 'Route1'

	EXECUTE [prcAlterFld] 'bu000', 'ReturendBillNumber', 'NVARCHAR(500)'
	EXECUTE [prcAlterFld] 'POSOrder000', 'ReturendBillNumber', 'NVARCHAR(500)'
	EXECUTE [prcAlterFld] 'POSOrderTemp000', 'ReturendBillNumber', 'NVARCHAR(500)'

	EXEC prcAddCharFld 'DistDeviceCU000', 'TaxNumber' , 250
	EXEC prcAddCharFld 'DistDeviceCU000', 'LocationName' , 250
	EXEC prcAddCharFld 'DistDeviceCU000', 'LocationLatinName' , 250

	-- BEGIN CMPT04 - 02
	-- BEGIN POS Field
	EXECUTE prcAddCharFld 'POSOrder000', 'TextFld1', 250
	EXECUTE prcAddCharFld 'POSOrder000', 'TextFld2', 250
	EXECUTE prcAddCharFld 'POSOrder000', 'TextFld3', 250
	EXECUTE prcAddCharFld 'POSOrder000', 'TextFld4', 250

	EXECUTE prcAddCharFld 'POSOrderTemp000', 'TextFld1', 250
	EXECUTE prcAddCharFld 'POSOrderTemp000', 'TextFld2', 250
	EXECUTE prcAddCharFld 'POSOrderTemp000', 'TextFld3', 250
	EXECUTE prcAddCharFld 'POSOrderTemp000', 'TextFld4', 250

	EXEC prcAddGUIDFld 'POSOrderItems000', 'RelatedBillID'
	EXEC prcAddGUIDFld 'POSOrderItemsTemp000', 'RelatedBillID'
	EXEC prcAddGUIDFld 'POSOrderItems000', 'BillItemID'
	EXEC prcAddGUIDFld 'POSOrderItemsTemp000', 'BillItemID'
	-- END POS Field
	
	IF [dbo].[fnObjectExists]('Allocations000.CustomerGUID') =  0
	BEGIN
		EXEC prcAddGUIDFld 'Allocations000', 'CustomerGUID'
		EXEC ('UPDATE   al
					SET CustomerGUID = (cu.GUID ) 
					FROM   
						Allocations000 al  
						INNER JOIN (   
							SELECT  cu.AccountGUID,count (*) as cnt  
							FROM cu000 as cu
							GROUP BY cu.AccountGUID 
							having count (*) = 1 ) cust
						ON    al.AccountGuid = cust.AccountGUID
						inner join cu000 as cu on cu.AccountGUID = cust.AccountGUID
				')
	END

	IF [dbo].[fnObjectExists]('Allocations000.ContraCustomerGUID') =  0
	BEGIN
		EXEC prcAddGUIDFld 'Allocations000', 'ContraCustomerGuid'
		EXEC ('UPDATE   al
					SET ContraCustomerGuid = (cu.GUID ) 
					FROM   
						Allocations000 al  
						INNER JOIN (   
							SELECT  cu.AccountGUID,count (*) as cnt  
							FROM cu000 as cu
							GROUP BY cu.AccountGUID 
							having count (*) = 1 ) cust
						ON    al.AccountGuid = cust.AccountGUID
						inner join cu000 as cu on cu.AccountGUID = cust.AccountGUID
				')

		EXEC ('
				DELETE FROM op000 WHERE Name = ''AccCfg_AllotmentCard.PaysGridsFields''
				DELETE FROM op000 WHERE Name = ''AccCfg_AllotmentCard.PaysChecksFields''
			')
	END

	EXECUTE	prcAddBitFld 'cu000', 'ConsiderChecksInBudget'
	EXECUTE [prcAddBitFld] 'SpecialOffers000', 'CanOfferedSelected'

	IF EXISTS (SELECT * FROM GCCTaxCoding000)
	BEGIN 
		IF NOT EXISTS (SELECT * FROM GCCTaxCoding000 WHERE TaxCode = 14)
			INSERT INTO GCCTaxCoding000 (Number, GUID, Code, Name, LatinName, TaxType, TaxCode, TaxRatio)
			SELECT 9, NEWID(), N'NA', N'غير مكلف', N'Not Assignment', 1, 14, 0

			EXEC ('
			UPDATE en
			SET GCCOriginDate = py.Date
			FROM 
				en000 en 
				INNER JOIN ce000 ce ON ce.GUID = en.ParentGUID 
				INNER JOIN er000 er ON ce.GUID = er.EntryGUID 
				INNER JOIN py000 py ON py.GUID = er.ParentGUID 
			WHERE GCCOriginNumber != N'''' AND GCCOriginDate = ''1980-01-01''')

	END 
	-- END CMPT04 - 02
	--- correct invalid customer related to account 

	EXEC ('		
		DECLARE @cnt INT 
		SET @cnt = 0

		EXEC prcDisableTriggers ''en000''

		UPDATE en000 
		SET CustomerGUID = cu.GUID
		FROM 
			en000 en 
			INNER JOIN ac000 ac ON ac.GUID = en.AccountGUID
			INNER JOIN 
			(SELECT a.GUID FROM ac000 a INNER JOIN cu000 cu ON a.GUID = cu.AccountGUID GROUP BY a.GUID HAVING COUNT(*) = 1) fn ON fn.GUID = ac.GUID
			INNER JOIN cu000 cu ON fn.GUID = cu.AccountGUID
		WHERE 
			en.CustomerGUID = 0x0
		SET @cnt = @@ROWCOUNT

		UPDATE en000 
		SET CustomerGUID = cu.GUID
		FROM 
			en000 en 
			INNER JOIN ac000 ac ON ac.GUID = en.AccountGUID
			INNER JOIN 
			(SELECT a.GUID FROM ac000 a INNER JOIN cu000 cu ON a.GUID = cu.AccountGUID GROUP BY a.GUID HAVING COUNT(*) = 1) fn ON fn.GUID = ac.GUID
			INNER JOIN cu000 cu ON fn.GUID = cu.AccountGUID
		WHERE 
			en.CustomerGUID != cu.GUID 
		SET @cnt = @@ROWCOUNT + @cnt

		UPDATE EN
			SET En.CustomerGUID = Bu.CustGUID
		FROM en000 AS EN
		INNER JOIN er000 AS ER ON ER.EntryGUID = EN.ParentGUID
		INNER JOIN bu000 AS Bu ON Bu.GUID = ER.ParentGUID AND EN.AccountGUID = Bu.CustAccGUID
		WHERE 
			BU.PayType = 0 -- Cash
			AND NOT EXISTS(SELECT 1 FROM cu000 WHERE AccountGUID = Bu.CustAccGUID)
			AND Bu.CustGUID <> 0x
			AND EN.CustomerGUID = 0x

		SET @cnt = @@ROWCOUNT + @cnt;

		EXEC prcEnableTriggers ''en000''

		IF @cnt > 0
			EXEC prcEntry_rePost ');

######################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10009667
AS
	EXEC prcAddDateFld 'mt000', 'FirstCostDate'
	EXEC prcAddBitFld 'mt000', 'IsCalcTaxForPUTaxCode'

	UPDATE bt000 set LatinAbbrev = N'Cost.In' where Name = N'إدخال تكلفة'
	UPDATE bt000 set Abbrev = N'Cost.In', LatinAbbrev = N'Cost.In' where Name = N'Enter cost'
	
	UPDATE bt000 set LatinAbbrev = N'Cost.Out' where Name = N'إخراج تكلفة'
	UPDATE bt000 set Abbrev =  N'Cost.Out', LatinAbbrev = N'Cost.Out' where Name = N'Output cost'
	
	-- BEGIN CMPT04 - 03
	EXEC prcAddGUIDFld 'POSOrderDiscountTemp000', 'OrderItemID'
	EXEC prcAddGUIDFld 'POSOrderDiscount000', 'OrderItemID'	

	IF [dbo].[fnObjectExists]('bu000.TotalReversChargeTax') =  0
	BEGIN
		EXEC prcAddFloatFld 'bu000', 'TotalReversChargeTax'
		EXEC prcAddFloatFld 'bu000', 'TotalPurchaseVal'
		IF EXISTS(SELECT 1 FROM bi000 WHERE ReversChargeVal > 0)
		BEGIN
			EXEC('
			;WITH R AS 
			(
				SELECT
					ParentGUID AS BuGUID,
					SUM(ReversChargeVal) AS RC,
					SUM(PurchaseVal) AS P
				FROM 
					bi000
				WHERE 
					ReversChargeVal > 0 OR PurchaseVal > 0
				GROUP BY ParentGUID
			)
			UPDATE BU
			SET
				TotalReversChargeTax = R.RC, TotalPurchaseVal = R.P
			FROM 
				bu000 AS BU
				JOIN R ON BU.GUID = R.BuGUID');
		END
	END
	

	IF OBJECT_ID(N'trg_cu000_Barcode', N'TR') IS NOT NULL
	BEGIN
		 DROP TRIGGER trg_cu000_Barcode
	END
	-- END CMPT04 - 03

	IF [dbo].[fnObjectExists]('SpecialOffer000.OfferIndex') =  0
	BEGIN
		EXEC prcAddIntFld 'SpecialOffer000', 'OfferMode'
		EXEC prcAddGUIDFld 'SpecialOffer000', 'MatID'
		EXEC prcAddGUIDFld 'SpecialOffer000', 'GroupID'
		EXEC prcAddIntFld 'SpecialOffer000', 'Unit'
		EXEC prcAddBitFld 'SpecialOffer000', 'ApplayOnce'
		EXEC prcAddBitFld 'SpecialOffer000', 'CheckExactQty'
		EXEC prcAddIntFld 'SpecialOffer000', 'OfferIndex'

		EXEC('WHILE EXISTS (SELECT * FROM SpecialOffer000 WHERE [OfferIndex] = 0)
		BEGIN
			UPDATE
			SpecialOffer000
				SET [OfferIndex] = (SELECT ISNULL(MAX([OfferIndex]), 0) + 1 FROM SpecialOffer000)
			WHERE Guid = (SELECT TOP 1 GUID FROM SpecialOffer000 WHERE [OfferIndex] = 0)
		END')
		--Must include delete statements in newer field check such as IF [dbo].[fnObjectExists]('') to prevent subsequent execution every update DB
		DELETE op000 WHERE Name = 'AccountPosFld'
		DELETE op000 WHERE Name = 'CustomerCreditFld'
		DELETE op000 WHERE Name = 'CurrFld'
		DELETE op000 WHERE Name = 'TotalPosFld'
		DELETE op000 WHERE Name = 'CounterAccountPosFld'
		DELETE op000 WHERE Name = 'CustomerDebitFld'
		DELETE op000 WHERE Name = 'PaymentsPosFld'
		DELETE op000 WHERE Name = 'MonthPortionPosFld'
		DELETE op000 WHERE Name = 'FromMonthPosFld'
		DELETE op000 WHERE Name = 'ToMonthPosFld'
		DELETE op000 WHERE Name = 'DistPayNumFld'
		DELETE op000 WHERE Name = 'DistPayPriceFld'
		DELETE op000 WHERE Name = 'RestPayNumFld'
		DELETE op000 WHERE Name = 'RestPayPriceFld'
		DELETE op000 WHERE Name = 'CirclePayNumFld'
		DELETE op000 WHERE Name = 'CirclePayPriceFld'
		DELETE op000 WHERE Name = 'DebitCostFld'
		DELETE op000 WHERE Name = 'CreditCostFld'
		DELETE op000 WHERE Name = 'NoteFld'
	END

	-- BEGIN CMPT04 - 04
	EXEC [prcAddGUIDFld] 'bu000', 'CreateUserGUID'
	EXEC [prcAddDateFld] 'bu000', 'CreateDate'
	EXEC [prcAddGUIDFld] 'bu000', 'LastUpdateUserGUID'	
	EXEC [prcAddDateFld] 'bu000', 'LastUpdateDate'
		
	EXEC [prcAddGUIDFld] 'ce000', 'CreateUserGuid'
	EXEC [prcAddDateFld] 'ce000', 'CreateDate'
	EXEC [prcAddGUIDFld] 'ce000', 'LastUpdateUserGuid'	
	EXEC [prcAddDateFld] 'ce000', 'LastUpdateDate'

	EXEC [prcAddGUIDFld] 'py000', 'CreateUserGuid'
	EXEC [prcAddDateFld] 'py000', 'CreateDate'
	EXEC [prcAddGUIDFld] 'py000', 'LastUpdateUserGuid'	
	EXEC [prcAddDateFld] 'py000', 'LastUpdateDate'		

	EXEC [prcAddBitFld ]'cu000', 'ExemptFromTax'
	EXEC [prcAddCharFld] 'cu000', 'TaxNumber' , 250

	-- END CMPT04 - 04
	--END
	EXEC [prcAddGUIDFld] 'POSOrder000', 'SalesManID'
	EXEC [prcAddGUIDFld] 'POSOrderTemp000', 'SalesManID'

	IF [dbo].[fnObjectExists]('nt000.IsfreezingCurrency') <>  0
	BEGIN
		EXEC PrcAddBitFld 'nt000', 'IsfrizzingCurrency', 0
		EXEC('UPDATE nt000 SET IsfrizzingCurrency = IsfreezingCurrency')

		EXEC prcDropFld	'nt000', 'IsfreezingCurrency'
	END
######################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10009743 
AS
  -- BEGIN GCC03
	EXEC [prcAddDateFld] 'GCCTaxSettings000', 'FirstPeriodStartDate'
	EXEC [prcAddDateFld] 'GCCTaxSettings000', 'FirstPeriodEndDate'
	EXEC [prcAddIntFld] 'GCCTaxSettings000', 'NextPeriodsType'
	EXEC [prcAddBitFld] 'GCCTaxSettings000', 'IsTransfered'
		 
	EXEC [prcAddBitFld] 'GCCTaxDurations000', 'IsTransfered'
	EXEC [prcAddBitFld] 'GCCTaxDurations000', 'IsCrossed'
	EXEC [prcAddGUIDFld] 'GCCTaxDurations000', 'TaxVatReportGUID'
	EXEC [prcAddBitFld] 'bt000', 'bCollectCustAccount'
	EXEC [prcAddIntFld] 'et000', 'FLdPaidState'
	IF [dbo].[fnObjectExists]('bu000.GCCLocationGUID') =  0
	BEGIN
		EXEC prcAddGUIDFld 'bu000', 'GCCLocationGUID'
		EXEC (
				N'UPDATE BU SET GCCLocationGUID = BT.DefaultLocationGUID
				FROM 
					BU000 BU 
					INNER JOIN BT000 BT ON BT.GUID = BU.TypeGUID
					INNER JOIN CU000 CU ON CU.GUID = BU.CustGUID
					INNER JOIN GCCCustLocations000 L ON L.GUID = CU.GCCLocationGUID
				WHERE 
					BT.BillType IN (1, 3) 
					AND 
					L.Classification = 0 AND ISNULL(BT.DefaultLocationGUID, 0x0) != 0x0')

		IF NOT EXISTS(SELECT * FROM mc000 WHERE Number = 1025 AND Asc1 = 'GCC3_UPGRADE' AND Num1 = 1)
		BEGIN
			INSERT INTO mc000(Number, Asc1, Num1) VALUES (1025, 'GCC3_UPGRADE', 1)
		END
	END
	IF [dbo].[fnObjectExists]('LC000.EntryGUID') !=  0
	BEGIN
		IF EXISTS (SELECT * FROM LC000)
			EXEC ('INSERT INTO LCEntries000 SELECT NEWID(), GUID, EntryGUID FROM LC000')
		EXEC prcDropFld 'LC000' , 'EntryGUID'
	END
  -- END GCC03

	--Segmentation
	EXECUTE [prcAddBitFld] 'mt000', 'HasSegments', 0
	EXECUTE	[prcAddGUIDFld]	'MT000',  'Parent'
	EXECUTE [prcAddBitFld]	'mt000', 'IsCompositionUpdated', 0
	EXECUTE [prcAddBitFld]	'mt000', 'InheritsParentSpecs', 0
	EXECUTE [prcAddCharFld]	'mt000', 'CompositionName', 250
	EXECUTE [prcAddCharFld]	'mt000', 'CompositionLatinName', 250
	EXECUTE [prcAddBitFld] 'bt000', 'ShowQtyTotal'
	EXECUTE [prcAddBitFld] 'bt000', 'bCollectCustAccount'
	EXECUTE [prcAddIntFld] 'bt000', 'FldComposition'

	EXEC [prcAddIntFld]  'PackingLists000', 'DisplayComposition'
	EXEC [prcAddBitFld]	 'bg000', 'IsSegmentedMaterial'
	EXEC [prcAddBitFld]	 'bg000', 'IsCodeInsteadName'
	EXEC [prcAddBitFld]	 'bgi000', 'IsCodeInsteadName'
	EXEC [prcAlterFld] 'mt000', 'Name', 'NVARCHAR(1000)'
	EXEC [prcAlterFld] 'mt000', 'Code', 'NVARCHAR(250)'
	EXEC [prcAlterFld] 'mt000', 'LatinName', 'NVARCHAR(1000)'

	EXECUTE [prcAddIntFld] 'BalSheet000', 'Security', 1
	EXECUTE [prcAddGUIDFld] 'FABalanceSheetAccount000', 'PrevClassificationGuid'
	EXECUTE [prcAlterFld] 'di000', 'Notes', 'NVARCHAR(1000)'
######################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From10009744
AS 
	EXEC('UPDATE mt000 SET ForceInClass = 0, ForceOutClass = 0  WHERE ClassFlag = 0')

	EXECUTE [prcAlterFld] 'py000', 'Notes', 'NVARCHAR(1000)'
	EXECUTE prcAddGuidFld 'Distributor000', 'UserGuid'
######################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From100091058
AS
	-- BEGIN CUST ADDRESS 01
	IF [dbo].[fnObjectExists]('cu000.DefaultAddressGUID') = 0
	BEGIN
		EXEC ('
			IF NOT EXISTS (SELECT * FROM POSInfos000 inf INNER JOIN RestConfig000 c ON inf.ConfigID = c.Guid WHERE inf.ValueIndex = 30)
				UPDATE inf SET ValueIndex = 30 FROM POSInfos000 inf INNER JOIN RestConfig000 c ON inf.ConfigID = c.Guid WHERE inf.ValueIndex = 27
			DELETE POSInfos000 FROM POSInfos000 inf INNER JOIN RestConfig000 c ON inf.ConfigID = c.Guid WHERE inf.ValueIndex = 27 ')

		EXEC prcAddGUIDFld 'cu000', 'DefaultAddressGUID'
		EXEC prcAddGUIDFld 'bu000', 'CustomerAddressGUID'
		
		EXEC ('
			DECLARE @Country TABLE(Country NVARCHAR(500))
			INSERT INTO @Country SELECT DISTINCT Country FROM cu000 

			IF ([dbo].[fnObjectExists](''RestAddress000'') = 1)
			BEGIN
				IF NOT EXISTS(SELECT * FROM @Country WHERE Country = '''') AND EXISTS(SELECT * FROM RestAddress000)
					INSERT INTO @Country SELECT ''''
			END
			INSERT INTO AddressCountry000(Number, GUID, Code, Name, LatinName)
			SELECT 
				ROW_NUMBER() OVER (ORDER BY Country), NEWID(), '''', Country, Country FROM @country

			DECLARE @City TABLE(Country NVARCHAR(500), City NVARCHAR(500), ParentGUID UNIQUEIDENTIFIER)
			INSERT INTO @City 
			SELECT DISTINCT 
				cu.Country, cu.City, aco.GUID 
			FROM 
				cu000 cu
				INNER JOIN AddressCountry000 aco ON cu.country = aco.name

			IF ([dbo].[fnObjectExists](''RestAddress000'') = 1)
			BEGIN
				INSERT INTO @City 
				SELECT DISTINCT '''', ra.City, aco.GUID 
				FROM 
					RestAddress000 ra 
					INNER JOIN AddressCountry000 aco ON aco.name = ''''
					LEFT JOIN @City c ON '''' = c.Country AND ra.City = c.City 
				WHERE c.Country IS NULL
			END
			INSERT INTO AddressCity000(Number, GUID, Code, Name, LatinName, ParentGUID)
			SELECT ROW_NUMBER() OVER (ORDER BY co.Name, ci.City), NEWID(), '''', ci.City, ci.City, ci.ParentGUID FROM 
				@City ci INNER JOIN AddressCountry000 co ON ci.ParentGUID = co.GUID

			DECLARE @Area TABLE(Country NVARCHAR(500), City NVARCHAR(500), Area NVARCHAR(500), ParentGUID UNIQUEIDENTIFIER)
			INSERT INTO @Area 
			SELECT DISTINCT 
				cu.Country, cu.City, cu.Area, aci.GUID 
			FROM 
				cu000 cu
				INNER JOIN AddressCity000 aci ON cu.city = aci.name
				INNER JOIN AddressCountry000 aco ON cu.country = aco.name and aci.ParentGUID = aco.GUID
			IF ([dbo].[fnObjectExists](''RestAddress000'') = 1)
			BEGIN
				INSERT INTO @Area 
				SELECT DISTINCT '''', ra.City, ra.Area, aci.GUID 
				FROM 
					RestAddress000 ra 
					INNER JOIN AddressCity000 aci ON ra.City = aci.name
					INNER JOIN AddressCountry000 aco ON '''' = aco.name
					LEFT JOIN @Area c ON '''' = c.Country AND ra.City = c.City AND ra.Area = c.Area
				WHERE c.Country IS NULL
			END
			INSERT INTO AddressArea000(Number, GUID, Code, Name, LatinName, ParentGUID)
			SELECT ROW_NUMBER() OVER (ORDER BY co.Name, ci.Name, ar.Area), NEWID(), '''', ar.Area, ar.Area, ar.ParentGUID FROM 
				@area ar INNER JOIN AddressCity000 ci ON ar.ParentGUID = ci.GUID
				INNER JOIN AddressCountry000 co ON ci.ParentGUID = co.GUID

			UPDATE AddressCountry000 
			SET Code = CASE WHEN Number < 10 THEN ''0'' + CAST(Number AS NVARCHAR(10)) ELSE CAST(Number AS NVARCHAR(10)) END
			
			UPDATE aci 
			SET Code =  aco.Code + (CASE WHEN t.num < 10 THEN ''0'' + CAST(t.num AS NVARCHAR(10)) ELSE CAST(t.num AS NVARCHAR(10)) END)
			FROM 
				AddressCity000 aci
				INNER JOIN AddressCountry000 aco ON aci.ParentGUID = aco.GUID
				INNER JOIN (select ci.guid as CityGUID, row_number() over(partition by co.guid order by co.number, ci.number) as num from 
					AddressCity000 ci INNER JOIN AddressCountry000 co ON ci.ParentGUID = co.GUID) t on t.CityGUID = aci.GUID	
			
			UPDATE aar 
			SET Code =  aci.Code + ( (CASE WHEN t.num < 10 THEN ''00'' ELSE (CASE WHEN t.num < 100 THEN ''0'' ELSE '''' END) END) + CAST(t.num AS NVARCHAR(10)))
			FROM
				AddressArea000 aar
				INNER JOIN AddressCity000 aci ON aar.ParentGUID = aci.GUID
				INNER JOIN (select ar.guid as AreaGUID, row_number() over(partition by ci.guid order by ci.number, ar.number) as num from 
					AddressArea000 ar INNER JOIN AddressCity000 ci ON ar.ParentGUID = ci.GUID) t on t.AreaGUID = aar.GUID	
		')

		EXEC( '
			DECLARE @CustAddress TABLE (
				Number INT,
				GUID UNIQUEIDENTIFIER,
				IsDefault BIT,
				CustGUID UNIQUEIDENTIFIER, 
				Address NVARCHAR(1000),
				Area NVARCHAR(1000),
				City NVARCHAR(1000),
				Street NVARCHAR(1000),
				Country NVARCHAR(1000),
				POBOX NVARCHAR(1000),
				ZipCode NVARCHAR(1000),
				BulidingNumber NVARCHAR(1000),
				FloorNumber NVARCHAR(1000),
				GPSX FLOAT,
				GPSY FLOAT,
				GPSZ FLOAT)

			INSERT INTO @CustAddress 
			SELECT -1, NEWID(), 1, GUID, Address, Area, City, Street, Country, POBOX, ZipCode, '''', '''', GPSX, GPSY, GPSZ
			FROM cu000 
			WHERE 
				(ISNULL(Address, '''') != '''') OR (ISNULL(Area, '''') != '''') OR
				(ISNULL(City, '''') != '''') OR (ISNULL(Street, '''') != '''') OR
				(ISNULL(Country, '''') != '''') OR (ISNULL(POBOX, '''') != '''') OR 
				(ISNULL(ZipCode, '''') != '''') OR 
				(ISNULL(GPSX, 0) != 0) OR (ISNULL(GPSY, 0) != 0) OR (ISNULL(GPSZ, 0) != 0)

			IF ([dbo].[fnObjectExists](''RestCustAddress000'') = 1)
			BEGIN
				INSERT INTO @CustAddress
				SELECT rca.Number, rca.GUID, 0, rca.CustGUID, rca.MoreDetails, ra.Area, 
					ra.City, ra.Street, '''', '''', '''', rca.Building, rca.FloorNumber, 0, 0, 0
				FROM 
					RestCustAddress000 rca
					INNER JOIN RestAddress000 ra ON rca.AddressGUID = ra.GUID

				UPDATE @CustAddress
				SET IsDefault = 0 
				FROM 
					@CustAddress ca INNER JOIN 
					(SELECT CustGUID FROM RestCustAddress000 WHERE IsDefault = 1) rca ON ca.CustGUID = rca.CustGUID
				
				UPDATE @CustAddress
				SET IsDefault = 1 
				FROM 
					@CustAddress ca 
					INNER JOIN RestCustAddress000 rca ON ca.GUID = rca.GUID
			END

			IF EXISTS (SELECT * FROM @CustAddress)
			BEGIN 
				INSERT INTO CustAddress000(Number, GUID, Name, LatinName, CustomerGUID, AreaGUID, Street,
					BulidingNumber, FloorNumber, MoreDetails, POBox, ZipCode, GPSX, GPSY, GPSZ)
				SELECT ROW_NUMBER() OVER(partition by a.CustGUID order by a.Number), a.GUID, N''الرئيسي'', N''Head Address'', 
					a.CustGUID, ISNULL(aar.GUID, 0x0), a.Street, 
					a.BulidingNumber, a.FloorNumber, a.[Address], a.POBox, a.ZipCode, a.GPSX, a.GPSY, a.GPSZ
				FROM 
					@CustAddress a 
					INNER JOIN AddressArea000 aar ON aar.Name = a.Area
					INNER JOIN AddressCity000 aci ON aci.GUID = aar.ParentGUID AND aci.Name = a.City 
					INNER JOIN AddressCountry000 aco ON aco.GUID = aci.ParentGUID AND aco.Name = a.Country
				
				UPDATE CustAddress000
				SET 
					Name = Name + '' '' + CAST(Number AS VARCHAR(10)),
					LatinName = LatinName + '' '' + CAST(Number AS VARCHAR(10))
				WHERE Number > 1

				EXEC prcDisableTriggers ''cu000'', 1
				UPDATE CU SET DefaultAddressGUID = AD.GUID 
				FROM 
					CU000 CU 
					INNER JOIN CustAddress000 AD ON CU.GUID = AD.CustomerGUID
					INNER JOIN @CustAddress CA ON CA.GUID = AD.GUID
				WHERE 
					CA.IsDefault = 1
				EXEC prcEnableTriggers ''cu000''

				EXEC prcDisableTriggers ''bu000'', 1 
				UPDATE BU 
				SET CustomerAddressGUID = ISNULL([RO].[CustomerAddressID], 0x0)
				FROM 
					BU000 BU 
					INNER JOIN [BillRel000] BR ON BU.GUID = BR.BillGUID 
					INNER JOIN RestOrder000 RO ON RO.GUID = BR.ParentGUID
				WHERE ISNULL([RO].[CustomerAddressID], 0x0) != 0x0

				EXEC prcEnableTriggers ''bu000''
			END 

			DELETE AddressArea000 WHERE GUID NOT IN (SELECT AreaGUID FROM CustAddress000)
			DELETE AddressCity000 WHERE GUID NOT IN (SELECT ParentGUID FROM AddressArea000)
			DELETE AddressCountry000 WHERE GUID NOT IN (SELECT ParentGUID FROM AddressCity000)
			')

		EXEC ('
			UPDATE AddressCountry000 SET Name = N''الافتراضي'', LatinName = N''Default'' WHERE Name = ''''
			UPDATE AddressCity000 SET Name = N''الافتراضي'', LatinName = N''Default'' WHERE Name = ''''
			UPDATE AddressArea000 SET Name = N''الافتراضي'', LatinName = N''Default'' WHERE Name = ''''
		')

		EXEC ('
			IF EXISTS(SELECT * FROM RestDriverAddress000)
			BEGIN 				
				DELETE RestDriverAddress000
				UPDATE RestVendor000 SET IsAllAddress = 1
			END 		
		')

		
	END

	EXEC prcDropTable 'RestAddress000'
	EXEC prcDropTable 'RestCustAddress000'
	EXEC prcDropTrigger 'trgRestAddress_Delete'
	EXEC prcDropProcedure 'prcRestCustAddress_Get'
	EXEC prcDropProcedure 'prcRestCustAddress_GetDefault'
	EXEC prcDropProcedure 'prcRestCustAddress_SetAsDefault'
	EXEC prcDropFld	'cu000', 'Address'
	EXEC prcDropFld	'cu000', 'GPSX'
	EXEC prcDropFld	'cu000', 'GPSY'
	EXEC prcDropFld	'cu000', 'GPSZ'
	EXEC prcDropFld	'cu000', 'Area'
	EXEC prcDropFld	'cu000', 'City'
	EXEC prcDropFld	'cu000', 'Street'
	EXEC prcDropFld	'cu000', 'Country'
	EXEC prcDropFld	'cu000', 'POBOX'
	EXEC prcDropFld	'cu000', 'ZipCode'
	EXECUTE [prcAddBitFld] 'bt000', 'ShowCustAddress'
	EXEC prcAddGUIDFld 'POSOrder000', 'CustomerAddressID'	
	EXEC prcAddGUIDFld 'POSOrderTemp000', 'CustomerAddressID'
	
	-- Edit For Android
	EXEC prcDropFld 'DistDeviceCu000','Area'
	EXEC prcDropFld 'DistDeviceCu000','Street'
	EXEC prcDropFld 'DistDeviceCu000','GPSX'
	EXEC prcDropFld 'DistDeviceCu000','GPSY'
	EXEC prcDropFld 'DistDeviceCu000','Address'
	EXEC prcDropFld 'DistDeviceCu000','ZipCode'		
	EXEC prcAddFloatFld 'DistDeviceCu000', 'CustomerDuePayments'
	EXEC prcAddGUIDFld 'DistDeviceCu000', 'DefaultAddressGUID'

	EXEC prcDropFld 'DistDeviceNewCu000','Area'
	EXEC prcDropFld 'DistDeviceNewCu000','Street'
	EXEC prcDropFld 'DistDeviceNewCu000','GPSX'
	EXEC prcDropFld 'DistDeviceNewCu000','GPSY'
	EXEC prcDropFld 'DistDeviceNewCu000','Address'
	EXEC prcDropFld 'DistDeviceNewCu000','ZipCode'
	EXEC prcAddGUIDFld 'DistDeviceNewCu000', 'DefaultAddressGUID'
	EXEC prcAddGUIDFld 'DistDevicebu000', 'CustomerAddressGUID'

	-- END CUST ADDRESS 01
	EXECUTE prcDeleteArchivingUnUsedData
######################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From100091187
AS
	IF [dbo].[fnObjectExists]('mc000.GUID') = 0
	BEGIN
		
		UPDATE [op]
			SET 
				[Value] = CAST([o].[Val] AS VARCHAR(10))
			FROM 
				FileOP000 [op] INNER JOIN 
				(SELECT [GUID], ROW_NUMBER() OVER(ORDER BY(CAST([Value] AS INT))) AS [Val]
				FROM FileOP000
				WHERE [Name] LIKE 'AmnPOS_%Index') o ON o.GUID = op.GUID 
		-- For replication every table must have ROWGUIDCOL property
		EXEC [prcAddFld] 'mc000',  'GUID', '[UNIQUEIDENTIFIER]  ROWGUIDCOL DEFAULT(NEWID())'
		EXEC [prcAddFld] 'gri000',  'GUID', '[UNIQUEIDENTIFIER]  ROWGUIDCOL DEFAULT(NEWID())'
		EXEC [prcAddFld] 'CustomizePrint000',  'GUID', '[UNIQUEIDENTIFIER]  ROWGUIDCOL DEFAULT(NEWID())'
		EXEC [prcAddFld] 'sti000',  'GUID', '[UNIQUEIDENTIFIER]  ROWGUIDCOL DEFAULT(NEWID())'
		EXEC [prcAddFld] 'MaterialSegmentElements000',  'Id', '[UNIQUEIDENTIFIER]  ROWGUIDCOL DEFAULT(NEWID())'
		EXEC [prcAddFld] 'GroupSegmentElements000',  'Id', '[UNIQUEIDENTIFIER]  ROWGUIDCOL DEFAULT(NEWID())'
		EXEC [prcAddFld] 'MaterialsSegmentsManagement000',  'Id', '[UNIQUEIDENTIFIER]  ROWGUIDCOL DEFAULT(NEWID())'

		EXEC('
			UPDATE mc000 SET GUID = NEWID() WHERE ISNULL(GUID, 0x0) = 0x0
			UPDATE gri000 SET GUID = NEWID() WHERE ISNULL(GUID, 0x0) = 0x0
			UPDATE CustomizePrint000 SET GUID = NEWID() WHERE ISNULL(GUID, 0x0) = 0x0
			UPDATE sti000 SET GUID = NEWID() WHERE ISNULL(GUID, 0x0) = 0x0
			UPDATE MaterialSegmentElements000 SET Id = NEWID() WHERE ISNULL(Id, 0x0) = 0x0
			UPDATE GroupSegmentElements000 SET Id = NEWID() WHERE ISNULL(Id, 0x0) = 0x0
			UPDATE MaterialsSegmentsManagement000 SET Id = NEWID() WHERE ISNULL(Id, 0x0) = 0x0');
		-- END For replication 
	END
	
	EXECUTE prcAddFloatFld 'RestOrderItemTemp000', 'ChangedQty'
	EXECUTE prcAddFloatFld 'RestOrderItem000', 'ChangedQty'
	EXECUTE prcAddFloatFld 'RestDeletedOrderItems000', 'ChangedQty'
	EXECUTE prcAddINTFld 'PSI000', 'Number'

	EXECUTE prcAddIntFld 'POSOrderItemsTemp000', 'SOGroup'
	EXECUTE prcAddIntFld 'POSOrderItems000', 'SOGroup'
	EXECUTE prcAddBitFld 'SpecialOffer000', 'IsIncludeGroups'
	EXECUTE prcAddIntFld 'OfferedItems000', 'PriceKind'

	 --Update Archiving Bill Security
	UPDATE ui 
	SET  ui.ReportId = 20480
	FROM ui000 ui
	INNER JOIN bt000 bt ON bt.GUID  = ui.SubId 
	WHERE 
	ReportId = 268627968 
	AND bt.Type <> 5
	AND bt.Type <> 6 
	
	-- Update Archiving Order Security
	UPDATE ui 
	SET  ui.ReportId = 20497
	FROM ui000 ui
	INNER JOIN bt000 bt ON bt.GUID  = ui.SubId 
	WHERE 
	ReportId = 268627968 
	AND (bt.Type <> 5 OR bt.Type <> 6 )
	
	-- Update Archiving Entry Security
	UPDATE ui 
	SET  ui.ReportId = 20481
	FROM ui000 ui
	INNER JOIN et000 et ON et.GUID  = ui.SubId 
	WHERE 
	ReportId = 268627968 
	
	-- Update Archiving Entry Security
	UPDATE ui 
	SET  ui.ReportId = 20482
	FROM ui000 ui
	INNER JOIN nt000 nt ON nt.GUID  = ui.SubId 
	WHERE 
	ReportId = 268627968 
	
	-- Update Archiving Customer Security
	UPDATE ui000 
	SET ReportId = 20483
	WHERE ReportId = 268533760 AND SubId = '2ADD5BD5-600B-4DCA-8278-C31116E20D29'
	
	-- Update Archiving Materials Security
	UPDATE ui000 
	SET ReportId = 20484
	WHERE ReportId = 268537856 AND SubId = 'A6CB57C2-5E18-42FA-AC6F-6252D8CD3AA5'
	
	-- Update Archiving Account Security
	UPDATE ui000 
	SET ReportId = 20485
	WHERE ReportId = 268529664 AND SubId = 'D77B0526-D4F1-4638-A0B6-7FCD923D0878'
	
	-- Update Archiving Cost Center Security
	UPDATE ui000 
	SET ReportId = 20486
	WHERE ReportId = 268546048 AND SubId = '6CB2DDFE-3851-40C5-9048-667612BA6B8A'
	
	-- Update Archiving Form Security
	UPDATE ui000 
	SET ReportId = 20488
	WHERE ReportId = 536879232 AND SubId = '273E69ED-3DA8-4D4D-A5E1-F87F9558C923'
	
	-- Update Archiving Manufacturing Process Security
	UPDATE ui000 
	SET ReportId = 20487
	WHERE ReportId = 536879168 AND SubId = '8050191A-418C-4939-9ED8-2A32C215E1D1'
	
	-- Update Archiving Production Plan Security
	UPDATE ui000 
	SET ReportId = 20489
	WHERE ReportId = 536879424 AND SubId = '00E8C7F5-FF28-4F03-B066-C3AC66869D40'

	-- old pos special offers 
	EXEC prcDropView 'vwPOSOrderItemsTempWithOutCanceledGroupedOnQty'
	EXEC prcDropView 'vwSpecialOfferDetailUnits'
	EXEC prcDropView 'vwSpecialOfferDetail'
	EXEC prcDropView 'vwOrderItemGroup'
	EXEC prcDropView 'vwMatOfferDetails'
	EXEC prcDropView 'vwGroupOfferDetails'
	EXEC prcDropView 'vwGroupOfferDetails'

	EXEC prcDropFunction 'fnGetSqlCheckCusts'
	EXEC prcDropFunction 'fnPOSGetOrderOfferedItem'
	EXEC prcDropFunction 'fnPOSGetOrderOfferedWhole'
	EXEC prcDropFunction 'fnPOSGetOrderOfferedMatItem'
	EXEC prcDropFunction 'fnPOSGetOrderOfferedMatItem'

	EXEC prcDropProcedure 'prcApplySpecialOfferOnMat'
	EXEC prcDropProcedure 'prcApplySpecialOfferOnMixedItem'
	EXEC prcDropProcedure 'prcApplySpecialOfferQuntityOnMixedItem'
	EXEC prcDropProcedure 'prcApplySpecialOfferOnGroupMixedItem'

	IF (SELECT COLUMNPROPERTY( OBJECT_ID('Segments000'),'Id','IsRowGuidCol') as RowGuid) = 0
		EXEC('ALTER TABLE Segments000 ALTER COLUMN Id ADD ROWGUIDCOL;')

	IF (SELECT COLUMNPROPERTY( OBJECT_ID('MaterialElements000'),'Id','IsRowGuidCol') as RowGuid) = 0
		EXEC('ALTER TABLE MaterialElements000  ALTER COLUMN Id ADD ROWGUIDCOL;')

	IF (SELECT COLUMNPROPERTY( OBJECT_ID('MaterialSegments000'),'Id','IsRowGuidCol') as RowGuid) = 0
		EXEC('ALTER TABLE MaterialSegments000  ALTER COLUMN Id ADD ROWGUIDCOL;')

	IF (SELECT COLUMNPROPERTY( OBJECT_ID('GroupSegments000'),'Id','IsRowGuidCol') as RowGuid) = 0
		EXEC('ALTER TABLE GroupSegments000  ALTER COLUMN Id ADD ROWGUIDCOL;')

	IF (SELECT COLUMNPROPERTY( OBJECT_ID('SegmentElements000'),'Id','IsRowGuidCol') as RowGuid) = 0
		EXEC('ALTER TABLE SegmentElements000 ALTER COLUMN Id ADD ROWGUIDCOL;')

	IF (SELECT COLUMNPROPERTY( OBJECT_ID('RichDocument000'),'Id','IsRowGuidCol') as RowGuid) = 0
		EXEC('ALTER TABLE RichDocument000 ALTER COLUMN Id ADD ROWGUIDCOL;')

	IF (SELECT COLUMNPROPERTY( OBJECT_ID('RichDocumentCalculatedField000'),'Id','IsRowGuidCol') as RowGuid) = 0
		EXEC('ALTER TABLE RichDocumentCalculatedField000 ALTER COLUMN Id ADD ROWGUIDCOL;')
	
	IF [dbo].[fnObjectExists]('bi000.IsPOSSpecialOffer') = 0
	BEGIN
		EXEC('UPDATE PSI000
		SET Number=code WHERE Number=0');
	END

	EXECUTE [prcAddBitFld] 'bi000', 'IsPOSSpecialOffer', 0
	EXECUTE [prcAlterFld] 'py000', 'Notes', 'NVARCHAR(1000)'
######################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From100091324
AS
	--CMPT05 BEGIN	
	EXEC PrcAddBitFld 'co000', 'IsHiddenInSearch', 0
	EXEC prcAddFloatFld 'bg000', 'BColor'
	EXEC prcAddFloatFld 'bg000', 'FColor'
	EXEC prcAddBitFld   'bg000', 'IsThemeColors'

	IF [dbo].[fnObjectExists]('RestVendor000.VnPassword') =  0
		EXEC('UPDATE bg000 SET IsThemeColors = 1')

	EXEC prcAddCharFld 'RestVendor000', 'VnPassword', 250

	EXEC('UPDATE FA 
		SET [Value] = ( CASE [Value] 
				WHEN 775			THEN 0
				WHEN 641			THEN 1
				WHEN 642			THEN 2
				WHEN 480			THEN 3
				WHEN 845			THEN 4
				WHEN 846			THEN 5
				WHEN 753			THEN 6
				WHEN 757			THEN 7
				WHEN 754			THEN 8
				WHEN 756			THEN 9
				WHEN 755			THEN 10
				WHEN 970			THEN 11
				WHEN 813			THEN 12
				WHEN 1423			THEN 13
				WHEN 1424			THEN 14
				WHEN 1425			THEN 15
				WHEN 1426			THEN 16
				WHEN 1286			THEN 18
				WHEN 1287			THEN 19
				WHEN 1132			THEN 1024
				WHEN 1133			THEN 2024
				WHEN 1134			THEN 3024
				WHEN 1139			THEN 1025
				WHEN 1140			THEN 2025
				WHEN 1141			THEN 3025
				WHEN 11429			THEN 26
				WHEN 548			THEN 1026
				WHEN 1428			THEN 2026
				WHEN 1429			THEN 3026
				WHEN 1095			THEN 27
				WHEN (1095 + 10000) THEN 1027
				WHEN (1095 + 11000) THEN 2027
				WHEN (1095 + 12000) THEN 3027
				WHEN 1096			THEN 28
				WHEN (1096 + 10000) THEN 1028
				WHEN (1096 + 11000) THEN 2028
				WHEN (1096 + 12000) THEN 3028
				WHEN 1097			THEN 29
				WHEN (1097 + 10000) THEN 1029
				WHEN (1097 + 11000) THEN 2029
				WHEN (1097 + 12000) THEN 3029
				WHEN 1099			THEN 30
				WHEN (1099 + 10000) THEN 1030
				WHEN (1099 + 11000) THEN 2030
				WHEN (1099 + 12000) THEN 3030
				WHEN 1098			THEN 31
				WHEN (1098 + 10000) THEN 1031
				WHEN (1098 + 11000) THEN 2031
				WHEN (1098 + 12000) THEN 3031
				WHEN 1100			THEN 32
				WHEN (1100 + 10000) THEN 1032
				WHEN (1100 + 11000) THEN 2032
				WHEN (1100 + 12000) THEN 3032
				WHEN 229			THEN 33
				WHEN 230			THEN 34
				WHEN 500			THEN 35
				WHEN 501			THEN 36
				WHEN 502			THEN 37
				WHEN 503			THEN 38
				WHEN 504			THEN 39
				WHEN 505			THEN 40
				WHEN 506			THEN 41
				WHEN 507			THEN 42
				WHEN 508			THEN 43
				ELSE [Value]
              END )
	FROM fa000 AS FA
	JOIN df000 DF ON FA.ParentGUID = DF.GUID
	WHERE FA.[type] = 2 AND DF.Type = 301')

	EXEC PrcAddBitFld 'bt000', 'bCostToTaxAcc', 0
	EXEC PrcAddBitFld 'et000', 'bCostToTaxAcc', 0
	EXECUTE	[prcAddGUIDFld]	'di000',  'CustomerGUID'
	EXEC ('
		IF	EXISTS (SELECT * FROM op000 WHERE [Name] = ''AmnCfg_AllowManyCustForAcc'' AND [Value] = ''1'')
			OR 
			EXISTS (	
				SELECT 
					*
				FROM 
					[ac000] ac
				WHERE (SELECT COUNT(*) AS Cnt FROM cu000 WHERE AccountGUID = ac.GUID) > 1
			)
			OR
			EXISTS (
				SELECT * 
				FROM 
					en000 en
					INNER JOIN ac000 ac ON ac.GUID = en.AccountGUID 
					INNER JOIN cu000 cu ON cu.GUID = en.CustomerGUID 
					INNER JOIN ce000 ce ON ce.GUID = en.ParentGUID
					LEFT JOIN er000 er ON ce.GUID = er.EntryGUID 
					LEFT JOIN bu000 bu ON bu.GUID = er.ParentGUID 			
				WHERE 
					(cu.AccountGUID != ac.GUID)	
					AND 
					((bu.GUID IS NULL) OR ((bu.GUID IS NOT NULL) AND ((bu.PayType != 0) OR (ac.GUID != bu.CustAccGUID)))))
		BEGIN 
			IF NOT EXISTS (SELECT * FROM op000 WHERE [Name] = ''AmnCfg_EnableMultiCustomersSystem'' AND [Value] = ''1'')
			BEGIN
				DELETE op000 WHERE [Name] = ''AmnCfg_EnableMultiCustomersSystem''

				INSERT INTO op000([GUID], Name, Value, [Type])
				SELECT NEWID(), ''AmnCfg_EnableMultiCustomersSystem'', ''1'', 0
			END
			
			DELETE op000 WHERE [Name] = ''AmnCfg_AllowManyCustForAcc''
		END ')

	IF [dbo].[fnObjectExists]('POSResetDrawerItem000.CashAccID') =  0
	BEGIN
		DECLARE @CashAccID UNIQUEIDENTIFIER
		DECLARE @ResetAccID UNIQUEIDENTIFIER
		DECLARE @UserID UNIQUEIDENTIFIER
		DECLARE @c CURSOR
		SET @c = CURSOR FAST_FORWARD FOR 
		SELECT DISTINCT UserID FROM UserOp000 WHERE Name = 'AmnPOS_DrawerID'
		OPEN @c FETCH FROM @c INTO @UserID
		WHILE @@FETCH_STATUS = 0
		BEGIN
			SELECT @CashAccID = CAST(Value AS UNIQUEIDENTIFIER) FROM UserOp000 WHERE Name = 'AmnPOS_DrawerID' AND UserID = @UserID
			SELECT @ResetAccID = CAST(Value AS UNIQUEIDENTIFIER) FROM UserOp000 WHERE Name = 'AmnPOS_ZeroCashAccID' AND UserID = @UserID

			INSERT INTO POSCurrencyItem000 ([GUID], [Number], [CurID], [Used], [UserID], [CashAccID], [ResetAccID])
			SELECT newid(), [Number], [GUID], 1, @UserID, @CashAccID, @ResetAccID FROM my000 my
			FETCH FROM @c INTO @UserID
		END
		CLOSE @c DEALLOCATE @c
	END

	EXECUTE prcDropFld	  'POSResetDrawer000', 'DrawerID'
	EXECUTE prcAddGUIDFld 'POSResetDrawerItem000', 'CashAccID'
	EXECUTE prcAddGUIDFld 'POSResetDrawerItem000', 'ResetAccID'
		
	EXEC prcAddDateFld	 'RestOrderTemp000', 'DeliveringTime'
	EXEC prcAddFloatFld  'RestOrderTemp000', 'DeliveringFees'
	EXEC prcAddDateFld	'RestOrder000', 'DeliveringTime'
	EXEC prcAddFloatFld	'RestOrder000', 'DeliveringFees'
	EXEC prcAddDateFld	'RestDeletedOrders000', 'DeliveringTime'
	EXEC prcAddFloatFld	'RestDeletedOrders000', 'DeliveringFees'

	EXECUTE PrcAddBitFld  'RestVendor000', 'IsInactive', 0

	IF EXISTS (SELECT * FROM GCCTaxCoding000)
	BEGIN 
		IF NOT EXISTS (SELECT * FROM GCCTaxCoding000 WHERE TaxCode = 15)
			INSERT INTO GCCTaxCoding000 (Number, GUID, Code, Name, LatinName, TaxType, TaxCode, TaxRatio)
			SELECT 10, NEWID(), N'GV', N' أعضاء المجموعة الضريبية', N'Members of the tax group', 1, 15, 0

		IF NOT EXISTS (SELECT * FROM GCCTaxCoding000 WHERE TaxCode = 16)
			INSERT INTO GCCTaxCoding000 (Number, GUID, Code, Name, LatinName, TaxType, TaxCode, TaxRatio)
			SELECT 11, NEWID(), N'TR', N' السياحة', N'Tourism', 1, 16, 0
	END

	EXEC PrcAddBitFld	'RestTaxes000', 'IsDiscountClc', 1
	EXEC PrcAddBitFld	'RestTaxes000', 'IsAddClc', 1
	EXEC PrcAddBitFld	'RestTaxes000', 'IsApplayOnPrevTaxes', 0

	EXEC PrcAddBitFld	'RestDiscTaxTemp000', 'IsDiscountClc', 1
	EXEC PrcAddBitFld	'RestDiscTaxTemp000', 'IsAddClc', 1
	EXEC PrcAddBitFld	'RestDiscTaxTemp000', 'IsApplayOnPrevTaxes', 0

	EXEC PrcAddBitFld	'RestDiscTax000', 'IsDiscountClc', 1
	EXEC PrcAddBitFld	'RestDiscTax000', 'IsAddClc', 1
	
	IF [dbo].[fnObjectExists]('RestDiscTax000.IsApplayOnPrevTaxes') =  0
	BEGIN
		EXEC PrcAddBitFld	'RestDiscTax000', 'IsApplayOnPrevTaxes', 0
		
		DECLARE @TaxesCalcMethod  BIT		
		SELECT @TaxesCalcMethod = ISNULL(VALUE, 0)
		FROM   FileOP000
		WHERE  NAME = 'AmnRest_TaxesCalcMethod'

		IF(@TaxesCalcMethod = 0)
		BEGIN
		EXEC('
				UPDATE RestTaxes000
				SET IsDiscountClc = 0, IsAddClc = 0, IsApplayOnPrevTaxes = 0

				UPDATE RestDiscTax000 
				SET IsDiscountClc = 0, IsAddClc = 0, IsApplayOnPrevTaxes = 0

				UPDATE RestDiscTaxTemp000
				SET IsDiscountClc = 0, IsAddClc = 0, IsApplayOnPrevTaxes = 0
			')
		END

		EXEC('
		DECLARE
			@RID_BILL [INT],
			@RID_MANUFACTURE [INT],
			@manufacBillGuid [uniqueidentifier];

		SET @RID_BILL = 0x10010000
		SET @RID_MANUFACTURE = 0x20002040

		-- Build security for manufacturing (duplicate out security to in security)
		SELECT @manufacBillGuid = [GUID] FROM [BT000] WHERE [Type] = 2 AND [SortNum] = 6
		IF @manufacBillGuid is not null 
		BEGIN 
			delete [ui000] where [reportID] = @RID_BILL and [subID] = @manufacBillGuid
			insert into [ui000] ([userGuid], [reportID], [subID], [System], [permType], [permission]) 
				select [UserGUID], @RID_BILL, @manufacBillGuid, [System], [Permtype], [Permission] from [UI000] where [reportID] = @RID_MANUFACTURE
			SELECT @manufacBillGuid = [GUID] FROM [BT000] WHERE [Type] = 2 AND [SortNum] = 5
			delete [ui000] where [reportID] = @RID_BILL and [subID] = @manufacBillGuid
			insert into [ui000] ([userGuid], [reportID], [subID], [System], [permType], [permission])  
				select [UserGUID], @RID_BILL , @manufacBillGuid, [System], [Permtype], [Permission] from [UI000] where [reportID] = @RID_MANUFACTURE
		END ');
		
	END
	-- END CMPT05
######################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From100091373 
AS

	EXECUTE [prcAlterFld] 'di000', 'Notes', 'NVARCHAR(1000)';
	EXECUTE [prcAddIntFld] 'Allocations000','Number'
	IF [dbo].[fnObjectExists]('DistDeviceCustAddress000.AddressGUID') =  0
	BEGIN 
		EXECUTE [prcAddGUIDFld] 'DistDeviceCustAddress000', 'AddressGUID'
		EXEC('UPDATE DistDeviceCustAddress000 SET AddressGUID = GUID');
		EXEC('UPDATE DistDeviceCustAddress000 SET GUID = NEWID() WHERE GUID = AddressGUID');
	END 

	IF [dbo].[fnObjectExists]('DistDeviceCustAddressWorkingDays000.AmenWorkingAddressGUID') =  0
	BEGIN 
		EXECUTE [prcAddGUIDFld] 'DistDeviceCustAddressWorkingDays000', 'AmenWorkingAddressGUID'
		EXEC('UPDATE DistDeviceCustAddressWorkingDays000 SET AmenWorkingAddressGUID = GUID');
		EXEC('UPDATE DistDeviceCustAddressWorkingDays000 SET GUID = NEWID() WHERE GUID = AmenWorkingAddressGUID');

		
	END 
######################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From100091473
AS

	IF [dbo].[fnObjectExists]('bi000.UnitCostPrice') =  0
	BEGIN
		EXEC prcAddFloatFld	'bi000', 'UnitCostPrice'
		IF NOT EXISTS(SELECT * FROM mc000 WHERE Number = 1026 AND Asc1 = 'Bill_Repost' AND Num1 = 1)
		BEGIN
			INSERT INTO mc000(Number, Asc1, Num1) VALUES (1026, 'Bill_Repost', 1)
		END
	END
	EXEC prcDropProcedure 'repBuProfitsWithCost'
	EXEC prcDropProcedure 'repBuProfitsNoCost'

	-- POSSD 2
	IF (OBJECT_ID(N'POS_DELETE') IS NOT NULL)
	BEGIN
	      DROP TRIGGER POS_DELETE;
	END;

	IF OBJECT_ID('dbo.POSSDCrossSaleMaterial000') IS NOT NULL 
		DROP TABLE POSSDCrossSaleMaterial000; 
	
	IF [dbo].[fnObjectExists]('gr000.PictureGUID') =  0
	BEGIN
		EXEC prcAddGUIDFld	 'gr000', 'PictureGUID'
		UPDATE ui000 SET ReportId = ReportId + 1 WHERE ReportId BETWEEN 5396 AND 5400
		UPDATE uix SET ReportId = ReportId + 1 WHERE ReportID BETWEEN 5396 AND 5400
	END
	
	EXEC prcAddGUIDFld	 'POSCard000', 'DefaultGroup'
	EXEC prcAddIntFld	 'POSCard000', 'DataTransferMode'
	EXEC prcAddFld		 'POSRelatedGroups000', 'Number', 'INT'
    EXEC [prcAddGUIDFld] 'POSCard000', 'CentralAccGUID';
    EXEC [prcAddGUIDFld] 'POSCard000', 'DebitAccGUID';
    EXEC [prcAddGUIDFld] 'POSCard000', 'CreditAccGUID';
    EXEC [prcAddGUIDFld] 'POSCard000', 'ExpenseAccGUID';
    EXEC [prcAddGUIDFld] 'POSCard000', 'IncomeAccGUID';
	EXEC [prcAddBitFld]  'POSCard000', 'AllowDebitAcc';
	EXEC prcAddIntFld	 'POSSDMaterialExtended000', 'Type';

	EXEC prcAddGUIDFld	 'my000', 'PictureGUID'
	EXEC [prcAddBitFld]  'POSEmployee000', 'ReturnByForeignCurrency';

    EXEC prcAddIntFld	 'POSTicket000', 'Type';
	EXEC prcAddCharFld 'POSTicket000', 'Code' , 250
	EXEC prcAddBitFld  'POSEmployee000', 'IsWorking';
	EXEC prcAddBitFld  'POSEmployee000', 'CanChangeForeignCurrencyVal';
	EXEC prcAddIntFld  'POSSDTicketBank000', 'CheckNumber'

	IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS 
				where CONSTRAINT_TYPE='UNIQUE' AND CONSTRAINT_NAME ='UQ_POSTicket_Number_ShiftGuid')
	BEGIN
		ALTER TABLE POSTicket000 DROP CONSTRAINT UQ_POSTicket_Number_ShiftGuid
		ALTER TABLE POSTicket000 ADD CONSTRAINT UQ_POSTicket_Number_ShiftGuid_Type UNIQUE NONCLUSTERED (Number, ShiftGuid, Type)
	END

	EXEC prcAddGuidFld 'POSSDRelatedPrintDesign000','BillTypeGUID'
	EXEC prcAddBitFld  'POSSDRelatedPrintDesign000','AskBeforePrinting'
	EXEC prcAddCharFld 'POSCard000', 'Address', 250
	EXEC prcAddGUIDFld 'POSCard000', 'LocationPictureGUID'

	EXEC prcAddGUIDFld 'POSExternalOperations000', 'CurrencyGUID'
	EXEC prcAddFloatFld 'POSExternalOperations000', 'CurrencyValue'
	
	EXEC prcAddFloatFld 'POSSDShiftCashCurrency000', 'CountedCash'
	EXEC prcDropFld	    'POSShift000'    , 'State'
	EXEC prcDropFld	    'POSShift000'    , 'Matching'
	EXEC prcDropFld	    'POSShift000'    , 'ShiftControlAccBal'
	EXEC prcDropFld	    'POSShift000'    , 'CountedCash'
	EXEC prcDropFld	    'POSShift000'    , 'FloatCash'
	EXEC prcDropFld	    'POSShift000'    , 'WithdrawnCash'
	EXEC prcDropFld	    'POSShift000'    , 'OpeningCash'
	EXEC prcAddCharFld 'POSSDPrintDesignSectionItem000', 'Style', 1000
	EXECUTE [prcAlterFld] 'POSSDPrintDesignSectionItem000', 'Style', 'NVARCHAR(1000)'
	EXEC prcAddBitFld  'POSEmployee000', 'UseCurrenciesInExternalOperations'

	EXEC prcDropFld	    'POSSDTicketBank000'    , 'CheckNumber'
	EXEC prcAddCharFld 'POSSDTicketBank000', 'CheckNumber', 32

	exec ('
	
	EXEC [prcRenameFld] ''POSSDShiftCashCurrency000'', ''ContinuesCash'', ''FloatCash''
	EXEC [prcRenameFld] ''POSSDShiftCashCurrency000'', ''ContinuesCashCurVal'', ''FloatCashCurVal''

	EXEC [prcRenameFld] ''POSSDPrintDesignSection000'', ''ParentGuid'', ''ParentGUID''
	EXEC [prcRenameFld] ''POSSDPrintDesignSectionItem000'', ''ParentGuid'',  ''ParentGUID''
	

	IF (dbo.fnTblExists(''POSCard000'') <> 0) AND (NOT EXISTS(SELECT * FROM POSSDStation000))
	BEGIN 
		INSERT INTO [dbo].[POSSDStation000]
           ([Number]
           ,[GUID]
           ,[Code]
           ,[Name]
           ,[LatinName]
           ,[Security]
           ,[ShiftControlGUID]
           ,[ContinuesCashGUID]
           ,[CentralAccGUID]
           ,[DebitAccGUID]
           ,[CreditAccGUID]
           ,[ExpenseAccGUID]
           ,[IncomeAccGUID]
           ,[PurchaseBillTypeGUID]
           ,[PurchaseReturnBillTypeGUID]
           ,[SaleBillTypeGUID]
           ,[SaleReturnBillTypeGUID]
           ,[PriceType]
           ,[PaymentMethods]
           ,[DefaultGroupGUID]
           ,[DataTransferMode]
           ,[AllowDebitAcc]
           ,[Address]
           ,[LocationPictureGUID])
		SELECT
			[Number]
           ,[GUID]
           ,[Code]
           ,[Name]
           ,[LatineName]
           ,[Security]
           ,[ShiftControl]
           ,[ContinuesCash]
           ,[CentralAccGUID]
           ,[DebitAccGUID]
           ,[CreditAccGUID]
           ,[ExpenseAccGUID]
           ,[IncomeAccGUID]
           ,[PurchaseBillType]
           ,[PurchaseReturnBillType]
           ,[SaleBillType]
           ,[SaleReturnBillType]
           ,[PriceType]
           ,[PaymentMethods]
           ,[DefaultGroup]
           ,[DataTransferMode]
           ,[AllowDebitAcc]
           ,[Address]
           ,[LocationPictureGUID]
		FROM 
			POSCard000 
	END

	IF (dbo.fnTblExists(''POSShift000'') <> 0) AND (NOT EXISTS(SELECT * FROM POSSDShift000))
	BEGIN 
	INSERT INTO [dbo].[POSSDShift000]
			   ([Number]
			   ,[GUID]
			   ,[StationGUID]
			   ,[Code]
			   ,[CloseShiftNote]
			   ,[EmployeeGUID]
			   ,[OpenDate]
			   ,[CloseDate]
			   ,[OpenShiftNote])
			SELECT
				[Number],
				[Guid],
				[POSGuid],
				[Code],
				[CloseShiftNote],
				[EmployeeId],
				[OpenDate],
				[CloseDate],
				[OpenShiftNote]
			FROM 
				POSShift000 
	END

	IF (dbo.fnTblExists(''POSShiftDetails000'') <> 0) AND (NOT EXISTS(SELECT * FROM POSSDShiftDetail000))
	BEGIN 
	INSERT INTO [dbo].[POSSDShiftDetail000]
			   ([GUID]
			   ,[ShiftGUID]
			   ,[EmployeeGUID]
			   ,[DeviceID]
			   ,[EntryDate])
			SELECT
				[Guid],
				[ShiftGuid],
				[POSUser],
				[DeviceID],
				[EntryDate]
			FROM 
				POSShiftDetails000 
	END

	IF (dbo.fnTblExists(''POSTicket000'') <> 0) AND (NOT EXISTS(SELECT * FROM POSSDTicket000))
	BEGIN 
	INSERT INTO [dbo].[POSSDTicket000]
			   ([GUID]
			   ,[Number]
			   ,[ShiftGUID]
			   ,[CustomerGUID]
			   ,[DiscValue]
			   ,[AddedValue]
			   ,[Total]
			   ,[State]
			   ,[OpenDate]
			   ,[PaymentDate]
			   ,[CollectedValue]
			   ,[LaterValue]
			   ,[IsDiscountPercentage]
			   ,[IsAdditionPercentage]
			   ,[Net]
			   ,[TaxTotal]
			   ,[Note]
			   ,[Type]
			   ,[Code])
			SELECT
				[Guid],
				[Number],
				[ShiftGuid],
				[CustomerGuid],
				[DiscValue],
				[AddedValue],
				[Total],
				[State],
				[OpenDate],
				[PaymentDate],
				[CollectedValue],
				[LaterValue],
				[IsDiscountPercentage],
				[IsAdditionPercentage],
				[Net],
				[TaxTotal],
				[Note],
				[Type],
				[Code]
			FROM 
				POSTicket000 
	END

	IF (dbo.fnTblExists(''POSRelatedGroups000'') <> 0) AND (NOT EXISTS(SELECT * FROM POSSDStationGroup000))
	BEGIN 
	INSERT INTO [dbo].[POSSDStationGroup000]
			   ([GUID]
			   ,[GroupGUID]
			   ,[StationGUID]
			   ,[Number])
			SELECT
				[Guid],
				[GroupGuid],
				[POSGuid],
				[Number]
			FROM 
				POSRelatedGroups000 
	END

	IF (dbo.fnTblExists(''POSTicketItem000'') <> 0) AND (NOT EXISTS(SELECT * FROM POSSDTicketItem000))
	BEGIN 
	INSERT INTO [dbo].[POSSDTicketItem000]
			   ([GUID]
			   ,[Number]
			   ,[TicketGUID]
			   ,[MatGUID]
			   ,[Qty]
			   ,[Price]
			   ,[Value]
			   ,[Unit]
			   ,[DiscountValue]
			   ,[ItemShareOfTotalDiscount]
			   ,[IsDiscountPercentage]
			   ,[AdditionValue]
			   ,[ItemShareOfTotalAddition]
			   ,[IsAdditionPercentage]
			   ,[PriceType]
			   ,[IsManualPrice]
			   ,[UnitType]
			   ,[PresentQty]
			   ,[Tax]
			   ,[TaxRatio])
			SELECT
				[Guid]
			   ,[Number]
			   ,[TicketGuid]
			   ,[MatGuid]
			   ,[Qty]
			   ,[Price]
			   ,[Value]
			   ,[Unit]
			   ,[DiscountValue]
			   ,[ItemShareOfTotalDiscount]
			   ,[IsDiscountPercentage]
			   ,[AdditionValue]
			   ,[ItemShareOfTotalAddition]
			   ,[IsAdditionPercentage]
			   ,[PriceType]
			   ,[IsManualPrice]
			   ,[UnitType]
			   ,[PresentQty]
			   ,[Tax]
			   ,[TaxRatio]
			FROM 
				POSTicketItem000 
	END

	IF (dbo.fnTblExists(''POSEmployee000'') <> 0) AND (NOT EXISTS(SELECT * FROM POSSDEmployee000))
	BEGIN 
	INSERT INTO [dbo].[POSSDEmployee000]
			   ([Number],
				[GUID],
				[Name],
				[LatinName],
				[Password],
				[ExtraAccountGUID],
				[MinusAccountGUID],
				[CanChangeTicketPrice],
				[Mobile],
				[Email],
				[Address],
				[Department],
				[Security],
				[IsReturnByForeignCurrency],
				[IsWorking],
				[CanChangeForeignCurrencyVal],
				[UseCurrenciesInExternalOperations])
			SELECT
				[Number],
				[Guid],
				[Name],
				[LatinName],
				[Password],
				[ExtraAccount],
				[MinusAccount],
				[ChangeTicketPrice],
				[Mobile],
				[Email],
				[Address],
				[Department],
				[Security],
				[ReturnByForeignCurrency],
				[IsWorking],
				[CanChangeForeignCurrencyVal],
				[UseCurrenciesInExternalOperations]

			FROM 
				POSEmployee000 
	END

	IF (dbo.fnTblExists(''POSCardDevice000'') <> 0) AND (NOT EXISTS(SELECT * FROM POSSDStationDevice000))
	BEGIN 
	INSERT INTO [dbo].[POSSDStationDevice000]
			   ([Number],
				[GUID],
				[StationGUID],
				[DeviceID],
				[DeviceIP])
			SELECT
				[Number],
				[Guid],
				[POSCardGuid],
				[DeviceID],
				[DeviceIP]

			FROM 
				POSCardDevice000 
	END

	IF (dbo.fnTblExists(''POSRelatedEmployees000'') <> 0) AND (NOT EXISTS(SELECT * FROM POSSDStationEmployee000))
	BEGIN 
	INSERT INTO [dbo].[POSSDStationEmployee000]
			   ([GUID],
				[EmployeeGUID],
				[StationGUID])
			SELECT
				[Guid],
				[EmployeeGuid],
				[POSGuid]
			FROM 
				POSRelatedEmployees000 
	END

	IF (dbo.fnTblExists(''POSExternalOperations000'') <> 0) AND (NOT EXISTS(SELECT * FROM POSSDExternalOperation000))
	BEGIN 
	INSERT INTO [dbo].[POSSDExternalOperation000]
			   ([GUID],
				[Number],
				[ShiftGUID],
				[DebitAccountGUID],
				[CreditAccountGUID],
				[Amount],
				[Date],
				[Note],
				[State],
				[IsPayment],
				[Type],
				[GenerateState],
				[CurrencyGUID],
				[CurrencyValue])
			SELECT
				[Guid],
				[Number],
				[ShiftGuid],
				[DebitAccount],
				[CreditAccount],
				[Amount],
				[Date],
				[Note],
				[State],
				[IsPayment],
				[Type],
				[GenerateState],
				[CurrencyGUID],
				[CurrencyValue]
			FROM 
				POSExternalOperations000 
	END

	IF (dbo.fnTblExists(''POSSDRelatedCurrencies000'') <> 0) AND (NOT EXISTS(SELECT * FROM POSSDStationCurrency000))
	BEGIN 
	INSERT INTO [dbo].[POSSDStationCurrency000]
			   ([GUID],
				[StationGUID],
				[CurrencyGUID],
				[IsUsed],
				[CentralBoxAccGUID],
				[FloatCachAccGUID])
			SELECT
				[Guid],
				[POSGUID],
				[CurGUID],
				[Used],
				[CentralBoxAccGUID],
				[FloatCachAccGUID]

			FROM 
				POSSDRelatedCurrencies000 
	END

	IF (dbo.fnTblExists(''POSSDRelatedBankCards000'') <> 0) AND (NOT EXISTS(SELECT * FROM POSSDStationBankCard000))
	BEGIN 
	INSERT INTO [dbo].[POSSDStationBankCard000]
			   ([GUID],
				[StationGUID],
				[BankCardGUID],
				[IsUsed])
			SELECT
				[Guid],
				[POSGUID],
				[BankCardGUID],
				[Used]
			FROM 
				POSSDRelatedBankCards000 
	END

	IF (dbo.fnTblExists(''POSSDReturenedSales000'') <> 0) AND (NOT EXISTS(SELECT * FROM POSSDStationResale000))
	BEGIN 
	INSERT INTO [dbo].[POSSDStationResale000]
			   ([StationGUID],
				[bCash],
				[bForeignCurrencies])
			SELECT
				[POSCardGUID],
				[bCash],
				[bForeignCurrencies]
			FROM 
				POSSDReturenedSales000 
	END

	IF (dbo.fnTblExists(''POSSDRelatedPrintDesign000'') <> 0) AND (NOT EXISTS(SELECT * FROM POSSDStationPrintDesign000))
	BEGIN 
	INSERT INTO [dbo].[POSSDStationPrintDesign000]
			   ([GUID],
				[Number],
				[StationGUID],
				[PrintDesignGUID],
				[BillTypeGUID],
				[AskBeforePrinting])
			SELECT
				[GUID],
				[Number],
				[POSCardGUID],
				[PrintDesignGUID],
				[BillTypeGUID],
				[AskBeforePrinting]
			FROM 
				POSSDRelatedPrintDesign000 
	END

	IF (dbo.fnTblExists(''POSSDTicketBank000'') <> 0) AND (NOT EXISTS(SELECT * FROM POSSDTicketBankCard000))
	BEGIN 
	INSERT INTO [dbo].[POSSDTicketBankCard000]
			   ([GUID],
				[TicketGUID],
				[Value],
				[BankCardGUID ],
				[CheckNumber])
			SELECT
				[GUID],
				[TicketGUID],
				[Value],
				[BankGUID],
				[CheckNumber]
			FROM 
				POSSDTicketBank000 
	END

	IF (dbo.fnTblExists(''POSSDOptions000'') <> 0) AND (NOT EXISTS(SELECT * FROM POSSDStationOption000))
	BEGIN 
	INSERT INTO [dbo].[POSSDStationOption000]
			   ([GUID],
				[StationGUID ],
				[Name],
				[Value])
			SELECT
				[GUID],
				[POSGUID],
				[Name],
				[Value]
			FROM 
				POSSDOptions000 
	END
	')

	-- POSSD Release 2 
	EXEC prcAddFloatFld 'POSSDTicketItem000', 'SpecialOfferQty' , 0
    EXEC prcAddGUIDFld 'POSSDTicketItem000', 'SpecialOfferGUID'

	--EXEC prcDropFld	'POSSDStationResale000', 'ReturnType'
	--EXEC prcDropFld 'POSSDStationResale000', 'bAllowGeneralReturn'
	--EXEC prcDropFld 'POSSDStationResale000', 'bAllowGeneralExchage'
	--EXEC prcDropFld 'POSSDStationResale000', 'bAllowReturnFromSales'
	--EXEC prcDropFld 'POSSDStationResale000', 'bAllowExchangeFromSales'
	--EXEC prcDropFld 'POSSDStationResale000', 'bReturnExpireDays'
	--EXEC prcDropFld 'POSSDStationResale000', 'ReturnExpireDays'
	--EXEC prcDropFld 'POSSDStationResale000', 'bRetunFromPrevYear'
	--EXEC prcDropFld  'POSSDStationResale000', 'PrevYearFile'
	--EXEC prcDropFld 'POSSDStationResale000', 'bAllowReturnFromOffersTicket'
	--EXEC prcDropFld 'POSSDStationResale000', 'bAllowSearch'
	--EXEC prcDropFld 'POSSDStationResale000', 'bSearchByCutomer'
	--EXEC prcDropFld 'POSSDStationResale000', 'bSearchByDate'
	--EXEC prcDropFld 'POSSDStationResale000', 'bAllowExchangeWithLessPrice'
	--EXEC prcDropFld 'POSSDStationResale000', 'bPrintReturnCoupon'
	--EXEC prcDropFld 'POSSDStationResale000', 'bProgramReturnCard'

	EXEC prcAddIntFld 'POSSDStationResale000', 'ReturnType'
	EXEC prcAddBitFld 'POSSDStationResale000', 'bAllowGeneralReturn'
	EXEC prcAddBitFld 'POSSDStationResale000', 'bAllowGeneralExchage'
	EXEC prcAddBitFld 'POSSDStationResale000', 'bAllowReturnFromSales'
	EXEC prcAddBitFld 'POSSDStationResale000', 'bAllowExchangeFromSales'
	EXEC prcAddBitFld 'POSSDStationResale000', 'bReturnExpireDays'
	EXEC prcAddIntFld 'POSSDStationResale000', 'ReturnExpireDays'
	EXEC prcAddBitFld 'POSSDStationResale000', 'bRetunFromPrevYear'
	EXEC prcAddGUIDFld 'POSSDStationResale000', 'PrevYearFile'
	EXEC prcAddBitFld 'POSSDStationResale000', 'bAllowReturnFromOffersTicket'
	EXEC prcAddBitFld 'POSSDStationResale000', 'bAllowSearch'
	EXEC prcAddBitFld 'POSSDStationResale000', 'bSearchByCutomer'
	EXEC prcAddBitFld 'POSSDStationResale000', 'bSearchByDate'
	EXEC prcAddBitFld 'POSSDStationResale000', 'bAllowExchangeWithLessPrice'
	EXEC prcAddBitFld 'POSSDStationResale000', 'bPrintReturnCoupon'
	--EXEC prcAddBitFld 'POSSDStationResale000', 'bProgramReturnCard'
	EXEC prcAddBitFld 'POSSDStationResale000', 'bReturnFromDiffStations'

	-- salesman columns in POSSDStation
	EXEC prcAddGUIDFld 'POSSDStation000', 'SalesmanGUID'
	EXEC prcAddBitFld  'POSSDStation000', 'bForceSalesman'
	
	EXEC prcAddBitFld  'POSSDStation000', 'bAllowReturnExchange'

	EXEC [prcAlterFld] 'POSSDSpecialOffer000', 'Type','int'
	EXEC [prcAlterFld] 'POSSDSpecialOffer000', 'State','int'
	EXEC [prcAlterFld] 'POSSDSpecialOfferGroup000', 'UnitType','int'
	EXEC [prcAlterFld] 'POSSDSpecialOfferGroup000', 'PriceType','int'

	EXEC prcAddGUIDFld 'POSSDTicket000', 'SalesmanGUID'
	EXEC prcAddGUIDFld 'POSSDTicket000', 'RelatedTo'
	EXEC prcAddINTFld  'POSSDTicket000', 'RelationType'

	EXEC prcAddFloatFld 'POSSDSpecialOffer000', 'OfferQty'
	EXEC prcAddFloatFld 'POSSDSpecialOffer000', 'GrantQty'
	EXEC [prcRenameFld] 'POSSDSpecialOffer000',  'Wedensday', 'Wednesday'
	EXEC [prcDropFld]   'POSSDReturnCoupon000', 'RemainingBalance'
	EXEC prcAddINTFld   'POSSDReturnCoupon000', 'Type'
	EXEC prcAddINTFld   'POSSDTicketReturnCoupon000', 'Type'
	EXEC prcAddBitFld   'POSSDTicketReturnCoupon000', 'IsReceipt'
	EXEC prcAddBitFld   'POSSDStationReturnCouponSettings000', 'IsUsedInPayment'

	EXEC prcDropFld 'POSSDStationResale000', 'bProgramReturnCard'
	EXEC prcAddGUIDFld 'POSSDReturnCoupon000', 'ProcessedExpiryCoupon'
	EXEC prcDropFld 'POSSDSpecialOffer000', 'State'
	EXEC prcAddBitFld   'POSSDSpecialOffer000', 'IsTimeLinkedToDate'

	EXEC prcRenameFld 'POSSDTicketItemSerialNumbers000', 'SerialNumbers',  'SN'
	EXEC prcAddINTFld 'POSSDTicketItemSerialNumbers000', 'Number'

	EXEC prcDropFld   'POSSDStationSpecialOffer000', 'IsSychronize'
	EXEC prcAddBitFld 'POSSDStationSpecialOffer000','IsSynchronized','0'
	
	EXEC prcAddBitFld 'POSSDSpecialOffer000','IsAppliedToAllStations','0'
	EXEC prcAddBitFld 'POSSDStation000', 'CheckSerialNumbers'

	EXEC prcAddBitFld 'POSSDStationResale000', 'bTaxExpireDays'
	EXEC prcAddIntFld 'POSSDStationResale000', 'TaxExpireDays'

	EXEC prcAddINTFld  'POSSDPrintDesign000','LanguageType',0
	EXEC prcAddINTFld  'POSSDAdditionalCopyPrintSettingHeader000','LanguageType',0

	EXEC prcAddFloatFld 'POSSDTicketItem000', 'ReturnedQty' , 0
	EXEC prcAddGUIDFld	'POSSDTicket000', 'RelatedFrom' 

	EXEC prcAddGUIDFld 'POSSDTicket000','SpecialOfferGUID'
	EXEC prcAddFloatFld 'POSSDSpecialOffer000', 'OfferSpentAmount', 0  
	 EXEC prcAddIntFld  'POSSDTicketItem000', 'NumberOfSpecialOfferApplied' , 0

	 EXEC prcAddIntFld 'POSSDTicket000','TaxType'

	 EXEC prcAddIntFld 'POSSDStation000', 'PaymentAction', 1
	
	EXEC prcAddBitFld  'POSSDStation000', 'bPrintDuplicateCopy', 0
	EXEC prcAddBitFld  'POSSDTicket000', 'bIsPrinted', 0

	EXEC prcAddGUIDFld 'POSSDAdditionalCopyPrintSettingHeader000','OriginalGUID'	
	ALTER TABLE POSSDAdditionalCopyPrintSettingHeader000 ALTER COLUMN OriginalGUID UNIQUEIDENTIFIER NULL; 
 

	EXEC prcAddGUIDFld 'POSSDAdditionalCopyPrintSettingHeader000','ProcessThreadGuid'
	ALTER TABLE POSSDAdditionalCopyPrintSettingHeader000 ALTER COLUMN ProcessThreadGuid UNIQUEIDENTIFIER NULL; 

	 EXEC prcAddGUIDFld 'POSSDTicketItem000', 'SpecialOfferSlideGUID'
	 ALTER TABLE POSSDTicketItem000 ALTER COLUMN SpecialOfferSlideGUID UNIQUEIDENTIFIER NULL; 

	 EXEC prcAddBitFld  'POSSDTicket000', 'IsTaxCalculationBeforeAddition', 0
	 EXEC prcAddBitFld  'POSSDTicket000', 'IsTaxCalculationBeforeDiscount', 0
	 EXEC prcAddCharFld 'POSSDTicket000', 'RelatedFromInfo', 100;
	 ALTER TABLE POSSDTicket000 ALTER COLUMN RelatedFromInfo NVARCHAR(100) NULL;

	 EXEC prcAddGUIDFld 'POSSDExternalOperation000','CustomerGUID'
	 EXEC prcAddIntFld 'POSSDTicket000','OrderType', 0
	 EXEC prcAddIntFld 'POSSDDriver000', 'Security', 1
	 ALTER TABLE POSSDTicket000 ALTER COLUMN OrderType INT NULL;
	
	EXEC prcAddBitFld   'POSSDEmployee000', IsSuperVisor, '0'
	EXEC prcAddFloatFld 'POSSDEmployee000', MaxTicketItemDiscount, '0'
	EXEC prcAddFloatFld 'POSSDEmployee000', MaxTicketItemAddition, '0'
	EXEC prcAddFloatFld 'POSSDEmployee000', MaxTicketDiscount, '0'
	EXEC prcAddFloatFld 'POSSDEmployee000', MaxTicketAddition, '0'
		
	IF EXISTS(SELECT *
			  FROM INFORMATION_SCHEMA.COLUMNS
			  WHERE TABLE_NAME = 'POSSDShiftCashCurrency000'
			  AND COLUMN_NAME = 'CentralBoxReceiptId')

			  BEGIN 
			  	EXEC prcAlterFld 'POSSDShiftCashCurrency000', 'CentralBoxReceiptId', 'NVARCHAR(100)'
			  END
			  ELSE
			  BEGIN 
				EXEC prcAddCharFld 'POSSDShiftCashCurrency000', 'CentralBoxReceiptId', 100;
			  END  

	IF EXISTS(SELECT *
			  FROM INFORMATION_SCHEMA.COLUMNS
			  WHERE TABLE_NAME = 'POSSDStationOrder000'
			  AND COLUMN_NAME = 'ForceCancelReason'
			  AND DATA_TYPE = 'nvarchar')
	BEGIN

		SELECT 
			StationGUID,
			CAST(ForceCancelReason AS BIT) AS ForceCancelReason, 
			CAST(ForceBackToWaitingReason AS BIT) AS ForceBackToWaitingReason
		INTO 
			#TempStationOrder
		FROM 
			POSSDStationOrder000 


		EXEC prcDropFld 'POSSDStationOrder000', 'ForceCancelReason'
		EXEC prcDropFld 'POSSDStationOrder000', 'ForceBackToWaitingReason'
		EXEC prcAddBitFld 'POSSDStationOrder000', ForceCancelReason, '0'
		EXEC prcAddBitFld 'POSSDStationOrder000', ForceBackToWaitingReason, '0'


		MERGE POSSDStationOrder000 AS T
		USING #TempStationOrder    AS S
		ON (T.StationGUID = S.StationGUID)
		WHEN MATCHED THEN
		UPDATE SET ForceCancelReason = S.ForceCancelReason, 
				   ForceBackToWaitingReason = S.ForceBackToWaitingReason;
	END

	EXEC [prcRenameFld] 'POSSDTicketOrderInfo000', 'DriverPayment',  'DeliveryFee'
	EXEC [prcAddIntFld] 'POSSDTicketOrderInfo000', 'Number'

	
	DELETE FROM POSSDEmployeePermissions000 WHERE Name='PreviewShiftSummary'


	UPDATE POSSDEmployeePermissions000
	SET NAME='ViewShiftDigestReport'
	WHERE NAME='POSSD_Employee_ShiftDigest_Report'


	UPDATE POSSDEmployeePermissions000
	SET NAME='ViewPreviousShiftDigestReport'
	WHERE NAME='POSSD_Employee_PreviousShiftDigest_Report'


	UPDATE POSSDEmployeePermissions000
	SET NAME='ViewSalesAnalysisReport'
	WHERE NAME='POSSD_Employee_SalesAnalysis_Report'


	UPDATE POSSDEmployeePermissions000
	SET NAME='ViewWorkingHoursReport'
	WHERE NAME='POSSD_Employee_WorkingHours_Report'

	EXEC prcAddGUIDFld 'POSSDTicketOrderInfo000','TripGUID'


	IF EXISTS (SELECT * FROM sys.indexes WHERE name = 'POSSDTicket000_Key_0')
	BEGIN
		DROP INDEX POSSDTicket000_Key_0  ON POSSDTicket000;  
	END

	CREATE UNIQUE NONCLUSTERED INDEX [POSSDTicket000_Key_0] ON [dbo].[POSSDTicket000]
	(
		[Number] ASC,
		[ShiftGUID] ASC,
		[Type] ASC,
		[OrderType] ASC
	)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)

	 EXEC prcAddBitFld  'POSSDSpecialOfferGroup000', 'IsSonGroup', 0
	 
	 EXEC prcAddBitFld  'POSSDStation000', 'bPrintNullValue', 1
	 ALTER TABLE POSSDStation000 ALTER COLUMN bPrintNullValue	BIT NULL; 
	EXECUTE prcAddGUIDFld 'POSSDOperationPermission000', 'SupervisorGUID'

	EXEC prcAddBitFld  'POSSDTicketOrderInfo000', 'IsEDDDefined', 0	
	EXEC ('UPDATE POSSDTicketOrderInfo000 SET IsEDDDefined = ISNULL(IsEDDDefined, 0)')

	EXEC [prcRenameFld] 'POSSDOrderTrip000', 'OrderGUID',  'DriverGUID'
	EXEC prcAddGUIDFld 'POSSDSpecialOfferGroup000','SubMaterialGuid'
	
	EXEC ('ALTER TABLE POSSDSpecialOfferGroup000 ALTER COLUMN SubMaterialGuid	UNIQUEIDENTIFIER NULL ')
	EXEC [prcAlterFld] 'cu000', 'ConsiderChecksInBudget','int'


	------------------------------------------
	;WITH CTE AS 
			(
			SELECT ch.GUID AS ChGuid,ce.GUID AS CeGuid,ce.Number AS CeNumber
			FROM
				ch000 ch 
				INNER JOIN er000 er ON ch.GUID = er.ParentGUID 
				INNER JOIN ce000 ce ON er.EntryGUID = ce.GUID
			WHERE 
				er.ParentType = 5)
				
	INSERT INTO ChequeHistory000 
			SELECT
			(SELECT DISTINCT ISNULL(MAX(Number), 0) FROM [ChequeHistory000] WHERE ChequeGUID = [chh].GUID ) + 1,
				 NEWID() , 
				[chh].GUID,
				[chh].DueDate , 
				[chh].State,
				33 ,
			ISNULL(CTE.CeNumber, 0),
				CASE WHEN [chh].Dir = 1 THEN [chh].Account2GUID ELSE  [chh].AccountGUID END,
				CASE WHEN [chh].Dir = 1 THEN [chh].AccountGUID ELSE [chh].Account2GUID  END,
				Val , 
				5,
			ISNULL(CTE.CeGuid, 0x0),
				[chh].CurrencyGUID,
				[chh].CurrencyVal,
				0x0,
				0,
				[chh].Cost1GUID,
				[chh].Cost2GUID,
				CASE WHEN [chh].Dir = 1 THEN 0x0 ELSE  [chh].CustomerGuid END ,
				CASE WHEN [chh].Dir = 1 THEN [chh].CustomerGuid ELSE 0x0  END 
		FROM ch000 as [chh]
		INNER JOIN CTE as CTE  on CTE.ChGuid = [chh].GUID
		WHERE   NOT EXISTS (SELECT ChequeGUID FROM [ChequeHistory000] WHERE ChequeGUID = [chh].GUID AND EventNumber = 33)

		EXECUTE [prcDropProcedure]  'repBillEntriesMoveByPrice'

		EXEC [prcAddFld] 'BillColected000',  'GUID', '[UNIQUEIDENTIFIER]  ROWGUIDCOL DEFAULT(NEWID())' 

	-- PFC02
	EXECUTE [prcAddCharFld]	'SubProfitCenter000', 'DiffSaleGoodsAccName', 250
	EXECUTE	[prcAddGUIDFld] 'SubProfitCenter000', 'DiffSaleGoodsAccGuid'

	EXECUTE	[prcAddGUIDFld] 'SubProfitCenter000', 'DirectPurchasingTypeGuid'
	EXECUTE	[prcAddGUIDFld] 'SubProfitCenter000', 'DirectReturnPurchasingTypeGuid'
	EXECUTE	[prcAddGUIDFld] 'PFCClosedDays000', 'DecreaseBillGUID'
	EXECUTE	[prcAddGUIDFld] 'PFCClosedDays000', 'IncreaseBillGUID'

	DECLARE @PFCSTORE UNIQUEIDENTIFIER = CAST(ISNULL((SELECT [value] FROM op000 WHERE name = 'PFC_Store'), '00000000-0000-0000-0000-000000000000') AS UNIQUEIDENTIFIER)

	IF(@PFCSTORE <> 0x0)
		UPDATE
			bi000 SET StoreGUID = bu.StoreGUID
		FROM
			bu000 AS bu INNER JOIN bi000 AS bi ON bi.ParentGUID = bu.GUID
		WHERE 
			bu.StoreGUID = @PFCSTORE
	
	--Archiving02

	EXECUTE [prcAddFld] 'NSMailMessage000', 'AttachmentFile', 'varbinary(max) DEFAULT NULL'
	EXECUTE prcAddCharFld 'NSMailMessage000', 'AttachmentName', 256

	IF (ASSEMBLYPROPERTY('AmnNotification', 'VersionMajor') < 2) And
		(SELECT is_trustworthy_on FROM sys.databases WHERE name = db_name()) = 1
	BEGIN
		IF EXISTS(SELECT * FROM sys.objects WHERE name = 'NSCLRSendSms')
			DROP procedure NSCLRSendSms

		IF EXISTS(SELECT * FROM sys.objects WHERE name = 'NSCLRSendMail')
			DROP procedure NSCLRSendMail

		IF EXISTS(SELECT * FROM sys.assemblies WHERE name = 'AmnNotificationCLR')
			DROP ASSEMBLY AmnNotificationCLR

		IF EXISTS(SELECT * FROM sys.assemblies WHERE name = 'AmnNotification')
			DROP ASSEMBLY [AmnNotification]

		CREATE ASSEMBLY [AmnNotification] 
		FROM 0x4D5A90000300000004000000FFFF0000B800000000000000400000000000000000000000000000000000000000000000000000000000000000000000800000000E1FBA0E00B409CD21B8014CCD21546869732070726F6772616D2063616E6E6F742062652072756E20696E20444F53206D6F64652E0D0D0A2400000000000000504500004C010300C4729B5C0000000000000000E00022200B0130000048000000060000000000004667000000200000008000000000001000200000000200000400000000000000060000000000000000C000000002000000000000030060850000100000100000000010000010000000000000100000000000000000000000F46600004F00000000800000CC0300000000000000000000000000000000000000A000000C000000BC6500001C0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000200000080000000000000000000000082000004800000000000000000000002E746578740000004C470000002000000048000000020000000000000000000000000000200000602E72737263000000CC0300000080000000040000004A0000000000000000000000000000400000402E72656C6F6300000C00000000A0000000020000004E0000000000000000000000000000400000420000000000000000000000000000000028670000000000004800000002000500903800002C2D000001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006E0272010000707D0100000402281100000A000002037D010000042A133001000C0000000100001100026F060000060A2B00062A13300300CB010000020000110072010000700A731200000A0B07176F1300000A0003731400000A07281500000A0C086F1600000A2C1B086F1700000A173312086F1800000A7203000070281900000A2B01160D092C520008721D0000706F1A00000A7227000070281900000A130411042C2E00086F1600000A2C0B086F1700000A19FE012B0116130511052C12086F1B00000A027B01000004281C00000A0A00086F1600000A2600381301000000086F1700000A173312086F1800000A722B000070281900000A2B0116130611062C0900086F1600000A2600086F1700000A173312086F1800000A7235000070281900000A2B0116130711072C15000602086F1D00000A2804000006281C00000A0A00086F1700000A173312086F1800000A723F000070281900000A2B0116130811082C3500086F1600000A2C0B086F1700000A19FE012B0116130911092C12067251000070086F1B00000A281E00000A0A086F1600000A2600086F1700000A1F0F3312086F1800000A722B000070281900000A2B0116130A110A2C0F0006027B01000004281C00000A0A00086F1700000A1F0F3312086F1800000A7255000070281900000A2B0116130B110B2C03002B1000086F1600000A130C110C3ADEFEFFFF06130D2B00110D2A00133007007B000000030000110072010000700A731200000A0B07176F1300000A0003731400000A07281500000A0C0208726D0000701728050000060A067201000070281F00000A0D092C06000613042B33060208728100007016280500000602087299000070172805000006020872AB000070172805000006282000000A0A0613042B0011042A00133002007E000000040000110072010000700A036F1600000A26036F1700000A17330E036F1800000A04281900000A2B01160B072C4C00036F2100000A16FE010C082C3D00036F1600000A2C0B036F1700000A19FE012B01160D092C1C052D08036F1B00000A2B107251000070036F1B00000A281C00000A0A036F1600000A2600000613042B0011042A00001330020041000000000000000272010000707D020000040272010000707D030000040272010000707D040000040272010000707D050000040272C10000702801000006000002037D020000042A000000133004004E0100000500001100731200000A0A06176F1300000A00027B02000004731400000A06281500000A0B38E400000000076F1700000A173312076F1800000A72CB000070281900000A2B01160D092C150002076F2200000A7D03000004076F1600000A2600076F1700000A173312076F1800000A7255000070281900000A2B0116130411042C5B000772DB0000706F1A00000A1305110572E7000070281900000A2D022B1E0272EB00007002076F1D00000A2803000006281C00000A7D040000042B1E02720701007002076F1D00000A2803000006281C00000A7D040000042B0000076F1700000A173312076F1800000A7223010070281900000A2B0116130611062C0E0002076F2200000A7D050000040000076F1600000A130711073A0DFFFFFF730E0000060C08027B030000046F0A0000060008027B040000046F330000060008027B050000046F0C000006000813082B0011082A2202037D080000042A1E027B080000042A2202037D090000042A1E027B090000042A22022835000006002AAE0272010000707D0A0000040272010000707D0B0000040272010000707D0C0000040203283900000600002A00000013300200BF0000000600001100731200000A0A06176F1300000A0003731400000A06281500000A0B388E00000000076F1700000A173312076F1800000A72CB000070281900000A2B01160C082C0E0002076F2300000A7D0A00000400076F1700000A173312076F1800000A723D010070281900000A2B01160D092C0E0002076F2300000A7D0B00000400076F1700000A173312076F1800000A7223010070281900000A2B0116130411042C0E0002076F2300000A7D0C0000040000076F1600000A130511053A63FFFFFF2A001B300400BB0000000700001100730E0000060A06027B0A0000046F0A0000060006027B0B0000046F330000060006027B0C0000046F0C0000060000027B1B0000046F2400000A0B2B441201282500000A0C0002027B0A000004086F2F000006086F310000066F2600000A7D0A00000402027B0B000004086F2F000006086F310000066F2600000A7D0B000004001201282700000A2DB3DE0F1201FE160200001B6F2800000A00DC06027B0A0000046F0A0000060006027B0B0000046F3300000600060D2B00092A000110000002003B00518C000F0000000013300200260000000800001100027B0D00000414FE010A062C0D000273260000067D0D00000400027B0D0000040B2B00072A00001B3004005302000009000011000E047201000070282900000A811800000104036F34000006282900000A8118000001050374110000026F46000006282900000A8118000001170A732A00000A0B076F2B00000A7247010070725D0100706F2C00000A00027B0D0000046F170000067201000070281F00000A0D092C2C0007166F2D00000A0007027B0D0000046F17000006027B0D0000046F19000006732E00000A6F2F00000A0000027B0D0000047B15000004027B0D0000046F1D00000604FE16180000016F3000000A6F3100000A00027B0D0000047B15000004027B0D0000046F1F00000605FE16180000016F3000000A6F3100000A00076F3200000A027B0D0000047B150000046F3300000A00140C027B0D0000046F1B00000672EC010070281900000A13041104399D000000000007027B0D0000046F1500000672EC010070027B0D0000047B150000046F3400000A13050E04283500000A11056F3600000A282900000A811800000100DE38130600160A11066F3700000A14FE03130711072C210011066F3700000A6F3800000A733900000A0C086F3A00000A1106733B00000A7AFE1ADE1D000814FE03130811082C0900086F3C00000A0000076F3D00000A0000DC00388B000000027B0D0000046F1B00000672F6010070281900000A130911092C700014130A0007027B0D0000046F150000066F3E00000A130A110A733900000A0C0E04086F3A00000A282900000A811800000100DE062600160AFE1ADE3200110A14FE03130B110B2C0A00110A6F3F00000A00000814FE03130C110C2C0900086F3C00000A0000076F3D00000A0000DC0006130D2B00110D2A0001340000000024013F6301381B00000102002401799D011D000000000000DF0131100206100000010200DF01391802320000000022022842000006002A1E027B0E0000042A2202037D0E0000042A1E027B0F0000042A2202037D0F0000042A1E027B100000042A2202037D100000042A1E027B110000042A2202037D110000042A1E027B120000042A2202037D120000042A1E027B130000042A2202037D130000042A1E027B140000042A2202037D140000042A13300300AF0100000A00001100027B150000046F4000000A0072010000700A0372FE0100706F4100000A0B07398201000000386C01000000036F1700000A17FE010C08399300000000036F1800000A0A067212020070281900000A0D092C76007201000070130472010000701305036F4200000A2C12036F1800000A7235000070281900000A2B0116130611062C0A00036F1B00000A130400036F4200000A2C12036F1800000A7234020070281900000A2B0116130711072C0A00036F1B00000A130500027B15000004110411056F2C00000A00000038C7000000036F1700000A19FE011308110839B50000000006130911097240020070281900000A2D4811097250020070281900000A2D4911097268020070281900000A2D4A11097276020070281900000A2D4B11097288020070281900000A2D4C1109729A020070281900000A2D4D2B5A02036F1B00000A2816000006002B4B02036F1B00000A281E000006002B3C02036F1B00000A2820000006002B2D02036F1B00000A2818000006002B1E02036F1B00000A281A000006002B0F02036F1B00000A281C000006002B000000036F1600000A130A110A3A85FEFFFF0017130B2B00110B2A00133002000F0000000B0000110002281500000614FE030A2B00062A00133001000B0000000C0000110072B00200700A2B00062A4E02734300000A7D1500000402281100000A002A0013300300350000000D0000110072CA02007002734400000A0A066F4500000A721E030070036F4600000A26026F4700000A00066F4800000A26026F4900000A002A2202281100000A002A2202037D160000042A1E027B160000042A2202037D170000042A1E027B170000042A2202037D180000042A1E027B180000042A2202037D190000042A1E027B190000042A0000133002006C0000000E00001100730E0000060A02722C0300706F4100000A0B072C4E00140C0272440300706F1A00000A0D09724E030070281900000A2D022B0E026F1D00000A73080000060C2B15026F4A00000A26026F1D00000A730F0000060C2B00086F0700000674050000020A000613042B0011042A13300200650000000F0000110073470000060A02726E0300706F4100000A0B072C4700140C0272440300706F1A00000A0D09724E030070281900000A2D022B0E026F1D00000A73430000060C2B0E026F1D00000A734C0000060C2B00086F0700000674110000020A000613042B0011042A6E02734B00000A7D1B00000402281100000A000002037D1A0000042A000000133002009C0000001000001100731200000A0A06176F1300000A00027B1A000004731400000A06281500000A0B2B6000076F1700000A173312076F1800000A7284030070281900000A2B01160C082C0F0002076F1D00000A6F3B0000060000076F1700000A173312076F1800000A7296030070281900000A2B01160D092C0F0002076F1D00000A6F3C000006000000076F1600000A130411042D94026F3D00000613052B0011052A133004003F0200001100001173620000060A00731200000A0B07176F1300000A000603731400000A07281500000A7D2900000438FE01000000067B290000046F1700000A173317067B290000046F1800000A72A0030070281900000A2B01160C082C430073320000060D09067B2900000472AC0300706F1A00000A6F2E0000060009067B2900000472BC0300706F1A00000A6F2C00000600027B1B000004096F4C00000A0000067B290000046F1700000A173317067B290000046F1800000A72CA030070281900000A2B011613041104390901000000067B290000046F4D00000A1305110539F30000000038CC00000000027B1B000004067B2A000004252D18260606FE0663000006734E00000A2513077D2A00000411076F4F00000A14FE0313061106399200000000067B290000046F1B00000A1208285000000A130911092C3B027B1B000004067B2B000004252D18260606FE0664000006734E00000A2513077D2B00000411076F4F00000A1208285100000A6F30000006002B3D027B1B000004067B2C000004252D18260606FE0665000006734E00000A2513077D2C00000411076F4F00000A067B290000046F1B00000A6F30000006000000067B290000046F4200000A130A110A3A20FFFFFF067B290000046F4A00000A260000067B290000046F2100000A2C17067B290000046F1800000A72DC030070281900000A2D29067B290000046F1700000A1F0F3317067B290000046F1800000A72DC030070281900000A2B01162B0117130B110B2C03002B1500067B290000046F1600000A130C110C3AEEFDFFFF2A0013300200140000000B00001100026F3E0000066F2800000616FE010A2B00062A13300200120000000B00001100026F3E000006036F270000060A2B00062A00001B300300920000001200001100170A140B0072F0030070026F3E0000066F29000006722E040070281E00000A03734400000A0C036F4700000A00086F5200000A0B076F5300000A0D092C23000207724E0400706F5400000A6F3000000A731400000A285500000A6F40000006260000DE062600160AFE1ADE1D000714FE03130411042C0900076F5600000A0000036F4900000A0000DC0613052B0011052A0000011C000000000500606500061000000102000500686D001D00000000DA0272010000707D1C0000040272010000707D1D0000040272010000707D1E00000402725C0400702801000006000002037D1C0000042A0013300300BD0000001300001100731200000A0A06176F1300000A00027B1C000004731400000A06281500000A0B2B6600076F1700000A173312076F1800000A7255000070281900000A2B01160D092C14000202076F1D00000A28030000067D1D00000400076F1700000A173312076F1800000A7262040070281900000A2B0116130411042C0E0002076F2200000A7D1E0000040000076F1600000A130511052D8E73470000060C08027B1D0000046F330000060008027B1E0000046F45000006000813062B0011062A2202037D1F0000042A1E027B1F0000042A1E027B200000042A2202037D200000042A1E027B210000042A2202037D210000042A2A0203283900000600002A00133002008B0000001400001100731200000A0A06176F1300000A0003731400000A06281500000A0B2B6000076F1700000A173312076F1800000A723D010070281900000A2B01160C082C0F0002076F2300000A28490000060000076F1700000A173312076F1800000A7262040070281900000A2B01160D092C0F0002076F2300000A284B000006000000076F1600000A130411042D942A001B30040085000000150000110073470000060A060228480000066F33000006000602284A0000066F450000060000027B1B0000046F2400000A0B2B281201282500000A0C0002022848000006086F2F000006086F310000066F2600000A284900000600001201282700000A2DCFDE0F1201FE160200001B6F2800000A00DC060228480000066F3300000600060D2B00092A0000000110000002002E003563000F0000000013300200260000000800001100027B2200000414FE010A062C0D000273610000067D2200000400027B220000040B2B00072A00001B300300B301000016000011000E077201000070282900000A81180000010E040374050000026F0B000006282900000A81180000010E05036F34000006282900000A81180000010E060374050000026F0D000006282900000A81180000011F14285700000A00170A735800000A0B07027B220000046F59000006735900000A6F5A00000A00076F5B00000A0E06FE16180000016F3000000A6F5C00000A00070E04FE16180000016F3000000A6F5D00000A00070E05FE16180000016F3000000A6F5E00000A0007176F5F00000A00046F6000000A16FE010C082C5300736100000A25727A0400706F6200000A00250F03FE16180000016F3000000A6F6300000A000D046F6400000A166A166F6500000A26046F6400000A09736600000A1304076F6700000A11046F6800000A00000000027B220000046F53000006736900000A1305001105027B220000046F550000066F6A00000A001105166F6B00000A001105027B220000046F5B000006027B220000046F5D000006732E00000A6F6C00000A001105027B220000046F570000066F6D00000A001105076F6E00000A0000DE0D11052C0811056F2800000A00DC00DE062600160AFE1A0613062B0011062A00011C0000020036015F95010D000000000000230182A50106100000012202037D230000042A1E027B230000042A2202037D240000042A1E027B240000042A2202037D250000042A1E027B250000042A2202037D260000042A1E027B260000042A2202037D270000042A1E027B270000042A2202037D280000042A1E027B280000042A0000133002003D0100001700001100382001000000036F1700000A173312036F1800000A729A040070281900000A2B01160A062C0F0002036F2300000A28520000060000036F1700000A173312036F1800000A72B0040070281900000A2B01160B072C0F0002036F6F00000A28540000060000036F1700000A173312036F1800000A72BA040070281900000A2B01160C082C0F0002036F7000000A28560000060000036F1700000A173312036F1800000A72CE040070281900000A2B01160D092C0F0002036F2300000A28580000060000036F1700000A173312036F1800000A72E6040070281900000A2B0116130411042C0F0002036F2300000A285A0000060000036F1700000A173312036F1800000A72F8040070281900000A2B0116130511052C0F0002036F2300000A285C000006000000036F1600000A130611063AD1FEFFFF1713072B0011072A0000001330020028000000180000110002285300000614FE010A062C0500160B2B130228530000067201000070281F00000A0B2B00072A133001000B0000000C00001100720A0500700A2B00062A5E036F2D000006027B290000046F1800000A281900000A2A0042534A4201000100000000000C00000076342E302E33303331390000000005006C00000080120000237E0000EC1200009810000023537472696E677300000000842300002805000023555300AC280000100000002347554944000000BC2800007004000023426C6F620000000000000002000001571FA2090902000000FA0133001600000100000040000000150000002C000000650000003C000000040000007000000003000000670000001800000007000000160000002C0000000400000001000000040000000100000000008D0901000000000006003607140D0600C407140D06004F06D40C0F00340D000006009206900A06001907900A0600FA06900A0600AB07900A06005607900A06007C07900A0600A906900A06007E06F50C06004106F50C0600DD06900A0600C40692080600820E1D0A0A00A00DAC090A00EF0BAC0906002606140D06000F06D40C06006306D40C06005B00D6005B00C30C00000E00B708430D1200130FB00E0600030CA2001200320BB00E06000D0AA2001200A20AFE000E00190B1D0F0E0093031D0F060042001D0A0E00C60B1D0F0E00860D430D12002F04740912004B05FF041200720F74091200460F74090A006309AC090600E20BA2000600100CA2000A003F05AC090600F8081D0A060056041D0A1200B60AB00E12001809B00E1200B20DB00E06008908C80F12006405B00E0600350B1D0A12007D0F49090E00CA0A1D0F0E00A30C1D0F0E000C0B3F0B0E0089033F0B060062041D0A0E00B90B3F0B1200310CB00E1200530E74091200E10A740906004E0AA2001200F70A740906004E002A091200A50FB00E000000008100000000000100010080001000650C6F0A410001000100A00000009A0C6F0A00000200070000001000450C6F0A0800020008000100100041046F0A300008000A00000010007D0C6F0A38000A000F0001001000260C6F0A3C000D0012000100100063086F0A41000E001500A100000044086F0A000016002700010010000F096F0A410016002A0000001000E70C6F0A410016002C000100100046046F0A4100190033000100100066106F0A41001A00360080001000940C6F0A41001A00390081001000C6036F0A41001C003E0000001000620C6F0A08001C0043000100100015046F0A30001F00450000001000910C6F0A380020004800010010001B0C6F0A3C0022004F000100100052086F0A410023005200030110000100000041002900620001000F05CE0201000606CE020100DB05CE020100F205CE0201000C0ECE025180C90ECE025180BF0ECE020100F902CE020100DA02CE020100DB05CE020100F205CE0201000C0ECE0201003908D10201002B01CE020100DD01CE0201007401CE0201005801CE020100A801CE020100C501CE0201001102CE0206006A0DD50201006402CE0201004401CE0201003202CE0201004403CE0204000606CE0204009C0DD90201000606CE020100F205CE0201001705CE0201007C02CE0201005A03CE0201009902CE0201002E08E10201001203CE0201002E03E50201004902E8020100BD02CE020100F701CE0201008E01CE020600F90BEB0206001600EF0206002C00EF0206006200EF025020000000008618CE0C100001006C2000000000E6019E05F802020084200000000086003A105D0002005C220000000086007B045D000300E4220000000081002210FD020400000000000000C6052004F8020700000000000000C6059E05F80207007023000000008618CE0C10000700C02300000000C6002004F80208001A25000000008608950E100008002325000000008608890E530009002B250000000086084D0E1000090034250000000086083B0E53000A003C25000000008618CE0C06000A004525000000008618CE0C10000A00742500000000C400BE0510000B00402600000000C4002004F8020C00182700000000C600740805030C004C27000000008600E90D0A030C00E029000000008618CE0C06001000E9290000000086088A0053001000F129000000008608960010001000FA29000000008608C30453001100022A000000008608D004100011000B2A000000008608D30353001200132A000000008608E003100012001C2A000000008608A80353001300242A000000008608B703100013002D2A000000008608840453001400352A0000000086089404100014003E2A000000008608AD0453001500462A000000008608B804100015004F2A000000008608700553001600572A000000008608840510001600602A00000000E601BB0E190317001C2C00000000E6014F1049001800382C00000000E601DD04530018004F2C000000008618CE0C06001800000000000000C605BB0E19031800000000000000C6054F1049001900000000000000C605DD0453001900642C000000009600B00C1F031900A52C000000008618CE0C06001B00AE2C000000008608640A10001B00B72C000000008608590A53001C00BF2C000000008608240110001C00C82C0000000086081D0153001D00D02C000000008608170810001D00D92C0000000086080D0853001E00A52C000000008618CE0C06001E00E12C000000008608DD0F10001E00EA2C000000008608D40F53001F00A52C000000008618CE0C06001F00F42C0000000096003B0426031F006C2D0000000096000F042D032000A52C000000008618CE0C06002100DD2D000000008618CE0C10002100FC2D00000000E6019E05F8022200000000000000C405BE0510002200A42E00000000C401B80010002300000000000000C4052004F8022400000000000000C605740805032400F0300000000086008F1049002400103100000000C601230819032400303100000000C6017E0834032500A52C000000008418CE0C06002600EC31000000008618CE0C10002600243200000000C6002004F8022700ED320000000086086F0B10002700F6320000000086085F0B530028003C25000000008618CE0C06002800FE32000000008608F20F5300280006330000000081080A10100028000F330000000086087F0B530029001733000000008108960B100029002033000000008618CE0C10002A002C3300000000C400BE0510002B00C43300000000C4002004F8022C00683400000000C600740805032C009C3400000000860084093A032C00E029000000008618CE0C060033007836000000008608420F100033008136000000008608330F5300340089360000000086089C0F010034009236000000008608930F7F0135009A36000000008608E90915003500A336000000008608DB0949003600AB360000000086082B0E10003600B4360000000086081B0E53003700BC36000000008608F20410003700C536000000008608E50453003800CD36000000008608FA0310003800D636000000008608ED0353003900E03600000000E601BB0E190339002C3800000000E6014F1049003A00603800000000E601DD0453003A00A52C000000008618CE0C06003A00A52C000000008618CE0C06003A0077380000000083001D0051033A007738000000008300330051033B007738000000008300690051033C00000001000F0500000100CB0500000100B70900000100F90B00000200FA0410100300EC07000001000606000001001B08000001001B0800000100060600000100CB05000001004E0402000200E60F02000300AD0B02000400B80F000001001B08000001001B08000001001B08000001001B08000001001B08000001001B08000001001B0800000100F90B00000100F90B00000100270B00000200BA0C000001001B08000001001B08000001001B08000001001B0800000100F90B00000100F90B00000100060600000100CB0500000100C10000000100F90B00000100270B000001000606000001001B08000001001B08000001001B0800000100060600000100CB05000001004E04000002007C0D00000300A40402000400A10E020005004310020006005F0E02000700B80F000001001B08000001001B08000001001B08000001001B08000001001B08000001001B0800000100F90B00000100210800000100210800000100210802000C00080024000E000C00140024000900CE0C01001100CE0C06001900CE0C0A002900CE0C10003100CE0C10003900CE0C10004100CE0C10004900CE0C10005100CE0C10005900CE0C10006100CE0C15006900CE0C10007100CE0C10007900CE0C10009900CE0C0600A900CE0C1A008100CE0C06008900CE0C060089005F0938004101CE0C10009100B7053F009100F5004900910032054D0091006904530059017510570091006F075D009100E207530059017B0E62009100BF09530059017B0E680059018110570059017B0E790091005F0F49009100AC0853009100CA0853000C00C00CBA001400870FCA0059010704CF001400BF0F49006101A6050600C100D40EF100C900CE0C0600C900F10DF700E900FA00FD00C900CF0D15007101CE0CFD00C900BF0D03018100C1085300E900BB0EFD00C900EF080A01E900FA000F01C9008F0D1501810178001E018101E5082401D90057052A018901020A3001D100CE0C350149017F0353009101CE0C3B014901980506009901A6050600C900F1004301E10098050600E900590B06009100FF085801910097074900E900CE0C0600F900CE0C6A01F900FD0D7101A10100087701B101490A0600B90156107F01B101980506009100510F49000C00CE0C06000C00FA00BE019100580D49001C00CE0CCC010C00A303D201C101AE05DE01C101C1085300F900D40BF101C901F5004900C901140AF7019100B705FC01C90198050600D101E00E3D021901CE0C0600D901CE0C10001901240A42021901520B4902E101FA0010001901950E10001901311010001901CC0915001101A10949002101CE0C06002101240510002101720410001101F7093001E10013094F022901CE0C570219016B0E60022400FA00BE013101CE0C100031019C0F01003101CF0D15003101BF0D6F023101E909150031019E0376029100FB0E7F0191002D0A49000E001800960202001900CC020E001C00B1022E000B0063032E0013006C032E001B008B032E00230094032E002B00A9032E003300A9032E003B00AF032E00430094032E004B00BE032E005300A9032E005B00A9032E006300DF032E006B0009042E007300160401017B00600401018300650421017B00600421018300650440017B00600460017B00600480017B006004A0017B006004C1017B006004C10183006504E1017B006004E1018300650401027B00600401028300650421027B00600421028300650441027B00600441028300650461027B00600461028300650481027B006004810283006504A0027B006004A3027B006004C0027B006004C1027B006004C10283006504E0027B006004E1027B006004E1028300650400037B00600401037B00600401038300650420037B00600421037B00600421038300650440037B00600460037B00600480037B006004A0037B006004C0037B006004E0037B006004E1037B006004E1038300650400047B00600401047B00600401048300650420047B00600421047B00600421048300650440047B00600461047B00600461048300650481047B006004810483006504A1047B006004A10483006504C1047B006004C10483006504E1047B006004E1048300650401057B00600401058300650480057B006004A0057B006004C0057B006004E0057B00600400067B00600420067B00600460067B00600480067B006004A0087B006004C0087B00600400097B00600420097B00600440097B00600460097B006004400A7B006004600A7B006004800A7B006004A00A7B006004C00A7B006004E00A7B006004000B7B006004200B7B006004400B7B006004600B7B006004800B7B006004A00B7B006004200025006F00810089009900A400D500DB0049015D016101650183018E019901A501E501040212021C022B027D02880205000100080003000B000A000C000D0011000E0012000F00140011000000A80E57030000510E570300009A0057030000D40457030000E40357030000BB0357030000980457030000BC0457030000880557030000680A570300002801570300001B08570300002C1057030000A10B570300000E10570300009A0B57030000460F57030000A00F5B030000ED095F030000530E57030000F60457030000FE03570302000B00030001000A00030002000D00050001000C000500020015000700010016000700020017000900010018000900020019000B0001001A000B0002001B000D0001001C000D0002001D000F0001001E000F0002001F00110001002000110002002100130001002200130002002D00150001002C00150002002F00170001002E001700020031001900010030001900020034001B00010033001B00020046001D00010045001D00020048001F00010049001F0002004A00210001004B00210002005300230001005200230002005500250001005400250002005700270001005600270002005900290001005800290002005B002B0001005A002B0002005D002D0001005C002D00B300C300C4016602048000000200000000000000000000000000800A00000400000000000000000000008D02CD00000000000400000000000000000000008D02AC09000000000400000000000000000000008D02AC00000000000400000000000000000000008D021D0A0000000015000E0000000000003C3E635F5F446973706C6179436C617373355F30003C3E395F5F30003C52656164446174613E625F5F30003C3E395F5F31003C52656164446174613E625F5F3100507265646963617465603100436F6C6C656374696F6E6031004C6973746031003C3E395F5F32003C52656164446174613E625F5F32006765745F55544638003C4D6F64756C653E006765745F4261736555524C007365745F4261736555524C0053797374656D2E494F0053797374656D2E44617461005265616444617461006D65737361676544617461006D73636F726C69620053797374656D2E436F6C6C656374696F6E732E47656E65726963004F70656E52656164004164640053797374656D2E436F6C6C656374696F6E732E5370656369616C697A6564006765745F6964007365745F6964003C4261736555524C3E6B5F5F4261636B696E674669656C64003C69643E6B5F5F4261636B696E674669656C64003C53656E644D6574686F643E6B5F5F4261636B696E674669656C64003C50617373576F72643E6B5F5F4261636B696E674669656C64003C50617373776F72643E6B5F5F4261636B696E674669656C64003C4D6573736167654E616D653E6B5F5F4261636B696E674669656C64003C746F4E616D653E6B5F5F4261636B696E674669656C64003C557365724E616D653E6B5F5F4261636B696E674669656C64003C557365726E616D653E6B5F5F4261636B696E674669656C64003C53756363657373526573706F6E73653E6B5F5F4261636B696E674669656C64003C76616C75653E6B5F5F4261636B696E674669656C64003C456E61626C6553736C3E6B5F5F4261636B696E674669656C64003C636F6C756D6E3E6B5F5F4261636B696E674669656C64003C50686F6E654E756D6265723E6B5F5F4261636B696E674669656C64003C6D65737361676550686F6E654E756D6265723E6B5F5F4261636B696E674669656C64003C4D61696C416464726573733E6B5F5F4261636B696E674669656C64003C546F4D61696C416464726573733E6B5F5F4261636B696E674669656C64003C5375626A6563743E6B5F5F4261636B696E674669656C64003C536D7470436C69656E743E6B5F5F4261636B696E674669656C64003C506F72743E6B5F5F4261636B696E674669656C64003C546578743E6B5F5F4261636B696E674669656C64003C6D65737361676554656D706C617465546578743E6B5F5F4261636B696E674669656C640052656164546F456E64004462436F6D6D616E640053716C436F6D6D616E640053656E640046696E64006765745F53656E644D6574686F64007365745F53656E644D6574686F640053656E6465724D6574686F64006765745F50617373576F7264007365745F50617373576F7264006765745F50617373776F7264007365745F50617373776F7264005265706C61636500437265617465534D534D65737361676500436F6D706F73654D657373616765004D61696C4D65737361676500437265617465456D61696C4D657373616765006D6573736167650049446973706F7361626C650053696E676C65006765745F4E616D65007365745F4E616D6500526561644E616D65006765745F4D6573736167654E616D65007365745F4D6573736167654E616D650066696C654E616D65006765745F746F4E616D65007365745F746F4E616D65006765745F557365724E616D65007365745F557365724E616D65004765744E616D65006765745F557365726E616D65007365745F557365726E616D650053797374656D2E4E65742E4D696D65006E65774C696E65006D65737361676550686F6E65007365745F4D6564696154797065006765745F4E6F64655479706500586D6C4E6F64655479706500436F6E74656E7454797065006765745F526573706F6E736500576562526573706F6E7365006765745F53756363657373526573706F6E7365007365745F53756363657373526573706F6E736500436C6F736500436F6D706F736500446973706F736500547279506172736500437265617465005265616454656D706C617465006D65737361676554656D706C617465006D6573736167655375626A65637454656D706C617465006D657373616765426F647954656D706C6174650074656D706C61746500446562756767657242726F777361626C65537461746500436F6D70696C657247656E65726174656441747472696275746500477569644174747269627574650044656275676761626C6541747472696275746500446562756767657242726F777361626C6541747472696275746500436F6D56697369626C6541747472696275746500417373656D626C795469746C6541747472696275746500417373656D626C7954726164656D61726B417474726962757465005461726765744672616D65776F726B41747472696275746500417373656D626C7946696C6556657273696F6E41747472696275746500417373656D626C79436F6E66696775726174696F6E41747472696275746500417373656D626C794465736372697074696F6E41747472696275746500436F6D70696C6174696F6E52656C61786174696F6E7341747472696275746500417373656D626C7950726F647563744174747269627574650047657441747472696275746500417373656D626C79436F70797269676874417474726962757465004D6F7665546F4E65787441747472696275746500417373656D626C79436F6D70616E794174747269627574650052756E74696D65436F6D7061746962696C697479417474726962757465006765745F56616C75650061646453706163654265666F726556616C7565004164645769746856616C7565006765745F76616C7565007365745F76616C75650066004C6F6164436F6E666967006D61696C436F6E6669670068747470436F6E666967004953656E646572436F6E66696700536D747053656E646572436F6E666967004874747053656E646572436F6E66696700476574436F6E66696700496E6974436F6E66696700456E636F64696E670053797374656D2E52756E74696D652E56657273696F6E696E670052656164537472696E670053716C537472696E6700546F537472696E670052656164456C656D656E74436F6E74656E744173537472696E6700476574537472696E67006765745F5175657279537472696E670052656164546F466F6C6C6F77696E67004C6F67005365656B004E6574776F726B43726564656E7469616C0053797374656D2E436F6C6C656374696F6E732E4F626A6563744D6F64656C0053797374656D2E436F6D706F6E656E744D6F64656C007365745F436F6E666F726D616E63654C6576656C0053797374656D2E4E65742E4D61696C0053656E644D61696C00416D6E4E6F74696669636174696F6E2E646C6C006765745F49734E756C6C0053797374656D2E586D6C006E616D65586D6C0052656164496E6E6572586D6C007365745F4973426F647948746D6C006765745F456E61626C6553736C007365745F456E61626C6553736C006765745F53747265616D00476574526573706F6E736553747265616D006765745F4974656D0053797374656D007365745F46726F6D0052656164456C656D656E74436F6E74656E744173426F6F6C65616E004F70656E005365656B4F726967696E006765745F636F6C756D6E007365745F636F6C756D6E00416D6E2E4E6F74696669636174696F6E00416D6E4E6F74696669636174696F6E0053797374656D2E5265666C656374696F6E004E616D6556616C7565436F6C6C656374696F6E00576562486561646572436F6C6C656374696F6E0053716C506172616D65746572436F6C6C656374696F6E004D61696C41646472657373436F6C6C656374696F6E004174746163686D656E74436F6C6C656374696F6E004462436F6E6E656374696F6E0053716C436F6E6E656374696F6E00636F6E6E656374696F6E00576562457863657074696F6E0053797374656D2E446174612E436F6D6D6F6E006765745F546F00436C656172006765745F50686F6E654E756D626572007365745F50686F6E654E756D626572006765745F6D65737361676550686F6E654E756D626572007365745F6D65737361676550686F6E654E756D6265720070686F6E654E756D626572004462446174615265616465720053716C44617461526561646572004578656375746552656164657200537472696E6752656164657200586D6C52656164657200786D6C5265616465720053747265616D526561646572005465787452656164657200536D747053656E646572004874747053656E6465720053657276696365506F696E744D616E6167657200456D61696C4163636F756E7442616C616E636573436F6D706F73657200536D734163636F756E7442616C616E636573436F6D706F73657200456D61696C4F626A656374436F6D706F73657200536D734F626A656374436F6D706F7365720053716C506172616D657465720053656E644572726F72006572726F7200476574456E756D657261746F72002E63746F720053797374656D2E446961676E6F7374696373004D6573736167654665696C64730053797374656D2E52756E74696D652E496E7465726F7053657276696365730053797374656D2E52756E74696D652E436F6D70696C6572536572766963657300446562756767696E674D6F6465730053797374656D2E446174612E53716C5479706573006765745F486173417474726962757465730052657175657374417474726962757465730066696C6542797465730053716C42797465730055706C6F616456616C756573006D667300586D6C52656164657253657474696E6773004943726564656E7469616C73007365745F43726564656E7469616C73007365745F55736544656661756C7443726564656E7469616C730053656E64536D73006765745F48656164657273006765745F506172616D6574657273006D65737361676541646472657373006765745F4D61696C41646472657373007365745F4D61696C41646472657373006765745F546F4D61696C41646472657373007365745F546F4D61696C41646472657373006D61696C41646472657373006765745F4174746163686D656E747300436F6E636174004F626A656374006765745F5375626A656374007365745F5375626A656374006D6573736167655375626A6563740053797374656D2E4E65740053657400416C69676E4C65667400416C69676E5269676874006F705F496D706C69636974007365745F44656661756C74436F6E6E656374696F6E4C696D69740052656164456C656D656E74436F6E74656E744173496E7400576562436C69656E740053797374656D2E446174612E53716C436C69656E74006765745F536D7470436C69656E74007365745F536D7470436C69656E74004D6F7665546F456C656D656E74006765745F4973456D707479456C656D656E74004174746163686D656E7400436F6D706F6E656E74006765745F43757272656E74006765745F506F7274007365745F506F7274004943726564656E7469616C734279486F7374006F7574707574004D6F76654E6578740053797374656D2E54657874006765745F54657874007365745F54657874006D65737361676554657874006765745F6D65737361676554656D706C61746554657874007365745F6D65737361676554656D706C6174655465787400476574456C656D656E7454657874007365745F426F64790052656164426F6479006D657373616765426F64790056657269667900457865637574654E6F6E5175657279004D657373616765466163746F7279006F705F457175616C697479006F705F496E657175616C697479004973456D7074790000000100194D006500730073006100670065005400690074006C0065000009530068006F0077000003310000094C0069006E00650000094E0061006D0065000011420061006C0061006E006300650073000003200000174D0065007300730061006700650042006F006400790000134E0061006D00650049006E004D005300470000174100630063006F0075006E0074004E0061006D006500001143006F00730074004E0061006D00650000154200720061006E00630068004E0061006D00650000093C00620072003E00000F5300750062006A00650063007400000B41006C00690067006E0000033000001B3C00700020006400690072003D002700720074006C0027003E00011B3C00700020006400690072003D0027006C007400720027003E00011945006D00610069006C004100640064007200650073007300000942006F0064007900001575007300650072002D006100670065006E00740001808D4D006F007A0069006C006C0061002F0034002E0030002000280063006F006D00700061007400690062006C0065003B0020004D00530049004500200036002E0030003B002000570069006E0064006F007700730020004E005400200035002E0032003B0020002E004E0045005400200043004C005200200031002E0030002E0033003700300035003B002900000950004F00530054000007470045005400001353004D00530043006F006E0066006900670000215200650071007500650073007400410074007400720069006200750074006500000B560061006C0075006500000F4200610073006500550052004C0000174D006500730073006100670065004E0061006D006500000D54006F004E0061006D006500001155007300650072004E0061006D0065000011500061007300730057006F00720064000015530065006E0064004D006500740068006F00640000194E0053005F0053006D00730043006F006E00660069006700005369006E007300650072007400200069006E0074006F002000440042004C006F006700200028004E006F0074006500730029002000760061006C007500650073002000280040006500720072006F0072002900000D40006500720072006F00720000174D00610069006C004D0065007300730061006700650000095400790070006500001F4100630063006F0075006E007400420061006C0061006E00630065007300001553006D0073004D006500730073006100670065000011540065006D0070006C0061007400650000094400610074006100000B4600690065006C006400000F4600690065006C00640049004400000D43006F006C0075006D006E000011460075006E006300740069006F006E000013460075006E006300740069006F006E007300003D530045004C004500430054002000640062006F002E0066006E004F007000740069006F006E005F00470065007400560061006C007500650028002700011F27002C00200030002900200041005300200043006F006E00660069006700010D43006F006E0066006900670000050D000A000017500068006F006E0065004E0075006D00620065007200001F6100700070006C00690063006100740069006F006E002F00700064006600001553006D007400700043006C00690065006E007400000950006F0072007400001345006E00610062006C006500530073006C0000174D00610069006C004100640064007200650073007300001155007300650072006E0061006D0065000011500061007300730077006F0072006400001B4E0053005F004D00610069006C0043006F006E00660069006700000000C0E8584D3F1487448571AA8102BFF84D00042001010803200001052001011111042001010E0420010102052001011151040701123012070E0E12451249020202020202020202020E0620010111809D09000212491280A51245032000020520001180A90320000E050002020E0E0420010E0E0500020E0E0E0600030E0E0E0E0907050E12451249020E0700040E0E0E0E0E0707050E0202020E0F070912451249121402020E020212300A070612451249020202020E0704121415115D01122C122C12300615125901122C08200015115D0113000615115D01122C04200013000520020E0E0E05070202122415070E021265126902021D05126D020202127102020205000111610E0520001280B5052002010E0E062001011280BD04200012750520010112750820031D050E0E12750500001280C10520010E1D050520001280C50420001271052001011271072002010E1280C905200112710E0E070C0E0202020E0E0202020E0202042001020E030701020307010E040701127D062002010E12790520001280D10720021280D50E1C032000080A0705121402120C0E12140A0705124402120C0E12440B070612451249020202123018070D1254124502122C0202021512808101122C0C02020202052001011300071512808101122C052002011C180B2001130015128081011300060002020E100C0B070602128085127D0202020520001280850420011C0E07000112491280A50D07071245124912440202021230090705124512490202020E0704124415115D01122C122C12301107070212808D02128091128095128099020400010108062001011280ED0520001280F10720020A0A1180F50820020112711280910520001280F908151280FD01128095062001011281010620010112808D0A07080202020202020202040702020208B77A5C561934E0891A3C00700020006400690072003D002700720074006C0027003E001A3C00700020006400690072003D0027006C007400720027003E00010102060E0306122003061275070615125901122C030612500206080206020306124908061512808101122C04200012300720030E12490E0204200012240E20040212301011611011611011610520010212490600020112790E0600011214124906000112441249052001021279162007021230128089116110116110116110116110116105200102122C0328000E03280008032800020801000800000000001E01000100540216577261704E6F6E457863657074696F6E5468726F7773010801000701000000001401000F416D6E4E6F74696669636174696F6E00000501000000000E0100094D6963726F736F667400002001001B436F7079726967687420C2A9204D6963726F736F6674203230313600002901002432616238643232322D343261312D343730332D623033622D35656537653765343431653500000C010007322E302E302E3000004901001A2E4E45544672616D65776F726B2C56657273696F6E3D76342E350100540E144672616D65776F726B446973706C61794E616D65122E4E4554204672616D65776F726B20342E350401000000080100000000000000000000000000C4729B5C00000000020000001C010000D8650000D8470000525344533C90627E1816764BA69E25C6AF97118701000000433A5C7372635C416D6E39312D4172636830325C416D6E38305C4472765C416D6E4E6F74696669636174696F6E5C6F626A5C44656275675C416D6E4E6F74696669636174696F6E2E70646200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001C67000000000000000000003667000000200000000000000000000000000000000000000000000028670000000000000000000000005F436F72446C6C4D61696E006D73636F7265652E646C6C0000000000FF250020001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000100100000001800008000000000000000000000000000000100010000003000008000000000000000000000000000000100000000004800000058800000700300000000000000000000700334000000560053005F00560045005200530049004F004E005F0049004E0046004F0000000000BD04EFFE00000100000002000000000000000200000000003F000000000000000400000002000000000000000000000000000000440000000100560061007200460069006C00650049006E0066006F00000000002400040000005400720061006E0073006C006100740069006F006E00000000000000B004D0020000010053007400720069006E006700460069006C00650049006E0066006F000000AC02000001003000300030003000300034006200300000001A000100010043006F006D006D0065006E007400730000000000000034000A00010043006F006D00700061006E0079004E0061006D006500000000004D006900630072006F0073006F00660074000000480010000100460069006C0065004400650073006300720069007000740069006F006E000000000041006D006E004E006F00740069006600690063006100740069006F006E000000300008000100460069006C006500560065007200730069006F006E000000000032002E0030002E0030002E003000000048001400010049006E007400650072006E0061006C004E0061006D006500000041006D006E004E006F00740069006600690063006100740069006F006E002E0064006C006C0000005A001B0001004C006500670061006C0043006F007000790072006900670068007400000043006F0070007900720069006700680074002000A90020004D006900630072006F0073006F006600740020003200300031003600000000002A00010001004C006500670061006C00540072006100640065006D00610072006B00730000000000000000005000140001004F0072006900670069006E0061006C00460069006C0065006E0061006D006500000041006D006E004E006F00740069006600690063006100740069006F006E002E0064006C006C000000400010000100500072006F0064007500630074004E0061006D0065000000000041006D006E004E006F00740069006600690063006100740069006F006E000000340008000100500072006F006400750063007400560065007200730069006F006E00000032002E0030002E0030002E003000000038000800010041007300730065006D0062006C0079002000560065007200730069006F006E00000032002E0030002E0030002E00300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006000000C000000483700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
		WITH PERMISSION_SET = UNSAFE
		
		CREATE ASSEMBLY [AmnNotificationCLR]
		FROM 0x4D5A90000300000004000000FFFF0000B800000000000000400000000000000000000000000000000000000000000000000000000000000000000000800000000E1FBA0E00B409CD21B8014CCD21546869732070726F6772616D2063616E6E6F742062652072756E20696E20444F53206D6F64652E0D0D0A2400000000000000504500004C010300C5729B5C0000000000000000E00022200B013000000E000000060000000000009E2C00000020000000400000000000100020000000020000040000000000000006000000000000000080000000020000000000000300608500001000001000000000100000100000000000001000000000000000000000004C2C00004F00000000400000C803000000000000000000000000000000000000006000000C000000142B00001C0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000200000080000000000000000000000082000004800000000000000000000002E74657874000000A40C000000200000000E000000020000000000000000000000000000200000602E72737263000000C8030000004000000004000000100000000000000000000000000000400000402E72656C6F6300000C0000000060000000020000001400000000000000000000000000004000004200000000000000000000000000000000802C0000000000004800000002000500102200000409000001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001B300800BD0000000100001100050E040E050E067201000070280D00000A250A811300000106250A811300000106250A8113000001068113000001007E0100000414FE010B072C2100730E00000A80010000047E010000047203000070730F00000A6F1000000A26007E01000004026F1100000A281200000A0304050E040E050E066F1300000A2600DE330C000E06086F1400000A280D00000A81130000017203000070730F00000A086F1500000A281600000A0016281700000A0DDE0917281700000A0D2B00092A0000000110000000002F00507F0033140000012202281800000A002A1E1480010000042A0000001B300500AA00000001000011000304057201000070280D00000A250A811300000106250A8113000001068113000001007E0200000414FE010B072C2100731900000A80020000047E020000047203000070730F00000A6F1000000A26007E02000004026F1100000A281A00000A0304056F1B00000A2600DE320C0005086F1400000A280D00000A81130000017203000070730F00000A086F1500000A281600000A0016281700000A0DDE0917281700000A0D2B00092A000001100000000023004A6D0032140000011E1480020000042A42534A4201000100000000000C00000076342E302E33303331390000000005006C00000024030000237E0000900300000404000023537472696E677300000000940700003400000023555300C8070000100000002347554944000000D80700002C01000023426C6F620000000000000002000001571502000900000000FA013300160000010000001D0000000300000002000000060000000B0000001B0000000D00000001000000010000000400000000002D02010000000000060068013C030600D5013C030600B30029030F005C0300000600C7007E0206004B017E0206002C017E020600BC017E02060088017E020600A1017E020600F4007E0206000F017E020600A20356020A00CB025D020E00DE00F7020E0001006B030E004F026B030E0080036B030E00FE016B0306009E0256020A00E1025D020E009002C4030A003B005D021200C10244020A00F2035D020A006B005D020A007D005D020A0011025D020A004E005D02000000000A000000000001000100010010002702000035000100010001001000920300003500020004001100D6027D001100EC02810050200000000096001E02850001002C210000000086181C0306000800352100000000911822039C00080040210000000096008903A00008002C210000000086181C0306000C00082200000000911822039C000C0000000100A30000000200850000000300940002000400A90302000500E60302000600960302000700780000000100A30002000200DA0302000300A80202000400780009001C03010011001C03060019001C030A0029001C03100031001C03100039001C03100041001C03100049001C03100051001C03100059001C03100061001C03100079001C0306009900B8031F0071001C030600B1001C031000B900F30125008900B4022B00C90065003000710015023700A10059004D00690008024D00E100120351008100B803580069001C030600A9001C030600C90048005E00A9008E0365002000630024012E000B00B0002E001300B9002E001B00D8002E002300E1002E002B00F9002E003300F9002E003B00F9002E004300E1002E004B00FF002E005300F9002E005B001701800063002401150004800000020000000000000000000000000013000000040000000000000000000000740032000000000002000000000000000000000000006E020000000004000000000000000000000074002600000000000400000000000000000000007400440200000000000000000053716C496E743332003C4D6F64756C653E00416D6E4E6F74696669636174696F6E434C520053797374656D2E44617461006D73636F726C69620053656E6465724D6574686F6400437265617465534D534D657373616765006765745F4D65737361676500437265617465456D61696C4D657373616765006572726F724D657373616765006174746163686D656E7446696C65006174746163686D656E744E616D65006D65737361676554656D706C6174650044656275676761626C6541747472696275746500417373656D626C795469746C654174747269627574650053716C50726F63656475726541747472696275746500417373656D626C7954726164656D61726B41747472696275746500417373656D626C7946696C6556657273696F6E41747472696275746500417373656D626C79436F6E66696775726174696F6E41747472696275746500417373656D626C794465736372697074696F6E41747472696275746500436F6D70696C6174696F6E52656C61786174696F6E7341747472696275746500417373656D626C7950726F6475637441747472696275746500417373656D626C79436F7079726967687441747472696275746500417373656D626C79436F6D70616E794174747269627574650052756E74696D65436F6D7061746962696C69747941747472696275746500496E6974436F6E6669670053716C537472696E6700546F537472696E67004C6F670053656E644D61696C00636C72666E53656E64456D61696C00416D6E4E6F74696669636174696F6E434C522E646C6C0053797374656D2E586D6C0053716C586D6C0053797374656D00416D6E2E4E6F74696669636174696F6E00416D6E4E6F74696669636174696F6E0053797374656D2E5265666C656374696F6E0053716C436F6E6E656374696F6E00457863657074696F6E0070686F6E654E756D6265720043726561746552656164657200586D6C52656164657200536D747053656E64657200736D747053656E646572004874747053656E646572006874747053656E646572004D6963726F736F66742E53716C5365727665722E5365727665720053656E644572726F72002E63746F72002E6363746F720053797374656D2E446961676E6F73746963730053797374656D2E52756E74696D652E436F6D70696C6572536572766963657300446562756767696E674D6F6465730053797374656D2E446174612E53716C54797065730053716C427974657300636C72666E53656E64536D73006D61696C41646472657373004F626A656374006D6573736167655375626A656374006F705F496D706C696369740053797374656D2E446174612E53716C436C69656E74006D65737361676554657874006D657373616765426F6479004D657373616765466163746F7279000000000001002F63006F006E007400650078007400200063006F006E006E0065006300740069006F006E003D007400720075006500000093061FAE5034CC4FBBF58AC4346A01A400042001010803200001052001011111042001010E090704114D0212511141050001114D0E05200102125904200012610600011269126115200702126D1249114D10114D10114D10114D10114D0320000E0600020112590E050001114108060001127512610E200402126D10114D10114D10114D08B77A5C561934E0890306123903061255160007114112451249114D10114D10114D10114D10114D030000010F00041141124510114D10114D10114D0801000800000000001E01000100540216577261704E6F6E457863657074696F6E5468726F77730108010007010000000017010012416D6E4E6F74696669636174696F6E434C52000005010000000017010012436F7079726967687420C2A920203230313900000C010007322E302E302E300000040100000000000000000000C5729B5C00000000020000001C010000302B0000300D000052534453658E81FAAFA7DA4191F080B32628EF5401000000433A5C7372635C416D6E39312D4172636830325C416D6E38305C4472765C416D6E4E6F74696669636174696F6E434C525C6F626A5C44656275675C416D6E4E6F74696669636174696F6E434C522E7064620000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000742C000000000000000000008E2C0000002000000000000000000000000000000000000000000000802C0000000000000000000000005F436F72446C6C4D61696E006D73636F7265652E646C6C0000000000FF2500200010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001001000000018000080000000000000000000000000000001000100000030000080000000000000000000000000000001000000000048000000584000006C03000000000000000000006C0334000000560053005F00560045005200530049004F004E005F0049004E0046004F0000000000BD04EFFE00000100000002000000000000000200000000003F000000000000000400000002000000000000000000000000000000440000000100560061007200460069006C00650049006E0066006F00000000002400040000005400720061006E0073006C006100740069006F006E00000000000000B004CC020000010053007400720069006E006700460069006C00650049006E0066006F000000A802000001003000300030003000300034006200300000001A000100010043006F006D006D0065006E007400730000000000000022000100010043006F006D00700061006E0079004E0061006D00650000000000000000004E0013000100460069006C0065004400650073006300720069007000740069006F006E000000000041006D006E004E006F00740069006600690063006100740069006F006E0043004C00520000000000300008000100460069006C006500560065007200730069006F006E000000000032002E0030002E0030002E00300000004E001700010049006E007400650072006E0061006C004E0061006D006500000041006D006E004E006F00740069006600690063006100740069006F006E0043004C0052002E0064006C006C00000000004800120001004C006500670061006C0043006F007000790072006900670068007400000043006F0070007900720069006700680074002000A90020002000320030003100390000002A00010001004C006500670061006C00540072006100640065006D00610072006B00730000000000000000005600170001004F0072006900670069006E0061006C00460069006C0065006E0061006D006500000041006D006E004E006F00740069006600690063006100740069006F006E0043004C0052002E0064006C006C0000000000460013000100500072006F0064007500630074004E0061006D0065000000000041006D006E004E006F00740069006600690063006100740069006F006E0043004C00520000000000340008000100500072006F006400750063007400560065007200730069006F006E00000032002E0030002E0030002E003000000038000800010041007300730065006D0062006C0079002000560065007200730069006F006E00000032002E0030002E0030002E0030000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002000000C000000A03C00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
		WITH PERMISSION_SET = UNSAFE

		DECLARE @sql NVARCHAR(MAX)
		SET @sql = 'CREATE PROCEDURE NSCLRSendMail(@message XML, @attatchmentFile VARBINARY(MAX), @attatchmentName NVARCHAR(256), @messageSubject NVARCHAR(256) OUTPUT, @messageBody NVARCHAR(max) OUTPUT, @mailAddress NVARCHAR(100) OUTPUT, @errorMessage NVARCHAR(max) OUTPUT) AS EXTERNAL NAME AmnNotificationCLR.Email.clrfnSendEmail'

		EXEC sp_executesql @sql

		SET @sql = 'CREATE PROCEDURE NSCLRSendSms(@message XML, @essageText NVARCHAR(max) OUTPUT, @phoneNumber NVARCHAR(20) OUTPUT, @errorMessage NVARCHAR(max) OUTPUT) AS EXTERNAL NAME AmnNotificationCLR.Sms.clrfnSendSms'

		EXEC sp_executesql @sql
	END
######################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From100091533
AS
	BEGIN
		EXEC  PrcAddBitFld  'Distributor000', 'ExportOrdersReportFlag', 0
		EXEC  prcAddIntFld  'Distributor000', 'ExportOrdersReportDays', 0
		EXEC  prcAddGUIDFld 'Distributor000', 'OrderStoreGuid'
		EXEC  prcAddGUIDFld 'LC000', 'CostCenterGUID'
		EXEC prcAddBitFld 'oit000', 'IsQtyReserved', 0
		EXEC  prcAddIntFld  'LCMain000', 'BranchMask', 0
		EXEC  prcAddGUIDFld 'LC000', 'BranchGUID'
		EXECUTE PrcAddBitFld  'TransferedOrderBillsInfo000', 'LcState', 1

		IF EXISTS (SELECT * 
					FROM Distributor000 D 
					INNER JOIN DistDd000 DD ON D.GUID = DD.DistributorGUID
					INNER JOIN bt000	BT ON BT.GUID = DD.ObjectGUID
					WHERE BT.Type = 5)
		BEGIN
			EXEC (' 
				UPDATE D
				SET D.OrderStoreGuid = D.StoreGUID
				FROM Distributor000 D 
				INNER JOIN DistDd000 DD ON D.GUID = DD.DistributorGUID
				INNER JOIN bt000	BT ON BT.GUID = DD.ObjectGUID
				WHERE BT.Type = 5
			')
		END

		EXEC  prcAddBitFld 'DistDeviceBt000', 'CalcTotalDiscRegardlessItemDisc', 0
		EXEC  prcAddBitFld  'DistDeviceBt000', 'CalcTotalExtraRegardlessItemExtra', 0
		EXEC  prcAddFloatFld 'DistDeviceMS000', 'ReservedQty', 0

		IF([dbo].[fnObjectExists]('prcSaveOrderInitiateInfo') = 1)
			DROP PROC prcSaveOrderInitiateInfo

		IF([dbo].[fnObjectExists]('prcSaveStartedStateToOrder') = 1)
			DROP PROC prcSaveStartedStateToOrder
	END

	EXEC [prcAlterFld] 'DistDeviceOrderStatement000', 'OrderNumber','INT'

######################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From100091597
AS
	BEGIN
		EXEC [PrcAddBitFld] 'bt000', 'bAffectCalcStoredQty', 1
		EXECUTE PrcAddBitFld  'Distributor000', 'PostedInvenytoryAfterRealizeOrders', 0

		
		EXECUTE [PrcAddBitFld]  'POSSDStationDevice000', 'ActiveFlag', 1
		EXECUTE [prcAddDateFld]	'POSSDStationDevice000', 'LastConnectedOn'
		EXECUTE [prcAddCharFld]	'POSSDStationDevice000', 'DeviceName', 300
		EXECUTE [prcAddCharFld]	'POSSDStationDevice000', 'DeviceModel', 300
		EXECUTE [prcAddCharFld]	'POSSDStationDevice000', 'DevicePlatform', 300
		EXECUTE [prcAddCharFld]	'POSSDStationDevice000', 'DeviceVersion', 300
		EXECUTE [prcAddCharFld]	'POSSDStationDevice000', 'DeviceIdiom', 300
		EXECUTE [prcAddCharFld]	'POSSDStationDevice000', 'DeviceManufacture', 300

		EXECUTE [prcAlterFld] 'POSSDStationDevice000', 'ActiveFlag', 'BIT', 1, '0'

		EXECUTE [prcAddCharFld]	'POSSDTicket000', 'DeviceID', 250
		EXECUTE [prcAddCharFld]	'POSSDExternalOperation000', 'DeviceID', 250
	End
######################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From100091737
AS
	EXECUTE [prcAddGUIDFld] 'DistDeviceMt000','CurrencyGUID'
	EXECUTE [prcAddFloatFld]'DistDeviceMt000', 'CurrencyValue'

	EXECUTE [prcAddGUIDFld] 'DistDeviceBi000','CurrencyGUID'
	EXECUTE [prcAddFloatFld]'DistDeviceBi000', 'CurrencyValue'

	EXECUTE [prcAddGUIDFld] 'DistDeviceBu000','CurrencyGUID'
	EXECUTE [prcAddFloatFld] 'DistDeviceBu000','CurrencyValue'
    EXECUTE [prcAddGUIDFld] 'DistDeviceSnc000','StGuid'

	EXEC [prcAddIntFld] 'POSSDTicketItem000','TaxCode'			
	EXECUTE [prcAddGUIDFld] 'POSSDTicket000','GCCLocationGUID';	

	IF [dbo].[fnObjectExists]('et000.CostBothAccount') <>  0
	BEGIN
		EXEC('UPDATE et000 SET CostForBothAcc = CostBothAccount WHERE CostBothAccount <> 0');
		EXEC [prcDropFld]  'et000', 'CostBothAccount'
	END
######################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From100091889
AS 
	--- Start CMPT06
	IF [dbo].[fnObjectExists]('RestDiscTax000.CalculatedValue') =  0
	BEGIN
		EXEC [prcAddFloatFld] 'RestDiscTax000' , 'CalculatedValue' 
		EXEC [prcAddFloatFld] 'RestDiscTaxTemp000' , 'CalculatedValue' 

		EXEC('
			UPDATE ui000 SET PermType = 8 
			WHERE 
				PermType = 6 
				AND 
				((ReportId IN (268517376, 536917136, 536917137, 536961138, 536961139)) OR (ReportId = 268525568 AND SubId IN (SELECT GUID FROM et000)))

			UPDATE uix SET PermType = 8
			WHERE 
				PermType = 6 
				AND 
				((ReportId IN (268517376, 536917136, 536917137, 536961138, 536961139)) OR (ReportId = 268525568 AND SubId IN (SELECT GUID FROM et000)))

			INSERT INTO ui000 (GUID, UserGUID, ReportId, SubId, System, PermType, Permission)
			SELECT newId(), UserGUID, ReportId, SubId, System, PermType + 3, Permission 
			FROM 
				ui000 
			WHERE 
				(PermType BETWEEN 3 AND 4)
				AND
				((ReportId IN (268517376, 536917136, 536917137, 536961138, 536961139)) OR (ReportId = 268525568 AND SubId IN (SELECT GUID FROM et000))) 

			INSERT INTO uix (GUID, UserGUID, ReportId, SubId, System, PermType, Permission)
			SELECT newId(), UserGUID, ReportId, SubId, System, PermType + 3, Permission 
			FROM 
				uix
			WHERE 
				(PermType BETWEEN 3 AND 4)
				AND
				((ReportId IN (268517376, 536917136, 536917137, 536961138, 536961139)) OR (ReportId = 268525568 AND SubId IN (SELECT GUID FROM et000))) 
		')

		EXEC('DECLARE	    @discountDiscount     FLOAT,
		        @discountExtra        FLOAT,
		        @discountType         INT,
		        @discountNotes        NVARCHAR(250),
		        @discountAccountGUID  UNIQUEIDENTIFIER,
		        @PaerentTaxID         UNIQUEIDENTIFIER,
				@taxes				  FLOAT = 0.0,
				@IsAded				  BIT,
				@IsDisc				  BIT,
				@IsApplyOnPrevTax	  BIT, 
				@DiscTaxGUID		  UNIQUEIDENTIFIER = NULL , 
				@salesOrderItemsTotal   FLOAT , 
				@DeliveringFees			FLOAT , 
				@orderSalesAdded		FLOAT , 
				@orderSalesDiscount		FLOAT , 
				@OrderID UNIQUEIDENTIFIER , 
				@PreviousOrderID UNIQUEIDENTIFIER = 0x0

		
		DECLARE discountCursor CURSOR FAST_FORWARD 
			FOR 
		         (  SELECT  RD.[GUID] , RD.[Type],
		                        CASE 	 
		                             WHEN RT.IsPercent = 0 THEN RT.[Value] /100
		                             ELSE RT.[Value]
		                        END AS [Value],
		                        RD.[AccountID] AS [AccountID],
						  CASE 		 
		                             WHEN RD.[Notes] = '''' THEN RT.[Name]
							 ELSE RD.[Notes] + '' - '' +RT.[Name]
		                        END AS [Notes],
		                        RD.ParentTaxID,
						  RT.IsAddClc,
						  RT.IsDiscountClc,
						  RT.IsApplayOnPrevTaxes ,
						  o.SubTotal , 
						  o.Added , 
						  o.Discount , 
						  o.DeliveringFees , 
						  RD.ParentID 						 
		                 FROM   RestDiscTax000 RD
		            INNER JOIN RestTaxes000 rt ON  RT.Guid = RD.ParentTaxID
					INNER JOIN RestOrder000 o ON ParentID =  o.guid 
		             WHERE   ISNULL(RD.ParentTaxID, 0X0) <> 0x0	 )		                	
					ORDER BY [ParentID] , rt.Number	
		
		OPEN discountCursor 
		FETCH NEXT 
		FROM discountCursor 
		INTO @DiscTaxGUID , @discountType, @discountDiscount, @discountAccountGUID, @discountNotes , 
		@PaerentTaxID, @IsAded, @IsDisc, @IsApplyOnPrevTax, @salesOrderItemsTotal , @orderSalesAdded , 
		 @orderSalesDiscount , @DeliveringFees , @OrderID
		WHILE @@FETCH_STATUS = 0
		BEGIN
			IF	@PreviousOrderID <> @OrderID 
				SET @taxes = 0

			   IF (@discountDiscount < 1)
			   BEGIN
			       SET @discountDiscount = (@salesOrderItemsTotal + ((@DeliveringFees + @orderSalesAdded) * @IsAded) - (@orderSalesDiscount * @IsDisc) + (@taxes) * @IsApplyOnPrevTax) * (@discountDiscount) 
					SET @taxes = @taxes + @discountDiscount
			   END

			UPDATE RestDiscTax000 
			SET CalculatedValue = @discountDiscount
			WHERE GUID = @DiscTaxGUID

			SET @PreviousOrderID = @OrderID

			FETCH NEXT FROM discountCursor 
				INTO @DiscTaxGUID , @discountType, @discountDiscount, @discountAccountGUID, @discountNotes, 
		    @PaerentTaxID, @IsAded, @IsDisc, @IsApplyOnPrevTax, @salesOrderItemsTotal, @orderSalesAdded, 
		 @orderSalesDiscount , @DeliveringFees , @OrderID
		END 
		CLOSE discountCursor 
		DEALLOCATE discountCursor ' )

		EXEC ('
			UPDATE GCCTaxVatReportDetails000
			SET RecId = RecId + 180
			WHERE [Type] = 2 AND RecId < 200

			UPDATE GCCTaxVatReportDetails000
			SET RecId = RecId + 270
			WHERE [Type] = 3 AND RecId < 300

			UPDATE GCCTaxVatReportDetails000
			SET RecId = 199
			WHERE [Type] = 1 AND RecId = 17

			UPDATE GCCTaxVatReportDetails000
			SET RecId = 17
			WHERE [Type] = 1 AND RecId = 16

			UPDATE GCCTaxVatReportDetails000
			SET RecId = 299
			WHERE [Type] = 2 AND RecId = 25')
	END

	EXECUTE [prcAddIntFld] 'RestDeletedOrders000', 'OldState', -1
	EXECUTE [prcAddBitFld]	'RestTaxes000' , 'IsActive' , 1
	EXECUTE [prcAddCharFld] 'pt000' , 'TransferedInfo' , 2048
	--- End CMPT06

	IF([dbo].[fnObjectExists]('fnGetLastNumric') = 1)
		DROP FUNCTION fnGetLastNumric
		
	IF([dbo].[fnObjectExists]('fnPOSSD_Station_GetCustomerArea') = 1)
		DROP FUNCTION  fnPOSSD_Station_GetCustomerArea
	
	EXEC prcDropFld 'POSSDStationAddressArea000', 'IsAdded'

	EXEC [prcAddGUIDFld] 'POSSDStationDeliveryArea000', 'AreaGUID'

	EXEC [prcAddGUIDFld] 'POSSDStationOrder000', 'DefaultCustomerCityGUID'

	EXEC [prcAddGUIDFld] 'POSSDStationOrder000', 'DefaultCustomerCountryGUID'
######################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From100092238
AS
	EXEC [prcAddFloatFld] 'DistDeviceStatement000', 'BonusQty'
	
	IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS 
				WHERE CONSTRAINT_NAME ='DF__POSSDTicke__Area__0A895299')
	BEGIN
		ALTER TABLE POSSDTicketOrderInfo000 DROP CONSTRAINT DF__POSSDTicke__Area__0A895299
		EXEC prcDropFld 'POSSDTicketOrderInfo000', 'Area'
	END
	
	EXEC prcAddGUIDFld 'POSSDTicketOrderInfo000','AreaGUID'
	EXEC prcAddGUIDFld 'POSSDTicketOrderInfo000','CustomerAddressGUID'

	EXEC [prcAddFloatFld] 'DiscountTypesCard000', 'DailyPackage'
	EXEC prcAddBitFld 'bt000','ShowOrderEvaluation', 0

	IF [dbo].[fnObjectExists]('bt000.defCustomerAccGuid') != 0
	BEGIN 
		EXEC('UPDATE bt000 SET DefMainAccount = defCustomerAccGuid WHERE ISNULL(defCustomerAccGuid, 0x0) != 0x0')
		EXEC prcDropFld 'bt000', 'defCustomerAccGuid'
	END
	IF [dbo].[fnObjectExists]('bt000.defGroupGuid') != 0
	BEGIN 
		EXEC('UPDATE bt000 SET DefaultGroupGUID = defGroupGuid WHERE ISNULL(defGroupGuid, 0x0) != 0x0')
		EXEC prcDropFld 'bt000', 'defGroupGuid'
	END

	-- CMPT07
	EXECUTE prcAddIntFld 'POSOrderItemsTemp000', 'MatBarcode'
	EXECUTE prcAddIntFld 'POSOrderItems000', 'MatBarcode'
	EXECUTE prcAddCharFld 'MatExBarcode000' , 'Notes' , 256

	EXECUTE [PrcAddBitFld] 'bt000', 'bFixBranch'
	EXECUTE [PrcAddBitFld] 'bt000', 'bFixCurrency'
	EXECUTE [PrcAddBitFld] 'bt000', 'bFixStore'

	IF (EXISTS (SELECT GUID FROM BT000 WHERE TYPE = 2 AND SortNum IN (3, 4, 7, 8)))
	BEGIN
		DECLARE @IntransGuid UNIQUEIDENTIFIER = (SELECT GUID FROM BT000 WHERE TYPE = 2 AND SortNum = 3)
		DECLARE @OuttransGuid UNIQUEIDENTIFIER = (SELECT GUID FROM BT000 WHERE TYPE = 2 AND SortNum = 4)
		DECLARE @entryIntransInGuid UNIQUEIDENTIFIER = (SELECT GUID FROM BT000 WHERE TYPE = 2 AND SortNum = 7)
		DECLARE @entryOuttransGuid UNIQUEIDENTIFIER = (SELECT GUID FROM BT000 WHERE TYPE = 2 AND SortNum = 8)
		
		DECLARE @maxNum INT = (SELECT MAX(SortNum) FROM BT000 BT INNER JOIN TT000 TT ON BT.GUID = TT.OutTypeGUID)

		UPDATE BT000 SET SortNum = ISNULL(@maxNum, 0) + 1, Abbrev = N'إد.م', Name = N'إد.عملية مناقلة', LatinAbbrev = N'In.Tr', LatinName = N'In.Transposition', TYPE = 4, BillType = 0, bNoEntry = 1 WHERE GUID = @IntransGuid
		UPDATE BT000 SET SortNum = ISNULL(@maxNum, 0) + 1, Abbrev = N'إخ.م', Name = N'إخ.عملية مناقلة', LatinAbbrev = N'Ou.Tr', LatinName = N'Ou.Transposition', TYPE = 3, BillType = 0, bNoEntry = 1 WHERE GUID = @OuttransGuid
		UPDATE BT000 SET SortNum = ISNULL(@maxNum, 0) + 2, Abbrev = N'إد.م.بقيد', Name = N'إد.عملية مناقلة بقيد', LatinAbbrev = N'In.Tr.En', LatinName = N'In.Transposition with Entry', TYPE = 4, BillType = 0, bGenContraAcc = 1 WHERE GUID = @entryIntransInGuid
		UPDATE BT000 SET SortNum = ISNULL(@maxNum, 0) + 2, Abbrev = N'إخ.م.بقيد', Name = N'إخ.عملية مناقلة بقيد', LatinAbbrev = N'Ou.Tr.En', LatinName = N'Ou.Transposition with Entry', TYPE = 3, BillType = 0, bGenContraAcc = 1 WHERE GUID = @entryOuttransGuid

		INSERT INTO tt000
			(GUID, InTypeGUID, OutTypeGUID, ExtraBelongsToIn, ExtraBelongsToOut, DiscBelongsToIn, DiscBelongsToOut, ClassBelongsToIn, ClassBelongsToOut)
		VALUES 
			(NEWID(), @IntransGuid, @OuttransGuid, 1, 0, 1, 0, 1, 1),
			(NEWID(), @entryIntransInGuid, @entryOuttransGuid, 1, 0, 1, 0, 1, 1)

		INSERT INTO TS000 (GUID, OutBillGUID)
		SELECT NEWID(), GUID
		FROM BU000 WHERE TypeGUID IN (@OuttransGuid, @entryOuttransGuid)

		UPDATE ts000 SET InBillGUID = INBILL.GUID
		FROM TS000 TS 
		INNER JOIN bu000 OUTBILL ON TS.OutBillGUID = OUTBILL.GUID
		INNER JOIN bu000 INbILL ON INBILL.Number = OUTBILL.NUMBER 
		AND INBILL.TypeGUID = @IntransGuid AND OUTBILL.TypeGUID = @OuttransGuid

		UPDATE ts000 SET InBillGUID = INBILL.GUID
		FROM TS000 TS 
		INNER JOIN bu000 OUTBILL ON TS.OutBillGUID = OUTBILL.GUID
		INNER JOIN bu000 INbILL ON INBILL.Number = OUTBILL.NUMBER 
		AND INBILL.TypeGUID = @entryIntransInGuid AND OUTBILL.TypeGUID = @entryOuttransGuid
	END
	
	IF NOT EXISTS (SELECT * FROM ui000 WHERE ReportId = 536919688)
	BEGIN
	    INSERT INTO ui000
	    SELECT NEWID(),u.GUID ,536919688 ,0x ,1 ,0 ,1 FROM us000 AS u WHERE bAdmin <> 1
	
	    UPDATE us000 SET Dirty = 1 WHERE bAdmin <> 1
	END
	
	IF NOT EXISTS (SELECT * FROM ui000 WHERE ReportId = 536961170)
	BEGIN
		INSERT INTO ui000
		SELECT NEWID(),u.GUID ,536961170 ,0x ,1 ,0 ,1 FROM us000 AS u WHERE bAdmin <> 1
	
		UPDATE us000 SET Dirty = 1 WHERE bAdmin <> 1
	END

	EXECUTE prcAddCharFld 'ac000' , 'AccMenuName' , 256
	EXECUTE prcAddCharFld 'ac000' , 'AccMenuLatinName' , 256
	-- END CMPT07

	-- DistDistributionLines000
	EXECUTE [prcAddDateFld] 'DistDistributionLines000', 'Route1Time'
	EXECUTE [prcAddDateFld] 'DistDistributionLines000', 'Route2Time'
	EXECUTE [prcAddDateFld] 'DistDistributionLines000', 'Route3Time'
	EXECUTE [prcAddDateFld] 'DistDistributionLines000', 'Route4Time'
	IF [dbo].[fnObjectExists]('cp000.BiGUID') = 0
	BEGIN 
		EXEC prcAddGUIDFld 'cp000', 'BiGUID'

		IF NOT EXISTS(SELECT * FROM mc000 WHERE Number = 1024 AND Asc1 = 'ReCalcBillCP' AND Num1 = 1)
		BEGIN
			INSERT INTO mc000(Number, Asc1, Num1) VALUES (1024, 'ReCalcBillCP', 1)
		END
	END

	EXEC prcAddBitFld 'cp000', 'IsTransfered', 0	
	EXEC prcDropProcedure 'prcBill_recalcCP'

	EXEC prcAddGUIDFld 'POSSDExternalOperation000', 'RelatedToGUID'
	EXEC prcAddIntFld  'POSSDExternalOperation000', 'RelatedToType', 0
	EXEC prcAddGUIDFld 'POSSDStationOrder000', 'DeliveryFeeAccountGUID'

	IF [dbo].[fnObjectExists]('RestOrder000.IsManualPrinted') = 0
	BEGIN 
		EXECUTE [prcAddBitFld] 'RestOrder000', 'IsManualPrinted'

		EXEC prcDisableTriggers 'RestOrder000', 1
		EXEC ('UPDATE [RestOrder000] SET IsManualPrinted = 1')			
		EXEC prcEnableTriggers 'RestOrder000'
	END 

	IF [dbo].[fnObjectExists]('RestOrderTemp000.IsManualPrinted') = 0
	BEGIN 
		EXECUTE [prcAddBitFld] 'RestOrderTemp000', 'IsManualPrinted'

		EXEC prcDisableTriggers 'RestOrderTemp000', 1
		EXEC ('UPDATE [RestOrderTemp000] SET IsManualPrinted = 1 WHERE IsPrinted > 0')			
		EXEC prcEnableTriggers 'RestOrderTemp000'
	END 
######################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From100092395
AS
	SET NOCOUNT ON
	EXEC [prcRenameFld] 'POSSDStationSyncModifiedData000', 'IsDataSync',  'IsNewDataSync'
	EXECUTE [prcAddCharFld]	'POSSDStationSyncModifiedData000', 'DeviceID', 250
	EXECUTE [prcAddIntFld]	'POSSDStationSyncModifiedData000' , 'IsModifiedDataSync' , -1

	IF EXISTS (SELECT * FROM sys.indexes WHERE name = 'POSSDStationSyncModifiedData000_Key_0')
    BEGIN
        DROP INDEX POSSDStationSyncModifiedData000_Key_0  ON POSSDStationSyncModifiedData000;  
    END 

    CREATE UNIQUE NONCLUSTERED INDEX POSSDStationSyncModifiedData000_Key_0 ON POSSDStationSyncModifiedData000
    (
		StationGuid ASC,
		DeviceID ASC,
		RelatedToObject ASC,
		ReleatedToObjectGuid ASC
    )

	EXECUTE [PrcAddBitFld] 'DistDeviceBt000', 'IsStopDate'
	EXECUTE [prcAddDateFld] 'DistDeviceBt000', 'StopDate'
	EXECUTE [PrcAddBitFld] 'DistDeviceEt000', 'IsStopDate'
	EXECUTE [prcAddDateFld] 'DistDeviceEt000', 'StopDate'

	IF EXISTS( SELECT I.name
			    FROM sys.indexes AS I
			    INNER JOIN sys.tables AS T ON I.[object_id] = T.[object_id]
			    WHERE T.name = 'POSSDTicket000' AND I.name = 'POSSDTicket000_Key_0' )
	 BEGIN 
		DROP INDEX POSSDTicket000_Key_0 ON POSSDTicket000;
	 END

	 CREATE UNIQUE INDEX POSSDTicket000_Key_0
	ON POSSDTicket000 ([Number], [Code], [ShiftGUID], [Type], [OrderType]);


	IF EXISTS (SELECT * FROM sys.indexes WHERE name = 'POSSDStationSyncModifiedData000_Key_1')
    BEGIN
        DROP INDEX POSSDStationSyncModifiedData000_Key_1  ON POSSDStationSyncModifiedData000;  
    END 

    CREATE NONCLUSTERED INDEX POSSDStationSyncModifiedData000_Key_1 ON POSSDStationSyncModifiedData000
    (
		[StationGuid] ASC,
		[DeviceID] ASC,
		[RelatedToObject] ASC,
		[ReleatedToObjectGuid] ASC,
		[IsNewDataSync] ASC,
		[IsModifiedDataSync] ASC
    )

	EXEC prcDropFld 'POSSDStationResale000', 'bPrintReturnCoupon'
######################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From100092400 
AS

	EXEC(N'UPDATE BP000 SET [Type] = 0 WHERE [Type] IS NULL');
	
	EXEC [prcAddBitFld] 'POSSDStation000', 'bReprintAfterDeliveryStart', 0
	EXEC('UPDATE BillColected000 SET [GUID] = NEWID() WHERE ISNULL([GUID], 0x0) = 0x0');
######################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From100092781
AS

	EXECUTE [prcAddCharFld]	'POSSDStationDevice000', 'DeviceConnectionID', 300

	EXECUTE [prcAddBitFld] 'POSSDSpecialOffer000', 'IsForcedToStop', 0
	EXECUTE [prcAddIntFld] 'POSSDStation000', 'RoundingType', 0
	
	EXEC [prcAddFloatFld] 'POSSDStation000', 'RoundingPrecision', 0

	IF [dbo].[fnObjectExists]('MN000.branchMask') = 0
	BEGIN
		EXEC [prcAddFld] 'MN000', 'branchMask', 'INT'

		EXEC ('UPDATE Mn
			SET Mn.branchMask = Fm.branchMask
			FROM MN000 Mn INNER JOIN FM000 Fm 
			ON Mn.FormGUID = Fm.GUID AND Mn.Type = 0')

		EXEC ('UPDATE cu
				SET cu.MaxDebit = cu.MaxDebit * ac.CurrencyVal
			  FROM cu000 cu INNER JOIN ac000 ac 
				ON cu.AccountGUID = ac.GUID')
		
	END

######################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From100092879
AS

	EXECUTE PrcAddBitFld   'POSSDTicket000', 'NetIsRounded', 0
	EXECUTE PrcAddBitFld   'POSSDTicket000', 'IsDiscountPercentageBeforRounding', 0
	EXECUTE PrcAddBitFld   'POSSDTicket000', 'IsAdditionPercentageBeforRounding', 0
	EXECUTE prcAddFloatFld 'POSSDTicket000', 'DiscountValueBeforRounding', 0
	EXECUTE prcAddFloatFld 'POSSDTicket000', 'AdditionValueBeforRounding', 0

	EXEC prcAlterFld N'POSOrderItemsTemp000', N'MatBarcode', N'NVARCHAR(100)',1, ''''''
	EXEC prcAlterFld N'POSOrderItems000', N'MatBarcode', N'NVARCHAR(100)',1, ''''''

	IF [dbo].[fnObjectExists]('POSSDTicket000.AdditionValueBeforRounding') = 0
	BEGIN
		EXEC prcChangeDefault 'mt000','CreateDate','GETDATE()'

		EXEC('
		EXEC prcDisableTriggers	''mt000''
	
		UPDATE MT1
		SET MT1.CreateDate = MT2.CreateDate
		FROM mt000 MT1 
		INNER JOIN mt000 MT2 ON MT1.Parent = MT2.GUID
		EXEC prcEnableTriggers ''mt000''
		');
	END
	
	EXEC ('UPDATE POSen 
			SET BranchGUID = ce.Branch 
		FROM POSPayRecieveTable000 POSen
	        INNER JOIN ce000 ce ON ce.[GUID] = POSen.[GUID]
		WHERE ISNULL(BranchGUID, 0x0) = 0x0 ')
######################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From100092985
AS
	EXECUTE PrcAddBitFld 'BT000', N'bForceSNInRSales', 0

	IF EXISTS(select * from 
	bi000 AS BI1
	INNER JOIN bi000 AS BI2 ON BI1.ParentGUID = BI2.ParentGUID AND BI1.GUID <> BI2.GUID AND BI1.Number = BI2.Number)
	BEGIN
		EXEC prcDisableTriggers 'BI000'

		EXEC('UPDATE bi
			SET bi.Number = RenumberdItem.Renumberd
			FROM bi000 AS bi
			CROSS APPLY (
					SELECT
						Number,
						ParentGUID,
						GUID,
						ROW_NUMBER() OVER(PARTITION BY ParentGUID Order BY Number) - 1 AS Renumberd
					FROM
						bi000
					WHERE ParentGUID = bi.ParentGUID
					
					) AS RenumberdItem 
		WHERE RenumberdItem.GUID = bi.GUID AND bi.Number <> RenumberdItem.Renumberd')

		EXEC prcEnableTriggers 'BI000'
	END

	EXECUTE [prcAddDateFld] 'POSSDShift000', 'OpenDateUTC'
	EXECUTE [prcAddDateFld] 'POSSDShift000', 'CloseDateUTC'
	EXEC [prcAddGUIDFld] 'POSSDTicketOrderInfo000', 'StationGUID'
	EXECUTE [prcAddDateFld] 'POSSDTicketOrderInfo000', 'ETDUTC'
	EXECUTE [prcAddDateFld] 'POSSDTicketOrderInfo000', 'EDDUTC'

	-- Delete duplicated options caused by replication prior to solve bug 204424
	IF EXISTS(SELECT 1 FROM FileOP000 OP1 JOIN FileOp000 OP2 ON OP1.Name = OP2.Name AND OP1.GUID <> OP2.GUID)
	BEGIN
		DELETE OP2
		FROM
		FileOP000 OP1
		JOIN FileOp000 OP2 ON OP1.Name = OP2.Name AND OP1.GUID <> OP2.GUID
	END

	-- Delete duplicated options caused by replication prior to solve bug 204424
	IF EXISTS(SELECT 1 FROM UserOP000 OP1 JOIN UserOP000 OP2 ON OP1.Name = OP2.Name AND OP1.GUID <> OP2.GUID AND OP1.UserID = OP2.UserID)
	BEGIN
		DELETE OP2
		FROM
		UserOP000 OP1
		JOIN UserOP000 OP2 ON OP1.Name = OP2.Name AND OP1.GUID <> OP2.GUID AND OP1.UserID = OP2.UserID
	END

	IF EXISTS(SELECT 1 FROM PcOP000 OP1 JOIN PcOP000 OP2 ON OP1.Name = OP2.Name AND OP1.CompName = OP2.CompName AND OP1.GUID <> OP2.GUID)
	BEGIN
		DELETE OP2
		FROM
		PcOP000 OP1
		JOIN PcOP000 OP2 ON OP1.Name = OP2.Name AND OP1.CompName = OP2.CompName AND OP1.GUID <> OP2.GUID
	END

	EXEC prcAlterFld N'POSOrderItemsTemp000', N'MatBarcode', N'NVARCHAR(100)',1, ''''''
	EXEC prcAlterFld N'POSOrderItems000', N'MatBarcode', N'NVARCHAR(100)',1, ''''''

######################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From100093006
AS

	-- JOC03 Start
	EXECUTE [prcAddDateFld] 'JobOrder000', 'TargetEndDate'
	EXECUTE [prcAddGUIDFld]'Manufactory000', 'DirectExpensesEntryTypeGuid'

	EXEC ('UPDATE JobOrder000 SET TargetEndDate = StartDate where TargetEndDate = ''1980-01-01 00:00:00.000''')
	EXECUTE [prcAddFld] 'JOCJobOrderCosts000', 'TotalDirectExpenses', 'MONEY'
	EXECUTE [prcAddGUIDFld] 'JOCBOMJobOrderEntry000', 'TypeGuid'
	
	EXECUTE PrcAddBitFld  'ProductionLine000', 'IsActualCostSaved', 0
	
	EXECUTE PrcAddBitFld  'Plcosts000', 'IsActualCostSaved', 0
	EXEC prcAddBitFld 'JOCBOM000', 'UseSpoilage', 0
	EXEC prcAddBitFld 'JOCJobOrderOperatingBOM000 ', 'UseSpoilage', 0

	IF NOT EXISTS(SELECT j.[Guid] FROM JobOrder000 J INNER JOIN JOCJobOrderCosts000 C ON C.JobOrderGuid = J.[Guid])
	BEGIN
		INSERT INTO JOCJobOrderCosts000 (JobOrderGuid, FinishedMaterialGuid, RequiredQty)
		SELECT JobOrder.[Guid],
			   FinishedGoods.MaterialGuid,
			   FinishedGoods.Quantity * JobOrder.PlannedProductionQty
		FROM JOCOperatingBOMFinishedGoods000 FinishedGoods 
		INNER JOIN JOCvwJobOrderFinishedGoodsBillItemsQtys FinishedGoodsQtys ON FinishedGoodsQtys.MaterialGuid = FinishedGoods.[MaterialGuid]
		INNER JOIN JobOrder000 JobOrder ON (JobOrder.[Guid] = FinishedGoodsQtys.[JobOrderGuid] AND FinishedGoods.[OperatingBOMGuid] = JobOrder.[OperatingBOMGuid])	
		WHERE JobOrder.IsActive = 1
	END
	
	-- JOC03 End


	EXEC prcAlterFld N'POSSDStationOrder000', N'DefaultCustomerCityGUID', N'NVARCHAR(250)'
	EXEC prcAlterFld N'POSSDStationOrder000', N'DefaultCustomerCityGUID', N'UNIQUEIDENTIFIER'

	EXEC prcAlterFld N'POSSDStationOrder000', N'DefaultCustomerCountryGUID', N'NVARCHAR(250)'
	EXEC prcAlterFld N'POSSDStationOrder000', N'DefaultCustomerCountryGUID', N'UNIQUEIDENTIFIER'

######################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From100093025
AS
	-- Start POSNF01
	IF [dbo].[fnObjectExists]('POSOrder000.CurrencyValue') =  0
	BEGIN
		EXEC [prcAddFloatFld] 'POSOrder000', 'CurrencyValue'
		EXEC ('
			UPDATE ord SET [CurrencyValue] = my.CurrencyVal FROM POSOrder000 ord INNER JOIN my000 my ON ord.CurrencyID = my.GUID
			UPDATE POSOrder000 SET [CurrencyValue] = 1 WHERE ISNULL([CurrencyValue], 0) = 0 ')
	END

	IF [dbo].[fnObjectExists]('POSOrderTemp000.CurrencyValue') =  0
	BEGIN
		EXEC [prcAddFloatFld] 'POSOrderTemp000', 'CurrencyValue'
		EXEC ('
			UPDATE ord SET [CurrencyValue] = my.CurrencyVal FROM POSOrderTemp000 ord INNER JOIN my000 my ON ord.CurrencyID = my.GUID
			UPDATE POSOrderTemp000 SET [CurrencyValue] = 1 WHERE ISNULL([CurrencyValue], 0) = 0 ')
	END

	IF [dbo].[fnObjectExists]('bgi000.Unit') = 0
	BEGIN
		EXEC prcAddIntFld 'bgi000', 'Unit', 0

		EXEC ('	
			DELETE bgi 
			FROM 
				bgi000  bgi
				INNER JOIN bg000 bg ON bgi.ParentID = bg.Guid
				INNER JOIN POSConfig000 cfg ON bg.ConfigID = cfg.GUID
			WHERE Command = 6128 OR Command = 6130 ')

		EXEC ('
			UPDATE  Cur
			SET 
				Cur.Paid     = -1 * ABS(Cur.Paid),
				Cur.Value    = -1 * ABS(Cur.Value),
				Cur.Returned = -1 * ABS(Cur.Returned)
			FROM 
				POSPaymentsPackageCurrency000 Cur 
				INNER JOIN POSPaymentsPackage000 Pack ON Pack.[GUID] = Cur.ParentID 
				INNER JOIN POSOrder000 O ON Pack.[GUID] = O.PaymentsPackageID
			WHERE O.SubTotal < 0 ') 
	END
	-- End POSNF01

	-- Start POSNF02
	EXEC prcAddGUIDFld	'POSOrder000',				'LoyaltyCardGUID'
	EXEC prcAddGUIDFld	'POSOrder000',				'LoyaltyCardTypeGUID'
	EXEC prcAddIntFld	'POSOrder000',				'PointsCount',		0
	EXEC prcAddGUIDFld	'POSOrderTemp000',			'LoyaltyCardGUID'
	EXEC prcAddGUIDFld	'POSOrderTemp000',			'LoyaltyCardTypeGUID'
	EXEC prcAddIntFld	'POSOrderTemp000',			'PointsCount',		0
	EXEC prcAddGUIDFld	'RestOrder000',				'LoyaltyCardGUID'
	EXEC prcAddGUIDFld	'RestOrder000',				'LoyaltyCardTypeGUID'
	EXEC prcAddIntFld	'RestOrder000',				'PointsCount',		0
	EXEC prcAddGUIDFld	'RestOrderTemp000',			'LoyaltyCardGUID'
	EXEC prcAddGUIDFld	'RestOrderTemp000',			'LoyaltyCardTypeGUID'
	EXEC prcAddIntFld	'RestOrderTemp000',			'PointsCount',		0

	EXEC prcAddBitFld 'POSUserBills000', 'UseLoyaltyCard'	
	-- End POSNF02
######################################################################################
CREATE PROCEDURE prcUpgradeDatabase_From100093043
AS
	EXEC('UPDATE BT000 SET bNoPost = 0, bAutoPost = 1 WHERE Type IN(9,10)');

	IF [dbo].[fnObjectExists]('Manufactory000.InsertNumber') = 0
	BEGIN
		EXEC prcAddIntFld 'Manufactory000', 'InsertNumber', 0 
		
		EXEC('UPDATE Manufactory000 SET InsertNumber = Number');
	END
######################################################################################
#END