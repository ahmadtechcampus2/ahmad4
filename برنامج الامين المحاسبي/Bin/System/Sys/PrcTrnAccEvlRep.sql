##########################################
CREATE PROCEDURE PrcTrnAccEvlRep
	@AccGUID   	UNIQUEIDENTIFIER = 0x0,
	@AccCurrGUID	UNIQUEIDENTIFIER = 0x0,
	@StartDate 	DATETIME = '1-1-1900',
	@ENDDATE   	DATETIME = '1-1-2100'

AS
SET NOCOUNT ON

CREATE TABLE #Result(AccGuid 				UNIQUEIDENTIFIER,
		     CurrencyGUID			UNIQUEIDENTIFIER,
		     SumDebit				FLOAT ,--„Ã„Ê⁄ «·„œÌ‰  
		     EqSumDebit				FLOAT ,--„Ã„Ê⁄ «·„œÌ‰ »«·⁄„·… «·√”«”Ì…
		     AVGDebit				FLOAT ,--Ê”ÿÌ «·„œÌ‰
		     SumCredit				FLOAT ,--„Ã„Ê⁄ «·œ«∆‰  
		     EqSumCredit			FLOAT ,--„Ã„Ê⁄ «·œ«∆‰ »«·⁄„·… «·√”«”Ì…
		     AVGCredit				FLOAT ,--Ê”ÿÌ «·œ«∆‰
		     EqBalanceInDiffCurr                FLOAT --„ﬂ«›∆ «·—’Ìœ ··Õ—ﬂ«  «·Œ«ÿ∆… «Ì »€Ì— ⁄„·… «·Õ”«»
			)

INSERT INTO #Result
--First ,  entries that have the same Account's Currency
SELECT Ac.GUID, 
       e.CurrencyGUID, 
       ISNULL( sum([e].[debit]/[e].[currencyval]), 0),
       ISNULL( sum([e].[debit]), 0),
       0,
       ISNULL( sum([e].[credit]/[e].[currencyval]), 0),
       ISNULL( sum([e].[credit]), 0),
       0,
       0--„ﬂ«›∆ «·—’Ìœ ··Õ—ﬂ«  «·Œ«ÿ∆… «Ì »€Ì— ⁄„·… «·Õ”«»
FROM  fnGetAccountsList(@AccGUID,1) AS Ac
INNER JOIN [AC000] [CurrAcc] ON [CurrAcc].GUID = AC.GUID AND
				[CurrAcc].TYPE = 1 AND
				[CurrAcc].NSons = 0 AND
				(@AccCurrGUID = 0x0 OR [CurrAcc].CurrencyGUID = @AccCurrGUID)
INNER JOIN [en000] [e] ON [e].[accountGuid] = AC.GUID AND 
			  [CurrAcc].[CurrencyGUID] = [e].[CurrencyGUID]--Entry in Same Account's Currency
INNER JOIN [ce000] [c] ON [e].[parentGuid] = [c].[guid] AND 
			  [c].[isPosted] <> 0
WHERE [c].[date] BETWEEN @StartDate AND @ENDDATE
GROUP BY Ac.GUID, e.CurrencyGUID

--Second , entries that have Different Currency from Account's Currency
UPDATE #Result 
	SET EqBalanceInDiffCurr =  
			(
				SELECT 
					ISNULL(sum([e].[debit]) - sum([e].[credit]), 0)
				FROM  fnGetAccountsList(@AccGUID,1) AS Ac
				INNER JOIN [AC000] [CurrAcc] ON [CurrAcc].GUID = AC.GUID AND
						[CurrAcc].TYPE = 1 AND
						[CurrAcc].NSons = 0 AND
						(@AccCurrGUID = 0x0 OR [CurrAcc].CurrencyGUID = @AccCurrGUID)
				INNER JOIN [en000] [e] ON [e].[accountGuid] = AC.GUID AND 
					  [e].[CurrencyGUID] <> [CurrAcc].[CurrencyGUID]--Entry in Different Account's Currency
				INNER JOIN [ce000] [c] ON [e].[parentGuid] = [c].[guid] AND 
					  [c].[isPosted] <> 0
				WHERE [c].[date] BETWEEN @StartDate AND @ENDDATE
			)
			
	WHERE AccGuid IN
			(
				SELECT Ac.GUID
				FROM  fnGetAccountsList(@AccGUID,1) AS Ac
				INNER JOIN [AC000] [CurrAcc] ON [CurrAcc].GUID = AC.GUID AND
						[CurrAcc].TYPE = 1 AND
						[CurrAcc].NSons = 0 AND
						(@AccCurrGUID = 0x0 OR [CurrAcc].CurrencyGUID = @AccCurrGUID)
				INNER JOIN [en000] [e] ON [e].[accountGuid] = AC.GUID AND 
						[e].[CurrencyGUID] <> [CurrAcc].[CurrencyGUID]--Entry in Different Account's Currency
				INNER JOIN [ce000] [c] ON [e].[parentGuid] = [c].[guid] AND 
						[c].[isPosted] <> 0
				WHERE [c].[date] BETWEEN @StartDate AND @ENDDATE
			)

UPDATE #Result SET AVGDebit  = EqSumDebit/SumDebit   WHERE SumDebit <> 0
UPDATE #Result SET AVGCredit = EqSumCredit/SumCredit WHERE SumCredit <> 0
		     


Select * From #Result

--EXEC PrcTrnAccEvlRep 'AF54AAC6-0765-45E0-A495-99AFBBBBFCD9'
#####################################################################################
#END		

