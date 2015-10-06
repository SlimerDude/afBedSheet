using afIoc
using afConcurrent

@NoDoc	// Advanced use only
const class ObjCache {
	private const Type[] 		serviceTypeCache
	private const AtomicMap		constTypeCache		:= AtomicMap()
	private const AtomicList	autobuildTypeCache	:= AtomicList()
	
	@Inject	private const Scope	scope

	new make(|This|in) {
		in(this) 
		this.serviceTypeCache = scope.registry.serviceDefs.vals.map { it.type }
	}

	@Operator
	Obj? get(Type? type) {
		if (type == null)
			return null
		
		obj := null
		if (serviceTypeCache.contains(type))
			obj = scope.serviceByType(type)

		if (constTypeCache.containsKey(type))
			obj = constTypeCache[type]
		
		if (autobuildTypeCache.contains(type))
			obj = scope.build(type)
		
		if (obj == null) {
			if (type.isConst) {
				obj = scope.build(type)
				constTypeCache.set(type, obj)
				
			} else {
				autobuildTypeCache.add(type)
				obj = scope.build(type)
			}
		}

		return obj
	}
}
