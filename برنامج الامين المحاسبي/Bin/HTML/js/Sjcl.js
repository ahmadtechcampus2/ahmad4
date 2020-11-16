
/****************************************************************
 * alameensoft JavaScript Class Library - SJCL                   *
 * Version 1.0.0                                                *
 * by Ziad Abdel-Majeed                                         *
 * Copyright (c) 2006-2017 alameensoft.  All Rights Reserved.    *
 ***************************************************************/

function $()
{
    var elements = [];

    for (var i = 0; i < arguments.length; i++) 
    {
        var element = arguments[i];
    
        if (typeof element == 'string')
            element = document.getElementById(element);

        if (arguments.length == 1)
          return element;

        elements.push(element);
    }

    return elements;
}

function $$(enumerable)
{
    var result = [];
    
    if (enumerable)
    {
        for (var i = 0; i < enumerable.length; i++)
        {
            result.push(enumerable[i]);
        }
    }
    
    return result;    
}

Object.extend = function(dest, src) 
{
    for (p in src) 
    {
        dest[p] = src[p];
    }
  
    return dest;
}

Function.prototype.bind = function(context)
{
    var method = this;
    var args = $$(arguments);
    
    return function()
    {
        method.apply(context, args.slice(1).concat($$(arguments)));
    };
}

Function.prototype.bindAsEvent = function(context)
{
    var method = this;
    
    return function(event)
    {
        method.call(context, event || window.event);
    };
}

Function.prototype.extend = function(src) 
{
    for (p in src) 
    {
        this.prototype[p] = src[p];
    }
  
    return this.prototype;
}

Function.prototype.inherits = function(parent)
{
    this.prototype = new parent();
    this.prototype.constructor = this;
}

Object.extend(Array.prototype,
{
    add: function(item, nodup)
    {
        if (typeof nodup == "undefined")
            nodup = false;
        
        if (!(nodup && this.contains(item)))
            this.push(item);
            
        return item;    
    },
    
    insertAt: function(index, item)
    {
        this.splice(index, 0, item);
    },
    
    removeAt: function(index)
    {
        this.splice(index, 1);
    },
    
    remove: function(item)
    {
        var index = this.indexOf(item);
        
        if (index >= 0)
            this.removeAt(index);
    },
    
    clear: function()
    {
        this.length = 0;
        
        return this;
    },
    
    empty: function()
    {
        return this.length == 0;
    },

    moveBefore: function(index1, index2)
    {
        var item1 = this[index1];
        
        this.splice(index1, 1);
        this.splice((index2 < index1 ? index2 : index2 - 1), 0, item1);
    },
    
    moveAfter: function(index1, index2)
    {
        var item1 = this[index1];
        
        this.splice(index1, 1);
        this.splice((index2 < index1 ? index2 + 1 : index2), 0, item1);
    },

    indexOf: function(item)
    {
        for (var i = 0; i < this.length; i++)
        {
            if (this[i] == item)
                return i;
        }
        
        return -1;
    },
    
    contains: function(item)
    {
        return this.indexOf(item) >= 0;
    },

    findByProp: function(prop, value)
    {
        for (var i = 0; i < this.length; i++)
        {
            if (this[i] && (this[i][prop] == value))
                return this[i];
        }
        
        return null;
    },
    
    indexByProp: function(prop, value)
    {
        for (var i = 0; i < this.length; i++)
        {
            if (this[i] && (this[i][prop] == value))
                return i;
        }
        
        return -1;
    },

    each: function(fn)
    {
        var result = null;
        
        for (var i = 0; i < this.length; i++)
        {
            if (result = fn(this[i]))
                break;
        }
        
        return result;    
    },
    
    reach: function(fn)
    {
        var result = null;
        
        for (var i = this.length - 1; i >= 0; i--)
        {
            if (result = fn(this[i]))
                break;
        }
        
        return result;    
    },

    copy: function(enumerable)
    {
        this.length = 0;
        
        if (enumerable)
        {
            for (var i = 0; i < enumerable.length; i++)
            {
                this.push(enumerable[i]);
            }
        }    
    },
    
    getEnumerator: function()
    {
        var _this = this;
        
        return {
            _container: _this,
            _index: -1,
             
            next: function()
            {
                this._index++;
                
                return (this._index > -1) && (this._index < this._container.length);
            },
            
            current: function()
            {
                return this._container[this._index];
            },
            
            reset: function()
            {
                this._index = -1;
            }
        };
    }
});

Object.extend(String.prototype,
{
    trim: function()
    {
        return this.replace(/(^\s+)|(\s+$)/g, "");
    }
});

var sjcl = 
{
    version:
    {
        major: 1,
        minor: 0,
        revision: 0,
        toString: function()
        {
            return [this.major, this.minor, this.revision].join(".");
        }
    },
    
    StringBuilder: function(glue)
    {
		if (typeof glue == "undefined")
			glue = "";
			
		this._buffer = [];
		this.glue = glue;
    },
    
    _nextId: 0,
    uid: function(prefix)
    {
        prefix = prefix ? prefix : "";
        
        return prefix + ++this._nextId;
    },

    time: function()
    {
	    return (new Date()).valueOf();
    },

	escape: function(str)
	{
		if (str == null)
			return "";
			
		var buffer = "";
		
		for (var i = 0; i < str.length; i++)
		{
			var unicode = str.charCodeAt(i);
			var delta = 0;
			
			if (unicode == 1548)
				delta = 1387;
			else if (unicode == 1567)
				delta = 1376;
			else if (unicode >= 1569 && unicode <= 1590)
				delta = 1376;
			else if (unicode >= 1591 && unicode <= 1594)
				delta = 1375;
			else if (unicode >= 1601 && unicode <= 1603)
				delta = 1380;
			else if (unicode == 1604)
				delta = 1379;
			else if (unicode >= 1605 && unicode <= 1608)	
				delta = 1378;
			else if (unicode >= 1609 && unicode <= 1610)	
				delta = 1373;
			else if (unicode >= 1611 && unicode <= 1614)
				delta = 1371;
			else if (unicode >= 1615 && unicode <= 1616)
				delta = 1370;
			else if (unicode >= 1617)
				delta = 1369;
							
			var ascii = unicode - delta;
			var tmp = ascii.toString(16);
			
			if (tmp.length == 1)
				tmp = "0" + tmp;
				
			buffer += "%" + tmp;
		}
		
		return buffer;
	},

    encodePostData: function(str)
    {
		return str.replace("&", "~amp;").replace("=", "~equal;");
    },
    
    getTagText: function(tag)
    {
		var reg = /<[^>]+>([^<]*)<\/\w+>/g;
		var result;
		
		return (result = reg.exec(tag)) ? result[1] : "";
    },

    setTagText: function(tag, text)
    {
		var reg = /(<[^>]+>)[^<]*(<\/\w+>)/g;
		
		return tag.replace(reg, "$1" + text + "$2");
    },
    
    rand: function(min, max)
    {
		var number = Math.round(Math.random() * 10000);
		var range = max - min + 1;
		
		return min + (number % range);
    }
};

sjcl.StringBuilder.extend(
{
	write: function(str)
	{
		this._buffer.push(str);
	},
	
	writeLn: function(str)
	{
		this._buffer.push(str + "\n");
	},
	
	clear: function()
	{
		this._buffer.clear();
	}
}
);

sjcl.StringBuilder.prototype.toString = function()
{
	return this._buffer.join(this.glue);
};

sjcl.browser = new function()
{
    this.version = parseInt(navigator.appVersion);
    this.agent = navigator.userAgent.toLowerCase();
    this.isNetscape = navigator.appName.indexOf("Netscape") != -1;
    this.isIE = navigator.appName.indexOf("Microsoft") != -1;
    this.isOpera = this.agent.indexOf("opera") != -1;
    this.isMSIE = this.isIE && !this.isOpera;
    this.isWindows = this.agent.indexOf("win") != -1;
    this.isMac = this.agent.indexOf("mac") != -1;
    this.isUnix = this.agent.indexOf("X11") != -1;
};

sjcl.debug = 
{
	_console: null,
	_indent: 0,
    
    _initConsole: function()
    {
	    if ((this._console == null) || (this._console.closed))
	    {
		    this._console = window.open("", "Console", "width=600,height=300,resizable=yes,scrollbars=yes");
		    this._console.document.open("text/plain");
	    }
    	
	    this._console.focus();
    },

    getIndent: function()
    {
	    var str = "";
    	
	    for (var i = 0; i < this._indent; i++)
		    str += "\t";
    		
	    return str;	
    },

    indent: function()
    {
	    this._indent++;
    },

    unIndent: function()
    {
	    if (this._indent > 0)
		    this._indent--;
    },

    write: function(msg)
    {
	    var doc;
	    
	    if (typeof msg == "undefined")
	        msg = "";

	    this._initConsole();
	    doc = this._console.document;
	    doc.write(msg);
	    doc.body.scrollTop = doc.body.scrollHeight - doc.body.clientHeight;
    },

    writeLine: function(msg)
    {
        var br = !sjcl.browser.isMSIE ? "<br />" : "";
		var doc;
		
	    if (typeof msg == "undefined")
	        msg = "";
	        
	    this._initConsole();
	    doc = this._console.document;
	    doc.writeln(this.getIndent() + msg + br);
	    doc.body.scrollTop = doc.body.scrollHeight - doc.body.clientHeight;
    },

    writeIf: function(exp, msg)
    {
        if (exp)
	        this.write(msg);
    },

    writeLineIf: function(exp, msg)
    {
	    if (exp)
	        this.writeLine(msg);
    },
    
    dump: function(obj, shallow)
    {
		shallow = shallow != undefined? shallow : true;
		
		for (var p in  obj)
		{
			switch (typeof obj[p])
			{
				case "function":
					alert(p + ": function(){...}");
					break;
					
				case "object":
					if (obj[p] == null)
						alert(p + " -> NULL");
					else if (obj == obj[p])
						alert(p + " -> [Recursive]");
					else
					{
						alert(p + " ->");
						
						if (!shallow)
						{
							this.indent();
							this.dump(obj[p]);
							this.unIndent();
						}
					}
					break;
				
				case "unknown":
					alert(p + ": [Unknown Type]");
					break;
										
				default:
					alert(p + ": " + obj[p]);
					break;
			}
		}
    }
};

sjcl.event = 
{
    add: function(e, evt, handler, capture)
    {
        capture = capture ? capture : false;
        
        if (e.addEventListener)
            e.addEventListener(evt, handler, capture);
        else
            e.attachEvent("on" + evt, handler);
    },
    
    remove: function(e, evt, handler, capture)
    {
        capture = capture ? capture : false;
        
        if (e.removeEventListener)
            e.removeEventListener(evt, handler, capture);
        else
            e.detachEvent("on" + evt, handler);
    },

    addMouseHoverEvents: function(e, overHandler, outHandler, capture)
    {
        if (e.addEventListener)
        {
            capture = capture ? capture : false;
            
            e.addEventListener("mouseover", overHandler, capture);
            e.addEventListener("mouseout", outHandler, capture);
        }
        else
        {
            e.attachEvent("onmouseenter", overHandler);
            e.attachEvent("onmouseleave", outHandler);
        }
    }
};

sjcl.Event = function(evt)
{
    this._event = evt ? evt : window.event;
    this.target = this._event.target ? this._event.target : this._event.srcElement;
    this.relatedTarget = this._event.relatedTarget ? this._event.relatedTarget : this._event.toElement;
    this.clientX = this._event.clientX;
    this.clientY = this._event.clientY;
    this.pageX = this.clientX + document.body.parentNode.scrollLeft;
    this.pageY = this.clientY + document.body.parentNode.scrollTop;
    this.keyCode = this._event.keyCode;
    this.button = this._event.button;
};

sjcl.Event.extend(
{
    cancelPropagation: function()
    {
        if (this._event.stopPropagation)
            this._event.stopPropagation();
        else
            this._event.cancelBubble = true;
    },
    
    cancelDefault: function()
    {
        if (this._event.preventDefault)
            this._event.preventDefault();
        else
            this._event.returnValue = false;
    },
    
    findByTagName: function(tag)
    {
        return sjcl.dom.getAncestorByTagName(this.target, tag);
    },

    findByAttribute: function(att)
    {
        return sjcl.dom.getAncestorByAttribute(this.target, att);
    },

    findByClassName: function(name)
    {
        return sjcl.dom.getAncestorByClassName(this.target, name);
    },
    
    rightButton: function()
    {
		return this.button == 2;
	}
}
);

if (!window.Node) 
{
    var Node = 
    {
        ELEMENT_NODE: 1,
        ATTRIBUTE_NODE: 2,
        TEXT_NODE: 3,
        COMMENT_NODE: 8,
        DOCUMENT_NODE: 9,
        DOCUMENT_FRAGMENT_NODE: 11
    }
} 

sjcl.dom =
{
    _CSStoJS: function(style)
    {
        var parts = style.split("-");
        var str = parts[0];
        
        for (var i = 1; i < parts.length; i++)
            str += parts[i].substring(0, 1).toUpperCase() + parts[i].substring(1);
            
        return str;    
    },
    
    getStyle: function(e, p)
    {
        if (e.currentStyle) 
        {
            return e.currentStyle[this._CSStoJS(p)];
        } 
        else if (window.getComputedStyle) 
        {
            return window.getComputedStyle(e, "").getPropertyValue(p);
        }
        
        return "";
    },
    
    _isWSNode: function(node)
    {
        return !(/[^\t\n\r ]/.test(node.data));
    },
    
    _isIgnorable: function(node)
    {
        return (node.nodeType == Node.COMMENT_NODE) || ((node.nodeType == Node.TEXT_NODE) && this._isWSNode(node)); 
    },
    
    previousSibling: function(node)
    {
        while ((node = node.previousSibling)) 
        {
            if (!this._isIgnorable(node)) 
                return node;
        }
        
        return null;
    },
    
    nextSibling: function(node)
    {
        while ((node = node.nextSibling)) 
        {
            if (!this._isIgnorable(node)) 
                return node;
        }
        
        return null;
    },

    firstChild: function(node)
    {
        var p = node.firstChild;
        
        while (p) 
        {
            if (!this._isIgnorable(p)) 
                return p;
                
            p = p.nextSibling;
        }
        
        return null;
    },
    
    lastChild: function(node)
    {
        var p = node.lastChild;
        
        while (p) 
        {
            if (!this._isIgnorable(p)) 
                return p;
            
            p = p.previousSibling;
        }
        
        return null;
    },
    
    nodeData: function(node)
    {
        var data = node.data;

        data = data.replace(/[\t\n\r ]+/g, " ");
        
        if (data.charAt(0) == " ")
            data = data.substring(1, data.length);
        
        if (data.charAt(data.length - 1) == " ")
            data = data.substring(0, data.length - 1);
            
        return data;
    },

    containsElement: function(src, target)
    {
        if (src.contains)
            return src.contains(target);
        else
        {
            if (src == target)
                return true;
                
            if (src.hasChildNodes())
            {
                for (var i = 0, n = src.childNodes.length; i < n; i++)
                {
                    if (this.containsElement(src.childNodes.item(i), target))
                        return true;
                }
             }    
        }
        
        return false;
    },
    
    getChildren: function(e)
    {
        var elements = [];
        var p = this.firstChild(e);
        
        while (p)
        {
            elements.push(p);
            p = this.nextSibling(p);
        }
        
        return elements;
    },
    
    getElementsByClassName: function(e, name)
    {
        var col = e.getElementsByTagName("*");
        var elements = [];
        
        for (var i = 0; i < col.length; i++)
        {
            var item = col.item(i);
            
            if (item.className == name)
                elements.push(item);
        }
        
        return elements;
    },
    
    getAncestorByTagName: function(e, tag)
    {
        for (var p = e; p ; p = p.parentNode)
        {
            if (p.nodeName == tag)
                return p;
        }
        
        return null;
    },

    getAncestorByAttribute: function(e, att)
    {
        for (var p = e; p ; p = p.parentNode)
        {
            if (p.getAttribute && p.getAttribute(att))
                return p;
        }
        
        return null;
    },

    getAncestorByClassName: function(e, name)
    {
        for (var p = e; p ; p = p.parentNode)
        {
            if (p.className && (p.className.indexOf(name) != -1))
                return p;
        }
        
        return null;
    },
    
    getChildByTagName: function(e, tag)
    {
        var col = e.getElementsByTagName(tag);
        
        if (col.length > 0)
            return col.item(0);
        
        return null;
    },

    getChildByAttribute: function(e, att)
    {
        var col = e.getElementsByTagName("*");
        
        for (var i = 0, n = col.length; i < n; i++)
        {
            var item = col.item(i);
            
            if (item.getAttribute(att))
                return item;
        }
        
        return null;
    },

    getChildByAttributeValue: function(e, att, value)
    {
        var col = e.getElementsByTagName("*");
        
        for (var i = 0, n = col.length; i < n; i++)
        {
            var item = col.item(i);
            
            if (item.getAttribute(att) == value)
                return item;
        }
        
        return null;
    },

    getChildByClassName: function(e, name)
    {
        var col = e.getElementsByTagName("*");
        
        for (var i = 0, n = col.length; i < n; i++)
        {
            var item = col.item(i);
            
            if (item.className == name)
                return item;
        }
        
        return null;
    },

    getFirstChildByTagName: function(e, tag)
    {
        for (p = e; p; p = p.firstChild)
        {
            if (p.nodeName == tag)
                return p;
        }
            
        return null;
    },

    innerText: function(e)
    {
		if (e.nodeType == Node.TEXT_NODE)
			return e.data;
			
		var text = "";
		
		for (var p = e.firstChild; p; p = p.nextSibling)
			text += arguments.callee(p);
			
		return text;	
    },
    
    elementPoint: function(e)
    {
	    var left = 0;
	    var top = 0;

	    while (e)
	    {
		    left += e.offsetLeft;
		    top += e.offsetTop - e.scrollTop;
    		
		    e = e.offsetParent;
	    }
	    
	    return {left: left, top: top};
    },
    
    elementRect: function(e)
    {
	    var left = 0;
	    var top = 0;
	    var width = e.offsetWidth;
	    var height = e.offsetHeight;
        var delta;
        
	    while (e)
	    {
		    left += e.offsetLeft;
		    top += e.offsetTop - e.scrollTop;
		    
		    e = e.offsetParent;
	    }
	    
	    return {
            left: left,
            top: top,
            width: width,
            height: height,
            right: left + width,
            bottom: top + height,
            
            contains: function(x, y)
            {
                return (x >= left) && (x <= left + width) && (y >= top) && (y <= top + height);
            },
            
            hContains: function(x, y)
            {
                return (x >= left) && (x <= left + width);
            },
            
            vContains: function(x, y)
            {
                return (y >= top) && (y <= top + height);
            }
        }
    },
    
    makeSameSize: function(e1, e2)
    {
        var rc = sjcl.dom.elementRect(e1);
        
        e2.style.width = rc.width + "px";
        e2.style.height = rc.height + "px";
    },
    
    makeSamePlacement: function(e1, e2)
    {
        var rc = sjcl.dom.elementRect(e1);
        
        e2.style.left = rc.left + "px";
        e2.style.top = rc.top + "px";
        e2.style.width = rc.width + "px";
        e2.style.height = rc.height + "px";
    },

    inflate: function(e, v)
    {
		e.style.left = parseInt(e.style.left) + v;
		e.style.top = parseInt(e.style.top) + v;
		e.style.width = parseInt(e.style.width) - v * 2;
		e.style.height = parseInt(e.style.height) - v * 2;
    },
    
    trackLink: function(a, evt)
    {
        if (a.href.indexOf("javascript") != -1)
        {
            eval(a.href);
        }
        else
        {
            if (evt.shiftkey)
                window.open(a.href);
            else
                window.location = a.href;    
        }        
    },

    getXmlDocument: function()
    {
        var xmlDoc = null;
        
        if (document.implementation && document.implementation.createDocument)
        {
            xmlDoc = document.implementation.createDocument("", "", null);
        }
        else if (window.ActiveXObject)
        {
            try
            {
                xmlDoc = new ActiveXObject("Msxml2.DOMDocument");
            } 
            catch(e)
            {
                xmlDoc = new ActiveXObject("Msxml.DOMDocument");
            }
        }
        
        return xmlDoc;
    },
    
    inputWidth: function(e, width)
    {
        if ((e.nodeName == "TEXTAREA") || (e.nodeName == "INPUT" && e.type == "text"))
        {
            if (sjcl.browser.isMSIE)
                width -= 6;
            else
                width -= 4;
        }
		
        width -= 2;
        
        return width;
    },
    
    inputHeight: function(e, height)
    {
        if (e.nodeName == "TEXTAREA")
        {
			height -= 5;
        }
		
        return height;
    },

    getFilter: function(e, name)
    {
		if (e.filters && e.filters.length > 0)
		{
			if (typeof name == "number")
				return e.filters.item(name);
			else
				return e.filters["DXImageTransform.Microsoft." + name];
				
		}
		else
			return null;
    }
};

sjcl.net = 
{
    READY_STATE_UNINITIALIZED: 0,
    READY_STATE_LOADING: 1,
    READY_STATE_LOADED: 2,
    READY_STATE_INTERACTIVE: 3,
    READY_STATE_COMPLETE: 4,
    
    WebRequest: function(url, onload, onerror, method, params, contentType)
    {
        this._request = this._createRequest();
        this._onload = onload;
        
        if (onerror)
            this._onerror = onerror;
            
        this._load(url, method, params, contentType);
    },
    
    WebRequestCollection: function()
    {
        this._length = 0;
    },

    load: function(url, onload, onerror)
    {
        new sjcl.net.WebRequest
        (
            url, 
            function()
            {
                onload.call(this, this.getText());
            }, 
            onerror
        );
    },

    loadJson: function(url, onload, onerror)
    {
        new sjcl.net.WebRequest
        (
            url, 
            function()
            {
                onload.call(this, this.getJson());
            }, 
            onerror
        );
    }
};

sjcl.net.WebRequest.extend(
{
    getText: function()
    {
		if (this._request.readyState == sjcl.net.READY_STATE_COMPLETE)
			return this._request.responseText;
		else
			return null;
    },

    getXml: function()
    {
        if (this._request.readyState == sjcl.net.READY_STATE_COMPLETE)
			return this._request.responseXML;
		else
			return null;
    },
    
    getJson: function()
    {
		if (this._request.readyState == sjcl.net.READY_STATE_COMPLETE)
			return eval("(" + this.getText() + ")");
		else
			return null;
    },

    cancel: function()
    {
        this.canceled = true;
        this._request.abort();
    },
    
    _createRequest: function()
    {
        var request = null;
        
        if (window.ActiveXObject) 
            request = new ActiveXObject("Microsoft.XMLHTTP");
        else if (window.XMLHttpRequest) 
            request = new XMLHttpRequest();

        return request;
    },
    
    _load: function(url, method, params, contentType)
    {
        if (!method)
            method = "GET";
            
        if (method == "POST" && !contentType)
            contentType='application/x-www-form-urlencoded';    

        if (this._request)
        {
            try
            {
                this._request.open(method, url);
                this._request.onreadystatechange = this._onready.bind(this);
                
                if (contentType)
                    this._request.setRequestHeader('Content-Type', contentType);
                
                this._request.send(params);
            }
            catch (e)
            {
                this._onerror.call(this);
            }
        }    
    },
    
    _onready: function()
    {
        if (this._request.readyState == sjcl.net.READY_STATE_COMPLETE)
        {
            if (this._request.status == 0 || this._request.status == 200)
                this._onload.call(this);
            else
                this._onerror.call(this);
        }
    },
    
    _onerror: function()
    {
        alert("ERROR!\n\nReadyState:" + 
                this._request.readyState + "\nHttp Status: " +
                this._request.status + "\n\nHeaders:\n" +
                this._request.getAllResponseHeaders());
    }
});

sjcl.net.WebRequestCollection.extend(
{
    add: function(id, webRequest)
    {
        if (typeof this[id] == "undefined")
        {
			this[id] = webRequest;
			this._length++;
		}
    },
    
    item: function(id)
    {
        return this[id];
    },
    
    remove: function(id)
    {
        this[id] = null;
        delete this[id];
        this._length--;
    },
    
    empty: function()
    {
        return this._length == 0;
    }
});

sjcl.widget = 
{
	Alignment:
	{
		BottomLeft: 0,
		BottomCenter: 1,
		BottomRight: 2,
		MiddleLeft: 3,
		MiddleCenter: 4,
		MiddleRight: 5,
		TopLeft: 6,
		TopCenter: 7,
		TopRight: 8
	},

    Orientation: 
    {
        horizontal: 0,
        vertical: 1
    },

    DataType:
    {
        String: 0,
        Integer: 1,
        Float: 2,
        Boolean: 3,
        Date: 4,
        DateTime: 5,
        Image: 6,
        BoolImage: 7,
        Link: 8
    },

    MenuItemType: 
    {
        String: 0,
        Check: 1,
        Separator: 2
    },

    RunningMode:
    {
        Client: 0,
        Server: 1,
        Callback: 2
    }
};    

var g_ContextMenu = null;

Object.extend(sjcl.widget,
{
    MenuClickEventArgs: function(menuId, itemId)
    {
        this.menuId = menuId;
        this.itemId = itemId;
        this.cancel = false;
    },
    
    MenuItem: function()
    {
        this.type = sjcl.widget.MenuItemType.String;
        this.caption = "";
        this.url = "";
        this.image = "";
        this.menu = "";
        this.checked = false;
        this.enabled = true;
        this.visible = true;
        
        if (!this.id)
            this.id = sjcl.uid("MI_");
    },
    
    Menu: function(id, hideOnClick)
    {
        this.id = id;
        this.hideOnClick = (typeof hideOnClick != "undefined") ? hideOnClick : true;
        this._items = [];
    },
    
    MenuBar: function()
    {
        this.orientation = sjcl.widget.Orientation.horizontal;
        this.direction = "ltr";
        this.barCssClass = "";
        this.barActiveCssClass = "";
        this.topItemCssClass = "";
        this.topItemHoverCssClass = "";
        this.topItemActiveCssClass = "";
        this.expandOnClick = false;
        this.alignToBar = false;
        this.showBorderEraser = true;
        this.specialEffects = true;
        this.target = null;
        this.expandDelay = 150;
        this._killTimerId = null;
        this._showTimerId = null;
        this._scrollTimerId = null;
        this._menus = [];
    }
}
);

sjcl.widget.MenuItem.extend(
{
    setCheck: function(state)
    {
        var e = $(this.id);

        if (e)
        {
            var td = sjcl.dom.getChildByClassName(e, "MenuItemMargin");
            var img = sjcl.dom.firstChild(td);

            img.style.visibility = state ? "visible" : "hidden";
        }
        
        this.checked = state;
    },
    
    setEnabled: function(state)
    {
        var e = $(this.id);
        
        if (e)
        {
            e.className = state ? "MenuItemRect" : "MenuItemRectDisabled";
        }
        
        this.enabled = state;
    },

    setVisible: function(state)
    {
        var e = $(this.id);
        
        if (e)
        {
            e.parentNode.style.display = state ? "" : "none";
        }
        
        this.visible = state;
    }
});

sjcl.widget.Menu.extend(
{
    append: function(info)
    {
        var item = new sjcl.widget.MenuItem();
        
        Object.extend(item, info);
        this._items.push(item);
    },
    
    remove: function(index)
    {
		var mi = this.item(index);
		
		this._items.remove(mi);
    },
    
    item: function(index)
    {
		if (typeof index == "string")
		{
			for (var i = 0; i < this._items.length; i++)
			{
				var item = this._items[i];
	            
				if (item.id == index)
					return item;
			}
	        
			return null;
		}
		else
			return this._items[index];
    },
    
    setItemCheck: function(id, state)
    {
        var item = this.item(id);
        
        if (item)
            item.setCheck(state);
    },
    
    setItemVisible: function(id, state)
    {
        var item = this.item(id);
        
        if (item)
            item.setVisible(state);
    },

    setItemEnabled: function(id, state)
    {
        var item = this.item(id);
        
        if (item)
            item.setEnabled(state);
    },

    getEnumerator: function()
    {
        return this._items.getEnumerator();
    },
    
    each: function(fn)
    {
        this._items.each(fn);
    },
    
    clear: function()
    {
		this._items.clear();
    },
    
    length: function()
    {
		return this._items.length;
    }
});

sjcl.widget.MenuBar.extend(
{
    attach: function(info)
    {
        Object.extend(this, info);
        
        if(this.target)
            this._attachMenu(this.target);
    },

    append: function(menu)
    {
        this._menus[menu.id] = menu;
    },
    
    getMenu: function(id)
    {
        return this._menus[id];
    },
    
    getMenuItem: function(id)
    {
		for (p in this._menus)
		{
			if (this._menus.hasOwnProperty(p))
			{
				var menu = this._menus[p];
				var item = menu.item(id);
				
				if (item != null)
					return item;
			}
		}
		
		return null;
    },
    
    showContextMenu: function()
    {
		if (g_ContextMenu)
			g_ContextMenu.hideContextMenu();
			
		var menu = arguments[0];
		var x, y, owner;
		
		if (arguments.length == 4)
		{
			var e = arguments[1];
			var rc = sjcl.dom.elementRect(e);
			
			owner = arguments[2];
			dir = arguments[3];
			
			if (this.direction == "ltr")
				x = dir == "ltr" ? rc.left : rc.right + 4;
			else
				x = dir == "ltr" ? rc.left + rc.width : rc.left;
			y = rc.bottom + 1;
		}
		else if (arguments.length == 5)
		{
			x = arguments[1];
			y = arguments[2];
			owner = arguments[3];
			dir = arguments[4];
		}
		else
			return;
			
		this._docClickBinder = this._docClick.bindAsEvent(this);
		sjcl.event.add(document, "mousedown", this._docClickBinder);
		this.contextMenu = menu;
		this.owner = owner;
		g_ContextMenu = this;
		
		this._openMenu(menu, null, x, y, true, dir);
    },
    
    hideContextMenu: function()
    {
		if (this.contextMenu)
		{
			this._killMenu(this.contextMenu, true);
			this.contextMenu = null;
			this.owner = null;
			g_ContextMenu = null;
		}
    },
    
    hideMenus: function()
    {
		this._menuKiller(false, true);
    },
    
    _attachMenu: function(e)
    {
        e.setAttribute("MenuContainer", true);
        sjcl.event.addMouseHoverEvents(e, this._onMenuOver.bindAsEvent(this), this._onMenuOut.bindAsEvent(this));
        
        var isMainBar = (e == this.target);
        var tag = isMainBar ? "*" : "TD";
        var itemClass = isMainBar ? this.topItemCssClass : "MenuItemRect";
        var col = e.getElementsByTagName(tag);
    	
        for (var i = 0, n = col.length; i < n; i++)
        {
	        var item = col.item(i);
    		
	        if (item.className.indexOf(itemClass) != -1)
	        {
                item.setAttribute("MenuItem", true);
                sjcl.event.addMouseHoverEvents(item, this._onItemOver.bindAsEvent(this), this._onItemOut.bindAsEvent(this));
				sjcl.event.add(item, "click", this._onItemClick.bindAsEvent(this));
	        }
        }
    },
    
    _onMenuOver: function(evt)
    {
        if (this._killTimerId)
        {
	        window.clearTimeout(this._killTimerId);
	        this._killTimerId = null;
        }
    },

    _onMenuOut: function(evt)
    {
        this._killTimerId = window.setTimeout(this._menuKiller.bind(this, false), this.expandDelay);
    },
    
    _onItemOver: function(evt)
    {
        var event = new sjcl.Event(evt);
        var item = event.findByAttribute("MenuItem");

        this._doItemOver(item);
    },
    
    _onItemOut: function(evt)
    {
        var event = new sjcl.Event(evt);
        var item = event.findByAttribute("MenuItem");
        var menu = item.getAttribute("menu");
        var oMenuItem = this.getMenuItem(item.id);
        
        if (menu && !this.getMenu(menu))
			return;

        if (oMenuItem && !oMenuItem.enabled)
			return;

        var container = event.findByAttribute("MenuContainer");
        var isTopItem = (container == this.target);
        
        if (!menu || menu != container.getAttribute("CurrentMenu"))
        {
            if (isTopItem)
                item.className = this.topItemCssClass;
            else
                item.className = "MenuItemRect";
        }
        	    
        if (this._showTimerId)
        {
	        window.clearTimeout(this._showTimerId);
	        this._showTimerId = null;
        }
    },
    
    _onItemClick: function(evt)
    {
        var event = new sjcl.Event(evt);
        var item = event.findByAttribute("MenuItem");
        var oMenuItem = this.getMenuItem(item.id);

        if (oMenuItem && !oMenuItem.enabled)
			return;

        var container = event.findByAttribute("MenuContainer");
        var isTopItem = (container == this.target);
        var menu = this.getMenu(container.id);
        var url = item.getAttribute("Url");
        var args = new sjcl.widget.MenuClickEventArgs(container.id, item.id);
        var subMenu = item.getAttribute("menu");
        
        if (this.expandOnClick)
        {
			this._expanded = true;
			this._doItemOver(item, 0);
		}
			
        if (this.onItemClick)
            this.onItemClick(args);

        if ((menu && menu.hideOnClick && !subMenu) || (subMenu && url))
            this._menuKiller(true, true);

        if (url && !args.cancel)
        {
            if (url.indexOf("javascript") != -1)
            {
                eval(url.substring(11));
            }    
            else
            {
                if (evt.shiftkey)
                    window.open(url);
                else
                    window.location = url;    
            }        
        }
        
        event.cancelPropagation();
    },
    
    _doItemOver: function(item, delay)
    {
        var menu = item.getAttribute("menu");
        var oMenuItem = this.getMenuItem(item.id);

        if (menu && !this.getMenu(menu))
			return;
			
        if (oMenuItem && !oMenuItem.enabled)
			return;
        
        var container = sjcl.dom.getAncestorByAttribute(item, "MenuContainer");
        var isTopItem = (container == this.target);
        
        if (isTopItem)
        {
			if ((menu != container.getAttribute("CurrentMenu")) && this.topItemHoverCssClass)
				item.className = this.topItemHoverCssClass;
		}
        else
        {
			item.className = "MenuItemRectHover";
		}
        
        if (this.expandOnClick && !this._expanded)
			return;
			
        var pt, x, y;

        if (!isTopItem)
        {
	        pt = sjcl.dom.elementPoint(item);
	        
	        if (this.direction == "ltr")
				x = pt.left + item.offsetWidth - 1;
	        else
				x = pt.left + 8;
	        
	        y = pt.top - 1;
        }
        else
        {
	        if (this.orientation == sjcl.widget.Orientation.horizontal)
	        {
	            if (this.alignToBar)
	            {
	                pt = sjcl.dom.elementPoint(container);
	                x = pt.left;
	                y = pt.top + container.offsetHeight - 1; 
	            }
	            else
	            {
	                pt = sjcl.dom.elementPoint(item);
	                x = pt.left;
	                y = pt.top + item.offsetHeight - 1; 
	            }

                if (this.offsetLeft)
					x += this.offsetLeft;
	        }
	        else
	        {
                pt = sjcl.dom.elementPoint(item);
                x = pt.left + item.offsetWidth - 1;
                y = pt.top - 2; 
	        }        
        }
        
    	var contextMenu = isTopItem ? false : this.contextMenu;
    	
        if (this._showTimerId)
	        window.clearTimeout(this._showTimerId);

        if (typeof delay == "undefined")
			delay = this.expandDelay;
			
        this._showTimerId = window.setTimeout(this._openMenu.bind(this, menu, container.id, x, y, contextMenu), delay);
    },
    
    _isTopItem: function(item)
    {
		return sjcl.dom.getAncestorByAttribute("MenuContainer") == this.target;
    },
    
    _docClick: function(evt)
    {
		var event = new sjcl.Event(evt);
		var menu = sjcl.dom.getAncestorByClassName(event.target, "SubMenu");
		
		if (!menu)
		{
			this.hideContextMenu();
			
			sjcl.event.remove(document, "mousedown", this._docClickBinder);
			this._docClickBinder = null;
		}
    },
    
    _createScroller: function(dir)
    {
        var scroller = document.createElement("DIV");
        var up = (dir == "up");

        if (up)
            scroller.setAttribute("UpScroller", true);
            
        scroller.className = up ? "MenuUpScroller" : "MenuDownScroller";
        sjcl.event.addMouseHoverEvents(scroller, this._startScroll.bindAsEvent(this), this._stopScroll.bindAsEvent(this));

        return scroller;
    },

    _createSubMenu: function(id)
    {
        var menu = this.getMenu(id);
        
        if (!menu)
			return null;
			
        var subMenu = document.createElement("DIV");
    	
        subMenu.id = id;
        subMenu.className = "SubMenu";
        subMenu.style.display = "none";
    	subMenu.style.zIndex = 1000;
    	    
        subMenu.appendChild(this._createScroller("up"));

        var itemsTable = document.createElement("TABLE");
        var itemsBody = document.createElement("TBODY");
    	
        itemsTable.className = "SubMenuArea";
        itemsTable.style.top = "0";
        itemsTable.cellSpacing = "1px";
        itemsTable.cellPadding = "0";
    	
        var itr = menu.getEnumerator();
        
        while(itr.next())
        {
	        var item = itr.current();
            var itemTr = document.createElement("TR");
            var itemTd = document.createElement("TD");

            itemTr.style.display = item.visible ? "" : "none";
            
            if (item.id)
                itemTd.id = item.id;
                
            var tr = document.createElement("TR");
            var td = document.createElement("TD");
            var img;
            
            td.className = "MenuItemMargin";
            switch (item.type)
            {
                case sjcl.widget.MenuItemType.String:
                    img = td.appendChild(document.createElement("IMG"));
                    img.src = (item.image) ? item.image : this.defaultImageUrl;
                    break;
                    
                case sjcl.widget.MenuItemType.Check:
                    img = td.appendChild(document.createElement("IMG"));
                    img.src = this.checkImageUrl;
                    img.style.visibility = item.checked ? "visible" : "hidden";
                    break;
            };
            
            tr.appendChild(td);
            
            td = document.createElement("TD");
            td.className = "MenuItemLabel";
            
            var caption = (item.type == sjcl.widget.MenuItemType.Separator) ? "-" : item.caption;
            var span = td.appendChild(document.createElement("SPAN"));
                
            span.appendChild(document.createTextNode(caption));
            
            if (item.menu)
            {
                var img = td.appendChild(document.createElement("IMG"));
                
                img.src = this.arrowImageUrl;
                img.style.width = "4px";
                img.style.height = "7px";
                img.className = "MenuItemArrow";
            }
                        
            tr.appendChild(td);
            
            var itemBody = document.createElement("TBODY");

            itemBody.appendChild(tr);
            
            var itemTable = document.createElement("TABLE");
            
            itemTable.appendChild(itemBody);
            itemTable.cellSpacing = "0";
            itemTable.cellPadding = "0";
            
            if (item.type != sjcl.widget.MenuItemType.Separator)
				itemTd.className =  item.enabled ? "MenuItemRect" : "MenuItemRectDisabled";
			else
				itemTd.className =  "MenuItemSeparator";
            
            if (item.url)
                itemTd.setAttribute("Url", item.url);
            
            if (item.menu)
                itemTd.setAttribute("menu", item.menu);
            
            itemTd.appendChild(itemTable);
            itemTr.appendChild(itemTd);
            itemsBody.appendChild(itemTr);
        }
    	
        itemsTable.appendChild(itemsBody);
        subMenu.appendChild(itemsTable);
        
        subMenu.appendChild(this._createScroller("down"));
        
        document.body.appendChild(subMenu);
        
        var div = document.body.appendChild(document.createElement("DIV"));
    	
        div.id = "mbe_" + id;
        div.className = "MenuBorderErase";

        return subMenu;
    },

    _adjustPositions: function(div)
    {
        var up = div.childNodes.item(0);
        var box = div.childNodes.item(1);
        var down = div.childNodes.item(2);
        var width = parseInt(box.offsetWidth) + 32;
        
        box.style.width = width + "px";
        up.style.width = down.style.width = div.clientWidth + "px";
        
        var tds = div.getElementsByTagName("TD");
        
        for (var i = 0, n = tds.length; i < n; i++)
        {
            var td = tds.item(i);
    	    
	        if (td.className.indexOf("MenuItemRect") != -1)
	        {
	            var imgs = td.getElementsByTagName("IMG");
    		    
	            for (var j = 0, m = imgs.length; j < m; j++)
	            {
	                var img = imgs.item(j);
    		        
	                if (img.className == "MenuItemArrow")
	                {
	                    if (this.direction == "ltr")
							img.style.left = (td.offsetWidth - img.offsetWidth - 4) + "px";
						else
							img.style.left = (td.offsetLeft + 4) + "px";
							
	                    img.style.top = (td.offsetTop + (td.offsetHeight - img.offsetHeight) / 2 + 1) + "px";
                    }
	            }    
	        }
        }
    },
    
    _getTopItem: function(div, menu)
    {
        var col = div.getElementsByTagName("*");
        
        for (var i = 0, n = col.length; i < n; i++)
        {
            var item = col.item(i);
            
            if (item.getAttribute("menu") == menu)
                return item;
        }
        
        return null;
    },
    
    _adjustBorderEraser: function(menu)
    {
	    var parent = $(menu.getAttribute("ParentMenu"));
    	
	    if (parent && (parent == this.target))
        {    
            var e = this.alignToBar ? parent : this._getTopItem(parent, parent.getAttribute("CurrentMenu"));
            var border = $("mbe_" + menu.id);
            
            border.style.left = (menu.offsetLeft + 1) + "px";
            border.style.top = menu.offsetTop + "px";
            border.style.width = (e.offsetWidth - 2) + "px";
            border.style.zIndex = menu.style.zIndex + 1;
            border.style.display = "";
        }    
    },
    
    _updatePopupMenu: function(div)
    {
        var menu = this.getMenu(div.id);
        var col = div.getElementsByTagName("TD");
        var index = 0;
        
        for (var i = 0; i < col.length; i++)
        {
            var td = col.item(i);
            
            if (td.className.indexOf("MenuItemRect") != -1)
            {
                
            }
        }
    },
    
    _showPopupMenu: function(div)
    {
	    var parent = $(div.getAttribute("ParentMenu"));
    	
	    if (this.specialEffects && div.filters && div.filters.length)
	    {
	        var fade = div.filters.item(1);
	        var verSlide = div.filters.item(2);
	        var horSlide = div.filters.item(3);
	        var isTopLevel = (parent == null) || (parent == this.target);
    	    
	        fade.apply();
	        if (isTopLevel)
	            verSlide.apply();
	        else
	            horSlide.apply();
    	        
	        div.style.display = "";
    	    
	        fade.play();
	        if (isTopLevel)
	            verSlide.play();
	        else
	            horSlide.play();
	    }
	    else
	        div.style.display = "";
    },
    
    _openMenu: function (id, parentId, x, y, contextMenu, dir)
    {
	    var parent = $(parentId);

		if (g_ContextMenu && g_ContextMenu != this)
			g_ContextMenu.hideContextMenu();
			
	    if (!contextMenu && this.contextMenu)
			this.hideContextMenu();
			
	    if (id && !this._initInvoked)
	    {
	        if (parent && this.topItemActiveCssClass)
	        {
				var e = sjcl.dom.getChildByAttributeValue(parent, "menu", id);
		        
				e.className = this.topItemActiveCssClass;
			}
	        
	        if (!contextMenu && this.barActiveCssClass)
				this.target.className = this.barActiveCssClass;
	        
	        if (this.onInit)
				this.onInit();
				
	        this._initInvoked = true;
	    }
	    
	    if (parent)
	    {
	        var current = parent.getAttribute("CurrentMenu");

	        if (id == current) 
	            return;
        	
	        this._killMenu(current);
        }
        
	    if (id && parentId)
	    {
		    parent.setAttribute("CurrentMenu", id);
        }
	    else if (parentId)
	    {
		    parent.removeAttribute("CurrentMenu");
		    return;
	    }
    	
	    var div = $(id);
	    var firstShow = (div == null);
    	
	    if (div == null)
	    {
		    var div = this._createSubMenu(id);

		    this._attachMenu(div);
	    }
    	
	    div.setAttribute("ParentMenu", parentId);
    	
    	if (this.onInitPopupMenu)
    	    this.onInitPopupMenu(id);
    	
    	this._updatePopupMenu(div);
	    this._showPopupMenu(div);
    	
	    if (firstShow)
	        this._adjustPositions(div);
        	
	    var html = sjcl.browser.isOpera ? document.body : document.body.parentNode;
	    var bodyHeight = html.clientHeight;
	    var bodyTop = html.scrollTop;
	    var bodyWidth = html.clientWidth;
	    var bodyLeft = html.scrollLeft;
	    var up = div.childNodes.item(0);
	    var box = div.childNodes.item(1);
	    var down = div.childNodes.item(2);

	    up.style.display = "none";
	    down.style.display = "none";
	    box.style.top = "0px";

	    if (box.offsetHeight > bodyHeight)
	    {
		    div.style.height = (bodyHeight - 8) + "px";

		    down.style.display = "";
		    down.style.left = "0px";
		    down.style.top = (div.clientHeight - down.clientHeight) + "px";
	    }
	    else
	        div.style.height = (box.offsetHeight) + "px";
    	    
	    var bodyBottom = bodyTop + bodyHeight;
        var normalPos = true;
        
	    if (y + div.offsetHeight > bodyBottom)
	    {
	        normalPos = false;

		    y = bodyBottom - div.offsetHeight;
		    if (y < bodyTop)
			    y = bodyTop + (bodyHeight - div.offsetHeight) / 2;
	    }
    	
	    if ((dir == "rtl") || (this.direction == "rtl"))
			x -= div.offsetWidth;
		
	    if (x + div.offsetWidth > bodyWidth + bodyLeft) 
	    {
	        if (parent)
				x = parent.offsetLeft - div.offsetWidth + 5;
			else
				x -= div.offsetWidth;
	    }    
		else if (x < 0)
		{
	        if (parent)
				x = parent.offsetLeft + parent.offsetWidth - 8;
			else
				x = 0;
		}

	    div.style.left = x + "px";
	    div.style.top = y + "px";
    	
        if (parent && this.showBorderEraser)
        {
            this._adjustBorderEraser(div);
            
            var eraser = $("mbe_" + id);
            
            eraser.style.display = normalPos ? "" : "none";
        }
        
	    this._hideElements("SELECT", div);
	    this._hideElements("OBJECT", div);
    },

    _menuKiller: function(killContextMenu, terminate)
    {
	    if (this.target)
	    {
			this._killMenu(this.target.getAttribute("CurrentMenu"), terminate);
			this.target.removeAttribute("CurrentMenu");
		}
		
		if (killContextMenu && this.contextMenu)
			this.hideContextMenu();
    },

    _killMenu: function(id, terminate)
    {
	    if (!id) 
	        return;

	    var menu = $(id);
	    var current = menu.getAttribute("CurrentMenu");
    	
	    if (current) 
	    {
		    this._killMenu(current);
		    menu.removeAttribute("CurrentMenu");
	    }
    	
	    var parent = $(menu.getAttribute("ParentMenu"));
    	
	    if (parent)
	    {
	        var isMainBar = (parent == this.target);
	        var tag = isMainBar ? "*" : "TD";
	        var itemClass = isMainBar ? this.topItemCssClass : "MenuItemRect";
	        var col = parent.getElementsByTagName(tag);
    	    
	        for (var i = 0, n = col.length; i < n; i++)
	        {
		        var item = col.item(i);
		        var m = item.getAttribute("menu");
        		
		        if (m == id)
		            item.className = itemClass;
	        }
        	
	        if (isMainBar)
	        {
	            var border = $("mbe_" + id);
            	
	            border.style.display = "none";
	        }
        }
        	
        if (terminate || (this._showTimerId == null))
        {
			if (this.barCssClass)
				this.target.className = this.barCssClass;
            
			if (this.onUninit)
				this.onUninit();
            
			this._initInvoked = false;    
			this._expanded = false;
		}
		
	    this._showElements("SELECT", menu);
	    this._showElements("OBJECT", menu);
    	
	    menu.style.display = "none";
    },
    
    _startScroll: function(evt)
    {
	    var event = new sjcl.Event(evt);
	    var div = event.target.parentNode;
	    var dy = event.target.getAttribute("UpScroller") ? +1 : -1;
        var box = div.childNodes.item(1);

	    div.setAttribute("startTime", sjcl.time());
	    div.setAttribute("startTop", parseInt(box.style.top));
    	
	    this._scrollTimerId = window.setInterval(this._scrollMenu.bind(this, div.id, dy), 35);
    },
    
    _stopScroll: function(evt)
    {
	    if (this._scrollTimerId)
		    window.clearInterval(this._scrollTimerId);
    		
	    this._scrollTimerId = null;
    },

    _scrollMenu: function(id, dy)
    {
	    var div = $(id);
	    var current = div.getAttribute("CurrentMenu");
    	
	    if (current)
	    {
		    this._killMenu(current);
		    div.removeAttribute("CurrentMenu");
	    }
    	
	    var up = div.childNodes.item(0);
	    var box = div.childNodes.item(1);
	    var down = div.childNodes.item(2);
	    var y = parseInt(div.getAttribute("startTop")) + Math.round((sjcl.time() - parseInt(div.getAttribute("startTime"))) * 0.150) * dy;
    	
	    if (div.clientHeight >= box.offsetHeight + y)
	    {
		    window.clearInterval(this._scrollTimerId);
		    this._scrollTimerId = null;
    		
		    box.style.top = (div.clientHeight - box.offsetHeight) + "px";
		    down.style.display = "none";
		    up.style.display = "";
	    }
	    else if (box.offsetTop > 0)
	    {
		    window.clearInterval(this._scrollTimerId);
		    this._scrollTimerId = null;
    		
		    box.style.top = 0;
		    up.style.display = "none";
		    down.style.display = "";
	    }
	    else
	    {
	        up.style.display = "";
	        down.style.display = "";
	        box.style.top = y + "px";
	    }
    },

    _hideElements: function(tagName, menu)
    {
	    this._setElementsVisibility(tagName, -1, menu);
    },

    _showElements: function(tagName, menu)
    {
	    this._setElementsVisibility(tagName, +1, menu);
    },
    
    _setElementsVisibility: function(tagName, change, menu)
    {
	    var col = document.getElementsByTagName(tagName);
	    var rect = sjcl.dom.elementRect(menu);

	    for (var i = 0, n = col.length; i < n; i++)
	    {
		    var e = col.item(i);
    		
		    if (this._menuOverlap(e, rect))
		    {
			    if (e.visLevel)
				    e.visLevel += change;
			    else
				    e.visLevel = change;
    				
			    if (e.visLevel == -1 && change == -1)
			    {
				    e.visibilitySave = e.style.visibility;
				    e.style.visibility = "hidden";
			    }
			    else if (e.visLevel == 0 && change == +1)
			    {
				    e.style.visibility = e.visibilitySave;
			    }
		    }
	    }
    },
    
    _menuOverlap: function(e, rect)
    {
	    var rc = sjcl.dom.elementRect(e);
    	
	    return (rc.left < rect.left + rect.width) && 
	           (rc.left + rc.width > rect.left) && 
	           (rc.top < rect.top + rect.height) && 
	           (rc.top + rc.height > rect.top);
    }
});

sjcl.effect = 
{
	Rect: function(left, top, width, height)
	{
		this.left = left;
		this.top = top;
		this.width = width;
		this.height = height;
		this.right = left + width;
		this.bottom = top + height;
	},
	
	RectAnimation: function(rc1, rc2, callback, steps, color, interval)
	{
		if (!steps)
			steps = 10;
			
		if (!color)
			color = "#6D7993";

		if (typeof interval != "number")
			interval = 10;

		this.rect1 = rc1;
		this.rect2 = rc2;
		this.callback = callback;
		this.steps = steps;
		this.color = color;
		this.interval = interval;
		this.active = false;
	},
    
    alignRect: function(rc1, rc2, align, margin)
    {
		if (typeof align == "undefined")
			align = sjcl.widget.Alignment.BottomLeft;
			
		if (typeof margin == "undefined")
			margin = 2;
			
		switch (align)
		{
			case sjcl.widget.Alignment.BottomLeft:
				rc1.left = rc2.left;
				rc1.top = rc2.top + rc2.height + margin;
				break;
				
			case sjcl.widget.Alignment.BottomCenter:
				rc1.left = rc2.left - (rc1.width - rc2.width) / 2;
				rc1.top = rc2.top + rc2.height + margin;
				break;

			case sjcl.widget.Alignment.BottomRight:
				rc1.left = rc2.left + rc2.width;
				rc1.top = rc2.top + rc2.height + margin;
				break;

			case sjcl.widget.Alignment.MiddleLeft:
				rc1.left = rc2.left;
				rc1.top = rc2.top - (rc1.height - rc2.height) / 2;
				break;
				
			case sjcl.widget.Alignment.MiddleCenter:
				rc1.left = rc2.left - (rc1.width - rc2.width) / 2;
				rc1.top = rc2.top - (rc1.height - rc2.height) / 2;
				break;

			case sjcl.widget.Alignment.MiddleRight:
				rc1.left = rc2.left + rc2.width + margin;
				rc1.top = rc2.top - (rc1.height - rc2.height) / 2;
				break;

			case sjcl.widget.Alignment.TopLeft:
				rc1.left = rc2.left;
				rc1.top = rc2.top - rc1.height - margin;
				break;
				
			case sjcl.widget.Alignment.TopCenter:
				rc1.left = rc2.left - (rc1.width - rc2.width) / 2;
				rc1.top = rc2.top - rc1.height - margin;
				break;

			case sjcl.widget.Alignment.TopRight:
				rc1.left = rc2.left + rc2.width;
				rc1.top = rc2.top - rc1.height - margin;
				break;
		}
    },
    
	getCursorPos: function(rc, x, y)
	{
		var delta = 4, grip = 12;
		var rc1, rc2;

		//left grip
		rc1 = new sjcl.effect.Rect(rc.left, rc.bottom - grip, delta, grip);
		rc2 = new sjcl.effect.Rect(rc.left, rc.bottom - delta, grip, delta);
		if (rc1.contains(x, y) || rc2.contains(x, y))
			return sjcl.widget.CursorPos.SizeBottomLeft;
		
		//right grip
		rc1 = new sjcl.effect.Rect(rc.right - delta, rc.bottom - grip, delta, grip);
		rc2 = new sjcl.effect.Rect(rc.right - grip, rc.bottom - delta, grip, delta);
		if (rc1.contains(x, y) || rc2.contains(x, y))
			return sjcl.widget.CursorPos.SizeBottomRight;

		//left border
		rc1 = new sjcl.effect.Rect(rc.left, rc.top, delta, rc.height - grip);
		if (rc1.contains(x, y))
			return sjcl.widget.CursorPos.SizeLeft;
		
		//right border
		rc1 = new sjcl.effect.Rect(rc.right - delta, rc.top, delta, rc.height - grip);
		if (rc1.contains(x, y))
			return sjcl.widget.CursorPos.SizeRight;

		//bottom border
		rc1 = new sjcl.effect.Rect(rc.left + grip, rc.bottom - delta, rc.width - grip * 2, delta);
		if (rc1.contains(x, y))
			return sjcl.widget.CursorPos.SizeBottom;
			
		return sjcl.widget.CursorPos.Default;
	},

    setCursor: function(e, pos)
    {
		switch (pos)
		{
			case sjcl.widget.CursorPos.SizeBottomLeft:	
				e.style.cursor = "ne-resize";
				break;

			case sjcl.widget.CursorPos.SizeBottomRight:	
				e.style.cursor = "nw-resize";
				break;

			case sjcl.widget.CursorPos.SizeLeft:
			case sjcl.widget.CursorPos.SizeRight:
				e.style.cursor = "w-resize";
				break;

			case sjcl.widget.CursorPos.SizeBottom:	
				e.style.cursor = "s-resize";
				break;

			default:	
				e.style.cursor = "default";
				break;
		}
    },
    
    drag: function(e, evt, onDragStart, onDragEnd)
    {
		var event = new sjcl.Event(evt);
		var x = parseInt(e.style.left);
		var y = parseInt(e.style.top);
		var deltaX = event.pageX - x;
		var deltaY = event.pageY - y;
		var dragged = false;
		
		sjcl.event.add(document, "mousemove", onMouseMove);
		sjcl.event.add(document, "mouseup", onMouseUp);
		
		event.cancelDefault();
		
		function onMouseMove(evt)
		{
			var event = new sjcl.Event(evt);
			
			if (!dragged)
			{
				if (onDragStart)
					onDragStart();
					
				dragged = true;
			}
			
			e.style.left = (event.pageX - deltaX) + "px";
			e.style.top = (event.pageY - deltaY) + "px";

			event.cancelPropagation();
			event.cancelDefault();
		}
		
		function onMouseUp(evt)
		{
			var event = new sjcl.Event(evt);
			
			if (dragged && onDragEnd)
				onDragEnd();
				
			sjcl.event.remove(document, "mousemove", onMouseMove);
			sjcl.event.remove(document, "mouseup", onMouseUp);
			
			event.cancelPropagation();
			event.cancelDefault();
		}
    },
    
    resize: function(e, evt, pos, onResizeStart, onResizeEnd, minWidth, minHeight)
    {
		var event = new sjcl.Event(evt);
		var rc = sjcl.dom.elementRect(e);
		var div = createResizeRect();
		var x = parseInt(div.style.left);
		var y = parseInt(div.style.top);
		var deltaX = rc.right - event.pageX;
		var deltaY = rc.bottom - event.pageY;
		var dragged = false;
		
		sjcl.effect.setCursor(document.body, pos);
		
		function createResizeRect()
		{
			var div = document.createElement("DIV");
			
			div.style.position = "absolute";
			div.style.border = "solid 2px #4C566D";
			div.style.zIndex = 2000;
			
			div.style.left = rc.left + "px";
			div.style.top = rc.top + "px";
			div.style.width = (rc.width - 4) + "px";
			div.style.height = (rc.height - 4) + "px";
			
			document.body.appendChild(div);
			
			return div;
		}

		sjcl.event.add(document, "mousemove", onMouseMove);
		sjcl.event.add(document, "mouseup", onMouseUp);
		
		event.cancelDefault();
		
		function onMouseMove(evt)
		{
			var event = new sjcl.Event(evt);
			var width, height;
			
			if (!dragged)
			{
				if (onResizeStart)
					onResizeStart();
					
				dragged = true;
			}
			
			switch (pos)
			{
				case sjcl.widget.CursorPos.SizeLeft:
					div.style.left = (event.pageX) + "px";
					if ((width = rc.right - event.pageX - 4) >= minWidth)
						div.style.width = width + "px";
					break;
				
				case sjcl.widget.CursorPos.SizeRight:
					if ((width = event.pageX - x - 4 + deltaX) >= minWidth)
						div.style.width = width + "px";
					break;
					
				case sjcl.widget.CursorPos.SizeBottom:
					if ((height = event.pageY - y - 4 + deltaY) >= minHeight)
						div.style.height = height + "px";
					break;
					
				case sjcl.widget.CursorPos.SizeBottomLeft:
					div.style.left = (event.pageX) + "px";
					if ((width = rc.right - event.pageX - 4) >= minWidth)
						div.style.width = width + "px";
					if ((height = event.pageY - y - 4 + deltaY) >= minHeight)
						div.style.height = height + "px";
					break;
					
				case sjcl.widget.CursorPos.SizeBottomRight:	
					if ((width = event.pageX - x - 4 + deltaX) >= minWidth)
						div.style.width = width + "px";
					if ((height = event.pageY - y - 4 + deltaY) >= minHeight)
						div.style.height = height + "px";
					break;
			}
			
			event.cancelPropagation();
			event.cancelDefault();
		}
		
		function onMouseUp(evt)
		{
			var event = new sjcl.Event(evt);
			var left = parseInt(div.style.left);
			var top = parseInt(div.style.top);
			var width = parseInt(div.style.width);
			var height = parseInt(div.style.height);
			
			e.style.left = left + "px";
			e.style.top = top + "px";
			e.style.width = width + "px";
			e.style.height = height + "px";
			
			div.parentNode.removeChild(div);
			document.body.style.cursor = "default";
			
			sjcl.event.remove(document, "mousemove", onMouseMove);
			sjcl.event.remove(document, "mouseup", onMouseUp);
			
			event.cancelPropagation();
			event.cancelDefault();

			if (dragged && onResizeEnd)
				onResizeEnd(left, top, width, height);
		}
    }
};

sjcl.effect.Rect.extend(
{
	contains: function(x, y)
	{
		return (x >= this.left) && (x <= this.right) && (y >= this.top) && (y <= this.bottom);
	}
});

sjcl.effect.RectAnimation.extend(
{
	play: function()
	{
		if (this.interval > 0)
		{
			var div = document.createElement("DIV");
			
			div.style.position = "absolute";
			div.style.border = "1px solid " + this.color;
			div.style.left = this.rect1.left + "px";
			div.style.top = this.rect1.top + "px";
			div.style.width = this.rect1.width + "px";
			div.style.height = this.rect1.height + "px";
			div.setAttribute("AnimationRect", true);
			
			document.body.appendChild(div);
			
			this._deltaLeft = (this.rect2.left - this.rect1.left) / this.steps;
			this._deltaTop = (this.rect2.top - this.rect1.top) / this.steps;
			this._deltaWidth = (this.rect2.width - this.rect1.width) / this.steps;
			this._deltaHeight = (this.rect2.height - this.rect1.height) / this.steps;
			this._element = div;
			this._step = 1;
			this._timerId = window.setInterval(this._animate.bind(this), this.interval);
			this.active = true;
		}
		else
		{
			if (this.callback)
				this.callback();
		}
		
		this.active = true;
	},
	
	cancel: function()
	{
		if (this._timerId)
		{
			window.clearInterval(this._timerId);
			this._timerId = null;
		}
		
		if (this._element)
		{
			document.body.removeChild(this._element);
			this._element = null;
		}
		
		this.active = false;
	},
	
	_animate: function()
	{
		if (this._step > this.steps)
		{
			this.cancel();
			
			if (this.callback)
				this.callback();
				
			return;	
		}
		
		var e = this._element;
		var left = parseInt(e.style.left) + this._deltaLeft;
		var top = parseInt(e.style.top) + this._deltaTop;
		var width = parseInt(e.style.width) + this._deltaWidth;
		var height = parseInt(e.style.height) + this._deltaHeight;
		
		if (this._step == this.steps)
		{
			left = this.rect2.left;
			top = this.rect2.top;
			width = this.rect2.width;
			height = this.rect2.height;
		}
		
		e.style.left = left + "px";
		e.style.top = top + "px";
		e.style.width = width + "px";
		e.style.height = height + "px";
		
		this._step++;
	}
});