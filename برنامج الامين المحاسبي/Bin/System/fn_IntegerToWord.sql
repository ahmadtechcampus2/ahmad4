#########################################################
CREATE FUNCTION fn_IntegerToWord
(	@Number AS INT, 
	@Year AS NVARCHAR(250), 
	@Language AS NVARCHAR(2) 
) 
RETURNS NVARCHAR(255)
AS
BEGIN
	DECLARE @Word NVARCHAR(255)
	IF 	@Language = 'Ar'
	BEGIN
		SET @Word = 
		(
			SELECT Case 
				WHEN @Number = 1  THEN   N'الفترة الضريبية الأولى '		+ @Year
				WHEN @Number = 2  THEN   N'الفترة الضريبية الثانية '		+ @Year
				WHEN @Number = 3  THEN   N'الفترة الضريبية الثالثة '		+ @Year
				WHEN @Number = 4  THEN   N'الفترة الضريبية الرابعة '		+ @Year
				WHEN @Number = 5  THEN   N'الفترة الضريبية الخامسة '		+ @Year
				WHEN @Number = 6  THEN   N'الفترة الضريبية السادسة '		+ @Year
				WHEN @Number = 7  THEN   N'الفترة الضريبية السابعة '		+ @Year
				WHEN @Number = 8  THEN   N'الفترة الضريبية الثامنة '		+ @Year
				WHEN @Number = 9  THEN   N'الفترة الضريبية التاسعة '		+ @Year
				WHEN @Number = 10 THEN   N'الفترة الضريبية العاشرة '		+ @Year
				WHEN @Number = 11 THEN   N'الفترة الضريبية الحادية عشر '	+ @Year
				WHEN @Number = 12 THEN   N'الفترة الضريبية الثانية عشر '	+ @Year
		 END
		)
	END
	ELSE IF @Language = 'En'
	BEGIN
	SET @Word = 
		(
			SELECT Case 
				WHEN @Number = 1  THEN  'First VAT Return Period '		+ @Year 
				WHEN @Number = 2  THEN  'Second VAT Return Period '		+ @Year 
				WHEN @Number = 3  THEN  'Third VAT Return Period '		+ @Year 
				WHEN @Number = 4  THEN  'Forth VAT Return Period '		+ @Year 
				WHEN @Number = 5  THEN  'Fifth VAT Return Period '		+ @Year 
				WHEN @Number = 6  THEN  'Sixth VAT Return Period '		+ @Year 
				WHEN @Number = 7  THEN  'Seventh VAT Return Period '	+ @Year 
				WHEN @Number = 8  THEN  'Eighth VAT Return Period '		+ @Year 
				WHEN @Number = 9  THEN  'Ninth VAT Return Period '		+ @Year 
				WHEN @Number = 10 THEN  'Tenth VAT Return Period '		+ @Year 
				WHEN @Number = 11 THEN  'Eleventh VAT Return Period '	+ @Year 
				WHEN @Number = 12 THEN  'Twelfth VAT Return Period '	+ @Year 
		 END
		)
	END
	SELECT @Word = RTRIM(@Word)
	RETURN (@Word)
END
#########################################################
#end