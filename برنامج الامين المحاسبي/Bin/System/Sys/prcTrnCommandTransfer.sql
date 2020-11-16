####################################################################################
CREATE PROCEDURE prcTrnCommandTransfer  
		@FromDate			DATETIME,     
        @ToDate				DATETIME,                 
        @SenderName			NVARCHAR(255),     
        @ReceiverName		NVARCHAR(255),    
        @CodeContains		NVARCHAR(255),   
        @PhoneNumber		NVARCHAR(150),               
        @FromNumber			NVARCHAR(200),     
        @ToNumber			NVARCHAR(200),     
        @StrState			NVARCHAR(150), -- Transfer State    
        @SourceBranchGuid		UNIQUEIDENTIFIER,    
        @DestinationBranchGuid	UNIQUEIDENTIFIER,
		@ShowAllTransfers		BIT = 0
AS
	SET NOCOUNT ON  
      
	DECLARE @value BIT
	SELECT @Value = CAST(Value AS BIT) FROM op000 WHERE Name = 'TrnCfg_TrnCanBePayidAtAnyBranch'
	SET @ShowAllTransfers = CASE @Value WHEN 0 THEN 0 ELSE @ShowAllTransfers END

    DECLARE @Temp Table ( [Data] SQL_VARIANT)    
    INSERT INTO @Temp
    SELECT * FROM [dbo].[fnTextToRows]( @strState)    
    
	--Ì „ Ã·» «·ÕÊ«·«  «·œ«Œ·Ì… ›ﬁÿ «Ì «·„’œ— Ê«·ÊÃÂ… ÂÊ ⁄»«—… ⁄‰ ›—⁄    
    DECLARE @Str NVARCHAR(4000)      
    SET @Str = 'SELECT [vt].* INTO #RES 
                FROM [vwTrnTransferVoucher] AS [vt] WHERE [vt].[TVSourceType] IN (1,2) AND [vt].[TVDestinationType] IN (1,2)  '  
                                     
    SET @Str = @Str + ' AND [vt].[TvDate] BETWEEN ''' + CAST (@FromDate AS NVARCHAR(20)) +''' AND ''' + CAST(@ToDate AS NVARCHAR(20))+ ''''       
    
    IF @PhoneNumber <> ''   
    Begin   
		SET @PhoneNumber =  '''%'  + @PhoneNumber +   '%'''  
		SET @Str = @Str + ' And ( [vt].SenderPhone1 like ' + @PhoneNumber + ' OR [vt].SenderPhone2 like ' + @PhoneNumber + ' OR [vt].RecPhone1 like ' +  @PhoneNumber + ' OR [vt].RecPhone2 like '+ @PhoneNumber + ' OR [vt].Rec2Phone1 like ' +  @PhoneNumber + ' OR [vt].Rec2Phone2 like ' +  @PhoneNumber + ' ) '   
    End   
    IF @SenderName <> '' 
	  
    BEGIN      
		SET @SenderName =  '''%'  + @SenderName +  '%'''  
        SET @Str = @Str + ' AND [vt].[SenderName] LIKE ' +  @SenderName   
    END  
    IF @ReceiverName <> ''       
    BEGIN      
		SET @ReceiverName =  '''%' + @ReceiverName +   '%'''  
        SET @Str = @Str + ' AND ([vt].[ReceivName] LIKE ' +  @ReceiverName + ' OR [vt].[Receiv2Name] LIKE ' +  @ReceiverName + ' ) ' 
    END  
    IF @CodeContains <> ''       
    BEGIN      
		SET @CodeContains =  '''%' + @CodeContains +   '%'''  
        SET @Str = @Str + ' AND [vt].[TVCode] LIKE ' +  @CodeContains   
    END  
    SET @Str = @Str + ' AND [vt].TvState IN (' + @strState + ')'     

    IF 1 IN (SELECT * FROM @Temp)    
                    SET @Str = @Str + ' AND [vt].TvCashed = 1'     
    IF 2 IN (SELECT * FROM @Temp)    
                    SET @Str = @Str + ' AND [vt].TvPaid = 1'    
    IF 10 IN (SELECT * FROM @Temp)    
                    SET @Str = @Str + ' AND [vt].TvNotified = 1 '                   
    
    IF (@FromNumber <> '')
    BEGIN
		IF (@ToNumber <> '')
			SET @Str = @Str + ' AND [vt].TvNumber BETWEEN ''' + @FromNumber + ''' AND ''' + @ToNumber + '''' 
		ELSE
			SET @Str = @Str + ' AND [vt].TvNumber = ''' + @FromNumber + ''''					
    END
    IF (@SourceBranchGuid <> 0x00)
		SET @Str = @Str + ' AND [vt].TvSourceBranch =''' + CAST(@SourceBranchGuid  AS NVARCHAR(255)) + ''''                 		
		
    IF (@DestinationBranchGuid <> 0x00)
		BEGIN
			DECLARE @desbranchSting NVARCHAR(50)
			SET @desbranchSting =  '''' + CAST(@DestinationBranchGuid  AS NVARCHAR(255)) + ''''
			SET @Str = @Str + ' AND (([vt].TvDestinationBranch = ' + @desbranchSting  +' AND [vt].TvState <> 7 )'  
			SET @Str = @Str + ' OR ([vt].TvState IN (7, 10) AND [vt].TvSourceBranch  = ' + @desbranchSting + ')'
			SET @Str = @Str + ' OR [vt].TvState in (6, 17) AND ' + CAST(@ShowAllTransfers AS CHAR) + ' = 1) '
        END  
	IF (@DestinationBranchGuid = 0x00)
		BEGIN
			SET @Str = @Str + 'AND NOT ([vt].TvState IN (2, 16) AND [vt].TvDestinationBranch = 0x00)'
		END 
                                                                 
    SET @Str = @Str + ' ORDER BY vt.TvInternalNum '                            

	SET @Str = @Str + ' SELECT * FROM #RES ORDER BY TvInternalNum ' 
	EXEC (@Str)     
################################################################################
CREATE PROC prcTrnGetLockingTransfer 
	@InternalNum INT,  
	@SenderBrachOffice [UNIQUEIDENTIFIER], 
	@DestinationBrachOffice [UNIQUEIDENTIFIER],
	@LockingState INT,
	@NotPaid INT,
	@NotCashed INT
AS 
	SET NOCOUNT ON  
	SELECT 
		TRN.Guid AS TrnGuid,
		TRN.InternalNum AS InternalNum,
		TRN.SourceBranch AS SourceBranchGUID,
		SourceBranchOffice.Name AS SourceBranchOfficeName,
		TRN.Destinationbranch AS DestinationbranchGUID,
		DestBranchOffice.Name AS DestBranchOfficeName,
		TRN.SenderGUID SenderGUID,
		Sender.Name AS SenderName,
		TRN.Receiver1_GUID AS ReceiverGUID,
		Receiver.Name AS ReceiverName,
		(TRN.MustPaidAmount / PayCurrencyVal) AS PayAmount,
		TRN.PayCurrency AS PayCurrencyGUID,
		my.Code AS PayCurrencyCode
	 FROM TrntransferVoucher000 AS TRN
		INNER JOIN VwTrnBranchOffice() AS SourceBranchOffice ON TRN.SourceBranch = SourceBranchOffice.Guid
		LEFT JOIN VwTrnBranchOffice() AS DestBranchOffice ON TRN.Destinationbranch = DestBranchOffice.Guid
		INNER JOIN TrnSenderReceiver000 AS Sender ON TRN.SenderGUID = Sender.GUID
		INNER JOIN TrnSenderReceiver000 AS Receiver ON TRN.Receiver1_GUID = Receiver.GUID
		INNER JOIN My000 AS My on TRN.PayCurrency = My.guid	
WHERE 
	((Trn.InternalNum = @InternalNum) OR (@InternalNum = 0))
	AND ((Trn.SourceBranch = @SenderBrachOffice) OR (@SenderBrachOffice = 0x00))
	AND ((Trn.DestinationBranch = @DestinationBrachOffice) OR (@DestinationBrachOffice = 0x00))
	AND (Trn.LockFlag = @LockingState)
	AND ((Trn.paid = 0 AND @NotPaid = 1) OR (@NotPaid = 0))
	AND ((Trn.Cashed = 0 AND @NotCashed = 1) OR (@NotCashed = 0))
ORDER BY internalNum
################################################################################
#END