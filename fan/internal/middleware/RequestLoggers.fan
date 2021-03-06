using afIoc

@NoDoc	// Don't overwhelm the masses
const class RequestLoggers : Middleware {
	
	@Inject
	private const Log				log
	internal const RequestLogger[]	requestLoggers
	
	new make(RequestLogger[] requestLoggers, |This|in) {
		in(this)
		this.requestLoggers = requestLoggers
	}
	
	override Void service(MiddlewarePipeline pipeline) {
		for (i := 0; i < requestLoggers.size; ++i) {
			requestLogger := requestLoggers[i]
			try requestLogger.logIncoming
			catch (Err err)
				log.err("Error in ${requestLogger.typeof.qname}.logIncoming() - ignoring...", err)			
		}
		
		pipeline.service

		for (i := 0; i < requestLoggers.size; ++i) {
			requestLogger := requestLoggers[i]
			try requestLogger.logOutgoing
			catch (Err err)
				log.err("Error in ${requestLogger.typeof.qname}.logOutgoing() - ignoring...", err)				
		}
	}
}

@NoDoc	// Don't overwhelm the masses
const class BasicRequestLogger : RequestLogger {
	@Inject private const HttpRequest		httpRequest
	@Inject private const HttpResponse		httpResponse
	@Inject private const |->RequestState|	reqStateFn
	@Inject private const Log				log
			private const Int				minLogWidth
	
	new make(Int minLogWidth, |This|in) {
		in(this)
		this.minLogWidth = minLogWidth
	}

	override Void logOutgoing() {
		if (log.isDebug) {
			// attempt to keep the standard debug line at 120 chars (120 isn't special, it just seems to be a manageable width)
			timeTaken := Duration.now.minus(reqStateFn().startTime)
			// 42 is the preamble length ... [20:33:47 04-Oct-15] [debug] [afBedSheet] 
			// 16 is the suffix ............ -> 200 (in 17ms)
			msg := "${httpRequest.httpMethod.justl(4)} ${httpRequest.url.encode}".padr(minLogWidth - 42 - 16, '-') + "-> ${httpResponse.statusCode} (in ${timeTaken.toLocale.justr(4)})"
			log.debug(msg)
		}
	}
}
