using afIoc::Inject
using web::Cookie

** (Service) - An injectable 'const' version of [WebRes]`web::WebRes`.
** 
** This will always refers to the current web response.
const mixin HttpResponse {

	** Get / set the HTTP status code for this response.
	** Setter throws Err if response is already committed.
	** 
	** @see `web::WebRes.statusCode`
	abstract Int statusCode
	
	** Map of HTTP response headers.  You must set all headers before you access out() for the 
	** first time, which commits the response.  
	** 
	** @see 
	**  - `web::WebRes.headers`
	**  - `http://en.wikipedia.org/wiki/List_of_HTTP_header_fields#Responses`
	abstract HttpResponseHeaders headers()
	
	** Return true if this response has been committed.  A committed response has written its 
	** response headers, and can no longer modify its status code or headers.  A response is 
	** committed the first time that `out` is called.
	** 
	** @see `web::WebRes.isCommitted`
	abstract Bool isCommitted()
	
	** Returns the 'OutStream' for this response. 
	** Should current settings allow, the 'OutStream' is automatically gzipped.
	** 
	** @see `web::WebRes.out`
	abstract OutStream out()
	
	** Set to 'true' to disable gzip compression for this response.
	abstract Bool disableGzip
	
	** Set to 'true' to disable buffering for this response.
	abstract Bool disableBuffering

	** Directs the client to display a 'save as' dialog by setting the 'Content-Disposition' HTTP 
	** response header. 
	** 
	** The 'Content-Type' HTTP response header is set to the MimeType derived from the fileName's 
	** extension.
	** 
	** @see `HttpResponseHeaders.contentDisposition`
	abstract Void saveAsAttachment(Str fileName)
}

** Wraps a given `HttpResponse`, delegating all its methods. 
** You may find it handy to use when contributing to the 'HttpResponse' delegate chain.
@NoDoc
const class HttpResponseWrapper : HttpResponse {
	const 	 HttpResponse res
	new 	 make(HttpResponse res) 			 { this.res = res 	} 
	override HttpResponseHeaders headers() 		 { res.headers		}
	override Bool isCommitted() 				 { res.isCommitted	}
	override OutStream out() 					 { res.out			}
	override Void saveAsAttachment(Str fileName) { res.saveAsAttachment(fileName) }
	override Bool disableGzip {
		get { res.disableGzip }
		set { res.disableGzip = it}
	}
	override Bool disableBuffering {
		get { res.disableBuffering }
		set { res.disableBuffering = it}
	}
	override Int statusCode {
		get { res.statusCode }
		set { res.statusCode = it }
	}
}


internal const class HttpResponseImpl : HttpResponse {
	
	@Inject  const |->RequestState|		reqState
	override const HttpResponseHeaders	headers

	new make(|This|in) { 
		in(this)
		this.headers = HttpResponseHeaders(|->Str:Str| {
			// cache the headers so we can access / read it after the response has been committed - handy for logging
			// note this only works while 'webRes.headers' returns the actual map used, and not a copy
			reqState().responseHeaders
		}, |->| {
			if (reqState().webRes.isCommitted)
				throw Err("HTTP Response has already been committed")
		})
	} 

	override Bool disableGzip {
		get { reqState().disableGzip ?: false }
		set { reqState().disableGzip = it}
	}
	override Bool disableBuffering {
		get { reqState().disableBuffering ?: false }
		set { reqState().disableBuffering = it}
	}
	override Int statusCode {
		get { reqState().webRes.statusCode }
		set { reqState().webRes.statusCode = it }
	}	
	override Bool isCommitted() {
		reqState().webRes.isCommitted
	}
	override OutStream out() {
		reqState().out
	}
	override Void saveAsAttachment(Str fileName) {
		headers.contentDisposition = "attachment; filename=${fileName}"
		headers.contentType = fileName.toUri.mimeType
	}
}

