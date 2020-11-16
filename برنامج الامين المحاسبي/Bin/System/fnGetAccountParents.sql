#########################################################
CREATE FUNCTION fnGetAccountParents(@StartGUID [UNIQUEIDENTIFIER])
	RETURNS @Result TABLE([GUID] [UNIQUEIDENTIFIER])
AS BEGIN

/*
This function:
	- returns a list of ascending parents accounts starting from a given account number.
	- handles the problem of orphants and cross-links.
*/

	DECLARE @ParentGUID [UNIQUEIDENTIFIER]

	SELECT @ParentGUID = [ParentGUID] FROM [ac000] WHERE [GUID] = @StartGUID
	WHILE @@ROWCOUNT <> 0
	BEGIN
		IF EXISTS(SELECT * FROM @Result WHERE [GUID] = @ParentGUID)
			BREAK

		INSERT INTO @Result VALUES(@ParentGUID)
		SELECT @ParentGUID = [ParentGUID] FROM [ac000] WHERE [GUID] = @ParentGUID
	END

	RETURN
END

#########################################################
#END