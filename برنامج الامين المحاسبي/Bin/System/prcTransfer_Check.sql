#########################################################
CREATE PROC prcTransfer_Check
	@InBillGUID [UNIQUEIDENTIFIER],
	@OutBillGUID [UNIQUEIDENTIFIER],
	@correct [INT] = 1 
AS 
	SET NOCOUNT ON 

	DECLARE 
		@InBillNumber FLOAT, 
		@OutBillNumber FLOAT

	IF NOT EXISTS( SELECT * FROM [BU000] WHERE [guid] = @InBillGUID)
	BEGIN 
		RAISERROR('AmnE1011: The InBill guid not found.', 16, 1) 
		RETURN 
	END 

	IF NOT EXISTS( SELECT * FROM [BU000] WHERE [guid] = @OutBillGUID)
	BEGIN 
		RAISERROR('AmnE1012: The OutBill guid not found.', 16, 1) 
		RETURN 
	END 

	SET @InBillNumber = (SELECT [NUMBER] FROM [BU000] WHERE [guid] = @InBillGUID)
	SET @OutBillNumber = (SELECT [NUMBER] FROM [BU000] WHERE [guid] = @OutBillGUID)

	IF( @InBillNumber <> @OutBillNumber)
	BEGIN 
		IF( @correct = 0)
		BEGIN 
			RAISERROR('AmnE1013: There is differnece between in bill and out bill.', 16, 1) 
			RETURN 

		END ELSE BEGIN 
			DECLARE 
				@InBillTypeGUID [UNIQUEIDENTIFIER],
				@OutBillTypeGUID [UNIQUEIDENTIFIER],
				@InBillBranchGUID [UNIQUEIDENTIFIER],
				@OutBillBranchGUID [UNIQUEIDENTIFIER],
				@bLoop [BIT]


			SELECT 
				@InBillTypeGUID = [TypeGUID], 
				@InBillBranchGUID = [Branch]
			FROM 
				[bu000]
			WHERE 
				[guid] = @InBillGUID


			SELECT 
				@OutBillTypeGUID = [TypeGUID], 
				@OutBillBranchGUID = [Branch]
			FROM 
				[bu000]
			WHERE 
				[guid] = @OutBillGUID
						

			IF @InBillNumber > @OutBillNumber
			BEGIN 
				IF NOT EXISTS( SELECT * FROM [BU000] WHERE [TypeGUID] = @OutBillTypeGUID AND [Branch] = @OutBillBranchGUID AND [NUMBER] = @InBillNumber)
					UPDATE [BU000] SET NUMBER = @InBillNumber WHERE [guid] = @OutBillGUID
				ELSE BEGIN 
					SET @bLoop = 1 

					WHILE @bLoop = 1
					BEGIN 
						SET @InBillNumber = @InBillNumber + 1
						
						IF NOT EXISTS( SELECT * FROM [BU000] WHERE [TypeGUID] = @OutBillTypeGUID AND [Branch] = @OutBillBranchGUID AND [NUMBER] = @InBillNumber)
							AND NOT EXISTS( SELECT * FROM [BU000] WHERE [TypeGUID] = @InBillTypeGUID AND [Branch] = @InBillBranchGUID AND [NUMBER] = @InBillNumber)
						BEGIN 
							UPDATE [bu000] set Number = @InBillNumber where guid = @InBillGUID
							IF @@ERROR <> 0
								CONTINUE

							UPDATE [bu000] set Number = @InBillNumber where guid = @OutBillGUID
							IF @@ERROR <> 0
								CONTINUE

							SET @bLoop = 0 
						END 
					END
				END 
			END ELSE BEGIN 
				IF NOT EXISTS( SELECT * FROM [BU000] WHERE [TypeGUID] = @InBillTypeGUID AND [Branch] = @InBillBranchGUID AND [NUMBER] = @OutBillNumber)
					UPDATE [BU000] SET NUMBER = @OutBillNumber WHERE [guid] = @InBillGUID
				ELSE BEGIN 
					SET @bLoop = 1 

					WHILE @bLoop = 1
					BEGIN 
						SET @OutBillNumber = @OutBillNumber + 1
						
						IF NOT EXISTS( SELECT * FROM [BU000] WHERE [TypeGUID] = @OutBillTypeGUID AND [Branch] = @OutBillBranchGUID AND [NUMBER] = @InBillNumber)
							AND NOT EXISTS( SELECT * FROM [BU000] WHERE [TypeGUID] = @InBillTypeGUID AND [Branch] = @InBillBranchGUID AND [NUMBER] = @InBillNumber)
						BEGIN 
							UPDATE [bu000] set Number = @OutBillNumber where guid = @InBillGUID
							IF @@ERROR <> 0
								CONTINUE

							UPDATE [bu000] set Number = @OutBillNumber where guid = @OutBillGUID
							IF @@ERROR <> 0
								CONTINUE

							SET @bLoop = 0 
						END 
					END
				END 
			END 
		END 
	END 
#########################################################
#END
