###########################################################################
CREATE FUNCTION fnFixSearchStr(@str NVARCHAR(500))
    RETURNS NVARCHAR(256)
AS
BEGIN
    DECLARE @result NVARCHAR(500) = ''
    DECLARE @i INT = 1
    DECLARE @len INT = LEN(@str)

    WHILE @i <= @len
    BEGIN
        DECLARE @char NVARCHAR(1) = SUBSTRING(@str, @i, 1)

        IF @char IN ('Ç', 'Ã', 'Å', 'Â')
            SET @result = @result + '[ÇÃÅÂ]'
        ELSE IF @char IN ('í', 'ì')
			SET @result = @result + '[íì]'
		ELSE IF @char IN ('å', 'É')
			SET @result = @result + '[åÉ]'
		ELSE
            SET @result = @result + @char
		
        SET @i = @i + 1
    END

    RETURN @result
END
###########################################################################
#END
