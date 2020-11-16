################################################################################
CREATE PROC prcPOS_LoyaltyCards_LOC_ActivateCardSource @DBName NVARCHAR(256), @FileName NVARCHAR(256), @UserName NVARCHAR(256), @IsActive BIT
AS
	SET NOCOUNT ON

	DECLARE @guid UNIQUEIDENTIFIER = ISNULL((SELECT TOP 1 GUID FROM POSLoyaltyCardSource000 
												WHERE DBName = @DBName AND UserName = @UserName
											), 0x0)

	IF @guid != 0x0
	BEGIN 
		UPDATE POSLoyaltyCardSource000 
		SET IsActive = @IsActive  , 
			OperationTime = IIF(@IsActive = 1, GETDATE(), OperationTime) , 
			[FileName] = @FileName, 
			InActivateDate = IIF(@IsActive = 1, InactivateDate, GETDATE()) 
		WHERE GUID = @guid
	END 
	ELSE 
	BEGIN 
		DECLARE @NextNumber INT = (SELECT ISNULL(MAX(Number),0) + 1 FROM POSLoyaltyCardSource000)
		DECLARE @InactivateDate DATETIME = IIF(@IsActive = 1, '', GETDATE())
		DECLARE @OperationTime  DATETIME = IIF(@IsActive = 1, GETDATE(), '')

		INSERT INTO POSLoyaltyCardSource000(Number, GUID, DBName, [FileName], UserName, OperationTime, IsActive, InActivateDate) 
		VALUES ( @NextNumber, NEWID(), @DBName, @FileName, @UserName, @OperationTime, @IsActive , @InactivateDate  )
	END

################################################################################
CREATE PROC prcPOS_LoyaltyCards_ActivateCardSource @prevDB NVARCHAR(256), @centralizedDB NVARCHAR(256), @IsActive BIT  
AS
	SET NOCOUNT ON

	IF @centralizedDB = '' AND @prevDB = ''
		RETURN

	IF @prevDB = @centralizedDB
		SET @prevDB = ''

	DECLARE @UserName NVARCHAR(256) = dbo.fnGetCurrentUserName()
	DECLARE @DBName NVARCHAR(256) = DB_NAME()
	DECLARE @FileName NVARCHAR(256) = ( SELECT CAST(Value AS NVARCHAR(256)) FROM sys.extended_properties   
										WHERE name =  IIF(dbo.fnConnections_GetLanguage() = 0, 'AmnDBName', 'AmnDBLatinName'
										))

	DECLARE @params NVARCHAR(1000) = N'@DBName NVARCHAR(256), @FileName NVARCHAR(256), @UserName NVARCHAR(256), @IsActive BIT '
	DECLARE @Sql NVARCHAR(MAX)

	IF @prevDB != '' AND EXISTS(SELECT 1 FROM sys.databases WHERE (name = @prevDB AND state = 0))
	BEGIN TRY 	
		DECLARE @DB NVARCHAR(256) = QUOTENAME(@prevDB) + N'.[dbo].'
		SET @Sql = N'EXEC ' + @DB + N'prcPOS_LoyaltyCards_LOC_ActivateCardSource @DBName, @FileName, @UserName, @IsActive'	
		EXEC sp_executesql @Sql, @params, @DBName = @DBName, @FileName = @FileName, @UserName = @UserName,  @IsActive = 0
	END TRY 
	BEGIN CATCH 

	END CATCH

	IF @centralizedDB = ''
		RETURN 

	IF EXISTS(SELECT 1 FROM sys.databases WHERE (name = @centralizedDB AND state = 0))
		BEGIN TRY 
			SET @DB = QUOTENAME(@centralizedDB) + N'.[dbo].'
			SET @Sql = N'EXEC ' + @DB + N'prcPOS_LoyaltyCards_LOC_ActivateCardSource @DBName, @FileName, @UserName, @IsActive'		
			EXEC sp_executesql @Sql, @params, @DBName = @DBName, @FileName = @FileName, @UserName = @UserName,  @IsActive = @IsActive
		END TRY 
		BEGIN CATCH
			IF @IsActive = 1 
				SELECT -1
		END CATCH	
	ELSE IF @IsActive = 1  
		SELECT -1
################################################################################
#END	