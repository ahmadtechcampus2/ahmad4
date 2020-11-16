############################################
CREATE FUNCTION fnGetRestOrderTables(@TableID UNIQUEIDENTIFIER)

	RETURNS @Result TABLE ( [ParentGuid] UNIQUEIDENTIFIER, [Code] NVARCHAR(250), [Cover] int)
AS
BEGIN
	DECLARE @ParentGuid UNIQUEIDENTIFIER, @Code NVARCHAR(250), @Cover NVARCHAR(250);
	DECLARE c CURSOR FOR SELECT ParentID, Code, Cover FROM RestOrderTable000 WHERE @TableID = 0x0 OR TableId = @TableID

	OPEN c FETCH NEXT FROM c INTO @ParentGuid, @Code, @Cover

	WHILE @@FETCH_STATUS = 0  
	BEGIN  
	   IF EXISTS(SELECT * FROM @Result WHERE ParentGuid = @ParentGuid)
	   BEGIN
			UPDATE r
				SET 
					r.Code = r.Code + ' - ' + @Code,
					r.Cover = r.Cover + @Cover
			FROM @Result r
			WHERE ParentGuid = @ParentGuid
	   END
	   ELSE
	   BEGIN
			INSERT INTO @Result VALUES (@ParentGuid, @Code, @Cover)
	   END
		FETCH NEXT FROM c   
		INTO @ParentGuid, @Code, @Cover
	END   
	CLOSE c;  
	DEALLOCATE c;
	RETURN
END
############################################
#END