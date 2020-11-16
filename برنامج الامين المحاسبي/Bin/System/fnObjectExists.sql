###########################################################################
CREATE FUNCTION fnObjectExists(@ObjectName [NVARCHAR](128))
	RETURNS [INT]
AS BEGIN
/*
This function:
	- searches in sysobjects for a given object in current db, including visible temporary tables.
	- @ObjectName examples:
		- trg_ac000_general
		- ac000
		- mt000.GUID
		- #Result
		- #Result.CostSecurity
	- returns 1 if founded, 0 if not.
*/
	DECLARE @i [INT]

	-- remove Full-Brackets if any:
	SET @ObjectName = REPLACE(REPLACE(@ObjectName, ']', ''), '[', '')
	SET @i = CHARINDEX('.', @ObjectName)

	IF @ObjectName LIKE '#%'
		IF @i = 0
			IF EXISTS(SELECT * FROM [tempdb]..[sysobjects] WHERE [id] = OBJECT_ID('tempdb..' + @ObjectName))
				RETURN 1
			ELSE
				RETURN 0
		ELSE
			IF EXISTS(SELECT * FROM [tempdb]..[syscolumns] WHERE [id] = OBJECT_ID('tempdb..' + LEFT(@ObjectName, @i - 1)) AND [name] = SUBSTRING(@ObjectName, @i + 1, 128))
				RETURN 1
			ELSE
				RETURN 0
	ELSE
		IF @i = 0
			IF EXISTS(SELECT * FROM [sysobjects] WHERE [ID] = OBJECT_ID (@ObjectName))
				RETURN 1
			ELSE
				RETURN 0
		ELSE
			IF EXISTS(SELECT * FROM [syscolumns] WHERE [id] = OBJECT_ID(LEFT(@ObjectName, @i - 1)) AND [name] = SUBSTRING(@ObjectName, @i + 1, 128))
				RETURN 1
			ELSE
				RETURN 0
	RETURN -1
END
###########################################################################
CREATE FUNCTION fnTblExists(@ObjectName [NVARCHAR](128))
	RETURNS [INT]
AS BEGIN
	SET @ObjectName = REPLACE(REPLACE(@ObjectName, ']', ''), '[', '')
	IF @ObjectName LIKE '#%'
		IF EXISTS(SELECT * FROM [tempdb]..[sysobjects] WHERE [id] = OBJECT_ID('tempdb..' + @ObjectName) AND [xType] = 'U') 
			RETURN 1
		ELSE
			RETURN 0
	ELSE
			IF EXISTS(SELECT * FROM [sysobjects] WHERE [ID] = OBJECT_ID (@ObjectName) AND [xType] = 'U')
				RETURN 1
			ELSE
				RETURN 0
		
	RETURN -1
END
###########################################################################
#END