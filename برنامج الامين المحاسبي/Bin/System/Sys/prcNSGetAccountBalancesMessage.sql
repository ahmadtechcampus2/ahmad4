################################################################################
CREATE	PROCEDURE GetAccountBalancesMessage
	 @templateGuid	UNIQUEIDENTIFIER,
	 @xmlMessage xml OUTPUT
AS
BEGIN
	SET NOCOUNT ON;
	DECLARE @TotalBalances float;
	DECLARE @NameInMsg NVARCHAR(max);
	DECLARE @AccGuid UNIQUEIDENTIFIER;
	DECLARE @CostGuid UNIQUEIDENTIFIER;
	DECLARE @BranchGuid UNIQUEIDENTIFIER;
	DECLARE @FromDate INT;
	DECLARE @ToDate INT;
	
	--„’«œ— «· ﬁ—Ì—
	DECLARE @SrcGuid	UNIQUEIDENTIFIER = 0X0;
	DECLARE @IdSub	Int ;
	DECLARE @RepSrcGuid UNIQUEIDENTIFIER =  Newid();
	SET @xmlMessage = ''
	DECLARE Src_cursor CURSOR
	    FOR  SELECT SrcGuid , SubId from NSAccountBalancesSchedulingSrcType000 WHERE ParentGuid = @templateGuid;
	OPEN Src_cursor
	FETCH NEXT FROM Src_cursor
	INTO  @SrcGuid , @IdSub;
	WHILE @@FETCH_STATUS = 0
	BEGIN
		
	INSERT INTO RepSrcs (IdTbl , IdType , IdSubType ) Values (@RepSrcGuid , @SrcGuid,@IdSub)
	FETCH NEXT FROM Src_cursor INTO  @SrcGuid , @IdSub;
	END 
	CLOSE Src_cursor;
	DEALLOCATE Src_cursor;
	
	DECLARE @language INT = (SELECT [language] FROM NSAccountBalancesScheduling000 WHERE Guid = @templateGuid)
	DECLARE @ShowName INT =  (SELECT ShowNameInMsg FROM NSAccountBalancesScheduling000 WHERE Guid = @templateGuid);
	DECLARE @MessageTitleXml xml = (SELECT @ShowName AS '@Show' , (SELECT Name FROM NSAccountBalancesScheduling000 WHERE Guid = @templateGuid) for XML PATH('MessageTitle'))
	
	DECLARE Msg_cursor CURSOR
	    FOR SELECT AccountGuid , CostGuid,BranchGuid,FromDate,ToDate,NameInMsg FROM NSAccountBalancesSchedulingGrid000 WHERE ParentGuid = @templateGuid  ORDER by [Index] ASC
	OPEN Msg_cursor
	FETCH NEXT FROM Msg_cursor
	INTO  @AccGuid , @CostGuid,@BranchGuid,@FromDate,@ToDate,@NameInMsg;
	WHILE @@FETCH_STATUS = 0
	BEGIN
		SET @TotalBalances = 0
		DECLARE @AccName NVARCHAR(max) = '';
		DECLARE @CostName NVARCHAR(max)= '';
		DECLARE @BranchName NVARCHAR(max)= '';
		DECLARE @Balances NVARCHAR(max)= '';
		DECLARE @lineXml xml;

		IF @language = 0
			 BEGIN
				SET @AccName = (SELECT Name From ac000 Where Guid = @AccGuid)
				IF @CostGuid != 0x0
					SET @CostName = (SELECT Name From co000 Where Guid = @CostGuid)
				IF @BranchGuid != 0x0
					SET @BranchName= (SELECT Name From br000 Where Guid = @BranchGuid)
		END
		ELSE
			 BEGIN
			 SET @AccName = (SELECT ISNULL(LatinName,Name) From ac000 Where Guid = @AccGuid)
				IF @CostGuid != 0x0
					SET @CostName = (SELECT ISNULL(LatinName,Name) From co000 Where Guid = @CostGuid)
				IF @BranchGuid != 0x0
					SET @BranchName= (SELECT ISNULL(LatinName,Name) From br000 Where Guid = @BranchGuid)
		END
		
		DECLARE @StartDate	[DATETIME]
		DECLARE @EndDate	[DATETIME]
		EXEC PrcNSGetAccountBalancesDate @FromDate , @StartDate OUTPUT
		EXEC PrcNSGetAccountBalancesDate @ToDate , @EndDate OUTPUT
			
		EXEC [NSAccBalRep] @StartDate,@EndDate,@AccGuid,@CostGuid,@BranchGuid ,@RepSrcGuid,@TotalBalances OUTPUT ;
		
		SET @Balances = (SELECT [dbo].fnNSFormatMoneyAsNVARCHAR(@TotalBalances,
								(SELECT Code FROM my000 Where Guid = (SELECT CurrencyGUID FROM ac000  WHERE GUID = @AccGuid))))
		
		DECLARE @NameXml xml = (SELECT @NameInMsg AS NameInMSG , @AccName AS AccountName, @CostName As CostName ,@BranchName As BranchName for XML PATH('Name'))
		SET @lineXml = (SELECT  @NameXml, CAST(@Balances AS XML) AS Balances  for XML PATH('Line'))	
				
		SET @xmlMessage =(SELECT @xmlMessage , @lineXml for XML PATH(''))
	
		FETCH NEXT FROM Msg_cursor INTO @AccGuid , @CostGuid,@BranchGuid,@FromDate,@ToDate,@NameInMsg;
	END 
	CLOSE Msg_cursor;
	DEALLOCATE Msg_cursor;
	
	SET @xmlMessage = ( SELECT @language AS '@Align' ,@MessageTitleXml, @xmlMessage for XML PATH('MessageBody'))
END

################################################################################
#END