#########################################################
CREATE FUNCTION fnGetGroupParents(@StartGUID [UNIQUEIDENTIFIER])
	RETURNS @Result TABLE([GUID] [UNIQUEIDENTIFIER])
AS BEGIN

/*
This function:
	- returns a list of ascending parents groups starting from a given group number
	- handles the problem of orphants and cross-links.
*/

	DECLARE @ParentGUID [UNIQUEIDENTIFIER]

	SELECT @ParentGUID = [ParentGUID] FROM [gr000] WHERE [GUID] = @StartGUID
	WHILE @@ROWCOUNT <> 0
	BEGIN
		IF EXISTS(SELECT * FROM @Result WHERE [GUID] = @ParentGUID)
			BREAK

		INSERT INTO @Result VALUES(@ParentGUID)
		SELECT @ParentGUID = [ParentGUID] FROM [gr000] WHERE [GUID] = @ParentGUID
	END

	RETURN
END

#########################################################
#END