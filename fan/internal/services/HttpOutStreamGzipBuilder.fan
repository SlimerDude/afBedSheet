using afIoc3::Inject
using afIoc3::Scope
using afIocConfig::Config

internal const class HttpOutStreamGzipBuilder : DelegateChainBuilder {
	@Inject	private const Scope 			scope
	@Inject	private const HttpRequest 		request
	@Inject	private const HttpResponse 		response
	@Inject	private const GzipCompressible 	gzipCompressible

	@Inject @Config { id="afBedSheet.gzip.disabled" }
	private const Bool gzipDisabled

	new make(|This|in) { in(this) } 
	
	override OutStream build(Obj delegate) {
		
		// if the response *could* be gzipped, then set the vary header
		// see http://blog.maxcdn.com/accept-encoding-its-vary-important/
		if (!gzipDisabled && !response.isCommitted && response.headers.vary == null)
			response.headers.vary = "Accept-Encoding"
		
		// do a sanity safety check - someone may have committed the stream behind our backs
		contentType := response.isCommitted ? null : response.headers.contentType
		acceptGzip	:= request.headers.acceptEncoding?.accepts("gzip") ?: false
		doGzip 		:= !gzipDisabled && !response.disableGzip && acceptGzip && gzipCompressible.isCompressible(contentType)		
		return		doGzip ? scope.build(GzipOutStream#, [delegate]) : delegate
	}
}
