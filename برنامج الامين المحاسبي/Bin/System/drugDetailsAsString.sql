CREATE FUNCTION drugDetailsAsString(@drugGuid UNIQUEIDENTIFIER,@tableFlag int)
RETURNS NVARCHAR(max)
AS 
BEGIN
	DECLARE @compositions AS NVARCHAR(max)
	DECLARE @c cursor
	DECLARE @searchTable TABLE (MatGuid UNIQUEIDENTIFIER ,string NVARCHAR(max))
	DECLARE @cursorGuid UNIQUEIDENTIFIER
	DECLARE @totalStr NVARCHAR(max)
	DECLARE @tempStr NVARCHAR(max)
		
	SET @totalStr = '';
	 IF @tableFlag = 1
		 BEGIN
		 SET @c = CURSOR FAST_FORWARD FOR  SELECT  MatGuid,composition FROM drugCompositions000 WHERE matguid =  @drugGuid
		  END
	 ELSE 
		 BEGIN
		 SET @c =  CURSOR FAST_FORWARD FOR  SELECT  MatGuid ,indication FROM drugIndications000  WHERE matguid =  @drugGuid
		 END
		 
	OPEN @c 
	FETCH FROM @c INTO @cursorGuid,@tempStr
		WHILE @@fetch_status = 0
		BEGIN
			set @totalStr = @totalStr +' '+ @tempStr
			
			FETCH NEXT FROM @c  INTO @cursorGuid,@tempStr
		END -- cursor
	CLOSE @c
	DEALLOCATE @c
		RETURN @totalStr	
END