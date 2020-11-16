#########################################################
CREATE VIEW vtTrnSenderReceiver
AS
	SELECT * FROM TrnSenderReceiver000

#########################################################
CREATE VIEW vcTrnSenderReceiver
AS
	SELECT * FROM vtTrnSenderReceiver

#########################################################
CREATE VIEW vdTrnSenderReceiver
AS
	SELECT * FROM vtTrnSenderReceiver

#########################################################
CREATE  VIEW vwTrnSenderReceiver
AS  
	SELECT  
		S.Number 			AS SRNumber,
		S.GUID 				AS SRGUID, 
		S.Name 				AS SRName, 
		S.FatherName 		AS SRFatherName, 
		S.LastName 			AS SRLastName, 
		S.MotherName		AS SRMotherName, 
		S.IdentityNo		AS SRIdentityNo, 
		S.IdentityType		AS SRIdentityType, 
		S.IdentityDate		AS SRIdentityDate, 
		S.Phone1 			AS SRPhone1, 
		S.Phone2 			AS SRPhone2, 
		S.Mobile			AS SRMobile, 
		S.Fax 				AS SRFax, 
		S.Address 			AS SRAddress, 
		S.Country 			AS SRCountry, 

		S.BranchGUID 		AS SRBranchGUID, 
		--br.[Name]			AS SRBranchName,
		S.Notes 			AS SRNotes, 
		S.EMail 			AS SREMail, 

		S.AccountGUID 		AS SRAccountGUID, 
		ISNULL( ac.acName, '')		AS SRAccountName, 
		S.Security 			AS SRSecurity, 
		S.branchMask 		AS SRbranchMask,
		S.Type				AS SRType
	FROM  
		vtTrnSenderReceiver AS S --INNER JOIN vtBr AS br On s.BranchGUID = br.GUID
		LEFT JOIN vwAc AS ac ON S.AccountGUID = ac.acGuid

#########################################################
CREATE FUNCTION fbTrnSenderReceiver
	( @Type AS INT)
	RETURNS TABLE
	AS
		RETURN (SELECT * FROM vcTrnSenderReceiver AS st WHERE st.Type = @Type)
#########################################################
CREATE FUNCTION fnTrnSenderReceiver
	(	@SenderOrreciever AS INT, --0 Sender, Else Reciever)
		@VoucherGuid AS UNIQUEIDENTIFIER = 0x0
	  )
	RETURNS @Result TABLE(
						Number INT, 
						GUID UNIQUEIDENTIFIER,
						Name NVARCHAR(255) COLLATE ARABIC_CI_AI, 
						phone1 NVARCHAR(255) COLLATE ARABIC_CI_AI
					 )
	AS
	BEGIN
		
		IF (ISNULL(@VoucherGuid, 0x0) = 0x0)
			INSERT INTO @Result
				SELECT [Number], [GUID], [Name], [phone1]
				FROM vcTrnSenderReceiver
			
		ELSE
		BEGIN
		
			Declare @Reciever2 UNIQUEIDENTIFIER,
					@UpdatedReciever1 UNIQUEIDENTIFIER,
					@UpdatedReciever2 UNIQUEIDENTIFIER
					
			Select @Reciever2 = ISNULL(Receiver2_GUID, 0x0) From TrnTransferVoucher000 WHERE GUID = @VoucherGuid
			Select @UpdatedReciever1 = ISNULL(UpdatedReciever1, 0x0) From TrnTransferVoucher000 WHERE GUID = @VoucherGuid
			Select @UpdatedReciever2 = ISNULL(UpdatedReciever2, 0x0) From TrnTransferVoucher000 WHERE GUID = @VoucherGuid
			
			IF (@SenderOrreciever = 0)
			BEGIN	
				 INSERT INTO @Result 
						SELECT sender.Number, sender.GUID, sender.Name, sender.phone1
						FROM vcTrnSenderReceiver AS sender 
						INNER JOIN TrnTransferVoucher000 AS V ON V.Guid = @VoucherGuid AND V.SenderGuid = sender.Guid
			END
			
			ELSE
			BEGIN
				 INSERT INTO @Result
						SELECT reciever1.Number, reciever1.GUID, reciever1.Name, reciever1.phone1 
						FROM TrnTransferVoucher000 AS V
						INNER JOIN vcTrnSenderReceiver AS reciever1 ON V.Guid = @VoucherGuid AND V.Receiver1_GUID = reciever1.Guid
				
				 IF (@Reciever2 <> 0x0)
				 BEGIN
					INSERT INTO @Result
						SELECT reciever2.Number, reciever2.GUID, reciever2.Name, reciever2.phone1 
						FROM TrnTransferVoucher000 AS V
						INNER JOIN vcTrnSenderReceiver AS reciever2 ON V.Guid = @VoucherGuid AND V.Receiver2_GUID = reciever2.Guid	
				 END
				 
				 IF (@UpdatedReciever1 <> 0x0)
				 BEGIN
					INSERT INTO @Result
						SELECT Updatedreciever1.Number, Updatedreciever1.GUID, Updatedreciever1.Name, Updatedreciever1.phone1 
						FROM TrnTransferVoucher000 AS V
						INNER JOIN vcTrnSenderReceiver AS Updatedreciever1 ON V.Guid = @VoucherGuid AND V.UpdatedReciever1 = Updatedreciever1.Guid	
				 END
				 
				 IF (@UpdatedReciever2 <> 0x0)
				 BEGIN
					INSERT INTO @Result
						SELECT Updatedreciever2.Number, Updatedreciever2.GUID, Updatedreciever2.Name, Updatedreciever2.phone1 
						FROM TrnTransferVoucher000 AS V
						INNER JOIN vcTrnSenderReceiver AS Updatedreciever2 ON V.Guid = @VoucherGuid AND V.UpdatedReciever2 = Updatedreciever2.Guid	
				 END
				 
				 IF ( (SELECT COUNT(*) FROM TrnVoucherPayeds000 WHERE ParentGuid = @VoucherGuid) <> 0)
				 BEGIN
					INSERT INTO @Result
						SELECT PARTPAYEDREC.Number, PARTPAYEDREC.GUID, PARTPAYEDREC.Name, PARTPAYEDREC.phone1 
						FROM TrnVoucherPayeds000 AS V
						INNER JOIN vcTrnSenderReceiver AS PARTPAYEDREC ON V.ParentGuid = @VoucherGuid AND V.RecieverGuid = PARTPAYEDREC.Guid		
				 END				
			END -- END ELSE IF (@SenderOrreciever = 0)
			
		END--  END ELSE IF (ISNULL(@VoucherGuid, 0x0) = 0x0)
		
		RETURN
	END
#########################################################
#END