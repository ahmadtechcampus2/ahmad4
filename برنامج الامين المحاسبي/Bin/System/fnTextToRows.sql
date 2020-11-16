###########################################################################
CREATE FUNCTION fnTextToRows (@Source [NVARCHAR](4000))
	RETURNS @Result TABLE(Data [SQL_VARIANT]) 
AS BEGIN 
/*
This function:
	- returns converts a coma delemited string to rows
*/

	DECLARE 
		@ComaPos [INT],
		@StartShift [INT],
		@LenSource [INT]

	SELECT
		@LenSource = LEN(@Source),
		@StartShift = 1
	IF RIGHT(@Source, 1) <> ','
		SET @Source = @Source + ','
	WHILE @StartShift <= @LenSource
	BEGIN
		SET @ComaPos = CHARINDEX(',', @Source, @StartShift)
		INSERT INTO @Result VALUES (LTRIM(RTRIM(SUBSTRING(@Source, @StartShift, @ComaPos - @StartShift))))
		SET @StartShift = @ComaPos + 1
	END
	RETURN
END

###########################################################################
#END