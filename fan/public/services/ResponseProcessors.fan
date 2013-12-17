using afIoc::StrategyRegistry

** (Service) - Contribute your `ResponseProcessor` implementations to this.
const mixin ResponseProcessors {

	** Recursively processes the response object until 'true' or 'false' is returned
	@NoDoc // not for public use
	abstract Bool processResponse(Obj response)

}

internal const class ResponseProcessorsImpl : ResponseProcessors {

	private const StrategyRegistry processorStrategy

	internal new make(Type:ResponseProcessor responseProcessors) {
		processorStrategy = StrategyRegistry(responseProcessors)
	}

	override Bool processResponse(Obj response) {
		while (!response.typeof.fits(Bool#))
			response = get(response.typeof).process(response)
		return response
	}	

	private ResponseProcessor get(Type responseType) {
		processorStrategy.findBestFit(responseType)
	}
}
