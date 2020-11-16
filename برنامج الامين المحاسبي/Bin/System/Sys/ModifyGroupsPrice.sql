##########################################################################
CREATE PROCEDURE rep_UpdateMatPrice
	@MatGuid	[UNIQUEIDENTIFIER],
	@GroupGuid	[UNIQUEIDENTIFIER],
	@CurrPtr	[UNIQUEIDENTIFIER],
	@UseUnit	[INT] = 1,
	@ImpBranchGroup	[INT] = 0,
	@WholePrice	[FLOAT] = 0,
	@HalfPrice [FLOAT] = 0,
	@RetailPrice [FLOAT] = 0,
	@ExportPrice [FLOAT] = 0,
	@EndUsePrice [FLOAT] = 0,
	@VndorPrice [FLOAT] = 0,
	@ModifyWhole	[INT] = 1,
	@ModifyHalf		[INT] = 1,
	@ModifyRetail	[INT] = 1,
	@ModifyExport	[INT] = 1,
	@ModifyVEndor	[INT] = 1,
	@ModifyEndUse	[INT] = 1,
	@MatCondGuid	[UNIQUEIDENTIFIER] = 0X00
	
AS
	SET NOCOUNT ON
	
	CREATE TABLE [#MatTbl]( [MatGUID] [UNIQUEIDENTIFIER], [mtSecurity] [INT]) 
	INSERT INTO [#MatTbl] EXEC [prcGetMatsList] 		@MatGuid, @GroupGuid ,-1,@MatCondGuid
	IF (@ImpBranchGroup = 0) AND (ISNULL(@GroupGuid,0X0) <> 0X0)
		DELETE [#MatTbl] WHERE [MatGUID] NOT IN (SELECT [GUID] FROM [MT000] WHERE [GroupGUID] = @GroupGuid) 
	
	DECLARE @UpdateSec [INT]
	DECLARE @CurrVal [FLOAT]
	SELECT @CurrVal = [CurrencyVal] FROM [my000] WHERE [Guid] = @CurrPtr
	
	SET @UpdateSec = [dbo].[fnGetUserMaterialSec_Update] ([dbo].[fnGetCurrentUserGUID]())
	BEGIN TRAN
	CREATE TABLE [#RES] ([Guid] [UNIQUEIDENTIFIER])
	IF (@UseUnit = 1)
	BEGIN
		UPDATE [MT000] 
		SET 
			[Whole] = CASE @ModifyWhole WHEN 0 THEN [Whole] ELSE @WholePrice*@CurrVal END ,
			[Half] = CASE @ModifyHalf WHEN 0 THEN [Half] ELSE @HalfPrice*@CurrVal END ,
			[EndUser] = CASE @ModifyEndUse WHEN 0 THEN [EndUser] ELSE @EndUsePrice*@CurrVal END,
			[Vendor] = CASE @ModifyVEndor WHEN 0 THEN [Vendor] ELSE @VndorPrice*@CurrVal END,
			[Export] = CASE @ModifyExport WHEN 0 THEN [Export] ELSE @ExportPrice*@CurrVal END ,
			[Retail] = CASE @ModifyRetail WHEN 0 THEN [Retail] ELSE @RetailPrice*@CurrVal END
		FROM [MT000] INNER JOIN [#MatTbl] ON [GUID] = [MatGUID]
		WHERE [SECURITY] <= @UpdateSec AND [PriceType] = 15
		
		INSERT INTO [#RES] SELECT [GUID]
		FROM [MT000] INNER JOIN [#MatTbl] ON [GUID] = [MatGUID]
		WHERE [SECURITY] <= @UpdateSec AND [PriceType] = 15 
	
	END
	ELSE IF @UseUnit = 2
	BEGIN 
		UPDATE [MT000] 
		SET 
			[Whole2] = CASE @ModifyWhole WHEN 0 THEN [Whole2] ELSE @WholePrice*@CurrVal END ,
			[Half2] = CASE @ModifyHalf WHEN 0 THEN [Half2] ELSE @HalfPrice*@CurrVal END ,
			[EndUser2] = CASE @ModifyEndUse WHEN 0 THEN [EndUser2] ELSE @EndUsePrice*@CurrVal END,
			[Vendor2] = CASE @ModifyVEndor WHEN 0 THEN [Vendor2] ELSE @VndorPrice*@CurrVal END,
			[Export2] = CASE @ModifyExport WHEN 0 THEN [Export2] ELSE @ExportPrice*@CurrVal END ,
			[Retail2] = CASE @ModifyRetail WHEN 0 THEN [Retail2] ELSE @RetailPrice*@CurrVal END

			
		FROM [MT000] INNER JOIN [#MatTbl] ON [GUID] = MatGUID
		WHERE [SECURITY] <= @UpdateSec AND [Unit2Fact] <>0 AND [PriceType] = 15
		
		INSERT INTO [#RES] SELECT [GUID]
		FROM [MT000] INNER JOIN [#MatTbl] ON [GUID] = [MatGUID]
		WHERE [SECURITY] <= @UpdateSec AND [Unit2Fact] <>0 AND [PriceType] = 15
	END
	ELSE 
	BEGIN
		UPDATE [MT000]
		SET 
			[Whole3] = CASE @ModifyWhole WHEN 0 THEN [Whole3] ELSE @WholePrice*@CurrVal END ,
			[Half3] = CASE @ModifyHalf WHEN 0 THEN [Half3] ELSE @HalfPrice*@CurrVal END ,
			[EndUser3] = CASE @ModifyEndUse WHEN 0 THEN [EndUser3] ELSE @EndUsePrice*@CurrVal END,
			[Vendor3] = CASE @ModifyVEndor WHEN 0 THEN [Vendor3] ELSE @VndorPrice*@CurrVal END,
			[Export3] = CASE @ModifyExport WHEN 0 THEN [Export3] ELSE @ExportPrice*@CurrVal END ,
			[Retail3] = CASE @ModifyRetail WHEN 0 THEN [Retail3] ELSE @RetailPrice*@CurrVal END
		FROM [MT000] INNER JOIN [#MatTbl] ON [GUID] = [MatGUID]
		WHERE [SECURITY] <= @UpdateSec AND [Unit3Fact] <>0 AND [PriceType] = 15
		
		INSERT INTO [#RES] SELECT [GUID]
		FROM [MT000] INNER JOIN [#MatTbl] ON [GUID] = [MatGUID]
		WHERE [SECURITY] <= @UpdateSec AND [Unit2Fact] <>0 AND [PriceType] = 15
	END
	
	COMMIT
	SELECT * FROM  [#RES]	


/*
PRCcONNECTIONS_ADD2 '„œÌ— '
EXEC  rep_UpdateMatPrice '00000000-0000-0000-0000-000000000000', 'e95ab79a-649f-4a71-a0ea-4e4da9a92e87', '4a1f0441-9397-44cc-b156-7965e08c4220', 1.000000, 1, 124.000000, 254.000000, 111.000000, 111.000000, 111.000000, 152.000000 

SELECT * FROM MT000
*/
###############################################################################
#END
