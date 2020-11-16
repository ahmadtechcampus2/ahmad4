#########################################################	
CREATE  TRIGGER trg_DistLines000_DistLines
	ON [DistDistributionLines000] FOR INSERT
AS 
/*
This trigger is used to :
	update Route Value in Temp Table to use it  
*/
	IF @@ROWCOUNT = 0 RETURN 
	SET NOCOUNT ON 

	IF EXISTS (select * from dbo.sysobjects where id = object_id(N'[dbo].[DistTempDeleted]'))	         
	BEGIN
		Update DistTempDeleted 
		Set 
			Route1 = i.Route1,
			Route2 = i.Route2,
			Route3 = i.Route3,
			Route4 = i.Route4,
			Route1Time = i.Route1Time,
			Route2Time = i.Route2Time,
			Route3Time = i.Route3Time,
			Route4Time = i.Route4Time
		From 
			DistTempDeleted AS d 
			INNER JOIN inserted AS i On d.DistGuid = i.DistGuid AND d.CustGuid = i.CustGuid	
	END

#########################################################	
CREATE TRIGGER trg_ci000_DistLines
	ON [ci000] FOR INSERT, UPDATE, DELETE 
	NOT FOR REPLICATION
AS 
/*
This trigger is used to:
	- When deleted  Delete Cust From DisDistributionLines
	- When inserted Insert Cust To DistDistributionLines 
*/
	IF @@ROWCOUNT = 0 RETURN  
	SET NOCOUNT ON  
	DECLARE  
		@C_DISTS		CURSOR, 
		@C_CUSTS		CURSOR, 
		@DistGUID 	UNIQUEIDENTIFIER, 
		@SonGUID 	UNIQUEIDENTIFIER 
	 
	SET @DistGuid = 0x0 
	 
	IF NOT EXISTS (select * from dbo.sysobjects where id = object_id(N'[dbo].[DistTempDeleted]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)	          
	BEGIN 
		CREATE TABLE DistTempDeleted ([Guid] UNIQUEIDENTIFIER PRIMARY KEY, DistGuid UNIQUEIDENTIFIER, 
				CustGuid UNIQUEIDENTIFIER, Route1 INT, Route2 INT, Route3 INT, Route4 INT, Route1Time DATETIME, Route2Time DATETIME, Route3Time DATETIME, Route4Time DATETIME)
		INSERT INTO  DistTempDeleted SELECT TOP 0 Guid, DistGuid, CustGuid, Route1, Route2, Route3, Route4, Route1Time, Route2Time, Route3Time, Route4Time  FROM DistDistributionLines000           
	END 
	IF EXISTS(SELECT TOP 1 * FROM [deleted] AS [d] INNER JOIN [Distributor000] AS [s] ON [d].[ParentGUID] = [s].[CustomersAccGuid])   
	BEGIN 
		SET @C_DISTS = CURSOR FAST_FORWARD FOR  
			SELECT DISTINCT [s].[Guid] FROM [deleted] AS [d] INNER JOIN [Distributor000] AS [s] ON [d].[ParentGUID] = [s].[CustomersAccGuid] 
		OPEN @C_DISTS FETCH FROM @C_DISTS INTO @DistGuid 
		WHILE @@FETCH_STATUS = 0 
		BEGIN 
			SET @C_CUSTS = Cursor FAST_FORWARD FOR SELECT DISTINCT [SonGuid] FROM [deleted]  
			OPEN @C_CUSTS FETCH FROM @C_CUSTS INTO @SonGuid 
			WHILE @@Fetch_Status = 0 
			BEGIN 
				INSERT INTO DistTempDeleted  
							(Guid, DistGuid, CustGuid, Route1, Route2, Route3, Route4, Route1Time, Route2Time, Route3Time, Route4Time)
					SELECT 	l.Guid, l.DistGuid, l.CustGuid, l.Route1, l.Route2, l.Route3, l.Route4, l.Route1Time, l.Route2Time, l.Route3Time, l.Route4Time
					FROM [DistDistributionLines000] AS l 
						INNER JOIN [dbo].[fnGetCustsOfAcc] (@SonGuid)  AS F ON F.Guid = l.CustGuid 
						LEFT JOIN DistTempDeleted AS dl ON l.DistGuid = dl.DistGuid AND l.CustGuid = dl.CustGuid 
					WHERE 	l.DistGuid = @DistGuid  
							AND dl.Guid Is Null 
												 
				DELETE FROM [DistDistributionLines000] 
				WHERE  
					[DistGuid] = @DistGuid AND 
					[CustGuid] IN (SELECT [Guid] FROM [dbo].[fnGetCustsOfAcc] (@SonGuid) ) 
				FETCH FROM @C_CUSTS INTO @SonGuid 
			END 
			CLOSE @C_CUSTS  
			FETCH FROM @C_DISTS INTO @DistGuid 
		END 
		CLOSE @C_DISTS  
		DEALLOCATE @C_DISTS DEALLOCATE @C_CUSTS 
	END 
	 
	IF EXISTS(SELECT TOP 1 * FROM [inserted] AS [i] INNER JOIN [Distributor000] AS [s] ON [i].[ParentGUID] = [s].[CustomersAccGuid])  
	BEGIN 
		SET @C_DISTS = CURSOR FAST_FORWARD FOR  
			SELECT DISTINCT [s].[Guid] FROM [inserted] AS [i] INNER JOIN [Distributor000] AS [s] ON [i].[ParentGUID] = [s].[CustomersAccGuid] 
		OPEN @C_DISTS FETCH FROM @C_DISTS INTO @DistGuid 
		WHILE @@FETCH_STATUS = 0 
		BEGIN 
			SET @C_CUSTS = CURSOR FAST_FORWARD FOR SELECT DISTINCT [sonGuid] From [inserted] 
			OPEN @C_CUSTS FETCH FROM @C_CUSTS INTO @SonGuid 
			WHILE @@Fetch_Status = 0  
			BEGIN 
				INSERT INTO [DistDistributionLines000]  
					(GUID, DistGUID, CustGUID, Route1, Route2, Route3,  Route4, Route1Time, Route2Time, Route3Time, Route4Time) 
				SELECT  
					newId(), @DistGuid, [F].[Guid], ISNULL(dl.Route1, 0), ISNULL(dl.Route2, 0), ISNULL(dl.Route3, 0), ISNULL(dl.Route4, 0), ISNULL(dl.Route1Time,0), ISNULL(dl.Route2Time,0), ISNULL(dl.Route3Time,0), ISNULL(dl.Route4Time, 0) 
				FROM  
					[dbo].[fnGetCustsOfAcc] (@SonGuid) AS [F]   
					LEFT JOIN [DistDistributionLines000] AS [l] ON [l].[CustGuid] = [F].[Guid] AND [l].[DistGUID] = @DistGuid 
					LEFT JOIN DistTempDeleted AS dl ON dl.CustGuid = F.Guid AND dl.DistGuid = @DistGuid 
				WHERE  
					l.Guid IS NULL 
				FETCH FROM @C_CUSTS INTO @SonGuid 
			END 
			CLOSE @C_CUSTS 
			FETCH FROM @C_DISTS INTO @DistGuid 
		END 
		CLOSE @C_DISTS  
		DEALLOCATE @C_DISTS DEALLOCATE @C_CUSTS 
	END 
#########################################################	
CREATE TRIGGER trg_cu000_DistLines
	ON [cu000] FOR INSERT, DELETE  
	NOT FOR REPLICATION
AS  
/*
This trigger used to:
	- Delete Cust From DistributionLines000 
	- Insert Cust To DistributionLines000 
*/
	IF @@ROWCOUNT = 0 RETURN   
	SET NOCOUNT ON   


	IF EXISTS(SELECT TOP 1 * FROM [deleted])
	BEGIN
		DELETE [DistDistributionLines000]
			FROM [DistDistributionLines000] AS [l] INNEr JOIN [deleted] as [d] ON [d].[Guid] = [l].[CustGUID]
	END

	IF EXISTS(SELECT TOP 1 * FROM [inserted])
	BEGIN
		DECLARE   
			@C_DISTS	CURSOR,  
			@C_Acc		CURSOR,  
			@DistGUID 	UNIQUEIDENTIFIER,  
			@AccGUID 	UNIQUEIDENTIFIER  
		CREATE TABLE #CustsAccGuid 
			( [DistGuid] UNIQUEIDENTIFIER, [CustsAccGuid] UNIQUEIDENTIFIER) 

		SET @C_Acc = CURSOR FAST_FORWARD FOR 	
			SELECT [AccountGuid] FROM [inserted]
		OPEN @C_Acc FETCH FROM @C_Acc INTO @AccGuid
		WHILE @@FETCH_STATUS = 0
		BEGIN
			INSERT INTO [#CustsAccGuid] ( [DistGUID], [CustsAccGUID])
			Select [d].[GUID],  [ci].[ParentGuid]
			FROM 
				[dbo].[fnGetAccountParents] (@AccGUID) AS [f] 
				INNER JOIN [ci000] 		AS [ci] ON [ci].[SonGUID] = [f].[GUID]
				INNER JOIN [Distributor000] 	AS [d] ON [d].[CustomersAccGuid] = [ci].[ParentGUID]
			FETCH FROM @C_Acc INTO @AccGuid
		END
		CLOSE @C_Acc DEALLOCATE @C_Acc
		SET @C_Dists = CURSOR FAST_FORWARD FOR
			SELECT DISTINCT [DistGUID] From [#CustsAccGuid]
		OPEN @C_Dists FETCH FROM @C_Dists INTO @DistGuid
		WHILE @@FETCH_STATUS = 0
		BEGIN
			INSERT INTO [DistDistributionLines000]   
				( [GUID], [DistGUID], [CustGUID], [Route1], [Route2], [Route3],  [Route4])  
			SELECT   
				newId(), @DistGuid, [i].[Guid], 0, 0, 0, 0
			FROM   
				[inserted] AS [i] 
				LEFT JOIN [DistDistributionLines000] AS [l] ON [l].[CustGuid] = [i].[Guid] AND [l].[DistGUID] = @DistGuid  
			WHERE   
				[l].[Guid] IS NULL  

			FETCH FROM @C_Dists INTO @DistGuid
		END
		CLOSE @C_Dists DEALLOCATE @C_Dists
	END
#########################################################	
#END