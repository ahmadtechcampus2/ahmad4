###############################################################################
CREATE PROCEDURE prcReBulidViewWithNoSons
		@DsViewName NVARCHAR(100),
		@SrcView	NVARCHAR(100),
		@SrcTbl		NVARCHAR(100),
		@OpName		NVARCHAR(100)
AS
	DECLARE @Sql NVARCHAR(max)
	SET @Sql = 'ALTER VIEW ' +  @DsViewName + CHAR(13)
	SET @Sql = @Sql + 'AS'+ CHAR(13)
	SET @Sql = @Sql + 'SELECT * FROM ' + @SrcView + ' a' + CHAR(13)
	DECLARE @OpValue NVARCHAR(100) = (SELECT Value from op000 where [name] = @OpName)
	
	IF (@OpValue = 1)		
		SET @Sql = @Sql + '	WHERE [a].[Guid] NOT IN (SELECT DISTINCT [b].[ParentGUID] FROM ' + @SrcTbl + ' [b] WHERE [b].[ParentGUID] = [a].[guid] AND [b].[ParentGUID] <> 0X00 )'

	IF (@OpValue = 1 AND @SrcTbl ='st000')
		SET @Sql = @Sql + ' AND [a].[Kind] <> 1'

	EXEC (@Sql)
###############################################################################
CREATE PROCEDURE prcReBulidViewsWithNoSons
AS
	EXEC prcReBulidViewWithNoSons 'vdCoNoSons','fnGetCostCenters(5)','fnGetCostCenters(5)','AmncfNotallowmainCost'
	EXEC prcReBulidViewWithNoSons 'vdStNoSons','vdSt','st000','AmncfNotallowmainStore'
	EXEC prcReBulidViewWithNoSons 'vdGrNoSons','vdGr','gr000','AmncfNotallowmainGroup'
###############################################################################
CREATE PROC prcFinalizeDatabase
AS
	-- install branch related tables:	
	EXEC [prcBranch_InstallBRTs]
	EXEC [prcCheckDBProc_init]
	EXEC [prcBTSortCostPrice_Install]
	EXEC [prcStrings_init]
	EXEC [prcUser_SetDirtyFlag]	
	-- call ameen extender build procedure if item security is enabled
	EXEC [prcItemSecurityExtended_InstallISRTs]
	EXEC [prc_InstallZeroValue]

	-- POSSD Initialize Table 
	EXEC [prcPOSSD_PrintDesign_InitType]

	INSERT INTO op000 values (NEWID(),'AmnCfg_UPDATEORDERPAYMENTSANDPOST',0, 0, '' ,NULL, 0, 0x0, 0x0 )
	INSERT INTO op000 values (NEWID(),'AmnCfg_UPDATEORITABLE',0, 0, '' ,NULL, 0, 0x0, 0x0 )

	IF EXISTS(SELECT * FROM OP000 WHERE NAME LIKE 'AmncfgMultiFiles' AND [Value] = '1')
		EXEC prcMultiFiles
	EXEC prcReBulidViewsWithNoSons

	IF EXISTS(SELECT * FROM mc000 WHERE Number = 1024 AND Asc1 = 'ReCalcBillCP' AND Num1 = 1)
	BEGIN
		EXEC prcCP_Recalc
		DELETE FROM mc000 WHERE Number = 1024 AND Asc1 = 'ReCalcBillCP' AND Num1 = 1
	END

	IF EXISTS(SELECT * FROM mc000 WHERE Number = 1025 AND Asc1 = 'GCC3_UPGRADE' AND Num1 = 1)
	BEGIN
		DECLARE 
			@C CURSOR,
			@BillGUID UNIQUEIDENTIFIER,
			@EntryNumber INT 
		
		DECLARE @BU TABLE (SortNum INT, BuDate DATE, BuNumber INT, BuGUID UNIQUEIDENTIFIER, CeNumber INT)

		INSERT INTO @BU 
		SELECT DISTINCT [bt].[SortNum], [bu].[Date], [bu].[Number], BU.[GUID], ce.Number
		FROM 
			bu000 bu
			INNER JOIN bi000 bi ON bu.GUID = bi.ParentGUID 
			INNER JOIN er000 er ON bu.GUID = er.ParentGUID 
			INNER JOIN ce000 ce ON ce.GUID = er.EntryGUID 
			INNER JOIN en000 en ON ce.GUID = en.ParentGUID 
			INNER JOIN bt000 bt ON bt.GUID = bu.TypeGUID 
		WHERE en.[Type] IN (205, 206, 207, 208) 

		SET @C = CURSOR FAST_FORWARD FOR 
			SELECT BuGUID, CeNumber
			FROM @BU
			ORDER BY [SortNum], [BuDate], [BuNumber]

		OPEN @C FETCH NEXT FROM @C INTO @BillGUID, @EntryNumber
		WHILE @@FETCH_STATUS = 0
		BEGIN
			EXEC prcBill_GenEntry @BillGUID, @EntryNumber
			FETCH NEXT FROM @C INTO @BillGUID, @EntryNumber
		END CLOSE @C DEALLOCATE @C 

		IF EXISTS(SELECT 1 FROM bi000 WHERE TaxCode = 6 /*OA*/ AND ISNULL(OrginalTaxCode, 0) = 0)
		BEGIN
			EXEC prcDisableTriggers 'bi000', 1;
		
			EXEC('
			UPDATE BI000 SET OrginalTaxCode = TaxCode WHERE ISNULL(TaxCode, 0) != 0 AND ISNULL(TaxCode, 0) != 6 /*OA*/
			
			;WITH BU AS
			(
				SELECT
					BU.GUID,
					BU.TypeGUID,
					ISNULL(VCT.TaxCode, 0) AS CustTaxCode,
					ISNULL(L.Classification, 0) AS CustClassification,
					CASE ISNULL(L.IsSubscribed, 0) WHEN 1 THEN CASE WHEN BU.Date >= SubscriptionDate THEN 1 ELSE 0 END ELSE 0 END AS CustIsSubscribed
				FROM
					bu000 AS BU
					INNER JOIN bi000 BI ON BU.GUID = BI.ParentGUID
					LEFT JOIN GCCCustomerTax000 AS VCT ON BU.CustGUID = VCT.CustGUID AND VCT.TaxType = 1 /*1 VAT*/
					LEFT JOIN cu000 AS CU ON BU.CustGUID = CU.GUID
					LEFT JOIN GCCCustLocations000 AS L ON L.GUID = CU.GCCLocationGUID
				WHERE BI.TaxCode = 6
			)

			UPDATE BI
			SET 
				BI.OrginalTaxCode = 
					ISNULL(dbo.fnGCCGetBillItemTaxCode(VGMT.TaxCode, BU.CustTaxCode, BU.TypeGUID, BU.CustClassification, BU.CustIsSubscribed, 0/*IsOA*/, 0 /*IsCalcTaxForPUTaxCode*/), 0)
			FROM
				bi000 AS BI
				INNER JOIN BU AS BU ON BI.ParentGUID = BU.GUID
				LEFT JOIN GCCMaterialTax000 AS VGMT ON VGMT.MatGUID = BI.MatGUID AND VGMT.TaxType = 1 /*1 VAT*/
			WHERE
				BI.TaxCode = 6;');

			EXEC prcEnableTriggers 'bi000';
		END

		DELETE FROM mc000 WHERE Number = 1024 AND Asc1 = 'GCC3_UPGRADE' AND Num1 = 1
	END

	IF EXISTS(SELECT * FROM mc000 WHERE Number = 1026 AND Asc1 = 'Bill_Repost' AND Num1 = 1)
	BEGIN 
		EXEC prcBill_Repost 1, 1
		DELETE FROM mc000 WHERE Number = 1026 AND Asc1 = 'Bill_Repost' AND Num1 = 1
	END 
###############################################################################
#END