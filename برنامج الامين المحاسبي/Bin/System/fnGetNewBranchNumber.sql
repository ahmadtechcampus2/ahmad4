#########################################################
CREATE FUNCTION fnGetNewBranchNumber()
RETURNS [INT] 
BEGIN
	IF (NOT EXISTS (SELECT 1 FROM [Br000]))
		RETURN 1;
	DECLARE 
		@C  	CURSOR,
		@No 	[FLOAT],	
		@Prev 	[INT]

		SET @C = CURSOR FAST_FORWARD FOR 
			SELECT ISNULL([Number], 0) FROM [Br000]
		OPEN @C 
		FETCH  FROM @C  INTO @No
		SET @Prev = @No
		WHILE @@FETCH_STATUS = 0 
		BEGIN
			FETCH FROM @c INTO @No
			IF @No <> 0 
				IF ( (@No - @Prev) > 1 )
				BEGIN
					Break
				END
			SET @Prev = @No					
			
		END
		CLOSE @C
		DEALLOCATE @C
	RETURN @Prev + 1 
END
#########################################################
#END  