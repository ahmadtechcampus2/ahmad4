CREATE  FUNCTION FetchCompositions
( 
	@DrugGuid UNIQUEIDENTIFIER 
							)  
RETURNS @result TABLE  
( 
Composition [nvarchar](1000)  
) 
BEGIN 
INSERT INTO @result 
SELECT composition from drugCompositions000  where matGuid = @DrugGuid or @DrugGuid = 0x0
RETURN 
END 