#########################################################
CREATE PROC prcNote_genEntry
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
		@NoteCurrencyGUID UNIQUEIDENTIFIER,
		@AutoPost BIT,
		@AutoManualGen BIT

	SELECT TOP 1 @DefCurrencyGUID = [GUID] FROM my000 WHERE CurrencyVal = 1 ORDER BY [Number]

	-- prepare variables data:  
	SELECT  
		@noteTypeGUID = [typeGUID], 
		@branchGUID = [BranchGUID],
		@NoteCurrencyGUID = [CurrencyGUID]
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
		@AutoPost = [bAutoPost],
		@AutoManualGen = [bManualGenEntry]
	FROM
		 [nt000]
	WHERE 
		[GUID] = @noteTypeGUID 

	CREATE TABLE #resbp(bpguid UNIQUEIDENTIFIER,type INT,acc UNIQUEIDENTIFIER)
	
	

	INSERT INTO #resbp
		SELECT bp.GUID,1,en.AccountGUID FROM ER000 er
		INNER JOIN EN000 en ON en.ParentGUID= er.EntryGUID AND er.ParentGUID =@noteGUID and er.ParentType=5
		INNER JOIN bp000 bp ON en.GUID= bp.PayGUID

	INSERT INTO #resbp
		SELECT bp.GUID,2,en.AccountGUID FROM ER000 er
		INNER JOIN EN000 en ON en.ParentGUID= er.EntryGUID AND er.ParentGUID =@noteGUID and er.ParentType=5
		INNER JOIN bp000 bp ON en.GUID= bp.DebtGUID

	SELECT bp.*  INTO #bp FROM bp000 bp
	INNER JOIN  #resbp re on re.bpguid= bp.GUID 


	DELETE  From ce000
	where guid=(select entryguid from er000 where ParentGUID =@noteGUID and ParentType=5)
	-- delete old entry:  
	EXEC [prcNote_DeleteEntry] @noteGUID 

	-- prepare new entry guid and number:  
	SET @entryGUID = NEWID()  

	UPDATE ch000
			SET Account2GUID=(CASE ISNULL( [Account2GUID], 0x0) WHEN 0x0 THEN CASE [dir] WHEN 1 THEN @defRecAccGUID ELSE @defPayAccGUID END ELSE [Account2GUID] END)
	WHERE guid=@noteGUID

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
		[Number] FLOAT,
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
		[CustGuid] UNIQUEIDENTIFIER)

	INSERT INTO @ce
	SELECT 
		@noteTypeGUID,
		1,
		@entryNum,
		[Date],
		[Val],
		[Val],
		[Notes],
		CASE ISNULL(@NoteCurrencyGUID, 0x0)
			WHEN 0x0 THEN 1
			ELSE [CurrencyVal]
		END,
		0,
		[Security],
		[BranchGUID],
		@entryGUID,
		ISNULL(@NoteCurrencyGUID, @DefCurrencyGUID),
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
		[CustomerGuid]  
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
		INSERT INTO @en( [Number], [Date], [Debit], [Credit], [Notes], [CurrencyVal], [ParentGUID], [accountGUID], [CurrencyGUID], [CostGUID], [ContraAccGUID], [Class], [CustGuid])
		SELECT
			-[e].[number] + 0.0001 * (ROW_NUMBER() OVER (ORDER BY acr.Number)), -- this is called unmarking.
			[e].[date],
			[e].[debit] * [acr].[Ratio] / 100,
			[e].[credit] * [acr].[Ratio] / 100,
			[e].[notes],
			[e].[currencyVal],
			[e].[parentGUID],
			[acr].[SonGUID],
			[e].[currencyGUID],
			[e].[costGUID],
			e.ContraAccGUID,
			[e].[Class],
			CASE ISNULL(acr.CustomerGUID, 0x0) WHEN 0x0 THEN [e].[CustGuid] ELSE acr.CustomerGUID END 
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
			INSERT INTO @en( [Number], [Date], [Debit], [Credit], [Notes], [CurrencyVal], [ParentGUID], [accountGUID], [CurrencyGUID], [CostGUID], [ContraAccGUID], [Class], [CustGuid])
			SELECT
				-[e].[number] + 0.0001 * (ROW_NUMBER() OVER (ORDER BY ci.Item)), -- this is called unmarking.
				[e].[date],
				[e].[debit] * ci.Num2 / 100,
				[e].[credit] * ci.Num2 / 100,
				[e].[notes],
				[e].[currencyVal],
				[e].[parentGUID],
				ci.SonGUID,
				[e].[currencyGUID],
				[e].[costGUID],
				e.ContraAccGUID,
				[e].[Class],
				CASE ISNULL(ci.CustomerGUID, 0x0) WHEN 0x0 THEN [e].[CustGuid] ELSE ci.CustomerGUID END 
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
		INSERT INTO @en([Number], [Date], Debit, Credit, Notes, CurrencyVal, ParentGUID, AccountGUID, CurrencyGUID, CostGUID, ContraAccGUID, Class, CustGuid)
		SELECT
			-[e].[number] + 0.0001 * (ROW_NUMBER() OVER (ORDER BY acr.Number)), -- this is called unmarking.
			e.[Date],
			e.[Debit] * [acr].[Ratio] / 100,
			e.[Credit] * [acr].[Ratio] / 100,
			e.[Notes],
			e.[CurrencyVal],
			e.[ParentGUID],
			e.[AccountGUID],
			e.[CurrencyGUID],
			[acr].[SonGUID],
			e.[ContraAccGUID],
			e.[Class],
			[e].[CustGuid]
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
			INSERT INTO @en([Number], [Date], Debit, Credit, Notes, CurrencyVal, ParentGUID, AccountGUID, CurrencyGUID, CostGUID, ContraAccGUID, Class, CustGuid)
			SELECT
				-[e].[number] + 0.0001 * (ROW_NUMBER() OVER (ORDER BY ci.Number)), -- this is called unmarking.
				e.[Date],
				e.[Debit] * ci.Rate / 100,
				e.[Credit] * ci.Rate / 100,
				e.[Notes],
				e.[CurrencyVal],
				e.[ParentGUID],
				e.[AccountGUID],
				e.[CurrencyGUID],
				ci.SonGUID,
				e.[ContraAccGUID],
				e.[Class],
				[e].[CustGuid]
			FROM
				@en e
				INNER JOIN co000 c ON e.CostGUID = c.[GUID]
				INNER JOIN CostItem000 ci ON ci.ParentGUID = c.[GUID]
			WHERE
				[e].[Number] < 0
		END 
	END

	DELETE @en WHERE 
	(ISNULL([AccountGUID], 0x0) = 0x0) OR
	([number] < 0) OR
	([Debit] < 0) OR
	([Credit] < 0) OR
	([Debit] <= 0 AND [Credit] <= 0)

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
	DECLARE @AccoutnGUID UNIQUEIDENTIFIER;

	UPDATE t
		SET CustGuid = cu.GUID 
		FROM @en t  
			INNER JOIN vwAcCu ac ON t.accountGUID = ac.GUID
			LEFT JOIN cu000 cu ON cu.AccountGUID = t.accountGUID
		WHERE ISNULL(t.CustGuid, 0x0) = 0x0
			AND ac.CustomersCount = 1

	IF EXISTS(SELECT t.accountGUID
	FROM @en t  
		INNER JOIN vwAcCu ac ON t.accountGUID = ac.GUID
		LEFT JOIN cu000 cu ON cu.AccountGUID = t.accountGUID
	WHERE ISNULL(t.CustGuid, 0x0) = 0x0
		AND ac.CustomersCount > 1)
	BEGIN
		SELECT TOP 1 @AccoutnGUID = t.accountGUID
		FROM @en t  
			INNER JOIN vwAcCu ac ON t.accountGUID = ac.GUID
			LEFT JOIN cu000 cu ON cu.AccountGUID = t.accountGUID
		WHERE ISNULL(t.CustGuid, 0x0) = 0x0
			AND ac.CustomersCount > 1

		INSERT INTO [ErrorLog] ([level], [type], [c1], [g1])
		SELECT 1, 0, 'AmnE052: [' + CAST(@AccoutnGUID AS NVARCHAR(36)) +'] Account Have Multi customer',0x0
		RETURN
	END

	-- insert ce:  
	INSERT INTO [ce000] ([typeGUID], [Type], [Number], [Date], [Debit], [Credit], [Notes], [CurrencyVal], [IsPosted], [Security], [Branch], [GUID], [CurrencyGUID], [PostDate])
	SELECT 
		[typeGUID], [Type], [dbo].[fnEntry_getNewNum1](@entryNum, @BranchGUID), [Date], [Debit], [Credit], [Notes], [CurrencyVal], 0, [Security], [Branch], [GUID], [CurrencyGUID], [PostDate]
	FROM @ce

	INSERT INTO [en000] ([Number], [Date], [Debit], [Credit], [Notes], [CurrencyVal], [ParentGUID], [accountGUID], [CurrencyGUID], [CostGUID], [ContraAccGUID], [Class], [CustomerGUID])
	SELECT 
	ROW_NUMBER() OVER (ORDER BY Number), [Date], [Debit], [Credit], [Notes], [CurrencyVal], [ParentGUID], [accountGUID], [CurrencyGUID], [CostGUID], [ContraAccGUID], [Class], [CustGuid]
	FROM @en

	-- post entry: 
	IF @AutoPost = 1
	BEGIN
		UPDATE [ce000] SET [IsPosted] = 1 WHERE [GUID] = @entryGUID 
	END

	IF @AutoManualGen = 0
	BEGIN
		UPDATE ChequeHistory000 SET EntryNumber = (select Number FROM ce000 WHERE [GUID] = @entryGUID) WHERE [ChequeGUID] = @noteGUID
	END

	INSERT INTO [er000]( [EntryGUID], [ParentGUID], [ParentType], [ParentNumber])
	SELECT @entryGUID, @NoteGUID, 5, ISNULL( [Number], 0) FROM [ch000] WHERE [Guid] = @NoteGUID

	UPDATE bp
			SET bp.PayGUID=(CASE WHEN b.type = 1 THEN en.guid ELSE bp.PayGUID END),
				bp.DebtGUID=(CASE WHEN b.type =2 then en.GUID ELSE bp.DebtGUID END)
	FROM #bp bp INNER JOIN #resbp b on bp.GUID = b.bpguid
	INNER JOIN en000 en on en.AccountGUID= b.acc
	INNER JOIN er000 er on er.EntryGUID= en.ParentGUID AND er.ParentGUID=@noteGUID AND ParentType=5

	INSERT INTO bp000
	SELECT * FROM #bp

	exitProc:
	-- return data about generated entry 
	SELECT 
		(CASE @error WHEN 0 THEN @entryGUID ELSE 0x0 END) AS [EntryGUID], 
		(CASE @error WHEN 0 THEN (SELECT Number FROM ce000 WHERE GUID = @entryGUID) ELSE @entryNum END) AS [EntryNumber]
##############################################################################################
CREATE  FUNCTION fnGetEntryNumberOFCheque
 (@cheuqeEntry UNIQUEIDENTIFIER)  RETURNS INT 
 AS
 BEGIN
	RETURN (SELECT count(*) as count FROM  ER000 WHERE ParentGUID=@cheuqeEntry);
END
######################################################################
#END