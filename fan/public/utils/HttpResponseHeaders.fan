using web::WebUtil

** A wrapper for HTTP response headers with accessors for commonly used headings.
** 
** @see `https://en.wikipedia.org/wiki/List_of_HTTP_header_fields`
const class HttpResponseHeaders {
	
	private const static Log	log				:= HttpResponseHeaders#.pod.log
	private const static Int 	maxTokenSize	:= 4096 - 10	// taken from web::WebUtil.maxTokenSize. -10 for good measure!
	private const |->Str:Str|	getHeaders
	private const |->| 			checkUncommitted
	private const Bool 			oldWispVer		:= Pod.find("wisp").version <= Version("1.0.66")

	internal new make(|->Str:Str| getHeaders, |->| checkUncommitted) {
		this.getHeaders = getHeaders
		this.checkUncommitted = checkUncommitted
	}
	
	** Tells all caching mechanisms from server to client whether they may cache this object. It is 
	** measured in seconds.
	** 
	** Example: 'Cache-Control: max-age=3600'
	Str? cacheControl {
		get { get("Cache-Control") }
		set { addOrRemove("Cache-Control", it) }
	}

	** The type of encoding used on the data.
	** 
	** Example: 'Content-Encoding: gzip'
	Str? contentEncoding {
		get { get("Content-Encoding") }
		set { addOrRemove("Content-Encoding", it) }
	}

	** Usually used to direct the client to display a 'save as' dialog.
	** 
	** Example: 'Content-Disposition: Attachment; filename=example.html'
	** 
	** @see `http://tools.ietf.org/html/rfc6266`
	Str? contentDisposition {
		get { get("Content-Disposition") }
		set { addOrRemove("Content-Disposition", it) }
	}

	** The length of the response body in octets (8-bit bytes).
	** 
	** Example: 'Content-Length: 348'
	Int? contentLength {
		get { makeIfNotNull("Content-Length") { Int.fromStr(it) }}
		set { addOrRemove("Content-Length", it?.toStr) }
	}

	** The MIME type of this content.
	** 
	** Example: 'Content-Type: text/html; charset=utf-8'
	MimeType? contentType {
		get { makeIfNotNull("Content-Type") { MimeType(it, true) }}
		set { addOrRemove("Content-Type", it?.toStr) }
	}

	** An identifier for a specific version of a resource, often a message digest.
	** 
	** Example: 'ETag: "737060cd8c284d8af7ad3082f209582d"'
	Str? eTag {
		get { makeIfNotNull("ETag") { WebUtil.fromQuotedStr(it) }}
		set { addOrRemove("ETag", (it==null) ? null : WebUtil.toQuotedStr(it)) }
	}
	
	** Gives the date/time after which the response is considered stale.
	** 
	** Example: 'Expires: Thu, 01 Dec 1994 16:00:00 GMT'
	DateTime? expires {
		get { makeIfNotNull("Expires") { DateTime.fromHttpStr(it, true)} }
		set { addOrRemove("Expires", it?.toHttpStr) }
	}

	** The last modified date for the requested object, in RFC 2822 format.
	** 
	** Example: 'Last-Modified: Tue, 15 Nov 1994 12:45:26 +0000'
	DateTime? lastModified {
		get { makeIfNotNull("Last-Modified") { DateTime.fromHttpStr(it, true)} }
		set { addOrRemove("Last-Modified", it?.toHttpStr) }
	}

	** Used in redirection, or when a new resource has been created.
	** 
	** Example: 'Location: http://www.w3.org/pub/WWW/People.html'
	Uri? location {
		get { makeIfNotNull("Location") { Uri.decode(it, true) } }
		set { addOrRemove("Location", it?.encode) }
	}

	** Implementation-specific headers.
	** 
	** Example: 'Pragma: no-cache'
	Str? pragma {
		get { get("Pragma") }
		set { addOrRemove("Pragma", it) }
	}

	** Tells downstream proxies how to match future request headers to decide whether the cached 
	** response can be used rather than requesting a fresh one from the origin server.
	** 
	** Example: 'Vary: Accept-Encoding'
	** 
	** @see [Accept-Encoding, It’s Vary important]`http://blog.maxcdn.com/accept-encoding-its-vary-important/`
	Str? vary {
		get { get("Vary") }
		set { addOrRemove("Vary", it) }
	}

	** Clickjacking protection, set to:
	**  - 'deny' - no rendering within a frame, 
	**  - 'sameorigin' - no rendering if origin mismatch
	** 
	** Example: 'X-Frame-Options: deny'
	Str? xFrameOptions {
		get { get("X-Frame-Options") }
		set { addOrRemove("X-Frame-Options", it) }
	}

	** Cross-site scripting (XSS) filter.
	** 
	** Example: 'X-XSS-Protection: 1; mode=block'
	Str? xXssProtection {
		get { get("X-XSS-Protection") }
		set { addOrRemove("X-XSS-Protection", it) }
	}

	** Returns the named response header.
	@Operator
	Str? get(Str name) {
		getHeaders()[name]
	}

	** Sets a response head to the given value.
	** 
	** If the given value is 'null' then it is removed.
	@Operator
	Void set(Str name, Str? value) {
		if (value == null) {
			remove(name)
			return
		}
			
		checkUncommitted()

		maxTokenSize := maxTokenSize
		valueSize	 := value.size
		if (oldWispVer) {
			// multiple lines in the header need to be prefixed with whitespace
			// see http://fantom.org/forum/topic/2427
			if (value.containsChar('\n'))
				value = value.splitLines.join("\n ")

		} else
			// newer Wisps will append whitespace for us, we just need to adjust our calculations
			maxTokenSize -= value.numNewlines * 2

		// 4096 limit is imposed by web::WebUtil.token() when reading headers,
		// encountered by the BedSheet Dev Proxy when returning the request back to the browser
		if (value.size > maxTokenSize) {
			log.warn("HTTP Response Header '${name}' is too large at $value.size chars, trimming to ${maxTokenSize}...")
			value = value[0..<maxTokenSize].trimEnd
		}
		
		getHeaders()[name] = value
	}
	
	** Removes a response header.
	Str? remove(Str name) {
		checkUncommitted()
		return getHeaders().remove(name)
	}

	** Returns a read / write map of the response headers.
	**  
	** It is better to use 'set()' / 'remove()' / or one of the setters on this 'HttpResponseHeaders' instance to change response values.
	** This allows us to check if the response has already been committed before updating header values.
	** 
	** Think of this 'map' as a *get-out-jail* card.
	Str:Str map() {
		getHeaders()
	}

	@NoDoc
	override Str toStr() {
		getHeaders().toStr
	}
	
	private Obj? makeIfNotNull(Str name, |Obj->Obj| func) {
		val := get(name)
		return (val == null) ? null : func(val)
	}

	private Void addOrRemove(Str name, Str? value) {
		if (value == null)
			remove(name)
		else
			set(name, value)
	}
}
