##########################################################################
CREATE PROCEDURE prcCopyMatAcc
	@MatSource			[UNIQUEIDENTIFIER],
	@Matdestination		[UNIQUEIDENTIFIER],
	@BrMask				[BIGINT] = 0
AS
	IF @BrMask = 0
		INSERT INTO 
			[MA000] ([Type], [ObjGUID], [BillTypeGuid], [MatAccGUID], [DiscAccGUID], [ExtraAccGUID], [VATAccGUID], [StoreAccGUID],
					[CostAccGUID], [GUID], [BonusAccGUID], [BonusContraAccGUID])
			SELECT	[Type], 
					@Matdestination,
					[BillTypeGUID],
					[MatAccGUID],
					[DiscAccGUID],
					[ExtraAccGUID],
					[VATAccGUID],
					[StoreAccGUID],
					[CostAccGUID],
					NewID(),
					[BonusAccGUID],
					[BonusContraAccGUID]
				FROM 
					[MA000]
				WHERE 
					[ObjGuid] = @MatSource
		ELSE
			INSERT INTO 
				[MA000] ([Type], [ObjGUID], [BillTypeGuid], [MatAccGUID], [DiscAccGUID], [ExtraAccGUID], [VATAccGUID], [StoreAccGUID],
						[CostAccGUID], [GUID], [BonusAccGUID], [BonusContraAccGUID])
			SELECT	[Type], 
					@Matdestination,
					[BillTypeGUID],
					CASE (SELECT [ac1].[BranchMask]&@BrMask FROM [AC000] [ac1] WHERE [ac1].[Guid] = [MatAccGUID]) WHEN 0 THEN 0X00 ELSE  [MatAccGUID] END,
					CASE (SELECT [ac2].[BranchMask]&@BrMask FROM [AC000] [ac2] WHERE [ac2].[Guid] = [DiscAccGUID]) WHEN 0 THEN 0X00 ELSE [DiscAccGUID] END,
					CASE (SELECT [ac3].[BranchMask]&@BrMask FROM [AC000] [ac3] WHERE [ac3].[Guid] = [ExtraAccGUID]) WHEN 0 THEN 0X00 ELSE [ExtraAccGUID] END,
					CASE (SELECT [ac4].[BranchMask]&@BrMask FROM [AC000] [ac4] WHERE [ac4].[Guid] = [VATAccGUID]) WHEN 0 THEN 0X00 ELSE [VATAccGUID] END,
					CASE (SELECT [ac5].[BranchMask]&@BrMask FROM [AC000] [ac5] WHERE [ac5].[Guid] = [StoreAccGUID]) WHEN 0 THEN 0X00 ELSE [StoreAccGUID] END,
					[CostAccGUID],
					NewID(),
					CASE (SELECT [ac6].[BranchMask]&@BrMask FROM [AC000] [ac6] WHERE [ac6].[Guid] = [BonusAccGUID]) WHEN 0 THEN 0X00 ELSE [BonusAccGUID] END,
					CASE (SELECT [ac7].[BranchMask]&@BrMask FROM [AC000] [ac7] WHERE [ac7].[Guid] = [BonusContraAccGUID]) WHEN 0 THEN 0X00 ELSE [BonusContraAccGUID] END
				FROM 
					[MA000] AS [ma] 
				WHERE 
						[ObjGuid] = @MatSource
	RETURN @@ROWCOUNT
	
######################################################################################
#END
 