#########################################
CREATE PROC prcPOSPay_genEntry -- Ê·Ìœ ”‰œ «·ﬁÌœ ·«Ì’«· œ›⁄ Êﬁ»÷ œÊ‰ ÊÃÊœ «·«Ê—«ﬁ «·„«·Ì… 
	@noteGUID [UNIQUEIDENTIFIER],
	@PayGUID  [UNIQUEIDENTIFIER],
	@Branch    [UNIQUEIDENTIFIER],
	@CostGUID [UNIQUEIDENTIFIER],
	@AccGuid1 [UNIQUEIDENTIFIER],
	@AccGuid2 [UNIQUEIDENTIFIER],
	@entryNum [INT] = 0 ,
	@Date DATE ,
	@Val FLOAT,
	@Notes NVARCHAR(MAX),
	@CurrencyValue FLOAT,
	@CurrencyGuid  [UNIQUEIDENTIFIER],
	@Dir INT,
	@CustGuid [UNIQUEIDENTIFIER]
AS  
	SET NOCOUNT ON  
	DECLARE  
		@entryGUID UNIQUEIDENTIFIER,  
		@branchGUID UNIQUEIDENTIFIER, 
		@defPayAccGUID UNIQUEIDENTIFIER = @AccGuid1,  
		@defRecAccGUID UNIQUEIDENTIFIER = @AccGuid2,
		@DefCurrencyGUID UNIQUEIDENTIFIER,
		@AutoPost BIT

	SELECT TOP 1 @DefCurrencyGUID = [GUID] FROM my000 WHERE CurrencyVal = 1 ORDER BY [Number] 

	-- prepare new entry guid and number:  
	SET @entryGUID = @noteGUID  
	SET @branchGUID = @Branch 
	DECLARE @ce TABLE(
		[typeGUID] UNIQUEIDENTIFIER,
		[Type] INT,
		[Number] INT,
		[Date] DATE,
		[Debit] FLOAT,
		[Credit] FLOAT,
		[Notes] NVARCHAR(1000),
		[CurrencyVal] FLOAT,
		[IsPosted] BIT,
		[Security] INT,
		[Branch] UNIQUEIDENTIFIER,
		[GUID] UNIQUEIDENTIFIER,
		[CurrencyGUID] UNIQUEIDENTIFIER,
		[PostDate] DATE)

	DECLARE @en TABLE(
		[Number] INT,
		[Date] DATE,
		[Debit] FLOAT,
		[Credit] FLOAT,
		[Notes] NVARCHAR(1000),
		[CurrencyVal] FLOAT,
		ParentGUID UNIQUEIDENTIFIER,
		AccountGUID UNIQUEIDENTIFIER,
		[CurrencyGUID] UNIQUEIDENTIFIER,
		CostGUID UNIQUEIDENTIFIER,
		ContraAccGUID UNIQUEIDENTIFIER,
		[CustomerGUID] UNIQUEIDENTIFIER)
		
	INSERT INTO @ce
	SELECT 
		@PayGUID,
		1,
		@entryNum,
		@Date,
		@Val,
		@Val,
		@Notes,
		@CurrencyValue,
		0,
		1,
		@Branch,
		@entryGUID,
		@CurrencyGuid,
		GETDATE()

	IF (@Dir = 1) --Pay Entry
	BEGIN
	INSERT INTO @en
	SELECT  
		1,
		@Date,   
		@Val,  
		0,  
		@Notes,  
		@CurrencyValue,  
		@entryGUID,  
		@defRecAccGUID,  
		@CurrencyGUID,  
		@CostGUID,  
		@defPayAccGUID, 
	 	@CustGUID 
	UNION ALL
	SELECT  
		2,  
		@Date,   
		0,  
		@val,  
		@Notes,  
		@CurrencyValue,  
		@entryGUID,  
		@defPayAccGUID,
		@CurrencyGuid,  
		0x0,  
		@defRecAccGUID, 
		0x0

	END
	ELSE
	BEGIN
		INSERT INTO @en
	SELECT  
		1,
		@Date,   
		0,  
		@Val,  
		@Notes,  
		@CurrencyValue,  
		@entryGUID,  
		@defPayAccGUID,  
		@CurrencyGUID,  
		@CostGUID,  
		@defRecAccGUID, 
	 	@CustGUID
	UNION ALL
	SELECT  
		2,  
		@Date,   
		@Val,  
		0,  
		@Notes,  
		@CurrencyValue,  
		@entryGUID,  
		@defRecAccGUID,
		@CurrencyGuid,  
		0x0,  
		@defPayAccGUID, 
		0x0
	END
	-- populate distibutive accounts:
	
	DECLARE @ControlDbColumnDebit NVARCHAR(250)
	DECLARE @ControlDbColumnCredit NVARCHAR(250)
	DECLARE @contraAccGUID UNIQUEIDENTIFIER
	
	--SELECT @dir = ch.dir FROM ch000 ch WHERE [GUID] = @noteGUID
	SELECT @ControlDbColumnDebit = CASE WHEN @dir = 1 THEN 'AccountGUID' ELSE 'Account2GUID' END
	SELECT @ControlDbColumnCredit = CASE WHEN @dir = 1 THEN 'Account2GUID' ELSE 'AccountGUID' END
		
	-- mark distributives:
	UPDATE @en
	SET [number] = - [e].[number] 
	FROM 
		@en [e] 
		INNER JOIN [ac000] [a] ON [e].[accountGuid] = [a].[guid] 
		INNER JOIN [ci000] ci ON ci.ParentGUID = a.guid 
	WHERE 
		[a].[type] = 8
		
	IF @@ROWCOUNT > 0
	BEGIN
		UPDATE en
		SET ContraAccGUID = 0x0
		FROM 
			@en en
			INNER JOIN ac000 ac ON ac.guid = en.ContraAccGUID
		WHERE 
			ac.[type] = 8

		-- insert distributives detailes:
		INSERT INTO @en( [Number], [Date], [Debit], [Credit], [Notes], [CurrencyVal], [ParentGUID], [accountGUID], [CurrencyGUID], [CostGUID], [ContraAccGUID], [CustomerGUID])
		SELECT
			- [e].[number], -- this is called unmarking.
			[e].[date],
			[e].[debit] * [acr].[Ratio] / 100,
			[e].[credit] * [acr].[Ratio] / 100,
			[e].[notes],
			[e].[currencyVal],
			[e].[parentGUID],
			[acr].[SonGUID],
			[e].[currencyGUID],
			[e].[costGUID],
			[e].[ContraAccGUID],
			[e].[CustomerGUID]
		FROM 
			@en [e]   
			INNER JOIN [ac000] [a] ON [e].[accountGuid] = [a].[guid] 
			INNER JOIN [AccCostNewRatio000] [acr] ON [a].[guid] = [acr].[PrimaryGUID]
		WHERE 
			e.Number < 0 
			AND
			[acr].ParentGUID = @noteGUID
			AND
			[acr].[ControlDbColumn] = (CASE e.Debit WHEN 0 THEN @ControlDbColumnCredit END)
			AND
			[acr].[Entry_Rel] = 0

		IF @@ROWCOUNT = 0
		BEGIN
			INSERT INTO @en( [Number], [Date], [Debit], [Credit], [Notes], [CurrencyVal], [ParentGUID], [accountGUID], [CurrencyGUID], [CostGUID], [ContraAccGUID], [CustomerGUID])
			SELECT
				- [e].[number], -- this is called unmarking.
				[e].[date],
				[e].[debit] * ci.Num2 / 100,
				[e].[credit] * ci.Num2 / 100,
				[e].[notes],
				[e].[currencyVal],
				[e].[parentGUID],
				[ci].[SonGUID],
				[e].[currencyGUID],
				[e].[costGUID],
				[e].[ContraAccGUID],
				[e].[CustomerGUID]
			FROM 
				@en [e] 
				INNER JOIN [ac000] [a] ON [e].[accountGuid] = [a].[guid] 
				INNER JOIN ci000 ci ON ci.ParentGUID = a.guid 
			WHERE 
				e.Number < 0 
		END
	END
	DELETE @en WHERE [number] < 0

	-- Replacing distributive cost centers with their sons
	SELECT @ControlDbColumnDebit = CASE WHEN @dir = 1 THEN 'Cost1GUID' ELSE 'Cost1GUID' END
	SELECT @ControlDbColumnCredit = CASE WHEN @dir = 1 THEN 'Cost1GUID' ELSE 'Cost1GUID' END

	-- mark distributive cost centers
	UPDATE @en
	SET [Number] = - [e].[Number]
	FROM
		@en e
		INNER JOIN co000 c ON e.CostGUID = c.[GUID]
		INNER JOIN CostItem000 ci ON ci.ParentGUID = c.[GUID]
	WHERE
		c.[Type] = 2

	IF @@ROWCOUNT > 0
	BEGIN
		-- Insert distributive details (sons of distributive cost center)
		INSERT INTO @en([Number], [Date], Debit, Credit, Notes, CurrencyVal, ParentGUID, AccountGUID, CurrencyGUID, CostGUID, ContraAccGUID, CustomerGUID)
		SELECT
			- [e].[Number], -- unmarking
			[e].[Date],
			[e].[Debit] * [acr].[Ratio] / 100,
			[e].[Credit] * [acr].[Ratio] / 100,
			[e].[Notes],
			[e].[CurrencyVal],
			[e].[ParentGUID],
			[e].[AccountGUID],
			[e].[CurrencyGUID],
			[acr].[SonGUID],
			[e].[ContraAccGUID],
			[e].[CustomerGUID]
		FROM
			@en e
			INNER JOIN co000 c ON e.CostGUID = c.[GUID]
			INNER JOIN AccCostNewRatio000 acr ON c.[GUID] = acr.PrimaryGUID
		WHERE
			[e].[Number] < 0
			AND
			[acr].ParentGUID = @noteGUID
			AND
			[acr].[ControlDbColumn] = (CASE e.Debit WHEN 0 THEN @ControlDbColumnCredit END)
		
		IF @@ROWCOUNT = 0
		BEGIN 
			INSERT INTO @en([Number], [Date], Debit, Credit, Notes, CurrencyVal, ParentGUID, AccountGUID, CurrencyGUID, CostGUID, ContraAccGUID, CustomerGUID)
			SELECT
				- [e].[Number], -- unmarking
				[e].[Date],
				[e].[Debit] * [ci].[Rate] / 100,
				[e].[Credit] * [ci].[Rate] / 100,
				[e].[Notes],
				[e].[CurrencyVal],
				[e].[ParentGUID],
				[e].[AccountGUID],
				[e].[CurrencyGUID],
				[ci].SonGUID,
				[e].[ContraAccGUID],
				[e].[CustomerGUID]
			FROM
				@en e
				INNER JOIN co000 c ON e.CostGUID = c.[GUID]
				INNER JOIN CostItem000 ci ON ci.ParentGUID = c.[GUID]
			WHERE
				[e].[Number] < 0
		END 
	END

	DELETE @en WHERE ISNULL([AccountGUID], 0x0) = 0x0
	DELETE @en WHERE [number] < 0
	DELETE @en WHERE [Debit] < 0 
	DELETE @en WHERE [Credit] < 0 
	DELETE @en WHERE [Debit] <= 0 AND [Credit] <= 0

	DECLARE @error BIT 
	SET @error = 0

	IF NOT EXISTS(SELECT * FROM @ce)
	BEGIN 
		SET @error = 1
		GOTO exitProc
	END 
	if NOT EXISTS(SELECT * FROM @en)
	BEGIN 
		SET @error = 1
		GOTO exitProc
	END 

	IF (SELECT ABS(SUM(Debit) - SUM(Credit)) FROM @en) > 0.01
	BEGIN 
		SET @error = 1
		GOTO exitProc
	END 

	-- insert ce:  
	INSERT INTO [ce000] ([typeGUID], [Type], [Number], [Date], [Debit], [Credit], [Notes], [CurrencyVal], [IsPosted], [Security], [Branch], [GUID], [CurrencyGUID], [PostDate])
	SELECT 
		[typeGUID], [Type], [dbo].[fnEntry_getNewNum1](@entryNum, @BranchGUID), [Date], [Debit], [Credit], [Notes], [CurrencyVal], 0, [Security], [Branch], [GUID], [CurrencyGUID], [PostDate]
	FROM @ce

	INSERT INTO [en000] ([Number], [Date], [Debit], [Credit], [Notes], [CurrencyVal], [ParentGUID], [accountGUID], [CurrencyGUID], [CostGUID], [ContraAccGUID], [CustomerGUID], Guid)
	SELECT *, NewID() FROM @en

	--Procedure for send message to users and customer 
	--where insert or modify entry
	--EXEC NSPrcObjectEvent @EnDebitID,  3, 0
	--EXEC NSPrcObjectEvent @EnCreditID, 3, 0

	-- post entry: 
		UPDATE [ce000] SET [IsPosted] = 1 WHERE [GUID] = @entryGUID 
	
	exitProc:
	-- return data about generated entry 
	SELECT 
		(CASE @error WHEN 0 THEN @entryGUID ELSE 0x0 END) AS [EntryGUID], 
		(CASE @error WHEN 0 THEN (SELECT Number FROM ce000 WHERE GUID = @entryGUID) ELSE @entryNum END) AS [EntryNumber]

#########################################
CREATE PROC prcPOSNote_genEntry -- Ê·Ìœ ”‰œ «·ﬁÌœ ·«Ì’«· œ›⁄ Êﬁ»÷ »ÊÃÊœ «·«Ê—«ﬁ «·„«·Ì… 
	@noteGUID [UNIQUEIDENTIFIER],   
	@entryNum [INT] = 0  
AS  
	SET NOCOUNT ON  

	DECLARE  
		@noteTypeGUID UNIQUEIDENTIFIER, 
		@entryGUID UNIQUEIDENTIFIER,  
		@branchGUID UNIQUEIDENTIFIER, 
		@defPayAccGUID UNIQUEIDENTIFIER,  
		@defRecAccGUID UNIQUEIDENTIFIER,
		@DefCurrencyGUID UNIQUEIDENTIFIER,
		@AutoPost BIT

	SELECT TOP 1 @DefCurrencyGUID = [GUID] FROM my000 WHERE CurrencyVal = 1 ORDER BY [Number]

	-- prepare variables data:  
	SELECT  
		@noteTypeGUID = [typeGUID], 
		@branchGUID = [BranchGUID]  
	FROM [ch000]  
	WHERE [GUID] = @noteGUID  

	-- check:
	IF @@ROWCOUNT = 0
	BEGIN
		RAISERROR('AmnE0192: Note specified was not found ...', 16, 1)
		RETURN
	END

	SELECT		 
		@defPayAccGUID = [DefPayAccGUID],  
		@defRecAccGUID = [DefRecAccGUID],
		@AutoPost = [bAutoPost]
	FROM
		 [nt000]
	WHERE 
		[GUID] = @noteTypeGUID 

	-- delete old entry:  
	EXEC [prcNote_DeleteEntry] @noteGUID 

	-- prepare new entry guid and number:  
	SET @entryGUID = @noteGUID  

	DECLARE @ce TABLE(
		[typeGUID] UNIQUEIDENTIFIER,
		[Type] INT,
		[Number] INT,
		[Date] DATE,
		[Debit] FLOAT,
		[Credit] FLOAT,
		[Notes] NVARCHAR(1000),
		[CurrencyVal] FLOAT,
		[IsPosted] BIT,
		[Security] INT,
		[Branch] UNIQUEIDENTIFIER,
		[GUID] UNIQUEIDENTIFIER,
		[CurrencyGUID] UNIQUEIDENTIFIER,
		[PostDate] DATE)

	DECLARE @en TABLE(
		[Number] INT,
		[Date] DATE,
		[Debit] FLOAT,
		[Credit] FLOAT,
		[Notes] NVARCHAR(1000),
		[CurrencyVal] FLOAT,
		ParentGUID UNIQUEIDENTIFIER,
		AccountGUID UNIQUEIDENTIFIER,
		[CurrencyGUID] UNIQUEIDENTIFIER,
		CostGUID UNIQUEIDENTIFIER,
		ContraAccGUID UNIQUEIDENTIFIER,
		[Class] [NVARCHAR](250),
		[CustomerGUID] UNIQUEIDENTIFIER)

	INSERT INTO @ce
	SELECT 
		@noteTypeGUID,
		1,
		@entryNum,
		[Date],
		[Val],
		[Val],
		[Notes],
		CASE ISNULL(@DefCurrencyGUID, 0x0)
			WHEN 0x0 THEN [CurrencyVal]
			ELSE 1
		END,
		0,
		[Security],
		[BranchGUID],
		@entryGUID,
		ISNULL(@DefCurrencyGUID, [CurrencyGUID]),
		GETDATE()
	FROM 
		[ch000]  
	WHERE 
		[GUID] = @noteGUID

	INSERT INTO @en
	SELECT  
		CASE [dir] WHEN 1 THEN 1 ELSE 2 END,
		[Date],   
		CASE [dir] WHEN 1 THEN [val] ELSE 0 END,  
		CASE [dir] WHEN 2 THEN [val] ELSE 0 END,  
		[Notes2],  
		[CurrencyVal],  
		@entryGUID,  
		CASE ISNULL( [Account2GUID], 0x0) WHEN 0x0 THEN CASE [dir] WHEN 1 THEN @defRecAccGUID ELSE @defPayAccGUID END ELSE [Account2GUID] END,  
		[CurrencyGUID],  
		[Cost2GUID],  
		CASE ISNULL( [AccountGUID], 0x0) WHEN 0x0 THEN CASE [dir] WHEN 1 THEN @defPayAccGUID ELSE @defRecAccGUID END ELSE [AccountGUID] END,
		[Num],
		0x0
	FROM [ch000]  
	WHERE [GUID] = @noteGUID  
	UNION ALL
	SELECT  
		CASE [dir] WHEN 2 THEN 1 ELSE 2 END,  
		[Date],   
		CASE [dir] WHEN 2 THEN [val] ELSE 0 END,  
		CASE [dir] WHEN 1 THEN [val] ELSE 0 END,  
		[Notes],  
		[CurrencyVal],  
		@entryGUID,  
		CASE ISNULL( [AccountGUID], 0x0) WHEN 0x0 THEN CASE [dir] WHEN 1 THEN @defPayAccGUID ELSE @defRecAccGUID END ELSE [AccountGUID] END,
		[CurrencyGUID],  
		[Cost1GUID],  
		CASE ISNULL( [Account2GUID], 0x0) WHEN 0x0 THEN CASE [dir] WHEN 1 THEN @defRecAccGUID ELSE @defPayAccGUID END ELSE [Account2GUID] END,
		[Num],
		CASE ISNULL( [AccountGUID], 0x0) WHEN 0x0 THEN 0x0 ELSE [CustomerGUID] END
	FROM [ch000]  
	WHERE [GUID] = @noteGUID

	-- populate distibutive accounts:
	DECLARE @dir INT
	DECLARE @ControlDbColumnDebit NVARCHAR(250)
	DECLARE @ControlDbColumnCredit NVARCHAR(250)
	DECLARE @contraAccGUID UNIQUEIDENTIFIER
	
	SELECT @dir = ch.dir FROM ch000 ch WHERE [GUID] = @noteGUID
	SELECT @ControlDbColumnDebit = CASE WHEN @dir = 1 THEN 'Account2GUID' ELSE 'AccountGUID' END
	SELECT @ControlDbColumnCredit = CASE WHEN @dir = 1 THEN 'AccountGUID' ELSE 'Account2GUID' END
		
	-- mark distributives:
	UPDATE @en
	SET [number] = - [e].[number] 
	FROM 
		@en [e] 
		INNER JOIN [ac000] [a] ON [e].[accountGuid] = [a].[guid] 
		INNER JOIN [ci000] ci ON ci.ParentGUID = a.guid 
	WHERE 
		[a].[type] = 8
		
	IF @@ROWCOUNT > 0
	BEGIN
		UPDATE en
		SET ContraAccGUID = 0x0
		FROM 
			@en en
			INNER JOIN ac000 ac ON ac.guid = en.ContraAccGUID
		WHERE 
			ac.[type] = 8

		-- insert distributives detailes:
		INSERT INTO @en( [Number], [Date], [Debit], [Credit], [Notes], [CurrencyVal], [ParentGUID], [accountGUID], [CurrencyGUID], [CostGUID], [ContraAccGUID], [Class], [CustomerGUID])
		SELECT
			- [e].[number], -- this is called unmarking.
			[e].[date],
			[e].[debit] * [acr].[Ratio] / 100,
			[e].[credit] * [acr].[Ratio] / 100,
			[e].[notes],
			[e].[currencyVal],
			[e].[parentGUID],
			[acr].[SonGUID],
			[e].[currencyGUID],
			[e].[costGUID],
			[e].[ContraAccGUID],
			[e].[Class],
			[e].[CustomerGUID]
		FROM 
			@en [e] 
			INNER JOIN [ac000] [a] ON [e].[accountGuid] = [a].[guid] 
			INNER JOIN [AccCostNewRatio000] [acr] ON [a].[guid] = [acr].[PrimaryGUID]
		WHERE 
			e.Number < 0 
			AND
			[acr].ParentGUID = @noteGUID
			AND
			[acr].[ControlDbColumn] = (CASE e.Debit WHEN 0 THEN @ControlDbColumnCredit ELSE @ControlDbColumnDebit END)
			AND
			[acr].[Entry_Rel] = 0

		IF @@ROWCOUNT = 0
		BEGIN
			INSERT INTO @en( [Number], [Date], [Debit], [Credit], [Notes], [CurrencyVal], [ParentGUID], [accountGUID], [CurrencyGUID], [CostGUID], [ContraAccGUID], [Class], [CustomerGUID])
			SELECT
				- [e].[number], -- this is called unmarking.
				[e].[date],
				[e].[debit] * [ci].[Num2] / 100,
				[e].[credit] * [ci].[Num2] / 100,
				[e].[notes],
				[e].[currencyVal],
				[e].[parentGUID],
				[ci].[SonGUID],
				[e].[currencyGUID],
				[e].[costGUID],
				[e].[ContraAccGUID],
				[e].[Class],
				[e].[CustomerGUID]
			FROM 
				@en [e] 
				INNER JOIN [ac000] [a] ON [e].[accountGuid] = [a].[guid] 
				INNER JOIN [ci000] [ci] ON [ci].[ParentGUID] = [a].[guid] 
			WHERE 
				[e].[Number] < 0 
		END
	END
	DELETE @en WHERE [number] < 0

	-- Replacing distributive cost centers with their sons
	SELECT @ControlDbColumnDebit = CASE WHEN @dir = 1 THEN 'Cost2GUID' ELSE 'Cost1GUID' END
	SELECT @ControlDbColumnCredit = CASE WHEN @dir = 1 THEN 'Cost1GUID' ELSE 'Cost2GUID' END

	-- mark distributive cost centers
	UPDATE @en
	SET [Number] = - [e].[Number]
	FROM
		@en e
		INNER JOIN co000 c ON e.CostGUID = c.[GUID]
		INNER JOIN CostItem000 ci ON ci.ParentGUID = c.[GUID]
	WHERE
		c.[Type] = 2

	IF @@ROWCOUNT > 0
	BEGIN
		-- Insert distributive details (sons of distributive cost center)
		INSERT INTO @en([Number], [Date], Debit, Credit, Notes, CurrencyVal, ParentGUID, AccountGUID, CurrencyGUID, CostGUID, ContraAccGUID, Class, [CustomerGUID])
		SELECT
			- [e].[Number], -- unmarking
			[e].[Date],
			[e].[Debit] * [acr].[Ratio] / 100,
			[e].[Credit] * [acr].[Ratio] / 100,
			[e].[Notes],
			[e].[CurrencyVal],
			[e].[ParentGUID],
			[e].[AccountGUID],
			[e].[CurrencyGUID],
			[acr].[SonGUID],
			[e].[ContraAccGUID],
			[e].[Class],
			[e].[CustomerGUID]
		FROM
			@en e
			INNER JOIN co000 c ON e.CostGUID = c.[GUID]
			INNER JOIN AccCostNewRatio000 acr ON c.[GUID] = acr.PrimaryGUID
		WHERE
			[e].[Number] < 0
			AND
			[acr].ParentGUID = @noteGUID
			AND
			[acr].[ControlDbColumn] = (CASE e.Debit WHEN 0 THEN @ControlDbColumnCredit ELSE @ControlDbColumnDebit END)
		
		IF @@ROWCOUNT = 0
		BEGIN 
			INSERT INTO @en([Number], [Date], Debit, Credit, Notes, CurrencyVal, ParentGUID, AccountGUID, CurrencyGUID, CostGUID, ContraAccGUID, Class, [CustomerGUID])
			SELECT
				- [e].[Number], -- unmarking
				[e].[Date],
				[e].[Debit] * [ci].[Rate] / 100,
				[e].[Credit] * [ci].[Rate] / 100,
				[e].[Notes],
				[e].[CurrencyVal],
				[e].[ParentGUID],
				[e].[AccountGUID],
				[e].[CurrencyGUID],
				[ci].[SonGUID],
				[e].[ContraAccGUID],
				[e].[Class],
				[e].[CustomerGUID]
			FROM
				@en e
				INNER JOIN co000 c ON e.CostGUID = c.[GUID]
				INNER JOIN CostItem000 ci ON ci.ParentGUID = c.[GUID]
			WHERE
				[e].[Number] < 0
		END 
	END

	DELETE @en WHERE ISNULL([AccountGUID], 0x0) = 0x0
	DELETE @en WHERE [number] < 0
	DELETE @en WHERE [Debit] < 0 
	DELETE @en WHERE [Credit] < 0 
	DELETE @en WHERE [Debit] <= 0 AND [Credit] <= 0

	DECLARE @error BIT 
	SET @error = 0

	IF NOT EXISTS(SELECT * FROM @ce)
	BEGIN 
		SET @error = 1
		GOTO exitProc
	END 
	if NOT EXISTS(SELECT * FROM @en)
	BEGIN 
		SET @error = 1
		GOTO exitProc
	END 

	IF (SELECT ABS(SUM(Debit) - SUM(Credit)) FROM @en) > 0.01
	BEGIN 
		SET @error = 1
		GOTO exitProc
	END 

	-- insert ce:  
	INSERT INTO [ce000] ([typeGUID], [Type], [Number], [Date], [Debit], [Credit], [Notes], [CurrencyVal], [IsPosted], [Security], [Branch], [GUID], [CurrencyGUID], [PostDate])
	SELECT 
		[typeGUID], [Type], [dbo].[fnEntry_getNewNum1](@entryNum, @BranchGUID), [Date], [Debit], [Credit], [Notes], [CurrencyVal], 0, [Security], [Branch], [GUID], [CurrencyGUID], [PostDate]
	FROM @ce

	INSERT INTO [en000] ([Number], [Date], [Debit], [Credit], [Notes], [CurrencyVal], [ParentGUID], [accountGUID], [CurrencyGUID], [CostGUID], [ContraAccGUID], [Class], [CustomerGUID])
	SELECT * FROM @en

	-- post entry: 
	IF @AutoPost = 1
	BEGIN
		UPDATE [ce000] SET [IsPosted] = 1 WHERE [GUID] = @entryGUID 
	END

	--INSERT INTO [er000]( [EntryGUID], [ParentGUID], [ParentType], [ParentNumber])
	--SELECT @entryGUID, @NoteGUID, 5, ISNULL( [Number], 0) FROM [ch000] WHERE [Guid] = @NoteGUID
	
	exitProc:
	-- return data about generated entry 
	SELECT 
		(CASE @error WHEN 0 THEN @entryGUID ELSE 0x0 END) AS [EntryGUID], 
		(CASE @error WHEN 0 THEN (SELECT Number FROM ce000 WHERE GUID = @entryGUID) ELSE @entryNum END) AS [EntryNumber]

#########################################
CREATE PROCEDURE prcPOSGeneratePREntry
	@Type [INT],
	@ID  [UNIQUEIDENTIFIER],
	@Date [DATE],
	@Notes [NVARCHAR](250),
	@From [UNIQUEIDENTIFIER],
	@To [UNIQUEIDENTIFIER],
	@CurrencyGUID [UNIQUEIDENTIFIER],
	@CurrencyValue [FLOAT],
	@Total		[FLOAT],
	@BranchGUID [UNIQUEIDENTIFIER],
	@CostGUID [UNIQUEIDENTIFIER],
	@BillNumber [INT],
	@BillName [NVARCHAR](250),
	@Security [INT],
	@PayGUID [UNIQUEIDENTIFIER],
	@CheckNumber [NVARCHAR](250),
	@CustGUID [UNIQUEIDENTIFIER]
	--,@i int
AS
SET NOCOUNT ON

DECLARE @Number [INT],
		@ceNumber [INT],
		@EnCreditID [UNIQUEIDENTIFIER],
		@EnDebitID [UNIQUEIDENTIFIER],
		@Value	FLOAT,
		@bManualGenEntry BIT, @AutoEntry BIT,
	    @language [INT]
SET @language = [dbo].[fnConnections_GetLanguage]()	

SET @bManualGenEntry = (SELECT bManualGenEntry FROM nt000 where guid = @PayGUID)
SET @AutoEntry = (SELECT bAutoEntry FROM nt000 where guid = @PayGUID)
SET @EnCreditID = newid()
SET @EnDebitID = newid()

SELECT @Number = ISNULL(Number, -1) FROM POSPayRecieveTable000  WHERE GUID=@ID
SELECT @ceNumber = Number FROM ce000 ce
	INNER JOIN er000 er ON er.EntryGUID=ce.guid
	WHERE er.ParentGUID = @ID

DELETE POSPayRecieveTable000 WHERE GUID=@ID
DELETE ch000 WHERE GUID=@ID

IF ISNULL(@Number, -1) = -1
	SELECT @Number = ISNULL(MAX(Number), 0) + 1 FROM POSPayRecieveTable000 WHERE Type=@Type
IF ISNULL(@ceNumber, -1) = -1
	SELECT @ceNumber = ISNULL(MAX(Number), 0) + 1 FROM ce000

INSERT INTO POSPayRecieveTable000
	([Number],[GUID],[Type],[Date],[Notes],[CurrencyGUID],[CurrencyValue],[FromAccGUID]
    ,[ToAccGUID],[Total],[BranchGUID],[Security],[BillNumber],[BillName]
	,[PayGUID],[CheckNumber],CostGUID, InsertTime, [CustomerGUID])
VALUES
(@Number,@ID,@Type,@Date,@Notes,@CurrencyGUID,@CurrencyValue,@From,@To,@Total*@CurrencyValue,@BranchGUID
	,@Security,@BillNumber,@BillName,@PayGUID,@CheckNumber, @CostGUID, GetDate(), @CustGUID)
	IF ((ISNULL(@PayGUID, 0x0) = 0x0))
	BEGIN 
		--INSERT INTO [en000] SELECT 1, GetDate(), @Total*@CurrencyValue, 0, @Notes, @CurrencyValue, '', 0, 0, 0, 0, @EnDebitID, @ID, @From, @CurrencyGUID, @CostGUID, @To,0, 0x0, 0x0
		--INSERT INTO [en000] SELECT 2, GetDate(), 0, @Total*@CurrencyValue, @Notes, @CurrencyValue, '', 0, 0, 0, 0, @EnCreditID, @ID, @To, @CurrencyGUID, @CostGUID, @From,0, 0x0, 0x0
		SET @Total = @Total*@CurrencyValue
		EXEC [prcPOSPay_genEntry] @ID, @PayGUID, @BranchGUID, @CostGUID, @To,@From, @ceNumber, @Date, @Total, @Notes, @CurrencyValue, @CurrencyGuid, @Type, @CustGUID
      END
	 

IF @Type=2 AND @BillNumber>0
BEGIN
	CREATE TABLE #temp 
	(
	    BillType UNIQUEIDENTIFIER,
		Abbrev NVARCHAR(250) collate ARABIC_CI_AI, 
		Name NVARCHAR(250) collate ARABIC_CI_AI, 
		Number float, 
		[date] DATETIME, 
		Note NVARCHAR(250) collate ARABIC_CI_AI, 
		GUID UNIQUEIDENTIFIER, 
		Debit float, 
		CurrencyVal float, 
		CurrencyGUID UNIQUEIDENTIFIER, 
		Code NVARCHAR(250) collate ARABIC_CI_AI
	)

	IF  @language = 0
		INSERT #temp EXEC  [prcPOSGetPayments] @To, 2
	ELSE
		INSERT #temp EXEC  [prcPOSGetPayments] @To, 1

	IF @@ROWCOUNT = 0
	BEGIN
		RETURN 0
	END

	SELECT @EnDebitID=GUID, @Value=Debit FROM #temp WHERE Name=@BillName AND Number=@BillNumber

	IF @@ROWCOUNT = 0
	BEGIN
		RETURN 0
	END		
	
	INSERT INTO bp000(GUID, DebtGUID, PayGUID, PayType, Val, CurrencyGUID, CurrencyVal, RecType, DebitType, ParentDebitGUID, ParentPayGUID, PayVal, PayCurVal) 
	SELECT newid(), @EnDebitID, @EnCreditID, 0, CASE WHEN @Total  > @Value THEN @Value ELSE @Total END, @CurrencyGUID, @CurrencyValue, 0, 0, 0x0, 0x0, CASE WHEN @Total > @Value THEN @Value ELSE @Total END, @CurrencyValue 

	IF @@ROWCOUNT = 0
	BEGIN
		RETURN 0
	END		

	DROP TABLE #temp
END


IF ISNULL(@PayGUID, 0x0) <> 0x0
BEGIN
    --‰„ÿ «·Ê—ﬁ… «·„«·Ì… «·„Œ «—…
   CREATE TABLE #checkDesc(TypeName NVARCHAR(250), BankGuid UNIQUEIDENTIFIER, CostCenter2 UNIQUEIDENTIFIER, GenNote BIT, GenContraNote BIT, CanFinishing BIT)
   INSERT INTO #checkDesc 
   SELECT Name, BankGUID, DefaultCostcenter, bAutoGenerateNote, bAutoGenerateContraNote, bCanFinishing
   FROM nt000 
   WHERE  guid = @PayGUID
  
    DECLARE  @chNotes1  NVARCHAR(MAX)
	DECLARE @chNumber INT, @BankGuid UNIQUEIDENTIFIER, @CostCenter2 UNIQUEIDENTIFIER = (select CostCenter2 from #checkDesc)
	DECLARE @TypeName NVARCHAR(250)= (select TypeName from #checkDesc)
	DECLARE @GenNote BIT =(select GenNote from #checkDesc),
    @GenContraNote BIT = (select GenContraNote from #checkDesc),
	@CanFinishing BIT = (select CanFinishing from #checkDesc)
	set @BankGuid = (select BankGUID from #checkDesc)
	DECLARE @BankName NVARCHAR(250) = (SELECT Code +'-'+BankName FROM Bank000 WHERE Guid = @BankGuid)

    SELECT @chNumber = ISNULL(MAX(ISNULL(NUMBER,0)),0) + 1 FROM ch000 WHERE TypeGuid = @PayGUID
	SET @chNotes1 = (CASE @GenNote WHEN 1 THEN ( [dbo].[fnStrings_get]('POS\RECEIVEDFROM', @language) + 
							(SELECT Code +'-'+ Name FROM ac000 WHERE GUID = @To)) + ' - ' + 
								(SELECT CustomerName FROM cu000 WHERE GUID = @CustGUID)  + ' ' + @TypeName +' '+
							   [dbo].[fnStrings_get]('POS\NUMBER', @language) +':'+ CONVERT(NVARCHAR(255), @chNumber)+' '+
							  +[dbo].[fnStrings_get]('POS\DATEOFPAYMENT', @language) +':'+  CONVERT(NVARCHAR(255), @Date,105)+' '+ 
							  + (CASE WHEN  @BankGuid <> 0x0  THEN [dbo].[fnStrings_get]('POS\DESTINATION', @language) +':'+ 
							  + (SELECT Code +'-'+BankName FROM Bank000 WHERE Guid = @BankGuid)+' ' ELSE ' ' END) 
								 ELSE ' ' END)
							  + @Notes 

	INSERT INTO [ch000]
	(
		[Number],
		[Dir],
		[Date],
		[DueDate],
		[ColDate],
		[Num],
		[BankGUID],
		[Notes],
		[Val],
		[CurrencyVal],
		[State],
		[Security],
		[PrevNum],
		[IntNumber],
		[FileInt],
		[FileExt],
		[FileDate],
		[OrgName],
		[GUID],
		[TypeGUID],
		[ParentGUID],
		[AccountGUID],
		[CurrencyGUID],
		[Cost1GUID],
		[Cost2GUID],
		[Account2GUID],
		[BranchGUID],
		[Notes2],
		[CustomerGUID]
	)VALUES(
		@chNumber, --Number
		1, --Dir
		@Date, --Date
		@Date, --DueDate
		@Date, --ColDate
		@CheckNumber, --Num
		@BankGuid, --Bank  
		CASE @GenNote WHEN 1 THEN @chNotes1 ELSE '' END,
		@Total*@CurrencyValue, --Val
		@CurrencyValue, --CurrencyVal
		CASE @CanFinishing WHEN 1 THEN 1 ELSE 0 END, --State
		1, --Security
		0, --PrevNum
		'', --IntNumber
		0, --FileInt
		0, --FileExt
		@Date, --FileDate
		'', --OrgName
		@ID, --GUID
		@PayGUID, --TypeGUID
		@ID, --ParentGUID
		@To, --AccountGUID
		@CurrencyGUID, --CurrencyGUID
		@CostGUID, --Cost1GUID
		@CostCenter2, --Cost2GUID
		@From, --Account2GUID
		@BranchGUID, --BranchGUID
		(CASE @GenContraNote WHEN 1 THEN @chNotes1 ELSE '' END), --Notes2
		@CustGUID) --CustomerGUID
	
	IF(((ISNULL(@PayGUID, 0x0) <> 0x0) AND @bManualGenEntry = 0 AND @AutoEntry = 1))
	  EXEC [prcPOSNote_genEntry] @ID, @ceNumber 
           
if( @bManualGenEntry = 0 )
	INSERT INTO er000 SELECT newid(), @ID, @ID, 5, @chNumber
END
ELSE
BEGIN
	INSERT INTO er000 SELECT newid(), @ID, @ID, 22, @ceNumber
END

RETURN 1
###########################
#END
