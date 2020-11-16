
var g_ColCount = 0;

function DeleteLayoutTable()
{
	var oTable = document.getElementById("LayoutTable");
	
	if (oTable)
		document.body.removeChild(oTable);
}

function CreateLayoutTable(colCount)
{
	var oTable = document.createElement("TABLE");
	var oTBody = document.createElement("TBODY");
	
	oTable.id = "LayoutTable";
	oTable.className = "LayoutTable";
	
	var oRow = document.createElement("TR");
	for (var i = 0; i < colCount; i++)
	{
		var oCell = document.createElement("TD");

		oCell.vAlign = "top";
		oRow.appendChild(oCell);
	}
	
	oTBody.appendChild(oRow);
	oTable.appendChild(oTBody);
	document.body.appendChild(oTable);
}

function InsertPanel(oPanel, index)
{
	var oTable = document.getElementById("LayoutTable");
	var oRow = oTable.firstChild.children[0];
	var col = index % oRow.childNodes.length;

	oRow.childNodes[col].appendChild(oPanel);
}

function MovePanelsToTable()
{
	var divs = document.getElementsByTagName("DIV");
	var panels = new Array();
	
	for (var i = 0; i < divs.length; i++)
	{
		if (divs[i].id.indexOf("divPanel") != -1)
			panels.push(divs[i].id);
	}

	panels.sort();
	
	for (var i = 0; i < panels.length; i++)
	{
		var oPanel = document.getElementById(panels[i]);
		
		InsertPanel(oPanel, i);
		oPanel.style.display = "block";
	}
}

function MovePanelsOutOfTable()
{
	var divs = document.getElementsByTagName("DIV");
	
	for (var i = divs.length - 1; i >= 0; i--)
	{
		var oDiv = divs[i];
		
		if (oDiv.id.indexOf("divPanel") != -1)
		{
			oDiv.style.display = "none";
			if (oDiv.parentElement.tagName == "TD")
				document.body.appendChild(oDiv);
		}
	}
}

function ArrangeDocument()
{
	var cx = document.body.clientWidth;
	var colCount = Math.floor(cx / 228);

	if (colCount != g_ColCount && colCount > 0)
	{
		MovePanelsOutOfTable();
		DeleteLayoutTable();
		CreateLayoutTable(colCount);
		MovePanelsToTable();
		
		g_ColCount = colCount;
	}
}

function window.onload()
{
	ArrangeDocument();
}

function window.onresize()
{
	ArrangeDocument();
}

document.attachEvent("ondragstart", function(){window.event.returnValue = false;});