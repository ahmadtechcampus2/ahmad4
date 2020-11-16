######################################################################################
CREATE PROCEDURE trnGetCurHistory_ByDate
		@Date		[DATETIME],
		@Lang		[INT]	= 0
AS
	SET NOCOUNT ON 
	
	DECLARE @CurCount [INT],
			@c_cur	CURSOR,
			@CurGUID [UNIQUEIDENTIFIER], 
			@NCurGUID [UNIQUEIDENTIFIER], 
			@GUID [UNIQUEIDENTIFIER],
			@CurDate [DATETIME],
			@CurName [NVARCHAR](255),
			@Flag [INT],
			@InCurVal [FLOAT],
			@OutCurVal [FLOAT]

	CREATE TABLE [#Result]( 
					[GUID] [UNIQUEIDENTIFIER], 
					[CurrencyGUID] [UNIQUEIDENTIFIER], 
					[CurrencyName] [NVARCHAR]( 255) COLLATE ARABIC_CI_AI,
					[InVal] [FLOAT], 
					[OutVal] [FLOAT], 
					[Date] [DATETIME],
					[Flag] [INT],
					[Number] [FLOAT]) 

	SET @CurGUID = 0x0
	INSERT INTO [#Result]
		SELECT 0x0, [myGUID], CASE @Lang WHEN 0 THEN [myName] ELSE CASE  [myLatinName] WHEN '' THEN [myName] ELSE [myLatinName] END END, [myCurrencyVal], [myCurrencyVal], '1/1/1980', 2,[myNumber] 
		FROM [vwMy] 
		SET @c_cur = CURSOR FAST_FORWARD FOR 
				SELECT 
					[GUID], [CurrencyGUID], [InCurrencyVal], [OutCurrencyVal], [Date]
				FROM
					[trnmh000]
				WHERE 
					[Date]<= @Date
				order by [CurrencyGUID], [Date] DESC

		OPEN @c_cur FETCH FROM @c_cur INTO 
				@GUID, @NCurGUID, @InCurVal, @OutCurVal, @CurDate

		WHILE @@FETCH_STATUS = 0 
		BEGIN
				IF( @NCurGUID <> @CurGUID)
				BEGIN
					SET @CurGUID = @NCurGUID 

					if( @Date = @CurDate)
						SET @Flag = 0
					else
						SELECT @Flag = 1, @GUID = 0x0
				UPDATE [#Result]
					SET
						[GUID] = @GUID,
						[InVal] = @InCurVal,
						[OutVal] = @OutCurVal,
						[Date] = @CurDate,
						[Flag] = @Flag
					WHERE
						[CurrencyGUID] = @NCurGUID 
				END
				FETCH FROM @c_cur INTO 
				@GUID, @NCurGUID, @InCurVal, @OutCurVal, @CurDate
		END
		CLOSE @c_cur	DEALLOCATE @c_cur 
	SELECT * FROM [#Result]
#####################################################################################
##
##
CREATE PROCEDURE trnGetCurHistory_ByCur
		@CurGuid	[UNIQUEIDENTIFIER]
AS 
SELECT 
	 [InCurrencyVal] As [InVal], [OutCurrencyVal] As [OutVal], [Date]
FROM [trnmh000]
WHERE 
	[CurrencyGUID] = @CurGuid
ORDER BY [Date]
#########################################################################
#END