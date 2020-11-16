#########################################################
CREATE PROC prcStrings_add
	@code [NVARCHAR](128),
	@arabic [NVARCHAR](256) = '',
	@english [NVARCHAR](256) = '',
	@french [NVARCHAR](256) = '',
	@update [BIT] = 0
AS
/*
This procedure:
	- inserted a string into strings table.
	- if code already exists, the proc may return, or update, according to the @update parameter
*/
	IF EXISTS(SELECT * FROM [strings] WHERE [code] = @code)
	BEGIN
		-- check to see if caller requested updating, or else exit:
		IF @update = 0
			RETURN	
		-- update current string: this will be done by deleting current, and inserting new:
		DELETE [strings] WHERE [code] = @code
	END
	
	-- insert the new string:
	INSERT INTO [strings] ([code], [arabic], [english], [french]) VALUES (@code, @arabic, @english, @french)

#########################################################
#END