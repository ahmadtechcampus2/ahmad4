############################################################################################
CREATE PROCEDURE prcCheckDB_bi_Nulls
	@Correct [INT] = 0
AS
	-- check NULLs:
	IF @Correct <> 1
	INSERT INTO [ErrorLog] ([Type], [g1]) 
		SELECT 0x408, [ParentGUID] FROM [bi000]
		WHERE
			[ParentGUID] IS NULL OR
			[Number] IS NULL OR
			[MatGUID] IS NULL OR
			[Qty] IS NULL OR
			[Order] IS NULL OR
			[OrderQnt] IS NULL OR
			[Unity] IS NULL OR
			[Price] IS NULL OR
			[BonusQnt] IS NULL OR
			[Discount] IS NULL OR
			[BonusDisc] IS NULL OR
			[Extra] IS NULL OR
			[CurrencyGUID] IS NULL OR
			[CurrencyVal] IS NULL OR
			[StoreGUID] IS NULL OR
			[Notes] IS NULL OR
			[Profits] IS NULL OR
			[Qty2] IS NULL OR
			[Qty3] IS NULL OR
			[CostGUID] IS NULL OR
			[ClassPtr] IS NULL OR
			[ExpireDate] IS NULL OR
			[ProductionDate] IS NULL OR
			[Length] IS NULL OR
			[Width] IS NULL OR
			[Height] IS NULL OR
			[VAT] IS NULL OR
			[VATRatio] IS NULL

	-- correct if necessary:
	IF @Correct <> 0
	BEGIN
		EXEC prcDisableTriggers 'bi000'
		UPDATE [bi000] SET
			[Number] = ISNULL([Number], 0),
			[MatGUID] = ISNULL([MatGUID], 0x0),
			[Qty] = ISNULL([Qty], 0),
			[Order] = ISNULL([Order], 0),
			[OrderQnt] = ISNULL([OrderQnt], 0),
			[Unity] = ISNULL([Unity], 0),
			[Price] = ISNULL([Price], 0),
			[BonusQnt] = ISNULL([BonusQnt], 0),
			[Discount] = ISNULL([Discount], 0),
			[BonusDisc] = ISNULL([BonusDisc], 0),
			[Extra] = ISNULL([Extra], 0),
			[CurrencyGUID] = ISNULL([CurrencyGUID], 0x0),
			[CurrencyVal] = ISNULL([CurrencyVal], 0),
			[StoreGUID] = ISNULL([StoreGUID], 0x0),
			[Notes] = ISNULL([Notes], ''),
			[Profits] = ISNULL([Profits], 0),
			[Qty2] = ISNULL([Qty2], 0),
			[Qty3] = ISNULL([Qty3], 0),
			[CostGUID] = ISNULL([CostGUID], 0x0),
			[ClassPtr] = ISNULL([ClassPtr], 0),
			[ExpireDate] = ISNULL([ExpireDate], '1980-1-1'),
			[ProductionDate] = ISNULL([ProductionDate], '1980-1-1'),
			[Length] = ISNULL([Length], 0),
			[Width] = ISNULL([Width], 0),
			[Height] = ISNULL([Height], 0),
			[VAT] = ISNULL([VAT],0),
			[VATRatio] = ISNULL([VATRatio], 0)
		WHERE
			[Number] IS NULL OR
			[MatGUID] IS NULL OR
			[Qty] IS NULL OR
			[Order] IS NULL OR
			[OrderQnt] IS NULL OR
			[Unity] IS NULL OR
			[Price] IS NULL OR
			[BonusQnt] IS NULL OR
			[Discount] IS NULL OR
			[BonusDisc] IS NULL OR
			[Extra] IS NULL OR
			[CurrencyGUID] IS NULL OR
			[CurrencyVal] IS NULL OR
			[StoreGUID] IS NULL OR
			[Notes] IS NULL OR
			[Profits] IS NULL OR
			[Qty2] IS NULL OR
			[Qty3] IS NULL OR
			[CostGUID] IS NULL OR
			[ClassPtr] IS NULL OR
			[ExpireDate] IS NULL OR
			[ProductionDate] IS NULL OR
			[Length] IS NULL OR
			[Width] IS NULL OR
			[Height] IS NULL OR
			[VAT] IS NULL OR
			[VATRatio] IS NULL
		ALTER TABLE [bi000] ENABLE TRIGGER ALL
	END

############################################################################################
#END