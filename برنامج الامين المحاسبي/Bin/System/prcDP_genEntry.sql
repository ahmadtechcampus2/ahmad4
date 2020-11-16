#########################################################
CREATE PROCEDURE prcDP_genEntry          
		@dpGUID [UNIQUEIDENTIFIER],       
		@entryGUID [UNIQUEIDENTIFIER] = NULL,       
		@entryNum [INT] = 0 ,     
		@entryType [UNIQUEIDENTIFIER] = NULL,
		@CeentryNum [INT] = 0, 
		@isDetailed [BIT] = 1,
		@CreateDate   [DATETIME],
		@CreateUserGUID [UNIQUEIDENTIFIER],
		@isModify [BIT] 
AS   
SET NOCOUNT ON       
	DECLARE       
		@DpNum [INT],       
		@Date [DATETIME],       
		@BranchGUID [UNIQUEIDENTIFIER],       
		@Total [FLOAT],       
		@AccGUID [UNIQUEIDENTIFIER],       
		@AccuAccGUID [UNIQUEIDENTIFIER] ,     
		@CeGuid   [UNIQUEIDENTIFIER]  ,
		@CustomerGUID [UNIQUEIDENTIFIER],       
		@AccuCustomerGUID [UNIQUEIDENTIFIER]
		  
	-- prepare new entry guid and number:         
	SET @entryGUID = ISNULL(@entryGUID, NEWID())       
	IF @entryNum = 0
		SELECT @entryNum = ISNULL(MAX(Number), 0) +1 FROM Py000 WHERE TypeGuid = @entryType
	-- prepare variables:       
	SELECT       
			@dpNum = [number],       
			@date = [date],       
			@branchGUID = [branchGUID] ,      
			@AccuAccGUID = AccuAccGUID,        
 			@AccGUID   = AccGUID      
		FROM [dp000] WHERE [guid] = @dpGUID   
		
	SET @total = (SELECT SUM([value]) FROM [dd000] WHERE [parentGUID] = @dpGUID AND [value] > 0)       
	IF @total IS NULL       
		RETURN       
	IF EXISTS(SELECT SUM([value]) FROM [dd000] WHERE [parentGUID] = @dpGUID AND [value] > 0)       
------------------------------------     
SELECT @CeGuid = newid()    
	INSERT INTO py000 (Number, Notes, Date, CurrencyVal,[Security], AccountGuid, Guid, TypeGuid, CurrencyGuid , BranchGuid)     
		SELECT @entryNum, [Notes], dp.Date, dp.CurrencyVal , dp.Security, et.DefAccGUID,  @EntryGuid, @entryType, dp.CurrencyGuid ,dp.BranchGuid    
		FROM	dp000 AS dp  INNER JOIN et000 et ON et.Guid = @entryType     
		WHERE dp.guid = @dpGUID    
		    
	INSERT INTO [er000] ([EntryGUID], [ParentGUID], [ParentType], [ParentNumber])       
			VALUES(@CeGUID, @EntryGuid, 101, @dpNum)       
---------------------------------     
-- insert entry header:       
	IF(@CeentryNum = -1)
		SET @CeentryNum = [dbo].[fnEntry_getNewNum](@BranchGUID)
	INSERT INTO [ce000] ([typeGUID], [Type], [Number], [Date], [Debit], [Credit], [Notes], [CurrencyVal], [IsPosted], [Security], [Branch], [GUID], [CurrencyGUID])           
		SELECT 0x0, 1, @CeentryNum, [Date], @total, @total, [Notes], [CurrencyVal], 0, [Security], [branchGUID], @CeGUID, [CurrencyGUID]       
		FROM [dp000]       
		WHERE [GUID] = @dpGUID       
-- insert en:       

CREATE TABLE #TMP(   
					[Number] [INT]
					, [Date] [DateTime]
					, [Debit] [float]
					, [Credit] [float]
					, [Notes] NVARCHAR (255) COLLATE ARABIC_CI_AI
					, [CurrencyVal] [float]
					, [ParentGUID] [UNIQUEIDENTIFIER]
					, [accountGUID] [UNIQUEIDENTIFIER]
					, [CurrencyGUID] [UNIQUEIDENTIFIER]
					, [CostGUID] [UNIQUEIDENTIFIER]
					, [ContraAccGUID] [UNIQUEIDENTIFIER]
					, [CustomerGUID] [UNIQUEIDENTIFIER]
                 )   
INSERT INTO #TMP
		SELECT         
			[d].[number],       
			@date,       
			0,       
			[d].[value],       
			[s].[Name] + ' ( ' + [a].[SN] + ' )',       
			[d].[CurrencyVal],       
			@CeGUID,       
			CASE @AccuAccGUID WHEN 0x0 THEN [s].[AccuDepAccGUID] ELSE @AccuAccGUID END AccuDepAccGUID,      
			[d].[CurrencyGUID],       
			[d].[CostGUID],       
			CASE @AccGUID WHEN 0x0 THEN [s].[DepAccGUID] ELSE @AccGUID END ,
			CASE ISNULL( @AccuCustomerGUID , 0x0) WHEN 0x0 THEN 0x0 ELSE @AccuCustomerGUID END 
		FROM        
			[dd000] AS [d]       
			INNER JOIN [ad000] AS [a] ON [d].[ADGUID] = [a].[GUID]        
			INNER JOIN [as000] AS [s] ON [a].[parentGUID] = [s].[GUID]       
		WHERE        
			[d].[parentGUID] = @dpGUID AND [d].[value]> 0       
		UNION ALL       
		SELECT         
			[d].[number],       
			@date,       
			[d].[value],       
			0,       
			[s].[Name] + ' ( ' + [a].[SN] + ' )',       
			[d].CurrencyVal,       
			@CeGUID,       
			CASE @AccGUID WHEN 0x0 THEN [s].[DepAccGUID] ELSE @AccGUID END DepAccGUID,       
			[d].[CurrencyGUID],       
			[d].[CostGUID],       
			CASE @AccuAccGUID WHEN 0x0 THEN [s].[AccuDepAccGUID] ELSE @AccuAccGUID END AccuDepAccGUID,
			CASE ISNULL( @CustomerGUID , 0x0) WHEN 0x0 THEN 0x0 ELSE @CustomerGUID END 
		FROM        
			[dd000] AS [d]        
			INNER JOIN [ad000] AS [a] ON [d].[ADGUID] = [a].[GUID]        
			INNER JOIN [as000] AS [s] ON [a].[parentGUID] = [s].[GUID]       
		WHERE        
			[d].[parentGUID] = @dpGUID AND [d].[value] > 0 

		IF EXISTS (SELECT * FROM  vwAcCu ac INNER JOIN #TMP t ON ac.GUID = t.accountGUID
					WHERE  CustomersCount > 1)
		BEGIN
			DECLARE @AccuGuid UNIQUEIDENTIFIER;
			SELECT @AccuGuid = GUID FROM  vwAcCu ac 
			INNER JOIN #TMP t ON ac.GUID = t.accountGUID
			WHERE 
				CustomersCount > 1
			
			INSERT INTO [ErrorLog] ([level], [type], [c1], [g1])
			SELECT 1, 0, 'AmnE0052: [' + CAST(@AccuGuid AS NVARCHAR(36)) +'] Account Have Multi customer',0x0
			RETURN 
		END

		ELSE IF EXISTS (SELECT * FROM vwAcCu ac INNER JOIN #TMP t ON ac.GUID = t.accountGUID
						WHERE  CustomersCount = 1)
		BEGIN
			UPDATE  t
			SET CustomerGUID = cu.CuGuid
			FROM #TMP t
			INNER JOIN vwCu cu ON cu.cuAccount = t.accountGUID
		END

		IF(@isDetailed = 0)
		BEGIN
			UPDATE #TMP SET notes = ''
			UPDATE #TMP SET number = 0
	
			SELECT [Number], [Date], SUM([Debit]) Debit, SUM([Credit]) Credit, [Notes], [CurrencyVal], [ParentGUID], [accountGUID], [CurrencyGUID], [CostGUID], [ContraAccGUID], CustomerGUID
			INTO #TEMP FROM #TMP
			GROUP BY [Number], [Date], [Notes], [CurrencyVal], [ParentGUID], [accountGUID], [CurrencyGUID], [CostGUID], [ContraAccGUID], CustomerGUID
	
			IF (SELECT COUNT(*) FROM #TEMP) = 1
			BEGIN 
				INSERT INTO [en000] ([Number], [Date], [Debit], [Credit], [Notes], [CurrencyVal], [ParentGUID], [accountGUID], [CurrencyGUID], [CostGUID], [ContraAccGUID], CustomerGUID)
				SELECT [Number], [Date], 0 Debit, SUM([Credit]) Credit, [Notes], [CurrencyVal], [ParentGUID], [accountGUID], [CurrencyGUID], [CostGUID], [ContraAccGUID], CustomerGUID
				FROM #TMP
				GROUP BY [Number], [Date], [Notes], [CurrencyVal], [ParentGUID], [accountGUID], [CurrencyGUID], [CostGUID], [ContraAccGUID],CustomerGUID

				INSERT INTO [en000] ([Number], [Date], [Debit], [Credit], [Notes], [CurrencyVal], [ParentGUID], [accountGUID], [CurrencyGUID], [CostGUID], [ContraAccGUID], CustomerGUID)
				SELECT [Number], [Date], SUM([Debit]) Debit, 0 Credit, [Notes], [CurrencyVal], [ParentGUID], [accountGUID], [CurrencyGUID], [CostGUID], [ContraAccGUID], CustomerGUID
				FROM #TMP
				GROUP BY [Number], [Date], [Notes], [CurrencyVal], [ParentGUID], [accountGUID], [CurrencyGUID], [CostGUID], [ContraAccGUID], CustomerGUID

			END
			ELSE
				INSERT INTO [en000] ([Number], [Date], [Debit], [Credit], [Notes], [CurrencyVal], [ParentGUID], [accountGUID], [CurrencyGUID], [CostGUID], [ContraAccGUID], [CustomerGUID])
				SELECT [Number], [Date], SUM([Debit]) Debit, SUM([Credit]) Credit, [Notes], [CurrencyVal], [ParentGUID], [accountGUID], [CurrencyGUID], [CostGUID], [ContraAccGUID], [CustomerGUID] 
				FROM #TMP
				GROUP BY [Number], [Date], [Notes], [CurrencyVal], [ParentGUID], [accountGUID], [CurrencyGUID], [CostGUID], [ContraAccGUID],[CustomerGUID]
		END
		ELSE
			INSERT INTO [en000] ([Number], [Date], [Debit], [Credit], [Notes], [CurrencyVal], [ParentGUID], [accountGUID], [CurrencyGUID], [CostGUID], [ContraAccGUID], [CustomerGUID])
			SELECT [Number], [Date], [Debit] Debit, [Credit] Credit, [Notes], [CurrencyVal], [ParentGUID], [accountGUID], [CurrencyGUID], [CostGUID], [ContraAccGUID],  [CustomerGUID]
			FROM #TMP

	DELETE FROM En000 
	WHERE ParentGuid = @CeGUID
	AND debit = 0 AND Credit = 0
	
	UPDATE Ce000
		SET IsPosted = 0,
			CreateDate = CASE WHEN @isModify = 1 THEN  @CreateDate ELSE GETDATE() END,
			CreateUserGUID = CASE WHEN @isModify = 1 THEN  @CreateUserGUID ELSE [dbo].[fnGetCurrentUserGUID]() END,
			LastUpdateDate = CASE WHEN @isModify = 1 THEN  GETDATE() ELSE LastUpdateDate END,
			LastUpdateUserGUID = CASE WHEN @isModify = 1 THEN  [dbo].[fnGetCurrentUserGUID]() ELSE LastUpdateUserGUID END
	
		WHERE 
			Guid = @CeGUID AND Guid NOT IN (SELECT ParentGuid FROM En000)
				
	UPDATE py000
		SET 
			CreateDate = CASE WHEN @isModify = 1 THEN  @CreateDate ELSE GETDATE() END,
			CreateUserGUID = CASE WHEN @isModify = 1 THEN  @CreateUserGUID ELSE [dbo].[fnGetCurrentUserGUID]() END,
			LastUpdateDate = CASE WHEN @isModify = 1 THEN  GETDATE() ELSE LastUpdateDate END,
			LastUpdateUserGUID = CASE WHEN @isModify = 1 THEN  [dbo].[fnGetCurrentUserGUID]() ELSE LastUpdateUserGUID END
		WHERE 
			Guid = @EntryGuid

	DELETE FROM Ce000 
	WHERE Guid = @CeGUID
	AND Guid NOT IN (SELECT ParentGuid FROM En000)
		
	DELETE FROM Py000
	WHERE Guid IN
	(
		SELECT EntryGuid FROM Dp000 WHERE EntryGuid = @CeGUID AND EntryGuid NOT IN (SELECT Guid FROM Ce000)
	) 
	
	DELETE FROM Er000
	WHERE EntryGuid = @CeGUID
	AND EntryGuid NOT IN (SELECT Guid FROM Ce000)

	DECLARE @AutoPost INT
	SELECT @AutoPost = bAutoPost FROM Et000 WHERE Guid = @entryType
	IF(@AutoPost = 1)	
		UPDATE [ce000]
			 SET 
				[IsPosted] = 1,  
				[PostDate] = [Date],
				CreateDate = CASE WHEN @isModify = 1 THEN  @CreateDate ELSE GETDATE() END,
				CreateUserGUID = CASE WHEN @isModify = 1 THEN  @CreateUserGUID ELSE [dbo].[fnGetCurrentUserGUID]() END,
				LastUpdateDate = CASE WHEN @isModify = 1 THEN  GETDATE() ELSE LastUpdateDate END,
				LastUpdateUserGUID = CASE WHEN @isModify = 1 THEN  [dbo].[fnGetCurrentUserGUID]() ELSE LastUpdateUserGUID END
			WHERE 
				[GUID] = @CeGUID 
	
	UPDATE [dp000] 
			SET        
				[entryGUID] = @EntryGuid, 
				[entryNum] = @entryNum        
			WHERE 
				[guid] = @dpGUID 

	DROP TABLE #TMP
#########################################################
#END
