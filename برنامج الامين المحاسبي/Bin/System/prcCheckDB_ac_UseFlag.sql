###########################################################################
CREATE PROCEDURE prcCheckDB_ac_UseFlag
	@Correct [INT] = 0
AS
	-- correct UseFlag
	IF @Correct <> 0
		UPDATE [ac000] SET [UseFlag] = 
				  (SELECT COUNT(*) FROM [as000]	WHERE [accGUID] = [ac000].[GUID])
				+ (SELECT COUNT(*) FROM [as000]	WHERE [depAccGUID] = [ac000].[GUID])
				+ (SELECT COUNT(*) FROM [as000]	WHERE [accuDepAccGUID] = [ac000].[GUID])
				+ (SELECT COUNT(*) FROM [bt000]	WHERE [defBillAccGUID] = [ac000].[GUID])
				+ (SELECT COUNT(*) FROM [bt000]	WHERE [defCashAccGUID] = [ac000].[GUID])
				+ (SELECT COUNT(*) FROM [bt000]	WHERE [defDiscAccGUID] = [ac000].[GUID])
				+ (SELECT COUNT(*) FROM [bt000]	WHERE [defExtraAccGUID] = [ac000].[GUID])
				+ (SELECT COUNT(*) FROM [bt000]	WHERE [defVATAccGUID] = [ac000].[GUID])
				+ (SELECT COUNT(*) FROM [bt000]	WHERE [defCostAccGUID] = [ac000].[GUID])
				+ (SELECT COUNT(*) FROM [bt000]	WHERE [defStockAccGUID] = [ac000].[GUID])
				+ (SELECT COUNT(*) FROM [bu000]	WHERE [custAccGUID] = [ac000].[GUID])
				+ (SELECT COUNT(*) FROM [bu000]	WHERE [matAccGUID] = [ac000].[GUID])
				+ (SELECT COUNT(*) FROM [ch000]	WHERE [GUID] = [ac000].[GUID])
				+ (SELECT COUNT(*) FROM [ci000]	WHERE [GUID] = [ac000].[GUID])
				+ (SELECT COUNT(*) FROM [ci000]	WHERE [sonGUID] = [ac000].[GUID])
				+ (SELECT COUNT(*) FROM [cu000]	WHERE [accountGUID] = [ac000].[GUID])
				+ (SELECT COUNT(*) FROM [di000]	WHERE [accountGUID] = [ac000].[GUID])
				+ (SELECT COUNT(*) FROM [en000]	WHERE [accountGUID] = [ac000].[GUID])
				+ (SELECT COUNT(*) FROM [en000]	WHERE [contraAccGUID] = [ac000].[GUID])
				+ (SELECT COUNT(*) FROM [et000]	WHERE [defAccGUID] = [ac000].[GUID])
				+ (SELECT COUNT(*) FROM [ma000]	WHERE [matAccGUID] = [ac000].[GUID])
				+ (SELECT COUNT(*) FROM [ma000]	WHERE [discAccGUID] = [ac000].[GUID])
				+ (SELECT COUNT(*) FROM [ma000]	WHERE [extraAccGUID] = [ac000].[GUID])
				+ (SELECT COUNT(*) FROM [ma000]	WHERE [VATAccGUID] = [ac000].[GUID])
				+ (SELECT COUNT(*) FROM [ma000]	WHERE [costAccGUID] = [ac000].[GUID])
				+ (SELECT COUNT(*) FROM [ma000]	WHERE [storeAccGUID] = [ac000].[GUID])
				+ (SELECT COUNT(*) FROM [mn000]	WHERE [inAccountGUID] = [ac000].[GUID])
				+ (SELECT COUNT(*) FROM [mn000]	WHERE [outAccountGUID] = [ac000].[GUID])
				+ (SELECT COUNT(*) FROM [mn000]	WHERE [inTempAccGUID] = [ac000].[GUID])
				+ (SELECT COUNT(*) FROM [mn000]	WHERE [outTempAccGUID] = [ac000].[GUID])
				+ (SELECT COUNT(*) FROM [nt000]	WHERE [defPayAccGUID] = [ac000].[GUID])
				+ (SELECT COUNT(*) FROM [nt000]	WHERE [defRecAccGUID] = [ac000].[GUID])
				+ (SELECT COUNT(*) FROM [nt000]	WHERE [defColAccGUID] = [ac000].[GUID])
				+ (SELECT COUNT(*) FROM [py000]	WHERE [accountGUID] = [ac000].[GUID])
				+ (SELECT COUNT(*) FROM [st000]	WHERE [accountGUID] = [ac000].[GUID])
				--+ (SELECT COUNT(*) FROM [vn000]	WHERE [accountGUID] = [ac000].[GUID])


###########################################################################
#END