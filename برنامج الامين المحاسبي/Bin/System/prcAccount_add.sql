########################################################
CREATE PROC prcAccount_add
	@Number [int] = 0, 
	@Name [NVARCHAR](128), 
	@Code  [NVARCHAR](128) = '', 
	@CDate [datetime] = NULL, 
	@NSons [int] = 0, 
	@Debit [float] = 0, 
	@Credit [float] = 0, 
	@InitDebit [float] = 0, 
	@InitCredit [float] = 0, 
	@UseFlag [int] = 0, 
	@MaxDebit [float] = 0, 
	@Notes [NVARCHAR](250) = '', 
	@CurrencyVal [float] = 1, 
	@Warn [int] = 0, 
	@CheckDate [datetime] = NULL, 
	@Security [int] = 1,  
	@DebitOrCredit [int] = 0, 
	@Type [int] = 1, 
	@State [int] = 0, 
	@Num1 [float] = 0, 
	@Num2 [float] = 0, 
	@LatinName [NVARCHAR](128) = '', 
	@GUID [uniqueidentifier] = 0x0, 
	@ParentGUID [uniqueidentifier] = 0x0, 
	@FinalGUID [uniqueidentifier] = 0x0, 
	@CurrencyGUID [uniqueidentifier] = 0x0,  
	@branchMask [bigint] = 0 
as 
	SET NOCOUNT ON
	-- fix parameters: 
	-- number: 
	if isnull(@number, 0) = 0 
		set @number= isnull((select max([number]) from [ac000]), 0) + 1 
	-- code: 
	if isnull(@code, '') = '' 
		set @code = cast((isnull((select max(cast([code] as [bigint])) from [ac000] where [parentGuid] = @parentGuid), 0) + 1) as [NVARCHAR](128)) 
	-- cdate: 
	if @cdate is null 
		set @cdate = getdate() 
	-- checkDate: 
	if @checkDate is null 
		set @checkDate = [dbo].[fnDate_Amn2Sql]([dbo].[fnOption_get]('AmnCfg_FPDate', default)) 
	-- latinName: 
	if isnull(@LatinName, '') = '' 
		set @latinName = @name 
	-- guid: 
	if isnull(@guid, 0x0) = 0x0 
		set @guid = newid() 
	-- currencyGuid: 
	if isnull(@currencyGuid, 0x0) = 0x0 
		set @currencyGuid = (select top 1 [guid] from [my000] where [currencyVal] = 1) 

	-- finalGuid
	if isnull(@finalGuid, 0x0) = 0x0
		set @finalGuid = (select top 1 [guid] from [ac000] where [number] = 1)

	-- insert the new account: 
	insert into [ac000] ([Number], [Name], [Code], [CDate], [NSons], [Debit], [Credit], [InitDebit], [InitCredit], [UseFlag], [MaxDebit], [Notes], [CurrencyVal], [Warn], [CheckDate], [Security], [DebitOrCredit], [Type], [State], [Num1], [Num2], [LatinName], [GUID],[ParentGUID],[FinalGUID],[CurrencyGUID],[branchMask]) 
			select @Number, @Name, @Code, @CDate, @NSons, @Debit, @Credit, @InitDebit, @InitCredit, @UseFlag, @MaxDebit, @Notes, @CurrencyVal, @Warn, @CheckDate, @Security, @DebitOrCredit, @Type, @State, @Num1, @Num2, @LatinName, @GUID, @ParentGUID, @FinalGUID, @CurrencyGUID, @branchMask 


########################################################
#END 