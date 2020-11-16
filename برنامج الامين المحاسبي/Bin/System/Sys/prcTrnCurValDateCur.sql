#######################################################################################
CREATE  PROCEDURE trnGetCurVal_ByDateCur
		@Date		[DATETIME], 
		@CurGUID_C	[UNIQUEIDENTIFIER], 
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
					[CurrencyCode] [NVARCHAR]( 255) COLLATE ARABIC_CI_AI, 
					[InVal] [FLOAT],  
					[OutVal] [FLOAT],  
					[Date] [DATETIME], 
					[Flag] [INT], 
					[Number] [FLOAT])  
					
	SET @CurGUID = 0x0 
	INSERT INTO [#Result] 
		SELECT 0x0, [GUID], CASE @Lang WHEN 0 THEN [Name] ELSE CASE  [LatinName] WHEN '' THEN [Name] ELSE [LatinName] END END, [Code],[CurrencyVal],[CurrencyVal], '1/1/1980', 2,[Number]  
		FROM [My000]  
		
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
	WHERE [CurrencyGUID] = @CurGUID_C 
#################################################################################
CREATE PROCEDURE trnGetCurValRange
AS
	
	SELECT 
		my.Number AS Number ,
		ISNULL(CurVal.CurrencyGuid, my.GUID) AS CurrencyGuid, 
		ISNULL(mh.InCurrencyVal, my.currencyVal) AS InVal, 
		ISNULL(mh.OutCurrencyVal, my.currencyVal) AS OutVal, 
		ISNULL(CurVal.MaxCashVal, ISNULL(mh.InCurrencyVal, my.currencyVal)) AS MaxCashVal,
		ISNULL(CurVal.MinPayVal, ISNULL(mh.OutCurrencyVal, my.currencyVal)) AS MinPayVal 
	FROM my000 AS my 
	LEFT JOIN TrnCurrencyValRange000 AS CurVal ON my.GUID = CurVal.CurrencyGuid
	LEFT JOIN trnmh000 AS mh ON my.Guid = mh.CurrencyGuid
		AND mh.DATE = (SELECT MAX(DATE) FROM trnmh000 WHERE CurrencyGuid = mh.CurrencyGuid)
ORDER BY Number
#################################################################################
#END