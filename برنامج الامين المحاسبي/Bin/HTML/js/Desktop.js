
/****************************************************************
* Al-Ameen 2017 Desktop                                        *
* Version 1.0                                                  *
* by Ziad Abdel-Majeed                                         *
* Copyright (c) 2006-2017 alameensoft.  All Rights Reserved.    *
****************************************************************/

var g_MenuStrip = new sjcl.widget.MenuBar();
var g_WebRequests = new sjcl.net.WebRequestCollection();
var g_TabsInfo = new Array();
var g_SelectedTab = "";
var g_TabsScrollTimerId = null;
var g_NavBar = new NavBar();
var g_NavBarMinWidth = 165;
var g_NavBarMaxWidth = Math.floor(screen.width * 3 / 5) - 8;
var g_NavBarPaneHeight = 32;
var g_NavBarIconWidth = 22;
var g_PanelToggleTimersId = new Array();
var g_HeaderSize = 140;
var g_InDragMode = false;
var g_Idle = true;
var g_IsFileOpen = false;

var g_StringTable = {
	ltr: {
		IDS_REFRESH: "Refresh",
		IDS_SEND_TO: "Send To",
		IDS_EXPAND: "Expand",
		IDS_COLLAPSE: "Collapse",
		IDS_CLOSE: "Close",
		IDS_CUSTOMIZE: "Customize",
		IDS_TOGGLE: "Expand/Collpase",
		IDS_COLUMNS: "Columns",
		IDS_CANCEL: "Cancel",
		IDS_PREV: "Previous",
		IDS_NEXT: "Next"
	},

	rtl: {
		IDS_REFRESH: " ÕœÌÀ",
		IDS_SEND_TO: "≈—”«· ≈·Ï",
		IDS_EXPAND: " Ê”Ì⁄",
		IDS_COLLAPSE: "ÿÌ",
		IDS_CLOSE: "≈€·«ﬁ",
		IDS_CUSTOMIZE: " Œ’Ì’",
		IDS_TOGGLE: " Ê”Ì⁄/ÿÌ",
		IDS_COLUMNS: "⁄„Êœ",
		IDS_CANCEL: "≈·€«¡ «·√„—",
		IDS_PREV: "«·”«»ﬁ",
		IDS_NEXT: "«· «·Ì"
	}
};

function getString(id) {
	var dir = g_Direction ? g_Direction : "ltr";

	return g_StringTable[dir][id];
}

Object.extend(g_TabsInfo,
{
	item: function (name) {
		return this.findByProp("name", name);
	},

	remove: function (name) {
		this.removeAt(this.indexByProp("name", name));
	}
});

Object.extend(g_NavBar.panes,
{
	item: function (name) {
		return this.findByProp("name", name);
	},

	remove: function (name) {
		this.removeAt(this.indexByProp("name", name));
	}
});

function removeElement(e) {
	e.parentNode.removeChild(e);
}

var TabLayout = {
	Auto: 0,
	Fixed: 1,
	Custom: 2
};

function TabInfo(name, caption, icon, columns, layout, dockable, largeIcon, contentId, docked) {
	if (columns == undefined) columns = 1;
	if (layout == undefined) layout = TabLayout.Auto;
	if (dockable == undefined) dockable = true;
	if (largeIcon == undefined) largeIcon = null;
	if (contentId == undefined) contentId = null;
	if (docked == undefined) docked = false;

	this.name = name;
	this.caption = caption;
	this.icon = icon;
	this.columns = columns;
	this.layout = layout;
	this.dockable = dockable;
	this.largeIcon = largeIcon;
	this.contentId = contentId;
	this.docked = docked;
}

function NavBarPane(name, expanded, row) {
	this.name = name;
	this.expanded = expanded;
	this.row = row;
}

function NavBar() {
	this.visible = true;
	this.panes = new Array();
}

function DragStatus(panel, x, y) {
	var pt = sjcl.dom.elementPoint(panel);

	this.startX = x;
	this.startY = y;
	this.deltaX = x - pt.left;
	this.deltaY = y - pt.top;
	this.dragRect = 2;
	this.status = 0;
	this.location = 0;
	this.target = null;
}

function setDirection(dir) {
	g_Direction = dir;
	g_MenuStrip.direction = dir;
	g_MenuStrip.arrowImageUrl = "images/" + dir + "/mnu_arrow.png";
}

function getClientHeight() {
	return document.body.parentNode.clientHeight;
}

function getClientWidth() {
	return document.body.parentNode.clientWidth;
}

function makeTabId(name) {
	return "tab_" + name;
}

function makeTabIconId(name) {
	return "tico_" + name;
}

function makePaneId(name) {
	return "nbp_" + name;
}

function makePaneIconId(name) {
	return "nbpi_" + name;
}

function makeTabPanelsMenuId(name) {
	return "mnuTP_" + name;
}

function makeTabPanelsMenuItemId(name) {
	return "tpmi_" + name;
}

function makeTabMenuId(name) {
	return "tmi_" + name;
}

function makePanelMenuId(name) {
	return "pmi_" + name;
}

function makeNavBarMenuId(name) {
	return "nbmi_" + name;
}

function makePanelId(name) {
	return "pnl_" + name;
}

function getTabNameById(id) {
	return id.substring(4);
}

function getTabNameByIconId(id) {
	return id.substring(5);
}

function getPaneNameById(id) {
	return id.substring(4);
}

function getPaneNameByIconId(id) {
	return id.substring(5);
}

function getPaneNameByMenuId(id) {
	return id.substring(5);
}

function getTabMenuNameById(id) {
	return id.substring(4);
}

function getPanelMenuNameById(id) {
	return id.substring(4);
}

function getNavBarMenuNameById(id) {
	return id.substring(5);
}


function getNotificationArea() {
	return $("NotificationArea");
}

function getTabPageFrames() {
	return $("TabPageFrames");
}

function getTabsGroup() {
	return $("TabsGroup");
}

function getTabsContainer() {
	var tbl = getTabsGroup();

	return tbl.firstChild.firstChild;
}

function getTabsGroupInner() {
	return $("TabsGroupInner");
}

function getTabsGroupOuter() {
	return $("TabsGroupOuter");
}

function getTabsMenu() {
	return $("TabsMenu");
}

function getTabContentCell() {
	return $("TabContent");
}

function getNavBarContentCell() {
	return $("NavBarContent");
}

function getNavBarMenu() {
	return $("mnuNavBar");
}

function getNavBar() {
	return $("NavBar");
}

function getNavBarCaption() {
	return $("NavBarCaption");
}

function getNavBarPanes() {
	return $("NavBarPanes");
}

function getNavBarFooter() {
	return $("NavBarFooter");
}

function getLogo() {
	return $("Logo");
}

function getSplitter() {
	return $("Splitter");
}

function getNavBarMenuArrow() {
	return $("NavBarMenu");
}

function getNavBarGrip() {
	return $("NavBarGrip");
}

function getToolBar() {
	return $("ToolBar");
}

function getColumnsPanel() {
	return $("ColumnsPanel");
}

function getCPColumns() {
	return $("CPColumns");
}

function getCPLabel() {
	return $("CPLabel");
}

function getCPEraser() {
	return $("CPEraser");
}

function getPanelsMenu() {
	return $("PanelsMenu");
}

function getPMEraser() {
	return $("PMEraser");
}

function getPanelNameById(id) {
	return id.substring(4);
}

function getTabPagesContainer(ti) {
	if (ti.docked)
		return getNavBarContentCell();
	else
		return getTabPageFrames();
}

function getTabPageColumns(ti) {
	var columns = 1;

	if (!ti.docked && (ti.layout != TabLayout.Custom))
		columns = ti.columns;

	if (columns < 1)
		columns = 1;

	return columns;
}

function getTabPageTr(ti) {
	return ti.frame.firstChild.firstChild;
}

function setIsFileOpen() {
	g_IsFileOpen = true;
	$("btnPanels").className = "Button";
	$("btnCustomize").className = "Button";
}

function createTabPageHeader(ti) {
	var tbl = document.createElement("TABLE");
	var bdy = tbl.appendChild(document.createElement("TBODY"));
	var tr = bdy.appendChild(document.createElement("TR"));
	var td, img;

	td = tr.appendChild(document.createElement("TD"));
	td.className = "LeftEdge";

	td = tr.appendChild(document.createElement("TD"));
	td.className = "Icon";

	img = td.appendChild(document.createElement("IMG"));
	img.src = ti.icon ? ti.icon : "images/spinner.gif";
	img.id = makeTabIconId(ti.name);

	if (!ti.icon)
		img.style.display = "none";

	td = tr.appendChild(document.createElement("TD"));
	td.className = "Title";
	td.appendChild(document.createTextNode(ti.caption));
	td.attachEvent("ondblclick", onTabDoubleClick);

	td = tr.appendChild(document.createElement("TD"));
	td.className = "Button";
	td.style.display = "none";

	img = td.appendChild(document.createElement("IMG"));
	img.src = "images/tab_refresh.png";
	img.attachEvent("onmouseenter", onTabButtonOver);
	img.attachEvent("onmouseleave", onTabButtonOut);
	img.attachEvent("onclick", onTabButtonClick);

	td = tr.appendChild(document.createElement("TD"));
	td.className = "RightEdge";

	tbl.cellSpacing = "0px";
	tbl.cellPadding = "0px";
	tbl.className = "TabNormal";

	return tbl;
}

function createTabPageFrame(ti) {
	var tbl = document.createElement("TABLE");
	var bdy = tbl.appendChild(document.createElement("TBODY"));
	var tr = bdy.appendChild(document.createElement("TR"));
	var columns = getTabPageColumns(ti);

	tbl.cellPadding = "0";
	tbl.cellSpacing = ti.docked ? "5px" : "10px";
	tbl.style.display = "none";
	tbl.style.tableLayout = "fixed";

	for (var i = 0; i < columns; i++) {
		td = tr.appendChild(document.createElement("TD"));
		td.setAttribute("PanelContainer", true);
		td.style.verticalAlign = "top";
	}

	return tbl;
}

function resetTabPageFrame(ti) {
	var tr = getTabPageTr(ti);
	var columns = getTabPageColumns(ti);

	while (tr.firstChild)
		tr.removeChild(tr.firstChild);

	for (var i = 0; i < columns; i++) {
		td = tr.appendChild(document.createElement("TD"));
		td.setAttribute("PanelContainer", true);
		td.style.verticalAlign = "top";
	}
}

function createTabPageCell(ti) {
	var td = document.createElement("TD");

	td.id = makeTabId(ti.name);
	td.setAttribute("TabContainer", true);
	td.attachEvent("onmouseenter", onTabOver);
	td.attachEvent("onmouseleave", onTabOut);
	td.attachEvent("onclick", onTabClick);

	if (ti.docked)
		td.style.display = "none";

	return td;
}

function createTabPage(name, caption, icon, columns, layout, dockable, largeIcon, contentId, docked) {
	var ti = new TabInfo(name, caption, icon, columns, layout, dockable, largeIcon, contentId, docked)
	var cell = createTabPageCell(ti);
	var header = createTabPageHeader(ti);
	var frame = createTabPageFrame(ti);
	var tr = getTabsContainer();
	var container = getTabPagesContainer(ti);

	g_TabsInfo.push(ti);

	cell.appendChild(header);
	tr.appendChild(cell);

	ti.cell = cell;
	ti.frame = frame;
	if (ti.layout == TabLayout.Custom) {
		var e = $(ti.contentId);

		if (e) {
			var td = sjcl.dom.getChildByTagName(frame, "TD");

			td.appendChild(e);
		}
	}
	container.appendChild(frame);

	if (ti.docked)
		addNavBarPane(name);

	appendTabToMenu("mnuTabs", makeTabMenuId(name), caption, icon);
	appendTabToMenu("mnuPanelSendTo", makePanelMenuId(name), caption, icon);

	g_MenuStrip.append(new sjcl.widget.Menu(makeTabPanelsMenuId(name)));

	if (!ti.docked) {
		setTabsMenuVisible(true);
		setToolBarButtonVisible("btnColumns", true);
		setToolBarButtonVisible("btnPanels", true);
	}

	window.external.OnTabCreated(name);

	return ti;
}

function appendTabToMenu(menuId, itemId, caption, icon) {
	var menu = g_MenuStrip.getMenu(menuId);
	var divMenu = $(menuId);

	menu.append({ caption: caption, id: itemId, image: icon });

	if (divMenu)
		removeElement(divMenu);
}

function removeTabFromMenu(menuId, id) {
	var menu = g_MenuStrip.getMenu(menuId);
	var divMenu = $(menuId);

	menu.remove(id);

	if (divMenu)
		removeElement(divMenu);
}

function addTabPanelsMenuItem(tabName, id, caption, icon, checked) {
	var menu = g_MenuStrip.getMenu("mnuAllPanels");
	var ti = g_TabsInfo.item(tabName);

	menu.append({ type: sjcl.widget.MenuItemType.Check, id: makeTabPanelsMenuItemId(id), caption: caption, image: icon, checked: checked, tabName: tabName });
}

function scrollTabsGroupLtr(step, end, callback) {
	var inner = getTabsGroupInner();
	var left = parseInt(inner.style.left);

	if (isNaN(left))
		left = 0;

	if (((step > 0) && (left + step > end)) || ((step < 0) && (left + step < end))) {
		inner.style.left = end + "px";

		window.clearInterval(g_TabsScrollTimerId);
		g_TabsScrollTimerId = null;
		window.setTimeout(callback, 10);
	}
	else
		inner.style.left = left + step + "px";
}

function scrollTabsGroupRtl(step, end, callback) {
	var inner = getTabsGroupInner();
	var left = parseInt(inner.style.left);

	if (isNaN(left))
		left = 0;

	if (((step > 0) && (left + step > end)) || ((step < 0) && (left + step < end))) {
		inner.style.left = end + "px";

		window.clearInterval(g_TabsScrollTimerId);
		g_TabsScrollTimerId = null;
		window.setTimeout(callback, 10);
	}
	else
		inner.style.left = left + step + "px";
}

function scrollTabsGroup(name, step, end) {
	if (g_Direction == "ltr")
		scrollTabsGroupLtr(name, step, end);
	else
		scrollTabsGroupRtl(name, step, end);
}

function setTabsMenuVisible(state) {
	var tdMenu = getTabsMenu();

	tdMenu.style.visibility = state ? "visible" : "hidden";
}

function setToolBarButtonVisible(id, state) {
	var btn = $(id);

	btn.style.visibility = state ? "visible" : "hidden";
}

function makeTabVisibleLtr(name, callback) {
	var td = $(makeTabId(name));
	var outer = getTabsGroupOuter();
	var inner = getTabsGroupInner();
	var from = inner.offsetLeft;
	var step, to;

	if (inner.offsetLeft + td.offsetLeft < 0)
		to = -td.offsetLeft;
	else if (td.offsetLeft + td.offsetWidth > outer.offsetWidth - inner.offsetLeft)
		to = -(td.offsetLeft + td.offsetWidth - outer.offsetWidth);
	else {
		callback();
		return;
	}

	step = Math.floor((to - from) / 10);

	g_TabsScrollTimerId = window.setInterval(scrollTabsGroup.bind(window, step, to, callback), 10);
}

function makeTabVisibleRtl(name, callback) {
	var td = $(makeTabId(name));
	var outer = getTabsGroupOuter();
	var inner = getTabsGroupInner();
	var tbl = inner.firstChild;
	var from = parseInt(inner.style.left);
	var innerLeft = parseInt(inner.style.left);
	var step, to;

	if (isNaN(from))
		from = 0;

	if (isNaN(innerLeft))
		innerLeft = 0;

	if (tbl.offsetWidth - td.offsetLeft - innerLeft > outer.offsetWidth)
		to = tbl.offsetWidth - td.offsetLeft - outer.offsetWidth;
	else if (tbl.offsetWidth - (td.offsetLeft + td.offsetWidth) - innerLeft < 0)
		to = (tbl.offsetWidth - td.offsetLeft - td.offsetWidth);
	else {
		callback();
		return;
	}


	step = Math.floor((to - from) / 10);

	g_TabsScrollTimerId = window.setInterval(scrollTabsGroup.bind(window, step, to, callback), 10);
}

function makeTabVisible(name, callback) {
	if (g_Direction == "ltr")
		makeTabVisibleLtr(name, callback);
	else
		makeTabVisibleRtl(name, callback);
}

function onMakeTabVisibleDone(name) {
	var ti = g_TabsInfo.item(name);

	if (ti.frame)
		ti.frame.style.display = "block";

	setContentBackground(name);
}

function resizeTabsGroup() {
	var outer = getTabsGroupOuter();
	var inner = getTabsGroupInner();
	var tabsGroup = getTabsGroup();

	if (tabsGroup.offsetWidth < outer.offsetWidth)
		inner.style.left = "0px";
}

function getNextTab(name) {
	var ti = g_TabsInfo.item(name);
	var id = "";

	for (p = ti.cell.nextSibling; p; p = p.nextSibling) {
		if (p.style.display != "none")
			return getTabNameById(p.id);
	}

	for (p = ti.cell.previousSibling; p; p = p.previousSibling) {
		if (p.style.display != "none")
			return getTabNameById(p.id);
	}

	return null;
}

function setTabVisible(ti, state, selNext) {
	if (typeof ti == "string")
		ti = g_TabsInfo.item(ti);

	if (selNext == undefined)
		selNext = true;

	if (state) {
		if (ti.docked)
			addNavBarPane(ti.name);
		else
			ti.cell.style.display = "block";
	}
	else {
		ti.frame.style.display = "none";

		if (ti.docked) {
			removeNavBarPane(ti.name);

			if (g_NavBar.selectedPane == ti.name)
				g_NavBar.selectedPane = "";
		}
		else {
			var tdButton = sjcl.dom.getChildByClassName(ti.cell, "Button");
			var nextTab;

			ti.cell.firstChild.className = "TabNormal";
			tdButton.style.display = "none";

			ti.cell.style.display = "none";

			if (g_SelectedTab == ti.name)
				g_SelectedTab = "";

			if (selNext && (nextTab = getNextTab(ti.name)))
				selectTab(nextTab);
		}
	}
}

function setTabDockable(ti, state) {
	if (typeof ti == "string")
		ti = g_TabsInfo.item(ti);

	ti.dockable = state;
}

function selectDockedTab(ti) {
	if (g_NavBar.selectedPane)
		deselectTab(g_NavBar.selectedPane);

	var pane = $(makePaneId(ti.name));
	var icon = $(makePaneIconId(ti.name));

	pane.className = "NavBarPaneSelected";
	icon.className = "NavBarFooterIconSelected";

	if (ti.frame)
		ti.frame.style.display = "block";

	g_NavBar.selectedPane = ti.name;
	setNavBarCaption(ti.caption);
	setNavBarButtonVisible("NavBarDock", ti.dockable);
	setNavBarButtonVisible("NavBarRefresh", true);
	setNavBarButtonVisible("NavBarPM", true);
}

function selectUndockedTab(ti) {
	if (g_SelectedTab != "")
		deselectTab(g_SelectedTab);

	var tdButton = sjcl.dom.getChildByClassName(ti.cell, "Button");

	ti.cell.firstChild.className = "TabActive";
	tdButton.style.display = "";
	makeTabVisible(ti.name, onMakeTabVisibleDone.bind(window, ti.name));

	if (ti.frame)
		ti.frame.style.display = "block";

	g_SelectedTab = ti.name;
}

function selectTab(name) {
	if (!window.external.OnTabSelecting(name))
		return;

	var ti = g_TabsInfo.item(name);

	if (!ti.initialized) {
		window.external.OnTabInitialize(name);
		ti.initialized = true;
	}

	if (ti.docked)
		selectDockedTab(ti);
	else
		selectUndockedTab(ti);

	setContentBackground(name);

	window.external.OnTabSelected(name);
}

function deselectTab(name) {
	var ti = g_TabsInfo.item(name);

	if (ti.docked) {
		var pane = $(makePaneId(name));
		var icon = $(makePaneIconId(name));

		pane.className = "NavBarPane";
		icon.className = "NavBarFooterIcon";
		ti.frame.style.display = "none";
	}
	else {
		var tdButton = sjcl.dom.getChildByClassName(ti.cell, "Button");

		ti.cell.firstChild.className = "TabNormal";
		tdButton.style.display = "none";
		ti.frame.style.display = "none";
		g_SelectedTab = "";
	}
}

function closeTab(name) {
	if (!window.external.OnTabClosing(name))
		return;

	var ti = g_TabsInfo.item(name);

	if (ti.docked)
		removeNavBarPane(name);

	if (name == g_SelectedTab)
		g_SelectedTab = "";
	else if (name == g_NavBar.selectedPane)
		g_NavBar.selectedPane = "";

	removeElement(ti.cell);
	removeElement(ti.frame);

	g_TabsInfo.remove(name);

	removeTabFromMenu("mnuTabs", makeTabMenuId(name));
	removeTabFromMenu("mnuPanelSendTo", makePanelMenuId(name));
}

function isTabDocked(name) {
	return g_NavBar.panes.item(name) != null;
}

function getSelectedTab() {
	return g_SelectedTab;
}

function getSelectedPane() {
	if (!g_NavBar.selectedPane)
		return "";

	return g_NavBar.selectedPane;
}

function setTabBackgroundColor(name, color) {
	var ti = g_TabsInfo.item(name);

	if (arguments.length == 1)
		delete ti.backgroundColor;
	else
		ti.backgroundColor = color;
}

function setTabBackgroundFill(name, startColor, endColor, type) {
	var ti = g_TabsInfo.item(name);

	if (arguments.length == 1)
		delete ti.backgroundFill;
	else
		ti.backgroundFill = startColor + "|" + endColor + "|" + type;
}

function setTabBackgroundImage(name, image, position, repeat) {
	var ti = g_TabsInfo.item(name);

	if (arguments.length == 1)
		delete ti.backgroundImage;
	else
		ti.backgroundImage = image + "|" + position + "|" + repeat;
}

function setContentBackgroundColor(info) {
	var e = getTabContentCell();

	if (arguments.length == 0) {
		e.style.backgroundColor = "";
		return;
	}

	e.style.backgroundColor = info[0];
	e.style.filter = "";
}

function setContentBackgroundFill(info) {
	var e = getTabContentCell();

	if (arguments.length == 0) {
		e.style.filter = "";
		return;
	}

	var filter;

	try {
		filter = e.filters.item("DXImageTransform.Microsoft.Gradient");
	}
	catch (exp) {
		e.style.filter += "progid:DXImageTransform.Microsoft.Gradient";
		filter = e.filters.item("DXImageTransform.Microsoft.Gradient");
	}

	filter.enabled = false;
	if (info[0])
		filter.startColorStr = info[0];
	if (info[1])
		filter.endColorStr = info[1];
	if (info[2])
		filter.gradientType = info[2];
	filter.enabled = true;
}

function setContentBackgroundImage(ti, info) {
	var e = getTabPagesContainer(ti);

	if (arguments.length == 1) {
		e.style.backgroundImage = "";
		return;
	}

	e.style.filter = "";

	if (info[0])
		e.style.backgroundImage = "url(" + info[0] + ")";
	if (info[1])
		e.style.backgroundPosition = info[1];
	if (info[2])
		e.style.backgroundRepeat = info[2];
}

function setContentBackground(name) {
	return;
	var ti = g_TabsInfo.item(name);

	if (ti.backgroundFill)
		setContentBackgroundFill(ti.backgroundFill.split("|"));
	else
		setContentBackgroundFill();

	if (ti.backgroundImage)
		setContentBackgroundImage(ti, ti.backgroundImage.split("|"));
	else
		setContentBackgroundImage(ti);

	if (ti.backgroundColor)
		setContentBackgroundColor(ti.backgroundColor.split("|"));
	else
		setContentBackgroundColor();
}

function clearContentBackground(name) {
	var ti = g_TabsInfo.item(name);

	setContentBackgroundFill();
	setContentBackgroundImage(ti);
	setContentBackgroundColor();
}

function setTabCaption(name, caption) {
	var ti = g_TabsInfo.item(name);
	var td = sjcl.dom.getChildByClassName(ti.cell, "Title");

	ti.caption = caption;
	td.innerHTML = caption;

	if (ti.docked)
		updateNavBarPaneCaption(ti);
}

function setTabIcon(name, icon) {
	var ti = g_TabsInfo.item(name);
	var td = sjcl.dom.getChildByClassName(ti.cell, "Icon");
	var img = td.firstChild;

	img.src = icon;
	ti.icon = icon;

	if (isTabDocked(name)) {
		td = $(makePaneIconId(name));
		img = td.firstChild;
		img.src = icon;
	}
}

function setTabLargeIcon(name, icon) {
	var ti = g_TabsInfo.item(name);
	var pane = $(makePaneId(name));
	var td = sjcl.dom.getChildByClassName(pane, "Icon");

	ti.largeIcon = icon;
	td.firstChild.src = icon;
	td.style.visibility = "visible";
}

function setTabContentId(name, id) {
	var ti = g_TabsInfo.item(name);
	var e = $(id);

	if (e && ti.layout == TabLayout.Custom) {
		var container = isTabDocked(name) ? getNavBarContentCell() : getTabPageFrames();

		ti.contentId = id;
		ti.frame = e;

		container.appendChild(e);

		if (g_SelectedTab == name)
			selectTab(name);
	}
}

function dockTab(name, showEffect) {
	if (!g_Idle)
		return;

	var ti = g_TabsInfo.item(name);

	if (!ti.dockable)
		return;

	if (!window.external.OnTabDocking(name))
		return;

	var navBarContent = getNavBarContentCell();
	var rc1 = sjcl.dom.elementRect(ti.cell);
	var rc2 = sjcl.dom.elementRect(navBarContent);
	var duration = showEffect ? 15 : 0;

	rc2.width -= 2;
	rc2.height -= 2;

	g_Idle = false;
	var effect = new sjcl.effect.RectAnimation(rc1, rc2,
		function () {
			var frame = createNavBarPaneFrame();

			setTabVisible(ti, false, false);
			moveTabPageContent(ti, frame);
			navBarContent.appendChild(frame);
			addNavBarPane(name);

			removeElement(ti.frame);

			ti.frame = frame;
			ti.docked = true;
			selectTab(name);

			var nextTab = getNextTab(name);

			if (nextTab)
				selectTab(nextTab);

			if (g_NavBar.panes.length == g_TabsInfo.length) {
				setTabsMenuVisible(false);
				setToolBarButtonVisible("btnColumns", false);
				setToolBarButtonVisible("btnPanels", false);
			}

			setContentBackground(name);
			window.setTimeout("adjustNavBarWidth()", 10);

			window.external.OnTabDocked(name);
			g_Idle = true;
		}
		, 20, null, duration);

	effect.play();
}

function undockTab(name, showEffect) {
	if (!g_Idle)
		return;

	var ti = g_TabsInfo.item(name);

	if (!ti.dockable || !isTabDocked(name))
		return;

	if (!window.external.OnTabUndocking(name))
		return;

	var navBarContent = getNavBarContentCell();
	var rc1 = sjcl.dom.elementRect(navBarContent);
	var rc2 = sjcl.dom.elementRect(ti.cell);
	var duration = showEffect ? 15 : 0;

	rc1.width -= 2;
	rc1.height -= 2;

	g_Idle = false;
	var effect = new sjcl.effect.RectAnimation(rc1, rc2,
		function () {
			clearContentBackground(name);
			ti.docked = false;

			var frame = createTabPageFrame(ti);
			var container = getTabPageFrames();
			var nextPane = getNextNavBarPane(name);

			moveTabPageContent(ti, frame);
			container.appendChild(frame);
			removeNavBarPane(name);

			removeElement(ti.frame);

			ti.cell.style.display = "";
			ti.frame = frame;
			selectTab(name);
			setTabsMenuVisible(true);
			setToolBarButtonVisible("btnColumns", true);
			setToolBarButtonVisible("btnPanels", true);

			if (nextPane)
				selectTab(nextPane);

			window.external.OnTabUndocked(name);
			g_Idle = true;
		}
		, 15, null, duration);

	effect.play();
}

function onTabsMenuOver() {
	if (!g_InDragMode) {
		var e = event.srcElement;

		e.className = "TabsMenuHover";
	}
}

function onTabsMenuOut() {
	if (!g_InDragMode) {
		var e = event.srcElement;

		if (g_MenuStrip.contextMenu != "mnuTabs")
			e.className = "TabsMenu";
	}
}

function onTabsMenuClick(e) {
	var e = sjcl.dom.getAncestorByClassName(event.srcElement, "TabsMenu");

	g_MenuStrip.showContextMenu("mnuTabs", e, null, "ltr");
}

function onTabStripButtonOver(e) {
	if (!g_InDragMode)
		e.src = e.src.replace(".png", "_hover.png");
}

function onTabStripButtonOut(e) {
	if (!g_InDragMode)
		e.src = e.src.replace("_hover.png", ".png");
}

function onTabStripMenuClick(e) {
	g_MenuStrip.showContextMenu("mnuTabs", e, null, "rtl");
}

function onTabOver() {
	if (!g_InDragMode) {
		var src = window.event.srcElement;
		var tbl = src.firstChild;
		var name = getTabNameById(src.id);

		if (name != g_SelectedTab)
			tbl.className = "TabHover";
	}
}

function onTabOut() {
	if (!g_InDragMode) {
		var src = window.event.srcElement;
		var tbl = src.firstChild;
		var name = getTabNameById(src.id);

		if (name != g_SelectedTab)
			tbl.className = "TabNormal";
	}
}

function onTabClick() {
	var event = new sjcl.Event(window.event);
	var td = event.findByAttribute("TabContainer");
	var name = getTabNameById(td.id);

	selectTab(name);
}

function onTabDoubleClick() {
	var event = new sjcl.Event(window.event);
	var td = event.findByAttribute("TabContainer");
	var name = getTabNameById(td.id);

	dockTab(name, true, true);
}


function onTabButtonOver() {
	if (!g_InDragMode) {
		var e = window.event.srcElement;

		e.src = e.src.replace(".png", "_hover.png");
	}
}

function onTabButtonOut() {
	var e = window.event.srcElement;

	e.src = e.src.replace("_hover.png", ".png");
}

function onTabButtonClick() {
	var td = sjcl.dom.getAncestorByAttribute(event.srcElement, "TabContainer");

	window.external.OnTabRefresh(getTabNameById(td.id));
}

function onInitPopupMenu(id) {
	var menu = g_MenuStrip.getMenu(id);

	switch (id) {
		case "mnuPanel":
			menu.setItemEnabled(makePanelMenuId("Expand"), !g_MenuStrip.owner.getAttribute("Expanded"));
			menu.setItemEnabled(makePanelMenuId("Collapse"), g_MenuStrip.owner.getAttribute("Expanded"));
			break;

		case "mnuTabs":
			menu.each(
				function (item) {
					var name = item.id.substring(4);

					item.setVisible(!g_NavBar.panes.item(name));
				}
			);
			break;

		case "mnuPanelSendTo":
			var tab = g_MenuStrip.owner.getAttribute("Location");

			menu.each(
				function (item) {
					var name = item.id.substring(4);

					item.setEnabled(name != tab);
				}
			);
			break;

		case "mnuNavBar":
			menu.each(
				function (item) {
					var name = item.id.substring(5);
					var td = $(makePaneIconId(name));
					var pane = g_NavBar.panes.item(name);

					item.setVisible((td.style.display == "none") && !pane.expanded);
				}
			);
			break;

	}
}

function onUninitPopupMenu() {
	if (g_MenuStrip.contextMenu == "mnuNavBar") {
		var div = getNavBarMenu();

		removeElement(div);
	}

	if (g_MenuStrip.contextMenu == "mnuTabs") {
		getTabsMenu().className = "TabsMenu";
	}
}

function onMenuItemClick(e) {
	switch (e.menuId) {
		case "mnuTabs":
			onTabsMenuItemClick(e.itemId);
			break;

		case "mnuPanel":
			onPanelMenuItemClick(e.itemId);
			break;

		case "mnuPanelSendTo":
			onPanelSendToMenuItemClick(e.itemId);
			break;

		case "mnuNavBar":
			onNavBarMenuItemClick(e.itemId);
			break;
	}
}

function onTabsMenuItemClick(id) {
	var name = id.substring(4);

	selectTab(name);
}

function onPanelMenuItemClick(id) {
	var name = getPanelNameById(g_MenuStrip.owner.id);

	switch (id) {
		case makePanelMenuId("Refresh"):
			refreshPanel(name);
			break;

		case makePanelMenuId("Expand"):
			expandPanel(name, true);
			break;

		case makePanelMenuId("Collapse"):
			collapsePanel(name, true);
			break;

		case makePanelMenuId("Close"):
			closePanel(name, true);
			break;
	}
}

function onPanelSendToMenuItemClick(id) {
	var name = id.substring(4);

	sendPanelTo(g_MenuStrip.owner, name);
}

function onNavBarMenuItemClick(id) {
	var name = id.substring(5);

	selectTab(name);
}

function getTabPanels(name) {
	var ti = g_TabsInfo.item(name);
	var tr = getTabPageTr(ti);
	var df = document.createDocumentFragment();
	var rows = 0;

	for (var i = 0; i < tr.childNodes.length; i++) {
		var td = tr.childNodes.item(i);

		rows = Math.max(rows, td.childNodes.length);
	}

	for (var i = 0; i < rows; i++) {
		for (var j = 0; j < tr.childNodes.length; j++) {
			var td = tr.childNodes.item(j);

			if (td.childNodes.length)
				df.appendChild(td.childNodes.item(0));
		}
	}

	return df;
}

function getTabPanelsNames(name) {
	var ti = g_TabsInfo.item(name);
	var tr = getTabPageTr(ti);
	var list = [];
	var rows = 0;

	for (var i = 0; i < tr.childNodes.length; i++) {
		var td = tr.childNodes.item(i);

		rows = Math.max(rows, td.childNodes.length);
	}

	for (var i = 0; i < rows; i++) {
		for (var j = 0; j < tr.childNodes.length; j++) {
			var td = tr.childNodes.item(j);

			if (td.childNodes.length)
				list.push(getPanelNameById(td.childNodes.item(i).id));
		}
	}

	return list;
}

function insertPanel(panel, td, index) {
	panel.setAttribute("Index", index);

	for (var p = td.firstChild; p; p = p.nextSibling) {
		if (parseInt(p.getAttribute("Index")) >= index) {
			td.insertBefore(panel, p);

			return;
		}
	}

	td.appendChild(panel);
}

function appendPanel(panel, ti, column, index) {
	var tr = getTabPageTr(ti);
	var td;

	if (column >= 0) {
		if (column >= tr.childNodes.length)
			column = tr.childNodes.length - 1;

		td = tr.childNodes.item(column);
		insertPanel(panel, td, index);
	}
	else {
		for (var row = 1; ; row++) {
			for (var td = tr.firstChild; td; td = td.nextSibling) {
				if (td.childNodes.length < row) {
					panel.setAttribute("Index", td.childNodes.length);
					td.appendChild(panel);

					return;
				}
			}
		}
	}
}

function appendPanels(panels, frame) {
	var tr = frame.firstChild.firstChild;
	var columns = tr.childNodes.length;

	for (var i = 0, n = panels.childNodes.length; i < n; i++) {
		var column = i % columns;
		var td = tr.childNodes.item(column);
		var panel = panels.childNodes.item(0);

		td.appendChild(panel);
	}
}

function moveTabPageContent(ti, frame) {
	if (ti.layout == TabLayout.Custom) {
		var td1 = sjcl.dom.getChildByTagName(ti.frame, "TD");
		var td2 = sjcl.dom.getChildByTagName(frame, "TD");

		if (td1.firstChild)
			td2.appendChild(td1.firstChild);
	}
	else
		appendPanels(getTabPanels(ti.name), frame);
}

function arrangeTabPanels(name, force) {
	var ti = g_TabsInfo.item(name);

	if (!ti || (ti.layout == TabLayout.Custom))
		return;

	var columns = getTabPageColumns(ti)

	if (force || columns != ti.columns) {
		ti.columns = columns;

		var panels = getTabPanels(name);

		resetTabPageFrame(ti);
		appendPanels(panels, ti.frame);
	}
}

function updateTabPanelsPositions(name) {
	var ti = g_TabsInfo.item(name);
	var tr = getTabPageTr(ti);

	for (var td = tr.firstChild; td; td = td.nextSibling) {
		for (var i = 0; i < td.childNodes.length; i++) {
			var panel = td.childNodes.item(i);

			panel.setAttribute("Index", i);
			window.external.OnPanelPositionChanged(name, getPanelNameById(panel.id), td.cellIndex, i);
		}
	}
}

function updateTabPanelsMenu(panel, from, to) {
	if (from == to)
		return;

	var name = getPanelNameById(panel.id);
	var mnuId = makeTabPanelsMenuItemId(name);
	var mnuFrom = g_MenuStrip.getMenu(makeTabPanelsMenuId(from));
	var mnuTo = g_MenuStrip.getMenu(makeTabPanelsMenuId(to));


	mnuFrom.remove(mnuId);
	mnuTo.append({ id: mnuId, caption: getPanelCaption(panel), image: getPanelIcon(panel), checked: true });
}

function getPanelCaption(panel) {
	var hdr = panel.firstChild;

	return hdr.innerText;
}

function getPanelIcon(panel) {
	var hdr = panel.firstChild;
	var td = sjcl.dom.getChildByClassName(hdr, "Icon");
	var img = td.firstChild;

	return img ? img.src : "";
}

function createPanelHeader(name, caption, icon, showCustomize, showRefresh, captionLink) {
	var tbl = document.createElement("TABLE");
	var bdy = tbl.appendChild(document.createElement("TBODY"));
	var tr = bdy.appendChild(document.createElement("TR"));
	var td, img, div, a;

	td = tr.appendChild(document.createElement("TD"));
	td.className = "LeftBorder";

	td = tr.appendChild(document.createElement("TD"));
	td.className = "Icon";

	img = td.appendChild(document.createElement("IMG"));
	img.src = icon;
	img.attachEvent("onclick", onPanelIconClick);

	if (!icon)
		td.style.display = "none";

	td = tr.appendChild(document.createElement("TD"));
	td.className = "Title";
	td.attachEvent("onmousedown", onPanelTitleMouseDown);

	div = td.appendChild(document.createElement("DIV"));

	if (captionLink) {
		a = div.appendChild(document.createElement("A"));
		a.appendChild(document.createTextNode(caption));
		a.href = "javascript: void(0);";
		a.attachEvent("onclick", onPanelCaptionClick);
	}
	else
		div.appendChild(document.createTextNode(caption));

	if (showCustomize) {
		td = tr.appendChild(document.createElement("TD"));
		td.className = "Button";
		td.setAttribute("Action", "Customize");

		img = td.appendChild(document.createElement("IMG"));
		img.src = "images/custom.png";
		img.alt = getString("IDS_CUSTOMIZE");
		img.attachEvent("onmouseenter", onPanelButtonEnter);
		img.attachEvent("onmouseleave", onPanelButtonLeave);
		img.attachEvent("onclick", onPanelButtonClick);
	}

	if (showRefresh) {
		td = tr.appendChild(document.createElement("TD"));
		td.className = "Button";
		td.setAttribute("Action", "Refresh");

		img = td.appendChild(document.createElement("IMG"));
		img.src = "images/np_refresh.png";
		img.alt = getString("IDS_REFRESH");
		img.attachEvent("onmouseenter", onPanelButtonEnter);
		img.attachEvent("onmouseleave", onPanelButtonLeave);
		img.attachEvent("onclick", onPanelButtonClick);
	}

	td = tr.appendChild(document.createElement("TD"));
	td.className = "Button";
	td.setAttribute("Action", "Toggle");

	img = td.appendChild(document.createElement("IMG"));
	img.src = "images/np_collapse.png";
	img.alt = getString("IDS_TOGGLE");
	img.attachEvent("onmouseenter", onPanelButtonEnter);
	img.attachEvent("onmouseleave", onPanelButtonLeave);
	img.attachEvent("onclick", onPanelButtonClick);

	td = tr.appendChild(document.createElement("TD"));
	td.className = "Button";
	td.setAttribute("Action", "Close");

	img = td.appendChild(document.createElement("IMG"));
	img.src = "images/np_close.png";
	img.alt = getString("IDS_CLOSE");
	img.attachEvent("onmouseenter", onPanelButtonEnter);
	img.attachEvent("onmouseleave", onPanelButtonLeave);
	img.attachEvent("onclick", onPanelButtonClick);

	td = tr.appendChild(document.createElement("TD"));
	td.className = "RightBorder";

	tbl.cellPadding = "0";
	tbl.cellSpacing = "0";
	tbl.className = "Header";

	return tbl;
}

function createPanelFooter() {
	var tbl = document.createElement("TABLE");
	var bdy = tbl.appendChild(document.createElement("TBODY"));
	var tr = bdy.appendChild(document.createElement("TR"));
	var td = tr.appendChild(document.createElement("TD"));;

	td.className = "LeftBorder";

	td = tr.appendChild(document.createElement("TD"));
	td.className = "MiddleBorder";

	td = tr.appendChild(document.createElement("TD"));
	td.className = "RightBorder";

	tbl.cellPadding = "0";
	tbl.cellSpacing = "0";
	tbl.className = "Footer";

	return tbl;
}

function doCreatePanel(name, caption, icon, showCustomize, showRefresh, captionLink) {
	var panel = document.createElement("DIV");
	var header = panel.appendChild(document.createElement("DIV"));
	var bdy = panel.appendChild(document.createElement("DIV"));
	//var footer = panel.appendChild(document.createElement("DIV"));

	header.className = "Header";
	header.appendChild(createPanelHeader(name, caption, icon, showCustomize, showRefresh, captionLink));

	bdy.className = "Content";

	//footer.appendChild(createPanelFooter());
	//footer.className = "Footer";

	panel.id = makePanelId(name);
	panel.className = "Panel";

	return panel;
}

function createPanel(name, caption, icon, expanded, showCustomize, showRefresh, captionLink, tabName, column, index) {
	var ti = g_TabsInfo.item(tabName);
	var panel = doCreatePanel(name, caption, icon, showCustomize, showRefresh, captionLink, tabName);

	panel.setAttribute("Expanded", true);
	panel.setAttribute("Location", tabName);
	panel.setAttribute("Index", index);

	appendPanel(panel, ti, column, index);

	if (!expanded)
		collapsePanel(name, false);
}

///////////////////////////////////////////////////////
///////////////////////////////////////////////////////

function createNotificationArea(isfirst, islast, numofcount, title, titleicon, istitlelink, desc, descicon, isdesclink, backgroundimage) {
	return;
	var vContainer = document.createElement('DIV');
	var tbl = vContainer.appendChild(document.createElement('TABLE'));
	var tbdy = tbl.appendChild(document.createElement('TBODY'));
	var headerTr = tbdy.appendChild(document.createElement('TR'));
	var conentTr = tbdy.appendChild(document.createElement('TR'));

	var vHeader = headerTr.appendChild(document.createElement('TD'));
	var vContent = conentTr.appendChild(document.createElement('TD'));

	tbl.style.width = '100%';
	tbl.cellPadding = '0';
	tbl.cellSpacing = '0';

	vContainer.className = 'Container';
	vContainer.id = "ID_NOTIFICATION_CONTAINER";

	vHeader.className = 'Header';
	vHeader.id = "ID_NOTIFICATION_HEADER";
	vHeader.appendChild(createNotificationArea_Header(isfirst, islast, title, titleicon, istitlelink, numofcount));

	vContent.className = 'Content';
	vContent.style.verticalAlign = 'top';
	vContent.id = "ID_NOTIFICATION_CONTENT";
	vContent.appendChild(createNotificationArea_Content(desc, descicon, isdesclink, backgroundimage));

	var vArea = getNotificationArea();

	if (backgroundimage == "")
		vArea.style.backgroundImage = "";
	else {
		vArea.style.backgroundImage = "url(" + backgroundimage + ")";
		vArea.style.backgroundPosition = (g_Direction == "ltr") ? "center right" : "center left";
		vArea.style.backgroundRepeat = "no-repeat";
	}

	vArea.className = 'NotificationArea';
	vArea.id = "ID_NOTIFICATIONAREA";
	vArea.appendChild(vContainer);
}

//////////////////////////////////////////////
// Content
function createNotificationArea_Content(desc, descicon, isdesclink, backgroundimage) {
	return;
	var vTbl = document.createElement("TABLE");
	var vBdy = vTbl.appendChild(document.createElement("TBODY"));
	var vTr = vBdy.appendChild(document.createElement("TR"));
	var vTd = vTr.appendChild(document.createElement("TD"));
	vTd.className = "Icon";
	var vImg = vTd.appendChild(document.createElement("IMG"));
	vImg.src = descicon;
	if (!descicon)
		vImg.style.display = "none";
	vTd = vTr.appendChild(document.createElement("TD"));
	vTd.className = "Title";
	var vDiv = vTd.appendChild(document.createElement("DIV"));
	if (isdesclink == "1") {
		vA = vDiv.appendChild(document.createElement("A"));
		vA.appendChild(document.createTextNode(desc));
		vA.href = "javascript: void(0);";
		vA.attachEvent("onclick", onNotificationPanelDescClick);
	}
	else
		vDiv.appendChild(document.createTextNode(desc));
	vTbl.cellPadding = "0";
	vTbl.cellSpacing = "0";
	vTbl.className = "Content";
	return vTbl;
}

//////////////////////////////////////////////
// Header
function createNotificationArea_Header(isfirst, islast, title, titleicon, istitlelink, numofcount) {
	return;
	var vTbl = document.createElement("TABLE");
	var vBody = vTbl.appendChild(document.createElement("TBODY"));
	var vTr = vBody.appendChild(document.createElement("TR"));
	var vTd, vImg, vDiv, vA;
	vTd = vTr.appendChild(document.createElement("TD"));
	vTd.className = "Icon";

	vImg = vTd.appendChild(document.createElement("IMG"));
	vImg.src = titleicon;
	if (!titleicon)
		vTd.style.display = "none";

	vTd = vTr.appendChild(document.createElement("TD"));
	vTd.className = "Title";
	vDiv = vTd.appendChild(document.createElement("DIV"));
	if (istitlelink == "1") {
		vA = vDiv.appendChild(document.createElement("A"));
		vA.appendChild(document.createTextNode(title));
		vA.href = "javascript: void(0);";
		vA.attachEvent("onclick", onNotificationPanelTitleClick);
	}
	else
		vDiv.appendChild(document.createTextNode(title));
	vTd = vTr.appendChild(document.createElement("TD"));
	vTd.className = "PrevButton";
	if (isfirst == "0") {
		vImg = vTd.appendChild(document.createElement("IMG"));
		vImg.style.cursor = "pointer";
		vImg.src = (g_Direction == "rtl") ? "images/np_rightarrow.png" : "images/np_leftarrow.png";
		vImg.alt = getString("IDS_PREV");
		vImg.attachEvent("onmouseenter", onPanelButtonEnter);
		vImg.attachEvent("onmouseleave", onPanelButtonLeave);
		vImg.attachEvent("onclick", onPrevClick);
	}
	else {
		vImg = vTd.appendChild(document.createElement("IMG"));
		vImg.src = (g_Direction == "rtl") ? "images/np_rightarrow_disable.png" : "images/np_leftarrow_disable.png";
	}
	vTd = vTr.appendChild(document.createElement("TD"));
	vTd.className = "NumberOfCount";
	vTd.appendChild(document.createTextNode(numofcount));
	vTd = vTr.appendChild(document.createElement("TD"));
	vTd.className = "NextButton";
	if (islast == "0") {
		vImg = vTd.appendChild(document.createElement("IMG"));
		vImg.style.cursor = "pointer";
		vImg.src = (g_Direction == "ltr") ? "images/np_rightarrow.png" : "images/np_leftarrow.png";
		vImg.alt = getString("IDS_NEXT");
		vImg.attachEvent("onmouseenter", onPanelButtonEnter);
		vImg.attachEvent("onmouseleave", onPanelButtonLeave);
		vImg.attachEvent("onclick", onNextClick);
	}
	else {
		vImg = vTd.appendChild(document.createElement("IMG"));
		vImg.src = (g_Direction == "ltr") ? "images/np_rightarrow_disable.png" : "images/np_leftarrow_disable.png";
	}

	vTd = vTr.appendChild(document.createElement("TD"));
	vTd.className = "RefreshButton";

	vImg = vTd.appendChild(document.createElement("IMG"));
	vImg.src = "images/refresh16.png";
	vImg.alt = getString("IDS_REFRESH");
	vImg.attachEvent("onmouseenter", onPanelButtonEnter);
	vImg.attachEvent("onmouseleave", onPanelButtonLeave);
	vImg.attachEvent("onclick", onNotificationPanelRefresh);

	vTbl.cellPadding = "0";
	vTbl.cellSpacing = "0";
	vTbl.className = "Header";
	return vTbl;
}

function refreshNotificationArea(isfirst, islast, numofcount, title, titleicon, istitlelink, desc, descicon, isdesclink, backgroundimage) {
	return;
	var vHeader = $("ID_NOTIFICATION_HEADER");
	if (!vHeader)
		return;

	var vTd = sjcl.dom.getChildByClassName(vHeader, "Icon");
	if (vTd.firstChild)
		vTd.removeChild(vTd.firstChild);

	vTd.className = "Icon";
	var vImg = vTd.appendChild(document.createElement("IMG"));
	vImg.src = titleicon;
	vTd.style.display = "block";
	if (!titleicon)
		vTd.style.display = "none";

	vTd = sjcl.dom.getChildByClassName(vHeader, "NumberOfCount");
	vTd.innerHTML = numofcount;

	vTd = sjcl.dom.getChildByClassName(vHeader, "Title");
	if (vTd.firstChild)
		vTd.removeChild(vTd.firstChild);

	var vDiv = vTd.appendChild(document.createElement("DIV"));
	if (istitlelink == "1") {
		var vA = vDiv.appendChild(document.createElement("A"));
		vA.appendChild(document.createTextNode(title));
		vA.href = "javascript: void(0);";
		vA.attachEvent("onclick", onNotificationPanelTitleClick);
	}
	else
		vDiv.appendChild(document.createTextNode(title));

	vTd = sjcl.dom.getChildByClassName(vHeader, "PrevButton");
	if (vTd.firstChild)
		vTd.removeChild(vTd.firstChild);
	if (isfirst == "0") {
		vImg = vTd.appendChild(document.createElement("IMG"));
		vImg.style.cursor = "pointer";
		vImg.src = (g_Direction == "rtl") ? "images/np_rightarrow.png" : "images/np_leftarrow.png";
		vImg.alt = getString("IDS_PREV");
		vImg.attachEvent("onmouseenter", onPanelButtonEnter);
		vImg.attachEvent("onmouseleave", onPanelButtonLeave);
		vImg.attachEvent("onclick", onPrevClick);
	}
	else {
		vImg = vTd.appendChild(document.createElement("IMG"));
		vImg.src = (g_Direction == "rtl") ? "images/np_rightarrow_disable.png" : "images/np_leftarrow_disable.png";
	}

	vTd = sjcl.dom.getChildByClassName(vHeader, "NextButton");
	if (vTd.firstChild)
		vTd.removeChild(vTd.firstChild);
	if (islast == "0") {
		vImg = vTd.appendChild(document.createElement("IMG"));
		vImg.style.cursor = "pointer";
		vImg.src = (g_Direction == "ltr") ? "images/np_rightarrow.png" : "images/np_leftarrow.png";
		vImg.alt = getString("IDS_NEXT");
		vImg.attachEvent("onmouseenter", onPanelButtonEnter);
		vImg.attachEvent("onmouseleave", onPanelButtonLeave);
		vImg.attachEvent("onclick", onNextClick);
	}
	else {
		vImg = vTd.appendChild(document.createElement("IMG"));
		vImg.src = (g_Direction == "ltr") ? "images/np_rightarrow_disable.png" : "images/np_leftarrow_disable.png";
	}

	var vArea = $("ID_NOTIFICATIONAREA");
	if (vArea) {
		if (backgroundimage == "")
			vArea.style.backgroundImage = "";
		else {
			vArea.style.backgroundImage = "url(" + backgroundimage + ")";
			vArea.style.backgroundPosition = (g_Direction == "ltr") ? "center right" : "center left";
			vArea.style.backgroundRepeat = "no-repeat";
		}
	}

	var vBody = $("ID_NOTIFICATION_CONTENT");
	if (!vBody)
		return;
	vTd = sjcl.dom.getChildByClassName(vBody, "Icon");
	if (vTd.firstChild)
		vTd.removeChild(vTd.firstChild);
	vTd.className = "Icon";
	vImg = vTd.appendChild(document.createElement("IMG"));
	vImg.src = descicon;
	vTd.style.display = "block";
	if (!descicon)
		vTd.style.display = "none";

	vTd = sjcl.dom.getChildByClassName(vBody, "Title");
	if (vTd.firstChild)
		vTd.removeChild(vTd.firstChild);

	vDiv = vTd.appendChild(document.createElement("DIV"));
	if (isdesclink == "1") {
		var vA = vDiv.appendChild(document.createElement("A"));
		vA.appendChild(document.createTextNode(desc));
		vA.href = "javascript: void(0);";
		vA.attachEvent("onclick", onNotificationPanelDescClick);
	}
	else
		vDiv.appendChild(document.createTextNode(desc));

}

function dropNotificationArea() {
	return;
	var vArea = $("ID_NOTIFICATIONAREA");
	if (vArea) {
		if (vArea.firstChild) {
			var fade = sjcl.dom.getFilter(vArea, "Fade");
			var slide = sjcl.dom.getFilter(vArea, "Slide");

			slide && slide.apply();
			fade && fade.apply();
			vArea.style.visibility = 'hidden';
			fade && fade.play();
			slide && slide.play();

			window.setTimeout(onFilterChange, 300);
		}
	}
}

function onFilterChange() {
	vArea = $('ID_NOTIFICATIONAREA');
	vArea.parentNode.removeChild(vArea);
}

function onPrevClick() {
	window.external.OnMovePreviousClick();
}

function onNextClick() {
	window.external.OnMoveNextClick();
}

function onNotificationPanelRefresh() {
	window.external.OnNotificationPanelRefresh();
}

function onNotificationPanelTitleClick() {
	window.external.OnNotificationPanelTitleClick();
}

function onNotificationPanelDescClick() {
	window.external.OnNotificationPanelDescClick();
}
///////////////////////////////////////////////////////
///////////////////////////////////////////////////////

function setPanelContent(name, content) {
	var panel = $(makePanelId(name));

	if (!panel)
		return;

	var div = panel.firstChild.nextSibling;
	var tbl = document.createElement("TABLE");
	var bdy = tbl.appendChild(document.createElement("TBODY"));
	var tr = bdy.appendChild(document.createElement("TR"));
	var td = tr.appendChild(document.createElement("TD"));

	tbl.cellPadding = "0";
	tbl.cellSpacing = "0";
	tbl.style.tableLayout = "fixed";

	td.innerHTML = content;

	if (div.firstChild)
		div.removeChild(div.firstChild);

	div.appendChild(tbl);
}

function setPanelCaption(name, caption) {
	var panel = $(makePanelId(name));
	var header = panel.firstChild;
	var td = sjcl.dom.getChildByClassName(header, "Title");
	var div = td.firstChild;

	div.innerHTML = caption;
}

function setPanelIcon(name, icon) {
	var panel = $(makePanelId(name));
	var header = panel.firstChild;
	var td = sjcl.dom.getChildByClassName(header, "Icon");
	var img = td.firstChild;

	td.style.display = "block";
	img.src = icon;
}

function clearPanel(name) {
	var panel = $(makePanelId(name));
	var bdy = panel.firstChild.nextSibling;

	if (bdy.firstChild)
		bdy.removeChild(bdy.firstChild);
}

function getPanelButtonImage(panel, img) {
	var tds = panel.firstChild.getElementsByTagName("TD");

	for (var i = 0; i < tds.length; i++) {
		var td = tds.item(i);

		if (td.getAttribute("Action") == img)
			return td.firstChild;
	}

	return null;
}

function expandPanel(name, showEffect) {
	if (!window.external.OnPanelExpanding(name))
		return;

	var panel = $(makePanelId(name));

	if (panel && !panel.getAttribute("Expanded")) {
		if (!showEffect) {
			var bdy = panel.firstChild.nextSibling;
			var img = getPanelButtonImage(panel, "Toggle");

			bdy.style.display = "block";
			img.src = img.src.replace("expand", "collapse");
			panel.setAttribute("Expanded", true);

			window.external.OnPanelExpaned(name);
		}
		else
			togglePanel(panel, true);
	}
}

function collapsePanel(name, showEffect) {
	if (!window.external.OnPanelCollapsing(name))
		return;

	var panel = $(makePanelId(name));

	if (panel && panel.getAttribute("Expanded")) {
		if (!showEffect) {
			var bdy = panel.firstChild.nextSibling;
			var img = getPanelButtonImage(panel, "Toggle");

			bdy.style.display = "none";
			img.src = img.src.replace("collapse", "expand");
			panel.setAttribute("Expanded", false);

			window.external.OnPanelCollapsed(name);
		}
		else
			togglePanel(panel, false);
	}
}

function togglePanel(panel, expand) {
	var bdy = panel.firstChild.nextSibling;
	var img = getPanelButtonImage(panel, "Toggle");

	bdy.style.display = expand ? "block" : "none";
	panel.setAttribute("Expanded", !panel.getAttribute("Expanded"));

	if (!expand)
		img.src = img.src.replace("collapse", "expand");
	else
		img.src = img.src.replace("expand", "collapse");
}

/*function doTogglePanel(panel, step, visibility) {
	var bdy = panel.firstChild.nextSibling;
	var tbl = bdy.firstChild;
	var height = bdy.offsetHeight + step;
	var panelId = getPanelNameById(panel.id);

	height = Math.max(1, Math.min(height, tbl.offsetHeight));
	bdy.style.height = height + "px";

	if (height == 1)
		bdy.style.display = "none";

	if (height == tbl.offsetHeight)
		bdy.style.height = "";

	if ((height == 1) || (height == tbl.offsetHeight)) {
		var img = getPanelButtonImage(panel, "Toggle");

		if (height == 1)
			img.src = img.src.replace("collapse", "expand");
		else
			img.src = img.src.replace("expand", "collapse");

		panel.setAttribute("Expanded", !panel.getAttribute("Expanded"));

		window.clearInterval(g_PanelToggleTimersId[panel.id]);
		delete g_PanelToggleTimersId[panel.id];
		g_Idle = true;

		if (height == 1)
			window.external.OnPanelCollapsed(panelId);
		else
			window.external.OnPanelExpanded(panelId);
	}
}*/

function closePanel(name, showEffect) {
	if (!window.external.OnPanelClosing(name))
		return;

	var id = makePanelId(name);
	var panel = $(id);

	if (!panel)
		return;

	doClosePanel(panel);

	var tabName = panel.getAttribute("Location");
	var menu = g_MenuStrip.getMenu("mnuAllPanels");

	menu.setItemCheck(makeTabPanelsMenuItemId(name), false);
}

function doClosePanel(panel) {
	panel.style.display = "none";
	window.external.OnPanelClosed(getPanelNameById(panel.id));
	g_Idle = true;
}

function showPanel(name) {
	var id = makePanelId(name);
	var panel = $(id);

	panel.style.visibility = "visible";
	panel.style.display = "block";
}

function hidePanel(name) {
	var id = makePanelId(name);
	var panel = $(id);

	panel.style.display = "none";
}

function sendPanelTo(panel, location) {
	var prevLocation = panel.getAttribute("Location");

	selectTab(location);
	appendPanel(panel, g_TabsInfo.item(location), -1, 0);

	panel.setAttribute("Location", location);
	window.external.OnPanelMoved(getPanelNameById(panel.id), "", prevLocation, location);

	updateTabPanelsMenu(panel, prevLocation, location);
	updateTabPanelsPositions(location);

	updateTabPanelsPositions(g_SelectedTab);
	updateTabPanelsPositions(prevLocation);
}

function refreshPanel(name) {
	window.external.OnPanelRefresh(name);
}

function onPanelIconClick() {
	var src = window.event.srcElement;
	var td = src.parentNode;
	var panel = sjcl.dom.getAncestorByClassName(td, "Panel");

	g_MenuStrip.showContextMenu("mnuPanel", src, panel, "ltr");
}

function onPanelButtonEnter() {
	var e = window.event.srcElement;

	e.src = e.src.replace(".png", "_hover.png");
}

function onPanelButtonLeave() {
	var e = window.event.srcElement;

	e.src = e.src.replace("_hover.png", ".png");
}

function onPanelButtonClick() {
	var src = window.event.srcElement;
	var td = src.parentNode;
	var panel = sjcl.dom.getAncestorByClassName(td, "Panel");
	var action = td.getAttribute("Action");
	var name = getPanelNameById(panel.id);

	if (!g_Idle)
		return;

	if (action == "Close")
		closePanel(name, true);
	else if (action == "Toggle") {
		if (panel.getAttribute("Expanded"))
			collapsePanel(name, true);
		else
			expandPanel(name, true);
	}
	else if (action == "Refresh")
		refreshPanel(name);
	else if (action == "Customize")
		window.external.OnPanelCustomize(name);
}

function onPanelItemClick(panel, id) {
	window.external.OnPanelItemClick(panel, id);
}

function onPanelCustomize(name) {
	window.external.OnPanelCustomize(name);
}

function onPanelCaptionClick() {
	var src = window.event.srcElement;
	var panel = sjcl.dom.getAncestorByClassName(src, "Panel");

	window.external.OnPanelCaptionClick(getPanelNameById(panel.id));
}

function onPanelTitleMouseDown() {
	var src = window.event.srcElement;

	if (src.tagName == "A")
		return;

	var panel = sjcl.dom.getAncestorByClassName(src, "Panel");
	var dragStatus = new DragStatus(panel, event.clientX, event.clientY);
	var clone = null;
	var hilite = null;
	var navBar = getNavBar();
	var rcNavBar = sjcl.dom.elementRect(navBar);
	var navBarPanes = getNavBarPanes();
	var rcNavBarPanes = sjcl.dom.elementRect(navBarPanes);
	var navBarFooter = getNavBarFooter();
	var rcNavBarFooter = sjcl.dom.elementRect(navBarFooter);

	if (!window.external.OnPanelMoving(getPanelNameById(panel.id)))
		return;

	document.attachEvent("onmousemove", onMouseMove);
	document.attachEvent("onmouseup", onMouseUp);

	event.returnValue = false;

	function createClone(x, y) {
		var pt = sjcl.dom.elementPoint(panel);

		clone = panel.cloneNode(true);
		clone.className = "Panel DragPanel";
		clone.style.width = panel.offsetWidth + "px";
		clone.style.left = pt.left + (x - dragStatus.startX) + "px";
		clone.style.top = pt.top + (y - dragStatus.startY) + "px";

		document.body.appendChild(clone);
	}

	function createHilite() {
		hilite = document.createElement("DIV");

		hilite.className = "HilitePanel";
		hilite.style.height = panel.offsetHeight + "px";
	}

	function activateTab(x, y) {
		var tabsGroup = getTabsGroup();
		var rc = sjcl.dom.elementRect(tabsGroup);

		if (rc.contains(x, y)) {
			for (var i = 0; i < g_TabsInfo.length; i++) {
				var ti = g_TabsInfo[i];
				var rc = sjcl.dom.elementRect(ti.cell);

				if (rc.contains(x, y)) {
					if (ti.name != g_SelectedTab)
						selectTab(ti.name);

					return true;
				}
			}
		}

		return false;
	}

	function activateNavBar(x, y) {
		if (rcNavBar.contains(x, y)) {
			if ((g_NavBar.panesSize > 0) && rcNavBarPanes.contains(x, y)) {
				for (var i = 0; i < g_NavBar.panes.length; i++) {
					var pane = g_NavBar.panes[i];

					if (pane.expanded) {
						var td = pane.row.firstChild;
						var rc = sjcl.dom.elementRect(td);

						if (rc.contains(x, y)) {
							selectTab(getPanelNameById(td.id));
							return true;
						}
					}
				}
			}
			else if (rcNavBarFooter.contains(x, y)) {
				for (var i = 0; i < g_NavBar.panes.length; i++) {
					var pane = g_NavBar.panes[i];

					if (!pane.expanded) {
						var td = $(makePaneIconId(pane.name));
						var rc = sjcl.dom.elementRect(td);

						if (rc.contains(x, y)) {
							selectTab(getPaneNameByIconId(td.id));
							return true;
						}
					}
				}
			}
		}

		return false;
	}

	function addHilite(location, target, anchor, pos) {
		if (pos == 1) {
			if (anchor.nextSibling)
				anchor.parentNode.insertBefore(hilite, anchor.nextSibling);
			else
				anchor.parentNode.appendChild(hilite);
		}
		else if (pos == 0)
			anchor.appendChild(hilite);
		else if (pos == -1)
			anchor.parentNode.insertBefore(hilite, anchor);

		dragStatus.dragOver = true;
		dragStatus.location = location;
		dragStatus.target = target;
		dragStatus.anchor = anchor;
		dragStatus.position = pos;
	}

	function removeHilite() {
		removeElement(hilite);

		dragStatus.dragOver = false;
		dragStatus.location = "";
		dragStatus.target = null;
		dragStatus.anchor = null;
		dragStatus.position = 0;
	}

	function isColumnEmpty(td) {
		if (td.childNodes.length == 0)
			return true;

		for (p = td.firstChild; p; p = p.nextSibling) {
			if (p.style.display != "none")
				return false;
		}

		return true;
	}

	function hiliteTabFrame(ti, x, y) {
		var tr = getTabPageTr(ti);
		var bEmptyFrame = true;

		for (var i = 0; i < tr.childNodes.length; i++) {
			var td = tr.childNodes.item(i);
			var rcTd = sjcl.dom.elementRect(td);

			if (td.childNodes.length > 0)
				bEmptyFrame = false;

			if (!rcTd.hContains(x, y))
				continue;

			for (var j = 0; j < td.childNodes.length; j++) {
				var div = td.childNodes.item(j);
				var rc;

				if ((div == panel) || (div == hilite))
					continue;

				rc = sjcl.dom.elementRect(div);

				if (rc.contains(x, y)) {
					if (event.clientY < (rc.top + rc.height / 2))
						addHilite(ti.name, div, div, -1);
					else
						addHilite(ti.name, div, div, 1);

					return true;
				}
			}

			var bEmptyCol = isColumnEmpty(td);

			if (bEmptyCol) {
				if (rcTd.hContains(x, y) && (y > rcTd.top) && (y < rcTd.top + clone.offsetHeight)) {
					addHilite(ti.name, null, td, 0);
					return true;
				}
			}
		}

		var rc = sjcl.dom.elementRect(ti.frame);

		if (rc.contains(x, y))
			return true;

		removeHilite();

		return false;
	}

	function hilitePanels(x, y) {
		var bHilite = false;
		var ti, rc;

		if (g_SelectedTab) {
			ti = g_TabsInfo.item(g_SelectedTab);
			rc = sjcl.dom.elementRect(ti.frame);

			if (rc.hContains(x, y))
				bHilite = hiliteTabFrame(ti, x, y);
		}

		if (!bHilite && g_NavBar.selectedPane) {
			ti = g_TabsInfo.item(g_NavBar.selectedPane);
			rc = sjcl.dom.elementRect(ti.frame);

			if (rc.hContains(x, y))
				bHilite = hiliteTabFrame(ti, x, y);
		}

		return bHilite;
	}

	function onMouseMove() {
		if (g_InDragMode || (Math.abs(event.clientX - dragStatus.startX) > dragStatus.dragRect) || (Math.abs(event.clientY - dragStatus.startY) > dragStatus.dragRect)) {
			var location = panel.getAttribute("Location");
			var shiftX = 0;
			var shiftY = 0;
			var bHilited;

			if (dragStatus.status == 0) {
				createClone(event.clientX, event.clientY);
				createHilite();
				panel.style.display = "none";
				dragStatus.status = 1;

				addHilite(panel.getAttribute("Location"), panel, panel, -1);
			}

			clone.style.left = (event.clientX - dragStatus.deltaX) + "px";
			clone.style.top = (event.clientY - dragStatus.deltaY) + "px";

			bHilited = activateTab(event.clientX, event.clientY);

			if (!bHilited)
				bHilited = activateNavBar(event.clientX, event.clientY);

			if (!bHilited)
				hilitePanels(event.clientX, event.clientY);

			g_InDragMode = true;
		}

		event.returnValue = false;
		event.cancelBubble = true;
	}

	function onMouseUp() {
		document.detachEvent("onmousemove", onMouseMove);
		document.detachEvent("onmouseup", onMouseUp);

		if (clone)
			removeElement(clone);

		if (hilite)
			removeElement(hilite);

		panel.style.display = "block";

		if (dragStatus.dragOver) {
			var prevLocation = panel.getAttribute("Location");
			var location = dragStatus.location;
			var strSource = getPanelNameById(panel.id);
			var strTarget = dragStatus.target ? getPanelNameById(dragStatus.target.id) : "";
			var ti = g_TabsInfo.item(location);

			if (window.external.OnPanelDrop(strSource, strTarget, prevLocation, location)) {
				if (dragStatus.position == 0)
					dragStatus.anchor.appendChild(panel);
				else if (dragStatus.position == -1)
					dragStatus.target.parentNode.insertBefore(panel, dragStatus.target);
				else if (dragStatus.position == 1) {
					if (dragStatus.target.nextSibling)
						dragStatus.target.parentNode.insertBefore(panel, dragStatus.target.nextSibling);
					else
						dragStatus.target.parentNode.appendChild(panel);
				}

				panel.setAttribute("Location", location);
				window.external.OnPanelMoved(strSource, strTarget, prevLocation, location)
			}

			updateTabPanelsMenu(panel, prevLocation, location);
			updateTabPanelsPositions(location);

			if (location != prevLocation)
				updateTabPanelsPositions(prevLocation);
		}

		g_InDragMode = false;
	}
}

function isPanelExpanded(name) {
	var panel = $(makePanelId(name));

	return panel.getAttribute("Expanded");
}

function setPanelBackgroundImage(name, image) {
	return;
	var panel = $(makePanelId(name));
	var bdy = panel.firstChild.nextSibling;

	if (!bdy)
		return;

	if (arguments.length == 1)
		bdy.style.backgroundImage = "";
	else if (image)
		bdy.style.backgroundImage = "url(" + image + ")";
}

function createNavBarPaneTable(name, caption, icon) {
	var tbl = document.createElement("TABLE");
	var bdy = tbl.appendChild(document.createElement("TBODY"));
	var tr = bdy.appendChild(document.createElement("TR"));
	var td, img;

	td = tr.appendChild(document.createElement("TD"));
	td.className = "Icon";

	img = td.appendChild(document.createElement("IMG"));
	img.src = icon;

	if (!icon)
		td.style.visibility = "hidden";

	td = tr.appendChild(document.createElement("TD"));
	td.className = "Caption";

	td.appendChild(document.createTextNode(caption));

	tbl.cellSpacing = "0px";
	tbl.cellPadding = "0px";

	return tbl;
}

function createNavBarPaneFrame() {
	var tbl = document.createElement("TABLE");
	var bdy = tbl.appendChild(document.createElement("TBODY"));
	var tr = bdy.appendChild(document.createElement("TR"));
	var td = tr.appendChild(document.createElement("TD"));

	tbl.style.tableLayout = "Fixed";
	tbl.cellPadding = "0px";
	tbl.cellSpacing = "5px";

	return tbl;
}

function getNextNavBarPane(name) {
	var pane = $(makePaneId(name));
	var tr = pane.parentNode;

	var id = "";

	if (tr.nextSibling)
		id = tr.nextSibling.firstChild.id;
	else if (tr.previousSibling)
		id = tr.previousSibling.firstChild.id;

	return id != "" ? getPaneNameById(id) : "";
}

function adjustNavBarFooter(footerWidth) {
	var div = getNavBarFooter();
	var tbl = div.firstChild;
	var tr = tbl.firstChild.firstChild;

	if (footerWidth == undefined)
		footerWidth = div.offsetWidth;

	var width = 0;
	var maxWidth = footerWidth - g_NavBarIconWidth;
	var needMenu = false;

	for (var i = g_NavBar.panes.length - 1; i >= 0; i--) {
		var pane = g_NavBar.panes[i];
		var td = $(makePaneIconId(pane.name));

		if (!pane.expanded) {
			width += g_NavBarIconWidth;

			td.style.display = (width < maxWidth) ? "block" : "none";
			needMenu = (width > maxWidth);
		}
		else
			td.style.display = "none";
	}

	g_NavBar.MenuEnabled = needMenu;
	setNavBarMenuEnabled(needMenu);
}

function addNavBarFooterIcon(name) {
	var ti = g_TabsInfo.item(name);
	var div = getNavBarFooter();
	var tbl = div.firstChild;
	var tr = tbl.firstChild.firstChild;
	var td, img;
	var width = getNavBarWidth();

	td = document.createElement("TD");

	td.id = makePaneIconId(name);
	td.className = "NavBarFooterIcon";
	td.style.display = "none";
	td.attachEvent("onmouseenter", onNavBarFooterIconOver);
	td.attachEvent("onmouseleave", onNavBarFooterIconOut);
	td.attachEvent("onmousedown", onNavBarFooterIconDown);
	td.attachEvent("onmouseup", onNavBarFooterIconUp);
	td.attachEvent("onclick", onNavBarFooterIconClick);

	img = td.appendChild(document.createElement("IMG"));
	img.src = ti.icon;

	if (tr.childNodes.length > 0)
		tr.insertBefore(td, tr.firstChild);
	else
		tr.appendChild(td);
}

function addNavBarPane(name) {
	var ti = g_TabsInfo.item(name);
	var tbl = getNavBarPanes();
	var bdy = tbl.firstChild;
	var tr, td;

	tr = document.createElement("TR");
	td = tr.appendChild(document.createElement("TD"));

	td.appendChild(createNavBarPaneTable(name, ti.caption, ti.largeIcon));
	td.id = makePaneId(name);
	td.className = "NavBarPane";
	td.setAttribute("PaneContainer", true);
	td.attachEvent("onmouseenter", onNavBarPaneOver);
	td.attachEvent("onmouseleave", onNavBarPaneOut);
	td.attachEvent("onmousedown", onNavBarPaneDown);
	td.attachEvent("onmouseup", onNavBarPaneUp);
	td.attachEvent("onclick", onNavBarPaneClick);

	tr.style.display = "none";
	tbl.style.display = "block";

	if (bdy.childNodes.length > 0)
		bdy.insertBefore(tr, bdy.firstChild);
	else
		bdy.appendChild(tr);

	g_NavBar.panes.push(new NavBarPane(name, false, tr));
	addNavBarFooterIcon(name);
	appendTabToMenu("mnuNavBar", makeNavBarMenuId(name), ti.caption, ti.icon);
	adjustNavBarFooter();
}

function removeNavBarPane(name) {
	var pane = $(makePaneId(name));
	var tr = pane.parentNode;
	var nextPane = getNextNavBarPane(name);
	var tdIcon = $(makePaneIconId(name));

	removeElement(tr);
	removeElement(tdIcon);
	g_NavBar.panes.remove(name);

	g_NavBar.selectedPane = "";
	setNavBarButtonVisible("NavBarDock", false);
	setNavBarButtonVisible("NavBarRefresh", false);
	setNavBarButtonVisible("NavBarPM", false);
	setNavBarCaption("");
	showNavBarPanes(g_NavBar.panesSize, true);
	adjustNavBarFooter();
	removeTabFromMenu("mnuNavBar", makeNavBarMenuId(name));

	if (g_NavBar.panes.length == 0)
		showNavBarPanesTable(false);

	if (nextPane)
		selectTab(nextPane);
}

function updateNavBarPaneCaption(ti) {
	var pane = g_NavBar.panes.item(ti.name);
	var td = sjcl.dom.getChildByClassName(pane.row, "Caption");

	td.innerHTML = ti.caption;

	if (g_NavBar.selectedPane == ti.name)
		setNavBarCaption(ti.caption);
}

function setNavBarCaption(caption) {
	var div = getNavBarCaption();
	var cell = sjcl.dom.getChildByTagName(div, "DIV");

	cell.innerHTML = caption;
}

function getNavBarWidth() {
	var navBar = getNavBar();

	return navBar.offsetWidth;
}

function setNavBarWidth(width) {
	var navBar = getNavBar();
	var logo = getLogo();

	navBar.style.width = width + "px";
	logo.style.width = width + "px";
}

function setNavBarPanes(panes) {
	showNavBarPanes(panes, true);
	adjustNavBarFooter();
	onWindowResize();
}

function adjustNavBarWidth() {
	var splitter = getSplitter();

	if (g_Direction == "ltr")
		setNavBarWidth(splitter.offsetLeft);
	else
		setNavBarWidth(getClientWidth() - (splitter.offsetLeft + splitter.offsetWidth));
}

function setNavBarButtonVisible(id, state) {
	var e = $(id);

	e.style.visibility = state ? "visible" : "hidden";
}

function setNavBarMenuEnabled(state) {
	var td = getNavBarMenuArrow();
	var img = td.firstChild;
	var file = state ? "nb_menu.png" : "nb_menu_disabled.png";

	img.src = "images/" + g_Direction + "/" + file;
	td.setAttribute("Enabled", state);
}

function setNavBarWithLimits(min, max) {
	g_NavBarMinWidth = min;
	g_NavBarMaxWidth = max;
}

function setNavBarVisible(state) {
	var navBar = getNavBar();

	navBar.style.display = state ? "block" : "none";
}

function getNavBarVisible() {
	var navBar = getNavBar();

	return navBar.style.display != "none";
}

function showNavBarPanes(count, force) {
	if (force || g_NavBar.panesSize != count) {
		g_NavBar.panesSize = 0;

		for (i = 0; i < g_NavBar.panes.length; i++) {
			var pane = g_NavBar.panes[i];
			var expanded = i < count;

			pane.row.style.display = expanded ? "block" : "none";
			pane.expanded = expanded;

			if (expanded)
				g_NavBar.panesSize++;
		}
	}
}

function showNavBarPanesTable(state) {
	var tbl = getNavBarPanes();

	tbl.style.display = state ? "block" : "none";
}

function onNavBarButtonOver() {
	if (!g_InDragMode) {
		var e = event.srcElement;

		if (e.parentNode.getAttribute("Active"))
			return;

		e.src = e.src.replace(".png", "_hover.png");
	}
}

function onNavBarButtonOut() {
	if (!g_InDragMode) {
		var e = event.srcElement;

		if (e.parentNode.getAttribute("Active"))
			return;

		e.src = e.src.replace("_hover", "");
	}
}

function onNavBarDockClick() {
	undockTab(g_NavBar.selectedPane, true);
}

function onNavBarRefreshClick() {
	window.external.OnTabRefresh(g_NavBar.selectedPane);
}

function onNavBarPMClick() {
	if (!g_NavBar.selectedPane)
		return;

	var menu = g_MenuStrip.getMenu(makeTabPanelsMenuId(g_NavBar.selectedPane));

	if (menu.length() == 0)
		return;

	fillTabPanelsMenu(g_NavBar.selectedPane);
	showPanelsMenu(true, true);
	document.attachEvent("onmousedown", onMouseDown);

	function onMouseDown() {
		var btn = $("NavBarPM");
		var cp = getPanelsMenu();
		var src = event.srcElement;

		if (btn.contains(src))
			return;

		showPanelsMenu(false, true)
		document.detachEvent("onmousedown", onMouseDown);
	}
}

function onNavBarPaneOver() {
	if (!g_InDragMode) {
		var e = event.srcElement;
		var name = getPaneNameById(e.id);

		if (name != g_NavBar.selectedPane)
			e.className = "NavBarPaneHover";
	}
}

function onNavBarPaneOut() {
	if (!g_InDragMode) {
		var e = event.srcElement;
		var name = getPaneNameById(e.id);

		if (name != g_NavBar.selectedPane)
			e.className = "NavBarPane";
	}
}

function onNavBarPaneDown() {
	var src = event.srcElement;
	var pane = sjcl.dom.getAncestorByAttribute(src, "PaneContainer");
	var name = getPaneNameById(pane.id);

	if (name != g_NavBar.selectedPane)
		pane.className = "NavBarPaneActive";
}

function onNavBarPaneUp() {
	var src = event.srcElement;
	var pane = sjcl.dom.getAncestorByAttribute(src, "PaneContainer");
	var name = getPaneNameById(pane.id);

	if (name != g_NavBar.selectedPane)
		pane.className = "NavBarPane";
}

function onNavBarPaneClick() {
	var src = event.srcElement;
	var pane = sjcl.dom.getAncestorByAttribute(src, "PaneContainer");

	selectTab(getPaneNameById(pane.id));
}

function onNavBarFooterIconOver() {
	if (!g_InDragMode) {
		var e = event.srcElement;
		var name = getPaneNameByIconId(e.id);

		if (name != g_NavBar.selectedPane)
			e.className = "NavBarFooterIconHover";
	}
}

function onNavBarFooterIconOut() {
	if (!g_InDragMode) {
		var e = event.srcElement;
		var name = getPaneNameByIconId(e.id);

		if (name != g_NavBar.selectedPane)
			e.className = "NavBarFooterIcon";
	}
}

function onNavBarFooterIconDown() {
	var src = event.srcElement;
	var pane = sjcl.dom.getAncestorByTagName(src, "TD");
	var name = getPaneNameByIconId(pane.id);

	if (name != g_NavBar.selectedPane)
		pane.className = "NavBarFooterIconActive";
}

function onNavBarFooterIconUp() {
	var src = event.srcElement;
	var pane = sjcl.dom.getAncestorByTagName(src, "TD");
	var name = getPaneNameByIconId(pane.id);

	if (name != g_NavBar.selectedPane)
		pane.className = "NavBarFooterIconSelected";
}

function onNavBarFooterIconClick() {
	var src = event.srcElement;
	var td = sjcl.dom.getAncestorByTagName(src, "TD");

	selectTab(getPaneNameByIconId(td.id));
}

function onNavBarMenuOver() {
	if (!g_InDragMode) {
		var e = event.srcElement;

		if (g_NavBar.MenuEnabled)
			e.className = "NavBarFooterIconHover";
	}
}

function onNavBarMenuOut() {
	if (!g_InDragMode) {
		var e = event.srcElement;

		if (g_NavBar.MenuEnabled)
			e.className = "NavBarFooterIcon";
	}
}

function onNavBarMenuDown() {
	var e = event.srcElement;
	var td = sjcl.dom.getAncestorByTagName(e, "TD");

	if (g_NavBar.MenuEnabled)
		td.className = "NavBarFooterIconActive";
}

function onNavBarMenuUp() {
	var e = event.srcElement;
	var td = sjcl.dom.getAncestorByTagName(e, "TD");

	if (g_NavBar.MenuEnabled)
		td.className = "NavBarFooterIconHover";
}

function onNavBarMenuClick() {
	if (g_NavBar.panes.length > 0 && g_NavBar.MenuEnabled) {
		var e = sjcl.dom.getAncestorByTagName(event.srcElement, "TD");
		var rc = sjcl.dom.elementRect(e);
		var x = (g_Direction == "ltr") ? rc.right + 1 : rc.left;

		g_MenuStrip.showContextMenu("mnuNavBar", x, rc.top, null, "ltr");
	}
}

function onSplitterMouseDown() {
	if (!window.external.OnNavBarResizing())
		return;

	var splitter = window.event.srcElement;
	var dragStatus = new DragStatus(splitter, event.clientX, event.clientY);
	var clone = createSplitter();
	var leftLimit = (g_Direction == "rtl") ? getClientWidth() - g_NavBarMaxWidth : g_NavBarMinWidth;
	var rightLimit = (g_Direction == "rtl") ? getClientWidth() - g_NavBarMinWidth : g_NavBarMaxWidth;

	document.attachEvent("onmousemove", onMouseMove);
	document.attachEvent("onmouseup", onMouseUp);
	splitter.setCapture(true);

	document.body.style.cursor = "col-resize";
	g_InDragMode = true;

	function createSplitter() {
		var div = document.createElement("DIV");

		div.className = "SplitterClone";
		sjcl.dom.makeSamePlacement(splitter, div);
		document.body.appendChild(div);

		return div;
	}

	function onMouseMove() {
		var left = event.clientX - dragStatus.deltaX;

		left = Math.max(leftLimit, Math.min(left, rightLimit));
		clone.style.left = left + "px";

		event.returnValue = false;
		event.cancelBubble = true;
	}

	function onMouseUp() {
		var width = clone.offsetLeft;

		if (g_Direction == "rtl")
			width = getClientWidth() - width;

		adjustNavBarFooter(width);
		setNavBarWidth(width);
		resizeTabsGroup();

		document.body.style.cursor = "default";
		document.body.removeChild(clone);

		splitter.releaseCapture();
		document.detachEvent("onmousemove", onMouseMove);
		document.detachEvent("onmouseup", onMouseUp);

		dragStatus = null;
		g_InDragMode = false;

		window.external.OnNavBarResized(width);
	}
}

function onNavBarGripMouseDown() {
	if (g_NavBar.panes.length == 0)
		return;

	var grip = window.event.srcElement;
	var panes = getNavBarPanes();
	var footer = panes.nextSibling;
	var paneHeight = g_NavBarPaneHeight;

	document.attachEvent("onmousemove", onMouseMove);
	document.attachEvent("onmouseup", onMouseUp);
	grip.setCapture(true);

	document.body.style.cursor = "n-resize";
	g_InDragMode = true;

	function onMouseMove() {
		var height = footer.offsetTop - event.clientY;
		var size;

		if (height == 0)
			return;

		size = Math.round(height / paneHeight)

		showNavBarPanes(size);
		adjustNavBarFooter();

		event.returnValue = false;
		event.cancelBubble = true;
	}

	function onMouseUp() {
		document.body.style.cursor = "default";

		grip.releaseCapture();
		document.detachEvent("onmousemove", onMouseMove);
		document.detachEvent("onmouseup", onMouseUp);
		g_InDragMode = false;

		window.external.OnNavBarPanesChanged(g_NavBar.panesSize);
	}
}

function addWebRequest(id, url) {
	g_WebRequests.add(id, new sjcl.net.WebRequest(url,
										onWebRequestDone.bind(window, id),
										onWebRequestError.bind(window, id)));
}

function onWebRequestDone(id) {
	var webRequest = g_WebRequests.item(id);

	if (webRequest) {
		var result = webRequest.getText();

		g_WebRequests.remove(id);

		if (result != null)
			window.external.OnWebRequestDone(id, result.trim());
	}
}

function onWebRequestError(id) {
	g_WebRequests.remove(id);
	window.external.OnWebRequestError(id);
}

function onToolBarButtonOver() {
	if (!g_InDragMode) {
		var e = event.srcElement;

		e.className = "ButtonHover";
	}
}

function onToolBarButtonOut() {
	if (!g_InDragMode) {
		var e = event.srcElement;

		if (e.getAttribute("Active"))
			return;

		e.className = "Button";
	}
}

function onCPColumnOver() {
	var e = event.srcElement;
	var cp = getColumnsPanel();
	var cpl = getCPLabel();
	var tr = e.parentNode;

	for (var p = tr.firstChild; ; p = p.nextSibling) {
		p.firstChild.src = p.firstChild.src.replace(".png", "_hover.png");
		cpl.innerText = (p.cellIndex + 1) + " " + getString("IDS_COLUMNS");

		if (p == e)
			break;
	}
}

function onCPColumnOut() {
	var e = sjcl.dom.getAncestorByTagName(event.srcElement, "TD");
	var cp = getColumnsPanel();
	var cpl = getCPLabel();
	var tr = e.parentNode;

	for (var p = tr.firstChild; ; p = p.nextSibling) {
		p.firstChild.src = p.firstChild.src.replace("_hover.png", ".png");
		cpl.innerText = getString("IDS_CANCEL");

		if (p == e)
			break;
	}
}

function onCPColumnClick() {
	var e = sjcl.dom.getAncestorByTagName(event.srcElement, "TD");
	var ti = g_TabsInfo.item(g_SelectedTab);

	showColumnsPanel(false);
	ti.columns = e.cellIndex + 1;
	arrangeTabPanels(g_SelectedTab, true);
	updateTabPanelsPositions(g_SelectedTab);
	window.external.OnTabColumnsChanged(ti.name, ti.columns);
}

function onCPButtonOver() {
	var e = event.srcElement;

	e.className = "ButtonHover";
}

function onCPButtonOut() {
	var e = event.srcElement;

	e.className = "Button";
}

function onCPLableClick() {
	showColumnsPanel(false);
}

function onCustomizeClick() {
	window.external.OnCustomize();
}

function onRefreshClick() {
	window.external.OnRefresh();
}

function showColumnsPanel(visibility) {
	var cp = getColumnsPanel();
	var eraser = getCPEraser();
	var btn = $("btnColumns");
	var rc = sjcl.dom.elementRect(btn);

	if (visibility) {
		btn.className = "ButtonActive";
		cp.style.visibility = "hidden";
		cp.style.display = "block";

		if (g_Direction == "ltr")
			cp.style.left = rc.right - cp.offsetWidth + "px";
		else
			cp.style.left = rc.left + "px";

		cp.style.top = rc.bottom - 1 + "px";
		cp.style.visibility = "visible";

		eraser.style.left = rc.left + 1 + "px";
		eraser.style.top = rc.bottom - 1 + "px";
		eraser.style.width = btn.offsetWidth - 2;
		eraser.style.display = "block";

		btn.setAttribute("Active", true);
	}
	else {
		cp.style.display = "none";
		eraser.style.display = "none";
		btn.className = "Button";
		btn.removeAttribute("Active");
	}
}

function showPanelsMenu(visibility, docked) {
	var btn = docked ? $("NavBarPM") : $("btnPanels");
	var pm = getPanelsMenu();
	var eraser = getPMEraser();
	var rc = sjcl.dom.elementRect(btn);

	if (visibility) {
		if (docked)
			btn.firstChild.src = btn.firstChild.src.replace("hover", "active");
		else
			btn.className = "ButtonActive";

		var filter = pm.filters.item(0);


		pm.setAttribute("Docked", docked);
		pm.style.visibility = "hidden";
		pm.style.display = "block";

		if (g_Direction == "ltr" || docked) {
			filter.direction = 225;
			pm.style.left = rc.right - pm.offsetWidth - (docked ? 1 : 0) + "px";
		}
		else {
			filter.direction = 135;
			pm.style.left = (rc.left + 1) + "px";
		}

		pm.style.top = rc.bottom - 1 + "px";
		pm.style.visibility = "visible";

		eraser.style.width = btn.offsetWidth - (docked ? 4 : 2);
		eraser.style.left = (rc.left + (g_Direction == "ltr" ? 1 : 2)) + "px";
		eraser.style.top = rc.bottom - 1 + "px";
		eraser.style.display = "block";

		btn.setAttribute("Active", true);
	}
	else {
		pm.style.display = "none";
		pm.removeAttribute("Docked");
		eraser.style.display = "none";
		btn.removeAttribute("Active");

		if (docked)
			btn.firstChild.src = btn.firstChild.src.replace("_active", "");
		else
			btn.className = "Button";
	}
}

function onColumnsClick() {
	showColumnsPanel(true);
	document.attachEvent("onmousedown", onMouseDown);

	function onMouseDown() {
		var cp = getColumnsPanel();
		var btn = $("btnColumns");
		var src = event.srcElement;

		if (btn.contains(src))
			return;

		showColumnsPanel(false)
		document.detachEvent("onmousedown", onMouseDown);
	}
}

function fillTabPanelsMenu(name) {
	var menu = g_MenuStrip.getMenu("mnuAllPanels");
	var div = getPanelsMenu();
	var bdy = div.firstChild.firstChild;

	while (bdy.firstChild)
		bdy.removeChild(bdy.firstChild);

	function createMenuItem(item) {
		var tbl = document.createElement("TABLE");
		var bdy = tbl.appendChild(document.createElement("TBODY"));
		var tr = bdy.appendChild(document.createElement("TR"));
		var td, img;

		tbl.cellPadding = "0";
		tbl.cellSpacing = "0";

		td = tr.appendChild(document.createElement("TD"));
		td.className = "Check";

		if (item.checked) {
			img = td.appendChild(document.createElement("IMG"));
			img.src = g_MenuStrip.checkImageUrl;
		}

		td = tr.appendChild(document.createElement("TD"));
		td.className = "Icon";

		if (item.image) {
			img = td.appendChild(document.createElement("IMG"));
			img.src = item.image;
		}

		td = tr.appendChild(document.createElement("TD"));
		td.className = "Caption";
		td.appendChild(document.createTextNode(item.caption));

		return tbl;

	}

	function createHeaderItem(item) {
		var tr = document.createElement("TR");
		var td = tr.appendChild(document.createElement("TD"));
		var ti = g_TabsInfo.item(item.tabName);

		td.className = "Header";
		td.appendChild(document.createTextNode(ti.caption));

		return tr;
	}

	var lastTab = null;

	menu.each(function (item) {
		var tr = document.createElement("TR");
		var td = tr.appendChild(document.createElement("TD"));

		if (item.tabName != lastTab) {
			bdy.appendChild(createHeaderItem(item));
			lastTab = item.tabName;
		}

		td.appendChild(createMenuItem(item));
		td.className = "ItemRect";
		td.attachEvent("onmouseenter", onPanelsMenuEnter);
		td.attachEvent("onmouseleave", onPanelsMenuLeave);
		td.attachEvent("onmousedown", onPanelsMenuClick);
		td.setAttribute("Panel", getPaneNameByMenuId(item.id));

		bdy.appendChild(tr);
	});
}

function onPanelsClick() {
	fillTabPanelsMenu(g_SelectedTab);
	showPanelsMenu(true, false);
	document.attachEvent("onmousedown", onMouseDown);

	function onMouseDown() {
		var btn = $("btnPanels");
		var cp = getPanelsMenu();
		var src = event.srcElement;

		if (btn.contains(src))
			return;

		showPanelsMenu(false, false)
		document.detachEvent("onmousedown", onMouseDown);
	}
}

function onPanelsMenuEnter() {
	var e = event.srcElement;

	e.className = "ItemRectHover";
}

function onPanelsMenuLeave() {
	var e = event.srcElement;

	e.className = "ItemRect";
}

function onPanelsMenuClick() {
	var src = event.srcElement;
	var e = sjcl.dom.getAncestorByAttribute(src, "Panel");
	var panel = e.getAttribute("Panel");
	var pm = getPanelsMenu();
	var tab = pm.getAttribute("Docked") ? g_NavBar.selectedPane : g_SelectedTab;
	var menu = g_MenuStrip.getMenu("mnuAllPanels");
	var item = menu.item(makeTabPanelsMenuItemId(panel));
	var checked = item.checked;

	showPanelsMenu(false, pm.getAttribute("Docked"));
	selectTab(item.tabName);

	if (checked)
		closePanel(panel, true);
	else
		window.external.OnPanelDisplay(panel);

	item.checked = !checked;
}

function onWindowResize() {
	var clientHeight = getClientHeight();
	var height = clientHeight - getTabsContainer().offsetHeight - 6;

	resizeTabsGroup();

	if (height > 0)
		getTabPageFrames().style.height = height;

	height = clientHeight - getLogo().offsetHeight - getNavBarCaption().offsetHeight - getNavBarGrip().offsetHeight - getNavBarPanes().offsetHeight - getNavBarFooter().offsetHeight - 1;

	if (height > 0)
		getNavBarContentCell().style.height = height;
}

function onDocumentSelectStart() {
	var e = event.srcElement;

	if (e && !e.getAttribute("Selectable"))
		event.returnValue = false;
}

function onDocumentDragStart() {
	window.event.returnValue = false;
}

function attachDocument() {
	var e = getTabsMenu();

	e.attachEvent("onmouseenter", onTabsMenuOver);
	e.attachEvent("onmouseleave", onTabsMenuOut);
	e.attachEvent("onclick", onTabsMenuClick);

	var tbr = getToolBar();
	var tr = sjcl.dom.getChildByTagName(tbr, "TR");

	for (var i = 0; i < tr.childNodes.length; i++) {
		var td = tr.childNodes.item(i);

		td.attachEvent("onmouseenter", onToolBarButtonOver);
		td.attachEvent("onmouseleave", onToolBarButtonOut);
	}

	tbr = getCPColumns();
	tr = sjcl.dom.getChildByTagName(tbr, "TR");

	for (var i = 0; i < tr.childNodes.length; i++) {
		var td = tr.childNodes.item(i);

		td.attachEvent("onmouseenter", onCPColumnOver);
		td.attachEvent("onmouseleave", onCPColumnOut);
		td.attachEvent("onmousedown", onCPColumnClick);
	}

	td = getCPLabel();
	td.attachEvent("onmouseenter", onCPButtonOver);
	td.attachEvent("onmouseleave", onCPButtonOut);

	e = getSplitter();
	e.attachEvent("onmousedown", onSplitterMouseDown);

	e = $("NavBarDock");
	e.firstChild.attachEvent("onmouseenter", onNavBarButtonOver);
	e.firstChild.attachEvent("onmouseleave", onNavBarButtonOut);
	e.firstChild.attachEvent("onclick", onNavBarDockClick);

	e = $("NavBarRefresh");
	e.firstChild.attachEvent("onmouseenter", onNavBarButtonOver);
	e.firstChild.attachEvent("onmouseleave", onNavBarButtonOut);
	e.firstChild.attachEvent("onclick", onNavBarRefreshClick);

	e = $("NavBarPM");
	e.firstChild.attachEvent("onmouseenter", onNavBarButtonOver);
	e.firstChild.attachEvent("onmouseleave", onNavBarButtonOut);
	e.firstChild.attachEvent("onclick", onNavBarPMClick);

	e = getNavBarGrip();
	e.attachEvent("onmousedown", onNavBarGripMouseDown);

	e = getNavBarMenuArrow();
	e.attachEvent("onmouseenter", onNavBarMenuOver);
	e.attachEvent("onmouseleave", onNavBarMenuOut);
	e.attachEvent("onmousedown", onNavBarMenuDown);
	e.attachEvent("onmouseup", onNavBarMenuUp);
	e.attachEvent("onclick", onNavBarMenuClick);

	g_MenuStrip.attach(
	{
		target: null,
		direction: g_Direction,
		defaultImageUrl: "images/null16.png",
		checkImageUrl: "images/mnu_check.png",
		arrowImageUrl: "images/" + g_Direction + "/mnu_arrow.png",
		specialEffects: true,
		onInitPopupMenu: onInitPopupMenu,
		onUninit: onUninitPopupMenu,
		onItemClick: onMenuItemClick
	});
}

function registerPanelEvent(name, id, evt) {
	var e = $(id);

	if (e) {
		e.attachEvent(evt,
			function () {
				window.external.OnPanelCommand(name, id, evt);
			}
		);
	}
}

function hiliteRow(tr) {
	for (var td = tr.firstChild; td; td = td.nextSibling)
		td.className += "Hover";
}

function unhiliteRow(tr) {
	for (var td = tr.firstChild; td; td = td.nextSibling)
		td.className = td.className.replace("Hover", "");
}

function getDocumentHtml() {
	return document.body.parentNode.outerHTML;
}

function setToolBarBackground(start, end) {
	var e = $("PageHeader");
	var filter = e.filters.item(0);

	filter.startColorStr = start;
	filter.endColorStr = end;
}

var menu = new sjcl.widget.Menu("mnuPanel");

menu.append({ caption: getString("IDS_REFRESH"), id: makePanelMenuId("Refresh"), image: "images/tab_refresh.png" });
menu.append({ caption: getString("IDS_SEND_TO"), id: makePanelMenuId("SendTo"), menu: "mnuPanelSendTo" });
menu.append({ type: sjcl.widget.MenuItemType.Separator });
menu.append({ caption: getString("IDS_EXPAND"), id: makePanelMenuId("Expand") });
menu.append({ caption: getString("IDS_COLLAPSE"), id: makePanelMenuId("Collapse") });
menu.append({ type: sjcl.widget.MenuItemType.Separator });
menu.append({ caption: getString("IDS_CLOSE"), id: makePanelMenuId("Close"), image: "images/np_close.png" });
g_MenuStrip.append(menu);

g_MenuStrip.append(new sjcl.widget.Menu("mnuPanelSendTo"));
g_MenuStrip.append(new sjcl.widget.Menu("mnuTabs"));
g_MenuStrip.append(new sjcl.widget.Menu("mnuNavBar"));
g_MenuStrip.append(new sjcl.widget.Menu("mnuAllPanels"));

window.attachEvent("onload", attachDocument);
window.attachEvent("onresize", onWindowResize);
document.attachEvent("onselectstart", onDocumentSelectStart);
document.attachEvent("ondragstart", onDocumentDragStart);