using web
using afIoc
using afIocEnv::IocEnv
using afIocConfig::ApplicationDefaults

internal class TestBoom : AppTest {

	override Type[] iocModules	:= [T_AppModule#]
	override Void setup() { }
	
	Void testBoomPage() {
		iocModules	= [T_AppModule#, T_TestBoomMod1#]
		super.setup
		
		client.reqUri = reqUri(`/boom`)
		client.writeReq
		client.readRes
		
		verifyEq(client.resCode, 500)
		verify(client.resStr.contains("Stack Trace"))
		
		// check the handy err headers have been added in dev
		verifyNotNull(client.resHeaders["X-afBedSheet-errMsg"])
		verifyNotNull(client.resHeaders["X-afBedSheet-errType"])
		verifyNotNull(client.resHeaders["X-afBedSheet-errStackTrace"])

		// never cache error pages!
		verifyEq(client.resHeaders["Cache-Control"], "private, max-age=0, no-store")
	}

	Void testBoomPageInProdModeIsNotScary() {
		iocModules	= [T_AppModule#, T_TestBoomMod2#]
		super.setup

		client.reqUri = reqUri(`/boom`)
		client.writeReq
		client.readRes

		verifyEq(client.resCode, 500)
		verifyFalse(client.resStr.contains("Stack Trace"))
		
		// check the handy err headers are dev only
		verifyNull(client.resHeaders["X-afBedSheet-errMsg"])
		verifyNull(client.resHeaders["X-afBedSheet-errType"])
		verifyNull(client.resHeaders["X-afBedSheet-errStackTrace"])

		// never cache error pages!
		verifyEq(client.resHeaders["Cache-Control"], "private, max-age=0, no-store")
	}

	Void testErr500WithNoErr() {
		super.setup
		
		client.reqUri = reqUri(`/boom2`)
		client.writeReq
		client.readRes
		
		verifyEq(client.resCode, 500)
		verify(client.resStr.contains("Alien-Factory"))
	}

	Void testErrPagesWillNeverDie() {
		iocModules	= [T_AppModule#, T_TestBoomMod3#]
		super.setup
		
		client.reqUri = reqUri(`/boom`)
		client.writeReq
		client.readRes

		verifyEq(client.resCode, 500)
		verify(client.resStr.contains("Fantom Diagnostics"))
	}
}

internal class T_TestBoomMod1 {
	@Override
	static IocEnv overrideIocEnv() {
        IocEnv.fromStr("dev")
    }
}

internal class T_TestBoomMod2 {
	@Override
	static IocEnv overrideIocEnv() {
        IocEnv.fromStr("prod")
    }
}

internal class T_TestBoomMod3 {
	@Contribute { serviceType=ErrPrinterHtml# } 
	static Void contributeErrPrinterHtml(Configuration config) {
		config.set("Die", |WebOutStream out, Err? err| { throw Err("Ouch!") }).before("afBedSheet.requestDetails")
	}

	@Contribute { serviceType=ErrPrinterStr# } 
	static Void contributeErrPrinterStr(Configuration config) {
		config.set("Die", |StrBuf out, Err? err| { throw Err("Ouch!") }).before("afBedSheet.requestDetails")
	}
}