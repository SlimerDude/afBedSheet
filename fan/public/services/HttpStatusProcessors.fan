using afIoc::Inject
using afIoc::Registry
using web::WebRes

** (Service) - Contribute your 'HttpStatusProcessor' implementations to this.
** 
** pre>
**   @Contribute { serviceType=HttpStatusProcessors# }
**   static Void contributeHttpStatusProcessors(MappedConfig conf) {
**     conf[404] = conf.autobuild(My404PageHandler#)
**   }
** <pre
** 
** If a processor for the given status code can not be found, the default page (processor) is used.
** The default page can be set in `afIocConfig::ApplicationDefaults`.
** 
** pre>
** @Contribute { serviceType=ApplicationDefaults# } 
** static Void configureApplicationDefaults(MappedConfig conf) {
**   conf[ConfigIds.httpStatusDefaultPage] = MyStatusPage()
** }
** <pre
** 
** @see `BedSheetConfigIds.defaultHttpStatusProcessor`
** 
** @uses a MappedConfig of 'Int:HttpStatusProcessor'
const mixin HttpStatusProcessors : ResponseProcessor {

	** Returns the result of processing the given `HttpStatus` as per the contributed processors.
	@NoDoc // not for public use
	override abstract Obj process(Obj response)
}

internal const class HttpStatusProcessorsImpl : HttpStatusProcessors {

	@Inject @Config { id="afBedSheet.httpStatusProcessors.default" }
	private const HttpStatusProcessor defaultHttpStatusProcessor
	
	private const Int:HttpStatusProcessor processors

	internal new make(Int:HttpStatusProcessor processors, |This|in) {
		in(this)
		this.processors = processors.toImmutable
	}

	** Returns the result of processing the given `HttpStatus` as per the contributed processors.
	override Obj process(Obj response) {
		httpStatus := (HttpStatus) response 
		return get(httpStatus.code).process(httpStatus)
	}	
	
	private HttpStatusProcessor get(Int status) {
		processors[status] ?: defaultHttpStatusProcessor
	}	
}
