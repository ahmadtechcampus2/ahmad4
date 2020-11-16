##  «·≈Ã—«¡ »Õ”«» Õ—ﬂ… Õ”«» »Ì‰  «—ÌŒÌ‰ »«·‰”»… ·Õ”«» ›—⁄Ì „⁄ ≈ŸÂ«— «·Õ”«» «·„ﬁ«»· 
#######################################################################################
CREATE PROCEDURE prcCalcEntries
	@StartDate DATETIME,	        
	@EndDate DATETIME,		        
	@AccPtr INT,			-- ??????  ???? ?? ???? ???? ?? ?????        
	@CurPtr INT,			-- ?????? ??????? ?? ???????        
	@CurVal FLOAT,			-- ??? ??????? ?????? ?? ???????        
	@UserCeSec INT,			-- ?????? ??????? ?????? ?????        
	@Class INT,			-- ????? ??????? ?? ???????        
	@ShowUnPosted INT,		-- ????? ??????? ????? ?????         
	@InvString NVARCHAR(256),--  ???? ???? ????? ??? ???  ??? ???? ?? ???? ????? ????? ?????         
	@InvAcc INT = 0,			-- ?????? ??????? ?????? ?? ???????        
	@CheckInv INT = 0,			-- =0 ??? ????? ?????? ???????        
	@CostPoint INT = 0,			-- =0 ??? ????? ???? ????        
	@ShowCost INT = 0,			-- =0 ??? ????? ???? ????        
	@Note1 NVARCHAR(256),	-- ????        
	@Note2 NVARCHAR(256),	-- ?? ????        
	@CalcPrevBal INT = 0,	-- ???? ?????? ??????        
	@ShowCur  INT = 0,		-- ?????? ?????? ???????? ?? ????? ????        
	@CurLevel INT,		-- ??????? ?????? ?? ???????        
	@SumAcc	INT,		-- 1 SumAcc calculate by account in the same entry  
	@CheckContain INT	--  0 Show PrvBalance Without CheckContain  
AS          
CREATE TABLE #t_Acc(        
			Number		INT, --NOT NULL PRIMARY KEY,        
			Parent		INT,        
			AccName		NVARCHAR(256) COLLATE ARABIC_CI_AI,         
			[Level]		INT,  
			CiNumber	INT,  
			CiNum1		INT
			)        
-- this is the basic result table:    
CREATE TABLE #t_Result(        
			EnDate	DATETIME,        
			enDebit	FLOAT		DEFAULT 0,        
			enCredit FLOAT		DEFAULT 0,    
			enCurDebit FLOAT	DEFAULT 0,        
			enCurCredit FLOAT	DEFAULT 0,        
			InvName NVARCHAR(256) COLLATE ARABIC_CI_AI	DEFAULT '',        
			DetailCnt INT		DEFAULT 0,        
			enParentNumber INT	DEFAULT 0,        
			enParentType INT	DEFAULT 0,        
			CostPoint INT		DEFAULT 0,        
			EnCurPtr INT		DEFAULT 0,        
			EnCurVal FLOAT		DEFAULT 0,             
			AccPtr INT		DEFAULT 0,          
			Parent INT		DEFAULT 0,        
			AccName NVARCHAR(256) COLLATE ARABIC_CI_AI	DEFAULT '',           
			enNotes NVARCHAR(256) COLLATE ARABIC_CI_AI	DEFAULT '',          			        
			[Level]  INT		DEFAULT 0,        
			CurLevel INT		DEFAULT 0,        
			RecType BIT		DEFAULT 0,     
			PrevBal FLOAT   	DEFAULT 0,    
			CeSecurity INT		DEFAULT 0,     
			)        
-- this table will hold balances in phase 1, then prev balances in phase 2:    
CREATE TABLE #t_Balances(        
			EnDate	DATETIME,        
			enDebit	FLOAT		DEFAULT 0,        
			enCredit FLOAT		DEFAULT 0,    
			enCurDebit FLOAT	DEFAULT 0,        
			enCurCredit FLOAT	DEFAULT 0,        
			InvName NVARCHAR(256) COLLATE ARABIC_CI_AI	DEFAULT '',        
			DetailCnt INT		DEFAULT 0,        
			enParentNumber INT	DEFAULT 0,        
			enParentType INT	DEFAULT 0,        
			CostPoint INT		DEFAULT 0,        
			EnCurPtr INT		DEFAULT 0,        
			EnCurVal FLOAT		DEFAULT 0,             
			AccPtr INT			DEFAULT 0,          
			Parent INT			DEFAULT 0,        
			AccName NVARCHAR(256) COLLATE ARABIC_CI_AI	DEFAULT '',           
			enNotes NVARCHAR(256) COLLATE ARABIC_CI_AI	DEFAULT '',          			        
			[Level]  INT		DEFAULT 0,        
			CurLevel INT		DEFAULT 0,        
			RecType BIT		DEFAULT 0,     
			PrevBal FLOAT   	DEFAULT 0,      
			ceSecurity INT		DEFAULT 0      			  
			)        
CREATE TABLE #t_SecViol(  
			SecType INT,  
			SecValue  INT  
			)  

-- Table Contains Accounts in the fnGetAcDescList join with AccTbl
CREATE TABLE #t_AcTbl(
			Number		INT, --NOT NULL PRIMARY KEY,        
			Parent		INT,        
			AccName		NVARCHAR(256) COLLATE ARABIC_CI_AI,         
			[Level]		INT,  
			AcType		INT 			        
		)

-- fetch #t_AcTbl
	INSERT INTO #t_AcTbl
		SELECT         
			fn.Number,         
			vw.acParent,         
			(vw.acCode +'-'+vw.acName),        
			fn.Level,
			vw.AcType  
		FROM        
			fnGetAcDescList(@AccPtr) AS fn INNER JOIN vwAc AS vw ON fn.Number = vw.acNumber

--SELECT * FROM #t_AcTbl

DECLARE @AcType INT     
SET @AcType = (SELECT acType FROM vwAc WHERE acNumber = @AccPtr)  


-- Table Contains detail Accounts for the Composite Accounts
CREATE TABLE #t_ciTbl(  
			Number INT,  
			Num1  INT  
			)  

-- fetch #t_ciTbl
INSERT INTO #t_ciTbl
	SELECT 
		Number,Num1 
	FROM 
		ci000 
	WHERE
		Type =1  
		AND ISNULL(Num2,0) = 0  
		AND Number IN ( SELECT Number FROM #t_AcTbl WHERE acType = 4 )   

--Select * from #t_ciTbl

-- fetch #t_Acc    
IF( @AcType <> 4 )  
BEGIN
	 INSERT INTO #t_Acc        
		SELECT         
			t_ac.Number,
			t_ac.Parent,
			t_ac.AccName,
			t_ac.Level,0,0
		FROM 
			#t_AcTbl as t_ac 
END
ELSE
BEGIN
	 INSERT INTO #t_Acc        
		SELECT         
			t_ac.Number,
			t_ac.Parent,
			t_ac.AccName,
			t_ac.Level,
			ISNULL(t_Ci.Number, 0),
			ISNULL(t_Ci.Num1, 0)
		FROM 
			#t_AcTbl as t_ac left join #t_ciTbl as t_ci
			ON t_ac.Number = t_ci.Num1
END

--SELECT * FROM #t_Acc
DECLARE @SqlString NVARCHAR(max)           

--select * from #t_Acc         

-- update the parent to composte parent  
IF( @AcType = 4 )  
BEGIN  
	UPDATE #t_Acc SET         
		parent  = ciNumber   
	where    
		ciNum1 > 0 and ciNumber > 0   
END  

-------------------------------------------------------------------------------------  
-------------------------------------------------------------------------------------  
IF( @SumAcc = 0 )        
BEGIN        
	SET @SqlString ='           
	INSERT INTO #t_Result    
	SELECT           
		en.EnDate,    
		 CASE enCurrencyPtr  WHEN ' + CAST(@CurPtr AS NVARCHAR)          
		+' THEN (en.enDebit / enCurrencyVal)        
		ELSE          
			(en.enDebit / '+CAST(@CurVal AS NVARCHAR)          
		+' ) END AS enDebit,          
		CASE enCurrencyPtr  WHEN ' + CAST(@CurPtr AS NVARCHAR)          
		+' THEN (en.enCredit / enCurrencyVal)          
		ELSE          
			(en.enCredit / ' + CAST(@CurVal AS NVARCHAR)          
		+' ) END AS enCredit,'          
	IF( @ShowCur > 0 )         
	BEGIN         
		SET @SqlString = @SqlString + 'en.EnDebit / enCurrencyVal AS CurCardDebit,    
				en.EnCredit / enCurrencyVal AS CurCardCredit,'        
	END           
	ELSE        
		SET @SqlString = @SqlString +'0, 0,'		        
	        
	IF( @CheckInv = 1 )          
	BEGIN    
		SET @SqlString = @SqlString +' (SELECT ISNULL(acCode+''-''+acName,'''') FROM vwAc WHERE acNumber = en.enContraAcc )As InvName,'  
		--DetailCnt----------------------           
		+'CASE en.enDebit           
			WHEN 0 THEN enCountOfDebitors          
		ELSE enCountOfCreditors          
			END As DetailCnt, '          
	END         
	ELSE        
		SET @SqlString = @SqlString +''''',0,'        
	        
	SET @SqlString = @SqlString +'ceNumber AS enParentNumber,          
		en.ceType AS enParentType,'        
	IF @ShowCost <> 0            
		SET @SqlString = @SqlString +'enCostPoint as CostPoint, '    		           
	ELSE        
		SET @SqlString = @SqlString +'0,'        
	SET @SqlString = @SqlString +'en.enCurrencyPtr AS EnCurPtr,         
		en.enCurrencyVal AS EnCurVal,         
		en.enAccount AS AccPtr,          
		en.acParent AS Parent,          
		(en.acCode +''-''+ en.acName) AS AccName,        
		en.enNotes,  		        
		-1,        
		0,        
		0,        
		0,ceSecurity  
	FROM           
		vwExtended_En_Statistics AS en	INNER JOIN #t_Acc AS Rt    
		ON en.enAccount = Rt.Number        
	WHERE	         		  
		en.EnDate Between '''+CAST(@StartDate  AS NVARCHAR)+ ''' AND ''' + CAST(@EndDate  AS NVARCHAR)+ ''''          
	IF @CostPoint > 0            
		SET @SqlString = @SqlString + ' AND enCostPoint IN (SELECT Number From  fnGetCostsList( '+ CAST( @CostPoint AS NVARCHAR) + '))'          
		        
	IF @Class  > 0            
		SET @SqlString = @SqlString + ' AND enClass = '+ CAST(@Class AS NVARCHAR)          
	IF @ShowUnPosted = 1          
		SET @SqlString = @SqlString + ' AND ceIsPosted <> 0 '        	  
	IF( ( @CheckInv = 1 )  and  (@InvAcc > 0) )          
		SET @SqlString = @SqlString + ' AND enContraAcc IN (SELECT Number FROM fnGetAccByLevel( '+ CAST (@InvAcc AS NVARCHAR) + ',0,4) )'  
		  
	IF ISNULL(@Note1, '') <> ''           
		SET @SqlString = @SqlString + ' AND (enNotes LIKE ''%'+ @Note1 +'%''' + ' OR       
											ceNotes LIKE ''%'+ @Note1 +'%'')'        
	IF ISNULL(@Note2, '') <> ''           
		SET @SqlString = @SqlString + ' AND (enNotes NOT LIKE ''%'+ @Note2 +'%''' + ' AND        
											ceNotes NOT LIKE ''%'+ @Note2 +'%'')' 	       
	SET @SqlString = @SqlString + ' ORDER BY  en.EnDate, ceType, ceNumber, EnNumber, enAccount'          
END        
--------------------------------------------------------------------------------------------        
--------------------------------------------------------------------------------------------        
ELSE        
IF( @SumAcc > 0 )        
BEGIN        
SET @SqlString ='           
	INSERT INTO #t_Result    
	SELECT           
		en.EnDate,          
		CASE enCurrencyPtr  WHEN ' + CAST(@CurPtr AS NVARCHAR)           
		+' THEN ( SUM(en.enDebit / enCurrencyVal) )           
		ELSE           
			(SUM(en.enDebit/ ' + CAST(@CurVal AS NVARCHAR)         
		+') ) END AS EnDebit,         
		CASE enCurrencyPtr  WHEN ' + CAST(@CurPtr AS NVARCHAR)           
		+' THEN (SUM(en.enCredit / enCurrencyVal) )           
		ELSE           
			(SUM(en.enCredit/ '+CAST(@CurVal AS NVARCHAR)           
		+' ))END AS EnCredit,'           
		IF( @ShowCur > 0 )           
		BEGIN         
			SET @SqlString = @SqlString + 'SUM(en.EnDebit / enCurrencyVal) AS CurCardDebit,    
				SUM(en.EnCredit / enCurrencyVal) AS CurCardCredit,'        
		END         
		else        
			SET @SqlString = @SqlString +'0, 0,'		        
		IF( @CheckInv = 1 )           
		BEGIN   
			SET @SqlString = @SqlString +' (SELECT ISNULL(acCode+''-''+acName,'''') FROM vwAc WHERE acNumber = en.enContraAcc )As InvName,'  
		--DetailCnt----------------------        
			+' CASE SUM(en.enDebit)           
				WHEN 0 THEN enCountOfDebitors          
				ELSE enCountOfCreditors          
				END As DetailCnt, '          
		END	 		-- end IF( @CheckInv = 1 )           
		ELSE        
			SET @SqlString = @SqlString +''''',0,'        
	        
		SET @SqlString = @SqlString +'ceNumber AS enParentNumber,            
			ceType AS enParentType,  '          
		IF @ShowCost <> 0            
			SET @SqlString = @SqlString +'enCostPoint AS CostPoint, '    		        
		ELSE        
			SET @SqlString = @SqlString +'0,'        
		SET @SqlString = @SqlString +'enCurrencyPtr AS EnCurPtr,         
			enCurrencyVal AS EnCurVal,         
			enAccount AS AccPtr,        
			acParent AS Parent,        
			(acCode +''-''+ acName) AS	AccName,'            
		SET @SqlString =@SqlString +'         
			CASE COUNT(*) WHEN 1 THEN           
			(            
				SELECT TOP 1 enNotes FROM vwEn AS en2            
				WHERE en2.enParent = ceNumber            
				AND en2.enType = ceType            
				AND en2.enAccount = acNumber            
			)            
			ELSE         
				'''+ @InvString + '''            
			END AS EnNotes,        
			-1,        
			0,        
			0,        
			0,ceSecurity    		     
		FROM            
			vwExtended_En_Statistics AS en	INNER JOIN  #t_Acc AS Rt    
			ON en.enAccount = Rt.Number        
		WHERE	            
			en.EnDate Between '''+CAST(@StartDate  AS NVARCHAR)+ ''' AND ''' + CAST(@EndDate  AS NVARCHAR)+ ''''            
		IF @CostPoint > 0           
			SET @SqlString = @SqlString + ' AND enCostPoint IN (SELECT NUMBER FROM fnGetCostsList( '+ CAST( @CostPoint AS NVARCHAR) + ') )'            
		IF @Class  > 0            
			SET @SqlString = @SqlString + ' AND enClass = '+ CAST(@Class AS NVARCHAR)            
		IF @ShowUnPosted = 1           
			SET @SqlString = @SqlString + ' AND ceIsPosted <> 0'           
		IF( ( @CheckInv = 1 )  and  (@InvAcc > 0) )          
			SET @SqlString = @SqlString + ' AND enContraAcc IN (SELECT Number FROM fnGetAccByLevel( '+ CAST (@InvAcc AS NVARCHAR) + ',0,4))'  
		IF ISNULL(@Note1, '') <> ''           
			SET @SqlString = @SqlString + ' AND (enNotes LIKE ''%'+ @Note1 +'%''' + ' OR       
												ceNotes LIKE ''%'+ @Note1 +'%'')'        
		IF ISNULL(@Note2, '') <> ''           
			SET @SqlString = @SqlString + ' AND (enNotes NOT LIKE ''%'+ @Note2 +'%''' + ' AND        
												ceNotes NOT LIKE ''%'+ @Note2 +'%'')'        
		SET @SqlString = @SqlString +            
			' GROUP BY            
				enAccount,           
				acNumber,           
				acparent,        
				acName,        
				acCode,           
				ceNumber,           
				ceType,           
				en.enDate,  
				enCountOfDebitors,           
				enCountOfCreditors,  
				enCurrencyPtr,         
				enCurrencyVal,         
				acCurrencyPtr,         
				acCurrencyVal,  
				ceSecurity'            
		IF @ShowCost <> 0           
			SET @SqlString = @SqlString +',enCostPoint '           
		IF( @CheckInv = 1 )           
			SET @SqlString = @SqlString +',enContraAcc '           
		SET @SqlString = @SqlString + ' ORDER BY en.EnDate, ceType, ceNumber,enAccount'           
END        
Exec(@SqlString)        
DECLARE @SecRec AS INT  
SET @SecRec = (select Count(*) from #t_Result where ceSecurity > @UserCeSec)  
INSERT INTO #t_SecViol  
VALUES(1, @SecRec)  
Delete from #t_Result where ceSecurity > @UserCeSec  
-- step5: fetch previouse balances:    
----------------------------------------------------------------------------------    
DECLARE @Cnt INT        
SET @Cnt = (SELECT Count(*) FROM #t_Result)        
IF @Cnt > 0        
BEGIN        
-- add Acc has movement with its level , but it's RecType = 1  
INSERT INTO #t_Result        
	SELECT         
		'',        
		0,        
		0,        
		0,        
		0,        
		'',        
		0,        
		0,        
		0,        
		0,        
		0,        
		0,         
		Number,          
		Parent,        
		AccName,          
		'',  			        
		Level,        
		0,        
		1,        
		0,0  
	FROM #t_Acc        
	WHERE Number IN (SELECT AccPtr FROM #t_Result where RecType = 0)        
   
IF( @CalcPrevBal > 0 )    
BEGIN    
	SET @SqlString = '    
		INSERT INTO #t_Balances (AccPtr, Parent, AccName, Level, ceSecurity ,PrevBal)    
			SELECT          
				enAccount,    
				Parent,    
				AccName,         
				Level, ceSecurity,   			       
				ISNULL( SUM(FixedEnDebit - FixedEnCredit),0) AS Balance    
			FROM  fnCeEn_Fixed('         
				+ CAST(@CurPtr AS NVARCHAR)+', '+CAST(@CurVal AS NVARCHAR)+')    
				 	INNER JOIN	#t_Acc AS Rt    
					ON enAccount = Rt.Number					     
			where '          
			+ ' EnDate < '''+CAST(@StartDate  AS NVARCHAR)+ ''''         
			IF @Class  > 0          
				SET @SqlString = @SqlString + ' AND enClass = '+ CAST(@Class AS NVARCHAR)         
			IF @ShowUnPosted = 1          
				SET @SqlString = @SqlString + ' AND ceIsPosted <> 0'         
			IF @CheckContain > 0   
			BEGIN  
				IF ISNULL(@Note1, '') <> ''         
					SET @SqlString = @SqlString + ' AND (enNotes LIKE ''%'+ @Note1 +'%''' + ' OR       
													ceNotes LIKE ''%'+ @Note1 +'%'')'        
				IF ISNULL(@Note2, '') <> ''         
					SET @SqlString = @SqlString + ' AND (enNotes NOT LIKE ''%'+ @Note2 +'%'' ' + ' AND     													ceNotes NOT LIKE ''%'+ @Note2 +'%'')' 	       
			END  
			SET @SqlString = @SqlString +'GROUP BY enAccount,Parent,AccName,Level,ceSecurity '    
EXEC(@SqlString)    
DECLARE @SecPrevRec AS INT  
SET @SecPrevRec = (SELECT count(*) FROM #t_Balances WHERE ceSecurity > @UserCeSec )  
INSERT INTO #t_SecViol  
VALUES(2, @SecPrevRec)  
-- delete rec that the user cant see it  
DELETE FROM #t_Balances  
WHERE  ceSecurity > @UserCeSec  
-- step6: Update t_result with previouse balances:    
	UPDATE #t_Result   
		SET PrevBal = b.SumBal 
	FROM    
		#t_Result AS t INNER JOIN ( select AccPtr,Sum(PrevBal) as SumBal from #t_Balances Group BY AccPtr) AS b    
		ON t.AccPtr = b.AccPtr    
	WHERE    
		t.RecType = 1    
	    
	DELETE #t_Balances     
	FROM     
		#t_Result AS t INNER JOIN #t_Balances AS b    
		ON t.AccPtr = b.AccPtr    
	    
-- insert acc has prevbal but has'nt movement    
	INSERT INTO #t_Result (AccPtr, Parent, AccName, Level, PrevBal,RecType)    
		SELECT    
			AccPtr,	    
			Parent,    
			AccName,    
			Level,	    
			PrevBal,    
			1            
		FROM    
			#t_Balances    
END    
-- update RecType 0 with Level:        
UPDATE #t_Result SET        
	Level = (SELECT Top 1 Level FROM #t_Result AS r2 WHERE r2.AccPtr = r1.AccPtr AND r2.RecType = 1)+1        
FROM #t_Result AS r1 WHERE r1.RecType = 0        
-- update RecType 1 with SumDebit and SumCredit:        
SET @SqlString ='          
UPDATE #t_Result SET        
	EnDebit  = (SELECT Sum(EnDebit)  FROM #t_Result AS r2 WHERE r2.AccPtr = r1.AccPtr AND r2.RecType = 0),        
	EnCredit = (SELECT Sum(EnCredit) FROM #t_Result AS r2 WHERE r2.AccPtr = r1.AccPtr AND r2.RecType = 0)'        
IF( @ShowCur > 0 )         
	SET @SqlString = @SqlString +', enCurDebit  = (SELECT Sum(enCurDebit)  FROM #t_Result AS r2 WHERE r2.AccPtr = r1.AccPtr AND r2.RecType = 0),	        
	enCurCredit = (SELECT Sum(enCurCredit) FROM #t_Result AS r2 WHERE r2.AccPtr = r1.AccPtr AND r2.RecType = 0)'        
SET @SqlString = @SqlString +'        
		FROM #t_Result AS r1 WHERE r1.RecType = 1'        
EXEC( @SqlString)         
DECLARE @Level INT        
SET @Level = 0        
	WHILE 1 = 1          
	BEGIN        
		-- Inc level  	        
		SET @Level = @Level + 1          
		INSERT INTO #t_Result        
		SELECT         
			'', 0, 0, 0, 0,'',0,  
			0, 0, 0, 0, 0, Number, Parent, AccName, '',  			        
			Level, @Level, 1, 0, 0        
		FROM   
			#t_Acc        
		WHERE   
			Number IN (SELECT Parent FROM #t_Result WHERE CurLevel = @Level - 1)        
		IF @@ROWCOUNT = 0         
		BEGIN  
			-- Add Composite Account  
			BREAK;      			  
		END  
		SET @SqlString ='          
			UPDATE #t_Result SET    			    
				EnDebit  = (SELECT Sum(EnDebit)  FROM #t_Result AS r2 WHERE r2.Parent = r1.AccPtr AND r2.RecType = 1),        
				EnCredit = (SELECT Sum(EnCredit) FROM #t_Result AS r2 WHERE r2.Parent = r1.AccPtr AND r2.RecType = 1)'        
		IF( @ShowCur > 0 )         
				SET @SqlString = @SqlString +', enCurDebit  = (SELECT Sum(enCurDebit)  FROM #t_Result AS r2 WHERE r2.Parent = r1.AccPtr AND r2.RecType = 1),        
				enCurCredit = (SELECT Sum(enCurCredit) FROM #t_Result AS r2 WHERE r2.Parent = r1.AccPtr AND r2.RecType = 1)'        
		IF( @CalcPrevBal > 0 )  
				SET @SqlString = @SqlString +', PrevBal = (SELECT SUM(PrevBal) FROM #t_Result AS r2 WHERE r2.Parent = r1.AccPtr AND r2.RecType = 1)'        
		SET @SqlString = @SqlString +'        
			FROM         
				#t_Result AS r1         
			WHERE         
				r1.RecType = 1         
				AND r1.CurLevel ='+ CAST(@Level AS NVARCHAR)        
	  
		EXEC( @SqlString)         
	        
		DELETE FROM #t_Result WHERE           
				CurLevel < @Level AND AccPtr IN (SELECT AccPtr FROM #t_Result AS t WHERE t.CurLevel = @Level)  	        
	END        
END   
--select * from #t_Result  
--------------------------------------------------------------------------------------------------------------------------------------------------------  
--------------------------------------------------------------------------------------------------------------------------------------------------------  
       
SET @SqlString = '    
	SELECT         
		RecType,        
		level,        
		CurLevel,        
		AccPtr,          
		Parent,        
		AccName,          
		EnDate,        
		enDebit,        
		enCredit,        
		enCurDebit,        
		enCurCredit,        
		InvName,        
		DetailCnt,        
		enParentNumber,        
		enParentType,        
		CostPoint,        
		EnCurPtr,        
		EnCurVal, 		        
		enNotes,  			        
		PrevBal				    		        
	FROM         
		#t_Result     
	WHERE    
		(enDebit + enCredit + PrevBal)  <> 0 '        
IF( @CurLevel <> 0 )        
	SET @SqlString = @SqlString + 'AND [Level] <= '+CAST(@CurLevel AS NVARCHAR)    
	SET @SqlString = @SqlString + ' ORDER BY RecType, EnDate, AccName '        
EXECUTE(@SqlString)   

select * from #t_SecViol  

   
DROP TABLE	#t_AcTbl     
DROP TABLE	#t_CiTbl         
DROP TABLE	#t_Acc       
DROP TABLE	#t_Result       
DROP TABLE	#t_Balances       
DROP TABLE	#t_SecViol       

--select * from ci000  
/*   
exec prcCalcEntries    
'9/1/2002',--	@StartDate DATETIME,	         
'10/15/2002',--	@EndDate DATETIME,		         
70,--	@AccPtr INT,			-- ??????  ???? ?? ???? ???? ?? ?????         
1,--	@CurPtr INT,			-- ?????? ??????? ?? ???????         
1,--	@CurVal FLOAT,			-- ??? ??????? ?????? ?? ???????         
5,--	@UserCeSec INT,			-- ?????? ??????? ?????? ?????         
0,--	@Class INT,				-- ????? ??????? ?? ???????         
0,--	@ShowUnPosted INT,		-- ????? ??????? ????? ?????          
'',--	@InvString NVARCHAR(256),--  ???? ???? ????? ??? ???  ??? ???? ?? ???? ????? ????? ?????          
0,--	@InvAcc INT,			-- ?????? ??????? ?????? ?? ???????         
0,--	@CheckInv INT,			-- =0 ??? ????? ?????? ???????         
0,--	@CostPoint INT,			-- =0 ??? ????? ???? ????         
0,--	@ShowCost INT,			-- =0 ??? ????? ???? ????         
'',--	@Note1 NVARCHAR(256),	-- ????         
'',--	@Note2 NVARCHAR(256),	-- ?? ????      	   
1,--	@CalcPrevBal INT,	-- add PrevBalance = 0  not calc the PrevBalance   
0,--	@ShowCur  INT,		-- ?????? ?????? ???????? ?? ????? ????         
0,--	@CurLevel INT,		-- ??????? ?????? ?? ???????         
0,--	@SumAcc	INT,			-- ????? ?????? ???? ?????         
0--	@CheckContain INT	--    
*/   


#######################################################################################

#END






