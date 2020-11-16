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

		
	IF (@State = 1)--������ ��� �����
		SET @ProcType = 2 --����� �������
		
	ELSE IF (@State = 0 AND @PrevState = 1)--����� ����� ��� ����� �������
		SET @ProcType = 3 --����� ����� �����
		
	ELSE IF (@State = 2 AND @PrevState = 0)--������ �� ������
		SET @ProcType = 4 --���
	
	ELSE IF (@State = 14)--������ �� ������ �����
		SET @ProcType = 2 --����� �������
		
	ELSE IF (@State = 2 AND @PrevState = 14)--������ �� ������ ��� ����� �������
		SET @ProcType = 3 --����� ����� �����
	
	ELSE IF (@State = 15)--�����
		SET @ProcType = 13 --�����
	
	ELSE IF (@State = 5)--����� ����� �� ������
		SET @ProcType = 6 --������������
		
	ELSE IF (@State = 16)--������
		SET @ProcType = 14 --���
		
	ELSE IF (@State = 10)--���� ���� ������
		SET @ProcType = 11 --�����
	
	ELSE IF (@State = 6)--����� ����� �� �������
		SET @ProcType = 9 --������ �������
	
	ELSE IF (@State = 17)--���� ���� ��������
		SET @ProcType = 11 --�����
	
	ELSE IF (@State = 7)--�� �������
		SET @ProcType = 7 --����� �������
	
	ELSE IF (@State = 18)--����� ������
		SET @ProcType = 8 --���
		
	ELSE IF (@State = 8)--������ �������
		SET @ProcType = 8 --���
		
	ELSE IF (@State = 13)--�����
		SET @ProcType = 12 --�����
		
	ELSE IF (@State = 19)--������ �����
		SET @ProcType = 15 --��� ����
	
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
