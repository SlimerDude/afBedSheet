using afIoc

internal const class AppModule {
	
	static Void bind(ServiceBinder binder) {
//		binder.bindImpl(Router#)
	}
	
	@Contribute { serviceType=Router# }
	static Void configureRouter(OrderedConfig config) {
		config.addUnordered(Route(`/textResult/plain`, 	TextPage#plain))
		config.addUnordered(Route(`/textResult/html`, 	TextPage#html))
		config.addUnordered(Route(`/textResult/xml`, 	TextPage#xml))
		
		
//		config.addUnordered(Route(`/pub/`, 	FileHandler#service))
	}

	@Contribute { serviceType=FileHandler# }
	static Void configureFileServer(MappedConfig config) {
//		config.addMapped(`/pub/`, `etc/web/`.toFile)
	}
	
}
