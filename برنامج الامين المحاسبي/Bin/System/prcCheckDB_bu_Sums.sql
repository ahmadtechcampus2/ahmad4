############################################################################################
CREATE PROCEDURE prcCheckDB_bu_Sums
	@Correct [INT] = 0
AS
	-- Sums: TotalDisc 
	IF @Correct <> 1 
		INSERT INTO [ErrorLog] ([Type], [g1], [f1], [f2]) 
			SELECT 
				0x308, 
				[bu].[GUID], 
				[bu].[TotalDisc], 
				(
				ISNULL((SELECT SUM([Discount]) FROM [bi000] WHERE [bi000].[ParentGUID] = [bu].[GUID]), 0) 
				+ 
				ISNULL((SELECT SUM([BonusDisc]) FROM [bi000] WHERE [bi000].[ParentGUID] = [bu].[GUID]), 0) 
				+
				ISNULL((SELECT SUM([Discount]) FROM [di000] WHERE [di000].[ParentGUID] = [bu].[GUID]), 0)
				) 
			FROM [bu000] AS [bu] 
			WHERE 
				ABS(ISNULL([bu].[TotalDisc], 0) - (ISNULL((SELECT SUM([Discount]) FROM [bi000] WHERE [bi000].[ParentGUID] = [bu].[GUID]), 0) + ISNULL((SELECT SUM([BonusDisc]) FROM [bi000] WHERE [bi000].[ParentGUID] = [bu].[GUID]), 0) + ISNULL((SELECT SUM([Discount]) FROM [di000] WHERE [di000].[ParentGUID] = [bu].[GUID]), 0))) > 0.1 
	-- correct TotalDisc if necessary: 
	IF @Correct <> 0 
	BEGIN 
			EXEC prcDisableTriggers 'bu000'

		UPDATE [bu000] SET [TotalDisc] = 
			ISNULL((SELECT SUM([Discount]) FROM [bi000] WHERE [bi000].[ParentGUID] = [bu].[GUID]), 0) 
			+
			ISNULL((SELECT SUM([BonusDisc]) FROM [bi000] WHERE [bi000].[ParentGUID] = [bu].[GUID]), 0) 			
			+ 
			ISNULL((SELECT SUM([Discount]) FROM [di000] WHERE [di000].[ParentGUID] = [bu].[GUID]), 0) 
		FROM [bu000] AS [bu] 
		WHERE ABS(ISNULL([bu].[TotalDisc], 0) - (ISNULL((SELECT SUM([Discount]) FROM [bi000] WHERE [bi000].[ParentGUID] = [bu].[GUID]), 0) + ISNULL((SELECT SUM([BonusDisc]) FROM [bi000] WHERE [bi000].[ParentGUID] = [bu].[GUID]), 0) + ISNULL((SELECT SUM([Discount]) FROM [di000] WHERE [di000].[ParentGUID] = [bu].[GUID]), 0))) > 0.1 

		ALTER TABLE [bu000] ENABLE TRIGGER ALL 
	END 
	-- Sums: TotalExtra: 
	IF @Correct <> 1 
		INSERT INTO [ErrorLog] ([Type], [g1], [f1], [f2]) 
			SELECT 0x309, [bu].[GUID], [bu].[TotalExtra], (ISNULL((SELECT SUM([Extra]) FROM [bi000] WHERE [bi000].[ParentGUID] = [bu].[GUID]), 0) + ISNULL((SELECT SUM([Extra]) FROM [di000] WHERE [di000].[ParentGUID] = [bu].[GUID]), 0)) 
			FROM [bu000] AS [bu] 
			WHERE ABS(ISNULL([bu].[TotalExtra], 0) - (ISNULL((SELECT SUM([Extra]) FROM [bi000] WHERE [bi000].[ParentGUID] = [bu].[GUID]), 0) + ISNULL((SELECT SUM([Extra]) FROM [di000] WHERE [di000].[ParentGUID] = [bu].[GUID]), 0))) > 0.1 
	-- correct TotalExtra if necessary: 
	IF @Correct <> 0 
	BEGIN 
			EXEC prcDisableTriggers 'bu000'
		UPDATE [bu000] SET [TotalExtra] = ISNULL((SELECT SUM([Extra]) FROM [bi000] WHERE [bi000].[ParentGUID] = [bu].[GUID]), 0) + ISNULL((SELECT SUM([Extra]) FROM [di000] WHERE [di000].[ParentGUID] = [bu].[GUID]), 0) 
			FROM [bu000] AS [bu] 
			WHERE ABS(ISNULL([bu].[TotalExtra], 0) - (ISNULL((SELECT SUM([Extra]) FROM [bi000] WHERE [bi000].[ParentGUID] = [bu].[GUID]), 0) + ISNULL((SELECT SUM([Extra]) FROM [di000] WHERE [di000].[ParentGUID] = [bu].[GUID]), 0))) > 0.1 
		ALTER TABLE [bu000] ENABLE TRIGGER ALL 
	END 
	-- Sums: ItemsDisc: 
	IF @Correct <> 1 
		INSERT INTO [ErrorLog] ([Type], [g1], [f1], [f2]) 
			SELECT 0x30A, [bu].[GUID], [bu].[ItemsDisc], ISNULL((SELECT SUM([Discount]) FROM [bi000] WHERE [bi000].[ParentGUID] = [bu].[GUID]), 0) 
			FROM [bu000] AS [bu] 
			WHERE ABS([bu].[ItemsDisc] - (SELECT SUM(Discount) FROM [bi000] WHERE [bi000].[ParentGUID] = [bu].[GUID])) > 0.1 
	 
	-- correct ItemsDisc if necessary 
	IF @Correct <> 0 
	BEGIN 
			EXEC prcDisableTriggers 'bu000'
		UPDATE [bu000] SET [ItemsDisc] = ISNULL((SELECT SUM([Discount]) FROM [bi000] WHERE [bi000].[ParentGUID] = [bu].[GUID]), 0) 
			FROM [bu000] AS [bu] 
			WHERE ABS(ISNULL([bu].[ItemsDisc], 0) - ISNULL((SELECT SUM([Discount]) FROM [bi000] WHERE [bi000].[ParentGUID] = [bu].[GUID]), 0)) > 0.1 
		ALTER TABLE [bu000] ENABLE TRIGGER ALL 
	END 
	-- Sums: BonusDisc: 
	IF @Correct <> 1 
		INSERT INTO [ErrorLog] ([Type], [g1], [f1], [f2]) 
			SELECT 0x30B, [bu].[GUID], [bu].[BonusDisc], ISNULL((SELECT SUM([biBonusDisc]) FROM [vwBiMt] WHERE [vwBiMt].[biParent] = [bu].[GUID]), 0) 
			FROM [bu000] AS [bu] 
			WHERE ABS(ISNULL([bu].[BonusDisc], 0) - ISNULL((SELECT SUM([biBonusDisc]) FROM [vwBiMt] WHERE [vwBiMt].[biParent] = [bu].[GUID]), 0)) > 0.1 
	-- correct BonusDisc if necessary 
	IF @Correct <> 0 
	BEGIN 	
		EXEC prcDisableTriggers 'bu000'
		UPDATE [bu000] SET [BonusDisc] = ISNULL((SELECT SUM([biBonusDisc]) FROM [vwBiMt] WHERE [vwBiMt].[biParent] = [bu].[GUID]), 0) 
			FROM [bu000] AS [bu] 
			WHERE ABS(ISNULL([bu].[BonusDisc], 0) - ISNULL((SELECT SUM([biBonusDisc]) FROM [vwBiMt] WHERE [vwBiMt].[biParent] = [bu].[GUID]), 0)) > 0.1 
		ALTER TABLE [bu000] ENABLE TRIGGER ALL 
	END 
	-- Sums: VAT 
	IF @Correct <> 1 
		INSERT INTO [ErrorLog] ([Type], [g1], [f1], [f2]) 
			SELECT 0x30C, [bu].[GUID], [VAT], (SELECT SUM( [bi].[VAT]) FROM [bi000] AS [bi] WHERE [bi].[ParentGUID] = [bu].[GUID]) 
			FROM [bu000] AS [bu] 
			WHERE ABS(ISNULL([bu].[VAT], 0) - ISNULL((SELECT SUM( [bi].[VAT]) FROM [bi000] AS [bi] WHERE [bi].[ParentGUID] = [bu].[GUID]), 0)) > 0.1
	
	-- correct VAT if necessary: 
	IF @Correct <> 0 
	BEGIN 
		EXEC prcDisableTriggers'bu000'
			UPDATE [bu000] SET [VAT] = ISNULL((SELECT SUM([VAT]) FROM [bi000] AS [bi] WHERE [bi].[ParentGUID] = [bu].[GUID]), 0)  
			FROM [bu000] AS [bu]
			WHERE ABS(ISNULL([bu].[VAT], 0) - ISNULL((SELECT SUM( [bi].[VAT]) FROM [bi000] AS [bi] WHERE [bi].[ParentGUID] = [bu].[GUID]), 0)) > 0.1
		ALTER TABLE [bu000] ENABLE TRIGGER ALL 
	END 

	-- Sums: Total 
	IF @Correct <> 1 
		INSERT INTO [ErrorLog] ([Type], [g1], [f1], [f2]) 
			SELECT 0x307, [bu].[GUID], [bu].[Total],  ISNULL((SELECT SUM([biPrice] * [biBillQty]) FROM [vwExtended_bi] [bi] WHERE [bi].[buGUID] = [bu].[GUID]), 0)  
			FROM [bu000] AS [bu] inner join bt000 bt on bu.TypeGuid = bt.Guid
			WHERE ABS([bu].[Total] - (SELECT SUM([biPrice] * [biBillQty]) FROM [vwExtended_bi] [bi] WHERE [bi].[buGUID] = [bu].[GUID])) > 0.1 

	-- correct Total if necessary: 
	IF @Correct <> 0 
	BEGIN 
		EXEC prcDisableTriggers 'bu000'
			UPDATE [bu000] SET [Total] = ISNULL((SELECT SUM([biPrice] * [biBillQty]) FROM [vwExtended_bi] [bi] WHERE [bi].[buGUID] = [bu].[GUID] ), 0) 
			FROM [bu000] AS [bu] INNER JOIN [bt000] [bt] ON [bu].[TypeGuid] = [bt].[Guid]
			WHERE ABS(ISNULL([bu].[Total], 0) - ISNULL((SELECT SUM([biPrice] * [biBillQty]) FROM [vwExtended_bi] [bi] WHERE [bi].[buGUID] = [bu].[GUID]), 0)) > 0.1 
		ALTER TABLE [bu000] ENABLE TRIGGER ALL
	END 
############################################################################################
#END