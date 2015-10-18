using afIoc
using inet::IpAddr
using web::WebMod

** Use to programmatically create and launch BedSheet server instances.
**
**   syntax: fantom 
**   useDevProxy := true
**   BedSheetBuilder(AppModule#).startWisp(8069, useDevProxy, "dev")
** 
class BedSheetBuilder {
	private static const Log log 	:= Utils.getLog(BedSheetBuilder#)
	private IpAddr? _ipAddr
	private Type[]	_moduleTypes	:= Type[,]
	private Obj[][]	_pods			:= Obj[][,]

	
	** The HTTP port to run the app on. Defaults to '8069'
	Int port {
		get { options[BsConstants.meta_appPort] }
		set { options[BsConstants.meta_appPort] = it }
	}

	** Options for IoC 'RegistryBuilder'.
	** Read only.
	Str:Obj? options := Str:Obj?[:] { it.caseInsensitive = true } {
		private set
	}
	
	private new makeFromNothing() { }
	
	** Creates a 'BedSheetBuilder'. 
	** 'modOrPodName' may be a pod name or a qualified 'AppModule' type name. 
	** 'addPodDependencies' is only used if a pod name is passed in.
	new makeFromName(Str modOrPodName, Bool addPodDependencies := true) {
		port = 0
		_initModules(modOrPodName, addPodDependencies)
		_initBanner()
	}
	
	** Creates a 'BedSheetBuilder' from the given 'AppModule'.
	new makeFromAppModule(Type appModule) : this.makeFromName(appModule.qname, true) { }
	
	** Adds an IoC module to the registry. 
	This addModule(Type moduleType) {
		_moduleTypes.add(moduleType)
		return this
	}
	
	** Adds many IoC modules to the registry. 
	This addModules(Type[] modules) {
		_moduleTypes.addAll(modules)
		return this
	}
	
	** Inspects the [pod's meta-data]`docLang::Pods#meta` for the key 'afIoc.module'. This is then 
	** treated as a CSV list of (qualified) module type names to load.
	** 
	** If 'addDependencies' is 'true' then the pod's dependencies are also inspected for IoC 
	** modules.
	**  
	** Convenience for 'registryBuilder.addModulesFromPod()'
	This addModulesFromPod(Str podName, Bool addDependencies := true) {
		_pods.add([podName, addDependencies])
		return this		
	}
	
	** Sets a value in the 'options' map. 
	** Returns 'this' so it may be used as a builder method. 		
	This setOption(Str name, Obj? value) {
		options.set(name, value)
		return this
	}

	** The application name. 
	** Taken from the app pod's 'proj.name' meta, or the pod name if the meta doesn't exist.
	** Read only.
	Str appName() {
		options[BsConstants.meta_appName]		
	}
	
	** Sets the local IP address that Wisp should bind to, or set to 'null' for the default.
	** 
	** This is useful when deploying your application to [Open Shift]`https://developers.openshift.com/en/diy-overview.html` 
	** or similar where the local IP address is mandated. 
	** See the Fantom Forum topic: [IP address for afBedSheet]`http://fantom.org/forum/topic/2399`.
	This setIpAddress(IpAddr? ipAddr) {
		this._ipAddr = ipAddr
		return this
	}

	** Builds the IoC 'Registry'. 
	Registry build() {
		bob := RegistryBuilder()
		_pods.each { bob.addModulesFromPod(it[0], it[1]) }
		_moduleTypes.each { bob.addModule(it) }
		options.each |v, k| { bob.options[k] = v }
		return bob.build
	}

	** Convenience method to start a Wisp server running 'BedSheetWebMod'.
	Int startWisp(Int port := 8069, Bool proxy := false, Str? env := null) {
		this.port = port
		options["afBedSheet.env"] = env
		watchAllPods := options[BsConstants.meta_watchAllPods]?.toStr?.toBool(false) ?: false
		mod := proxy ? ProxyMod(this, port, watchAllPods) : BedSheetBootMod(this)
		return runWebMod(mod, port, _ipAddr)
	}

	This enableRequestLogs() {
		this.typeof.pod.log.level = LogLevel.debug
		return this
	}
	
	** Hook to run a fully configured BedSheet 'WebMod'.
	@NoDoc
	virtual Int runWebMod(WebMod webMod, Int port, IpAddr? ipAddr) {
		WebModRunner().run(webMod, port, ipAddr)
	}

	@NoDoc // for serialisation
	Str toStringy() {
		mods := _moduleTypes
		pods := _pods
		opts := options.dup
		opts.remove("afIoc.bannerText")
		
		appPod := (Pod) opts[BsConstants.meta_appPod]
		opts[BsConstants.meta_appPodName] = appPod.name
		opts.remove(BsConstants.meta_appPod)
		
		buf := Buf()
		Zip.gzipOutStream(buf.out).writeObj([mods, pods, opts]).close
		return buf.flip.toBase64.replace("/", "_").replace("+", "-")
	}

	@NoDoc // for serialisation
	static BedSheetBuilder fromStringy(Str str) {
		b64  := str.replace("_", "/").replace("-", "+")
		data := (Obj[]) Zip.gzipInStream(Buf.fromBase64(b64).in).readObj
		
		mods := (Type[])	data[0]
		pods := (Obj[][])	data[1]
		opts := (Str:Obj?)	data[2]
		
		appPodName	:= (Str) opts[BsConstants.meta_appPodName]
		opts[BsConstants.meta_appPod] = Pod.find(appPodName, true)
		opts.remove(BsConstants.meta_appPodName)

		// reinstate appPod
		bob := BedSheetBuilder()
		bob._moduleTypes	= mods
		bob._pods			= pods.map { [it[0], it[1]] }
		bob.options			= opts
		bob._initBanner
		
		return bob
	}
	
	private Void _initModules(Str moduleName, Bool transDeps) {
		Pod?  pod
		Type? mod
		
		// Pod name given...
		// lots of start up checks looking for pods and modules... 
		// see https://bitbucket.org/SlimerDude/afbedsheet/issue/1/add-a-warning-when-no-appmodule-is-passed
		if (!moduleName.contains("::")) {
			pod = Pod.find(moduleName, true)
			log.info(BsLogMsgs.bedSheetWebMod_foundPod(pod))
			mods := _findModFromPod(pod)
			mod = mods.first
			
			if (!transDeps)
				log.info("Suppressing transitive dependencies...")
			addModulesFromPod(pod.name, transDeps)
			mods.each { addModule(it) }
		}

		// AppModule name given...
		if (moduleName.contains("::")) {
			mod = Type.find(moduleName, true)
			log.info(BsLogMsgs.bedSheetWebMod_foundType(mod))
			pod = mod.pod
			
			addModule(mod)
		}

		// we're screwed! No module = no web app!
		if (mod == null)
			log.warn(BsLogMsgs.bedSheetWebMod_noModuleFound)
		
		// A simple thing - ensure the BedSheet module is added! 
		// (transitive dependencies are added explicitly via @SubModule)
		addModule(BedSheetModule#)

		projName := (Str?) null
		try pod?.meta?.get("proj.name")
		catch { /* JS F4 Errs */ }

		options[BsConstants.meta_appName]	= (projName ?: pod?.name) ?: "Unknown"
		options[BsConstants.meta_appPod]	= pod
		options[BsConstants.meta_appModule]	= mod
	}

	** Looks for an 'AppModule' in the given pod. 
	private static Type[] _findModFromPod(Pod pod) {
		mods := Type#.emptyList
		modNames := pod.meta["afIoc.module"]
		if (modNames != null) {
			mods = modNames.split.map { Type.find(it, true) }
			log.info(BsLogMsgs.bedSheetWebMod_foundType(mods.first))
		} else {
			// we have a pod with no module meta... so lets guess the name 'AppModule'
			mod := pod.type("AppModule", false)
			if (mod != null) {
				mods = [mod]
				log.info(BsLogMsgs.bedSheetWebMod_foundType(mod))
				log.warn(BsLogMsgs.bedSheetWebMod_addModuleToPodMeta(pod, mod))
			}
		}
		return mods
	}
	
	private Void _initBanner() {
		bannerText := _easterEgg("Alien-Factory BedSheet v${BedSheetWebMod#.pod.version}, IoC v${Registry#.pod.version}")
		options["afIoc.bannerText"] = bannerText		
	}

	private static Str _easterEgg(Str title) {
		quotes := _loadQuotes
		if (quotes.isEmpty || (Int.random(0..8) != 2))
			return title
		return quotes[Int.random(0..<quotes.size)]
	}

	private static Str[] _loadQuotes() {
		BedSheetWebMod#.pod.file(`/res/misc/quotes.txt`).readAllLines.exclude { it.isEmpty || it.startsWith("#")}
	}
}
