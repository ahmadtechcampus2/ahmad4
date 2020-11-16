#########################################################
CREATE PROCEDURE prcAccount_UpdateMatAcc
	@SourceAcc AS [UNIQUEIDENTIFIER],
	@TargetAcc AS [UNIQUEIDENTIFIER]
AS

	SET NOCOUNT ON
	
	BEGIN TRAN

	UPDATE [ma000]
	SET [ma000].[MatAccGUID] = @TargetAcc
	WHERE [ma000].[MatAccGUID] = @SourceAcc

	UPDATE [ma000]
	SET [ma000].[DiscAccGUID] = @TargetAcc
	WHERE [ma000].[DiscAccGUID] = @SourceAcc

	UPDATE [ma000]
	SET [ma000].[ExtraAccGUID] = @TargetAcc
	WHERE [ma000].[ExtraAccGUID] = @SourceAcc

	UPDATE [ma000]
	SET [ma000].[VATAccGUID] = @TargetAcc
	WHERE [ma000].[VATAccGUID] = @SourceAcc

	UPDATE [ma000]
	SET [ma000].[CostAccGUID] = @TargetAcc
	WHERE [ma000].[CostAccGUID] = @SourceAcc

	UPDATE [ma000]
	SET [ma000].[StoreAccGUID] = @TargetAcc
	WHERE [ma000].[StoreAccGUID] = @SourceAcc

	COMMIT TRAN

#########################################################
#END