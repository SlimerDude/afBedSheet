using afIoc
using afIocConfig
using afIocEnv

** We want to make IocEnv ourselves, but we don't want to incur the overhead of an override Id 
** This is 'cos most people will want to override our override in tests - it makes it all, um, icky!
internal class BedSheetEnvModule {
	@Build
	private static IocEnv buildIocEnv(RegistryMeta meta) {
		IocEnv(meta["afBedSheet.env"])
	}
	
	@Contribute { serviceType=FactoryDefaults# }
	internal static Void contributeFactoryDefaults(Configuration config, IocEnv iocEnv) {
		config[IocEnvConfigIds.env]		= iocEnv.env
		config[IocEnvConfigIds.isProd]	= iocEnv.isProd
		config[IocEnvConfigIds.isTest]	= iocEnv.isTest
		config[IocEnvConfigIds.isDev]	= iocEnv.isDev
	}

	@Contribute { serviceType=RegistryStartup# }
	internal static Void contributeRegistryStartup(Configuration conf, IocEnv iocEnv) {
		conf["afIocEnv.logEnv"] = |->| {
			iocEnv.logToInfo
		}
	}
}