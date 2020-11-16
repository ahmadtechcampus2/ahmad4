###########################################################################################
CREATE PROCEDURE prcCheckDB_er
	@Correct [INT] = 0
AS
/*
This method checks, corrects and reports the following:
	- 0xB01 ce for more than one source.
	- 0xB02 bu for more than one entry.
	- 0xB03 check ch for more than one entry.
	- 0xB04 check py for more than one entry.
*/
	-- check ce for more than one source:
	IF @Correct <> 1
		INSERT INTO [ErrorLog] ([Type], [g1])
			SELECT 0xB01, [EntryGUID] FROM [er000] GROUP BY [EntryGUID] HAVING COUNT(*) > 1

	-- check bu for more than one entry:
	IF @Correct <> 1
		INSERT INTO [ErrorLog] ([Type], [g1])
			SELECT 0xB02, [erBillGUID] FROM [vwER_EntriesBills] GROUP BY [erBillGUID] HAVING COUNT(*) > 1

	-- check ch for more than one entry:
	IF @Correct <> 1
		INSERT INTO [ErrorLog]([Type], [g1])
			SELECT 0xB03, [erNoteGUID] FROM [vwER_EntriesNotes] GROUP BY [erNoteGUID] HAVING COUNT(*) > 1
			UNION ALL
			SELECT 0xB03, [erNoteGUID] FROM [vwER_EntriesCollectedNotes] GROUP BY [erNoteGUID] HAVING COUNT(*) > 1

	-- check py for more than one entry:
	IF @Correct <> 1
		INSERT INTO [ErrorLog]([Type], [g1])
			SELECT 0xB04, [erPayGUID] FROM [vwEr_EntriesPays] GROUP BY [erPayGUID] HAVING COUNT(*) > 1
	
	-- check ce for Entry Parent is not found in bu000 table
	-- ERT_BILL, ERT_FPAY
	IF @Correct <> 1
		INSERT INTO [ErrorLog]([c1], [f1], [Type], [g1])
			SELECT 'Bill not found', er.ParentNumber, 0xB05, [ce].[GUID]
			FROM
				ce000 ce 
				INNER JOIN er000 er ON ce.Guid = er.EntryGuid
				LEFT JOIN bu000 bu ON er.ParentGuid = bu.Guid
			where
				(er.ParentType = 2 OR er.ParentType = 3)
				AND bu.Guid IS NULL
				
	-- check ce for Entry Parent is not found in py000 table
	-- ERT_PAY
	IF @Correct <> 1
		INSERT INTO [ErrorLog]( [c1], [f1], [Type], [g1])
			SELECT 'Pay not found', er.ParentNumber, 0xB05, [ce].[GUID]
			FROM
				ce000 ce 
				INNER JOIN er000 er ON ce.Guid = er.EntryGuid
				LEFT JOIN py000 py ON er.ParentGuid = py.Guid
			where
				er.ParentType = 4
				AND py.Guid IS NULL
	-- check ce for Entry Parent is not found in ch000 table
	-- ERT_CHECK, ERT_CHECKCOL, ERT_CHECKRET, ERT_CHECKRET2, ERT_CHECKREENDORSE, ERT_CHECKRETREENDORSE
	IF @Correct <> 1 
		INSERT INTO [ErrorLog]( [c1], [f1], [Type], [g1])
			SELECT 'Note not found', 0,0xB05, [ce].[GUID]
			FROM
				ce000 ce 
				INNER JOIN er000 er ON ce.Guid = er.EntryGuid
				LEFT JOIN ch000 ch ON er.ParentGuid = ch.Guid
			where
				(er.ParentType = 5 
					or er.ParentType = 6 
					or er.ParentType = 7 
					or er.ParentType = 8 
					or er.ParentType = 10 
					or er.ParentType = 11)
				AND ch.Guid IS NULL
	-- check ce for Entry Parent is not found in or000 table
	-- ERT_POSENTRY
--	IF @Correct <> 1
--		INSERT INTO [ErrorLog]( [c1], [f1], [Type], [g1])
--			SELECT 'Parent not found (POS_OR)', er.ParentNumber, 0xB05, [ce].[GUID]
--			FROM
--				ce000 ce 
--				INNER JOIN er000 er ON ce.Guid = er.EntryGuid
--				LEFT JOIN or000 ord ON er.ParentGuid = ord.Guid
--			where
--				er.ParentType = 9
--				AND ord.Guid IS NULL
				
	-- check ce for Entry Parent is not found in ppr000 table
	-- ERT_RECEIVABLETYPE, ERT_PAYABLETYPE
	IF @Correct <> 1
		INSERT INTO [ErrorLog]( [c1], [f1], [Type], [g1])
			SELECT 'Parent not found (RECEIVABLETYPE_PAYABLETYPE)', er.ParentNumber, 0xB05, [ce].[GUID]
			FROM
				ce000 ce 
				INNER JOIN er000 er ON ce.Guid = er.EntryGuid
				LEFT JOIN ppr000 ppr ON er.ParentGuid = ppr.Guid
			where
				( er.ParentType = 200 or er.ParentType = 201)
				AND ppr.Guid IS NULL

	-- check ce for Entry Parent is not found in hosPFile000 table
	-- ERT_HOS_GENERAL_TEST, ERT_HOS_MEDICAL_CONS, ERT_HOS_CLOSE_DOSSIER, ERT_HOS_STAY, ERT_HOS_SURGERY, 
	IF @Correct <> 1
		INSERT INTO [ErrorLog]( [c1], [f1], [Type], [g1])
			SELECT 'Parent not found (HOSPITAL)', er.ParentNumber, 0xB05, [ce].[GUID]
			FROM
				ce000 ce 
				INNER JOIN er000 er ON ce.Guid = er.EntryGuid
				LEFT JOIN hosPFile000 hos ON er.ParentGuid = hos.Guid
			where
				(	er.ParentType = 202
					or er.ParentType = 301
					or er.ParentType = 302
					or er.ParentType = 304
				)
				AND hos.Guid IS NULL

	IF @Correct <> 1
		INSERT INTO [ErrorLog]( [c1], [f1], [Type], [g1])
			SELECT 'Parent not found (HOSPITAL STAY)', er.ParentNumber, 0xB05, [ce].[GUID]
			FROM
				ce000 ce 
				INNER JOIN er000 er ON ce.Guid = er.EntryGuid
				LEFT JOIN hosStay000 as  hosStay ON er.ParentGuid = hosStay.Guid
			where	er.ParentType =303
			AND hosStay.Guid IS NULL
	IF @Correct <> 1
		INSERT INTO [ErrorLog]( [c1], [f1], [Type], [g1])
			SELECT 'Parent not found (HOSPITAL GENERALTEST)', er.ParentNumber, 0xB05, [ce].[GUID]
			FROM
				ce000 ce 
				INNER JOIN er000 er ON ce.Guid = er.EntryGuid
				LEFT JOIN hosGeneralTest000  as gt ON er.ParentGuid = gt.Guid
			where	er.ParentType = 300
			AND gt.Guid IS NULL

	-- check ce for Entry Parent is not found in ax000 table
	-- ERT_ASSET_ADDED
	IF @Correct <> 1
		INSERT INTO [ErrorLog]( [c1], [f1], [Type], [g1])
			SELECT 'Parent not found (ASSET_ADDED)', er.ParentNumber, 0xB05, [ce].[GUID]
			FROM
				ce000 ce 
				INNER JOIN er000 er ON ce.Guid = er.EntryGuid
				LEFT JOIN ax000 ax ON er.ParentGuid = ax.Guid
			where
				er.ParentType = 100
				AND ax.Guid IS NULL

	-- check ce for Entry Parent is not found in dp000 table
	-- ERT_ASSET_DEPRECATION
	IF @Correct <> 1
		INSERT INTO [ErrorLog]( [c1], [f1], [Type], [g1])
			SELECT 'Parent not found (ASSET_DEPRECATION)', er.ParentNumber, 0xB05, [ce].[GUID]
			FROM
				ce000 ce 
				INNER JOIN er000 er ON ce.Guid = er.EntryGuid
				LEFT JOIN dp000 dp ON er.ParentGuid = dp.EntryGUID
			where
				er.ParentType = 101
				AND dp.Guid IS NULL

	-- check ce for Entry Parent is not found in TrnTransferVoucher000 table
	-- ERT_TRANSFER_CASH, ERT_TRANSFER_PAY, ERT_TRANSFER_RETURN
	IF @Correct <> 1
		INSERT INTO [ErrorLog]( [c1], [f1], [Type], [g1])
			SELECT 'Parent not found (TRANSFER)', er.ParentNumber, 0xB05, [ce].[GUID]
			FROM
				ce000 ce 
				INNER JOIN er000 er ON ce.Guid = er.EntryGuid
				LEFT JOIN TrnTransferVoucher000 t ON er.ParentGuid = t.Guid
			where
				( er.ParentType = 500 or er.ParentType = 501 or er.ParentType = 502)
				AND t.Guid IS NULL
	
	-- check ce for Entry Parent is not found in TrnStatement000 table
	-- ERT_TRN_STATEMENT
	IF @Correct <> 1
		INSERT INTO [ErrorLog]( [c1], [f1], [Type], [g1])
			SELECT 'Parent not found (TRANSFER_STATEMENT)', er.ParentNumber, 0xB05, [ce].[GUID]
			FROM
				ce000 ce 
				INNER JOIN er000 er ON ce.Guid = er.EntryGuid
				LEFT JOIN TrnStatement000 t ON er.ParentGuid = t.Guid
			where
				er.ParentType = 510
				AND t.Guid IS NULL
				
	IF @Correct <> 1
		INSERT INTO [ErrorLog]( [c1], [f1], [Type])
		SELECT 'Entry not found', er.ParentNumber, 0xB06
		FROM
			[er000] [er]
			LEFT JOIN [ce000] [ce] ON [ce].[GUID] = [er].[EntryGUID]
		WHERE
			[ce].[GUID] IS NULL

	IF @Correct <> 0
		DELETE [er000]
		FROM
			[er000] [er]
			LEFT JOIN [ce000] [ce] ON [ce].[GUID] = [er].[EntryGUID]
		WHERE
			[ce].[GUID] IS NULL
###########################################################################################
#END