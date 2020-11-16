#########################################################
CREATE PROCEDURE PrcReOrderingMNPS
	@DestDBName	[NVARCHAR](255)
as	
	DECLARE @Str [NVARCHAR](max)
	IF SUBSTRING(@DestDBName, 1, 1) != '['
		SET @DestDBName = '[' + @DestDBName + ']'

	SET @Str = 'UPDATE '+@DestDBName+'..MNPS000  
					SET Number =(select rownum from (
				SELECT  *,
						row_number() OVER(ORDER BY NUMBER ) AS rownum
						FROM MNPS000) as res1
						where guid='+@DestDBName+'..MNPS000.guid)
						'
			
	EXEC (@Str)

############################################################
CREATE PROCEDURE prcReTrance
	@DestDBName	[NVARCHAR](255),
	@UpdatePreTransferedData bit,
	@d Date
AS
	SET NOCOUNT ON
	BEGIN TRAN 		
	IF SUBSTRING(@DestDBName, 1, 1) != '['
		SET @DestDBName = '[' + @DestDBName + ']'

	DECLARE @Str [NVARCHAR](max)
	-- For FirstPerid Bills
	SET @Str = 'ALTER TABLE ' + @DestDBName + '..[bu000] DISABLE TRIGGER ALL'
		EXEC sp_executesql @Str
	SET @Str = 'UPDATE [BU] SET [IsPosted] = 0 FROM '+@DestDBName+'..[BU000] AS [BU] INNER JOIN ' +@DestDBName +'..[MC000] AS [MC] ON CAST ([BU].[GUID] AS [NVARCHAR](256))=  [ASC2]  WHERE [MC].[TYPE] IN (36, 40)'
		EXEC sp_executesql @Str
	SET @Str = 'ALTER TABLE ' + @DestDBName + '..[bu000] ENABLE TRIGGER ALL'
		EXEC sp_executesql @Str
	SET @Str = 'DELETE [BU]  FROM '+@DestDBName+'..[BU000] AS [BU] INNER JOIN ' +@DestDBName +'..[MC000] AS [MC] ON CAST ([BU].[GUID] AS [NVARCHAR](256))=  [ASC2]  WHERE [MC].[TYPE] IN (36, 40)'
		EXEC sp_executesql @Str

	--For Opening Entry
	SET @Str = 'ALTER TABLE ' + @DestDBName + '..[CE000] DISABLE TRIGGER ALL'
		EXEC sp_executesql @Str
	SET @Str = 'UPDATE [ce]  SET [IsPosted] = 0 FROM '+@DestDBName+'..[CE000] AS [ce] INNER JOIN ' +@DestDBName +'..[MC000] AS [MC] ON CAST ([ce].[GUID] AS [NVARCHAR](256))=  [ASC2]  WHERE [MC].[TYPE] = 36'
		EXEC sp_executesql @Str
	SET @Str = 'ALTER TABLE ' + @DestDBName + '..[CE000] ENABLE TRIGGER ALL'
		EXEC sp_executesql @Str
	SET @Str = 'DELETE [ce] FROM '+@DestDBName+'..[CE000] AS [ce] INNER JOIN ' +@DestDBName +'..[MC000] AS [MC] ON CAST ([ce].[GUID] AS [NVARCHAR](256))=  [ASC2]  WHERE [MC].[TYPE] = 36'
		EXEC sp_executesql @Str
	SET @Str = ' 
		UPDATE c set isposted = 0 FROM  '+@DestDBName+'..ce000 c INNER JOIN  '+@DestDBName+'..er000 er on er.EntryGUID = c.GUID 
		 inner join  '+@DestDBName+'..mc000 m on m.Asc2 = CAST(er.Parentguid as NVARCHAR(36))
		 
		 DELETE c  FROM  '+@DestDBName+'..ce000 c INNER JOIN  '+@DestDBName+'..er000 er on er.EntryGUID = c.GUID 
		 inner join  '+@DestDBName+'..mc000 m on m.Asc2 = CAST(er.Parentguid as NVARCHAR(36))
		DELETE py FROM  '+@DestDBName+'..py000 py inner join  '+@DestDBName+'..mc000 m on m.Asc2 = CAST(py.[Guid] as NVARCHAR(36))'
		EXEC sp_executesql @Str
	SET @Str = 'DELETE '+ @DestDBName +'..[SN000] WHERE [INGUID] NOT IN (SELECT  [GUID] FROM  '+ @DestDBName +'..[BI000]) '
   		EXEC sp_executesql @Str

	SET @Str = 'DELETE '+ @DestDBName +'..[MC000] WHERE [TYPE] IN (36, 40) '
   		EXEC sp_executesql @Str
   	SET @Str = 'Guid Not IN (SELECT [GUID] FROM ' + @DestDBName + '..[my000]) '
	EXEC [prcCopyTbl] @DestDBName,'my000',@Str,1,0
	SET @Str = 'Guid Not IN (SELECT [GUID] FROM ' + @DestDBName + '..[gr000]) '
	EXEC [prcCopyTbl] @DestDBName,'gr000',@Str,1,0, @UpdatePreTransferedData
	
	BEGIN TRY  		
		--CREATE TABLES
		EXEC('SELECT mt.*, (CASE WHEN EXISTS(SELECT 1 FROM bi000 WHERE mt.GUID = MatGUID) THEN 1 ELSE 0 END) AS MovedComposite INTO ' + @DestDBName + '..mt2	FROM mt000 AS mt')
		EXEC('SELECT * INTO '				+ @DestDBName + '..mtOriginal					FROM ' + @DestDBName + '..mt000')
		EXEC('SELECT * INTO '				+ @DestDBName + '..segments2					FROM Segments000')
		EXEC('SELECT * INTO '				+ @DestDBName + '..segmentElements2				FROM SegmentElements000')
		EXEC('SELECT * INTO '				+ @DestDBName + '..matElements2					FROM MaterialElements000')
		EXEC('SELECT * INTO '				+ @DestDBName + '..matSegments2					FROM MaterialSegments000')
		EXEC('SELECT * INTO '				+ @DestDBName + '..matSegmentElements2			FROM MaterialSegmentElements000')
		EXEC('SELECT * INTO '				+ @DestDBName + '..groupSegments2				FROM GroupSegments000')
		EXEC('SELECT * INTO '				+ @DestDBName + '..groupSegmentElements2		FROM GroupSegmentElements000')
		EXEC('SELECT * INTO '				+ @DestDBName + '..MaterialsSegmentsManagement2	FROM MaterialsSegmentsManagement000')
		EXEC('SELECT GUID, Code INTO '		+ @DestDBName + '..groups2						FROM gr000')

		--ReTransfer
		EXEC('EXEC ' + @DestDBName + '..prcIE_FilterImportedMaterials 1, 1')
		EXEC('EXEC ' + @DestDBName + '..rep_ImportMat 0x00, 1, 0, 1, N'''', 1')
		EXEC('EXEC ' + @DestDBName + '..prcIE_ImportSegments 1, 1')
		EXEC('EXEC ' + @DestDBName + '..prcIE_ImportMaterialsSegmentsManagement')		
		EXEC('EXEC ' + @DestDBName + '..prcIE_ImportSegmentElements 1')
		EXEC('EXEC ' + @DestDBName + '..prcIE_ImportMatElements')
		EXEC('EXEC ' + @DestDBName + '..prcIE_ImportMatSegments 1')
		EXEC('EXEC ' + @DestDBName + '..prcIE_ImportMatSegmentElements')
		EXEC('EXEC ' + @DestDBName + '..prcIE_ImportGroupSegments')
		EXEC('EXEC ' + @DestDBName + '..prcIE_ImportGroupSegmentElements')

		--POSSD ReTransfer
		EXEC prcPOSSD_ReTransfer @DestDBName

		--DELETE TABLES
		EXEC('DROP TABLE ' + @DestDBName + '..mt2')
		EXEC('DROP TABLE ' + @DestDBName + '..mtOriginal')
		EXEC('DROP TABLE ' + @DestDBName + '..segments2')
		EXEC('DROP TABLE ' + @DestDBName + '..segmentElements2')
		EXEC('DROP TABLE ' + @DestDBName + '..matElements2')
		EXEC('DROP TABLE ' + @DestDBName + '..matSegments2')
		EXEC('DROP TABLE ' + @DestDBName + '..matSegmentElements2')
		EXEC('DROP TABLE ' + @DestDBName + '..groupSegments2')
		EXEC('DROP TABLE ' + @DestDBName + '..groupSegmentElements2')
		EXEC('DROP TABLE ' + @DestDBName + '..MaterialsSegmentsManagement2')
		EXEC('DROP TABLE ' + @DestDBName + '..groups2')
	END TRY  
	BEGIN CATCH  
		DECLARE @ERS NVARCHAR(MAX)
		SET @ERS = ERROR_MESSAGE()
		ROLLBACK TRANSACTION
		RAISERROR (@ERS, 16, 1);
		RETURN
	END CATCH;   	

	SET @Str = 'Guid Not IN (SELECT [GUID] FROM ' + @DestDBName + '..[mtdw000]) '
	EXEC [prcCopyTbl] @DestDBName,'mtdw000',@Str,1,0, @UpdatePreTransferedData

	SET @Str = 'Guid Not IN (SELECT [GUID] FROM ' + @DestDBName + '..[ac000]) '
	EXEC [prcCopyTbl] @DestDBName,'ac000',@Str,1,0, @UpdatePreTransferedData

	SET @Str = 'Guid Not IN (SELECT [GUID] FROM ' + @DestDBName + '..[ci000]) '
	EXEC [prcCopyTbl] @DestDBName,'ci000',@Str,1,0, @UpdatePreTransferedData

	SET @Str = 'Guid Not IN (SELECT [GUID] FROM ' + @DestDBName + '..[Allocations000]) '
	EXEC [prcCopyTbl] @DestDBName,'Allocations000',@Str,1,0, @UpdatePreTransferedData

	SET @Str = 'Guid Not IN (SELECT [GUID] FROM ' + @DestDBName + '..[Allotment000]) '
	EXEC [prcCopyTbl] @DestDBName,'Allotment000',@Str,1,0, @UpdatePreTransferedData

	SET @Str = 'Guid Not IN (SELECT [GUID] FROM ' + @DestDBName + '..[cu000]) '
	EXEC [prcCopyTbl] @DestDBName,'cu000',@Str,1,0, @UpdatePreTransferedData

	SET @Str = 'Guid Not IN (SELECT [GUID] FROM ' + @DestDBName + '..[bm000]) '
	EXEC [prcCopyTbl] @DestDBName,'bm000',@Str,1,0, @UpdatePreTransferedData


	IF @UpdatePreTransferedData > 0
	BEGIN
	DECLARE  @SQL		[NVARCHAR](max)
		SET @SQL = ' ALTER TABLE ' +  @DestDBName +'..[CustAddress000] DISABLE TRIGGER ALL ' 
		EXECUTE (@SQL) 

		SET @Str = 'DELETE '+ @DestDBName +'..[CustAddress000] WHERE [GUID] IN (SELECT [GUID] FROM CustAddress000)'
   		EXEC sp_executesql @Str

		SET @SQL = @SQL + ' ALTER TABLE ' + @DestDBName +'..[CustAddress000] ENABLE TRIGGER ALL '
		EXECUTE (@SQL) 

		SET @SQL = ' ALTER TABLE ' +  @DestDBName +'..[AddressArea000] DISABLE TRIGGER ALL ' 
		EXECUTE (@SQL)

		SET @Str = 'DELETE '+ @DestDBName +'..[AddressArea000] WHERE [GUID] IN (SELECT [GUID] FROM AddressArea000)'
   		EXEC sp_executesql @Str

		SET @SQL = @SQL + ' ALTER TABLE ' + @DestDBName +'..[AddressArea000] ENABLE TRIGGER ALL '
		EXECUTE (@SQL) 
		
		SET @SQL = ' ALTER TABLE ' +  @DestDBName +'..[AddressCity000] DISABLE TRIGGER ALL ' 
		EXECUTE (@SQL)

		SET @Str = 'DELETE '+ @DestDBName +'..[AddressCity000] WHERE [GUID] IN (SELECT [GUID] FROM AddressCity000)'
   		EXEC sp_executesql @Str

		SET @SQL = @SQL + ' ALTER TABLE ' + @DestDBName +'..[AddressCity000] ENABLE TRIGGER ALL '
		EXECUTE (@SQL) 
		
		SET @SQL = ' ALTER TABLE ' +  @DestDBName +'..[AddressCountry000] DISABLE TRIGGER ALL ' 
		EXECUTE (@SQL)

		SET @Str = 'DELETE '+ @DestDBName +'..[AddressCountry000] WHERE [GUID] IN (SELECT [GUID] FROM AddressCountry000)'
   		EXEC sp_executesql @Str

		SET @SQL = @SQL + ' ALTER TABLE ' + @DestDBName +'..[AddressCountry000] ENABLE TRIGGER ALL '
		EXECUTE (@SQL) 
	END


	SET @Str = 'Guid Not IN (SELECT [GUID] FROM ' + @DestDBName + '..[AddressCountry000]) '
	EXEC [prcCopyTbl] @DestDBName,'AddressCountry000',@Str,1,0, @UpdatePreTransferedData

	SET @Str = 'Guid Not IN (SELECT [GUID] FROM ' + @DestDBName + '..[AddressCity000]) '
	EXEC [prcCopyTbl] @DestDBName,'AddressCity000',@Str,1,0, @UpdatePreTransferedData

	SET @Str = 'Guid Not IN (SELECT [GUID] FROM ' + @DestDBName + '..[AddressArea000]) '
	EXEC [prcCopyTbl] @DestDBName,'AddressArea000',@Str,1,0, @UpdatePreTransferedData

	
	SET @Str = 'Guid Not IN (SELECT [GUID] FROM ' + @DestDBName + '..[CustAddress000]) '
	EXEC [prcCopyTbl] @DestDBName,'CustAddress000',@Str,1,0, @UpdatePreTransferedData

	IF @UpdatePreTransferedData > 0
	BEGIN
		UPDATE AddressArea000 SET Number = NULL
		DECLARE @i INT  = (SELECT ISNULL(MAX(Number), 0) FROM AddressArea000)
		UPDATE AddressArea000
		SET Number  = @i , @i = @i + 1
		WHERE Number IS NULL

		UPDATE AddressCity000 SET Number = NULL
		SET @i = (SELECT ISNULL(MAX(Number), 0) FROM AddressCity000)
		UPDATE AddressCity000
		SET Number  = @i , @i = @i + 1
		WHERE Number IS NULL

		UPDATE AddressCountry000 SET Number = NULL
		SET @i = (SELECT ISNULL(MAX(Number), 0) FROM AddressCountry000)
		UPDATE AddressCountry000
		SET Number  = @i , @i = @i + 1
		WHERE Number IS NULL

		UPDATE CustAddress000 SET Number = NULL
		SET @i = (SELECT ISNULL(MAX(Number), 0) FROM CustAddress000)
		UPDATE CustAddress000
		SET Number  = @i , @i = @i + 1
		WHERE Number IS NULL
	END

	SET @Str = 'Guid Not IN (SELECT [GUID] FROM ' + @DestDBName + '..[co000]) '
	EXEC [prcCopyTbl] @DestDBName,'co000',@Str,1,0
	
	SET @Str = 'Guid Not IN (SELECT [GUID] FROM ' +  @DestDBName + '..[nt000]) '
	EXEC [prcCopyTbl] @DestDBName,'nt000',@Str,1,0
	
	SET @Str = 'Guid Not IN (SELECT [GUID] FROM ' + @DestDBName + '..[bt000]) '
	EXEC [prcCopyTbl] @DestDBName,'bt000',@Str,1,0
	
	SET @Str = 'Guid Not IN (SELECT [GUID] FROM ' +  @DestDBName + '..[et000]) '
	EXEC [prcCopyTbl] @DestDBName,'et000',@Str,1,0
	
	SET @Str = 'Guid Not IN (SELECT [GUID] FROM ' +  @DestDBName + '..[st000]) '
	EXEC [prcCopyTbl] @DestDBName,'st000',@Str,1,0, @UpdatePreTransferedData
	
	SET @Str = 'Guid Not IN (SELECT [GUID] FROM ' +  @DestDBName + '..[Containers000]) '
	EXEC [prcCopyTbl] @DestDBName,'Containers000',@Str,1,0
	
	SET @Str = 'Guid Not IN (SELECT [GUID] FROM ' +  @DestDBName + '..[Packages000]) '
	EXEC [prcCopyTbl] @DestDBName,'Packages000',@Str,1,0

	-- BEGIN LETTER OF CREDIT TRANSFARE
	SET @Str = 'Guid NOT IN (SELECT [GUID] FROM ' + @DestDBName + '..[LCMain000]) '
	EXEC [prcCopyTbl] @DestDBName,'LCMain000',@Str, 1, 0, @UpdatePreTransferedData

	SET @Str = 'Guid NOT IN (SELECT [GUID] FROM ' + @DestDBName + '..[LC000]) AND [State] = 1 '
	EXEC [prcCopyTbl] @DestDBName,'LC000',@Str, 1, 0, @UpdatePreTransferedData

	SET @Str = 'Guid NOT IN (SELECT [GUID] FROM ' + @DestDBName + '..[LCExpenses000]) '
	EXEC [prcCopyTbl] @DestDBName,'LCExpenses000',@Str, 1, 0, @UpdatePreTransferedData
	
	SET @Str = 'DELETE FROM ' + @DestDBName + '..[LCRelatedExpense000] WHERE IsTransfared = 1'
		EXEC sp_executesql @Str
	-- END LETTER OF CREDIT TRANSFARE

	-- fixed assets start
	SET @Str = 'Guid Not IN (SELECT [GUID] FROM ' + @DestDBName + '..[as000]) '
	EXEC [prcCopyTbl] @DestDBName,'as000',@Str,1,0

	SET @Str = 'Guid Not IN (SELECT [GUID] FROM ' + @DestDBName + '..[ad000]) '
	EXEC [prcCopyTbl] @DestDBName,'ad000',@Str,1,@UpdatePreTransferedData, @UpdatePreTransferedData
		EXEC repAssetTransfer @DestDBName

	SET @Str = 'Guid Not IN (SELECT [GUID] FROM ' + @DestDBName + '..[AssetEmployee000]) '
	EXEC [prcCopyTbl] @DestDBName,'AssetEmployee000',@Str, 1, 0, @UpdatePreTransferedData
		--EXEC prcAssetPossessionsReNumTransferedCard @DestDBName
	SET @Str = 'Guid Not IN (SELECT [GUID] FROM ' + @DestDBName + '..[AssetPossessionsForm000]) '
	EXEC [prcCopyTbl] @DestDBName,'AssetPossessionsForm000',@Str, 1, 0, 0
	SET @Str = 'NOT EXISTS (SELECT * FROM ' + @DestDBName + '..[AssetPossessionsFormItem000] AS fi WHERE AssetPossessionsFormItem000.ParentGuid = fi.ParentGuid AND AssetPossessionsFormItem000.AssetGuid = fi.AssetGuid )  '
	EXEC [prcCopyTbl] @DestDBName,'AssetPossessionsFormItem000',@Str, 1, 0, 0
		--EXEC prcAssetPossessionsTransfer @DestDBName
	-- fixed assets end
	-- Workers
	SET @Str = 'Guid Not IN (SELECT [GUID] FROM ' + @DestDBName + '..[Workers000]) '
	EXEC [prcCopyTbl] @DestDBName,'Workers000',@Str,1,0,@UpdatePreTransferedData
	--Alternative Materials Start
	SET @Str = 'Guid Not IN (SELECT [GUID] FROM ' +  @DestDBName + '..[AlternativeMats000]) '
	EXEC [prcCopyTbl] @DestDBName,'AlternativeMats000',@Str,1,0,@UpdatePreTransferedData

	CREATE TABLE [#CHK]([ID] [INT] IDENTITY(1,1), [ASC1] UNIQUEIDENTIFIER)
	SET @Str = 'INSERT INTO  [#CHK] ([ASC1]) SELECT [GUID] FROM [CH000] WHERE [GUID] NOT IN (SELECT [GUID] FROM ' 
			+ @DestDBName + '..[CH000]) AND [STate] IN (0, 2, 7, 4, 10, 11, 14) AND [TypeGUID] IN (SELECT [GUID] FROM nt000 WHERE bTransfer = 1)'
		EXEC sp_executesql @Str
	SET @Str = 'INSERT INTO ' + @DestDBName + '..[MC000] ([Type], [Number], [Item], [ASC1]) SELECT 36, [ID], 3, CAST([ASC1] AS [VARCHAR](256)) FROM [#CHK]'
		EXEC sp_executesql @Str
	SET @Str = 'DECLARE @Num INT '
	SET @Str = @Str + ' SELECT @Num = ISNULL(MAX([Number]),0) FROM ' +  @DestDBName + '..[ch000] WHERE [STate] = 0 '
	SET @Str = @Str +  'UPDATE [ch000] SET [Number] = [Number] + @Num  WHERE [Guid] Not IN (SELECT [GUID] FROM ' +  @DestDBName + '..[ch000]) AND [STate] = 0 '
		EXEC sp_executesql @Str
	SET @Str = 'Guid Not IN (SELECT [GUID] FROM ' +  @DestDBName + '..[ch000]) AND [STate] IN (0, 2, 7, 4, 10, 11, 14) AND [TypeGUID] IN (SELECT [GUID] FROM nt000 WHERE bTransfer = 1)'
	EXEC [prcCopyTbl] @DestDBName,'ch000', @Str, 1, 0
	SET @Str = 'INSERT INTO ' +  @DestDBName + '..ChequeHistory000 SELECT * FROM ChequeHistory000 WHERE ChequeGUID IN (SELECT [ASC1] FROM [#CHK]) AND EventNumber != 2'
		EXEC sp_executesql @Str
	SET @Str = 'UPDATE ' +  @DestDBName + '..ch000 
				SET TransferCheck = 1, TransferState = (CASE ch.State WHEN 2 THEN 0 ELSE ch.State END) 
				FROM [#CHK] temp INNER JOIN [ch000] ch ON ch.GUID = temp.ASC1'
		EXEC sp_executesql @Str

	DECLARE 
		@C CURSOR,
		@Guid UNIQUEIDENTIFIER,
		@Temp FLOAT

	SELECT ch.* INTO #RESULT FROM [#CHK] temp INNER JOIN [ch000] ch ON ch.GUID = temp.ASC1 where ch.[State] = 2

	SET @C = CURSOR FAST_FORWARD FOR SELECT GUID FROM #RESULT
	OPEN @C FETCH FROM @C INTO @GUID
	WHILE @@FETCH_STATUS = 0 
	BEGIN 
		SET @Temp = dbo.fnCheck_GetCollectedValue(@GUID)
		SET @Str = 'UPDATE #RESULT SET VAL = (VAL) - (' + CAST(@Temp AS NVARCHAR(250)) + '), NOTES = ''ﬁ»÷/œ›⁄ Ã“∆Ì« „‰ «·› —… «·”«»ﬁ… '' WHERE GUID = ''' + CAST( @GUID AS NVARCHAR(250)) + '''' 
			EXEC sp_executesql @Str
		FETCH @C INTO @GUID 
	END
	CLOSE @C
	DEALLOCATE @C

	SET @Str = ' ALTER TABLE ' + @DestDBName + '..ch000 DISABLE TRIGGER ALL 
		DELETE ' + @DestDBName + '..ch000 FROM ' + @DestDBName + '..ch000 ch INNER JOIN #RESULT r ON r.GUID = ch.GUID WHERE r.VAL <= 0
		
		UPDATE ' + @DestDBName + '..ch000 SET VAL = r.VAL, State = 0, Notes = r.Notes FROM ' + @DestDBName + '..ch000 ch INNER JOIN #RESULT r ON r.GUID = ch.GUID WHERE r.VAL > 0
		DELETE ' + @DestDBName + '..ChequeHistory000 WHERE ChequeGUID NOT IN (SELECT GUID FROM ' + @DestDBName + '..ch000) ' 
		EXEC sp_executesql @Str
	SET @Str = 'ALTER TABLE '+ @DestDBName + '..ch000 ENABLE TRIGGER ALL'
		EXEC sp_executesql @Str

	SET @Str = 'DELETE  ' +  @DestDBName + '..[MA000] WHERE (CAST(BillTypeGUID AS VARCHAR(40)) + CAST(ObjGUID AS VARCHAR(40)))  IN (SELECT (CAST(BillTypeGUID AS VARCHAR(40)) + CAST(ObjGUID AS VARCHAR(40))) FROM [MA000])  '
		EXEC sp_executesql @Str
	SET @Str = ' GUID  Not IN (SELECT GUID FROM ' +  @DestDBName + '..[MA000])  '
	EXEC [prcCopyTbl] @DestDBName,'MA000',@Str,1,0
	

	SET @Str='INSERT INTO '+@DestDBName+'..MNPS000
				SELECT * FROM MNPS000
				WHERE Guid Not IN (SELECT [GUID] FROM ' +  @DestDBName + '..[MNPS000]) AND state = 0 
				AND GUID in (SELECT parentGuid FROM psi000 where state = 0 and Startdate >='+CAST(@d AS NVARCHAR)+' ) 
				and EndDate >=' + CAST(@d AS NVARCHAR)
		EXEC sp_executesql @Str
	
	SET @Str='INSERT INTO '+@DestDBName+'..PSI000
				SELECT * from PSI000
				WHERE Guid Not IN (SELECT [GUID] FROM ' +  @DestDBName + '..[PSI000])  and state=0  and Startdate >='+ CAST(@d AS NVARCHAR)
		EXEC sp_executesql @Str
	
		--exec PrcReOrderingMNPS @DestDBName

	DECLARE @dbname NVARCHAR(MAX)
	
	SELECT @dbname=db_name()

	EXEC   prc_SJ_TransfareCopyScheduledTasks @DestDBName,@dbname,@d

	BEGIN
	SET @Str = 'DELETE ' + @DestDBName + '..[ad000] Where [SnGuid] NOT IN ( SELECT [GUID] FROM ' + @DestDBName + '..[SNC000])'
	EXEC sp_executesql @Str

	EXEC prcTransferNotificationSystem @DestDBName, @UpdatePreTransferedData

		SET @Str = 'Id Not IN (SELECT [Id] FROM ' +  @DestDBName + '..[RichDocument000]) '
		EXEC [prcCopyTbl] @DestDBName,'RichDocument000',@Str,1,0,@UpdatePreTransferedData

		SET @Str = 'Id Not IN (SELECT [Id] FROM ' +  @DestDBName + '..[RichDocumentCalculatedField000]) '
		EXEC [prcCopyTbl] @DestDBName,'RichDocumentCalculatedField000',@Str,1,0,@UpdatePreTransferedData

		-- Œ’Ì’ «·ÿ»«⁄Â
		SET @Str = 'TempletPrintGuid Not IN (
											SELECT [TempletPrintGuid] FROM ' +  @DestDBName + '..[CustomizePrint000] AS DestTbl
											where DestTbl.TypeGuid = TypeGuid AND
												 DestTbl.UserGuid = UserGuid
											)'
		EXEC [prcCopyTbl] @DestDBName,'CustomizePrint000', @Str, 1, 0, @UpdatePreTransferedData

		--Õ”«»«  «·⁄„·« 
		SET @Str = '[GUID] NOT IN (SELECT [GUID] FROM ' +  @DestDBName + '..[POSCurrencyItem000]) '
		EXEC [prcCopyTbl] @DestDBName, 'POSCurrencyItem000', @Str, 1, 0, @UpdatePreTransferedData

		CREATE TABLE #GCCTaxItems ([GUID] UNIQUEIDENTIFIER, ItemGUID UNIQUEIDENTIFIER, TaxType INT)
		SET @Str = 'INSERT INTO #GCCTaxItems([GUID], ItemGUID, TaxType) SELECT [GUID], CustGUID, TaxType FROM [GCCCustomerTax000] WHERE [GUID] NOT IN (SELECT [GUID] FROM ' +  @DestDBName + '..[GCCCustomerTax000]) '
		EXEC sp_executesql @Str
		
		IF EXISTS (SELECT * FROM #GCCTaxItems)
		BEGIN 
			SET @Str = 'DELETE FROM ' + @DestDBName + '..[GCCCustomerTax000] cu INNER JOIN #GCCTaxItems g ON cu.CustGUID = g.ItemGUID AND cu.TaxType = g.TaxType '
			EXEC sp_executesql @Str
		END 
		SET @Str = '[GUID] NOT IN (SELECT [GUID] FROM ' +  @DestDBName + '..[GCCCustomerTax000]) '
		EXEC [prcCopyTbl] @DestDBName, 'GCCCustomerTax000', @Str, 1, 0, @UpdatePreTransferedData

		DELETE #GCCTaxItems
		SET @Str = 'INSERT INTO #GCCTaxItems([GUID], ItemGUID, TaxType) SELECT [GUID], MatGUID, TaxType FROM [GCCMaterialTax000] WHERE [GUID] NOT IN (SELECT [GUID] FROM ' +  @DestDBName + '..[GCCMaterialTax000]) '
		EXEC sp_executesql @Str
		
		IF EXISTS (SELECT * FROM #GCCTaxItems)
		BEGIN 
			SET @Str = 'DELETE FROM ' + @DestDBName + '..[GCCMaterialTax000] mt INNER JOIN #GCCTaxItems g ON mt.MatGUID = g.ItemGUID AND mt.TaxType = g.TaxType '
			EXEC sp_executesql @Str
		END 
		SET @Str = '[GUID] NOT IN (SELECT [GUID] FROM ' +  @DestDBName + '..[GCCMaterialTax000]) '
		EXEC [prcCopyTbl] @DestDBName, 'GCCMaterialTax000', @Str, 1, 0, @UpdatePreTransferedData

		CREATE TABLE #DestDurations([GUID] UNIQUEIDENTIFIER, StartDate DATE, EndDate DATE, [State] INT, IsTransfered BIT)
		SET @Str = 'INSERT INTO #DestDurations([GUID], StartDate, EndDate, [State], IsTransfered) SELECT [GUID], StartDate, EndDate, [State], IsTransfered FROM ' + @DestDBName + '..[GCCTaxDurations000]'
		EXEC sp_executesql @Str

		SET @Str = 'DELETE FROM ' + @DestDBName + '..[GCCTaxDurations000] WHERE GUID IN (SELECT GUID FROM GCCTaxDurations000)'
		EXEC sp_executesql @Str

		SET @Str = 'DELETE FROM ' + @DestDBName + '..[GCCTaxVatReports000] WHERE GUID NOT IN (SELECT TaxVATReportGUID FROM ' + @DestDBName + '..GCCTaxDurations000)'
		EXEC sp_executesql @Str	 

		SET @Str = 'DELETE FROM ' + @DestDBName + '..[GCCTaxVatReportDetails000] WHERE ParentGUID NOT IN (SELECT TaxVATReportGUID FROM ' + @DestDBName + '..GCCTaxDurations000)'
		EXEC sp_executesql @Str	 

		EXEC [prcCopyTbl] @DestDBName, 'GCCTaxDurations000', '', 1, 0, 0
		EXEC [prcCopyTbl] @DestDBName, 'GCCTaxVatReports000', '', 1, 0, 0
		EXEC [prcCopyTbl] @DestDBName, 'GCCTaxVatReportDetails000', '', 1, 0, 0
		
		SET @Str = 'UPDATE ' + @DestDBName + '..[GCCTaxDurations000] SET IsTransfered = 1 WHERE GUID IN (SELECT GUID FROM GCCTaxDurations000)'
		EXEC sp_executesql @Str
		
		CREATE TABLE [#DestOpenDate] (OpenFilePeriodDate DATE)
		EXEC ('INSERT INTO [#DestOpenDate] SELECT [dbo].[fnDate_Amn2Sql]([Value]) FROM ' + @DestDBName + '..[op000] WHERE [Name] = ' +  '''AmnCfg_FPDate''')
		DECLARE @OpeningDate DATE = (SELECT TOP 1 OpenFilePeriodDate FROM [#DestOpenDate]) 
		SELECT * INTO #DestCrossDurations FROM #DestDurations WHERE IsTransfered = 1 AND [State] = 0 AND StartDate < @OpeningDate AND EndDate >= @OpeningDate

		IF EXISTS (SELECT * FROM #DestCrossDurations) 
		BEGIN
			SET @Str = 'UPDATE ' + @DestDBName + '..[GCCTaxDurations000] SET [State] = 0  WHERE GUID IN (SELECT GUID FROM #DestCrossDurations)'
			EXEC sp_executesql @Str
		END

		IF EXISTS (SELECT * FROM #DestDurations WHERE IsTransfered = 0 AND [State] = 1)
		BEGIN 
			SET @Str = 'DELETE FROM ' + @DestDBName + '..[GCCTaxDurations000] WHERE IsTransfered = 0'
			EXEC sp_executesql @Str			
			
			EXEC [prcGCC_Transfer] @DestDBName
		END
	END
	COMMIT
#########################################################
CREATE PROCEDURE prcTransferNotificationSystem @DestDBName	NVARCHAR(255), @UpdatePreTransferedData BIT
AS
DECLARE @Str NVARCHAR(MAX)

--»ÿ«ﬁ… „Ã„Ê⁄… “»«∆‰
SET @Str = 'Guid Not IN (SELECT [GUID] FROM ' +  @DestDBName + '..NSCustomerGroup000) '
EXEC prcCopyTbl @DestDBName,'NSCustomerGroup000',@Str,1,0,@UpdatePreTransferedData
	
SET @Str = 'CustomerGroupGuid Not IN (SELECT [CustomerGroupGuid] FROM ' +  @DestDBName + '..NSCustomerGroupCustomer000) '
EXEC prcCopyTbl @DestDBName,'NSCustomerGroupCustomer000',@Str,1,0,@UpdatePreTransferedData
	
--—”«∆· «·›Ê« Ì—
SET @Str = 'Guid Not IN (SELECT [GUID] FROM ' +  @DestDBName + '..NSBillCondition000) '
EXEC prcCopyTbl @DestDBName,'NSBillCondition000',@Str,1,0,@UpdatePreTransferedData
	
SET @Str = 'Guid Not IN (SELECT [GUID] FROM ' +  @DestDBName + '..NSBillEventCondition000) '
EXEC prcCopyTbl @DestDBName,'NSBillEventCondition000',@Str,1,0,@UpdatePreTransferedData
	
SET @Str = 'Guid Not IN (SELECT [GUID] FROM ' +  @DestDBName + '..NSBillWelcomeEventCondition000) '
EXEC prcCopyTbl @DestDBName,'NSBillWelcomeEventCondition000',@Str,1,0,@UpdatePreTransferedData
	
SET @Str = 'Guid Not IN (SELECT [GUID] FROM ' +  @DestDBName + '..NSBillSrcType000) '
EXEC prcCopyTbl @DestDBName,'NSBillSrcType000',@Str,1,0,@UpdatePreTransferedData
	
--—”«∆· «·ÿ·»Ì« 
SET @Str = 'Guid Not IN (SELECT [GUID] FROM ' +  @DestDBName + '..NSOrderCondition000) '
EXEC prcCopyTbl @DestDBName,'NSOrderCondition000',@Str,1,0,@UpdatePreTransferedData
	
SET @Str = 'Guid Not IN (SELECT [GUID] FROM ' +  @DestDBName + '..NSOrderSrcType000) '
EXEC prcCopyTbl @DestDBName,'NSOrderSrcType000',@Str,1,0,@UpdatePreTransferedData
	
--—”«∆· «·«Ê—«ﬁ «·„«·Ì…
SET @Str = 'Guid Not IN (SELECT [GUID] FROM ' +  @DestDBName + '..NSChecksCondition000) '
EXEC prcCopyTbl @DestDBName,'NSChecksCondition000',@Str,1,0,@UpdatePreTransferedData
	
SET @Str = 'Guid Not IN (SELECT [GUID] FROM ' +  @DestDBName + '..NSChecksSrcType000) '
EXEC prcCopyTbl @DestDBName,'NSChecksSrcType000',@Str,1,0,@UpdatePreTransferedData
	
--—”«∆· «·”‰œ« 
SET @Str = 'Guid Not IN (SELECT [GUID] FROM ' +  @DestDBName + '..NSEntryCondition000) '
EXEC prcCopyTbl @DestDBName,'NSEntryCondition000',@Str,1,0,@UpdatePreTransferedData
	
SET @Str = 'Guid Not IN (SELECT [GUID] FROM ' +  @DestDBName + '..NSEntryEventCondition000) '
EXEC prcCopyTbl @DestDBName,'NSEntryEventCondition000',@Str,1,0,@UpdatePreTransferedData
	
SET @Str = 'Guid Not IN (SELECT [GUID] FROM ' +  @DestDBName + '..NSEntrySrcType000) '
EXEC prcCopyTbl @DestDBName,'NSEntrySrcType000',@Str,1,0,@UpdatePreTransferedData
	
--—”«∆· „—«ﬁ»… «·„Ê«œ
SET @Str = 'Guid Not IN (SELECT [GUID] FROM ' +  @DestDBName + '..NSMatMonitoringCondition000) '
EXEC prcCopyTbl @DestDBName,'NSMatMonitoringCondition000',@Str,1,0,@UpdatePreTransferedData
	
SET @Str = 'Guid Not IN (SELECT [GUID] FROM ' +  @DestDBName + '..NSMatMonitoringEventCondition000) '
EXEC prcCopyTbl @DestDBName,'NSMatMonitoringEventCondition000',@Str,1,0,@UpdatePreTransferedData
	
--—”«∆· «—’œ… Õ—ﬂ… «·Õ”«»
SET @Str = 'Guid Not IN (SELECT [GUID] FROM ' +  @DestDBName + '..NSAccountBalancesJob000) '
EXEC prcCopyTbl @DestDBName,'NSAccountBalancesJob000',@Str,1,0,@UpdatePreTransferedData
	
SET @Str = 'Guid Not IN (SELECT [GUID] FROM ' +  @DestDBName + '..NSAccountBalancesScheduling000) '
EXEC prcCopyTbl @DestDBName,'NSAccountBalancesScheduling000',@Str,1,0,@UpdatePreTransferedData
	
SET @Str = 'Guid Not IN (SELECT [GUID] FROM ' +  @DestDBName + '..NSAccountBalancesSchedulingGrid000) '
EXEC prcCopyTbl @DestDBName,'NSAccountBalancesSchedulingGrid000',@Str,1,0,@UpdatePreTransferedData
	
SET @Str = 'Guid Not IN (SELECT [GUID] FROM ' +  @DestDBName + '..NSAccountBalancesSchedulingSrcType000) '
EXEC prcCopyTbl @DestDBName,'NSAccountBalancesSchedulingSrcType000',@Str,1,0,@UpdatePreTransferedData
	
SET @Str = 'Guid Not IN (SELECT [GUID] FROM ' +  @DestDBName + '..NSAccountBalancesSchedulingUser000) '
EXEC prcCopyTbl @DestDBName,'NSAccountBalancesSchedulingUser000',@Str,1,0,@UpdatePreTransferedData
	
--—”«∆·  Â‰∆… »⁄Ìœ „Ì·«œ “»Ê‰
SET @Str = 'Guid Not IN (SELECT [GUID] FROM ' +  @DestDBName + '..NSCustBirthDayCondition000) '
EXEC prcCopyTbl @DestDBName,'NSCustBirthDayCondition000',@Str,1,0,@UpdatePreTransferedData
	
--Ãœ«Ê· ‰Ÿ«„ «·—”«∆· «·—∆Ì”Ì…
SET @Str = 'Guid Not IN (SELECT [GUID] FROM ' +  @DestDBName + '..NSEvent000) '
EXEC prcCopyTbl @DestDBName,'NSEvent000',@Str,1,0,@UpdatePreTransferedData
	
SET @Str = 'Guid Not IN (SELECT [GUID] FROM ' +  @DestDBName + '..NSEventCondition000) '
EXEC prcCopyTbl @DestDBName,'NSEventCondition000',@Str,1,0,@UpdatePreTransferedData
	
SET @Str = 'Guid Not IN (SELECT [GUID] FROM ' +  @DestDBName + '..NSNotification000) '
EXEC prcCopyTbl @DestDBName,'NSNotification000',@Str,1,0,@UpdatePreTransferedData
	
SET @Str = 'Guid Not IN (SELECT [GUID] FROM ' +  @DestDBName + '..NSMessage000) '
EXEC prcCopyTbl @DestDBName,'NSMessage000',@Str,1,0,@UpdatePreTransferedData
	
SET @Str = 'MessageGuid Not IN (SELECT [MessageGuid] FROM ' +  @DestDBName + '..NSMessageFields000) '
EXEC prcCopyTbl @DestDBName,'NSMessageFields000',@Str,1,0,@UpdatePreTransferedData
	
SET @Str = 'Guid Not IN (SELECT [GUID] FROM ' +  @DestDBName + '..NSScheduleEventCondition000) '
EXEC prcCopyTbl @DestDBName,'NSScheduleEventCondition000', @Str, 1, 0, @UpdatePreTransferedData

SET @Str = '[GUID] NOT IN (SELECT [GUID] FROM ' +  @DestDBName + '..NSAccountCondition000) '
EXEC prcCopyTbl @DestDBName,'NSAccountCondition000', @Str, 1, 0, @UpdatePreTransferedData

SET @Str = '[GUID] NOT IN (SELECT [GUID] FROM ' +  @DestDBName + '..NSAccountEventCondition000) '
EXEC prcCopyTbl @DestDBName,'NSAccountEventCondition000', @Str, 1, 0, @UpdatePreTransferedData

SET @Str = '[GUID] NOT IN (SELECT [GUID] FROM ' +  @DestDBName + '..NSMailMessage000) '
EXEC prcCopyTbl @DestDBName,'NSMailMessage000', @Str, 1, 0, @UpdatePreTransferedData


SET @Str = 'ObjectGuid NOT IN (SELECT ObjectGuid FROM ' +  @DestDBName + '..NSObjectNotification000) '
EXEC prcCopyTbl @DestDBName,'NSObjectNotification000', @Str, 1, 0, @UpdatePreTransferedData

SET @Str = '[GUID] NOT IN (SELECT [GUID] FROM ' +  @DestDBName + '..NSSmsMessage000) '
EXEC prcCopyTbl @DestDBName,'NSSmsMessage000', @Str, 1, 0, @UpdatePreTransferedData



######################################################### 
CREATE PROCEDURE prcgenTrNoteEntry
	@StartDate [DATETIME],
	@DbName	[NVARCHAR](256)
AS
			SET @DbName = '[' + @DbName + ']';

	CREATE TABLE [#er] ([Guid]  [UNIQUEIDENTIFIER])
	DECLARE @s  [NVARCHAR](350)
	SET @s = 'INSERT INTO [#er]([Guid])  SELECT [er].[ParentGuid] FROM ' + @DbName +'.dbo.[er000] AS [er] INNER JOIN ' + @DbName +'.dbo.[ch000] [ch] ON [er].[ParentGuid] = [ch].[Guid] WHERE [ch].[Guid] NOT IN  (SELECT [ParentGuid] FROM [er000]) AND [ch].[State] = 0 AND [er].[ParentType] = 5'
	EXEC (@S)
	UPDATE [ch000] SET [Date] = @StartDate WHERE [DATE] < @StartDate
	UPDATE [ce000] SET [DATE] = @StartDate WHERE [DATE] < @StartDate
	ALTER TABLE [en000] DISABLE TRIGGER [trg_en000_checkConstraints]
	UPDATE [en000] SET [DATE] = @StartDate WHERE [DATE] < @StartDate
	ALTER TABLE [en000] ENABLE TRIGGER [trg_en000_checkConstraints]
	ALTER TABLE [ce000] DISABLE TRIGGER [trg_ce000_post] 
	DECLARE @GUID [UNIQUEIDENTIFIER],@c CURSOR
	SET @c = CURSOR FAST_FORWARD FOR
		SELECT [ch].[Guid] FROM [ch000] AS [ch] --INNER JOIN [nt000] AS [nt] ON [ch].[TypeGuid] = [nt].[Guid]
		INNER JOIN [#er] AS [er] ON [ch].[GUID] = [er].[Guid]
		WHERE [ch].[State] = 0   AND [ch].[GUID] NOT IN (SELECT [ParentGuid] FROM [er000]) --AND [nt].[bAutoEntry] = 1
	OPEN @c 
	FETCH FROM @c INTO @GUID
	WHILE @@FETCH_STATUS = 0 
	BEGIN 
		EXEC prcNote_GenEntry @GUID
		FETCH FROM @c INTO @GUID  
	END
	CLOSE @c 
	DEALLOCATE @c
	ALTER TABLE [ce000] ENABLE TRIGGER [trg_ce000_post] 
######################################################### 
CREATE PROCEDURE prcUpdateBranchMask
AS
	UPDATE [Mt000] set [BranchMask] = 0
	UPDATE [Ac000] set [BranchMask] = 0
	UPDATE [Co000] set [BranchMask] = 0
	UPDATE [My000] set [BranchMask] = 0
	UPDATE [St000] set [BranchMask] = 0
	UPDATE [Gr000] set [BranchMask] = 0
	UPDATE [Bt000] set [BranchMask] = 0
	UPDATE [Et000] set [BranchMask] = 0
	UPDATE [Nt000] set [BranchMask] = 0
	
	
######################################################### 
#END
