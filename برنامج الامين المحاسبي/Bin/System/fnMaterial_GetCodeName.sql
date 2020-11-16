CREATE FUNCTION fnMaterial_GetCodeName( @g uniqueidentifier) 
	RETURNS NVARCHAR(max)
as
	BEGIN
		DECLARE @Code AS NVARCHAR(max)
		DECLARE @Name AS NVARCHAR(max)
		DECLARE @LatinName AS NVARCHAR(max)
		DECLARE @Result AS NVARCHAR(max)
		SELECT @Code = [Code], @Name = [Name], @LatinName = [LatinName] FROM mt000 WHERE [GUID] = @g
		IF @LatinName = '' 
			SET @LatinName = @Name
		DECLARE @Lang AS INTEGER
		SET @Lang = dbo.fnConnections_GetLanguage()
		IF @Lang = 0
			SET @Result = @Code + '-' + @Name
		IF @Lang = 1
			SET @Result = @Code + '-' + @LatinName
	IF @Result IS NULL SET @Result = 'Nothing'
	RETURN @Result
	END	
########################################################################
#END