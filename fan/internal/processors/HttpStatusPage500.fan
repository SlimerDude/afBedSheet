using afIoc::Inject
using web::WebOutStream

** Shamelessly based on 'draft's err page
internal const class HttpStatusPage500 : HttpStatusProcessor {
	private const static Log log := Utils.getLog(HttpStatusPage500#)
	
	@Inject	private const HttpRequest  req
	@Inject	private const HttpResponse res
	
	internal new make(|This|in) { in(this) }
	
	override Obj process(HttpStatus httpStatus) {
	 	logErr(httpStatus.cause)

		buf := StrBuf()
		out := WebOutStream(buf.out)
			
		// send HTML response
		msg := httpStatus.cause?.msg ?: httpStatus.msg
		titleMsg := msg[0..(msg.index("\n"))]	// keep the title small - remove Ioc's Operations Trace
		
		out.docType
		out.html
		out.head
			.title.esc("${httpStatus.code} Error - $titleMsg").titleEnd
			.style.w("pre,td { font-family:monospace; } td:first-child { color:#888; padding-right:1em; }").styleEnd
		.headEnd
			
		out.body
		
		// TODO: only print the gubbins in devMode 
		
		// msg
		h1Msg := msg.split('\n').join("<br/>") { it.toXml }
		out.h1.w(h1Msg).h1End
		out.hr
			
		// req headers
		out.table
		req.headers.each |v,k| { out.tr.td.w(k).tdEnd.td.w(v).tdEnd.trEnd }
		out.tableEnd
		out.hr
		
		// TODO: print thread locals
			
		// stack trace
		if (httpStatus.cause != null) {
			out.pre
			out.writeChars(Utils.traceErr(httpStatus.cause, 50))
			out.preEnd
		}

		out.bodyEnd
		out.htmlEnd
		
		if (!res.isCommitted)	// a sanity check
			res.setStatusCode(httpStatus.code)
		return TextResponse.fromHtml(buf.toStr)
	}

	private Void logErr(Err? err) {
		if (err == null) return
		
		buf := StrBuf()
		buf.add("$err.msg - $req.uri\n")
		
		buf.add("\nHeaders:\n")
		req.headers.each |v,k| { buf.add("  $k: $v\n") }

		if (req.form != null) {
			buf.add("\nForm:\n")
			req.form.each |v,k| { buf.add("  $k: $v\n") }
		}
		
		buf.add("\nLocales:\n")
		req.locales.each |v,k| { buf.add("  $k: $v\n") }
		
		buf.add("\nStack Trace:\n")
		Utils.traceErr(err, 50).splitLines.each |s| { buf.add("$s\n") }
		log.err(buf.toStr.trim)
	}		
}
