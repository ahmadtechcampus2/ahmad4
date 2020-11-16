##################################################################
###
###
CREATE PROCEDURE repGetCurHistory_ByDate
		@Date		DATETIME
AS
DECLARE @CurCount INT,
		@c_cur	CURSOR,
		@CurGUID UNIQUEIDENTIFIER, 
		@NCurGUID UNIQUEIDENTIFIER, 
		@CurDate DATETIME,
		@CurName NVARCHAR(255),
		@Flag INT,
		@CurVal FLOAT

CREATE TABLE #Result( 
				CurrencyGUID UNIQUEIDENTIFIER, 
				CurrencyName NVARCHAR( 255),
				CurrencySecurity INT, 
				Val FLOAT, 
				Flag INT) 
CREATE TABLE #SecViol( Type INT, Cnt INT)

SET @CurGUID = 0x0
INSERT INTO #Result
	SELECT myGUID, myName, mySecurity, myCurrencyVal, 2 
	FROM vwMy --AS my INNER JOIN vwMh AS mh ON my.myGUID = mh.mhCurrencyGUID

	SET @c_cur = CURSOR FAST_FORWARD FOR 
			SELECT 
				CurrencyGUID, CurrencyVal, [Date]
			FROM
				mh000
			WHERE 
				[Date]<= @Date

	OPEN @c_cur FETCH FROM @c_cur INTO 
			@NCurGUID, @CurVal, @CurDate
	WHILE @@FETCH_STATUS = 0 
	BEGIN
			IF( @NCurGUID <> @CurGUID)
			BEGIN
				SET @CurGUID = @NCurGUID 
				if( @Date = @CurDate)
					SET @Flag = 0
				else
					SET @Flag = 1
				UPDATE #Result
				SET
					Val = @CurVal,
					Flag = @Flag
				WHERE
					CurrencyGUID = @NCurGUID 
			END
			FETCH FROM @c_cur INTO 
			@NCurGUID, @CurVal, @Date
	END
	CLOSE @c_cur	DEALLOCATE @c_cur 
	EXEC prcCheckSecurity 
SELECT * FROM #Result
SELECT * FROM #SecViol
#########################################################################
##
##
CREATE PROCEDURE repGetCurHistory_ByCur
		@CurGuid	UNIQUEIDENTIFIER
AS 
SELECT 
	 CurrencyVal, Date
FROM mh000
WHERE 
	CurrencyGUID = @CurGuid
#########################################################################
#END