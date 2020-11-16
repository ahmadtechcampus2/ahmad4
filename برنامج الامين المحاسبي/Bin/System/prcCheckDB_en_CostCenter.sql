###########################################################################################
CREATE PROCEDURE prcCheckDB_en_CostCenter
	@Correct [INT] = 0 
AS 
	DECLARE 
		@c CURSOR, 
		@guid [UNIQUEIDENTIFIER], 
		@name [NVARCHAR](128), 
		@code [NVARCHAR](128), 
		@counter [INT],
		@Cnt [INT]
	-- unknown en.CostCenter: 
	IF @Correct <> 1 
		INSERT INTO [ErrorLog] ([Type], [g1]) 
			SELECT 0x609, [en].[ParentGUID] 
			FROM 
				[en000] AS [en] LEFT JOIN [co000] AS [co] 
				ON [en].[CostGUID] = [co].[GUID] 
			WHERE 
				ISNULL( [en].[CostGUID], 0x0) <> 0x0
				AND [co].[GUID] IS NULL

	IF @Correct <> 0 AND EXISTS(SELECT * FROM [en000] WHERE [CostGuid] != 0x0 AND [CostGuid] NOT IN (SELECT [GUID] FROM [co000])) 
	BEGIN 
		set @code = (select max([code]) from [co000] where [code] like '#_%') 
		if @code is null 
			set @counter = 1 
		else 
			set @counter = cast(right(@code, len(@code) - 2) as int) + 1 
		
		SELECT @Cnt = MAX([Number]) from [co000]

		SET @c = CURSOR FAST_FORWARD FOR SELECT DISTINCT [CostGuid] FROM [en000] WHERE [CostGuid] != 0x0 AND [CostGuid] NOT IN (SELECT [GUID] FROM [co000]) 
		OPEN @c FETCH FROM @c INTO @guid 
			 
		WHILE @@FETCH_STATUS = 0 
		BEGIN 
			set @code = '#_' + replicate('0', 6 - len(cast(@counter as [NVARCHAR](50)))) + cast(@counter as [NVARCHAR](50)) 
			set @name = '„—ﬂ“ ﬂ·›… Œÿ√ #' + cast(@counter as [NVARCHAR](50)) 
			SET @Cnt = @Cnt + 1
			INSERT INTO [co000]( [Number], [Guid], [Code], [Name], [ParentGuid], [Security])
				    VALUES( @Cnt, @guid, @code, @name, 0x0, 1)
			set @counter = @counter + 1 
			FETCH FROM @c INTO @guid 
		END 
		CLOSE @c DEALLOCATE @c 
	END 
###########################################################################################
#END