###########################################################################
CREATE FUNCTION fn_IsMaterialNameDuplicated(@MaterialId UNIQUEIDENTIFIER, @Name NVARCHAR(250), @Field INT)
RETURNS INT
AS
BEGIN

	DECLARE @result INT = 0;

	IF EXISTS ( SELECT * FROM mt000 
				WHERE Name = CASE WHEN @Field = 2 AND @Name <> '' THEN @Name ELSE Name END
				AND LatinName = CASE WHEN @Field = 4 AND @Name <> '' THEN @Name ELSE LatinName END
				AND GUID <> @MaterialId
				AND (Parent <> @MaterialId OR @MaterialId = 0x00)
				)	
	BEGIN
		SET @result = 1;
	END

return @result
END


###########################################################################
#END