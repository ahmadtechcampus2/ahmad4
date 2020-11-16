#####################################################
CREATE PROCEDURE RepTrnTransferBranchTotal
                 @SourceBranch               UNIQUEIDENTIFIER = 0x0 , 
                 @DestBranch   UNIQUEIDENTIFIER = 0x0
AS 
   IF (@SourceBranch <> 0x0 AND @DestBranch <> 0x0)
     BEGIN
                select SourcBranchName , DestBranchName ,sum(TVAmount) AS Ammount
        from  vwTrnTransferVoucher 
        where TVSourceBranch = @SourceBranch
        And   TVDESTINATIONBRANCH = @DestBranch
        group by SourcBranchName , DestBranchName
    
    END
   
   ELSE IF(@SourceBranch <> 0x0 AND @DestBranch = 0x0)
      BEGIN
        select SourcBranchName , DestBranchName ,sum(TVAmount) AS Ammount
        from  vwTrnTransferVoucher 
        where TVSourceBranch = @SourceBranch
        group by SourcBranchName , DestBranchName
      END

   ELSE IF(@SourceBranch = 0x0 AND @DestBranch <> 0x0)
      BEGIN
        select SourcBranchName , DestBranchName ,sum(TVAmount) AS Ammount
        from  vwTrnTransferVoucher 
        where TVDESTINATIONBRANCH = @DestBranch
        group by SourcBranchName , DestBranchName
      END

   ELSE 
      BEGIN
        select SourcBranchName , DestBranchName ,sum(TVAmount) AS Ammount
        from  vwTrnTransferVoucher 
        group by SourcBranchName , DestBranchName
      END
#####################################################
CREATE PROCEDURE prcGetTransfersTypesList
	@SrcGuid UNIQUEIDENTIFIER = NULL , 
	@UserGuid UNIQUEIDENTIFIER = NULL 
AS
	SET NOCOUNT ON
	SELECT 
		[GUID], 
		[Security] 
	FROM 
		[dbo].[fnGetTransfersTypesList](@SrcGuid, @UserGuid) 
#####################################################
CREATE PROCEDURE prcGetTransfersCenterList
	@SrcGuid UNIQUEIDENTIFIER = NULL , 
	@UserGuid UNIQUEIDENTIFIER = NULL 
AS
	SET NOCOUNT ON
	SELECT 
		[GUID], 
		[Security] 
	FROM 
		[dbo].[fnGetTransfersCenterList](@SrcGuid, @UserGuid) 
#####################################################
CREATE   PROCEDURE prcBrowsTransfer 
            @FromDate                       DATETIME,    
            @ToDate                         DATETIME,    
            @DateType                       INT,    
            @SenderName					    NVARCHAR(255),    
            @ReceiverName                   NVARCHAR(255),   
            @CodeContains                   NVARCHAR(255),  
            @Number                         NVARCHAR(200),    
            @FromNumber                     NVARCHAR(200),    
            @ToNumber                       NVARCHAR(200),    
            @SourceRepGuid                  UNIQUEIDENTIFIER,   
            @DestRepGuid                    UNIQUEIDENTIFIER, 
            @StrState                       NVARCHAR(150), -- Transfer State    
            @SortBy                         INT, 
            @UseStatementNo                 INT, 
            @PhoneNumber                    NVARCHAR(150),  
            @VouchersType                   INT, -- √‰Ê«⁄ «·ÕÊ«·« 
            @StmType                        INT, 
            @StmTypeGuid                    UNIQUEIDENTIFIER = 0x0, 
            @StmNumber						NVARCHAR(50) = '',
            @BankGuid					    UNIQUEIDENTIFIER = 0x0,
            @OpType							INT = 0,	--0 Browse,	1 Sourcer-Branch Operation,	2 Destination-Branch Operation 
            @FilterStatement				INT = 2,	--2 All Transfers, 1 FromStatement Transfers, 0 Not FromStatement Transfers 
            @FilterBySrcDstType				INT = 0		--0 All : No filtering(Src=Any, Dst=Any) , 1 (Src=Branch, Dst=Any), 2 (Src=Any, Dst=Branch), 3 (Src=Branch, Dst=Branch)
AS 
            /*    
            @DateType    
            -1 «—ÌŒ «·ÕÊ«·…    
            -2  «—ÌŒ «·≈—”«·   
            -3  «—ÌŒ «· »·Ì€    
            -4  «—ÌŒ «·œ›⁄    
            -5  «—ÌŒ «·«” Õﬁ«ﬁ    
            */    
            /*
            @VouchersType
            -1«·ﬂ·
            -2«·ÕÊ«·«  «·„’—›Ì… ›ﬁÿ
            -3«·ÕÊ«·«  €Ì— «·„’—›Ì… ›ﬁÿ
			*/   
			 SET NOCOUNT ON 
             
            DECLARE @Temp Table ( [Data] SQL_VARIANT)   
            INSERT INTO @Temp SELECT * FROM [dbo].[fnTextToRows]( @strState)   
               
            DECLARE @Str NVARCHAR(4000)     
            CREATE TABLE [#TransfersSourceTbl] ( [Guid] [UNIQUEIDENTIFIER], [UserSecurity] [INTEGER])     
            CREATE TABLE [#TransfersDestTbl] ( [Guid] [UNIQUEIDENTIFIER], [UserSecurity] [INTEGER])     
            INSERT INTO [#TransfersSourceTbl]EXEC [prcGetTransfersTypesList] @SourceRepGuid     
            INSERT INTO [#TransfersDestTbl]EXEC [prcGetTransfersTypesList]           @DestRepGuid     
            

            IF (@VouchersType = 1) -- 1«·ﬂ·
            BEGIN
            SET @Str = 'SELECT [vt].*, ''00000000-0000-0000-0000-000000000000'' AS BankGuid INTO #RES
                        FROM [vwTrnTransferVoucher] AS [vt] ' 
            END
            ELSE IF (@VouchersType = 2) -- «·ÕÊ«·«  «·„’—›Ì… ›ﬁÿ
            BEGIN
            SET @Str = 'SELECT [vt].*, BankGuid INTO #RES
                        FROM [vwTrnTransferVoucher] AS [vt] ' 
            END            
            ELSE					-- 3«·ÕÊ«·«  €Ì— «·„’—›Ì… ›ﬁÿ
            SET @Str = 'SELECT [vt].* INTO #RES
                                                            FROM [vwTrnTransferVoucher] AS [vt] ' 
			
			IF (@VouchersType <> 2) -- «·ﬂ· √Ê €Ì— «·„’—›Ì…
			BEGIN
            IF (@SourceRepGuid <> 0x0)
				SET @Str = @Str + ' INNER JOIN #TransfersSourceTbl AS srcBr ON srcBr.Guid = vt.TVSourceBranch '
				
			IF (@DestRepGuid <> 0x0)
                SET @Str = @Str + ' INNER JOIN #TransfersDestTbl AS dstBr ON dstBr.Guid = vt.TVDestinationBranch '
            END
            
            IF (@VouchersType = 2) -- «·„’—›Ì…
            BEGIN
				SET @Str = @Str + 'INNER JOIN TrnTransferBankOrder000 AS BankVoucher ON vt.TVBankOrderGuid = BankVoucher.Guid ' 
				SET @Str = @Str + 'INNER JOIN TrnBankAccountNumber000 as bankAccNum on BankVoucher.MediatorAccountNumberGuid = bankAccNum.guid ' 				
			END
           
            
            IF (@VouchersType = 1) -- «·ﬂ·
            BEGIN
				SET @Str = @Str + ' INSERT INTO #RES 				
					SELECT [vt].*, bankAccNum.BankGuid
					FROM [vwTrnTransferVoucher] AS [vt] 
					INNER JOIN TrnTransferBankOrder000 AS BankVoucher ON vt.TVBankOrderGuid = BankVoucher.Guid
					INNER JOIN TrnBankAccountNumber000 as bankAccNum on BankVoucher.MediatorAccountNumberGuid = bankAccNum.guid
				 ' 
			END			

			IF (@VouchersType = 2) -- «·„’—›Ì…
            BEGIN
				SET  @Str=@Str+' SELECT r.*,b.name as bankname FROM #RES r'
				SET @STR =@Str + ' INNER JOIN trnbank000  b on b.guid = bankguid '
			END
			ELSE
				SET  @Str=@Str+' SELECT r.* FROM #RES r'


			IF @StmType <> 0 
            BEGIN 
                            SET @Str = @Str + ' LEFT JOIN [vwTrnStatement] AS [vstm] ON (vstm.Guid = InStatementGuid) '      
                            SET @Str = @Str + ' LEFT JOIN [vwTrnStatementTypes] AS [vs] ON vs.ttGuid = vstm.TypeGUID ' 
                            SET @Str = @Str +  ' AND vstm.TypeGUID = ''' + CAST (@StmTypeGuid AS NVARCHAR(150)) +  '''' 
            END
			

			SET @Str = @Str + ' WHERE ' +      
            (CASE @DateType WHEN 1 THEN              '[TvDate]'     
                                                                            WHEN 2 THEN '[TvSendDate]'   
                                                                            WHEN 3 THEN '[TVNotifyDate]'                                                                            
                                                                            WHEN 4 THEN '[TvPayDate]'     
                                                                            WHEN 5 THEN '[TvDueDate]' END) +      
            ' BETWEEN ''' + CAST (@FromDate AS NVARCHAR(20)) +''' AND ''' + CAST(@ToDate AS NVARCHAR(20))+ ''''      

			SET @Str = @Str + ' AND TvState' +' IN (' + @strState + ')'   
			    IF 1 IN (SELECT * FROM @Temp)   
				SET @Str = @Str + ' AND TvCashed = 1'
            IF 2 IN (SELECT * FROM @Temp)   
                SET @Str = @Str + ' AND TvPaid = 1'   
            IF 10 IN (SELECT * FROM @Temp)   
                SET @Str = @Str + ' AND TvNotified = 1 '    
             

			  IF @BankGuid <> 0x0
                            SET @Str = @Str + ' AND Bankguid = ''' + CAST (@BankGuid AS NVARCHAR(1000)) + ''''

            DECLARE @NumberField NVARCHAR(32) 
             IF @UseStatementNo = 1  
				SET @NumberField = 'TVStatementNumber' 
            ELSE 
				SET @NumberField = 'TvNumber' 
               
               
            IF (@StmType <> 0 AND @StmNumber <> '') 
            BEGIN   
                SET @Str = @Str + ' AND ( InStatementCode = ''' +  @StmNumber + '''' 
                SET @Str = @Str + ' OR OutStatementCode = ''' +    @StmNumber + ''' ) ' 
            END 
           
            
            SET @Str = @Str + ' AND (TVFromStatement = ' + CAST (@FilterStatement AS NVARCHAR(10)) + ' OR ' + CAST (@FilterStatement AS NVARCHAR(10)) + ' = 2) '--All Transfers
            
            IF (@FilterBySrcDstType = 1 OR @FilterBySrcDstType = 3)--Src is branch
				SET @Str = @Str + ' AND TVSourceType = 1 '
			IF (@FilterBySrcDstType = 2 OR @FilterBySrcDstType = 3)--Dst is branch
				SET @Str = @Str + ' AND TVDestinationType = 1 ' 

			IF @Number <> ''                  
                            SET @Str = @Str + ' AND ' +  @NumberField + ' = ''' + @Number + ''''  

			 IF @FromNumber <> '' OR @ToNumber <> ''      
                            SET @Str = @Str + ' AND ' +  @NumberField + ' BETWEEN ''' + @FromNumber + ''' AND ''' + @ToNumber + '''' 

			IF @PhoneNumber <> ''  
            Begin  
                            Set @PhoneNumber =  '''%'  + @PhoneNumber +   '%''' 
				Set @Str = @Str + ' And ( SenderPhone1 like ' + @PhoneNumber + ' OR SenderPhone2 like ' + @PhoneNumber + ' OR RecPhone1 like ' +  @PhoneNumber + ' OR RecPhone2 like '+ @PhoneNumber + ' OR Rec2Phone1 like ' +  @PhoneNumber + ' OR Rec2Phone2 like ' +  @PhoneNumber + ' ) '
            End  
            IF @SenderName <> ''  
            BEGIN     
                            Set @SenderName =  '''%'  + @SenderName +  '%''' 
                SET @Str = @Str + ' AND [SenderName] LIKE ' +  @SenderName  
            END 
            IF @ReceiverName <> ''      
            BEGIN     
                            Set @ReceiverName =  '''%' + @ReceiverName +   '%''' 
                SET @Str = @Str + ' AND ([ReceivName] LIKE ' +  @ReceiverName + ' OR [Receiv2Name] LIKE ' +  @ReceiverName + ' ) '
            END 
            IF @CodeContains <> ''      
            BEGIN     
                            Set @CodeContains =  '''%' + @CodeContains +   '%''' 
                SET @Str = @Str + ' AND [TVCode] LIKE ' +  @CodeContains  
			END
			     
            IF @SortBy = 0  
				SET @Str = @Str + ' ORDER BY TvInternalNum '                
            IF @SortBy = 1  
                SET @Str = @Str + ' ORDER BY LEN(TvCode), TvCode '             
            IF @SortBy = 2  
                SET @Str = @Str + ' ORDER BY TvSourceBranch '              
            IF @SortBy = 3  
                SET @Str = @Str + ' ORDER BY TvDestinationBranch '    
            IF @SortBy = 4  
                SET @Str = @Str + ' ORDER BY TvDate '                                
            IF @SortBy = 5  
                SET @Str = @Str + ' ORDER BY TvDueDate '        
            IF @SortBy = 6  
                SET @Str = @Str + ' ORDER BY LEN(TvStatementNumber), TvStatementNumber '     
            IF @SortBy = 7  
				SET @Str = @Str + ' ORDER BY TvSendDate '      
            IF @SortBy = 8  
                SET @Str = @Str + ' ORDER BY SenderName '   
            IF @SortBy = 9  
                SET @Str = @Str + ' ORDER BY ReceivName '     
            IF @SortBy = 10  
                SET @Str = @Str + ' ORDER BY TvAmount '
        EXEC (@Str) 
#####################################################
#END