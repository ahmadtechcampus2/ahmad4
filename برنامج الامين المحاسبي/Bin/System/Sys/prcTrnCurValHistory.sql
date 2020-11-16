######################################################################################
CREATE  PROCEDURE trnGetCurHistory_ByDate
		@Date		[DATETIME],
		@Sort		[int] = 0,
		@Lang		[INT]	= 0
AS
SET NOCOUNT ON 
	
DECLARE @CurCount [INT],
			@c_cur		CURSOR,
			@CurGUID	[UNIQUEIDENTIFIER], 
			@NCurGUID	[UNIQUEIDENTIFIER], 
			@GUID		[UNIQUEIDENTIFIER],
			@CurDate	[DATETIME],
			@CurName	[NVARCHAR](255),
			@Flag		[INT],
			@InCurVal	[FLOAT],
			@OutCurVal	[FLOAT],
			@TrnBuyVal	[FLOAT],
			@TrnSellVal	[FLOAT],
			@bMulConst BIT

	CREATE TABLE [#Result](
				[GUID]					[UNIQUEIDENTIFIER], 
				[CurrencyGUID]			[UNIQUEIDENTIFIER], 
				[CurrencyName]			[NVARCHAR]( 255) COLLATE ARABIC_CI_AI,
				[InVal]					[FLOAT], 
				[OutVal]				[FLOAT], 
				[BuyTransferVal]		[FLOAT],
				[SellTransferVal]		[FLOAT],
				[Date]					[DATETIME],
				[Flag]					[INT],
				[Number]				[INT],
				[bReleatedWithForiegnCur][BIT],
				[bMulConst]				[BIT],
				ConstMulCurrVal			[FLOAT]
				) 

	SET @CurGUID = 0x0
	INSERT INTO [#Result]
		SELECT		0x0, 
					M.[GUID],
					CASE @Lang 
						WHEN 0 THEN [Name]
						ELSE (CASE [LatinName] WHEN '' THEN [Name] ELSE [LatinName] END)
					END,
					[CurrencyVal],
					[CurrencyVal],
					[CurrencyVal], 
					[CurrencyVal],  
					'1/1/1980', 
					2,
					m.[Number],
					CASE WHEN s.Guid IS NULL THEN 0 ELSE 1 END,
					ISNULL(s.bIsMultConst,0),
					ISNULL(CASE bIsMultConst WHEN 0 THEN 1 / s.CurrencyConst ELSE s.CurrencyConst END, 0)
		FROM [My000] as M
		LEFT JOIN TrnCurrencyConstValue000 AS s ON s.CurrencyGuid = m.guid
		ORDER BY [NUMBER]
		
		SET @c_cur = CURSOR FAST_FORWARD FOR 
				SELECT 
					t.[GUID], 
					t.[CurrencyGUID], 
					t.[InCurrencyVal], 
					t.[OutCurrencyVal], 
					t.[BuyTransferVal],
					t.[SellTransferVal],
					t.[Date], 
					ISNULL(s.bIsMultConst, 0)
				FROM
					[MY000] AS M	
					INNER JOIN [trnmh000] as t ON M.GUID = t.Currencyguid
					LEFT JOIN TrnCurrencyConstValue000 AS S on s.CurrencyGuid = t.CurrencyGuid
				WHERE 
					t.[Date]<= @Date
				ORDER BY t.[CurrencyGUID], t.[Date] DESC

		OPEN @c_cur FETCH FROM @c_cur INTO 
		@GUID, @NCurGUID, @InCurVal, @OutCurVal, @TrnBuyVal, @TrnSellVal, @CurDate, @bMulConst


		WHILE @@FETCH_STATUS = 0 
		BEGIN
				IF( @NCurGUID <> @CurGUID)
				BEGIN
					SET @CurGUID = @NCurGUID 
					IF( @Date = @CurDate)
						SET @Flag = 0
					ELSE
						SELECT @Flag = 1, @GUID = 0x0

					UPDATE [#Result]
						SET
							[GUID] = @GUID,
							[InVal] = @InCurVal,
							[OutVal] = @OutCurVal,
							[BuyTransferVal] = CASE @TrnBuyVal WHEN 0 THEN @InCurVal ELSE @TrnBuyVal END,
							[SellTransferVal] = CASE @TrnSellVal WHEN 0 THEN @OutCurVal ELSE @TrnSellVal END,
							[Date] = @CurDate,
							[Flag] = @Flag,
							[bMulConst] = @bMulConst
						WHERE
							[CurrencyGUID] = @NCurGUID 
				END
				FETCH FROM @c_cur INTO 
				@GUID, @NCurGUID, @InCurVal, @OutCurVal, @TrnBuyVal, @TrnSellVal, @CurDate, @bMulConst
		END
		CLOSE @c_cur DEALLOCATE @c_cur 
	IF (@Sort = 0)
		SELECT * FROM [#Result]
	ELSE
		SELECT * FROM [#Result]
		ORDER by Number, CurrencyName
#####################################################################################
CREATE PROCEDURE trnGetCurHistory_ByCur
		@CurGuid	[UNIQUEIDENTIFIER]
AS 
SET NOCOUNT ON 

DECLARE @Result TABLE 
			(	
				[InVal] 			[FLOAT],
				[OutVal] 			[FLOAT],
				[BuyTransferVal]	[FLOAT],
				[SellTransferVal]	[FLOAT],
				[InBaseForeignVal]	[FLOAT],
				[Date]				[DateTime]
			)

	INSERT INTO @Result
	SELECT 
	 	[InCurrencyVal],
	 	[OutCurrencyVal],
		[BuyTransferVal],
		[SellTransferVal],
	 	0, 
	 	[Date]
	FROM [trnmh000]
	WHERE 
		[CurrencyGUID] = @CurGuid
	ORDER BY [Date]

	DECLARE @BasCur 	[UNIQUEIDENTIFIER]

	SELECT @BasCur =  CAST(Value AS [UNIQUEIDENTIFIER])
	FROM op000 WHERE [NAME] LIKE 'TrnCfg_BasicExchangeCurrency'
	
	IF (ISNULL(@BasCur, 0x0) <> 0x0)
	BEGIN
		DECLARE @Date DATETIME
		DECLARE Cur CURSOR FOR 

		SELECT	[Date]
		FROM trnmh000
		WHERE [CurrencyGUID] = @CurGuid

		OPEN Cur
		FETCH FROM Cur INTO @Date
	
			WHILE @@FETCH_STATUS = 0 
			BEGIN
				DECLARE @InBaseVal [FLOAT]
				SELECT 
					@InBaseVal = InVal
				FROM fnTrnGetCurrencyInOutVal(@BasCur, @Date)
					
				UPDATE @Result
				SET [InBaseForeignVal] = @InBaseVal
				WHERE [Date] = @Date
			FETCH FROM Cur INTO @Date
		END
		CLOSE Cur
		DEALLOCATE Cur
	END
	SELECT * FROM @Result ORDER BY [DATE]
#########################################################################
#END