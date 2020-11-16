#########################################
CREATE FUNCTION fnVwSenderReceiver ( @BranchGUID UNIQUEIDENTIFIER)
RETURNS TABLE
AS 
	RETURN
		SELECT
			Number, 
			GUID, 
			Name, 
			MotherName, 
			IdentityNo, 
			IdentityType, 
			IdentityDate, 
			Phone1, 
			Phone2, 
			Fax, 
			Address, 
			Country, 
			BranchGUID, 
			Notes, 
			EMail, 
			AccountGUID, 
			Security
		FROM
			TrnSenderReceiver000
		WHERE 
			BranchGUID = @BranchGUID
#########################################
CREATE  FUNCTION fnTrnGetSenders
		(
			@BranhGuid        UNIQUEIDENTIFIER,
			@Name		      NVARCHAR(100),
			@IdentityNo       NVARCHAR(100),
			@Mobile		      NVARCHAR(100),
			@Phone		      NVARCHAR(100),
			@Country	      NVARCHAR(100),
			@SenderOrReceiver INT -- 0 All , 1 Sender, 2 Receiver
		)
RETURNS TABLE 
AS
	RETURN(
			 SELECT * 

			 FROM 	VwTrnSenderReceiver

			 WHERE 
			 	    ((@SenderOrReceiver = 1 OR @SenderOrReceiver = 0) AND SRGUID IN (SELECT SenderGUID     FROM TrnTransferVoucher000))
				 OR ((@SenderOrReceiver = 2 OR @SenderOrReceiver = 0) AND SRGUID IN (SELECT Receiver1_GUID FROM TrnTransferVoucher000))
				 OR ((@SenderOrReceiver = 2 OR @SenderOrReceiver = 0) AND SRGUID IN (SELECT Receiver2_GUID FROM TrnTransferVoucher000))
				AND	(@BranhGuid = 0x0 OR @BranhGuid = SRBranchGuid) 
				AND  [SRname]		LIKE '%' + @Name	   + '%'  
				AND  [SRIdentityNo] LIKE '%' + @IdentityNo + '%' 
				AND  [SRMobile]		LIKE '%' + @Mobile	   + '%' 
				AND ([SRPhone1]		LIKE '%' + @Phone	   + '%' OR [SRPhone2] LIKE '%' + @Phone + '%')
				AND  [SRCountry]	LIKE '%' + @Country	   + '%'
		  )
##############################################################
CREATE  FUNCTION fnTrnGetSendResVoucher
		(
			@SenderResGuid UNIQUEIDENTIFIER,
			@SenderState INT = 2--0 All, 1 sender, 2 Receivs
		)

RETURNS @Result TABLE (TVGuid uniqueidentifier, TVCode NVARCHAR(200),
			TVAmount FLOAT, CurrencyName  NVARCHAR(200),
			TVDate DateTime, [DueDate] DateTime,
			SourcBranchName  NVARCHAR(200), DestBranchName  NVARCHAR(200),
			SenderName  NVARCHAR(200), ReceivName  NVARCHAR(200), TVState INT) 
AS
BEGIN
	insert into @Result
	SELECT  
		TVGuid,
		TVCode,
		TVAmount,
		CurrencyName,
		TVDate,
		TVDueDate,
		SourcBranchName,
		DestBranchName,
		SenderName,
		ReceivName,
		TVState
	From 	vwTrnTransferVoucher
	Where 
		(@SenderState = 1 AND TVSenderGUID = @SenderResGuid)
		OR 
		(@SenderState = 2 AND (
			@SenderResGuid = TVReceiver1_Guid 
			OR 
			@SenderResGuid = TVReceiver2_Guid 
			OR 
			@SenderResGuid = TVReceiver3_Guid
			OR
			@SenderResGuid = TVUpdatedReciever1 
			OR
			@SenderResGuid = TVUpdatedReciever2 )
		)
		OR
		(@SenderState = 0 AND(
			TVSenderGUID = @SenderResGuid
			OR 
			@SenderResGuid = TVReceiver1_Guid 
			OR 
			@SenderResGuid = TVReceiver2_Guid 
			OR 
			@SenderResGuid = TVReceiver3_Guid 
			OR
			@SenderResGuid = TVUpdatedReciever1 
			OR
			@SenderResGuid = TVUpdatedReciever2 )
		)
		ORDER BY [TVDate] , TVCode
	RETURN
END
#####################################################################
CREATE FUNCTION fnTrnFindTransferBankOrder
	(
		@PayeeBankName			VARCHAR(250)
		,@PayeeBankSwift		VARCHAR(250)
		,@PayeeBankAddress		VARCHAR(250)
		,@PayeeAccountNumber	VARCHAR(250)
		,@PayeeIBAN				VARCHAR(250)
		,@PayeeGuid				UNIQUEIDENTIFIER
		,@SenderGuid			UNIQUEIDENTIFIER
		,@MediatorAccountNumberGuid	UNIQUEIDENTIFIER
	)
RETURNS TABLE 
AS
RETURN
(
	SELECT 
		*
	FROM 	
		TrnTransferBankOrder000
	WHERE 
		PayeeBankName = @PayeeBankName	
		AND
		PayeeBankSwift	= @PayeeBankSwift	
		AND 
		PayeeBankAddress = @PayeeBankAddress	
		AND
		PayeeAccountNumber = @PayeeAccountNumber	
		AND
		PayeeIBAN = @PayeeIBAN			
		AND
		PayeeGuid = @PayeeGuid
		AND 
		SenderGuid = @SenderGuid
		AND
		@MediatorAccountNumberGuid = MediatorAccountNumberGuid
)
#####################################################################
CREATE PROCEDURE IsTrnSenderOrReceiverFound
	@Name			VARCHAR(250) = '', 
	@Phone			VARCHAR(250) = '', 
	@MotherName		VARCHAR(250) = '', 
	@Address		VARCHAR(250) = '', 
	@Nation			VARCHAR(250) ='', 
	@IdentityType	VARCHAR(250) = '', 
	@IdentityNumber VARCHAR(250) = '', 
	@FatherName		VARCHAR(250) = '', 
	@LastName		VARCHAR(250) = '',
	@DocumentExpiryDate	DATETIME = '1980-01-01',
	@IdentityDate		DATETIME = '1980-01-01'
AS 
	SET NOCOUNT ON 
	DECLARE @Guid UNIQUEIDENTIFIER = NULL 
	SELECT TOP 1
		@Guid = GUID  
	FROM TrnSenderReceiver000  
	WHERE  
		Name = @Name  
		AND (phone1 IN(@Phone, '') OR @phone = '')
		AND (MotherName IN(@MotherName, '') OR @MotherName = '')
		AND (FatherName IN(@FatherName, '') OR @FatherName = '')
		AND (LastName IN(@LastName, '') OR @LastName = '')
		--AND [Address] = @Address 
		--AND nation = @Nation 
		--AND IdentityType = @IdentityType 
		AND (IdentityNo in(@IdentityNumber, '') OR @IdentityNumber = '')
		--AND DocumentExpiryDate = @DocumentExpiryDate

	Update TrnSenderReceiver000
	SET 
		MotherName = CASE @MotherName WHEN '' THEN MotherName ELSE @MotherName END,
		FatherName = CASE @FatherName WHEN '' THEN FatherName ELSE @FatherName END ,
		LastName   = CASE @LastName WHEN '' THEN LastName ELSE @LastName END,
		[Address] =	 CASE @Address WHEN '' THEN [Address] ELSE @Address END,
		Nation =	 CASE @Nation WHEN '' THEN Nation ELSE @Nation END,
		IdentityType = CASE @IdentityType WHEN '' THEN IdentityType ELSE @IdentityType END,
		IdentityNo =   CASE @IdentityNumber WHEN '' THEN IdentityNo ELSE @IdentityNumber END,
		DocumentExpiryDate = CASE @DocumentExpiryDate WHEN '' THEN DocumentExpiryDate ELSE @DocumentExpiryDate END,
		IdentityDate = CASE @IdentityDate WHEN '' THEN IdentityDate ELSE @IdentityDate END
	WHERE GUID = @Guid
	 
	SELECT ISNULL(@guid, 0x0) AS SenderReceiverGuid
#####################################################################
#END
