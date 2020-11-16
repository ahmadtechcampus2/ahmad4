##################################################################
###
###
CREATE PROCEDURE repGetCurHistory_ByDate
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
			@CurVal [FLOAT]

	CREATE TABLE [#Result]( 
					[GUID] [UNIQUEIDENTIFIER], 
					[CurrencyGUID] [UNIQUEIDENTIFIER], 
					[CurrencyName] [NVARCHAR]( 255) COLLATE ARABIC_CI_AI,
					[Val] [FLOAT], 
					[Date] [DATETIME],
					[Flag] [INT],
					[Number] [FLOAT]) 

	SET @CurGUID = 0x0
	INSERT INTO [#Result]
		SELECT 0x0, [myGUID], CASE @Lang WHEN 0 THEN [myName] ELSE CASE  [myLatinName] WHEN '' THEN [myName] ELSE [myLatinName] END END, [myCurrencyVal], '1/1/1980', 2,[myNumber] 
		FROM [vwMy] 
		SET @c_cur = CURSOR FAST_FORWARD FOR 
				SELECT 
					[GUID], [CurrencyGUID], [CurrencyVal], [Date]
				FROM
					[mh000]
				WHERE 
					[Date]<= @Date
				order by [CurrencyGUID], [Date] DESC

		OPEN @c_cur FETCH FROM @c_cur INTO 
				@GUID, @NCurGUID, @CurVal, @CurDate
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
						[Val] = @CurVal,
						[Date] = @CurDate,
						[Flag] = @Flag
					WHERE
						[CurrencyGUID] = @NCurGUID 
				END
				FETCH FROM @c_cur INTO 
				@GUID, @NCurGUID, @CurVal, @CurDate
		END
		CLOSE @c_cur	DEALLOCATE @c_cur 
	SELECT * FROM [#Result] ORDER BY [Number]
#########################################################################
CREATE PROCEDURE repGetCurHistory_ByCur
	@CurGuid [UNIQUEIDENTIFIER]
AS 
	SELECT 
		[myCurrencyVal]  As [Val],
		[myDate] as [Date]
	FROM 
		[vwMy] 
	WHERE 
		MyGuid = @CurGuid
	UNION ALL 
	SELECT 
		[mhCurrencyVal] AS [Val],
		[mhDate] AS [Date]
	FROM 
		[vwMy] [my]
		INNER JOIN [vwMh] [mh] ON [my].[MyGuid] = [mh].[mhCurrencyGUID]
	WHERE 
		[my].[MyGuid] = @CurGuid
		AND 
		[my].[myCurrencyVal] <> 1
	ORDER BY 
		[Date]
#########################################################################
CREATE PROCEDURE prcShowCurrencyByHistory
	@CurGuid [UNIQUEIDENTIFIER]
AS 
	SELECT vwMh.[mhCurrencyVal] AS [Val] , vwMh.mhDate AS [Date] 
	FROM vwMh
	WHERE vwMh.mhCurrencyGUID = @CurGuid
	ORDER BY [Date]
#########################################################################
#END