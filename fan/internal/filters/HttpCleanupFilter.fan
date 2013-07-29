using afIoc::Inject
using afIoc::Registry
using afIoc::ThreadStashManager

** Ensures the `HttpOutStream` is closed and cleans up all data held in the current thread / 
** request. As such, this must always be the first filter in the pipeline.   
internal const class HttpCleanupFilter : HttpPipelineFilter {
	
	@Inject	private const Registry				registry
	@Inject	private const ThreadStashManager	stashManager
	@Inject	private const HttpResponse			httpResponse	

	new make(|This|in) { in(this) }
	
	override Bool service(HttpPipeline handler) {
		try {
			return handler.service
		} finally {
			httpResponse.out.close
			stashManager.cleanUpThread
		}
	}
}