##########################################################################
CREATE PROCEDURE repstkGetDistDisc
	@BillGuid 	[UNIQUEIDENTIFIER],
	@BillDate	[DATETIME],
	@curGuid [UNIQUEIDENTIFIER],
	@CurVal [FLOAT],
	@CoGuid [UNIQUEIDENTIFIER]
AS
	SET NOCOUNT ON
	DECLARE @MatGuid [UNIQUEIDENTIFIER],@GrGuid [UNIQUEIDENTIFIER],@Price [FLOAT],@Qty [FLOAT]
	DECLARE @c CURSOR
	SELECT  [MatGuid],[GroupGuid],SUM([Price]/CASE [bi].[Unity] WHEN 1 THEN 1 WHEN 2 THEN [Unit2Fact] ELSE [Unit3Fact] END * [bi].[Qty]) AS [Price],SUM([bi].[Qty]) AS [Qty] 
	INTO [#mt] 
	FROM [dbo].[bi000] AS [bi] INNER JOIN [mt000] AS [mt] ON [bi].[MatGuid] = [mt].[Guid]
	WHERE [ParentGuid] = @BillGuid
	GROUP BY [MatGuid],[GroupGuid]
	
	SELECT DISTINCT [dd].[Guid]
	INTO [#DDDitsc] 
		FROM [dbo].[DistDisc000] AS [dd] 
		INNER JOIN  [dbo].[DistDiscDistributor000] AS [dists] ON [dists].[ParentGuid] = [dd].[Guid]
		INNER JOIN ( SELECT DISTINCT [Dist].[Guid] FROM [dbo].[Distributor000] AS [Dist] INNER JOIN [dbo].[DistSalesman000] AS [ds] ON [ds].[Guid] = [Dist].[PrimSalesmanGUID] OR [ds].[Guid] = [Dist].[AssisSalesmanGUID] WHERE  [ds].[CostGUID] = @CoGuid) AS [DDS] ON [dists].[DistGuid] = [DDS].[Guid]
	WHERE @BillDate BETWEEN [dd].[StartDate] AND [dd].[EndDate] and [dists].[Value] = 1
	
	SELECT [mt].[MatGuid],[Percent],[Value],[AccountGUID],[Price],[Qty]
	INTO [#disc]
	FROM  [dbo].[DistDisc000] AS [d]
		INNER JOIN [#DDDitsc] AS [dd] ON [dd].[Guid] = [d].[Guid]
		INNER JOIN [#mt] AS [mt] ON [mt].[MatGuid] = [d].[MatGuid]
	WHERE [AccountGUID] <> 0X00 AND CalcType = 3 AND GivingType = 1 AND [Price] <> 0
		AND @BillDate BETWEEN [StartDate] AND [EndDate]
		AND((([CondValue] = 0) AND ([CondValueTo] = 0) ) OR ([Qty] BETWEEN [CondValue] AND [CondValueTo]))
	
	IF EXISTS(SELECT * FROM [dbo].[DistDisc000] AS [d] INNER JOIN [#DDDitsc] AS [dd] ON [dd].[Guid] = [d].[Guid] WHERE [GroupGuid] <> 0X00 AND [CalcType] = 3 AND [GivingType] = 1 AND @BillDate BETWEEN [StartDate] AND [EndDate])
	BEGIN
		SET @c = CURSOR FAST_FORWARD FOR 
			SELECT [MatGuid],[GroupGuid],[Price],[Qty] FROM [#mt]
		OPEN @c 	
		FETCH  FROM @c  INTO @MatGuid,@GrGuid,@Price,@Qty
		WHILE @@FETCH_STATUS = 0
		BEGIN
			IF 	@Price > 0
				INSERT INTO [#disc] 
					SELECT @MatGuid,[Percent],[Value],[AccountGUID],@Price,@Qty
					FROM  [dbo].[DistDisc000] AS [d]
						INNER JOIN [#DDDitsc] AS [dd] ON [dd].[Guid] = [d].[Guid]
						INNER JOIN (SELECT @GrGuid AS [guid]
							UNION
							SELECT [guid] FROM [dbo].[fnGetGroupParents](@GrGuid)
							WHERE [guid] <> 0X00 ) AS [f] ON [f].[Guid] = [d].[GroupGuid]
					WHERE [d].[GroupGuid] <> 0x00 AND [CalcType] = 3 AND [GivingType] = 1
						AND @BillDate BETWEEN [StartDate] AND [EndDate]
						AND((([CondValue] = 0) AND ([CondValueTo] = 0) ) OR (@Qty BETWEEN [CondValue] AND [CondValueTo]))
				
			FETCH  FROM @c  INTO @MatGuid,@GrGuid,@Price,@Qty
		END
		CLOSE @c
		DEALLOCATE @c
	END
	
	CREATE TABLE [#DISCOUNTS] ([Id] [INT] IDENTITY(1,1), [AccountGUID] [UNIQUEIDENTIFIER],[Discount] [FLOAT])
	
	INSERT INTO [#DISCOUNTS] ( [AccountGUID] ,[Discount])
		SELECT [AccountGUID],SUM([Value]*[Qty] + [Price]*[Percent]/100) FROM [#disc] GROUP BY  [AccountGUID]
	
	INSERT INTO [di000]([Number],[GUID],[Discount],[ParentGUID],[AccountGUID],[CurrencyGUID],[CurrencyVal],[CostGUID])
		SELECT [id],NEWID(),[Discount],@BillGuid,[AccountGUID],@curGuid,@CurVal,@CoGuid FROM [#DISCOUNTS]
	
	DECLARE @SumDic [FLOAT]
	SELECT  @SumDic = SUM([Discount]) FROM [#DISCOUNTS]
	
	UPDATE [bu000] SET [TotalDisc] = [TotalDisc] + @SumDic WHERE [Guid] = @BillGuid 
 
###############################################################################
#END