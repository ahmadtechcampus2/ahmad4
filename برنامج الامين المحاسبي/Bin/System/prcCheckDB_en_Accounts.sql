###########################################################################################
CREATE PROCEDURE prcCheckDB_en_Accounts
	@Correct [INT] = 0
AS


	DECLARE
		@c CURSOR,
		@guid [UNIQUEIDENTIFIER],
		@name [NVARCHAR](128),
		@code [NVARCHAR](128),
		@counter [INT]



	-- unknown en.Account:
	IF @Correct <> 1
		INSERT INTO [ErrorLog]([Type], [g1])
			SELECT 0x604, [en].[ParentGUID]
			FROM [en000] AS [en] LEFT JOIN [ac000] AS [ac] ON [en].[AccountGUID] = [ac].[GUID]
			WHERE [ac].[GUID] IS NULL

	IF @Correct <> 0 AND EXISTS(SELECT * FROM [en000] WHERE [accountGuid] NOT IN (SELECT [GUID] FROM [ac000]) AND [accountGuid] != 0x0)
	BEGIN
		set @code = (select max([code]) from [ac000] where [code] like '#_%')
		if @code is null
			set @counter = 1
		else
			set @counter = cast(right(@code, len(@code) - 2) as int) + 1


		SET @c = CURSOR FAST_FORWARD FOR SELECT DISTINCT [accountGuid] FROM [en000] WHERE [accountGuid] NOT IN (SELECT [GUID] FROM [ac000]) AND [accountGuid] != 0x0
		OPEN @c FETCH FROM @c INTO @guid
			
		WHILE @@FETCH_STATUS = 0
		BEGIN
			set @code = '#_' + replicate('0', 6 - len(cast(@counter as [NVARCHAR](50)))) + cast(@counter as [NVARCHAR](50))
			set @name = 'Õ”«» Œÿ√ #' + cast(@counter as [NVARCHAR](50))
			exec  [prcAccount_add] @guid = @guid, @code = @code, @name = @name, @UseFlag = 1
			set @counter = @counter + 1
			FETCH FROM @c INTO @guid
		END

		CLOSE @c DEALLOCATE @c

	END

	-- en.Account has sons:
	IF @Correct <> 1
		INSERT INTO [ErrorLog] ([Type], [g1], [g2])
			SELECT 0x605, [en].[ParentGUID], [en].[AccountGUID]
			FROM [en000] AS [en] INNER JOIN [ac000] AS [ac] ON [en].[AccountGUID] = [ac].[GUID]
			WHERE [ac].[NSons] <> 0

	-- en.Account type is not normal:
	IF @Correct <> 1
		INSERT INTO [ErrorLog] ([Type], [g1], [g2])
			SELECT 0x606, [en].[ParentGUID], [en].[AccountGUID]
			FROM [en000] AS [en] INNER JOIN [ac000] AS [ac] ON [en].[AccountGUID] = [ac].[GUID]
			WHERE [ac].[Type] <> 1


	-- unknown en.contraAccount:
	IF @Correct <> 1
		INSERT INTO [ErrorLog] ([Type], [g1])
			SELECT 0x607, [en].[ParentGUID]
			FROM [en000] AS [en] LEFT JOIN [ac000] AS [ac] ON [en].[contraAccGUID] = [ac].[GUID]
			WHERE [ac].[GUID] IS NULL and [en].[contraAccGuid] != 0x0

	-- correct by set contra acc to 0x0
	IF @Correct <> 0 AND EXISTS(SELECT * FROM [en000] WHERE [contraAccGuid] NOT IN (SELECT [GUID] FROM [ac000]) AND [contraAccGuid] != 0x0)
	BEGIN
		set @code = (select max([code]) from [ac000] where [code] like '#_%')
		if @code is null
			set @counter = 1
		else
			set @counter = cast(right(@code, len(@code) - 2) as int) + 1


		SET @c = CURSOR FAST_FORWARD FOR SELECT DISTINCT [contraAccGuid] FROM [en000] WHERE [contraAccGuid] NOT IN (SELECT [GUID] FROM [ac000]) AND [contraAccGuid] != 0x0
		OPEN @c FETCH FROM @c INTO @guid
			
		WHILE @@FETCH_STATUS = 0
		BEGIN
			set @code = '#_' + replicate('0', 6 - len(cast(@counter as [NVARCHAR](50)))) + cast(@counter as [NVARCHAR](50))
			set @name = 'Õ”«» Œÿ√ #' + cast(@counter as [NVARCHAR](50))
			exec  [prcAccount_add] @guid = @guid, @code = @code, @name = @name, @UseFlag = 1
			set @counter = @counter + 1
			FETCH FROM @c INTO @guid
		END

		CLOSE @c DEALLOCATE @c

	END

	if( @Correct <> 0)
	begin
		
		EXEC prcDisableTriggers  'en000'
		update en set en.ContraAccGuid = py.AccountGuid
		from 
			py000 py 
			inner join  er000 er on er.ParentGuid = Py.Guid
			inner join ce000 ce on ce.Guid = er.EntryGuid
			inner join en000 en on ce.Guid = en.ParentGuid
			inner join et000 et on et.Guid = ce.TypeGuid
		where
			isnull( py.AccountGuid, 0x0) != 0x0 and py.AccountGuid != en.AccountGuid and isnull( en.ContraAccGuid, 0x0) = 0x0
			and fldContraAcc !=  0
		alter table en000 enable trigger all
	end

###########################################################################################
#END