###############################################
CREATE FUNCTION fnGetTrnStatementTypesList ( 
	@SrcGuid UNIQUEIDENTIFIER = 0x0, 
	@UserGUID UNIQUEIDENTIFIER = 0x0) 
	RETURNS @Result TABLE( GUID UNIQUEIDENTIFIER, Security INT) 
AS 
BEGIN 
	IF ISNULL(@UserGUID, 0x0) = 0x0 
		SET @UserGUID = dbo.fnGetCurrentUserGUID() 
/*	IF ISNULL(@SrcGuid, 0x0)= 0x0 
		INSERT INTO @Result 
			SELECT 
					ttGUID, 
					BrowseSec, 
					ReadPriceSec 
				FROM 
					dbo.fnGetUserBillsSec( @UserGUID ) AS fn 
					INNER JOIN vwTrnTransferTypes AS b ON fn.GUID = b.ttGUID 
	ELSE */
		INSERT INTO @Result 
			SELECT 
					IdType, 
					1 --dbo.fnGetUserBillSec_Browse(@UserGUID, IdType), 
				FROM 
					dbo.RepSrcs AS r  
					INNER JOIN vwTrnStatementTypes AS b ON r.IdType = b.ttGUID 
				WHERE 
					IdTbl = @SrcGuid 
	RETURN 
END 
#####################################################
CREATE FUNCTION fnTrnOutStatement_FilterVoucher
	(
		@SourceBranch			UNIQUEIDENTIFIER
		,@DestinationOffice		UNIQUEIDENTIFIER
		,@FromDate				DATETIME
		,@ToDate				DATETIME
		,@DestinationGuid		UNIQUEIDENTIFIER = 0x0
		,@senderNameContains	NVARCHAR(250) = ''
		,@receiverNameContains	NVARCHAR(250) = ''

	)
RETURNS TABLE 
AS
RETURN
	(
		SELECT 
			--vr.[Guid]
			--,vr.[Date]
			vr.*
		FROM 
			Trntransfervoucher000 AS vr
			INNER JOIN TrnSenderReceiver000 AS sender ON  vr.SenderGUId = sender.[GUID]
			INNER JOIN TrnSenderReceiver000 rec ON vr.Receiver1_GUID = rec.[GUID]
		WHERE
			vr.[State] = 20 -- execute by office
			AND vr.OutStatementGuid = 0x0
			AND vr.DestinationType = 2
			AND vr.DestinationBranch = @DestinationOffice		
			AND (@senderNameContains = '' OR sender.[Name] = @senderNameContains)
			AND (@receiverNameContains = '' OR rec.[Name] = @receiverNameContains)
			AND (vr.[Date] BETWEEN @FromDate AND @ToDate)
			AND (@DestinationGuid = 0x0 OR vr.DestinationGuid = @DestinationGuid)
			--AND (
			--		(vr.SourceType = 1 AND vr.SourceBranch = @SourceBranch)
			--		OR
			--		(vr.SourceType = 2 AND vr.AgentBranch = @SourceBranch)
			--	)	
	)	
#####################################################
CREATE FUNCTION fnTrnInPayStatement_FilterVoucher
	(
		@SourceOffice			UNIQUEIDENTIFIER
		,@DestinationBranch		UNIQUEIDENTIFIER
		,@FromDate				DATETIME
		,@ToDate				DATETIME
		,@DestinationGuid		UNIQUEIDENTIFIER = 0x0
		,@senderNameContains	NVARCHAR(250) = ''
		,@receiverNameContains	NVARCHAR(250) = ''
	)
RETURNS TABLE 
AS
RETURN
	(
		SELECT 
			--vr.[Guid] 
			--,vr.[Date] 
			vr.*
		FROM 
			Trntransfervoucher000 AS vr
			INNER JOIN TrnSenderReceiver000 AS sender ON  vr.SenderGUId = sender.[GUID]
			INNER JOIN TrnSenderReceiver000 rec ON vr.Receiver1_GUID = rec.[GUID]
			INNER JOIN TrnStatement000 Stm ON Stm.[GUID] = vr.StatementGUID 
			INNER JOIN TrnStatementTypes000 StmType ON StmType.[GUID] = Stm.TypeGUID 
		WHERE
			
			vr.StatementGuid <> 0x0 
			--AND SourceType = 2
			--AND vr.SourceBranch = stm.OfficeGuid
			--AND vr.SourceBranch = @SourceOffice
			AND(
					vr.[State] = 7 -- returned
					OR 
					(vr.DestinationType = 2 AND vr.[State] = 20) -- execute by office
					OR
					(vr.DestinationType = 1 AND vr.[State] = 8) -- paied by reciever
			)	
			
			AND (@senderNameContains = '' OR sender.[Name] = @senderNameContains)
			AND (@receiverNameContains = '' OR rec.[Name] = @receiverNameContains)
			AND (vr.[Date] BETWEEN @FromDate AND @ToDate)
			AND (@DestinationGuid = 0x0 OR vr.DestinationGuid = @DestinationGuid)
			--AND (
			--		(vr.DestinationType = 1 AND vr.DestinationBranch = @DestinationBranch)
			--		OR
			--		(vr.SourceType = 2 AND vr.AgentBranch = @DestinationBranch)
			--	)	
	)		
#####################################################
CREATE FUNCTION FnGetTransferBankOrders
	(  
		@ReceiverName			NVARCHAR(255) = '',
		@ReceiverPhone			NVARCHAR(255) = '',
		@ReceiverAccountNumber	NVARCHAR(255) ='',
		@PayeeBankName			NVARCHAR(255) = '',
		@PayeeBankBranchName	NVARCHAR(255) = '',
		@PayeeBankSWIFT			NVARCHAR(255) = '',
		@MediatorBankSWIFT		NVARCHAR(255) = '',
		@MediatorBankName		NVARCHAR(255) = '',
		@MediatorBankAccountNumber NVARCHAR(255) = '',
		@SenderName				NVARCHAR(255) = '',
		@SenderPhone			NVARCHAR(255) = '',
		@SenderAddress			NVARCHAR(255) = '',
		@GeneralParameter		NVARCHAR(255) = ''--This parameter contains one parameter or more of: @ReceiverName, @ReceiverAccountNumber, @MediatorBankName, @MediatorBankSWIFT, @SenderName
      ) 
	RETURNS TABLE 
    AS 
		RETURN 
		(
            SELECT
				
				BankOrder.[Guid] AS BankOrderGuid,
				
				Payee.Name PayeeName,
				Payee.Phone1 PayeePhone,
				BankOrder.PayeeBankName,
				BankOrder.PayeeBankSWIFT,
				BankOrder.PayeeBankBranch,
				BankOrder.PayeeAccountNumber PayeeBankAccountNumber,

				Sender.Name SenderName,
				Sender.[Address] SenderAddress,
				Sender.Phone1 SenderPhone,
				
				ISNULL(MediratorBank.Name, '') MediratorBankName,
				ISNULL(MediratorBank.SWIFT, '') MediratorBankSWIFT,
				ISNULL(BankAccountNumber.Number, '') MediratorBankAccountNumber
				
            FROM 
				TrnTransferBankOrder000 BankOrder
				INNER JOIN TrnSenderReceiver000 Payee ON BankOrder.PayeeGuid = payee.[Guid]
				INNER JOIN TrnSenderReceiver000 Sender ON BankOrder.SenderGuid = Sender.[Guid]
				LEFT JOIN TrnBankAccountNumber000 BankAccountNumber ON BankOrder.MediatorAccountNumberGuid = BankAccountNumber.[Guid]
				--INNER JOIN TrnTransferVoucher000 [Transfer] ON [Transfer].BankOrderGuid = BankOrder.[Guid]
				LEFT JOIN TrnBank000 MediratorBank ON BankAccountNumber.BankGuid = MediratorBank.[Guid]
            
            WHERE
				(
					@ReceiverName = ''
					OR 
					Payee.Name LIKE '%' + @ReceiverName + '%' 
				)				
				
				AND
				(
					@ReceiverPhone = ''
					OR 
					Payee.Phone1 LIKE '%' + @ReceiverPhone + '%' 
				)				
				
				AND
				(
					@ReceiverAccountNumber = ''
					OR 
					BankOrder.PayeeAccountNumber LIKE '%' + @ReceiverAccountNumber + '%' 
				)				

				AND
				(
					@MediatorBankName = ''
					OR 
					MediratorBank.[Name] LIKE '%' + @MediatorBankName + '%' 
				)				

				AND
				(
					@MediatorBankSWIFT = ''
					OR 
					MediratorBank.SWIFT LIKE '%' + @MediatorBankSWIFT + '%' 
				)								

				AND
				(
					@MediatorBankAccountNumber = ''
					OR 
					BankAccountNumber.Number LIKE '%' + @MediatorBankAccountNumber + '%' 
				)								
				
				AND
				(
					@PayeeBankName = ''
					OR 
					BankOrder.PayeeBankName LIKE '%' + @PayeeBankName + '%' 
				)								
				
				AND
				(
					@PayeeBankSWIFT = ''
					OR 
					BankOrder.PayeeBankSWIFT LIKE '%' + @PayeeBankSWIFT + '%' 
				)																													
			
				AND
				(
					@PayeeBankBranchName = ''
					OR 
					BankOrder.PayeeBankBranch LIKE '%' + @PayeeBankBranchName + '%' 
				)	

				AND
				(
					@SenderName = ''
					OR 
					Sender.Name LIKE '%' + @SenderName + '%' 
				)	
					
				AND
				(
					@SenderAddress = ''
					OR 
					Sender.[Address] LIKE '%' + @SenderAddress + '%' 
				)						
				
				AND
				(
					@SenderPhone = ''
					OR 
					Sender.Phone1 LIKE '%' + @SenderPhone + '%' 
				)						
				
				AND
				(
					@GeneralParameter = ''
					OR 
					@GeneralParameter LIKE '%' + Payee.name + '%' 
					OR 
					@GeneralParameter LIKE '%' + BankOrder.PayeeAccountNumber + '%' 
					OR 
					@GeneralParameter LIKE '%' + BankOrder.PayeeBankName + '%' 
					OR 
					@GeneralParameter LIKE '%' + BankOrder.PayeeBankSWIFT + '%' 
					OR 
					@GeneralParameter LIKE '%' + Sender.Name + '%' 
				)	
		)
#####################################################
#END
