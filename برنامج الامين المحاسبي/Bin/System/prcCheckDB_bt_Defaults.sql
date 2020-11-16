###########################################################################################
CREATE PROCEDURE prcCheckDB_bt_Defaults
	@Correct [INT] = 0
AS
/*
This method checks, corrects and reports the following:
	- 0x901 unknown DefStoreGUID.
	- 0x902 unknown DefBillAccGUID.
	- 0x903 unknown check DefCashAccGUID.
	- 0x904 unknown DefDiscAccGUID.
	- 0x905 unknown DefExtraAccGUID.
	- 0x906 unknown DefVATAccGUID.
	- 0x907 unknown DefCostAccGUID.
	- 0x908 unknown DefStockAccGUID.
*/

	-- check DefStoreGUID:
	IF @Correct <> 1
		INSERT INTO [ErrorLog]([Type], [g1])
			SELECT 0x901, [bt].[GUID] FROM [bt000] AS [bt] LEFT JOIN [st000] AS [st] ON [bt].[DefStoreGUID] = [st].[GUID] WHERE [st].[GUID] IS NULL and [bt].[DefStoreGuid] != 0x0

	-- correct by reseting to NULL:
	IF @Correct <> 0
		UPDATE [bt000] SET [DefStoreGUID] = 0x0 FROM [bt000] AS [bt] LEFT JOIN [st000] AS [st] ON [bt].[DefStoreGUID] = [st].[GUID] WHERE [st].[GUID] IS NULL and [bt].[DefStoreGuid] != 0x0

	-- check DefBillAccGUID:
	IF @Correct <> 1
		INSERT INTO [ErrorLog]([Type], [g1])
			SELECT 0x902, [bt].[GUID] FROM [bt000] AS [bt] LEFT JOIN [ac000] AS [ac] ON [bt].[DefBillAccGUID] = [ac].[GUID] WHERE [ac].[GUID] IS NULL and [bt].[DefBillAccGuid] != 0x0
	-- correct by reseting to NULL:
	IF @Correct <> 0
		UPDATE [bt000] SET [DefBillAccGUID] = 0x0 FROM [bt000] AS [bt] LEFT JOIN [ac000] AS [ac] ON [bt].[DefBillAccGUID] = [ac].[GUID] WHERE [ac].[GUID] IS NULL and [bt].[DefBillAccGuid] != 0x0

	-- check DefCashAccGUID:
	IF @Correct <> 1
		INSERT INTO [ErrorLog]([Type], [g1])
			SELECT 0x903, [bt].[GUID] FROM [bt000] AS [bt] LEFT JOIN [ac000] AS [ac] ON [bt].[DefCashAccGUID] = [ac].[GUID] WHERE [ac].[GUID] IS NULL and [bt].[DefCashAccGuid] != 0x0
	-- correct by reseting to NULL:
	IF @Correct <> 0
		UPDATE [bt000] SET [DefCashAccGUID] = 0x0 FROM [bt000] AS [bt] LEFT JOIN [ac000] AS [ac] ON [bt].[DefCashAccGUID] = [ac].[GUID] WHERE [ac].[GUID] IS NULL and [bt].[DefCashAccGuid] != 0x0

	-- check DefDiscAccGUID:
	IF @Correct <> 1
		INSERT INTO [ErrorLog]([Type], [g1])
			SELECT 0x904, [bt].[GUID] FROM [bt000] AS [bt] LEFT JOIN [ac000] AS [ac] ON [bt].[DefDiscAccGUID] = [ac].[GUID] WHERE [ac].[GUID] IS NULL and [bt].[DefDiscAccGuid] != 0x0

	-- correct by reseting to NULL:
	IF @Correct <> 0
		UPDATE [bt000] SET [DefDiscAccGUID] = 0x0 FROM [bt000] AS [bt] LEFT JOIN [ac000] AS [ac] ON [bt].[DefDiscAccGUID] = [ac].[GUID] WHERE [ac].[GUID] IS NULL and [bt].[DefDiscAccGuid] != 0x0

	-- check DefExtraAccGUID:
	IF @Correct <> 1
		INSERT INTO [ErrorLog]([Type], [g1])
			SELECT 0x905, [bt].[GUID] FROM [bt000] AS [bt] LEFT JOIN [ac000] AS [ac] ON [bt].[DefExtraAccGUID] = [ac].[GUID] WHERE [ac].[GUID] IS NULL and [bt].[DefExtraAccGuid] != 0x0
	-- correct by reseting to NULL:
	IF @Correct <> 0
		UPDATE [bt000] SET [DefExtraAccGUID] = 0x0 FROM [bt000] AS [bt] LEFT JOIN [ac000] AS [ac] ON [bt].[DefExtraAccGUID] = [ac].[GUID] WHERE [ac].[GUID] IS NULL and [bt].[DefExtraAccGuid] != 0x0

	-- check DefVATAccGUID:
	IF @Correct <> 1
		INSERT INTO [ErrorLog]([Type], [g1])
			SELECT 0x906, [bt].[GUID] FROM [bt000] AS [bt] LEFT JOIN [ac000] AS [ac] ON [bt].[DefVATAccGUID] = [ac].[GUID] WHERE [ac].[GUID] IS NULL and [bt].[DefVATAccGuid] != 0x0

	-- correct by reseting to NULL:
	IF (@@ROWCOUNT * @Correct <> 0)
		UPDATE [bt000] SET [DefVATAccGUID] = 0x0 FROM [bt000] AS [bt] LEFT JOIN [ac000] AS [ac] ON [bt].[DefVATAccGUID] = [ac].[GUID] WHERE [ac].[GUID] IS NULL and [bt].[DefVATAccGuid] != 0x0

	-- check DefCostAccGUID:
	IF @Correct <> 1
		INSERT INTO [ErrorLog]([Type], [g1])
			SELECT 0x907, [bt].[GUID] FROM [bt000] AS [bt] LEFT JOIN [ac000] AS [ac] ON [bt].[DefCostAccGUID] = [ac].[GUID] WHERE [ac].[GUID] IS NULL and [bt].[DefCostAccGuid] != 0x0

	-- correct by reseting to NULL:
	IF @Correct <> 0
		UPDATE [bt000] SET [DefCostAccGUID] = 0x0 FROM [bt000] AS [bt] LEFT JOIN [ac000] AS [ac] ON [bt].[DefCostAccGUID] = [ac].[GUID] WHERE [ac].[GUID] IS NULL and [bt].[DefCostAccGuid] != 0x0

	-- check DefStockAccGUID:
	IF @Correct <> 1
		INSERT INTO [ErrorLog]([Type], [g1])
			SELECT 0x908, [bt].[GUID] FROM [bt000] AS [bt] LEFT JOIN [ac000] AS [ac] ON [bt].[DefStockAccGUID] = [ac].[GUID] WHERE [ac].[GUID] IS NULL and [bt].[DefStockAccGuid] != 0x0

	-- correct by reseting to NULL:
	IF @Correct <> 0
		UPDATE [bt000] SET [DefStockAccGUID] = 0x0 FROM [bt000] AS [bt] LEFT JOIN [ac000] AS [ac] ON [bt].[DefStockAccGUID] = [ac].[GUID] WHERE [ac].[GUID] IS NULL and [bt].[DefStockAccGuid] != 0x0

	---------------------------------------------------------------------------
	-- check if types contain Main Accounts 

	-- check DefBillAccGUID:
	IF @Correct <> 1
		INSERT INTO [ErrorLog]([Type], [g1], [c1])
			SELECT 0x909, [bt].[GUID], [ac].[Name] FROM [bt000] AS [bt] INNER JOIN [ac000] AS [ac] ON [bt].[DefBillAccGUID] = [ac].[GUID] WHERE [ac].[NSons] != 0
	-- correct by reseting to NULL:
	IF @Correct <> 0
		UPDATE [bt000] SET [DefBillAccGUID] = 0x0 FROM [bt000] AS [bt] INNER JOIN [ac000] AS [ac] ON [bt].[DefBillAccGUID] = [ac].[GUID] WHERE  [ac].[NSons] != 0
	
	-- check DefCashAccGUID:
	IF @Correct <> 1
		INSERT INTO [ErrorLog]([Type], [g1], [c1])
			SELECT 0x909, [bt].[GUID], [ac].[Name] FROM [bt000] AS [bt] INNER JOIN [ac000] AS [ac] ON [bt].[DefCashAccGUID] = [ac].[GUID] WHERE [ac].[NSons] != 0
	-- correct by reseting to NULL:
	IF @Correct <> 0
		UPDATE [bt000] SET [DefCashAccGUID] = 0x0 FROM [bt000] AS [bt] INNER JOIN [ac000] AS [ac] ON [bt].[DefCashAccGUID] = [ac].[GUID] WHERE [ac].[NSons] != 0

	-- check DefDiscAccGUID:
	IF @Correct <> 1
		INSERT INTO [ErrorLog]([Type], [g1], [c1])
			SELECT 0x909, [bt].[GUID], [ac].[Name] FROM [bt000] AS [bt] INNER JOIN [ac000] AS [ac] ON [bt].[DefDiscAccGUID] = [ac].[GUID] WHERE [ac].[NSons] != 0

	-- correct by reseting to NULL:
	IF @Correct <> 0
		UPDATE [bt000] SET [DefDiscAccGUID] = 0x0 FROM [bt000] AS [bt] INNER JOIN [ac000] AS [ac] ON [bt].[DefDiscAccGUID] = [ac].[GUID] WHERE [ac].[NSons] != 0

	-- check DefExtraAccGUID:
	IF @Correct <> 1
		INSERT INTO [ErrorLog]([Type], [g1], [c1])
			SELECT 0x909, [bt].[GUID], [ac].[Name] FROM [bt000] AS [bt] INNER JOIN [ac000] AS [ac] ON [bt].[DefExtraAccGUID] = [ac].[GUID] WHERE [ac].[NSons] != 0
	-- correct by reseting to NULL:
	IF @Correct <> 0
		UPDATE [bt000] SET [DefExtraAccGUID] = 0x0 FROM [bt000] AS [bt] INNER JOIN [ac000] AS [ac] ON [bt].[DefExtraAccGUID] = [ac].[GUID] WHERE [ac].[NSons] != 0

	-- check DefVATAccGUID:
	IF @Correct <> 1
		INSERT INTO [ErrorLog]([Type], [g1], [c1])
			SELECT 0x909, [bt].[GUID], [ac].[Name] FROM [bt000] AS [bt] INNER JOIN [ac000] AS [ac] ON [bt].[DefVATAccGUID] = [ac].[GUID] WHERE [ac].[NSons] != 0

	-- correct by reseting to NULL:
	IF (@@ROWCOUNT * @Correct <> 0)
		UPDATE [bt000] SET [DefVATAccGUID] = 0x0 FROM [bt000] AS [bt] INNER JOIN [ac000] AS [ac] ON [bt].[DefVATAccGUID] = [ac].[GUID] WHERE [ac].[NSons] != 0

	-- check DefCostAccGUID:
	IF @Correct <> 1
		INSERT INTO [ErrorLog]([Type], [g1], [c1])
			SELECT 0x909, [bt].[GUID], [ac].[Name] FROM [bt000] AS [bt] INNER JOIN [ac000] AS [ac] ON [bt].[DefCostAccGUID] = [ac].[GUID] WHERE [ac].[NSons] != 0

	-- correct by reseting to NULL:
	IF @Correct <> 0
		UPDATE [bt000] SET [DefCostAccGUID] = 0x0 FROM [bt000] AS [bt] INNER JOIN [ac000] AS [ac] ON [bt].[DefCostAccGUID] = [ac].[GUID] WHERE [ac].[NSons] != 0

	-- check DefStockAccGUID:
	IF @Correct <> 1
		INSERT INTO [ErrorLog]([Type], [g1], [c1])
			SELECT 0x909, [bt].[GUID], [ac].[Name] FROM [bt000] AS [bt] INNER JOIN [ac000] AS [ac] ON [bt].[DefStockAccGUID] = [ac].[GUID] WHERE [ac].[NSons] != 0

	-- correct by reseting to NULL:
	IF @Correct <> 0
		UPDATE [bt000] SET [DefStockAccGUID] = 0x0 FROM [bt000] AS [bt] INNER JOIN [ac000] AS [ac] ON [bt].[DefStockAccGUID] = [ac].[GUID] WHERE [ac].[NSons] != 0
	
###########################################################################################
#END