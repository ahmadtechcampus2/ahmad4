#########################################################
CREATE PROCEDURE prcUpdatePrGrAccounts
	@Group AS [UNIQUEIDENTIFIER],
	@Type AS [INT],
	@PartialUpdate AS [BIT] = 0
AS	
	BEGIN TRANSACTION
	
	-- Mats and Groups:
	CREATE TABLE [#tmt]([MatGUID] [UNIQUEIDENTIFIER])
	
	IF @Type = 1
		INSERT INTO [#tmt] SELECT [mtGUID] FROM [fnGetMatsOfGroups](@Group) WHERE (([mtGUID] NOT IN(SELECT [objGUID] FROM [ma000]) AND (@PartialUpdate=1))OR(@PartialUpdate=0))
	
	IF @Type = 2
		INSERT INTO [#tmt] SELECT [GUID] FROM [fnGetGroupsOfGroup](@Group) WHERE [GUID] <> @Group
	
	-- Delete old ma000:
	DELETE [ma000] FROM [ma000] AS [ma] INNER JOIN [#tmt] AS [t] ON [ma].[objGUID] = [t].[MatGUID] WHERE [ma].[Type] = @Type
	
	-- insert new ma000 from group info:
	INSERT INTO [ma000] ([Type], [objGUID], [BillTypeGUID], [MatAccGUID], [DiscAccGUID], [ExtraAccGUID], [VATAccGUID], [StoreAccGUID], [CostAccGUID], [BonusAccGUID], [BonusContraAccGUID], [CashAccGUID])
		SELECT @Type, [t].[MatGUID], [ma].[BillTypeGUID], [ma].[MatAccGUID], [ma].[DiscAccGUID], [ma].[ExtraAccGUID], [ma].[VATAccGUID], [ma].[StoreAccGUID], [ma].[CostAccGUID], [ma].[BonusAccGuid], [ma].[BonusContraAccGuid], [ma].[CashAccGUID]		FROM [ma000] AS [ma] CROSS JOIN [#tmt] AS [t]
		WHERE [ma].[Type] = 2 AND [ma].[objGUID] = @Group
	
	DROP TABLE [#tmt]
	
	COMMIT TRANSACTION

#########################################################
CREATE PROCEDURE prcUpdateProductsAccounts
	@GrpGUID AS [UNIQUEIDENTIFIER],
	@PartialUpdate AS [BIT] = 0
AS
	EXECUTE [prcUpdatePrGrAccounts] @GrpGUID, 1, @PartialUpdate

#########################################################
CREATE PROCEDURE prcUpdateGroupsAccounts
	@GrpGUID AS [UNIQUEIDENTIFIER]
AS
	EXECUTE [prcUpdatePrGrAccounts] @GrpGUID, 2

#########################################################
#END
