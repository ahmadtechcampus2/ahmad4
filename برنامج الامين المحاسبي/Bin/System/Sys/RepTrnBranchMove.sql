##################################################################
CREATE PROC RepTrnBranchMove
	@FromDate 		DATETIME,
	@ToDate 		DATETIME,
	@SourceRepGuid	UNIQUEIDENTIFIER,   
	@DestRepGuid    UNIQUEIDENTIFIER, 
	@State 			NVARCHAR(150),
	@Field1_GroupBy INT,
	@Field2_GroupBy INT
AS
	SET NOCOUNT ON 
             
	DECLARE @Temp Table ( [Data] SQL_VARIANT)   
	INSERT INTO @Temp SELECT * FROM [dbo].[fnTextToRows]( @State)  
	
	
	DECLARE @SqlString NVARCHAR(4000)     
	CREATE TABLE [#TransfersSourceTbl] ( [Guid] [UNIQUEIDENTIFIER], [UserSecurity] [INTEGER])     
        CREATE TABLE [#TransfersDestTbl] ( [Guid] [UNIQUEIDENTIFIER], [UserSecurity] [INTEGER])     
	
	INSERT INTO [#TransfersSourceTbl]EXEC [prcGetTransfersTypesList] @SourceRepGuid     
	INSERT INTO [#TransfersDestTbl]EXEC [prcGetTransfersTypesList] @DestRepGuid     
	

	SET @SqlString = 'SELECT [vt].* 
			FROM [vwTrnTransferVoucher] AS [vt] ' 

	IF (@SourceRepGuid <> 0x0)
		SET @SqlString = @SqlString + ' INNER JOIN #TransfersSourceTbl AS srcBr ON srcBr.Guid = vt.TVSourceBranch '
				
	IF (@DestRepGuid <> 0x0)
		SET @SqlString = @SqlString + ' INNER JOIN #TransfersDestTbl AS dstBr ON dstBr.Guid = vt.TVDestinationBranch '

	SET @SqlString = @SqlString + ' WHERE [vt].[TvDate] BETWEEN ''' + CAST (@FromDate AS NVARCHAR(20)) +''' AND ''' + CAST(@ToDate AS NVARCHAR(20))+ ''''      
	


	IF @Field1_GroupBy = 0  
		SET @SqlString = @SqlString + ' ORDER BY [vt].[TvDate] '                
	ELSE	
	
	IF @Field1_GroupBy = 1   
	BEGIN
		IF @Field2_GroupBy = 2
			SET @SqlString = @SqlString + ' ORDER BY [vt].SourcBranchName, [vt].DestBranchName, [vt].[TvDate]'
		ELSE
			SET @SqlString = @SqlString + ' ORDER BY [vt].SourcBranchName, [vt].[TvDate]'
	END		
	
	ELSE
	IF @Field1_GroupBy = 2   
	BEGIN
		IF @Field2_GroupBy = 1
			SET @SqlString = @SqlString + ' ORDER BY [vt].DestBranchName, [vt].SourcBranchName, [vt].[TvDate]'
		ELSE			
			SET @SqlString = @SqlString + ' ORDER BY [vt].DestBranchName, [vt].[TvDate]'
	END
	
	EXEC (@SqlString)
###################################################################
CREATE PROC RepTrnCenterMove
	@FromDate 		DATETIME,
	@ToDate 		DATETIME,
	@SourceRepGuid	UNIQUEIDENTIFIER,   
	@DestRepGuid    UNIQUEIDENTIFIER, 
	@State 			NVARCHAR(150),
	@Field1_GroupBy INT,
	@Field2_GroupBy INT
AS
	SET NOCOUNT ON 
             
	DECLARE @Temp Table ( [Data] SQL_VARIANT)   
	INSERT INTO @Temp SELECT * FROM [dbo].[fnTextToRows]( @State)  
	
	
	DECLARE @SqlString NVARCHAR(4000)     
	CREATE TABLE [#TransfersSourceTbl] ( [Guid] [UNIQUEIDENTIFIER], [UserSecurity] [INTEGER])     
        CREATE TABLE [#TransfersDestTbl] ( [Guid] [UNIQUEIDENTIFIER], [UserSecurity] [INTEGER])     
	
	INSERT INTO [#TransfersSourceTbl]	EXEC [prcGetTransfersCenterList] @SourceRepGuid     
	INSERT INTO [#TransfersDestTbl]		EXEC [prcGetTransfersCenterList] @DestRepGuid     
	

	SET @SqlString = 'SELECT [vt].*
	FROM [vwTrnTransferVoucher] AS [vt] ' 

	IF (@SourceRepGuid <> 0x0)
	BEGIN
		SET @SqlString = @SqlString + ' 
		INNER JOIN #TransfersSourceTbl AS senderCenter ON senderCenter.Guid = vt.TVSenderCenterGuid '
		--SET @SqlString = @SqlString + '
		--INNER JOIN VwTrnCenter AS senderCenter ON senderCenter.Guid =  senCenter.Guid  '
	END			
	IF (@DestRepGuid <> 0x0)
	BEGIN
		SET @SqlString = @SqlString + ' 
		INNER JOIN #TransfersDestTbl AS RecieverCenter ON RecieverCenter.Guid = vt.TVRecieverCenterGuid '
		--SET @SqlString = @SqlString + '
		--INNER JOIN VwTrnCenter AS RecieverCenter ON RecieverCenter.Guid =  resCenter.Guid '
	END
	SET @SqlString = @SqlString + ' 
	WHERE [vt].[TVDate] BETWEEN ''' + CAST (@FromDate AS NVARCHAR(20)) +''' AND ''' + CAST(@ToDate AS NVARCHAR(20))+ ''''      
	

	IF @Field1_GroupBy = 0  
		SET @SqlString = @SqlString + ' 
	ORDER BY [vt].[TVDate] '                
	ELSE	
	
	IF @Field1_GroupBy = 1   
	BEGIN
		IF @Field2_GroupBy = 2
			SET @SqlString = @SqlString + ' 
	ORDER BY vt.[TVSenderCenterName], vt.[TVRecieverCenterName], [vt].[TVDate]'
		ELSE
			SET @SqlString = @SqlString + ' 
	ORDER BY vt.[TVSenderCenterName], [vt].[TVDate]'
	END		
	
	ELSE
	IF @Field1_GroupBy = 2   
	BEGIN
		IF @Field2_GroupBy = 1
			SET @SqlString = @SqlString + ' 
	ORDER BY vt.[TVRecieverCenterName],vt.[TVSenderCenterName], [vt].[TVDate]'
		ELSE			
			SET @SqlString = @SqlString + ' 
	ORDER BY vt.[TVRecieverCenterName], [vt].[TVDate]'
	END
	EXEC (@SqlString)
####################################################################
#END