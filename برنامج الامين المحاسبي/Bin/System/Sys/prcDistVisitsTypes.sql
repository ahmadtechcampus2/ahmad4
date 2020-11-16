################################################################################
CREATE PROCEDURE prcDistGetVisitsState
	@StartDate	DATETIME,
	@EndDate	DATETIME,
	@HiGuid		UNIQUEIDENTIFIER = 0x0,
	@DistGuid	UNIQUEIDENTIFIER = 0x0,
	@ManualEntryVisit	INT = 0,	-- 1  Entry From Ameen IS Visit		0 Entry From Amn Is Not Visit 
	@SrcGuid			[UNIQUEIDENTIFIER]
AS
	SET NOCOUNT ON

	--تم إضافة السكريبت التالي لإزلة التكرارات في جدول
	--DistVd000
	--والناتجة عن بعض الأخطاء عند إضافة الزيارات إليه
	--يتم حذف التكرار فقط مع الزيارات ذات النوع 2 و 3
	--و فقط عند وجود تكرار
	--------------------------------------------------------------------
	EXEC prcDropTable 'TempVd'
	
	Select VistGuid, ObjectGuid, Type INTO TempVd
	From DistVd000 
	GROUP By VistGuid, ObjectGuid, Type
	Having  COUNT(Type)>1

	----------------------------------
	DECLARE @RowCount INT
	SELECT @RowCount = COUNT(*) FROM TempVd
	IF(@RowCount > 0)
	BEGIN
		Delete DistVd000 
		FROM DistVd000 AS vd
		INNER JOIN TempVd AS t On t.ObjectGuid = vd.ObjectGuid AND t.VistGuid = vd.VistGuid
		----------------------------------
	
		INSERT INTO DistVd000 
		Select newId(), VistGuid, Type, ObjectGuid, 1, '', ''
		From TempVd 
	END
	--Drop Table TempVd
	-----------
	--this script is used to delete the records in the distvd that doesn't have a corresponding objectguid in en000
	--which could result from deleting or modifying some records in en000
	DELETE FROM DistVd000
	WHERE ObjectGuid NOT IN (SELECT Guid FROM en000) AND Type = 2
	-----------------------------------------------------------------------

	-----------
	CREATE TABLE #DistTable (DistGuid UNIQUEIDENTIFIER)
	IF @DistGuid <> 0X0  
	BEGIN 
		INSERT INTO #DistTable
			SELECT Guid FROM vwDistributor WHERE  Guid = @DistGuid 
	END
	ELSE
	BEGIN
		INSERT INTO #DistTable 
			SELECT Guid FROM vwDistributor  
			WHERE  HierarchyGUID IN (SELECT Guid FROM fnGetHierarchyList(@HiGuid,0))
	END

	------ Report Sources Bills and entries -------------------------------------------------------- 
	DECLARE @UserId		UNIQUEIDENTIFIER      
	SET @UserId = dbo.fnGetCurrentUserGUID()        
	CREATE TABLE [#BillTable] ([Type] [UNIQUEIDENTIFIER], [Security] [INT], [ReadPriceSecurity] [INT], [UnPostedSecurity] [INT])       
	INSERT INTO [#BillTable]
		SELECT  
			GUID,  
			PostedSecurity AS Security, 
			ReadPriceSecurity, 
			UnPostedSecurity
		FROM
			dbo.fnGetBillsTypesList2(@SrcGuid, @UserId, DEFAULT) 

	CREATE TABLE [#EntryTable]( [Type] 	[UNIQUEIDENTIFIER], [Security]  	[INT])  
	INSERT INTO [#EntryTable]
		SELECT * 
		FROM 
			[dbo].[fnGetEntriesTypesList]( @SrcGuid, @UserId)

	-------------------------------------------------------------------------------------      
	--Get All of the visits in the specified date range along with the type of the visit
	CREATE TABLE #Visits (VisitGuid UNIQUEIDENTIFIER, Type INT, ObjectGuid UNIQUEIDENTIFIER, DistributorGuid UNIQUEIDENTIFIER, CustGuid UNIQUEIDENTIFIER, VisitDate DATETIME)

	INSERT INTO #Visits --Insert the visits stored in Vd (that has type of 0,1,2,3)
		SELECT
			Vd.VistGuid,
			Vd.Type, --
			Vd.ObjectGuid,
			TrVi.TrDistributorGuid,
			TrVi.ViCustomerGuid,
			TrVi.ViStartTime
		FROM DistVd000 AS Vd
		INNER JOIN vwDistTrVi AS TrVi ON Vd.VistGuid = TrVi.ViGuid
		INNER JOIN #DistTable AS d ON TrVi.TrDistributorGuid = d.DistGuid
		WHERE TrVi.ViStartTime BETWEEN @StartDate AND @EndDate

	INSERT INTO #Visits -- Insert the visits not stored in Vd (Like the visits with Customers stock and shelfe share)
		SELECT
			TrVi.ViGuid,
			5,
			0x0,
			TrVi.TrDistributorGuid,
			TrVi.ViCustomerGuid,
			TrVi.ViStartTime
		FROM vwDistTrVi AS TrVi
		INNER JOIN #DistTable AS d ON TrVi.TrDistributorGuid = d.DistGuid
		WHERE (TrVi.ViStartTime BETWEEN @StartDate AND @EndDate) AND TrVi.ViGuid NOT IN (SELECT VistGuid From DistVd000)
			
	
	--SELECT * FROM #Visits
	------------------------------------------------------------

	-- Get the options from the op000 table
	DECLARE @VisitTypes NCHAR (20)
	SELECT @VisitTypes = Value FROM op000 WHERE Name = 'DistCfg_VisitTypes'
	--
	DECLARE --Variables to hold the visit types options stored in the options table
			-- 0 for inactive & 1 for active
		@OutBill	NCHAR (1),	--فواتير إخراج
		@InBill		NCHAR (1),	--فواتير إدخال
		@Payment	NCHAR (1),	--سندات قبض
		@Receipt	NCHAR (1),	--سندات دفع
		@OutStore	NCHAR (1),	--مناقلات من مستودع المندوب
		@InStore	NCHAR (1),	--مناقلات إلى مستودع المندوب
		@NoSale		NCHAR (1),	--أسباب عدم بيع
		@Activities	NCHAR (1),	--الفعاليات
		@ShelfShare	NCHAR (1),	--حصة الرف
		@CustStock	NCHAR (1)	--مخزون الزبائن
		--Fill in the options values
	IF ISNULL(@VisitTypes, '') <> ''
		BEGIN
		SET @OutBill	= SUBSTRING(@VisitTypes, 1, 1)
		SET @InBill		= SUBSTRING(@VisitTypes, 3, 1)
		SET @Receipt	= SUBSTRING(@VisitTypes, 5, 1)
		SET @Payment	= SUBSTRING(@VisitTypes, 7, 1)
		SET @OutStore	= SUBSTRING(@VisitTypes, 9, 1)
		SET @InStore	= SUBSTRING(@VisitTypes, 11, 1)
		SET @NoSale		= SUBSTRING(@VisitTypes, 13, 1)
		SET @Activities	= SUBSTRING(@VisitTypes, 15, 1)
		SET @ShelfShare	= SUBSTRING(@VisitTypes, 17, 1)
		SET @CustStock	= SUBSTRING(@VisitTypes, 19, 1)
		END
	ELSE
		BEGIN
		SET @OutBill	= 1
		SET @InBill		= 1
		SET @Payment	= 0
		SET @Receipt	= 0
		SET @OutStore	= 1
		SET @InStore	= 1
		SET @NoSale		= 0
		SET @Activities	= 0
		SET @ShelfShare	= 0
		SET @CustStock	= 0
		END
		------------------------------------------------------------

	CREATE TABLE #VisitsStates (VisitGuid UNIQUEIDENTIFIER, CustGuid UNIQUEIDENTIFIER, DistGuid UNIQUEIDENTIFIER, State INT, VisitDate DATETIME, ObjectType INT, ObjectGuid UNIQUEIDENTIFIER) -- State: 1 Active , 0 Inactive

	--Add the visits that marked as "InBill" OR "OutBill"
	INSERT INTO #VisitsStates
			SELECT
				Vi.VisitGuid,
				Vi.CustGuid,
				Vi.DistributorGuid,
				1,
				dbo.fnGetDateFromDT(Vi.VisitDate),
				Vi.Type,
				Vi.ObjectGuid
			FROM #Visits AS Vi
			INNER JOIN bu000 AS bu ON bu.Guid = Vi.ObjectGuid
			INNER JOIN #BillTable AS bs ON bs.Type = bu.TypeGuid
			INNER JOIN bt000 AS bt ON bu.TypeGuid = bt.Guid
			WHERE (bt.type NOT IN (3,4) AND Vi.Type = 3 AND --الفواتير من نوع 3 و4 هي فواتير مناقلات ستعالج لاحقا
					((@InBill = '1' AND bt.bIsInput = 1) OR (@OutBill = '1' AND bt.bIsOutput = 1)))

	--Add the visits that marked as "Payment" OR "Receipt"
	INSERT INTO #VisitsStates
			SELECT DISTINCT
				Vi.VisitGuid,
				Vi.CustGuid,
				Vi.DistributorGuid,
				1,
				dbo.fnGetDateFromDT(Vi.VisitDate),
				Vi.Type,
				Vi.ObjectGuid
			FROM #Visits AS Vi
			INNER JOIN en000 AS en ON en.Guid = Vi.ObjectGuid
			INNER JOIN ce000 AS ce ON en.ParentGuid = ce.Guid
			INNER JOIN #EntryTable AS es ON es.Type = ce.TypeGuid
			INNER JOIN et000 AS et ON ce.TypeGuid = et.Guid
			WHERE (Vi.Type = 2 AND ((@Payment = '1' AND  et.FldDebit <> 0 AND et.FldCredit = 0)  --دائن
								 OR (@Receipt = '1' AND  et.FldDebit = 0 AND et.FldCredit <> 0))) --مدين
		-- The entries that generated by the first pay of the bill don't have type of payment or receipt
		-- so they should be handled in this "insert"
	INSERT INTO #VisitsStates
			SELECT DISTINCT
				Vi.VisitGuid,
				Vi.CustGuid,
				Vi.DistributorGuid,
				1,
				dbo.fnGetDateFromDT(Vi.VisitDate),
				Vi.Type,
				Vi.ObjectGuid
			FROM #Visits AS Vi
			INNER JOIN bu000 AS bu ON bu.Guid = Vi.ObjectGuid
			INNER JOIN bt000 AS bt ON bu.TypeGuid = bt.Guid
			INNER JOIN #BillTable AS bs ON bs.Type = bt.Guid
			WHERE (Vi.Type = 3 AND ((@Payment = '1' AND  bu.FirstPay <> 0 AND bt.bIsInput  = 1)
								 OR (@Receipt = '1' AND  bu.FirstPay <> 0 AND bt.bIsOutput = 1)))

	--Add the visits that marked as "OutStore" OR "InStore"
	INSERT INTO #VisitsStates
			SELECT DISTINCT
				Vi.VisitGuid,
				Vi.CustGuid,
				Vi.DistributorGuid,
				1,
				dbo.fnGetDateFromDT(Vi.VisitDate),
				Vi.Type,
				Vi.ObjectGuid
			FROM #Visits AS Vi
			INNER JOIN bu000 AS bu ON bu.Guid = Vi.ObjectGuid
			INNER JOIN #BillTable AS bs ON bs.Type = bu.TypeGuid
			INNER JOIN bt000 AS bt ON bu.TypeGuid = bt.Guid
			WHERE (bt.type IN (3,4) AND Vi.Type = 3 AND
					((@InStore = '1' AND bt.bIsInput = 1) OR (@OutStore = '1' AND bt.bIsOutput = 1)))

	--Add the visits that marked as "NoSales Reasons" OR "Activities"
	INSERT INTO #VisitsStates
			SELECT DISTINCT
				Vi.VisitGuid,
				Vi.CustGuid,
				Vi.DistributorGuid,
				1,
				dbo.fnGetDateFromDT(Vi.VisitDate),
				Vi.Type,
				Vi.ObjectGuid
			FROM #Visits AS Vi
			INNER JOIN DistVd000 AS Vd ON Vd.VistGuid = Vi.VisitGuid
			WHERE (@NoSale = '1' AND Vi.Type = 0) OR (@Activities = '1' AND Vi.Type = 1)

	--Add the visits that marked as "Shelfe Share"
	INSERT INTO #VisitsStates
			SELECT DISTINCT
				Vi.VisitGuid,
				Vi.CustGuid,
				Vi.DistributorGuid,
				1,
				dbo.fnGetDateFromDT(Vi.VisitDate),
				Vi.Type,
				Vi.ObjectGuid
			FROM #Visits AS Vi
			INNER JOIN DistCg000 AS Cg ON Cg.VisitGuid = Vi.VisitGuid
			WHERE @ShelfShare = '1'

	--Add the visits that marked as "Customer Stock"
	INSERT INTO #VisitsStates
			SELECT DISTINCT
				Vi.VisitGuid,
				Vi.CustGuid,
				Vi.DistributorGuid,
				1,
				dbo.fnGetDateFromDT(Vi.VisitDate),
				Vi.Type,
				Vi.ObjectGuid
			FROM #Visits AS Vi
			INNER JOIN DistCm000 AS Cm ON Cm.VisitGuid = Vi.VisitGuid
			WHERE @CustStock = '1'

	--Delete the duplicated visits in the #VisitsState And set the one resulting visit state to 1 (Active)
	--And insert the result in the #FinalVisitsStates table
	CREATE TABLE #FinalVisitsStates (VisitGuid UNIQUEIDENTIFIER, CustGuid UNIQUEIDENTIFIER, DistGuid UNIQUEIDENTIFIER, State INT, VisitDate DATETIME, ObjectType INT, ObjectGuid UNIQUEIDENTIFIER) -- State: 1 Active , 0 Inactive
	INSERT INTO #FinalVisitsStates
		SELECT DISTINCT * FROM #VisitsStates

	--Insert the Inactive visits to the #VisitsStates Table
	INSERT INTO #FinalVisitsStates
		SELECT
			Vi.VisitGuid,
			Vi.CustGuid,
			Vi.DistributorGuid,
			0,
			Vi.VisitDate,
			Vi.Type,
			Vi.ObjectGuid
		FROM #Visits AS Vi
		WHERE Vi.VisitGuid NOT IN (SELECT VisitGuid FROM #VisitsStates)

	--لحذف أنماط الفواتير الغير موجودة ضمن مصادر التقرير و ذلك بالنسبة للزيارات الغير فعالة
	DELETE FROM #FinalVisitsStates
		WHERE ObjectType = 3 AND ObjectGuid NOT IN (SELECT bu.Guid FROM bu000 AS bu
													INNER JOIN #BillTable AS bs ON bu.TypeGuid = bs.Type)
													
	--لحذف أنماط السندات الغير موجودة ضمن مصادر التقرير و ذلك بالنسبة للزيارات الغير فعالة
	DELETE FROM #FinalVisitsStates
		WHERE ObjectType = 2 AND ObjectGuid NOT IN (SELECT en.Guid FROM en000 AS en
													INNER JOIN ce000 AS ce ON en.ParentGuid = ce.Guid
													INNER JOIN #EntryTable AS es ON ce.TypeGuid = es.Type)

	--Add the Manual bills and Entries from Al-Ameen if @ManualEntryVisit = 1
	IF @ManualEntryVisit = 1
	BEGIN
	INSERT INTO #FinalVisitsStates --Insert the bills
		SELECT
			ISNULL(Vd.VistGuid, newid()),
			bu.CustGuid,
			d.Guid,
			1,
			bu.Date,
			3,
			bu.Guid
		FROM bu000 AS bu
		INNER JOIN bt000 AS bt ON bu.TypeGuid = bt.Guid
		INNER JOIN #BillTable AS bs ON bs.Type = bu.TypeGuid
		INNER JOIN DistSalesMan000 AS sm ON bu.CostGuid = sm.CostGuid
		INNER JOIN Distributor000 AS d ON sm.Guid = d.PrimSalesmanGuid --To retrive the distributor associted with the current bill
		INNER JOIN #DistTable AS dt ON d.Guid = dt.DistGuid
		LEFT JOIN DistVd000 AS Vd ON Vd.ObjectGuid = bu.Guid
		WHERE (bu.Date BETWEEN @StartDate AND @EndDate) AND bu.Guid NOT IN (SELECT ObjectGuid FROM #Visits) --To prevent the same bill from being repeated more than one time (With a  visit and without a visit)
				AND ISNULL(Vd.VistGuid, 0x0) NOT IN (SELECT VisitGuid FROM #FinalVisitsStates)
				AND ((bt.type NOT IN (3,4) AND ((@InBill = '1' AND bt.bIsInput = 1) OR (@OutBill = '1' AND bt.bIsOutput = 1)))
					OR (bt.type	  IN (3,4) AND ((@InStore = '1' AND bt.bIsInput = 1) OR (@OutStore = '1' AND bt.bIsOutput = 1))))

	
	--Insert the visits generated by manual bills into the visits table to use the object guid in the following step
	--
	INSERT INTO #Visits
		SELECT
			0x0,
			3,
			bu.Guid,
			0x0,
			0x0,
			bu.Date
		FROM bu000 AS bu
		INNER JOIN bt000 AS bt ON bu.TypeGuid = bt.Guid
		INNER JOIN #BillTable AS bs ON bs.Type = bu.TypeGuid
		INNER JOIN DistSalesMan000 AS sm ON bu.CostGuid = sm.CostGuid
		INNER JOIN Distributor000 AS d ON sm.Guid = d.PrimSalesmanGuid --To retrive the distributor associted with the current bill
		INNER JOIN #DistTable AS dt ON d.Guid = dt.DistGuid
		WHERE (bu.Date BETWEEN @StartDate AND @EndDate) AND bu.Guid NOT IN (SELECT ObjectGuid FROM #Visits) --To prevent the same bill from being repeated more than one time (With a  visit and without a visit)
				AND ((bt.type NOT IN (3,4) AND ((@InBill = '1' AND bt.bIsInput = 1) OR (@OutBill = '1' AND bt.bIsOutput = 1)))
					OR (bt.type	  IN (3,4) AND ((@InStore = '1' AND bt.bIsInput = 1) OR (@OutStore = '1' AND bt.bIsOutput = 1))))

	-- The entries that generated by the first pay of the bill don't have type of payment or receipt
	-- so they should be handled in this "insert"
	INSERT INTO #FinalVisitsStates
			SELECT DISTINCT
				ISNULL(Vd.VistGuid, newid()),
				bu.CustGuid,
				d.Guid,
				1,
				bu.Date,
				3,
				bu.Guid
			FROM bu000 AS bu
			INNER JOIN bt000 AS bt ON bu.TypeGuid = bt.Guid
			INNER JOIN #BillTable AS bs ON bs.Type = bt.Guid
			INNER JOIN DistSalesMan000 AS sm ON bu.CostGuid = sm.CostGuid
			INNER JOIN Distributor000 AS d ON sm.Guid = d.PrimSalesmanGuid --To retrive the distributor associted with the current bill
			INNER JOIN #DistTable AS dt ON d.Guid = dt.DistGuid
			LEFT JOIN DistVd000 AS Vd ON Vd.ObjectGuid = bu.Guid
			WHERE (bu.Date BETWEEN @StartDate AND @EndDate) AND bu.Guid NOT IN (SELECT ObjectGuid FROM #Visits) --To prevent the same bill from being repeated more than one time (With a  visit and without a visit)
					AND ((@Payment = '1' AND  bu.FirstPay <> 0 AND bt.bIsInput  = 1)
					OR   (@Receipt = '1' AND  bu.FirstPay <> 0 AND bt.bIsOutput = 1))


	--Add the visits generated by manual bills to Distvd000
	INSERT INTO DistVd000
		SELECT
			newid(),
			VisitGuid,
			3, --type = 3; bill
			ObjectGuid,
			1,
			'',
			''
		FROM #FinalVisitsStates AS fv
		WHERE ObjectType = 3 AND ObjectGuid NOT IN (SELECT ObjectGuid FROM DistVd000)

	--Add the visits generated by manual entries to Distvd000
	INSERT INTO DistVd000
		SELECT
			newid(),
			ISNULL(Vd.VistGuid, newid()), --create a new visitguid
			2, --type = 2; entry
			en.Guid,
			1,
			'',
			''
		FROM cu000 AS cu

		INNER JOIN en000 AS en ON cu.AccountGuid = en.AccountGuid	-- لمنع تكرار
		INNER JOIN ce000 as ce ON en.parentguid = ce.guid			-- السند و الفاتورة
		INNER JOIN #EntryTable AS es ON es.Type = ce.TypeGuid
		INNER JOIN et000 AS et ON ce.TypeGuid = et.Guid
		INNER JOIN er000 as er ON ce.guid = er.entryguid			-- المتولد عنها

		INNER JOIN DistSalesMan000 AS sm ON en.CostGuid = sm.CostGuid
		INNER JOIN Distributor000 AS d ON sm.Guid = d.PrimSalesmanGuid --To retrive the distributor associted with the current entry
		INNER JOIN #DistTable AS dt ON d.Guid = dt.DistGuid

		LEFT JOIN DistVd000 AS Vd ON Vd.ObjectGuid = er.ParentGuid

		WHERE (en.Date BETWEEN @StartDate AND @EndDate)
			AND en.Guid NOT IN (SELECT ObjectGuid FROM #FinalVisitsStates)
			AND en.Guid NOT IN (SELECT ObjectGuid FROM DistVd000)

	-------------------------------------------
	INSERT INTO #FinalVisitsStates --Insert the entries
		SELECT
			ISNULL(Vd.VistGuid, newid()),
			cu.Guid,
			d.Guid,
			1,
			en.Date,
			2,
			en.Guid
		FROM cu000 AS cu

		INNER JOIN en000 AS en ON cu.AccountGuid = en.AccountGuid	-- لمنع تكرار
		INNER JOIN ce000 as ce ON en.parentguid = ce.guid			-- السند و الفاتورة 
		INNER JOIN #EntryTable AS es ON es.Type = ce.TypeGuid
		INNER JOIN et000 AS et ON ce.TypeGuid = et.Guid
		INNER JOIN er000 as er ON ce.guid = er.entryguid			-- المتولد عنها 

		INNER JOIN DistSalesMan000 AS sm ON en.CostGuid = sm.CostGuid
		INNER JOIN Distributor000 AS d ON sm.Guid = d.PrimSalesmanGuid --To retrive the distributor associted with the current entry
		INNER JOIN #DistTable AS dt ON d.Guid = dt.DistGuid

		LEFT JOIN DistVd000 AS Vd ON Vd.ObjectGuid = en.Guid

		WHERE (en.Date BETWEEN @StartDate AND @EndDate) AND er.ParentGuid NOT IN (SELECT ObjectGuid FROM #Visits) --To prevent the same entry from being repeated more than one time (With a  visit and without a visit)
			AND ISNULL(Vd.VistGuid, 0x0) NOT IN (SELECT VisitGuid FROM #FinalVisitsStates)
			AND en.Guid NOT IN (SELECT ObjectGuid FROM #FinalVisitsStates)
			AND	((@Payment = '1' AND  et.FldDebit <> 0 AND et.FldCredit = 0)  --دائن
			  OR (@Receipt = '1' AND  et.FldDebit = 0 AND et.FldCredit <> 0)) --مدين


	
	--Insert the visits generated by manual Entries into the visits table to use the object guid in the following step
	--
	INSERT INTO #Visits
		SELECT
			0x0,
			2, 
			er.ParentGuid, -- أصل هذا السند يجب استخدامه عند إضافة الفواتير اليدوية لاحقا في حال تحديد الفواتير كزيارات غير فعالة. و ذلك لمنع تكرار فاتورة حالتها 0 مع سند متولد عن هذه الفاتورة حالته 1
			0x0,
			0x0,
			en.Date
		FROM cu000 AS cu
		--INNER JOIN ac000 AS ac ON cu.AccountGuid = ac.Guid
		INNER JOIN en000 AS en ON cu.AccountGuid = en.AccountGuid	-- لمنع تكرار
		INNER JOIN ce000 as ce ON en.parentguid = ce.guid			-- السند و الفاتورة 
		INNER JOIN #EntryTable AS es ON es.Type = ce.TypeGuid
		INNER JOIN et000 AS et ON ce.TypeGuid = et.Guid
		INNER JOIN er000 as er ON ce.guid = er.entryguid			-- المتولد عنها 

		INNER JOIN DistSalesMan000 AS sm ON en.CostGuid = sm.CostGuid
		INNER JOIN Distributor000 AS d ON sm.Guid = d.PrimSalesmanGuid --To retrive the distributor associted with the current entry
		INNER JOIN #DistTable AS dt ON d.Guid = dt.DistGuid

		WHERE (en.Date BETWEEN @StartDate AND @EndDate) AND er.ParentGuid NOT IN (SELECT ObjectGuid FROM #Visits) --To prevent the same entry from being repeated more than one time (With a  visit and without a visit)
			AND	((@Payment = '1' AND  et.FldDebit <> 0 AND et.FldCredit = 0)  --دائن
			  OR (@Receipt = '1' AND  et.FldDebit = 0 AND et.FldCredit <> 0)) --مدين


----------------------------------------------------------------------------
	-- Insert the inactive visits generated by manual bills and entries
	------------------------------------------------------------------------
	--Insert the inactive visits generated by manual bills
	INSERT INTO #FinalVisitsStates
		SELECT
			ISNULL(Vd.VistGuid, newid()),
			bu.CustGuid,
			d.Guid,
			0,
			bu.Date,
			3,
			bu.Guid
		FROM bu000 AS bu
		INNER JOIN bt000 AS bt ON bu.TypeGuid = bt.Guid
		INNER JOIN #BillTable AS bs ON bs.Type = bu.TypeGuid
		INNER JOIN DistSalesMan000 AS sm ON bu.CostGuid = sm.CostGuid
		INNER JOIN Distributor000 AS d ON sm.Guid = d.PrimSalesmanGuid --To retrive the distributor associted with the current bill
		INNER JOIN #DistTable AS dt ON d.Guid = dt.DistGuid
		LEFT JOIN DistVd000 AS Vd ON Vd.ObjectGuid = bu.Guid
		WHERE (bu.Date BETWEEN @StartDate AND @EndDate) AND bu.Guid NOT IN (SELECT ObjectGuid FROM #Visits) --To prevent the same bill from being repeated more than one time (With a  visit and without a visit)
				AND ISNULL(Vd.VistGuid, 0x0) NOT IN (SELECT VisitGuid FROM #FinalVisitsStates)
				AND ((bt.type NOT IN (3,4) AND ((@InBill = '0' AND bt.bIsInput = 1) OR (@OutBill = '0' AND bt.bIsOutput = 1)))
					OR (bt.type	  IN (3,4) AND ((@InStore = '0' AND bt.bIsInput = 1) OR (@OutStore = '0' AND bt.bIsOutput = 1))))
	
	--Add the visits generated by manual bills to Distvd000
	INSERT INTO DistVd000
		SELECT
			newid(),
			VisitGuid, --create a new visitguid
			3, --type = 3; bill
			ObjectGuid,
			1,
			'',
			''
		FROM #FinalVisitsStates AS fv
		WHERE ObjectType = 3 AND ObjectGuid NOT IN (SELECT ObjectGuid FROM DistVd000)

	--Insert the visits generated by manual bills into the visits table to use the object guid in the following step
	--
	INSERT INTO #Visits
		SELECT
			0x0,
			-1, --To indicate that this visit is not a real visit
			bu.Guid,
			0x0,
			0x0,
			bu.Date
		FROM bu000 AS bu
		INNER JOIN bt000 AS bt ON bu.TypeGuid = bt.Guid
		INNER JOIN #BillTable AS bs ON bs.Type = bu.TypeGuid
		INNER JOIN DistSalesMan000 AS sm ON bu.CostGuid = sm.CostGuid
		INNER JOIN Distributor000 AS d ON sm.Guid = d.PrimSalesmanGuid --To retrive the distributor associted with the current bill
		INNER JOIN #DistTable AS dt ON d.Guid = dt.DistGuid
		WHERE (bu.Date BETWEEN @StartDate AND @EndDate) AND bu.Guid NOT IN (SELECT ObjectGuid FROM #Visits) --To prevent the same bill from being repeated more than one time (With a  visit and without a visit)
				AND ((bt.type NOT IN (3,4) AND ((@InBill = '0' AND bt.bIsInput = 1) OR (@OutBill = '0' AND bt.bIsOutput = 1)))
					OR (bt.type	  IN (3,4) AND ((@InStore = '0' AND bt.bIsInput = 1) OR (@OutStore = '0' AND bt.bIsOutput = 1))))

	--Insert the inactive entries 
	INSERT INTO #FinalVisitsStates
		SELECT
			ISNULL(Vd.VistGuid, newid()),
			cu.Guid,
			d.Guid,
			0,
			en.Date,
			2,
			en.Guid
		FROM cu000 AS cu

		INNER JOIN en000 AS en ON cu.AccountGuid = en.AccountGuid	-- لمنع تكرار
		INNER JOIN ce000 as ce ON en.parentguid = ce.guid			-- السند و الفاتورة 
		INNER JOIN #EntryTable AS es ON es.Type = ce.TypeGuid
		INNER JOIN et000 AS et ON ce.TypeGuid = et.Guid
		INNER JOIN er000 as er ON ce.guid = er.entryguid			-- المتولد عنها 

		INNER JOIN DistSalesMan000 AS sm ON en.CostGuid = sm.CostGuid
		INNER JOIN Distributor000 AS d ON sm.Guid = d.PrimSalesmanGuid --To retrive the distributor associted with the current entry
		INNER JOIN #DistTable AS dt ON d.Guid = dt.DistGuid

		LEFT JOIN DistVd000 AS Vd ON Vd.ObjectGuid = en.Guid

		WHERE (en.Date BETWEEN @StartDate AND @EndDate) AND er.ParentGuid NOT IN (SELECT ObjectGuid FROM #Visits) --To prevent the same entry from being repeated if its parent bill is allready in the inactive visits list
			AND en.Guid NOT IN (SELECT ObjectGuid FROM #FinalVisitsStates)
			AND ISNULL(Vd.VistGuid, 0x0) NOT IN (SELECT VisitGuid FROM #FinalVisitsStates)
			AND	((@Payment = '0' AND  et.FldDebit <> 0 AND et.FldCredit = 0)  --دائن
			  OR (@Receipt = '0' AND  et.FldDebit = 0 AND et.FldCredit <> 0)) --مدين

	END

	SELECT
			VisitGuid,
			CustGuid,
			DistGuid,
			(CASE SUM(fvs.State) WHEN 0 THEN 0 ELSE 1 END) AS State,
			VisitDate
		FROM #FinalVisitsStates AS fvs
		INNER JOIN cu000 AS cu ON fvs.CustGuid = cu.Guid
		GROUP BY VisitGuid, CustGuid, DistGuid, VisitDate
/*
EXEC prcDistGetVisitsState '2009-7-12', '2009-7-13', 0x0, '5d67f3f5-0721-43bc-92a0-f8e574e4c689', 1, 0x0
*/
################################################################################
#END