
@NoDoc	// this class seems too important to keep internal!
const class RegexRoute : Route {
	private static const Str star	:= "(.*?)"

	** The uri regex this route matches.
	override const Regex routeRegex

	** The response to be returned from this route. 
	override const Obj response

	** HTTP method used for this route
	override const Str httpMethod

	private  const Regex[] 	httpMethodGlob
	private  const Bool		matchAllSegs
	private  const Bool		matchToEnd
	private  const Bool		isGlob
	internal const RouteResponseFactory	factory

	new makeFromGlob(Uri urlGlob, Obj response, Str httpMethod := "GET") {
	    if (urlGlob.scheme != null || urlGlob.host != null || urlGlob.port!= null )
			throw ArgErr(BsErrMsgs.route_shouldBePathOnly(urlGlob))
	    if (!urlGlob.isPathAbs)
			throw ArgErr(BsErrMsgs.route_shouldStartWithSlash(urlGlob))

		uriGlob	:= urlGlob.toStr
		regex	:= "(?i)^"
		uriGlob.each |c, i| {
			if (c.isAlphaNum || c == '?' || c == '\\')
				regex += c.toChar
			else if (c == '*')  
				regex += star
			else 
				regex += ("\\" + c.toChar)
		}
		
		matchAllSegs	:= false
		matchToEnd		:= false
		if (uriGlob.endsWith("***")) {
			regex = regex[0..<-star.size*3] + "(.*)"
			matchToEnd	= true
			
		} else if (uriGlob.endsWith("**")) {
			regex = regex[0..<-star.size*2] + "(.*?)\\/?"
			matchAllSegs = true
		}
		
		regex += "\$"
		
		this.routeRegex 	= Regex.fromStr(regex)
		this.response 		= response
		this.factory 		= wrapResponse(response)
		this.httpMethod 	= httpMethod
		// split on both space and ','
		this.httpMethodGlob	= httpMethod.split.map { it.split(',') }.flatten.map { Regex.glob(it) }
		this.matchToEnd		= matchToEnd
		this.matchAllSegs	= matchAllSegs
		this.isGlob			= true
		this.factory.validate(routeRegex, urlGlob, matchAllSegs)
	}

	new makeFromRegex(Regex uriRegex, Obj response, Str httpMethod := "GET", Bool matchAllSegs := false) {
		this.routeRegex 	= uriRegex
		this.response 		= response
		this.factory 		= wrapResponse(response)
		this.httpMethod 	= httpMethod
		// split on both space and ','
		this.httpMethodGlob	= httpMethod.split.map { it.split(',') }.flatten.map { Regex.glob(it) }
		this.matchAllSegs	= matchAllSegs
		this.isGlob			= false
		this.factory.validate(routeRegex, null, matchAllSegs)
	}

	** Returns a response object should the given uri (and http method) match this route. Returns 'null' if not.
	override Obj? match(HttpRequest httpRequest) {
		if (!httpMethodGlob.any { it.matches(httpRequest.httpMethod) })
			return null

		uriSegs := matchUri(httpRequest.url)
		if (uriSegs == null)
			return null

		// decode the Str *from* URI standard form, see http://fantom.org/sidewalk/topic/2357
		// from here on we don't expect the Strs to have escaping '\' backslashes, so we take them out.
		strSegs := uriSegs.map { decodeUri(it) }
		
		if (!factory.matchSegments(strSegs))
			return null
		
		return factory.createResponse(strSegs)
	}

	** Returns null if the given uri does not match the uri regex
	internal Str?[]? matchUri(Uri uri) {
		matcher := routeRegex.matcher(uri.pathOnly.toStr)
		find := matcher.find 
		if (!find)
			return null
		
		groups := Str[,]
		
		// use find as supplied Regex may not have ^...$
		while (find) {
			groupCunt := matcher.groupCount
			if (groupCunt == 0)
				return Str#.emptyList
			
			(1..groupCunt).each |i| {
				g := matcher.group(i)
				groups.add(g)
			}
		
			find = matcher.find
		}
		
		if (matchAllSegs && !groups.isEmpty && groups.last.contains("/")) {
			groups.addAll(splitPath(groups.removeAt(-1)))				
		}
		
		if (isGlob && !matchToEnd && !matchAllSegs && groups.last.contains("/")) {
			// ensure all '/' chars are escaped
			if (groups.last.split('/')[0..<-1].any { it.getSafe(-1) != '\\' })
				return null
		}

		// convert empty Strs to nulls
		// see http://fantom.org/sidewalk/topic/2178#c14077
		// 'seg' needs to be named to return an instance of Str[], not Obj[] -> important for method injection
		return groups.map |Str seg->Str?| { seg.isEmpty ? null : seg }
	}
	
	** Tricky... We need to split on '/' but not an escaped '\/'
	static internal Str[] splitPath(Str uriPath) {
		split := uriPath.split('/')

		// attempt to re-join segs that were escaped
		segs := Str[,]
		split.each |seg| {
			// beware of escaped '\' !!!
			if (!segs.isEmpty && segs[-1].getSafe(-1) == '\\' && segs[-1].getSafe(-2) != '\\')
				segs[-1] = segs.last + "/" + seg
			else
				segs.add(seg)
		}
		return segs
	}

	** Decode the Str *from* URI standard form
	** see http://fantom.org/sidewalk/topic/2357
	private static Str? decodeUri(Str? str) {
		if (str == null || !str.chars.contains('\\'))
			return str
		buf := StrBuf(str.size)
		escaped := false
		str.chars.each |char| {
			escaped = (char == '\\' && !escaped)
			if (!escaped)
				buf.addChar(char)
		}
		return buf.toStr
	}
	
	private RouteResponseFactory wrapResponse(Obj response) {
		if (response.typeof.fits(RouteResponseFactory#))
			return response
		if (response.typeof.fits(Method#))
			return MethodCallFactory(response)
		return NoOpFactory(response)
	}
	
	override Str matchHint() {
		"${httpMethod} - ${routeRegex}"
	}
	
	override Str responseHint() {
		factory.toStr
	}
	
	override Str toStr() {
		"${httpMethod.justl(4)} - $routeRegex : $factory"
	}
}

** Keep public 'cos it could prove useful!
@NoDoc
const mixin RouteResponseFactory {

	abstract Bool matchSegments(Str?[] segments)

	abstract Obj? createResponse(Str?[] segments)

	virtual Void validate(Regex routeRegex, Uri? routeGlob, Bool matchAllSegs) { }

	static Bool matchesMethod(Method method, Str?[] segments) {
		if (segments.size > method.params.size)
			return false
		return method.params.all |Param param, i->Bool| {
			if (i >= segments.size)
				return param.hasDefault
			return (segments[i] == null) ? param.type.isNullable : true
		}
	}

	static Bool matchesParams(Type[] params, Str?[] segments) {
		if (segments.size > params.size)
			return false
		return params.all |Type param, i->Bool| {
			if (i >= segments.size)
				return false
			return (segments[i] == null) ? param.isNullable : true
		}
	}
}

internal const class MethodCallFactory : RouteResponseFactory {
	const Method method
	
	new make(Method method) {
		this.method = method
	}
	
	override Bool matchSegments(Str?[] segments) {
		matchesMethod(method, segments)
	}

	override Obj? createResponse(Str?[] segments) {
		MethodCall(method, segments)
	}

	override Void validate(Regex routeRegex, Uri? routeGlob, Bool matchAllSegs) {
		args := (Int) routeRegex.toStr.split('/').reduce(0) |Int count, arg -> Int| {
			count + (arg.contains(".*") ? 1 : 0)
		}
		if (args > method.params.size)
			throw ArgErr(BsErrMsgs.route_uriWillNeverMatchMethod(routeRegex, routeGlob, method))
		
		if (!matchAllSegs) {
			defs := (Int) method.params.reduce(0) |Int count, param -> Int| { count + (param.hasDefault ? 0 : 1) }
			if (args < defs)
				throw ArgErr(BsErrMsgs.route_uriWillNeverMatchMethod(routeRegex, routeGlob, method))
		}
	}

	override Str toStr() { "-> $method.qname" }
}

internal const class NoOpFactory : RouteResponseFactory {
	const Obj? response
	new make(Obj? response) { this.response = response }
	override Bool matchSegments(Str?[] segments) { true	}
	override Obj? createResponse(Str?[] segments) { response }
	override Str toStr() { response.toStr }
}