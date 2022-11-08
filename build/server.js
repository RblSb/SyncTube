(function ($global) { "use strict";
var $estr = function() { return js_Boot.__string_rec(this,''); },$hxEnums = $hxEnums || {},$_;
function $extend(from, fields) {
	var proto = Object.create(from);
	for (var name in fields) proto[name] = fields[name];
	if( fields.toString !== Object.prototype.toString ) proto.toString = fields.toString;
	return proto;
}
var ClientGroup = $hxEnums["ClientGroup"] = { __ename__:true,__constructs__:null
	,Banned: {_hx_name:"Banned",_hx_index:0,__enum__:"ClientGroup",toString:$estr}
	,User: {_hx_name:"User",_hx_index:1,__enum__:"ClientGroup",toString:$estr}
	,Leader: {_hx_name:"Leader",_hx_index:2,__enum__:"ClientGroup",toString:$estr}
	,Admin: {_hx_name:"Admin",_hx_index:3,__enum__:"ClientGroup",toString:$estr}
};
ClientGroup.__constructs__ = [ClientGroup.Banned,ClientGroup.User,ClientGroup.Leader,ClientGroup.Admin];
var Client = function(ws,req,id,name,group) {
	this.isAlive = true;
	this.ws = ws;
	this.req = req;
	this.id = id;
	this.name = name;
	var i = group;
	if(group == null) {
		i = 0;
	}
	this.group = i;
};
Client.__name__ = true;
Client.prototype = {
	hasPermission: function(permission,permissions) {
		if((this.group & 1) != 0) {
			return permissions.banned.indexOf(permission) != -1;
		}
		if((this.group & 8) != 0) {
			return permissions.admin.indexOf(permission) != -1;
		}
		if((this.group & 4) != 0) {
			return permissions.leader.indexOf(permission) != -1;
		}
		if((this.group & 2) != 0) {
			return permissions.user.indexOf(permission) != -1;
		}
		return permissions.guest.indexOf(permission) != -1;
	}
	,setGroupFlag: function(type,flag) {
		if(flag) {
			this.group |= 1 << type._hx_index;
		} else {
			this.group &= -1 - (1 << type._hx_index);
		}
		return flag;
	}
	,getData: function() {
		return { name : this.name, group : this.group};
	}
	,__class__: Client
};
var ClientTools = function() { };
ClientTools.__name__ = true;
ClientTools.setLeader = function(clients,name) {
	var _g = 0;
	while(_g < clients.length) {
		var client = clients[_g];
		++_g;
		if(client.name == name) {
			client.setGroupFlag(ClientGroup.Leader,true);
		} else if((client.group & 4) != 0) {
			client.setGroupFlag(ClientGroup.Leader,false);
		}
	}
};
ClientTools.hasLeader = function(clients) {
	var _g = 0;
	while(_g < clients.length) if((clients[_g++].group & 4) != 0) {
		return true;
	}
	return false;
};
ClientTools.getByName = function(clients,name,def) {
	var _g = 0;
	while(_g < clients.length) {
		var client = clients[_g];
		++_g;
		if(client.name == name) {
			return client;
		}
	}
	return def;
};
var DateTools = function() { };
DateTools.__name__ = true;
DateTools.__format_get = function(d,e) {
	switch(e) {
	case "%":
		return "%";
	case "A":
		return DateTools.DAY_NAMES[d.getDay()];
	case "B":
		return DateTools.MONTH_NAMES[d.getMonth()];
	case "C":
		return StringTools.lpad(Std.string(d.getFullYear() / 100 | 0),"0",2);
	case "D":
		return DateTools.__format(d,"%m/%d/%y");
	case "F":
		return DateTools.__format(d,"%Y-%m-%d");
	case "I":case "l":
		var hour = d.getHours() % 12;
		return StringTools.lpad(Std.string(hour == 0 ? 12 : hour),e == "I" ? "0" : " ",2);
	case "M":
		return StringTools.lpad(Std.string(d.getMinutes()),"0",2);
	case "R":
		return DateTools.__format(d,"%H:%M");
	case "S":
		return StringTools.lpad(Std.string(d.getSeconds()),"0",2);
	case "T":
		return DateTools.__format(d,"%H:%M:%S");
	case "Y":
		return Std.string(d.getFullYear());
	case "a":
		return DateTools.DAY_SHORT_NAMES[d.getDay()];
	case "b":case "h":
		return DateTools.MONTH_SHORT_NAMES[d.getMonth()];
	case "d":
		return StringTools.lpad(Std.string(d.getDate()),"0",2);
	case "e":
		return Std.string(d.getDate());
	case "H":case "k":
		return StringTools.lpad(Std.string(d.getHours()),e == "H" ? "0" : " ",2);
	case "m":
		return StringTools.lpad(Std.string(d.getMonth() + 1),"0",2);
	case "n":
		return "\n";
	case "p":
		if(d.getHours() > 11) {
			return "PM";
		} else {
			return "AM";
		}
		break;
	case "r":
		return DateTools.__format(d,"%I:%M:%S %p");
	case "s":
		return Std.string(d.getTime() / 1000 | 0);
	case "t":
		return "\t";
	case "u":
		var t = d.getDay();
		if(t == 0) {
			return "7";
		} else if(t == null) {
			return "null";
		} else {
			return "" + t;
		}
		break;
	case "w":
		return Std.string(d.getDay());
	case "y":
		return StringTools.lpad(Std.string(d.getFullYear() % 100),"0",2);
	default:
		throw new haxe_exceptions_NotImplementedException("Date.format %" + e + "- not implemented yet.",null,{ fileName : "DateTools.hx", lineNumber : 101, className : "DateTools", methodName : "__format_get"});
	}
};
DateTools.__format = function(d,f) {
	var r_b = "";
	var p = 0;
	while(true) {
		var np = f.indexOf("%",p);
		if(np < 0) {
			break;
		}
		var len = np - p;
		r_b += len == null ? HxOverrides.substr(f,p,null) : HxOverrides.substr(f,p,len);
		r_b += Std.string(DateTools.__format_get(d,HxOverrides.substr(f,np + 1,1)));
		p = np + 2;
	}
	var len = f.length - p;
	r_b += len == null ? HxOverrides.substr(f,p,null) : HxOverrides.substr(f,p,len);
	return r_b;
};
DateTools.format = function(d,f) {
	return DateTools.__format(d,f);
};
var EReg = function(r,opt) {
	this.r = new RegExp(r,opt.split("u").join(""));
};
EReg.__name__ = true;
EReg.prototype = {
	match: function(s) {
		if(this.r.global) {
			this.r.lastIndex = 0;
		}
		this.r.m = this.r.exec(s);
		this.r.s = s;
		return this.r.m != null;
	}
	,matched: function(n) {
		if(this.r.m != null && n >= 0 && n < this.r.m.length) {
			return this.r.m[n];
		} else {
			throw haxe_Exception.thrown("EReg::matched");
		}
	}
	,matchedPos: function() {
		if(this.r.m == null) {
			throw haxe_Exception.thrown("No string matched");
		}
		return { pos : this.r.m.index, len : this.r.m[0].length};
	}
	,matchSub: function(s,pos,len) {
		if(len == null) {
			len = -1;
		}
		if(this.r.global) {
			this.r.lastIndex = pos;
			this.r.m = this.r.exec(len < 0 ? s : HxOverrides.substr(s,0,pos + len));
			var b = this.r.m != null;
			if(b) {
				this.r.s = s;
			}
			return b;
		} else {
			var b = this.match(len < 0 ? HxOverrides.substr(s,pos,null) : HxOverrides.substr(s,pos,len));
			if(b) {
				this.r.s = s;
				this.r.m.index += pos;
			}
			return b;
		}
	}
	,split: function(s) {
		return s.replace(this.r,"#__delim__#").split("#__delim__#");
	}
	,map: function(s,f) {
		var offset = 0;
		var buf_b = "";
		while(true) {
			if(offset >= s.length) {
				break;
			} else if(!this.matchSub(s,offset)) {
				buf_b += Std.string(HxOverrides.substr(s,offset,null));
				break;
			}
			var p = this.matchedPos();
			buf_b += Std.string(HxOverrides.substr(s,offset,p.pos - offset));
			buf_b += Std.string(f(this));
			if(p.len == 0) {
				buf_b += Std.string(HxOverrides.substr(s,p.pos,1));
				offset = p.pos + 1;
			} else {
				offset = p.pos + p.len;
			}
			if(!this.r.global) {
				break;
			}
		}
		if(!this.r.global && offset > 0 && offset < s.length) {
			buf_b += Std.string(HxOverrides.substr(s,offset,null));
		}
		return buf_b;
	}
	,__class__: EReg
};
var HxOverrides = function() { };
HxOverrides.__name__ = true;
HxOverrides.dateStr = function(date) {
	var m = date.getMonth() + 1;
	var d = date.getDate();
	var h = date.getHours();
	var mi = date.getMinutes();
	var s = date.getSeconds();
	return date.getFullYear() + "-" + (m < 10 ? "0" + m : "" + m) + "-" + (d < 10 ? "0" + d : "" + d) + " " + (h < 10 ? "0" + h : "" + h) + ":" + (mi < 10 ? "0" + mi : "" + mi) + ":" + (s < 10 ? "0" + s : "" + s);
};
HxOverrides.strDate = function(s) {
	switch(s.length) {
	case 8:
		var k = s.split(":");
		var d = new Date();
		d["setTime"](0);
		d["setUTCHours"](k[0]);
		d["setUTCMinutes"](k[1]);
		d["setUTCSeconds"](k[2]);
		return d;
	case 10:
		var k = s.split("-");
		return new Date(k[0],k[1] - 1,k[2],0,0,0);
	case 19:
		var k = s.split(" ");
		var y = k[0].split("-");
		var t = k[1].split(":");
		return new Date(y[0],y[1] - 1,y[2],t[0],t[1],t[2]);
	default:
		throw haxe_Exception.thrown("Invalid date format : " + s);
	}
};
HxOverrides.cca = function(s,index) {
	var x = s.charCodeAt(index);
	if(x != x) {
		return undefined;
	}
	return x;
};
HxOverrides.substr = function(s,pos,len) {
	if(len == null) {
		len = s.length;
	} else if(len < 0) {
		if(pos == 0) {
			len = s.length + len;
		} else {
			return "";
		}
	}
	return s.substr(pos,len);
};
HxOverrides.remove = function(a,obj) {
	var i = a.indexOf(obj);
	if(i == -1) {
		return false;
	}
	a.splice(i,1);
	return true;
};
HxOverrides.now = function() {
	return Date.now();
};
var json2object_reader_BaseParser = function(errors,putils,errorType) {
	this.errors = errors;
	this.putils = putils;
	this.errorType = errorType;
};
json2object_reader_BaseParser.__name__ = true;
json2object_reader_BaseParser.prototype = {
	fromJson: function(jsonString,filename) {
		if(filename == null) {
			filename = "";
		}
		this.putils = new json2object_PositionUtils(jsonString);
		this.errors = [];
		try {
			this.loadJson(new hxjsonast_Parser(jsonString,filename).doParse());
		} catch( _g ) {
			var _g1 = haxe_Exception.caught(_g).unwrap();
			if(((_g1) instanceof hxjsonast_Error)) {
				var e = _g1;
				this.errors.push(json2object_Error.ParserError(e.message,this.putils.convertPosition(e.pos)));
			} else {
				throw _g;
			}
		}
		return this.value;
	}
	,loadJson: function(json,variable) {
		if(variable == null) {
			variable = "";
		}
		var pos = this.putils.convertPosition(json.pos);
		var _g = json.value;
		switch(_g._hx_index) {
		case 0:
			this.loadJsonString(_g.s,pos,variable);
			break;
		case 1:
			this.loadJsonNumber(_g.s,pos,variable);
			break;
		case 2:
			this.loadJsonObject(_g.fields,pos,variable);
			break;
		case 3:
			this.loadJsonArray(_g.values,pos,variable);
			break;
		case 4:
			this.loadJsonBool(_g.b,pos,variable);
			break;
		case 5:
			this.loadJsonNull(pos,variable);
			break;
		}
		return this.value;
	}
	,loadJsonNull: function(pos,variable) {
		this.onIncorrectType(pos,variable);
	}
	,loadJsonString: function(s,pos,variable) {
		this.onIncorrectType(pos,variable);
	}
	,loadString: function(s,pos,variable,validValues,defaultValue) {
		if(validValues.indexOf(s) != -1) {
			return s;
		}
		this.onIncorrectType(pos,variable);
		return defaultValue;
	}
	,loadJsonNumber: function(f,pos,variable) {
		this.onIncorrectType(pos,variable);
	}
	,loadJsonInt: function(f,pos,variable,value) {
		if(Std.parseInt(f) != null && Std.parseInt(f) == parseFloat(f)) {
			return Std.parseInt(f);
		}
		this.onIncorrectType(pos,variable);
		return value;
	}
	,loadJsonFloat: function(f,pos,variable,value) {
		if(Std.parseInt(f) != null) {
			return parseFloat(f);
		}
		this.onIncorrectType(pos,variable);
		return value;
	}
	,loadJsonBool: function(b,pos,variable) {
		this.onIncorrectType(pos,variable);
	}
	,loadJsonArray: function(a,pos,variable) {
		this.onIncorrectType(pos,variable);
	}
	,loadJsonArrayValue: function(a,loadJsonFn,variable) {
		var _g = [];
		var _g1 = 0;
		while(_g1 < a.length) {
			var j = a[_g1++];
			var tmp;
			try {
				tmp = loadJsonFn(j,variable);
			} catch( _g2 ) {
				var _g3 = haxe_Exception.caught(_g2).unwrap();
				if(js_Boot.__instanceof(_g3,json2object_InternalError)) {
					var e = _g3;
					if(e != json2object_InternalError.ParsingThrow) {
						throw haxe_Exception.thrown(e);
					}
					continue;
				} else {
					throw _g2;
				}
			}
			_g.push(tmp);
		}
		return _g;
	}
	,loadJsonObject: function(o,pos,variable) {
		this.onIncorrectType(pos,variable);
	}
	,loadObjectField: function(loadJsonFn,field,name,assigned,defaultValue,pos) {
		try {
			var ret = loadJsonFn(field.value,field.name);
			this.mapSet(assigned,name,true);
			return ret;
		} catch( _g ) {
			var _g1 = haxe_Exception.caught(_g).unwrap();
			if(js_Boot.__instanceof(_g1,json2object_InternalError)) {
				var e = _g1;
				if(e != json2object_InternalError.ParsingThrow) {
					throw haxe_Exception.thrown(e);
				}
			} else {
				this.errors.push(json2object_Error.CustomFunctionException(_g1,pos));
			}
		}
		return defaultValue;
	}
	,objectSetupAssign: function(assigned,keys,values) {
		var _g = 0;
		var _g1 = keys.length;
		while(_g < _g1) {
			var i = _g++;
			this.mapSet(assigned,keys[i],values[i]);
		}
	}
	,objectErrors: function(assigned,pos) {
		var lastPos = this.putils.convertPosition(new hxjsonast_Position(pos.file,pos.max - 1,pos.max - 1));
		var s_keys = Object.keys(assigned.h);
		var s_length = s_keys.length;
		var s_current = 0;
		while(s_current < s_length) {
			var s = s_keys[s_current++];
			if(!assigned.h[s]) {
				this.errors.push(json2object_Error.UninitializedVariable(s,lastPos));
			}
		}
	}
	,onIncorrectType: function(pos,variable) {
		this.parsingThrow();
	}
	,parsingThrow: function() {
		if(this.errorType != 0) {
			throw haxe_Exception.thrown(json2object_InternalError.ParsingThrow);
		}
	}
	,objectThrow: function(pos,variable) {
		if(this.errorType == 2) {
			throw haxe_Exception.thrown(json2object_InternalError.ParsingThrow);
		}
		if(this.errorType == 1) {
			this.errors.push(json2object_Error.UninitializedVariable(variable,pos));
		}
	}
	,mapSet: function(map,key,value) {
		map.h[key] = value;
	}
	,__class__: json2object_reader_BaseParser
};
var JsonParser_$1 = function(errors,putils,errorType) {
	if(errorType == null) {
		errorType = 0;
	}
	json2object_reader_BaseParser.call(this,errors,putils,errorType);
};
JsonParser_$1.__name__ = true;
JsonParser_$1.__super__ = json2object_reader_BaseParser;
JsonParser_$1.prototype = $extend(json2object_reader_BaseParser.prototype,{
	onIncorrectType: function(pos,variable) {
		this.errors.push(json2object_Error.IncorrectType(variable,"{ ?updatePlaylist : Null<{ videoList : Array<VideoItem> }>, ?updateClients : Null<{ clients : Array<ClientData> }>, type : WsEventType, ?togglePlaylistLock : Null<{ isOpen : Bool }>, ?toggleItemType : Null<{ pos : Int }>, ?skipVideo : Null<{ url : String }>, ?setTime : Null<{ time : Float }>, ?setRate : Null<{ rate : Float }>, ?setNextItem : Null<{ pos : Int }>, ?setLeader : Null<{ clientName : String }>, ?serverMessage : Null<{ textId : String }>, ?rewind : Null<{ time : Float }>, ?removeVideo : Null<{ url : String }>, ?playItem : Null<{ pos : Int }>, ?play : Null<{ time : Float }>, ?pause : Null<{ time : Float }>, ?message : Null<{ text : String, clientName : String }>, ?logout : Null<{ oldClientName : String, clients : Array<ClientData>, clientName : String }>, ?login : Null<{ ?passHash : Null<String>, ?isUnknownClient : Null<Bool>, ?clients : Null<Array<ClientData>>, clientName : String }>, ?kickClient : Null<{ name : String }>, ?getTime : Null<{ time : Float, ?rate : Null<Float>, ?paused : Null<Bool> }>, ?dump : Null<{ data : String }>, ?connected : Null<{ videoList : Array<VideoItem>, itemPos : Int, isUnknownClient : Bool, isPlaylistOpen : Bool, history : Array<Message>, globalIp : String, config : Config, clients : Array<ClientData>, clientName : String }>, ?banClient : Null<{ time : Float, name : String }>, ?addVideo : Null<{ item : VideoItem, atEnd : Bool }> }",pos));
		json2object_reader_BaseParser.prototype.onIncorrectType.call(this,pos,variable);
	}
	,loadJsonNull: function(pos,variable) {
		this.value = null;
	}
	,loadJsonObject: function(o,pos,variable) {
		var assigned = new haxe_ds_StringMap();
		this.objectSetupAssign(assigned,["addVideo","banClient","connected","dump","getTime","kickClient","login","logout","message","pause","play","playItem","removeVideo","rewind","serverMessage","setLeader","setNextItem","setRate","setTime","skipVideo","toggleItemType","togglePlaylistLock","type","updateClients","updatePlaylist"],[true,true,true,true,true,true,true,true,true,true,true,true,true,true,true,true,true,true,true,true,true,true,false,true,true]);
		this.value = this.getAuto();
		var _g = 0;
		while(_g < o.length) {
			var field = o[_g];
			++_g;
			switch(field.name) {
			case "addVideo":
				this.value.addVideo = this.loadObjectField(($_=new JsonParser_$3(this.errors,this.putils,1),$bind($_,$_.loadJson)),field,"addVideo",assigned,this.value.addVideo,pos);
				break;
			case "banClient":
				this.value.banClient = this.loadObjectField(($_=new JsonParser_$5(this.errors,this.putils,1),$bind($_,$_.loadJson)),field,"banClient",assigned,this.value.banClient,pos);
				break;
			case "connected":
				this.value.connected = this.loadObjectField(($_=new JsonParser_$7(this.errors,this.putils,1),$bind($_,$_.loadJson)),field,"connected",assigned,this.value.connected,pos);
				break;
			case "dump":
				this.value.dump = this.loadObjectField(($_=new JsonParser_$9(this.errors,this.putils,1),$bind($_,$_.loadJson)),field,"dump",assigned,this.value.dump,pos);
				break;
			case "getTime":
				this.value.getTime = this.loadObjectField(($_=new JsonParser_$11(this.errors,this.putils,1),$bind($_,$_.loadJson)),field,"getTime",assigned,this.value.getTime,pos);
				break;
			case "kickClient":
				this.value.kickClient = this.loadObjectField(($_=new JsonParser_$13(this.errors,this.putils,1),$bind($_,$_.loadJson)),field,"kickClient",assigned,this.value.kickClient,pos);
				break;
			case "login":
				this.value.login = this.loadObjectField(($_=new JsonParser_$15(this.errors,this.putils,1),$bind($_,$_.loadJson)),field,"login",assigned,this.value.login,pos);
				break;
			case "logout":
				this.value.logout = this.loadObjectField(($_=new JsonParser_$17(this.errors,this.putils,1),$bind($_,$_.loadJson)),field,"logout",assigned,this.value.logout,pos);
				break;
			case "message":
				this.value.message = this.loadObjectField(($_=new JsonParser_$19(this.errors,this.putils,1),$bind($_,$_.loadJson)),field,"message",assigned,this.value.message,pos);
				break;
			case "pause":
				this.value.pause = this.loadObjectField(($_=new JsonParser_$21(this.errors,this.putils,1),$bind($_,$_.loadJson)),field,"pause",assigned,this.value.pause,pos);
				break;
			case "play":
				this.value.play = this.loadObjectField(($_=new JsonParser_$21(this.errors,this.putils,1),$bind($_,$_.loadJson)),field,"play",assigned,this.value.play,pos);
				break;
			case "playItem":
				this.value.playItem = this.loadObjectField(($_=new JsonParser_$23(this.errors,this.putils,1),$bind($_,$_.loadJson)),field,"playItem",assigned,this.value.playItem,pos);
				break;
			case "removeVideo":
				this.value.removeVideo = this.loadObjectField(($_=new JsonParser_$25(this.errors,this.putils,1),$bind($_,$_.loadJson)),field,"removeVideo",assigned,this.value.removeVideo,pos);
				break;
			case "rewind":
				this.value.rewind = this.loadObjectField(($_=new JsonParser_$21(this.errors,this.putils,1),$bind($_,$_.loadJson)),field,"rewind",assigned,this.value.rewind,pos);
				break;
			case "serverMessage":
				this.value.serverMessage = this.loadObjectField(($_=new JsonParser_$27(this.errors,this.putils,1),$bind($_,$_.loadJson)),field,"serverMessage",assigned,this.value.serverMessage,pos);
				break;
			case "setLeader":
				this.value.setLeader = this.loadObjectField(($_=new JsonParser_$29(this.errors,this.putils,1),$bind($_,$_.loadJson)),field,"setLeader",assigned,this.value.setLeader,pos);
				break;
			case "setNextItem":
				this.value.setNextItem = this.loadObjectField(($_=new JsonParser_$23(this.errors,this.putils,1),$bind($_,$_.loadJson)),field,"setNextItem",assigned,this.value.setNextItem,pos);
				break;
			case "setRate":
				this.value.setRate = this.loadObjectField(($_=new JsonParser_$31(this.errors,this.putils,1),$bind($_,$_.loadJson)),field,"setRate",assigned,this.value.setRate,pos);
				break;
			case "setTime":
				this.value.setTime = this.loadObjectField(($_=new JsonParser_$21(this.errors,this.putils,1),$bind($_,$_.loadJson)),field,"setTime",assigned,this.value.setTime,pos);
				break;
			case "skipVideo":
				this.value.skipVideo = this.loadObjectField(($_=new JsonParser_$25(this.errors,this.putils,1),$bind($_,$_.loadJson)),field,"skipVideo",assigned,this.value.skipVideo,pos);
				break;
			case "toggleItemType":
				this.value.toggleItemType = this.loadObjectField(($_=new JsonParser_$23(this.errors,this.putils,1),$bind($_,$_.loadJson)),field,"toggleItemType",assigned,this.value.toggleItemType,pos);
				break;
			case "togglePlaylistLock":
				this.value.togglePlaylistLock = this.loadObjectField(($_=new JsonParser_$33(this.errors,this.putils,1),$bind($_,$_.loadJson)),field,"togglePlaylistLock",assigned,this.value.togglePlaylistLock,pos);
				break;
			case "type":
				this.value.type = this.loadObjectField(($_=new JsonParser_$34(this.errors,this.putils,1),$bind($_,$_.loadJson)),field,"type",assigned,this.value.type,pos);
				break;
			case "updateClients":
				this.value.updateClients = this.loadObjectField(($_=new JsonParser_$36(this.errors,this.putils,1),$bind($_,$_.loadJson)),field,"updateClients",assigned,this.value.updateClients,pos);
				break;
			case "updatePlaylist":
				this.value.updatePlaylist = this.loadObjectField(($_=new JsonParser_$38(this.errors,this.putils,1),$bind($_,$_.loadJson)),field,"updatePlaylist",assigned,this.value.updatePlaylist,pos);
				break;
			default:
				this.errors.push(json2object_Error.UnknownVariable(field.name,this.putils.convertPosition(field.namePos)));
			}
		}
		this.objectErrors(assigned,pos);
	}
	,getAuto: function() {
		return { addVideo : new JsonParser_$3([],this.putils,0).loadJson(new hxjsonast_Json(hxjsonast_JsonValue.JNull,new hxjsonast_Position("",0,1))), banClient : new JsonParser_$5([],this.putils,0).loadJson(new hxjsonast_Json(hxjsonast_JsonValue.JNull,new hxjsonast_Position("",0,1))), connected : new JsonParser_$7([],this.putils,0).loadJson(new hxjsonast_Json(hxjsonast_JsonValue.JNull,new hxjsonast_Position("",0,1))), dump : new JsonParser_$9([],this.putils,0).loadJson(new hxjsonast_Json(hxjsonast_JsonValue.JNull,new hxjsonast_Position("",0,1))), getTime : new JsonParser_$11([],this.putils,0).loadJson(new hxjsonast_Json(hxjsonast_JsonValue.JNull,new hxjsonast_Position("",0,1))), kickClient : new JsonParser_$13([],this.putils,0).loadJson(new hxjsonast_Json(hxjsonast_JsonValue.JNull,new hxjsonast_Position("",0,1))), login : new JsonParser_$15([],this.putils,0).loadJson(new hxjsonast_Json(hxjsonast_JsonValue.JNull,new hxjsonast_Position("",0,1))), logout : new JsonParser_$17([],this.putils,0).loadJson(new hxjsonast_Json(hxjsonast_JsonValue.JNull,new hxjsonast_Position("",0,1))), message : new JsonParser_$19([],this.putils,0).loadJson(new hxjsonast_Json(hxjsonast_JsonValue.JNull,new hxjsonast_Position("",0,1))), pause : new JsonParser_$21([],this.putils,0).loadJson(new hxjsonast_Json(hxjsonast_JsonValue.JNull,new hxjsonast_Position("",0,1))), play : new JsonParser_$21([],this.putils,0).loadJson(new hxjsonast_Json(hxjsonast_JsonValue.JNull,new hxjsonast_Position("",0,1))), playItem : new JsonParser_$23([],this.putils,0).loadJson(new hxjsonast_Json(hxjsonast_JsonValue.JNull,new hxjsonast_Position("",0,1))), removeVideo : new JsonParser_$25([],this.putils,0).loadJson(new hxjsonast_Json(hxjsonast_JsonValue.JNull,new hxjsonast_Position("",0,1))), rewind : new JsonParser_$21([],this.putils,0).loadJson(new hxjsonast_Json(hxjsonast_JsonValue.JNull,new hxjsonast_Position("",0,1))), serverMessage : new JsonParser_$27([],this.putils,0).loadJson(new hxjsonast_Json(hxjsonast_JsonValue.JNull,new hxjsonast_Position("",0,1))), setLeader : new JsonParser_$29([],this.putils,0).loadJson(new hxjsonast_Json(hxjsonast_JsonValue.JNull,new hxjsonast_Position("",0,1))), setNextItem : new JsonParser_$23([],this.putils,0).loadJson(new hxjsonast_Json(hxjsonast_JsonValue.JNull,new hxjsonast_Position("",0,1))), setRate : new JsonParser_$31([],this.putils,0).loadJson(new hxjsonast_Json(hxjsonast_JsonValue.JNull,new hxjsonast_Position("",0,1))), setTime : new JsonParser_$21([],this.putils,0).loadJson(new hxjsonast_Json(hxjsonast_JsonValue.JNull,new hxjsonast_Position("",0,1))), skipVideo : new JsonParser_$25([],this.putils,0).loadJson(new hxjsonast_Json(hxjsonast_JsonValue.JNull,new hxjsonast_Position("",0,1))), toggleItemType : new JsonParser_$23([],this.putils,0).loadJson(new hxjsonast_Json(hxjsonast_JsonValue.JNull,new hxjsonast_Position("",0,1))), togglePlaylistLock : new JsonParser_$33([],this.putils,0).loadJson(new hxjsonast_Json(hxjsonast_JsonValue.JNull,new hxjsonast_Position("",0,1))), type : new JsonParser_$34([],this.putils,0).loadJson(new hxjsonast_Json(hxjsonast_JsonValue.JNull,new hxjsonast_Position("",0,1))), updateClients : new JsonParser_$36([],this.putils,0).loadJson(new hxjsonast_Json(hxjsonast_JsonValue.JNull,new hxjsonast_Position("",0,1))), updatePlaylist : new JsonParser_$38([],this.putils,0).loadJson(new hxjsonast_Json(hxjsonast_JsonValue.JNull,new hxjsonast_Position("",0,1)))};
	}
	,__class__: JsonParser_$1
});
var JsonParser_$11 = function(errors,putils,errorType) {
	if(errorType == null) {
		errorType = 0;
	}
	json2object_reader_BaseParser.call(this,errors,putils,errorType);
};
JsonParser_$11.__name__ = true;
JsonParser_$11.__super__ = json2object_reader_BaseParser;
JsonParser_$11.prototype = $extend(json2object_reader_BaseParser.prototype,{
	onIncorrectType: function(pos,variable) {
		this.errors.push(json2object_Error.IncorrectType(variable,"{ time : Float, ?rate : Null<Float>, ?paused : Null<Bool> }",pos));
		json2object_reader_BaseParser.prototype.onIncorrectType.call(this,pos,variable);
	}
	,loadJsonNull: function(pos,variable) {
		this.value = null;
	}
	,loadJsonObject: function(o,pos,variable) {
		var assigned = new haxe_ds_StringMap();
		this.objectSetupAssign(assigned,["paused","rate","time"],[true,true,false]);
		this.value = this.getAuto();
		var _g = 0;
		while(_g < o.length) {
			var field = o[_g];
			++_g;
			switch(field.name) {
			case "paused":
				this.value.paused = this.loadObjectField(($_=new JsonParser_$54(this.errors,this.putils,1),$bind($_,$_.loadJson)),field,"paused",assigned,this.value.paused,pos);
				break;
			case "rate":
				this.value.rate = this.loadObjectField(($_=new JsonParser_$56(this.errors,this.putils,1),$bind($_,$_.loadJson)),field,"rate",assigned,this.value.rate,pos);
				break;
			case "time":
				this.value.time = this.loadObjectField(($_=new JsonParser_$43(this.errors,this.putils,1),$bind($_,$_.loadJson)),field,"time",assigned,this.value.time,pos);
				break;
			default:
				this.errors.push(json2object_Error.UnknownVariable(field.name,this.putils.convertPosition(field.namePos)));
			}
		}
		this.objectErrors(assigned,pos);
	}
	,getAuto: function() {
		return { paused : new JsonParser_$54([],this.putils,0).loadJson(new hxjsonast_Json(hxjsonast_JsonValue.JNull,new hxjsonast_Position("",0,1))), rate : new JsonParser_$56([],this.putils,0).loadJson(new hxjsonast_Json(hxjsonast_JsonValue.JNull,new hxjsonast_Position("",0,1))), time : new JsonParser_$43([],this.putils,0).loadJson(new hxjsonast_Json(hxjsonast_JsonValue.JNull,new hxjsonast_Position("",0,1)))};
	}
	,__class__: JsonParser_$11
});
var JsonParser_$13 = function(errors,putils,errorType) {
	if(errorType == null) {
		errorType = 0;
	}
	json2object_reader_BaseParser.call(this,errors,putils,errorType);
};
JsonParser_$13.__name__ = true;
JsonParser_$13.__super__ = json2object_reader_BaseParser;
JsonParser_$13.prototype = $extend(json2object_reader_BaseParser.prototype,{
	onIncorrectType: function(pos,variable) {
		this.errors.push(json2object_Error.IncorrectType(variable,"{ name : String }",pos));
		json2object_reader_BaseParser.prototype.onIncorrectType.call(this,pos,variable);
	}
	,loadJsonNull: function(pos,variable) {
		this.value = null;
	}
	,loadJsonObject: function(o,pos,variable) {
		var assigned = new haxe_ds_StringMap();
		this.objectSetupAssign(assigned,["name"],[false]);
		this.value = this.getAuto();
		var _g = 0;
		while(_g < o.length) {
			var field = o[_g];
			++_g;
			if(field.name == "name") {
				this.value.name = this.loadObjectField(($_=new JsonParser_$42(this.errors,this.putils,1),$bind($_,$_.loadJson)),field,"name",assigned,this.value.name,pos);
			} else {
				this.errors.push(json2object_Error.UnknownVariable(field.name,this.putils.convertPosition(field.namePos)));
			}
		}
		this.objectErrors(assigned,pos);
	}
	,getAuto: function() {
		return { name : new JsonParser_$42([],this.putils,0).loadJson(new hxjsonast_Json(hxjsonast_JsonValue.JNull,new hxjsonast_Position("",0,1)))};
	}
	,__class__: JsonParser_$13
});
var JsonParser_$15 = function(errors,putils,errorType) {
	if(errorType == null) {
		errorType = 0;
	}
	json2object_reader_BaseParser.call(this,errors,putils,errorType);
};
JsonParser_$15.__name__ = true;
JsonParser_$15.__super__ = json2object_reader_BaseParser;
JsonParser_$15.prototype = $extend(json2object_reader_BaseParser.prototype,{
	onIncorrectType: function(pos,variable) {
		this.errors.push(json2object_Error.IncorrectType(variable,"{ ?passHash : Null<String>, ?isUnknownClient : Null<Bool>, ?clients : Null<Array<ClientData>>, clientName : String }",pos));
		json2object_reader_BaseParser.prototype.onIncorrectType.call(this,pos,variable);
	}
	,loadJsonNull: function(pos,variable) {
		this.value = null;
	}
	,loadJsonObject: function(o,pos,variable) {
		var assigned = new haxe_ds_StringMap();
		this.objectSetupAssign(assigned,["clientName","clients","isUnknownClient","passHash"],[false,true,true,true]);
		this.value = this.getAuto();
		var _g = 0;
		while(_g < o.length) {
			var field = o[_g];
			++_g;
			switch(field.name) {
			case "clientName":
				this.value.clientName = this.loadObjectField(($_=new JsonParser_$42(this.errors,this.putils,1),$bind($_,$_.loadJson)),field,"clientName",assigned,this.value.clientName,pos);
				break;
			case "clients":
				this.value.clients = this.loadObjectField(($_=new JsonParser_$52(this.errors,this.putils,1),$bind($_,$_.loadJson)),field,"clients",assigned,this.value.clients,pos);
				break;
			case "isUnknownClient":
				this.value.isUnknownClient = this.loadObjectField(($_=new JsonParser_$54(this.errors,this.putils,1),$bind($_,$_.loadJson)),field,"isUnknownClient",assigned,this.value.isUnknownClient,pos);
				break;
			case "passHash":
				this.value.passHash = this.loadObjectField(($_=new JsonParser_$46(this.errors,this.putils,1),$bind($_,$_.loadJson)),field,"passHash",assigned,this.value.passHash,pos);
				break;
			default:
				this.errors.push(json2object_Error.UnknownVariable(field.name,this.putils.convertPosition(field.namePos)));
			}
		}
		this.objectErrors(assigned,pos);
	}
	,getAuto: function() {
		return { clientName : new JsonParser_$42([],this.putils,0).loadJson(new hxjsonast_Json(hxjsonast_JsonValue.JNull,new hxjsonast_Position("",0,1))), clients : new JsonParser_$52([],this.putils,0).loadJson(new hxjsonast_Json(hxjsonast_JsonValue.JNull,new hxjsonast_Position("",0,1))), isUnknownClient : new JsonParser_$54([],this.putils,0).loadJson(new hxjsonast_Json(hxjsonast_JsonValue.JNull,new hxjsonast_Position("",0,1))), passHash : new JsonParser_$46([],this.putils,0).loadJson(new hxjsonast_Json(hxjsonast_JsonValue.JNull,new hxjsonast_Position("",0,1)))};
	}
	,__class__: JsonParser_$15
});
var JsonParser_$17 = function(errors,putils,errorType) {
	if(errorType == null) {
		errorType = 0;
	}
	json2object_reader_BaseParser.call(this,errors,putils,errorType);
};
JsonParser_$17.__name__ = true;
JsonParser_$17.__super__ = json2object_reader_BaseParser;
JsonParser_$17.prototype = $extend(json2object_reader_BaseParser.prototype,{
	onIncorrectType: function(pos,variable) {
		this.errors.push(json2object_Error.IncorrectType(variable,"{ oldClientName : String, clients : Array<ClientData>, clientName : String }",pos));
		json2object_reader_BaseParser.prototype.onIncorrectType.call(this,pos,variable);
	}
	,loadJsonNull: function(pos,variable) {
		this.value = null;
	}
	,loadJsonObject: function(o,pos,variable) {
		var assigned = new haxe_ds_StringMap();
		this.objectSetupAssign(assigned,["clientName","clients","oldClientName"],[false,false,false]);
		this.value = this.getAuto();
		var _g = 0;
		while(_g < o.length) {
			var field = o[_g];
			++_g;
			switch(field.name) {
			case "clientName":
				this.value.clientName = this.loadObjectField(($_=new JsonParser_$42(this.errors,this.putils,1),$bind($_,$_.loadJson)),field,"clientName",assigned,this.value.clientName,pos);
				break;
			case "clients":
				this.value.clients = this.loadObjectField(($_=new JsonParser_$47(this.errors,this.putils,1),$bind($_,$_.loadJson)),field,"clients",assigned,this.value.clients,pos);
				break;
			case "oldClientName":
				this.value.oldClientName = this.loadObjectField(($_=new JsonParser_$42(this.errors,this.putils,1),$bind($_,$_.loadJson)),field,"oldClientName",assigned,this.value.oldClientName,pos);
				break;
			default:
				this.errors.push(json2object_Error.UnknownVariable(field.name,this.putils.convertPosition(field.namePos)));
			}
		}
		this.objectErrors(assigned,pos);
	}
	,getAuto: function() {
		return { clientName : new JsonParser_$42([],this.putils,0).loadJson(new hxjsonast_Json(hxjsonast_JsonValue.JNull,new hxjsonast_Position("",0,1))), clients : new JsonParser_$47([],this.putils,0).loadJson(new hxjsonast_Json(hxjsonast_JsonValue.JNull,new hxjsonast_Position("",0,1))), oldClientName : new JsonParser_$42([],this.putils,0).loadJson(new hxjsonast_Json(hxjsonast_JsonValue.JNull,new hxjsonast_Position("",0,1)))};
	}
	,__class__: JsonParser_$17
});
var JsonParser_$19 = function(errors,putils,errorType) {
	if(errorType == null) {
		errorType = 0;
	}
	json2object_reader_BaseParser.call(this,errors,putils,errorType);
};
JsonParser_$19.__name__ = true;
JsonParser_$19.__super__ = json2object_reader_BaseParser;
JsonParser_$19.prototype = $extend(json2object_reader_BaseParser.prototype,{
	onIncorrectType: function(pos,variable) {
		this.errors.push(json2object_Error.IncorrectType(variable,"{ text : String, clientName : String }",pos));
		json2object_reader_BaseParser.prototype.onIncorrectType.call(this,pos,variable);
	}
	,loadJsonNull: function(pos,variable) {
		this.value = null;
	}
	,loadJsonObject: function(o,pos,variable) {
		var assigned = new haxe_ds_StringMap();
		this.objectSetupAssign(assigned,["clientName","text"],[false,false]);
		this.value = this.getAuto();
		var _g = 0;
		while(_g < o.length) {
			var field = o[_g];
			++_g;
			switch(field.name) {
			case "clientName":
				this.value.clientName = this.loadObjectField(($_=new JsonParser_$42(this.errors,this.putils,1),$bind($_,$_.loadJson)),field,"clientName",assigned,this.value.clientName,pos);
				break;
			case "text":
				this.value.text = this.loadObjectField(($_=new JsonParser_$42(this.errors,this.putils,1),$bind($_,$_.loadJson)),field,"text",assigned,this.value.text,pos);
				break;
			default:
				this.errors.push(json2object_Error.UnknownVariable(field.name,this.putils.convertPosition(field.namePos)));
			}
		}
		this.objectErrors(assigned,pos);
	}
	,getAuto: function() {
		return { clientName : new JsonParser_$42([],this.putils,0).loadJson(new hxjsonast_Json(hxjsonast_JsonValue.JNull,new hxjsonast_Position("",0,1))), text : new JsonParser_$42([],this.putils,0).loadJson(new hxjsonast_Json(hxjsonast_JsonValue.JNull,new hxjsonast_Position("",0,1)))};
	}
	,__class__: JsonParser_$19
});
var JsonParser_$21 = function(errors,putils,errorType) {
	if(errorType == null) {
		errorType = 0;
	}
	json2object_reader_BaseParser.call(this,errors,putils,errorType);
};
JsonParser_$21.__name__ = true;
JsonParser_$21.__super__ = json2object_reader_BaseParser;
JsonParser_$21.prototype = $extend(json2object_reader_BaseParser.prototype,{
	onIncorrectType: function(pos,variable) {
		this.errors.push(json2object_Error.IncorrectType(variable,"{ time : Float }",pos));
		json2object_reader_BaseParser.prototype.onIncorrectType.call(this,pos,variable);
	}
	,loadJsonNull: function(pos,variable) {
		this.value = null;
	}
	,loadJsonObject: function(o,pos,variable) {
		var assigned = new haxe_ds_StringMap();
		this.objectSetupAssign(assigned,["time"],[false]);
		this.value = this.getAuto();
		var _g = 0;
		while(_g < o.length) {
			var field = o[_g];
			++_g;
			if(field.name == "time") {
				this.value.time = this.loadObjectField(($_=new JsonParser_$43(this.errors,this.putils,1),$bind($_,$_.loadJson)),field,"time",assigned,this.value.time,pos);
			} else {
				this.errors.push(json2object_Error.UnknownVariable(field.name,this.putils.convertPosition(field.namePos)));
			}
		}
		this.objectErrors(assigned,pos);
	}
	,getAuto: function() {
		return { time : new JsonParser_$43([],this.putils,0).loadJson(new hxjsonast_Json(hxjsonast_JsonValue.JNull,new hxjsonast_Position("",0,1)))};
	}
	,__class__: JsonParser_$21
});
var JsonParser_$23 = function(errors,putils,errorType) {
	if(errorType == null) {
		errorType = 0;
	}
	json2object_reader_BaseParser.call(this,errors,putils,errorType);
};
JsonParser_$23.__name__ = true;
JsonParser_$23.__super__ = json2object_reader_BaseParser;
JsonParser_$23.prototype = $extend(json2object_reader_BaseParser.prototype,{
	onIncorrectType: function(pos,variable) {
		this.errors.push(json2object_Error.IncorrectType(variable,"{ pos : Int }",pos));
		json2object_reader_BaseParser.prototype.onIncorrectType.call(this,pos,variable);
	}
	,loadJsonNull: function(pos,variable) {
		this.value = null;
	}
	,loadJsonObject: function(o,pos,variable) {
		var assigned = new haxe_ds_StringMap();
		this.objectSetupAssign(assigned,["pos"],[false]);
		this.value = this.getAuto();
		var _g = 0;
		while(_g < o.length) {
			var field = o[_g];
			++_g;
			if(field.name == "pos") {
				this.value.pos = this.loadObjectField(($_=new JsonParser_$50(this.errors,this.putils,1),$bind($_,$_.loadJson)),field,"pos",assigned,this.value.pos,pos);
			} else {
				this.errors.push(json2object_Error.UnknownVariable(field.name,this.putils.convertPosition(field.namePos)));
			}
		}
		this.objectErrors(assigned,pos);
	}
	,getAuto: function() {
		return { pos : new JsonParser_$50([],this.putils,0).loadJson(new hxjsonast_Json(hxjsonast_JsonValue.JNull,new hxjsonast_Position("",0,1)))};
	}
	,__class__: JsonParser_$23
});
var JsonParser_$25 = function(errors,putils,errorType) {
	if(errorType == null) {
		errorType = 0;
	}
	json2object_reader_BaseParser.call(this,errors,putils,errorType);
};
JsonParser_$25.__name__ = true;
JsonParser_$25.__super__ = json2object_reader_BaseParser;
JsonParser_$25.prototype = $extend(json2object_reader_BaseParser.prototype,{
	onIncorrectType: function(pos,variable) {
		this.errors.push(json2object_Error.IncorrectType(variable,"{ url : String }",pos));
		json2object_reader_BaseParser.prototype.onIncorrectType.call(this,pos,variable);
	}
	,loadJsonNull: function(pos,variable) {
		this.value = null;
	}
	,loadJsonObject: function(o,pos,variable) {
		var assigned = new haxe_ds_StringMap();
		this.objectSetupAssign(assigned,["url"],[false]);
		this.value = this.getAuto();
		var _g = 0;
		while(_g < o.length) {
			var field = o[_g];
			++_g;
			if(field.name == "url") {
				this.value.url = this.loadObjectField(($_=new JsonParser_$42(this.errors,this.putils,1),$bind($_,$_.loadJson)),field,"url",assigned,this.value.url,pos);
			} else {
				this.errors.push(json2object_Error.UnknownVariable(field.name,this.putils.convertPosition(field.namePos)));
			}
		}
		this.objectErrors(assigned,pos);
	}
	,getAuto: function() {
		return { url : new JsonParser_$42([],this.putils,0).loadJson(new hxjsonast_Json(hxjsonast_JsonValue.JNull,new hxjsonast_Position("",0,1)))};
	}
	,__class__: JsonParser_$25
});
var JsonParser_$27 = function(errors,putils,errorType) {
	if(errorType == null) {
		errorType = 0;
	}
	json2object_reader_BaseParser.call(this,errors,putils,errorType);
};
JsonParser_$27.__name__ = true;
JsonParser_$27.__super__ = json2object_reader_BaseParser;
JsonParser_$27.prototype = $extend(json2object_reader_BaseParser.prototype,{
	onIncorrectType: function(pos,variable) {
		this.errors.push(json2object_Error.IncorrectType(variable,"{ textId : String }",pos));
		json2object_reader_BaseParser.prototype.onIncorrectType.call(this,pos,variable);
	}
	,loadJsonNull: function(pos,variable) {
		this.value = null;
	}
	,loadJsonObject: function(o,pos,variable) {
		var assigned = new haxe_ds_StringMap();
		this.objectSetupAssign(assigned,["textId"],[false]);
		this.value = this.getAuto();
		var _g = 0;
		while(_g < o.length) {
			var field = o[_g];
			++_g;
			if(field.name == "textId") {
				this.value.textId = this.loadObjectField(($_=new JsonParser_$42(this.errors,this.putils,1),$bind($_,$_.loadJson)),field,"textId",assigned,this.value.textId,pos);
			} else {
				this.errors.push(json2object_Error.UnknownVariable(field.name,this.putils.convertPosition(field.namePos)));
			}
		}
		this.objectErrors(assigned,pos);
	}
	,getAuto: function() {
		return { textId : new JsonParser_$42([],this.putils,0).loadJson(new hxjsonast_Json(hxjsonast_JsonValue.JNull,new hxjsonast_Position("",0,1)))};
	}
	,__class__: JsonParser_$27
});
var JsonParser_$29 = function(errors,putils,errorType) {
	if(errorType == null) {
		errorType = 0;
	}
	json2object_reader_BaseParser.call(this,errors,putils,errorType);
};
JsonParser_$29.__name__ = true;
JsonParser_$29.__super__ = json2object_reader_BaseParser;
JsonParser_$29.prototype = $extend(json2object_reader_BaseParser.prototype,{
	onIncorrectType: function(pos,variable) {
		this.errors.push(json2object_Error.IncorrectType(variable,"{ clientName : String }",pos));
		json2object_reader_BaseParser.prototype.onIncorrectType.call(this,pos,variable);
	}
	,loadJsonNull: function(pos,variable) {
		this.value = null;
	}
	,loadJsonObject: function(o,pos,variable) {
		var assigned = new haxe_ds_StringMap();
		this.objectSetupAssign(assigned,["clientName"],[false]);
		this.value = this.getAuto();
		var _g = 0;
		while(_g < o.length) {
			var field = o[_g];
			++_g;
			if(field.name == "clientName") {
				this.value.clientName = this.loadObjectField(($_=new JsonParser_$42(this.errors,this.putils,1),$bind($_,$_.loadJson)),field,"clientName",assigned,this.value.clientName,pos);
			} else {
				this.errors.push(json2object_Error.UnknownVariable(field.name,this.putils.convertPosition(field.namePos)));
			}
		}
		this.objectErrors(assigned,pos);
	}
	,getAuto: function() {
		return { clientName : new JsonParser_$42([],this.putils,0).loadJson(new hxjsonast_Json(hxjsonast_JsonValue.JNull,new hxjsonast_Position("",0,1)))};
	}
	,__class__: JsonParser_$29
});
var JsonParser_$3 = function(errors,putils,errorType) {
	if(errorType == null) {
		errorType = 0;
	}
	json2object_reader_BaseParser.call(this,errors,putils,errorType);
};
JsonParser_$3.__name__ = true;
JsonParser_$3.__super__ = json2object_reader_BaseParser;
JsonParser_$3.prototype = $extend(json2object_reader_BaseParser.prototype,{
	onIncorrectType: function(pos,variable) {
		this.errors.push(json2object_Error.IncorrectType(variable,"{ item : VideoItem, atEnd : Bool }",pos));
		json2object_reader_BaseParser.prototype.onIncorrectType.call(this,pos,variable);
	}
	,loadJsonNull: function(pos,variable) {
		this.value = null;
	}
	,loadJsonObject: function(o,pos,variable) {
		var assigned = new haxe_ds_StringMap();
		this.objectSetupAssign(assigned,["atEnd","item"],[false,false]);
		this.value = this.getAuto();
		var _g = 0;
		while(_g < o.length) {
			var field = o[_g];
			++_g;
			switch(field.name) {
			case "atEnd":
				this.value.atEnd = this.loadObjectField(($_=new JsonParser_$44(this.errors,this.putils,1),$bind($_,$_.loadJson)),field,"atEnd",assigned,this.value.atEnd,pos);
				break;
			case "item":
				this.value.item = this.loadObjectField(($_=new JsonParser_$41(this.errors,this.putils,1),$bind($_,$_.loadJson)),field,"item",assigned,this.value.item,pos);
				break;
			default:
				this.errors.push(json2object_Error.UnknownVariable(field.name,this.putils.convertPosition(field.namePos)));
			}
		}
		this.objectErrors(assigned,pos);
	}
	,getAuto: function() {
		return { atEnd : new JsonParser_$44([],this.putils,0).loadJson(new hxjsonast_Json(hxjsonast_JsonValue.JNull,new hxjsonast_Position("",0,1))), item : new JsonParser_$41([],this.putils,0).loadJson(new hxjsonast_Json(hxjsonast_JsonValue.JNull,new hxjsonast_Position("",0,1)))};
	}
	,__class__: JsonParser_$3
});
var JsonParser_$31 = function(errors,putils,errorType) {
	if(errorType == null) {
		errorType = 0;
	}
	json2object_reader_BaseParser.call(this,errors,putils,errorType);
};
JsonParser_$31.__name__ = true;
JsonParser_$31.__super__ = json2object_reader_BaseParser;
JsonParser_$31.prototype = $extend(json2object_reader_BaseParser.prototype,{
	onIncorrectType: function(pos,variable) {
		this.errors.push(json2object_Error.IncorrectType(variable,"{ rate : Float }",pos));
		json2object_reader_BaseParser.prototype.onIncorrectType.call(this,pos,variable);
	}
	,loadJsonNull: function(pos,variable) {
		this.value = null;
	}
	,loadJsonObject: function(o,pos,variable) {
		var assigned = new haxe_ds_StringMap();
		this.objectSetupAssign(assigned,["rate"],[false]);
		this.value = this.getAuto();
		var _g = 0;
		while(_g < o.length) {
			var field = o[_g];
			++_g;
			if(field.name == "rate") {
				this.value.rate = this.loadObjectField(($_=new JsonParser_$43(this.errors,this.putils,1),$bind($_,$_.loadJson)),field,"rate",assigned,this.value.rate,pos);
			} else {
				this.errors.push(json2object_Error.UnknownVariable(field.name,this.putils.convertPosition(field.namePos)));
			}
		}
		this.objectErrors(assigned,pos);
	}
	,getAuto: function() {
		return { rate : new JsonParser_$43([],this.putils,0).loadJson(new hxjsonast_Json(hxjsonast_JsonValue.JNull,new hxjsonast_Position("",0,1)))};
	}
	,__class__: JsonParser_$31
});
var JsonParser_$33 = function(errors,putils,errorType) {
	if(errorType == null) {
		errorType = 0;
	}
	json2object_reader_BaseParser.call(this,errors,putils,errorType);
};
JsonParser_$33.__name__ = true;
JsonParser_$33.__super__ = json2object_reader_BaseParser;
JsonParser_$33.prototype = $extend(json2object_reader_BaseParser.prototype,{
	onIncorrectType: function(pos,variable) {
		this.errors.push(json2object_Error.IncorrectType(variable,"{ isOpen : Bool }",pos));
		json2object_reader_BaseParser.prototype.onIncorrectType.call(this,pos,variable);
	}
	,loadJsonNull: function(pos,variable) {
		this.value = null;
	}
	,loadJsonObject: function(o,pos,variable) {
		var assigned = new haxe_ds_StringMap();
		this.objectSetupAssign(assigned,["isOpen"],[false]);
		this.value = this.getAuto();
		var _g = 0;
		while(_g < o.length) {
			var field = o[_g];
			++_g;
			if(field.name == "isOpen") {
				this.value.isOpen = this.loadObjectField(($_=new JsonParser_$44(this.errors,this.putils,1),$bind($_,$_.loadJson)),field,"isOpen",assigned,this.value.isOpen,pos);
			} else {
				this.errors.push(json2object_Error.UnknownVariable(field.name,this.putils.convertPosition(field.namePos)));
			}
		}
		this.objectErrors(assigned,pos);
	}
	,getAuto: function() {
		return { isOpen : new JsonParser_$44([],this.putils,0).loadJson(new hxjsonast_Json(hxjsonast_JsonValue.JNull,new hxjsonast_Position("",0,1)))};
	}
	,__class__: JsonParser_$33
});
var JsonParser_$34 = function(errors,putils,errorType) {
	if(errorType == null) {
		errorType = 0;
	}
	json2object_reader_BaseParser.call(this,errors,putils,errorType);
};
JsonParser_$34.__name__ = true;
JsonParser_$34.__super__ = json2object_reader_BaseParser;
JsonParser_$34.prototype = $extend(json2object_reader_BaseParser.prototype,{
	onIncorrectType: function(pos,variable) {
		this.value = "Connected";
		this.errors.push(json2object_Error.IncorrectType(variable,"WsEventType",pos));
		this.objectThrow(pos,variable);
	}
	,loadJsonNull: function(pos,variable) {
		this.value = null;
	}
	,loadJsonString: function(s,pos,variable) {
		this.value = this.loadString(s,pos,variable,["Connected","Disconnected","Login","PasswordRequest","LoginError","Logout","Message","ServerMessage","UpdateClients","BanClient","KickClient","AddVideo","RemoveVideo","SkipVideo","VideoLoaded","Pause","Play","GetTime","SetTime","SetRate","Rewind","Flashback","SetLeader","PlayItem","SetNextItem","ToggleItemType","ClearChat","ClearPlaylist","ShufflePlaylist","UpdatePlaylist","TogglePlaylistLock","Dump"],"Connected");
	}
	,__class__: JsonParser_$34
});
var JsonParser_$36 = function(errors,putils,errorType) {
	if(errorType == null) {
		errorType = 0;
	}
	json2object_reader_BaseParser.call(this,errors,putils,errorType);
};
JsonParser_$36.__name__ = true;
JsonParser_$36.__super__ = json2object_reader_BaseParser;
JsonParser_$36.prototype = $extend(json2object_reader_BaseParser.prototype,{
	onIncorrectType: function(pos,variable) {
		this.errors.push(json2object_Error.IncorrectType(variable,"{ clients : Array<ClientData> }",pos));
		json2object_reader_BaseParser.prototype.onIncorrectType.call(this,pos,variable);
	}
	,loadJsonNull: function(pos,variable) {
		this.value = null;
	}
	,loadJsonObject: function(o,pos,variable) {
		var assigned = new haxe_ds_StringMap();
		this.objectSetupAssign(assigned,["clients"],[false]);
		this.value = this.getAuto();
		var _g = 0;
		while(_g < o.length) {
			var field = o[_g];
			++_g;
			if(field.name == "clients") {
				this.value.clients = this.loadObjectField(($_=new JsonParser_$47(this.errors,this.putils,1),$bind($_,$_.loadJson)),field,"clients",assigned,this.value.clients,pos);
			} else {
				this.errors.push(json2object_Error.UnknownVariable(field.name,this.putils.convertPosition(field.namePos)));
			}
		}
		this.objectErrors(assigned,pos);
	}
	,getAuto: function() {
		return { clients : new JsonParser_$47([],this.putils,0).loadJson(new hxjsonast_Json(hxjsonast_JsonValue.JNull,new hxjsonast_Position("",0,1)))};
	}
	,__class__: JsonParser_$36
});
var JsonParser_$38 = function(errors,putils,errorType) {
	if(errorType == null) {
		errorType = 0;
	}
	json2object_reader_BaseParser.call(this,errors,putils,errorType);
};
JsonParser_$38.__name__ = true;
JsonParser_$38.__super__ = json2object_reader_BaseParser;
JsonParser_$38.prototype = $extend(json2object_reader_BaseParser.prototype,{
	onIncorrectType: function(pos,variable) {
		this.errors.push(json2object_Error.IncorrectType(variable,"{ videoList : Array<VideoItem> }",pos));
		json2object_reader_BaseParser.prototype.onIncorrectType.call(this,pos,variable);
	}
	,loadJsonNull: function(pos,variable) {
		this.value = null;
	}
	,loadJsonObject: function(o,pos,variable) {
		var assigned = new haxe_ds_StringMap();
		this.objectSetupAssign(assigned,["videoList"],[false]);
		this.value = this.getAuto();
		var _g = 0;
		while(_g < o.length) {
			var field = o[_g];
			++_g;
			if(field.name == "videoList") {
				this.value.videoList = this.loadObjectField(($_=new JsonParser_$39(this.errors,this.putils,1),$bind($_,$_.loadJson)),field,"videoList",assigned,this.value.videoList,pos);
			} else {
				this.errors.push(json2object_Error.UnknownVariable(field.name,this.putils.convertPosition(field.namePos)));
			}
		}
		this.objectErrors(assigned,pos);
	}
	,getAuto: function() {
		return { videoList : new JsonParser_$39([],this.putils,0).loadJson(new hxjsonast_Json(hxjsonast_JsonValue.JNull,new hxjsonast_Position("",0,1)))};
	}
	,__class__: JsonParser_$38
});
var JsonParser_$39 = function(errors,putils,errorType) {
	if(errorType == null) {
		errorType = 0;
	}
	json2object_reader_BaseParser.call(this,errors,putils,errorType);
};
JsonParser_$39.__name__ = true;
JsonParser_$39.__super__ = json2object_reader_BaseParser;
JsonParser_$39.prototype = $extend(json2object_reader_BaseParser.prototype,{
	onIncorrectType: function(pos,variable) {
		this.errors.push(json2object_Error.IncorrectType(variable,"Array<VideoItem>",pos));
		json2object_reader_BaseParser.prototype.onIncorrectType.call(this,pos,variable);
	}
	,loadJsonNull: function(pos,variable) {
		this.value = null;
	}
	,loadJsonArray: function(a,pos,variable) {
		this.value = this.loadJsonArrayValue(a,($_=new JsonParser_$41(this.errors,this.putils,2),$bind($_,$_.loadJson)),variable);
	}
	,__class__: JsonParser_$39
});
var JsonParser_$41 = function(errors,putils,errorType) {
	if(errorType == null) {
		errorType = 0;
	}
	json2object_reader_BaseParser.call(this,errors,putils,errorType);
};
JsonParser_$41.__name__ = true;
JsonParser_$41.__super__ = json2object_reader_BaseParser;
JsonParser_$41.prototype = $extend(json2object_reader_BaseParser.prototype,{
	onIncorrectType: function(pos,variable) {
		this.errors.push(json2object_Error.IncorrectType(variable,"{ url : String, title : String, ?subs : Null<String>, isTemp : Bool, isIframe : Bool, duration : Float, author : String }",pos));
		json2object_reader_BaseParser.prototype.onIncorrectType.call(this,pos,variable);
	}
	,loadJsonNull: function(pos,variable) {
		this.value = null;
	}
	,loadJsonObject: function(o,pos,variable) {
		var assigned = new haxe_ds_StringMap();
		this.objectSetupAssign(assigned,["author","duration","isIframe","isTemp","subs","title","url"],[false,false,false,false,true,false,false]);
		this.value = this.getAuto();
		var _g = 0;
		while(_g < o.length) {
			var field = o[_g];
			++_g;
			switch(field.name) {
			case "author":
				this.value.author = this.loadObjectField(($_=new JsonParser_$42(this.errors,this.putils,1),$bind($_,$_.loadJson)),field,"author",assigned,this.value.author,pos);
				break;
			case "duration":
				this.value.duration = this.loadObjectField(($_=new JsonParser_$43(this.errors,this.putils,1),$bind($_,$_.loadJson)),field,"duration",assigned,this.value.duration,pos);
				break;
			case "isIframe":
				this.value.isIframe = this.loadObjectField(($_=new JsonParser_$44(this.errors,this.putils,1),$bind($_,$_.loadJson)),field,"isIframe",assigned,this.value.isIframe,pos);
				break;
			case "isTemp":
				this.value.isTemp = this.loadObjectField(($_=new JsonParser_$44(this.errors,this.putils,1),$bind($_,$_.loadJson)),field,"isTemp",assigned,this.value.isTemp,pos);
				break;
			case "subs":
				this.value.subs = this.loadObjectField(($_=new JsonParser_$46(this.errors,this.putils,1),$bind($_,$_.loadJson)),field,"subs",assigned,this.value.subs,pos);
				break;
			case "title":
				this.value.title = this.loadObjectField(($_=new JsonParser_$42(this.errors,this.putils,1),$bind($_,$_.loadJson)),field,"title",assigned,this.value.title,pos);
				break;
			case "url":
				this.value.url = this.loadObjectField(($_=new JsonParser_$42(this.errors,this.putils,1),$bind($_,$_.loadJson)),field,"url",assigned,this.value.url,pos);
				break;
			default:
				this.errors.push(json2object_Error.UnknownVariable(field.name,this.putils.convertPosition(field.namePos)));
			}
		}
		this.objectErrors(assigned,pos);
	}
	,getAuto: function() {
		return { author : new JsonParser_$42([],this.putils,0).loadJson(new hxjsonast_Json(hxjsonast_JsonValue.JNull,new hxjsonast_Position("",0,1))), duration : new JsonParser_$43([],this.putils,0).loadJson(new hxjsonast_Json(hxjsonast_JsonValue.JNull,new hxjsonast_Position("",0,1))), isIframe : new JsonParser_$44([],this.putils,0).loadJson(new hxjsonast_Json(hxjsonast_JsonValue.JNull,new hxjsonast_Position("",0,1))), isTemp : new JsonParser_$44([],this.putils,0).loadJson(new hxjsonast_Json(hxjsonast_JsonValue.JNull,new hxjsonast_Position("",0,1))), subs : new JsonParser_$46([],this.putils,0).loadJson(new hxjsonast_Json(hxjsonast_JsonValue.JNull,new hxjsonast_Position("",0,1))), title : new JsonParser_$42([],this.putils,0).loadJson(new hxjsonast_Json(hxjsonast_JsonValue.JNull,new hxjsonast_Position("",0,1))), url : new JsonParser_$42([],this.putils,0).loadJson(new hxjsonast_Json(hxjsonast_JsonValue.JNull,new hxjsonast_Position("",0,1)))};
	}
	,__class__: JsonParser_$41
});
var JsonParser_$42 = function(errors,putils,errorType) {
	if(errorType == null) {
		errorType = 0;
	}
	json2object_reader_BaseParser.call(this,errors,putils,errorType);
};
JsonParser_$42.__name__ = true;
JsonParser_$42.__super__ = json2object_reader_BaseParser;
JsonParser_$42.prototype = $extend(json2object_reader_BaseParser.prototype,{
	onIncorrectType: function(pos,variable) {
		this.errors.push(json2object_Error.IncorrectType(variable,"String",pos));
		json2object_reader_BaseParser.prototype.onIncorrectType.call(this,pos,variable);
	}
	,loadJsonNull: function(pos,variable) {
		this.value = null;
	}
	,loadJsonString: function(s,pos,variable) {
		this.value = s;
	}
	,__class__: JsonParser_$42
});
var JsonParser_$43 = function(errors,putils,errorType) {
	if(errorType == null) {
		errorType = 0;
	}
	json2object_reader_BaseParser.call(this,errors,putils,errorType);
	this.value = 0;
};
JsonParser_$43.__name__ = true;
JsonParser_$43.__super__ = json2object_reader_BaseParser;
JsonParser_$43.prototype = $extend(json2object_reader_BaseParser.prototype,{
	onIncorrectType: function(pos,variable) {
		this.errors.push(json2object_Error.IncorrectType(variable,"Float",pos));
		json2object_reader_BaseParser.prototype.onIncorrectType.call(this,pos,variable);
	}
	,loadJsonNumber: function(f,pos,variable) {
		this.value = this.loadJsonFloat(f,pos,variable,this.value);
	}
	,__class__: JsonParser_$43
});
var JsonParser_$44 = function(errors,putils,errorType) {
	if(errorType == null) {
		errorType = 0;
	}
	json2object_reader_BaseParser.call(this,errors,putils,errorType);
	this.value = false;
};
JsonParser_$44.__name__ = true;
JsonParser_$44.__super__ = json2object_reader_BaseParser;
JsonParser_$44.prototype = $extend(json2object_reader_BaseParser.prototype,{
	onIncorrectType: function(pos,variable) {
		this.errors.push(json2object_Error.IncorrectType(variable,"Bool",pos));
		json2object_reader_BaseParser.prototype.onIncorrectType.call(this,pos,variable);
	}
	,loadJsonBool: function(b,pos,variable) {
		this.value = b;
	}
	,__class__: JsonParser_$44
});
var JsonParser_$46 = function(errors,putils,errorType) {
	if(errorType == null) {
		errorType = 0;
	}
	json2object_reader_BaseParser.call(this,errors,putils,errorType);
};
JsonParser_$46.__name__ = true;
JsonParser_$46.__super__ = json2object_reader_BaseParser;
JsonParser_$46.prototype = $extend(json2object_reader_BaseParser.prototype,{
	onIncorrectType: function(pos,variable) {
		this.errors.push(json2object_Error.IncorrectType(variable,"String",pos));
		json2object_reader_BaseParser.prototype.onIncorrectType.call(this,pos,variable);
	}
	,loadJsonNull: function(pos,variable) {
		this.value = null;
	}
	,loadJsonString: function(s,pos,variable) {
		this.value = s;
	}
	,__class__: JsonParser_$46
});
var JsonParser_$47 = function(errors,putils,errorType) {
	if(errorType == null) {
		errorType = 0;
	}
	json2object_reader_BaseParser.call(this,errors,putils,errorType);
};
JsonParser_$47.__name__ = true;
JsonParser_$47.__super__ = json2object_reader_BaseParser;
JsonParser_$47.prototype = $extend(json2object_reader_BaseParser.prototype,{
	onIncorrectType: function(pos,variable) {
		this.errors.push(json2object_Error.IncorrectType(variable,"Array<ClientData>",pos));
		json2object_reader_BaseParser.prototype.onIncorrectType.call(this,pos,variable);
	}
	,loadJsonNull: function(pos,variable) {
		this.value = null;
	}
	,loadJsonArray: function(a,pos,variable) {
		this.value = this.loadJsonArrayValue(a,($_=new JsonParser_$49(this.errors,this.putils,2),$bind($_,$_.loadJson)),variable);
	}
	,__class__: JsonParser_$47
});
var JsonParser_$49 = function(errors,putils,errorType) {
	if(errorType == null) {
		errorType = 0;
	}
	json2object_reader_BaseParser.call(this,errors,putils,errorType);
};
JsonParser_$49.__name__ = true;
JsonParser_$49.__super__ = json2object_reader_BaseParser;
JsonParser_$49.prototype = $extend(json2object_reader_BaseParser.prototype,{
	onIncorrectType: function(pos,variable) {
		this.errors.push(json2object_Error.IncorrectType(variable,"{ name : String, group : Int }",pos));
		json2object_reader_BaseParser.prototype.onIncorrectType.call(this,pos,variable);
	}
	,loadJsonNull: function(pos,variable) {
		this.value = null;
	}
	,loadJsonObject: function(o,pos,variable) {
		var assigned = new haxe_ds_StringMap();
		this.objectSetupAssign(assigned,["group","name"],[false,false]);
		this.value = this.getAuto();
		var _g = 0;
		while(_g < o.length) {
			var field = o[_g];
			++_g;
			switch(field.name) {
			case "group":
				this.value.group = this.loadObjectField(($_=new JsonParser_$50(this.errors,this.putils,1),$bind($_,$_.loadJson)),field,"group",assigned,this.value.group,pos);
				break;
			case "name":
				this.value.name = this.loadObjectField(($_=new JsonParser_$42(this.errors,this.putils,1),$bind($_,$_.loadJson)),field,"name",assigned,this.value.name,pos);
				break;
			default:
				this.errors.push(json2object_Error.UnknownVariable(field.name,this.putils.convertPosition(field.namePos)));
			}
		}
		this.objectErrors(assigned,pos);
	}
	,getAuto: function() {
		return { group : new JsonParser_$50([],this.putils,0).loadJson(new hxjsonast_Json(hxjsonast_JsonValue.JNull,new hxjsonast_Position("",0,1))), name : new JsonParser_$42([],this.putils,0).loadJson(new hxjsonast_Json(hxjsonast_JsonValue.JNull,new hxjsonast_Position("",0,1)))};
	}
	,__class__: JsonParser_$49
});
var JsonParser_$5 = function(errors,putils,errorType) {
	if(errorType == null) {
		errorType = 0;
	}
	json2object_reader_BaseParser.call(this,errors,putils,errorType);
};
JsonParser_$5.__name__ = true;
JsonParser_$5.__super__ = json2object_reader_BaseParser;
JsonParser_$5.prototype = $extend(json2object_reader_BaseParser.prototype,{
	onIncorrectType: function(pos,variable) {
		this.errors.push(json2object_Error.IncorrectType(variable,"{ time : Float, name : String }",pos));
		json2object_reader_BaseParser.prototype.onIncorrectType.call(this,pos,variable);
	}
	,loadJsonNull: function(pos,variable) {
		this.value = null;
	}
	,loadJsonObject: function(o,pos,variable) {
		var assigned = new haxe_ds_StringMap();
		this.objectSetupAssign(assigned,["name","time"],[false,false]);
		this.value = this.getAuto();
		var _g = 0;
		while(_g < o.length) {
			var field = o[_g];
			++_g;
			switch(field.name) {
			case "name":
				this.value.name = this.loadObjectField(($_=new JsonParser_$42(this.errors,this.putils,1),$bind($_,$_.loadJson)),field,"name",assigned,this.value.name,pos);
				break;
			case "time":
				this.value.time = this.loadObjectField(($_=new JsonParser_$43(this.errors,this.putils,1),$bind($_,$_.loadJson)),field,"time",assigned,this.value.time,pos);
				break;
			default:
				this.errors.push(json2object_Error.UnknownVariable(field.name,this.putils.convertPosition(field.namePos)));
			}
		}
		this.objectErrors(assigned,pos);
	}
	,getAuto: function() {
		return { name : new JsonParser_$42([],this.putils,0).loadJson(new hxjsonast_Json(hxjsonast_JsonValue.JNull,new hxjsonast_Position("",0,1))), time : new JsonParser_$43([],this.putils,0).loadJson(new hxjsonast_Json(hxjsonast_JsonValue.JNull,new hxjsonast_Position("",0,1)))};
	}
	,__class__: JsonParser_$5
});
var JsonParser_$50 = function(errors,putils,errorType) {
	if(errorType == null) {
		errorType = 0;
	}
	json2object_reader_BaseParser.call(this,errors,putils,errorType);
	this.value = 0;
};
JsonParser_$50.__name__ = true;
JsonParser_$50.__super__ = json2object_reader_BaseParser;
JsonParser_$50.prototype = $extend(json2object_reader_BaseParser.prototype,{
	onIncorrectType: function(pos,variable) {
		this.errors.push(json2object_Error.IncorrectType(variable,"Int",pos));
		json2object_reader_BaseParser.prototype.onIncorrectType.call(this,pos,variable);
	}
	,loadJsonNumber: function(f,pos,variable) {
		this.value = this.loadJsonInt(f,pos,variable,this.value);
	}
	,__class__: JsonParser_$50
});
var JsonParser_$52 = function(errors,putils,errorType) {
	if(errorType == null) {
		errorType = 0;
	}
	json2object_reader_BaseParser.call(this,errors,putils,errorType);
};
JsonParser_$52.__name__ = true;
JsonParser_$52.__super__ = json2object_reader_BaseParser;
JsonParser_$52.prototype = $extend(json2object_reader_BaseParser.prototype,{
	onIncorrectType: function(pos,variable) {
		this.errors.push(json2object_Error.IncorrectType(variable,"Array<ClientData>",pos));
		json2object_reader_BaseParser.prototype.onIncorrectType.call(this,pos,variable);
	}
	,loadJsonNull: function(pos,variable) {
		this.value = null;
	}
	,loadJsonArray: function(a,pos,variable) {
		this.value = this.loadJsonArrayValue(a,($_=new JsonParser_$49(this.errors,this.putils,2),$bind($_,$_.loadJson)),variable);
	}
	,__class__: JsonParser_$52
});
var JsonParser_$54 = function(errors,putils,errorType) {
	if(errorType == null) {
		errorType = 0;
	}
	json2object_reader_BaseParser.call(this,errors,putils,errorType);
};
JsonParser_$54.__name__ = true;
JsonParser_$54.__super__ = json2object_reader_BaseParser;
JsonParser_$54.prototype = $extend(json2object_reader_BaseParser.prototype,{
	onIncorrectType: function(pos,variable) {
		this.errors.push(json2object_Error.IncorrectType(variable,"Bool",pos));
		json2object_reader_BaseParser.prototype.onIncorrectType.call(this,pos,variable);
	}
	,loadJsonNull: function(pos,variable) {
		this.value = null;
	}
	,loadJsonBool: function(b,pos,variable) {
		this.value = b;
	}
	,__class__: JsonParser_$54
});
var JsonParser_$56 = function(errors,putils,errorType) {
	if(errorType == null) {
		errorType = 0;
	}
	json2object_reader_BaseParser.call(this,errors,putils,errorType);
};
JsonParser_$56.__name__ = true;
JsonParser_$56.__super__ = json2object_reader_BaseParser;
JsonParser_$56.prototype = $extend(json2object_reader_BaseParser.prototype,{
	onIncorrectType: function(pos,variable) {
		this.errors.push(json2object_Error.IncorrectType(variable,"Float",pos));
		json2object_reader_BaseParser.prototype.onIncorrectType.call(this,pos,variable);
	}
	,loadJsonNull: function(pos,variable) {
		this.value = null;
	}
	,loadJsonNumber: function(f,pos,variable) {
		this.value = this.loadJsonFloat(f,pos,variable,this.value);
	}
	,__class__: JsonParser_$56
});
var JsonParser_$58 = function(errors,putils,errorType) {
	if(errorType == null) {
		errorType = 0;
	}
	json2object_reader_BaseParser.call(this,errors,putils,errorType);
};
JsonParser_$58.__name__ = true;
JsonParser_$58.__super__ = json2object_reader_BaseParser;
JsonParser_$58.prototype = $extend(json2object_reader_BaseParser.prototype,{
	onIncorrectType: function(pos,variable) {
		this.errors.push(json2object_Error.IncorrectType(variable,"{ youtubePlaylistLimit : Int, youtubeApiKey : String, userVideoLimit : Int, totalVideoLimit : Int, templateUrl : String, serverChatHistory : Int, ?salt : Null<String>, requestLeaderOnPause : Bool, port : Int, permissions : Permissions, maxMessageLength : Int, maxLoginLength : Int, localNetworkOnly : Bool, localAdmins : Bool, ?isVerbose : Null<Bool>, filters : Array<Filter>, emotes : Array<Emote>, channelName : String, allowProxyIps : Bool }",pos));
		json2object_reader_BaseParser.prototype.onIncorrectType.call(this,pos,variable);
	}
	,loadJsonNull: function(pos,variable) {
		this.value = null;
	}
	,loadJsonObject: function(o,pos,variable) {
		var assigned = new haxe_ds_StringMap();
		this.objectSetupAssign(assigned,["allowProxyIps","channelName","emotes","filters","isVerbose","localAdmins","localNetworkOnly","maxLoginLength","maxMessageLength","permissions","port","requestLeaderOnPause","salt","serverChatHistory","templateUrl","totalVideoLimit","userVideoLimit","youtubeApiKey","youtubePlaylistLimit"],[false,false,false,false,true,false,false,false,false,false,false,false,true,false,false,false,false,false,false]);
		this.value = this.getAuto();
		var _g = 0;
		while(_g < o.length) {
			var field = o[_g];
			++_g;
			switch(field.name) {
			case "allowProxyIps":
				this.value.allowProxyIps = this.loadObjectField(($_=new JsonParser_$44(this.errors,this.putils,1),$bind($_,$_.loadJson)),field,"allowProxyIps",assigned,this.value.allowProxyIps,pos);
				break;
			case "channelName":
				this.value.channelName = this.loadObjectField(($_=new JsonParser_$42(this.errors,this.putils,1),$bind($_,$_.loadJson)),field,"channelName",assigned,this.value.channelName,pos);
				break;
			case "emotes":
				this.value.emotes = this.loadObjectField(($_=new JsonParser_$62(this.errors,this.putils,1),$bind($_,$_.loadJson)),field,"emotes",assigned,this.value.emotes,pos);
				break;
			case "filters":
				this.value.filters = this.loadObjectField(($_=new JsonParser_$63(this.errors,this.putils,1),$bind($_,$_.loadJson)),field,"filters",assigned,this.value.filters,pos);
				break;
			case "isVerbose":
				this.value.isVerbose = this.loadObjectField(($_=new JsonParser_$54(this.errors,this.putils,1),$bind($_,$_.loadJson)),field,"isVerbose",assigned,this.value.isVerbose,pos);
				break;
			case "localAdmins":
				this.value.localAdmins = this.loadObjectField(($_=new JsonParser_$44(this.errors,this.putils,1),$bind($_,$_.loadJson)),field,"localAdmins",assigned,this.value.localAdmins,pos);
				break;
			case "localNetworkOnly":
				this.value.localNetworkOnly = this.loadObjectField(($_=new JsonParser_$44(this.errors,this.putils,1),$bind($_,$_.loadJson)),field,"localNetworkOnly",assigned,this.value.localNetworkOnly,pos);
				break;
			case "maxLoginLength":
				this.value.maxLoginLength = this.loadObjectField(($_=new JsonParser_$50(this.errors,this.putils,1),$bind($_,$_.loadJson)),field,"maxLoginLength",assigned,this.value.maxLoginLength,pos);
				break;
			case "maxMessageLength":
				this.value.maxMessageLength = this.loadObjectField(($_=new JsonParser_$50(this.errors,this.putils,1),$bind($_,$_.loadJson)),field,"maxMessageLength",assigned,this.value.maxMessageLength,pos);
				break;
			case "permissions":
				this.value.permissions = this.loadObjectField(($_=new JsonParser_$65(this.errors,this.putils,1),$bind($_,$_.loadJson)),field,"permissions",assigned,this.value.permissions,pos);
				break;
			case "port":
				this.value.port = this.loadObjectField(($_=new JsonParser_$50(this.errors,this.putils,1),$bind($_,$_.loadJson)),field,"port",assigned,this.value.port,pos);
				break;
			case "requestLeaderOnPause":
				this.value.requestLeaderOnPause = this.loadObjectField(($_=new JsonParser_$44(this.errors,this.putils,1),$bind($_,$_.loadJson)),field,"requestLeaderOnPause",assigned,this.value.requestLeaderOnPause,pos);
				break;
			case "salt":
				this.value.salt = this.loadObjectField(($_=new JsonParser_$46(this.errors,this.putils,1),$bind($_,$_.loadJson)),field,"salt",assigned,this.value.salt,pos);
				break;
			case "serverChatHistory":
				this.value.serverChatHistory = this.loadObjectField(($_=new JsonParser_$50(this.errors,this.putils,1),$bind($_,$_.loadJson)),field,"serverChatHistory",assigned,this.value.serverChatHistory,pos);
				break;
			case "templateUrl":
				this.value.templateUrl = this.loadObjectField(($_=new JsonParser_$42(this.errors,this.putils,1),$bind($_,$_.loadJson)),field,"templateUrl",assigned,this.value.templateUrl,pos);
				break;
			case "totalVideoLimit":
				this.value.totalVideoLimit = this.loadObjectField(($_=new JsonParser_$50(this.errors,this.putils,1),$bind($_,$_.loadJson)),field,"totalVideoLimit",assigned,this.value.totalVideoLimit,pos);
				break;
			case "userVideoLimit":
				this.value.userVideoLimit = this.loadObjectField(($_=new JsonParser_$50(this.errors,this.putils,1),$bind($_,$_.loadJson)),field,"userVideoLimit",assigned,this.value.userVideoLimit,pos);
				break;
			case "youtubeApiKey":
				this.value.youtubeApiKey = this.loadObjectField(($_=new JsonParser_$42(this.errors,this.putils,1),$bind($_,$_.loadJson)),field,"youtubeApiKey",assigned,this.value.youtubeApiKey,pos);
				break;
			case "youtubePlaylistLimit":
				this.value.youtubePlaylistLimit = this.loadObjectField(($_=new JsonParser_$50(this.errors,this.putils,1),$bind($_,$_.loadJson)),field,"youtubePlaylistLimit",assigned,this.value.youtubePlaylistLimit,pos);
				break;
			default:
				this.errors.push(json2object_Error.UnknownVariable(field.name,this.putils.convertPosition(field.namePos)));
			}
		}
		this.objectErrors(assigned,pos);
	}
	,getAuto: function() {
		return { allowProxyIps : new JsonParser_$44([],this.putils,0).loadJson(new hxjsonast_Json(hxjsonast_JsonValue.JNull,new hxjsonast_Position("",0,1))), channelName : new JsonParser_$42([],this.putils,0).loadJson(new hxjsonast_Json(hxjsonast_JsonValue.JNull,new hxjsonast_Position("",0,1))), emotes : new JsonParser_$62([],this.putils,0).loadJson(new hxjsonast_Json(hxjsonast_JsonValue.JNull,new hxjsonast_Position("",0,1))), filters : new JsonParser_$63([],this.putils,0).loadJson(new hxjsonast_Json(hxjsonast_JsonValue.JNull,new hxjsonast_Position("",0,1))), isVerbose : new JsonParser_$54([],this.putils,0).loadJson(new hxjsonast_Json(hxjsonast_JsonValue.JNull,new hxjsonast_Position("",0,1))), localAdmins : new JsonParser_$44([],this.putils,0).loadJson(new hxjsonast_Json(hxjsonast_JsonValue.JNull,new hxjsonast_Position("",0,1))), localNetworkOnly : new JsonParser_$44([],this.putils,0).loadJson(new hxjsonast_Json(hxjsonast_JsonValue.JNull,new hxjsonast_Position("",0,1))), maxLoginLength : new JsonParser_$50([],this.putils,0).loadJson(new hxjsonast_Json(hxjsonast_JsonValue.JNull,new hxjsonast_Position("",0,1))), maxMessageLength : new JsonParser_$50([],this.putils,0).loadJson(new hxjsonast_Json(hxjsonast_JsonValue.JNull,new hxjsonast_Position("",0,1))), permissions : new JsonParser_$65([],this.putils,0).loadJson(new hxjsonast_Json(hxjsonast_JsonValue.JNull,new hxjsonast_Position("",0,1))), port : new JsonParser_$50([],this.putils,0).loadJson(new hxjsonast_Json(hxjsonast_JsonValue.JNull,new hxjsonast_Position("",0,1))), requestLeaderOnPause : new JsonParser_$44([],this.putils,0).loadJson(new hxjsonast_Json(hxjsonast_JsonValue.JNull,new hxjsonast_Position("",0,1))), salt : new JsonParser_$46([],this.putils,0).loadJson(new hxjsonast_Json(hxjsonast_JsonValue.JNull,new hxjsonast_Position("",0,1))), serverChatHistory : new JsonParser_$50([],this.putils,0).loadJson(new hxjsonast_Json(hxjsonast_JsonValue.JNull,new hxjsonast_Position("",0,1))), templateUrl : new JsonParser_$42([],this.putils,0).loadJson(new hxjsonast_Json(hxjsonast_JsonValue.JNull,new hxjsonast_Position("",0,1))), totalVideoLimit : new JsonParser_$50([],this.putils,0).loadJson(new hxjsonast_Json(hxjsonast_JsonValue.JNull,new hxjsonast_Position("",0,1))), userVideoLimit : new JsonParser_$50([],this.putils,0).loadJson(new hxjsonast_Json(hxjsonast_JsonValue.JNull,new hxjsonast_Position("",0,1))), youtubeApiKey : new JsonParser_$42([],this.putils,0).loadJson(new hxjsonast_Json(hxjsonast_JsonValue.JNull,new hxjsonast_Position("",0,1))), youtubePlaylistLimit : new JsonParser_$50([],this.putils,0).loadJson(new hxjsonast_Json(hxjsonast_JsonValue.JNull,new hxjsonast_Position("",0,1)))};
	}
	,__class__: JsonParser_$58
});
var JsonParser_$59 = function(errors,putils,errorType) {
	if(errorType == null) {
		errorType = 0;
	}
	json2object_reader_BaseParser.call(this,errors,putils,errorType);
};
JsonParser_$59.__name__ = true;
JsonParser_$59.__super__ = json2object_reader_BaseParser;
JsonParser_$59.prototype = $extend(json2object_reader_BaseParser.prototype,{
	onIncorrectType: function(pos,variable) {
		this.errors.push(json2object_Error.IncorrectType(variable,"Array<Message>",pos));
		json2object_reader_BaseParser.prototype.onIncorrectType.call(this,pos,variable);
	}
	,loadJsonNull: function(pos,variable) {
		this.value = null;
	}
	,loadJsonArray: function(a,pos,variable) {
		this.value = this.loadJsonArrayValue(a,($_=new JsonParser_$61(this.errors,this.putils,2),$bind($_,$_.loadJson)),variable);
	}
	,__class__: JsonParser_$59
});
var JsonParser_$61 = function(errors,putils,errorType) {
	if(errorType == null) {
		errorType = 0;
	}
	json2object_reader_BaseParser.call(this,errors,putils,errorType);
};
JsonParser_$61.__name__ = true;
JsonParser_$61.__super__ = json2object_reader_BaseParser;
JsonParser_$61.prototype = $extend(json2object_reader_BaseParser.prototype,{
	onIncorrectType: function(pos,variable) {
		this.errors.push(json2object_Error.IncorrectType(variable,"{ time : String, text : String, name : String }",pos));
		json2object_reader_BaseParser.prototype.onIncorrectType.call(this,pos,variable);
	}
	,loadJsonNull: function(pos,variable) {
		this.value = null;
	}
	,loadJsonObject: function(o,pos,variable) {
		var assigned = new haxe_ds_StringMap();
		this.objectSetupAssign(assigned,["name","text","time"],[false,false,false]);
		this.value = this.getAuto();
		var _g = 0;
		while(_g < o.length) {
			var field = o[_g];
			++_g;
			switch(field.name) {
			case "name":
				this.value.name = this.loadObjectField(($_=new JsonParser_$42(this.errors,this.putils,1),$bind($_,$_.loadJson)),field,"name",assigned,this.value.name,pos);
				break;
			case "text":
				this.value.text = this.loadObjectField(($_=new JsonParser_$42(this.errors,this.putils,1),$bind($_,$_.loadJson)),field,"text",assigned,this.value.text,pos);
				break;
			case "time":
				this.value.time = this.loadObjectField(($_=new JsonParser_$42(this.errors,this.putils,1),$bind($_,$_.loadJson)),field,"time",assigned,this.value.time,pos);
				break;
			default:
				this.errors.push(json2object_Error.UnknownVariable(field.name,this.putils.convertPosition(field.namePos)));
			}
		}
		this.objectErrors(assigned,pos);
	}
	,getAuto: function() {
		return { name : new JsonParser_$42([],this.putils,0).loadJson(new hxjsonast_Json(hxjsonast_JsonValue.JNull,new hxjsonast_Position("",0,1))), text : new JsonParser_$42([],this.putils,0).loadJson(new hxjsonast_Json(hxjsonast_JsonValue.JNull,new hxjsonast_Position("",0,1))), time : new JsonParser_$42([],this.putils,0).loadJson(new hxjsonast_Json(hxjsonast_JsonValue.JNull,new hxjsonast_Position("",0,1)))};
	}
	,__class__: JsonParser_$61
});
var JsonParser_$62 = function(errors,putils,errorType) {
	if(errorType == null) {
		errorType = 0;
	}
	json2object_reader_BaseParser.call(this,errors,putils,errorType);
};
JsonParser_$62.__name__ = true;
JsonParser_$62.__super__ = json2object_reader_BaseParser;
JsonParser_$62.prototype = $extend(json2object_reader_BaseParser.prototype,{
	onIncorrectType: function(pos,variable) {
		this.errors.push(json2object_Error.IncorrectType(variable,"Array<Emote>",pos));
		json2object_reader_BaseParser.prototype.onIncorrectType.call(this,pos,variable);
	}
	,loadJsonNull: function(pos,variable) {
		this.value = null;
	}
	,loadJsonArray: function(a,pos,variable) {
		this.value = this.loadJsonArrayValue(a,($_=new JsonParser_$71(this.errors,this.putils,2),$bind($_,$_.loadJson)),variable);
	}
	,__class__: JsonParser_$62
});
var JsonParser_$63 = function(errors,putils,errorType) {
	if(errorType == null) {
		errorType = 0;
	}
	json2object_reader_BaseParser.call(this,errors,putils,errorType);
};
JsonParser_$63.__name__ = true;
JsonParser_$63.__super__ = json2object_reader_BaseParser;
JsonParser_$63.prototype = $extend(json2object_reader_BaseParser.prototype,{
	onIncorrectType: function(pos,variable) {
		this.errors.push(json2object_Error.IncorrectType(variable,"Array<Filter>",pos));
		json2object_reader_BaseParser.prototype.onIncorrectType.call(this,pos,variable);
	}
	,loadJsonNull: function(pos,variable) {
		this.value = null;
	}
	,loadJsonArray: function(a,pos,variable) {
		this.value = this.loadJsonArrayValue(a,($_=new JsonParser_$69(this.errors,this.putils,2),$bind($_,$_.loadJson)),variable);
	}
	,__class__: JsonParser_$63
});
var JsonParser_$65 = function(errors,putils,errorType) {
	if(errorType == null) {
		errorType = 0;
	}
	json2object_reader_BaseParser.call(this,errors,putils,errorType);
};
JsonParser_$65.__name__ = true;
JsonParser_$65.__super__ = json2object_reader_BaseParser;
JsonParser_$65.prototype = $extend(json2object_reader_BaseParser.prototype,{
	onIncorrectType: function(pos,variable) {
		this.errors.push(json2object_Error.IncorrectType(variable,"{ user : Array<Permission>, leader : Array<Permission>, guest : Array<Permission>, banned : Array<Permission>, admin : Array<Permission> }",pos));
		json2object_reader_BaseParser.prototype.onIncorrectType.call(this,pos,variable);
	}
	,loadJsonNull: function(pos,variable) {
		this.value = null;
	}
	,loadJsonObject: function(o,pos,variable) {
		var assigned = new haxe_ds_StringMap();
		this.objectSetupAssign(assigned,["admin","banned","guest","leader","user"],[false,false,false,false,false]);
		this.value = this.getAuto();
		var _g = 0;
		while(_g < o.length) {
			var field = o[_g];
			++_g;
			switch(field.name) {
			case "admin":
				this.value.admin = this.loadObjectField(($_=new JsonParser_$66(this.errors,this.putils,1),$bind($_,$_.loadJson)),field,"admin",assigned,this.value.admin,pos);
				break;
			case "banned":
				this.value.banned = this.loadObjectField(($_=new JsonParser_$66(this.errors,this.putils,1),$bind($_,$_.loadJson)),field,"banned",assigned,this.value.banned,pos);
				break;
			case "guest":
				this.value.guest = this.loadObjectField(($_=new JsonParser_$66(this.errors,this.putils,1),$bind($_,$_.loadJson)),field,"guest",assigned,this.value.guest,pos);
				break;
			case "leader":
				this.value.leader = this.loadObjectField(($_=new JsonParser_$66(this.errors,this.putils,1),$bind($_,$_.loadJson)),field,"leader",assigned,this.value.leader,pos);
				break;
			case "user":
				this.value.user = this.loadObjectField(($_=new JsonParser_$66(this.errors,this.putils,1),$bind($_,$_.loadJson)),field,"user",assigned,this.value.user,pos);
				break;
			default:
				this.errors.push(json2object_Error.UnknownVariable(field.name,this.putils.convertPosition(field.namePos)));
			}
		}
		this.objectErrors(assigned,pos);
	}
	,getAuto: function() {
		return { admin : new JsonParser_$66([],this.putils,0).loadJson(new hxjsonast_Json(hxjsonast_JsonValue.JNull,new hxjsonast_Position("",0,1))), banned : new JsonParser_$66([],this.putils,0).loadJson(new hxjsonast_Json(hxjsonast_JsonValue.JNull,new hxjsonast_Position("",0,1))), guest : new JsonParser_$66([],this.putils,0).loadJson(new hxjsonast_Json(hxjsonast_JsonValue.JNull,new hxjsonast_Position("",0,1))), leader : new JsonParser_$66([],this.putils,0).loadJson(new hxjsonast_Json(hxjsonast_JsonValue.JNull,new hxjsonast_Position("",0,1))), user : new JsonParser_$66([],this.putils,0).loadJson(new hxjsonast_Json(hxjsonast_JsonValue.JNull,new hxjsonast_Position("",0,1)))};
	}
	,__class__: JsonParser_$65
});
var JsonParser_$66 = function(errors,putils,errorType) {
	if(errorType == null) {
		errorType = 0;
	}
	json2object_reader_BaseParser.call(this,errors,putils,errorType);
};
JsonParser_$66.__name__ = true;
JsonParser_$66.__super__ = json2object_reader_BaseParser;
JsonParser_$66.prototype = $extend(json2object_reader_BaseParser.prototype,{
	onIncorrectType: function(pos,variable) {
		this.errors.push(json2object_Error.IncorrectType(variable,"Array<Permission>",pos));
		json2object_reader_BaseParser.prototype.onIncorrectType.call(this,pos,variable);
	}
	,loadJsonNull: function(pos,variable) {
		this.value = null;
	}
	,loadJsonArray: function(a,pos,variable) {
		this.value = this.loadJsonArrayValue(a,($_=new JsonParser_$67(this.errors,this.putils,2),$bind($_,$_.loadJson)),variable);
	}
	,__class__: JsonParser_$66
});
var JsonParser_$67 = function(errors,putils,errorType) {
	if(errorType == null) {
		errorType = 0;
	}
	json2object_reader_BaseParser.call(this,errors,putils,errorType);
};
JsonParser_$67.__name__ = true;
JsonParser_$67.__super__ = json2object_reader_BaseParser;
JsonParser_$67.prototype = $extend(json2object_reader_BaseParser.prototype,{
	onIncorrectType: function(pos,variable) {
		this.value = "guest";
		this.errors.push(json2object_Error.IncorrectType(variable,"Permission",pos));
		this.objectThrow(pos,variable);
	}
	,loadJsonNull: function(pos,variable) {
		this.value = null;
	}
	,loadJsonString: function(s,pos,variable) {
		this.value = this.loadString(s,pos,variable,["guest","user","leader","admin","writeChat","addVideo","removeVideo","requestLeader","rewind","clearChat","setLeader","changeOrder","toggleItemType","lockPlaylist","banClient"],"guest");
	}
	,__class__: JsonParser_$67
});
var JsonParser_$69 = function(errors,putils,errorType) {
	if(errorType == null) {
		errorType = 0;
	}
	json2object_reader_BaseParser.call(this,errors,putils,errorType);
};
JsonParser_$69.__name__ = true;
JsonParser_$69.__super__ = json2object_reader_BaseParser;
JsonParser_$69.prototype = $extend(json2object_reader_BaseParser.prototype,{
	onIncorrectType: function(pos,variable) {
		this.errors.push(json2object_Error.IncorrectType(variable,"{ replace : String, regex : String, name : String, flags : String }",pos));
		json2object_reader_BaseParser.prototype.onIncorrectType.call(this,pos,variable);
	}
	,loadJsonNull: function(pos,variable) {
		this.value = null;
	}
	,loadJsonObject: function(o,pos,variable) {
		var assigned = new haxe_ds_StringMap();
		this.objectSetupAssign(assigned,["flags","name","regex","replace"],[false,false,false,false]);
		this.value = this.getAuto();
		var _g = 0;
		while(_g < o.length) {
			var field = o[_g];
			++_g;
			switch(field.name) {
			case "flags":
				this.value.flags = this.loadObjectField(($_=new JsonParser_$42(this.errors,this.putils,1),$bind($_,$_.loadJson)),field,"flags",assigned,this.value.flags,pos);
				break;
			case "name":
				this.value.name = this.loadObjectField(($_=new JsonParser_$42(this.errors,this.putils,1),$bind($_,$_.loadJson)),field,"name",assigned,this.value.name,pos);
				break;
			case "regex":
				this.value.regex = this.loadObjectField(($_=new JsonParser_$42(this.errors,this.putils,1),$bind($_,$_.loadJson)),field,"regex",assigned,this.value.regex,pos);
				break;
			case "replace":
				this.value.replace = this.loadObjectField(($_=new JsonParser_$42(this.errors,this.putils,1),$bind($_,$_.loadJson)),field,"replace",assigned,this.value.replace,pos);
				break;
			default:
				this.errors.push(json2object_Error.UnknownVariable(field.name,this.putils.convertPosition(field.namePos)));
			}
		}
		this.objectErrors(assigned,pos);
	}
	,getAuto: function() {
		return { flags : new JsonParser_$42([],this.putils,0).loadJson(new hxjsonast_Json(hxjsonast_JsonValue.JNull,new hxjsonast_Position("",0,1))), name : new JsonParser_$42([],this.putils,0).loadJson(new hxjsonast_Json(hxjsonast_JsonValue.JNull,new hxjsonast_Position("",0,1))), regex : new JsonParser_$42([],this.putils,0).loadJson(new hxjsonast_Json(hxjsonast_JsonValue.JNull,new hxjsonast_Position("",0,1))), replace : new JsonParser_$42([],this.putils,0).loadJson(new hxjsonast_Json(hxjsonast_JsonValue.JNull,new hxjsonast_Position("",0,1)))};
	}
	,__class__: JsonParser_$69
});
var JsonParser_$7 = function(errors,putils,errorType) {
	if(errorType == null) {
		errorType = 0;
	}
	json2object_reader_BaseParser.call(this,errors,putils,errorType);
};
JsonParser_$7.__name__ = true;
JsonParser_$7.__super__ = json2object_reader_BaseParser;
JsonParser_$7.prototype = $extend(json2object_reader_BaseParser.prototype,{
	onIncorrectType: function(pos,variable) {
		this.errors.push(json2object_Error.IncorrectType(variable,"{ videoList : Array<VideoItem>, itemPos : Int, isUnknownClient : Bool, isPlaylistOpen : Bool, history : Array<Message>, globalIp : String, config : Config, clients : Array<ClientData>, clientName : String }",pos));
		json2object_reader_BaseParser.prototype.onIncorrectType.call(this,pos,variable);
	}
	,loadJsonNull: function(pos,variable) {
		this.value = null;
	}
	,loadJsonObject: function(o,pos,variable) {
		var assigned = new haxe_ds_StringMap();
		this.objectSetupAssign(assigned,["clientName","clients","config","globalIp","history","isPlaylistOpen","isUnknownClient","itemPos","videoList"],[false,false,false,false,false,false,false,false,false]);
		this.value = this.getAuto();
		var _g = 0;
		while(_g < o.length) {
			var field = o[_g];
			++_g;
			switch(field.name) {
			case "clientName":
				this.value.clientName = this.loadObjectField(($_=new JsonParser_$42(this.errors,this.putils,1),$bind($_,$_.loadJson)),field,"clientName",assigned,this.value.clientName,pos);
				break;
			case "clients":
				this.value.clients = this.loadObjectField(($_=new JsonParser_$47(this.errors,this.putils,1),$bind($_,$_.loadJson)),field,"clients",assigned,this.value.clients,pos);
				break;
			case "config":
				this.value.config = this.loadObjectField(($_=new JsonParser_$58(this.errors,this.putils,1),$bind($_,$_.loadJson)),field,"config",assigned,this.value.config,pos);
				break;
			case "globalIp":
				this.value.globalIp = this.loadObjectField(($_=new JsonParser_$42(this.errors,this.putils,1),$bind($_,$_.loadJson)),field,"globalIp",assigned,this.value.globalIp,pos);
				break;
			case "history":
				this.value.history = this.loadObjectField(($_=new JsonParser_$59(this.errors,this.putils,1),$bind($_,$_.loadJson)),field,"history",assigned,this.value.history,pos);
				break;
			case "isPlaylistOpen":
				this.value.isPlaylistOpen = this.loadObjectField(($_=new JsonParser_$44(this.errors,this.putils,1),$bind($_,$_.loadJson)),field,"isPlaylistOpen",assigned,this.value.isPlaylistOpen,pos);
				break;
			case "isUnknownClient":
				this.value.isUnknownClient = this.loadObjectField(($_=new JsonParser_$44(this.errors,this.putils,1),$bind($_,$_.loadJson)),field,"isUnknownClient",assigned,this.value.isUnknownClient,pos);
				break;
			case "itemPos":
				this.value.itemPos = this.loadObjectField(($_=new JsonParser_$50(this.errors,this.putils,1),$bind($_,$_.loadJson)),field,"itemPos",assigned,this.value.itemPos,pos);
				break;
			case "videoList":
				this.value.videoList = this.loadObjectField(($_=new JsonParser_$39(this.errors,this.putils,1),$bind($_,$_.loadJson)),field,"videoList",assigned,this.value.videoList,pos);
				break;
			default:
				this.errors.push(json2object_Error.UnknownVariable(field.name,this.putils.convertPosition(field.namePos)));
			}
		}
		this.objectErrors(assigned,pos);
	}
	,getAuto: function() {
		return { clientName : new JsonParser_$42([],this.putils,0).loadJson(new hxjsonast_Json(hxjsonast_JsonValue.JNull,new hxjsonast_Position("",0,1))), clients : new JsonParser_$47([],this.putils,0).loadJson(new hxjsonast_Json(hxjsonast_JsonValue.JNull,new hxjsonast_Position("",0,1))), config : new JsonParser_$58([],this.putils,0).loadJson(new hxjsonast_Json(hxjsonast_JsonValue.JNull,new hxjsonast_Position("",0,1))), globalIp : new JsonParser_$42([],this.putils,0).loadJson(new hxjsonast_Json(hxjsonast_JsonValue.JNull,new hxjsonast_Position("",0,1))), history : new JsonParser_$59([],this.putils,0).loadJson(new hxjsonast_Json(hxjsonast_JsonValue.JNull,new hxjsonast_Position("",0,1))), isPlaylistOpen : new JsonParser_$44([],this.putils,0).loadJson(new hxjsonast_Json(hxjsonast_JsonValue.JNull,new hxjsonast_Position("",0,1))), isUnknownClient : new JsonParser_$44([],this.putils,0).loadJson(new hxjsonast_Json(hxjsonast_JsonValue.JNull,new hxjsonast_Position("",0,1))), itemPos : new JsonParser_$50([],this.putils,0).loadJson(new hxjsonast_Json(hxjsonast_JsonValue.JNull,new hxjsonast_Position("",0,1))), videoList : new JsonParser_$39([],this.putils,0).loadJson(new hxjsonast_Json(hxjsonast_JsonValue.JNull,new hxjsonast_Position("",0,1)))};
	}
	,__class__: JsonParser_$7
});
var JsonParser_$71 = function(errors,putils,errorType) {
	if(errorType == null) {
		errorType = 0;
	}
	json2object_reader_BaseParser.call(this,errors,putils,errorType);
};
JsonParser_$71.__name__ = true;
JsonParser_$71.__super__ = json2object_reader_BaseParser;
JsonParser_$71.prototype = $extend(json2object_reader_BaseParser.prototype,{
	onIncorrectType: function(pos,variable) {
		this.errors.push(json2object_Error.IncorrectType(variable,"{ name : String, image : String }",pos));
		json2object_reader_BaseParser.prototype.onIncorrectType.call(this,pos,variable);
	}
	,loadJsonNull: function(pos,variable) {
		this.value = null;
	}
	,loadJsonObject: function(o,pos,variable) {
		var assigned = new haxe_ds_StringMap();
		this.objectSetupAssign(assigned,["image","name"],[false,false]);
		this.value = this.getAuto();
		var _g = 0;
		while(_g < o.length) {
			var field = o[_g];
			++_g;
			switch(field.name) {
			case "image":
				this.value.image = this.loadObjectField(($_=new JsonParser_$42(this.errors,this.putils,1),$bind($_,$_.loadJson)),field,"image",assigned,this.value.image,pos);
				break;
			case "name":
				this.value.name = this.loadObjectField(($_=new JsonParser_$42(this.errors,this.putils,1),$bind($_,$_.loadJson)),field,"name",assigned,this.value.name,pos);
				break;
			default:
				this.errors.push(json2object_Error.UnknownVariable(field.name,this.putils.convertPosition(field.namePos)));
			}
		}
		this.objectErrors(assigned,pos);
	}
	,getAuto: function() {
		return { image : new JsonParser_$42([],this.putils,0).loadJson(new hxjsonast_Json(hxjsonast_JsonValue.JNull,new hxjsonast_Position("",0,1))), name : new JsonParser_$42([],this.putils,0).loadJson(new hxjsonast_Json(hxjsonast_JsonValue.JNull,new hxjsonast_Position("",0,1)))};
	}
	,__class__: JsonParser_$71
});
var JsonParser_$9 = function(errors,putils,errorType) {
	if(errorType == null) {
		errorType = 0;
	}
	json2object_reader_BaseParser.call(this,errors,putils,errorType);
};
JsonParser_$9.__name__ = true;
JsonParser_$9.__super__ = json2object_reader_BaseParser;
JsonParser_$9.prototype = $extend(json2object_reader_BaseParser.prototype,{
	onIncorrectType: function(pos,variable) {
		this.errors.push(json2object_Error.IncorrectType(variable,"{ data : String }",pos));
		json2object_reader_BaseParser.prototype.onIncorrectType.call(this,pos,variable);
	}
	,loadJsonNull: function(pos,variable) {
		this.value = null;
	}
	,loadJsonObject: function(o,pos,variable) {
		var assigned = new haxe_ds_StringMap();
		this.objectSetupAssign(assigned,["data"],[false]);
		this.value = this.getAuto();
		var _g = 0;
		while(_g < o.length) {
			var field = o[_g];
			++_g;
			if(field.name == "data") {
				this.value.data = this.loadObjectField(($_=new JsonParser_$42(this.errors,this.putils,1),$bind($_,$_.loadJson)),field,"data",assigned,this.value.data,pos);
			} else {
				this.errors.push(json2object_Error.UnknownVariable(field.name,this.putils.convertPosition(field.namePos)));
			}
		}
		this.objectErrors(assigned,pos);
	}
	,getAuto: function() {
		return { data : new JsonParser_$42([],this.putils,0).loadJson(new hxjsonast_Json(hxjsonast_JsonValue.JNull,new hxjsonast_Position("",0,1)))};
	}
	,__class__: JsonParser_$9
});
var Lambda = function() { };
Lambda.__name__ = true;
Lambda.has = function(it,elt) {
	var x = $getIterator(it);
	while(x.hasNext()) if(x.next() == elt) {
		return true;
	}
	return false;
};
Lambda.exists = function(it,f) {
	var x = $getIterator(it);
	while(x.hasNext()) if(f(x.next())) {
		return true;
	}
	return false;
};
Lambda.count = function(it,pred) {
	var n = 0;
	if(pred == null) {
		var _ = $getIterator(it);
		while(_.hasNext()) {
			_.next();
			++n;
		}
	} else {
		var x = $getIterator(it);
		while(x.hasNext()) if(pred(x.next())) {
			++n;
		}
	}
	return n;
};
Lambda.find = function(it,f) {
	var v = $getIterator(it);
	while(v.hasNext()) {
		var v1 = v.next();
		if(f(v1)) {
			return v1;
		}
	}
	return null;
};
var haxe_IMap = function() { };
haxe_IMap.__name__ = true;
haxe_IMap.__isInterface__ = true;
var haxe_ds_StringMap = function() {
	this.h = Object.create(null);
};
haxe_ds_StringMap.__name__ = true;
haxe_ds_StringMap.__interfaces__ = [haxe_IMap];
haxe_ds_StringMap.prototype = {
	__class__: haxe_ds_StringMap
};
var Lang = function() { };
Lang.__name__ = true;
Lang.request = function(path,callback) {
	callback(js_node_Fs.readFileSync(path,{ encoding : "utf8"}));
};
Lang.init = function(folderPath,callback) {
	Lang.langs.h = Object.create(null);
	var count = 0;
	var _g = 0;
	var _g1 = Lang.ids;
	while(_g < _g1.length) {
		var name = [_g1[_g]];
		++_g;
		Lang.request("" + folderPath + "/" + name[0] + ".json",(function(name) {
			return function(data) {
				var data1 = JSON.parse(data);
				var lang = new haxe_ds_StringMap();
				var _g = 0;
				var _g1 = Reflect.fields(data1);
				while(_g < _g1.length) {
					var key = _g1[_g];
					++_g;
					lang.h[key] = Reflect.field(data1,key);
				}
				var id = haxe_io_Path.withoutExtension(name[0]);
				Lang.langs.h[id] = lang;
				count += 1;
				if(count == Lang.ids.length && callback != null) {
					callback();
				}
			};
		})(name));
	}
};
Lang.get = function(lang,key) {
	if(Lang.langs.h[lang] == null) {
		lang = "en";
	}
	var text = Lang.langs.h[lang].h[key];
	if(text == null) {
		return key;
	} else {
		return text;
	}
};
Math.__name__ = true;
var Reflect = function() { };
Reflect.__name__ = true;
Reflect.field = function(o,field) {
	try {
		return o[field];
	} catch( _g ) {
		return null;
	}
};
Reflect.fields = function(o) {
	var a = [];
	if(o != null) {
		var hasOwnProperty = Object.prototype.hasOwnProperty;
		for( var f in o ) {
		if(f != "__id__" && f != "hx__closures__" && hasOwnProperty.call(o,f)) {
			a.push(f);
		}
		}
	}
	return a;
};
var Std = function() { };
Std.__name__ = true;
Std.string = function(s) {
	return js_Boot.__string_rec(s,"");
};
Std.parseInt = function(x) {
	if(x != null) {
		var _g = 0;
		var _g1 = x.length;
		while(_g < _g1) {
			var i = _g++;
			var c = x.charCodeAt(i);
			if(c <= 8 || c >= 14 && c != 32 && c != 45) {
				var nc = x.charCodeAt(i + 1);
				var v = parseInt(x,nc == 120 || nc == 88 ? 16 : 10);
				if(isNaN(v)) {
					return null;
				} else {
					return v;
				}
			}
		}
	}
	return null;
};
Std.random = function(x) {
	if(x <= 0) {
		return 0;
	} else {
		return Math.floor(Math.random() * x);
	}
};
var StringBuf = function() {
	this.b = "";
};
StringBuf.__name__ = true;
StringBuf.prototype = {
	__class__: StringBuf
};
var StringTools = function() { };
StringTools.__name__ = true;
StringTools.startsWith = function(s,start) {
	if(s.length >= start.length) {
		return s.lastIndexOf(start,0) == 0;
	} else {
		return false;
	}
};
StringTools.endsWith = function(s,end) {
	var elen = end.length;
	var slen = s.length;
	if(slen >= elen) {
		return s.indexOf(end,slen - elen) == slen - elen;
	} else {
		return false;
	}
};
StringTools.isSpace = function(s,pos) {
	var c = HxOverrides.cca(s,pos);
	if(!(c > 8 && c < 14)) {
		return c == 32;
	} else {
		return true;
	}
};
StringTools.ltrim = function(s) {
	var l = s.length;
	var r = 0;
	while(r < l && StringTools.isSpace(s,r)) ++r;
	if(r > 0) {
		return HxOverrides.substr(s,r,l - r);
	} else {
		return s;
	}
};
StringTools.rtrim = function(s) {
	var l = s.length;
	var r = 0;
	while(r < l && StringTools.isSpace(s,l - r - 1)) ++r;
	if(r > 0) {
		return HxOverrides.substr(s,0,l - r);
	} else {
		return s;
	}
};
StringTools.trim = function(s) {
	return StringTools.ltrim(StringTools.rtrim(s));
};
StringTools.lpad = function(s,c,l) {
	if(c.length <= 0) {
		return s;
	}
	var buf_b = "";
	l -= s.length;
	while(buf_b.length < l) buf_b += c == null ? "null" : "" + c;
	buf_b += s == null ? "null" : "" + s;
	return buf_b;
};
StringTools.rpad = function(s,c,l) {
	if(c.length <= 0) {
		return s;
	}
	var buf_b = "";
	buf_b = "" + (s == null ? "null" : "" + s);
	while(buf_b.length < l) buf_b += c == null ? "null" : "" + c;
	return buf_b;
};
StringTools.replace = function(s,sub,by) {
	return s.split(sub).join(by);
};
StringTools.hex = function(n,digits) {
	var s = "";
	while(true) {
		s = "0123456789ABCDEF".charAt(n & 15) + s;
		n >>>= 4;
		if(!(n > 0)) {
			break;
		}
	}
	if(digits != null) {
		while(s.length < digits) s = "0" + s;
	}
	return s;
};
var VideoList = function() {
	this.items = [];
	this.isOpen = true;
	this.pos = 0;
};
VideoList.__name__ = true;
VideoList.prototype = {
	setItems: function(items) {
		this.items.length = 0;
		this.pos = 0;
		var _g = 0;
		while(_g < items.length) this.items.push(items[_g++]);
	}
	,setPos: function(i) {
		if(i < 0 || i > this.items.length - 1) {
			i = 0;
		}
		this.pos = i;
	}
	,exists: function(f) {
		return Lambda.exists(this.items,f);
	}
	,findIndex: function(f) {
		var i = 0;
		var _g = 0;
		var _g1 = this.items;
		while(_g < _g1.length) {
			if(f(_g1[_g++])) {
				return i;
			}
			++i;
		}
		return -1;
	}
	,addItem: function(item,atEnd) {
		if(atEnd) {
			this.items.push(item);
		} else {
			this.items.splice(this.pos + 1,0,item);
		}
	}
	,setNextItem: function(nextPos) {
		var next = this.items[nextPos];
		HxOverrides.remove(this.items,next);
		if(nextPos < this.pos) {
			this.pos--;
		}
		this.items.splice(this.pos + 1,0,next);
	}
	,toggleItemType: function(pos) {
		this.items[pos].isTemp = !this.items[pos].isTemp;
	}
	,removeItem: function(index) {
		if(index < this.pos) {
			this.pos--;
		}
		HxOverrides.remove(this.items,this.items[index]);
		if(this.pos >= this.items.length) {
			this.pos = 0;
		}
	}
	,skipItem: function() {
		var item = this.items[this.pos];
		if(!item.isTemp) {
			this.pos++;
		} else {
			HxOverrides.remove(this.items,item);
		}
		if(this.pos >= this.items.length) {
			this.pos = 0;
		}
	}
	,itemsByUser: function(client) {
		var i = 0;
		var _g = 0;
		var _g1 = this.items;
		while(_g < _g1.length) if(_g1[_g++].author == client.name) {
			++i;
		}
		return i;
	}
	,shuffle: function() {
		var current = this.items[this.pos];
		HxOverrides.remove(this.items,current);
		this.shuffleArray(this.items);
		this.items.splice(this.pos,0,current);
	}
	,shuffleArray: function(arr) {
		var _g_current = 0;
		while(_g_current < arr.length) {
			var _g1_value = arr[_g_current++];
			var n = Std.random(arr.length);
			arr[_g_current - 1] = arr[n];
			arr[n] = _g1_value;
		}
	}
	,__class__: VideoList
};
var haxe_Exception = function(message,previous,native) {
	Error.call(this,message);
	this.message = message;
	this.__previousException = previous;
	this.__nativeException = native != null ? native : this;
};
haxe_Exception.__name__ = true;
haxe_Exception.caught = function(value) {
	if(((value) instanceof haxe_Exception)) {
		return value;
	} else if(((value) instanceof Error)) {
		return new haxe_Exception(value.message,null,value);
	} else {
		return new haxe_ValueException(value,null,value);
	}
};
haxe_Exception.thrown = function(value) {
	if(((value) instanceof haxe_Exception)) {
		return value.get_native();
	} else if(((value) instanceof Error)) {
		return value;
	} else {
		var e = new haxe_ValueException(value);
		return e;
	}
};
haxe_Exception.__super__ = Error;
haxe_Exception.prototype = $extend(Error.prototype,{
	unwrap: function() {
		return this.__nativeException;
	}
	,toString: function() {
		return this.get_message();
	}
	,get_message: function() {
		return this.message;
	}
	,get_native: function() {
		return this.__nativeException;
	}
	,__class__: haxe_Exception
});
var haxe_Log = function() { };
haxe_Log.__name__ = true;
haxe_Log.formatOutput = function(v,infos) {
	var str = Std.string(v);
	if(infos == null) {
		return str;
	}
	var pstr = infos.fileName + ":" + infos.lineNumber;
	if(infos.customParams != null) {
		var _g = 0;
		var _g1 = infos.customParams;
		while(_g < _g1.length) str += ", " + Std.string(_g1[_g++]);
	}
	return pstr + ": " + str;
};
haxe_Log.trace = function(v,infos) {
	var str = haxe_Log.formatOutput(v,infos);
	if(typeof(console) != "undefined" && console.log != null) {
		console.log(str);
	}
};
var haxe_Timer = function(time_ms) {
	var me = this;
	this.id = setInterval(function() {
		me.run();
	},time_ms);
};
haxe_Timer.__name__ = true;
haxe_Timer.delay = function(f,time_ms) {
	var t = new haxe_Timer(time_ms);
	t.run = function() {
		t.stop();
		f();
	};
	return t;
};
haxe_Timer.prototype = {
	stop: function() {
		if(this.id == null) {
			return;
		}
		clearInterval(this.id);
		this.id = null;
	}
	,run: function() {
	}
	,__class__: haxe_Timer
};
var haxe_ValueException = function(value,previous,native) {
	haxe_Exception.call(this,String(value),previous,native);
	this.value = value;
};
haxe_ValueException.__name__ = true;
haxe_ValueException.__super__ = haxe_Exception;
haxe_ValueException.prototype = $extend(haxe_Exception.prototype,{
	unwrap: function() {
		return this.value;
	}
	,__class__: haxe_ValueException
});
var haxe_crypto_Sha256 = function() {
};
haxe_crypto_Sha256.__name__ = true;
haxe_crypto_Sha256.encode = function(s) {
	var sh = new haxe_crypto_Sha256();
	return sh.hex(sh.doEncode(haxe_crypto_Sha256.str2blks(s),s.length * 8));
};
haxe_crypto_Sha256.str2blks = function(s) {
	var s1 = haxe_io_Bytes.ofString(s);
	var nblk = (s1.length + 8 >> 6) + 1;
	var blks = [];
	var _g = 0;
	var _g1 = nblk * 16;
	while(_g < _g1) blks[_g++] = 0;
	var _g = 0;
	var _g1 = s1.length;
	while(_g < _g1) {
		var i = _g++;
		blks[i >> 2] |= s1.b[i] << 24 - ((i & 3) << 3);
	}
	var i = s1.length;
	blks[i >> 2] |= 128 << 24 - ((i & 3) << 3);
	blks[nblk * 16 - 1] = s1.length * 8;
	return blks;
};
haxe_crypto_Sha256.prototype = {
	doEncode: function(m,l) {
		var K = [1116352408,1899447441,-1245643825,-373957723,961987163,1508970993,-1841331548,-1424204075,-670586216,310598401,607225278,1426881987,1925078388,-2132889090,-1680079193,-1046744716,-459576895,-272742522,264347078,604807628,770255983,1249150122,1555081692,1996064986,-1740746414,-1473132947,-1341970488,-1084653625,-958395405,-710438585,113926993,338241895,666307205,773529912,1294757372,1396182291,1695183700,1986661051,-2117940946,-1838011259,-1564481375,-1474664885,-1035236496,-949202525,-778901479,-694614492,-200395387,275423344,430227734,506948616,659060556,883997877,958139571,1322822218,1537002063,1747873779,1955562222,2024104815,-2067236844,-1933114872,-1866530822,-1538233109,-1090935817,-965641998];
		var HASH = [1779033703,-1150833019,1013904242,-1521486534,1359893119,-1694144372,528734635,1541459225];
		var W = [];
		W[64] = 0;
		var a;
		var b;
		var c;
		var d;
		var e;
		var f;
		var g;
		var h;
		var T1;
		var T2;
		m[l >> 5] |= 128 << 24 - l % 32;
		m[(l + 64 >> 9 << 4) + 15] = l;
		var i = 0;
		while(i < m.length) {
			a = HASH[0];
			b = HASH[1];
			c = HASH[2];
			d = HASH[3];
			e = HASH[4];
			f = HASH[5];
			g = HASH[6];
			h = HASH[7];
			var _g = 0;
			while(_g < 64) {
				var j = _g++;
				if(j < 16) {
					W[j] = m[j + i];
				} else {
					var x = W[j - 2];
					var x1 = (x >>> 17 | x << 15) ^ (x >>> 19 | x << 13) ^ x >>> 10;
					var y = W[j - 7];
					var lsw = (x1 & 65535) + (y & 65535);
					var x2 = (x1 >> 16) + (y >> 16) + (lsw >> 16) << 16 | lsw & 65535;
					var x3 = W[j - 15];
					var y1 = (x3 >>> 7 | x3 << 25) ^ (x3 >>> 18 | x3 << 14) ^ x3 >>> 3;
					var lsw1 = (x2 & 65535) + (y1 & 65535);
					var x4 = (x2 >> 16) + (y1 >> 16) + (lsw1 >> 16) << 16 | lsw1 & 65535;
					var y2 = W[j - 16];
					var lsw2 = (x4 & 65535) + (y2 & 65535);
					W[j] = (x4 >> 16) + (y2 >> 16) + (lsw2 >> 16) << 16 | lsw2 & 65535;
				}
				var y3 = (e >>> 6 | e << 26) ^ (e >>> 11 | e << 21) ^ (e >>> 25 | e << 7);
				var lsw3 = (h & 65535) + (y3 & 65535);
				var x5 = (h >> 16) + (y3 >> 16) + (lsw3 >> 16) << 16 | lsw3 & 65535;
				var y4 = e & f ^ ~e & g;
				var lsw4 = (x5 & 65535) + (y4 & 65535);
				var x6 = (x5 >> 16) + (y4 >> 16) + (lsw4 >> 16) << 16 | lsw4 & 65535;
				var y5 = K[j];
				var lsw5 = (x6 & 65535) + (y5 & 65535);
				var x7 = (x6 >> 16) + (y5 >> 16) + (lsw5 >> 16) << 16 | lsw5 & 65535;
				var y6 = W[j];
				var lsw6 = (x7 & 65535) + (y6 & 65535);
				T1 = (x7 >> 16) + (y6 >> 16) + (lsw6 >> 16) << 16 | lsw6 & 65535;
				var x8 = (a >>> 2 | a << 30) ^ (a >>> 13 | a << 19) ^ (a >>> 22 | a << 10);
				var y7 = a & b ^ a & c ^ b & c;
				var lsw7 = (x8 & 65535) + (y7 & 65535);
				T2 = (x8 >> 16) + (y7 >> 16) + (lsw7 >> 16) << 16 | lsw7 & 65535;
				h = g;
				g = f;
				f = e;
				var lsw8 = (d & 65535) + (T1 & 65535);
				e = (d >> 16) + (T1 >> 16) + (lsw8 >> 16) << 16 | lsw8 & 65535;
				d = c;
				c = b;
				b = a;
				var lsw9 = (T1 & 65535) + (T2 & 65535);
				a = (T1 >> 16) + (T2 >> 16) + (lsw9 >> 16) << 16 | lsw9 & 65535;
			}
			var y8 = HASH[0];
			var lsw10 = (a & 65535) + (y8 & 65535);
			HASH[0] = (a >> 16) + (y8 >> 16) + (lsw10 >> 16) << 16 | lsw10 & 65535;
			var y9 = HASH[1];
			var lsw11 = (b & 65535) + (y9 & 65535);
			HASH[1] = (b >> 16) + (y9 >> 16) + (lsw11 >> 16) << 16 | lsw11 & 65535;
			var y10 = HASH[2];
			var lsw12 = (c & 65535) + (y10 & 65535);
			HASH[2] = (c >> 16) + (y10 >> 16) + (lsw12 >> 16) << 16 | lsw12 & 65535;
			var y11 = HASH[3];
			var lsw13 = (d & 65535) + (y11 & 65535);
			HASH[3] = (d >> 16) + (y11 >> 16) + (lsw13 >> 16) << 16 | lsw13 & 65535;
			var y12 = HASH[4];
			var lsw14 = (e & 65535) + (y12 & 65535);
			HASH[4] = (e >> 16) + (y12 >> 16) + (lsw14 >> 16) << 16 | lsw14 & 65535;
			var y13 = HASH[5];
			var lsw15 = (f & 65535) + (y13 & 65535);
			HASH[5] = (f >> 16) + (y13 >> 16) + (lsw15 >> 16) << 16 | lsw15 & 65535;
			var y14 = HASH[6];
			var lsw16 = (g & 65535) + (y14 & 65535);
			HASH[6] = (g >> 16) + (y14 >> 16) + (lsw16 >> 16) << 16 | lsw16 & 65535;
			var y15 = HASH[7];
			var lsw17 = (h & 65535) + (y15 & 65535);
			HASH[7] = (h >> 16) + (y15 >> 16) + (lsw17 >> 16) << 16 | lsw17 & 65535;
			i += 16;
		}
		return HASH;
	}
	,hex: function(a) {
		var str = "";
		var _g = 0;
		while(_g < a.length) str += StringTools.hex(a[_g++],8);
		return str.toLowerCase();
	}
	,__class__: haxe_crypto_Sha256
};
var haxe_exceptions_PosException = function(message,previous,pos) {
	haxe_Exception.call(this,message,previous);
	if(pos == null) {
		this.posInfos = { fileName : "(unknown)", lineNumber : 0, className : "(unknown)", methodName : "(unknown)"};
	} else {
		this.posInfos = pos;
	}
};
haxe_exceptions_PosException.__name__ = true;
haxe_exceptions_PosException.__super__ = haxe_Exception;
haxe_exceptions_PosException.prototype = $extend(haxe_Exception.prototype,{
	toString: function() {
		return "" + haxe_Exception.prototype.toString.call(this) + " in " + this.posInfos.className + "." + this.posInfos.methodName + " at " + this.posInfos.fileName + ":" + this.posInfos.lineNumber;
	}
	,__class__: haxe_exceptions_PosException
});
var haxe_exceptions_NotImplementedException = function(message,previous,pos) {
	if(message == null) {
		message = "Not implemented";
	}
	haxe_exceptions_PosException.call(this,message,previous,pos);
};
haxe_exceptions_NotImplementedException.__name__ = true;
haxe_exceptions_NotImplementedException.__super__ = haxe_exceptions_PosException;
haxe_exceptions_NotImplementedException.prototype = $extend(haxe_exceptions_PosException.prototype,{
	__class__: haxe_exceptions_NotImplementedException
});
var haxe_io_Bytes = function(data) {
	this.length = data.byteLength;
	this.b = new Uint8Array(data);
	this.b.bufferValue = data;
	data.hxBytes = this;
	data.bytes = this.b;
};
haxe_io_Bytes.__name__ = true;
haxe_io_Bytes.ofString = function(s,encoding) {
	if(encoding == haxe_io_Encoding.RawNative) {
		var buf = new Uint8Array(s.length << 1);
		var _g = 0;
		var _g1 = s.length;
		while(_g < _g1) {
			var i = _g++;
			var c = s.charCodeAt(i);
			buf[i << 1] = c & 255;
			buf[i << 1 | 1] = c >> 8;
		}
		return new haxe_io_Bytes(buf.buffer);
	}
	var a = [];
	var i = 0;
	while(i < s.length) {
		var c = s.charCodeAt(i++);
		if(55296 <= c && c <= 56319) {
			c = c - 55232 << 10 | s.charCodeAt(i++) & 1023;
		}
		if(c <= 127) {
			a.push(c);
		} else if(c <= 2047) {
			a.push(192 | c >> 6);
			a.push(128 | c & 63);
		} else if(c <= 65535) {
			a.push(224 | c >> 12);
			a.push(128 | c >> 6 & 63);
			a.push(128 | c & 63);
		} else {
			a.push(240 | c >> 18);
			a.push(128 | c >> 12 & 63);
			a.push(128 | c >> 6 & 63);
			a.push(128 | c & 63);
		}
	}
	return new haxe_io_Bytes(new Uint8Array(a).buffer);
};
haxe_io_Bytes.prototype = {
	__class__: haxe_io_Bytes
};
var haxe_io_Encoding = $hxEnums["haxe.io.Encoding"] = { __ename__:true,__constructs__:null
	,UTF8: {_hx_name:"UTF8",_hx_index:0,__enum__:"haxe.io.Encoding",toString:$estr}
	,RawNative: {_hx_name:"RawNative",_hx_index:1,__enum__:"haxe.io.Encoding",toString:$estr}
};
haxe_io_Encoding.__constructs__ = [haxe_io_Encoding.UTF8,haxe_io_Encoding.RawNative];
var haxe_io_Path = function(path) {
	switch(path) {
	case ".":case "..":
		this.dir = path;
		this.file = "";
		return;
	}
	var c1 = path.lastIndexOf("/");
	var c2 = path.lastIndexOf("\\");
	if(c1 < c2) {
		this.dir = HxOverrides.substr(path,0,c2);
		path = HxOverrides.substr(path,c2 + 1,null);
		this.backslash = true;
	} else if(c2 < c1) {
		this.dir = HxOverrides.substr(path,0,c1);
		path = HxOverrides.substr(path,c1 + 1,null);
	} else {
		this.dir = null;
	}
	var cp = path.lastIndexOf(".");
	if(cp != -1) {
		this.ext = HxOverrides.substr(path,cp + 1,null);
		this.file = HxOverrides.substr(path,0,cp);
	} else {
		this.ext = null;
		this.file = path;
	}
};
haxe_io_Path.__name__ = true;
haxe_io_Path.withoutExtension = function(path) {
	var s = new haxe_io_Path(path);
	s.ext = null;
	return s.toString();
};
haxe_io_Path.extension = function(path) {
	var s = new haxe_io_Path(path);
	if(s.ext == null) {
		return "";
	}
	return s.ext;
};
haxe_io_Path.normalize = function(path) {
	var slash = "/";
	path = path.split("\\").join(slash);
	if(path == slash) {
		return slash;
	}
	var target = [];
	var _g = 0;
	var _g1 = path.split(slash);
	while(_g < _g1.length) {
		var token = _g1[_g];
		++_g;
		if(token == ".." && target.length > 0 && target[target.length - 1] != "..") {
			target.pop();
		} else if(token == "") {
			if(target.length > 0 || HxOverrides.cca(path,0) == 47) {
				target.push(token);
			}
		} else if(token != ".") {
			target.push(token);
		}
	}
	var acc_b = "";
	var colon = false;
	var slashes = false;
	var _g2_offset = 0;
	var _g2_s = target.join(slash);
	while(_g2_offset < _g2_s.length) {
		var s = _g2_s;
		var index = _g2_offset++;
		var c = s.charCodeAt(index);
		if(c >= 55296 && c <= 56319) {
			c = c - 55232 << 10 | s.charCodeAt(index + 1) & 1023;
		}
		var c1 = c;
		if(c1 >= 65536) {
			++_g2_offset;
		}
		var c2 = c1;
		switch(c2) {
		case 47:
			if(!colon) {
				slashes = true;
			} else {
				var i = c2;
				colon = false;
				if(slashes) {
					acc_b += "/";
					slashes = false;
				}
				acc_b += String.fromCodePoint(i);
			}
			break;
		case 58:
			acc_b += ":";
			colon = true;
			break;
		default:
			var i1 = c2;
			colon = false;
			if(slashes) {
				acc_b += "/";
				slashes = false;
			}
			acc_b += String.fromCodePoint(i1);
		}
	}
	return acc_b;
};
haxe_io_Path.addTrailingSlash = function(path) {
	if(path.length == 0) {
		return "/";
	}
	var c1 = path.lastIndexOf("/");
	var c2 = path.lastIndexOf("\\");
	if(c1 < c2) {
		if(c2 != path.length - 1) {
			return path + "\\";
		} else {
			return path;
		}
	} else if(c1 != path.length - 1) {
		return path + "/";
	} else {
		return path;
	}
};
haxe_io_Path.prototype = {
	toString: function() {
		return (this.dir == null ? "" : this.dir + (this.backslash ? "\\" : "/")) + this.file + (this.ext == null ? "" : "." + this.ext);
	}
	,__class__: haxe_io_Path
};
var haxe_iterators_ArrayIterator = function(array) {
	this.current = 0;
	this.array = array;
};
haxe_iterators_ArrayIterator.__name__ = true;
haxe_iterators_ArrayIterator.prototype = {
	hasNext: function() {
		return this.current < this.array.length;
	}
	,next: function() {
		return this.array[this.current++];
	}
	,__class__: haxe_iterators_ArrayIterator
};
var hxjsonast_Error = function(message,pos) {
	this.message = message;
	this.pos = pos;
};
hxjsonast_Error.__name__ = true;
hxjsonast_Error.prototype = {
	__class__: hxjsonast_Error
};
var hxjsonast_Json = function(value,pos) {
	this.value = value;
	this.pos = pos;
};
hxjsonast_Json.__name__ = true;
hxjsonast_Json.prototype = {
	__class__: hxjsonast_Json
};
var hxjsonast_JsonValue = $hxEnums["hxjsonast.JsonValue"] = { __ename__:true,__constructs__:null
	,JString: ($_=function(s) { return {_hx_index:0,s:s,__enum__:"hxjsonast.JsonValue",toString:$estr}; },$_._hx_name="JString",$_.__params__ = ["s"],$_)
	,JNumber: ($_=function(s) { return {_hx_index:1,s:s,__enum__:"hxjsonast.JsonValue",toString:$estr}; },$_._hx_name="JNumber",$_.__params__ = ["s"],$_)
	,JObject: ($_=function(fields) { return {_hx_index:2,fields:fields,__enum__:"hxjsonast.JsonValue",toString:$estr}; },$_._hx_name="JObject",$_.__params__ = ["fields"],$_)
	,JArray: ($_=function(values) { return {_hx_index:3,values:values,__enum__:"hxjsonast.JsonValue",toString:$estr}; },$_._hx_name="JArray",$_.__params__ = ["values"],$_)
	,JBool: ($_=function(b) { return {_hx_index:4,b:b,__enum__:"hxjsonast.JsonValue",toString:$estr}; },$_._hx_name="JBool",$_.__params__ = ["b"],$_)
	,JNull: {_hx_name:"JNull",_hx_index:5,__enum__:"hxjsonast.JsonValue",toString:$estr}
};
hxjsonast_JsonValue.__constructs__ = [hxjsonast_JsonValue.JString,hxjsonast_JsonValue.JNumber,hxjsonast_JsonValue.JObject,hxjsonast_JsonValue.JArray,hxjsonast_JsonValue.JBool,hxjsonast_JsonValue.JNull];
var hxjsonast_JObjectField = function(name,namePos,value) {
	this.name = name;
	this.namePos = namePos;
	this.value = value;
};
hxjsonast_JObjectField.__name__ = true;
hxjsonast_JObjectField.prototype = {
	__class__: hxjsonast_JObjectField
};
var hxjsonast_Parser = function(source,filename) {
	this.source = source;
	this.filename = filename;
	this.pos = 0;
};
hxjsonast_Parser.__name__ = true;
hxjsonast_Parser.prototype = {
	doParse: function() {
		var result = this.parseRec();
		var c;
		while(true) {
			c = this.source.charCodeAt(this.pos++);
			if(!(c == c)) {
				break;
			}
			switch(c) {
			case 9:case 10:case 13:case 32:
				break;
			default:
				this.invalidChar();
			}
		}
		return result;
	}
	,parseRec: function() {
		while(true) {
			var c = this.source.charCodeAt(this.pos++);
			switch(c) {
			case 9:case 10:case 13:case 32:
				break;
			case 34:
				var save = this.pos;
				return new hxjsonast_Json(hxjsonast_JsonValue.JString(this.parseString()),new hxjsonast_Position(this.filename,save - 1,this.pos));
			case 45:case 48:case 49:case 50:case 51:case 52:case 53:case 54:case 55:case 56:case 57:
				var start = this.pos - 1;
				var minus = c == 45;
				var digit = !minus;
				var zero = c == 48;
				var point = false;
				var e = false;
				var pm = false;
				var end = false;
				while(true) {
					switch(this.source.charCodeAt(this.pos++)) {
					case 43:case 45:
						if(!e || pm) {
							this.invalidNumber(start);
						}
						digit = false;
						pm = true;
						break;
					case 46:
						if(minus || point || e) {
							this.invalidNumber(start);
						}
						digit = false;
						point = true;
						break;
					case 48:
						if(zero && !point) {
							this.invalidNumber(start);
						}
						if(minus) {
							minus = false;
							zero = true;
						}
						digit = true;
						break;
					case 49:case 50:case 51:case 52:case 53:case 54:case 55:case 56:case 57:
						if(zero && !point) {
							this.invalidNumber(start);
						}
						if(minus) {
							minus = false;
						}
						digit = true;
						zero = false;
						break;
					case 69:case 101:
						if(minus || zero || e) {
							this.invalidNumber(start);
						}
						digit = false;
						e = true;
						break;
					default:
						if(!digit) {
							this.invalidNumber(start);
						}
						this.pos--;
						end = true;
					}
					if(end) {
						break;
					}
				}
				return new hxjsonast_Json(hxjsonast_JsonValue.JNumber(HxOverrides.substr(this.source,start,this.pos - start)),new hxjsonast_Position(this.filename,start,this.pos));
			case 91:
				var values = [];
				var comma = null;
				var startPos = this.pos - 1;
				while(true) switch(this.source.charCodeAt(this.pos++)) {
				case 9:case 10:case 13:case 32:
					break;
				case 44:
					if(comma) {
						comma = false;
					} else {
						this.invalidChar();
					}
					break;
				case 93:
					if(comma == false) {
						this.invalidChar();
					}
					return new hxjsonast_Json(hxjsonast_JsonValue.JArray(values),new hxjsonast_Position(this.filename,startPos,this.pos));
				default:
					if(comma) {
						this.invalidChar();
					}
					this.pos--;
					values.push(this.parseRec());
					comma = true;
				}
				break;
			case 102:
				var save1 = this.pos;
				if(this.source.charCodeAt(this.pos++) != 97 || this.source.charCodeAt(this.pos++) != 108 || this.source.charCodeAt(this.pos++) != 115 || this.source.charCodeAt(this.pos++) != 101) {
					this.pos = save1;
					this.invalidChar();
				}
				return new hxjsonast_Json(hxjsonast_JsonValue.JBool(false),new hxjsonast_Position(this.filename,save1 - 1,this.pos));
			case 110:
				var save2 = this.pos;
				if(this.source.charCodeAt(this.pos++) != 117 || this.source.charCodeAt(this.pos++) != 108 || this.source.charCodeAt(this.pos++) != 108) {
					this.pos = save2;
					this.invalidChar();
				}
				return new hxjsonast_Json(hxjsonast_JsonValue.JNull,new hxjsonast_Position(this.filename,save2 - 1,this.pos));
			case 116:
				var save3 = this.pos;
				if(this.source.charCodeAt(this.pos++) != 114 || this.source.charCodeAt(this.pos++) != 117 || this.source.charCodeAt(this.pos++) != 101) {
					this.pos = save3;
					this.invalidChar();
				}
				return new hxjsonast_Json(hxjsonast_JsonValue.JBool(true),new hxjsonast_Position(this.filename,save3 - 1,this.pos));
			case 123:
				var fields = [];
				var names_h = Object.create(null);
				var field = null;
				var fieldPos = null;
				var comma1 = null;
				var startPos1 = this.pos - 1;
				while(true) switch(this.source.charCodeAt(this.pos++)) {
				case 9:case 10:case 13:case 32:
					break;
				case 34:
					if(field != null || comma1) {
						this.invalidChar();
					}
					var fieldStartPos = this.pos - 1;
					field = this.parseString();
					fieldPos = new hxjsonast_Position(this.filename,fieldStartPos,this.pos);
					if(Object.prototype.hasOwnProperty.call(names_h,field)) {
						throw haxe_Exception.thrown(new hxjsonast_Error("Duplicate field name \"" + field + "\"",fieldPos));
					} else {
						names_h[field] = true;
					}
					break;
				case 44:
					if(comma1) {
						comma1 = false;
					} else {
						this.invalidChar();
					}
					break;
				case 58:
					if(field == null) {
						this.invalidChar();
					}
					fields.push(new hxjsonast_JObjectField(field,fieldPos,this.parseRec()));
					field = null;
					fieldPos = null;
					comma1 = true;
					break;
				case 125:
					if(field != null || comma1 == false) {
						this.invalidChar();
					}
					return new hxjsonast_Json(hxjsonast_JsonValue.JObject(fields),new hxjsonast_Position(this.filename,startPos1,this.pos));
				default:
					this.invalidChar();
				}
				break;
			default:
				this.invalidChar();
			}
		}
	}
	,parseString: function() {
		var start = this.pos;
		var buf = null;
		while(true) {
			var c = this.source.charCodeAt(this.pos++);
			if(c == 34) {
				break;
			}
			if(c == 92) {
				if(buf == null) {
					buf = new StringBuf();
				}
				var s = this.source;
				var len = this.pos - start - 1;
				buf.b += len == null ? HxOverrides.substr(s,start,null) : HxOverrides.substr(s,start,len);
				c = this.source.charCodeAt(this.pos++);
				switch(c) {
				case 34:case 47:case 92:
					buf.b += String.fromCodePoint(c);
					break;
				case 98:
					buf.b += String.fromCodePoint(8);
					break;
				case 102:
					buf.b += String.fromCodePoint(12);
					break;
				case 110:
					buf.b += String.fromCodePoint(10);
					break;
				case 114:
					buf.b += String.fromCodePoint(13);
					break;
				case 116:
					buf.b += String.fromCodePoint(9);
					break;
				case 117:
					var uc = Std.parseInt("0x" + HxOverrides.substr(this.source,this.pos,4));
					this.pos += 4;
					buf.b += String.fromCodePoint(uc);
					break;
				default:
					throw haxe_Exception.thrown(new hxjsonast_Error("Invalid escape sequence \\" + String.fromCodePoint(c),new hxjsonast_Position(this.filename,this.pos - 2,this.pos)));
				}
				start = this.pos;
			} else if(c != c) {
				this.pos--;
				throw haxe_Exception.thrown(new hxjsonast_Error("Unclosed string",new hxjsonast_Position(this.filename,start - 1,this.pos)));
			}
		}
		if(buf == null) {
			return HxOverrides.substr(this.source,start,this.pos - start - 1);
		} else {
			var s = this.source;
			var len = this.pos - start - 1;
			buf.b += len == null ? HxOverrides.substr(s,start,null) : HxOverrides.substr(s,start,len);
			return buf.b;
		}
	}
	,invalidChar: function() {
		this.pos--;
		throw haxe_Exception.thrown(new hxjsonast_Error("Invalid character: " + this.source.charAt(this.pos),new hxjsonast_Position(this.filename,this.pos,this.pos + 1)));
	}
	,invalidNumber: function(start) {
		throw haxe_Exception.thrown(new hxjsonast_Error("Invalid number: " + this.source.substring(start,this.pos),new hxjsonast_Position(this.filename,start,this.pos)));
	}
	,__class__: hxjsonast_Parser
};
var hxjsonast_Position = function(file,min,max) {
	this.file = file;
	this.min = min;
	this.max = max;
};
hxjsonast_Position.__name__ = true;
hxjsonast_Position.prototype = {
	__class__: hxjsonast_Position
};
var js_Boot = function() { };
js_Boot.__name__ = true;
js_Boot.getClass = function(o) {
	if(o == null) {
		return null;
	} else if(((o) instanceof Array)) {
		return Array;
	} else {
		var cl = o.__class__;
		if(cl != null) {
			return cl;
		}
		var name = js_Boot.__nativeClassName(o);
		if(name != null) {
			return js_Boot.__resolveNativeClass(name);
		}
		return null;
	}
};
js_Boot.__string_rec = function(o,s) {
	if(o == null) {
		return "null";
	}
	if(s.length >= 5) {
		return "<...>";
	}
	var t = typeof(o);
	if(t == "function" && (o.__name__ || o.__ename__)) {
		t = "object";
	}
	switch(t) {
	case "function":
		return "<function>";
	case "object":
		if(o.__enum__) {
			var e = $hxEnums[o.__enum__];
			var con = e.__constructs__[o._hx_index];
			var n = con._hx_name;
			if(con.__params__) {
				s = s + "\t";
				return n + "(" + ((function($this) {
					var $r;
					var _g = [];
					{
						var _g1 = 0;
						var _g2 = con.__params__;
						while(true) {
							if(!(_g1 < _g2.length)) {
								break;
							}
							var p = _g2[_g1];
							_g1 = _g1 + 1;
							_g.push(js_Boot.__string_rec(o[p],s));
						}
					}
					$r = _g;
					return $r;
				}(this))).join(",") + ")";
			} else {
				return n;
			}
		}
		if(((o) instanceof Array)) {
			var str = "[";
			s += "\t";
			var _g = 0;
			var _g1 = o.length;
			while(_g < _g1) {
				var i = _g++;
				str += (i > 0 ? "," : "") + js_Boot.__string_rec(o[i],s);
			}
			str += "]";
			return str;
		}
		var tostr;
		try {
			tostr = o.toString;
		} catch( _g ) {
			return "???";
		}
		if(tostr != null && tostr != Object.toString && typeof(tostr) == "function") {
			var s2 = o.toString();
			if(s2 != "[object Object]") {
				return s2;
			}
		}
		var str = "{\n";
		s += "\t";
		var hasp = o.hasOwnProperty != null;
		var k = null;
		for( k in o ) {
		if(hasp && !o.hasOwnProperty(k)) {
			continue;
		}
		if(k == "prototype" || k == "__class__" || k == "__super__" || k == "__interfaces__" || k == "__properties__") {
			continue;
		}
		if(str.length != 2) {
			str += ", \n";
		}
		str += s + k + " : " + js_Boot.__string_rec(o[k],s);
		}
		s = s.substring(1);
		str += "\n" + s + "}";
		return str;
	case "string":
		return o;
	default:
		return String(o);
	}
};
js_Boot.__interfLoop = function(cc,cl) {
	while(true) {
		if(cc == null) {
			return false;
		}
		if(cc == cl) {
			return true;
		}
		var intf = cc.__interfaces__;
		if(intf != null) {
			var _g = 0;
			var _g1 = intf.length;
			while(_g < _g1) {
				var i = intf[_g++];
				if(i == cl || js_Boot.__interfLoop(i,cl)) {
					return true;
				}
			}
		}
		cc = cc.__super__;
	}
};
js_Boot.__instanceof = function(o,cl) {
	if(cl == null) {
		return false;
	}
	switch(cl) {
	case Array:
		return ((o) instanceof Array);
	case Bool:
		return typeof(o) == "boolean";
	case Dynamic:
		return o != null;
	case Float:
		return typeof(o) == "number";
	case Int:
		if(typeof(o) == "number") {
			return ((o | 0) === o);
		} else {
			return false;
		}
		break;
	case String:
		return typeof(o) == "string";
	default:
		if(o != null) {
			if(typeof(cl) == "function") {
				if(js_Boot.__downcastCheck(o,cl)) {
					return true;
				}
			} else if(typeof(cl) == "object" && js_Boot.__isNativeObj(cl)) {
				if(((o) instanceof cl)) {
					return true;
				}
			}
		} else {
			return false;
		}
		if(cl == Class ? o.__name__ != null : false) {
			return true;
		}
		if(cl == Enum ? o.__ename__ != null : false) {
			return true;
		}
		return o.__enum__ != null ? $hxEnums[o.__enum__] == cl : false;
	}
};
js_Boot.__downcastCheck = function(o,cl) {
	if(!((o) instanceof cl)) {
		if(cl.__isInterface__) {
			return js_Boot.__interfLoop(js_Boot.getClass(o),cl);
		} else {
			return false;
		}
	} else {
		return true;
	}
};
js_Boot.__nativeClassName = function(o) {
	var name = js_Boot.__toStr.call(o).slice(8,-1);
	if(name == "Object" || name == "Function" || name == "Math" || name == "JSON") {
		return null;
	}
	return name;
};
js_Boot.__isNativeObj = function(o) {
	return js_Boot.__nativeClassName(o) != null;
};
js_Boot.__resolveNativeClass = function(name) {
	return $global[name];
};
var js_node_Fs = require("fs");
var js_node_Http = require("http");
var js_node_Https = require("https");
var js_node_Os = require("os");
var js_node_Path = require("path");
var js_node_Readline = require("readline");
var js_node_url_URL = require("url").URL;
var js_npm_ws_Server = require("ws").Server;
var json2object_Error = $hxEnums["json2object.Error"] = { __ename__:true,__constructs__:null
	,IncorrectType: ($_=function(variable,expected,pos) { return {_hx_index:0,variable:variable,expected:expected,pos:pos,__enum__:"json2object.Error",toString:$estr}; },$_._hx_name="IncorrectType",$_.__params__ = ["variable","expected","pos"],$_)
	,IncorrectEnumValue: ($_=function(value,expected,pos) { return {_hx_index:1,value:value,expected:expected,pos:pos,__enum__:"json2object.Error",toString:$estr}; },$_._hx_name="IncorrectEnumValue",$_.__params__ = ["value","expected","pos"],$_)
	,InvalidEnumConstructor: ($_=function(value,expected,pos) { return {_hx_index:2,value:value,expected:expected,pos:pos,__enum__:"json2object.Error",toString:$estr}; },$_._hx_name="InvalidEnumConstructor",$_.__params__ = ["value","expected","pos"],$_)
	,UninitializedVariable: ($_=function(variable,pos) { return {_hx_index:3,variable:variable,pos:pos,__enum__:"json2object.Error",toString:$estr}; },$_._hx_name="UninitializedVariable",$_.__params__ = ["variable","pos"],$_)
	,UnknownVariable: ($_=function(variable,pos) { return {_hx_index:4,variable:variable,pos:pos,__enum__:"json2object.Error",toString:$estr}; },$_._hx_name="UnknownVariable",$_.__params__ = ["variable","pos"],$_)
	,ParserError: ($_=function(message,pos) { return {_hx_index:5,message:message,pos:pos,__enum__:"json2object.Error",toString:$estr}; },$_._hx_name="ParserError",$_.__params__ = ["message","pos"],$_)
	,CustomFunctionException: ($_=function(e,pos) { return {_hx_index:6,e:e,pos:pos,__enum__:"json2object.Error",toString:$estr}; },$_._hx_name="CustomFunctionException",$_.__params__ = ["e","pos"],$_)
};
json2object_Error.__constructs__ = [json2object_Error.IncorrectType,json2object_Error.IncorrectEnumValue,json2object_Error.InvalidEnumConstructor,json2object_Error.UninitializedVariable,json2object_Error.UnknownVariable,json2object_Error.ParserError,json2object_Error.CustomFunctionException];
var json2object_InternalError = $hxEnums["json2object.InternalError"] = { __ename__:true,__constructs__:null
	,AbstractNoJsonRepresentation: ($_=function(name) { return {_hx_index:0,name:name,__enum__:"json2object.InternalError",toString:$estr}; },$_._hx_name="AbstractNoJsonRepresentation",$_.__params__ = ["name"],$_)
	,CannotGenerateSchema: ($_=function(name) { return {_hx_index:1,name:name,__enum__:"json2object.InternalError",toString:$estr}; },$_._hx_name="CannotGenerateSchema",$_.__params__ = ["name"],$_)
	,HandleExpr: {_hx_name:"HandleExpr",_hx_index:2,__enum__:"json2object.InternalError",toString:$estr}
	,ParsingThrow: {_hx_name:"ParsingThrow",_hx_index:3,__enum__:"json2object.InternalError",toString:$estr}
	,UnsupportedAbstractEnumType: ($_=function(name) { return {_hx_index:4,name:name,__enum__:"json2object.InternalError",toString:$estr}; },$_._hx_name="UnsupportedAbstractEnumType",$_.__params__ = ["name"],$_)
	,UnsupportedEnumAbstractValue: ($_=function(name) { return {_hx_index:5,name:name,__enum__:"json2object.InternalError",toString:$estr}; },$_._hx_name="UnsupportedEnumAbstractValue",$_.__params__ = ["name"],$_)
	,UnsupportedMapKeyType: ($_=function(name) { return {_hx_index:6,name:name,__enum__:"json2object.InternalError",toString:$estr}; },$_._hx_name="UnsupportedMapKeyType",$_.__params__ = ["name"],$_)
	,UnsupportedSchemaObjectType: ($_=function(name) { return {_hx_index:7,name:name,__enum__:"json2object.InternalError",toString:$estr}; },$_._hx_name="UnsupportedSchemaObjectType",$_.__params__ = ["name"],$_)
	,UnsupportedSchemaType: ($_=function(type) { return {_hx_index:8,type:type,__enum__:"json2object.InternalError",toString:$estr}; },$_._hx_name="UnsupportedSchemaType",$_.__params__ = ["type"],$_)
};
json2object_InternalError.__constructs__ = [json2object_InternalError.AbstractNoJsonRepresentation,json2object_InternalError.CannotGenerateSchema,json2object_InternalError.HandleExpr,json2object_InternalError.ParsingThrow,json2object_InternalError.UnsupportedAbstractEnumType,json2object_InternalError.UnsupportedEnumAbstractValue,json2object_InternalError.UnsupportedMapKeyType,json2object_InternalError.UnsupportedSchemaObjectType,json2object_InternalError.UnsupportedSchemaType];
var json2object_ErrorUtils = function() { };
json2object_ErrorUtils.__name__ = true;
json2object_ErrorUtils.convertError = function(e) {
	var pos;
	switch(e._hx_index) {
	case 0:
		pos = e.pos;
		break;
	case 1:
		pos = e.pos;
		break;
	case 2:
		pos = e.pos;
		break;
	case 3:
		pos = e.pos;
		break;
	case 4:
		pos = e.pos;
		break;
	case 5:
		pos = e.pos;
		break;
	case 6:
		pos = e.pos;
		break;
	}
	var header = "";
	if(pos != null) {
		var file = pos.file == "" ? "line" : "" + pos.file + ":";
		if(pos.lines.length == 1) {
			header = "" + file + pos.lines[0].number + ": characters " + pos.lines[0].start + "-" + pos.lines[0].end + " : ";
		} else if(pos.lines.length > 1) {
			header = "" + file + pos.lines[0].number + ": lines " + pos.lines[0].number + "-" + pos.lines[pos.lines.length - 1].number + " : ";
		}
	}
	switch(e._hx_index) {
	case 0:
		return header + ("Variable '" + e.variable + "' should be of type '" + e.expected + "'");
	case 1:
		return header + ("Identifier '" + e.value + "' isn't part of '" + e.expected + "'");
	case 2:
		return header + ("Enum argument '" + e.value + "' should be of type '" + e.expected + "'");
	case 3:
		return header + ("Variable '" + e.variable + "' should be in the json");
	case 4:
		return header + ("Variable '" + e.variable + "' isn't part of the schema");
	case 5:
		return header + ("Parser error: " + e.message);
	case 6:
		var _g = e.e;
		return header + ("Custom function exception: " + (_g == null ? "null" : Std.string(_g)));
	}
};
json2object_ErrorUtils.convertErrorArray = function(e) {
	var f = json2object_ErrorUtils.convertError;
	var result = new Array(e.length);
	var _g = 0;
	var _g1 = e.length;
	while(_g < _g1) {
		var i = _g++;
		result[i] = f(e[i]);
	}
	return result.join("\n");
};
var json2object_PositionUtils = function(content) {
	this.linesInfo = [];
	var s = 0;
	var e = 0;
	var i = 0;
	var lineCount = 0;
	while(i < content.length) switch(content.charAt(i)) {
	case "\n":
		e = i;
		this.linesInfo.push({ number : lineCount, start : s, end : e});
		++lineCount;
		++i;
		s = i;
		break;
	case "\r":
		e = i;
		if(content.charAt(i + 1) == "\n") {
			++e;
		}
		this.linesInfo.push({ number : lineCount, start : s, end : e});
		++lineCount;
		i = e + 1;
		s = i;
		break;
	default:
		++i;
	}
	this.linesInfo.push({ number : lineCount, start : s, end : i});
};
json2object_PositionUtils.__name__ = true;
json2object_PositionUtils.prototype = {
	convertPosition: function(position) {
		var min = position.min;
		var max = position.max;
		var pos = { file : position.file, min : min + 1, max : max + 1, lines : []};
		var bounds_min = 0;
		var bounds_max = this.linesInfo.length - 1;
		if(min > this.linesInfo[0].end) {
			while(bounds_max > bounds_min) {
				var i = (bounds_min + bounds_max) / 2 | 0;
				var line = this.linesInfo[i];
				if(line.start == min) {
					bounds_min = i;
					bounds_max = i;
				}
				if(line.end < min) {
					bounds_min = i + 1;
				}
				if(line.start > min || line.end >= min && line.start < min) {
					bounds_max = i;
				}
			}
		}
		var _g = bounds_min;
		var _g1 = this.linesInfo.length;
		while(_g < _g1) {
			var line = this.linesInfo[_g++];
			if(line.start <= min && line.end >= max) {
				pos.lines.push({ number : line.number + 1, start : min - line.start + 1, end : max - line.start + 1});
				break;
			}
			if(line.start <= min && min <= line.end) {
				pos.lines.push({ number : line.number + 1, start : min - line.start + 1, end : line.end + 1});
			}
			if(line.start <= max && max <= line.end) {
				pos.lines.push({ number : line.number + 1, start : line.start + 1, end : max - line.start + 1});
			}
			if(line.start >= max || line.end >= max) {
				break;
			}
		}
		return pos;
	}
	,__class__: json2object_PositionUtils
};
var server_ConsoleInput = function(main) {
	var _g = new haxe_ds_StringMap();
	_g.h["addAdmin"] = { args : ["name","password"], desc : "Adds channel admin"};
	_g.h["removeAdmin"] = { args : ["name"], desc : "Removes channel admin"};
	_g.h["replay"] = { args : ["name"], desc : "Replay log file on server from user/logs/"};
	_g.h["logList"] = { args : [], desc : "Show log list from user/logs/"};
	_g.h["exit"] = { args : [], desc : "Exit process"};
	this.commands = _g;
	this.main = main;
};
server_ConsoleInput.__name__ = true;
server_ConsoleInput.prototype = {
	initConsoleInput: function() {
		var _gthis = this;
		var rl = js_node_Readline.createInterface({ input : process.stdin, output : process.stdout, completer : $bind(this,this.onCompletion)});
		haxe_Log.trace = function(msg,infos) {
			js_node_Readline.clearLine(process.stdout,0);
			js_node_Readline.cursorTo(process.stdout,0,null);
			console.log(_gthis.formatOutput(msg,infos));
			rl.prompt(true);
		};
		rl.prompt();
		rl.on("line",function(line) {
			_gthis.parseLine(line);
			rl.prompt();
		});
	}
	,formatOutput: function(v,infos) {
		var str = Std.string(v);
		if(infos == null) {
			return str;
		}
		if(infos.customParams != null) {
			var _g = 0;
			var _g1 = infos.customParams;
			while(_g < _g1.length) str += ", " + Std.string(_g1[_g++]);
		}
		return str;
	}
	,onCompletion: function(line) {
		var _g = [];
		var item_keys = Object.keys(this.commands.h);
		var item_length = item_keys.length;
		var item_current = 0;
		while(item_current < item_length) _g.push("/" + item_keys[item_current++] + " ");
		var _g1 = [];
		var _g11 = 0;
		while(_g11 < _g.length) {
			var v = _g[_g11];
			++_g11;
			if(StringTools.startsWith(v,line)) {
				_g1.push(v);
			}
		}
		if(_g1.length > 0) {
			return [_g1,line];
		}
		return [_g,line];
	}
	,parseLine: function(line) {
		if(line.charCodeAt(0) != 47 || line.length < 2) {
			this.printHelp(line);
			return;
		}
		var args = StringTools.trim(line).split(" ");
		var command = HxOverrides.substr(args.shift(),1,null);
		if(this.commands.h[command] == null) {
			this.printHelp(line);
			return;
		}
		if(!this.isValidArgs(command,args)) {
			return;
		}
		switch(command) {
		case "addAdmin":
			var name = args[0];
			var password = args[1];
			if(this.main.badNickName(name)) {
				haxe_Log.trace(StringTools.replace(Lang.get("usernameError"),"$MAX","" + this.main.config.maxLoginLength),{ fileName : "src/server/ConsoleInput.hx", lineNumber : 115, className : "server.ConsoleInput", methodName : "parseLine"});
				return;
			}
			this.main.addAdmin(name,password);
			break;
		case "exit":
			this.main.exit();
			break;
		case "logList":
			server_Utils.ensureDir(this.main.logsDir);
			var _this = js_node_Fs.readdirSync(this.main.logsDir);
			var _g = [];
			var _g1 = 0;
			while(_g1 < _this.length) {
				var v = _this[_g1];
				++_g1;
				if(StringTools.endsWith(v,".json")) {
					_g.push(v);
				}
			}
			var _g1 = 0;
			while(_g1 < _g.length) haxe_Log.trace(haxe_io_Path.withoutExtension(_g[_g1++]),{ fileName : "src/server/ConsoleInput.hx", lineNumber : 142, className : "server.ConsoleInput", methodName : "parseLine"});
			break;
		case "removeAdmin":
			this.main.removeAdmin(args[0]);
			break;
		case "replay":
			server_Utils.ensureDir(this.main.logsDir);
			var path = haxe_io_Path.normalize("" + this.main.logsDir + "/" + args[0] + ".json");
			if(!sys_FileSystem.exists(path)) {
				haxe_Log.trace("File \"" + path + "\" not found",{ fileName : "src/server/ConsoleInput.hx", lineNumber : 129, className : "server.ConsoleInput", methodName : "parseLine"});
				return;
			}
			var events = JSON.parse(js_node_Fs.readFileSync(path,{ encoding : "utf8"}));
			this.main.replayLog(events);
			break;
		}
	}
	,isValidArgs: function(command,args) {
		var len = args.length;
		var actual = this.commands.h[command].args.length;
		if(len != actual) {
			haxe_Log.trace("Wrong count of arguments for command \"" + command + "\" (" + len + " instead of " + actual + ")",{ fileName : "src/server/ConsoleInput.hx", lineNumber : 154, className : "server.ConsoleInput", methodName : "isValidArgs"});
			return false;
		}
		return true;
	}
	,printHelp: function(line) {
		var maxLength = 0;
		var h = this.commands.h;
		var _g_keys = Object.keys(h);
		var _g_length = _g_keys.length;
		var _g_current = 0;
		while(_g_current < _g_length) {
			var key = _g_keys[_g_current++];
			var _g = { key : key, value : h[key]};
			var len = ("/" + _g.key + " " + _g.value.args.join(" ")).length;
			if(maxLength < len) {
				maxLength = len;
			}
		}
		var list = [];
		var h = this.commands.h;
		var _g_keys = Object.keys(h);
		var _g_length = _g_keys.length;
		var _g_current = 0;
		while(_g_current < _g_length) {
			var key = _g_keys[_g_current++];
			var _g = { key : key, value : h[key]};
			var data = _g.value;
			list.push("" + StringTools.rpad("/" + _g.key + " " + data.args.join(" ")," ",maxLength) + " | " + data.desc);
		}
		haxe_Log.trace("Unknown command \"" + line + "\". List:\n" + list.join("\n"),{ fileName : "src/server/ConsoleInput.hx", lineNumber : 173, className : "server.ConsoleInput", methodName : "printHelp"});
	}
	,__class__: server_ConsoleInput
};
var server_HttpServer = function() { };
server_HttpServer.__name__ = true;
server_HttpServer.init = function(dir,customDir,allowLocalRequests) {
	server_HttpServer.dir = dir;
	if(customDir == null) {
		return;
	}
	server_HttpServer.customDir = customDir;
	server_HttpServer.hasCustomRes = sys_FileSystem.exists(customDir);
	server_HttpServer.allowLocalRequests = allowLocalRequests;
};
server_HttpServer.serveFiles = function(req,res) {
	var url;
	try {
		url = new js_node_url_URL(server_HttpServer.safeDecodeURI(req.url),"http://localhost");
	} catch( _g ) {
		url = new js_node_url_URL("/","http://localhost");
	}
	var filePath = server_HttpServer.getPath(server_HttpServer.dir,url);
	var ext = haxe_io_Path.extension(filePath).toLowerCase();
	res.setHeader("Accept-Ranges","bytes");
	res.setHeader("Content-Type",server_HttpServer.getMimeType(ext));
	if(server_HttpServer.allowLocalRequests && req.socket.remoteAddress == req.socket.localAddress || server_HttpServer.allowedLocalFiles.h[url.pathname]) {
		if(server_HttpServer.isMediaExtension(ext)) {
			server_HttpServer.allowedLocalFiles.h[url.pathname] = true;
			var s = url.pathname;
			if(server_HttpServer.serveMedia(req,res,decodeURIComponent(s.split("+").join(" ")))) {
				return;
			}
		}
	}
	if(!server_HttpServer.isChildOf(server_HttpServer.dir,filePath)) {
		res.statusCode = 500;
		var rel = js_node_Path.relative(server_HttpServer.dir,filePath);
		res.end("Error getting the file: No access to " + rel + ".");
		return;
	}
	if(url.pathname == "/proxy") {
		if(!server_HttpServer.proxyUrl(req,res)) {
			res.end("Proxy error: " + req.url);
		}
		return;
	}
	if(server_HttpServer.hasCustomRes) {
		var path = server_HttpServer.getPath(server_HttpServer.customDir,url);
		if(js_node_Fs.existsSync(path)) {
			filePath = path;
		}
	}
	if(server_HttpServer.isMediaExtension(ext)) {
		if(server_HttpServer.serveMedia(req,res,filePath)) {
			return;
		}
	}
	js_node_Fs.readFile(filePath,function(err,data) {
		if(err != null) {
			server_HttpServer.readFileError(err,res,filePath);
			return;
		}
		if(ext == "html") {
			data = server_HttpServer.localizeHtml(data.toString(),req.headers["accept-language"]);
		}
		res.end(data);
	});
};
server_HttpServer.getPath = function(dir,url) {
	var filePath = dir + url.pathname;
	filePath = decodeURIComponent(filePath.split("+").join(" "));
	if(!sys_FileSystem.isDirectory(filePath)) {
		return filePath;
	}
	return haxe_io_Path.addTrailingSlash(filePath) + "index.html";
};
server_HttpServer.readFileError = function(err,res,filePath) {
	if(err.code == "ENOENT") {
		res.statusCode = 404;
		res.end("File " + js_node_Path.relative(server_HttpServer.dir,filePath) + " not found.");
	} else {
		res.statusCode = 500;
		res.end("Error getting the file: " + Std.string(err) + ".");
	}
};
server_HttpServer.serveMedia = function(req,res,filePath) {
	if(!js_node_Fs.existsSync(filePath)) {
		return false;
	}
	var videoSize = js_node_Fs.statSync(filePath).size;
	var range = req.headers["range"];
	if(range == null) {
		res.statusCode = 200;
		res.setHeader("Content-Length","" + videoSize);
		js_node_Fs.createReadStream(filePath).pipe(res);
		return true;
	}
	var ranges = new EReg("[-=]","g").split(range);
	var start = parseFloat(ranges[1]);
	if(server_Utils.isOutOfRange(start,0,videoSize - 1)) {
		start = 0;
	}
	var end = parseFloat(ranges[2]);
	if(isNaN(end)) {
		end = start + 5242880;
	}
	if(server_Utils.isOutOfRange(end,start,videoSize - 1)) {
		end = videoSize - 1;
	}
	res.setHeader("Content-Range","bytes " + start + "-" + end + "/" + videoSize);
	res.setHeader("Content-Length","" + (end - start + 1));
	res.statusCode = 206;
	js_node_Fs.createReadStream(filePath,{ start : start, end : end}).pipe(res);
	return true;
};
server_HttpServer.isMediaExtension = function(ext) {
	if(!(ext == "mp4" || ext == "mp3")) {
		return ext == "wav";
	} else {
		return true;
	}
};
server_HttpServer.localizeHtml = function(data,lang) {
	if(lang != null && server_HttpServer.matchLang.match(lang)) {
		lang = server_HttpServer.matchLang.matched(0);
	} else {
		lang = "en";
	}
	data = server_HttpServer.matchVarString.map(data,function(regExp) {
		var key = regExp.matched(1);
		return Lang.get(lang,key);
	});
	return data;
};
server_HttpServer.proxyUrl = function(req,res) {
	var proxy = server_HttpServer.proxyRequest(StringTools.replace(req.url,"/proxy?url=",""),req,res,function(proxyReq) {
		var url = proxyReq.headers["location"];
		if(url == null) {
			return false;
		}
		var proxy2 = server_HttpServer.proxyRequest(url,req,res,function(proxyReq) {
			return false;
		});
		if(proxy2 == null) {
			res.end("Proxy error: multiple redirects for url " + url);
			return true;
		}
		req.pipe(proxy2,{ end : true});
		return true;
	});
	if(proxy == null) {
		return false;
	}
	req.pipe(proxy,{ end : true});
	return true;
};
server_HttpServer.proxyRequest = function(url,req,res,fn) {
	var url1;
	try {
		url1 = new js_node_url_URL(server_HttpServer.safeDecodeURI(url));
	} catch( _g ) {
		return null;
	}
	if(url1.host == req.headers["host"]) {
		return null;
	}
	var proxy = (url1.protocol == "https:" ? js_node_Https.request : js_node_Http.request)({ host : url1.hostname, port : Std.parseInt(url1.port), path : url1.pathname + url1.search, method : req.method},function(proxyReq) {
		if(fn(proxyReq)) {
			return;
		}
		proxyReq.headers["Content-Type"] = "application/octet-stream";
		res.writeHead(proxyReq.statusCode,proxyReq.headers);
		proxyReq.pipe(res,{ end : true});
	});
	proxy.on("error",function(err) {
		res.end("Proxy error: " + url1.href);
	});
	return proxy;
};
server_HttpServer.isChildOf = function(parent,child) {
	var rel = js_node_Path.relative(parent,child);
	if(rel.length > 0 && !StringTools.startsWith(rel,"..")) {
		return !js_node_Path.isAbsolute(rel);
	} else {
		return false;
	}
};
server_HttpServer.getMimeType = function(ext) {
	var contentType = server_HttpServer.mimeTypes.h[ext];
	if(contentType == null) {
		return "application/octet-stream";
	}
	return contentType;
};
server_HttpServer.safeDecodeURI = function(data) {
	try {
		data = decodeURI(data);
	} catch( _g ) {
		data = "";
	}
	data = data.replace(server_HttpServer.ctrlCharacters.r,"");
	return data;
};
var server_Logger = function(folder,maxCount,verbose) {
	this.matchFileFormat = new EReg("[0-9_-]+\\.json$","");
	this.logs = [];
	this.folder = folder;
	this.maxCount = maxCount;
	this.verbose = verbose;
};
server_Logger.__name__ = true;
server_Logger.prototype = {
	log: function(event) {
		this.logs.push(event);
		if(this.logs.length > 1000) {
			this.logs.shift();
		}
		if(this.hasSameLatestEvents("GetTime",5)) {
			this.logs.splice(this.logs.length - 3,1);
		}
	}
	,hasSameLatestEvents: function(type,count) {
		if(this.logs.length < count) {
			return false;
		}
		var _g = 1;
		var _g1 = count + 1;
		while(_g < _g1) if(this.logs[this.logs.length - _g++].event.type != type) {
			return false;
		}
		return true;
	}
	,saveLog: function() {
		if(this.logs.length == 0) {
			return;
		}
		server_Utils.ensureDir(this.folder);
		this.removeOldestLog(this.folder);
		var name = DateTools.format(new Date(),"%Y-%m-%d_%H_%M_%S");
		js_node_Fs.writeFileSync("" + this.folder + "/" + name + ".json",JSON.stringify(this.getLogs(),$bind(this,this.filterNulls),"\t"));
	}
	,getLogs: function() {
		return this.logs;
	}
	,filterNulls: function(key,value) {
		if(value == null) {
			return undefined;
		}
		return value;
	}
	,removeOldestLog: function(folder) {
		var _gthis = this;
		var names = js_node_Fs.readdirSync(folder);
		if(Lambda.count(names,function(item) {
			return _gthis.matchFileFormat.match(item);
		}) < this.maxCount) {
			return;
		}
		var minDate = 0.0;
		var fileName = null;
		var _g = 0;
		while(_g < names.length) {
			var name = names[_g];
			++_g;
			var date = this.extractFileDate(name).getTime();
			if(minDate == 0 || minDate > date) {
				minDate = date;
				fileName = name;
			}
		}
		if(fileName == null) {
			return;
		}
		js_node_Fs.unlinkSync("" + folder + "/" + fileName);
	}
	,extractFileDate: function(name) {
		name = haxe_io_Path.withoutExtension(name);
		var t = name.split("_");
		var d = t.shift().split("-");
		if(d.length != 3 && t.length != 3) {
			return new Date(0);
		}
		return HxOverrides.strDate("" + d[0] + "-" + d[1] + "-" + d[2] + " " + t[0] + ":" + t[1] + ":" + t[2]);
	}
	,__class__: server_Logger
};
var server_Main = function(opts) {
	this.flashbackTime = 0.0;
	this.loadedClientsCount = 0;
	this.matchGuestName = new EReg("guest [0-9]+","");
	this.matchHtmlChars = new EReg("[&^<>'\"]","");
	this.isHeroku = false;
	this.messages = [];
	this.videoTimer = new server_VideoTimer();
	this.videoList = new VideoList();
	this.wsEventParser = new JsonParser_$1();
	this.freeIds = [];
	this.clients = [];
	this.rootDir = "" + __dirname + "/..";
	var _gthis = this;
	this.isNoState = !opts.loadState;
	this.verbose = Lambda.has(process.argv.slice(2),"--verbose");
	this.statePath = "" + this.rootDir + "/user/state.json";
	this.logsDir = "" + this.rootDir + "/user/logs";
	process.on("SIGINT",$bind(this,this.exit));
	process.on("SIGUSR1",$bind(this,this.exit));
	process.on("SIGUSR2",$bind(this,this.exit));
	process.on("SIGTERM",$bind(this,this.exit));
	process.on("uncaughtException",function(err) {
		_gthis.logError("uncaughtException",{ message : err.message, stack : err.stack});
		_gthis.exit();
	});
	process.on("unhandledRejection",function(reason,promise) {
		_gthis.logError("unhandledRejection",reason);
		_gthis.exit();
	});
	this.logger = new server_Logger(this.logsDir,10,this.verbose);
	this.consoleInput = new server_ConsoleInput(this);
	this.consoleInput.initConsoleInput();
	this.initIntergationHandlers();
	this.loadState();
	this.config = this.loadUserConfig();
	this.userList = this.loadUsers();
	this.config.isVerbose = this.verbose;
	this.config.salt = this.generateConfigSalt();
	if(this.config.localNetworkOnly) {
		this.localIp = "127.0.0.1";
	} else {
		this.localIp = server_Utils.getLocalIp();
	}
	this.globalIp = this.localIp;
	this.port = this.config.port;
	var envPort = process.env.PORT;
	if(envPort != null) {
		this.port = envPort;
	}
	var attempts = this.isNoState ? 500 : 5;
	var preparePort = null;
	preparePort = function() {
		server_Utils.isPortFree(_gthis.port,function(isFree) {
			if(!isFree && attempts > 0) {
				haxe_Log.trace("Warning: port " + _gthis.port + " is already in use. Changed to " + (_gthis.port + 1),{ fileName : "src/server/Main.hx", lineNumber : 105, className : "server.Main", methodName : "new"});
				attempts -= 1;
				_gthis.port++;
				preparePort();
				return;
			}
			_gthis.runServer();
		});
	};
	preparePort();
};
server_Main.__name__ = true;
server_Main.main = function() {
	new server_Main({ loadState : true});
};
server_Main.prototype = {
	runServer: function() {
		var _gthis = this;
		haxe_Log.trace("Local: http://" + this.localIp + ":" + this.port,{ fileName : "src/server/Main.hx", lineNumber : 118, className : "server.Main", methodName : "runServer"});
		if(this.config.localNetworkOnly) {
			haxe_Log.trace("Global network is disabled in config",{ fileName : "src/server/Main.hx", lineNumber : 120, className : "server.Main", methodName : "runServer"});
		} else if(!this.isNoState) {
			server_Utils.getGlobalIp(function(ip) {
				_gthis.globalIp = ip;
				haxe_Log.trace("Global: http://" + _gthis.globalIp + ":" + _gthis.port,{ fileName : "src/server/Main.hx", lineNumber : 124, className : "server.Main", methodName : "runServer"});
			});
		}
		var dir = "" + this.rootDir + "/res";
		server_HttpServer.init(dir,"" + this.rootDir + "/user/res",this.config.localAdmins);
		Lang.init("" + dir + "/langs");
		var server = js_node_Http.createServer(function(req,res) {
			server_HttpServer.serveFiles(req,res);
		});
		this.wss = new js_npm_ws_Server({ server : server});
		this.wss.on("connection",$bind(this,this.onConnect));
		if(this.config.localNetworkOnly) {
			server.listen(this.port,this.localIp,$bind(this,this.onServerInited));
		} else {
			server.listen(this.port,$bind(this,this.onServerInited));
		}
		new haxe_Timer(25000).run = function() {
			var _g = 0;
			var _g1 = _gthis.clients;
			while(_g < _g1.length) {
				var client = _g1[_g];
				++_g;
				if(client.isAlive) {
					client.isAlive = false;
					client.ws.ping();
					continue;
				}
				client.ws.terminate();
			}
		};
	}
	,onServerInited: function() {
	}
	,exit: function() {
		this.saveState();
		this.logger.saveLog();
		process.exit();
	}
	,generateConfigSalt: function() {
		if(this.userList.salt == null) {
			var tmp = "" + Math.random();
			this.userList.salt = haxe_crypto_Sha256.encode(tmp);
		}
		return this.userList.salt;
	}
	,loadUserConfig: function() {
		var config = this.getUserConfig();
		var groups = ["guest","user","leader","admin"];
		var _g = 0;
		while(_g < groups.length) {
			var field = groups[_g];
			++_g;
			var group = Reflect.field(config.permissions,field);
			var _g1 = 0;
			while(_g1 < groups.length) {
				var type = groups[_g1];
				++_g1;
				if(type == field) {
					continue;
				}
				if(group.indexOf(type) == -1) {
					continue;
				}
				HxOverrides.remove(group,type);
				var _g2 = 0;
				var _g3 = Reflect.field(config.permissions,type);
				while(_g2 < _g3.length) group.push(_g3[_g2++]);
			}
		}
		return config;
	}
	,getUserConfig: function() {
		var config = JSON.parse(js_node_Fs.readFileSync("" + this.rootDir + "/default-config.json",{ encoding : "utf8"}));
		if(this.isNoState) {
			return config;
		}
		var customPath = "" + this.rootDir + "/user/config.json";
		if(!sys_FileSystem.exists(customPath)) {
			return config;
		}
		var customConfig = JSON.parse(js_node_Fs.readFileSync(customPath,{ encoding : "utf8"}));
		var _g = 0;
		var _g1 = Reflect.fields(customConfig);
		while(_g < _g1.length) {
			var field = _g1[_g];
			++_g;
			if(Reflect.field(config,field) == null) {
				haxe_Log.trace("Warning: config field \"" + field + "\" is unknown",{ fileName : "src/server/Main.hx", lineNumber : 195, className : "server.Main", methodName : "getUserConfig"});
			}
			config[field] = Reflect.field(customConfig,field);
		}
		var emoteCopies_h = Object.create(null);
		var _g = 0;
		var _g1 = config.emotes;
		while(_g < _g1.length) {
			var emote = _g1[_g];
			++_g;
			if(emoteCopies_h[emote.name]) {
				haxe_Log.trace("Warning: emote name \"" + emote.name + "\" has copy",{ fileName : "src/server/Main.hx", lineNumber : 201, className : "server.Main", methodName : "getUserConfig"});
			}
			emoteCopies_h[emote.name] = true;
			if(!this.verbose) {
				continue;
			}
			if(emoteCopies_h[emote.image]) {
				haxe_Log.trace("Warning: emote url of name \"" + emote.name + "\" has copy",{ fileName : "src/server/Main.hx", lineNumber : 205, className : "server.Main", methodName : "getUserConfig"});
			}
			emoteCopies_h[emote.image] = true;
		}
		return config;
	}
	,loadUsers: function() {
		var customPath = "" + this.rootDir + "/user/users.json";
		if(this.isNoState || !sys_FileSystem.exists(customPath)) {
			return { admins : [], bans : []};
		}
		var users = JSON.parse(js_node_Fs.readFileSync(customPath,{ encoding : "utf8"}));
		if(users.admins == null) {
			users.admins = [];
		}
		if(users.bans == null) {
			users.bans = [];
		}
		var _g = 0;
		var _g1 = users.bans;
		while(_g < _g1.length) {
			var field = _g1[_g];
			++_g;
			field.toDate = HxOverrides.strDate(field.toDate);
		}
		return users;
	}
	,writeUsers: function(users) {
		var folder = "" + this.rootDir + "/user";
		server_Utils.ensureDir(folder);
		var users1 = users.admins;
		var _g = [];
		var _g1 = 0;
		var _g2 = users.bans;
		while(_g1 < _g2.length) {
			var field = _g2[_g1];
			++_g1;
			_g.push({ ip : field.ip, toDate : HxOverrides.dateStr(field.toDate)});
		}
		js_node_Fs.writeFileSync("" + folder + "/users.json",JSON.stringify({ admins : users1, bans : _g, salt : users.salt},null,"\t"));
	}
	,saveState: function() {
		haxe_Log.trace("Saving state...",{ fileName : "src/server/Main.hx", lineNumber : 244, className : "server.Main", methodName : "saveState"});
		var json = JSON.stringify(this.getCurrentState(),null,"\t");
		js_node_Fs.writeFileSync(this.statePath,json);
		this.writeUsers(this.userList);
	}
	,getCurrentState: function() {
		return { videoList : this.videoList.items, isPlaylistOpen : this.videoList.isOpen, itemPos : this.videoList.pos, messages : this.messages, timer : { time : this.videoTimer.getTime(), paused : this.videoTimer.isPaused()}};
	}
	,loadState: function() {
		if(this.isNoState) {
			return;
		}
		if(!sys_FileSystem.exists(this.statePath)) {
			return;
		}
		haxe_Log.trace("Loading state...",{ fileName : "src/server/Main.hx", lineNumber : 266, className : "server.Main", methodName : "loadState"});
		var data = JSON.parse(js_node_Fs.readFileSync(this.statePath,{ encoding : "utf8"}));
		this.videoList.setItems(data.videoList);
		this.messages.length = 0;
		this.videoList.isOpen = data.isPlaylistOpen;
		this.videoList.setPos(data.itemPos);
		var _g = 0;
		var _g1 = data.messages;
		while(_g < _g1.length) this.messages.push(_g1[_g++]);
		this.videoTimer.start();
		this.videoTimer.setTime(data.timer.time);
		this.videoTimer.pause();
	}
	,logError: function(type,data) {
		haxe_Log.trace(type,{ fileName : "src/server/Main.hx", lineNumber : 281, className : "server.Main", methodName : "logError", customParams : [data]});
		var crashesFolder = "" + this.rootDir + "/user/crashes";
		server_Utils.ensureDir(crashesFolder);
		js_node_Fs.writeFileSync("" + crashesFolder + "/" + (DateTools.format(new Date(),"%Y-%m-%d_%H_%M_%S") + "-" + type) + ".json",JSON.stringify(data,null,"\t"));
	}
	,initIntergationHandlers: function() {
		var _gthis = this;
		this.isHeroku = process.env["_"] != null && process.env["_"].indexOf("heroku") != -1;
		if(this.isHeroku && process.env["APP_URL"] != null) {
			var url = process.env["APP_URL"];
			if(!StringTools.startsWith(url,"http")) {
				url = "http://" + url;
			}
			new haxe_Timer(600000).run = function() {
				if(_gthis.clients.length == 0) {
					return;
				}
				haxe_Log.trace("Ping " + url,{ fileName : "src/server/Main.hx", lineNumber : 298, className : "server.Main", methodName : "initIntergationHandlers"});
				js_node_Http.get(url,null,function(r) {
				});
			};
		}
	}
	,clientIp: function(req) {
		if(this.config.allowProxyIps || this.isHeroku) {
			var forwarded = req.headers["x-forwarded-for"];
			if(forwarded == null || forwarded.length == 0) {
				return req.socket.remoteAddress;
			}
			return StringTools.trim(forwarded.split(",")[0]);
		}
		return req.socket.remoteAddress;
	}
	,addAdmin: function(name,password) {
		password += this.config.salt;
		var hash = haxe_crypto_Sha256.encode(password);
		this.userList.admins.push({ name : name, hash : hash});
		haxe_Log.trace("Admin " + name + " added.",{ fileName : "src/server/Main.hx", lineNumber : 321, className : "server.Main", methodName : "addAdmin"});
	}
	,removeAdmin: function(name) {
		HxOverrides.remove(this.userList.admins,Lambda.find(this.userList.admins,function(item) {
			return item.name == name;
		}));
		haxe_Log.trace("Admin " + name + " removed.",{ fileName : "src/server/Main.hx", lineNumber : 328, className : "server.Main", methodName : "removeAdmin"});
	}
	,replayLog: function(events) {
		var _gthis = this;
		var timer = new haxe_Timer(1000);
		timer.run = function() {
			if(events.length == 0) {
				timer.stop();
				return;
			}
			var e = events.shift();
			switch(e.event.type) {
			case "Connected":
				if(ClientTools.getByName(_gthis.clients,e.clientName) == null) {
					var ws = { send : function() {
						return;
					}};
					var client = new Client(ws,null,_gthis.freeIds.length > 0 ? _gthis.freeIds.shift() : _gthis.clients.length,e.clientName,e.clientGroup);
					ws.ping = function() {
						return client.isAlive = true;
					};
					_gthis.clients.push(client);
				}
				_gthis.onMessage(ClientTools.getByName(_gthis.clients,e.clientName),e.event,true);
				break;
			case "Login":
				var name = e.event.login.clientName;
				if(e.event.login.passHash != null && !Lambda.exists(_gthis.userList.admins,function(a) {
					return a.name == name;
				})) {
					e.event.login.passHash = null;
				}
				_gthis.onMessage(ClientTools.getByName(_gthis.clients,e.clientName),e.event,true);
				break;
			default:
				_gthis.onMessage(ClientTools.getByName(_gthis.clients,e.clientName),e.event,true);
			}
		};
	}
	,onConnect: function(ws,req) {
		var _gthis = this;
		var ip = this.clientIp(req);
		var id = this.freeIds.length > 0 ? this.freeIds.shift() : this.clients.length;
		var name = "Guest " + (id + 1);
		haxe_Log.trace(HxOverrides.dateStr(new Date()),{ fileName : "src/server/Main.hx", lineNumber : 366, className : "server.Main", methodName : "onConnect", customParams : ["" + name + " connected (" + ip + ")"]});
		var client = new Client(ws,req,id,name,0);
		client.setGroupFlag(ClientGroup.Admin,this.config.localAdmins && req.socket.localAddress == ip);
		this.clients.push(client);
		ws.on("pong",function() {
			return client.isAlive = true;
		});
		this.onMessage(client,{ type : "Connected"},true);
		ws.on("message",function(data) {
			var obj = _gthis.wsEventParser.fromJson(data.toString());
			if(_gthis.wsEventParser.errors.length > 0 || _gthis.noTypeObj(obj)) {
				var errors = "" + ("Wrong request for type \"" + obj.type + "\":") + "\n" + json2object_ErrorUtils.convertErrorArray(_gthis.wsEventParser.errors);
				haxe_Log.trace(errors,{ fileName : "src/server/Main.hx", lineNumber : 382, className : "server.Main", methodName : "onConnect"});
				_gthis.serverMessage(client,errors);
				return;
			}
			_gthis.onMessage(client,obj,false);
		});
		ws.on("close",function(err) {
			_gthis.onMessage(client,{ type : "Disconnected"},true);
		});
	}
	,noTypeObj: function(data) {
		if(data.type == "GetTime") {
			return false;
		}
		if(data.type == "Flashback") {
			return false;
		}
		if(data.type == "TogglePlaylistLock") {
			return false;
		}
		if(data.type == "UpdatePlaylist") {
			return false;
		}
		if(data.type == "Logout") {
			return false;
		}
		if(data.type == "Dump") {
			return false;
		}
		var t = data.type;
		return ((Reflect.field(data,t.charAt(0).toLowerCase() + HxOverrides.substr(t,1,null))) === null);
	}
	,onMessage: function(client,data,internal) {
		var _gthis = this;
		this.logger.log({ clientName : client.name, clientGroup : client.group, event : data, time : HxOverrides.dateStr(new Date())});
		switch(data.type) {
		case "AddVideo":
			if(this.isPlaylistLockedFor(client)) {
				return;
			}
			if(!this.checkPermission(client,"addVideo")) {
				return;
			}
			if(this.config.totalVideoLimit != 0 && this.videoList.items.length >= this.config.totalVideoLimit) {
				this.serverMessage(client,"totalVideoLimitError");
				return;
			}
			if(this.config.userVideoLimit != 0 && this.videoList.itemsByUser(client) >= this.config.userVideoLimit) {
				this.serverMessage(client,"videoLimitPerUserError");
				return;
			}
			if(!data.addVideo.atEnd && !this.checkPermission(client,"changeOrder")) {
				data.addVideo.atEnd = true;
			}
			var item = data.addVideo.item;
			item.author = client.name;
			var local = "" + this.localIp + ":" + this.port;
			if(item.url.indexOf(local) != -1) {
				item.url = StringTools.replace(item.url,local,"" + this.globalIp + ":" + this.port);
			}
			if(this.videoList.exists(function(i) {
				return i.url == item.url;
			})) {
				this.serverMessage(client,"videoAlreadyExistsError");
				return;
			}
			this.videoList.addItem(item,data.addVideo.atEnd);
			this.broadcast(data);
			if(this.videoList.items.length == 1) {
				this.restartWaitTimer();
			}
			break;
		case "BanClient":
			if(!this.checkPermission(client,"banClient")) {
				return;
			}
			var name = data.banClient.name;
			var bannedClient = ClientTools.getByName(this.clients,name);
			if(bannedClient == null) {
				return;
			}
			if(client.name == name || (bannedClient.group & 8) != 0) {
				this.serverMessage(client,"adminsCannotBeBannedError");
				return;
			}
			var ip = this.clientIp(bannedClient.req);
			HxOverrides.remove(this.userList.bans,Lambda.find(this.userList.bans,function(item) {
				return item.ip == ip;
			}));
			if(data.banClient.time == 0) {
				bannedClient.setGroupFlag(ClientGroup.Banned,false);
				this.sendClientList();
				return;
			}
			var currentTime = new Date().getTime();
			var time = currentTime + data.banClient.time * 1000;
			if(time < currentTime) {
				return;
			}
			this.userList.bans.push({ ip : ip, toDate : new Date(time)});
			this.checkBan(bannedClient);
			this.serverMessage(client,"" + bannedClient.name + " (" + ip + ") has been banned.");
			this.sendClientList();
			break;
		case "ClearChat":
			if(!this.checkPermission(client,"clearChat")) {
				return;
			}
			this.messages.length = 0;
			this.broadcast(data);
			break;
		case "ClearPlaylist":
			if(this.isPlaylistLockedFor(client)) {
				return;
			}
			if(!this.checkPermission(client,"removeVideo")) {
				return;
			}
			this.videoTimer.stop();
			var _this = this.videoList;
			_this.items.length = 0;
			_this.pos = 0;
			this.broadcast(data);
			break;
		case "Connected":
			if(!internal) {
				return;
			}
			if(this.clients.length == 1 && this.videoList.items.length > 0) {
				if(this.videoTimer.isPaused()) {
					this.videoTimer.play();
				}
			}
			this.checkBan(client);
			this.send(client,{ type : "Connected", connected : { config : this.config, history : this.messages, isUnknownClient : true, clientName : client.name, clients : this.clientList(), videoList : this.videoList.items, isPlaylistOpen : this.videoList.isOpen, itemPos : this.videoList.pos, globalIp : this.globalIp}});
			this.sendClientListExcept(client);
			break;
		case "Disconnected":
			if(!internal) {
				return;
			}
			haxe_Log.trace(HxOverrides.dateStr(new Date()),{ fileName : "src/server/Main.hx", lineNumber : 442, className : "server.Main", methodName : "onMessage", customParams : ["Client " + client.name + " disconnected"]});
			server_Utils.sortedPush(this.freeIds,client.id);
			HxOverrides.remove(this.clients,client);
			this.sendClientList();
			if((client.group & 4) != 0) {
				if(this.videoTimer.isPaused()) {
					this.videoTimer.play();
				}
			}
			if(this.clients.length == 0) {
				if(this.waitVideoStart != null) {
					this.waitVideoStart.stop();
				}
				this.videoTimer.pause();
			}
			haxe_Timer.delay(function() {
				if(Lambda.exists(_gthis.clients,function(i) {
					return i.name == client.name;
				})) {
					return;
				}
				_gthis.broadcast({ type : "ServerMessage", serverMessage : { textId : "" + client.name + " has left"}});
			},5000);
			break;
		case "Dump":
			if((client.group & 8) == 0) {
				return;
			}
			var data1 = this.getCurrentState();
			var _this = this.clients;
			var result = new Array(_this.length);
			var _g = 0;
			var _g1 = _this.length;
			while(_g < _g1) {
				var i = _g++;
				var client1 = _this[i];
				result[i] = { name : client1.name, id : client1.id, ip : _gthis.clientIp(client1.req), isBanned : (client1.group & 1) != 0, isAdmin : (client1.group & 8) != 0, isLeader : (client1.group & 4) != 0, isUser : (client1.group & 2) != 0};
			}
			var json = JSON.stringify({ state : data1, clients : result, logs : this.logger.getLogs()},($_=this.logger,$bind($_,$_.filterNulls)),"\t");
			this.send(client,{ type : "Dump", dump : { data : json}});
			break;
		case "Flashback":
			if(!this.checkPermission(client,"rewind")) {
				return;
			}
			if(this.videoList.items.length == 0) {
				return;
			}
			this.loadFlashbackTime();
			this.broadcast({ type : "Rewind", rewind : { time : this.videoTimer.getTime()}});
			break;
		case "GetTime":
			if(this.videoList.items.length == 0) {
				return;
			}
			var _this = this.videoList;
			var maxTime = _this.items[_this.pos].duration - 0.01;
			if(this.videoTimer.getTime() > maxTime) {
				this.videoTimer.pause();
				this.videoTimer.setTime(maxTime);
				var _this = this.videoList;
				var skipUrl = _this.items[_this.pos].url;
				haxe_Timer.delay(function() {
					_gthis.skipVideo({ type : "SkipVideo", skipVideo : { url : skipUrl}});
				},1000);
				return;
			}
			var obj = { type : "GetTime", getTime : { time : this.videoTimer.getTime()}};
			if(this.videoTimer.isPaused()) {
				obj.getTime.paused = true;
			}
			if(this.videoTimer.getRate() != 1) {
				if(!ClientTools.hasLeader(this.clients)) {
					this.videoTimer.setRate(1);
				} else {
					obj.getTime.rate = this.videoTimer.getRate();
				}
			}
			this.send(client,obj);
			break;
		case "KickClient":
			if(!this.checkPermission(client,"banClient")) {
				return;
			}
			var name = data.kickClient.name;
			var kickedClient = ClientTools.getByName(this.clients,name);
			if(kickedClient == null) {
				return;
			}
			if(client.name != name && (kickedClient.group & 8) != 0) {
				this.serverMessage(client,"adminsCannotBeBannedError");
				return;
			}
			this.send(kickedClient,{ type : "KickClient"});
			break;
		case "Login":
			var name = StringTools.trim(data.login.clientName);
			var lcName = name.toLowerCase();
			if(this.badNickName(lcName)) {
				this.serverMessage(client,"usernameError");
				this.send(client,{ type : "LoginError"});
				return;
			}
			var hash = data.login.passHash;
			if(hash == null) {
				if(Lambda.exists(this.userList.admins,function(a) {
					return a.name.toLowerCase() == lcName;
				})) {
					this.send(client,{ type : "PasswordRequest"});
					return;
				}
			} else if(Lambda.exists(this.userList.admins,function(a) {
				if(a.name.toLowerCase() == lcName) {
					return a.hash == hash;
				} else {
					return false;
				}
			})) {
				client.setGroupFlag(ClientGroup.Admin,true);
			} else {
				this.serverMessage(client,"passwordMatchError");
				this.send(client,{ type : "LoginError"});
				return;
			}
			haxe_Log.trace(HxOverrides.dateStr(new Date()),{ fileName : "src/server/Main.hx", lineNumber : 529, className : "server.Main", methodName : "onMessage", customParams : ["Client " + client.name + " logged as " + name]});
			client.name = name;
			client.setGroupFlag(ClientGroup.User,true);
			this.checkBan(client);
			this.send(client,{ type : data.type, login : { isUnknownClient : true, clientName : client.name, clients : this.clientList()}});
			this.sendClientListExcept(client);
			break;
		case "LoginError":
			break;
		case "Logout":
			var oldName = client.name;
			client.name = "Guest " + (this.clients.indexOf(client) + 1);
			client.setGroupFlag(ClientGroup.User,false);
			haxe_Log.trace(HxOverrides.dateStr(new Date()),{ fileName : "src/server/Main.hx", lineNumber : 550, className : "server.Main", methodName : "onMessage", customParams : ["Client " + oldName + " logout to " + client.name]});
			this.send(client,{ type : data.type, logout : { oldClientName : oldName, clientName : client.name, clients : this.clientList()}});
			this.sendClientListExcept(client);
			break;
		case "Message":
			if(!this.checkPermission(client,"writeChat")) {
				return;
			}
			var text = data.message.text;
			if(text.length == 0) {
				return;
			}
			if(text.length > this.config.maxMessageLength) {
				text = HxOverrides.substr(text,0,this.config.maxMessageLength);
			}
			data.message.text = text;
			data.message.clientName = client.name;
			var date = new Date();
			var time = HxOverrides.dateStr(new Date(date.getTime() + date.getTimezoneOffset() * 60 * 1000));
			this.messages.push({ text : text, name : client.name, time : time});
			if(this.messages.length > this.config.serverChatHistory) {
				this.messages.shift();
			}
			this.broadcast(data);
			break;
		case "PasswordRequest":
			break;
		case "Pause":
			if(this.videoList.items.length == 0) {
				return;
			}
			if((client.group & 4) == 0) {
				return;
			}
			if(Math.abs(data.pause.time - this.videoTimer.getTime()) > 30) {
				this.saveFlashbackTime();
			}
			this.videoTimer.setTime(data.pause.time);
			this.videoTimer.pause();
			this.broadcast({ type : data.type, pause : data.pause});
			break;
		case "Play":
			if(this.videoList.items.length == 0) {
				return;
			}
			if((client.group & 4) == 0) {
				return;
			}
			if(Math.abs(data.play.time - this.videoTimer.getTime()) > 30) {
				this.saveFlashbackTime();
			}
			this.videoTimer.setTime(data.play.time);
			this.videoTimer.play();
			this.broadcast({ type : data.type, play : data.play});
			break;
		case "PlayItem":
			if(!this.checkPermission(client,"changeOrder")) {
				return;
			}
			this.videoList.setPos(data.playItem.pos);
			data.playItem.pos = this.videoList.pos;
			this.restartWaitTimer();
			this.broadcast(data);
			break;
		case "RemoveVideo":
			if(this.isPlaylistLockedFor(client)) {
				return;
			}
			if(!this.checkPermission(client,"removeVideo")) {
				return;
			}
			if(this.videoList.items.length == 0) {
				return;
			}
			var url = data.removeVideo.url;
			var index = this.videoList.findIndex(function(item) {
				return item.url == url;
			});
			if(index == -1) {
				return;
			}
			var _this = this.videoList;
			var isCurrent = _this.items[_this.pos].url == url;
			this.videoList.removeItem(index);
			if(isCurrent && this.videoList.items.length > 0) {
				this.broadcast(data);
				this.restartWaitTimer();
			} else {
				this.broadcast(data);
			}
			break;
		case "Rewind":
			if(!this.checkPermission(client,"rewind")) {
				return;
			}
			if(this.videoList.items.length == 0) {
				return;
			}
			data.rewind.time += this.videoTimer.getTime();
			if(data.rewind.time < 0) {
				data.rewind.time = 0;
			}
			this.saveFlashbackTime();
			this.videoTimer.setTime(data.rewind.time);
			this.broadcast({ type : data.type, rewind : data.rewind});
			break;
		case "ServerMessage":
			break;
		case "SetLeader":
			var clientName = data.setLeader.clientName;
			if(client.name == clientName) {
				if(!this.checkPermission(client,"requestLeader")) {
					return;
				}
			} else if((client.group & 4) == 0 && clientName != "") {
				if(!this.checkPermission(client,"setLeader")) {
					return;
				}
			}
			ClientTools.setLeader(this.clients,clientName);
			this.broadcast({ type : "SetLeader", setLeader : { clientName : clientName}});
			if(this.videoList.items.length == 0) {
				return;
			}
			if(!ClientTools.hasLeader(this.clients)) {
				if(this.videoTimer.isPaused()) {
					this.videoTimer.play();
				}
				this.videoTimer.setRate(1);
				this.broadcast({ type : "Play", play : { time : this.videoTimer.getTime()}});
			}
			break;
		case "SetNextItem":
			if(this.isPlaylistLockedFor(client)) {
				return;
			}
			if(!this.checkPermission(client,"changeOrder")) {
				return;
			}
			var pos = data.setNextItem.pos;
			if(pos == this.videoList.pos || pos == this.videoList.pos + 1) {
				return;
			}
			this.videoList.setNextItem(pos);
			this.broadcast(data);
			break;
		case "SetRate":
			if(this.videoList.items.length == 0) {
				return;
			}
			if((client.group & 4) == 0) {
				return;
			}
			this.videoTimer.setRate(data.setRate.rate);
			this.broadcastExcept(client,{ type : data.type, setRate : data.setRate});
			break;
		case "SetTime":
			if(this.videoList.items.length == 0) {
				return;
			}
			if((client.group & 4) == 0) {
				return;
			}
			if(Math.abs(data.setTime.time - this.videoTimer.getTime()) > 30) {
				this.saveFlashbackTime();
			}
			this.videoTimer.setTime(data.setTime.time);
			this.broadcastExcept(client,{ type : data.type, setTime : data.setTime});
			break;
		case "ShufflePlaylist":
			if(this.isPlaylistLockedFor(client)) {
				return;
			}
			if(!this.checkPermission(client,"changeOrder")) {
				return;
			}
			if(this.videoList.items.length == 0) {
				return;
			}
			this.videoList.shuffle();
			this.broadcast({ type : "UpdatePlaylist", updatePlaylist : { videoList : this.videoList.items}});
			break;
		case "SkipVideo":
			if(!this.checkPermission(client,"removeVideo")) {
				return;
			}
			this.skipVideo(data);
			break;
		case "ToggleItemType":
			if(this.isPlaylistLockedFor(client)) {
				return;
			}
			if(!this.checkPermission(client,"toggleItemType")) {
				return;
			}
			this.videoList.toggleItemType(data.toggleItemType.pos);
			this.broadcast(data);
			break;
		case "TogglePlaylistLock":
			if(!this.checkPermission(client,"lockPlaylist")) {
				return;
			}
			this.videoList.isOpen = !this.videoList.isOpen;
			this.broadcast({ type : "TogglePlaylistLock", togglePlaylistLock : { isOpen : this.videoList.isOpen}});
			break;
		case "UpdateClients":
			this.sendClientList();
			break;
		case "UpdatePlaylist":
			this.broadcast({ type : "UpdatePlaylist", updatePlaylist : { videoList : this.videoList.items}});
			break;
		case "VideoLoaded":
			this.prepareVideoPlayback();
			break;
		}
	}
	,clientList: function() {
		var _g = [];
		var _g1 = 0;
		var _g2 = this.clients;
		while(_g1 < _g2.length) _g.push(_g2[_g1++].getData());
		return _g;
	}
	,sendClientList: function() {
		this.broadcast({ type : "UpdateClients", updateClients : { clients : this.clientList()}});
	}
	,sendClientListExcept: function(skipped) {
		this.broadcastExcept(skipped,{ type : "UpdateClients", updateClients : { clients : this.clientList()}});
	}
	,serverMessage: function(client,textId) {
		this.send(client,{ type : "ServerMessage", serverMessage : { textId : textId}});
	}
	,send: function(client,data) {
		client.ws.send(JSON.stringify(data),null);
	}
	,broadcast: function(data) {
		var json = JSON.stringify(data);
		var _g = 0;
		var _g1 = this.clients;
		while(_g < _g1.length) _g1[_g++].ws.send(json,null);
	}
	,broadcastExcept: function(skipped,data) {
		var json = JSON.stringify(data);
		var _g = 0;
		var _g1 = this.clients;
		while(_g < _g1.length) {
			var client = _g1[_g];
			++_g;
			if(client == skipped) {
				continue;
			}
			client.ws.send(json,null);
		}
	}
	,skipVideo: function(data) {
		if(this.videoList.items.length == 0) {
			return;
		}
		var _this = this.videoList;
		if(_this.items[_this.pos].url != data.skipVideo.url) {
			return;
		}
		this.videoList.skipItem();
		if(this.videoList.items.length > 0) {
			this.restartWaitTimer();
		}
		this.broadcast(data);
	}
	,checkPermission: function(client,perm) {
		if((client.group & 1) != 0) {
			this.checkBan(client);
		}
		var state = client.hasPermission(perm,this.config.permissions);
		if(!state) {
			this.send(client,{ type : "ServerMessage", serverMessage : { textId : "accessError"}});
		}
		return state;
	}
	,checkBan: function(client) {
		if((client.group & 8) != 0) {
			client.setGroupFlag(ClientGroup.Banned,false);
			return;
		}
		var ip = this.clientIp(client.req);
		var currentTime = new Date().getTime();
		var _g = 0;
		var _g1 = this.userList.bans;
		while(_g < _g1.length) {
			var ban = _g1[_g];
			++_g;
			if(ban.ip != ip) {
				continue;
			}
			var isOutdated = ban.toDate.getTime() < currentTime;
			client.setGroupFlag(ClientGroup.Banned,!isOutdated);
			if(isOutdated) {
				HxOverrides.remove(this.userList.bans,ban);
				haxe_Log.trace("" + client.name + " ban removed",{ fileName : "src/server/Main.hx", lineNumber : 935, className : "server.Main", methodName : "checkBan"});
				this.sendClientList();
			}
			break;
		}
	}
	,badNickName: function(name) {
		if(name.length > this.config.maxLoginLength) {
			return true;
		}
		if(name.length == 0) {
			return true;
		}
		if(this.matchHtmlChars.match(name)) {
			return true;
		}
		if(this.matchGuestName.match(name)) {
			return true;
		}
		if(Lambda.exists(this.clients,function(i) {
			return i.name.toLowerCase() == name;
		})) {
			return true;
		}
		return false;
	}
	,restartWaitTimer: function() {
		if(this.videoTimer.getTime() > 30) {
			this.saveFlashbackTime();
		}
		this.videoTimer.stop();
		if(this.waitVideoStart != null) {
			this.waitVideoStart.stop();
		}
		this.waitVideoStart = haxe_Timer.delay($bind(this,this.startVideoPlayback),3000);
	}
	,prepareVideoPlayback: function() {
		if(this.videoTimer.isStarted) {
			return;
		}
		this.loadedClientsCount++;
		if(this.loadedClientsCount == 1) {
			this.restartWaitTimer();
		}
		if(this.loadedClientsCount >= this.clients.length) {
			this.startVideoPlayback();
		}
	}
	,startVideoPlayback: function() {
		if(this.waitVideoStart != null) {
			this.waitVideoStart.stop();
		}
		this.loadedClientsCount = 0;
		this.broadcast({ type : "VideoLoaded"});
		this.videoTimer.start();
	}
	,saveFlashbackTime: function() {
		var time = this.videoTimer.getTime();
		if(Math.abs(this.flashbackTime - time) < 30) {
			return;
		}
		this.flashbackTime = time;
	}
	,loadFlashbackTime: function() {
		var time = this.videoTimer.getTime();
		this.videoTimer.setTime(this.flashbackTime);
		this.flashbackTime = time;
	}
	,isPlaylistLockedFor: function(client) {
		if(!this.videoList.isOpen) {
			if(!this.checkPermission(client,"lockPlaylist")) {
				return true;
			}
		}
		return false;
	}
	,__class__: server_Main
};
var server_Utils = function() { };
server_Utils.__name__ = true;
server_Utils.ensureDir = function(path) {
	if(!sys_FileSystem.exists(path)) {
		sys_FileSystem.createDirectory(path);
	}
};
server_Utils.isPortFree = function(port,callback) {
	var server = js_node_Http.createServer();
	var timeout = 1000;
	var status = false;
	server.setTimeout(timeout);
	server.once("error",function(err) {
		status = false;
		server.close();
	});
	server.once("timeout",function() {
		status = false;
		haxe_Log.trace("Timeout (" + timeout + "ms) occurred waiting for port " + port + " to be available",{ fileName : "src/server/Utils.hx", lineNumber : 26, className : "server.Utils", methodName : "isPortFree"});
		server.close();
	});
	server.once("listening",function() {
		status = true;
		server.close();
	});
	server.once("close",function() {
		callback(status);
	});
	server.listen(port);
};
server_Utils.getGlobalIp = function(callback) {
	var onError = function(e) {
		haxe_Log.trace("Warning: connection error, server is local.",{ fileName : "src/server/Utils.hx", lineNumber : 39, className : "server.Utils", methodName : "getGlobalIp"});
		callback("127.0.0.1");
	};
	var url = new js_node_url_URL("https://myexternalip.com/raw");
	js_node_Https.get({ timeout : 5000, protocol : url.protocol, host : url.host, path : url.pathname},function(r) {
		r.setEncoding("utf8");
		var data_b = "";
		r.on("data",function(chunk) {
			data_b += Std.string(chunk);
		});
		r.on("end",function(_) {
			callback(data_b);
		});
	}).on("error",onError).on("timeout",onError);
};
server_Utils.getLocalIp = function() {
	var ifaces = js_node_Os.networkInterfaces();
	var _g = 0;
	var _g1 = Reflect.fields(ifaces);
	while(_g < _g1.length) {
		var type = Reflect.field(ifaces,_g1[_g++]);
		var _g2 = 0;
		var _g3 = Reflect.fields(type);
		while(_g2 < _g3.length) {
			var iface = Reflect.field(type,_g3[_g2++]);
			if("IPv4" != iface.family || iface.internal != false) {
				continue;
			}
			return iface.address;
		}
	}
	return "127.0.0.1";
};
server_Utils.isOutOfRange = function(value,min,max) {
	if(!(value == null || isNaN(value) || value < min)) {
		return value > max;
	} else {
		return true;
	}
};
server_Utils.sortedPush = function(ids,id) {
	var _g_current = 0;
	while(_g_current < ids.length) if(id < ids[_g_current++]) {
		ids.splice(_g_current - 1,0,id);
		return;
	}
	ids.push(id);
};
var server_VideoTimer = function() {
	this.rate = 1.0;
	this.rateStartTime = 0.0;
	this.pauseStartTime = 0.0;
	this.startTime = 0.0;
	this.isStarted = false;
};
server_VideoTimer.__name__ = true;
server_VideoTimer.prototype = {
	start: function() {
		this.isStarted = true;
		var hrtime = process.hrtime();
		this.startTime = hrtime[0] + hrtime[1] / 1e9;
		this.pauseStartTime = 0;
		var hrtime = process.hrtime();
		this.rateStartTime = hrtime[0] + hrtime[1] / 1e9;
	}
	,stop: function() {
		this.isStarted = false;
		this.startTime = 0;
		this.pauseStartTime = 0;
	}
	,pause: function() {
		this.startTime += this.rateTime() - this.rateTime() * this.rate;
		var hrtime = process.hrtime();
		this.pauseStartTime = hrtime[0] + hrtime[1] / 1e9;
		this.rateStartTime = 0;
	}
	,play: function() {
		if(!this.isStarted) {
			this.start();
		}
		this.startTime += this.pauseTime();
		this.pauseStartTime = 0;
		var hrtime = process.hrtime();
		this.rateStartTime = hrtime[0] + hrtime[1] / 1e9;
	}
	,getTime: function() {
		if(this.startTime == 0) {
			return 0;
		}
		var hrtime = process.hrtime();
		return hrtime[0] + hrtime[1] / 1e9 - this.startTime - this.rateTime() + this.rateTime() * this.rate - this.pauseTime();
	}
	,setTime: function(secs) {
		var hrtime = process.hrtime();
		this.startTime = hrtime[0] + hrtime[1] / 1e9 - secs;
		var hrtime = process.hrtime();
		this.rateStartTime = hrtime[0] + hrtime[1] / 1e9;
		if(this.isPaused()) {
			this.pause();
		}
	}
	,isPaused: function() {
		if(this.isStarted) {
			return this.pauseStartTime != 0;
		} else {
			return true;
		}
	}
	,getRate: function() {
		return this.rate;
	}
	,setRate: function(rate) {
		if(!this.isPaused()) {
			this.startTime += this.rateTime() - this.rateTime() * this.rate;
			var hrtime = process.hrtime();
			this.rateStartTime = hrtime[0] + hrtime[1] / 1e9;
		}
		this.rate = rate;
	}
	,pauseTime: function() {
		if(this.pauseStartTime == 0) {
			return 0;
		}
		var hrtime = process.hrtime();
		return hrtime[0] + hrtime[1] / 1e9 - this.pauseStartTime;
	}
	,rateTime: function() {
		if(this.rateStartTime == 0) {
			return 0;
		}
		var hrtime = process.hrtime();
		return hrtime[0] + hrtime[1] / 1e9 - this.rateStartTime - this.pauseTime();
	}
	,__class__: server_VideoTimer
};
var sys_FileSystem = function() { };
sys_FileSystem.__name__ = true;
sys_FileSystem.exists = function(path) {
	try {
		js_node_Fs.accessSync(path);
		return true;
	} catch( _g ) {
		return false;
	}
};
sys_FileSystem.isDirectory = function(path) {
	try {
		return js_node_Fs.statSync(path).isDirectory();
	} catch( _g ) {
		return false;
	}
};
sys_FileSystem.createDirectory = function(path) {
	try {
		js_node_Fs.mkdirSync(path);
	} catch( _g ) {
		var _g1 = haxe_Exception.caught(_g).unwrap();
		if(_g1.code == "ENOENT") {
			sys_FileSystem.createDirectory(js_node_Path.dirname(path));
			js_node_Fs.mkdirSync(path);
		} else {
			var stat;
			try {
				stat = js_node_Fs.statSync(path);
			} catch( _g2 ) {
				throw _g1;
			}
			if(!stat.isDirectory()) {
				throw _g1;
			}
		}
	}
};
function $getIterator(o) { if( o instanceof Array ) return new haxe_iterators_ArrayIterator(o); else return o.iterator(); }
function $bind(o,m) { if( m == null ) return null; if( m.__id__ == null ) m.__id__ = $global.$haxeUID++; var f; if( o.hx__closures__ == null ) o.hx__closures__ = {}; else f = o.hx__closures__[m.__id__]; if( f == null ) { f = m.bind(o); o.hx__closures__[m.__id__] = f; } return f; }
$global.$haxeUID |= 0;
if(typeof(performance) != "undefined" ? typeof(performance.now) == "function" : false) {
	HxOverrides.now = performance.now.bind(performance);
}
if( String.fromCodePoint == null ) String.fromCodePoint = function(c) { return c < 0x10000 ? String.fromCharCode(c) : String.fromCharCode((c>>10)+0xD7C0)+String.fromCharCode((c&0x3FF)+0xDC00); }
String.prototype.__class__ = String;
String.__name__ = true;
Array.__name__ = true;
Date.prototype.__class__ = Date;
Date.__name__ = "Date";
var Int = { };
var Dynamic = { };
var Float = Number;
var Bool = Boolean;
var Class = { };
var Enum = { };
js_Boot.__toStr = ({ }).toString;
DateTools.DAY_SHORT_NAMES = ["Sun","Mon","Tue","Wed","Thu","Fri","Sat"];
DateTools.DAY_NAMES = ["Sunday","Monday","Tuesday","Wednesday","Thursday","Friday","Saturday"];
DateTools.MONTH_SHORT_NAMES = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"];
DateTools.MONTH_NAMES = ["January","February","March","April","May","June","July","August","September","October","November","December"];
Lang.langs = new haxe_ds_StringMap();
Lang.ids = ["en","ru"];
server_HttpServer.mimeTypes = (function($this) {
	var $r;
	var _g = new haxe_ds_StringMap();
	_g.h["html"] = "text/html";
	_g.h["js"] = "text/javascript";
	_g.h["css"] = "text/css";
	_g.h["json"] = "application/json";
	_g.h["png"] = "image/png";
	_g.h["jpg"] = "image/jpg";
	_g.h["gif"] = "image/gif";
	_g.h["svg"] = "image/svg+xml";
	_g.h["ico"] = "image/x-icon";
	_g.h["wav"] = "audio/wav";
	_g.h["mp3"] = "audio/mpeg";
	_g.h["mp4"] = "video/mp4";
	_g.h["woff"] = "application/font-woff";
	_g.h["ttf"] = "application/font-ttf";
	_g.h["eot"] = "application/vnd.ms-fontobject";
	_g.h["otf"] = "application/font-otf";
	_g.h["wasm"] = "application/wasm";
	$r = _g;
	return $r;
}(this));
server_HttpServer.hasCustomRes = false;
server_HttpServer.allowedLocalFiles = new haxe_ds_StringMap();
server_HttpServer.allowLocalRequests = false;
server_HttpServer.matchLang = new EReg("^[A-z]+","");
server_HttpServer.matchVarString = new EReg("\\${([A-z_]+)}","g");
server_HttpServer.ctrlCharacters = new EReg("[\\u0000-\\u001F\\u007F-\\u009F\\u2000-\\u200D\\uFEFF]","g");
server_Main.main();
})(typeof window != "undefined" ? window : typeof global != "undefined" ? global : typeof self != "undefined" ? self : this);
