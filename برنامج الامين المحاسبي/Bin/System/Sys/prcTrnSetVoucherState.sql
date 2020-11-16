#######################################################################
CREATE PROCEDURE prcTrnSetVoucherState
	@VoucherGuid 	UNIQUEIDENTIFIER,
	@BranchGuid		UNIQUEIDENTIFIER
AS
	SET NOCOUNT ON
	DECLARE	@Number		INT,
			@State		INT,
			@PrevState  INT,
			@ProcType   INT,
			@CenterString NVARCHAR(100),
			@CenterGuid	UNIQUEIDENTIFIER 	

	SELECT 
		@Number = ISNULL(MAX(Number), 0) + 1
	FROM TrnVoucherproc000 
	WHERE VoucherGuid = @VoucherGuid
	
	SELECT 
		@State = State, 
		@PrevState = PreviousState
	FROM TrnTransferVoucher000 WHERE GUID = @VoucherGuid
		
	SELECT 
			@CenterString = VALUE 
	FROM op000 
	WHERE Name = 'TrnCfg_CurrentCenter'
		AND Computer = Host_Name()		
		
	IF (@CenterString IS NULL)
		SELECT @CenterGuid = 0x0
	ELSE	
		SELECT @CenterGuid = CAST(@CenterString AS UNIQUEIDENTIFIER)

		
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
##########################################################
#END
