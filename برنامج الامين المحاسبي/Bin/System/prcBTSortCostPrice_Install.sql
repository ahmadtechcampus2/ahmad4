#########################################################
CREATE PROC prcBTSortCostPrice_Install 
	@Refill BIT = 0
AS
	SET NOCOUNT ON

	IF EXISTS(SELECT * FROM BTSortCostPrice000) AND @Refill = 0
		RETURN 

	-- BTType	BTBillType	BTSortNum			BTIsInput		Desc				DefaultSort		IsRelated	RelationType
	-- 3		4			-					1				��. �����			1				1			0
	-- 3		5			-					0				��. �����			1				1			0
	-- 2		-			1					1				����� ��� ���		2				0			-
	-- 6		4			-					1				������ ����			3				0			-
	-- 1		0			-					1				����				4				0			-
	-- 1		2			-					0				�.����				5				0			-
	-- 1		4			-					1				����� ������		6				0			-
	-- 2		-			5					1				����� ���� �����	7				0			-
	-- 10		-			-					1				����� - �����		8				0			-
	-- 9		-			-					1				����� - �����		9				0			-
	-- 2		-			8					0				����� ����			10				1			1
	-- 2		-			7					1				����� ����			10				1			1
	-- 2		-			4					0				����� ������		11				1			2
	-- 2		-			3					1				����� ������		11				1			2
	-- 3		0			-					0				��.������			12				1			3
	-- 4		0			-					1				��.������			12				1			3
	-- 5		5			-					0				������ ���			13				0			-
	-- 1		1			-					0				������				14				0			-
	-- 1		3			-					1				�.������			15				0			-
	-- 1		5			-					0				����� ������		16				0			-
	-- 2		-			2					0				��.���� �����		17				0			-
	-- 9		-			0					0				����� - �����		18				0			-
	-- 10		-			0 					0				����� - �����		19				0			-


	IF @Refill = 1
		DELETE BTSortCostPrice000

	DECLARE @num INT 
	SET @num = 1
	-- ����� ����� 
	INSERT INTO BTSortCostPrice000 ([GUID], Number, [RecordID], [BTType], BTBillType, BTSortNum, BTIsInput, ActualSort, DefaultSort, IsRelated, RelationType)
	SELECT NEWID(), @num, 1/*RecordID*/, 3/*Type*/, 4/*BillType*/, 0/*SortNum*/, 1/*BTIsInput*/, 1, 1, 1, 0
	SET @num = @num + 1

	-- ����� �����
	INSERT INTO BTSortCostPrice000 ([GUID], Number, [RecordID], [BTType], BTBillType, BTSortNum, BTIsInput, ActualSort, DefaultSort, IsRelated, RelationType)
	SELECT NEWID(), @num, 1/*RecordID*/, 3/*Type*/, 5/*BillType*/, 0/*SortNum*/, 0/*BTIsInput*/, 1, 1, 1, 0
	SET @num = @num + 1

	-- ����� ��� ���
	INSERT INTO BTSortCostPrice000 ([GUID], Number, [RecordID], [BTType], BTBillType, BTSortNum, BTIsInput, ActualSort, DefaultSort, IsRelated, RelationType)
	SELECT NEWID(), @num, 2/*RecordID*/, 2/*Type*/, 4/*BillType*/, 1/*SortNum*/, 1/*BTIsInput*/, 2, 2, 0, -1
	SET @num = @num + 1

	-- ������ ����
	INSERT INTO BTSortCostPrice000 ([GUID], Number, [RecordID], [BTType], BTBillType, BTSortNum, BTIsInput, ActualSort, DefaultSort, IsRelated, RelationType)
	SELECT NEWID(), @num, 3/*RecordID*/, 6/*Type*/, 4/*BillType*/, 0/*SortNum*/, 1/*BTIsInput*/, 3, 3, 0, -1
	SET @num = @num + 1

	-- ����
	INSERT INTO BTSortCostPrice000 ([GUID], Number, [RecordID], [BTType], BTBillType, BTSortNum, BTIsInput, ActualSort, DefaultSort, IsRelated, RelationType)
	SELECT NEWID(), @num, 4/*RecordID*/, 1/*Type*/, 0/*BillType*/, 0/*SortNum*/, 1/*BTIsInput*/, 4, 4, 0, -1
	SET @num = @num + 1

	-- �.����
	INSERT INTO BTSortCostPrice000 ([GUID], Number, [RecordID], [BTType], BTBillType, BTSortNum, BTIsInput, ActualSort, DefaultSort, IsRelated, RelationType)
	SELECT NEWID(), @num, 5/*RecordID*/, 1/*Type*/, 2/*BillType*/, 0/*SortNum*/, 0/*BTIsInput*/, 5, 5, 0, -1
	SET @num = @num + 1

	-- ����� ������
	INSERT INTO BTSortCostPrice000 ([GUID], Number, [RecordID], [BTType], BTBillType, BTSortNum, BTIsInput, ActualSort, DefaultSort, IsRelated, RelationType)
	SELECT NEWID(), @num, 6/*RecordID*/, 1/*Type*/, 4/*BillType*/, 0/*SortNum*/, 1/*BTIsInput*/, 6, 6, 0, -1
	SET @num = @num + 1

	-- ����� ���� �����
	INSERT INTO BTSortCostPrice000 ([GUID], Number, [RecordID], [BTType], BTBillType, BTSortNum, BTIsInput, ActualSort, DefaultSort, IsRelated, RelationType)
	SELECT NEWID(), @num, 7/*RecordID*/, 2/*Type*/, 4/*BillType*/, 5/*SortNum*/, 1/*BTIsInput*/, 7, 7, 0, -1
	SET @num = @num + 1

	-- ����� - �����
	INSERT INTO BTSortCostPrice000 ([GUID], Number, [RecordID], [BTType], BTBillType, BTSortNum, BTIsInput, ActualSort, DefaultSort, IsRelated, RelationType)
	SELECT NEWID(), @num, 8/*RecordID*/, 10/*Type*/, 0/*BillType*/, 0/*SortNum*/, 1/*BTIsInput*/, 8, 8, 0, -1
	SET @num = @num + 1

	-- ����� - �����
	INSERT INTO BTSortCostPrice000 ([GUID], Number, [RecordID], [BTType], BTBillType, BTSortNum, BTIsInput, ActualSort, DefaultSort, IsRelated, RelationType)
	SELECT NEWID(), @num, 9/*RecordID*/, 9/*Type*/, 0/*BillType*/, 0/*SortNum*/, 1/*BTIsInput*/, 9, 9, 0, -1
	SET @num = @num + 1

	-- ����� ����
	INSERT INTO BTSortCostPrice000 ([GUID], Number, [RecordID], [BTType], BTBillType, BTSortNum, BTIsInput, ActualSort, DefaultSort, IsRelated, RelationType)
	SELECT NEWID(), @num, 10/*RecordID*/, 2/*Type*/, 5/*BillType*/, 8/*SortNum*/, 0/*BTIsInput*/, 10, 10, 1, 1
	SET @num = @num + 1

	-- ����� ����
	INSERT INTO BTSortCostPrice000 ([GUID], Number, [RecordID], [BTType], BTBillType, BTSortNum, BTIsInput, ActualSort, DefaultSort, IsRelated, RelationType)
	SELECT NEWID(), @num, 10/*RecordID*/, 2/*Type*/, 4/*BillType*/, 7/*SortNum*/, 1/*BTIsInput*/, 10, 10, 1, 1
	SET @num = @num + 1

	-- ����� ������
	INSERT INTO BTSortCostPrice000 ([GUID], Number, [RecordID], [BTType], BTBillType, BTSortNum, BTIsInput, ActualSort, DefaultSort, IsRelated, RelationType)
	SELECT NEWID(), @num, 11/*RecordID*/, 2/*Type*/, 5/*BillType*/, 4/*SortNum*/, 0/*BTIsInput*/, 11, 11, 1, 2
	SET @num = @num + 1

	-- ����� ������
	INSERT INTO BTSortCostPrice000 ([GUID], Number, [RecordID], [BTType], BTBillType, BTSortNum, BTIsInput, ActualSort, DefaultSort, IsRelated, RelationType)
	SELECT NEWID(), @num, 11/*RecordID*/, 2/*Type*/, 4/*BillType*/, 3/*SortNum*/, 1/*BTIsInput*/, 11, 11, 1, 2
	SET @num = @num + 1

	-- ��.������
	INSERT INTO BTSortCostPrice000 ([GUID], Number, [RecordID], [BTType], BTBillType, BTSortNum, BTIsInput, ActualSort, DefaultSort, IsRelated, RelationType)
	SELECT NEWID(), @num, 12/*RecordID*/, 3/*Type*/, 0/*BillType*/, 0/*SortNum*/, 0/*BTIsInput*/, 12, 12, 1, 3
	SET @num = @num + 1

	-- ��.������
	INSERT INTO BTSortCostPrice000 ([GUID], Number, [RecordID], [BTType], BTBillType, BTSortNum, BTIsInput, ActualSort, DefaultSort, IsRelated, RelationType)
	SELECT NEWID(), @num, 12/*RecordID*/, 4/*Type*/, 0/*BillType*/, 0/*SortNum*/, 1/*BTIsInput*/, 12, 12, 1, 3
	SET @num = @num + 1

	-- ������ ���
	INSERT INTO BTSortCostPrice000 ([GUID], Number, [RecordID], [BTType], BTBillType, BTSortNum, BTIsInput, ActualSort, DefaultSort, IsRelated, RelationType)
	SELECT NEWID(), @num, 13/*RecordID*/, 5/*Type*/, 5/*BillType*/, 0/*SortNum*/, 0/*BTIsInput*/, 13, 13, 0, -1
	SET @num = @num + 1

	-- ������
	INSERT INTO BTSortCostPrice000 ([GUID], Number, [RecordID], [BTType], BTBillType, BTSortNum, BTIsInput, ActualSort, DefaultSort, IsRelated, RelationType)
	SELECT NEWID(), @num, 14/*RecordID*/, 1/*Type*/, 1/*BillType*/, 0/*SortNum*/, 0/*BTIsInput*/, 14, 14, 0, -1
	SET @num = @num + 1

	-- �.������
	INSERT INTO BTSortCostPrice000 ([GUID], Number, [RecordID], [BTType], BTBillType, BTSortNum, BTIsInput, ActualSort, DefaultSort, IsRelated, RelationType)
	SELECT NEWID(), @num, 15/*RecordID*/, 1/*Type*/, 3/*BillType*/, 0/*SortNum*/, 1/*BTIsInput*/, 15, 15, 0, -1
	SET @num = @num + 1

	-- ����� ������
	INSERT INTO BTSortCostPrice000 ([GUID], Number, [RecordID], [BTType], BTBillType, BTSortNum, BTIsInput, ActualSort, DefaultSort, IsRelated, RelationType)
	SELECT NEWID(), @num, 16/*RecordID*/, 1/*Type*/, 5/*BillType*/, 0/*SortNum*/, 0/*BTIsInput*/, 16, 16, 0, -1
	SET @num = @num + 1

	-- ��.���� �����
	INSERT INTO BTSortCostPrice000 ([GUID], Number, [RecordID], [BTType], BTBillType, BTSortNum, BTIsInput, ActualSort, DefaultSort, IsRelated, RelationType)
	SELECT NEWID(), @num, 17/*RecordID*/, 2/*Type*/, 5/*BillType*/, 6/*SortNum*/, 0/*BTIsInput*/, 17, 17, 0, -1
	SET @num = @num + 1

	-- ����� - �����
	INSERT INTO BTSortCostPrice000 ([GUID], Number, [RecordID], [BTType], BTBillType, BTSortNum, BTIsInput, ActualSort, DefaultSort, IsRelated, RelationType)
	SELECT NEWID(), @num, 18/*RecordID*/, 9/*Type*/, 0/*BillType*/, 0/*SortNum*/, 0/*BTIsInput*/, 18, 18, 0, -1
	SET @num = @num + 1

		-- ����� - �����
	INSERT INTO BTSortCostPrice000 ([GUID], Number, [RecordID], [BTType], BTBillType, BTSortNum, BTIsInput, ActualSort, DefaultSort, IsRelated, RelationType)
	SELECT NEWID(), @num, 19/*RecordID*/, 10/*Type*/, 0/*BillType*/, 0/*SortNum*/, 0/*BTIsInput*/, 19, 19, 0, -1
	SET @num = @num + 1
#########################################################
#END
