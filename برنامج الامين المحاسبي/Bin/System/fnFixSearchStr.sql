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

        IF @char IN ('�', '�', '�', '�')
            SET @result = @result + '[����]'
        ELSE IF @char IN ('�', '�')
			SET @result = @result + '[��]'
		ELSE IF @char IN ('�', '�')
			SET @result = @result + '[��]'
		ELSE
            SET @result = @result + @char
		
        SET @i = @i + 1
    END

    RETURN @result
END
###########################################################################
#END
