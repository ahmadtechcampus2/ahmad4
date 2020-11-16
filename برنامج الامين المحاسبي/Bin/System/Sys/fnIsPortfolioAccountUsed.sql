#############################################################################
CREATE FUNCTION  fnIsPortfolioAccountUsed(@accGuid  UNIQUEIDENTIFIER, @portfolioNumber INT)
	RETURNS  @cheque table(accGuid uniqueidentifier, parenttype int, dir int, debit float, credit float)
BEGIN
	IF ISNULL(@accGuid,0x0) = 0x0
	RETURN

	DECLARE @allcheque table(accGuid UNIQUEIDENTIFIER, parenttype INT, dir INT, debit FLOAT, credit FLOAT)

	INSERT INTO @allcheque 
	SELECT en.AccountGUID, er.ParentType, ch.Dir, en.Debit, en.Credit  
	FROM en000 en
		INNER JOIN ce000 ce ON  ce.GUID = en.ParentGUID
		INNER JOIN er000 er ON er.EntryGUID = ce.GUID
		INNER JOIN ch000 ch ON ch.GUID = er.ParentGUID 
	WHERE en.AccountGUID = @accGuid

	 IF @portfolioNumber = 0
	 BEGIN 
		 INSERT INTO @cheque 
		 SELECT *
		 FROM  @allcheque
		 WHERE dir = 1 AND parenttype = 5 AND debit > 0
		 
		 INSERT INTO @cheque 
		 SELECT DefRecAccGUID,0,0,0,0
		 FROM  nt000 nt
		 WHERE nt.DefRecAccGUID = @accGuid 
	 END 

	 IF @portfolioNumber = 1
	 BEGIN
		 INSERT INTO @cheque 
		 SELECT *
		 FROM  @allcheque
		 WHERE dir = 2 AND parenttype = 5 AND credit > 0

		 INSERT INTO @cheque 
		 SELECT DefPayAccGUID,0,0,0,0
		 FROM  nt000 nt
		 WHERE nt.DefPayAccGUID = @accGuid 
	 END 
 
	 IF @portfolioNumber = 2
	 
	 BEGIN	 
		INSERT INTO @cheque 
		 SELECT *
		 FROM  @allcheque
		 WHERE (dir = 1 AND parenttype IN (6,12,252,260)  AND debit > 0 )OR (dir = 2 AND parenttype IN (6,12)  AND credit > 0 ) 

		INSERT INTO @cheque 
		 SELECT DefRecOrPayAccGUID,0,0,0,0
		 FROM  nt000 nt
		 WHERE nt.DefRecOrPayAccGUID = @accGuid 
	 END

	 IF @portfolioNumber = 3
	 BEGIN
		 INSERT INTO @cheque 
		 SELECT *
		 FROM  @allcheque
		 WHERE dir = 1 AND parenttype = 7 AND credit > 0

		 INSERT INTO @cheque 
		 SELECT DefEndorseAccGUID,0,0,0,0
		 FROM  nt000 nt
		WHERE nt.DefEndorseAccGUID = @accGuid 
	 END 

	 IF @portfolioNumber = 4
	 BEGIN
		 INSERT INTO @cheque 
		 SELECT *
		 FROM  @allcheque
		 WHERE dir = 1 AND parenttype = 250 AND debit > 0 

		 INSERT INTO @cheque 
		 SELECT DefColAccGUID,0,0,0,0
		 FROM  nt000 nt
		 WHERE nt.DefColAccGUID = @accGuid 
	 END 

	 IF @portfolioNumber = 5
	 BEGIN
		 INSERT INTO @cheque 
		 SELECT *
		 FROM  @allcheque
		 WHERE dir = 1
		  AND parenttype = 257 AND debit > 0 

		 INSERT INTO @cheque 
		 SELECT DefUnderDisAccGUID,0,0,0,0
		 FROM  nt000 nt
		 WHERE nt.DefUnderDisAccGUID = @accGuid 
	 END 

	 IF @portfolioNumber = 6
	 BEGIN
		 INSERT INTO @cheque 
		 SELECT *
		 FROM  @allcheque
		 WHERE dir = 1 AND parenttype = 260 AND credit > 0 

		 INSERT INTO @cheque 
		 SELECT DefDisAccGUID,0,0,0,0
		 FROM  nt000 nt
		 WHERE nt.DefDisAccGUID = @accGuid 
	 END

RETURN
END
#############################################################################
#END