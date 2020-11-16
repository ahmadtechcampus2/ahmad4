#################################################################
CREATE PROCEDURE RepNotesMoves
	@AccountGuid	UNIQUEIDENTIFIER,
	@CostGuid		UNIQUEIDENTIFIER,
	@BankGuid		UNIQUEIDENTIFIER,
	@Dir			INT, -- 1 ãÞÈæÖÉ	2 ãÏÝæÚÉ	3 Çáßá
	@EventNumber	INT, -- if -1 convert to 0
	@CurrGuid		UNIQUEIDENTIFIER,
	@StartDate		DATETIME,
	@EndDate		DATETIME,
	@SrcGuid		UNIQUEIDENTIFIER	
AS
		IF(@EventNumber = -1)
			SET @EventNumber = 0

		DECLARE @UserId [UNIQUEIDENTIFIER]
		SET @UserId = [dbo].[fnGetCurrentUserGUID]()     
		CREATE TABLE [#NotesTbl]([Type] [UNIQUEIDENTIFIER], [Security] [INT]) 
		INSERT INTO [#NotesTbl] EXEC [prcGetNotesTypesList]  @SrcGuid, @UserID 
		
		CREATE TABLE [#RESULT]([chGUID] UNIQUEIDENTIFIER,
			[EventDate] DATETIME,
			[chName] NVARCHAR(255),
			[chNumber] NVARCHAR(255),
			[AccGuid] UNIQUEIDENTIFIER,
			[AccName] NVARCHAR(255),
			[EventVal_Fix] FLOAT,
			[EventCurr] NVARCHAR(255),
			[CurrVal] FLOAT,
			[EventVal] FLOAT,
			[DAGuid] UNIQUEIDENTIFIER,
			[DebitAcc] NVARCHAR(255),
			[CAGuid] UNIQUEIDENTIFIER,
			[CreditAcc] NVARCHAR(255),
			[ExRate] FLOAT)
		
		INSERT INTO #RESULT
		SELECT 
			[ch].[chGUID],
			[Date] AS [EventDate],
			[nt].[Name] AS [chName],
			CAST([ch].[chNumber] AS NVARCHAR(MAX))+':'+[ch].[chNum] AS [chNumber],
			[ch].[chAccount] AS [AccGuid],
			[ac].[acName] AS [AccName],
			([chist].[EventVal] / [chist].[CurrencyVal]) AS EventVal_Fix,
			[my].[myName] AS [EventCurr],
			[chist].[CurrencyVal] AS [CurrVal],
			[chist].[EventVal],
			[chist].[DebitAccount] AS [DAGuid],
			[acDe].[acName] AS [DebitAcc],
			[chist].[CreditAccount] AS [CAGuid],
			[acCr].[acName] AS [CreditAcc],
			[chist].[ExchangeRatesValue] AS [ExRate]
		
		FROM ChequeHistory000 chist
			INNER JOIN [vwCh] [ch] ON [ch].[chGUID] = [chist].[ChequeGUID]
			INNER JOIN [#NotesTbl] [n] ON [n].[Type] = [ch].[chType]
			INNER JOIN [nt000] [nt] ON [nt].[GUID] = [ch].[chType]
			INNER JOIN [vwAc] [ac] ON [ac].[acGUID] = [ch].[chAccount]
			INNER JOIN vwMy my ON my.myGUID = chist.CurrencyGUID
			INNER JOIN vwAc acDe ON acDe.acGUID = chist.DebitAccount
			INNER JOIN vwAc acCr ON acCr.acGUID = chist.CreditAccount
		where (@AccountGuid = 0x0 OR(ch.chAccount = @AccountGuid))
			AND (@CostGuid = 0x0 OR(ch.chCost1GUID = @CostGuid))
			AND (@BankGuid = 0x0 OR(ch.chBankGUID = @BankGuid))
			AND (@Dir = 3 OR(ch.chDir = @Dir))
			AND (@EventNumber = -1 OR(chist.EventNumber = @EventNumber))
			AND (@CurrGuid = 0x0 OR(ch.chCurrencyPtr = @CurrGuid))
			AND (@StartDate = '1980-01-01' OR(chist.[Date] >= @StartDate))
			AND (@EndDate = '1980-01-01' OR(chist.[Date] <= @EndDate))
		
		SELECT chGUID, 
			EventDate, 
			chName, 
			chNumber, 
			AccGuid, 
			AccName, 
			EventVal_Fix, 
			EventCurr, 
			CurrVal, 
			EventVal, 
			DAGuid, 
			DebitAcc, 
			CAGuid, 
			CreditAcc, 
			ExRate  
		FROM #RESULT
		ORDER BY EventDate, chNumber
		
		
		SELECT EventCurr AS EventCurr_Sum, SUM(EventVal_Fix) AS EventVal_Fix_Sum
		FROM #RESULT
		GROUP BY EventCurr
		

		--DECLARE  @Src [UNIQUEIDENTIFIER] = newid()
		--exec prcRSCREATEEntry  @Src

		--exec RepNotesMoves 
		--		0x0,
		--		0x0,
		--		0x0,
		--		3,
		--		-1,
		--		0x0,
		--		'1980-01-01',
		--		'1980-01-01',
		--		@Src

		--exec prcRSClean @Src
		--go
################################################################
#END

select * from DMSTblFile FilyBytes