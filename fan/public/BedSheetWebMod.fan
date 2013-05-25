using concurrent::AtomicRef
using web
using afIoc

const class BedSheetWebMod : WebMod {

	const Str moduleName
	const Bool devMode
	
	const AtomicRef	registry	:= AtomicRef()
	
	Registry reg {
		get { registry.val }
		set { }
	}
	
	// pass registry startup optoins?
	new make(Str moduleName, Bool devMode) {
		this.moduleName = moduleName
		this.devMode	= devMode
	}
	
	
	override Void onService() {
		req.mod = this
		stashManager := (ThreadStashManager) reg.dependencyByType(ThreadStashManager#)

		try {
			router := (Router) reg.dependencyByType(Router#)
			
			// match req to Route
			match := router.match(req.modRel, req.method)
			req.stash["bedSheet.routeMatch"] = match 

//			if (match == null) throw DraftErr(404)
			if (match == null) throw Err("404")

			// delegate to Route.handler
			h := match.route.handler
			args := h.params.isEmpty ? null : [match.args]
			
			weblet := null
			
			
			// TODO: have cache of |func|s that either build per thread or return cache
			// naa, have router take a serive type, and have a service interface?
			try {
				weblet = reg.dependencyByType(h.parent)
			} catch (IocErr e) {
				weblet = reg.autobuild(h.parent) 
			}
			result := weblet.trap(h.name, args)

			// TODO: if (result == null), we assume all handled??? 
			
			if (result != null) {
				
			resProSrc := (ResultProcessorSource) reg.dependencyByType(ResultProcessorSource#)
			resPro 		:= resProSrc.getResultProcessor(result.typeof)
			resPro.process(result)
				
			}

			// we don't flush ot close because if, say for example, we send a 304 Not Modified, then there's nothing to close!
//			try { res.out.flush } catch (IOErr ioe) { }
			// make sure everyone tidies up after themselves
//			res.out.close
		}
		catch (Err err) {
			buf:=StrBuf()
			err.trace(Env.cur.out, ["maxDepth":500])
			
			// TODO: contribute Err handlers
//			if (err isnot DraftErr) err = DraftErr(500, err)
//			onErr(err)
		} finally {
			stashManager.cleanUp
		}
	}
	
	override Void onStart() {
		
		Env.cur.err.printLine("hello!")//TODO:log

		pod := Pod.find(moduleName, false)
		mod := Type.find(moduleName, false)

		bob := RegistryBuilder()
		
		if (pod != null)
			bob.addModulesFromDependencies(pod, true)
		
		if (mod != null) {
			bob.addModule(BedSheetModule#)
			bob.addModule(mod)
		}
		
		reg := bob.build.startup
		
		registry.val = reg
	}

	override Void onStop() {
		reg := (Registry?) registry.val
		reg?.shutdown
		Env.cur.err.printLine("Goodbye!")	//TODO:log
	}
}
