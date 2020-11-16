##################################################################
CREATE PROC prcMergeAddress
	@AddressCardType INT, -- 1: Country, 2: City, 3: Area
	@FromGUID UNIQUEIDENTIFIER,
	@ToGUID UNIQUEIDENTIFIER,
	@DeleteMergedCards BIT = 0
AS
    SET NOCOUNT ON

	DECLARE 
		@UpdatedRowsAffected INT,
		@RowsNotUpdated INT,
		@IsDeleted BIT 

	SET @UpdatedRowsAffected = 0
	SET @IsDeleted = 0
	SET @RowsNotUpdated = 0

	IF @AddressCardType = 0
		GOTO FINISH 
	IF (ISNULL(@FromGUID, 0x0) = 0x0) OR (ISNULL(@ToGUID, 0x0) = 0x0)
		GOTO FINISH
	IF @FromGUID = @ToGUID
		GOTO FINISH

	IF @AddressCardType = 1
	BEGIN 
		IF (NOT EXISTS (SELECT * FROM AddressCountry000 WHERE GUID = @FromGUID) OR 
			NOT EXISTS (SELECT * FROM AddressCountry000 WHERE GUID = @ToGUID))
				GOTO FINISH
		
		UPDATE AddressCity000 
		SET ParentGUID = @ToGUID
		WHERE 
			ParentGUID = @FromGUID
			AND 
			[Name] NOT IN (SELECT [Name] FROM AddressCity000 WHERE ParentGUID = @ToGUID) 
			AND
			[LatinName] NOT IN(SELECT [LatinName] FROM AddressCity000 WHERE ParentGUID = @ToGUID AND [LatinName] != '')

		SET @UpdatedRowsAffected = @@ROWCOUNT

		SET @RowsNotUpdated = (SELECT COUNT(*) FROM AddressCity000 WHERE ParentGUID = @FromGUID)
		
		IF (@RowsNotUpdated = 0) AND (ISNULL(@DeleteMergedCards, 0) = 1)
		BEGIN
			DELETE AddressCountry000 WHERE GUID = @FromGUID 
			SET @IsDeleted = 1
		END
	END
	IF @AddressCardType = 2
	BEGIN 
		IF (NOT EXISTS (SELECT * FROM AddressCity000 WHERE GUID = @FromGUID) OR 
			NOT EXISTS (SELECT * FROM AddressCity000 WHERE GUID = @ToGUID))
				GOTO FINISH

		UPDATE AddressArea000 
		SET ParentGUID = @ToGUID
		WHERE 
			ParentGUID = @FromGUID
			AND 
			[Name] NOT IN (SELECT [Name] FROM AddressArea000 WHERE ParentGUID = @ToGUID) 
			AND
			[LatinName] NOT IN(SELECT [LatinName] FROM AddressArea000 WHERE ParentGUID = @ToGUID AND [LatinName] != '')

		SET @UpdatedRowsAffected = @@ROWCOUNT

		SET @RowsNotUpdated = (SELECT COUNT(*) FROM AddressArea000 WHERE ParentGUID = @FromGUID)
		
		IF (@RowsNotUpdated = 0) AND (ISNULL(@DeleteMergedCards, 0) = 1)
		BEGIN
			DELETE AddressCity000 WHERE GUID = @FromGUID 
			SET @IsDeleted = 1
		END
	END
	IF @AddressCardType = 3
	BEGIN 
		IF (NOT EXISTS (SELECT * FROM AddressArea000 WHERE GUID = @FromGUID) OR 
			NOT EXISTS (SELECT * FROM AddressArea000 WHERE GUID = @ToGUID))
				GOTO FINISH

		UPDATE CustAddress000 
		SET AreaGUID = @ToGUID
		WHERE AreaGUID = @FromGUID

		SET @UpdatedRowsAffected = @@ROWCOUNT

		UPDATE RestDriverAddress000 SET AddressGUID = @ToGUID WHERE AddressGUID = @FromGUID

		SET @RowsNotUpdated = (SELECT COUNT(*) FROM CustAddress000 WHERE AreaGUID = @FromGUID)

		IF (@RowsNotUpdated = 0) AND (ISNULL(@DeleteMergedCards, 0) = 1)
		BEGIN
			DELETE AddressArea000 WHERE GUID = @FromGUID 
			SET @IsDeleted = 1
		END
	END

	FINISH:
		SELECT 
			@UpdatedRowsAffected AS UpdatedRowsAffected,
			@RowsNotUpdated AS RowsNotUpdated,
			@IsDeleted AS IsDeleted
#######################################################################################
#END