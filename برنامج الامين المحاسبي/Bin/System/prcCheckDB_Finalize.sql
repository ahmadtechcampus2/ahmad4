###########################################################################################
CREATE PROCEDURE prcCheckDB_Finalize
	@LogGuid UNIQUEIDENTIFIER = 0X00
AS
/* 
This method:
	- is used to return ErrorLog
	- is usualy called from CheckDB procs in Al-Ameen


This method checks, corrects and reports the following
	- 0x001 ParentGUID closed links.
	- 0x002 ParentGUID broken links.
	- 0x003 types out of range 1, 2, 4, 8
	- 0x004 normal accounts having final accounts as ParentGUIDs.
	- 0x005 final accounts having normal accounts as ParentGUIDs.
	- 0x006 unknown ci accounts.
	- 0x007 miscalculated NSons (Corrected by recalculating).


	- 0x301 bu without bi, corrected by deletion
	- 0x302 unknown CustPtr
	- 0x303 unknown CustAccount
	- 0x304 unknown StorePtr (corrected to 1)
	- 0x305 unknown CurrPtr (corrected to 1)
	- 0x306 CurrVal found 0 (corrected  to 1)
	- 0x307 sums Total errror (corrected by recalculating)
	- 0x308 sums TotalDisc errror (corrected by recalculating)
	- 0x309 sums TotalExtra errror (corrected by recalculating)
	- 0x30A sums ItemsDisc errror (corrected by recalculating)
	- 0x30B sums BonusDisc errror (corrected by recalculating)
	- 0x30C NULLs in bu.
	- 0x30D sums VAT errror (corrected by recalculating)
	- 0x30E Posted without entries while bill type auto-generates entry
	
	
	- 0x901 unknown DefStoreGUID.
	- 0x902 unknown DefBillAccGUID.
	- 0x903 unknown check DefCashAccGUID.
	- 0x904 unknown DefDiscAccGUID.
	- 0x905 unknown DefExtraAccGUID.
	- 0x906 unknown DefVATAccGUID.
	- 0x907 unknown DefCostAccGUID.
	- 0x908 unknown DefStockAccGUID.
*/ 
	SET NOCOUNT ON
	IF (@LogGuid <> 0X00)
	BEGIN
		IF  EXISTS(SELECT * FROM MaintenanceLog000 WHERE [Guid] = @LogGuid)
		BEGIN
	
		INSERT INTO MaintenanceLogItem000 ( GUID, ParentGUID, Severity, LogTime, ErrorSourceGUID1, ErrorSourceType1,ErrorSourceGUID2, ErrorSourceType2, Notes)
			SELECT NEWID(), @LogGuid, 3,GETDATE(), G1,
			CASE 
				WHEN c1 >= 0x001  OR c1 <= 0x007 THEN 268529664
				WHEN C1 <= 0x908 OR C1 >= 0x301 THEN 268500992
				ELSE 0
			END 
			,G2,
			CASE 
				WHEN c2 >= 0x001  OR c2 <= 0x007 THEN 268529664
				WHEN C2 <= 0x908 OR C2 >= 0x301 THEN 268500992
				ELSE 0
			END, 
			CASE c1 
			WHEN 0x001 THEN 'ParentGUID closed links'
			WHEN 0x002 THEN 'ParentGUID broken links'
			WHEN 0x003 THEN 'types out of range 1, 2, 4, 8'
			WHEN 0x004 THEN 'normal accounts having final accounts as ParentGUIDs.'
			WHEN 0x005 THEN 'final accounts having normal accounts as ParentGUIDs.'
			WHEN 0x006 THEN 'unknown ci accounts.'
			WHEN 0x007 THEN 'miscalculated NSons (Corrected by recalculating).'

			WHEN 0x301 THEN 'bu without bi, corrected by deletion'
			WHEN 0x302 THEN 'unknown CustPtr'
			WHEN 0x303 THEN 'unknown CustAccount'
			WHEN 0x304 THEN 'unknown StorePtr (corrected to 1)'
			WHEN 0x305 THEN 'unknown CurrPtr (corrected to 1)'
			WHEN 0x306 THEN 'CurrVal found 0 (corrected  to 1)'
			WHEN 0x307 THEN 'sums Total errror (corrected by recalculating)'
			WHEN 0x308 THEN 'sums TotalDisc errror (corrected by recalculating)'
			WHEN 0x309 THEN 'sums TotalExtra errror (corrected by recalculating)'
			WHEN 0x30A THEN 'sums ItemsDisc errror (corrected by recalculating)'
			WHEN 0x30B THEN 'sums BonusDisc errror (corrected by recalculating)'
			WHEN 0x30C THEN 'NULLs in bu.'
			WHEN 0x30D THEN 'sums VAT errror (corrected by recalculating)'
			WHEN 0x30E THEN 'Posted without entries while bill type auto-generates entry'
			WHEN 0x901 THEN 'unknown DefStoreGUID.'
			WHEN 0x902 THEN 'unknown DefBillAccGUID.'
			WHEN 0x903 THEN 'unknown check DefCashAccGUID.'
			WHEN 0x904 THEN 'unknown DefDiscAccGUID.'
			WHEN 0x905 THEN 'unknown DefExtraAccGUID.'
			WHEN 0x906 THEN 'unknown DefVATAccGUID.'
			WHEN 0x907 THEN 'unknown DefCostAccGUID.'
			WHEN 0x908 THEN 'unknown DefStockAccGUID.'
		ELSE '' END
		FROM [ErrorLog]
		WHERE [type] != 0 AND [HostName] = HOST_NAME() AND [HostId] = HOST_ID()	
		END
	END
	SELECT * 
	FROM [ErrorLog]
	WHERE [type] != 0 AND [HostName] = HOST_NAME() AND [HostId] = HOST_ID()
	ORDER BY [Type]
###########################################################################################
#END 
