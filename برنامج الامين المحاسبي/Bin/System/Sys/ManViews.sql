########################################################
CREATE VIEW VwMan_Form_RawMat
AS
SELECT     Rw.MatGuid, mt.Code + '-' + mt.Name AS MatName, Rw.StoreGuid, st.Code + '-' + st.Name AS StoreName, mt.Unity AS Unit1, mt.Unit2, mt.Unit3, 
                      Rw.Qty1, Rw.Qty2, Rw.Qty3, Rw.Price, Rw.Note, Rw.ParentForm, Rw.IsUsed, Rw.GroupingNumber, mt.Unit2FactFlag, mt.Unit3FactFlag, mt.Unit2Fact, 
                      mt.Unit3Fact, Rw.Unity
FROM       dbo.Man_Form_RawMat000 AS Rw LEFT OUTER JOIN
                      dbo.st000 AS st ON Rw.StoreGuid = st.GUID LEFT OUTER JOIN
                      dbo.Man_Form000 AS frm ON Rw.ParentForm = frm.Guid LEFT OUTER JOIN
                      dbo.mt000 AS mt ON Rw.MatGuid = mt.GUID
########################################################                      
CREATE VIEW vwManufacturedMat
AS
SELECT     RY.MatGuid, MT.Code + '-' + MT.Name AS MatName, RY.StoreGuid, ST.Code + '-' + ST.Name AS StoreName, MT.Unity AS unit, MT.Unit2, MT.Unit3, 
                      RY.Qty1, RY.Qty2, RY.Qty3, RY.Price, RY.Unity, RY.Note, MT.Unit2Fact, MT.Unit2FactFlag, MT.Unit3Fact, MT.Unit3FactFlag, RY.DivPercent, 
                      RY.DivPercentType, RY.ParentForm
FROM         dbo.ManManafucturedMats000 AS RY LEFT OUTER JOIN
                      dbo.Man_Form000 AS MF ON RY.ParentForm = MF.Guid LEFT OUTER JOIN
                      dbo.mt000 AS MT ON RY.MatGuid = MT.GUID LEFT OUTER JOIN
                      dbo.st000 AS ST ON RY.StoreGuid = ST.GUID                      
#########################################################	                      
#END                      