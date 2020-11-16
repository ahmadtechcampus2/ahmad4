###############################################################
CREATE PROC GetMainBranchParents
@MainBranchGUID uniqueidentifier,
@ChildBranchGUID uniqueidentifier
AS
BEGIN

SET NOCOUNT ON;
-- Â–« «··ÊÃÌﬂ ›«∆„ ⁄·Ï ⁄—÷ Ã„Ì⁄ «»«¡ ··›—⁄ «·—∆Ì”Ì

With BranchesCTE ([GUID], [ParentGUID])
AS
(
	SELECT Branch.[GUID], Branch.[ParentGUID]
	FROM br000 AS Branch
	WHERE Branch.[GUID] = @MainBranchGUID

	UNION ALL 

	SELECT Branch.[GUID], Branch.[ParentGUID]
	FROM br000 AS Branch 
	JOIN BranchesCTE
	ON Branch.[GUID] = BranchesCTE.[ParentGUID]
	
)

--«–« ﬂ«‰ «·«»‰ «Õœ «»«¡«·›—⁄ «·—∆Ì”Ì ,ÊÃ» «Ìﬁ«› «·⁄„·Ì… «·Ã«—Ì… 
SELECT [GUID] FROM BranchesCTE WHERE [GUID] = @ChildBranchGUID

END
##############################################################
#END