###########################################################################
CREATE PROCEDURE prcIsMaterialNameDuplicated
	@MaterialId UNIQUEIDENTIFIER, 
	@Name NVARCHAR(500), 
	@Field INT
AS
	SELECT *	FROM mt000 
				WHERE Name = CASE WHEN @Field = 2 AND @Name <> '' THEN @Name ELSE Name END
				AND LatinName = CASE WHEN @Field = 4 AND @Name <> '' THEN @Name ELSE LatinName END
				AND GUID <> @MaterialId
				AND (Parent <> @MaterialId OR @MaterialId = 0x00)
				ORDER BY HasSegments DESC
###########################################################################
#END