####################################################
CREATE  PROCEDURE TrnGetExchangeCurDetail
		@TypeGuid 	uniqueidentifier,
		@CurrencyGuid uniqueidentifier = 0x0

AS
	SET NOCOUNT ON 
	
DECLARE @Date	[DATETIME]
SET @Date = GetDate()

DECLARE		@CurrencyAccountGUID uniqueidentifier,
			@CurCount [INT],
			@c_cur	CURSOR,
			@CurGUID [UNIQUEIDENTIFIER], 
			@Guid  [UNIQUEIDENTIFIER], 
			@NCurGUID [UNIQUEIDENTIFIER], 
			@CurDate [DATETIME],
			@InCurVal [FLOAT],
			@OutCurVal [FLOAT]

	CREATE TABLE [#Result](
					--[GUID] [UNIQUEIDENTIFIER], 
					[CurrencyGUID] [UNIQUEIDENTIFIER], 
					[InVal] [FLOAT], 
					[OutVal] [FLOAT], 
					--[AvgVal] [FLOAT],
					--ate] [DATETIME],
					--[Flag] [INT],
					[Number] [FLOAT],
					AccountGuid [uniqueidentifier]
				)

	SET @CurGUID = 0x0
	INSERT INTO [#Result]
		SELECT my.[Guid], 
				[CurrencyVal],
				[CurrencyVal], 
				my.[Number],
				acc.accountguid 
				
		FROM [My000] as my
		INNER JOIN  TrnCurrencyAccount000 as Acc on Acc.CurrencyGuid = my.guid 
		INNER JOIN TrnExchangeTypes000 As t ON t.GroupCurrencyAccGUID = Acc.ParentGuid
		WHERE  t.Guid = @TypeGuid AND (@CurrencyGuid = 0x0 OR Acc.CurrencyGuid = @CurrencyGuid)
		
		ORDER BY my.[NUMBER]
		
		SET @c_cur = CURSOR FAST_FORWARD FOR 
				SELECT 
					t.[GUID], t.[CurrencyGUID], [InCurrencyVal], [OutCurrencyVal]--, [Date]
				FROM
					[trnmh000] as t
				WHERE 
					[Date]<= @Date
				order by t.[CurrencyGUID], [Date] DESC

		OPEN @c_cur FETCH FROM @c_cur INTO 
				@GUID, @NCurGUID, @InCurVal, @OutCurVal


		WHILE @@FETCH_STATUS = 0 
		BEGIN
				IF( @NCurGUID <> @CurGUID)
				BEGIN

					SET @CurGUID = @NCurGUID 
					UPDATE [#Result]
					SET
						[InVal] = @InCurVal,
						[OutVal] = @OutCurVal
						--[AvgVal] = @AvgPayCurrencyVal
		
					WHERE
						[CurrencyGUID] = @NCurGUID 

				END
				FETCH FROM @c_cur INTO 
				 @GUID, @NCurGUID, @InCurVal, @OutCurVal
		END
		CLOSE @c_cur	DEALLOCATE @c_cur 
	SELECT * FROM [#Result]
##########################################################
#END