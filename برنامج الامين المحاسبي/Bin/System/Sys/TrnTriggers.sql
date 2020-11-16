####################################################
CREATE TRIGGER trnStatementTypes000_CheckConstraints
	ON trnStatementTypes000 FOR INSERT, UPDATE, DELETE
	NOT FOR REPLICATION
AS
/*
This trigger checks:
	- not to delete used Statement templates.
	- not to use main accounts.
*/
	-- study a case when deletinf used bts:
	IF @@ROWCOUNT = 0 RETURN
	SET NOCOUNT ON	

	IF EXISTS(SELECT * FROM deleted AS d INNER JOIN trnStatement000 AS b ON d.[GUID] = b.[typeGUID]) AND NOT EXISTS(SELECT * FROM inserted)
	BEGIN
		RAISERROR('AmnE0450: Can''t delete Statement template, it''s being used ...', 16, 1)
		ROLLBACK TRANSACTION
		RETURN
	END

	IF EXISTS(
			SELECT *
			FROM inserted AS i INNER JOIN ac000 AS a ON 
				i.[SourceAcc] = a.[GUID] OR
				i.[DestAcc] = a.[GUID]
			WHERE a.[NSons] <> 0)
	BEGIN
		RAISERROR('AmnE0151: Can''t use main Accounts', 16, 1)
		ROLLBACK TRANSACTION
		RETURN
	END

#########################################################
CREATE TRIGGER trg_trnStatementTypes000_useFlag
	ON trnStatementTypes000 FOR INSERT, UPDATE, DELETE
	NOT FOR REPLICATION
AS
/*
This trigger:
  - updates UseFlag of concerned accounts.
*/
	IF @@ROWCOUNT = 0 RETURN
	SET NOCOUNT ON

	IF UPDATE([SourceAcc]) OR UPDATE([DestAcc])
	BEGIN
		IF EXISTS(SELECT * FROM deleted)
		BEGIN
			UPDATE ac000 SET [UseFlag] = [UseFlag] - 1 FROM ac000 AS a INNER JOIN deleted AS d ON a.[GUID] = d.[SourceAcc]
			UPDATE ac000 SET [UseFlag] = [UseFlag] - 1 FROM ac000 AS a INNER JOIN deleted AS d ON a.[GUID] = d.[DestAcc]
		END

		IF EXISTS(SELECT * FROM inserted)
		BEGIN
			UPDATE ac000 SET [UseFlag] = [UseFlag] + 1 FROM ac000 AS a INNER JOIN inserted AS i ON a.[GUID] = i.[SourceAcc]
			UPDATE ac000 SET [UseFlag] = [UseFlag] + 1 FROM ac000 AS a INNER JOIN inserted AS i ON a.[GUID] = i.[DestAcc]
		END
	END
#####################################################				
CREATE TRIGGER trg_wages_delete
ON [TrnWages000] FOR DELETE
NOT FOR REPLICATION
AS
	IF @@ROWCOUNT = 0 RETURN
	SET NOCOUNT ON	

IF NOT EXISTS (SELECT * FROM [inserted]) -- deleteing only 
BEGIN
	IF EXISTS ( SELECT * FROM [TrnTransferVoucher000] AS [t] INNER JOIN [deleted] AS d ON [t].[WagesTypeGUID] = [d].[GUID]) 
	BEGIN
		RAISERROR( 'AmnE0451: Can''t delete Wages template, it''s being used', 16, 1)
		ROLLBACK
		RETURN
	END
	
	
	
	DELETE [TrnWagesItem000] FROM [TrnWagesItem000] AS [t] INNER JOIN [deleted] AS [d]
		ON [t].[ParentGuid] = [d].[Guid]

END
#####################################################					
CREATE TRIGGER trg_TrnBranch_Check
ON [TrnBranch000] FOR INSERT, UPDATE
NOT FOR REPLICATION
AS
	IF @@ROWCOUNT = 0 RETURN
	SET NOCOUNT ON	

	IF EXISTS ( SELECT * FROM [TrnBranch000] AS [b] INNER JOIN [inserted] AS i 
			ON [b].[AmnBranchGUID] = [i].[AmnBranchGUID] WHERE [b].[GUID] <> [i].[GUID]) 
	BEGIN
		RAISERROR( 'AmnE0452: Ameen Branch it''s being used in another Transfers Branch..', 16, 1)
		ROLLBACK
		RETURN
	END
#####################################################	
CREATE TRIGGER trg_trnBranch_delete
ON [TrnBranch000] FOR DELETE
NOT FOR REPLICATION
AS
IF @@ROWCOUNT = 0 RETURN
SET NOCOUNT ON	

IF NOT EXISTS (SELECT * FROM [inserted]) -- deleteing only 
BEGIN
	IF EXISTS ( SELECT * FROM [TrnTransferVoucher000] AS [t] INNER JOIN [deleted] AS d ON [t].[SourceBranch] = [d].[AmnBranchGUID]) 
	BEGIN
		RAISERROR( 'AmnE0456: Can''t delete TrnBranch Card, it''s being used', 16, 1)
		ROLLBACK
		RETURN
	END
	IF EXISTS ( SELECT * FROM [TrnTransferVoucher000] AS [t] INNER JOIN [deleted] AS d ON [t].[DestinationBranch] = [d].[AmnBranchGUID]) 
	BEGIN
		RAISERROR( 'AmnE0456: Can''t delete TrnBranch Card, it''s being used', 16, 1)
		ROLLBACK
		RETURN
	END
END
#####################################################	
CREATE TRIGGER trg_trnratio_delete
ON [TrnRatio000] FOR DELETE
NOT FOR REPLICATION
AS
IF @@ROWCOUNT = 0 RETURN
SET NOCOUNT ON	

IF NOT EXISTS (SELECT * FROM [inserted]) -- deleteing only 
	IF EXISTS ( SELECT * FROM [TrnBranchsConfig000] AS [t] INNER JOIN [deleted] AS d ON [t].[RatioTypeGUID] = [d].[GUID]) 
	BEGIN
		RAISERROR( 'AmnE0454: Can''t delete Ratio template, it''s being used', 16, 1)
		ROLLBACK
		RETURN
	END
######################################################	
CREATE TRIGGER trg_trnsenderReceiver_delete
ON [TrnSenderReceiver000] FOR DELETE
NOT FOR REPLICATION
AS
IF @@ROWCOUNT = 0 RETURN
SET NOCOUNT ON	

IF NOT EXISTS (SELECT * FROM [inserted]) -- deleteing only 
BEGIN
	IF EXISTS ( SELECT * FROM [TrnTransferVoucher000] AS [t] INNER JOIN [deleted] AS d ON [t].[SenderGUID] = [d].[GUID]) 
	BEGIN
		RAISERROR( 'AmnE0455: Can''t delete Sender/Receiver Card , it''s being used', 16, 1)
		ROLLBACK
		RETURN
	END 
	IF EXISTS ( SELECT * FROM [TrnTransferVoucher000] AS [t] INNER JOIN [deleted] AS d ON [t].[Receiver1_GUID] = [d].[GUID]) 
	BEGIN
		RAISERROR( 'AmnE0455: Can''t delete Sender/Receiver Card , it''s being used', 16, 1)
		ROLLBACK
		RETURN
	END
	IF EXISTS ( SELECT * FROM [TrnTransferVoucher000] AS [t] INNER JOIN [deleted] AS d ON [t].[Receiver2_GUID] = [d].[GUID]) 
	BEGIN
		RAISERROR( 'AmnE0455: Can''t delete Sender/Receiver Card , it''s being used', 16, 1)
		ROLLBACK
		RETURN
	END
	IF EXISTS ( SELECT * FROM [TrnTransferVoucher000] AS [t] INNER JOIN [deleted] AS d ON [t].[Receiver3_GUID] = [d].[GUID]) 
	BEGIN
		RAISERROR( 'AmnE0455: Can''t delete Sender/Receiver Card , it''s being used', 16, 1)
		ROLLBACK
		RETURN
	END 
END	
######################################################	
CREATE TRIGGER trg_trnVoucher_delete
	ON [TrnTransferVoucher000] FOR DELETE 
	NOT FOR REPLICATION
AS 
	IF @@ROWCOUNT = 0 RETURN
	SET NOCOUNT ON	

	IF NOT EXISTS (SELECT * FROM [inserted]) -- deleteing only  
	BEGIN 	
		DECLARE @ce table (GUID uniqueidentifier)
		DECLARE @Voucher table (GUID UNIQUEIDENTIFIER)
		INSERT INTO @Voucher SELECT [GUID] FROM [deleted]
		INSERT INTO @ce SELECT [EntryGuid] FROM [er000] WHERE [ParentGUID] IN (SELECT GUID FROM @Voucher)
	
		UPDATE [Ce000] SET IsPosted = 0 WHERE [GUID] IN (SELECT GUID FROM @ce)
		DELETE FROM [Ce000] WHERE [GUID] IN (SELECT GUID FROM @ce)
				
		DELETE [TrnNotify000] FROM [TrnNotify000] AS [n] INNER JOIN [deleted] AS [d] ON [n].[VoucherGuid] = [d].[Guid] 
		DELETE [TrnVoucherPayInfo000] FROM [TrnVoucherPayInfo000] AS [p] INNER JOIN [deleted] AS [d] ON [p].[VoucherGuid] = [d].[Guid]  
		DELETE TransferCheckDetails000 FROM TransferCheckDetails000 AS tch INNER JOIN deleted AS d ON tch.ParentTransferGuid = d.GUID
	END
######################################################	
CREATE TRIGGER trg_trnCheckDetails_delete
	ON TransferCheckDetails000 FOR DELETE 
AS 
	IF @@ROWCOUNT = 0 RETURN
	SET NOCOUNT ON	
	IF NOT EXISTS (SELECT * FROM [inserted]) -- deleteing only  
	BEGIN 	
		DELETE ch000 FROM ch000 AS ch INNER JOIN deleted AS d ON ch.GUID = d.GUID
	END
######################################################	
CREATE TRIGGER trg_trnstatement_delete
ON [TrnStatement000] FOR DELETE
NOT FOR REPLICATION
AS
IF @@ROWCOUNT = 0 RETURN
SET NOCOUNT ON	

IF NOT EXISTS (SELECT * FROM [inserted]) -- deleteing only 
BEGIN
	DECLARE @Guid UNIQUEIDENTIFIER,
			@EntryGuid UNIQUEIDENTIFIER
			
	SELECT @Guid = GUID
	FROM [deleted]
	DELETE FROM TrnStatementItems000 WHERE ParentGUID = @Guid
	DELETE FROM er000 WHERE ParentGuid = @GUID

END
######################################################
CREATE TRIGGER trg_bnkstatement_delete
ON [TrnBankTrans000] FOR DELETE 
NOT FOR REPLICATION
AS
IF @@ROWCOUNT = 0 RETURN
SET NOCOUNT ON

IF NOT EXISTS (SELECT * FROM [inserted])
BEGIN
	DECLARE @Guid UNIQUEIDENTIFIER,
			@EntryGuid UNIQUEIDENTIFIER
			
	SELECT @Guid = GUID
	FROM [deleted]
	DELETE FROM er000 WHERE ParentGuid = @GUID

END
######################################################	
CREATE TRIGGER trg_br000_Trn_CheckConstraints
	ON br000 FOR INSERT, UPDATE, DELETE
	NOT FOR REPLICATION
AS
/* 
This trigger checks: 
	- not to delete used General Branches used in Transfer Branch
*/ 
	IF @@ROWCOUNT = 0 RETURN
	SET NOCOUNT ON	

	IF NOT EXISTS(SELECT * FROM inserted) 
	BEGIN 
		insert into ErrorLog (level, type, c1, g1) 
			select 1, 0, 'AmnE0457: card already used in Transfer Branch', d.guid 
			from TrnBranch000 AS T inner join deleted d on T.AmnBranchGuid = d.guid 

		insert into [ErrorLog] ([level], [type], [c1], [g1])
			select 1, 0, 'AmnE0084: card already used in Notification system .can''t delete card', d.[guid]
			from  NSGetBranchUse() fn  inner join [deleted] [d] ON [d].[guid] = [fn].[GUID]
	END

######################################################	
CREATE TRIGGER trg_br000_Trn_ChangeSecurity
	ON br000 FOR  UPDATE
	NOT FOR REPLICATION
AS 
	IF @@ROWCOUNT = 0 RETURN
	SET NOCOUNT ON	

	IF EXISTS (SELECT * FROM [deleted] AS [d] INNER JOIN [inserted] AS [i] ON [i].[Guid] = [d].[Guid] WHERE [i].[Security] <>  [d].[Security])
		UPDATE [br] SET   [Security] = [i].[Security] FROM  [TrnBranch000] AS [br] INNER JOIN [inserted] AS [i] ON [AmnBranchGUID] = [i].[Guid]
######################################################	
create  TRIGGER trg_TrnExchange_br 
		ON [TrnExchange000] FOR INSERT   
	AS  
		IF @@ROWCOUNT = 0 RETURN  

		SET NOCOUNT ON 
		DECLARE @defBranch [UNIQUEIDENTIFIER]  
		IF EXISTS(SELECT * FROM [inserted] WHERE ISNULL([BranchGuid], 0x0) = 0x0)  
		BEGIN  
			SET @defBranch = [dbo].[fnBranch_GetDefaultGuid]() 
			IF @defBranch IS NOT NULL  
				UPDATE [TrnExchange000] SET [BranchGuid] = @defBranch 
					FROM [TrnExchange000] AS [x] 
					INNER JOIN [inserted] AS [i] ON [x].[GUID] = [i].[GUID]
					WHERE ISNULL([i].[BranchGuid], 0x0) = 0x0
		END
##################################################
CREATE  TRIGGER trg_TrnCloseCashier_br
		ON [TrnCloseCashier000] FOR INSERT 
	AS  
		IF @@ROWCOUNT = 0 RETURN  

		SET NOCOUNT ON 
		DECLARE @defBranch [UNIQUEIDENTIFIER]  
		IF EXISTS(SELECT * FROM [inserted] WHERE ISNULL([BranchGuid], 0x0) = 0x0)  
		BEGIN  
			SET @defBranch = [dbo].[fnBranch_GetDefaultGuid]() 
			IF @defBranch IS NOT NULL  
				UPDATE [TrnCloseCashier000] SET [BranchGuid] = @defBranch 
					FROM [TrnCloseCashier000] AS [x] 
					INNER JOIN [inserted] AS [i] ON [x].[GUID] = [i].[GUID]
					WHERE ISNULL([i].[BranchGuid], 0x0) = 0x0
		END
##################################################		
CREATE TRIGGER trg_trnExchange000_DeleteEntry
	ON trnExchange000 FOR  Delete
	NOT FOR REPLICATION
AS 
	IF @@ROWCOUNT = 0 RETURN
	SET NOCOUNT ON	

	DECLARE @EntryGuid		 UNIQUEIDENTIFIER,
			@CancelEntryGuid UNIQUEIDENTIFIER,
			@guid			 UNIQUEIDENTIFIER 
	
	select	
		@guid		= guid, 
		@EntryGuid	= EntryGuid,
		@CancelEntryGuid = CancelEntryGuid
	from deleted 
	
	DELETE FROM trnExchangedetail000 WHERE ExchangeGuid = @guid
	
	UPDATE ce000 set isposted = 0 
	WHERE guid = @EntryGuid OR Guid = @CancelEntryGuid
	
	DELETE FROM er000 WHERE entryGuid = @EntryGuid OR entryGuid = @CancelEntryGuid
	DELETE FROM ce000 WHERE guid = @EntryGuid OR guid = @CancelEntryGuid
######################################################	
Create Trigger trgExchange_DeleteCurrencyClasses
ON TrnExchange000 For Delete 
NOT FOR REPLICATION
AS
 SET NOCOUNT ON
 DELETE CurClasses
 FROM TrnExchangeCurrClass000 AS CurClasses INNER JOIN deleted AS Ex
	ON ex.guid = CurClasses.parentguid
######################################################	
Create Trigger trgCloseCashier_DeleteDetails
ON [TrnCloseCashier000] For Delete 
NOT FOR REPLICATION
AS
 SET NOCOUNT ON
 DELETE [CloseDetails]
 FROM [TrnCloseCashierDetail000] AS CloseDetails INNER JOIN deleted AS Ex
	ON [Ex].[GUID] = [CloseDetails].[ParentGUID]
######################################################	
Create Trigger trgCloseCashier_DeleteEntry
ON [TrnCloseCashier000] For Delete 
NOT FOR REPLICATION
AS
	IF @@ROWCOUNT = 0 RETURN
	SET NOCOUNT ON	

	declare @guid uniqueidentifier 

	select @guid = EntryGuid 
	from deleted 

	update ce set isposted = 0 
	from ce000 as ce 
	where guid = @guid

	DELETE FROM ce000 WHERE guid = @guid
######################################################	
CREATE  TRIGGER trg_TrnDeposit_br
		ON [TrnDeposit000] FOR INSERT 
	AS  
		IF @@ROWCOUNT = 0 RETURN  

		SET NOCOUNT ON 
		DECLARE @defBranch [UNIQUEIDENTIFIER]  
		IF EXISTS(SELECT * FROM [inserted] WHERE ISNULL([BranchGuid], 0x0) = 0x0)  
		BEGIN  
			SET @defBranch = [dbo].[fnBranch_GetDefaultGuid]() 
			IF @defBranch IS NOT NULL  
				UPDATE [TrnDeposit000] SET [BranchGuid] = @defBranch 
					FROM [TrnDeposit000] AS [x] 
					INNER JOIN [inserted] AS [i] ON [x].[GUID] = [i].[GUID]
					WHERE ISNULL([i].[BranchGuid], 0x0) = 0x0
		END
##################################################		
Create Trigger trgTrnDeposit_DeleteEntry
ON [TrnDeposit000] For Delete 
NOT FOR REPLICATION
AS
	IF @@ROWCOUNT = 0 RETURN
	SET NOCOUNT ON	

	declare @guid uniqueidentifier 

	select @guid = EntryGuid 
	from deleted 

	update ce set isposted = 0 
	from ce000 as ce 
	where guid = @guid

	DELETE FROM ce000 WHERE guid = @guid
	DELETE FROM TrnDepositDetail000 WHERE ParentGuid = @guid
######################################################	
Create Trigger trgTrnAccountsEvl_DeleteDetails
ON [TrnAccountsEvl000] For Delete 
NOT FOR REPLICATION
AS
 SET NOCOUNT ON
 DELETE [AccEvlDetails]
 FROM [TrnAccountsEvlDetail000] AS AccEvlDetails INNER JOIN deleted AS Ex
	ON [Ex].[GUID] = [AccEvlDetails].[ParentGUID]
######################################################
Create Trigger trgTrnAccountsEvl_DeleteEntry
ON [TrnAccountsEvl000] For Delete 
NOT FOR REPLICATION
AS
	IF @@ROWCOUNT = 0 RETURN
	SET NOCOUNT ON	

	declare @guid uniqueidentifier 

	select @guid = EntryGuid 
	from deleted 

	update ce set isposted = 0 
	from ce000 as ce 
	where guid = @guid

	DELETE FROM ce000 WHERE guid = @guid	
######################################################
CREATE  TRIGGER trgTrnAccountsEvl_br
		ON [TrnAccountsEvl000] FOR INSERT 
	AS  
		IF @@ROWCOUNT = 0 RETURN  

		SET NOCOUNT ON 
		DECLARE @defBranch [UNIQUEIDENTIFIER]  
		IF EXISTS(SELECT * FROM [inserted] WHERE ISNULL([BranchGuid], 0x0) = 0x0)  
		BEGIN  
			SET @defBranch = [dbo].[fnBranch_GetDefaultGuid]() 
			IF @defBranch IS NOT NULL  
				UPDATE [TrnAccountsEvl000] SET [BranchGuid] = @defBranch 
					FROM [TrnAccountsEvl000] AS [x] 
					INNER JOIN [inserted] AS [i] ON [x].[GUID] = [i].[GUID]
					WHERE ISNULL([i].[BranchGuid], 0x0) = 0x0
		END
######################################################
CREATE  TRIGGER trgTrnVoucher_Insert
		ON TrnTransferVoucher000 FOR INSERT 
AS  
	IF @@ROWCOUNT = 0 RETURN 
	DECLARE @Number	INT,
			@CenterString NVARCHAR(100),
			@CenterGuid	UNIQUEIDENTIFIER,
			@BranchGuid UNIQUEIDENTIFIER
			
	SET @Number = (SELECT ISNULL(max(Vproc.number), 0) 
				   from TrnVoucherproc000 AS Vproc 
				   INNER JOIN inserted AS Voucher ON Vproc.VoucherGuid = Voucher.GUID) 
				   + 1

	SELECT @CenterString = [VALUE] FROM op000 WHERE Name = 'TrnCfg_CurrentCenter' AND Computer = Host_Name()		
	SELECT @CenterGuid = CAST(@CenterString AS UNIQUEIDENTIFIER)
	SELECT @BranchGuid = BranchGuid FROM TrnCenter000 WHERE GUID = @CenterGuid
	
	INSERT INTO TrnVoucherproc000
	(Number, VoucherGuid, Branch, [DateTime], StateBefore, StateAfter, ProcType, UserGuid, CenterGuid)
	SELECT
		@Number,
		GUID,
		@BranchGuid,
		GetDate(),
		-1,
		0,
		PayType,
		dbo.fnGetCurrentUserGuid(),
		@CenterGuid
		
	FROM
		inserted
######################################################
CREATE  TRIGGER trgTrnVoucher_UpdateState
		ON TrnTransferVoucher000 FOR UPDATE 
AS  
	IF @@ROWCOUNT = 0 RETURN 

	IF EXISTS (	SELECT * FROM [TrnStatementItems000] AS [s] INNER JOIN [inserted] AS [i] ON [s].[TransferVoucherGuid] = [i].[GUID])
	UPDATE [s] SET
		[s].DestinationBranch = [i].DestinationBranch
		FROM [TrnStatementItems000] AS [s] 
		INNER JOIN [inserted] AS [i] ON [s].[TransferVoucherGuid] = [i].[GUID]

	IF NOT EXISTS 
	(
		SELECT 
			* 
		FROM deleted AS d 
			INNER JOIN inserted AS i ON i.Guid = d.Guid AND (i.State <> d.State OR i.LockFlag <> d.LockFlag)
	)
		RETURN 

	DECLARE @Number		INT,
			@State		INT,
			@PrevState  INT,
			@ProcType   INT,
			@BranchGuid UNIQUEIDENTIFIER,
			@VoucherGuid UNIQUEIDENTIFIER,
			@CenterString NVARCHAR(100),
			@CenterGuid	UNIQUEIDENTIFIER,
			@NewLockFlag BIT,
			@OldLockFlag BIT
	
	SET @Number = (SELECT ISNULL(max(Vproc.number), 0) 
				   FROM TrnVoucherproc000 AS Vproc 
				   INNER JOIN inserted AS Voucher ON Vproc.VoucherGuid = Voucher.GUID) 
				   + 1
	SELECT 
		@State = i.[State], 
		@PrevState = d.[state],--i.PreviousState,
		@VoucherGuid = i.[GUID],
		@NewLockFlag = i.lockFlag,
		@OldLockFlag = d.lockFlag
	FROM inserted As i 
	INNER JOIN deleted AS d On i.GUID = d.GUID --AND (i.State <> d.State OR i.LockFlag <> d.LockFlag)
	

	IF (@State <> @PrevState)
	BEGIN
	IF (@State = 1)--„ÊﬁÊ›… ﬁ»· «·ﬁ»÷
		SET @ProcType = 2 --≈Ìﬁ«› «·ÕÊ«·…
		
	ELSE IF (@State = 0 AND @PrevState = 1)--ÃœÌœ… ‰ﬁœÌ… »⁄œ ≈⁄«œ… «· ›⁄Ì·
		SET @ProcType = 3 --≈⁄«œ…  ›⁄Ì· ÕÊ«·…
		
	ELSE IF (@State = 2 AND @PrevState = 0)--„ﬁ»Ê÷… „‰ «·„—”·
		SET @ProcType = 4 --ﬁ»÷
	
	ELSE IF (@State = 14)--„ÊﬁÊ›… „‰ «·„—”· „ƒﬁ «
		SET @ProcType = 2 --≈Ìﬁ«› «·ÕÊ«·…
		
	ELSE IF (@State = 2 AND @PrevState = 14)--„ﬁ»Ê÷… „‰ «·„—”· »⁄œ ≈⁄«œ… «· ›⁄Ì·
		SET @ProcType = 3 --≈⁄«œ…  ›⁄Ì· ÕÊ«·…
	
	ELSE IF (@State = 15)--„·€Ì…
		SET @ProcType = 13 --≈·€«¡
	
	ELSE IF (@State = 5)--„Ê«›ﬁ ⁄·ÌÂ« „‰ «·„—”·
		SET @ProcType = 6 --„Ê«›ﬁ…«·„—”·
		
	ELSE IF (@State = 16)--„—›Ê÷…
		SET @ProcType = 14 --—›÷
		
	ELSE IF (@State = 10)--„»·€ ⁄‰Â« ··„—”·
		SET @ProcType = 11 -- »·Ì€
	
	ELSE IF (@State = 6)--„Ê«›ﬁ ⁄·ÌÂ« „‰ «·„” ·„
		SET @ProcType = 9 --„Ê«›ﬁ… «·„” ·„
	
	ELSE IF (@State = 17)--„»·€ ⁄‰Â« ··„” ﬁ»·
		SET @ProcType = 11 -- »·Ì€
	
	ELSE IF (@State = 7)-- „ ≈—Ã«⁄Â«
		SET @ProcType = 7 --≈—Ã«⁄ «·„” ·„
	
	ELSE IF (@State = 18)--„⁄«œ… ··„—”·
		SET @ProcType = 8 --œ›⁄
		
	ELSE IF (@State = 8)--„œ›Ê⁄… ··„” ·„
		SET @ProcType = 8 --œ›⁄
		
	ELSE IF (@State = 13)--„ﬁ›·…
		SET @ProcType = 12 --≈ﬁ›«·
		
	ELSE IF (@State = 19)--„œ›Ê⁄… Ã“∆Ì«
		SET @ProcType = 15 --œ›⁄ œ›⁄…
	
	ELSE SET @ProcType = -1	--NO Proc		
	END
	
	ELSE 
	IF (@NewLockFlag <> @oldLockFlag)
	BEGIN
		IF (@NewLockFlag = 1)
			SET @ProcType = 16 --ﬁ›· «·ÕÊ«·…
		ELSE
			SET @ProcType = 17 --›ﬂ ﬁ›· «·ÕÊ«·…
	END
		
			
	
	SELECT @CenterString = [VALUE] FROM op000 WHERE Name = 'TrnCfg_CurrentCenter' AND Computer = Host_Name()		
	SELECT @CenterGuid = CAST(@CenterString AS UNIQUEIDENTIFIER)
	SELECT @BranchGuid = BranchGuid FROM TrnCenter000 WHERE GUID = @CenterGuid

	INSERT INTO TrnVoucherproc000
	(Number, VoucherGuid, Branch, [DateTime], StateBefore, StateAfter, ProcType, UserGuid, CenterGuid)
	VALUES
	(
		@Number,
		@VoucherGuid,
		@BranchGuid,
		GetDate(),
		@PrevState,
		@State,
		@ProcType,
		dbo.fnGetCurrentUserGuid(),
		@CenterString
	)
######################################################
CREATE  TRIGGER trg_TrnExchange_InternalNum 
	ON [TrnExchange000] FOR INSERT   
AS  
	IF @@ROWCOUNT = 0 RETURN  

	SET NOCOUNT ON 

	DECLARE @MaxExchangeInternalNumber INT,
		@MaxDetalExchangeInternalNumber INT
	SELECT 	@MaxExchangeInternalNumber = MAX(InternalNumber) FROM [TrnExchange000]
	SELECT	@MaxDetalExchangeInternalNumber = MAX(InternalNumber) FROM [TrnExchangeDetail000]	
	SET @MaxExchangeInternalNumber = ISNULL(@MaxExchangeInternalNumber, 0)
	SET @MaxDetalExchangeInternalNumber = ISNULL(@MaxDetalExchangeInternalNumber, 0)

	IF(@MaxDetalExchangeInternalNumber > @MaxExchangeInternalNumber)
		SET @MaxExchangeInternalNumber = @MaxDetalExchangeInternalNumber
	
	UPDATE [TrnExchange000] 
		SET [InternalNumber] = @MaxExchangeInternalNumber + 1
		FROM [TrnExchange000] AS [x] 
		INNER JOIN [inserted] AS [i] ON [x].[GUID] = [i].[GUID]
######################################################
CREATE  TRIGGER trg_TrnExchangeDetail_InternalNum 
	ON [TrnExchangeDetail000] FOR INSERT   
AS  
	IF @@ROWCOUNT = 0 RETURN  

	SET NOCOUNT ON 

	DECLARE @MaxExchangeInternalNumber INT,
		@MaxDetalExchangeInternalNumber INT
	SELECT 	@MaxExchangeInternalNumber = MAX(InternalNumber) FROM [TrnExchange000]
	SELECT	@MaxDetalExchangeInternalNumber = MAX(InternalNumber) FROM [TrnExchangeDetail000]	
	SET @MaxExchangeInternalNumber = ISNULL(@MaxExchangeInternalNumber, 0)
	SET @MaxDetalExchangeInternalNumber = ISNULL(@MaxDetalExchangeInternalNumber, 0)

	IF(@MaxDetalExchangeInternalNumber > @MaxExchangeInternalNumber)
		SET @MaxExchangeInternalNumber = @MaxDetalExchangeInternalNumber
	
	UPDATE [TrnExchangeDetail000] 
		SET [InternalNumber] = @MaxExchangeInternalNumber + 1
		FROM [TrnExchangeDetail000] AS [x] 
		INNER JOIN [inserted] AS [i] ON [x].[GUID] = [i].[GUID]
######################################################
#END

