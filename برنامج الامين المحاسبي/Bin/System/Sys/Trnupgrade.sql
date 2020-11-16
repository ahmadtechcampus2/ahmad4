----
UPDATE trntransfervoucher000
	SET sendercenterguid = us.centerguid
FROM trntransfervoucher000 AS tr
INNER JOIN TrnUserConfig000 AS us ON us.userguid = tr.senderuserguid 

UPDATE trntransfervoucher000
	SET Recievercenterguid = us.centerguid
FROM trntransfervoucher000 AS tr
INNER JOIN TrnUserConfig000 AS us ON us.userguid = tr.Receiveruserguid 

----------------------------------------------------------------------
----------Script for Add InternalNumber to TrnExchange000
----------------------------------------------------------------------
--1.Add Field
EXEC [prcAddIntFld] 'TrnExchange000', 'InternalNumber'
EXEC [prcAddIntFld] 'TrnExchangeDetail000', 'InternalNumber'

--2.Ordered Tbl
DECLARE @OrderedEx TABLE
			(GUID UNIQUEIDENTIFIER,
			isSimple BIT,	
			InternalNumber INT IDENTITY)
INSERT INTO @OrderedEx (GUID, isSimple) 
	SELECT 
		ISNULL(det.GUID, ex.GUID),
		ex.bsimple
	FROM 
		TrnExchange000 AS ex
	 	LEFT JOIN TrnExchangeDetail000 AS Det ON Det.ExchangeGUID = ex.GUID
	ORDER BY  ex.[Date], ex.Number


	--3.Update
	Update TrnExchange000
		SET InternalNumber = OrderedEx.InternalNumber
	FROM TrnExchange000 ex 
	INNER JOIN @OrderedEx OrderedEx ON ex.GUID = OrderedEx.GUID


	Update TrnExchangeDetail000
		SET InternalNumber = OrderedEx.InternalNumber
	FROM TrnExchangeDetail000 ex 
	INNER JOIN @OrderedEx OrderedEx ON ex.GUID = OrderedEx.GUID
-------------------------------------------------------------------------------
----------This Trigger To adjust IntrnalNumber in [TrnExchange000] after Insert
-------------------------------------------------------------------------------
