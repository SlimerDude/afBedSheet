using afIoc
using afIocConfig
using afIocEnv

** We want to make IocEnv ourselves, but we don't want to incur the overhead of an override Id 
** This is 'cos most people will want to override our override in tests - it makes it all, um, icky!
internal const class BedSheetEnvModule {

	static Void defineModule(RegistryBuilder bob) {
		// Ssshhhh! No one needs to know!
		bob.suppressLogging = true
		bob.removeModule(IocEnvModule#)
		bob.suppressLogging = false
	}

	// define our own env from meta - so we can pass it through from BedSheetBuilder
	@Build { scopes=["root"] }	
	static IocEnv buildIocEnv(RegistryMeta meta) {
		IocEnv(meta["afBedSheet.env"])
	}
	
	@Contribute { serviceType=FactoryDefaults# }
	static Void contributeFactoryDefaults(Configuration config, IocEnv iocEnv) {
		config[IocEnvConfigIds.env]		= iocEnv.env
		config[IocEnvConfigIds.isProd]	= iocEnv.isProd
		config[IocEnvConfigIds.isTest]	= iocEnv.isTest
		config[IocEnvConfigIds.isDev]	= iocEnv.isDev
	}

	static Void onRegistryStartup(Configuration config) {
		config["afIocEnv.logEnv"] = |Scope scope| {
			iocEnv := (IocEnv) scope.serviceById(IocEnv#.qname)
			iocEnv.logToInfo
		}
	}
}
