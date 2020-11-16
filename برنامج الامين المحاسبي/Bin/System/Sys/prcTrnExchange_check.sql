###############################################
CREATE PROCEDURE prcTrnExchange_check
	@ErrorType INT
AS
	SET NOCOUNT ON
	DECLARE @Result TABLE (
			[ExGUID] [UNIQUEIDENTIFIER],
			[ExNumber] [INT],
			[CeGUID] [UNIQUEIDENTIFIER],
			[CeNumber] [INT],
			[ParentType] [INT],
			[Date] [DateTime],
			[PayCurrency][UNIQUEIDENTIFIER],		
			[PayCurrVal] [FLOAT],
			[PayCurrAvg][FLOAT],
			[Fixed] [INT],
			[ErrorType] [INT])  
	
	IF (@ErrorType & 1 = 1)
	BEGIN
		-- „·›«  ’—«›… ·Ì” ·Â« ”‰œ 
		INSERT INTO @Result ([ExGUID], [ExNumber], [ParentType], [Fixed], [ErrorType])
			SELECT  
				ex.Guid,
				ex.Number,
				507,
				0,
				1
			FROM TrnExchange000 as ex 
			LEFT JOIN Ce000 as ce on ex.EntryGuid = ce.Guid
			WHERE  Ce.Guid is NULL

		INSERT INTO @Result ([ExGUID], [ExNumber], [ParentType], [Fixed],[ErrorType])
			SELECT  
				cl.Guid,
				cl.Number,
				517,
				0,
				1
			FROM TrnCloseCashier000 AS cl
			LEFT JOIN Ce000 AS ce ON cl.EntryGuid = ce.Guid
			WHERE  Ce.Guid IS NULL
	END

	IF (@ErrorType & 2 = 2)
	BEGIN
		-- ”‰œ«  «·’—«›… «·€Ì— „— Ìÿ… »‹„·›«  «·’—«›…
		INSERT INTO @Result ([ExGUID], [ExNumber],[CeGUID], [CeNumber], [ParentType], [Fixed], [ErrorType])
		SELECT  
				er.parentGuid, 
				er.parentNumber,
				[Ce].[Guid],  
				[Ce].[Number],
				Er.ParentType,
				0,
				2
			FROM  
				Ce000 as ce 
				inner join Er000 as er on er.EntryGuid = ce.Guid 
				LEFT JOIN TrnExchange000 as ex on ex.EntryGuid = ce.Guid
			WHERE  er.ParentType = 507 AND [ex].[Guid] IS NULL 

		INSERT INTO @Result([ExGUID], [ExNumber],[CeGUID], [CeNumber], [ParentType], [Fixed],[ErrorType])
			SELECT  
				er.parentGuid, 
				er.parentNumber,
				[Ce].[Guid],  
				[Ce].[Number],
				Er.ParentType,
				0,
				2
			FROM  
				Ce000 as ce 
				inner join Er000 as er on er.EntryGuid = ce.Guid 
				LEFT JOIN TrnCloseCashier000 as c on c.EntryGuid = ce.Guid
			WHERE  er.ParentType = 517 AND [c].[Guid] IS NULL 

		EXEC  prcDisableTriggers 'ce000'
		EXEC  prcDisableTriggers 'en000'
			Delete from Ce000 where Guid in (select CeGuid From @Result where ErrorType = 1)
			Delete from En000 where ParentGuid in (select CeGuid From @Result where ErrorType = 1)
			Delete From er000 where EntryGuid in  (select CeGuid From @Result where ErrorType = 1)
		EXEC prcEnableTriggers 'ce000' 
		EXEC prcEnableTriggers 'en000' 

		update @Result
		set Fixed = 1
		Where ErrorType = 1 AND CeGuid not In(select Guid From ce000)
	END	
	if (@ErrorType & 4 = 4)
	BEGIN
		-- „·›«  ’—«›… „· „‰Â«  Ê·œ √ﬂÀ— „‰ ”‰œ Ê«Õœ 
		INSERT INTO @Result ([ExGUID], [ExNumber],[CeGUID], [CeNumber], [ParentType], [Fixed],[ErrorType])
			SELECT  
				er.ParentGuid,--ex.guid,
				er.parentNumber,--ex.number,
				[Ce].[Guid],  
				[Ce].[Number],
				Er.ParentType,
				0,
				4
			FROM TrnExchange000 as ex
			INNER JOIN Er000 as er on er.ParentGuid = ex.Guid
			INNER JOIN CE000 AS CE on ce.Guid = er.EntryGuid AND ex.EntryGuid <> ce.Guid 
			WHERE er.ParentType = 507

		INSERT INTO @Result([ExGUID], [ExNumber],[CeGUID], [CeNumber], [ParentType], [Fixed],[ErrorType])
			SELECT  
				cl.guid,
				cl.number,
				[Ce].[Guid],  
				[Ce].[Number],
				Er.ParentType,
				0,
				4
			FROM TrnCloseCashier000 as Cl
			INNER JOIN Er000 as er on er.ParentGuid = cl.Guid
			INNER JOIN CE000 AS CE on ce.Guid = er.EntryGuid AND cl.EntryGuid <> ce.Guid 
			WHERE er.ParentType = 517

		EXEC  prcDisableTriggers 'ce000'
		EXEC  prcDisableTriggers 'en000'			Delete from Ce000 where Guid in (select CeGuid From @Result where ErrorType = 2)
			Delete from En000 where ParentGuid in (select CeGuid From @Result where ErrorType = 2)
			Delete From er000 where EntryGuid in  (select CeGuid From @Result where ErrorType = 2)
		EXEC prcEnableTriggers 'ce000' 
		EXEC prcEnableTriggers 'en000' 
		update @Result
		set Fixed = 1
		Where ErrorType = 2 AND CeGuid not In(select Guid From ce000)

	END

	if (@ErrorType & 8 = 8)
	BEGIN
		--  «Ì’«·«  »Ì⁄ ’—«›… ÌﬂÊ‰ ›ÌÂ« ”⁄— «· ⁄œ· „Œ ·› ⁄‰ «·Ê”ÿÌ
		Declare @currbalance table
		(currency uniqueidentifier, Debit Float, Credit Float, Balance float, currencyval float)
		insert into @currbalance
		select guid,0,0,0,0 from my000
	
		declare	@c_debit float,	@c_credit float, @c_ceGuid uniqueidentifier,
			@c_cenumber int, @c_exGuid uniqueidentifier, @c_exNumber int,
			@c_currency uniqueidentifier, @c_currencyval float, @c_NewAvg float,
			@c_CurBalance float, @c_Date DateTime, @c_Type INT,
			@Balance float, @Avg float, @Debit float, @Credit float

		DECLARE balcursor CURSOR FORWARD_ONLY FOR
		SELECT 
			fn.ceGuid, fn.CeNumber,
			CASE ISNULL(ex.Guid, 0X0) 
				WHEN 0X0 THEN 
					CASE ISNULL(cl.Guid, 0X0) 
						WHEN 0X0 THEN 3
					ELSE 2 END
				ELSE 1 END,
			isNull(ex.Guid, ISNULL(cl.Guid , 0x0)),
			isNull(ex.Number, ISNULL(cl.Number, -1)),
			fn.CurrencyGuid,
			fn.CurrencyVal,
			fn.[date],
			fn.Debit / fn.CurrencyVal,
			fn.Credit / fn.CurrencyVal

		FROM FnTrnExCurrEntries(0x0, 0x0, '', '2100', 0, 0x0) AS fn
		LEFT JOIN TrnCloseCashier000 AS cl ON cl.EntryGuid = fn.ceGuid
		LEFT JOIN TrnExchange000 AS ex ON ex.EntryGuid = fn.ceGuid
		WHERE --((fn.Debit / fn.CurrencyVal) > 1 OR (fn.Credit / fn.CurrencyVal) > 1) AND
		 (fn.Credit <> 0 OR (fn.Debit <> 0 AND fn.AvgEffect <> 0 ))

		ORDER BY fn.[Date], fn.CeNumber, fn.EnNumber
		
		OPEN balcursor 
		FETCH NEXT FROM balcursor INTO 
			@c_ceGuid, @c_cenumber,	@c_Type, @c_exGuid,
			@c_exNumber, @c_currency,@c_currencyval,
			@c_Date, @c_debit, @c_credit

		WHILE @@FETCH_STATUS = 0 
		BEGIN  
			SELECT	@avg = ISNULL(CurrencyVal, 0),
				@Balance = ISNULL(Balance, 0) 
			FROM @currbalance
			WHERE currency = @c_currency

			IF (@c_debit > 0) -- purchase
			BEGIN
				IF (@c_Type = 2)
					IF (@Avg > 0)
					BEGIN
						IF (round(@c_currencyval, 3) <> round(@Avg, 3))
							INSERT INTO @Result
							Values(@c_exGuid, @c_exNumber, @c_ceGuid, @c_cenumber, 517,
							@c_Date,@c_currency, @c_currencyval,@Avg,0, 8) 
					END
				SET @c_NewAvg = (@c_debit * @c_currencyval + @Balance * @Avg)
				SET @c_NewAvg = @c_NewAvg / (@c_debit + @Balance)
				SET @c_CurBalance = @c_debit + @Balance

				UPDATE @currbalance
				SET balance = @c_CurBalance,
					Debit = Debit + @c_debit,
					currencyval =  @c_NewAvg
				WHERE currency = @c_currency
					
			END
			ELSE
			BEGIN
				SELECT @c_CurBalance = isNull(balance, 0) - @c_credit
				FROM @currbalance WHERE  currency = @c_currency
			

			if (@c_exGuid <> 0x0)
			BEGIN
				if (@c_CurBalance >= 0 AND round(@c_currencyval,3) <> round(@Avg,3))
					INSERT INTO @Result
					Values(@c_exGuid, @c_exNumber, @c_ceGuid, @c_cenumber, 507,
						@c_Date,@c_currency, @c_currencyval,@Avg,0, 8) 
			END		

			if (@c_CurBalance < 0)
				set @c_CurBalance = 0

			update @currbalance
			set balance = @c_CurBalance,
			Credit = Credit + @c_credit
			where currency = @c_currency	
		END
	
		FETCH NEXT FROM balcursor INTO 
			@c_ceGuid, @c_cenumber,	@c_Type, @c_exGuid,
			@c_exNumber, @c_currency,@c_currencyval,
			@c_Date, @c_debit, @c_credit
		END
	
		CLOSE balcursor 
		DEALLOCATE balcursor
	END
	
	select * from @result order by ErrorType, [Date]
################################
#END
