###########################################################################
CREATE PROCEDURE prcEntry_post
	@GUID [UNIQUEIDENTIFIER] = NULL, 
	@QF [INT] = 1 
AS  
/*  
this procedure  
	-- is resposible for affecting account for posting and unposting of entries  
	-- is usually called from ce triggers  
	-- is also called from prcEntry_rePost, where @GUID is null  
*/  
	DECLARE @t TABLE ([account] [UNIQUEIDENTIFIER], [debit] [FLOAT], [credit] [FLOAT], [level] INT,[ParentGuid] UNIQUEIDENTIFIER)  
	DECLARE @cu TABLE ([customer] [UNIQUEIDENTIFIER], [debit] [FLOAT], [credit] [FLOAT])
	DECLARE @j TABLE ([jobcost] [UNIQUEIDENTIFIER], [debit] [FLOAT], [credit] [FLOAT], [level] INT,[ParentGuid] UNIQUEIDENTIFIER)  
	DECLARE @level [INT], @cnt INT  
	set  @level = 0
	-- check to see if this is a rePost:  
	IF @GUID IS NULL -- the procedure is being called from prcEntry_rePost  
	BEGIN
		INSERT INTO @t ([account],[debit],[credit],[level],[ParentGuid]) 
			SELECT [enAccount], SUM([enDebit]), SUM([enCredit]), @level ,a.ParentGuid
				FROM [vwCeEn] INNER JOIN AC000 a ON a.Guid = enAccount
			WHERE [ceIsPosted]= 1  
			GROUP BY [enAccount],a.ParentGuid

		INSERT INTO @cu ([customer], [debit], [credit]) 
			SELECT [enCustomerGUID], SUM([enDebit]), SUM([enCredit])
			FROM 				
				cu000 cu
				INNER JOIN ac000 ac ON ac.GUID = cu.AccountGUID 
				INNER JOIN [vwCeEn] ON cu.GUID = enCustomerGUID AND ac.GUID = enAccount
			WHERE [ceIsPosted] = 1  
			GROUP BY [enCustomerGUID]
		
		INSERT INTO @j ([jobcost],[debit],[credit],[level],[ParentGuid]) 
			SELECT [enCostPoint], SUM([enDebit]), SUM([enCredit]), @level ,CO.ParentGUID
				FROM [vwCeEn] INNER JOIN CO000 CO ON CO.Guid = [enCostPoint]
			WHERE [ceIsPosted]= 1  
			GROUP BY [enCostPoint],CO.ParentGUID
	END
	ELSE -- the procedure is being called for a sigle entry, usally from trg_ce000_update  
	BEGIN
		INSERT INTO @t ([account], [debit], [credit], [level], [ParentGuid] )  
		SELECT [accountGUID], @QF * SUM(en.[debit]), @QF * SUM(en.[credit]), @level, a.ParentGuid
		FROM 
			[en000] en 
			INNER JOIN AC000 a ON en.AccountGUID = a.Guid
		WHERE 
			en.[parentGUID] = @GUID  
		GROUP BY 
			[accountGUID],
			a.ParentGuid 

		INSERT INTO @cu ([customer], [debit], [credit]) 
			SELECT en.[CustomerGUID], @QF * SUM(en.[debit]), @QF * SUM(en.[credit])
			FROM 
				cu000 cu 
				INNER JOIN ac000 ac ON ac.Guid = cu.AccountGUID 
				INNER JOIN [en000] en ON cu.Guid = en.CustomerGUID AND ac.Guid = en.AccountGUID				
			WHERE 
				en.[parentGUID] = @GUID  
			GROUP BY en.[CustomerGUID]
		
		INSERT INTO @j([jobcost],[debit],[credit],[level],[ParentGuid] )  
			SELECT en.[CostGUID], @QF * SUM(en.[debit]), @QF * SUM(en.[credit]), @level, CO.ParentGUID
			FROM [en000]  en INNER JOIN CO000 CO ON CO.Guid = en.[CostGUID]
			WHERE en.[parentGUID] = @GUID  
			GROUP BY en.[CostGUID],CO.ParentGUID
	END
	-- notify concerned accounts: 
	SET @cnt  =1
	WHILE @cnt > 0
	BEGIN
		SET @level = @level + 1
		INSERT INTO @t ([account],[debit],[credit],[level],[ParentGuid]) 
			SELECT t.[ParentGuid],SUM(t.[debit]),SUM(t.[credit]),@level,a.[ParentGuid]
			FROM @t t INNER JOIN [ac000] a ON t.[ParentGuid] = a.[Guid]
			WHERE [level] = @level  -1
			GROUP BY t.[ParentGuid],a.[ParentGuid]
		SET @cnt = @@ROWCOUNT
	END
	
	UPDATE [ac000] SET  
		[debit] = [a].[debit] + [t].[debit],  
		credit = [a].[credit] + [t].[credit]  
	FROM  
		[ac000] [a] INNER JOIN @t AS [t]  
		ON [a].[GUID] = [t].[account] 

	UPDATE [cu000] SET  
		[debit] = [cu].[debit] + [c].[debit],  
		credit = [cu].[credit] + [c].[credit]  
	FROM  
		[cu000] [cu] INNER JOIN @cu AS [c]  
		ON [cu].[GUID] = [c].[customer] 

	-- notify concerned JobCosts: 
	SET @level = 0
	SET @cnt  =1
	WHILE @cnt > 0
	BEGIN
		SET @level = @level + 1
		INSERT INTO @j ([jobcost],[debit],[credit],[level],[ParentGuid]) 
			SELECT j.[ParentGuid],SUM(j.[debit]),SUM(j.[credit]),@level,co.[ParentGuid]
			FROM @j j INNER JOIN [co000] co ON j.[ParentGuid] = co.[Guid]
			WHERE [level] = @level  -1
			GROUP BY j.[ParentGuid],co.[ParentGuid]
		SET @cnt = @@ROWCOUNT
	END

	UPDATE [co000] SET  
		[debit] = [co].[debit] + [j].[debit],  
		[Credit] = [co].[credit] + [j].[credit]  
	FROM  
		[co000] [co] INNER JOIN @j AS [j]  
		ON [co].[GUID] = [j].[jobcost]
###########################################################################
CREATE PROC prcEntry_Post1
	@ceGUID [UNIQUEIDENTIFIER], 
	@bPost [BIT] 
AS  
	SET NOCOUNT ON  
	UPDATE [ce000] SET [IsPosted] = @bPost WHERE [guid] = @ceGUID AND [IsPosted] <> @bPost 
###########################################################################
#END
