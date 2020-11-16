CREATE  PROC prcDistUpdateData
AS
	SET NOCOUNT ON
	IF [dbo].[fnObjectExists]( 'DistCe000.DistributorGuid') <> 0 
	EXEC('
		CREATE TABLE [#DistTbl] ([DistGuid] [UNIQUEIDENTIFIER], [DistCode] [NVARCHAR](255), [DistName] [NVARCHAR](255), [CiGuid] [UNIQUEIDENTIFIER])
		INSERT INTO [#DistTbl] (DistGuid, DistCode, DistName)
			SELECT Ce.DistributorGuid, D.Code, D.Name
			FROM DistCE000 AS Ce INNER JOIN Distributor000 AS D ON D.Guid = Ce.DistributorGuid
			GROUP BY Ce.DistributorGuid, D.Code, D.Name

		CREATE TABLE [#AccTbl] ([DistGuid] [UNIQUEIDENTIFIER], [AccGuid] [UNIQUEIDENTIFIER], [CustGuid] [UNIQUEIDENTIFIER], [Route1] [INT], [Route2] [INT], [Route3] [INT], [Route4] [INT])
		INSERT INTO [#AccTbl] 
			SELECT Ce.DistributorGuid, Cu.CuAccount, Ce.CustomerGuid, Ce.Route1, Ce.Route2, Ce.Route3, Ce.Route4 
			FROM DistCE000 AS Ce 
			INNER JOIN vwCu AS Cu ON Cu.CuGuid = Ce.CustomerGuid

		DECLARE @CMain		Cursor,
			@CDetail	Cursor,
			@DistGuid	UNIQUEIDENTIFIER,
			@CiGuid		UNIQUEIDENTIFIER,
			@AccGuid	UNIQUEIDENTIFIER,
			@DistCode	NVARCHAR(255),
			@DistName	NVARCHAR(255),
			@AccName	NVARCHAR(255),
			@AccCode	NVARCHAR(255),
			@CheckDate	DATETIME,
			@Number		INT
	
		SET @CMain = CURSOR FAST_FORWARD FOR 
			SELECT DistGuid, DistCode, DistName FROM #DistTbl
		OPEN @CMain FETCH FROM @CMain INTO @DistGuid, @DistCode, @DistName
		WHILE @@FETCH_STATUS = 0 
		BEGIN 
			SET @CiGuid = newId()
			SET @AccCode = ''8000'' + @DistCode
			SET @AccName = @DistName
			SELECT @Number = MAX(Number) + 1 FROM Ac000	
			SELECT TOP 1 @CheckDate = CheckDate FROM Ac000	
		        -- Create Aggregate Accounts
			INSERT INTO Ac000 
				(Number,     Code,     Name,     CDate, NSons, CurrencyVal, CheckDate, Security, Type, State,    Guid, ParentGuid, FinalGuid, CurrencyGuid, BranchGuid, BranchMask)
			VALUES
				(@Number, @AccCode, @AccName, GetDate(), 0,     0,          @CheckDate, 1,        4,    0,    @CiGuid, 0x00,       0x00,      0x00,         0x00,       0)
				-- Create Aggregate Sons Accounts
				SET @CDetail = CURSOR FAST_FORWARD FOR 
					SELECT AccGuid FROM #AccTbl WHERE DistGuid = @DistGuid
				OPEN @CDetail FETCH FROM @CDetail INTO @AccGuid
				WHILE @@FETCH_STATUS = 0 
				BEGIN 
					SELECT @Number = MAX(ISNULL(Item,0)) + 1 FROM Ci000	WHERE ParentGuid = @CiGuid
					INSERT INTO Ci000 	(Item, Guid, ParentGuid, SonGuid)
					VALUES			(@Number, newID(), @CiGuid, @AccGuid)	
							   
					FETCH FROM @CDetail INTO @AccGuid
				END
				CLOSE @CDetail DEALLOCATE @CDETAIL 
			-- Update DistAccCust To Take Aggregate Account
			UPDATE Distributor000 SET CustomersAccGuid = @CiGuid WHERE Guid = @DistGuid
				 
			FETCH FROM @CMain INTO @DistGuid, @DistCode, @DistName
		END -- @c loop 
		CLOSE @CMain DEALLOCATE @CMain 

		-- Move Dist Lines From DistCe To DistLines
		DELETE FROM DistDistributionLines000
		INSERT INTO DistDistributionLines000 
			SELECT NewID(), [DistGuid], [CustGuid], [Route1], [Route2], [Route3], [Route4]
			FROM [#AccTbl]

		-- Delete Columns
		EXEC [dbo].[prcDropFld] ''DistCe000'', ''DistributorGUID''
		EXEC [dbo].[prcDropFld] ''DistCe000'', ''Route1''
		EXEC [dbo].[prcDropFld] ''DistCe000'', ''Route2''
		EXEC [dbo].[prcDropFld] ''DistCe000'', ''Route3''
		EXEC [dbo].[prcDropFld] ''DistCe000'', ''Route4''
		EXEC [dbo].[prcDropFld] ''DistCe000'', ''MaxDebt''
	')
	-------------------------------------------------------------------------
