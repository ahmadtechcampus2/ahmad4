#########################################################
CREATE PROC prcAX_genEntry
	@axGUID			[UNIQUEIDENTIFIER]
AS  
	SET NOCOUNT ON  
	DECLARE  
		@axType [INT],  
		@axNum [INT],  
		@asAccGUID [UNIQUEIDENTIFIER],  
		@adGUID [UNIQUEIDENTIFIER],  
		@branchGUID [UNIQUEIDENTIFIER]  
/*  
axType  
	0: additions  
	1: deductions  
	2: maintenance  
*/  
	-- prepare variables data:  
	
	DECLARE @entryTypeGUID	[UNIQUEIDENTIFIER]  
	DECLARE @entryGUID		[UNIQUEIDENTIFIER]
	DECLARE @entryNum		[INT]
	DECLARE @PyentryGUID	[UNIQUEIDENTIFIER]
	DECLARE @PyentryNum		[INT]
	DECLARE @asCustomerGUID  [UNIQUEIDENTIFIER]
	SELECT  
		@axType = [Type],  
		@axNum = [number],  
		@adGUID = [ADGUID],  
		@branchGUID = [branchGUID],
		@PyentryGUID = [EntryGuid],
		@PyentryNum = [EntryNum],
		@entryTypeGUID = [EntryTypeGuid]
	FROM [ax000] WHERE [GUID] = @axGUID  
	SET @asAccGUID = (SELECT CASE @axType WHEN 2 THEN [ExpensesAccGUID] ELSE [accGUID] END FROM [as000] AS [s] INNER JOIN [ad000] AS [d] ON [s].[GUID] = [d].[parentGUID] WHERE [d].[GUID] = @adGUID)  
	
	IF EXISTS (SELECT * FROM vwAcCu WHERE GUID = @asAccGUID  AND CustomersCount > 1 )
	BEGIN
	INSERT INTO [ErrorLog] ([level], [type], [c1], [g1])
		SELECT 1, 0, 'AmnE0052: [' + CAST(@asAccGUID AS NVARCHAR(36)) +'] Account Have Multi customer',0x0
		RETURN 
	END

	ELSE IF EXISTS (SELECT * FROM vwAcCu WHERE GUID = @asAccGUID  AND CustomersCount = 1 )
	BEGIN
		SELECT @asCustomerGUID = cuGUID FROM vwcu WHERE cuAccount = @asAccGUID
	END

	-- delete old entry:  
	EXEC [prcAX_DeleteEntry] @PyentryGUID  
	-- prepare new entry guid and number:  
	SET @entryGUID = NEWID() 
	SET @entryNum = [dbo].[fnEntry_getNewNum](@BranchGUID)  
	-- insert ce:  
	INSERT INTO [ce000] ([typeGUID], [Type], [Number],[Date],[Debit],[Credit],[Notes],[CurrencyVal],[IsPosted],[Security],[Branch],[GUID],[CurrencyGUID])  
		SELECT @entryTypeGUID, 1, @entryNum,[Date],[Value],[Value],[Spec],[CurrencyVal], 0,[Security],[branchGUID], @entryGUID,[CurrencyGUID]  
		FROM [ax000]  
		WHERE [GUID] = @axGUID  
	-- insert py:  
	IF( @PyentryNum = 0 )
		BEGIN
			SELECT @PyentryNum = MAX([Number]) FROM py000 where typeGuid = @entryTypeGUID 
			SET @PyentryNum = ISNULL(@PyentryNum, 0) + 1 
		END
	INSERT INTO	[py000]([Number], [Date], [Notes], [CurrencyVal], [Skip], [Security], [GUID], [TypeGuid], [AccountGuid], [CurrencyGuid], [BranchGuid]) 
	SELECT @PyentryNum, [Date], '', [CurrencyVal], 0, [Security], @PyentryGUID, @entryTypeGUID, 0x0, [CurrencyGUID], [branchGUID] 
		FROM [ax000]  
		WHERE [GUID] = @axGUID  
	-- insert en:  
	INSERT INTO [en000] ([Number], [Date], [Debit], [Credit], [Notes], [CurrencyVal], [ParentGUID], [accountGUID], [CurrencyGUID], [CostGUID], [ContraAccGUID],[CustomerGUID])  
		SELECT  
			0, 	--Number  
			[Date],  
			[value], 	--Debit  
			0, 	--Credit  
			[Notes],  
			[CurrencyVal],  
			@entryGUID,  
			CASE @axType WHEN 1 THEN [accGUID] ELSE @asAccGUID END,  
			[CurrencyGUID],  
			[CostGUID],  
			CASE @axType WHEN 1 THEN @asAccGUID ELSE [accGUID] END,
			CASE @axType WHEN 1 THEN [CustomerGUID] ELSE ISNULL(@asCustomerGUID, 0x0) END
		FROM [ax000]  
		WHERE [GUID] = @axGUID  
		UNION ALL  
		SELECT  
			1, 	--Number  
			[Date],  
			0, 	-- Debit  
			[value], 	-- Credit  
			[Notes],  
			[CurrencyVal],  
			@entryGUID,  
			CASE @axType WHEN 1 THEN @asAccGUID ELSE [accGUID] END,  
			[CurrencyGUID],  
			[CostGUID],  
			CASE @axType WHEN 1 THEN [accGUID] ELSE @asAccGUID END,
			CASE @axType WHEN 1 THEN ISNULL(@asCustomerGUID, 0x0) ELSE [CustomerGUID]  END
		FROM [ax000]  
		WHERE [GUID] = @axGUID  
	-- update ax with new entry data:  
	UPDATE [ax000] SET  
			[entryGUID] = @PyEntryGUID,  
			[entryNum] = @PyentryNum  
		WHERE [GUID] = @axGUID  

	-- post entry:  
	UPDATE [ce000] SET [IsPosted] = 1, [PostDate] = GetDate() WHERE [GUID] = @entryGUID  	
	-- update er:  
	INSERT INTO [er000] ([EntryGUID],[ParentGUID],[ParentType],[ParentNumber])  
			VALUES(@entryGUID, @PyEntryGUID, 104, @PyentryNum)  
#########################################################
#END