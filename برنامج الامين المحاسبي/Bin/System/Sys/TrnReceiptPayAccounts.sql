##############################################
CREATE FUNCTION fnTrnReceiptAccounts ()
	RETURNS @EndResult TABLE(
			Number	[INT],
			Name	[NVARCHAR](256),
			Code	[NVARCHAR](256),
			NSons	[INT],
			GUID	[UNIQUEIDENTIFIER],
			Parent	[UNIQUEIDENTIFIER])
AS BEGIN
	DECLARE @AccGUID UNIQUEIDENTIFIER
	DECLARE @Result TABLE (acc UNIQUEIDENTIFIER)

	DECLARE TrnReceiptPayAccountsCursor CURSOR FOR   
	SELECT ReceiptAccounts
	FROM 
		TrnReceiptPayAccounts000 
  	WHERE 
		ISNULL(ReceiptAccounts, 0x0) <> 0x0

	OPEN TrnReceiptPayAccountsCursor  
  
	FETCH NEXT FROM TrnReceiptPayAccountsCursor   
	INTO @AccGUID
  
	WHILE @@FETCH_STATUS = 0  
	BEGIN
		INSERT INTO @Result
		SELECT GUID FROM fnGetAccountsListByFinal(@AccGUID)
		FETCH NEXT FROM TrnReceiptPayAccountsCursor   
		INTO @AccGUID 
	END
	CLOSE TrnReceiptPayAccountsCursor;  
	DEALLOCATE TrnReceiptPayAccountsCursor;  

	INSERT INTO @EndResult
	SELECT DISTINCT Number, Name, Code, NSons, GUID, ParentGUID	FROM ac000 AS a
	INNER JOIN @Result AS r ON a.GUID = r.acc AND a.GUID NOT IN (SELECT ParentGUID FROM ac000) AND Type != 4
	RETURN
END
#################################
CREATE FUNCTION fnTrnPayAccounts ()
	RETURNS @EndResult TABLE(
			Number	[INT],
			Name	[NVARCHAR](256),
			Code	[NVARCHAR](256),
			NSons	[INT],
			GUID	[UNIQUEIDENTIFIER],
			Parent	[UNIQUEIDENTIFIER])
AS BEGIN
	DECLARE @AccGUID UNIQUEIDENTIFIER
	DECLARE @Result TABLE (acc UNIQUEIDENTIFIER)

	DECLARE TrnReceiptPayAccountsCursor CURSOR FOR   
	SELECT PayAccounts
	FROM 
		TrnReceiptPayAccounts000 
	WHERE 
		ISNULL(PayAccounts, 0x0) <> 0x0
	
	OPEN TrnReceiptPayAccountsCursor  
  
	FETCH NEXT FROM TrnReceiptPayAccountsCursor   
	INTO @AccGUID
  
	WHILE @@FETCH_STATUS = 0  
	BEGIN
		INSERT INTO @Result
		SELECT GUID FROM fnGetAccountsListByFinal(@AccGUID)
		FETCH NEXT FROM TrnReceiptPayAccountsCursor   
		INTO @AccGUID 
	END
	CLOSE TrnReceiptPayAccountsCursor;  
	DEALLOCATE TrnReceiptPayAccountsCursor;  

	INSERT INTO @EndResult
	SELECT DISTINCT Number, Name, Code, NSons, GUID, ParentGUID	FROM ac000 AS a
	INNER JOIN @Result AS r ON a.GUID = r.acc AND a.GUID NOT IN (SELECT ParentGUID FROM ac000) AND Type != 4
	RETURN
END
#################################
#END