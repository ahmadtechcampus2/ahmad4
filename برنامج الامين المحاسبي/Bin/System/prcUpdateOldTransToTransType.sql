#########################################################
CREATE PROC prcUpdateOldTransToTransType
AS
	INSERT INTO tt000 
	SELECT 
		newid(), btOut.Guid, btIn.Guid, 0, 0, 0, 0
	FROM 
		bt000 btOut INNER JOIN bt000 btIn
		ON 
		btOut.Type = 2 AND btOut.BillType = 5 AND btOut.SortNum = 4 
		AND btIn.Type = 2 AND btIn.BillType = 4 AND btIn.SortNum = 3


	INSERT INTO tt000 
	SELECT 
		newid(), btOut.Guid, btIn.Guid, 0, 0, 0, 0
	FROM 
		bt000 btOut INNER JOIN bt000 btIn
		ON 
		btOut.Type = 2 AND btOut.BillType = 5 AND btOut.SortNum = 8 
		AND btIn.Type = 2 AND btIn.BillType = 4 AND btIn.SortNum = 7


	UPDATE bt000 SET [Name] = '??.????? ??????', LatinName = 'In.Store Translat' WHERE Type = 2 AND BillType = 4 AND SortNum = 3 
	UPDATE bt000 SET [Name] = '??.????? ??????', LatinName = 'Out.Store Translat' WHERE Type = 2 AND BillType = 5 AND SortNum = 4 

	UPDATE bt000 SET [Name] = '??.????? ?????? ????', LatinName = 'In.Store Translat Entry' WHERE Type = 2 AND BillType = 4 AND SortNum = 7
	UPDATE bt000 SET [Name] = '??.????? ?????? ????', LatinName = 'Out.Store Translat Entry' WHERE Type = 2 AND BillType = 5 AND SortNum = 8 


	UPDATE bt000 SET Type = 4, BillType = 0, BillGroup = 0  WHERE Type = 2 AND BillType = 4 AND (SortNum = 3 OR SortNum = 7)
	UPDATE bt000 SET Type = 3, BillType = 0, BillGroup = 0  WHERE Type = 2 AND BillType = 5 AND (SortNum = 4 OR SortNum = 8)
	--------------------------------------------------------------------
	-- update error trans : 
	--	output bill without inbut bill 
	--	or input bill without outbut bill
	--------------------------------------------------------------------
	
	DECLARE @BbuDeleted TABLE( buGUID UNIQUEIDENTIFIER, buTypeGuid UNIQUEIDENTIFIER, NewbuGUID UNIQUEIDENTIFIER, NewbuTypeGuid UNIQUEIDENTIFIER)
	-- output bill without inbut bill 
	INSERT INTO @BbuDeleted
		SELECT  billOut.GUID, billOut.TypeGuid, newid(), tt.InTypeGuid
		FROM
			tt000 tt INNER JOIN 
			(SELECT buOut.GUID GUID, buOut.Number Number, btOut.Type Type, btOut.Guid TypeGuid FROM bu000 buOut INNER JOIN bt000 btOut on buOut.TypeGuid = btOut.Guid WHERE btOut.Type = 3) billOut
			ON billOut.TypeGuid = tt.OutTypeGuid
			LEFT JOIN 		
			(SELECT buIn.GUID GUID, buIn.Number Number, btIn.Type Type, btIn.Guid TypeGuid FROM bu000 buIn INNER JOIN bt000 btIn on buIn.TypeGuid = btIn.Guid where btIn.Type = 4) billIn
			ON billOut.Number = billIn.Number
		WHERE
			billIn.GUID IS NULL

	-- input bill without outbut bill
	INSERT INTO @BbuDeleted
		SELECT  billIn.GUID, billIn.TypeGuid, newid(), tt.OutTypeGuid
		FROM 	
			tt000 tt INNER JOIN 
			(SELECT buIn.GUID GUID, buIn.Number Number, btIn.Type Type, btIn.Guid TypeGuid FROM bu000 buIn INNER JOIN bt000 btIn on buIn.TypeGuid = btIn.Guid where btIn.Type = 4) billIn
			ON billIn.TypeGuid = tt.InTypeGuid
			LEFT JOIN 		
			(SELECT buOut.GUID GUID, buOut.Number Number, btOut.Type Type, btOut.Guid TypeGuid FROM bu000 buOut INNER JOIN bt000 btOut on buOut.TypeGuid = btOut.Guid WHERE btOut.Type = 3) billOut
			ON billOut.Number = billIn.Number
		WHERE
			billOut.GUID IS NULL

	UPDATE bu SET IsPosted = 0 
	FROM
		bu000 bu inner join @BbuDeleted b
		on bu.Guid = b.buGuid
	--------------------------------------------------------------------
	SELECT * INTO #Bill
		FROM ( SELECT bu.* FROM
			bu000 bu inner join @BbuDeleted buDel
			on bu.Guid = buDel.buGuid) d

	UPDATE bill SET Guid = b.NewbuGUID, TypeGuid = b.NewbuTypeGuid, IsPosted = 0
	FROM
		#Bill bill INNER JOIN  @BbuDeleted b ON b.buGUID = bill.Guid

	INSERT INTO bu000 SELECT * FROM #Bill

	SELECT * INTO #BillItem FROM ( SELECT bi.* FROM
			bi000 bi inner join @BbuDeleted buDel
			on bi.ParentGuid = buDel.buGuid) d

	UPDATE BillItem SET Guid = newId(), ParentGuid = b.NewbuGuid
	FROM 
		#BillItem BillItem INNER JOIN @BbuDeleted b ON BillItem.ParentGuid = b.buGuid

	INSERT INTO bi000 SELECT * FROM #BillItem
	
	--------------------------------------------------------------------	
	delete from ts000 where OutBillGUID in (SELECT buOut.GUID GUID FROM bu000 buOut INNER JOIN bt000 btOut on buOut.TypeGuid = btOut.Guid WHERE btOut.Type = 3)
	delete from ts000 where InBillGUID in  (SELECT buIn.GUID GUID FROM bu000 buIn INNER JOIN bt000 btIn on buIn.TypeGuid = btIn.Guid where btIn.Type = 4)

	INSERT INTO ts000
	SELECT newid(), billOut.Guid, billIn.Guid
	FROM 
		tt000 tt INNER JOIN 
		(SELECT buOut.GUID GUID, buOut.Number Number, btOut.Type Type, btOut.Guid TypeGuid FROM bu000 buOut INNER JOIN bt000 btOut on buOut.TypeGuid = btOut.Guid WHERE btOut.Type = 3) billOut
		ON BillOut.TypeGuid = tt.OutTypeGuid
		INNER JOIN 
		(SELECT buIn.GUID GUID, buIn.Number Number, btIn.Type Type, btIn.Guid TypeGuid FROM bu000 buIn INNER JOIN bt000 btIn on buIn.TypeGuid = btIn.Guid where btIn.Type = 4) billIn
		ON BillIn.TypeGuid = tt.InTypeGuid AND billOut.Number = billIn.Number
#########################################################
#END