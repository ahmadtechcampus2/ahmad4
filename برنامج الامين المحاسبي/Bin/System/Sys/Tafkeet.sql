################################################################################
CREATE FUNCTION Tafkeet
(
	@Input            NUMERIC(32, 3),	-- Input number with as many as 18 digits
	@Currency         NVARCHAR(250) = N'جنيه', 
	@CurrencyPart     NVARCHAR(250) = N'قرش',
	@CurrencyPartPrecision NVARCHAR(250) = '' 
)
RETURNS NVARCHAR(1000)
AS
BEGIN
/************************************************************
 * Tafkeet function
 * used to convert numbers to words in arabic or foreign languages .
 * Created By Abdulkareem Attiya.
 * Time: 14/12/2013 02:53:54 م
 ************************************************************/
--SELECT dbo.[Tafkeet] (123456789.126,'جنيه','قرش',1000)
	SET @Input = ROUND(@Input, LEN(@CurrencyPartPrecision)-1)
	IF ((SELECT dbo.fnConnections_GetLanguage()) = 0)
	BEGIN
	    IF @Input <= 0
	        RETURN N'zero'
	    
	    DECLARE @TheNoAfterReplicate NVARCHAR(15) 
	    SET @TheNoAfterReplicate = RIGHT(
	            REPLICATE('0', 15) + CAST(FLOOR(@Input) AS NVARCHAR(15)),
	            15
	        )
	    
	    DECLARE @ComWithWord          NVARCHAR(1000),
	            @TheNoWithDecimal     AS NVARCHAR(400),
	            @ThreeWords           AS INT
	    
	    SET @ThreeWords = 0 
	    SET @ComWithWord = N' فقط ' 
	    DECLARE @Tafket TABLE (num INT, NoName NVARCHAR(100)) 
	    INSERT INTO @Tafket
	    VALUES
	      (
	        0,
	        ''
	      )  
	    INSERT INTO @Tafket
	    VALUES
	      (
	        1,
	        N'واحد'
	      ) 
	    INSERT INTO @Tafket
	    VALUES
	      (
	        2,
	        N'اثنان'
	      ) 
	    INSERT INTO @Tafket
	    VALUES
	      (
	        3,
	        N'ثلاثة'
	      ) 
	    INSERT INTO @Tafket
	    VALUES
	      (
	        4,
	        N'اربعة'
	      ) 
	    INSERT INTO @Tafket
	    VALUES
	      (
	        5,
	        N'خمسة'
	      ) 
	    INSERT INTO @Tafket
	    VALUES
	      (
	        6,
	        N'ستة'
	      ) 
	    INSERT INTO @Tafket
	    VALUES
	      (
	        7,
	        N'سبعة'
	      ) 
	    INSERT INTO @Tafket
	    VALUES
	      (
	        8,
	        N'ثمانية'
	      ) 
	    INSERT INTO @Tafket
	    VALUES
	      (
	        9,
	        N'تسعة'
	      ) 
	    INSERT INTO @Tafket
	    VALUES
	      (
	        10,
	        N'عشرة'
	      ) 
	    INSERT INTO @Tafket
	    VALUES
	      (
	        11,
	        N'احدى عشر'
	      ) 
	    INSERT INTO @Tafket
	    VALUES
	      (
	        12,
	        N'اثنى عشر'
	      ) 
	    INSERT INTO @Tafket
	    VALUES
	      (
	        13,
	        N'ثلاثة عشر'
	      ) 
	    INSERT INTO @Tafket
	    VALUES
	      (
	        14,
	        N'اربعة عشر'
	      ) 
	    INSERT INTO @Tafket
	    VALUES
	      (
	        15,
	        N'خمسة عشر'
	      ) 
	    INSERT INTO @Tafket
	    VALUES
	      (
	        16,
	        N'ستة عشر'
	      ) 
	    INSERT INTO @Tafket
	    VALUES
	      (
	        17,
	        N'سبعة عشر'
	      ) 
	    INSERT INTO @Tafket
	    VALUES
	      (
	        18,
	        N'ثمانية عشر'
	      ) 
	    INSERT INTO @Tafket
	    VALUES
	      (
	        19,
	        N'تسعة عشر'
	      ) 
	    INSERT INTO @Tafket
	    VALUES
	      (
	        20,
	        N'عشرون'
	      ) 
	    INSERT INTO @Tafket
	    VALUES
	      (
	        30,
	        N'ثلاثون'
	      ) 
	    INSERT INTO @Tafket
	    VALUES
	      (
	        40,
	        N'اربعون'
	      ) 
	    INSERT INTO @Tafket
	    VALUES
	      (
	        50,
	        N'خمسون'
	      ) 
	    INSERT INTO @Tafket
	    VALUES
	      (
	        60,
	        N'ستون'
	      ) 
	    INSERT INTO @Tafket
	    VALUES
	      (
	        70,
	        N'سبعون'
	      ) 
	    INSERT INTO @Tafket
	    VALUES
	      (
	        80,
	        N'ثمانون'
	      ) 
	    INSERT INTO @Tafket
	    VALUES
	      (
	        90,
	        N'تسعون'
	      ) 
	    INSERT INTO @Tafket
	    VALUES
	      (
	        100,
	        N'مائة'
	      ) 
	    INSERT INTO @Tafket
	    VALUES
	      (
	        200,
	        N'مائتان'
	      ) 
	    INSERT INTO @Tafket
	    VALUES
	      (
	        300,
	        N'ثلاثمائة'
	      ) 
	    INSERT INTO @Tafket
	    VALUES
	      (
	        400,
	        N'أربعمائة'
	      ) 
	    INSERT INTO @Tafket
	    VALUES
	      (
	        500,
	        N'خمسمائة'
	      ) 
	    INSERT INTO @Tafket
	    VALUES
	      (
	        600,
	        N'ستمائة'
	      ) 
	    INSERT INTO @Tafket
	    VALUES
	      (
	        700,
	        N'سبعمائة'
	      ) 
	    INSERT INTO @Tafket
	    VALUES
	      (
	        800,
	        N'ثمانمائة'
	      ) 
	    INSERT INTO @Tafket
	    VALUES
	      (
	        900,
	        N'تسعمائة'
	      ) 
	    INSERT INTO @Tafket
	    SELECT FirstN.num + LasteN.num,
	           LasteN.NoName + N' و ' + FirstN.NoName
	    FROM   (
	               SELECT *
	               FROM   @Tafket
	               WHERE  num >= 20
	                      AND num <= 90
	           ) FirstN
	           CROSS JOIN (
	                    SELECT *
	                    FROM   @Tafket
	                    WHERE  num >= 1
	                           AND num <= 9
	                ) LasteN
	    
	    INSERT INTO @Tafket
	    SELECT FirstN.num + LasteN.num,
	           FirstN.NoName + N' و ' + LasteN.NoName
	    FROM   (
	               SELECT *
	               FROM   @Tafket
	               WHERE  num >= 100
	                      AND num <= 900
	           ) FirstN
	           CROSS JOIN (
	                    SELECT *
	                    FROM   @Tafket
	                    WHERE  num >= 1
	                           AND num <= 99
	                ) LasteN
	    
	    
	    IF LEFT(@TheNoAfterReplicate, 3) > 0
	        SET @ComWithWord = @ComWithWord + ISNULL(
	                (
	                    SELECT NoName
	                    FROM   @Tafket
	                    WHERE  num = LEFT(@TheNoAfterReplicate, 3)
	                ),
	                N''
	            ) + N' ترليون'
	    
	    IF LEFT(RIGHT(@TheNoAfterReplicate, 12), 3) > 0
	       AND LEFT(@TheNoAfterReplicate, 3) > 0
	        SET @ComWithWord = @ComWithWord + N' و '
	    
	    IF LEFT(RIGHT(@TheNoAfterReplicate, 12), 3) > 0
	        SET @ComWithWord = @ComWithWord + ISNULL(
	                (
	                    SELECT NoName
	                    FROM   @Tafket
	                    WHERE  num = LEFT(RIGHT(@TheNoAfterReplicate, 12), 3)
	                ),
	                N''
	            ) + N' بليون'
	    
	    IF LEFT(RIGHT(@TheNoAfterReplicate, 9), 3) > 0
	    BEGIN
	        SET @ComWithWord = @ComWithWord + CASE 
	                                               WHEN @Input > 999000000 THEN 
	                                                    N' و'
	                                               ELSE N''
	                                          END
	        
	        SET @ThreeWords = LEFT(RIGHT(@TheNoAfterReplicate, 9), 3)
	        SET @ComWithWord = @ComWithWord + ISNULL(
	                (
	                    SELECT CASE 
	                                WHEN @ThreeWords > 2 THEN NoName
	                           END
	                    FROM   @Tafket
	                    WHERE  num = LEFT(RIGHT(@TheNoAfterReplicate, 9), 3)
	                ),
	                N''
	            ) + CASE 
	                     WHEN @ThreeWords = 2 THEN N' مليونان'
	                     WHEN @ThreeWords BETWEEN 3 AND 10 THEN N' ملايين'
	                     ELSE N' مليون'
	                END
	    END
	    
	    IF LEFT(RIGHT(@TheNoAfterReplicate, 6), 3) > 0
	    BEGIN
	        SET @ComWithWord = @ComWithWord + CASE 
	                                               WHEN @Input > 999000 THEN 
	                                                    N' و'
	                                               ELSE N''
	                                          END
	        
	        SET @ThreeWords = LEFT(RIGHT(@TheNoAfterReplicate, 6), 3)
	        SET @ComWithWord = @ComWithWord + ISNULL(
	                (
	                    SELECT CASE 
	                                WHEN @ThreeWords > 2 THEN NoName
	                           END
	                    FROM   @Tafket
	                    WHERE  num = LEFT(RIGHT(@TheNoAfterReplicate, 6), 3)
	                ),
	                N''
	            ) + CASE 
	                     WHEN @ThreeWords = 2 THEN N' الفان'
	                     WHEN @ThreeWords BETWEEN 3 AND 10 THEN N' الاف'
	                     ELSE N' الف'
	                END
	    END
	    
	    IF RIGHT(@TheNoAfterReplicate, 3) > 0
	    BEGIN
	        IF @Input > 999
	        BEGIN
	            SET @ComWithWord = @ComWithWord + N' و'
	        END
	        
	        IF RIGHT(@TheNoAfterReplicate, 2) = N'01'
	           OR RIGHT(@TheNoAfterReplicate, 2) = N'02'
	        BEGIN
	            --set @ComWithWord=@ComWithWord + case  when @Input>1000  then N' و'  else N'' end
	            --set @ThreeWords=left(right(@TheNoAfterReplicate,6),3)
	            SET @ComWithWord = @ComWithWord + N' ' + ISNULL(
	                    (
	                        SELECT noname
	                        FROM   @Tafket
	                        WHERE  num = RIGHT(@TheNoAfterReplicate, 3)
	                    ),
	                    N''
	                )
	        END
	        
	        SET @ThreeWords = RIGHT(@TheNoAfterReplicate, 2)
	        
	        IF @ThreeWords = 0
	        BEGIN
	            --   set @ComWithWord=@ComWithWord + N' و' 
	            SET @ComWithWord = @ComWithWord + ISNULL(
	                    (
	                        SELECT NoName
	                        FROM   @Tafket
	                        WHERE  @ThreeWords = 0
	                               AND num = RIGHT(@TheNoAfterReplicate, 3)
	                    ),
	                    N''
	                )
	        END
	    END
	    
	    SET @ThreeWords = RIGHT(@TheNoAfterReplicate, 2) 
	    SET @ComWithWord = @ComWithWord + ISNULL(
	            (
	                SELECT NoName
	                FROM   @Tafket
	                WHERE  @ThreeWords > 2
	                       AND num = RIGHT(@TheNoAfterReplicate, 3)
	            ),
	            N''
	        )
	    
	    SET @ComWithWord = @ComWithWord + N' ' + @Currency
	    
	    IF RIGHT(RTRIM(@ComWithWord), 1) = N','
	        SET @ComWithWord = SUBSTRING(@ComWithWord, 1, LEN(@ComWithWord) -1)
	    
	    IF RIGHT(@Input, LEN(@Input) -CHARINDEX(N'.', @Input)) > 0
	       AND CHARINDEX(N'.', @Input) <> 0
	    BEGIN 
	        SET @ThreeWords = LEFT(PARSENAME(@Input,1), LEN(@CurrencyPartPrecision)-1)  
	        SELECT @TheNoWithDecimal = N' و ' + ISNULL( 
	                   ( 
	                       SELECT NoName 
	                       FROM   @Tafket 
	                       WHERE  num = @ThreeWords 
	                              AND @ThreeWords > 3 
	                   ), 
	                   N'' 
	               ) 
	        SET @ComWithWord = @ComWithWord + CONVERT(NVARCHAR(MAX), @TheNoWithDecimal) + N' ' + @CurrencyPart 
	    END 
	    
	    SET @ComWithWord = @ComWithWord + N' لا غير  '
	    
	    RETURN RTRIM(@ComWithWord)
	END
	ELSE
	BEGIN
	    DECLARE @Number NUMERIC(32)
	    SET @Number = FLOOR(@Input)
	    DECLARE @Cents AS INT
	    DECLARE @PartPrecision AS INT 
	    SET @PartPrecision = LEN(@CurrencyPartPrecision) 
	    --Select cast(@Input as money) 
	    SET @Cents =(LEFT(PARSENAME(@Input,1), LEN(@CurrencyPartPrecision)-1))
	    DECLARE @inputNumber NVARCHAR(38)
	    DECLARE @NumbersTable TABLE (number NCHAR(2), word NVARCHAR(10))
	    DECLARE @outputString NVARCHAR(max)
	    DECLARE @length INT
	    DECLARE @counter INT
	    DECLARE @loops INT
	    DECLARE @position INT
	    DECLARE @chunk NCHAR(3) -- for chunks of 3 numbers
	    DECLARE @tensones NCHAR(2)
	    DECLARE @hundreds NCHAR(1)
	    DECLARE @tens NCHAR(1)
	    DECLARE @ones NCHAR(1)
	    
	    IF @Number = 0
	        RETURN N'Zero'
	    
	    -- initialize the variables
	    SELECT @inputNumber = CONVERT(NVARCHAR(38), @Number),
	           @outputString     = N'',
	           @counter          = 1
	    
	    SELECT @length = LEN(@inputNumber),
	           @position     = LEN(@inputNumber) - 2,
	           @loops        = LEN(@inputNumber) / 3
	    
	    -- make sure there is an extra loop added for the remaining numbers
	    IF LEN(@inputNumber) % 3 <> 0
	        SET @loops = @loops + 1
	    
	    -- insert data for the numbers and words
	    INSERT INTO @NumbersTable
	    SELECT N'00',
	           N''
	    UNION ALL
	    SELECT N'01',
	           N'one' UNION ALL
	    SELECT N'02',
	           N'two'
	    UNION ALL
	    SELECT N'03',
	           N'three' UNION ALL
	    SELECT N'04',
	           N'four'
	    UNION ALL
	    SELECT N'05',
	           N'five' UNION ALL
	    SELECT N'06',
	           N'six'
	    UNION ALL
	    SELECT N'07',
	           N'seven' UNION ALL
	    SELECT N'08',
	           N'eight'
	    UNION ALL
	    SELECT N'09',
	           N'nine' UNION ALL
	    SELECT N'10',
	           N'ten'
	    UNION ALL
	    SELECT N'11',
	           N'eleven' UNION ALL
	    SELECT N'12',
	           N'twelve'
	    UNION ALL
	    SELECT N'13',
	           N'thirteen' UNION ALL
	    SELECT N'14',
	           N'fourteen'
	    UNION ALL
	    SELECT N'15',
	           N'fifteen' UNION ALL
	    SELECT N'16',
	           N'sixteen'
	    UNION ALL
	    SELECT N'17',
	           N'seventeen' UNION ALL
	    SELECT N'18',
	           N'eighteen'
	    UNION ALL
	    SELECT N'19',
	           N'nineteen' UNION ALL
	    SELECT N'20',
	           N'twenty'
	    UNION ALL
	    SELECT N'30',
	           N'thirty' UNION ALL
	    SELECT N'40',
	           N'forty'
	    UNION ALL
	    SELECT N'50',
	           N'fifty' UNION ALL
	    SELECT N'60',
	           N'sixty'
	    UNION ALL
	    SELECT N'70',
	           N'seventy' UNION ALL
	    SELECT N'80',
	           N'eighty'
	    UNION ALL
	    SELECT N'90',
	           N'ninety'   
	    
	    WHILE @counter <= @loops
	    BEGIN
	        -- get chunks of 3 numbers at a time, padded with leading zeros
	        SET @chunk = RIGHT(N'000' + SUBSTRING(@inputNumber, @position, 3), 3)
	        
	        IF @chunk <> N'000'
	        BEGIN
	            SELECT @tensones = SUBSTRING(@chunk, 2, 2),
	                   @hundreds     = SUBSTRING(@chunk, 1, 1),
	                   @tens         = SUBSTRING(@chunk, 2, 1),
	                   @ones         = SUBSTRING(@chunk, 3, 1)
	            
	            -- If twenty or less, use the word directly from @NumbersTable
	            IF CONVERT(INT, @tensones) <= 20
	               OR @Ones = N'0'
	            BEGIN
	                SET @outputString = (
	                        SELECT word
	                        FROM   @NumbersTable
	                        WHERE  @tensones = number
	                    )
	                    + CASE @counter
	                           WHEN 1 THEN N'' -- No name
	                           WHEN 2 THEN N' thousand '
	                           WHEN 3 THEN N' million '
	                           WHEN 4 THEN N' billion '
	                           WHEN 5 THEN N' trillion '
	                           WHEN 6 THEN N' quadrillion '
	                           WHEN 7 THEN N' quintillion '
	                           WHEN 8 THEN N' sextillion '
	                           WHEN 9 THEN N' septillion '
	                           WHEN 10 THEN N' octillion '
	                           WHEN 11 THEN N' nonillion '
	                           WHEN 12 THEN N' decillion '
	                           WHEN 13 THEN N' undecillion '
	                           ELSE N''
	                      END
	                    + @outputString
	            END
	            ELSE
	            BEGIN
	                -- break down the ones and the tens separately
	                
	                SET @outputString = N' ' 
	                    + (
	                        SELECT word
	                        FROM   @NumbersTable
	                        WHERE  @tens + N'0' = number
	                    )
	                    + N'-'
	                    + (
	                        SELECT word
	                        FROM   @NumbersTable
	                        WHERE  N'0' + @ones = number
	                    )
	                    + CASE @counter
	                           WHEN 1 THEN N'' -- No name
	                           WHEN 2 THEN N' thousand '
	                           WHEN 3 THEN N' million '
	                           WHEN 4 THEN N' billion '
	                           WHEN 5 THEN N' trillion '
	                           WHEN 6 THEN N' quadrillion '
	                           WHEN 7 THEN N' quintillion '
	                           WHEN 8 THEN N' sextillion '
	                           WHEN 9 THEN N' septillion '
	                           WHEN 10 THEN N' octillion '
	                           WHEN 11 THEN N' nonillion '
	                           WHEN 12 THEN N' decillion '
	                           WHEN 13 THEN N' undecillion '
	                           ELSE N''
	                      END
	                    + @outputString
	            END
	            
	            -- now get the hundreds
	            IF @hundreds <> N'0'
	            BEGIN
	                SET @outputString = (
	                        SELECT word
	                        FROM   @NumbersTable
	                        WHERE  N'0' + @hundreds = number
	                    )
	                    + N' hundred ' 
	                    + @outputString
	            END
	        END
	        
	        SELECT @counter = @counter + 1,
	               @position = @position - 3
	    END
	    
	    -- Remove any double spaces
	    SET @outputString = LTRIM(RTRIM(REPLACE(@outputString, N'  ', N' ')))
	    SET @outputstring = UPPER(LEFT(@outputstring, 1)) + SUBSTRING(@outputstring, 2, 8000)
	    
	    DECLARE @VCents NVARCHAR(2)
	    SET @VCents = CONVERT(NVARCHAR(20), @Cents)
	    IF LEN(@VCents) = 1
	    BEGIN
	        SET @VCents = N'0' + @Vcents
	    END
	    
	    RETURN UPPER(@outputString) + N' ' + @Currency + 
	    CASE 
	         WHEN @Cents > 0 THEN N' AND ' + CAST(
	                  dbo.Tafkeet(@Cents, @CurrencyPart, N'', 0) AS NVARCHAR(250)
	              )
	         ELSE N' ONLY'
	    END --+ '/100 CENTS'-- return the result
	    
	END
	
	RETURN N''
END 
################################################################################
#END