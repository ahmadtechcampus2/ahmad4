###########################################################################
CREATE FUNCTION fnGetBillFlags(@BillId AS INT)
	RETURNS INT
AS BEGIN
/*
���� ������ ��� ������ ��� ������ ����
*/
	DECLARE @Flag INT
	IF @BillId < 255
		SELECT @Flag = Num4	FROM mc000 WHERE Type = 1 AND Number = @BillId
	ELSE
		SELECT @Flag = Num4 FROM mc000 WHERE Type = 2 AND Number = @BillId - 255
	RETURN @Flag
END

###########################################################################
#END
