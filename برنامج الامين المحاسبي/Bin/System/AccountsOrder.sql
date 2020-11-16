###############################################################################
CREATE PROC prcAccountsOrder_Sort
	@Column	[INT], -- 0 for Code, 1 for Name 
	@Parent	[INT] = 0, 
	@Index	[INT] = 0,
	@Level	[INT] = 0
AS 
/* 
This procedure: 
	- updates the Level, Index and IndexDirty columns in AccountsOrder table. 
	- works recursivelly as following: 
		- 1st. step:	increments the current instances @Level. 
		- 2nd. step:	allocate a cursor for sons of given @Parent. 
		- 3rd. step:	loop on the brothers accounts, updating the level, Index and Dirty flags. 
		- 4th. step:	increment Index in current instance, and follow its value from nesting calls. 
		- 5th. step:	return last brothers' index to the calling instance. and continue recursion. 
*/ 
	SET NOCOUNT ON
	DECLARE 
		@c		CURSOR, 
		@Number	[INT],
		@NSons	[INT]

	-- 1st. step:	increments the current instances @Level: 
	SET @Level = @Level + 1 

	-- 2nd. step:	allocate a cursor for sons of given @Parent: 
	IF @Column = 0 -- SortByCode 
		SET @c = CURSOR FAST_FORWARD FOR SELECT [acNumber], [acNSons] FROM [vwAc] WHERE [acParent] = @Parent AND [acType] < 4 ORDER BY [acType], [acCode]

	ELSE IF @Column = 1 -- SortByName 
		SET @c = CURSOR FAST_FORWARD FOR SELECT [acNumber], [acNSons] FROM vwAc  WHERE [acParent] = @Parent AND [acType] < 4 ORDER BY [acType], [acName]

	ELSE BEGIN 
		RAISERROR('AMNxxx: requested sorting Column isn''t recognized', 16, 1) 
		ROLLBACK TRANSACTION  
		RETURN 
	END

	OPEN @c FETCH FROM @c INTO @Number, @NSons
	WHILE @@FETCH_STATUS = 0 
	BEGIN 
		-- 3rd. step:	loop on the brothers accounts, updating the level, Index and Dirty flags. 
		IF @Column = 0 -- SortByCode 
			UPDATE [AccountsOrder] SET [CodeIndex] = @Index, [Level] = @Level, [CodeIndexDirty] = 0 WHERE [Number] = @Number
		ELSE -- SortByName 
			UPDATE [AccountsOrder] SET [NameIndex] = @Index, [Level] = @Level, [NameIndexDirty] = 0 WHERE [Number] = @Number	 

		-- 4th. step:	increment Index in current instance, and collect its value from nesting calls. 
		SET @Index = @Index + 1 
		IF @NSons > 0
			EXEC @Index = prcAccountsOrder_Sort @Column, @Number, @Index, @Level
		FETCH FROM @c INTO @Number, @NSons
	END 
	ClOSE @c 
	DEALLOCATE @c

	-- 5th. step:	return last brothers' index to the calling instance. and continue recursion. 
	RETURN @Index

##################################################################################
CREATE PROC prcAccountsOrder_SortCI
	@Index	[INT],
	@Parent	[INT] = 0,
	@Level	[INT] = 1
AS
	SET NOCOUNT ON
	
	DECLARE
		@c				CURSOR,
		@Number			[INT],
		@Son			[INT],
		@FirstLevel		[INT],
		@FirstCodeIndex	[INT],
		@FirstNameIndex	[INT],
		@OldNumber		[INT]

	SET @OldNumber = 0

	IF @Parent = 0
		SET @c = CURSOR FAST_FORWARD FOR SELECT [Number], [Num1] FROM [ci000] ORDER BY [Number], [Item]
 	ELSE
		SET @c = CURSOR FAST_FORWARD FOR SELECT [Number], [Num1] FROM [ci000] WHERE [Number] = @Parent ORDER BY [Number], [Item]
	
	OPEN @c FETCH FROM @c INTO @Number, @Son
	WHILE @@FETCH_STATUS = 0
	BEGIN
		IF @OldNumber <> @Number
		BEGIN
			INSERT INTO [AccountsOrder] ([Number],  [CodeIndex], [NameIndex], [Level], [CodeIndexDirty], [NameIndexDirty]) VALUES (@Number, @Index, @Index, @Level, 0, 0)
			SELECT @Index = @Index + 1, @OldNumber = @Number
		END

		IF @Son IN (SELECT [Number] FROM [ci000])
		BEGIN
			SET @Level = @Level + 1
			EXEC @Index = [prcAccountsOrder_SortCI] @Index, @Son, @Level
			SET @Level = @Level - 1
		END
		ELSE
		BEGIN
			SELECT TOP 1 @FirstCodeIndex = [CodeIndex], @FirstNameIndex = [NameIndex], @FirstLevel = [Level] FROM [AccountsOrder] WHERE [Number] = @Son ORDER BY [CodeIndex]	

			-- insert the accounts' sons:
			INSERT INTO [AccountsOrder] ([Number], [CodeIndex], [NameIndex], [Level], [CodeIndexDirty], [NameIndexDirty])
				SELECT [Number], [CodeIndex] + @Index - @FirstCodeIndex, [NameIndex] + @Index - @FirstNameIndex, [Level] - @FirstLevel + @Level + 1, 0, 0
				FROM [AccountsOrder]
				WHERE [CodeIndex] BETWEEN @FirstCodeIndex AND ((SELECT MIN([CodeIndex]) FROM [AccountsOrder] WHERE [CodeIndex] > @FirstCodeIndex AND [Level] <= @FirstLevel) - 1)
				ORDER BY [CodeIndex]

			SET @Index = @Index + @@ROWCOUNT
		END

		FETCH FROM @c INTO @Number, @Son
	END
	
	CLOSE @c 
	DEALLOCATE @c
	RETURN @Index

##################################################################################
CREATE PROC prcAccountsOrder_Refresh
	@Forced [BIT] = 0 -- 0 for rebuilding indexed only if necessary 
AS 
/* 
This procedure: 
	- handles the creation and filling of AccountsOrder table, witch contains indexing informations for accounts. 
	- works as following: 
		- 1st. step:	checks for the necessety of re-calculating.
		- 2nd. step:	deletes AccountsOrder table.
		- 3rd. step:	inserts dirt records from ac000 into AccountsOrder table. 
		- 4th. step:	calls the Accounts Sorting procedures.
		- 5th. step:	calls the ci sorting procedure.
*/ 
	SET NOCOUNT ON 
	SET XACT_ABORT ON

	DECLARE @Index [INT]

	-- 1st. step:	checks for the necessety of re-calculating.
	IF @Forced = 0 -- sorting is optional. 
			AND EXISTS(SELECT * FROM [AccountsOrder]) -- and table already has records. 
			AND NOT EXISTS (SELECT * FROM [AccountsOrder] WHERE [CodeIndexDirty] = 1 OR [NameIndexDirty] = 1) -- and the records are not dirty. 
		RETURN -- no need to continue 

	-- work in a transaction: 
	BEGIN TRAN

	-- 2nd. step:	deletes AccountsOrder table.
	DELETE FROM [AccountsOrder]

	-- 3rd. step:	inserts dirt records from ac000 into AccountsOrder table. 
	INSERT INTO [AccountsOrder] ([Number]) SELECT [acNumber] FROM [vwAc] WHERE [acType] < 4

	-- 4th. step:	calls the Accounts Sorting procedures.
	EXEC [prcAccountsOrder_Sort] 0 -- SortByCode
	EXEC @Index = [prcAccountsOrder_Sort] 1 -- SortByIndex

	-- 5th. step:	calls the ci sorting procedure.
	EXEC @Index = [prcAccountsOrder_SortCI] @Index

	COMMIT TRAN

###########################################################################
#END