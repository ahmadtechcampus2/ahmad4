#########################################################
##	prcManufac_reNum
##		@InBillType [UNIQUEIDENTIFIER], 
##		@OutBillType [UNIQUEIDENTIFIER],
##		@ReNumMan [INT]
##
##
CREATE PROCEDURE prcManufac_reNum
	@InBillType [UNIQUEIDENTIFIER],
	@OutBillType [UNIQUEIDENTIFIER]
	
AS
	SET NOCOUNT ON	
	EXEC prcDisableTriggers 'mn000'
	EXEC prcDisableTriggers 'bu000'


	DECLARE @Tmp Table (
			[ManGUID] [UNIQUEIDENTIFIER],
			[NewNum] [INT] identity (1, 1))

	------ Insert Manuf Rec With Auto Number
	INSERT INTO @Tmp ([ManGUID])
		SELECT [mnGUID]
		FROM [vwMn]
		WHERE [mnType] = 1
		ORDER BY [mndate]

	
	UPDATE [mn000] SET
			[Number] = [t].[NewNum]
		FROM [mn000] INNER JOIN @Tmp AS [t] ON [mn000].[GUID] = [t].[ManGUID]

	-------- ReNum Bills Linked To Mn
	UPDATE [bu000] SET
			[Number] = [t].[NewNum]
		FROM 
			[bu000]  AS [bu] INNER JOIN [MB000] as [mb] ON [bu].[GUID] = [mb].[BillGUID]
			INNER JOIN @Tmp AS [t] ON [mb].[ManGUID] = [t].[ManGUID] AND ([bu].[TypeGUID] = @InBillType OR [bu].[TypeGUID] = @OutBillType)
		
	---------------------------------		
	ALTER TABLE [mn000] ENABLE TRIGGER ALL
	ALTER TABLE [bu000] ENABLE TRIGGER ALL
	
#########################################################
#END